## Class Feature
## Resolves and executes class feature abilities during combat or events.
class_name ClassFeature
extends RefCounted


## Execute an active class feature on a character.
## Returns a result dictionary describing what happened.
static func execute(character: Character, feature: Dictionary, target = null) -> Dictionary:
	var feature_id: String = feature.get("id", "")
	var feature_name: String = feature.get("name", "Unknown")

	# Check if the character has uses remaining
	if not character.use_feature(feature_id):
		return {"success": false, "message": "No uses remaining for %s!" % feature_name}

	var effects: Array = feature.get("effects", [])
	var results: Array[Dictionary] = []

	for effect in effects:
		var result := _resolve_feature_effect(character, effect, target)
		if not result.is_empty():
			results.append(result)

	return {
		"success": true,
		"feature_name": feature_name,
		"results": results,
		"message": "%s used %s!" % [character.character_name, feature_name],
	}


## Resolve a single feature effect.
static func _resolve_feature_effect(character: Character, effect: Dictionary, target) -> Dictionary:
	var effect_type: String = effect.get("type", "")

	match effect_type:
		"heal_self":
			var heal_str: String = effect.get("value", "1d6")
			var modifiers := character.ability_scores.get_all_modifiers()
			modifiers["level"] = character.level
			var amount := Dice.parse_dice_string(heal_str, modifiers)
			var actual := character.heal(amount)
			return {"type": "heal", "amount": actual, "message": "%s healed %d HP!" % [character.character_name, actual]}

		"grant_extra_action":
			return {"type": "extra_action", "message": "%s gains an extra action!" % character.character_name}

		_:
			# Pass through to EventResolver for common effects
			return EventResolver._apply_single_effect(character, effect)
