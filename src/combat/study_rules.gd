## Authored observation questions and exact observer knowledge on room objects.
class_name StudyRules
extends RefCounted

const SKILLS := ["Arcana", "History", "Investigation", "Nature", "Religion"]


static func saved_recollections_error(data: Dictionary) -> String:
	if not data.has("known_recollections"):
		return ""
	var records: Variant = data.get("known_recollections")
	if not records is Dictionary or records.size() > 500:
		return "Saved recollection knowledge is malformed."
	for room_id in records:
		var ids: Variant = records[room_id]
		if not room_id is String or str(room_id).strip_edges().is_empty() or not ids is Array or ids.size() > 32:
			return "Saved recollection room or question IDs are malformed."
		var seen: Dictionary = {}
		for id in ids:
			if not id is String or str(id).strip_edges().is_empty() or seen.has(id):
				return "Saved recollection IDs must be unique nonempty strings."
			seen[id] = true
	return ""


static func recollection_error(room: Dictionary) -> String:
	if not room.has("recollections"):
		return ""
	var topics: Variant = room.get("recollections")
	if not topics is Array or topics.is_empty() or topics.size() > 32:
		return "Room recollections need 1-32 authored questions."
	var seen: Dictionary = {}
	for topic in topics:
		if not topic is Dictionary or topic.size() not in [5, 6]:
			return "Room recollections need id, question, skill, dc, answer and optional verbal_help."
		for field in ["id", "question", "answer"]:
			if not topic.get(field) is String or str(topic[field]).strip_edges().is_empty() or str(topic[field]).length() > 4000:
				return "Room recollection text or identity is invalid."
		if seen.has(topic.id) or topic.get("skill") not in SKILLS or not ResourcePoolRules._integer(topic.get("dc"), 1, 1000) or (topic.has("verbal_help") and not topic.verbal_help is bool):
			return "Room recollection identity, skill, DC or verbal-help policy is invalid."
		seen[topic.id] = true
	return ""


static func recollection_topics(room: Dictionary) -> Array:
	return room.get("recollections", []) if recollection_error(room).is_empty() else []


static func recollection_known(room: Dictionary, actor: Character, id: String) -> bool:
	return actor != null and id in actor.known_recollections.get(str(room.get("id", "")), [])


static func recollection_answers(room: Dictionary, actor: Character) -> Array[String]:
	var result: Array[String] = []
	for topic in recollection_topics(room):
		if recollection_known(room, actor, str(topic.id)):
			result.append("%s — %s %s" % [str(room.get("name", "Room memory")), str(topic.question), str(topic.answer)])
	return result


static func object_error(object: Dictionary) -> String:
	if not object.has("study"):
		return "Study receipts need authored questions." if object.has("studied_by") else ""
	var topics: Variant = object.study
	if not topics is Array or topics.is_empty() or topics.size() > 32: return "Study needs 1-32 authored questions."
	var ids := {}
	for topic in topics:
		if not topic is Dictionary or topic.size() not in [5, 6]: return "Study questions need id, question, skill, dc, answer and optional verbal_help."
		for field in ["id", "question", "answer"]:
			if not topic.get(field) is String or str(topic[field]).strip_edges().is_empty() or str(topic[field]).length() > 4000: return "Study question text or identity is invalid."
		if ids.has(topic.id) or topic.get("skill") not in SKILLS or not ResourcePoolRules._integer(topic.get("dc"), 1, 1000) or (topic.has("verbal_help") and not topic.verbal_help is bool): return "Study question identity, skill, DC or verbal-help policy is invalid."
		ids[topic.id] = true
	var receipts: Variant = object.get("studied_by", {})
	if not receipts is Dictionary: return "Study receipts must map question IDs to observers."
	for id in receipts:
		if not ids.has(id) or not receipts[id] is Array or receipts[id].is_empty() or receipts[id].size() > 200: return "Study receipt references an invalid question or observers."
		var seen: Dictionary = {}
		for observer in receipts[id]:
			if not observer is String or observer.is_empty() or seen.has(observer): return "Study observer identity is invalid or duplicated."
			seen[observer] = true
	return ""


static func known(object: Dictionary, actor: Character, id: String) -> bool:
	return actor != null and object_error(object).is_empty() and actor.character_id in object.get("studied_by", {}).get(id, [])


