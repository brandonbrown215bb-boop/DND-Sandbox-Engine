## Small combat-grid representations for Prestidigitation effects with a visible
## target surface. Inventory and exploration object interactions stay elsewhere.
class_name PrestidigitationRules
extends RefCounted

const RANGE_HEXES := 2 # 10 feet.
const MAX_ACTIVE_EFFECTS := 3
const HOUR_ROUNDS := 600


static func is_instantaneous(effect_type: String) -> bool:
	return effect_type == "sensory_effect"


static func duration_rounds(effect_type: String) -> int:
	match effect_type:
		"magic_mark":
			return HOUR_ROUNDS
		"minor_creation":
			return 2 # Until the end of the caster's next turn.
		_:
			return 0


static func create_effect(position: Vector2i, caster_id: String, caster_name: String, effect_type: String, description: String, cast_round: int) -> Dictionary:
	if effect_type not in ["sensory_effect", "magic_mark", "minor_creation"] or description.strip_edges().is_empty():
		return {}
	return {
		"position": [position.x, position.y],
		"caster_id": caster_id,
		"caster_name": caster_name,
		"effect_type": effect_type,
		"description": description.strip_edges(),
		"cast_round": cast_round,
		"rounds_remaining": duration_rounds(effect_type),
	}


static func tick(effects: Array[Dictionary]) -> Array[Dictionary]:
	var active: Array[Dictionary] = []
	for effect in effects:
		if is_instantaneous(str(effect.get("effect_type", ""))):
			continue
		var updated := effect.duplicate(true)
		updated["rounds_remaining"] = maxi(0, int(updated.get("rounds_remaining", 0)) - 1)
		if int(updated["rounds_remaining"]) > 0:
			active.append(updated)
	return active

