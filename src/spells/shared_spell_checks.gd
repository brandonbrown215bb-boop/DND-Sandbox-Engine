## Production checks for new IDs authored only in JSON.
class_name SharedSpellChecks
extends RefCounted

static func run(check: Callable) -> void:
	DataLoader._load_content_type("res://data/fixtures/shared_spells/spells/", "spell")
	_save_context_eligibility_checks(check)
	check.call(DataLoader.get_load_errors().is_empty(), "Shared JSON fixtures load through the production loader")
	_outcome_mapping_checks(check)
	_batch_c_boundary_checks(check)
	_fact_predicate_checks(check)
	_action_history_checks(check)
	_damage_history_checks(check)
	_distance_predicate_checks(check)
	_entity_binding_checks(check)
	_relationship_query_checks(check)
	_acceptance_repair_checks(check)
	_class_level_table_checks(check)
	_formula_input_checks(check)
	_child_group_checks(check)
	_result_reducer_checks(check)
	_batch_e_boundary_checks(check)
	_damage_stage_policy_checks(check)
	_shared_result_sum_checks(check)
	_shared_prior_measure_checks(check)
	_shared_margin_hp_gate_checks(check)
	_batch_025_dice_checks(check)
	_batch_025_review_regressions(check)
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
	_p1_correction_checks(check)
	_failed_save_numeric_bonus_checks(check)
	_failed_save_outcome_override_checks(check)
	_shared_spell_attack_bonus_checks(check)
	_attack_result_adjustment_checks(check)
	_post_roll_die_bonus_checks(check)
	# Fixture loading also updates DataLoader's source index; reload one coherent
	# production registry before another logic group uses it in the same process.
	DataLoader.load_all_data()
	print("SHARED_SPELL_CHECKS_COMPLETE")


static func _damage_stage_policy_checks(check: Callable) -> void:
	DataLoader._load_content_type("res://data/fixtures/failed_save_bonus/classes/", "class")
	var neutral: Dictionary = DataLoader.get_spell("fixture:typed_reduction_neutral")
	var renamed: Dictionary = DataLoader.get_spell("fixture:occurrence_reduction_renamed")
	var bypass: Dictionary = DataLoader.get_spell("fixture:layer_bypass_neutral")
	var combined: Dictionary = DataLoader.get_spell("fixture:combined_bypass_renamed")
	check.call(not neutral.is_empty() and not renamed.is_empty() and not bypass.is_empty() and not combined.is_empty() and SharedSpell.content_error(neutral).is_empty() and SharedSpell.content_error(renamed).is_empty() and SharedSpell.content_error(bypass).is_empty() and SharedSpell.content_error(combined).is_empty(), "S-109/S-110 neutral and renamed damage policies load and validate")
	var success_feature: Dictionary = DataLoader.get_character_class("fixture:save_bonus_final_success_class").get("features_by_level", {}).get("1", [{}])[0]
	var failure_feature: Dictionary = DataLoader.get_character_class("fixture:save_bonus_final_failure_class").get("features_by_level", {}).get("1", [{}])[0]
	var payment_owner := Character.new()
	payment_owner.initialize("Predicate payment owner", "human", "wizard", AbilityScores.new())
	payment_owner.character_id = "predicate-payment-owner"
	var success_source := "fixture:final-success:chosen"
	var failure_source := "fixture:final-failure:chosen"
	var sibling_source := "fixture:final-success:sibling"
	for pair in [[success_feature, success_source], [failure_feature, failure_source], [success_feature, sibling_source]]:
		var feature: Dictionary = pair[0].duplicate(true)
		feature["source_instance_id"] = str(pair[1])
		payment_owner.features.append(feature)
		check.call(bool(ResourcePoolRules.acquire(payment_owner, pair[0], str(pair[1])).get("success", false)), "S-100 loaded result-payment source acquires exact pool %s" % str(pair[1]))
	var success_selection := {"source_instance_id": success_source, "pool_definition_id": str(success_feature.get("resource_pool", {}).get("id", "")), "cost": 1, "payment_policy": "pay_on_final_success"}
	var failure_selection := {"source_instance_id": failure_source, "pool_definition_id": str(failure_feature.get("resource_pool", {}).get("id", "")), "cost": 2, "payment_policy": "pay_on_final_failure"}
	var insufficient_selection: Dictionary = success_selection.duplicate(true)
	insufficient_selection["cost"] = 3
	var insufficient_reservation := SpellDamageRolls.begin_selected_payment(payment_owner, insufficient_selection)
	check.call(not bool(insufficient_reservation.get("success", false)) and int(ResourcePoolRules.availability(payment_owner, success_source).get("current", -1)) == 2 and int(ResourcePoolRules.availability(payment_owner, success_source).get("reserved", -1)) == 0, "S-100 upfront availability rejects a cost larger than the exact pool without reservation or charge")
	var success_reservation := SpellDamageRolls.begin_selected_payment(payment_owner, success_selection)
	var success_reserved_id := str(success_reservation.get("reservation_id", ""))
	var sibling_before := int(ResourcePoolRules.availability(payment_owner, sibling_source).get("current", -1))
	var success_reserved_state: Dictionary = ResourcePoolRules.availability(payment_owner, success_source)
	var success_refund := SpellDamageRolls.finish_selected_payment(payment_owner, success_selection, false, success_reserved_id)
	var success_refund_current := int(ResourcePoolRules.availability(payment_owner, success_source).get("current", -1))
	var success_commit_reservation := SpellDamageRolls.begin_selected_payment(payment_owner, success_selection)
	var success_commit := SpellDamageRolls.finish_selected_payment(payment_owner, success_selection, true, str(success_commit_reservation.get("reservation_id", "")))
	var failure_commit_reservation := SpellDamageRolls.begin_selected_payment(payment_owner, failure_selection)
	var failure_commit := SpellDamageRolls.finish_selected_payment(payment_owner, failure_selection, false, str(failure_commit_reservation.get("reservation_id", "")))
	var failure_commit_current := int(ResourcePoolRules.availability(payment_owner, failure_source).get("current", -1))
	var failure_refund_reservation := SpellDamageRolls.begin_selected_payment(payment_owner, failure_selection)
	var failure_refund := SpellDamageRolls.finish_selected_payment(payment_owner, failure_selection, true, str(failure_refund_reservation.get("reservation_id", "")))
	var failure_refund_current := int(ResourcePoolRules.availability(payment_owner, failure_source).get("current", -1))
	var canceled_reservation := ResourcePoolRules.reserve_payment(payment_owner, success_source, 1)
	var cancel_settlement := ResourcePoolRules.settle_payment_reservation(str(canceled_reservation.get("reservation", {}).get("reservation_id", "")), false)
	var s100_pass: bool = int(success_reserved_state.get("current", -1)) == 2 and int(success_reserved_state.get("reserved", -1)) == 1 and int(success_reserved_state.get("spendable", -1)) == 1 and success_refund.get("state", "") == "refunded" and success_refund_current == 2 and success_commit.get("state", "") == "committed" and int(ResourcePoolRules.availability(payment_owner, success_source).get("current", -1)) == 1 and failure_commit.get("state", "") == "committed" and failure_commit_current == 2 and failure_refund.get("state", "") == "refunded" and failure_refund_current == 2 and cancel_settlement.get("state", "") == "refunded" and int(ResourcePoolRules.availability(payment_owner, sibling_source).get("current", -1)) == sibling_before and int(ResourcePoolRules.availability(payment_owner, success_source).get("reserved", -1)) == 0
	check.call(s100_pass, "S-100 reserves only the selected exact pool, commits matching final success/failure, refunds mismatches and cancellation, and releases every reservation")
	var removed_reservation := ResourcePoolRules.reserve_payment(payment_owner, success_source, 1)
	ResourcePoolRules.remove(payment_owner, success_source)
	var recreated_source := ResourcePoolRules.acquire(payment_owner, success_feature, success_source)
	var removed_settlement := ResourcePoolRules.settle_payment_reservation(str(removed_reservation.get("reservation", {}).get("reservation_id", "")), true)
	check.call(bool(recreated_source.get("success", false)) and not bool(removed_settlement.get("success", false)) and str(removed_settlement.get("message", "")).contains("no payment was charged") and int(ResourcePoolRules.availability(payment_owner, success_source).get("current", -1)) == 2 and int(ResourcePoolRules.availability(payment_owner, success_source).get("reserved", -1)) == 0 and int(ResourcePoolRules.availability(payment_owner, sibling_source).get("current", -1)) == sibling_before, "S-100 removed-and-recreated source identity cannot inherit an old reservation or charge its parent/sibling")
	var caster := Character.new()
	caster.initialize("Damage policy caster", "human", "wizard", AbilityScores.new())
	caster.character_id = "damage-policy-caster"
	caster.ability_scores.intelligence = 30
	var target := Character.new()
	target.initialize("Damage policy target", "human", "fighter", AbilityScores.new())
	target.character_id = "damage-policy-target"
	target.max_hp = 100
	target.current_hp = 100
	target.temp_hp = 1
	target.ability_scores.dexterity = -100
	var reduced := CombatAction.resolve_spell(caster, target, neutral, false, {}, [], 1)
	var reduced_outcome: Dictionary = reduced.get("step_results", [])[0].get("target_outcomes", [])[0]
	var reduced_components: Array = reduced_outcome.get("damage_components", [])
	var reduction_receipts: Array = reduced_outcome.get("damage_reduction_receipts", [])
	var component_overflow := int(reduced_components[2].get("reduction_receipts", [{}])[0].get("requested", -1)) - int(reduced_components[2].get("reduction_receipts", [{}])[0].get("applied", -1))
	check.call(reduced_components.size() == 3 and reduced_components[0].get("component_id", "") == "flame" and int(reduced_components[0].get("raw", -1)) == 4 and int(reduced_components[0].get("reduction_prevented", -1)) == 2 and int(reduced_components[0].get("resolved", -1)) == 2 and int(reduced_components[0].get("absorbed", -1)) == 1 and int(reduced_components[0].get("hp_loss", -1)) == 1 and int(reduced_components[1].get("reduction_prevented", -1)) == 4 and int(reduced_components[1].get("resolved", -1)) == 0 and int(reduced_components[2].get("reduction_prevented", -1)) == 4 and component_overflow == 4 and target.current_hp == 99 and target.temp_hp == 0, "S-109 component reductions below, equal to and above typed amounts floor at zero, preserve raw/prevented/resolved/absorbed/HP-loss and discard excess")
	var pending_spell: Dictionary = neutral.duplicate(true)
	pending_spell["id"] = "fixture:pending_damage_policy_renamed"
	for component in pending_spell["steps"][0]["damage_components"]:
		component["damage"] = "1d6"
	var pending_target := Character.new()
	pending_target.initialize("Pending policy target", "human", "fighter", AbilityScores.new())
	pending_target.character_id = "pending-policy-target"
	pending_target.max_hp = 100
	pending_target.current_hp = 100
	pending_target.ability_scores.dexterity = -100
	caster.features.append({"id": "sorcerer_metamagic"})
	caster.sorcerer_metamagic_choices.append("empowered_spell")
	caster.feature_uses["sorcery_points"] = 3
	caster.ability_scores.charisma = 16
	FighterChecks._seed_die(20, 1)
	FighterChecks._seed_die(6, 1)
	var pending_damage := CombatAction.resolve_spell(caster, pending_target, pending_spell, false, {"metamagic:empowered": true, "defer_empowered": true}, [], 1)
	var pending_damage_id := str(pending_damage.get("damage_request", {}).get("request_id", ""))
	var pending_hp_before := pending_target.current_hp
	var pending_points_before := caster.get_sorcery_points()
	var wrong_occurrence := CombatAction.finish_pending_spell_damage(caster, pending_target, {"damage_request": {"request_id": pending_damage_id + ":wrong"}}, {"metamagic:empowered_dice": [0]})
	check.call(not pending_damage_id.is_empty() and pending_target.current_hp == pending_hp_before and wrong_occurrence.get("refused", false) and caster.get_sorcery_points() == pending_points_before, "S-109 pending typed occurrence rejects a wrong occurrence before spending Empowered points or applying damage")
	FighterChecks._seed_die(6, 6)
	var pending_final := CombatAction.finish_pending_spell_damage(caster, pending_target, pending_damage, {"metamagic:empowered_dice": [0]})
	var pending_outcomes: Array = pending_final.get("step_results", [])[0].get("target_outcomes", [])
	var pending_components: Array = pending_outcomes[0].get("damage_components", []) if not pending_outcomes.is_empty() else []
	var pending_replay := CombatAction.finish_pending_spell_damage(caster, pending_target, {"damage_request": {"request_id": pending_damage_id}}, {"metamagic:empowered_dice": [0]})
	check.call(pending_components.size() == 3 and int(pending_components[0].get("raw", -1)) == 6 and int(pending_components[0].get("reduction_prevented", -1)) == 2 and int(pending_components[0].get("resolved", -1)) == 4 and int(pending_components[1].get("resolved", -1)) == 0 and int(pending_components[2].get("resolved", -1)) == 0 and pending_target.current_hp == 96 and caster.get_sorcery_points() == pending_points_before - 1 and pending_replay.get("refused", false), "S-109 applies reductions once after the real deferred damage roll, preserves component receipts and refuses replay")
	pending_target.current_hp = 100
	FighterChecks._seed_die(20, 1)
	FighterChecks._seed_die(6, 1)
	var teardown_pending := CombatAction.resolve_spell(caster, pending_target, pending_spell, false, {"metamagic:empowered": true, "defer_empowered": true}, [], 1)
	SpellDamageRolls.clear_pending_requests()
	var stale_after_teardown := CombatAction.finish_pending_spell_damage(caster, pending_target, teardown_pending, {"metamagic:empowered_dice": [0]})
	check.call(teardown_pending.has("damage_request") and stale_after_teardown.get("refused", false) and pending_target.current_hp == 100 and caster.get_sorcery_points() == pending_points_before - 1 and ResourcePoolRules._payment_reservations.is_empty(), "S-109 teardown invalidates a pending policy occurrence without hidden reservations, new point cost or stale damage")
	var miss_spell: Dictionary = neutral.duplicate(true)
	miss_spell["id"] = "fixture:miss_damage_policy_renamed"
	miss_spell["steps"][0]["type"] = "attack"
	miss_spell["steps"][0]["attack_type"] = "ranged_spell"
	miss_spell["steps"][0].erase("save")
	miss_spell["steps"][0].erase("damage_components")
	miss_spell["steps"][0]["damage"] = "4"
	miss_spell["steps"][0]["damage_type"] = "fire"
	miss_spell["steps"][0]["damage_reductions"] = [{"scope": "occurrence", "amount": 2, "stage": "after_scale_before_mitigation"}]
	var miss_target := {"name": "Policy miss target", "current_hp": 100, "max_hp": 100, "is_alive": true, "armor_class": 1000, "conditions": {}}
	var miss_result := CombatAction.resolve_spell(caster, miss_target, miss_spell, false, {}, [], 1)
	var miss_step_results: Array = miss_result.get("step_results", [])
	var miss_target_outcomes: Array = miss_step_results[0].get("target_outcomes", []) if not miss_step_results.is_empty() else []
	var miss_damage_components: Array = miss_target_outcomes[0].get("damage_components", []) if not miss_target_outcomes.is_empty() else []
	check.call(not bool(miss_result.get("hit", true)) and miss_damage_components.is_empty() and int(miss_target.get("current_hp", 0)) == 100 and ResourcePoolRules._payment_reservations.is_empty(), "S-109 final miss never starts a damage occurrence, applies reduction, spends a damage-only resource or leaves a reservation")
	var whole_target := Character.new()
	whole_target.initialize("Whole occurrence target", "human", "fighter", AbilityScores.new())
	whole_target.character_id = "whole-occurrence-target"
	whole_target.max_hp = 100
	whole_target.current_hp = 100
	whole_target.ability_scores.dexterity = -100
	var whole := CombatAction.resolve_spell(caster, whole_target, renamed, false, {}, [], 1)
	var whole_outcome: Dictionary = whole.get("step_results", [])[0].get("target_outcomes", [])[0]
	var whole_components: Array = whole_outcome.get("damage_components", [])
	var whole_receipt: Dictionary = whole_outcome.get("damage_reduction_receipts", [])[0]
	check.call(int(whole_receipt.get("requested", -1)) == 10 and int(whole_receipt.get("applied", -1)) == 9 and int(whole_receipt.get("overflow", -1)) == 1 and whole_receipt.get("allocated_component_ids", []) == ["ember", "rime", "spore"] and whole_components.all(func(c): return int(c.get("resolved", -1)) == 0 and int(c.get("hp_loss", -1)) == 0) and whole_target.current_hp == 100, "S-109 whole-occurrence actor formula is floored, allocated in declared component order and excess is discarded")
	var ward_target := Character.new()
	ward_target.initialize("Layer bypass target", "human", "fighter", AbilityScores.new())
	ward_target.character_id = "layer-bypass-target"
	ward_target.max_hp = 100
	ward_target.current_hp = 100
	ward_target.temp_hp = 2
	ward_target.ability_scores.dexterity = -100
	ward_target.feature_uses["damage_resistances"] = ["fire", "cold"]
	ward_target.feature_uses["damage_immunities"] = ["cold"]
	ward_target.features.append({"id": "fixture:policy_ward", "effects": [{"type": "damage_ward_pool", "pool_id": "policy_ward", "trigger_schools": ["Abjuration"], "max_hp_level_multiplier": 0, "max_hp_flat_bonus": 3}]})
	WardRules.on_slot_spell_cast(ward_target, {"level": 1, "school": "Abjuration"}, 1)
	var layers := CombatAction.resolve_spell(caster, ward_target, bypass, false, {}, [], 1)
	var layer_outcome: Dictionary = layers.get("step_results", [])[0].get("target_outcomes", [])[0]
	var layer_components: Array = layer_outcome.get("damage_components", [])
	check.call(int(layer_components[0].get("resolved", -1)) == 4 and layer_components[1].get("bypass_layers", []).size() == 1 and int(layer_components[1].get("resolved", -1)) == 1 and int(layer_components[1].get("prevented", -1)) == 3 and layer_components[2].get("bypass_layers", []).size() == 1 and int(layer_components[2].get("resolved", -1)) == 2 and layer_components[2].get("bypass_layers", []) == ["immunity"] and int(layer_components[3].get("resolved", -1)) == 4 and int(layer_outcome.get("ward_absorbed", -1)) == 3 and int(ward_target.damage_wards.pools.policy_ward.current_hp) == 0 and ward_target.temp_hp == 0 and ward_target.current_hp == 91, "S-110 independently bypasses ward, Resistance or Immunity while unselected layers, unrelated components, ward and Temporary HP keep normal order")
	var sphere_target := Character.new()
	sphere_target.initialize("Prevention bypass target", "human", "fighter", AbilityScores.new())
	sphere_target.character_id = "prevention-bypass-target"
	sphere_target.max_hp = 100
	sphere_target.current_hp = 100
	sphere_target.ability_scores.dexterity = -100
	sphere_target.add_condition("resilient_sphere", 10)
	var prevention := CombatAction.resolve_spell(caster, sphere_target, bypass, false, {}, [], 1)
	var prevention_steps: Array = prevention.get("step_results", [])
	var prevention_outcomes: Array = prevention_steps[0].get("target_outcomes", []) if not prevention_steps.is_empty() else []
	var prevention_components: Array = prevention_outcomes[0].get("damage_components", []) if not prevention_outcomes.is_empty() else []
	check.call(prevention_components.size() == 4 and int(prevention_components[0].get("resolved", -1)) == 0 and int(prevention_components[1].get("resolved", -1)) == 0 and int(prevention_components[2].get("resolved", -1)) == 0 and int(prevention_components[3].get("resolved", -1)) == 4 and sphere_target.current_hp == 96, "S-110 prevention bypass applies only to the selected component; Resilient Sphere still blocks siblings")
	var combined_target := Character.new()
	combined_target.initialize("Combined bypass target", "human", "fighter", AbilityScores.new())
	combined_target.character_id = "combined-bypass-target"
	combined_target.max_hp = 100
	combined_target.current_hp = 100
	combined_target.ability_scores.dexterity = -100
	combined_target.feature_uses["damage_resistances"] = ["fire"]
	combined_target.feature_uses["damage_immunities"] = ["fire"]
	combined_target.add_condition("resilient_sphere", 10)
	combined_target.features.append({"id": "fixture:combined_ward", "effects": [{"type": "damage_ward_pool", "pool_id": "combined_ward", "trigger_schools": ["Abjuration"], "max_hp_level_multiplier": 0, "max_hp_flat_bonus": 3}]})
	WardRules.on_slot_spell_cast(combined_target, {"level": 1, "school": "Abjuration"}, 1)
	var combination := CombatAction.resolve_spell(caster, combined_target, combined, false, {}, [], 1)
	var combination_components: Array = combination.get("step_results", [])[0].get("target_outcomes", [])[0].get("damage_components", [])
	var ordinary := CombatAction.resolve_damage(combined_target, 4, "fire", {}, false, false, caster)
	check.call(int(combination_components[0].get("resolved", -1)) == 4 and combination_components[0].get("bypass_layers", []) == ["resistance", "immunity", "ward", "prevention"] and int(combination_components[1].get("resolved", -1)) == 0 and int(ordinary.get("resolved", -1)) == 0 and combined_target.current_hp == 96, "S-110 combined layers stay on one loaded source/component, siblings and a later source retain normal prevention")
	var invalid := neutral.duplicate(true)
	invalid.steps[0].damage_bypasses = [{"scope": "occurrence", "layers": ["resistance", "everything"], "stage": "mitigation"}]
	check.call(not SharedSpell.content_error(invalid).is_empty(), "S-110 unsupported bypass layers reject during content preflight")


## Regressions for the acceptance review's numeric, window and outcome defects.
static func _s029_cast_host(caster: Character, target: Character, spell: Dictionary) -> SpellCastContext:
	var host := SpellCastContext.new()
	host.caster = caster
	host.spell = spell
	host.spell_origin = Vector2i.ZERO
	host.target_coord = Vector2i(2, 0)
	host.grid = HexGrid.new()
	for x in range(-2, 3):
		for y in range(-2, 3):
			var tile := HexTile.new()
			tile.coord = Vector2i(x, y)
			host.grid.add_tile(tile)
	host.players = [{"character": target, "hex_position": host.target_coord}]
	host.owner_label_for_character = func(_owner): return "Save Owner"
	return host


static func _s029_attach_source(target: Character, feature: Dictionary) -> String:
	var source_id := str(feature.get("id", "")) + ":owned"
	var owned := feature.duplicate(true)
	owned["source_instance_id"] = source_id
	target.features.append(owned)
	ResourcePoolRules.acquire(target, owned, source_id)
	return source_id


static func _save_context_eligibility_checks(check: Callable) -> void:
	DataLoader._load_content_type("res://data/fixtures/s029/classes/", "class")
	DataLoader._load_content_type("res://data/fixtures/s029/spells/", "spell")
	var see_class: Dictionary = DataLoader.get_character_class("fixture:s029_sense_class")
	var darkvision_class: Dictionary = DataLoader.get_character_class("fixture:s029_darkvision_class")
	var see_feature: Dictionary = see_class.get("features_by_level", {}).get("1", [{}])[0]
	var darkvision_feature: Dictionary = darkvision_class.get("features_by_level", {}).get("1", [{}])[0]
	var avoid_spell: Dictionary = DataLoader.get_spell("fixture:s029_poison_avoid")
	var end_spell: Dictionary = DataLoader.get_spell("fixture:s029_toxin_end")
	var maintain_spell: Dictionary = DataLoader.get_spell("fixture:s029_poison_maintain")
	var ordinary_spell: Dictionary = DataLoader.get_spell("fixture:s029_ordinary_con")
	check.call(not see_feature.is_empty() and not darkvision_feature.is_empty() and SharedSpell.content_error(avoid_spell).is_empty() and SharedSpell.content_error(end_spell).is_empty() and SharedSpell.content_error(maintain_spell).is_empty() and SharedSpell.content_error(ordinary_spell).is_empty(), "Neutral/renamed save contexts and ordinary Constitution control load and validate")
	var malformed_context := avoid_spell.duplicate(true)
	malformed_context["save_context"]["purpose_id"] = "Avoiding poison"
	check.call(not SharedSpell.content_error(malformed_context).is_empty(), "Save cause and purpose are structured identifier fields, never prose")
	var malformed_steps := avoid_spell.duplicate(true)
	malformed_steps["steps"] = null
	check.call(not SharedSpell.content_error(malformed_steps).is_empty(), "Malformed step containers refuse before the save-context scan")

	var caster := Character.new()
	caster.initialize("S029 Cause", "human", "wizard", AbilityScores.new())
	caster.character_id = "fixture:s029_origin_caster"
	var target := Character.new()
	target.initialize("S029 Save Owner", "human", "fighter", AbilityScores.new())
	target.character_id = "fixture:s029_save_owner"
	target.ability_scores.constitution = -100
	target.current_hp = 100
	target.max_hp = 100
	var see_source := _s029_attach_source(target, see_feature)
	var test_hud := CombatHUD.new()
	var see_host := _s029_cast_host(caster, target, avoid_spell)
	see_host.hud = test_hud
	var see_pending := CombatAction.resolve_spell(caster, target, avoid_spell, false, {"cast_context": see_host}, [], 0, -1, see_host)
	var see_record := SpellDamageRolls.failed_save_numeric_bonus_record(caster, target, see_pending)
	var see_choice: Dictionary = {}
	for option in see_record.get("options", []):
		if str(option.get("source_instance_id", "")) == see_source: see_choice = option
	var captured_context: Dictionary = see_record.get("save_test", {}).get("save_context", {})
	check.call(see_pending.has("save_bonus_request") and not see_choice.is_empty() and str(captured_context.get("cause_id", "")) == "poison_exposure" and str(captured_context.get("purpose_id", "")) == "avoid" and str(captured_context.get("origin_effect_id", "")) == "spore_burst" and str(captured_context.get("spell_definition_id", "")) == str(avoid_spell.get("id", "")) and str(captured_context.get("source_definition_id", "")) == str(avoid_spell.get("id", "")) and str(captured_context.get("source_owner_id", "")) == caster.character_id, "Sight-gated CON modifier captures the loaded cause, avoid purpose, originating effect, exact spell/source owner, and the existing save-choice request")
	var see_tile: HexTile = see_host.grid.get_tile(Vector2i(1, 0))
	see_tile.custom_properties["blocks_sight"] = true
	var changed_sense := SpellDamageRolls.settle_failed_save_numeric_bonus(caster, target, see_pending, see_source)
	check.call(bool(changed_sense.get("refused", false)) and int(ResourcePoolRules.availability(target, see_source).get("current", -1)) == 4, "Sight is rechecked when the paused save choice commits; changed availability refuses without payment")
	see_tile.custom_properties["blocks_sight"] = false
	var settled := SpellDamageRolls.settle_failed_save_numeric_bonus(caster, target, see_pending, see_source)
	check.call(bool(settled.get("success", false)) and str(settled.get("save_context", {}).get("origin_effect_id", "")) == "spore_burst" and int(ResourcePoolRules.availability(target, see_source).get("current", -1)) == 3, "Restored sense permits the same captured choice to settle once with its original context")

	var target_end := Character.new()
	target_end.initialize("S029 Renamed Owner", "human", "fighter", AbilityScores.new())
	target_end.character_id = "fixture:s029_renamed_owner"
	target_end.ability_scores.constitution = -100
	target_end.darkvision_feet = 60
	var darkvision_source := _s029_attach_source(target_end, darkvision_feature)
	var end_host := _s029_cast_host(caster, target_end, end_spell)
	end_host.hud = test_hud
	var end_pending := CombatAction.resolve_spell(caster, target_end, end_spell, false, {"cast_context": end_host}, [], 0, -1, end_host)
	var end_record := SpellDamageRolls.failed_save_numeric_bonus_record(caster, target_end, end_pending)
	var end_choice: Dictionary = end_record.get("options", [{}])[0] if not end_record.get("options", []).is_empty() else {}
	check.call(end_pending.has("save_bonus_request") and str(end_choice.get("cause_id", "")) == "toxin_condition" and str(end_choice.get("purpose_id", "")) == "end" and str(end_choice.get("required_sense", "")) == "darkvision", "Renamed loaded consumer selects only its distinct originating cause, end purpose, and represented darkvision requirement")
	target_end.add_condition("blinded", 1, "review:blind")
	var blind_end := SpellDamageRolls.settle_failed_save_numeric_bonus(caster, target_end, end_pending, darkvision_source)
	check.call(bool(blind_end.get("refused", false)) and int(ResourcePoolRules.availability(target_end, darkvision_source).get("current", -1)) == 4, "Darkvision cannot qualify a blinded save owner or charge its paused source")
	target_end.remove_condition("blinded")
	end_host.grid.get_tile(Vector2i(1, 0)).custom_properties["blocks_sight"] = true
	check.call(SpellDamageRolls.failed_save_choice_options(target_end, "CON", false, end_record.get("cast")).is_empty(), "Darkvision cannot qualify through a represented wall")
	end_host.grid.get_tile(Vector2i(1, 0)).custom_properties["blocks_sight"] = false
	var wrong_purpose := SpellDamageRolls.failed_save_choice_options(target, "CON", false, _s029_make_resolution(caster, target, maintain_spell, see_host))
	check.call(wrong_purpose.is_empty(), "Maintaining a condition does not match an otherwise identical CON save declared to end it")
	var ordinary := SpellDamageRolls.failed_save_choice_options(target_end, "CON", false, _s029_make_resolution(caster, target_end, ordinary_spell, end_host))
	check.call(ordinary.is_empty(), "An ordinary Constitution save with the same ability and DC receives no cause-specific source")

	var unknown_sense_effect := see_feature.duplicate(true)
	unknown_sense_effect["passive_effects"][0]["required_sense"] = "hearing"
	var unknown_sense_target := Character.new()
	unknown_sense_target.initialize("Unknown Sense Owner", "human", "fighter", AbilityScores.new())
	unknown_sense_target.character_id = "fixture:s029_unknown_sense_owner"
	var unknown_source := _s029_attach_source(unknown_sense_target, unknown_sense_effect)
	var unknown_host := _s029_cast_host(caster, unknown_sense_target, avoid_spell)
	unknown_host.hud = test_hud
	var unknown_context := _s029_make_resolution(caster, unknown_sense_target, avoid_spell, unknown_host)
	check.call(not unknown_source.is_empty() and SpellDamageRolls.failed_save_choice_options(unknown_sense_target, "CON", false, unknown_context).is_empty(), "Unknown hearing capability stays unavailable rather than falling back to sight")

	SpellDamageRolls.clear_pending_requests()
	for test_host in [see_host, end_host, unknown_host]:
		test_host.hud = null
		if is_instance_valid(test_host.grid): test_host.grid.free()
	if is_instance_valid(test_hud): test_hud.free()


static func _s029_make_resolution(caster: Character, target: Character, spell: Dictionary, host: SpellCastContext) -> SpellResolutionContext:
	var cast := SpellResolutionContext.new()
	cast.caster = caster
	cast.target = target
	cast.spell = spell
	cast.spatial_host = host
	cast.spell_definition_id = str(spell.get("id", ""))
	cast.source_definition_id = cast.spell_definition_id
	cast.source_instance_id = "fixture:s029-origin-instance"
	cast.source_owner_id = caster.character_id
	cast.invocation_id = "fixture:s029-origin-invocation"
	return cast
