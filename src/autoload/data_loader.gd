## Data Loader
## Autoloaded singleton that scans and loads all JSON content data from disk.
## Loads from res://data/core/ (base game) and res://data/mods/ (user content).
## Mods can add new content or override core content by using the same ID.
extends Node

## Emitted when all data has finished loading.
signal data_loaded

## Emitted when a loading error occurs.
signal load_error(message: String)

## Content registries — all keyed by string ID.
var classes: Dictionary = {}      # id -> Dictionary
var races: Dictionary = {}        # id -> Dictionary
var items: Dictionary = {}        # id -> Dictionary
var spells: Dictionary = {}       # id -> Dictionary
var monsters: Dictionary = {}     # id -> Dictionary
var events: Dictionary = {}       # table_id -> Dictionary (event table)
var campaigns: Dictionary = {}    # id -> Dictionary

## Load order tracking.
var _load_errors: Array[String] = []

## Base paths to scan for content.
const CORE_PATH := "res://data/core/"
const MODS_PATH := "res://data/mods/"


func _ready() -> void:
	load_all_data()


## Load all content from core and mods directories.
func load_all_data() -> void:
	_load_errors.clear()
	classes.clear()
	races.clear()
	items.clear()
	spells.clear()
	monsters.clear()
	events.clear()
	campaigns.clear()

	# Load core content first
	_load_directory(CORE_PATH)

	# Load mods (overrides core if same ID)
	_load_directory(MODS_PATH)

	if not _load_errors.is_empty():
		for err in _load_errors:
			push_warning("[DataLoader] %s" % err)
			load_error.emit(err)

	print("[DataLoader] Loaded: %d classes, %d races, %d items, %d spells, %d monsters, %d event tables, %d campaigns" % [
		classes.size(), races.size(), items.size(), spells.size(),
		monsters.size(), events.size(), campaigns.size()
	])

	data_loaded.emit()


## Recursively scan a directory for JSON files and register their content.
func _load_directory(base_path: String) -> void:
	if not DirAccess.dir_exists_absolute(base_path):
		return

	# Scan subdirectories by content type
	_load_content_type(base_path + "classes/", "class")
	_load_content_type(base_path + "races/", "race")
	_load_content_type(base_path + "items/", "item")
	_load_content_type(base_path + "spells/", "spell")
	_load_content_type(base_path + "monsters/", "monster")
	_load_content_type(base_path + "events/", "event")
	_load_content_type(base_path + "campaigns/", "campaign")


## Load all JSON files in a directory and register them by type.
func _load_content_type(dir_path: String, content_type: String) -> void:
	if not DirAccess.dir_exists_absolute(dir_path):
		return

	var dir := DirAccess.open(dir_path)
	if dir == null:
		_load_errors.append("Cannot open directory: %s" % dir_path)
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".json"):
			var file_path := dir_path + file_name
			_load_json_file(file_path, content_type)
		file_name = dir.get_next()
	dir.list_dir_end()


## Load and parse a single JSON file, registering its content.
func _load_json_file(file_path: String, content_type: String) -> void:
	if not FileAccess.file_exists(file_path):
		_load_errors.append("File not found: %s" % file_path)
		return

	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		_load_errors.append("Cannot open file: %s (error: %s)" % [file_path, FileAccess.get_open_error()])
		return

	var text := file.get_as_text()
	file.close()

	var json := JSON.new()
	var error := json.parse(text)
	if error != OK:
		_load_errors.append("JSON parse error in %s line %d: %s" % [file_path, json.get_error_line(), json.get_error_message()])
		return

	var data = json.data

	# Handle files that contain a single object or an array of objects
	if data is Dictionary:
		_register_content(data, content_type, file_path)
	elif data is Array:
		for entry in data:
			if entry is Dictionary:
				_register_content(entry, content_type, file_path)
			else:
				_load_errors.append("Non-dictionary entry in array in %s" % file_path)


## Register a parsed content dictionary into the appropriate registry.
func _register_content(data: Dictionary, content_type: String, source_path: String) -> void:
	# Validate required fields
	var id: String = data.get("id", "")
	if id.is_empty():
		# For event tables, use table_id instead
		id = data.get("table_id", "")
		if id.is_empty():
			_load_errors.append("Missing 'id' field in %s" % source_path)
			return

	# Tag with source for debugging
	data["_source"] = source_path

	match content_type:
		"class":
			if not _validate_class(data, source_path):
				return
			classes[id] = data
		"race":
			if not _validate_race(data, source_path):
				return
			races[id] = data
		"item":
			items[id] = data
		"spell":
			spells[id] = data
		"monster":
			monsters[id] = data
		"event":
			events[id] = data
		"campaign":
			campaigns[id] = data


## Validate a class definition has required fields.
func _validate_class(data: Dictionary, source: String) -> bool:
	var required := ["id", "name", "hit_die", "primary_ability"]
	for field in required:
		if field not in data:
			_load_errors.append("Class missing required field '%s' in %s" % [field, source])
			return false
	return true


## Validate a race definition has required fields.
func _validate_race(data: Dictionary, source: String) -> bool:
	var required := ["id", "name"]
	for field in required:
		if field not in data:
			_load_errors.append("Race missing required field '%s' in %s" % [field, source])
			return false
	return true


# --- Public API ---

## Get all loaded classes as an array of dictionaries.
func get_all_classes() -> Array:
	return classes.values()


## Get a specific class by ID.
func get_character_class(id: String) -> Dictionary:
	return classes.get(id, {})


## Get all loaded races as an array of dictionaries.
func get_all_races() -> Array:
	return races.values()


## Get a specific race by ID.
func get_race(id: String) -> Dictionary:
	return races.get(id, {})


## Get all loaded items as an array of dictionaries.
func get_all_items() -> Array:
	return items.values()


## Get a specific item by ID.
func get_item(id: String) -> Dictionary:
	return items.get(id, {})


## Get all loaded spells as an array of dictionaries.
func get_all_spells() -> Array:
	return spells.values()


## Get a specific spell by ID.
func get_spell(id: String) -> Dictionary:
	return spells.get(id, {})


## Get all loaded monsters as an array of dictionaries.
func get_all_monsters() -> Array:
	return monsters.values()


## Get a specific monster by ID.
func get_monster(id: String) -> Dictionary:
	return monsters.get(id, {})


## Get an event table by its table ID.
func get_event_table(table_id: String) -> Dictionary:
	return events.get(table_id, {})


## Get all loaded campaigns as an array of dictionaries.
func get_all_campaigns() -> Array:
	return campaigns.values()


## Get a specific campaign by ID.
func get_campaign(id: String) -> Dictionary:
	return campaigns.get(id, {})


## Get all loading errors that occurred.
func get_load_errors() -> Array[String]:
	return _load_errors


## Reload all data (useful after mods are added/removed).
func reload() -> void:
	load_all_data()
