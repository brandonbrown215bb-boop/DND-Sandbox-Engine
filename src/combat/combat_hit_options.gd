## Optional, data-authored consequences of a settled hit from a tagged attack grant.
## The combat host supplies choices and movement; the existing save owner rolls.
class_name CombatHitOptions
extends RefCounted

static func content_error(effect: Dictionary) -> String:
	if not str(effect.get("attack_tag", "")).is_valid_identifier() or str(effect.get("dc_ability", "")) not in DataLoader.VALID_ABILITIES:
		return "Hit options require an attack tag and DC ability."
	var options: Variant = effect.get("options")
	if not options is Array or options.is_empty() or options.size() > 8: return "Hit options require 1-8 options."
	var ids := {}
	for option in options:
		if not option is Dictionary or not str(option.get("id", "")).is_valid_identifier() or ids.has(option.id) or str(option.get("name", "")).is_empty(): return "Hit options require unique IDs and labels."
		ids[option.id] = true
		if option.has("save") and str(option.save) not in DataLoader.VALID_ABILITIES: return "Unsupported hit-option save."
		match str(option.get("operation", "")):
			"grant_condition":
				if str(option.get("condition", "")) not in ["prone", "opportunity_attack_blocked"]: return "Unsupported hit-option condition."
				if option.has("expiry") and str(option.expiry) != "target_start": return "Unsupported hit-option expiry."
				if option.condition == "opportunity_attack_blocked" and option.get("expiry") != "target_start": return "Opportunity blocking must expire at target start."
			"push":
				if not SharedStepExecutor._integer(option.get("max_distance_feet"), 5, 30) or int(option.max_distance_feet) % 5 != 0: return "Push distance must be 5-30 feet in 5-foot steps."
			_:
				return "Unsupported hit-option operation."
		for field in option:
			if field not in ["id", "name", "save", "operation", "condition", "expiry", "max_distance_feet"]: return "Unknown hit-option field."
	for field in effect:
		if field not in ["type", "attack_tag", "dc_ability", "options"]: return "Unknown hit-options field."
	return ""

static func offers(actor: Character, attack_tag: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if actor == null or attack_tag.is_empty(): return out
	for effect in ClassProgression.selected_feature_effects_of_type(actor, "hit_options"):
		if str(effect.get("attack_tag", "")) == attack_tag: out.append(effect)
	return out

static func settle(actor: Character, target: Dictionary, effect: Dictionary, option: Dictionary, source: String, decisions: Dictionary = {}) -> Dictionary:
	var result := {"option_id":option.id, "applied":false}
	if option.has("save"):
		var save := BarbarianRules.roll_monster_save_result(target, str(option.save), actor, false, false, decisions)
		var dc := 8 + actor.proficiency_bonus + actor.ability_scores.get_ability_modifier(str(effect.dc_ability))
		save["dc"] = dc; save["success"] = not bool(save.get("auto_failed", false)) and int(save.total) >= dc
		result["save"] = save
		if save.success: return result
	if option.operation == "grant_condition":
		CombatAction.apply_condition(target, str(option.condition), -1, source)
		if option.get("expiry", "") == "target_start":
			var endings: Array = target.get("target_start_conditions", [])
			endings.append({"condition":option.condition, "source":source})
			target["target_start_conditions"] = endings
	result["applied"] = option.operation == "push" or target.get("condition_sources", {}).get(str(option.get("condition", "")), {}).has(source)
	return result
