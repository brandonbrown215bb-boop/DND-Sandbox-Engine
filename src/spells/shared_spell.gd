## JSON-only ordinary spells. Reuses the existing cast, roll and source lifecycle.
## This contract describes supported operations, never executable mod scripts.
class_name SharedSpell
extends RefCounted

const CONDITIONS := ["blinded", "deafened", "frightened", "poisoned", "prone", "restrained", "stunned", "paralyzed", "incapacitated", "blessed", "baned", "shield_of_faith"]
const ABILITIES := ["STR", "DEX", "CON", "INT", "WIS", "CHA"]
const EFFECTS := ["heal", "temporary_hp", "grant_condition", "remove_condition", "area_selection", "grant_source_benefits", "grant_damage_link", "grant_damage_response", "create_actor", "actor_projection", "suppress_item_magic", "bind_tether"]
const STEP_FIELDS := ["id", "type", "gate", "gate_step", "target", "shape", "radius", "size", "attack_type", "damage", "damage_type", "damage_components", "component_id", "scaling", "upcast", "save", "half_on_save", "save_context", "damage_scale_by_outcome", "damage_dice_policy", "damage_result_multiplier", "damage_reductions", "damage_bypasses", "recipient_exemption_choice", "effects", "incoming_negation", "incoming_negation_rule", "physical_requirements", "spatial_requirements"]
const STEP_TYPES := ["attack", "save", "damage", "effect"]
const STEP_GATES := ["always", "hit", "miss", "failed_save", "successful_save"]
const FIELDS := ["containment_targeting", "id", "name", "description", "execution", "level", "casting_time", "range", "range_kind", "range_by_character_level_feet", "target", "base_targets", "attack_type", "damage", "damage_type", "component_id", "scaling", "upcast", "save", "half_on_save", "save_exit_placement", "save_context", "damage_scale_by_outcome", "damage_dice_policy", "damage_result_multiplier", "damage_reductions", "damage_bypasses", "recipient_exemption_choice", "attack_unit_substitution", "requires_target_sight", "target_creature_types", "target_creature_type_exclusions", "target_sizes", "ignore_cover_on_save", "effects", "concentration", "duration", "duration_seconds", "repeat_save", "repeat_save_schedule", "repeat_save_interval_seconds", "repeat_save_stages", "repeat_save_dc_progression", "targets_objects", "ignites_objects", "area_radius", "cone_size", "end_on_target_damage", "end_on_any_damage", "end_on_party_damage", "source_end_rules", "components", "material", "material_component_item_id", "material_component_cost", "material_component_consumed", "consumed_material_item_id", "ritual", "rules_source", "rules_status", "school", "classes", "source", "trigger", "steps", "formula_inputs", "interruption_policy", "failure_policy", "empty_effect_policy", "cast_settlement", "cancellation_rule", "stopping_cost_policy", "incoming_negation_rule", "physical_requirements", "spatial_requirements", "zero_hp_aftermath", "end_aftermath", "reaction_trigger"] # Batch 065: reaction_trigger is validated by ReactionTriggers.spell_trigger_error.

static func damage_dice_policy_error(value: Variant) -> String:
	if not value is Dictionary or value.is_empty():
		return "Damage dice policy must be a nonempty object."
	for field in value:
		if field not in ["remove", "maximize", "sides", "apply_to_critical"]:
			return "Damage dice policy contains unsupported field '%s'." % str(field)
	for field in ["remove", "maximize"]:
		if value.has(field) and not _integer(value[field], 0, 20):
			return "Damage dice policy %s must be an integer from 0 through 20." % field
	if value.has("sides") and value["sides"] not in [4, 6, 8, 10, 12, 20]:
		return "Damage dice policy sides must be a supported die size."
	if value.has("apply_to_critical") and not value["apply_to_critical"] is bool:
		return "Damage dice policy apply_to_critical must be Boolean."
	if int(value.get("remove", 0)) == 0 and int(value.get("maximize", 0)) == 0:
		return "Damage dice policy must remove or maximize at least one die."
	return ""

static func damage_multiplier_error(value: Variant) -> String:
	if not value is Dictionary or value.is_empty():
		return "Damage result multiplier must be a nonempty object."
	for field in value:
		if field not in ["numerator", "denominator", "rounding", "exclude_critical"]:
			return "Damage result multiplier contains unsupported field '%s'." % str(field)
	if not _integer(value.get("numerator", null), 0, 20) or not _integer(value.get("denominator", 1), 1, 20) or str(value.get("rounding", "floor")) not in ["floor", "ceil", "nearest"]:
		return "Damage result multiplier requires an integer numerator, positive denominator and supported rounding."
	if value.has("exclude_critical") and not value["exclude_critical"] is bool:
		return "Damage result multiplier exclude_critical must be Boolean."
	return ""

static func healing_reroll_policy_error(value: Variant) -> String:
	if not value is Dictionary or value.is_empty(): return "Healing reroll policy must be a nonempty object."
	for field in value:
		if field not in ["count", "selection", "keep", "sides", "cost"]: return "Healing reroll policy contains unsupported field '%s'." % str(field)
	if not _integer(value.get("count", null), 1, 20): return "Healing reroll count must be an integer from 1 through 20."
	if str(value.get("selection", "lowest")) not in ["lowest", "highest"]: return "Healing reroll selection must be lowest or highest."
	if str(value.get("keep", "new")) not in ["new", "higher", "lower"]: return "Healing reroll keep must be new, higher or lower."
	if value.has("sides") and value["sides"] not in [4, 6, 8, 10, 12, 20]: return "Healing reroll sides must be a supported die size."
	if value.has("cost"):
		var cost: Variant = value["cost"]
		if not cost is Dictionary or cost.size() != 2 or not cost.has("source_instance_id") or not cost.has("amount") or not cost["source_instance_id"] is String or str(cost["source_instance_id"]).is_empty() or not _integer(cost["amount"], 1, 100):
			return "Healing reroll cost requires an exact source_instance_id and amount from 1 through 100."
	return ""

const SOURCE_END_EVENTS := ["attack", "cast", "movement", "status", "equipment", "range", "damage"]
const SOURCE_END_RULE_FIELDS := ["event", "actor", "school", "spell_id", "action", "status", "equipment", "state", "paid_slot_level", "maximum_range_feet", "except_source_id"]

static func save_context_error(value: Variant) -> String:
	if not value is Dictionary or value.size() != 3:
		return "save_context requires cause_id, purpose_id, and origin_effect_id."
	for field in ["cause_id", "purpose_id", "origin_effect_id"]:
		var token: Variant = value.get(field, null)
		if not token is String or not str(token).is_valid_identifier() or str(token) != str(token).to_lower():
			return "save_context.%s must be a lowercase identifier." % field
	return ""

static func uses(spell: Dictionary) -> bool:
	return spell.get("execution", "") == "shared"

