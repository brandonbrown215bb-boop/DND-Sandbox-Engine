class_name Batch068Controls
extends RefCounted
## Batch 068 (S-196/S-210): the real room Stow / Take out / Attach / Detach
## buttons offer exact compartments, contents, sockets and parts when two or
## more are eligible. Dismissing spends nothing and passes no time; a stale pick
## is refused before anything moves; a replayed pick is ignored; only the
## chosen identity moves. Real save/load here; batch_068_exact_contents_reload
## rechecks the placements in a fresh process.

const SLOT := "batch_068_exact_contents"
const IDS := "user://batch_068_ids.json"

static func _select(view: LocalRoomView, id: String) -> bool:
	view.refresh()
	for i in view.items.item_count:
		if str(view.items.get_item_metadata(i)) == id:
			view.items.select(i)
			view._refresh_item_actions()
			return true
	return false

## Press a real button with `id` selected; return the open choice menu (or null).
static func _press(h: Node, view: LocalRoomView, id: String, label: String) -> PopupMenu:
	if not _select(view, id):
		h._assert(false, "068 copy is listed in the room item selector")
		return null
	view.exact_choice_menu = null
	h._local_room_press(view, label)
	return view.exact_choice_menu

static func _index(options: Array, k1: String, v1: String, k2: String, v2: String) -> int:
	for i in options.size():
		if str(options[i].get(k1, "")) == v1 and str(options[i].get(k2, "")) == v2: return i
	return -1

static func run(h: Node) -> void:
	h._enter_test("batch_068_exact_contents_flow")
	h._setup_world()
	Batch068Checks.load_fixtures()
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
	var inv := c.inventory
	var s1 := Batch043Checks.add(c, Batch068Checks.SAT)
	var s2 := Batch043Checks.add(c, Batch068Checks.SAT)
	var f1 := Batch043Checks.add(c, Batch068Checks.FLASK)
	var f2 := Batch043Checks.add(c, Batch068Checks.FLASK)
	var clock := int(GameManager.campaign_elapsed_seconds)
	# Cancel: the real Stow button opens the exact menu; dismissing it spends nothing.
	var options := ContainerRules.stow_options(inv, f1)
	var menu := _press(h, view, f1, "Stow")
	h._assert(menu != null and menu.item_count == 4 and options.size() == 4, "068 actual Stow with two satchel copies opens a menu of all four exact compartments")
	var snapshot := inv.to_dict()
	if menu != null: menu.hide()
	await h.get_tree().process_frame
	h._assert(inv.to_dict() == snapshot and int(GameManager.campaign_elapsed_seconds) == clock, "068 actual dismissing the compartment menu moves nothing and passes no time")
	# Stale: the chosen satchel leaves the holder while the menu is open.
	menu = _press(h, view, f1, "Stow")
	var gone := inv.take_instance(s2)
	snapshot = inv.to_dict()
	if menu != null: menu.id_pressed.emit(_index(options, "container_id", s2, "compartment", "sleeve"))
	h._assert(menu != null and inv.to_dict() == snapshot and Batch043Checks.owns(c, f1) and int(GameManager.campaign_elapsed_seconds) == clock, "068 actual a satchel that left while the menu was open refuses before any time or movement")
	inv.receive_instance(gone)
	# Choose the second satchel's sleeve; a replayed pick is ignored.
	menu = _press(h, view, f1, "Stow")
	var index := _index(options, "container_id", s2, "compartment", "sleeve")
	if menu != null:
		menu.id_pressed.emit(index)
		menu.id_pressed.emit(index)
	var placed := ContainerRules.contents(inv, s2, "sleeve").map(func(r): return str(r.instance_id))
	h._assert(placed == [f1] and ContainerRules.contents(inv, s1).is_empty() and Batch043Checks.owns(c, f2) and int(GameManager.campaign_elapsed_seconds) == clock + 6, "068 actual choosing the second satchel's sleeve stows exactly that flask there once (6 s, replay ignored)")
	options = ContainerRules.stow_options(inv, f2)
	menu = _press(h, view, f2, "Stow")
	if menu != null: menu.id_pressed.emit(_index(options, "container_id", s2, "compartment", "main"))
	h._assert(ContainerRules.contents(inv, s2, "main").map(func(r): return str(r.instance_id)) == [f2], "068 actual the second flask goes into the chosen main compartment")
	# Take out: both flasks are offered; the earlier one (not last-out) is taken.
	var held := ContainerRules.content_options(inv, s2)
	var t0 := int(GameManager.campaign_elapsed_seconds)
	menu = _press(h, view, s2, "Take out")
	h._assert(menu != null and menu.item_count == 2, "068 actual Take out with two contained flasks opens the exact copy menu")
	if menu != null: menu.hide()
	await h.get_tree().process_frame
	h._assert(ContainerRules.contents(inv, s2).size() == 2 and int(GameManager.campaign_elapsed_seconds) == t0, "068 actual dismissing the take-out menu moves nothing")
	menu = _press(h, view, s2, "Take out")
	if menu != null: menu.id_pressed.emit(_index(held, "instance_id", f1, "compartment", "sleeve"))
	h._assert(Batch043Checks.owns(c, f1) and ContainerRules.contents(inv, s2).map(func(r): return str(r.instance_id)) == [f2] and int(GameManager.campaign_elapsed_seconds) == t0 + 6, "068 actual choosing the first-stowed flask takes out exactly it")
	# Parts: two hosts and two gems through the real Attach / Detach buttons.
	var h1 := Batch044Checks.add(c, Batch068Checks.HOST)
	var h2 := Batch044Checks.add(c, Batch068Checks.HOST)
	var g1 := Batch044Checks.add(c, Batch068Checks.GEM)
	var g2 := Batch044Checks.add(c, Batch068Checks.GEM)
	var sockets := AttachmentRules.socket_options(inv, g1)
	menu = _press(h, view, g1, "Attach")
	h._assert(menu != null and menu.item_count == sockets.size() and sockets.size() == 6, "068 actual Attach with two hosts opens every exact eligible socket")
	if menu != null: menu.id_pressed.emit(_index(sockets, "host_id", h2, "socket", "gem_b"))
	sockets = AttachmentRules.socket_options(inv, g2)
	menu = _press(h, view, g2, "Attach")
	if menu != null: menu.id_pressed.emit(_index(sockets, "host_id", h2, "socket", "gem_a"))
	h._assert(AttachmentRules.attached(inv, h1).is_empty() and str(AttachmentRules.attached(inv, h2).get("gem_b", {}).get("instance_id", "")) == g1 and str(AttachmentRules.attached(inv, h2).get("gem_a", {}).get("instance_id", "")) == g2, "068 actual the chosen gems fill exactly the chosen sockets of the chosen host")
	var parts := AttachmentRules.part_options(inv, h2)
	menu = _press(h, view, h2, "Detach")
	# Stale: the gem_b part is swapped while the menu is open.
	var swap := AttachmentRules.detach(inv, h2, "gem_b")
	var g3 := Batch044Checks.add(c, Batch068Checks.GEM)
	AttachmentRules.attach(inv, h2, g3, "gem_b")
	snapshot = inv.to_dict()
	var t1 := int(GameManager.campaign_elapsed_seconds)
	if menu != null: menu.id_pressed.emit(_index(parts, "instance_id", g1, "socket", "gem_b"))
	h._assert(swap.success and inv.to_dict() == snapshot and int(GameManager.campaign_elapsed_seconds) == t1, "068 actual a part swapped while the detach menu was open is refused; the new part stays and no time passes")
	parts = AttachmentRules.part_options(inv, h2)
	menu = _press(h, view, h2, "Detach")
	if menu != null: menu.id_pressed.emit(_index(parts, "instance_id", g2, "socket", "gem_a"))
	h._assert(Batch044Checks.owns(c, g2) and AttachmentRules.attached(inv, h2).keys() == ["gem_b"] and str(AttachmentRules.attached(inv, h2).gem_b.instance_id) == g3 and int(GameManager.campaign_elapsed_seconds) == t1 + 6, "068 actual detaching the chosen gem (not last-filled) moves only it")
	var cid := c.character_id
	FileAccess.open(IDS, FileAccess.WRITE).store_string(JSON.stringify({"cid": cid, "s1": s1, "s2": s2, "f1": f1, "f2": f2, "h1": h1, "h2": h2, "g3": g3}))
	h._teardown_scene(dungeon)
	GameManager.current_state = GameManager.GameState.OVERWORLD
	GameManager.game_in_progress = true
	var block := SaveManager.get_save_block_reason()
	var saved: bool = block.is_empty() and SaveManager.save_game(SLOT)
	h._assert(saved, "068 actual real save (block='%s')" % block)
	if saved:
		var loaded := SaveManager.load_game(SLOT)
		var nc: Character = PartyManager.characters.get(cid, null)
		h._assert(loaded and nc != null and _placed(nc, s1, s2, f2, h1, h2, g3), "068 actual real load keeps each chosen copy in its chosen container and socket")
	h._exit_test()

