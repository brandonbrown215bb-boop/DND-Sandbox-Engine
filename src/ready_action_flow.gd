class_name ReadyActionFlow
extends RefCounted


static func answer(h: Node, combat: CombatState, operation: Callable, target: Variant, accept := true, cancel_target := false) -> Dictionary:
	var done := {"done":false}
	GameManager.test_mode = false
	_run(operation, done)
	var prompted := false
	for _frame in 300:
		await h.get_tree().process_frame
		for child in combat.hud.get_children():
			if not child is ConfirmationDialog or not child.visible: continue
			if child.dialog_text.contains("readied trigger"):
				prompted = true
				if accept: child.confirmed.emit()
				else: child.canceled.emit()
			else:
				# Optional Opportunity Attacks and riders are independent choices.
				child.canceled.emit()
		if not combat.ready_actions.selection.is_empty():
			if cancel_target: await combat._on_hud_action("cancel", {})
			elif target is Vector2i: await combat._on_hex_clicked(target)
		if done.done: break
	GameManager.test_mode = true
	h._assert(done.done and prompted, "S237 actual completed trigger and owning Reaction prompt settle")
	return done


static func _run(operation: Callable, done: Dictionary) -> void:
	await operation.call()
	done.done = true


static func declare(h: Node, combat: CombatState, actor: Character, response: Dictionary, trigger: Dictionary = {"event":"movement", "side":"enemy"}) -> void:
	h._p_focus(combat, actor)
	await combat._on_hud_action("ready_action", {"trigger":trigger, "response":response, "action_cost":"free"})
	h._assert(combat.ready_actions.held.has(actor.character_id) and not combat.turn_budget.can_spend("action") and actor.reaction_available, "S237 Ready costs the owner's Action now and reserves no extra Reaction")


