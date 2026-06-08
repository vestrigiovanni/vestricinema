extends Node2D
class_name BaggageContainer
## BaggageContainer (Fase 5)
##
## Contenitore di una singola valigia sul nastro. Riceve dal generatore una lista
## di oggetti (output di BaggageAssembler + ThreatInjector) e la trasforma in
## TestAsset visibili: per ogni oggetto legge `z_eff_base` dal DataManager via
## `item_id` e ne ricava le proporzioni di materiale (organico/misto/metallo) che
## lo shader di assorbimento (Fase 2) usa per il falso colore.
##
## Si registra nel gruppo "baggage" cosi' il ConveyorController puo' trascinarlo
## e distruggerlo (queue_free) quando esce dalla viewport.

const TEST_ASSET_SCENE: PackedScene = preload("res://scenes/TestAsset.tscn")

# Raggio base (px) di un oggetto prima della variazione di scala dal generatore.
const OBJECT_BASE_RADIUS: float = 18.0

# Z di riferimento e coefficienti mu delle tre bande: DEVONO rispecchiare le
# costanti degli shader (xray_absorption.gdshader / xray_colormap.gdshader) per
# ottenere il colore corretto a partire da z_eff_base.
const Z_ORG: float = 7.0
const Z_MIX: float = 14.0
const Z_METAL: float = 26.0
const MU_ORG: float = 0.50
const MU_MIX: float = 0.75
const MU_METAL: float = 0.95

# Identificativo della valigia (usato dalla logica di gameplay).
@export var baggage_id: String = ""

# Stato della minaccia, valorizzato dal ConveyorController in fase di spawn e
# letto dalla logica di valutazione della Fase 6.
var has_threat: bool = false
var threat_item_id: String = ""

# Nodi TestAsset che rappresentano l'oggetto-minaccia iniettato. Usati
# dall'AICmoreOverlay per disegnare il bounding box rosso che li segue.
var threat_nodes: Array = []


func _ready() -> void:
	add_to_group("baggage")
	# Animazione di comparsa sobria: scala 0.95 -> 1.0 in 0.3s.
	scale = Vector2(0.95, 0.95)
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


## Istanzia un TestAsset per ogni voce in items_data e lo posiziona dentro la
## valigia. items_data e' l'Array prodotto da BaggageAssembler/ThreatInjector:
## ciascun elemento ha { item_id, position, rotation, scale }.
func populate(items_data: Array) -> void:
	threat_nodes.clear()
	for entry in items_data:
		var item_id: String = String(entry.get("item_id", ""))
		var item: Dictionary = DataManager.get_item(item_id)
		if item.is_empty():
			push_warning("BaggageContainer: item_id sconosciuto '%s', oggetto saltato." % item_id)
			continue

		var z_eff: float = float(item.get("z_eff_base", Z_ORG))
		var thickness: float = float(item.get("thickness_multiplier", 1.0))
		var fractions: Vector3 = _fractions_for_zeff(z_eff)

		var asset: Node2D = TEST_ASSET_SCENE.instantiate()
		# I parametri vanno impostati PRIMA di add_child: TestAsset li legge nel
		# suo _ready (che scatta all'ingresso nell'albero).
		asset.organic_fraction = fractions.x
		asset.mixed_fraction = fractions.y
		asset.metal_fraction = fractions.z
		asset.radius = OBJECT_BASE_RADIUS
		asset.density = clampf(thickness, 0.3, 3.0)

		asset.position = entry.get("position", Vector2.ZERO)
		asset.rotation = float(entry.get("rotation", 0.0))
		var s: float = float(entry.get("scale", 1.0))
		asset.scale = Vector2(s, s)

		add_child(asset)

		# Segna l'oggetto-minaccia (quello iniettato dal ThreatInjector) cosi'
		# l'iCMORE puo' incorniciarlo. Col pool del BaggageAssembler privo di
		# minacce, solo l'oggetto iniettato combacia con threat_item_id.
		if has_threat and item_id == threat_item_id:
			threat_nodes.append(asset)


## Converte un numero atomico efficace (z_eff_base) nelle proporzioni di materiale
## R/G/B attese dal TestAsset, tali che il pass di falso colore ricostruisca
## ESATTAMENTE quel z_eff.
##
## Il colormap calcola: z_eff = (acc.r*Z_ORG + acc.g*Z_MIX + acc.b*Z_METAL) / sum,
## dove acc_banda = mu_banda * frazione * spessore * scala. Mescolando solo le due
## bande adiacenti a z e scegliendo le frazioni in modo che il rapporto degli
## assorbimenti sia (Z_hi - z) : (z - Z_lo), la media pesata torna esattamente z.
func _fractions_for_zeff(z: float) -> Vector3:
	z = clampf(z, Z_ORG, Z_METAL)

	var z_lo: float
	var z_hi: float
	var mu_lo: float
	var mu_hi: float
	var ch_lo: int
	var ch_hi: int

	if z <= Z_MIX:
		z_lo = Z_ORG; z_hi = Z_MIX
		mu_lo = MU_ORG; mu_hi = MU_MIX
		ch_lo = 0; ch_hi = 1 # organico -> misto
	else:
		z_lo = Z_MIX; z_hi = Z_METAL
		mu_lo = MU_MIX; mu_hi = MU_METAL
		ch_lo = 1; ch_hi = 2 # misto -> metallo

	# Assorbimenti voluti nelle due bande (proporzioni della media pesata).
	var acc_lo: float = z_hi - z
	var acc_hi: float = z - z_lo
	# Inverti il peso mu per ottenere le frazioni che producono quegli assorbimenti.
	var frac_lo: float = acc_lo / mu_lo
	var frac_hi: float = acc_hi / mu_hi

	var v: Vector3 = Vector3.ZERO
	v[ch_lo] = frac_lo
	v[ch_hi] = frac_hi

	# Normalizza (TestAsset normalizza comunque, ma teniamo i valori puliti).
	var sum: float = v.x + v.y + v.z
	if sum > 0.0:
		v /= sum
	else:
		v = Vector3(1.0, 0.0, 0.0)
	return v


## Restituisce i rettangoli (in coordinate GLOBALI) attorno agli oggetti-minaccia
## di questo bagaglio, gia' pronti per essere disegnati dall'AICmoreOverlay.
func get_threat_global_rects() -> Array:
	var rects: Array = []
	for n in threat_nodes:
		if not is_instance_valid(n):
			continue
		var rad: float = OBJECT_BASE_RADIUS * maxf(absf(n.scale.x), absf(n.scale.y)) + 8.0
		var c: Vector2 = n.global_position
		rects.append(Rect2(c.x - rad, c.y - rad, rad * 2.0, rad * 2.0))
	return rects