static func _outcome_mapping_checks(check: Callable) -> void:
	var attack := DataLoader.get_spell("sandbox:outcome_attack_neutral")
	var ordered_attack := DataLoader.get_spell("sandbox:outcome_attack_ordered")
	var save := DataLoader.get_spell("sandbox:outcome_save_renamed")
	var ordered_save := DataLoader.get_spell("sandbox:outcome_save_ordered_renamed")
	check.call(not attack.is_empty() and not ordered_attack.is_empty() and not save.is_empty() and not ordered_save.is_empty() and [attack, ordered_attack, save, ordered_save].all(func(spell): return SharedSpell.content_error(spell).is_empty()), "Neutral attack and renamed save outcome maps load and validate for flat and ordered delivery")
	var invalid_attack: Dictionary = attack.duplicate(true)
	invalid_attack["damage_scale_by_outcome"] = {"hit": 1}
	var invalid_rider: Dictionary = save.duplicate(true)
	invalid_rider["effects"][0]["rider_by_outcome"] = {"failure": true}
	var invalid_scale: Dictionary = ordered_save.duplicate(true)
	invalid_scale["steps"][0]["damage_scale_by_outcome"] = {"success": 0.5, "failure": 2}
	check.call(not SharedSpell.content_error(invalid_attack).is_empty() and not SharedSpell.content_error(invalid_rider).is_empty() and not SharedSpell.content_error(invalid_scale).is_empty(), "Outcome maps reject absent outcomes and unsupported scales during preflight")
	var caster := Character.new()
	caster.initialize("Outcome caster", "human", "wizard", AbilityScores.new())
	caster.character_id = "s098-caster"
	var miss_target := {"id": "s098-miss", "name": "Miss target", "current_hp": 100, "max_hp": 100, "is_alive": true, "armor_class": 100, "conditions": {}, "condition_sources": {}, "temp_hp": 0}
	FighterChecks._seed_die(20, 5)
	var miss := CombatAction.resolve_spell(caster, miss_target, attack, false, {}, [], 1, 5)
	check.call(not bool(miss.get("hit", true)) and int(miss.get("damage", 0)) == 2 and miss.get("damage_scale_decision", {}).get("outcome", "") == "miss" and not CombatAction.has_condition(miss_target, "frightened") and miss.get("rider_decisions", []).size() == 1 and not bool(miss["rider_decisions"][0].get("eligible", true)), "Flat attack miss remains a miss, floors half of odd damage, records both decisions, and suppresses its hit-only condition")
	var hit_target := {"id": "s098-hit", "name": "Hit target", "current_hp": 100, "max_hp": 100, "is_alive": true, "armor_class": -100, "conditions": {}, "condition_sources": {}, "temp_hp": 0}
	FighterChecks._seed_die(20, 10)
	var hit := CombatAction.resolve_spell(caster, hit_target, attack, false, {}, [], 1, 5)
	check.call(bool(hit.get("hit", false)) and int(hit.get("damage", 0)) == 5 and CombatAction.has_condition(hit_target, "frightened") and bool(hit.get("rider_decisions", [])[0].get("eligible", false)), "Flat attack hit uses its independent full-damage entry and applies its hit-only rider")
	var ordered_target := {"id": "s098-ordered-miss", "name": "Ordered miss target", "current_hp": 100, "max_hp": 100, "is_alive": true, "armor_class": 100, "conditions": {}, "condition_sources": {}, "temp_hp": 0}
	FighterChecks._seed_die(20, 5)
	var ordered_miss := CombatAction.resolve_spell(caster, ordered_target, ordered_attack, false, {}, [], 1, 5)
	var ordered_occurrence: Dictionary = ordered_miss.get("step_results", [])[0].get("target_outcomes", [])[0]
	check.call(not bool(ordered_occurrence.get("hit", true)) and int(ordered_occurrence.get("damage", 0)) == 2 and ordered_occurrence.get("damage_scale_decision", {}).get("outcome", "") == "miss" and ordered_occurrence.get("rider_decisions", []).size() == 1 and not bool(ordered_occurrence["rider_decisions"][0].get("eligible", true)) and not CombatAction.has_condition(ordered_target, "frightened") and int(ordered_target.get("temp_hp", 0)) == 1, "Ordered attack miss exposes its per-target maps, settles half damage without its hit rider, then continues to its following step")
	var fail_target := Character.new()
	fail_target.initialize("Save failure", "human", "fighter", AbilityScores.new())
	fail_target.character_id = "s098-save-fail"
	FighterChecks._seed_die(20, 1)
	var failed := CombatAction.resolve_spell(caster, fail_target, save, false, {}, [], 1, 5)
	check.call(not bool(failed.get("saved", true)) and int(failed.get("damage", 0)) == 5 and CombatAction.has_condition(fail_target, "restrained") and failed.get("damage_scale_decision", {}).get("outcome", "") == "failure", "Renamed flat save applies its configured failure damage and condition maps")
	var success_target := Character.new()
	success_target.initialize("Save success", "human", "fighter", AbilityScores.new())
	success_target.character_id = "s098-save-success"
	FighterChecks._seed_die(20, 20)
	var succeeded := CombatAction.resolve_spell(caster, success_target, save, false, {}, [], 1, 5)
	check.call(bool(succeeded.get("saved", false)) and int(succeeded.get("damage", 0)) == 2 and not CombatAction.has_condition(success_target, "restrained") and succeeded.get("damage_scale_decision", {}).get("outcome", "") == "success", "Renamed flat save floors half of odd damage after success and suppresses the failure-only condition")
	var ordered_save_target := Character.new()
	ordered_save_target.initialize("Ordered save failure", "human", "fighter", AbilityScores.new())
	ordered_save_target.character_id = "s098-ordered-save-failure"
	FighterChecks._seed_die(20, 1)
	var ordered_failed := CombatAction.resolve_spell(caster, ordered_save_target, ordered_save, false, {}, [], 1, 5)
	var ordered_save_result: Dictionary = ordered_failed.get("step_results", [])[0].get("target_outcomes", [])[0]
	check.call(not bool(ordered_save_result.get("saved", true)) and int(ordered_save_result.get("damage", 0)) == 5 and ordered_save_result.get("damage_scale_decision", {}).get("outcome", "") == "failure" and ordered_save_result.get("rider_decisions", []).size() == 1 and bool(ordered_save_result["rider_decisions"][0].get("eligible", false)) and CombatAction.has_condition(ordered_save_target, "restrained") and ordered_save_target.temp_hp == 1, "Ordered renamed save exposes its per-target failure maps and continues to its following step")
	var ordered_success_target := Character.new()
	ordered_success_target.initialize("Ordered save success", "human", "fighter", AbilityScores.new())
	ordered_success_target.character_id = "s098-ordered-save-success"
	FighterChecks._seed_die(20, 20)
	var ordered_succeeded := CombatAction.resolve_spell(caster, ordered_success_target, ordered_save, false, {}, [], 1, 5)
	var ordered_success_result: Dictionary = ordered_succeeded.get("step_results", [])[0].get("target_outcomes", [])[0]
	check.call(bool(ordered_success_result.get("saved", false)) and int(ordered_success_result.get("damage", 0)) == 2 and not CombatAction.has_condition(ordered_success_target, "restrained") and ordered_success_target.temp_hp == 1, "Ordered renamed save applies its success scale independently, suppresses the failure rider and continues once")


static func _batch_c_boundary_checks(check: Callable) -> void:
	var caster := Character.new()
	caster.initialize("Batch C caster", "human", "wizard", AbilityScores.new())
	caster.character_id = "batch-c-review-caster"
	var ordered := DataLoader.get_spell("sandbox:outcome_save_ordered_renamed").duplicate(true)
	for explicit_id in [true, false]:
		var component := {"damage": "5", "damage_type": "cold"}
		if explicit_id: component["id"] = "only_cold"
		var expected_id := "only_cold" if explicit_id else "cold:1"
		ordered["steps"][0].erase("damage")
		ordered["steps"][0].erase("damage_type")
		ordered["steps"][0]["damage_components"] = [component]
		ordered["steps"][1]["effects"][0]["value"] = {"result": {"step": "save", "target": "same", "component": "cold", "component_id": expected_id, "measure": "raw"}}
		var target := {"id": "batch-c-component", "name": "Single component", "current_hp": 100, "max_hp": 100, "is_alive": true, "ability_scores": {"DEX": 100}, "conditions": {}, "temp_hp": 0}
		var result := CombatAction.resolve_spell(caster, target, ordered, false, {}, [], 1, 5)
		var outcomes: Array = result.get("step_results", [])[0].get("target_outcomes", [])
		check.call(SharedSpell.content_error(ordered).is_empty() and int(target["current_hp"]) == 98 and int(target["temp_hp"]) == 2 and outcomes[0].get("damage_components", [])[0].get("component_id", "") == expected_id, "Single-entry component list retains %s identity through mapped damage and a later authored consumer" % expected_id)
	var automatic := DataLoader.get_spell("sandbox:outcome_save_renamed").duplicate(true)
	automatic.erase("save")
	automatic["effects"] = []
	var automatic_rider := automatic.duplicate(true)
	automatic_rider.erase("damage_scale_by_outcome")
	automatic_rider["effects"] = [{"type": "temporary_hp", "value": 9, "rider_by_outcome": {"success": false, "failure": true}}]
	var outer_map := ordered.duplicate(true)
	outer_map["damage_scale_by_outcome"] = {"success": 0, "failure": 0}
	var outer_rider := ordered.duplicate(true)
	outer_rider["effects"] = automatic_rider["effects"].duplicate(true)
	for malformed in [automatic, automatic_rider, outer_map, outer_rider]:
		var target := {"id": "batch-c-preflight", "name": "Preflight target", "current_hp": 100, "max_hp": 100, "is_alive": true, "ability_scores": {"DEX": 100}, "conditions": {}, "temp_hp": 0}
		caster.spell_slots["1"] = 2
		var result := CombatAction.resolve_spell(caster, target, malformed, true, {}, [], 1, 5)
		check.call(not SharedSpell.content_error(malformed).is_empty() and not bool(result.get("success", true)) and int(caster.spell_slots["1"]) == 2 and int(target["current_hp"]) == 100 and int(target["temp_hp"]) == 0, "Outcome maps without a flat attack/save or an owning ordered step refuse before slot payment and effects (%s)" % str(malformed.keys()))
	for scale in [0.0, 0.5]:
		var attack := DataLoader.get_spell("sandbox:outcome_attack_neutral").duplicate(true)
		attack["damage_scale_by_outcome"]["hit"] = scale
		var defender := Character.new()
		defender.initialize("Dodging mapped hit", "human", "fighter", AbilityScores.new())
		defender.character_id = "batch-c-dodge"
		defender.max_hp = 100
		defender.current_hp = 100
		defender.features.append({"id": "rogue_uncanny_dodge"})
		FighterChecks._seed_die(20, 19)
		var result := CombatAction.resolve_spell(caster, defender, attack, false, {"uncanny_dodge": true}, [], 1, 5)
		var expected_damage := int(floor(5.0 * scale * 0.5))
		check.call(bool(result.get("hit", false)) and int(result.get("damage", -1)) == expected_damage and defender.current_hp == 100 - expected_damage and is_equal_approx(float(result.get("damage_scale_decision", {}).get("scale", -1)), scale), "Uncanny Dodge halves the authored hit scale %s without replacing the map decision or creating damage" % str(scale))
	randomize()


static func _acceptance_repair_checks(check: Callable) -> void:
	var caster := Character.new()
	caster.initialize("Review Caster", "human", "wizard", AbilityScores.new())
	caster.character_id = "review-window-caster"
	var numeric_effects: Array = JSON.parse_string('[{"type":"heal","value":5},{"type":"temporary_hp","value":7}]')
	var target := Character.new()
	target.initialize("Review Target", "human", "fighter", AbilityScores.new())
	target.character_id = "review-window-target"
	target.max_hp = 100
	target.current_hp = 1
	SharedSpell.apply_custom_effects(caster, target, numeric_effects, {}, 1)
	check.call(target.current_hp == 6 and target.temp_hp == 7, "Integral JSON numeric healing and Temporary HP reach Character recipients as fixed amounts")
	var monster := {"id": "review-window-monster", "name": "Review Monster", "current_hp": 1, "max_hp": 100, "is_alive": true, "armor_class": 5, "temp_hp": 0, "conditions": {}}
	SharedSpell.apply_custom_effects(caster, monster, numeric_effects, {}, 1)
	check.call(int(monster["current_hp"]) == 6 and int(monster["temp_hp"]) == 7, "Integral JSON numeric healing and Temporary HP also reach dictionary recipients")
	check.call(not SharedSpell._validate_single_effect({"type": "heal", "value": 5.5}).is_empty(), "Fractional scalar healing remains invalid rather than being silently truncated")
	monster["current_hp"] = 100
	monster["temp_hp"] = 0
	var spell: Dictionary = DataLoader.get_spell("sandbox:owned_spell_attack_renamed").duplicate(true)
	FighterChecks._seed_die(20, 20)
	var direct := CombatAction.resolve_spell(caster, monster, spell)
	check.call(bool(direct.get("hit", false)) and CombatAction.has_condition(monster, "deafened") and CombatAction.has_condition(monster, "restrained"), "Direct ordered attack effects and following effects consume the actual post-damage window")
	var cast := SpellResolutionContext.new()
	cast.caster = caster
	cast.target = monster
	cast.spell = spell
	cast.spell_definition_id = str(spell["id"])
	cast.effect_cast = SpellEffects.begin_cast(caster, spell)
	var adapter := SharedStepExecutor.SpellAdapter.new(cast)
	var step: Dictionary = spell["steps"][1]
	FighterChecks._seed_die(20, 20)
	adapter.resolve_attack_step(step, monster, 1, 0, [], 0, [], false, true, false, false, [], [monster], 0, true)
	var first_occurrence := str(cast.resolution_window.get("occurrence_id", ""))
	check.call(SharedStepExecutor.evaluate_predicate({"fact": "resolution.window", "eq": "post_damage"}, adapter, monster, []) and not SharedStepExecutor.evaluate_predicate({"fact": "resolution.window", "eq": "post_damage"}, adapter, caster, []), "Current ordered receipt qualifies its exact recipient but cannot qualify another actor")
	# The first fixture hit restrained this target. Remove that Advantage before
	# seeding the single natural-1 miss used to check a new occurrence.
	SpellEffects.consume_spell(monster, str(spell["id"]))
	monster["conditions"] = {}
	FighterChecks._seed_die(20, 1)
	adapter.resolve_attack_step(step, monster, 1, 0, [], 0, [], false, true, false, false, [], [monster], 0, true)
	check.call(str(cast.resolution_window.get("occurrence_id", "")) != first_occurrence and not SharedStepExecutor.evaluate_predicate({"fact": "resolution.window", "eq": "post_damage"}, adapter, monster, []) and not SharedStepExecutor._read_fact("resolution.damage_hp_loss", adapter, monster).get("available", false), "A fresh missed occurrence replaces the previous damage window and cannot reuse its facts")
	DataLoader._load_content_type("res://data/fixtures/failed_save_bonus/classes/", "class")
	var override_class: Dictionary = DataLoader.get_character_class("fixture:save_success_override_class")
	var feature: Dictionary = override_class["features_by_level"]["1"][1]
	for domain in ["weapon_attack", "shared_spell_attack"]:
		var mixed := feature.duplicate(true)
		mixed["passive_effects"].append({"type": "weapon_attack_numeric_bonus", "domains": [domain], "amount": 1, "cost": 1})
		var override_first := DataLoader._feature_content_error(mixed)
		mixed["passive_effects"].reverse()
		check.call(not override_first.is_empty() and not DataLoader._feature_content_error(mixed).is_empty(), "Same-source numeric/outcome conflict refuses in both authoring orders for %s" % domain)
		var duplicate := feature.duplicate(true)
		duplicate["passive_effects"].append(feature["passive_effects"][0].duplicate(true))
		check.call(not DataLoader._feature_content_error(duplicate).is_empty(), "Duplicate attack outcome declarations cannot produce ambiguous source choices")
		var actor := Character.new()
		actor.initialize("Review Peerless", "human", "fighter", AbilityScores.new())
		actor.character_id = "review-peerless-%s" % domain
		actor.fighter_training["boon"] = "combat_prowess"
		var source := "review:override:%s" % domain
		var owned := feature.duplicate(true)
		owned["source_instance_id"] = source
		actor.features.append(owned)
		ResourcePoolRules.acquire(actor, feature, source)
		target.current_hp = 100
		target.temp_hp = 0
		var hud := CombatHUD.new()
		var host := SpellCastContext.new()
		host.caster = actor
		host.hud = hud
		host.owner_label_for_character = func(_owner): return "Owner"
		FighterChecks._seed_die(20, 20)
		var pending: Dictionary
		if domain == "weapon_attack":
			pending = CombatAction.resolve_weapon_attack(actor, target, {"name": "Review Weapon", "damage": "1d6", "damage_type": "slashing", "ability": "STR", "range": 1}, false, false, {"allow_weapon_attack_bonus": true})
		else:
			pending = CombatAction.resolve_spell(actor, target, DataLoader.get_spell("sandbox:owned_spell_attack_neutral"), false, {"cast_context": host}, [], 1, 12)
		var final := SpellDamageRolls.settle_weapon_attack_bonus(actor, target, pending, source)
		check.call(pending.has("weapon_attack_bonus_request") and not bool(final.get("hit", true)) and target.current_hp == 100 and not bool(actor.feature_uses.get("epic_boon_combat_prowess_used", false)) and int(ResourcePoolRules.availability(actor, source).get("current", -1)) == 3, "Forced miss charges its source once and preserves unused Peerless Aim for %s" % domain)
		SpellDamageRolls.clear_pending_requests()
		host.hud = null
		hud.free()


static func _failed_save_outcome_override_checks(check: Callable) -> void:
	DataLoader._load_content_type("res://data/fixtures/failed_save_bonus/classes/", "class")
	var neutral_class: Dictionary = DataLoader.get_character_class("fixture:save_success_override_class")
	var renamed_class: Dictionary = DataLoader.get_character_class("fixture:resolute_success_class")
	var neutral_feature: Dictionary = neutral_class.get("features_by_level", {}).get("1", [{}])[0]
	var renamed_feature: Dictionary = renamed_class.get("features_by_level", {}).get("1", [{}])[0]
	var neutral_roll_feature: Dictionary = {}
	var renamed_roll_feature: Dictionary = {}
	for feature in neutral_class.get("features_by_level", {}).get("1", []):
		if str(feature.get("id", "")) == "fixture:steadfast_roll_outcomes": neutral_roll_feature = feature
	for feature in renamed_class.get("features_by_level", {}).get("1", []):
		if str(feature.get("id", "")) == "fixture:resolute_roll_outcomes": renamed_roll_feature = feature
	check.call(not neutral_feature.is_empty() and DataLoader._feature_content_error(neutral_feature).is_empty(), "Neutral DEX outcome-override feature loads and validates as an owned passive operation")
	check.call(not renamed_feature.is_empty() and DataLoader._feature_content_error(renamed_feature).is_empty(), "Renamed CON outcome-override feature validates different data without ID dispatch")
	check.call(not neutral_roll_feature.is_empty() and DataLoader._feature_content_error(neutral_roll_feature).is_empty() and not renamed_roll_feature.is_empty() and DataLoader._feature_content_error(renamed_roll_feature).is_empty(), "Neutral and renamed authored hit/miss/save-failure operations pass source validation")
	var duplicate_operation := neutral_feature.duplicate(true)
	duplicate_operation["passive_effects"].append({"type": "failed_save_numeric_bonus", "ability": "DEX", "amount": 5, "cost": 1})
	check.call(not DataLoader._feature_content_error(duplicate_operation).is_empty(), "One passive source cannot declare two same-ability failed-save modifications")
	var invalid_override := neutral_feature.duplicate(true)
	invalid_override["passive_effects"][0]["outcome"] = "natural_20"
	check.call(not DataLoader._feature_content_error(invalid_override).is_empty(), "Outcome override data cannot author a natural-roll replacement or extra field")
	var invalid_cost := neutral_feature.duplicate(true)
	invalid_cost["passive_effects"][0]["cost"] = 0
	check.call(not DataLoader._feature_content_error(invalid_cost).is_empty(), "Outcome override requires a positive bounded exact-pool cost")
	var invalid_stage := neutral_roll_feature.duplicate(true)
	invalid_stage["passive_effects"][0]["stage"] = "after_damage"
	check.call(not DataLoader._feature_content_error(invalid_stage).is_empty(), "Attack outcome override rejects a stage outside its authorized provisional window")

	var caster := Character.new()
	caster.initialize("Outcome Override Caster", "human", "wizard", AbilityScores.new())
	var target := Character.new()
	target.initialize("Outcome Override Owner", "human", "fighter", AbilityScores.new())
	target.character_id = "outcome-override-owner"
	target.ability_scores.dexterity = 10
	target.max_hp = 100
	target.current_hp = 100
	var numeric_fixture: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/fixtures/shared_failed_save_numeric_bonus.json"))
	var numeric_feature: Dictionary = numeric_fixture.get("features_by_level", {}).get("1", [{}])[0]
	var numeric_source := "fixture:outcome_override_numeric_source"
	var numeric_instance := numeric_feature.duplicate(true)
	numeric_instance["source_instance_id"] = numeric_source
	target.features.append(numeric_instance)
	var numeric_acquired := ResourcePoolRules.acquire(target, numeric_feature, numeric_source)
	var override_source := "fixture:outcome_override_success_source"
	var override_instance := neutral_feature.duplicate(true)
	override_instance["source_instance_id"] = override_source
	target.features.append(override_instance)
	var override_acquired := ResourcePoolRules.acquire(target, neutral_feature, override_source)
	var choices := SpellDamageRolls.failed_save_choice_options(target, "DEX")
	check.call(bool(numeric_acquired.get("success", false)) and bool(override_acquired.get("success", false)) and choices.size() == 2, "Numeric and outcome-override sources remain separate selectable exact choices")
	check.call(SpellDamageRolls.failed_save_choice_options(target, "STR").is_empty(), "The explicit success operation is restricted to its authored save ability")

	var host := SpellCastContext.new()
	host.caster = caster
	var test_hud := CombatHUD.new()
	host.hud = test_hud
	host.owner_label_for_character = func(_owner): return "Owner"
	var spell: Dictionary = DataLoader.get_spell("sandbox:steady_save_burst").duplicate(true)
	spell["_save_dc_override"] = 12
	var failure_target := Character.new()
	failure_target.initialize("Failure Override Owner", "human", "fighter", AbilityScores.new())
	failure_target.character_id = "failure-outcome-override-owner"
	failure_target.max_hp = 100
	failure_target.current_hp = 100
	var failure_source := "fixture:steadfast_roll_outcomes:failure-owner"
	var failure_instance := neutral_roll_feature.duplicate(true)
	failure_instance["source_instance_id"] = failure_source
	failure_target.features.append(failure_instance)
	var failure_pool := ResourcePoolRules.acquire(failure_target, neutral_roll_feature, failure_source)
	FighterChecks._seed_die(20, 20)
	var failure_pending := CombatAction.resolve_spell(caster, failure_target, spell, false, {"cast_context": host})
	var failure_record := SpellDamageRolls.failed_save_numeric_bonus_record(caster, failure_target, failure_pending)
	check.call(bool(failure_pool.get("success", false)) and failure_pending.has("save_bonus_request") and bool(failure_pending.get("saved", false)) and failure_record.get("options", []).size() == 1 and str(failure_record.get("options", [])[0].get("outcome", "")) == "failure", "An actually rolled successful shared save offers only its authored failure override")
	var failure_natural := int(failure_record.get("save_test", {}).get("natural_roll", -1))
	var failure_total := int(failure_record.get("save_test", {}).get("total", -1))
	var failure_result := SpellDamageRolls.settle_failed_save_numeric_bonus(caster, failure_target, failure_pending, failure_source)
	check.call(not bool(failure_result.get("saved", true)) and str(failure_result.get("save_outcome_override", "")) == "failure" and str(failure_result.get("save_outcome_override_source", "")) == failure_source and str(failure_result.get("save_outcome_override_feature_id", "")) == "fixture:steadfast_roll_outcomes" and str(failure_result.get("save_outcome_override_owner_id", "")) == failure_target.character_id and int(failure_result.get("save_natural_roll", -1)) == failure_natural and int(failure_result.get("save_total", -2)) == failure_total and int(failure_result.get("save_dc", -1)) == 12 and int(ResourcePoolRules.availability(failure_target, failure_source).get("current", -1)) == 3 and failure_target.current_hp < 100, "Forced save failure keeps the natural, modifier, total and DC facts, records feature/owner provenance, pays once, and resumes failed-save consequences")

	DataLoader._load_content_type("res://data/fixtures/shared_spells/spells/", "spell")
	var attack_caster := Character.new()
	attack_caster.initialize("Attack Outcome Owner", "human", "wizard", AbilityScores.new())
	attack_caster.character_id = "attack-outcome-override-owner"
	var attack_source := "fixture:steadfast_roll_outcomes:attack-owner"
	var attack_instance := neutral_roll_feature.duplicate(true)
	attack_instance["source_instance_id"] = attack_source
	attack_caster.features.append(attack_instance)
	var attack_pool := ResourcePoolRules.acquire(attack_caster, neutral_roll_feature, attack_source)
	var attack_host := SpellCastContext.new()
	attack_host.caster = attack_caster
	attack_host.hud = test_hud
	attack_host.owner_label_for_character = func(_owner): return "Owner"
	var attack_target := Character.new()
	attack_target.initialize("Attack Outcome Target", "human", "fighter", AbilityScores.new())
	attack_target.max_hp = 100
	attack_target.current_hp = 100
	var attack_spell: Dictionary = DataLoader.get_spell("sandbox:owned_spell_attack_neutral").duplicate(true)
	FighterChecks._seed_die(20, 1)
	var forced_hit_pending := CombatAction.resolve_spell(attack_caster, attack_target, attack_spell, false, {"cast_context": attack_host}, [], 1, 12)
	var forced_hit_record := SpellDamageRolls.weapon_attack_bonus_record(attack_caster, attack_target, forced_hit_pending)
	var forced_hit_natural := int(forced_hit_record.get("context", {}).get("attack_result", {}).get("natural", -1))
	var forced_hit_total := int(forced_hit_pending.get("attack_roll", -1))
	var hp_before_forced_hit := attack_target.current_hp
	var forced_hit := SpellDamageRolls.settle_weapon_attack_bonus(attack_caster, attack_target, forced_hit_pending, attack_source)
	check.call(bool(attack_pool.get("success", false)) and forced_hit_pending.has("weapon_attack_bonus_request") and forced_hit_natural == 1 and hp_before_forced_hit == 100 and bool(forced_hit.get("hit", false)) and not bool(forced_hit.get("crit", false)) and int(forced_hit.get("attack_roll", -2)) == forced_hit_total and int(forced_hit.get("numeric_margin", 999)) == forced_hit_total - int(forced_hit.get("attack_target_ac", 0)) and int(forced_hit.get("numeric_margin", 0)) < 0 and str(forced_hit.get("attack_outcome_override", "")) == "hit" and str(forced_hit.get("attack_outcome_override_source", "")) == attack_source and str(forced_hit.get("attack_outcome_override_feature_id", "")) == "fixture:steadfast_roll_outcomes" and str(forced_hit.get("attack_outcome_override_owner_id", "")) == attack_caster.character_id and int(ResourcePoolRules.availability(attack_caster, attack_source).get("current", -1)) == 3, "Forced hit on natural 1 remains noncritical, preserves its negative numeric margin separately from final hit, and records exact source, feature and owner before one-time consequences")
	attack_target.current_hp = 100
	FighterChecks._seed_die(20, 20)
	var forced_miss_pending := CombatAction.resolve_spell(attack_caster, attack_target, attack_spell, false, {"cast_context": attack_host}, [], 1, 12)
	var forced_miss_record := SpellDamageRolls.weapon_attack_bonus_record(attack_caster, attack_target, forced_miss_pending)
	var forced_miss_total := int(forced_miss_record.get("context", {}).get("attack_result", {}).get("total", -1))
	var hp_before_forced_miss := attack_target.current_hp
	var forced_miss := SpellDamageRolls.settle_weapon_attack_bonus(attack_caster, attack_target, forced_miss_pending, attack_source)
	check.call(forced_miss_pending.has("weapon_attack_bonus_request") and bool(forced_miss_record.get("context", {}).get("attack_result", {}).get("is_crit", false)) and not bool(forced_miss.get("hit", true)) and not bool(forced_miss.get("crit", false)) and int(forced_miss.get("attack_roll", -2)) == forced_miss_total and str(forced_miss.get("attack_outcome_override", "")) == "miss" and str(forced_miss.get("attack_outcome_override_source", "")) == attack_source and attack_target.current_hp == hp_before_forced_miss and int(ResourcePoolRules.availability(attack_caster, attack_source).get("current", -1)) == 2, "Forced miss on natural 20 suppresses critical damage, preserves its total and pays once without touching target HP")
	var ordered_caster := Character.new()
	ordered_caster.initialize("Ordered Outcome Owner", "human", "sorcerer", AbilityScores.new())
	ordered_caster.character_id = "ordered-outcome-override-owner"
	ordered_caster.current_hp = 5
	ordered_caster.max_hp = 10
	ordered_caster.features.append({"id": "sorcerer_metamagic"})
	ordered_caster.sorcerer_metamagic_choices.append("empowered_spell")
	ordered_caster.feature_uses["sorcery_points"] = 2
	var ordered_source := "fixture:resolute_roll_outcomes:attack-continuation"
	var ordered_instance := renamed_roll_feature.duplicate(true)
	ordered_instance["source_instance_id"] = ordered_source
	ordered_caster.features.append(ordered_instance)
	var ordered_pool := ResourcePoolRules.acquire(ordered_caster, renamed_roll_feature, ordered_source)
	var ordered_host := SpellCastContext.new()
	ordered_host.caster = ordered_caster
	ordered_host.hud = test_hud
	ordered_host.owner_label_for_character = func(_owner): return "Owner"
	var ordered_attack_spell: Dictionary = DataLoader.get_spell("sandbox:owned_spell_attack_renamed").duplicate(true)
	FighterChecks._seed_die(20, 1)
	var ordered_pending := CombatAction.resolve_spell(ordered_caster, attack_target, ordered_attack_spell, false, {"cast_context": ordered_host, "metamagic:empowered": true, "defer_empowered": true}, [], 1, 12)
	var ordered_deferred := SpellDamageRolls.settle_weapon_attack_bonus(ordered_caster, attack_target, ordered_pending, ordered_source)
	var target_hp_after_ordered_outcome := attack_target.current_hp
	check.call(bool(ordered_pool.get("success", false)) and ordered_pending.has("weapon_attack_bonus_request") and ordered_caster.current_hp == 7 and not CombatAction.has_condition(attack_target, "restrained") and ordered_deferred.has("damage_request") and target_hp_after_ordered_outcome == 100 and int(ResourcePoolRules.availability(ordered_caster, ordered_source).get("current", -1)) == 6, "Ordered earlier step settles once while forced-hit damage and its rider remain suspended at the later damage choice")
	var ordered_attack_finished := CombatAction.finish_pending_spell_damage(ordered_caster, attack_target, ordered_deferred, {"metamagic:empowered": true, "metamagic:empowered_dice": []})
	var continued_attack_result: Dictionary = {}
	var continued_steps: Array = ordered_attack_finished.get("step_results", [])
	if continued_steps.size() > 1:
		var continued_attack_outcomes: Array = continued_steps[1].get("target_outcomes", [])
		if not continued_attack_outcomes.is_empty():
			continued_attack_result = continued_attack_outcomes[0].get("result", {})
	check.call(bool(ordered_attack_finished.get("success", false)) and not ordered_attack_finished.has("damage_request") and str(continued_attack_result.get("attack_outcome_override", "")) == "hit" and str(continued_attack_result.get("attack_outcome_override_source", "")) == ordered_source and CombatAction.has_condition(attack_target, "restrained") and attack_target.current_hp < 100 and int(ResourcePoolRules.availability(ordered_caster, ordered_source).get("current", -1)) == 6, "Completing the later damage choice retains the exact attack override receipt, then applies the hit rider and damage once")
	target.feature_uses["bardic_inspiration_die"] = "1d6"
	var bardic_seed := -1
	for candidate in 100000:
		seed(candidate)
		var candidate_d20 := randi_range(1, 20)
		var candidate_d6 := randi_range(1, 6)
		if candidate_d20 == 1 and candidate_d6 == 1:
			bardic_seed = candidate
			break
	check.call(bardic_seed >= 0, "A deterministic failed save and still-failing Inspiration sequence is available")
	seed(bardic_seed)
	var dice_counts := {"d20": 0, "d6": 0}
	var count_save_and_inspiration := func(payload: Dictionary) -> void:
		if int(payload.get("sides", 0)) == 20: dice_counts["d20"] += 1
		if int(payload.get("sides", 0)) == 6: dice_counts["d6"] += 1
	Dice.dice_rolled.connect(count_save_and_inspiration)
	var hp_before_decline := target.current_hp
	var bardic_pending := CombatAction.resolve_spell(caster, target, spell, false, {"cast_context": host, "bardic_inspiration": true})
	var bardic_record := SpellDamageRolls.failed_save_numeric_bonus_record(caster, target, bardic_pending)
	var bardic_test: Dictionary = bardic_record.get("save_test", {})
	check.call(bardic_pending.has("save_bonus_request") and int(bardic_test.get("total", -1)) == 2 and int(bardic_test.get("bardic_inspiration_bonus", -1)) == 1 and bool(bardic_test.get("_post_roll_flags", {}).get("bardic_inspiration_used", false)), "Still-failing Bardic Inspiration is captured in the pending save before a further choice")
	var declined_bardic := SpellDamageRolls.settle_failed_save_numeric_bonus(caster, target, bardic_pending, "")
	Dice.dice_rolled.disconnect(count_save_and_inspiration)
	check.call(bool(declined_bardic.get("success", false)) and not bool(declined_bardic.get("saved", true)) and int(declined_bardic.get("save_total", -1)) == 2 and int(declined_bardic.get("save_natural_roll", -1)) == 1 and int(declined_bardic.get("save_modifier", -1)) == 0 and int(declined_bardic.get("save_dc", -1)) == 12 and bool(declined_bardic.get("bardic_inspiration_used", false)), "Declining after Inspiration retains its adjusted failed total and original roll/DC")
	check.call(target.current_hp == hp_before_decline - 4 and not target.feature_uses.has("bardic_inspiration_die") and dice_counts["d20"] == 1 and dice_counts["d6"] == 1, "Decline applies full failed-save damage without repeating the d20 or Inspiration die")

	# The fixed bonus uses the post-Inspiration total and converts only when both apply.
	target.current_hp = 100
	target.feature_uses["bardic_inspiration_die"] = "1d6"
	var combined_seed := -1
	for candidate in 100000:
		seed(candidate)
		var candidate_d20 := randi_range(1, 20)
		var candidate_d6 := randi_range(1, 6)
		if candidate_d20 == 1 and candidate_d6 == 6:
			combined_seed = candidate
			break
	seed(combined_seed)
	dice_counts["d20"] = 0
	dice_counts["d6"] = 0
	Dice.dice_rolled.connect(count_save_and_inspiration)
	var combined_pending := CombatAction.resolve_spell(caster, target, spell, false, {"cast_context": host, "bardic_inspiration": true})
	var combined_record := SpellDamageRolls.failed_save_numeric_bonus_record(caster, target, combined_pending)
	var combined_request_test: Dictionary = combined_record.get("save_test", {})
	var hp_before_combined := target.current_hp
	var combined_result := SpellDamageRolls.settle_failed_save_numeric_bonus(caster, target, combined_pending, numeric_source)
	Dice.dice_rolled.disconnect(count_save_and_inspiration)
	check.call(int(combined_request_test.get("total", -1)) == 7 and int(combined_request_test.get("bardic_inspiration_bonus", -1)) == 6, "The pending choice snapshots Bardic Inspiration's adjusted total before the numeric bonus")
	check.call(bool(combined_result.get("saved", false)) and int(combined_result.get("save_natural_roll", -1)) == 1 and int(combined_result.get("save_modifier", -1)) == 0 and int(combined_result.get("save_total", -1)) == 12 and int(combined_result.get("save_post_roll_bonus", -1)) == 5 and int(combined_result.get("save_test", {}).get("bardic_inspiration_bonus", -1)) == 6, "A fixed bonus converts the save only after the retained Inspiration bonus is included")
	check.call(target.current_hp == hp_before_combined - 2 and dice_counts["d20"] == 1 and dice_counts["d6"] == 1 and int(ResourcePoolRules.availability(target, numeric_source).get("current", -1)) == 1 and int(ResourcePoolRules.availability(target, override_source).get("current", -1)) == 2, "Combined save settles half damage once, spends only the chosen numeric source, and rolls each die once")

	# Explicit override preserves the failed numeric result and does not stack the other source.
	target.current_hp = 100
	FighterChecks._seed_die(20, 1)
	var override_pending := CombatAction.resolve_spell(caster, target, spell, false, {"cast_context": host})
	var override_record := SpellDamageRolls.failed_save_numeric_bonus_record(caster, target, override_pending)
	var original_test: Dictionary = override_record.get("save_test", {})
	var original_numeric_pool := int(ResourcePoolRules.availability(target, numeric_source).get("current", -1))
	var original_override_pool := int(ResourcePoolRules.availability(target, override_source).get("current", -1))
	var hp_before_override := target.current_hp
	target.numeric_resource_pools[override_source]["current"] = 0
	var stale_override := SpellDamageRolls.settle_failed_save_numeric_bonus(caster, target, override_pending, override_source)
	check.call(bool(stale_override.get("refused", false)) and target.current_hp == hp_before_override and int(ResourcePoolRules.availability(target, override_source).get("current", -1)) == 0, "A source that becomes empty while the override is pending refuses without damage")
	target.numeric_resource_pools[override_source]["current"] = original_override_pool
	var override_result := SpellDamageRolls.settle_failed_save_numeric_bonus(caster, target, override_pending, override_source)
	var override_test: Dictionary = override_result.get("save_test", {})
	check.call(bool(override_result.get("saved", false)) and int(override_result.get("save_natural_roll", -1)) == int(original_test.get("natural_roll", -2)) and int(override_result.get("save_total", -1)) == int(original_test.get("total", -2)) and int(override_result.get("save_dc", -1)) == int(original_test.get("dc", -2)), "Forced success keeps the natural roll, numeric total, modifier and DC unchanged")
	check.call(int(override_result.get("numeric_margin", 999)) == int(override_result.get("save_total", 0)) - int(override_result.get("save_dc", 0)) and int(override_result.get("numeric_margin", 0)) < 0 and bool(override_result.get("saved", false)), "S-092 forced success preserves its negative numeric margin separately from the final successful outcome")
	check.call(str(override_result.get("save_outcome_override", "")) == "success" and str(override_result.get("save_outcome_override_source", "")) == override_source and str(override_test.get("outcome_override", "")) == "success" and str(override_test.get("outcome_override_source", "")) == override_source and not override_result.has("save_post_roll_bonus"), "Override is explicit with exact source metadata and never appears as a numeric bonus")
	check.call(target.current_hp == hp_before_override - 2 and int(ResourcePoolRules.availability(target, override_source).get("current", -1)) == original_override_pool - 1 and int(ResourcePoolRules.availability(target, numeric_source).get("current", -1)) == original_numeric_pool, "Downstream half-on-save damage uses the override and only its selected source pays")
	var override_replay := SpellDamageRolls.settle_failed_save_numeric_bonus(caster, target, override_pending, override_source)
	check.call(bool(override_replay.get("refused", false)) and target.current_hp == hp_before_override - 2 and int(ResourcePoolRules.availability(target, override_source).get("current", -1)) == original_override_pool - 1, "Outcome-override request replay cannot spend or apply its effect twice")

	var renamed_target := Character.new()
	renamed_target.initialize("Renamed Override Owner", "human", "fighter", AbilityScores.new())
	renamed_target.character_id = "renamed-outcome-override-owner"
	renamed_target.ability_scores.constitution = 10
	renamed_target.max_hp = 100
	renamed_target.current_hp = 100
	var renamed_source := "fixture:resolute_success:renamed-instance"
	var renamed_instance := renamed_feature.duplicate(true)
	renamed_instance["source_instance_id"] = renamed_source
	renamed_target.features.append(renamed_instance)
	var renamed_pool := ResourcePoolRules.acquire(renamed_target, renamed_feature, renamed_source)
	var renamed_options := SpellDamageRolls.failed_save_choice_options(renamed_target, "CON")
	var con_spell: Dictionary = DataLoader.get_spell("sandbox:failed_save_bonus_con_area").duplicate(true)
	con_spell["_save_dc_override"] = 12
	FighterChecks._seed_die(20, 1)
	var renamed_pending := CombatAction.resolve_spell(caster, renamed_target, con_spell, false, {"cast_context": host})
	var renamed_result := SpellDamageRolls.settle_failed_save_numeric_bonus(caster, renamed_target, renamed_pending, renamed_source)
	check.call(bool(renamed_pool.get("success", false)) and renamed_options.size() == 1 and int(renamed_options[0].get("cost", -1)) == 2 and bool(renamed_result.get("saved", false)) and int(renamed_result.get("save_natural_roll", -1)) == 1 and int(renamed_result.get("save_total", -1)) == 3 and int(renamed_result.get("save_modifier", -1)) == 2 and str(renamed_result.get("save_outcome_override_source", "")) == renamed_source and int(ResourcePoolRules.availability(renamed_target, renamed_source).get("current", -1)) == 1 and renamed_target.current_hp == 98, "Renamed CON/cost data uses the same explicit override and existing half-damage gate")

	# A save choice inside an ordered save must keep its parent continuation if
	# replaying the save opens a deferred Empowered Spell damage choice.
	DataLoader._load_content_type("res://data/fixtures/shared_spells/spells/", "spell")
	var empowered_ordered_spell: Dictionary = DataLoader.get_spell("sandbox:failed_save_override_empowered_ordered").duplicate(true)
	check.call(SharedSpell.content_error(empowered_ordered_spell).is_empty(), "Ordered save and Empowered Spell continuation fixture validates through DataLoader")
	caster.class_id = "sorcerer"
	caster.features.append({"id": "sorcerer_metamagic"})
	caster.sorcerer_metamagic_choices.append("empowered_spell")
	caster.ability_scores.charisma = 16
	caster.feature_uses["sorcery_points"] = 2
	target.current_hp = 100
	target.remove_condition("poisoned")
	target.remove_condition("blessed")
	target.remove_condition("frightened")
	target.numeric_resource_pools[override_source]["current"] = 1
	var empowered_cast := SpellResolutionContext.new()
	empowered_cast.caster = caster
	empowered_cast.target = target
	empowered_cast.spell = empowered_ordered_spell
	empowered_cast.slot_level = 1
	empowered_cast.has_damage_payload = true
	empowered_cast.effect_cast = SpellEffects.begin_cast(caster, empowered_ordered_spell)
	empowered_cast.decisions = {
		"cast_context": host,
		"metamagic:empowered": true,
		"defer_empowered": true,
	}
	FighterChecks._seed_die(20, 1)
	var hp_before_ordered_choice := target.current_hp
	var ordered_choice := SharedSpell.resolve(empowered_cast)
	var ordered_record := SpellDamageRolls.failed_save_numeric_bonus_record(caster, target, ordered_choice)
	var ordered_request_id := str(ordered_choice.get("save_bonus_request", {}).get("request_id", ""))
	var ordered_original_dc := int(ordered_record.get("save_test", {}).get("dc", -1))
	caster.ability_scores.charisma = 20
	check.call(ordered_choice.has("save_bonus_request") and not target.has_condition("poisoned") and not target.has_condition("frightened") and target.current_hp == hp_before_ordered_choice, "Ordered save defers failed-save riders, damage and HP changes until its save chooser answers")
	var ordered_pool_before := int(ResourcePoolRules.availability(target, override_source).get("current", -1))
	var ordered_bonus_settled := SpellDamageRolls.settle_failed_save_numeric_bonus(caster, target, ordered_choice, override_source)
	var ordered_damage_request: Dictionary = ordered_bonus_settled.get("damage_request", {})
	var ordered_damage_id := str(ordered_damage_request.get("request_id", ""))
	check.call(ordered_bonus_settled.has("damage_request") and not target.has_condition("blessed") and not target.has_condition("poisoned") and not target.has_condition("frightened") and target.current_hp == hp_before_ordered_choice and int(ResourcePoolRules.availability(target, override_source).get("current", -1)) == ordered_pool_before - 1 and caster.get_sorcery_points() == 2, "Accepting override spends only its source once and suspends for Empowered dice without advancing riders or damage")
	var ordered_damage_replay_payload := {"damage_request": {"request_id": ordered_damage_id}}
	var ordered_finished := CombatAction.finish_pending_spell_damage(caster, target, ordered_bonus_settled, {"metamagic:empowered_dice": [0]})
	var hp_after_ordered_finish := target.current_hp
	var pool_after_ordered_finish := int(ResourcePoolRules.availability(target, override_source).get("current", -1))
	var final_ordered_dc := -2
	var final_ordered_override := ""
	var final_ordered_override_source := ""
	var final_ordered_steps: Array = ordered_finished.get("step_results", [])
	if not final_ordered_steps.is_empty():
		var final_target_outcomes: Array = final_ordered_steps[0].get("target_outcomes", [])
		if not final_target_outcomes.is_empty():
			var final_save_receipt: Dictionary = final_target_outcomes[0].get("result", {})
			final_ordered_dc = int(final_save_receipt.get("save_dc", -2))
			final_ordered_override = str(final_save_receipt.get("save_outcome_override", ""))
			final_ordered_override_source = str(final_save_receipt.get("save_outcome_override_source", ""))
	var old_save_replay := SpellDamageRolls.settle_failed_save_numeric_bonus(caster, target, {"save_bonus_request": {"request_id": ordered_request_id}}, override_source)
	var old_damage_replay := CombatAction.finish_pending_spell_damage(caster, target, ordered_damage_replay_payload, {"metamagic:empowered_dice": [0]})
	check.call(ordered_finished.get("success", false) and not ordered_finished.has("damage_request") and final_ordered_dc == ordered_original_dc and final_ordered_override == "success" and final_ordered_override_source == override_source and target.has_condition("blessed") and not target.has_condition("poisoned") and not target.has_condition("frightened") and hp_after_ordered_finish < hp_before_ordered_choice and caster.get_sorcery_points() == 1 and pool_after_ordered_finish == ordered_pool_before - 1, "Deferred ordered damage completes once, follows the overridden save, and retains its exact outcome receipt and captured DC after caster-stat changes")
	check.call(bool(old_save_replay.get("refused", false)) and target.current_hp == hp_after_ordered_finish and int(ResourcePoolRules.availability(target, override_source).get("current", -1)) == pool_after_ordered_finish and str(ordered_record.get("request_id", "")) == ordered_request_id and not ordered_damage_id.is_empty(), "Old save and damage completions cannot reapply effects, damage, or source payment after the newer continuation settles")
	SpellDamageRolls.clear_pending_requests()
	host.hud = null
	test_hud.free()


