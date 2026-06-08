extends Node2D
class_name AICmoreOverlay
## AICmoreOverlay (Fase 6)
##
## Simula il sistema automatico iCMORE degli scanner Smiths Detection: quando
## attivo, disegna un bounding box rosso lampeggiante attorno agli oggetti
## classificati come minaccia nei bagagli sul nastro, seguendoli mentre scorrono.
##
## Affidabilita' "reale" > 95%: niente falsi positivi sintetici -> se un bagaglio
## non ha minaccia (has_threat=false) non viene disegnato nulla.
##
## Va posto SOPRA il pass colormap (Fase 2) nell'albero, cosi' i box appaiono
## sull'immagine a falsi colori. Si assume trasformazione identita' (origine
## scena): le posizioni globali dei bagagli vengono convertite con to_local().

# Periodo di lampeggio del box (s): toggle visibilita' lento.
@export var blink_interval: float = 0.5

# Colore e spessore del bounding box.
@export var box_color: Color = Color(1.0, 0.05, 0.05, 1.0)
@export var box_width: float = 3.0

# Attivato/disattivato dal pulsante iCMORE della dashboard.
var enabled: bool = false

var _blink_on: bool = true
var _blink_timer: Timer


func _ready() -> void:
	_blink_timer = Timer.new()
	_blink_timer.wait_time = blink_interval
	_blink_timer.one_shot = false
	add_child(_blink_timer)
	_blink_timer.timeout.connect(_on_blink)
	_blink_timer.start()


func _process(_delta: float) -> void:
	# Ridisegna ogni frame quando attivo: i box seguono i bagagli in movimento.
	if enabled:
		queue_redraw()


func _on_blink() -> void:
	_blink_on = not _blink_on
	if enabled:
		queue_redraw()


func _draw() -> void:
	if not enabled or not _blink_on:
		return

	for bag in get_tree().get_nodes_in_group("baggage"):
		if not bag.has_method("get_threat_global_rects"):
			continue
		if not bag.has_threat:
			continue
		for r in bag.get_threat_global_rects():
			var local := Rect2(to_local(r.position), r.size)
			# Box principale + leggero alone interno per renderlo piu' visibile.
			draw_rect(local, box_color, false, box_width)
			var inner := local.grow(-3.0)
			draw_rect(inner, Color(box_color.r, box_color.g, box_color.b, 0.25), false, 1.0)
