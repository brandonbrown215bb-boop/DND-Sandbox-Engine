## Save Manager
## Versioned, transactional persistence for supported safe-save states.
extends Node

const AnimalMessengerRulesRef = preload("res://src/spells/animal_messenger_rules.gd")

const LEGACY_SAVE_DIR := "user://saves/"
const SAVE_DIR := "user://saves/dnd2024/"
const SAVE_SCHEMA_VERSION := 2
const RULESET_ID := "dnd-2024-srd-5.2.1"
const GAME_VERSION := "crown-2024-partial"


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
	SpellEffects.reconcile(PartyManager.characters.values(), PartyManager.characters.values())

	var save_data := {
		"schema_version": SAVE_SCHEMA_VERSION,
		"ruleset_id": RULESET_ID,
		"game_version": GAME_VERSION,
		"campaign_id": GameManager.active_campaign.get("id", ""),
		"current_state": int(GameManager.current_state),
		"defeated_monsters": GameManager.defeated_monsters.duplicate(),
		"campaign_ledger": _serialize_campaign_ledger(),
		"activity_history": ActivityHistory.serialize(),
		"party": PartyManager.serialize(),
		"active_dungeon_state": _serialize_dungeon_state(GameManager.active_dungeon_state),
		"players": PlayerManager.serialize(),
		"current_round": PlayerManager.current_round,
		"active_player_index": PlayerManager.active_player_index,
		"saved_at": Time.get_datetime_dict_from_system(),
	}
	var validation_error := _validate_save_data(save_data)
	if not validation_error.is_empty():
		push_warning("[SaveManager] Save rejected before writing: %s" % validation_error)
		return false
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
	var prepared_activity: Dictionary = ActivityHistory.prepare_snapshot(save_data.get("activity_history", {}))
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
	# Party data owns the current character state. Seats must reference that same
	# object, rather than the duplicate DTO reconstructed by PlayerManager.
	for index in PlayerManager.get_player_count():
		var player_data: Dictionary = PlayerManager.get_player(index)
		var player_character: Character = player_data.get("character")
		if player_character != null and PartyManager.characters.has(player_character.character_id):
			PlayerManager.set_player_character(index, PartyManager.characters[player_character.character_id])
		elif player_character != null:
			for slot_id in player_data.get("assigned_slot_ids", []):
				for slot in PartyManager.party_slots:
					var cid := str(slot.get("character_id", ""))
					if str(slot.get("slot_id", "")) == str(slot_id) and not bool(slot.get("is_companion", false)) and PartyManager.characters.has(cid):
						PlayerManager.set_player_character(index, PartyManager.characters[cid])
						break
	SpellEffects.reconcile(PartyManager.characters.values(), PartyManager.characters.values())
	PlayerManager.current_round = int(save_data.get("current_round", 1))
	PlayerManager.active_player_index = int(save_data.get("active_player_index", 0))
	ActivityHistory.apply_prepared_snapshot(prepared_activity)
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


## Read-only menu choice; validation remains the existing save boundary.
func get_latest_resumable_save() -> String:
	var latest := ""
	var latest_time := -1
	for slot in get_resumable_saves():
		var path := SAVE_DIR + slot + ".sav"
		if not FileAccess.file_exists(path): path += ".bak"
		var modified := int(FileAccess.get_modified_time(path))
		if modified > latest_time:
			latest = slot
			latest_time = modified
	return latest


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


