## Single shared ordered execution runtime for stepped spells and creature event rules.
## Executes ordered operations with gate evaluation, per-target resolution, and unified result semantics.
class_name SharedStepExecutor
extends RefCounted

const STEP_TYPES := ["attack", "save", "damage", "effect", "replace_hp"]
const STEP_GATES := ["always", "hit", "miss", "failed_save", "successful_save"]
const ABILITIES := ["STR", "DEX", "CON", "INT", "WIS", "CHA"]

const SPELL_STEP_TYPES := ["attack", "save", "damage", "effect"]
const SPELL_STEP_FIELDS := [
	"id", "type", "gate", "gate_step", "target", "shape", "radius", "size",
	"attack_type", "damage", "damage_type", "damage_components", "component_id", "scaling", "upcast",
	"save", "half_on_save", "save_context", "damage_scale_by_outcome", "damage_dice_policy", "damage_result_multiplier", "damage_reductions", "damage_bypasses", "effects", "when",
	"incoming_negation", "incoming_negation_rule", "physical_requirements", "spatial_requirements"
]
const DAMAGE_HISTORY_FACTS := ["target.damage_raw_since_combat_turn", "target.damage_prevented_since_combat_turn", "target.damage_absorbed_since_combat_turn", "target.damage_resolved_since_combat_turn", "target.damage_hp_loss_since_combat_turn", "target.damage_raw_since_owner_turn", "target.damage_prevented_since_owner_turn", "target.damage_absorbed_since_owner_turn", "target.damage_resolved_since_owner_turn", "target.damage_hp_loss_since_owner_turn", "target.damage_raw_within_last_minute", "target.damage_prevented_within_last_minute", "target.damage_absorbed_within_last_minute", "target.damage_resolved_within_last_minute", "target.damage_hp_loss_within_last_minute"]
const RULE_FACTS := ["actor.id", "actor.level", "target.id", "target.current_hp", "target.max_hp", "target.is_alive", "target.is_wounded", "target.is_source_owner", "target.relationship", "target.willingness", "target.charmed_by_actor", "target.marked_by_actor", "target.actor_hex_distance_feet", "target.source_hex_distance_feet", "target.first_round", "target.first_own_turn", "target.acted_since_combat_turn", "target.acted_since_owner_turn", "target.attacked_since_combat_turn", "target.attacked_since_owner_turn", "source.id", "source.owner_id", "action.id", "action.invocation_id", "item.definition_id", "item.instance_id", "spell.definition_id", "spell.invocation_id", "source.definition_id", "source.instance_id", "resolution.window", "resolution.occurrence_id", "resolution.kind", "resolution.actor_id", "resolution.target_id", "resolution.action_id", "resolution.action_invocation_id", "resolution.spell_definition_id", "resolution.spell_invocation_id", "resolution.source_definition_id", "resolution.source_instance_id", "resolution.source_owner_id", "resolution.roll_natural", "resolution.roll_modifier", "resolution.roll_total", "resolution.target_ac", "resolution.provisional_hit", "resolution.provisional_critical", "resolution.final_hit", "resolution.critical", "resolution.damage_occurrence_id", "resolution.damage_type", "resolution.damage_raw", "resolution.damage_resolved", "resolution.damage_hp_loss"] + DAMAGE_HISTORY_FACTS
const PREDICATE_UNKNOWN := -1
const PREDICATE_FALSE := 0
const PREDICATE_TRUE := 1
const FORMULA_OPS := ["add", "subtract", "multiply", "floor_divide", "min", "max"]
const PREDICATE_OPS := ["eq", "ne", "lt", "lte", "gt", "gte"]

const EVENT_STEP_TYPES := ["save", "replace_hp"]
const EVENT_STEP_FIELDS := [
	"id", "type", "gate", "gate_step", "target",
	"save", "save_ability", "dc_base", "dc_add_damage",
	"replacement_hp"
]

const ZERO_HP_RULE_FIELDS := [
	"id", "name", "type", "trigger", "description",
	"bypass_damage_types", "bypass_critical", "steps",
	"save_ability", "save", "dc_base", "dc_add_damage", "replacement_hp"
]


static func _integer(value: Variant, minimum: int, maximum: int) -> bool:
	if value is bool: return false
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floor(float(value)) and float(value) >= minimum and float(value) <= maximum


static func _formula(value: Variant) -> bool:
	if value is bool: return false
	if value is int or value is float: return _integer(value, 0, 999)
	if not value is String: return false
	var expression := RegEx.new()
	expression.compile("^([0-9]{1,3}|[1-9][0-9]?d(4|6|8|10|12|20))([+][0-9]{1,3})?$")
	return expression.search(str(value).replace(" ", "")) != null


static func formula_content_error(value: Variant) -> String:
	return _validate_formula_expression(value, {}, 0)


static func validate_damage_policy(reductions: Variant, bypasses: Variant, component_ids: Array[String]) -> String:
	if not reductions is Array or reductions.size() > 8:
		return "damage_reductions must be an array of at most eight entries."
	for reduction in reductions:
		if not reduction is Dictionary:
			return "Each damage reduction must be an object."
		var scope := str(reduction.get("scope", ""))
		if scope not in ["component", "occurrence"] or str(reduction.get("stage", "")) != "after_scale_before_mitigation":
			return "Damage reductions require component/occurrence scope at after_scale_before_mitigation."
		if not reduction.has("amount") or not formula_content_error(reduction["amount"]).is_empty():
			return "Damage reduction amount must be a supported fixed or formula value."
		if reduction["amount"] is String:
			return "Damage reductions require a fixed integer or deterministic actor formula object."
		if reduction["amount"] is Dictionary and not ResourcePoolRules._actor_formula_error(reduction["amount"]).is_empty():
			return "Damage reduction formulas may use actor-only inputs."
		if scope == "component":
			var component_id := str(reduction.get("component_id", ""))
			if component_id.is_empty() or not component_ids.has(component_id):
				return "Component damage reductions require an exact component_id in this occurrence."
		else:
			if reduction.has("component_id"):
				return "Occurrence damage reductions cannot declare component_id."
		for field in reduction:
			if field not in ["scope", "component_id", "amount", "stage"]:
				return "Damage reduction contains an unsupported field '%s'." % str(field)
	if not bypasses is Array or bypasses.size() > 8:
		return "damage_bypasses must be an array of at most eight entries."
	for bypass in bypasses:
		if not bypass is Dictionary:
			return "Each damage bypass must be an object."
		var scope := str(bypass.get("scope", ""))
		var layers: Variant = bypass.get("layers", null)
		if scope not in ["component", "occurrence"] or str(bypass.get("stage", "")) != "mitigation" or not layers is Array or layers.is_empty() or layers.size() > 4:
			return "Damage bypasses require component/occurrence scope, mitigation stage and selected layers."
		var seen_layers: Array[String] = []
		for layer in layers:
			if not layer is String or str(layer) not in ["resistance", "immunity", "ward", "prevention"] or str(layer) in seen_layers:
				return "Damage bypass layers must be unique resistance, immunity, ward or prevention entries."
			seen_layers.append(str(layer))
		if scope == "component":
			var component_id := str(bypass.get("component_id", ""))
			if component_id.is_empty() or not component_ids.has(component_id):
				return "Component damage bypasses require an exact component_id in this occurrence."
		elif bypass.has("component_id"):
			return "Occurrence damage bypasses cannot declare component_id."
		for field in bypass:
			if field not in ["scope", "component_id", "layers", "stage"]:
				return "Damage bypass contains an unsupported field '%s'." % str(field)
	return ""


static func _validate_formula_expression(value: Variant, step_ids: Dictionary, before_index: int, all_steps: Array = []) -> String:
	return _validate_formula_expression_bounded(value, step_ids, before_index, all_steps, 0, false)


static func _validate_formula_expression_bounded(value: Variant, step_ids: Dictionary, before_index: int, all_steps: Array, depth: int, deterministic_only: bool) -> String:
	if depth > 12:
		return "Formula nesting exceeds the supported depth."
	if _formula(value):
		if deterministic_only and value is String and str(value).to_lower().contains("d"):
			return "Breakpoint lookup inputs cannot contain dice or random formulas."
		return ""
	if not value is Dictionary: return "Expected a number, dice expression, or shared formula object."
	if value.has("input_value"):
		return "" if value.size() == 1 and value.input_value is String and value.input_value.is_valid_identifier() else "input_value requires a declared identifier."
	if value.has("source_die"):
		if value.size() != 1 or not value.source_die is Dictionary: return "source_die requires one selector."
		var selector: Dictionary = value.source_die
		if selector.size() != 4 or selector.get("target") not in ["same", "cast_target"] or selector.get("policy") not in ["captured", "revalidate"] or not selector.get("pool_id") is String or str(selector.pool_id).is_empty(): return "source_die requires step, target, pool_id and captured/revalidate policy."
		var id: Variant = selector.get("step")
		if not id is String or not step_ids.has(id) or int(step_ids[id]) >= before_index or int(step_ids[id]) >= all_steps.size() or all_steps[int(step_ids[id])].get("type") not in ["attack", "save"]: return "source_die requires a prior attack/save step."
		return ""
	if value.get("op", "") in ["breakpoint_lookup", "progression_lookup"]:
		var progression: bool = value.get("op") == "progression_lookup"
		if value.size() != (5 if progression else 3) or not value.has("input") or not value.has("breakpoints"):
			return "breakpoint_lookup requires input and breakpoints only."
		if progression and (value.get("value_type") not in ["number", "die_size"] or value.get("below_first") not in ["unavailable", "zero"] or (value.get("value_type") == "die_size" and value.get("below_first") != "unavailable")): return "Progression tables require number/die_size and explicit below_first policy (dice require unavailable)."
		var input_error := _validate_formula_expression_bounded(value["input"], step_ids, before_index, all_steps, depth + 1, true)
		if not input_error.is_empty(): return input_error
		var breakpoints: Variant = value["breakpoints"]
		if not breakpoints is Array or breakpoints.is_empty() or breakpoints.size() > 20:
			return "breakpoint_lookup requires 1 to 20 bounded rows."
		var previous_threshold := -1000
		for row in breakpoints:
			if not row is Dictionary or row.size() != 2 or not row.has("threshold") or not row.has("value"):
				return "breakpoint_lookup rows require threshold and value only."
			var threshold: Variant = row["threshold"]
			var output: Variant = row["value"]
			if not _integer(threshold, -999, 999) or not _integer(output, 0, 999):
				return "breakpoint_lookup thresholds and values must be bounded integers."
			if progression and value.value_type == "die_size" and int(output) not in ResourcePoolRules.SUPPORTED_DIE_SIZES: return "Progression row has an unsupported die size."
			if int(threshold) <= previous_threshold:
				return "breakpoint_lookup thresholds must be strictly increasing and unique."
			previous_threshold = int(threshold)
		return ""
	if value.has("caster_level") or value.has("caster_proficiency_bonus") or value.has("caster_class_level") or value.has("caster_ability_modifier") or value.has("selected_slot_level"):
		if value.size() != 1: return "Character/cast formula references must contain exactly one selector."
		if value.has("caster_level") and value["caster_level"] is bool and value["caster_level"]: return ""
		if value.has("caster_proficiency_bonus") and value["caster_proficiency_bonus"] is bool and value["caster_proficiency_bonus"]: return ""
		if value.has("selected_slot_level") and value["selected_slot_level"] is bool and value["selected_slot_level"]: return ""
		if value.has("caster_class_level"):
			var class_id: Variant = value["caster_class_level"]
			if class_id is String and not class_id.strip_edges().is_empty() and not DataLoader.get_character_class(class_id).is_empty(): return ""
			return "caster_class_level requires a known class ID."
		if value.has("caster_ability_modifier"):
			if value["caster_ability_modifier"] is String and str(value["caster_ability_modifier"]) in ABILITIES: return ""
			return "caster_ability_modifier requires one of STR, DEX, CON, INT, WIS, or CHA."
		return "Character/cast formula selectors require Boolean true."
	if value.has("result"):
		if value.size() != 1 or not value["result"] is Dictionary: return "Result formula must contain only a result selector."
		var selector: Dictionary = value["result"]
		for key in selector:
			if key not in ["step", "target", "component", "component_id", "measure"]: return "Unsupported result selector field '%s'." % str(key)
		var ref_id := str(selector.get("step", ""))
		if not step_ids.has(ref_id) or int(step_ids[ref_id]) >= before_index: return "Formula references nonexistent or forward step '%s'." % ref_id
		var ref_index := int(step_ids[ref_id])
		if ref_index >= all_steps.size() or not all_steps[ref_index] is Dictionary: return "Formula result step '%s' is unavailable." % ref_id
		var ref_step: Dictionary = all_steps[ref_index]
		if selector.get("target", "") not in ["same", "cast_target"]: return "Result references require target 'same' or 'cast_target'."
		var measure := str(selector.get("measure", ""))
		if measure == "margin":
			if selector.has("component") or selector.has("component_id"):
				return "A roll margin selects one target's attack/save result and takes no damage component."
			if str(ref_step.get("type", "")) not in ["attack", "save"]:
				return "Formula result step '%s' has no attack/save margin." % ref_id
			return ""
		if measure == "hp_after":
			if selector.has("component") or selector.has("component_id"):
				return "Post-settlement HP selects one target's step result and takes no damage component."
			if str(ref_step.get("type", "")) not in ["attack", "save", "damage"] or (not ref_step.has("damage") and not ref_step.has("damage_components")):
				return "Formula result step '%s' has no damage settlement HP receipt." % ref_id
			return ""
		if measure == "healed":
			if selector.has("component") or selector.has("component_id"):
				return "The healed measure selects the target's heal receipt and does not take a damage component."
			if str(ref_step.get("type", "")) != "effect" or not _step_has_heal_effect(ref_step):
				return "Formula result step '%s' has no healing effect receipt." % ref_id
			return ""
		if str(ref_step.get("type", "")) not in ["attack", "save", "damage"] or (not ref_step.has("damage") and not ref_step.has("damage_components")):
			return "Formula result step '%s' has no damage payload." % ref_id
		if not selector.get("component", "") is String or str(selector.get("component", "")).is_empty(): return "Result references require a damage component type."
		if selector.has("component_id") and (not selector["component_id"] is String or str(selector["component_id"]).is_empty()):
			return "Result component_id must be a non-empty string."
		if not _step_has_damage_component(ref_step, str(selector.get("component", "")), str(selector.get("component_id", ""))):
			return "Formula result step '%s' has no '%s' damage component." % [ref_id, str(selector.get("component", ""))]
		if measure not in ["raw", "resolved", "hp_loss", "prevented", "absorbed"]: return "Result references require a supported damage or healing measure."
		return ""
	if value.has("result_sum"):
		if value.size() != 1 or not value["result_sum"] is Dictionary:
			return "Result sums must contain one sum selector."
		var selector: Dictionary = value["result_sum"]
		if selector.size() != 3 or not selector.has("step") or not selector.has("component") or not selector.has("measure"):
			return "Result sums require step, component, and measure only."
		if not selector["step"] is String or str(selector["step"]).is_empty():
			return "Result sums require a named earlier step."
		var ref_id := str(selector["step"])
		if not step_ids.has(ref_id) or int(step_ids[ref_id]) >= before_index:
			return "Formula references nonexistent or forward step '%s'." % ref_id
		var ref_index := int(step_ids[ref_id])
		if ref_index >= all_steps.size() or not all_steps[ref_index] is Dictionary:
			return "Formula result step '%s' is unavailable." % ref_id
		var ref_step: Dictionary = all_steps[ref_index]
		if str(ref_step.get("type", "")) not in ["attack", "save", "damage"] or not ref_step.has("damage"):
			return "Formula result step '%s' has no damage payload." % ref_id
		if not selector["component"] is String or str(selector["component"]).is_empty() or str(ref_step.get("damage_type", "")) != str(selector["component"]):
			return "Formula result step '%s' has no '%s' damage component." % [ref_id, str(selector.get("component", ""))]
		if selector["measure"] not in ["raw", "resolved", "hp_loss"]:
			return "Result sums require measure raw, resolved, or hp_loss."
		return ""
	if value.has("result_reduce"):
		if value.size() != 1 or not value["result_reduce"] is Dictionary:
			return "result_reduce must contain one explicit reducer selection."
		return _validate_result_reducer_selector(value["result_reduce"], step_ids, before_index, all_steps)
	if value.size() != 3 or not value.has("op") or value.get("op") not in FORMULA_OPS or not value.has("left") or not value.has("right"):
		return "Formula objects require op, left, and right using a supported arithmetic operation."
	for key in ["left", "right"]:
		var err := _validate_formula_expression_bounded(value[key], step_ids, before_index, all_steps, depth + 1, deterministic_only)
		if not err.is_empty(): return err
	if value["op"] == "floor_divide":
		var divisor = value["right"]
		if (divisor is int or divisor is float) and int(divisor) <= 0:
			return "floor_divide requires a positive divisor."
		if divisor is String and divisor.replace(" ", "").is_valid_int() and int(divisor) <= 0:
			return "floor_divide requires a positive divisor."
	return ""


