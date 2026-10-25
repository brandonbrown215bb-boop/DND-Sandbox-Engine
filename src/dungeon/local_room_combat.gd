## Bind an encounter to its existing local room rather than a fresh arena.
class_name LocalRoomCombat
extends RefCounted

static func room() -> Dictionary:
	return GameManager.transition_context.get("local_room", {})

static func bind_grid(grid: HexGrid) -> void:
	var state := room()
	if state.is_empty(): return
	for position in grid.tiles:
		grid.tiles[position].custom_properties["surface"] = LocalRoomRules.surface_at(state, position)
		grid.tiles[position].custom_properties["blocks_movement"] = not LocalRoomRules.passable(state, position)
		grid.tiles[position].custom_properties["blocks_sight"] = LocalRoomRules.blocks_sight(state, position)
		grid.tiles[position].custom_properties["elevation_feet"] = LocalRoomRules.elevation_feet(state, position)
		grid.tiles[position].custom_properties["ceiling_feet"] = LocalRoomRules.ceiling_feet(state, position)
		if LocalRoomRules.has_wall(state, position):
			grid.tiles[position].custom_properties["wall_height_feet"] = LocalRoomRules.wall_height_feet(state, position)
			grid.tiles[position].custom_properties["wall_material"] = LocalRoomRules.wall_material(state, position)

static func add_objects(grid: HexGrid) -> void:
	for object in room().get("objects", []):
		if not bool(object.get("removed", false)):
			grid.add_entity({"hex_position": LocalRoomRules.coord(object["position"]), "world_object": object})


## Room-owned wards remain active while an encounter uses the room's grid.
## The creature ID is stable for party members and encounter-stable for monsters.
static func enter_room_areas(target, from_hex: Vector2i, to_hex: Vector2i) -> Array[Dictionary]:
	var state := room()
	if state.is_empty(): return []
	var creature_id: String = ""
	if target is Character:
		creature_id = target.character_id
	elif target is Dictionary:
		creature_id = str(target.get("id", ""))
	return LocalRoomAreas.enter(state, creature_id, from_hex, to_hex, int(GameManager.campaign_elapsed_seconds), PhysicalFactsRules.get_plane(target, {"plane": PhysicalFactsRules.get_plane(state)}))

static func capture(players: Array, ground_items: Array = []) -> void:
	var state := room()
	if state.is_empty(): return
	var altitudes: Dictionary = state.get("party_altitudes", {}).duplicate(true)
	var altitude_modes: Dictionary = state.get("party_altitude_modes", {}).duplicate(true)
	var created_positions: Dictionary = state.get("created_actor_positions", {}).duplicate(true)
	for player in players:
		var character: Character = player.get("character")
		if character != null and bool(player.get("is_created_actor", false)):
			var created_position: Vector2i = player.get("hex_position", Vector2i.ZERO)
			created_positions[character.character_id] = [created_position.x, created_position.y]
		if character != null and state["party_positions"].has(character.character_id):
			var position: Vector2i = player.get("hex_position", Vector2i.ZERO)
			state["party_positions"][character.character_id] = [position.x, position.y]
			altitudes[character.character_id] = int(player.get("altitude_feet", LocalRoomRules.altitude_feet(state, character.character_id)))
			var steed_state := PaladinRules.find_steed_state(character)
			if bool(steed_state.get("mounted", false)) and int(steed_state.get("fly_speed_feet", 0)) > 0:
				altitude_modes[character.character_id] = "fly"
	capture_ground_items(state, ground_items)
	state["party_altitudes"] = altitudes
	state["party_altitude_modes"] = altitude_modes
	state["created_actor_positions"] = created_positions
	GameManager.remember_dungeon()


