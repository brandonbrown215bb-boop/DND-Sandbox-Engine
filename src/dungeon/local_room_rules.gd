## Durable local room objects. Coordinates here are five-foot hexes, not rooms.
class_name LocalRoomRules
extends RefCounted

static func coord(value: Array) -> Vector2i:
	return Vector2i(int(value[0]), int(value[1]))

static func create(definition: Dictionary, characters: Array) -> Dictionary:
	var state := definition.duplicate(true)
	state["party_positions"] = {}
	state["created_actor_positions"] = state.get("created_actor_positions", {}).duplicate(true)
	state["encounter_cleared"] = false
	state["areas"] = []
	state["area_serial"] = 0
	state["cell_elevations"] = state.get("cell_elevations", []).duplicate(true)
	state["cell_ceilings"] = state.get("cell_ceilings", []).duplicate(true)
	state["cell_terrains"] = state.get("cell_terrains", []).duplicate(true)
	state["wall_details"] = state.get("wall_details", []).duplicate(true)
	state["party_altitudes"] = {}
	state["party_altitude_modes"] = {}
	for index in characters.size():
		var character: Character = characters[index]
		var spawn: Array = definition.get("party_spawns", [[-3, 0], [-3, 1], [-2, -1], [-2, 0]])[index]
		state["party_positions"][character.character_id] = spawn.duplicate()
		state["party_altitudes"][character.character_id] = elevation_feet(state, coord(spawn))
		state["party_altitude_modes"][character.character_id] = "ground"
	for object in state.get("objects", []):
		var contents: Array = []
		for index in object.get("contents", []).size():
			var entry: Variant = object["contents"][index]
			if entry is String:
				contents.append({"instance_id": "world:%s:%s:%d" % [state["id"], object["id"], index], "definition_id": entry, "state": {}})
			else: contents.append(entry.duplicate(true))
		object["contents"] = contents
	return state

static func get_object(state: Dictionary, id: String) -> Dictionary:
	for object in state.get("objects", []):
		if str(object.get("id", "")) == id: return object
	return {}

## Successor owns a new identity; ending the parent again cannot remove it.
static func add_aftermath_object(state: Dictionary, id: String, child: Dictionary, event: Dictionary) -> Dictionary:
	var location: Dictionary = event.final_location
	if not state.get("cells", []).any(func(cell): return coord(cell) == coord(location.position)): return failure("Aftermath origin is outside this room.")
	if state.get("objects", []).size() >= 200: return failure("This room has no object capacity.")
	if not get_object(state, id).is_empty(): return {"success": true, "successor_id": id}
	state.objects.append({"id": id, "kind": str(child.kind), "name": str(child.name), "position": location.position.duplicate(), "plane": str(location.plane), "hp": int(child.hp), "max_hp": int(child.hp), "contents": [], "parent_source_id": str(event.source_id)})
	return {"success": true, "successor_id": id}

static func object_at(state: Dictionary, position: Vector2i) -> Dictionary:
	for object in state.get("objects", []):
		if not bool(object.get("removed", false)) and ContainmentRules.relation(state, "object", str(object.id)).is_empty() and coord(object["position"]) == position: return object
	return {}

static func passable(state: Dictionary, position: Vector2i) -> bool:
	var inside := false
	for cell in state.get("cells", []):
		if coord(cell) == position: inside = true; break
	if not inside: return false
	if has_wall(state, position): return false
	var object := object_at(state, position)
	return object.is_empty() or str(object.get("kind", "")) not in ["door", "barrier"] or bool(object.get("open", false)) or int(object.get("hp", 1)) == 0


static func blocks_sight(state: Dictionary, position: Vector2i) -> bool:
	if has_wall(state, position):
		return wall_height_feet(state, position) >= 10 and wall_material(state, position) != "glass"
	var object := object_at(state, position)
	return not object.is_empty() and str(object.get("kind", "")) == "door" and not bool(object.get("open", false))


static func wall_height_feet(state: Dictionary, position: Vector2i) -> int:
	var object := barrier_at(state, position)
	if str(object.get("kind", "")) == "barrier": return int(object.get("height_feet", 10))
	for wall in state.get("wall_details", []):
		if coord(wall.get("position", [])) == position: return int(wall.get("height_feet", 10))
	return 10


static func has_wall(state: Dictionary, position: Vector2i) -> bool:
	var object := barrier_at(state, position)
	if str(object.get("kind", "")) == "barrier": return int(object.get("hp", 1)) > 0
	for wall in state.get("walls", []):
		if coord(wall) == position: return true
	return false


static func wall_material(state: Dictionary, position: Vector2i) -> String:
	var object := barrier_at(state, position)
	if str(object.get("kind", "")) == "barrier": return str(object.get("material", "stone"))
	for wall in state.get("wall_details", []):
		if coord(wall.get("position", [])) == position: return str(wall.get("material", "stone"))
	return "stone"


static func barrier_at(state: Dictionary, position: Vector2i) -> Dictionary:
	for object in state.get("objects", []):
		if str(object.get("kind", "")) == "barrier" and coord(object["position"]) == position:
			return object
	return {}

static func elevation_feet(state: Dictionary, position: Vector2i) -> int:
	for cell_elevation in state.get("cell_elevations", []):
		if coord(cell_elevation.get("position", [])) == position:
			return int(cell_elevation.get("feet", 0))
	return 0


static func ceiling_feet(state: Dictionary, position: Vector2i) -> int:
	for ceiling in state.get("cell_ceilings", []):
		if coord(ceiling.get("position", [])) == position:
			return int(ceiling.get("feet", 1000))
	return int(state.get("ceiling_feet", 1000))


static func altitude_feet(state: Dictionary, character_id: String) -> int:
	var position_value: Variant = state.get("party_positions", {}).get(character_id, [0, 0])
	var floor_feet := elevation_feet(state, coord(position_value)) if position_value is Array else 0
	return int(state.get("party_altitudes", {}).get(character_id, floor_feet))


static func movement_speed_feet(character: Character, mode: String) -> int:
	if character == null:
		return 0
	if mode == "levitate":
		if not SpellEffects.has_spell(character, "levitate"):
			return 0
		var climb_speed := character.movement_speed_feet("climb")
		return climb_speed if climb_speed > 0 else character.movement_speed_feet("walk")
	var steed_state := PaladinRules.find_steed_state(character)
	if steed_state.is_empty() or not bool(steed_state.get("mounted", false)):
		return character.movement_speed_feet(mode)
	if mode == "walk":
		return int(steed_state.get("speed_feet", 0))
	if mode == "fly":
		return int(steed_state.get("fly_speed_feet", 0))
	return 0


static func levitation_surface_in_reach(state: Dictionary, position: Vector2i, altitude: int) -> bool:
	if ceiling_feet(state, position) - altitude <= 5:
		return true
	for wall in state.get("walls", []):
		if HexUtils.get_distance(position, coord(wall)) <= 1:
			return true
	for object in state.get("objects", []):
		if not bool(object.get("removed", false)) and bool(object.get("fixed", false)) and HexUtils.get_distance(position, coord(object.get("position", [9999, 9999]))) <= 1:
			return true
	return false


static func find_steed_position(state: Dictionary, character: Character, party: Array) -> Vector2i:
	var steed_state := PaladinRules.find_steed_state(character)
	if steed_state.is_empty() or int(steed_state.get("current_hp", 0)) <= 0:
		return Vector2i(9999, 9999)
	var room_id := str(state.get("id", ""))
	var owner_position := coord(state.get("party_positions", {}).get(character.character_id, [9999, 9999]))
	if bool(steed_state.get("mounted", false)):
		PaladinRules.set_find_steed_room_position(character, room_id, owner_position)
		return owner_position
	var saved_position := PaladinRules.find_steed_room_position(character, room_id)
	if saved_position != Vector2i(9999, 9999) and saved_position != owner_position and passable(state, saved_position) and object_at(state, saved_position).is_empty() and not _room_space_occupied(state, saved_position, character, party):
		return saved_position
	for candidate in HexUtils.get_hexes_in_range(owner_position, 1):
		if candidate != owner_position and passable(state, candidate) and object_at(state, candidate).is_empty() and not _room_space_occupied(state, candidate, character, party):
			PaladinRules.set_find_steed_room_position(character, room_id, candidate)
			return candidate
	return Vector2i(9999, 9999)


static func toggle_find_steed_mount(state: Dictionary, character: Character, party: Array) -> Dictionary:
	if character != null and ContainmentRules.involved(state, "character", character.character_id): return failure("Internal occupants and occupied containers require release before changing location.")
	if character == null or CombatAction.is_incapacitated(character):
		return failure("You cannot mount or dismount right now.")
	var steed_state := PaladinRules.find_steed_state(character)
	if steed_state.is_empty() or int(steed_state.get("current_hp", 0)) <= 0:
		return failure("Your bonded steed is not present in this room.")
	var owner_position := coord(state.get("party_positions", {}).get(character.character_id, [9999, 9999]))
	var steed_position := find_steed_position(state, character, party)
	if steed_position == Vector2i(9999, 9999):
		return failure("There is no open space beside you for your steed.")
	var half_speed := int(floor(float(character.get_speed()) / 2.0))
	if character.get_speed() <= 0 or half_speed <= 0:
		return failure("You need at least 10 feet of Speed to mount or dismount.")
	if bool(steed_state.get("mounted", false)):
		var destination := Vector2i(9999, 9999)
		for candidate in HexUtils.get_hexes_in_range(steed_position, 1):
			if candidate == steed_position or not passable(state, candidate) or not object_at(state, candidate).is_empty() or _room_space_occupied(state, candidate, character, party):
				continue
			destination = candidate
			break
		if destination == Vector2i(9999, 9999):
			return failure("There is no open space beside the steed to dismount.")
		state["party_positions"][character.character_id] = [destination.x, destination.y]
		PaladinRules.set_find_steed_mounted(character, false)
		PaladinRules.set_find_steed_room_position(character, str(state.get("id", "")), steed_position)
		return {"success": true, "seconds": 6, "message": "%s dismounts, spending %d feet of movement." % [character.character_name, half_speed], "movement_cost_feet": half_speed}
	if HexUtils.get_distance(owner_position, steed_position) > 1:
		return failure("Move within 5 feet of your steed before mounting.")
	if not PaladinRules.set_find_steed_mounted(character, true):
		return failure("The bonded steed state is unavailable.")
	PaladinRules.set_find_steed_room_position(character, str(state.get("id", "")), owner_position)
	return {"success": true, "seconds": 6, "message": "%s mounts the steed, spending %d feet of movement." % [character.character_name, half_speed], "movement_cost_feet": half_speed}