static func _placed(c: Character, s1: String, s2: String, f2: String, h1: String, h2: String, g3: String) -> bool:
	var inv := c.inventory
	return ContainerRules.contents(inv, s2, "main").map(func(r): return str(r.instance_id)) == [f2] and ContainerRules.contents(inv, s1).is_empty() and AttachmentRules.attached(inv, h1).is_empty() and AttachmentRules.attached(inv, h2).keys() == ["gem_b"] and str(AttachmentRules.attached(inv, h2).gem_b.instance_id) == g3 and ContainerRules.content_options(inv, s2).size() == 1 and AttachmentRules.part_options(inv, h2).size() == 1

## Fresh process: reload the slot written by the flow scenario, then delete it.
static func reload(h: Node) -> void:
	h._enter_test("batch_068_exact_contents_reload")
	Batch068Checks.load_fixtures()
	var ids: Variant = JSON.parse_string(FileAccess.get_file_as_string(IDS))
	var loaded := SaveManager.load_game(SLOT)
	var nc: Character = PartyManager.characters.get(str(ids.cid), null) if ids is Dictionary else null
	h._assert(loaded and nc != null and _placed(nc, str(ids.s1), str(ids.s2), str(ids.f2), str(ids.h1), str(ids.h2), str(ids.g3)), "068 fresh process the exact contents and attached part are where they were chosen")
	if nc != null:
		var out := ContainerRules.take_out(nc.inventory, ContainerRules.content_options(nc.inventory, str(ids.s2))[0])
		h._assert(out.success and str(out.instance_id) == str(ids.f2) and Batch043Checks.owns(nc, str(ids.f2)), "068 fresh process the reloaded exact copy can be taken out once")
	SaveManager.delete_save(SLOT)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(IDS))
	h._exit_test()
