## SC-01 support 01: generic source-owned conditions (speed_reduced amount, healing_prevented,
## opportunity_attack_blocked, next_attack_disadvantage) and target-turn expiry boundaries,
## proven through real player casts of Ray of Frost, Chill Touch, Shocking Grasp, and Vicious Mockery.
class_name CrownSc01Support01Flow
extends RefCounted

const SLOT := "crown_sc_01_support_01"
const P := "SC-01 support 01: "

static func _monster(id: String, hex: Vector2i, ac: int, scores: Dictionary = {}) -> Dictionary:
	return {"id": id, "name": id, "creature_type": "beast", "hex_position": hex, "is_alive": true, "current_hp": 1000, "max_hp": 1000, "temp_hp": 0, "armor_class": ac, "speed": 6, "conditions": {}, "condition_sources": {}, "spell_effects": {}, "damage_resistances": [], "condition_immunities": [], "spell_slots": {}, "ability_scores": scores, "attacks": [{"name": "Bite", "attack_bonus": 4, "damage": "1d4", "damage_type": "piercing"}]}

## Ordinary class selection that keeps the wanted cantrips and fills the rest.
static func _prepare_cantrips(caster: Character, wanted: Array) -> bool:
	var chosen: Array[String] = []
	for id in wanted: chosen.append(str(id))
	for id in caster.get_spell_option_ids(true):
		if chosen.size() >= caster.get_spellcasting_capacity("cantrips"): break
		if id not in chosen: chosen.append(id)
	var spells: Array[String] = []
	for id in caster.get_spell_option_ids(false):
		if spells.size() >= caster.get_spellcasting_capacity("prepared_spells"): break
		spells.append(id)
	chosen.append_array(spells)
	return ClassProgression.choose_spell_selection(caster, chosen)

## Real picker + hex click; a cantrip costs the action and no slot.
static func _cast_until(h, combat, caster: Character, id: String, hex: Vector2i, stop: Callable, label: String) -> bool:
	for _attempt in 40:
		var slots := caster.spell_slots.duplicate(true)
		ConversionBatch002Flow._select(h, combat, caster, id, 0)
		await combat._on_hex_clicked(hex)
		await ConversionBatch002Flow._wait_resolution(h, combat)
		if combat.turn_budget.action_available or caster.spell_slots != slots:
			h._assert(false, P + "%s spends the action and no slot" % label)
			return false
		if stop.call(): return true
	return false

static func _only_source(target) -> String:
	var found := ""
	for key in SpellEffects.records(target): found = str(key)
	return found

static func _renamed(h, from_id: String, new_id: String) -> Dictionary:
	var definition := DataLoader.get_spell(from_id).duplicate(true)
	for key in definition.keys():
		if str(key).begins_with("_"): definition.erase(key)
	definition.id = new_id
	definition.name = "Neutral " + new_id.get_slice(":", 1)
	definition.classes = []
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.artifacts/crown-sc-01-support-01"))
	var path := "res://.artifacts/crown-sc-01-support-01/%s.json" % new_id.get_slice(":", 1)
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify([definition]))
	file.close()
	DataLoader._load_json_file(path, "spell")
	var renamed := DataLoader.get_spell(new_id)
	h._assert(DataLoader.get_load_errors().is_empty() and SharedSpell.uses(renamed) and SharedSpell.content_error(renamed).is_empty(), P + "renamed %s passes the production loader as shared data" % from_id)
	return renamed

static func _forget(id: String) -> void:
	DataLoader.spells.erase(id)
	DataLoader._registered_sources.get("spell", {}).erase(id)