static func _seed_failed_d20_and_d6(wanted_d6: int) -> int:
	for candidate in 100000:
		seed(candidate)
		var d20 := randi_range(1, 20)
		var d6 := randi_range(1, 6)
		if d20 == 1 and d6 == wanted_d6:
			seed(candidate)
			return candidate
	return -1


static func _p1_correction_checks(check: Callable) -> void:
	var caster := Character.new()
	caster.initialize("P1 caster", "human", "wizard", AbilityScores.new())
	caster.character_id = "p1-correction-caster"
	caster.ability_scores.intelligence = 16
	caster.spell_slots["1"] = 2
	caster.max_hp = 100
	caster.current_hp = 40
	var character_target := Character.new()
	character_target.initialize("P1 target", "human", "fighter", AbilityScores.new())
	character_target.character_id = "p1-correction-target"
	character_target.max_hp = 100
	character_target.current_hp = 5
	character_target.temp_hp = 3
	var dictionary_target := {"id": "p1-dictionary", "name": "P1 dictionary", "current_hp": 5, "max_hp": 100, "temp_hp": 3, "is_alive": true, "conditions": {}}
	for target in [character_target, dictionary_target]:
		var settled := SpellDamageRolls._finish_spell_damage(caster, target, {"final_total": 12}, 0, 1.0, "fire", {}, {"success": true, "message": "P1 deals {damage}."}, 1, [{"type": "cold", "details": {"final_total": 4}}])
		var components: Array = settled.get("damage_components", [])
		check.call(components.size() == 2 and components[0].raw == 12 and components[0].resolved == 12 and components[0].hp_loss == 5, "P1 component HP loss excludes Temporary HP and overkill for %s" % ("Character" if target is Character else "Dictionary"))
		check.call(components.size() == 2 and components[1].resolved == 4 and components[1].hp_loss == 0, "P1 later component cannot remove HP already lost for %s" % ("Character" if target is Character else "Dictionary"))

	var spell := DataLoader.get_spell("sandbox:ember_echo").duplicate(true)
	spell["steps"][0]["when"] = {"fact": "actor.level", "lt": 0}
	spell["steps"][1].erase("when")
	var effect: Dictionary = spell["steps"][1]["effects"][0]
	effect.erase("when")
	effect["ability_bonus_from_caster"] = true
	check.call(SharedSpell.content_error(spell).is_empty(), "P1 permits a reference to an earlier conditional damage step")
	var missing_result := CombatAction.resolve_spell(caster, dictionary_target, spell, false)
	check.call(missing_result.get("success", false) and caster.current_hp == 40 and int(missing_result.get("healing", 0)) == 0, "P1 missing damage outcome skips healing including the caster bonus")
	for kind in ["heal", "temporary_hp"]:
		effect["type"] = kind
		effect["value"] = {"op": "floor_divide", "left": 8, "right": {"op": "subtract", "left": 1, "right": 1}}
		check.call(SharedSpell.content_error(spell).is_empty(), "P1 accepts a calculated divisor for %s" % kind)
		var zero_divisor_result := CombatAction.resolve_spell(caster, dictionary_target, spell, false)
		check.call(zero_divisor_result.get("success", false) and caster.current_hp == 40 and caster.temp_hp == 0 and int(zero_divisor_result.get("healing", 0)) == 0, "P1 runtime zero divisor skips %s including the caster bonus" % kind)
	effect["type"] = "heal"
	for divisor in [0, 0.0, "0"]:
		effect["value"] = {"op": "floor_divide", "left": 8, "right": divisor}
		check.call(not SharedSpell.content_error(spell).is_empty(), "P1 rejects a literal zero divisor of type %s" % type_string(typeof(divisor)))
	effect["value"] = {"op": "floor_divide", "left": 0, "right": 2}
	var valid_zero_result := CombatAction.resolve_spell(caster, dictionary_target, spell, false)
	var healing_step: Dictionary = valid_zero_result["step_results"][1]["target_outcomes"][0]["result"]
	check.call(caster.current_hp == 43 and int(healing_step.get("healing", 0)) == 3, "P1 valid zero calculation still applies its declared caster bonus")

	var formula_cast := SpellResolutionContext.new()
	formula_cast.caster = caster
	formula_cast.slot_level = 3
	var formula_adapter := SharedStepExecutor.SpellAdapter.new(formula_cast)
	var formula_refs := [
		[{"caster_level": true}, caster.level],
		[{"caster_class_level": "wizard"}, caster.get_class_level("wizard")],
		[{"caster_proficiency_bonus": true}, caster.proficiency_bonus],
		[{"caster_ability_modifier": "INT"}, 3],
		[{"selected_slot_level": true}, 3]
	]
	for item in formula_refs:
		var evaluated := SharedStepExecutor.evaluate_formula(item[0], formula_adapter, caster, [])
		check.call(bool(evaluated.get("success", false)) and int(evaluated.get("value", -1)) == int(item[1]), "P1 character/cast formula reference evaluates %s" % str(item[0]))
	var breakpoint_spell := DataLoader.get_spell("sandbox:breakpoint_lookup_probe")
	var breakpoint_hp_before := caster.current_hp
	var breakpoint_cast := CombatAction.resolve_spell(caster, caster, breakpoint_spell, false, {}, [], 1, 5)
	check.call(not breakpoint_spell.is_empty() and SharedSpell.content_error(breakpoint_spell).is_empty() and breakpoint_cast.get("success", false) and caster.current_hp == breakpoint_hp_before + 3, "An ordinary shared spell composes breakpoint lookup with arithmetic through production spell resolution")
	caster.current_hp = breakpoint_hp_before
	var constant_breakpoint_spell := DataLoader.get_spell("sandbox:breakpoint_constant_probe")
	var constant_breakpoint_caster := Character.new()
	constant_breakpoint_caster.initialize("Constant Breakpoint Caster", "human", "wizard", AbilityScores.new())
	constant_breakpoint_caster.max_hp = 20
	constant_breakpoint_caster.current_hp = 10
	var constant_breakpoint_cast := CombatAction.resolve_spell(constant_breakpoint_caster, constant_breakpoint_caster, constant_breakpoint_spell, false)
	check.call(not constant_breakpoint_spell.is_empty() and SharedSpell.content_error(constant_breakpoint_spell).is_empty() and constant_breakpoint_cast.get("success", false) and constant_breakpoint_caster.current_hp == 17, "DataLoader and shared spell resolution accept deterministic constant expression 3+2 as a breakpoint input")
	var actor_cast_only := SharedStepExecutor.evaluate_actor_formula({"op": "add", "left": 1, "right": {"selected_slot_level": true}}, caster)
	check.call(not actor_cast_only.get("success", true), "Actor formula evaluation safely refuses nested cast-only leaves when no cast context exists")
	var dice_lookup_error := SharedStepExecutor.formula_content_error({"op": "breakpoint_lookup", "input": "1d4", "breakpoints": [{"threshold": 1, "value": 2}]})
	check.call(not dice_lookup_error.is_empty(), "Breakpoint lookup still rejects dice input after allowing deterministic constant expressions")

	var slotward := DataLoader.get_spell("sandbox:slotward").duplicate(true)
	var slotward_result := CombatAction.resolve_spell(caster, caster, slotward, false, {}, [], 2)
	check.call(slotward_result.get("success", false) and caster.temp_hp == 5 and int(caster.spell_slots["1"]) == 2, "P1 Slotward uses INT modifier + selected slot level even when no slot is paid")
	caster.temp_hp = 0
	for bad_reference in [{"caster_class_level": "not_a_class"}, {"caster_ability_modifier": "INTELLIGENCE"}, {"selected_slot_level": false}, {"selected_slot_level": true, "caster_level": true}]:
		slotward["steps"][0]["effects"][0]["value"] = bad_reference
		check.call(not SharedSpell.content_error(slotward).is_empty(), "P1 rejects malformed or unknown formula reference %s" % str(bad_reference))
		var refused_reference := CombatAction.resolve_spell(caster, caster, slotward, true, {}, [], 1)
		check.call(not refused_reference.get("success", true) and int(caster.spell_slots["1"]) == 2 and caster.temp_hp == 0, "P1 invalid formula reference refuses before slot or Temporary HP mutation")

	for top_effect in [{"type": "heal", "value": {"unsupported": true}}, {"type": "heal", "value": "4", "when": {"fact": "unsupported.fact", "eq": true}}]:
		var invalid := DataLoader.get_spell("sandbox:ember_echo").duplicate(true)
		invalid["effects"] = [top_effect]
		check.call(not SharedSpell.content_error(invalid).is_empty(), "P1 rejects spell-level formulas/predicates even with valid ordered steps")
		caster.spell_slots["1"] = 2
		var refused := CombatAction.resolve_spell(caster, dictionary_target, invalid, true)
		check.call(not refused.get("success", true) and int(caster.spell_slots["1"]) == 2 and caster.current_hp == 43, "P1 spell-level expression refusal occurs before slot or HP mutation")


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


static func _failed_save_numeric_bonus_checks(check: Callable) -> void:
	var fixture: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/fixtures/shared_failed_save_numeric_bonus.json"))
	var feature: Dictionary = fixture.get("features_by_level", {}).get("1", [])[0]
	check.call(DataLoader._feature_content_error(feature).is_empty(), "Failed-save bonus fixture validates as a passive exact-pool carrier")
	var renamed: Dictionary = feature.duplicate(true)
	renamed["id"] = "fixture:steadfast_resolve"
	renamed["resource_pool"]["id"] = "fixture:steadfast_resolve_pool"
	renamed["passive_effects"][0]["ability"] = "CON"
	renamed["passive_effects"][0]["amount"] = 7
	check.call(DataLoader._feature_content_error(renamed).is_empty(), "Renamed bonus feature validates different ability and amount without identity dispatch")
	DataLoader._load_content_type("res://data/fixtures/failed_save_bonus/classes/", "class")
	var pay_choice_class: Dictionary = DataLoader.get_character_class("fixture:save_bonus_pay_on_choice_class")
	var pay_success_class: Dictionary = DataLoader.get_character_class("fixture:save_bonus_pay_on_success_class")
	var pay_choice_feature: Dictionary = pay_choice_class.get("features_by_level", {}).get("1", [{}])[0]
	var pay_success_feature: Dictionary = pay_success_class.get("features_by_level", {}).get("1", [{}])[0]
	check.call(DataLoader._feature_content_error(pay_choice_feature).is_empty() and DataLoader._feature_content_error(pay_success_feature).is_empty(), "Neutral pay-on-choice and renamed pay-on-converted-success policy fixtures validate through production DataLoader")
	var invalid_payment_policy: Dictionary = pay_success_feature.duplicate(true)
	invalid_payment_policy["passive_effects"][0]["payment_policy"] = "refund_if_failed"
	check.call(not DataLoader._feature_content_error(invalid_payment_policy).is_empty(), "Unknown failed-save payment policies refuse during content validation")
	var duplicate_ability: Dictionary = feature.duplicate(true)
	duplicate_ability["passive_effects"].append(duplicate_ability["passive_effects"][0].duplicate(true))
	check.call(not DataLoader._feature_content_error(duplicate_ability).is_empty(), "One source refuses ambiguous duplicate bonus operations for the same ability")
	var invalid_amount: Dictionary = feature.duplicate(true)
	invalid_amount["passive_effects"][0]["amount"] = 0
	check.call(not DataLoader._feature_content_error(invalid_amount).is_empty(), "Failed-save bonuses reject zero or nonpositive authored amounts")

	var caster := Character.new()
	caster.initialize("Save Bonus Caster", "human", "wizard", AbilityScores.new())
	var target := Character.new()
	target.initialize("Save Bonus Owner", "human", "fighter", AbilityScores.new())
	target.character_id = "failed-save-bonus-owner"
	target.ability_scores.dexterity = 2
	target.max_hp = 100
	target.current_hp = 100
	target.features.append(feature.duplicate(true))
	var source_id := str(feature["id"])
	check.call(ResourcePoolRules.acquire(target, feature, source_id).get("success", false), "Passive pool carrier acquires one exact source quantity")
	var renamed_source := renamed.duplicate(true)
	target.features.append(renamed_source)
	check.call(ResourcePoolRules.acquire(target, renamed_source, str(renamed_source["id"])).get("success", false), "Renamed passive carrier owns an independent exact source pool")
	var options := SpellDamageRolls.failed_save_numeric_bonus_options(target, "DEX")
	check.call(options.size() == 1 and str(options[0].get("source_instance_id", "")) == source_id and str(options[0].get("payment_policy", "")) == "pay_on_choice", "Only the matching available source is offered and omitted policy preserves pay-on-choice")
	check.call(SpellDamageRolls.failed_save_numeric_bonus_options(target, "STR").is_empty(), "A nonmatching save ability does not offer the bonus")

	var host := SpellCastContext.new()
	host.caster = caster
	var test_hud := CombatHUD.new()
	host.hud = test_hud
	host.owner_label_for_character = func(_owner): return "Owner"
	var spell: Dictionary = DataLoader.get_spell("sandbox:steady_save_burst")
	check.call(not spell.is_empty(), "Neutral save-bonus consumer loads through the shared-spell fixture loader")
	FighterChecks._seed_die(20, 1)
	var pending := CombatAction.resolve_spell(caster, target, spell, false, {"cast_context": host})
	check.call(pending.has("save_bonus_request") and target.current_hp == 100, "Rolled matching failed save suspends before damage when a combat chooser exists")
	var before_pool := int(ResourcePoolRules.availability(target, source_id).get("current", -1))
	var forged := SpellDamageRolls.settle_failed_save_numeric_bonus(caster, target, pending, "fixture:forged")
	check.call(bool(forged.get("refused", false)) and int(ResourcePoolRules.availability(target, source_id).get("current", -1)) == before_pool and target.current_hp == 100, "Forged source answer refuses before payment or damage")
	var settled := SpellDamageRolls.settle_failed_save_numeric_bonus(caster, target, pending, source_id)
	check.call(bool(settled.get("success", false)) and not bool(settled.get("saved", true)) and int(settled.get("save_total", 0)) == int(settled.get("save_natural_roll", 0)) + int(settled.get("save_modifier", 0)) + 5 and int(settled.get("save_post_roll_bonus", 0)) == 5 and int(settled.get("save_natural_roll", 0)) == 1 and target.current_hp == 96 and int(ResourcePoolRules.availability(target, source_id).get("current", -1)) == before_pool - 1, "Accepted +5 retains the natural roll and modifier, pays once and settles before damage")
	var replay := SpellDamageRolls.settle_failed_save_numeric_bonus(caster, target, pending, source_id)
	check.call(bool(replay.get("refused", false)) and target.current_hp == 96 and int(ResourcePoolRules.availability(target, source_id).get("current", -1)) == before_pool - 1, "Save-bonus completion replay cannot charge or apply damage again")

	var success_source := str(pay_success_feature.get("id", ""))
	caster.ability_scores.intelligence = 20
	var conditional_target := Character.new()
	conditional_target.initialize("Conditional Save Owner", "human", "wizard", AbilityScores.new())
	conditional_target.character_id = "conditional-save-bonus-owner"
	conditional_target.max_hp = 100
	conditional_target.current_hp = 100
	conditional_target.ability_scores.constitution = 2
	conditional_target.features.append(pay_success_feature.duplicate(true))
	var success_pool := ResourcePoolRules.acquire(conditional_target, pay_success_feature, success_source)
	var conditional_options := SpellDamageRolls.failed_save_numeric_bonus_options(conditional_target, "CON")
	check.call(bool(success_pool.get("success", false)) and conditional_options.size() == 1 and str(conditional_options[0].get("payment_policy", "")) == "pay_on_converted_success", "Renamed conditional source offers only with its exact pool and authored payment policy")
	var con_spell: Dictionary = DataLoader.get_spell("sandbox:failed_save_bonus_con_area")
	check.call(not con_spell.is_empty(), "Conditional payment probe uses the loaded shared CON-save spell")
	var conditional_hp := conditional_target.current_hp
	FighterChecks._seed_die(20, 1)
	var conditional_failure := CombatAction.resolve_spell(caster, conditional_target, con_spell, false, {"cast_context": host})
	var conditional_failure_result := SpellDamageRolls.settle_failed_save_numeric_bonus(caster, conditional_target, conditional_failure, success_source)
	check.call(bool(conditional_failure_result.get("success", false)) and not bool(conditional_failure_result.get("saved", true)) and int(conditional_failure_result.get("save_total", 0)) == -3 + 7 and int(conditional_failure_result.get("save_post_roll_bonus", 0)) == 7 and str(conditional_failure_result.get("save_payment_policy", "")) == "pay_on_converted_success" and not bool(conditional_failure_result.get("save_cost_paid", true)) and conditional_target.current_hp == conditional_hp - 4 and int(ResourcePoolRules.availability(conditional_target, success_source).get("current", -1)) == 2, "Accepted conditional bonus stays applied on a remaining failure, causes full damage, and pays nothing")
	conditional_target.ability_scores.constitution = 20
	conditional_target.numeric_resource_pools[success_source]["current"] = 1
	var before_stale_commit_hp := conditional_target.current_hp
	FighterChecks._seed_die(20, 8)
	var insufficient_pending := CombatAction.resolve_spell(caster, conditional_target, con_spell, false, {"cast_context": host})
	conditional_target.numeric_resource_pools[success_source]["current"] = 0
	var insufficient_commit := SpellDamageRolls.settle_failed_save_numeric_bonus(caster, conditional_target, insufficient_pending, success_source)
	check.call(bool(insufficient_commit.get("refused", false)) and conditional_target.current_hp == before_stale_commit_hp and int(ResourcePoolRules.availability(conditional_target, success_source).get("current", -1)) == 0, "A changed-to-empty exact source refuses settlement before bonus, payment or consequences")
	conditional_target.numeric_resource_pools[success_source]["current"] = 1
	var converted := SpellDamageRolls.settle_failed_save_numeric_bonus(caster, conditional_target, insufficient_pending, success_source)
	check.call(bool(converted.get("success", false)) and bool(converted.get("saved", false)) and int(converted.get("save_natural_roll", 0)) == 8 and int(converted.get("save_total", 0)) == 20 and bool(converted.get("save_cost_paid", false)) and conditional_target.current_hp == before_stale_commit_hp - 2 and int(ResourcePoolRules.availability(conditional_target, success_source).get("current", -1)) == 0, "After funds are restored, converted success pays once and applies half damage using the final save")
	var empty_pool_hp := conditional_target.current_hp
	FighterChecks._seed_die(20, 1)
	var empty_source_result := CombatAction.resolve_spell(caster, conditional_target, con_spell, false, {"cast_context": host})
	check.call(not empty_source_result.has("save_bonus_request") and not bool(empty_source_result.get("saved", true)) and conditional_target.current_hp == empty_pool_hp - 4 and int(ResourcePoolRules.availability(conditional_target, success_source).get("current", -1)) == 0, "An empty conditional source is not offered and cannot provide a free bonus")
	# Settled requests remain as replay tombstones. This test's request retains
	# the real cast context (and its temporary HUD), so clear it before freeing
	# the HUD just as an encounter/session teardown does.
	SpellDamageRolls.clear_pending_requests()
	host.hud = null
	test_hud.free()


