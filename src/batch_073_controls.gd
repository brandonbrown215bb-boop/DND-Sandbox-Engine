class_name Batch073Controls
extends RefCounted
## Batch 073 (S-119): explicit death/destruction without damage through the
## HUD spell picker and target click. Cancel spends nothing; ineligible and
## already-dead targets refuse before any slot or Action is paid; a living
## goblin and a downed party member each die once; a real save/load and
## batch_073_explicit_death_reload keep the single recorded death.

const SLOT := "batch_073_explicit_death"
const SPELLS := [Batch073Checks.ENDING, Batch073Checks.UNMAKING]

static func _in_tracker(combat: Node, id: String) -> bool:
	for entry in combat.tracker.combatants:
		if str(entry.get("id", "")) == id: return true
	return false

static func run(h: Node) -> void:
	h._enter_test("batch_073_explicit_death_flow")
	h._setup_world()
	Batch071Checks.load_fixtures()
	Batch073Checks.load_fixtures()
	var alice: Character = PlayerManager.get_player(0).get("character")
	var bob: Character = PlayerManager.get_player(1).get("character")
	for c in [alice, bob]:
		c.known_spells.assign(SPELLS)
		c.wizard_spellbook.assign(SPELLS)
		c.feature_choices[c.get_spellcasting_feature_id()] = SPELLS.duplicate()
		c.features.append({"id": "fixture:b073_prepared_permission", "effects": [{"type": "always_prepared_spells", "spells": SPELLS.duplicate(), "ability": "INT", "maximum_spell_level": 1}]})
		c.spell_slots["1"] = 4
	GameManager.transition_context = {"terrain": "plains", "monster_ids": ["goblin"]}
	GameManager.current_state = GameManager.GameState.COMBAT
	GameManager.test_mode = false
	var combat: Node = await h._spawn_scene("res://scenes/combat.tscn", 0.8)
	for _frame in 600:
		if combat.active_combatant.get("is_player", false): break
		await h.get_tree().process_frame
	for entry in combat.player_entities:
		if entry.get("character") == alice: entry["hex_position"] = Vector2i.ZERO
		if entry.get("character") == bob: entry["hex_position"] = Vector2i(0, 1)
	var gob: Dictionary = combat.monster_entities[0]
	gob["hex_position"] = Vector2i(2, 0)
	gob["max_hp"] = 20
	gob["current_hp"] = 20
	var brute := Batch071Checks.monster("b073_brute", 40)
	brute["hex_position"] = Vector2i(3, 0)
	var shade := Batch071Checks.monster("b073_shade", 5)
	shade["creature_type"] = "undead"
	shade["hex_position"] = Vector2i(2, 2)
	combat.monster_entities.append(brute)
	combat.monster_entities.append(shade)
	combat._update_grid_entities()
	Batch071Controls._turn(combat, alice)
	var shown := await Batch071Controls._cancel(h, combat, alice, Batch073Checks.ENDING)
	h._assert(shown and int(alice.spell_slots["1"]) == 4 and combat.turn_budget.action_available and bool(gob.is_alive), "073 live Cancel at the slot prompt spends no slot or Action and kills nothing")
	await Batch031Controls._cast_to(h, combat, alice, Batch073Checks.ENDING, Vector2i(3, 0))
	h._assert(bool(brute.is_alive) and int(brute.current_hp) == 40 and int(alice.spell_slots["1"]) == 4 and combat.turn_budget.action_available, "073 live a 40-HP creature (threshold 30) is refused before any slot or Action")
	await Batch031Controls._cast_to(h, combat, alice, Batch073Checks.ENDING, Vector2i(2, 2))
	h._assert(bool(shade.is_alive) and int(alice.spell_slots["1"]) == 4 and combat.turn_budget.action_available, "073 live an undead target (excluded type) is refused before any slot or Action")
	await Batch031Controls._cast_to(h, combat, alice, Batch073Checks.UNMAKING, Vector2i(2, 2))
	h._assert(bool(shade.is_alive) and int(alice.spell_slots["1"]) == 4 and combat.turn_budget.action_available, "073 live a creature type not listed by the policy is refused before paying")
	var ok: bool = await Batch031Controls._cast_to(h, combat, alice, Batch073Checks.ENDING, Vector2i(2, 0))
	var after: Dictionary = gob.get("zero_hp_aftermath", {})
	h._assert(ok and not bool(gob.is_alive) and int(gob.current_hp) == 0 and int(gob.max_hp) == 20 and after.get("cause", "") == "word_of_ending" and after.get("remains", "") == "intact" and int(alice.spell_slots["1"]) == 3 and not combat.turn_budget.action_available, "073 live HUD cast kills the 20-HP goblin outright with intact remains; one slot and the Action paid")
	h._assert(not _in_tracker(combat, str(gob.get("id", ""))), "073 live the goblin's defeat is processed (removed from initiative)")
	var snapshot := JSON.stringify(after)
	Batch071Controls._turn(combat, bob)
	await Batch031Controls._cast_to(h, combat, bob, Batch073Checks.ENDING, Vector2i(2, 0))
	h._assert(JSON.stringify(gob.get("zero_hp_aftermath", {})) == snapshot and int(bob.spell_slots["1"]) == 4 and combat.turn_budget.action_available, "073 live recasting at the dead goblin is refused before paying; no duplicate death or remains")
	# A downed party member (0 HP, not dead).
	alice.current_hp = 0
	alice.is_alive = false
	alice.death_save_failures = 1
	var serial := alice.body_death_serial
	await Batch031Controls._cast_to(h, combat, bob, Batch073Checks.UNMAKING, Vector2i.ZERO)
	h._assert(alice.is_downed() and alice.corpse_state.is_empty() and int(bob.spell_slots["1"]) == 4 and combat.turn_budget.action_available, "073 live at_zero refuse: the downed ally stays downed and nothing is paid")
	ok = await Batch031Controls._cast_to(h, combat, bob, Batch073Checks.ENDING, Vector2i.ZERO)
	h._assert(ok and alice.is_dead() and alice.body_death_serial == serial + 1 and alice.corpse_state.get("cause", "") == "word_of_ending" and alice.corpse_state.get("remains", "") == "intact" and int(bob.spell_slots["1"]) == 3, "073 live the downed ally dies once from the explicit effect (serial %d -> %d)" % [serial, alice.body_death_serial])
	Batch071Controls._turn(combat, bob)
	await Batch031Controls._cast_to(h, combat, bob, Batch073Checks.ENDING, Vector2i.ZERO)
	h._assert(alice.body_death_serial == serial + 1 and int(bob.spell_slots["1"]) == 3 and combat.turn_budget.action_available, "073 live a cast at the ally's corpse is refused before paying; no second death")
	GameManager.test_mode = true
	h._teardown_scene(combat)
	var dto := alice.to_dict()
	var json_back := Character.new()
	json_back.from_dict(JSON.parse_string(JSON.stringify(dto)))
	h._assert(json_back.is_dead() and json_back.body_death_serial == alice.body_death_serial and json_back.corpse_state.get("cause_source", {}) == alice.corpse_state.get("cause_source", {}), "073 live JSON-text DTO keeps the single explicit death")
	GameManager.current_state = GameManager.GameState.OVERWORLD
	GameManager.game_in_progress = true
	var block := SaveManager.get_save_block_reason()
	var saved: bool = block.is_empty() and SaveManager.save_game(SLOT)
	h._assert(saved, "073 live real save (block='%s')" % block)
	if saved:
		var loaded := SaveManager.load_game(SLOT)
		var nc: Character = PartyManager.characters.get(alice.character_id, null)
		h._assert(loaded and nc != null and nc.is_dead() and nc.body_death_serial == serial + 1 and nc.corpse_state.get("cause", "") == "word_of_ending", "073 live real load keeps one explicit death")
		var f := FileAccess.open("user://batch_073_ids.txt", FileAccess.WRITE)
		f.store_string("%s|%d" % [alice.character_id, serial + 1])
		f.close()
	h._exit_test()

static func reload(h: Node) -> void:
	h._enter_test("batch_073_explicit_death_reload")
	Batch073Checks.load_fixtures()
	var parts := FileAccess.get_file_as_string("user://batch_073_ids.txt").strip_edges().split("|")
	var loaded := SaveManager.load_game(SLOT)
	var nc: Character = PartyManager.characters.get(parts[0], null) if parts.size() == 2 else null
	h._assert(loaded and nc != null and nc.is_dead() and nc.body_death_serial == int(parts[1]) and nc.corpse_state.get("cause_source", {}).get("policy_id", "") == "b073:ending", "073 fresh process the explicit death and its cause load once")
	h._assert(nc != null and not ZeroHpAftermathRules.explicit_target_error(nc, Batch073Checks.policy(Batch073Checks.ENDING)).is_empty(), "073 fresh process the loaded corpse is still refused")
	SaveManager.delete_save(SLOT)
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://batch_073_ids.txt"))
	h._exit_test()
