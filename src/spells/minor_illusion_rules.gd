## Combat-grid marker for the Minor Illusion cantrip.
## Actual sound, physical interaction, and Investigation checks need world rules.
class_name MinorIllusionRules
extends RefCounted

const RANGE_HEXES := 6 # 30 feet.
const DURATION_ROUNDS := 10 # One minute at six seconds per round.
const IMAGE_MAX_CUBE_FEET := 5


static func create_illusion(position: Vector2i, caster_id: String, caster_name: String, form: String, description: String, cast_round: int) -> Dictionary:
	if form not in ["sound", "image"] or description.strip_edges().is_empty():
		return {}
	return {
		"position": [position.x, position.y],
		"caster_id": caster_id,
		"caster_name": caster_name,
		"form": form,
		"description": description.strip_edges(),
		"cast_round": cast_round,
		"rounds_remaining": DURATION_ROUNDS,
	}


static func tick(illusion: Dictionary) -> Dictionary:
	var updated := illusion.duplicate(true)
	updated["rounds_remaining"] = maxi(0, int(updated.get("rounds_remaining", 0)) - 1)
	return {"active": int(updated["rounds_remaining"]) > 0, "illusion": updated}