static func _validate_single_effect(effect: Variant) -> String:
	if not effect is Dictionary or effect.get("type", "") not in EFFECTS:
		return "Unsupported shared effect operation."
	var kind := str(effect["type"])
	var allowed := ["type", "on_spell_hit", "on_failed_save", "rider_by_outcome", "when"]
	if effect.has("when") and not effect["when"] is Dictionary: return "Shared effect when must be a predicate object."
	if kind in ["heal", "temporary_hp"]:
		allowed.append_array(["value", "ability_bonus_from_caster", "dice_policy", "result_multiplier", "reroll_policy"])
		if not _formula(effect.get("value")) and not effect.get("value") is Dictionary: return "Shared healing/temporary HP requires a valid value."
		if effect.has("ability_bonus_from_caster") and not effect["ability_bonus_from_caster"] is bool: return "ability_bonus_from_caster must be Boolean."
		if effect.has("dice_policy"):
			var dice_error := damage_dice_policy_error(effect["dice_policy"])
			if not dice_error.is_empty(): return dice_error
			if effect["dice_policy"].has("apply_to_critical"): return "Healing dice policies cannot declare apply_to_critical."
		if effect.has("reroll_policy"):
			if kind != "heal": return "Authored healing rerolls are supported only for heal effects."
			if effect.get("value") is Dictionary: return "Authored healing rerolls require a dice expression."
			var reroll_error := healing_reroll_policy_error(effect["reroll_policy"])
			if not reroll_error.is_empty(): return reroll_error
		if effect.has("result_multiplier"):
			var multiplier_error := damage_multiplier_error(effect["result_multiplier"])
			if not multiplier_error.is_empty(): return multiplier_error
			if effect["result_multiplier"].has("exclude_critical"): return "Healing result multipliers cannot declare exclude_critical."
	elif kind == "grant_source_benefits":
		if effect.size() != 2: return "Source benefit grants accept only type and benefits."
		allowed.append("benefits")
		var error := SourceBenefitRules.benefits_error(effect.get("benefits"))
		if not error.is_empty(): return error
	elif kind == "create_actor":
		for key in effect:
			if str(key) not in ["type", "template", "placement", "options", "count_choice", "mix", "material_targets", "end_aftermath"]: return "Created actor effects accept only type, template, options, count_choice, mix, material_targets, end_aftermath and placement."
		allowed.append_array(["template", "placement", "options", "count_choice", "mix", "material_targets", "end_aftermath"])
		if effect.has("end_aftermath"):
			var aftermath_error := SourceEndAftermathRules.validate(effect.end_aftermath)
			if not aftermath_error.is_empty(): return aftermath_error
		var options_error := CreatedActorRules.options_error(effect) # Batch 054: S-155.
		if not options_error.is_empty(): return options_error
		var material_error := MaterialTargetRules.error(effect) # Batch 059: S-155.
		if not material_error.is_empty(): return material_error
		var template_error := CreatedActorRules.template_error(effect.get("template"))
		if not template_error.is_empty(): return template_error
		if effect.has("placement"):
			var placement_error := PlacementRules.policy_error(effect.placement) # Batch 053: S-122.
			if not placement_error.is_empty(): return placement_error
	elif kind == "bind_tether":
		allowed.append_array(["condition", "range_hexes", "escape", "capacity", "rescue", "hp", "anchor"]) # S-168/169 object anchors reuse existing room records.
		var tether_error := TetherRules.effect_error(effect)
		if not tether_error.is_empty(): return tether_error
	elif kind == "suppress_item_magic":
		allowed.append_array(["properties", "mode"])
		var magic_error := MagicPropertyRules.effect_error(effect)
		if not magic_error.is_empty(): return magic_error
	elif kind == "actor_projection":
		allowed.append_array(["forms", "retain", "equipment"])
		var projection_error := ActorProjectionRules.effect_error(effect)
		if not projection_error.is_empty(): return projection_error
	elif kind == "grant_damage_link":
		if effect.size() != 2: return "Damage link grants accept only type and policy."
		allowed.append("policy")
		var link_error := DamageLinkRules.link_error(effect.get("policy"))
		if not link_error.is_empty(): return link_error
	elif kind == "grant_damage_response":
		if effect.size() != 2: return "Damage response grants accept only type and policy."
		allowed.append("policy")
		var response_error := DamageResponseRules.policy_error(effect.get("policy"))
		if not response_error.is_empty(): return response_error
	elif kind in ["grant_condition", "remove_condition"]:
		allowed.append("condition")
		if effect.get("condition", "") not in CONDITIONS: return "Unsupported shared condition."
	else:
		allowed.append_array(["shape", "radius", "size"])
		if effect.get("shape", "") not in ["sphere", "cone", "cube"]: return "Unsupported shared area shape."
		var geometry_key := "radius" if effect["shape"] == "sphere" else "size"
		if not _integer(effect.get(geometry_key), 1, 100): return "Shared areas require the shape's radius/size in hexes."
	for key in effect:
		if key not in allowed: return "Unsupported field '%s' for shared %s." % [key, kind]
	for gate in ["on_spell_hit", "on_failed_save"]:
		if effect.has(gate) and not effect[gate] is bool: return "Shared effect gates must be Boolean."
	if effect.has("rider_by_outcome"):
		var map_error := validate_outcome_map(effect["rider_by_outcome"], ["hit", "miss"], "rider_by_outcome", true)
		if not map_error.is_empty():
			map_error = validate_outcome_map(effect["rider_by_outcome"], ["success", "failure"], "rider_by_outcome", true)
		if not map_error.is_empty(): return map_error
	return ""

static func validate_outcome_map(value: Variant, outcomes: Array, label: String, boolean_values: bool = false) -> String:
	if not value is Dictionary or value.size() != outcomes.size():
		return "%s must explicitly map every outcome: %s." % [label, str(outcomes)]
	for outcome in outcomes:
		if not value.has(outcome): return "%s is missing '%s'." % [label, outcome]
		var entry: Variant = value[outcome]
		if boolean_values:
			if not entry is bool: return "%s values must be Boolean." % label
		elif not ((entry is int or entry is float) and not entry is bool and is_finite(float(entry)) and float(entry) >= 0.0 and float(entry) <= 1.0):
			return "%s values must be finite scales from 0 through 1." % label
	for key in value:
		if not outcomes.has(str(key)): return "%s has unsupported outcome '%s'." % [label, str(key)]
	return ""

static func outcome_domain_for_delivery(attack: bool) -> Array:
	return ["hit", "miss"] if attack else ["success", "failure"]

