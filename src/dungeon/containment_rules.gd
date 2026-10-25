class_name ContainmentRules
extends RefCounted
## S-170. Relations locate actual room bodies; inventory ownership stays on the body.
## Room coordinates on an internal body are its remembered entry cell, not its location.

static func key(kind: String, id: String) -> String:
	return kind + ":" + id

static func policy_error(value: Variant) -> String:
	if not value is Dictionary: return "Containment policy must be an object."
	if value.is_empty(): return ""
	if value.keys().any(func(k): return k not in ["capacity", "occupant_kinds", "sizes", "creature_types", "targeting", "internal_damage", "escape", "rescue", "release", "expires_at_seconds"]): return "Unknown containment policy field."
	if value.has("release"):
		var error := release_policy_error(value.release)
		if not error.is_empty(): return error
	if value.has("expires_at_seconds") and (not value.has("release") or not SourceEndAftermathRules._int(value.expires_at_seconds, 0, 2147483647)): return "Containment expiry requires an absolute campaign deadline and release policy."
	if value.has("targeting"):
		var error := targeting_error(value.targeting)
		if not error.is_empty(): return error
	if value.has("internal_damage"):
		var damage: Variant = value.internal_damage
		if not damage is Dictionary or damage.size() != 3 or not SharedSpell._formula(damage.get("damage")) or damage.get("damage_type") not in DataLoader.VALID_DAMAGE_TYPES or not SourceEndAftermathRules._int(damage.get("interval_seconds"), 1, 86400): return "Invalid internal damage formula, type or interval."
	for route in ["escape", "rescue"]:
		if not value.has(route): continue
		var check: Variant = value[route]
		if not check is Dictionary or check.size() != 3 or check.get("ability") not in TetherRules.ESCAPES or not SourceEndAftermathRules._int(check.get("dc"), 1, 100) or not SourceEndAftermathRules._int(check.get("seconds"), 1, 3600): return "Containment checks require ability, dc and seconds."
	if not SourceEndAftermathRules._int(value.get("capacity"), 1, 32): return "Containment capacity must be a whole count from 1 to 32."
	for field in ["occupant_kinds", "sizes", "creature_types"]:
		if field == "creature_types" and not value.has(field): continue
		var entries: Variant = value.get(field)
		if not entries is Array or entries.is_empty() or entries.size() > 32: return "Containment eligibility must be declared."
		var seen := {}
		for entry in entries:
			if not entry is String or entry.is_empty() or seen.has(entry): return "Containment eligibility is invalid or duplicated."
			if field == "occupant_kinds" and entry not in ["character", "object"]: return "Unsupported occupant kind."
			if field == "sizes" and entry not in PhysicalFactsRules.VALID_SIZES: return "Unsupported occupant size."
			seen[entry] = true
	return ""

static func entity(room: Dictionary, party: Array, kind: String, id: String):
	if kind == "object": return LocalRoomRules.get_object(room, id)
	if kind == "character":
		var available: Array = party if not party.is_empty() else PartyManager.characters.values()
		for actor in available + VesselProjectionRules.actors(available):
			if actor is Character and actor.character_id == id: return actor
	return null

static func policy(target) -> Dictionary:
	return target.containment if target is Character else target.get("containment", {}) if target is Dictionary else {}

static func relation(room: Dictionary, kind: String, id: String) -> Dictionary:
	for row in room.get("containment_occupants", []):
		if row.occupant_kind == kind and row.occupant_id == id: return row
	return {}

static func occupants(room: Dictionary, kind: String, id: String) -> Array:
	return room.get("containment_occupants", []).filter(func(r): return r.container_kind == kind and r.container_id == id)

static func active(room: Dictionary) -> bool:
	return not room.get("containment_occupants", []).is_empty()

const TARGET_ROUTES := ["same_interior", "occupant_to_container", "external_to_occupant", "occupant_to_external"]

static func targeting_error(value: Variant) -> String:
	if not value is Array or value.is_empty() or value.size() > TARGET_ROUTES.size(): return "Declare containment target routes explicitly."
	var seen := {}
	for route in value:
		if route not in TARGET_ROUTES or seen.has(route): return "Unknown or duplicate containment target route."
		seen[route] = true
	return ""

## Both the boundary and the effect must permit the crossing. No inferred range
## or targeting privilege comes from a remembered entry cell.
static func target_error(actor: Character, target, effect: Dictionary, room: Dictionary = {}, party: Array = []) -> String:
	if actor == null: return "Missing containment actor."
	var tk := "character" if target is Character else "object"
	var tid: String = target.character_id if target is Character else str(target.get("id", "")) if target is Dictionary else ""
	if room.is_empty():
		for candidate in GameManager.saved_local_room_states():
			if not relation(candidate, "character", actor.character_id).is_empty() or (not relation(candidate, tk, tid).is_empty() and (tk == "character" or is_same(entity(candidate, [], tk, tid), target.get("world_object", target)))):
				return target_error(actor, target, effect, candidate, PartyManager.characters.values())
		return ""
	var a := relation(room, "character", actor.character_id)
	var t := relation(room, tk, tid)
	if a.is_empty() and t.is_empty(): return ""
	if not is_same(entity(room, party, "character", actor.character_id), actor) or not is_same(entity(room, party, tk, tid), target.get("world_object", target) if target is Dictionary else target): return "The exact containment actor or target was replaced."
	if effect.has("steps") or effect.has("save_exit_placement") or effect.get("target", "single") not in ["single", "self"]: return "Internal targeting requires an individual effect without placement or secondary targets."
	if effect.get("effects", []).any(func(e): return e.get("type") not in ["heal", "temporary_hp", "grant_condition", "remove_condition"]): return "This effect needs additional containment settlement support."
	if is_same(actor, target): return ""
	var route := ""
	var boundary: Dictionary
	if not a.is_empty() and not t.is_empty():
		if a.container_kind != t.container_kind or a.container_id != t.container_id: return "Effects between separate interiors are unavailable."
		route = "same_interior"
		boundary = a
	elif not a.is_empty():
		route = "occupant_to_container" if a.container_kind == tk and a.container_id == tid else "occupant_to_external"
		boundary = a
	else:
		route = "external_to_occupant"
		boundary = t
	var container = entity(room, party, boundary.container_kind, boundary.container_id)
	if boundary.has("release_pending") or int(policy(container).get("expires_at_seconds", 2147483647)) <= int(GameManager.campaign_elapsed_seconds) or not _container_active(room, container, boundary.container_kind, boundary.container_id): return "The containment boundary is awaiting release."
	if not targeting_error(effect.get("containment_targeting", [])).is_empty() or route not in effect.get("containment_targeting", []) or route not in policy(container).get("targeting", []): return "This effect is not eligible across that containment boundary."
	if route != "same_interior" and not relation(room, boundary.container_kind, boundary.container_id).is_empty(): return "Crossing nested containment boundaries is unavailable."
	return ""

