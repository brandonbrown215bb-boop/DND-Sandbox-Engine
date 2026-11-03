## Bounded Wisdom (Insight) Search for authored intent/emotion clues on encounter creatures.
class_name InsightSearchRules
extends RefCounted

const RANGE_HEXES := 6
const CLUE_FIELDS := ["dc", "kind", "information"]


static func definition_error(monster: Dictionary) -> String:
	if not monster.has("insight_search"):
		return ""
	var clue: Variant = monster.insight_search
	if not clue is Dictionary or clue.size() != CLUE_FIELDS.size(): return "Insight Search needs dc, kind and information."
	for field in clue:
		if field not in CLUE_FIELDS: return "Unsupported Insight Search clue field."
	if not ResourcePoolRules._integer(clue.get("dc"), 1, 1000): return "Insight Search needs a DC from 1 to 1000."
	if clue.get("kind") != "intent_emotion": return "Insight Search clue kind must be intent_emotion."
	if not clue.get("information") is String or str(clue.information).strip_edges().is_empty() or str(clue.information).length() > 500: return "Insight Search information must be nonempty and at most 500 characters."
	return ""


static func ledger_error(room: Dictionary) -> String:
	var rows: Variant = room.get("insight_search_discoveries", [])
	if not rows is Array or rows.size() > 1000: return "Insight Search discoveries are malformed."
	if rows.is_empty(): return ""
	var encounter_monsters: Variant = room.get("encounter_monsters", null)
	if not encounter_monsters is Array or encounter_monsters.is_empty() or encounter_monsters.size() > 200: return "Insight Search encounter identities are malformed."
	var party_positions: Variant = room.get("party_positions", null)
	if not party_positions is Dictionary: return "Insight Search observer identities are malformed."
	var seen := {}
	for row in rows:
		if not row is Dictionary or row.size() != 3: return "Insight Search receipts need exact creature, source and observer identities."
		var index: Variant = row.get("encounter_index")
		if not ResourcePoolRules._integer(index, 0, encounter_monsters.size() - 1): return "Insight Search creature index is invalid."
		var monster_id := str(encounter_monsters[int(index)])
		if row.get("monster_id") != monster_id or not row.get("observer_id") is String or not party_positions.has(str(row.get("observer_id", ""))): return "Insight Search source or observer identity is invalid."
		var source: Dictionary = DataLoader.get_monster(monster_id)
		if source.is_empty() or not definition_error(source).is_empty(): return "Insight Search receipt has no valid authored clue."
		var key := "%d|%s|%s" % [int(index), monster_id, str(row.observer_id)]
		if seen.has(key): return "Insight Search receipt is duplicated."
		seen[key] = true
	return ""


static func observer_information(room: Dictionary, actor: Character) -> Array[String]:
	var information: Array[String] = []
	if actor == null: return information
	for row in room.get("insight_search_discoveries", []):
		if row.get("observer_id") != actor.character_id: continue
		var source: Dictionary = DataLoader.get_monster(str(row.get("monster_id", "")))
		var clue: Dictionary = source.get("insight_search", {})
		if not clue.is_empty(): information.append(str(clue.get("information", "")))
	return information


static func known(room: Dictionary, monster: Dictionary, actor: Character) -> bool:
	if actor == null: return false
	for row in room.get("insight_search_discoveries", []):
		if int(row.get("encounter_index", -1)) == int(monster.get("encounter_index", -2)) and row.get("monster_id") == monster.get("monster_id") and row.get("observer_id") == actor.character_id:
			return true
	return false


