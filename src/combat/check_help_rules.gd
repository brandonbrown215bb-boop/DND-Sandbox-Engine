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
		var matches: bool = (entry.kind == "skill" and entry.name == skill) or (entry.kind == "tool" and _tool_matches(str(entry.name), tool))
		if not matches: continue
		var helper: Character = entry.helper.get_ref()
		if helper == null or not helper.is_alive or CombatAction.is_incapacitated(helper) or not owns(helper, str(entry.kind), str(entry.name)): continue
		if not participants.any(func(participant): return participant == helper if participant is Character else participant.get("character") == helper): continue
		var origin: Variant = CombatPerception._position(helper, grid)
		if origin == null or HexUtils.get_distance(origin, recipient_position) > 1 or not Targeting.has_line_of_sight(origin, recipient_position, grid): continue
		used.append(str(entry.token))
		# All matching assistance is used by this one check; it cannot bank
		# several advantaged rolls by stacking helpers.
		recipient.combat_check_help.erase(entry)
	return {"advantage":not used.is_empty(), "sources":used}
