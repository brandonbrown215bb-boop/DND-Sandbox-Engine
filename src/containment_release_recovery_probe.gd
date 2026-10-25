extends Node

func _ready() -> void:
	GameManager.test_mode = true
	ContainmentReleaseFlow.fixtures()
	var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string(ContainmentReleaseFlow.MANIFEST))
	if not manifest is Dictionary or manifest.get("pid") == OS.get_process_id(): return _fail("Recovery requires a fresh process")
	for slot in manifest.snapshots:
		if not ContainmentReleaseFlow.verify(slot, manifest.snapshots[slot]): return _fail("Exact checkpoint state changed: " + slot)
		var dungeon: DungeonState = load("res://scenes/dungeon.tscn").instantiate()
		add_child(dungeon)
		await get_tree().process_frame
		dungeon._enter_local_room("0")
		await get_tree().process_frame
		var view := dungeon.local_view
		var room := view.state
		var carrier: Character = view.characters[0]
		var inventory: Dictionary = view.characters[1].inventory.to_dict().duplicate(true)
		if slot.contains("pending"):
			var before: Array = room.containment_occupants.duplicate(true)
			if ContainmentRules.prepare_release(room, view.characters, ContainmentRules.occupants(room, "character", carrier.character_id)).success: return _fail("Blocked recovery invented room space")
			GameManager.advance_campaign_time(6)
			if room.containment_occupants != before: return _fail("Repeated recovered expiry changed pending receipts")
			room.walls = []
			view.refresh()
			var dialog := ContainmentReleaseFlow.release_dialog(view, "character", carrier.character_id)
			if dialog == null: return _fail("Recovered pending release has no continuation")
			dialog.confirmed.emit(); dialog.confirmed.emit()
			await get_tree().process_frame
		else:
			GameManager.advance_campaign_time(12)
			ContainmentRules.advance_internal_damage(room, view.characters, int(GameManager.campaign_elapsed_seconds))
		if not ContainmentRules.occupants(room, "character", carrier.character_id).is_empty() or room.containment_occupants.size() != 1 or view.characters[1].inventory.to_dict() != inventory: return _fail("Recovered release lost bodies, gear or nested relationships")
		var inner := LocalRoomRules.get_object(room, "renamed_inner")
		CombatObjectRules.apply_damage(inner, 100, "force")
		CombatObjectRules.settle_destruction(inner)
		if ContainmentRules.active(room): return _fail("Recovered destruction did not release remaining occupant")
		var room_before := room.duplicate(true)
		CombatObjectRules.settle_destruction(inner)
		if room != room_before: return _fail("Repeated recovered destruction changed released state")
		dungeon.queue_free()
		await get_tree().process_frame
	print("CONTAINMENT RELEASE FRESH-PROCESS RECOVERY PASSED")
	get_tree().quit(0)

func _fail(message: String) -> void:
	push_error(message)
	get_tree().quit(1)
