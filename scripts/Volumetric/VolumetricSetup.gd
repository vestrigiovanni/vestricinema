extends Node3D
## VolumetricSetup (Fase 9)
##
## Nodo radice della scena di test del raymarcher volumetrico. All'avvio:
##   1. genera proceduralmente una texture di blue noise 64x64 (Halton 2/3) e
##      logga la sua entropia media;
##   2. voxelizza gli stessi 3 oggetti hardcoded della Fase 8 (laptop, bottiglia,
##      chiave inglese) col VoxelizerManager;
##   3. ricostruisce una ImageTexture3D dal readback RGBA16F (il VoxelizerManager
##      usa un RenderingDevice LOCALE, quindi il suo RID non e' campionabile da
##      uno spatial shader sul device principale: serve una risorsa Texture3D);
##   4. inietta volume e blue noise nel ShaderMaterial del cubo proxy;
##   5. aggiorna la uniform volume_transform ogni frame.
##
## La UI minima (slider/toggle/label) e' cablata qui.

const VoxelizerManager := preload("res://scripts/Volumetric/VoxelizerManager.gd")
const BVHAccelerator := preload("res://scripts/Volumetric/BVHAccelerator.gd")
const ObjectDragger := preload("res://scripts/Volumetric/ObjectDragger.gd")
const DectAnalysisOverlay := preload("res://scripts/UI/DectAnalysisOverlay.gd")
const PhysicsValidator := preload("res://scripts/Debug/PhysicsValidator.gd")
const RAYMARCH_SHADER := preload("res://shaders/volumetric/xray_raymarch.gdshader")

const GRID := VoxelizerManager.GRID          # 128
const BYTES_PER_VOXEL := 8                    # RGBA half
const NOISE_SIZE := 64

# Lato fisico del volume (carry-on ~60cm) per le coordinate in cm del drag.
const VOLUME_CM := 60.0
# Le normali dei tre piani di taglio, indicizzate come in SlicingPanel.
const CLIP_NORMALS := [
	Vector3(1, 0, 0),  # SAG sagittale
	Vector3(0, 1, 0),  # COR coronale
	Vector3(0, 0, 1),  # AX  assiale
]

# FASE 12 — modalità d'uso. Standalone (RaymarchViewport.tscn): voxelizza i 3
# oggetti di test e cabla la propria UI. Embedded (stazione CT della v2.0):
# attende load_baggage() e i controlli arrivano dal pannello destro esterno.
@export var auto_test_baggage := true
@export var show_builtin_ui := true

# FASE 12 — segnali per la v2.0.
signal load_finished                 # voxelizzazione + texture pronte (fade-in 3D)
signal dect_result(info: Dictionary) # esito analisi DECT al click (-> pannello)
signal lod_changed(text: String)     # livello LOD corrente (-> monitor F3)

@onready var voxelizer: VoxelizerManager = $Voxelizer
@onready var proxy_cube: MeshInstance3D = $ProxyCube

# --- UI ---------------------------------------------------------------------
@onready var abs_slider: HSlider = $UI/Panel/AbsorptionSlider
@onready var beam_slider: HSlider = $UI/Panel/BeamSlider
@onready var steps_slider: HSlider = $UI/Panel/StepsSlider
@onready var abs_label: Label = $UI/Panel/AbsorptionLabel
@onready var beam_label: Label = $UI/Panel/BeamLabel
@onready var steps_label: Label = $UI/Panel/StepsLabel
@onready var organic_toggle: CheckButton = $UI/Panel/OrganicToggle
@onready var metal_toggle: CheckButton = $UI/Panel/MetalToggle
@onready var invert_toggle: CheckButton = $UI/Panel/InvertToggle
# --- Controlli Fase 11 ------------------------------------------------------
@onready var scatter_slider: HSlider = $UI/Panel/ScatterSlider
@onready var scatter_label: Label = $UI/Panel/ScatterLabel
@onready var scatter_thr_slider: HSlider = $UI/Panel/ScatterThrSlider
@onready var scatter_thr_label: Label = $UI/Panel/ScatterThrLabel
@onready var window_slider: HSlider = $UI/Panel/WindowSlider
@onready var window_label: Label = $UI/Panel/WindowLabel
@onready var level_slider: HSlider = $UI/Panel/LevelSlider
@onready var level_label: Label = $UI/Panel/LevelLabel
@onready var reset_button: Button = $UI/Panel/ResetButton
@onready var fps_label: Label = $UI/FpsLabel
@onready var slicing_panel: Panel = $UI/SlicingPanel
@onready var selected_label: Label = $UI/SelectedLabel
@onready var drag_label: Label = $UI/DragLabel

var _material: ShaderMaterial
@onready var _camera: Camera3D = $ArcBallCamera