static func _room_space_occupied(state: Dictionary, position: Vector2i, except_owner: Character, party: Array) -> bool:
	if CreatedCreatureRules.occupied(state, position): return true
	for member in party:
		if member == null or not ContainmentRules.relation(state, "character", member.character_id).is_empty():
			continue
		var member_position := coord(state.get("party_positions", {}).get(member.character_id, [9999, 9999]))
		if member_position == position and member != except_owner:
			return true
		if FamiliarRules.position(member, str(state.get("id", ""))) == position: return true
		if member != except_owner and not PaladinRules.find_steed_state(member).is_empty() and not PaladinRules.find_steed_is_mounted(member):
			if PaladinRules.find_steed_room_position(member, str(state.get("id", ""))) == position:
				return true
	return false


static func change_flight_altitude(state: Dictionary, character: Character, delta_feet: int) -> Dictionary:
	if character != null and ContainmentRules.involved(state, "character", character.character_id): return failure("Internal occupants and occupied containers require release before changing location.")
	if character == null or not character.is_alive or CombatAction.is_incapacitated(character):
		return failure("That character cannot change altitude.")
	if character.movement_speed_feet("fly") <= 0:
		return failure("A flying Speed is required to change altitude.")
	if abs(delta_feet) != 5:
		return failure("Altitude changes one five-foot step at a time.")
	_ensure_party_altitudes(state)
	var position := coord(state.get("party_positions", {}).get(character.character_id, [0, 0]))
	var floor_feet := elevation_feet(state, position)
	var current_altitude := altitude_feet(state, character.character_id)
	var next_altitude := current_altitude + delta_feet
	if next_altitude < floor_feet:
		return failure("The character is already at floor level.")
	if next_altitude + 5 > ceiling_feet(state, position):
		return failure("The ceiling leaves no room at that altitude.")
	state["party_altitudes"][character.character_id] = next_altitude
	state["party_altitude_modes"][character.character_id] = "fly"
	return {"success": true, "seconds": 6, "message": "%s flies to %d feet above the room's ground datum." % [character.character_name, next_altitude], "altitude_feet": next_altitude}


static func change_levitation_altitude(state: Dictionary, character: Character, delta_feet: int) -> Dictionary:
	if character != null and ContainmentRules.involved(state, "character", character.character_id): return failure("Internal occupants and occupied containers require release before changing location.")
	if character == null or not character.is_alive or CombatAction.is_incapacitated(character) or not SpellEffects.has_spell(character, "levitate"):
		return failure("Levitate is not active on this character.")
	if delta_feet == 0 or abs(delta_feet) > 20 or delta_feet % 5 != 0:
		return failure("Levitate changes altitude by at most 20 feet in five-foot steps.")
	_ensure_party_altitudes(state)
	var position := coord(state.get("party_positions", {}).get(character.character_id, [0, 0]))
	var floor_feet := elevation_feet(state, position)
	var current_altitude := altitude_feet(state, character.character_id)
	var next_altitude := current_altitude + delta_feet
	if next_altitude < floor_feet or next_altitude + 5 > ceiling_feet(state, position):
		return failure("That altitude is blocked by the floor or ceiling.")
	state["party_altitudes"][character.character_id] = next_altitude
	state["party_altitude_modes"][character.character_id] = "levitate"
	return {"success": true, "seconds": 6, "message": "%s levitates to altitude %d feet." % [character.character_name, next_altitude], "altitude_feet": next_altitude}


static func reconcile_flight_altitudes(state: Dictionary, characters: Array) -> Array[String]:
	var messages: Array[String] = []
	_ensure_party_altitudes(state)
	for character in characters:
		if character == null or not character.is_alive or character.movement_speed_feet("fly") > 0 or SpellEffects.has_spell(character, "levitate"):
			continue
		var steed_state := PaladinRules.find_steed_state(character)
		if bool(steed_state.get("mounted", false)) and int(steed_state.get("fly_speed_feet", 0)) > 0 and int(steed_state.get("current_hp", 0)) > 0:
			continue
		var position_value: Variant = state.get("party_positions", {}).get(character.character_id, null)
		if not position_value is Array:
			continue
		var floor_feet := elevation_feet(state, coord(position_value))
		var altitude := altitude_feet(state, character.character_id)
		var drop_feet := altitude - floor_feet
		if str(state.get("party_altitude_modes", {}).get(character.character_id, "ground")) == "levitate":
			state["party_altitudes"][character.character_id] = floor_feet
			state["party_altitude_modes"][character.character_id] = "ground"
			messages.append("%s floats gently down as Levitate ends." % character.character_name)
			continue
		if drop_feet <= 0:
			state["party_altitudes"][character.character_id] = floor_feet
			state["party_altitude_modes"][character.character_id] = "ground"
			continue
		var damage := 0
		for _die in fall_dice_for_drop(drop_feet):
			damage += Dice.roll(6, character)
		state["party_altitudes"][character.character_id] = floor_feet
		if damage > 0:
			character.take_damage(damage)
		messages.append("%s falls %d feet and takes %d damage as its flying magic ends." % [character.character_name, drop_feet, damage])
	return messages


static func fall_dice_for_drop(drop_feet: int) -> int:
	if drop_feet < 10:
		return 0
	return mini(20, int(floor(float(drop_feet) / 10.0)))

static func surface_at(state: Dictionary, position: Vector2i) -> String:
	for cell_terrain in state.get("cell_terrains", []):
		if coord(cell_terrain.get("position", [])) == position:
			return str(cell_terrain.get("surface", "ground"))
	return "ground"


static func requires_surface_traversal(surface: String) -> bool:
	return surface in ["water", "acid", "mud", "snow", "quicksand", "lava"]

