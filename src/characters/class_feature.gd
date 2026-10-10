## Class Feature
## Resolves and executes class feature abilities during combat or events.
class_name ClassFeature
extends RefCounted

## Common self-targeted class activations use the same costs, budgets and
## effect vocabulary. Targeted combat actions keep their existing resolvers.
const COMMON_SELF_EFFECTS := [
	"heal", "heal_self", "temporary_hp", "full_heal",
	"grant_condition", "apply_condition", "remove_condition",
	"remove_all_conditions", "stat_modifier", "ac_bonus",
	"speed_modifier", "roll_modifier", "restore_resource",
	"pact_magic_recovery", "innate_sorcery", "clear_concentration",
]

static func content_error(feature: Dictionary) -> String:
	if feature.get("executor", "") != "class_feature":
		return "Unknown feature executor"
	if feature.get("type", "") != "active" or feature.get("target", "self") != "self":
		return "Common class activations must target the user"
	if feature.has("requires_no_heavy_armor") and not feature["requires_no_heavy_armor"] is bool:
		return "Armor requirements must be boolean"
	if feature.get("action_cost", "") not in ["action", "magic_action", "bonus_action", "free"]:
		return "Unsupported action cost"
	if feature.has("resource_id"):
		if not feature["resource_id"] is String or feature["resource_id"].is_empty():
			return "Resource reference must be a nonempty ID"
	elif feature.get("uses_per", "") not in ["short_rest", "long_rest", "rest", "turn", "combat"]:
		return "An active feature requires an explicit resource recovery cadence"
	var cost: Variant = feature.get("resource_cost", 1)
	if not (cost is int or cost is float) or float(cost) != float(int(cost)) or int(cost) < 1 or int(cost) > 100:
		return "Resource cost must be a positive integer up to 100"
	if not feature.get("effects", []) is Array or feature.get("effects", []).is_empty():
		return "Common class activations require an effect"
	for effect in feature["effects"]:
		var error := _effect_content_error(effect)
		if not error.is_empty():
			return error
	if not feature.get("passive_effects", []) is Array:
		return "Passive class effects must be an array"
	for effect in feature.get("passive_effects", []):
		var error := passive_effect_content_error(effect)
		if not error.is_empty():
			return error
	return ""


static func passive_effect_content_error(effect: Variant) -> String:
	if not effect is Dictionary:
		return "Passive class effects must be dictionaries"
	var effect_type := str(effect.get("type", ""))
	if effect_type not in ["ability_check_override", "ability_check_advantage", "ability_check_floor", "saving_throw_advantage"]:
		return "Unsupported shared passive operation"
	var ability := str(effect.get("ability", "")).to_upper()
	if ability not in ["STR", "DEX", "CON", "INT", "WIS", "CHA"]:
		return "Passive check operation requires a supported ability"
	if effect_type == "ability_check_override":
		var skills: Variant = effect.get("skills", [])
		if not skills is Array or skills.is_empty() or skills.size() > 18:
			return "Ability check override requires a bounded skill list"
		for skill in skills:
			if not skill is String or skill.is_empty() or skill.length() > 32:
				return "Ability check override contains an invalid skill"
	if effect_type == "ability_check_floor":
		var applies_to: Variant = effect.get("applies_to", [])
		if not applies_to is Array or applies_to.is_empty():
			return "Ability check floor requires a check type"
		for check_type in applies_to:
			if check_type not in ["ability_check", "saving_throw"]:
				return "Ability check floor contains an unsupported check type"
	for field in ["condition", "unless_condition"]:
		if effect.has(field) and (not effect[field] is String or effect[field].is_empty() or not effect[field].is_valid_identifier()):
			return "Conditional feature effect requires a simple condition ID"
	return ""

