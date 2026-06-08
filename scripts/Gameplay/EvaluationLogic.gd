extends Node
## EvaluationLogic (Autoload singleton - Fase 6)
##
## Chiude il ciclo di feedback dell'operatore: confronta la decisione
## (APPROVE / REJECT) con la verita' di base del bagaglio sotto ispezione
## (has_threat, valorizzato dal ThreatInjector in Fase 5) e classifica l'esito
## nella matrice di confusione tipica dello screening:
##
##   APPROVE + nessuna minaccia -> TRUE_NEGATIVE  (corretto: cleared)
##   REJECT  + minaccia         -> TRUE_POSITIVE  (corretto: minaccia identificata)
##   REJECT  + nessuna minaccia -> FALSE_POSITIVE (falso allarme)
##   APPROVE + minaccia         -> FALSE_NEGATIVE (minaccia mancata - il piu' grave)
##
## La UI (ScoreFeedback) ascolta `evaluation_complete` per mostrare il popup.

signal evaluation_complete(outcome: String, was_threat: bool, threat_item_id: String)

# Bagaglio attualmente sotto ispezione (impostato dal PanelController quando il
# nastro si ferma). Letto in evaluate().
var current_baggage: Node = null

# Contatori globali di sessione.
var correct: int = 0
var false_alarms: int = 0
var missed_threats: int = 0


## Valuta la decisione dell'operatore sul bagaglio corrente.
## `decision` deve essere "APPROVE" o "REJECT".
func evaluate(decision: String) -> void:
	var was_threat: bool = false
	var threat_id: String = ""
	if is_instance_valid(current_baggage):
		was_threat = current_baggage.has_threat
		threat_id = current_baggage.threat_item_id

	var outcome: String = ""
	if decision == "REJECT" and was_threat:
		outcome = "TRUE_POSITIVE"
		correct += 1
	elif decision == "APPROVE" and not was_threat:
		outcome = "TRUE_NEGATIVE"
		correct += 1
	elif decision == "REJECT" and not was_threat:
		outcome = "FALSE_POSITIVE"
		false_alarms += 1
	else: # APPROVE + minaccia
		outcome = "FALSE_NEGATIVE"
		missed_threats += 1

	print("[EvaluationLogic] decision=%s threat=%s -> %s  (CORRETTI:%d FALSI:%d MANCATE:%d)" % [
		decision, str(was_threat), outcome, correct, false_alarms, missed_threats,
	])

	evaluation_complete.emit(outcome, was_threat, threat_id)


## Azzera i contatori di sessione (utile per future schermate di riepilogo).
func reset_counters() -> void:
	correct = 0
	false_alarms = 0
	missed_threats = 0
