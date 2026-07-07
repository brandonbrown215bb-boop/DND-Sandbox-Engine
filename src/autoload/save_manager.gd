## Save Manager
## Manages saving and loading campaign states to/from the filesystem.
extends Node

const SAVE_DIR := "user://saves/"


func _ready() -> void:
	# Ensure the save directory exists
	if not DirAccess.dir_exists_absolute(SAVE_DIR):
		DirAccess.make_dir_recursive_absolute(SAVE_DIR)


## Save the current game state to a slot.
func save_game(slot_name: String) -> bool:
	if not GameManager.game_in_progress or GameManager.active_campaign.is_empty():
		push_warning("[SaveManager] No active game in progress to save.")
		return false

	var save_data := {
		"campaign_id": GameManager.active_campaign.get("id", ""),
		"current_state": int(GameManager.current_state),
		"defeated_monsters": GameManager.defeated_monsters.duplicate(),
		"active_dungeon_state": GameManager.active_dungeon_state.duplicate(),
		"players": PlayerManager.serialize(),
		"current_round": PlayerManager.current_round,
		"active_player_index": PlayerManager.active_player_index,
		"save_time": Time.get_datetime_dict_from_system()
	}

	var json_string := JSON.stringify(save_data, "\t")
	var file_path := SAVE_DIR + slot_name + ".sav"
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		push_error("[SaveManager] Failed to open file for writing: %s (error: %s)" % [file_path, FileAccess.get_open_error()])
		return false

	file.store_string(json_string)
	file.close()
	print("[SaveManager] Successfully saved game to %s" % file_path)
	return true


## Load a game state from a slot.
func load_game(slot_name: String) -> bool:
	var file_path := SAVE_DIR + slot_name + ".sav"
	if not FileAccess.file_exists(file_path):
		push_error("[SaveManager] Save file not found: %s" % file_path)
		return false

	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		push_error("[SaveManager] Failed to open file for reading: %s (error: %s)" % [file_path, FileAccess.get_open_error()])
		return false

	var text := file.get_as_text()
	file.close()

	var json := JSON.new()
	var error := json.parse(text)
	if error != OK:
		push_error("[SaveManager] Failed to parse save file JSON: line %d - %s" % [json.get_error_line(), json.get_error_message()])
		return false

	var save_data: Dictionary = json.data
	
	# Load campaign first
	var campaign_id: String = save_data.get("campaign_id", "")
	GameManager.active_campaign = DataLoader.get_campaign(campaign_id)
	if GameManager.active_campaign.is_empty():
		push_error("[SaveManager] Failed to load campaign data for ID: %s" % campaign_id)
		return false

	# Set loading flag to prevent ready logic overrides
	GameManager.is_loading_save = true

	# Restore game managers state
	GameManager.defeated_monsters.clear()
	for monster_id in save_data.get("defeated_monsters", []):
		GameManager.defeated_monsters.append(str(monster_id))
		
	GameManager.active_dungeon_state = save_data.get("active_dungeon_state", {}).duplicate()

	# Restore players
	PlayerManager.deserialize(save_data.get("players", []))
	PlayerManager.current_round = int(save_data.get("current_round", 1))
	PlayerManager.active_player_index = int(save_data.get("active_player_index", 0))

	GameManager.game_in_progress = true

	# Restore game state scene
	var loaded_state: GameManager.GameState = save_data.get("current_state", int(GameManager.GameState.OVERWORLD)) as GameManager.GameState
	
	# Transition
	GameManager.change_state(loaded_state)
	print("[SaveManager] Successfully loaded game from %s" % file_path)
	return true


## Get list of all available save slots.
func get_available_saves() -> Array[String]:
	var saves: Array[String] = []
	if not DirAccess.dir_exists_absolute(SAVE_DIR):
		return saves

	var dir := DirAccess.open(SAVE_DIR)
	if dir == null:
		return saves

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".sav"):
			saves.append(file_name.get_basename())
		file_name = dir.get_next()
	dir.list_dir_end()
	return saves


## Delete a save slot.
func delete_save(slot_name: String) -> bool:
	var file_path := SAVE_DIR + slot_name + ".sav"
	if FileAccess.file_exists(file_path):
		var err := DirAccess.remove_absolute(file_path)
		if err == OK:
			print("[SaveManager] Deleted save slot: %s" % slot_name)
			return true
		else:
			push_error("[SaveManager] Failed to delete save file: %s (error: %d)" % [file_path, err])
	return false