static func _contract_checks(h) -> void:
	var frost := DataLoader.get_spell("ray_of_frost").duplicate(true)
	var bad := frost.duplicate(true)
	bad.effects[0].erase("amount")
	h._assert(not SharedSpell.content_error(bad).is_empty(), P + "speed_reduced without an amount is rejected")
	bad.effects[0].amount = 0
	h._assert(not SharedSpell.content_error(bad).is_empty(), P + "a zero speed reduction is rejected")
	bad.effects[0].amount = 13
	h._assert(not SharedSpell.content_error(bad).is_empty(), P + "an out-of-range speed reduction is rejected")
	bad = DataLoader.get_spell("chill_touch").duplicate(true)
	bad.effects[0].amount = 2
	h._assert(not SharedSpell.content_error(bad).is_empty(), P + "an amount on a non-magnitude condition is rejected")
	bad.effects[0].erase("amount")
	bad.effects[0].expiry = {"boundary": "target_turn_middle", "turns": 1}
	h._assert(not SharedSpell.content_error(bad).is_empty(), P + "an unknown expiry boundary is rejected")

## Each new operation through a renamed neutral definition: production loader, targeting, resolve_spell.
static func _renamed_checks(h) -> void:
	var caster := ConversionBatch002Checks.actor("crown-sc01s1-renamed-caster", "wizard", 5)
	var caster_id := SpellEffects.caster_id(caster)
	# Magnitude condition with a caster-start expiry.
	var slow := _renamed(h, "ray_of_frost", "crown_sc_01_support_01:neutral_slow")
	var slow_target := _monster("crown-sc01s1-renamed-slow", Vector2i(3, 0), -100)
	h._assert(HexUtils.get_distance(Vector2i.ZERO, Vector2i(3, 0)) <= int(slow.range) and HexUtils.get_distance(Vector2i.ZERO, Vector2i(13, 0)) > int(slow.range), P + "renamed slow ray reaches a creature 15 feet away")
	for _attempt in 40:
		CombatAction.resolve_spell(caster, slow_target, slow, false, {}, [], 0, 3)
		if CombatAction.has_condition(slow_target, "speed_reduced"): break
	var slow_source := _only_source(slow_target)
	h._assert(FighterRules.monster_speed(slow_target) == 4 and str(slow_target.spell_effects.get(slow_source, {}).get("expiry_phase", "")) == "start" and int(slow_target.spell_effects.get(slow_source, {}).get("condition_amounts", {}).get("speed_reduced", 0)) == 2, P + "renamed definition reduces Speed by its authored amount until the caster's next start, with no ID registration")
	SpellEffects.tick_boundary([slow_target], caster_id, "start")
	h._assert(FighterRules.monster_speed(slow_target) == 6 and slow_target.spell_effects.is_empty(), P + "renamed speed reduction ends at the caster's next turn start")
	# Recipient-owned start boundary.
	var jolt := _renamed(h, "shocking_grasp", "crown_sc_01_support_01:neutral_jolt")
	var jolt_target := _monster("crown-sc01s1-renamed-jolt", Vector2i(1, 0), -100)
	for _attempt in 40:
		CombatAction.resolve_spell(caster, jolt_target, jolt, false, {}, [], 0, 1)
		if CombatAction.blocks_opportunity_attack(jolt_target): break
	var jolt_source := _only_source(jolt_target)
	h._assert(CombatAction.blocks_opportunity_attack(jolt_target) and str(jolt_target.spell_effects.get(jolt_source, {}).get("expiry_phase", "")) == "recipient_start", P + "renamed definition blocks Opportunity Attacks with a target-turn-start expiry")
	SpellEffects.tick_boundary([jolt_target], caster_id, "start")
	SpellEffects.tick_boundary([jolt_target], caster_id, "end")
	h._assert(CombatAction.blocks_opportunity_attack(jolt_target), P + "renamed target-owned expiry ignores the caster's boundaries")
	SpellEffects.tick_boundary([jolt_target], "crown-sc01s1-renamed-jolt", "start")
	h._assert(not CombatAction.blocks_opportunity_attack(jolt_target) and jolt_target.spell_effects.is_empty(), P + "renamed restriction ends at the target's own turn start")
	# Failed-save once-only disadvantage with a target-end expiry.
	var jeer := _renamed(h, "vicious_mockery", "crown_sc_01_support_01:neutral_jeer")
	var jeer_target := _monster("crown-sc01s1-renamed-jeer", Vector2i(2, 0), 10, {"WIS": -100})
	CombatAction.resolve_spell(caster, jeer_target, jeer, false, {}, [], 0, 2)
	var attacker := CombatState._make_temp_monster_character(jeer_target)
	var roll := attacker.make_attack_roll()
	CombatState._sync_consumed_monster_attack_conditions(jeer_target, attacker)
	var second := CombatState._make_temp_monster_character(jeer_target).make_attack_roll()
	h._assert(roll.get("disadvantage", false) and not second.get("disadvantage", false) and jeer_target.spell_effects.is_empty(), P + "renamed failed-save grant gives Disadvantage to exactly one attack roll")
	for id in [str(slow.id), str(jolt.id), str(jeer.id)]: _forget(id)

