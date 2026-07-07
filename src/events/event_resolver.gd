## Event Resolver
## Executes event effects on characters: damage, healing, items, conditions, combat triggers.
class_name EventResolver
extends RefCounted


## Resolve a skill check for an event.
## Returns {"success": bool, "roll": int, "dc": int, "modifier": int}.
static func resolve_skill_check(character: Character, check_data: Dictionary) -> Dictionary:
	var ability: String = check_data.get("ability", "STR")
	var dc: int = int(check_data.get("dc", 10))

	var roll := Dice.roll(20)
	var modifier := character.ability_scores.get_ability_modifier(ability)
	var total := roll + modifier

	return {
		"success": total >= dc,
		"natural_roll": roll,
		"total": total,
		"modifier": modifier,
		"dc": dc,
		"ability": ability,
	}


## Apply an array of effect dictionaries to a character.
## Returns a summary array of applied effects (for display).
static func apply_effects(character: Character, effects: Array) -> Array[Dictionary]:
	var results: Array[Dictionary] = []

	for effect in effects:
		var effect_type: String = effect.get("type", "")
		var result := _apply_single_effect(character, effect)
		if not result.is_empty():
			results.append(result)

	return results


## Apply a single effect to a character.
static func _apply_single_effect(character: Character, effect: Dictionary) -> Dictionary:
	var effect_type: String = effect.get("type", "")

	match effect_type:
		"damage":
			var damage_str: String = effect.get("value", "1d6")
			var modifiers := character.ability_scores.get_all_modifiers()
			modifiers["level"] = character.level
			var amount := Dice.parse_dice_string(damage_str, modifiers)
			var actual := character.take_damage(amount)
			return {"type": "damage", "amount": actual, "damage_type": effect.get("damage_type", ""), "message": "%s took %d %s damage!" % [character.character_name, actual, effect.get("damage_type", "")]}

		"heal":
			var heal_str: String = effect.get("value", "1d6")
			var modifiers := character.ability_scores.get_all_modifiers()
			modifiers["level"] = character.level
			var amount := Dice.parse_dice_string(heal_str, modifiers)
			var actual := character.heal(amount)
			return {"type": "heal", "amount": actual, "message": "%s healed %d HP!" % [character.character_name, actual]}

		"heal_self":
			var heal_str: String = effect.get("value", "1d6")
			var modifiers := character.ability_scores.get_all_modifiers()
			modifiers["level"] = character.level
			var amount := Dice.parse_dice_string(heal_str, modifiers)
			var actual := character.heal(amount)
			return {"type": "heal", "amount": actual, "message": "%s healed %d HP!" % [character.character_name, actual]}

		"full_heal":
			var actual := character.heal(character.max_hp)
			return {"type": "heal", "amount": actual, "message": "%s is fully healed!" % character.character_name}

		"give_item":
			var item_id: String = effect.get("item_id", "")
			if not item_id.is_empty():
				character.inventory.add_item(item_id)
				var item_data := DataLoader.get_item(item_id)
				var item_name: String = item_data.get("name", item_id)
				return {"type": "give_item", "item_id": item_id, "message": "%s received %s!" % [character.character_name, item_name]}

		"take_gold":
			var amount: int = int(effect.get("value", 0))
			var taken := mini(amount, character.inventory.gold)
			character.inventory.gold -= taken
			return {"type": "take_gold", "amount": taken, "message": "%s lost %d gold!" % [character.character_name, taken]}

		"grant_condition":
			var condition_name: String = effect.get("condition", "")
			var duration: int = int(effect.get("duration", 3))
			if not condition_name.is_empty():
				character.add_condition(condition_name, duration)
				return {"type": "condition", "condition": condition_name, "duration": duration, "message": "%s is now %s for %d turns!" % [character.character_name, condition_name, duration]}

		"remove_condition":
			var condition_name: String = effect.get("condition", "")
			if not condition_name.is_empty():
				character.remove_condition(condition_name)
				return {"type": "remove_condition", "condition": condition_name, "message": "%s is no longer %s!" % [character.character_name, condition_name]}

		"remove_all_conditions":
			character.conditions.clear()
			return {"type": "remove_all_conditions", "message": "%s is cured of all conditions!" % character.character_name}

		"gold":
			var amount: int = int(effect.get("value", 0))
			character.inventory.gold += amount
			return {"type": "gold", "amount": amount, "message": "%s gained %d gold!" % [character.character_name, amount]}

		"rest":
			character.reset_rest_features()
			return {"type": "rest", "message": "%s takes a rest and recovers abilities." % character.character_name}

		"start_combat":
			var monster_ids: Array = effect.get("monsters", [])
			return {"type": "start_combat", "monster_ids": monster_ids, "message": "Combat begins!"}

		"teleport_random":
			return {"type": "teleport_random", "message": "%s is teleported to a random location!" % character.character_name}

		"reveal_map":
			var radius: int = int(effect.get("radius", 2))
			return {"type": "reveal_map", "radius": radius, "message": "The surrounding area is revealed!"}

		"reduce_speed":
			return {"type": "reduce_speed", "value": int(effect.get("value", 2)), "duration": int(effect.get("duration", 1)), "message": "%s's movement is reduced!" % character.character_name}

		_:
			push_warning("[EventResolver] Unknown effect type: %s" % effect_type)
			return {}

	return {}
