## Encounter-local spell areas: ownership, spatial queries, movement/turn triggers and cleanup.
## Rules modules receive this bounded context; they never receive CombatState.
class_name CombatSpellZones
extends RefCounted

var active_spell_zones: Dictionary = {}
var _spell_zone_serial := 0
var hex_grid: HexGrid
var hud: CombatHUD
var tracker: InitiativeTracker
var player_entities: Array[Dictionary] = []
var monster_entities: Array[Dictionary] = []
var light_spell_markers: Dictionary = {}
var produce_flame_markers: Dictionary = {}
var dancing_light_sets: Dictionary = {}

# Combat owns prompts, reactions, defeat rewards and redraws. Awaited callbacks
# preserve their existing order around the shared CombatAction resolver.
var collect_save_decisions: Callable
var collect_attack_decision: Callable
var collect_shield_decision: Callable
var check_concentration: Callable
var end_concentration: Callable
var enemy_defeated: Callable
var refresh_grid: Callable
var highlight_reachable: Callable

func bind_encounter(grid: HexGrid, combat_hud: CombatHUD, initiative: InitiativeTracker, players: Array[Dictionary], monsters: Array[Dictionary]) -> void:
	hex_grid = grid
	hud = combat_hud
	tracker = initiative
	player_entities = players
	monster_entities = monsters

func _current_spell_trigger_turn() -> String:
	return "%d:%s" % [tracker.current_round, str(tracker.get_active().get("id", ""))]


func _spell_zone_target_id(target) -> String:
	if target is Character:
		return target.character_id
	return str(target.get("id", "")) if target is Dictionary else ""


func _spell_zone_target_hex(target) -> Vector2i:
	if target is Character:
		for entity in player_entities:
			if entity.get("character") == target:
				return entity.get("hex_position", Vector2i.ZERO)
	elif target is Dictionary:
		return target.get("hex_position", Vector2i.ZERO)
	return Vector2i.ZERO


func _has_spell_condition_source(target, source_id: String, condition: String = "restrained") -> bool:
	if target is Character:
		return target.condition_sources.get(condition, {}).has(source_id)
	if target is Dictionary:
		return target.get("condition_sources", {}).get(condition, {}).has(source_id)
	return false


func _spell_target_at_hex(target_hex: Vector2i):
	for entity in player_entities:
		var character: Character = entity.get("character")
		if character != null and (character.is_alive or character.is_downed()) and entity.get("hex_position", Vector2i.ZERO) == target_hex:
			return character
	for monster in monster_entities:
		if monster.get("is_alive", false) and monster.get("hex_position", Vector2i.ZERO) == target_hex:
			return monster
	return null


func _cloud_of_daggers_zone_source_for_caster(caster: Character) -> String:
	return source_for_caster(caster, "cloud_of_daggers")


func _conjure_animals_zone_source_for_caster(caster: Character) -> String:
	return source_for_caster(caster, "conjure_animals")


func _refresh_conjure_animals_strength_advantage(caster: Character) -> void:
	if caster == null:
		return
	var source_id := _conjure_animals_zone_source_for_caster(caster)
	var zone: Dictionary = active_spell_zones.get(source_id, {})
	var caster_hex := Vector2i.ZERO
	for entity in player_entities:
		if entity.get("character") == caster:
			caster_hex = entity.get("hex_position", Vector2i.ZERO)
			break
	if not zone.is_empty() and HexUtils.get_distance(caster_hex, zone.get("center", Vector2i.ZERO)) <= 1:
		caster.feature_uses["conjure_animals_strength_advantage"] = true
	else:
		caster.feature_uses.erase("conjure_animals_strength_advantage")


func _conjure_celestial_zone_source_for_caster(caster: Character) -> String:
	return source_for_caster(caster, "conjure_celestial")


func _resolve_conjure_celestial_area_movement(zone: Dictionary, old_coords: Array, new_coords: Array) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	for coord in new_coords:
		if coord in old_coords:
			continue
		var target = _spell_target_at_hex(coord)
		if target != null:
			results.append(await SpellZoneConjurations._resolve_conjure_celestial_zone_trigger(self, target, zone))
	return results


func _conjure_elemental_zone_source_for_caster(caster: Character) -> String:
	return source_for_caster(caster, "conjure_elemental")


func _is_unoccupied_conjure_fey_space(center: Vector2i) -> bool:
	if not hex_grid.has_tile(center) or _has_creature_at(center):
		return false
	for zone in active_spell_zones.values():
		if str(zone.get("spell_id", "")) == "conjure_fey" and zone.get("center", Vector2i.ZERO) == center:
			return false
		if str(zone.get("spell_id", "")) == "conjure_elemental" and center in zone.get("coords", []):
			return false
	return true


func _conjure_fey_zone_source_for_caster(caster: Character) -> String:
	return source_for_caster(caster, "conjure_fey")


func _conjure_minor_elementals_zone_source_for_caster(caster: Character) -> String:
	return source_for_caster(caster, "conjure_minor_elementals")


func _conjure_woodland_beings_zone_source_for_caster(caster: Character) -> String:
	return source_for_caster(caster, "conjure_woodland_beings")


func _character_combat_hex(character: Character) -> Vector2i:
	for player in player_entities:
		if player.get("character") == character:
			return player.get("hex_position", Vector2i.ZERO)
	return Vector2i.ZERO