static func _shared_spell_attack_bonus_checks(check: Callable) -> void:
	DataLoader._load_content_type("res://data/fixtures/failed_save_bonus/classes/", "class")
	DataLoader._load_content_type("res://data/fixtures/shared_spells/spells/", "spell")
	var neutral_class: Dictionary = DataLoader.get_character_class("fixture:weapon_attack_bonus_neutral_class")
	var renamed_class: Dictionary = DataLoader.get_character_class("fixture:weapon_attack_bonus_renamed_class")
	var neutral_feature: Dictionary = neutral_class.get("features_by_level", {}).get("1", [{}])[0]
	var renamed_feature: Dictionary = renamed_class.get("features_by_level", {}).get("1", [{}])[0]
	var flat_spell: Dictionary = DataLoader.get_spell("sandbox:owned_spell_attack_neutral")
	var ordered_spell: Dictionary = DataLoader.get_spell("sandbox:owned_spell_attack_renamed")
	check.call(not neutral_feature.is_empty() and not renamed_feature.is_empty() and not DataLoader._feature_content_error(neutral_feature) and not DataLoader._feature_content_error(renamed_feature), "Neutral and renamed attack sources validate both weapon and shared-spell domains")
	check.call(not flat_spell.is_empty() and not ordered_spell.is_empty() and SharedSpell.content_error(flat_spell).is_empty() and SharedSpell.content_error(ordered_spell).is_empty() and str(flat_spell.get("damage_type", "")) == "fire" and str(ordered_spell.get("steps", [{}, {}])[1].get("damage_type", "")) == "cold", "Production loader registers flat Fire and ordered Cold shared-attack fixtures with distinct payloads")
	var unsupported_domain: Dictionary = neutral_feature.duplicate(true)
	unsupported_domain["passive_effects"][0]["domains"] = ["spell_attack"]
	check.call(not DataLoader._feature_content_error(unsupported_domain).is_empty(), "Attack bonus accepts only its explicitly supported weapon and shared-spell domains")

	var caster := Character.new()
	caster.initialize("Shared Attack Bonus Caster", "human", "sorcerer", AbilityScores.new())
	caster.character_id = "fixture:shared_attack_bonus_caster"
	caster.ability_scores.charisma = 20
	while caster.level < 3:
		caster.level_up()
	caster.sorcerer_metamagic_choices.append("empowered_spell")
	caster.feature_uses["sorcery_points"] = 3
	var neutral_source := "fixture:shared_attack_bonus:neutral"
	var renamed_source := "fixture:shared_attack_bonus:renamed"
	var neutral_instance := neutral_feature.duplicate(true)
	neutral_instance["source_instance_id"] = neutral_source
	var renamed_instance := renamed_feature.duplicate(true)
	renamed_instance["source_instance_id"] = renamed_source
	caster.features.append(neutral_instance)
	caster.features.append(renamed_instance)
	var neutral_acquired := ResourcePoolRules.acquire(caster, neutral_feature, neutral_source)
	var renamed_acquired := ResourcePoolRules.acquire(caster, renamed_feature, renamed_source)
	var choices := SpellDamageRolls.attack_numeric_bonus_options(caster, "shared_spell_attack")
	check.call(bool(neutral_acquired.get("success", false)) and bool(renamed_acquired.get("success", false)) and choices.size() == 2 and int(choices[0].get("amount", 0)) == 5 and int(choices[1].get("amount", 0)) == 8, "One source option builder offers independent authored +5/cost 1 and +8/cost 2 spell bonuses")

	var target := {"id": "fixture:shared_attack_bonus_target", "name": "Attack target", "armor_class": 20, "current_hp": 100, "max_hp": 100, "is_alive": true, "temp_hp": 0, "conditions": {}}
	var cast_host := SpellCastContext.new()
	cast_host.caster = caster
	var test_hud := CombatHUD.new()
	cast_host.hud = test_hud
	cast_host.owner_label_for_character = func(_owner): return "Caster"
	var decisions := {"players": [{"character": caster}], "monsters": [target], "cast_context": cast_host, "hud": cast_host.hud}
	FighterChecks._seed_die(20, 8)
	var noninteractive := CombatAction.resolve_spell(caster, target, flat_spell, false, {"players": [{"character": caster}], "monsters": [target]})
	check.call(not noninteractive.has("weapon_attack_bonus_request") and not bool(noninteractive.get("hit", true)), "A shared spell caller without the real combat chooser keeps ordinary miss resolution")
	var dice_counts := {"d20": 0}
	var count_d20 := func(payload: Dictionary) -> void:
		if int(payload.get("sides", 0)) == 20:
			dice_counts["d20"] += 1
	Dice.dice_rolled.connect(count_d20)
	FighterChecks._seed_die(20, 8)
	var pending := CombatAction.resolve_spell(caster, target, flat_spell, false, decisions)
	var record := SpellDamageRolls.weapon_attack_bonus_record(caster, target, pending)
	var flat_roll: Dictionary = record.get("context", {}).get("attack_result", {})
	var flat_pending_windows: Array = pending.get("resolution_windows", [])
	var hp_before := int(target.get("current_hp", 0))
	var pool_before := int(ResourcePoolRules.availability(caster, neutral_source).get("current", -1))
	check.call(pending.has("weapon_attack_bonus_request") and not pending.has("damage_request") and int(flat_roll.get("natural", 0)) == 8 and hp_before == 100 and flat_pending_windows.map(func(window): return str(window.get("window", ""))) == ["before_roll", "after_natural", "provisional_outcome"], "Flat shared spell attack suspends after its provisional window with original d20 and HP intact")
	var flat_resolved := SpellDamageRolls.settle_weapon_attack_bonus(caster, target, pending, neutral_source)
	check.call(bool(flat_resolved.get("success", false)) and bool(flat_resolved.get("hit", false)) and int(flat_resolved.get("post_roll_bonus", 0)) == 5 and int(flat_resolved.get("attack_roll", 0)) == int(flat_roll.get("total", 0)) + 5 and int(ResourcePoolRules.availability(caster, neutral_source).get("current", -1)) == pool_before - 1 and int(dice_counts["d20"]) == 1, "Flat +5 resumes without reroll, pays its exact source once, then applies fire damage")
	var flat_windows: Array = flat_resolved.get("resolution_windows", [])
	var flat_window_names: Array[String] = []
	for window in flat_windows:
		flat_window_names.append(str(window.get("window", "")))
	var flat_receipts_bound := flat_windows.size() == 5
	var flat_window_facts_observed := flat_windows.size() == 5
	var flat_cast: SpellResolutionContext = record.get("context", {}).get("spell_cast")
	var flat_adapter := SharedStepExecutor.SpellAdapter.new(flat_cast)
	for index in range(flat_windows.size()):
		var window: Dictionary = flat_windows[index]
		flat_receipts_bound = flat_receipts_bound and str(window.get("occurrence_id", "")) == str(flat_resolved.get("resolution_occurrence_id", "")) and str(window.get("kind", "")) == "spell_attack" and str(window.get("actor_id", "")) == caster.character_id and str(window.get("target_id", "")) == str(target.get("id", "")) and str(window.get("source_definition_id", "")) == str(flat_spell.get("id", "")) and str(window.get("source_owner_id", "")) == caster.character_id
		flat_cast.resolution_window = window
		flat_window_facts_observed = flat_window_facts_observed and SharedStepExecutor.evaluate_predicate({"fact": "resolution.window", "eq": str(window.get("window", ""))}, flat_adapter, target, [])
	var before_fields: Array = flat_windows[0].get("available_fields", []) if flat_windows.size() == 5 else []
	var natural_fields: Array = flat_windows[1].get("available_fields", []) if flat_windows.size() == 5 else []
	var provisional_fields: Array = flat_windows[2].get("available_fields", []) if flat_windows.size() == 5 else []
	var pre_damage_fields: Array = flat_windows[3].get("available_fields", []) if flat_windows.size() == 5 else []
	var post_fields: Array = flat_windows[4].get("available_fields", []) if flat_windows.size() == 5 else []
	var windows_gate_facts := flat_window_names == SpellDamageRolls.RESOLUTION_WINDOW_ORDER and not before_fields.has("roll_natural") and natural_fields.has("roll_natural") and not natural_fields.has("final_hit") and provisional_fields.has("provisional_hit") and not provisional_fields.has("final_hit") and not provisional_fields.has("damage_raw") and pre_damage_fields.has("final_hit") and not pre_damage_fields.has("damage_raw") and post_fields.has("damage_raw") and post_fields.has("damage_resolved") and post_fields.has("damage_hp_loss")
	check.call(flat_receipts_bound and flat_window_facts_observed and windows_gate_facts, "All five loaded neutral spell-attack windows expose ordered exact bindings and only facts available at that stage")
	var post_damage: Dictionary = flat_windows[4] if flat_windows.size() == 5 else {}
	var primary_damage_component: Dictionary = flat_resolved.get("damage_components", [{}])[0] if not flat_resolved.get("damage_components", []).is_empty() else {}
	flat_cast.resolution_window = post_damage
	var damage_occurrence_matches_receipt: bool = SharedStepExecutor.evaluate_predicate({"fact": "resolution.damage_occurrence_id", "eq": int(post_damage.get("damage_occurrence_id", 0))}, flat_adapter, target, [])
	check.call(int(post_damage.get("damage_occurrence_id", 0)) > 0 and damage_occurrence_matches_receipt and str(post_damage.get("damage_type", "")) == str(primary_damage_component.get("type", "")) and int(post_damage.get("damage_raw", -1)) == int(primary_damage_component.get("raw", -2)) and int(post_damage.get("damage_resolved", -1)) == int(primary_damage_component.get("resolved", -2)) and int(post_damage.get("damage_hp_loss", -1)) == int(primary_damage_component.get("hp_loss", -2)), "Post-damage window selects the existing raw/resolved/HP-loss component receipt")
	var flat_replay := SpellDamageRolls.settle_weapon_attack_bonus(caster, target, pending, neutral_source)
	check.call(bool(flat_replay.get("refused", false)) and int(dice_counts["d20"]) == 1, "Flat shared spell attack completion replay cannot reroll or charge again")
	target["current_hp"] = 100
	var neutral_pool_before_decline := int(ResourcePoolRules.availability(caster, neutral_source).get("current", -1))
	FighterChecks._seed_die(20, 8)
	var declined_pending := CombatAction.resolve_spell(caster, target, flat_spell, false, decisions)
	var declined_miss := SpellDamageRolls.settle_weapon_attack_bonus(caster, target, declined_pending, "")
	check.call(bool(declined_miss.get("success", false)) and not bool(declined_miss.get("hit", true)) and not declined_miss.has("damage_request") and not declined_miss.has("damage_components") and int(ResourcePoolRules.availability(caster, neutral_source).get("current", -1)) == neutral_pool_before_decline and declined_miss.get("resolution_windows", []).map(func(window): return str(window.get("window", ""))) == ["before_roll", "after_natural", "provisional_outcome"], "Declining a miss keeps its original cost and never opens or charges a damage-only consumer")
	SpellDamageRolls.clear_pending_requests()

	# The renamed ordered spell pauses the attack step, then resumes its own
	# target/step continuation before applying the hit rider and later steps.
	target["armor_class"] = 23
	target["current_hp"] = 100
	target["conditions"] = {}
	FighterChecks._seed_die(20, 8)
	var ordered_decisions := decisions.duplicate()
	ordered_decisions["metamagic:empowered"] = true
	ordered_decisions["defer_empowered"] = true
	var ordered_pending := CombatAction.resolve_spell(caster, target, ordered_spell, false, ordered_decisions)
	var ordered_record := SpellDamageRolls.weapon_attack_bonus_record(caster, target, ordered_pending)
	var ordered_hp_before := int(target.get("current_hp", 0))
	var renamed_pool_before := int(ResourcePoolRules.availability(caster, renamed_source).get("current", -1))
	check.call(ordered_pending.has("weapon_attack_bonus_request") and ordered_pending.has("ordered_continuation") and ordered_hp_before == 100, "Ordered shared attack suspends with its canonical continuation before damage or riders")
	var ordered_damage_pending := SpellDamageRolls.settle_weapon_attack_bonus(caster, target, ordered_pending, renamed_source)
	check.call(ordered_damage_pending.has("damage_request") and target.get("current_hp", 0) == 100 and not CombatAction.has_condition(target, "restrained") and int(ResourcePoolRules.availability(caster, renamed_source).get("current", -1)) == renamed_pool_before - 2, "A hit bonus charges once but keeps damage and ordered riders pending for the existing Empowered choice")
	var ordered_cast: SpellResolutionContext = ordered_record.get("context", {}).get("spell_cast")
	var ordered_occurrence_id := str(ordered_cast.resolution_window_context.get("base", {}).get("occurrence_id", "")) if ordered_cast != null else ""
	var ordered_paused_windows: Array = ordered_damage_pending.get("resolution_windows", [])
	check.call(ordered_paused_windows.map(func(window): return str(window.get("window", ""))) == ["before_roll", "after_natural", "provisional_outcome", "pre_damage"] and not ordered_damage_pending.has("_resolution_context"), "Renamed ordered attack retains the same occurrence through pre-damage pause without exposing internal host state")
	var ordered_resolved := CombatAction.finish_pending_spell_damage(caster, target, ordered_damage_pending, {"metamagic:empowered": true, "metamagic:empowered_dice": []})
	var ordered_steps: Array = ordered_resolved.get("step_results", [])
	var ordered_first: Dictionary = ordered_steps[1] if ordered_steps.size() > 1 else {}
	var ordered_attack_result: Dictionary = ordered_first.get("target_outcomes", [{}])[0].get("result", {}) if ordered_first.get("target_outcomes", []).size() > 0 else {}
	check.call(bool(ordered_resolved.get("success", false)) and ordered_first.get("hit", false) and int(ordered_attack_result.get("post_roll_bonus", 0)) == 8 and int(ResourcePoolRules.availability(caster, renamed_source).get("current", -1)) == renamed_pool_before - 2, "Renamed +8/cost 2 resumes the same ordered attack and charges only its exact source")
	check.call(str(ordered_attack_result.get("resolution_occurrence_id", "")) == ordered_occurrence_id and ordered_attack_result.get("resolution_windows", []).map(func(window): return str(window.get("window", ""))) == SpellDamageRolls.RESOLUTION_WINDOW_ORDER, "Renamed ordered attack completes all five windows on its original occurrence after Empowered settlement")
	check.call(ordered_steps.size() == 4 and str(ordered_steps[0].get("step_id", "")) == "rime_guard" and CombatAction.has_condition(target, "restrained") and not CombatAction.has_condition(target, "poisoned") and int(dice_counts["d20"]) == 3, "Prior self-grant step remains ordered before the final hit rider; miss rider stays absent and no attack rerolls")
	var ordered_hp_after := int(target.get("current_hp", 0))
	var ordered_replay := SpellDamageRolls.settle_weapon_attack_bonus(caster, target, ordered_pending, renamed_source)
	check.call(bool(ordered_replay.get("refused", false)) and int(target.get("current_hp", 0)) == ordered_hp_after and int(ResourcePoolRules.availability(caster, renamed_source).get("current", -1)) == renamed_pool_before - 2, "Ordered continuation cannot be applied twice by replaying its completed bonus")
	var renamed_pool: Dictionary = caster.numeric_resource_pools.get(renamed_source, {})
	if not renamed_pool.is_empty():
		renamed_pool["current"] = int(renamed_pool.get("maximum", 2))
	target["current_hp"] = 100
	target["armor_class"] = 20
	FighterChecks._seed_die(20, 8)
	var old_occurrence_answer := CombatAction.resolve_spell(caster, target, flat_spell, false, decisions)
	var old_occurrence_id := str(old_occurrence_answer.get("resolution_occurrence_id", ""))
	var old_decline := SpellDamageRolls.settle_weapon_attack_bonus(caster, target, old_occurrence_answer, "")
	FighterChecks._seed_die(20, 8)
	var fresh_occurrence_answer := CombatAction.resolve_spell(caster, target, flat_spell, false, decisions)
	var fresh_occurrence_id := str(fresh_occurrence_answer.get("resolution_occurrence_id", ""))
	var old_answer_against_fresh := SpellDamageRolls.settle_weapon_attack_bonus(caster, target, old_occurrence_answer, neutral_source)
	check.call(bool(old_decline.get("success", false)) and not old_occurrence_id.is_empty() and fresh_occurrence_id != old_occurrence_id and bool(old_answer_against_fresh.get("refused", false)), "An old occurrence answer is refused while a fresh occurrence remains pending")
	var attack_monsters: Array = decisions["monsters"]
	attack_monsters.clear()
	var removed_host_answer := SpellDamageRolls.settle_weapon_attack_bonus(caster, target, fresh_occurrence_answer, "")
	check.call(bool(removed_host_answer.get("refused", false)) and int(target.get("current_hp", 0)) == 100, "Removing the captured target from its encounter host invalidates its pending spell-attack answer")
	attack_monsters.append(target)
	SpellDamageRolls.clear_pending_requests()
	FighterChecks._seed_die(20, 8)
	var removed_source_answer := CombatAction.resolve_spell(caster, target, flat_spell, false, decisions)
	var removed_source_pool_before := int(ResourcePoolRules.availability(caster, renamed_source).get("current", -1))
	var removed_source_was_offered: bool = removed_source_answer.get("options", []).any(func(option): return str(option.get("source_instance_id", "")) == renamed_source)
	caster.numeric_resource_pools.erase(renamed_source)
	var removed_source_result := SpellDamageRolls.settle_weapon_attack_bonus(caster, target, removed_source_answer, renamed_source)
	check.call(removed_source_was_offered and bool(removed_source_result.get("refused", false)) and int(target.get("current_hp", 0)) == 100 and not bool(ResourcePoolRules.availability(caster, renamed_source).get("available", false)) and removed_source_pool_before >= 0, "Removing the exact offered source refuses before payment or damage")
	Dice.dice_rolled.disconnect(count_d20)
	SpellDamageRolls.clear_pending_requests()
	cast_host.hud = null
	test_hud.free()


static func _attack_result_adjustment_checks(check: Callable) -> void:
	DataLoader._load_content_type("res://data/fixtures/failed_save_bonus/classes/", "class")
	DataLoader._load_content_type("res://data/fixtures/shared_spells/spells/", "spell")
	var adjustment_fixture: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/fixtures/failed_save_bonus/classes/attack_result_adjustments.json"))
	var neutral_class: Dictionary = DataLoader.get_character_class("fixture:attack_total_adjustment_class")
	var renamed_class: Dictionary = DataLoader.get_character_class("fixture:defending_ac_adjustment_class")
	var neutral_feature: Dictionary = neutral_class.get("features_by_level", {}).get("1", [{}])[0]
	var renamed_feature: Dictionary = renamed_class.get("features_by_level", {}).get("1", [{}])[0]
	check.call(adjustment_fixture is Array and adjustment_fixture.size() == 2 and not DataLoader._feature_content_error(neutral_feature) and not DataLoader._feature_content_error(renamed_feature) and SharedSpell.content_error(DataLoader.get_spell("sandbox:owned_spell_attack_neutral")).is_empty(), "Loaded neutral total-subtraction and renamed defending-AC definitions validate without content-ID rules")
	var malformed := neutral_feature.duplicate(true)
	malformed["passive_effects"][0]["trigger"] = "failed_save"
	check.call(not DataLoader._feature_content_error(malformed).is_empty(), "Attack adjustments reject a trigger outside the declared provisional-hit window")
	var caster := Character.new()
	caster.initialize("S095 Attack Owner", "human", "sorcerer", AbilityScores.new())
	caster.character_id = "fixture:s095_attack_owner"
	caster.ability_scores.charisma = 18
	while caster.level < 3:
		caster.level_up()
	caster.sorcerer_metamagic_choices.append("empowered_spell")
	caster.feature_uses["sorcery_points"] = 3
	var neutral_source := "fixture:s095:downward_total"
	var renamed_source := "fixture:s095:raised_defense"
	var neutral_instance := neutral_feature.duplicate(true)
	neutral_instance["source_instance_id"] = neutral_source
	var renamed_instance := renamed_feature.duplicate(true)
	renamed_instance["source_instance_id"] = renamed_source
	caster.features.append(neutral_instance)
	caster.features.append(renamed_instance)
	var neutral_pool := ResourcePoolRules.acquire(caster, neutral_feature, neutral_source)
	var renamed_pool := ResourcePoolRules.acquire(caster, renamed_feature, renamed_source)
	var choices := SpellDamageRolls.attack_choice_options(caster, "shared_spell_attack", true, false, true)
	check.call(bool(neutral_pool.get("success", false)) and bool(renamed_pool.get("success", false)) and choices.size() == 2 and choices.any(func(option): return str(option.get("resolution", "")) == "attack_total_adjustment" and int(option.get("amount", 0)) == 6 and int(option.get("cost", 0)) == 1) and choices.any(func(option): return str(option.get("resolution", "")) == "defending_ac_adjustment" and int(option.get("amount", 0)) == 2 and int(option.get("cost", 0)) == 2), "Only the attack owner's exact live pools offer the loaded amount-6 subtraction and renamed amount-2 AC change")
	check.call(SpellDamageRolls.attack_choice_options(caster, "shared_spell_attack", false, false, true).is_empty(), "A miss cannot open an adjustment authored only for a provisional hit")
	var weapon_choices := SpellDamageRolls.attack_choice_options(caster, "weapon_attack", true, false, true)
	var natural_twenty := {"natural": 20, "modifier": 6, "total": 26, "is_crit": true}
	var critical_adjusted := SpellDamageRolls.apply_attack_result_adjustment(natural_twenty, 17, choices[0])
	check.call(weapon_choices.size() == 2 and SpellDamageRolls.attack_choice_options(caster, "weapon_attack", true, false, false).is_empty() and SpellDamageRolls.attack_choice_options(caster, "weapon_attack", true, false, true).size() == 2 and bool(critical_adjusted.get("attack_result", {}).get("is_crit", false)) and int(critical_adjusted.get("attack_result", {}).get("natural", 0)) == 20, "Both authored effects expose the weapon domain only when its provisional-hit chooser enables them, while the captured natural-20 critical marker remains unchanged")
	var target := {"id": "fixture:s095_target", "name": "S095 Target", "armor_class": 17, "current_hp": 100, "max_hp": 100, "is_alive": true, "temp_hp": 0, "conditions": {}}
	var cast_host := SpellCastContext.new()
	cast_host.caster = caster
	var hud := CombatHUD.new()
	cast_host.hud = hud
	cast_host.owner_label_for_character = func(_owner): return "Attack Owner"
	var decisions := {"players": [{"character": caster}], "monsters": [target], "cast_context": cast_host}
	var spell: Dictionary = DataLoader.get_spell("sandbox:owned_spell_attack_neutral")
	FighterChecks._seed_die(20, 15)
	var total_pending := CombatAction.resolve_spell(caster, target, spell, false, decisions)
	var total_record := SpellDamageRolls.weapon_attack_bonus_record(caster, target, total_pending)
	var original_attack: Dictionary = total_record.get("context", {}).get("attack_result", {}).duplicate(true)
	var original_hp := int(target["current_hp"])
	var before_pool := int(ResourcePoolRules.availability(caster, neutral_source).get("current", -1))
	var unrelated := Character.new()
	unrelated.initialize("Wrong S095 Owner", "human", "wizard", AbilityScores.new())
	var wrong_actor := SpellDamageRolls.settle_weapon_attack_bonus(unrelated, target, total_pending, neutral_source)
	var pool_record: Dictionary = caster.numeric_resource_pools.get(neutral_source, {})
	caster.numeric_resource_pools.erase(neutral_source)
	var removed_source := SpellDamageRolls.settle_weapon_attack_bonus(caster, target, total_pending, neutral_source)
	caster.numeric_resource_pools[neutral_source] = pool_record
	var total_miss := SpellDamageRolls.settle_weapon_attack_bonus(caster, target, total_pending, neutral_source)
	var miss_receipt: Dictionary = total_miss.get("attack_adjustment_receipt", {})
	check.call(total_pending.has("weapon_attack_bonus_request") and bool(wrong_actor.get("refused", false)) and bool(removed_source.get("refused", false)) and int(ResourcePoolRules.availability(caster, neutral_source).get("current", -1)) == before_pool - 1 and bool(total_miss.get("success", false)) and not bool(total_miss.get("hit", true)) and int(target["current_hp"]) == original_hp and int(miss_receipt.get("original", {}).get("natural", -1)) == int(original_attack.get("natural", -2)) and int(miss_receipt.get("original", {}).get("modifier", -9)) == int(original_attack.get("modifier", -8)) and int(miss_receipt.get("original", {}).get("total", -9)) == int(original_attack.get("total", -8)) and int(miss_receipt.get("original", {}).get("target_ac", -1)) == 17 and int(miss_receipt.get("final", {}).get("total", -9)) == int(original_attack.get("total", -8)) - 6 and str(miss_receipt.get("source_instance_id", "")) == neutral_source and str(miss_receipt.get("owner_id", "")) == caster.character_id and bool(miss_receipt.get("cost_paid", false)), "The captured total subtraction turns only the provisional hit into a miss; wrong owner/removal refuse, original roll/profile/AC and exact paid-source receipt remain, and no damage applies")
	var replay := SpellDamageRolls.settle_weapon_attack_bonus(caster, target, total_pending, neutral_source)
	check.call(bool(replay.get("refused", false)) and int(ResourcePoolRules.availability(caster, neutral_source).get("current", -1)) == before_pool - 1 and int(target["current_hp"]) == original_hp, "Replaying the settled adjustment cannot spend again or change the completed miss")
	FighterChecks._seed_die(20, 15)
	var decline_pending := CombatAction.resolve_spell(caster, target, spell, false, decisions)
	var stale_answer := SpellDamageRolls.settle_weapon_attack_bonus(caster, target, total_pending, neutral_source)
	var declined := SpellDamageRolls.settle_weapon_attack_bonus(caster, target, decline_pending, "")
	check.call(bool(stale_answer.get("refused", false)) and bool(declined.get("success", false)) and bool(declined.get("hit", false)) and not declined.has("attack_adjustment_receipt") and int(ResourcePoolRules.availability(caster, neutral_source).get("current", -1)) == before_pool - 1 and int(target["current_hp"]) < original_hp, "A declined new occurrence resolves its captured hit without adjustment payment; an old replay cannot consume or mutate that occurrence")
	SpellDamageRolls.clear_pending_requests()
	target["armor_class"] = 17
	target["current_hp"] = 100
	var ordered_spell: Dictionary = DataLoader.get_spell("sandbox:owned_spell_attack_renamed")
	var ordered_decisions := decisions.duplicate()
	ordered_decisions["metamagic:empowered"] = true
	ordered_decisions["defer_empowered"] = true
	FighterChecks._seed_die(20, 15)
	var ordered_pending := CombatAction.resolve_spell(caster, target, ordered_spell, false, ordered_decisions)
	var ordered_record := SpellDamageRolls.weapon_attack_bonus_record(caster, target, ordered_pending)
	var ordered_original: Dictionary = ordered_record.get("context", {}).get("attack_result", {}).duplicate(true)
	var defense_before := int(ResourcePoolRules.availability(caster, renamed_source).get("current", -1))
	var damage_pending := SpellDamageRolls.settle_weapon_attack_bonus(caster, target, ordered_pending, renamed_source)
	var defense_receipt: Dictionary = damage_pending.get("attack_adjustment_receipt", {})
	var pre_damage_windows: Array = damage_pending.get("resolution_windows", [])
	var pre_damage: Dictionary = pre_damage_windows[3] if pre_damage_windows.size() > 3 else {}
	check.call(ordered_pending.has("weapon_attack_bonus_request") and damage_pending.has("damage_request") and bool(defense_receipt.get("final", {}).get("hit", false)) and int(defense_receipt.get("original", {}).get("natural", -1)) == int(ordered_original.get("natural", -2)) and int(defense_receipt.get("original", {}).get("modifier", -9)) == int(ordered_original.get("modifier", -8)) and int(defense_receipt.get("original", {}).get("total", -9)) == int(ordered_original.get("total", -8)) and int(defense_receipt.get("original", {}).get("target_ac", -1)) == 17 and int(defense_receipt.get("final", {}).get("total", -9)) == int(ordered_original.get("total", -8)) and int(defense_receipt.get("final", {}).get("target_ac", -1)) == 19 and str(defense_receipt.get("source_instance_id", "")) == renamed_source and int(ResourcePoolRules.availability(caster, renamed_source).get("current", -1)) == defense_before - 2 and str(pre_damage.get("attack_adjustment", {}).get("source_instance_id", "")) == renamed_source and int(target["current_hp"]) == 100 and int(target["armor_class"]) == 17, "The renamed +2 defending-AC change leaves the captured hit, keeps original AC and source receipt through the real ordered damage choice, and pays its exact cost once without changing target AC")
	var settled := CombatAction.finish_pending_spell_damage(caster, target, damage_pending, {"metamagic:empowered": true, "metamagic:empowered_dice": []})
	var settled_steps: Array = settled.get("step_results", [])
	var attack_step: Dictionary = settled_steps[1] if settled_steps.size() > 1 else {}
	var attack_outcome: Dictionary = attack_step.get("target_outcomes", [{}])[0].get("result", {}) if attack_step.get("target_outcomes", []).size() > 0 else {}
	var replay_ac := SpellDamageRolls.settle_weapon_attack_bonus(caster, target, ordered_pending, renamed_source)
	check.call(bool(settled.get("success", false)) and bool(attack_outcome.get("hit", false)) and str(attack_outcome.get("attack_adjustment_receipt", {}).get("source_instance_id", "")) == renamed_source and int(attack_outcome.get("numeric_margin", -999)) == int(attack_outcome.get("attack_roll", 0)) - int(attack_outcome.get("attack_target_ac", 0)) and int(attack_outcome.get("attack_target_ac", -1)) == 19 and int(ResourcePoolRules.availability(caster, renamed_source).get("current", -1)) == defense_before - 2 and bool(replay_ac.get("refused", false)), "After the following ordered damage choice the same attack stays a hit, retains its adjusted numeric margin and AC receipt, and rejects replay without repaying")
	SpellDamageRolls.clear_pending_requests()
	DataLoader.load_all_data()
	cast_host.hud = null
	hud.free()


