## Terrain, obscuration and hazard spell areas.
class_name SpellZoneTerrain
extends RefCounted


static func light_is_dispersed_by_darkness(active_spell_zones: Dictionary, light_center: Vector2i, light_radius_hexes: int) -> bool:
	for zone in active_spell_zones.values():
		if str(zone.get("spell_id", "")) != "darkness":
			continue
		var zone_center: Vector2i = zone.get("center", Vector2i.ZERO)
		var zone_radius := int(zone.get("radius_hexes", 0))
		if HexUtils.get_distance(light_center, zone_center) <= light_radius_hexes + zone_radius:
			return true
	return false


static func dispel_darkness_in_area(zones: CombatSpellZones, area_coords: Array[Vector2i]) -> int:
	var removed := 0
	for source_value in zones.active_spell_zones.keys().duplicate():
		var source_id := str(source_value)
		var zone: Dictionary = zones.active_spell_zones.get(source_id, {})
		if str(zone.get("spell_id", "")) != "darkness":
			continue
		var overlaps := area_coords.any(func(coord): return coord in zone.get("coords", []))
		if not overlaps:
			continue
		var caster := zones._spell_zone_caster(zone)
		if caster != null and str(caster.concentrating_on.get("spell_id", "")) == "darkness" and str(caster.concentrating_on.get("darkness_source_id", "")) == source_id:
			zones.end_concentration.call(caster)
		else:
			zones._remove_spell_zone(source_id)
		removed += 1
	return removed

static func _create_grease_zone(zones: CombatSpellZones, active_character: Character, center: Vector2i) -> void:
	zones._spell_zone_serial += 1
	var source_id := "grease:%s:%d" % [active_character.character_id, zones._spell_zone_serial]
	var coords := Targeting.get_square_targets(center, 10, zones.hex_grid)
	if coords.is_empty():
		return
	zones.active_spell_zones[source_id] = {
		"spell_id": "grease",
		"caster_id": active_character.character_id,
		"coords": coords,
		"save_dc": active_character.get_spell_save_dc(),
		"rounds_remaining": 10,
	}
	zones.hex_grid.add_difficult_terrain(source_id, coords)
	zones.hud.add_log("[color=olive]Grease covers a 10-foot area for 1 minute, making it Difficult Terrain.[/color]")
	zones.refresh_grid.call()
	zones.highlight_reachable.call()


static func _create_spike_growth_zone(zones: CombatSpellZones, active_character: Character, center: Vector2i, slot_level: int) -> void:
	zones._spell_zone_serial += 1
	var source_id := "spike_growth:%s:%d" % [active_character.character_id, zones._spell_zone_serial]
	var coords := Targeting.get_sphere_targets(center, 4, zones.hex_grid)
	if coords.is_empty():
		return
	var spell_data: Dictionary = DataLoader.get_spell("spike_growth")
	var damage_formula := CombatAction.spell_damage_formula(active_character, spell_data, slot_level)
	zones.active_spell_zones[source_id] = {
		"spell_id": "spike_growth",
		"caster_id": active_character.character_id,
		"center": center,
		"radius_hexes": 4,
		"coords": coords,
		"slot_level": slot_level,
		"damage_formula": damage_formula,
		"concentration": true,
		"rounds_remaining": 100,
	}
	active_character.concentrating_on["duration_rounds_remaining"] = 100
	active_character.concentrating_on["duration_started_round"] = zones.tracker.current_round
	active_character.concentrating_on["spike_growth_source_id"] = source_id
	zones.hex_grid.add_difficult_terrain(source_id, coords)
	zones.hud.add_log("[color=olive]Spike Growth covers a 20-foot Sphere for up to 10 minutes, making it Difficult Terrain.[/color]")
	zones.refresh_grid.call()
	zones.highlight_reachable.call()


static func _create_entangle_zone(zones: CombatSpellZones, active_character: Character, center: Vector2i, source_id: String, restrained_targets: Array) -> void:
	var coords := Targeting.get_square_targets(center, 20, zones.hex_grid)
	if coords.is_empty():
		return
	zones.active_spell_zones[source_id] = {
		"spell_id": "entangle",
		"caster_id": active_character.character_id,
		"center": center,
		"radius_hexes": 0,
		"coords": coords,
		"save_dc": active_character.get_spell_save_dc(),
		"restrained_targets": restrained_targets.duplicate(),
		"concentration": true,
		"rounds_remaining": 10,
	}
	active_character.concentrating_on["entangle_source_id"] = source_id
	active_character.concentrating_on["duration_rounds_remaining"] = 10
	active_character.concentrating_on["duration_started_round"] = zones.tracker.current_round
	zones.hex_grid.add_difficult_terrain(source_id, coords)
	zones.hud.add_log("[color=olive]Entangling plants cover a 20-foot square for up to 1 minute, making it Difficult Terrain. A Restrained character can click their hex to spend an Action and attempt a Strength (Athletics) escape.[/color]")
	zones.refresh_grid.call()
	zones.highlight_reachable.call()


