extends Node
## ObjectDragger (Fase 10)
##
## Gestisce selezione e trascinamento 3D degli oggetti del bagaglio dentro il
## raymarcher. Tutta la geometria/voxelizzazione vive nell'host (VolumetricSetup):
## qui sta SOLO la macchina a stati dell'input.
##
## Flusso:
##   - click sinistro -> ray picking (host.pick_object). Se colpisce un oggetto:
##     selezione + highlight, si DISABILITA l'input dell'ArcBallCamera ed entra in
##     modalita' drag. Se NON colpisce nulla: deseleziona e lascia ruotare la
##     camera (drag sfondo = orbita).
##   - drag del mouse -> trasla l'oggetto su un piano parallelo alla camera
##     (profondita' invariata).
##   - scroll durante il drag -> cambia la profondita' lungo l'asse di vista.
##   - rilascio -> ri-voxelizza SOLO la regione modificata (host.commit_object_move)
##     e riabilita la camera.

const DEPTH_STEP := 0.04  # passo profondita' per tacca di scroll (unita' mondo)

var _host                       # VolumetricSetup
var _camera: Camera3D           # e' anche l'ArcBallCamera (stesso nodo)

var _selected := -1
var _dragging := false
var _drag_plane: Plane
var _grab_offset := Vector3.ZERO
var _start_center_vol := Vector3.ZERO


func setup(host, camera: Camera3D) -> void:
	_host = host
	_camera = camera
	set_process_unhandled_input(true)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_on_press(event.position)
			else:
				_on_release()
		elif _dragging and event.pressed:
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				_on_scroll(1.0)
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_on_scroll(-1.0)
	elif event is InputEventMouseMotion and _dragging:
		_on_motion(event.position)


func _on_press(screen_pos: Vector2) -> void:
	var idx: int = _host.pick_object(screen_pos)
	if idx < 0:
		# Sfondo: nessun oggetto -> deseleziona, la camera potra' orbitare.
		_selected = -1
		_host.clear_selection()
		return

	_selected = idx
	_host.highlight_object(idx)

	# Entra in drag: blocca la rotazione camera finche' non rilascio.
	_camera.input_enabled = false
	_dragging = true
	_start_center_vol = _host.get_object_center_vol(idx)

	var center: Vector3 = _host.get_object_world_center(idx)
	# Piano parallelo all'immagine (normale = direzione di vista) per il centro.
	var view_dir: Vector3 = -_camera.global_transform.basis.z.normalized()
	_drag_plane = Plane(view_dir, view_dir.dot(center))
	var hit = _project_to_plane(screen_pos)
	_grab_offset = (hit - center) if hit != null else Vector3.ZERO
	_update_label()


func _on_motion(screen_pos: Vector2) -> void:
	if _selected < 0:
		return
	var hit = _project_to_plane(screen_pos)
	if hit == null:
		return
	_host.set_object_world_center(_selected, hit - _grab_offset)
	_update_label()


func _on_scroll(dir: float) -> void:
	if _selected < 0:
		return
	var view_dir: Vector3 = -_camera.global_transform.basis.z.normalized()
	var center: Vector3 = _host.get_object_world_center(_selected) + view_dir * (DEPTH_STEP * dir)
	_host.set_object_world_center(_selected, center)
	# La profondita' e' cambiata: sposta il piano di drag al nuovo centro.
	_drag_plane = Plane(view_dir, view_dir.dot(_host.get_object_world_center(_selected)))
	_update_label()


func _on_release() -> void:
	if not _dragging:
		return
	_dragging = false
	_camera.input_enabled = true
	_host.commit_object_move(_selected, _start_center_vol)
	_host.hide_drag_label()


func _project_to_plane(screen_pos: Vector2):
	var o := _camera.project_ray_origin(screen_pos)
	var d := _camera.project_ray_normal(screen_pos)
	return _drag_plane.intersects_ray(o, d)


func _update_label() -> void:
	var cm: Vector3 = _host.object_center_cm(_selected)
	_host.set_drag_label("X: %.1fcm  Y: %.1fcm  Z: %.1fcm" % [cm.x, cm.y, cm.z])
