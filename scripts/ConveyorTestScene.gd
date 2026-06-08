extends Node2D
## ConveyorTestScene (Fase 3 - solo test)
##
## Scena di prova isolata: spawna automaticamente 3 valigie placeholder
## a intervalli di 1.5s per validare lo scorrimento del nastro.
## NON e' la scena di gioco definitiva.

const MAX_SPAWN := 3

@onready var conveyor: ConveyorController = $ConveyorBelt
@onready var spawn_timer: Timer = $SpawnTimer

var _spawned: int = 0


func _ready() -> void:
	# Prima valigia subito, le altre via Timer ogni 1.5s.
	_spawn_next()
	spawn_timer.start()


func _on_spawn_timer_timeout() -> void:
	_spawn_next()


func _spawn_next() -> void:
	if _spawned >= MAX_SPAWN:
		spawn_timer.stop()
		return
	_spawned += 1
	conveyor.spawn_baggage("bag_%d" % _spawned)