## Legacy policies keep deferred receipts. Authored releases settle through the
## same placement owner as arrivals, with all footprints reserved before mutation.
static func release_policy_error(value: Variant) -> String:
	if not value is Dictionary or value.keys().any(func(k): return k not in ["range_hexes", "fallback_range_hexes", "no_space"]): return "Invalid containment release policy."
	if not SourceEndAftermathRules._int(value.get("range_hexes"), 1, 24) or value.get("no_space") not in ["defer", "refuse"]: return "Release requires range_hexes and no_space defer/refuse."
	if value.has("fallback_range_hexes") and not SourceEndAftermathRules._int(value.fallback_range_hexes, int(value.range_hexes), 24): return "Fallback range must include the primary release range."
	return ""

static func placement_state(room: Dictionary, party: Array) -> Dictionary:
	var grid := HexGrid.new()
	for cell in room.get("cells", []):
		var tile := HexTile.new()
		tile.coord = LocalRoomRules.coord(cell)
		tile.custom_properties["blocks_movement"] = not LocalRoomRules.passable(room, tile.coord)
		grid.add_tile(tile)
	var players: Array = []
	for actor in party:
		if actor is Character and room.get("party_positions", {}).has(actor.character_id) and relation(room, "character", actor.character_id).is_empty():
			# Downed bodies also require space when releasing living occupants.
			players.append({"character": actor, "hex_position": LocalRoomRules.coord(room.party_positions[actor.character_id])})
	var reserved: Array = []
	for actor in players:
		reserved.append({"hex": actor.hex_position, "size": PhysicalFactsRules.get_size(actor.character)})
	for object in room.get("objects", []):
		if not bool(object.get("removed", false)) and relation(room, "object", str(object.id)).is_empty():
			reserved.append({"hex": LocalRoomRules.coord(object.position), "size": PhysicalFactsRules.get_size(object)})
	for actor in party:
		if not actor is Character: continue
		var familiar := FamiliarRules.position(actor, str(room.get("id", "")))
		if familiar != FamiliarRules.ABSENT: reserved.append({"hex": familiar, "size": "medium"})
		var steed := PaladinRules.find_steed_state(actor)
		if int(steed.get("current_hp", 0)) > 0 and not bool(steed.get("mounted", false)):
			var position := PaladinRules.find_steed_room_position(actor, str(room.get("id", "")))
			if position != Vector2i(9999, 9999): reserved.append({"hex": position, "size": "large"})
	for creature in CreatedCreatureRules.room_records(room):
		if int(creature.get("current_hp", 0)) > 0: reserved.append({"hex": LocalRoomRules.coord(creature.position), "size": str(creature.get("size", "medium"))})
	var created_sizes := {}
	for owner in party:
		if not owner is Character: continue
		for actor in CreatedActorRules.actors(owner): created_sizes[actor.character_id] = PhysicalFactsRules.get_size(actor)
		for instance_id in owner.item_projections:
			var actor := ItemProjectionRules.actor(owner, str(instance_id))
			if actor != null: created_sizes[actor.character_id] = PhysicalFactsRules.get_size(actor)
	for id in room.get("created_actor_positions", {}):
		reserved.append({"hex": LocalRoomRules.coord(room.created_actor_positions[id]), "size": str(created_sizes.get(id, "medium"))})
	return {"_placement_grid": grid, "_placement_players": players, "room": room, "objects": room.get("objects", []), "plane": PhysicalFactsRules.get_plane(room), "placement_plane": PhysicalFactsRules.get_plane(room), "reserved": reserved}

static func prepare_release(room: Dictionary, party: Array, rows: Array) -> Dictionary:
	if rows.is_empty(): return LocalRoomRules.failure("No occupants await release.")
	var validation := room_error(room, party, true)
	if not validation.is_empty(): return LocalRoomRules.failure(validation)
	var state := placement_state(room, party)
	var reserved: Array = state.reserved.duplicate(true)
	var entries: Array = []
	var seen := {}
	var error := ""
	for row in rows:
		if not is_same(relation(room, str(row.get("occupant_kind", "")), str(row.get("occupant_id", ""))), row):
			error = "That release relationship changed."; break
		var identity := key(row.occupant_kind, row.occupant_id)
		if seen.has(identity): error = "An occupant was selected twice."; break
		seen[identity] = true
		var container = entity(room, party, row.container_kind, row.container_id)
		var body = entity(room, party, row.occupant_kind, row.occupant_id)
		var rule: Dictionary = row.get("release_pending", {}).get("placement", policy(container).get("release", {}))
		var origin := external_location(room, row.container_kind, row.container_id, party)
		if body == null or (body is Dictionary and body.is_empty()) or rule.is_empty() or not release_policy_error(rule).is_empty() or origin.get("kind") != "external" or origin.get("plane") != state.plane or PhysicalFactsRules.get_plane(body, {"plane": state.plane}) != state.plane:
			error = "Release needs actual bodies, a represented origin and an authored placement policy."; break
		if not room.get("cells", []).any(func(cell): return LocalRoomRules.coord(cell) == LocalRoomRules.coord(origin.position)):
			error = "Release origin is outside represented geometry."; break
		var size := PhysicalFactsRules.get_size(body)
		var reach := int(rule.range_hexes)
		var options := PlacementRules.candidates(state, LocalRoomRules.coord(origin.position), size, reach, reserved)
		if options.is_empty() and rule.has("fallback_range_hexes"):
			reach = int(rule.fallback_range_hexes)
			options = PlacementRules.candidates(state, LocalRoomRules.coord(origin.position), size, reach, reserved)
		if options.is_empty(): error = "There is no legal space for every released occupant."; break
		var destination := options[0]
		entries.append({"row": row, "snapshot": row.duplicate(true), "body": body, "container": container, "policy": policy(container).duplicate(true), "origin": origin, "rule": rule.duplicate(true), "hex": destination, "range": reach, "size": size})
		reserved.append({"hex": destination, "size": size})
	state._placement_grid.free()
	if not error.is_empty(): return LocalRoomRules.failure(error)
	return {"success": true, "_room": room, "entries": entries}

