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
	"nourish",
]


static func is_effect_supported(effect_type: String) -> bool:
	return effect_type in SUPPORTED_EFFECT_TYPES


## Resolve a skill check for an event.
## Returns {"success": bool, "roll": int, "dc": int, "modifier": int}.
static func resolve_skill_check(character: Character, check_data: Dictionary, decisions: Dictionary = {}, authored_context: Dictionary = {}) -> Dictionary:
	var skill := str(check_data.get("skill", ""))
	var ability: String = character.get_skill_check_ability(str(check_data.get("ability", "STR")), skill, bool(check_data.get("use_primal_knowledge", true)))
	var dc: int = int(check_data.get("dc", 10))
	var familiar_help := bool(check_data.get("request_familiar_help", false)) and FamiliarRules.skill_help_available(character, check_data)

	var mode_receipt := ability_check_roll_mode(character, ability, skill, authored_context, familiar_help)
	var advantage := bool(mode_receipt.get("advantage", false))
	var disadvantage := bool(mode_receipt.get("disadvantage", false))
	var merged_decisions := check_data.duplicate(true)
	merged_decisions.merge(decisions, true)
	var floor_sources := CheckFloorRules.capture(character, ability, skill, authored_context)
	var d20_details: Dictionary = RollTokenRules.resolve_d20_test(character, "ability_check", advantage, disadvantage, merged_decisions)
	var roll := int(d20_details.get("total", 1))
	var raw_natural := roll
	roll = CheckFloorRules.natural(roll, floor_sources)
	roll = character.apply_skill_check_roll_floor(roll, skill)
	var roll_floor := CheckFloorRules.natural(character.apply_skill_check_roll_floor(1, skill), floor_sources)
	var tool_bonus := character.inventory.skill_tool_bonus(skill, str(check_data.get("context", "")))
	var check_context: Dictionary = authored_context.duplicate(true)
	check_context["ability"] = ability
	check_context["skill"] = skill
	check_context["dc"] = dc
	var context_tool: Dictionary = character.inventory.skill_check_context_bonus(ability, skill, check_context)
	var contextual_tool_bonus := int(context_tool.get("bonus", 0))
	var modifier := character.get_skill_check_modifier(skill, ability) + tool_bonus + contextual_tool_bonus
	var base_modifier := modifier
	var total := roll + modifier
	var guidance_bonus := 0
	var bonus_dice: Array[Dictionary] = []
	if character.has_condition("guidance") and character.guidance_skill == skill:
		var guidance_roll: Dictionary = Dice.roll_single_details(4, character)
		guidance_bonus = int(guidance_roll.get("total", 0))
		total += guidance_bonus
		bonus_dice.append({"source": "guidance", "label": "Guidance", "sides": 4, "value": guidance_bonus, "roll": guidance_roll.duplicate(true), "included_in_modifier": false, "applied_before_total_floor": true})
	var natural_total_floor := character.apply_feature_check_floor(0, ability, "ability_check")
	var total_floor_active := natural_total_floor > 0
	total = character.apply_feature_check_floor(total, ability, "ability_check")

	var result := {
		"floor_sources": floor_sources,
		"success": total >= dc,
		"roll": roll,
		"natural_roll": roll,
		"raw_natural_roll": raw_natural,
		"total": total,
		"modifier": modifier,
		"base_modifier": base_modifier,
		"dc": dc,
		"ability": ability,
		"guidance_bonus": guidance_bonus,
		"tool_bonus": tool_bonus,
		"contextual_tool_bonus": contextual_tool_bonus,
		"check_context": check_context,
		"context_tool_source": context_tool,
		"actor_id": character.character_id,
		"familiar_help": familiar_help,
		"advantage": advantage and not disadvantage,
		"disadvantage": disadvantage and not advantage,
		"roll_mode": "advantage" if advantage and not disadvantage else ("disadvantage" if disadvantage and not advantage else "normal"),
		"roll_mode_contributors": mode_receipt.get("contributors", []).duplicate(true),
		"roll_details": d20_details.duplicate(true),
		"roll_floor_minimum": roll_floor,
		"total_floor_minimum": natural_total_floor,
		"total_floor_active": total_floor_active,
		"check_bonus_dice": bonus_dice,
		"rolls": d20_details.get("rolls", [roll]),
		"kept": d20_details.get("kept", [true]),
		"roll_token_replaced": bool(d20_details.get("replaced", false)),
		"replaced_by_roll_token": bool(d20_details.get("replaced", false)),
		"roll_token_id": str(d20_details.get("roll_token_id", "")),
		"roll_token_value": int(d20_details.get("roll_token_value", 0)),
		"roll_token_error": str(d20_details.get("roll_token_error", "")),
	}

	CheckFloorRules.finish(result)
	return result


