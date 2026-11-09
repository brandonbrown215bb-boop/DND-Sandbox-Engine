class_name AmmunitionRules
extends RefCounted
## S-249: each record is one piece, never a purchase lot.
static var shots: Dictionary = {}
static var next_shot: int = 0

static func definition_error(item: Dictionary) -> String:
	if not item.has("ammunition_kind"): return "ammunition piece needs ammunition_kind" if item.get("type") == "ammunition" else ""
	if not item.ammunition_kind is String or str(item.ammunition_kind).strip_edges().is_empty(): return "ammunition_kind must be a nonempty string"
	if str(item.get("type", "")) == "weapon":
		if not item.get("properties", []) is Array or "ammunition" not in item.get("properties", []): return "ammunition weapon needs the ammunition property"
	elif str(item.get("type", "")) != "ammunition": return "ammunition_kind requires a weapon or ammunition piece"
	if item.has("purchase_quantity") and not whole(item.purchase_quantity, 1): return "ammunition purchase quantity must be a positive whole number"
	return ""

static func whole(value: Variant, minimum: int = 0, maximum: int = 100000) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floorf(float(value)) and float(value) >= minimum and (maximum < 0 or float(value) <= maximum)

static func paid(actor: Character, weapon: Dictionary) -> bool:
	var shot: Dictionary = shots.get(weapon.get("_ammunition_shot", 0), {})
	return not shot.is_empty() and shot.actor == actor and shot.weapon == str(weapon.get("id", "")) and shot.weapon_copy == str(weapon.get("_ammunition_weapon_copy", ""))

static func options(actor: Character, weapon: Dictionary) -> Array:
	var result: Array = []
	var kind := str(weapon.get("ammunition_kind", ""))
	for record in actor.inventory.backpack_instances():
		var definition := DataLoader.get_item(str(record.definition_id))
		if definition.get("type") == "ammunition" and definition.get("ammunition_kind") == kind:
			result.append({"copy":record, "container":"", "compartment":""})
	for host in actor.inventory.owned_instances():
		for compartment in host.get("state", {}).get("contents", {}):
			for record in host.state.contents[compartment]:
				var definition := DataLoader.get_item(str(record.definition_id))
				if definition.get("type") == "ammunition" and definition.get("ammunition_kind") == kind:
					result.append({"copy":record, "container":str(host.instance_id), "compartment":str(compartment)})
	return result

static func weapon_copy(actor: Character, weapon: Dictionary) -> String:
	for slot in [Inventory.Slot.WEAPON, Inventory.Slot.OFFHAND]:
		if actor.inventory.get_equipped(slot) == str(weapon.get("id", "")):
			return actor.inventory.equipped_instance_id(slot)
	return ""

static func attack_error(actor: Character, weapon: Dictionary) -> String:
	if not weapon.has("ammunition_kind") or paid(actor, weapon): return ""
	var error := definition_error(weapon)
	if not error.is_empty(): return error
	var inventory := actor.inventory
	if weapon.has("_ammunition_weapon_copy") and str(weapon._ammunition_weapon_copy) != weapon_copy(actor, weapon): return "The exact weapon copy changed."
	if str(weapon.get("id", "")) not in [inventory.get_weapon(), inventory.get_equipped(Inventory.Slot.OFFHAND)]: return "The ammunition weapon is no longer equipped."
	if not inventory.get_equipped(Inventory.Slot.SHIELD).is_empty() or (not inventory.get_equipped(Inventory.Slot.WEAPON).is_empty() and not inventory.get_equipped(Inventory.Slot.OFFHAND).is_empty()): return "Loading this weapon needs a free hand."
	if options(actor, weapon).is_empty(): return "No matching ammunition remains."
	return ""

## Called at commitment, before prompts/rolls. A continuation carries this shot.
static func commit(actor: Character, weapon: Dictionary) -> String:
	var error := attack_error(actor, weapon)
	if not error.is_empty() or not weapon.has("ammunition_kind") or paid(actor, weapon): return error
	var selected: Dictionary = options(actor, weapon)[0]
	var record: Dictionary = selected.copy
	if str(selected.container).is_empty():
		if actor.inventory.take_instance(str(record.instance_id)).is_empty(): return "The ammunition copy is no longer carried."
	else:
		var host := actor.inventory.get_instance(str(selected.container))
		host.state.contents[selected.compartment].erase(record)
		if host.state.contents[selected.compartment].is_empty(): host.state.contents.erase(selected.compartment)
		if host.state.contents.is_empty(): host.state.erase("contents")
		if not actor.inventory.update_instance(host): return "The ammunition container is no longer carried."
	actor.ammunition_spent.append(record.duplicate(true))
	next_shot += 1
	weapon["_ammunition_weapon_copy"] = weapon_copy(actor, weapon)
	shots[next_shot] = {"weapon_copy":str(weapon._ammunition_weapon_copy),"actor":actor, "weapon":str(weapon.get("id", "")), "copy":str(record.instance_id)}
	weapon["_ammunition_shot"] = next_shot
	return ""

