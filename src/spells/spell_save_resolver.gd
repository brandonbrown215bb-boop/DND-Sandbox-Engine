## Saving-throw spell resolution and its existing decisions.
class_name SpellSaveResolver
extends RefCounted

## Components consume one occurrence's edit budget in authored order. Read the
## roll receipt as well when area damage reuses an already captured primary roll.
static func _consume_dice_policy(remaining: Dictionary, details: Dictionary) -> void:
	var applied: Dictionary = details.get("damage_dice_policy", {})
	for field in ["remove", "maximize"]:
		if remaining.has(field):
			remaining[field] = maxi(0, int(remaining[field]) - int(applied.get("removed" if field == "remove" else "maximized", 0)))

static func resolve(cast: SpellResolutionContext) -> Dictionary:
	var save_ability: String = cast.spell.get("save", "DEX")
	var save_dc := 15 if str(cast.spell.get("id", "")) == "contact_other_plane" else int(cast.spell.get("_save_dc_override", SpellPermissionRules.save_dc(cast.caster, cast.spell)))
	var contact_patron_saved := str(cast.spell.get("id", "")) == "contact_other_plane" and cast.caster.has_feature("warlock_contact_patron")
	var willing_target_no_save := bool(cast.spell.get("willing_target_skips_save", false)) and cast.target is Character
	var careful_saved := not willing_target_no_save and SorcererRules.is_careful_spell_target(cast.caster, cast.spell, cast.target, cast.decisions.get("metamagic:careful_targets", []))
	var save_test: Dictionary = {}
	# Roll save for target
	var save_roll := 0
	var bonus_cache: Dictionary = cast.decisions.get("failed_save_numeric_bonus_tests", {})
	var result_key := str(cast.spell.get("_save_bonus_result_key", "direct:%s:%s:%s" % [str(cast.target.get_instance_id()) if cast.target is Object else str(cast.target.get("id", "target")), str(cast.spell.get("id", "")), save_ability]))
	var cached_save_test: Dictionary = bonus_cache.get(result_key, {})
	if not cached_save_test.is_empty():
		# The pending choice owns the exact check. A caster's live DC changes
		# while that choice is open must not rewrite the captured save.
		save_dc = int(cached_save_test.get("dc", save_dc))
	var cached_post_roll_flags: Dictionary = cached_save_test.get("_post_roll_flags", {})
	if not cached_save_test.is_empty():
		save_test = cached_save_test.duplicate(true)
		save_test.erase("_post_roll_flags")
		bonus_cache.erase(result_key)
		cast.decisions["failed_save_numeric_bonus_tests"] = bonus_cache
		save_roll = int(save_test.get("total", 0))
	var poison_save_advantage := false
	if cast.target is Character:
		poison_save_advantage = cast.target.has_condition("protection_from_poison") and CombatAction.spell_grants_condition(cast.spell, "poisoned")
	elif cast.target is Dictionary:
		poison_save_advantage = cast.target.get("conditions", {}).has("protection_from_poison") and CombatAction.spell_grants_condition(cast.spell, "poisoned")
	var target_save_advantage := poison_save_advantage or (cast.target is Dictionary and bool(cast.spell.get("save_advantage_if_fighting_target", false)))
	var auto_fail_creature_types: Array = cast.spell.get("auto_fail_save_creature_types", [])
	var target_creature_type := ""
	if cast.target is Character:
		target_creature_type = cast.target.get_creature_type()
	elif cast.target is Dictionary:
		target_creature_type = str(cast.target.get("creature_type", ""))
	var target_save_disadvantage: bool = target_creature_type in cast.spell.get("save_disadvantage_creature_types", [])
	target_save_disadvantage = target_save_disadvantage or (save_ability == "DEX" and CombatAction.has_condition(cast.target, "restrained"))
	var paralyzed_save_auto_fail := CombatAction.is_paralyzed(cast.target) and save_ability in ["STR", "DEX"]
	var object_without_ability_scores: bool = cast.target is Dictionary and bool(cast.target.get("is_object", false)) and not cast.target.has("ability_scores")
	var automatically_fails: bool = not contact_patron_saved and (target_creature_type in auto_fail_creature_types or paralyzed_save_auto_fail or (save_ability in ["STR", "DEX"] and object_without_ability_scores))
	var heightened := bool(cached_post_roll_flags.get("heightened", false)) if not cached_save_test.is_empty() else bool(cast.decisions.get("metamagic:heightened", false)) and not automatically_fails and not careful_saved and not contact_patron_saved and cast.caster.class_id == "sorcerer" and "heightened_spell" in cast.caster.sorcerer_metamagic_choices and str(cast.spell.get("target", "")) == "single"
	if cached_save_test.is_empty() and heightened and not SorcererRules.spend_metamagic_cost(cast.caster, 2, cast.decisions):
		heightened = false
	if not cached_save_test.is_empty():
		pass
	elif contact_patron_saved:
		save_test = {"total": save_dc, "success": true}
		save_roll = save_dc
	elif automatically_fails:
		save_test = {"total": -1000, "success": false}
		save_roll = -1000
	elif willing_target_no_save:
		save_test = {"total": 0, "success": false}
		save_roll = 0
	elif cast.target is Character:
		save_test = cast.target.saving_throw_test_to_dc(save_ability, save_dc, target_save_advantage, heightened or target_save_disadvantage, cast.decisions)
		save_roll = int(save_test.get("total", 0))
	elif cast.target is Dictionary:
		# Monster stats
		var save_has_advantage: bool = target_save_advantage and not target_save_disadvantage and not heightened
		var save_has_disadvantage: bool = (target_save_disadvantage or heightened) and not target_save_advantage
		save_test = BarbarianRules.roll_monster_save_result(cast.target, save_ability, null, save_has_advantage, save_has_disadvantage, cast.decisions)
		save_roll = int(save_test.get("total", 0))
		if save_ability in ["STR", "DEX"] and cast.target.get("conditions", {}).has("stunned"):
			save_roll = -1000
	var save_context_receipt := SpellDamageRolls.save_context_receipt(cast)
	if save_context_receipt.is_empty():
		save_test.erase("save_context")
	else:
		save_test["save_context"] = save_context_receipt.duplicate(true)

	var outcome_override := str(save_test.get("outcome_override", ""))
	var saved := outcome_override == "success" or (outcome_override != "failure" and (contact_patron_saved or careful_saved or (not willing_target_no_save and save_roll >= save_dc)))
	var target_name: String = cast.target.character_name if cast.target is Character else str(cast.target.get("name", "Target"))
	var countercharm_used := bool(cached_post_roll_flags.get("countercharm_used", false))
	var inflicted_condition := str(cast.spell.get("condition_on_failed_save", ""))
	if SharedSpell.uses(cast.spell):
		# SharedSpell applies the grant; this name only enables Countercharm.
		for candidate in ["charmed", "frightened"]:
			if CombatAction.spell_grants_condition(cast.spell, candidate):
				inflicted_condition = candidate
				break
	if cached_save_test.is_empty() and not saved and not automatically_fails and cast.target is Character and inflicted_condition in ["charmed", "frightened"]:
		for observer in cast.observers:
			if not observer is Character or not observer.is_alive or CombatAction.is_incapacitated(observer) or not observer.has_feature("bard_countercharm") or not observer.reaction_available:
				continue
			var observer_key := "countercharm:%s" % observer.character_id
			if not bool(cast.decisions.get(observer_key, cast.decisions.get("countercharm:%s" % observer.character_name, cast.decisions.get("countercharm", false)))):
				continue
			observer.reaction_available = false
			save_test = cast.target.make_saving_throw_result(save_ability, true, heightened)
			save_test["dc"] = save_dc
			save_roll = int(save_test.get("total", 0))
			saved = save_roll >= save_dc
			countercharm_used = true
			break
	var stroke_of_luck_used := bool(cached_post_roll_flags.get("stroke_of_luck_used", false))
	if cached_save_test.is_empty() and not saved and not automatically_fails and not willing_target_no_save and cast.target is Character:
		var stroke_key := "stroke_of_luck:%s" % cast.target.character_id
		var stroke_result := RogueRules.apply_stroke_of_luck(cast.target, save_test, bool(cast.decisions.get(stroke_key, cast.decisions.get("stroke_of_luck_save", false))))
		if stroke_result.get("used", false):
			save_test = stroke_result.get("result", save_test)
			save_roll = int(save_test.get("total", save_roll))
			saved = bool(save_test.get("success", save_roll >= save_dc))
			stroke_of_luck_used = true
	var bardic_inspiration_used := bool(cached_post_roll_flags.get("bardic_inspiration_used", false))
	if cached_save_test.is_empty() and not saved and not automatically_fails and not willing_target_no_save and cast.target is Character:
		var inspiration_test := BardicInspirationRules.apply_to_test(cast.target, save_roll, save_dc, bool(cast.decisions.get("bardic_inspiration", false)))
		if inspiration_test.get("used", false):
			save_roll = int(inspiration_test["total"])
			saved = bool(inspiration_test["success"])
			save_test["total"] = save_roll
			save_test["success"] = saved
			save_test["bardic_inspiration_bonus"] = int(inspiration_test.get("bonus", 0))
			save_test["bardic_inspiration_die"] = str(inspiration_test.get("die", ""))
			bardic_inspiration_used = true
	var shared_spell := SharedSpell.uses(cast.spell) or bool(cast.spell.get("_shared_spell_step", false))
	var has_rolled_save := save_test.has("natural_roll") or save_test.has("natural")
	if shared_spell and SpellDamageRolls.has_failed_save_choice_host(cast.decisions) and not automatically_fails and not willing_target_no_save and not careful_saved and not contact_patron_saved and cast.target is Character and cached_save_test.is_empty() and has_rolled_save:
		var bonus_options := SpellDamageRolls.failed_save_choice_options(cast.target, save_ability, saved, cast, save_test)
		if not bonus_options.is_empty():
			save_test["_post_roll_flags"] = {"heightened": heightened, "stroke_of_luck_used": stroke_of_luck_used, "bardic_inspiration_used": bardic_inspiration_used, "countercharm_used": countercharm_used}
			return SpellDamageRolls.create_failed_save_numeric_bonus_request(cast, cast.target, save_ability, save_test, result_key, bonus_options, saved)
	
	# Roll damage
	var damage_components: Array = cast.spell.get("damage_components", [])
	var primary_component: Dictionary = damage_components[0] if not damage_components.is_empty() else {}
	var component_counts: Dictionary = {}
	var primary_damage_spell := cast.spell
	if not primary_component.is_empty():
		primary_damage_spell = {"damage": str(primary_component.get("damage", "0")), "level": int(cast.spell.get("level", 0)), "upcast": primary_component.get("upcast", cast.spell.get("upcast", {}))}
	var damage_str := SpellDamageRolls.spell_damage_formula(cast.caster, primary_damage_spell, cast.slot_level)
	var damage_type: String = primary_component.get("damage_type", cast.spell.get("damage_type", "fire"))
	component_counts[damage_type] = 1
	var damage_details := SpellDamageRolls._roll_spell_damage(cast.caster, damage_str, 1, cast.decisions, cast.spell.get("damage_dice_policy", {})) if cast.has_damage_payload else {"dice_terms": [], "final_total": 0}
	var remaining_dice_policy: Dictionary = cast.spell.get("damage_dice_policy", {}).duplicate()
	_consume_dice_policy(remaining_dice_policy, damage_details)
	var additional_damage_packets: Array[Dictionary] = []
	for component_index in range(1, damage_components.size()):
		var component: Dictionary = damage_components[component_index]
		var component_spell := {"damage": str(component.get("damage", "0")), "level": int(cast.spell.get("level", 0)), "upcast": component.get("upcast", cast.spell.get("upcast", {}))}
		var component_formula := SpellDamageRolls.spell_damage_formula(cast.caster, component_spell, cast.slot_level)
		var component_decisions := cast.decisions.duplicate()
		component_decisions.erase("spell_damage_context")
		var component_details := SpellDamageRolls._roll_spell_damage(cast.caster, component_formula, 1, component_decisions, remaining_dice_policy)
		_consume_dice_policy(remaining_dice_policy, component_details)
		additional_damage_packets.append({
			"component_id": str(component.get("id", "%s:%d" % [str(component.get("damage_type", "fire")), int(component_counts.get(str(component.get("damage_type", "fire")), 0)) + 1])),
			"details": component_details,
			"type": str(component.get("damage_type", "fire")),
			"label": str(component.get("label", "%s damage" % str(component.get("damage_type", "fire")).capitalize())),
			"formula": component_formula,
		})
		var component_type := str(component.get("damage_type", "fire"))
		component_counts[component_type] = int(component_counts.get(component_type, 0)) + 1
	var damage_scale := 1.0
	
	var has_evasion := false
	if cast.target is Character and cast.target.has_feature_effect("evasion") and save_ability == "DEX" and bool(cast.spell.get("half_on_save", false)) and not CombatAction.is_incapacitated(cast.target):
		has_evasion = true

	if saved:
		if has_evasion:
			damage_scale = 0.0
		elif cast.spell.get("half_on_save", false):
			damage_scale = 0.0 if careful_saved else 0.5
		else:
			damage_scale = 0.0
	else:
		if has_evasion and cast.spell.get("half_on_save", false):
			damage_scale = 0.5
	var save_outcome := "success" if saved else "failure"
	if cast.spell.has("damage_scale_by_outcome") and not has_evasion and not careful_saved:
		damage_scale = SharedSpell.authored_damage_scale(cast.spell, save_outcome, damage_scale)
	var recipient_damage_receipt: Dictionary = _recipient_damage_map(cast, save_outcome) if not has_evasion and not careful_saved else {}
	if not recipient_damage_receipt.is_empty():
		damage_scale = float(recipient_damage_receipt.get("scale", damage_scale))
	var exemption_receipt := _recipient_damage_exemption(cast)
	if not exemption_receipt.is_empty():
		damage_scale = 0.0
	var msg := ""
	if outcome_override in ["success", "failure"]:
		msg = "%s's %s save was overridden to %s by %s (natural roll %d, total %d vs DC %d)." % [target_name, save_ability, outcome_override, str(save_test.get("outcome_override_source", "an owned source")), int(save_test.get("natural_roll", save_test.get("natural", save_roll))), save_roll, save_dc]
	elif willing_target_no_save:
		msg = "%s willingly enters Resilient Sphere without a saving throw." % target_name
	elif contact_patron_saved:
		msg = "%s automatically succeeds on the Contact Other Plane saving throw through Contact Patron." % target_name
	elif saved:
		msg = "%s succeeded on %s save (DC %d) taking {damage} %s damage." % [target_name, save_ability, save_dc, damage_type]
	else:
		msg = "%s failed %s save (DC %d) taking {damage} %s damage." % [target_name, save_ability, save_dc, damage_type]
	if automatically_fails:
		if cast.target is Dictionary and bool(cast.target.get("is_object", false)):
			msg = "%s automatically fails the %s save, taking {damage} %s damage." % [target_name, save_ability, damage_type]
		else:
			msg = "%s automatically fails the %s save as a %s, taking {damage} %s damage." % [target_name, save_ability, target_creature_type.capitalize(), damage_type]
	if not cast.has_damage_payload and not contact_patron_saved and not willing_target_no_save:
		if saved:
			msg = "%s succeeded on %s save (DC %d)." % [target_name, save_ability, save_dc]
		else:
			msg = "%s failed %s save (DC %d)." % [target_name, save_ability, save_dc]
	if countercharm_used:
		msg += " Countercharm rerolled the save with Advantage."
	if bardic_inspiration_used:
		msg += " Bardic Inspiration adds to the saving throw."
	if careful_saved:
		msg += " Careful Spell causes the creature to succeed and take no damage."
	if not saved and not inflicted_condition.is_empty():
		msg += " %s is %s." % [target_name, inflicted_condition]
	
	if cast.target is Character and not cast.target.last_save_note.is_empty():
		msg += " " + cast.target.last_save_note
	if stroke_of_luck_used:
		msg += " Stroke of Luck turns the failed saving throw into a 20."
	if int(save_test.get("post_roll_bonus", 0)) > 0:
		if save_test.get("post_roll_bonus_die", {}) is Dictionary and not save_test.get("post_roll_bonus_die", {}).is_empty():
			msg += " %s adds %d from a d%d after the failed save." % [str(save_test.get("post_roll_bonus_source", "A source")), int(save_test.get("post_roll_bonus", 0)), int(save_test["post_roll_bonus_die"].get("sides", 0))]
		else:
			msg += " %s adds +%d after the failed save." % [str(save_test.get("post_roll_bonus_source", "A source")), int(save_test.get("post_roll_bonus", 0))]
	var effective_save_disadvantage: bool = (target_save_disadvantage or heightened) and not target_save_advantage
	var base_res := {"success": true, "saved": saved, "save_total": save_roll, "save_dc": save_dc, "save_disadvantage": effective_save_disadvantage, "effect_cast": cast.effect_cast, "condition": inflicted_condition if not saved and not SharedSpell.uses(cast.spell) else "", "condition_source": "animal_friendship:%s" % cast.caster.character_id if str(cast.spell.get("id", "")) == "animal_friendship" else "", "caster_creature_type": cast.caster.creature_type, "countercharm_used": countercharm_used, "bardic_inspiration_used": bardic_inspiration_used, "stroke_of_luck_used": stroke_of_luck_used, "metamagic_used": careful_saved, "roll_token_replaced": bool(save_test.get("roll_token_replaced", false)), "message": msg}
	base_res["save_test"] = save_test.duplicate(true)
	if not save_context_receipt.is_empty():
		base_res["save_context"] = save_context_receipt.duplicate(true)
	if cast.spell.has("damage_scale_by_outcome") and not has_evasion and not careful_saved:
		SharedSpell.record_damage_scale(base_res, cast.spell, save_outcome, damage_scale)
	base_res["save_natural_roll"] = int(save_test.get("natural_roll", save_test.get("natural", save_roll)))
	base_res["save_modifier"] = int(save_test.get("modifier", 0))
	if not recipient_damage_receipt.is_empty():
		base_res["recipient_damage_map"] = recipient_damage_receipt.duplicate(true)
	if not exemption_receipt.is_empty():
		base_res["recipient_damage_exemption"] = exemption_receipt.duplicate(true)
	# Preserve a numeric roll margin separately from the final saved/failed result.
	# Automatic/no-roll outcomes deliberately have no numeric margin receipt.
	if save_test.has("natural_roll") or save_test.has("natural"):
		base_res["numeric_margin"] = save_roll - save_dc
	if int(save_test.get("post_roll_bonus", 0)) > 0:
		base_res["save_post_roll_bonus"] = int(save_test["post_roll_bonus"])
		base_res["save_post_roll_bonus_source"] = str(save_test.get("post_roll_bonus_source", ""))
		if save_test.get("post_roll_bonus_die", {}) is Dictionary and not save_test.get("post_roll_bonus_die", {}).is_empty():
			base_res["save_post_roll_bonus_die"] = save_test["post_roll_bonus_die"].duplicate(true)
			var source_id := str(save_test.get("post_roll_bonus_source", ""))
			var source_pool: Dictionary = cast.target.numeric_resource_pools.get(source_id, {}) if cast.target is Character else {}
			base_res["formula_source_die"] = {"source_instance_id":source_id, "owner_id":str(source_pool.get("owner_id", "")), "pool_definition_id":str(source_pool.get("definition_id", "")), "sides":int(save_test.post_roll_bonus_die.get("sides", 0)), "face":int(save_test.post_roll_bonus_die.get("total", 0))}
		base_res["save_payment_policy"] = str(save_test.get("save_payment_policy", "pay_on_choice"))
		base_res["save_cost_paid"] = bool(save_test.get("save_cost_paid", true))
	if outcome_override in ["success", "failure"]:
		base_res["save_outcome_override"] = outcome_override
		base_res["save_outcome_override_source"] = str(save_test.get("outcome_override_source", ""))
		base_res["save_outcome_override_feature_id"] = str(save_test.get("outcome_override_feature_id", ""))
		base_res["save_outcome_override_pool_definition_id"] = str(save_test.get("outcome_override_pool_definition_id", ""))
		base_res["save_outcome_override_owner_id"] = str(save_test.get("outcome_override_owner_id", cast.target.character_id if cast.target is Character else ""))
		base_res["save_outcome_override_domain"] = str(save_test.get("outcome_override_domain", "shared_spell_save"))
		base_res["save_outcome_override_stage"] = str(save_test.get("outcome_override_stage", "after_roll_before_consequences"))
		base_res["save_cost_paid"] = bool(save_test.get("save_cost_paid", true))
	if bool(save_test.get("roll_token_replaced", false)):
		base_res["roll_token_id"] = str(save_test.get("roll_token_id", ""))
		base_res["roll_token_value"] = int(save_test.get("roll_token_value", 0))
	var settlement_decisions := cast.decisions.duplicate(true)
	settlement_decisions["damage_result_multiplier"] = cast.spell.get("damage_result_multiplier", {})
	settlement_decisions["_shared_component_id"] = str(primary_component.get("id", cast.spell.get("component_id", "%s:1" % damage_type)))
	return SpellDamageRolls._finish_spell_damage(cast.caster, cast.target, damage_details, CombatAction.spell_damage_bonus(cast.caster, cast.spell) if cast.has_damage_payload else 0, damage_scale, damage_type, settlement_decisions, base_res, maxi(1, int(cast.spell.get("condition_duration", 1))), additional_damage_packets, cast.spell.get("damage_reductions", []), cast.spell.get("damage_bypasses", []))


