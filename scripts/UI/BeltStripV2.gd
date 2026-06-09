extends Control
class_name BeltStripV2
## BeltStripV2 (Fase 12)
##
## Striscia inferiore (80px): vista top-down del nastro. Disegna un rettangolo per
## ogni bagaglio in coda lungo una barra orizzontale, evidenzia quello in
## ispezione, e mostra a destra quanti bagagli sono stati ispezionati e il
## punteggio corrente (letti dall'autoload EvaluationLogic).
##
## Il riferimento al nastro (ConveyorController, dentro il SubViewport SCAN) e i
## suoi estremi in ascissa vengono passati da SimulatorV2.

const C_GREEN := Color("00ff41")
const C_DIM := Color(0.2, 0.4, 0.25)
const C_BAG := Color(0.0, 0.8, 0.32)
const C_CURRENT := Color(1.0, 0.82, 0.0)
const C_BG := Color(0.06, 0.06, 0.06)

var _conveyor: Node = null
var _belt_min_x := -150.0   # ascissa di spawn (scan world)
var _belt_max_x := 1550.0   # ascissa di despawn (scan world)
var _mono := SystemFont.new()


func setup(conveyor: Node, belt_min_x: float, belt_max_x: float) -> void:
	_conveyor = conveyor
	_belt_min_x = belt_min_x
	_belt_max_x = belt_max_x
	_mono.font_names = PackedStringArray(["Menlo", "Courier New", "monospace"])


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	draw_rect(Rect2(Vector2.ZERO, size), C_BG, true)

	# Binario: linea orizzontale a metà altezza, nell'area "nastro" (sinistra 70%).
	var track_w := w * 0.7
	var track_y := h * 0.5
	draw_line(Vector2(12, track_y), Vector2(track_w - 12, track_y), C_DIM, 2.0)

	if _conveyor != null and _conveyor.has_method("get_inspection_baggage"):
		var current: Node = _conveyor.get_inspection_baggage()
		var span := maxf(_belt_max_x - _belt_min_x, 1.0)
		for bag in get_tree().get_nodes_in_group("baggage"):
			if not (bag is Node2D):
				continue
			var t: float = clampf((bag.global_position.x - _belt_min_x) / span, 0.0, 1.0)
			var cx := 12.0 + t * (track_w - 24.0)
			var is_current := bag == current
			var bw := 26.0 if is_current else 20.0
			var bh := 16.0 if is_current else 12.0
			var col := C_CURRENT if is_current else C_BAG
			var r := Rect2(cx - bw * 0.5, track_y - bh * 0.5, bw, bh)
			draw_rect(r, col, true)
			draw_rect(r, col.lightened(0.3), false, 1.5)

	# Contatori a destra (30%).
	var inspected := EvaluationLogic.correct + EvaluationLogic.false_alarms + EvaluationLogic.missed_threats
	var score := EvaluationLogic.correct - EvaluationLogic.missed_threats
	var tx := w * 0.72
	var font := _mono
	draw_string(font, Vector2(tx, h * 0.42), "ISPEZIONATI: %d" % inspected,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 16, C_GREEN)
	draw_string(font, Vector2(tx, h * 0.82), "PUNTEGGIO: %d   (✓%d  ✗%d  ☠%d)" % [
		score, EvaluationLogic.correct, EvaluationLogic.false_alarms, EvaluationLogic.missed_threats
	], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, C_GREEN)
