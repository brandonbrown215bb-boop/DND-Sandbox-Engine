## Rules shared by Rogue feature selection and combat resolution.
class_name RogueRules
extends RefCounted

const CUNNING_KNOCKOUT_SOURCE := "rogue_cunning_knock_out"
const CUNNING_DAZE_SOURCE := "rogue_cunning_daze"
const CUNNING_OBSCURE_SOURCE := "rogue_cunning_obscure"

static func sneak_attack_eligible(character: Character, weapon: Dictionary, advantage: bool, disadvantage: bool, ally_adjacent: bool) -> bool:
	if character == null or not character.has_feature_effect("sneak_attack") or int(character.feature_uses.get("sneak_attack_used_this_turn", 0)) > 0:
		return false
	var properties: Array = weapon.get("properties", [])
	if "finesse" not in properties and "ranged" not in properties:
		return false
	# Advantage and Disadvantage cancel; an adjacent ally can still qualify.
	return (advantage and not disadvantage) or (ally_adjacent and not (disadvantage and not advantage))


static func cunning_strike_options(character: Character, target: Dictionary) -> Array[String]:
	var options: Array[String] = []
	if character == null or not character.has_feature("rogue_cunning_strike"):
		return options
	if character.inventory.has_item("poisoners_kit"):
		options.append("poison")
	var size := str(target.get("size", "Medium")).to_lower()
	if size not in ["huge", "gargantuan"]:
		options.append("trip")
	options.append("withdraw")
	if character.has_feature("rogue_devious_strikes"):
		options.append_array(["daze", "knock_out", "obscure"])
	return options


static func cunning_strike_max_effects(character: Character) -> int:
	return 2 if character != null and character.has_feature("rogue_improved_cunning_strike") else 1


static func cunning_strike_dice_cost(option_id: String) -> int:
	return {"poison": 1, "trip": 1, "withdraw": 1, "daze": 2, "obscure": 3, "knock_out": 6}.get(option_id, 0)


static func cunning_strike_save_ability(option_id: String) -> String:
	return "CON" if option_id in ["poison", "daze", "knock_out"] else "DEX"


static func remaining_sneak_attack_dice(total_dice: int, options: Array[String]) -> int:
	var spent := 0
	for option_id in options:
		spent += cunning_strike_dice_cost(option_id)
	return maxi(0, total_dice - spent)


static func saving_throw_dc(character: Character) -> int:
	if character == null:
		return 0
	return 8 + character.ability_scores.get_ability_modifier("DEX") + character.proficiency_bonus


static func resolve_knock_out_repeat_save(target: Dictionary, save_total: int, save_dc: int) -> bool:
	if target.is_empty() or not CombatAction.has_condition_source(target, CUNNING_KNOCKOUT_SOURCE):
		return false
	if save_total >= save_dc:
		CombatAction.remove_condition_source(target, CUNNING_KNOCKOUT_SOURCE, ["unconscious"])
		target.erase("rogue_cunning_knock_out_dc")
		return true
	return false


static func apply_stroke_of_luck(character: Character, test_result: Dictionary, accepted: bool) -> Dictionary:
	if character == null or not character.has_feature("rogue_stroke_of_luck") or bool(test_result.get("success", true)) or not accepted:
		return {"used": false, "result": test_result.duplicate(true)}
	if not character.use_feature("rogue_stroke_of_luck"):
		return {"used": false, "result": test_result.duplicate(true)}
	var adjusted := test_result.duplicate(true)
	adjusted["natural_roll"] = 20
	adjusted["total"] = 20 + int(adjusted.get("modifier", 0))
	adjusted["success"] = int(adjusted["total"]) >= int(adjusted.get("dc", 0))
	return {"used": true, "result": adjusted}


static func apply_stroke_of_luck_to_attack(character: Character, attack_result: Dictionary, accepted: bool) -> Dictionary:
	if character == null or not character.has_feature("rogue_stroke_of_luck") or not accepted:
		return {"used": false, "result": attack_result.duplicate(true)}
	if not character.use_feature("rogue_stroke_of_luck"):
		return {"used": false, "result": attack_result.duplicate(true)}
	var adjusted := attack_result.duplicate(true)
	var modifier := 0
	for term in adjusted.get("activity_modifiers", []):
		modifier += int(term.get("value", 0))
	adjusted["natural"] = 20
	adjusted["total"] = 20 + modifier
	adjusted["is_crit"] = true
	adjusted["is_miss"] = false
	adjusted["advantage"] = false
	adjusted["disadvantage"] = false
	adjusted["roll_results"] = [20]
	adjusted["roll_kept"] = [true]
	return {"used": true, "result": adjusted}
