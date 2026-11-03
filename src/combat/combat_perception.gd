## Shared combat visibility checks for authored darkness and creature senses.
class_name CombatPerception
extends RefCounted

const DARKVISION_FALLBACK_FEET := 60


static func configure_ambient_light(grid: HexGrid, illumination: String) -> void:
	if grid == null:
		return
	var normalized := illumination.to_lower()
	if normalized not in ["bright", "dim", "dark"]:
		normalized = "bright"
	for tile in grid.tiles.values():
		tile.custom_properties["ambient_illumination"] = normalized
	grid.queue_redraw()


static func illumination_level_at(grid: HexGrid, position: Vector2i) -> String:
	var ambient := "bright"
	if grid != null and grid.has_tile(position):
		ambient = str(grid.get_tile(position).custom_properties.get("ambient_illumination", "bright"))
	var level := ambient
	if level == "bright":
		return level
	for source in grid.entities if grid != null else []:
		var distance := HexUtils.get_distance(source.get("hex_position", Vector2i.ZERO), position)
		var bright_radius := int(source.get("bright_light_radius_hexes", 0))
		var dim_radius := int(source.get("dim_light_radius_hexes", 0))
		if not Targeting.has_line_of_sight(source.get("hex_position", Vector2i.ZERO), position, grid):
			continue
		if bright_radius > 0 and distance <= bright_radius:
			return "bright"
		if dim_radius > 0 and distance <= dim_radius:
			level = "dim"
	return level


static func can_see_target(observer, target, observer_position: Vector2i, target_position: Vector2i, grid: HexGrid) -> bool:
	if observer == null or grid == null:
		return false
	if observer is Character and observer.familiar_senses != null:
		var familiar: Character = observer.familiar_senses
		var bond: Dictionary = FamiliarRules.state(observer)
		if familiar.is_alive and not CombatAction.is_incapacitated(familiar) and not bond.is_empty() and not bool(bond.get("pocket", false)) and familiar.character_id == str(bond.get("creature_id", "")) and HexUtils.get_distance(observer_position, observer.familiar_senses_position) <= 20:
			return can_see_target(familiar, target, observer.familiar_senses_position, target_position, grid)
		observer.familiar_senses = null
	return _can_see(observer, target, observer_position, target_position, grid)


static func sight_is_lightly_obscured(observer, position: Vector2i, grid: HexGrid, distance_feet: int) -> bool:
	if observer is Character and observer.familiar_senses != null:
		return sight_is_lightly_obscured(observer.familiar_senses, position, grid, HexUtils.get_distance(observer.familiar_senses_position, position) * 5)
	if _has_blindsight(observer, distance_feet) or _has_truesight(observer, distance_feet) or _sees_magical_darkness(observer, distance_feet, "", {}): return false
	var light := illumination_level_at(grid, position)
	if light == "dark": return true
	var darkvision := _darkvision_range_feet(observer)
	return light == "dim" and (darkvision <= 0 or darkvision < distance_feet)


## Re-Hide must not use its own Invisible benefit to pass the location gate.
static func can_see_before_hide(observer, target, origin: Vector2i, destination: Vector2i, grid: HexGrid) -> bool:
	return _can_see(observer, target, origin, destination, grid, -1, true)