static func _apply_black_tentacles_restrained(zones: CombatSpellZones, target, source_id: String, restrained_targets: Array) -> void:
	CombatAction.apply_condition(target, "restrained", 99, source_id)
	var has_grant := false
	if target is Character:
		has_grant = target.condition_sources.get("restrained", {}).has(source_id)
	elif target is Dictionary:
		has_grant = target.get("condition_sources", {}).get("restrained", {}).has(source_id)
	if has_grant and target not in restrained_targets:
		restrained_targets.append(target)
		var target_name: String = target.character_name if target is Character else str(target.get("name", "The creature"))
		zones.hud.add_log("[color=purple]%s is Restrained by Black Tentacles.[/color]" % target_name)
		zones.refresh_grid.call()


static func _create_black_tentacles_zone(zones: CombatSpellZones, active_character: Character, pending_spell_data: Dictionary, center: Vector2i, source_id: String, restrained_targets: Array, initial_targets: Array, slot_level: int) -> void:
	var coords := Targeting.get_square_targets(center, 20, zones.hex_grid)
	if coords.is_empty():
		return
	var last_trigger_turn_by_target: Dictionary = {}
	for target_hex in initial_targets:
		var target = zones._spell_target_at_hex(target_hex)
		var target_id := zones._spell_zone_target_id(target)
		if not target_id.is_empty():
			last_trigger_turn_by_target[target_id] = zones._current_spell_trigger_turn()
	var concentrating := str(active_character.concentrating_on.get("spell_id", "")) == "black_tentacles"
	var duration_rounds := int(pending_spell_data.get("_black_tentacles_duration_rounds", 10))
	zones.active_spell_zones[source_id] = {
		"source_id": source_id,
		"spell_id": "black_tentacles",
		"caster_id": active_character.character_id,
		"coords": coords,
		"save_dc": active_character.get_spell_save_dc(),
		"last_trigger_turn_by_target": last_trigger_turn_by_target,
		"restrained_targets": restrained_targets.duplicate(),
		"slot_level": slot_level,
		"concentration": concentrating,
		"rounds_remaining": duration_rounds,
	}
	if concentrating:
		active_character.concentrating_on["black_tentacles_source_id"] = source_id
		active_character.concentrating_on["duration_rounds_remaining"] = duration_rounds
		active_character.concentrating_on["duration_started_round"] = zones.tracker.current_round
		var effect_source := str(active_character.concentrating_on.get("effect_source", ""))
		if effect_source.is_empty():
			var effect_cast: Dictionary = pending_spell_data.get("_effect_cast", {})
			if effect_cast.is_empty(): effect_cast = SpellEffects.begin_cast(active_character, DataLoader.get_spell("black_tentacles"))
			effect_source = str(effect_cast.get("source_id", ""))
			active_character.concentrating_on["effect_source"] = effect_source
			SpellEffects.records(active_character)[effect_source] = effect_cast.duplicate(true)
		if SpellEffects.records(active_character).has(effect_source):
			SpellEffects.records(active_character)[effect_source]["remaining_seconds"] = duration_rounds * 6
	zones.hex_grid.add_difficult_terrain(source_id, coords)
	var duration_text := "until dispelled" if duration_rounds < 0 else "24 hours" if slot_level >= 7 else "16 hours" if slot_level >= 5 and bool(pending_spell_data.get("_metamagic_extended", false)) else "8 hours" if slot_level >= 5 else "up to 2 minutes" if duration_rounds == 20 else "up to 1 minute"
	var concentration_text := " with Concentration" if concentrating else " without Concentration"
	zones.hud.add_log("[color=olive]Black Tentacles fill a 20-foot square for %s%s, making it Difficult Terrain. Restrained creatures can spend an Action on a Strength (Athletics) check to escape.[/color]" % [duration_text, concentration_text])
	zones.refresh_grid.call()
	zones.highlight_reachable.call()


static func _create_sleet_storm_zone(zones: CombatSpellZones, active_character: Character, center: Vector2i, source_id: String, extended: bool) -> void:
	var spell: Dictionary = DataLoader.get_spell("sleet_storm")
	var radius := int(spell.get("area_radius", 4))
	var coords := Targeting.get_sphere_targets(center, radius, zones.hex_grid)
	if coords.is_empty():
		return
	var duration_rounds := 20 if extended else 10
	zones.active_spell_zones[source_id] = {
		"source_id": source_id,
		"spell_id": "sleet_storm",
		"caster_id": active_character.character_id,
		"center": center,
		"coords": coords,
		"radius_feet": int(spell.get("area_radius", 4)) * 5,
		"height_feet": int(spell.get("area_height_feet", 40)),
		"save_dc": active_character.get_spell_save_dc(),
		"last_trigger_turn_by_target": {},
		"heavily_obscured": bool(spell.get("area_heavily_obscured", true)),
		"douses_exposed_flames": bool(spell.get("douses_exposed_flames", true)),
		"concentration": true,
		"rounds_remaining": duration_rounds,
	}
	active_character.concentrating_on["sleet_storm_source_id"] = source_id
	active_character.concentrating_on["save_dc"] = active_character.get_spell_save_dc()
	active_character.concentrating_on["duration_rounds_remaining"] = duration_rounds
	active_character.concentrating_on["duration_started_round"] = zones.tracker.current_round
	zones.hex_grid.add_difficult_terrain(source_id, coords)
	zones.hud.add_log("[color=sky_blue]Sleet Storm fills a %d-foot-radius Cylinder (%d feet high) for up to %s, making the ground Difficult Terrain. The area is Heavily Obscured.[/color]" % [int(spell.get("area_radius", 4)) * 5, int(spell.get("area_height_feet", 40)), "2 minutes" if extended else "1 minute"])
	zones.refresh_grid.call()
	zones.highlight_reachable.call()


