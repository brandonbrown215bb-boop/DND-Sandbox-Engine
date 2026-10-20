class_name Batch034Controls
extends RefCounted

static func cast(h: Node, combat: Node, caster: Character, target, suffix: String) -> void:
	h._p_focus(combat, caster)
	combat.hud._show_spell_selection()
	for index in combat.hud.spells_registered.size():
		if combat.hud.spells_registered[index].get("id") == "fixture:b034_" + suffix:
			combat.hud._on_spell_selected(index)
			break
	await Batch027Controls.answer(h, combat, "", "Level 1")
	var pos: Vector2i = target.get("hex_position", Vector2i.ZERO) if target is Dictionary else Batch031Controls._position(combat, target)
	combat._on_hex_clicked(pos)
	for _frame in 300:
		await h.get_tree().process_frame
		if not combat._cast_in_progress and combat.pending_action_type.is_empty(): break
	h._assert(not combat._cast_in_progress, "034 cast finishes through its production continuation")

static func receipt(combat: Node) -> Dictionary:
	var records: Array = combat.last_spell_damage_receipts
	print("B034 RECEIPTS ", JSON.stringify(records))
	return records[0] if not records.is_empty() else {}

static func living(a: Character, hp: int = 20) -> void:
	a.corpse_state.clear()
	a.disintegrated = false
	a.death_save_failures = 0
	a.death_save_successes = 0
	a.is_stable = false
	a.current_hp = hp
	a.temp_hp = 0
	a.is_alive = true
	a.remove_condition("unconscious")

static func run(h: Node) -> void:
	h._enter_test("batch_034_aftermath_flow")
	h._setup_world()
	Batch034Checks.load_fixtures()
	seed(34034)
	var a: Character = PlayerManager.get_player(0).get("character")
	var b: Character = PlayerManager.get_player(1).get("character")
	var spells: Array[String] = []
	for id in DataLoader.spells:
		if str(id).begins_with("fixture:b034_"): spells.append(str(id))
	b.known_spells.assign(spells)
	b.wizard_spellbook.assign(spells)
	b.feature_choices[b.get_spellcasting_feature_id()] = spells.duplicate()
	b.features.append({"id": "fixture:b034_permission", "effects": [{"type": "always_prepared_spells", "spells": spells.duplicate(), "ability": "INT", "maximum_spell_level": 1}]})
	b.spell_slots["1"] = 40
	a.max_hp = 100
	b.max_hp = 100
	b.current_hp = 50
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
	enemy["hex_position"] = Vector2i(1, 0)
	# S-119 actual shared spell: dust death, nonmagical gear destroyed.
	living(a)
	a.inventory.add_item("ring_of_protection")
	var identity := a.character_id
	await cast(h, combat, b, a, "dust")
	var r := receipt(combat)
	var aftermath: Dictionary = r.get("zero_hp_aftermath", {})
	h._assert(a.is_dead() and a.corpse_state.remains == "dust" and a.corpse_state.cause == "dust_aftermath" and a.corpse_state.character_id == identity and str(a.corpse_state.cause_source.source_instance_id).begins_with("spell:fixture:b034_dust") and a.inventory.has_item("ring_of_protection") and a.inventory.owned_instances().size() == 1, "034 actual dust spell kills outright with declared remains, cause and gear policy")
	h._assert(aftermath.get("applied", false) and int(r.get("hp_loss", -1)) == 20, "034 actual receipt records the aftermath separately from ordinary HP loss")
	h._assert(not CorpseRules.target_error(a, "revivify", int(GameManager.campaign_elapsed_seconds)).is_empty(), "034 actual dust remains refuse Revivify")
	var dto := a.to_dict()
	h._assert(CorpseRules.saved_error(dto).is_empty(), "034 actual corpse with cause detail validates")
	# Ordinary HP loss control through the same production cast.
	living(a)
	await cast(h, combat, b, a, "plain")
	h._assert(a.is_downed() and not a.is_dead() and receipt(combat).get("zero_hp_aftermath", {}).is_empty(), "034 actual plain spell leaves the ordinary 0-HP route")
	# S-093 actual turn start: downed actor's Death Save is canceled, no prompt.
	living(a, 0)
	a.is_alive = false
	a.death_save_failures = 1
	a.add_condition("unconscious", 999)
	a.features.append(Batch034Checks.rule(0))
	a.add_condition("blessed", 999)
	for index in combat.tracker.combatants.size():
		if combat.tracker.combatants[index]["entity"] is Character and combat.tracker.combatants[index]["entity"] == a:
			combat.tracker.active_index = index
	await combat._start_combat_turn()
	var saved: Dictionary = combat.last_automatic_death_save
	h._assert(saved.get("canceled", false) and not saved.get("rolled", true) and a.death_save_failures == 1 and a.death_save_successes == 0 and not a.is_dead(), "034 actual turn-start Death Save is canceled before any roll or consequence")
	a.features = a.features.filter(func(f): return str(f.get("source_instance_id", "")) != "b034:vigil")
	a.remove_condition("blessed")
	living(a, 20)
	# Destruction on the live creature host.
	enemy["current_hp"] = 10
	enemy["is_alive"] = true
	await cast(h, combat, b, enemy, "erase")
	h._assert(not bool(enemy.get("is_alive", true)) and enemy.get("zero_hp_aftermath", {}).get("remains", "") == "destroyed", "034 actual creature destruction records destroyed remains and cause")
	h._teardown_scene(combat)
	living(a, 20)
	a.features = a.features.filter(func(f): return str(f.get("source_instance_id", "")) != "b034:vigil")
	a.remove_condition("blessed")
	h._exit_test()