static func _can_see(observer, target, origin: Vector2i, destination: Vector2i, grid: HexGrid, distance_override: int = -1, ignore_hidden: bool = false) -> bool:
	if observer == null:
		return false
	if grid != null and not Targeting.has_line_of_sight(origin, destination, grid):
		return false
	var feet := distance_override if distance_override >= 0 else HexUtils.get_distance(origin, destination) * 5
	# Blindsight is sight without eyes; Truesight and See Invisibility still need eyes.
	if _has_blindsight(observer, feet):
		return true
	if _has_condition(observer, "blinded"):
		return false
	if _has_condition(observer, "fog_cloud_obscured") or _has_condition(target, "fog_cloud_obscured"):
		return false
	var darkness_sources := {}
	if grid != null:
		var ray := Targeting.line_cells(origin, destination)
		for source in grid.obscurement_sources:
			var area: Dictionary = grid.obscurement_sources[source]
			if not ray.any(func(coord): return coord in area.get("coords", [])):
				continue
			if area.get("kind", "") == "fog":
				return false
			if area.get("kind", "") == "magical_darkness":
				darkness_sources[source] = area
	# Endpoint conditions remain supported for native/direct consumers.
	for entity in [observer, target]:
		if not _is_magically_obscured(entity): continue
		var sources: Dictionary = entity.condition_sources if entity is Character else entity.get("condition_sources", {})
		var grants: Dictionary = sources.get("darkness_obscured", {})
		if grants.is_empty(): darkness_sources["ordinary"] = {}
		for source in grants:
			if not darkness_sources.has(source): darkness_sources[source] = {}
	for source in darkness_sources:
		if not _has_truesight(observer, feet) and not _sees_magical_darkness(observer, feet, str(source), darkness_sources[source]):
			return false
	var sees_invisible := CombatAction.can_perceive_invisible(observer, feet)
	if target != null and CombatAction.is_invisible(target, not ignore_hidden) and not sees_invisible:
		return false
	return _target_is_illuminated(observer, destination, grid, feet)


## Location disclosure is encounter-local and belongs only to this observer.
## The receipt expires on movement or a new Hide, without removing Hidden.
static func reveal_location(observer, target, position: Vector2i, grid: HexGrid) -> void:
	var owner := CombatAction.actor_id(observer)
	var subject := CombatAction.actor_id(target)
	if grid == null or owner.is_empty() or subject.is_empty(): return
	if not grid.observer_locations.has(owner): grid.observer_locations[owner] = {}
	grid.observer_locations[owner][subject] = {"position": position, "revision": _concealment_revision(target)}


static func can_locate_target(observer, target, origin: Vector2i, destination: Vector2i, grid: HexGrid) -> bool:
	if observer == null or target == null or grid == null: return false
	if can_see_target(observer, target, origin, destination, grid) or has_required_sense(observer, target, origin, destination, grid, "tremorsense"):
		reveal_location(observer, target, destination, grid)
		return true
	if not _has_condition(target, "hidden"):
		# Encounter occupants have known locations until they Hide. Invisible is
		# not Hidden; hearing/guess-square controls are a separate host.
		return true
	var known: Dictionary = grid.observer_locations.get(CombatAction.actor_id(observer), {}).get(CombatAction.actor_id(target), {})
	return known.get("position") == destination and known.get("revision", -1) == _concealment_revision(target)


static func invalidate_hidden_location(target) -> void:
	if not _has_condition(target, "hidden"): return
	if target is Character: target.concealment_revision += 1
	elif target is Dictionary: target["concealment_revision"] = int(target.get("concealment_revision", 0)) + 1


static func _concealment_revision(target) -> int:
	return int(target.concealment_revision) if target is Character else int(target.get("concealment_revision", 0))


## Attach live combat positions for weapon callers, including off-turn attacks.
static func weapon_decisions(grid: HexGrid, observer, target, decisions: Dictionary = {}, origin: Variant = null, destination: Variant = null) -> Dictionary:
	var result := decisions.duplicate()
	var actual: Variant = observer.feature_uses.get("monster_source", observer) if observer is Character else observer
	if origin == null: origin = _position(actual, grid)
	if destination == null: destination = _position(target, grid)
	if grid != null and origin is Vector2i and destination is Vector2i:
		result["weapon_visibility"] = {"grid":grid, "caster_position":origin, "target_position":destination, "observer":actual, "effect_plane":PhysicalFactsRules.get_plane(actual, {"plane":grid.cover_plane})}
	return result


static func _position(entity, grid: HexGrid) -> Variant:
	if entity is Dictionary: return entity.get("hex_position")
	if grid != null:
		for participant in grid.perception_participants:
			if participant.get("character") == entity: return participant.get("hex_position")
	return null