static func _apply_authored_healing_rerolls(caster: Character, details: Dictionary, policy: Dictionary) -> Dictionary:
	var candidates: Array[Dictionary] = []
	var dice := Dice.selectable_dice(details)
	for index in dice.size():
		var die: Dictionary = dice[index]
		if not policy.has("sides") or int(die.get("sides", 0)) == int(policy["sides"]):
			candidates.append({"index": index, "value": int(die.get("value", 0))})
	var selection := str(policy.get("selection", "lowest"))
	candidates.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		if int(left.value) == int(right.value): return int(left.index) < int(right.index)
		return int(left.value) < int(right.value) if selection == "lowest" else int(left.value) > int(right.value)
	)
	var selected: Array[int] = []
	for candidate in candidates.slice(0, mini(int(policy.get("count", 1)), candidates.size())):
		selected.append(int(candidate.index))
	if selected.is_empty(): return {"details": details, "receipt": {"selected": [], "rerolls": [], "paid": false}}
	var cost: Dictionary = policy.get("cost", {})
	var payment_receipt: Dictionary = {}
	if not cost.is_empty():
		var payment := ResourcePoolRules.spend(caster, str(cost.get("source_instance_id", "")), int(cost.get("amount", 0)))
		if not bool(payment.get("success", false)):
			return {"details": details, "receipt": {"selected": [], "rerolls": [], "paid": false, "payment_refused": true, "source_instance_id": str(cost.get("source_instance_id", "")), "cost_amount": int(cost.get("amount", 0)), "payment": payment.duplicate(true)}}
		payment_receipt = payment.duplicate(true)
	var rerolled := Dice.reroll_selected_dice(details, selected, int(policy.get("count", 1)), caster, str(policy.get("keep", "new")))
	if not bool(rerolled.get("success", false)):
		return {"details": details, "receipt": {"selected": [], "rerolls": [], "paid": not cost.is_empty(), "source_instance_id": str(cost.get("source_instance_id", "")), "cost_amount": int(cost.get("amount", 0)), "payment": payment_receipt}}
	return {"details": rerolled.details, "receipt": {"selected": selected, "rerolls": rerolled.get("rerolls", []), "paid": not cost.is_empty(), "source_instance_id": str(cost.get("source_instance_id", "")), "cost_amount": int(cost.get("amount", 0)), "payment": payment_receipt}}

static func authored_damage_scale(payload: Dictionary, outcome: String, default_scale: float) -> float:
	var mapping: Variant = payload.get("damage_scale_by_outcome", {})
	return float(mapping[outcome]) if mapping is Dictionary and mapping.has(outcome) else default_scale

static func record_damage_scale(result: Dictionary, payload: Dictionary, outcome: String, scale: float) -> void:
	if payload.has("damage_scale_by_outcome"):
		result["damage_scale_decision"] = {"outcome": outcome, "scale": scale, "source": "authored_map", "rounding": "floor_after_bonus_before_typed_settlement"}

static func _steps_error(spell: Dictionary) -> String:
	var raw_steps: Variant = spell.get("steps", [])
	if raw_steps is Array:
		for step in raw_steps:
			if not step is Dictionary:
				continue
			if step.has("damage_dice_policy"):
				var dice_error := damage_dice_policy_error(step["damage_dice_policy"])
				if not dice_error.is_empty(): return dice_error
			if step.has("damage_result_multiplier"):
				var multiplier_error := damage_multiplier_error(step["damage_result_multiplier"])
				if not multiplier_error.is_empty(): return multiplier_error
			if step.has("physical_requirements"):
				var phys_error := PhysicalFactsRules.physical_requirements_error(step["physical_requirements"])
				if not phys_error.is_empty(): return phys_error
			if step.has("spatial_requirements"):
				var space_error := PhysicalFactsRules.spatial_requirements_error(step["spatial_requirements"])
				if not space_error.is_empty(): return space_error
	var err := SharedStepExecutor.validate_steps(spell.get("steps", []), "spell")
	if not err.is_empty():
		return err
	var has_condition_grant := false
	for step in spell.get("steps", []):
		if step is Dictionary and step.has("effects") and step["effects"] is Array:
			for eff in step["effects"]:
				if eff is Dictionary and eff.get("type", "") == "grant_condition":
					has_condition_grant = true
	if has_condition_grant and not spell.has("duration_seconds"):
		return "Condition grants require duration_seconds."
	return ""

