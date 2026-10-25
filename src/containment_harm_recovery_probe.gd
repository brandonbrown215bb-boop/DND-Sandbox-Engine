extends Node

func _ready() -> void:
	GameManager.test_mode = true
	ContainmentHarmFlow.fixtures()
	var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string(ContainmentHarmFlow.MANIFEST))
	if not manifest is Dictionary or manifest.get("pid") == OS.get_process_id(): return _fail("Recovery requires a fresh process")
	for slot in manifest.snapshots:
		var expected: Dictionary = manifest.snapshots[slot]
		if not ContainmentHarmFlow.verify(slot, expected): return _fail("Checkpoint replay or exact identity mismatch: " + slot)
		var dungeon: DungeonState = load("res://scenes/dungeon.tscn").instantiate()
		add_child(dungeon)
		await get_tree().process_frame
		dungeon.hex_grid.hex_clicked.emit(dungeon.party_position)
		await get_tree().process_frame
		var view := dungeon.local_view
		if view == null: return _fail("Recovered room failed to reopen")
		var room := view.state
		var before: Array = room.containment_occupants.duplicate(true)
		if not ContainmentFlow.select(view, "ContainmentContainers", "object", "chamber_a") or not TetherGroupFlow.press(view, "Inspect occupants"): return _fail("Recovered exact inspection unavailable")
		if slot.contains("pending"):
			if not view.hud.log_text.text.contains("deferred"): return _fail("Pending settlement is not visible")
			for row in room.containment_occupants:
				if not row.has("release_pending"): return _fail("Pending release disappeared")
				var occupant = ContainmentRules.entity(room, view.characters, row.occupant_kind, row.occupant_id)
				var result := ContainmentRules.prepare_check(room, view.characters, occupant if occupant is Character else view.actor(), row.occupant_kind, row.occupant_id, "escape")
				if result.success or int(result.get("seconds", 0)) != 0: return _fail("Recovered release permits repeated check/cost")
		TetherGroupFlow.press(view, "Room map")
		await get_tree().process_frame
		if not SaveManager.save_game("containment_harm_resaved") or not ContainmentHarmFlow.verify("containment_harm_resaved", expected): return _fail("Re-save replayed settlement")
		# Active timers continue exactly once after recovery; pending ones remain frozen.
		room = GameManager.active_dungeon_state.local_rooms["0"]
		var amounts := {}
		for row in room.containment_occupants:
			var body = ContainmentRules.entity(room, PartyManager.characters.values(), row.occupant_kind, row.occupant_id)
			amounts[ContainmentRules.key(row.occupant_kind, row.occupant_id)] = body.current_hp if body is Character else int(body.hp)
		GameManager.advance_campaign_time(6)
		for row in room.containment_occupants:
			var body = ContainmentRules.entity(room, PartyManager.characters.values(), row.occupant_kind, row.occupant_id)
			var hp: int = body.current_hp if body is Character else int(body.hp)
			var prior := int(amounts[ContainmentRules.key(row.occupant_kind, row.occupant_id)])
			if hp != prior - (0 if row.has("release_pending") else 2): return _fail("Recovered timer lost or replayed damage")
		if not ContainmentRules.advance_internal_damage(room, PartyManager.characters.values(), int(GameManager.campaign_elapsed_seconds)).is_empty(): return _fail("Repeated recovered tick replayed")
		dungeon.queue_free()
		await get_tree().process_frame
	print("CONTAINMENT HARM FRESH-PROCESS RECOVERY PASSED")
	get_tree().quit(0)

func _fail(message: String) -> void:
	push_error(message)
	get_tree().quit(1)
