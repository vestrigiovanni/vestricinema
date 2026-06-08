extends Resource
class_name ThreatInjector
## ThreatInjector (Fase 5 - Threat Image Projection)
##
## Decide se un bagaglio deve contenere una minaccia e, in caso affermativo,
## SCAMBIA uno degli oggetti gia' posizionati dal BaggageAssembler con un oggetto
## marcato `is_threat = true` nel database. Lo scambio (invece dell'aggiunta)
## mantiene coerente il numero totale di oggetti e riusa posizione/rotazione/scala
## gia' generate, cosi' la minaccia si "mimetizza" tra gli altri oggetti.
##
## Lo stato dell'ultima iniezione (`current_baggage_has_threat`, `threat_item_id`)
## viene letto dalla logica di valutazione della Fase 6.

# Probabilita' che un bagaglio contenga una minaccia (0..1).
@export_range(0.0, 1.0) var threat_probability: float = 0.3

# Esito dell'ultima chiamata a inject() - letto dalla Fase 6.
var current_baggage_has_threat: bool = false
var threat_item_id: String = ""


## Prende l'output del BaggageAssembler e, con probabilita' threat_probability,
## sostituisce un oggetto a caso con una minaccia. Restituisce l'array (modificato
## in-place se c'e' minaccia, invariato altrimenti).
func inject(baggage_data: Array) -> Array:
	current_baggage_has_threat = false
	threat_item_id = ""

	if baggage_data.is_empty():
		return baggage_data

	# Tiro di dado: la maggior parte dei bagagli e' pulita.
	if randf() > threat_probability:
		return baggage_data

	var threat_ids: Array = _gather_threat_ids()
	if threat_ids.is_empty():
		push_warning("ThreatInjector: nessun oggetto con is_threat=true nel database.")
		return baggage_data

	var chosen: String = String(threat_ids[randi() % threat_ids.size()])
	var idx: int = randi() % baggage_data.size()

	# Scambio: conserva position/rotation/scale, cambia solo l'item_id.
	baggage_data[idx]["item_id"] = chosen

	current_baggage_has_threat = true
	threat_item_id = chosen
	print("[ThreatInjector] Bagaglio con minaccia: %s" % chosen)

	return baggage_data


## Raccoglie gli id di tutti gli oggetti marcati come minaccia nel DataManager.
func _gather_threat_ids() -> Array:
	var out: Array = []
	for id in DataManager.items:
		var item: Dictionary = DataManager.items[id]
		if item.get("is_threat", false):
			out.append(id)
	return out
