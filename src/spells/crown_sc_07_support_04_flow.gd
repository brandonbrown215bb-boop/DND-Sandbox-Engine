## SC-07 support 04: Enthrall as shared data.
## New generic pieces: the "enthralled" marker whose perception_penalty_10
## consequence is read by EventResolver for Character and monster Wisdom
## (Perception) checks and by the new EventResolver.passive_perception; the
## "fighting_caster_side" save auto-success trait (opposed initiative combatants).
class_name CrownSc07Support04Flow
extends RefCounted

const P := "SC-07 s4: "
const SLOT := "crown_sc_07_support_04"

static func _wis(id: String, hex: Vector2i, bonus: int) -> Dictionary:
	var m := CrownSc01Support01Flow._monster(id, hex, 10, {"wisdom": 10})
	m["saving_throw_bonuses"] = {"WIS": bonus}
	m["skills"] = {"Perception": 3}
	return m

static func _contract_checks(h) -> void:
	var spell := DataLoader.get_spell("enthrall")
	h._assert(SharedSpell.uses(spell) and SharedSpell.content_error(spell).is_empty() and int(spell.range) == 12 and spell.save == "WIS" and spell.target == "multi" and bool(spell.requires_target_sight) and bool(spell.concentration) and spell.save_auto_success_traits == ["fighting_caster_side"], P + "Enthrall is shared data (60 ft, chosen seen creatures, Wis save, concentration, fighting auto-success)")
	h._assert(CombatAction.condition_rule("enthralled", "perception_penalty_10") and "enthralled" in SharedSpell.CONDITIONS, P + "the enthralled marker carries the perception penalty consequence")
	var bad := spell.duplicate(true)
	bad["save_auto_success_traits"] = ["is_a_friend_of_bards"]
	h._assert(not SharedSpell.content_error(bad).is_empty(), P + "an unknown auto-success trait is rejected")
	bad = spell.duplicate(true)
	bad.effects[0]["condition"] = "spellbound_forever"
	h._assert(not SharedSpell.content_error(bad).is_empty(), P + "an unknown granted condition is rejected")

static func _renamed_checks(h) -> void:
	var caster := ConversionBatch002Checks.actor("crown-sc07s4-renamed", "bard", 5)
	var lull := CrownSc01Support01Flow._renamed(h, "enthrall", "crown_sc_07_support_04:neutral_lull")
	var weak := _wis("crown-sc07s4-r1", Vector2i(3, 0), -1000)
	var mod_before := EventResolver.monster_ability_check_modifier(weak, "WIS", "Perception")
	var passive_before := EventResolver.passive_perception(weak)
	var failed := CombatAction.resolve_spell(caster, weak, lull, false, {}, [], 2, 3)
	h._assert(not bool(failed.get("saved", true)) and CombatAction.has_condition(weak, "enthralled"), P + "renamed enthrall: a failed Wis save outside a fight grants enthralled through CombatAction.resolve_spell")
	var check := EventResolver.resolve_monster_ability_check(weak, "WIS", "Perception", 0)
	h._assert(EventResolver.monster_ability_check_modifier(weak, "WIS", "Perception") == mod_before - 10 and int(check.get("modifier", 0)) == mod_before - 10 and EventResolver.passive_perception(weak) == passive_before - 10 and passive_before == 13, P + "an enthralled monster's Wisdom (Perception) check and Passive Perception drop by 10 (13 -> %d)" % EventResolver.passive_perception(weak))
	h._assert(EventResolver.monster_ability_check_modifier(weak, "WIS", "Insight") == 0 and EventResolver.monster_ability_check_modifier(weak, "DEX", "Stealth") == 0, P + "other checks are unchanged")
	var hero := ConversionBatch002Checks.actor("crown-sc07s4-hero", "fighter", 1)
	var hero_mod := int(EventResolver.resolve_skill_check(hero, {"ability": "WIS", "skill": "Perception", "dc": 0}).get("modifier", 0))
	var hero_passive := EventResolver.passive_perception(hero)
	SpellEffects.grant(hero, SpellEffects.begin_cast(caster, lull), "enthralled")
	var hero_after := int(EventResolver.resolve_skill_check(hero, {"ability": "WIS", "skill": "Perception", "dc": 0}).get("modifier", 0))
	var hero_insight := int(EventResolver.resolve_skill_check(hero, {"ability": "WIS", "skill": "Insight", "dc": 0}).get("modifier", 0))
	h._assert(hero_after == hero_mod - 10 and EventResolver.passive_perception(hero) == hero_passive - 10 and hero_insight == hero.get_skill_check_modifier("Insight", "WIS"), P + "an enthralled Character's Perception check and Passive Perception drop by 10; Insight is unchanged")
	# Fighting: an opposed initiative combatant auto-succeeds without dice.
	var foe := _wis("crown-sc07s4-r2", Vector2i(3, 0), -1000)
	var tracker := InitiativeTracker.new()
	tracker.add_combatant(caster.character_id, caster.character_name, true, caster, 15, 10)
	tracker.add_combatant(str(foe.id), str(foe.name), false, foe, 10, 10)
	var host := SpellCastContext.new()
	host.caster = caster; host.spell = lull; host.tracker = tracker
	var cast := SpellResolutionContext.new()
	cast.caster = caster; cast.target = foe; cast.spell = lull; cast.spatial_host = host
	var fought := SpellSaveResolver.resolve(cast)
	h._assert(bool(fought.get("saved", false)) and bool(fought.get("automatic_save", false)) and not CombatAction.has_condition(foe, "enthralled"), P + "a creature the caster's side is fighting automatically succeeds")
	foe["influence"] = {"attitude": "friendly"}
	h._assert(not SpellSaveResolver.is_fighting_caster_side(cast, foe), P + "a friendly creature in initiative is not being fought")
	CrownSc01Support01Flow._forget(str(lull.id))

