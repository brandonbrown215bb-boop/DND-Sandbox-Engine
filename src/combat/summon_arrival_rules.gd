## Batch 086 (S-121/S-122): a spell's single summoned arrival host. The spell's
## summoned_creature record declares the body size and an ordinary
## PlacementRules placement policy; legality is PlacementRules.legal_error over
## the WHOLE footprint (terrain, map bounds, room walls, plane, clearance, other
## creatures' footprints, blocking objects). The caster's own previous body from
## this spell is ignored, because a new casting replaces it (SRD 5.2.1 Find Steed).
## PARTIAL: one arrival per cast; multi-target and planar arrivals are not here.
class_name SummonArrivalRules
extends RefCounted

## {} when the spell declares no sized arrival; else {"size", "range_hexes", "no_space"}.
static func spec(spell: Dictionary) -> Dictionary:
	var summon: Variant = spell.get("summoned_creature", {})
	if not summon is Dictionary or not summon.has("size") or PlacementRules.footprint(str(summon.size)).is_empty(): return {}
	var policy := PlacementRules.policy(summon)
	return {"size": str(summon.size).to_lower(), "range_hexes": int(policy.range_hexes), "no_space": str(policy.no_space)}

## Load-time refusal for a malformed arrival record ("" when valid or absent).
static func data_error(spell: Dictionary) -> String:
	var summon: Variant = spell.get("summoned_creature", {})
	if not summon is Dictionary: return ""
	if summon.has("size") and PlacementRules.footprint(str(summon.size)).is_empty(): return "summoned_creature size '%s' is not a supported body size" % str(summon.size)
	if summon.has("placement"): return PlacementRules.policy_error(summon.placement)
	return ""

## The living body this owner already has from the steed host, or null.
static func previous_body(players: Array, owner: Character) -> Variant:
	for entity in players:
		if bool(entity.get("is_steed", false)) and is_same(entity.get("steed_owner"), owner): return entity.get("character")
	return null

## "" when hex is a legal arrival for this spell from origin; else the reason.
## range_hexes < 0 skips the range test (recovery of an existing body).
static func destination_error(state, players: Array, owner: Character, origin: Vector2i, hex: Vector2i, spell: Dictionary, range_override: int = -2) -> String:
	var arrival := spec(spell)
	if arrival.is_empty(): return ""
	var ctx := {}
	var body: Variant = previous_body(players, owner)
	if body != null: ctx["ignore_entity"] = body
	var range_hexes: int = int(arrival.range_hexes) if range_override == -2 else range_override
	return PlacementRules.legal_error(state, origin, hex, str(arrival.size), range_hexes, [], ctx)

## Nearest legal full-footprint spaces for recovering an existing body.
static func recovery_candidates(state, players: Array, owner: Character, origin: Vector2i, spell: Dictionary) -> Array[Vector2i]:
	var arrival := spec(spell)
	if arrival.is_empty(): return [] as Array[Vector2i]
	var ctx := {}
	var body: Variant = previous_body(players, owner)
	if body != null: ctx["ignore_entity"] = body
	return PlacementRules.candidates(state, origin, str(arrival.size), int(arrival.range_hexes), [], ctx)

## Hexes between `from` and the nearest cell of a body of `size` centred on
## `center` (0 = inside the footprint, 1 = within 5 feet of it).
static func body_distance(from: Vector2i, center: Vector2i, size: String) -> int:
	var best := HexUtils.get_distance(from, center)
	for offset in PlacementRules.footprint(size):
		best = mini(best, HexUtils.get_distance(from, center + offset))
	return best