## Pure eligibility query for the selected loaded EventDialog check domain.
## Call again immediately before RollTokenRules commits the original d20.
static func ability_check_roll_mode(character: Character, ability: String, skill: String, context: Dictionary, familiar_help: bool = false) -> Dictionary:
	var grants: Array[Dictionary] = []
	var policies: Array[Dictionary] = []
	var bound := not str(context.get("origin_event_id", "")).is_empty() and not str(context.get("origin_check_id", "")).is_empty()
	if character != null and bound:
		for feature in character.features:
			if not feature is Dictionary or not bool(feature.get("enabled", true)):
				continue
			var feature_id := str(feature.get("id", ""))
			var source_instance_id := str(feature.get("source_instance_id", feature_id))
			for effect in feature.get("effects", []) + feature.get("passive_effects", []):
				if not effect is Dictionary or str(effect.get("type", "")) not in ["ability_check_roll_mode", "ability_check_roll_mode_policy"]:
					continue
				if not _roll_mode_effect_matches(effect, ability, skill, context):
					continue
				var contribution := {"source_owner_id": character.character_id, "source_definition_id": feature_id, "source_instance_id": source_instance_id, "effect_id": str(effect.get("id", "")), "mode": str(effect.get("mode", "")), "operation": str(effect.get("operation", "grant")), "status": "pending"}
				if contribution["operation"] == "grant":
					grants.append(contribution)
				else:
					contribution["exempt_source_definition_ids"] = effect.get("exempt_source_definition_ids", []).duplicate()
					contribution["exempt_source_instance_ids"] = effect.get("exempt_source_instance_ids", []).duplicate()
					policies.append(contribution)
	var contributors: Array[Dictionary] = []
	var has_advantage := familiar_help
	var has_disadvantage := ability.to_upper() == "STR" and character != null and character.has_condition("ray_of_enfeeblement")
	if familiar_help:
		contributors.append({"source_kind": "native", "source_id": "familiar_help", "mode": "advantage", "status": "active"})
	if character != null and character.has_ability_check_advantage(ability):
		has_advantage = true
		contributors.append({"source_kind": "native", "source_id": "existing_ability_check_advantage", "mode": "advantage", "status": "active"})
	if character != null and character.has_feature("champion_remarkable_athlete") and ability.to_upper() == "STR" and skill == "Athletics":
		has_advantage = true
		contributors.append({"source_kind": "native", "source_id": "champion_remarkable_athlete", "mode": "advantage", "status": "active"})
	if has_disadvantage:
		contributors.append({"source_kind": "native", "source_id": "ray_of_enfeeblement", "mode": "disadvantage", "status": "active"})
	for grant in grants:
		var suppressors: Array[Dictionary] = []
		for policy in policies:
			if str(policy.get("mode", "")) != str(grant.get("mode", "")):
				continue
			if str(grant.get("source_definition_id", "")) in policy.get("exempt_source_definition_ids", []) or str(grant.get("source_instance_id", "")) in policy.get("exempt_source_instance_ids", []):
				continue
			suppressors.append(policy)
		var accepted := suppressors.is_empty()
		var outcome := grant.duplicate(true)
		outcome["status"] = "active" if accepted else ("prohibited" if suppressors.any(func(item): return str(item.get("operation", "")) == "prohibit") else "canceled")
		if not suppressors.is_empty():
			outcome["suppressed_by"] = suppressors.map(func(item): return {"source_owner_id": item.get("source_owner_id", ""), "source_definition_id": item.get("source_definition_id", ""), "source_instance_id": item.get("source_instance_id", ""), "effect_id": item.get("effect_id", ""), "operation": item.get("operation", "")})
		contributors.append(outcome)
		if accepted:
			if str(grant.get("mode", "")) == "advantage":
				has_advantage = true
			else:
				has_disadvantage = true
	for policy in policies:
		contributors.append({"source_owner_id": policy.get("source_owner_id", ""), "source_definition_id": policy.get("source_definition_id", ""), "source_instance_id": policy.get("source_instance_id", ""), "effect_id": policy.get("effect_id", ""), "mode": policy.get("mode", ""), "operation": policy.get("operation", ""), "exempt_source_definition_ids": policy.get("exempt_source_definition_ids", []).duplicate(), "exempt_source_instance_ids": policy.get("exempt_source_instance_ids", []).duplicate(), "status": "applied"})
	return {"advantage": has_advantage, "disadvantage": has_disadvantage, "effective_mode": "advantage" if has_advantage and not has_disadvantage else ("disadvantage" if has_disadvantage and not has_advantage else "normal"), "contributors": contributors}