static func commit_release(room: Dictionary, party: Array, plan: Dictionary, commit: bool = true) -> Dictionary:
	var validation := room_error(room, party, true)
	if not validation.is_empty(): return LocalRoomRules.failure(validation)
	if not plan.get("success", false) or plan.get("consumed", false) or not is_same(plan.get("_room"), room): return LocalRoomRules.failure("That release choice is stale.")
	var state := placement_state(room, party)
	var reserved: Array = state.reserved.duplicate(true)
	var error := ""
	for entry in plan.entries:
		var row: Dictionary = entry.row
		if not is_same(relation(room, row.occupant_kind, row.occupant_id), row) or row != entry.snapshot or not is_same(entity(room, party, row.occupant_kind, row.occupant_id), entry.body) or not is_same(entity(room, party, row.container_kind, row.container_id), entry.container) or policy(entry.container) != entry.policy or external_location(room, row.container_kind, row.container_id, party) != entry.origin or PhysicalFactsRules.get_size(entry.body) != entry.size or PhysicalFactsRules.get_plane(entry.body, {"plane": state.plane}) != state.plane:
			error = "The exact release bodies, relationship, rules or origin changed."; break
		error = PlacementRules.legal_error(state, LocalRoomRules.coord(entry.origin.position), entry.hex, entry.size, entry.range, reserved)
		if not error.is_empty(): break
		reserved.append({"hex": entry.hex, "size": entry.size})
	state._placement_grid.free()
	if not error.is_empty(): return LocalRoomRules.failure(error)
	if not commit: return {"success": true}
	plan["consumed"] = true
	# No callbacks between removing the complete batch and placing its exact bodies.
	for entry in plan.entries:
		var row: Dictionary = entry.row
		var rows: Array = room.containment_occupants
		rows.remove_at(rows.find(row))
	for entry in plan.entries:
		var row: Dictionary = entry.row
		var position := [entry.hex.x, entry.hex.y]
		if row.occupant_kind == "character":
			LocalRoomRules._ensure_party_altitudes(room)
			room.party_positions[row.occupant_id] = position
			room.party_altitudes[row.occupant_id] = LocalRoomRules.elevation_feet(room, entry.hex)
			room.party_altitude_modes[row.occupant_id] = "ground"
		else:
			entry.body.position = position
			entry.body["altitude_feet"] = LocalRoomRules.elevation_feet(room, entry.hex)
	return {"success": true, "released": plan.entries.size(), "message": "%d occupant(s) released into legal space." % plan.entries.size()}

static func _mark_release(room: Dictionary, row: Dictionary, reason: String, actor_id: String = "") -> void:
	if row.has("release_pending"): return
	row["release_pending"] = {"reason": reason, "actor_id": actor_id, "at_seconds": int(GameManager.campaign_elapsed_seconds)}
	var rule: Dictionary = policy(entity(room, PartyManager.characters.values(), row.container_kind, row.container_id)).get("release", {})
	if not rule.is_empty(): row.release_pending["placement"] = rule.duplicate(true)

static func request_releases(room: Dictionary, rows: Array, reason: String, actor_id: String = "", prepared: Dictionary = {}) -> Dictionary:
	for row in rows:
		if not is_same(relation(room, str(row.get("occupant_kind", "")), str(row.get("occupant_id", ""))), row): return LocalRoomRules.failure("That containment relation is stale.")
	for row in rows: _mark_release(room, row, reason, actor_id)
	var party := PartyManager.characters.values()
	if not prepared.is_empty():
		for entry in prepared.entries: entry.snapshot = entry.row.duplicate(true)
	var result := commit_release(room, party, prepared if not prepared.is_empty() else prepare_release(room, party, rows))
	if result.success: return result
	return {"success": true, "deferred": true, "message": "Release settlement deferred: %s Occupants and gear remain inside." % result.message}

static func request_release(room: Dictionary, row: Dictionary, reason: String, actor_id: String = "") -> Dictionary:
	return request_releases(room, [row], reason, actor_id)

static func settle_object_destruction(object: Dictionary) -> void:
	for room in GameManager.saved_local_room_states():
		if not is_same(LocalRoomRules.get_object(room, str(object.get("id", ""))), object): continue
		var rows := occupants(room, "object", str(object.id))
		var parent := relation(room, "object", str(object.id))
		if not rows.is_empty() or not parent.is_empty(): object["removed"] = false
		if not parent.is_empty():
			_mark_release(room, parent, "occupant_destroyed")
			rows.append(parent)
		if not rows.is_empty(): request_releases(room, rows, "container_destroyed")
		if not rows.is_empty() or not parent.is_empty(): object["removed"] = false

static func _container_active(room: Dictionary, body, kind: String, id: String) -> bool:
	return _present(room, body, kind, id, false) and (body.is_alive if body is Character else true)

static func settle_character_loss(body: Character) -> void:
	if body == null or body.is_alive: return
	# The item projection owns atomic passenger/cargo/original settlement.
	if body.has_meta("projected_item_id"): return
	for room in GameManager.saved_local_room_states():
		if not is_same(entity(room, PartyManager.characters.values(), "character", body.character_id), body): continue
		var rows := occupants(room, "character", body.character_id)
		if not rows.is_empty(): request_releases(room, rows, "container_destroyed")

