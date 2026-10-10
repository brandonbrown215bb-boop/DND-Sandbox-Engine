## Spell damage/healing scaling, damage rolls, rerolls and settlement.
class_name SpellDamageRolls
extends RefCounted

static func spell_damage_formula(caster: Character, spell_data: Dictionary, slot_level: int = 0) -> String:
	var formula := str(spell_data.get("damage", "0"))
	if caster == null:
		return formula
	var base_level := int(spell_data.get("level", 0))
	if base_level == 0:
		var scaling: Dictionary = spell_data.get("scaling", {})
		var thresholds: Array[int] = []
		for threshold in scaling:
			if str(threshold).is_valid_int():
				thresholds.append(int(threshold))
		thresholds.sort()
		for threshold in thresholds:
			if caster.level >= threshold:
				formula = str(scaling[str(threshold)])
	var upcast: Dictionary = spell_data.get("upcast", {})
	var extra_dice := str(upcast.get("damage_per_level", ""))
	var start_level := int(upcast.get("starting_level", base_level))
	var interval := maxi(1, int(upcast.get("levels_per_increment", 1)))
	var increments := int(maxi(0, slot_level - start_level) / interval)
	if increments > 0 and not extra_dice.is_empty():
		var die_pattern := RegEx.new()
		die_pattern.compile("^([0-9]*)[dD]([0-9]+)$")
		var die_match := die_pattern.search(extra_dice.replace(" ", ""))
		if die_match != null:
			var dice_per_increment := 1 if die_match.get_string(1).is_empty() else int(die_match.get_string(1))
			var sides := int(die_match.get_string(2))
			formula += " + %dd%d" % [dice_per_increment * increments, sides]
	return formula


static func spell_delayed_damage_for_resolution(caster: Character, spell_data: Dictionary, resolution: Dictionary) -> Dictionary:
	var delayed: Dictionary = spell_data.get("delayed_damage", {})
	if delayed.is_empty() or not bool(resolution.get("hit", false)):
		return {}
	var delayed_spell := spell_data.duplicate(true)
	delayed_spell["damage"] = str(delayed.get("damage", ""))
	delayed_spell["damage_type"] = str(delayed.get("damage_type", spell_data.get("damage_type", "acid")))
	return {
		"spell_id": str(spell_data.get("id", "")),
		"formula": SpellDamageRolls.spell_damage_formula(caster, delayed_spell, int(resolution.get("slot_level", spell_data.get("level", 0)))),
		"damage_type": str(delayed_spell["damage_type"]),
		"trigger": str(delayed.get("trigger", "end_of_target_next_turn"))
	}


static func spell_effects_for_slot_level(spell_data: Dictionary, slot_level: int) -> Array:
	var effects: Array = spell_data.get("effects", []).duplicate(true)
	var upcast: Dictionary = spell_data.get("upcast", {})
	var start_level := int(upcast.get("starting_level", int(spell_data.get("level", 0))))
	var healing_per_level := int(upcast.get("healing_per_level", 0))
	var extra_healing := maxi(0, slot_level - start_level) * healing_per_level
	var healing_dice_per_level := str(upcast.get("healing_dice_per_level", ""))
	var healing_increments := maxi(0, slot_level - start_level)
	var temp_hp_per_level := int(upcast.get("temporary_hp_per_level", 0))
	var extra_temp_hp := maxi(0, slot_level - start_level) * temp_hp_per_level
	var hp_per_level := int(upcast.get("hit_points_per_level", 0))
	var extra_hit_points := maxi(0, slot_level - start_level) * hp_per_level
	for index in effects.size():
		var effect_type := str(effects[index].get("type", ""))
		if effect_type == "heal" and extra_healing > 0:
			effects[index]["value"] = int(effects[index].get("value", 0)) + extra_healing
		elif effect_type == "heal" and healing_increments > 0 and not healing_dice_per_level.is_empty():
			var die_pattern := RegEx.new()
			die_pattern.compile("^([0-9]*)[dD]([0-9]+)$")
			var die_match := die_pattern.search(healing_dice_per_level.replace(" ", ""))
			if die_match != null:
				var dice_per_increment := 1 if die_match.get_string(1).is_empty() else int(die_match.get_string(1))
				var sides := int(die_match.get_string(2))
				var base_value := str(effects[index].get("value", "0"))
				effects[index]["value"] = "%s + %dd%d" % [base_value, dice_per_increment * healing_increments, sides]
		elif effect_type == "temporary_hp" and extra_temp_hp > 0:
			effects[index]["value"] = "%s + %d" % [str(effects[index].get("value", "0")), extra_temp_hp]
		elif effect_type == "aid_hp_bonus" and extra_hit_points > 0:
			effects[index]["value"] = int(effects[index].get("value", 0)) + extra_hit_points
	return effects