static func _validate_predicate(predicate: Variant, step_ids: Dictionary, before_index: int, all_steps: Array = [], depth: int = 0) -> String:
	if depth > 12 or not predicate is Dictionary: return "Predicates must be bounded objects."
	if predicate.has("child_group"):
		if predicate.size() != 1 or not predicate.child_group is Dictionary: return "child_group requires one selector."
		return _validate_child_group(predicate.child_group, step_ids, before_index, all_steps)
	if predicate.has("all") or predicate.has("any"):
		var key := "all" if predicate.has("all") else "any"
		if predicate.size() != 1 or not predicate[key] is Array or predicate[key].is_empty(): return "Boolean predicates require a non-empty all/any array."
		for child in predicate[key]:
			var child_err := _validate_predicate(child, step_ids, before_index, all_steps, depth + 1)
			if not child_err.is_empty(): return child_err
		return ""
	if predicate.has("not"):
		if predicate.size() != 1: return "not predicates accept one child only."
		return _validate_predicate(predicate["not"], step_ids, before_index, all_steps, depth + 1)
	var value_key := "fact" if predicate.has("fact") else ("result" if predicate.has("result") else ("result_sum" if predicate.has("result_sum") else ("result_reduce" if predicate.has("result_reduce") else "")))
	if value_key.is_empty(): return "Predicate requires a fact or result selector."
	if value_key == "fact":
		if predicate.size() != 2 or str(predicate["fact"]) not in RULE_FACTS: return "Unknown or malformed shared fact '%s'." % str(predicate.get("fact", ""))
	else:
		var selector_err := _validate_formula_expression({value_key: predicate[value_key]}, step_ids, before_index, all_steps)
		if not selector_err.is_empty(): return selector_err
		if predicate.size() != 2: return "Result predicates require exactly one comparison."
	var comparison := ""
	for op in PREDICATE_OPS:
		if predicate.has(op): comparison = op
	if comparison.is_empty() or predicate.size() != 2: return "Predicates require one eq/ne/lt/lte/gt/gte comparison."
	if comparison in ["lt", "lte", "gt", "gte"] and (not (predicate[comparison] is int or predicate[comparison] is float) or predicate[comparison] is bool):
		return "Ordered predicate comparisons require a numeric value."
	var compare_value = predicate[comparison]
	if compare_value is Dictionary or compare_value is Array: return "Predicate comparison values must be scalar."
	if value_key in ["result", "result_sum", "result_reduce"] and (not (compare_value is int or compare_value is float) or compare_value is bool): return "Damage-result predicates require a numeric comparison value."
	if value_key == "fact":
		var fact_name := str(predicate["fact"])
		var numeric_fact := fact_name in ["actor.level", "target.current_hp", "target.max_hp", "target.actor_hex_distance_feet", "target.source_hex_distance_feet", "resolution.roll_natural", "resolution.roll_modifier", "resolution.roll_total", "resolution.target_ac", "resolution.damage_occurrence_id", "resolution.damage_raw", "resolution.damage_resolved", "resolution.damage_hp_loss"] or fact_name in DAMAGE_HISTORY_FACTS
		var boolean_fact := fact_name in ["target.is_alive", "target.is_wounded", "target.is_source_owner", "target.charmed_by_actor", "target.marked_by_actor", "target.first_round", "target.first_own_turn", "target.acted_since_combat_turn", "target.acted_since_owner_turn", "target.attacked_since_combat_turn", "target.attacked_since_owner_turn", "resolution.provisional_hit", "resolution.provisional_critical", "resolution.final_hit", "resolution.critical"]
		if numeric_fact and (not (compare_value is int or compare_value is float) or compare_value is bool):
			return "Numeric facts require a numeric comparison value."
		if boolean_fact and (comparison not in ["eq", "ne"] or not compare_value is bool):
			return "Predicate comparison type does not match fact '%s'." % fact_name
		if _is_string_fact(fact_name) and (comparison not in ["eq", "ne"] or not compare_value is String):
			return "Identity facts require string equality/inequality."
		if fact_name == "target.relationship" and compare_value not in ["ally", "enemy"]:
			return "Relationship facts compare only ally or enemy."
		if fact_name == "target.willingness" and compare_value not in ["willing", "unwilling"]:
			return "Willingness facts compare only explicit willing or unwilling values."
	return ""


static func _validate_child_group(group: Dictionary, step_ids: Dictionary, before_index: int, steps: Array) -> String:
	for key in group:
		if key not in ["mode", "steps", "targets", "outcome", "empty", "skipped", "comparison", "threshold"]: return "Unknown child_group field."
	for key in ["mode", "steps", "targets", "outcome", "empty", "skipped"]:
		if not group.has(key): return "child_group requires explicit selection, empty and skipped policies."
	if group.mode not in ["all", "any", "count"] or group.targets not in ["all", "same", "cast_target"]: return "Invalid child_group mode/targets."
	if group.outcome not in ["hit", "miss", "successful_save", "failed_save"]: return "Invalid child_group outcome."
	if group.empty not in ["pass", "fail", "unavailable"] or group.skipped not in ["exclude", "fail", "unavailable"]: return "Invalid child_group empty/skipped policy."
	if not group.steps is Array or group.steps.is_empty() or group.steps.size() > 20: return "child_group requires 1 to 20 prior steps."
	var seen := {}
	for id in group.steps:
		if not id is String or seen.has(id) or not step_ids.has(id) or int(step_ids[id]) >= before_index: return "child_group requires unique existing prior steps."
		seen[id] = true
		var index := int(step_ids[id])
		if index >= steps.size() or str(steps[index].get("type", "")) != ("attack" if group.outcome in ["hit", "miss"] else "save"): return "child_group outcome must match each selected attack/save step."
	if group.mode == "count":
		if group.size() != 8 or group.get("comparison", "") not in PREDICATE_OPS or not _integer(group.get("threshold"), 0, 1000): return "Count requires a bounded threshold and comparison."
	elif group.size() != 6: return "all/any accept no count comparison."
	return ""


static func _child_group_state(group: Dictionary, adapter: Object, target, results: Array) -> int:
	var cast = adapter.get("cast")
	var selected = target if group.targets == "same" else (cast.target if group.targets == "cast_target" and cast != null else null)
	if group.targets != "all" and selected == null: return PREDICATE_UNKNOWN
	var matched := 0
	var total := 0
	# Inspect the entire selection before evaluating ANY or a count threshold.
	for id in group.steps:
		var found: Dictionary = {}
		for row in results:
			if not row is Dictionary: return PREDICATE_UNKNOWN
			if row.get("step_id") == id:
				if not found.is_empty(): return PREDICATE_UNKNOWN
				found = row
		if found.is_empty() or found.get("complete") != true or not found.get("target_outcomes") is Array: return PREDICATE_UNKNOWN
		if found.get("type") != ("attack" if group.outcome in ["hit", "miss"] else "save"): return PREDICATE_UNKNOWN
		if found.get("skipped", false) and found.target_outcomes.is_empty():
			if group.skipped == "unavailable": return PREDICATE_UNKNOWN
			if group.skipped == "fail": total += 1
		var seen: Array = []
		for child in found.target_outcomes:
			if not child is Dictionary or child.get("target") == null: return PREDICATE_UNKNOWN
			if group.targets != "all" and not is_same(child.target, selected): continue
			for prior in seen:
				if is_same(prior, child.target): return PREDICATE_UNKNOWN
			seen.append(child.target)
			if child.get("skipped", false):
				if group.skipped == "unavailable": return PREDICATE_UNKNOWN
				if group.skipped == "fail": total += 1
				continue
			var key := "hit" if group.outcome in ["hit", "miss"] else "saved"
			if not child.get(key) is bool: return PREDICATE_UNKNOWN
			total += 1
			if child[key] == (group.outcome in ["hit", "successful_save"]): matched += 1
		if group.targets != "all" and not found.target_outcomes.is_empty() and seen.is_empty(): return PREDICATE_UNKNOWN
	if total == 0:
		return PREDICATE_TRUE if group.empty == "pass" else (PREDICATE_FALSE if group.empty == "fail" else PREDICATE_UNKNOWN)
	var passes := false
	match str(group.mode):
		"all": passes = matched == total
		"any": passes = matched > 0
		"count":
			match str(group.comparison):
				"eq": passes = matched == int(group.threshold)
				"ne": passes = matched != int(group.threshold)
				"lt": passes = matched < int(group.threshold)
				"lte": passes = matched <= int(group.threshold)
				"gt": passes = matched > int(group.threshold)
				"gte": passes = matched >= int(group.threshold)
	return PREDICATE_TRUE if passes else PREDICATE_FALSE


static func _step_has_heal_effect(step: Dictionary) -> bool:
	var effects: Variant = step.get("effects", [])
	if not effects is Array:
		return false
	for effect in effects:
		if effect is Dictionary and str(effect.get("type", "")) == "heal":
			return true
	return false


static func _step_has_damage_component(step: Dictionary, component_type: String, component_id: String = "") -> bool:
	var components: Variant = step.get("damage_components", null)
	if components is Array:
		var type_counts: Dictionary = {}
		for i in components.size():
			var component: Variant = components[i]
			if not component is Dictionary:
				continue
			var kind := str(component.get("damage_type", ""))
			var expected_id := str(component.get("id", "%s:%d" % [kind, int(type_counts.get(kind, 0)) + 1]))
			if component_id.is_empty() or expected_id == component_id:
				if kind == component_type:
					return true
			type_counts[kind] = int(type_counts.get(kind, 0)) + 1
		return false
	if str(step.get("damage_type", "")) != component_type:
		return false
	var expected := str(step.get("component_id", "%s:%s" % [str(step.get("id", "")), component_type]))
	return component_id.is_empty() or expected == component_id


static func _validate_result_reducer_selector(selector: Dictionary, step_ids: Dictionary, before_index: int, all_steps: Array) -> String:
	var allowed := ["reducer", "steps", "targets", "component", "component_id", "measure", "empty"]
	for key in selector:
		if key not in allowed:
			return "result_reduce contains unsupported selector field '%s'." % str(key)
	for required in ["reducer", "steps", "targets", "component", "measure", "empty"]:
		if not selector.has(required):
			return "result_reduce requires explicit reducer, steps, targets, component, measure and empty policy."
	var reducer := str(selector.get("reducer", ""))
	if reducer not in ["sum", "min", "max"]:
		return "result_reduce accepts sum, min or max."
	var expected_empty := "zero" if reducer == "sum" else "unavailable"
	if str(selector.get("empty", "")) != expected_empty:
		return "result_reduce %s requires empty='%s'." % [reducer, expected_empty]
	if not selector["steps"] is Array or selector["steps"].is_empty() or selector["steps"].size() > 20:
		return "result_reduce requires 1 to 20 explicitly selected prior steps."
	if selector.get("targets", "") not in ["all", "same", "cast_target"]:
		return "result_reduce targets must be all, same or cast_target."
	if not selector["component"] is String or str(selector["component"]).is_empty():
		return "result_reduce requires one typed damage component."
	if selector.has("component_id") and (not selector["component_id"] is String or str(selector["component_id"]).is_empty()):
		return "result_reduce component_id must be a non-empty string."
	if str(selector.get("measure", "")) not in ["raw", "prevented", "absorbed", "resolved", "hp_loss"]:
		return "result_reduce requires a supported settled damage measure."
	var seen_steps: Dictionary = {}
	for step_name in selector["steps"]:
		if not step_name is String or str(step_name).is_empty() or seen_steps.has(step_name):
			return "result_reduce step IDs must be unique non-empty strings."
		seen_steps[step_name] = true
		if not step_ids.has(step_name) or int(step_ids[step_name]) >= before_index:
			return "result_reduce references nonexistent or forward step '%s'." % str(step_name)
		var step_index := int(step_ids[step_name])
		if step_index >= all_steps.size() or not all_steps[step_index] is Dictionary:
			return "result_reduce step '%s' is unavailable." % str(step_name)
		var ref_step: Dictionary = all_steps[step_index]
		if str(ref_step.get("type", "")) not in ["attack", "save", "damage"] or (not ref_step.has("damage") and not ref_step.has("damage_components")):
			return "result_reduce step '%s' has no settled damage payload." % str(step_name)
		if not _step_has_damage_component(ref_step, str(selector["component"]), str(selector.get("component_id", ""))):
			return "result_reduce step '%s' has no selected typed component." % str(step_name)
		if not selector.has("component_id") and _step_damage_component_count(ref_step, str(selector["component"])) > 1:
			return "result_reduce step '%s' has an ambiguous component; specify component_id." % str(step_name)
	return ""


static func _step_damage_component_count(step: Dictionary, component_type: String) -> int:
	var components: Variant = step.get("damage_components", null)
	if not components is Array:
		return 1 if str(step.get("damage_type", "")) == component_type else 0
	var count := 0
	for component in components:
		if component is Dictionary and str(component.get("damage_type", "")) == component_type:
			count += 1
	return count


static func _numeric_fact_value(value: Variant) -> Dictionary:
	if (value is int or value is float) and not value is bool and is_finite(float(value)):
		return {"available": true, "value": value}
	return {"available": false}


static func _identity_fact_value(value: Variant) -> Dictionary:
	if value is String and not str(value).strip_edges().is_empty():
		return {"available": true, "value": str(value)}
	return {"available": false}


static func _boolean_fact_value(value: Variant) -> Dictionary:
	if value is bool:
		return {"available": true, "value": value}
	return {"available": false}


static func _actor_fact(actor: Variant, field: String) -> Dictionary:
	if actor is Character:
		match field:
			"id": return _identity_fact_value(actor.character_id)
			"level": return _numeric_fact_value(actor.level)
			"current_hp": return _numeric_fact_value(actor.current_hp)
			"max_hp": return _numeric_fact_value(actor.max_hp)
			"is_alive": return _boolean_fact_value(actor.is_alive and not actor.is_dead())
			"is_wounded": return _boolean_fact_value(actor.current_hp < actor.max_hp)
		return {"available": false}
	if actor is Dictionary:
		match field:
			"id": return _identity_fact_value(actor.get("id", null))
			"level": return _numeric_fact_value(actor.get("level", null))
			"current_hp": return _numeric_fact_value(actor.get("current_hp", null))
			"max_hp": return _numeric_fact_value(actor.get("max_hp", null))
			"is_alive": return _boolean_fact_value(actor.get("is_alive", null))
			"is_wounded":
				var current_hp: Dictionary = _numeric_fact_value(actor.get("current_hp", null))
				var max_hp: Dictionary = _numeric_fact_value(actor.get("max_hp", null))
				if not current_hp.get("available", false) or not max_hp.get("available", false): return {"available": false}
				return _boolean_fact_value(float(current_hp["value"]) < float(max_hp["value"]))
	return {"available": false}


static func _item_fact(cast: SpellResolutionContext, field: String) -> Dictionary:
	if not cast.item_copy_validated or cast.item_instance_id.is_empty() or cast.item_definition_id.is_empty():
		return {"available": false}
	return _identity_fact_value(cast.item_definition_id if field == "definition_id" else cast.item_instance_id)


static func _is_string_fact(fact_name: String) -> bool:
	return fact_name in ["actor.id", "target.id", "target.relationship", "target.willingness", "source.id", "source.owner_id", "action.id", "action.invocation_id", "item.definition_id", "item.instance_id", "spell.definition_id", "spell.invocation_id", "source.definition_id", "source.instance_id", "resolution.window", "resolution.occurrence_id", "resolution.kind", "resolution.actor_id", "resolution.target_id", "resolution.action_id", "resolution.action_invocation_id", "resolution.spell_definition_id", "resolution.spell_invocation_id", "resolution.source_definition_id", "resolution.source_instance_id", "resolution.source_owner_id", "resolution.damage_type"]


## Each attack resolves on a child cast. Bind its canonical receipt to the
## ordered consumer, including after an awaited attack/damage choice.
static func _bind_resolution_window(cast: SpellResolutionContext, target, result: Dictionary) -> void:
	cast.resolution_window = {}
	cast.resolution_window_context = {}
	cast.resolution_window_target = null
	var windows: Array = result.get("resolution_windows", [])
	if windows.is_empty():
		return
	cast.resolution_window = windows.back().duplicate(true)
	cast.resolution_window_context = {"base": windows[0].duplicate(true), "windows": windows.duplicate(true)}
	cast.resolution_window_target = target


static func _read_resolution_fact(fact: String, cast: SpellResolutionContext, target) -> Dictionary:
	if not _same_actor(cast.resolution_window_target, target):
		return {"available": false}
	var receipt: Dictionary = cast.resolution_window
	var field := fact.trim_prefix("resolution.")
	if field == "window":
		return _identity_fact_value(receipt.get("window", ""))
	if not receipt.get("available_fields", []).has(field):
		return {"available": false}
	var value: Variant = receipt.get(field)
	if field in ["provisional_hit", "provisional_critical", "final_hit", "critical"]:
		return _boolean_fact_value(value)
	if field in ["roll_natural", "roll_modifier", "roll_total", "target_ac", "damage_occurrence_id", "damage_raw", "damage_resolved", "damage_hp_loss"]:
		return _numeric_fact_value(value)
	return _identity_fact_value(value)


static func _read_fact(fact: String, adapter: Object, target):
	if adapter == null or not adapter is SpellAdapter or adapter.cast == null:
		return {"available": false}
	var cast: SpellResolutionContext = adapter.cast
	match fact:
		"actor.id": return _actor_fact(cast.caster, "id")
		"actor.level": return _actor_fact(cast.caster, "level")
		"target.id": return _actor_fact(target, "id")
		"target.current_hp": return _actor_fact(target, "current_hp")
		"target.max_hp": return _actor_fact(target, "max_hp")
		"target.is_alive": return _actor_fact(target, "is_alive")
		"target.is_wounded": return _actor_fact(target, "is_wounded")
		"target.willingness": return _actor_willingness(target)
		"target.relationship": return _actor_relationship(cast, target)
		"target.charmed_by_actor": return _target_has_source_condition(target, cast.caster, "charmed")
		"target.marked_by_actor": return _target_has_source_condition(target, cast.caster, "hunters_mark")
		"target.actor_hex_distance_feet": return _actor_distance_feet(cast, cast.caster, target)
		"target.source_hex_distance_feet": return _source_distance_feet(cast, target)
		"target.first_round", "target.first_own_turn", "target.acted_since_combat_turn", "target.acted_since_owner_turn", "target.attacked_since_combat_turn", "target.attacked_since_owner_turn", "target.damage_raw_since_combat_turn", "target.damage_prevented_since_combat_turn", "target.damage_absorbed_since_combat_turn", "target.damage_resolved_since_combat_turn", "target.damage_hp_loss_since_combat_turn", "target.damage_raw_since_owner_turn", "target.damage_prevented_since_owner_turn", "target.damage_absorbed_since_owner_turn", "target.damage_resolved_since_owner_turn", "target.damage_hp_loss_since_owner_turn":
			if cast.spatial_host == null or cast.spatial_host.action_history == null:
				return {"available": false}
			return cast.spatial_host.action_history.fact(target, fact, cast.caster, str(cast.decisions.get("damage_source_instance_id", "")))
		"target.damage_raw_within_last_minute", "target.damage_prevented_within_last_minute", "target.damage_absorbed_within_last_minute", "target.damage_resolved_within_last_minute", "target.damage_hp_loss_within_last_minute":
			if not target is Character or not cast.caster is Character:
				return {"available": false}
			var damage_measure_name := fact.trim_prefix("target.damage_").trim_suffix("_within_last_minute")
			return target.recent_damage_measure(cast.caster.character_id, str(cast.decisions.get("damage_source_instance_id", "")), damage_measure_name, int(GameManager.campaign_elapsed_seconds))
		"source.id":
			var source_id: Variant = cast.effect_cast.get("source_id", cast.source_definition_id)
			return _identity_fact_value(source_id)
		"source.definition_id":
			return _identity_fact_value(cast.source_definition_id)
		"source.instance_id":
			return _identity_fact_value(cast.source_instance_id)
		"source.owner_id":
			return _identity_fact_value(cast.source_owner_id)
		"action.id": return _identity_fact_value(cast.action_id)
		"action.invocation_id": return _identity_fact_value(cast.action_invocation_id)
		"item.definition_id": return _item_fact(cast, "definition_id")
		"item.instance_id": return _item_fact(cast, "instance_id")
		"spell.definition_id": return _identity_fact_value(cast.spell_definition_id)
		"spell.invocation_id": return _identity_fact_value(cast.invocation_id)
		"resolution.window", "resolution.occurrence_id", "resolution.kind", "resolution.actor_id", "resolution.target_id", "resolution.action_id", "resolution.action_invocation_id", "resolution.spell_definition_id", "resolution.spell_invocation_id", "resolution.source_definition_id", "resolution.source_instance_id", "resolution.source_owner_id", "resolution.roll_natural", "resolution.roll_modifier", "resolution.roll_total", "resolution.target_ac", "resolution.provisional_hit", "resolution.provisional_critical", "resolution.final_hit", "resolution.critical", "resolution.damage_occurrence_id", "resolution.damage_type", "resolution.damage_raw", "resolution.damage_resolved", "resolution.damage_hp_loss":
			return _read_resolution_fact(fact, cast, target)
		"target.is_source_owner":
			var target_id: Dictionary = _actor_fact(target, "id")
			var source_owner: Dictionary = _read_fact("source.owner_id", adapter, target)
			if not target_id.get("available", false) or not source_owner.get("available", false): return {"available": false}
			return {"available": true, "value": str(target_id["value"]) == str(source_owner["value"])}
	return {"available": false}