static func _create_wall_of_fire_zone(zones: CombatSpellZones, active_character: Character, line_start: Vector2i, line_end: Vector2i, source_id: String, slot_level: int, extended: bool = false) -> void:
	var coords := HexUtils.hex_line(line_start, line_end)
	if coords.is_empty() or coords.size() > 13:
		return
	var dangerous_cells: Array[Vector2i] = coords.duplicate()
	var caster_hex := zones._spell_zone_target_hex(active_character)
	for wall_cell in coords:
		var nearest_side := Vector2i.ZERO
		var nearest_distance := 999
		for neighbor in HexUtils.get_neighbors(wall_cell):
			if not zones.hex_grid.has_tile(neighbor) or neighbor in coords:
				continue
			var distance := HexUtils.get_distance(caster_hex, neighbor)
			if distance < nearest_distance:
				nearest_distance = distance
				nearest_side = neighbor
		if nearest_distance < 999 and nearest_side not in dangerous_cells:
			dangerous_cells.append(nearest_side)
	var spell := DataLoader.get_spell("wall_of_fire")
	var damage_formula := CombatAction.spell_damage_formula(active_character, spell, slot_level)
	var duration_rounds := 20 if extended else 10
	zones.active_spell_zones[source_id] = {
		"source_id": source_id,
		"spell_id": "wall_of_fire",
		"caster_id": active_character.character_id,
		"center": line_start,
		"coords": coords,
		"dangerous_coords": dangerous_cells,
		"damage_formula": damage_formula,
		"save_dc": active_character.get_spell_save_dc(),
		"slot_level": slot_level,
		"concentration": true,
		"rounds_remaining": duration_rounds,
	}
	active_character.concentrating_on["wall_of_fire_source_id"] = source_id
	active_character.concentrating_on["save_dc"] = active_character.get_spell_save_dc()
	active_character.concentrating_on["duration_rounds_remaining"] = duration_rounds
	active_character.concentrating_on["duration_started_round"] = zones.tracker.current_round
	zones.hud.add_log("[color=orange]Wall of Fire burns in a line for up to 1 minute. Its dangerous side faces the caster.")
	zones.refresh_grid.call()
	zones.highlight_reachable.call()


static func _create_plant_growth_zone(zones: CombatSpellZones, active_character: Character, center: Vector2i) -> void:
	zones._spell_zone_serial += 1
	var source_id := "plant_growth:%s:%d" % [active_character.character_id, zones._spell_zone_serial]
	var coords := Targeting.get_sphere_targets(center, 20, zones.hex_grid)
	if coords.is_empty():
		return
	zones.active_spell_zones[source_id] = {
		"spell_id": "plant_growth",
		"caster_id": active_character.character_id,
		"center": center,
		"coords": coords,
		# Overgrowth has Instantaneous duration: the plants stay overgrown after the magic ends.
		"rounds_remaining": -1,
	}
	zones.hex_grid.add_movement_cost_override(source_id, coords, 4.0)
	zones.hud.add_log("[color=olive]Plant Growth overgrowth fills a 100-foot Sphere; each foot of movement through it costs 4 feet.[/color]")
	zones.refresh_grid.call()
	zones.highlight_reachable.call()


static func _create_fog_cloud_zone(zones: CombatSpellZones, active_character: Character, center: Vector2i, slot_level: int, extended: bool) -> void:
	if active_character == null or str(active_character.concentrating_on.get("spell_id", "")) != "fog_cloud" or not zones.hex_grid.has_tile(center):
		return
	zones._spell_zone_serial += 1
	var source_id := "fog_cloud:%s:%d" % [active_character.character_id, zones._spell_zone_serial]
	var radius_hexes := 4 + maxi(0, slot_level - 1) * 4
	var coords := Targeting.get_sphere_targets(center, radius_hexes, zones.hex_grid)
	if coords.is_empty():
		return
	var duration_rounds := 1200 if extended else 600
	zones.active_spell_zones[source_id] = {
		"source_id": source_id,
		"spell_id": "fog_cloud",
		"caster_id": active_character.character_id,
		"center": center,
		"coords": coords,
		"radius_hexes": radius_hexes,
		"radius_feet": radius_hexes * 5,
		"heavily_obscured": true,
		"concentration": true,
		"rounds_remaining": duration_rounds,
	}
	active_character.concentrating_on["fog_cloud_source_id"] = source_id
	active_character.concentrating_on["duration_rounds_remaining"] = duration_rounds
	active_character.concentrating_on["duration_started_round"] = zones.tracker.current_round
	var effect_source := str(active_character.concentrating_on.get("effect_source", ""))
	if effect_source.is_empty():
		var effect_cast := SpellEffects.begin_cast(active_character, DataLoader.get_spell("fog_cloud"))
		effect_source = str(effect_cast.get("source_id", ""))
		active_character.concentrating_on["effect_source"] = effect_source
		SpellEffects.records(active_character)[effect_source] = effect_cast.duplicate(true)
	if SpellEffects.records(active_character).has(effect_source):
		SpellEffects.records(active_character)[effect_source]["remaining_seconds"] = duration_rounds * 6
	zones._refresh_fog_cloud_conditions()
	var duration_text := "up to 2 hours" if extended else "up to 1 hour"
	zones.hud.add_log("[color=sky_blue]Fog Cloud creates a %d-foot-radius Heavily Obscured Sphere for %s with Concentration.[/color]" % [radius_hexes * 5, duration_text])
	zones.refresh_grid.call()
	zones.highlight_reachable.call()