func _spirit_guardians_zone_source_for_caster(caster: Character) -> String:
	return source_for_caster(caster, "spirit_guardians")


func _aura_of_life_zone_source_for_caster(caster: Character) -> String:
	return source_for_caster(caster, "aura_of_life")


func _refresh_aura_of_life_protection() -> void:
	for player in player_entities:
		var character: Character = player.get("character")
		if character != null:
			character.aura_of_life_sources.clear()
	for monster in monster_entities:
		monster["aura_of_life_sources"] = []
	for source_id_value in active_spell_zones:
		var source_id := str(source_id_value)
		var zone: Dictionary = active_spell_zones[source_id]
		if str(zone.get("spell_id", "")) != "aura_of_life":
			continue
		var caster := _spell_zone_caster(zone)
		if caster == null:
			continue
		var caster_hex := _character_combat_hex(caster)
		var radius := int(zone.get("radius_hexes", 6))
		for player in player_entities:
			var ally: Character = player.get("character")
			if ally != null and HexUtils.get_distance(player.get("hex_position", Vector2i.ZERO), caster_hex) <= radius:
				ally.aura_of_life_sources.append(source_id)


func _aura_of_life_allows_hp_maximum(target: Character) -> bool:
	return target != null and not target.aura_of_life_sources.is_empty()


func _spirit_guardians_movement_slowed(target, coord: Vector2i) -> bool:
	var target_id := _spell_zone_target_id(target)
	for zone in active_spell_zones.values():
		if str(zone.get("spell_id", "")) != "spirit_guardians" or not SpellZoneConjurations._spirit_guardians_zone_affects_target(self, zone, target_id):
			continue
		var caster := _spell_zone_caster(zone)
		if caster != null and HexUtils.get_distance(coord, _character_combat_hex(caster)) <= int(zone.get("radius_hexes", 3)):
			return true
	return false


func _resolve_spirit_guardians_area_movement(zone: Dictionary, old_center: Vector2i, new_center: Vector2i) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var radius := int(zone.get("radius_hexes", 3))
	var old_coords := Targeting.get_sphere_targets(old_center, radius, hex_grid)
	var new_coords := Targeting.get_sphere_targets(new_center, radius, hex_grid)
	for coord in new_coords:
		if coord in old_coords:
			continue
		var target = _spell_target_at_hex(coord)
		if target != null:
			results.append(await SpellZoneConjurations._resolve_spirit_guardians_zone_save(self, target, zone))
	return results


func _conjure_minor_elementals_applies_to_target(caster: Character, target) -> bool:
	var source_id := _conjure_minor_elementals_zone_source_for_caster(caster)
	if source_id.is_empty() or target == null:
		return false
	var zone: Dictionary = active_spell_zones.get(source_id, {})
	return HexUtils.get_distance(_character_combat_hex(caster), _spell_zone_target_hex(target)) <= int(zone.get("radius_hexes", 3))


func _conjure_fey_targets_within(center: Vector2i) -> Array[Dictionary]:
	var targets: Array[Dictionary] = []
	for player in player_entities:
		var character: Character = player.get("character")
		if character == null or not character.is_alive or HexUtils.get_distance(player.get("hex_position", Vector2i.ZERO), center) > 1:
			continue
		targets.append({"id": character.character_id, "name": character.character_name})
	for monster in monster_entities:
		if bool(monster.get("is_alive", false)) and HexUtils.get_distance(monster.get("hex_position", Vector2i.ZERO), center) <= 1:
			targets.append({"id": str(monster.get("id", "")), "name": str(monster.get("name", "The creature"))})
	return targets


func _conjure_fey_target_by_id(target_id: String):
	if target_id.is_empty():
		return null
	for player in player_entities:
		var character: Character = player.get("character")
		if character != null and character.is_alive and character.character_id == target_id:
			return character
	for monster in monster_entities:
		if bool(monster.get("is_alive", false)) and str(monster.get("id", "")) == target_id:
			return monster
	return null


func _expire_conjure_fey_frightened(caster: Character) -> void:
	var source_id := _conjure_fey_zone_source_for_caster(caster)
	if source_id.is_empty():
		return
	var zone: Dictionary = active_spell_zones.get(source_id, {})
	for target in zone.get("frightened_targets", []):
		CombatAction.remove_condition_source(target, source_id, ["frightened"])
	zone["frightened_targets"] = []


func _resolve_conjure_woodland_beings_area_movement(zone: Dictionary, old_center: Vector2i, new_center: Vector2i) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var radius := int(zone.get("radius_hexes", 2))
	var old_coords := Targeting.get_sphere_targets(old_center, radius, hex_grid)
	var new_coords := Targeting.get_sphere_targets(new_center, radius, hex_grid)
	for coord in new_coords:
		if coord in old_coords:
			continue
		var target = _spell_target_at_hex(coord)
		if target != null:
			results.append(await SpellZoneConjurations._resolve_conjure_woodland_beings_zone_save(self, target, zone))
	return results


func _resolve_conjure_animals_area_movement(zone: Dictionary, old_coords: Array, new_coords: Array) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	for coord in new_coords:
		if coord in old_coords:
			continue
		var target = _spell_target_at_hex(coord)
		if target != null:
			results.append(await SpellZoneConjurations._resolve_conjure_animals_zone_save(self, target, zone))
	return results