static func _roll_mode_effect_matches(effect: Dictionary, ability: String, skill: String, context: Dictionary) -> bool:
	return str(effect.get("domain", "")) == "event_skill_check" and str(effect.get("ability", "")).to_upper() == ability.to_upper() and str(effect.get("skill", "")) == skill and ability_check_context_matches(effect, context)


## Reroll only the captured d20 and explicitly selected bonus dice. This does
## not rerun skill modifiers, loaded context, roll-token replacement or native
## feature choices that have already settled.
static func reroll_captured_skill_check(character: Character, captured: Dictionary, reroll_mode: String, bonus_dice_policy: String, new_test_mode: String = "captured", level_bonus: int = 0) -> Dictionary:
	if character == null or not can_reroll_captured_skill_check(captured, reroll_mode, bonus_dice_policy):
		return {}
	var original_mode := str(captured.get("roll_mode", "normal"))
	var selected_mode := original_mode if new_test_mode == "captured" else new_test_mode
	if selected_mode not in ["normal", "advantage", "disadvantage"]:
		return {}
	var d20_details: Dictionary
	if reroll_mode == "whole_test" and selected_mode == "advantage":
		d20_details = Dice.roll_with_advantage_details(20, character)
	elif reroll_mode == "whole_test" and selected_mode == "disadvantage":
		d20_details = Dice.roll_with_disadvantage_details(20, character)
	else:
		d20_details = Dice.roll_single_details(20, character)
	var raw_natural := int(d20_details.get("total", 1))
	var natural := maxi(int(captured.get("roll_floor_minimum", 1)), raw_natural)
	var bonus_dice: Array = captured.get("check_bonus_dice", []).duplicate(true)
	if bonus_dice_policy == "reroll":
		for index in bonus_dice.size():
			var bonus: Dictionary = bonus_dice[index]
			var sides := int(bonus.get("sides", 0))
			if sides not in ResourcePoolRules.SUPPORTED_DIE_SIZES:
				return {}
			var rolled: Dictionary = Dice.roll_single_details(sides, character)
			bonus["value"] = int(rolled.get("total", 0))
			bonus["roll"] = rolled.duplicate(true)
			bonus["rerolled"] = true
			bonus_dice[index] = bonus
	var base_modifier := int(captured.get("base_modifier", captured.get("modifier", 0))) + level_bonus
	var pre_floor_total := natural + base_modifier
	for bonus in bonus_dice:
		if bonus is Dictionary and bool(bonus.get("applied_before_total_floor", false)):
			pre_floor_total += int(bonus.get("value", 0)) * int(bonus.get("sign", 1))
	var total := maxi(int(captured.get("total_floor_minimum", 0)), pre_floor_total) if bool(captured.get("total_floor_active", false)) else pre_floor_total
	var modifier := base_modifier
	for bonus in bonus_dice:
		if not bonus is Dictionary:
			continue
		if bool(bonus.get("included_in_modifier", false)):
			modifier += int(bonus.get("value", 0)) * int(bonus.get("sign", 1))
		if not bool(bonus.get("applied_before_total_floor", false)):
			total += int(bonus.get("value", 0)) * int(bonus.get("sign", 1))
	var rerolled := captured.duplicate(true)
	rerolled["roll"] = natural
	rerolled["natural_roll"] = natural
	rerolled["raw_natural_roll"] = raw_natural
	rerolled["total"] = total
	rerolled["modifier"] = modifier
	rerolled["success"] = total >= int(captured.get("dc", 0))
	rerolled["roll_details"] = d20_details.duplicate(true)
	rerolled["rolls"] = d20_details.get("rolls", [raw_natural]).duplicate(true)
	rerolled["kept"] = d20_details.get("kept", [true]).duplicate(true)
	rerolled["check_bonus_dice"] = bonus_dice
	var actual_mode := selected_mode if reroll_mode == "whole_test" else "normal"
	rerolled["original_roll_mode"] = original_mode
	rerolled["roll_mode"] = actual_mode
	rerolled["reroll_roll_mode"] = actual_mode
	rerolled["original_advantage"] = bool(captured.get("advantage", original_mode == "advantage"))
	rerolled["original_disadvantage"] = bool(captured.get("disadvantage", original_mode == "disadvantage"))
	rerolled["original_familiar_help"] = bool(captured.get("familiar_help", false))
	rerolled["advantage"] = actual_mode == "advantage"
	rerolled["disadvantage"] = actual_mode == "disadvantage"
	# Familiar Help may explain the captured advantage, but a natural-only reroll
	# does not roll with that advantage again.
	rerolled["familiar_help"] = bool(captured.get("familiar_help", false)) and reroll_mode == "whole_test"
	rerolled["captured_level_bonus"] = level_bonus
	rerolled["new_test_roll_mode"] = selected_mode
	for bonus in bonus_dice:
		if not bonus is Dictionary:
			continue
		match str(bonus.get("source", "")):
			"guidance": rerolled["guidance_bonus"] = int(bonus.get("value", 0))
			"bardic_inspiration": rerolled["inspiration_bonus"] = int(bonus.get("value", 0))
			"fighter_tactical_mind": rerolled["tactical_mind_bonus"] = int(bonus.get("value", 0))
	rerolled.erase("authored_floor_adjustment")
	CheckFloorRules.finish(rerolled)
	return rerolled


