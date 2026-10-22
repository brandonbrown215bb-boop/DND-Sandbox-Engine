## S-165: one exact owned item copy projects into a declared temporary actor.
## The copy leaves the inventory into the owner's projection record with its
## identity, state and contents intact, so it cannot be equipped, traded,
## spent or projected twice while the actor exists. Reversion returns that
## same copy; nothing is duplicated or recreated.
class_name ItemProjectionRules
extends RefCounted

const POLICY_KEYS := ["template"]
const RECORD_KEYS := ["copy", "actor"]

static var _live := {}

static func policy_error(policy: Variant) -> String:
	if not policy is Dictionary or policy.size() != 1 or not policy.has("template"): return "item actor_projection accepts only a template"
	var e := CreatedActorRules.template_error(policy.template)
	if not e.is_empty(): return "item actor_projection " + e
	if CreatedActorRules.value(policy.template.count, 0) != 1: return "item actor_projection projects exactly one actor"
	return ""

static func _policy(definition_id: String) -> Dictionary:
	var policy: Variant = DataLoader.get_item(definition_id).get("actor_projection", {})
	return policy if policy is Dictionary and policy_error(policy).is_empty() else {}

static func is_projected(owner, instance_id: String) -> bool:
	return owner is Character and owner.item_projections.has(instance_id)

static func actor_id(instance_id: String) -> String:
	return "%s:projected" % instance_id

static func project(owner: Character, instance_id: String) -> Dictionary:
	if owner == null: return {"projected": false, "reason": "No owner."}
	if is_projected(owner, instance_id): return {"projected": false, "reason": "That copy is already projected."}
	# Review 041 R1/R4: a form that blocks equipment refuses before any copy moves.
	if not ActorProjectionRules.equip_error(owner).is_empty(): return {"projected": false, "reason": ActorProjectionRules.equip_error(owner)}
	var copy := owner.inventory.get_instance(instance_id)
	if ActiveTimeRules.is_active(copy) or WorkRules.is_active(copy): return {"projected": false, "reason": "Pause active use and stop work before projecting that copy."}
	if copy.is_empty() or instance_id not in owner.inventory.backpack_instances().map(func(c): return str(c.instance_id)): return {"projected": false, "reason": "Carry that exact copy, unequipped, to project it."}
	var policy := _policy(str(copy.definition_id))
	if policy.is_empty(): return {"projected": false, "reason": "That copy declares no projection."}
	if bool(copy.get("state", {}).get("cursed_attunement", false)): return {"projected": false, "reason": "A cursed copy cannot leave its holder."}
	var maximum := CreatedActorRules.value(policy.template.max_hp, 0)
	owner.item_projections[instance_id] = {"copy": copy.duplicate(true), "actor": {"actor_id": actor_id(instance_id), "current_hp": maximum}}
	if owner.inventory.take_instance(instance_id).is_empty():
		owner.item_projections.erase(instance_id)
		return {"projected": false, "reason": "That copy cannot be released."}
	var a := actor(owner, instance_id)
	return {"projected": true, "instance_id": instance_id, "actor_id": a.character_id, "max_hp": a.max_hp, "ac": a.base_ac}

static func actor(owner: Character, instance_id: String) -> Character:
	if not is_projected(owner, instance_id): return null
	var record: Dictionary = owner.item_projections[instance_id]
	var policy := _policy(str(record.copy.get("definition_id", "")))
	if policy.is_empty(): return null
	var id := str(record.actor.actor_id)
	if not _live.has(id) or _live[id].get_meta("projection_owner_instance", 0) != owner.get_instance_id():
		var a := CreatedActorRules.instance(policy.template, 0, record.actor)
		a.set_meta("projection_owner_instance", owner.get_instance_id())
		a.set_meta("projection_owner_id", owner.character_id)
		a.set_meta("projected_item_id", instance_id)
		_live[id] = a
	return _live[id]

static func sync(owner: Character) -> void:
	for id in owner.item_projections:
		var a := actor(owner, str(id))
		if a != null: owner.item_projections[id].actor.current_hp = maxi(0, a.current_hp)

## Return the same copy to the owner's inventory; the actor ends.
static func revert(owner: Character, instance_id: String) -> Dictionary:
	if not is_projected(owner, instance_id): return {"reverted": false, "reason": "That copy is not projected."}
	var record: Dictionary = owner.item_projections[instance_id]
	if not owner.inventory.receive_instance(record.copy): return {"reverted": false, "reason": "There is no room to take the copy back."}
	owner.item_projections.erase(instance_id)
	_live.erase(str(record.actor.actor_id))
	return {"reverted": true, "instance_id": instance_id, "state": record.copy.get("state", {}).duplicate(true)}