func _refresh_fog_cloud_conditions() -> void:
	var targets := _spell_effect_targets()
	for target in targets:
		for source_id_value in active_spell_zones.keys():
			var source_id := str(source_id_value)
			if str(active_spell_zones[source_id].get("spell_id", "")) == "fog_cloud":
				CombatAction.remove_condition_source(target, source_id, ["fog_cloud_obscured"])
	for source_id_value in active_spell_zones.keys():
		var source_id := str(source_id_value)
		var zone: Dictionary = active_spell_zones[source_id]
		if str(zone.get("spell_id", "")) != "fog_cloud":
			continue
		var zone_coords: Array = zone.get("coords", [])
		for target in targets:
			if _spell_zone_target_hex(target) in zone_coords:
				CombatAction.apply_condition(target, "fog_cloud_obscured", 70000, source_id)


func _refresh_darkness_conditions() -> void:
	var targets := _spell_effect_targets()
	for target in targets:
		for source_id_value in active_spell_zones.keys():
			var source_id := str(source_id_value)
			if str(active_spell_zones[source_id].get("spell_id", "")) == "darkness":
				CombatAction.remove_condition_source(target, source_id, ["darkness_obscured"])
	for source_id_value in active_spell_zones.keys():
		var source_id := str(source_id_value)
		var zone: Dictionary = active_spell_zones[source_id]
		if str(zone.get("spell_id", "")) != "darkness":
			continue
		var zone_coords: Array = zone.get("coords", [])
		for target in targets:
			if _spell_zone_target_hex(target) in zone_coords:
				CombatAction.apply_condition(target, "darkness_obscured", 70000, source_id)


func _advance_cloudkill_zones_for_caster(caster: Character) -> void:
	if caster == null:
		return
	var caster_hex := Vector2i.ZERO
	for player_entity in player_entities:
		if player_entity.get("character") == caster:
			caster_hex = player_entity.get("hex_position", Vector2i.ZERO)
			break
	var current_turn := _current_spell_trigger_turn()
	for source_value in active_spell_zones.keys().duplicate():
		var source_id := str(source_value)
		var zone: Dictionary = active_spell_zones.get(source_id, {})
		if str(zone.get("spell_id", "")) != "cloudkill" or str(zone.get("caster_id", "")) != caster.character_id:
			continue
		if str(zone.get("last_move_turn", "")) == current_turn:
			continue
		var old_center: Vector2i = zone.get("center", Vector2i.ZERO)
		var destination := old_center
		var best_distance := HexUtils.get_distance(caster_hex, destination)
		for direction in HexUtils.DIRECTIONS:
			var candidate: Vector2i = old_center + direction * 2
			var candidate_distance := HexUtils.get_distance(caster_hex, candidate)
			if candidate_distance > best_distance:
				best_distance = candidate_distance
				destination = candidate
		var old_coords: Array = zone.get("coords", []).duplicate()
		var new_coords := Targeting.get_sphere_targets(destination, int(zone.get("radius_hexes", 4)), hex_grid)
		zone["center"] = destination
		zone["coords"] = new_coords
		zone["last_move_turn"] = current_turn
		hud.add_log("[color=olive]Cloudkill drifts 10 feet away from %s.[/color]" % caster.character_name)
		await _resolve_cloudkill_area_movement(zone, old_coords, new_coords)
	refresh_grid.call()


func _cloud_of_daggers_can_move(zone: Dictionary) -> bool:
	return str(zone.get("cast_turn", "")) != _current_spell_trigger_turn()


func _moonbeam_zone_source_for_caster(caster: Character) -> String:
	return source_for_caster(caster, "moonbeam")


func _moonbeam_can_move(zone: Dictionary) -> bool:
	return str(zone.get("cast_turn", "")) != _current_spell_trigger_turn()


func _release_moonbeam_shape_lock(target, source_id: String, zone: Dictionary) -> void:
	var lock_source := "%s:shape_lock" % source_id
	CombatAction.remove_condition_source(target, lock_source, ["moonbeam_shape_lock"])
	var locked_targets: Array = zone.get("shape_locked_targets", [])
	locked_targets.erase(target)
	zone["shape_locked_targets"] = locked_targets


func _resolve_moonbeam_area_movement(zone: Dictionary, old_coords: Array, new_coords: Array) -> void:
	var source_id := str(zone.get("source_id", ""))
	for target in zone.get("shape_locked_targets", []).duplicate():
		var target_hex: Vector2i = _position_for_spell_target(target)
		if target_hex in old_coords and target_hex not in new_coords:
			_release_moonbeam_shape_lock(target, source_id, zone)
	for coord in new_coords:
		if coord in old_coords:
			continue
		var target = _spell_target_at_hex(coord)
		if target != null:
			await SpellZoneTerrain._resolve_moonbeam_zone_save(self, target, zone)


func _position_for_spell_target(target) -> Vector2i:
	if target is Character:
		for entity in player_entities:
			if entity.get("character") == target:
				return entity.get("hex_position", Vector2i.ZERO)
	elif target is Dictionary:
		return target.get("hex_position", Vector2i.ZERO)
	return Vector2i.ZERO


