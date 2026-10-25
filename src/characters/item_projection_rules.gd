## S-165: one exact owned item copy projects into a declared temporary actor.
## The copy leaves the inventory into the owner's projection record with its
## identity, state and contents intact, so it cannot be equipped, traded,
## spent or projected twice while the actor exists. Reversion returns that
## same copy; nothing is duplicated or recreated.
class_name ItemProjectionRules
extends RefCounted

const POLICY_KEYS := ["template", "reversion", "placement", "activation", "dismiss_cost", "end_aftermath", "vessel"]
const RECORD_KEYS := ["copy", "actor", "ending"]
const RETURN_KEYS := ["hp_reset", "overflow", "original_hp", "on_end", "on_zero_hp", "destination", "no_space", "range_hexes", "size"]

static var _live := {}
static var _combat_host: WeakRef

static func policy_error(policy: Variant) -> String:
	if not policy is Dictionary or not policy.has("template"): return "item actor_projection needs a template"
	for key in policy:
		if key not in POLICY_KEYS: return "Unknown item actor_projection field: " + str(key)
	var e := CreatedActorRules.template_error(policy.template)
	if not e.is_empty(): return "item actor_projection " + e
	if policy.has("end_aftermath"):
		var aftermath_error := SourceEndAftermathRules.validate(policy.end_aftermath)
		if not aftermath_error.is_empty(): return aftermath_error
	if CreatedActorRules.value(policy.template.count, 0) != 1: return "item actor_projection projects exactly one actor"
	if policy.has("vessel"):
		var vessel_error := VesselProjectionRules.policy_error(policy)
		if not vessel_error.is_empty(): return vessel_error
	if policy.has("placement") and not PlacementRules.policy_error(policy.placement).is_empty(): return PlacementRules.policy_error(policy.placement)
	if policy.has("dismiss_cost") and policy.dismiss_cost not in ["none", "action", "bonus_action", "magic"]: return "item dismiss_cost must be none, action, bonus_action or magic"
	if policy.has("activation"):
		var activation: Variant = policy.activation
		if not activation is Dictionary: return "item projection activation must be an object"
		for key in activation:
			if key not in ["action_cost", "charges", "bond_id"]: return "Unknown item projection activation field: " + str(key)
		if activation.get("action_cost", "none") not in ["none", "action", "bonus_action", "magic"]: return "item projection action_cost must be none, action, bonus_action or magic"
		if not CreatedActorRules._int(activation.get("charges", 0), 0, 1000000): return "item projection charges must be a nonnegative integer"
		if activation.has("bond_id") and (not activation.bond_id is String or activation.bond_id.is_empty()): return "item projection bond_id must be a nonempty string"
	if policy.has("reversion"):
		var r: Variant = policy.reversion
		if not r is Dictionary: return "item reversion must be an object"
		for key in r:
			if key not in RETURN_KEYS: return "Unknown item reversion field: " + str(key)
		if r.get("hp_reset") not in ["full", "preserve"]: return "item reversion needs full/preserve hp_reset"
		if r.get("overflow") not in ["discard", "original"]: return "item reversion needs discard/original overflow"
		if r.get("overflow") == "original" and not CreatedActorRules._int(r.get("original_hp"), 1, 1000000): return "original overflow needs original_hp"
		if r.has("original_hp") and r.overflow != "original": return "original_hp requires original overflow"
		if r.get("on_end") not in ["return", "destroy"] or r.get("on_zero_hp") not in ["return", "destroy"]: return "item reversion needs return/destroy ending policies"
		if r.get("destination") not in ["backpack", "ground", "backpack_or_ground"] or r.get("no_space") != "defer": return "item reversion needs a destination and no_space defer"
		if not CreatedActorRules._int(r.get("range_hexes"), 1, 24) or r.get("size") not in PhysicalFactsRules.VALID_SIZES: return "item reversion needs a supported size and range_hexes 1-24"
	return ""

## Legacy definitions keep their existing full-HP, backpack-only return.
static func return_policy(policy: Dictionary) -> Dictionary:
	return policy.get("reversion", {"hp_reset": "full", "overflow": "discard", "on_end": "return", "on_zero_hp": "return", "destination": "backpack", "no_space": "defer", "range_hexes": 1, "size": "tiny"})

