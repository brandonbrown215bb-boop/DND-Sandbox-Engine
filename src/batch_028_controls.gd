class_name Batch028Controls
extends RefCounted

static func pause(h: Node, frames: int = 4) -> void:
	for frame in frames: await h.get_tree().process_frame

static func pick_spell(h: Node, combat: Node, id: String) -> bool:
	combat.hud._show_spell_selection()
	for index in combat.hud.spells_registered.size():
		if combat.hud.spells_registered[index].get("id") == id and not combat.hud.spell_list.is_item_disabled(index):
			combat.hud._on_spell_selected(index)
			await Batch027Controls.answer(h, combat, "", "Level 1")
			return combat.pending_action_type == "spell"
	return false

static func reset(h: Node, combat: Node, actor: Character) -> void:
	combat._cancel_pending_action()
	combat.remaining_attack_swings = 0
	combat._reset_turn_action_economy()
	h._p_focus(combat, actor, false)
	combat.remaining_speed = 6.0
	actor.spell_slots = {"1":20}

static func choose(h: Node, combat: Node, child: String) -> bool:
	return await Batch027Controls.answer(h, combat, "Choose child action", child)

static func run(h: Node) -> void:
	h._enter_test("batch_028_actions_flow")
	h._setup_world()
	Batch028Checks.load_fixtures()
	h._assert(DataLoader.get_load_errors().is_empty(), "028 examples load through ordinary spell/class/item validation")
	var scores := AbilityScores.new()
	scores.from_dict({"STR":16,"DEX":20,"CON":14,"INT":16,"WIS":10,"CHA":10})
	var actor := Character.new()
	actor.initialize("Sequence owner", "human", "fixture:028_class", scores)
	actor.character_id = "b028_owner"
	actor.max_hp = 100
	actor.current_hp = 20
	actor.extra_attacks = 3
	actor.spell_slots = {"1":20}
	actor.inventory.add_item("fixture:028_draught")
	actor.inventory.add_item("fixture:028_draught")
	var observer := Character.new()
	observer.initialize("Sequence witness", "human", "monk", scores)
	observer.level_up()
	observer.character_id = "b028_witness"
	observer.max_hp = 100
	observer.current_hp = 100
	while PlayerManager.get_player_count() < 2: PlayerManager.add_player("Witness")
	PartyManager.reset()
	PlayerManager.set_player_character(1, observer)
	PartyManager.register_player_character(1, observer)
	PlayerManager.set_player_character(0, actor)
	PartyManager.register_player_character(0, actor)
	GameManager.transition_context = {"terrain":"plains", "monster_ids":["goblin"]}
	GameManager.current_state = GameManager.GameState.COMBAT
	GameManager.test_mode = false
	FighterChecks._seed_die(20, 20)
	var combat: Node = await h._spawn_scene("res://scenes/combat.tscn", 0.8)
	for frame in 600:
		if combat.active_combatant.get("is_player", false): break
		await h.get_tree().process_frame
	h._p_focus(combat, actor)
	combat.player_entities[0].hex_position = Vector2i.ZERO
	combat.player_entities[1].hex_position = Vector2i(0,1)
	var enemy: Dictionary = combat.monster_entities[0]
	enemy.hex_position = Vector2i(1,0)
	enemy.current_hp = 1000
	enemy.max_hp = 1000
	combat._update_grid_entities()
	combat.hud.btn_attack.pressed.emit()
	await combat._on_hex_clicked(enemy.hex_position)
	h._assert(combat.remaining_attack_swings == 3 and not combat.turn_budget.action_available, "028 actual Attack resolves one strike and retains three units for substitution")
	var slots := int(actor.spell_slots["1"])
	h._assert(await pick_spell(h, combat, "fixture:028_one"), "028 actual spell and slot pickers select an eligible one-unit child")
	combat.hud.cancel_pressed.emit()
	await pause(h)
	h._assert(combat.remaining_attack_swings == 3 and actor.spell_slots["1"] == slots, "028 cancel targeting preserves units and spell payment")
	await pick_spell(h, combat, "fixture:028_one")
	var hp := actor.current_hp
	await combat._on_hex_clicked(Vector2i.ZERO)
	h._assert(actor.current_hp == hp+2 and actor.spell_slots["1"] == slots-1 and combat.remaining_attack_swings == 2 and not combat.turn_budget.action_available, "028 actual target heals and pays one slot/one unit without another Action")
	await pick_spell(h, combat, "fixture:028_two")
	await combat._on_hex_clicked(Vector2i.ZERO)
	h._assert(combat.remaining_attack_swings == 0 and actor.spell_slots["1"] == slots-2, "028 two-unit spell consumes exactly the remaining two units")
	await combat._on_hex_clicked(Vector2i.ZERO)
	h._assert(actor.spell_slots["1"] == slots-2, "028 repeated target click cannot replay a settled child")
	reset(h, combat, actor)
	combat.hud.btn_attack.pressed.emit()
	await combat._on_hex_clicked(enemy.hex_position)
	var copies := actor.inventory.backpack_instances().filter(func(copy): return copy.definition_id == "fixture:028_draught")
	var first := str(copies[0].instance_id)
	var sibling := str(copies[1].instance_id)
	combat.hud._show_feature_selection()
	for index in combat.hud.features_registered.size():
		if combat.hud.features_registered[index].get("instance_id") == first: combat.hud._on_feature_selected(index); break
	h._assert(actor.inventory.get_instance(first).is_empty() and not actor.inventory.get_instance(sibling).is_empty() and combat.remaining_attack_swings == 1, "028 actual item control consumes the exact copy and two units, preserving its sibling")
	var before_heal := actor.current_hp
	h._assert(h._p_select(combat, "fixture:028_heal"), "028 self-healing feature stays selectable with strike units and no Action")
	h._assert(actor.current_hp > before_heal and actor.feature_uses["fixture:028_heal"] == 3 and combat.remaining_attack_swings == 0, "028 non-spell healing pays its own use and one strike unit")
	# Real parent feature -> child chooser -> ordinary targeting, with local waivers.
	reset(h, combat, actor)
	h._assert(h._p_select(combat, "fixture:028_parent_action"), "028 Action parent is offered through the feature menu")
	h._assert(await choose(h, combat, "Strike:"), "028 actual chooser selects a declared strike")
	var hp_enemy := int(enemy.current_hp)
	combat.call_deferred("_on_hex_clicked", enemy.hex_position)
	h._assert(await choose(h, combat, "Move:"), "028 strike resumes its parent chooser once")
	var canonical_parents: Array = CombatAction.weapon_rider_rolls.values().filter(func(roll): return str(roll.get("parent", "")) == "sequence_action" and roll.get("causal_parent", {}).get("source_id") == "fixture:028_parent_action")
	h._assert(canonical_parents.size() == 1, "028 actual weapon receipt carries child parent classification/source into rider eligibility")
	h._assert(int(enemy.current_hp) <= hp_enemy and combat.child_actions.receipts.size() == 1 and combat.remaining_attack_swings == 0, "028 child strike retains its own receipt without creating Extra Attack units")
	combat.call_deferred("_on_hex_clicked", Vector2i(-1,0))
	h._assert(await choose(h, combat, "Cast:"), "028 real movement resumes the parent to select its cast child")
	await Batch027Controls.answer(h, combat, "", "Level 1")
	h._assert(combat.player_entities[0].hex_position == Vector2i(-1,0) and combat.remaining_speed == 5.0, "028 move child uses ordinary legal movement and spends its actual distance")
	combat.call_deferred("_on_hex_clicked", Vector2i(-1,0))
	await pause(h, 30)
	h._assert(combat.child_actions.frame.is_empty() and combat.child_actions.receipts.size() == 3 and actor.feature_uses["fixture:028_parent_action"] == 2 and not combat.turn_budget.action_available and combat.turn_budget.bonus_action_available, "028 three children finish exactly once under one paid Action parent")
	var receipt: Dictionary = combat.child_actions.receipts[-1]
	h._assert(receipt.action_id == "sequence_action" and receipt.source_id == "fixture:028_parent_action" and combat.child_actions.receipts[0].parent == receipt.parent, "028 sibling receipts preserve parent classification and original causal source")
	# Bonus parent cancellation stops without refund/restart; Reaction parent skip retains siblings.
	reset(h, combat, actor)
	h._p_select(combat, "fixture:028_parent_bonus")
	await choose(h, combat, "Strike:")
	combat.hud.cancel_pressed.emit()
	await pause(h)
	h._assert(combat.child_actions.frame.is_empty() and not combat.turn_budget.bonus_action_available and combat.turn_budget.action_available and actor.feature_uses["fixture:028_parent_bonus"] == 2, "028 stop policy ends the paid Bonus parent without charging its Action or restarting")
	reset(h, combat, actor)
	h._p_select(combat, "fixture:028_parent_reaction")
	await choose(h, combat, "Strike:")
	combat.hud.cancel_pressed.emit()
	h._assert(await choose(h, combat, "Move:"), "028 skip policy drops only canceled child and resumes remaining siblings")
	h._assert(not actor.reaction_available and combat.turn_budget.action_available and combat.turn_budget.bonus_action_available, "028 Reaction parent spends only its own Reaction")
	combat.hud.cancel_pressed.emit()
	await choose(h, combat, "")
	await pause(h)
	h._assert(combat.child_actions.frame.is_empty() and actor.feature_uses["fixture:028_parent_reaction"] == 2, "028 declining resumed chooser does not repay or replay the parent")
	# Refusal after selection and renamed consumers through the same game route.
	reset(h, combat, actor)
	combat.player_entities[0].hex_position = Vector2i.ZERO
	combat._update_grid_entities()
	combat.hud.btn_attack.pressed.emit()
	await combat._on_hex_clicked(enemy.hex_position)
	await pick_spell(h, combat, "fixture:028_renamed")
	var spell_source := actor.get_feature("fixture:028_spells")
	actor.features.erase(spell_source)
	await combat._on_hex_clicked(Vector2i.ZERO)
	h._assert(actor.spell_slots["1"] == 20 and combat.remaining_attack_swings == 3 and not combat._cast_in_progress, "028 loss of selected permission refuses before payment and releases input")
	actor.features.append(spell_source)
	await pick_spell(h, combat, "fixture:028_renamed")
	await combat._on_hex_clicked(Vector2i.ZERO)
	h._assert(actor.spell_slots["1"] == 19 and combat.remaining_attack_swings == 2, "028 renamed loaded spell executes without native ID dispatch")
	# Incremental native Flurry uses the same declared substitution path.
	observer.features.append(spell_source.duplicate(true))
	observer.spell_slots = {"1":2}
	h._p_focus(combat, observer)
	combat._reset_turn_action_economy()
	combat.player_entities[1].hex_position = Vector2i(1,-1)
	combat._update_grid_entities()
	var focus_before := observer.get_focus_points()
	h._assert(h._p_select(combat, "monk_flurry_of_blows"), "028 native Flurry remains selectable")
	await combat._on_hex_clicked(enemy.hex_position)
	h._assert(combat.remaining_flurry_swings == 1 and observer.get_focus_points() == focus_before-1 and not combat.turn_budget.bonus_action_available, "028 Flurry commits its Bonus/Focus once and leaves one explicit unit")
	await pick_spell(h, combat, "fixture:028_one")
	await combat._on_hex_clicked(Vector2i(1,-1))
	h._assert(combat.remaining_flurry_swings == 0 and observer.spell_slots["1"] == 1 and combat.turn_budget.action_available, "028 Flurry substitution consumes its unit and spell payment while preserving Action")
	# Counterspell interrupts a real child, returns to its paid parent and never replays it.
	reset(h, combat, actor)
	SpellPermissionChecks.grant_slot_permission(observer, ["counterspell"])
	observer.spell_slots = {"3":1}
	observer.reaction_available = true
	actor.add_modifier("roll", "save:CON", -1000, 4)
	var prior_receipts: int = combat.child_actions.receipts.size()
	h._p_select(combat, "fixture:028_parent_bonus")
	await choose(h, combat, "Cast:")
	await Batch027Controls.answer(h, combat, "", "Level 1")
	var old_hp := actor.current_hp
	combat.call_deferred("_on_hex_clicked", Vector2i.ZERO)
	var reaction: ConfirmationDialog = null
	for frame in 120:
		await h.get_tree().process_frame
		for window in combat.hud.get_children():
			if window is ConfirmationDialog and window.visible and str(window.dialog_text).contains("Force a Constitution save"): reaction = window; break
		if reaction != null: break
	h._assert(reaction != null, "028 actual Counterspell prompt suspends a selected child")
	# A second click while paused must not launch a second invocation/payment.
	combat.call_deferred("_on_hex_clicked", Vector2i.ZERO)
	if reaction != null: reaction.confirmed.emit()
	h._assert(await choose(h, combat, "Move:"), "028 interrupted cast resumes its original parent chooser once")
	h._assert(actor.current_hp == old_hp and actor.spell_slots["1"] == 20 and observer.spell_slots["3"] == 0 and not observer.reaction_available and combat.child_actions.receipts.size() == prior_receipts+1 and not combat.turn_budget.bonus_action_available, "028 interrupted child refunds exact spell slot, spends Counterspell Reaction and retains paid parent once")
	combat.hud.cancel_pressed.emit()
	await pause(h)
	h._assert(combat.child_actions.frame.is_empty(), "028 stop policy after interrupted child ends remaining siblings")
	# A delayed chooser callback from the previous turn must not touch a newer parent.
	reset(h, combat, actor)
	h._p_select(combat, "fixture:028_parent_action")
	var old_menu: PopupMenu = await Batch027Controls.popup(h, combat, "Choose child action")
	combat._reset_turn_action_economy()
	combat.resolving_player_action = false
	h._p_select(combat, "fixture:028_parent_action")
	await pause(h)
	var new_parent: String = str(combat.child_actions.frame.get("invocation", ""))
	var new_menu: PopupMenu = null
	for window in combat.hud.get_children():
		if window is PopupMenu and window != old_menu and window.visible and window.title == "Choose child action": new_menu = window
	if old_menu != null: old_menu.id_pressed.emit(0)
	await pause(h)
	h._assert(not new_parent.is_empty() and combat.child_actions.frame.get("invocation") == new_parent and combat.resolving_player_action, "028 stale real chooser callback cannot clear or unlock the next parent")
	if new_menu != null: new_menu.hide()
	await pause(h)
	h._assert(combat.child_actions.frame.is_empty() and not combat.resolving_player_action, "028 current chooser still cancels and releases its own controls")
	h._teardown_scene(combat)
	GameManager.test_mode = true
	DataLoader.load_all_data()
	h._exit_test()