static func content_error(spell: Dictionary) -> String:
	if spell.has("containment_targeting"):
		var containment_error := ContainmentRules.targeting_error(spell.containment_targeting)
		if not containment_error.is_empty(): return containment_error
	if has_effect(spell, "grant_source_benefits") or has_effect(spell, "create_actor") or has_effect(spell, "actor_projection") or has_effect(spell, "suppress_item_magic"):
		if spell.has("steps") or spell.has("repeat_save") or spell.get("target", "") != "self" or spell.has("save") or spell.get("attack_type", "none") != "none" or spell.has("damage") or spell.get("effects", []).size() != 1:
			return "Source carriers require a flat automatic self-cast with one grant effect."
	if spell.get("execution", "") != "shared":
		return "Unknown spell execution; use 'shared' for ordinary JSON spells."
	for key in spell:
		if str(key) not in FIELDS and not str(key).begins_with("_"):
			return "Unsupported shared spell field '%s'." % str(key)
	var input_error := SpellFormulaInputs.content_error(spell)
	if not input_error.is_empty(): return input_error
	if spell.has("save_context"):
		var context_error := save_context_error(spell["save_context"])
		if not context_error.is_empty(): return context_error
	if str(spell.get("id", "")).is_empty() or str(spell.get("name", "")).is_empty():
		return "Shared spells require an id and name."
	if not _integer(spell.get("level"), 0, 9) or not _integer(spell.get("range"), 0, 1000):
		return "Shared spells require integer level (0-9) and range in hexes (0-1000)."
	if spell.has("source_end_rules"):
		var end_error := source_end_rules_error(spell.get("source_end_rules"))
		if not end_error.is_empty(): return end_error
	if spell.has("end_aftermath"):
		var aftermath_error := SourceEndAftermathRules.validate(spell["end_aftermath"])
		if not aftermath_error.is_empty(): return aftermath_error
	if spell.has("damage_dice_policy"):
		var dice_error := damage_dice_policy_error(spell["damage_dice_policy"])
		if not dice_error.is_empty(): return dice_error
	if spell.has("damage_result_multiplier"):
		var multiplier_error := damage_multiplier_error(spell["damage_result_multiplier"])
	if spell.get("casting_time", "action") not in ["action", "bonus_action", "reaction"] or not str(spell.get("trigger", "")).is_empty():
		return "Shared spells support ordinary Action, Bonus Action or Reaction casts."
	if spell.get("casting_time", "action") == "reaction" and not spell.has("cancellation_rule") and not spell.has("stopping_cost_policy") and not spell.has("reaction_trigger"):
		return "Shared reaction spells require a cancellation_rule, stopping_cost_policy or reaction_trigger." # Batch 065: or a data-declared trigger.
	if spell.has("interruption_policy"):
		if not spell["interruption_policy"] is String: return "interruption_policy must be commit or refund."
		var p_err := CastInterruptionRules.settlement_policy_error(spell["interruption_policy"])
		if not p_err.is_empty(): return p_err
	if spell.has("failure_policy"):
		if not spell["failure_policy"] is String: return "failure_policy must be commit or refund."
		var p_err := CastInterruptionRules.settlement_policy_error(spell["failure_policy"])
		if not p_err.is_empty(): return p_err
	if spell.has("empty_effect_policy"):
		if not spell["empty_effect_policy"] is String: return "empty_effect_policy must be commit or refund."
		var p_err := CastInterruptionRules.settlement_policy_error(spell["empty_effect_policy"])
		if not p_err.is_empty(): return p_err
	if spell.has("cast_settlement"):
		var p_err := CastInterruptionRules.settlement_policy_error(spell["cast_settlement"])
		if not p_err.is_empty(): return p_err
	if spell.has("cancellation_rule"):
		var c_err := CastInterruptionRules.cancellation_rule_error(spell["cancellation_rule"])
		if not c_err.is_empty(): return c_err
	if spell.has("stopping_cost_policy"):
		var s_err := CastInterruptionRules.stopping_cost_policy_error(spell["stopping_cost_policy"])
		if not s_err.is_empty(): return s_err
	if spell.has("incoming_negation_rule"):
		var n_err := CastInterruptionRules.incoming_negation_rule_error(spell["incoming_negation_rule"])
		if not n_err.is_empty(): return n_err
	if spell.has("physical_requirements"):
		var phys_err := PhysicalFactsRules.physical_requirements_error(spell["physical_requirements"])
		if not phys_err.is_empty(): return phys_err
	if spell.has("spatial_requirements"):
		var space_err := PhysicalFactsRules.spatial_requirements_error(spell["spatial_requirements"])
		if not space_err.is_empty(): return space_err
	if spell.has("save_exit_placement"):
		var exit_error := SaveExitPlacementRules.policy_error(spell["save_exit_placement"])
		if not exit_error.is_empty(): return exit_error
		if spell.has("steps") or spell.get("target", "single") != "single" or not spell.has("save") or spell.get("attack_type", "none") != "none" or spell.has("targets_objects") or spell.has("repeat_save") or spell.has("repeat_save_schedule") or spell.has("repeat_save_stages") or spell.has("recipient_exemption_choice"):
			return "save_exit_placement currently supports only a flat single-target saving throw without repeat saves or recipient exemptions."
	if spell.has("attack_unit_substitution"):
		var substitution: Variant = spell["attack_unit_substitution"]
		if spell.get("casting_time", "action") != "action" or not substitution is Dictionary or substitution.size() != 1 or not _integer(substitution.get("units", null), 1, 2):
			return "attack_unit_substitution requires an Action spell and an object containing units 1 or 2."
	if spell.get("target", "single") not in ["single", "self", "multi", "area", "cone"]:
		return "Unsupported shared target selector."
	if spell.has("steps"):
		if spell.has("damage_reductions") or spell.has("damage_bypasses"):
			return "Ordered damage policies must be declared on their exact damage step."
		if spell.has("damage_scale_by_outcome"):
			return "Ordered damage outcome maps must belong to an attack or save step."
		if spell.has("recipient_exemption_choice"):
			return "Recipient exemption choices must be declared on a flat shared spell."
		var steps_err := _steps_error(spell)
		if not steps_err.is_empty():
			return steps_err
		var contains_save_step := false
		for step in spell.get("steps", []):
			if step is Dictionary and str(step.get("type", "")) == "save": contains_save_step = true
			if step is Dictionary and step.has("save_context"):
				if str(step.get("type", "")) != "save": return "save_context may only be declared on a save step."
				var step_context_error := save_context_error(step["save_context"])
				if not step_context_error.is_empty(): return step_context_error
		if spell.has("save_context") and not contains_save_step:
			return "Spell-level save_context requires at least one save step."
	else:
		if spell.has("save_context") and not spell.has("save"):
			return "save_context requires saving-throw delivery."
		if spell.get("attack_type", "none") not in ["none", "ranged_spell", "melee_spell"]:
			return "Unsupported shared attack delivery."
		if spell.has("save") and spell["save"] not in ABILITIES:
			return "Shared saving throws require an ability."
		if spell.has("save") and spell.get("attack_type", "none") != "none":
			return "Choose either attack or saving-throw delivery."
		if spell.has("recipient_exemption_choice"):
			var exemption: Variant = spell.get("recipient_exemption_choice")
			var context: Dictionary = spell.get("save_context", {})
			if not exemption is Dictionary or exemption.size() != 7 or not str(exemption.get("selection_id", "")).is_valid_identifier() or not _integer(exemption.get("selection_limit", null), 1, 20) or str(exemption.get("stage", "")) != "before_target_saves":
				return "recipient_exemption_choice requires an ID, bounded selection limit and before_target_saves stage."
			for field in exemption:
				if field not in ["selection_id", "selection_limit", "stage", "save_ability", "cause_id", "purpose_id", "origin_effect_id"]: return "recipient_exemption_choice contains an unsupported field."
			if not spell.has("save") or str(exemption.get("save_ability", "")).to_upper() != str(spell.get("save", "")).to_upper() or str(exemption.get("cause_id", "")) != str(context.get("cause_id", "")) or str(exemption.get("purpose_id", "")) != str(context.get("purpose_id", "")) or str(exemption.get("origin_effect_id", "")) != str(context.get("origin_effect_id", "")):
				return "recipient_exemption_choice eligibility must match the spell's exact saving-throw context."
		if spell.has("damage_scale_by_outcome"):
			if not spell.has("save") and spell.get("attack_type", "none") == "none": return "damage_scale_by_outcome requires attack or save delivery."
			if not spell.has("damage"): return "damage_scale_by_outcome requires a damage payload."
			var scale_error := validate_outcome_map(spell["damage_scale_by_outcome"], outcome_domain_for_delivery(spell.get("attack_type", "none") != "none"), "damage_scale_by_outcome")
			if not scale_error.is_empty(): return scale_error
		if spell.has("damage") and (not _formula(spell["damage"]) or spell.get("damage_type", "") not in DataLoader.VALID_DAMAGE_TYPES):
			return "Shared damage requires a valid formula and damage type."
		if spell.has("component_id") and (not spell["component_id"] is String or str(spell["component_id"]).is_empty()):
			return "Damage component_id must be a nonempty string."
		if spell.has("damage_reductions") or spell.has("damage_bypasses"):
			if not spell.has("damage"):
				return "Flat damage policies require a typed damage payload."
			var policy_ids: Array[String] = [str(spell.get("component_id", "%s:1" % str(spell.get("damage_type", ""))))]
			var damage_policy_error := SharedStepExecutor.validate_damage_policy(spell.get("damage_reductions", []), spell.get("damage_bypasses", []), policy_ids)
			if not damage_policy_error.is_empty(): return damage_policy_error
		if spell.get("attack_type", "none") != "none" and not spell.has("damage"):
			return "Shared attack spells require a damage payload."
	# These need dedicated handlers; a shared label must never enable a no-op.
	for key in ["damage_per_dart", "damage_per_ray", "damage_components", "summoned_creature", "delayed_damage", "condition_on_failed_save", "area_point_count"]:
		if spell.has(key):
			return "Shared spells do not support '%s'; use a dedicated handler." % key
	for key in ["concentration", "half_on_save", "requires_target_sight", "targets_objects", "ignites_objects", "end_on_target_damage", "end_on_any_damage", "end_on_party_damage", "ritual", "material_component_consumed", "ignore_cover_on_save"]:
		if spell.has(key) and not spell[key] is bool:
			return "Shared '%s' must be Boolean." % key
	if spell.has("duration_seconds") and not _integer(spell["duration_seconds"], 1, 86400):
		return "Shared duration_seconds must be 1-86400."
	if spell.has("repeat_save") and spell["repeat_save"] not in ABILITIES:
		return "Shared repeat_save requires an ability."
	if spell.has("repeat_save_schedule") and str(spell["repeat_save_schedule"]) not in ["target_turn_end", "elapsed_seconds"]:
		return "repeat_save_schedule must be target_turn_end or elapsed_seconds."
	if spell.has("repeat_save_schedule") and not spell.has("repeat_save"):
		return "Repeat-save schedules require a repeat_save ability."
	if spell.has("repeat_save_schedule") and str(spell["repeat_save_schedule"]) == "elapsed_seconds" and not _integer(spell.get("repeat_save_interval_seconds", null), 1, 86400):
		return "Elapsed repeat saves require a 1-86400 second interval."
	if spell.has("repeat_save_interval_seconds") and (not spell.has("repeat_save_schedule") or str(spell.get("repeat_save_schedule", "")) != "elapsed_seconds" or not _integer(spell["repeat_save_interval_seconds"], 1, 86400)):
		return "repeat_save_interval_seconds requires an elapsed_seconds schedule."
	if spell.has("repeat_save_stages"):
		var stages_error := repeat_save_stages_error(spell["repeat_save_stages"])
		if not stages_error.is_empty(): return stages_error
		if not spell.has("repeat_save"): return "Repeat-save stages require a repeat_save ability."
		var initial_condition := ""
		for effect in spell.get("effects", []):
			if effect is Dictionary and str(effect.get("type", "")) == "grant_condition":
				initial_condition = str(effect.get("condition", ""))
				break
		if initial_condition.is_empty() or initial_condition != str(spell["repeat_save_stages"][0].get("condition", "")):
			return "The first repeat-save stage must match the spell's granted condition."
	if spell.has("repeat_save_dc_progression"):
		var progression: Variant = spell["repeat_save_dc_progression"]
		if not progression is Dictionary or progression.is_empty(): return "repeat_save_dc_progression must be a nonempty object."
		for key in progression:
			if key not in ["increase_on", "amount", "maximum", "reset_on_success"]: return "Unsupported repeat-save DC progression field '%s'." % str(key)
		if str(progression.get("increase_on", "")) not in ["attempt", "failure"] or not _integer(progression.get("amount", null), 1, 20) or not _integer(progression.get("maximum", null), 0, 100) or progression.get("reset_on_success", null) is not bool:
			return "repeat_save_dc_progression requires increase_on, amount, maximum and reset_on_success."
		if not spell.has("repeat_save"): return "Repeat-save DC progression requires a repeat_save ability."
	if not spell.get("effects", []) is Array or not spell.get("upcast", {}) is Dictionary or not spell.get("scaling", {}) is Dictionary:
		return "Shared effects must be an array; upcast and scaling must be objects."
	for threshold in spell.get("scaling", {}):
		if int(spell["level"]) != 0 or not str(threshold).is_valid_int() or int(threshold) < 1 or int(threshold) > 20 or not _formula(spell["scaling"][threshold]):
			return "Invalid shared damage scaling."
	for key in spell.get("upcast", {}):
		if key in ["damage_per_level", "healing_dice_per_level"]:
			if not spell["upcast"][key] is String or not _dice_formula(spell["upcast"][key]): return "Shared upcast dice must be a plain dice expression."
		elif key in ["starting_level", "levels_per_increment", "additional_targets_per_level", "temporary_hp_per_level", "healing_per_level"]:
			if not _integer(spell["upcast"][key], 0, 100): return "Invalid shared upcast amount."
		else:
			return "Unsupported shared upcast operation '%s'." % key
	var upcast: Dictionary = spell.get("upcast", {})
	if (upcast.has("damage_per_level") or not spell.get("scaling", {}).is_empty()) and not spell.has("damage") and not spell.has("steps"):
		return "Damage scaling requires a damage payload."
	if (upcast.has("healing_per_level") or upcast.has("healing_dice_per_level")) and not has_effect(spell, "heal"):
		return "Healing upcasts require a healing payload."
	if upcast.has("temporary_hp_per_level") and not has_effect(spell, "temporary_hp"):
		return "Temporary HP upcasts require a Temporary HP payload."
	if upcast.has("healing_per_level") and upcast.has("healing_dice_per_level"):
		return "Choose fixed or dice healing upcasts, not both."
	if (upcast.has("healing_per_level") or upcast.has("healing_dice_per_level") or upcast.has("temporary_hp_per_level")) and int(upcast.get("levels_per_increment", 1)) != 1:
		return "Healing and Temporary HP upcasts increment every slot level."
	if spell.has("base_targets") and not _integer(spell["base_targets"], 1, 100):
		return "Shared base_targets must be 1-100."
	for key in ["area_radius", "cone_size"]:
		if spell.has(key) and not _integer(spell[key], 1, 100): return "Shared geometry must use positive hex counts."
	for key in ["target_creature_types", "target_creature_type_exclusions", "target_sizes", "components"]:
		if spell.has(key) and (not spell[key] is Array or not spell[key].all(func(value): return value is String)):
			return "Shared '%s' must be an array of strings." % key
	var has_payload: bool = spell.has("damage") or spell.has("steps") or spell.has("cancellation_rule") or spell.has("stopping_cost_policy") or spell.has("incoming_negation_rule") or spell.has("physical_requirements") or spell.has("spatial_requirements") or (str(spell.get("empty_effect_policy", "")) in ["commit", "refund"])
	var timed := false
	var areas := 0
	for effect in spell.get("effects", []):
		if effect is Dictionary and effect.has("when"): return "Shared effect predicates must be inside ordered steps."
		if effect is Dictionary and effect.get("value") is Dictionary: return "Shared formula objects must be inside ordered steps."
		var eff_err := _validate_single_effect(effect)
		if not eff_err.is_empty(): return eff_err
		if effect is Dictionary and effect.has("rider_by_outcome"):
			if spell.has("steps"): return "Ordered rider outcome maps must belong to an attack or save step."
			if not spell.has("save") and spell.get("attack_type", "none") == "none": return "rider_by_outcome requires attack or save delivery."
			var domain := outcome_domain_for_delivery(spell.get("attack_type", "none") != "none")
			var rider_error := validate_outcome_map(effect["rider_by_outcome"], domain, "rider_by_outcome", true)
			if not rider_error.is_empty(): return rider_error
		var kind := str(effect.get("type", ""))
		if kind == "bind_tether":
			if (str(effect.get("anchor", "character")) != "object" and not bool(spell.get("concentration", false))) or spell.get("target", "single") not in ["single", "single_enemy", "single_ally"]: return "Character tethers require concentration; object tethers need an individual creature target."
			if int(spell.get("base_targets", 1)) > int(effect.get("capacity", 1)): return "Tether base_targets exceeds its capacity."
		if kind in ["grant_condition", "grant_source_benefits", "grant_damage_link", "grant_damage_response", "create_actor", "actor_projection", "suppress_item_magic", "bind_tether"]: timed = true
		elif kind == "area_selection": areas += 1
		has_payload = has_payload or kind != "area_selection"
		if bool(effect.get("on_spell_hit", false)) and spell.get("attack_type", "none") == "none" and not spell.has("steps"): return "on_spell_hit requires attack delivery."
		if bool(effect.get("on_failed_save", false)) and not spell.has("save") and not spell.has("steps"): return "on_failed_save requires save delivery."
	if not has_payload: return "Shared spells require an executable payload."
	if areas > 1 or (areas > 0 and spell.get("target", "single") not in ["area", "cone"]):
		return "Shared area geometry requires one area/cone selector."
	if spell.get("target", "single") in ["area", "cone"] and not has_effect(spell, "area_selection"):
		return "Shared area spells require an area_selection effect."
	if timed and not spell.has("duration_seconds"): return "Condition grants require duration_seconds."
	if (bool(spell.get("concentration", false)) or spell.has("repeat_save")) and not timed: return "Concentration/repeat saves require a timed condition grant."
	return ""

