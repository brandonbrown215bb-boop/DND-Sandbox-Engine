## Saved room-owned area markers with campaign-clock expiry and entry caps.
class_name LocalRoomAreas
extends RefCounted

static func add_aftermath_area(state: Dictionary, id: String, child: Dictionary, event: Dictionary) -> Dictionary:
	for area in state.get("areas", []):
		if area.get("id") == id: return {"success": true, "successor_id": id}
	if state.get("areas", []).size() >= 500: return {"success": false, "reason": "area_capacity"}
	var details := {"id": id, "hazard_kind": str(child.kind), "trigger_scope": str(child.trigger_scope), "amount": int(child.amount), "damage_type": str(child.damage_type), "plane": str(event.final_location.plane), "parent_source_id": str(event.source_id)}
	if child.has("trigger_policies"):
		details["trigger_policies"] = child.trigger_policies.duplicate(true)
		details["created_center"] = event.final_location.position.duplicate()
	var result := add(state, str(event.definition_id), str(event.caster_id), LocalRoomRules.coord(event.final_location.position), int(child.radius_hexes), int(child.duration_seconds), int(child.trigger_limit), details)
	if result.get("success", false): return {"success": true, "successor_id": id}
	return result

static func resolve_aftermath_entry(area: Dictionary, target) -> Dictionary:
	if area.get("hazard_kind", "") not in ["entry_damage", "trigger_damage"] or str(area.get("plane", "")) != PhysicalFactsRules.get_plane(target, {"plane": str(area.get("plane", ""))}): return {}
	if area.has("trigger_policies") and not SpatialTriggerRules.settle(area): return {}
	if (target is Character and not target.is_alive) or (target is Dictionary and not target.get("is_alive", true)): return {}
	var damage := CombatAction.resolve_damage(target, int(area.amount), str(area.damage_type), {"damage_source_instance_id": str(area.id), "damage_source_actor_id": str(area.caster_id)})
	return {"spell_id": str(area.get("definition_id", area.spell_id)), "hazard_kind": str(area.hazard_kind), "source_id": str(area.id), "trigger_event": area.get("trigger_event", "entry"), "damage": int(damage.get("hp_loss", 0)), "resolved": int(damage.get("resolved", 0)), "damage_type": str(area.damage_type)}

static func add(state: Dictionary, spell_id: String, caster_id: String, center: Vector2i, radius_hexes: int, duration_seconds: int, trigger_limit: int = 1, details: Dictionary = {}) -> Dictionary:
	if details.has("trigger_policies"):
		var error := SpatialTriggerRules.policies_error(details.trigger_policies)
		if not error.is_empty(): return {"success": false, "message": error}
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
	if area.has("trigger_policies"):
		SpatialTriggerRules.mark_created(area)
		area["created_room_event_serial"] = int(state.get("area_event_serial", 0))
		area["created_room_event_prefix"] = "room:%s:move:" % state.get("id", "")
	var areas: Array = state.get("areas", [])
	areas.append(area)
	state["areas"] = areas
	return {"success": true, "area": area}


static func expire(state: Dictionary, now_seconds: int) -> int:
	var areas: Array = state.get("areas", [])
	var before := areas.size()
	for area in areas:
		if area is Dictionary and int(area.get("expires_at_seconds", 0)) <= now_seconds:
			area["_trigger_ended"] = true
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
			area["_trigger_ended"] = true
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


static func enter(state: Dictionary, character_id: String, from: Vector2i, to: Vector2i, now_seconds: int, plane: String = "", event_id: String = "", clocks: Dictionary = {}, movement_kind: String = "movement", trigger_actor_id: String = "") -> Array[Dictionary]:
	expire(state, now_seconds)
	var entered: Array[Dictionary] = []
	if character_id.is_empty() or from == to: return entered
	for area in state.get("areas", []):
		if not area is Dictionary: continue
		if area.has("hazard_kind") and str(area.get("plane", "")) != (plane if not plane.is_empty() else PhysicalFactsRules.get_plane(state)): continue
		if character_id in area.get("ignored_character_ids", []): continue
		if area.has("trigger_policies"):
			var events := SpatialTriggerRules.movement_events(contains(area, from, true), contains(area, to, true))
			if movement_kind == "teleport": events = ["entry"] if not contains(area, from, true) and contains(area, to, true) else []
			entered.append_array(SpatialTriggerRules.claim(area, trigger_actor_id if not trigger_actor_id.is_empty() else character_id, events, event_id, clocks if not clocks.is_empty() else turn_clocks(state)))
			continue
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


static func turn_clocks(state: Dictionary) -> Dictionary:
	var prefix := "room:" + str(state.get("id", "")) + ":"
	return {"turn": prefix + str(state.get("area_turn_serial", 0)), "actors": state.get("area_actor_turns", {}), "initial_actor": prefix + "initial"}

static func next_movement_event(state: Dictionary) -> String:
	state["area_event_serial"] = int(state.get("area_event_serial", 0)) + 1
	return "room:%s:move:%d" % [state.get("id", ""), state.area_event_serial]

static func turn_event(state: Dictionary, actor_id: String, position: Vector2i, event: String, clocks: Dictionary = {}, plane: String = "", event_id: String = "") -> Array[Dictionary]:
	expire(state, int(GameManager.campaign_elapsed_seconds))
	var deliveries: Array[Dictionary] = []
	if clocks.is_empty(): clocks = turn_clocks(state)
	if event_id.is_empty():
		var key := JSON.stringify([clocks.turn, actor_id, event])
		var boundaries: Dictionary = state.get("area_boundary_events", {})
		if not boundaries.has(key): boundaries[key] = next_movement_event(state)
		state["area_boundary_events"] = boundaries
		event_id = str(boundaries[key])
	for area in state.get("areas", []):
		if not area.has("trigger_policies") or not contains(area, position): continue
		if str(area.get("plane", "")) != (plane if not plane.is_empty() else PhysicalFactsRules.get_plane(state)): continue
		if actor_id in area.get("ignored_character_ids", []): continue
		deliveries.append_array(SpatialTriggerRules.claim(area, actor_id, [event], event_id, clocks))
	return deliveries

static func remove(state: Dictionary, source_id: String) -> bool:
	for area in state.get("areas", []):
		if area.get("id") != source_id: continue
		area["_trigger_ended"] = true
		_remove_area_condition_sources(area)
		state.areas.erase(area)
		return true
	return false

## Explicit area movement never borrows creature-entry semantics.
static func move_area(state: Dictionary, source_id: String, destination: Vector2i, actors: Array, clocks: Dictionary = {}) -> Array[Dictionary]:
	expire(state, int(GameManager.campaign_elapsed_seconds))
	var deliveries: Array[Dictionary] = []
	if not state.get("cells", []).any(func(cell): return LocalRoomRules.coord(cell) == destination): return deliveries
	for area in state.get("areas", []):
		if area.get("id") != source_id or not area.has("trigger_policies") or area.has("footprint"): continue
		if LocalRoomRules.coord(area.center) == destination: return deliveries
		var inside := {}
		for actor in actors: inside[str(actor.id)] = contains(area, actor.position, true)
		area.center = [destination.x, destination.y]
		var event_id := next_movement_event(state)
		for actor in actors:
			if actor.get("plane", "") != area.get("plane", "") or actor.id in area.get("ignored_character_ids", []): continue
			if not inside[str(actor.id)] and contains(area, actor.position, true):
				deliveries.append_array(SpatialTriggerRules.claim(area, str(actor.id), ["area_enter"], event_id, clocks if not clocks.is_empty() else turn_clocks(state)))
	return deliveries


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