## A projected actor at 0 HP reverts to its copy (overflow/reset is S-166).
static func settle(owner: Character) -> Array:
	var out: Array = []
	for id in owner.item_projections.keys():
		var a := actor(owner, str(id))
		if a != null and a.current_hp <= 0 and revert(owner, str(id)).get("reverted", false): out.append(str(id))
	return out

static func restore(owner: Character, data: Dictionary) -> void:
	owner.item_projections = data.get("item_projections", {}).duplicate(true) if data.get("item_projections", {}) is Dictionary else {}

static func saved_error(dto: Dictionary) -> String:
	var all: Variant = dto.get("item_projections", {})
	if not all is Dictionary: return "item projections are invalid"
	var copies: Dictionary = dto.get("inventory", {}).get("copies", {})
	var held: Dictionary = copies.get("records", {})
	# Validate the same exact records while projected as while carried. The
	# temporary inventory view also checks serials, nested state and attunements.
	var inventory: Dictionary = dto.get("inventory", {}).duplicate(true)
	if not all.is_empty() and (not copies.get("records") is Dictionary or not copies.get("backpack") is Array or not inventory.get("backpack") is Array): return "projected copy inventory is malformed"
	for id in all:
		var record: Variant = all[id]
		if not record is Dictionary or record.size() != 2 or not record.get("copy") is Dictionary or not record.get("actor") is Dictionary: return "item projection record is invalid"
		var copy: Dictionary = record.copy
		if str(copy.get("instance_id", "")) != str(id) or held.has(str(id)): return "projected copy is duplicated or misidentified"
		if not id is String or str(id).is_empty() or not copy.get("state") is Dictionary: return "projected copy is malformed"
		var policy := _policy(str(copy.get("definition_id", "")))
		if policy.is_empty(): return "projected copy declares no projection"
		if ActiveTimeRules.is_active(copy) or WorkRules.is_active(copy): return "projected copy must be paused and not worked on"
		var a: Dictionary = record.actor
		if a.size() != 2 or str(a.get("actor_id", "")) != actor_id(str(id)) or not CreatedActorRules._int(a.get("current_hp"), 0, CreatedActorRules.value(policy.template.max_hp, 0)): return "projected actor is invalid"
		inventory.copies.records[id] = copy.duplicate(true)
		inventory.copies.backpack.append(id)
		inventory.backpack.append(str(copy.definition_id))
	if all.is_empty(): return ""
	var error := InventoryCopies.saved_error(inventory)
	if not error.is_empty(): return "projected copy: " + error
	var combined := {"inventory": inventory}
	error = ContainerRules.saved_error(combined)
	if not error.is_empty(): return "projected copy: " + error
	error = AttachmentRules.saved_error(combined)
	if not error.is_empty(): return "projected copy: " + error
	return ""

static func copy_ids(dto: Dictionary) -> Array:
	var ids: Array = []
	for record in dto.get("item_projections", {}).values():
		var copy: Dictionary = record.get("copy", {})
		ids.append(str(copy.get("instance_id", "")))
		var inventory := {"copies": {"records": {str(copy.get("instance_id", "")): copy}}}
		ids.append_array(ContainerRules.content_ids(inventory))
		ids.append_array(AttachmentRules.attached_ids(inventory))
	return ids

## Combat host: living projected actors join their owner's side.
static func attach(state: Node, owner: Character, origin: Vector2i) -> Array:
	var joined: Array = []
	settle(owner) # Review 042 R1: destroyed projected actors revert before placement.
	for entity in state.player_entities.duplicate():
		var c = entity.get("character", null)
		if c is Character and c.has_meta("projected_item_id") and str(c.get_meta("projection_owner_id", "")) == owner.character_id and not is_projected(owner, str(c.get_meta("projected_item_id"))):
			state.player_entities.erase(entity)
			state.tracker.remove_combatant(c.character_id)
	for id in owner.item_projections:
		var a := actor(owner, str(id))
		if a == null or not a.is_alive or state.player_entities.any(func(e): return e.get("combat_id", "") == a.character_id): continue
		# Batch 053 S-122: the nearest legal adjacent space; none means it stays off the grid (never overlaps).
		var policy := _policy(str(owner.item_projections[id].copy.get("definition_id", "")))
		var hexes := PlacementRules.reserve(state, origin, str(policy.get("template", {}).get("size", "medium")), 1, 1)
		if hexes.is_empty(): continue
		state.player_entities.append({"name": a.character_name, "display_name": a.character_name, "character": a, "combat_id": a.character_id, "owner_player_index": -1, "hex_position": hexes[0], "is_created_actor": true, "created_owner_id": owner.character_id, "reaction_available": true, "color": Color(0.7, 0.6, 0.4)})
		joined.append(a.character_id)
	state._update_grid_entities()
	return joined
