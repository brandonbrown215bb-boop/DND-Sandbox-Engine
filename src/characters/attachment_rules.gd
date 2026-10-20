class_name AttachmentRules
extends RefCounted
## S-210 attached exact child copies and required sets.
## A host declares attachments {sockets:[{id, item_types?, accepts?}], sets:[{id, requires, benefits}]}.
## Each attached child keeps its own identity and state in host.state.attached[socket].
## A set's benefits apply only while the host is equipped and every required socket
## is filled; removing one part disables only the sets that require that socket.

static func policy_error(policy: Variant) -> String:
	if not policy is Dictionary or policy.keys().any(func(k): return str(k) not in ["sockets", "sets"]): return "attachment policy is invalid"
	var sockets: Variant = policy.get("sockets")
	if not sockets is Array or sockets.is_empty(): return "attachment policy needs sockets"
	var ids := {}
	for s in sockets:
		if not s is Dictionary or s.keys().any(func(k): return str(k) not in ["id", "item_types", "accepts"]): return "attachment socket is invalid"
		var id := str(s.get("id", ""))
		if id.is_empty() or ids.has(id): return "attachment socket ids must be unique"
		ids[id] = true
		for k in ["item_types", "accepts"]:
			if s.has(k) and (not s[k] is Array or s[k].is_empty() or s[k].any(func(t): return not t is String)): return "attachment socket %s is invalid" % k
		if not s.has("item_types") and not s.has("accepts"): return "attachment socket must declare what it accepts"
	var set_ids := {}
	for set in policy.get("sets", []):
		if not set is Dictionary or set.keys().any(func(k): return str(k) not in ["id", "requires", "benefits"]): return "attachment set is invalid"
		if str(set.get("id", "")).is_empty() or set_ids.has(str(set.id)): return "attachment set ids must be unique"
		set_ids[str(set.id)] = true
		if not set.get("requires") is Array or set.requires.is_empty() or set.requires.any(func(r): return not ids.has(str(r))): return "attachment set requires undeclared sockets"
		var benefit_error := SourceBenefitRules.benefits_error(set.get("benefits"))
		if not benefit_error.is_empty(): return "attachment set " + benefit_error
	return ""

static func policy(definition_id: String) -> Dictionary:
	var p: Variant = DataLoader.get_item(definition_id).get("attachments", {})
	return p if p is Dictionary else {}

static func is_host(definition_id: String) -> bool:
	return not policy(definition_id).get("sockets", []).is_empty()

static func _socket(definition_id: String, socket_id: String) -> Dictionary:
	for s in policy(definition_id).get("sockets", []):
		if str(s.id) == socket_id: return s
	return {}

## Exact attached child records keyed by socket.
static func attached(inventory: Inventory, host_id: String) -> Dictionary:
	var a: Variant = inventory.get_instance(host_id).get("state", {}).get("attached", {})
	return a if a is Dictionary else {}

static func attach_error(inventory: Inventory, host_id: String, child_id: String, socket_id: String) -> String:
	if inventory == null or not inventory.owned_instances().any(func(c): return str(c.instance_id) == host_id): return "Carry or wear that item to attach parts to it."
	var host := inventory.get_instance(host_id)
	var socket := _socket(str(host.get("definition_id", "")), socket_id)
	if socket.is_empty(): return "That item has no such socket."
	if attached(inventory, host_id).has(socket_id): return "That socket is already filled."
	if child_id == host_id or child_id not in inventory.backpack_instances().map(func(c): return str(c.instance_id)): return "Only an unequipped carried copy can be attached."
	var child := inventory.get_instance(child_id)
	var state: Dictionary = child.get("state", {})
	var definition := str(child.definition_id)
	if bool(state.get("cursed_attunement", false)) or state.has("attuned_to"): return "An attuned copy cannot be attached."
	if state.has("contents") or state.has("attached") or is_host(definition) or ContainerRules.is_container(definition): return "Containers and hosts cannot be attached."
	if ContainerRules._bonded(inventory, child_id): return "A bonded copy cannot be attached."
	if socket.has("accepts") and definition not in socket.accepts: return "That socket does not accept this item."
	if socket.has("item_types") and str(DataLoader.get_item(definition).get("type", "")) not in socket.item_types: return "That socket does not accept this kind of item."
	return ""

static func attach(inventory: Inventory, host_id: String, child_id: String, socket_id: String) -> Dictionary:
	var error := attach_error(inventory, host_id, child_id, socket_id)
	if not error.is_empty(): return {"success": false, "message": error}
	var record := inventory.take_instance(child_id)
	if record.is_empty(): return {"success": false, "message": "That copy cannot be attached."}
	inventory.copies.sync(inventory)
	var host: Dictionary = inventory.copies.records[host_id]
	var a: Dictionary = host.state.get("attached", {})
	a[socket_id] = record
	host.state["attached"] = a
	return {"success": true, "instance_id": child_id, "socket": socket_id, "seconds": 6, "message": "%s attached to %s." % [DataLoader.get_item(str(record.definition_id)).get("name", "Part"), DataLoader.get_item(str(host.definition_id)).get("name", "the item")]}

