## Dice Roller Utility
## Autoloaded singleton providing D&D-style dice rolling.
## Supports standard dice, advantage/disadvantage, and dice string parsing.
extends Node

signal dice_rolled(result: Dictionary)


func _ready() -> void:
	randomize()


## Roll a single die with the given number of sides.
func roll(sides: int) -> int:
	var result := randi_range(1, sides)
	dice_rolled.emit({"type": "single", "sides": sides, "rolls": [result], "total": result})
	return result


## Roll multiple dice and return the array of individual results.
func roll_multiple(count: int, sides: int) -> Array[int]:
	var results: Array[int] = []
	for i in count:
		results.append(randi_range(1, sides))
	var total := 0
	for r in results:
		total += r
	dice_rolled.emit({"type": "multiple", "count": count, "sides": sides, "rolls": results, "total": total})
	return results


## Roll with advantage: roll twice, return the higher result.
func roll_with_advantage(sides: int) -> int:
	return int(roll_with_advantage_details(sides).get("total", 0))


## Roll with advantage and retain both dice plus the kept flags for activity records.
func roll_with_advantage_details(sides: int) -> Dictionary:
	var a := randi_range(1, sides)
	var b := randi_range(1, sides)
	var result := maxi(a, b)
	dice_rolled.emit({"type": "advantage", "sides": sides, "rolls": [a, b], "total": result})
	return {"rolls": [a, b], "kept": [a >= b, b > a], "total": result}


## Roll with disadvantage: roll twice, return the lower result.
func roll_with_disadvantage(sides: int) -> int:
	return int(roll_with_disadvantage_details(sides).get("total", 0))


## Roll with disadvantage and retain both dice plus the kept flags for activity records.
func roll_with_disadvantage_details(sides: int) -> Dictionary:
	var a := randi_range(1, sides)
	var b := randi_range(1, sides)
	var result := mini(a, b)
	dice_rolled.emit({"type": "disadvantage", "sides": sides, "rolls": [a, b], "total": result})
	return {"rolls": [a, b], "kept": [a <= b, b < a], "total": result}


## Parse and evaluate a dice string expression like "2d6 + 3" or "1d20 + STR".
## The optional `modifiers` dictionary maps names to integer values (e.g., {"STR": 3, "level": 5}).
func parse_dice_string(dice_string: String, modifiers: Dictionary = {}) -> int:
	return int(parse_dice_details(dice_string, modifiers).get("final_total", 0))


## Evaluate a dice expression while retaining the exact dice and modifiers used.
func parse_dice_details(dice_string: String, modifiers: Dictionary = {}) -> Dictionary:
	var total := 0
	var expression := dice_string.strip_edges().to_upper()
	var resolved_modifiers: Array[Dictionary] = []

	# Replace named modifiers with their values
	for key in modifiers:
		var key_name := str(key).to_upper()
		if key_name in expression:
			resolved_modifiers.append({"label": key_name, "value": int(modifiers[key])})
			expression = expression.replace(key_name, str(modifiers[key]))

	expression = expression.replace(" ", "")
	while "+-" in expression or "--" in expression or "-+" in expression or "++" in expression:
		expression = expression.replace("+-", "-")
		expression = expression.replace("--", "+")
		expression = expression.replace("-+", "-")
		expression = expression.replace("++", "+")

	# Split on + and - while keeping the operator
	var tokens := _tokenize_expression(expression)

	var dice_terms: Array[Dictionary] = []
	for token in tokens:
		token = token.strip_edges()
		if token.is_empty():
			continue

		# Determine sign
		var sign := 1
		if token.begins_with("-"):
			sign = -1
			token = token.substr(1).strip_edges()
		elif token.begins_with("+"):
			token = token.substr(1).strip_edges()

		# Check if it's a dice expression (e.g., "2D6", "D20", "1D8")
		if "D" in token:
			var parts := token.split("D")
			var count := 1
			if not parts[0].is_empty():
				count = parts[0].to_int()
			var sides := parts[1].to_int()
			if sides > 0:
				var rolls := roll_multiple(count, sides)
				var roll_total := 0
				for r in rolls:
					roll_total += r
				total += sign * roll_total
				var kept: Array[bool] = []
				for roll_value in rolls:
					kept.append(true)
				dice_terms.append({
					"count": count,
					"sides": sides,
					"results": rolls.duplicate(),
					"kept": kept,
					"label": "%sd%d" % ["-" if sign < 0 else "", sides],
					"subtotal": sign * roll_total,
				})
		elif token.is_valid_int():
			total += sign * token.to_int()

	return {
		"formula": dice_string.strip_edges(),
		"dice_terms": dice_terms,
		"modifiers": resolved_modifiers,
		"final_total": total,
	}


## Tokenize a dice expression string into individual terms.
## "2d6 + 3 - 1d4" becomes ["+2d6", "+3", "-1d4"]
func _tokenize_expression(expression: String) -> Array[String]:
	var tokens: Array[String] = []
	var current := ""
	var first_term := true

	for ch in expression:
		if ch == "+" or ch == "-":
			if not current.strip_edges().is_empty():
				if first_term:
					tokens.append("+" + current.strip_edges())
					first_term = false
				else:
					tokens.append(current.strip_edges())
				current = ""
			if ch == "-":
				current = "-"
			else:
				current = "+"
			first_term = false
		elif ch == " ":
			current += ch
		else:
			if first_term and current.is_empty():
				current = "+"
				first_term = false
			current += ch

	if not current.strip_edges().is_empty():
		if first_term:
			tokens.append("+" + current.strip_edges())
		else:
			tokens.append(current.strip_edges())

	return tokens


## Roll a standard D&D ability score: 4d6, drop the lowest.
func roll_ability_score() -> int:
	var rolls := roll_multiple(4, 6)
	rolls.sort()
	return rolls[1] + rolls[2] + rolls[3]


## Roll a full set of 6 ability scores.
func roll_ability_scores() -> Array[int]:
	var scores: Array[int] = []
	for i in 6:
		scores.append(roll_ability_score())
	return scores