static func _original_hp(copy: Dictionary, policy: Dictionary) -> int:
	return int(copy.state.get("combat_object_hp", copy.state.get("physical", {}).get("hp", policy.get("original_hp", 1))))

static func copy_error(copy: Dictionary) -> String:
	var state: Dictionary = copy.get("state", {})
	var policy := _policy(str(copy.get("definition_id", "")))
	if policy.is_empty(): return "item form state needs a declared projection" if state.has("item_form_hp") or state.has("item_form_serial") else ""
	if state.has("item_form_hp") and not CreatedActorRules._int(state.item_form_hp, 0, CreatedActorRules.value(policy.template.max_hp, 0)): return "invalid remembered item form HP"
	if state.has("item_form_serial") and not CreatedActorRules._int(state.item_form_serial, 1, 2147483647): return "invalid item form serial"
	var r := return_policy(policy)
	if r.overflow == "original":
		var physical: Variant = state.get("physical", {})
		if not physical is Dictionary or not CreatedActorRules._int(state.get("combat_object_hp", physical.get("hp", r.original_hp)), 0, int(r.original_hp)): return "invalid original item HP"
	return ""

static func _policy(definition_id: String) -> Dictionary:
	var policy: Variant = DataLoader.get_item(definition_id).get("actor_projection", {})
	return policy if policy is Dictionary and policy_error(policy).is_empty() else {}

static func is_projected(owner, instance_id: String) -> bool:
	return owner is Character and owner.item_projections.has(instance_id)

static func actor_id(instance_id: String) -> String:
	return "%s:projected" % instance_id

static func project_error(owner: Character, instance_id: String) -> String:
	if owner == null: return "No owner."
	if is_projected(owner, instance_id): return "That copy is already projected."
	# Review 041 R1/R4: a form that blocks equipment refuses before any copy moves.
	if not ActorProjectionRules.equip_error(owner).is_empty(): return ActorProjectionRules.equip_error(owner)
	var copy := owner.inventory.get_instance(instance_id)
	if ActiveTimeRules.is_active(copy) or WorkRules.is_active(copy): return "Pause active use and stop work before projecting that copy."
	if copy.is_empty() or instance_id not in owner.inventory.backpack_instances().map(func(c): return str(c.instance_id)): return "Carry that exact copy, unequipped, to project it."
	var policy := _policy(str(copy.definition_id))
	if policy.is_empty(): return "That copy declares no projection."
	if policy.has("vessel") and GameManager.current_state != GameManager.GameState.DUNGEON: return "Vessels require a represented local room."
	if policy.has("vessel"):
		var room_id := str(GameManager.active_dungeon_state.get("local_room_id", ""))
		var room: Dictionary = GameManager.active_dungeon_state.get("local_rooms", {}).get(room_id, {})
		if room.is_empty() or not ContainmentRules.relation(room, "character", owner.character_id).is_empty(): return "Vessel controls need an external owner in the current room."
	var aftermath_host_error := LocatedSourceEndRules.host_error(owner, policy.get("end_aftermath", []))
	if not aftermath_host_error.is_empty(): return aftermath_host_error
	if not copy_error(copy).is_empty(): return copy_error(copy)
	if return_policy(policy).overflow == "original" and _original_hp(copy, return_policy(policy)) <= 0: return "The original copy has no HP remaining."
	if bool(copy.get("state", {}).get("cursed_attunement", false)): return "A cursed copy cannot leave its holder."
	var maximum := CreatedActorRules.value(policy.template.max_hp, 0)
	var hp := maximum if return_policy(policy).hp_reset == "full" else int(copy.state.get("item_form_hp", maximum))
	if hp <= 0: return "That copy's form has no HP remaining."
	return ""

