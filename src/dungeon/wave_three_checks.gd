## Regressions for durable area ownership and room movement boundaries.
class_name WaveThreeChecks
extends RefCounted

static func run(check: Callable) -> void:
	var prior_context := GameManager.transition_context.duplicate()
	var prior_active := GameManager.active_dungeon_state
	var prior_snapshots := GameManager.dungeon_snapshots
	var definition: Dictionary = DataLoader.get_campaign("the_lost_crown")["dungeons"]["ruins_of_ashvale"]["tactical_rooms"]["1"]
	var transferred_spells: Array[String] = ["fog_cloud", "darkness", "cloud_of_daggers", "spike_growth", "entangle", "black_tentacles", "grease", "sleet_storm", "moonbeam", "wall_of_fire"]
	for spell_id in transferred_spells:
		var caster := Character.new()
		caster.initialize("Area owner", "human", "wizard", AbilityScores.new())
		caster.character_id = "wave3_%s" % spell_id
		var source_id := "%s:%s:1" % [spell_id, caster.character_id]
		var concentrating := spell_id != "grease"
		caster.concentrating_on = {"spell_id": spell_id, "%s_source_id" % spell_id: source_id, "targets": []} if concentrating else {}
		var room_state := LocalRoomRules.create(definition, [caster])
		GameManager.transition_context = {"local_room": room_state}
		var slot_level := 4 if spell_id in ["black_tentacles", "wall_of_fire"] else 3 if spell_id == "sleet_storm" else 2
		var zone := {"spell_id": spell_id, "source_id": source_id, "caster_id": caster.character_id, "center": Vector2i.ZERO, "coords": [Vector2i.ZERO], "dangerous_coords": [Vector2i.ZERO, Vector2i(0, 1)], "radius_hexes": 1, "rounds_remaining": 8, "concentration": concentrating, "slot_level": slot_level, "save_dc": 13, "heavily_obscured": true, "douses_exposed_flames": true, "height_feet": 40}
		zone["damage_formula"] = "5d8" if spell_id == "wall_of_fire" else "2d4" if spell_id == "spike_growth" else "4d4"
		LocalRoomCombat.capture_spell_zones([{"character": caster}], {source_id: zone})
		var caster_dto: Dictionary = JSON.parse_string(JSON.stringify(caster.to_dict()))
		var room_dto: Dictionary = JSON.parse_string(JSON.stringify(room_state))
		var reloaded := Character.new()
		reloaded.from_dict(caster_dto)
		GameManager.transition_context = {"local_room": room_dto}
		var restored := LocalRoomCombat.restore_spell_zones([{"character": reloaded}])
		check.call(SpellEffects.saved_state_error(caster_dto).is_empty() and DungeonPersistence.local_error(room_dto).is_empty() and restored.has(source_id) and int(restored[source_id]["rounds_remaining"]) == 8, "%s retains its concentration owner, footprint and duration through character/room JSON reload" % spell_id)

	# End Concentration from another room, including an unloaded dungeon.
	var owner := Character.new()
	owner.initialize("Unloaded owner", "human", "wizard", AbilityScores.new())
	owner.character_id = "unloaded_owner"
	owner.concentrating_on = {"spell_id": "fog_cloud", "fog_cloud_source_id": "fog:owned", "effect_source": "spell:unloaded_owner:1"}
	var unloaded := LocalRoomRules.create(definition, [owner])
	LocalRoomAreas.add(unloaded, "fog_cloud", owner.character_id, Vector2i.ZERO, 1, 600, 1, {"concentration_source_id": "fog:owned", "heavily_obscured": true})
	LocalRoomAreas.add(unloaded, "fog_cloud", "other_owner", Vector2i.ZERO, 1, 600, 1, {"concentration_source_id": "fog:other", "heavily_obscured": true})
	GameManager.active_dungeon_state = {}
	GameManager.transition_context = {}
	GameManager.dungeon_snapshots = {"ruins_of_ashvale": {"local_rooms": {"1": unloaded}}}
	SpellEffects.end_concentration(owner, [owner])
	check.call(unloaded["areas"].size() == 1 and unloaded["areas"][0]["concentration_source_id"] == "fog:other", "Ending Concentration elsewhere clears only the owner's unloaded room area")

	var flyer := Character.new()
	flyer.initialize("Floor boundary", "human", "wizard", AbilityScores.new())
	flyer.character_id = "floor_boundary"
	flyer.set_movement_speed_feet("fly", 60)
	var flight_room := LocalRoomRules.create(definition, [flyer])
	flight_room["party_positions"][flyer.character_id] = [0, 0]
	flight_room["party_altitudes"][flyer.character_id] = 0
	flight_room["cell_elevations"] = [{"position": [1, 0], "feet": 10}]
	var grid := HexGrid.new()
	for position in [Vector2i.ZERO, Vector2i(1, 0)]:
		var tile := HexTile.new()
		tile.coord = position
		grid.add_tile(tile)
	var blocked := LocalRoomRules.move(flight_room, flyer, Vector2i(1, 0), grid, "fly")
	check.call(not blocked.get("success", true) and LocalRoomRules.coord(flight_room["party_positions"][flyer.character_id]) == Vector2i.ZERO, "Flight cannot enter raised ground below its floor elevation")
	flight_room["party_altitudes"][flyer.character_id] = 10
	check.call(LocalRoomRules.move(flight_room, flyer, Vector2i(1, 0), grid, "fly").get("success", false), "Flight can enter raised ground after gaining sufficient altitude")
	grid.free()
	_check_barriers(check, definition)
	_check_heat(check, definition)
	GameManager.transition_context = prior_context
	GameManager.active_dungeon_state = prior_active
	GameManager.dungeon_snapshots = prior_snapshots


