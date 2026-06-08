extends CanvasLayer
## PerformanceMonitor (Autoload - Fase 7)
##
## Overlay diagnostico attivabile con F3, SOLO nelle build di debug (in export
## release si auto-disabilita). Mostra in alto a sinistra:
##   - FPS correnti
##   - numero totale di nodi attivi nella scena
##   - memoria statica usata (OS.get_static_memory_usage)
##   - numero di BaggageContainer attivi (gruppo "baggage")
##
## Serve a confermare che il conteggio nodi non cresca dopo molti bagagli
## ispezionati: prova visiva che queue_free() libera correttamente la memoria.

var _label: Label
var _enabled: bool = false


func _ready() -> void:
	layer = 128 # sopra tutto

	var panel := PanelContainer.new()
	panel.position = Vector2(12, 12)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.0, 0.0, 0.0, 0.55)
	sb.set_content_margin_all(10.0)
	sb.set_border_width_all(1)
	sb.border_color = Color(0.0, 1.0, 0.16, 0.6)
	panel.add_theme_stylebox_override("panel", sb)
	add_child(panel)

	_label = Label.new()
	_label.add_theme_color_override("font_color", Color(0.0, 1.0, 0.16, 1.0))
	_label.add_theme_font_size_override("font_size", 16)
	var mono := SystemFont.new()
	mono.font_names = PackedStringArray(["Menlo", "Courier New", "monospace"])
	_label.add_theme_font_override("font", mono)
	panel.add_child(_label)

	visible = false

	# Inerte fuori dalle build di debug (non compare nell'.app esportato).
	if not OS.is_debug_build():
		set_process(false)
		set_process_input(false)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F3:
			_enabled = not _enabled
			visible = _enabled


func _process(_delta: float) -> void:
	if not _enabled:
		return
	var tree := get_tree()
	var baggage := tree.get_nodes_in_group("baggage").size()
	var mem_mb := OS.get_static_memory_usage() / (1024.0 * 1024.0)
	_label.text = "FPS:      %d\nNODI:     %d\nMEM:      %.1f MB\nBAGAGLI:  %d" % [
		Engine.get_frames_per_second(),
		tree.get_node_count(),
		mem_mb,
		baggage,
	]
