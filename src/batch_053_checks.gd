class_name Batch053Checks
extends RefCounted
## Batch 053 (S-121/S-122): legal destinations for created and projected actors.

const PAIR := "fixture:b053_pair"
const GAMBLE := "fixture:b053_gamble"
const COMBAT_PERSIST := "fixture:b053_combat_persistent"
const MIXED := "fixture:b053_mixed_size_factory"

static func load_fixtures() -> void:
	Batch042Checks.load_fixtures()
	if not DataLoader.get_spell(PAIR).is_empty(): return
	DataLoader._load_json_file("res://data/fixtures/batch_053/spells/placement.json", "spell")

static func grid() -> HexGrid:
	var g := HexGrid.new()
	for hex in HexUtils.get_hexes_in_range(Vector2i.ZERO, 3):
		var t := HexTile.new()
		t.coord = hex
		g.add_tile(t)
	return g

static func state(g: HexGrid, players: Array = [], monsters: Array = []) -> Dictionary:
	return {"hex_grid": g, "player_entities": players, "monster_entities": monsters}

static func run(check: Callable) -> void:
	load_fixtures()
	check.call(DataLoader.get_load_errors().is_empty() and not DataLoader.get_spell(PAIR).is_empty() and not DataLoader.get_spell(GAMBLE).is_empty() and not DataLoader.get_spell(COMBAT_PERSIST).is_empty() and not DataLoader.get_spell(MIXED).is_empty(), "053 placement fixtures load: %s" % str(DataLoader.get_load_errors()))
	var bad := [{"range_hexes": 0}, {"no_space": "refund"}, {"choose": "yes"}, {"where": "anywhere"}, []]
	var effect: Dictionary = DataLoader.get_spell(PAIR).effects[0].duplicate(true)
	effect["placement"] = {"no_space": "refund"}
	check.call(bad.all(func(p): return not PlacementRules.policy_error(p).is_empty()) and PlacementRules.policy_error({"range_hexes": 2, "no_space": "spend", "choose": true}).is_empty() and not SharedSpell.content_error({"id": "x", "level": 1, "execution": "shared", "target": "self", "effects": [effect]}).is_empty(), "053 loader refuses unknown placement fields, ranges and failure policies")
	check.call(PlacementRules.policy({}) == {"range_hexes": 1, "no_space": "refuse", "choose": false}, "053 an unauthored placement is adjacent, refuses with no space and does not prompt")
	var g := grid()
	var ally := Batch031Checks._character("b053_ally", 10)
	var foe := {"name": "Foe", "is_alive": true, "hex_position": Vector2i(0, -1)}
	var dead := {"name": "Corpse", "is_alive": false, "hex_position": Vector2i(-1, 0)}
	g.get_tile(Vector2i(1, -1)).custom_properties["blocks_movement"] = true
	var s := state(g, [{"character": ally, "hex_position": Vector2i(1, 0)}], [foe, dead])
	var c := PlacementRules.candidates(s, Vector2i.ZERO, "medium", 1)
	check.call(c == [Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1)], "053 candidates skip the origin, a living ally, a living foe and a blocked cell; a corpse's cell is free (%s)" % str(c))
	check.call(PlacementRules.legal_error(s, Vector2i.ZERO, Vector2i(0, 1), "unknown", 1).contains("unknown"), "053 unknown sizes fail closed instead of receiving an empty footprint")
	check.call(PlacementRules.legal_error(s, Vector2i.ZERO, Vector2i(2, 0), "medium", 1).contains("out of placement range") and PlacementRules.legal_error(s, Vector2i.ZERO, Vector2i(4, 0), "medium", 9).contains("outside"), "053 out-of-range and off-grid destinations are refused")
	var pair := PlacementRules.reserve(s, Vector2i.ZERO, "medium", 1, 2)
	var four := PlacementRules.reserve(s, Vector2i.ZERO, "medium", 1, 4)
	check.call(pair == [Vector2i(-1, 0), Vector2i(-1, 1)] and four.is_empty(), "053 multiple arrivals reserve distinct cells; too few cells reserve none")
	check.call(not PlacementRules.confirm_error(s, Vector2i.ZERO, "medium", 1, [Vector2i(0, 1), Vector2i(0, 1)]).is_empty(), "053 confirmation refuses the same cell twice")
	s.monster_entities.append({"name": "Late", "is_alive": true, "hex_position": Vector2i(0, 1)})
	check.call(PlacementRules.confirm_error(s, Vector2i.ZERO, "medium", 1, [Vector2i(0, 1)]).contains("occupied"), "053 confirmation rechecks: a cell occupied since the pick is refused")
	check.call(PlacementRules.decode(PlacementRules.encode([Vector2i(-1, 1)])) == [Vector2i(-1, 1)], "053 placement picks round-trip through the cast copy")
	var large_grid := grid()
	large_grid.get_tile(Vector2i(1, 0)).custom_properties["blocks_movement"] = true
	var large_state := state(large_grid, [{"character": ally, "hex_position": Vector2i(0, -2)}])
	var large_options := PlacementRules.candidates(large_state, Vector2i(0, -2), "large", 2)
	check.call(PlacementRules.footprint("large").size() == 7 and PlacementRules.legal_error(large_state, Vector2i(0, -2), Vector2i(0, 0), "large", 2).contains("impassable"), "053 Large uses the authored size's seven-cell axial disk and rejects a partly blocked footprint")
	var old_pick := [Vector2i(0, 0)]
	large_grid.get_tile(Vector2i(0, 0)).custom_properties["blocks_movement"] = true
	check.call(PlacementRules.confirm_error(large_state, Vector2i(0, -2), "large", 2, old_pick) != "", "053 placement confirmation catches a cell blocked after the footprint was picked")
	large_grid.get_tile(Vector2i(0, 0)).custom_properties.erase("blocks_movement")
	var exiting := {"id": "large-exit", "size": "large", "is_alive": true, "hex_position": Vector2i(0, -2)}
	var exit_host := SpellCastContext.new()
	exit_host.grid = large_grid
	exit_host.monsters = [exiting]
	var exit_policy := {"range_hexes": 3, "no_space_outcome": "failure"}
	check.call(not SaveExitPlacementRules.chosen_error(exit_host, exiting, Vector2i(0, -2), Vector2i.ZERO, "large", "material", exit_policy).is_empty(), "S-121 required exit rejects a clear center when another cell of the Large footprint is blocked")
	large_grid.get_tile(Vector2i(1, 0)).custom_properties.erase("blocks_movement")
	check.call(SaveExitPlacementRules.chosen_error(exit_host, exiting, Vector2i(0, -2), Vector2i.ZERO, "large", "material", exit_policy).is_empty(), "S-121 full-footprint exit ignores the exiting body's old cells")
	exit_host.monsters.append({"id": "large-blocker", "size": "large", "is_alive": true, "hex_position": Vector2i(2, 0)})
	check.call(not SaveExitPlacementRules.chosen_error(exit_host, exiting, Vector2i(0, -2), Vector2i(1, 0), "medium", "material", exit_policy).is_empty(), "S-121 exit refuses a cell occupied by the edge of another Large footprint")
	large_grid.get_tile(Vector2i(1, 0)).custom_properties["blocks_movement"] = true
	large_grid.get_tile(Vector2i(0, 0)).custom_properties["blocks_movement"] = true
	var mixed_picks := PlacementRules.reserve(large_state, Vector2i(0, -2), ["medium", "large"], 2, 2)
	check.call(mixed_picks.size() == 2 and PlacementRules.confirm_error(large_state, Vector2i(0, -2), ["medium", "large"], 2, mixed_picks).is_empty(), "053 mixed-size reservations retain separate footprints without overlap")
	var mixed_spell := DataLoader.get_spell(MIXED)
	var mixed_effect := CreatedActorRules._effect(mixed_spell)
	check.call(SharedSpell.content_error(mixed_spell).is_empty() and CreatedActorRules.mix_error(mixed_effect).is_empty(), "053 authored mixed factory permits different sizes and per-kind command/initiative policies")
	# S-122 spend policy: paid with no legal space creates nothing and leaves no record.
	var caster := Batch031Checks._character("b053_caster", 20)
	var gamble := DataLoader.get_spell(GAMBLE).duplicate(true)
	gamble["_placement"] = []
	var before := caster.spell_effects.size()
	var applied := SharedSpell.apply(caster, caster, gamble, {"success": true, "slot_level": 1, "effect_cast": {"source_id": "spell:%s:b053" % caster.character_id, "caster_id": caster.character_id, "spell_id": GAMBLE, "concentration": true, "conditions": []}})
	check.call(caster.spell_effects.size() == before and CreatedActorRules.actors(caster).is_empty(), "053 'spend' with no legal space creates no actor and no source record")
	g.free()
	large_grid.free()