static func project(owner: Character, instance_id: String) -> Dictionary:
	var error := project_error(owner, instance_id)
	if not error.is_empty(): return {"projected": false, "reason": error}
	var copy := owner.inventory.get_instance(instance_id)
	var policy := _policy(str(copy.definition_id))
	var maximum := CreatedActorRules.value(policy.template.max_hp, 0)
	var hp := maximum if return_policy(policy).hp_reset == "full" else int(copy.state.get("item_form_hp", maximum))
	copy = copy.duplicate(true)
	# Only new declarations add a serial; legacy copy payloads remain unchanged.
	if policy.has("reversion") or policy.has("end_aftermath"): copy.state["item_form_serial"] = int(copy.state.get("item_form_serial", 0)) + 1
	owner.item_projections[instance_id] = {"copy": copy, "actor": {"actor_id": actor_id(instance_id), "current_hp": hp}}
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
	var live := _live
	if owner.get_meta("projection_validation", false):
		if not owner.has_meta("projection_validation_actors"): owner.set_meta("projection_validation_actors", {})
		live = owner.get_meta("projection_validation_actors")
	if not live.has(id) or live[id].get_meta("projection_owner_instance", 0) != owner.get_instance_id() or int(live[id].get_meta("projection_serial", 0)) != int(record.copy.state.get("item_form_serial", 0)):
		var a := CreatedActorRules.instance(policy.template, 0, record.actor)
		a.set_meta("projection_owner_instance", owner.get_instance_id())
		a.set_meta("projection_owner_id", owner.character_id)
		a.set_meta("projection_owner_ref", weakref(owner))
		a.set_meta("projection_serial", int(record.copy.state.get("item_form_serial", 0)))
		a.set_meta("projected_item_id", instance_id)
		if policy.has("vessel"): a.containment = policy.vessel.containment.duplicate(true)
		live[id] = a
	return live[id]

static func sync(owner: Character) -> void:
	for id in owner.item_projections:
		var a := actor(owner, str(id))
		if a != null: owner.item_projections[id].actor.current_hp = maxi(0, a.current_hp)

