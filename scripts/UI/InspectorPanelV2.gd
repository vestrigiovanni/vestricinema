extends PanelContainer
class_name InspectorPanelV2
## InspectorPanelV2 (Fase 12)
##
## Pannello controlli destro (520×900) della stazione di analisi CT v2.0. Unica
## colonna organizzata in sezioni COLLASSABILI con header cliccabile:
##   IMMAGINE — controlli shader v1.0 + Window/Level (Fase 11);
##   SLICING  — i tre piani SAG/COR/AX (Fase 10);
##   DECT     — esito dell'ultima analisi cliccata (Fase 11);
##   AZIONI   — APPROVA / RESPINGI (solo in modalità INSPECT) + iCMORE.
##
## Non conosce lo shader: emette segnali che SimulatorV2 traduce in chiamate
## all'API pubblica di VolumetricSetup / EvaluationLogic. Stile industriale
## coerente col resto del progetto (#1a1a1a, verde terminale, monospace).

signal image_param_changed(key: String, value)
signal clip_changed(axis: int, offset: float, enabled: bool)
signal reset_camera_pressed
signal approve_pressed
signal reject_pressed
signal icmore_toggled(on: bool)

const C_BG := Color("1a1a1a")
const C_PANEL := Color("121212")
const C_GREEN := Color("00ff41")
const C_DIM := Color("00ff41", 0.55)
const C_RED := Color("ff4141")

var _mono := SystemFont.new()
var _approve_btn: Button
var _reject_btn: Button
var _icmore_btn: Button
var _dect_label: RichTextLabel
var _value_labels := {}   # key -> Label (per aggiornare il testo "NOME  valore")


func _ready() -> void:
	_mono.font_names = PackedStringArray(["Menlo", "Courier New", "Consolas", "monospace"])
	custom_minimum_size = Vector2(520, 900)

	var sb := StyleBoxFlat.new()
	sb.bg_color = C_BG
	sb.set_border_width_all(1)
	sb.border_color = Color(0.2, 0.2, 0.2)
	add_theme_stylebox_override("panel", sb)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	var root := VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 10)
	scroll.add_child(root)
	root.custom_minimum_size = Vector2(496, 0)

	_build_image_section(root)
	_build_slicing_section(root)
	_build_dect_section(root)
	_build_actions_section(root)


# ----------------------------------------------------------------------------
#  Costruzione sezioni
# ----------------------------------------------------------------------------
func _add_section(parent: VBoxContainer, title: String) -> VBoxContainer:
	var header := Button.new()
	header.text = "▼  " + title
	header.alignment = HORIZONTAL_ALIGNMENT_LEFT
	header.focus_mode = Control.FOCUS_NONE
	header.add_theme_font_override("font", _mono)
	header.add_theme_font_size_override("font_size", 18)
	header.add_theme_color_override("font_color", C_GREEN)
	var hsb := StyleBoxFlat.new()
	hsb.bg_color = C_PANEL
	hsb.set_content_margin_all(8.0)
	header.add_theme_stylebox_override("normal", hsb)
	header.add_theme_stylebox_override("hover", hsb)
	header.add_theme_stylebox_override("pressed", hsb)
	header.add_theme_stylebox_override("focus", hsb)
	parent.add_child(header)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 6)
	parent.add_child(content)

	# Header cliccabile: collassa/espande il contenuto.
	header.pressed.connect(func():
		content.visible = not content.visible
		header.text = ("▼  " if content.visible else "▶  ") + title
	)
	return content


func _make_label(text: String, color: Color = C_GREEN) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", _mono)
	l.add_theme_font_size_override("font_size", 15)
	l.add_theme_color_override("font_color", color)
	return l


## Slider con label "NOME  valore". Emette image_param_changed(key, value).
func _add_slider(parent: VBoxContainer, key: String, title: String,
		mn: float, mx: float, step: float, val: float, is_int: bool = false) -> void:
	var lbl := _make_label("")
	parent.add_child(lbl)
	_value_labels[key] = {"label": lbl, "title": title, "int": is_int}

	var s := HSlider.new()
	s.min_value = mn
	s.max_value = mx
	s.step = step
	s.value = val
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(s)
	s.value_changed.connect(func(v):
		_update_value_label(key, v)
		image_param_changed.emit(key, int(v) if is_int else v)
	)
	_update_value_label(key, val)


func _update_value_label(key: String, v: float) -> void:
	var info = _value_labels.get(key)
	if info == null:
		return
	if info.int:
		info.label.text = "%-14s %d" % [info.title, int(v)]
	else:
		info.label.text = "%-14s %.2f" % [info.title, v]


func _add_toggle(parent: VBoxContainer, title: String, on_toggle: Callable) -> Button:
	var b := Button.new()
	b.toggle_mode = true
	b.text = title
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", _mono)
	b.add_theme_color_override("font_color", C_DIM)
	b.add_theme_color_override("font_pressed_color", C_GREEN)
	b.add_theme_color_override("font_hover_color", C_GREEN)
	parent.add_child(b)
	b.toggled.connect(on_toggle)
	return b


