## Help grants the next matching real check, not a stored general Advantage.
class_name CheckHelpRules
extends RefCounted

static var serial := 0


static func options(actor: Character) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for name in DataLoader.VALID_SKILLS:
		if owns(actor, "skill", name): out.append({"kind":"skill", "name":name})
	for name in actor.tool_proficiencies: out.append({"kind":"tool", "name":name})
	return out


static func owns(actor: Character, kind: String, name: String) -> bool:
	return name in DataLoader.VALID_SKILLS and actor.get_skill_proficiency_bonus(name) >= actor.proficiency_bonus if kind == "skill" else name in actor.tool_proficiencies if kind == "tool" else false


static func grant(helper: Character, recipient: Character, kind: String, name: String) -> Dictionary:
	if helper == null or recipient == null or helper == recipient or not owns(helper, kind, name) or not helper.is_alive or CombatAction.is_incapacitated(helper): return {"success":false}
	serial += 1
	var token := "help:%s:%d" % [helper.character_id, serial]
	recipient.combat_check_help.append({"token":token, "helper_id":helper.character_id, "helper":weakref(helper), "kind":kind, "name":name})
	return {"success":true, "token":token}


static func start_turn(helper: Character, recipients: Array) -> void:
	for recipient in recipients:
		if recipient is Character:
			recipient.combat_check_help = recipient.combat_check_help.filter(func(entry): return entry.helper_id != helper.character_id)


static func room_error(room: Dictionary, helper: Character, recipient: Character, party: Array, grid: HexGrid) -> String:
	if helper == null or recipient == null or helper == recipient or helper not in party or recipient not in party or not helper.is_alive or not recipient.is_alive or CombatAction.is_incapacitated(helper) or CombatAction.is_incapacitated(recipient): return "Choose an able ally and helper."
	for member in [helper, recipient]:
		if not room.get("party_positions", {}).has(member.character_id) or not ContainmentRules.relation(room, "character", member.character_id).is_empty(): return "Both characters must be in the room."
	if PhysicalFactsRules.get_plane(helper, room) != PhysicalFactsRules.get_plane(recipient, room): return "Your ally is on another plane."
	var origin := LocalRoomRules.coord(room.party_positions[helper.character_id])
	var destination := LocalRoomRules.coord(room.party_positions[recipient.character_id])
	if grid == null or not grid.has_tile(origin) or not grid.has_tile(destination) or HexUtils.get_distance(origin, destination) > 1 or abs(LocalRoomRules.altitude_feet(room, helper.character_id) - LocalRoomRules.altitude_feet(room, recipient.character_id)) > 5 or not Targeting.has_line_of_effect(origin, destination, grid): return "Move within 5 feet of your ally with a clear path."
	return ""


static func grant_verbal(helper: Character, recipient: Character, kind: String, name: String, speaker_position: Vector2i, listener_position: Vector2i, grid: HexGrid, room: Dictionary = {}, range_feet: int = CommunicationRules.DEFAULT_RANGE_FEET) -> Dictionary:
	if not owns(helper, kind, name): return {"success":false, "message":"Choose one of your actual proficiencies."}
	var error: String = CommunicationRules.eligibility_error(helper, recipient, speaker_position, listener_position, grid, room, range_feet)
	if not error.is_empty(): return {"success":false, "message":error}
	var result: Dictionary = grant(helper, recipient, kind, name)
	if result.get("success", false):
		recipient.combat_check_help[-1]["verbal"] = true
		recipient.combat_check_help[-1]["language"] = CommunicationRules.shared_language(helper, recipient)
	return result