static func check_error(room: Dictionary, party: Array, actor: Character, kind: String, id: String, mode: String) -> String:
	if mode not in ["escape", "rescue"]: return "Choose escape or rescue."
	if actor == null or actor not in party or not actor.is_alive or CombatAction.is_incapacitated(actor): return "That actor cannot attempt a containment check."
	var row := relation(room, kind, id)
	if row.is_empty(): return "Choose an exact contained occupant."
	for pair in [["character", actor.character_id], [row.container_kind, row.container_id], [kind, id]]:
		var matches: Array = party.filter(func(c): return c is Character and c.character_id == pair[1]) if pair[0] == "character" else room.get("objects", []).filter(func(o): return o is Dictionary and o.get("id") == pair[1])
		if matches.size() != 1: return "That body identity is missing or duplicated."
	if row.has("release_pending"): return "Release settlement is already deferred; no further check or cost is needed."
	var container = entity(room, party, row.container_kind, row.container_id)
	var occupant = entity(room, party, kind, id)
	if not _container_active(room, container, row.container_kind, row.container_id) or not _present(room, occupant, kind, id, false): return "That exact body is no longer eligible."
	var declaration := policy(container)
	if int(declaration.get("expires_at_seconds", 2147483647)) <= int(GameManager.campaign_elapsed_seconds): return "That containment has expired."
	if not policy_error(declaration).is_empty() or not declaration.has(mode): return "That containment source does not allow this check."
	if mode == "escape":
		if kind != "character" or not is_same(actor, occupant): return "Only the selected occupant can attempt its escape."
	else:
		if is_same(actor, occupant) or (row.container_kind == "character" and actor.character_id == row.container_id) or not relation(room, "character", actor.character_id).is_empty(): return "Choose a distinct outside rescuer."
		var a := location(room, "character", actor.character_id, party)
		var c := location(room, row.container_kind, row.container_id, party)
		if a.get("kind") != "external" or c.get("kind") != "external" or a.plane != c.plane or abs(int(a.altitude) - int(c.altitude)) > 5 or HexUtils.get_distance(LocalRoomRules.coord(a.position), LocalRoomRules.coord(c.position)) > 1: return "The rescuer must be outside, within reach on the same plane."
		for loc in [a, c]:
			if not room.get("cells", []).any(func(cell): return LocalRoomRules.coord(cell) == LocalRoomRules.coord(loc.position)) or not LocalRoomRules.passable(room, LocalRoomRules.coord(loc.position)): return "Geometry blocks rescue."
	return ""

static func prepare_check(room: Dictionary, party: Array, actor: Character, kind: String, id: String, mode: String) -> Dictionary:
	var error := check_error(room, party, actor, kind, id, mode)
	if not error.is_empty(): return LocalRoomRules.failure(error)
	var row := relation(room, kind, id)
	return {"success": true, "mode": mode, "release_plan": prepare_release(room, party, [row]) if policy(entity(room, party, row.container_kind, row.container_id)).has("release") else {}, "_room": room, "_actor": actor, "_container": entity(room, party, row.container_kind, row.container_id), "_occupant": entity(room, party, kind, id), "_row": row, "relation": row.duplicate(true), "policy": policy(entity(room, party, row.container_kind, row.container_id)).duplicate(true), "actor_location": location(room, "character", actor.character_id, party), "container_location": external_location(room, row.container_kind, row.container_id, party)}

static func attempt_check(room: Dictionary, party: Array, actor: Character, choice: Dictionary) -> Dictionary:
	var row: Dictionary = choice.get("_row", {})
	if not bool(choice.get("success", false)) or choice.get("consumed", false) or actor == null or not is_same(choice.get("_room"), room) or not is_same(choice.get("_actor"), actor) or not is_same(relation(room, str(row.get("occupant_kind", "")), str(row.get("occupant_id", ""))), row): return LocalRoomRules.failure("That containment choice is stale or already settled.")
	var error := check_error(room, party, actor, row.occupant_kind, row.occupant_id, str(choice.get("mode", "")))
	if not error.is_empty(): return LocalRoomRules.failure(error)
	if choice.get("relation") != row or not is_same(choice.get("_container"), entity(room, party, row.container_kind, row.container_id)) or not is_same(choice.get("_occupant"), entity(room, party, row.occupant_kind, row.occupant_id)) or choice.policy != policy(choice._container) or choice.actor_location != location(room, "character", actor.character_id, party) or choice.container_location != external_location(room, row.container_kind, row.container_id, party): return LocalRoomRules.failure("The exact bodies, rules or locations changed. Choose again.")
	var prepared: Dictionary = choice.get("release_plan", {})
	if prepared.get("success", false) and not commit_release(room, party, prepared, false).success: return LocalRoomRules.failure("That release destination changed. Choose again before rolling or spending time.")
	var release_rule: Dictionary = choice.policy.get("release", {})
	if release_rule.get("no_space") == "refuse" and not prepare_release(room, party, [row]).success: return LocalRoomRules.failure("No legal release destination; the check and time cost are refused.")
	choice["consumed"] = true
	var rule: Dictionary = choice.policy[choice.mode]
	var check := EventResolver.resolve_skill_check(actor, {"ability": rule.ability, "skill": TetherRules.ESCAPES[rule.ability], "dc": int(rule.dc), "use_primal_knowledge": false})
	var passed := bool(check.get("success", false))
	var result := request_releases(room, [row], choice.mode, actor.character_id, prepared if prepared.get("success", false) else {}) if passed else {"success": false, "message": "Containment %s failed (%d vs DC %d)." % [choice.mode, int(check.get("total", 0)), int(rule.dc)]}
	result.merge({"attempted": true, "seconds": int(rule.seconds), "total": int(check.get("total", 0)), "source_id": str(row.get("source_id", "")), "occupant_id": str(row.occupant_id), "actor_id": actor.character_id}, true)
	return result

