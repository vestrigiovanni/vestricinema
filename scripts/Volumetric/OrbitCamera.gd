extends Camera3D
class_name OrbitCamera
## OrbitCamera (Fase 8)
##
## Camera orbitale minimale per ispezionare la nuvola di voxel:
##   - trascina col tasto sinistro per ruotare attorno al target;
##   - rotella per zoomare (avvicinarsi/allontanarsi dal target).
## Il target di default e' il centro del volume normalizzato (0.5, 0.5, 0.5).

@export var target: Vector3 = Vector3(0.5, 0.5, 0.5)
@export var distance: float = 1.8
@export var min_distance: float = 0.3
@export var max_distance: float = 6.0
@export var rotate_speed: float = 0.01
@export var zoom_step: float = 0.12

var _yaw: float = 0.7
var _pitch: float = 0.5
var _dragging := false


func _ready() -> void:
	_update_transform()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				_dragging = event.pressed
			MOUSE_BUTTON_WHEEL_UP:
				distance = clampf(distance - zoom_step, min_distance, max_distance)
				_update_transform()
			MOUSE_BUTTON_WHEEL_DOWN:
				distance = clampf(distance + zoom_step, min_distance, max_distance)
				_update_transform()
	elif event is InputEventMouseMotion and _dragging:
		_yaw -= event.relative.x * rotate_speed
		_pitch = clampf(_pitch - event.relative.y * rotate_speed, -1.4, 1.4)
		_update_transform()


func _update_transform() -> void:
	var dir := Vector3(
		cos(_pitch) * sin(_yaw),
		sin(_pitch),
		cos(_pitch) * cos(_yaw)
	)
	global_position = target + dir * distance
	look_at(target, Vector3.UP)