static func _effect_content_error(effect: Variant) -> String:
	if not effect is Dictionary or str(effect.get("type", "")) not in COMMON_SELF_EFFECTS:
		return "Unsupported common self-effect"
	var effect_type := str(effect["type"])
	if effect_type in ["heal", "heal_self", "temporary_hp"]:
		var expressions: Array = [effect.get("value", "")]
		if effect.has("value_by_level"):
			if not effect["value_by_level"] is Dictionary or effect["value_by_level"].is_empty() or not effect["value_by_level"].has("1"):
				return "Healing scaling requires a level table with a level-1 baseline"
			expressions = effect["value_by_level"].values()
			for key in effect["value_by_level"]:
				if not str(key).is_valid_int() or str(int(key)) != str(key) or int(key) < 1 or int(key) > 20:
					return "Healing scaling level must be 1-20"
		var expression := RegEx.new()
		expression.compile("^[1-9][0-9]?d(4|6|8|10|12|20)(\\+(level|STR|DEX|CON|INT|WIS|CHA|[0-9]{1,3}))?$")
		for value in expressions:
			if not value is String or expression.search(value) == null:
				return "Healing requires bounded dice with an optional level, ability modifier or constant"
	if effect_type in ["grant_condition", "apply_condition", "remove_condition"]:
		var condition := str(effect.get("condition", ""))
		if condition.is_empty() or condition.length() > 48 or not condition.is_valid_identifier():
			return "Condition effects require a simple condition ID"
		if effect_type != "remove_condition" and (int(effect.get("duration", 1)) < 1 or int(effect.get("duration", 1)) > 100):
			return "Condition duration must be 1-100 turns"
	if effect_type in ["stat_modifier", "ac_bonus", "speed_modifier", "roll_modifier"]:
		var amount := int(effect.get("amount", effect.get("value", 0)))
		if amount < -100 or amount > 100:
			return "Modifier amount must be between -100 and 100"
		if int(effect.get("duration", 1)) < 1 or int(effect.get("duration", 1)) > 100:
			return "Modifier duration must be 1-100 turns"
		if effect.has("amount_by_level"):
			var levels: Variant = effect["amount_by_level"]
			if not levels is Dictionary or levels.is_empty() or not levels.has("1"):
				return "Modifier scaling requires a level table with a level-1 baseline"
			for key in levels:
				var value: Variant = levels[key]
				if not str(key).is_valid_int() or str(int(key)) != str(key) or int(key) < 1 or int(key) > 20:
					return "Modifier scaling level must be 1-20"
				if not (value is int or value is float) or float(value) != float(int(value)) or int(value) < -100 or int(value) > 100:
					return "Modifier scaling amount must be an integer from -100 to 100"
	if effect_type == "restore_resource":
		if str(effect.get("resource_id", effect.get("feature_id", ""))).is_empty() or int(effect.get("amount", 1)) < 1 or int(effect.get("amount", 1)) > 100:
			return "Resource recovery requires a resource ID and amount from 1-100"
	if effect_type == "pact_magic_recovery":
		var fraction := float(effect.get("fraction", 0.5))
		if fraction <= 0.0 or fraction > 1.0:
			return "Pact Magic recovery fraction must be above 0 and at most 1"
		if effect.has("fraction_by_level"):
			var fractions: Variant = effect["fraction_by_level"]
			if not fractions is Dictionary or fractions.is_empty() or not fractions.has("1"):
				return "Pact Magic recovery fractions require a level-1 baseline"
			for key in fractions:
				var level_fraction: Variant = fractions[key]
				if not str(key).is_valid_int() or str(int(key)) != str(key) or int(key) < 1 or int(key) > 20 or not (level_fraction is int or level_fraction is float) or float(level_fraction) <= 0.0 or float(level_fraction) > 1.0:
					return "Pact Magic recovery fractions must be between 0 and 1 at levels 1-20"
	if effect_type == "innate_sorcery" and (int(effect.get("duration", 10)) < 1 or int(effect.get("duration", 10)) > 100):
		return "Innate Sorcery duration must be 1-100 turns"
	return ""

