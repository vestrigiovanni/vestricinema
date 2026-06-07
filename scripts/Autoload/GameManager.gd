extends Node
## GameManager (Autoload singleton)
##
## Stub di Fase 1: tiene solo lo stato di gioco corrente.
## La logica di transizione tra stati verrà aggiunta nelle fasi successive.

enum State {
	MENU,
	INSPECTION,
	PAUSE,
}

## Stato di gioco corrente.
var current_state: State = State.MENU
