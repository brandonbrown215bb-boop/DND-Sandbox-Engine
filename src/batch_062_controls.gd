class_name Batch062Controls
extends RefCounted
## Batch 062 scenario: the real local-room panel activates a costed mode outside
## combat, refusals spend nothing, real save/load keeps it, and combat carries it.

static func _uses(c: Character) -> int:
	return int(c.feature_uses.get(Batch057Checks.STANCE, -1))

static func _offer(view: LocalRoomView, prefix: String) -> int:
	view.refresh()
	if view.mode_offers == null: return -1
	for i in view.mode_offers.item_count:
		if view.mode_offers.get_item_text(i).begins_with(prefix):
			view.mode_offers.select(i)
			return i
	return -1

static func _open(h: Node, view: LocalRoomView, prefix: String) -> PopupMenu:
	if _offer(view, prefix) < 0: return null
	for button in view.mode_row.get_children():
		if button is Button and not button is OptionButton and button.text == "Use mode": button.pressed.emit()
	await h.get_tree().process_frame
	var menus: Array = view.panel.get_children().filter(func(w): return w is PopupMenu and not w.is_queued_for_deletion())
	return menus.back() if not menus.is_empty() else null

static func run(h: Node) -> void:
	h._enter_test("batch_062_mode_costs_outside_flow")
	h._setup_world()
	Batch057Checks.load_fixtures()
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
	Batch057Checks.kit(c)
	var act := "Activate: Mode: Rush Stance (2/2 uses) (Bonus Action; no turn outside combat)"
	h._assert(_offer(view, act) >= 0, "062 actual the room panel offers the Bonus Action activation outside combat")
	var menu := await _open(h, view, "Activate: Mode: Rush Stance")
	var opened: bool = menu != null
	await Batch052Controls._press(h, menu, "Cancel")
	h._assert(opened and _uses(c) == 2 and not bool(c.feature_modes.get(Batch057Checks.STANCE, {}).get("active", false)), "062 actual room Cancel spends nothing")
	var old := await _open(h, view, "Activate: Mode: Rush Stance")
	var newer := await _open(h, view, "Activate: Mode: Rush Stance")
	var both: bool = old != null and newer != null and old != newer
	await Batch052Controls._press(h, old, "guard")
	await Batch052Controls._press(h, newer, "Cancel")
	h._assert(both and _uses(c) == 2 and not bool(c.feature_modes.get(Batch057Checks.STANCE, {}).get("active", false)), "062 actual a superseded room popup answer spends nothing")
	var late := await _open(h, view, "Activate: Mode: Rush Stance")
	var late_open: bool = late != null
	c.add_condition("stunned", 2)
	await Batch052Controls._press(h, late, "guard")
	var stunned_hidden := _offer(view, "Activate: Mode: Rush Stance") < 0
	c.remove_condition("stunned")
	h._assert(late_open and stunned_hidden and _uses(c) == 2 and not bool(c.feature_modes.get(Batch057Checks.STANCE, {}).get("active", false)), "062 actual an incapacitated owner is offered nothing and a pending answer spends nothing")
	c.feature_uses[Batch057Checks.STANCE] = 0
	var none_left := _offer(view, "Activate: Mode: Rush Stance") < 0
	c.feature_uses[Batch057Checks.STANCE] = 2
	h._assert(none_left and _uses(c) == 2, "062 actual with no uses left the room offers no activation")
	var go := await _open(h, view, "Activate: Mode: Rush Stance")
	await Batch052Controls._press(h, go, "guard")
	h._assert(_uses(c) == 1 and str(c.feature_modes[Batch057Checks.STANCE].mode) == "guard", "062 actual the room activation charges one use exactly once")
	var re := await _open(h, view, "Change mode: Mode: Rush Stance")
	await Batch052Controls._press(h, re, "dash")
	h._assert(_uses(c) == 1 and str(c.feature_modes[Batch057Checks.STANCE].mode) == "dash" and _offer(view, "Activate:") < 0, "062 actual room reselect (Action cost) spends no use and no re-activation is offered")
	var cid := c.character_id
	h._teardown_scene(dungeon)
	GameManager.current_state = GameManager.GameState.OVERWORLD
	GameManager.game_in_progress = true
	var slot := "batch_062_mode_costs_outside"
	var block := SaveManager.get_save_block_reason()
	var saved: bool = block.is_empty() and SaveManager.save_game(slot)
	h._assert(saved, "062 actual real save (block='%s')" % block)
	var nc: Character = c
	if saved:
		var loaded := SaveManager.load_game(slot)
		nc = PartyManager.characters.get(cid, null)
		h._assert(loaded and nc != null and _uses(nc) == 1 and str(nc.feature_modes[Batch057Checks.STANCE].mode) == "dash" and bool(nc.feature_modes[Batch057Checks.STANCE].active), "062 actual real load keeps the use and the active mode")
		SaveManager.delete_save(slot)
	if nc == null: nc = c
	GameManager.transition_context = {"terrain": "plains", "monster_ids": ["goblin"]}
	GameManager.current_state = GameManager.GameState.COMBAT
	var combat: Node = await h._spawn_scene("res://scenes/combat.tscn", 0.8)
	var fighter: Character = nc
	for entity in combat.player_entities:
		var ch: Character = entity.get("character")
		if ch != null and ch.character_id == cid: fighter = ch
	h._p_focus(combat, fighter)
	combat.resolving_player_action = false
	combat.hud._show_feature_selection()
	var texts: Array = []
	for i in combat.hud.features_registered.size(): texts.append(combat.hud.feature_list.get_item_text(i))
	combat.hud._hide_feature_selection()
	var carried: bool = _uses(fighter) == 1 and str(fighter.feature_modes.get(Batch057Checks.STANCE, {}).get("mode", "")) == "dash" and texts.any(func(t): return str(t).begins_with("Change mode: Mode: Rush Stance")) and not texts.any(func(t): return str(t).begins_with("Activate: Mode: Rush Stance"))
	h._assert(carried, "062 actual combat starting afterward carries the active mode and its use count")
	var outside_in_combat := ModeControls.apply(fighter, Batch057Checks.STANCE, "reselect", "guard", ModeControls.row(fighter, Batch057Checks.STANCE).token, ModeControls.outside_combat())
	h._assert(outside_in_combat.reason == "in_combat" and combat._can_spend_action_cost("action") and str(fighter.feature_modes[Batch057Checks.STANCE].mode) == "dash", "062 actual the outside-combat context is refused once combat is running and spends nothing")
	h._teardown_scene(combat)
	h._exit_test()
