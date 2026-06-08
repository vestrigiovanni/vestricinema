extends Node2D
## TestAsset (temporaneo, solo per Fase 2)
##
## Genera proceduralmente le due texture di dati che lo shader a raggi X si
## aspetta, cosi' possiamo validare la pipeline senza asset definitivi:
##   - depth map  : scala di grigi = spessore attraversato (cupola sferica),
##                  con alpha = sagoma dell'oggetto.
##   - material map: colore pieno (R=organico, G=misto, B=metallo) = proporzioni.
##
## Ogni asset riceve una ShaderMaterial PROPRIA (creata a runtime) cosi' i
## parametri di un oggetto non si propagano agli altri.

const ABSORPTION_SHADER: Shader = preload("res://shaders/xray_absorption.gdshader")
const TEX_SIZE := 192

# Proporzioni di materiale (vengono normalizzate). Cambiale per virare il colore:
#   organico -> arancione, misto -> verde, metallo -> blu.
@export_range(0.0, 1.0) var organic_fraction := 1.0
@export_range(0.0, 1.0) var mixed_fraction := 0.0
@export_range(0.0, 1.0) var metal_fraction := 0.0

# Raggio a schermo (px) e densita' (piu' densa = piu' scura).
@export var radius := 130.0
@export_range(0.0, 4.0) var density := 1.0

@onready var sprite: Sprite2D = $Sprite


func _ready() -> void:
	add_to_group("xray_object")

	var fractions := _normalized_fractions()

	# Materiale shader dedicato a questo oggetto.
	var mat := ShaderMaterial.new()
	mat.shader = ABSORPTION_SHADER
	mat.set_shader_parameter("material_map", _make_material_texture(fractions))
	mat.set_shader_parameter("density", density)

	sprite.material = mat
	sprite.texture = _make_depth_texture()
	# Scala lo sprite per ottenere il raggio richiesto a schermo.
	var s := (2.0 * radius) / float(TEX_SIZE)
	sprite.scale = Vector2(s, s)


## Normalizza le proporzioni di materiale a somma 1 (fallback: tutto organico).
func _normalized_fractions() -> Vector3:
	var v := Vector3(organic_fraction, mixed_fraction, metal_fraction)
	var sum := v.x + v.y + v.z
	if sum <= 0.0:
		return Vector3(1.0, 0.0, 0.0)
	return v / sum


## Depth map: cupola sferica (spessore max al centro) con bordo morbido.
func _make_depth_texture() -> ImageTexture:
	var img := Image.create(TEX_SIZE, TEX_SIZE, false, Image.FORMAT_RGBA8)
	var center := float(TEX_SIZE) * 0.5
	var radius_px := center
	for y in TEX_SIZE:
		for x in TEX_SIZE:
			var dx := (float(x) + 0.5 - center) / radius_px
			var dy := (float(y) + 0.5 - center) / radius_px
			var d := sqrt(dx * dx + dy * dy) # 0 al centro .. 1 al bordo
			var thickness := 0.0
			if d < 1.0:
				thickness = sqrt(1.0 - d * d) # profilo di una sfera
			var alpha := 1.0 - smoothstep(0.96, 1.0, d)
			img.set_pixel(x, y, Color(thickness, thickness, thickness, alpha))
	return ImageTexture.create_from_image(img)


## Material map: colore pieno con le proporzioni nei canali RGB.
func _make_material_texture(fractions: Vector3) -> ImageTexture:
	var img := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	img.fill(Color(fractions.x, fractions.y, fractions.z, 1.0))
	return ImageTexture.create_from_image(img)
