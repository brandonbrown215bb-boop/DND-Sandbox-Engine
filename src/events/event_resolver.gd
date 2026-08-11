## Event Resolver
## Executes event effects on characters: damage, healing, items, conditions, combat triggers.
class_name EventResolver
extends RefCounted

const SUPPORTED_EFFECT_TYPES := [
	"damage", "heal", "heal_self", "temporary_hp", "full_heal", "give_item",
	"take_gold", "spend_resource", "restore_resource", "grant_condition",
	"apply_condition", "remove_condition", "remove_all_conditions", "gold", "rest",
	"start_combat", "set_concentration", "clear_concentration", "stat_modifier", "cunning_action", "step_of_the_wind", "lay_on_hands", "unarmed_attack", "favored_foe", "hunters_mark", "reckless_attack", "divine_sense", "bardic_inspiration", "pact_magic", "pact_magic_recovery", "sorcery_points", "innate_sorcery", "metamagic",
	"ac_bonus", "speed_modifier", "movement", "roll_modifier", "reaction",
	"teleport_random", "reveal_map", "reduce_speed", "vision_bonus", "area_selection",
]


static func is_effect_supported(effect_type: String) -> bool:
	return effect_type in SUPPORTED_EFFECT_TYPES


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


## Validate a transient combat area-selection descriptor. The selected hexes
## belong to the active combat scene and are never persisted by this effect.
static func resolve_area_selection(effect: Dictionary) -> Dictionary:
	var shape := str(effect.get("shape", "sphere"))
	if shape not in ["sphere", "cone"]:
		return {"success": false, "type": "area_selection", "message": "Unsupported area shape: %s" % shape}

	if shape == "sphere":
		var radius := int(effect.get("radius", 0))
		if radius < 1 or radius > 8:
			return {"success": false, "type": "area_selection", "message": "Area radius must be between 1 and 8."}
		return {
			"success": true,
			"type": "area_selection",
			"shape": shape,
			"radius": radius,
			"persistent": false,
			"message": "Selected a sphere with radius %d." % radius,
		}

	var size := int(effect.get("size", 0))
	if size < 1 or size > 8:
		return {"success": false, "type": "area_selection", "message": "Cone size must be between 1 and 8."}
	return {
		"success": true,
		"type": "area_selection",
		"shape": shape,
		"size": size,
		"persistent": false,
		"message": "Selected a cone with size %d." % size,
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

		"temporary_hp":
			var temp_str: String = effect.get("value", "1d6")
			var temp_amount := Dice.parse_dice_string(temp_str, {"level": character.level})
			if temp_amount <= character.temp_hp:
				return {"type": "temporary_hp", "amount": 0, "message": "%s keeps their existing temporary HP." % character.character_name}
			character.temp_hp = temp_amount
			return {"type": "temporary_hp", "amount": temp_amount, "message": "%s gains %d temporary HP!" % [character.character_name, temp_amount]}

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

		"spend_resource":
			var resource_id := str(effect.get("resource_id", effect.get("feature_id", "")))
			var spend_amount := maxi(1, int(effect.get("amount", 1)))
			var remaining := int(character.feature_uses.get(resource_id, -1))
			if resource_id.is_empty() or remaining < spend_amount:
				return {"type": "spend_resource", "success": false, "amount": 0, "message": "%s could not spend %s." % [character.character_name, resource_id]}
			character.feature_uses[resource_id] = remaining - spend_amount
			return {"type": "spend_resource", "success": true, "amount": spend_amount, "message": "%s spent %d use(s) of %s." % [character.character_name, spend_amount, resource_id]}

		"restore_resource":
			var restore_id := str(effect.get("resource_id", effect.get("feature_id", "")))
			var restore_amount := maxi(1, int(effect.get("amount", 1)))
			var current := int(character.feature_uses.get(restore_id, -1))
			var maximum := _feature_max_uses(character, restore_id)
			if restore_id.is_empty() or current < 0 or maximum < 0:
				return {"type": "restore_resource", "success": false, "amount": 0, "message": "%s has no resource named %s." % [character.character_name, restore_id]}
			var restored := mini(restore_amount, maximum - current)
			character.feature_uses[restore_id] = current + restored
			return {"type": "restore_resource", "success": true, "amount": restored, "message": "%s restored %d use(s) of %s." % [character.character_name, restored, restore_id]}

		"grant_condition":
			var condition_name: String = effect.get("condition", "")
			var duration: int = int(effect.get("duration", 3))
			if not condition_name.is_empty():
				character.add_condition(condition_name, duration)
				return {"type": "condition", "condition": condition_name, "duration": duration, "message": "%s is now %s for %d turns!" % [character.character_name, condition_name, duration]}

		"apply_condition":
			var applied_condition := str(effect.get("condition", ""))
			var applied_duration := int(effect.get("duration", 3))
			if not applied_condition.is_empty():
				character.add_condition(applied_condition, applied_duration)
				return {"type": "condition", "condition": applied_condition, "duration": applied_duration, "message": "%s is now %s for %d turns!" % [character.character_name, applied_condition, applied_duration]}

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

		"set_concentration":
			var spell_id := str(effect.get("spell_id", ""))
			if spell_id.is_empty():
				return {}
			character.concentrating_on = effect.duplicate(true)
			return {"type": "concentration", "spell_id": spell_id, "message": "%s begins concentrating." % character.character_name}

		"clear_concentration":
			character.concentrating_on.clear()
			return {"type": "concentration", "message": "%s ends concentration." % character.character_name}

		"stat_modifier", "ac_bonus", "speed_modifier", "movement":
			var stat_key := str(effect.get("key", effect.get("stat", "")))
			if effect_type == "ac_bonus":
				stat_key = "AC"
			elif effect_type in ["speed_modifier", "movement"]:
				stat_key = "speed"
			var stat_amount := int(effect.get("amount", effect.get("value", 0)))
			var stat_duration := int(effect.get("duration", 1))
			if stat_key.is_empty() or stat_amount == 0:
				return {}
			character.add_modifier("stat", stat_key, stat_amount, stat_duration)
			return {"type": "stat_modifier", "key": stat_key, "amount": stat_amount, "duration": stat_duration, "message": "%s's %s changes by %d for %d turns." % [character.character_name, stat_key, stat_amount, stat_duration]}

		"roll_modifier":
			var roll_key := str(effect.get("key", ""))
			var roll_amount := int(effect.get("amount", effect.get("value", 0)))
			var roll_duration := int(effect.get("duration", 1))
			if roll_key.is_empty() or roll_amount == 0:
				return {}
			character.add_modifier("roll", roll_key, roll_amount, roll_duration)
			return {"type": "roll_modifier", "key": roll_key, "amount": roll_amount, "duration": roll_duration, "message": "%s gains a %s roll modifier of %+d for %d turns." % [character.character_name, roll_key, roll_amount, roll_duration]}

		"pact_magic_recovery":
			var recovered := character.recover_pact_magic_slots(float(effect.get("fraction", 0.5)))
			return {"type": "pact_magic_recovery", "amount": recovered, "message": "%s recovers %d Pact Magic slot%s." % [character.character_name, recovered, "" if recovered == 1 else "s"]}

		"innate_sorcery":
			var duration := maxi(1, int(effect.get("duration", 10)))
			character.add_condition("innate_sorcery", duration)
			return {"type": "innate_sorcery", "duration": duration, "message": "%s unleashes Innate Sorcery for %d turns." % [character.character_name, duration]}

		"reaction":
			var reaction_id := str(effect.get("reaction", ""))
			if reaction_id.is_empty():
				return {}
			return {"type": "reaction", "reaction": reaction_id, "message": "%s has %s available as a reaction." % [character.character_name, reaction_id.replace("_", " ")]}

		"teleport_random":
			return {"type": "teleport_random", "message": "%s is teleported to a random location!" % character.character_name}

		"reveal_map":
			var radius: int = int(effect.get("radius", 2))
			return {"type": "reveal_map", "radius": radius, "message": "The surrounding area is revealed!"}

		"reduce_speed":
			var speed_reduction := int(effect.get("value", 2))
			var speed_duration := int(effect.get("duration", 1))
			character.add_modifier("stat", "speed", -speed_reduction, speed_duration)
			return {"type": "reduce_speed", "value": speed_reduction, "duration": speed_duration, "message": "%s's movement is reduced by %d for %d turns." % [character.character_name, speed_reduction, speed_duration]}

		"vision_bonus":
			var vision_amount := int(effect.get("value", 2))
			var vision_duration := int(effect.get("duration", 1))
			character.add_modifier("stat", "vision", vision_amount, vision_duration)
			return {"type": "vision_bonus", "value": vision_amount, "duration": vision_duration, "message": "%s's vision improves by %d for %d turns." % [character.character_name, vision_amount, vision_duration]}

		"area_selection":
			return resolve_area_selection(effect)

		_:
			push_warning("[EventResolver] Unknown effect type: %s" % effect_type)
			return {}

	return {}


static func _feature_max_uses(character: Character, feature_id: String) -> int:
	return character.get_feature_max_uses(feature_id)
