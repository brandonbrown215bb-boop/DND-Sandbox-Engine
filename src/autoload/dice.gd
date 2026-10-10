## Dice Roller Utility
## Autoloaded singleton providing D&D-style dice rolling.
## Supports standard dice, advantage/disadvantage, and dice string parsing.
extends Node

signal dice_rolled(result: Dictionary)


func _ready() -> void:
	randomize()


## Roll a single die with the given number of sides.
func roll(sides: int, roller: Character = null) -> int:
	return int(roll_single_details(sides, roller)["total"])


func roll_single_details(sides: int, roller: Character = null, emit_roll: bool = true) -> Dictionary:
	var original := randi_range(1, sides)
	var had_inspiration := roller != null and roller.heroic_inspiration
	var result := FighterRules.inspire_die(roller, sides, original)
	var rerolled := had_inspiration and not roller.heroic_inspiration
	var details := {"type": "single", "sides": sides, "rolls": [original, result] if rerolled else [result], "kept": [false, true] if rerolled else [true], "total": result}
	if emit_roll:
		dice_rolled.emit(details)
	return details


## Roll multiple dice and return the array of individual results.
func roll_multiple(count: int, sides: int, roller: Character = null) -> Array[int]:
	var results: Array[int] = []
	for i in count:
		results.append(int(roll_single_details(sides, roller, false)["total"]))
	var total := 0
	for r in results:
		total += r
	dice_rolled.emit({"type": "multiple", "count": count, "sides": sides, "rolls": results, "total": total})
	return results


## Roll with advantage: roll twice, return the higher result.
func roll_with_advantage(sides: int, roller: Character = null) -> int:
	return int(roll_with_advantage_details(sides, roller).get("total", 0))


## Roll with advantage and retain both dice plus the kept flags for activity records.
func roll_with_advantage_details(sides: int, roller: Character = null) -> Dictionary:
	var first := roll_single_details(sides, roller, false)
	var second := roll_single_details(sides, roller, false)
	var a := int(first["total"])
	var b := int(second["total"])
	var result := maxi(a, b)
	return _combined_roll(first, second, a >= b, "advantage", sides, result)


## Roll with disadvantage: roll twice, return the lower result.
func roll_with_disadvantage(sides: int, roller: Character = null) -> int:
	return int(roll_with_disadvantage_details(sides, roller).get("total", 0))


## Roll with disadvantage and retain both dice plus the kept flags for activity records.
func roll_with_disadvantage_details(sides: int, roller: Character = null) -> Dictionary:
	var first := roll_single_details(sides, roller, false)
	var second := roll_single_details(sides, roller, false)
	var a := int(first["total"])
	var b := int(second["total"])
	var result := mini(a, b)
	return _combined_roll(first, second, a <= b, "disadvantage", sides, result)


func _combined_roll(first: Dictionary, second: Dictionary, keep_first: bool, kind: String, sides: int, result: int) -> Dictionary:
	var rolls: Array = first["rolls"] + second["rolls"]
	var kept: Array = []
	for i in rolls.size():
		kept.append(i == (first["rolls"].size() - 1 if keep_first else rolls.size() - 1))
	var details := {"type": kind, "sides": sides, "rolls": rolls, "kept": kept, "total": result}
	dice_rolled.emit(details)
	return details


## Parse and evaluate a dice string expression like "2d6 + 3" or "1d20 + STR".
## The optional `modifiers` dictionary maps names to integer values (e.g., {"STR": 3, "level": 5}).
func parse_dice_string(dice_string: String, modifiers: Dictionary = {}, roller: Character = null) -> int:
	return int(parse_dice_details(dice_string, modifiers, roller).get("final_total", 0))


