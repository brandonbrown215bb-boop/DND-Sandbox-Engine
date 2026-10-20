## Ordered shared spell boundary: validation, resources, interruption and dispatch.
class_name SpellResolver
extends RefCounted

static func resolve(caster: Character, target_entity, spell_data: Dictionary, deduct_slot: bool = false, reaction_decisions: Dictionary = {}, reaction_observers: Array = [], slot_level_override: int = 0, distance_feet: int = -1, owned_cast_context: SpellCastContext = null) -> Dictionary:
	var cast := SpellResolutionContext.new()
	cast.caster = caster
	cast.target = target_entity
	cast.spell = spell_data
	cast.spell_definition_id = str(spell_data.get("id", ""))
	cast.decisions = reaction_decisions.duplicate()
	cast.observers = reaction_observers
	cast.distance_feet = distance_feet
	var invocation_host := owned_cast_context
	var owned_host_valid := false
	if invocation_host != null and invocation_host.caster == caster and str(invocation_host.spell.get("id", "")) == cast.spell_definition_id:
		owned_host_valid = true
		cast.spatial_host = invocation_host
		cast.invocation_id = invocation_host.invocation_id
		cast.action_id = invocation_host.action_id
		cast.action_invocation_id = invocation_host.action_invocation_id
		cast.parent_source_id = invocation_host.parent_source_id
		cast.item_definition_id = str(invocation_host.component_item_id)
		cast.item_instance_id = str(invocation_host.component_instance_id)
		cast.item_copy_validated = bool(invocation_host.component_copy_validated)
		if invocation_host.action_history != null:
			cast.decisions["combat_history"] = invocation_host.action_history
	var support := SpellSupport.availability(cast.spell)
	if not support["available"]:
		return {"success": false, "unavailable": true, "message": support["reason"]}
	if SharedSpell.has_effect(cast.spell, "grant_source_benefits") and (caster == null or caster.character_id.is_empty()):
		return {"success": false, "refused": true, "message": "Source benefits require an identified caster."}
	var damage_policy_error := SharedSpell.damage_policy_availability_error(cast.spell, caster)
	if not damage_policy_error.is_empty():
		return {"success": false, "refused": true, "message": damage_policy_error}
	var ongoing_zone_trigger := bool(cast.spell.get("_ongoing_zone_trigger", false))
	for input_id in cast.spell.get("formula_inputs", {}):
		if not SpellFormulaInputs.read(cast, str(input_id)).get("success", false):
			return {"success":false,"refused":true,"message":"Formula input was not captured by this cast."}
	if cast.caster.has_condition("raging") and not ongoing_zone_trigger:
		return {"success": false, "message": "You cannot cast spells while raging."}
	if not ongoing_zone_trigger and not DruidRules.can_cast_spell(cast.caster, cast.spell):
		return {"success": false, "message": "You cannot cast this spell while using Wild Shape."}
	if not ongoing_zone_trigger:
		var target_validation := CombatAction.validate_spell_target(cast.caster, cast.target, cast.spell, cast.distance_feet)
		if not target_validation.get("success", false):
			return target_validation
	if str(cast.spell.get("id", "")) == "spare_the_dying":
		return SpellHealingResolver.spare_the_dying(cast)
	var spell_level: int = int(cast.spell.get("level", 0))
	cast.slot_level = maxi(spell_level, slot_level_override)
	cast.incoming_slot_spent = false
	cast.incoming_slot_key = ""

	# Refuse unavailable host capabilities / spatial context before slot deduction and effects
	if cast.spell.has("steps") and cast.spell.get("steps") is Array:
		var spatial_err := SharedStepExecutor.validate_spatial_context_for_steps(cast.spell.get("steps", []), cast.decisions)
		if not spatial_err.is_empty():
			return {"success": false, "refused": true, "error": spatial_err, "message": spatial_err}

	if not cast.spell.has("steps"):
		if cast.spell.has("physical_requirements"):
			var physical := PhysicalFactsRules.evaluate_physical_eligibility(cast.target, cast.spell.physical_requirements)
			if not physical.get("eligible", false): return {"success":false,"refused":true,"message":physical.get("reason", "Physical requirements are not met.")}
		if cast.spell.has("spatial_requirements"):
			var adapter := SharedStepExecutor.SpellAdapter.new(cast)
			var spatial := adapter.spatial_eligibility(cast.target, {})
			if not spatial.get("eligible", false): return {"success":false,"refused":true,"message":spatial.get("reason", "Spatial requirements are not met.")}

	# A validated exploration ritual finishes before its new effect begins.
	if owned_host_valid and invocation_host.ritual_seconds > 0:
		var party: Array = PartyManager.characters.values()
		if caster not in party: party.append(caster)
		for target in caster.concentrating_on.get("targets", []):
			if target != null and target not in party: party.append(target)
		if not SpellEffects.end_concentration(caster, party):
			SpellEncounterLifecycle._end_concentration(null, caster)
		GameManager.advance_campaign_time(invocation_host.ritual_seconds)
		var current_permission := SpellPermissionRules.selected_permission(caster, cast.spell)
		var captured_permission: Dictionary = {}
		for candidate in cast.spell.get("_source_permissions", []):
			if candidate.get("id", "") == cast.spell.get("_source_permission_id", ""): captured_permission = candidate
		if not caster.is_alive or CombatAction.is_incapacitated(caster) or current_permission.is_empty() or current_permission != captured_permission or not caster.inventory.has_required_spell_component(cast.spell, str(current_permission.get("class_id", caster.class_id))):
			return {"success":false,"interrupted":true,"ritual_seconds":invocation_host.ritual_seconds,"message":"The ritual was interrupted during its casting time; no spell effect or Material consumption completed."}
		invocation_host.component_instance_id = caster.inventory.required_spell_component_instance(cast.spell)
		if bool(cast.spell.get("material_component_consumed", false)) and not invocation_host.component_instance_id.is_empty():
			caster.inventory.take_instance(invocation_host.component_instance_id)
	# Deduct spell slot if leveled spell
	if deduct_slot and spell_level > 0:
		var slot_result := CombatAction.spend_spell_slot(cast.caster, cast.spell)
		if not slot_result.get("success", false):
			return slot_result
		cast.slot_level = int(slot_result.get("slot_level", spell_level))
		cast.incoming_slot_spent = not bool(slot_result.get("slot_recalled", false))
		cast.incoming_slot_key = str(cast.slot_level)
		cast.incoming_slot_pool_id = str(slot_result.get("slot_pool_id", "ordinary"))
	# Combat already paid its exact slot before opening reaction controls.
	# Carry that receipt into cancellation rather than treating this as an unpaid cast.
	if owned_host_valid and not deduct_slot and invocation_host.incoming_slot_spent:
		cast.incoming_slot_spent = true
		cast.incoming_slot_key = str(invocation_host.slot_level_used)
		cast.incoming_slot_pool_id = invocation_host.incoming_slot_pool_id
	CastInterruptionRules.reserve_cast_payment(cast, cast.spell)
	if not ongoing_zone_trigger:
		SpellEffects.consume_spell(cast.caster, "sanctuary", "cast", {"actor_id": SpellEffects.caster_id(cast.caster), "spell_id": str(cast.spell.get("id", ""))})
		if str(cast.spell.get("id", "")) != "invisibility":
			SpellEffects.consume_spell(cast.caster, "invisibility", "cast", {"actor_id": SpellEffects.caster_id(cast.caster), "spell_id": str(cast.spell.get("id", ""))})
	var source_created_for_cast := false
	cast.effect_cast = cast.spell.get("_effect_cast", {})
	if SpellEffects.manages(cast.spell) and cast.effect_cast.is_empty():
		cast.effect_cast = SpellEffects.begin_cast(cast.caster, cast.spell)
		source_created_for_cast = true
	cast.source_definition_id = cast.spell_definition_id
	cast.source_instance_id = str(cast.effect_cast.get("source_id", "")) if owned_host_valid or source_created_for_cast else ""
	cast.source_owner_id = SpellEffects.caster_id(caster) if caster != null else ""
	if not cast.source_instance_id.is_empty():
		cast.decisions["damage_source_instance_id"] = cast.source_instance_id
	else:
		if cast.invocation_id.is_empty():
			caster.spell_cast_serial += 1
		var invocation_source_id := cast.invocation_id if not cast.invocation_id.is_empty() else "cast:%d" % caster.spell_cast_serial
		cast.decisions["damage_source_instance_id"] = "spell:%s:%s:%s" % [cast.spell_definition_id, cast.source_owner_id, invocation_source_id]

	if cast.spell.get("zero_hp_aftermath") is Dictionary:
		cast.decisions["zero_hp_aftermath"] = cast.spell["zero_hp_aftermath"]
	var interruption := _resolve_counterspell(cast)
	for key in ["counterspell_saved_by", "counterspell_save_total", "counterspell_save_dc"]:
		if cast.decisions.has(key):
			reaction_decisions[key] = cast.decisions[key]
	if not interruption.is_empty():
		if owned_host_valid and bool(interruption.get("incoming_spell_slot_refunded", false)): invocation_host.incoming_slot_spent = false
		return interruption
	var flat_step := {"type":"save" if cast.spell.has("save") else "attack" if cast.spell.get("attack_type", "none") != "none" else "damage" if cast.spell.has("damage") else "effect"}
	if not cast.spell.has("steps") and cast.target != null and CastInterruptionRules.is_recipient_negated(cast, cast.target, flat_step):
		if not owned_host_valid: CastInterruptionRules.settle_cast_outcome(cast, "negated")
		return CastInterruptionRules.create_negated_result(cast, cast.target)
	if cast.incoming_slot_spent and cast.slot_level >= 1 and not owned_host_valid:
		WardRules.on_slot_spell_cast(cast.caster, cast.spell, cast.slot_level)

	if str(cast.spell.get("id", "")) == "disintegrate":
		var special := SpellControlResolver.disintegrate(cast)
		if not special.is_empty():
			return special
	if str(cast.spell.get("id", "")) == "power_word_stun":
		return SpellControlResolver.power_word_stun(cast)
	if str(cast.spell.get("id", "")) == "sleep":
		return SpellControlResolver.sleep(cast)
	if str(cast.spell.get("id", "")) == "revivify":
		return CorpseRules.revive(cast.target, int(GameManager.campaign_elapsed_seconds))
	if str(cast.spell.get("id", "")) == "gentle_repose":
		CorpseRules.preserve(cast.target, int(GameManager.campaign_elapsed_seconds))
		return {"success": true, "hit": true, "message": "%s’s remains are preserved for 10 days." % cast.target.character_name}
	if str(cast.spell.get("id", "")) == "regenerate":
		return SpellHealingResolver.regenerate(cast)
	if str(cast.spell.get("id", "")) == "animal_messenger":
		var special := SpellControlResolver.animal_messenger(cast)
		if not special.is_empty():
			return special
	if str(cast.spell.get("id", "")) == "hunters_mark":
		return SpellWardResolver.hunters_mark(cast)
	if str(cast.spell.get("id", "")) == "false_life":
		return SpellWardResolver.false_life(cast)
	if str(cast.spell.get("id", "")) == "divine_favor":
		return SpellWardResolver.divine_favor(cast)
	if str(cast.spell.get("id", "")) == "death_ward":
		return SpellWardResolver.death_ward(cast)
	if str(cast.spell.get("id", "")) == "sanctuary":
		return SpellWardResolver.sanctuary(cast)
	if str(cast.spell.get("id", "")) == "heroism":
		return SpellWardResolver.heroism(cast)
	if str(cast.spell.get("id", "")) == "magic_weapon":
		return SpellWardResolver.magic_weapon(cast)
	if str(cast.spell.get("id", "")) == "invisibility":
		return SpellWardResolver.invisibility(cast)
	if CombatAction._spell_directly_damages_target(cast.spell) and not CombatAction._spell_is_area_effect(cast.spell) and SpellEffects.has_spell(cast.target, "sanctuary"):
		var sanctuary_dc := CombatAction._spell_effect_save_dc(cast.target, "sanctuary", cast.caster.get_spell_save_dc())
		var sanctuary_save := int(cast.caster.saving_throw_test_to_dc("WIS", sanctuary_dc, false, false, cast.decisions).get("total", 0))
		if sanctuary_save < sanctuary_dc:
			return {"success": true, "hit": false, "damage": 0, "sanctuary_blocked": true, "saved": true, "sanctuary_save_total": sanctuary_save, "sanctuary_save_dc": sanctuary_dc, "slot_level": cast.slot_level, "effect_cast": cast.effect_cast, "message": "%s fails the Wisdom save against Sanctuary; the spell has no effect on that creature." % cast.caster.character_name}
	if SharedSpell.uses(cast.spell):
		var result := SharedSpell.resolve(cast)
		if not owned_host_valid and not result.has("damage_request") and not result.has("save_bonus_request") and not result.has("weapon_attack_bonus_request") and not result.has("concentration_request"):
			result["cast_settlement"] = CastInterruptionRules.settle_cast_outcome(cast, CastInterruptionRules.result_outcome(cast.spell, result))
		return result
	if str(cast.spell.get("id", "")) in ["power_word_heal", "power_word_kill"]:
		return SpellHealingResolver._resolve_words_power_spell(cast.caster, cast.target, cast.spell, cast.decisions)

	if cast.spell.has("damage_per_dart"):
		return SpellProjectileResolver._resolve_magic_missile(cast.caster, cast.target, cast.spell, cast.decisions, cast.slot_level)
	if cast.spell.has("damage_per_ray"):
		return SpellProjectileResolver._resolve_scorching_ray(cast.caster, cast.target, cast.spell, cast.decisions, cast.slot_level, cast.distance_feet)
	cast.has_damage_payload = cast.spell.has("damage") or cast.spell.has("damage_per_dart") or cast.spell.has("damage_per_ray") or not cast.spell.get("damage_components", []).is_empty()
	if not cast.has_damage_payload and not CombatAction.spell_requires_saving_throw(cast.spell) and str(cast.spell.get("attack_type", "none")) == "none":
		return {"success": true, "hit": true, "damage": 0, "slot_level": cast.slot_level, "effect_cast": cast.effect_cast, "message": "%s resolves without a damage roll." % cast.spell.get("name", "Spell")}

	if CombatAction.spell_requires_saving_throw(cast.spell):
		return SpellSaveResolver.resolve(cast)
	return SpellAttackResolver.resolve(cast)


static func _resolve_counterspell(cast: SpellResolutionContext) -> Dictionary:
	return CastInterruptionRules.resolve_cancellation(cast)
