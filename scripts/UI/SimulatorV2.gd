extends Control
## SimulatorV2 (Fase 12) — controller della scena principale v2.0.
##
## Orchestra l'intero flusso operatore unendo Fasi 1-11:
##   - modalità SCAN: il nastro scorre, vista 2D X-Ray laterale (renderer v1.0);
##   - SPACE: ferma il nastro e transita (fade 2D->3D) alla stazione di analisi CT;
##   - modalità INSPECT: volume CT 3D con ArcBall/slicing/picking/DECT/Window-Level;
##   - APPROVA/RESPINGI: valuta (EvaluationLogic v1.0), mostra il feedback, e dopo
##     una pausa torna a SCAN riavviando il nastro.
##
## La transizione NON è un cambio di scena: due SubViewport sovrapposti (SCAN 2D /
## INSPECT 3D) che fanno fade in/out. La voxelizzazione gira in parte su Thread
## (VolumetricSetup.load_baggage) mentre una schermata "ANALISI CT IN CORSO..."
## copre i ~100ms di attesa.

const PX_TO_CM := 0.05          # come PanelController v1.0
const RESTART_DELAY := 2.0      # pausa feedback prima del ritorno a SCAN
const FADE := 0.3               # durata fade out/in (s)

const C_GREEN := Color("00ff41")
const C_RED := Color("ff4141")

@onready var _scan_container: SubViewportContainer = $Central/ScanContainer
@onready var _inspect_container: SubViewportContainer = $Central/InspectContainer
@onready var _conveyor: ConveyorController = $Central/ScanContainer/ScanViewport/Conveyor
@onready var _icmore: Node = $Central/ScanContainer/ScanViewport/AICmoreOverlay
@onready var _inspect = $Central/InspectContainer/InspectViewport/InspectView
@onready var _loading: Control = $LoadingScreen
@onready var _loading_label: Label = $LoadingScreen/Center/Label
@onready var _panel = $UILayer/InspectorPanel
@onready var _belt_strip = $UILayer/BeltStrip
@onready var _belt_status: Label = %BeltStatus
@onready var _belt_speed: Label = %BeltSpeed
@onready var _insp_time: Label = %InspectionTime
@onready var _clock: Label = %Clock

# Estremi del nastro nello spazio del SubViewport SCAN (per la striscia inferiore).
const BELT_MIN_X := -150.0
const BELT_MAX_X := 1550.0

var _mode := "SCAN"
var _transitioning := false
var _awaiting_load := false
var _loading_active := false
var _loading_t := 0.0
var _inspection_elapsed := 0.0
var _tracked_baggage: Node = null


func _ready() -> void:
	# Stato iniziale: SCAN visibile, INSPECT spento.
	_inspect_container.visible = false
	_inspect_container.modulate.a = 0.0
	_scan_container.modulate.a = 1.0
	_loading.visible = false

	_belt_strip.setup(_conveyor, BELT_MIN_X, BELT_MAX_X)

	# Wiring pannello -> stazione CT.
	_panel.image_param_changed.connect(_inspect.set_image_param)
	_panel.clip_changed.connect(_inspect.set_clip)
	_panel.reset_camera_pressed.connect(_inspect.reset_camera)
	_panel.approve_pressed.connect(func(): _decide("APPROVE"))
	_panel.reject_pressed.connect(func(): _decide("REJECT"))
	_panel.icmore_toggled.connect(func(on): _icmore.enabled = on)
	_panel.set_actions_enabled(false)

	# Stazione CT -> pannello / monitor.
	_inspect.dect_result.connect(_panel.set_dect_result)
	_inspect.load_finished.connect(_on_inspect_loaded)
	_inspect.lod_changed.connect(func(t): PerformanceMonitor.set_lod_text(t))

	print("[SimulatorV2] v2.0 pronta. SCAN attivo — SPACE per analisi CT.")


func _process(delta: float) -> void:
	_update_header(delta)
	if _loading_active:
		_loading_t += delta
		var dots := ".".repeat(1 + (int(_loading_t * 3.0) % 3))
		_loading_label.text = "ANALISI CT IN CORSO" + dots


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE:
		if _mode == "SCAN" and not _transitioning:
			_enter_inspect()


