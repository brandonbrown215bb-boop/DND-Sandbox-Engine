## Located source-end children for shared spell records and self activation modes.
## Room records own the durable receipt; the bounded diagnostic event ring does not.
class_name LocatedSourceEndRules
extends RefCounted

static var combat_areas: WeakRef
const CHILD_TYPES := ["heal", "room_object", "room_area"]

static func children_error(entry: Dictionary) -> String:
	for key in entry:
		if key not in ["id", "reasons", "children", "cancel_policy", "delay_seconds"]: return "Unsupported located aftermath field: %s" % key
	if entry.get("cancel_policy") not in ["skip", "stop"]: return "Located aftermath needs skip/stop cancel_policy"
	if not SourceEndAftermathRules._int(entry.get("delay_seconds", 0), 0, 86400): return "Invalid aftermath delay_seconds"
	var children: Variant = entry.get("children")
	if not children is Array or children.is_empty() or children.size() > 12: return "Located aftermath needs 1-12 children"
	var ids := {}
	for child in children:
		if not child is Dictionary or not child.get("id") is String or str(child.id).is_empty() or ids.has(child.id): return "Aftermath children need distinct ids"
		ids[child.id] = true
		if child.get("type") not in CHILD_TYPES: return "Unsupported source-end child producer/type"
		var fields := ["id", "type", "choose", "amount"] if child.type == "heal" else ["id", "type", "choose", "kind", "name", "hp"] if child.type == "room_object" else ["id", "type", "choose", "kind", "amount", "damage_type", "radius_hexes", "duration_seconds", "trigger_limit", "trigger_scope"]
		for key in child:
			if key not in fields: return "Unsupported source-end child field: %s" % key
		if child.has("choose") and not child.choose is bool: return "Child choose must be boolean"
		match str(child.type):
			"heal":
				if not SourceEndAftermathRules._int(child.get("amount"), 1, 1000): return "Invalid child healing"
			"room_object":
				if child.get("kind") != "loose" or not child.get("name") is String or str(child.name).is_empty() or not SourceEndAftermathRules._int(child.get("hp"), 1, 1000): return "Only loose room-object successors are supported"
			"room_area":
				if child.get("kind") != "entry_damage" or child.get("trigger_scope") != "entry": return "Only entry-scoped damage hazards are supported"
				if not SourceEndAftermathRules._int(child.get("amount"), 1, 1000) or child.get("damage_type") not in DataLoader.VALID_DAMAGE_TYPES: return "Invalid hazard damage"
				if not SourceEndAftermathRules._int(child.get("radius_hexes"), 0, 20) or not SourceEndAftermathRules._int(child.get("duration_seconds"), 1, 86400) or not SourceEndAftermathRules._int(child.get("trigger_limit"), 1, 100): return "Invalid hazard limits"
	return ""

static func has_children(entries: Array) -> bool:
	return entries.any(func(entry): return entry is Dictionary and entry.has("children"))

static func current_room() -> Dictionary:
	var room := LocalRoomCombat.room()
	if not room.is_empty(): return room
	var dungeon: Dictionary = GameManager.active_dungeon_state
	return dungeon.get("local_rooms", {}).get(str(dungeon.get("local_room_id", "")), {})

static func next_mode_serial(actor_id: String, feature_id: String, proposed: int) -> int:
	var serial := proposed
	for room in GameManager.saved_local_room_states():
		for pending in room.get("source_end_continuations", {}).values():
			var event: Dictionary = pending.event
			if event.source_kind == "mode" and event.caster_id == actor_id and event.definition_id == feature_id:
				serial = maxi(serial, int(event.record.mode_state.activation_serial) + 1)
	return serial

