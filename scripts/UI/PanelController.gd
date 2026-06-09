extends Control
class_name PanelController
## PanelController (Fase 4)
##
## Cervello della dashboard operatore. Traduce i segnali dei controlli laterali
## in modifiche degli `uniform` del ColorMap shader (Fase 2), aggiornando
## l'immagine X-Ray in tempo reale.
##
## Il nodo che porta il ShaderMaterial della colormap viene passato via
## `colormap_node` (NodePath). In modalita' standalone (path vuoto) i controlli
## restano funzionanti ma non hanno nulla da pilotare: il placeholder "XRAY
## VIEW" resta visibile.

# Nodo CanvasItem che porta il ShaderMaterial del pass colormap.
@export var colormap_node: NodePath

# Nastro (ConveyorController) e overlay iCMORE. Vuoti in modalita' standalone
# (es. OperatorTestScene Fase 4): in quel caso i pulsanti restano disabilitati.
@export var conveyor_node: NodePath
@export var icmore_overlay_node: NodePath

# Pausa prima del riavvio automatico del nastro dopo una valutazione (s).
const RESTART_DELAY := 2.0

# Fattore di scala pixel -> centimetri per il display velocita' nastro.
const PX_TO_CM := 0.05

# Oltre questa soglia (s) sullo stesso bagaglio il clock lampeggia in giallo.
const SLOW_INSPECTION := 30.0

# Colori terminale.
const C_GREEN := Color("00ff41")
const C_RED := Color("ff4141")
const C_YELLOW := Color("aaaa00")
const C_GREY := Color("333333")

# Riferimenti ai controlli (nomi univoci nella scena).
@onready var _zoom_slider: HSlider = %ZoomSlider
@onready var _zoom_value: Label = %ZoomValue
@onready var _brightness_slider: HSlider = %BrightnessSlider
@onready var _brightness_value: Label = %BrightnessValue
@onready var _window_slider: HSlider = %WindowSlider
@onready var _window_value: Label = %WindowValue
@onready var _level_slider: HSlider = %LevelSlider
@onready var _level_value: Label = %LevelValue
@onready var _organic_button: Button = %OrganicButton
@onready var _metal_button: Button = %MetalButton
@onready var _invert_button: Button = %InvertButton
@onready var _belt_status: Label = %BeltStatus
@onready var _belt_speed: Label = %BeltSpeed
@onready var _inspection_time: Label = %InspectionTime
@onready var _xray_placeholder: Control = %XRayPlaceholder
@onready var _approve_button: Button = %ApproveButton
@onready var _reject_button: Button = %RejectButton
@onready var _icmore_button: Button = %IcmoreButton

var _mat: ShaderMaterial
var _conveyor: Node = null
var _overlay: Node = null

# Clock di ispezione: si azzera ad ogni nuovo bagaglio sotto la testa di lettura.
var _inspection_elapsed: float = 0.0
var _tracked_baggage: Node = null


func _ready() -> void:
	_resolve_material()

	# In modalita' integrata (c'e' una vera immagine X-Ray dietro) nascondi il
	# placeholder, cosi' i due blob della Fase 2 restano visibili al centro.
	_xray_placeholder.visible = (_mat == null)

	_connect_signals()

	# Allinea shader e label allo stato iniziale dei controlli.
	_on_zoom_changed(_zoom_slider.value)
	_on_brightness_changed(_brightness_slider.value)
	_on_window_changed(_window_slider.value)
	_on_level_changed(_level_slider.value)
	_apply_material_filters()
	_on_invert_toggled(_invert_button.button_pressed)

	_setup_gameplay()


func _process(delta: float) -> void:
	_update_belt_speed()
	_update_inspection_clock(delta)


## Display velocita' nastro in cm/s (0 quando fermo).
func _update_belt_speed() -> void:
	var cm_s := 0.0
	if _conveyor != null and _conveyor.is_running:
		cm_s = _conveyor.belt_speed * PX_TO_CM
	_belt_speed.text = "%.1f cm/s" % cm_s


## Clock MM:SS sul bagaglio corrente: si azzera al cambio bagaglio e lampeggia
## in giallo oltre SLOW_INSPECTION secondi (operatore lento).
func _update_inspection_clock(delta: float) -> void:
	var current: Node = null
	if _conveyor != null:
		current = _conveyor.get_inspection_baggage()

	if current != _tracked_baggage:
		_tracked_baggage = current
		_inspection_elapsed = 0.0

	_inspection_elapsed += delta
	var total := int(_inspection_elapsed)
	_inspection_time.text = "%02d:%02d" % [total / 60, total % 60]

	if _inspection_elapsed >= SLOW_INSPECTION:
		# Lampeggio giallo a ~2Hz.
		var on := fmod(_inspection_elapsed, 0.5) < 0.25
		_inspection_time.add_theme_color_override("font_color", Color("ffcc00") if on else C_GREEN)
	else:
		_inspection_time.add_theme_color_override("font_color", C_GREEN)


## Risolve il ShaderMaterial della colormap dal NodePath esportato.
func _resolve_material() -> void:
	if colormap_node.is_empty():
		return
	var node := get_node_or_null(colormap_node) as CanvasItem
	if node != null:
		_mat = node.material as ShaderMaterial


func _connect_signals() -> void:
	_zoom_slider.value_changed.connect(_on_zoom_changed)
	_brightness_slider.value_changed.connect(_on_brightness_changed)
	_window_slider.value_changed.connect(_on_window_changed)
	_level_slider.value_changed.connect(_on_level_changed)
	_organic_button.toggled.connect(_on_organic_toggled)
	_metal_button.toggled.connect(_on_metal_toggled)
	_invert_button.toggled.connect(_on_invert_toggled)


