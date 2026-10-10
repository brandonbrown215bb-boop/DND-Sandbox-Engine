## Bounded combat representation for the Mage Hand cantrip.
class_name MageHandRules
extends RefCounted

const RANGE_HEXES := 6 # 30 feet
const MAX_MOVE_HEXES := 6 # 30 feet per Magic action
const DURATION_ROUNDS := 10 # One minute at six seconds per combat round.

static func create_hand(position: Vector2i, caster_id: String, caster_name: String, cast_round: int) -> Dictionary:
	return {
		"position": [position.x, position.y],
		"caster_id": caster_id,
		"caster_name": caster_name,
		"cast_round": cast_round,
		"rounds_remaining": DURATION_ROUNDS,
	}

static func can_move(hand: Dictionary, origin: Vector2i, destination: Vector2i) -> bool:
	var position: Array = hand.get("position", [])
	if position.size() != 2:
		return false
	var current := Vector2i(int(position[0]), int(position[1]))
	return HexUtils.get_distance(current, destination) <= MAX_MOVE_HEXES and HexUtils.get_distance(origin, destination) <= RANGE_HEXES

static func tick(hand: Dictionary) -> Dictionary:
	var updated := hand.duplicate(true)
	updated["rounds_remaining"] = maxi(0, int(updated.get("rounds_remaining", 0)) - 1)
	return {"active": int(updated["rounds_remaining"]) > 0, "hand": updated}