static func run(h: Node) -> void:
	h._enter_test("ready_action_flow")
	h._setup_mixed_world()
	DataLoader._load_json_file("res://data/fixtures/ordinary_actions/ready_spells.json", "spell")
	DataLoader._load_json_file("res://data/fixtures/ordinary_actions/class.json", "class")
	var combat: CombatState = await h._spawn_scene("res://scenes/combat.tscn", 0.5)
	var fighter: Character = combat.player_entities[0].character
	var other: Character = combat.player_entities[1].character
	var wizard: Character = combat.player_entities[2].character
	for index in combat.player_entities.size(): combat.player_entities[index].hex_position = Vector2i(-index, 0)
	while fighter.level < 5: fighter.level_up()
	fighter.ability_scores.strength = 40
	fighter.ability_scores.dexterity = 40
	fighter.inventory.add_item("shortbow")
	fighter.inventory.unequip(Inventory.Slot.SHIELD)
	fighter.inventory.equip(Inventory.Slot.WEAPON, "shortbow", true)
	h._assert(fighter.inventory.get_weapon() == "shortbow", "S237 fixture equips legal ranged Ready weapon with Shield removed")
	var enemy: Dictionary = combat.monster_entities[0]
	enemy.current_hp = 10000; enemy.max_hp = 10000; enemy.armor_class = -100; enemy.hex_position = Vector2i(2, 0)
	var upgrade: Dictionary = DataLoader.get_character_class("fixture:ordinary_actions").features_by_level["1"][1].duplicate(true)
	fighter.features.append(upgrade)
	combat._update_grid_entities()
	await declare(h, combat, fighter, {"kind":"attack"})
	var hp := int(enemy.current_hp)
	h._p_focus(combat, other)
	combat.turn_budget.spend("action"); combat.turn_budget.spend("bonus_action")
	var movement := combat.remaining_speed
	FighterChecks._seed_die(20, 15)
	await answer(h, combat, func(): await combat._check_opportunity_attacks_for_path(null, enemy, [Vector2i(2, 0), Vector2i(3, 0)], true), Vector2i(3, 0))
	h._assert(enemy.current_hp < hp and not fighter.reaction_available and not combat.ready_actions.held.has(fighter.character_id), "S237 readied Attack resolves one strike and spends/consumes its exact Reaction once")
	h._assert(combat.active_character == other and not combat.turn_budget.action_available and not combat.turn_budget.bonus_action_available and combat.remaining_speed == movement and combat.remaining_attack_swings == 0, "S237 off-turn attack leaves interrupted actor, Action, Bonus Action, movement and Extra Attack budget unchanged")
	var attack: Dictionary = combat.ready_actions.last_result.get("result", {})
	var formula := str(attack.get("activity_damage", {}).get("formula", ""))
	h._assert(not attack.is_empty() and formula.count("+2") == 1, "S237 loaded additive weapon profile applies only once to readied attack: " + formula)
	# Declining/cancelling a trigger retains both held response and Reaction.
	await declare(h, combat, fighter, {"kind":"attack"})
	h._p_focus(combat, other)
	await answer(h, combat, func(): await combat._check_opportunity_attacks_for_path(null, enemy, [Vector2i(3, 0), Vector2i(2, 0)], true), null, false)
	h._assert(fighter.reaction_available and combat.ready_actions.held.has(fighter.character_id), "S237 declining a completed trigger keeps Ready and Reaction")
	await answer(h, combat, func(): await combat._check_opportunity_attacks_for_path(null, enemy, [Vector2i(2, 0), Vector2i(3, 0)], true), null, true, true)
	h._assert(fighter.reaction_available and combat.ready_actions.held.has(fighter.character_id), "S237 cancelling readied targeting ignores this trigger without payment")
	combat.ready_actions.clear_owner(fighter)
	# A readied movement has its own Speed allowance and ordinary OA policy.
	await declare(h, combat, fighter, {"kind":"move"})
	h._p_focus(combat, other)
	movement = combat.remaining_speed
	await answer(h, combat, func(): await combat._check_opportunity_attacks_for_path(null, enemy, [Vector2i(3, 0), Vector2i(2, 0)], true), Vector2i(0, 1))
	h._assert(combat.player_entities[0].hex_position == Vector2i(0, 1) and combat.remaining_speed == movement and not fighter.reaction_available, "S237 readied movement uses its owner's Speed without borrowing interrupted movement")
	await spells(h, combat, wizard, other, enemy)
	await thunderwave_ready(h, combat, wizard, fighter, other, enemy)
	await own_turn(h, combat, fighter, other, enemy)
	await expiry(h, combat, fighter, enemy)
	await OrdinaryWorldActionFlow.run(h, combat, fighter, other, enemy)
	h._teardown_scene(combat)
	h._assert(combat.ready_actions.held.is_empty() and wizard.concentrating_on.is_empty(), "S237 encounter teardown clears held actions/energy without durable state")
	h._exit_test()


