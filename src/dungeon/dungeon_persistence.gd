## Validate plain world state before SaveManager mutates the live session.
class_name DungeonPersistence
extends RefCounted

static func coordinate(value: Variant) -> bool:
	if not value is Array or value.size() != 2: return false
	for component in value:
		if not component is int and not component is float: return false
		if not is_finite(float(component)) or float(component) != floorf(float(component)) or absf(float(component)) > 10000: return false
	return true

static func saved_error(state: Variant) -> String:
	if not state is Dictionary: return "dungeon state is not an object"
	if state.is_empty(): return ""
	if not state.get("dungeon_id") is String or str(state["dungeon_id"]).is_empty(): return "dungeon identity is missing"
	if not state.get("rooms") is Array or state["rooms"].size() > 500 or not coordinate(state.get("party_position")): return "dungeon layout is malformed"
	var room_ids: Dictionary = {}
	var room_coords: Dictionary = {}
	for room in state["rooms"]:
		if not room is Dictionary or not coordinate(room.get("coord")): return "dungeon room position is invalid"
		var raw_id: Variant = room.get("id")
		if not raw_id is int and not raw_id is float: return "dungeon room identity is invalid"
		if not is_finite(float(raw_id)) or float(raw_id) != floorf(float(raw_id)) or int(raw_id) < 0: return "dungeon room identity is invalid"
		var id := str(int(raw_id))
		var position := LocalRoomRules.coord(room["coord"])
		if room_ids.has(id) or room_coords.has(position): return "dungeon contains duplicate rooms"
		room_ids[id] = true
		room_coords[position] = true
	var locals: Variant = state.get("local_rooms", {})
	if not locals is Dictionary: return "local rooms are not an object"
	for id in locals:
		if not room_ids.has(str(id)): return "local room references a missing dungeon room"
		var error := local_error(locals[id])
		if not error.is_empty(): return error
	var selected := str(state.get("local_room_id", ""))
	if not selected.is_empty() and not locals.has(selected): return "active local room is missing"
	return ""

static func snapshots_error(snapshots: Variant, campaign: Dictionary) -> String:
	if not snapshots is Dictionary: return "dungeon snapshots are not an object"
	for id in snapshots:
		if not campaign.get("dungeons", {}).has(id): return "snapshot references an unknown dungeon"
		var error := saved_error(snapshots[id])
		if not error.is_empty(): return error
		if snapshots[id]["dungeon_id"] != id: return "snapshot identity differs from its dungeon"
	return ""