static func _create_darkness_zone(zones: CombatSpellZones, active_character: Character, center: Vector2i, extended: bool) -> void:
	if active_character == null or str(active_character.concentrating_on.get("spell_id", "")) != "darkness" or not zones.hex_grid.has_tile(center):
		return
	zones._spell_zone_serial += 1
	var source_id := "darkness:%s:%d" % [active_character.character_id, zones._spell_zone_serial]
	var radius_hexes := 3
	var coords := Targeting.get_sphere_targets(center, radius_hexes, zones.hex_grid)
	if coords.is_empty():
		return
	var duration_rounds := 200 if extended else 100
	zones.active_spell_zones[source_id] = {
		"source_id": source_id,
		"spell_id": "darkness",
		"caster_id": active_character.character_id,
		"center": center,
		"coords": coords,
		"radius_hexes": radius_hexes,
		"radius_feet": 15,
		"heavily_obscured": true,
		"concentration": true,
		"rounds_remaining": duration_rounds,
	}
	active_character.concentrating_on["darkness_source_id"] = source_id
	active_character.concentrating_on["duration_rounds_remaining"] = duration_rounds
	active_character.concentrating_on["duration_started_round"] = zones.tracker.current_round
	var effect_source := str(active_character.concentrating_on.get("effect_source", ""))
	if effect_source.is_empty():
		var effect_cast := SpellEffects.begin_cast(active_character, DataLoader.get_spell("darkness"))
		effect_source = str(effect_cast.get("source_id", ""))
		active_character.concentrating_on["effect_source"] = effect_source
		SpellEffects.records(active_character)[effect_source] = effect_cast.duplicate(true)
	if SpellEffects.records(active_character).has(effect_source):
		SpellEffects.records(active_character)[effect_source]["remaining_seconds"] = duration_rounds * 6
	for caster_id in zones.light_spell_markers.keys().duplicate():
		var marker: Dictionary = zones.light_spell_markers[caster_id]
		var position: Array = marker.get("position", [0, 0])
		var light_center := Vector2i(int(position[0]), int(position[1]))
		if light_is_dispersed_by_darkness(zones.active_spell_zones, light_center, LightRules.DIM_RADIUS_HEXES):
			zones.light_spell_markers.erase(caster_id)
	for caster_id in zones.produce_flame_markers.keys().duplicate():
		var flame: Dictionary = zones.produce_flame_markers[caster_id]
		var flame_position: Array = flame.get("position", [0, 0])
		var flame_center := Vector2i(int(flame_position[0]), int(flame_position[1]))
		if HexUtils.get_distance(center, flame_center) <= radius_hexes + ProduceFlameRules.DIM_LIGHT_RADIUS_HEXES:
			zones.produce_flame_markers.erase(caster_id)
	for caster_id in zones.dancing_light_sets.keys().duplicate():
		var light_set: Dictionary = zones.dancing_light_sets[caster_id]
		var overlaps := false
		for position_value in light_set.get("positions", []):
			var dancing_light_center := Vector2i(int(position_value[0]), int(position_value[1]))
			if HexUtils.get_distance(center, dancing_light_center) <= radius_hexes + DancingLightsRules.DIM_LIGHT_RADIUS_HEXES:
				overlaps = true
				break
		if overlaps:
			var light_caster := zones._spell_zone_caster({"caster_id": str(caster_id)})
			if light_caster != null and str(light_caster.concentrating_on.get("spell_id", "")) == "dancing_lights":
				zones.end_concentration.call(light_caster)
			else:
				zones.dancing_light_sets.erase(caster_id)
	zones._refresh_darkness_conditions()
	zones.hud.add_log("[color=sky_blue]Magical Darkness fills a 15-foot-radius Sphere for up to 10 minutes with Concentration.[/color]")
	zones.refresh_grid.call()
	zones.highlight_reachable.call()