static func detach(inventory: Inventory, host_id: String, socket_id: String) -> Dictionary:
	if inventory == null or not inventory.owned_instances().any(func(c): return str(c.instance_id) == host_id): return {"success": false, "message": "Carry or wear that item to detach parts."}
	inventory.copies.sync(inventory)
	var host: Dictionary = inventory.copies.records[host_id]
	var a: Dictionary = host.state.get("attached", {})
	if not a.has(socket_id): return {"success": false, "message": "That socket is empty."}
	if inventory.backpack.size() >= Inventory.MAX_BACKPACK_SIZE: return {"success": false, "message": "The backpack is full."}
	var record: Dictionary = a[socket_id]
	a.erase(socket_id)
	if a.is_empty(): host.state.erase("attached")
	if not inventory.receive_instance(record):
		a[socket_id] = record
		host.state["attached"] = a
		return {"success": false, "message": "That part cannot return to the backpack."}
	return {"success": true, "instance_id": str(record.instance_id), "socket": socket_id, "seconds": 6, "message": "%s detached." % DataLoader.get_item(str(record.definition_id)).get("name", "Part")}

## HUD: attach the selected copy to the first carried or worn host socket that accepts it.
static func attach_any(inventory: Inventory, child_id: String) -> Dictionary:
	var reason := "No carried item has a socket for that copy."
	for host in inventory.owned_instances():
		for s in policy(str(host.definition_id)).get("sockets", []):
			var error := attach_error(inventory, str(host.instance_id), child_id, str(s.id))
			if error.is_empty(): return attach(inventory, str(host.instance_id), child_id, str(s.id))
			if str(host.instance_id) != child_id: reason = error
	return {"success": false, "message": reason}

## HUD: detach the most recently filled socket of the selected host.
static func detach_last(inventory: Inventory, host_id: String) -> Dictionary:
	var a := attached(inventory, host_id)
	if a.is_empty(): return {"success": false, "message": "Nothing is attached."}
	return detach(inventory, host_id, str(a.keys()[a.size() - 1]))

## Completed sets on one exact host copy: [{set_id, benefits}].
static func complete_sets(host: Dictionary) -> Array:
	var result: Array = []
	var a: Variant = host.get("state", {}).get("attached", {})
	if not a is Dictionary: return result
	for set in policy(str(host.get("definition_id", ""))).get("sets", []):
		if set.requires.all(func(r): return a.has(str(r))): result.append({"set_id": str(set.id), "benefits": set.benefits})
	return result

static func attached_ids(inventory_dto: Dictionary) -> Array:
	var ids: Array = []
	var records: Variant = inventory_dto.get("copies", {}).get("records", {})
	if not records is Dictionary: return ids
	for record in records.values():
		var a: Variant = record.get("state", {}).get("attached", {}) if record is Dictionary and record.get("state") is Dictionary else {}
		if a is Dictionary:
			for child in a.values(): if child is Dictionary: ids.append(str(child.get("instance_id", "")))
	return ids

static func saved_error(dto: Dictionary) -> String:
	var copies: Variant = dto.get("inventory", {}).get("copies", {})
	if not copies is Dictionary or not copies.get("records") is Dictionary: return ""
	var seen := {}
	for id in copies.records: seen[str(id)] = true
	for id in ContainerRules.content_ids(dto.get("inventory", {})): seen[str(id)] = true
	var prefix := str(copies.get("inventory_id", "")) + ":"
	for record in copies.records.values():
		if not record is Dictionary or not record.get("state") is Dictionary or not record.state.has("attached"): continue
		var a: Variant = record.state.attached
		var definition := str(record.get("definition_id", ""))
		if not is_host(definition): return "saved attachments are held by a non-host"
		if not a is Dictionary or a.is_empty(): return "saved attachments are malformed"
		for socket_id in a:
			var socket := _socket(definition, str(socket_id))
			var child: Variant = a[socket_id]
			if socket.is_empty(): return "saved attachment uses an undeclared socket"
			if not child is Dictionary or not child.get("instance_id") is String or not child.get("state") is Dictionary or DataLoader.get_item(str(child.get("definition_id", ""))).is_empty(): return "saved attached copy is malformed"
			var cid := str(child.instance_id)
			if seen.has(cid): return "saved attached copy duplicates an identity"
			seen[cid] = true
			if cid.begins_with(prefix) and cid.get_slice(":", 1).to_int() >= int(copies.get("next_id", 0)): return "inventory serial would reuse an identity"
			var cdef := str(child.definition_id)
			if child.state.has("attached") or child.state.has("contents") or child.state.has("attuned_to") or is_host(cdef) or ContainerRules.is_container(cdef): return "saved attached copy is not a plain part"
			if socket.has("accepts") and cdef not in socket.accepts: return "saved attachment does not fit its socket"
			if socket.has("item_types") and str(DataLoader.get_item(cdef).get("type", "")) not in socket.item_types: return "saved attachment does not fit its socket"
	return ""
