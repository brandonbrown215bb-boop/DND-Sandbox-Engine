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

	# Refuse to "resume" a save that has no in-progress game (e.g. a menu-only
	# quicksave). Loading it would call change_state(MAIN_MENU) from the menu —
	# a silent no-op that just confuses the player.
	var loaded_state: GameManager.GameState = save_data.get("current_state", int(GameManager.GameState.OVERWORLD)) as GameManager.GameState
	if loaded_state == GameManager.GameState.MAIN_MENU:
		push_warning("[SaveManager] Save '%s' has no in-progress game (MAIN_MENU state) — not resuming." % slot_name)
		GameManager.is_loading_save = false
		return false

	# The isolated viewport harness owns the scene tree. Restore the logical
	# state without replacing that supervisor; production loads still perform
	# the normal scene transition.
	if GameManager.test_mode:
		GameManager.current_state = loaded_state
		GameManager.is_loading_save = false
		print("[SaveManager] Test mode: restored save state without scene transition")
		return true

	# Transition
	GameManager.change_state(loaded_state)
	print("[SaveManager] Successfully loaded game from %s" % file_path)
	return true


## Returns true if a save slot holds a resumable game (i.e. it is not a
## menu-only/empty save). A save whose current_state is MAIN_MENU has no in-
## progress game to return to, so loading it is a silent no-op — treat it as
## non-resumable so the menu can disable Load instead of confusing the player.
func is_save_resumable(slot_name: String) -> bool:
	var file_path := SAVE_DIR + slot_name + ".sav"
	if not FileAccess.file_exists(file_path):
		return false
	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		return false
	var text := file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(text) != OK:
		return false
	var save_data: Dictionary = json.data
	var state: int = int(save_data.get("current_state", int(GameManager.GameState.MAIN_MENU)))
	return state != GameManager.GameState.MAIN_MENU


## Get list of save slots that hold a resumable game (not menu-only saves).
func get_resumable_saves() -> Array[String]:
	var all := get_available_saves()
	var resumable: Array[String] = []
	for slot in all:
		if is_save_resumable(slot):
			resumable.append(slot)
	return resumable


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
