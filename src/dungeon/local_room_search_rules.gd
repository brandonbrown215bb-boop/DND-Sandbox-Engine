## Search one represented room space and retain discovery on the exact object.
class_name LocalRoomSearchRules
extends RefCounted

const RANGE_FEET := 60


static func object_error(object: Dictionary) -> String:
	if object.has("tracks_search"):
		var tracks_clue: Variant = object.tracks_search
		if not tracks_clue is Dictionary: return "Survival Search needs an authored track source."
		if not ResourcePoolRules._integer(tracks_clue.get("dc"), 1, 1000) or not ResourcePoolRules._integer(tracks_clue.get("range_feet"), 1, RANGE_FEET): return "Survival Search needs a DC and a range of 1-60 feet."
		if tracks_clue.get("kind", "") != "tracks" or not tracks_clue.get("information", null) is String or str(tracks_clue.information).strip_edges().is_empty() or str(tracks_clue.information).length() > 500: return "Survival Search needs authored track information."
		for field in tracks_clue:
			if field not in ["dc", "range_feet", "kind", "information"]: return "Unsupported Survival Search clue field."
	elif object.has("tracks_discovered_by"):
		return "Track clue receipts need a track clue."
	if object.has("tracks_search"):
		var track_observers: Variant = object.get("tracks_discovered_by", [])
		if not track_observers is Array or track_observers.size() > 200: return "Track clue observers are malformed."
		var track_seen := {}
		for id in track_observers:
			if not id is String or id.is_empty() or track_seen.has(id): return "Track clue observer identity is invalid."
			track_seen[id] = true
	if object.has("medical_search"):
		var clue: Variant = object.medical_search
		if str(object.get("kind", "")) != "remains" or not clue is Dictionary: return "Medical Search needs an authored remains source."
		if not ResourcePoolRules._integer(clue.get("dc"), 1, 1000) or not ResourcePoolRules._integer(clue.get("range_feet"), 1, RANGE_FEET): return "Medical Search needs a DC and a range of 1-60 feet."
		if clue.get("kind", "") != "cause_of_death" or not clue.get("information", null) is String or str(clue.information).strip_edges().is_empty() or str(clue.information).length() > 500: return "Medical Search needs a cause-of-death clue and declared information."
		if not ResourcePoolRules._integer(clue.get("recent_until_seconds"), 0, 9007199254740991): return "Cause-of-death clues need a recent-source deadline."
		for field in clue:
			if field not in ["dc", "range_feet", "kind", "information", "recent_until_seconds"]: return "Unsupported Medical Search clue field."
	elif object.has("medical_discovered_by"):
		return "Medical clue receipts need a medical clue."
	if object.has("medical_search"):
		var medical_observers: Variant = object.get("medical_discovered_by", [])
		if not medical_observers is Array or medical_observers.size() > 200: return "Medical clue observers are malformed."
		var medical_seen := {}
		for id in medical_observers:
			if not id is String or id.is_empty() or medical_seen.has(id): return "Medical clue observer identity is invalid."
			medical_seen[id] = true
	if not object.has("discovery"):
		return "Discovery receipts need a discovery rule." if object.has("discovered_by") else ""
	var rule: Variant = object.discovery
	if not rule is Dictionary or not ResourcePoolRules._integer(rule.get("dc"), 1, 1000) or not ResourcePoolRules._integer(rule.get("range_feet"), 1, RANGE_FEET): return "Discovery needs a DC and a range of 1-60 feet."
	for field in rule:
		if field not in ["dc", "range_feet", "sense", "noise"]: return "Unsupported discovery field."
	if rule.get("sense", "sight") not in ["sight", "hearing"]: return "Discovery sense must be sight or hearing."
	if rule.get("sense", "sight") == "hearing":
		var error := CombatNoiseRules.error(rule.get("noise", {}))
		if not error.is_empty(): return error
	elif rule.has("noise"): return "Only hearing discovery declares ongoing noise."
	var observers: Variant = object.get("discovered_by", [])
	if not observers is Array or observers.size() > 200: return "Discovery observers are malformed."
	var seen := {}
	for id in observers:
		if not id is String or id.is_empty() or seen.has(id): return "Discovery observer identity is invalid."
		seen[id] = true
	return ""


static func known(object: Dictionary, observer) -> bool:
	if object.is_empty(): return false
	if not object.has("discovery"): return true
	return object_error(object).is_empty() and observer != null and CombatAction.actor_id(observer) in object.get("discovered_by", [])