# --- Stato Fase 10 ----------------------------------------------------------
var _objects: Array = []              # item del bagaglio (mutabili: il drag li sposta)
var _proxies: Array = []             # descrittori proxy risolti, allineati a _objects
var _bvh: BVHAccelerator             # per il ray picking
var _volume_images: Array[Image] = [] # fette cache della Texture3D (update dirty)
var _volume_tex: ImageTexture3D
var _highlight: MeshInstance3D       # wireframe AABB dell'oggetto selezionato
var _dragger                         # ObjectDragger
var _dect_overlay                    # DectAnalysisOverlay (Fase 11)
var _physics_validator               # PhysicsValidator (Fase 11)
var _selected_index := -1
# Stato clipping (offset e abilitazione per i 3 piani).
var _clip_offset := [0.0, 0.0, 0.0]
var _clip_on := [false, false, false]

# --- Stato Fase 12 (LOD + threading) ----------------------------------------
var _grid := GRID                    # lato griglia corrente (LOD: 128 o 64)
var _vox_thread: Thread              # build delle fette su thread (non blocca il main)
# Stato dei parametri immagine: i setter (UI standalone O pannello v2.0) scrivono
# qui, _push_all_uniforms legge da qui. Default identici alla Fase 11.
var _p := {
	"absorption_scale": 6.0,
	"beam_intensity": 1.0,
	"max_steps": 256,
	"organic_only": false,
	"metal_only": false,
	"invert": false,
	"scatter_intensity": 0.3,
	"scatter_threshold": 0.4,
	"window": 1.0,
	"level": 0.5,
}
# LOD: livelli 0=128³/256, 1=128³/192, 2=64³/128. Monitor ogni 2s.
var _lod := 0
var _lod_accum := 0.0
var _lod_good_streak := 0.0
const LOD_NAMES := ["128³ / steps 256", "128³ / steps 192", "64³ / steps 128"]


func _ready() -> void:
	_material = ShaderMaterial.new()
	_material.shader = RAYMARCH_SHADER
	proxy_cube.material_override = _material

	# 1) Blue noise -> uniform.
	var noise := _generate_blue_noise()
	_material.set_shader_parameter("blue_noise", noise)

	# Fase 10: wireframe di selezione + dragger (input puro).
	_setup_highlight()
	_dragger = ObjectDragger.new()
	add_child(_dragger)
	_dragger.setup(self, _camera)

	# Fase 11: overlay DECT + validatore fisico (F4).
	_dect_overlay = DectAnalysisOverlay.new()
	add_child(_dect_overlay)
	if show_builtin_ui:
		# Standalone: popup floating sopra la propria UI.
		_dect_overlay.setup(self, _camera, $UI)
	else:
		# Embedded (v2.0): nessun popup, il risultato va al pannello via segnale.
		_dect_overlay.setup_signal(self, _camera, func(info): dect_result.emit(info))
	_physics_validator = PhysicsValidator.new()
	add_child(_physics_validator)
	_physics_validator.setup(self)

	# UI integrata solo in modalità standalone; in embedded la nasconde.
	if show_builtin_ui:
		_sync_ui_from_params()
		_setup_ui()
	else:
		$UI.visible = false

	_push_all_uniforms()
	_push_clip_uniforms()
	clear_selection()

	# Standalone: voxelizza subito i 3 oggetti di test. Embedded: attende load_baggage().
	if auto_test_baggage:
		load_baggage(_test_baggage())
	print("[VolumetricSetup] Pronto (%s). " % ("standalone" if show_builtin_ui else "embedded v2.0"))


func _process(delta: float) -> void:
	# 5) La matrice modello del cubo proxy puo' cambiare (qui e' statica, ma lo
	# shader la richiede ad ogni frame per derivare il raggio in spazio locale).
	if _material:
		_material.set_shader_parameter("volume_transform", proxy_cube.global_transform)
		# Fase 11: anima la grana di Poisson variando il seed ogni frame.
		_material.set_shader_parameter("noise_seed", Time.get_ticks_msec() * 0.001)
	if show_builtin_ui:
		fps_label.text = "FPS: %d" % Engine.get_frames_per_second()
	_update_lod(delta)


# ----------------------------------------------------------------------------
#  FASE 12 — LOD automatico. Campiona gli FPS ogni 2s e degrada/ripristina la
#  qualità per garantire >=30 FPS su M1:
#    livello 0: 128³, max_steps 256 (qualità piena)
#    livello 1: 128³, max_steps 192 (FPS < 45)
#    livello 2: 64³,  max_steps 128 (FPS < 30)
#  Risale di un livello dopo 5s consecutivi sopra 50 FPS.
# ----------------------------------------------------------------------------
func _update_lod(delta: float) -> void:
	_lod_accum += delta
	var fps := Engine.get_frames_per_second()

	# Risalita: 5s consecutivi sopra 50 FPS -> migliora di un livello.
	if fps > 50.0 and _lod > 0:
		_lod_good_streak += delta
		if _lod_good_streak >= 5.0:
			_set_lod(_lod - 1)
			_lod_good_streak = 0.0
	else:
		_lod_good_streak = 0.0

	# Discesa: valutata ogni 2s sugli FPS correnti.
	if _lod_accum < 2.0:
		return
	_lod_accum = 0.0
	if fps < 30.0 and _lod < 2:
		_set_lod(2)
	elif fps < 45.0 and _lod < 1:
		_set_lod(1)


