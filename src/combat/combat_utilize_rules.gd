## Combat delivery for the room's existing physical object interactions.
class_name CombatUtilizeRules
extends RefCounted

const ACTIONS := ["open", "close", "lock", "unlock", "pick_lock", "pry", "force_open", "bar", "unbar", "jam", "unjam", "extinguish", "take", "put"]


static func error(state: CombatState, actor: Character, room: Dictionary, object: Dictionary, position: Vector2i) -> String:
	if not LocalRoomSearchRules.known(object, actor): return "There is no known object there."
	if room.is_empty() or not is_same(LocalRoomCombat.room(), room): return "This encounter has no matching room."
	if object.is_empty() or not is_same(LocalRoomRules.get_object(room, str(object.get("id", ""))), object) or bool(object.get("removed", false)) or LocalRoomRules.coord(object.position) != position: return "That exact object is no longer here."
	var entity := state.ready_actions.owner_entity(state, actor)
	if entity.is_empty() or not actor.is_alive or CombatAction.is_incapacitated(actor): return "You cannot interact now."
	if ContainmentRules.involved(room, "object", str(object.id)) or not ContainmentRules.relation(room, "character", actor.character_id).is_empty(): return "Release the contained object or creature first."
	if PhysicalFactsRules.get_plane(actor, room) != PhysicalFactsRules.get_plane(object, room): return "The object is on another plane."
	var origin: Vector2i = entity.hex_position
	var object_altitude := int(object.get("altitude_feet", LocalRoomRules.elevation_feet(room, position)))
	var actor_altitude := int(entity.get("altitude_feet", LocalRoomRules.elevation_feet(room, origin)))
	if HexUtils.get_distance(origin, position) > 1 or abs(actor_altitude - object_altitude) > 5: return "Move within 5 feet of the object first."
	if not state.hex_grid.has_tile(position) or not Targeting.has_line_of_sight(origin, position, state.hex_grid): return "The object is blocked."
	if not CombatPerception.can_see_target(actor, object, origin, position, state.hex_grid): return "You cannot see that object."
	return ""


static func targets(state: CombatState, actor: Character) -> Dictionary:
	var room := LocalRoomCombat.room()
	var result := {}
	for object in room.get("objects", []):
		var position := LocalRoomRules.coord(object.position)
		if error(state, actor, room, object, position).is_empty(): result[position] = object
	return result


static func options(object: Dictionary) -> Array[String]:
	var result: Array[String] = []
	if str(object.get("kind", "")) in ["door", "container"]:
		result.append("close" if object.get("open", false) else "open")
		if not object.get("open", false):
			if object.get("lockable", false): result.append("unlock" if object.get("locked", false) else "lock")
			if CombatObjectRules.is_locked(object): result.append_array(["pick_lock", "pry"])
			result.append("force_open")
			if object.get("barrable", false) and not object.get("barred", false): result.append("bar")
			if not object.get("stuck", false) and not object.get("jammed", false): result.append("jam")
		if object.get("barred", false): result.append("unbar")
		if object.get("stuck", false) or object.get("jammed", false): result.append("unjam")
	if object.get("burning", false): result.append("extinguish")
	if str(object.get("kind", "")) != "container" or object.get("open", false):
		if not object.get("contents", []).is_empty(): result.append("take")
		if str(object.get("kind", "")) == "container": result.append("put")
	return result


## All choices are unpaid. Resolve synchronously after the final live guard;
## a failed rolled attempt still spends, a refusal (seconds == 0) does not.
static func request(state: CombatState, actor: Character, object: Dictionary, current: Callable, pay: Callable) -> Dictionary:
	var room := LocalRoomCombat.room()
	var position := LocalRoomRules.coord(object.position)
	var actions := options(object)
	if actions.is_empty(): return {"status":"refused", "message":"This object has no supported Utilize interaction."}
	var labels := {}
	for action in actions: labels[action] = action.replace("_", " ").capitalize()
	var action := await state.hud._request_popup_choice("Utilize: " + str(object.get("name", "Object")), actions, labels)
	if action.is_empty(): return {"status":"ignored"}
	if not current.call() or not error(state, actor, room, object, position).is_empty() or action not in options(object): return {"status":"stale"}
	var instance_id := ""
	if action in ["take", "put"]:
		var records: Array = object.get("contents", []) if action == "take" else actor.inventory.backpack_instances()
		var ids: Array[String] = []
		labels = {}
		for record in records:
			ids.append(str(record.instance_id))
			labels[str(record.instance_id)] = InventoryCopies.display_name(record, ids.size())
		instance_id = await state.hud._request_popup_choice("Utilize: choose the exact item", ids, labels)
		if instance_id.is_empty(): return {"status":"ignored"}
	return settle(state, actor, room, object, position, action, instance_id, current, pay)


static func settle(state: CombatState, actor: Character, room: Dictionary, object: Dictionary, position: Vector2i, action: String, instance_id: String, current: Callable, pay: Callable) -> Dictionary:
	if not current.call() or action not in ACTIONS: return {"status":"stale"}
	var refused := error(state, actor, room, object, position)
	if not refused.is_empty(): return {"status":"stale", "message":refused}
	var declarations: Variant = object.get("interaction_noise", {})
	if not declarations is Dictionary: return {"status":"refused", "message":"Object interaction_noise must map operations to sounds."}
	var noise: Variant = declarations.get(action, {})
	if declarations.has(action) and not CombatNoiseRules.error(noise).is_empty(): return {"status":"refused", "message":CombatNoiseRules.error(noise)}
	# Supply live combat space without adding summoned actors to the durable party map.
	var result := LocalRoomRules.interact(room, str(object.id), action, actor, instance_id, state._ability_check_context(actor))
	if int(result.get("seconds", 0)) > 0:
		var paid := bool(pay.call())
		assert(paid, "Utilize payment was validated immediately before synchronous resolution")
		result["status"] = "resolved"
		if declarations.has(action): result["noise"] = noise.duplicate(true)
	else: result["status"] = "refused"
	state._update_grid_entities()
	return result