static func answers(room: Dictionary, actor: Character) -> Array[String]:
	var result: Array[String] = []
	for object in room.get("objects", []):
		if not object_error(object).is_empty(): continue
		for topic in object.get("study", []):
			if known(object, actor, str(topic.id)): result.append("%s — %s %s" % [str(object.name), str(topic.question), str(topic.answer)])
	result.append_array(recollection_answers(room, actor))
	return result


static func observation_error(room: Dictionary, actor: Character, object: Dictionary, origin: Vector2i, altitude: int, grid: HexGrid) -> String:
	if actor == null or not actor.is_alive or CombatAction.is_incapacitated(actor): return "That character cannot Study now."
	if object.is_empty() or not is_same(LocalRoomRules.get_object(room, str(object.get("id", "")), actor), object) or bool(object.get("removed", false)) or int(object.get("hp", 1)) <= 0: return "That exact source is not available to study."
	var reason := object_error(object)
	if not reason.is_empty(): return reason
	if not ContainmentRules.relation(room, "character", actor.character_id).is_empty() or not ContainmentRules.relation(room, "object", str(object.id)).is_empty(): return "Release the contained source or character first."
	if PhysicalFactsRules.get_plane(actor, room) != PhysicalFactsRules.get_plane(object, room): return "The source is on another plane."
	var position := LocalRoomRules.coord(object.position)
	var height := int(object.get("altitude_feet", LocalRoomRules.elevation_feet(room, position)))
	if HexUtils.get_distance(origin, position) > 1 or abs(altitude - height) > 5: return "Move within 5 feet of the source first."
	if grid == null or not grid.has_tile(origin) or not grid.has_tile(position) or not Targeting.has_line_of_sight(origin, position, grid) or not CombatPerception.can_see_target(actor, object, origin, position, grid): return "You cannot see the source to study it."
	return ""


static func resolve(room: Dictionary, actor: Character, object: Dictionary, id: String, origin: Vector2i, altitude: int, grid: HexGrid, context: Dictionary) -> Dictionary:
	var reason := observation_error(room, actor, object, origin, altitude, grid)
	if not reason.is_empty(): return LocalRoomRules.failure(reason)
	var topic: Dictionary = {}
	for candidate in object.get("study", []):
		if candidate.id == id: topic = candidate; break
	if topic.is_empty():
		var unknown := LocalRoomRules.failure("Unknown: no authored answer is available for that question.")
		unknown["unknown"] = true
		return unknown
	if known(object, actor, id): return {"success":true, "seconds":0, "message":str(topic.answer), "remembered":true}
	var actual_context := context.duplicate()
	actual_context["sight_target_position"] = LocalRoomRules.coord(object.position)
	actual_context["verbal_help_allowed"] = bool(topic.get("verbal_help", false))
	var check := EventResolver.resolve_skill_check(actor, {"ability":"INT", "skill":str(topic.skill), "dc":int(topic.dc), "sense":"sight"}, {}, actual_context)
	if check.success:
		if not object.has("studied_by"): object["studied_by"] = {}
		if not object.studied_by.has(id): object.studied_by[id] = []
		object.studied_by[id].append(actor.character_id)
	return {"success":bool(check.success), "seconds":6, "check":check, "message":"Study: %s %d vs DC %d — %s" % [str(topic.skill), int(check.total), int(topic.dc), str(topic.answer) if check.success else "the answer remains unknown."]}


static func room_study(room: Dictionary, actor: Character, id: String, topic: String, grid: HexGrid, party: Array) -> Dictionary:
	if actor == null or actor not in party or not room.get("party_positions", {}).has(actor.character_id): return LocalRoomRules.failure("Choose a character present in this room.")
	return resolve(room, actor, LocalRoomRules.get_object(room, id, actor), topic, LocalRoomRules.coord(room.party_positions[actor.character_id]), LocalRoomRules.altitude_feet(room, actor.character_id), grid, LocalRoomSearchRules.check_context(room, actor, grid, party))