func _remove_spell_zone(source_id: String) -> void:
	var zone: Dictionary = active_spell_zones.get(source_id, {})
	if str(zone.get("spell_id", "")) == "black_tentacles":
		for target in zone.get("restrained_targets", []):
			CombatAction.remove_condition_source(target, source_id, ["restrained"])
	if str(zone.get("spell_id", "")) == "conjure_elemental":
		for target in zone.get("restrained_targets", []):
			CombatAction.remove_condition_source(target, source_id, ["restrained"])
	if str(zone.get("spell_id", "")) == "conjure_fey":
		for target in zone.get("frightened_targets", []):
			CombatAction.remove_condition_source(target, source_id, ["frightened"])
	if str(zone.get("spell_id", "")) == "conjure_woodland_beings":
		var caster := _spell_zone_caster(zone)
		if caster != null:
			caster.feature_uses.erase("conjure_woodland_beings_disengage_source_id")
	active_spell_zones.erase(source_id)
	hex_grid.remove_difficult_terrain(source_id)
	hex_grid.remove_movement_cost_override(source_id)
	if str(zone.get("spell_id", "")) == "fog_cloud":
		_refresh_fog_cloud_conditions()
	if str(zone.get("spell_id", "")) == "darkness":
		_refresh_darkness_conditions()


func _tick_spell_zones() -> void:
	for source_id_value in active_spell_zones.keys().duplicate():
		var source_id := str(source_id_value)
		var zone: Dictionary = active_spell_zones[source_id]
		if int(zone.get("rounds_remaining", 0)) < 0:
			continue
		zone["rounds_remaining"] = int(zone.get("rounds_remaining", 0)) - 1
		if int(zone["rounds_remaining"]) <= 0:
			var spell_id := str(zone.get("spell_id", ""))
			var is_concentration_zone := bool(zone.get("concentration", spell_id in ["spike_growth", "entangle", "moonbeam", "sleet_storm", "wall_of_fire", "cloud_of_daggers", "cloudkill", "fog_cloud", "darkness", "conjure_animals", "conjure_celestial", "conjure_elemental", "conjure_fey", "conjure_minor_elementals", "conjure_woodland_beings", "spirit_guardians", "aura_of_life", "antilife_shell"]))
			if is_concentration_zone:
				var caster := _spell_zone_caster(zone)
				if caster != null and str(caster.concentrating_on.get("spell_id", "")) == spell_id:
					end_concentration.call(caster)
				else:
					_remove_spell_zone(source_id)
				hud.add_log("[color=gray]The %s area expires.[/color]" % str(zone.get("spell_id", "Spell zone")).capitalize())
			else:
				_remove_spell_zone(source_id)
				hud.add_log("[color=gray]The %s area expires.[/color]" % str(zone.get("spell_id", "Spell zone")).capitalize())
	refresh_grid.call()
	highlight_reachable.call()


func _resolve_cloud_of_daggers_area_movement(zone: Dictionary, old_coords: Array, new_coords: Array) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	for coord in new_coords:
		if coord in old_coords:
			continue
		var target = _spell_target_at_hex(coord)
		if target != null:
			results.append(await SpellZoneTerrain._resolve_cloud_of_daggers_damage(self, target, zone))
	return results


func _resolve_cloudkill_area_movement(zone: Dictionary, old_coords: Array, new_coords: Array) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	for coord in new_coords:
		if coord in old_coords:
			continue
		var target = _spell_target_at_hex(coord)
		if target != null:
			results.append(await SpellZoneTerrain._resolve_cloudkill_zone_save(self, target, zone))
	return results


func _spell_zone_caster(zone: Dictionary) -> Character:
	for player_entity in player_entities:
		var candidate: Character = player_entity.get("character")
		if candidate != null and candidate.character_id == str(zone.get("caster_id", "")):
			return candidate
	return null


func _antilife_shell_affects(target) -> bool:
	if target == null:
		return false
	var target_type := ""
	if target is Character:
		target_type = target.get_creature_type()
	else:
		target_type = str(target.get("creature_type", ""))
	return target_type not in ["construct", "undead"]


func _antilife_shell_blocks_crossing(target, from_hex: Vector2i, to_hex: Vector2i) -> bool:
	if from_hex == to_hex or not _antilife_shell_affects(target):
		return false
	for zone in active_spell_zones.values():
		if typeof(zone) != TYPE_DICTIONARY:
			continue
		if str(zone.get("spell_id", "")) != "antilife_shell":
			continue
		var caster := _spell_zone_caster(zone)
		if caster == null:
			continue
		if target is Character and caster == target:
			continue
		var center := _character_combat_hex(caster)
		var radius := int(zone.get("radius_hexes", 2))
		var was_inside := HexUtils.get_distance(from_hex, center) <= radius
		var is_inside := HexUtils.get_distance(to_hex, center) <= radius
		if was_inside != is_inside:
			return true
	return false


