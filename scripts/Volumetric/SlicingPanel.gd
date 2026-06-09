extends Panel
## SlicingPanel (Fase 10)
##
## Pannello UI per il slicing CT: tre piani anatomici (sagittale / coronale /
## assiale) con slider verticale (offset 0..1) e toggle di abilitazione, piu' un
## RESET SLICE che riporta tutto a zero. Non conosce lo shader: emette segnali e
## VolumetricSetup li traduce nelle uniform clip_* del raymarcher.
##
## Stile industriale identico alla dashboard operatore (Fase 4): sfondo #1a1a1a,
## testo verde terminale, font monospace (definiti nel theme della scena).

signal plane_changed(axis: int, offset: float, enabled: bool)
signal reset_requested

const SAG := 0  # sagittale  -> normale (1,0,0)
const COR := 1  # coronale   -> normale (0,1,0)
const AX := 2   # assiale    -> normale (0,0,1)

@onready var _sliders := [
	$Margin/VBox/Sliders/SagCol/SagSlider,
	$Margin/VBox/Sliders/CorCol/CorSlider,
	$Margin/VBox/Sliders/AxCol/AxSlider,
]
@onready var _toggles := [
	$Margin/VBox/Toggles/SagToggle,
	$Margin/VBox/Toggles/CorToggle,
	$Margin/VBox/Toggles/AxToggle,
]
@onready var _schematics := [
	$Margin/VBox/Sliders/SagCol/SagSchem,
	$Margin/VBox/Sliders/CorCol/CorSchem,
	$Margin/VBox/Sliders/AxCol/AxSchem,
]
@onready var _reset_button: Button = $Margin/VBox/ResetButton

const LABELS := ["SAG", "COR", "AX"]


func _ready() -> void:
	for axis in 3:
		_sliders[axis].value_changed.connect(_on_slider_changed.bind(axis))
		_toggles[axis].toggled.connect(_on_toggle.bind(axis))
		_update_schematic(axis)
	_reset_button.pressed.connect(_on_reset)


func _on_slider_changed(_value: float, axis: int) -> void:
	_update_schematic(axis)
	plane_changed.emit(axis, _sliders[axis].value, _toggles[axis].button_pressed)


func _on_toggle(_pressed: bool, axis: int) -> void:
	_update_schematic(axis)
	plane_changed.emit(axis, _sliders[axis].value, _toggles[axis].button_pressed)


func _on_reset() -> void:
	for axis in 3:
		_sliders[axis].set_value_no_signal(0.0)
		_toggles[axis].set_pressed_no_signal(false)
		_update_schematic(axis)
		plane_changed.emit(axis, 0.0, false)
	reset_requested.emit()


## Indicatore schematico testuale della direzione del taglio attivo.
func _update_schematic(axis: int) -> void:
	var name: String = LABELS[axis]
	if _toggles[axis].button_pressed:
		_schematics[axis].text = "[<- %s ->]\n%.2f" % [name, _sliders[axis].value]
		_schematics[axis].add_theme_color_override("font_color", Color(0, 1, 0.2549))
	else:
		_schematics[axis].text = "[  off  ]\n----"
		_schematics[axis].add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
