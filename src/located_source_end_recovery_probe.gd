extends Node

func _ready() -> void:
	GameManager.test_mode = true
	LocatedSourceEndChecks.load_fixtures()
	var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string("user://located_source_end_manifest.json"))
	if not manifest is Dictionary or int(manifest.get("pid", 0)) == OS.get_process_id(): return _fail("Recovery must run in a fresh process")
	if not SaveManager.load_game(LocatedSourceEndControls.SLOT): return _fail("Allowed source-end checkpoint refused")
	var owner: Character = PartyManager.characters.get(str(manifest.owner_id))
	var wizard: Character = PartyManager.characters.get(str(manifest.wizard_id))
	var room: Dictionary = GameManager.active_dungeon_state.get("local_rooms", {}).get(str(manifest.room_id), {})
	if owner == null or wizard == null or room.is_empty(): return _fail("Owner or located room missing")
	var exact_copies: Array = manifest.get("exact_copy_ids", [])
	if exact_copies.size() != 2 or not exact_copies.all(func(id): return owner.inventory.get_instance(str(id)).get("instance_id", "") == str(id)) or not owner.item_projections.is_empty() or not CreatedActorRules.actors(wizard).is_empty(): return _fail("Fresh load changed exact copy identity, retained an ended form, or rebuilt a cleaned-up created actor")
	LocatedSourceEndRules.observe(room, PartyManager.characters.values())
	var objects: Array = room.objects.filter(func(o): return o.has("parent_source_id")).map(func(o): return o.id)
	var areas: Array = room.areas.filter(func(a): return a.has("parent_source_id")).map(func(a): return a.id)
	if objects != manifest.object_ids or areas != manifest.area_ids or owner.current_hp != int(manifest.hp) or int(owner.feature_uses.get(LocatedSourceEndChecks.MODE, -1)) != int(manifest.uses) or int(wizard.spell_slots.get("1", -1)) != int(manifest.slot_count) or room.source_end_continuations.size() != int(manifest.queue_count): return _fail("Fresh load replayed a child/cost or changed successor identity")
	GameManager.advance_campaign_time(720)
	var requests := LocatedSourceEndRules.observe(room, PartyManager.characters.values())
	if requests.size() != 1: return _fail("Waiting timer did not resume exactly one child")
	var request: Dictionary = requests[0]
	var result := LocatedSourceEndRules.answer(room, str(request.invocation), str(request.child_id), true, PartyManager.characters.values())
	LocatedSourceEndRules.observe(room, PartyManager.characters.values())
	if not result.get("success", false) or owner.current_hp != int(manifest.hp) + 4 or int(owner.feature_uses[LocatedSourceEndChecks.MODE]) != int(manifest.uses): return _fail("Recovered child did not settle once")
	var new_objects: Array = room.objects.filter(func(o): return o.has("parent_source_id") and o.id not in objects)
	var expected_exact: Array = manifest.get("exact_expected_objects", [])
	var exact_recovered := expected_exact.all(func(expected): return new_objects.any(func(o): return o.get("id", "") == expected.id and o.get("name", "") == expected.name and LocalRoomRules.coord(o.get("position", [])) == LocalRoomRules.coord(expected.position) and o.get("parent_source_id", "") == expected.source_id))
	if new_objects.size() != expected_exact.size() + 1 or not exact_recovered or LocalRoomRules.coord(new_objects.filter(func(o): return o.get("name", "") == "Cooling remnant")[0].position) != LocalRoomRules.coord(manifest.origin) or not DungeonPersistence.local_error(room).is_empty(): return _fail("Recovered exact successor lost its identity/location or replayed a child: " + DungeonPersistence.local_error(room))
	if LocatedSourceEndRules.answer(room, str(request.invocation), str(request.child_id), true, PartyManager.characters.values()).get("success", false): return _fail("Recovered child replay accepted")
	print("LOCATED SOURCE END FRESH-PROCESS RECOVERY PASSED")
	get_tree().quit()

func _fail(message: String) -> void:
	push_error("[LocatedSourceEndRecovery] " + message)
	get_tree().quit(1)