static func _actor_willingness(actor) -> Dictionary:
	var value: Variant = actor.willingness if actor is Character else actor.get("willingness", null) if actor is Dictionary else null
	if value is String and value in ["willing", "unwilling"]:
		return {"available": true, "value": value}
	return {"available": false}


static func _actor_relationship(cast: SpellResolutionContext, target) -> Dictionary:
	if is_same(cast.caster, target):
		return {"available": true, "value": "ally"}
	var players: Variant = cast.decisions.get("players", null)
	var monsters: Variant = cast.decisions.get("monsters", null)
	if not players is Array or not monsters is Array:
		return {"available": false}
	var caster_side := _participant_side(cast.caster, players, monsters)
	var target_side := _participant_side(target, players, monsters)
	if caster_side.is_empty() or target_side.is_empty():
		return {"available": false}
	return {"available": true, "value": "ally" if caster_side == target_side else "enemy"}


static func _participant_side(actor, players: Array, monsters: Array) -> String:
	var player_match := false
	for entry in players:
		var participant = entry.get("character", entry) if entry is Dictionary else entry
		if is_same(actor, participant): player_match = true
	var monster_match := false
	for participant in monsters:
		if is_same(actor, participant): monster_match = true
	if player_match == monster_match: return ""
	return "players" if player_match else "monsters"


static func _target_has_source_condition(target, giver, condition: String) -> Dictionary:
	var giver_id := SpellEffects.caster_id(giver) if giver is Character else str(giver.get("id", "")) if giver is Dictionary else ""
	if giver_id.is_empty(): return {"available": false}
	var conditions: Dictionary = target.condition_sources if target is Character else target.get("condition_sources", {}) if target is Dictionary else {}
	var effects: Dictionary = target.spell_effects if target is Character else target.get("spell_effects", {}) if target is Dictionary else {}
	var grants: Variant = conditions.get(condition, {})
	if not grants is Dictionary or not effects is Dictionary: return {"available": false}
	for source_id in grants:
		if not effects.has(source_id): continue
		var record: Variant = effects[source_id]
		if not record is Dictionary or str(record.get("caster_id", "")) != giver_id: continue
		if not record.get("conditions", []) is Array or condition not in record["conditions"]: continue
		return {"available": true, "value": true}
	return {"available": true, "value": false}


static func _actor_distance_feet(cast: SpellResolutionContext, origin_actor, target_actor) -> Dictionary:
	var origin_position := _live_actor_position(cast, origin_actor)
	var target_position := _live_actor_position(cast, target_actor)
	if not origin_position.get("available", false) or not target_position.get("available", false):
		return {"available": false}
	return _numeric_fact_value(HexUtils.get_distance(origin_position["value"], target_position["value"]) * 5)


static func _source_distance_feet(cast: SpellResolutionContext, target_actor) -> Dictionary:
	var source_position := _live_source_position(cast)
	var target_position := _live_actor_position(cast, target_actor)
	if not source_position.get("available", false) or not target_position.get("available", false):
		return {"available": false}
	return _numeric_fact_value(HexUtils.get_distance(source_position["value"], target_position["value"]) * 5)


static func _live_actor_position(cast: SpellResolutionContext, actor) -> Dictionary:
	if actor == null:
		return {"available": false}
	var host := cast.spatial_host
	if host != null:
		var position := _position_from_live_entries(actor, host.players)
		if position.get("available", false):
			return position
		position = _position_from_live_entries(actor, host.monsters)
		if position.get("available", false):
			return position
		return {"available": false}
	# LocalRoomRules owns persisted party coordinates outside an encounter. Do not
	# fall back to hex_position on an actor projection when no live entry matched.
	if actor is Character and actor in PartyManager.get_active_characters():
		var room := LocalRoomCombat.room()
		var party_positions: Variant = room.get("party_positions", null)
		if party_positions is Dictionary and party_positions.has(actor.character_id):
			var coordinate: Variant = party_positions[actor.character_id]
			if coordinate is Array and coordinate.size() == 2 and _integer(coordinate[0], -100000, 100000) and _integer(coordinate[1], -100000, 100000):
				return {"available": true, "value": Vector2i(int(coordinate[0]), int(coordinate[1]))}
			if coordinate is Vector2i:
				return {"available": true, "value": coordinate}
	return {"available": false}


static func _position_from_live_entries(actor, entries: Array) -> Dictionary:
	for entry in entries:
		if not entry is Dictionary:
			continue
		var participant: Variant = entry.get("character", entry)
		# Runtime identity must match the actual live entity object. Matching only
		# a definition or actor ID would admit stale projections and duplicates.
		if not is_same(actor, participant):
			continue
		var position: Variant = entry.get("hex_position", null)
		if position is Vector2i:
			return {"available": true, "value": position}
		return {"available": false}
	return {"available": false}


static func _live_source_position(cast: SpellResolutionContext) -> Dictionary:
	if cast == null or cast.spatial_host == null or cast.spatial_host.areas == null:
		return {"available": false}
	# A definition ID is not a location. Only the exact live source instance can
	# resolve to a placed area center; removal erases this record from the owner.
	if cast.source_instance_id.is_empty():
		return {"available": false}
	var zones: Dictionary = cast.spatial_host.areas.active_spell_zones
	if not zones.has(cast.source_instance_id):
		return {"available": false}
	var zone: Variant = zones[cast.source_instance_id]
	if not zone is Dictionary or bool(zone.get("removed", false)):
		return {"available": false}
	var center: Variant = zone.get("center", null)
	if not center is Vector2i:
		return {"available": false}
	return {"available": true, "value": center}


static func _result_component(selector: Dictionary, adapter: Object, target, step_results: Array) -> Dictionary:
	if adapter == null or not adapter is SpellAdapter or adapter.cast == null:
		return {"success": false, "value": 0}
	var cast: SpellResolutionContext = adapter.cast
	var selected_target = target if selector.get("target") == "same" else cast.target
	var selected_step: Dictionary = {}
	for step_result in step_results:
		if not step_result is Dictionary:
			return {"success": false, "value": 0, "error": "Malformed prior step result."}
		if str(step_result.get("step_id", "")) != str(selector.get("step", "")):
			continue
		if not selected_step.is_empty():
			return {"success": false, "value": 0, "error": "Duplicate prior step results."}
		selected_step = step_result
	if selected_step.is_empty():
		return {"success": false, "value": 0, "error": "Referenced prior step result is absent."}
	var outcomes: Variant = selected_step.get("target_outcomes", null)
	if not outcomes is Array:
		return {"success": false, "value": 0, "error": "Malformed prior target outcomes."}
	var selected_outcome: Dictionary = {}
	for outcome in outcomes:
		if not outcome is Dictionary or not outcome.has("target") or outcome.get("target") == null:
			return {"success": false, "value": 0, "error": "Malformed prior target outcome."}
		if not _same_actor(outcome["target"], selected_target):
			continue
		if not selected_outcome.is_empty():
			return {"success": false, "value": 0, "error": "Ambiguous prior target outcome."}
		selected_outcome = outcome
	if selected_outcome.is_empty():
		return {"success": false, "value": 0, "error": "Referenced runtime target outcome is absent."}
	var measure := str(selector.get("measure", ""))
	if measure == "margin":
		var roll_result: Variant = selected_outcome.get("result", null)
		if not roll_result is Dictionary or not _integer(roll_result.get("numeric_margin", null), -1000000, 1000000):
			return {"success": false, "value": 0, "error": "Numeric roll margin is unavailable for this result."}
		return {"success": true, "value": int(roll_result["numeric_margin"])}
	if measure == "hp_after":
		var hp_after: Variant = selected_outcome.get("hp_after", null)
		if not _integer(hp_after, 0, 1000000):
			return {"success": false, "value": 0, "error": "Post-settlement target HP receipt is unavailable."}
		return {"success": true, "value": int(hp_after)}
	if measure == "healed":
		var effect_result: Variant = selected_outcome.get("result", null)
		if not effect_result is Dictionary or not _integer(effect_result.get("healing", null), 0, 1000000):
			return {"success": false, "value": 0, "error": "Actual healing receipt is unavailable."}
		return {"success": true, "value": int(effect_result["healing"])}
	var components: Variant = selected_outcome.get("damage_components", null)
	if not components is Array:
		return {"success": false, "value": 0, "error": "Prior damage components are unavailable."}
	var selected_component: Dictionary = {}
	for component in components:
		if not component is Dictionary or not component.has("type"):
			return {"success": false, "value": 0, "error": "Malformed prior damage component."}
		if str(component.get("type", "")) != str(selector.get("component", "")):
			continue
		if selector.has("component_id") and str(component.get("component_id", "")) != str(selector["component_id"]):
			continue
		if not selected_component.is_empty():
			return {"success": false, "value": 0, "error": "Ambiguous prior damage component; specify component_id."}
		selected_component = component
	if selected_component.is_empty():
		return {"success": false, "value": 0, "error": "Referenced typed damage component is absent."}
	var amount: Variant = selected_component.get(measure, null)
	if not _integer(amount, 0, 1000000):
		return {"success": false, "value": 0, "error": "Prior damage measure is unavailable."}
	return {"success": true, "value": int(amount)}


static func _result_component_sum(selector: Dictionary, step_results: Array) -> Dictionary:
	var selected_step: Dictionary = {}
	for step_result in step_results:
		if not step_result is Dictionary:
			return {"success": false, "value": 0, "error": "Malformed prior step result."}
		if str(step_result.get("step_id", "")) == str(selector.get("step", "")):
			if not selected_step.is_empty():
				return {"success": false, "value": 0, "error": "Duplicate prior step results."}
			selected_step = step_result
	if selected_step.is_empty():
		return {"success": false, "value": 0, "error": "Referenced prior step result is absent."}
	if str(selected_step.get("type", "")) not in ["attack", "save", "damage"]:
		return {"success": false, "value": 0, "error": "Referenced prior step result has an unsupported type."}
	var outcomes: Variant = selected_step.get("target_outcomes", null)
	if not outcomes is Array:
		return {"success": false, "value": 0, "error": "Referenced prior step outcomes are malformed."}
	var total := 0
	var seen_targets: Array = []
	for outcome in outcomes:
		if not outcome is Dictionary or not outcome.has("target") or outcome.get("target") == null or not (outcome["target"] is Character or outcome["target"] is Dictionary):
			return {"success": false, "value": 0, "error": "Referenced prior target outcome is malformed."}
		if outcome.has("skipped") and not outcome["skipped"] is bool:
			return {"success": false, "value": 0, "error": "Referenced prior skipped state is malformed."}
		if bool(outcome.get("skipped", false)):
			continue
		var duplicate_target := false
		for seen_target in seen_targets:
			if _same_actor(seen_target, outcome["target"]):
				duplicate_target = true
				break
		if duplicate_target:
			continue
		seen_targets.append(outcome["target"])
		var components: Variant = outcome.get("damage_components", null)
		var explicit_zero_damage: bool = outcome.has("damage") and _integer(outcome["damage"], 0, 1000000) and int(outcome["damage"]) == 0
		var explicit_no_damage: bool = explicit_zero_damage and ((outcome.has("hit") and outcome["hit"] is bool and not bool(outcome["hit"])) or (outcome.has("saved") and outcome["saved"] is bool and bool(outcome["saved"])))
		if not components is Array:
			if explicit_no_damage:
				continue
			return {"success": false, "value": 0, "error": "Referenced target damage components are absent or malformed."}
		var component_found := false
		for component in components:
			if not component is Dictionary or not component.has("type"):
				return {"success": false, "value": 0, "error": "Referenced damage component is malformed."}
			if str(component.get("type", "")) != str(selector.get("component", "")):
				continue
			var measure := str(selector.get("measure", ""))
			var amount: Variant = component.get(measure, null)
			if not _integer(amount, 0, 1000000):
				return {"success": false, "value": 0, "error": "Referenced damage measure is absent or malformed."}
			total += int(amount)
			component_found = true
			break
		if not component_found and not explicit_no_damage:
			return {"success": false, "value": 0, "error": "Referenced target is missing the selected damage component."}
	return {"success": true, "value": total}


static func _result_reduce(selector: Dictionary, adapter: Variant, target, step_results: Array) -> Dictionary:
	var cast = adapter.get("cast") if adapter is Object else null
	var selected_target = target if selector.get("targets") == "same" else (cast.target if selector.get("targets") == "cast_target" and cast != null else null)
	if selector.get("targets") != "all" and selected_target == null:
		return {"success": false, "value": 0, "error": "Selected reducer target is unavailable."}
	var selected_values: Array[int] = []
	var measure := str(selector.get("measure", ""))
	var component_type := str(selector.get("component", ""))
	var component_id := str(selector.get("component_id", ""))
	for requested_step in selector.get("steps", []):
		var selected_step: Dictionary = {}
		for step_result in step_results:
			if not step_result is Dictionary:
				return {"success": false, "value": 0, "error": "Malformed prior step result."}
			if str(step_result.get("step_id", "")) != str(requested_step):
				continue
			if not selected_step.is_empty():
				return {"success": false, "value": 0, "error": "Duplicate prior step results."}
			selected_step = step_result
		if selected_step.is_empty():
			return {"success": false, "value": 0, "error": "Selected reducer step is absent or unfinished."}
		if str(selected_step.get("type", "")) not in ["attack", "save", "damage"]:
			return {"success": false, "value": 0, "error": "Selected reducer step has an unsupported type."}
		var outcomes: Variant = selected_step.get("target_outcomes", null)
		if not outcomes is Array:
			return {"success": false, "value": 0, "error": "Selected reducer target outcomes are malformed."}
		var seen_targets: Array = []
		for outcome in outcomes:
			if not outcome is Dictionary or not outcome.has("target") or outcome.get("target") == null or not (outcome["target"] is Character or outcome["target"] is Dictionary):
				return {"success": false, "value": 0, "error": "Selected reducer target outcome is malformed."}
			if outcome.has("skipped") and not outcome["skipped"] is bool:
				return {"success": false, "value": 0, "error": "Selected reducer skipped state is malformed."}
			if bool(outcome.get("skipped", false)):
				continue
			if selector.get("targets") != "all" and not _same_actor(outcome["target"], selected_target):
				continue
			var duplicate_target := false
			for seen_target in seen_targets:
				if _same_actor(seen_target, outcome["target"]):
					duplicate_target = true
					break
			if duplicate_target:
				return {"success": false, "value": 0, "error": "Duplicate target outcome would count a settled receipt twice."}
			seen_targets.append(outcome["target"])
			var components: Variant = outcome.get("damage_components", null)
			var explicit_zero_damage: bool = outcome.has("damage") and _integer(outcome["damage"], 0, 1000000) and int(outcome["damage"]) == 0
			var explicit_no_damage: bool = explicit_zero_damage and ((outcome.get("hit") is bool and not outcome["hit"]) or (outcome.get("saved") is bool and outcome["saved"]))
			if explicit_no_damage and (components == null or (components is Array and components.is_empty())):
				continue
			if not components is Array:
				return {"success": false, "value": 0, "error": "Selected target damage components are missing or malformed."}
			var matches: Array = []
			for component in components:
				if not component is Dictionary or not component.has("type"):
					return {"success": false, "value": 0, "error": "Selected damage component is malformed."}
				if str(component.get("type", "")) != component_type:
					continue
				if not component_id.is_empty() and str(component.get("component_id", "")) != component_id:
					continue
				matches.append(component)
			if matches.size() != 1:
				return {"success": false, "value": 0, "error": "Selected target has a missing or ambiguous damage component."}
			var amount: Variant = matches[0].get(measure, null)
			if not _integer(amount, 0, 1000000):
				return {"success": false, "value": 0, "error": "Selected damage measure is missing or malformed."}
			selected_values.append(int(amount))
	if selected_values.is_empty():
		if str(selector.get("reducer", "")) == "sum":
			return {"success": true, "value": 0}
		return {"success": false, "value": 0, "error": "Minimum and maximum are unavailable for an empty selection."}
	var result := selected_values[0]
	for index in range(1, selected_values.size()):
		match str(selector.get("reducer", "")):
			"sum": result += selected_values[index]
			"min": result = mini(result, selected_values[index])
			"max": result = maxi(result, selected_values[index])
	return {"success": true, "value": result}


