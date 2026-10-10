## Combat-grid representation of a held Produce Flame.
class_name ProduceFlameRules
extends RefCounted

const DURATION_ROUNDS := 100 # 10 minutes at 6 seconds per combat round.
const RANGE_HEXES := 12 # 60 feet.
const BRIGHT_LIGHT_RADIUS_HEXES := 4
const DIM_LIGHT_RADIUS_HEXES := 8

static func action_cost_for_mode(mode: String) -> String:
	return "magic_action" if mode == "hurl" else "bonus_action"

static func create_flame(caster_id: String, caster_name: String, position: Vector2i, round_number: int) -> Dictionary:
	return {
		"caster_id": caster_id,
		"caster_name": caster_name,
		"position": [position.x, position.y],
		"round_created": round_number,
		"rounds_remaining": DURATION_ROUNDS,
	}

static func tick(flame: Dictionary) -> Dictionary:
	var result := flame.duplicate(true)
	result["rounds_remaining"] = int(result.get("rounds_remaining", 0)) - 1
	return result if int(result["rounds_remaining"]) > 0 else {}