static func _player_casts(h) -> void:
	var warlock := ConversionBatch002Checks.actor("crown-sc07s4-lock", "warlock", 1)
	var learned := ConversionBatch001Flow._prepare(warlock, [])
	for _level in 2:
		warlock.level_up()
	learned = learned and ConversionBatch001Flow._prepare(warlock, ["enthrall"])
	h._assert(learned and warlock.level == 3 and "enthrall" in warlock.get_spell_option_ids(false), P + "a Warlock reaches level 3 and selects Enthrall through ordinary class selection")
	PlayerManager.set_player_character(0, warlock)
	PartyManager.reset()
	PartyManager.register_player_character(0, warlock)
	var combat = await h._spawn_scene("res://scenes/combat.tscn", 1.5)
	h._ready_spell_components(warlock)
	combat.player_entities[0].hex_position = Vector2i.ZERO
	var hostile := _wis("crown-sc07s4-hostile", Vector2i(2, 0), -1000)
	var bystander := _wis("crown-sc07s4-bystander", Vector2i(0, 2), -1000)
	bystander["influence"] = {"attitude": "friendly"}
	combat.monster_entities.clear()
	combat.monster_entities.assign([hostile, bystander])
	for m in [hostile, bystander]: combat.tracker.add_combatant(str(m.id), str(m.name), false, m, 5, 10)
	combat._update_grid_entities()
	GameManager.test_mode = false
	warlock.spell_slots = {"1": 0, "2": 2}
	ConversionBatch002Flow._select(h, combat, warlock, "enthrall", 2)
	await combat._on_hex_clicked(Vector2i(2, 0))
	await combat._on_hex_clicked(Vector2i(0, 2))
	await combat._on_hex_clicked(Vector2i(0, 2))
	await ConversionBatch002Flow._wait_resolution(h, combat)
	h._assert(CombatAction.has_condition(bystander, "enthralled") and not CombatAction.has_condition(hostile, "enthralled") and str(warlock.concentrating_on.get("spell_id", "")) == "enthrall" and int(warlock.spell_slots["2"]) == 1, P + "picker + two hex clicks + confirm: the fought hostile auto-succeeds, the friendly bystander fails and is enthralled under concentration (%s)" % combat.hud.log_text.text.right(240))
	h._assert(EventResolver.passive_perception(bystander) == 3, P + "the live enthralled bystander's Passive Perception is 3 (13 - 10)")
	SpellEffects.end_concentration(warlock, [hostile, bystander])
	warlock.concentrating_on = {}
	h._assert(not CombatAction.has_condition(bystander, "enthralled") and EventResolver.passive_perception(bystander) == 13, P + "ending concentration ends the penalty")
	GameManager.test_mode = true
	h._teardown_scene(combat)