static func advance_internal_damage(room: Dictionary, party: Array, now_seconds: int) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var ending := {}
	for row in room.get("containment_occupants", []).duplicate():
		var container = entity(room, party, row.container_kind, row.container_id)
		if container is Character and container.has_meta("projected_item_id") and not container.is_alive: continue
		if not _container_active(room, container, row.container_kind, row.container_id) or int(policy(container).get("expires_at_seconds", 2147483647)) <= now_seconds:
			var id := key(row.container_kind, row.container_id)
			if not ending.has(id):
				ending[id] = true
				request_releases(room, occupants(room, row.container_kind, row.container_id), "expiry" if int(policy(container).get("expires_at_seconds", 2147483647)) <= now_seconds else "container_destroyed")
	for row in room.get("containment_occupants", []).duplicate():
		if row.has("release_pending"): continue
		var container = entity(room, party, row.container_kind, row.container_id)
		var target = entity(room, party, row.occupant_kind, row.occupant_id)
		if not _container_active(room, container, row.container_kind, row.container_id):
			request_release(room, row, "container_destroyed")
			continue
		if not row.has("next_damage_seconds"): continue
		var rule: Dictionary = policy(container).get("internal_damage", {})
		if rule.is_empty() or not policy_error(policy(container)).is_empty(): continue
		while int(row.next_damage_seconds) <= now_seconds and not row.has("release_pending"):
			# Consume the occurrence before shared damage can end sources or re-enter.
			row.next_damage_seconds = int(row.next_damage_seconds) + int(rule.interval_seconds)
			var amount := Dice.parse_dice_string(str(rule.damage))
			var dealt := 0
			if target is Character:
				var facts := {"damage_source_instance_id": str(row.source_id), "damage_source_actor_id": str(row.container_id) if row.container_kind == "character" else key("object", str(row.container_id))}
				dealt = int(CombatAction.resolve_damage(target, amount, str(rule.damage_type), facts, false, false, container if container is Character else null).get("resolved", 0))
			elif target is Dictionary and not target.is_empty():
				dealt = CombatObjectRules.apply_damage(target, amount, str(rule.damage_type), true)
			results.append({"source_id": str(row.source_id), "occupant_id": str(row.occupant_id), "damage": dealt, "message": "%s takes %d internal %s damage." % [str(row.occupant_id), dealt, str(rule.damage_type)]})
	return results

static func involved(room: Dictionary, kind: String, id: String) -> bool:
	return not relation(room, kind, id).is_empty() or not occupants(room, kind, id).is_empty()

static func object_involved(object: Dictionary) -> bool:
	if object.is_empty(): return false
	for room in GameManager.saved_local_room_states():
		for body in room.get("objects", []):
			if is_same(body, object): return involved(room, "object", str(object.get("id", "")))
	return false

static func _present(room: Dictionary, target, kind: String, id: String, admission: bool = true) -> bool:
	if kind == "character": return target is Character and (not admission or target.is_alive) and (room.get("party_positions", {}).has(id) or room.get("created_actor_positions", {}).has(id))
	return target is Dictionary and not target.is_empty() and not bool(target.get("removed", false)) and int(target.get("hp", 1)) > 0

## Internal locations deliberately expose no room position. External origin is a separate query.
static func location(room: Dictionary, kind: String, id: String, party: Array = []) -> Dictionary:
	var inside := relation(room, kind, id)
	if not inside.is_empty(): return {"kind": "internal", "room_id": str(room.get("id", "")), "container_kind": inside.container_kind, "container_id": inside.container_id}
	var target = entity(room, party, kind, id)
	if target == null and kind == "character": target = PartyManager.characters.get(id)
	var position: Variant = target.get("position") if target is Dictionary and not target.is_empty() else room.get("party_positions", {}).get(id, room.get("created_actor_positions", {}).get(id))
	if not DungeonPersistence.coordinate(position): return {}
	var plane := PhysicalFactsRules.get_plane(target, {"plane": PhysicalFactsRules.get_plane(room)}) if target != null else PhysicalFactsRules.get_plane(room)
	var altitude := LocalRoomRules.elevation_feet(room, LocalRoomRules.coord(position))
	if kind == "character" and room.get("party_positions", {}).has(id): altitude = LocalRoomRules.altitude_feet(room, id)
	elif target is Dictionary: altitude = int(target.get("altitude_feet", altitude))
	return {"kind": "external", "room_id": str(room.get("id", "")), "position": position.duplicate(), "plane": plane, "altitude": altitude}

static func internal_location(target, room: Dictionary = {}) -> Dictionary:
	if not target is Character and not target is Dictionary: return {}
	var kind := "character" if target is Character else "object"
	var id: String = target.character_id if target is Character else str(target.get("world_object", target).get("id", "")) if target is Dictionary else ""
	var rooms: Array = [room] if not room.is_empty() else GameManager.saved_local_room_states()
	for candidate in rooms:
		if kind == "object" and room.is_empty() and not is_same(LocalRoomRules.get_object(candidate, id), target.get("world_object", target)): continue
		var inside := relation(candidate, kind, id)
		if not inside.is_empty():
			var result := location(candidate, kind, id)
			result["external_location"] = external_location(candidate, kind, id)
			return result
	return {}

static func external_location(room: Dictionary, kind: String, id: String, party: Array = []) -> Dictionary:
	var seen := {}
	while true:
		var identity := key(kind, id)
		if seen.has(identity): return {}
		seen[identity] = true
		var result := location(room, kind, id, party)
		if result.get("kind") != "internal": return result
		kind = result.container_kind
		id = result.container_id
	return {}

static func _fits(container: Dictionary, target, kind: String, used: int) -> String:
	if container.is_empty() or not policy_error(container).is_empty(): return "That body has no declared creature/object containment."
	if used >= int(container.capacity): return "That container is full."
	if kind not in container.occupant_kinds or PhysicalFactsRules.get_size(target) not in container.sizes: return "That occupant is not eligible."
	if kind == "character" and container.has("creature_types") and target.get_creature_type() not in container.creature_types: return "That creature type is not eligible."
	return ""