## End/retry the exact form. Callers retaining callbacks may pin its serial.
## A blocked voluntary end leaves the living form unchanged; a lethal end
## retains its settled damage and original copy until a legal return exists.
static func revert(owner: Character, instance_id: String, expected_serial: int = -1, end_reason: String = "dismissed", cause: Dictionary = {}) -> Dictionary:
	if not is_projected(owner, instance_id): return {"reverted": false, "reason": "That copy is not projected."}
	var record: Dictionary = owner.item_projections[instance_id]
	if expected_serial >= 0 and int(record.copy.state.get("item_form_serial", 0)) != expected_serial: return {"reverted": false, "reason": "That ending belongs to an earlier form."}
	var projection_policy := _policy(str(record.copy.definition_id))
	var policy := return_policy(projection_policy)
	var a := actor(owner, instance_id)
	var reason := "zero_hp" if a != null and a.current_hp <= 0 else end_reason
	var ending: Dictionary = record.get("ending", {"reason": reason, "overflow": 0, "location": _location(a), "cause": cause.duplicate(true)})
	var destroy := str(policy.on_zero_hp if ending.reason == "zero_hp" else policy.on_end) == "destroy"
	if policy.overflow == "original" and _original_hp(record.copy, policy) <= 0: destroy = true
	var vessel := VesselProjectionRules.prepare_end(owner, record, ending, destroy)
	if vessel.has("error"): return {"reverted": false, "pending": record.has("ending"), "reason": vessel.error}
	var plan := {"destination": "destroy"} if destroy else _return_plan(owner, record.copy, ending.location, policy, vessel.get("reserved", []))
	if plan.has("error"): return {"reverted": false, "pending": record.has("ending"), "reason": plan.error}
	if not vessel.is_empty() and plan.destination == "ground":
		var ground_id := str(LocalRoomRules.placed_item(plan.room, record.copy, plan.hex).id)
		var new_original := 1 if LocalRoomRules.get_object(plan.room, ground_id).is_empty() else 0
		if vessel.object_ids.has(ground_id):
			if plan.get("temporary_grid") != null: plan.temporary_grid.free()
			return {"reverted": false, "reason": "The original and released cargo claim the same ground identity."}
		if plan.room.objects.size() + int(vessel.new_objects) + new_original > 200:
			if plan.get("temporary_grid") != null: plan.temporary_grid.free()
			return {"reverted": false, "reason": "The room cannot hold all returned copies."}
	var vessel_error := VesselProjectionRules.confirm_end(vessel)
	if not vessel_error.is_empty():
		if plan.get("temporary_grid") != null: plan.temporary_grid.free()
		return {"reverted": false, "reason": vessel_error}
	var copy: Dictionary = record.copy.duplicate(true)
	if vessel.get("release_cargo", false): copy.state.erase("contents")
	if _policy(str(copy.definition_id)).has("reversion"):
		copy.state["item_form_hp"] = CreatedActorRules.value(_policy(str(copy.definition_id)).template.max_hp, 0) if policy.hp_reset == "full" else maxi(0, a.current_hp)
	if plan.destination == "backpack":
		if not owner.inventory.receive_instance(copy): return {"reverted": false, "reason": "There is no room to take the copy back."}
	elif plan.destination == "ground":
		# S-121: recheck the selected cell immediately before the exact copy moves.
		var error := PlacementRules.legal_error(plan.host, plan.origin, plan.hex, str(plan.get("size", policy.size)), int(policy.range_hexes), plan.get("reserved", []))
		if not error.is_empty():
			if plan.temporary_grid != null: plan.temporary_grid.free()
			return {"reverted": false, "reason": error}
		var placed := LocalRoomRules.placed_item(plan.room, copy, plan.hex)
		placed["plane"] = str(ending.location.plane)
		if vessel.get("retain_passengers", false): placed["containment"] = projection_policy.vessel.containment.duplicate(true)
		var old := LocalRoomRules.get_object(plan.room, str(placed.id))
		if old.is_empty(): plan.room.objects.append(placed)
		else:
			old.clear()
			old.merge(placed)
		if plan.temporary_grid != null: plan.temporary_grid.free()
	VesselProjectionRules.commit_end(vessel, plan, copy)
	var aftermath: Array = projection_policy.get("end_aftermath", [])
	var event := {}
	if not aftermath.is_empty():
		var serial := int(record.copy.get("state", {}).get("item_form_serial", 0))
		var producer := {"kind": "item_copy", "owner_id": owner.character_id, "copy_id": instance_id, "definition_id": str(record.copy.definition_id), "activation_serial": serial, "copy_record": record.copy.duplicate(true)}
		var source := "item-form:" + JSON.stringify([owner.character_id, instance_id, serial])
		var source_record := {"source_id": source, "source_kind": "item_copy", "definition_id": str(record.copy.definition_id), "caster_id": owner.character_id, "recipient_id": owner.character_id, "copy_id": instance_id, "end_aftermath": aftermath.duplicate(true), "producer": producer}
		var captured_location: Dictionary = LocatedSourceEndRules.capture(a if a != null else owner, {"source_id": source, "caster_id": owner.character_id}, str(ending.reason), ending.get("cause", cause)).final_location
		if ending.has("final_location"): captured_location = ending.final_location.duplicate(true)
		elif record.has("ending") and not ending.location.is_empty():
			# Legacy pending returns retained their room/hex/plane before these
			# complete end facts existed. Keep that origin instead of recapturing it.
			captured_location.merge(ending.location, true)
			captured_location["location_known"] = true
		var actual_reason := "death" if str(ending.reason) == "zero_hp" else str(ending.reason)
		if destroy: actual_reason = "destroyed"
		event = LocatedSourceEndRules.capture(owner, source_record, actual_reason, ending.get("cause", cause), captured_location)
		event["ended_at_seconds"] = int(ending.get("ended_at_seconds", GameManager.campaign_elapsed_seconds))
	owner.item_projections.erase(instance_id)
	_live.erase(str(record.actor.actor_id))
	for room in GameManager.saved_local_room_states() + [LocalRoomCombat.room()]:
		room.get("created_actor_positions", {}).erase(str(record.actor.actor_id))
	# Release only this identity. A form ending must not dispose linked mates.
	if plan.destination != "backpack":
		for bond in owner.exclusive_bonds.values(): bond.targets = bond.get("targets", []).filter(func(e): return str(e.target_id) != instance_id)
	if a != null: a.is_alive = false
	if not event.is_empty(): SpellEffects.finish_source_end(owner, event)
	return {"reverted": true, "instance_id": instance_id, "destination": plan.destination, "destroyed": destroy, "overflow": int(ending.overflow), "state": copy.state.duplicate(true)}

