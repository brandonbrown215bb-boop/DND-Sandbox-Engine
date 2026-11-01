## Search one represented room space and retain discovery on the exact object.
class_name LocalRoomSearchRules
extends RefCounted

const RANGE_FEET := 60


static func object_error(object: Dictionary) -> String:
	if not object.has("discovery"):
		return "Discovery receipts need a discovery rule." if object.has("discovered_by") else ""
	var rule: Variant = object.discovery
	if not rule is Dictionary or rule.size() != 2 or not ResourcePoolRules._integer(rule.get("dc"), 1, 1000) or not ResourcePoolRules._integer(rule.get("range_feet"), 1, RANGE_FEET): return "Discovery needs a DC and a range of 1-60 feet."
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


static func search(state: Dictionary, actor: Character, position: Vector2i, grid: HexGrid, party: Array) -> Dictionary:
	if actor == null or actor not in party or not actor.is_alive or CombatAction.is_incapacitated(actor): return LocalRoomRules.failure("That character cannot Search now.")
	if not ContainmentRules.relation(state, "character", actor.character_id).is_empty(): return LocalRoomRules.failure("An internal occupant cannot search the outside room.")
	var origin_data: Variant = state.get("party_positions", {}).get(actor.character_id)
	if not origin_data is Array or grid == null or not grid.has_tile(position): return LocalRoomRules.failure("Choose a represented room space.")
	var origin := LocalRoomRules.coord(origin_data)
	if HexUtils.get_distance(origin, position) * 5 > RANGE_FEET: return LocalRoomRules.failure("Choose a space within 60 feet.")
	if not CombatPerception.can_see_target(actor, null, origin, position, grid): return LocalRoomRules.failure("You cannot see that space to search it.")
	for object in state.get("objects", []):
		if LocalRoomRules.coord(object.position) == position and not object_error(object).is_empty(): return LocalRoomRules.failure(object_error(object))
	var participants: Array = []
	for member in party:
		if state.get("party_positions", {}).has(member.character_id): participants.append({"character":member, "hex_position":LocalRoomRules.coord(state.party_positions[member.character_id])})
	var context := {"grid":grid, "participants":participants, "actor_position":origin, "sense":"sight", "lightly_obscured":CombatPerception.sight_is_lightly_obscured(actor, position, grid, HexUtils.get_distance(origin, position) * 5)}
	context["sight_target_position"] = position
	var check := EventResolver.resolve_skill_check(actor, {"ability":"WIS", "skill":"Perception", "sense":"sight", "dc":0}, {}, context)
	var found: Array[String] = []
	for object in state.get("objects", []):
		if bool(object.get("removed", false)) or not object.has("discovery") or known(object, actor) or LocalRoomRules.coord(object.position) != position: continue
		if not ContainmentRules.relation(state, "object", str(object.id)).is_empty() or PhysicalFactsRules.get_plane(object, state) != PhysicalFactsRules.get_plane(actor, state): continue
		if HexUtils.get_distance(origin, position) * 5 > int(object.discovery.range_feet) or bool(check.get("auto_failed", false)) or int(check.total) < int(object.discovery.dc): continue
		if not object.has("discovered_by"): object["discovered_by"] = []
		object.discovered_by.append(actor.character_id)
		found.append(str(object.name))
	return {"success":true, "seconds":6, "check":check, "found":found, "message":"Search: Perception %d; %s." % [int(check.total), "nothing new found" if found.is_empty() else "found " + ", ".join(found)]}