## Both directions use the same actual combatants, never a caster projection.
## Non-spatial native callers retain bounded endpoint-condition/sense behavior.
static func attack_visibility(attacker, target, distance_feet: int, context: Dictionary = {}) -> Dictionary:
	var spatial: Dictionary = context.get("spell_visibility", context.get("weapon_visibility", {}))
	var grid: HexGrid = spatial.get("grid")
	var origin: Vector2i = spatial.get("caster_position", Vector2i.ZERO)
	var destination: Vector2i = spatial.get("target_position", Vector2i.ZERO)
	var actual_attacker: Variant = spatial.get("observer", attacker)
	var sees_target := can_see_target(actual_attacker, target, origin, destination, grid) if grid != null else _can_see(actual_attacker, target, origin, destination, null, maxi(0, distance_feet))
	var sees_attacker := can_see_target(target, actual_attacker, destination, origin, grid) if grid != null else _can_see(target, actual_attacker, destination, origin, null, maxi(0, distance_feet))
	return {"advantage": not sees_attacker and not (target is Dictionary and target.get("is_object", false)), "disadvantage": not sees_target, "attacker_sees_target": sees_target, "target_sees_attacker": sees_attacker}


## Checks only senses with an existing production owner. Unknown sense names are
## unavailable instead of silently falling back to sight or a caller assertion.
static func has_required_sense(observer, target, observer_position: Vector2i, target_position: Vector2i, grid: HexGrid, sense: String) -> bool:
	var distance_feet := HexUtils.get_distance(observer_position, target_position) * 5
	match sense:
		"see":
			return can_see_target(observer, target, observer_position, target_position, grid)
		"darkvision":
			return _darkvision_range_feet(observer) >= distance_feet and _darkvision_range_feet(observer) > 0 and not _has_condition(observer, "blinded") and can_see_target(observer, target, observer_position, target_position, grid)
		"truesight":
			return not _has_condition(observer, "blinded") and _has_truesight(observer, distance_feet) and can_see_target(observer, target, observer_position, target_position, grid)
		"blindsight":
			return _sense_range(observer, sense) >= distance_feet and _sense_range(observer, sense) > 0 and can_see_target(observer, target, observer_position, target_position, grid)
		"tremorsense":
			return grid != null and target != null and _sense_range(observer, sense) > 0 and distance_feet <= _sense_range(observer, sense) and _contact_surface(observer, observer_position, grid) != "" and _contact_surface(observer, observer_position, grid) == _contact_surface(target, target_position, grid)
		_:
			return false


static func _target_is_illuminated(observer, target: Vector2i, grid: HexGrid, distance_feet: int) -> bool:
	if illumination_level_at(grid, target) != "dark" or _has_truesight(observer, distance_feet) or _has_blindsight(observer, distance_feet) or _sees_magical_darkness(observer, distance_feet, "", {}):
		return true
	var darkvision_range := _darkvision_range_feet(observer)
	return darkvision_range > 0 and distance_feet <= darkvision_range


static func _darkvision_range_feet(entity) -> int:
	if entity == null:
		return 0
	var declared := _sense_range(entity, "darkvision")
	if SpellEffects.has_spell(entity, "darkvision"):
		return maxi(150, declared)
	if entity is Character:
		var creature_range := int(entity.feature_uses.get("creature_darkvision_range_feet", 0))
		if creature_range > 0:
			return maxi(creature_range, declared)
		if entity.darkvision_feet > 0:
			return maxi(entity.darkvision_feet, declared)
		var race := DataLoader.get_race(entity.race_id)
		if int(race.get("darkvision_feet", 0)) > 0:
			return maxi(int(race.get("darkvision_feet", 0)), declared)
		if bool(race.get("darkvision", false)):
			for trait_value in race.get("traits", []):
				var trait_data: Dictionary = trait_value
				if str(trait_data.get("name", "")).to_lower() != "darkvision":
					continue
				var expression := RegEx.new()
				if expression.compile("range of ([0-9]+) feet") == OK:
					var result := expression.search(str(trait_data.get("description", "")).to_lower())
					if result != null:
						return maxi(int(result.get_string(1)), declared)
				return maxi(DARKVISION_FALLBACK_FEET, declared)
		return declared
	var senses: Dictionary = entity.get("senses", {})	
	return maxi(0, maxi(int(entity.get("darkvision_range_feet", 0)), int(senses.get("darkvision", 0))))