func get_legacy_save_names() -> Array[String]:
	var names: Array[String] = []
	var dir := DirAccess.open(LEGACY_SAVE_DIR)
	if dir == null:
		return names
	for file_name in dir.get_files():
		var slot := ""
		if file_name.ends_with(".sav"):
			slot = file_name.trim_suffix(".sav")
		elif file_name.ends_with(".sav.bak"):
			slot = file_name.trim_suffix(".sav.bak")
		if not slot.is_empty() and slot not in names:
			names.append(slot)
	names.sort()
	return names


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
	var campaign_clock: Variant = data.get("campaign_ledger", {})
	var saved_campaign_seconds := int(campaign_clock.get("campaign_elapsed_seconds", 0)) if campaign_clock is Dictionary else 0
	if int(data.get("schema_version", -1)) != SAVE_SCHEMA_VERSION:
		return "unsupported schema version"
	if str(data.get("ruleset_id", "")) != RULESET_ID:
		return "save uses incompatible rules; start a new campaign"
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
			var progression_error := PermanentProgressionRules.saved_error(character_data)
			if not progression_error.is_empty(): return progression_error
			var allocation_error := Character.saved_class_levels_error(character_data)
			if not allocation_error.is_empty(): return allocation_error
			var pact_slots_error := Character.saved_pact_spell_slots_error(character_data)
			if not pact_slots_error.is_empty(): return pact_slots_error
			var gift_error := CapturedGrantRules.saved_error(character_data, saved_campaign_seconds)
			if not gift_error.is_empty(): return gift_error
			var zero_hp_error := SharedStepExecutor.saved_zero_hp_history_error(character_data)
			if not zero_hp_error.is_empty(): return zero_hp_error
			var max_hp_source_error := MaxHpSourceRules.saved_error(character_data)
			if not max_hp_source_error.is_empty(): return max_hp_source_error
			var feature_mode_error := FeatureModeRules.saved_error(character_data)
			if not feature_mode_error.is_empty(): return feature_mode_error
			var numeric_pool_error := ResourcePoolRules.saved_state_error(character_data)
			if not numeric_pool_error.is_empty(): return numeric_pool_error
			var survival_error := SurvivalRules.saved_state_error(character_data)
			if not survival_error.is_empty(): return survival_error
			var corpse_error := CorpseRules.saved_error(character_data)
			if not corpse_error.is_empty(): return corpse_error
			var willingness_error := Character.saved_willingness_error(character_data)
			if not willingness_error.is_empty(): return willingness_error
			var familiar_error := FamiliarRules.saved_error(character_data)
			if not familiar_error.is_empty(): return familiar_error
			var steed_error := PaladinRules.saved_steed_error(character_data)
			if not steed_error.is_empty(): return steed_error
			var inventory_error := InventoryCopies.saved_error(character_data.get("inventory", {}))
			if not inventory_error.is_empty(): return inventory_error
			var fighter_error := FighterRules.saved_training_error(character_data)
			if not fighter_error.is_empty():
				return fighter_error
			var choices_error := ClassProgression.saved_choices_error(character_data)
			if not choices_error.is_empty():
				return choices_error
			var spell_error := SpellEffects.saved_state_error(character_data)
			if not spell_error.is_empty():
				return spell_error
			var temporary_hp_error := TemporaryHPRules.saved_error(character_data, saved_campaign_seconds)
			if not temporary_hp_error.is_empty(): return temporary_hp_error
			var aura_entry_error := AuraProtectionRules.saved_error(character_data, saved_campaign_seconds)
			if not aura_entry_error.is_empty(): return aura_entry_error
			var protection_error := ProtectionRules.saved_error(character_data,saved_campaign_seconds)
			if not protection_error.is_empty(): return protection_error
			var timed_modifier_error := Character.saved_campaign_modifier_error(character_data, saved_campaign_seconds)
			if not timed_modifier_error.is_empty():
				return timed_modifier_error
			var next_hit_grant_error := Character.saved_next_weapon_hit_grants_error(character_data, saved_campaign_seconds)
			if not next_hit_grant_error.is_empty():
				return next_hit_grant_error
			var timed_temporary_hp_error := Character.saved_timed_temporary_hp_error(character_data, saved_campaign_seconds)
			if not timed_temporary_hp_error.is_empty():
				return timed_temporary_hp_error
			var damage_history_error := Character.saved_damage_history_error(character_data, saved_campaign_seconds)
			if not damage_history_error.is_empty():
				return damage_history_error
	var party_data = data.get("party")
	if party_data != null:
		if not party_data is Dictionary:
			return "party DTO is not an object"
		var party_error := _validate_party_data(party_data, saved_campaign_seconds)
		if not party_error.is_empty():
			return party_error
	if not data.get("defeated_monsters", []) is Array:
		return "defeated monster ledger is not an array"
	if not data.get("campaign_ledger", {}) is Dictionary:
		return "campaign ledger is not an object"
	var campaign_ledger: Dictionary = data.get("campaign_ledger", {})
	var creature_error := CreatedCreatureRules.saved_error(campaign_ledger.get("created_creatures", []), campaign_ledger.get("next_created_creature_id", 1), int(campaign_ledger.get("campaign_elapsed_seconds", 0)))
	if not creature_error.is_empty(): return creature_error
	var world_error := DungeonPersistence.snapshots_error(campaign_ledger.get("dungeon_snapshots", {}), DataLoader.get_campaign(str(data["campaign_id"])))
	if not world_error.is_empty(): return world_error
	world_error = DungeonPersistence.saved_error(data.get("active_dungeon_state", {}))
	if not world_error.is_empty(): return world_error
	creature_error = CreatedCreatureRules.saved_locations_error(campaign_ledger.get("created_creatures", []), DataLoader.get_campaign(str(data["campaign_id"])), campaign_ledger.get("dungeon_snapshots", {}), data.get("active_dungeon_state", {}))
	if not creature_error.is_empty(): return creature_error
	var temporary_hp_links_error := TemporaryHPRules.saved_links_error(data)
	if not temporary_hp_links_error.is_empty(): return temporary_hp_links_error
	var aura_links_error := AuraProtectionRules.saved_links_error(data)
	if not aura_links_error.is_empty(): return aura_links_error
	var gift_links_error := CapturedGrantRules.saved_links_error(data)
	if not gift_links_error.is_empty(): return gift_links_error
	var ownership_error := InventoryCopies.ownership_error(data)
	var animated_rooms: Array = []
	for dungeon in [data.get("active_dungeon_state", {})] + campaign_ledger.get("dungeon_snapshots", {}).values():
		animated_rooms.append_array(dungeon.get("local_rooms", {}).values())
	creature_error = AnimatedObjectRules.saved_links_error(campaign_ledger.get("created_creatures", []), animated_rooms, data.get("party", {}).get("characters", {}))
	if not creature_error.is_empty(): return creature_error
	if not ownership_error.is_empty(): return ownership_error
	var messenger_error := AnimalMessengerRulesRef.validate_saved_deliveries(campaign_ledger.get("animal_messenger_deliveries", []))
	if not messenger_error.is_empty():
		return messenger_error
	var visit_error := _validate_visited_overworld_locations(campaign_ledger.get("visited_overworld_locations", []))
	if not visit_error.is_empty():
		return visit_error
	if int(campaign_ledger.get("campaign_elapsed_seconds", 0)) < 0 or int(campaign_ledger.get("next_animal_messenger_id", 1)) < 1:
		return "campaign travel clock is invalid"
	var clock_characters: Array = []
	for player in data.get("players", []):
		if player.get("character") is Dictionary: clock_characters.append(player["character"])
	if party_data is Dictionary: clock_characters.append_array(party_data.get("characters", {}).values())
	for member_data in clock_characters:
		var corpse_clock_error := CorpseRules.saved_clock_error(member_data, int(campaign_ledger.get("campaign_elapsed_seconds", 0)))
		if not corpse_clock_error.is_empty(): return corpse_clock_error
	return ""


