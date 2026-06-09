extends Node
class_name VoxelizerManager
## VoxelizerManager (Fase 8)
##
## Orchestra la pipeline di voxelizzazione GPU tramite RenderingDevice:
##   1. compila compute/voxelizer.glsl in SPIR-V a runtime;
##   2. impacchetta gli oggetti del bagaglio in proxy analitici (cubo/sfera);
##   3. esegue il compute shader che riempie una Texture3D RGBA16F 128^3;
##   4. legge a CPU il risultato (per la VoxelDebugView della Fase 8).
##
## Usa un RenderingDevice LOCALE (separato dal device di rendering principale)
## cosi' la voxelizzazione non interferisce col render 2.5D delle Fasi 1-7 e il
## readback della texture e' diretto via texture_get_data().

const SHADER_PATH := "res://compute/voxelizer.glsl"

# Lato della griglia di voxel (deve combaciare con la costante GRID nello shader).
const GRID := 128
# local_size(4,4,4) -> 32 gruppi di lavoro per asse.
const WORKGROUP := 4
# Float per proxy: 3 * vec4 = 12.
const PROXY_FLOATS := 12

# category (DataManager) -> material_id scritto nel canale B.
#   organico -> 0.0 (arancione), misto/elettronica -> 0.5 (verde), metallo -> 1.0 (blu)
const MATERIAL_ID := {
	"organic": 0.0,
	"electronics": 0.5,
	"mixed": 0.5,
	"metal": 1.0,
}

# category -> tipo di proxy procedurale (box per elettronica/indumenti/metallo,
# sfera per liquidi/cibo, cioe' la categoria "organic" del DataManager v1.0).
const PROXY_FOR_CATEGORY := {
	"organic": "sphere",
	"electronics": "box",
	"mixed": "box",
	"metal": "box",
}

# --- Stato GPU (persistente) ------------------------------------------------
var _rd: RenderingDevice
var _shader: RID
var _pipeline: RID
var _shader_ok := false

# FASE 12 — lato griglia CORRENTE (per il LOD automatico). Parte da GRID (128) e
# può scendere a 64³ se gli FPS crollano. La costante GRID resta il default.
var grid: int = GRID

# --- Risorse dell'ultima voxelizzazione (liberate da clear_volume / al riuso) -
var _proxy_buffer: RID
var _counter_buffer: RID
var _volume_texture: RID

# --- Risultati pubblici (letti dalla VoxelDebugView) ------------------------
var last_volume_data: PackedByteArray   # GRID^3 voxel, 8 byte/voxel (RGBA half)
var last_occupied_count := 0
var last_time_ms := 0.0
var last_item_count := 0


func _ready() -> void:
	_rd = RenderingServer.create_local_rendering_device()
	if _rd == null:
		push_error("[VoxelizerManager] RenderingDevice non disponibile su questo backend.")
		return
	_compile_shader()


func _exit_tree() -> void:
	_free_buffers()
	if _rd != null:
		if _pipeline.is_valid():
			_rd.free_rid(_pipeline)
		if _shader.is_valid():
			_rd.free_rid(_shader)
		_rd.free()
		_rd = null


## Compila il compute shader da sorgente GLSL e crea la pipeline.
## Logga in console l'esito (successo o dettaglio errore SPIR-V).
func _compile_shader() -> void:
	if not FileAccess.file_exists(SHADER_PATH):
		push_error("[VoxelizerManager] Shader non trovato: %s" % SHADER_PATH)
		return

	var file := FileAccess.open(SHADER_PATH, FileAccess.READ)
	if file == null:
		push_error("[VoxelizerManager] Impossibile aprire %s" % SHADER_PATH)
		return
	var raw := file.get_as_text()
	file.close()

	# Il file porta il tag Godot "#[compute]" (per non rompere l'import in editor),
	# ma shader_compile_spirv_from_source() vuole GLSL puro: lo togliamo.
	var glsl := ""
	for line in raw.split("\n"):
		if line.strip_edges().begins_with("#["):
			continue
		glsl += line + "\n"

	# FASE 12 — LOD: sostituisce il lato griglia hardcoded (128) con quello
	# corrente prima della compilazione SPIR-V, così lo stesso sorgente serve sia
	# 128³ (qualità piena) sia 64³ (fallback performance).
	if grid != GRID:
		glsl = glsl.replace("const int GRID = 128", "const int GRID = %d" % grid)

	var src := RDShaderSource.new()
	src.language = RenderingDevice.SHADER_LANGUAGE_GLSL
	src.source_compute = glsl

	var spirv := _rd.shader_compile_spirv_from_source(src)
	var err := spirv.compile_error_compute
	if err != "":
		push_error("[VoxelizerManager] Compilazione SPIR-V FALLITA (stage compute):\n%s" % err)
		return

	_shader = _rd.shader_create_from_spirv(spirv)
	if not _shader.is_valid():
		push_error("[VoxelizerManager] shader_create_from_spirv ha restituito un RID non valido.")
		return

	_pipeline = _rd.compute_pipeline_create(_shader)
	_shader_ok = _pipeline.is_valid()
	if _shader_ok:
		print("[VoxelizerManager] Compute shader compilato — SPIR-V OK, pipeline pronta (griglia %d^3)." % grid)
	else:
		push_error("[VoxelizerManager] compute_pipeline_create FALLITA.")