func _set_lod(level: int) -> void:
	level = clampi(level, 0, 2)
	if level == _lod:
		return
	var old := _lod
	_lod = level

	# max_steps per livello.
	var steps: int = [256, 192, 128][_lod]
	_p["max_steps"] = steps
	_material.set_shader_parameter("max_steps", steps)

	# Risoluzione del volume: 64³ solo al livello 2, altrimenti 128³.
	var want_grid := 64 if _lod >= 2 else GRID
	if want_grid != voxelizer.grid:
		if voxelizer.set_grid(want_grid) and not _objects.is_empty():
			# Ri-voxelizza il bagaglio corrente alla nuova griglia (sincrono: è
			# raro e va completato prima del frame successivo).
			_resolve_all_proxies()
			voxelizer.voxelize_baggage(_objects)
			_volume_images = _slices_from_bytes(voxelizer.last_volume_data, voxelizer.grid)
			if not _volume_images.is_empty():
				_grid = voxelizer.grid
				_volume_tex = ImageTexture3D.new()
				_volume_tex.create(Image.FORMAT_RGBAH, _grid, _grid, _grid, false, _volume_images)
				_material.set_shader_parameter("volume_tex", _volume_tex)
				_rebuild_bvh()

	if _lod > old:
		print("[LOD] Riduzione qualità: %s voxel, max_steps=%d" % [
			"64³" if _lod >= 2 else "128³", steps
		])
	else:
		print("[LOD] Ripristino qualità: %s voxel, max_steps=%d" % [
			"64³" if _lod >= 2 else "128³", steps
		])
	lod_changed.emit(LOD_NAMES[_lod])


# ----------------------------------------------------------------------------
#  Bagaglio di test — identico alla Fase 8 (VoxelDebugView._test_baggage).
# ----------------------------------------------------------------------------
func _test_baggage() -> Array:
	return [
		{   # 1) Laptop: box "misto" (verde), al centro del volume.
			"name": "Laptop 15\"",
			"category": "electronics", "z_eff": 14.0, "density": 0.6,
			"proxy": "box", "size": Vector3(0.35, 0.03, 0.25),
			"position": Vector3(0.5, 0.5, 0.5),
		},
		{   # 2) Bottiglia: sfera "organica" (arancione), sovrapposta al laptop.
			"name": "Bottiglia 500ml",
			"category": "organic", "z_eff": 7.4, "density": 0.4,
			"proxy": "sphere", "radius": 0.08,
			"position": Vector3(0.35, 0.55, 0.5),
		},
		{   # 3) Chiave inglese: box "metallo" (blu), sul laptop, angolata 30 gradi.
			"name": "Chiave inglese",
			"category": "metal", "z_eff": 26.0, "density": 0.9,
			"proxy": "box", "size": Vector3(0.18, 0.02, 0.03),
			"position": Vector3(0.6, 0.52, 0.48), "rotation": deg_to_rad(30.0),
		},
	]


# ----------------------------------------------------------------------------
#  Blue noise 64x64 (FORMAT_L8) via sequenza di Halton base 2 / base 3.
#  Approssimazione del rumore blu senza void-and-cluster completo: i valori
#  (base 2, a bassa discrepanza) vengono distribuiti sui pixel in un ordine
#  scrambled dalla base 3, ottenendo un istogramma uniforme (entropia ~ massima)
#  e una disposizione spazialmente decorrelata.
# ----------------------------------------------------------------------------
func _generate_blue_noise() -> ImageTexture:
	var count := NOISE_SIZE * NOISE_SIZE
	var values := PackedFloat32Array()
	var keys := PackedFloat32Array()
	values.resize(count)
	keys.resize(count)
	for i in count:
		values[i] = _halton(i + 1, 2)
		keys[i] = _halton(i + 1, 3)

	# Permutazione pseudo-casuale dei pixel pilotata dalla base 3.
	var order := range(count)
	order.sort_custom(func(a, b): return keys[a] < keys[b])

	var img := Image.create(NOISE_SIZE, NOISE_SIZE, false, Image.FORMAT_L8)
	var histogram := PackedInt32Array()
	histogram.resize(256)
	histogram.fill(0)
	for rank in count:
		var pix: int = order[rank]
		var x := pix % NOISE_SIZE
		var y := pix / NOISE_SIZE
		var v: float = values[rank]
		img.set_pixel(x, y, Color(v, v, v))
		histogram[int(clampf(v * 255.0, 0.0, 255.0))] += 1

	# Entropia media (Shannon, bit) dell'istogramma a 256 livelli.
	var entropy := 0.0
	for h in histogram:
		if h > 0:
			var p := float(h) / float(count)
			entropy -= p * (log(p) / log(2.0))
	print("[VolumetricSetup] Blue noise %dx%d generata (Halton 2/3) — entropia media %.3f bit (max teorico 8.000 su 256 livelli)." % [
		NOISE_SIZE, NOISE_SIZE, entropy
	])

	var tex := ImageTexture.create_from_image(img)
	return tex