static func move(state: Dictionary, character: Character, destination: Vector2i, grid: HexGrid, mode: String = "walk", party: Array = []) -> Dictionary:
	if character != null and not ContainmentRules.relation(state, "character", character.character_id).is_empty(): return failure("Internal occupants cannot move independently.")
	if character == null or not character.is_alive or CombatAction.is_incapacitated(character): return failure("That character cannot move.")
	var projected := character.has_meta("projected_item_id")
	if projected and mode != "walk": return failure("Projected vessels currently use ground movement.")
	var positions: Dictionary = state.get("created_actor_positions", {}) if projected else state["party_positions"]
	if not positions.has(character.character_id): return failure("That body has no represented position.")
	var altitudes: Dictionary = {} if projected else state.get_or_add("party_altitudes", {})
	var altitude_modes: Dictionary = {} if projected else state.get_or_add("party_altitude_modes", {})
	var available_speed := movement_speed_feet(character, mode)
	if mode not in ["walk", "climb", "swim", "fly", "levitate"] or available_speed <= 0: return failure("That movement mode is unavailable.")
	_ensure_party_altitudes(state)
	LocalRoomAreas.expire(state, int(GameManager.campaign_elapsed_seconds))
	var origin := coord(positions[character.character_id])
	var altitude := elevation_feet(state, origin) if projected else altitude_feet(state, character.character_id)
	if mode != "fly" and altitude <= elevation_feet(state, origin):
		altitude = elevation_feet(state, origin)
		altitudes[character.character_id] = altitude
	if mode == "levitate":
		if altitude <= elevation_feet(state, origin) or not levitation_surface_in_reach(state, origin, altitude):
			return failure("Push or pull against a wall, fixed object, or ceiling within reach before moving while levitating.")
	elif mode != "fly" and altitude > elevation_feet(state, origin):
		return failure("Descend to the floor before moving with this mode.")
	if not passable(state, destination) and not (mode == "fly" and has_wall(state, destination)): return failure("The way is blocked.")
	for id in state["party_positions"]:
		if id != character.character_id and ContainmentRules.relation(state, "character", str(id)).is_empty() and coord(state["party_positions"][id]) == destination: return failure("That space is occupied.")
	for member in party:
		if member != null and not PaladinRules.find_steed_state(member).is_empty() and not PaladinRules.find_steed_is_mounted(member) and find_steed_position(state, member, party) == destination:
			return failure("That space is occupied by a bonded steed.")
	for member in party:
		if FamiliarRules.position(member, str(state.get("id", ""))) == destination:
			return failure("That space is occupied by a familiar.")
	var can_enter := func(position: Vector2i) -> bool:
		if not grid.has_tile(position): return false
		for created_id in state.get("created_actor_positions", {}):
			if created_id != character.character_id and coord(state.created_actor_positions[created_id]) == position: return false
		if projected:
			var placement := ContainmentRules.placement_state(state, party)
			var reserved: Array = placement.reserved.filter(func(r): return r.hex != origin)
			var error := PlacementRules.legal_error(placement, origin, position, PhysicalFactsRules.get_size(character), -1, reserved, {"ignore_entity": character})
			placement._placement_grid.free()
			if not error.is_empty(): return false
		if mode == "levitate":
			return altitude >= elevation_feet(state, position) and altitude + 5 <= ceiling_feet(state, position) and not has_wall(state, position) and levitation_surface_in_reach(state, position, altitude) and (not requires_surface_traversal(surface_at(state, position)) or altitude > elevation_feet(state, position)) and grid.is_hex_passable(position)
		if has_wall(state, position):
			if mode == "fly":
				return altitude >= elevation_feet(state, position) + wall_height_feet(state, position) and altitude + 5 <= ceiling_feet(state, position)
			return mode == "climb" and wall_height_feet(state, position) <= movement_speed_feet(character, "climb")
		if mode == "fly" and (altitude < elevation_feet(state, position) or altitude + 5 > ceiling_feet(state, position)):
			return false
		var surface := surface_at(state, position)
		if requires_surface_traversal(surface):
			return mode == "fly" or (surface == "water" and mode == "swim") or (mode == "walk" and SpellEffects.has_spell(character, "water_walk"))
		return grid.is_hex_passable(position)
	var movement_cost := func(position: Vector2i) -> float:
		var ignores_difficult_terrain := SpellEffects.has_spell(character, "freedom_of_movement")
		var cost := 1.0 if requires_surface_traversal(surface_at(state, position)) else maxf(1.0, grid.get_hex_cost(position, ignores_difficult_terrain))
		if mode == "levitate" and character.movement_speed_feet("climb") <= 0:
			cost += 1.0
		if not ignores_difficult_terrain:
			var area_is_difficult: bool = state.get("areas", []).any(func(area): return bool(area.get("difficult_terrain", false)) and LocalRoomAreas.contains(area, position))
			if area_is_difficult:
				cost *= 2.0
		return cost
	var path := HexUtils.find_path(origin, destination, can_enter, movement_cost)
	if path.size() < 2: return failure("Choose a reachable space within Speed.")
	var movement_cost_feet := 0
	for step in range(1, path.size()):
		var height_change := elevation_feet(state, path[step]) - elevation_feet(state, path[step - 1])
		movement_cost_feet += int(ceil(float(movement_cost.call(path[step])) * 5.0))
		if mode == "walk" and height_change > 0: movement_cost_feet += height_change
		if mode == "climb" and has_wall(state, path[step]): movement_cost_feet += wall_height_feet(state, path[step])
	if movement_cost_feet > available_speed: return failure("That route exceeds this movement mode's Speed.")
	var fall_damage := 0
	if mode == "levitate":
		altitudes[character.character_id] = altitude
		altitude_modes[character.character_id] = "levitate"
	elif mode != "fly":
		altitudes[character.character_id] = elevation_feet(state, destination)
		altitude_modes[character.character_id] = "ground"
	var entered: Array[Dictionary] = []
	var spike_growth_outcomes: Array[Dictionary] = []
	var heat_outcomes: Array[Dictionary] = []
	var actual_cost_feet := 0
	for step in range(1, path.size()):
		var step_position: Vector2i = path[step]
		var step_altitude := altitude if mode in ["fly", "levitate"] else elevation_feet(state, step_position)
		var height_change := elevation_feet(state, step_position) - elevation_feet(state, path[step - 1])
		actual_cost_feet += int(ceil(float(movement_cost.call(step_position)) * 5.0))
		if mode == "walk" and height_change > 0: actual_cost_feet += height_change
		if mode == "climb" and has_wall(state, step_position): actual_cost_feet += wall_height_feet(state, step_position)
		positions[character.character_id] = [step_position.x, step_position.y]
		altitudes[character.character_id] = step_altitude
		if PaladinRules.find_steed_is_mounted(character):
			PaladinRules.set_find_steed_room_position(character, str(state.get("id", "")), step_position)
		if mode not in ["fly", "levitate"] and height_change <= -10:
			var step_fall_damage := 0
			for _die in fall_dice_for_drop(-height_change): step_fall_damage += Dice.roll(6, character)
			fall_damage += step_fall_damage
			character.take_damage(step_fall_damage)
			if not character.is_alive: break
		var heat := resolve_surface_heat(state, character, step_position, step_altitude)
		if not heat.is_empty(): heat_outcomes.append(heat)
		if not character.is_alive: break
		LocalRoomAreas.leave(state, character, path[step - 1], step_position)
		entered.append_array(LocalRoomAreas.enter(state, character.character_id, path[step - 1], step_position, int(GameManager.campaign_elapsed_seconds), PhysicalFactsRules.get_plane(character, {"plane": PhysicalFactsRules.get_plane(state)})))
		for area in state.get("areas", []):
			if not area is Dictionary or str(area.get("spell_id", "")) != "spike_growth" or not LocalRoomAreas.contains(area, step_position):
				continue
			var caster := _party_character(party, str(area.get("caster_id", "")))
			var damage_formula := str(area.get("damage_formula", "2d4"))
			var damage := Dice.parse_dice_string(damage_formula, {}, caster if caster != null else character)
			var damage_result := CombatAction.resolve_damage(character, damage, "piercing")
			spike_growth_outcomes.append({"spell_id": "spike_growth", "damage": int(damage_result.get("resolved", 0)), "damage_formula": damage_formula, "position": step_position})
			if not character.is_alive: break
		if not character.is_alive: break
	if not character.is_alive: SpellEffects.end_concentration(character, party)
	movement_cost_feet = actual_cost_feet
	var message := "%s moves." % character.character_name
	if fall_damage > 0: message += " Falls and takes %d damage." % fall_damage
	if not entered.is_empty():
		message += " Crosses %s." % ", ".join(entered.map(func(area): return str(area.get("spell_id", "an area")).replace("_", " ")))
		message += _alarm_alert_text(entered)
	return {"success": true, "seconds": 6, "message": message, "entered_areas": entered, "spike_growth_outcomes": spike_growth_outcomes, "heat_outcomes": heat_outcomes, "movement_cost_feet": movement_cost_feet, "fall_damage": fall_damage}


## Authored heat is separate from surface traversal: Water Walk doesn't
## grant Fire immunity. The room author chooses damage and vertical reach.
static func resolve_surface_heat(state: Dictionary, target, position: Vector2i, altitude: int) -> Dictionary:
	for terrain in state.get("cell_terrains", []):
		if coord(terrain.get("position", [])) != position or not terrain.has("heat_damage_formula"):
			continue
		if altitude > elevation_feet(state, position) + int(terrain.get("heat_height_feet", 0)):
			return {}
		var formula := str(terrain["heat_damage_formula"])
		var amount := Dice.parse_dice_string(formula, {}, target if target is Character else null)
		var outcome := CombatAction.resolve_damage(target, amount, "fire")
		return {"spell_id": "surface_heat", "damage": int(outcome.get("resolved", 0)), "damage_formula": formula, "position": position}
	return {}


static func _ensure_party_altitudes(state: Dictionary) -> void:
	if not state.get("party_altitudes", null) is Dictionary:
		state["party_altitudes"] = {}
	if not state.get("party_altitude_modes", null) is Dictionary:
		state["party_altitude_modes"] = {}
	var altitudes: Dictionary = state["party_altitudes"]
	for id in state.get("party_positions", {}):
		if not altitudes.has(id):
			var position_value: Variant = state["party_positions"][id]
			if position_value is Array:
				altitudes[id] = elevation_feet(state, coord(position_value))
		if not state["party_altitude_modes"].has(id):
			state["party_altitude_modes"][id] = "ground"


static func resolve_area_entries(areas: Array, character: Character) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	if character == null or not character.is_alive:
		return results
	var resolved_tentacle_area_ids: Dictionary = {}
	for area in areas:
		if not area is Dictionary:
			continue
		var spell_id := str(area.get("spell_id", ""))
		var area_id := str(area.get("id", ""))
		if area.get("hazard_kind", "") == "entry_damage":
			var hazard := LocalRoomAreas.resolve_aftermath_entry(area, character)
			if not hazard.is_empty(): results.append(hazard)
		elif spell_id == "grease":
			if resolved_tentacle_area_ids.has(area_id):
				continue
			resolved_tentacle_area_ids[area_id] = true
			var grease_dc := int(area.get("save_dc", 0))
			var grease_save := character.saving_throw_test_to_dc("DEX", grease_dc)
			var grease_failed := not bool(grease_save.get("success", false))
			if grease_failed:
				CombatAction.apply_condition(character, "prone", 99)
			results.append({"spell_id": spell_id, "save_total": int(grease_save.get("total", 0)), "save_dc": grease_dc, "saved": not grease_failed, "condition": "prone" if grease_failed else ""})
		elif spell_id == "sleet_storm":
			var storm_dc := int(area.get("save_dc", 0))
			var storm_save := character.saving_throw_test_to_dc("DEX", storm_dc)
			var storm_failed := not bool(storm_save.get("success", false))
			if storm_failed:
				CombatAction.apply_condition(character, "prone", 99)
			results.append({"spell_id": spell_id, "save_total": int(storm_save.get("total", 0)), "save_dc": storm_dc, "saved": not storm_failed, "condition": "prone" if storm_failed else ""})
		elif spell_id == "moonbeam":
			results.append(_resolve_local_moonbeam_save(area, character))
		elif spell_id == "black_tentacles":
			if resolved_tentacle_area_ids.has(area_id):
				continue
			resolved_tentacle_area_ids[area_id] = true
			results.append(_resolve_black_tentacles_save(area, character))
		elif spell_id == "cloud_of_daggers":
			var damage_formula := str(area.get("damage_formula", "4d4"))
			var damage := Dice.parse_dice_string(damage_formula, {}, character)
			var damage_result := CombatAction.resolve_damage(character, damage, "slashing")
			results.append({"spell_id": spell_id, "damage": int(damage_result.get("resolved", 0)), "damage_formula": damage_formula})
		elif spell_id == "wall_of_fire":
			results.append(_resolve_wall_of_fire_room_damage(area, character))
	return results


static func end_local_turn(state: Dictionary, character: Character) -> Dictionary:
	if character != null and ContainmentRules.involved(state, "character", character.character_id): return failure("Internal occupants and occupied containers require release before changing location.")
	if character == null or not character.is_alive or CombatAction.is_incapacitated(character):
		return failure("That character cannot end a turn here.")
	var outcomes := end_turn_area_saves(state, character)
	var heat := resolve_surface_heat(state, character, coord(state["party_positions"][character.character_id]), altitude_feet(state, character.character_id))
	if not heat.is_empty(): outcomes.append(heat)
	return {"success": true, "seconds": 6, "message": "%s ends a turn." % character.character_name, "end_turn_outcomes": outcomes}