static func _has_truesight(entity, distance_feet: int) -> bool:
	return distance_feet >= 0 and _sense_range(entity, "truesight") > 0 and distance_feet <= _sense_range(entity, "truesight")


static func _has_blindsight(entity, distance_feet: int) -> bool:
	return distance_feet >= 0 and _sense_range(entity, "blindsight") > 0 and distance_feet <= _sense_range(entity, "blindsight")


static func sense_effect_error(effect: Dictionary) -> String:
	var feet: Variant = effect.get("range_feet")
	if not ResourcePoolRules._integer(feet, 1, 5280): return "Sense range_feet must be a positive integer up to 5280"
	var kind := str(effect.get("type", ""))
	for key in effect:
		if key in ["type", "range_feet"]: continue
		if kind != "darkvision" or key not in ["magical", "obscurement_source_id", "own_source_only"]: return "Unsupported sense field"
		if key in ["magical", "own_source_only"] and not effect[key] is bool: return "Sense exception flags must be boolean"
		if key == "obscurement_source_id" and (not effect[key] is String or str(effect[key]).is_empty()): return "Sense exception requires an exact nonempty source id"
	if (effect.has("obscurement_source_id") or effect.has("own_source_only")) and not bool(effect.get("magical", false)): return "Source-specific exceptions require magical Darkvision"
	return ""


static func _sense_range(entity, sense: String) -> int:
	if entity == null: return 0
	var feet := 120 if sense == "truesight" and SpellEffects.has_spell(entity, "true_seeing") else 0
	if entity is Character:
		feet = maxi(feet, int(entity.feature_uses.get("creature_" + sense + "_range_feet", 0)))
		feet = maxi(feet, int(entity.feature_uses.get("monster_" + sense + "_range_feet", 0)))
		for effect in ClassProgression.selected_feature_effects_of_type(entity, sense):
			feet = maxi(feet, int(effect.get("range_feet", 0)))
	else:
		feet = maxi(feet, maxi(int(entity.get(sense + "_range_feet", 0)), int(entity.get("senses", {}).get(sense, 0))))
	return feet


static func _sees_magical_darkness(entity, feet: int, source: String, area: Dictionary) -> bool:
	if not entity is Character: return false
	for effect in ClassProgression.selected_feature_effects_of_type(entity, "darkvision"):
		if not bool(effect.get("magical", false)) or feet > int(effect.get("range_feet", 0)): continue
		if effect.has("obscurement_source_id") and str(effect.obscurement_source_id) != source: continue
		if bool(effect.get("own_source_only", false)) and area.get("caster_id", "") != CombatAction.actor_id(entity): continue
		return true
	return false


static func _contact_surface(entity, position: Vector2i, grid: HexGrid) -> String:
	if not grid.has_tile(position): return ""
	var altitude := int(entity.get("altitude_feet", 0)) if entity is Dictionary else 0
	if entity is Character:
		for participant in grid.perception_participants:
			if participant.get("character") == entity:
				altitude = int(participant.get("altitude_feet", 0))
				break
	var floor_feet := int(grid.get_tile(position).custom_properties.get("elevation_feet", 0))
	if altitude > floor_feet: return ""
	return str(grid.get_tile(position).custom_properties.get("contact_surface_id", "ground"))


static func _is_magically_obscured(entity) -> bool:
	if entity is Character:
		return entity.has_condition("darkness_obscured")
	return entity is Dictionary and (entity.get("conditions", {}) as Dictionary).has("darkness_obscured")


static func _has_condition(entity, condition: String) -> bool:
	if entity is Character:
		return entity.has_condition(condition)
	return entity is Dictionary and (entity.get("conditions", {}) as Dictionary).has(condition)


