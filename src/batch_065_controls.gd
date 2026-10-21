class_name Batch065Controls
extends RefCounted
## Batch 065 scenario: in a real combat, an own hit fires the data-declared
## on_hit_with_attack trigger through the existing reaction prompt. A declined
## prompt spends nothing; a confirmed one spends the Reaction and switches the
## stance once; a second trigger with the Reaction spent offers nothing; real
## save/load keeps the switched mode and its declared trigger.

static func _fire(combat: Node, c: Character, foe: Dictionary, out: Array) -> void:
	var ppos: Vector2i = combat.player_entities[0]["hex_position"]
	out.append(await combat._fire_reaction_trigger(c, "on_hit_with_attack", foe, ppos, foe.get("hex_position", ppos)))

static func run(h: Node) -> void:
	h._enter_test("batch_065_reaction_triggers_flow")
	h._setup_world()
	Batch065Checks.load_fixtures()
	var c: Character = PlayerManager.get_player(0).get("character")
	c.origin_feat = ""
	Batch065Checks.kit(c)
	c.max_hp = 200
	c.current_hp = 200
	GameManager.transition_context = {"terrain": "plains", "monster_ids": ["goblin"]}
	GameManager.current_state = GameManager.GameState.COMBAT
	var combat: Node = await h._spawn_scene("res://scenes/combat.tscn", 0.8)
	for _frame in 600:
		if combat.active_combatant.get("is_player", false): break
		await h.get_tree().process_frame
	combat.resolving_player_action = false
	var foe: Dictionary = combat.monster_entities[0]
	foe["hex_position"] = combat.player_entities[0]["hex_position"] + Vector2i(1, 0)
	c.reaction_available = true
	Batch065Checks.open_window(c)
	var before := Batch065Checks.mode_state(c)
	# test_mode answers every reaction prompt with Decline.
	var declined: Array = await combat._fire_reaction_trigger(c, "on_hit_with_attack", foe, combat.player_entities[0]["hex_position"], foe.hex_position)
	h._assert(declined.size() == 1 and declined[0].reason == "canceled" and Batch065Checks.mode_state(c) == before and c.reaction_available, "065 actual a declined reaction prompt spends nothing (%s)" % str(declined.map(func(r): return r.reason)))
	GameManager.test_mode = false
	var out: Array = []
	_fire(combat, c, foe, out)
	var answered := false
	for _frame in 240:
		for child in combat.hud.get_children():
			if child is ConfirmationDialog and not child.is_queued_for_deletion() and child.visible:
				child.confirmed.emit()
				answered = true
		if answered: break
		await h.get_tree().process_frame
	for _frame in 240:
		if not out.is_empty(): break
		await h.get_tree().process_frame
	GameManager.test_mode = true
	var receipt: Dictionary = out[0][0] if not out.is_empty() and not out[0].is_empty() else {}
	h._assert(answered and bool(receipt.get("success", false)) and str(c.feature_modes[Batch065Checks.MODE].mode) == "lunge" and not c.reaction_available and not bool(combat.player_entities[0].get("reaction_available", true)) and int(c.feature_uses.get(Batch065Checks.MODE, -1)) == 1, "065 actual a confirmed prompt spends the Reaction once and switches the stance (%s)" % str(receipt.get("reason", "")))
	Batch065Checks.open_window(c)
	var spent: Array = await combat._fire_reaction_trigger(c, "on_hit_with_attack", foe, combat.player_entities[0]["hex_position"], foe.hex_position)
	h._assert(spent.is_empty() and str(c.feature_modes[Batch065Checks.MODE].mode) == "lunge", "065 actual with the Reaction spent the next trigger offers nothing")
	GameManager.current_state = GameManager.GameState.OVERWORLD
	GameManager.game_in_progress = true
	var slot := "batch_065_reaction_triggers"
	var block := SaveManager.get_save_block_reason()
	var saved: bool = block.is_empty() and SaveManager.save_game(slot)
	h._assert(saved, "065 actual real save (block='%s')" % block)
	if saved:
		var loaded := SaveManager.load_game(slot)
		var nc: Character = PartyManager.characters.get(c.character_id, null)
		h._assert(loaded and nc != null and str(nc.feature_modes[Batch065Checks.MODE].mode) == "lunge" and ModeControls.cost(nc, Batch065Checks.MODE, "switch") == "reaction" and str(FeatureModeRules.rule(nc, Batch065Checks.MODE).get("reaction_trigger", {}).get("event", "")) == "on_hit_with_attack", "065 actual real load keeps the switched mode, the Reaction cost and the declared trigger")
		SaveManager.delete_save(slot)
	h._teardown_scene(combat)
	h._exit_test()