static func _post_roll_die_bonus_checks(check: Callable) -> void:
	DataLoader._load_content_type("res://data/fixtures/failed_save_bonus/classes/", "class")
	DataLoader._load_content_type("res://data/fixtures/shared_spells/spells/", "spell")
	var neutral_class: Dictionary = DataLoader.get_character_class("fixture:post_roll_die_neutral_class")
	var renamed_class: Dictionary = DataLoader.get_character_class("fixture:post_roll_die_renamed_class")
	var neutral_feature: Dictionary = neutral_class.get("features_by_level", {}).get("1", [{}])[0].duplicate(true)
	var renamed_feature: Dictionary = renamed_class.get("features_by_level", {}).get("1", [{}])[0].duplicate(true)
	check.call(not neutral_feature.is_empty() and not renamed_feature.is_empty() and DataLoader._feature_content_error(neutral_feature).is_empty() and DataLoader._feature_content_error(renamed_feature).is_empty(), "Production DataLoader accepts neutral d6/cost1 and renamed d8/cost2 source-die definitions")
	if neutral_feature.is_empty() or renamed_feature.is_empty():
		return
	var malformed_both: Dictionary = neutral_feature.duplicate(true)
	malformed_both["passive_effects"][0]["amount"] = 4
	var unsupported_die: Dictionary = renamed_feature.duplicate(true)
	unsupported_die["passive_effects"][0]["die_size"] = 5
	check.call(not DataLoader._feature_content_error(malformed_both).is_empty() and not DataLoader._feature_content_error(unsupported_die).is_empty(), "A post-roll operation rejects simultaneous fixed amount and die_size plus unsupported die sizes")
	var caster := Character.new()
	caster.initialize("Post-roll Die Caster", "human", "wizard", AbilityScores.new())
	caster.character_id = "fixture:post_roll_die_caster"
	var cast_host := SpellCastContext.new()
	cast_host.caster = caster
	var test_hud := CombatHUD.new()
	cast_host.hud = test_hud
	cast_host.owner_label_for_character = func(_owner): return "Caster"
	var dice_counts := {20: 0, 6: 0, 8: 0}
	var bonus_roll_payloads: Array[Dictionary] = []
	var count_bonus_rolls := func(payload: Dictionary) -> void:
		var sides := int(payload.get("sides", 0))
		if dice_counts.has(sides):
			dice_counts[sides] += 1
			if sides in [6, 8]:
				bonus_roll_payloads.append(payload.duplicate(true))
	Dice.dice_rolled.connect(count_bonus_rolls)
	var save_owner := Character.new()
	save_owner.initialize("Neutral Die Save Owner", "human", "fighter", AbilityScores.new())
	save_owner.character_id = "fixture:post_roll_die_save_owner"
	save_owner.ability_scores.dexterity = -100
	var neutral_source := "fixture:post_roll_die_save_source"
	neutral_feature["source_instance_id"] = neutral_source
	save_owner.features.append(neutral_feature)
	var neutral_pool := ResourcePoolRules.acquire(save_owner, neutral_feature, neutral_source)
	var save_spell: Dictionary = DataLoader.get_spell("sandbox:steady_save_burst")
	var count_before_save := dice_counts.duplicate()
	FighterChecks._seed_die(20, 1)
	var save_pending := CombatAction.resolve_spell(caster, save_owner, save_spell, false, {"cast_context": cast_host})
	var save_record := SpellDamageRolls.failed_save_numeric_bonus_record(caster, save_owner, save_pending)
	var save_test: Dictionary = save_pending.get("save_test", {})
	var save_options := SpellDamageRolls.failed_save_choice_options(save_owner, "DEX")
	var save_source_offered := save_options.any(func(option): return str(option.get("source_instance_id", "")) == neutral_source and str(option.get("resolution", "")) == "die_bonus" and int(option.get("die_size", 0)) == 6)
	var no_save_die_before_accept := int(dice_counts[6]) == int(count_before_save[6])
	SpellDamageRolls.failed_save_choice_options(save_owner, "DEX")
	var die_save_query_is_pure := int(dice_counts[6]) == int(count_before_save[6])
	var save_pool_before := int(ResourcePoolRules.availability(save_owner, neutral_source).get("current", -1))
	var save_result := SpellDamageRolls.settle_failed_save_numeric_bonus(caster, save_owner, save_pending, neutral_source)
	var settled_save_test: Dictionary = save_result.get("save_test", {})
	var saved_d6: Dictionary = settled_save_test.get("post_roll_bonus_die", {})
	var save_roll_proof := int(save_result.get("save_total", -1)) == int(settled_save_test.get("natural_roll", -100)) + int(settled_save_test.get("modifier", 0)) + int(saved_d6.get("total", 0))
	check.call(bool(neutral_pool.get("success", false)) and save_pending.has("save_bonus_request") and save_source_offered and no_save_die_before_accept and die_save_query_is_pure, "Neutral failed-save source offers d6 without rolling during the save or either availability query")
	check.call(not bool(save_result.get("saved", true)) and save_roll_proof and int(saved_d6.get("sides", 0)) == 6 and int(dice_counts[20]) == int(count_before_save[20]) + 1 and int(dice_counts[6]) == int(count_before_save[6]) + 1 and int(save_pool_before - ResourcePoolRules.availability(save_owner, neutral_source).get("current", -1)) == 1, "Accepted d6 is rolled once, adds to the captured save, and pay-on-choice charges one use while failure remains")
	var save_replay := SpellDamageRolls.settle_failed_save_numeric_bonus(caster, save_owner, save_pending, neutral_source)
	check.call(bool(save_replay.get("refused", false)) and int(dice_counts[6]) == int(count_before_save[6]) + 1, "Save die completion replay cannot roll again")
	SpellDamageRolls.clear_pending_requests()
	var renamed_owner := Character.new()
	renamed_owner.initialize("Renamed Die Save Owner", "human", "wizard", AbilityScores.new())
	renamed_owner.character_id = "fixture:post_roll_die_renamed_save_owner"
	renamed_owner.ability_scores.constitution = -100
	var renamed_source := "fixture:post_roll_die_renamed_save_source"
	renamed_feature["source_instance_id"] = renamed_source
	renamed_owner.features.append(renamed_feature)
	var renamed_pool := ResourcePoolRules.acquire(renamed_owner, renamed_feature, renamed_source)
	var con_spell: Dictionary = DataLoader.get_spell("sandbox:failed_save_bonus_con_area")
	FighterChecks._seed_die(20, 1)
	var con_pending := CombatAction.resolve_spell(caster, renamed_owner, con_spell, false, {"cast_context": cast_host})
	var con_options := SpellDamageRolls.failed_save_choice_options(renamed_owner, "CON")
	var con_die_offered := con_options.any(func(option): return str(option.get("source_instance_id", "")) == renamed_source and str(option.get("resolution", "")) == "die_bonus" and int(option.get("die_size", 0)) == 8)
	var renamed_pool_before := int(ResourcePoolRules.availability(renamed_owner, renamed_source).get("current", -1))
	var count_before_d8 := int(dice_counts[8])
	var con_result := SpellDamageRolls.settle_failed_save_numeric_bonus(caster, renamed_owner, con_pending, renamed_source)
	var saved_d8: Dictionary = con_result.get("save_test", {}).get("post_roll_bonus_die", {})
	check.call(bool(renamed_pool.get("success", false)) and con_pending.has("save_bonus_request") and con_die_offered and not bool(con_result.get("saved", true)) and int(saved_d8.get("sides", 0)) == 8 and int(dice_counts[8]) == count_before_d8 + 1 and int(renamed_pool_before - ResourcePoolRules.availability(renamed_owner, renamed_source).get("current", -1)) == 0, "Renamed d8/cost2 remains an authored alternative and pay-on-converted-success leaves a still-failing save free")
	SpellDamageRolls.clear_pending_requests()
	var attack_owner := ClassFeatureChecks._character("sorcerer", 3)
	attack_owner.sorcerer_metamagic_choices.append("empowered_spell")
	attack_owner.feature_uses["sorcery_points"] = 3
	attack_owner.ability_scores.charisma = 14
	attack_owner.character_id = "fixture:post_roll_die_shared_attack_owner"
	var attack_source := "fixture:post_roll_die_shared_attack_source"
	renamed_feature["source_instance_id"] = attack_source
	attack_owner.features.append(renamed_feature)
	var attack_pool := ResourcePoolRules.acquire(attack_owner, renamed_feature, attack_source)
	var attack_target := {"id": "fixture:post_roll_die_shared_attack_target", "name": "Shared Attack Target", "armor_class": 13, "current_hp": 100, "max_hp": 100, "is_alive": true, "conditions": {}}
	var attack_host := SpellCastContext.new()
	attack_host.caster = attack_owner
	attack_host.hud = test_hud
	attack_host.owner_label_for_character = func(_owner): return "Die Owner"
	var attack_decisions := {"players": [{"character": attack_owner}], "monsters": [attack_target], "cast_context": attack_host, "hud": test_hud, "metamagic:empowered": true, "defer_empowered": true}
	var attack_spell: Dictionary = DataLoader.get_spell("sandbox:owned_spell_attack_renamed")
	var count_before_attack := int(dice_counts[8])
	FighterChecks._seed_die(20, 8)
	var attack_pending := CombatAction.resolve_spell(attack_owner, attack_target, attack_spell, false, attack_decisions)
	var attack_record := SpellDamageRolls.weapon_attack_bonus_record(attack_owner, attack_target, attack_pending)
	var captured_attack: Dictionary = attack_record.get("context", {}).get("attack_result", {})
	var attack_options := SpellDamageRolls.attack_numeric_bonus_options(attack_owner, "shared_spell_attack")
	var attack_die_offered := attack_options.any(func(option): return str(option.get("source_instance_id", "")) == attack_source and str(option.get("bonus_kind", "")) == "die" and int(option.get("die_size", 0)) == 8)
	SpellDamageRolls.attack_numeric_bonus_options(attack_owner, "shared_spell_attack")
	var no_spell_die_before_accept := int(dice_counts[8]) == count_before_attack
	var d20_before_attack_accept := int(dice_counts[20])
	var bonus_payload_count_before_attack := bonus_roll_payloads.size()
	var attack_pool_before := int(ResourcePoolRules.availability(attack_owner, attack_source).get("current", -1))
	var attack_result := SpellDamageRolls.settle_weapon_attack_bonus(attack_owner, attack_target, attack_pending, attack_source)
	var ordered_die_total := int(bonus_roll_payloads[bonus_payload_count_before_attack].get("total", -1)) if bonus_roll_payloads.size() > bonus_payload_count_before_attack else -1
	var d8_roll_count_after_accept := int(dice_counts[8])
	var pending_attack_hit: bool = attack_result.has("damage_request") and int(attack_target.get("current_hp", 0)) == 100
	var attack_cost_paid_once := int(attack_pool_before - ResourcePoolRules.availability(attack_owner, attack_source).get("current", -1)) == 2
	var attack_resolved := CombatAction.finish_pending_spell_damage(attack_owner, attack_target, attack_result, {"metamagic:empowered": true, "metamagic:empowered_dice": []}) if pending_attack_hit else attack_result
	var attack_steps: Array = attack_resolved.get("step_results", [])
	var attack_step: Dictionary = attack_steps[1] if attack_steps.size() > 1 else {}
	var attack_outcomes: Array = attack_step.get("target_outcomes", [])
	var attack_spell_outcome: Dictionary = attack_outcomes[0].get("result", {}) if not attack_outcomes.is_empty() else attack_resolved
	var attack_die: Dictionary = attack_spell_outcome.get("post_roll_bonus_die", {})
	var resolved_attack_roll := int(attack_spell_outcome.get("attack_roll", attack_result.get("attack_roll", -1)))
	check.call(bool(attack_pool.get("success", false)) and attack_pending.has("weapon_attack_bonus_request") and attack_pending.has("ordered_continuation") and attack_die_offered and no_spell_die_before_accept, "Shared-spell attack offers the renamed d8 through its ordered chooser without rolling on query")
	check.call(pending_attack_hit and attack_cost_paid_once and int(dice_counts[20]) == d20_before_attack_accept and d8_roll_count_after_accept == count_before_attack + 2, "Accepted shared-spell d8 converts the captured miss; one accepted d8 and one spell-damage d8 are rolled before suspension")
	check.call(bool(attack_resolved.get("success", false)) and bool(attack_spell_outcome.get("hit", false)) and int(attack_die.get("sides", 0)) == 8 and int(attack_die.get("total", -1)) == ordered_die_total and resolved_attack_roll == int(captured_attack.get("total", 0)) + ordered_die_total and int(dice_counts[8]) == d8_roll_count_after_accept and int(dice_counts[20]) == d20_before_attack_accept and int(attack_pool_before - ResourcePoolRules.availability(attack_owner, attack_source).get("current", -1)) == 2, "The same accepted d8 and final hit survive the Empowered damage continuation without rerolling or repaying")
	check.call(attack_steps.size() == 4 and CombatAction.has_condition(attack_target, "restrained") and not CombatAction.has_condition(attack_target, "poisoned"), "Ordered shared-spell hit rider waits for the resumed die-modified result")
	Dice.dice_rolled.disconnect(count_bonus_rolls)
	SpellDamageRolls.clear_pending_requests()
	attack_host.hud = null
	cast_host.hud = null
	test_hud.free()


static func _fact_predicate_checks(check: Callable) -> void:
	var neutral: Dictionary = DataLoader.get_spell("sandbox:fact_window_neutral")
	var renamed: Dictionary = DataLoader.get_spell("sandbox:fact_window_renamed")
	check.call(not neutral.is_empty() and not renamed.is_empty() and SharedSpell.content_error(neutral).is_empty() and SharedSpell.content_error(renamed).is_empty(), "Neutral and renamed nested fact predicates load through shared spell validation")
	if neutral.is_empty() or renamed.is_empty(): return
	var caster := Character.new()
	caster.initialize("Fact caster", "human", "wizard", AbilityScores.new())
	caster.character_id = "fact-caster"
	caster.spell_slots["1"] = 2
	caster.current_hp = 10
	var target := caster
	var cast_context := SpellResolutionContext.new()
	cast_context.caster = caster
	cast_context.target = target
	cast_context.spell = neutral
	cast_context.effect_cast = {"source_id": "fact-source", "caster_id": caster.character_id}
	cast_context.spell_definition_id = str(neutral.get("id", ""))
	cast_context.source_definition_id = cast_context.spell_definition_id
	cast_context.source_instance_id = "fact-source"
	cast_context.source_owner_id = caster.character_id
	var adapter := SharedStepExecutor.SpellAdapter.new(cast_context)
	var neutral_when: Dictionary = neutral["steps"][0]["effects"][1]["when"]
	var renamed_when: Dictionary = renamed["steps"][0]["effects"][0]["when"]
	check.call(SharedStepExecutor.evaluate_predicate(neutral_when, adapter, target, []) and not SharedStepExecutor.evaluate_predicate(renamed_when, adapter, target, []), "Nested all/any/not predicates distinguish authored neutral and renamed eligibility")
	var pool_definition := {"id": "fact-pool", "level": 1, "resource_pool": {"id": "fact-pool", "capacity_formula": 2, "initial_quantity": 2}}
	var pool_acquired := ResourcePoolRules.acquire(caster, pool_definition, "fact-source")
	var grant_added := caster.add_campaign_modifier("stat", "AC", 2, 60, 0, "fact-source")
	caster.max_hp = 100
	var pool_before: Dictionary = caster.numeric_resource_pools.duplicate(true)
	var grant_before: Array = caster.modifiers.duplicate(true)
	caster.current_hp = 25
	cast_context.spell = neutral
	var neutral_off := CombatAction.resolve_spell(caster, caster, neutral, false)
	var neutral_off_hp := caster.current_hp
	caster.level = 3
	caster.current_hp = 20
	var renamed_on := CombatAction.resolve_spell(caster, caster, renamed, false)
	var renamed_on_hp := caster.current_hp
	var renamed_steps: Array = renamed_on.get("step_results", [])
	var renamed_outcomes: Array = renamed_steps[0].get("target_outcomes", []) if not renamed_steps.is_empty() else []
	var renamed_effect_result: Dictionary = renamed_outcomes[0].get("result", {}) if not renamed_outcomes.is_empty() else {}
	caster.current_hp = 45
	var renamed_off := CombatAction.resolve_spell(caster, caster, renamed, false)
	check.call(pool_acquired.get("success", false) and grant_added.get("success", false) and int(neutral_off.get("healing", 0)) == 0 and neutral_off_hp == 25 and int(renamed_effect_result.get("healing", 0)) == 5 and renamed_on_hp == 25 and int(renamed_off.get("healing", 0)) == 0 and caster.current_hp == 45, "Loaded spell effect eligibility follows changed represented facts and applies only its authored effect (pool %s grant %s neutral %s hp%s renamed %s hp%s max%s final%s)" % [str(pool_acquired), str(grant_added), str(neutral_off), str(neutral_off_hp), str(renamed_on), str(renamed_on_hp), str(caster.max_hp), str(caster.current_hp)])
	check.call(caster.numeric_resource_pools == pool_before and caster.modifiers == grant_before and int(caster.spell_slots["1"]) == 2, "Fact queries and eligibility changes do not reacquire, spend, or restart an owned pool or timed grant")

	var missing_context := SpellResolutionContext.new()
	missing_context.caster = Character.new()
	missing_context.spell = neutral
	missing_context.effect_cast = {}
	var missing_adapter := SharedStepExecutor.SpellAdapter.new(missing_context)
	var missing_target := {"name": "No current HP fact"}
	var missing_id_under_not := {"not": {"fact": "target.id", "eq": "some-target"}}
	var missing_number_under_not := {"not": {"fact": "target.current_hp", "ne": 0}}
	var present_zero_under_not := {"not": {"fact": "target.current_hp", "ne": 0}}
	var missing_result_measure_under_not := {"not": {"result": {"step": "prior", "target": "same", "component": "fire", "measure": "resolved"}, "ne": 0}}
	var present_zero_result_under_not := {"not": {"result": {"step": "prior", "target": "same", "component": "fire", "measure": "resolved"}, "ne": 0}}
	var zero_target := {"current_hp": 0}
	var valid_or_missing := {"any": [missing_id_under_not, {"fact": "target.current_hp", "eq": 0}]}
	var missing_measure_results: Array = [{"step_id": "prior", "target_outcomes": [{"target": zero_target, "damage_components": [{"type": "fire", "raw": 0}]}]}]
	var present_zero_results: Array = [{"step_id": "prior", "target_outcomes": [{"target": zero_target, "damage_components": [{"type": "fire", "raw": 0, "resolved": 0}]}]}]
	check.call(not SharedStepExecutor.evaluate_predicate(missing_id_under_not, missing_adapter, missing_target, []) and not SharedStepExecutor.evaluate_predicate(missing_number_under_not, missing_adapter, missing_target, []) and SharedStepExecutor.evaluate_predicate(present_zero_under_not, missing_adapter, zero_target, []) and not SharedStepExecutor.evaluate_predicate(missing_result_measure_under_not, missing_adapter, zero_target, missing_measure_results) and SharedStepExecutor.evaluate_predicate(present_zero_result_under_not, missing_adapter, zero_target, present_zero_results) and SharedStepExecutor.evaluate_predicate(valid_or_missing, missing_adapter, zero_target, []), "Unavailable facts/results stay nonqualifying under not while represented zero remains distinct and valid OR branches can qualify")

	var invalid_bool_numeric := neutral.duplicate(true)
	invalid_bool_numeric["steps"][0]["effects"][0]["when"] = {"fact": "actor.level", "eq": true}
	var invalid_empty_fact_not := neutral.duplicate(true)
	invalid_empty_fact_not["steps"][0]["effects"][0]["when"] = {"not": {"fact": "missing.world_fact", "eq": true}}
	var invalid_numeric_string := neutral.duplicate(true)
	invalid_numeric_string["steps"][0]["effects"][0]["when"] = {"fact": "target.current_hp", "gt": "0"}
	check.call(not SharedSpell.content_error(invalid_bool_numeric).is_empty() and not SharedSpell.content_error(invalid_empty_fact_not).is_empty() and not SharedSpell.content_error(invalid_numeric_string).is_empty(), "Malformed, unknown-fact and wrong-type predicates refuse content before execution")
	var slots_before := int(caster.spell_slots["1"])
	var refused := CombatAction.resolve_spell(caster, caster, invalid_bool_numeric, true)
	check.call(not refused.get("success", true) and int(caster.spell_slots["1"]) == slots_before and caster.current_hp == 45 and caster.numeric_resource_pools == pool_before and caster.modifiers == grant_before, "Invalid predicate content refuses a production cast before slot or target/source mutation")


static func _action_history_checks(check: Callable) -> void:
	var neutral: Dictionary = DataLoader.get_spell("sandbox:action_history_neutral")
	var renamed: Dictionary = DataLoader.get_spell("sandbox:action_history_renamed")
	check.call(not neutral.is_empty() and not renamed.is_empty() and SharedSpell.content_error(neutral).is_empty() and SharedSpell.content_error(renamed).is_empty(), "Neutral and renamed action-history consumers load through shared spell validation")
	if neutral.is_empty() or renamed.is_empty():
		return
	var history := CombatActionHistory.new()
	var first := {"id": "history-first"}
	var second := {"id": "history-second"}
	history.begin_turn(first, 1)
	var host := SpellCastContext.new()
	host.action_history = history
	var cast := SpellResolutionContext.new()
	cast.caster = Character.new()
	cast.spatial_host = host
	cast.spell = neutral
	var adapter := SharedStepExecutor.SpellAdapter.new(cast)
	var acted_query: Dictionary = neutral["steps"][0]["effects"][0]["when"]
	var attacked_query: Dictionary = renamed["steps"][1]["effects"][0]["when"]
	check.call(SharedStepExecutor.evaluate_predicate({"fact": "target.first_round", "eq": true}, adapter, first, []) and SharedStepExecutor.evaluate_predicate({"fact": "target.first_own_turn", "eq": true}, adapter, first, []) and not SharedStepExecutor.evaluate_predicate({"fact": "target.first_own_turn", "eq": true}, adapter, second, []), "First round and current first own turn are separate actor-boundary facts")
	history.record_action(first)
	var turn_serial_before_resume := history._turn_serial
	history.begin_turn(first, 1)
	history.record_attack(first, second)
	check.call(history._turn_serial == turn_serial_before_resume and SharedStepExecutor.evaluate_predicate(acted_query, adapter, first, []) and SharedStepExecutor.evaluate_predicate(attacked_query, adapter, second, []) and not SharedStepExecutor.evaluate_predicate(attacked_query, adapter, first, []), "Committed action and resolved attack receipts stay on their actual actor/target, and resuming the same initiative turn does not reset its boundary")
	history.begin_turn(second, 1)
	check.call(SharedStepExecutor.evaluate_predicate({"fact": "target.first_own_turn", "eq": true}, adapter, second, []) and not SharedStepExecutor.evaluate_predicate({"fact": "target.attacked_since_owner_turn", "eq": true}, adapter, second, []), "Another actor turn resets combat-turn and owner-turn intervals without borrowing prior history")
	history.record_action(second)
	history.record_attack(first, second)
	check.call(SharedStepExecutor.evaluate_predicate(attacked_query, adapter, second, []) and SharedStepExecutor.evaluate_predicate({"fact": "target.acted_since_owner_turn", "eq": true}, adapter, second, []), "Events after the named turn boundary qualify once for that exact subject")
	var joined_late := {"id": "history-joined-after-initiative"}
	var late_first_turn_before_start: Dictionary = history.fact(joined_late, "target.first_own_turn")
	check.call(not SharedStepExecutor.evaluate_predicate({"not": {"fact": "target.acted_since_owner_turn", "eq": true}}, adapter, joined_late, []) and not bool(history.fact(joined_late, "target.attacked_since_owner_turn").get("available", true)), "An actor with no own-turn boundary stays unavailable under action-history negation")
	history.begin_turn(joined_late, 2)
	check.call(not bool(late_first_turn_before_start.get("available", true)) and SharedStepExecutor.evaluate_predicate({"fact": "target.first_own_turn", "eq": true}, adapter, joined_late, []) and not bool(history.fact(joined_late, "target.first_round").get("value", true)), "A participant joining in round two gets its first own turn without inheriting first-round eligibility")
	history.begin_turn(first, 2)
	check.call(not SharedStepExecutor.evaluate_predicate({"fact": "target.first_round", "eq": true}, adapter, first, []) and not SharedStepExecutor.evaluate_predicate({"fact": "target.first_own_turn", "eq": true}, adapter, first, []) and not SharedStepExecutor.evaluate_predicate({"fact": "target.attacked_since_combat_turn", "eq": true}, adapter, second, []), "Later round and current-turn boundaries reset explicitly while owner interval history remains independent")
	var malformed := neutral.duplicate(true)
	malformed["steps"][0]["effects"][0]["when"] = {"fact": "target.attacked_since_combat_turn", "eq": 1}
	check.call(not SharedSpell.content_error(malformed).is_empty(), "History facts reject non-Boolean authored comparisons before a cast")


static func _damage_history_checks(check: Callable) -> void:
	var source_spell: Dictionary = DataLoader.get_spell("sandbox:damage_history_source")
	var turn_spell: Dictionary = DataLoader.get_spell("sandbox:damage_history_turn_neutral")
	var time_spell: Dictionary = DataLoader.get_spell("sandbox:damage_history_time_renamed")
	check.call(not source_spell.is_empty() and not turn_spell.is_empty() and not time_spell.is_empty() and SharedSpell.content_error(source_spell).is_empty() and SharedSpell.content_error(turn_spell).is_empty() and SharedSpell.content_error(time_spell).is_empty(), "Neutral turn, renamed campaign-time, and loaded damage source definitions pass shared validation")
	if source_spell.is_empty() or turn_spell.is_empty() or time_spell.is_empty(): return
	var prior_seconds := int(GameManager.campaign_elapsed_seconds)
	GameManager.campaign_elapsed_seconds = 5000
	var source := Character.new()
	source.character_id = "damage-source-a"
	var second_source := Character.new()
	second_source.character_id = "damage-source-b"
	var target := Character.new()
	target.character_id = "damage-target-a"
	target.max_hp = 30
	target.current_hp = 30
	target.temp_hp = 3
	var history := CombatActionHistory.new()
	history.begin_turn(source, 1)
	var fire_receipt: Dictionary = CombatAction.resolve_damage(target, 8, "fire", {"combat_history": history, "damage_source_instance_id": "spell:test:damage-a"}, false, false, source)
	var time_fact: Dictionary = target.recent_damage_measure(source.character_id, "spell:test:damage-a", "hp_loss", 5000)
	var source_isolated: Dictionary = target.recent_damage_measure(second_source.character_id, "spell:test:damage-a", "hp_loss", 5000)
	var turn_fact: Dictionary = history.damage_measure(target, source, "spell:test:damage-a", "hp_loss", "combat_turn")
	var raw_turn: Dictionary = history.damage_measure(target, source, "spell:test:damage-a", "raw", "combat_turn")
	var absorbed_turn: Dictionary = history.damage_measure(target, source, "spell:test:damage-a", "absorbed", "combat_turn")
	check.call(int(fire_receipt.get("raw", -1)) == 8 and int(fire_receipt.get("resolved", -1)) == 8 and int(fire_receipt.get("absorbed", -1)) == 3 and int(fire_receipt.get("hp_loss", -1)) == 5 and int(turn_fact.get("value", -1)) == 5 and int(raw_turn.get("value", -1)) == 8 and int(absorbed_turn.get("value", -1)) == 3 and int(time_fact.get("value", -1)) == 5 and int(source_isolated.get("value", -1)) == 0, "One real typed settlement records distinct raw/resolved/absorbed/HP-loss measures against exact target and source IDs")
	var second_target := Character.new()
	second_target.character_id = "damage-target-b"
	second_target.max_hp = 40
	second_target.current_hp = 40
	var second_target_receipt: Dictionary = CombatAction.resolve_damage(second_target, 4, "fire", {"combat_history": history, "damage_source_instance_id": "spell:test:damage-a"}, false, false, source)
	var first_target_history: Dictionary = target.recent_damage_measure(source.character_id, "spell:test:damage-a", "raw", 5000)
	var second_target_history: Dictionary = second_target.recent_damage_measure(source.character_id, "spell:test:damage-a", "raw", 5000)
	check.call(int(second_target_receipt.get("hp_loss", -1)) == 4 and int(first_target_history.get("value", -1)) == 8 and int(second_target_history.get("value", -1)) == 4, "Two actual Character targets sharing one exact source instance keep independent settled histories")
	var overkill_target := Character.new()
	overkill_target.character_id = "damage-target-overkill"
	overkill_target.max_hp = 30
	overkill_target.current_hp = 2
	var overkill_receipt: Dictionary = CombatAction.resolve_damage(overkill_target, 9, "fire", {"combat_history": history, "damage_source_instance_id": "spell:test:overkill"}, false, false, source)
	var overkill_history: Dictionary = overkill_target.recent_damage_measure(source.character_id, "spell:test:overkill", "hp_loss", 5000)
	check.call(int(overkill_receipt.get("raw", -1)) == 9 and int(overkill_receipt.get("resolved", -1)) == 9 and int(overkill_receipt.get("hp_loss", -1)) == 2 and int(overkill_history.get("value", -1)) == 2, "Overkill retains resolved damage while HP-loss history caps at the target's actual remaining HP")
	history.begin_turn(target, 1)
	var owner_source_start: Dictionary = history.damage_measure(target, source, "spell:test:damage-a", "hp_loss", "owner_turn")
	check.call(owner_source_start.get("available", false) and int(owner_source_start.get("value", -1)) == 0, "The target's explicit own-turn start creates an empty independent damage boundary")
	target.feature_uses["damage_immunities"] = ["fire"]
	var immune_receipt: Dictionary = CombatAction.resolve_damage(target, 6, "fire", {"combat_history": history, "damage_source_instance_id": "spell:test:damage-b"}, false, false, second_source)
	var first_source_still_isolated: Dictionary = history.damage_measure(target, source, "spell:test:damage-a", "raw", "owner_turn")
	var second_source_prevented: Dictionary = history.damage_measure(target, second_source, "spell:test:damage-b", "prevented", "owner_turn")
	check.call(int(immune_receipt.get("raw", -1)) == 6 and int(immune_receipt.get("resolved", -1)) == 0 and int(immune_receipt.get("hp_loss", -1)) == 0 and int(first_source_still_isolated.get("value", -1)) == 0 and int(second_source_prevented.get("value", -1)) == 6, "Immunity records prevented damage under the second exact source without aliasing the first")
	var saved := target.to_dict()
	var loaded := Character.new()
	var save_valid := Character.saved_damage_history_error(saved, 5000).is_empty()
	loaded.from_dict(saved)
	var restored_measure: Dictionary = loaded.recent_damage_measure(second_source.character_id, "spell:test:damage-b", "prevented", 5000)
	var malformed := saved.duplicate(true)
	malformed["recent_damage_history"][0]["source_actor_id"] = ""
	var future := saved.duplicate(true)
	future["recent_damage_history"][0]["at_seconds"] = 5001
	check.call(save_valid and int(restored_measure.get("value", -1)) == 6 and not Character.saved_damage_history_error(malformed, 5000).is_empty() and not Character.saved_damage_history_error(future, 5000).is_empty(), "Allowed Character DTO retains attributed measures and preflight rejects missing source IDs and future timestamps")
	var before_deadline: Dictionary = loaded.recent_damage_measure(second_source.character_id, "spell:test:damage-b", "prevented", 5059)
	var at_deadline: Dictionary = loaded.recent_damage_measure(second_source.character_id, "spell:test:damage-b", "prevented", 5060)
	var after_jump: Dictionary = loaded.recent_damage_measure(second_source.character_id, "spell:test:damage-b", "prevented", 9000)
	check.call(int(before_deadline.get("value", -1)) == 6 and int(at_deadline.get("value", -1)) == 0 and int(after_jump.get("value", -1)) == 0, "Campaign history expires at the declared equality boundary and time jumps do not restart or fabricate receipts")
	var attack_probe: Dictionary = DataLoader.get_spell("sandbox:action_history_renamed")
	var miss_target := {"id": "damage-miss-target", "name": "Damage History Miss", "armor_class": 100, "max_hp": 30, "current_hp": 30, "is_alive": true, "conditions": {}}
	# High AC still allows a natural 20; this check requires an actual miss.
	FighterChecks._seed_die(20, 1)
	var miss_result: Dictionary = CombatAction.resolve_spell(source, miss_target, attack_probe, false, {}, [], 1, 5)
	randomize()
	var refused_spell := turn_spell.duplicate(true)
	refused_spell["steps"][1]["effects"][0]["when"]["fact"] = "target.not_a_damage_history_fact"
	var refused_before := target.recent_damage_history.size()
	var refused_result: Dictionary = CombatAction.resolve_spell(source, target, refused_spell, true, {}, [], 1, 5)
	check.call(not bool(miss_result.get("hit", true)) and int(miss_target.get("current_hp", -1)) == 30 and not bool(refused_result.get("success", true)) and target.recent_damage_history.size() == refused_before, "A real attack miss and malformed/refused command add no damage-history entry")
	GameManager.campaign_elapsed_seconds = prior_seconds


