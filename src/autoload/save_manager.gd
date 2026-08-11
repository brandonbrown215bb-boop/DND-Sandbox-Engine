## Save Manager
## Versioned, transactional persistence for supported safe-save states.
extends Node

const SAVE_DIR := "user://saves/"
const SAVE_SCHEMA_VERSION := 1
const GAME_VERSION := "crown-gate-2"


func _ready() -> void:
	if not DirAccess.dir_exists_absolute(SAVE_DIR):
		DirAccess.make_dir_recursive_absolute(SAVE_DIR)


## Save only from an explicit safe state. The guard is repeated here so UI
## callers cannot create combat, event, transition, or active-dungeon saves.
func save_game(slot_name: String) -> bool:
	if not _valid_slot_name(slot_name):
		push_warning("[SaveManager] Invalid save slot name.")
		return false
	var reason := get_save_block_reason()
	if not reason.is_empty():
		push_warning("[SaveManager] Save rejected: %s" % reason)
		return false

	var save_data := {
		"schema_version": SAVE_SCHEMA_VERSION,
		"game_version": GAME_VERSION,
		"campaign_id": GameManager.active_campaign.get("id", ""),
		"current_state": int(GameManager.current_state),
		"defeated_monsters": GameManager.defeated_monsters.duplicate(),
		"campaign_ledger": _serialize_campaign_ledger(),
		"party": PartyManager.serialize(),
		"active_dungeon_state": _serialize_dungeon_state(GameManager.active_dungeon_state),
		"players": PlayerManager.serialize(),
		"current_round": PlayerManager.current_round,
		"active_player_index": PlayerManager.active_player_index,
		"saved_at": Time.get_datetime_dict_from_system(),
	}
	var json_string := JSON.stringify(save_data, "\t")
	var file_path := SAVE_DIR + slot_name + ".sav"
	var temp_path := file_path + ".tmp"
	var backup_path := file_path + ".bak"
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		push_error("[SaveManager] Failed to open temporary save file: %s" % temp_path)
		return false
	file.store_string(json_string)
	file.close()
	if FileAccess.file_exists(backup_path):
		DirAccess.remove_absolute(backup_path)
	if FileAccess.file_exists(file_path):
		var backup_error := DirAccess.rename_absolute(file_path, backup_path)
		if backup_error != OK:
			DirAccess.remove_absolute(temp_path)
			push_error("[SaveManager] Failed to stage previous save file: %s" % file_path)
			return false
	_maybe_hold_for_process_interruption(slot_name, backup_path)
	var rename_error := DirAccess.rename_absolute(temp_path, file_path)
	if rename_error != OK:
		if FileAccess.file_exists(backup_path):
			DirAccess.rename_absolute(backup_path, file_path)
		DirAccess.remove_absolute(temp_path)
		push_error("[SaveManager] Failed to commit save file: %s" % file_path)
		return false
	if FileAccess.file_exists(backup_path):
		DirAccess.remove_absolute(backup_path)
	print("[SaveManager] Successfully saved game to %s" % file_path)
	return true


## Test-only synchronization point for the host process-interruption fixture.
## It is inert unless both test mode and the explicit environment marker are set.
func _maybe_hold_for_process_interruption(slot_name: String, backup_path: String) -> void:
	if not GameManager.test_mode:
		return
	var marker_path := OS.get_environment("GATE3_SAVE_INTERRUPT_MARKER")
	var marker_slot := OS.get_environment("GATE3_SAVE_INTERRUPT_SLOT")
	if marker_path.is_empty() or marker_slot != slot_name or not FileAccess.file_exists(backup_path):
		return
	var marker := FileAccess.open(marker_path, FileAccess.WRITE)
	if marker == null:
		push_error("[SaveManager] Failed to create process-interruption marker: %s" % marker_path)
		return
	marker.store_string("backup-ready")
	marker.close()
	print("[SaveManager] Process interruption hold reached after backup staging.")
	while FileAccess.file_exists(marker_path):
		OS.delay_msec(25)