## Called from Character after temporary HP and zero-HP replacement settlement.
static func damaged(a: Character, hp_before: int, hp_damage: int, cause: Dictionary = {}) -> void:
	if not a.has_meta("projected_item_id"): return
	var ref: WeakRef = a.get_meta("projection_owner_ref", null)
	var owner = ref.get_ref() if ref != null else null
	var id := str(a.get_meta("projected_item_id", ""))
	if not is_projected(owner, id) or actor(owner, id) != a: return
	var record: Dictionary = owner.item_projections[id]
	record.actor.current_hp = maxi(0, a.current_hp)
	if a.current_hp > 0 or record.has("ending"): return
	var policy := return_policy(_policy(str(record.copy.definition_id)))
	var overflow := maxi(0, hp_damage - hp_before)
	record["ending"] = {"reason": "zero_hp", "overflow": overflow, "location": _location(a), "cause": cause.duplicate(true)}
	if _policy(str(record.copy.definition_id)).has("end_aftermath"):
		record.ending["final_location"] = LocatedSourceEndRules.capture(a, {}, "death", cause).final_location
		record.ending["ended_at_seconds"] = int(GameManager.campaign_elapsed_seconds)
	if policy.overflow == "original": record.copy.state["combat_object_hp"] = maxi(0, _original_hp(record.copy, policy) - overflow)
	revert(owner, id, int(a.get_meta("projection_serial", 0)), "death", cause)

static func _host():
	var host = _combat_host.get_ref() if _combat_host != null else null
	return host if host != null and host.is_inside_tree() and GameManager.current_state == GameManager.GameState.COMBAT else null

static func _location(a: Character) -> Dictionary:
	var host = _host()
	if a == null: return {}
	if host != null:
		for entity in host.player_entities:
			if entity.get("character") == a:
				var hex: Vector2i = entity.hex_position
				return {"room_id": str(LocalRoomCombat.room().get("id", "")), "position": [hex.x, hex.y], "plane": PhysicalFactsRules.get_plane(a, {"plane": PhysicalFactsRules.get_plane(LocalRoomCombat.room())})}
	if GameManager.current_state != GameManager.GameState.COMBAT:
		for room in GameManager.saved_local_room_states():
			if room.get("created_actor_positions", {}).has(a.character_id):
				return {"room_id": str(room.id), "position": room.created_actor_positions[a.character_id].duplicate(), "plane": PhysicalFactsRules.get_plane(a, {"plane": PhysicalFactsRules.get_plane(room)})}
	return {}