static func _create_cloudkill_zone(zones: CombatSpellZones, active_character: Character, center: Vector2i, source_id: String, slot_level: int, extended: bool) -> void:
	var spell: Dictionary = DataLoader.get_spell("cloudkill")
	var radius := int(spell.get("area_radius", 4))
	var coords := Targeting.get_sphere_targets(center, radius, zones.hex_grid)
	if coords.is_empty():
		return
	var last_trigger_turn_by_target: Dictionary = {}
	for coord in coords:
		var initial_target = zones._spell_target_at_hex(coord)
		var target_id := zones._spell_zone_target_id(initial_target)
		if not target_id.is_empty():
			last_trigger_turn_by_target[target_id] = zones._current_spell_trigger_turn()
	var duration_rounds := 200 if extended else 100
	zones.active_spell_zones[source_id] = {
		"source_id": source_id,
		"spell_id": "cloudkill",
		"caster_id": active_character.character_id,
		"center": center,
		"coords": coords,
		"radius_hexes": radius,
		"slot_level": slot_level,
		"save_dc": active_character.get_spell_save_dc(),
		"damage_formula": CombatAction.spell_damage_formula(active_character, spell, slot_level),
		"heavily_obscured": bool(spell.get("area_heavily_obscured", true)),
		"last_trigger_turn_by_target": last_trigger_turn_by_target,
		"cast_turn": zones._current_spell_trigger_turn(),
		"last_move_turn": zones._current_spell_trigger_turn(),
		"concentration": true,
		"rounds_remaining": duration_rounds,
	}
	active_character.concentrating_on["cloudkill_source_id"] = source_id
	active_character.concentrating_on["save_dc"] = active_character.get_spell_save_dc()
	active_character.concentrating_on["duration_rounds_remaining"] = duration_rounds
	active_character.concentrating_on["duration_started_round"] = zones.tracker.current_round
	zones.hud.add_log("[color=olive]Cloudkill fills a 20-foot-radius Sphere with Heavily Obscured fog. Creatures save when it appears, enters their space, they enter it, or end their turn there; it drifts 10 feet away from you at the start of your turns.[/color]")
	zones.refresh_grid.call()
	zones.highlight_reachable.call()


static func _create_cloud_of_daggers_zone(zones: CombatSpellZones, active_character: Character, center: Vector2i, slot_level: int, extended: bool) -> void:
	if active_character == null or str(active_character.concentrating_on.get("spell_id", "")) != "cloud_of_daggers" or not zones.hex_grid.has_tile(center):
		return
	zones._spell_zone_serial += 1
	var source_id := "cloud_of_daggers:%s:%d" % [active_character.character_id, zones._spell_zone_serial]
	var coords: Array[Vector2i] = [center]
	var last_trigger_turn_by_target: Dictionary = {}
	for coord in coords:
		var initial_target = zones._spell_target_at_hex(coord)
		var target_id := zones._spell_zone_target_id(initial_target)
		if not target_id.is_empty():
			last_trigger_turn_by_target[target_id] = zones._current_spell_trigger_turn()
	var duration_rounds := 20 if extended else 10
	var damage_dice := 4 + maxi(0, slot_level - 2) * 2
	zones.active_spell_zones[source_id] = {
		"source_id": source_id,
		"spell_id": "cloud_of_daggers",
		"caster_id": active_character.character_id,
		"center": center,
		"coords": coords,
		"slot_level": slot_level,
		"damage_formula": "%dd4" % damage_dice,
		"cast_turn": zones._current_spell_trigger_turn(),
		"last_trigger_turn_by_target": last_trigger_turn_by_target,
		"concentration": true,
		"rounds_remaining": duration_rounds,
	}
	active_character.concentrating_on["cloud_of_daggers_source_id"] = source_id
	active_character.concentrating_on["duration_rounds_remaining"] = duration_rounds
	active_character.concentrating_on["duration_started_round"] = zones.tracker.current_round
	zones.hud.add_log("[color=cyan]Cloud of Daggers occupies one 5-foot hex for up to %s. On later turns, you can teleport it up to 30 feet with a Magic action.[/color]" % ["2 minutes" if extended else "1 minute"])
	zones.refresh_grid.call()
	zones.highlight_reachable.call()


static func _create_moonbeam_zone(zones: CombatSpellZones, active_character: Character, center: Vector2i, slot_level: int, initial_targets: Array, source_id: String, shape_locked_targets: Array) -> void:
	var coords := Targeting.get_sphere_targets(center, 1, zones.hex_grid)
	if coords.is_empty():
		return
	var last_trigger_turn_by_target: Dictionary = {}
	for target_hex in initial_targets:
		var initial_target = zones._spell_target_at_hex(target_hex)
		var target_id := zones._spell_zone_target_id(initial_target)
		if not target_id.is_empty():
			last_trigger_turn_by_target[target_id] = zones._current_spell_trigger_turn()
	zones.active_spell_zones[source_id] = {
		"source_id": source_id,
		"spell_id": "moonbeam",
		"caster_id": active_character.character_id,
		"center": center,
		"coords": coords,
		"slot_level": slot_level,
		"save_dc": active_character.get_spell_save_dc(),
		"last_trigger_turn_by_target": last_trigger_turn_by_target,
		"shape_locked_targets": shape_locked_targets.duplicate(),
		"cast_turn": zones._current_spell_trigger_turn(),
		"rounds_remaining": 10,
	}
	active_character.concentrating_on["duration_rounds_remaining"] = 10
	active_character.concentrating_on["duration_started_round"] = zones.tracker.current_round
	active_character.concentrating_on["moonbeam_source_id"] = source_id
	zones.hud.add_log("[color=cyan]Moonbeam fills a 5-foot-radius Cylinder with Dim Light. You can move it up to 60 feet with a Magic action on a later turn.[/color]")
	zones.refresh_grid.call()
	zones.highlight_reachable.call()


