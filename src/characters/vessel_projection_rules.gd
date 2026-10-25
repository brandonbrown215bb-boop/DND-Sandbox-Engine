class_name VesselProjectionRules
extends RefCounted
## S-167 adapts exact item projections to the existing containment and placement
## owners. Cargo stays in the original container copy; passengers stay real bodies.

static func policy_error(projection: Dictionary) -> String:
	var v: Variant = projection.get("vessel")
	if not v is Dictionary or v.size() != 4 or not v.has("containment"): return "Vessel needs containment and three ending policies."
	var error := ContainmentRules.policy_error(v.containment)
	if not error.is_empty() or v.containment.is_empty() or not v.containment.has("release"): return "Vessel needs declared capacity and legal release placement."
	var r: Variant = projection.get("reversion", {})
	if not r is Dictionary or r.is_empty(): return "Vessel needs explicit exact item reversion."
	for reason in ["on_reversion", "on_dismissal", "on_destruction"]:
		var rule: Variant = v.get(reason)
		if not rule is Dictionary or rule.size() != 2 or rule.get("cargo") not in ["retain", "release"] or rule.get("passengers") not in ["retain", "release"]: return "Vessel endings must separately declare cargo and passengers retain/release."
		if rule.passengers == "retain" and (reason == "on_destruction" or r.get("destination") != "ground" or r.get("on_end") != "return"): return "Retained passengers require a surviving ground item; destruction must release passengers."
		var destroys_original: bool = r.get("overflow") == "original" or r.get("on_zero_hp") == "destroy" if reason == "on_destruction" else r.get("on_end") == "destroy"
		if rule.cargo == "retain" and destroys_original: return "A destroyed original must release its cargo."
	return ""

static func actors(party: Array) -> Array:
	var result: Array = []
	for owner in party:
		if not owner is Character: continue
		for id in owner.item_projections:
			if not ItemProjectionRules._policy(str(owner.item_projections[id].copy.definition_id)).has("vessel"): continue
			var body := ItemProjectionRules.actor(owner, str(id))
			if body != null: result.append(body)
	return result

static func room_for(id: String) -> Dictionary:
	for room in GameManager.saved_local_room_states():
		if room.get("created_actor_positions", {}).has(id): return room
	return {}

static func current_room(room: Dictionary) -> bool:
	var dungeon: Dictionary = GameManager.active_dungeon_state
	var id := str(dungeon.get("local_room_id", ""))
	return GameManager.current_state == GameManager.GameState.DUNGEON and not id.is_empty() and is_same(dungeon.get("local_rooms", {}).get(id), room)

static func prepare_end(owner: Character, record: Dictionary, ending: Dictionary, destroy: bool) -> Dictionary:
	var projection := ItemProjectionRules._policy(str(record.copy.definition_id))
	if not projection.has("vessel"): return {}
	if GameManager.current_state == GameManager.GameState.COMBAT: return {"error": "Vessel endings require their represented room."}
	var room := room_for(str(record.actor.actor_id))
	if room.is_empty(): return {"error": "The vessel has no represented room."}
	if not record.has("ending") and not current_room(room): return {"error": "Return to the vessel's room before ending its form."}
	var party := PartyManager.characters.values()
	var key := "on_destruction" if ending.reason == "zero_hp" or destroy else "on_dismissal" if ending.reason == "dismissed" else "on_reversion"
	var rule: Dictionary = projection.vessel[key]
	var rows := ContainmentRules.occupants(room, "character", str(record.actor.actor_id))
	# An irreversible cause retains the complete form/copy until every required
	# release can fit. Existing first receipts are never overwritten.
	if ending.reason == "zero_hp":
		for row in rows: ContainmentRules._mark_release(room, row, "container_destroyed")
	var passengers := {}
	if rule.passengers == "release" and not rows.is_empty():
		passengers = ContainmentRules.prepare_release(room, party, rows)
		if not passengers.success: return {"error": passengers.message}
	var state := ContainmentRules.placement_state(room, party)
	var reserved: Array = state.reserved.duplicate(true)
	var extra: Array = []
	for entry in passengers.get("entries", []):
		var space := {"hex": entry.hex, "size": entry.size}
		reserved.append(space); extra.append(space)
	var cargo: Array = []
	var new_objects := 0
	var object_ids := {}
	var error := ""
	if rule.cargo == "release":
		for copies in record.copy.state.get("contents", {}).values():
			for copy in copies:
				var size := PhysicalFactsRules.get_size(LocalRoomRules.placed_item(room, copy, Vector2i.ZERO))
				var origin := LocalRoomRules.coord(ending.location.get("position", []))
				var reach := int(projection.vessel.containment.release.get("fallback_range_hexes", projection.vessel.containment.release.range_hexes))
				var choices := PlacementRules.candidates(state, origin, size, reach, reserved)
				if choices.is_empty(): error = "No legal space for every exact cargo copy."; break
				var object := LocalRoomRules.placed_item(room, copy, choices[0])
				if object_ids.has(str(object.id)):
					error = "Two released copies claim the same ground object identity."; break
				object_ids[str(object.id)] = true
				var old := LocalRoomRules.get_object(room, str(object.id))
				if not old.is_empty() and (not bool(old.get("removed", false)) or not old.get("contents", []).is_empty()): error = "That cargo ground identity already exists."; break
				if old.is_empty(): new_objects += 1
				cargo.append({"copy": copy, "hex": choices[0], "size": size, "range": reach, "origin": origin})
				var space := {"hex": choices[0], "size": size}
				reserved.append(space); extra.append(space)
	if room.objects.size() + new_objects > 200: error = "The room cannot hold every returned cargo copy."
	state._placement_grid.free()
	if not error.is_empty(): return {"error": error}
	return {"room": room, "party": party, "rows": rows, "passengers": passengers, "cargo": cargo, "object_ids": object_ids, "new_objects": new_objects, "reserved": extra, "retain_passengers": rule.passengers == "retain" and not rows.is_empty(), "release_cargo": rule.cargo == "release"}