static func spells(h: Node, combat: CombatState, wizard: Character, other: Character, enemy: Dictionary) -> void:
	wizard.known_spells.assign(["fixture:held_bolt", "fixture:renamed_held_bolt"])
	h._own_class_spells(wizard); h._ready_spell_components(wizard)
	for id in ["fixture:held_bolt", "fixture:renamed_held_bolt"]:
		wizard.spell_slots["1"] = 1
		var options := SpellPermissionRules.payment_choices(wizard, id)
		h._assert(not options.is_empty(), "S237 loaded renamed held spell has production cast permission")
		if options.is_empty(): continue
		await declare(h, combat, wizard, {"kind":"spell", "spell":options[0]})
		h._assert(wizard.spell_slots["1"] == 0 and not wizard.concentrating_on.get("ready_token", "").is_empty(), "S237 Ready spends last slot now and holds even a non-Concentration spell with exact Concentration token")
		h._p_focus(combat, other)
		var hp := int(enemy.current_hp)
		var origin: Vector2i = enemy.hex_position
		var destination := Vector2i(2, 0) if origin != Vector2i(2, 0) else Vector2i(3, 0)
		FighterChecks._seed_die(20, 15)
		await answer(h, combat, func(): await combat._check_opportunity_attacks_for_path(null, enemy, [origin, destination], true), destination)
		h._assert(wizard.spell_slots["1"] == 0 and int(enemy.current_hp) == hp - 1 and wizard.concentrating_on.is_empty() and not wizard.reaction_available, "S237 actual readied spell releases after trigger without re-paying last slot or retaining hold: " + id)
	wizard.known_spells.append("magic_missile")
	h._own_class_spells(wizard)
	wizard.spell_slots["1"] = 1
	await declare(h, combat, wizard, {"kind":"spell", "spell":SpellPermissionRules.payment_choices(wizard, "magic_missile")[0]})
	h._p_focus(combat, other)
	var missile_hp := int(enemy.current_hp)
	var missile_origin: Vector2i = enemy.hex_position
	var missile_destination := Vector2i(2, 0) if missile_origin != Vector2i(2, 0) else Vector2i(3, 0)
	await answer(h, combat, func(): await combat._check_opportunity_attacks_for_path(null, enemy, [missile_origin, missile_destination], true), missile_destination)
	var missile_damage := missile_hp - int(enemy.current_hp)
	h._assert(missile_damage >= 6 and missile_damage <= 15 and wizard.spell_slots["1"] == 0 and not wizard.reaction_available, "S237 actual readied native Magic Missile assigns all three projectiles and pays its last slot once")
	wizard.spell_slots["1"] = 1
	h._p_focus(combat, wizard)
	combat.turn_budget.action_available = false
	combat.turn_budget.grant_surge_action()
	var restricted := await combat.ready_actions.begin(combat, wizard, {"event":"movement", "side":"enemy"}, {"kind":"spell", "spell":SpellPermissionRules.payment_choices(wizard, "fixture:held_bolt")[0]})
	h._assert(not restricted.success and wizard.spell_slots["1"] == 1 and combat.turn_budget.surge_actions == 1, "S237 restricted extra Action cannot become a cast-now spell or an unpaid future Magic action through Ready")
	# Breaking concentration before the trigger dissipates energy without refund.
	wizard.spell_slots["1"] = 1
	await declare(h, combat, wizard, {"kind":"spell", "spell":SpellPermissionRules.payment_choices(wizard, "fixture:held_bolt")[0]})
	wizard.add_condition("stunned", 100, "fixture:interrupt_hold")
	h._assert(not combat.ready_actions.valid(combat, combat.ready_actions.held[wizard.character_id]) and wizard.spell_slots["1"] == 0 and wizard.concentrating_on.is_empty(), "S237 Incapacitated dissipates held energy without refund")
	CombatAction.remove_condition_source(wizard, "fixture:interrupt_hold", ["stunned"])
	combat.ready_actions.clear_owner(wizard)
	await material_hold(h, combat, wizard, other, enemy)
	await marker_hold(h, combat, wizard, other, enemy)


static func interrupt_ready_thunderwave(h: Node, combat: CombatState, wizard: Character, spell: Dictionary, trigger: Dictionary) -> Dictionary:
	var run_state := {"done":false}
	GameManager.test_mode = false
	_run(func():
		await combat._on_hud_action("ready_action", {"trigger":trigger, "response":{"kind":"spell", "spell":spell}, "action_cost":"free"})
		run_state["done"] = true
	, run_state)
	var counterspell_prompt := false
	var verbal_reaction_prompt := false
	for _frame in 300:
		await h.get_tree().process_frame
		for dialog in combat.hud.get_children():
			if dialog is PopupMenu and dialog.visible and dialog.item_count > 0:
				dialog.id_pressed.emit(dialog.get_item_id(0))
			if not dialog is ConfirmationDialog or not dialog.visible: continue
			if str(dialog.dialog_text).contains("Force a Constitution save"):
				counterspell_prompt = true
				dialog.confirmed.emit()
			elif str(dialog.dialog_text).contains("readied trigger"):
				verbal_reaction_prompt = true
				dialog.confirmed.emit()
			else:
				dialog.canceled.emit()
		if run_state.done: break
	GameManager.test_mode = true
	h._assert(run_state.done and counterspell_prompt and verbal_reaction_prompt, "S237 actual Counterspell interrupts Thunderwave Ready and its separate Verbal sound still resolves")
	return run_state


