class_name Batch069Controls
extends RefCounted
## Batch 069 (S-032/S-196): the real room Place / Inspect / Take / Inspect item
## controls keep a Bell's missing weight unknown. A refused Place spends no
## time; Take moves the copy once; a legacy 1 lb stamp is migrated on a real
## load. batch_069_unknown_weight_reload rechecks in a fresh process.

const SLOT := "batch_069_unknown_weight"
const IDS := "user://batch_069_ids.json"

static func _select_item(view: LocalRoomView, id: String) -> bool:
	view.refresh()
	for i in view.items.item_count:
		if str(view.items.get_item_metadata(i)) == id:
			view.items.select(i)
			view._refresh_item_actions()
			return true
	return false

static func _select_object(view: LocalRoomView, id: String) -> bool:
	view.refresh()
	for i in view.objects.item_count:
		if str(view.objects.get_item_metadata(i)) == id:
			view.objects.select(i)
			view.objects.item_selected.emit(i)
			return true
	return false

static func _log(view: LocalRoomView) -> String:
	return str(view.hud.log_text.text) if view.hud != null and view.hud.log_text != null else ""

static func _room_with(object_id: String) -> Dictionary:
	for room in GameManager.active_dungeon_state.get("local_rooms", {}).values():
		if room is Dictionary and not LocalRoomRules.get_object(room, object_id).is_empty(): return room
	return {}

static func run(h: Node) -> void:
	h._enter_test("batch_069_unknown_weight_flow")
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
	var b1 := Batch041Checks.add_copy(c, "bell")
	var b2 := Batch041Checks.add_copy(c, "bell")
	# Inspect item reports the unknown data weight; volume is PARTIAL.
	h._assert(_select_item(view, b1), "069 the Bell copy is listed in the room item selector")
	h._local_room_press(view, "Inspect item")
	h._assert(_log(view).contains("Weight: unknown") and _log(view).contains("PARTIAL"), "069 actual Inspect item says the Bell's weight is unknown and volume is PARTIAL")
	# Place the exact copy: no invented 1 lb / Tiny / mixed.
	var clock := int(GameManager.campaign_elapsed_seconds)
	h._local_room_press(view, "Place")
	var placed := LocalRoomRules.get_object(state, "placed:" + b1)
	h._assert(not placed.is_empty() and not placed.has("weight_lb") and not placed.has("size") and not placed.has("material") and int(GameManager.campaign_elapsed_seconds) == clock + 6 and c.inventory.get_instance(b1).is_empty(), "069 actual Place drops the exact Bell with unknown measurements for one 6-second action")
	# Refuse before paying: the cell is occupied; the second Bell stays held and no time passes.
	h._assert(_select_item(view, b2), "069 the second Bell is listed")
	var held_before := c.inventory.to_dict()
	clock = int(GameManager.campaign_elapsed_seconds)
	h._local_room_press(view, "Place")
	h._assert(int(GameManager.campaign_elapsed_seconds) == clock and c.inventory.to_dict() == held_before and LocalRoomRules.get_object(state, "placed:" + b2).is_empty(), "069 actual a refused Place spends no time and moves nothing")
	# Inspect the room object: every missing measurement is named unknown.
	h._assert(_select_object(view, "placed:" + b1), "069 the placed Bell is listed as a room object")
	h._local_room_press(view, "Inspect")
	h._assert(_log(view).contains("unknown material, unknown size, unknown weight") and int(GameManager.campaign_elapsed_seconds) == clock, "069 actual Inspect names the unknown measurements and spends no time")
	# Take once: the copy carries no invented measurement; a replay is refused.
	view.refresh()
	view.contents.select(0)
	h._local_room_press(view, "Take")
	var back := c.inventory.get_instance(b1)
	h._assert(not back.is_empty() and not back.state.get("physical", {}).has("weight_lb") and int(GameManager.campaign_elapsed_seconds) == clock + 6, "069 actual Take returns the exact Bell once with weight still unknown")
	clock = int(GameManager.campaign_elapsed_seconds)
	var replay := LocalRoomRules.interact(state, "placed:" + b1, "take", c, b1)
	h._assert(not replay.success and int(GameManager.campaign_elapsed_seconds) == clock and c.inventory.count_item("bell") == 2, "069 a stale Take of the already-taken Bell is refused; the cost was paid once")
	# A legacy 1 lb stamp written by an old build: object and held copy.
	var pos: Array = state.party_positions[c.character_id]
	var legacy := Batch069Checks.legacy_object("b069:legacy", "bell", Vector2i(int(pos[0]), int(pos[1])))
	legacy.contents[0].state = Batch069Checks.legacy_record("b069:legacy", "bell").state
	legacy.contents[0].state.physical.room_id = str(state.id)
	state.objects.append(legacy)
	var cid := c.character_id
	FileAccess.open(IDS, FileAccess.WRITE).store_string(JSON.stringify({"cid": cid, "b1": b1, "b2": b2}))
	h._teardown_scene(dungeon)
	GameManager.current_state = GameManager.GameState.OVERWORLD
	GameManager.game_in_progress = true
	var block := SaveManager.get_save_block_reason()
	var saved: bool = block.is_empty() and SaveManager.save_game(SLOT)
	h._assert(saved, "069 actual real save (block='%s')" % block)
	if saved:
		var loaded := SaveManager.load_game(SLOT)
		h._assert(loaded and check_loaded(str(cid), b1), "069 actual real load: the legacy stamp is unknown again and the taken Bell keeps unknown weight")
	h._exit_test()

static func check_loaded(cid: String, b1: String) -> bool:
	var nc: Character = PartyManager.characters.get(cid, null)
	var room := _room_with("placed:b069:legacy")
	var object := LocalRoomRules.get_object(room, "placed:b069:legacy")
	if nc == null or object.is_empty(): return false
	var copy: Dictionary = object.contents[0]
	return not object.has("weight_lb") and not object.has("size") and not object.has("material") and not copy.state.physical.has("weight_lb") and not nc.inventory.get_instance(b1).get("state", {}).get("physical", {}).has("weight_lb") and PhysicalFactsRules.get_mass_lb(object) == null

## Fresh process: reload the slot written by the flow scenario, then delete it.
static func reload(h: Node) -> void:
	h._enter_test("batch_069_unknown_weight_reload")
	var ids: Variant = JSON.parse_string(FileAccess.get_file_as_string(IDS))
	var loaded := SaveManager.load_game(SLOT)
	h._assert(loaded and ids is Dictionary and check_loaded(str(ids.cid), str(ids.b1)), "069 fresh process the legacy room copy and the taken Bell keep unknown weight")
	if loaded and ids is Dictionary:
		var room := _room_with("placed:b069:legacy")
		var nc: Character = PartyManager.characters.get(str(ids.cid), null)
		var copy := LocalRoomRules.placed_item(room, LocalRoomRules.get_object(room, "placed:b069:legacy").contents[0], Vector2i.ZERO)
		h._assert(not copy.has("weight_lb") and nc != null and nc.inventory.count_item("bell") == 2, "069 fresh process a re-placement payload of the migrated copy still has no invented weight")
	SaveManager.delete_save(SLOT)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(IDS))
	h._exit_test()
