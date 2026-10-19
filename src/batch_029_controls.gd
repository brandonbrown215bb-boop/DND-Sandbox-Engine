class_name Batch029Controls
extends RefCounted

static func pause(h: Node, frames: int = 4) -> void:
	for frame in frames: await h.get_tree().process_frame


static func run(h: Node) -> void:
	h._enter_test("batch_029_interruption_flow")
	h._setup_world()
	Batch029Checks.load_fixtures()
	h._assert(DataLoader.get_load_errors().is_empty(), "029 examples load through ordinary spell/class/item validation")

	var scores := AbilityScores.new()
	scores.from_dict({"STR": 10, "DEX": 16, "CON": 14, "INT": 18, "WIS": 12, "CHA": 10})

	var caster := Character.new()
	caster.initialize("Interruption Caster", "human", "wizard", scores)
	caster.character_id = "b029_caster"
	caster.max_hp = 50
	caster.current_hp = 50
	caster.spell_slots = {"1": 4, "2": 3, "3": 2}
	caster.known_spells = ["fixture:029_target_refund", "fixture:029_target_commit", "fixture:029_multi_target_stepped"]

	var negator := Character.new()
	negator.initialize("Negation Warder", "human", "fixture:029_class", scores)
	negator.character_id = "b029_negator"
	negator.max_hp = 40
	negator.current_hp = 40

	PartyManager.reset()
	PlayerManager.set_player_character(0, caster)
	PartyManager.register_player_character(0, caster)
	PlayerManager.set_player_character(1, negator)
	PartyManager.register_player_character(1, negator)

	GameManager.transition_context = {"terrain": "plains", "monster_ids": ["goblin"]}
	GameManager.current_state = GameManager.GameState.COMBAT
	GameManager.test_mode = false

	var combat: Node = await h._spawn_scene("res://scenes/combat.tscn", 0.8)
	for frame in 600:
		if combat.active_combatant.get("is_player", false): break
		await h.get_tree().process_frame

	h._p_focus(combat, caster)
	combat.player_entities[0].hex_position = Vector2i.ZERO
	combat.player_entities[1].hex_position = Vector2i(0, 1)

	var enemy: Dictionary = combat.monster_entities[0]
	enemy.hex_position = Vector2i(2, 0)
	enemy.current_hp = 50
	enemy.max_hp = 50
	combat._update_grid_entities()

	# 1. Test live cancellation and refund (S-142 & S-115)
	var stopper_char := Character.new()
	stopper_char.initialize("Reactive Defender", "human", "wizard", scores)
	stopper_char.reaction_available = true
	stopper_char.spell_slots = {"2": 1}
	SpellPermissionChecks.grant_slot_permission(stopper_char, ["fixture:029_stopping_spell"])

	var target_refund_spell: Dictionary = DataLoader.get_spell("fixture:029_target_refund")
	var stopping_spell: Dictionary = DataLoader.get_spell("fixture:029_stopping_spell")

	var stopping_payment: Dictionary = SpellPermissionRules.payment_choices(stopper_char, stopping_spell["id"])[0]
	var refund_decisions := {
		"stopping_spell:%s" % stopper_char.character_name: stopping_spell,
		SpellPermissionRules.reaction_key(stopper_char, stopping_spell["id"]): stopping_payment
	}
	var res_refund := CombatAction.resolve_spell(caster, enemy, target_refund_spell, true, refund_decisions, [stopper_char])
	h._assert(bool(res_refund.get("canceled", false)) and not bool(res_refund.get("success", true)), "029 live combat reaction cancels eligible target spell")
	h._assert(bool(res_refund.get("incoming_spell_slot_refunded", false)) and int(caster.spell_slots["1"]) == 4, "029 live interrupted spell refunds slot per declared policy")
	h._assert(not stopper_char.reaction_available and int(stopper_char.spell_slots["2"]) == 0, "029 live stopper commits level-2 slot and reaction")

	# 2. Test live cancellation with commit policy (S-142)
	stopper_char.reaction_available = true
	stopper_char.spell_slots["2"] = 1
	var target_commit_spell: Dictionary = DataLoader.get_spell("fixture:029_target_commit")
	var commit_payment: Dictionary = SpellPermissionRules.payment_choices(stopper_char, stopping_spell["id"])[0]
	var commit_decisions := {
		"stopping_spell:%s" % stopper_char.character_name: stopping_spell,
		SpellPermissionRules.reaction_key(stopper_char, stopping_spell["id"]): commit_payment
	}
	var res_commit := CombatAction.resolve_spell(caster, enemy, target_commit_spell, true, commit_decisions, [stopper_char])
	h._assert(bool(res_commit.get("canceled", false)), "029 live reaction cancels commit spell")
	h._assert(not bool(res_commit.get("incoming_spell_slot_refunded", true)) and int(caster.spell_slots["1"]) == 3, "029 live commit spell retains spent slot on cancellation")

	# 3. Test Spell Breaker failure refund (S-143)
	caster.spell_slots["1"] = 4
	var breaker_spell: Dictionary = DataLoader.get_spell("fixture:029_spell_breaker")
	var breaker_char := Character.new()
	breaker_char.initialize("Breaker Guard", "human", "wizard", scores)
	breaker_char.reaction_available = true
	breaker_char.spell_slots = {"3": 1}
	SpellPermissionChecks.grant_slot_permission(breaker_char, ["fixture:029_spell_breaker"])

	caster.add_modifier("roll", "save:CON", 1000, 4)
	var breaker_payment: Dictionary = SpellPermissionRules.payment_choices(breaker_char, breaker_spell["id"])[0]
	var breaker_decisions := {
		"stopping_spell:%s" % breaker_char.character_name: breaker_spell,
		SpellPermissionRules.reaction_key(breaker_char, breaker_spell["id"]): breaker_payment
	}
	var res_breaker := CombatAction.resolve_spell(caster, enemy, target_refund_spell, true, breaker_decisions, [breaker_char])
	h._assert(bool(res_breaker.get("success", false)), "029 failed stop lets incoming spell resolve against target")
	h._assert(not breaker_char.reaction_available and int(breaker_char.spell_slots["3"]) == 1, "029 Spell Breaker refunds stopping slot on failed attempt while committing reaction")
	h._assert(int(caster.spell_slots["1"]) == 3, "029 original target spell slot is spent normally on completion without repaying")

	# 4. Test live recipient negation (S-116)
	var multi_spell: Dictionary = DataLoader.get_spell("fixture:029_multi_target_stepped")
	var res_negated_single := CombatAction.resolve_spell(caster, negator, multi_spell)
	h._assert(bool(res_negated_single.get("recipient_negated", false)) and int(res_negated_single.get("damage", 0)) == 0, "029 live single-target negation deals 0 damage to ward bearer")
	h._assert(negator.current_hp == 40, "029 ward bearer HP unchanged after negated cast")

	# Stepped resolution across negator and normal enemy
	var step_cast := SpellResolutionContext.new()
	step_cast.caster = caster
	step_cast.target = enemy
	step_cast.spell = multi_spell
	step_cast.spell_definition_id = str(multi_spell["id"])
	step_cast.slot_level = 1

	var adapter = SharedStepExecutor.SpellAdapter.new(step_cast)
	h._assert(adapter.is_recipient_negated(negator), "029 adapter identifies negator recipient")
	h._assert(not adapter.is_recipient_negated(enemy), "029 adapter confirms enemy is not negated")

	await _actual_payment_controls(h, combat, caster, negator, enemy)
	await _custom_stopping_controls(h, combat, caster, negator, enemy)
	await pause(h, 6)
	h._teardown_scene(combat)
	GameManager.test_mode = true
	DataLoader.load_all_data()
	h._exit_test()
	print("BATCH_029_CONTROLS_COMPLETE: PRODUCTION CONTROLS PASSED")