static func target_error(state: CombatState, actor: Character, room: Dictionary, monster: Dictionary, position: Vector2i) -> String:
	if room.is_empty() or not is_same(LocalRoomCombat.room(), room): return "Insight Search needs this encounter's captured room."
	if monster.is_empty() or not state.monster_entities.any(func(candidate): return is_same(candidate, monster)) or monster.get("hex_position") != position or not monster.get("is_alive", false) or int(monster.get("current_hp", 0)) <= 0: return "That exact creature is no longer alive and present."
	var index: Variant = monster.get("encounter_index")
	if not ResourcePoolRules._integer(index, 0, room.get("encounter_monsters", []).size() - 1) or room.encounter_monsters[int(index)] != monster.get("monster_id"): return "Insight Search needs an exact represented encounter creature."
	if not monster.has("insight_search"): return "This creature has no authored Insight clue."
	var definition_error_message := definition_error(monster)
	if not definition_error_message.is_empty(): return definition_error_message
	if actor == null or not actor.is_alive or CombatAction.is_incapacitated(actor): return "You cannot Search now."
	var entity: Dictionary = state.ready_actions.owner_entity(state, actor)
	if entity.is_empty() or not ContainmentRules.relation(room, "character", actor.character_id).is_empty(): return "Choose a present character outside containment."
	if known(room, monster, actor): return "This character already knows that creature's authored clue."
	if PhysicalFactsRules.get_plane(actor, room) != PhysicalFactsRules.get_plane(monster, room): return "The creature is on another plane."
	var origin: Vector2i = entity.hex_position
	var target_altitude := int(monster.get("altitude_feet", LocalRoomRules.elevation_feet(room, position)))
	var origin_altitude := int(entity.get("altitude_feet", LocalRoomRules.elevation_feet(room, origin)))
	if HexUtils.get_distance(origin, position) > RANGE_HEXES or abs(origin_altitude - target_altitude) > 30: return "Move within 30 feet to Search this creature."
	if not state.hex_grid.has_tile(position) or not Targeting.has_line_of_sight(origin, position, state.hex_grid) or not CombatPerception.can_see_target(actor, monster, origin, position, state.hex_grid): return "You cannot see that creature well enough to Search it."
	return ledger_error(room)


static func targets(state, actor: Character) -> Dictionary:
	var room := LocalRoomCombat.room()
	var result := {}
	for monster in state.monster_entities:
		var position: Vector2i = monster.get("hex_position", Vector2i.ZERO)
		if target_error(state, actor, room, monster, position).is_empty():
			if not result.has(position): result[position] = []
			result[position].append(monster)
	return result


static func request(state, actor: Character, monsters: Array, position: Vector2i, current: Callable, pay: Callable) -> Dictionary:
	var room := LocalRoomCombat.room()
	if not current.call(): return {"status":"stale"}
	monsters = monsters.filter(func(candidate): return target_error(state, actor, room, candidate, position).is_empty())
	if monsters.is_empty(): return {"status":"refused", "message":"Unknown or unavailable Insight Search target."}
	var monster: Dictionary = monsters[0]
	if monsters.size() > 1:
		var ids: Array[String] = []
		var labels := {}
		for candidate in monsters:
			ids.append(str(candidate.id))
			labels[str(candidate.id)] = str(candidate.name)
		var picked: String = await state.hud._request_popup_choice("Search: choose the exact creature", ids, labels)
		if picked.is_empty(): return {"status":"ignored"}
		if picked not in ids: return {"status":"stale"}
		monster = monsters[ids.find(picked)]
	if not current.call() or not target_error(state, actor, room, monster, position).is_empty(): return {"status":"stale"}
	var captured: Dictionary = monster.insight_search.duplicate(true)
	if not current.call() or not target_error(state, actor, room, monster, position).is_empty() or monster.insight_search != captured: return {"status":"stale"}
	var context: Dictionary = state._ability_check_context(actor, monster)
	context["sight"] = true
	context["sight_target_position"] = position
	var check := EventResolver.resolve_skill_check(actor, {"ability":"WIS", "skill":"Insight", "dc":int(captured.dc), "sense":"sight"}, {}, context)
	var paid := bool(pay.call())
	if not paid: return {"status":"refused", "message":"Insight Search could not settle its Action."}
	if bool(check.get("success", false)):
		if not room.has("insight_search_discoveries"): room["insight_search_discoveries"] = []
		room.insight_search_discoveries.append({"encounter_index":int(monster.encounter_index), "monster_id":str(monster.monster_id), "observer_id":actor.character_id})
	var outcome := "clue recorded in the searcher's field notes" if bool(check.get("success", false)) else "no authored clue discerned"
	return {"status":"resolved", "success":bool(check.get("success", false)), "check":check, "information":str(captured.information) if bool(check.get("success", false)) else "", "message":"Search: Insight %d vs DC %d — %s." % [int(check.total), int(captured.dc), outcome]}
