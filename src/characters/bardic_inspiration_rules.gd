## Shared Bardic Inspiration behavior for any failed D20 Test.
class_name BardicInspirationRules
extends RefCounted


static func consume(target: Character) -> Dictionary:
	if not has_die(target):
		return {"success": false, "bonus": 0, "message": "No Bardic Inspiration die is held."}
	var die := str(target.feature_uses.get("bardic_inspiration_die", "1d6"))
	var die_size := int(die.trim_prefix("1d"))
	var roll_details: Dictionary = Dice.roll_single_details(die_size, target)
	var bonus := int(roll_details.get("total", 0))
	target.feature_uses.erase("bardic_inspiration_die")
	target.feature_uses.erase("bardic_inspiration_source")
	target.feature_uses.erase("bardic_inspiration_seconds_remaining")
	return {"success": true, "bonus": bonus, "die": die, "roll_details": roll_details, "message": "%s adds Bardic Inspiration (%d)." % [target.character_name, bonus]}


static func apply_to_test(target: Character, total: int, dc: int, accepted: bool, natural_roll: int = 0, attack_roll: bool = false) -> Dictionary:
	if target == null or not accepted or total >= dc or not has_die(target):
		return {"used": false, "total": total, "success": total >= dc}
	# A natural 1 always misses an attack, so the die cannot turn that attack into a hit.
	if attack_roll and natural_roll == 1:
		return {"used": false, "total": total, "success": false}
	var inspiration := consume(target)
	if not inspiration.get("success", false):
		return {"used": false, "total": total, "success": total >= dc}
	var adjusted_total := total + int(inspiration.get("bonus", 0))
	return {
		"used": true,
		"total": adjusted_total,
		"bonus": int(inspiration.get("bonus", 0)),
		"die": str(inspiration.get("die", "1d6")),
		"roll_details": inspiration.get("roll_details", {}).duplicate(true),
		"success": adjusted_total >= dc,
		"message": str(inspiration.get("message", "Bardic Inspiration")),
	}


static func has_die(target: Character) -> bool:
	if target == null:
		return false
	advance_time(target, 0)
	return target.feature_uses.has("bardic_inspiration_die")


static func advance_time(target: Character, elapsed_seconds: int) -> void:
	if target == null or not target.feature_uses.has("bardic_inspiration_die"):
		return
	# Older saves did not retain elapsed time; adopt one bounded hour once.
	var remaining := int(target.feature_uses.get("bardic_inspiration_seconds_remaining", 3600))
	remaining = maxi(0, mini(3600, remaining) - maxi(0, elapsed_seconds))
	if remaining == 0:
		for key in ["bardic_inspiration_die", "bardic_inspiration_source", "bardic_inspiration_seconds_remaining"]:
			target.feature_uses.erase(key)
	else:
		target.feature_uses["bardic_inspiration_seconds_remaining"] = remaining


static func can_receive(caster: Character, target: Character, distance_feet: int = 0) -> bool:
	if caster == null or target == null or caster == target or not caster.is_alive or not target.is_alive or distance_feet > 60:
		return false
	if CombatAction.is_incapacitated(caster) or CombatAction.is_unconscious(target):
		return false
	var can_hear := not target.has_condition("deafened") and not target.has_condition("silenced") and not caster.has_condition("silenced")
	var can_see := not target.has_condition("blinded") and CombatAction.spell_target_is_visible_to(target, caster, {"requires_target_sight": true}, distance_feet)
	return can_hear or can_see


static func apply_to_attack_result(target: Character, attack: Dictionary, dc: int, accepted: bool) -> Dictionary:
	var result := apply_to_test(target, int(attack.get("total", 0)), dc, accepted, int(attack.get("natural", 0)), true)
	if result.get("used", false):
		attack["total"] = int(result["total"])
		attack["is_miss"] = not bool(result["success"])
		var terms: Array = attack.get("bonus_dice_terms", [])
		terms.append({"count": 1, "sides": int(str(result["die"]).trim_prefix("1d")), "results": [result["bonus"]], "kept": [true], "label": "Bardic Inspiration", "subtotal": result["bonus"]})
		attack["bonus_dice_terms"] = terms
	return result


static func saved_state_error(dto: Dictionary) -> String:
	var uses: Variant = dto.get("feature_uses", {})
	if not uses is Dictionary:
		return "Feature uses are not an object"
	if uses.has("bardic_inspiration_die") and uses["bardic_inspiration_die"] not in ["1d6", "1d8", "1d10", "1d12"]:
		return "Held Bardic Inspiration die is invalid"
	if uses.has("bardic_inspiration_seconds_remaining"):
		var seconds: Variant = uses["bardic_inspiration_seconds_remaining"]
		if not (seconds is int or seconds is float):
			return "Bardic Inspiration clock is not numeric"
		if float(seconds) != floor(float(seconds)) or float(seconds) < 0 or float(seconds) > 3600:
			return "Bardic Inspiration clock is outside its one-hour bounds"
	return ""