## Read live positions once, before condition cleanup/reversion/removal.
static func capture(target, record: Dictionary, reason: String, cause: Dictionary = {}, final_location_override: Dictionary = {}) -> Dictionary:
	var room := current_room()
	var context := {"room": room, "plane": PhysicalFactsRules.get_plane(room)}
	if GameManager.current_state == GameManager.GameState.COMBAT:
		var areas = combat_areas.get_ref() if combat_areas != null else null
		if areas != null: context["players"] = areas.player_entities
	elif target is Character:
		var positions: Dictionary = room.get("party_positions", {})
		if positions.has(target.character_id): context["players"] = [{"character": target, "hex_position": LocalRoomRules.coord(positions[target.character_id]), "altitude_feet": LocalRoomRules.altitude_feet(room, target.character_id)}]
		elif room.get("created_actor_positions", {}).has(target.character_id): context["players"] = [{"character": target, "hex_position": LocalRoomRules.coord(room.created_actor_positions[target.character_id]), "altitude_feet": LocalRoomRules.altitude_feet(room, target.character_id)}]
	var location := PhysicalFactsRules.get_location(target, context)
	if not final_location_override.is_empty(): location = final_location_override.duplicate(true)
	if location.position is Vector2i: location.position = [location.position.x, location.position.y]
	location["room_id"] = str(location.get("room_id", room.get("id", "")))
	return {"source_id": str(record.get("source_id", "")), "source_kind": str(record.get("source_kind", "spell")), "definition_id": str(record.get("definition_id", record.get("spell_id", ""))), "spell_id": str(record.get("spell_id", "")), "caster_id": str(record.get("caster_id", "")), "recipient_id": str(record.get("recipient_id", SourceEndAftermathRules._id(target))), "subject_id": SourceEndAftermathRules._id(target), "end_reason": reason, "ended_at_seconds": int(GameManager.campaign_elapsed_seconds), "final_location": location, "cause": cause.duplicate(true), "record": record.duplicate(true)}

static func host_error(target, entries: Array) -> String:
	if not has_children(entries): return ""
	var location: Dictionary = capture(target, {}, "").final_location
	if not location.location_known or str(location.room_id).is_empty(): return "Located aftermath requires a represented room recipient"
	return ""

static func enqueue(event: Dictionary) -> void:
	if not has_children(event.record.get("end_aftermath", [])): return
	var room := current_room()
	var location: Dictionary = event.final_location
	if str(room.get("id", "")) != str(location.room_id):
		for candidate in GameManager.saved_local_room_states():
			if str(candidate.get("id", "")) == str(location.room_id): room = candidate; break
	if room.is_empty() or not location.location_known or str(location.room_id) != str(room.get("id", "")):
		event["continuation_refusal"] = "unrepresented_end_location"
		return
	var queue: Dictionary = room.get("source_end_continuations", {})
	for entry in event.record.get("end_aftermath", []):
		if not entry.has("children") or event.end_reason not in entry.reasons: continue
		var id := "source-end:" + JSON.stringify([event.source_id, event.recipient_id, entry.id])
		if queue.has(id): continue
		var pending := CombatChildActions.continuation(id, entry.children, str(entry.cancel_policy))
		pending["event"] = event.duplicate(true)
		pending["aftermath_id"] = str(entry.id)
		pending["due_at_seconds"] = int(event.ended_at_seconds) + int(entry.get("delay_seconds", 0))
		queue[id] = pending
	room["source_end_continuations"] = queue

## Automatic children run in order. Chosen children yield an exact request token.
## No target/location is recaptured when a timer or a choice resumes.
static func observe(room: Dictionary, party: Array) -> Array[Dictionary]:
	var requests: Array[Dictionary] = []
	for pending in room.get("source_end_continuations", {}).values():
		if int(pending.due_at_seconds) > int(GameManager.campaign_elapsed_seconds): continue
		while not pending.remaining.is_empty():
			if pending.current.is_empty(): CombatChildActions.select_child(pending, str(pending.remaining[0].id))
			if bool(pending.current.get("choose", false)):
				requests.append({"invocation": pending.invocation, "child_id": pending.current.id})
				break
			var result := _execute(room, pending, party)
			if not result.get("success", false):
				pending.current = {} # Retry automatic children later without blocking checkpoints.
				break
			_settle(pending, result)
	return requests

