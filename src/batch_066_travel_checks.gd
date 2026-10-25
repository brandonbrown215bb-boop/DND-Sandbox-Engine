class_name Batch066TravelChecks
extends RefCounted
## Batch 066 (S-121/S-122): travel arrival placement. Teleport reach and sight
## come from data; arrival legality is PlacementRules for the traveler's own
## footprint; illegal destinations refuse before any cost; arrival settles once.

static func _grid(radius: int) -> HexGrid:
	var grid := HexGrid.new()
	for q in range(-radius, radius + 1):
		for r in range(maxi(-radius, -q - radius), mini(radius, -q + radius) + 1):
			var tile := HexTile.new()
			tile.coord = Vector2i(q, r)
			grid.add_tile(tile)
	return grid

static func _wizard() -> Character:
	var c := Character.new()
	c.initialize("Travel Wizard", "human", "wizard", AbilityScores.new())
	c.character_id = "b066_wizard"
	c.known_spells.append("misty_step")
	c.spell_slots["2"] = 1
	return c

static func run(check: Callable) -> void:
	var misty: Dictionary = DataLoader.get_spell("misty_step")
	check.call(TravelPlacementRules.spell_error(misty).is_empty() and TravelPlacementRules.range_hexes(misty) == 6 and TravelPlacementRules.requires_sight(misty), "066 Misty Step data declares distance 6 and requires_sight (SRD: a space you can see)")
	var no_distance := {"effects": [{"type": "teleport"}]}
	check.call(not TravelPlacementRules.spell_error(no_distance).is_empty() and TravelPlacementRules.range_hexes(no_distance) == -1, "066 a teleport effect without an authored distance is refused (no engine default)")
	check.call(not TravelPlacementRules.spell_error({"effects": [{"type": "teleport", "distance": 6, "range": 3}]}).is_empty(), "066 unknown teleport fields are refused")
	check.call(not TravelPlacementRules.spell_error({"effects": [{"type": "teleport", "distance": 0}]}).is_empty() and not TravelPlacementRules.spell_error({"effects": [{"type": "teleport", "distance": 6, "requires_sight": "yes"}]}).is_empty(), "066 zero distance and non-boolean sight are refused")
	var grid := _grid(8)
	var wizard := _wizard()
	var players: Array[Dictionary] = [{"character": wizard, "hex_position": Vector2i.ZERO, "is_alive": true}]
	var big: Dictionary = {"id": "b066_ogre", "name": "Ogre", "size": "large", "hex_position": Vector2i(4, 0), "is_alive": true, "current_hp": 10}
	var monsters: Array[Dictionary] = [big]
	var cast := SpellCastContext.new()
	cast.caster = wizard
	cast.players = players
	cast.monsters = monsters
	cast.grid = grid
	var e := func(dest: Vector2i, spell: Dictionary = misty) -> String: return TravelPlacementRules.destination_error(cast, wizard, Vector2i.ZERO, dest, spell, grid)
	check.call(e.call(Vector2i(2, 0)).is_empty(), "066 a free visible space within 6 hexes is legal")
	check.call(not e.call(Vector2i(4, 0)).is_empty(), "066 the occupant's center is refused")
	check.call(not e.call(Vector2i(3, 0)).is_empty(), "066 a cell inside a Large occupant's footprint is refused (not only its center)")
	check.call(not e.call(Vector2i(7, 0)).is_empty(), "066 a destination beyond the authored distance is refused")
	check.call(not e.call(Vector2i.ZERO).is_empty() and not e.call(Vector2i(20, 0)).is_empty(), "066 same space and off-map destinations are refused")
	check.call(not e.call(Vector2i(2, 0), no_distance).is_empty(), "066 a spell without authored distance refuses at cast time")
	grid.get_tile(Vector2i(0, 2)).custom_properties["blocks_movement"] = true
	check.call(not e.call(Vector2i(0, 2)).is_empty(), "066 a wall/impassable destination is refused")
	grid.get_tile(Vector2i(0, 2)).custom_properties["blocks_movement"] = false
	grid.get_tile(Vector2i(-1, 0)).custom_properties["blocks_sight"] = true
	grid.get_tile(Vector2i(-1, 0)).custom_properties["blocks_movement"] = true
	var blind_spell := {"effects": [{"type": "teleport", "distance": 6, "requires_sight": true}]}
	var free_spell := {"effects": [{"type": "teleport", "distance": 6}]}
	check.call(not e.call(Vector2i(-3, 0), blind_spell).is_empty() and e.call(Vector2i(-3, 0), free_spell).is_empty(), "066 sight is required only when the data asks for it")
	# Once-only settle and refuse-before-pay through the real resolver.
	cast.spell = misty.duplicate(true)
	cast.player_index = 0
	cast.hud = null
	cast.target_coord = Vector2i(4, 0)
	check.call(SpellCastMovement.refuse_teleport_destination_reason(cast) != "" and players[0].hex_position == Vector2i.ZERO, "066 the pre-payment recheck refuses an occupied destination and nothing moves")
	cast.target_coord = Vector2i(2, 0)
	check.call(SpellCastMovement.refuse_teleport_destination_reason(cast) == "", "066 the pre-payment recheck accepts the legal destination")
	grid.free()
	# Room host: LocalRoomRules.cast_teleport uses the same rules before the slot.
	var definition: Dictionary = DataLoader.get_campaign("the_lost_crown")["dungeons"]["ruins_of_ashvale"]["tactical_rooms"]["1"]
	var ally := Character.new()
	ally.initialize("Travel Ally", "human", "fighter", AbilityScores.new())
	ally.character_id = "b066_ally"
	var traveler := _wizard()
	var state := LocalRoomRules.create(definition, [traveler, ally])
	var room_grid := HexGrid.new()
	for cell in state.get("cells", []):
		var tile := HexTile.new()
		tile.coord = LocalRoomRules.coord(cell)
		tile.custom_properties["blocks_movement"] = not LocalRoomRules.passable(state, tile.coord)
		tile.custom_properties["blocks_sight"] = LocalRoomRules.blocks_sight(state, tile.coord)
		room_grid.add_tile(tile)
	var room_origin := LocalRoomRules.coord(state.party_positions[traveler.character_id])
	var ally_hex := LocalRoomRules.coord(state.party_positions[ally.character_id])
	var onto_ally := LocalRoomRules.cast_teleport(state, "misty_step", traveler, ally_hex, room_grid, [traveler, ally])
	var far := Vector2i(9999, 9999)
	for cell in state.get("cells", []):
		var c := LocalRoomRules.coord(cell)
		if HexUtils.get_distance(room_origin, c) > 6 and LocalRoomRules.passable(state, c): far = c; break
	var too_far := LocalRoomRules.cast_teleport(state, "misty_step", traveler, far, room_grid, [traveler, ally])
	check.call(not onto_ally.get("success", true) and not too_far.get("success", true) and int(traveler.spell_slots.get("2", 0)) == 1 and LocalRoomRules.coord(state.party_positions[traveler.character_id]) == room_origin, "066 room Misty Step refuses an ally's space and an out-of-range space before the slot (%s / %s)" % [onto_ally.get("message", ""), too_far.get("message", "")])
	var legal := Vector2i(9999, 9999)
	for cell in state.get("cells", []):
		var c := LocalRoomRules.coord(cell)
		if LocalRoomRules.travel_destination_error(state, traveler, room_origin, c, DataLoader.get_spell("misty_step"), room_grid, [traveler, ally]).is_empty(): legal = c; break
	var ok := LocalRoomRules.cast_teleport(state, "misty_step", traveler, legal, room_grid, [traveler, ally])
	var again := LocalRoomRules.cast_teleport(state, "misty_step", traveler, room_origin, room_grid, [traveler, ally])
	check.call(ok.get("success", false) and LocalRoomRules.coord(state.party_positions[traveler.character_id]) == legal and int(traveler.spell_slots.get("2", 0)) == 0 and not again.get("success", true), "066 room Misty Step arrives once, spends one slot, and a second cast with no slot is refused")
	check.call(DungeonPersistence.local_error(JSON.parse_string(JSON.stringify(state))).is_empty(), "066 the room arrival is valid saved room state")
	room_grid.free()