static func _recipient_damage_map(cast: SpellResolutionContext, outcome: String) -> Dictionary:
	if cast == null or not cast.target is Character or outcome not in ["success", "failure"]:
		return {}
	var declaration: Dictionary = cast.spell.get("save_context", {})
	var matches: Array[Dictionary] = []
	for effect in ClassProgression.selected_feature_effects_of_type(cast.target, "recipient_damage_map"):
		if str(effect.get("domain", "")) != "shared_spell_save" or str(effect.get("ability", "")).to_upper() != str(cast.spell.get("save", "")).to_upper():
			continue
		var eligible := true
		for field in ["cause_id", "purpose_id", "origin_effect_id"]:
			if str(effect.get(field, "")) != str(declaration.get(field, "")):
				eligible = false
		if eligible:
			matches.append(effect)
	if matches.size() != 1:
		return {}
	var selected: Dictionary = matches[0]
	return {
		"owner_id": str(selected.get("source_owner_id", cast.target.character_id)),
		"feature_id": str(selected.get("feature_id", "")),
		"source_instance_id": str(selected.get("source_instance_id", "")),
		"effect_id": str(selected.get("id", "")),
		"domain": "shared_spell_save", "cause_id": str(declaration.get("cause_id", "")),
		"purpose_id": str(declaration.get("purpose_id", "")), "origin_effect_id": str(declaration.get("origin_effect_id", "")),
		"outcome": outcome, "scale": float(selected.get("success_scale" if outcome == "success" else "failure_scale", 1.0)),
	}


