class_name Batch078Controls
extends RefCounted
## Batch 078 (S-032/S-196): the real room Inspect / Put controls use declared
## container capacity, label the engine technical limit separately, keep the
## Bell's weight unknown and show a filled SRD weight.

static func _log(view: LocalRoomView) -> String:
	return str(view.hud.log_text.text) if view.hud != null and view.hud.log_text != null else ""

static func _select_object(view: LocalRoomView, id: String) -> bool:
	view.refresh()
	for i in view.objects.item_count:
		if str(view.objects.get_item_metadata(i)) == id:
			view.objects.select(i)
			view.objects.item_selected.emit(i)
			return true
	return false

static func _pick_item(view: LocalRoomView, id: String) -> bool:
	for i in view.items.item_count:
		if str(view.items.get_item_metadata(i)) == id:
			view.items.select(i)
			view._refresh_item_actions()
			return true
	return false

static func run(h: Node) -> void:
	h._enter_test("batch_078_declared_capacity_flow")
	h._setup_world()
	GameManager._reset_campaign_ledgers()
	GameManager.active_dungeon_state.clear()
	GameManager.game_in_progress = true
	GameManager.current_state = GameManager.GameState.DUNGEON
	GameManager.transition_context = {"dungeon_id": "ruins_of_ashvale"}
	var dungeon: DungeonState = await h._spawn_scene("res://scenes/dungeon.tscn", 0.2)
	var room: Room
	for candidate in dungeon.rooms.values():
		if candidate.id == 1: room = candidate
	dungeon.hex_grid.hex_clicked.emit(room.coord)
	await h.get_tree().process_frame
	var view: LocalRoomView = dungeon.local_view
	var c: Character = view.actor()
	var state: Dictionary = view.state
	var pos: Array = state.party_positions[c.character_id]
	state.objects.append({"id": "b078_declared", "kind": "container", "name": "Declared box", "position": [int(pos[0]), int(pos[1])], "open": true, "contents": [], "capacity": 1, "hp": 1, "max_hp": 1})
	state.objects.append({"id": "b078_undeclared", "kind": "container", "name": "Plain box", "position": [int(pos[0]), int(pos[1])], "open": true, "contents": [], "hp": 1, "max_hp": 1})
	var d1 := Batch041Checks.add_copy(c, "dagger")
	var d2 := Batch041Checks.add_copy(c, "dagger")
	var bell := Batch041Checks.add_copy(c, "bell")
	view.refresh()
	h._assert(_pick_item(view, bell), "078 the Bell copy is listed")
	h._local_room_press(view, "Inspect item")
	h._assert(_log(view).contains("Weight: unknown"), "078 actual Inspect item: the Bell's SRD '—' weight stays unknown")
	h._assert(_pick_item(view, d1), "078 the Dagger copy is listed")
	h._local_room_press(view, "Inspect item")
	h._assert(_log(view).contains("Weight: 1 lb"), "078 actual Inspect item: the filled SRD Dagger weight (1 lb, p.91) is shown")
	h._assert(_select_object(view, "b078_undeclared"), "078 the undeclared box is listed")
	h._local_room_press(view, "Inspect")
	h._assert(_log(view).contains("capacity undeclared; engine technical limit") and _log(view).contains("(not a game rule)"), "078 actual Inspect: undeclared capacity shows no fake 20 and the technical limit is labeled separately")
	h._assert(_select_object(view, "b078_declared"), "078 the declared box is listed")
	h._local_room_press(view, "Inspect")
	h._assert(_log(view).contains("capacity 1 items (declared)"), "078 actual Inspect: declared capacity is reported")
	h._assert(_pick_item(view, d1), "078 first Dagger selected for Put")
	h._local_room_press(view, "Put")
	var box := LocalRoomRules.get_object(state, "b078_declared")
	h._assert(box.contents.size() == 1 and c.inventory.get_instance(d1).is_empty(), "078 actual Put stows one copy within declared capacity")
	_select_object(view, "b078_declared")
	h._assert(_pick_item(view, d2), "078 second Dagger selected for Put")
	h._local_room_press(view, "Put")
	h._assert(box.contents.size() == 1 and not c.inventory.get_instance(d2).is_empty() and _log(view).contains("declared capacity 1"), "078 actual Put is refused at the declared capacity and the copy stays held")
	# Legacy shape: a container saved before Batch 078 with no capacity key validates and reads as undeclared.
	var roundtrip: Dictionary = JSON.parse_string(JSON.stringify(state))
	var err := DungeonPersistence.local_error(roundtrip)
	h._assert(err.is_empty() and RoomMeasurements.declared_capacity(LocalRoomRules.get_object(roundtrip, "b078_undeclared")) == null, "078 a container saved without capacity validates and loads as undeclared (%s)" % err)
	h._teardown_scene(dungeon)
	h._exit_test()
