class_name ContainerRules
extends RefCounted
## S-196 exact item contents in declared compartments.
## A carried container copy keeps actual child copies (identity and state) in
## state.contents[compartment_id]. Insertion and removal validate everything
## before anything moves; contents are saved with the container record.

const KEYS := ["id", "item_types", "max_count", "max_weight", "max_volume"]

static func policy_error(policy: Variant) -> String:
	if not policy is Dictionary or policy.keys().any(func(k): return str(k) != "compartments"): return "container policy is invalid"
	var comps: Variant = policy.get("compartments")
	if not comps is Array or comps.is_empty(): return "container policy needs compartments"
	var ids := {}
	for c in comps:
		if not c is Dictionary or c.keys().any(func(k): return str(k) not in KEYS): return "container compartment is invalid"
		var id := str(c.get("id", ""))
		if id.is_empty() or ids.has(id): return "container compartment ids must be unique"
		ids[id] = true
		if c.has("item_types") and (not c.item_types is Array or c.item_types.is_empty() or c.item_types.any(func(t): return not t is String)): return "container item_types are invalid"
		if not _positive(c.get("max_count"), true): return "container compartment needs a whole max_count"
		for k in ["max_weight", "max_volume"]:
			if c.has(k) and not _positive(c[k], false): return "container %s is invalid" % k
	return ""

static func _positive(v: Variant, whole: bool) -> bool:
	return (v is int or v is float) and is_finite(float(v)) and float(v) > 0.0 and (not whole or float(v) == floorf(float(v)))

## Declared compartments of a definition: id -> compartment.
static func compartments(definition_id: String) -> Dictionary:
	var result := {}
	var policy: Variant = DataLoader.get_item(definition_id).get("container", {})
	if policy is Dictionary:
		for c in policy.get("compartments", []): result[str(c.id)] = c
	return result

static func is_container(definition_id: String) -> bool:
	return not compartments(definition_id).is_empty()

## Exact child records, optionally limited to one compartment.
static func contents(inventory: Inventory, container_id: String, compartment: String = "") -> Array:
	var all: Variant = inventory.get_instance(container_id).get("state", {}).get("contents", {})
	var result: Array = []
	if not all is Dictionary: return result
	for key in all:
		if compartment.is_empty() or str(key) == compartment: result.append_array(all[key])
	return result

static func _owned(inventory: Inventory, id: String) -> bool:
	return inventory.owned_instances().any(func(c): return str(c.instance_id) == id)

static func _bonded(inventory: Inventory, id: String) -> bool:
	var actor = inventory.owner_character_ref.get_ref() if inventory.owner_character_ref != null else null
	if not actor is Character: return false
	for state in actor.exclusive_bonds.values():
		if state.get("targets", []).any(func(e): return str(e.get("target_id", "")) == id): return true
	return false

static func _fits(compartment: Dictionary, existing: Array, definition_id: String) -> String:
	var item := DataLoader.get_item(definition_id)
	if compartment.has("item_types") and str(item.get("type", "")) not in compartment.item_types: return "That compartment does not hold this kind of item."
	if existing.size() + 1 > int(compartment.max_count): return "That compartment is full."
	for pair in [["max_weight", "weight"], ["max_volume", "volume"]]:
		if not compartment.has(pair[0]): continue
		if not item.has(pair[1]): return "This item has no recorded %s, so it cannot be measured into that compartment." % pair[1]
		var total := float(item[pair[1]])
		for child in existing: total += float(DataLoader.get_item(str(child.definition_id)).get(pair[1], 0.0))
		if total > float(compartment[pair[0]]) + 0.00001: return "That would exceed the compartment's %s limit." % pair[1]
	return ""

static func put_error(inventory: Inventory, container_id: String, child_id: String, compartment: String) -> String:
	if inventory == null or not _owned(inventory, container_id): return "Carry that container to use it."
	var comps := compartments(str(inventory.get_instance(container_id).get("definition_id", "")))
	if comps.is_empty(): return "That item is not a container."
	if not comps.has(compartment): return "That container has no such compartment."
	if child_id == container_id: return "A container cannot hold itself."
	if child_id not in inventory.backpack_instances().map(func(c): return str(c.instance_id)): return "Only an unequipped carried copy can be stowed."
	var child := inventory.get_instance(child_id)
	var state: Dictionary = child.get("state", {})
	if bool(state.get("cursed_attunement", false)): return "A cursed copy cannot leave its holder."
	if state.has("attuned_to"): return "End attunement before stowing that copy."
	if is_container(str(child.definition_id)): return "Nested containers are not supported."
	if _bonded(inventory, child_id): return "A bonded copy stays in hand; stowing bonded copies is not supported."
	return _fits(comps[compartment], contents(inventory, container_id, compartment), str(child.definition_id))

## Move the exact carried copy into the container compartment.
static func put(inventory: Inventory, container_id: String, child_id: String, compartment: String) -> Dictionary:
	var error := put_error(inventory, container_id, child_id, compartment)
	if not error.is_empty(): return {"success": false, "message": error}
	var record := inventory.take_instance(child_id)
	if record.is_empty(): return {"success": false, "message": "That copy cannot be stowed."}
	var host := inventory.get_instance(container_id)
	var all: Dictionary = host.state.get("contents", {})
	var list: Array = all.get(compartment, [])
	list.append(record)
	all[compartment] = list
	host.state["contents"] = all
	if not inventory.update_instance(host):
		inventory.receive_instance(record)
		return {"success": false, "message": "That container could not be updated."}
	return {"success": true, "instance_id": child_id, "container_id": container_id, "compartment": compartment, "seconds": 6, "message": "%s stowed in %s." % [DataLoader.get_item(str(record.definition_id)).get("name", "Item"), DataLoader.get_item(str(host.definition_id)).get("name", "the container")]}