static func sync_obscurement(state: Dictionary, grid: HexGrid, observer: Character) -> void:
	grid.obscurement_sources.clear()
	for area in state.get("areas", []):
		if int(area.get("expires_at_seconds", 0)) <= int(GameManager.campaign_elapsed_seconds) or PhysicalFactsRules.get_plane(area, state) != PhysicalFactsRules.get_plane(observer, state): continue
		var kind := str(area.get("obscurement_kind", ""))
		# Preserve the existing native room-area declarations. New sources can
		# declare their kind independently of the spell's identity.
		if kind.is_empty() and bool(area.get("heavily_obscured", false)): kind = "magical_darkness" if area.get("spell_id") == "darkness" else "fog"
		if kind not in ["fog", "magical_darkness"]: continue
		var coords: Array = []
		for position in grid.tiles:
			if LocalRoomAreas.contains(area, position): coords.append(position)
		grid.obscurement_sources[str(area.id)] = {"kind":kind, "coords":coords, "caster_id":str(area.get("caster_id", ""))}


static func check_context(state: Dictionary, actor: Character, grid: HexGrid, party: Array) -> Dictionary:
	var participants: Array = []
	for member in party:
		if state.get("party_positions", {}).has(member.character_id) and ContainmentRules.relation(state, "character", member.character_id).is_empty(): participants.append({"character":member, "hex_position":LocalRoomRules.coord(state.party_positions[member.character_id])})
	return {"room":state, "grid":grid, "participants":participants, "actor_position":LocalRoomRules.coord(state.party_positions[actor.character_id])}


static func search(state: Dictionary, actor: Character, position: Vector2i, grid: HexGrid, party: Array, sense: String = "sight") -> Dictionary:
	if sense not in ["sight", "hearing", "medicine", "survival"]: return LocalRoomRules.failure("Choose Look, Listen, Medicine or Survival Search.")
	if actor == null or actor not in party or not actor.is_alive or CombatAction.is_incapacitated(actor): return LocalRoomRules.failure("That character cannot Search now.")
	if not ContainmentRules.relation(state, "character", actor.character_id).is_empty(): return LocalRoomRules.failure("An internal occupant cannot search the outside room.")
	var origin_data: Variant = state.get("party_positions", {}).get(actor.character_id)
	if not origin_data is Array or grid == null or not grid.has_tile(position): return LocalRoomRules.failure("Choose a represented room space.")
	var origin := LocalRoomRules.coord(origin_data)
	if HexUtils.get_distance(origin, position) * 5 > RANGE_FEET: return LocalRoomRules.failure("Choose a space within 60 feet.")
	if sense in ["sight", "medicine", "survival"] and not CombatPerception.can_see_target(actor, null, origin, position, grid): return LocalRoomRules.failure("You cannot see that space to search it.")
	for object in state.get("objects", []):
		if LocalRoomRules.coord(object.position) == position and not object_error(object).is_empty(): return LocalRoomRules.failure(object_error(object))
	if sense == "medicine":
		return _medical_search(state, actor, position, origin, grid, party)
	if sense == "survival":
		return _tracks_search(state, actor, position, origin, grid, party)
	var context := check_context(state, actor, grid, party)
	context["sense"] = sense
	if sense == "sight":
		context["lightly_obscured"] = CombatPerception.sight_is_lightly_obscured(actor, position, grid, HexUtils.get_distance(origin, position) * 5)
		context["sight_target_position"] = position
	var check := EventResolver.resolve_skill_check(actor, {"ability":"WIS", "skill":"Perception", "sense":sense, "dc":0}, {}, context)
	var found: Array[String] = []
	for object in state.get("objects", []):
		if bool(object.get("removed", false)) or not object.has("discovery") or known(object, actor) or LocalRoomRules.coord(object.position) != position: continue
		if object.discovery.get("sense", "sight") != sense or int(object.get("hp", 1)) <= 0: continue
		if not ContainmentRules.relation(state, "object", str(object.id)).is_empty() or PhysicalFactsRules.get_plane(object, state) != PhysicalFactsRules.get_plane(actor, state): continue
		if sense == "hearing" and not CombatNoiseRules.can_hear(actor, origin, position, grid, object.discovery.noise, object, state): continue
		if HexUtils.get_distance(origin, position) * 5 > int(object.discovery.range_feet) or bool(check.get("auto_failed", false)) or int(check.total) < int(object.discovery.dc): continue
		if not object.has("discovered_by"): object["discovered_by"] = []
		object.discovered_by.append(actor.character_id)
		found.append(str(object.name))
	return {"success":true, "seconds":6, "check":check, "found":found, "message":"Search: Perception %d; %s." % [int(check.total), "nothing new found" if found.is_empty() else "found " + ", ".join(found)]}