static func reconcile_flight_altitudes(players: Array) -> Array[String]:
	var state := room()
	var messages: Array[String] = []
	if state.is_empty():
		return messages
	var altitudes: Dictionary = state.get("party_altitudes", {}).duplicate(true)
	var altitude_modes: Dictionary = state.get("party_altitude_modes", {}).duplicate(true)
	for player in players:
		var character: Character = player.get("character")
		if character == null:
			continue
		# Summons have separate owner records, not entries in the four-slot
		# party-position/altitude maps persisted by DungeonPersistence.
		if not state.get("party_positions", {}).has(character.character_id):
			continue
		var position: Vector2i = player.get("hex_position", Vector2i.ZERO)
		var floor_feet := LocalRoomRules.elevation_feet(state, position)
		var altitude := int(player.get("altitude_feet", altitudes.get(character.character_id, floor_feet)))
		var steed_state := PaladinRules.find_steed_state(character)
		var mounted_flight := bool(steed_state.get("mounted", false)) and int(steed_state.get("fly_speed_feet", 0)) > 0 and int(steed_state.get("current_hp", 0)) > 0
		if character.movement_speed_feet("fly") > 0 or mounted_flight or SpellEffects.has_spell(character, "levitate"):
			continue
		var drop_feet := altitude - floor_feet
		if str(altitude_modes.get(character.character_id, "ground")) == "levitate":
			player["altitude_feet"] = floor_feet
			altitudes[character.character_id] = floor_feet
			altitude_modes[character.character_id] = "ground"
			messages.append("%s floats gently down as Levitate ends." % character.character_name)
			continue
		if drop_feet <= 0:
			player["altitude_feet"] = floor_feet
			altitudes[character.character_id] = floor_feet
			continue
		var damage := 0
		for _die in LocalRoomRules.fall_dice_for_drop(drop_feet):
			damage += Dice.roll(6, character)
		character.take_damage(damage)
		player["altitude_feet"] = floor_feet
		altitudes[character.character_id] = floor_feet
		altitude_modes[character.character_id] = "ground"
		messages.append("%s falls %d feet and takes %d damage as its flying magic ends." % [character.character_name, drop_feet, damage])
	state["party_altitudes"] = altitudes
	state["party_altitude_modes"] = altitude_modes
	return messages


static func capture_spell_zones(players: Array, active_zones: Dictionary) -> void:
	var state := room()
	if state.is_empty():
		return
	# These room-stable areas and durations survive an encounter boundary.
	# Other encounter-local zones still end.
	for source_value in active_zones.keys():
		var source_id := str(source_value)
		var zone: Dictionary = active_zones[source_id]
		var spell_id := str(zone.get("spell_id", ""))
		var requires_concentration := bool(zone.get("concentration", false)) or spell_id == "moonbeam"
		if spell_id not in ["spike_growth", "entangle", "cloud_of_daggers", "fog_cloud", "darkness", "black_tentacles", "grease", "sleet_storm", "moonbeam", "wall_of_fire"]:
			continue
		var remaining_seconds := maxi(0, int(zone.get("rounds_remaining", 0)) * 6)
		if remaining_seconds <= 0:
			continue
		var caster_id := str(zone.get("caster_id", ""))
		var caster: Character = _character_by_id(players, caster_id)
		if caster == null:
			continue
		if requires_concentration and (str(caster.concentrating_on.get("spell_id", "")) != spell_id or str(caster.concentrating_on.get("%s_source_id" % spell_id, "")) != source_id):
			continue
		if requires_concentration:
			var effect_source := str(caster.concentrating_on.get("effect_source", ""))
			if effect_source.is_empty():
				# Every transferred concentration area needs a serializable owner,
				# including spells with older encounter-only concentration handlers.
				var marker := SpellEffects.begin_cast(caster, DataLoader.get_spell(spell_id))
				effect_source = str(marker["source_id"])
				SpellEffects.records(caster)[effect_source] = marker
				caster.concentrating_on["effect_source"] = effect_source
			if SpellEffects.records(caster).has(effect_source):
				SpellEffects.records(caster)[effect_source]["remaining_seconds"] = remaining_seconds
		LocalRoomAreas.remove_concentration(state, caster_id, spell_id, source_id)
		var center: Vector2i = zone.get("center", Vector2i.ZERO)
		var details := {
			"concentration_source_id": source_id,
		}
		if spell_id in ["spike_growth", "cloud_of_daggers", "moonbeam"]:
			var daggers_footprint: Array = []
			for cell in zone.get("coords", []): daggers_footprint.append([cell.x, cell.y])
			details["footprint"] = daggers_footprint
			if spell_id == "moonbeam":
				details["save_dc"] = int(zone.get("save_dc", 0))
				details["slot_level"] = int(zone.get("slot_level", 2))
				details["damage_formula"] = "%dd10" % (2 + maxi(0, int(zone.get("slot_level", 2)) - 2))
				details["height_feet"] = 40
				details["dim_light"] = true
				details["requires_concentration"] = true
			elif spell_id == "spike_growth":
				details["damage_formula"] = str(zone.get("damage_formula", "2d4"))
				details["slot_level"] = int(zone.get("slot_level", 2))
				details["difficult_terrain"] = true
				details["requires_concentration"] = true
			else:
				details["damage_formula"] = str(zone.get("damage_formula", "4d4"))
				details["slot_level"] = int(zone.get("slot_level", 2))
		elif spell_id in ["fog_cloud", "darkness"]:
			details["heavily_obscured"] = true
			if spell_id == "fog_cloud":
				var fog_footprint: Array = []
				for cell in zone.get("coords", []): fog_footprint.append([cell.x, cell.y])
				details["footprint"] = fog_footprint
		elif spell_id in ["black_tentacles", "grease", "entangle", "sleet_storm", "wall_of_fire"]:
			var footprint: Array = []
			for cell in zone.get("coords", []): footprint.append([cell.x, cell.y])
			details["footprint"] = footprint
			if spell_id == "wall_of_fire":
				var dangerous_footprint: Array = []
				for cell in zone.get("dangerous_coords", zone.get("coords", [])): dangerous_footprint.append([cell.x, cell.y])
				details["dangerous_footprint"] = dangerous_footprint
				details["damage_formula"] = str(zone.get("damage_formula", "5d8"))
				details["slot_level"] = int(zone.get("slot_level", 4))
			if spell_id != "sleet_storm": details["save_dc"] = int(zone.get("save_dc", 0))
			if spell_id == "black_tentacles":
				details["slot_level"] = int(zone.get("slot_level", 4))
			if spell_id != "wall_of_fire": details["difficult_terrain"] = true
			details["requires_concentration"] = requires_concentration
			if spell_id == "sleet_storm":
				details["save_dc"] = int(zone.get("save_dc", 0))
				details["heavily_obscured"] = bool(zone.get("heavily_obscured", true))
				details["height_feet"] = int(zone.get("height_feet", 40))
				details["douses_exposed_flames"] = bool(zone.get("douses_exposed_flames", true))
		var trigger_limit := 100 if spell_id in ["grease", "cloud_of_daggers", "spike_growth", "wall_of_fire"] else int(ceil(float(remaining_seconds) / 6.0)) + 1 if spell_id in ["black_tentacles", "sleet_storm", "moonbeam"] else 1
		var result := LocalRoomAreas.add(state, spell_id, caster_id, center, int(zone.get("radius_hexes", 0)), remaining_seconds, trigger_limit, details)
		if not result.get("success", false):
			push_warning("[LocalRoomCombat] Could not transfer %s to the saved room: %s" % [spell_id, str(result.get("message", "unknown reason"))])
		elif spell_id == "sleet_storm":
			for object in state.get("objects", []):
				if object is Dictionary and bool(object.get("burning", false)) and LocalRoomAreas.contains(result["area"], LocalRoomRules.coord(object.get("position", [0, 0]))):
					object["burning"] = false
					object.erase("burning_next_tick_seconds")