static func _distance_predicate_checks(check: Callable) -> void:
	var neutral: Dictionary = DataLoader.get_spell("sandbox:distance_actor_neutral")
	var renamed: Dictionary = DataLoader.get_spell("sandbox:distance_source_renamed")
	check.call(not neutral.is_empty() and not renamed.is_empty() and SharedSpell.content_error(neutral).is_empty() and SharedSpell.content_error(renamed).is_empty(), "Neutral actor-relative and renamed source-relative distance consumers load through shared spell validation")
	if neutral.is_empty() or renamed.is_empty(): return
	var caster := Character.new()
	caster.initialize("Distance caster", "human", "fighter", AbilityScores.new())
	caster.character_id = "distance-caster"
	var first_target := Character.new()
	first_target.initialize("First twin", "human", "fighter", AbilityScores.new())
	first_target.character_id = "distance-target-one"
	var second_target := Character.new()
	second_target.initialize("Second twin", "human", "fighter", AbilityScores.new())
	second_target.character_id = "distance-target-two"
	var host := SpellCastContext.new()
	host.caster = caster
	host.spell = renamed
	host.players = [
		{"character": caster, "hex_position": Vector2i.ZERO},
		{"character": first_target, "hex_position": Vector2i(2, 0)},
		{"character": second_target, "hex_position": Vector2i(4, 0)}
	]
	host.areas = CombatSpellZones.new()
	host.areas.active_spell_zones = {
		"source-one": {"spell_id": str(renamed.get("id", "")), "caster_id": caster.character_id, "center": Vector2i.ZERO},
		"source-two": {"spell_id": str(renamed.get("id", "")), "caster_id": caster.character_id, "center": Vector2i(6, 0)}
	}
	var cast := SpellResolutionContext.new()
	cast.caster = caster
	cast.target = first_target
	cast.spell = neutral
	cast.spatial_host = host
	cast.source_definition_id = str(renamed.get("id", ""))
	cast.source_instance_id = "source-one"
	var adapter := SharedStepExecutor.SpellAdapter.new(cast)
	var actor_when: Dictionary = neutral["steps"][0]["effects"][0]["when"]
	var source_when: Dictionary = renamed["steps"][0]["effects"][0]["when"]
	var exact_actor_range: Dictionary = SharedStepExecutor._read_fact("target.actor_hex_distance_feet", adapter, first_target)
	check.call(exact_actor_range.get("available", false) and int(exact_actor_range.get("value", -1)) == 10 and SharedStepExecutor.evaluate_predicate(actor_when, adapter, first_target, []) and not SharedStepExecutor.evaluate_predicate({"fact": "target.actor_hex_distance_feet", "lt": 10}, adapter, first_target, []), "Axial hex distance is expressed in feet and the authored inclusive range boundary includes exact equality")
	host.players[0]["hex_position"] = Vector2i(1, 0)
	check.call(SharedStepExecutor.evaluate_predicate(actor_when, adapter, first_target, []), "Moving the actor endpoint updates a live distance query")
	host.players[0]["hex_position"] = Vector2i.ZERO
	host.players[1]["hex_position"] = Vector2i(3, 0)
	check.call(not SharedStepExecutor.evaluate_predicate(actor_when, adapter, first_target, []), "Moving the target endpoint updates a live distance query")
	check.call(not SharedStepExecutor.evaluate_predicate(actor_when, adapter, second_target, []) and int(SharedStepExecutor._read_fact("target.actor_hex_distance_feet", adapter, second_target).get("value", -1)) == 20, "Two represented actors of the same definition resolve their own distinct live positions")
	host.players[1]["hex_position"] = Vector2i(2, 0)
	var source_at_ten: Dictionary = SharedStepExecutor._read_fact("target.source_hex_distance_feet", adapter, first_target)
	check.call(source_at_ten.get("available", false) and int(source_at_ten.get("value", -1)) == 10 and SharedStepExecutor.evaluate_predicate(source_when, adapter, first_target, []), "A represented placed source is measured from its exact instance center with inclusive range equality")
	host.players[0]["hex_position"] = Vector2i(5, 0)
	check.call(SharedStepExecutor.evaluate_predicate(source_when, adapter, first_target, []) and not SharedStepExecutor.evaluate_predicate(actor_when, adapter, first_target, []), "Moving the source bearer does not move the located source endpoint")
	host.players[0]["hex_position"] = Vector2i.ZERO
	host.players[1]["hex_position"] = Vector2i(3, 0)
	check.call(not SharedStepExecutor.evaluate_predicate(source_when, adapter, first_target, []), "Moving the bearer/target changes source-relative range while the placed source remains fixed")
	host.areas.active_spell_zones["source-one"]["center"] = Vector2i(1, 0)
	check.call(SharedStepExecutor.evaluate_predicate(source_when, adapter, first_target, []), "Moving the located source changes its live range while the bearer stays fixed")
	cast.source_instance_id = "source-two"
	check.call(not SharedStepExecutor.evaluate_predicate(source_when, adapter, first_target, []) and int(SharedStepExecutor._read_fact("target.source_hex_distance_feet", adapter, first_target).get("value", -1)) == 15, "Two located source instances sharing one definition resolve independently by exact instance identity")
	cast.source_instance_id = "source-one"
	cast.source_instance_id = ""
	check.call(not SharedStepExecutor._read_fact("target.source_hex_distance_feet", adapter, first_target).get("available", false) and not SharedStepExecutor.evaluate_predicate({"not": source_when}, adapter, first_target, []), "Definition identity alone cannot supply a location and unavailable source distance stays unavailable under not")
	cast.source_instance_id = "source-one"
	host.areas.active_spell_zones.erase("source-one")
	check.call(not SharedStepExecutor._read_fact("target.source_hex_distance_feet", adapter, first_target).get("available", false), "Removing the exact located source makes its distance unavailable")
	var stale_target := Character.new()
	stale_target.initialize("Stale first twin", "human", "fighter", AbilityScores.new())
	stale_target.character_id = first_target.character_id
	check.call(not SharedStepExecutor._read_fact("target.actor_hex_distance_feet", adapter, stale_target).get("available", false), "A stale actor projection with a reused ID cannot borrow a live participant position")
	var prior_transition: Dictionary = GameManager.transition_context.duplicate(true)
	GameManager.transition_context["local_room"] = {"party_positions": {caster.character_id: [0, 0], first_target.character_id: [1, 0]}}
	check.call(not SharedStepExecutor._read_fact("target.actor_hex_distance_feet", adapter, stale_target).get("available", false), "A stale combat actor cannot borrow the room position of a live actor with the same ID")
	host.players.erase(host.players[1])
	check.call(not SharedStepExecutor._read_fact("target.actor_hex_distance_feet", adapter, first_target).get("available", false), "Removing a combat endpoint cannot fall back to its old room position")
	host.players.clear()
	host.monsters.clear()
	cast.spatial_host = null
	var prior_characters := PartyManager.characters.duplicate()
	var prior_slots := PartyManager.party_slots.duplicate(true)
	PartyManager.characters[caster.character_id] = caster
	PartyManager.characters[first_target.character_id] = first_target
	PartyManager.party_slots = [{"occupied": true, "character_id": caster.character_id}, {"occupied": true, "character_id": first_target.character_id}]
	var room_distance: Dictionary = SharedStepExecutor._read_fact("target.actor_hex_distance_feet", adapter, first_target)
	check.call(room_distance.get("available", false) and int(room_distance.get("value", -1)) == 5, "Outside an encounter, actor distance uses the room-owned party position map")
	check.call(not SharedStepExecutor._read_fact("target.actor_hex_distance_feet", adapter, stale_target).get("available", false), "A room distance requires the current party Character, not a copied ID")
	PartyManager.characters = prior_characters
	PartyManager.party_slots = prior_slots
	GameManager.transition_context = prior_transition


static func _entity_binding_checks(check: Callable) -> void:
	var neutral: Dictionary = DataLoader.get_spell("sandbox:entity_bindings_neutral")
	var renamed: Dictionary = DataLoader.get_spell("sandbox:entity_bindings_renamed")
	check.call(not neutral.is_empty() and not renamed.is_empty() and SharedSpell.content_error(neutral).is_empty() and SharedSpell.content_error(renamed).is_empty(), "Neutral and renamed entity-binding definitions load through SharedSpell validation")
	if neutral.is_empty() or renamed.is_empty(): return
	var owner := Character.new()
	owner.initialize("Binding owner", "human", "wizard", AbilityScores.new())
	owner.character_id = "binding-owner"
	var other_owner := Character.new()
	other_owner.initialize("Other owner", "human", "wizard", AbilityScores.new())
	other_owner.character_id = "renamed-owner"
	var target := Character.new()
	target.initialize("Binding target", "human", "fighter", AbilityScores.new())
	target.character_id = "binding-target"
	var other_target := Character.new()
	other_target.initialize("Other target", "human", "fighter", AbilityScores.new())
	other_target.character_id = "renamed-target"
	owner.inventory.add_item("diamond_300gp")
	owner.inventory.add_item("diamond_300gp")
	owner.inventory.copies.sync(owner.inventory)
	var diamond_copies: Array[String] = []
	for copy_id in owner.inventory.copies.backpack:
		if str(owner.inventory.copies.records.get(copy_id, {}).get("definition_id", "")) == "diamond_300gp":
			diamond_copies.append(str(copy_id))
	var copy_one := diamond_copies[0]
	var copy_two := diamond_copies[1]
	var context := SpellResolutionContext.new()
	context.caster = owner
	context.target = target
	context.spell = neutral
	context.effect_cast = {"source_id": "source-copy-one", "spell_id": str(neutral["id"]), "caster_id": owner.character_id}
	context.spell_definition_id = str(neutral["id"])
	context.source_definition_id = str(neutral["id"])
	context.source_instance_id = "source-copy-one"
	context.source_owner_id = owner.character_id
	context.action_id = "magic"
	context.action_invocation_id = "action-invocation-one"
	context.invocation_id = "spell-invocation-one"
	context.item_definition_id = "diamond_300gp"
	context.item_instance_id = copy_one
	context.item_copy_validated = true
	var adapter := SharedStepExecutor.SpellAdapter.new(context)
	var neutral_when: Dictionary = neutral["steps"][1]["effects"][0]["when"]
	var renamed_when: Dictionary = renamed["steps"][1]["effects"][0]["when"]
	check.call(SharedStepExecutor.evaluate_predicate(neutral_when, adapter, target, []) and not SharedStepExecutor.evaluate_predicate(renamed_when, adapter, target, []), "Actor, target, spell definition and source definition resolve from their own bindings")
	check.call(not SharedStepExecutor.evaluate_predicate(neutral_when, adapter, other_target, []) and not SharedStepExecutor.evaluate_predicate(neutral_when, adapter, other_owner, []), "Owner and recipient identities cannot be substituted through the same id field")
	var source_two := SpellResolutionContext.new()
	source_two.caster = owner
	source_two.target = target
	source_two.spell = neutral
	source_two.effect_cast = {"source_id": "source-copy-two", "spell_id": str(neutral["id"]), "caster_id": owner.character_id}
	source_two.spell_definition_id = str(neutral["id"])
	source_two.source_definition_id = str(neutral["id"])
	source_two.source_instance_id = "source-copy-two"
	source_two.source_owner_id = owner.character_id
	var first_source: Dictionary = SharedStepExecutor._read_fact("source.instance_id", adapter, target)
	var second_source: Dictionary = SharedStepExecutor._read_fact("source.instance_id", SharedStepExecutor.SpellAdapter.new(source_two), target)
	check.call(first_source.get("available", false) and second_source.get("available", false) and first_source.get("value") != second_source.get("value") and SharedStepExecutor._read_fact("source.definition_id", adapter, target).get("value") == SharedStepExecutor._read_fact("source.definition_id", SharedStepExecutor.SpellAdapter.new(source_two), target).get("value"), "Two source instances of one spell definition stay distinct from the shared definition ID")
	var copy_one_fact: Dictionary = SharedStepExecutor._read_fact("item.instance_id", adapter, target)
	context.item_instance_id = copy_two
	var copy_two_fact: Dictionary = SharedStepExecutor._read_fact("item.instance_id", adapter, target)
	check.call(copy_one_fact.get("available", false) and copy_two_fact.get("available", false) and copy_one_fact.get("value") != copy_two_fact.get("value") and SharedStepExecutor._read_fact("item.definition_id", adapter, target).get("value") == "diamond_300gp", "Two owned copies retain distinct runtime IDs under one loaded item definition")
	var routed_host := SpellCastContext.new()
	routed_host.caster = owner
	routed_host.action_id = "magic"
	routed_host.component_item_id = "diamond_300gp"
	routed_host.component_instance_id = copy_one
	routed_host.component_copy_validated = true
	var routed_spell := neutral.duplicate(true)
	routed_spell["steps"][1]["effects"][0]["when"] = {"all": [
		{"fact": "action.id", "eq": "magic"},
		{"fact": "action.invocation_id", "eq": routed_host.action_invocation_id},
		{"fact": "spell.invocation_id", "eq": routed_host.invocation_id},
		{"fact": "item.instance_id", "eq": copy_one},
		{"fact": "source.instance_id", "ne": "missing-source"}
	]}
	routed_host.spell = routed_spell
	target.current_hp = 1
	var spoofed_host_result := CombatAction.resolve_spell(owner, target, routed_spell, false, {"cast_context": routed_host})
	var spoofed_host_refused_fact := target.current_hp == 1
	var routed_result := CombatAction.resolve_spell(owner, target, routed_spell, false, {}, [], 1, -1, routed_host)
	check.call(spoofed_host_refused_fact and target.current_hp == 2 and target.has_condition("blessed") and not str(routed_result.get("effect_cast", {}).get("source_id", "")).is_empty() and routed_result.get("success", false), "Caller decision metadata cannot impersonate the host; the owned host supplies invocation/item facts and the real effect source")
	context.item_copy_validated = false
	context.item_instance_id = ""
	check.call(not SharedStepExecutor.evaluate_predicate({"not": {"fact": "item.instance_id", "eq": "missing-copy"}}, adapter, target, []), "A spell-only host with no validated item copy leaves item facts unavailable under not")
	context.item_copy_validated = true
	context.item_instance_id = copy_one
	context.spell = neutral.duplicate(true)
	context.spell["steps"] = []
	var continuation_step := {"id": "bind", "type": "effect", "effects": [{"type": "heal", "value": "1", "when": {"all": [
		{"fact": "actor.id", "eq": "binding-owner"},
		{"fact": "target.id", "eq": "binding-target"},
		{"fact": "action.invocation_id", "eq": "action-invocation-one"},
		{"fact": "spell.invocation_id", "eq": "spell-invocation-one"},
		{"fact": "item.instance_id", "eq": copy_one},
		{"fact": "source.instance_id", "eq": "source-copy-one"}
	]}}]}
	target.current_hp = 1
	other_target.current_hp = 1
	var continuation := {"cast": context, "step": continuation_step, "pending_target": target, "step_index": 0, "target_index": 0}
	var resumed := SharedStepExecutor.resume_spell_steps(other_owner, other_target, {"success": true, "hit": true}, {}, continuation)
	check.call(target.current_hp == 2 and other_target.current_hp == 1 and resumed.get("success", false), "Captured action, spell, item and source identities survive resume; caller owner/target substitutions do not replace them")
	var invalid_kind := neutral.duplicate(true)
	invalid_kind["steps"][1]["effects"][0]["when"] = {"fact": "item.instance_id", "eq": 3}
	check.call(not SharedSpell.content_error(invalid_kind).is_empty(), "Identity bindings reject wrong-kind numeric comparisons before execution")


static func _relationship_query_checks(check: Callable) -> void:
	var neutral: Dictionary = DataLoader.get_spell("sandbox:relationship_neutral")
	var renamed: Dictionary = DataLoader.get_spell("sandbox:relationship_renamed")
	check.call(not neutral.is_empty() and not renamed.is_empty() and SharedSpell.content_error(neutral).is_empty() and SharedSpell.content_error(renamed).is_empty(), "Neutral and renamed relationship consumers load and validate")
	var caster := Character.new()
	caster.initialize("Relation caster", "human", "wizard", AbilityScores.new())
	caster.character_id = "relation-caster"
	var ally := Character.new()
	ally.initialize("Willing ally", "human", "fighter", AbilityScores.new())
	ally.character_id = "relation-ally"
	ally.willingness = "willing"
	ally.current_hp = 1
	var enemy := Character.new()
	enemy.initialize("Unwilling enemy", "human", "fighter", AbilityScores.new())
	enemy.character_id = "relation-enemy"
	enemy.willingness = "unwilling"
	enemy.current_hp = 1
	var players := [{"character": caster}, {"character": ally}]
	var monsters := [enemy]
	var ally_source := "spell:relation-caster:1"
	var enemy_source := "spell:relation-caster:2"
	_seed_relation_condition(ally, caster.character_id, ally_source, "charmed")
	_seed_relation_condition(enemy, caster.character_id, enemy_source, "hunters_mark")
	var neutral_gate: Dictionary = neutral["steps"][0]["effects"][0]["when"]
	var renamed_gate: Dictionary = renamed["steps"][0]["effects"][0]["when"]
	var neutral_result := CombatAction.resolve_spell(caster, ally, neutral, false, {"players": players, "monsters": monsters})
	var renamed_result := CombatAction.resolve_spell(caster, enemy, renamed, false, {"players": players, "monsters": monsters})
	check.call(neutral_result.get("success", false) and ally.current_hp == 3 and renamed_result.get("success", false) and enemy.current_hp == 6, "Loaded neutral ally/willing/charm and renamed enemy/unwilling/mark consumers qualify through shared effect settlement")
	var neutral_context := SpellResolutionContext.new()
	neutral_context.caster = caster
	neutral_context.target = ally
	neutral_context.spell = neutral
	neutral_context.decisions = {"players": players, "monsters": monsters}
	var adapter := SharedStepExecutor.SpellAdapter.new(neutral_context)
	check.call(SharedStepExecutor.evaluate_predicate(neutral_gate, adapter, ally, []) and SharedStepExecutor._read_fact("target.relationship", adapter, ally).get("value") == "ally", "Current participant control classifies an ally from the live player roster")
	var stale_ally := Character.new()
	stale_ally.character_id = ally.character_id
	check.call(not SharedStepExecutor._read_fact("target.relationship", adapter, stale_ally).get("available", false), "A stale same-ID actor cannot borrow a live participant's allegiance")
	var continuation_cast := SpellResolutionContext.new()
	continuation_cast.caster = caster
	continuation_cast.target = ally
	continuation_cast.spell = neutral
	continuation_cast.decisions = {"players": players, "monsters": monsters}
	ally.current_hp = 1
	var other_giver := Character.new()
	other_giver.initialize("Other giver", "human", "wizard", AbilityScores.new())
	other_giver.character_id = "relation-other-giver"
	var other_recipient := Character.new()
	other_recipient.initialize("Substitute target", "human", "fighter", AbilityScores.new())
	other_recipient.character_id = "relation-substitute"
	other_recipient.current_hp = 1
	var continuation := {"cast": continuation_cast, "step": neutral["steps"][0], "pending_target": ally, "step_index": 0, "target_index": 0}
	var continued := SharedStepExecutor.resume_spell_steps(other_giver, other_recipient, {"success": true, "hit": true}, {}, continuation)
	check.call(continued.get("success", false) and ally.current_hp == 3 and other_recipient.current_hp == 1, "Continuation retains captured caster, recipient and participant bindings when called with substituted entities")
	neutral_context.decisions["players"] = [{"character": caster}]
	neutral_context.decisions["monsters"] = [ally, enemy]
	check.call(SharedStepExecutor._read_fact("target.relationship", adapter, ally).get("value") == "enemy", "Changing represented control changes the live relationship query")
	ally.willingness = "unknown"
	check.call(not SharedStepExecutor._read_fact("target.willingness", adapter, ally).get("available", false) and not SharedStepExecutor.evaluate_predicate({"not": {"fact": "target.willingness", "eq": "willing"}}, adapter, ally, []), "Unknown willingness stays unavailable, including under not, and is never consent")
	var no_roster := SpellResolutionContext.new()
	no_roster.caster = caster
	no_roster.target = enemy
	no_roster.spell = neutral
	var no_roster_adapter := SharedStepExecutor.SpellAdapter.new(no_roster)
	check.call(not SharedStepExecutor._read_fact("target.relationship", no_roster_adapter, enemy).get("available", false), "Missing allegiance/control participants yield an unavailable relationship")
	var second_charm_source := "spell:relation-other-giver:1"
	_seed_relation_condition(ally, other_giver.character_id, second_charm_source, "charmed")
	var caster_context := SpellResolutionContext.new()
	caster_context.caster = caster
	caster_context.target = ally
	caster_context.spell = neutral
	var caster_adapter := SharedStepExecutor.SpellAdapter.new(caster_context)
	var second_context := SpellResolutionContext.new()
	second_context.caster = other_giver
	second_context.target = ally
	second_context.spell = neutral
	var second_adapter := SharedStepExecutor.SpellAdapter.new(second_context)
	check.call(SharedStepExecutor._read_fact("target.charmed_by_actor", caster_adapter, ally).get("value", false) and SharedStepExecutor._read_fact("target.charmed_by_actor", second_adapter, ally).get("value", false), "Two independent givers of the same Charmed effect each match their own retained source record")
	SpellEffects.remove(ally, ally_source)
	check.call(not SharedStepExecutor._read_fact("target.charmed_by_actor", caster_adapter, ally).get("value", true) and SharedStepExecutor._read_fact("target.charmed_by_actor", second_adapter, ally).get("value", false), "Removing one exact source preserves the other giver's same-kind effect")
	var persistence := ally.to_dict()
	var restored := Character.new()
	restored.from_dict(persistence)
	check.call(restored.willingness == "unknown" and Character.saved_willingness_error(persistence).is_empty() and not Character.saved_willingness_error({"willingness": "maybe"}).is_empty(), "Explicit willingness values persist and malformed values are rejected")


static func _seed_relation_condition(target: Character, giver_id: String, source_id: String, condition: String) -> void:
	var grants: Dictionary = target.condition_sources.get(condition, {})
	grants[source_id] = 10
	target.condition_sources[condition] = grants
	target.conditions[condition] = 10
	target.spell_effects[source_id] = {"source_id": source_id, "caster_id": giver_id, "conditions": [condition], "remaining_seconds": 60}


static func _result_reducer_checks(check: Callable) -> void:
	var neutral: Dictionary = DataLoader.get_spell("sandbox:result_reduce_neutral")
	var renamed: Dictionary = DataLoader.get_spell("sandbox:result_reduce_renamed")
	check.call(not neutral.is_empty() and not renamed.is_empty() and SharedSpell.content_error(neutral).is_empty() and SharedSpell.content_error(renamed).is_empty(), "Neutral and renamed explicit sum/min/max consumers load and pass shared validation")
	if neutral.is_empty() or renamed.is_empty(): return
	var caster := Character.new()
	caster.initialize("Reducer caster", "human", "wizard", AbilityScores.new())
	caster.character_id = "reducer-caster"
	caster.max_hp = 100
	caster.current_hp = 50
	var target := Character.new()
	target.initialize("Reducer target", "human", "fighter", AbilityScores.new())
	target.character_id = "reducer-target"
	target.max_hp = 100
	target.current_hp = 100
	var neutral_cast: Dictionary = CombatAction.resolve_spell(caster, target, neutral, false, {}, [], 1)
	var neutral_steps: Array = neutral_cast.get("step_results", [])
	var neutral_outcome: Dictionary = neutral_steps[2].get("target_outcomes", [{}])[0] if neutral_steps.size() > 2 else {}
	var neutral_receipt: Dictionary = neutral_outcome.get("result", {})
	var neutral_hp_loss := int(neutral_steps[0].get("target_outcomes", [{}])[0].get("damage_components", [{}])[0].get("hp_loss", -1)) + int(neutral_steps[1].get("target_outcomes", [{}])[0].get("damage_components", [{}])[0].get("hp_loss", -1))
	var neutral_values_ok := bool(neutral_cast.get("success", false)) and neutral_hp_loss == 11 and int(caster.current_hp) == 55 and int(caster.temp_hp) == 7 and int(neutral_receipt.get("healing", -1)) == 5
	caster.current_hp = 50
	caster.temp_hp = 0
	target.current_hp = 100
	var renamed_cast: Dictionary = CombatAction.resolve_spell(caster, target, renamed, false, {}, [], 1)
	var renamed_steps: Array = renamed_cast.get("step_results", [])
	var renamed_outcome: Dictionary = renamed_steps[2].get("target_outcomes", [{}])[0] if renamed_steps.size() > 2 else {}
	var renamed_receipt: Dictionary = renamed_outcome.get("result", {})
	var renamed_values_ok := bool(renamed_cast.get("success", false)) and int(caster.current_hp) == 57 and int(caster.temp_hp) == 3 and int(renamed_receipt.get("healing", -1)) == 7
	check.call(neutral_values_ok and renamed_values_ok, "Loaded ordered consumers apply distinct settled sums and max/min receipts once (neutral heal/thp=%d/%d renamed=%d/%d)" % [int(neutral_receipt.get("healing", -1)), int(caster.temp_hp if renamed_values_ok else -1), int(renamed_receipt.get("healing", -1)), int(caster.temp_hp)])
	var a := Character.new()
	a.character_id = "reducer-target-a"
	var b := Character.new()
	b.character_id = "reducer-target-b"
	var context := SpellResolutionContext.new()
	context.caster = caster
	context.target = a
	context.spell = neutral
	var adapter := SharedStepExecutor.SpellAdapter.new(context)
	var outcomes: Array = [
		{"step_id": "one", "type": "damage", "target_outcomes": [{"target": a, "damage_components": [{"type": "fire", "raw": 4, "resolved": 4, "hp_loss": 4}]}, {"target": b, "damage_components": [{"type": "fire", "raw": 8, "resolved": 8, "hp_loss": 8}]}]},
		{"step_id": "two", "type": "damage", "target_outcomes": [{"target": a, "damage_components": [{"type": "fire", "raw": 7, "resolved": 7, "hp_loss": 7}]}, {"target": b, "damage_components": [{"type": "fire", "raw": 2, "resolved": 2, "hp_loss": 2}]}]},
		{"step_id": "unselected_high", "type": "damage", "target_outcomes": [{"target": a, "damage_components": [{"type": "fire", "raw": 99, "resolved": 99, "hp_loss": 99}]}]}
	]
	var base := {"steps": ["one", "two"], "targets": "all", "component": "fire", "measure": "hp_loss", "empty": "zero"}
	var sum_selector := base.duplicate(true)
	sum_selector["reducer"] = "sum"
	var min_selector := base.duplicate(true)
	min_selector["reducer"] = "min"
	min_selector["empty"] = "unavailable"
	var max_selector := base.duplicate(true)
	max_selector["reducer"] = "max"
	max_selector["empty"] = "unavailable"
	var sum_value: Dictionary = SharedStepExecutor.evaluate_formula({"result_reduce": sum_selector}, adapter, a, outcomes)
	var min_value: Dictionary = SharedStepExecutor.evaluate_formula({"result_reduce": min_selector}, adapter, a, outcomes)
	var max_value: Dictionary = SharedStepExecutor.evaluate_formula({"result_reduce": max_selector}, adapter, a, outcomes)
	var same_selector := sum_selector.duplicate(true)
	same_selector["targets"] = "same"
	var same_value: Dictionary = SharedStepExecutor.evaluate_formula({"result_reduce": same_selector}, adapter, a, outcomes)
	var cast_target_selector := sum_selector.duplicate(true)
	cast_target_selector["targets"] = "cast_target"
	var cast_target_value: Dictionary = SharedStepExecutor.evaluate_formula({"result_reduce": cast_target_selector}, adapter, a, outcomes)
	var empty_outcomes: Array = [{"step_id": "one", "type": "damage", "target_outcomes": [{"target": a, "skipped": true}]}, {"step_id": "two", "type": "damage", "target_outcomes": []}]
	var empty_sum: Dictionary = SharedStepExecutor.evaluate_formula({"result_reduce": sum_selector}, adapter, a, empty_outcomes)
	var empty_min: Dictionary = SharedStepExecutor.evaluate_formula({"result_reduce": min_selector}, adapter, a, empty_outcomes)
	var missing_input: Dictionary = SharedStepExecutor.evaluate_formula({"result_reduce": max_selector}, adapter, a, [outcomes[0]])
	var duplicate_outcomes := outcomes.duplicate(true)
	duplicate_outcomes[0]["target_outcomes"].append(duplicate_outcomes[0]["target_outcomes"][0].duplicate(true))
	var duplicate_rejected: Dictionary = SharedStepExecutor.evaluate_formula({"result_reduce": sum_selector}, adapter, a, duplicate_outcomes)
	var zero_outcomes: Array = [{"step_id": "one", "type": "damage", "target_outcomes": [{"target": a, "damage_components": [{"type": "fire", "raw": 0, "resolved": 0, "hp_loss": 0}]}]}, {"step_id": "two", "type": "damage", "target_outcomes": [{"target": a, "damage_components": [{"type": "fire", "raw": 0, "resolved": 0, "hp_loss": 0}]}]}]
	var zero_min: Dictionary = SharedStepExecutor.evaluate_formula({"result_reduce": min_selector}, adapter, a, zero_outcomes)
	check.call(int(sum_value.get("value", -1)) == 21 and int(min_value.get("value", -1)) == 2 and int(max_value.get("value", -1)) == 8 and int(same_value.get("value", -1)) == 11 and int(cast_target_value.get("value", -1)) == 11 and int(empty_sum.get("value", -1)) == 0 and not empty_min.get("success", true) and int(zero_min.get("value", -1)) == 0 and not missing_input.get("success", true) and not duplicate_rejected.get("success", true), "Reducers select each exact target/step once, exclude an unrelated high value, preserve same/cast-target scope, and distinguish known zero from empty/missing/duplicate inputs")
	var repeated := neutral.duplicate(true)
	repeated["steps"][0]["type"] = "save"
	repeated["steps"][0]["save"] = "DEX"
	repeated["steps"][0]["damage_components"] = [{"damage_type": "fire", "damage": "4"}, {"damage_type": "fire", "damage": "2"}]
	repeated["steps"][0].erase("damage")
	repeated["steps"][0].erase("damage_type")
	check.call(not SharedSpell.content_error(repeated).is_empty(), "Repeated damage component without an explicit component_id is rejected during content preflight")
	var empty_gate := {"result_reduce": sum_selector, "eq": 0}
	check.call(SharedStepExecutor.evaluate_predicate(empty_gate, adapter, a, empty_outcomes), "Predicate consumers can explicitly observe an empty sum as zero")


static func _batch_e_boundary_checks(check: Callable) -> void:
	var caster := Character.new()
	caster.initialize("Batch E caster", "human", "wizard", AbilityScores.new())
	caster.character_id = "batch-e-caster"
	var target := Character.new()
	target.initialize("Batch E target", "human", "fighter", AbilityScores.new())
	target.character_id = "batch-e-target"
	target.max_hp = 100
	target.current_hp = 100
	var instant: Dictionary = DataLoader.get_spell("sandbox:result_reduce_neutral")
	CombatAction.resolve_spell(caster, target, instant, false, {}, [], 1)
	var first_source := str(target.recent_damage_history.back().get("source_instance_id", ""))
	CombatAction.resolve_spell(caster, target, instant, false, {}, [], 1)
	var second_source := str(target.recent_damage_history.back().get("source_instance_id", ""))
	check.call(first_source != second_source and target.recent_damage_history.size() == 2, "Batch E: repeated instant casts without a combat host retain independent causal source instances")
	target.features.append({"id": "batch_e_ward", "effects": [{"type": "damage_ward_pool", "pool_id": "batch_e_ward", "trigger_schools": ["Abjuration"], "max_hp_level_multiplier": 0, "max_hp_flat_bonus": 3}]})
	WardRules.on_slot_spell_cast(target, {"level": 1, "school": "Abjuration"}, 1)
	target.temp_hp = 2
	var ward_cast: Dictionary = CombatAction.resolve_spell(caster, target, instant, false, {}, [], 1)
	var ward_component: Dictionary = ward_cast.get("step_results", [])[0]["target_outcomes"][0]["damage_components"][0]
	var ward_history: Dictionary = target.recent_damage_history.back()
	check.call(int(ward_component.get("absorbed", -1)) == 1 and int(ward_component.get("prevented", -1)) == 3 and int(ward_history.get("absorbed", -1)) == 5, "Batch E: component absorption retains its accepted Temporary HP measure while history separately includes ward absorption")
	var context := SpellResolutionContext.new()
	context.caster = caster
	context.target = target
	var adapter := SharedStepExecutor.SpellAdapter.new(context)
	var selector := {"reducer": "sum", "steps": ["miss"], "targets": "all", "component": "fire", "measure": "hp_loss", "empty": "zero"}
	var missed: Array = [{"step_id": "miss", "type": "attack", "target_outcomes": [{"target": target, "hit": false, "damage": 0}]}]
	var miss_sum := SharedStepExecutor.evaluate_formula({"result_reduce": selector}, adapter, target, missed)
	check.call(bool(miss_sum.get("success", false)) and int(miss_sum.get("value", -1)) == 0, "Batch E: a settled miss is a known empty damage selection, not missing input")
	var miss_spell := instant.duplicate(true)
	miss_spell["steps"][0]["type"] = "attack"
	miss_spell["steps"][0]["attack_type"] = "ranged_spell"
	caster.current_hp = 50
	caster.max_hp = 100
	var miss_target := {"id": "batch-e-miss", "armor_class": 100, "current_hp": 100, "max_hp": 100, "is_alive": true, "conditions": {}}
	FighterChecks._seed_die(20, 1)
	var actual_miss := CombatAction.resolve_spell(caster, miss_target, miss_spell, false, {}, [], 1)
	check.call(bool(actual_miss.get("success", false)) and caster.current_hp == 53 and miss_target.current_hp == 93, "Batch E: loaded ordered reducer continues past a real missed attack and consumes only the later settled damage")