static func _recipient_damage_exemption(cast: SpellResolutionContext) -> Dictionary:
	var declaration: Variant = cast.spell.get("recipient_exemption_choice", {})
	var host := cast.spatial_host
	if host == null: return {}
	var binding := host.recipient_exemption_selection
	if binding.is_empty() or binding.get("caster")!=cast.caster or binding.get("invocation_id")!=cast.invocation_id or binding.get("declaration")!=declaration or binding.get("save_context")!=cast.spell.get("save_context",{}) or not SpellDamageRolls._host_contains(host.players,host.monsters,cast.caster) or not SpellDamageRolls._host_contains(host.players,host.monsters,cast.target): return {}
	if not binding.get("recipients",[]).any(func(actor): return SpellDamageRolls._is_canonical_actor(actor,cast.target)): return {}
	var selection: Variant = binding.get("receipt",{})
	if not declaration is Dictionary or declaration.is_empty() or not selection is Dictionary:
		return {}
	var recipient_id := SorcererRules.careful_spell_target_id(cast.target)
	var recipients: Variant = selection.get("recipient_ids", null)
	var eligible: Variant = selection.get("eligible_recipient_ids", null)
	if recipient_id.is_empty() or not recipients is Array or not eligible is Array or recipient_id not in recipients or recipient_id not in eligible:
		return {}
	if str(selection.get("selection_id", "")) != str(declaration.get("selection_id", "")) or str(selection.get("spell_definition_id", "")) != str(cast.spell.get("id", "")) or str(selection.get("caster_id", "")) != cast.caster.character_id:
		return {}
	var unique_ids := {}
	for id in recipients:
		if not id is String or id not in eligible or unique_ids.has(id): return {}
		unique_ids[id]=true
	if recipients.size() > int(declaration.get("selection_limit", 0)):
		return {}
	return {"selection_id": str(selection.get("selection_id", "")), "spell_definition_id": str(cast.spell.get("id", "")), "caster_id": cast.caster.character_id, "recipient_id": recipient_id, "stage": "after_save_before_damage", "save_unchanged": true, "riders_unchanged": true, "scale": 0.0}