static func restore_spell_zones(players: Array) -> Dictionary:
	var restored: Dictionary = {}
	var state := room()
	if state.is_empty():
		return restored
	var now := int(GameManager.campaign_elapsed_seconds)
	LocalRoomAreas.expire(state, now)
	for area in state.get("areas", []):
		if not area is Dictionary or str(area.get("spell_id", "")) not in ["spike_growth", "entangle", "cloud_of_daggers", "fog_cloud", "darkness", "black_tentacles", "grease", "sleet_storm", "moonbeam", "wall_of_fire"]:
			continue
		var spell_id := str(area.get("spell_id", ""))
		var caster_id := str(area.get("caster_id", ""))
		var source_id := str(area.get("concentration_source_id", ""))
		var caster: Character = _character_by_id(players, caster_id)
		var requires_concentration := bool(area.get("requires_concentration", true))
		if caster == null or source_id.is_empty() or (requires_concentration and (str(caster.concentrating_on.get("spell_id", "")) != spell_id or str(caster.concentrating_on.get("%s_source_id" % spell_id, "")) != source_id)):
			continue
		var expires_at := int(area.get("expires_at_seconds", 0))
		var remaining_seconds := expires_at - now
		var center := LocalRoomRules.coord(area.get("center", [0, 0]))
		var coords: Array[Vector2i] = []
		var radius := int(area.get("radius_hexes", 0))
		if spell_id in ["spike_growth", "entangle", "cloud_of_daggers", "fog_cloud", "black_tentacles", "grease", "sleet_storm", "moonbeam", "wall_of_fire"]:
			for cell in area.get("footprint", []):
				var cell_coord := LocalRoomRules.coord(cell)
				if state.get("cells", []).any(func(room_cell): return LocalRoomRules.coord(room_cell) == cell_coord): coords.append(cell_coord)
		else:
			for cell in state.get("cells", []):
				var cell_coord := LocalRoomRules.coord(cell)
				if HexUtils.get_distance(center, cell_coord) <= radius: coords.append(cell_coord)
		if remaining_seconds <= 0 or coords.is_empty():
			continue
		if requires_concentration and caster != null:
			var effect_source := str(caster.concentrating_on.get("effect_source", ""))
			if SpellEffects.records(caster).has(effect_source):
				SpellEffects.records(caster)[effect_source]["remaining_seconds"] = remaining_seconds
		var zone := {
			"source_id": source_id,
			"spell_id": spell_id,
			"caster_id": caster_id,
			"center": center,
			"coords": coords,
			"radius_hexes": radius,
			"radius_feet": radius * 5,
			"concentration": requires_concentration,
			"rounds_remaining": int(ceil(float(remaining_seconds) / 6.0)),
		}
		if spell_id in ["fog_cloud", "darkness", "sleet_storm"]:
			zone["heavily_obscured"] = true
		if spell_id in ["black_tentacles", "grease", "entangle", "sleet_storm", "wall_of_fire"]:
			zone["save_dc"] = int(area.get("save_dc", 0))
			if spell_id == "wall_of_fire":
				zone["dangerous_coords"] = []
				for cell in area.get("dangerous_footprint", area.get("footprint", [])):
					zone["dangerous_coords"].append(LocalRoomRules.coord(cell))
				zone["damage_formula"] = str(area.get("damage_formula", "5d8"))
				zone["slot_level"] = int(area.get("slot_level", 4))
			if spell_id == "sleet_storm":
				zone["height_feet"] = int(area.get("height_feet", 40))
				zone["douses_exposed_flames"] = bool(area.get("douses_exposed_flames", true))
			if spell_id == "black_tentacles":
				zone["slot_level"] = int(area.get("slot_level", 4))
			if spell_id in ["black_tentacles", "entangle"]: zone["restrained_targets"] = []
		elif spell_id == "moonbeam":
			zone["save_dc"] = int(area.get("save_dc", 0))
			zone["slot_level"] = int(area.get("slot_level", 2))
			zone["height_feet"] = 40
			zone["dim_light"] = true
			zone["shape_locked_targets"] = []
			zone["last_trigger_turn_by_target"] = {}
			zone["damage_formula"] = "%dd10" % (2 + maxi(0, int(zone["slot_level"]) - 2))
		elif spell_id == "cloud_of_daggers":
			zone["damage_formula"] = str(area.get("damage_formula", "4d4"))
			zone["slot_level"] = int(area.get("slot_level", 2))
		elif spell_id == "spike_growth":
			zone["damage_formula"] = str(area.get("damage_formula", "2d4"))
			zone["slot_level"] = int(area.get("slot_level", 2))
		restored[source_id] = zone
	return restored


