class_name Batch063Controls
extends RefCounted
## Batch 063 scenario: the real combat HUD shows and pays a Magic-action mode
## cost; with no Action left (even with a surge action) nothing is spent; real
## save/load keeps the use, the mode and the authored cost.

static func _uses(c: Character) -> int:
	return int(c.feature_uses.get(Batch063Checks.FOCUS, -1))

static func run(h: Node) -> void:
	h._enter_test("batch_063_magic_action_cost_flow")
	h._setup_world()
	Batch063Checks.load_fixtures()
	var c: Character = PlayerManager.get_player(0).get("character")
	c.origin_feat = ""
	Batch063Checks.kit(c)
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
	var title := "Activate: Arcane Focus"
	var label := "Activate: Mode: Arcane Focus (2/2 uses) (Magic action)"
	var row := Batch057Controls._row(combat, label)
	h._assert(row >= 0 and not combat.hud.feature_list.is_item_disabled(row), "063 actual the HUD shows the declared (Magic action) cost on the activation")
	combat.hud._hide_feature_selection()
	var menu := await Batch057Controls._open(h, combat, "Activate: Mode: Arcane Focus", title)
	var opened: bool = menu != null
	await Batch052Controls._press(h, menu, "Cancel")
	h._assert(opened and _uses(c) == 2 and combat._can_spend_action_cost("magic_action"), "063 actual Cancel spends neither the use nor the Action")
	combat.turn_budget.spend("action")
	combat.turn_budget.grant_surge_action()
	var broke := Batch057Controls._row(combat, "Activate: Mode: Arcane Focus")
	var disabled: bool = broke >= 0 and combat.hud.feature_list.is_item_disabled(broke) and combat.hud.feature_list.get_item_text(broke).ends_with("[unaffordable]")
	combat.hud._hide_feature_selection()
	var forced := ModeControls.apply(c, Batch063Checks.FOCUS, "activate", "guard", ModeControls.row(c, Batch063Checks.FOCUS).token, combat)
	h._assert(disabled and forced.reason == "unaffordable" and _uses(c) == 2 and combat.turn_budget.surge_actions == 1 and combat._can_spend_action_cost("bonus_action") and not bool(c.feature_modes.get(Batch063Checks.FOCUS, {}).get("active", false)), "063 actual checklist (a): with no Action left (only a surge action) the Magic-action activation is offered disabled and a forced attempt spends nothing")
	combat.turn_budget.surge_actions = 0
	combat.turn_budget.grant_action()
	h._p_focus(combat, c)
	combat.resolving_player_action = false
	var go := await Batch057Controls._open(h, combat, "Activate: Mode: Arcane Focus", title)
	await Batch052Controls._press(h, go, "guard")
	h._assert(_uses(c) == 1 and not combat._can_spend_action_cost("action") and combat._can_spend_action_cost("bonus_action") and str(c.feature_modes[Batch063Checks.FOCUS].mode) == "guard", "063 actual the activation spends one use and the Action (Magic action) exactly once, not the Bonus Action")
	combat.hud._hide_feature_selection()
	GameManager.current_state = GameManager.GameState.OVERWORLD
	GameManager.game_in_progress = true
	var slot := "batch_063_magic_action_cost"
	var block := SaveManager.get_save_block_reason()
	var saved: bool = block.is_empty() and SaveManager.save_game(slot)
	h._assert(saved, "063 actual real save (block='%s')" % block)
	if saved:
		var loaded := SaveManager.load_game(slot)
		var nc: Character = PartyManager.characters.get(c.character_id, null)
		h._assert(loaded and nc != null and _uses(nc) == 1 and str(nc.feature_modes[Batch063Checks.FOCUS].mode) == "guard" and ModeControls.cost(nc, Batch063Checks.FOCUS, "activate") == "magic", "063 actual real load keeps the use, the mode and the authored Magic-action cost")
		SaveManager.delete_save(slot)
	h._teardown_scene(combat)
	h._exit_test()
