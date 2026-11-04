## SC-07 support 02: every combat Strength ability check reads the generic
## str_d20_disadvantage consequence (MARKER_RULES / CONDITION_RULES).
## All ability checks route through EventResolver.resolve_skill_check
## (Characters) or resolve_monster_ability_check (monsters); this flow proves
## the live restraint-escape and tether-escape owners and guards the routing.
class_name CrownSc07Support02Flow
extends RefCounted

const P := "SC-07 s2: "
const SLOT := "crown_sc_07_support_02"

static func _enfeeble(caster: Character, target, spell: Dictionary) -> bool:
	for _attempt in 80:
		CombatAction.resolve_spell(caster, target, spell, false, {}, [], 2, 2)
		if CombatAction.has_condition(target, "enfeebled"): return true
		for key in SpellEffects.records(target).keys(): SpellEffects.remove(target, str(key))
	return false

static func _routing_guard(h) -> void:
	var offenders: Array[String] = []
	var stack: Array[String] = ["res://src"]
	while not stack.is_empty():
		var dir_path: String = stack.pop_back()
		var dir := DirAccess.open(dir_path)
		if dir == null: continue
		for sub in dir.get_directories(): stack.append(dir_path + "/" + sub)
		for file in dir.get_files():
			if not file.ends_with(".gd") or file.ends_with("_flow.gd") or file.ends_with("_checks.gd") or file in ["test_runner.gd", "viewport_harness.gd"]: continue
			var text := FileAccess.get_file_as_string(dir_path + "/" + file)
			for line in text.split("\n"):
				if line.contains("resolve_d20_test(") and line.contains("\"ability_check\"") and file != "event_resolver.gd":
					offenders.append(file)
	h._assert(offenders.is_empty(), P + "only EventResolver rolls ability-check d20 tests, so every Strength check reads the shared consequence (offenders: %s)" % str(offenders))

static func _resolver_checks(h) -> void:
	var caster := ConversionBatch002Checks.actor("crown-sc07s2-renamed", "wizard", 5)
	var wilt := CrownSc01Support01Flow._renamed(h, "ray_of_enfeeblement", "crown_sc_07_support_02:neutral_wilt")
	var hero := ConversionBatch002Checks.actor("crown-sc07s2-hero", "fighter", 1)
	hero.ability_scores.from_dict({"STR": 16, "DEX": 10, "CON": 1, "INT": 10, "WIS": 10, "CHA": 10})
	var monster := CrownSc01Support01Flow._monster("crown-sc07s2-m", Vector2i(3, 0), 10, {"strength": 16, "constitution": 10})
	monster["saving_throw_bonuses"] = {"CON": -1000}
	h._assert(EventResolver.resolve_skill_check(hero, {"ability": "STR", "skill": "Athletics", "dc": 10}).roll_mode == "normal" and EventResolver.resolve_monster_ability_check(monster, "STR", "Athletics", 10).roll_mode == "normal", P + "control: unaffected Strength checks roll normally")
	h._assert(_enfeeble(caster, hero, wilt) and _enfeeble(caster, monster, wilt), P + "the renamed neutral ray enfeebles a Character and a monster through CombatAction.resolve_spell")
	var c_str := EventResolver.resolve_skill_check(hero, {"ability": "STR", "skill": "Athletics", "dc": 10})
	var c_raw := EventResolver.resolve_skill_check(hero, {"ability": "STR", "skill": "", "dc": 10})
	var c_dex := EventResolver.resolve_skill_check(hero, {"ability": "DEX", "skill": "Acrobatics", "dc": 10})
	h._assert(c_str.roll_mode == "disadvantage" and c_raw.roll_mode == "disadvantage" and c_dex.roll_mode == "normal", P + "an enfeebled Character rolls Strength (Athletics) and raw Strength checks at Disadvantage, Dexterity normally")
	h._assert(str(c_str.roll_mode_contributors[0].source_id) == "enfeebled", P + "the check receipt names the enfeebled marker as the Disadvantage source")
	var m_str := EventResolver.resolve_monster_ability_check(monster, "STR", "Athletics", 10)
	var m_dex := EventResolver.resolve_monster_ability_check(monster, "DEX", "Acrobatics", 10)
	h._assert(m_str.roll_mode == "disadvantage" and m_dex.roll_mode == "normal", P + "an enfeebled monster rolls Strength checks at Disadvantage, Dexterity normally")
	for key in SpellEffects.records(hero).keys(): SpellEffects.remove(hero, str(key))
	hero.add_condition("ray_of_enfeeblement", 10)
	var legacy_monster := CrownSc01Support01Flow._monster("crown-sc07s2-legacy", Vector2i(3, 0), 10, {"strength": 16})
	CombatAction.apply_condition(legacy_monster, "ray_of_enfeeblement", 10)
	h._assert(EventResolver.resolve_skill_check(hero, {"ability": "STR", "skill": "Athletics", "dc": 10}).roll_mode == "disadvantage" and EventResolver.resolve_monster_ability_check(legacy_monster, "STR", "Athletics", 10).roll_mode == "disadvantage", P + "legacy ray_of_enfeeblement markers from older saves impose the same Strength check Disadvantage")
	hero.remove_condition("ray_of_enfeeblement")
	CrownSc01Support01Flow._forget(str(wilt.id))