static func run(h) -> void:
	h._enter_test("crown_sc_01_support_01_flow")
	if OS.get_environment("CROWN_SC_01_SUPPORT_01_RECOVER") == "1":
		_recover(h)
		h._exit_test()
		return
	h._setup_world()
	_contract_checks(h)
	_renamed_checks(h)
	for id in ["ray_of_frost", "chill_touch", "shocking_grasp", "vicious_mockery"]:
		var spell := DataLoader.get_spell(id)
		h._assert(SharedSpell.uses(spell) and SharedSpell.content_error(spell).is_empty() and int(spell.level) == 0, P + "%s is shared cantrip data" % id)
	var sorcerer := ConversionBatch002Checks.actor("crown-sc01s1-sorcerer", "sorcerer", 1)
	var bard := ConversionBatch002Checks.actor("crown-sc01s1-bard", "bard", 1)
	var ally := ConversionBatch002Checks.actor("crown-sc01s1-ally", "fighter", 5)
	h._assert(_prepare_cantrips(sorcerer, ["ray_of_frost", "chill_touch", "shocking_grasp"]), P + "Sorcerer learns Ray of Frost, Chill Touch, and Shocking Grasp through ordinary class selection")
	h._assert(_prepare_cantrips(bard, ["vicious_mockery"]), P + "Bard learns Vicious Mockery through ordinary class selection")
	PlayerManager.set_player_character(0, sorcerer)
	while PlayerManager.get_player_count() < 3: PlayerManager.add_player("P%d" % PlayerManager.get_player_count())
	PlayerManager.set_player_character(1, bard)
	PlayerManager.set_player_character(2, ally)
	PartyManager.reset()
	PartyManager.register_player_character(0, sorcerer)
	PartyManager.register_player_character(1, bard)
	PartyManager.register_player_character(2, ally)
	var combat = await h._spawn_scene("res://scenes/combat.tscn", 1.5)
	combat.player_entities[0].hex_position = Vector2i.ZERO
	combat.player_entities[1].hex_position = Vector2i(0, 3)
	combat.player_entities[2].hex_position = Vector2i(-1, 0)
	var frost_target := _monster("crown-sc01s1-frost", Vector2i(3, 0), -100)
	var frost_miss := _monster("crown-sc01s1-frost-miss", Vector2i(3, -1), 1000)
	var chill_target := _monster("crown-sc01s1-chill", Vector2i(1, 0), -100)
	var shock_target := _monster("crown-sc01s1-shock", Vector2i(0, 1), -100)
	var mock_fail := _monster("crown-sc01s1-mock-fail", Vector2i(2, 2), 10, {"WIS": -100})
	var mock_save := _monster("crown-sc01s1-mock-save", Vector2i(-2, 3), 10, {"WIS": 100})
	combat.monster_entities.clear()
	combat.monster_entities.assign([frost_target, frost_miss, chill_target, shock_target, mock_fail, mock_save])
	combat._update_grid_entities()
	GameManager.test_mode = false
	var sid := SpellEffects.caster_id(sorcerer)
	var bid := SpellEffects.caster_id(bard)

	# Ray of Frost: hit reduces Speed by 10 ft until the start of the caster's next turn; miss does nothing.
	var missed := await _cast_until(h, combat, sorcerer, "ray_of_frost", Vector2i(3, -1), func(): return int(frost_miss.current_hp) == 1000, "Ray of Frost miss")
	h._assert(missed and frost_miss.spell_effects.is_empty() and FighterRules.monster_speed(frost_miss) == 6, P + "a missed Ray of Frost deals no damage and leaves Speed unchanged")
	var hit := await _cast_until(h, combat, sorcerer, "ray_of_frost", Vector2i(3, 0), func(): return int(frost_target.current_hp) < 1000, "Ray of Frost hit")
	h._assert(hit and 1000 - int(frost_target.current_hp) <= 8 and FighterRules.monster_speed(frost_target) == 4, P + "Ray of Frost deals 1d8 Cold and reduces Speed by 10 feet")
	SpellEffects.tick_boundary([frost_target], sid, "end")
	SpellEffects.tick_boundary([frost_target], str(frost_target.id), "start")
	h._assert(FighterRules.monster_speed(frost_target) == 4, P + "the reduction lasts through the caster's turn end and the target's own turn")
	SpellEffects.tick_boundary([frost_target], sid, "start")
	h._assert(FighterRules.monster_speed(frost_target) == 6 and frost_target.spell_effects.is_empty(), P + "the reduction ends at the start of the caster's next turn")

	# Chill Touch: target can't regain HP until the end of the caster's next turn.
	var chilled := await _cast_until(h, combat, sorcerer, "chill_touch", Vector2i(1, 0), func(): return CombatAction.is_healing_suppressed(chill_target), "Chill Touch")
	h._assert(chilled and 1000 - int(chill_target.current_hp) <= 10, P + "Chill Touch deals 1d10 Necrotic and blocks healing")
	SpellEffects.tick_boundary([chill_target], sid, "end")
	h._assert(CombatAction.is_healing_suppressed(chill_target), P + "healing stays blocked through the casting turn's end")
	SpellEffects.tick_boundary([chill_target], sid, "end")
	h._assert(not CombatAction.is_healing_suppressed(chill_target), P + "healing returns after the end of the caster's next turn")

	# Shocking Grasp: no Opportunity Attacks until the start of the target's next turn.
	var shocked := await _cast_until(h, combat, sorcerer, "shocking_grasp", Vector2i(0, 1), func(): return CombatAction.blocks_opportunity_attack(shock_target), "Shocking Grasp")
	h._assert(shocked and 1000 - int(shock_target.current_hp) <= 8, P + "Shocking Grasp deals 1d8 Lightning and blocks Opportunity Attacks")
	SpellEffects.tick_boundary([shock_target], sid, "end")
	SpellEffects.tick_boundary([shock_target], sid, "start")
	h._assert(CombatAction.blocks_opportunity_attack(shock_target), P + "caster boundaries do not end the target-owned restriction")
	SpellEffects.tick_boundary([shock_target], str(shock_target.id), "start")
	h._assert(not CombatAction.blocks_opportunity_attack(shock_target), P + "the restriction ends at the start of the target's next turn")

	# Vicious Mockery: failed WIS save → 1d6 Psychic + Disadvantage on one attack before the end of its next turn.
	var mocked := await _cast_until(h, combat, bard, "vicious_mockery", Vector2i(2, 2), func(): return int(mock_fail.current_hp) < 1000, "Vicious Mockery")
	h._assert(mocked and 1000 - int(mock_fail.current_hp) <= 6 and CombatAction.attacker_has_condition_disadvantage(mock_fail), P + "a failed save deals 1d6 Psychic and imposes Disadvantage")
	var saver := await _cast_until(h, combat, bard, "vicious_mockery", Vector2i(-2, 3), func(): return true, "Vicious Mockery save")
	h._assert(saver and int(mock_save.current_hp) == 1000 and mock_save.spell_effects.is_empty(), P + "a successful save takes no damage and no Disadvantage")
	var attacker := CombatState._make_temp_monster_character(mock_fail)
	var roll := attacker.make_attack_roll()
	CombatState._sync_consumed_monster_attack_conditions(mock_fail, attacker)
	h._assert(roll.get("disadvantage", false) and not CombatAction.attacker_has_condition_disadvantage(mock_fail) and mock_fail.spell_effects.is_empty(), P + "the next attack roll has Disadvantage and consumes it")
	mock_fail.current_hp = 1000
	var mocked_again := await _cast_until(h, combat, bard, "vicious_mockery", Vector2i(2, 2), func(): return int(mock_fail.current_hp) < 1000, "Vicious Mockery expiry")
	SpellEffects.tick_boundary([mock_fail], bid, "end")
	SpellEffects.tick_boundary([mock_fail], str(mock_fail.id), "start")
	h._assert(mocked_again and CombatAction.attacker_has_condition_disadvantage(mock_fail), P + "an unused Disadvantage survives the caster's turn end and the target's turn start")
	SpellEffects.tick_boundary([mock_fail], str(mock_fail.id), "end")
	h._assert(not CombatAction.attacker_has_condition_disadvantage(mock_fail) and mock_fail.spell_effects.is_empty(), P + "an unused Disadvantage expires at the end of the target's next turn")

	# Durable checkpoint: target-owned and magnitude records on the party ally save and reload.
	ally.base_ac = -100
	var ally_speed := ally.get_speed()
	var ally_frost := await _cast_until(h, combat, sorcerer, "ray_of_frost", Vector2i(-1, 0), func(): return ally.has_condition("speed_reduced"), "ally Ray of Frost")
	var ally_shock := await _cast_until(h, combat, sorcerer, "shocking_grasp", Vector2i(-1, 0), func(): return CombatAction.blocks_opportunity_attack(ally), "ally Shocking Grasp")
	h._assert(ally_frost and ally_shock and ally.get_speed() == ally_speed - 2, P + "the ally carries a live Speed reduction and Opportunity Attack block")
	h._teardown_scene(combat)
	GameManager.current_state = GameManager.GameState.OVERWORLD
	GameManager.test_mode = true
	GameManager.game_in_progress = true
	h._assert(SaveManager.get_save_block_reason().is_empty() and SaveManager.save_game(SLOT), P + "live target-owned and magnitude records save at the overworld checkpoint")
	var dto := SaveManager._read_save(SLOT)
	h._assert(SaveManager._validate_save_data(dto).is_empty(), P + "the DTO passes production save preflight")
	h._assert(SaveManager.load_game(SLOT), P + "the checkpoint reloads through SaveManager")
	var restored: Character = PartyManager.characters.get(ally.character_id)
	h._assert(restored != null and restored.get_speed() == ally_speed - 2 and CombatAction.blocks_opportunity_attack(restored), P + "reload restores the Speed amount and the target-owned block")
	print("CROWN_SC_01_SUPPORT_01_CHECKPOINT_READY")
	h._exit_test()

