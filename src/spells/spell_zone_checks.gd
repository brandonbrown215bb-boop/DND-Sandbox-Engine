## Regression checks for area ownership across the extracted combat boundary.
class_name SpellZoneChecks
extends RefCounted

static func _character(id: String) -> Character:
	var character := Character.new()
	var scores := AbilityScores.new()
	scores.from_dict({"INT": 16, "CON": 14, "WIS": 14})
	character.initialize(id, "human", "wizard", scores)
	character.character_id = id
	return character

static func run(check: Callable) -> void:
	var state := CombatState.new()
	var grid := HexGrid.new()
	state.hex_grid = grid
	var tile := HexTile.new()
	tile.coord = Vector2i.ZERO
	tile.terrain = HexTile.TerrainType.PLAINS
	grid.add_tile(tile)
	var caster := _character("zone-owner")
	var target := _character("zone-target")
	state.player_entities.assign([{"character": caster, "hex_position": Vector2i.ZERO}])
	var zones := state._spell_zones()
	state.player_entities = [{"character": target, "hex_position": Vector2i(2, 0)}]
	check.call(state._spell_target_at_hex(Vector2i(2, 0)) == target and zones._spell_target_at_hex(Vector2i.ZERO) == null, "Area queries follow replaced encounter entity arrays")
	state.player_entities.assign([{"character": caster, "hex_position": Vector2i.ZERO}])
	zones = state._spell_zones()
	var sources := ["black_tentacles:owned", "black_tentacles:persistent", "black_tentacles:other-caster"]
	for source_id in sources:
		zones.active_spell_zones[source_id] = {"spell_id": "black_tentacles", "caster_id": caster.character_id if source_id != sources[2] else "other-owner", "concentration": source_id != sources[1], "restrained_targets": [target]}
		CombatAction.apply_condition(target, "restrained", 99, source_id)
		grid.add_difficult_terrain(source_id, [Vector2i.ZERO])
	caster.concentrating_on = {"spell_id": "black_tentacles", "black_tentacles_source_id": sources[0]}
	zones.end_area_concentration(caster)
	check.call(not state.active_spell_zones.has(sources[0]) and state.active_spell_zones.has(sources[1]) and state.active_spell_zones.has(sources[2]), "Ending one area cast preserves a persistent cast and another caster's area")
	check.call(not target.condition_sources.get("restrained", {}).has(sources[0]) and target.condition_sources.get("restrained", {}).has(sources[1]) and target.condition_sources.get("restrained", {}).has(sources[2]) and grid.get_hex_cost(Vector2i.ZERO) == 2.0, "Area cleanup removes only its condition source and preserves overlapping Difficult Terrain")
	# Missing source IDs retain the old concentrating-area fallback, while
	# higher-slot nonconcentration casts remain active.
	zones.active_spell_zones["black_tentacles:fallback"] = {"spell_id": "black_tentacles", "caster_id": caster.character_id, "concentration": true}
	caster.concentrating_on = {"spell_id": "black_tentacles"}
	zones.end_area_concentration(caster)
	check.call(not zones.active_spell_zones.has("black_tentacles:fallback") and zones.active_spell_zones.has(sources[1]), "Area ownership fallback preserves nonconcentration Black Tentacles")
	var moon_source := "moonbeam:owned"
	zones.active_spell_zones[moon_source] = {"spell_id": "moonbeam", "caster_id": caster.character_id, "shape_locked_targets": [target]}
	CombatAction.apply_condition(target, "moonbeam_shape_lock", 99, moon_source + ":shape_lock")
	CombatAction.apply_condition(target, "moonbeam_shape_lock", 99, "moonbeam:other:shape_lock")
	caster.concentrating_on = {"spell_id": "moonbeam"}
	zones.end_area_concentration(caster)
	check.call(not zones.active_spell_zones.has(moon_source) and not target.condition_sources.get("moonbeam_shape_lock", {}).has(moon_source + ":shape_lock") and target.condition_sources.get("moonbeam_shape_lock", {}).has("moonbeam:other:shape_lock"), "Moonbeam teardown releases only its cast-owned shape lock")
	zones.active_spell_zones["darkness:overlap"] = {"spell_id": "darkness", "caster_id": "unloaded-owner", "center": Vector2i.ZERO, "coords": [Vector2i.ZERO], "radius_hexes": 3}
	zones.active_spell_zones["darkness:outside"] = {"spell_id": "darkness", "caster_id": "unloaded-owner-2", "center": Vector2i(4, 0), "coords": [Vector2i(4, 0)], "radius_hexes": 3}
	var darkness_removed := SpellZoneTerrain.dispel_darkness_in_area(zones, [Vector2i.ZERO])
	check.call(darkness_removed == 1 and not zones.active_spell_zones.has("darkness:overlap") and zones.active_spell_zones.has("darkness:outside"), "Sunburst removes every overlapping Darkness zone and preserves Darkness outside its sphere")
	state.free()
	grid.free()