func _validate_visited_overworld_locations(value: Variant) -> String:
	if not value is Array or value.size() > 2000:
		return "visited overworld locations are not a bounded array"
	var seen_ids: Dictionary = {}
	for location in value:
		if not location is Dictionary:
			return "visited overworld location is not an object"
		var location_id := str(location.get("id", ""))
		var coord = location.get("coord", null)
		if location_id.is_empty() or seen_ids.has(location_id) or not coord is Array or coord.size() != 2:
			return "visited overworld location is invalid"
		if not _valid_json_coordinate(coord[0]) or not _valid_json_coordinate(coord[1]) or str(location.get("name", "")).strip_edges().is_empty():
			return "visited overworld location is invalid"
		seen_ids[location_id] = true
	return ""


## JSON numbers decode as floats. Validate before narrowing to Vector2i's int32.
func _valid_json_coordinate(value: Variant) -> bool:
	if not (value is int or value is float):
		return false
	return is_finite(float(value)) and value >= -2147483648 and value <= 2147483647 and float(value) == floor(float(value))


func _validate_party_data(data: Dictionary, campaign_seconds: int = 0) -> String:
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
		var progression_error := PermanentProgressionRules.saved_error(character_data)
		if not progression_error.is_empty(): return progression_error
		var allocation_error := Character.saved_class_levels_error(character_data)
		if not allocation_error.is_empty(): return allocation_error
		var pact_slots_error := Character.saved_pact_spell_slots_error(character_data)
		if not pact_slots_error.is_empty(): return pact_slots_error
		var survival_error := SurvivalRules.saved_state_error(character_data)
		if not survival_error.is_empty(): return survival_error
		var gift_error := CapturedGrantRules.saved_error(character_data, campaign_seconds)
		if not gift_error.is_empty(): return gift_error
		var zero_hp_error := SharedStepExecutor.saved_zero_hp_history_error(character_data)
		if not zero_hp_error.is_empty(): return zero_hp_error
		var max_hp_source_error := MaxHpSourceRules.saved_error(character_data)
		if not max_hp_source_error.is_empty(): return max_hp_source_error
		var feature_mode_error := FeatureModeRules.saved_error(character_data)
		if not feature_mode_error.is_empty(): return feature_mode_error
		var numeric_pool_error := ResourcePoolRules.saved_state_error(character_data)
		if not numeric_pool_error.is_empty(): return numeric_pool_error
		var corpse_error := CorpseRules.saved_error(character_data)
		if not corpse_error.is_empty(): return corpse_error
		var willingness_error := Character.saved_willingness_error(character_data)
		if not willingness_error.is_empty(): return willingness_error
		var familiar_error := FamiliarRules.saved_error(character_data)
		if not familiar_error.is_empty(): return familiar_error
		var steed_error := PaladinRules.saved_steed_error(character_data)
		if not steed_error.is_empty(): return steed_error
		var inventory_error := InventoryCopies.saved_error(character_data.get("inventory", {}))
		if not inventory_error.is_empty(): return inventory_error
		var fighter_error := FighterRules.saved_training_error(character_data)
		if not fighter_error.is_empty():
			return fighter_error
		var choices_error := ClassProgression.saved_choices_error(character_data)
		if not choices_error.is_empty():
			return choices_error
		var spell_error := SpellEffects.saved_state_error(character_data)
		if not spell_error.is_empty():
			return spell_error
		var temporary_hp_error := TemporaryHPRules.saved_error(character_data, campaign_seconds)
		if not temporary_hp_error.is_empty(): return temporary_hp_error
		var aura_entry_error := AuraProtectionRules.saved_error(character_data, campaign_seconds)
		if not aura_entry_error.is_empty(): return aura_entry_error
		var protection_error := ProtectionRules.saved_error(character_data,campaign_seconds)
		if not protection_error.is_empty(): return protection_error
		var timed_modifier_error := Character.saved_campaign_modifier_error(character_data, campaign_seconds)
		if not timed_modifier_error.is_empty():
			return timed_modifier_error
		var next_hit_grant_error := Character.saved_next_weapon_hit_grants_error(character_data, campaign_seconds)
		if not next_hit_grant_error.is_empty():
			return next_hit_grant_error
		var timed_temporary_hp_error := Character.saved_timed_temporary_hp_error(character_data, campaign_seconds)
		if not timed_temporary_hp_error.is_empty():
			return timed_temporary_hp_error
		var damage_history_error := Character.saved_damage_history_error(character_data, campaign_seconds)
		if not damage_history_error.is_empty():
			return damage_history_error
	var leader_slot_id := str(data.get("leader_slot_id", "slot_0"))
	var effect_party_error := SpellEffects.saved_party_error(characters)
	if not effect_party_error.is_empty():
		return effect_party_error
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
		"dungeon_snapshots": GameManager.dungeon_snapshots.duplicate(true),
		"completed_milestones": GameManager.completed_milestones.duplicate(),
		"cleared_dungeons": GameManager.cleared_dungeons.duplicate(),
		"claimed_rewards": GameManager.claimed_rewards.duplicate(),
		"recruited_companions": GameManager.recruited_companions.duplicate(),
		"dismissed_companions": GameManager.dismissed_companions.duplicate(),
		"visited_overworld_locations": GameManager.visited_overworld_locations.duplicate(true),
		"animal_messenger_deliveries": GameManager.animal_messenger_deliveries.duplicate(true),
		"campaign_elapsed_seconds": GameManager.campaign_elapsed_seconds,
		"next_animal_messenger_id": GameManager.next_animal_messenger_id,
		"created_creatures": GameManager.created_creatures.duplicate(true),
		"next_created_creature_id": GameManager.next_created_creature_id,
		"campaign_completed": GameManager.campaign_completed,
	}


