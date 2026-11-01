class_name PerceptionFlow
extends RefCounted

static func run(h: Node) -> void:
	h._enter_test("perception_flow")
	h._setup_world()
	PlayerManager.reset()
	PartyManager.reset()
	PlayerManager.add_player("Ordinary observer")
	PlayerManager.add_player("Special observer")
	PerceptionChecks.fixtures()
	var ordinary := PerceptionChecks.actor("perception_ordinary")
	var special := PerceptionChecks.actor("perception_special")
	PerceptionChecks.sense(special, "short_blind")
	while ordinary.level < 5: ordinary.level_up()
	while special.level < 5: special.level_up()
	for c in [ordinary, special]:
		c.known_spells.assign(["fixture:sight_bolt", "fixture:renamed_sight_bolt", "fixture:known_bolt", "darkness", "true_strike", "fixture:renamed_sight_burst"])
		h._own_class_spells(c)
		h._ready_spell_components(c)
		c.inventory.add_item("shortbow")
		c.inventory.equip(Inventory.Slot.WEAPON, "shortbow")
		c.ability_scores.dexterity = 50
	for index in 2:
		var c: Character = [ordinary, special][index]
		PlayerManager.set_player_character(index, c)
		h._assert(PartyManager.register_player_character(index, c), "S190 fixture registers actual party observer " + c.character_id)
	GameManager.transition_context = {"terrain":"plains", "monster_ids":["goblin"]}
	var combat: CombatState = await h._spawn_scene("res://scenes/combat.tscn", 0.5)
	if combat.monster_entities.is_empty():
		h._assert(false, "S190 production encounter has target")
		h._teardown_scene(combat); h._exit_test(); return
	var enemy: Dictionary = combat.monster_entities[0]
	enemy.hex_position = Vector2i(2, 0); enemy.current_hp = 2000; enemy.max_hp = 2000; enemy.armor_class = -100
	enemy.erase("senses"); enemy.erase("darkvision_range_feet")
	combat.player_entities[0].hex_position = Vector2i.ZERO
	combat.player_entities[1].hex_position = Vector2i.ZERO
	h._p_focus(combat, ordinary)
	combat._update_grid_entities()
	CombatAction.apply_condition(enemy, "invisible", 100, "perception:cloak")
	combat.hud.btn_attack.pressed.emit()
	FighterChecks._seed_die(20, 10)
	await combat._on_hex_clicked(enemy.hex_position)
	var roll := last_attack_roll()
	h._assert(not combat._can_spend_action_cost("action") and roll.get("disadvantage", false), "S191 real Attack control targets known Invisible creature with Disadvantage")
	h._p_focus(combat, ordinary)
	CombatAction.apply_condition(enemy, "hidden", 100, "perception:hide")
	combat._update_grid_entities()
	var hp := int(enemy.current_hp)
	combat.hud.btn_attack.pressed.emit()
	await combat._on_hex_clicked(enemy.hex_position)
	h._assert(combat._can_spend_action_cost("action") and enemy.current_hp == hp and not token_present(combat, enemy), "S191 real unknown Hidden click refuses without payment and hides token for ordinary observer")
	await combat._on_hud_action("cancel", {})
	h._p_focus(combat, special)
	combat._update_grid_entities()
	h._assert(token_present(combat, enemy), "S191 active observer with Blindsight discovers same Hidden target")
	combat.hud.btn_attack.pressed.emit()
	FighterChecks._seed_die(20, 10)
	await combat._on_hex_clicked(enemy.hex_position)
	roll = last_attack_roll()
	h._assert(not combat._can_spend_action_cost("action") and not roll.get("disadvantage", true), "S191 same actual Attack control uses special observer's sight")
	h._p_focus(combat, ordinary)
	combat._update_grid_entities()
	h._assert(not token_present(combat, enemy), "S191 special observer discovery does not reveal token when ordinary observer becomes active")
	combat.active_character = null; combat.current_player_idx = -1
	combat._update_grid_entities()
	h._assert(not token_present(combat, enemy), "S191 board retains ordinary observer's concealment during monster turn")
	h._p_focus(combat, special)
	special.features = special.features.filter(func(f): return str(f.get("id", "")) != "fixture:short_blind")
	combat._update_grid_entities()
	h._assert(token_present(combat, enemy) and not combat._spell_target_visible_to_active_character(enemy.hex_position, DataLoader.get_spell("fixture:sight_bolt")), "S191 source removal retains learned location but removes sight")
	for id in ["fixture:sight_bolt", "fixture:renamed_sight_bolt"]:
		h._p_focus(combat, special)
		await h._cast_menu_spell(combat, id)
		hp = int(enemy.current_hp)
		await combat._on_hex_clicked(enemy.hex_position)
		h._assert(combat._can_spend_action_cost("action") and enemy.current_hp == hp, "S190 permissioned renamed sight spell refuses unseen target without payment: " + id)
		await combat._on_hud_action("cancel", {})
	h._p_focus(combat, special)
	await h._cast_menu_spell(combat, "fixture:known_bolt")
	var spell_rolls := await roll_types_for_click(combat, enemy.hex_position)
	h._assert(not combat._can_spend_action_cost("action") and "disadvantage" in spell_rolls, "S191 permissioned non-sight shared spell targets observer's discovered Hidden location")
	h._p_focus(combat, ordinary)
	await h._cast_menu_spell(combat, "fixture:known_bolt")
	hp = int(enemy.current_hp)
	await combat._on_hex_clicked(enemy.hex_position)
	h._assert(combat._can_spend_action_cost("action") and enemy.current_hp == hp, "S191 another observer cannot use discovered Hidden location for the same shared spell")
	await combat._on_hud_action("cancel", {})
	h._p_focus(combat, ordinary)
	h._ready_spell_components(ordinary)
	await h._cast_menu_spell(combat, "fixture:renamed_sight_burst", 1)
	hp = int(enemy.current_hp)
	enemy["saving_throw_bonuses"] = {"DEX":-100}
	await combat._on_hex_clicked(enemy.hex_position)
	h._assert(not combat._can_spend_action_cost("action") and enemy.current_hp == hp - 1 and CombatAction.has_condition(enemy, "hidden"), "S191 sight-required area point remains legal over unknown Hidden/Invisible occupant and damages it normally")
	CombatAction.remove_condition_source(enemy, "perception:hide", ["hidden"])
	CombatAction.remove_condition_source(enemy, "perception:cloak", ["invisible"])
	await darkness(h, combat, ordinary, special, enemy)
	await opportunity(h, combat, ordinary, enemy)
	h._p_focus(combat, ordinary)
	ordinary.inventory.unequip(Inventory.Slot.WEAPON)
	ordinary.inventory.add_item("quarterstaff")
	ordinary.inventory.equip(Inventory.Slot.WEAPON, "quarterstaff")
	enemy.hex_position = Vector2i(1, 0)
	ordinary.add_condition("hidden", 10)
	combat._update_grid_entities()
	await h._cast_menu_spell(combat, "true_strike")
	await combat._on_hex_clicked(enemy.hex_position)
	h._assert(not combat._can_spend_action_cost("action") and not ordinary.has_condition("hidden"), "S191 native True Strike reveals Hidden attacker through shared weapon settlement")
	h._teardown_scene(combat)
	await h.get_tree().process_frame
	h._setup_world()
	h._exit_test()