static func evaluate_formula(value: Variant, adapter: Variant, target, step_results: Array) -> Dictionary:
	if value is int or value is float: return {"success": true, "value": int(value)}
	if value is String:
		var cast = adapter.get("cast")
		var roller: Character = cast.caster if cast != null else null
		return {"success": true, "value": Dice.parse_dice_string(value, {}, roller)}
	if not value is Dictionary: return {"success": false, "value": 0}
	var cast = adapter.get("cast")
	if value.has("input_value"): return SpellFormulaInputs.read(cast, str(value.input_value))
	if value.has("source_die"): return SpellFormulaInputs.source_die(value.source_die, cast, target, step_results)
	if str(value.get("op", "")) in ["breakpoint_lookup", "progression_lookup"]:
		var input_result := evaluate_formula(value.get("input"), adapter, target, step_results)
		if not bool(input_result.get("success", false)):
			return {"success": false, "value": 0, "error": str(input_result.get("error", "Breakpoint lookup input failed."))}
		var input_value := int(input_result.get("value", 0))
		var selected := false
		var selected_value := 0
		for row in value.get("breakpoints", []):
			if input_value < int(row.get("threshold", 0)):
				break
			selected = true
			selected_value = int(row.get("value", 0))
		if not selected:
			if value.get("below_first") == "zero": return {"success":true,"value":0}
			return {"success": false, "value": 0, "error": "Breakpoint lookup input is below the first threshold."}
		return {"success": true, "value": selected_value, "input":input_value, "value_type":str(value.get("value_type", "number"))}
	if value.has("caster_level") or value.has("caster_proficiency_bonus") or value.has("caster_class_level") or value.has("caster_ability_modifier") or value.has("selected_slot_level"):
		var caster: Character = cast.caster if cast != null else adapter.get("actor")
		if value.size() != 1 or not caster is Character: return {"success": false, "value": 0}
		if value.has("caster_level") and value["caster_level"] is bool and value["caster_level"]: return {"success": true, "value": caster.level}
		if value.has("caster_proficiency_bonus") and value["caster_proficiency_bonus"] is bool and value["caster_proficiency_bonus"]: return {"success": true, "value": caster.proficiency_bonus}
		if value.has("caster_class_level") and value["caster_class_level"] is String:
			var class_level := caster.get_class_level(str(value["caster_class_level"]))
			return {"success":class_level >= 0,"value":class_level}
		if value.has("caster_ability_modifier") and value["caster_ability_modifier"] is String and str(value["caster_ability_modifier"]) in ABILITIES:
			return {"success": true, "value": caster.ability_scores.get_ability_modifier(str(value["caster_ability_modifier"]))}
		if value.has("selected_slot_level") and value["selected_slot_level"] is bool and value["selected_slot_level"] and cast != null: return {"success": true, "value": int(cast.slot_level)}
		return {"success": false, "value": 0}
	if value.has("result"): return _result_component(value["result"], adapter, target, step_results)
	if value.has("result_sum"): return _result_component_sum(value["result_sum"], step_results)
	if value.has("result_reduce"): return _result_reduce(value["result_reduce"], adapter, target, step_results)
	var left := evaluate_formula(value.get("left"), adapter, target, step_results)
	var right := evaluate_formula(value.get("right"), adapter, target, step_results)
	if not left.success or not right.success: return {"success": false, "value": 0}
	var a := int(left.value)
	var b := int(right.value)
	match str(value.get("op", "")):
		"add": return {"success": true, "value": a + b}
		"subtract": return {"success": true, "value": a - b}
		"multiply": return {"success": true, "value": a * b}
		"floor_divide": return {"success": b > 0, "value": int(floor(float(a) / float(b))) if b > 0 else 0}
		"min": return {"success": true, "value": mini(a, b)}
		"max": return {"success": true, "value": maxi(a, b)}
	return {"success": false, "value": 0}


## Evaluate the same shared formula vocabulary against an owned actor, outside a cast.
static func evaluate_actor_formula(value: Variant, actor: Character) -> Dictionary:
	if actor == null:
		return {"success": false, "value": 0}
	if _actor_formula_has_cast_only_reference(value):
		return {"success": false, "value": 0}
	return evaluate_formula(value, {"actor": actor}, null, [])


## Progression binds only the existing shared actor identity and level facts.
static func validate_actor_predicate(predicate: Variant) -> String:
	var error := _validate_predicate(predicate, {}, 0)
	if not error.is_empty(): return error
	return _actor_predicate_scope_error(predicate)


static func _actor_predicate_scope_error(predicate: Dictionary) -> String:
	for key in ["all", "any"]:
		if predicate.has(key):
			for child in predicate[key]:
				var error := _actor_predicate_scope_error(child)
				if not error.is_empty(): return error
			return ""
	if predicate.has("not"): return _actor_predicate_scope_error(predicate["not"])
	if predicate.get("fact", "") not in ["actor.id", "actor.level"]:
		return "Progression predicates require actor.id or actor.level facts."
	return ""


## Reuse shared typed comparisons and unknown propagation; no target/cast facts are authorized.
static func evaluate_actor_predicate(predicate: Dictionary, actor: Character) -> bool:
	if actor == null or not validate_actor_predicate(predicate).is_empty(): return false
	var context := SpellResolutionContext.new()
	context.caster = actor
	return evaluate_predicate(predicate, SpellAdapter.new(context), null, [])