## Return an explanation suitable for the player-facing HUD.
func get_save_block_reason() -> String:
	if not GameManager.game_in_progress:
		return "no game is in progress"
	if GameManager.active_campaign.is_empty():
		return "no campaign is active"
	if GameManager.is_loading_save:
		return "a save is currently loading"
	match GameManager.current_state:
		GameManager.GameState.OVERWORLD:
			return ""
		GameManager.GameState.DUNGEON:
			if bool(GameManager.active_dungeon_state.get("save_checkpoint", false)):
				return ""
			return "the party is inside an active dungeon; return to its entrance checkpoint"
		_:
			return "saving is unavailable during this activity"


## Load after parsing and validating the entire DTO. The active session is not
## changed when a file is corrupt, unsupported, or references missing content.
func load_game(slot_name: String) -> bool:
	if not _valid_slot_name(slot_name):
		return false
	var save_data := _read_save(slot_name)
	if save_data.is_empty():
		return false
	var validation_error := _validate_save_data(save_data)
	if not validation_error.is_empty():
		push_warning("[SaveManager] Save '%s' rejected: %s" % [slot_name, validation_error])
		return false

	var loaded_campaign: Dictionary = DataLoader.get_campaign(str(save_data.get("campaign_id", "")))
	var loaded_state := int(save_data.get("current_state", int(GameManager.GameState.OVERWORLD)))
	GameManager.is_loading_save = true
	GameManager.active_campaign = loaded_campaign
	GameManager.defeated_monsters.assign(_string_array(save_data.get("defeated_monsters", [])))
	_apply_campaign_ledger(save_data.get("campaign_ledger", {}))
	GameManager.active_dungeon_state = _deserialize_dungeon_state(save_data.get("active_dungeon_state", {}))
	PlayerManager.deserialize(save_data.get("players", []))
	var party_data = save_data.get("party", {})
	if party_data is Dictionary and not party_data.is_empty():
		PartyManager.deserialize(party_data)
	else:
		PartyManager.sync_from_player_manager()
	PlayerManager.current_round = int(save_data.get("current_round", 1))
	PlayerManager.active_player_index = int(save_data.get("active_player_index", 0))
	GameManager.game_in_progress = true

	if GameManager.test_mode:
		GameManager.current_state = loaded_state
		GameManager.is_loading_save = false
		print("[SaveManager] Test mode: restored save state without scene transition")
		return true
	GameManager.is_loading_save = false
	GameManager.change_state(loaded_state)
	print("[SaveManager] Successfully loaded game from %s%s" % [SAVE_DIR, slot_name])
	return true


func is_save_resumable(slot_name: String) -> bool:
	var save_data := _read_save(slot_name)
	if save_data.is_empty() or not _validate_save_data(save_data).is_empty():
		return false
	return int(save_data.get("current_state", int(GameManager.GameState.MAIN_MENU))) != int(GameManager.GameState.MAIN_MENU)


func get_resumable_saves() -> Array[String]:
	var resumable: Array[String] = []
	for slot in get_available_saves():
		if is_save_resumable(slot):
			resumable.append(slot)
	return resumable


func get_available_saves() -> Array[String]:
	var save_names: Dictionary = {}
	if not DirAccess.dir_exists_absolute(SAVE_DIR):
		return []
	var dir := DirAccess.open(SAVE_DIR)
	if dir == null:
		return []
	var file_names: PackedStringArray = dir.get_files()
	file_names.sort()
	for file_name in file_names:
		if file_name.ends_with(".sav"):
			save_names[file_name.trim_suffix(".sav")] = true
		elif file_name.ends_with(".sav.bak"):
			save_names[file_name.trim_suffix(".sav.bak")] = true
	var saves: Array[String] = []
	for save_name in save_names:
		saves.append(str(save_name))
	saves.sort()
	return saves


