## SC-07 support 01: Ray of Enfeeblement as shared data.
## New generic pieces: the "enfeebled" marker whose consequences
## (str_d20_disadvantage, damage_roll_penalty_d8) are read through
## CombatAction.conditions_with_consequence for saves, attacks, checks and
## damage; the legacy "ray_of_enfeeblement" marker keeps the same rules for old saves.
class_name CrownSc07Support01Flow
extends RefCounted

const P := "SC-07 s1: "
const SLOT := "crown_sc_07_support_01"

static func _con(id: String, hex: Vector2i, bonus: int) -> Dictionary:
	var m := CrownSc01Support01Flow._monster(id, hex, 10, {"strength": 16, "constitution": 10})
	m["saving_throw_bonuses"] = {"CON": bonus}
	return m

static func _source(target) -> String:
	for key in SpellEffects.records(target): return str(key)
	return ""

static func _contract_checks(h) -> void:
	var ray := DataLoader.get_spell("ray_of_enfeeblement")
	h._assert(SharedSpell.uses(ray) and SharedSpell.content_error(ray).is_empty() and int(ray.range) == 12 and ray.save == "CON" and ray.repeat_save == "CON" and ray.repeat_save_schedule == "target_turn_end" and bool(ray.concentration) and ray.effects.size() == 2, P + "Ray of Enfeeblement is shared data (60 ft, Con save, concentration, end-of-turn Con repeat)")
	h._assert(CombatAction.condition_rule("enfeebled", "str_d20_disadvantage") and CombatAction.condition_rule("enfeebled", "damage_roll_penalty_d8") and CombatAction.condition_rule("ray_of_enfeeblement", "damage_roll_penalty_d8"), P + "the enfeebled marker (and the legacy alias) carry both consequences")
	var bad := ray.duplicate(true)
	bad.effects[0]["condition"] = "withered_forever"
	h._assert(not SharedSpell.content_error(bad).is_empty(), P + "an unknown granted condition is rejected")
	bad = ray.duplicate(true)
	bad.effects[1]["rider_by_outcome"] = {"success": true}
	h._assert(not SharedSpell.content_error(bad).is_empty(), P + "an incomplete outcome map is rejected")

static func _renamed_checks(h) -> void:
	var caster := ConversionBatch002Checks.actor("crown-sc07s1-renamed", "wizard", 5)
	var wilt := CrownSc01Support01Flow._renamed(h, "ray_of_enfeeblement", "crown_sc_07_support_01:neutral_wilt")
	var weak := _con("crown-sc07s1-r1", Vector2i(3, 0), -1000)
	var failed := CombatAction.resolve_spell(caster, weak, wilt, false, {}, [], 2, 3)
	h._assert(not bool(failed.get("saved", true)) and CombatAction.has_condition(weak, "enfeebled") and not CombatAction.has_condition(weak, "next_attack_disadvantage"), P + "renamed ray: a failed Con save grants enfeebled through CombatAction.resolve_spell")
	h._assert(CombatAction.save_has_disadvantage(weak, "STR") and not CombatAction.save_has_disadvantage(weak, "DEX"), P + "enfeebled imposes Disadvantage on Strength saves only")
	h._assert(CombatAction.attacker_has_condition_disadvantage(weak, "STR") and not CombatAction.attacker_has_condition_disadvantage(weak, "DEX"), P + "enfeebled imposes Disadvantage on Strength attack rolls only")

	var hero := ConversionBatch002Checks.actor("crown-sc07s1-hero", "fighter", 3)
	SpellEffects.grant(hero, SpellEffects.begin_cast(caster, wilt), "enfeebled")
	var hero_attack := hero.make_attack_roll("STR")
	var hero_finesse := hero.make_attack_roll("DEX")
	var dummy := {"id": "crown-sc07s1-dummy", "current_hp": 100, "max_hp": 100, "is_alive": true, "conditions": {}, "damage_resistances": [], "damage_immunities": []}
	var dealt := CombatAction.resolve_damage(dummy, 20, "force", {}, false, false, hero)
	h._assert(bool(hero_attack.get("disadvantage", false)) and not bool(hero_finesse.get("disadvantage", false)) and int(dealt.get("resolved", -1)) >= 12 and int(dealt.get("resolved", -1)) <= 19, P + "an enfeebled Character rolls Strength attacks at Disadvantage and subtracts 1d8 from its damage (20 -> %d)" % int(dealt.get("resolved", -1)))
	h._assert(hero.saving_throw_test_to_dc("STR", 10).get("roll_mode", "") == "disadvantage", P + "an enfeebled Character's Strength save is rolled at Disadvantage")
	var source := _source(weak)
	h._assert(not bool(CombatAction.resolve_condition_spell_repeat_save(weak, source).get("saved", true)) and CombatAction.has_condition(weak, "enfeebled"), P + "a failed end-of-turn repeat save keeps the effect")
	weak["saving_throw_bonuses"] = {"CON": 1000}
	h._assert(bool(CombatAction.resolve_condition_spell_repeat_save(weak, source).get("saved", false)) and not CombatAction.has_condition(weak, "enfeebled") and SpellEffects.records(weak).is_empty(), P + "a successful repeat save ends the spell on the target")
	var hardy := _con("crown-sc07s1-r2", Vector2i(3, 0), 1000)
	var saved := CombatAction.resolve_spell(caster, hardy, wilt, false, {}, [], 2, 3)
	h._assert(bool(saved.get("saved", false)) and CombatAction.has_condition(hardy, "next_attack_disadvantage") and not CombatAction.has_condition(hardy, "enfeebled"), P + "a successful save grants only Disadvantage on the next attack roll")
	SpellEffects.tick_boundary([hardy], SpellEffects.caster_id(caster), "end")
	h._assert(CombatAction.has_condition(hardy, "next_attack_disadvantage"), P + "the success rider survives the caster's turn end")
	SpellEffects.tick_boundary([hardy], SpellEffects.caster_id(caster), "start")
	h._assert(not CombatAction.has_condition(hardy, "next_attack_disadvantage"), P + "the success rider expires at the start of the caster's next turn")
	CrownSc01Support01Flow._forget(str(wilt.id))

