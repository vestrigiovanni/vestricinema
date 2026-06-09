extends Camera3D
class_name ArcBallCamera
## ArcBallCamera (Fase 9)
##
## Camera orbitale attorno al centro del volume per ispezionare il raymarch:
##   - drag tasto SINISTRO: ruota su azimuth (orizzontale) ed elevation
##     (verticale, clampata a +/-85 gradi per evitare il gimbal lock);
##   - rotella: cambia il raggio orbitale tra 1.5 e 5.0;
##   - tasto R: reset alla posizione di default con un Tween di 0.4s.
##
## La posizione della Camera3D viene RICALCOLATA ogni frame dagli angoli
## correnti (azimuth/elevation/radius), cosi' un Tween che li anima produce un
## movimento fluido senza toccare direttamente il transform.

@export var target: Vector3 = Vector3.ZERO

# Stato orbitale corrente.
@export var azimuth: float = 0.6      # rad
@export var elevation: float = 0.45   # rad
@export var radius: float = 3.0

const MIN_RADIUS := 1.5
const MAX_RADIUS := 5.0
const MAX_ELEVATION := deg_to_rad(85.0)
const ROTATE_SPEED := 0.008
const ZOOM_STEP := 0.25

# Default a cui torna il tasto R.
var _def_azimuth: float
var _def_elevation: float
var _def_radius: float

var _dragging := false
var _reset_tween: Tween

## Disabilita l'input della camera (Fase 10): durante il drag di un oggetto il
## tasto sinistro NON deve ruotare la camera. Mettendolo a false si azzera anche
## lo stato di drag in corso, cosi' la camera non "scatta" al re-enable.
var input_enabled := true:
	set(value):
		input_enabled = value
		if not value:
			_dragging = false


func _ready() -> void:
	_def_azimuth = azimuth
	_def_elevation = elevation
	_def_radius = radius
	_update_position()


func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled:
		return
	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				_dragging = event.pressed
			MOUSE_BUTTON_WHEEL_UP:
				radius = clampf(radius - ZOOM_STEP, MIN_RADIUS, MAX_RADIUS)
			MOUSE_BUTTON_WHEEL_DOWN:
				radius = clampf(radius + ZOOM_STEP, MIN_RADIUS, MAX_RADIUS)
	elif event is InputEventMouseMotion and _dragging:
		if _reset_tween and _reset_tween.is_running():
			_reset_tween.kill()
		azimuth -= event.relative.x * ROTATE_SPEED
		elevation = clampf(elevation - event.relative.y * ROTATE_SPEED, -MAX_ELEVATION, MAX_ELEVATION)
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R:
			_reset_camera()


func _process(_delta: float) -> void:
	# La posizione e' SEMPRE derivata dagli angoli correnti -> un Tween che li
	# anima si riflette automaticamente qui.
	_update_position()


func _reset_camera() -> void:
	if _reset_tween and _reset_tween.is_running():
		_reset_tween.kill()
	_reset_tween = create_tween()
	_reset_tween.set_parallel(true)
	_reset_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_reset_tween.tween_property(self, "azimuth", _def_azimuth, 0.4)
	_reset_tween.tween_property(self, "elevation", _def_elevation, 0.4)
	_reset_tween.tween_property(self, "radius", _def_radius, 0.4)


func _update_position() -> void:
	var dir := Vector3(
		cos(elevation) * sin(azimuth),
		sin(elevation),
		cos(elevation) * cos(azimuth)
	)
	global_position = target + dir * radius
	look_at(target, Vector3.UP)