## FASE 12 — riconfigura il lato della griglia (LOD) e ricompila la pipeline.
## Ritorna true se la nuova pipeline è pronta. In caso di errore mantiene lo stato
## precedente non valido (il chiamante deve gestire il fallback).
func set_grid(new_grid: int) -> bool:
	if new_grid == grid and _shader_ok:
		return true
	# Libera pipeline/shader correnti prima di ricompilare.
	if _rd != null:
		if _pipeline.is_valid():
			_rd.free_rid(_pipeline)
			_pipeline = RID()
		if _shader.is_valid():
			_rd.free_rid(_shader)
			_shader = RID()
	_shader_ok = false
	grid = new_grid
	_compile_shader()
	return _shader_ok


## Voxelizza il bagaglio e restituisce il RID della Texture3D risultante.
##
## items_array: Array di Dictionary. Due forme accettate:
##   - esplicita (dati di test Fase 8): { category, z_eff, density, proxy,
##     size:Vector3 | radius:float, position:Vector3, rotation:float };
##   - DataManager (integrazione v1.0): { item_id, position, rotation, scale }
##     -> categoria/z_eff/proxy risolti dal DataManager.
func voxelize_baggage(items_array: Array) -> RID:
	if not _shader_ok:
		push_error("[VoxelizerManager] Shader non pronto: voxelizzazione annullata.")
		return RID()

	# Libera le risorse della voxelizzazione precedente (no VRAM leak / no accumulo).
	_free_buffers()

	# --- Impacchetta i proxy in un PackedFloat32Array (layout std430) --------
	var proxy_data := PackedFloat32Array()
	var n := 0
	for item in items_array:
		var pr: Dictionary = _resolve_proxy(item)
		if pr.is_empty():
			continue
		var size_radius: Vector3 = pr.half if pr.type == 0 else Vector3(pr.radius, 0.0, 0.0)
		proxy_data.append_array(PackedFloat32Array([
			pr.center.x, pr.center.y, pr.center.z, float(pr.type),
			size_radius.x, size_radius.y, size_radius.z, 0.0,
			pr.density, pr.zeff_norm, pr.material_id, pr.rot,
		]))
		n += 1
	last_item_count = n
	if n == 0:
		push_warning("[VoxelizerManager] Nessun proxy valido: il volume risultera' vuoto.")

	var proxy_bytes := proxy_data.to_byte_array()
	# Uno StorageBuffer non puo' avere dimensione 0: garantiamo almeno un proxy "vuoto".
	if proxy_bytes.size() == 0:
		proxy_bytes.resize(PROXY_FLOATS * 4)
	_proxy_buffer = _rd.storage_buffer_create(proxy_bytes.size(), proxy_bytes)

	# Contatore atomico azzerato.
	var zero := PackedByteArray()
	zero.resize(4)
	_counter_buffer = _rd.storage_buffer_create(4, zero)

	# Texture3D di destinazione (RGBA16F).
	var fmt := RDTextureFormat.new()
	fmt.width = grid
	fmt.height = grid
	fmt.depth = grid
	fmt.texture_type = RenderingDevice.TEXTURE_TYPE_3D
	fmt.format = RenderingDevice.DATA_FORMAT_R16G16B16A16_SFLOAT
	fmt.usage_bits = (
		RenderingDevice.TEXTURE_USAGE_STORAGE_BIT
		| RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT
		| RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT
	)
	_volume_texture = _rd.texture_create(fmt, RDTextureView.new(), [])

	# --- Uniform set ---------------------------------------------------------
	var u_proxy := RDUniform.new()
	u_proxy.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	u_proxy.binding = 0
	u_proxy.add_id(_proxy_buffer)

	var u_volume := RDUniform.new()
	u_volume.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	u_volume.binding = 1
	u_volume.add_id(_volume_texture)

	var u_counter := RDUniform.new()
	u_counter.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	u_counter.binding = 2
	u_counter.add_id(_counter_buffer)

	var uniform_set := _rd.uniform_set_create([u_proxy, u_volume, u_counter], _shader, 0)

	# Push constant: num_proxies + padding (deve essere multiplo di 16 byte).
	var push_bytes := PackedInt32Array([n, 0, 0, 0]).to_byte_array()

	# --- Dispatch ------------------------------------------------------------
	var groups := grid / WORKGROUP  # 32 a 128³, 16 a 64³
	var t0 := Time.get_ticks_usec()
	var compute_list := _rd.compute_list_begin()
	_rd.compute_list_bind_compute_pipeline(compute_list, _pipeline)
	_rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
	_rd.compute_list_set_push_constant(compute_list, push_bytes, push_bytes.size())
	_rd.compute_list_dispatch(compute_list, groups, groups, groups)
	_rd.compute_list_end()
	# Su RenderingDevice locale, submit()+sync() racchiude la barriera implicita
	# tra il dispatch e il readback successivo (l'esplicito barrier() e' deprecato).
	_rd.submit()
	_rd.sync()
	last_time_ms = float(Time.get_ticks_usec() - t0) / 1000.0

	# --- Readback ------------------------------------------------------------
	last_volume_data = _rd.texture_get_data(_volume_texture, 0)
	last_occupied_count = _rd.buffer_get_data(_counter_buffer).decode_u32(0)

	# L'uniform set e' transitorio: lo liberiamo subito (i buffer/texture restano).
	_rd.free_rid(uniform_set)

	print("[VoxelizerManager] Voxelizzazione completata in %.2fms — %d oggetti, %d voxel occupati" % [
		last_time_ms, n, last_occupied_count
	])
	return _volume_texture


