extends Resource
class_name BaggageAssembler
## BaggageAssembler (Fase 5)
##
## Costruisce la "ricetta" di un bagaglio procedurale: un Array di dizionari che
## descrive quali oggetti mettere nella valigia e dove. NON crea nodi: produce
## solo dati, che il BaggageContainer trasformera' poi in TestAsset visibili.
##
## E' una Resource (non un nodo) cosi' i parametri sono editabili da Inspector
## ed e' riusabile/condivisibile tra piu' nastri.
##
## Le posizioni sono in coordinate LOCALI della valigia, CENTRATE sull'origine
## (0,0 = centro del bagaglio). Il containment garantisce che il centro di ogni
## oggetto resti dentro il rettangolo con un margine, cosi' nessun oggetto finisce
## a cavallo del bordo.

# Numero di oggetti per bagaglio (estremi inclusi).
@export var min_items: int = 4
@export var max_items: int = 12

# Dimensioni del rettangolo interno della valigia (px).
@export var baggage_width: int = 280
@export var baggage_height: int = 180

# Margine dai bordi entro cui deve stare il CENTRO di ogni oggetto (px).
@export var margin: int = 30

# Variazione di scala per varieta' visiva (1.0 +/- 20%).
@export var min_scale: float = 0.8
@export var max_scale: float = 1.2

# Rotazione casuale massima in gradi (+/-).
@export var max_rotation_deg: float = 45.0


## Genera la lista di oggetti del bagaglio.
## Restituisce un Array di Dictionary { item_id, position, rotation, scale }.
func build() -> Array:
	var result: Array = []

	# Pesca SOLO oggetti innocui: le minacce sono esclusivamente di competenza
	# del ThreatInjector (Fase 5/6), cosi' has_threat resta l'unica fonte di
	# verita' e l'oggetto-minaccia e' identificabile in modo univoco (iCMORE).
	var ids: Array = []
	for id in DataManager.items:
		if not DataManager.items[id].get("is_threat", false):
			ids.append(id)
	if ids.is_empty():
		push_warning("BaggageAssembler: nessun oggetto innocuo nel DataManager, bagaglio vuoto.")
		return result

	var count: int = randi_range(min_items, max_items)

	# Semi-estensioni entro cui puo' stare il centro di un oggetto.
	var half_w: float = float(baggage_width) * 0.5 - float(margin)
	var half_h: float = float(baggage_height) * 0.5 - float(margin)
	half_w = maxf(half_w, 0.0)
	half_h = maxf(half_h, 0.0)

	for i in count:
		# Selezione con ripetizione: con pochi oggetti nel DB un bagaglio puo'
		# contenerne due uguali (perfettamente realistico).
		var item_id: String = String(ids[randi() % ids.size()])
		result.append({
			"item_id": item_id,
			"position": Vector2(randf_range(-half_w, half_w), randf_range(-half_h, half_h)),
			"rotation": deg_to_rad(randf_range(-max_rotation_deg, max_rotation_deg)),
			"scale": randf_range(min_scale, max_scale),
		})

	return result
