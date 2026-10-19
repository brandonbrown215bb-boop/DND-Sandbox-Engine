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
	if not Targeting.has_line_of_sight(observer_position, target_position, grid):
		return false
	var distance_feet := HexUtils.get_distance(observer_position, target_position) * 5
	if _has_condition(observer, "blinded") and not _has_blindsight(observer, distance_feet):
		return false
	if _is_magically_obscured(observer) or _is_magically_obscured(target):
		return _has_truesight(observer, distance_feet) or _has_blindsight(observer, distance_feet)
	if target != null and CombatAction.is_invisible(target) and not CombatAction.can_perceive_invisible(observer, distance_feet):
		return false
	return _target_is_illuminated(observer, target_position, grid, distance_feet)


## Checks only senses with an existing production owner. Unknown sense names are
## unavailable instead of silently falling back to sight or a caller assertion.
static func has_required_sense(observer, target, observer_position: Vector2i, target_position: Vector2i, grid: HexGrid, sense: String) -> bool:
	var distance_feet := HexUtils.get_distance(observer_position, target_position) * 5
	match sense:
		"see":
			return can_see_target(observer, target, observer_position, target_position, grid)
		"darkvision":
			return _darkvision_range_feet(observer) >= distance_feet and _darkvision_range_feet(observer) > 0 and not _has_condition(observer, "blinded") and can_see_target(observer, target, observer_position, target_position, grid)
		_:
			return false


static func _target_is_illuminated(observer, target: Vector2i, grid: HexGrid, distance_feet: int) -> bool:
	if illumination_level_at(grid, target) != "dark" or _has_truesight(observer, distance_feet) or _has_blindsight(observer, distance_feet):
		return true
	var darkvision_range := _darkvision_range_feet(observer)
	return darkvision_range > 0 and distance_feet <= darkvision_range


static func _darkvision_range_feet(entity) -> int:
	if entity == null:
		return 0
	if SpellEffects.has_spell(entity, "darkvision"):
		return 150
	if entity is Character:
		var creature_range := int(entity.feature_uses.get("creature_darkvision_range_feet", 0))
		if creature_range > 0:
			return creature_range
		if entity.darkvision_feet > 0:
			return entity.darkvision_feet
		var race := DataLoader.get_race(entity.race_id)
		if int(race.get("darkvision_feet", 0)) > 0:
			return int(race.get("darkvision_feet", 0))
		if bool(race.get("darkvision", false)):
			for trait_value in race.get("traits", []):
				var trait_data: Dictionary = trait_value
				if str(trait_data.get("name", "")).to_lower() != "darkvision":
					continue
				var expression := RegEx.new()
				if expression.compile("range of ([0-9]+) feet") == OK:
					var result := expression.search(str(trait_data.get("description", "")).to_lower())
					if result != null:
						return int(result.get_string(1))
				return DARKVISION_FALLBACK_FEET
		return 0
	var senses: Dictionary = entity.get("senses", {})	
	return maxi(0, int(entity.get("darkvision_range_feet", senses.get("darkvision", 0))))


static func _has_truesight(entity, distance_feet: int) -> bool:
	if entity == null:
		return false
	if SpellEffects.has_spell(entity, "true_seeing") and distance_feet <= 120:
		return true
	if entity is Character:
		var character_range := int(entity.feature_uses.get("monster_truesight_range_feet", 0))
		return character_range > 0 and character_range >= distance_feet
	var senses: Dictionary = entity.get("senses", {})
	var sense_range := int(entity.get("truesight_range_feet", senses.get("truesight", 0)))
	return sense_range > 0 and sense_range >= distance_feet


static func _has_blindsight(entity, distance_feet: int) -> bool:
	if entity == null:
		return false
	if entity is Character:
		if int(entity.feature_uses.get("creature_blindsight_range_feet", 0)) >= distance_feet and int(entity.feature_uses.get("creature_blindsight_range_feet", 0)) > 0: return true
		for effect in ClassProgression.selected_feature_effects_of_type(entity, "blindsight"):
			var range_feet := int(effect.get("range_feet", 0))
			if range_feet > 0 and distance_feet <= range_feet:
				return true
		return false
	var senses: Dictionary = entity.get("senses", {})
	var sense_range := int(entity.get("blindsight_range_feet", senses.get("blindsight", 0)))
	return sense_range > 0 and sense_range >= distance_feet


static func _is_magically_obscured(entity) -> bool:
	if entity is Character:
		return entity.has_condition("darkness_obscured")
	return entity is Dictionary and (entity.get("conditions", {}) as Dictionary).has("darkness_obscured")


static func _has_condition(entity, condition: String) -> bool:
	if entity is Character:
		return entity.has_condition(condition)
	return entity is Dictionary and (entity.get("conditions", {}) as Dictionary).has(condition)