static func _roll_spell_damage(caster: Character, formula: String, repetitions: int, decisions: Dictionary) -> Dictionary:
	var context: Dictionary = decisions.get("spell_damage_context", {})
	# A damaging area spell rolls damage once for every target of that cast.
	if context.has("details"):
		return context["details"]
	var details := {"formula": formula, "dice_terms": [], "modifiers": [], "final_total": 0}
	for _repeat in repetitions:
		var roll := Dice.parse_dice_details(formula, {}, caster)
		details["dice_terms"].append_array(roll["dice_terms"])
		details["final_total"] = int(details["final_total"]) + int(roll["final_total"])
	if decisions.has("spell_damage_context"):
		context["details"] = details
	return details


static func _roll_sorcerous_burst_damage(caster: Character, formula: String, explode_on: int, ability: String) -> Dictionary:
	var details := Dice.parse_dice_details(formula, {}, caster)
	details["_sorcerous_burst_explode_on"] = explode_on
	details["_sorcerous_burst_extra_limit"] = maxi(0, caster.ability_scores.get_ability_modifier(ability))
	details["_sorcerous_burst_extra_rolled"] = 0
	details["_sorcerous_burst_triggered"] = []
	return SpellDamageRolls._resolve_sorcerous_burst_explosions(caster, details)


static func _resolve_sorcerous_burst_explosions(caster: Character, details: Dictionary) -> Dictionary:
	if not details.has("_sorcerous_burst_explode_on"):
		return details
	var explode_on := int(details["_sorcerous_burst_explode_on"])
	var extra_limit := int(details["_sorcerous_burst_extra_limit"])
	var extra_rolled := int(details["_sorcerous_burst_extra_rolled"])
	var triggered: Array = details["_sorcerous_burst_triggered"]
	for term_index in details.get("dice_terms", []).size():
		var term: Dictionary = details["dice_terms"][term_index]
		if int(term.get("sides", 0)) != 8 or str(term.get("label", "")).begins_with("-"):
			continue
		var index := 0
		while index < term.get("results", []).size() and extra_rolled < extra_limit:
			var trigger_key := "%d:%d" % [term_index, index]
			var is_kept := bool(term["kept"][index])
			if is_kept and int(term["results"][index]) == explode_on and not trigger_key in triggered:
				triggered.append(trigger_key)
				var should_explode := true
				while should_explode and extra_rolled < extra_limit:
					var roll := Dice.roll_single_details(8, caster)
					var result := int(roll["total"])
					var added_index: int = term["results"].size()
					term["results"].append_array(roll["rolls"])
					term["kept"].append_array(roll["kept"])
					term["count"] = term["results"].size()
					term["subtotal"] = int(term["subtotal"]) + result
					details["final_total"] = int(details["final_total"]) + result
					extra_rolled += 1
					if result == explode_on:
						var added_key := "%d:%d" % [term_index, added_index]
						triggered.append(added_key)
						should_explode = true
					else:
						should_explode = false
			index += 1
	details["_sorcerous_burst_extra_rolled"] = extra_rolled
	return details


static func _can_empower(caster: Character, decisions: Dictionary) -> bool:
	return bool(decisions.get("metamagic:empowered", false)) and caster.has_feature("sorcerer_metamagic") and "empowered_spell" in caster.sorcerer_metamagic_choices


