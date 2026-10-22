class_name Batch060Controls
extends RefCounted
## Batch 060 scenario: the real HUD shows and charges each order's data-declared command cost.

static func _budget(combat: Node) -> Array:
	return [combat._can_spend_action_cost("action"), combat._can_spend_action_cost("bonus_action"), combat.active_character.reaction_available]

static func run(h: Node) -> void:
	h._enter_test("batch_060_command_cost_flow")
	h._setup_world()
	Batch060Checks.load_fixtures()
	var a: Character = PlayerManager.get_player(0).get("character")
	var b: Character = PlayerManager.get_player(1).get("character")
	var prior := {"known": b.known_spells.duplicate(), "book": b.wizard_spellbook.duplicate(), "choices": b.feature_choices.duplicate(true), "features": b.features.duplicate(true)}
	var spells: Array[String] = [Batch060Checks.HOUNDS]
	b.known_spells.assign(spells)
	b.wizard_spellbook.assign(spells)
	b.feature_choices[b.get_spellcasting_feature_id()] = spells.duplicate()
	b.features.append({"id": "fixture:b060_permission", "effects": [{"type": "always_prepared_spells", "spells": spells.duplicate(), "ability": "INT", "maximum_spell_level": 1}]})
	GameManager.transition_context = {"terrain": "plains", "monster_ids": ["goblin"]}
	GameManager.current_state = GameManager.GameState.COMBAT
	GameManager.test_mode = false
	var combat: Node = await h._spawn_scene("res://scenes/combat.tscn", 0.8)
	for _frame in 600:
		if combat.active_combatant.get("is_player", false): break
		await h.get_tree().process_frame
	for entry in combat.player_entities:
		entry["hex_position"] = Vector2i.ZERO if entry.character == a else Vector2i(0, 1)
		entry["has_turn"] = true
	var enemy: Dictionary = combat.monster_entities[0]
	enemy["hex_position"] = Vector2i(1, 1)
	enemy["current_hp"] = 200
	enemy["max_hp"] = 200
	combat._update_grid_entities()
	Batch047Controls.fresh_turn(h, combat, b)
	b.spell_slots = {"1": 4}
	await Batch047Controls.begin(h, combat, b, Batch060Checks.HOUNDS)
	await Batch047Controls.settle(h, combat)
	var hs := CreatedActorRules.actors(b)
	Batch047Controls.fresh_turn(h, combat, b)
	var dodge := Batch055Controls._index(combat, "Command Hound 1 [1]: Dodge (Free)")
	var attack := Batch055Controls._index(combat, "Command Hound 1 [1]: Attack (Action)")
	h._assert(hs.size() == 2 and dodge >= 0 and attack >= 0, "060 actual the HUD shows each order's declared cost (Dodge Free, Attack Action)")
	var before := _budget(combat)
	combat.hud._on_feature_selected(dodge)
	for _f in 3: await h.get_tree().process_frame
	h._assert(hs[0].has_condition("dodging") and before == [true, true, true] and _budget(combat) == before, "060 actual a free Dodge command consumes no Action, Bonus Action or reaction")
	# Spend the Action elsewhere: the Action-cost attack order is offered disabled and a forced one spends nothing.
	combat.turn_budget.spend("action")
	var blocked := Batch055Controls._index(combat, "Command Hound 2 [2]: Attack (Action)")
	h._assert(blocked >= 0 and combat.hud.feature_list.is_item_disabled(blocked) and combat.hud.feature_list.get_item_text(blocked).contains("No action"), "060 actual with no Action left the Action-cost attack order is offered disabled")
	combat.hud._hide_feature_selection()
	var hp_before := int(enemy.current_hp)
	var spent_before := _budget(combat)
	combat._on_hud_action("command_created_actor", {"actor_id": hs[1].character_id, "order": "attack", "target_id": str(enemy.id)})
	for _f in 3: await h.get_tree().process_frame
	h._assert(int(enemy.current_hp) == hp_before and _budget(combat) == spent_before and CreatedCommandRules._commanded.get(hs[1].character_id, -1) != CombatAction.active_turn_serial, "060 actual a forced unaffordable attack order is refused and spends nothing")
	# Wrong turn: the partner is active; a forced command for b's hound spends nothing.
	Batch047Controls.fresh_turn(h, combat, a)
	var a_before := _budget(combat)
	combat._on_hud_action("command_created_actor", {"actor_id": hs[1].character_id, "order": "dodge"})
	for _f in 3: await h.get_tree().process_frame
	h._assert(not hs[1].has_condition("dodging") and _budget(combat) == a_before, "060 actual a command on another creature's turn is refused and spends nothing")
	# Incapacitated owner: refused before paying.
	Batch047Controls.fresh_turn(h, combat, b)
	b.add_condition("stunned", 2)
	var b_before := _budget(combat)
	combat._on_hud_action("command_created_actor", {"actor_id": hs[1].character_id, "order": "attack", "target_id": str(enemy.id)})
	for _f in 3: await h.get_tree().process_frame
	b.remove_condition("stunned")
	h._assert(int(enemy.current_hp) == hp_before and _budget(combat) == b_before, "060 actual an incapacitated owner's costed order is refused and spends nothing")
	# Stale actor id and superseded target popup spend nothing; the current answer pays one Action.
	combat._on_hud_action("command_created_actor", {"actor_id": "b060_gone", "order": "attack", "target_id": str(enemy.id)})
	for _f in 3: await h.get_tree().process_frame
	h._assert(_budget(combat) == b_before, "060 actual a stale actor id is refused and spends nothing")
	var wolf_hex: Vector2i = CreatedCommandRules._entity(combat, hs[1].character_id).hex_position
	for n in HexUtils.get_neighbors(wolf_hex):
		if not combat._is_occupied_hex(n):
			enemy["hex_position"] = n
			break
	combat._update_grid_entities()
	Batch047Controls.fresh_turn(h, combat, b)
	combat.hud._on_feature_selected(Batch055Controls._index(combat, "Command Hound 2 [2]: Attack (Action)"))
	var cancel := await Batch053Controls._popup(h, combat, "Command target")
	h._assert(cancel != null and cancel.get_item_text(0) == "Cancel", "060 actual the Action-cost attack order asks for its target with Cancel")
	if cancel != null: cancel.id_pressed.emit(cancel.get_item_id(0))
	for _f in 3: await h.get_tree().process_frame
	h._assert(_budget(combat) == b_before, "060 actual canceling the target spends nothing")
	combat.hud._on_feature_selected(Batch055Controls._index(combat, "Command Hound 2 [2]: Attack (Action)"))
	var old := await Batch053Controls._popup(h, combat, "Command target")
	combat.hud._on_feature_selected(Batch055Controls._index(combat, "Command Hound 2 [2]: Attack (Action)"))
	var newer := await Batch053Controls._popup(h, combat, "Command target", old)
	var both := old != null and newer != null
	if old != null: old.id_pressed.emit(old.get_item_id(1))
	for _f in 3: await h.get_tree().process_frame
	h._assert(both and _budget(combat) == b_before and int(enemy.current_hp) == hp_before, "060 actual answering a superseded target popup spends nothing")
	if newer != null: newer.id_pressed.emit(newer.get_item_id(1))
	for _f in 6: await h.get_tree().process_frame
	h._assert(_budget(combat) == [false, true, true] and CreatedCommandRules._commanded.get(hs[1].character_id, -1) == CombatAction.active_turn_serial, "060 actual the current attack order charges exactly one Action and leaves the Bonus Action")
	h._teardown_scene(combat)
	b.known_spells.assign(prior.known)
	b.wizard_spellbook.assign(prior.book)
	b.feature_choices = prior.choices
	b.features = prior.features
	GameManager.current_state = GameManager.GameState.OVERWORLD
	GameManager.game_in_progress = true
	var slot := "batch_060_command_cost"
	var block := SaveManager.get_save_block_reason()
	var saved: bool = block.is_empty() and SaveManager.save_game(slot)
	h._assert(saved, "060 actual real save (block='%s')" % block)
	if saved:
		var loaded := SaveManager.load_game(slot)
		var nb: Character = PartyManager.characters.get(b.character_id, null)
		var back: Array = [] if nb == null else CreatedActorRules.actors(nb)
		h._assert(loaded and back.size() == 2 and CreatedCommandRules.cost(CreatedCommandRules.policy(CreatedCommandRules._template(nb, back[0])), "attack") == "action", "060 actual real load keeps both hounds and their data-declared command cost")
		SaveManager.delete_save(slot)
	h._exit_test()
