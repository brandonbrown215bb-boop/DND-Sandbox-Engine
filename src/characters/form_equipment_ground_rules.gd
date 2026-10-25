## Atomic form-equipment transfer using ordinary exact-copy removal and placement.
class_name FormEquipmentGroundRules
extends RefCounted

static func plan(actor: Character, host: SpellCastContext = null) -> Dictionary:
	actor.inventory.copies.sync(actor.inventory)
	var dto := {"inventory": actor.inventory.to_dict()}
	for error in [InventoryCopies.saved_error(dto.inventory), ContainerRules.saved_error(dto), AttachmentRules.saved_error(dto)]:
		if not error.is_empty(): return {"error": "Equipment transfer refused: " + error}
	var slots: Array = []
	for slot in actor.inventory.copies.equipped:
		var copy := actor.inventory.get_instance(str(actor.inventory.copies.equipped[slot]))
		if CurseRules.is_cursed(copy) and not CurseRules.removal_allowed(copy): continue
		slots.append(slot)
	if slots.is_empty(): return {"slots": slots}
	var room := host.ground_room if host != null and not host.ground_room.is_empty() else LocatedSourceEndRules.current_room()
	var position: Variant = null
	var combat := host != null and host.grid != null and host.ground_room.is_empty()
	if combat:
		room = LocalRoomCombat.room()
		if room.is_empty(): return {"error": "Equipment drops require a persistent room for this encounter."}
		for player in host.players:
			if player.get("character") == actor: position = player.get("hex_position")
		if not position is Vector2i or not host.grid.tiles.has(position): return {"error": "Equipment drops require the actor's actual combat location."}
	else:
		if GameManager.current_state == GameManager.GameState.COMBAT and (host == null or host.ground_room.is_empty()): return {"error": "Equipment drops require the live combat host."}
		var raw: Variant = room.get("party_positions", {}).get(actor.character_id)
		if not DungeonPersistence.coordinate(raw): return {"error": "Equipment drops require the actor's actual room location."}
		position = LocalRoomRules.coord(raw)
		if not room.get("cells", []).has(raw): return {"error": "Equipment drop location is outside the room."}
	if not room.get("cells", []).any(func(cell): return LocalRoomRules.coord(cell) == position): return {"error": "Equipment drop location is outside the persistent room."}
	var candidate := room.duplicate(true)
	if combat: LocalRoomCombat.capture_ground_items(candidate, host.ground_items)
	var ids := {}
	var destinations := {}
	var pending_destinations := {}
	for object in room.get("objects", []): destinations[str(object.id)] = true
	if combat:
		for ground in host.ground_items:
			if str(ground.get("instance_id", "")).is_empty(): continue
			var copy := {"instance_id": ground.instance_id, "definition_id": ground.get("definition_id", ""), "state": ground.get("copy_state", {})}
			var destination := LocalRoomRules.placed_item(room, copy, LocalRoomRules.coord(ground.position))
			destinations[str(destination.id)] = true
			pending_destinations[str(destination.id)] = true
	for slot in slots:
		var copy := actor.inventory.get_instance(str(actor.inventory.copies.equipped[slot]))
		if DataLoader.get_item(str(copy.get("definition_id", ""))).is_empty() or not InventoryCopies.record_state_error(copy).is_empty(): return {"error": "Equipment copy cannot be transferred."}
		var placed := LocalRoomRules.placed_item(room, copy, position)
		if ids.has(placed.id) or pending_destinations.has(placed.id): return {"error": "Equipment copies share a ground destination."}
		ids[placed.id] = true
		var old := LocalRoomRules.get_object(room, str(placed.id))
		if not old.is_empty() and (not bool(old.get("removed", false)) or not old.get("contents", []).is_empty()): return {"error": "Equipment ground destination is already occupied."}
		destinations[str(placed.id)] = true
		var candidate_old := LocalRoomRules.get_object(candidate, str(placed.id))
		if candidate_old.is_empty(): candidate.objects.append(placed)
		else:
			candidate_old.clear()
			candidate_old.merge(placed)
		if combat:
			if host.ground_items.any(func(g): return str(g.get("instance_id", "")) == str(copy.instance_id)): return {"error": "Equipment copy is already on the combat ground."}
			if CombatObjectRules.make_dropped_item(copy, position, actor.character_id).is_empty(): return {"error": "Equipment copy cannot be placed in combat."}
	if not room.is_empty() and destinations.size() > 200: return {"error": "There is no room for all equipment ground records."}
	var placement_error := DungeonPersistence.local_error(candidate)
	if not placement_error.is_empty(): return {"error": "Equipment ground transfer refused: " + placement_error}
	return {"slots": slots, "room": room, "position": position, "combat": combat, "host": host}

## No awaits between full validation and commit; removal hooks stamp the outgoing copy.
static func commit(actor: Character, transfer: Dictionary) -> Array:
	var dropped: Array = []
	var copies := actor.inventory.drop_equipped_instances(transfer.slots)
	for copy in copies:
		dropped.append(str(copy.instance_id))
		if transfer.combat:
			var object := CombatObjectRules.make_dropped_item(copy, transfer.position, actor.character_id)
			transfer.host.ground_items.append(object)
		else:
			var object := LocalRoomRules.placed_item(transfer.room, copy, transfer.position)
			var old := LocalRoomRules.get_object(transfer.room, str(object.id))
			if old.is_empty(): transfer.room.objects.append(object)
			else:
				old.clear()
				old.merge(object)
	return dropped
