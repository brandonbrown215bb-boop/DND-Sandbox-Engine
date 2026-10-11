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
	FighterChecks._seed_die(20, 10)
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

	# Ordered Execution: attack then save (preserving attack damage on save)
	var atk_then_save := DataLoader.get_spell("sandbox:attack_then_save")
	check.call(atk_then_save != null and not atk_then_save.is_empty(), "Fixture sandbox:attack_then_save loaded")
	var dummy_enemy := {"name": "Test target", "current_hp": 100, "max_hp": 100, "is_alive": true, "armor_class": -100, "conditions": {}, "ability_scores": {"CON": 100}}
	FighterChecks._seed_die(20, 10)
	var hit_saved_res := CombatAction.resolve_spell(caster, dummy_enemy, atk_then_save, false, {}, [], 1, 5)
	check.call(hit_saved_res.get("hit", false) and hit_saved_res.get("saved", false) and int(hit_saved_res.get("damage", 0)) > 0 and int(dummy_enemy["current_hp"]) < 100 and not CombatAction.has_condition(dummy_enemy, "poisoned"), "Attack then save preserves attack damage when secondary save succeeds and suppresses poisoned condition")
	check.call(hit_saved_res.get("step_results", []).size() == 2 and hit_saved_res["step_results"][0]["hit"] and hit_saved_res["step_results"][1]["saved"] and hit_saved_res["step_results"][1]["damage"] == 0, "Per-step results distinguish attack hit from save success")

	# Secondary save fails -> deals secondary damage and grants condition
	dummy_enemy["current_hp"] = 100
	dummy_enemy["ability_scores"]["CON"] = -100
	FighterChecks._seed_die(20, 10)
	var hit_failed_res := CombatAction.resolve_spell(caster, dummy_enemy, atk_then_save, false, {}, [], 1, 5)
	check.call(hit_failed_res.get("hit", false) and not hit_failed_res.get("saved", true) and hit_failed_res.get("step_results", [])[1]["damage"] > 0 and CombatAction.has_condition(dummy_enemy, "poisoned"), "Attack then save deals secondary poison damage and grants condition on failed save")
	CombatAction.remove_condition_source(dummy_enemy, str(hit_failed_res.get("effect_cast", {}).get("source_id", "")), ["poisoned"])

	# Attack misses -> gated save is skipped entirely
	dummy_enemy["current_hp"] = 100
	dummy_enemy["armor_class"] = 1000
	FighterChecks._seed_die(20, 1)
	var miss_res := CombatAction.resolve_spell(caster, dummy_enemy, atk_then_save, false, {}, [], 1, 5)
	check.call(not miss_res.get("hit", true) and miss_res.get("step_results", [])[1].get("skipped", false) and int(dummy_enemy["current_hp"]) == 100, "Missed attack skips gated save step entirely without rolling or dealing damage")

	# Ordered Execution: attack then independent area save (runs after hit AND miss)
	var atk_then_area := DataLoader.get_spell("sandbox:attack_then_area")
	var primary_target := {"name": "Primary target", "current_hp": 100, "max_hp": 100, "is_alive": true, "armor_class": -100, "conditions": {}, "ability_scores": {"DEX": -100}}
	var nearby_target := {"name": "Nearby target", "current_hp": 100, "max_hp": 100, "is_alive": true, "armor_class": 10, "conditions": {}, "ability_scores": {"DEX": 100}}
	var area_decisions := {"area_targets": [primary_target, nearby_target]}
	FighterChecks._seed_die(20, 10)
	var area_hit_res := CombatAction.resolve_spell(caster, primary_target, atk_then_area, false, area_decisions, [], 1, 5)
	var area_step: Dictionary = area_hit_res.get("step_results", [])[1]
	check.call(area_hit_res.get("hit", false) and area_step.get("target_outcomes", []).size() == 2, "Attack hits and independent area save executes against all area targets")
	var pri_outcome: Dictionary = area_step["target_outcomes"][0]
	var near_outcome: Dictionary = area_step["target_outcomes"][1]
	check.call(not pri_outcome.get("saved", true) and near_outcome.get("saved", false) and pri_outcome.get("damage", 0) > near_outcome.get("damage", 0), "Original and nearby area targets have distinct save and damage outcomes")

	# Area save runs after attack miss
	primary_target["current_hp"] = 100
	primary_target["armor_class"] = 1000
	nearby_target["current_hp"] = 100
	FighterChecks._seed_die(20, 1)
	var area_miss_res := CombatAction.resolve_spell(caster, primary_target, atk_then_area, false, area_decisions, [], 1, 5)
	var miss_area_step: Dictionary = area_miss_res.get("step_results", [])[1]
	check.call(not area_miss_res.get("hit", true) and not miss_area_step.get("skipped", false) and miss_area_step.get("target_outcomes", []).size() == 2, "Independently declared area save runs after an attack miss with distinct target outcomes")

	# Ordered Execution: save enabling a later attack (ADR-0017)
	var save_then_atk := DataLoader.get_spell("sandbox:save_then_attack")
	var save_atk_target := {"name": "Ensnare target", "current_hp": 100, "max_hp": 100, "is_alive": true, "armor_class": -100, "conditions": {}, "ability_scores": {"STR": -100}}
	FighterChecks._seed_die(20, 10)
	var save_failed_res := CombatAction.resolve_spell(caster, save_atk_target, save_then_atk, false, {}, [], 1, 5)
	check.call(not save_failed_res.get("saved", true) and save_failed_res.get("step_results", [])[1].get("hit", false) and int(save_failed_res.get("damage", 0)) > 0, "Failed initial save enables subsequent attack roll and damage")

	save_atk_target["current_hp"] = 100
	save_atk_target["ability_scores"]["STR"] = 100
	var save_succeeded_res := CombatAction.resolve_spell(caster, save_atk_target, save_then_atk, false, {}, [], 1, 5)
	check.call(save_succeeded_res.get("saved", false) and save_succeeded_res.get("step_results", [])[1].get("skipped", false) and int(save_succeeded_res.get("damage", 0)) == 0, "Successful initial save disables subsequent attack step")

	# Suspension, awaited decision, cancellation/refusal and resume (Empowered Spell)
	var sorcerer := Character.new()
	sorcerer.initialize("Empowered sorcerer", "human", "sorcerer", AbilityScores.new())
	sorcerer.character_id = "shared-sorcerer"
	sorcerer.sorcerer_metamagic_choices.append("empowered_spell")
	sorcerer.features.append({"id": "sorcerer_metamagic"})
	sorcerer.feature_uses["sorcery_points"] = 3
	sorcerer.spell_slots["1"] = 3
	var empower_spell := DataLoader.get_spell("sandbox:ordered_empowered")
	var empower_target := {"name": "Empower target", "current_hp": 100, "max_hp": 100, "is_alive": true, "armor_class": -100, "conditions": {}, "ability_scores": {"DEX": -100}}

	# Preflight refusal before spending:
	sorcerer.spell_slots["1"] = 0
	var slot_refused := CombatAction.resolve_spell(sorcerer, empower_target, empower_spell, true, {"metamagic:empowered": true})
	check.call(not slot_refused.get("success", true) and int(sorcerer.feature_uses["sorcery_points"]) == 3, "Insufficient slot refuses before spending slot or Sorcery Points")
	sorcerer.spell_slots["1"] = 3

	# Cast with defer_empowered:
	var pending_decisions := {"metamagic:empowered": true, "defer_empowered": true}
	FighterChecks._seed_die(20, 10)
	var suspended_cast := CombatAction.resolve_spell(sorcerer, empower_target, empower_spell, true, pending_decisions, [], 1, 5)
	check.call(suspended_cast.has("damage_request") and suspended_cast.get("suspended_step") == 0 and int(sorcerer.spell_slots["1"]) == 2 and int(sorcerer.feature_uses["sorcery_points"]) == 3, "Cast suspends at step 0 damage request with slot spent once and Sorcery Points uncharged")

	# Resume with reroll:
	var reroll_decisions := {"metamagic:empowered": true, "metamagic:empowered_dice": [0]}
	var resumed_result := CombatAction.finish_pending_spell_damage(sorcerer, empower_target, suspended_cast, reroll_decisions)
	check.call(not resumed_result.has("damage_request") and int(sorcerer.feature_uses["sorcery_points"]) == 2 and resumed_result.get("step_results", []).size() == 2, "Resuming with reroll charges Sorcery Point exactly once and completes step 1 save")

	# Stale / repeated call on already completed result is idempotent:
	var stale_points_before: int = int(sorcerer.feature_uses["sorcery_points"])
	var stale_hp_before: int = int(empower_target["current_hp"])
	var stale_res := CombatAction.finish_pending_spell_damage(sorcerer, empower_target, resumed_result, reroll_decisions)
	check.call(int(sorcerer.feature_uses["sorcery_points"]) == stale_points_before and int(empower_target["current_hp"]) == stale_hp_before, "Calling finish_pending_spell_damage on completed result is idempotent")

	# Refusal / cancellation:
	empower_target["current_hp"] = 100
	FighterChecks._seed_die(20, 10)
	var cancel_cast := CombatAction.resolve_spell(sorcerer, empower_target, empower_spell, true, {"metamagic:empowered": true, "defer_empowered": true}, [], 1, 5)
	check.call(cancel_cast.has("damage_request") and int(sorcerer.spell_slots["1"]) == 1, "New cast suspends with slot spent exactly once")
	var cancel_original_total: int = int(cancel_cast["damage_request"]["details"]["final_total"]) + int(cancel_cast["damage_request"]["bonus"])
	var cancel_decisions := {"metamagic:empowered": true, "metamagic:empowered_dice": []}
	var cancelled_result := CombatAction.finish_pending_spell_damage(sorcerer, empower_target, cancel_cast, cancel_decisions)
	check.call(int(empower_target["current_hp"]) == 100 - cancel_original_total and int(sorcerer.feature_uses["sorcery_points"]) == 2, "Cancelling the first Empowered prompt keeps exactly the original rolled damage and charges no Sorcery Points")
	# The allowance is still unused, so the later save step legitimately opens its own prompt.
	check.call(cancelled_result.has("damage_request") and cancelled_result.get("suspended_step") == 1, "Cancelling step 0 continues into the legitimate step 1 prompt instead of disabling later choices")
	cancelled_result = CombatAction.finish_pending_spell_damage(sorcerer, empower_target, cancelled_result, cancel_decisions)
	check.call(not cancelled_result.has("damage_request") and int(sorcerer.feature_uses["sorcery_points"]) == 2 and cancelled_result.get("step_results", []).size() == 2 and int(empower_target["current_hp"]) < 100 - cancel_original_total, "Cancelling the later prompt too completes both steps with no Sorcery Point charge and the second step's original damage applied")

	# Step validation error checks:
	var invalid_step_field := atk_then_save.duplicate(true)
	invalid_step_field["steps"][0]["unknown_field"] = "bad"
	check.call(not SharedSpell.content_error(invalid_step_field).is_empty(), "Unsupported step field rejects preflight")

	var invalid_gate_ref := atk_then_save.duplicate(true)
	invalid_gate_ref["steps"][1]["gate_step"] = "nonexistent"
	check.call(not SharedSpell.content_error(invalid_gate_ref).is_empty(), "Step referencing nonexistent gate step rejects preflight")

	var invalid_gate_type := save_then_atk.duplicate(true)
	invalid_gate_type["steps"][1]["gate"] = "hit"
	check.call(not SharedSpell.content_error(invalid_gate_type).is_empty(), "Gate 'hit' referencing save step prerequisite rejects preflight")

	# Production loader invalid fixtures:
	var invalid_loader_spell := ember.duplicate(true)
	invalid_loader_spell["steps"] = [
		{"id": "s1", "type": "attack", "attack_type": "ranged_spell", "damage": "1d6", "damage_type": "fire"},
		{"id": "s2", "type": "replace_hp", "replacement_hp": 1}
	]
	check.call(not DataLoader._validate_content(invalid_loader_spell, "spell", "fixture-invalid-step"), "Production loader rejects spell fixture with unsupported replace_hp step")
	DataLoader._load_errors.pop_back()

	var invalid_dc_spell := shock.duplicate(true)
	invalid_dc_spell["steps"] = [{"id": "s1", "type": "save", "save": "DEX", "dc_base": 15}]
	check.call(not DataLoader._validate_content(invalid_dc_spell, "spell", "fixture-invalid-dc"), "Production loader rejects spell save step declaring dc_base")
	DataLoader._load_errors.pop_back()

	var invalid_monster := {
		"id": "bad_monster", "name": "Bad Monster", "hit_points": "10", "armor_class": 10, "speed": 6, "attacks": [], "ai_behavior": "aggressive",
		"special_abilities": [{"type": "zero_hp_replacement", "trigger": "zero_hp", "steps": [{"id": "s1", "type": "save", "save": "CON"}, {"id": "s2", "type": "attack", "attack_type": "ranged_spell", "damage": "1d6", "damage_type": "fire"}]}]
	}
	check.call(not DataLoader._validate_content(invalid_monster, "monster", "fixture-invalid-monster-op"), "Production loader rejects monster special ability with unsupported attack step")
	DataLoader._load_errors.pop_back()

	var invalid_scalar_monster := {
		"id": "bad_monster_2", "name": "Bad Monster 2", "hit_points": "10", "armor_class": 10, "speed": 6, "attacks": [], "ai_behavior": "aggressive",
		"special_abilities": [{"type": 123, "trigger": "zero_hp"}]
	}
	check.call(not DataLoader._validate_content(invalid_scalar_monster, "monster", "fixture-invalid-scalar"), "Production loader rejects monster special ability with non-string type scalar")
	DataLoader._load_errors.pop_back()

	var invalid_trigger_monster := {
		"id": "bad_monster_3", "name": "Bad Monster 3", "hit_points": "10", "armor_class": 10, "speed": 6, "attacks": [], "ai_behavior": "aggressive",
		"special_abilities": [{"type": "zero_hp_replacement", "trigger": "unknown_trigger"}]
	}
	check.call(not DataLoader._validate_content(invalid_trigger_monster, "monster", "fixture-invalid-trigger"), "Production loader rejects monster special ability with unknown trigger")
	DataLoader._load_errors.pop_back()

	# Preflight refusal with an earlier valid mutating step followed by unsupported op:
	caster.spell_slots["1"] = 1
	var mutate_target := {"name": "Mutate Target", "current_hp": 50, "max_hp": 50, "is_alive": true, "armor_class": -100, "conditions": {}}
	var partial_spell := ember.duplicate(true)
	partial_spell["steps"] = [
		{"id": "step_attack", "type": "attack", "attack_type": "ranged_spell", "damage": "2d6", "damage_type": "fire"},
		{"id": "step_unsupported", "type": "replace_hp", "replacement_hp": 1}
	]
	FighterChecks._seed_die(20, 20)
	var preflight_res := CombatAction.resolve_spell(caster, mutate_target, partial_spell, true)
	check.call(not preflight_res.get("success", true) and int(caster.spell_slots["1"]) == 1 and int(mutate_target["current_hp"]) == 50 and mutate_target["conditions"].is_empty(), "Preflight refusal with earlier valid mutating step followed by unsupported op proves no partial damage, cost, or effect")

	var step_cast_test := SpellResolutionContext.new()
	step_cast_test.caster = caster
	step_cast_test.target = mutate_target
	step_cast_test.spell = partial_spell
	var direct_preflight := SharedStepExecutor.execute_spell(step_cast_test)
	check.call(not direct_preflight.get("success", true) and bool(direct_preflight.get("refused", false)) and int(mutate_target["current_hp"]) == 50, "SharedStepExecutor direct preflight execution refusal prevents step 0 damage mutation")

	# B1: save -> attack visible summary
	var save_atk_summary_target := {"name": "Save-Atk Target", "current_hp": 100, "max_hp": 100, "is_alive": true, "armor_class": -100, "conditions": {}, "ability_scores": {"STR": -100}}
	FighterChecks._seed_die(20, 10)
	var save_atk_summary_res := CombatAction.resolve_spell(caster, save_atk_summary_target, save_then_atk, false, {}, [], 1, 5)
	check.call(save_atk_summary_res.get("hit", false) == true and not save_atk_summary_res.get("saved", true) and int(save_atk_summary_res.get("damage", 0)) > 0, "Save followed by attack correctly reports hit=true in visible summary when attack hits")

	# B1: Per-target gating order independence
	var gated_area_spell := {
		"id": "sandbox:gated_area_test",
		"name": "Gated Area Test",
		"execution": "shared",
		"duration_seconds": 60,
		"steps": [
			{"id": "step_save", "type": "save", "save": "DEX", "target": "area", "shape": "sphere", "radius": 2, "damage": "2d6", "damage_type": "fire", "half_on_save": true},
			{"id": "step_gated", "type": "save", "save": "CON", "target": "area", "shape": "sphere", "radius": 2, "gate_step": "step_save", "gate": "failed_save", "effects": [{"type": "grant_condition", "condition": "poisoned", "on_failed_save": true}]}
		]
	}
	var actor_fail := {"name": "Actor Fail", "current_hp": 100, "max_hp": 100, "is_alive": true, "ability_scores": {"DEX": -100, "CON": -100}, "conditions": {}}
	var actor_pass := {"name": "Actor Pass", "current_hp": 100, "max_hp": 100, "is_alive": true, "ability_scores": {"DEX": 100, "CON": 100}, "conditions": {}}

	var ctx1 := SpellResolutionContext.new()
	ctx1.caster = caster
	ctx1.target = actor_fail
	ctx1.spell = gated_area_spell
	ctx1.effect_cast = SpellEffects.begin_cast(caster, gated_area_spell)
	ctx1.decisions = {"area_targets": [actor_fail, actor_pass]}
	var order1_res := SharedStepExecutor.execute_spell(ctx1)
	var step1_outcomes: Array = order1_res["step_results"][1]["target_outcomes"]
	var f1_skipped := false
	var p1_skipped := false
	for to in step1_outcomes:
		if SharedStepExecutor._same_actor(to["target"], actor_fail):
			f1_skipped = bool(to.get("skipped", false))
		elif SharedStepExecutor._same_actor(to["target"], actor_pass):
			p1_skipped = bool(to.get("skipped", false))
	check.call(not f1_skipped and p1_skipped, "Order [fail, pass]: failing actor executes gated step while succeeding actor is skipped")

	var ctx2 := SpellResolutionContext.new()
	ctx2.caster = caster
	ctx2.target = actor_pass
	ctx2.spell = gated_area_spell
	ctx2.effect_cast = SpellEffects.begin_cast(caster, gated_area_spell)
	ctx2.decisions = {"area_targets": [actor_pass, actor_fail]}
	var order2_res := SharedStepExecutor.execute_spell(ctx2)
	var step2_outcomes: Array = order2_res["step_results"][1]["target_outcomes"]
	var f2_skipped := false
	var p2_skipped := false
	for to in step2_outcomes:
		if SharedStepExecutor._same_actor(to["target"], actor_fail):
			f2_skipped = bool(to.get("skipped", false))
		elif SharedStepExecutor._same_actor(to["target"], actor_pass):
			p2_skipped = bool(to.get("skipped", false))
	check.call(not f2_skipped and p2_skipped, "Order [pass, fail]: target evaluation is order-independent; failing actor still executes gated step")

	# B1: Spatial context refusal before state mutation
	var spatial_refusal_spell := {
		"id": "sandbox:spatial_area",
		"name": "Spatial Area",
		"execution": "shared",
		"steps": [{"id": "s1", "type": "damage", "target": "area", "shape": "sphere", "radius": 2, "damage": "2d6", "damage_type": "fire"}]
	}
	var no_context_ctx := SpellResolutionContext.new()
	no_context_ctx.caster = caster
	no_context_ctx.target = actor_fail
	no_context_ctx.spell = spatial_refusal_spell
	no_context_ctx.decisions = {}
	var refused_spatial := SharedStepExecutor.execute_spell(no_context_ctx)
	check.call(not refused_spatial.get("success", true) and bool(refused_spatial.get("refused", false)), "Area step missing encounter spatial context refuses before mutation")

	# B1: Wall line-of-sight obstruction filters area targets
	var wall_grid := HexGrid.new()
	for x in range(-3, 4):
		for y in range(-3, 4):
			var tile := HexTile.new()
			tile.coord = Vector2i(x, y)
			if x == 1 and y == 0:
				tile.custom_properties["blocks_sight"] = true
			wall_grid.add_tile(tile)
	var los_caster := Character.new()
	los_caster.initialize("LOS Caster", "human", "wizard", AbilityScores.new())
	los_caster.character_id = "los-caster"
	var open_monster := {"id": "open_m", "name": "Open Monster", "hex_position": Vector2i(0, 1), "current_hp": 50, "max_hp": 50, "is_alive": true}
	var blocked_monster := {"id": "blocked_m", "name": "Blocked Monster", "hex_position": Vector2i(2, 0), "current_hp": 50, "max_hp": 50, "is_alive": true}
	var los_cast := SpellResolutionContext.new()
	los_cast.caster = los_caster
	los_cast.target = {"hex_position": Vector2i(0, 0)}
	los_cast.spell = {
		"id": "sandbox:los_area",
		"name": "LOS Area",
		"execution": "shared",
		"steps": [{"id": "s1", "type": "damage", "target": "area", "shape": "sphere", "radius": 3, "damage": "1d6", "damage_type": "fire"}]
	}
	los_cast.decisions = {
		"grid": wall_grid,
		"players": [{"character": los_caster, "hex_position": Vector2i(0, 0)}],
		"monsters": [open_monster, blocked_monster]
	}
	var los_res := SharedStepExecutor.execute_spell(los_cast)
	var los_outcomes: Array = los_res["step_results"][0]["target_outcomes"]
	var open_hit := false
	var blocked_hit := false
	for to in los_outcomes:
		var target_id: String = to["target"].character_id if to["target"] is Character else str(to["target"].get("id", ""))
		if target_id == "open_m": open_hit = true
		if target_id == "blocked_m": blocked_hit = true
	check.call(open_hit and not blocked_hit, "Wall blocks line of sight in area target discovery: open monster hit, obstructed monster excluded")
	wall_grid.free()

	# B1: Multi-target area suspension and exact resumption without dropping remaining actors
	var area_susp_target_a := {"name": "Target A", "current_hp": 100, "max_hp": 100, "is_alive": true, "ability_scores": {"DEX": -100}, "conditions": {}}
	var area_susp_target_b := {"name": "Target B", "current_hp": 100, "max_hp": 100, "is_alive": true, "ability_scores": {"DEX": -100}, "conditions": {}}
	var area_susp_spell := {
		"id": "sandbox:area_susp",
		"name": "Area Susp",
		"execution": "shared",
		"level": 1,
		"range": 6,
		"steps": [{"id": "s1", "type": "save", "save": "DEX", "target": "area", "shape": "sphere", "radius": 2, "damage": "2d6", "damage_type": "fire"}]
	}
	var sorc_area := Character.new()
	sorc_area.initialize("Area Sorc", "human", "sorcerer", AbilityScores.new())
	sorc_area.character_id = "sorc-area"
	sorc_area.sorcerer_metamagic_choices.append("empowered_spell")
	sorc_area.features.append({"id": "sorcerer_metamagic"})
	sorc_area.feature_uses["sorcery_points"] = 3
	sorc_area.spell_slots["1"] = 3

	var area_susp_decisions := {
		"area_targets": [area_susp_target_a, area_susp_target_b],
		"metamagic:empowered": true,
		"defer_empowered": true,
		"spell_damage_context": {}
	}
	FighterChecks._seed_die(20, 10)
	var area_susp_cast := CombatAction.resolve_spell(sorc_area, area_susp_target_a, area_susp_spell, true, area_susp_decisions, [], 1, 5)
	check.call(area_susp_cast.has("damage_request"), "Multi-target area cast suspends at first target damage request")
	var area_cont: Dictionary = area_susp_cast.get("ordered_continuation", {})
	check.call(area_cont.get("target_index") == 0 and area_cont.get("pending_target") == area_susp_target_a, "Continuation records target A at target_index 0")

	var area_reroll_decisions := {"metamagic:empowered": true, "metamagic:empowered_dice": [0]}
	var area_resumed := CombatAction.finish_pending_spell_damage(sorc_area, area_susp_target_a, area_susp_cast, area_reroll_decisions)
	check.call(not area_resumed.has("damage_request"), "Resuming area cast finishes without pending damage request")
	check.call(int(area_susp_target_a["current_hp"]) < 100 and int(area_susp_target_b["current_hp"]) < 100, "Exact continuation executes remaining area targets: both Target A and Target B take damage")
	check.call(area_resumed.get("step_results", [])[0]["target_outcomes"].size() == 2, "Both target outcomes are preserved in step results")

	# B1: Post-resume condition grant applies once on settled failed save
	var grant_target := {"name": "Grant Target", "current_hp": 100, "max_hp": 100, "is_alive": true, "ability_scores": {"DEX": -100}, "conditions": {}}
	var grant_spell := {
		"id": "sandbox:grant_spell",
		"name": "Grant Spell",
		"execution": "shared",
		"level": 1,
		"range": 6,
		"duration_seconds": 60,
		"steps": [{"id": "s1", "type": "save", "save": "DEX", "damage": "2d6", "damage_type": "poison", "effects": [{"type": "grant_condition", "condition": "poisoned", "on_failed_save": true}]}]
	}
	sorc_area.spell_slots["1"] = 3
	var grant_susp := CombatAction.resolve_spell(sorc_area, grant_target, grant_spell, true, {"metamagic:empowered": true, "defer_empowered": true}, [], 1, 5)
	check.call(grant_susp.has("damage_request") and not CombatAction.has_condition(grant_target, "poisoned"), "Suspended save does not grant condition before damage settlement")
	var grant_resumed := CombatAction.finish_pending_spell_damage(sorc_area, grant_target, grant_susp, {"metamagic:empowered": true, "metamagic:empowered_dice": []})
	check.call(CombatAction.has_condition(grant_target, "poisoned"), "Resumed save grants failed-save condition once after damage settlement")
	# Idempotent replay:
	CombatAction.finish_pending_spell_damage(sorc_area, grant_target, grant_resumed, {})
	check.call(CombatAction.has_condition(grant_target, "poisoned"), "Duplicate replay does not corrupt condition")

	# B1: Empowered multi-roll budget spends 1 SP once and tracks remaining dice allowance across rolls
	var multi_sorc := Character.new()
	multi_sorc.initialize("Multi Sorc", "human", "sorcerer", AbilityScores.new())
	multi_sorc.character_id = "multi-sorc"
	multi_sorc.ability_scores.charisma = 14
	multi_sorc.sorcerer_metamagic_choices.append("empowered_spell")
	multi_sorc.features.append({"id": "sorcerer_metamagic"})
	multi_sorc.feature_uses["sorcery_points"] = 3
	var empower_decisions := {"metamagic:empowered": true, "metamagic:empowered_dice": [0]}
	var roll1_details := {"dice_terms": [{"sides": 6, "results": [1, 2], "kept": [true, true], "count": 2, "subtotal": 3}], "final_total": 3}
	var emp_res1 := SpellDamageRolls._apply_empowered_spell(multi_sorc, roll1_details, empower_decisions)
	check.call(emp_res1["used"] and int(multi_sorc.feature_uses["sorcery_points"]) == 2 and int(empower_decisions["empowered_remaining_dice"]) == 1 and bool(empower_decisions["empowered_sp_spent"]) == true, "First roll spends 1 SP and decreases die allowance from 2 to 1")

	empower_decisions["metamagic:empowered_dice"] = [0]
	var roll2_details := {"dice_terms": [{"sides": 6, "results": [1, 3], "kept": [true, true], "count": 2, "subtotal": 4}], "final_total": 4}
	var emp_res2 := SpellDamageRolls._apply_empowered_spell(multi_sorc, roll2_details, empower_decisions)
	check.call(emp_res2["used"] and int(multi_sorc.feature_uses["sorcery_points"]) == 2 and int(empower_decisions["empowered_remaining_dice"]) == 0, "Second roll uses remaining allowance of 1 without charging additional SP (total SP spent = 1)")

	empower_decisions["metamagic:empowered_dice"] = [0]
	check.call(not SpellDamageRolls._can_empower(multi_sorc, empower_decisions), "Allowance exhausted prevents further Empowered rerolls on subsequent rolls")

	# =========================================================================
	# B1R1 Deterministic Production Tests
	# =========================================================================

	# B1R1 Test 1: Pending result copied before settlement and replayed after settlement is refused
	var b1r1_sorc := Character.new()
	b1r1_sorc.initialize("B1R1 Sorcerer", "human", "sorcerer", AbilityScores.new())
	b1r1_sorc.character_id = "b1r1-sorc"
	b1r1_sorc.sorcerer_metamagic_choices.append("empowered_spell")
	b1r1_sorc.features.append({"id": "sorcerer_metamagic"})
	b1r1_sorc.feature_uses["sorcery_points"] = 3
	b1r1_sorc.spell_slots["1"] = 3
	var b1r1_target := {"id": "b1r1_t1", "name": "B1R1 Target", "current_hp": 100, "max_hp": 100, "is_alive": true, "armor_class": -100, "conditions": {}, "ability_scores": {"DEX": -100}}

	FighterChecks._seed_die(20, 10)
	var susp1 := CombatAction.resolve_spell(b1r1_sorc, b1r1_target, empower_spell, true, {"metamagic:empowered": true, "defer_empowered": true}, [], 1, 5)
	check.call(susp1.has("damage_request"), "B1R1: Cast suspends with damage request")
	var copy_before_settle := susp1.duplicate(true)

	# Legitimate settlement:
	var settle_decisions := {"metamagic:empowered": true, "metamagic:empowered_dice": [0]}
	var valid_resumed := CombatAction.finish_pending_spell_damage(b1r1_sorc, b1r1_target, susp1, settle_decisions)
	check.call(not valid_resumed.has("damage_request") and int(b1r1_sorc.feature_uses["sorcery_points"]) == 2, "B1R1: Valid settlement charges 1 SP and completes")
	var hp_after_settle: int = int(b1r1_target["current_hp"])
	check.call(hp_after_settle < 100, "B1R1: Target took damage on valid settlement")

	# Replay copied pending result after valid settlement:
	var replay_res := CombatAction.finish_pending_spell_damage(b1r1_sorc, b1r1_target, copy_before_settle, settle_decisions)
	check.call(bool(replay_res.get("refused", false)) == true, "B1R1: Copied pending result replayed after settlement is refused")
	check.call(int(b1r1_sorc.feature_uses["sorcery_points"]) == 2, "B1R1: Copied replay does not spend additional Sorcery Points")
	check.call(int(b1r1_target["current_hp"]) == hp_after_settle, "B1R1: Copied replay does not reapply damage")

	# B1R1 Test 2: Replay of an older request while a newer request is outstanding is refused as stale; newer request remains valid
	var b1r1_target2 := {"id": "b1r1_t2", "name": "B1R1 Target 2", "current_hp": 100, "max_hp": 100, "is_alive": true, "armor_class": -100, "conditions": {}, "ability_scores": {"DEX": -100}}
	FighterChecks._seed_die(20, 10)
	var req1_cast := CombatAction.resolve_spell(b1r1_sorc, b1r1_target, empower_spell, true, {"metamagic:empowered": true, "defer_empowered": true}, [], 1, 5)
	check.call(req1_cast.has("damage_request"), "B1R1: First request opened")

	FighterChecks._seed_die(20, 10)
	var req2_cast := CombatAction.resolve_spell(b1r1_sorc, b1r1_target2, empower_spell, true, {"metamagic:empowered": true, "defer_empowered": true}, [], 1, 5)
	check.call(req2_cast.has("damage_request"), "B1R1: Second request opened (now outstanding)")

	# Attempt to answer older req1_cast while req2_cast is outstanding:
	var points_before_stale: int = int(b1r1_sorc.feature_uses["sorcery_points"])
	var hp1_before: int = int(b1r1_target["current_hp"])
	var stale_replay := CombatAction.finish_pending_spell_damage(b1r1_sorc, b1r1_target, req1_cast, settle_decisions)
	check.call(bool(stale_replay.get("refused", false)) == true, "B1R1: Replaying older request while later request is outstanding is refused as stale")
	check.call(int(b1r1_sorc.feature_uses["sorcery_points"]) == points_before_stale and int(b1r1_target["current_hp"]) == hp1_before, "B1R1: Stale replay does not mutate SP or target HP")

	# Outstanding req2_cast remains legitimate and available to answer:
	var req2_settled := CombatAction.finish_pending_spell_damage(b1r1_sorc, b1r1_target2, req2_cast, settle_decisions)
	check.call(req2_settled.get("success", false) and not req2_settled.has("damage_request"), "B1R1: Outstanding newer request settles successfully after stale callback refusal")
	check.call(int(b1r1_target2["current_hp"]) < 100, "B1R1: Outstanding request target took damage")

	# B1R1 Test 3: Wrong caster/request/actor and missing actor refuse before mutation, leaving legitimate request available
	var other_caster := Character.new()
	other_caster.initialize("Other Caster", "human", "wizard", AbilityScores.new())
	other_caster.character_id = "other-caster"

	var wrong_target := {"id": "wrong_t", "name": "Wrong Target", "current_hp": 100, "max_hp": 100, "is_alive": true, "armor_class": -100}
	var b1r1_target3 := {"id": "b1r1_t3", "name": "B1R1 Target 3", "current_hp": 100, "max_hp": 100, "is_alive": true, "armor_class": -100, "conditions": {}, "ability_scores": {"DEX": -100}}
	b1r1_sorc.spell_slots["1"] = 3
	b1r1_sorc.feature_uses["sorcery_points"] = 3
	FighterChecks._seed_die(20, 10)
	var pending_auth := CombatAction.resolve_spell(b1r1_sorc, b1r1_target3, empower_spell, true, {"metamagic:empowered": true, "defer_empowered": true}, [], 1, 5)

	# 3a. Wrong caster:
	var wrong_c_res := CombatAction.finish_pending_spell_damage(other_caster, b1r1_target3, pending_auth, settle_decisions)
	check.call(bool(wrong_c_res.get("refused", false)) == true, "B1R1: Wrong caster refuses before mutation")
	check.call(int(b1r1_sorc.feature_uses["sorcery_points"]) == 3 and int(b1r1_target3["current_hp"]) == 100, "B1R1: Wrong caster does not charge SP or damage target")

	# 3b. Wrong actor:
	var wrong_a_res := CombatAction.finish_pending_spell_damage(b1r1_sorc, wrong_target, pending_auth, settle_decisions)
	check.call(bool(wrong_a_res.get("refused", false)) == true, "B1R1: Wrong actor refuses before mutation")
	check.call(int(b1r1_sorc.feature_uses["sorcery_points"]) == 3 and int(b1r1_target3["current_hp"]) == 100, "B1R1: Wrong actor does not charge SP or damage target")

	# 3c. Missing actor (null):
	var missing_a_res := CombatAction.finish_pending_spell_damage(b1r1_sorc, null, pending_auth, settle_decisions)
	check.call(bool(missing_a_res.get("refused", false)) == true, "B1R1: Missing actor refuses before mutation")
	check.call(int(b1r1_sorc.feature_uses["sorcery_points"]) == 3 and int(b1r1_target3["current_hp"]) == 100, "B1R1: Missing actor does not charge SP or damage target")

	# 3d. Fake request ID:
	var fake_req_res := CombatAction.finish_pending_spell_damage(b1r1_sorc, b1r1_target3, {"damage_request": {"request_id": "fake_unregistered_id"}}, settle_decisions)
	check.call(bool(fake_req_res.get("refused", false)) == true, "B1R1: Fake unregistered request ID refuses before mutation")

	# Legitimate request was NOT consumed or damaged by the refused calls and can now be answered:
	var legit_auth_res := CombatAction.finish_pending_spell_damage(b1r1_sorc, b1r1_target3, pending_auth, settle_decisions)
	check.call(legit_auth_res.get("success", false) and int(b1r1_target3["current_hp"]) < 100 and int(b1r1_sorc.feature_uses["sorcery_points"]) == 2, "B1R1: Legitimate request settles cleanly after preceding refused attempts")

	# B1R1 Test 3e: a pending result deep-copied BEFORE its first answer carries a detached Dictionary actor
	var make_empower_sorc := func(label: String, id: String) -> Character:
		var made := Character.new()
		made.initialize(label, "human", "sorcerer", AbilityScores.new())
		made.character_id = id
		made.sorcerer_metamagic_choices.append("empowered_spell")
		made.features.append({"id": "sorcerer_metamagic"})
		made.feature_uses["sorcery_points"] = 3
		made.spell_slots["1"] = 5
		return made
	var own_sorc: Character = make_empower_sorc.call("Owner Sorc", "owner-sorc")
	var own_target := {"id": "own_t", "name": "Owner Target", "current_hp": 100, "max_hp": 100, "is_alive": true, "armor_class": -100, "conditions": {}, "ability_scores": {"DEX": -100}}
	FighterChecks._seed_die(20, 10)
	var own_pending := CombatAction.resolve_spell(own_sorc, own_target, empower_spell, true, {"metamagic:empowered": true, "defer_empowered": true}, [], 1, 5)
	check.call(own_pending.has("damage_request"), "B1R1: Owner request opened for copy-before-answer case")
	var own_copy: Dictionary = own_pending.duplicate(true)
	var detached_target: Dictionary = own_copy["ordered_continuation"]["pending_target"]
	check.call(not is_same(detached_target, own_target), "B1R1: Deep copy before first answer detaches the Dictionary actor")
	var own_reroll := {"metamagic:empowered": true, "metamagic:empowered_dice": [0]}
	var detached_answer := CombatAction.finish_pending_spell_damage(own_sorc, detached_target, own_copy, own_reroll)
	check.call(bool(detached_answer.get("refused", false)) and int(detached_target["current_hp"]) == 100 and int(own_target["current_hp"]) == 100 and int(own_sorc.feature_uses["sorcery_points"]) == 3, "B1R1: Copied first answer holding the detached actor refuses without damaging the copy, the original actor, or Sorcery Points")
	var own_original_total: int = int(own_pending["damage_request"]["details"]["final_total"]) + int(own_pending["damage_request"]["bonus"])
	var original_after_refusal := CombatAction.finish_pending_spell_damage(own_sorc, own_target, own_pending, {"metamagic:empowered": true, "metamagic:empowered_dice": []})
	check.call(int(own_target["current_hp"]) == 100 - own_original_total and int(own_sorc.feature_uses["sorcery_points"]) == 3 and original_after_refusal.get("suspended_step") == 1, "B1R1: Refused copied answer left the original request usable: original damage applied once, no charge, and its later legitimate prompt opens")
	# Fresh request for the settle-from-copy case, with a payload that tries to replace roll/scale/step.
	var copy_sorc: Character = make_empower_sorc.call("Copy Sorc", "copy-sorc")
	var copy_target := {"id": "copy_t", "name": "Copy Target", "current_hp": 100, "max_hp": 100, "is_alive": true, "armor_class": -100, "conditions": {}, "ability_scores": {"DEX": -100}}
	FighterChecks._seed_die(20, 10)
	var copy_pending := CombatAction.resolve_spell(copy_sorc, copy_target, empower_spell, true, {"metamagic:empowered": true, "defer_empowered": true}, [], 1, 5)
	var tampered_copy: Dictionary = copy_pending.duplicate(true)
	var copy_detached_target: Dictionary = tampered_copy["ordered_continuation"]["pending_target"]
	tampered_copy["damage_request"]["details"]["final_total"] = 999
	tampered_copy["damage_request"]["scale"] = 5.0
	tampered_copy["damage_request"]["damage_type"] = "psychic"
	tampered_copy["ordered_continuation"]["step_index"] = 1
	tampered_copy["ordered_continuation"]["step"] = {"id": "forged", "type": "damage", "damage": "50", "damage_type": "psychic"}
	var copy_settled := CombatAction.finish_pending_spell_damage(copy_sorc, copy_target, tampered_copy, {"metamagic:empowered": true, "metamagic:empowered_dice": [0]})
	var copy_loss: int = 100 - int(copy_target["current_hp"])
	check.call(copy_settled.get("success", false) and not copy_settled.has("damage_request") and copy_settled.get("step_results", []).size() == 2, "B1R1: Copied first answer settles the canonical recorded request and completes its own steps")
	check.call(copy_loss >= 1 and copy_loss <= 22 and int(copy_detached_target["current_hp"]) == 100, "B1R1: Tampered copy payload cannot replace the rolled damage/scale/type; only the canonical actor (not the detached copy) is damaged")
	check.call(int(copy_sorc.feature_uses["sorcery_points"]) == 2, "B1R1: Copied first answer charges one Sorcery Point once")
	var copy_original_replay := CombatAction.finish_pending_spell_damage(copy_sorc, copy_target, copy_pending, {"metamagic:empowered": true, "metamagic:empowered_dice": [0]})
	check.call(bool(copy_original_replay.get("refused", false)) and 100 - int(copy_target["current_hp"]) == copy_loss and int(copy_sorc.feature_uses["sorcery_points"]) == 2, "B1R1: Original replayed after the copy settled it is refused and changes nothing")

	# B1R1 Test 3f: actual host/actor validity, not matching IDs
	var host_sorc: Character = make_empower_sorc.call("Host Sorc", "host-sorc")
	var host_monster := {"id": "host_m", "name": "Host Monster", "hex_position": Vector2i(1, 0), "current_hp": 100, "max_hp": 100, "is_alive": true, "armor_class": -100, "conditions": {}, "ability_scores": {"DEX": -100}}
	var host_monsters: Array = [host_monster]
	var host_players: Array = [{"character": host_sorc, "hex_position": Vector2i(0, 0)}]
	FighterChecks._seed_die(20, 10)
	var host_pending := CombatAction.resolve_spell(host_sorc, host_monster, empower_spell, true, {"metamagic:empowered": true, "defer_empowered": true, "players": host_players, "monsters": host_monsters}, [], 1, 5)
	check.call(host_pending.has("damage_request"), "B1R1: Request opened inside an encounter host")
	var host_reroll := {"metamagic:empowered": true, "metamagic:empowered_dice": [0]}
	host_monsters.clear()
	var removed_answer := CombatAction.finish_pending_spell_damage(host_sorc, host_monster, host_pending, host_reroll)
	check.call(bool(removed_answer.get("refused", false)) and int(host_monster["current_hp"]) == 100 and int(host_sorc.feature_uses["sorcery_points"]) == 3, "B1R1: Removed actor passed as the old non-null reference refuses before damage or cost")
	var replacement_monster: Dictionary = host_monster.duplicate(true)
	host_monsters.append(replacement_monster)
	var replaced_answer := CombatAction.finish_pending_spell_damage(host_sorc, host_monster, host_pending, host_reroll)
	var replaced_by_copy_answer := CombatAction.finish_pending_spell_damage(host_sorc, replacement_monster, host_pending, host_reroll)
	check.call(bool(replaced_answer.get("refused", false)) and bool(replaced_by_copy_answer.get("refused", false)) and int(host_monster["current_hp"]) == 100 and int(replacement_monster["current_hp"]) == 100 and int(host_sorc.feature_uses["sorcery_points"]) == 3, "B1R1: Same-ID replacement actor in the encounter is neither the old actor's valid host nor the recorded actor; both refuse unchanged")
	host_monsters.clear()
	host_monsters.append(host_monster)
	var host_settled := CombatAction.finish_pending_spell_damage(host_sorc, host_monster, host_pending, host_reroll)
	check.call(host_settled.get("success", false) and int(host_monster["current_hp"]) < 100 and int(host_sorc.feature_uses["sorcery_points"]) == 2, "B1R1: Refusals did not consume the request; it settles once the recorded actor is genuinely present")
	var caster_host_sorc: Character = make_empower_sorc.call("Caster Host Sorc", "caster-host-sorc")
	var caster_host_target := {"id": "caster_host_t", "name": "Caster Host Target", "hex_position": Vector2i(1, 0), "current_hp": 100, "max_hp": 100, "is_alive": true, "armor_class": -100, "conditions": {}, "ability_scores": {"DEX": -100}}
	var caster_players: Array = [{"character": caster_host_sorc, "hex_position": Vector2i(0, 0)}]
	FighterChecks._seed_die(20, 10)
	var caster_host_pending := CombatAction.resolve_spell(caster_host_sorc, caster_host_target, empower_spell, true, {"metamagic:empowered": true, "defer_empowered": true, "players": caster_players, "monsters": [caster_host_target]}, [], 1, 5)
	caster_players.clear()
	var removed_caster_answer := CombatAction.finish_pending_spell_damage(caster_host_sorc, caster_host_target, caster_host_pending, host_reroll)
	check.call(bool(removed_caster_answer.get("refused", false)) and int(caster_host_target["current_hp"]) == 100 and int(caster_host_sorc.feature_uses["sorcery_points"]) == 3, "B1R1: Caster removed from the encounter host refuses before damage or cost")

	# B1R1 Test 3g: encounter/session reset invalidates callbacks and request IDs never alias
	var reset_sorc: Character = make_empower_sorc.call("Reset Sorc", "reset-sorc")
	var reset_target := {"id": "reset_t", "name": "Reset Target", "current_hp": 100, "max_hp": 100, "is_alive": true, "armor_class": -100, "conditions": {}, "ability_scores": {"DEX": -100}}
	FighterChecks._seed_die(20, 10)
	var reset_old := CombatAction.resolve_spell(reset_sorc, reset_target, empower_spell, true, {"metamagic:empowered": true, "defer_empowered": true}, [], 1, 5)
	SpellDamageRolls.clear_pending_requests()
	var reset_old_answer := CombatAction.finish_pending_spell_damage(reset_sorc, reset_target, reset_old, host_reroll)
	check.call(bool(reset_old_answer.get("refused", false)) and int(reset_target["current_hp"]) == 100 and int(reset_sorc.feature_uses["sorcery_points"]) == 3, "B1R1: Callback answered after the encounter reset refuses before damage or cost")
	FighterChecks._seed_die(20, 10)
	var reset_fresh := CombatAction.resolve_spell(reset_sorc, reset_target, empower_spell, true, {"metamagic:empowered": true, "defer_empowered": true}, [], 1, 5)
	check.call(reset_fresh.has("damage_request") and str(reset_fresh["damage_request"]["request_id"]) != str(reset_old["damage_request"]["request_id"]), "B1R1: Reopened request for the same caster and actor gets a new ID instead of aliasing the cleared one")
	var reset_old_again := CombatAction.finish_pending_spell_damage(reset_sorc, reset_target, reset_old, host_reroll)
	check.call(bool(reset_old_again.get("refused", false)) and int(reset_target["current_hp"]) == 100, "B1R1: Old callback still refuses after a fresh request for the same caster/actor exists")
	var reset_fresh_settled := CombatAction.finish_pending_spell_damage(reset_sorc, reset_target, reset_fresh, host_reroll)
	check.call(reset_fresh_settled.get("success", false) and int(reset_target["current_hp"]) < 100 and int(reset_sorc.feature_uses["sorcery_points"]) == 2, "B1R1: Fresh current request remains answerable after the reset")

	# B1R1 Test 4: Initial pending attack followed by real encounter area discovery using a minimal UI answer
	var grid := HexGrid.new()
	for coord in HexUtils.get_hexes_in_range(Vector2i.ZERO, 15):
		var tile := HexTile.new()
		tile.coord = coord
		grid.add_tile(tile)
	var enc_sorc := Character.new()
	enc_sorc.initialize("Encounter Sorc", "human", "sorcerer", AbilityScores.new())
	enc_sorc.character_id = "enc-sorc"
	enc_sorc.sorcerer_metamagic_choices.append("empowered_spell")
	enc_sorc.features.append({"id": "sorcerer_metamagic"})
	enc_sorc.feature_uses["sorcery_points"] = 3
	enc_sorc.spell_slots["1"] = 3

	var enc_primary := Character.new()
	enc_primary.initialize("Primary Foe", "human", "fighter", AbilityScores.new())
	enc_primary.character_id = "primary-foe"
	enc_primary.current_hp = 100
	enc_primary.max_hp = 100

	var enc_monster := {"id": "enc_mon_1", "name": "Area Goblin", "hex_position": Vector2i(1, 1), "current_hp": 50, "max_hp": 50, "is_alive": true, "armor_class": 10, "conditions": {}, "ability_scores": {"DEX": -100}}
	var enc_far_monster := {"id": "enc_mon_far", "name": "Far Goblin", "hex_position": Vector2i(9, 9), "current_hp": 50, "max_hp": 50, "is_alive": true, "armor_class": 10, "conditions": {}, "ability_scores": {"DEX": -100}}

	var enc_players: Array = [
		{"character": enc_sorc, "hex_position": Vector2i(-6, 0)},
		{"character": enc_primary, "hex_position": Vector2i(1, 0)}
	]
	var enc_monsters: Array = [enc_monster, enc_far_monster]

	var atk_then_area_spell := {
		"id": "sandbox:atk_then_area",
		"name": "Attack Then Area",
		"execution": "shared",
		"level": 1,
		"range": 10,
		"steps": [
			{"id": "step_atk", "type": "attack", "attack_type": "ranged_spell", "damage": "1d6", "damage_type": "fire"},
			{"id": "step_area", "type": "save", "save": "DEX", "target": "area", "shape": "sphere", "radius": 2, "damage": "2d6", "damage_type": "fire"}
		]
	}

	var enc_cast_decisions := {
		"grid": grid,
		"players": enc_players,
		"monsters": enc_monsters,
		"metamagic:empowered": true,
		"defer_empowered": true
	}
	FighterChecks._seed_die(20, 20) # Natural 20 always hits the Character target
	var enc_susp := CombatAction.resolve_spell(enc_sorc, enc_primary, atk_then_area_spell, true, enc_cast_decisions, [], 1, 5)
	check.call(enc_susp.has("damage_request") and enc_susp.get("suspended_step") == 0, "B1R1: Attack step suspends at step 0")
	var enc_primary_hp_before: int = enc_primary.current_hp

	# UI callback provides minimal answer with NO grid or monsters keys:
	var minimal_ui_answer := {"metamagic:empowered": true, "metamagic:empowered_dice": [0]}
	var enc_resumed := CombatAction.finish_pending_spell_damage(enc_sorc, enc_primary, enc_susp, minimal_ui_answer)
	check.call(enc_resumed.get("success", false) and not enc_resumed.has("damage_request"), "B1R1: Resumed attack with minimal UI answer completes all steps")
	check.call(enc_primary.current_hp < enc_primary_hp_before, "B1R1: Primary target took damage from step 0 attack")
	check.call(int(enc_monster["current_hp"]) < 50, "B1R1: Real encounter monster at (1,1) discovered by step 1 area save and took damage")
	check.call(int(enc_far_monster["current_hp"]) == 50, "B1R1: Distant monster at (9,9) outside radius 2 was not targeted")
	var enc_area_outcomes: Array = enc_resumed.get("step_results", [])[1].get("target_outcomes", []) if enc_resumed.get("step_results", []).size() > 1 else []
	var enc_area_live := false
	for area_outcome in enc_area_outcomes:
		if is_same(area_outcome.get("target"), enc_monster):
			enc_area_live = true
	check.call(enc_area_live, "B1R1: Area step outcome references the live encounter monster Dictionary, not a copy")
	grid.free()

	# B1R1 Test 5: Secondary actor suspension without redirecting to the primary/first actor
	var sec_sorc := Character.new()
	sec_sorc.initialize("Secondary Sorc", "human", "sorcerer", AbilityScores.new())
	sec_sorc.character_id = "sec-sorc"
	sec_sorc.sorcerer_metamagic_choices.append("empowered_spell")
	sec_sorc.features.append({"id": "sorcerer_metamagic"})
	sec_sorc.feature_uses["sorcery_points"] = 3
	sec_sorc.spell_slots["1"] = 3

	# A saves step s1 (so the failed-save gate skips A at s2); B fails s1 and is the first/only actor rolling s2.
	var sec_target_a := {"id": "sec_a", "name": "Target A First", "current_hp": 100, "max_hp": 100, "is_alive": true, "conditions": {}, "ability_scores": {"DEX": 100, "CON": -100}}
	var sec_target_b := {"id": "sec_b", "name": "Target B Secondary", "current_hp": 100, "max_hp": 100, "is_alive": true, "conditions": {}, "ability_scores": {"DEX": -100, "CON": -100}}

	var area_save_spell := {
		"id": "sandbox:sec_area_spell",
		"name": "Secondary Area Spell",
		"execution": "shared",
		"level": 1,
		"range": 10,
		"steps": [
			{"id": "s1", "type": "save", "save": "DEX", "target": "area", "shape": "sphere", "radius": 2},
			{"id": "s2", "type": "save", "save": "CON", "target": "area", "shape": "sphere", "radius": 2, "gate": "failed_save", "gate_step": "s1", "damage": "2d6", "damage_type": "fire"}
		]
	}

	FighterChecks._seed_die(20, 10)
	var sec_susp := CombatAction.resolve_spell(sec_sorc, sec_target_a, area_save_spell, true, {"area_targets": [sec_target_a, sec_target_b], "metamagic:empowered": true, "defer_empowered": true}, [], 1, 5)
	check.call(sec_susp.has("damage_request") and sec_susp.get("suspended_step") == 1, "B1R1: Area step suspends on the gated step")
	var sec_cont: Dictionary = sec_susp.get("ordered_continuation", {})
	check.call(sec_cont.get("target_index") == 1 and is_same(sec_cont.get("pending_target"), sec_target_b), "B1R1: Secondary target B (not first target A) is pending at target_index 1")
	check.call(int(sec_target_a["current_hp"]) == 100 and int(sec_target_b["current_hp"]) == 100 and int(sec_sorc.feature_uses["sorcery_points"]) == 3, "B1R1: Nothing is damaged or charged while the secondary actor's request is open")

	# Wrong actor: passing first target A when secondary target B is pending must refuse before any mutation:
	var wrong_sec_res := CombatAction.finish_pending_spell_damage(sec_sorc, sec_target_a, sec_susp, {"metamagic:empowered": true, "metamagic:empowered_dice": [0]})
	check.call(bool(wrong_sec_res.get("refused", false)) and int(sec_target_a["current_hp"]) == 100 and int(sec_target_b["current_hp"]) == 100 and int(sec_sorc.feature_uses["sorcery_points"]) == 3, "B1R1: Passing first target A when secondary target B is pending refuses without redirecting damage or charging")

	# Valid settlement on secondary target B:
	var sec_good_res := CombatAction.finish_pending_spell_damage(sec_sorc, sec_target_b, sec_susp, {"metamagic:empowered": true, "metamagic:empowered_dice": [0]})
	check.call(sec_good_res.get("success", false) and not sec_good_res.has("damage_request") and int(sec_target_b["current_hp"]) < 100 and int(sec_sorc.feature_uses["sorcery_points"]) == 2, "B1R1: Secondary target B settles once, takes damage, and the cast is charged once")
	check.call(int(sec_target_a["current_hp"]) == 100, "B1R1: First target A was not redirected or damaged")
	var sec_s2_outcomes: Array = sec_good_res.get("step_results", [])[1].get("target_outcomes", []) if sec_good_res.get("step_results", []).size() > 1 else []
	check.call(sec_s2_outcomes.size() == 2 and bool(sec_s2_outcomes[0].get("skipped", false)) and not bool(sec_s2_outcomes[1].get("skipped", false)) and is_same(sec_s2_outcomes[1].get("target"), sec_target_b), "B1R1: Step s2 records A skipped by the gate and B settled against the live B Dictionary")

	# B1R1 Test 6: One raw area roll shared with differing saves across suspension
	var raw_sorc := Character.new()
	raw_sorc.initialize("Raw Area Sorc", "human", "sorcerer", AbilityScores.new())
	raw_sorc.character_id = "raw-sorc"
	raw_sorc.sorcerer_metamagic_choices.append("empowered_spell")
	raw_sorc.features.append({"id": "sorcerer_metamagic"})
	raw_sorc.feature_uses["sorcery_points"] = 3
	raw_sorc.spell_slots["1"] = 3

	var raw_target_a := {"id": "raw_a", "name": "Raw Target A (Fail)", "current_hp": 100, "max_hp": 100, "is_alive": true, "ability_scores": {"DEX": -100}}
	var raw_target_b := {"id": "raw_b", "name": "Raw Target B (Success)", "current_hp": 100, "max_hp": 100, "is_alive": true, "ability_scores": {"DEX": 100}}

	var raw_spell := {
		"id": "sandbox:raw_area_spell",
		"name": "Raw Area Spell",
		"execution": "shared",
		"level": 1,
		"range": 10,
		"steps": [
			{"id": "s1", "type": "save", "save": "DEX", "target": "area", "shape": "sphere", "radius": 2, "half_on_save": true, "damage": "2d6", "damage_type": "fire"}
		]
	}

	var raw_decisions := {
		"area_targets": [raw_target_a, raw_target_b],
		"metamagic:empowered": true,
		"defer_empowered": true,
		"spell_damage_context": {}
	}
	FighterChecks._seed_die(20, 10)
	var raw_susp := CombatAction.resolve_spell(raw_sorc, raw_target_a, raw_spell, true, raw_decisions, [], 1, 5)
	check.call(raw_susp.has("damage_request"), "B1R1: Raw area cast suspends on target A")

	var raw_resumed := CombatAction.finish_pending_spell_damage(raw_sorc, raw_target_a, raw_susp, {"metamagic:empowered": true, "metamagic:empowered_dice": [0]})
	check.call(raw_resumed.get("success", false) and not raw_resumed.has("damage_request"), "B1R1: Raw area cast finishes all targets")

	var raw_step_results: Array = raw_resumed.get("step_results", [])
	var outcomes: Array = raw_step_results[0].get("target_outcomes", []) if not raw_step_results.is_empty() and raw_step_results[0] is Dictionary else []
	check.call(outcomes.size() == 2, "B1R1: Both outcomes recorded")
	var dmg_a: int = int(outcomes[0]["damage"]) if outcomes.size() > 0 else 0
	var dmg_b: int = int(outcomes[1]["damage"]) if outcomes.size() > 1 else 0
	check.call(outcomes.size() >= 2 and outcomes[0].get("saved", true) == false and outcomes[1].get("saved", false) == true, "B1R1: Target A failed save while Target B succeeded save")
	check.call(dmg_a > 0 and dmg_b == int(floor(float(dmg_a) * 0.5)), "B1R1: Target A took full damage and Target B took exact half damage from single shared raw roll (%d vs %d)" % [dmg_a, dmg_b])

	# B1R1 Test 7: Live Dictionary actor references and later mutations
	var live_monster := {"id": "live_orc_99", "name": "Live Orc", "current_hp": 100, "max_hp": 100, "is_alive": true, "armor_class": 10, "ability_scores": {"DEX": 10}}
	var live_sorc := Character.new()
	live_sorc.initialize("Live Sorc", "human", "sorcerer", AbilityScores.new())
	live_sorc.character_id = "live-sorc"
	live_sorc.spell_slots["1"] = 3

	var live_spell := {
		"id": "sandbox:live_dict_spell",
		"name": "Live Dict Spell",
		"execution": "shared",
		"level": 1,
		"range": 10,
		"steps": [
			{"id": "s1", "type": "attack", "attack_type": "ranged_spell", "damage": "1d6", "damage_type": "fire"}
		]
	}
	FighterChecks._seed_die(20, 15)
	var live_result := CombatAction.resolve_spell(live_sorc, live_monster, live_spell, true, {}, [], 1, 5)
	var target_in_outcome = live_result["step_results"][0]["target_outcomes"][0]["target"]
	check.call(target_in_outcome == live_monster, "B1R1: Step outcome target matches live_monster reference")
	live_monster["current_hp"] = 42
	check.call(int(target_in_outcome["current_hp"]) == 42, "B1R1: Later mutation to live_monster is reflected through step outcome target")

	# B1R1 Test 8a: Suspended save -> attack summary retains attack hit after suspension
	var summary_sorc := Character.new()
	summary_sorc.initialize("Summary Sorc", "human", "sorcerer", AbilityScores.new())
	summary_sorc.character_id = "sum-sorc"
	summary_sorc.sorcerer_metamagic_choices.append("empowered_spell")
	summary_sorc.features.append({"id": "sorcerer_metamagic"})
	summary_sorc.feature_uses["sorcery_points"] = 3
	summary_sorc.spell_slots["1"] = 3

	var sum_target := {"id": "sum_t", "name": "Summary Target", "current_hp": 100, "max_hp": 100, "is_alive": true, "armor_class": 10, "ability_scores": {"DEX": 10}}
	var save_then_atk_susp := {
		"id": "sandbox:save_then_atk_susp",
		"name": "Save Then Attack Suspended",
		"execution": "shared",
		"level": 1,
		"range": 10,
		"steps": [
			{"id": "s1", "type": "save", "save": "DEX", "half_on_save": true, "damage": "1d4", "damage_type": "fire"},
			{"id": "s2", "type": "attack", "attack_type": "ranged_spell", "damage": "1d6", "damage_type": "fire"}
		]
	}
	FighterChecks._seed_die(20, 15)
	var sum_susp := CombatAction.resolve_spell(summary_sorc, sum_target, save_then_atk_susp, true, {"metamagic:empowered": true, "defer_empowered": true}, [], 1, 5)
	while sum_susp.has("damage_request"):
		FighterChecks._seed_die(20, 15)
		sum_susp = CombatAction.finish_pending_spell_damage(summary_sorc, sum_target, sum_susp, {"metamagic:empowered": true, "metamagic:empowered_dice": []})
	check.call(sum_susp.get("hit", false) == true, "B1R1: Suspended save -> attack summary accurately reports hit == true")

	# B1R1 Test 8b: Later attack miss does not overwrite first actual attack hit in summary
	summary_sorc.spell_slots["1"] = 3
	var atk_then_atk_spell := {
		"id": "sandbox:two_atks_spell",
		"name": "Two Attacks Spell",
		"execution": "shared",
		"level": 1,
		"range": 10,
		"steps": [
			{"id": "atk1", "type": "attack", "attack_type": "ranged_spell", "damage": "1d6", "damage_type": "fire"},
			{"id": "atk2", "type": "attack", "attack_type": "ranged_spell", "damage": "1d6", "damage_type": "fire"}
		]
	}
	FighterChecks._seed_die(20, 18)
	var two_atk_res := CombatAction.resolve_spell(summary_sorc, sum_target, atk_then_atk_spell, true, {"metamagic:empowered": true, "defer_empowered": true}, [], 1, 5)
	while two_atk_res.has("damage_request"):
		FighterChecks._seed_die(20, 2)
		two_atk_res = CombatAction.finish_pending_spell_damage(summary_sorc, sum_target, two_atk_res, {"metamagic:empowered": true, "metamagic:empowered_dice": []})
	check.call(two_atk_res.get("hit", false) == true, "B1R1: First actual attack hit stands in summary even when followed by a later attack miss")

	# B1R1 Test 9: Chained legitimate choices use remaining allowance, 1 SP once, and no die rerolled twice
	var chain_sorc := Character.new()
	chain_sorc.initialize("Chain Sorc", "human", "sorcerer", AbilityScores.new())
	chain_sorc.character_id = "chain-sorc"
	chain_sorc.ability_scores.charisma = 14
	chain_sorc.sorcerer_metamagic_choices.append("empowered_spell")
	chain_sorc.features.append({"id": "sorcerer_metamagic"})
	chain_sorc.feature_uses["sorcery_points"] = 3
	chain_sorc.spell_slots["1"] = 3

	var chain_target := {"id": "chain_t", "name": "Chain Target", "current_hp": 100, "max_hp": 100, "is_alive": true, "armor_class": -100, "ability_scores": {"DEX": -100}}
	var two_dmg_steps := {
		"id": "sandbox:two_dmg_steps",
		"name": "Two Damage Steps",
		"execution": "shared",
		"level": 1,
		"range": 10,
		"steps": [
			{"id": "d1", "type": "damage", "damage": "2d6", "damage_type": "fire"},
			{"id": "d2", "type": "damage", "damage": "2d6", "damage_type": "cold"}
		]
	}
	var chain_cast := CombatAction.resolve_spell(chain_sorc, chain_target, two_dmg_steps, true, {"metamagic:empowered": true, "defer_empowered": true}, [], 1, 5)
	check.call(chain_cast.has("damage_request") and chain_cast.get("suspended_step") == 0, "B1R1: First damage step suspends")
	check.call(int(chain_sorc.feature_uses["sorcery_points"]) == 3, "B1R1: SP uncharged before first choice")

	# Step 1 rerolls 1 die:
	var chain_res1 := CombatAction.finish_pending_spell_damage(chain_sorc, chain_target, chain_cast, {"metamagic:empowered": true, "metamagic:empowered_dice": [0]})
	check.call(chain_res1.has("damage_request") and chain_res1.get("suspended_step") == 1, "B1R1: Chained second damage step suspends")
	check.call(int(chain_sorc.feature_uses["sorcery_points"]) == 2, "B1R1: First choice spends 1 SP (3 -> 2)")

	# Step 2 rerolls 1 die (using remaining allowance of 1):
	var chain_res2 := CombatAction.finish_pending_spell_damage(chain_sorc, chain_target, chain_res1, {"metamagic:empowered": true, "metamagic:empowered_dice": [0]})
	check.call(chain_res2.get("success", false) and not chain_res2.has("damage_request"), "B1R1: Second choice finishes cast")
	check.call(int(chain_sorc.feature_uses["sorcery_points"]) == 2, "B1R1: Chained choice does not charge SP a second time (total 1 SP spent for the cast)")

	# Subsequent cast gets a fresh budget:
	chain_sorc.spell_slots["1"] = 3
	var fresh_cast := CombatAction.resolve_spell(chain_sorc, chain_target, two_dmg_steps, true, {"metamagic:empowered": true, "defer_empowered": true}, [], 1, 5)
	check.call(fresh_cast.has("damage_request"), "B1R1: Subsequent cast gets a fresh budget and suspends")
	var fresh_res := CombatAction.finish_pending_spell_damage(chain_sorc, chain_target, fresh_cast, {"metamagic:empowered": true, "metamagic:empowered_dice": [0]})
	check.call(int(chain_sorc.feature_uses["sorcery_points"]) == 1, "B1R1: Subsequent cast charges 1 SP for its own fresh metamagic use (2 -> 1)")
	var fresh_res2 := CombatAction.finish_pending_spell_damage(chain_sorc, chain_target, fresh_res, {"metamagic:empowered": true, "metamagic:empowered_dice": []})
	check.call(fresh_res2.get("success", false) and not fresh_res2.has("damage_request"), "B1R1: Subsequent cast finishes cleanly")

	# =========================================================================
	# Correction B1R2: Damage settlement and pre-payment host refusal
	# =========================================================================

	# B1R2 Test 1: Typed per-actor packet facts carried through result and outcomes
	var b1r2_caster := Character.new()
	b1r2_caster.initialize("B1R2 Caster", "human", "wizard", AbilityScores.new())
	b1r2_caster.character_id = "b1r2-caster"
	b1r2_caster.spell_slots["1"] = 3
	var b1r2_target := {"id": "b1r2_target", "name": "B1R2 Target", "current_hp": 30, "max_hp": 30, "temp_hp": 10, "is_alive": true, "armor_class": 10}
	var b1r2_damage_spell := {
		"id": "sandbox:b1r2_dmg",
		"name": "B1R2 Damage",
		"execution": "shared",
		"level": 1,
		"range": 10,
		"steps": [
			{"id": "s1", "type": "damage", "damage": "25", "damage_type": "fire"}
		]
	}
	var b1r2_res := CombatAction.resolve_spell(b1r2_caster, b1r2_target, b1r2_damage_spell, false, {}, [], 1, 5)
	check.call(b1r2_res.get("resolved") == 25 and b1r2_res.get("temp_hp_absorbed") == 10 and b1r2_res.get("hp_loss") == 15 and b1r2_res.get("damage") == 15 and b1r2_res.get("hp_before") == 30 and b1r2_res.get("hp_after") == 15 and b1r2_res.get("temp_hp_before") == 10 and b1r2_res.get("temp_hp_after") == 0 and b1r2_res.get("is_alive_before") == true and b1r2_res.get("is_alive_after") == true, "B1R2: Result carries typed packet facts (resolved, temp_hp_absorbed, hp_loss, before/after HP and Temp HP)")
	var b1r2_step_outcomes: Array = b1r2_res.get("step_results", [])[0].get("target_outcomes", [])
	check.call(not b1r2_step_outcomes.is_empty() and b1r2_step_outcomes[0].get("resolved") == 25 and b1r2_step_outcomes[0].get("temp_hp_absorbed") == 10 and b1r2_step_outcomes[0].get("hp_loss") == 15, "B1R2: Step target outcome carries typed per-actor packet facts")

	# B1R2 Test 2: Ordered settlement counterexample (Shield of Faith concentration stripped by Step 0 allows Step 1 attack to hit)
	var b1r2_faith_caster := Character.new()
	b1r2_faith_caster.initialize("Faith Caster", "human", "cleric", AbilityScores.new())
	b1r2_faith_caster.character_id = "faith-caster"
	b1r2_faith_caster.current_hp = 30
	b1r2_faith_caster.max_hp = 30
	b1r2_faith_caster.ability_scores.constitution = 10
	b1r2_faith_caster.base_ac = 13
	b1r2_faith_caster.add_condition("shield_of_faith", 100)
	b1r2_faith_caster.concentrating_on = {
		"spell_id": "shield_of_faith",
		"targets": [b1r2_faith_caster],
		"duration_rounds_remaining": 100
	}
	check.call(b1r2_faith_caster.get_ac() == 15, "B1R2: Initial AC is 15 with Shield of Faith")

	var b1r2_counter_spell := {
		"id": "sandbox:b1r2_counter",
		"name": "B1R2 Counterexample",
		"execution": "shared",
		"level": 1,
		"range": 10,
		"steps": [
			{"id": "atk1", "type": "attack", "attack_type": "ranged_spell", "damage": "10", "damage_type": "fire"},
			{"id": "atk2", "type": "attack", "attack_type": "ranged_spell", "damage": "10", "damage_type": "fire"}
		]
	}
	var b1r2_attacker := Character.new()
	b1r2_attacker.initialize("Attacker", "human", "wizard", AbilityScores.new())
	b1r2_attacker.character_id = "attacker-char"
	b1r2_attacker.ability_scores.intelligence = 10
	# Seed attack 1 (hits 15), CON save (fails DC 10), attack 2 (hits reduced AC 13, misses 15)
	for candidate in 50000:
		seed(candidate)
		var r1 := randi_range(1, 20)
		var r2 := randi_range(1, 20)
		var r3 := randi_range(1, 20)
		if r1 >= 13 and r2 <= 9 and (r3 + 2 == 13):
			seed(candidate)
			break
	var counter_res := CombatAction.resolve_spell(b1r2_attacker, b1r2_faith_caster, b1r2_counter_spell, false, {}, [], 1, 5)
	check.call(counter_res.get("step_results", []).size() == 2, "B1R2: Counterexample executes both attack steps")
	var s0_hit: bool = bool(counter_res["step_results"][0]["target_outcomes"][0]["hit"])
	var s1_hit: bool = bool(counter_res["step_results"][1]["target_outcomes"][0]["hit"])
	check.call(s0_hit and s1_hit and not b1r2_faith_caster.has_condition("shield_of_faith") and b1r2_faith_caster.concentrating_on.is_empty(), "B1R2 Counterexample: Step 0 damage ends Shield of Faith concentration; Step 1 hits against reduced AC (13 vs 13)")

	# B1R2 Test 3: Concentration DC rules:
	var b1r2_conc_char := Character.new()
	b1r2_conc_char.initialize("Conc Char", "human", "wizard", AbilityScores.new())
	b1r2_conc_char.current_hp = 50
	b1r2_conc_char.max_hp = 50
	b1r2_conc_char.temp_hp = 10
	b1r2_conc_char.ability_scores.constitution = 30
	b1r2_conc_char.concentrating_on = {"spell_id": "bless", "targets": [b1r2_conc_char]}
	FighterChecks._seed_die(20, 4)
	await SpellEncounterLifecycle._check_concentration_save(null, b1r2_conc_char, 30)
	check.call(b1r2_conc_char.concentrating_on.is_empty(), "B1R2: Temp 10 / damage 30 tests DC 15 (failed save ends concentration)")

	b1r2_conc_char.concentrating_on = {"spell_id": "bless", "targets": [b1r2_conc_char]}
	FighterChecks._seed_die(20, 20)
	await SpellEncounterLifecycle._check_concentration_save(null, b1r2_conc_char, 70)
	check.call(not b1r2_conc_char.concentrating_on.is_empty(), "B1R2: Damage 70 caps at DC 30 (roll 20 + 10 = 30 maintains concentration)")

	b1r2_conc_char.ability_scores.constitution = 10
	b1r2_conc_char.temp_hp = 20
	b1r2_conc_char.concentrating_on = {"spell_id": "bless", "targets": [b1r2_conc_char]}
	FighterChecks._seed_die(20, 5)
	await SpellEncounterLifecycle._check_concentration_save(null, b1r2_conc_char, 10)
	check.call(b1r2_conc_char.concentrating_on.is_empty(), "B1R2: Buffer-only damage (10 dmg absorbed by 20 TempHP) still rolls DC 10 save")

	b1r2_conc_char.concentrating_on = {"spell_id": "bless", "targets": [b1r2_conc_char]}
	await SpellEncounterLifecycle._check_concentration_save(null, b1r2_conc_char, 0)
	check.call(not b1r2_conc_char.concentrating_on.is_empty(), "B1R2: 0 damage untouched, maintains concentration without roll")

	b1r2_conc_char.add_condition("incapacitated", 2)
	await SpellEncounterLifecycle._check_concentration_save(null, b1r2_conc_char, 5)
	check.call(b1r2_conc_char.concentrating_on.is_empty(), "B1R2: Incapacitated ends concentration immediately")
	b1r2_conc_char.remove_condition("incapacitated")

	# B1R2 Test 4: Defeated Dictionary monster already marked is_alive=false is removed from initiative and defeat callback fires once
	var defeat_cb_calls: Array = []
	var test_defeat_cb := func(monster, killer):
		defeat_cb_calls.append({"monster_id": str(monster.get("id")), "killer": killer})
	var b1r2_mon := {"id": "b1r2_mon_dead", "name": "B1R2 Dead Monster", "current_hp": 10, "max_hp": 10, "is_alive": true}
	var b1r2_lethal_spell := {
		"id": "sandbox:b1r2_lethal",
		"name": "B1R2 Lethal",
		"execution": "shared",
		"level": 1,
		"range": 10,
		"steps": [{"id": "s1", "type": "damage", "damage": "20", "damage_type": "fire"}]
	}
	var lethal_cast_ctx := SpellCastContext.new()
	lethal_cast_ctx.caster = b1r2_caster
	lethal_cast_ctx.spell = b1r2_lethal_spell
	lethal_cast_ctx.target_coord = Vector2i(0, 0)
	lethal_cast_ctx.monsters = [b1r2_mon]
	lethal_cast_ctx.players = [{"character": b1r2_caster, "hex_position": Vector2i(0, 0)}]
	lethal_cast_ctx.grid = null
	lethal_cast_ctx.tracker = null
	lethal_cast_ctx.trigger_enemy_defeat_features = test_defeat_cb
	var lethal_decisions := {
		"cast_context": lethal_cast_ctx,
		"trigger_enemy_defeat_features": test_defeat_cb,
		"monsters": [b1r2_mon]
	}
	var lethal_res := CombatAction.resolve_spell(b1r2_caster, b1r2_mon, b1r2_lethal_spell, false, lethal_decisions, [], 1, 5)
	check.call(int(b1r2_mon.get("current_hp", 0)) == 0 and bool(b1r2_mon.get("_defeat_processed", false)) and defeat_cb_calls.size() == 1, "B1R2: Defeated Dictionary monster triggers defeat callback exactly once")
	await SpellCastResults._settle_stepped_spell_actors(lethal_cast_ctx, lethal_res)
	check.call(defeat_cb_calls.size() == 1, "B1R2: End-of-cast pass does not duplicate defeat callback")

	# B1R2 Test 5: Critical spell attack refuses bypass_critical replacement on Zombie / renamed JSON projection; downed Character takes 2 failures
	var dread_husk := {
		"id": "dread_husk_1",
		"name": "Dread Husk",
		"current_hp": 10,
		"max_hp": 10,
		"is_alive": true,
		"armor_class": -100,
		"ability_scores": {"CON": 100},
		"special_abilities": [
			{
				"id": "inexorable_resilience",
				"name": "Inexorable Resilience",
				"type": "zero_hp_replacement",
				"trigger": "zero_hp",
				"bypass_critical": true,
				"save_ability": "CON",
				"dc_base": 5,
				"dc_add_damage": true,
				"replacement_hp": 1
			}
		]
	}
	var atk_spell_1 := {
		"id": "sandbox:atk_test",
		"name": "Attack Test",
		"execution": "shared",
		"level": 1,
		"range": 10,
		"steps": [{"id": "a1", "type": "attack", "attack_type": "ranged_spell", "damage": "15", "damage_type": "fire"}]
	}
	FighterChecks._seed_die(20, 10)
	var non_crit_res := CombatAction.resolve_spell(b1r2_caster, dread_husk, atk_spell_1, false, {}, [], 1, 5)
	check.call(int(dread_husk["current_hp"]) == 1 and bool(dread_husk["is_alive"]) == true, "B1R2: Non-critical hit allows renamed JSON zero-HP replacement to survive at 1 HP")

	FighterChecks._seed_die(20, 20)
	var crit_res := CombatAction.resolve_spell(b1r2_caster, dread_husk, atk_spell_1, false, {}, [], 1, 5)
	check.call(crit_res.get("critical", false) == true and int(dread_husk["current_hp"]) == 0 and bool(dread_husk["is_alive"]) == false, "B1R2: Critical spell attack refuses bypass_critical replacement; monster drops to 0 HP and dies")

	var downed_char := Character.new()
	downed_char.initialize("Downed Char", "human", "fighter", AbilityScores.new())
	downed_char.max_hp = 50
	downed_char.current_hp = 0
	downed_char.death_save_failures = 0
	FighterChecks._seed_die(20, 20)
	var downed_crit_res := CombatAction.resolve_spell(b1r2_caster, downed_char, atk_spell_1, false, {}, [], 1, 5)
	check.call(downed_char.death_save_failures == 2, "B1R2: Downed Character hit by critical spell attack takes 2 death save failures")

	var atk_then_save_crit := {
		"id": "sandbox:crit_isolation",
		"name": "Crit Isolation",
		"execution": "shared",
		"level": 1,
		"range": 10,
		"steps": [
			{"id": "s0_atk", "type": "attack", "attack_type": "ranged_spell", "damage": "5", "damage_type": "fire"},
			{"id": "s1_save", "type": "save", "save": "DEX", "damage": "5", "damage_type": "fire"}
		]
	}
	var crit_iso_target := {"id": "crit_iso", "name": "Crit Iso", "current_hp": 50, "max_hp": 50, "is_alive": true, "armor_class": -100, "ability_scores": {"DEX": -100}}
	FighterChecks._seed_die(20, 20)
	var crit_iso_res := CombatAction.resolve_spell(b1r2_caster, crit_iso_target, atk_then_save_crit, false, {}, [], 1, 5)
	var step0_crit: bool = bool(crit_iso_res["step_results"][0]["target_outcomes"][0].get("critical", false))
	var step1_crit: bool = bool(crit_iso_res["step_results"][1]["target_outcomes"][0].get("critical", false))
	check.call(step0_crit == true and step1_crit == false, "B1R2: Attack critical fact is scoped to Step 0 and does not leak to Step 1 save")

	# B1R2 Test 6: Runtime-refused valid JSON area via real CombatAction.resolve_spell(... deduct_slot=true) preserves slot/SP/HP/effects
	var b1r2_refusal_caster := Character.new()
	b1r2_refusal_caster.initialize("Refusal Caster", "human", "wizard", AbilityScores.new())
	b1r2_refusal_caster.character_id = "refusal-caster"
	b1r2_refusal_caster.spell_slots["1"] = 3
	b1r2_refusal_caster.current_hp = 25
	b1r2_refusal_caster.add_condition("sanctuary", 10)
	b1r2_refusal_caster.add_condition("invisibility", 10)
	var b1r2_area_no_grid := {
		"id": "sandbox:area_refusal_no_grid",
		"name": "Area Refusal No Grid",
		"execution": "shared",
		"level": 1,
		"range": 10,
		"steps": [{"id": "s1", "type": "damage", "target": "area", "shape": "sphere", "radius": 2, "damage": "2d6", "damage_type": "fire"}]
	}
	var no_grid_res := CombatAction.resolve_spell(b1r2_refusal_caster, b1r2_target, b1r2_area_no_grid, true, {}, [], 1, 5)
	check.call(bool(no_grid_res.get("refused", false)) == true and not bool(no_grid_res.get("success", true)), "B1R2: Area spell without grid/participants returns refused=true")
	check.call(int(b1r2_refusal_caster.spell_slots["1"]) == 3, "B1R2: Refused area cast preserves spell slot (3 remaining)")
	check.call(b1r2_refusal_caster.current_hp == 25, "B1R2: Refused area cast preserves HP")
	check.call(b1r2_refusal_caster.has_condition("sanctuary") and b1r2_refusal_caster.has_condition("invisibility"), "B1R2: Refused area cast preserves Sanctuary and Invisibility")

	# B1R2 Test 7: Real concentration suspension on taking damage choice
	# Step 0 damage pauses for Stroke of Luck popup; Step 1 does not run while pending;
	# decline strips concentration and reduced defense is hit; accept maintains concentration and defense.
	var pause_caster := Character.new()
	pause_caster.initialize("Pause Caster", "human", "wizard", AbilityScores.new())
	pause_caster.character_id = "pause-caster"
	pause_caster.ability_scores.intelligence = 10 # spell atk +2

	var pause_target := Character.new()
	pause_target.initialize("Pause Target", "human", "rogue", AbilityScores.new())
	pause_target.character_id = "pause-target"
	pause_target.current_hp = 30
	pause_target.max_hp = 30
	pause_target.base_ac = 13
	pause_target.ability_scores.constitution = 10 # +0 CON save
	pause_target.features.append({"id": "rogue_stroke_of_luck"})
	pause_target.feature_uses["rogue_stroke_of_luck"] = 1
	pause_target.add_condition("shield_of_faith", 100)
	pause_target.concentrating_on = {
		"spell_id": "shield_of_faith",
		"targets": [pause_target],
		"duration_rounds_remaining": 100
	}
	check.call(pause_target.get_ac() == 15, "B1R2 Test 7: Initial AC is 15 with Shield of Faith")

	var two_step_atk := {
		"id": "sandbox:two_step_pause",
		"name": "Two Step Pause",
		"execution": "shared",
		"level": 1,
		"range": 10,
		"steps": [
			{"id": "s0", "type": "attack", "attack_type": "ranged_spell", "damage": "10", "damage_type": "fire"},
			{"id": "s1", "type": "attack", "attack_type": "ranged_spell", "damage": "10", "damage_type": "fire"}
		]
	}

	# Seed: atk1 rolls >= 13 (+2 = 15 hits AC 15), CON save rolls <= 9 (fails DC 10), atk2 rolls 11 (+2 = 13: hits 13, misses 15)
	var found_seed := 0
	for candidate in 50000:
		seed(candidate)
		var r1 := randi_range(1, 20)
		var r2 := randi_range(1, 20)
		var r3 := randi_range(1, 20)
		if r1 >= 13 and r2 <= 9 and (r3 + 2 == 13):
			found_seed = candidate
			seed(candidate)
			break

	var pause_res := CombatAction.resolve_spell(pause_caster, pause_target, two_step_atk, false, {}, [], 1, 5)
	check.call(pause_res.has("concentration_request") and pause_res.has("ordered_continuation"), "B1R2 Test 7: Failed CON save with Stroke of Luck creates owned concentration request and continuation")
	check.call(pause_target.get_ac() == 15 and pause_target.has_condition("shield_of_faith"), "B1R2 Test 7: Concentration and Shield of Faith defense retained while choice is pending")
	check.call(pause_target.current_hp == 20, "B1R2 Test 7: Target suffered Step 0 damage (20 HP remaining) but Step 1 has not executed")
	check.call(pause_res.get("step_results", []).is_empty(), "B1R2 Test 7: Execution suspended; Step 1 not present in step_results")

	# Canonical actor checks on concentration request:
	var forged_pause_target := Character.new()
	forged_pause_target.initialize("Forged Target", "human", "rogue", AbilityScores.new())
	forged_pause_target.character_id = pause_target.character_id
	var forged_conc_refusal := CombatAction.finish_pending_concentration_choice(pause_caster, forged_pause_target, pause_res, {"accepted": false})
	check.call(bool(forged_conc_refusal.get("refused", false)), "B1R2 Test 7: Refuses forged target Character with identical ID")

	var wrong_pause_caster := Character.new()
	wrong_pause_caster.initialize("Wrong Caster", "human", "wizard", AbilityScores.new())
	var wrong_conc_refusal := CombatAction.finish_pending_concentration_choice(wrong_pause_caster, pause_target, pause_res, {"accepted": false})
	check.call(bool(wrong_conc_refusal.get("refused", false)), "B1R2 Test 7: Refuses wrong caster caller")

	# Decline reaction choice: concentration is lost, AC drops to 13, Step 1 executes against reduced defense
	var decline_res := CombatAction.finish_pending_concentration_choice(pause_caster, pause_target, pause_res, {"accepted": false})
	check.call(not bool(decline_res.get("refused", false)), "B1R2 Test 7: Legitimate decline settles successfully")
	check.call(pause_target.concentrating_on.is_empty() and not pause_target.has_condition("shield_of_faith"), "B1R2 Test 7: Declining reaction ends concentration and removes Shield of Faith")
	check.call(pause_target.get_ac() == 13, "B1R2 Test 7: AC drops to 13 after concentration ends")
	check.call(decline_res.get("step_results", []).size() == 2, "B1R2 Test 7: Resumption completes Step 1 (both steps present)")
	var dec_s1_hit: bool = bool(decline_res["step_results"][1]["target_outcomes"][0]["hit"])
	check.call(dec_s1_hit == true, "B1R2 Test 7: Step 1 attack (roll 13) hits against reduced AC 13")
	check.call(pause_target.current_hp == 10, "B1R2 Test 7: Target HP suffered Step 0 (10 dmg) and Step 1 (10 dmg); no re-applied damage (10 HP remaining)")

	# Duplicate replay refusal:
	var dup_conc_res := CombatAction.finish_pending_concentration_choice(pause_caster, pause_target, pause_res, {"accepted": false})
	check.call(dup_conc_res == pause_res or bool(dup_conc_res.get("refused", false)), "B1R2 Test 7: Duplicate settlement replay refused")

	# Acceptance test: Stroke of Luck turns save into 20, concentration maintained, Step 1 misses against AC 15
	pause_target.current_hp = 30
	pause_target.add_condition("shield_of_faith", 100)
	pause_target.concentrating_on = {
		"spell_id": "shield_of_faith",
		"targets": [pause_target],
		"duration_rounds_remaining": 100
	}
	pause_target.feature_uses["rogue_stroke_of_luck"] = 1
	seed(found_seed)
	var accept_pause_res := CombatAction.resolve_spell(pause_caster, pause_target, two_step_atk, false, {}, [], 1, 5)
	check.call(accept_pause_res.has("concentration_request"), "B1R2 Test 7: Acceptance setup triggers concentration request")
	var accept_res := CombatAction.finish_pending_concentration_choice(pause_caster, pause_target, accept_pause_res, {"accepted": true})
	check.call(not pause_target.concentrating_on.is_empty() and pause_target.has_condition("shield_of_faith"), "B1R2 Test 7: Accepting Stroke of Luck maintains concentration on Shield of Faith")
	check.call(pause_target.get_ac() == 15, "B1R2 Test 7: AC remains 15 with maintained Shield of Faith")
	check.call(accept_res.get("step_results", []).size() == 2, "B1R2 Test 7: Both steps completed after accepted resumption")
	var acc_s1_hit: bool = bool(accept_res["step_results"][1]["target_outcomes"][0]["hit"])
	check.call(acc_s1_hit == false, "B1R2 Test 7: Step 1 attack (roll 13) misses against retained AC 15")
	check.call(pause_target.current_hp == 20, "B1R2 Test 7: Target HP suffered only Step 0 damage (20 HP remaining)")

	# B1R2 Test 8: Real ordered damage wholly/partly absorbed by TempHP drives CON save from taken damage
	var temphp_target := Character.new()
	temphp_target.initialize("TempHP Target", "human", "cleric", AbilityScores.new())
	temphp_target.current_hp = 30
	temphp_target.max_hp = 30
	temphp_target.temp_hp = 10
	temphp_target.ability_scores.constitution = 10 # modifier +0
	temphp_target.concentrating_on = {"spell_id": "bless", "targets": [temphp_target]}

	# Stepped spell deals 24 fire damage: 10 absorbed by TempHP, 14 HP loss, total resolved 24.
	# CON save DC = floor(24 / 2) = 12 (not floor(14 / 2) = 7 -> 10).
	# Roll 10: would pass DC 10, but fails DC 12!
	var temphp_dmg_spell := {
		"id": "sandbox:temphp_stepped",
		"name": "TempHP Stepped",
		"execution": "shared",
		"level": 1,
		"range": 10,
		"steps": [{"id": "s0", "type": "damage", "damage": "24", "damage_type": "fire"}]
	}
	FighterChecks._seed_die(20, 10)
	var temphp_res := CombatAction.resolve_spell(pause_caster, temphp_target, temphp_dmg_spell, false, {}, [], 1, 5)
	check.call(temphp_target.temp_hp == 0 and temphp_target.current_hp == 16, "B1R2 Test 8: 10 TempHP absorbed, 14 HP loss (16 HP remaining)")
	check.call(temphp_target.concentrating_on.is_empty(), "B1R2 Test 8: Roll 10 fails DC 12 (driven by resolved damage 24, not hp_loss 14 which would be DC 10)")

	# Wholly absorbed: 20 TempHP absorbing 8 damage (hp_loss = 0, resolved = 8)
	temphp_target.current_hp = 30
	temphp_target.temp_hp = 20
	temphp_target.concentrating_on = {"spell_id": "bless", "targets": [temphp_target]}
	var temphp_absorb_spell := {
		"id": "sandbox:temphp_absorb",
		"name": "TempHP Absorb",
		"execution": "shared",
		"level": 1,
		"range": 10,
		"steps": [{"id": "s0", "type": "damage", "damage": "8", "damage_type": "fire"}]
	}
	FighterChecks._seed_die(20, 5)
	var absorb_res := CombatAction.resolve_spell(pause_caster, temphp_target, temphp_absorb_spell, false, {}, [], 1, 5)
	check.call(temphp_target.temp_hp == 12 and temphp_target.current_hp == 30, "B1R2 Test 8: 8 TempHP absorbed, 0 HP loss (30 HP preserved)")
	check.call(temphp_target.concentrating_on.is_empty(), "B1R2 Test 8: Wholly absorbed damage (hp_loss=0) still triggers DC 10 save (roll 5 fails, drops concentration)")

	# B1R2 Test 9: Chained suspensions: Empowered Spell damage suspension preceding concentration suspension
	var chain_susp_sorcerer := Character.new()
	chain_susp_sorcerer.initialize("Chain Sorcerer", "human", "sorcerer", AbilityScores.new())
	chain_susp_sorcerer.character_id = "chain-sorcerer"
	chain_susp_sorcerer.features.append({"id": "sorcerer_metamagic"})
	chain_susp_sorcerer.sorcerer_metamagic_choices.append("empowered_spell")
	chain_susp_sorcerer.feature_uses["sorcery_points"] = 3
	chain_susp_sorcerer.ability_scores.charisma = 16

	var chain_susp_target := Character.new()
	chain_susp_target.initialize("Chain Target", "human", "rogue", AbilityScores.new())
	chain_susp_target.character_id = "chain-target"
	chain_susp_target.current_hp = 30
	chain_susp_target.max_hp = 30
	chain_susp_target.ability_scores.constitution = 10
	chain_susp_target.features.append({"id": "rogue_stroke_of_luck"})
	chain_susp_target.feature_uses["rogue_stroke_of_luck"] = 1
	chain_susp_target.concentrating_on = {"spell_id": "bless", "targets": [chain_susp_target]}

	var chained_spell := {
		"id": "sandbox:chained_suspension",
		"name": "Chained Suspension",
		"execution": "shared",
		"level": 1,
		"range": 10,
		"steps": [
			{"id": "s0_dmg", "type": "damage", "damage": "1d6", "damage_type": "fire"},
			{"id": "s1_dmg", "type": "damage", "damage": "5", "damage_type": "fire"}
		]
	}
	# Seed: 1d6 rolls 1 (eligible for empower), then CON save rolls 4 (fails DC 10)
	FighterChecks._seed_die(6, 1)
	var chain_decisions := {
		"metamagic:empowered": true,
		"defer_empowered": true
	}
	var chain_res := CombatAction.resolve_spell(chain_susp_sorcerer, chain_susp_target, chained_spell, false, chain_decisions, [], 1, 5)
	check.call(chain_res.has("damage_request"), "B1R2 Test 9: Step 0 suspends first for Empowered Spell damage request")

	# Settle damage request: resumption immediately encounters failed CON save and suspends for concentration
	FighterChecks._seed_die(20, 4)
	var dmg_settled := CombatAction.finish_pending_spell_damage(chain_susp_sorcerer, chain_susp_target, chain_res, {"metamagic:empowered_dice": [0]})
	check.call(dmg_settled.has("concentration_request"), "B1R2 Test 9: Damage settlement immediately suspends for concentration request")

	# Settle concentration request: resumption completes Step 1
	var conc_settled := CombatAction.finish_pending_concentration_choice(chain_susp_sorcerer, chain_susp_target, dmg_settled, {"accepted": false})
	check.call(conc_settled.get("step_results", []).size() == 2, "B1R2 Test 9: Concentration settlement completes Step 1 (both steps present)")
	check.call(chain_susp_target.concentrating_on.is_empty(), "B1R2 Test 9: Concentration ended after declined reaction")

	# B1R2 Test 10: Registry teardown / clear_pending_requests invalidates pending concentration request
	var teardown_target := Character.new()
	teardown_target.initialize("Teardown Target", "human", "rogue", AbilityScores.new())
	teardown_target.current_hp = 30
	teardown_target.max_hp = 30
	teardown_target.features.append({"id": "rogue_stroke_of_luck"})
	teardown_target.feature_uses["rogue_stroke_of_luck"] = 1
	teardown_target.concentrating_on = {"spell_id": "bless", "targets": [teardown_target]}
	var teardown_spell := {
		"id": "sandbox:teardown_pause",
		"name": "Teardown Pause",
		"execution": "shared",
		"level": 1,
		"range": 10,
		"steps": [
			{"id": "s0", "type": "damage", "damage": "10", "damage_type": "fire"},
			{"id": "s1", "type": "damage", "damage": "10", "damage_type": "fire"}
		]
	}
	FighterChecks._seed_die(20, 4)
	var teardown_res := CombatAction.resolve_spell(pause_caster, teardown_target, teardown_spell, false, {}, [], 1, 5)
	check.call(teardown_res.has("concentration_request"), "B1R2 Test 10: Concentration request created before teardown")
	SpellDamageRolls.clear_pending_requests()
	var post_teardown := CombatAction.finish_pending_concentration_choice(pause_caster, teardown_target, teardown_res, {"accepted": false})

	# B1R2 Correction Test 11: DC 30 Stroke of Luck save semantics
	# 11A. Pending-callback path: DC 30, modifier 0. Accepted Stroke turns d20 into 20, total 20 < 30 still fails.
	# Stroke feature use is spent once, but concentration is lost.
	var dc30_caster := Character.new()
	dc30_caster.initialize("DC30 Caster", "human", "wizard", AbilityScores.new())
	var dc30_target_mod0 := Character.new()
	dc30_target_mod0.initialize("DC30 Target Mod0", "human", "rogue", AbilityScores.new())
	dc30_target_mod0.current_hp = 100
	dc30_target_mod0.max_hp = 100
	dc30_target_mod0.ability_scores.constitution = 10 # modifier +0
	dc30_target_mod0.features.append({"id": "rogue_stroke_of_luck"})
	dc30_target_mod0.feature_uses["rogue_stroke_of_luck"] = 1
	dc30_target_mod0.add_condition("shield_of_faith", 100)
	dc30_target_mod0.concentrating_on = {"spell_id": "shield_of_faith", "targets": [dc30_target_mod0]}

	var dc30_two_step := {
		"id": "sandbox:dc30_two_step",
		"name": "DC30 Two Step",
		"execution": "shared",
		"level": 1,
		"range": 10,
		"steps": [
			{"id": "s0", "type": "damage", "damage": "60", "damage_type": "fire"}, # 60 dmg -> DC 30
			{"id": "s1", "type": "damage", "damage": "10", "damage_type": "fire"}
		]
	}
	# Seed CON save to roll 12 (fails DC 30)
	FighterChecks._seed_die(20, 12)
	var dc30_pending := CombatAction.resolve_spell(dc30_caster, dc30_target_mod0, dc30_two_step, false, {}, [], 1, 5)
	check.call(dc30_pending.has("concentration_request"), "B1R2 Test 11A: Suspends for concentration request at DC 30")
	check.call(dc30_target_mod0.current_hp == 40, "B1R2 Test 11A: Step 0 dealt 60 damage (40 HP remaining), Step 1 has not executed")
	check.call(dc30_target_mod0.has_condition("shield_of_faith"), "B1R2 Test 11A: Shield of Faith intact while pending")

	# Settle with accepted: true
	var dc30_settled := CombatAction.finish_pending_concentration_choice(dc30_caster, dc30_target_mod0, dc30_pending, {"accepted": true})
	check.call(int(dc30_target_mod0.feature_uses.get("rogue_stroke_of_luck", 0)) == 0, "B1R2 Test 11A: Stroke of Luck was spent once")
	check.call(dc30_target_mod0.concentrating_on.is_empty(), "B1R2 Test 11A: Total 20 < 30 fails; concentration ended")
	check.call(not dc30_target_mod0.has_condition("shield_of_faith"), "B1R2 Test 11A: Shield of Faith lost after failed save")
	check.call(dc30_target_mod0.current_hp == 30, "B1R2 Test 11A: Step 1 completed (10 dmg -> 30 HP remaining); Step 0 not duplicated")

	# 11B. Pending-callback path: DC 30, sufficient modifier (+10). Natural 20 + 10 = 30 >= 30 succeeds.
	var dc30_target_mod10 := Character.new()
	dc30_target_mod10.initialize("DC30 Target Mod10", "human", "rogue", AbilityScores.new())
	dc30_target_mod10.current_hp = 100
	dc30_target_mod10.max_hp = 100
	dc30_target_mod10.level = 17
	dc30_target_mod10.proficiency_bonus = 6
	dc30_target_mod10.ability_scores.constitution = 18 # modifier +4
	dc30_target_mod10.saving_throw_proficiencies.append("CON") # +4 + 6 = +10 modifier
	dc30_target_mod10.features.append({"id": "rogue_stroke_of_luck"})
	dc30_target_mod10.feature_uses["rogue_stroke_of_luck"] = 1
	dc30_target_mod10.add_condition("shield_of_faith", 100)
	dc30_target_mod10.concentrating_on = {"spell_id": "shield_of_faith", "targets": [dc30_target_mod10]}

	FighterChecks._seed_die(20, 5) # 5 + 10 = 15 < 30 (fails)
	var dc30_mod10_pending := CombatAction.resolve_spell(dc30_caster, dc30_target_mod10, dc30_two_step, false, {}, [], 1, 5)
	check.call(dc30_mod10_pending.has("concentration_request"), "B1R2 Test 11B: Mod +10 suspends for concentration request at DC 30")
	var dc30_mod10_settled := CombatAction.finish_pending_concentration_choice(dc30_caster, dc30_target_mod10, dc30_mod10_pending, {"accepted": true})
	check.call(int(dc30_target_mod10.feature_uses.get("rogue_stroke_of_luck", 0)) == 0, "B1R2 Test 11B: Stroke of Luck was spent once")
	check.call(not dc30_target_mod10.concentrating_on.is_empty(), "B1R2 Test 11B: Natural 20 + modifier 10 = 30 >= 30 succeeds; concentration maintained")
	check.call(dc30_target_mod10.has_condition("shield_of_faith"), "B1R2 Test 11B: Shield of Faith maintained")

	# 11C. Supplied-decision path: DC 30, modifier 0. Accepted Stroke spends once but fails and ends concentration.
	var dc30_target_sup0 := Character.new()
	dc30_target_sup0.initialize("DC30 Sup0", "human", "rogue", AbilityScores.new())
	dc30_target_sup0.current_hp = 100
	dc30_target_sup0.max_hp = 100
	dc30_target_sup0.ability_scores.constitution = 10 # modifier +0
	dc30_target_sup0.features.append({"id": "rogue_stroke_of_luck"})
	dc30_target_sup0.feature_uses["rogue_stroke_of_luck"] = 1
	dc30_target_sup0.add_condition("shield_of_faith", 100)
	dc30_target_sup0.concentrating_on = {"spell_id": "shield_of_faith", "targets": [dc30_target_sup0]}

	FighterChecks._seed_die(20, 10)
	var dc30_sup0_res := CombatAction.resolve_spell(dc30_caster, dc30_target_sup0, dc30_two_step, false, {"concentration_stroke_of_luck": true}, [], 1, 5)
	check.call(not dc30_sup0_res.has("concentration_request"), "B1R2 Test 11C: Supplied decision resolves without suspension")
	check.call(int(dc30_target_sup0.feature_uses.get("rogue_stroke_of_luck", 0)) == 0, "B1R2 Test 11C: Stroke of Luck spent once in supplied-decision path")
	check.call(dc30_target_sup0.concentrating_on.is_empty(), "B1R2 Test 11C: 20 < 30 fails; concentration ended in supplied-decision path")

	# 11D. Supplied-decision path: DC 30, modifier +10. Accepted Stroke succeeds.
	var dc30_target_sup10 := Character.new()
	dc30_target_sup10.initialize("DC30 Sup10", "human", "rogue", AbilityScores.new())
	dc30_target_sup10.current_hp = 100
	dc30_target_sup10.max_hp = 100
	dc30_target_sup10.level = 17
	dc30_target_sup10.proficiency_bonus = 6
	dc30_target_sup10.ability_scores.constitution = 18
	dc30_target_sup10.saving_throw_proficiencies.append("CON") # +10 modifier
	dc30_target_sup10.features.append({"id": "rogue_stroke_of_luck"})
	dc30_target_sup10.feature_uses["rogue_stroke_of_luck"] = 1
	dc30_target_sup10.add_condition("shield_of_faith", 100)
	dc30_target_sup10.concentrating_on = {"spell_id": "shield_of_faith", "targets": [dc30_target_sup10]}

	FighterChecks._seed_die(20, 8)
	var dc30_sup10_res := CombatAction.resolve_spell(dc30_caster, dc30_target_sup10, dc30_two_step, false, {"concentration_stroke_of_luck": true}, [], 1, 5)
	check.call(not dc30_sup10_res.has("concentration_request"), "B1R2 Test 11D: Supplied decision resolves without suspension")
	check.call(int(dc30_target_sup10.feature_uses.get("rogue_stroke_of_luck", 0)) == 0, "B1R2 Test 11D: Stroke of Luck spent once in supplied-decision path")
	check.call(not dc30_target_sup10.concentrating_on.is_empty(), "B1R2 Test 11D: 20 + 10 = 30 >= 30 succeeds; concentration maintained in supplied path")

	# B1R2 Correction Test 12: Ordered choice sequencing (Stroke of Luck then Bardic Inspiration)
	var seq_caster := Character.new()
	seq_caster.initialize("Seq Caster", "human", "wizard", AbilityScores.new())
	seq_caster.spell_slots = {"1": 2}

	var seq_spell := {
		"id": "sandbox:seq_spell",
		"name": "Seq Spell",
		"execution": "shared",
		"level": 1,
		"range": 10,
		"steps": [
			{"id": "s0", "type": "damage", "damage": "20", "damage_type": "fire"}, # DC 10
			{"id": "s1", "type": "effect", "effects": [{"type": "temporary_hp", "value": "5"}]}
		]
	}

	# 12A. Decline Stroke, then accept Bardic can preserve concentration.
	var seq_target_a := Character.new()
	seq_target_a.initialize("Seq Target A", "human", "rogue", AbilityScores.new())
	seq_target_a.current_hp = 50
	seq_target_a.max_hp = 50
	seq_target_a.temp_hp = 0
	seq_target_a.ability_scores.constitution = 10 # +0 modifier
	seq_target_a.features.append({"id": "rogue_stroke_of_luck"})
	seq_target_a.feature_uses["rogue_stroke_of_luck"] = 1
	seq_target_a.feature_uses["bardic_inspiration_die"] = "1d6"
	seq_target_a.add_condition("shield_of_faith", 100)
	seq_target_a.concentrating_on = {"spell_id": "shield_of_faith", "targets": [seq_target_a]}

	# CON save rolls 5 (fails DC 10)
	FighterChecks._seed_die(20, 5)
	var seq_susp1 := CombatAction.resolve_spell(seq_caster, seq_target_a, seq_spell, true, {}, [], 1, 5)
	check.call(seq_susp1.has("concentration_request"), "B1R2 Test 12A: Suspends with concentration request")
	check.call(str(seq_susp1["concentration_request"]["feature"]) == "stroke_of_luck", "B1R2 Test 12A: First choice offered is stroke_of_luck")
	check.call(seq_target_a.current_hp == 30, "B1R2 Test 12A: Step 0 damage applied once (30 HP remaining)")
	check.call(seq_target_a.temp_hp == 0, "B1R2 Test 12A: Step 1 waits while choice is pending")
	check.call(seq_target_a.has_condition("shield_of_faith"), "B1R2 Test 12A: Shield of Faith intact while pending")
	check.call(int(seq_caster.spell_slots.get("1", 0)) == 1, "B1R2 Test 12A: Slot cost deducted exactly once at cast commitment")

	# Decline Stroke of Luck -> should return next concentration request for bardic_inspiration!
	var seq_after_stroke := CombatAction.finish_pending_concentration_choice(seq_caster, seq_target_a, seq_susp1, {"accepted": false})
	check.call(seq_after_stroke.has("concentration_request"), "B1R2 Test 12A: Declining Stroke offers chained Bardic Inspiration request")
	check.call(str(seq_after_stroke["concentration_request"]["feature"]) == "bardic_inspiration", "B1R2 Test 12A: Second choice is bardic_inspiration")
	check.call(int(seq_after_stroke["concentration_request"]["roll"]) == 5, "B1R2 Test 12A: Original roll 5 retained")
	check.call(int(seq_target_a.feature_uses.get("rogue_stroke_of_luck", 0)) == 1, "B1R2 Test 12A: Stroke of Luck was not spent")
	check.call(seq_target_a.current_hp == 30, "B1R2 Test 12A: Step 1 still waiting while Bardic choice pending; no duplicate damage")
	check.call(seq_target_a.temp_hp == 0, "B1R2 Test 12A: Step 1 still not executed while Bardic choice pending")
	check.call(seq_target_a.has_condition("shield_of_faith"), "B1R2 Test 12A: Shield of Faith intact while Bardic choice pending")
	check.call(int(seq_caster.spell_slots.get("1", 0)) == 1, "B1R2 Test 12A: No extra slot charge while chained choice pending")

	# Accept Bardic Inspiration: seed 1d6 to roll 6 -> total 5 + 6 = 11 >= 10 (success!)
	FighterChecks._seed_die(6, 6)
	var seq_settled := CombatAction.finish_pending_concentration_choice(seq_caster, seq_target_a, seq_after_stroke, {"accepted": true})
	check.call(not seq_settled.has("concentration_request"), "B1R2 Test 12A: All concentration choices completed")
	check.call(not seq_target_a.feature_uses.has("bardic_inspiration_die"), "B1R2 Test 12A: Bardic Inspiration die consumed")
	check.call(not seq_target_a.concentrating_on.is_empty(), "B1R2 Test 12A: 5 + 6 = 11 >= 10 preserves concentration")
	check.call(seq_target_a.has_condition("shield_of_faith"), "B1R2 Test 12A: Shield of Faith preserved")
	check.call(seq_target_a.current_hp == 30, "B1R2 Test 12A: Step 0 damage applied once, not duplicated")
	check.call(seq_target_a.temp_hp == 5, "B1R2 Test 12A: Step 1 completed (5 TempHP granted)")
	check.call(int(seq_caster.spell_slots.get("1", 0)) == 1, "B1R2 Test 12A: Final cast cost remains correct (no extra charge upon settlement)")
	check.call(seq_settled.get("step_results", []).size() == 2, "B1R2 Test 12A: Both steps executed")

	# 12B. Accepted Stroke that still fails permits Bardic Inspiration.
	var seq_target_b := Character.new()
	seq_target_b.initialize("Seq Target B", "human", "rogue", AbilityScores.new())
	seq_target_b.current_hp = 50
	seq_target_b.max_hp = 50
	seq_target_b.temp_hp = 0
	seq_target_b.ability_scores.constitution = 10
	seq_target_b.features.append({"id": "rogue_stroke_of_luck"})
	seq_target_b.feature_uses["rogue_stroke_of_luck"] = 1
	seq_target_b.feature_uses["bardic_inspiration_die"] = "1d6"
	seq_target_b.add_condition("shield_of_faith", 100)
	seq_target_b.concentrating_on = {"spell_id": "shield_of_faith", "targets": [seq_target_b]}

	var seq_spell_dc22 := {
		"id": "sandbox:seq_dc22",
		"name": "Seq DC22",
		"execution": "shared",
		"level": 1,
		"range": 10,
		"steps": [
			{"id": "s0", "type": "damage", "damage": "44", "damage_type": "fire"}, # DC 22
			{"id": "s1", "type": "effect", "effects": [{"type": "temporary_hp", "value": "5"}]}
		]
	}
	FighterChecks._seed_die(20, 8) # fails DC 22
	var seq_dc22_susp := CombatAction.resolve_spell(seq_caster, seq_target_b, seq_spell_dc22, false, {}, [], 1, 5)
	check.call(seq_dc22_susp.has("concentration_request"), "B1R2 Test 12B: Suspends for stroke at DC 22")
	check.call(seq_target_b.current_hp == 6, "B1R2 Test 12B: Step 0 damage applied once (6 HP remaining)")
	check.call(seq_target_b.temp_hp == 0, "B1R2 Test 12B: Step 1 waits while pending")

	# Accept Stroke: turns natural roll into 20 (+0 mod = 20 < 22 still fails)
	var seq_dc22_after_stroke := CombatAction.finish_pending_concentration_choice(seq_caster, seq_target_b, seq_dc22_susp, {"accepted": true})
	check.call(int(seq_target_b.feature_uses.get("rogue_stroke_of_luck", 0)) == 0, "B1R2 Test 12B: Stroke was spent")
	check.call(seq_dc22_after_stroke.has("concentration_request"), "B1R2 Test 12B: Still-failed save permits Bardic choice")
	check.call(str(seq_dc22_after_stroke["concentration_request"]["feature"]) == "bardic_inspiration", "B1R2 Test 12B: Chained request is bardic_inspiration")
	check.call(int(seq_dc22_after_stroke["concentration_request"]["roll"]) == 20, "B1R2 Test 12B: Roll carried forward as 20 from Stroke")
	check.call(seq_target_b.temp_hp == 0, "B1R2 Test 12B: Step 1 still waiting while Bardic choice pending")

	# Accept Bardic: roll 1d6 = 4 -> total 20 + 4 = 24 >= 22 (success!)
	FighterChecks._seed_die(6, 4)
	var seq_dc22_settled := CombatAction.finish_pending_concentration_choice(seq_caster, seq_target_b, seq_dc22_after_stroke, {"accepted": true})
	check.call(not seq_dc22_settled.has("concentration_request"), "B1R2 Test 12B: Settlement complete")
	check.call(not seq_target_b.concentrating_on.is_empty(), "B1R2 Test 12B: Concentration maintained by Bardic after Stroke failure")
	check.call(not seq_target_b.feature_uses.has("bardic_inspiration_die"), "B1R2 Test 12B: Bardic die consumed")
	check.call(seq_target_b.temp_hp == 5, "B1R2 Test 12B: Step 1 completed (5 TempHP granted)")
	check.call(seq_target_b.current_hp == 6, "B1R2 Test 12B: Step 0 damage applied once, not duplicated")

	# 12C. Accepted Stroke that succeeds does NOT offer or consume Bardic Inspiration.
	var seq_target_c := Character.new()
	seq_target_c.initialize("Seq Target C", "human", "rogue", AbilityScores.new())
	seq_target_c.current_hp = 50
	seq_target_c.max_hp = 50
	seq_target_c.temp_hp = 0
	seq_target_c.ability_scores.constitution = 10
	seq_target_c.features.append({"id": "rogue_stroke_of_luck"})
	seq_target_c.feature_uses["rogue_stroke_of_luck"] = 1
	seq_target_c.feature_uses["bardic_inspiration_die"] = "1d6"
	seq_target_c.add_condition("shield_of_faith", 100)
	seq_target_c.concentrating_on = {"spell_id": "shield_of_faith", "targets": [seq_target_c]}

	FighterChecks._seed_die(20, 5) # DC 10
	var seq_succ_susp := CombatAction.resolve_spell(seq_caster, seq_target_c, seq_spell, false, {}, [], 1, 5)
	var seq_succ_settled := CombatAction.finish_pending_concentration_choice(seq_caster, seq_target_c, seq_succ_susp, {"accepted": true})
	check.call(not seq_succ_settled.has("concentration_request"), "B1R2 Test 12C: Stroke success ends choice chain immediately")
	check.call(seq_target_c.feature_uses.has("bardic_inspiration_die"), "B1R2 Test 12C: Bardic Inspiration die NOT consumed when Stroke succeeds")
	check.call(int(seq_target_c.feature_uses.get("rogue_stroke_of_luck", 0)) == 0, "B1R2 Test 12C: Stroke spent once")
	check.call(not seq_target_c.concentrating_on.is_empty(), "B1R2 Test 12C: Concentration maintained")
	check.call(seq_target_c.temp_hp == 5, "B1R2 Test 12C: Step 1 completed")
	check.call(seq_target_c.current_hp == 30, "B1R2 Test 12C: Step 0 damage applied once")

	# 12D. Final decline ends concentration only after all choices finish.
	var seq_target_d := Character.new()
	seq_target_d.initialize("Seq Target D", "human", "rogue", AbilityScores.new())
	seq_target_d.current_hp = 50
	seq_target_d.max_hp = 50
	seq_target_d.temp_hp = 0
	seq_target_d.ability_scores.constitution = 10
	seq_target_d.features.append({"id": "rogue_stroke_of_luck"})
	seq_target_d.feature_uses["rogue_stroke_of_luck"] = 1
	seq_target_d.feature_uses["bardic_inspiration_die"] = "1d6"
	seq_target_d.add_condition("shield_of_faith", 100)
	seq_target_d.concentrating_on = {"spell_id": "shield_of_faith", "targets": [seq_target_d]}

	FighterChecks._seed_die(20, 5) # DC 10
	var seq_dec_susp := CombatAction.resolve_spell(seq_caster, seq_target_d, seq_spell, false, {}, [], 1, 5)
	var seq_dec_stroke := CombatAction.finish_pending_concentration_choice(seq_caster, seq_target_d, seq_dec_susp, {"accepted": false})
	check.call(not seq_target_d.concentrating_on.is_empty(), "B1R2 Test 12D: Concentration NOT ended yet after declining Stroke while Bardic pending")
	check.call(seq_target_d.has_condition("shield_of_faith"), "B1R2 Test 12D: Shield of Faith intact while Bardic pending")
	var seq_dec_bardic := CombatAction.finish_pending_concentration_choice(seq_caster, seq_target_d, seq_dec_stroke, {"accepted": false})
	check.call(seq_target_d.concentrating_on.is_empty(), "B1R2 Test 12D: Concentration ended only after Bardic also declined")
	check.call(not seq_target_d.has_condition("shield_of_faith"), "B1R2 Test 12D: Shield of Faith removed")
	check.call(seq_target_d.feature_uses.has("bardic_inspiration_die"), "B1R2 Test 12D: Declining Bardic did not consume die")
	check.call(int(seq_target_d.feature_uses.get("rogue_stroke_of_luck", 0)) == 1, "B1R2 Test 12D: Stroke was not consumed")
	check.call(seq_target_d.temp_hp == 5, "B1R2 Test 12D: Step 1 completed after choices finish")
	check.call(seq_target_d.current_hp == 30, "B1R2 Test 12D: Step 0 damage applied once")

	# 12E. Feature-specific supplied decisions: bardic answer does not accept stroke; caster attack decision does not become target CON answer.
	var seq_target_e := Character.new()
	seq_target_e.initialize("Seq Target E", "human", "rogue", AbilityScores.new())
	seq_target_e.current_hp = 50
	seq_target_e.max_hp = 50
	seq_target_e.temp_hp = 0
	seq_target_e.ability_scores.constitution = 10
	seq_target_e.features.append({"id": "rogue_stroke_of_luck"})
	seq_target_e.feature_uses["rogue_stroke_of_luck"] = 1
	seq_target_e.feature_uses["bardic_inspiration_die"] = "1d6"
	seq_target_e.add_condition("shield_of_faith", 100)
	seq_target_e.concentrating_on = {"spell_id": "shield_of_faith", "targets": [seq_target_e]}

	var feature_spec_decisions := {
		"stroke_of_luck": true, # belongs to caster attack context
		"has_attack": true,
		"concentration_bardic_inspiration": true
	}
	for candidate in 10000:
		seed(candidate)
		var r_d20 := randi_range(1, 20)
		var r_d6 := randi_range(1, 6)
		if r_d20 == 5 and r_d6 == 6:
			seed(candidate)
			break
	var spec_res := CombatAction.resolve_spell(seq_caster, seq_target_e, seq_spell, false, feature_spec_decisions, [], 1, 5)
	check.call(int(seq_target_e.feature_uses.get("rogue_stroke_of_luck", 0)) == 1, "B1R2 Test 12E: Target did NOT consume Stroke of Luck from caster's attack decision")
	check.call(not seq_target_e.feature_uses.has("bardic_inspiration_die"), "B1R2 Test 12E: Target consumed Bardic Inspiration from feature-specific key")
	check.call(not seq_target_e.concentrating_on.is_empty(), "B1R2 Test 12E: Concentration maintained by Bardic")
	check.call(seq_target_e.temp_hp == 5, "B1R2 Test 12E: Step 1 completed")
	check.call(seq_target_e.current_hp == 30, "B1R2 Test 12E: Step 0 damage applied once")

	# B1R2 Correction Test 13: Wrong-kind envelopes and chained request safeguards
	# 13A. Live damage ID under concentration envelope: refuses before changes, original damage request settles once.
	var wk_sorc := Character.new()
	wk_sorc.initialize("WK Sorcerer", "human", "sorcerer", AbilityScores.new())
	wk_sorc.character_id = "wk-sorc"
	wk_sorc.features.append({"id": "sorcerer_metamagic"})
	wk_sorc.sorcerer_metamagic_choices.append("empowered_spell")
	wk_sorc.feature_uses["sorcery_points"] = 3
	wk_sorc.ability_scores.charisma = 16

	var wk_target := Character.new()
	wk_target.initialize("WK Target", "human", "fighter", AbilityScores.new())
	wk_target.character_id = "wk-target"
	wk_target.current_hp = 30
	wk_target.max_hp = 30

	var wk_dmg_spell := {
		"id": "sandbox:wk_dmg",
		"name": "WK Dmg",
		"execution": "shared",
		"level": 1,
		"range": 10,
		"steps": [{"id": "s0", "type": "damage", "damage": "1d6", "damage_type": "fire"}]
	}
	FighterChecks._seed_die(6, 1)
	var wk_dmg_res := CombatAction.resolve_spell(wk_sorc, wk_target, wk_dmg_spell, false, {"metamagic:empowered": true, "defer_empowered": true}, [], 1, 5)
	check.call(wk_dmg_res.has("damage_request"), "B1R2 Test 13A: Live damage request created")
	var live_dmg_id: String = wk_dmg_res["damage_request"]["request_id"]

	# Supply live damage ID under concentration envelope:
	var wrong_conc_envelope := {"concentration_request": {"request_id": live_dmg_id}}
	var wrong_conc_kind_refusal := CombatAction.finish_pending_concentration_choice(wk_sorc, wk_target, wrong_conc_envelope, {"accepted": true})
	check.call(bool(wrong_conc_kind_refusal.get("refused", false)), "B1R2 Test 13A: Refuses damage ID under concentration envelope")
	check.call("kind mismatch" in str(wrong_conc_kind_refusal.get("error", "")).to_lower(), "B1R2 Test 13A: Refusal error reports kind mismatch")
	check.call(wk_target.current_hp == 30, "B1R2 Test 13A: Target HP unchanged (no damage applied)")
	check.call(int(wk_sorc.feature_uses.get("sorcery_points", 0)) == 3, "B1R2 Test 13A: Sorcery points unchanged")

	# Original damage request settles successfully exactly once:
	var wk_dmg_settled := CombatAction.finish_pending_spell_damage(wk_sorc, wk_target, wk_dmg_res, {"metamagic:empowered_dice": [0]})
	check.call(not bool(wk_dmg_settled.get("refused", false)), "B1R2 Test 13A: Original damage request settles successfully after wrong-kind refusal")
	check.call(wk_target.current_hp < 30, "B1R2 Test 13A: Damage applied once upon legitimate settlement")
	check.call(int(wk_sorc.feature_uses.get("sorcery_points", 0)) == 2, "B1R2 Test 13A: 1 SP spent upon legitimate settlement")

	# 13B. Live concentration ID under damage envelope: refuses before changes, original concentration settles once.
	var wk_conc_caster := Character.new()
	wk_conc_caster.initialize("WK Conc Caster", "human", "wizard", AbilityScores.new())
	var wk_conc_target := Character.new()
	wk_conc_target.initialize("WK Conc Target", "human", "rogue", AbilityScores.new())
	wk_conc_target.current_hp = 30
	wk_conc_target.max_hp = 30
	wk_conc_target.temp_hp = 0
	wk_conc_target.ability_scores.constitution = 10
	wk_conc_target.features.append({"id": "rogue_stroke_of_luck"})
	wk_conc_target.feature_uses["rogue_stroke_of_luck"] = 1
	wk_conc_target.add_condition("shield_of_faith", 100)
	wk_conc_target.concentrating_on = {"spell_id": "shield_of_faith", "targets": [wk_conc_target]}

	var wk_conc_spell := {
		"id": "sandbox:wk_conc",
		"name": "WK Conc",
		"execution": "shared",
		"level": 1,
		"range": 10,
		"steps": [
			{"id": "s0", "type": "damage", "damage": "10", "damage_type": "fire"},
			{"id": "s1", "type": "effect", "effects": [{"type": "temporary_hp", "value": "5"}]}
		]
	}
	FighterChecks._seed_die(20, 5) # fails DC 10
	var wk_conc_res := CombatAction.resolve_spell(wk_conc_caster, wk_conc_target, wk_conc_spell, false, {}, [], 1, 5)
	check.call(wk_conc_res.has("concentration_request"), "B1R2 Test 13B: Live concentration request created")
	var live_conc_id: String = wk_conc_res["concentration_request"]["request_id"]

	# Supply live concentration ID under damage envelope:
	var wrong_dmg_envelope := {"damage_request": {"request_id": live_conc_id}}
	var wrong_dmg_refusal := CombatAction.finish_pending_spell_damage(wk_conc_caster, wk_conc_target, wrong_dmg_envelope, {})
	check.call(bool(wrong_dmg_refusal.get("refused", false)), "B1R2 Test 13B: Refuses concentration ID under damage envelope")
	check.call("kind mismatch" in str(wrong_dmg_refusal.get("error", "")).to_lower(), "B1R2 Test 13B: Refusal error reports kind mismatch")
	check.call(wk_conc_target.has_condition("shield_of_faith"), "B1R2 Test 13B: Concentration and Shield of Faith intact")
	check.call(wk_conc_target.current_hp == 20, "B1R2 Test 13B: Step 1 still waiting; no extra damage")
	check.call(wk_conc_target.temp_hp == 0, "B1R2 Test 13B: Step 1 effect has not executed")

	# Settle legitimate concentration request:
	var wk_conc_settled := CombatAction.finish_pending_concentration_choice(wk_conc_caster, wk_conc_target, wk_conc_res, {"accepted": true})
	check.call(not bool(wk_conc_settled.get("refused", false)), "B1R2 Test 13B: Original concentration request settles successfully")
	check.call(not wk_conc_target.concentrating_on.is_empty(), "B1R2 Test 13B: Concentration maintained by accepted Stroke")
	check.call(wk_conc_target.temp_hp == 5, "B1R2 Test 13B: Step 1 executed upon legitimate settlement (5 TempHP granted)")
	check.call(wk_conc_target.current_hp == 20, "B1R2 Test 13B: Damage applied once, not duplicated")

	# 13C. Safeguards on chained choice ID: forged target, wrong caster, duplicate replay.
	var guard_caster := Character.new()
	guard_caster.initialize("Guard Caster", "human", "wizard", AbilityScores.new())
	var guard_target := Character.new()
	guard_target.initialize("Guard Target", "human", "rogue", AbilityScores.new())
	guard_target.current_hp = 50
	guard_target.max_hp = 50
	guard_target.ability_scores.constitution = 10
	guard_target.features.append({"id": "rogue_stroke_of_luck"})
	guard_target.feature_uses["rogue_stroke_of_luck"] = 1
	guard_target.feature_uses["bardic_inspiration_die"] = "1d6"
	guard_target.concentrating_on = {"spell_id": "bless", "targets": [guard_target]}

	FighterChecks._seed_die(20, 5) # DC 10
	var guard_susp := CombatAction.resolve_spell(guard_caster, guard_target, seq_spell, false, {}, [], 1, 5)
	# Decline Stroke -> chains to Bardic:
	var chained_res := CombatAction.finish_pending_concentration_choice(guard_caster, guard_target, guard_susp, {"accepted": false})
	check.call(chained_res.has("concentration_request"), "B1R2 Test 13C: Chained Bardic request obtained")
	check.call(str(chained_res["concentration_request"]["feature"]) == "bardic_inspiration", "B1R2 Test 13C: Feature is bardic_inspiration")

	# Forged target refusal on chained ID:
	var forged_chained_target := Character.new()
	forged_chained_target.initialize("Forged Chained Target", "human", "rogue", AbilityScores.new())
	forged_chained_target.character_id = guard_target.character_id
	var forged_chain_refusal := CombatAction.finish_pending_concentration_choice(guard_caster, forged_chained_target, chained_res, {"accepted": true})
	check.call(bool(forged_chain_refusal.get("refused", false)), "B1R2 Test 13C: Refuses forged target on chained request ID")

	# Wrong caster refusal on chained ID:
	var wrong_chain_caster := Character.new()
	wrong_chain_caster.initialize("Wrong Chain Caster", "human", "wizard", AbilityScores.new())
	var wrong_caster_chain_refusal := CombatAction.finish_pending_concentration_choice(wrong_chain_caster, guard_target, chained_res, {"accepted": true})
	check.call(bool(wrong_caster_chain_refusal.get("refused", false)), "B1R2 Test 13C: Refuses wrong caster on chained request ID")

	# Legitimate settlement of chained ID:
	FighterChecks._seed_die(6, 6)
	var chain_legit_settled := CombatAction.finish_pending_concentration_choice(guard_caster, guard_target, chained_res, {"accepted": true})
	check.call(not bool(chain_legit_settled.get("refused", false)), "B1R2 Test 13C: Legitimate settlement of chained request succeeds")
	check.call(not guard_target.concentrating_on.is_empty(), "B1R2 Test 13C: Concentration maintained")

	# Duplicate replay refusal on chained ID:
	var dup_chain_res := CombatAction.finish_pending_concentration_choice(guard_caster, guard_target, chained_res, {"accepted": true})
	check.call(dup_chain_res == chained_res or bool(dup_chain_res.get("refused", false)), "B1R2 Test 13C: Duplicate settlement replay on chained ID refused")

	pause_target.concentrating_on.clear()
	temphp_target.concentrating_on.clear()
	chain_susp_target.concentrating_on.clear()
	teardown_target.concentrating_on.clear()
	b1r2_conc_char.concentrating_on.clear()
	dc30_target_mod0.concentrating_on.clear()
	dc30_target_mod10.concentrating_on.clear()
	dc30_target_sup0.concentrating_on.clear()
	dc30_target_sup10.concentrating_on.clear()
	seq_target_a.concentrating_on.clear()
	seq_target_b.concentrating_on.clear()
	seq_target_c.concentrating_on.clear()
	seq_target_d.concentrating_on.clear()
	seq_target_e.concentrating_on.clear()
	wk_conc_target.concentrating_on.clear()
	guard_target.concentrating_on.clear()
	SpellDamageRolls.clear_pending_requests()

	_ordered_roll_choice_checks(check)
	DataLoader.spells = original_spells
	print("SHARED_SPELL_CHECKS_COMPLETE")


