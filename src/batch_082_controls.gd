class_name Batch082Controls
extends RefCounted
## Batch 082 (#46 follow-up, S-066): the real room Start work / Join work /
## Wait 8 hours controls with the authored "past 1 hour" pause limit. A helper
## who is away for exactly 60 minutes keeps progress; 61 minutes resets it. The
## item description states "past 1 hour". A real save mid-pause plus
## batch_082_interruption_boundary_reload (fresh process) proves exactly the
## limit is still allowed and one second more resets.

const SLOT := "batch_082_interruption_boundary"
const IDS := "user://batch_082_ids.json"

static func _away_to(rec_since: int, seconds: int) -> void:
	GameManager.advance_campaign_time(rec_since + seconds - int(GameManager.campaign_elapsed_seconds))

static func run(h: Node) -> void:
	h._enter_test("batch_082_interruption_boundary_flow")
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
	var desc := str(DataLoader.get_item(Batch074Checks.LOOM).description)
	h._assert(desc.contains("past 1 hour") and int(DataLoader.get_item(Batch074Checks.LOOM).work.site.away_limit_seconds) == 3600, "082 the loom's description says 'past 1 hour' and matches its authored 3600 s limit")
	Batch074Controls._act_as(view, a)
	h._assert(Batch074Controls._select_item(view, loom), "082 the loom copy is listed")
	h._local_room_press(view, "Start work")
	var site := Batch074Controls._pos(view, a)
	h._assert(await Batch074Controls._walk(h, view, b, site, 10), "082 Bob stands 10 feet from the site")
	h._local_room_press(view, "Join work")
	var menu := Batch074Controls._menu(view)
	if menu != null: menu.id_pressed.emit(0)
	h._local_room_press(view, "Wait 8 hours")
	var kept := WorkRules.progress(a.inventory.get_instance(loom))
	h._assert(kept == 28800, "082 Wait 8 hours accrues with both at the site (%d)" % kept)
	# Exactly 60 minutes away: allowed.
	h._assert(await Batch074Controls._walk(h, view, b, site, 15), "082 Bob steps away")
	GameManager.advance_campaign_time(60)
	var since := int(a.inventory.get_instance(loom).state.get("work_away_since", -1))
	_away_to(since, 3600)
	var rec := a.inventory.get_instance(loom)
	h._assert(since >= 0 and WorkRules.is_active(rec) and WorkRules.progress(rec) == kept and int(GameManager.campaign_elapsed_seconds) == since + 3600, "082 actual exactly 60 minutes away keeps progress (%d)" % WorkRules.progress(rec))
	h._assert(await Batch074Controls._walk(h, view, b, site, 10), "082 Bob returns")
	GameManager.advance_campaign_time(60)
	rec = a.inventory.get_instance(loom)
	h._assert(WorkRules.is_active(rec) and not rec.state.has("work_away_since") and WorkRules.progress(rec) >= kept, "082 actual returning after exactly 60 minutes resumes from the kept work, not from zero (%d >= %d)" % [WorkRules.progress(rec), kept])
	# 61 minutes away: reset.
	h._assert(await Batch074Controls._walk(h, view, b, site, 15), "082 Bob steps away again")
	GameManager.advance_campaign_time(60)
	since = int(a.inventory.get_instance(loom).state.get("work_away_since", -1))
	_away_to(since, 3660)
	rec = a.inventory.get_instance(loom)
	h._assert(not WorkRules.is_active(rec) and WorkRules.progress(rec) == 0, "082 actual 61 minutes away is past 1 hour: progress resets (%d)" % WorkRules.progress(rec))
	# Restart; save 30 minutes into an absence.
	h._assert(await Batch074Controls._walk(h, view, b, site, 10), "082 Bob returns for the restart")
	Batch074Controls._act_as(view, a)
	Batch074Controls._select_item(view, loom)
	h._local_room_press(view, "Start work")
	Batch074Controls._act_as(view, b)
	h._local_room_press(view, "Join work")
	menu = Batch074Controls._menu(view)
	if menu != null: menu.id_pressed.emit(0)
	GameManager.advance_campaign_time(600)
	kept = WorkRules.progress(a.inventory.get_instance(loom))
	h._assert(await Batch074Controls._walk(h, view, b, site, 15), "082 Bob steps away before the save")
	GameManager.advance_campaign_time(60)
	since = int(a.inventory.get_instance(loom).state.get("work_away_since", -1))
	_away_to(since, 1800)
	rec = a.inventory.get_instance(loom)
	h._assert(kept > 0 and since >= 0 and WorkRules.is_active(rec) and WorkRules.progress(rec) == kept, "082 actual paused 30 minutes with progress %d" % kept)
	FileAccess.open(IDS, FileAccess.WRITE).store_string(JSON.stringify({"a": a.character_id, "loom": loom, "since": since, "kept": kept}))
	h._teardown_scene(dungeon)
	GameManager.current_state = GameManager.GameState.OVERWORLD
	GameManager.game_in_progress = true
	var block := SaveManager.get_save_block_reason()
	var saved: bool = block.is_empty() and SaveManager.save_game(SLOT)
	h._assert(saved, "082 actual real save mid-pause (block='%s')" % block)
	if saved:
		var loaded := SaveManager.load_game(SLOT)
		var na: Character = PartyManager.characters.get(a.character_id, null)
		h._assert(loaded and na != null and int(na.inventory.get_instance(loom).state.get("work_away_since", -1)) == since and WorkRules.progress(na.inventory.get_instance(loom)) == kept, "082 actual real load keeps the pause and the progress")
	h._exit_test()

## Fresh process: the remaining 30 minutes reach exactly the limit (kept); one more second resets.
static func reload(h: Node) -> void:
	h._enter_test("batch_082_interruption_boundary_reload")
	Batch074Checks.load_fixtures()
	var ids: Variant = JSON.parse_string(FileAccess.get_file_as_string(IDS))
	var loaded := SaveManager.load_game(SLOT)
	var na: Character = PartyManager.characters.get(str(ids.a), null) if ids is Dictionary else null
	h._assert(loaded and na != null and WorkRules.is_active(na.inventory.get_instance(str(ids.loom))), "082 fresh process the paused site work loads")
	if na != null:
		_away_to(int(ids.since), 3600)
		var rec := na.inventory.get_instance(str(ids.loom))
		h._assert(WorkRules.is_active(rec) and WorkRules.progress(rec) == int(ids.kept), "082 fresh process exactly 1 hour away is allowed: progress kept (%d)" % WorkRules.progress(rec))
		var receipts := GameManager.advance_campaign_time(1)
		var lapse: Array = receipts.filter(func(r): return r.get("interrupted", false) and str(r.get("instance_id", "")) == str(ids.loom))
		rec = na.inventory.get_instance(str(ids.loom))
		h._assert(lapse.size() == 1 and int(lapse[0].at) == int(ids.since) + 3601 and WorkRules.progress(rec) == 0 and not WorkRules.is_active(rec), "082 fresh process one second past 1 hour resets at away_since + 3601")
	SaveManager.delete_save(SLOT)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(IDS))
	h._exit_test()