static func _apply_empowered_spell(caster: Character, details: Dictionary, decisions: Dictionary) -> Dictionary:
	var context: Dictionary = decisions.get("spell_damage_context", {})
	if context.get("empowered_resolved", false):
		return {"details": context.get("details", details), "used": bool(context.get("empowered_used", false))}
	var indices: Array = decisions.get("metamagic:empowered_dice", [])
	var maximum := maxi(1, caster.ability_scores.get_ability_modifier("CHA"))
	var used := false
	if SpellDamageRolls._can_empower(caster, decisions) and Dice.valid_reroll_selection(details, indices, maximum) and SorcererRules.spend_metamagic_cost(caster, 1, decisions):
		details = Dice.reroll_selected_dice(details, indices, maximum, caster)["details"]
		used = true
	if decisions.has("spell_damage_context"):
		context["empowered_resolved"] = true
		context["empowered_used"] = used
		context["details"] = details
	return {"details": details, "used": used}


## Delay only the damage settlement while the owner selects already-rolled dice.
## Attack/save rolls and slot charges are never repeated, and HP is not changed
## until the final roll has passed through the ordinary damage boundary.


static func _finish_spell_damage(caster: Character, target, details: Dictionary, bonus: int, scale: float, damage_type: String, decisions: Dictionary, result: Dictionary, condition_duration: int = 1, additional_damage_packets: Array[Dictionary] = []) -> Dictionary:
	var context: Dictionary = decisions.get("spell_damage_context", {})
	if SpellDamageRolls._can_empower(caster, decisions) and bool(decisions.get("defer_empowered", false)) and not context.get("empowered_resolved", false) and not Dice.selectable_dice(details).is_empty():
		result["damage_request"] = {"details": details, "bonus": bonus, "scale": scale, "damage_type": damage_type, "condition_duration": condition_duration, "additional_damage_packets": additional_damage_packets}
		return result
	var metamagic := SpellDamageRolls._apply_empowered_spell(caster, details, decisions)
	details = metamagic["details"]
	details = SpellDamageRolls._resolve_sorcerous_burst_explosions(caster, details)
	var amount := int(floor(float(int(details["final_total"]) + bonus) * scale))
	var actual := int(CombatAction.resolve_damage(target, amount, damage_type, decisions, false, false, caster)["damage"])
	var additional_components: Array[Dictionary] = []
	for packet in additional_damage_packets:
		var packet_details: Dictionary = packet.get("details", {})
		if packet_details.is_empty():
			continue
		var packet_type := str(packet.get("type", "acid"))
		var packet_amount := int(floor(float(int(packet_details.get("final_total", 0))) * scale))
		var packet_result := CombatAction.resolve_damage(target, packet_amount, packet_type, decisions, false, false, caster)
		var packet_damage := int(packet_result.get("damage", 0))
		actual += packet_damage
		additional_components.append({"label": str(packet.get("label", "Additional damage")), "value": packet_damage, "type": packet_type, "formula": str(packet.get("formula", "")), "roll": packet_details})
	if not str(result.get("condition", "")).is_empty():
		if not result.get("effect_cast", {}).is_empty():
			SpellEffects.grant(target, result["effect_cast"], str(result["condition"]))
		else:
			CombatAction.apply_condition(target, str(result["condition"]), condition_duration, str(result.get("condition_source", "")))
	result.erase("condition_source")
	result["damage"] = actual
	result["damage_roll"] = details
	result["damage_type"] = damage_type
	result["additional_damage_components"] = additional_components
	result["metamagic_used"] = bool(result.get("metamagic_used", false)) or bool(metamagic["used"])
	result["message"] = str(result["message"]).replace("{damage}", str(actual))
	if metamagic["used"]:
		result["message"] += " Empowered Spell rerolls the selected damage dice; the new rolls stand."
	return result


static func finish_pending_spell_damage(caster: Character, target, result: Dictionary, decisions: Dictionary) -> Dictionary:
	if not result.has("damage_request"):
		return result
	var request: Dictionary = result["damage_request"]
	result.erase("damage_request")
	# A packet can be settled only once, even if a UI callback is repeated.
	var final_decisions := decisions.duplicate()
	final_decisions["defer_empowered"] = false
	return SpellDamageRolls._finish_spell_damage(caster, target, request["details"], int(request["bonus"]), float(request["scale"]), str(request["damage_type"]), final_decisions, result, int(request["condition_duration"]), request.get("additional_damage_packets", []))