static func last_attack_roll() -> Dictionary:
	var records := ActivityHistory.get_records()
	if records.is_empty(): return {}
	var attacks: Array = records.back().get("payload", {}).get("sections", {}).get("attacks", [])
	return attacks[0].get("roll", {}) if not attacks.is_empty() else {}

static func token_present(combat: CombatState, enemy: Dictionary) -> bool:
	return combat.hex_grid.entities.any(func(e): return e.get("monster", {}) == enemy)

static func darkness(h: Node, combat: CombatState, ordinary: Character, special: Character, enemy: Dictionary) -> void:
	h._p_focus(combat, ordinary)
	combat._update_grid_entities()
	h._ready_spell_components(ordinary)
	await h._cast_menu_spell(combat, "darkness", 2)
	await combat._on_hex_clicked(enemy.hex_position)
	var source := str(ordinary.concentrating_on.get("darkness_source_id", ""))
	h._assert(not source.is_empty() and combat.hex_grid.obscurement_sources.has(source), "S190 real native Darkness cast publishes exact area source")
	PerceptionChecks.sense(special, "short_blind")
	special.add_condition("blinded", 10)
	h._assert(not CombatPerception.can_see_target(ordinary, enemy, Vector2i.ZERO, enemy.hex_position, combat.hex_grid) and CombatPerception.can_see_target(special, enemy, Vector2i.ZERO, enemy.hex_position, combat.hex_grid), "S190 same native Darkness differs by observer even while special observer is Blinded")
	for id in ["fixture:sight_bolt", "fixture:renamed_sight_bolt"]:
		h._p_focus(combat, special)
		await h._cast_menu_spell(combat, id)
		var spell_rolls := await roll_types_for_click(combat, enemy.hex_position)
		h._assert(not combat._can_spend_action_cost("action") and "advantage" in spell_rolls and "disadvantage" not in spell_rolls, "S190 actual renamed shared cast uses one-sided Blindsight in Darkness: " + id)
	combat._end_concentration(ordinary)
	h._assert(not combat.hex_grid.obscurement_sources.has(source) and not CombatAction.has_condition(enemy, "darkness_obscured") and CombatPerception.can_see_target(ordinary, enemy, Vector2i.ZERO, enemy.hex_position, combat.hex_grid), "S190 production source ending clears its area and endpoint obstruction")
	special.remove_condition("blinded")

static func opportunity(h: Node, combat: CombatState, ordinary: Character, enemy: Dictionary) -> void:
	h._p_focus(combat, ordinary)
	ordinary.add_condition("invisible", 100)
	enemy.hex_position = Vector2i(1, 0)
	enemy["reaction_available"] = true
	enemy.conditions.clear()
	combat.player_entities[0].hex_position = Vector2i.ZERO
	var path: Array[Vector2i] = [Vector2i.ZERO, Vector2i(-1, 0)]
	await combat._check_opportunity_attacks_for_path(ordinary, combat.player_entities[0], path, false)
	h._assert(enemy.reaction_available, "S191 known Invisible movement cannot trigger ordinary observer's sight-required Opportunity Attack")
	combat.player_entities[0].hex_position = Vector2i.ZERO
	enemy["senses"] = {"blindsight":10}
	await combat._check_opportunity_attacks_for_path(ordinary, combat.player_entities[0], path, false)
	h._assert(not enemy.reaction_available, "S191 same movement triggers in-range Blindsight observer's Opportunity Attack")
	ordinary.remove_condition("invisible")
	combat.player_entities[0].hex_position = Vector2i.ZERO
	enemy.erase("senses")

static func roll_types_for_click(combat: CombatState, position: Vector2i) -> Array[String]:
	var types: Array[String] = []
	var capture := func(roll: Dictionary): types.append(str(roll.get("type", "")))
	Dice.dice_rolled.connect(capture)
	FighterChecks._seed_die(20, 10)
	await combat._on_hex_clicked(position)
	Dice.dice_rolled.disconnect(capture)
	return types