static func _resolve_moonbeam_zone_save(zones: CombatSpellZones, target, zone: Dictionary) -> Dictionary:
	var target_id := zones._spell_zone_target_id(target)
	if target_id.is_empty():
		return {}
	var last_trigger_turn_by_target: Dictionary = zone.get("last_trigger_turn_by_target", {})
	var current_turn := zones._current_spell_trigger_turn()
	if str(last_trigger_turn_by_target.get(target_id, "")) == current_turn:
		return {"success": true, "skipped": true, "reason": "already_triggered_this_turn"}
	last_trigger_turn_by_target[target_id] = current_turn
	zone["last_trigger_turn_by_target"] = last_trigger_turn_by_target
	var caster := zones._spell_zone_caster(zone)
	if caster == null:
		return {}
	var spell_data: Dictionary = DataLoader.get_spell("moonbeam").duplicate(true)
	var target_was_shape_shifted := target is Character and DruidRules.is_shaped(target)
	spell_data["_ongoing_zone_trigger"] = true
	spell_data["_save_dc_override"] = int(zone.get("save_dc", caster.get_spell_save_dc()))
	spell_data["_skip_counterspell"] = true
	var decisions: Dictionary = await zones.collect_save_decisions.call(target, "Moonbeam", spell_data)
	var result := CombatAction.resolve_spell(caster, target, spell_data, false, decisions, [], int(zone.get("slot_level", 2)), 0)
	var target_name: String = target.character_name if target is Character else str(target.get("name", "The creature"))
	zones.hud.add_log("[color=cyan]%s %s the Moonbeam Constitution save (%d vs DC %d) and takes %d Radiant damage.[/color]" % [target_name, "succeeds on" if bool(result.get("saved", false)) else "fails", int(result.get("save_total", 0)), int(zone.get("save_dc", 0)), int(result.get("damage", 0))])
	if not bool(result.get("saved", true)) and target is Character and target_was_shape_shifted:
		var locked_targets: Array = zone.get("shape_locked_targets", [])
		if SpellZoneTerrain._apply_moonbeam_shape_change(zones, target, str(zone.get("source_id", "moonbeam")), locked_targets, true):
			zone["shape_locked_targets"] = locked_targets
			zones.hud.add_log("[color=yellow]%s reverts to normal form and can't shape-shift until leaving the Moonbeam.[/color]" % target_name)
	if int(result.get("resolved", result.get("damage", 0))) > 0 and target is Character:
		await zones.check_concentration.call(target, int(result.get("resolved", result.get("damage", 0))))
	elif target is Dictionary and int(target.get("current_hp", 0)) <= 0 and bool(target.get("is_alive", true)):
		target["is_alive"] = false
		zones.tracker.remove_combatant(str(target.get("id", "")))
		zones.enemy_defeated.call(target, caster)
	if target is Character and not target.is_alive:
		zones.end_concentration.call(target)
	return result


static func _apply_moonbeam_shape_change(zones: CombatSpellZones, target: Character, source_id: String, locked_targets: Array, was_shape_shifted: bool = false) -> bool:
	if target == null or (not DruidRules.is_shaped(target) and not was_shape_shifted):
		return false
	if DruidRules.is_shaped(target):
		DruidRules.revert(target)
	CombatAction.apply_condition(target, "moonbeam_shape_lock", 99, "%s:shape_lock" % source_id)
	if target not in locked_targets:
		locked_targets.append(target)
	zones.refresh_grid.call()
	return true


static func _resolve_spell_zone_save(zones: CombatSpellZones, target, zone: Dictionary) -> Dictionary:
	var caster: Character = zones._spell_zone_caster(zone)
	if caster == null:
		return {}
	var spell_data := DataLoader.get_spell("grease").duplicate(true)
	spell_data["_ongoing_zone_trigger"] = true
	spell_data["_save_dc_override"] = int(zone.get("save_dc", caster.get_spell_save_dc()))
	spell_data["_skip_counterspell"] = true
	spell_data["condition_on_failed_save"] = "prone"
	spell_data["condition_duration"] = 99
	var decisions: Dictionary = await zones.collect_save_decisions.call(target, "Grease", spell_data)
	var result := CombatAction.resolve_spell(caster, target, spell_data, false, decisions, [], 1, 0)
	var target_name: String = target.character_name if target is Character else str(target.get("name", "The creature"))
	zones.hud.add_log("%s %s the Grease Dexterity save (%d vs DC %d)." % [target_name, "succeeds on" if result.get("saved", false) else "fails", int(result.get("save_total", 0)), int(zone.get("save_dc", 0))])
	if not result.get("saved", false):
		CombatAction.apply_condition(target, "prone", 99)
		zones.refresh_grid.call()
	return result