static func _checkpoint(h) -> void:
	var caster := ConversionBatch002Checks.actor("crown-sc07s4-saver", "bard", 5)
	var ally := ConversionBatch002Checks.actor("crown-sc07s4-ally", "fighter", 1)
	PartyManager.reset()
	PlayerManager.set_player_character(0, caster)
	PlayerManager.set_player_character(1, ally)
	PartyManager.register_player_character(0, caster)
	PartyManager.register_player_character(1, ally)
	ally.ability_scores.from_dict({"STR": 16, "DEX": 10, "CON": 12, "INT": 10, "WIS": 1, "CHA": 10})
	for _attempt in 80:
		CombatAction.resolve_spell(caster, ally, DataLoader.get_spell("enthrall"), false, {}, [], 2, 2)
		if ally.has_condition("enthralled"): break
		for key in SpellEffects.records(ally).keys(): SpellEffects.remove(ally, str(key))
	caster.concentrating_on = {"spell_id": "enthrall", "effect_source": CrownSc07Support01Flow._source(ally), "targets": [ally]}
	h._assert(ally.has_condition("enthralled"), P + "the party carries an enthralled record")
	GameManager.current_state = GameManager.GameState.OVERWORLD
	GameManager.test_mode = true
	GameManager.game_in_progress = true
	h._assert(SaveManager.get_save_block_reason().is_empty() and SaveManager.save_game(SLOT), P + "the record saves at the overworld checkpoint")
	h._assert(SaveManager._validate_save_data(SaveManager._read_save(SLOT)).is_empty(), P + "the DTO passes production save preflight")
	h._assert(SaveManager.load_game(SLOT), P + "the checkpoint reloads through SaveManager")
	print("CROWN_SC_07_SUPPORT_04_CHECKPOINT_READY")

static func _recover(h) -> void:
	h._assert(SaveManager.load_game(SLOT), P + "a fresh process loads the real checkpoint")
	var ally: Character = PartyManager.characters.get("crown-sc07s4-ally")
	var caster: Character = PartyManager.characters.get("crown-sc07s4-saver")
	if ally == null or caster == null:
		h._assert(false, P + "the caster and target identities recover")
		return
	var expected := 10 + ally.get_skill_check_modifier("Perception", "WIS") - 10
	h._assert(ally.has_condition("enthralled") and EventResolver.passive_perception(ally) == expected and int(EventResolver.resolve_skill_check(ally, {"ability": "WIS", "skill": "Perception", "dc": 0}).get("modifier", 0)) == ally.get_skill_check_modifier("Perception", "WIS") - 10, P + "fresh-process recovery keeps enthralled: Perception check and Passive Perception are still -10 (passive %d)" % EventResolver.passive_perception(ally))
	SpellEffects.end_concentration(caster, [ally])
	h._assert(not ally.has_condition("enthralled") and EventResolver.passive_perception(ally) == expected + 10, P + "the recovered record still ends with the caster's concentration")
	print("CROWN_SC_07_SUPPORT_04_FRESH_PROCESS_PASSED")

static func run(h) -> void:
	h._enter_test("crown_sc_07_support_04_flow")
	if OS.get_environment("CROWN_SC_07_SUPPORT_04_RECOVER") == "1":
		_recover(h)
		h._exit_test()
		return
	h._setup_world()
	_contract_checks(h)
	_renamed_checks(h)
	await _player_casts(h)
	_checkpoint(h)
	h._exit_test()