## Sequenza di Halton: radical inverse dell'indice in una data base.
func _halton(index: int, base: int) -> float:
	var result := 0.0
	var f := 1.0
	var i := index
	while i > 0:
		f /= float(base)
		result += f * float(i % base)
		i = i / base
	return result


# ============================================================================
#  FASE 12 — Caricamento bagaglio con voxelizzazione (parz.) in background.
#
#  Il dispatch GPU (RenderingDevice LOCALE) resta sul main thread: un RD locale è
#  affine a un solo thread e dura ~3ms. La parte CPU pesante — ricostruire le
#  ~128 Image RGBAH dal readback (decine di MB) — gira invece su un Thread, così
#  il main resta reattivo e la schermata "ANALISI CT IN CORSO" può animarsi.
#  Al termine, _finalize_load (sul main, via call_deferred) crea la ImageTexture3D
#  e la inietta, poi emette load_finished per il fade-in 3D.
# ============================================================================
func load_baggage(items: Array) -> void:
	_objects = items
	_resolve_all_proxies()
	# Dispatch GPU sincrono (~3ms): riempie voxelizer.last_volume_data.
	voxelizer.voxelize_baggage(_objects)
	_grid = voxelizer.grid

	# Build delle fette su thread (non blocca il main).
	if _vox_thread != null and _vox_thread.is_started():
		_vox_thread.wait_to_finish()
	_vox_thread = Thread.new()
	_vox_thread.start(_thread_build_slices.bind(voxelizer.last_volume_data, _grid))


## Eseguito sul Thread: decodifica i byte del readback in Array[Image]. Nessun
## accesso a risorse GPU qui (solo Image, sicuro fuori dal main).
func _thread_build_slices(data: PackedByteArray, g: int) -> void:
	var images := _slices_from_bytes(data, g)
	call_deferred("_finalize_load", images)


## Costruisce le fette RGBAH dal readback depth-major (g fette di g*g voxel da 8B).
func _slices_from_bytes(data: PackedByteArray, g: int) -> Array[Image]:
	var out: Array[Image] = []
	var slice_bytes := g * g * BYTES_PER_VOXEL
	if data.size() < g * slice_bytes:
		return out
	for z in g:
		var slice := data.slice(z * slice_bytes, (z + 1) * slice_bytes)
		out.append(Image.create_from_data(g, g, false, Image.FORMAT_RGBAH, slice))
	return out


## Sul main thread: crea la Texture3D, la inietta, ricostruisce la BVH e segnala.
func _finalize_load(images: Array[Image]) -> void:
	if _vox_thread != null and _vox_thread.is_started():
		_vox_thread.wait_to_finish()
		_vox_thread = null

	if images.is_empty():
		push_error("[VolumetricSetup] Readback voxel non valido: volume non iniettato.")
		load_finished.emit()
		return

	_volume_images = images
	_volume_tex = ImageTexture3D.new()
	_volume_tex.create(Image.FORMAT_RGBAH, _grid, _grid, _grid, false, _volume_images)
	_material.set_shader_parameter("volume_tex", _volume_tex)
	_rebuild_bvh()
	clear_selection()
	print("[VolumetricSetup] Texture3D %d³ iniettata (%d oggetti)." % [_grid, _objects.size()])
	load_finished.emit()


func _exit_tree() -> void:
	if _vox_thread != null and _vox_thread.is_started():
		_vox_thread.wait_to_finish()
		_vox_thread = null


# ----------------------------------------------------------------------------
#  UI
# ----------------------------------------------------------------------------
func _setup_ui() -> void:
	for s in [abs_slider, beam_slider, steps_slider, scatter_slider, scatter_thr_slider, window_slider, level_slider]:
		s.value_changed.connect(func(_v): _pull_ui_into_params())
	organic_toggle.toggled.connect(_on_organic_toggled)
	metal_toggle.toggled.connect(_on_metal_toggled)
	invert_toggle.toggled.connect(func(_v): _pull_ui_into_params())
	reset_button.pressed.connect(_camera._reset_camera)

	# Slicing CT (Fase 10).
	slicing_panel.plane_changed.connect(_on_plane_changed)
	slicing_panel.reset_requested.connect(func(): pass)  # gia' gestito da plane_changed


