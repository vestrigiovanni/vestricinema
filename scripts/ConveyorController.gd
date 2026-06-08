extends Node2D
class_name ConveyorController
## ConveyorController (Fase 5)
##
## Gestisce il nastro trasportatore: scorre i BaggageContainer verso destra a
## velocita' costante e li distrugge oltre il DespawnPoint (niente memory leak).
##
## Da Fase 5 e' anche il MOTORE di spawn: ogni `spawn_interval` secondi genera un
## bagaglio procedurale (BaggageAssembler) e vi inietta eventualmente una minaccia
## (ThreatInjector) prima di istanziarlo e popolarlo.
##
## Il movimento usa sempre `delta` -> indipendente dal framerate.
## Premere SPAZIO ferma/riavvia il nastro.

const BAGGAGE_SCENE: PackedScene = preload("res://scenes/BaggageContainer.tscn")

## Emesso quando il nastro parte/si ferma: la dashboard lo usa per abilitare i
## pulsanti APPROVA/RESPINGI solo a nastro fermo.
signal running_changed(is_running: bool)

# Velocita' di scorrimento del nastro in pixel al secondo.
@export var belt_speed: float = 200.0

# Intervallo (s) tra uno spawn e il successivo.
@export var spawn_interval: float = 3.0

# Se true il nastro genera bagagli da solo tramite il Timer interno.
@export var auto_spawn: bool = true

# Ascissa (px) del punto di ispezione: il bagaglio piu' vicino e' quello che
# l'operatore sta esaminando quando ferma il nastro.
@export var inspection_x: float = 780.0

# Generatori (Resource). Se non assegnati da Inspector vengono creati con i
# valori di default in _ready, cosi' la scena funziona "out of the box".
@export var assembler: BaggageAssembler
@export var threat_injector: ThreatInjector

# Quando false il nastro e' fermo (le valigie non si muovono).
var is_running: bool = true

var _spawn_count: int = 0
var _spawn_timer: Timer

@onready var spawn_point: Marker2D = $SpawnPoint
@onready var despawn_point: Marker2D = $DespawnPoint


func _ready() -> void:
	if assembler == null:
		assembler = BaggageAssembler.new()
	if threat_injector == null:
		threat_injector = ThreatInjector.new()

	if auto_spawn:
		_spawn_timer = Timer.new()
		_spawn_timer.wait_time = spawn_interval
		_spawn_timer.one_shot = false
		add_child(_spawn_timer)
		_spawn_timer.timeout.connect(_on_spawn_timer_timeout)
		_spawn_timer.start()
		# Primo bagaglio subito, senza attendere il primo tick.
		spawn_baggage()


func _physics_process(delta: float) -> void:
	if not is_running:
		return

	var step := belt_speed * delta
	for child in get_children():
		if not child.is_in_group("baggage"):
			continue
		child.position.x += step
		# Oltre il DespawnPoint la valigia esce di scena: liberala dalla memoria.
		if child.global_position.x > despawn_point.global_position.x:
			child.queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE:
			toggle()


func _on_spawn_timer_timeout() -> void:
	# A nastro fermo non si accumulano bagagli al SpawnPoint: si genera solo
	# quando il nastro scorre.
	if is_running:
		spawn_baggage()


## Avvia lo scorrimento del nastro.
func start() -> void:
	if is_running:
		return
	is_running = true
	SoundManager.set_belt_running(true)
	running_changed.emit(true)


## Ferma istantaneamente lo scorrimento del nastro.
func stop() -> void:
	if not is_running:
		return
	is_running = false
	SoundManager.set_belt_running(false)
	running_changed.emit(false)


## Inverte lo stato di scorrimento (fermo <-> in movimento).
func toggle() -> void:
	if is_running:
		stop()
	else:
		start()


## Restituisce il BaggageContainer piu' vicino al punto di ispezione (o null se
## non ce ne sono): e' il bagaglio che l'operatore sta esaminando.
func get_inspection_baggage() -> Node:
	var best: Node = null
	var best_dist: float = INF
	for child in get_children():
		if not child.is_in_group("baggage"):
			continue
		var dist: float = absf(child.global_position.x - inspection_x)
		if dist < best_dist:
			best_dist = dist
			best = child
	return best


## Genera un bagaglio procedurale, vi inietta eventualmente una minaccia, lo
## istanzia al SpawnPoint e lo popola con gli oggetti generati.
func spawn_baggage(id: String = "") -> BaggageContainer:
	var data: Array = assembler.build()
	data = threat_injector.inject(data)

	var bag := BAGGAGE_SCENE.instantiate() as BaggageContainer
	bag.position = spawn_point.position
	bag.baggage_id = id if id != "" else "bag_%d" % _spawn_count
	# Memorizza l'esito della TIP sul bagaglio per la valutazione (Fase 6).
	bag.has_threat = threat_injector.current_baggage_has_threat
	bag.threat_item_id = threat_injector.threat_item_id

	add_child(bag)
	bag.populate(data)
	SoundManager.play_spawn()

	_spawn_count += 1
	return bag