static func _resolve_black_tentacles_zone_save(zones: CombatSpellZones, target, zone: Dictionary) -> Dictionary:
	var target_id := zones._spell_zone_target_id(target)
	if target_id.is_empty():
		return {}
	var last_trigger_turn_by_target: Dictionary = zone.get("last_trigger_turn_by_target", {})
	var current_turn := zones._current_spell_trigger_turn()
	if str(last_trigger_turn_by_target.get(target_id, "")) == current_turn:
		return {"success": true, "saved": true, "skipped": true, "reason": "already_triggered_this_turn"}
	last_trigger_turn_by_target[target_id] = current_turn
	zone["last_trigger_turn_by_target"] = last_trigger_turn_by_target
	var caster := zones._spell_zone_caster(zone)
	if caster == null:
		return {}
	var spell_data: Dictionary = DataLoader.get_spell("black_tentacles").duplicate(true)
	spell_data["condition_on_failed_save"] = ""
	spell_data["_ongoing_zone_trigger"] = true
	spell_data["_save_dc_override"] = int(zone.get("save_dc", caster.get_spell_save_dc()))
	spell_data["_skip_counterspell"] = true
	var decisions: Dictionary = await zones.collect_save_decisions.call(target, "Black Tentacles", spell_data)
	var result := CombatAction.resolve_spell(caster, target, spell_data, false, decisions, [], int(zone.get("slot_level", 4)), 0)
	if not bool(result.get("saved", true)):
		SpellZoneTerrain._apply_black_tentacles_restrained(zones, target, str(zone.get("source_id", "")), zone.get("restrained_targets", []))
	var target_name: String = target.character_name if target is Character else str(target.get("name", "The creature"))
	var outcome := "succeeds on" if bool(result.get("saved", false)) else "fails"
	var damage_text := " and takes %d Bludgeoning damage" % int(result.get("damage", 0)) if not bool(result.get("saved", true)) else ""
	zones.hud.add_log("%s %s the Black Tentacles Strength save (%d vs DC %d)%s." % [target_name, outcome, int(result.get("save_total", 0)), int(zone.get("save_dc", 0)), damage_text])
	var damage_taken := int(result.get("damage", 0))
	if target is Character and damage_taken > 0:
		await zones.check_concentration.call(target, damage_taken)
	elif target is Dictionary and int(target.get("current_hp", 0)) <= 0 and bool(target.get("is_alive", true)):
		target["is_alive"] = false
		zones.tracker.remove_combatant(str(target.get("id", "")))
		zones.enemy_defeated.call(target, caster)
	if target is Character and not target.is_alive:
		zones.end_concentration.call(target)
	return result


static func _resolve_sleet_storm_zone_save(zones: CombatSpellZones, target, zone: Dictionary) -> Dictionary:
	var target_id := zones._spell_zone_target_id(target)
	if target_id.is_empty():
		return {}
	var last_trigger_turn_by_target: Dictionary = zone.get("last_trigger_turn_by_target", {})
	var current_turn := zones._current_spell_trigger_turn()
	if str(last_trigger_turn_by_target.get(target_id, "")) == current_turn:
		return {"success": true, "saved": true, "skipped": true, "reason": "already_triggered_this_turn"}
	last_trigger_turn_by_target[target_id] = current_turn
	zone["last_trigger_turn_by_target"] = last_trigger_turn_by_target
	var caster := zones._spell_zone_caster(zone)
	if caster == null:
		return {}
	var spell_data: Dictionary = DataLoader.get_spell("sleet_storm").duplicate(true)
	spell_data["_ongoing_zone_trigger"] = true
	spell_data["_save_dc_override"] = int(zone.get("save_dc", caster.get_spell_save_dc()))
	spell_data["_skip_counterspell"] = true
	var decisions: Dictionary = await zones.collect_save_decisions.call(target, "Sleet Storm", spell_data)
	var result := CombatAction.resolve_spell(caster, target, spell_data, false, decisions, [], 3, 0)
	var target_name: String = target.character_name if target is Character else str(target.get("name", "The creature"))
	if not bool(result.get("saved", true)):
		var concentration_ended := false
		if target is Character and not target.concentrating_on.is_empty():
			zones.end_concentration.call(target)
			concentration_ended = true
		elif target is Dictionary and target.get("concentrating_on", {}) is Dictionary and not target.get("concentrating_on", {}).is_empty():
			target["concentrating_on"] = {}
			target["concentrating_spell"] = ""
			concentration_ended = true
		zones.hud.add_log("%s fails the Sleet Storm Dexterity save (%d vs DC %d), falls Prone%s." % [target_name, int(result.get("save_total", 0)), int(zone.get("save_dc", 0)), " and loses Concentration" if concentration_ended else ""])
	else:
		zones.hud.add_log("%s succeeds on the Sleet Storm Dexterity save (%d vs DC %d)." % [target_name, int(result.get("save_total", 0)), int(zone.get("save_dc", 0))])
	zones.refresh_grid.call()
	return result