## All'avvio standalone: i valori autorati negli slider .tscn diventano lo stato.
func _sync_ui_from_params() -> void:
	_pull_ui_into_params()


## Copia lo stato dei controlli standalone in _p e applica.
func _pull_ui_into_params() -> void:
	_p.absorption_scale = abs_slider.value
	_p.beam_intensity = beam_slider.value
	_p.max_steps = int(steps_slider.value)
	_p.organic_only = organic_toggle.button_pressed
	_p.metal_only = metal_toggle.button_pressed
	_p.invert = invert_toggle.button_pressed
	_p.scatter_intensity = scatter_slider.value
	_p.scatter_threshold = scatter_thr_slider.value
	_p.window = window_slider.value
	_p.level = level_slider.value
	_push_all_uniforms()


# ============================================================================
#  FASE 12 — API pubblica per il pannello controlli della v2.0 (embedded).
#  Il pannello esterno scrive i parametri qui senza conoscere lo shader.
# ============================================================================
func set_image_param(key: String, value) -> void:
	match key:
		"organic_only":
			_p.organic_only = bool(value)
			if value:
				_p.metal_only = false
		"metal_only":
			_p.metal_only = bool(value)
			if value:
				_p.organic_only = false
		_:
			_p[key] = value
	_push_all_uniforms()


func set_clip(axis: int, offset: float, enabled: bool) -> void:
	_on_plane_changed(axis, offset, enabled)


func reset_camera() -> void:
	_camera._reset_camera()


# ----------------------------------------------------------------------------
#  Clipping planes / slicing
# ----------------------------------------------------------------------------
func _on_plane_changed(axis: int, offset: float, enabled: bool) -> void:
	_clip_offset[axis] = offset
	_clip_on[axis] = enabled
	_push_clip_uniforms()


func _push_clip_uniforms() -> void:
	if _material == null:
		return
	_material.set_shader_parameter("clip_sag", _clip_vec4(0))
	_material.set_shader_parameter("clip_cor", _clip_vec4(1))
	_material.set_shader_parameter("clip_ax", _clip_vec4(2))
	_material.set_shader_parameter("clip_enabled", Vector3(
		1.0 if _clip_on[0] else 0.0,
		1.0 if _clip_on[1] else 0.0,
		1.0 if _clip_on[2] else 0.0,
	))


func _clip_vec4(axis: int) -> Vector4:
	var n: Vector3 = CLIP_NORMALS[axis]
	# Lo shader si aspetta vec4(normale, offset).
	return Vector4(n.x, n.y, n.z, _clip_offset[axis])


# I filtri organic/metal sono mutuamente esclusivi: attivarne uno spegne l'altro.
func _on_organic_toggled(on: bool) -> void:
	if on and metal_toggle.button_pressed:
		metal_toggle.set_pressed_no_signal(false)
	_pull_ui_into_params()


func _on_metal_toggled(on: bool) -> void:
	if on and organic_toggle.button_pressed:
		organic_toggle.set_pressed_no_signal(false)
	_pull_ui_into_params()


## Spinge lo stato corrente di _p (popolato dalla UI standalone O dai setter v2.0)
## nelle uniform dello shader. Aggiorna le label solo se la UI integrata è visibile.
func _push_all_uniforms() -> void:
	if _material == null:
		return
	_material.set_shader_parameter("absorption_scale", _p.absorption_scale)
	_material.set_shader_parameter("beam_intensity", _p.beam_intensity)
	_material.set_shader_parameter("max_steps", int(_p.max_steps))
	_material.set_shader_parameter("enable_organic_only", _p.organic_only)
	_material.set_shader_parameter("enable_metal_only", _p.metal_only)
	_material.set_shader_parameter("invert_image", _p.invert)
	_material.set_shader_parameter("scatter_intensity", _p.scatter_intensity)
	_material.set_shader_parameter("scatter_threshold", _p.scatter_threshold)
	_material.set_shader_parameter("window", _p.window)
	_material.set_shader_parameter("level", _p.level)
	if not show_builtin_ui:
		return
	abs_label.text = "ABSORPTION: %.1f" % _p.absorption_scale
	beam_label.text = "BEAM: %.2f" % _p.beam_intensity
	steps_label.text = "MAX STEPS: %d" % int(_p.max_steps)
	scatter_label.text = "SCATTER: %.2f" % _p.scatter_intensity
	scatter_thr_label.text = "SCATTER THR: %.2f" % _p.scatter_threshold
	window_label.text = "WINDOW: %.2f" % _p.window
	level_label.text = "LEVEL: %.2f" % _p.level