static func can_reroll_captured_skill_check(captured: Dictionary, reroll_mode: String, bonus_dice_policy: String) -> bool:
	if reroll_mode not in ["natural_only", "whole_test"] or bonus_dice_policy not in ["keep", "reroll"]:
		return false
	if str(captured.get("roll_mode", "")) not in ["normal", "advantage", "disadvantage"]:
		return false
	var raw_natural: Variant = captured.get("raw_natural_roll", null)
	var floor_minimum: Variant = captured.get("roll_floor_minimum", null)
	var total_floor: Variant = captured.get("total_floor_minimum", null)
	var details: Variant = captured.get("roll_details", null)
	if not ResourcePoolRules._integer(raw_natural, 1, 20) or not ResourcePoolRules._integer(floor_minimum, 1, 20) or not ResourcePoolRules._integer(total_floor, 0, 30) or not captured.get("total_floor_active") is bool or not details is Dictionary:
		return false
	if bool(captured.get("total_floor_active", false)) != (int(total_floor) > 0):
		return false
	if not _valid_captured_d20_receipt(details, str(captured.get("roll_mode", "")), raw_natural):
		return false
	var bonus_dice: Variant = captured.get("check_bonus_dice", [])
	if not bonus_dice is Array:
		return false
	for bonus in bonus_dice:
		if not bonus is Dictionary or int(bonus.get("sides", 0)) not in ResourcePoolRules.SUPPORTED_DIE_SIZES or int(bonus.get("value", 0)) < 1 or int(bonus.get("value", 0)) > int(bonus.get("sides", 0)):
			return false
		if int(bonus.get("sign", 1)) not in [-1, 1]:
			return false
		var bonus_roll: Variant = bonus.get("roll", null)
		if not bonus_roll is Dictionary or int(bonus_roll.get("total", -1)) != int(bonus.get("value", 0)):
			return false
		var bonus_rolls: Variant = bonus_roll.get("rolls", null)
		var bonus_kept: Variant = bonus_roll.get("kept", null)
		if not bonus_rolls is Array or bonus_rolls.is_empty() or not bonus_kept is Array or bonus_kept.size() != bonus_rolls.size():
			return false
		var kept_count := 0
		var kept_total := -1
		for index in bonus_rolls.size():
			if not ResourcePoolRules._integer(bonus_rolls[index], 1, int(bonus.get("sides", 0))) or not bonus_kept[index] is bool:
				return false
			if bool(bonus_kept[index]):
				kept_count += 1
				kept_total = int(bonus_rolls[index])
		if kept_count != 1 or kept_total != int(bonus.get("value", 0)):
			return false
	return true