static func repeat_save_stages_error(value: Variant) -> String:
	if not value is Array or value.is_empty() or value.size() > 8:
		return "Repeat-save stages require one through eight stage records."
	for stage in value:
		if not stage is Dictionary or stage.is_empty(): return "Each repeat-save stage must be an object."
		for field in stage:
			if str(field) not in ["condition", "successes_required", "minimum_margin", "on_failure", "reset_successes_on_failure"]: return "Unsupported repeat-save stage field '%s'." % str(field)
		if str(stage.get("condition", "")) not in CONDITIONS or not _integer(stage.get("successes_required", null), 1, 20) or not _integer(stage.get("minimum_margin", 0), 0, 100) or str(stage.get("on_failure", "stay")) not in ["stay", "advance", "end"] or (stage.has("reset_successes_on_failure") and not stage["reset_successes_on_failure"] is bool):
			return "Repeat-save stage requires a supported condition, success count, margin and failure route."
	return ""

static func source_end_rules_error(value: Variant) -> String:
	if not value is Array or value.size() > 16: return "source_end_rules must be an array of at most 16 rules."
	for rule in value:
		if not rule is Dictionary or str(rule.get("event", "")) not in SOURCE_END_EVENTS: return "Each source end rule requires a supported event."
		for field in rule:
			if str(field) not in SOURCE_END_RULE_FIELDS: return "Source end rule contains an unsupported field."
		if str(rule.get("actor", "any")) not in ["any", "caster", "recipient"]: return "Source end rule actor must be any, caster or recipient."
		for field in ["school", "spell_id", "action", "status", "equipment", "state", "except_source_id"]:
			if rule.has(field) and (not rule[field] is String or str(rule[field]).is_empty()): return "Source end rule '%s' must be a non-empty string." % field
		if rule.has("paid_slot_level") and not _integer(rule["paid_slot_level"], 0, 9): return "Source end rule paid_slot_level must be 0-9."
		if rule.has("maximum_range_feet") and not _integer(rule["maximum_range_feet"], 0, 10000): return "Source end rule maximum_range_feet must be 0-10000."
		if rule.has("except_source_id") and (str(rule.get("event", "")) != "damage" or (str(rule["except_source_id"]) != "this_source" and not str(rule["except_source_id"]).begins_with("spell:"))): return "except_source_id is a damage-only exact source exception."
		if (rule.has("school") or rule.has("spell_id") or rule.has("paid_slot_level")) and str(rule.get("event", "")) != "cast": return "School, spell_id and paid_slot_level filters require a cast event."
		if rule.has("action") and str(rule.get("event", "")) != "attack": return "The action filter requires an attack event."
		if rule.has("status") and str(rule.get("event", "")) != "status": return "The status filter requires a status event."
		if (rule.has("equipment") or rule.has("state")) and str(rule.get("event", "")) != "equipment": return "Equipment and state filters require an equipment event."
		if rule.has("maximum_range_feet") and str(rule.get("event", "")) != "range": return "maximum_range_feet requires a range event."
	return ""


