class_name Batch035Controls
extends RefCounted

static func player_attack(h: Node, combat: Node, actor: Character, monster: Dictionary) -> void:
	for i in combat.player_entities.size():
		if combat.player_entities[i].character == actor: combat.current_player_idx = i
	combat.active_character = actor
	combat.turn_budget.has_acted_this_turn = false
	combat.turn_budget.action_available = true
	combat.remaining_attack_swings = 0
	combat.pending_action_type = "attack"
	combat._on_hex_clicked(monster["hex_position"])
	for _frame in 120:
		await h.get_tree().process_frame
		if combat.pending_action_type.is_empty(): break

static func run(h: Node) -> void:
	h._enter_test("batch_035_profile_max_hp_flow")
	h._setup_world()
	Batch035Checks.load_fixtures()
	seed(35035)
	var a: Character = PlayerManager.get_player(0).get("character")
	var prior_features := a.features.duplicate(true)
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
	# S-130 actual incoming monster rider: exact creature owns its reduction.
	a.max_hp = 40
	a.current_hp = 40
	a.max_hp_sources.clear()
	var saved_attacks: Array = enemy.get("attacks", []).duplicate(true)
	enemy["attacks"] = DataLoader.get_monster("fixture:b035_drainer").attacks.duplicate(true)
	var base_ac := a.base_ac
	a.base_ac = 1
	Batch031Controls._seed_hit()
	await combat._execute_monster_attack(enemy, a.character_name, 0)
	var source_id := "%s:b035:hollow" % str(enemy.get("id", ""))
	var dealt := 40 - a.current_hp
	h._assert(combat.last_monster_weapon_attack_result.get("hit", false) and a.max_hp_sources.has(source_id) and a.max_hp == 40 - dealt and dealt > 0, "035 actual monster hit reduces the maximum by damage dealt under its exact source (dealt=%d max=%d)" % [dealt, a.max_hp])
	var dto := a.to_dict()
	h._assert(MaxHpSourceRules.saved_error(dto).is_empty(), "035 actual reduced actor produces a valid DTO")
	var max_after_hit := a.max_hp
	CombatAction.advance_combat_turn(a, 99)
	h._assert(a.max_hp == max_after_hit - 1, "035 actual turn-start periodic reduction applies once")
	enemy["attacks"] = saved_attacks
	a.base_ac = base_ac
	RestRules.complete_long_rest([a], {"allow_in_test": true, "skip_campaign_time": true})
	h._assert(a.max_hp == 40 and a.max_hp_sources.is_empty(), "035 actual completed Long Rest cures the declared reduction")
	# S-126 actual player weapon command: control, then scoped profile.
	a.inventory.equip(Inventory.Slot.WEAPON, "longsword", true)
	enemy["armor_class"] = -100
	# Review: positive control proves the same command lands and deals damage, so the
	# immune control below cannot pass merely because no attack happened.
	enemy["damage_immunities"] = []
	enemy["current_hp"] = 500
	enemy["max_hp"] = 500
	enemy["is_alive"] = true
	Batch031Controls._seed_hit()
	await player_attack(h, combat, a, enemy)
	h._assert(int(enemy.current_hp) < 500, "035 review positive control: the unprofiled longsword command lands and deals damage (hp=%d)" % int(enemy.current_hp))
	enemy["damage_immunities"] = ["slashing"]
	enemy["current_hp"] = 500
	Batch031Controls._seed_hit()
	await player_attack(h, combat, a, enemy)
	h._assert(int(enemy.current_hp) == 500, "035 actual control longsword stays slashing and is fully immune")
	a.features.append(Batch035Checks.feature(1))
	Batch031Controls._seed_hit()
	await player_attack(h, combat, a, enemy)
	h._assert(int(enemy.current_hp) < 500, "035 actual scoped profile turns the same longsword attack into fire damage (hp=%d)" % int(enemy.current_hp))
	enemy["damage_immunities"] = ["fire"]
	enemy["current_hp"] = 500
	Batch031Controls._seed_hit()
	await player_attack(h, combat, a, enemy)
	h._assert(int(enemy.current_hp) == 500, "035 review negative control: profiled attack is fully stopped by fire immunity, so its type is exactly fire (hp=%d)" % int(enemy.current_hp))
	h._assert(DataLoader.get_item("longsword").damage_type == "slashing", "035 actual catalog weapon remains slashing after the profiled attack")
	h._teardown_scene(combat)
	a.features = prior_features
	h._exit_test()