static func site() -> String:
	var position := PartyManager.get_exploration_position()
	var dungeon := GameManager.active_dungeon_state
	var raw_position: Variant = dungeon.get("party_position", [0, 0])
	var room_position: Vector2i = raw_position if raw_position is Vector2i else LocalRoomRules.coord(raw_position)
	return "%s:%d,%d:%s:%d,%d:%s" % [str(GameManager.active_campaign.get("id", "")), position.x, position.y, str(dungeon.get("dungeon_id", "")), room_position.x, room_position.y, str(dungeon.get("local_room_id", ""))]

static func clear_shots(actor: Character) -> void:
	actor.ammunition_spent.clear()
	for key in shots.keys():
		if shots[key].actor == actor: shots.erase(key)

static func finish(actor: Character) -> void:
	if actor.ammunition_spent.is_empty(): return
	var count := actor.ammunition_spent.size()
	var pieces := actor.ammunition_spent.slice(0, floori(float(count) / 2.0))
	if not pieces.is_empty():
		actor.ammunition_recovery.append({"site":site(), "spent_count":count, "pieces":pieces, "ended_at":int(GameManager.campaign_elapsed_seconds)})
	clear_shots(actor)

static func recovery_error(actor: Character) -> String:
	if GameManager.current_state not in [GameManager.GameState.OVERWORLD, GameManager.GameState.DUNGEON]: return "Recover ammunition after the fight."
	if not actor.is_alive or CombatAction.is_incapacitated(actor): return "You cannot search for ammunition now."
	var count := 0
	for batch in actor.ammunition_recovery:
		if batch.site == site():
			count = batch.pieces.size()
			break
	if count == 0: return "No recoverable ammunition at this site."
	if actor.inventory.backpack.size() + count > Inventory.MAX_BACKPACK_SIZE: return "Make backpack space for the recovered ammunition."
	return ""

static func recover(actor: Character) -> Dictionary:
	var error := recovery_error(actor)
	if not error.is_empty(): return {"success":false, "message":error}
	var count := 0
	for batch in actor.ammunition_recovery.duplicate():
		if batch.site != site(): continue
		for piece in batch.pieces:
			actor.inventory.receive_instance(piece)
			count += 1
		actor.ammunition_recovery.erase(batch)
		break
	GameManager.advance_campaign_time(60)
	return {"success":true, "count":count, "message":"Recovered %d ammunition in 1 minute." % count}

static func saved_error(dto: Dictionary, seconds: int) -> String:
	var batches: Variant = dto.get("ammunition_recovery", [])
	if not batches is Array: return "ammunition recovery must be an array"
	var inventory: Variant = dto.get("inventory", {})
	if not inventory is Dictionary: return "ammunition owner inventory is malformed"
	var copies: Variant = inventory.get("copies", {})
	if not copies is Dictionary: return "ammunition owner copies are malformed"
	if not batches.is_empty() and (not copies.get("inventory_id") is String or not whole(copies.get("next_id"), 1, -1)): return "ammunition owner identity is malformed"
	var seen := {}
	for batch in batches:
		if not batch is Dictionary or not batch.get("site") is String or str(batch.site).is_empty() or not whole(batch.get("spent_count"), 2) or not whole(batch.get("ended_at"), 0, -1) or int(batch.ended_at) > seconds or not batch.get("pieces") is Array: return "ammunition recovery batch is malformed"
		if batch.pieces.size() != floori(float(batch.spent_count) / 2.0): return "ammunition recovery count differs from spent pieces"
		for piece in batch.pieces:
			if not piece is Dictionary or not piece.get("instance_id") is String or str(piece.instance_id).is_empty() or not piece.get("state") is Dictionary: return "ammunition recovery copy is malformed"
			if piece.state.has("contents") or piece.state.has("attached"): return "ammunition recovery piece cannot hold other copies"
			var definition := DataLoader.get_item(str(piece.get("definition_id", "")))
			if definition.get("type") != "ammunition" or not definition.has("ammunition_kind") or not InventoryCopies.record_state_error(piece).is_empty(): return "ammunition recovery references an invalid piece"
			var prefix := str(copies.get("inventory_id", "")) + ":"
			if str(piece.instance_id).begins_with(prefix) and str(piece.instance_id).get_slice(":", 1).to_int() >= int(copies.get("next_id", 0)): return "ammunition recovery would reuse an inventory serial"
			if seen.has(piece.instance_id): return "ammunition recovery duplicates a copy"
			seen[piece.instance_id] = true
	return ""

static func copy_ids(dto: Dictionary) -> Array:
	var result := []
	for batch in dto.get("ammunition_recovery", []):
		for piece in batch.pieces: result.append(piece.instance_id)
	return result
