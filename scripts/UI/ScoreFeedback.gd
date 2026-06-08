extends Control
class_name ScoreFeedback
## ScoreFeedback (Fase 6)
##
## Popup di feedback che appare per 2 secondi dopo ogni valutazione. Ascolta il
## segnale `evaluation_complete` dell'autoload EvaluationLogic e mostra esito,
## eventuale oggetto-minaccia e i contatori aggiornati.
##
## Il caso FALSE_NEGATIVE (minaccia mancata) e' il piu' critico: il testo rosso
## lampeggia 3 volte per essere impossibile da ignorare.

const DISPLAY_TIME: float = 2.0

# Mappa esito -> { testo, colore }.
const OUTCOMES := {
	"TRUE_NEGATIVE":  {"text": "✓ CLEARED",            "color": Color("00ff41")},
	"TRUE_POSITIVE":  {"text": "⚠ THREAT IDENTIFIED",  "color": Color("ffaa00")},
	"FALSE_POSITIVE": {"text": "✗ FALSE ALARM",        "color": Color("ff6600")},
	"FALSE_NEGATIVE": {"text": "☠ THREAT MISSED",      "color": Color("ff0000")},
}

@onready var _outcome: Label = %OutcomeLabel
@onready var _detail: Label = %DetailLabel
@onready var _counters: Label = %CountersLabel

var _hide_timer: Timer


func _ready() -> void:
	visible = false
	_hide_timer = Timer.new()
	_hide_timer.one_shot = true
	_hide_timer.wait_time = DISPLAY_TIME
	add_child(_hide_timer)
	_hide_timer.timeout.connect(_hide)

	EvaluationLogic.evaluation_complete.connect(_on_evaluation_complete)


func _on_evaluation_complete(outcome: String, was_threat: bool, threat_item_id: String) -> void:
	var info: Dictionary = OUTCOMES.get(outcome, {"text": outcome, "color": Color.WHITE})
	_outcome.text = info["text"]
	_outcome.add_theme_color_override("font_color", info["color"])
	_outcome.modulate.a = 1.0

	# Dettaglio oggetto-minaccia, solo se il bagaglio ne conteneva una.
	if was_threat and threat_item_id != "":
		var item: Dictionary = DataManager.get_item(threat_item_id)
		_detail.text = "OGGETTO: %s    Z_eff: %.1f" % [
			item.get("name", threat_item_id),
			float(item.get("z_eff_base", 0.0)),
		]
		_detail.visible = true
	else:
		_detail.text = ""
		_detail.visible = false

	_counters.text = "CORRETTI: %d  |  FALSI ALLARMI: %d  |  MINACCE MANCATE: %d" % [
		EvaluationLogic.correct, EvaluationLogic.false_alarms, EvaluationLogic.missed_threats,
	]

	visible = true
	if outcome == "FALSE_NEGATIVE":
		_blink_critical()
		SoundManager.play_threat_missed()
	elif outcome == "TRUE_NEGATIVE" or outcome == "TRUE_POSITIVE":
		SoundManager.play_confirm()

	_hide_timer.start()


## Lampeggia 3 volte l'esito (per FALSE_NEGATIVE), entro la finestra dei 2s.
func _blink_critical() -> void:
	var tw := create_tween()
	for i in 3:
		tw.tween_property(_outcome, "modulate:a", 0.1, 0.18)
		tw.tween_property(_outcome, "modulate:a", 1.0, 0.18)


func _hide() -> void:
	visible = false
