class_name Batch076FootprintControls
extends RefCounted
## Batch 076 (#38 follow-up): live combat forced movement through the
## production push host (CombatState._push_combat_target ->
## TravelPlacementRules.forced_step_blocked -> PlacementRules.footprint_terrain_error).
## A Huge creature is refused passing through a wall when only its center fits;
## a legal push moves; the overlap escape allowance never waives terrain.

static func _clear_area(combat: Node) -> void:
	for q in range(-6, 9):
		for r in range(-6, 7):
			var tile := HexTile.new()
			tile.coord = Vector2i(q, r)
			combat.hex_grid.add_tile(tile)

static func run(h: Node) -> void:
	h._enter_test("batch_076_footprint_terrain_flow")
	h._setup_world()
	GameManager.transition_context["monster_ids"] = ["goblin"]
	var fighter: Character = h._fresh_char("Footprint Fighter", "human", "fighter", {"STR": 16, "DEX": 12, "CON": 14, "INT": 10, "WIS": 10, "CHA": 10})
	PlayerManager.set_player_character(0, fighter)
	PartyManager.reset()
	PartyManager.register_player_character(0, fighter)
	var combat: Node = await h._spawn_scene("res://scenes/combat.tscn", 1.5)
	_clear_area(combat)
	for i in combat.player_entities.size():
		combat.player_entities[i]["hex_position"] = Vector2i(-5, -i)
	var giant: Dictionary = combat.monster_entities[0]
	giant["size"] = "huge"
	giant["current_hp"] = 10000
	giant["max_hp"] = 10000
	giant["hex_position"] = Vector2i.ZERO
	combat._update_grid_entities()
	var wall: HexTile = combat.hex_grid.get_tile(Vector2i(3, -2)) # edge cell of a Huge footprint centred on (1,0)
	wall.custom_properties["blocks_movement"] = true
	var center_fits: bool = PlacementRules.footprint_terrain_error(combat, Vector2i(1, 0), "medium").is_empty()
	var moved: int = await combat._push_combat_target(giant, Vector2i(-1, 0), 2, false)
	h._assert(center_fits and moved == 0 and giant["hex_position"] == Vector2i.ZERO, "076 live a Huge creature is refused passing into a wall that only its edge cell touches (center fits)")
	# Escape allowance: the start overlaps another creature, terrain still binds.
	combat.player_entities[0]["hex_position"] = Vector2i(0, 1)
	combat._update_grid_entities()
	moved = await combat._push_combat_target(giant, Vector2i(-1, 0), 2, false)
	h._assert(moved == 0 and giant["hex_position"] == Vector2i.ZERO, "076 live an overlapping Huge start gets no terrain waiver from the escape allowance")
	wall.custom_properties["blocks_movement"] = false
	moved = await combat._push_combat_target(giant, Vector2i(-1, 0), 2, false)
	h._assert(moved == 10 and giant["hex_position"] == Vector2i(2, 0), "076 live with the wall gone the overlapping Huge start escapes 10 feet (creature overlap only is waived)")
	# Legal case from a legal start.
	combat.player_entities[0]["hex_position"] = Vector2i(-5, 0)
	combat._update_grid_entities()
	moved = await combat._push_combat_target(giant, Vector2i(1, 0), 2, false)
	h._assert(moved == 10 and giant["hex_position"] == Vector2i(4, 0), "076 live a legal Huge push moves the full distance when its whole footprint fits")
	# Map bounds: the next step would put edge cells off the map although the center is on it.
	for r in range(-6, 7):
		combat.hex_grid.remove_tile(Vector2i(8, r))
	var at_edge: bool = combat.hex_grid.has_tile(Vector2i(7, 0))
	moved = await combat._push_combat_target(giant, Vector2i(3, 0), 3, false)
	h._assert(at_edge and giant["hex_position"] == Vector2i(5, 0) and moved == 5, "076 live a Huge push stops before its footprint would leave the map, though its center would stay on it")
	h._teardown_scene(combat)
	h._exit_test()