static func _medical_search(state: Dictionary, actor: Character, position: Vector2i, origin: Vector2i, grid: HexGrid, party: Array) -> Dictionary:
	var candidates: Array = []
	for object in state.get("objects", []):
		if not object.has("medical_search") or LocalRoomRules.coord(object.position) != position: continue
		if bool(object.get("removed", false)) or int(object.get("hp", 1)) <= 0 or str(object.get("remains", "destroyed")) == "destroyed": continue
		if not ContainmentRules.relation(state, "object", str(object.id)).is_empty() or PhysicalFactsRules.get_plane(object, state) != PhysicalFactsRules.get_plane(actor, state): continue
		if HexUtils.get_distance(origin, position) * 5 > int(object.medical_search.range_feet): continue
		if int(GameManager.campaign_elapsed_seconds) > int(object.medical_search.recent_until_seconds): continue
		if actor.character_id in object.get("medical_discovered_by", []): continue
		candidates.append(object)
	var context := check_context(state, actor, grid, party)
	context["sense"] = "sight"
	context["sight_target_position"] = position
	context["lightly_obscured"] = CombatPerception.sight_is_lightly_obscured(actor, position, grid, HexUtils.get_distance(origin, position) * 5)
	var check := EventResolver.resolve_skill_check(actor, {"ability":"WIS", "skill":"Medicine", "dc":0}, {}, context)
	var found: Array[String] = []
	var information: Array[String] = []
	for object in candidates:
		if bool(check.get("auto_failed", false)) or int(check.total) < int(object.medical_search.dc): continue
		if not object.has("medical_discovered_by"): object["medical_discovered_by"] = []
		object.medical_discovered_by.append(actor.character_id)
		found.append(str(object.name))
		information.append(str(object.medical_search.information))
	var message := "Search: Medicine %d; %s." % [int(check.total), "no new medical clue found" if information.is_empty() else "revealed: " + "; ".join(information)]
	return {"success":true, "seconds":6, "check":check, "found":found, "medical_information":information, "message":message}


static func _tracks_search(state: Dictionary, actor: Character, position: Vector2i, origin: Vector2i, grid: HexGrid, party: Array) -> Dictionary:
	var candidates: Array = []
	for object in state.get("objects", []):
		if not object.has("tracks_search") or LocalRoomRules.coord(object.position) != position: continue
		if bool(object.get("removed", false)) or int(object.get("hp", 1)) <= 0: continue
		if not ContainmentRules.relation(state, "object", str(object.id)).is_empty() or PhysicalFactsRules.get_plane(object, state) != PhysicalFactsRules.get_plane(actor, state): continue
		if HexUtils.get_distance(origin, position) * 5 > int(object.tracks_search.range_feet): continue
		if actor.character_id in object.get("tracks_discovered_by", []): continue
		candidates.append(object)
	var context := check_context(state, actor, grid, party)
	context["sense"] = "sight"
	context["sight_target_position"] = position
	context["lightly_obscured"] = CombatPerception.sight_is_lightly_obscured(actor, position, grid, HexUtils.get_distance(origin, position) * 5)
	var check := EventResolver.resolve_skill_check(actor, {"ability":"WIS", "skill":"Survival", "dc":0}, {}, context)
	var found: Array[String] = []
	var information: Array[String] = []
	for object in candidates:
		if bool(check.get("auto_failed", false)) or int(check.total) < int(object.tracks_search.dc): continue
		if not object.has("tracks_discovered_by"): object["tracks_discovered_by"] = []
		object.tracks_discovered_by.append(actor.character_id)
		found.append(str(object.name))
		information.append(str(object.tracks_search.information))
	var message := "Search: Survival %d; %s." % [int(check.total), "no new track clue found" if information.is_empty() else "revealed: " + "; ".join(information)]
	return {"success":true, "seconds":6, "check":check, "found":found, "track_information":information, "message":message}