func delete_save(slot_name: String) -> bool:
	if not _valid_slot_name(slot_name):
		return false
	var file_path := SAVE_DIR + slot_name + ".sav"
	var backup_path := file_path + ".bak"
	if not FileAccess.file_exists(file_path) and not FileAccess.file_exists(backup_path):
		return false
	var removed := false
	if FileAccess.file_exists(file_path):
		removed = DirAccess.remove_absolute(file_path) == OK
	if FileAccess.file_exists(backup_path):
		removed = DirAccess.remove_absolute(backup_path) == OK or removed
	if removed:
		print("[SaveManager] Deleted save slot: %s" % slot_name)
		return true
	push_error("[SaveManager] Failed to delete save file: %s" % file_path)
	return false


func _valid_slot_name(slot_name: String) -> bool:
	return not slot_name.is_empty() and slot_name.length() <= 48 and not slot_name.contains("..") and not slot_name.contains("/") and not slot_name.contains("\\")


func _read_save(slot_name: String) -> Dictionary:
	if not _valid_slot_name(slot_name):
		return {}
	var file_paths := [SAVE_DIR + slot_name + ".sav", SAVE_DIR + slot_name + ".sav.bak"]
	var first_data: Dictionary = {}
	for file_path in file_paths:
		if not FileAccess.file_exists(file_path):
			continue
		var file := FileAccess.open(file_path, FileAccess.READ)
		if file == null:
			continue
		var json := JSON.new()
		var error := json.parse(file.get_as_text())
		file.close()
		if error != OK or not json.data is Dictionary:
			continue
		var candidate: Dictionary = json.data
		if first_data.is_empty():
			first_data = candidate
		if _validate_save_data(candidate).is_empty():
			return candidate
	return first_data


func _validate_save_data(data: Dictionary) -> String:
	if int(data.get("schema_version", -1)) != SAVE_SCHEMA_VERSION:
		return "unsupported schema version"
	if str(data.get("game_version", "")).is_empty():
		return "missing game version"
	if DataLoader.get_campaign(str(data.get("campaign_id", ""))).is_empty():
		return "campaign reference is missing or unknown"
	var state := int(data.get("current_state", -1))
	if state == int(GameManager.GameState.MAIN_MENU):
		return "save has no resumable game state"
	if state < int(GameManager.GameState.CHARACTER_CREATION) or state > int(GameManager.GameState.GAME_OVER):
		return "invalid game state"
	if not data.get("players", []) is Array:
		return "players DTO is not an array"
	for player in data.get("players", []):
		if not player is Dictionary:
			return "player DTO is not an object"
		if str(player.get("input_mode", PlayerManager.INPUT_MODE_SHARED)) not in [PlayerManager.INPUT_MODE_SHARED, PlayerManager.INPUT_MODE_CONTROLLER]:
			return "player input mode is invalid"
		if not player.get("assigned_slot_ids", []) is Array:
			return "player party-slot DTO is not an array"
		for slot_id in player.get("assigned_slot_ids", []):
			if str(slot_id) not in ["slot_0", "slot_1", "slot_2", "slot_3"]:
				return "player references an unknown party slot"
		var character_data = player.get("character")
		if character_data != null:
			if not character_data is Dictionary:
				return "character DTO is not an object"
			if DataLoader.get_race(str(character_data.get("race_id", ""))).is_empty() or DataLoader.get_character_class(str(character_data.get("class_id", ""))).is_empty():
				return "character references unknown content"
	var party_data = data.get("party")
	if party_data != null:
		if not party_data is Dictionary:
			return "party DTO is not an object"
		var party_error := _validate_party_data(party_data)
		if not party_error.is_empty():
			return party_error
	if not data.get("defeated_monsters", []) is Array:
		return "defeated monster ledger is not an array"
	if not data.get("campaign_ledger", {}) is Dictionary:
		return "campaign ledger is not an object"
	return ""


