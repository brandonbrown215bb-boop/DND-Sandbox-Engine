## Daily food and water hazards for characters tracked by the campaign clock.
class_name SurvivalRules
extends RefCounted


static func settle_day(character: Character, day_end_seconds: int) -> void:
	if character == null or not character.is_alive:
		return
	var food_need := food_need_for_character(character)
	var water_need := water_need_for_character(character)
	var food_eaten := character.food_eaten_today_pounds
	var water_drank := character.water_drank_today_gallons
	var legacy_food_day := food_eaten <= 0.0 and character.nourishment_until_seconds >= day_end_seconds
	var legacy_water_day := water_drank <= 0.0 and character.hydration_until_seconds >= day_end_seconds
	if food_eaten >= food_need or legacy_food_day:
		character.days_without_food = 0
		character.remove_exhaustion_recovery_blocker("malnutrition")
	elif food_eaten <= 0.0:
		character.days_without_food += 1
		if character.days_without_food >= 5:
			character.gain_exhaustion("malnutrition")
	else:
		character.days_without_food = 0
		if food_eaten < food_need * 0.5 and not bool(character.saving_throw_test_to_dc("CON", 10).get("success", false)):
			character.gain_exhaustion("malnutrition")
	if water_drank >= water_need or legacy_water_day:
		character.remove_exhaustion_recovery_blocker("dehydration")
	elif water_drank < water_need * 0.5:
		character.gain_exhaustion("dehydration")
	character.food_eaten_today_pounds = 0.0
	character.water_drank_today_gallons = 0.0


static func food_need_for_size(size: String) -> float:
	match size.to_lower():
		"tiny": return 0.25
		"small", "medium": return 1.0
		"large": return 4.0
		"huge": return 16.0
		"gargantuan": return 64.0
	return 1.0


static func water_need_for_size(size: String) -> float:
	return food_need_for_size(size)


static func food_need_for_character(character: Character) -> float:
	return food_need_for_size(str(DataLoader.get_race(character.race_id).get("size", "medium")))


static func water_need_for_character(character: Character) -> float:
	return water_need_for_size(str(DataLoader.get_race(character.race_id).get("size", "medium")))


static func saved_state_error(character_data: Dictionary) -> String:
	for field in ["food_eaten_today_pounds", "water_drank_today_gallons"]:
		if not character_data.has(field):
			continue
		var amount: Variant = character_data[field]
		if not amount is int and not amount is float:
			return "saved food or water intake is invalid"
		if not is_finite(float(amount)) or float(amount) < 0.0 or not is_equal_approx(float(amount) * 16.0, roundf(float(amount) * 16.0)):
			return "saved food or water intake is invalid"
	return ""
