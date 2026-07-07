## Ability Scores
## D&D 5e ability score container with modifier calculation and point buy support.
class_name AbilityScores
extends RefCounted

## The six ability scores.
var strength: int = 10
var dexterity: int = 10
var constitution: int = 10
var intelligence: int = 10
var wisdom: int = 10
var charisma: int = 10

## Ability score abbreviations for JSON and display.
const ABILITIES := ["STR", "DEX", "CON", "INT", "WIS", "CHA"]

## Standard array option.
const STANDARD_ARRAY := [15, 14, 13, 12, 10, 8]

## Point buy: cost per score value (scores 8–15).
const POINT_BUY_COSTS := {
	8: 0, 9: 1, 10: 2, 11: 3, 12: 4, 13: 5, 14: 7, 15: 9,
}

## Total points available for point buy.
const POINT_BUY_TOTAL := 27


## Calculate the modifier for an ability score: floor((score - 10) / 2).
static func get_modifier(score: int) -> int:
	return int(floor(float(score - 10) / 2.0))


## Get the modifier for a named ability.
func get_ability_modifier(ability: String) -> int:
	return AbilityScores.get_modifier(get_score(ability))


## Get a score by ability name (case-insensitive).
func get_score(ability: String) -> int:
	match ability.to_upper():
		"STR", "STRENGTH":
			return strength
		"DEX", "DEXTERITY":
			return dexterity
		"CON", "CONSTITUTION":
			return constitution
		"INT", "INTELLIGENCE":
			return intelligence
		"WIS", "WISDOM":
			return wisdom
		"CHA", "CHARISMA":
			return charisma
		_:
			push_warning("[AbilityScores] Unknown ability: %s" % ability)
			return 10


## Set a score by ability name.
func set_score(ability: String, value: int) -> void:
	match ability.to_upper():
		"STR", "STRENGTH":
			strength = value
		"DEX", "DEXTERITY":
			dexterity = value
		"CON", "CONSTITUTION":
			constitution = value
		"INT", "INTELLIGENCE":
			intelligence = value
		"WIS", "WISDOM":
			wisdom = value
		"CHA", "CHARISMA":
			charisma = value
		_:
			push_warning("[AbilityScores] Unknown ability: %s" % ability)


## Apply racial bonuses from a race data dictionary.
## Expected format: {"ability_bonuses": {"STR": 2, "CHA": 1}}
func apply_racial_bonuses(race_data: Dictionary) -> void:
	var bonuses: Dictionary = race_data.get("ability_bonuses", {})
	for ability in bonuses:
		var current := get_score(ability)
		set_score(ability, current + int(bonuses[ability]))


## Calculate total point buy cost of current scores.
func get_point_buy_cost() -> int:
	var total := 0
	for ability in ABILITIES:
		var score := get_score(ability)
		total += POINT_BUY_COSTS.get(score, 0)
	return total


## Check if current scores are valid for point buy.
func is_valid_point_buy() -> bool:
	var cost := get_point_buy_cost()
	if cost > POINT_BUY_TOTAL:
		return false
	# All scores must be 8–15
	for ability in ABILITIES:
		var score := get_score(ability)
		if score < 8 or score > 15:
			return false
	return true


## Set all scores from a dictionary (e.g., {"STR": 15, "DEX": 14, ...}).
func from_dict(data: Dictionary) -> void:
	for ability in data:
		set_score(ability, int(data[ability]))


## Export all scores as a dictionary.
func to_dict() -> Dictionary:
	return {
		"STR": strength,
		"DEX": dexterity,
		"CON": constitution,
		"INT": intelligence,
		"WIS": wisdom,
		"CHA": charisma,
	}


## Get all modifiers as a dictionary.
func get_all_modifiers() -> Dictionary:
	return {
		"STR": get_ability_modifier("STR"),
		"DEX": get_ability_modifier("DEX"),
		"CON": get_ability_modifier("CON"),
		"INT": get_ability_modifier("INT"),
		"WIS": get_ability_modifier("WIS"),
		"CHA": get_ability_modifier("CHA"),
	}


## Format a modifier as a string (e.g., "+2" or "-1").
static func format_modifier(mod: int) -> String:
	if mod >= 0:
		return "+%d" % mod
	return "%d" % mod


## Create a copy of these ability scores.
func duplicate_scores() -> AbilityScores:
	var copy := AbilityScores.new()
	copy.strength = strength
	copy.dexterity = dexterity
	copy.constitution = constitution
	copy.intelligence = intelligence
	copy.wisdom = wisdom
	copy.charisma = charisma
	return copy