static func admission_error(room: Dictionary, party: Array, actor: Character, ck: String, cid: String, ok: String, oid: String) -> String:
	if actor == null or actor not in party or not actor.is_alive or CombatAction.is_incapacitated(actor): return "That actor cannot admit occupants."
	if not relation(room, "character", actor.character_id).is_empty(): return "An internal occupant cannot admit bodies from outside."
	var container = entity(room, party, ck, cid)
	var occupant = entity(room, party, ok, oid)
	if occupant is Character and occupant.has_meta("projected_item_id"): return "Projected vessels cannot be admitted as occupants."
	for pair in [[ck, cid], [ok, oid]]:
		var matches: Array = (party + VesselProjectionRules.actors(party)).filter(func(c): return c is Character and c.character_id == pair[1]) if pair[0] == "character" else room.get("objects", []).filter(func(o): return o is Dictionary and o.get("id") == pair[1])
		if matches.size() != 1: return "That body identity is missing or duplicated."
	if int(policy(container).get("expires_at_seconds", 2147483647)) <= int(GameManager.campaign_elapsed_seconds): return "That containment has expired."
	if not _present(room, container, ck, cid) or not _present(room, occupant, ok, oid): return "That exact container or occupant is no longer present."
	if container is Dictionary and (bool(container.get("locked", false)) or (container.has("open") and not bool(container.open))): return "Open and unlock that container first."
	for body in [container, occupant]:
		if body is Dictionary and bool(body.get("burning", false)): return "Extinguish that body before admission."
	if key(ck, cid) == key(ok, oid): return "A body cannot contain itself."
	if not relation(room, ok, oid).is_empty(): return "That exact occupant is already inside a container."
	var cursor := key(ck, cid)
	var seen := {}
	while not cursor.is_empty():
		if cursor == key(ok, oid) or seen.has(cursor): return "Containment would create a cycle."
		seen[cursor] = true
		var parent := relation(room, cursor.get_slice(":", 0), cursor.substr(cursor.find(":") + 1))
		cursor = key(parent.container_kind, parent.container_id) if not parent.is_empty() else ""
	if not relation(room, ck, cid).is_empty(): return "The container is internal; outside admission is unavailable."
	var error := _fits(policy(container), occupant, ok, occupants(room, ck, cid).size())
	if not error.is_empty(): return error
	if ok == "object" and bool(occupant.get("fixed", false)): return "A fixed object cannot be admitted."
	var anchor := location(room, ck, cid, party)
	for loc in [location(room, "character", actor.character_id, party), location(room, ok, oid, party)]:
		if loc.get("kind") != "external" or anchor.get("kind") != "external": return "Admission requires known external locations."
		for at in [loc.position, anchor.position]:
			if not room.get("cells", []).any(func(c): return LocalRoomRules.coord(c) == LocalRoomRules.coord(at)): return "Admission location is outside this room."
		if loc.plane != anchor.plane or abs(int(loc.altitude) - int(anchor.altitude)) > 5 or HexUtils.get_distance(LocalRoomRules.coord(loc.position), LocalRoomRules.coord(anchor.position)) > 1: return "Move the actor and occupant within reach on the container's plane."
		if not LocalRoomRules.passable(room, LocalRoomRules.coord(loc.position)) or not LocalRoomRules.passable(room, LocalRoomRules.coord(anchor.position)): return "Geometry blocks admission."
	return ""

static func prepare(room: Dictionary, party: Array, actor: Character, ck: String, cid: String, ok: String, oid: String) -> Dictionary:
	var error := admission_error(room, party, actor, ck, cid, ok, oid)
	if not error.is_empty(): return {"success": false, "message": error}
	return {"success": true, "actor_id": actor.character_id, "container_kind": ck, "container_id": cid, "occupant_kind": ok, "occupant_id": oid, "actor_location": location(room, "character", actor.character_id, party), "container_location": location(room, ck, cid, party), "occupant_location": location(room, ok, oid, party), "_room": room, "_actor": actor, "_container": entity(room, party, ck, cid), "_occupant": entity(room, party, ok, oid)}

## The only mutation is appending one exact relation, after every live check.
static func admit(room: Dictionary, party: Array, actor: Character, choice: Dictionary) -> Dictionary:
	if not bool(choice.get("success", false)) or actor == null or choice.get("actor_id") != actor.character_id: return LocalRoomRules.failure("That admission choice is stale.")
	var ck := str(choice.get("container_kind", ""))
	var cid := str(choice.get("container_id", ""))
	var ok := str(choice.get("occupant_kind", ""))
	var oid := str(choice.get("occupant_id", ""))
	if not is_same(choice.get("_room"), room) or not is_same(choice.get("_actor"), actor) or not is_same(choice.get("_container"), entity(room, party, ck, cid)) or not is_same(choice.get("_occupant"), entity(room, party, ok, oid)): return LocalRoomRules.failure("That exact body or room was replaced. Choose again.")
	var error := admission_error(room, party, actor, ck, cid, ok, oid)
	if not error.is_empty(): return LocalRoomRules.failure(error)
	if choice.get("actor_location") != location(room, "character", actor.character_id, party) or choice.get("container_location") != location(room, ck, cid, party) or choice.get("occupant_location") != location(room, ok, oid, party): return LocalRoomRules.failure("The chosen locations changed. Choose again.")
	var rows: Array = room.get("containment_occupants", [])
	rows.append({"container_kind": ck, "container_id": cid, "occupant_kind": ok, "occupant_id": oid})
	var row: Dictionary = rows.back()
	room["containment_serial"] = int(room.get("containment_serial", 0)) + 1
	var room_key := str(room.get("id", ""))
	for saved_key in GameManager.active_dungeon_state.get("local_rooms", {}):
		if is_same(GameManager.active_dungeon_state.local_rooms[saved_key], room): room_key = str(saved_key); break
	row["source_id"] = "containment:%s:%s:%s:%d" % [str(GameManager.active_dungeon_state.get("dungeon_id", "")), room_key, str(room.get("id", "")), int(room.containment_serial)]
	var damage: Dictionary = policy(entity(room, party, ck, cid)).get("internal_damage", {})
	if not damage.is_empty(): row["next_damage_seconds"] = int(GameManager.campaign_elapsed_seconds) + int(damage.interval_seconds)
	room["containment_occupants"] = rows
	return {"success": true, "message": "%s is inside %s." % [oid, cid]}