static func _resolve_wall_of_fire_damage(zones: CombatSpellZones, target, zone: Dictionary, on_entry: bool = true) -> Dictionary:
	var target_id := zones._spell_zone_target_id(target)
	if target_id.is_empty():
		return {}
	# First entry and end of turn are separate damage triggers. Only the
	# appearance damage allows a Dexterity save.
	var trigger_id := target_id if on_entry else "%s:end" % target_id
	var last_trigger_turn_by_target: Dictionary = zone.get("last_trigger_turn_by_target", {})
	var current_turn := zones._current_spell_trigger_turn()
	if str(last_trigger_turn_by_target.get(trigger_id, "")) == current_turn:
		return {"success": true, "skipped": true, "reason": "already_triggered_this_turn"}
	last_trigger_turn_by_target[trigger_id] = current_turn
	zone["last_trigger_turn_by_target"] = last_trigger_turn_by_target
	var caster := zones._spell_zone_caster(zone)
	if caster == null:
		return {}
	var formula := str(zone.get("damage_formula", "5d8"))
	var amount := int(Dice.parse_dice_details(formula, {}, caster).get("final_total", 0))
	var damage_result := CombatAction.resolve_damage(target, amount, "fire", {}, false, false, caster)
	var target_name: String = target.character_name if target is Character else str(target.get("name", "The creature"))
	var dealt := int(damage_result.get("damage", 0))
	var damage_taken := int(damage_result.get("resolved", 0))
	zones.hud.add_log("%s takes %d Fire damage from Wall of Fire (%s)." % [target_name, dealt, formula])
	if target is Character and damage_taken > 0:
		await zones.check_concentration.call(target, damage_taken)
	elif target is Dictionary and int(target.get("current_hp", 0)) <= 0 and bool(target.get("is_alive", true)):
		target["is_alive"] = false
		zones.tracker.remove_combatant(str(target.get("id", "")))
		zones.enemy_defeated.call(target, caster)
	if target is Character and not target.is_alive:
		zones.end_concentration.call(target)
	return {"success": true, "damage": dealt, "resolved": damage_taken}


static func _resolve_cloud_of_daggers_damage(zones: CombatSpellZones, target, zone: Dictionary) -> Dictionary:
	var target_id := zones._spell_zone_target_id(target)
	if target_id.is_empty():
		return {}
	var last_trigger_turn_by_target: Dictionary = zone.get("last_trigger_turn_by_target", {})
	var current_turn := zones._current_spell_trigger_turn()
	if str(last_trigger_turn_by_target.get(target_id, "")) == current_turn:
		return {"success": true, "skipped": true, "reason": "already_triggered_this_turn"}
	last_trigger_turn_by_target[target_id] = current_turn
	zone["last_trigger_turn_by_target"] = last_trigger_turn_by_target
	var caster := zones._spell_zone_caster(zone)
	if caster == null:
		return {}
	var formula := str(zone.get("damage_formula", "4d4"))
	var amount := int(Dice.parse_dice_details(formula, {}, caster).get("final_total", 0))
	var damage_result := CombatAction.resolve_damage(target, amount, "slashing", {}, false, false, caster)
	var target_name: String = target.character_name if target is Character else str(target.get("name", "The creature"))
	var dealt := int(damage_result.get("damage", 0))
	zones.hud.add_log("[color=red]%s takes %d Slashing damage from Cloud of Daggers (%s).[/color]" % [target_name, dealt, formula])
	var damage_taken := int(damage_result.get("resolved", 0))
	if target is Character and damage_taken > 0:
		await zones.check_concentration.call(target, damage_taken)
	elif target is Dictionary and int(target.get("current_hp", 0)) <= 0 and bool(target.get("is_alive", true)):
		target["is_alive"] = false
		zones.tracker.remove_combatant(str(target.get("id", "")))
		zones.enemy_defeated.call(target, caster)
	if target is Character and not target.is_alive:
		zones.end_concentration.call(target)
	return {"success": true, "damage": dealt, "resolved": damage_taken}


static func _resolve_cloudkill_zone_save(zones: CombatSpellZones, target, zone: Dictionary) -> Dictionary:
	var target_id := zones._spell_zone_target_id(target)
	if target_id.is_empty():
		return {}
	var last_trigger_turn_by_target: Dictionary = zone.get("last_trigger_turn_by_target", {})
	var current_turn := zones._current_spell_trigger_turn()
	if str(last_trigger_turn_by_target.get(target_id, "")) == current_turn:
		return {"success": true, "skipped": true, "reason": "already_triggered_this_turn"}
	last_trigger_turn_by_target[target_id] = current_turn
	zone["last_trigger_turn_by_target"] = last_trigger_turn_by_target
	var caster := zones._spell_zone_caster(zone)
	if caster == null:
		return {}
	var spell_data: Dictionary = DataLoader.get_spell("cloudkill").duplicate(true)
	spell_data["_ongoing_zone_trigger"] = true
	spell_data["_save_dc_override"] = int(zone.get("save_dc", caster.get_spell_save_dc()))
	spell_data["_skip_counterspell"] = true
	var decisions: Dictionary = await zones.collect_save_decisions.call(target, "Cloudkill", spell_data)
	var result := CombatAction.resolve_spell(caster, target, spell_data, false, decisions, [], int(zone.get("slot_level", 5)), 0)
	var target_name: String = target.character_name if target is Character else str(target.get("name", "The creature"))
	zones.hud.add_log("%s %s the Cloudkill Constitution save (%d vs DC %d), taking %d Poison damage." % [target_name, "succeeds on" if bool(result.get("saved", false)) else "fails", int(result.get("save_total", 0)), int(zone.get("save_dc", 0)), int(result.get("damage", 0))])
	var damage_taken := int(result.get("damage", 0))
	if target is Character and damage_taken > 0:
		await zones.check_concentration.call(target, damage_taken)
	elif target is Dictionary and int(target.get("current_hp", 0)) <= 0 and bool(target.get("is_alive", true)):
		target["is_alive"] = false
		zones.tracker.remove_combatant(str(target.get("id", "")))
		zones.enemy_defeated.call(target, caster)
	if target is Character and not target.is_alive:
		zones.end_concentration.call(target)
	return result