static func advance_burning_objects(state: Dictionary, now_seconds: int) -> Array[String]:
	var messages: Array[String] = []
	for object_value in state.get("objects", []):
		if not object_value is Dictionary:
			continue
		var object: Dictionary = object_value
		if not bool(object.get("burning", false)) or int(object.get("hp", 1)) <= 0:
			continue
		# Legacy saves have no start time. Begin ticking from this visit rather than
		# guessing how long the object has already burned.
		if not object.has("burning_next_tick_seconds"):
			object["burning_next_tick_seconds"] = now_seconds + 6
			continue
		var next_tick := int(object.get("burning_next_tick_seconds", now_seconds + 6))
		while next_tick <= now_seconds and bool(object.get("burning", false)) and int(object.get("hp", 1)) > 0:
			var rolled_damage := Dice.roll(4)
			var damage := CombatObjectRules.apply_damage(object, rolled_damage, "fire")
			messages.append("%s takes %d Fire damage from burning." % [str(object.get("name", "The object")), damage])
			next_tick += 6
			object["burning_next_tick_seconds"] = next_tick
			if int(object.get("hp", 1)) <= 0:
				object["burning"] = false
				object.erase("burning_next_tick_seconds")
				messages.append("%s burns out." % str(object.get("name", "The object")))
			elif _room_fire_exposes(object):
				messages.append_array(_spread_room_object_fire(state, object, now_seconds))
	return messages


static func _spread_room_object_fire(state: Dictionary, source: Dictionary, now_seconds: int) -> Array[String]:
	var messages: Array[String] = []
	var source_position := coord(source.get("position", [9999, 9999]))
	for target_value in state.get("objects", []):
		if not target_value is Dictionary:
			continue
		var target: Dictionary = target_value
		if target == source or bool(target.get("burning", false)) or not CombatObjectRules.can_take_spell_damage(target) or not CombatObjectRules.is_flammable(target) or not _room_fire_exposes(target):
			continue
		if HexUtils.get_distance(source_position, coord(target.get("position", [9999, 9999]))) > 1:
			continue
		if CombatObjectRules.ignite(target):
			# A fire resolved after returning to the room spreads now; newly caught
			# objects begin their own six-second burn schedule from this tick.
			target["burning_next_tick_seconds"] = now_seconds + 6
			messages.append("%s catches fire from %s." % [str(target.get("name", "An object")), str(source.get("name", "nearby flames"))])
	return messages


static func _room_fire_exposes(object: Dictionary) -> bool:
	if not bool(object.get("fire_exposed", true)):
		return false
	return str(object.get("kind", "")) != "container" or bool(object.get("open", false))


static func end_turn_area_saves(state: Dictionary, character: Character) -> Array[Dictionary]:
	var outcomes: Array[Dictionary] = []
	if character == null or not character.is_alive or not state.get("party_positions", {}).has(character.character_id):
		return outcomes
	LocalRoomAreas.expire(state, int(GameManager.campaign_elapsed_seconds))
	var position := coord(state["party_positions"][character.character_id])
	var turn_index := int(floor(float(GameManager.campaign_elapsed_seconds) / 6.0))
	for area in state.get("areas", []):
		if not area is Dictionary or str(area.get("spell_id", "")) not in ["cloud_of_daggers", "black_tentacles", "grease", "sleet_storm", "moonbeam", "wall_of_fire"] or not LocalRoomAreas.contains(area, position):
			continue
		var checked_turns: Dictionary = area.get("check_turn_by_character", {})
		var trigger_id := "%s:end" % character.character_id if str(area.get("spell_id", "")) == "wall_of_fire" else character.character_id
		if int(checked_turns.get(trigger_id, -1)) == turn_index:
			continue
		checked_turns[trigger_id] = turn_index
		area["check_turn_by_character"] = checked_turns
		if str(area.get("spell_id", "")) == "cloud_of_daggers":
			var damage_formula := str(area.get("damage_formula", "4d4"))
			var damage := Dice.parse_dice_string(damage_formula, {}, character)
			var damage_result := CombatAction.resolve_damage(character, damage, "slashing")
			outcomes.append({"spell_id": "cloud_of_daggers", "damage": int(damage_result.get("resolved", 0)), "damage_formula": damage_formula})
		elif str(area.get("spell_id", "")) == "black_tentacles":
			outcomes.append(_resolve_black_tentacles_save(area, character))
		elif str(area.get("spell_id", "")) == "moonbeam":
			outcomes.append(_resolve_local_moonbeam_save(area, character))
		elif str(area.get("spell_id", "")) == "grease":
			var grease_dc := int(area.get("save_dc", 0))
			var grease_save := character.saving_throw_test_to_dc("DEX", grease_dc)
			var grease_failed := not bool(grease_save.get("success", false))
			if grease_failed:
				CombatAction.apply_condition(character, "prone", 99)
			outcomes.append({"spell_id": "grease", "save_total": int(grease_save.get("total", 0)), "save_dc": grease_dc, "saved": not grease_failed, "condition": "prone" if grease_failed else ""})
		elif str(area.get("spell_id", "")) == "sleet_storm":
			var storm_dc := int(area.get("save_dc", 0))
			var storm_save := character.saving_throw_test_to_dc("DEX", storm_dc)
			var storm_failed := not bool(storm_save.get("success", false))
			if storm_failed:
				CombatAction.apply_condition(character, "prone", 99)
			outcomes.append({"spell_id": "sleet_storm", "save_total": int(storm_save.get("total", 0)), "save_dc": storm_dc, "saved": not storm_failed, "condition": "prone" if storm_failed else ""})
		else:
			outcomes.append(_resolve_wall_of_fire_room_damage(area, character))
	return outcomes


static func _resolve_wall_of_fire_room_damage(area: Dictionary, character: Character) -> Dictionary:
	var formula := str(area.get("damage_formula", "5d8"))
	var rolled := Dice.parse_dice_string(formula, {}, character)
	var damage := CombatAction.resolve_damage(character, rolled, "fire")
	return {"spell_id": "wall_of_fire", "damage": int(damage.get("resolved", 0)), "damage_formula": formula}


static func _resolve_local_moonbeam_save(area: Dictionary, character: Character) -> Dictionary:
	var dc := int(area.get("save_dc", 0))
	var save := character.saving_throw_test_to_dc("CON", dc)
	var failed := not bool(save.get("success", false))
	var damage_formula := str(area.get("damage_formula", "2d10"))
	var rolled_damage := Dice.parse_dice_string(damage_formula, {}, character)
	var damage_to_apply := rolled_damage if failed else int(floor(float(rolled_damage) / 2.0))
	var damage := CombatAction.resolve_damage(character, damage_to_apply, "radiant")
	var reverted := false
	var source_id := str(area.get("concentration_source_id", ""))
	if failed and DruidRules.is_shaped(character):
		reverted = DruidRules.revert(character)
		if reverted and not source_id.is_empty():
			CombatAction.apply_condition(character, "moonbeam_shape_lock", 99, "%s:shape_lock" % source_id)
	return {"spell_id": "moonbeam", "save_total": int(save.get("total", 0)), "save_dc": dc, "saved": not failed, "damage": int(damage.get("resolved", 0)), "damage_formula": damage_formula, "shape_reverted": reverted}


static func escape_black_tentacles(state: Dictionary, character: Character) -> Dictionary:
	if character == null or not character.is_alive or CombatAction.is_incapacitated(character):
		return failure("That character cannot escape.")
	var position_value: Variant = state.get("party_positions", {}).get(character.character_id, null)
	if not position_value is Array or not character.has_condition("restrained"):
		return failure("That character is not Restrained here.")
	var position := coord(position_value)
	for area in state.get("areas", []):
		if not area is Dictionary or str(area.get("spell_id", "")) != "black_tentacles" or not LocalRoomAreas.contains(area, position):
			continue
		var source_id := str(area.get("concentration_source_id", ""))
		if source_id.is_empty() or not character.condition_sources.get("restrained", {}).has(source_id):
			continue
		var dc := int(area.get("save_dc", 0))
		var check := EventResolver.resolve_skill_check(character, {"ability": "STR", "skill": "Athletics", "context": "escaping Black Tentacles", "dc": dc})
		if bool(check.get("success", false)):
			CombatAction.remove_condition_source(character, source_id, ["restrained"])
		return {"success": true, "seconds": 6, "message": "%s %s the Athletics escape check (%d vs DC %d)." % [character.character_name, "escapes Black Tentacles" if check.get("success", false) else "remains Restrained", int(check.get("total", 0)), dc], "escape_check": check}
	return failure("No active Black Tentacles area is holding this character.")


static func escape_entangle(state: Dictionary, character: Character) -> Dictionary:
	if character == null or not character.is_alive or CombatAction.is_incapacitated(character):
		return failure("That character cannot escape.")
	if not character.has_condition("restrained"):
		return failure("That character is not Restrained here.")
	for area in state.get("areas", []):
		if not area is Dictionary or str(area.get("spell_id", "")) != "entangle":
			continue
		var source_id := str(area.get("concentration_source_id", ""))
		if source_id.is_empty() or not character.condition_sources.get("restrained", {}).has(source_id):
			continue
		var dc := int(area.get("save_dc", 0))
		var check := EventResolver.resolve_skill_check(character, {"ability": "STR", "skill": "Athletics", "context": "escaping Entangle", "dc": dc})
		if bool(check.get("success", false)):
			CombatAction.remove_condition_source(character, source_id, ["restrained"])
		return {"success": true, "seconds": 6, "message": "%s %s the Athletics escape check (%d vs DC %d)." % [character.character_name, "escapes Entangle" if check.get("success", false) else "remains Restrained", int(check.get("total", 0)), dc], "escape_check": check}
	return failure("No active Entangle area is holding this character.")