static func _actual_payment_controls(h: Node, combat: Node, caster: Character, reactor: Character, target: Dictionary) -> void:
	SpellPermissionChecks.grant_slot_permission(caster, ["fixture:029_target_refund", "fixture:029_empty_refund"])
	SpellPermissionChecks.grant_slot_permission(reactor, ["counterspell"])
	caster.features.append({"id":"fixture:029_control_free","type":"passive","effects":[{"type":"spell_free_cast","spells":["fixture:029_target_refund"],"ability":"INT","uses":2}]})
	caster.features.append({"id":"fixture:029_control_points","type":"passive","effects":[{"type":"always_prepared_spells","spells":["fixture:029_target_refund"],"ability":"INT","point_payment":{"resource_id":"fixture:029_points","cost":3}}]})
	caster.feature_uses["free_spell_cast:fixture:029_control_free"] = 2
	caster.feature_uses["fixture:029_points"] = 6
	caster.add_modifier("roll", "save:CON", -10000, 100)
	for index in 2: caster.inventory.add_item("fixture:029_charge_ring")
	var copies: Array = caster.inventory.backpack_instances().filter(func(copy): return copy.definition_id == "fixture:029_charge_ring")
	var first := str(copies[0].instance_id)
	var second := str(copies[1].instance_id)
	caster.inventory.equip_instance(Inventory.Slot.RING_1, first)
	caster.inventory.equip_instance(Inventory.Slot.RING_2, second)
	var kinds := ["slot", "free_cast", "points", "item_charges"]
	for kind in kinds:
		combat._cancel_pending_action()
		combat._reset_turn_action_economy()
		h._p_focus(combat, caster, false)
		caster.spell_slots = {"1":4}
		reactor.spell_slots = {"3":1}
		reactor.reaction_available = true
		var before_hp := int(target.current_hp)
		combat.hud.update_hud(caster, combat.tracker)
		combat.hud._show_spell_selection()
		var selected := -1
		for index in combat.hud.spells_registered.size():
			var row: Dictionary = combat.hud.spells_registered[index]
			if row.get("id") == "fixture:029_target_refund" and row.get("_spell_payment_kind") == kind and (kind != "item_charges" or row.get("_spell_payment_source_id") == first): selected = index; break
		h._assert(selected >= 0, "029 actual spell picker offers selected payment: " + kind)
		if selected < 0: continue
		combat.hud._on_spell_selected(selected)
		if kind == "slot": await Batch027Controls.answer(h, combat, "", "Level 1")
		combat.call_deferred("_on_hex_clicked", target.hex_position)
		var reaction: ConfirmationDialog = null
		for frame in 120:
			await h.get_tree().process_frame
			for window in combat.hud.get_children():
				if window is ConfirmationDialog and window.visible and str(window.dialog_text).contains("Force a Constitution save"): reaction = window; break
			if reaction != null: break
		h._assert(reaction != null, "029 actual Counterspell prompt pauses paid cast: " + kind)
		if reaction != null: reaction.confirmed.emit()
		for frame in 120:
			await h.get_tree().process_frame
			if not combat._cast_in_progress: break
		h._assert(not combat._cast_in_progress and caster.spell_slots["1"] == 4 and caster.feature_uses["free_spell_cast:fixture:029_control_free"] == 2 and caster.feature_uses["fixture:029_points"] == 6 and caster.inventory.get_instance(first).state.charges == 5 and caster.inventory.get_instance(second).state.charges == 5, "029 actual interruption refunds exactly the selected source and amount: " + kind)
		h._assert(not combat.turn_budget.action_available and not reactor.reaction_available and reactor.spell_slots["3"] == 0 and int(target.current_hp) == before_hp, "029 actual interrupted cast retains Action and stopping costs without effect: " + kind)
	# A successful empty effect declares its own refund, while keeping the Action.
	combat._cancel_pending_action()
	combat._reset_turn_action_economy()
	h._p_focus(combat, caster, false)
	reactor.reaction_available = false
	combat.hud.update_hud(caster, combat.tracker)
	combat.hud._show_spell_selection()
	var empty_index := -1
	for index in combat.hud.spells_registered.size():
		if combat.hud.spells_registered[index].get("id") == "fixture:029_empty_refund": empty_index = index; break
	h._assert(empty_index >= 0, "029 actual picker offers authored empty-effect settlement")
	if empty_index >= 0:
		combat.hud._on_spell_selected(empty_index)
		await Batch027Controls.answer(h, combat, "", "Level 1")
		await combat._on_hex_clicked(target.hex_position)
		h._assert(caster.spell_slots["1"] == 4 and not combat.turn_budget.action_available, "029 actual empty-effect cast refunds slot and retains Action")


