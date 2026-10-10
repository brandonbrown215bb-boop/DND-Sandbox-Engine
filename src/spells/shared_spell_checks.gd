## Production checks for new IDs authored only in JSON.
class_name SharedSpellChecks
extends RefCounted

static func run(check: Callable) -> void:
	var original_spells := DataLoader.spells.duplicate(true)
	DataLoader._load_content_type("res://data/fixtures/shared_spells/spells/", "spell")
	check.call(DataLoader.get_load_errors().is_empty(), "Shared JSON fixtures load through the production loader")
	var caster := Character.new()
	caster.initialize("Shared caster", "human", "wizard", AbilityScores.new())
	caster.character_id = "shared-unit-caster"
	var ally := Character.new()
	ally.initialize("Shared target", "human", "fighter", AbilityScores.new())
	ally.character_id = "shared-unit-target"
	var shock := DataLoader.get_spell("sandbox:shock")
	var ember := DataLoader.get_spell("sandbox:ember")
	var attack_target := {"name": "Attack target", "current_hp": 1000, "max_hp": 1000, "is_alive": true, "armor_class": -100, "conditions": {"paralyzed": 10}}
	seed(20261009)
	var attack_result := CombatAction.resolve_spell(caster, attack_target, ember, false, {}, [], 3, 10)
	check.call(attack_result.get("hit", false) and int(attack_result.get("damage", 0)) > 0 and SpellDamageRolls.spell_damage_formula(caster, ember, 3) == "2d6 + 2d6", "New attack IDs reuse real spell attacks and upcast damage")
	randomize()
	check.call(SpellSupport.is_available(shock) and "sandbox:shock" not in SpellSupport.AVAILABLE_SLICES, "New shared IDs are executable without spell allowlist edits")
	var target := {"name": "Failed-save target", "current_hp": 100, "max_hp": 100, "is_alive": true, "ability_scores": {"DEX": -100, "CON": -100}, "conditions": {}}
	var shock_result := CombatAction.resolve_spell(caster, target, shock, false, {}, [], 1, 5)
	check.call(shock_result.get("success", false) and not shock_result.get("saved", true) and int(target["current_hp"]) == 96 and CombatAction.has_condition(target, "poisoned"), "New save spell applies typed damage and its failed-save condition")
	var repeat_source := str(shock_result.get("effect_cast", {}).get("source_id", ""))
	target["ability_scores"]["CON"] = 100
	check.call(CombatAction.resolve_condition_spell_repeat_save(target, repeat_source).get("saved", false) and not CombatAction.has_condition(target, "poisoned"), "New-ID repeat saves remove only the spell's source")
	target["ability_scores"]["DEX"] = 100
	target["current_hp"] = 100
	var saved_result := CombatAction.resolve_spell(caster, target, shock, false, {}, [], 1, 5)
	check.call(saved_result.get("saved", false) and int(target["current_hp"]) == 98 and not CombatAction.has_condition(target, "poisoned"), "Successful saves halve damage and suppress failed-save payloads")
	var bard := Character.new()
	bard.initialize("Countercharm bard", "human", "bard", AbilityScores.new())
	bard.features.append({"id": "bard_countercharm"})
	bard.reaction_available = true
	var fear := shock.duplicate(true)
	fear["effects"][1]["condition"] = "frightened"
	var original_dexterity := ally.ability_scores.dexterity
	ally.ability_scores.dexterity = -100
	var fear_result := CombatAction.resolve_spell(caster, ally, fear, false, {"countercharm": true}, [bard], 1, 5)
	ally.ability_scores.dexterity = original_dexterity
	check.call(fear_result.get("countercharm_used", false) and not bard.reaction_available, "New failed-save Frightened payloads use the existing Countercharm reaction")
	SpellEffects.consume_spell(ally, str(fear["id"]))
	var sanctuary := DataLoader.get_spell("sanctuary")
	var protected_target := {"name": "Protected target", "current_hp": 100, "max_hp": 100, "is_alive": true, "armor_class": -100, "conditions": {}}
	SpellEffects.grant(protected_target, SpellEffects.begin_cast(ally, sanctuary), "sanctuary")
	var original_wisdom := caster.ability_scores.wisdom
	caster.ability_scores.wisdom = -100
	var blocked := CombatAction.resolve_spell(caster, protected_target, ember, false, {}, [], 1, 5)
	caster.ability_scores.wisdom = original_wisdom
	check.call(blocked.get("sanctuary_blocked", false) and int(protected_target["current_hp"]) == 100, "Shared attacks preserve Sanctuary's pre-damage protection and use the attacker's saving throw")
	ally.current_hp = 0
	ally.is_alive = false
	ally.add_condition("poisoned", 10)
	var mend := DataLoader.get_spell("sandbox:mend")
	check.call(SpellCastTargeting.can_target_downed(ally, mend), "New healing IDs use downed-target selection")
	var heal_result := CombatAction.resolve_spell(caster, ally, mend, false, {}, [], 1, 5)
	check.call(heal_result.get("healing", 0) == 4 and ally.current_hp == 4 and ally.is_alive and ally.temp_hp == 3 and not ally.has_condition("poisoned"), "Shared composed healing revives an unconscious ally, cleanses and grants nonstacking Temporary HP")
	SharedSpell.apply(caster, ally, mend, heal_result)
	check.call(ally.current_hp == 4, "Reapplying the presentation result does not heal twice")
	var ward := DataLoader.get_spell("sandbox:resolve")
	var ward_result := CombatAction.resolve_spell(caster, ally, ward, false, {}, [], 1, 5)
	var source := str(ward_result["effect_cast"]["source_id"])
	caster.concentrating_on = {"spell_id": ward["id"], "effect_source": source, "targets": [ally]}
	check.call(ally.has_condition("blessed") and SpellEffects.saved_state_error(ally.to_dict()).is_empty() and SpellEffects.saved_state_error(caster.to_dict()).is_empty(), "New-ID condition and concentration records pass production save validation")
	ally.add_condition("blessed", 20, "other-source")
	SpellEffects.end_concentration(caster, [ally])
	check.call(ally.has_condition("blessed") and not SpellEffects.records(ally).has(source), "Concentration cleanup preserves unrelated condition sources")
	var timed := CombatAction.resolve_spell(caster, ally, ward, false, {}, [], 1, 5)
	SpellEffects.advance_time([ally], 60)
	check.call(not SpellEffects.records(ally).has(str(timed["effect_cast"]["source_id"])), "New-ID timed effects expire through the campaign clock")
	var invalid := mend.duplicate(true)
	invalid["effects"].append({"type": "unknown_mod_operation"})
	caster.spell_slots["1"] = 1
	var refused := CombatAction.resolve_spell(caster, ally, invalid, true)
	check.call(not refused.get("success", true) and int(caster.spell_slots["1"]) == 1, "Unsupported shared operations refuse before spending a slot")
	var unknown_field := mend.duplicate(true)
	unknown_field["unimplemented_payload"] = true
	check.call(not SharedSpell.content_error(unknown_field).is_empty(), "Unknown shared fields cannot silently enable unimplemented behavior")
	var invalid_upcast := ember.duplicate(true)
	invalid_upcast["upcast"] = {"damage_per_level": "1d6+3"}
	check.call(not SharedSpell.content_error(invalid_upcast).is_empty(), "Unsupported upcast expressions reject instead of silently ignoring scaling")
	caster.known_spells.assign(["sandbox:resolve", "sandbox:ember"])
	var room_grid := HexGrid.new()
	for coord in HexUtils.get_hexes_in_range(Vector2i.ZERO, 15):
		var tile := HexTile.new()
		tile.coord = coord
		room_grid.add_tile(tile)
	var room := {"party_positions": {caster.character_id: [0, 0], ally.character_id: [1, 0]}, "objects": [], "areas": []}
	var room_cast := LocalRoomSharedSpells.cast(room, caster, "sandbox:resolve", ally, [caster, ally], room_grid)
	check.call(room_cast.get("success", false) and ally.has_condition("blessed") and int(caster.spell_slots["1"]) == 0, "Exploration uses the same new-ID concentration spell and resource path: %s" % str(room_cast))
	SpellEffects.end_concentration(caster, [caster, ally])
	caster.spell_slots["1"] = 1
	room["party_positions"][ally.character_id] = [13, 0]
	var distant_cast := LocalRoomSharedSpells.cast(room, caster, "sandbox:resolve", ally, [caster, ally], room_grid)
	check.call(not distant_cast.get("success", true) and int(caster.spell_slots["1"]) == 1, "Exploration rejects out-of-range shared spells before cost")
	room_grid.free()
	check.call(not DataLoader._validate_content(invalid, "spell", "fixture-invalid"), "Production loader rejects unknown shared operations")
	DataLoader._load_errors.pop_back()
	DataLoader.spells = original_spells
	print("SHARED_SPELL_CHECKS_COMPLETE")