static func _player_casts(h) -> void:
	var warlock := ConversionBatch002Checks.actor("crown-sc07s1-lock", "warlock", 1)
	var learned := ConversionBatch001Flow._prepare(warlock, [])
	for _level in 2:
		warlock.level_up()
	learned = learned and ConversionBatch001Flow._prepare(warlock, ["ray_of_enfeeblement"])
	h._assert(learned and warlock.level == 3 and "ray_of_enfeeblement" in warlock.get_spell_option_ids(false), P + "a Warlock reaches level 3 and selects Ray of Enfeeblement through ordinary class selection")
	PlayerManager.set_player_character(0, warlock)
	PartyManager.reset()
	PartyManager.register_player_character(0, warlock)
	var combat = await h._spawn_scene("res://scenes/combat.tscn", 1.5)
	h._ready_spell_components(warlock)
	combat.player_entities[0].hex_position = Vector2i.ZERO
	var brute := _con("crown-sc07s1-brute", Vector2i(1, 0), -1000)
	brute["attacks"] = [{"name": "Slam", "attack_bonus": 100, "damage": "20", "damage_type": "bludgeoning", "ability": "STR"}]
	combat.monster_entities.clear()
	combat.monster_entities.assign([brute])
	combat._update_grid_entities()
	GameManager.test_mode = false
	warlock.spell_slots = {"1": 0, "2": 2}
	ConversionBatch002Flow._select(h, combat, warlock, "ray_of_enfeeblement", 2)
	await combat._on_hex_clicked(Vector2i(1, 0))
	await ConversionBatch002Flow._wait_resolution(h, combat)
	h._assert(CombatAction.has_condition(brute, "enfeebled") and str(warlock.concentrating_on.get("spell_id", "")) == "ray_of_enfeeblement" and int(warlock.spell_slots["2"]) == 1, P + "picker + hex click: the failed save enfeebles the target under concentration (%s)" % combat.hud.log_text.text.right(200))
	var hp_before := warlock.current_hp
	warlock.max_hp = 500
	warlock.current_hp = 500
	hp_before = 500
	var lost := 0
	for _attempt in 40:
		await combat._execute_monster_attack(brute, warlock.character_name, 0)
		lost = hp_before - warlock.current_hp
		if lost > 0: break
		await h.get_tree().process_frame
	h._assert(lost >= 12 and lost <= 19, P + "the enfeebled monster's live 20-damage attack is reduced by 1d8 (lost %d)" % lost)
	brute["saving_throw_bonuses"] = {"CON": 1000}
	CombatAction.resolve_condition_spell_repeat_save(brute, _source(brute))
	h._assert(not CombatAction.has_condition(brute, "enfeebled"), P + "the live target's successful end-of-turn save ends the effect")
	SpellEffects.end_concentration(warlock, [brute])
	warlock.concentrating_on = {}
	combat.turn_budget.reset(warlock, combat.player_entities)
	ConversionBatch002Flow._select(h, combat, warlock, "ray_of_enfeeblement", 2)
	await combat._on_hex_clicked(Vector2i(1, 0))
	await ConversionBatch002Flow._wait_resolution(h, combat)
	h._assert(CombatAction.has_condition(brute, "next_attack_disadvantage") and not CombatAction.has_condition(brute, "enfeebled") and int(warlock.spell_slots["2"]) == 0, P + "picker + hex click: a successful save leaves only next-attack Disadvantage")
	GameManager.test_mode = true
	h._teardown_scene(combat)