static func _custom_stopping_controls(h: Node, combat: Node, caster: Character, reactor: Character, target: Dictionary) -> void:
	# Restrict each attempt to its authored reaction; inherited native Counterspell
	# cannot accidentally make a renamed definition appear functional.
	reactor.features = reactor.features.filter(func(feature): return feature.get("id") != "fixture:reaction_counterspell")
	var ids := ["fixture:029_stopping_spell", "fixture:029_renamed_breaker"]
	for stop_id in ids:
		SpellPermissionChecks.grant_slot_permission(reactor, [stop_id])
		var stopping_spell := DataLoader.get_spell(stop_id)
		combat._cancel_pending_action()
		combat._reset_turn_action_economy()
		h._p_focus(combat, caster, false)
		caster.spell_slots = {"1":4}
		var stopping_level := int(stopping_spell.level)
		reactor.spell_slots = {str(stopping_level):1}
		reactor.reaction_available = true
		if stop_id == "fixture:029_renamed_breaker": caster.add_modifier("roll", "save:CON", 20000, 100)
		combat.hud.update_hud(caster, combat.tracker)
		combat.hud._show_spell_selection()
		var selected := -1
		for index in combat.hud.spells_registered.size():
			var row: Dictionary = combat.hud.spells_registered[index]
			if row.get("id") == "fixture:029_target_refund" and row.get("_spell_payment_kind") == "slot": selected = index; break
		h._assert(selected >= 0, "029 ordinary cast picker starts authored stopping test: " + stop_id)
		if selected < 0: continue
		combat.hud._on_spell_selected(selected)
		await Batch027Controls.answer(h, combat, "", "Level 1")
		combat.call_deferred("_on_hex_clicked", target.hex_position)
		var reaction: ConfirmationDialog = null
		for frame in 120:
			await h.get_tree().process_frame
			for window in combat.hud.get_children():
				if window is ConfirmationDialog and window.visible and (str(window.title).contains(str(stopping_spell.name)) or str(window.dialog_text).contains(str(stopping_spell.name))): reaction = window; break
			if reaction != null: break
		h._assert(reaction != null, "029 actual reaction collector offers loaded custom spell: " + stop_id)
		if reaction != null: reaction.confirmed.emit()
		for frame in 120:
			await h.get_tree().process_frame
			if not combat._cast_in_progress: break
		var expected_target_slots := 4 if stop_id == "fixture:029_stopping_spell" else 3
		var expected_stopper_slots := 0 if stop_id == "fixture:029_stopping_spell" else 1
		h._assert(not combat._cast_in_progress and caster.spell_slots["1"] == expected_target_slots and reactor.spell_slots[str(stopping_level)] == expected_stopper_slots and not reactor.reaction_available and not combat.turn_budget.action_available, "029 authored stopping result settles original and stopping costs through actual controls: " + stop_id)
		reactor.features = reactor.features.filter(func(feature): return feature.get("id") != "fixture:reaction_" + stop_id)