# ----------------------------------------------------------------------------
#  Transizione SCAN -> INSPECT
# ----------------------------------------------------------------------------
func _enter_inspect() -> void:
	var bag := _conveyor.get_inspection_baggage()
	if bag == null:
		return  # niente sotto la testa di lettura: ignora

	_transitioning = true
	_conveyor.stop()
	EvaluationLogic.current_baggage = bag
	_panel.set_actions_enabled(false)

	# Fade out del 2D, poi voxelizzazione in background.
	var tw := create_tween()
	tw.tween_property(_scan_container, "modulate:a", 0.0, FADE)
	tw.tween_callback(_begin_voxelize.bind(bag))


func _begin_voxelize(bag: Node) -> void:
	_scan_container.visible = false
	_show_loading(true)
	# Ricostruisce gli stessi oggetti del bagaglio in proxy 3D e li voxelizza.
	var proxies: Array = _conveyor.assembler.to_proxy_3d(bag.contents)
	_awaiting_load = true
	_inspect.load_baggage(proxies)  # async: emette load_finished


func _on_inspect_loaded() -> void:
	if not _awaiting_load:
		return
	_awaiting_load = false
	_show_loading(false)
	_inspect.reset_camera()
	_inspect_container.visible = true
	_inspect_container.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_inspect_container, "modulate:a", 1.0, FADE)
	tw.tween_callback(func():
		_mode = "INSPECT"
		_transitioning = false
		_panel.set_actions_enabled(true)
	)


# ----------------------------------------------------------------------------
#  Decisione -> feedback -> ritorno a SCAN
# ----------------------------------------------------------------------------
func _decide(decision: String) -> void:
	if _mode != "INSPECT" or _transitioning:
		return
	_transitioning = true
	_panel.set_actions_enabled(false)
	SoundManager.play_click()
	EvaluationLogic.evaluate(decision)  # -> ScoreFeedback popup (v1.0)
	get_tree().create_timer(RESTART_DELAY).timeout.connect(_return_to_scan, CONNECT_ONE_SHOT)


func _return_to_scan() -> void:
	var tw := create_tween()
	tw.tween_property(_inspect_container, "modulate:a", 0.0, FADE)
	tw.tween_callback(func():
		_inspect_container.visible = false
		_scan_container.visible = true
		_scan_container.modulate.a = 0.0
	)
	tw.tween_property(_scan_container, "modulate:a", 1.0, FADE)
	tw.tween_callback(func():
		_mode = "SCAN"
		_transitioning = false
		_conveyor.start()  # riprende lo scorrimento e lo spawn
	)


# ----------------------------------------------------------------------------
#  Loading screen industriale
# ----------------------------------------------------------------------------
func _show_loading(on: bool) -> void:
	_loading.visible = on
	_loading_active = on
	_loading_t = 0.0
	if on:
		_loading_label.text = "ANALISI CT IN CORSO"


# ----------------------------------------------------------------------------
#  Header (striscia superiore) — stato nastro / velocità / timer / orologio
# ----------------------------------------------------------------------------
func _update_header(delta: float) -> void:
	var running: bool = _conveyor.is_running
	_belt_status.text = "BELT: RUNNING" if running else "BELT: STOPPED"
	_belt_status.add_theme_color_override("font_color", C_GREEN if running else C_RED)

	var cm_s := _conveyor.belt_speed * PX_TO_CM if running else 0.0
	_belt_speed.text = "%.1f cm/s" % cm_s

	# Timer ispezione: si azzera al cambio del bagaglio sotto la testa di lettura.
	var current := _conveyor.get_inspection_baggage()
	if current != _tracked_baggage:
		_tracked_baggage = current
		_inspection_elapsed = 0.0
	_inspection_elapsed += delta
	var total := int(_inspection_elapsed)
	_insp_time.text = "T+%02d:%02d" % [total / 60, total % 60]

	_clock.text = Time.get_time_string_from_system()