# ============================================================================
#  FASE 10 — Picking, selezione, drag e dirty-region re-voxelization.
#  Questi metodi sono l'API che ObjectDragger chiama: la geometria e la
#  voxelizzazione restano qui, l'input nel dragger.
# ============================================================================

# --- Proxy e BVH ------------------------------------------------------------

## Risolve ogni item nel suo descrittore proxy (stesso usato dalla GPU): cosi'
## il rasterizzatore CPU del dirty update e gli AABB del picking restano coerenti.
func _resolve_all_proxies() -> void:
	_proxies.clear()
	for item in _objects:
		_proxies.append(voxelizer._resolve_proxy(item))


## (Ri)costruisce la BVH sugli AABB degli oggetti, in spazio LOCALE del cubo
## proxy ([-0.5,0.5]^3): il ray picking trasforma il raggio in quello spazio.
func _rebuild_bvh() -> void:
	var objs: Array = []
	for i in _objects.size():
		var pr: Dictionary = _proxies[i]
		var ext := _proxy_extent_vol(pr)
		var center_local: Vector3 = pr.center - Vector3(0.5, 0.5, 0.5)
		objs.append({
			"center": center_local,
			"size": ext * 2.0,
			"item_index": i,
		})
	_bvh = BVHAccelerator.new()
	_bvh.build(objs)


## Semi-estensioni dell'AABB dell'oggetto in spazio volume [0,1].
## Per il box ruotato attorno a Y si calcola l'AABB che lo racchiude.
func _proxy_extent_vol(pr: Dictionary) -> Vector3:
	if pr.type == 1:  # sfera
		var r: float = pr.radius
		return Vector3(r, r, r)
	var h: Vector3 = pr.half
	var rot: float = pr.rot
	var c := absf(cos(rot))
	var s := absf(sin(rot))
	return Vector3(h.x * c + h.z * s, h.y, h.x * s + h.z * c)


# --- API per ObjectDragger --------------------------------------------------

## Ray picking: lancia un raggio dalla camera attraverso il pixel e interroga la
## BVH. Ritorna l'indice dell'item colpito o -1.
func pick_object(screen_pos: Vector2) -> int:
	if _bvh == null:
		return -1
	var o_world := _camera.project_ray_origin(screen_pos)
	var n_world := _camera.project_ray_normal(screen_pos)
	var inv := proxy_cube.global_transform.affine_inverse()
	var o_local := inv * o_world
	var n_local := (inv.basis * n_world).normalized()
	var hit := _bvh.query_ray(o_local, n_local)
	if hit.is_empty():
		return -1
	return int(hit.object.item_index)


func get_object_center_vol(index: int) -> Vector3:
	return _proxies[index].center


func get_object_world_center(index: int) -> Vector3:
	return proxy_cube.global_transform * (_proxies[index].center - Vector3(0.5, 0.5, 0.5))


## Sposta l'oggetto (in coordinate mondo) durante il drag: aggiorna item, proxy e
## wireframe in tempo reale, MA non ri-voxelizza (avviene solo al rilascio).
func set_object_world_center(index: int, world_center: Vector3) -> void:
	var inv := proxy_cube.global_transform.affine_inverse()
	var vol := (inv * world_center) + Vector3(0.5, 0.5, 0.5)
	var ext := _proxy_extent_vol(_proxies[index])
	# Tieni l'oggetto dentro al volume (il centro non esce dai bordi dell'AABB).
	vol.x = clampf(vol.x, ext.x, 1.0 - ext.x)
	vol.y = clampf(vol.y, ext.y, 1.0 - ext.y)
	vol.z = clampf(vol.z, ext.z, 1.0 - ext.z)
	_objects[index]["position"] = vol
	_proxies[index] = voxelizer._resolve_proxy(_objects[index])
	_draw_highlight_box(index)


func object_center_cm(index: int) -> Vector3:
	return _proxies[index].center * VOLUME_CM


## Conferma del drag: ri-voxelizza SOLO la regione modificata (union AABB vecchio
## + nuovo) e ricostruisce la BVH. Logga voxel toccati e tempo.
func commit_object_move(index: int, old_center_vol: Vector3) -> void:
	if index < 0:
		return
	_revoxelize_region(index, old_center_vol)
	_rebuild_bvh()


# --- Highlight (wireframe AABB) ---------------------------------------------

func _setup_highlight() -> void:
	_highlight = MeshInstance3D.new()
	_highlight.mesh = ImmediateMesh.new()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.95, 0.2)   # giallo selezione
	mat.no_depth_test = true                    # disegna SOPRA il volume bianco
	_highlight.material_override = mat
	proxy_cube.add_child(_highlight)  # eredita il transform del cubo (spazio locale)
	_highlight.visible = false


func highlight_object(index: int) -> void:
	_selected_index = index
	_draw_highlight_box(index)
	_highlight.visible = true
	var item: Dictionary = _objects[index]
	selected_label.text = "%s | z_eff: %.1f" % [str(item.get("name", "Oggetto")), float(item.z_eff)]