func _antilife_shell_blocks_melee(attacker, from_hex: Vector2i, target_hex: Vector2i, weapon_data: Dictionary) -> bool:
	if not _antilife_shell_affects(attacker):
		return false
	var properties: Array = weapon_data.get("properties", [])
	if int(weapon_data.get("range", 1)) > 1 or "reach" in properties:
		return false
	for zone in active_spell_zones.values():
		if typeof(zone) != TYPE_DICTIONARY or str(zone.get("spell_id", "")) != "antilife_shell":
			continue
		var caster := _spell_zone_caster(zone)
		if caster == null:
			continue
		var center := _character_combat_hex(caster)
		var radius := int(zone.get("radius_hexes", 2))
		if (HexUtils.get_distance(from_hex, center) <= radius) != (HexUtils.get_distance(target_hex, center) <= radius):
			return true
	return false


func _resolve_spell_zone_entries(target, from_hex: Vector2i, to_hex: Vector2i) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	if from_hex == to_hex:
		return results
	var heat := await _resolve_room_surface_heat(target, to_hex)
	if not heat.is_empty(): results.append(heat)
	var room_areas := LocalRoomCombat.enter_room_areas(target, from_hex, to_hex)
	var room_alert := LocalRoomRules._alarm_alert_text(room_areas)
	if not room_alert.is_empty():
		hud.add_log("[color=yellow]%s[/color]" % room_alert.strip_edges())
	for source_value in active_spell_zones.keys().duplicate():
		var source_id := str(source_value)
		var zone: Dictionary = active_spell_zones[source_id]
		if str(zone.get("spell_id", "")) == "antilife_shell":
			var shell_caster := _spell_zone_caster(zone)
			if target is Character and target == shell_caster:
				var old_center: Vector2i = zone.get("center", from_hex)
				var shell_radius := int(zone.get("radius_hexes", 2))
				var forced_through := false
				for player_entity in player_entities:
					var affected: Character = player_entity.get("character")
					if affected == null or affected == shell_caster or not affected.is_alive or not _antilife_shell_affects(affected):
						continue
					var affected_hex: Vector2i = player_entity.get("hex_position", Vector2i.ZERO)
					if (HexUtils.get_distance(affected_hex, old_center) <= shell_radius) != (HexUtils.get_distance(affected_hex, to_hex) <= shell_radius):
						forced_through = true
						break
				if not forced_through:
					for affected in monster_entities:
						if not bool(affected.get("is_alive", false)) or not _antilife_shell_affects(affected):
							continue
						var affected_hex: Vector2i = affected.get("hex_position", Vector2i.ZERO)
						if (HexUtils.get_distance(affected_hex, old_center) <= shell_radius) != (HexUtils.get_distance(affected_hex, to_hex) <= shell_radius):
							forced_through = true
							break
				if forced_through:
					end_concentration.call(shell_caster)
				else:
					zone["center"] = to_hex
		elif str(zone.get("spell_id", "")) == "moonbeam":
			if to_hex in zone.get("coords", []) and from_hex not in zone.get("coords", []):
				results.append(await SpellZoneTerrain._resolve_moonbeam_zone_save(self, target, zone))
			elif from_hex in zone.get("coords", []) and to_hex not in zone.get("coords", []):
				_release_moonbeam_shape_lock(target, source_id, zone)
		elif str(zone.get("spell_id", "")) == "grease" and to_hex in zone.get("coords", []) and from_hex not in zone.get("coords", []):
			results.append(await SpellZoneTerrain._resolve_spell_zone_save(self, target, zone))
		elif str(zone.get("spell_id", "")) == "black_tentacles" and to_hex in zone.get("coords", []) and from_hex not in zone.get("coords", []):
			results.append(await SpellZoneTerrain._resolve_black_tentacles_zone_save(self, target, zone))
		elif str(zone.get("spell_id", "")) == "sleet_storm" and to_hex in zone.get("coords", []) and from_hex not in zone.get("coords", []):
			results.append(await SpellZoneTerrain._resolve_sleet_storm_zone_save(self, target, zone))
		elif str(zone.get("spell_id", "")) == "wall_of_fire" and to_hex in zone.get("coords", []) and from_hex not in zone.get("coords", []):
			results.append(await SpellZoneTerrain._resolve_wall_of_fire_damage(self, target, zone))
		elif str(zone.get("spell_id", "")) == "cloud_of_daggers" and to_hex in zone.get("coords", []) and from_hex not in zone.get("coords", []):
			results.append(await SpellZoneTerrain._resolve_cloud_of_daggers_damage(self, target, zone))
		elif str(zone.get("spell_id", "")) == "cloudkill" and to_hex in zone.get("coords", []) and from_hex not in zone.get("coords", []):
			results.append(await SpellZoneTerrain._resolve_cloudkill_zone_save(self, target, zone))
		elif str(zone.get("spell_id", "")) == "conjure_animals" and to_hex in zone.get("coords", []) and from_hex not in zone.get("coords", []):
			results.append(await SpellZoneConjurations._resolve_conjure_animals_zone_save(self, target, zone))
		elif str(zone.get("spell_id", "")) == "conjure_woodland_beings":
			var caster := _spell_zone_caster(zone)
			var radius := int(zone.get("radius_hexes", 2))
			if target is Character and caster == target:
				zone["center"] = to_hex
				results.append_array(await _resolve_conjure_woodland_beings_area_movement(zone, from_hex, to_hex))
			elif caster != null and HexUtils.get_distance(from_hex, _character_combat_hex(caster)) > radius and HexUtils.get_distance(to_hex, _character_combat_hex(caster)) <= radius:
				results.append(await SpellZoneConjurations._resolve_conjure_woodland_beings_zone_save(self, target, zone))
		elif str(zone.get("spell_id", "")) == "spirit_guardians":
			var caster := _spell_zone_caster(zone)
			var radius := int(zone.get("radius_hexes", 3))
			if target is Character and caster == target:
				zone["center"] = to_hex
				results.append_array(await _resolve_spirit_guardians_area_movement(zone, from_hex, to_hex))
			elif caster != null and HexUtils.get_distance(from_hex, _character_combat_hex(caster)) > radius and HexUtils.get_distance(to_hex, _character_combat_hex(caster)) <= radius:
				results.append(await SpellZoneConjurations._resolve_spirit_guardians_zone_save(self, target, zone))
		elif str(zone.get("spell_id", "")) == "conjure_celestial" and to_hex in zone.get("coords", []) and from_hex not in zone.get("coords", []):
			results.append(await SpellZoneConjurations._resolve_conjure_celestial_zone_trigger(self, target, zone))
		elif str(zone.get("spell_id", "")) == "conjure_elemental" and to_hex in zone.get("coords", []) and from_hex not in zone.get("coords", []):
			results.append(await SpellZoneConjurations._resolve_conjure_elemental_save(self, target, zone))
	if target is Character and _conjure_animals_zone_source_for_caster(target) != "":
		_refresh_conjure_animals_strength_advantage(target)
	return results