func _apply_campaign_ledger(data: Dictionary) -> void:
	GameManager.created_creatures.assign(_dictionary_array(data.get("created_creatures", [])))
	GameManager.next_created_creature_id = int(data.get("next_created_creature_id", 1))
	GameManager.dungeon_snapshots = data.get("dungeon_snapshots", {}).duplicate(true)
	GameManager.completed_milestones.assign(_string_array(data.get("completed_milestones", [])))
	GameManager.cleared_dungeons.assign(_string_array(data.get("cleared_dungeons", [])))
	GameManager.claimed_rewards.assign(_string_array(data.get("claimed_rewards", [])))
	GameManager.recruited_companions.assign(_string_array(data.get("recruited_companions", [])))
	GameManager.dismissed_companions.assign(_string_array(data.get("dismissed_companions", [])))
	GameManager.visited_overworld_locations.assign(_dictionary_array(data.get("visited_overworld_locations", [])))
	for location in GameManager.visited_overworld_locations:
		location["coord"] = [int(location["coord"][0]), int(location["coord"][1])]
	GameManager.animal_messenger_deliveries.assign(_dictionary_array(data.get("animal_messenger_deliveries", [])))
	GameManager.campaign_elapsed_seconds = maxi(0, int(data.get("campaign_elapsed_seconds", 0)))
	GameManager.next_animal_messenger_id = maxi(1, int(data.get("next_animal_messenger_id", 1)))
	GameManager.campaign_completed = bool(data.get("campaign_completed", false))


func _string_array(value) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for entry in value:
			result.append(str(entry))
	return result


func _dictionary_array(value) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if value is Array:
		for entry in value:
			if entry is Dictionary:
				result.append(entry.duplicate(true))
	return result


func _serialize_dungeon_state(state: Dictionary) -> Dictionary:
	if state.is_empty():
		return {}
	var result := state.duplicate(true)
	var raw_rooms = state.get("rooms", {})
	var room_dtos: Array = []
	if raw_rooms is Dictionary:
		for coord in raw_rooms:
			var room = raw_rooms[coord]
			if room is Room:
				room_dtos.append(room.to_dict())
			elif room is Dictionary:
				room_dtos.append(room.duplicate(true))
	elif raw_rooms is Array:
		for room in raw_rooms:
			if room is Dictionary: room_dtos.append(room.duplicate(true))
	result["rooms"] = room_dtos
	var position = state.get("party_position", Vector2i.ZERO)
	if position is Vector2i:
		result["party_position"] = [position.x, position.y]
	return result


func _deserialize_dungeon_state(state) -> Dictionary:
	if not state is Dictionary:
		return {}
	return state.duplicate(true)