static func _valid_captured_d20_receipt(details: Dictionary, mode: String, expected_total: int) -> bool:
	var rolls: Variant = details.get("rolls", null)
	var kept: Variant = details.get("kept", null)
	if not rolls is Array or rolls.is_empty() or not kept is Array or kept.size() != rolls.size():
		return false
	var replaced := bool(details.get("replaced_by_roll_token", details.get("replaced", false)))
	if replaced and str(details.get("mode", "")) != "replaced":
		return false
	var expected_count := 2 if mode in ["advantage", "disadvantage"] and not replaced else 1
	if rolls.size() != expected_count or int(details.get("total", -1)) != expected_total:
		return false
	var kept_count := 0
	var kept_total := -1
	var high := -1
	var low := 21
	for index in rolls.size():
		if not ResourcePoolRules._integer(rolls[index], 1, 20) or not kept[index] is bool:
			return false
		var value := int(rolls[index])
		high = maxi(high, value)
		low = mini(low, value)
		if bool(kept[index]):
			kept_count += 1
			kept_total = value
	if kept_count != 1 or kept_total != expected_total:
		return false
	if not replaced and mode == "advantage" and expected_total != high:
		return false
	if not replaced and mode == "disadvantage" and expected_total != low:
		return false
	return true


## Validate a transient combat area-selection descriptor. The selected hexes
## belong to the active combat scene and are never persisted by this effect.
static func resolve_area_selection(effect: Dictionary) -> Dictionary:
	var shape := str(effect.get("shape", "sphere"))
	if shape not in ["sphere", "cone", "cube", "square", "point", "line"]:
		return {"success": false, "type": "area_selection", "message": "Unsupported area shape: %s" % shape}
	if shape == "point":
		return {"success": true, "type": "area_selection", "shape": shape, "persistent": false, "message": "Selected one point."}
	if shape == "line":
		var length := int(effect.get("size", 0))
		if length < 1 or length > 12:
			return {"success": false, "type": "area_selection", "message": "Line length must be between 1 and 12 hexes."}
		return {"success": true, "type": "area_selection", "shape": shape, "size": length, "persistent": false, "message": "Selected a line up to %d hexes long." % length}
	if shape == "square":
		var size_feet := int(effect.get("size_feet", 0))
		if size_feet < 5 or size_feet > 60:
			return {"success": false, "type": "area_selection", "message": "Square size must be between 5 and 60 feet."}
		return {
			"success": true,
			"type": "area_selection",
			"shape": shape,
			"size_feet": size_feet,
			"persistent": false,
			"message": "Selected a %d-foot square." % size_feet,
		}

	if shape == "sphere":
		var radius := int(effect.get("radius", 0))
		if radius < 1 or radius > 40:
			return {"success": false, "type": "area_selection", "message": "Sphere radius must be between 1 and 40 hexes."}
		return {
			"success": true,
			"type": "area_selection",
			"shape": shape,
			"radius": radius,
			"persistent": false,
			"message": "Selected a sphere with radius %d." % radius,
		}

	var size := int(effect.get("size", 0))
	if size < 1 or size > 12:
		return {"success": false, "type": "area_selection", "message": "%s size must be between 1 and 12." % shape.capitalize()}
	return {
		"success": true,
		"type": "area_selection",
		"shape": shape,
		"size": size,
		"persistent": false,
		"message": "Selected a %s with size %d." % [shape.capitalize(), size],
	}


