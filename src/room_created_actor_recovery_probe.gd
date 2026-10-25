extends Node

const SLOT := "room_created_actor_checkpoint"

func _ready() -> void:
	GameManager.test_mode = true
	Batch053Checks.load_fixtures()
	Batch059Checks.load_fixtures()
	DataLoader.spells[Batch053Checks.PAIR]["duration_seconds"] = 86400
	for fixture_spell_id in [Batch053Checks.PAIR, Batch053Checks.GAMBLE, Batch059Checks.REMAINS]:
		if fixture_spell_id not in DataLoader.classes["sorcerer"].get("spell_list_ids", []):
			DataLoader.classes["sorcerer"].spell_list_ids.append(fixture_spell_id)
	var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string("user://room_created_actor_manifest.json"))
	if not manifest is Dictionary or int(manifest.get("pid", 0)) == OS.get_process_id():
		return _fail("Checkpoint manifest is missing or this is not a fresh process")
	if not SaveManager.load_game(SLOT):
		return _fail("Allowed dungeon checkpoint refused in the recovery process")
	var owner_id := str(manifest.get("owner_id", ""))
	var owner: Character = PartyManager.characters.get(owner_id)
	var room: Dictionary = GameManager.active_dungeon_state.get("local_rooms", {}).get(str(manifest.get("room_id", "")), {})
	if owner == null:
		return _fail("Created actor owner was not restored")
	var actor_ids: Array = CreatedActorRules.actors(owner).map(func(actor): return actor.character_id)
	var remains: Dictionary = {}
	for object in room.get("objects", []):
		if str(object.get("id", "")) == str(manifest.get("remains_id", "")):
			remains = object
	var actual_positions: Dictionary = room.get("created_actor_positions", {})
	var expected_positions: Dictionary = manifest.get("positions", {})
	var positions_match := actual_positions.size() == expected_positions.size()
	for actor_id in expected_positions:
		if not actual_positions.has(actor_id) or LocalRoomRules.coord(actual_positions[actor_id]) != LocalRoomRules.coord(expected_positions[actor_id]): positions_match = false
	if actor_ids != manifest.get("actor_ids", []) or not positions_match or int(owner.spell_slots.get("1", -1)) != 0 or int(owner.spell_slots.get("3", -1)) != 1 or not bool(remains.get("removed", false)):
		return _fail("Fresh recovery changed actor identity, room placement, slot cost or consumed remains")
	print("ROOM CREATED ACTOR FRESH-PROCESS RECOVERY PASSED: " + JSON.stringify({"owner": owner_id, "actor_ids": actor_ids, "positions": room.get("created_actor_positions", {}), "remains_removed": true}))
	get_tree().quit()

func _fail(message: String) -> void:
	push_error("[RoomCreatedActorRecoveryProbe] " + message)
	get_tree().quit(1)
