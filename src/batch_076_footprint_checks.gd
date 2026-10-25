class_name Batch076FootprintChecks
extends RefCounted
## Batch 076 (#38 follow-up, S-121/S-122): the whole size-based footprint is
## checked against terrain and map bounds. A Huge creature is never allowed to
## pass through or land in a wall because its center fits; the overlap escape
## allowance waives creature overlap only, never terrain.

static func _mover(at: Vector2i) -> Dictionary:
	return {"id": "b076_huge", "name": "Footprint Giant", "size": "huge", "hex_position": at, "is_alive": true, "current_hp": 10}

static func run(check: Callable) -> void:
	var grid := Batch066TravelChecks._grid(8)
	var wizard := Batch066TravelChecks._wizard()
	var players: Array[Dictionary] = [{"character": wizard, "hex_position": Vector2i(-6, 0), "is_alive": true}]
	var huge := _mover(Vector2i.ZERO)
	var cast := SpellCastContext.new()
	cast.caster = wizard
	cast.players = players
	cast.monsters = [huge] as Array[Dictionary]
	cast.grid = grid
	# (3,-2) is inside a Huge footprint centred on (1,0) but not its center.
	var wall := Vector2i(3, -2)
	check.call(PlacementRules.footprint_terrain_error(cast, Vector2i(1, 0), "huge").is_empty(), "076 an open area fits a Huge footprint")
	grid.get_tile(wall).custom_properties["blocks_movement"] = true
	check.call(PlacementRules.footprint_terrain_error(cast, Vector2i(1, 0), "medium").is_empty(), "076 the Huge center cell alone is open (the center fits)")
	check.call(not PlacementRules.footprint_terrain_error(cast, Vector2i(1, 0), "huge").is_empty(), "076 a wall under an edge cell of a Huge footprint is refused")
	check.call(TravelPlacementRules.forced_step_blocked(cast, Vector2i.ZERO, Vector2i(1, 0), "huge", huge), "076 a legal Huge start is not pushed into a wall under an edge cell")
	# Escape allowance: an overlapping start may pass creature overlap, never terrain.
	players[0].hex_position = Vector2i(0, 1)
	check.call(TravelPlacementRules.forced_step_blocked(cast, Vector2i.ZERO, Vector2i(1, 0), "huge", huge), "076 an overlapping Huge start is still refused when an edge cell enters a wall (terrain never waived)")
	grid.get_tile(wall).custom_properties["blocks_movement"] = false
	check.call(not TravelPlacementRules.forced_step_blocked(cast, Vector2i.ZERO, Vector2i(1, 0), "huge", huge), "076 an overlapping Huge start may still move through creature overlap when terrain fits")
	# Map bounds: center on the map, an edge cell off it.
	huge.hex_position = Vector2i(6, 0)
	players[0].hex_position = Vector2i(6, 1)
	check.call(grid.has_tile(Vector2i(7, 0)) and TravelPlacementRules.forced_step_blocked(cast, Vector2i(6, 0), Vector2i(7, 0), "huge", huge), "076 an overlapping Huge start is refused when an edge cell would leave the map")
	players[0].hex_position = Vector2i(-6, 0)
	huge.hex_position = Vector2i.ZERO
	# Teleport arrival shares the same full-footprint rule (production host:
	# TravelPlacementRules.destination_error -> PlacementRules.legal_error).
	var spell := {"effects": [{"type": "teleport", "distance": 6}]}
	check.call(TravelPlacementRules.destination_error(cast, huge, Vector2i.ZERO, Vector2i(3, 0), spell, grid).is_empty(), "076 a Huge traveler may land where its whole footprint fits")
	grid.get_tile(Vector2i(5, -2)).custom_properties["blocks_movement"] = true
	check.call(not TravelPlacementRules.destination_error(cast, huge, Vector2i.ZERO, Vector2i(3, 0), spell, grid).is_empty(), "076 a Huge traveler cannot land with an edge cell in a wall although its center fits")
	grid.get_tile(Vector2i(5, -2)).custom_properties["blocks_movement"] = false
	check.call(not TravelPlacementRules.destination_error(cast, huge, Vector2i(1, 0), Vector2i(7, 0), spell, grid).is_empty(), "076 a Huge traveler cannot land with edge cells off the map although its center is on it")
	# Review 076 stress: Large edge wall, axial-diagonal push, legal start into a creature.
	var large := {"id": "b076_large", "name": "Footprint Ogre", "size": "large", "hex_position": Vector2i.ZERO, "is_alive": true, "current_hp": 10}
	cast.monsters = [large] as Array[Dictionary]
	grid.get_tile(Vector2i(2, -1)).custom_properties["blocks_movement"] = true
	check.call(TravelPlacementRules.forced_step_blocked(cast, Vector2i.ZERO, Vector2i(1, 0), "large", large), "076 review: a Large body is not pushed with an edge cell into a wall")
	check.call(TravelPlacementRules.forced_step_blocked(cast, Vector2i.ZERO, Vector2i(1, -1), "large", large), "076 review: an axial-diagonal push is refused when an edge cell enters a wall")
	grid.get_tile(Vector2i(2, -1)).custom_properties["blocks_movement"] = false
	check.call(not TravelPlacementRules.forced_step_blocked(cast, Vector2i.ZERO, Vector2i(-1, 1), "large", large), "076 review: an axial-diagonal push into open terrain is allowed")
	players[0].hex_position = Vector2i(-2, 0)
	check.call(TravelPlacementRules.forced_step_blocked(cast, Vector2i.ZERO, Vector2i(-1, 0), "large", large), "076 review: a legal Large start is not pushed into another creature's square")
	check.call(not PhysicalFactsRules.is_space_available(grid, Vector2i(-2, 0), "medium", "material", {"players": players}).available and PhysicalFactsRules.is_space_available(grid, Vector2i(-2, 0), "medium", "material", {"ignore_occupants": true}).available, "076 review: occupants still block by default; only the explicit flag ignores them")
	grid.free()
