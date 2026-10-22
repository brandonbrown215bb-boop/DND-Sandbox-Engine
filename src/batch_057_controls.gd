class_name Batch057Controls
extends RefCounted
## Batch 057 scenario: the real combat HUD pays declared mode costs from the turn budget.

static func _row(combat: Node, prefix: String) -> int:
	combat.hud._show_feature_selection()
	for i in combat.hud.features_registered.size():
		if combat.hud.feature_list.get_item_text(i).begins_with(prefix): return i
	return -1

static func _open(h: Node, combat: Node, prefix: String, title: String, exclude: PopupMenu = null) -> PopupMenu:
	var i := _row(combat, prefix)
	if i < 0: return null
	var existing: Array = combat.hud.get_children().filter(func(w): return w is PopupMenu)
	combat.hud._on_feature_selected(i)
	for _f in 60:
		await h.get_tree().process_frame
		for w in combat.hud.get_children():
			if w is PopupMenu and w != exclude and not existing.has(w) and w.visible and not w.is_queued_for_deletion() and str(w.title).begins_with(title): return w
	return null

static func _uses(c: Character) -> int:
	return int(c.feature_uses.get(Batch057Checks.STANCE, -1))

static func run(h: Node) -> void:
	h._enter_test("batch_057_mode_costs_flow")
	h._setup_world()
	Batch057Checks.load_fixtures()
	var c: Character = PlayerManager.get_player(0).get("character")
	var other: Character = PlayerManager.get_player(1).get("character")
	c.origin_feat = ""
	Batch057Checks.kit(c)
	c.max_hp = 200
	c.current_hp = 200
	GameManager.transition_context = {"terrain": "plains", "monster_ids": ["goblin"]}
	GameManager.current_state = GameManager.GameState.COMBAT
	var combat: Node = await h._spawn_scene("res://scenes/combat.tscn", 0.8)
	for _frame in 600:
		if combat.active_combatant.get("is_player", false): break
		await h.get_tree().process_frame
	h._p_focus(combat, c)
	combat.resolving_player_action = false
	var title := "Activate: Rush Stance"
	var label := "Activate: Mode: Rush Stance (2/2 uses) (Bonus Action)"
	h._assert(_row(combat, label) >= 0 and not combat.hud.feature_list.is_item_disabled(_row(combat, label)), "057 actual the HUD shows the declared Bonus Action cost on the activation")
	combat.hud._hide_feature_selection()
	var menu := await _open(h, combat, "Activate: Mode: Rush Stance", title)
	var menu_open: bool = menu != null
	await Batch052Controls._press(h, menu, "Cancel")
	h._assert(menu_open and _uses(c) == 2 and combat._can_spend_action_cost("bonus_action"), "057 actual Cancel spends neither the use nor the Bonus Action (%s %d %s)" % [str(menu_open), _uses(c), str(combat._can_spend_action_cost("bonus_action"))])
	var old := await _open(h, combat, "Activate: Mode: Rush Stance", title)
	var newer := await _open(h, combat, "Activate: Mode: Rush Stance", title, old)
	var both: bool = old != null and newer != null
	await Batch052Controls._press(h, old, "guard")
	await Batch052Controls._press(h, newer, "Cancel")
	h._assert(both and _uses(c) == 2 and combat._can_spend_action_cost("bonus_action") and not bool(c.feature_modes.get(Batch057Checks.STANCE, {}).get("active", false)), "057 actual a stale popup answer spends neither")
	# Wrong turn: the popup is answered after the turn passed to someone else.
	var late := await _open(h, combat, "Activate: Mode: Rush Stance", title)
	var late_open: bool = late != null
	h._p_focus(combat, other, false)
	await Batch052Controls._press(h, late, "guard")
	h._p_focus(combat, c, false)
	h._assert(late_open and _uses(c) == 2 and combat._can_spend_action_cost("bonus_action"), "057 actual a popup answered after the owner's turn ended spends neither (%s %d %s)" % [str(late_open), _uses(c), str(combat._can_spend_action_cost("bonus_action"))])
	c.add_condition("stunned", 2)
	var stunned_row := _row(combat, "Mode: Rush Stance")
	var stunned_off: bool = stunned_row >= 0 and combat.hud.feature_list.is_item_disabled(stunned_row)
	c.remove_condition("stunned")
	h._assert(stunned_off and _uses(c) == 2, "057 actual an incapacitated owner is offered the stance disabled and spends nothing")
	combat.turn_budget.spend("bonus_action")
	var broke := _row(combat, "Activate: Mode: Rush Stance")
	h._assert(broke >= 0 and combat.hud.feature_list.is_item_disabled(broke) and combat.hud.feature_list.get_item_text(broke).ends_with("[unaffordable]"), "057 actual with no Bonus Action left the activation is offered disabled")
	combat.hud._hide_feature_selection()
	var forced := ModeControls.apply(c, Batch057Checks.STANCE, "activate", "guard", ModeControls.row(c, Batch057Checks.STANCE).token, combat)
	h._assert(forced.reason == "unaffordable" and _uses(c) == 2, "057 actual a forced unaffordable activation spends nothing")
	h._p_focus(combat, c)
	combat.resolving_player_action = false
	var go := await _open(h, combat, "Activate: Mode: Rush Stance", title)
	await Batch052Controls._press(h, go, "guard")
	h._assert(_uses(c) == 1 and not combat._can_spend_action_cost("bonus_action") and combat._can_spend_action_cost("action") and str(c.feature_modes[Batch057Checks.STANCE].mode) == "guard", "057 actual the activation spends one use and the Bonus Action exactly once")
	var re := await _open(h, combat, "Change mode: Mode: Rush Stance", "Change mode: Rush Stance")
	await Batch052Controls._press(h, re, "dash")
	h._assert(_uses(c) == 1 and not combat._can_spend_action_cost("action") and str(c.feature_modes[Batch057Checks.STANCE].mode) == "dash", "057 actual reselect follows its declared Action cost and spends no use")
	combat.hud._hide_feature_selection()
	GameManager.current_state = GameManager.GameState.OVERWORLD
	GameManager.game_in_progress = true
	var slot := "batch_057_mode_costs"
	var block := SaveManager.get_save_block_reason()
	var saved: bool = block.is_empty() and SaveManager.save_game(slot)
	h._assert(saved, "057 actual real save (block='%s')" % block)
	if saved:
		var loaded := SaveManager.load_game(slot)
		var nc: Character = PartyManager.characters.get(c.character_id, null)
		h._assert(loaded and nc != null and int(nc.feature_uses.get(Batch057Checks.STANCE, -1)) == 1 and str(nc.feature_modes[Batch057Checks.STANCE].mode) == "dash" and ModeControls.cost(nc, Batch057Checks.STANCE, "activate") == "bonus_action", "057 actual real load keeps the use, the mode and the authored cost")
		SaveManager.delete_save(slot)
	h._teardown_scene(combat)
	h._exit_test()