static func _checkpoint(h) -> void:
	var caster := ConversionBatch002Checks.actor("crown-sc07s1-saver", "wizard", 5)
	var ally := ConversionBatch002Checks.actor("crown-sc07s1-ally", "fighter", 1)
	PartyManager.reset()
	PlayerManager.set_player_character(0, caster)
	PlayerManager.set_player_character(1, ally)
	PartyManager.register_player_character(0, caster)
	PartyManager.register_player_character(1, ally)
	ally.ability_scores.from_dict({"STR": 16, "DEX": 10, "CON": 1, "INT": 10, "WIS": 10, "CHA": 10})
	for _attempt in 80:
		CombatAction.resolve_spell(caster, ally, DataLoader.get_spell("ray_of_enfeeblement"), false, {}, [], 2, 2)
		if ally.has_condition("enfeebled"): break
		for key in SpellEffects.records(ally).keys(): SpellEffects.remove(ally, str(key))
	caster.concentrating_on = {"spell_id": "ray_of_enfeeblement", "effect_source": _source(ally), "targets": [ally]}
	h._assert(ally.has_condition("enfeebled"), P + "the party carries an enfeebled record")
	GameManager.current_state = GameManager.GameState.OVERWORLD
	GameManager.test_mode = true
	GameManager.game_in_progress = true
	h._assert(SaveManager.get_save_block_reason().is_empty() and SaveManager.save_game(SLOT), P + "the record saves at the overworld checkpoint")
	h._assert(SaveManager._validate_save_data(SaveManager._read_save(SLOT)).is_empty(), P + "the DTO passes production save preflight")
	h._assert(SaveManager.load_game(SLOT), P + "the checkpoint reloads through SaveManager")
	print("CROWN_SC_07_SUPPORT_01_CHECKPOINT_READY")

static func _recover(h) -> void:
	h._assert(SaveManager.load_game(SLOT), P + "a fresh process loads the real checkpoint")
	var ally: Character = PartyManager.characters.get("crown-sc07s1-ally")
	if ally == null:
		h._assert(false, P + "the target identity recovers")
		return
	var dummy := {"id": "crown-sc07s1-dummy2", "current_hp": 100, "max_hp": 100, "is_alive": true, "conditions": {}, "damage_resistances": [], "damage_immunities": []}
	var dealt := int(CombatAction.resolve_damage(dummy, 20, "force", {}, false, false, ally).get("resolved", -1))
	h._assert(ally.has_condition("enfeebled") and CombatAction.save_has_disadvantage(ally, "STR") and dealt >= 12 and dealt <= 19, P + "fresh-process recovery keeps enfeebled: Strength save Disadvantage and the 1d8 damage penalty (20 -> %d)" % dealt)
	var source := _source(ally)
	ally.ability_scores.from_dict({"STR": 16, "DEX": 10, "CON": 30, "INT": 10, "WIS": 10, "CHA": 10})
	var repeat := {}
	for _attempt in 20:
		repeat = CombatAction.resolve_condition_spell_repeat_save(ally, source)
		if bool(repeat.get("saved", false)): break
	h._assert(bool(repeat.get("saved", false)) and not ally.has_condition("enfeebled"), P + "the recovered record still ends on a successful Con repeat save")
	# Legacy marker from an older save keeps its penalties through the alias.
	ally.add_condition("ray_of_enfeeblement", 10)
	h._assert(CombatAction.save_has_disadvantage(ally, "STR") and CombatAction.attacker_has_condition_disadvantage(ally, "STR"), P + "a legacy ray_of_enfeeblement marker keeps Strength Disadvantage")
	ally.remove_condition("ray_of_enfeeblement")
	print("CROWN_SC_07_SUPPORT_01_FRESH_PROCESS_PASSED")

static func run(h) -> void:
	h._enter_test("crown_sc_07_support_01_flow")
	if OS.get_environment("CROWN_SC_07_SUPPORT_01_RECOVER") == "1":
		_recover(h)
		h._exit_test()
		return
	h._setup_world()
	_contract_checks(h)
	_renamed_checks(h)
	await _player_casts(h)
	_checkpoint(h)
	h._exit_test()