static func grant_room(room: Dictionary, helper: Character, recipient: Character, kind: String, name: String, party: Array, grid: HexGrid, verbal: bool = false) -> Dictionary:
	if not owns(helper, kind, name): return LocalRoomRules.failure("Choose one of your actual proficiencies.")
	var seconds_error: String = room_error(room, helper, recipient, party, grid)
	if verbal:
		if helper == null or recipient == null or helper == recipient or helper not in party or recipient not in party or not helper.is_alive or not recipient.is_alive or CombatAction.is_incapacitated(helper) or CombatAction.is_incapacitated(recipient): return LocalRoomRules.failure("Choose an able ally and helper.")
		for member in [helper, recipient]:
			if not room.get("party_positions", {}).has(member.character_id) or not ContainmentRules.relation(room, "character", member.character_id).is_empty(): return LocalRoomRules.failure("Both characters must be present in the room.")
		if PhysicalFactsRules.get_plane(helper, room) != PhysicalFactsRules.get_plane(recipient, room): return LocalRoomRules.failure("Your ally is on another plane.")
		seconds_error = CommunicationRules.eligibility_error(helper, recipient, LocalRoomRules.coord(room.party_positions[helper.character_id]), LocalRoomRules.coord(room.party_positions[recipient.character_id]), grid, room)
	if not seconds_error.is_empty(): return LocalRoomRules.failure(seconds_error)
	# One world Action advances six seconds. Keep the benefit through the next
	# action interval, then expire before another one can use it.
	var result: Dictionary = grant(helper, recipient, kind, name)
	if not result.get("success", false): return LocalRoomRules.failure("The chosen character cannot assist this check.")
	var entry: Dictionary = recipient.combat_check_help[-1]
	entry["room"] = room
	entry["expires_at_seconds"] = int(GameManager.campaign_elapsed_seconds) + 12
	if verbal:
		entry["verbal"] = true
		entry["language"] = CommunicationRules.shared_language(helper, recipient)
	result.merge({"seconds":6, "message":"%s %s %s with %s on their next check." % [helper.character_name, "verbally assists" if verbal else "helps", recipient.character_name, name]})
	return result


static func clear_room(party: Array) -> void:
	for member in party:
		member.combat_check_help = member.combat_check_help.filter(func(entry): return not entry.has("room"))


static func _tool_matches(name: String, tool_id: String) -> bool:
	if name.is_empty() or tool_id.is_empty(): return false
	var item := DataLoader.get_item(tool_id)
	return name == tool_id or name.to_lower() == str(item.get("name", "")).to_lower()


static func consume(recipient: Character, check: Dictionary, context: Dictionary) -> Dictionary:
	var used: Array[String] = []
	var skill := str(check.get("skill", ""))
	var tool := str(check.get("tool_id", check.get("check_context", {}).get("required_tool_id", "")))
	var grid: HexGrid = context.get("grid")
	var participants: Array = context.get("participants", [])
	if grid == null or participants.is_empty(): return {"advantage":false, "sources":used}
	if not participants.any(func(participant): return participant == recipient if participant is Character else participant.get("character") == recipient): return {"advantage":false, "sources":used}
	var recipient_position: Variant = CombatPerception._position(recipient, grid)
	if recipient_position == null: return {"advantage":false, "sources":used}
	for entry in recipient.combat_check_help.duplicate():
		var helper: Character = entry.helper.get_ref()
		if entry.has("room"):
			if int(GameManager.campaign_elapsed_seconds) >= int(entry.expires_at_seconds): recipient.combat_check_help.erase(entry); continue
			if not is_same(context.get("room", {}), entry.room): continue
			var members: Array = participants.map(func(p): return p if p is Character else p.get("character"))
			if not bool(entry.get("verbal", false)) and not room_error(entry.room, helper, recipient, members, grid).is_empty(): continue
		elif context.has("room"): continue
		var matches: bool = (entry.kind == "skill" and entry.name == skill) or (entry.kind == "tool" and _tool_matches(str(entry.name), tool))
		if not matches: continue
		if helper == null or not helper.is_alive or CombatAction.is_incapacitated(helper) or not owns(helper, str(entry.kind), str(entry.name)): continue
		if not participants.any(func(participant): return participant == helper if participant is Character else participant.get("character") == helper): continue
		var origin: Variant = CombatPerception._position(helper, grid)
		if origin == null: continue
		if bool(entry.get("verbal", false)):
			if not bool(context.get("verbal_help_allowed", false)): continue
			var communication_error: String = CommunicationRules.eligibility_error(helper, recipient, origin, recipient_position, grid, context.get("room", {}))
			if not communication_error.is_empty(): continue
		elif HexUtils.get_distance(origin, recipient_position) > 1 or not Targeting.has_line_of_sight(origin, recipient_position, grid): continue
		used.append(str(entry.token))
		# All matching assistance is used by this one check; it cannot bank
		# several advantaged rolls by stacking helpers.
		recipient.combat_check_help.erase(entry)
	return {"advantage":not used.is_empty(), "sources":used}