static func availability(character: Character, feature: Dictionary, budget: CombatTurnBudget = null) -> Dictionary:
	var owned := character.get_feature(str(feature.get("id", "")))
	var error := "Feature is not owned" if owned.is_empty() else content_error(owned)
	var pool := str(owned.get("resource_id", owned.get("id", "")))
	var remaining := int(character.feature_uses.get(pool, 0))
	var cost := int(owned.get("resource_cost", 1))
	if str(owned.get("id", "")) == "barbarian_rage" and character.has_condition("raging"):
		cost = 0
	var action := str(owned.get("action_cost", "action"))
	if error.is_empty() and bool(owned.get("requires_no_heavy_armor", false)) and character._is_wearing_heavy_armor():
		error = "Unavailable while wearing heavy armor"
	if error.is_empty() and remaining < cost:
		error = "No uses remaining"
	if error.is_empty() and budget != null and not budget.can_spend(action):
		error = "No %s available" % action.replace("_", " ")
	return {"available": error.is_empty(), "reason": error, "remaining": remaining, "maximum": character.get_feature_max_uses(pool), "cost": cost, "action_cost": action}


## Execute an active class feature on a character.
## Returns a result dictionary describing what happened.
static func execute(character: Character, feature: Dictionary, target = null, budget: CombatTurnBudget = null) -> Dictionary:
	# Commands and direct callers both resolve current owned production metadata.
	feature = character.get_feature(str(feature.get("id", "")))
	if feature.is_empty():
		return {"success": false, "message": "Feature is not owned."}
	var feature_id: String = feature.get("id", "")
	var feature_name: String = feature.get("name", "Unknown")
	var sorcery_incarnate_reactivation := feature_id == "sorcerer_innate_sorcery" and character.class_id == "sorcerer" and character.level >= 7 and int(character.feature_uses.get(feature_id, 0)) <= 0
	if feature_id == "sorcerer_innate_sorcery" and character.has_condition("innate_sorcery"):
		return {"success": false, "message": "Innate Sorcery is already active."}
	if sorcery_incarnate_reactivation and character.get_sorcery_points() < 2:
		return {"success": false, "message": "Sorcery Incarnate can reactivate Innate Sorcery for 2 Sorcery Points."}
	if feature.has("executor"):
		var available := availability(character, feature, budget)
		if (not available["available"] and not sorcery_incarnate_reactivation) or (target != null and target != character):
			return {"success": false, "message": available["reason"] if not available["available"] else "This feature can only target its user."}
	elif budget != null and not budget.can_spend(str(feature.get("action_cost", "action"))):
		return {"success": false, "message": "Action unavailable."}
	if feature_id == "barbarian_rage" and character.has_condition("raging"):
		if budget != null:
			budget.spend("bonus_action")
		BarbarianRules.maintain_rage(character)
		return {"success": true, "rage_extended": true, "results": [{"message": "%s extends Rage." % character.character_name}]}

	# Check if the character has uses remaining
	if sorcery_incarnate_reactivation and budget != null and not budget.can_spend(str(feature.get("action_cost", "action"))):
		return {"success": false, "message": "No Bonus Action is available to reactivate Innate Sorcery."}
	if sorcery_incarnate_reactivation:
		character.spend_sorcery_points(2)
		if budget != null:
			budget.spend(str(feature.get("action_cost", "action")))
	elif not character.use_feature(feature_id):
		return {"success": false, "message": "No uses remaining for %s!" % feature_name}
	if budget != null and not sorcery_incarnate_reactivation:
		budget.spend(str(feature.get("action_cost", "action")))

	var effects: Array = feature.get("effects", [])
	var results: Array[Dictionary] = []

	for effect in effects:
		var result := _resolve_feature_effect(character, effect, target)
		if not result.is_empty():
			results.append(result)
	if feature_id == "barbarian_rage":
		BarbarianRules.start_rage(character)

	return {
		"success": true,
		"feature_name": feature_name,
		"results": results,
		"message": "%s used %s%s!" % [character.character_name, feature_name, " for 2 Sorcery Points" if sorcery_incarnate_reactivation else ""],
	}


## Resolve a single feature effect.
static func _resolve_feature_effect(character: Character, effect: Dictionary, target) -> Dictionary:
	var effect_type: String = effect.get("type", "")

	match effect_type:
		"grant_extra_action":
			return {"type": "extra_action", "message": "%s gains an extra action!" % character.character_name}

		_:
			# Pass through to EventResolver for common effects
			return EventResolver._apply_single_effect(character, effect)