static func room_error(room: Dictionary, party: Array = [], check_links: bool = false) -> String:
	for object in room.get("objects", []):
		var error := policy_error(object.get("containment", {}))
		if not error.is_empty(): return error
	var rows: Variant = room.get("containment_occupants", [])
	if not rows is Array or rows.size() > 200: return "Containment occupants must be a bounded array."
	if not SourceEndAftermathRules._int(room.get("containment_serial", 0), 0, 2147483647): return "Invalid containment source serial."
	var parents := {}
	var counts := {}
	var sources := {}
	for row in rows:
		if not row is Dictionary or row.keys().any(func(k): return k not in ["container_kind", "container_id", "occupant_kind", "occupant_id", "source_id", "next_damage_seconds", "release_pending"]): return "Malformed containment relation."
		if row.has("source_id") and (not row.source_id is String or row.source_id.is_empty()): return "Missing containment source."
		if row.has("source_id"):
			var suffix: String = row.source_id.get_slice(":", row.source_id.get_slice_count(":") - 1)
			if sources.has(row.source_id) or not suffix.is_valid_int() or int(suffix) < 1 or int(suffix) > int(room.get("containment_serial", 0)): return "Duplicated containment source or invalid serial."
			sources[row.source_id] = true
		if row.has("next_damage_seconds") and (not row.has("source_id") or not SourceEndAftermathRules._int(row.next_damage_seconds, 0, 2147483647)): return "Invalid containment damage checkpoint."
		if row.has("release_pending"):
			var pending: Variant = row.release_pending
			if not pending is Dictionary or pending.keys().any(func(k): return k not in ["reason", "actor_id", "at_seconds", "placement"]) or pending.get("reason") not in ["escape", "rescue", "container_destroyed", "occupant_destroyed", "expiry"] or not pending.get("actor_id") is String or not SourceEndAftermathRules._int(pending.get("at_seconds"), 0, 2147483647): return "Invalid deferred containment release."
			if pending.has("placement") and not release_policy_error(pending.placement).is_empty(): return "Invalid pending release placement."
			if pending.reason == "escape" and (row.get("occupant_kind") != "character" or pending.actor_id != row.get("occupant_id")): return "Escape receipt does not name its exact occupant."
			if pending.reason == "rescue" and (not room.get("party_positions", {}).has(pending.actor_id) or (row.get("occupant_kind") == "character" and pending.actor_id == row.get("occupant_id")) or (row.get("container_kind") == "character" and pending.actor_id == row.get("container_id"))): return "Rescue receipt does not name a distinct rescuer."
			if pending.reason in ["container_destroyed", "occupant_destroyed", "expiry"] and not pending.actor_id.is_empty(): return "Destruction receipt cannot impersonate a rescuer."
		for field in ["container_kind", "occupant_kind"]:
			if row.get(field) not in ["character", "object"]: return "Invalid containment body kind."
		for field in ["container_id", "occupant_id"]:
			if not row.get(field) is String or row[field].is_empty(): return "Missing containment identity."
		if check_links or row.container_kind == "object":
			var declaration := policy(entity(room, party, row.container_kind, row.container_id))
			if declaration.has("internal_damage") and (not row.has("source_id") or not row.has("next_damage_seconds")): return "Internal damage lacks its source/timer checkpoint."
			if not row.has("release_pending") and not _container_active(room, entity(room, party, row.container_kind, row.container_id), row.container_kind, row.container_id): return "Destroyed containment requires an explicit pending release."
		var child := key(row.occupant_kind, row.occupant_id)
		var parent := key(row.container_kind, row.container_id)
		if parents.has(child): return "Duplicate contained occupant."
		parents[child] = parent
		counts[parent] = int(counts.get(parent, 0)) + 1
		for pair in [[row.container_kind, row.container_id], [row.occupant_kind, row.occupant_id]]:
			if pair[0] == "character" and not check_links:
				if not room.get("party_positions", {}).has(pair[1]) and not room.get("created_actor_positions", {}).has(pair[1]): return "Contained Character has no room identity."
			elif not _present(room, entity(room, party, pair[0], pair[1]), pair[0], pair[1], false):
				var body = entity(room, party, pair[0], pair[1])
				if not row.has("release_pending") or not body is Dictionary or body.is_empty() or bool(body.get("removed", false)): return "Containment references a missing body."
		if row.container_kind == "object":
			var declaration := policy(entity(room, party, "object", row.container_id))
			if declaration.is_empty() or int(counts[parent]) > int(declaration.capacity) or row.occupant_kind not in declaration.occupant_kinds: return "Invalid object containment capacity or eligibility."
		if check_links or (row.container_kind == "object" and row.occupant_kind == "object"):
			var target = entity(room, party, row.occupant_kind, row.occupant_id)
			if target is Character and target.has_meta("projected_item_id"): return "Projected vessels cannot be contained occupants."
			var error := _fits(policy(entity(room, party, row.container_kind, row.container_id)), target, row.occupant_kind, int(counts[parent]) - 1)
			if not error.is_empty(): return error
	for child in parents:
		var cursor: String = child
		var seen := {}
		while parents.has(cursor):
			if seen.has(cursor): return "Invalid containment cycle."
			seen[cursor] = true
			cursor = parents[cursor]
	return ""