static func thunderwave_ready(h: Node, combat: CombatState, wizard: Character, fighter: Character, other: Character, enemy: Dictionary) -> void:
	var listener: Character = combat.player_entities[3].character
	var enemy_origin: Vector2i = enemy.hex_position
	var wizard_origin: Vector2i = combat.player_entities[2].hex_position
	var fighter_origin: Vector2i = combat.player_entities[0].hex_position
	var other_origin: Vector2i = combat.player_entities[1].hex_position
	var listener_origin: Vector2i = combat.player_entities[3].hex_position
	var enemy_hp: int = int(enemy.current_hp)
	combat.player_entities[2].hex_position = Vector2i(-2, 0)
	combat.player_entities[0].hex_position = Vector2i(-3, 0)
	combat.player_entities[1].hex_position = Vector2i(-4, 2)
	combat.player_entities[3].hex_position = Vector2i(11, 0)
	enemy.hex_position = Vector2i(0, 0)
	enemy.current_hp = 10000
	enemy.max_hp = 10000
	enemy.armor_class = -100
	enemy["saving_throw_bonuses"] = {"CON":-1000}
	for q in range(-4, 13):
		var tile_position := Vector2i(q, 0)
		if not combat.hex_grid.has_tile(tile_position):
			var tile := HexTile.new()
			tile.coord = tile_position
			combat.hex_grid.add_tile(tile)
	combat._update_grid_entities()
	wizard.known_spells.append("thunderwave")
	h._own_class_spells(wizard)
	wizard.spell_slots["1"] = 1
	fighter.reaction_available = true
	listener.reaction_available = true
	wizard.reaction_available = true
	fighter.remove_condition("dodging")
	listener.remove_condition("dodging")
	var origin := Vector2i(-2, 0)
	var sound_trigger: Dictionary = {"event":"sound", "side":"ally", "actor_id":wizard.character_id, "at_hex":[origin.x, origin.y]}
	await h._start_class_fixture_turn(combat, fighter)
	await declare(h, combat, fighter, {"kind":"ordinary", "action":"dodge"}, sound_trigger)
	await h._start_class_fixture_turn(combat, listener)
	await declare(h, combat, listener, {"kind":"ordinary", "action":"dodge"}, sound_trigger)
	await h._start_class_fixture_turn(combat, wizard)
	var receipt_start: int = combat.ready_actions.receipts.size()
	await declare(h, combat, wizard, {"kind":"spell", "spell":SpellPermissionRules.payment_choices(wizard, "thunderwave")[0]}, {"event":"movement", "side":"enemy"})
	h._assert(wizard.spell_slots["1"] == 0 and wizard.reaction_available and not combat.turn_budget.can_spend("action") and not wizard.concentrating_on.get("ready_token", "").is_empty(), "S237 native Thunderwave Ready pays its last slot and Action at declaration, not effect release")
	var verbal_receipt: Dictionary = combat.ready_actions.receipts.back() if combat.ready_actions.receipts.size() > receipt_start else {}
	h._assert("V" in DataLoader.get_spell("thunderwave").get("components", []) and combat.ready_actions.receipts.size() == receipt_start + 1 and str(verbal_receipt.get("status", "")) == "declined" and fighter.reaction_available and combat.ready_actions.held.has(fighter.character_id) and listener.reaction_available and combat.ready_actions.held.has(listener.character_id), "S237 Ready Thunderwave's separate Verbal event is audible to the close listener, while the 65-foot listener holds through the 60-foot cast sound")
	combat.ready_actions.clear_owner(fighter)
	var direction := Vector2i(-1, 0)
	var held_hp: int = int(enemy.current_hp)
	h._p_focus(combat, other)
	await answer(h, combat, func(): await combat._check_opportunity_attacks_for_path(null, enemy, [Vector2i(0, 0), Vector2i(1, 0)], true), null, true, true)
	h._assert(wizard.spell_slots["1"] == 0 and int(enemy.current_hp) == held_hp and wizard.reaction_available and combat.ready_actions.held.has(wizard.character_id) and listener.reaction_available and combat.ready_actions.receipts.size() == receipt_start + 2, "S237 cancelling a native area-release target preserves paid Thunderwave and emits no effect sound")
	var stale := {"done":false, "mutated":false, "prompted":false}
	GameManager.test_mode = false
	_run(func():
		await combat._check_opportunity_attacks_for_path(null, enemy, [Vector2i(1, 0), Vector2i(0, 0)], true)
		stale["done"] = true
	, stale)
	for _frame in 240:
		await h.get_tree().process_frame
		for dialog in combat.hud.get_children():
			if dialog is ConfirmationDialog and dialog.visible and str(dialog.dialog_text).contains("readied trigger"):
				stale["prompted"] = true
				dialog.confirmed.emit()
		if not combat.ready_actions.selection.is_empty() and not stale.mutated:
			combat.player_entities[2].hex_position = Vector2i(-3, 0)
			combat._update_grid_entities()
			stale["mutated"] = true
			await combat._on_hex_clicked(direction)
		if stale.done: break
	GameManager.test_mode = true
	combat.player_entities[2].hex_position = origin
	combat._update_grid_entities()
	h._assert(stale.done and stale.prompted and stale.mutated and str(combat.ready_actions.last_result.get("status", "")) == "stale" and wizard.spell_slots["1"] == 0 and int(enemy.current_hp) == held_hp and wizard.reaction_available and combat.ready_actions.held.has(wizard.character_id) and listener.reaction_available and combat.ready_actions.receipts.size() == receipt_start + 3, "S237 stale live Thunderwave release selection pays no Reaction, resolves no effect, emits no boom and retains the held spell")
	var receipts_before_release: int = combat.ready_actions.receipts.size()
	var target_hp_before: int = int(enemy.current_hp)
	var interrupted_action_before: bool = combat.turn_budget.can_spend("action")
	await answer(h, combat, func(): await combat._check_opportunity_attacks_for_path(null, enemy, [Vector2i(0, 0), Vector2i(1, 0)], true), direction)
	h._assert(int(enemy.current_hp) < target_hp_before and wizard.spell_slots["1"] == 0 and combat.turn_budget.can_spend("action") == interrupted_action_before and wizard.concentrating_on.is_empty(), "S237 actual readied native Thunderwave resolves its Cube and does not repay its declaration slot or Action: hp=%d/%d slot=%d action=%s/%s concentration=%s" % [int(enemy.current_hp), target_hp_before, int(wizard.spell_slots["1"]), str(combat.turn_budget.can_spend("action")), str(interrupted_action_before), str(wizard.concentrating_on)])
	h._assert(not listener.reaction_available and listener.has_condition("dodging") and not combat.ready_actions.held.has(listener.character_id) and not wizard.reaction_available and combat.ready_actions.receipts.size() == receipts_before_release + 2, "S237 only the released 300-foot effect boom reaches the Ready listener 65 feet away")
	var receipts_after_release: int = combat.ready_actions.receipts.size()
	listener.remove_condition("dodging")
	listener.reaction_available = true
	fighter.reaction_available = true
	fighter.remove_condition("dodging")
	var other_slots_before: Dictionary = other.spell_slots.duplicate(true)
	var other_reaction_before: bool = other.reaction_available
	combat.player_entities[1].hex_position = Vector2i(-1, 0)
	combat._update_grid_entities()
	await h._start_class_fixture_turn(combat, listener)
	await declare(h, combat, listener, {"kind":"ordinary", "action":"dodge"}, sound_trigger)
	await h._start_class_fixture_turn(combat, fighter)
	await declare(h, combat, fighter, {"kind":"ordinary", "action":"dodge"}, sound_trigger)
	SpellPermissionChecks.grant_slot_permission(other, ["counterspell"])
	other.spell_slots = {"3":1}
	h._assert(not SpellPermissionRules.payment_choices(other, "counterspell").is_empty(), "S237 counterspell fixture owns the production Reaction-spell permission")
	other.reaction_available = true
	await h._start_class_fixture_turn(combat, other)
	await h._start_class_fixture_turn(combat, wizard)
	wizard.spell_slots["1"] = 1
	var interrupt_receipts_before: int = combat.ready_actions.receipts.size()
	await interrupt_ready_thunderwave(h, combat, wizard, SpellPermissionRules.payment_choices(wizard, "thunderwave")[0], {"event":"movement", "side":"enemy"})
	var interruption_receipt: Dictionary = combat.ready_actions.receipts.back() if combat.ready_actions.receipts.size() > interrupt_receipts_before else {}
	h._assert(wizard.spell_slots["1"] == 1 and not combat.turn_budget.can_spend("action") and wizard.reaction_available and not combat.ready_actions.held.has(wizard.character_id) and other.spell_slots["3"] == 0 and not other.reaction_available and not fighter.reaction_available and str(interruption_receipt.get("status", "")) == "resolved" and listener.reaction_available and combat.ready_actions.held.has(listener.character_id), "S237 Counterspell refunds the interrupted Ready spell slot, keeps the casting Action spent, spends only its own Reaction, and leaves no Thunderwave energy or 300-foot sound")
	var receipts_after_interrupted_cast: int = combat.ready_actions.receipts.size()
	other.spell_slots = other_slots_before
	other.reaction_available = other_reaction_before
	fighter.remove_condition("dodging")
	fighter.reaction_available = true
	await h._start_class_fixture_turn(combat, other)
	await h._start_class_fixture_turn(combat, wizard)
	wizard.spell_slots["1"] = 1
	await declare(h, combat, wizard, {"kind":"spell", "spell":SpellPermissionRules.payment_choices(wizard, "thunderwave")[0]})
	wizard.add_condition("stunned", 100, "fixture:thunderwave_ready_lost_concentration")
	h._assert(not combat.ready_actions.valid(combat, combat.ready_actions.held.get(wizard.character_id, {})) and wizard.concentrating_on.is_empty() and wizard.spell_slots["1"] == 0 and listener.reaction_available and combat.ready_actions.held.has(listener.character_id) and combat.ready_actions.receipts.size() == receipts_after_interrupted_cast, "S237 lost concentration invalidates native Thunderwave without refund or effect sound")
	CombatAction.remove_condition_source(wizard, "fixture:thunderwave_ready_lost_concentration", ["stunned"])
	wizard.spell_slots["1"] = 1
	await h._start_class_fixture_turn(combat, wizard)
	await declare(h, combat, wizard, {"kind":"spell", "spell":SpellPermissionRules.payment_choices(wizard, "thunderwave")[0]})
	await h._start_class_fixture_turn(combat, other)
	await h._start_class_fixture_turn(combat, wizard)
	h._assert(not combat.ready_actions.held.has(wizard.character_id) and wizard.concentrating_on.is_empty() and wizard.spell_slots["1"] == 0 and listener.reaction_available and combat.ready_actions.held.has(listener.character_id) and combat.ready_actions.receipts.size() == receipts_after_interrupted_cast, "S237 next-owner-turn expiry dissipates native Thunderwave without refund or effect sound")
	combat.ready_actions.clear_owner(listener)
	combat.ready_actions.clear_owner(wizard)
	wizard.known_spells.erase("thunderwave")
	enemy.erase("saving_throw_bonuses")
	combat.player_entities[2].hex_position = wizard_origin
	combat.player_entities[0].hex_position = fighter_origin
	combat.player_entities[1].hex_position = other_origin
	combat.player_entities[3].hex_position = listener_origin
	enemy.hex_position = enemy_origin
	enemy.current_hp = enemy_hp
	combat._update_grid_entities()