static func answer(room: Dictionary, invocation: String, child_id: String, accept: bool, party: Array) -> Dictionary:
	var pending: Dictionary = room.get("source_end_continuations", {}).get(invocation, {})
	if pending.is_empty() or str(pending.get("current", {}).get("id", "")) != child_id or not bool(pending.current.get("choose", false)) or bool(pending.settled): return {"success": false, "reason": "stale_child"}
	if accept:
		var result := _execute(room, pending, party)
		if not result.get("success", false): return result
		_settle(pending, result)
	else:
		pending.receipts.append({"child_id": child_id, "canceled": true})
		CombatChildActions.cancel_continuation(pending, str(pending.cancel_policy))
	observe(room, party)
	return {"success": true}

static func _settle(pending: Dictionary, result: Dictionary) -> void:
	result["child_id"] = str(pending.current.id)
	pending.receipts.append(result)
	pending.settled = true
	CombatChildActions.finish_child(pending)

static func _execute(room: Dictionary, pending: Dictionary, party: Array) -> Dictionary:
	var child: Dictionary = pending.current
	var event: Dictionary = pending.event
	var location: Dictionary = event.final_location
	if str(location.room_id) != str(room.get("id", "")): return {"success": false, "reason": "wrong_room"}
	var successor := str(pending.invocation) + ":child:" + str(child.id)
	match str(child.type):
		"heal":
			for actor in party:
				if actor is Character and actor.character_id == str(event.recipient_id): return {"success": true, "healed": actor.heal(int(child.amount))}
			return {"success": false, "reason": "recipient_unavailable"}
		"room_object":
			return LocalRoomRules.add_aftermath_object(room, successor, child, event)
		"room_area":
			return LocalRoomAreas.add_aftermath_area(room, successor, child, event)
	return {"success": false, "reason": "unsupported_child"}

static func pending_choice(room: Dictionary) -> bool:
	for pending in room.get("source_end_continuations", {}).values():
		if not pending.get("current", {}).is_empty(): return true
	return false

