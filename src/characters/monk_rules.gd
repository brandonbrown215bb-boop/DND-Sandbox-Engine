## SRD 5.2.1 Monk rules and progression helper.
## Handles Martial Arts scaling, Unarmored Movement bonus, Focus,
## and Monk feature resolutions across levels 1-20.
class_name MonkRules
extends RefCounted


## Return the Martial Arts damage die according to Monk level.
## Levels 1-4: 1d6, Levels 5-10: 1d8, Levels 11-16: 1d10, Levels 17-20: 1d12.
static func get_martial_arts_die(level: int) -> String:
	if level >= 17:
		return "1d12"
	elif level >= 11:
		return "1d10"
	elif level >= 5:
		return "1d8"
	return "1d6"


## Return the Unarmored Movement speed bonus in grid tiles (5 ft per tile).
## Level 2-5: +10 ft (2 tiles), Level 6-9: +15 ft (3 tiles),
## Level 10-13: +20 ft (4 tiles), Level 14-17: +25 ft (5 tiles),
## Level 18-20: +30 ft (6 tiles).
static func get_unarmored_movement_bonus(level: int) -> int:
	if level >= 18:
		return 6
	elif level >= 14:
		return 5
	elif level >= 10:
		return 4
	elif level >= 6:
		return 3
	elif level >= 2:
		return 2
	return 0


## Return maximum Focus points based on Monk level (equal to level at level 2+).
static func get_max_focus(level: int) -> int:
	return level if level >= 2 else 0


## Return maximum uses of Wholeness of Body (Wisdom modifier, minimum 1).
static func get_wholeness_of_body_max_uses(c: Character) -> int:
	if c == null:
		return 0
	return maxi(1, c.ability_scores.get_ability_modifier("WIS"))


## Activate Wholeness of Body healing as a Bonus Action.
## Restores HP equal to 1 roll of Martial Arts die + Wisdom modifier.
static func use_wholeness_of_body(monk: Character) -> Dictionary:
	if monk == null or not monk.has_feature("monk_wholeness_of_body"):
		return {"success": false, "message": "Wholeness of Body is unavailable."}
	var result := ClassFeature.execute(monk, monk.get_feature("monk_wholeness_of_body"))
	result["healing"] = int(result.get("results", [{}])[0].get("amount", 0))
	result["remaining_uses"] = int(monk.feature_uses.get("monk_wholeness_of_body", 0))
	return result


## Activate Superior Defense (Level 18):
## Expends 3 Focus Points to gain resistance to all damage except Force for 10 turns (1 minute).
static func activate_superior_defense(monk: Character, spend_focus: bool = false) -> Dictionary:
	if monk == null or not monk.has_feature("monk_superior_defense"):
		return {"success": false, "message": "Superior Defense is unavailable."}
	if spend_focus:
		if monk.get_focus_points() < 3:
			return {"success": false, "message": "Superior Defense requires 3 Focus Points."}
		monk.spend_focus_points(3)
	monk.add_condition("superior_defense", 10)
	return {"success": true, "message": "%s activates Superior Defense (damage resistance for 1 minute)." % monk.character_name}


## Apply Self-Restoration (Level 10):
## Removes one condition (Charmed, Frightened, or Poisoned) from the Monk.
static func apply_self_restoration(monk: Character, specific_condition: String = "") -> bool:
	if monk == null or not monk.has_feature("monk_self_restoration"):
		return false
	if specific_condition != "":
		if specific_condition in ["charmed", "frightened", "poisoned"] and monk.has_condition(specific_condition):
			monk.remove_condition(specific_condition)
			return true
		return false
	for cond in ["charmed", "frightened", "poisoned"]:
		if monk.has_condition(cond):
			monk.remove_condition(cond)
			return true
	return false


## Apply Perfect Focus (Level 15):
## When rolling initiative, if remaining Focus is 3 or fewer, restore to 4.
static func apply_perfect_focus(monk: Character) -> bool:
	if monk == null or not monk.has_feature("monk_perfect_focus"):
		return false
	if monk.get_focus_points() <= 3:
		monk.feature_uses["focus_points"] = 4
		return true
	return false


## Resolve Open Hand Technique (Level 3):
## Applies Addle, Push (STR save vs DC), or Topple (DEX save vs DC).
static func resolve_open_hand_technique(_monk: Character, _target: Dictionary, _option: String) -> Dictionary:
	return {"success":false, "message":"Hit options require a settled Flurry hit through combat."}


## Resolve Quivering Palm (Level 17):
## Costs 4 Focus Points. Target makes Constitution save: 10d12 Force damage on fail, half on success.
static func resolve_quivering_palm(attacker: Character, target: Dictionary) -> Dictionary:
	if attacker == null or not attacker.has_feature("monk_quivering_palm") or int(target.get("current_hp", 0)) <= 0 or attacker.get_focus_points() < 4:
		return {"success": false, "message": "Quivering Palm is unavailable or requires 4 Focus."}
	attacker.spend_focus_points(4)
	var dc := 8 + attacker.proficiency_bonus + attacker.ability_scores.get_ability_modifier("WIS")
	var save_receipt := BarbarianRules.roll_monster_save_result(target, "CON", attacker)
	var roll := int(save_receipt.get("total", 0))
	var failed := roll < dc
	var base_dmg := Dice.parse_dice_string("10d12")
	var actual_dmg := base_dmg if failed else int(floor(float(base_dmg) / 2.0))
	var dealt := int(CombatAction.resolve_damage(target, actual_dmg, "force")["damage"])
	var outcome := "failed" if failed else "succeeded"
	return {
		"success": true,
		"damage": dealt,
		"damage_type": "force",
		"failed": failed,
		"save": save_receipt,
		"message": "Quivering Palm: %s %s CON save (%d vs DC %d), taking %d force damage." % [target.get("name", "Target"), outcome, roll, dc, dealt]
	}
