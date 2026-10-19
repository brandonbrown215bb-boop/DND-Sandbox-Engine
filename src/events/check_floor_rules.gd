## Authored floors for loaded EventDialog checks. No attack/save policy is inferred.
class_name CheckFloorRules
extends RefCounted

static func content_error(effect: Dictionary) -> String:
	for key in effect:
		if key not in ["type", "id", "domain", "stage", "minimum", "ability", "skill", "task_id", "purpose_id", "source_event_id", "source_check_id"]:
			return "Check floor contains an unsupported field."
	if str(effect.get("domain", "")) != "event_skill_check" or str(effect.get("stage", "")) not in ["natural_d20", "final_total"] or str(effect.get("ability", "")) not in AbilityScores.ABILITIES:
		return "Check floor requires a supported domain, stage and ability."
	for key in ["id", "task_id", "purpose_id", "source_check_id"]:
		if not effect.get(key) is String or not str(effect[key]).is_valid_identifier(): return "Check floor requires exact check context."
	if str(effect.get("source_event_id", "")).is_empty() or (str(effect.get("skill", "")) != "" and str(effect.skill) not in DataLoader.VALID_SKILLS): return "Check floor requires event and skill context."
	var value: Variant = effect.get("minimum")
	if not SharedStepExecutor.formula_content_error(value).is_empty() or not ResourcePoolRules._actor_formula_error(value).is_empty(): return "Check floor requires an actor numeric formula."
	if value is int or value is float:
		if not ResourcePoolRules._integer(value, 1 if effect.stage == "natural_d20" else -100, 20 if effect.stage == "natural_d20" else 100): return "Floor threshold is out of range."
	return ""

static func capture(actor: Character, ability: String, skill: String, context: Dictionary) -> Array[Dictionary]:
	var receipts: Array[Dictionary] = []
	if actor==null or actor.character_id.is_empty(): return receipts
	for feature in actor.features:
		if not feature is Dictionary or not bool(feature.get("enabled", true)): continue
		var source := str(feature.get("source_instance_id", feature.get("id", "")))
		if source.is_empty(): continue
		for effect in feature.get("effects", []) + feature.get("passive_effects", []):
			if not effect is Dictionary or effect.get("type") != "check_floor" or not content_error(effect).is_empty() or not EventResolver._roll_mode_effect_matches(effect, ability, skill, context): continue
			var evaluated := SharedStepExecutor.evaluate_actor_formula(effect.minimum, actor)
			if not evaluated.get("success", false) or not ResourcePoolRules._integer(evaluated.get("value"), 1 if effect.stage == "natural_d20" else -100, 20 if effect.stage == "natural_d20" else 100): continue
			receipts.append({"owner_id":actor.character_id,"source_definition_id":str(feature.get("id", "")),"source_instance_id":source,"effect_id":effect.id,"domain":effect.domain,"stage":effect.stage,"minimum":int(evaluated.value),"capture_policy":"captured_for_test_and_mandatory_rerolls"})
	return receipts

static func natural(raw: int, receipts: Array) -> int:
	var value := raw
	for receipt in receipts:
		if receipt.stage == "natural_d20": value = maxi(value, int(receipt.minimum))
	return value

static func finish(result: Dictionary) -> void:
	var subtotal := int(result.get("total", 0)) - int(result.get("authored_floor_adjustment", 0))
	result["total"] = subtotal
	result["pre_floor_subtotal"] = subtotal
	for receipt in result.get("floor_sources", []):
		if receipt.stage == "final_total": result["total"] = maxi(int(result.total), int(receipt.minimum))
	result["authored_floor_adjustment"] = int(result.total) - subtotal
	result["success"] = int(result.total) >= int(result.dc)
	result["natural_outcome_policy"] = "ability_check_numeric_comparison_no_automatic_1_or_20"
