class_name Batch074Controls
extends RefCounted
## Batch 074 (S-066): the real room Start work / Join work / Wait 8 hours
## controls and room clicks. A helper too far from the site is refused at the
## confirmed join; cancelling the join offer changes nothing; a helper who moves
## away between offer and confirm is refused; moving away pauses, returning
## resumes without crediting away time; a long jump lapses the pause at the
## exact limit and resets. Real save/load plus batch_074_work_site_reload.

const SLOT := "batch_074_work_site"
const IDS := "user://batch_074_ids.json"

static func _select_item(view: LocalRoomView, id: String) -> bool:
	view.refresh()
	for i in view.items.item_count:
		if str(view.items.get_item_metadata(i)) == id:
			view.items.select(i)
			view._refresh_item_actions()
			return true
	return false

static func _act_as(view: LocalRoomView, c: Character) -> void:
	for i in view.characters.size():
		if view.characters[i] == c:
			view.actors.select(i)
			view.actors.item_selected.emit(i)
	view.refresh()

static func _pos(view: LocalRoomView, c: Character) -> Vector2i:
	return LocalRoomRules.coord(view.state.party_positions[c.character_id])

## Click-move the acting character to a cell `feet` from `site` (exact), returning success.
static func _walk(h: Node, view: LocalRoomView, c: Character, site: Vector2i, feet: int) -> bool:
	_act_as(view, c)
	var start := _pos(view, c)
	if start != site and HexUtils.get_distance(start, site) * 5 == feet: return true
	for cell in HexUtils.get_hexes_in_range(site, feet / 5):
		if HexUtils.get_distance(cell, site) * 5 != feet or HexUtils.get_distance(cell, start) > 5: continue
		if not LocalRoomRules.passable(view.state, cell) or not LocalRoomRules.object_at(view.state, cell).is_empty(): continue
		view.click(cell)
		await h.get_tree().process_frame
		if _pos(view, c) == cell: return true
	return false

static func _menu(view: LocalRoomView) -> PopupMenu:
	return view.exact_choice_menu