static func local_error(state: Variant) -> String:
	if not state is Dictionary or not state.get("cells") is Array or state["cells"].is_empty() or state["cells"].size() > 500: return "local room cells are malformed"
	if not state.get("id") is String or str(state["id"]).is_empty() or not state.get("name") is String or not state.get("encounter_cleared") is bool or not state.get("encounter_monsters") is Array: return "local room identity or encounter is malformed"
	if state.has("ceiling_feet"):
		var room_ceiling: Variant = state["ceiling_feet"]
		if not room_ceiling is int and not room_ceiling is float: return "local ceiling height is invalid"
		if not is_finite(float(room_ceiling)) or float(room_ceiling) != floorf(float(room_ceiling)) or int(room_ceiling) < 5 or int(room_ceiling) > 1000 or int(room_ceiling) % 5 != 0: return "local ceiling height is invalid"
	for monster in state["encounter_monsters"]:
		if not monster is String or DataLoader.get_monster(monster).is_empty(): return "local encounter references unknown content"
	var cells: Dictionary = {}
	for position in state["cells"]:
		if not coordinate(position) or cells.has(LocalRoomRules.coord(position)): return "local room has invalid or duplicate cells"
		cells[LocalRoomRules.coord(position)] = true
	var elevations: Variant = state.get("cell_elevations", [])
	if not elevations is Array or elevations.size() > state["cells"].size(): return "local cell elevations are malformed"
	var elevated_cells: Dictionary = {}
	for cell_elevation in elevations:
		if not cell_elevation is Dictionary or not coordinate(cell_elevation.get("position")): return "local cell elevation is invalid"
		var elevation_position := LocalRoomRules.coord(cell_elevation["position"])
		if not cells.has(elevation_position) or elevated_cells.has(elevation_position): return "local cell elevation is outside the room or duplicated"
		elevated_cells[elevation_position] = true
		var feet: Variant = cell_elevation.get("feet", null)
		if not feet is int and not feet is float: return "local cell elevation is invalid"
		if not is_finite(float(feet)) or float(feet) != floorf(float(feet)) or absf(float(feet)) > 1000.0 or int(feet) % 5 != 0: return "local cell elevation is invalid"
	if state.has("ceiling_feet"):
		for position in state["cells"]:
			if int(state["ceiling_feet"]) < LocalRoomRules.elevation_feet(state, LocalRoomRules.coord(position)) + 5: return "local ceiling intersects room geometry"
	var ceilings: Variant = state.get("cell_ceilings", [])
	if not ceilings is Array or ceilings.size() > state["cells"].size(): return "local cell ceilings are malformed"
	var ceiling_cells: Dictionary = {}
	for ceiling in ceilings:
		if not ceiling is Dictionary or not coordinate(ceiling.get("position")): return "local cell ceiling is invalid"
		var ceiling_position := LocalRoomRules.coord(ceiling["position"])
		if not cells.has(ceiling_position) or ceiling_cells.has(ceiling_position): return "local cell ceiling is outside the room or duplicated"
		ceiling_cells[ceiling_position] = true
		var ceiling_feet: Variant = ceiling.get("feet", null)
		if not ceiling_feet is int and not ceiling_feet is float: return "local ceiling height is invalid"
		if not is_finite(float(ceiling_feet)) or float(ceiling_feet) != floorf(float(ceiling_feet)) or int(ceiling_feet) < LocalRoomRules.elevation_feet(state, ceiling_position) + 5 or int(ceiling_feet) > 1000 or int(ceiling_feet) % 5 != 0: return "local ceiling height is invalid"
	var terrains: Variant = state.get("cell_terrains", [])
	if not terrains is Array or terrains.size() > state["cells"].size(): return "local cell terrains are malformed"
	var terrained_cells: Dictionary = {}
	for cell_terrain in terrains:
		if not cell_terrain is Dictionary or not coordinate(cell_terrain.get("position")) or str(cell_terrain.get("surface", "")) not in ["water", "acid", "mud", "snow", "quicksand", "lava"]: return "local cell terrain is invalid"
		var terrain_position := LocalRoomRules.coord(cell_terrain["position"])
		if not cells.has(terrain_position) or terrained_cells.has(terrain_position): return "local cell terrain is outside the room or duplicated"
		terrained_cells[terrain_position] = true
		if cell_terrain.has("heat_damage_formula") or cell_terrain.has("heat_height_feet"):
			var heat_formula: Variant = cell_terrain.get("heat_damage_formula", null)
			var heat_height: Variant = cell_terrain.get("heat_height_feet", null)
			if not heat_formula is String: return "surface heat damage is invalid"
			var heat_dice := RegEx.create_from_string("^([1-9]|1[0-9]|20)d(4|6|8|10|12|20)$")
			if heat_dice.search(str(heat_formula)) == null: return "surface heat damage is invalid"
			if (not heat_height is int and not heat_height is float) or not is_finite(float(heat_height)) or float(heat_height) != floorf(float(heat_height)) or int(heat_height) < 0 or int(heat_height) > 1000 or int(heat_height) % 5 != 0: return "surface heat height is invalid"
	for field in ["walls", "exits", "party_spawns", "monster_spawns"]:
		if not state.get(field) is Array: return "local room geometry is malformed"
		for position in state[field]:
			if not coordinate(position) or not cells.has(LocalRoomRules.coord(position)): return "local geometry lies outside the room"
	var wall_positions: Dictionary = {}
	for wall in state.get("walls", []): wall_positions[LocalRoomRules.coord(wall)] = true
	var wall_details: Variant = state.get("wall_details", [])
	if not wall_details is Array or wall_details.size() > state.get("walls", []).size(): return "local wall details are malformed"
	var described_walls: Dictionary = {}
	for wall in wall_details:
		if not wall is Dictionary or not coordinate(wall.get("position")): return "local wall detail is invalid"
		var wall_position := LocalRoomRules.coord(wall["position"])
		if not wall_positions.has(wall_position) or described_walls.has(wall_position): return "local wall detail is outside geometry or duplicated"
		described_walls[wall_position] = true
		var height: Variant = wall.get("height_feet", null)
		if not height is int and not height is float: return "local wall height is invalid"
		if not is_finite(float(height)) or float(height) != floorf(float(height)) or int(height) < 5 or int(height) > 1000 or int(height) % 5 != 0: return "local wall height is invalid"
		if not wall.get("material") is String or str(wall["material"]) not in ["stone", "wood", "iron", "glass", "ice", "other"]: return "local wall material is invalid"
	if not state.get("party_positions") is Dictionary or state["party_positions"].size() > 4: return "local party positions are malformed"
	for id in state["party_positions"]:
		if not id is String or str(id).is_empty(): return "local character identity is invalid"
		var position: Variant = state["party_positions"][id]
		if not coordinate(position) or not cells.has(LocalRoomRules.coord(position)): return "party position lies outside the room"
	if state.has("party_altitudes"):
		var altitudes: Variant = state["party_altitudes"]
		if not altitudes is Dictionary or altitudes.size() > state["party_positions"].size(): return "local party altitudes are malformed"
		for id in altitudes:
			if not state["party_positions"].has(id): return "local party altitude has no matching character position"
			var altitude: Variant = altitudes[id]
			var position := LocalRoomRules.coord(state["party_positions"][id])
			if not altitude is int and not altitude is float: return "local party altitude is invalid"
			if not is_finite(float(altitude)) or float(altitude) != floorf(float(altitude)) or int(altitude) < LocalRoomRules.elevation_feet(state, position) or int(altitude) + 5 > LocalRoomRules.ceiling_feet(state, position) or int(altitude) % 5 != 0: return "local party altitude is invalid"
	if state.has("party_altitude_modes"):
		var altitude_modes: Variant = state["party_altitude_modes"]
		if not altitude_modes is Dictionary or altitude_modes.size() > state["party_positions"].size(): return "local party altitude modes are malformed"
		for id in altitude_modes:
			if not state["party_positions"].has(id) or not altitude_modes[id] is String or str(altitude_modes[id]) not in ["ground", "fly", "levitate"]: return "local party altitude mode is invalid"
	var areas_value: Variant = state.get("areas", [])
	if not areas_value is Array or areas_value.size() > 500: return "local room areas are malformed"
	var area_ids: Dictionary = {}
	var alarm_warded_object_ids: Dictionary = {}
	var zone_area_sources: Dictionary = {}
	for area in areas_value:
		if not area is Dictionary or not area.get("id") is String or str(area["id"]).is_empty() or area_ids.has(area["id"]): return "local area identity is invalid"
		area_ids[area["id"]] = true
		if not area.get("spell_id") is String or str(area["spell_id"]).is_empty() or not area.get("caster_id") is String or str(area["caster_id"]).is_empty(): return "local area source is invalid"
		if not coordinate(area.get("center")) or not cells.has(LocalRoomRules.coord(area["center"])): return "local area center is outside the room"
		for field in ["radius_hexes", "expires_at_seconds", "trigger_limit"]:
			var number: Variant = area.get(field, null)
			if not number is int and not number is float: return "local area number is invalid"
			if not is_finite(float(number)) or float(number) != floorf(float(number)) or int(number) < 0: return "local area number is invalid"
		if int(area["radius_hexes"]) > 20 or int(area["expires_at_seconds"]) <= 0 or int(area["trigger_limit"]) <= 0: return "local area limits are invalid"
		var triggered_by: Variant = area.get("triggered_by", {})
		if not triggered_by is Dictionary or triggered_by.size() > 100: return "local area trigger ledger is invalid"
		for character_id in triggered_by:
			var count: Variant = triggered_by[character_id]
			if not character_id is String or str(character_id).is_empty() or (not count is int and not count is float): return "local area trigger count is invalid"
			if not is_finite(float(count)) or float(count) != floorf(float(count)) or int(count) < 0 or int(count) > int(area["trigger_limit"]): return "local area trigger count is invalid"
		if area.has("check_turn_by_character"):
			var checked_turns: Variant = area["check_turn_by_character"]
			if str(area["spell_id"]) not in ["cloud_of_daggers", "black_tentacles", "grease", "sleet_storm", "moonbeam", "wall_of_fire"] or not checked_turns is Dictionary or checked_turns.size() > 100: return "local area turn ledger is invalid"
			for character_id in checked_turns:
				var turn_index: Variant = checked_turns[character_id]
				if not character_id is String or str(character_id).is_empty() or (not turn_index is int and not turn_index is float): return "local area turn ledger is invalid"
				if not is_finite(float(turn_index)) or float(turn_index) != floorf(float(turn_index)) or int(turn_index) < 0 or int(turn_index) > 200000000: return "local area turn ledger is invalid"
		if str(area["spell_id"]) == "alarm":
			if not area.get("alert_mode") is String or str(area["alert_mode"]) not in ["audible", "mental"] or not area.get("caster_name") is String or str(area["caster_name"]).is_empty() or not area.get("warded_object_id") is String or str(area["warded_object_id"]).is_empty(): return "saved Alarm details are invalid"
			var alarm_delivery_values := {"audible_duration_seconds": 10, "audible_radius_feet": 60, "mental_range_feet": 5280}
			for delivery_field in ["audible_duration_seconds", "audible_radius_feet", "mental_range_feet"]:
				if area.has(delivery_field):
					var delivery_value: Variant = area[delivery_field]
					if (not delivery_value is int and not delivery_value is float) or not is_finite(float(delivery_value)) or float(delivery_value) != floorf(float(delivery_value)) or int(delivery_value) != int(alarm_delivery_values[delivery_field]): return "saved Alarm delivery rules are invalid"
			if area.has("mental_wakes_if_asleep") and area["mental_wakes_if_asleep"] != true: return "saved Alarm wake rule is invalid"
			var ignored_ids: Variant = area.get("ignored_character_ids", [])
			if not ignored_ids is Array or ignored_ids.size() > 4: return "saved Alarm exclusions are invalid"
			var ignored_seen: Dictionary = {}
			for ignored_id in ignored_ids:
				if not ignored_id is String or str(ignored_id).is_empty() or ignored_seen.has(ignored_id): return "saved Alarm exclusions are invalid"
				ignored_seen[ignored_id] = true
			alarm_warded_object_ids[area["warded_object_id"]] = true
		elif str(area["spell_id"]) in ["spike_growth", "entangle", "cloud_of_daggers", "fog_cloud", "darkness", "black_tentacles", "grease", "sleet_storm", "moonbeam", "wall_of_fire"]:
			if not area.get("concentration_source_id") is String or str(area["concentration_source_id"]).is_empty(): return "saved area zone source is invalid"
			if str(area["spell_id"]) in ["fog_cloud", "darkness", "sleet_storm"] and (not area.get("heavily_obscured") is bool or not bool(area["heavily_obscured"])): return "saved obscuring area source is invalid"
			if str(area["spell_id"]) == "fog_cloud" and area.has("footprint"):
				var fog_footprint: Variant = area.get("footprint", null)
				if not fog_footprint is Array or fog_footprint.is_empty() or fog_footprint.size() > 200: return "saved Fog Cloud footprint is invalid"
				var fog_seen_cells: Dictionary = {}
				for cell in fog_footprint:
					if not coordinate(cell) or not cells.has(LocalRoomRules.coord(cell)) or fog_seen_cells.has(str(cell)): return "saved Fog Cloud footprint is invalid"
					fog_seen_cells[str(cell)] = true
			if str(area["spell_id"]) == "cloud_of_daggers":
				var daggers_footprint: Variant = area.get("footprint", null)
				var daggers_slot: Variant = area.get("slot_level", null)
				if not daggers_footprint is Array or daggers_footprint.size() != 1 or (not daggers_slot is int and not daggers_slot is float) or not is_finite(float(daggers_slot)) or float(daggers_slot) != floorf(float(daggers_slot)) or int(daggers_slot) < 2 or int(daggers_slot) > 9: return "saved Cloud of Daggers footprint or slot is invalid"
				var damage_dice := 4 + maxi(0, int(area["slot_level"]) - 2) * 2
				if str(area.get("damage_formula", "")) != "%dd4" % damage_dice: return "saved Cloud of Daggers damage is invalid"
				var daggers_cell: Variant = daggers_footprint[0]
				if not coordinate(daggers_cell) or not cells.has(LocalRoomRules.coord(daggers_cell)): return "saved Cloud of Daggers footprint is invalid"
			if str(area["spell_id"]) == "spike_growth":
				var spike_footprint: Variant = area.get("footprint", null)
				var spike_slot: Variant = area.get("slot_level", null)
				if not spike_footprint is Array or spike_footprint.is_empty() or spike_footprint.size() > 200 or (not spike_slot is int and not spike_slot is float) or not is_finite(float(spike_slot)) or float(spike_slot) != floorf(float(spike_slot)) or int(spike_slot) < 2 or int(spike_slot) > 9 or not area.get("difficult_terrain") is bool or not bool(area["difficult_terrain"]) or not area.get("requires_concentration") is bool or not bool(area["requires_concentration"]): return "saved Spike Growth details are invalid"
				if str(area.get("damage_formula", "")) != "2d4": return "saved Spike Growth damage is invalid"
				var spike_seen_cells: Dictionary = {}
				for cell in spike_footprint:
					if not coordinate(cell) or not cells.has(LocalRoomRules.coord(cell)) or spike_seen_cells.has(str(cell)): return "saved Spike Growth footprint is invalid"
					spike_seen_cells[str(cell)] = true
			if str(area["spell_id"]) in ["black_tentacles", "grease", "entangle", "sleet_storm"]:
				var footprint: Variant = area.get("footprint", null)
				if not footprint is Array or footprint.is_empty() or footprint.size() > 200 or not area.get("difficult_terrain") is bool or not bool(area["difficult_terrain"]) or not area.get("requires_concentration") is bool: return "saved area terrain footprint is invalid"
				if str(area["spell_id"]) == "grease" and bool(area["requires_concentration"]): return "saved Grease cannot require Concentration"
				if str(area["spell_id"]) == "entangle" and not bool(area["requires_concentration"]): return "saved Entangle must require Concentration"
				if str(area["spell_id"]) == "sleet_storm" and not bool(area["requires_concentration"]): return "saved Sleet Storm must require Concentration"
				var seen_cells: Dictionary = {}
				for cell in footprint:
					if not coordinate(cell) or not cells.has(LocalRoomRules.coord(cell)) or seen_cells.has(str(cell)): return "saved Black Tentacles footprint is invalid"
					seen_cells[str(cell)] = true
				var numeric_fields := ["save_dc"] if str(area["spell_id"]) != "sleet_storm" else ["save_dc", "height_feet"]
				if str(area["spell_id"]) == "sleet_storm" and (not area.get("heavily_obscured") is bool or not bool(area["heavily_obscured"]) or not area.get("douses_exposed_flames") is bool): return "saved Sleet Storm details are invalid"
				if str(area["spell_id"]) == "black_tentacles": numeric_fields.append("slot_level")
				for field in numeric_fields:
					var number: Variant = area.get(field, null)
					var minimum := 1 if field == "slot_level" else 5 if field == "height_feet" else 0
					var maximum := 9 if field == "slot_level" else 200 if field == "height_feet" else 100
					if (not number is int and not number is float) or not is_finite(float(number)) or float(number) != floorf(float(number)) or int(number) < minimum or int(number) > maximum: return "saved area details are invalid"
			if str(area["spell_id"]) == "moonbeam":
				var moonbeam_footprint: Variant = area.get("footprint", null)
				var moonbeam_slot: Variant = area.get("slot_level", null)
				var moonbeam_height: Variant = area.get("height_feet", null)
				var moonbeam_dc: Variant = area.get("save_dc", null)
				if not moonbeam_footprint is Array or moonbeam_footprint.is_empty() or moonbeam_footprint.size() > 200 or (not moonbeam_slot is int and not moonbeam_slot is float) or not is_finite(float(moonbeam_slot)) or float(moonbeam_slot) != floorf(float(moonbeam_slot)) or int(moonbeam_slot) < 2 or int(moonbeam_slot) > 9 or (not moonbeam_height is int and not moonbeam_height is float) or float(moonbeam_height) != 40.0 or (not moonbeam_dc is int and not moonbeam_dc is float) or not is_finite(float(moonbeam_dc)) or float(moonbeam_dc) != floorf(float(moonbeam_dc)) or int(moonbeam_dc) < 0 or int(moonbeam_dc) > 100 or not area.get("dim_light") is bool or not bool(area["dim_light"]) or not bool(area.get("requires_concentration", false)):
					return "saved Moonbeam details are invalid"
				if str(area.get("damage_formula", "")) != "%dd10" % (2 + maxi(0, int(moonbeam_slot) - 2)):
					return "saved Moonbeam damage is invalid"
				var moonbeam_seen: Dictionary = {}
				for cell in moonbeam_footprint:
					if not coordinate(cell) or not cells.has(LocalRoomRules.coord(cell)) or moonbeam_seen.has(str(cell)): return "saved Moonbeam footprint is invalid"
					moonbeam_seen[str(cell)] = true
			if str(area["spell_id"]) == "wall_of_fire":
				var wall_footprint: Variant = area.get("footprint", null)
				var dangerous_footprint: Variant = area.get("dangerous_footprint", null)
				var wall_slot: Variant = area.get("slot_level", null)
				var wall_dc: Variant = area.get("save_dc", null)
				if not wall_footprint is Array or wall_footprint.is_empty() or wall_footprint.size() > 13 or not dangerous_footprint is Array or dangerous_footprint.is_empty() or dangerous_footprint.size() > 39 or (not wall_slot is int and not wall_slot is float) or int(wall_slot) < 4 or int(wall_slot) > 9 or (not wall_dc is int and not wall_dc is float) or int(wall_dc) < 0 or int(wall_dc) > 100 or not bool(area.get("requires_concentration", false)):
					return "saved Wall of Fire details are invalid"
				var wall_damage_formula := "5d8" if int(wall_slot) == 4 else "5d8 + %dd8" % (int(wall_slot) - 4)
				if str(area.get("damage_formula", "")) != wall_damage_formula:
					return "saved Wall of Fire damage is invalid"
				for footprint in [wall_footprint, dangerous_footprint]:
					var wall_seen: Dictionary = {}
					for cell in footprint:
						if not coordinate(cell) or not cells.has(LocalRoomRules.coord(cell)) or wall_seen.has(str(cell)): return "saved Wall of Fire footprint is invalid"
						wall_seen[str(cell)] = true
			var concentration_area_source := "%s:%s" % [str(area["caster_id"]), str(area["concentration_source_id"])]
			if zone_area_sources.has(concentration_area_source): return "saved area zone source is duplicated"
			zone_area_sources[concentration_area_source] = true
		elif area.has("alert_mode") or area.has("caster_name") or area.has("warded_object_id") or area.has("ignored_character_ids"):
			return "non-Alarm area contains Alarm details"
		if str(area["spell_id"]) not in ["fog_cloud", "darkness", "sleet_storm"] and area.has("heavily_obscured"):
			return "non-obscuring area contains obscuration details"
		if str(area["spell_id"]) not in ["spike_growth", "entangle", "cloud_of_daggers", "fog_cloud", "black_tentacles", "grease", "sleet_storm", "moonbeam", "wall_of_fire"] and (area.has("footprint") or area.has("difficult_terrain") or area.has("save_dc") or area.has("slot_level") or area.has("requires_concentration")):
			return "non-Black Tentacles area contains zone details"
		if str(area["spell_id"]) not in ["sleet_storm", "moonbeam"] and (area.has("height_feet") or area.has("douses_exposed_flames")):
			return "non-storm area contains height or flame details"
		if str(area["spell_id"]) != "moonbeam" and area.has("dim_light"):
			return "non-Moonbeam area contains Dim Light details"
		if str(area["spell_id"]) not in ["spike_growth", "entangle", "cloud_of_daggers", "fog_cloud", "darkness", "black_tentacles", "grease", "sleet_storm", "moonbeam", "wall_of_fire"] and area.has("concentration_source_id"):
			return "unsupported area contains concentration zone details"
	if not state.get("objects") is Array or state["objects"].size() > 200: return "local objects are malformed"
	var objects: Dictionary = {}
	var instances: Dictionary = {}
	for object in state["objects"]:
		if not object is Dictionary or not object.get("id") is String or str(object["id"]).is_empty() or objects.has(object["id"]) or not object.get("name") is String: return "object identity is invalid"
		objects[object["id"]] = true
		if str(object.get("kind", "")) not in ["door", "container", "loose", "barrier", "remains"] or not coordinate(object.get("position")) or not cells.has(LocalRoomRules.coord(object["position"])): return "object location or kind is invalid"
		if str(object.get("kind", "")) == "remains":
			if object.get("body_creature_type") not in ["humanoid", "beast", "undead"] or object.get("remains") not in CorpseRules.REMAINS or str(object.get("size", "")).to_lower() not in ["tiny", "small", "medium", "large", "huge", "gargantuan"] or not object.get("contents", []) is Array or not object.get("contents", []).is_empty(): return "world remains are invalid"
			if not CorpseRules._integer(object.get("preserved_until", 0), 0): return "world remains preservation is invalid"
		if str(object.get("kind", "")) == "barrier":
			var barrier_height: Variant = object.get("height_feet", 10)
			if (not barrier_height is int and not barrier_height is float) or not is_finite(float(barrier_height)) or float(barrier_height) != floorf(float(barrier_height)) or int(barrier_height) < 5 or int(barrier_height) > 1000 or int(barrier_height) % 5 != 0 or not bool(object.get("fixed", false)): return "barrier height or attachment is invalid"
			if str(object.get("material", "")) not in ["stone", "wood", "iron", "glass", "ice", "other"]: return "barrier material is invalid"
		for flag in ["open", "locked", "lockable", "fixed", "removed"]:
			if object.has(flag) and not object[flag] is bool: return "object flag is invalid"
		for flag in ["food_or_drink", "magical", "dirty", "flammable", "burning"]:
			if object.has(flag) and not object[flag] is bool: return "environment object flag is invalid"
		if object.has("burning_next_tick_seconds"):
			var burning_tick: Variant = object["burning_next_tick_seconds"]
			if not object.get("burning", false) or (not burning_tick is int and not burning_tick is float) or not is_finite(float(burning_tick)) or float(burning_tick) != floorf(float(burning_tick)) or int(burning_tick) < 0: return "object burning timer is invalid"
		if object.has("volume_cubic_feet"):
			if not object["volume_cubic_feet"] is int and not object["volume_cubic_feet"] is float: return "object volume is invalid"
			if not is_finite(float(object["volume_cubic_feet"])) or float(object["volume_cubic_feet"]) < 0.0 or float(object["volume_cubic_feet"]) > 1000.0: return "object volume is invalid"
		if object.has("temperature_effect"):
			var temperature: Variant = object["temperature_effect"]
			if not temperature is Dictionary or str(temperature.get("mode", "")) not in ["warm", "cool"]: return "object temperature is invalid"
			var expiry: Variant = temperature.get("expires_at", -1)
			if not expiry is int and not expiry is float: return "object temperature is invalid"
			if not is_finite(float(expiry)) or float(expiry) != floorf(float(expiry)) or int(expiry) < 0: return "object temperature is invalid"
		if object.has("contamination"):
			if not object["contamination"] is Array or object["contamination"].size() > 8: return "object contamination is malformed"
			for kind in object["contamination"]:
				if not kind is String or str(kind) not in ["poison", "disease"]: return "object contamination is invalid"
		if object.has("contamination_sources"):
			if not object["contamination_sources"] is Array or object["contamination_sources"].size() > 8: return "object contamination sources are malformed"
			for source in object["contamination_sources"]:
				if not source is String or str(source) != "sight_rot": return "object contamination source is invalid"
			if not object.get("contamination_sources", []).is_empty() and (not bool(object.get("food_or_drink", false)) or "disease" not in object.get("contamination", [])): return "disease source lacks disease-contaminated food or drink"
		if not object.get("contamination", []).is_empty() and not bool(object.get("food_or_drink", false)): return "non-food object has contamination"
		for field in ["hp", "max_hp", "capacity", "lock_dc", "capacity_gallons", "armor_class", "damage_threshold"]:
			if object.has(field):
				if not object[field] is int and not object[field] is float: return "object number is invalid"
				if not is_finite(float(object[field])) or float(object[field]) != floorf(float(object[field])) or int(object[field]) < 0: return "object number is invalid"
		for field in ["damage_immunities", "damage_resistances", "damage_vulnerabilities"]:
			if not object.has(field): continue
			if not object[field] is Array or object[field].size() > 13: return "object damage rules are invalid"
			for damage_type in object[field]:
				if not damage_type is String or damage_type not in ["acid", "bludgeoning", "cold", "fire", "force", "lightning", "necrotic", "piercing", "poison", "psychic", "radiant", "slashing", "thunder"]: return "object damage rules are invalid"
		for field in ["water_gallons", "food_servings"]:
			if object.has(field):
				if not object[field] is int and not object[field] is float: return "food or water quantity is invalid"
				var quantity := float(object[field])
				if not is_finite(quantity) or quantity < 0.0 or not is_equal_approx(quantity * 16.0, roundf(quantity * 16.0)): return "food or water quantity is invalid"
		if not object.get("contents") is Array or object["contents"].size() > 100: return "container items are malformed"
		if int(object.get("hp", 1)) > int(object.get("max_hp", 1)): return "object health exceeds its maximum"
		if float(object.get("water_gallons", 0.0)) > float(object.get("capacity_gallons", 0.0)): return "stored water exceeds its container capacity"
		if object.has("food_servings") and not bool(object.get("food_or_drink", false)): return "food servings are attached to a non-food object"
		if bool(object.get("removed", false)) and not object["contents"].is_empty(): return "removed object retains inaccessible items"
		for item in object["contents"]:
			if not item is Dictionary or not item.get("instance_id") is String or str(item["instance_id"]).is_empty() or instances.has(item["instance_id"]) or not item.get("state") is Dictionary or DataLoader.get_item(str(item.get("definition_id", ""))).is_empty(): return "world item identity is invalid"
			instances[item["instance_id"]] = true
	for warded_object_id in alarm_warded_object_ids:
		var warded_object := LocalRoomRules.get_object(state, str(warded_object_id))
		if warded_object.is_empty() or str(warded_object.get("kind", "")) != "door": return "saved Alarm references a missing or ineligible door"
	return ""