static func _check_barriers(check: Callable, definition: Dictionary) -> void:
	var owner := Character.new()
	owner.initialize("Barrier owner", "human", "fighter", AbilityScores.new())
	owner.character_id = "barrier_owner"
	var state := LocalRoomRules.create(definition, [owner])
	var timber := LocalRoomRules.get_object(state, "timber_partition")
	var stone := LocalRoomRules.get_object(state, "stone_partition")
	check.call(not timber.is_empty() and not stone.is_empty() and LocalRoomRules.has_wall(state, Vector2i(0, -1)) and LocalRoomRules.blocks_sight(state, Vector2i(0, -1)), "The authored timber and stone partitions block movement and sight before damage")
	var timber_damage := CombatObjectRules.apply_damage(timber, 5, "fire")
	var stone_fire := CombatObjectRules.apply_damage(stone, 20, "fire")
	var stone_small_hit := CombatObjectRules.apply_damage(stone, 9, "bludgeoning")
	var stone_big_hit := CombatObjectRules.apply_damage(stone, 10, "bludgeoning")
	check.call(timber_damage == 5 and CombatObjectRules.ignite(timber) and stone_fire == 0 and not CombatObjectRules.ignite(stone) and stone_small_hit == 0 and stone_big_hit == 10, "Wood can burn; authored stone rejects Fire and sub-threshold damage, while a sufficient physical hit damages it")
	CombatObjectRules.apply_damage(timber, 100, "bludgeoning")
	var snapshot: Dictionary = JSON.parse_string(JSON.stringify(state))
	check.call(not LocalRoomRules.has_wall(snapshot, Vector2i(0, -1)) and LocalRoomRules.passable(snapshot, Vector2i(0, -1)) and not LocalRoomRules.blocks_sight(snapshot, Vector2i(0, -1)) and DungeonPersistence.local_error(snapshot).is_empty(), "A destroyed partition opens passage and sight after validated room JSON reload")
	stone["material"] = "glass"
	check.call(LocalRoomRules.has_wall(state, Vector2i(0, 1)) and not LocalRoomRules.blocks_sight(state, Vector2i(0, 1)), "An intact glass barrier blocks movement while allowing sight")
	var corrupt := snapshot.duplicate(true)
	LocalRoomRules.get_object(corrupt, "stone_partition")["damage_threshold"] = "bad"
	check.call(not DungeonPersistence.local_error(corrupt).is_empty(), "Malformed barrier damage data is rejected before loading")


static func _check_heat(check: Callable, definition: Dictionary) -> void:
	var actor := Character.new()
	actor.initialize("Heat boundary", "human", "druid", AbilityScores.new())
	actor.character_id = "heat_boundary"
	actor.max_hp = 100
	actor.current_hp = 100
	var state := LocalRoomRules.create(definition, [actor])
	var position := Vector2i(3, -1)
	var snapshot: Dictionary = JSON.parse_string(JSON.stringify(state))
	check.call(DungeonPersistence.local_error(snapshot).is_empty() and snapshot["cell_terrains"][0]["heat_damage_formula"] == "1d4", "Authored heat damage and vertical reach survive validated room JSON reload")
	var exposure := LocalRoomRules.resolve_surface_heat(snapshot, actor, position, 0)
	var above_heat := LocalRoomRules.resolve_surface_heat(snapshot, actor, position, 10)
	var immune := LocalRoomRules.resolve_surface_heat(snapshot, {"current_hp": 100, "damage_immunities": ["fire"], "conditions": {}}, position, 0)
	check.call(int(exposure.get("damage", 0)) in range(1, 5) and above_heat.is_empty() and int(immune.get("damage", -1)) == 0, "Authored surface heat damages an exposed creature, respects Fire immunity, and stops above its vertical reach")
	snapshot["cell_terrains"][0]["heat_damage_formula"] = "bad"
	check.call(not DungeonPersistence.local_error(snapshot).is_empty(), "Malformed surface heat refuses before loading")
	actor.known_spells.append("water_walk")
	actor.spell_slots["3"] = 1
	actor.inventory.add_item("component_pouch")
	actor.inventory.unequip(Inventory.Slot.WEAPON)
	LocalRoomRules.cast_movement_spell(state, "water_walk", actor, [actor])
	state["party_positions"][actor.character_id] = [2, -1]
	actor.current_hp = 1
	var grid := HexGrid.new()
	for cell in [Vector2i(2, -1), Vector2i(3, -1), Vector2i(4, -1)]:
		var tile := HexTile.new()
		tile.coord = cell
		grid.add_tile(tile)
	var interrupted := LocalRoomRules.move(state, actor, Vector2i(4, -1), grid)
	check.call(interrupted.get("success", false) and not actor.is_alive and state["party_positions"][actor.character_id] == [3, -1] and int(interrupted.get("movement_cost_feet", 0)) == 5, "Heat that knocks out a walker stops movement in the damaging cell without charging the untraveled route")
	grid.free()