static func confirm_end(plan: Dictionary) -> String:
	if plan.is_empty(): return ""
	if not plan.passengers.is_empty():
		var result := ContainmentRules.commit_release(plan.room, plan.party, plan.passengers, false)
		if not result.success: return result.message
	return ""

static func commit_end(plan: Dictionary, returned: Dictionary, copy: Dictionary) -> void:
	if plan.is_empty(): return
	# All checks have passed synchronously; no callbacks until the original item,
	# exact cargo and complete passenger batch have moved.
	if not plan.passengers.is_empty(): ContainmentRules.commit_release(plan.room, plan.party, plan.passengers)
	for entry in plan.cargo:
		var placed := LocalRoomRules.placed_item(plan.room, entry.copy, entry.hex)
		var old := LocalRoomRules.get_object(plan.room, str(placed.id))
		if old.is_empty(): plan.room.objects.append(placed)
		else:
			old.clear()
			old.merge(placed)
	if plan.retain_passengers:
		var ground := LocalRoomRules.placed_item(plan.room, copy, returned.hex)
		for row in plan.rows:
			row.container_kind = "object"
			row.container_id = str(ground.id)

static func move(room: Dictionary, owner: Character, body: Character, destination: Vector2i, grid: HexGrid, party: Array) -> Dictionary:
	if body == null or ItemProjectionRules.actor(owner, str(body.get_meta("projected_item_id", ""))) != body or not current_room(room) or not is_same(room_for(body.character_id), room): return LocalRoomRules.failure("That exact vessel changed.")
	var result := LocalRoomRules.move(room, body, destination, grid, "walk", party)
	result["acting_body"] = body
	return result

static func saved_error(save: Dictionary) -> String:
	var dungeons: Dictionary = save.get("campaign_ledger", {}).get("dungeon_snapshots", {}).duplicate(true)
	var active: Dictionary = save.get("active_dungeon_state", {})
	if not active.is_empty(): dungeons[active.dungeon_id] = active
	var owners: Dictionary = save.get("party", {}).get("characters", {}).duplicate(true)
	for player in save.get("players", []):
		if player.get("character") is Dictionary and not owners.has(str(player.character.get("character_id", ""))): owners[str(player.character.character_id)] = player.character
	var vessels := {}
	for owner in owners.values():
		for record in owner.get("item_projections", {}).values():
			if ItemProjectionRules._policy(str(record.copy.definition_id)).has("vessel"): vessels[str(record.actor.actor_id)] = record
	var locations := {}
	for dungeon in dungeons.values():
		for room in dungeon.get("local_rooms", {}).values():
			for id in room.get("created_actor_positions", {}):
				if not vessels.has(id): continue
				if locations.has(id): return "A projected vessel is represented in several rooms."
				locations[id] = true
				var record: Dictionary = vessels[id]
				if record.has("ending") and (record.ending.location.get("room_id") != room.id or record.ending.location.get("position") != room.created_actor_positions[id] or record.ending.location.get("plane") != PhysicalFactsRules.get_plane(room)): return "Pending vessel origin differs from its actual room."
	for id in vessels:
		if not locations.has(id): return "A projected vessel has no represented room."
	return ""