func _resolve_spell_zone_movement(target, to_hex: Vector2i) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	for zone in active_spell_zones.values():
		if str(zone.get("spell_id", "")) != "spike_growth" or to_hex not in zone.get("coords", []):
			continue
		var caster := _spell_zone_caster(zone)
		if caster == null:
			continue
		var damage_details := Dice.parse_dice_details(str(zone.get("damage_formula", "2d4")), {}, caster)
		var amount := int(damage_details.get("final_total", 0))
		var damage_result := CombatAction.resolve_damage(target, amount, "piercing", {}, false, false, caster)
		var damage_taken := int(damage_result.get("resolved", 0))
		var target_name: String = target.character_name if target is Character else str(target.get("name", "The creature"))
		hud.add_log("[color=red]%s takes %d Piercing damage from Spike Growth (%s).[/color]" % [target_name, int(damage_result.get("damage", 0)), str(zone.get("damage_formula", "2d4"))])
		if target is Character and damage_taken > 0:
			await check_concentration.call(target, damage_taken)
		elif target is Dictionary and int(target.get("current_hp", 0)) <= 0 and bool(target.get("is_alive", true)):
			target["is_alive"] = false
			tracker.remove_combatant(str(target.get("id", "")))
			enemy_defeated.call(target, caster)
		results.append({"spell_id": "spike_growth", "damage": int(damage_result.get("damage", 0)), "hex": to_hex})
		if target is Character and not target.is_alive:
			end_concentration.call(target)
	return results


func _resolve_spell_zone_path(target, path: Array) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	for index in range(1, path.size()):
		results.append_array(await _resolve_spell_zone_entries(target, path[index - 1], path[index]))
		results.append_array(await _resolve_spell_zone_movement(target, path[index]))
	return results


func _resolve_spell_zone_end_turn(target, coord: Vector2i) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var heat := await _resolve_room_surface_heat(target, coord)
	if not heat.is_empty(): results.append(heat)
	for zone in active_spell_zones.values():
		if str(zone.get("spell_id", "")) == "moonbeam" and coord in zone.get("coords", []):
			results.append(await SpellZoneTerrain._resolve_moonbeam_zone_save(self, target, zone))
		elif str(zone.get("spell_id", "")) == "grease" and coord in zone.get("coords", []):
			results.append(await SpellZoneTerrain._resolve_spell_zone_save(self, target, zone))
		elif str(zone.get("spell_id", "")) == "black_tentacles" and coord in zone.get("coords", []):
			results.append(await SpellZoneTerrain._resolve_black_tentacles_zone_save(self, target, zone))
		elif str(zone.get("spell_id", "")) == "wall_of_fire" and coord in zone.get("dangerous_coords", zone.get("coords", [])):
			results.append(await SpellZoneTerrain._resolve_wall_of_fire_damage(self, target, zone, false))
		elif str(zone.get("spell_id", "")) == "cloud_of_daggers" and coord in zone.get("coords", []):
			results.append(await SpellZoneTerrain._resolve_cloud_of_daggers_damage(self, target, zone))
		elif str(zone.get("spell_id", "")) == "cloudkill" and coord in zone.get("coords", []):
			results.append(await SpellZoneTerrain._resolve_cloudkill_zone_save(self, target, zone))
		elif str(zone.get("spell_id", "")) == "conjure_animals" and coord in zone.get("coords", []):
			results.append(await SpellZoneConjurations._resolve_conjure_animals_zone_save(self, target, zone))
		elif str(zone.get("spell_id", "")) == "conjure_woodland_beings":
			var caster := _spell_zone_caster(zone)
			if caster != null and HexUtils.get_distance(coord, _character_combat_hex(caster)) <= int(zone.get("radius_hexes", 2)):
				results.append(await SpellZoneConjurations._resolve_conjure_woodland_beings_zone_save(self, target, zone))
		elif str(zone.get("spell_id", "")) == "spirit_guardians":
			var caster := _spell_zone_caster(zone)
			if caster != null and HexUtils.get_distance(coord, _character_combat_hex(caster)) <= int(zone.get("radius_hexes", 3)):
				results.append(await SpellZoneConjurations._resolve_spirit_guardians_zone_save(self, target, zone))
		elif str(zone.get("spell_id", "")) == "conjure_celestial" and coord in zone.get("coords", []):
			results.append(await SpellZoneConjurations._resolve_conjure_celestial_zone_trigger(self, target, zone))
	return results