## Return the exact contained copy to the backpack.
static func remove(inventory: Inventory, container_id: String, child_id: String) -> Dictionary:
	if inventory == null or not _owned(inventory, container_id): return {"success": false, "message": "Carry that container to use it."}
	var host := inventory.get_instance(container_id)
	var all: Dictionary = host.state.get("contents", {})
	for key in all:
		var list: Array = all[key]
		for i in list.size():
			if str(list[i].get("instance_id", "")) != child_id: continue
			if inventory.backpack.size() >= Inventory.MAX_BACKPACK_SIZE: return {"success": false, "message": "The backpack is full."}
			var record: Dictionary = list[i]
			list.remove_at(i)
			if list.is_empty(): all.erase(key)
			else: all[key] = list
			if all.is_empty(): host.state.erase("contents")
			else: host.state["contents"] = all
			if not inventory.update_instance(host): return {"success": false, "message": "That container could not be updated."}
			if not inventory.receive_instance(record):
				var restored := inventory.get_instance(container_id)
				var back: Dictionary = restored.state.get("contents", {})
				var again: Array = back.get(key, [])
				again.insert(i, record)
				back[key] = again
				restored.state["contents"] = back
				inventory.update_instance(restored)
				return {"success": false, "message": "That copy cannot return to the backpack."}
			return {"success": true, "instance_id": child_id, "seconds": 6, "message": "%s taken out." % DataLoader.get_item(str(record.definition_id)).get("name", "Item")}
	return {"success": false, "message": "That container does not hold that copy."}

## HUD: stow the selected copy in the first carried container compartment that accepts it.
static func stow(inventory: Inventory, child_id: String) -> Dictionary:
	var reason := "No carried container can hold that copy."
	for host in inventory.owned_instances():
		var comps := compartments(str(host.definition_id))
		for key in comps:
			var error := put_error(inventory, str(host.instance_id), child_id, str(key))
			if error.is_empty(): return put(inventory, str(host.instance_id), child_id, str(key))
			if str(host.instance_id) != child_id: reason = error
	return {"success": false, "message": reason}

## HUD: take the most recently stowed copy out of the selected container.
static func retrieve_last(inventory: Inventory, container_id: String) -> Dictionary:
	var held := contents(inventory, container_id)
	if held.is_empty(): return {"success": false, "message": "That container is empty."}
	return remove(inventory, container_id, str(held[held.size() - 1].instance_id))

## Ids of copies held inside an inventory DTO's containers.
static func content_ids(inventory_dto: Dictionary) -> Array:
	var ids: Array = []
	var records: Variant = inventory_dto.get("copies", {}).get("records", {})
	if not records is Dictionary: return ids
	for record in records.values():
		var all: Variant = record.get("state", {}).get("contents", {}) if record is Dictionary and record.get("state") is Dictionary else {}
		if all is Dictionary:
			for list in all.values():
				if list is Array:
					for child in list: if child is Dictionary: ids.append(str(child.get("instance_id", "")))
	return ids

static func saved_error(dto: Dictionary) -> String:
	var copies: Variant = dto.get("inventory", {}).get("copies", {})
	if not copies is Dictionary or not copies.get("records") is Dictionary: return ""
	var seen := {}
	for id in copies.records: seen[str(id)] = true
	var prefix := str(copies.get("inventory_id", "")) + ":"
	for record in copies.records.values():
		if not record is Dictionary or not record.get("state") is Dictionary or not record.state.has("contents"): continue
		var comps := compartments(str(record.get("definition_id", "")))
		var all: Variant = record.state.contents
		if comps.is_empty(): return "saved contents are held by a non-container"
		if not all is Dictionary or all.is_empty(): return "saved container contents are malformed"
		for key in all:
			if not comps.has(str(key)): return "saved contents use an undeclared compartment"
			var list: Variant = all[key]
			if not list is Array or list.is_empty(): return "saved compartment contents are malformed"
			var placed: Array = []
			for child in list:
				if not child is Dictionary or not child.get("instance_id") is String or not child.get("state") is Dictionary or DataLoader.get_item(str(child.get("definition_id", ""))).is_empty(): return "saved contained copy is malformed"
				var cid := str(child.instance_id)
				if seen.has(cid): return "saved contained copy duplicates an identity"
				seen[cid] = true
				if cid.begins_with(prefix) and cid.get_slice(":", 1).to_int() >= int(copies.get("next_id", 0)): return "inventory serial would reuse an identity"
				if child.state.has("contents") or is_container(str(child.definition_id)): return "saved contents nest a container"
				if bool(child.state.get("cursed_attunement", false)) or child.state.has("attuned_to"): return "saved contained copy is attuned"
				var error := _fits(comps[str(key)], placed, str(child.definition_id))
				if not error.is_empty(): return "saved contents exceed their compartment"
				placed.append(child)
	return ""