static func _actor_formula_has_cast_only_reference(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	if value.has("input_value") or value.has("source_die") or value.has("result") or value.has("result_sum") or value.has("result_reduce") or value.has("selected_slot_level"):
		return true
	if str(value.get("op", "")) in ["breakpoint_lookup", "progression_lookup"]:
		return _actor_formula_has_cast_only_reference(value.get("input"))
	if str(value.get("op", "")) in FORMULA_OPS:
		return _actor_formula_has_cast_only_reference(value.get("left")) or _actor_formula_has_cast_only_reference(value.get("right"))
	return false


static func evaluate_predicate(predicate: Dictionary, adapter: Object, target, step_results: Array) -> bool:
	return _evaluate_predicate_state(predicate, adapter, target, step_results) == PREDICATE_TRUE


static func _evaluate_predicate_state(predicate: Dictionary, adapter: Object, target, step_results: Array) -> int:
	if predicate.has("child_group"):
		return _child_group_state(predicate.child_group, adapter, target, step_results)
	if predicate.has("all"):
		var has_unknown := false
		for child in predicate["all"]:
			var child_state := _evaluate_predicate_state(child, adapter, target, step_results)
			if child_state == PREDICATE_FALSE: return PREDICATE_FALSE
			if child_state == PREDICATE_UNKNOWN: has_unknown = true
		return PREDICATE_UNKNOWN if has_unknown else PREDICATE_TRUE
	if predicate.has("any"):
		var has_unknown := false
		for child in predicate["any"]:
			var child_state := _evaluate_predicate_state(child, adapter, target, step_results)
			if child_state == PREDICATE_TRUE: return PREDICATE_TRUE
			if child_state == PREDICATE_UNKNOWN: has_unknown = true
		return PREDICATE_UNKNOWN if has_unknown else PREDICATE_FALSE
	if predicate.has("not"):
		var child_state := _evaluate_predicate_state(predicate["not"], adapter, target, step_results)
		if child_state == PREDICATE_UNKNOWN: return PREDICATE_UNKNOWN
		return PREDICATE_FALSE if child_state == PREDICATE_TRUE else PREDICATE_TRUE
	var actual: Variant
	if predicate.has("fact"):
		var fact_value: Dictionary = _read_fact(str(predicate["fact"]), adapter, target)
		if not fact_value.get("available", false): return PREDICATE_UNKNOWN
		actual = fact_value.get("value")
	else:
		var selected_result := _result_component_sum(predicate["result_sum"], step_results) if predicate.has("result_sum") else (_result_reduce(predicate["result_reduce"], adapter, target, step_results) if predicate.has("result_reduce") else _result_component(predicate["result"], adapter, target, step_results))
		if not bool(selected_result.get("success", false)): return PREDICATE_UNKNOWN
		actual = selected_result.get("value", 0)
	var expected: Variant = predicate.get("eq", predicate.get("ne", predicate.get("lt", predicate.get("lte", predicate.get("gt", predicate.get("gte"))))))
	if predicate.has("fact"):
		var fact_name := str(predicate["fact"])
		var numeric_fact := fact_name in ["actor.level", "target.current_hp", "target.max_hp", "target.actor_hex_distance_feet", "target.source_hex_distance_feet", "resolution.roll_natural", "resolution.roll_modifier", "resolution.roll_total", "resolution.target_ac", "resolution.damage_occurrence_id", "resolution.damage_raw", "resolution.damage_resolved", "resolution.damage_hp_loss"] or fact_name in DAMAGE_HISTORY_FACTS
		var boolean_fact := fact_name in ["target.is_alive", "target.is_wounded", "target.is_source_owner", "target.charmed_by_actor", "target.marked_by_actor", "target.first_round", "target.first_own_turn", "target.acted_since_combat_turn", "target.acted_since_owner_turn", "target.attacked_since_combat_turn", "target.attacked_since_owner_turn", "resolution.provisional_hit", "resolution.provisional_critical", "resolution.final_hit", "resolution.critical"]
		if numeric_fact and (not (actual is int or actual is float) or actual is bool or not (expected is int or expected is float) or expected is bool): return PREDICATE_UNKNOWN
		if boolean_fact and (not actual is bool or not expected is bool): return PREDICATE_UNKNOWN
		if _is_string_fact(fact_name) and (not actual is String or not expected is String): return PREDICATE_UNKNOWN
	else:
		if not (actual is int or actual is float) or actual is bool or not (expected is int or expected is float) or expected is bool: return PREDICATE_UNKNOWN
	if (expected is bool and not actual is bool) or (actual is bool and not expected is bool):
		return PREDICATE_UNKNOWN
	var comparison_name := "eq" if predicate.has("eq") else ("ne" if predicate.has("ne") else ("lt" if predicate.has("lt") else ("lte" if predicate.has("lte") else ("gt" if predicate.has("gt") else "gte"))))
	if comparison_name in ["lt", "lte", "gt", "gte"] and (not (actual is int or actual is float) or actual is bool or not (expected is int or expected is float) or expected is bool):
		return PREDICATE_UNKNOWN
	match comparison_name:
		"eq": return PREDICATE_TRUE if actual == expected else PREDICATE_FALSE
		"ne": return PREDICATE_TRUE if actual != expected else PREDICATE_FALSE
		"lt": return PREDICATE_TRUE if float(actual) < float(expected) else PREDICATE_FALSE
		"lte": return PREDICATE_TRUE if float(actual) <= float(expected) else PREDICATE_FALSE
		"gt": return PREDICATE_TRUE if float(actual) > float(expected) else PREDICATE_FALSE
		"gte": return PREDICATE_TRUE if float(actual) >= float(expected) else PREDICATE_FALSE
	return PREDICATE_UNKNOWN


static func validate_spatial_context_for_steps(steps: Array, decisions: Dictionary) -> String:
	for step in steps:
		if not step is Dictionary:
			continue
		if str(step.get("target", "target")) == "area":
			if not decisions.has("area_targets"):
				if not decisions.has("grid") or decisions.get("grid") == null:
					return "Area targeting requires encounter grid and participants."
				var players = decisions.get("players", [])
				var monsters = decisions.get("monsters", [])
				var players_empty: bool = not (players is Array and not players.is_empty())
				var monsters_empty: bool = not (monsters is Array and not monsters.is_empty())
				if players_empty and monsters_empty:
					return "Area targeting requires encounter grid and participants."
	return ""


static func validate_step(step: Variant, step_index: int, step_ids: Dictionary, all_steps: Array = [], context: String = "") -> String:
	if not step is Dictionary:
		return "Shared step must be an object."
	var allowed_fields: Array = SPELL_STEP_FIELDS if context == "spell" else (EVENT_STEP_FIELDS if (context == "zero_hp_replacement" or context == "event") else (SPELL_STEP_FIELDS + ["save_ability", "dc_base", "dc_add_damage", "replacement_hp"]))
	var allowed_types: Array = SPELL_STEP_TYPES if context == "spell" else (EVENT_STEP_TYPES if (context == "zero_hp_replacement" or context == "event") else STEP_TYPES)
	for key in step:
		if not key is String:
			return "Shared step keys must be strings."
		if str(key) not in allowed_fields:
			return "Unsupported shared step field '%s'." % str(key)
	if step.has("incoming_negation_rule"):
		var negation_error := CastInterruptionRules.incoming_negation_rule_error(step.incoming_negation_rule)
		if not negation_error.is_empty(): return negation_error
	if step.has("physical_requirements"):
		var physical_error := PhysicalFactsRules.physical_requirements_error(step.physical_requirements)
		if not physical_error.is_empty(): return physical_error
	if step.has("spatial_requirements"):
		var spatial_error := PhysicalFactsRules.spatial_requirements_error(step.spatial_requirements)
		if not spatial_error.is_empty(): return spatial_error
	if not step.has("id") or not step["id"] is String or str(step["id"]).is_empty():
		return "Shared steps require a string id."
	var step_id := str(step["id"])
	if step_ids.has(step_id):
		return "Duplicate step id '%s'." % step_id
	if not step.has("type") or not step["type"] is String:
		return "Shared step type must be a string."
	var step_type := str(step["type"])
	if step_type not in allowed_types:
		return "Unsupported shared step type '%s'." % step_type
	if step.has("damage_scale_by_outcome"):
		if step_type not in ["attack", "save"]: return "damage_scale_by_outcome requires an attack or save step."
		if not step.has("damage") and not step.has("damage_components"): return "damage_scale_by_outcome requires a damage payload."
		var scale_error := SharedSpell.validate_outcome_map(step["damage_scale_by_outcome"], SharedSpell.outcome_domain_for_delivery(step_type == "attack"), "damage_scale_by_outcome")
		if not scale_error.is_empty(): return scale_error
	if step.has("effects") and step["effects"] is Array and step_type in ["attack", "save"]:
		for effect in step["effects"]:
			if effect is Dictionary and effect.has("rider_by_outcome"):
				var rider_error := SharedSpell.validate_outcome_map(effect["rider_by_outcome"], SharedSpell.outcome_domain_for_delivery(step_type == "attack"), "rider_by_outcome", true)
				if not rider_error.is_empty(): return rider_error
	if step.has("effects") and step["effects"] is Array and step_type not in ["attack", "save"]:
		for effect in step["effects"]:
			if effect is Dictionary and effect.has("rider_by_outcome"): return "rider_by_outcome requires an attack or save step."
	var gate := "always"
	if step.has("gate"):
		if not step["gate"] is String:
			return "Shared step gate must be a string."
		gate = str(step["gate"])
		if gate not in STEP_GATES:
			return "Unsupported shared step gate '%s'." % gate
	if gate != "always" and step_index == 0:
		return "First step cannot specify gate without prerequisite."
	if step.has("gate_step") or (gate != "always" and step_index > 0):
		var ref = step.get("gate_step", step_index - 1)
		var ref_idx := -1
		if ref is int and not ref is bool:
			ref_idx = ref
		elif ref is String and step_ids.has(ref):
			ref_idx = int(step_ids[ref])
		else:
			return "Step '%s' references nonexistent or forward step '%s'." % [step_id, str(ref)]
		if ref_idx < 0 or ref_idx >= step_index:
			return "Step '%s' references nonexistent or forward step '%s'." % [step_id, str(ref)]
		if not all_steps.is_empty() and ref_idx < all_steps.size():
			var ref_step: Dictionary = all_steps[ref_idx]
			var ref_type: String = str(ref_step.get("type", ""))
			if gate in ["hit", "miss"] and ref_type != "attack":
				return "Gate '%s' on step '%s' requires an attack step prerequisite." % [gate, step_id]
			if gate in ["failed_save", "successful_save"] and ref_type != "save":
				return "Gate '%s' on step '%s' requires a save step prerequisite." % [gate, step_id]
			var ref_target: String = str(ref_step.get("target", "target"))
			var cur_target: String = str(step.get("target", "target"))
			if ref_target == "self" and cur_target != "self":
				return "Step '%s' with target '%s' cannot gate on self step '%s'." % [step_id, cur_target, str(ref_step.get("id", ref_idx))]
			if ref_target == "area" and cur_target == "self":
				return "Step '%s' with target 'self' cannot gate on area step '%s'." % [step_id, str(ref_step.get("id", ref_idx))]
	var step_target := "target"
	if step.has("target"):
		if not step["target"] is String:
			return "Shared step target must be a string."
		step_target = str(step["target"])
		if context in ["zero_hp_replacement", "event"]:
			if step_target != "target":
				return "Unsupported zero_hp_replacement step target '%s'; expected 'target'." % step_target
		else:
			if step_target not in ["target", "self", "area"]:
				return "Unsupported shared step target '%s'." % step_target
	if step_target == "area":
		if not step.get("shape") is String or step["shape"] not in ["sphere", "cone", "cube"]:
			return "Shared step area requires a supported shape."
		var geom_key := "radius" if step.get("shape") == "sphere" else "size"
		if not _integer(step.get(geom_key), 1, 100):
			return "Shared step area requires a positive integer radius/size."

	if step.has("scaling"):
		if not step["scaling"] is Dictionary:
			return "Shared %s step scaling must be an object." % step_type
		if not step.has("damage"):
			return "Shared %s step scaling requires damage payload." % step_type
		for threshold in step["scaling"]:
			if not str(threshold).is_valid_int() or int(threshold) < 1 or int(threshold) > 20 or not _formula(step["scaling"][threshold]):
				return "Invalid shared damage scaling."

	if step.has("upcast"):
		if not step["upcast"] is Dictionary:
			return "Shared %s step upcast must be an object." % step_type
		if not step.has("damage"):
			return "Shared %s step upcast requires damage payload." % step_type
		for key in step["upcast"]:
			if key == "damage_per_level":
				if not step["upcast"][key] is String or not SharedSpell._dice_formula(step["upcast"][key]):
					return "Shared upcast dice must be a plain dice expression."
			elif key in ["starting_level", "levels_per_increment"]:
				if not _integer(step["upcast"][key], 0, 100):
					return "Invalid shared upcast amount."
			else:
				return "Unsupported shared step upcast operation '%s'." % key
	if step.has("component_id") and (not step["component_id"] is String or str(step["component_id"]).is_empty()):
		return "Damage component_id must be a non-empty string."
	if step.has("damage_components"):
		if step_type != "save" or not step["damage_components"] is Array or step["damage_components"].is_empty():
			return "damage_components are supported only as a non-empty save-step component list."
		var component_ids: Array[String] = []
		var type_counts: Dictionary = {}
		for component in step["damage_components"]:
			if not component is Dictionary or not _formula(component.get("damage")) or not component.get("damage_type") is String or str(component["damage_type"]) not in DataLoader.VALID_DAMAGE_TYPES:
				return "Each damage component requires a valid damage formula and damage_type."
			if component.has("id") and (not component["id"] is String or str(component["id"]).is_empty()):
				return "Damage component id must be a non-empty string."
			var component_type := str(component["damage_type"])
			var component_id := str(component.get("id", "%s:%d" % [component_type, int(type_counts.get(component_type, 0)) + 1]))
			if component_id in component_ids:
				return "Damage component ids must be unique within a step."
			component_ids.append(component_id)
			type_counts[component_type] = int(type_counts.get(component_type, 0)) + 1
	if step.has("damage_reductions") or step.has("damage_bypasses"):
		var policy_component_ids: Array[String] = []
		if step.has("damage_components"):
			var policy_type_counts: Dictionary = {}
			for component in step["damage_components"]:
				var component_type := str(component.get("damage_type", ""))
				var component_id := str(component.get("id", "%s:%d" % [component_type, int(policy_type_counts.get(component_type, 0)) + 1]))
				policy_component_ids.append(component_id)
				policy_type_counts[component_type] = int(policy_type_counts.get(component_type, 0)) + 1
		elif step.has("damage_type"):
			policy_component_ids.append(str(step.get("component_id", "%s:%s" % [step_id, str(step.get("damage_type", ""))])))
		if policy_component_ids.is_empty():
			return "Damage policies require a typed damage payload."
		var damage_policy_error := validate_damage_policy(step.get("damage_reductions", []), step.get("damage_bypasses", []), policy_component_ids)
		if not damage_policy_error.is_empty(): return damage_policy_error

	if step.has("effects"):
		if not step["effects"] is Array:
			return "Shared step effects must be an array."
		for eff in step["effects"]:
			var err := SharedSpell._validate_single_effect(eff)
			if not err.is_empty(): return err
			if eff is Dictionary and eff.has("value") and eff["value"] is Dictionary:
				var value_err := _validate_formula_expression(eff["value"], step_ids, step_index, all_steps)
				if not value_err.is_empty(): return value_err
			if eff is Dictionary and eff.has("when"):
				var effect_when_err := _validate_predicate(eff["when"], step_ids, step_index, all_steps)
				if not effect_when_err.is_empty(): return effect_when_err
	if step.has("when"):
		var when_err := _validate_predicate(step["when"], step_ids, step_index, all_steps)
		if not when_err.is_empty(): return when_err

	match step_type:
		"attack":
			if not step.get("attack_type") is String or step.get("attack_type") not in ["ranged_spell", "melee_spell"]:
				return "Shared attack step requires a spell attack delivery."
			if not step.has("damage") or not _formula(step["damage"]) or not step.get("damage_type") is String or step.get("damage_type") not in DataLoader.VALID_DAMAGE_TYPES:
				return "Shared attack step requires valid damage and damage type."
		"save":
			if context == "spell":
				if not step.has("save") or not step["save"] is String or step["save"] not in ABILITIES:
					return "Shared save step requires a valid ability."
				if step.has("dc_base") or step.has("dc_add_damage") or step.has("save_ability"):
					return "Spell save step cannot declare dc_base, dc_add_damage, or save_ability."
				if step.has("half_on_save") and not step["half_on_save"] is bool:
					return "half_on_save must be a boolean."
				if step.has("damage") and (not _formula(step["damage"]) or not step.get("damage_type") is String or step.get("damage_type") not in DataLoader.VALID_DAMAGE_TYPES):
					return "Shared save step damage requires valid formula and damage type."
				if step.has("damage_components") and step.has("damage"):
					return "Shared save step chooses damage or damage_components, not both."
			else:
				var ability_val = step.get("save", step.get("save_ability", ""))
				if not ability_val is String or ability_val not in ABILITIES:
					return "Shared save step requires a valid ability."
				if step.has("dc_base") and not _integer(step["dc_base"], 0, 100):
					return "Shared save step dc_base must be an integer between 0 and 100."
				if step.has("dc_add_damage") and not step["dc_add_damage"] is bool:
					return "Shared save step dc_add_damage must be a boolean."
		"damage":
			if not step.has("damage") or not _formula(step["damage"]) or not step.get("damage_type") is String or step.get("damage_type") not in DataLoader.VALID_DAMAGE_TYPES:
				return "Shared damage step requires valid damage and damage type."
		"effect":
			if not step.has("effects") or not step["effects"] is Array or step["effects"].is_empty():
				return "Shared effect step requires a non-empty effects array."
			for eff in step["effects"]:
				var err := SharedSpell._validate_single_effect(eff)
				if not err.is_empty(): return err
		"replace_hp":
			if not step.has("replacement_hp") or not _integer(step["replacement_hp"], 1, 9999):
				return "Shared replace_hp step requires a positive integer replacement_hp."
	return ""


static func validate_steps(steps: Variant, context: String = "") -> String:
	if not steps is Array or steps.is_empty():
		return "Shared steps must be a non-empty array."
	var step_ids: Dictionary = {}
	for i in steps.size():
		var err := validate_step(steps[i], i, step_ids, steps, context)
		if not err.is_empty():
			return err
		step_ids[str(steps[i]["id"])] = i
	return ""


static func validate_zero_hp_replacement_rule(rule: Variant) -> String:
	if not rule is Dictionary:
		return "zero_hp_replacement rule must be an object."
	for key in rule:
		if not key is String:
			return "zero_hp_replacement rule keys must be strings."
		if str(key) not in ZERO_HP_RULE_FIELDS:
			return "Unsupported zero_hp_replacement field '%s'." % str(key)
	if rule.has("id") and not rule["id"] is String:
		return "zero_hp_replacement rule id must be a string."
	if rule.has("name") and not rule["name"] is String:
		return "zero_hp_replacement rule name must be a string."
	if rule.has("type"):
		if not rule["type"] is String or rule["type"] != "zero_hp_replacement":
			return "Unsupported type '%s' for zero_hp_replacement; expected 'zero_hp_replacement'." % str(rule["type"])
	if rule.has("trigger"):
		if not rule["trigger"] is String or rule["trigger"] != "zero_hp":
			return "Unsupported trigger '%s' for zero_hp_replacement; expected 'zero_hp'." % str(rule["trigger"])
	if not rule.has("type") and not rule.has("trigger"):
		return "zero_hp_replacement rule requires type 'zero_hp_replacement' and trigger 'zero_hp'."
	if rule.has("bypass_damage_types"):
		if not rule["bypass_damage_types"] is Array:
			return "bypass_damage_types must be an array of strings."
		for dt in rule["bypass_damage_types"]:
			if not dt is String or dt.to_lower() not in DataLoader.VALID_DAMAGE_TYPES:
				return "Invalid bypass damage type '%s'." % str(dt)
	if rule.has("bypass_critical") and not rule["bypass_critical"] is bool:
		return "bypass_critical must be a boolean."
	if rule.has("steps"):
		var steps_err := validate_steps(rule["steps"], "zero_hp_replacement")
		if not steps_err.is_empty():
			return steps_err
	else:
		var ability_val = rule.get("save_ability", rule.get("save", ""))
		if not ability_val is String or ability_val not in ABILITIES:
			return "zero_hp_replacement requires a valid save_ability."
		if not _integer(rule.get("dc_base", 5), 0, 100):
			return "zero_hp_replacement requires integer dc_base (0-100)."
		if rule.has("dc_add_damage") and not rule["dc_add_damage"] is bool:
			return "dc_add_damage must be a boolean."
		if not _integer(rule.get("replacement_hp", 1), 1, 9999):
			return "zero_hp_replacement requires a positive integer replacement_hp."
	return ""


static func validate_monster_special_abilities(monster: Dictionary) -> String:
	var abilities: Variant = monster.get("special_abilities", [])
	if not abilities is Array:
		return "special_abilities must be an array."
	for ability in abilities:
		if not ability is Dictionary:
			return "special_ability must be an object."
		if ability.has("type") and not ability["type"] is String:
			return "special_ability type must be a string."
		if ability.has("trigger") and not ability["trigger"] is String:
			return "special_ability trigger must be a string."
		var a_type := str(ability.get("type", ""))
		var a_trigger := str(ability.get("trigger", ""))
		if a_type == "zero_hp_replacement" or a_trigger == "zero_hp" or ability.has("steps") or a_type.begins_with("zero_hp") or a_trigger.begins_with("zero_hp"):
			var err := validate_zero_hp_replacement_rule(ability)
			if not err.is_empty():
				return err
	return ""


static func canonicalize_rule(rule: Dictionary) -> Dictionary:
	var canon := rule.duplicate(true)
	if not canon.has("steps"):
		var ability: String = str(canon.get("save", canon.get("save_ability", "CON")))
		var dc_base: int = int(canon.get("dc_base", 5))
		var dc_add_damage: bool = bool(canon.get("dc_add_damage", true))
		var replacement_hp: int = int(canon.get("replacement_hp", 1))
		canon["steps"] = [
			{
				"id": "zero_hp_save",
				"type": "save",
				"target": "target",
				"save": ability,
				"dc_base": dc_base,
				"dc_add_damage": dc_add_damage
			},
			{
				"id": "zero_hp_replacement",
				"type": "replace_hp",
				"target": "target",
				"gate": "successful_save",
				"gate_step": "zero_hp_save",
				"replacement_hp": replacement_hp
			}
		]
	return canon


static func get_zero_hp_replacement_rule(target) -> Dictionary:
	var raw_candidates: Array = []
	if target is Character:
		for feature in target.features:
			if feature is Dictionary:
				if (feature.has("type") and feature["type"] is String and feature["type"] == "zero_hp_replacement") or (feature.has("trigger") and feature["trigger"] is String and feature["trigger"] == "zero_hp"):
					raw_candidates.append(feature)
	elif target is Dictionary:
		for ability in target.get("special_abilities", []):
			if ability is Dictionary:
				if (ability.has("type") and ability["type"] is String and ability["type"] == "zero_hp_replacement") or (ability.has("trigger") and ability["trigger"] is String and ability["trigger"] == "zero_hp"):
					raw_candidates.append(ability)
		if raw_candidates.is_empty() and bool(target.get("undead_fortitude", false)):
			var zombie_data: Dictionary = DataLoader.get_monster("zombie")
			for ability in zombie_data.get("special_abilities", []):
				if ability is Dictionary and ability.get("type") is String and ability.get("type") == "zero_hp_replacement" and ability.get("trigger") is String and ability.get("trigger") == "zero_hp":
					raw_candidates.append(ability)
					break

	if raw_candidates.is_empty():
		return {}

	var valid_candidates: Array = []
	for candidate in raw_candidates:
		var err := validate_zero_hp_replacement_rule(candidate)
		if not err.is_empty():
			push_warning("[SharedStepExecutor] Malformed zero_hp_replacement rule on target: %s" % err)
			continue
		valid_candidates.append(candidate)

	if valid_candidates.size() > 1:
		push_warning("[SharedStepExecutor] Competing zero_hp_replacement rules on target (%d rules). Competing replacements refused." % valid_candidates.size())
		return {}
	elif valid_candidates.size() == 1:
		return valid_candidates[0]
	return {}


static func _same_actor(a, b) -> bool:
	if a == null or b == null:
		return false
	if a is Character and b is Character:
		return a == b or (not a.character_id.is_empty() and a.character_id == b.character_id)
	if a is Dictionary and b is Dictionary:
		if a.has("id") and b.has("id"):
			return str(a["id"]) == str(b["id"])
		return is_same(a, b)
	return false


static func _copy_damage_components_for_step(components: Array, step: Dictionary) -> Array:
	var copied: Array = components.duplicate(true)
	# List entries already carry their authored ID or type ordinal, even when
	# there is only one. Step-derived IDs belong to scalar damage payloads.
	if step.has("damage_components"):
		return copied
	var component_type := str(step.get("damage_type", ""))
	var component_id := str(step.get("component_id", "%s:%s" % [str(step.get("id", "")), component_type]))
	if copied.size() == 1 and copied[0] is Dictionary:
		copied[0]["component_id"] = component_id
		return copied
	for component in copied:
		if component is Dictionary and not component.has("component_id"):
			component["component_id"] = component_id
	return copied


static func _copy_target_outcomes(outcomes: Array) -> Array:
	var copy: Array = []
	for outcome in outcomes:
		if outcome is Dictionary:
			var outcome_copy: Dictionary = outcome.duplicate(false)
			if outcome_copy.has("result") and outcome_copy["result"] is Dictionary:
				outcome_copy["result"] = outcome_copy["result"].duplicate(false)
			if outcome_copy.has("damage_components") and outcome_copy["damage_components"] is Array:
				outcome_copy["damage_components"] = outcome_copy["damage_components"].duplicate(true)
			copy.append(outcome_copy)
		else:
			copy.append(outcome)
	return copy


static func _copy_step_results(step_results: Array) -> Array:
	var copy: Array = []
	for sr in step_results:
		if sr is Dictionary:
			var sr_copy: Dictionary = sr.duplicate(false)
			if sr_copy.has("target_outcomes") and sr_copy["target_outcomes"] is Array:
				sr_copy["target_outcomes"] = _copy_target_outcomes(sr_copy["target_outcomes"])
			copy.append(sr_copy)
		else:
			copy.append(sr)
	return copy


static func execute_steps(steps: Array, adapter: Object, start_step_index: int = 0, prior_state: Dictionary = {}, start_target_index: int = 0) -> Dictionary:
	var context_name := ""
	if adapter.has_method("get_context_name"):
		context_name = str(adapter.get_context_name())
	if start_step_index == 0 and start_target_index == 0:
		var preflight_err := validate_steps(steps, context_name)
		if not preflight_err.is_empty():
			push_warning("[SharedStepExecutor] Refusing execution before state mutation: %s" % preflight_err)
			return {
				"success": false,
				"refused": true,
				"error": preflight_err,
				"message": preflight_err
			}
		if adapter.has_method("validate_spatial_context"):
			var spatial_err: String = adapter.validate_spatial_context(steps)
			if not spatial_err.is_empty():
				push_warning("[SharedStepExecutor] Refusing execution before state mutation: %s" % spatial_err)
				return {
					"success": false,
					"refused": true,
					"error": spatial_err,
					"message": spatial_err
				}

	var step_results: Array = _copy_step_results(prior_state.get("step_results", []))
	var total_damage: int = int(prior_state.get("total_damage", 0))
	var messages: Array[String] = []
	for m in prior_state.get("messages", []): messages.append(str(m))
	var first_attack_hit: bool = bool(prior_state.get("first_attack_hit", false))
	var has_attack: bool = bool(prior_state.get("has_attack", false))
	var primary_save_saved: bool = bool(prior_state.get("primary_save_saved", false))
	var has_save: bool = bool(prior_state.get("has_save", false))
	var replaced: bool = bool(prior_state.get("replaced", false))

	for i in range(start_step_index, steps.size()):
		var step: Dictionary = steps[i]
		var step_id: String = str(step.get("id", str(i)))
		var step_type: String = str(step.get("type", ""))
		var gate: String = str(step.get("gate", "always"))
		var step_target_mode: String = str(step.get("target", "target"))

		var step_targets: Array = []
		if i == start_step_index and prior_state.has("step_targets"):
			step_targets = prior_state["step_targets"]
		else:
			step_targets = adapter.get_step_targets(step)

		var target_outcomes: Array = _copy_target_outcomes(prior_state.get("target_outcomes", [])) if i == start_step_index else []
		var step_damage: int = int(prior_state.get("step_damage", 0)) if i == start_step_index else 0
		var step_hit := false
		var step_saved := false
		var current_target_start := start_target_index if i == start_step_index else 0

		# Check if prerequisite step as a whole was skipped
		var prereq_skipped := false
		if gate != "always":
			var gate_ref = step.get("gate_step", i - 1)
			var ref_idx := -1
			if gate_ref is int:
				ref_idx = gate_ref
			elif gate_ref is String:
				for idx in step_results.size():
					if step_results[idx].get("step_id") == gate_ref:
						ref_idx = idx
						break
			if ref_idx >= 0 and ref_idx < step_results.size():
				var ref_res: Dictionary = step_results[ref_idx]
				if bool(ref_res.get("skipped", false)):
					prereq_skipped = true

		if prereq_skipped:
			step_results.append({
			"complete": true,
				"step_id": step_id,
				"type": step_type,
				"target_mode": step_target_mode,
				"skipped": true,
				"reason": "prerequisite_skipped",
				"target_outcomes": []
			})
			continue

		for target_idx in range(current_target_start, step_targets.size()):
			var s_target = step_targets[target_idx]
			if not adapter.is_target_eligible(step, s_target):
				continue
			if adapter.has_method("is_recipient_negated") and adapter.is_recipient_negated(s_target, step):
				target_outcomes.append({
					"target": s_target,
					"target_name": adapter.get_target_name(s_target),
					"skipped": true,
					"negated": true,
					"reason": "recipient_effect_negated"
				})
				continue
			var physical_requirements: Dictionary = adapter.physical_requirements(step) if adapter.has_method("physical_requirements") else step.get("physical_requirements", {})
			if not physical_requirements.is_empty():
				var phys_eval := PhysicalFactsRules.evaluate_physical_eligibility(s_target, physical_requirements)
				if not phys_eval.eligible:
					target_outcomes.append({
						"target": s_target,
						"target_name": adapter.get_target_name(s_target),
						"skipped": true,
						"ineligible": true,
						"reason": phys_eval.reason
					})
					continue
			if adapter.has_method("spatial_eligibility"):
				var spatial: Dictionary = adapter.spatial_eligibility(s_target, step)
				if not spatial.get("eligible", false):
					target_outcomes.append({"target":s_target,"target_name":adapter.get_target_name(s_target),"skipped":true,"ineligible":true,"reason":spatial.get("reason", "spatial_ineligible")})
					continue
			if step.has("when") and not evaluate_predicate(step["when"], adapter, s_target, step_results):
				target_outcomes.append({"target": s_target, "target_name": adapter.get_target_name(s_target), "skipped": true, "reason": "when_not_satisfied"})
				continue

			# Per-target gate evaluation
			if gate != "always":
				var gate_ref = step.get("gate_step", i - 1)
				var ref_idx := -1
				if gate_ref is int:
					ref_idx = gate_ref
				elif gate_ref is String:
					for idx in step_results.size():
						if step_results[idx].get("step_id") == gate_ref:
							ref_idx = idx
							break
				if ref_idx < 0 or ref_idx >= step_results.size():
					target_outcomes.append({
						"target": s_target,
						"target_name": adapter.get_target_name(s_target),
						"skipped": true,
						"reason": "gate_not_found"
					})
					continue
				var ref_res: Dictionary = step_results[ref_idx]
				if bool(ref_res.get("skipped", false)):
					target_outcomes.append({
						"target": s_target,
						"target_name": adapter.get_target_name(s_target),
						"skipped": true,
						"reason": "prerequisite_skipped"
					})
					continue

				var ref_outcome: Dictionary = {}
				for to in ref_res.get("target_outcomes", []):
					if _same_actor(to.get("target"), s_target):
						ref_outcome = to
						break
				if ref_outcome.is_empty():
					if str(ref_res.get("target_mode", "target")) == "target" and not ref_res.get("target_outcomes", []).is_empty():
						ref_outcome = ref_res["target_outcomes"][0]
				if ref_outcome.is_empty():
					target_outcomes.append({
						"target": s_target,
						"target_name": adapter.get_target_name(s_target),
						"skipped": true,
						"reason": "gate_target_not_found"
					})
					continue
				if bool(ref_outcome.get("skipped", false)):
					target_outcomes.append({
						"target": s_target,
						"target_name": adapter.get_target_name(s_target),
						"skipped": true,
						"reason": "prerequisite_target_skipped"
					})
					continue

				var gate_satisfied := false
				match gate:
					"hit": gate_satisfied = bool(ref_outcome.get("hit", false))
					"miss": gate_satisfied = not bool(ref_outcome.get("hit", false))
					"failed_save": gate_satisfied = not bool(ref_outcome.get("saved", true))
					"successful_save": gate_satisfied = bool(ref_outcome.get("saved", false))
				if not gate_satisfied:
					target_outcomes.append({
						"target": s_target,
						"target_name": adapter.get_target_name(s_target),
						"skipped": true,
						"reason": "gate_not_satisfied",
						"gate": gate
					})
					continue

			if step_type in ["attack", "save"] and adapter.has_method("request_step_roll_choice"):
				var roll_state := {
					"step_results": _copy_step_results(step_results), "total_damage": total_damage,
					"step_damage": step_damage, "messages": messages.duplicate(),
					"first_attack_hit": first_attack_hit, "has_attack": has_attack,
					"primary_save_saved": primary_save_saved, "has_save": has_save,
					"step_targets": step_targets, "target_outcomes": _copy_target_outcomes(target_outcomes),
				}
				var roll_choice: Dictionary = adapter.request_step_roll_choice(step, s_target, i, target_idx, roll_state)
				if roll_choice.has("roll_choice_request"):
					return roll_choice

			match step_type:
				"attack":
					var is_first_attack := not has_attack
					has_attack = true
					var res: Dictionary = adapter.resolve_attack_step(step, s_target, i, target_idx, step_results, total_damage, messages, first_attack_hit, has_attack, primary_save_saved, has_save, target_outcomes, step_targets, step_damage, is_first_attack)
					if res.has("damage_request") or res.has("weapon_attack_bonus_request"):
						return res
					var hit := bool(res.get("hit", false))
					step_hit = hit
					if is_first_attack:
						first_attack_hit = hit
					var dmg := int(res.get("damage", 0))
					step_damage += dmg
					total_damage += dmg
					var msg := str(res.get("message", "")).strip_edges()
					if not msg.is_empty(): messages.append(msg)
					var outcome_entry := {
						"target": s_target,
						"target_name": adapter.get_target_name(s_target),
						"hit": hit,
						"damage": dmg,
						"result": res
					}
					for fact in ["resolved", "ward_absorbed", "ward_remaining_hp", "ward_projected", "temp_hp_absorbed", "hp_loss", "hp_before", "hp_after", "temp_hp_before", "temp_hp_after", "is_alive_before", "is_alive_after", "critical", "damage_is_critical", "damage_scale_decision", "damage_reduction_receipts", "rider_decisions"]:
						if res.has(fact):
							outcome_entry[fact] = res[fact]
					if res.has("damage_components"):
						outcome_entry["damage_components"] = _copy_damage_components_for_step(res["damage_components"], step)
					if adapter.has_method("settle_target_occurrence"):
						var settle_susp = adapter.settle_target_occurrence(s_target, step, res, outcome_entry, i, target_idx, step_results, total_damage, step_damage, messages, first_attack_hit, has_attack, primary_save_saved, has_save, target_outcomes, step_targets, is_first_attack)
						if settle_susp is Dictionary and (settle_susp.has("concentration_request") or settle_susp.has("roll_choice_request")):
							return settle_susp
					target_outcomes.append(outcome_entry)

				"save":
					has_save = true
					var res: Dictionary = adapter.resolve_save_step(step, s_target, i, target_idx, step_results, total_damage, messages, first_attack_hit, has_attack, primary_save_saved, has_save, target_outcomes, step_targets, step_damage)
					if res.has("damage_request") or res.has("save_bonus_request"):
						return res
					var saved := bool(res.get("saved", false))
					step_saved = saved
					if adapter.is_primary_target(s_target) or not has_save:
						primary_save_saved = saved
					var dmg := int(res.get("damage", 0))
					step_damage += dmg
					total_damage += dmg
					var msg := str(res.get("message", "")).strip_edges()
					if not msg.is_empty(): messages.append(msg)
					var outcome_entry := {
						"target": s_target,
						"target_name": adapter.get_target_name(s_target),
						"saved": saved,
						"damage": dmg,
						"result": res
					}
					for fact in ["resolved", "ward_absorbed", "ward_remaining_hp", "ward_projected", "temp_hp_absorbed", "hp_loss", "hp_before", "hp_after", "temp_hp_before", "temp_hp_after", "is_alive_before", "is_alive_after", "critical", "damage_is_critical", "damage_scale_decision", "damage_reduction_receipts", "rider_decisions"]:
						if res.has(fact):
							outcome_entry[fact] = res[fact]
					if res.has("damage_components"):
						outcome_entry["damage_components"] = _copy_damage_components_for_step(res["damage_components"], step)
					if adapter.has_method("settle_target_occurrence"):
						var settle_susp = adapter.settle_target_occurrence(s_target, step, res, outcome_entry, i, target_idx, step_results, total_damage, step_damage, messages, first_attack_hit, has_attack, primary_save_saved, has_save, target_outcomes, step_targets, false)
						if settle_susp is Dictionary and (settle_susp.has("concentration_request") or settle_susp.has("roll_choice_request")):
							return settle_susp
					target_outcomes.append(outcome_entry)

				"damage":
					var res: Dictionary = adapter.resolve_damage_step(step, s_target, i, target_idx, step_results, total_damage, messages, first_attack_hit, has_attack, primary_save_saved, has_save, target_outcomes, step_targets, step_damage)
					if res.has("damage_request"):
						return res
					var dmg := int(res.get("damage", 0))
					step_damage += dmg
					total_damage += dmg
					var msg := str(res.get("message", "")).strip_edges()
					if not msg.is_empty(): messages.append(msg)
					var outcome_entry := {
						"target": s_target,
						"target_name": adapter.get_target_name(s_target),
						"damage": dmg,
						"result": res
					}
					for fact in ["resolved", "ward_absorbed", "ward_remaining_hp", "ward_projected", "temp_hp_absorbed", "hp_loss", "hp_before", "hp_after", "temp_hp_before", "temp_hp_after", "is_alive_before", "is_alive_after", "critical", "damage_is_critical"]:
						if res.has(fact):
							outcome_entry[fact] = res[fact]
					if res.has("damage_components"):
						outcome_entry["damage_components"] = _copy_damage_components_for_step(res["damage_components"], step)
					if adapter.has_method("settle_target_occurrence"):
						var settle_susp = adapter.settle_target_occurrence(s_target, step, res, outcome_entry, i, target_idx, step_results, total_damage, step_damage, messages, first_attack_hit, has_attack, primary_save_saved, has_save, target_outcomes, step_targets, false)
						if settle_susp is Dictionary and (settle_susp.has("concentration_request") or settle_susp.has("roll_choice_request")):
							return settle_susp
					target_outcomes.append(outcome_entry)

				"effect":
					var res: Dictionary = adapter.resolve_effect_step(step, s_target, step_results)
					var msg := str(res.get("message", "")).strip_edges()
					if not msg.is_empty(): messages.append(msg)
					target_outcomes.append({
						"target": s_target,
						"target_name": adapter.get_target_name(s_target),
						"result": res
					})

				"replace_hp":
					var res: Dictionary = adapter.resolve_replace_hp_step(step, s_target)
					replaced = bool(res.get("replaced", false))
					var msg := str(res.get("message", "")).strip_edges()
					if not msg.is_empty(): messages.append(msg)
					target_outcomes.append({
						"target": s_target,
						"target_name": adapter.get_target_name(s_target),
						"replaced": replaced,
						"replacement_hp": res.get("replacement_hp", 1),
						"result": res
					})

		var all_targets_skipped := not target_outcomes.is_empty()
		for to in target_outcomes:
			if not bool(to.get("skipped", false)):
				all_targets_skipped = false
				break

		step_results.append({
			"complete": true,
			"step_id": step_id,
			"type": step_type,
			"target_mode": step_target_mode,
			"hit": step_hit,
			"saved": step_saved,
			"replaced": replaced if step_type == "replace_hp" else false,
			"damage": step_damage,
			"skipped": all_targets_skipped,
			"target_outcomes": target_outcomes
		})

	var final_result := {
		"success": true,
		"damage": total_damage,
		"hit": first_attack_hit if has_attack else true,
		"saved": primary_save_saved if has_save else false,
		"replaced": replaced,
		"step_results": step_results,
		"message": " ".join(messages).strip_edges()
	}
	return adapter.finalize_result(final_result)


static func execute_spell(cast: SpellResolutionContext, start_step_index: int = 0, prior_state: Dictionary = {}, start_target_index: int = 0) -> Dictionary:
	var adapter := SpellAdapter.new(cast)
	return execute_steps(cast.spell.get("steps", []), adapter, start_step_index, prior_state, start_target_index)


static func resume_roll_choice(record: Dictionary, selected: Dictionary) -> Dictionary:
	var cast: SpellResolutionContext = record["cast"]
	var cont: Dictionary = record["ordered_continuation"]
	cont["settled"] = true
	var answered: Dictionary = cast.decisions.get("ordered_roll_choices_answered", {})
	answered[cont["choice_key"]] = true
	cast.decisions["ordered_roll_choices_answered"] = answered
	cast.decisions.erase("roll_token_replacement")
	if not selected.is_empty():
		var owned_choice := selected.duplicate()
		owned_choice["test_kind"] = record["test_kind"]
		owned_choice["roller"] = record["roller"]
		cast.decisions["roll_token_replacement"] = owned_choice
	var i := int(cont["step_index"])
	var target_idx := int(cont["target_index"])
	if str(cont["phase"]) == "step":
		return execute_spell(cast, i, cont["prior_state"], target_idx)
	var adapter := SpellAdapter.new(cast)
	var outcome: Dictionary = cont["current_outcome_entry"]
	var pending := adapter.settle_target_occurrence(record["target"], cont["step"], cont["result"], outcome, i, target_idx, cont["step_results"], cont["total_damage"], cont["step_damage"], cont["messages"], cont["first_attack_hit"], cont["has_attack"], cont["primary_save_saved"], cont["has_save"], cont["target_outcomes"], cont["step_targets"], cont["is_first_attack"])
	if pending.has("concentration_request") or pending.has("roll_choice_request"):
		return pending
	# Damage and step effects were settled before the pre-save prompt.
	cont["settled"] = false
	return resume_spell_steps_occurrence(cast.caster, record["target"], cont["result"], cast.decisions, cont, {"success": not record["target"].concentrating_on.is_empty()})


static func resume_spell_steps(caster: Character, target, settled_result: Dictionary, _decisions: Dictionary, ordered_cont: Dictionary) -> Dictionary:
	if bool(ordered_cont.get("settled", false)):
		push_warning("[SharedStepExecutor] Continuation already settled; ignoring duplicate replay.")
		return settled_result
	ordered_cont["settled"] = true

	var step_index: int = int(ordered_cont.get("step_index", 0))
	var target_index: int = int(ordered_cont.get("target_index", 0))
	var pending_target = ordered_cont.get("pending_target", target)
	var step: Dictionary = ordered_cont.get("step", {})
	var cast: SpellResolutionContext = ordered_cont["cast"]
	var step_results: Array = _copy_step_results(ordered_cont.get("step_results", []))
	var adapter := SpellAdapter.new(cast)

	# Apply step effects if save or attack had effects and was pending
	_bind_resolution_window(cast, pending_target, settled_result)
	if step.has("effects") and not bool(settled_result.get("step_effects_applied", false)):
		settled_result["step_effects_applied"] = true
		var effects_to_apply: Array = step["effects"]
		if str(step.get("type", "")) == "attack" and not bool(settled_result.get("hit", false)):
			effects_to_apply = effects_to_apply.filter(func(effect): return effect is Dictionary and effect.has("rider_by_outcome"))
		if not effects_to_apply.is_empty():
			settled_result = SharedSpell.apply_custom_effects(cast.caster, pending_target, effects_to_apply, settled_result, cast.slot_level, step_results, adapter)

	var target_outcomes: Array = _copy_target_outcomes(ordered_cont.get("target_outcomes", []))
	var total_damage: int = int(ordered_cont.get("total_damage", 0)) + int(settled_result.get("damage", 0))
	var step_damage: int = int(ordered_cont.get("step_damage", 0)) + int(settled_result.get("damage", 0))
	var messages: Array[String] = []
	for m in ordered_cont.get("messages", []): messages.append(str(m))
	var settled_msg := str(settled_result.get("message", "")).strip_edges()
	if not settled_msg.is_empty():
		messages.append(settled_msg)

	var step_targets: Array = ordered_cont.get("step_targets", [])
	var next_target_idx := target_index + 1
	var is_first_attack: bool = bool(ordered_cont.get("is_first_attack", false))
	var current_first_attack_hit: bool = bool(ordered_cont.get("first_attack_hit", false))
	if is_first_attack and str(step.get("type", "")) == "attack":
		current_first_attack_hit = bool(settled_result.get("hit", false))

	var outcome_entry := {
		"target": pending_target,
		"target_name": adapter.get_target_name(pending_target),
		"hit": settled_result.get("hit", false),
		"saved": settled_result.get("saved", false),
		"damage": int(settled_result.get("damage", 0)),
		"result": settled_result
	}
	for fact in ["resolved", "ward_absorbed", "ward_remaining_hp", "ward_projected", "temp_hp_absorbed", "hp_loss", "hp_before", "hp_after", "temp_hp_before", "temp_hp_after", "is_alive_before", "is_alive_after", "critical", "damage_is_critical", "damage_scale_decision", "rider_decisions"]:
		if settled_result.has(fact):
			outcome_entry[fact] = settled_result[fact]
	if settled_result.has("damage_components"):
		outcome_entry["damage_components"] = _copy_damage_components_for_step(settled_result["damage_components"], step)
	if adapter.has_method("settle_target_occurrence"):
		var settle_susp = adapter.settle_target_occurrence(pending_target, step, settled_result, outcome_entry, step_index, target_index, step_results, total_damage, step_damage, messages, current_first_attack_hit, bool(ordered_cont.get("has_attack", false)), bool(ordered_cont.get("primary_save_saved", false)), bool(ordered_cont.get("has_save", false)), target_outcomes, step_targets, is_first_attack)
		if settle_susp is Dictionary and (settle_susp.has("concentration_request") or settle_susp.has("roll_choice_request")):
			return settle_susp
	target_outcomes.append(outcome_entry)

	# Cast-owned execution state (grid, participants, visibility, raw area roll,
	# choice context, Metamagic budget) stays exactly as the suspended cast holds
	# it. The owner's answer was already validated and applied by the registry, so
	# caller-supplied decisions are never merged here.

	var prior_state := {
		"step_results": step_results,
		"total_damage": total_damage,
		"step_damage": step_damage,
		"messages": messages,
		"first_attack_hit": current_first_attack_hit,
		"has_attack": bool(ordered_cont.get("has_attack", false)),
		"primary_save_saved": settled_result.get("saved", false) if adapter.is_primary_target(pending_target) and str(step.get("type", "")) == "save" else bool(ordered_cont.get("primary_save_saved", false)),
		"has_save": bool(ordered_cont.get("has_save", false)),
		"step_targets": step_targets,
		"target_outcomes": target_outcomes
	}

	var steps: Array = cast.spell.get("steps", [])

	if next_target_idx < step_targets.size():
		return execute_steps(steps, adapter, step_index, prior_state, next_target_idx)
	else:
		step_results.append({
			"complete": true,
			"step_id": str(step.get("id", str(step_index))),
			"type": str(step.get("type", "")),
			"target_mode": str(step.get("target", "target")),
			"hit": bool(settled_result.get("hit", false)),
			"saved": bool(settled_result.get("saved", false)),
			"replaced": false,
			"damage": step_damage,
			"target_outcomes": target_outcomes
		})
		prior_state["step_results"] = step_results
		prior_state.erase("step_targets")
		prior_state.erase("target_outcomes")
		prior_state["step_damage"] = 0
		return execute_steps(steps, adapter, step_index + 1, prior_state, 0)


static func resume_spell_steps_occurrence(caster: Character, target, settled_result: Dictionary, _decisions: Dictionary, ordered_cont: Dictionary, settlement: Dictionary = {}) -> Dictionary:
	if bool(ordered_cont.get("settled", false)):
		push_warning("[SharedStepExecutor] Continuation already settled; ignoring duplicate replay.")
		return settled_result
	ordered_cont["settled"] = true

	var step_index: int = int(ordered_cont.get("step_index", 0))
	var target_index: int = int(ordered_cont.get("target_index", 0))
	var pending_target = ordered_cont.get("pending_target", target)
	var step: Dictionary = ordered_cont.get("step", {})
	var cast: SpellResolutionContext = ordered_cont["cast"]

	var target_outcomes: Array = _copy_target_outcomes(ordered_cont.get("target_outcomes", []))
	var step_results: Array = _copy_step_results(ordered_cont.get("step_results", []))
	var total_damage: int = int(ordered_cont.get("total_damage", 0))
	var step_damage: int = int(ordered_cont.get("step_damage", 0))
	var messages: Array[String] = []
	for m in ordered_cont.get("messages", []): messages.append(str(m))

	var current_outcome: Dictionary = ordered_cont.get("current_outcome_entry", {})
	if current_outcome.is_empty():
		current_outcome = {
			"target": pending_target,
			"target_name": SpellAdapter.new(cast).get_target_name(pending_target),
			"hit": settled_result.get("hit", false),
			"saved": settled_result.get("saved", false),
			"damage": int(settled_result.get("damage", 0)),
			"result": settled_result
		}
	current_outcome["occurrence_settled"] = true
	current_outcome["concentration_maintained"] = bool(settlement.get("success", false))
	target_outcomes.append(current_outcome)

	var step_targets: Array = ordered_cont.get("step_targets", [])
	var next_target_idx := target_index + 1
	var adapter := SpellAdapter.new(cast)

	var is_first_attack: bool = bool(ordered_cont.get("is_first_attack", false))
	var current_first_attack_hit: bool = bool(ordered_cont.get("first_attack_hit", false))

	var prior_state := {
		"step_results": step_results,
		"total_damage": total_damage,
		"step_damage": step_damage,
		"messages": messages,
		"first_attack_hit": current_first_attack_hit,
		"has_attack": bool(ordered_cont.get("has_attack", false)),
		"primary_save_saved": bool(ordered_cont.get("primary_save_saved", false)),
		"has_save": bool(ordered_cont.get("has_save", false)),
		"step_targets": step_targets,
		"target_outcomes": target_outcomes
	}

	var steps: Array = cast.spell.get("steps", [])
	if next_target_idx < step_targets.size():
		return execute_steps(steps, adapter, step_index, prior_state, next_target_idx)
	else:
		step_results.append({
			"complete": true,
			"step_id": str(step.get("id", str(step_index))),
			"type": str(step.get("type", "")),
			"target_mode": str(step.get("target", "target")),
			"hit": bool(current_outcome.get("hit", false)),
			"saved": bool(current_outcome.get("saved", false)),
			"replaced": false,
			"damage": step_damage,
			"target_outcomes": target_outcomes
		})
		prior_state["step_results"] = step_results
		prior_state.erase("step_targets")
		prior_state.erase("target_outcomes")
		prior_state["step_damage"] = 0
		return execute_steps(steps, adapter, step_index + 1, prior_state, 0)


static func resolve_zero_hp_replacement(target, hp_before: int, damage: int, damage_type: String, critical: bool, decisions: Dictionary = {}) -> bool:
	if hp_before <= 0 or damage <= 0:
		return false
	if target is Character and target.is_dead():
		return false
	if target is Dictionary and not bool(target.get("is_alive", true)):
		return false
	var current_hp: int = target.current_hp if target is Character else int(target.get("current_hp", 0))
	if current_hp > 0:
		return false
	var rule := get_zero_hp_replacement_rule(target)
	if rule.is_empty():
		return false

	if critical and bool(rule.get("bypass_critical", false)):
		return false
	var bypass_types: Array = rule.get("bypass_damage_types", [])
	if damage_type.to_lower() in bypass_types:
		return false

	var canon_rule := canonicalize_rule(rule)
	var adapter := DamageEventAdapter.new(target, hp_before, damage, damage_type, critical, decisions)
	var result := execute_steps(canon_rule["steps"], adapter)
	return bool(result.get("replaced", false))


class DamageEventAdapter:
	var target
	var hp_before: int
	var damage: int
	var damage_type: String
	var critical: bool
	var decisions: Dictionary = {}

	func _init(p_target, p_hp_before: int, p_damage: int, p_damage_type: String, p_critical: bool, p_decisions: Dictionary = {}) -> void:
		target = p_target
		hp_before = p_hp_before
		damage = p_damage
		damage_type = p_damage_type
		critical = p_critical
		decisions = p_decisions

	func get_context_name() -> String:
		return "zero_hp_replacement"

	func is_primary_target(t) -> bool:
		return SharedStepExecutor._same_actor(t, target)

	func get_step_targets(step: Dictionary) -> Array:
		var target_mode := str(step.get("target", "target"))
		if target_mode != "target":
			return []
		return [target]

	func is_target_eligible(_step: Dictionary, _target) -> bool:
		return true

	func get_target_name(t) -> String:
		return t.character_name if t is Character else str(t.get("name", "Target"))

	func resolve_attack_step(_step, _t, _i, _target_idx, _step_results, _total_damage, _messages, _first_attack_hit, _has_attack, _primary_save_saved, _has_save, _target_outcomes, _step_targets, _step_damage: int = 0, _is_first_attack: bool = false) -> Dictionary:
		return {"success": false, "error": "Attack step unsupported in zero_hp_replacement"}

	func resolve_save_step(step: Dictionary, t, _i, _target_idx, _step_results, _total_damage, _messages, _first_attack_hit, _has_attack, _primary_save_saved, _has_save, _target_outcomes, _step_targets, _step_damage: int = 0) -> Dictionary:
		var ability: String = str(step.get("save", step.get("save_ability", "CON")))
		var dc: int = int(step.get("dc_base", 5)) + (damage if bool(step.get("dc_add_damage", false)) else 0)
		var saved := false
		if t is Character:
			saved = t.saving_throw_to_dc(ability, dc, false, false, decisions) >= dc
		elif t is Dictionary:
			saved = BarbarianRules.roll_monster_save(t, ability, null, false, false, decisions) >= dc
		return {
			"success": true,
			"saved": saved,
			"dc": dc,
			"message": "%s rolls %s saving throw vs DC %d: %s" % [get_target_name(t), ability, dc, "Success" if saved else "Failure"]
		}

	func resolve_damage_step(_step, _t, _i, _target_idx, _step_results, _total_damage, _messages, _first_attack_hit, _has_attack, _primary_save_saved, _has_save, _target_outcomes, _step_targets, _step_damage: int = 0) -> Dictionary:
		return {"success": false, "error": "Damage step unsupported in zero_hp_replacement"}

	func resolve_effect_step(_step, _t) -> Dictionary:
		return {"success": false, "error": "Effect step unsupported in zero_hp_replacement"}

	func resolve_replace_hp_step(step: Dictionary, t) -> Dictionary:
		var replacement_hp: int = int(step.get("replacement_hp", 1))
		var max_hp_val: int = t.max_hp if t is Character else int(t.get("max_hp", 0))
		if max_hp_val > 0:
			replacement_hp = mini(replacement_hp, max_hp_val)
		replacement_hp = maxi(1, replacement_hp)
		if t is Character:
			t.current_hp = replacement_hp
			t.is_alive = true
			t.death_save_failures = 0
		elif t is Dictionary:
			t["current_hp"] = replacement_hp
			t["is_alive"] = true
		return {
			"success": true,
			"replaced": true,
			"replacement_hp": replacement_hp,
			"message": "%s drops to %d HP instead." % [get_target_name(t), replacement_hp]
		}

	func finalize_result(final_result: Dictionary) -> Dictionary:
		return final_result


class SpellAdapter:
	var cast: SpellResolutionContext

	func _init(p_cast: SpellResolutionContext) -> void:
		cast = p_cast

	func get_context_name() -> String:
		return "spell"

	func is_primary_target(t) -> bool:
		return SharedStepExecutor._same_actor(t, cast.target)

	func validate_spatial_context(steps: Array) -> String:
		return SharedStepExecutor.validate_spatial_context_for_steps(steps, cast.decisions)

	func request_step_roll_choice(step: Dictionary, s_target, i: int, target_idx: int, prior_state: Dictionary) -> Dictionary:
		var cast_ctx: SpellCastContext = cast.decisions.get("cast_context")
		var choice_key := "%d:%d:step" % [i, target_idx]
		if cast_ctx == null or not cast_ctx.collect_roll_token_decision.is_valid() or cast.decisions.get("ordered_roll_choices_answered", {}).has(choice_key):
			return {}
		var roller = cast.caster if str(step["type"]) == "attack" else s_target
		var test_kind := "attack" if str(step["type"]) == "attack" else "save" if s_target is Character else "monster_save"
		var label := "spell attack for %s" % cast.spell.get("name", "Spell") if test_kind == "attack" else "%s saving throw against %s" % [step.get("save", "Spell"), cast.spell.get("name", "Spell")]
		return SpellDamageRolls.create_roll_choice_request(cast, s_target, roller, test_kind, label, {
			"settled": false, "phase": "step", "choice_key": choice_key,
			"step_index": i, "target_index": target_idx, "prior_state": prior_state,
			"step_results": prior_state.get("step_results", []),
		})

	func settle_target_occurrence(s_target, step: Dictionary, res: Dictionary, outcome_entry: Dictionary = {}, i: int = 0, target_idx: int = 0, step_results: Array = [], total_damage: int = 0, step_damage: int = 0, messages: Array = [], first_attack_hit: bool = false, has_attack: bool = false, primary_save_saved: bool = false, has_save: bool = false, target_outcomes: Array = [], step_targets: Array = [], is_first_attack: bool = false) -> Dictionary:
		var dmg_resolved: int = int(res.get("resolved", res.get("damage", 0)))
		var hp_loss: int = int(res.get("damage", 0))

		if dmg_resolved > 0 or hp_loss > 0:
			ClericRules.clear_turning_after_damage(s_target)

		var cast_ctx: SpellCastContext = cast.decisions.get("cast_context")
		var hud = cast.decisions.get("hud", cast_ctx.hud if cast_ctx != null else null)
		var tracker = cast.decisions.get("tracker", cast_ctx.tracker if cast_ctx != null else null)
		var trigger_defeat = cast.decisions.get("trigger_enemy_defeat_features", cast_ctx.trigger_enemy_defeat_features if cast_ctx != null else null)

		# Defeat processing for 0 HP monster actors:
		if s_target is Dictionary and int(s_target.get("current_hp", 0)) <= 0 and not bool(s_target.get("_defeat_processed", false)):
			s_target["_defeat_processed"] = true
			s_target["is_alive"] = false
			if hud != null:
				hud.add_log("[color=green]%s was defeated![/color]" % str(s_target.get("name", "The creature")))
			if tracker != null:
				tracker.remove_combatant(str(s_target.get("id", "")))
			if trigger_defeat != null and trigger_defeat.is_valid():
				trigger_defeat.call(s_target, cast.caster)

		# Concentration save per occurrence for concentrating Characters:
		if s_target is Character and not s_target.concentrating_on.is_empty():
			if not s_target.is_alive or s_target.current_hp <= 0 or s_target.has_condition("incapacitated") or s_target.has_condition("unconscious"):
				SpellEncounterLifecycle._end_concentration(cast_ctx, s_target)
				outcome_entry["occurrence_settled"] = true
				return {}
			elif dmg_resolved > 0:
				var concentration_spell_id := str(s_target.concentrating_on.get("spell_id", ""))
				var protected_hunter := false
				for feature in s_target.features:
					for effect in s_target._feature_effects(feature):
						if effect.get("type", "") == "concentration_protection" and concentration_spell_id in effect.get("spells", []):
							protected_hunter = true
							break
				if protected_hunter:
					outcome_entry["occurrence_settled"] = true
					return {}

				var dc: int = mini(30, maxi(10, int(floor(float(dmg_resolved) / 2.0))))
				var choice_key := "%d:%d:concentration" % [i, target_idx]
				if cast_ctx != null and cast_ctx.collect_roll_token_decision.is_valid() and not cast.decisions.get("ordered_roll_choices_answered", {}).has(choice_key):
					return SpellDamageRolls.create_roll_choice_request(cast, s_target, s_target, "save", "CON concentration save", {
						"settled": false, "phase": "concentration", "choice_key": choice_key,
						"step_index": i, "target_index": target_idx, "step": step, "cast": cast,
						"step_results": SharedStepExecutor._copy_step_results(step_results),
						"total_damage": total_damage, "step_damage": step_damage, "messages": messages.duplicate(),
						"first_attack_hit": first_attack_hit, "has_attack": has_attack,
						"primary_save_saved": primary_save_saved, "has_save": has_save,
						"target_outcomes": SharedStepExecutor._copy_target_outcomes(target_outcomes), "step_targets": step_targets,
						"current_outcome_entry": outcome_entry, "result": res, "is_first_attack": is_first_attack,
					})
				var save_test: Dictionary = s_target.saving_throw_test_to_dc("CON", dc, bool(s_target.concentrating_on.get("extended_spell", false)), false, cast.decisions)
				var roll := int(save_test.get("total", 0))
				var success: bool = roll >= dc

				if not success:
					var has_stroke: bool = s_target.has_feature("rogue_stroke_of_luck") and int(s_target.feature_uses.get("rogue_stroke_of_luck", 0)) > 0
					var has_bardic: bool = BardicInspirationRules.has_die(s_target)
					if has_stroke or has_bardic:
						var stroke_dec = SpellDamageRolls.get_concentration_decision(cast.decisions, s_target, "stroke_of_luck", cast.caster) if has_stroke else null
						var bardic_dec = SpellDamageRolls.get_concentration_decision(cast.decisions, s_target, "bardic_inspiration", cast.caster) if has_bardic else null

						# If stroke can be decided immediately via supplied decisions:
						if has_stroke and stroke_dec != null:
							var stroke_accepted: bool = bool(stroke_dec)
							var stroke := RogueRules.apply_stroke_of_luck(s_target, save_test, stroke_accepted)
							if stroke.get("used", false):
								save_test = stroke.get("result", save_test)
								roll = int(save_test.get("total", roll))
								success = bool(save_test.get("success", false))

						# If stroke succeeded, concentration is maintained! Bardic is not offered.
						if success:
							if hud != null:
								hud.add_log("[color=green]%s maintained concentration![/color]" % s_target.character_name)
							outcome_entry["occurrence_settled"] = true
							return {}

						# If bardic decision is supplied and stroke is resolved (or stroke was not chosen for concentration):
						if has_bardic and bardic_dec != null:
							var bardic_accepted: bool = bool(bardic_dec)
							var inspiration := BardicInspirationRules.apply_to_test(s_target, roll, dc, bardic_accepted)
							if inspiration.get("used", false):
								roll = int(inspiration.get("total", roll))
								success = bool(inspiration.get("success", false))
							if success:
								if hud != null:
									hud.add_log("[color=green]%s maintained concentration![/color]" % s_target.character_name)
							else:
								SpellEncounterLifecycle._end_concentration(cast_ctx, s_target)
								if hud != null:
									hud.add_log("[color=red]%s failed CON save! Concentration lost.[/color]" % s_target.character_name)
							outcome_entry["occurrence_settled"] = true
							return {}

						# If stroke was supplied (and failed) and no bardic is available:
						if (has_stroke and stroke_dec != null) and not has_bardic:
							SpellEncounterLifecycle._end_concentration(cast_ctx, s_target)
							if hud != null:
								hud.add_log("[color=red]%s failed CON save! Concentration lost.[/color]" % s_target.character_name)
							outcome_entry["occurrence_settled"] = true
							return {}

						# Needs suspension! Choice sequencing: offer Stroke first if available and undecided, else Bardic.
						var feature_choice: String = "stroke_of_luck" if (has_stroke and stroke_dec == null) else "bardic_inspiration"
						var req_id := SpellDamageRolls.create_concentration_request(cast.caster, s_target, dc, roll, feature_choice, cast.decisions, res, save_test)
						var continuation := {
							"continuation_id": req_id,
							"request_id": req_id,
							"kind": "concentration",
							"step_index": i,
							"target_index": target_idx,
							"pending_target": s_target,
							"step_results": SharedStepExecutor._copy_step_results(step_results),
							"total_damage": total_damage,
							"step_damage": step_damage,
							"messages": messages,
							"first_attack_hit": bool(res.get("hit", false)) if (not has_attack or is_first_attack) else first_attack_hit,
							"has_attack": has_attack,
							"is_first_attack": is_first_attack,
							"primary_save_saved": primary_save_saved,
							"has_save": has_save,
							"cast": cast,
							"step": step,
							"step_targets": step_targets,
							"target_outcomes": SharedStepExecutor._copy_target_outcomes(target_outcomes),
							"current_outcome_entry": outcome_entry,
							"settled": false
						}
						SpellDamageRolls.attach_continuation(req_id, continuation, cast)
						var susp_res := res.duplicate()
						susp_res["concentration_request"] = {
							"request_id": req_id,
							"target": s_target,
							"dc": dc,
							"roll": roll,
							"feature": feature_choice,
							"save_test": save_test.duplicate(true)
						}
						susp_res["ordered_continuation"] = continuation
						susp_res["suspended_step"] = i
						susp_res["step_results"] = SharedStepExecutor._copy_step_results(step_results)
						return susp_res

					# No reaction feature available: failed CON save drops concentration immediately
					SpellEncounterLifecycle._end_concentration(cast_ctx, s_target)
					if hud != null:
						hud.add_log("[color=red]%s failed CON save! Concentration lost.[/color]" % s_target.character_name)
				else:
					if hud != null:
						hud.add_log("[color=green]%s maintained concentration![/color]" % s_target.character_name)

		outcome_entry["occurrence_settled"] = true
		return {}

	func get_step_targets(step: Dictionary) -> Array:
		var step_target_mode: String = str(step.get("target", "target"))
		if step_target_mode == "area":
			# One raw roll per area step, shared by all of that step's targets. A
			# resumed step never reaches here again, so the roll survives suspension.
			cast.decisions["spell_damage_context"] = {}
		else:
			cast.decisions.erase("spell_damage_context")

		if step_target_mode == "self":
			return [cast.caster]
		elif step_target_mode == "area":
			if cast.decisions.has("area_targets"):
				return cast.decisions["area_targets"]
			var grid: HexGrid = cast.decisions.get("grid")
			if grid == null:
				return []

			var caster_coord := Vector2i.ZERO
			for p in cast.decisions.get("players", []):
				if p.get("character") == cast.caster:
					caster_coord = p.get("hex_position", Vector2i.ZERO)
					break
			if caster_coord == Vector2i.ZERO and cast.decisions.has("spell_visibility"):
				caster_coord = cast.decisions["spell_visibility"].get("caster_position", Vector2i.ZERO)

			var target_coord := Vector2i.ZERO
			if cast.target is Character:
				for p in cast.decisions.get("players", []):
					if p.get("character") == cast.target:
						target_coord = p.get("hex_position", Vector2i.ZERO)
						break
			elif cast.target is Dictionary:
				target_coord = cast.target.get("hex_position", Vector2i.ZERO)
			if target_coord == Vector2i.ZERO and cast.decisions.has("spell_visibility"):
				target_coord = cast.decisions["spell_visibility"].get("target_position", Vector2i.ZERO)

			var shape: String = str(step.get("shape", "sphere"))
			var area_hexes: Array[Vector2i] = []
			if shape == "cone":
				var size := int(step.get("size", step.get("cone_size", 3)))
				area_hexes = Targeting.get_cone_targets(caster_coord, target_coord, size, grid)
				area_hexes = area_hexes.filter(func(h): return Targeting.has_line_of_sight(caster_coord, h, grid))
			elif shape == "cube":
				var size := int(step.get("size", 2))
				area_hexes = Targeting.get_cube_targets(caster_coord, target_coord, size, grid)
				area_hexes = area_hexes.filter(func(h): return Targeting.has_line_of_sight(caster_coord, h, grid))
			else:
				var radius := int(step.get("radius", step.get("size", 2)))
				area_hexes = Targeting.get_sphere_targets(target_coord, radius, grid)
				area_hexes = area_hexes.filter(func(h): return Targeting.has_line_of_sight(target_coord, h, grid))

			var step_targets: Array = []
			for p in cast.decisions.get("players", []):
				var ch: Character = p.get("character")
				if p.get("hex_position") in area_hexes and ch != null and not ch.is_dead():
					step_targets.append(ch)
			for m in cast.decisions.get("monsters", []):
				if m.get("hex_position") in area_hexes and bool(m.get("is_alive", false)):
					step_targets.append(m)
			return step_targets
		return [cast.target]

	func is_target_eligible(step: Dictionary, t) -> bool:
		if t is Character:
			if t.is_dead() and not step.has("revive"):
				return false
			return true
		if t is Dictionary and not bool(t.get("is_alive", true)):
			return false
		return true

	func physical_requirements(step: Dictionary) -> Dictionary:
		return step.get("physical_requirements", cast.spell.get("physical_requirements", {}))

	func spatial_eligibility(t, step: Dictionary) -> Dictionary:
		var requirements: Dictionary = step.get("spatial_requirements", cast.spell.get("spatial_requirements", {}))
		if requirements.is_empty(): return {"eligible":true}
		var host := cast.spatial_host
		var grid: HexGrid = host.grid if host != null else cast.decisions.get("grid")
		var participants: Array = host.players if host != null else cast.decisions.get("players", [])
		var monsters: Array = host.monsters if host != null else cast.decisions.get("monsters", [])
		var position := Vector2i(9999, 9999)
		if t is Dictionary: position = t.get("hex_position", position)
		else:
			for participant in participants:
				if participant.get("character") == t: position = participant.get("hex_position", position)
		if position == Vector2i(9999, 9999): return {"eligible":false,"reason":"missing_target_position"}
		var room := LocalRoomCombat.room()
		return PhysicalFactsRules.evaluate_spatial_eligibility(grid, position, requirements, {"caster":cast.caster,"players":participants,"monsters":monsters,"room":room,"plane":str(room.get("plane", PhysicalFactsRules.DEFAULT_PLANE)),"ignore_entity":cast.caster})

	func is_recipient_negated(t, step: Dictionary = {}) -> bool:
		return CastInterruptionRules.is_recipient_negated(cast, t, step)

	func get_target_name(t) -> String:
		return t.character_name if t is Character else str(t.get("name", "Target"))

	func _clean_step_spell(step: Dictionary) -> Dictionary:
		var step_spell := cast.spell.duplicate(true)
		var step_type := str(step.get("type", ""))
		var step_id := str(step.get("id", ""))
		step_spell.erase("steps")
		step_spell.erase("attack_type")
		step_spell.erase("save")
		step_spell.erase("half_on_save")
		step_spell.erase("damage_scale_by_outcome")
		step_spell.erase("damage_dice_policy")
		step_spell.erase("damage_result_multiplier")
		step_spell.erase("damage_reductions")
		step_spell.erase("damage_bypasses")
		step_spell.erase("damage")
		step_spell.erase("damage_type")
		step_spell.erase("damage_components")
		step_spell.erase("scaling")
		step_spell.erase("upcast")
		step_spell.erase("effects")
		if step.has("damage"):
			step_spell["damage"] = step["damage"]
			step_spell["damage_type"] = step.get("damage_type", "untyped")
			step_spell["component_id"] = str(step.get("component_id", "%s:%s" % [step_id, str(step_spell["damage_type"])]))
		if step.has("damage_components"): step_spell["damage_components"] = step["damage_components"]
		if step.has("scaling"): step_spell["scaling"] = step["scaling"]
		if step.has("upcast"): step_spell["upcast"] = step["upcast"]
		if step.has("effects"): step_spell["effects"] = step["effects"]
		if step.has("damage_scale_by_outcome"): step_spell["damage_scale_by_outcome"] = step["damage_scale_by_outcome"]
		if step.has("damage_dice_policy"): step_spell["damage_dice_policy"] = step["damage_dice_policy"]
		if step.has("damage_result_multiplier"): step_spell["damage_result_multiplier"] = step["damage_result_multiplier"]
		if step.has("damage_reductions"): step_spell["damage_reductions"] = step["damage_reductions"]
		if step.has("damage_bypasses"): step_spell["damage_bypasses"] = step["damage_bypasses"]
		if step.has("component_id"): step_spell["component_id"] = step["component_id"]
		if step.has("save_context"): step_spell["save_context"] = step["save_context"]
		if step_type == "save": step_spell["_origin_effect_id"] = step_id
		return step_spell

	func _create_step_cast(s_target, step_spell: Dictionary) -> SpellResolutionContext:
		return SharedSpell._create_step_cast(cast, s_target, step_spell)

	func resolve_attack_step(step: Dictionary, s_target, i: int, target_idx: int, step_results: Array, total_damage: int, messages: Array, first_attack_hit: bool, has_attack: bool, primary_save_saved: bool, has_save: bool, target_outcomes: Array, step_targets: Array, step_damage: int, is_first_attack: bool = false) -> Dictionary:
		var step_spell := _clean_step_spell(step)
		step_spell["attack_type"] = step["attack_type"]
		var step_cast := _create_step_cast(s_target, step_spell)
		var res := SpellAttackResolver.resolve(step_cast)
		SharedStepExecutor._bind_resolution_window(cast, s_target, res)
		if res.has("damage_request") or res.has("weapon_attack_bonus_request"):
			var request_key := "weapon_attack_bonus_request" if res.has("weapon_attack_bonus_request") else "damage_request"
			var req_id: String = str(res[request_key].get("request_id", ""))
			var continuation := {
				"continuation_id": req_id if not req_id.is_empty() else "cont_%d_%d_%d" % [cast.get_instance_id(), i, target_idx],
				"request_id": req_id,
				"step_index": i,
				"target_index": target_idx,
				"pending_target": s_target,
				"step_results": SharedStepExecutor._copy_step_results(step_results),
				"total_damage": total_damage,
				"step_damage": step_damage,
				"messages": messages,
				"first_attack_hit": bool(res.get("hit", false)) if (not has_attack or is_first_attack) else first_attack_hit,
				"has_attack": has_attack,
				"is_first_attack": is_first_attack,
				"primary_save_saved": primary_save_saved,
				"has_save": has_save,
				"cast": cast,
				"step": step,
				"step_targets": step_targets,
				"target_outcomes": SharedStepExecutor._copy_target_outcomes(target_outcomes),
				"settled": false
			}
			SpellDamageRolls.attach_continuation(req_id, continuation, cast)
			res["ordered_continuation"] = continuation
			res["suspended_step"] = i
			res["step_results"] = SharedStepExecutor._copy_step_results(step_results)
			return res
		if step.has("effects"):
			var effects_to_apply: Array = step["effects"]
			if not bool(res.get("hit", false)):
				effects_to_apply = effects_to_apply.filter(func(effect): return effect is Dictionary and effect.has("rider_by_outcome"))
			if not effects_to_apply.is_empty():
				res = SharedSpell.apply_custom_effects(cast.caster, s_target, effects_to_apply, res, cast.slot_level, step_results, self)
		return res

	func resolve_save_step(step: Dictionary, s_target, i: int, target_idx: int, step_results: Array, total_damage: int, messages: Array, first_attack_hit: bool, has_attack: bool, primary_save_saved: bool, has_save: bool, target_outcomes: Array, step_targets: Array, step_damage: int) -> Dictionary:
		var step_spell := _clean_step_spell(step)
		step_spell["save"] = step["save"]
		step_spell["half_on_save"] = bool(step.get("half_on_save", false))
		step_spell["_shared_spell_step"] = true
		step_spell["_save_bonus_result_key"] = "step:%s:%d:%d:%s" % [str(step.get("id", i)), i, target_idx, str(s_target.get_instance_id()) if s_target is Object else str(s_target.get("id", "target"))]
		var step_cast := _create_step_cast(s_target, step_spell)
		var res := SpellSaveResolver.resolve(step_cast)
		SharedStepExecutor._bind_resolution_window(cast, s_target, res)
		if res.has("damage_request") or res.has("save_bonus_request"):
			var request_key := "save_bonus_request" if res.has("save_bonus_request") else "damage_request"
			var req_id: String = str(res[request_key].get("request_id", ""))
			var continuation := {
				"continuation_id": req_id if not req_id.is_empty() else "cont_%d_%d_%d" % [cast.get_instance_id(), i, target_idx],
				"request_id": req_id,
				"step_index": i,
				"target_index": target_idx,
				"pending_target": s_target,
				"step_results": SharedStepExecutor._copy_step_results(step_results),
				"total_damage": total_damage,
				"step_damage": step_damage,
				"messages": messages,
				"first_attack_hit": first_attack_hit,
				"has_attack": has_attack,
				"is_first_attack": false,
				"primary_save_saved": primary_save_saved,
				"has_save": has_save,
				"cast": cast,
				"step": step,
				"step_targets": step_targets,
				"target_outcomes": SharedStepExecutor._copy_target_outcomes(target_outcomes),
				"settled": false
			}
			SpellDamageRolls.attach_continuation(req_id, continuation, cast)
			res["ordered_continuation"] = continuation
			res["suspended_step"] = i
			res["step_results"] = SharedStepExecutor._copy_step_results(step_results)
			return res
		if step.has("effects"):
			res = SharedSpell.apply_custom_effects(cast.caster, s_target, step["effects"], res, cast.slot_level, step_results, self)
		return res

	func resolve_damage_step(step: Dictionary, s_target, i: int, target_idx: int, step_results: Array, total_damage: int, messages: Array, first_attack_hit: bool, has_attack: bool, primary_save_saved: bool, has_save: bool, target_outcomes: Array, step_targets: Array, step_damage: int) -> Dictionary:
		SharedStepExecutor._bind_resolution_window(cast, s_target, {})
		var step_spell := _clean_step_spell(step)
		var formula := SpellDamageRolls.spell_damage_formula(cast.caster, step_spell, cast.slot_level)
		var roll := SpellDamageRolls._roll_spell_damage(cast.caster, formula, 1, cast.decisions, step.get("damage_dice_policy", {}))
		var damage_decisions := cast.decisions.duplicate()
		damage_decisions["damage_result_multiplier"] = step.get("damage_result_multiplier", {})
		damage_decisions["_shared_component_id"] = str(step_spell.get("component_id", "%s:%s" % [str(step.get("id", "")), str(step_spell["damage_type"])]))
		var res := SpellDamageRolls._finish_spell_damage(cast.caster, s_target, roll, CombatAction.spell_damage_bonus(cast.caster, step_spell), 1.0, str(step_spell["damage_type"]), damage_decisions, {"success": true, "hit": true, "effect_cast": cast.effect_cast, "message": "%s deals {damage} %s damage." % [cast.spell["name"], step_spell["damage_type"]]}, 1, [], step_spell.get("damage_reductions", []), step_spell.get("damage_bypasses", []))
		if res.has("damage_request"):
			var req_id: String = str(res["damage_request"].get("request_id", ""))
			var continuation := {
				"continuation_id": req_id if not req_id.is_empty() else "cont_%d_%d_%d" % [cast.get_instance_id(), i, target_idx],
				"request_id": req_id,
				"step_index": i,
				"target_index": target_idx,
				"pending_target": s_target,
				"step_results": SharedStepExecutor._copy_step_results(step_results),
				"total_damage": total_damage,
				"step_damage": step_damage,
				"messages": messages,
				"first_attack_hit": first_attack_hit,
				"has_attack": has_attack,
				"is_first_attack": false,
				"primary_save_saved": primary_save_saved,
				"has_save": has_save,
				"cast": cast,
				"step": step,
				"step_targets": step_targets,
				"target_outcomes": SharedStepExecutor._copy_target_outcomes(target_outcomes),
				"settled": false
			}
			SpellDamageRolls.attach_continuation(req_id, continuation, cast)
			res["ordered_continuation"] = continuation
			res["suspended_step"] = i
			res["step_results"] = SharedStepExecutor._copy_step_results(step_results)
			return res
		if step.has("effects"):
			res = SharedSpell.apply_custom_effects(cast.caster, s_target, step["effects"], res, cast.slot_level, step_results, self)
		return res

	func resolve_effect_step(step: Dictionary, s_target, step_results: Array = []) -> Dictionary:
		if step.has("effects"):
			var res := {"success": true, "hit": true, "slot_level": cast.slot_level, "effect_cast": cast.effect_cast}
			res = SharedSpell.apply_custom_effects(cast.caster, s_target, step["effects"], res, cast.slot_level, step_results, self)
			return res
		return {}

	func resolve_replace_hp_step(_step, _s_target) -> Dictionary:
		return {"success": false, "error": "replace_hp step unsupported in spells"}

	func finalize_result(final_result: Dictionary) -> Dictionary:
		final_result["slot_level"] = cast.slot_level
		final_result["effect_cast"] = cast.effect_cast
		if cast.target != null:
			var primary_outcomes: Array = []
			for sr in final_result.get("step_results", []):
				for to in sr.get("target_outcomes", []):
					if SharedStepExecutor._same_actor(to.get("target"), cast.target):
						primary_outcomes.append(to)
			if not primary_outcomes.is_empty():
				var first_to: Dictionary = primary_outcomes[0]
				var last_to: Dictionary = primary_outcomes[primary_outcomes.size() - 1]
				var primary_resolved := 0
				var primary_ward_absorbed := 0
				var primary_ward_remaining := 0
				var primary_ward_projected := false
				var primary_temp_absorbed := 0
				var primary_hp_loss := 0
				var had_damage_fact := false
				var any_critical := false
				for to in primary_outcomes:
					if to.has("resolved"):
						primary_resolved += int(to["resolved"])
						had_damage_fact = true
					if to.has("ward_absorbed"):
						primary_ward_absorbed += int(to["ward_absorbed"])
						had_damage_fact = true
					if to.has("ward_remaining_hp"):
						primary_ward_remaining = int(to["ward_remaining_hp"])
					if bool(to.get("ward_projected", false)):
						primary_ward_projected = true
					if to.has("temp_hp_absorbed"):
						primary_temp_absorbed += int(to["temp_hp_absorbed"])
					if to.has("hp_loss"):
						primary_hp_loss += int(to["hp_loss"])
					elif to.has("damage"):
						primary_hp_loss += int(to["damage"])
					if bool(to.get("critical", false)) or bool(to.get("damage_is_critical", false)):
						any_critical = true
				if had_damage_fact:
					final_result["resolved"] = primary_resolved
					final_result["ward_absorbed"] = primary_ward_absorbed
					final_result["ward_remaining_hp"] = primary_ward_remaining
					final_result["ward_projected"] = primary_ward_projected
					final_result["temp_hp_absorbed"] = primary_temp_absorbed
					final_result["hp_loss"] = primary_hp_loss
					if first_to.has("hp_before"):
						final_result["hp_before"] = first_to["hp_before"]
					if last_to.has("hp_after"):
						final_result["hp_after"] = last_to["hp_after"]
					if first_to.has("temp_hp_before"):
						final_result["temp_hp_before"] = first_to["temp_hp_before"]
					if last_to.has("temp_hp_after"):
						final_result["temp_hp_after"] = last_to["temp_hp_after"]
					if first_to.has("is_alive_before"):
						final_result["is_alive_before"] = first_to["is_alive_before"]
					if last_to.has("is_alive_after"):
						final_result["is_alive_after"] = last_to["is_alive_after"]
					if any_critical:
						final_result["critical"] = true
						final_result["damage_is_critical"] = true
		var any_negated := false
		var any_resolved := false
		for row in final_result.get("step_results", []):
			for outcome in row.get("target_outcomes", []):
				any_negated = any_negated or bool(outcome.get("negated", false))
				any_resolved = any_resolved or not bool(outcome.get("skipped", false))
		if any_negated and not any_resolved:
			final_result["negated"] = true
			final_result["recipient_negated"] = true
			final_result["hit"] = false
		if cast.spell.has("effects"):
			final_result = SharedSpell.apply(cast.caster, cast.target, cast.spell, final_result)
		return final_result
