class_name Batch086Checks
extends RefCounted
## Batch 086 (S-121/S-122): Find Steed's arrival host. The data-declared Large
## body must fit its WHOLE footprint (PlacementRules.legal_error) inside the
## invocation's range; the caster's own previous steed is replaced, so it never
## blocks the new arrival; recovery picks the nearest full-footprint space.

static func run(check: Callable) -> void:
	var spell := DataLoader.get_spell("find_steed")
	var arrival := SummonArrivalRules.spec(spell)
	check.call(arrival.get("size") == "large" and int(arrival.get("range_hexes", 0)) == 6 and arrival.get("no_space") == "refuse", "086 Find Steed data declares a Large body and a 30-foot refuse-before-cost placement (spec=%s)" % JSON.stringify(arrival))
	check.call(SummonArrivalRules.spec({"summoned_creature": {"kind": "x"}}).is_empty() and SummonArrivalRules.spec({}).is_empty(), "086 a spell with no declared body size has no arrival host")
	check.call(not SummonArrivalRules.data_error({"summoned_creature": {"size": "colossal"}}).is_empty() and not SummonArrivalRules.data_error({"summoned_creature": {"size": "large", "placement": {"range_hexes": 0}}}).is_empty() and not SummonArrivalRules.data_error({"summoned_creature": {"size": "large", "placement": {"rnage": 3}}}).is_empty(), "086 load validation refuses an unknown body size, a bad range and an unknown placement key")
	check.call(SummonArrivalRules.data_error(spell).is_empty(), "086 the shipped Find Steed record validates")
	var grid := Batch066TravelChecks._grid(8)
	var paladin := Batch066TravelChecks._wizard()
	var players: Array[Dictionary] = [{"character": paladin, "hex_position": Vector2i.ZERO, "is_alive": true}]
	var cast := SpellCastContext.new()
	cast.caster = paladin
	cast.players = players
	cast.monsters = [] as Array[Dictionary]
	cast.grid = grid
	check.call(SummonArrivalRules.destination_error(cast, players, paladin, Vector2i.ZERO, Vector2i(3, 0), spell).is_empty(), "086 an open Large footprint 15 ft away is a legal arrival")
	check.call(not SummonArrivalRules.destination_error(cast, players, paladin, Vector2i.ZERO, Vector2i(1, 0), spell).is_empty(), "086 a Large footprint adjacent to the caster overlaps the caster and is refused (the center alone would fit)")
	# A wall under one edge cell of the Large footprint centred on (3,0).
	grid.get_tile(Vector2i(4, -1)).custom_properties["blocks_movement"] = true
	var walled := SummonArrivalRules.destination_error(cast, players, paladin, Vector2i.ZERO, Vector2i(3, 0), spell)
	check.call(not walled.is_empty() and PlacementRules.footprint_terrain_error(cast, Vector2i(3, 0), "medium").is_empty(), "086 a wall under an edge cell refuses the Large arrival although its center is open (%s)" % walled)
	grid.get_tile(Vector2i(4, -1)).custom_properties["blocks_movement"] = false
	check.call(not SummonArrivalRules.destination_error(cast, players, paladin, Vector2i.ZERO, Vector2i(7, 0), spell).is_empty(), "086 a space beyond 30 feet is out of range")
	check.call(SummonArrivalRules.destination_error(cast, players, paladin, Vector2i.ZERO, Vector2i(7, 0), spell, 8).is_empty(), "086 the invocation's own range (e.g. a cast-local transform) is honoured")
	# Map edge: center on the map, an edge cell off it.
	var edge := Vector2i(8, -4)
	check.call(grid.has_tile(edge) and not SummonArrivalRules.destination_error(cast, players, paladin, Vector2i(4, -2), edge, spell, -1).is_empty(), "086 a Large footprint hanging off the map is refused")
	# Another creature's footprint, and the caster's own previous steed.
	var other := Character.new()
	other.is_alive = true
	players.append({"character": other, "hex_position": Vector2i(4, 0), "is_alive": true})
	check.call(not SummonArrivalRules.destination_error(cast, players, paladin, Vector2i.ZERO, Vector2i(3, 0), spell).is_empty(), "086 another creature inside the footprint refuses the arrival")
	players[1]["is_steed"] = true
	players[1]["steed_owner"] = paladin
	check.call(SummonArrivalRules.destination_error(cast, players, paladin, Vector2i.ZERO, Vector2i(3, 0), spell).is_empty(), "086 the caster's own previous steed is replaced and does not block the new arrival")
	players[1]["steed_owner"] = Character.new()
	check.call(not SummonArrivalRules.destination_error(cast, players, paladin, Vector2i.ZERO, Vector2i(3, 0), spell).is_empty(), "086 someone else's steed still blocks")
	players.remove_at(1)
	# Recovery: nearest legal full-footprint space, never a center-only fit.
	var options := SummonArrivalRules.recovery_candidates(cast, players, paladin, Vector2i.ZERO, spell)
	var first: Vector2i = options[0] if not options.is_empty() else Vector2i(999, 999)
	check.call(not options.is_empty() and HexUtils.get_distance(Vector2i.ZERO, first) == 2 and PlacementRules.legal_error(cast, first, first, "large", -1).is_empty(), "086 recovery picks the nearest space whose whole Large footprint fits (first=%s)" % str(first))