static func _recover(h) -> void:
	h._assert(SaveManager.load_game(SLOT), P + "a fresh process loads the real checkpoint")
	var sorcerer: Character = PartyManager.characters.get("crown-sc01s1-sorcerer")
	var ally: Character = PartyManager.characters.get("crown-sc01s1-ally")
	if sorcerer == null or ally == null:
		h._assert(false, P + "caster and target identities recover")
		return
	var base := ally.get_speed() + SpellEffects.condition_amount(ally, "speed_reduced")
	h._assert(SpellEffects.condition_amount(ally, "speed_reduced") == 2 and CombatAction.blocks_opportunity_attack(ally), P + "fresh-process recovery keeps both records")
	SpellEffects.tick_boundary([ally], SpellEffects.caster_id(ally), "start")
	h._assert(not CombatAction.blocks_opportunity_attack(ally) and ally.get_speed() == base - 2, P + "the recovered block ends at the target's own turn start; Speed stays reduced")
	SpellEffects.tick_boundary([ally], SpellEffects.caster_id(sorcerer), "start")
	h._assert(ally.get_speed() == base and ally.spell_effects.is_empty(), P + "the recovered Speed reduction ends at the caster's next turn start")
	h._assert(SaveManager.save_game(SLOT), P + "the recovered state saves")
	print("CROWN_SC_01_SUPPORT_01_FRESH_PROCESS_PASSED")
