extends Node

func _ready() -> void:
	GameManager.test_mode = true
	ProjectedVesselFlow.fixtures()
	var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string(ProjectedVesselFlow.MANIFEST))
	if not manifest is Dictionary or int(manifest.get("pid", 0)) == OS.get_process_id(): return _fail("Recovery requires a fresh process")
	for slot in manifest.snapshots:
		if not ProjectedVesselFlow.verify(slot, manifest.snapshots[slot]): return _fail("Exact vessel checkpoint changed: " + slot)
		var dungeon: DungeonState = load("res://scenes/dungeon.tscn").instantiate()
		add_child(dungeon)
		await get_tree().process_frame
		dungeon._enter_local_room("0")
		await get_tree().process_frame
		var view := dungeon.local_view
		var owner: Character = PartyManager.characters.get(str(manifest.owner))
		var passenger: Character = PartyManager.characters.get(str(manifest.passenger))
		var gear := passenger.inventory.to_dict().duplicate(true)
		if slot.contains("pending"):
			var record: Dictionary = owner.item_projections[manifest.doomed].duplicate(true)
			for _i in 3: ItemProjectionRules.settle(owner)
			if owner.item_projections.get(manifest.doomed) != record or not ItemFormReturnControls.find(view.state, manifest.cargo).is_empty(): return _fail("Blocked recovery partially settled or replayed destruction")
			view.state.walls = []
			var result := ItemProjectionRules.revert(owner, str(manifest.doomed))
			if not result.reverted or not result.destroyed or ItemProjectionRules.is_projected(owner, manifest.doomed) or ItemFormReturnControls.find(view.state, manifest.cargo).get("state", {}).get("cargo_stamp") != "recover this same cargo" or not ContainmentRules.relation(view.state, "character", passenger.character_id).is_empty(): return _fail("Recovered destruction lost exact cargo/passenger")
			var before := view.state.duplicate(true)
			ItemProjectionRules.settle(owner); ItemProjectionRules.revert(owner, str(manifest.doomed))
			if before != view.state: return _fail("Repeated recovered ending duplicated cargo")
		elif slot.contains("active"):
			for id in owner.item_projections.keys():
				var body := ItemProjectionRules.actor(owner, str(id))
				var location := ContainmentRules.location(view.state, "character", body.character_id, view.characters)
				if location.get("kind") != "external": return _fail("Recovered vessel lost actual location")
				var ended := ItemProjectionRules.revert(owner, str(id), -1, "reverted")
				if not ended.reverted: return _fail("Recovered loaded vessel cannot revert")
		if gear != passenger.inventory.to_dict() or not DungeonPersistence.local_error(view.state).is_empty(): return _fail("Recovered vessel release changed gear or broke room DTO")
		dungeon.queue_free()
		await get_tree().process_frame
	print("PROJECTED VESSEL FRESH-PROCESS RECOVERY PASSED")
	get_tree().quit(0)

func _fail(message: String) -> void:
	push_error(message)
	get_tree().quit(1)