func _resolve_room_surface_heat(target, position: Vector2i) -> Dictionary:
	var state := LocalRoomCombat.room()
	if state.is_empty(): return {}
	var altitude := LocalRoomRules.elevation_feet(state, position)
	if target is Character:
		for entity in player_entities:
			if entity.get("character") == target and (target.movement_speed_feet("fly") > 0 or SpellEffects.has_spell(target, "levitate")):
				altitude = int(entity.get("altitude_feet", altitude))
	elif target is Dictionary:
		altitude = int(target.get("altitude_feet", altitude))
	var outcome := LocalRoomRules.resolve_surface_heat(state, target, position, altitude)
	if outcome.is_empty(): return {}
	var damage := int(outcome.get("damage", 0))
	var target_name: String = target.character_name if target is Character else str(target.get("name", "The creature"))
	hud.add_log("%s takes %d Fire damage from the hot surface (%s)." % [target_name, damage, outcome.get("damage_formula", "")])
	if target is Character:
		if damage > 0: await check_concentration.call(target, damage)
		if not target.is_alive: end_concentration.call(target)
	elif int(target.get("current_hp", 0)) <= 0 and bool(target.get("is_alive", true)):
		target["is_alive"] = false
		tracker.remove_combatant(str(target.get("id", "")))
		enemy_defeated.call(target, null)
	return outcome


func _resolve_spell_zone_start_turn(target, coord: Vector2i) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	for source_id_value in active_spell_zones.keys().duplicate():
		var zone: Dictionary = active_spell_zones.get(str(source_id_value), {})
		if str(zone.get("spell_id", "")) == "sleet_storm" and coord in zone.get("coords", []):
			results.append(await SpellZoneTerrain._resolve_sleet_storm_zone_save(self, target, zone))
		elif str(zone.get("spell_id", "")) == "conjure_elemental":
			var source_id := str(zone.get("source_id", source_id_value))
			if _has_spell_condition_source(target, source_id):
				results.append(await SpellZoneConjurations._resolve_conjure_elemental_save(self, target, zone, true))
			elif not SpellZoneConjurations._conjure_elemental_has_restrained_target(self, zone) and HexUtils.get_distance(coord, zone.get("center", Vector2i.ZERO)) <= 2:
				results.append(await SpellZoneConjurations._resolve_conjure_elemental_save(self, target, zone))
		elif str(zone.get("spell_id", "")) == "aura_of_life" and target is Character and target.current_hp <= 0:
			var caster := _spell_zone_caster(zone)
			var target_id := _spell_zone_target_id(target)
			var last_revive_turn_by_target: Dictionary = zone.get("last_revive_turn_by_target", {})
			var current_turn := _current_spell_trigger_turn()
			if caster != null and caster != target and _aura_of_life_allows_hp_maximum(target) and str(last_revive_turn_by_target.get(target_id, "")) != current_turn and HexUtils.get_distance(coord, _character_combat_hex(caster)) <= int(zone.get("radius_hexes", 6)):
				last_revive_turn_by_target[target_id] = current_turn
				zone["last_revive_turn_by_target"] = last_revive_turn_by_target
				var restored: int = target.heal(1)
				if restored > 0:
					hud.add_log("[color=green]Aura of Life restores 1 Hit Point to %s at the start of their turn.[/color]" % target.character_name)
					results.append({"spell_id": "aura_of_life", "healing": restored, "target_id": target_id})
	return results


func _has_creature_at(coord: Vector2i) -> bool:
	for player in player_entities:
		var character: Character = player.get("character")
		if player.get("hex_position", Vector2i.ZERO) == coord and character != null and character.is_alive:
			return true
	for monster in monster_entities:
		if monster.get("hex_position", Vector2i.ZERO) == coord and monster.get("is_alive", false):
			return true
	return false


func _is_occupied_hex(active_character: Character, coord: Vector2i) -> bool:
	var active_steed_owner: Character = null
	for player in player_entities:
		if player.get("character") == active_character and player.get("is_steed", false):
			active_steed_owner = player.get("steed_owner")
			break
	for player in player_entities:
		var candidate: Character = player.get("character")
		var is_mounted_pair := false
		if player.get("is_steed", false) and player.get("steed_owner") == active_character:
			is_mounted_pair = PaladinRules.find_steed_is_mounted(active_character)
		elif active_steed_owner != null and candidate == active_steed_owner:
			is_mounted_pair = PaladinRules.find_steed_is_mounted(active_steed_owner)
		if not is_mounted_pair and candidate != active_character and player.get("hex_position", Vector2i.ZERO) == coord and candidate != null and candidate.is_alive:
			return true
	for monster in monster_entities:
		if monster.get("hex_position", Vector2i.ZERO) == coord and monster.get("is_alive", false):
			return true
	for zone in active_spell_zones.values():
		if str(zone.get("spell_id", "")) == "conjure_fey" and zone.get("center", Vector2i.ZERO) == coord:
			return true
	return false


