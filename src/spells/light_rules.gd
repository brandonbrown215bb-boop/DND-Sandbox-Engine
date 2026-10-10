## Bounded combat representation for the Light cantrip.
class_name LightRules
extends RefCounted

const BRIGHT_RADIUS_FEET := 20
const DIM_RADIUS_FEET := 40
const BRIGHT_RADIUS_HEXES := 4
const DIM_RADIUS_HEXES := 8
const DURATION_ROUNDS := 600 # One hour at six seconds per combat round.

static func create_marker(position: Vector2i, caster_id: String, caster_name: String) -> Dictionary:
	return {
		"position": [position.x, position.y],
		"caster_id": caster_id,
		"caster_name": caster_name,
		"rounds_remaining": DURATION_ROUNDS,
	}

static func tick(marker: Dictionary) -> Dictionary:
	var updated := marker.duplicate(true)
	updated["rounds_remaining"] = maxi(0, int(updated.get("rounds_remaining", 0)) - 1)
	return {"active": int(updated["rounds_remaining"]) > 0, "marker": updated}
