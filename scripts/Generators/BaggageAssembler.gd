extends Resource
class_name BaggageAssembler
## BaggageAssembler (Fase 5 / esteso in Fase 12)
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
##
## FASE 12 — due rappresentazioni PARALLELE dello stesso bagaglio:
##   - `build()` produce la ricetta 2D (item_id, position px, rotation, scale) usata
##     dal renderer sprite della v1.0 (invariata, retro-compatibile);
##   - `to_proxy_3d()` traduce quella STESSA ricetta (eventualmente già passata per
##     il ThreatInjector) in descrittori di proxy 3D (box/sfera con dimensioni
##     fisiche in cm da `dimensions_cm` nel DataManager) pronti per la
##     voxelizzazione GPU della pipeline CT (Fasi 8-11).

# Lato fisico del volume CT in cm (carry-on ~60cm): converte cm -> spazio [0,1]^3.
const VOLUME_CM := 60.0

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


## FASE 12 — converte la ricetta 2D (output di build(), eventualmente già passata
## per il ThreatInjector) nei descrittori di proxy 3D per la voxelizzazione CT.
##
## Ogni elemento 2D { item_id, position(px), rotation, scale } diventa un proxy
## { name, category, z_eff, density, proxy:"box"/"sphere", size|radius,
##   position(Vector3 in [0,1]^3), rotation } — la forma ESPLICITA accettata da
## VoxelizerManager._resolve_proxy. Le dimensioni vengono da `dimensions_cm` nel
## DataManager, scalate in spazio volume (cm / VOLUME_CM).
##
## La posizione 2D nel piano della valigia (px, centrata) viene mappata sul piano
## XZ del volume; Y resta centrato (gli oggetti "appoggiano" a metà altezza).
func to_proxy_3d(items_2d: Array) -> Array:
	var proxies: Array = []
	# Semi-lato della valigia (px) usato per normalizzare la posizione in [0,1].
	var span_x := float(baggage_width)
	var span_y := float(baggage_height)

	for entry in items_2d:
		var item_id := String(entry.get("item_id", ""))
		var data: Dictionary = DataManager.get_item(item_id)
		if data.is_empty():
			continue

		var z_eff := float(data.get("z_eff_base", 7.0))
		var scale := float(entry.get("scale", 1.0))
		var shape := String(data.get("proxy_shape", "box"))
		var dims_cm: Array = data.get("dimensions_cm", [10, 10, 10])
		# Dimensioni piene in spazio volume [0,1] (cm / lato fisico), con la scala
		# procedurale del bagaglio.
		var size_vol := Vector3(
			float(dims_cm[0]) / VOLUME_CM,
			float(dims_cm[1]) / VOLUME_CM,
			float(dims_cm[2]) / VOLUME_CM
		) * scale

		# Posizione 2D (px, centrata sull'origine) -> piano XZ del volume, Y al centro.
		var pos2: Vector2 = entry.get("position", Vector2.ZERO)
		var center := Vector3(
			clampf(0.5 + pos2.x / span_x, 0.08, 0.92),
			0.5,
			clampf(0.5 + pos2.y / span_y, 0.08, 0.92)
		)

		# La densità (canale R del volume) cresce col numero atomico: i metalli
		# risultano più radiopachi degli organici, come nella realtà.
		var density := clampf(z_eff / 30.0, 0.12, 1.0)

		var proxy := {
			"name": String(data.get("name", item_id)),
			"category": String(data.get("category", "organic")),
			"z_eff": z_eff,
			"density": density,
			"position": center,
			"rotation": float(entry.get("rotation", 0.0)),
		}

		# La voxelizzazione GPU (voxelizer.glsl) conosce solo box e sfera: il
		# cilindro (bottiglie, cavi avvolti) viene approssimato col suo box
		# circoscritto — fedele a sufficienza per la lettura radiografica.
		if shape == "sphere":
			proxy["proxy"] = "sphere"
			proxy["radius"] = maxf(maxf(size_vol.x, size_vol.y), size_vol.z) * 0.5
		else:
			proxy["proxy"] = "box"
			proxy["size"] = size_vol

		proxies.append(proxy)

	return proxies