static func _ordered_roll_choice_checks(check: Callable) -> void:
	var caster := Character.new()
	caster.initialize("Ordered Portent", "human", "wizard", AbilityScores.new())
	while caster.level < 3:
		caster.level_up()
	ClassProgression.choose_subclass(caster, "diviner")
	caster.roll_tokens["diviner_portent"] = [{"token_id": "ordered:20", "value": 20, "feature_id": "diviner_portent", "pool_id": "diviner_portent", "die_sides": 20}]
	var target := {"id": "ordered_target", "name": "Ordered Target", "current_hp": 100, "max_hp": 100, "is_alive": true, "armor_class": -100, "ability_scores": {"CON": 10}, "conditions": {}}
	var host := SpellCastContext.new()
	host.caster = caster
	host.collect_roll_token_decision = func(_roller, _kind, _label, _seed = {}): return {}
	var decisions := {"cast_context": host, "target_visible": true}
	var spell := {
		"id": "sandbox:ordered_portent", "name": "Ordered Portent", "execution": "shared", "level": 1, "range": 6,
		"steps": [
			{"id": "hit", "type": "attack", "attack_type": "ranged_spell", "damage": "2", "damage_type": "fire"},
			{"id": "save", "type": "save", "save": "CON", "damage": "3", "damage_type": "fire"}
		]
	}
	var first := CombatAction.resolve_spell(caster, target, spell, false, decisions)
	check.call(first.has("roll_choice_request") and target.current_hp == 100, "Ordered Portent pauses before the first attack or damage")
	var first_record := SpellDamageRolls.roll_choice_record(caster, first)
	check.call(first_record.get("test_kind") == "attack", "Ordered Portent identifies the first attack test")
	var wrong_kind := CombatAction.finish_pending_spell_damage(caster, target, {"damage_request": first.roll_choice_request}, {})
	check.call(bool(wrong_kind.get("refused", false)) and target.current_hp == 100, "Roll choice cannot settle as damage or alter HP")
	var forged_target := target.duplicate(true)
	check.call(bool(SpellDamageRolls.settle_roll_choice(caster, forged_target, first, {}).get("refused", false)), "Roll choice refuses a copied actor without poisoning the live choice")
	FighterChecks._seed_die(20, 10)
	var second := SpellDamageRolls.settle_roll_choice(caster, target, first, {})
	check.call(second.has("roll_choice_request") and target.current_hp == 98, "Declining the attack offers Portent before the later save, preserving attack damage")
	check.call(SpellDamageRolls.roll_choice_record(caster, second).get("test_kind") == "monster_save", "Later save records its own roller and test kind")
	var answer := {"roll_token_replacement": {"owner": caster, "pool_id": "diviner_portent", "token_id": "ordered:20"}}
	var invalid_answer := {"roll_token_replacement": {"owner": caster, "pool_id": "diviner_portent", "token_id": "missing"}}
	check.call(bool(SpellDamageRolls.settle_roll_choice(caster, target, second, invalid_answer).get("refused", false)) and target.current_hp == 98, "Invalid token leaves the pending save and earlier damage intact")
	var finished := SpellDamageRolls.settle_roll_choice(caster, target, second, answer)
	check.call(bool(finished.get("success", false)) and target.current_hp == 98 and finished.get("step_results", []).size() == 2, "Later Portent save succeeds without repeating attack damage")
	check.call(RollTokenRules.get_available_values(caster, "diviner_portent").is_empty(), "Later save consumes exactly one Portent token")
	check.call(bool(SpellDamageRolls.settle_roll_choice(caster, target, first, {}).get("refused", false)) and bool(SpellDamageRolls.settle_roll_choice(caster, target, second, answer).get("refused", false)) and target.current_hp == 98, "Replaying either roll choice cannot repeat the cast")

	# Area saves suspend independently, retaining the one shared damage roll.
	var area_a := target.duplicate(true)
	area_a.id = "area_a"
	area_a.current_hp = 100
	var area_b := area_a.duplicate(true)
	area_b.id = "area_b"
	var area_spell := {
		"id": "sandbox:area_portent", "name": "Area Portent", "execution": "shared", "level": 1, "range": 6,
		"steps": [{"id": "area", "type": "save", "target": "area", "shape": "sphere", "radius": 1, "save": "CON", "damage": "3", "damage_type": "fire"}]
	}
	var area_first := CombatAction.resolve_spell(caster, area_a, area_spell, false, {"cast_context": host, "area_targets": [area_a, area_b]})
	check.call(SpellDamageRolls.roll_choice_record(caster, area_first).get("roller") == area_a, "Area Portent pauses for its first target")
	FighterChecks._seed_die(20, 1)
	var area_second := SpellDamageRolls.settle_roll_choice(caster, area_a, area_first, {})
	check.call(area_second.has("roll_choice_request") and area_a.current_hp == 97 and area_b.current_hp == 100, "Area Portent pauses for its second target after settling only the first")
	FighterChecks._seed_die(20, 20)
	var area_finished := SpellDamageRolls.settle_roll_choice(caster, area_b, area_second, {})
	check.call(bool(area_finished.get("success", false)) and area_a.current_hp == 97 and area_b.current_hp == 100 and area_finished.step_results[0].target_outcomes.size() == 2, "Area resume keeps both independent outcomes without duplicating damage")

	# Each damaging occurrence offers a concentration pre-roll choice after HP loss.
	var ally := Character.new()
	ally.initialize("Concentrating Ally", "human", "fighter", AbilityScores.new())
	ally.max_hp = 100
	ally.current_hp = 100
	ally.concentrating_on = {"spell_id": "bless", "targets": [ally]}
	var concentration_spell := {
		"id": "sandbox:concentration_portent", "name": "Concentration Portent", "execution": "shared", "level": 1, "range": 6,
		"steps": [
			{"id": "one", "type": "damage", "damage": "2", "damage_type": "fire"},
			{"id": "two", "type": "damage", "damage": "3", "damage_type": "fire"}
		]
	}
	var conc_first := CombatAction.resolve_spell(caster, ally, concentration_spell, false, {"cast_context": host})
	check.call(conc_first.has("roll_choice_request") and ally.current_hp == 98, "Concentration Portent pauses after exactly one damage occurrence")
	FighterChecks._seed_die(20, 20)
	var conc_second := SpellDamageRolls.settle_roll_choice(caster, ally, conc_first, {})
	check.call(conc_second.has("roll_choice_request") and ally.current_hp == 95 and not ally.concentrating_on.is_empty(), "Second damaging step offers its own concentration pre-roll choice")
	FighterChecks._seed_die(20, 20)
	var conc_finished := SpellDamageRolls.settle_roll_choice(caster, ally, conc_second, {})
	check.call(bool(conc_finished.get("success", false)) and ally.current_hp == 95 and int(conc_finished.get("damage", 0)) == 5 and conc_finished.step_results.size() == 2, "Concentration resume preserves exactly-once damage and completed steps")
	ally.concentrating_on.clear()
	var stale := CombatAction.resolve_spell(caster, target, spell, false, decisions)
	SpellDamageRolls.clear_pending_requests()
	check.call(bool(SpellDamageRolls.settle_roll_choice(caster, target, stale, {}).get("refused", false)) and target.current_hp == 98, "Encounter teardown invalidates pending pre-roll choices")