# --- Gameplay (Fase 6): valutazione, nastro, iCMORE -------------------------

## Risolve nastro/overlay, collega i pulsanti e imposta lo stato iniziale. In
## assenza di nastro (modalita' standalone) i pulsanti restano disabilitati.
func _setup_gameplay() -> void:
	if not conveyor_node.is_empty():
		_conveyor = get_node_or_null(conveyor_node)
	if not icmore_overlay_node.is_empty():
		_overlay = get_node_or_null(icmore_overlay_node)

	_approve_button.pressed.connect(_on_approve_pressed)
	_reject_button.pressed.connect(_on_reject_pressed)
	_icmore_button.toggled.connect(_on_icmore_toggled)

	# Space non deve attivare un pulsante a fuoco: lo lasciamo arrivare al nastro.
	_approve_button.focus_mode = Control.FOCUS_NONE
	_reject_button.focus_mode = Control.FOCUS_NONE
	_icmore_button.focus_mode = Control.FOCUS_NONE

	_apply_icmore_style(false)

	if _conveyor != null:
		_conveyor.running_changed.connect(_on_belt_running_changed)
		# Allinea lo stato iniziale (il nastro parte gia' nel suo _ready).
		_on_belt_running_changed(_conveyor.is_running)
	else:
		set_belt_running(false)
		_set_decision_enabled(false)


func _on_belt_running_changed(running: bool) -> void:
	set_belt_running(running)
	# Decisione possibile solo a nastro fermo.
	_set_decision_enabled(not running)
	if running:
		EvaluationLogic.current_baggage = null
	else:
		EvaluationLogic.current_baggage = _conveyor.get_inspection_baggage()


func _set_decision_enabled(enabled: bool) -> void:
	_approve_button.disabled = not enabled
	_reject_button.disabled = not enabled


func _on_approve_pressed() -> void:
	_submit_decision("APPROVE")


func _on_reject_pressed() -> void:
	_submit_decision("REJECT")


func _submit_decision(decision: String) -> void:
	_set_decision_enabled(false)
	SoundManager.play_click()
	EvaluationLogic.evaluate(decision)
	# Riavvia il nastro (-> spawn del prossimo bagaglio) dopo la finestra di feedback.
	get_tree().create_timer(RESTART_DELAY).timeout.connect(_restart_belt)


func _restart_belt() -> void:
	if _conveyor != null:
		_conveyor.start()


func _on_icmore_toggled(pressed: bool) -> void:
	if _overlay != null:
		_overlay.enabled = pressed
	_apply_icmore_style(pressed)


## Bordo giallo quando iCMORE e' attivo, grigio quando spento.
func _apply_icmore_style(active: bool) -> void:
	_icmore_button.text = "iCMORE: ON" if active else "iCMORE: OFF"
	var border := C_YELLOW if active else C_GREY
	for state in ["normal", "hover", "pressed", "focus"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.12, 0.12, 0.12, 1.0)
		sb.set_border_width_all(2)
		sb.border_color = border
		sb.content_margin_left = 10.0
		sb.content_margin_right = 10.0
		sb.content_margin_top = 7.0
		sb.content_margin_bottom = 7.0
		_icmore_button.add_theme_stylebox_override(state, sb)
	_icmore_button.add_theme_color_override("font_color", C_YELLOW if active else Color(0.53, 0.53, 0.53, 1.0))


# --- Handler dei controlli ---------------------------------------------------

func _on_zoom_changed(value: float) -> void:
	_zoom_value.text = "ZOOM        %.1fx" % value
	if _mat != null:
		_mat.set_shader_parameter("zoom_level", value)


func _on_brightness_changed(value: float) -> void:
	_brightness_value.text = "BRIGHTNESS  %.2f" % value
	if _mat != null:
		_mat.set_shader_parameter("beam_intensity", value)


func _on_window_changed(value: float) -> void:
	_window_value.text = "WINDOW      %.2f" % value
	if _mat != null:
		_mat.set_shader_parameter("window", value)


func _on_level_changed(value: float) -> void:
	_level_value.text = "LEVEL       %.2f" % value
	if _mat != null:
		_mat.set_shader_parameter("level", value)


func _on_organic_toggled(pressed: bool) -> void:
	# Mutua esclusione: attivare ORGANIC spegne METAL (senza ri-emettere segnale).
	if pressed:
		_metal_button.set_pressed_no_signal(false)
	_apply_material_filters()


func _on_metal_toggled(pressed: bool) -> void:
	if pressed:
		_organic_button.set_pressed_no_signal(false)
	_apply_material_filters()


func _on_invert_toggled(pressed: bool) -> void:
	if _mat != null:
		_mat.set_shader_parameter("invert_image", pressed)


## Spinge lo stato corrente dei due toggle materiale verso lo shader.
func _apply_material_filters() -> void:
	if _mat == null:
		return
	_mat.set_shader_parameter("enable_organic_only", _organic_button.button_pressed)
	_mat.set_shader_parameter("enable_metal_only", _metal_button.button_pressed)


# --- API pubblica (usata in seguito dall'integrazione col nastro) ------------

## Aggiorna l'indicatore di stato del nastro in alto.
func set_belt_running(running: bool) -> void:
	if running:
		_belt_status.text = "BELT: RUNNING"
		_belt_status.add_theme_color_override("font_color", C_GREEN)
	else:
		_belt_status.text = "BELT: STOPPED"
		_belt_status.add_theme_color_override("font_color", C_RED)