static func material_hold(h: Node, combat: CombatState, wizard: Character, other: Character, enemy: Dictionary) -> void:
	wizard.known_spells.append("fixture:material_held_bolt")
	h._own_class_spells(wizard)
	wizard.spell_slots["1"] = 1
	enemy.current_hp = int(enemy.max_hp) - 2
	h._p_focus(combat, wizard)
	var selected: Dictionary = SpellPermissionRules.payment_choices(wizard, "fixture:material_held_bolt")[0]
	wizard.add_condition("hidden", 100, "fixture:oa02_hidden_caster")
	var missing := await combat.ready_actions.begin(combat, wizard, {"event":"movement", "side":"enemy"}, {"kind":"spell", "spell":selected})
	h._assert(not missing.success and wizard.spell_slots["1"] == 1 and combat.turn_budget.action_available, "S237 missing consumed component refuses Ready before Action or slot payment")
	wizard.inventory.add_item("diamond_300gp")
	var component := wizard.inventory.required_spell_component_instance(DataLoader.get_spell("fixture:material_held_bolt"))
	await declare(h, combat, wizard, {"kind":"spell", "spell":selected})
	h._assert(not component.is_empty() and wizard.inventory.get_instance(component).is_empty() and wizard.spell_slots["1"] == 0, "S237 Ready consumes the exact material copy at casting time")
	var token := str(wizard.concentrating_on.get("ready_token", ""))
	h._p_focus(combat, other)
	var origin: Vector2i = enemy.hex_position
	var destination := Vector2i(2, 0) if origin != Vector2i(2, 0) else Vector2i(3, 0)
	await answer(h, combat, func(): await combat._check_opportunity_attacks_for_path(null, enemy, [origin, destination], true), null, true, true)
	h._assert(wizard.concentrating_on.get("ready_token", "") == token and wizard.reaction_available and combat.ready_actions.held.has(wizard.character_id) and wizard.has_condition("hidden"), "OA02 cancelled target-origin release preserves held energy and caster Hide")
	var hp := int(enemy.current_hp)
	FighterChecks._seed_die(20, 15)
	await answer(h, combat, func(): await combat._check_opportunity_attacks_for_path(null, enemy, [destination, origin], true), origin)
	h._assert(enemy.current_hp == hp + 1 and wizard.spell_slots["1"] == 0 and wizard.concentrating_on.is_empty() and not wizard.reaction_available and wizard.has_condition("hidden"), "OA02 successful readied release emits once from the exact target and keeps caster Hide")