func clear_selection() -> void:
	_selected_index = -1
	if _highlight:
		_highlight.visible = false
	selected_label.text = "Click su un oggetto per selezionarlo"
	hide_drag_label()


## Ridisegna i 12 spigoli dell'AABB dell'oggetto in spazio locale del cubo.
func _draw_highlight_box(index: int) -> void:
	var pr: Dictionary = _proxies[index]
	var c: Vector3 = pr.center - Vector3(0.5, 0.5, 0.5)
	var h := _proxy_extent_vol(pr)
	var mesh: ImmediateMesh = _highlight.mesh
	mesh.clear_surfaces()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	# 8 vertici del box.
	var corners: Array = []
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				corners.append(c + Vector3(sx * h.x, sy * h.y, sz * h.z))
	# Indici dei 12 spigoli (coppie di corner che differiscono per un solo asse).
	var edges := [
		[0, 1], [2, 3], [4, 5], [6, 7],  # lungo Z
		[0, 2], [1, 3], [4, 6], [5, 7],  # lungo Y
		[0, 4], [1, 5], [2, 6], [3, 7],  # lungo X
	]
	for e in edges:
		mesh.surface_add_vertex(corners[e[0]])
		mesh.surface_add_vertex(corners[e[1]])
	mesh.surface_end()


# --- Label di drag ----------------------------------------------------------

func set_drag_label(text: String) -> void:
	drag_label.text = text
	drag_label.visible = true


func hide_drag_label() -> void:
	drag_label.visible = false


# --- Dirty-region re-voxelization (CPU) -------------------------------------
#  Il compute shader della Fase 8 riscrive l'INTERO volume; qui invece, per non
#  ricalcolare 128^3 voxel ad ogni drop, ri-rasterizziamo analiticamente SOLO la
#  scatola che racchiude la posizione vecchia e quella nuova, replicando la
#  logica di voxelizer.glsl (proxy piu' denso vince), e aggiorniamo solo le fette
#  Image toccate prima dell'upload alla Texture3D.

func _revoxelize_region(index: int, old_center_vol: Vector3) -> void:
	var t0 := Time.get_ticks_usec()
	var pr: Dictionary = _proxies[index]
	var ext := _proxy_extent_vol(pr)
	var new_center: Vector3 = pr.center

	# Union AABB (vol space) di vecchia e nuova posizione, con 1 voxel di padding.
	var lo := Vector3(
		minf(old_center_vol.x, new_center.x),
		minf(old_center_vol.y, new_center.y),
		minf(old_center_vol.z, new_center.z)
	) - ext
	var hi := Vector3(
		maxf(old_center_vol.x, new_center.x),
		maxf(old_center_vol.y, new_center.y),
		maxf(old_center_vol.z, new_center.z)
	) + ext

	var vmin := Vector3i(
		clampi(int(floor(lo.x * _grid)) - 1, 0, _grid - 1),
		clampi(int(floor(lo.y * _grid)) - 1, 0, _grid - 1),
		clampi(int(floor(lo.z * _grid)) - 1, 0, _grid - 1)
	)
	var vmax := Vector3i(
		clampi(int(ceil(hi.x * _grid)) + 1, 0, _grid - 1),
		clampi(int(ceil(hi.y * _grid)) + 1, 0, _grid - 1),
		clampi(int(ceil(hi.z * _grid)) + 1, 0, _grid - 1)
	)

	var inv_grid := 1.0 / float(_grid)
	var touched := 0
	for z in range(vmin.z, vmax.z + 1):
		var img: Image = _volume_images[z]
		for y in range(vmin.y, vmax.y + 1):
			for x in range(vmin.x, vmax.x + 1):
				var p := (Vector3(x, y, z) + Vector3(0.5, 0.5, 0.5)) * inv_grid
				img.set_pixel(x, y, _sample_proxies(p))
				touched += 1

	# Upload: update() rimpiazza tutte le fette ma solo quelle nell'intervallo Z
	# sono cambiate (le altre Image sono le stesse istanze in cache).
	_volume_tex.update(_volume_images)

	var ms := float(Time.get_ticks_usec() - t0) / 1000.0
	print("[VolumetricSetup] Dirty region update — %s spostato a (%.2f, %.2f, %.2f) vol | %d voxel ri-rasterizzati (box %dx%dx%d) in %.2fms" % [
		str(_objects[index].get("name", "?")), new_center.x, new_center.y, new_center.z,
		touched, vmax.x - vmin.x + 1, vmax.y - vmin.y + 1, vmax.z - vmin.z + 1, ms
	])