static func _return_plan(owner: Character, copy: Dictionary, location: Dictionary, policy: Dictionary, extra_reserved: Array = []) -> Dictionary:
	owner.inventory.copies.sync(owner.inventory)
	if not owner.inventory.get_instance(str(copy.instance_id)).is_empty(): return {"error": "The exact copy is already held."}
	if policy.destination != "ground" and owner.inventory.backpack.size() < Inventory.MAX_BACKPACK_SIZE: return {"destination": "backpack"}
	if policy.destination == "backpack": return {"error": "There is no room to take the copy back."}
	if location.is_empty() or str(location.get("room_id", "")).is_empty(): return {"error": "The form has no represented ground return location."}
	var room := {}
	for candidate in GameManager.saved_local_room_states():
		if str(candidate.get("id", "")) == str(location.room_id): room = candidate; break
	if str(LocalRoomCombat.room().get("id", "")) == str(location.room_id): room = LocalRoomCombat.room()
	if room.is_empty(): return {"error": "The original return room is unavailable."}
	var host = _host()
	if host == null and GameManager.current_state == GameManager.GameState.COMBAT: return {"error": "Ground return requires the live combat host."}
	var grid: HexGrid
	var reserved: Array = extra_reserved.duplicate(true)
	# Loose copies also need distinct return cells, rather than a pile that hides
	# another copy. Persistent summon positions remain occupied after relaunch.
	for object in room.get("objects", []):
		if not bool(object.get("removed", false)): reserved.append(LocalRoomRules.coord(object.position))
	var temporary := host == null
	if not temporary and not is_same(LocalRoomCombat.room(), room): return {"error": "The live combat host is in another room."}
	if temporary:
		grid = HexGrid.new()
		for cell in room.get("cells", []):
			var tile := HexTile.new()
			tile.coord = LocalRoomRules.coord(cell)
			tile.custom_properties["blocks_movement"] = not LocalRoomRules.passable(room, tile.coord)
			grid.add_tile(tile)
		var players: Array = []
		for member in PartyManager.characters.values():
			if room.get("party_positions", {}).has(member.character_id) and ContainmentRules.relation(room, "character", member.character_id).is_empty(): players.append({"character": member, "hex_position": LocalRoomRules.coord(room.party_positions[member.character_id])})
			var familiar := FamiliarRules.position(member, str(room.id))
			if familiar != FamiliarRules.ABSENT: reserved.append(familiar)
			var steed := PaladinRules.find_steed_state(member)
			if int(steed.get("current_hp", 0)) > 0 and not bool(steed.get("mounted", false)):
				var position := PaladinRules.find_steed_room_position(member, str(room.id))
				if position != Vector2i(9999, 9999): reserved.append(position)
		for position in room.get("created_actor_positions", {}).values(): reserved.append(LocalRoomRules.coord(position))
		for creature in CreatedCreatureRules.room_records(room):
			if int(creature.get("current_hp", 0)) > 0: reserved.append(LocalRoomRules.coord(creature.position))
		host = {"hex_grid": grid, "player_entities": players, "room": room, "objects": room.get("objects", []), "plane": PhysicalFactsRules.get_plane(room)}
	else:
		grid = host.hex_grid
		for ground in host.dropped_combat_items:
			if not bool(ground.get("removed", false)): reserved.append(LocalRoomRules.coord(ground.position))
	# Query the ending plane, independently of whoever now stands on its origin.
	var placement := {"hex_grid": grid, "player_entities": host.player_entities, "monster_entities": host.monster_entities if not temporary else [], "room": room, "objects": room.get("objects", []), "plane": PhysicalFactsRules.get_plane(room), "placement_plane": str(location.plane), "reserved": reserved}
	var origin := LocalRoomRules.coord(location.position)
	var return_size := PhysicalFactsRules.get_size(LocalRoomRules.placed_item(room, copy, origin))
	if return_size.is_empty(): return_size = str(policy.size)
	var picks: Array = []
	if str(location.plane) == PhysicalFactsRules.get_plane(room): picks = PlacementRules.reserve(placement, origin, return_size, int(policy.range_hexes), 1, reserved)
	var placed := LocalRoomRules.placed_item(room, copy, picks[0] if not picks.is_empty() else origin)
	var old := LocalRoomRules.get_object(room, str(placed.id))
	var collision: bool = not old.is_empty() and (not bool(old.get("removed", false)) or not old.get("contents", []).is_empty())
	if picks.is_empty() or collision or (old.is_empty() and room.get("objects", []).size() >= 200):
		if temporary: grid.free()
		return {"error": "No legal ground return space is available; the exact copy is retained."}
	return {"destination": "ground", "room": room, "host": placement, "origin": origin, "hex": picks[0], "size": return_size, "reserved": reserved, "temporary_grid": grid if temporary else null}