## A prevention bypass may cross the spell-level Resilient Sphere gate only
## for an ordered shared spell whose steps do nothing beyond typed damage.
## Component settlement still applies prevention to every unselected component.
static func allows_damage_prevention_bypass(spell: Dictionary) -> bool:
	if not uses(spell):
		return false
	var top_effects: Variant = spell.get("effects", [])
	if not top_effects is Array or not top_effects.is_empty():
		return false
	for key in ["damage", "damage_type", "attack_type", "save", "half_on_save", "concentration", "duration", "repeat_save", "recipient_exemption_choice"]:
		if spell.has(key):
			return false
	var steps: Variant = spell.get("steps", [])
	if not steps is Array or steps.is_empty():
		return false
	var has_prevention_bypass := false
	for step_variant in steps:
		if not step_variant is Dictionary:
			return false
		var step: Dictionary = step_variant
		if str(step.get("type", "")) not in ["save", "attack", "damage"]:
			return false
		var components: Variant = step.get("damage_components", [])
		if not components is Array or components.is_empty() or step.has("effects"):
			return false
		for key in step:
			if str(key) not in ["id", "type", "gate", "gate_step", "save", "attack_type", "half_on_save", "damage_components", "damage_reductions", "damage_bypasses"]:
				return false
		for bypass in step.get("damage_bypasses", []):
			if bypass is Dictionary and "prevention" in bypass.get("layers", []):
				has_prevention_bypass = true
	return has_prevention_bypass

## Actor-only reductions must already be available before the cast pays.
## Settlement still evaluates live values after any pending roll choice.
static func damage_policy_availability_error(spell: Dictionary, caster: Character) -> String:
	if not uses(spell): return ""
	var payloads: Array = [spell]
	payloads.append_array(spell.get("steps", []))
	for payload in payloads:
		for reduction in payload.get("damage_reductions", []):
			var amount: Variant = reduction.get("amount", 0)
			if amount is Dictionary and not SharedStepExecutor.evaluate_actor_formula(amount, caster).get("success", false):
				return "The authored damage reduction formula is unavailable."
	return ""