static func room_recollection(room: Dictionary, actor: Character, id: String, grid: HexGrid, party: Array) -> Dictionary:
	if actor == null or actor not in party or not room.get("party_positions", {}).has(actor.character_id) or not actor.is_alive or CombatAction.is_incapacitated(actor):
		return LocalRoomRules.failure("Choose an able character present in this room.")
	var error: String = recollection_error(room)
	if not error.is_empty(): return LocalRoomRules.failure(error)
	var topic: Dictionary = {}
	for candidate in room.recollections:
		if str(candidate.id) == id: topic = candidate; break
	if topic.is_empty():
		var unknown := LocalRoomRules.failure("Unknown: no authored recollection answers that question.")
		unknown["unknown"] = true
		unknown["seconds"] = 0
		return unknown
	if recollection_known(room, actor, id):
		return {"success":true, "remembered":true, "seconds":0, "message":str(topic.answer)}
	var context: Dictionary = LocalRoomSearchRules.check_context(room, actor, grid, party)
	context["verbal_help_allowed"] = bool(topic.get("verbal_help", false))
	var check: Dictionary = EventResolver.resolve_skill_check(actor, {"ability":"INT", "skill":str(topic.skill), "dc":int(topic.dc)}, {}, context)
	if check.success:
		var room_id := str(room.get("id", ""))
		if not actor.known_recollections.has(room_id): actor.known_recollections[room_id] = []
		if id not in actor.known_recollections[room_id]: actor.known_recollections[room_id].append(id)
	return {"success":bool(check.success), "seconds":6, "check":check, "message":"Study: %s %d vs DC %d — %s" % [str(topic.skill), int(check.total), int(topic.dc), str(topic.answer) if check.success else "the answer remains unknown."]}



static func combat_error(state, actor: Character, room: Dictionary, object: Dictionary, position: Vector2i) -> String:
	if room.is_empty() or not is_same(LocalRoomCombat.room(), room) or object.is_empty() or LocalRoomRules.coord(object.position) != position: return "The Study source changed."
	var entity: Dictionary = state.ready_actions.owner_entity(state, actor)
	if entity.is_empty(): return "The studying character left this encounter."
	return observation_error(room, actor, object, entity.hex_position, int(entity.get("altitude_feet", LocalRoomRules.elevation_feet(room, entity.hex_position))), state.hex_grid)


static func combat_targets(state, actor: Character) -> Dictionary:
	var room := LocalRoomCombat.room()
	var result := {}
	for object in room.get("objects", []):
		if not object_error(object).is_empty(): continue
		var position := LocalRoomRules.coord(object.position)
		if not object.get("study", []).is_empty() and combat_error(state, actor, room, object, position).is_empty():
			if not result.has(position): result[position] = []
			result[position].append(object)
	return result


static func combat_request(state, actor: Character, objects: Array, position: Vector2i, current: Callable, pay: Callable) -> Dictionary:
	var room := LocalRoomCombat.room()
	if not current.call(): return {"status":"stale"}
	objects = objects.filter(func(candidate): return combat_error(state, actor, room, candidate, position).is_empty())
	if objects.is_empty(): return {"status":"refused"}
	var object: Dictionary = objects[0]
	if objects.size() > 1:
		var ids: Array[String] = []
		var labels := {}
		for candidate in objects: ids.append(str(candidate.id)); labels[str(candidate.id)] = str(candidate.name)
		var selected: String = await state.hud._request_popup_choice("Study: choose the exact source", ids, labels)
		if selected.is_empty(): return {"status":"ignored"}
		object = objects[ids.find(selected)] if selected in ids else {}
	if object.is_empty(): return {"status":"stale"}
	if not current.call() or not combat_error(state, actor, room, object, position).is_empty(): return {"status":"stale"}
	var captured: Array = object.get("study", []).duplicate(true)
	var ids: Array[String] = []
	var labels := {}
	for topic in captured: ids.append(str(topic.id)); labels[str(topic.id)] = "%s (%s)" % [str(topic.question), str(topic.skill)]
	var selected: String = await state.hud._request_popup_choice("Study: choose a question", ids, labels)
	if selected.is_empty(): return {"status":"ignored"}
	if selected not in ids or not current.call() or not combat_error(state, actor, room, object, position).is_empty() or object.get("study") != captured: return {"status":"stale"}
	var entity: Dictionary = state.ready_actions.owner_entity(state, actor)
	var result := resolve(room, actor, object, selected, entity.hex_position, int(entity.get("altitude_feet", LocalRoomRules.elevation_feet(room, entity.hex_position))), state.hex_grid, state._ability_check_context(actor))
	if int(result.get("seconds", 0)) > 0:
		var paid := bool(pay.call())
		assert(paid, "Study payment was validated before synchronous resolution")
		result["status"] = "resolved"
	else: result["status"] = "remembered" if result.get("remembered", false) else "refused"
	return result
