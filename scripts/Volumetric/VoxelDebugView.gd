extends Node3D
## VoxelDebugView (Fase 8)
##
## Scena di debug per validare la correttezza GEOMETRICA della voxelizzazione
## prima di costruire il raymarcher (Fase 9). Legge la Texture3D prodotta dal
## VoxelizerManager, ricostruisce a CPU una nuvola di punti colorati per
## material_id e permette di:
##   - ispezionare il volume con una camera orbitale;
##   - isolare una "fetta" lungo Z con lo slider SLICE Z;
##   - rigenerare la voxelizzazione (verifica stabilita' del conteggio).

# preload (anziche' class_name) cosi' il riferimento non dipende dal global
# class cache: la scena F6 parte anche su un progetto appena clonato.
const VoxelizerManager := preload("res://scripts/Volumetric/VoxelizerManager.gd")

const GRID := VoxelizerManager.GRID
const TOTAL_VOXELS := GRID * GRID * GRID  # 2_097_152
const BYTES_PER_VOXEL := 8                # RGBA half (4 * 2 byte)
const SLICE_THICKNESS := 8                # spessore della fetta SLICE Z

# Palette coerente con le Fasi 2-4 (xray_colormap.gdshader).
const COLOR_ORGANIC := Color(0.95, 0.55, 0.15)  # arancione
const COLOR_MIXED := Color(0.25, 0.75, 0.30)     # verde
const COLOR_METAL := Color(0.10, 0.45, 0.80)     # blu

@onready var voxelizer: VoxelizerManager = $Voxelizer
@onready var cloud: MeshInstance3D = $VoxelCloud
@onready var info_label: Label = $UI/InfoLabel
@onready var slice_slider: HSlider = $UI/SliceSlider
@onready var regen_button: Button = $UI/RegenButton

var _mesh := ImmediateMesh.new()
var _point_material := StandardMaterial3D.new()


func _ready() -> void:
	_point_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_point_material.vertex_color_use_as_albedo = true
	_point_material.use_point_size = true
	_point_material.point_size = 3.0
	cloud.mesh = _mesh
	cloud.material_override = _point_material

	slice_slider.value_changed.connect(_on_slice_changed)
	regen_button.pressed.connect(_on_regenerate_pressed)

	_regenerate()


## Bagaglio di test hardcoded (3 oggetti) — vedi specifica Fase 8.
func _test_baggage() -> Array:
	return [
		{   # 1) Laptop: box "misto" (verde), al centro del volume.
			"category": "electronics", "z_eff": 14.0, "density": 0.6,
			"proxy": "box", "size": Vector3(0.35, 0.03, 0.25),
			"position": Vector3(0.5, 0.5, 0.5),
		},
		{   # 2) Bottiglia: sfera "organica" (arancione), sovrapposta al laptop.
			"category": "organic", "z_eff": 7.4, "density": 0.4,
			"proxy": "sphere", "radius": 0.08,
			"position": Vector3(0.35, 0.55, 0.5),
		},
		{   # 3) Chiave inglese: box "metallo" (blu), sul laptop, angolata 30°.
			"category": "metal", "z_eff": 26.0, "density": 0.9,
			"proxy": "box", "size": Vector3(0.18, 0.02, 0.03),
			"position": Vector3(0.6, 0.52, 0.48), "rotation": deg_to_rad(30.0),
		},
	]


func _regenerate() -> void:
	voxelizer.voxelize_baggage(_test_baggage())
	_rebuild_cloud()
	_update_label()


func _on_regenerate_pressed() -> void:
	_regenerate()


func _on_slice_changed(_value: float) -> void:
	_rebuild_cloud()
	_update_label()


## Ricostruisce la nuvola di punti. Con SLICE Z = 0 mostra l'INTERO volume (i tre
## blob); con SLICE Z > 0 isola la fetta [slice_z, slice_z + 8] per ispezionarla.
func _rebuild_cloud() -> void:
	_mesh.clear_surfaces()
	var data := voxelizer.last_volume_data
	if data.size() < TOTAL_VOXELS * BYTES_PER_VOXEL:
		return

	var slice_z := int(slice_slider.value)
	var z_start := 0
	var z_end := GRID
	if slice_z > 0:
		z_start = slice_z
		z_end = mini(slice_z + SLICE_THICKNESS, GRID)

	var colors := PackedColorArray()
	var verts := PackedVector3Array()
	var inv_grid := 1.0 / float(GRID)
	for z in range(z_start, z_end):
		for y in GRID:
			for x in GRID:
				var idx := ((z * GRID + y) * GRID + x) * BYTES_PER_VOXEL
				# Canale A (occupancy) e' il 4° half -> offset +6.
				if data.decode_half(idx + 6) <= 0.5:
					continue
				var material_id := data.decode_half(idx + 4)  # canale B
				colors.append(_color_for_material(material_id))
				verts.append(Vector3(x, y, z) * inv_grid)

	# surface_end() fallisce se non c'e' alcun vertice (fetta vuota): la saltiamo.
	if verts.is_empty():
		return
	_mesh.surface_begin(Mesh.PRIMITIVE_POINTS)
	for i in verts.size():
		_mesh.surface_set_color(colors[i])
		_mesh.surface_add_vertex(verts[i])
	_mesh.surface_end()


func _color_for_material(material_id: float) -> Color:
	if material_id < 0.25:
		return COLOR_ORGANIC
	elif material_id < 0.75:
		return COLOR_MIXED
	return COLOR_METAL


func _update_label() -> void:
	var occupied := voxelizer.last_occupied_count
	var pct := 100.0 * float(occupied) / float(TOTAL_VOXELS)
	info_label.text = "Voxel occupati: %d / %d (%.3f%%) — Tempo: %.2fms" % [
		occupied, TOTAL_VOXELS, pct, voxelizer.last_time_ms
	]