## Rasterizza un singolo voxel testando tutti i proxy (il piu' denso vince),
## esattamente come il compute shader. Ritorna RGBA = (densita', z_eff, mat_id, occ).
func _sample_proxies(p: Vector3) -> Color:
	var best := -1.0
	var result := Color(0, 0, 0, 0)
	for pr in _proxies:
		var hit: bool = (_inside_sphere(p, pr) if pr.type == 1 else _inside_box(p, pr))
		if hit and pr.density > best:
			best = pr.density
			result = Color(pr.density, pr.zeff_norm, pr.material_id, 1.0)
	return result


func _inside_box(p: Vector3, pr: Dictionary) -> bool:
	var d: Vector3 = p - pr.center
	var rot: float = pr.rot
	var c := cos(-rot)
	var s := sin(-rot)
	var local := Vector3(c * d.x - s * d.z, d.y, s * d.x + c * d.z)
	var h: Vector3 = pr.half
	return absf(local.x) <= h.x and absf(local.y) <= h.y and absf(local.z) <= h.z


func _inside_sphere(p: Vector3, pr: Dictionary) -> bool:
	return p.distance_to(pr.center) <= float(pr.radius)


# ============================================================================
#  FASE 11 — API per DECT overlay e PhysicsValidator.
#  La geometria/volume vivono qui (come in Fase 10): l'overlay e il validatore
#  leggono soltanto. Campioniamo i proxy analitici (_sample_proxies) che sono
#  l'equivalente esatto del contenuto della Texture3D, evitando di decodificare
#  i mezzi-float RGBAH a CPU.
# ============================================================================

## Lancia un raggio dalla camera attraverso il pixel e restituisce il PRIMO voxel
## occupato incontrato dentro il volume. {} / {hit:false} se colpisce il vuoto.
func sample_volume_ray(screen_pos: Vector2) -> Dictionary:
	var o_world := _camera.project_ray_origin(screen_pos)
	var n_world := _camera.project_ray_normal(screen_pos)
	var inv := proxy_cube.global_transform.affine_inverse()
	# Spazio locale del cubo [-0.5,0.5] -> +0.5 per il cubo unitario [0,1].
	var ray_o := (inv * o_world) + Vector3(0.5, 0.5, 0.5)
	var ray_d := (inv.basis * n_world).normalized()

	# Intersezione raggio/AABB [0,1]^3 (slab method, come nello shader).
	var inv_d := Vector3(1.0 / ray_d.x, 1.0 / ray_d.y, 1.0 / ray_d.z)
	var ta := (Vector3.ZERO - ray_o) * inv_d
	var tb := (Vector3.ONE - ray_o) * inv_d
	var tmin3 := Vector3(minf(ta.x, tb.x), minf(ta.y, tb.y), minf(ta.z, tb.z))
	var tmax3 := Vector3(maxf(ta.x, tb.x), maxf(ta.y, tb.y), maxf(ta.z, tb.z))
	var t_enter := maxf(maxf(tmin3.x, tmin3.y), tmin3.z)
	var t_exit := minf(minf(tmax3.x, tmax3.y), tmax3.z)
	t_enter = maxf(t_enter, 0.0)
	if t_exit < t_enter:
		return {}

	var step := 1.0 / float(_grid)
	var t := t_enter
	while t <= t_exit:
		var p := ray_o + ray_d * t
		var voxel := _sample_proxies(p)
		if voxel.a > 0.5:
			return {
				"hit": true,
				"density": voxel.r,
				"zeff_norm": voxel.g,
				"material_id": voxel.b,
				"point": p,
			}
		t += step
	return {}


## Oggetti di test correnti (per il validatore).
func get_test_objects() -> Array:
	return _objects


## material_id (canale B) risolto per un item di test.
func material_id_for_item(item: Dictionary) -> float:
	return float(voxelizer._resolve_proxy(item).material_id)


## Il laptop fra gli oggetti di test (box "misto"), o {} se assente.
func get_laptop_item() -> Dictionary:
	for item in _objects:
		if str(item.get("name", "")).begins_with("Laptop"):
			return item
	return {}


## absorption_scale corrente (mu della Beer-Lambert discreta).
func get_absorption_scale() -> float:
	return _p.absorption_scale


## Marcia un raggio verticale (lungo Y) alla colonna (x,z) e somma l'optical depth
## dei voxel del materiale richiesto: tau = sum(absorption_scale * densita' * step).
## Isola un singolo oggetto (es. il laptop "misto") ignorando gli altri materiali.
func measure_column_tau(x: float, z: float, target_material_id: float) -> float:
	var step := 1.0 / float(_grid)
	var mu: float = _p.absorption_scale
	var tau := 0.0
	var y := 0.5 * step
	while y < 1.0:
		var voxel := _sample_proxies(Vector3(x, y, z))
		if voxel.a > 0.5 and absf(voxel.b - target_material_id) < 0.1:
			tau += mu * voxel.r * step
		y += step
	return tau