static func expiry(h: Node, combat: CombatState, actor: Character, enemy: Dictionary) -> void:
	await declare(h, combat, actor, {"kind":"ordinary", "action":"dodge"})
	await h._start_class_fixture_turn(combat, actor)
	h._assert(not combat.ready_actions.held.has(actor.character_id) and not actor.has_condition("dodging"), "S237 actual next owner turn expires held action before start effects")
	await declare(h, combat, actor, {"kind":"ordinary", "action":"disengage"})
	var other: Character = combat.player_entities[1].character
	h._p_focus(combat, other)
	var origin: Vector2i = enemy.hex_position
	var destination := Vector2i(2, 0) if origin != Vector2i(2, 0) else Vector2i(3, 0)
	await answer(h, combat, func(): await combat._check_opportunity_attacks_for_path(null, enemy, [origin, destination], true), null)
	h._assert(actor.has_condition("disengaging"), "S237 readied Disengage is active for triggering turn")
	combat.ready_actions.end_turn()
	h._assert(not actor.has_condition("disengaging"), "S237 readied Disengage ends with triggering turn, before owner's next turn")


static func marker_hold(h: Node, combat: CombatState, wizard: Character, other: Character, enemy: Dictionary) -> void:
	wizard.known_spells.append("mage_hand")
	h._own_class_spells(wizard)
	var selected := await combat.hud.request_spell_payment(wizard, "mage_hand")
	h._assert(not selected.is_empty() and selected.get("_spell_payment_kind", "invalid") == "", "S237 actual source/payment chooser offers owned cantrips without a slot")
	if selected.is_empty(): return
	await declare(h, combat, wizard, {"kind":"spell", "spell":selected})
	# These arrive after the held spell was actually cast. Releasing its energy
	# cannot repeat the cast activity and strip these new sources.
	var invisibility := CombatAction.resolve_spell(other, wizard, DataLoader.get_spell("invisibility"), false)
	other.concentrating_on = {"spell_id":"invisibility", "effect_source":str(invisibility.get("effect_cast", {}).get("source_id", "")), "targets":[wizard]}
	CombatAction.resolve_spell(other, wizard, DataLoader.get_spell("sanctuary"), false)
	h._assert(SpellEffects.has_spell(wizard, "invisibility") and SpellEffects.has_spell(wizard, "sanctuary"), "S237 fixture grants new spell sources after Ready casting")
	h._p_focus(combat, other)
	var destination := Vector2i(0, 2)
	var origin: Vector2i = enemy.hex_position
	var next := Vector2i(2, 0) if origin != Vector2i(2, 0) else Vector2i(3, 0)
	await answer(h, combat, func(): await combat._check_opportunity_attacks_for_path(null, enemy, [origin, next], true), destination)
	h._assert(combat.mage_hand_markers.get(wizard.character_id, {}).get("position") == [destination.x, destination.y] and not wizard.reaction_available, "S237 readied point spell creates its actual marker on an empty legal hex")
	h._assert(SpellEffects.has_spell(wizard, "invisibility") and SpellEffects.has_spell(wizard, "sanctuary"), "S237 releasing a held marker does not repeat cast cleanup on newly acquired Invisibility or Sanctuary")