func _is_unoccupied_conjure_elemental_space(center: Vector2i) -> bool:
	if not hex_grid.has_tile(center):
		return false
	var spirit_space := Targeting.get_sphere_targets(center, 1, hex_grid)
	if spirit_space.size() < 7:
		return false
	for coord in spirit_space:
		for player in player_entities:
			var character: Character = player.get("character")
			if character != null and character.is_alive and player.get("hex_position", Vector2i.ZERO) == coord:
				return false
		for monster in monster_entities:
			if monster.get("is_alive", false) and monster.get("hex_position", Vector2i.ZERO) == coord:
				return false
		for zone in active_spell_zones.values():
			if str(zone.get("spell_id", "")) == "conjure_elemental" and coord in zone.get("coords", []):
				return false
	return true


func _spell_effect_targets() -> Array:
	var targets: Array = []
	for player in player_entities:
		if player.get("character") != null:
			targets.append(player["character"])
	targets.append_array(monster_entities)
	return targets


func end_area_concentration(caster: Character) -> void:
	var spell_id := str(caster.concentrating_on.get("spell_id", ""))
	# Keep the existing ownership policies. Older areas use caster ownership;
	# newer ones capture a source ID, with a fallback only for these spells.
	var all_caster_areas := spell_id in ["spike_growth", "moonbeam", "entangle"]
	var exact_source := spell_id in ["cloud_of_daggers", "cloudkill", "fog_cloud", "darkness", "wall_of_fire", "conjure_animals", "conjure_celestial", "antilife_shell"]
	var source_with_fallback := spell_id in ["black_tentacles", "sleet_storm", "conjure_elemental", "conjure_fey", "conjure_woodland_beings", "spirit_guardians", "aura_of_life", "conjure_minor_elementals"]
	if not (all_caster_areas or exact_source or source_with_fallback):
		LocalRoomCombat.remove_concentration(caster, spell_id, str(caster.concentrating_on.get("%s_source_id" % spell_id, "")))
		return
	var concentration_source := str(caster.concentrating_on.get("%s_source_id" % spell_id, ""))
	LocalRoomCombat.remove_concentration(caster, spell_id, concentration_source)
	for source_value in active_spell_zones.keys().duplicate():
		var source_id := str(source_value)
		var zone: Dictionary = active_spell_zones.get(source_id, {})
		if str(zone.get("spell_id", "")) != spell_id or str(zone.get("caster_id", "")) != caster.character_id:
			continue
		var owned := all_caster_areas or source_id == concentration_source
		if source_with_fallback and concentration_source.is_empty() and bool(zone.get("concentration", false)):
			owned = true
		if not owned:
			continue
		if spell_id == "moonbeam":
			for target in zone.get("shape_locked_targets", []):
				CombatAction.remove_condition_source(target, "%s:shape_lock" % source_id, ["moonbeam_shape_lock"])
		if spell_id == "entangle":
			for target in zone.get("restrained_targets", []):
				CombatAction.remove_condition_source(target, source_id, ["restrained"])
		_remove_spell_zone(source_id)
	if spell_id == "conjure_animals":
		caster.feature_uses.erase("conjure_animals_strength_advantage")
		caster.feature_uses.erase("conjure_animals_moved_this_turn")
		caster.feature_uses.erase("conjure_animals_pack_moved_this_turn")
	if spell_id == "conjure_celestial":
		caster.feature_uses.erase("conjure_celestial_moved_this_turn")
		caster.feature_uses.erase("conjure_celestial_pillar_moved_this_turn")


func source_for_caster(caster: Character, spell_id: String) -> String:
	if caster == null:
		return ""
	for source_value in active_spell_zones:
		var zone: Dictionary = active_spell_zones[source_value]
		if str(zone.get("spell_id", "")) == spell_id and str(zone.get("caster_id", "")) == caster.character_id:
			return str(source_value)
	return ""


func _enemy_movement_cost(coord: Vector2i, mover_id: String = "") -> float:
	var cost := hex_grid.get_hex_cost(coord)
	if not hex_grid.is_difficult_terrain(coord):
		for source_id_value in active_spell_zones:
			var zone: Dictionary = active_spell_zones[source_id_value]
			if str(zone.get("spell_id", "")) != "conjure_minor_elementals" or not bool(zone.get("enemy_difficult_terrain", false)):
				continue
			var caster := _spell_zone_caster(zone)
			if caster != null and HexUtils.get_distance(coord, _character_combat_hex(caster)) <= int(zone.get("radius_hexes", 3)):
				cost += 1.0
	for zone in active_spell_zones.values():
		if str(zone.get("spell_id", "")) != "spirit_guardians" or not SpellZoneConjurations._spirit_guardians_zone_affects_target(self, zone, mover_id):
			continue
		var caster := _spell_zone_caster(zone)
		if caster != null and HexUtils.get_distance(coord, _character_combat_hex(caster)) <= int(zone.get("radius_hexes", 3)):
			cost *= 2.0
			break
	return cost