static func escape_nonmagical_restraint(character: Character) -> Dictionary:
	if character == null or not character.is_alive or not SpellEffects.has_spell(character, "freedom_of_movement"):
		return failure("Freedom of Movement is required to escape a nonmagical restraint this way.")
	if not CombatAction.escape_nonmagical_restraint(character):
		return failure("No nonmagical restraint is holding this character.")
	return {"success": true, "seconds": 6, "message": "%s spends 5 feet of movement and escapes the nonmagical restraint." % character.character_name}


static func _resolve_black_tentacles_save(area: Dictionary, character: Character) -> Dictionary:
	var dc := int(area.get("save_dc", 0))
	var save := character.saving_throw_test_to_dc("STR", dc)
	var failed := not bool(save.get("success", false))
	var damage := 0
	var source_id := str(area.get("concentration_source_id", ""))
	if failed:
		damage = Dice.parse_dice_string("3d6", {}, character)
		CombatAction.resolve_damage(character, damage, "bludgeoning")
		CombatAction.apply_condition(character, "restrained", 99, source_id)
	else:
		CombatAction.remove_condition_source(character, source_id, ["restrained"])
	return {"spell_id": "black_tentacles", "save_total": int(save.get("total", 0)), "save_dc": dc, "saved": not failed, "damage": damage, "condition": "restrained" if failed and character.has_condition("restrained") else ""}


static func interact(state: Dictionary, id: String, action: String, character: Character, instance_id: String = "") -> Dictionary:
	if ContainmentRules.involved(state, "object", id) or (character != null and not ContainmentRules.relation(state, "character", character.character_id).is_empty()): return failure("Internal interaction and occupied container changes require release support.")
	var object := get_object(state, id)
	if object.is_empty() or bool(object.get("removed", false)): return failure("Object is no longer here.")
	if character == null or not character.is_alive or CombatAction.is_incapacitated(character): return failure("That character cannot interact.")
	var origin := coord(state.get("party_positions", {}).get(character.character_id, [-999, -999]))
	if HexUtils.get_distance(origin, coord(object["position"])) > 1: return failure("Move next to the object first.")
	if action == "strike":
		var weapon := DataLoader.get_item(character.inventory.get_weapon())
		if weapon.is_empty(): return failure("Equip a weapon before striking the barrier.")
		if not CombatObjectRules.can_take_spell_damage(object): return failure("That object cannot be damaged here.")
		var target := CombatObjectRules.make_resolution_target(object)
		# Resolve the attack/weapon roll once; the object boundary then applies
		# its authored immunities, resistances and threshold once.
		target["damage_immunities"] = []
		target["damage_resistances"] = []
		target["damage_vulnerabilities"] = []
		var result := CombatAction.resolve_weapon_attack(character, target, weapon)
		var dealt := CombatObjectRules.apply_damage(object, int(result.get("damage", 0)), str(weapon.get("damage_type", "bludgeoning"))) if bool(result.get("hit", false)) else 0
		return {"success": true, "seconds": 6, "message": "%s strikes %s and deals %d damage%s." % [character.character_name, str(object["name"]), dealt, "; the barrier breaks" if int(object.get("hp", 1)) == 0 else ""], "damage": dealt, "hit": bool(result.get("hit", false))}
	var alarm_areas: Array[Dictionary] = []
	if action in ["open", "close", "lock", "unlock", "pick_lock", "pry"]:
		alarm_areas = LocalRoomAreas.touch_object(state, character.character_id, id, int(GameManager.campaign_elapsed_seconds))
	var alarm_suffix := _alarm_alert_text(alarm_areas)
	if action == "inspect":
		var environment := _environment_description(object)
		return {"success": true, "seconds": 0, "message": "%s — %s; %d/%d HP; %s, %s%s%s. %s" % [object["name"], RoomMeasurements.describe_object(object), object.get("hp", 1), object.get("max_hp", 1), "open" if object.get("open", false) else "closed", "locked" if object.get("locked", false) else "unlocked", "; burning" if object.get("burning", false) else "", "; " + environment if not environment.is_empty() else "", object.get("description", "")]}
	match action:
		"extinguish":
			if not CombatObjectRules.extinguish(object): return failure("This object is not burning.")
		"open", "close":
			if str(object.get("kind", "")) not in ["door", "container"]: return failure("This object cannot be opened." + alarm_suffix)
			if action == "open" and bool(object.get("locked", false)): return failure("It is locked." + alarm_suffix)
			object["open"] = action == "open"
		"unlock", "lock":
			if not bool(object.get("lockable", false)): return failure("There is no lock." + alarm_suffix)
			if action == "lock" and bool(object.get("open", false)): return failure("Close it before locking." + alarm_suffix)
			if not character.inventory.has_item(str(object.get("key_id", ""))): return failure("The matching key must be in your backpack." + alarm_suffix)
			object["locked"] = action == "lock"
		"pick_lock":
			if not object.get("locked", false): return failure("It is already unlocked." + alarm_suffix)
			if not character.inventory.has_item("thieves_tools"): return failure("Thieves' Tools are required." + alarm_suffix)
			var check := EventResolver.resolve_skill_check(character, {"ability": "DEX", "skill": "Sleight of Hand", "dc": int(object.get("lock_dc", 15))})
			if not check["success"]: return {"success": false, "seconds": 6, "message": "Lock check %d vs DC %d: still locked." % [check["total"], check["dc"]] + alarm_suffix}
			object["locked"] = false
		"pry":
			if not bool(object.get("lockable", false)) or not bool(object.get("locked", false)) or bool(object.get("open", false)): return failure("There is no closed locked object to pry open." + alarm_suffix)
			if not character.inventory.has_item("crowbar"): return failure("A Crowbar is required to pry this object open." + alarm_suffix)
			var pry_check := EventResolver.resolve_skill_check(character, {"ability": "STR", "skill": "Athletics", "context": "prying", "dc": int(object.get("lock_dc", 15))})
			if not pry_check["success"]: return {"success": false, "seconds": 6, "message": "Prying check %d vs DC %d: still locked." % [pry_check["total"], pry_check["dc"]] + alarm_suffix}
			object["locked"] = false
			object["open"] = true
		"take":
			if str(object.get("kind", "")) == "loose" and bool(object.get("fixed", false)): return failure("Detach the object before picking it up.")
			if str(object.get("kind", "")) == "container" and not bool(object.get("open", false)): return failure("Open the container first.")
			var contents: Array = object.get("contents", [])
			var selected := -1
			for index in contents.size():
				if str(contents[index]["instance_id"]) == instance_id: selected = index; break
			if selected < 0: return failure("Select an item that is still here.")
			var record: Dictionary = contents[selected].duplicate(true)
			if str(object.get("kind", "")) == "loose":
				record["state"]["combat_object_hp"] = int(object.get("hp", 1))
				record["state"]["physical"] = {"room_id": state["id"], "object_id": object["id"]}
				for field in ["material", "size", "weight_lb", "fixed", "hp", "max_hp"]:
					if object.has(field): record["state"]["physical"][field] = object[field]
				record["state"]["physical"] = RoomMeasurements.known_fields(record["state"]["physical"], str(record.get("definition_id", ""))) # S-032
			if not character.inventory.receive_instance(record): return failure("Your backpack is full or that item cannot be received.")
			contents.remove_at(selected)
			if str(object.get("kind", "")) == "loose" and contents.is_empty(): object["removed"] = true
		"put":
			if str(object.get("kind", "")) != "container" or not bool(object.get("open", false)): return failure("Choose an open container.")
			if object["contents"].size() >= int(object.get("capacity", 20)): return failure("The container is full.")
			var record := character.inventory.take_instance(instance_id)
			if record.is_empty(): return failure("Select an item from your backpack.")
			object["contents"].append(record)
		_:
			return failure("That interaction is unsupported.")
	var message := "%s: %s." % [object["name"], action.replace("_", " ")]
	message += alarm_suffix
	return {"success": true, "seconds": 6, "message": message}


static func fire_bolt_object(state: Dictionary, id: String, character: Character, grid: HexGrid) -> Dictionary:
	if ContainmentRules.involved(state, "object", id) or (character != null and not ContainmentRules.relation(state, "character", character.character_id).is_empty()): return failure("Internal targeting and occupied-container damage are unavailable.")
	var spell := DataLoader.get_spell("fire_bolt")
	var caster_error := _room_spell_caster_error(character, spell)
	if not caster_error.is_empty(): return failure(caster_error)
	var object := get_object(state, id)
	if not CombatObjectRules.can_take_spell_damage(object): return failure("Choose an unattended nonmagical object.")
	var origin := coord(state.get("party_positions", {}).get(character.character_id, [-999, -999]))
	var position := coord(object["position"])
	if not Targeting.is_in_range(origin, position, int(spell.get("range", 24))) or not Targeting.has_line_of_sight(origin, position, grid): return failure("Choose an object within range and an unobstructed path.")
	var target := CombatObjectRules.make_resolution_target(object)
	target["damage_immunities"] = []
	target["damage_resistances"] = []
	target["damage_vulnerabilities"] = []
	var result := CombatAction.resolve_spell(character, target, spell, false, {}, [], 0, HexUtils.get_distance(origin, position) * 5)
	var hit := bool(result.get("hit", false))
	var dealt := CombatObjectRules.apply_damage(object, int(result.get("damage", 0)), "fire") if hit else 0
	var ignited := hit and CombatObjectRules.ignite(object)
	return {"success": true, "seconds": 6, "damage": dealt, "hit": hit, "ignited": ignited, "message": "%s casts Fire Bolt at %s: %s%s." % [character.character_name, str(object["name"]), "%d Fire damage" % dealt if hit else "miss", "; catches fire" if ignited else ""]}