static func _live_escapes(h) -> void:
	var warlock := ConversionBatch002Checks.actor("crown-sc07s2-lock", "warlock", 1)
	var learned := ConversionBatch001Flow._prepare(warlock, [])
	for _level in 2:
		warlock.level_up()
	learned = learned and ConversionBatch001Flow._prepare(warlock, ["ray_of_enfeeblement"])
	var ally := ConversionBatch002Checks.actor("crown-sc07s2-ally", "fighter", 1)
	ally.ability_scores.from_dict({"STR": 16, "DEX": 10, "CON": 1, "INT": 10, "WIS": 10, "CHA": 10})
	h._assert(learned, P + "the Warlock selects Ray of Enfeeblement through class selection")
	PartyManager.reset()
	for i in 2:
		PlayerManager.set_player_character(i, [warlock, ally][i])
		PartyManager.register_player_character(i, [warlock, ally][i])
	var combat = await h._spawn_scene("res://scenes/combat.tscn", 1.5)
	h._ready_spell_components(warlock)
	combat.player_entities[0].hex_position = Vector2i.ZERO
	combat.player_entities[1].hex_position = Vector2i(0, 1)
	var brute := CrownSc01Support01Flow._monster("crown-sc07s2-brute", Vector2i(2, 0), 10, {"strength": 16, "constitution": 10})
	brute["saving_throw_bonuses"] = {"CON": -1000}
	combat.monster_entities.clear()
	combat.monster_entities.assign([brute])
	combat._update_grid_entities()
	var events: Array = []
	var capture := func(r: Dictionary): events.append(r.duplicate(true))
	Dice.dice_rolled.connect(capture)
	# Control: a restrained, unaffected monster escapes at a normal roll.
	CombatAction.apply_condition(brute, "restrained", 100, "entangle:sc07s2_probe")
	combat.active_spell_zones["entangle:sc07s2_probe"] = {"spell_id": "entangle", "save_dc": 100, "restrained_targets": [brute]}
	events.clear()
	h._assert(combat._try_monster_escape_restrained_zone(brute) and not events.any(func(r): return r.get("type") == "disadvantage"), P + "control: the live monster zone escape rolls normally before the ray")
	GameManager.test_mode = false
	warlock.spell_slots = {"1": 0, "2": 2}
	ConversionBatch002Flow._select(h, combat, warlock, "ray_of_enfeeblement", 2)
	await combat._on_hex_clicked(Vector2i(2, 0))
	await ConversionBatch002Flow._wait_resolution(h, combat)
	GameManager.test_mode = true
	h._assert(CombatAction.has_condition(brute, "enfeebled"), P + "picker + hex click enfeebles the restrained monster")
	events.clear()
	h._assert(combat._try_monster_escape_restrained_zone(brute) and events.any(func(r): return r.get("type") == "disadvantage"), P + "the live monster restraint escape (Strength (Athletics)) rolls at Disadvantage")
	combat.active_spell_zones.erase("entangle:sc07s2_probe")
	CombatAction.remove_condition_source(brute, "entangle:sc07s2_probe", ["restrained"])
	# The enfeebled party member escapes a restraint on its own turn.
	h._assert(_enfeeble(warlock, ally, DataLoader.get_spell("ray_of_enfeeblement")), P + "the ally is enfeebled through the production resolver")
	CombatAction.apply_condition(ally, "restrained", 100, "entangle:sc07s2_ally")
	combat.active_spell_zones["entangle:sc07s2_ally"] = {"spell_id": "entangle", "save_dc": 100, "restrained_targets": [ally]}
	combat.current_player_idx = 1
	combat.active_character = ally
	combat.active_combatant = {"is_player": true, "entity": ally}
	combat.turn_budget.reset(ally, combat.player_entities)
	events.clear()
	var resolved: bool = await combat._try_escape_restrained_zone(ally)
	h._assert(resolved and events.any(func(r): return r.get("type") == "disadvantage") and not combat.turn_budget.action_available and CombatAction.has_condition(ally, "restrained"), P + "the live Character restraint escape spends the action and rolls Strength (Athletics) at Disadvantage")
	combat.active_spell_zones.erase("entangle:sc07s2_ally")
	CombatAction.remove_condition_source(ally, "entangle:sc07s2_ally", ["restrained"])
	Dice.dice_rolled.disconnect(capture)
	h._teardown_scene(combat)