static func run(h: Node) -> void:
	h._enter_test("batch_074_work_site_flow")
	h._setup_world()
	Batch074Checks.load_fixtures()
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
	var a: Character = PlayerManager.get_player(0).get("character")
	var b: Character = PlayerManager.get_player(1).get("character")
	var loom := Batch041Checks.add_copy(a, Batch074Checks.LOOM)
	# Start: the exact cell is recorded as the site.
	_act_as(view, a)
	h._assert(_select_item(view, loom), "074 the loom copy is listed")
	h._local_room_press(view, "Start work")
	var site := _pos(view, a)
	var rec := a.inventory.get_instance(loom)
	h._assert(WorkRules.is_active(rec) and LocalRoomRules.coord(rec.state.work_site.position) == site and str(rec.state.work_site.room_id) == str(GameManager.active_dungeon_state.local_room_id) and not str(rec.state.work_site.room_id).is_empty(), "074 actual Start work records the represented start cell as the site")
	# Too far: refused at the confirmed join, nothing changed, no clock.
	h._assert(await _walk(h, view, b, site, 15), "074 Bob walks 15 feet from the site")
	var clock := int(GameManager.campaign_elapsed_seconds)
	var before := a.inventory.get_instance(loom)
	h._local_room_press(view, "Join work")
	var menu := _menu(view)
	h._assert(menu != null and menu.item_count == 1, "074 actual Join work offers Alice's work for confirmation")
	if menu != null: menu.id_pressed.emit(0)
	h._assert(a.inventory.get_instance(loom) == before and int(GameManager.campaign_elapsed_seconds) == clock, "074 actual a helper 15 feet away is refused at the join; nothing changes and no time passes")
	# Cancel the offer: nothing changes.
	h._assert(await _walk(h, view, b, site, 10), "074 Bob walks back to 10 feet")
	before = a.inventory.get_instance(loom)
	h._local_room_press(view, "Join work")
	menu = _menu(view)
	var offered := menu != null
	if offered: menu.hide()
	await h.get_tree().process_frame
	h._assert(offered and a.inventory.get_instance(loom).state.work_participants == [a.character_id], "074 actual dismissing the join offer joins nobody")
	# Stale: Bob moves away between offer and confirm.
	h._local_room_press(view, "Join work")
	menu = _menu(view)
	var stale_offered := menu != null
	var moved := await _walk(h, view, b, site, 15)
	if stale_offered and is_instance_valid(menu): menu.id_pressed.emit(0)
	h._assert(moved and stale_offered and a.inventory.get_instance(loom).state.work_participants == [a.character_id], "074 actual a helper who moved away after the offer is refused at confirmation")
	# Join for real and wait.
	h._assert(await _walk(h, view, b, site, 10), "074 Bob returns to 10 feet")
	h._local_room_press(view, "Join work")
	menu = _menu(view)
	if menu != null: menu.id_pressed.emit(0)
	h._assert(a.inventory.get_instance(loom).state.work_participants == [a.character_id, b.character_id], "074 actual a helper within 10 feet joins on confirmation")
	var p0 := WorkRules.progress(a.inventory.get_instance(loom))
	h._local_room_press(view, "Wait 8 hours")
	var p1 := WorkRules.progress(a.inventory.get_instance(loom))
	h._assert(p1 - p0 == 28800, "074 actual Wait 8 hours accrues 8 hours with both at the site (%d)" % (p1 - p0))
	# Away and back: no away time is credited.
	h._assert(await _walk(h, view, b, site, 15), "074 Bob steps away")
	h._assert(a.inventory.get_instance(loom).state.has("work_away_since") and WorkRules.progress(a.inventory.get_instance(loom)) == p1, "074 actual the room move itself is the boundary: the work pauses with no away time credited")
	h._local_room_press(view, "Wait 8 hours")
	rec = a.inventory.get_instance(loom)
	h._assert(not WorkRules.is_active(rec) and WorkRules.progress(rec) == 0, "074 actual 8 hours away exceeds the 1-hour limit: reset applies, nothing credited (%d)" % WorkRules.progress(rec))
	# Restart, then save mid-pause for the long jump.
	_act_as(view, a)
	_select_item(view, loom)
	h._local_room_press(view, "Start work")
	site = _pos(view, a)
	h._assert(await _walk(h, view, b, site, 5), "074 Bob comes within 5 feet")
	h._local_room_press(view, "Join work")
	menu = _menu(view)
	if menu != null: menu.id_pressed.emit(0)
	h._local_room_press(view, "Wait 8 hours")
	var kept := WorkRules.progress(a.inventory.get_instance(loom))
	h._assert(await _walk(h, view, b, site, 15), "074 Bob leaves again")
	GameManager.advance_campaign_time(60) # The first away span starts the pause.
	rec = a.inventory.get_instance(loom)
	var since := int(rec.state.get("work_away_since", -1))
	h._assert(kept == 28800 and WorkRules.is_active(rec) and since >= 0 and WorkRules.progress(rec) == kept, "074 actual a paused work keeps its progress (%d) with away_since=%d" % [kept, since])
	FileAccess.open(IDS, FileAccess.WRITE).store_string(JSON.stringify({"a": a.character_id, "loom": loom, "since": since, "kept": kept}))
	h._teardown_scene(dungeon)
	GameManager.current_state = GameManager.GameState.OVERWORLD
	GameManager.game_in_progress = true
	var block := SaveManager.get_save_block_reason()
	var saved: bool = block.is_empty() and SaveManager.save_game(SLOT)
	h._assert(saved, "074 actual real save with paused site work (block='%s')" % block)
	if saved:
		var loaded := SaveManager.load_game(SLOT)
		var na: Character = PartyManager.characters.get(a.character_id, null)
		h._assert(loaded and na != null and na != a and int(na.inventory.get_instance(loom).state.get("work_away_since", -1)) == since and WorkRules.progress(na.inventory.get_instance(loom)) == kept, "074 actual real load keeps the site, the pause and the progress")
	h._exit_test()

## Fresh process: a two-day jump lapses the pause just past away_since + 1 hour and resets.
static func reload(h: Node) -> void:
	h._enter_test("batch_074_work_site_reload")
	Batch074Checks.load_fixtures()
	var ids: Variant = JSON.parse_string(FileAccess.get_file_as_string(IDS))
	var loaded := SaveManager.load_game(SLOT)
	var na: Character = PartyManager.characters.get(str(ids.a), null) if ids is Dictionary else null
	h._assert(loaded and na != null and WorkRules.is_active(na.inventory.get_instance(str(ids.loom))) and int(na.inventory.get_instance(str(ids.loom)).state.work_away_since) == int(ids.since), "074 fresh process the paused site work loads")
	if na != null:
		var receipts := GameManager.advance_campaign_time(2 * 86400)
		var lapse: Array = receipts.filter(func(r): return r.get("interrupted", false) and str(r.get("instance_id", "")) == str(ids.loom))
		var rec := na.inventory.get_instance(str(ids.loom))
		h._assert(lapse.size() == 1 and int(lapse[0].at) == int(ids.since) + 3601 and int(lapse[0].lost_seconds) == int(ids.kept) and WorkRules.progress(rec) == 0 and not WorkRules.is_active(rec), "074 fresh process a two-day jump applies reset just past away_since + 1 hour, crediting none of it")
	SaveManager.delete_save(SLOT)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(IDS))
	h._exit_test()