static func remove_concentration(caster: Character, spell_id: String, source_id: String) -> int:
	if caster == null or spell_id.is_empty() or source_id.is_empty():
		return 0
	if spell_id == "black_tentacles":
		for character in PartyManager.characters.values():
			if character is Character:
				CombatAction.remove_condition_source(character, source_id, ["restrained"])
	return LocalRoomAreas.remove_concentration(room(), caster.character_id, spell_id, source_id)


static func _character_by_id(players: Array, character_id: String) -> Character:
	if character_id.is_empty():
		return null
	for player in players:
		var character: Character = player.get("character")
		if character != null and character.character_id == character_id:
			return character
	return null


## Settle encounter ground copies before the room checkpoint. Tombstones carry no items.
static func capture_ground_items(state: Dictionary, ground_items: Array) -> void:
	for ground in ground_items:
		var id := str(ground.get("instance_id", ""))
		if id.is_empty(): continue
		var record := {"instance_id": id, "definition_id": str(ground.get("definition_id", "")), "state": ground.get("copy_state", {}).duplicate(true)}
		if not bool(ground.get("copy_destroyed", false)) and not ground.get("contents", []).is_empty():
			record = ground.contents[0].duplicate(true)
			record.state = ground.get("copy_state", record.state).duplicate(true)
		record.state["combat_object_hp"] = int(ground.get("hp", 1))
		var object := LocalRoomRules.placed_item(state, record, LocalRoomRules.coord(ground.position))
		object.hp = int(ground.get("hp", 1))
		object.max_hp = int(ground.get("max_hp", 1))
		if bool(ground.get("copy_destroyed", false)) and not ground.get("contents", []).is_empty():
			object.contents = ground.contents.duplicate(true)
			object.kind = "container"
			object.open = true
			object.locked = false
		elif bool(ground.get("removed", false)) or object.hp <= 0:
			object.contents = []
			object.removed = true
		var previous := LocalRoomRules.get_object(state, str(object.id))
		if previous.is_empty(): state.objects.append(object)
		else:
			previous.clear()
			previous.merge(object)