static func _checkpoint(h) -> void:
	var caster := ConversionBatch002Checks.actor("crown-sc07s2-saver", "wizard", 5)
	var ally := ConversionBatch002Checks.actor("crown-sc07s2-target", "fighter", 1)
	ally.ability_scores.from_dict({"STR": 16, "DEX": 10, "CON": 1, "INT": 10, "WIS": 10, "CHA": 10})
	PartyManager.reset()
	for i in 2:
		PlayerManager.set_player_character(i, [caster, ally][i])
		PartyManager.register_player_character(i, [caster, ally][i])
	h._assert(_enfeeble(caster, ally, DataLoader.get_spell("ray_of_enfeeblement")), P + "the party carries an enfeebled record")
	var source := ""
	for key in SpellEffects.records(ally): source = str(key)
	caster.concentrating_on = {"spell_id": "ray_of_enfeeblement", "effect_source": source, "targets": [ally]}
	GameManager.current_state = GameManager.GameState.OVERWORLD
	GameManager.test_mode = true
	GameManager.game_in_progress = true
	h._assert(SaveManager.get_save_block_reason().is_empty() and SaveManager.save_game(SLOT) and SaveManager._validate_save_data(SaveManager._read_save(SLOT)).is_empty(), P + "the record saves and passes preflight")
	print("CROWN_SC_07_SUPPORT_02_CHECKPOINT_READY")

static func _recover(h) -> void:
	h._assert(SaveManager.load_game(SLOT), P + "a fresh process loads the checkpoint")
	var ally: Character = PartyManager.characters.get("crown-sc07s2-target")
	if ally == null:
		h._assert(false, P + "the target recovers")
		return
	var check := EventResolver.resolve_skill_check(ally, {"ability": "STR", "skill": "Athletics", "dc": 10})
	var dex := EventResolver.resolve_skill_check(ally, {"ability": "DEX", "skill": "Acrobatics", "dc": 10})
	h._assert(ally.has_condition("enfeebled") and check.roll_mode == "disadvantage" and dex.roll_mode == "normal", P + "fresh-process recovery keeps Strength check Disadvantage only")
	print("CROWN_SC_07_SUPPORT_02_FRESH_PROCESS_PASSED")

static func run(h) -> void:
	h._enter_test("crown_sc_07_support_02_flow")
	if OS.get_environment("CROWN_SC_07_SUPPORT_02_RECOVER") == "1":
		_recover(h)
		h._exit_test()
		return
	h._setup_world()
	_routing_guard(h)
	_resolver_checks(h)
	await _live_escapes(h)
	_checkpoint(h)
	h._exit_test()
