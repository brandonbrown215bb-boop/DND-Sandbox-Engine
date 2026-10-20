class_name Batch038Controls
extends RefCounted

static func run(h: Node) -> void:
	h._enter_test("batch_038_switch_option_flow")
	h._setup_world()
	Batch038Checks.load_fixtures()
	var a: Character = PlayerManager.get_player(0).get("character")
	var prior_features := a.features.duplicate()
	var prior_uses := a.feature_uses.duplicate(true)
	var stance := Batch038Checks.STANCE
	a.features.append(Batch038Checks.catalog("1", 0))
	a.features.append(Batch038Checks.catalog("2", 1)) # adds the hit permission
	a.feature_uses[stance] = a.get_feature_max_uses(stance)
	GameManager.transition_context = {"terrain": "plains", "monster_ids": ["goblin"]}
	GameManager.current_state = GameManager.GameState.COMBAT
	GameManager.test_mode = false
	var combat: Node = await h._spawn_scene("res://scenes/combat.tscn", 0.8)
	for _frame in 600:
		if combat.active_combatant.get("is_player", false): break
		await h.get_tree().process_frame
	for entry in combat.player_entities:
		entry["hex_position"] = Vector2i.ZERO if entry.character == a else Vector2i(0, 1)
	var enemy: Dictionary = combat.monster_entities[0]
	enemy["hex_position"] = Vector2i(1, 0)
	combat._update_grid_entities()
	a.inventory.equip(Inventory.Slot.WEAPON, "longsword", true)
	var base_ac := a.get_ac()
	h._assert(FeatureModeRules.activate(a, stance, "guard").success and a.get_ac() == base_ac + 2, "038 actual party member activates guard")
	var uses := int(a.feature_uses[stance])
	var deadline := int(a.feature_modes[stance].remaining_seconds)
	# Actual player weapon hit opens the upgraded hit window after settlement.
	enemy["armor_class"] = -100
	enemy["current_hp"] = 500
	enemy["max_hp"] = 500
	Batch031Controls._seed_hit()
	await Batch035Controls.player_attack(h, combat, a, enemy)
	var dealt := 500 - int(enemy.current_hp)
	h._assert(dealt > 0 and a.feature_modes[stance].get("window", {}).get("event", "") == "hit", "038 actual weapon hit opens the declared switch window (dealt=%d)" % dealt)
	var r := FeatureModeRules.switch(a, stance, "stride", "hit")
	h._assert(r.success and int(enemy.current_hp) == 500 - dealt and int(a.feature_uses[stance]) == uses and int(a.feature_modes[stance].remaining_seconds) == deadline, "038 actual switch leaves the settled hit, parent cost and deadline unchanged")
	Batch031Controls._seed_hit()
	await combat._execute_monster_attack(enemy, a.character_name, 0)
	h._assert(int(combat.last_monster_weapon_attack_result.get("target_ac", -1)) == base_ac, "038 actual monster attack sees the switched mode (no guard AC)")
	h._assert(not FeatureModeRules.switch(a, stance, "guard", "hit").success, "038 actual window is spent after one switch")
	CombatAction.advance_combat_turn(a, 2)
	h._assert(FeatureModeRules.switch(a, stance, "guard", "turn_start").success and a.get_ac() == base_ac + 2, "038 actual own turn start switches back")
	Batch031Controls._seed_hit()
	await combat._execute_monster_attack(enemy, a.character_name, 0)
	h._assert(int(combat.last_monster_weapon_attack_result.get("target_ac", -1)) == base_ac + 2, "038 actual monster attack reads the restored guard AC")
	h._teardown_scene(combat)
	a.features = prior_features
	a.feature_uses = prior_uses
	a.feature_modes.clear()
	h._exit_test()
