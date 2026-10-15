## JSON-only ordinary spells. Reuses the existing cast, roll and source lifecycle.
## This contract describes supported operations, never executable mod scripts.
class_name SharedSpell
extends RefCounted

const CONDITIONS := ["blinded", "deafened", "frightened", "poisoned", "prone", "restrained", "stunned", "paralyzed", "incapacitated", "blessed", "baned", "shield_of_faith"]
const ABILITIES := ["STR", "DEX", "CON", "INT", "WIS", "CHA"]
const EFFECTS := ["heal", "temporary_hp", "grant_condition", "remove_condition", "area_selection"]
const STEP_FIELDS := ["id", "type", "gate", "gate_step", "target", "shape", "radius", "size", "attack_type", "damage", "damage_type", "damage_components", "component_id", "scaling", "upcast", "save", "half_on_save", "damage_scale_by_outcome", "effects"]
const STEP_TYPES := ["attack", "save", "damage", "effect"]
const STEP_GATES := ["always", "hit", "miss", "failed_save", "successful_save"]
const FIELDS := ["id", "name", "description", "execution", "level", "casting_time", "range", "range_kind", "range_by_character_level_feet", "target", "base_targets", "attack_type", "damage", "damage_type", "scaling", "upcast", "save", "half_on_save", "damage_scale_by_outcome", "requires_target_sight", "target_creature_types", "target_creature_type_exclusions", "target_sizes", "ignore_cover_on_save", "effects", "concentration", "duration", "duration_seconds", "repeat_save", "targets_objects", "ignites_objects", "area_radius", "cone_size", "end_on_target_damage", "end_on_any_damage", "end_on_party_damage", "components", "material", "material_component_item_id", "material_component_cost", "material_component_consumed", "consumed_material_item_id", "ritual", "rules_source", "rules_status", "school", "classes", "source", "trigger", "steps"]

static func uses(spell: Dictionary) -> bool:
	return spell.get("execution", "") == "shared"

static func _validate_single_effect(effect: Variant) -> String:
	if not effect is Dictionary or effect.get("type", "") not in EFFECTS:
		return "Unsupported shared effect operation."
	var kind := str(effect["type"])
	var allowed := ["type", "on_spell_hit", "on_failed_save", "rider_by_outcome", "when"]
	if effect.has("when") and not effect["when"] is Dictionary: return "Shared effect when must be a predicate object."
	if kind in ["heal", "temporary_hp"]:
		allowed.append_array(["value", "ability_bonus_from_caster"])
		if not _formula(effect.get("value")) and not effect.get("value") is Dictionary: return "Shared healing/temporary HP requires a valid value."
		if effect.has("ability_bonus_from_caster") and not effect["ability_bonus_from_caster"] is bool: return "ability_bonus_from_caster must be Boolean."
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

static func authored_damage_scale(payload: Dictionary, outcome: String, default_scale: float) -> float:
	var mapping: Variant = payload.get("damage_scale_by_outcome", {})
	return float(mapping[outcome]) if mapping is Dictionary and mapping.has(outcome) else default_scale

static func record_damage_scale(result: Dictionary, payload: Dictionary, outcome: String, scale: float) -> void:
	if payload.has("damage_scale_by_outcome"):
		result["damage_scale_decision"] = {"outcome": outcome, "scale": scale, "source": "authored_map", "rounding": "floor_after_bonus_before_typed_settlement"}