## Validate durable receipts against the declared producer, including completed
## children. Neither a forged cursor nor a changed producer can replay a child.
static func saved_error(room: Dictionary) -> String:
	var queue: Variant = room.get("source_end_continuations", {})
	if not queue is Dictionary: return "source-end continuations must be an object"
	for id in queue:
		var p: Variant = queue[id]
		if not p is Dictionary or not p.get("event") is Dictionary: return "invalid source-end continuation"
		var e: Dictionary = p.event
		if e.get("source_kind") not in ["spell", "mode", "item_copy", "created_actor"] or not e.get("record") is Dictionary: return "unsupported saved source-end producer"
		var entries: Variant = []
		if e.source_kind == "spell": entries = DataLoader.get_spell(str(e.get("definition_id", ""))).get("end_aftermath", [])
		elif e.source_kind == "mode" or e.source_kind == "item_copy" or e.source_kind == "created_actor": entries = e.record.get("end_aftermath", []) # Cross-checked against the pinned producer before load.
		if not SourceEndAftermathRules.validate(entries).is_empty() or e.record.get("end_aftermath", []) != entries: return "invalid saved source-end declaration"
		var entry := {}
		for candidate in entries:
			if candidate.id == p.get("aftermath_id", ""): entry = candidate
		if entry.is_empty() or not entry.has("children") or e.get("end_reason") not in entry.reasons: return "invalid saved source-end reason"
		if not e.get("source_id") is String or str(e.source_id).is_empty() or not e.get("recipient_id") is String or str(e.recipient_id).is_empty() or not e.get("caster_id") is String or str(e.caster_id).is_empty(): return "invalid source-end identity"
		if str(id) != "source-end:" + JSON.stringify([e.source_id, e.recipient_id, entry.id]) or p.get("invocation") != id or p.get("cancel_policy") != entry.cancel_policy: return "invalid source-end invocation"
		var loc: Variant = e.get("final_location")
		if not loc is Dictionary or not loc.get("location_known", false) or not DungeonPersistence.coordinate(loc.get("position")) or loc.get("room_id") != room.get("id") or not loc.get("plane") is String or str(loc.plane).is_empty(): return "invalid source-end location"
		if not room.cells.any(func(cell): return LocalRoomRules.coord(cell) == LocalRoomRules.coord(loc.position)): return "source-end location outside room"
		if not SourceEndAftermathRules._int(e.get("ended_at_seconds"), 0, 2147483647) or p.get("due_at_seconds") != int(e.ended_at_seconds) + int(entry.get("delay_seconds", 0)): return "invalid source-end timer"
		if not p.get("current") is Dictionary or not p.current.is_empty(): return "finish the source-end child decision before saving"
		if not p.get("remaining") is Array or not p.get("receipts") is Array or not p.get("settled") is bool: return "invalid source-end cursor"
		if p.receipts.size() > entry.children.size(): return "too many source-end child receipts"
		var stopped := false
		for index in p.receipts.size():
			var receipt: Variant = p.receipts[index]
			var child: Dictionary = entry.children[index]
			if stopped or not receipt is Dictionary or receipt.get("child_id") != child.id: return "invalid source-end child receipt/order"
			if receipt.get("canceled", false) == true:
				if not child.get("choose", false): return "unchosen child cannot be canceled"
				stopped = entry.cancel_policy == "stop"
			elif receipt.get("success") != true: return "unsettled source-end child receipt"
			elif child.type != "heal" and receipt.get("successor_id") != str(id) + ":child:" + str(child.id): return "invalid source-end successor identity"
		var expected: Array = [] if stopped else entry.children.slice(p.receipts.size())
		if p.remaining != expected: return "invalid source-end remaining children"
	return _world_links_error(room)

static func _world_links_error(room: Dictionary) -> String:
	for object in room.get("objects", []) + room.get("areas", []):
		if not object is Dictionary: continue # General room validation reports malformed rows.
		if not object.has("parent_source_id") and not object.has("hazard_kind"): continue
		var found := false
		for pending in room.get("source_end_continuations", {}).values():
			for index in pending.receipts.size():
				var receipt: Dictionary = pending.receipts[index]
				if receipt.get("successor_id", "") != object.get("id", ""): continue
				var child: Dictionary = {}
				for entry in pending.event.record.end_aftermath:
					if entry.id == pending.aftermath_id: child = entry.children[index]
				var loc: Dictionary = pending.event.final_location
				if object.get("parent_source_id") != pending.event.source_id or object.get("plane") != loc.plane: return "source-end successor provenance differs"
				if child.type == "room_object":
					if object.get("kind") != child.kind or object.get("name") != child.name or object.get("max_hp") != child.hp or LocalRoomRules.coord(object.get("position", [])) != LocalRoomRules.coord(loc.position): return "source-end object differs from its child"
				elif child.type == "room_area":
					for key in ["amount", "damage_type", "radius_hexes", "trigger_limit", "trigger_scope"]:
						if object.get(key) != child.get(key): return "source-end hazard differs from its child"
					if object.get("hazard_kind") != child.kind or LocalRoomRules.coord(object.get("center", [])) != LocalRoomRules.coord(loc.position): return "source-end hazard location/kind differs"
				else: return "source-end successor has no world child"
				found = true
		if not found: return "source-end successor has no settled child receipt"
	return ""

