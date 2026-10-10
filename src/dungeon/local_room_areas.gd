## Saved room-owned area markers with campaign-clock expiry and entry caps.
class_name LocalRoomAreas
extends RefCounted

static func add(state: Dictionary, spell_id: String, caster_id: String, center: Vector2i, radius_hexes: int, duration_seconds: int, trigger_limit: int = 1, details: Dictionary = {}) -> Dictionary:
	if spell_id.is_empty() or caster_id.is_empty() or radius_hexes < 0 or radius_hexes > 20 or duration_seconds <= 0 or trigger_limit <= 0:
		return {"success": false, "message": "Area details are invalid."}
	var inside := false
	for cell in state.get("cells", []):
		if LocalRoomRules.coord(cell) == center: inside = true; break
	if not inside:
		return {"success": false, "message": "Area center is outside this room."}
	var serial := int(state.get("area_serial", 0)) + 1
	state["area_serial"] = serial
	var area := {
		"id": "%s:%d" % [spell_id, serial],
		"spell_id": spell_id,
		"caster_id": caster_id,
		"center": [center.x, center.y],
		"radius_hexes": radius_hexes,
		"expires_at_seconds": int(GameManager.campaign_elapsed_seconds) + duration_seconds,
		"trigger_limit": trigger_limit,
		"triggered_by": {},
	}
	for key in details:
		area[key] = details[key]
	var areas: Array = state.get("areas", [])
	areas.append(area)
	state["areas"] = areas
	return {"success": true, "area": area}


static func expire(state: Dictionary, now_seconds: int) -> int:
	var areas: Array = state.get("areas", [])
	var before := areas.size()
	for area in areas:
		if area is Dictionary and int(area.get("expires_at_seconds", 0)) <= now_seconds:
			_remove_area_condition_sources(area)
	areas = areas.filter(func(area): return int(area.get("expires_at_seconds", 0)) > now_seconds)
	state["areas"] = areas
	return before - areas.size()


static func contains(area: Dictionary, position: Vector2i, on_entry: bool = false) -> bool:
	if not on_entry and str(area.get("spell_id", "")) == "wall_of_fire" and area.has("dangerous_footprint"):
		for cell in area.get("dangerous_footprint", []):
			if LocalRoomRules.coord(cell) == position: return true
		return false
	if area.has("footprint"):
		for cell in area.get("footprint", []):
			if LocalRoomRules.coord(cell) == position: return true
		return false
	return HexUtils.get_distance(LocalRoomRules.coord(area.get("center", [0, 0])), position) <= int(area.get("radius_hexes", 0))


static func remove_concentration(state: Dictionary, caster_id: String, spell_id: String, source_id: String) -> int:
	if state.is_empty() or caster_id.is_empty() or spell_id.is_empty() or source_id.is_empty():
		return 0
	var areas: Array = state.get("areas", [])
	var before := areas.size()
	for area in areas:
		if area is Dictionary and str(area.get("spell_id", "")) == spell_id and str(area.get("caster_id", "")) == caster_id and str(area.get("concentration_source_id", "")) == source_id:
			_remove_area_condition_sources(area)
	areas = areas.filter(func(area):
		return not (area is Dictionary
			and str(area.get("spell_id", "")) == spell_id
			and str(area.get("caster_id", "")) == caster_id
			and str(area.get("concentration_source_id", "")) == source_id)
	)
	state["areas"] = areas
	return before - areas.size()


static func _remove_area_condition_sources(area: Dictionary) -> void:
	if str(area.get("spell_id", "")) not in ["black_tentacles", "entangle", "moonbeam"]:
		return
	var source_id := str(area.get("concentration_source_id", ""))
	if source_id.is_empty():
		return
	for character in PartyManager.characters.values():
		if character is Character:
			CombatAction.remove_condition_source(character, source_id, ["restrained"])
			CombatAction.remove_condition_source(character, "%s:shape_lock" % source_id, ["moonbeam_shape_lock"])


static func leave(state: Dictionary, character: Character, from: Vector2i, to: Vector2i) -> void:
	if character == null or from == to:
		return
	for area in state.get("areas", []):
		if not area is Dictionary or str(area.get("spell_id", "")) != "moonbeam":
			continue
		if not contains(area, from) or contains(area, to):
			continue
		var source_id := str(area.get("concentration_source_id", ""))
		if not source_id.is_empty():
			CombatAction.remove_condition_source(character, "%s:shape_lock" % source_id, ["moonbeam_shape_lock"])


static func enter(state: Dictionary, character_id: String, from: Vector2i, to: Vector2i, now_seconds: int) -> Array[Dictionary]:
	expire(state, now_seconds)
	var entered: Array[Dictionary] = []
	if character_id.is_empty() or from == to: return entered
	for area in state.get("areas", []):
		if not area is Dictionary: continue
		if character_id in area.get("ignored_character_ids", []): continue
		if contains(area, from, true) or not contains(area, to, true): continue
		if str(area.get("spell_id", "")) in ["black_tentacles", "grease", "cloud_of_daggers", "sleet_storm", "moonbeam", "wall_of_fire"]:
			var checked_turns: Dictionary = area.get("check_turn_by_character", {})
			var turn_index := int(floor(float(now_seconds) / 6.0))
			if int(checked_turns.get(character_id, -1)) == turn_index: continue
			checked_turns[character_id] = turn_index
			area["check_turn_by_character"] = checked_turns
		var triggered_by: Dictionary = area.get("triggered_by", {})
		var used := int(triggered_by.get(character_id, 0))
		if used >= int(area.get("trigger_limit", 1)): continue
		triggered_by[character_id] = used + 1
		area["triggered_by"] = triggered_by
		entered.append(area)
	return entered


static func touch_object(state: Dictionary, character_id: String, object_id: String, now_seconds: int) -> Array[Dictionary]:
	expire(state, now_seconds)
	var triggered: Array[Dictionary] = []
	if character_id.is_empty() or object_id.is_empty(): return triggered
	for area in state.get("areas", []):
		if not area is Dictionary or str(area.get("spell_id", "")) != "alarm" or str(area.get("warded_object_id", "")) != object_id:
			continue
		if character_id in area.get("ignored_character_ids", []): continue
		var triggered_by: Dictionary = area.get("triggered_by", {})
		var used := int(triggered_by.get(character_id, 0))
		if used >= int(area.get("trigger_limit", 1)): continue
		triggered_by[character_id] = used + 1
		area["triggered_by"] = triggered_by
		triggered.append(area)
	return triggered