static func cast_alarm(state: Dictionary, id: String, alert_mode: String, character: Character, party: Array, ritual: bool = false) -> Dictionary:
	var door := get_object(state, id)
	if door.is_empty() or bool(door.get("removed", false)) or str(door.get("kind", "")) != "door":
		return failure("Alarm can be placed on a door in this room.")
	if alert_mode not in ["audible", "mental"]: return failure("Choose an audible or mental Alarm.")
	if character == null or not character.is_alive or CombatAction.is_incapacitated(character): return failure("That character cannot cast a spell.")
	var spell := DataLoader.get_spell("alarm")
	var caster_error := _room_spell_caster_error(character, spell)
	if not caster_error.is_empty(): return failure(caster_error)
	var origin := coord(state.get("party_positions", {}).get(character.character_id, [-999, -999]))
	var center := coord(door["position"])
	if HexUtils.get_distance(origin, center) > CombatAction.spell_range_in_hexes(spell, character.level):
		return failure("Choose a door within Alarm's range.")
	var now := int(GameManager.campaign_elapsed_seconds)
	for area in state.get("areas", []):
		if str(area.get("spell_id", "")) == "alarm" and str(area.get("warded_object_id", "")) == id and int(area.get("expires_at_seconds", 0)) > now:
			return failure("This door already has an active Alarm.")
	if ritual and not bool(spell.get("ritual", false)): return failure("Alarm cannot be cast as a ritual.")
	var spent: Dictionary = {}
	if not ritual:
		spent = CombatAction.spend_spell_slot(character, spell)
		if not spent.get("success", false): return failure(str(spent.get("message", "No level 1 spell slot remains.")))
	var ignored: Array[String] = []
	for member in party:
		if member is Character: ignored.append(member.character_id)
	var duration := int(spell.get("duration_seconds", 0))
	# A 20-foot cube is represented by a small radius on the room's five-foot hex grid.
	var added := LocalRoomAreas.add(state, "alarm", character.character_id, center, 2, duration, 1000, {
		"alert_mode": alert_mode,
		"caster_name": character.character_name,
		"warded_object_id": id,
		"ignored_character_ids": ignored,
		"audible_duration_seconds": 10,
		"audible_radius_feet": 60,
		"mental_range_feet": 5280,
		"mental_wakes_if_asleep": true,
	})
	if not added.get("success", false): return failure(str(added.get("message", "The ward could not be placed.")))
	if not ritual and not bool(spent.get("slot_recalled", false)):
		WardRules.on_slot_spell_cast(character, spell, int(spent.get("slot_level", 1)))
	var seconds := 660 if ritual else int(spell.get("casting_time_seconds", 60))
	return {"success": true, "seconds": seconds, "message": "%s sets an %s Alarm on %s for eight hours%s." % [character.character_name, alert_mode, door.get("name", "the door"), " as a ritual" if ritual else ""]}


static func purify_food_and_drink(state: Dictionary, id: String, character: Character) -> Dictionary:
	var center_object := get_object(state, id)
	if center_object.is_empty() or bool(center_object.get("removed", false)):
		return failure("That food or drink is no longer here.")
	if character == null or not character.is_alive or CombatAction.is_incapacitated(character):
		return failure("That character cannot cast a spell.")
	var spell := DataLoader.get_spell("purify_food_and_drink")
	var caster_error := _room_spell_caster_error(character, spell)
	if not caster_error.is_empty(): return failure(caster_error)
	var origin := coord(state.get("party_positions", {}).get(character.character_id, [-999, -999]))
	var center := coord(center_object["position"])
	if HexUtils.get_distance(origin, center) > CombatAction.spell_range_in_hexes(spell, character.level):
		return failure("Choose a point within Purify Food and Drink's range.")
	var radius_hexes := int(ceil(float(spell.get("area_radius_feet", 5)) / 5.0))
	var affected: Array[Dictionary] = []
	for object in state.get("objects", []):
		if bool(object.get("removed", false)) or bool(object.get("magical", false)) or not bool(object.get("food_or_drink", false)):
			continue
		if HexUtils.get_distance(center, coord(object["position"])) > radius_hexes:
			continue
		var contamination: Array = object.get("contamination", [])
		if contamination.any(func(kind): return str(kind) in spell.get("removes", [])):
			affected.append(object)
	if affected.is_empty():
		return failure("There is no contaminated nonmagical food or drink in that area.")
	var spent := CombatAction.spend_spell_slot(character, spell)
	if not spent.get("success", false):
		return failure(str(spent.get("message", "No level 1 spell slot remains.")))
	var names: Array[String] = []
	for object in affected:
		var remaining: Array = []
		for kind in object.get("contamination", []):
			if str(kind) not in spell.get("removes", []):
				remaining.append(kind)
		object["contamination"] = remaining
		if "disease" in spell.get("removes", []) and not "disease" in remaining:
			object["contamination_sources"] = []
		names.append(str(object.get("name", "Food or drink")))
	return {"success": true, "seconds": 6, "message": "Purify Food and Drink clears poison and disease from %s." % ", ".join(names)}


static func create_or_destroy_water(state: Dictionary, id: String, mode: String, character: Character) -> Dictionary:
	var container := get_object(state, id)
	if container.is_empty() or bool(container.get("removed", false)):
		return failure("That water container is no longer here.")
	if mode not in ["create", "destroy"] or str(container.get("kind", "")) != "container" or not bool(container.get("food_or_drink", false)) or bool(container.get("magical", false)):
		return failure("Choose an eligible nonmagical water container.")
	if not bool(container.get("open", false)):
		return failure("The container must be open.")
	if character == null or not character.is_alive or CombatAction.is_incapacitated(character):
		return failure("That character cannot cast a spell.")
	var spell := DataLoader.get_spell("create_or_destroy_water")
	var caster_error := _room_spell_caster_error(character, spell)
	if not caster_error.is_empty(): return failure(caster_error.replace("Purify Food and Drink", "Create or Destroy Water"))
	var origin := coord(state.get("party_positions", {}).get(character.character_id, [-999, -999]))
	if HexUtils.get_distance(origin, coord(container["position"])) > CombatAction.spell_range_in_hexes(spell, character.level):
		return failure("Choose a container within Create or Destroy Water's range.")
	var water_before := float(container.get("water_gallons", 0.0))
	var capacity := float(container.get("capacity_gallons", 0.0))
	var base_change := minf(10.0, capacity - water_before) if mode == "create" else minf(10.0, water_before)
	if base_change <= 0:
		return failure("There is no capacity for more water." if mode == "create" else "The container has no water to destroy.")
	var spent := CombatAction.spend_spell_slot(character, spell)
	if not spent.get("success", false):
		return failure(str(spent.get("message", "No level 1 spell slot remains.")))
	var maximum_change := float(10 + 10 * maxi(0, int(spent.get("slot_level", 1)) - 1))
	var changed := minf(maximum_change, capacity - water_before) if mode == "create" else minf(maximum_change, water_before)
	container["water_gallons"] = water_before + changed if mode == "create" else water_before - changed
	var verb := "creates" if mode == "create" else "destroys"
	return {"success": true, "seconds": 6, "message": "Create or Destroy Water %s %s gallons in %s." % [verb, _quantity_text(changed), container.get("name", "the container")]}


static func create_or_destroy_water_area(state: Dictionary, mode: String, center: Vector2i, character: Character, party: Array) -> Dictionary:
	if mode not in ["rain", "clear_fog"]:
		return failure("Choose rain or fog removal.")
	if not _room_contains(state, center):
		return failure("Choose an area inside the local room.")
	if character == null or not character.is_alive or CombatAction.is_incapacitated(character):
		return failure("That character cannot cast a spell.")
	var spell := DataLoader.get_spell("create_or_destroy_water")
	var caster_error := _room_spell_caster_error(character, spell)
	if not caster_error.is_empty(): return failure(caster_error.replace("Purify Food and Drink", "Create or Destroy Water"))
	var origin_value: Variant = state.get("party_positions", {}).get(character.character_id, null)
	if not origin_value is Array:
		return failure("The caster must be in the local room.")
	var origin := coord(origin_value)
	if HexUtils.get_distance(origin, center) > CombatAction.spell_range_in_hexes(spell, character.level):
		return failure("Choose a cube within Create or Destroy Water's range.")
	var spent := CombatAction.spend_spell_slot(character, spell)
	if not spent.get("success", false):
		return failure(str(spent.get("message", "No level 1 spell slot remains.")))
	var slot_level := int(spent.get("slot_level", 1))
	var cube_radius := _water_cube_radius(slot_level)
	var changed := 0
	if mode == "rain":
		for object_value in state.get("objects", []):
			if not object_value is Dictionary:
				continue
			var object: Dictionary = object_value
			if bool(object.get("removed", false)) or not bool(object.get("burning", false)) or not _rain_exposes(object):
				continue
			if HexUtils.get_distance(center, coord(object.get("position", [9999, 9999]))) > cube_radius:
				continue
			if CombatObjectRules.extinguish(object):
				changed += 1
		for target in party:
			if not target is Character:
				continue
			var target_position: Variant = state.get("party_positions", {}).get(target.character_id, null)
			if not target_position is Array or HexUtils.get_distance(center, coord(target_position)) > cube_radius:
				continue
			for record in target.inventory.owned_instances():
				if str(record.get("definition_id", "")) != "torch" or not LightSourceRules.is_lit(record):
					continue
				var extinguished: Dictionary = record.duplicate(true)
				var item_state: Dictionary = extinguished.get("state", {}).duplicate(true)
				item_state["light_source_lit"] = false
				extinguished["state"] = item_state
				if target.inventory.update_instance(extinguished):
					changed += 1
		var rain_message := "Rain falls in the %d-hex cube" % cube_radius
		if changed > 0:
			rain_message += " and extinguishes %d exposed flame%s" % [changed, "" if changed == 1 else "s"]
		else:
			rain_message += "; there are no modeled exposed flames to extinguish"
		return {"success": true, "seconds": 6, "slot_level": slot_level, "area_radius_hexes": cube_radius, "message": rain_message + "."}
	var cube_cells: Dictionary = {}
	for cell in state.get("cells", []):
		var position := coord(cell)
		if HexUtils.get_distance(center, position) <= cube_radius:
			cube_cells[position] = true
	var cleared_clouds := 0
	for area_value in state.get("areas", []).duplicate():
		if not area_value is Dictionary or str(area_value.get("spell_id", "")) != "fog_cloud":
			continue
		var area: Dictionary = area_value
		var cloud_center := coord(area.get("center", [0, 0]))
		var cloud_cells: Array[Vector2i] = []
		if area.has("footprint"):
			for cell in area.get("footprint", []):
				cloud_cells.append(coord(cell))
		else:
			for cell in state.get("cells", []):
				var position := coord(cell)
				if HexUtils.get_distance(cloud_center, position) <= int(area.get("radius_hexes", 0)):
					cloud_cells.append(position)
		var remaining_cloud_cells: Array[Vector2i] = []
		for cloud_cell in cloud_cells:
			if not cube_cells.has(cloud_cell):
				remaining_cloud_cells.append(cloud_cell)
		if remaining_cloud_cells.size() == cloud_cells.size():
			continue
		cleared_clouds += 1
		var caster_id := str(area.get("caster_id", ""))
		var source_id := str(area.get("concentration_source_id", ""))
		if remaining_cloud_cells.is_empty():
			LocalRoomAreas.remove_concentration(state, caster_id, "fog_cloud", source_id)
			var fog_caster := _party_character(party, caster_id)
			if fog_caster != null and str(fog_caster.concentrating_on.get("fog_cloud_source_id", "")) == source_id:
				SpellEffects.end_concentration(fog_caster, party)
		else:
			var footprint: Array = []
			for cloud_cell in remaining_cloud_cells:
				footprint.append([cloud_cell.x, cloud_cell.y])
			area["footprint"] = footprint
	var fog_message := "Create or Destroy Water removes fog from the %d-hex cube" % cube_radius
	if cleared_clouds == 0:
		fog_message += "; no Fog Cloud was affected"
	else:
		fog_message += " and affects %d Fog Cloud area%s" % [cleared_clouds, "" if cleared_clouds == 1 else "s"]
	return {"success": true, "seconds": 6, "slot_level": slot_level, "area_radius_hexes": cube_radius, "message": fog_message + "."}