static func saved_producers_error(rooms: Array) -> String:
	for room in rooms:
		for pending in room.get("source_end_continuations", {}).values():
			var e: Dictionary = pending.event
			if e.record.get("source_id") != e.source_id or e.record.get("caster_id") != e.caster_id: return "source-end captured identity differs"
			if e.source_kind == "spell":
				if e.record.get("spell_id") != e.definition_id or not str(e.source_id).begins_with("spell:" + str(e.caster_id) + ":"): return "invalid spell end source"
				continue
			if e.source_kind == "item_copy":
				var producer_value: Variant = e.record.get("producer", {})
				if not producer_value is Dictionary: return "saved item-copy producer is malformed"
				var producer: Dictionary = producer_value
				var definition := DataLoader.get_item(str(producer.get("definition_id", "")))
				var policy: Dictionary = definition.get("actor_projection", {})
				var copy_record: Variant = producer.get("copy_record", {})
				if not copy_record is Dictionary or copy_record.get("instance_id") != producer.get("copy_id") or copy_record.get("definition_id") != producer.get("definition_id"): return "saved item-copy identity differs"
				if producer.get("kind") != "item_copy" or policy.get("end_aftermath", []) != e.record.get("end_aftermath", []) or producer.get("copy_id") != e.record.get("copy_id") or producer.get("owner_id") != e.caster_id or e.recipient_id != e.caster_id or e.subject_id != e.caster_id or not SourceEndAftermathRules._int(producer.get("activation_serial"), 1, 2147483647) or e.source_id != "item-form:" + JSON.stringify([e.caster_id, producer.get("copy_id"), int(producer.get("activation_serial", 0))]): return "saved item-copy end producer is not declared by its owner"
				continue
			if e.source_kind == "created_actor":
				var producer_value: Variant = e.record.get("producer", {})
				if not producer_value is Dictionary: return "saved created-actor producer is malformed"
				var producer: Dictionary = producer_value
				var spell := DataLoader.get_spell(str(producer.get("spell_id", "")))
				var effect := CreatedActorRules._effect(spell)
				var parent_source := str(producer.get("parent_source_id", ""))
				var actor_tail := str(producer.get("actor_id", "")).trim_prefix(parent_source + ":actor:")
				if producer.get("kind") != "created_actor" or effect.get("end_aftermath", []) != e.record.get("end_aftermath", []) or producer.get("actor_id") != e.source_id or producer.get("template_id") != e.record.get("template_id") or producer.get("spell_id") != e.definition_id or e.record.get("spell_id") != e.definition_id or e.record.get("parent_source_id") != parent_source or not parent_source.begins_with("spell:" + str(e.caster_id) + ":") or actor_tail == str(producer.get("actor_id", "")) or not actor_tail.is_valid_int() or e.recipient_id != e.caster_id or e.subject_id != e.caster_id: return "saved created-actor end producer is not declared by its owner"
				continue
			var producer: Variant = e.record.get("producer")
			if not producer is Dictionary or producer.get("kind") not in ["class", "subclass", "race", "feat"]: return "unsupported saved mode producer"
			var catalog: Dictionary = {"class": DataLoader.classes, "subclass": DataLoader.subclasses, "race": DataLoader.races, "feat": DataLoader.feats}[producer.kind]
			var rule := {}
			for feature in FeatureModeRules.aftermath_features(catalog.get(str(producer.get("id", "")), {})):
				if feature.get("id") == e.definition_id: rule = feature
			if rule.is_empty() or rule.get("end_aftermath", []) != e.record.get("end_aftermath", []) or e.recipient_id != e.caster_id: return "saved mode end producer is not declared by its owner"
			var state: Variant = e.record.get("mode_state")
			if not state is Dictionary or not state.get("active", false) or not SourceEndAftermathRules._int(state.get("activation_serial"), 1, 1000000): return "invalid captured mode state"
			if e.source_id != "mode:" + JSON.stringify([e.caster_id, e.definition_id, state.get("mode"), int(state.activation_serial)]): return "invalid mode end source"
			var end_on: Variant = e.record.get("end_on", [])
			if not FeatureModeRules.end_on_error(end_on).is_empty() or e.end_reason not in ["duration", "dismissed"] + end_on: return "invalid captured effective mode end reason"
	return ""