static func _shared_result_sum_checks(check: Callable) -> void:
	var spell: Dictionary = DataLoader.get_spell("sandbox:area_hp_tithe")
	var renamed: Dictionary = DataLoader.get_spell("sandbox:area_hp_tithe_renamed")
	check.call(not spell.is_empty() and not renamed.is_empty() and SharedSpell.content_error(spell).is_empty() and SharedSpell.content_error(renamed).is_empty(), "Neutral and renamed earlier-step damage-sum fixtures load and validate")
	var caster := Character.new()
	caster.initialize("Area Tithe Caster", "human", "wizard", AbilityScores.new())
	caster.character_id = "area_tithe_caster"
	caster.max_hp = 100
	caster.current_hp = 10
	var short_target := {"id": "tithe-short", "definition_id": "fixture:training_dummy", "name": "Short target", "current_hp": 3, "max_hp": 100, "is_alive": true, "temp_hp": 0, "conditions": {}}
	var resistant_target := {"id": "tithe-resistant", "definition_id": "fixture:training_dummy", "name": "Resistant target", "current_hp": 50, "max_hp": 100, "is_alive": true, "temp_hp": 4, "damage_resistances": ["fire"], "conditions": {}}
	var immune_target := {"id": "tithe-immune", "name": "Immune target", "current_hp": 100, "max_hp": 100, "is_alive": true, "temp_hp": 0, "damage_immunities": ["fire"], "conditions": {}}
	var neutral_decisions := {"area_targets": [short_target, resistant_target, immune_target]}
	var neutral_result := CombatAction.resolve_spell(caster, short_target, spell, false, neutral_decisions)
	var neutral_outcomes: Array = neutral_result.get("step_results", [])[0].get("target_outcomes", []) if neutral_result.get("step_results", []).size() > 0 else []
	var neutral_context := SpellResolutionContext.new()
	neutral_context.caster = caster
	neutral_context.target = short_target
	neutral_context.spell = spell
	neutral_context.decisions = neutral_decisions
	var neutral_adapter := SharedStepExecutor.SpellAdapter.new(neutral_context)
	var hp_loss_sum := SharedStepExecutor.evaluate_formula({"result_sum": {"step": "blast", "component": "fire", "measure": "hp_loss"}}, neutral_adapter, caster, neutral_result.get("step_results", []))
	var resolved_sum := SharedStepExecutor.evaluate_formula({"result_sum": {"step": "blast", "component": "fire", "measure": "resolved"}}, neutral_adapter, caster, neutral_result.get("step_results", []))
	var raw_sum := SharedStepExecutor.evaluate_formula({"result_sum": {"step": "blast", "component": "fire", "measure": "raw"}}, neutral_adapter, caster, neutral_result.get("step_results", []))
	var single_target_value := SharedStepExecutor.evaluate_formula({"result": {"step": "blast", "target": "cast_target", "component": "fire", "measure": "hp_loss"}}, neutral_adapter, caster, neutral_result.get("step_results", []))
	var neutral_heal: Dictionary = neutral_result.get("step_results", [])[1].get("target_outcomes", [])[0].get("result", {}) if neutral_result.get("step_results", []).size() > 1 else {}
	check.call(bool(neutral_result.get("success", false)) and neutral_outcomes.size() == 3 and short_target.current_hp == 0 and resistant_target.current_hp == 48 and resistant_target.temp_hp == 0 and immune_target.current_hp == 100, "Neutral ordered area damage settles once per target across overkill, resistance, Temporary HP, and immunity")
	check.call(hp_loss_sum.get("success", false) and int(hp_loss_sum.get("value", -1)) == 5 and resolved_sum.get("success", false) and int(resolved_sum.get("value", -1)) == 18 and raw_sum.get("success", false) and int(raw_sum.get("value", -1)) == 36, "Aggregate selector separately sums actual HP loss, resolved damage, and raw damage")
	check.call(int(single_target_value.get("value", -1)) == 3 and caster.current_hp == 12 and int(neutral_heal.get("healing", -1)) == 2, "Existing single-target selectors remain intact and area heal occurs once using floor(total HP loss / 2)")

	caster.current_hp = 10
	var renamed_short := {"id": "tithe-renamed-short", "name": "Renamed short", "current_hp": 4, "max_hp": 100, "is_alive": true, "temp_hp": 0, "conditions": {}}
	var renamed_resistant := {"id": "tithe-renamed-resistant", "name": "Renamed resistant", "current_hp": 20, "max_hp": 100, "is_alive": true, "temp_hp": 2, "damage_resistances": ["cold"], "conditions": {}}
	var renamed_immune := {"id": "tithe-renamed-immune", "name": "Renamed immune", "current_hp": 100, "max_hp": 100, "is_alive": true, "temp_hp": 0, "damage_immunities": ["cold"], "conditions": {}}
	var renamed_decisions := {"area_targets": [renamed_short, renamed_resistant, renamed_immune]}
	var renamed_result := CombatAction.resolve_spell(caster, renamed_short, renamed, false, renamed_decisions)
	var renamed_sum := SharedStepExecutor.evaluate_formula({"result_sum": {"step": "flare", "component": "cold", "measure": "hp_loss"}}, neutral_adapter, caster, renamed_result.get("step_results", []))
	var renamed_heal: Dictionary = renamed_result.get("step_results", [])[1].get("target_outcomes", [])[0].get("result", {}) if renamed_result.get("step_results", []).size() > 1 else {}
	check.call(bool(renamed_result.get("success", false)) and renamed_sum.get("success", false) and int(renamed_sum.get("value", -1)) == 7 and caster.current_hp == 13 and int(renamed_heal.get("healing", -1)) == 3, "Renamed Cold/10 fixture uses its own step, component and value through the same aggregate path")

	var empty_sum := SharedStepExecutor.evaluate_formula({"result_sum": {"step": "blast", "component": "fire", "measure": "hp_loss"}}, neutral_adapter, caster, [{"step_id": "blast", "type": "damage", "target_outcomes": []}])
	var skipped_sum := SharedStepExecutor.evaluate_formula({"result_sum": {"step": "blast", "component": "fire", "measure": "hp_loss"}}, neutral_adapter, caster, [{"step_id": "blast", "type": "damage", "target_outcomes": [{"target": short_target, "skipped": true}]}])
	var missing_sum := SharedStepExecutor.evaluate_formula({"result_sum": {"step": "blast", "component": "fire", "measure": "hp_loss"}}, neutral_adapter, caster, [])
	var malformed_sum := SharedStepExecutor.evaluate_formula({"result_sum": {"step": "blast", "component": "fire", "measure": "hp_loss"}}, neutral_adapter, caster, [{"step_id": "blast", "type": "damage", "target_outcomes": ["bad"]}])
	var duplicate_sum := SharedStepExecutor.evaluate_formula({"result_sum": {"step": "blast", "component": "fire", "measure": "raw"}}, neutral_adapter, caster, [{"step_id": "blast", "type": "damage", "target_outcomes": [{"target": short_target, "damage": 12, "damage_components": [{"type": "fire", "raw": 12}]}, {"target": short_target, "damage": 12, "damage_components": [{"type": "fire", "raw": 12}]}]}])
	var sum_predicate := SharedStepExecutor.evaluate_predicate({"result_sum": {"step": "blast", "component": "fire", "measure": "hp_loss"}, "gt": 0}, neutral_adapter, caster, [{"step_id": "blast", "target_outcomes": []}])
	check.call(empty_sum.get("success", false) and int(empty_sum.get("value", -1)) == 0 and skipped_sum.get("success", false) and int(skipped_sum.get("value", -1)) == 0 and not sum_predicate and duplicate_sum.get("success", false) and int(duplicate_sum.get("value", -1)) == 12, "Present empty/skipped outcomes sum to zero, predicates gate effects, and repeated target records count once")
	check.call(not missing_sum.get("success", true) and not malformed_sum.get("success", true), "Absent and malformed prior outcome data fails instead of fabricating zero")

	var invalid_future := spell.duplicate(true)
	invalid_future["steps"][1]["effects"][0]["value"]["left"]["result_sum"]["step"] = "after_heal"
	invalid_future["steps"].append({"id": "after_heal", "type": "effect", "target": "self", "effects": [{"type": "heal", "value": 1}]})
	var invalid_current := spell.duplicate(true)
	invalid_current["steps"][1]["effects"][0]["value"]["left"]["result_sum"]["step"] = "tithe_heal"
	var invalid_component := spell.duplicate(true)
	invalid_component["steps"][1]["effects"][0]["value"]["left"]["result_sum"]["component"] = "cold"
	var invalid_predicate := spell.duplicate(true)
	invalid_predicate["steps"][1]["when"]["result_sum"]["measure"] = "overkill"
	check.call(not SharedSpell.content_error(invalid_future).is_empty() and not SharedSpell.content_error(invalid_current).is_empty() and not SharedSpell.content_error(invalid_component).is_empty() and not SharedSpell.content_error(invalid_predicate).is_empty(), "Future/current-step references, wrong damage components and unsupported measures refuse content before costs")
	var preflight_caster := Character.new()
	preflight_caster.initialize("Aggregate Preflight", "human", "wizard", AbilityScores.new())
	preflight_caster.spell_slots["1"] = 2
	for invalid_spell in [invalid_future, invalid_current, invalid_component]:
		var refused_cast := CombatAction.resolve_spell(preflight_caster, short_target, invalid_spell, true, {"area_targets": [short_target]}, [], 1)
		check.call(not refused_cast.get("success", true) and int(preflight_caster.spell_slots.get("1", -1)) == 2, "Invalid aggregate reference refuses the production cast before spell-slot payment")

	# Resume a real loaded aggregate spell through the established per-target save-choice continuation.
	# Settling each target appends one outcome; only the completed damage step may run the caster heal.
	var continuation_caster := Character.new()
	continuation_caster.initialize("Aggregate Continuation", "human", "wizard", AbilityScores.new())
	continuation_caster.character_id = "aggregate_continuation_caster"
	while continuation_caster.level < 3:
		continuation_caster.level_up()
	ClassProgression.choose_subclass(continuation_caster, "diviner")
	continuation_caster.current_hp = 10
	continuation_caster.max_hp = 100
	continuation_caster.spell_slots["1"] = 2
	continuation_caster.roll_tokens["diviner_portent"] = [{"token_id": "aggregate:20", "value": 20, "feature_id": "diviner_portent", "pool_id": "diviner_portent", "die_sides": 20}]
	var continuation_short := {"id": "aggregate-short", "definition_id": "fixture:training_dummy", "name": "Aggregate short", "current_hp": 3, "max_hp": 100, "is_alive": true, "temp_hp": 0, "ability_scores": {"DEX": -100}, "conditions": {}}
	var continuation_resistant := {"id": "aggregate-resistant", "definition_id": "fixture:training_dummy", "name": "Aggregate resistant", "current_hp": 50, "max_hp": 100, "is_alive": true, "temp_hp": 2, "damage_resistances": ["fire"], "ability_scores": {"DEX": -100}, "conditions": {}}
	var continuation_immune := {"id": "aggregate-immune", "name": "Aggregate immune", "current_hp": 100, "max_hp": 100, "is_alive": true, "temp_hp": 0, "damage_immunities": ["fire"], "ability_scores": {"DEX": -100}, "conditions": {}}
	var continuation_spell := spell.duplicate(true)
	continuation_spell["steps"][0]["type"] = "save"
	continuation_spell["steps"][0]["save"] = "DEX"
	var continuation_host := SpellCastContext.new()
	continuation_host.caster = continuation_caster
	continuation_host.collect_roll_token_decision = func(_roller, _kind, _label, _seed = {}): return {}
	var continuation_decisions := {"cast_context": continuation_host, "target_visible": true, "area_targets": [continuation_short, continuation_resistant, continuation_immune]}
	FighterChecks._seed_die(20, 10)
	var continuation_result := CombatAction.resolve_spell(continuation_caster, continuation_short, continuation_spell, true, continuation_decisions, [], 1, 6)
	var slot_after_cast := int(continuation_caster.spell_slots.get("1", -1))
	var roll_resumes := 0
	while continuation_result.has("roll_choice_request") and roll_resumes < 4:
		var roll_record := SpellDamageRolls.roll_choice_record(continuation_caster, continuation_result)
		var roll_target = roll_record.get("roller", null)
		if roll_target == null:
			break
		FighterChecks._seed_die(20, 10 + roll_resumes)
		continuation_result = SpellDamageRolls.settle_roll_choice(continuation_caster, roll_target, continuation_result, {})
		roll_resumes += 1
	var continuation_steps: Array = continuation_result.get("step_results", [])
	var continuation_outcomes: Array = continuation_steps[0].get("target_outcomes", []) if continuation_steps.size() > 0 else []
	var continuation_sum := SharedStepExecutor.evaluate_formula({"result_sum": {"step": "blast", "component": "fire", "measure": "hp_loss"}}, neutral_adapter, continuation_caster, continuation_steps)
	var resumed_exact_result := SharedStepExecutor.evaluate_formula({"result": {"step": "blast", "target": "same", "component": "fire", "measure": "hp_loss"}}, neutral_adapter, continuation_short, continuation_steps)
	var resumed_hp_before_mutation := int(continuation_short["current_hp"])
	continuation_short["current_hp"] = 77
	var resumed_after_live_hp_change := SharedStepExecutor.evaluate_formula({"result": {"step": "blast", "target": "same", "component": "fire", "measure": "hp_loss"}}, neutral_adapter, continuation_short, continuation_steps)
	continuation_short["current_hp"] = resumed_hp_before_mutation
	var continuation_heal: Dictionary = continuation_steps[1].get("target_outcomes", [])[0].get("result", {}) if continuation_steps.size() > 1 and continuation_steps[1].get("target_outcomes", []).size() > 0 else {}
	var continuation_hp := [int(continuation_short["current_hp"]), int(continuation_resistant["current_hp"]), int(continuation_immune["current_hp"])]
	var continuation_caster_hp := continuation_caster.current_hp
	var continuation_slot_count := int(continuation_caster.spell_slots.get("1", -1))
	var replayed_continuation := SpellDamageRolls.settle_roll_choice(continuation_caster, continuation_short, continuation_result, {})
	check.call(roll_resumes == 3 and continuation_result.get("success", false) and continuation_outcomes.size() == 3 and int(slot_after_cast) == 1 and continuation_slot_count == 1, "Resumed loaded aggregate cast settles all distinct same-definition targets and pays its spell slot once")
	check.call(continuation_sum.get("success", false) and continuation_sum.get("value", -1) > 0 and int(continuation_heal.get("healing", -1)) == floor(float(continuation_sum.get("value", 0)) / 2.0) and continuation_caster.current_hp == 10 + int(continuation_heal.get("healing", 0)), "Aggregate predicate runs after all resumed outcomes and heals the caster once from actual HP loss")
	check.call(roll_resumes == 3 and resumed_exact_result.get("success", false) and resumed_exact_result.get("value", -1) == 3 and resumed_after_live_hp_change.get("value", -1) == 3, "Exact component HP-loss receipt survives a later-target pause/resume and subsequent target HP change")
	check.call(continuation_short.current_hp == 0, "Resumed area damage preserves overkill against the low-HP target")
	check.call(continuation_resistant.current_hp < 50 and continuation_resistant.temp_hp == 0, "Resumed area damage applies resistance after absorbing the resistant target's Temporary HP (HP %s, temp %s, outcome %s)" % [str(continuation_resistant.current_hp), str(continuation_resistant.temp_hp), str(continuation_outcomes[1] if continuation_outcomes.size() > 1 else {})])
	check.call(continuation_immune.current_hp == 100, "Resumed area damage preserves the immune target's HP")
	check.call(bool(replayed_continuation.get("refused", false)) and continuation_caster.current_hp == continuation_caster_hp and continuation_caster.spell_slots.get("1", -1) == continuation_slot_count and continuation_short.current_hp == continuation_hp[0] and continuation_resistant.current_hp == continuation_hp[1] and continuation_immune.current_hp == continuation_hp[2], "Replaying the completed continuation cannot repeat damage, aggregate healing, or cast cost")


static func _shared_prior_measure_checks(check: Callable) -> void:
	var spell: Dictionary = DataLoader.get_spell("sandbox:receipt_probe")
	var renamed: Dictionary = DataLoader.get_spell("sandbox:receipt_probe_renamed")
	check.call(not spell.is_empty() and not renamed.is_empty() and SharedSpell.content_error(spell).is_empty() and SharedSpell.content_error(renamed).is_empty(), "Neutral and renamed measure consumers load and validate through DataLoader")
	var caster := Character.new()
	caster.initialize("Receipt Caster", "human", "wizard", AbilityScores.new())
	caster.character_id = "receipt-caster"
	caster.spell_slots["1"] = 2
	var target_a := {"id": "receipt-target-a", "definition_id": "fixture:shared_dummy", "name": "Resistant with Temporary HP", "current_hp": 9, "max_hp": 30, "is_alive": true, "temp_hp": 4, "damage_resistances": ["fire"], "damage_immunities": ["force"], "ability_scores": {"DEX": -100}, "conditions": {}}
	var target_b := {"id": "receipt-target-b", "definition_id": "fixture:shared_dummy", "name": "Unresistant twin", "current_hp": 100, "max_hp": 150, "is_alive": true, "temp_hp": 0, "damage_immunities": ["force"], "ability_scores": {"DEX": -100}, "conditions": {}}
	var target_immune := {"id": "receipt-target-immune", "definition_id": "fixture:shared_dummy", "name": "Immune twin", "current_hp": 100, "max_hp": 100, "is_alive": true, "temp_hp": 0, "damage_immunities": ["force", "fire"], "ability_scores": {"DEX": -100}, "conditions": {}}
	FighterChecks._seed_die(20, 1)
	var cast_result := CombatAction.resolve_spell(caster, target_a, spell, false, {"area_targets": [target_a, target_b, target_immune]})
	var steps: Array = cast_result.get("step_results", [])
	var damage_outcomes: Array = []
	for step in steps:
		if str(step.get("step_id", "")) == "impact": damage_outcomes = step.get("target_outcomes", [])
	var healed_outcomes: Array = []
	for step in steps:
		if str(step.get("step_id", "")) == "mend":
			healed_outcomes = step.get("target_outcomes", [])
	var adapter_cast := SpellResolutionContext.new()
	adapter_cast.caster = caster
	adapter_cast.target = target_a
	adapter_cast.spell = spell
	adapter_cast.effect_cast = {"caster_id": caster.character_id}
	var adapter := SharedStepExecutor.SpellAdapter.new(adapter_cast)
	var select := func(target, component_id: String, measure: String, component_type: String = "fire") -> Dictionary:
		return SharedStepExecutor.evaluate_formula({"result": {"step": "impact", "target": "same", "component": component_type, "component_id": component_id, "measure": measure}}, adapter, target, steps)
	var raw_a: Dictionary = select.call(target_a, "fire_a", "raw")
	var resolved_a: Dictionary = select.call(target_a, "fire_a", "resolved")
	var prevented_a: Dictionary = select.call(target_a, "fire_a", "prevented")
	var absorbed_a: Dictionary = select.call(target_a, "fire_a", "absorbed")
	var hp_loss_a: Dictionary = select.call(target_a, "fire_a", "hp_loss")
	var repeated_type_a: Dictionary = select.call(target_a, "fire_b", "raw")
	var repeated_type_hp_loss: Dictionary = select.call(target_a, "fire_b", "hp_loss")
	var target_b_raw: Dictionary = select.call(target_b, "fire_a", "raw")
	var target_b_hp_loss: Dictionary = select.call(target_b, "fire_a", "hp_loss")
	var immune_prevented: Dictionary = select.call(target_immune, "fire_a", "prevented")
	var type_only_ambiguous := SharedStepExecutor.evaluate_formula({"result": {"step": "impact", "target": "same", "component": "fire", "measure": "raw"}}, adapter, target_a, steps)
	check.call(cast_result.get("success", false) and damage_outcomes.size() == 3 and raw_a.get("success", false) and raw_a.get("value", -1) == 6 and resolved_a.get("value", -1) == 3 and prevented_a.get("value", -1) == 3 and absorbed_a.get("value", -1) == 3 and hp_loss_a.get("value", -1) == 0 and repeated_type_a.get("value", -1) == 4 and repeated_type_hp_loss.get("value", -1) == 1, "Exact component receipts separate raw, resisted prevention, Temporary HP absorption and actual HP loss")
	check.call(target_b_raw.get("value", -1) == 6 and target_b_hp_loss.get("value", -1) == 6 and not type_only_ambiguous.get("success", true) and str(type_only_ambiguous.get("error", "")).contains("Ambiguous"), "Runtime target identity separates same-definition actors and ambiguous same-type selection refuses")
	var heal_selector := {"result": {"step": "mend", "target": "same", "measure": "healed"}}
	var healed_a := SharedStepExecutor.evaluate_formula(heal_selector, adapter, target_a, steps)
	var healed_b := SharedStepExecutor.evaluate_formula(heal_selector, adapter, target_b, steps)
	var actual_healing_a: int = int(healed_outcomes[0].get("result", {}).get("healing", -1)) if healed_outcomes.size() > 0 else -1
	check.call(healed_a.get("success", false) and healed_a.get("value", -1) == 5 and healed_b.get("success", false) and healed_b.get("value", -1) == 10 and actual_healing_a == 5 and target_a.get("temp_hp", -1) == 5 and target_b.get("temp_hp", -1) == 10, "Capped actual healing is read from its effect receipt and the later consumer observes that amount")
	var hp_before_mutation := int(target_a.get("current_hp", -1))
	target_a["current_hp"] = 0
	var retained_after_hp_change: Dictionary = select.call(target_a, "fire_b", "hp_loss")
	target_a["current_hp"] = hp_before_mutation
	check.call(retained_after_hp_change.get("success", false) and retained_after_hp_change.get("value", -1) == 1, "Settled damage receipt survives later live HP changes")
	var invalid_ambiguous := spell.duplicate(true)
	var component_consumer_index := -1
	for index in invalid_ambiguous["steps"].size():
		if str(invalid_ambiguous["steps"][index].get("id", "")) == "echo_absorbed": component_consumer_index = index
	invalid_ambiguous["steps"][component_consumer_index]["effects"][0]["value"] = {"result": {"step": "impact", "target": "same", "component": "fire", "measure": "raw"}}
	var runtime_ambiguous: Dictionary = SharedStepExecutor.evaluate_formula(invalid_ambiguous["steps"][component_consumer_index]["effects"][0]["value"], adapter, target_a, steps)
	var invalid_component := spell.duplicate(true)
	invalid_component["steps"][component_consumer_index]["effects"][0]["value"] = {"result": {"step": "impact", "target": "same", "component": "fire", "component_id": "missing", "measure": "raw"}}
	var invalid_healed_component := spell.duplicate(true)
	var afterglow_index := -1
	for index in invalid_healed_component["steps"].size():
		if str(invalid_healed_component["steps"][index].get("id", "")) == "afterglow": afterglow_index = index
	invalid_healed_component["steps"][afterglow_index]["effects"][0]["value"] = {"result": {"step": "mend", "target": "same", "component": "fire", "measure": "healed"}}
	check.call(SharedSpell.content_error(invalid_ambiguous).is_empty() and not runtime_ambiguous.get("success", true) and str(runtime_ambiguous.get("error", "")).contains("Ambiguous") and not SharedSpell.content_error(invalid_component).is_empty() and not SharedSpell.content_error(invalid_healed_component).is_empty(), "Ambiguous types refuse at runtime instead of taking first; missing identities and component-bound healing selectors refuse")
	var missing_heal := SharedStepExecutor.evaluate_formula(heal_selector, adapter, target_a, [{"step_id": "mend", "type": "effect", "target_outcomes": [{"target": target_a, "result": {}}]}])
	var real_zero: Dictionary = select.call(target_immune, "fire_a", "hp_loss")
	check.call(not missing_heal.get("success", true) and real_zero.get("success", false) and real_zero.get("value", -1) == 0 and immune_prevented.get("success", false) and immune_prevented.get("value", -1) == 6, "Missing healing stays unavailable while immunity records prevented damage and a real zero HP-loss receipt")
	var renamed_caster := Character.new()
	renamed_caster.initialize("Renamed Receipt Caster", "human", "wizard", AbilityScores.new())
	var renamed_target := {"id": "renamed-receipt-target", "current_hp": 20, "max_hp": 20, "is_alive": true, "temp_hp": 0, "damage_resistances": ["cold"], "ability_scores": {"DEX": -100}, "conditions": {}}
	FighterChecks._seed_die(20, 1)
	var renamed_result := CombatAction.resolve_spell(renamed_caster, renamed_target, renamed, false, {"area_targets": [renamed_target]})
	var renamed_steps: Array = renamed_result.get("step_results", [])
	var renamed_context := SpellResolutionContext.new()
	renamed_context.caster = renamed_caster
	renamed_context.target = renamed_target
	renamed_context.spell = renamed
	var renamed_adapter := SharedStepExecutor.SpellAdapter.new(renamed_context)
	var renamed_prevented := SharedStepExecutor.evaluate_formula({"result": {"step": "flare", "target": "same", "component": "cold", "component_id": "cold_a", "measure": "prevented"}}, renamed_adapter, renamed_target, renamed_steps)
	check.call(renamed_result.get("success", false) and renamed_prevented.get("success", false) and renamed_prevented.get("value", -1) == 2, "Renamed data selects its own typed component and measure without ID-specific behavior")


static func _shared_margin_hp_gate_checks(check: Callable) -> void:
	var margin_spell: Dictionary = DataLoader.get_spell("sandbox:margin_gate_neutral")
	var hp_spell: Dictionary = DataLoader.get_spell("sandbox:settlement_hp_gate_renamed")
	check.call(not margin_spell.is_empty() and not hp_spell.is_empty() and SharedSpell.content_error(margin_spell).is_empty() and SharedSpell.content_error(hp_spell).is_empty(), "Neutral margin and renamed settlement-HP gate consumers load and validate")

	var sorcerer := Character.new()
	sorcerer.initialize("Margin Gate Sorcerer", "human", "sorcerer", AbilityScores.new())
	sorcerer.character_id = "margin-gate-sorcerer"
	sorcerer.sorcerer_metamagic_choices.append("empowered_spell")
	sorcerer.features.append({"id": "sorcerer_metamagic"})
	sorcerer.feature_uses["sorcery_points"] = 3
	sorcerer.spell_slots["1"] = 2
	var save_target := {"id": "margin-gate-target", "name": "Margin Gate Target", "current_hp": 100, "max_hp": 100, "temp_hp": 0, "is_alive": true, "ability_scores": {"CON": -100}, "conditions": {}}
	FighterChecks._seed_die(20, 4)
	var pending := CombatAction.resolve_spell(sorcerer, save_target, margin_spell, true, {"metamagic:empowered": true, "defer_empowered": true}, [], 1, 5)
	var pending_margin := int(pending.get("numeric_margin", 999))
	check.call(pending.has("damage_request") and pending.get("suspended_step", -1) == 0 and pending_margin <= -5 and not bool(pending.get("saved", true)) and int(save_target["temp_hp"]) == 0 and int(sorcerer.spell_slots.get("1", -1)) == 1, "The failed-save margin is captured while damage and its aftermath remain suspended for the existing Empowered choice")
	var settled := CombatAction.finish_pending_spell_damage(sorcerer, save_target, pending, {"metamagic:empowered": true, "metamagic:empowered_dice": [0]})
	var settled_steps: Array = settled.get("step_results", [])
	var save_outcome: Dictionary = settled_steps[0].get("target_outcomes", [{}])[0] if settled_steps.size() > 0 else {}
	var aftermath_outcomes: Array = settled_steps[1].get("target_outcomes", []) if settled_steps.size() > 1 else []
	var settled_margin := SharedStepExecutor.evaluate_formula({"result": {"step": "save", "target": "same", "measure": "margin"}}, SharedStepExecutor.SpellAdapter.new(_margin_adapter_context(sorcerer, save_target, margin_spell)), save_target, settled_steps)
	var hp_after_empowered := int(save_outcome.get("hp_after", -1))
	var hp_at_live_mutation := int(save_target["current_hp"])
	save_target["current_hp"] = 70
	var margin_after_live_change := SharedStepExecutor.evaluate_formula({"result": {"step": "save", "target": "same", "measure": "margin"}}, SharedStepExecutor.SpellAdapter.new(_margin_adapter_context(sorcerer, save_target, margin_spell)), save_target, settled_steps)
	save_target["current_hp"] = hp_at_live_mutation
	var saved_sp := int(sorcerer.feature_uses.get("sorcery_points", -1))
	var saved_slot := int(sorcerer.spell_slots.get("1", -1))
	var saved_hp := int(save_target["current_hp"])
	var replay := CombatAction.finish_pending_spell_damage(sorcerer, save_target, pending, {"metamagic:empowered": true, "metamagic:empowered_dice": [0]})
	check.call(bool(settled.get("success", false)) and int(save_outcome.get("result", {}).get("numeric_margin", 999)) == pending_margin and settled_margin.get("value", 999) == pending_margin and margin_after_live_change.get("value", 999) == pending_margin, "The named save margin survives settlement and later HP changes without being recomputed from live state")
	check.call(aftermath_outcomes.size() == 1 and int(save_target["temp_hp"]) == 2 and hp_after_empowered >= 0 and saved_sp == 2 and saved_slot == 1 and int(save_target["current_hp"]) == saved_hp and int(sorcerer.feature_uses.get("sorcery_points", -1)) == saved_sp, "The failed-margin aftermath waits for damage settlement, applies once, and replay cannot repeat effects or costs (aftermath=%d, thp=%d, hp_after=%d, sp=%d, slot=%d, replay=%s)" % [aftermath_outcomes.size(), int(save_target["temp_hp"]), hp_after_empowered, saved_sp, saved_slot, str(replay)])

	var margin_context := _margin_adapter_context(sorcerer, save_target, margin_spell)
	var margin_adapter := SharedStepExecutor.SpellAdapter.new(margin_context)
	var exact_boundary := [{"step_id": "save", "type": "save", "target_outcomes": [{"target": save_target, "saved": false, "result": {"numeric_margin": -5}}]}]
	var one_above := [{"step_id": "save", "type": "save", "target_outcomes": [{"target": save_target, "saved": false, "result": {"numeric_margin": -4}}]}]
	var equality_success := [{"step_id": "save", "type": "save", "target_outcomes": [{"target": save_target, "saved": true, "result": {"numeric_margin": 0}}]}]
	var margin_gate: Dictionary = margin_spell["steps"][1]["effects"][0]["when"]
	check.call(SharedStepExecutor.evaluate_predicate(margin_gate, margin_adapter, save_target, exact_boundary) and not SharedStepExecutor.evaluate_predicate(margin_gate, margin_adapter, save_target, one_above) and SharedStepExecutor.evaluate_predicate({"result": {"step": "save", "target": "same", "measure": "margin"}, "eq": 0}, margin_adapter, save_target, equality_success), "Signed margin threshold includes exact equality, excludes one point above, and zero at DC is an available successful save margin")
	var no_roll := [{"step_id": "save", "type": "save", "target_outcomes": [{"target": save_target, "saved": false, "result": {}}]}]
	check.call(not SharedStepExecutor.evaluate_formula({"result": {"step": "save", "target": "same", "measure": "margin"}}, margin_adapter, save_target, no_roll).get("success", true), "An overridden/no-roll outcome without numeric roll fields has no fabricated margin")

	var hp_target := {"id": "settlement-hp-target", "name": "Settlement HP Target", "current_hp": 10, "max_hp": 100, "temp_hp": 0, "is_alive": true, "conditions": {}}
	var hp_result := CombatAction.resolve_spell(sorcerer, hp_target, hp_spell, false, {}, [], 1, 5)
	var hp_steps: Array = hp_result.get("step_results", [])
	var impact_outcome: Dictionary = hp_steps[0].get("target_outcomes", [{}])[0] if hp_steps.size() > 0 else {}
	var captured_hp := SharedStepExecutor.evaluate_formula({"result": {"step": "impact", "target": "same", "measure": "hp_after"}}, SharedStepExecutor.SpellAdapter.new(_margin_adapter_context(sorcerer, hp_target, hp_spell)), hp_target, hp_steps)
	var hp_before_change := int(hp_target["current_hp"])
	hp_target["current_hp"] = 40
	var captured_hp_after_change := SharedStepExecutor.evaluate_formula({"result": {"step": "impact", "target": "same", "measure": "hp_after"}}, SharedStepExecutor.SpellAdapter.new(_margin_adapter_context(sorcerer, hp_target, hp_spell)), hp_target, hp_steps)
	hp_target["current_hp"] = hp_before_change
	check.call(bool(hp_result.get("success", false)) and int(impact_outcome.get("hp_after", -1)) == 2 and int(hp_target["current_hp"]) == 5 and int(hp_target["temp_hp"]) == 3 and captured_hp.get("value", -1) == 2 and captured_hp_after_change.get("value", -1) == 2, "Renamed HP gate uses post-damage HP despite later healing, damage and live HP changes")
	var explicit_zero_hp := [{"step_id": "impact", "type": "damage", "target_outcomes": [{"target": hp_target, "hp_after": 0}]}]
	check.call(SharedStepExecutor.evaluate_formula({"result": {"step": "impact", "target": "same", "measure": "hp_after"}}, SharedStepExecutor.SpellAdapter.new(_margin_adapter_context(sorcerer, hp_target, hp_spell)), hp_target, explicit_zero_hp).get("value", -1) == 0 and not SharedStepExecutor.evaluate_formula({"result": {"step": "impact", "target": "same", "measure": "hp_after"}}, SharedStepExecutor.SpellAdapter.new(_margin_adapter_context(sorcerer, hp_target, hp_spell)), hp_target, []).get("success", true), "A settled zero HP receipt remains distinct from a missing HP receipt")
	var unknown_ref := hp_spell.duplicate(true)
	unknown_ref["steps"][3]["effects"][0]["when"]["result"]["step"] = "absent"
	var malformed_ref := hp_spell.duplicate(true)
	malformed_ref["steps"][3]["effects"][0]["when"]["result"]["component"] = "force"
	var future_ref := hp_spell.duplicate(true)
	future_ref["steps"][3]["effects"][0]["when"]["result"]["step"] = "afterimage"
	var invalid_refs: Array = [unknown_ref, malformed_ref, future_ref]
	var invalid_refs_refused := true
	for invalid_ref in invalid_refs:
		var slots_before_refusal := int(sorcerer.spell_slots.get("1", -1))
		var hp_before_refusal := int(hp_target["current_hp"])
		var refused_ref := CombatAction.resolve_spell(sorcerer, hp_target, invalid_ref, true, {}, [], 1, 5)
		invalid_refs_refused = invalid_refs_refused and not SharedSpell.content_error(invalid_ref).is_empty() and not bool(refused_ref.get("success", true)) and int(sorcerer.spell_slots.get("1", -1)) == slots_before_refusal and int(hp_target["current_hp"]) == hp_before_refusal
	check.call(invalid_refs_refused, "Unknown, malformed and future gate references refuse before slot payment or HP changes")