func _build_image_section(root: VBoxContainer) -> void:
	var c := _add_section(root, "IMMAGINE")
	_add_slider(c, "absorption_scale", "ASSORBIM.", 0.0, 20.0, 0.5, 6.0)
	_add_slider(c, "beam_intensity", "FASCIO", 0.0, 2.0, 0.05, 1.0)
	_add_slider(c, "max_steps", "MAX STEPS", 16, 512, 16, 256, true)
	_add_slider(c, "scatter_intensity", "SCATTER", 0.0, 1.0, 0.05, 0.3)
	_add_slider(c, "scatter_threshold", "SCAT.SOGLIA", 0.0, 1.0, 0.05, 0.4)
	_add_slider(c, "window", "WINDOW", 0.01, 1.0, 0.01, 1.0)
	_add_slider(c, "level", "LEVEL", 0.0, 1.0, 0.01, 0.5)

	var org := _add_toggle(c, "ORGANIC ONLY", func(_v): pass)
	var met := _add_toggle(c, "METAL ONLY", func(_v): pass)
	# Mutua esclusione gestita qui prima di propagare.
	org.toggled.connect(func(on):
		if on and met.button_pressed:
			met.set_pressed_no_signal(false)
		image_param_changed.emit("organic_only", on)
	)
	met.toggled.connect(func(on):
		if on and org.button_pressed:
			org.set_pressed_no_signal(false)
		image_param_changed.emit("metal_only", on)
	)
	_add_toggle(c, "INVERT B&N", func(on): image_param_changed.emit("invert", on))

	var reset := Button.new()
	reset.text = "RESET CAMERA"
	reset.focus_mode = Control.FOCUS_NONE
	reset.add_theme_font_override("font", _mono)
	reset.add_theme_color_override("font_color", C_GREEN)
	c.add_child(reset)
	reset.pressed.connect(func(): reset_camera_pressed.emit())


func _build_slicing_section(root: VBoxContainer) -> void:
	var c := _add_section(root, "SLICING")
	var axes := [["SAG", 0], ["COR", 1], ["AX", 2]]
	for a in axes:
		var name: String = a[0]
		var axis: int = a[1]
		var row := HBoxContainer.new()
		c.add_child(row)
		var toggle := Button.new()
		toggle.toggle_mode = true
		toggle.text = name
		toggle.custom_minimum_size = Vector2(70, 0)
		toggle.focus_mode = Control.FOCUS_NONE
		toggle.add_theme_font_override("font", _mono)
		toggle.add_theme_color_override("font_color", C_DIM)
		toggle.add_theme_color_override("font_pressed_color", C_GREEN)
		row.add_child(toggle)
		var slider := HSlider.new()
		slider.min_value = 0.0
		slider.max_value = 1.0
		slider.step = 0.01
		slider.value = 0.0
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(slider)
		# Entrambi emettono lo stato corrente del piano.
		var emit_plane := func():
			clip_changed.emit(axis, slider.value, toggle.button_pressed)
		slider.value_changed.connect(func(_v): emit_plane.call())
		toggle.toggled.connect(func(_on): emit_plane.call())


func _build_dect_section(root: VBoxContainer) -> void:
	var c := _add_section(root, "DECT")
	_dect_label = RichTextLabel.new()
	_dect_label.bbcode_enabled = true
	_dect_label.fit_content = true
	_dect_label.custom_minimum_size = Vector2(0, 90)
	_dect_label.add_theme_font_override("normal_font", _mono)
	_dect_label.add_theme_color_override("default_color", C_DIM)
	_dect_label.text = "Clicca un punto del volume\nper l'analisi dual-energy."
	c.add_child(_dect_label)


func _build_actions_section(root: VBoxContainer) -> void:
	var c := _add_section(root, "AZIONI")
	_approve_btn = _make_action_button("APPROVA", Color("0a3a14"), Color("0aff41"))
	c.add_child(_approve_btn)
	_approve_btn.pressed.connect(func(): approve_pressed.emit())
	_reject_btn = _make_action_button("RESPINGI", Color("3a0a0a"), Color("ff6666"))
	c.add_child(_reject_btn)
	_reject_btn.pressed.connect(func(): reject_pressed.emit())
	set_actions_enabled(false)

	_icmore_btn = _add_toggle(c, "iCMORE: OFF", func(on):
		_icmore_btn.text = "iCMORE: ON" if on else "iCMORE: OFF"
		icmore_toggled.emit(on)
	)


func _make_action_button(text: String, bg: Color, fg: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 44)
	b.add_theme_font_override("font", _mono)
	b.add_theme_font_size_override("font_size", 20)
	b.add_theme_color_override("font_color", fg)
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_content_margin_all(8.0)
	sb.set_border_width_all(1)
	sb.border_color = fg
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sb)
	b.add_theme_stylebox_override("pressed", sb)
	return b


# ----------------------------------------------------------------------------
#  API pubblica (chiamata da SimulatorV2)
# ----------------------------------------------------------------------------
func set_actions_enabled(enabled: bool) -> void:
	if _approve_btn:
		_approve_btn.disabled = not enabled
	if _reject_btn:
		_reject_btn.disabled = not enabled


func set_dect_result(info: Dictionary) -> void:
	if _dect_label == null:
		return
	_dect_label.add_theme_color_override("default_color", C_GREEN)
	_dect_label.text = "[b]%s[/b]\nz_eff stimato: %.1f\ndensità: %.1f g/cm³\nrapporto μ₈₀/μ₁₄₀: %.3f" % [
		str(info.get("label", "?")), float(info.get("zeff", 0.0)),
		float(info.get("density", 0.0)), float(info.get("ratio", 0.0))
	]