## Dealloca buffer e texture dalla VRAM (chiamare quando il bagaglio esce dalla viewport).
func clear_volume() -> void:
	_free_buffers()
	last_volume_data = PackedByteArray()
	last_occupied_count = 0
	print("[VoxelizerManager] Volume e buffer liberati dalla VRAM.")


func _free_buffers() -> void:
	if _rd == null:
		return
	if _volume_texture.is_valid():
		_rd.free_rid(_volume_texture)
		_volume_texture = RID()
	if _proxy_buffer.is_valid():
		_rd.free_rid(_proxy_buffer)
		_proxy_buffer = RID()
	if _counter_buffer.is_valid():
		_rd.free_rid(_counter_buffer)
		_counter_buffer = RID()


## Risolve un elemento del bagaglio in un descrittore di proxy normalizzato.
## Ritorna {} se l'elemento non e' risolvibile.
func _resolve_proxy(item: Dictionary) -> Dictionary:
	var category := ""
	var z_eff := 1.0
	var density := 0.5
	var proxy := "box"
	var center := Vector3(0.5, 0.5, 0.5)
	var size := Vector3(0.1, 0.1, 0.1)
	var radius := 0.05
	var rot := 0.0

	if item.has("proxy"):
		# Forma esplicita (dati di test Fase 8).
		category = str(item.get("category", ""))
		z_eff = float(item.get("z_eff", item.get("z_eff_base", 1.0)))
		density = float(item.get("density", 0.5))
		proxy = str(item.get("proxy", "box"))
		center = item.get("position", center)
		size = item.get("size", size)
		radius = float(item.get("radius", radius))
		rot = float(item.get("rotation", 0.0))
	else:
		# Forma DataManager (integrazione v1.0). La mappatura 2D->3D e' provvisoria
		# (la geometria reale arriva in Fase 9/10): qui basta a non rompere il riuso.
		var data: Dictionary = DataManager.get_item(str(item.get("item_id", "")))
		if data.is_empty():
			push_warning("[VoxelizerManager] item_id sconosciuto, oggetto saltato: %s" % str(item))
			return {}
		category = str(data.get("category", ""))
		z_eff = float(data.get("z_eff_base", 1.0))
		var thick := float(data.get("thickness_multiplier", 1.0))
		var scale := float(item.get("scale", 1.0))
		density = clampf(z_eff / 30.0, 0.0, 1.0)
		proxy = String(PROXY_FOR_CATEGORY.get(category, "box"))
		var pos2: Vector2 = item.get("position", Vector2.ZERO)
		# Mappa la posizione 2D (centrata sull'origine, ~ +/-140 px) nel piano XZ [0,1].
		center = Vector3(
			clampf(0.5 + pos2.x / 280.0, 0.05, 0.95),
			0.5,
			clampf(0.5 + pos2.y / 280.0, 0.05, 0.95)
		)
		size = Vector3(0.12, 0.04, 0.12) * scale * thick
		radius = 0.06 * scale * thick
		rot = float(item.get("rotation", 0.0))

	var zeff_norm := clampf((z_eff - 1.0) / 29.0, 0.0, 1.0)
	var material_id := float(MATERIAL_ID.get(category, 0.5))
	var type := 1 if proxy == "sphere" else 0

	return {
		"type": type,
		"center": center,
		"half": size * 0.5,   # size = estensioni piene -> semi-estensioni per il SAT
		"radius": radius,
		"density": density,
		"zeff_norm": zeff_norm,
		"material_id": material_id,
		"rot": rot,
	}