static func _margin_adapter_context(caster: Character, target, spell: Dictionary) -> SpellResolutionContext:
	var context := SpellResolutionContext.new()
	context.caster = caster
	context.target = target
	context.spell = spell
	context.effect_cast = {"caster_id": caster.character_id}
	return context


static func _child_group_checks(check: Callable) -> void:
	var actor := Character.new()
	actor.initialize("Group", "human", "wizard", AbilityScores.new())
	var other := Character.new()
	other.initialize("Twin", "human", "wizard", AbilityScores.new())
	var cast := SpellResolutionContext.new()
	cast.caster = actor
	cast.target = actor
	var adapter := SharedStepExecutor.SpellAdapter.new(cast)
	var group := {"mode":"count", "steps":["a","b"], "targets":"all", "outcome":"hit", "empty":"fail", "skipped":"exclude", "comparison":"gte", "threshold":2}
	var results := [{"step_id":"a", "type":"attack", "complete":true, "target_outcomes":[{"target":actor,"hit":true},{"target":other,"hit":false}]}, {"step_id":"b", "type":"attack", "complete":true, "target_outcomes":[{"target":actor,"hit":true}]}]
	for threshold in [1,2,3]:
		group.threshold=threshold
		check.call(SharedStepExecutor.evaluate_predicate({"child_group":group},adapter,actor,results)==(threshold<=2), "Child count below/at/above threshold retains repeated actor attempts")
	group.erase("comparison")
	group.erase("threshold")
	for mode in ["all","any"]:
		group.mode=mode
		check.call(SharedStepExecutor.evaluate_predicate({"child_group":group},adapter,actor,results)==(mode=="any"), "Child group mixed final outcomes: "+mode)
		results[1].complete=false
		check.call(SharedStepExecutor._evaluate_predicate_state({"child_group":group},adapter,actor,results)==-1, "Unfinished child blocks even already satisfied "+mode)
		results[1].complete=true
	group.steps=["a"]
	results[0].target_outcomes=[]
	for policy in ["pass","fail","unavailable"]:
		group.empty=policy
		check.call(SharedStepExecutor._evaluate_predicate_state({"child_group":group},adapter,actor,results)==(1 if policy=="pass" else (0 if policy=="fail" else -1)), "Known empty group explicit policy: "+policy)
	results[0].target_outcomes=[{"target":actor,"skipped":true}]
	group.empty="pass"
	for policy in ["exclude","fail","unavailable"]:
		group.skipped=policy
		check.call(SharedStepExecutor._evaluate_predicate_state({"child_group":group},adapter,actor,results)==(1 if policy=="exclude" else (0 if policy=="fail" else -1)), "Skipped child explicit policy: "+policy)
	group.steps=["missing"]
	check.call(SharedStepExecutor._evaluate_predicate_state({"not":{"child_group":group}},adapter,actor,results)==-1, "Missing child group remains unknown under negation")
	for id in ["sandbox:child_group_neutral","sandbox:child_group_renamed"]:
		check.call(SharedSpell.content_error(DataLoader.get_spell(id)).is_empty(), "Loaded child group fixture validates: "+id)


static func _formula_input_checks(check: Callable) -> void:
	var actor := Character.new()
	actor.initialize("Input", "human", "wizard", AbilityScores.new())
	var host := SpellCastContext.new()
	host.caster=actor
	host.spell=DataLoader.get_spell("sandbox:formula_number_renamed").duplicate(true)
	for invalid in [true, "2", 1.5, -1, 4, null]:
		check.call(not SpellFormulaInputs.capture(host,"amount",invalid) and host.formula_inputs.is_empty(), "Numeric input refuses wrong type/range: "+str(invalid))
	check.call(SpellFormulaInputs.capture(host,"amount",1) and not SpellFormulaInputs.capture(host,"amount",3), "Numeric input captures once at lower edge; replay cannot replace it")
	var cast := SpellResolutionContext.new()
	cast.caster=actor
	cast.spatial_host=host
	cast.invocation_id=host.invocation_id
	cast.spell=host.spell
	cast.spell_definition_id=str(host.spell.id)
	var read := SpellFormulaInputs.read(cast,"amount")
	check.call(read.get("success",false) and read.get("value")==1 and not SpellFormulaInputs.read(cast,"unknown").get("success",true), "Only declared host-captured numeric value is available")
	host.formula_inputs.clear()
	check.call(SpellFormulaInputs.capture(host,"amount",3) and SpellFormulaInputs.read(cast,"amount").get("value")==3, "Numeric upper edge remains exact")
	for id in ["sandbox:formula_die_neutral","sandbox:formula_number_renamed"]:
		check.call(SharedSpell.content_error(DataLoader.get_spell(id)).is_empty(), "Loaded formula input definition validates: "+id)


static func _class_level_table_checks(check: Callable) -> void:
	DataLoader._load_json_file("res://data/fixtures/class_level_tables.json","class")
	var actor := Character.new()
	actor.initialize("Allocation", "human", "wizard", AbilityScores.new())
	actor.character_id="fixture:allocation"
	actor.level=8
	actor.class_levels={"wizard":3,"cleric":5}
	var neutral: Dictionary = DataLoader.classes["fixture:class_table_neutral_class"].features_by_level["1"][0]
	var renamed: Dictionary = DataLoader.classes["fixture:class_table_renamed_class"].features_by_level["1"][0]
	check.call(actor.get_class_level("wizard")==3 and actor.get_class_level("cleric")==5 and actor.get_class_level("fighter")==0, "Actual allocation separates each class and absent class from total eight")
	var a := ResourcePoolRules.acquire(actor,neutral,"fixture:allocation:a")
	var b := ResourcePoolRules.acquire(actor,renamed,"fixture:allocation:b")
	check.call(a.get("success",false) and b.get("success",false) and a.pool.capacity==5 and a.pool.die_size==8 and b.pool.capacity==4 and b.pool.die_size==6, "Independent source pools select declared numeric and die-size rows")
	ResourcePoolRules.spend(actor,"fixture:allocation:a",1)
	actor.class_levels={"wizard":5,"cleric":3}
	var grown := ResourcePoolRules.recalculate_capacity(actor,neutral,"fixture:allocation:a")
	check.call(grown.get("success",false) and grown.pool.capacity==7 and grown.pool.current==1 and grown.pool.die_size==12 and actor.numeric_resource_pools["fixture:allocation:b"].current==2, "Growth updates numeric/die-size rows, preserves spent quantity and unrelated source")
	actor.class_levels={"wizard":1,"cleric":7}
	var shrunk := ResourcePoolRules.recalculate_capacity(actor,neutral,"fixture:allocation:a")
	check.call(shrunk.pool.capacity==3 and shrunk.pool.current==1 and shrunk.pool.die_size==6, "Shrink keeps/clamps remaining instead of reacquiring")
	var table: Dictionary = neutral.resource_pool.die_size.duplicate(true)
	for bad in [7,0,21,3.5,true]:
		table.breakpoints[0].value=bad
		check.call(not ResourcePoolRules.die_size_error(table).is_empty(), "Unsupported die-size row refuses before RNG: "+str(bad))
	table=neutral.resource_pool.capacity_formula.duplicate(true)
	actor.class_levels={"wizard":1,"cleric":7}
	table.breakpoints=[{"threshold":2,"value":4}]
	check.call(not SharedStepExecutor.evaluate_actor_formula(table,actor).get("success",true), "Below-first unavailable is explicit")
	table.below_first="zero"
	check.call(SharedStepExecutor.evaluate_actor_formula(table,actor).get("value")==0, "Numeric below-first zero policy is explicit")
	table.breakpoints=[{"threshold":2,"value":4},{"threshold":2,"value":5}]
	check.call(not SharedStepExecutor.formula_content_error(table).is_empty(), "Duplicate progression thresholds refuse")
	actor.class_levels={"wizard":2,"cleric":7}
	check.call(not SharedStepExecutor.evaluate_actor_formula({"caster_class_level":"wizard"},actor).get("success",true), "Malformed total cannot guess a class level")
	for allocation in [{"wizard":2,"cleric":7},{"wizard":8,"unknown":1},{"wizard":true},{"cleric":8},[8]]:
		check.call(not Character.saved_class_levels_error({"class_levels":allocation,"class_id":"wizard","level":8}).is_empty(), "Malformed saved class allocation refuses: "+str(allocation))


static func _batch_025_dice_checks(check: Callable) -> void:
	BatchJChecks.run(check)
	var multiplier_floor := Dice.apply_damage_multiplier(5, 1, 2, "floor")
	var multiplier_ceil := Dice.apply_damage_multiplier(5, 1, 2, "ceil")
	check.call(multiplier_floor.success and multiplier_floor.value == 2 and multiplier_ceil.value == 3, "Damage-result multipliers apply their explicit floor or ceiling rounding")
	check.call(not Dice.apply_damage_multiplier(5, 1, 0, "floor").success, "Damage-result multiplier rejects a zero denominator")
	var caster := Character.new()
	caster.initialize("Dice policy", "human", "wizard", AbilityScores.new())
	var target := {"id": "fixture:batch025_target", "name": "Dice target", "current_hp": 100, "max_hp": 100, "is_alive": true, "conditions": {}}
	var spell := {
		"id": "fixture:batch025_damage", "name": "Bounded Dice", "execution": "shared", "level": 0,
		"casting_time": "action", "range": 1, "target": "single", "damage": "3d6",
		"damage_type": "force", "damage_dice_policy": {"remove": 1, "maximize": 1},
		"damage_result_multiplier": {"numerator": 1, "denominator": 2, "rounding": "floor"}
	}
	check.call(SharedSpell.content_error(spell).is_empty(), "Loaded shared spell accepts bounded removal, maximization and a rounded final multiplier")
	var resolved := CombatAction.resolve_spell(caster, target, spell, false, {}, [], 1, 0)
	var details: Dictionary = resolved.get("damage_roll", {})
	var roll_policy: Dictionary = details.get("damage_dice_policy", {})
	var multiplier_receipt: Dictionary = resolved.get("damage_multiplier_receipt", {})
	var expected_damage := int(floor(float(int(details.get("final_total", 0))) / 2.0))
	check.call(resolved.get("success", false) and int(roll_policy.get("removed", -1)) == 1 and int(roll_policy.get("maximized", -1)) == 1 and int(resolved.get("damage", -1)) == expected_damage and target.current_hp == 100 - expected_damage and int(multiplier_receipt.get("numerator", 0)) == 1 and int(multiplier_receipt.get("denominator", 0)) == 2 and str(multiplier_receipt.get("rounding", "")) == "floor", "Shared spell host removes and maximizes dice before rolling, then records its final multiplier receipt")
	var healing_target := {"id": "fixture:batch025_heal_target", "name": "Healing dice target", "current_hp": 50, "max_hp": 100, "is_alive": true, "conditions": {}, "temp_hp": 0}
	var healing_spell := {"id": "fixture:batch025_healing", "name": "Bounded Healing", "execution": "shared", "level": 1, "casting_time": "action", "range": 1, "target": "single", "effects": [{"type": "heal", "value": "3d6", "dice_policy": {"remove": 1, "maximize": 1}, "result_multiplier": {"numerator": 1, "denominator": 2, "rounding": "floor"}}]}
	var healing_result := CombatAction.resolve_spell(caster, healing_target, healing_spell, false, {}, [], 1, 1)
	check.call(SharedSpell.content_error(healing_spell).is_empty() and healing_result.get("success", false) and int(healing_result.get("healing", -1)) >= 3 and int(healing_result.get("healing", -1)) <= 6 and int(healing_target.current_hp) == 50 + int(healing_result.get("healing", 0)), "Shared heal effect applies pre-roll die edits and the explicit final-result rounding")
	var malformed := spell.duplicate(true)
	malformed["damage_dice_policy"] = {"remove": -1}
	check.call(not SharedSpell.content_error(malformed).is_empty(), "Malformed dice edits refuse at shared content validation")
	var reroll_input := Dice.parse_dice_details("2d6")
	var reroll_old := int(reroll_input.dice_terms[0].results[0])
	var rerolled := Dice.reroll_selected_dice(reroll_input, [0], 1)
	var reroll_detail: Dictionary = rerolled.details.dice_terms[0]
	check.call(rerolled.success and not bool(reroll_detail.kept[0]) and int(reroll_detail.results[0]) == reroll_old and reroll_detail.results.size() == 3 and int(rerolled.details.final_total) == int(reroll_detail.subtotal), "Selected-die reroll preserves the old face and unchanged sibling while replacing exactly one result")
	for keep_case in [{"policy": "higher", "original": 6}, {"policy": "lower", "original": 1}]:
		var original_face := int(keep_case.original)
		var retained_input := {"dice_terms": [{"sides": 6, "results": [original_face], "kept": [true], "subtotal": original_face, "count": 1}], "final_total": original_face}
		seed(1)
		var retained := Dice.reroll_selected_dice(retained_input, [0], 1, null, keep_case.policy)
		var retained_dice := Dice.selectable_dice(retained.details)
		check.call(retained_dice.size() == 1 and int(retained_dice[0].value) == original_face and int(retained.details.final_total) == original_face, "Retained %s reroll keeps the original face selectable and excludes its discarded replacement" % keep_case.policy)
	var inspired_roller := Character.new()
	inspired_roller.initialize("Inspired reroll", "human", "wizard", AbilityScores.new())
	inspired_roller.heroic_inspiration = true
	inspired_roller.fighter_training["inspiration_any_die"] = true
	seed(3)
	var inspired := Dice.reroll_selected_dice({"dice_terms": [{"sides": 6, "results": [6], "kept": [true], "subtotal": 6, "count": 1}], "final_total": 6}, [0], 1, inspired_roller)
	var inspired_term: Dictionary = inspired.details.dice_terms[0]
	var aligned: bool = inspired_term.results.size() == inspired_term.kept.size()
	check.call(not inspired_roller.heroic_inspiration and inspired_term.results.size() == 3 and aligned, "An inspired selected reroll preserves one kept flag per original and Inspiration face")
	if aligned:
		var inspired_dice := Dice.selectable_dice(inspired.details)
		check.call(inspired_dice.size() == 1 and int(inspired_dice[0].value) == int(inspired.details.final_total), "An inspired selected reroll remains safely selectable with exactly the final kept face")
	var critical_dice_policy := {"remove": 1, "apply_to_critical": false}
	FighterChecks._seed_die(6, 3)
	var critical_dice := SpellDamageRolls._roll_spell_damage(caster, "1d6", 2, {}, critical_dice_policy)
	check.call(int(critical_dice.get("final_total", -1)) == 3 and int(critical_dice.get("damage_dice_policy", {}).get("removed", 0)) == 1, "Critical damage dice edits can spend their declared count on the base die while leaving the added critical die eligible to roll")
	var critical_target := {"id": "fixture:batch025_critical_target", "name": "Critical target", "current_hp": 20, "max_hp": 20, "is_alive": true, "conditions": {}, "temp_hp": 0}
	var critical_result := SpellDamageRolls._finish_spell_damage(caster, critical_target, {"final_total": 5, "dice_terms": []}, 0, 1.0, "force", {"critical": true, "damage_result_multiplier": {"numerator": 2, "exclude_critical": true}}, {"success": true, "hit": true, "message": "Test deals {damage}."})
	var critical_multiplier: Dictionary = critical_result.get("damage_multiplier_receipt", {})
	check.call(int(critical_result.get("damage", -1)) == 5 and critical_multiplier.get("applied", true) == false and critical_multiplier.get("excluded_critical", false), "An authored damage-result multiplier can explicitly leave critical results unchanged and records the exclusion")
	caster.character_id = "fixture:batch025_packet_caster"
	for critical in [true, false]:
		var packet_target := Character.new()
		packet_target.initialize("Critical packet history", "human", "fighter", AbilityScores.new())
		packet_target.character_id = "fixture:batch025_packet_history"
		packet_target.max_hp = 100
		packet_target.current_hp = 100
		var packet_result := SpellDamageRolls._finish_spell_damage(caster, packet_target, {"final_total": 5, "dice_terms": []}, 0, 1.0, "force", {"critical": critical, "damage_result_multiplier": {"numerator": 2, "exclude_critical": true}}, {"success": true, "message": "Test {damage}"}, 1, [{"type": "cold", "details": {"final_total": 4, "dice_terms": []}}])
		var expected_total := 9 if critical else 18
		var packet_history: Dictionary = packet_target.recent_damage_history.back()
		check.call(packet_result.damage == expected_total and packet_target.current_hp == 100 - expected_total and int(packet_result.damage_components[1].raw) == (4 if critical else 8), "Critical exclusion applies consistently to additional packet HP and raw receipts: critical=%s" % str(critical))
		check.call(int(packet_history.raw) == expected_total and int(packet_history.prevented) == 0 and int(packet_history.resolved) == expected_total, "Additional packet history never invents prevention when a critical multiplier is excluded: critical=%s" % str(critical))
	var heal_pool := {"id": "fixture:batch025_healing_reroll", "resource_pool": {"id": "fixture:batch025_healing_reroll_pool", "capacity_formula": 2, "initial_quantity": 1}}
	caster.character_id = "fixture:batch025_healing_reroll_owner"
	check.call(ResourcePoolRules.acquire(caster, heal_pool, "fixture:batch025_healing_reroll_source").get("success", false), "Healing reroll fixture acquires its exact authored payment source")
	var healing_policy := {"count": 1, "selection": "lowest", "keep": "new", "sides": 6, "cost": {"source_instance_id": "fixture:batch025_healing_reroll_source", "amount": 1}}
	var authored_heal := {"type": "heal", "value": "1d6", "reroll_policy": healing_policy}
	var reroll_target := {"id": "fixture:batch025_authored_heal", "name": "Authored heal target", "current_hp": 0, "max_hp": 20, "is_alive": true, "conditions": {}, "temp_hp": 0}
	FighterChecks._seed_die(6, 1)
	var authored_heal_result := SharedSpell.apply_custom_effects(caster, reroll_target, [authored_heal], {"success": true}, 1, [], null, {"id": "fixture:authored_healing_reroll"})
	var authored_reroll: Dictionary = authored_heal_result.get("healing_rerolls", [{}])[0]
	var authored_die: Dictionary = authored_reroll.get("rerolls", [{}])[0]
	var authored_payment: Dictionary = authored_reroll.get("payment", {})
	check.call(int(authored_reroll.get("selected", []).size()) == 1 and int(authored_die.get("original", 0)) == 1 and str(authored_die.get("kept", "")) == "new" and authored_reroll.get("paid", false) and str(authored_reroll.get("source_instance_id", "")) == "fixture:batch025_healing_reroll_source" and int(authored_reroll.get("cost_amount", 0)) == 1 and authored_payment.get("success", false) and int(ResourcePoolRules.availability(caster, "fixture:batch025_healing_reroll_source").get("current", -1)) == 0 and int(authored_heal_result.get("healing", -1)) == int(authored_die.get("new", 0)), "Authored healing reroll selects one eligible rolled die, keeps its replacement and records its exact paid pool receipt")
	var highest_seed := -1
	var highest_first := 0
	var highest_second := 0
	for seed_value in 10000:
		seed(seed_value)
		highest_first = randi_range(1, 6)
		highest_second = randi_range(1, 6)
		if highest_first < highest_second:
			highest_seed = seed_value
			break
	seed(highest_seed)
	var highest_target := {"id": "fixture:batch025_highest", "name": "Highest target", "current_hp": 0, "max_hp": 20, "is_alive": true, "conditions": {}, "temp_hp": 0}
	var highest_result := SharedSpell.apply_custom_effects(caster, highest_target, [{"type": "heal", "value": "2d6", "reroll_policy": {"count": 1, "selection": "highest", "keep": "new"}}], {"success": true}, 1, [], null, {"id": "fixture:authored_healing_reroll"})
	var highest_reroll: Dictionary = highest_result.get("healing_rerolls", [{}])[0].get("rerolls", [{}])[0]
	check.call(int(highest_reroll.get("original", 0)) == highest_second and int(highest_result.get("healing", -1)) == int(highest_reroll.get("new", 0)) + highest_first, "Authored healing reroll selection=highest chooses the highest eligible face and freezes its sibling")
	for keep_case in [{"policy": "higher", "first": 6, "second": 1}, {"policy": "lower", "first": 1, "second": 6}]:
		var pair_seed := -1
		for seed_value in 10000:
			seed(seed_value)
			if randi_range(1, 6) == int(keep_case.first) and randi_range(1, 6) == int(keep_case.second):
				pair_seed = seed_value
				break
		seed(pair_seed)
		var keep_target := {"id": "fixture:batch025_keep_%s" % keep_case.policy, "name": "Keep target", "current_hp": 0, "max_hp": 20, "is_alive": true, "conditions": {}, "temp_hp": 0}
		var keep_effect := {"type": "heal", "value": "1d6", "reroll_policy": {"count": 1, "selection": "lowest", "keep": str(keep_case.policy)}}
		var keep_result := SharedSpell.apply_custom_effects(caster, keep_target, [keep_effect], {"success": true}, 1, [], null, {"id": "fixture:authored_healing_reroll"})
		var keep_receipt: Dictionary = keep_result.get("healing_rerolls", [{}])[0]
		var keep_roll: Dictionary = keep_receipt.get("rerolls", [{}])[0]
		check.call(str(keep_roll.get("kept", "")) == "original" and int(keep_roll.get("original", 0)) == int(keep_case.first) and int(keep_roll.get("new", 0)) == int(keep_case.second) and int(keep_result.get("healing", -1)) == int(keep_case.first), "Authored healing keep=%s rerolls once but preserves the selected original face when it wins" % str(keep_case.policy))
	var sides_target := {"id": "fixture:batch025_sides", "name": "Sides target", "current_hp": 0, "max_hp": 20, "is_alive": true, "conditions": {}, "temp_hp": 0}
	FighterChecks._seed_die(6, 2)
	var sides_result := SharedSpell.apply_custom_effects(caster, sides_target, [{"type": "heal", "value": "1d6", "reroll_policy": {"count": 1, "selection": "lowest", "sides": 4}}], {"success": true}, 1, [], null, {"id": "fixture:authored_healing_reroll"})
	var sides_receipt: Dictionary = sides_result.get("healing_rerolls", [{}])[0]
	check.call(sides_receipt.get("selected", []).is_empty() and sides_receipt.get("rerolls", []).is_empty() and int(sides_result.get("healing", -1)) == 2, "Authored healing reroll excludes dice of an ineligible size without rerolling them")
	FighterChecks._seed_die(6, 1)
	var unpaid_target := {"id": "fixture:batch025_unpaid", "name": "Unpaid target", "current_hp": 0, "max_hp": 20, "is_alive": true, "conditions": {}, "temp_hp": 0}
	var unpaid_result := SharedSpell.apply_custom_effects(caster, unpaid_target, [authored_heal], {"success": true}, 1, [], null, {"id": "fixture:authored_healing_reroll"})
	var unpaid_receipt: Dictionary = unpaid_result.get("healing_rerolls", [{}])[0]
	var refused_payment: Dictionary = unpaid_receipt.get("payment", {})
	check.call(unpaid_receipt.get("payment_refused", false) and str(unpaid_receipt.get("source_instance_id", "")) == "fixture:batch025_healing_reroll_source" and int(unpaid_receipt.get("cost_amount", 0)) == 1 and refused_payment.get("success", true) == false and unpaid_receipt.get("selected", []).is_empty() and unpaid_receipt.get("rerolls", []).is_empty() and int(unpaid_result.get("healing", -1)) == 1 and int(ResourcePoolRules.availability(caster, "fixture:batch025_healing_reroll_source").get("current", -1)) == 0, "Authored healing reroll records exact-source refusal and skips cleanly when its cost source is empty")
	ResourcePoolRules.acquire(caster, heal_pool, "fixture:batch025_beacon_reroll_source")
	var beacon_target := {"id": "fixture:batch025_beacon", "name": "Beacon target", "current_hp": 0, "max_hp": 20, "is_alive": true, "conditions": {}, "temp_hp": 0, "spell_effects": {"fixture:beacon": {"spell_id": "beacon_of_hope"}}}
	var beacon_policy: Dictionary = healing_policy.duplicate(true)
	beacon_policy.cost.source_instance_id = "fixture:batch025_beacon_reroll_source"
	FighterChecks._seed_die(6, 2)
	var beacon_result := SharedSpell.apply_custom_effects(caster, beacon_target, [{"type": "heal", "value": "1d6", "reroll_policy": beacon_policy}], {"success": true}, 1, [], null, {"id": "fixture:authored_healing_reroll"})
	var beacon_receipt: Dictionary = beacon_result.get("healing_rerolls", [{}])[0]
	check.call(beacon_receipt.get("skipped_reason", "") == "beacon_maximizes_healing" and not beacon_receipt.get("paid", true) and int(ResourcePoolRules.availability(caster, "fixture:batch025_beacon_reroll_source").get("current", -1)) == 1 and int(beacon_result.get("healing", -1)) == 6, "Beacon's maximized healing makes rerolls redundant and leaves their declared payment untouched")
	var invalid_heal := {"id": "fixture:invalid_heal_reroll", "name": "Invalid reroll", "execution": "shared", "level": 1, "casting_time": "action", "range": 1, "target": "single", "effects": [{"type": "heal", "value": "2d6", "reroll_policy": {"count": 0}}]}
	check.call(not SharedSpell.content_error(invalid_heal).is_empty(), "Malformed authored healing reroll policy refuses before execution")


static func _batch_025_review_regressions(check: Callable) -> void:
	var caster := Character.new()
	var scores := AbilityScores.new()
	scores.from_dict({"INT": 16})
	caster.initialize("Review dice caster", "human", "wizard", scores)
	var target := {"id": "review-dice-target", "name": "Dice target", "current_hp": 100, "max_hp": 100, "is_alive": true, "armor_class": -100, "conditions": {}, "spell_effects": {}, "saving_throw_bonuses": {"WIS": -100}}
	var spell := {"id": "fixture:review_dice", "name": "Review dice", "execution": "shared", "level": 1, "casting_time": "action", "range": 6, "target": "single", "steps": []}
	for delivery in ["attack", "save"]:
		var step := {"id": "impact", "type": delivery, "damage": "1d6", "damage_type": "force", "damage_dice_policy": {"remove": 1}, "damage_result_multiplier": {"numerator": 2}}
		step["attack_type" if delivery == "attack" else "save"] = "ranged_spell" if delivery == "attack" else "WIS"
		spell["steps"] = [step]
		FighterChecks._seed_die(20, 10)
		var result := CombatAction.resolve_spell(caster, target, spell, false, {}, [], 1, 5)
		check.call(SharedSpell.content_error(spell).is_empty() and result.get("success", false) and int(result.get("damage", -1)) == 0, "Batch 025 ordered %s forwards dice removal" % delivery)
		step.erase("damage_dice_policy")
		step["damage"] = "5"
		FighterChecks._seed_die(20, 10)
		result = CombatAction.resolve_spell(caster, target, spell, false, {}, [], 1, 5)
		check.call(result.get("success", false) and int(result.get("damage", -1)) == 10, "Batch 025 ordered %s forwards its result multiplier" % delivery)
	# A top-level policy must not leak into an unrelated ordered sibling.
	spell["damage_dice_policy"] = {"remove": 20}
	spell["damage_result_multiplier"] = {"numerator": 0}
	spell["steps"] = [{"id": "plain", "type": "save", "save": "WIS", "damage": "5", "damage_type": "force"}]
	var result := CombatAction.resolve_spell(caster, target, spell, false, {}, [], 1, 5)
	check.call(int(result.get("damage", -1)) == 5, "Batch 025 ordered sibling does not inherit undeclared dice/result policies")
	spell.erase("damage_dice_policy")
	spell.erase("damage_result_multiplier")
	for policy in [{"remove": 2}, {"remove": 1, "maximize": 1}, {"maximize": 1, "sides": 8}, {"remove": 1}, {"maximize": 1}]:
		var components := [{"id": "fire", "damage_type": "fire", "damage": "1d6"}, {"id": "cold", "damage_type": "cold", "damage": "1d8"}]
		spell["steps"] = [{"id": "typed", "type": "save", "save": "WIS", "damage_components": components, "damage_dice_policy": policy}]
		result = CombatAction.resolve_spell(caster, target, spell, false, {}, [], 1, 5)
		var damage := int(result.get("damage", -1))
		var expected := 0 if policy.get("remove", 0) == 2 else 8
		var outcome: Dictionary = result.get("step_results", [])[0].get("target_outcomes", [])[0].get("result", {})
		var primary_policy: Dictionary = outcome.get("damage_roll", {}).get("damage_dice_policy", {})
		var secondary_policy: Dictionary = outcome.get("additional_damage_components", [])[0].get("roll", {}).get("damage_dice_policy", {})
		var exact_budget := int(primary_policy.get("removed", 0)) + int(secondary_policy.get("removed", 0)) == int(policy.get("remove", 0)) and int(primary_policy.get("maximized", 0)) + int(secondary_policy.get("maximized", 0)) == int(policy.get("maximize", 0))
		var amount_ok := damage >= 1 and damage <= 14
		if int(policy.get("remove", 0)) == 2 or policy.has("remove") and policy.has("maximize"): amount_ok = damage == expected
		check.call(SharedSpell.content_error(spell).is_empty() and exact_budget and amount_ok, "Batch 025 typed components share one dice-edit budget and keep size eligibility: %s" % str(policy))
	for kind in ["heal", "temporary_hp"]:
		spell.erase("steps")
		spell["effects"] = [{"type": kind, "value": 5, "ability_bonus_from_caster": true, "result_multiplier": {"numerator": 2}}]
		target["current_hp"] = 1
		target["temp_hp"] = 0
		result = CombatAction.resolve_spell(caster, target, spell, false, {}, [], 1, 5)
		check.call((int(result.get("healing", -1)) if kind == "heal" else int(target.get("temp_hp", -1))) == 16, "Batch 025 %s multiplies the complete value including the caster bonus" % kind)
		spell.erase("effects")
		spell["steps"] = [{"id": "restore", "type": "effect", "effects": [{"type": kind, "value": {"op": "add", "left": 2, "right": 3}, "result_multiplier": {"numerator": 2}}]}]
		target["current_hp"] = 1
		target["temp_hp"] = 0
		result = CombatAction.resolve_spell(caster, target, spell, false, {}, [], 1, 5)
		check.call(SharedSpell.content_error(spell).is_empty() and (int(target.current_hp) == 11 if kind == "heal" else int(target.temp_hp) == 10), "Batch 025 %s formula result receives its declared multiplier" % kind)
	spell.erase("steps")
	target["spell_effects"] = {"fixture:beacon": {"spell_id": "beacon_of_hope"}}
	for numerator in [0, 2]:
		spell["effects"] = [{"type": "heal", "value": "2d6", "dice_policy": {"remove": 1}, "result_multiplier": {"numerator": numerator}}]
		target["current_hp"] = 1
		result = CombatAction.resolve_spell(caster, target, spell, false, {}, [], 1, 5)
		check.call(int(result.get("healing", -1)) == 6 * numerator, "Batch 025 Beacon maximizes only remaining healing dice before multiplication: %d" % numerator)
	randomize()