## Both player-only and party DTO saves restore links, never replay admission.
static func saved_error(save: Dictionary) -> String:
	var worlds: Array = [save.get("active_dungeon_state", {})] + save.get("campaign_ledger", {}).get("dungeon_snapshots", {}).values()
	if not worlds.any(func(d): return d.get("local_rooms", {}).values().any(func(r): return active(r))): return ""
	var dtos: Dictionary = save.get("party", {}).get("characters", {}).duplicate(true)
	for player in save.get("players", []):
		var dto: Variant = player.get("character")
		if not dto is Dictionary: continue
		var id := str(dto.get("character_id", ""))
		if dtos.has(id) and dtos[id].get("containment", {}) != dto.get("containment", {}): return "Player and party containment policies differ."
		if not dtos.has(id): dtos[id] = dto
	var party: Array = []
	for dto in dtos.values():
		var actor := Character.new()
		actor.set_meta("projection_validation", true)
		actor.from_dict(dto)
		party.append(actor)
	var player_party := party.duplicate()
	for player in save.get("players", []):
		if not player.get("character") is Dictionary: continue
		var actor := Character.new()
		actor.set_meta("projection_validation", true)
		actor.from_dict(player.character)
		for index in player_party.size():
			if player_party[index].character_id == actor.character_id: player_party[index] = actor
	var dungeons: Dictionary = save.get("campaign_ledger", {}).get("dungeon_snapshots", {}).duplicate(true)
	var active_dungeon: Dictionary = save.get("active_dungeon_state", {})
	if not active_dungeon.is_empty(): dungeons[active_dungeon.dungeon_id] = active_dungeon
	var occupied := {}
	var character_rooms := {}
	var sources := {}
	for dungeon in dungeons.values():
		for room_key in dungeon.get("local_rooms", {}):
			var room: Dictionary = dungeon.local_rooms[room_key]
			var error := room_error(room, party, true)
			if not error.is_empty(): return error
			error = room_error(room, player_party, true)
			if not error.is_empty(): return error
			for row in room.get("containment_occupants", []):
				var container = entity(room, party, row.container_kind, row.container_id)
				if not row.has("release_pending") and int(policy(container).get("expires_at_seconds", 2147483647)) <= int(save.get("campaign_ledger", {}).get("campaign_elapsed_seconds", 0)): return "Expired containment requires a pending release."
				if row.has("release_pending") and int(row.release_pending.at_seconds) > int(save.get("campaign_ledger", {}).get("campaign_elapsed_seconds", 0)): return "Containment release receipt is in the future."
				if row.has("source_id"):
					if sources.has(row.source_id): return "Containment source is duplicated across rooms."
					sources[row.source_id] = true
				var world_key := str(dungeon.dungeon_id) + ":" + str(room.id)
				for pair in [[row.container_kind, row.container_id], [row.occupant_kind, row.occupant_id]]:
					if pair[0] != "character": continue
					if character_rooms.has(pair[1]) and character_rooms[pair[1]] != world_key: return "A Character is involved in containment in several rooms."
					character_rooms[pair[1]] = world_key
					if int(save.get("current_state", -1)) != int(GameManager.GameState.DUNGEON) or str(active_dungeon.get("dungeon_id", "")) != str(dungeon.dungeon_id): return "Contained party bodies require their represented dungeon."
					var represented := false
					for map_room in active_dungeon.get("rooms", []):
						if str(int(map_room.id)) == str(room_key) and map_room.coord == active_dungeon.get("party_position"): represented = true
					if not represented or str(active_dungeon.get("local_room_id", "")) not in ["", str(room_key)]: return "Contained party bodies are outside their represented room."
				# Object IDs are room-local; Character IDs are campaign-global.
				if row.occupant_kind != "character": continue
				if occupied.has(row.occupant_id): return "A Character occupies several containers or rooms."
				occupied[row.occupant_id] = true
	return ""

## Room-map travel carries only groups rooted in actual travelling Characters.
## Object identities remain room-local, so collisions refuse before any transfer.
static func transfer_party(source: Dictionary, destination: Dictionary, party: Array) -> Dictionary:
	for room in [source, destination]:
		var error := DungeonPersistence.local_error(room)
		if not error.is_empty(): return LocalRoomRules.failure(error)
		error = room_error(room, party, true)
		if not error.is_empty(): return LocalRoomRules.failure(error)
	if destination.get("containment_occupants", []).any(func(r): return r.container_kind == "character" or r.occupant_kind == "character"): return LocalRoomRules.failure("Party containment already exists in that room.")
	var rows: Array = source.get("containment_occupants", [])
	var moved: Array = []
	var roots := {}
	var objects: Array = []
	for row in rows:
		var root := external_location(source, row.container_kind, row.container_id, party)
		var kind: String = row.container_kind
		var id: String = row.container_id
		while not relation(source, kind, id).is_empty():
			var parent := relation(source, kind, id)
			kind = parent.container_kind; id = parent.container_id
		if kind != "character":
			if row.occupant_kind == "character": return LocalRoomRules.failure("A stationary object contains a party body; release it before travelling.")
			continue
		if not party.any(func(c): return c is Character and c.character_id == id) or root.get("plane") != PhysicalFactsRules.get_plane(destination): return LocalRoomRules.failure("That container cannot travel to this room.")
		moved.append(row)
		roots[key(row.occupant_kind, row.occupant_id)] = id
		if row.occupant_kind == "object":
			var body := LocalRoomRules.get_object(source, row.occupant_id)
			if not LocalRoomRules.get_object(destination, row.occupant_id).is_empty(): return LocalRoomRules.failure("An exact object identity already exists in the destination room.")
			objects.append(body)
	if moved.is_empty(): return {"success": true}
	if destination.get("objects", []).size() + objects.size() > 200 or destination.get("containment_occupants", []).size() + moved.size() > 200: return LocalRoomRules.failure("That room cannot hold this group.")
	var candidate := destination.duplicate(true)
	candidate.party_positions = {}
	var state := placement_state(candidate, party)
	var reserved: Array = state.reserved.duplicate(true)
	var positions := {}
	var error := ""
	for actor in party:
		var inside := relation(source, "character", actor.character_id)
		if not inside.is_empty(): continue
		if PhysicalFactsRules.get_plane(actor, {"plane": PhysicalFactsRules.get_plane(source)}) != state.plane:
			error = "The arriving body is on another plane."; break
		var options: Array = destination.get("party_spawns", destination.cells).duplicate()
		options.append_array(destination.cells)
		var found := false
		for position in options:
			var hex := LocalRoomRules.coord(position)
			if PlacementRules.legal_error(state, hex, hex, PhysicalFactsRules.get_size(actor), -1, reserved).is_empty():
				positions[actor.character_id] = position.duplicate()
				reserved.append({"hex": hex, "size": PhysicalFactsRules.get_size(actor)})
				found = true; break
		if not found: error = "No legal arrival for every travelling body."; break
	state._placement_grid.free()
	if not error.is_empty(): return LocalRoomRules.failure(error)
	for object in objects:
		object.position = positions[roots[key("object", str(object.id))]].duplicate()
		source.objects.remove_at(source.objects.find(object))
		destination.objects.append(object)
	if not destination.has("containment_occupants"): destination["containment_occupants"] = []
	for row in moved:
		source.containment_occupants.remove_at(source.containment_occupants.find(row))
		destination.containment_occupants.append(row)
	destination["containment_serial"] = maxi(int(destination.get("containment_serial", 0)), int(source.get("containment_serial", 0)))
	LocalRoomRules._ensure_party_altitudes(destination)
	for actor in party:
		var id: String = actor.character_id
		var position: Array = positions[id] if positions.has(id) else positions[roots[key("character", id)]]
		destination.party_positions[id] = position.duplicate()
		destination.party_altitudes[id] = LocalRoomRules.elevation_feet(destination, LocalRoomRules.coord(position))
		destination.party_altitude_modes[id] = "ground"
	return {"success": true, "message": "Contained bodies travel with their actual container."}
