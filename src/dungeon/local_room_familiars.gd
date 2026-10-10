## Familiar presence controls in Crown's authored rooms.
class_name LocalRoomFamiliars
extends RefCounted

static func available(state: Dictionary, position: Vector2i, owner: Character, party: Array) -> bool:
	if not LocalRoomRules.passable(state, position) or not LocalRoomRules.object_at(state, position).is_empty(): return false
	if LocalRoomRules.requires_surface_traversal(LocalRoomRules.surface_at(state, position)): return false
	for member in party:
		if LocalRoomRules.coord(state.get("party_positions", {}).get(member.character_id, [9999, 9999])) == position: return false
		if member != owner and FamiliarRules.position(member, str(state["id"])) == position: return false
		if not PaladinRules.find_steed_is_mounted(member) and PaladinRules.find_steed_room_position(member, str(state["id"])) == position: return false
	if not bool(state.get("encounter_cleared", false)):
		for spawn in state.get("monster_spawns", []):
			if LocalRoomRules.coord(spawn) == position: return false
	return true

static func spawn_position(state: Dictionary, owner: Character, party: Array, radius: int = 2) -> Vector2i:
	var origin := LocalRoomRules.coord(state.get("party_positions", {}).get(owner.character_id, [9999, 9999]))
	for candidate in HexUtils.get_hexes_in_range(origin, radius):
		if available(state, candidate, owner, party): return candidate
	return FamiliarRules.ABSENT

static func ensure_position(state: Dictionary, owner: Character, party: Array) -> Vector2i:
	var record := FamiliarRules.state(owner)
	if record.is_empty() or bool(record.get("pocket", false)): return FamiliarRules.ABSENT
	var saved := FamiliarRules.position(owner, str(state["id"]))
	if saved != FamiliarRules.ABSENT and available(state, saved, owner, party): return saved
	var destination := spawn_position(state, owner, party)
	if destination != FamiliarRules.ABSENT: FamiliarRules.set_position(owner, str(state["id"]), destination)
	return destination

static func summon(state: Dictionary, owner: Character, party: Array, form_id: String, cost: String) -> Dictionary:
	var destination := spawn_position(state, owner, party)
	if destination == FamiliarRules.ABSENT: return LocalRoomRules.failure("No unoccupied floor space is available; no resource was spent.")
	var result := DruidRules.summon_wild_companion(owner, form_id, cost)
	if not bool(result.get("success", false)): return result
	FamiliarRules.set_position(owner, str(state["id"]), destination)
	result["seconds"] = 6
	return result

static func cast_find_familiar(state: Dictionary, owner: Character, party: Array, form_id: String, creature_type: String, ritual: bool = false) -> Dictionary:
	if owner == null or not owner.is_alive or CombatAction.is_incapacitated(owner): return LocalRoomRules.failure("That character cannot cast a spell.")
	if GameManager.current_state == GameManager.GameState.COMBAT: return LocalRoomRules.failure("An hour-long cast is unavailable during combat.")
	if form_id not in DruidRules.WILD_COMPANION_FORMS or creature_type not in ["celestial", "fey", "fiend"]: return LocalRoomRules.failure("Choose a supported familiar form and creature type.")
	var spell := DataLoader.get_spell("find_familiar")
	var caster_error := LocalRoomRules._room_spell_caster_error(owner, spell)
	if not caster_error.is_empty(): return LocalRoomRules.failure(caster_error)
	if ritual and not bool(spell.get("ritual", false)): return LocalRoomRules.failure("This spell cannot be cast as a ritual.")
	var destination := spawn_position(state, owner, party)
	if destination == FamiliarRules.ABSENT: return LocalRoomRules.failure("No unoccupied floor space is available; no component or slot was spent.")
	var component_id := owner.inventory.required_spell_component_instance(spell)
	if component_id.is_empty(): return LocalRoomRules.failure("Find Familiar consumes incense worth 10 GP, even as a ritual.")
	if not ritual:
		var spent := CombatAction.spend_spell_slot(owner, spell)
		if not bool(spent.get("success", false)): return LocalRoomRules.failure(str(spent.get("message", "No spell slot remains.")))
	owner.inventory.destroy_instance(component_id)
	FamiliarRules.create(owner, form_id, "find_familiar", creature_type)
	FamiliarRules.set_position(owner, str(state["id"]), destination)
	return {"success": true, "seconds": 4200 if ritual else 3600, "message": "%s summons a %s %s%s, consuming 10 GP of incense. This familiar remains through Long Rests." % [owner.character_name, creature_type, DataLoader.get_monster(form_id).get("name", form_id), " as a ritual" if ritual else ""]}

static func change_presence(state: Dictionary, owner: Character, party: Array, mode: String) -> Dictionary:
	if owner == null or not owner.is_alive or CombatAction.is_incapacitated(owner): return LocalRoomRules.failure("You cannot command your familiar right now.")
	var record := FamiliarRules.state(owner)
	if record.is_empty(): return LocalRoomRules.failure("You have no familiar; summon one first.")
	if mode == "release":
		FamiliarRules.forget(owner)
		return {"success": true, "seconds": 6, "message": "Your familiar is released. Summoning another requires a new resource."}
	if mode == "dismiss" and not bool(record.get("pocket", false)):
		FamiliarRules.set_pocket(owner, true)
		return {"success": true, "seconds": 6, "message": "Your familiar waits in its pocket dimension, retaining its Hit Points."}
	if mode == "recall" and bool(record.get("pocket", false)):
		var destination := spawn_position(state, owner, party, 6)
		if destination == FamiliarRules.ABSENT: return LocalRoomRules.failure("No unoccupied floor space is available to recall your familiar.")
		FamiliarRules.set_pocket(owner, false)
		FamiliarRules.set_position(owner, str(state["id"]), destination)
		return {"success": true, "seconds": 6, "message": "Your familiar returns with its retained Hit Points; no summon resource was spent."}
	return LocalRoomRules.failure("That familiar presence command is unavailable.")
