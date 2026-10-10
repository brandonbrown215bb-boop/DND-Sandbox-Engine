## Position and range rules for the Dancing Lights spell.
class_name DancingLightsRules
extends RefCounted

const SPELL_RANGE_HEXES := 24 # 120 feet on the combat grid.
const MOVE_RANGE_HEXES := 12 # 60 feet.
const LINK_RANGE_HEXES := 4 # 20 feet.
const DIM_LIGHT_RADIUS_HEXES := 2 # 10 feet.
const CLUSTER_OFFSETS: Array[Vector2i] = [Vector2i.ZERO, Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 1)]


static func create_light_set(caster_id: String, caster_name: String, caster_position: Vector2i, anchor: Vector2i, humanoid_form: bool = false, light_count: int = 4) -> Dictionary:
	if caster_id.is_empty() or HexUtils.get_distance(caster_position, anchor) > SPELL_RANGE_HEXES:
		return {"success": false, "message": "Choose a point within 120 feet for Dancing Lights."}
	var positions: Array[Vector2i] = []
	if humanoid_form:
		positions.append(anchor)
	else:
		for offset_index in mini(CLUSTER_OFFSETS.size(), clampi(light_count, 1, 4)):
			positions.append(anchor + CLUSTER_OFFSETS[offset_index])
		for position in positions:
			if HexUtils.get_distance(caster_position, position) > SPELL_RANGE_HEXES:
				return {"success": false, "message": "All Dancing Lights must remain within 120 feet."}
	return {
		"success": true,
		"lights": {
			"caster_id": caster_id,
			"caster_name": caster_name,
			"anchor": [anchor.x, anchor.y],
			"positions": _to_coordinate_arrays(positions),
			"humanoid_form": humanoid_form,
			"dim_light_radius_hexes": DIM_LIGHT_RADIUS_HEXES,
		},
	}


static func move_light_set(light_set: Dictionary, caster_position: Vector2i, new_anchor: Vector2i) -> Dictionary:
	var old_anchor_value: Variant = light_set.get("anchor", [])
	if not _valid_coord(old_anchor_value):
		return {"success": false, "message": "The Dancing Lights have no valid anchor."}
	var old_anchor := Vector2i(int(old_anchor_value[0]), int(old_anchor_value[1]))
	if HexUtils.get_distance(old_anchor, new_anchor) > MOVE_RANGE_HEXES:
		return {"success": false, "message": "Move the Dancing Lights no more than 60 feet."}
	if HexUtils.get_distance(caster_position, new_anchor) > SPELL_RANGE_HEXES:
		return {"success": false, "message": "Choose a destination within the spell's 120-foot range."}
	var moved_positions: Array[Array] = []
	for position_value in light_set.get("positions", []):
		if not _valid_coord(position_value):
			return {"success": false, "message": "A Dancing Light has no valid position."}
		var translated := Vector2i(int(position_value[0]), int(position_value[1])) + (new_anchor - old_anchor)
		if HexUtils.get_distance(caster_position, translated) > SPELL_RANGE_HEXES:
			continue # A light vanishes if it moves beyond the spell's range.
		moved_positions.append([translated.x, translated.y])
	return {"success": true, "light_set": {"caster_id": str(light_set.get("caster_id", "")), "caster_name": str(light_set.get("caster_name", "")), "anchor": [new_anchor.x, new_anchor.y], "positions": moved_positions, "humanoid_form": bool(light_set.get("humanoid_form", false)), "dim_light_radius_hexes": DIM_LIGHT_RADIUS_HEXES}}


static func _to_coordinate_arrays(positions: Array[Vector2i]) -> Array[Array]:
	var result: Array[Array] = []
	for position in positions:
		result.append([position.x, position.y])
	return result


static func _valid_coord(value: Variant) -> bool:
	return value is Array and value.size() == 2 and value[0] is int and value[1] is int
