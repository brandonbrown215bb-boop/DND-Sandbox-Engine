class_name Batch037Controls
extends RefCounted

static func run(h: Node) -> void:
	h._enter_test("batch_037_mode_upgrade_flow")
	h._setup_world()
	Batch037Checks.load_fixtures()
	var a: Character = PlayerManager.get_player(0).get("character")
	var prior_features := a.features.duplicate()
	var prior_uses := a.feature_uses.duplicate(true)
	var stance := Batch037Checks.STANCE
	a.features.append(Batch037Checks.catalog("1", 0))
	a.features.append(Batch037Checks.catalog("1", 1))
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
	var base_ac := a.get_ac()
	var r := FeatureModeRules.activate(a, stance, "guard")
	h._assert(r.success and int(a.feature_uses[stance]) == 1, "037 actual party member activates a declared mode and pays one parent use")
	Batch031Controls._seed_hit()
	await combat._execute_monster_attack(enemy, a.character_name, 0)
	h._assert(int(combat.last_monster_weapon_attack_result.get("target_ac", -1)) == base_ac + 2, "037 actual monster attack reads the active mode's AC grant (%d vs %d)" % [int(combat.last_monster_weapon_attack_result.get("target_ac", -1)), base_ac])
	var remaining := int(a.feature_modes[stance].remaining_seconds)
	r = FeatureModeRules.choose(a, stance, "guard")
	h._assert(not r.success and FeatureModeRules.choose(a, stance, "stride").success and a.get_ac() == base_ac and int(a.feature_uses[stance]) == 1 and int(a.feature_modes[stance].remaining_seconds) == remaining, "037 actual reselect swaps grants without restarting the parent")
	Batch031Controls._seed_hit()
	await combat._execute_monster_attack(enemy, a.character_name, 0)
	h._assert(int(combat.last_monster_weapon_attack_result.get("target_ac", -1)) == base_ac, "037 actual next attack sees the replaced mode, not the old grant")
	h._teardown_scene(combat)
	a.current_hp = a.max_hp
	FeatureModeRules.choose(a, Batch037Checks.ATTUNE, "warded")
	RestRules.complete_long_rest([a], {"allow_in_test": true, "skip_campaign_time": true})
	h._assert(not a.feature_modes[stance].active and int(a.feature_uses[stance]) == 2 and a.get_ac() == base_ac + 1, "037 actual Long Rest ends the activation, restores uses and keeps the rest mode until replaced")
	h._assert(FeatureModeRules.choose(a, Batch037Checks.ATTUNE, "swift").success and a.get_ac() == base_ac, "037 actual post-rest choice replaces the rest mode's grant")
	a.features = prior_features
	a.feature_uses = prior_uses
	a.feature_modes.clear()
	h._exit_test()