static func _water_cube_radius(slot_level: int) -> int:
	var cube_side_feet := 30 + 5 * maxi(0, slot_level - 1)
	return int(ceil(float(cube_side_feet - 5) / 10.0))


static func _rain_exposes(object: Dictionary) -> bool:
	if not bool(object.get("rain_exposed", true)):
		return false
	return str(object.get("kind", "")) != "container" or bool(object.get("open", false))


static func _room_contains(state: Dictionary, position: Vector2i) -> bool:
	for cell in state.get("cells", []):
		if coord(cell) == position:
			return true
	return false


static func _party_character(party: Array, character_id: String) -> Character:
	for character in party:
		if character is Character and character.character_id == character_id:
			return character
	return null


static func eat_food(state: Dictionary, id: String, character: Character, pounds: float = 1.0) -> Dictionary:
	var object := get_object(state, id)
	if object.is_empty() or bool(object.get("removed", false)) or not bool(object.get("food_or_drink", false)) or bool(object.get("magical", false)):
		return failure("Choose present, nonmagical food.")
	if not object.get("contamination", []).is_empty(): return failure("The food is contaminated; purify it first.")
	if float(object.get("food_servings", 0.0)) <= 0.0: return failure("There is no food remaining.")
	if character == null or not character.is_alive or CombatAction.is_incapacitated(character): return failure("That character cannot eat now.")
	if HexUtils.get_distance(coord(state.get("party_positions", {}).get(character.character_id, [-999, -999])), coord(object["position"])) > 1: return failure("Move next to the food first.")
	var consumed := minf(maxf(0.0, pounds), float(object.get("food_servings", 0.0)))
	if consumed <= 0.0: return failure("Choose a positive amount of food.")
	object["food_servings"] = maxf(0.0, float(object.get("food_servings", 0.0)) - consumed)
	character.record_food_intake(consumed)
	return {"success": true, "seconds": 6, "message": "%s eats %s lb of food." % [character.character_name, _quantity_text(consumed)]}


static func drink_water(state: Dictionary, id: String, character: Character, gallons: float = 1.0) -> Dictionary:
	var object := get_object(state, id)
	if object.is_empty() or bool(object.get("removed", false)) or not bool(object.get("food_or_drink", false)) or bool(object.get("magical", false)):
		return failure("Choose a present, nonmagical water source.")
	var contamination: Array = object.get("contamination", [])
	var contamination_sources: Array = object.get("contamination_sources", [])
	var has_sight_rot := "disease" in contamination and "sight_rot" in contamination_sources and float(object.get("water_gallons", 0.0)) > 0.0
	if not contamination.is_empty() and not has_sight_rot: return failure("The water is contaminated; purify it first.")
	if float(object.get("water_gallons", 0.0)) <= 0.0: return failure("There is no water remaining.")
	if character == null or not character.is_alive or CombatAction.is_incapacitated(character): return failure("That character cannot drink now.")
	if HexUtils.get_distance(coord(state.get("party_positions", {}).get(character.character_id, [-999, -999])), coord(object["position"])) > 1: return failure("Move next to the water first.")
	var consumed := minf(maxf(0.0, gallons), float(object.get("water_gallons", 0.0)))
	if consumed <= 0.0: return failure("Choose a positive amount of water.")
	object["water_gallons"] = maxf(0.0, float(object.get("water_gallons", 0.0)) - consumed)
	character.record_water_intake(consumed)
	var message := "%s drinks %s gallon%s of water." % [character.character_name, _quantity_text(consumed), "" if is_equal_approx(consumed, 1.0) else "s"]
	var exposure := _expose_sight_rot(character) if has_sight_rot else {"exposed": false}
	if bool(exposure.get("exposed", false)):
		if bool(exposure.get("infected", false)):
			message += " The Sight Rot takes hold; %s is Blinded until the contagion ends." % character.character_name
		else:
			message += " %s resists the Sight Rot." % character.character_name
	return {"success": true, "seconds": 6, "message": message, "disease_exposure": exposure}


static func _expose_sight_rot(character: Character) -> Dictionary:
	var creature_type := character.get_creature_type().to_lower()
	if creature_type not in ["beast", "humanoid"]:
		return {"exposed": false, "immune_by_type": true}
	if character.saving_throw_to_dc("CON", 15) >= 15:
		return {"exposed": true, "infected": false, "save_dc": 15}
	if not CombatAction.is_immune_to_condition(character, "blinded"):
		var sources: Dictionary = character.condition_sources.get("blinded", {})
		if sources.is_empty() and int(character.conditions.get("blinded", 0)) > 0:
			sources["ordinary"] = int(character.conditions["blinded"])
		sources["disease:sight_rot"] = -1
		character.condition_sources["blinded"] = sources
		character.conditions["blinded"] = int(sources.values().max())
	return {"exposed": true, "infected": true, "disease": "sight_rot", "save_dc": 15}


static func eat_goodberry(casters: Array, character: Character) -> Dictionary:
	if character == null or not character.is_alive or CombatAction.is_incapacitated(character): return failure("That character cannot eat now.")
	if SpellEffects.goodberry_count_for_party(casters) < 1 or not SpellEffects.consume_goodberry_from_party(casters): return failure("No Goodberries are available.")
	character.add_nourishment()
	var healing := character.heal(1)
	return {"success": true, "seconds": 6, "message": "%s eats a Goodberry, regains %d HP, and is nourished for a day." % [character.character_name, healing]}


static func prestidigitation(state: Dictionary, id: String, mode: String, character: Character) -> Dictionary:
	var object := get_object(state, id)
	if object.is_empty() or bool(object.get("removed", false)) or bool(object.get("magical", false)):
		return failure("Choose a present, nonmagical object.")
	if mode not in ["clean", "soil", "warm", "cool"]:
		return failure("That Prestidigitation mode is unsupported.")
	if mode in ["clean", "soil"] and float(object.get("volume_cubic_feet", 1001.0)) > 1.0:
		return failure("Cleaning or soiling requires an object no larger than 1 cubic foot.")
	var spell := DataLoader.get_spell("prestidigitation")
	var caster_error := _room_spell_caster_error(character, spell)
	if not caster_error.is_empty(): return failure(caster_error)
	var origin := coord(state.get("party_positions", {}).get(character.character_id, [-999, -999]))
	if HexUtils.get_distance(origin, coord(object["position"])) > CombatAction.spell_range_in_hexes(spell, character.level):
		return failure("Choose an object within Prestidigitation's range.")
	match mode:
		"clean": object["dirty"] = false
		"soil": object["dirty"] = true
		"warm", "cool": object["temperature_effect"] = {"mode": mode, "expires_at": int(GameManager.campaign_elapsed_seconds) + 3600}
	var message := "%s %s%s." % [str(object.get("name", "The object")), mode, " for one hour" if mode in ["warm", "cool"] else ""]
	return {"success": true, "seconds": 6, "message": message}