func _validate_party_data(data: Dictionary) -> String:
	var slots = data.get("party_slots", [])
	var characters = data.get("characters", {})
	var roster = data.get("companion_roster", {})
	if not slots is Array:
		return "party slots DTO is not an array"
	if not characters is Dictionary:
		return "party characters DTO is not an object"
	if not roster is Dictionary:
		return "companion roster DTO is not an object"
	var known_slots := ["slot_0", "slot_1", "slot_2", "slot_3"]
	var seen_slots: Dictionary = {}
	var seen_characters: Dictionary = {}
	for slot_data in slots:
		if not slot_data is Dictionary:
			return "party slot DTO is not an object"
		var slot_id := str(slot_data.get("slot_id", ""))
		if slot_id not in known_slots:
			return "party slot references an unknown slot"
		if seen_slots.has(slot_id):
			return "party slots contain a duplicate slot"
		seen_slots[slot_id] = true
		var character_id := str(slot_data.get("character_id", ""))
		if bool(slot_data.get("occupied", false)):
			if character_id.is_empty() or not characters.has(character_id):
				return "occupied party slot references a missing character"
			if seen_characters.has(character_id):
				return "party character is assigned to multiple slots"
			seen_characters[character_id] = true
		else:
			if not character_id.is_empty():
				return "empty party slot carries a character reference"
	for character_id in characters:
		var character_data = characters[character_id]
		if not character_data is Dictionary:
			return "party character DTO is not an object"
		if DataLoader.get_race(str(character_data.get("race_id", ""))).is_empty() or DataLoader.get_character_class(str(character_data.get("class_id", ""))).is_empty():
			return "party character references unknown content"
	var leader_slot_id := str(data.get("leader_slot_id", "slot_0"))
	if leader_slot_id not in known_slots:
		return "party leader references an unknown slot"
	for companion_id in roster:
		var record = roster[companion_id]
		if not record is Dictionary:
			return "companion roster record is not an object"
		var state := str(record.get("state", ""))
		if state not in ["available", "recruited", "declined", "dismissed"]:
			return "companion roster has an invalid state"
		var character_id := str(record.get("character_id", ""))
		if character_id.is_empty() or not characters.has(character_id):
			return "companion roster references a missing character"
	return ""


func _serialize_campaign_ledger() -> Dictionary:
	return {
		"completed_milestones": GameManager.completed_milestones.duplicate(),
		"cleared_dungeons": GameManager.cleared_dungeons.duplicate(),
		"claimed_rewards": GameManager.claimed_rewards.duplicate(),
		"recruited_companions": GameManager.recruited_companions.duplicate(),
		"dismissed_companions": GameManager.dismissed_companions.duplicate(),
		"campaign_completed": GameManager.campaign_completed,
	}


func _apply_campaign_ledger(data: Dictionary) -> void:
	GameManager.completed_milestones.assign(_string_array(data.get("completed_milestones", [])))
	GameManager.cleared_dungeons.assign(_string_array(data.get("cleared_dungeons", [])))
	GameManager.claimed_rewards.assign(_string_array(data.get("claimed_rewards", [])))
	GameManager.recruited_companions.assign(_string_array(data.get("recruited_companions", [])))
	GameManager.dismissed_companions.assign(_string_array(data.get("dismissed_companions", [])))
	GameManager.campaign_completed = bool(data.get("campaign_completed", false))


func _string_array(value) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for entry in value:
			result.append(str(entry))
	return result


func _serialize_dungeon_state(state: Dictionary) -> Dictionary:
	if state.is_empty():
		return {}
	var result := state.duplicate()
	var raw_rooms = state.get("rooms", {})
	var room_dtos: Array = []
	if raw_rooms is Dictionary:
		for coord in raw_rooms:
			var room = raw_rooms[coord]
			if room is Room:
				room_dtos.append(room.to_dict())
			elif room is Dictionary:
				room_dtos.append(room.duplicate(true))
	result["rooms"] = room_dtos
	var position = state.get("party_position", Vector2i.ZERO)
	if position is Vector2i:
		result["party_position"] = [position.x, position.y]
	return result


func _deserialize_dungeon_state(state) -> Dictionary:
	if not state is Dictionary:
		return {}
	return state.duplicate(true)