## Apply an array of effect dictionaries to a character.
## Returns a summary array of applied effects (for display).
static func apply_effects(character: Character, effects: Array, roller: Character = null, casting_ability: String = "") -> Array[Dictionary]:
	var results: Array[Dictionary] = []

	for effect in effects:
		var effect_type: String = effect.get("type", "")
		var result := _apply_single_effect(character, effect, roller, casting_ability)
		if not result.is_empty():
			results.append(result)

	return results


## Apply a single effect to a character.
static func _apply_single_effect(character: Character, effect: Dictionary, roller: Character = null, casting_ability: String = "") -> Dictionary:
	var effect_type: String = effect.get("type", "")
	if roller == null:
		roller = character

	match effect_type:
		"nourish":
			var days := maxi(1, int(effect.get("days", 1)))
			character.add_nourishment(days)
			return {"type": "nourish", "days": days, "message": "%s has food for %d day%s." % [character.character_name, days, "" if days == 1 else "s"]}

		"damage":
			var damage_str: String = effect.get("value", "1d6")
			var modifiers := character.ability_scores.get_all_modifiers()
			modifiers["level"] = character.level
			var amount := Dice.parse_dice_string(damage_str, modifiers)
			var actual := int(CombatAction.resolve_damage(character, amount, str(effect.get("damage_type", "")))["damage"])
			return {"type": "damage", "amount": actual, "damage_type": effect.get("damage_type", ""), "message": "%s took %d %s damage!" % [character.character_name, actual, effect.get("damage_type", "")]}

		"heal":
			var heal_str := _level_scaled_expression(effect, "value_by_level", "value", character.level, "1d6")
			var modifiers := character.ability_scores.get_all_modifiers()
			modifiers["level"] = character.level
			var amount := Dice.parse_dice_string(heal_str, modifiers, roller)
			amount = SpellEffects.maximize_healing(character, amount, Dice.maximum_dice_string(heal_str, modifiers))
			if bool(effect.get("ability_bonus_from_caster", false)) and roller != null:
				amount += roller.ability_scores.get_ability_modifier(casting_ability if casting_ability in AbilityScores.ABILITIES else roller.get_spellcasting_ability())
			amount = maxi(0, amount)
			var actual := character.heal(amount)
			return {"type": "heal", "amount": actual, "message": "%s healed %d HP!" % [character.character_name, actual]}

		"heal_self":
			var heal_str := _level_scaled_expression(effect, "value_by_level", "value", character.level, "1d6")
			var modifiers := character.ability_scores.get_all_modifiers()
			modifiers["level"] = character.level
			var amount := maxi(0, Dice.parse_dice_string(heal_str, modifiers, roller))
			amount = SpellEffects.maximize_healing(character, amount, Dice.maximum_dice_string(heal_str, modifiers))
			var actual := character.heal(amount)
			return {"type": "heal", "amount": actual, "message": "%s healed %d HP!" % [character.character_name, actual]}

		"temporary_hp":
			var temp_str := _level_scaled_expression(effect, "value_by_level", "value", character.level, "1d6")
			var modifiers := character.ability_scores.get_all_modifiers()
			modifiers["level"] = character.level
			var temp_amount := Dice.parse_dice_string(temp_str, modifiers, roller)
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
			var stat_amount := _level_scaled_amount(effect, character.level)
			var stat_duration := int(effect.get("duration", 1))
			if stat_key.is_empty() or stat_amount == 0:
				return {}
			character.add_modifier("stat", stat_key, stat_amount, stat_duration)
			return {"type": "stat_modifier", "key": stat_key, "amount": stat_amount, "duration": stat_duration, "message": "%s's %s changes by %d for %d turns." % [character.character_name, stat_key, stat_amount, stat_duration]}

		"roll_modifier":
			var roll_key := str(effect.get("key", ""))
			var roll_amount := _level_scaled_amount(effect, character.level)
			var roll_duration := int(effect.get("duration", 1))
			if roll_key.is_empty() or roll_amount == 0:
				return {}
			character.add_modifier("roll", roll_key, roll_amount, roll_duration)
			return {"type": "roll_modifier", "key": roll_key, "amount": roll_amount, "duration": roll_duration, "message": "%s gains a %s roll modifier of %+d for %d turns." % [character.character_name, roll_key, roll_amount, roll_duration]}

		"pact_magic_recovery":
			var recovery_fraction := float(effect.get("fraction", 0.5))
			var recovery_by_level: Dictionary = effect.get("fraction_by_level", {})
			var recovery_level := 0
			for level_key in recovery_by_level:
				var attained_level := int(level_key)
				if attained_level <= character.level and attained_level > recovery_level:
					recovery_level = attained_level
			if recovery_level > 0:
				recovery_fraction = float(recovery_by_level[str(recovery_level)])
			var recovered := character.recover_pact_magic_slots(recovery_fraction)
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
			if SpellEffects.has_spell(character, "freedom_of_movement"):
				return {"type": "reduce_speed", "value": 0, "duration": int(effect.get("duration", 1)), "message": "%s is unaffected by the movement reduction." % character.character_name}
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