static func cast_movement_spell(state: Dictionary, spell_id: String, character: Character, party: Array) -> Dictionary:
	if spell_id not in ["fly", "levitate", "spider_climb", "freedom_of_movement", "water_walk"]:
		return failure("That movement spell is not supported in local rooms.")
	var spell := DataLoader.get_spell(spell_id)
	var caster_error := _room_spell_caster_error(character, spell)
	if not caster_error.is_empty(): return failure(caster_error)
	_ensure_party_altitudes(state)
	if spell_id == "levitate":
		var position_value: Variant = state.get("party_positions", {}).get(character.character_id, null)
		if not position_value is Array: return failure("The character must be in the local room to Levitate.")
		var position := coord(position_value)
		var floor_feet := elevation_feet(state, position)
		var max_altitude := mini(floor_feet + 20, ceiling_feet(state, position) - 5)
		if altitude_feet(state, character.character_id) >= max_altitude: return failure("There is not enough room above this character to Levitate.")
	var spent := CombatAction.spend_spell_slot(character, spell)
	if not spent.get("success", false): return failure(str(spent.get("message", "No spell slot remains.")))
	if not bool(spent.get("slot_recalled", false)):
		WardRules.on_slot_spell_cast(character, spell, int(spent.get("slot_level", 1)))
	if bool(spell.get("concentration", false)):
		var previous_spell_id := str(character.concentrating_on.get("spell_id", ""))
		var previous_source_id := str(character.concentrating_on.get("%s_source_id" % previous_spell_id, ""))
		LocalRoomAreas.remove_concentration(state, character.character_id, previous_spell_id, previous_source_id)
		SpellEffects.end_concentration(character, party)
	var cast := SpellEffects.begin_cast(character, spell)
	SpellEffects.grant(character, cast, spell_id)
	if bool(spell.get("concentration", false)):
		character.concentrating_on = {"spell_id": spell_id, "effect_source": str(cast.get("source_id", "")), "targets": [character]}
	if spell_id == "fly":
		state["party_altitude_modes"][character.character_id] = "fly"
	if spell_id == "levitate":
		var position := coord(state["party_positions"][character.character_id])
		var current_altitude := altitude_feet(state, character.character_id)
		var floor_feet := elevation_feet(state, position)
		var target_altitude := mini(current_altitude + 20, mini(floor_feet + 20, ceiling_feet(state, position) - 5))
		state["party_altitudes"][character.character_id] = target_altitude
		state["party_altitude_modes"][character.character_id] = "levitate"
		return {"success": true, "seconds": 6, "message": "%s rises to %d feet and floats under Levitate." % [character.character_name, target_altitude], "altitude_feet": target_altitude}
	var movement_benefit := "a 60-foot flying speed" if spell_id == "fly" else "a climbing speed equal to its walking speed" if spell_id == "spider_climb" else "a swimming speed equal to its walking speed" if spell_id == "freedom_of_movement" else "the ability to move across water, acid, mud, snow, quicksand, and lava surfaces"
	return {"success": true, "seconds": 6, "message": "%s gains %s for the spell's duration." % [character.character_name, movement_benefit]}


static func cast_teleport(state: Dictionary, spell_id: String, character: Character, destination: Vector2i, grid: HexGrid, party: Array = []) -> Dictionary:
	if character != null and ContainmentRules.involved(state, "character", character.character_id): return failure("Internal occupants and occupied containers require release before changing location.")
	if spell_id != "misty_step": return failure("That teleport spell is not supported in local rooms.")
	var spell := DataLoader.get_spell(spell_id)
	var caster_error := _room_spell_caster_error(character, spell)
	if not caster_error.is_empty(): return failure(caster_error)
	var origin := coord(state.get("party_positions", {}).get(character.character_id, [-999, -999]))
	# Batch 066 (S-121/S-122): the room host uses the same PlacementRules legality
	# as room creation and containment release, before the slot is spent.
	var why := travel_destination_error(state, character, origin, destination, spell, grid, party)
	if not why.is_empty(): return failure(why)
	if requires_surface_traversal(surface_at(state, destination)) and not SpellEffects.has_spell(character, "water_walk"): return failure("That destination is blocked or occupied.")
	var spent := CombatAction.spend_spell_slot(character, spell)
	if not spent.get("success", false): return failure(str(spent.get("message", "No spell slot remains.")))
	LocalRoomAreas.leave(state, character, origin, destination)
	state["party_positions"][character.character_id] = [destination.x, destination.y]
	_ensure_party_altitudes(state)
	state["party_altitudes"][character.character_id] = elevation_feet(state, destination)
	state["party_altitude_modes"][character.character_id] = "ground"
	return {"success": true, "seconds": 6, "message": "%s teleports to the chosen space." % character.character_name}


## Batch 066: room arrival legality for teleport travel (no slot is spent here).
static func travel_destination_error(state: Dictionary, character: Character, origin: Vector2i, destination: Vector2i, spell: Dictionary, grid: HexGrid, party: Array = []) -> String:
	var members: Array = party.duplicate()
	if character not in members: members.append(character)
	var placement := ContainmentRules.placement_state(state, members)
	var reserved: Array = placement.reserved.filter(func(r): return r.hex != origin)
	var why := TravelPlacementRules.destination_error(placement, character, origin, destination, spell, grid, reserved)
	placement._placement_grid.free()
	if not why.is_empty(): return why
	for character_id in state.get("party_positions", {}):
		if character_id != character.character_id and coord(state["party_positions"][character_id]) == destination: return "That teleport destination is not available: occupied."
	for created_id in state.get("created_actor_positions", {}):
		if coord(state.created_actor_positions[created_id]) == destination: return "That teleport destination is not available: occupied."
	return ""


static func _room_spell_caster_error(character: Character, spell: Dictionary) -> String:
	if character == null or not character.is_alive or CombatAction.is_incapacitated(character):
		return "That character cannot cast a spell."
	var spell_id := str(spell.get("id", ""))
	if not SpellSupport.is_available(spell) or spell_id not in character.known_spells:
		return "That character cannot cast %s." % str(spell.get("name", "this spell"))
	if not DruidRules.can_cast_spells(character) or not character.inventory.has_required_spell_component(spell, character.class_id):
		return "That character cannot provide the spell's components."
	return ""


static func _environment_description(object: Dictionary) -> String:
	var details: Array[String] = []
	if object.has("water_gallons"):
		details.append("%s gallons of water" % _quantity_text(float(object.get("water_gallons", 0.0))))
	if object.has("food_servings"):
		details.append("%s lb of food" % _quantity_text(float(object.get("food_servings", 0.0))))
	var contamination: Array = object.get("contamination", [])
	if not contamination.is_empty():
		var contamination_text := ", ".join(contamination)
		if "sight_rot" in object.get("contamination_sources", []): contamination_text += " (Sight Rot)"
		details.append("contaminated: %s" % contamination_text)
	if bool(object.get("dirty", false)): details.append("dirty")
	var temperature: Dictionary = object.get("temperature_effect", {})
	if int(temperature.get("expires_at", 0)) > GameManager.campaign_elapsed_seconds:
		details.append(str(temperature.get("mode", "")))
	return ", ".join(details)


static func _alarm_alert_text(areas: Array) -> String:
	var alerts: Array[String] = []
	for area in areas:
		if str(area.get("spell_id", "")) != "alarm": continue
		if str(area.get("alert_mode", "audible")) == "mental":
			var range_feet := int(area.get("mental_range_feet", 5280))
			alerts.append("A mental Alarm pings %s within %d mile%s of the ward and can wake them if asleep." % [str(area.get("caster_name", "the caster")), maxi(1, int(round(float(range_feet) / 5280.0))), "" if range_feet <= 5280 else "s"])
		else:
			alerts.append("The audible Alarm rings like a handbell for %d seconds; creatures within %d feet of the ward can hear it." % [int(area.get("audible_duration_seconds", 10)), int(area.get("audible_radius_feet", 60))])
	return (" " + " ".join(alerts)) if not alerts.is_empty() else ""

static func place(state: Dictionary, character: Character, instance_id: String) -> Dictionary:
	if character != null and ContainmentRules.involved(state, "character", character.character_id): return failure("Internal occupants and occupied containers require release before changing location.")
	if character == null or not character.is_alive or CombatAction.is_incapacitated(character): return failure("That character cannot place an item.")
	var position: Array = state["party_positions"][character.character_id]
	if not object_at(state, coord(position)).is_empty(): return failure("There is already an object here.")
	var record := character.inventory.take_instance(instance_id)
	if record.is_empty(): return failure("Select an item from your backpack.")
	var placed := placed_item(state, record, coord(position))
	var object := get_object(state, str(placed.id))
	if object.is_empty(): state.objects.append(placed)
	else:
		object.clear()
		object.merge(placed)
	return {"success": true, "seconds": 6, "message": "%s placed." % placed.name}

## Shared exact-copy placement payload; callers own the inventory transaction.
static func placed_item(state: Dictionary, record: Dictionary, position: Vector2i) -> Dictionary:
	var item := DataLoader.get_item(str(record.definition_id))
	var physical := RoomMeasurements.known_fields(record.state.get("physical", {}), str(record.definition_id)) # S-032: legacy 1 lb stamps stay unknown.
	var object_id := str(physical["object_id"]) if physical.get("room_id", "") == state.get("id", "") and physical.has("object_id") else "placed:%s" % record.instance_id
	var object := {"id": object_id, "kind": "loose", "name": item.get("name", record.definition_id), "fixed": false, "hp": 1, "max_hp": 1, "position": [position.x, position.y], "contents": [record], "removed": false}
	for field in ["material", "size"]:
		if item.has(field): object[field] = item[field]
	if item.has("weight"): object["weight_lb"] = item.weight
	for field in ["material", "size", "weight_lb", "fixed", "hp", "max_hp"]:
		if physical.has(field): object[field] = physical[field]
	if record.state.has("combat_object_hp"):
		object.hp = int(record.state.combat_object_hp)
		object.max_hp = maxi(int(object.max_hp), int(object.hp))
	return object

static func failure(message: String) -> Dictionary:
	return {"success": false, "seconds": 0, "message": message}


static func _quantity_text(amount: float) -> String:
	if is_equal_approx(amount, roundf(amount)):
		return str(int(roundf(amount)))
	return str(snappedf(amount, 0.01))

static func transfer(state: Dictionary, character: Character, recipient: Character, instance_id: String) -> Dictionary:
	if not ContainmentRules.relation(state, "character", character.character_id).is_empty() or not ContainmentRules.relation(state, "character", recipient.character_id).is_empty(): return failure("Internal gear transfer is unavailable.")
	if character == recipient or not character.is_alive or not recipient.is_alive or CombatAction.is_incapacitated(character): return failure("Those characters cannot transfer an item.")
	var origin := coord(state["party_positions"][character.character_id])
	var destination := coord(state["party_positions"][recipient.character_id])
	if HexUtils.get_distance(origin, destination) > 1: return failure("Move next to the recipient first.")
	if not character.inventory.transfer_instance(instance_id, recipient.inventory): return failure("Transfer refused; items unchanged.")
	return {"success": true, "seconds": 6, "message": "Item transferred to %s." % recipient.character_name}
