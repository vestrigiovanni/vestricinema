extends Node
## DataManager (Autoload singleton)
##
## Carica il database degli oggetti da data/items_database.json e li indicizza
## per id in un dizionario, pronto per essere interrogato dal resto del gioco.

const DATABASE_PATH := "res://data/items_database.json"

## Dizionario { id: String -> item: Dictionary } con tutti gli oggetti caricati.
var items: Dictionary = {}


func _ready() -> void:
	_load_database()


## Apre, fa il parsing del JSON e popola il dizionario indicizzato per id.
## Gestisce file mancante, JSON malformato e struttura inattesa senza crashare.
func _load_database() -> void:
	if not FileAccess.file_exists(DATABASE_PATH):
		push_error("DataManager: file database non trovato: %s" % DATABASE_PATH)
		return

	var file := FileAccess.open(DATABASE_PATH, FileAccess.READ)
	if file == null:
		push_error("DataManager: impossibile aprire %s (errore %d)" % [DATABASE_PATH, FileAccess.get_open_error()])
		return

	var raw_text := file.get_as_text()
	file.close()

	var json := JSON.new()
	var parse_result := json.parse(raw_text)
	if parse_result != OK:
		push_error("DataManager: JSON malformato in %s alla riga %d: %s" % [DATABASE_PATH, json.get_error_line(), json.get_error_message()])
		return

	var data = json.data
	if typeof(data) != TYPE_DICTIONARY or not data.has("items"):
		push_error("DataManager: struttura del database inattesa, manca la chiave \"items\".")
		return

	var raw_items = data["items"]
	if typeof(raw_items) != TYPE_ARRAY:
		push_error("DataManager: la chiave \"items\" deve essere un array.")
		return

	items.clear()
	for entry in raw_items:
		if typeof(entry) != TYPE_DICTIONARY or not entry.has("id"):
			push_warning("DataManager: voce ignorata, manca il campo \"id\": %s" % str(entry))
			continue
		var item_id := str(entry["id"])
		if items.has(item_id):
			push_warning("DataManager: id duplicato \"%s\", la voce successiva sovrascrive la precedente." % item_id)
		items[item_id] = entry

	_log_loaded_items()


## Stampa in console un riepilogo leggibile degli oggetti caricati.
func _log_loaded_items() -> void:
	print("DataManager: caricati %d oggetti da %s" % [items.size(), DATABASE_PATH])
	for item_id in items:
		var item: Dictionary = items[item_id]
		var threat_label := "MINACCIA" if item.get("is_threat", false) else "sicuro"
		print("  - [%s] %s (%s, z_eff=%s) -> %s" % [
			item_id,
			item.get("name", "?"),
			item.get("category", "?"),
			str(item.get("z_eff_base", "?")),
			threat_label,
		])


## Restituisce l'oggetto con l'id dato, o un dizionario vuoto se assente.
func get_item(item_id: String) -> Dictionary:
	return items.get(item_id, {})