static func own_turn(h: Node, combat: CombatState, actor: Character, other: Character, enemy: Dictionary) -> void:
	h._p_focus(combat, actor)
	var prior := combat.active_combatant
	combat.active_combatant = {"is_player":false, "entity":enemy}
	var rejected := await combat.ready_actions.begin(combat, actor, {"event":"movement", "side":"enemy"}, {"kind":"attack"})
	h._assert(not rejected.success and combat.turn_budget.can_spend("action") and not combat.ready_actions.held.has(actor.character_id), "S237 stale previous-player pointers cannot Ready during actual monster turn")
	combat.active_combatant = prior
	await declare(h, combat, actor, {"kind":"ordinary", "action":"dash"}, {"event":"movement", "side":"any", "actor_id":actor.character_id})
	var origin: Vector2i = combat.player_entities[0].hex_position
	var destination := Vector2i(1, 1) if origin != Vector2i(1, 1) else Vector2i(0, 1)
	actor.add_condition("blinded", 100)
	var speed := combat.remaining_speed
	var bonus := combat._active_movement_speed_hexes()
	await answer(h, combat, func(): await combat._check_opportunity_attacks_for_path(actor, combat.player_entities[0], [origin, destination], false), null)
	h._assert(combat.remaining_speed == speed + bonus and not actor.reaction_available and not combat.turn_budget.action_available, "S237 self-triggered readied Dash grants actual movement only, without refilling Action or Reaction")
	actor.remove_condition("blinded")
	combat.ready_actions.end_turn()
	h._assert(combat.ready_actions.dash_movement.is_empty(), "S237 unused readied Dash allowance expires with triggering turn")