static func _steps_error(spell: Dictionary) -> String:
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
	if spell.get("execution", "") != "shared":
		return "Unknown spell execution; use 'shared' for ordinary JSON spells."
	for key in spell:
		if str(key) not in FIELDS and not str(key).begins_with("_"):
			return "Unsupported shared spell field '%s'." % str(key)
	if str(spell.get("id", "")).is_empty() or str(spell.get("name", "")).is_empty():
		return "Shared spells require an id and name."
	if not _integer(spell.get("level"), 0, 9) or not _integer(spell.get("range"), 0, 1000):
		return "Shared spells require integer level (0-9) and range in hexes (0-1000)."
	if spell.get("casting_time", "action") not in ["action", "bonus_action"] or not str(spell.get("trigger", "")).is_empty():
		return "Shared spells support ordinary Action or Bonus Action casts."
	if spell.get("target", "single") not in ["single", "self", "multi", "area", "cone"]:
		return "Unsupported shared target selector."
	if spell.has("steps"):
		if spell.has("damage_scale_by_outcome"):
			return "Ordered damage outcome maps must belong to an attack or save step."
		var steps_err := _steps_error(spell)
		if not steps_err.is_empty():
			return steps_err
	else:
		if spell.get("attack_type", "none") not in ["none", "ranged_spell", "melee_spell"]:
			return "Unsupported shared attack delivery."
		if spell.has("save") and spell["save"] not in ABILITIES:
			return "Shared saving throws require an ability."
		if spell.has("save") and spell.get("attack_type", "none") != "none":
			return "Choose either attack or saving-throw delivery."
		if spell.has("damage_scale_by_outcome"):
			if not spell.has("save") and spell.get("attack_type", "none") == "none": return "damage_scale_by_outcome requires attack or save delivery."
			if not spell.has("damage"): return "damage_scale_by_outcome requires a damage payload."
			var scale_error := validate_outcome_map(spell["damage_scale_by_outcome"], outcome_domain_for_delivery(spell.get("attack_type", "none") != "none"), "damage_scale_by_outcome")
			if not scale_error.is_empty(): return scale_error
		if spell.has("damage") and (not _formula(spell["damage"]) or spell.get("damage_type", "") not in DataLoader.VALID_DAMAGE_TYPES):
			return "Shared damage requires a valid formula and damage type."
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
	var has_payload := spell.has("damage") or spell.has("steps")
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
		if kind == "grant_condition": timed = true
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
	if spell.get("effects", []).any(func(effect): return effect is Dictionary and effect.get("type", "") == kind):
		return true
	for step in spell.get("steps", []):
		if step is Dictionary and step.get("effects", []).any(func(effect): return effect is Dictionary and effect.get("type", "") == kind):
			return true
	return false

static func manages(spell: Dictionary) -> bool:
	return has_effect(spell, "grant_condition") and content_error(spell).is_empty()

static func _create_step_cast(cast: SpellResolutionContext, target, step_spell: Dictionary) -> SpellResolutionContext:
	var step_cast := SpellResolutionContext.new()
	step_cast.caster = cast.caster
	step_cast.target = target
	step_cast.spell = step_spell
	step_cast.decisions = cast.decisions
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
	step_cast.item_definition_id = cast.item_definition_id
	step_cast.item_instance_id = cast.item_instance_id
	step_cast.item_copy_validated = cast.item_copy_validated
	step_cast.source_definition_id = cast.source_definition_id
	step_cast.source_instance_id = cast.source_instance_id
	step_cast.source_owner_id = cast.source_owner_id
	step_cast.incoming_slot_spent = cast.incoming_slot_spent
	step_cast.incoming_slot_key = cast.incoming_slot_key
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
		var roll := SpellDamageRolls._roll_spell_damage(cast.caster, formula, 1, cast.decisions)
		result = SpellDamageRolls._finish_spell_damage(cast.caster, cast.target, roll, CombatAction.spell_damage_bonus(cast.caster, cast.spell), 1.0, str(cast.spell["damage_type"]), cast.decisions, {"success": true, "hit": true, "effect_cast": cast.effect_cast, "message": "%s deals {damage} %s damage." % [cast.spell["name"], cast.spell["damage_type"]]})
	else:
		result = {"success": true, "hit": true, "damage": 0, "effect_cast": cast.effect_cast, "message": str(cast.spell["name"]) + " resolves."}
	result["slot_level"] = cast.slot_level
	result["effect_cast"] = cast.effect_cast
	return apply(cast.caster, cast.target, cast.spell, result)

static func apply_custom_effects(caster: Character, target, effects: Array, result: Dictionary, slot_level: int, step_results: Array = [], adapter: Object = null) -> Dictionary:
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
					if not evaluated.get("success", false): continue
					amount = int(evaluated["value"])
				else:
					amount = Dice.parse_dice_string(formula, {}, caster)
				if effect["type"] == "heal" and not formula_value is Dictionary: amount = SpellEffects.maximize_healing(target, amount, Dice.maximum_dice_string(formula))
				if bool(effect.get("ability_bonus_from_caster", false)): amount += caster.ability_scores.get_ability_modifier(caster.get_spellcasting_ability())
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
static func apply(caster: Character, target, spell: Dictionary, result: Dictionary) -> Dictionary:
	if result.get("shared_effects_applied", false) or not result.get("success", false) or result.get("sanctuary_blocked", false) or result.has("damage_request") or result.has("save_bonus_request") or result.has("weapon_attack_bonus_request"):
		return result
	result["shared_effects_applied"] = true
	var effects := SpellDamageRolls.spell_effects_for_slot_level(spell, int(result.get("slot_level", spell.get("level", 0))))
	return apply_custom_effects(caster, target, effects, result, int(result.get("slot_level", spell.get("level", 0))))
