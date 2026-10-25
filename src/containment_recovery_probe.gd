extends Node

func _ready() -> void:
	GameManager.test_mode = true
	ContainmentFlow.fixtures()
	var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string(ContainmentFlow.MANIFEST))
	if not manifest is Dictionary or manifest.get("pid") == OS.get_process_id(): return _fail("Recovery must use a fresh process")
	for slot in [ContainmentFlow.SLOT, ContainmentFlow.PLAYER_SLOT]:
		if not ContainmentFlow.verify(manifest, slot): return _fail("Exact relationship or gear changed in " + slot)
		var dungeon: DungeonState = load("res://scenes/dungeon.tscn").instantiate()
		add_child(dungeon)
		await get_tree().process_frame
		dungeon.hex_grid.hex_clicked.emit(dungeon.party_position)
		await get_tree().process_frame
		var view := dungeon.local_view
		if view == null or not ContainmentFlow.select(view, "ContainmentContainers", "object", "chamber_a") or not TetherGroupFlow.press(view, "Inspect occupants"): return _fail("Recovered controls cannot reopen and inspect exact occupants")
		for entity in view.grid.entities:
			var actor = entity.get("character")
			if actor is Character and not ContainmentRules.relation(view.state, "character", actor.character_id).is_empty(): return _fail("Internal occupant returned to the external room grid")
		TetherGroupFlow.press(view, "Room map")
		await get_tree().process_frame
		# Re-saving and loading cannot re-enter or append an occupant.
		if not SaveManager.save_game("containment_resaved") or not ContainmentFlow.verify(manifest, "containment_resaved"): return _fail("Re-save replayed an admission")
		dungeon.queue_free()
		await get_tree().process_frame
	print("CONTAINMENT FRESH-PROCESS RECOVERY PASSED")
	get_tree().quit(0)

func _fail(message: String) -> void:
	push_error(message)
	get_tree().quit(1)
