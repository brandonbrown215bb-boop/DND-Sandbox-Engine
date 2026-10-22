class_name Batch064Controls
extends RefCounted
## Batch 064 scenario: the real room panel shows and logs a mode's data-declared
## activation time outside combat, does not advance the campaign clock, and the
## mode survives a real save/load.

static func _uses(c: Character) -> int:
	return int(c.feature_uses.get(Batch064Checks.MODE, -1))

static func run(h: Node) -> void:
	h._enter_test("batch_064_mode_duration_flow")
	h._setup_world()
	Batch064Checks.load_fixtures()
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
	c.origin_feat = ""
	Batch064Checks.kit(c)
	var label := "Activate: Mode: Slow Ward (2/2 uses) (Action; no turn outside combat) [takes 10 min; time not advanced]"
	h._assert(Batch062Controls._offer(view, label) >= 0, "064 actual the room panel label shows the 10 min data duration")
	var clock := int(GameManager.campaign_elapsed_seconds)
	var menu := await Batch062Controls._open(h, view, "Activate: Mode: Slow Ward")
	var opened: bool = menu != null
	await Batch052Controls._press(h, menu, "Cancel")
	h._assert(opened and _uses(c) == 2 and int(GameManager.campaign_elapsed_seconds) == clock, "064 actual room Cancel spends nothing and passes no time")
	var go := await Batch062Controls._open(h, view, "Activate: Mode: Slow Ward")
	await Batch052Controls._press(h, go, "warded")
	var logged: bool = view.hud.log_text != null and str(view.hud.log_text.text).contains("(takes 10 min; time not advanced)")
	h._assert(_uses(c) == 1 and str(c.feature_modes[Batch064Checks.MODE].mode) == "warded" and int(GameManager.campaign_elapsed_seconds) == clock and logged, "064 actual activation charges one use, logs the duration and leaves the campaign clock unchanged")
	var cid := c.character_id
	h._teardown_scene(dungeon)
	GameManager.current_state = GameManager.GameState.OVERWORLD
	GameManager.game_in_progress = true
	var slot := "batch_064_mode_duration"
	var block := SaveManager.get_save_block_reason()
	var saved: bool = block.is_empty() and SaveManager.save_game(slot)
	h._assert(saved, "064 actual real save (block='%s')" % block)
	if saved:
		var loaded := SaveManager.load_game(slot)
		var nc: Character = PartyManager.characters.get(cid, null)
		h._assert(loaded and nc != null and _uses(nc) == 1 and bool(nc.feature_modes[Batch064Checks.MODE].active) and int(GameManager.campaign_elapsed_seconds) == clock, "064 actual real load keeps the use, the active mode and the unadvanced clock")
		SaveManager.delete_save(slot)
	h._exit_test()