static func _integer(value: Variant, minimum: int, maximum: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floor(float(value)) and float(value) >= minimum and float(value) <= maximum

static func _formula(value: Variant) -> bool:
	if value is int or value is float: return _integer(value, 0, 999)
	if not value is String: return false
	var expression := RegEx.new()
	expression.compile("^([0-9]{1,3}|[1-9][0-9]?d(4|6|8|10|12|20))([+][0-9]{1,3})?$")
	return expression.search(str(value).replace(" ", "")) != null

static func _dice_formula(value: String) -> bool:
	var expression := RegEx.new()
	expression.compile("^[1-9][0-9]?d(4|6|8|10|12|20)$")
	return expression.search(value.replace(" ", "")) != null

static func has_effect(spell: Dictionary, kind: String) -> bool:
	if not uses(spell): return false
	var effects: Variant = spell.get("effects", [])
	if effects is Array and effects.any(func(effect): return effect is Dictionary and effect.get("type", "") == kind):
		return true
	var steps: Variant = spell.get("steps", [])
	if not steps is Array: return false
	for step in steps:
		if step is Dictionary and step.get("effects", []) is Array and step.get("effects", []).any(func(effect): return effect is Dictionary and effect.get("type", "") == kind):
			return true
	return false

static func manages(spell: Dictionary) -> bool:
	return (has_effect(spell, "grant_condition") or has_effect(spell, "grant_source_benefits") or has_effect(spell, "grant_damage_link") or has_effect(spell, "grant_damage_response") or has_effect(spell, "create_actor") or has_effect(spell, "actor_projection") or has_effect(spell, "suppress_item_magic") or has_effect(spell, "bind_tether")) and content_error(spell).is_empty()

static func _create_step_cast(cast: SpellResolutionContext, target, step_spell: Dictionary) -> SpellResolutionContext:
	var step_cast := SpellResolutionContext.new()
	step_cast.caster = cast.caster
	step_cast.target = target
	step_cast.spell = step_spell
	step_cast.decisions = cast.decisions
	step_cast.spatial_host = cast.spatial_host
	step_cast.observers = cast.observers
	step_cast.slot_level = cast.slot_level
	step_cast.distance_feet = cast.distance_feet
	step_cast.effect_cast = cast.effect_cast
	# A step attack is a new resolver context for its target, but it is still
	# part of the exact parent cast/action and must retain those canonical IDs.
	step_cast.invocation_id = cast.invocation_id
	step_cast.spell_definition_id = cast.spell_definition_id
	step_cast.action_id = cast.action_id
	step_cast.action_invocation_id = cast.action_invocation_id
	step_cast.parent_source_id = cast.parent_source_id
	step_cast.item_definition_id = cast.item_definition_id
	step_cast.item_instance_id = cast.item_instance_id
	step_cast.item_copy_validated = cast.item_copy_validated
	step_cast.source_definition_id = cast.source_definition_id
	step_cast.source_instance_id = cast.source_instance_id
	step_cast.source_owner_id = cast.source_owner_id
	step_cast.originating_step_id = str(step_spell.get("_origin_effect_id", ""))
	step_cast.incoming_slot_spent = cast.incoming_slot_spent
	step_cast.incoming_slot_key = cast.incoming_slot_key
	step_cast.incoming_slot_pool_id = cast.incoming_slot_pool_id
	step_cast.has_damage_payload = step_spell.has("damage") or not step_spell.get("damage_components", []).is_empty()
	return step_cast

static func _resolve_steps(cast: SpellResolutionContext, start_step_index: int = 0, prior_state: Dictionary = {}) -> Dictionary:
	return SharedStepExecutor.execute_spell(cast, start_step_index, prior_state)


static func resume_pending_steps(caster: Character, target, settled_result: Dictionary, decisions: Dictionary, ordered_cont: Dictionary) -> Dictionary:
	return SharedStepExecutor.resume_spell_steps(caster, target, settled_result, decisions, ordered_cont)

static func resume_pending_occurrence(caster: Character, target, settled_result: Dictionary, decisions: Dictionary, ordered_cont: Dictionary, settlement: Dictionary = {}) -> Dictionary:
	return SharedStepExecutor.resume_spell_steps_occurrence(caster, target, settled_result, decisions, ordered_cont, settlement)

static func resolve(cast: SpellResolutionContext) -> Dictionary:
	if cast.spell.has("steps"):
		return _resolve_steps(cast)
	cast.has_damage_payload = cast.spell.has("damage") or not cast.spell.get("damage_components", []).is_empty()
	var result: Dictionary
	if cast.spell.has("save"):
		result = SpellSaveResolver.resolve(cast)
	elif cast.spell.get("attack_type", "none") != "none":
		result = SpellAttackResolver.resolve(cast)
	elif cast.has_damage_payload:
		var formula := SpellDamageRolls.spell_damage_formula(cast.caster, cast.spell, cast.slot_level)
		var roll := SpellDamageRolls._roll_spell_damage(cast.caster, formula, 1, cast.decisions, cast.spell.get("damage_dice_policy", {}))
		cast.decisions["damage_result_multiplier"] = cast.spell.get("damage_result_multiplier", {})
		cast.decisions["_shared_component_id"] = str(cast.spell.get("component_id", "%s:1" % str(cast.spell["damage_type"])))
		result = SpellDamageRolls._finish_spell_damage(cast.caster, cast.target, roll, CombatAction.spell_damage_bonus(cast.caster, cast.spell), 1.0, str(cast.spell["damage_type"]), cast.decisions, {"success": true, "hit": true, "effect_cast": cast.effect_cast, "message": "%s deals {damage} %s damage." % [cast.spell["name"], cast.spell["damage_type"]]}, 1, [], cast.spell.get("damage_reductions", []), cast.spell.get("damage_bypasses", []))
	else:
		result = {"success": true, "hit": true, "damage": 0, "effect_cast": cast.effect_cast, "message": str(cast.spell["name"]) + " resolves."}
	result["slot_level"] = cast.slot_level
	result["effect_cast"] = cast.effect_cast
	return apply(cast.caster, cast.target, cast.spell, result, cast.spatial_host)

static func apply_custom_effects(caster: Character, target, effects: Array, result: Dictionary, slot_level: int, step_results: Array = [], adapter: Object = null, spell: Dictionary = {}, host: SpellCastContext = null) -> Dictionary:
	if adapter != null:
		var context = adapter.get("cast")
		if context != null:
			if spell.is_empty(): spell = context.spell
			if host == null: host = context.spatial_host
	var messages: Array[String] = []
	var target_name: String = target.character_name if target is Character else str(target.get("name", "Target"))
	var outcome := ("hit" if bool(result.get("hit", false)) else "miss") if result.has("hit") else (("success" if bool(result.get("saved", false)) else "failure") if result.has("saved") else "")
	if effects.any(func(effect): return effect is Dictionary and effect.has("rider_by_outcome")):
		for effect in effects:
			if effect is Dictionary and effect.has("rider_by_outcome") and (outcome.is_empty() or not effect["rider_by_outcome"].has(outcome)):
				return {"success": false, "refused": true, "error": "Authored rider outcome is unavailable."}
	for effect in effects:
		if not effect is Dictionary: continue
		if effect.has("rider_by_outcome"):
			var eligible := bool(effect["rider_by_outcome"][outcome])
			var decisions: Array = result.get("rider_decisions", [])
			decisions.append({"effect": str(effect.get("type", "")), "outcome": outcome, "eligible": eligible, "source": "authored_map"})
			result["rider_decisions"] = decisions
			if not eligible: continue
		if bool(effect.get("on_spell_hit", false)) and not result.get("hit", false): continue
		if bool(effect.get("on_failed_save", false)) and result.get("saved", true): continue
		if effect.has("when") and (adapter == null or not SharedStepExecutor.evaluate_predicate(effect["when"], adapter, target, step_results)): continue
		match str(effect.get("type", "")):
			"heal", "temporary_hp":
				var formula_value = effect.get("value", "0")
				# JSON decodes integral numbers as floats; the dice parser expects
				# integer text rather than e.g. "5.0" for an accepted fixed value.
				var formula := str(int(formula_value)) if formula_value is int or formula_value is float else str(formula_value) if not formula_value is Dictionary else ""
				var amount := 0
				if formula_value is Dictionary:
					var evaluated := SharedStepExecutor.evaluate_formula(formula_value, adapter, target, step_results)
					if not result.has("formula_reads"): result["formula_reads"] = []
					result["formula_reads"].append({"formula":formula_value.duplicate(true), "receipt":evaluated.duplicate(true)})
					if not evaluated.get("success", false): continue
					amount = int(evaluated["value"])
				else:
					var rolled := Dice.parse_dice_details(formula, {}, caster, effect.get("dice_policy", {}))
					amount = int(rolled.get("final_total", 0))
					if effect.has("reroll_policy"):
						var reroll_result := {"details": rolled, "receipt": {"selected": [], "rerolls": [], "paid": false}}
						if SpellEffects.has_spell(target, "beacon_of_hope"):
							reroll_result["receipt"]["skipped_reason"] = "beacon_maximizes_healing"
						else:
							reroll_result = _apply_authored_healing_rerolls(caster, rolled, effect["reroll_policy"])
						rolled = reroll_result.get("details", rolled)
						amount = int(rolled.get("final_total", amount))
						var reroll_receipts: Array = result.get("healing_rerolls", [])
						reroll_receipts.append(reroll_result.get("receipt", {}).duplicate(true))
						result["healing_rerolls"] = reroll_receipts
					if effect["type"] == "heal":
						amount = SpellEffects.maximize_healing(target, amount, Dice.maximum_dice_string(formula, {}, effect.get("dice_policy", {})))
				if bool(effect.get("ability_bonus_from_caster", false)): amount += caster.ability_scores.get_ability_modifier(SpellPermissionRules.selected_ability(spell, caster.get_spellcasting_ability()))
				if effect.has("result_multiplier"):
					var multiplier: Dictionary = effect["result_multiplier"]
					var adjusted := Dice.apply_damage_multiplier(amount, int(multiplier.get("numerator", 1)), int(multiplier.get("denominator", 1)), str(multiplier.get("rounding", "floor")))
					if not adjusted.get("success", false): continue
					amount = int(adjusted.value)
				amount = maxi(0, amount)
				if effect["type"] == "temporary_hp":
					if target is Character: target.temp_hp = maxi(target.temp_hp, amount)
					else: target["temp_hp"] = maxi(int(target.get("temp_hp", 0)), amount)
					messages.append("%s gains %d Temporary Hit Points." % [target_name, amount])
				else:
					var healed := 0
					if target is Character: healed = target.heal(amount)
					elif not CombatAction.is_healing_suppressed(target):
						healed = mini(amount, maxi(0, int(target.get("max_hp", 0)) - int(target.get("current_hp", 0))))
						target["current_hp"] = int(target.get("current_hp", 0)) + healed
						if healed > 0: target["is_alive"] = true
					result["healing"] = int(result.get("healing", 0)) + healed
					messages.append("%s regains %d Hit Points." % [target_name, healed])
			"grant_source_benefits":
				if target is Character and SourceBenefitRules.grant(target, result.get("effect_cast", {}), effect.benefits):
					messages.append("%s gains source-owned benefits." % target_name)
			"create_actor":
				if target is Character and target == caster:
					if spell.has("_placement") and PlacementRules.decode(spell._placement).is_empty():
						# Batch 053 S-122: authored "spend" policy with no legal space: the cost stays paid, nothing is created.
						result["created_actors"] = {"created": false, "no_space": true}
						messages.append("There is no legal space; %s creates nothing." % str(spell.get("name", "the spell")))
						continue
					# Batch 054 S-155: the cast's chosen template/count; refused choices create nothing.
					var factory: Dictionary = spell.get("_factory", {}) if spell.get("_factory", {}) is Dictionary else {}
					var chosen := CreatedActorRules._template(spell, str(factory.get("template_id", "")))
					if chosen.is_empty(): chosen = effect.template
					var made := CreatedActorRules.create(target, result.get("effect_cast", {}), chosen, slot_level, spell, int(factory.get("count", -1)), factory.get("mix", {}) if factory.get("mix", {}) is Dictionary else {})
					if made.get("created", false):
						result["created_actors"] = made
						messages.append("%s creates %d %s." % [target_name, int(made.count), "creatures" if made.has("mix") else str(chosen.name)])
			"actor_projection":
				if target is Character and target == caster:
					var projected := ActorProjectionRules.apply(target, result.get("effect_cast", {}), effect, slot_level, spell, str(spell.get("_projection_form_id", "")), str(spell.get("_projection_equipment", "")), host)
					result["projection"] = projected
					if projected.get("projected", false): messages.append("%s takes the %s form." % [target_name, str(projected.form_id)])
					else: messages.append("%s cannot take that form: %s." % [target_name, str(projected.get("reason", ""))])
			"bind_tether":
				var bound := TetherRules.apply(caster, target, result.get("effect_cast", {}), effect, spell)
				result["tether"] = bound
				if bound.get("bound", false): messages.append("%s is tethered." % target_name)
			"suppress_item_magic":
				if target is Character and target == caster:
					var muted := MagicPropertyRules.apply(target, result.get("effect_cast", {}), effect)
					result["magic_suppression"] = muted
					if muted.get("applied", false): messages.append("%s's magic is %s on %d item%s." % [target_name, "destroyed" if muted.mode == "destroy" else "suppressed", muted.copies.size(), "" if muted.copies.size() == 1 else "s"])
					else: messages.append("%s: %s" % [target_name, str(muted.get("reason", ""))])
			"grant_damage_link":
				if DamageLinkRules.grant(target, result.get("effect_cast", {}), effect.policy):
					messages.append("%s gains a source-owned damage link." % target_name)
			"grant_damage_response":
				if DamageResponseRules.grant(target, result.get("effect_cast", {}), effect.policy):
					messages.append("%s gains a source-owned damage response." % target_name)
			"grant_condition":
				SpellEffects.grant(target, result.get("effect_cast", {}), str(effect["condition"]))
				if CombatAction.has_condition(target, str(effect["condition"])): messages.append("%s is %s." % [target_name, effect["condition"]])
			"remove_condition":
				if target is Character: target.remove_condition(str(effect["condition"]))
				else:
					target.get("conditions", {}).erase(str(effect["condition"]))
					target.get("condition_sources", {}).erase(str(effect["condition"]))
				SpellEffects.prune(target)
				messages.append("%s's %s condition ends." % [target_name, effect["condition"]])
	if not messages.is_empty():
		result["message"] = str(result.get("message", "")) + " " + " ".join(messages)
	return result

## Applied once after attack/save and any awaited Empowered damage settlement.
static func apply(caster: Character, target, spell: Dictionary, result: Dictionary, host: SpellCastContext = null) -> Dictionary:
	if result.get("recipient_negated", false) or result.get("shared_effects_applied", false) or not result.get("success", false) or result.get("sanctuary_blocked", false) or result.has("damage_request") or result.has("save_bonus_request") or result.has("weapon_attack_bonus_request") or result.has("save_exit_request"):
		return result
	result["shared_effects_applied"] = true
	var effects := SpellDamageRolls.spell_effects_for_slot_level(spell, int(result.get("slot_level", spell.get("level", 0))))
	return apply_custom_effects(caster, target, effects, result, int(result.get("slot_level", spell.get("level", 0))), [], null, spell, host)