static func _level_scaled_amount(effect: Dictionary, level: int) -> int:
	var progression: Dictionary = effect.get("amount_by_level", {})
	if progression.is_empty():
		return int(effect.get("amount", effect.get("value", 0)))
	var threshold := 0
	for key in progression:
		var attained := int(key)
		if attained <= level and attained > threshold:
			threshold = attained
	return int(progression[str(threshold)]) if threshold > 0 else int(effect.get("amount", effect.get("value", 0)))


static func _level_scaled_expression(effect: Dictionary, table_field: String, value_field: String, level: int, fallback: String) -> String:
	var progression: Dictionary = effect.get(table_field, {})
	var threshold := 0
	for key in progression:
		var attained := int(key)
		if attained <= level and attained > threshold:
			threshold = attained
	return str(progression[str(threshold)]) if threshold > 0 else str(effect.get(value_field, fallback))


## All four authored filters combine; an absent check fact never matches a filter.
static func ability_check_context_matches(effect: Dictionary, context: Dictionary) -> bool:
	if not ClassFeature.ability_check_filter_error(effect).is_empty(): return false
	for field in ["task_id", "purpose_id", "source_event_id", "source_check_id"]:
		if not effect.has(field): continue
		var fact: String = "origin_event_id" if field == "source_event_id" else "origin_check_id" if field == "source_check_id" else field
		if not context.has(fact) or effect[field] != context[fact]: return false
	return true