## Retry placement without replaying the damage already stored in the ending.
static func settle(owner: Character) -> Array:
	var out: Array = []
	for id in owner.item_projections.keys():
		var a := actor(owner, str(id))
		if a != null and a.current_hp <= 0 and not owner.item_projections[id].has("ending"): damaged(a, 0, 0)
		if not is_projected(owner, str(id)):
			out.append(str(id))
			continue
		if a != null and (a.current_hp <= 0 or owner.item_projections[id].has("ending")) and revert(owner, str(id)).get("reverted", false): out.append(str(id))
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
		if not record is Dictionary or not record.get("copy") is Dictionary or not record.get("actor") is Dictionary: return "item projection record is invalid"
		for key in record:
			if key not in RECORD_KEYS: return "item projection record has unknown fields"
		var copy: Dictionary = record.copy
		if str(copy.get("instance_id", "")) != str(id) or held.has(str(id)): return "projected copy is duplicated or misidentified"
		if not id is String or str(id).is_empty() or not copy.get("state") is Dictionary: return "projected copy is malformed"
		var policy := _policy(str(copy.get("definition_id", "")))
		if policy.is_empty(): return "projected copy declares no projection"
		if ActiveTimeRules.is_active(copy) or WorkRules.is_active(copy): return "projected copy must be paused and not worked on"
		var a: Dictionary = record.actor
		if a.size() != 2 or str(a.get("actor_id", "")) != actor_id(str(id)) or not CreatedActorRules._int(a.get("current_hp"), 0, CreatedActorRules.value(policy.template.max_hp, 0)): return "projected actor is invalid"
		if record.has("ending"):
			var pending: Variant = record.ending
			if not pending is Dictionary or pending.keys().any(func(key): return key not in ["reason", "overflow", "location", "cause", "final_location", "ended_at_seconds"]) or pending.get("reason") != "zero_hp" or int(a.current_hp) != 0 or not CreatedActorRules._int(pending.get("overflow"), 0, 2147483647) or not pending.get("location") is Dictionary or (pending.has("cause") and not pending.cause is Dictionary): return "invalid pending item return"
			var loc: Dictionary = pending.location
			if not loc.is_empty() and (loc.size() != 3 or not loc.get("room_id") is String or not DungeonPersistence.coordinate(loc.get("position")) or not loc.get("plane") is String or str(loc.plane).is_empty()): return "invalid item return location"
			if pending.has("final_location") or pending.has("ended_at_seconds"):
				var final: Variant = pending.get("final_location")
				if not CreatedActorRules._int(pending.get("ended_at_seconds"), 0, 2147483647) or not final is Dictionary or final.size() != 6 or not final.get("location_known") is bool or not final.get("plane") is String or str(final.plane).is_empty() or not final.get("room_id") is String or not CreatedActorRules._int(final.get("elevation_feet"), -2147483648, 2147483647) or not CreatedActorRules._int(final.get("altitude_feet"), -2147483648, 2147483647): return "invalid pending item end facts"
				if bool(final.location_known):
					if not DungeonPersistence.coordinate(final.get("position")) or loc.is_empty() or final.room_id != loc.room_id or final.position != loc.position or final.plane != loc.plane: return "pending item end location differs from return origin"
				elif final.get("position") != null: return "invalid unknown pending item end location"
			var r := return_policy(policy)
			if r.overflow == "original" and not copy.state.has("combat_object_hp"): return "pending original overflow needs settled item HP"
			if not policy.has("vessel") and (r.on_zero_hp == "destroy" or (r.overflow == "original" and int(copy.state.get("combat_object_hp", 0)) == 0)): return "destroyed original cannot have a pending return"
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
static func attach(state: Node, owner: Character, origin: Vector2i, destinations: Dictionary = {}) -> Array:
	var joined: Array = []
	_combat_host = weakref(state)
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
		var placement := PlacementRules.policy(policy)
		var size := str(policy.template.size)
		var hexes: Array = []
		var room_pick: Variant = LocalRoomCombat.room().get("created_actor_positions", {}).get(a.character_id, null)
		var pick: Variant = destinations.get(str(id), LocalRoomRules.coord(room_pick) if room_pick is Array else null)
		if pick is Vector2i and PlacementRules.legal_error(state, origin, pick, size, int(placement.range_hexes)).is_empty(): hexes = [pick]
		if hexes.is_empty(): hexes = PlacementRules.reserve(state, origin, size, int(placement.range_hexes), 1)
		if hexes.is_empty(): continue
		state.player_entities.append({"name": a.character_name, "display_name": a.character_name, "character": a, "combat_id": a.character_id, "owner_player_index": -1, "hex_position": hexes[0], "is_created_actor": true, "created_owner_id": owner.character_id, "reaction_available": true, "color": Color(0.7, 0.6, 0.4)})
		if not LocalRoomCombat.room().is_empty(): LocalRoomCombat.room().get_or_add("created_actor_positions", {})[a.character_id] = [hexes[0].x, hexes[0].y]
		joined.append(a.character_id)
	state._update_grid_entities()
	return joined

## Grid refresh is the normal post-damage/removal host, including native attacks.
static func refresh(state: Node) -> void:
	_combat_host = weakref(state)
	for entity in state.player_entities.duplicate():
		var owner = entity.get("character")
		if owner is Character and not owner.has_meta("projected_item_id"): settle(owner)
	for entity in state.player_entities.duplicate():
		var a = entity.get("character")
		if not a is Character or not a.has_meta("projected_item_id"): continue
		var ref: WeakRef = a.get_meta("projection_owner_ref", null)
		var owner = ref.get_ref() if ref != null else null
		if not is_projected(owner, str(a.get_meta("projected_item_id"))):
			state.player_entities.erase(entity)
			state.tracker.remove_combatant(a.character_id)
