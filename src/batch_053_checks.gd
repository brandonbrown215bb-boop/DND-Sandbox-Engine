class_name Batch053Checks
extends RefCounted
## Batch 053 (S-121/S-122): legal destinations for created and projected actors.

const PAIR := "fixture:b053_pair"
const GAMBLE := "fixture:b053_gamble"

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
	check.call(DataLoader.get_load_errors().is_empty() and not DataLoader.get_spell(PAIR).is_empty() and not DataLoader.get_spell(GAMBLE).is_empty(), "053 placement fixtures load: %s" % str(DataLoader.get_load_errors()))
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
	check.call(PlacementRules.legal_error(s, Vector2i.ZERO, Vector2i(2, 0), "medium", 1).contains("out of placement range") and PlacementRules.legal_error(s, Vector2i.ZERO, Vector2i(4, 0), "medium", 9).contains("outside"), "053 out-of-range and off-grid destinations are refused")
	var pair := PlacementRules.reserve(s, Vector2i.ZERO, "medium", 1, 2)
	var four := PlacementRules.reserve(s, Vector2i.ZERO, "medium", 1, 4)
	check.call(pair == [Vector2i(-1, 0), Vector2i(-1, 1)] and four.is_empty(), "053 multiple arrivals reserve distinct cells; too few cells reserve none")
	check.call(not PlacementRules.confirm_error(s, Vector2i.ZERO, "medium", 1, [Vector2i(0, 1), Vector2i(0, 1)]).is_empty(), "053 confirmation refuses the same cell twice")
	s.monster_entities.append({"name": "Late", "is_alive": true, "hex_position": Vector2i(0, 1)})
	check.call(PlacementRules.confirm_error(s, Vector2i.ZERO, "medium", 1, [Vector2i(0, 1)]).contains("occupied"), "053 confirmation rechecks: a cell occupied since the pick is refused")
	check.call(PlacementRules.decode(PlacementRules.encode([Vector2i(-1, 1)])) == [Vector2i(-1, 1)], "053 placement picks round-trip through the cast copy")
	# S-122 spend policy: paid with no legal space creates nothing and leaves no record.
	var caster := Batch031Checks._character("b053_caster", 20)
	var gamble := DataLoader.get_spell(GAMBLE).duplicate(true)
	gamble["_placement"] = []
	var before := caster.spell_effects.size()
	var applied := SharedSpell.apply(caster, caster, gamble, {"success": true, "slot_level": 1, "effect_cast": {"source_id": "spell:%s:b053" % caster.character_id, "caster_id": caster.character_id, "spell_id": GAMBLE, "concentration": true, "conditions": []}})
	check.call(caster.spell_effects.size() == before and CreatedActorRules.actors(caster).is_empty(), "053 'spend' with no legal space creates no actor and no source record")
	g.free()