## Return the highest possible total for the supported signed dice expression.
## Used by effects such as Beacon of Hope without rolling or spending Inspiration.
func maximum_dice_string(dice_string: String, modifiers: Dictionary = {}) -> int:
	var expression := dice_string.strip_edges().to_upper().replace(" ", "")
	for key in modifiers:
		var key_name := str(key).to_upper()
		if key_name in expression:
			expression = expression.replace(key_name, str(modifiers[key]))
	while "+-" in expression or "--" in expression or "-+" in expression or "++" in expression:
		expression = expression.replace("+-", "-").replace("--", "+").replace("-+", "-").replace("++", "+")
	var total := 0
	for token_value in _tokenize_expression(expression):
		var token := str(token_value).strip_edges()
		if token.is_empty():
			continue
		var sign := 1
		if token.begins_with("-"):
			sign = -1
			token = token.substr(1)
		elif token.begins_with("+"):
			token = token.substr(1)
		if "D" in token:
			var parts := token.split("D")
			if parts.size() != 2 or not parts[1].is_valid_int() or (not parts[0].is_empty() and not parts[0].is_valid_int()):
				continue
			var count := 1 if parts[0].is_empty() else int(parts[0])
			var sides := int(parts[1])
			if count > 0 and sides > 0:
				total += sign * count * sides
		elif token.is_valid_int():
			total += sign * int(token)
	return total


## Evaluate a dice expression while retaining the exact dice and modifiers used.
func parse_dice_details(dice_string: String, modifiers: Dictionary = {}, roller: Character = null) -> Dictionary:
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
				var rolls: Array[int] = []
				var kept: Array[bool] = []
				var roll_total := 0
				for die in count:
					var detail := roll_single_details(sides, roller, false)
					rolls.append_array(detail["rolls"])
					kept.append_array(detail["kept"])
					roll_total += int(detail["total"])
				total += sign * roll_total
				dice_rolled.emit({"type": "multiple", "count": rolls.size(), "sides": sides, "rolls": rolls, "kept": kept, "total": roll_total})
				dice_terms.append({
					"count": rolls.size(),
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


## Flatten only kept, positive dice. Constants and discarded Inspiration rolls
## are never selectable for a damage-die reroll.
func selectable_dice(details: Dictionary) -> Array[Dictionary]:
	var dice: Array[Dictionary] = []
	for term_index in details.get("dice_terms", []).size():
		var term: Dictionary = details["dice_terms"][term_index]
		if str(term.get("label", "")).begins_with("-"):
			continue
		for roll_index in term.get("results", []).size():
			if bool(term.get("kept", [])[roll_index]):
				dice.append({"term": term_index, "roll": roll_index, "sides": int(term["sides"]), "value": int(term["results"][roll_index])})
	return dice


func valid_reroll_selection(details: Dictionary, indices: Array, maximum: int) -> bool:
	if indices.is_empty() or indices.size() > maximum:
		return false
	var dice := selectable_dice(details)
	var seen: Array = []
	for index in indices:
		if not index is int or index < 0 or index >= dice.size() or index in seen:
			return false
		seen.append(index)
	return true


## Retain old and new rolls for the activity record; the new result must stand.
func reroll_selected_dice(details: Dictionary, indices: Array, maximum: int, roller: Character = null) -> Dictionary:
	if not valid_reroll_selection(details, indices, maximum):
		return {"success": false, "details": details}
	var updated := details.duplicate(true)
	var dice := selectable_dice(details)
	for index in indices:
		var die: Dictionary = dice[index]
		var term: Dictionary = updated["dice_terms"][die["term"]]
		var reroll := roll_single_details(int(die["sides"]), roller)
		var delta := int(reroll["total"]) - int(die["value"])
		term["kept"][die["roll"]] = false
		term["results"].append_array(reroll["rolls"])
		term["kept"].append_array(reroll["kept"])
		term["count"] = term["results"].size()
		term["subtotal"] = int(term["subtotal"]) + delta
		updated["final_total"] = int(updated["final_total"]) + delta
	return {"success": true, "details": updated}


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
