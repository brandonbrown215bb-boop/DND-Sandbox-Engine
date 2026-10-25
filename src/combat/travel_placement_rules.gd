## S-121/S-122 (Batch 066): arrival placement for travel/teleport hosts.
## A `teleport` effect declares its own reach and sight requirement in data:
##   {"type": "teleport", "distance": <hexes 1-200>, "requires_sight": <bool>?}
## There is no engine default distance: a teleport effect without `distance`
## is refused by the loader and refused at cast time before any cost.
## Legality is PlacementRules.legal_error for the traveler's own size-based
## footprint (tile, walls, plane, clearance, living occupants, blocking objects),
## ignoring the traveler's current body.
class_name TravelPlacementRules
extends RefCounted

const TELEPORT_KEYS := ["type", "distance", "requires_sight"]

static func teleport_effects(spell: Dictionary) -> Array:
	return spell.get("effects", []).filter(func(e): return e is Dictionary and str(e.get("type", "")) == "teleport")

## Loader check for every teleport effect in a spell. "" when valid.
static func spell_error(spell: Dictionary) -> String:
	for effect in teleport_effects(spell):
		for key in effect:
			if str(key) not in TELEPORT_KEYS: return "teleport effect has unknown field '%s'" % key
		if not effect.has("distance") or not CreatedActorRules._int(effect.distance, 1, 200): return "teleport effect requires an authored distance of 1-200 hexes"
		if effect.has("requires_sight") and not effect.requires_sight is bool: return "teleport requires_sight must be a boolean"
	return ""

## The authored reach in hexes, or -1 when no valid teleport effect is declared.
static func range_hexes(spell: Dictionary) -> int:
	var out := -1
	if not spell_error(spell).is_empty(): return -1
	for effect in teleport_effects(spell): out = maxi(out, int(effect.distance))
	return out

static func requires_sight(spell: Dictionary) -> bool:
	return teleport_effects(spell).any(func(e): return bool(e.get("requires_sight", false)))

## "" when the traveler may arrive at destination; otherwise the refusal reason.
## state is any PlacementRules host (combat node or room placement Dictionary).
static func destination_error(state, traveler, origin: Vector2i, destination: Vector2i, spell: Dictionary, grid: HexGrid, reserved: Array = []) -> String:
	var reach := range_hexes(spell)
	if reach < 1: return "That teleport has no authored distance."
	if destination == origin: return "Choose a different space to teleport to."
	if grid == null or not grid.has_tile(destination): return "That teleport destination is not on the map."
	if HexUtils.get_distance(origin, destination) > reach: return "That teleport destination is out of range."
	if requires_sight(spell) and not Targeting.has_line_of_sight(origin, destination, grid): return "That teleport destination is not visible."
	if traveler == null: return "No traveler is represented for that teleport."
	var size := PhysicalFactsRules.get_size(traveler)
	var error := PlacementRules.legal_error(state, origin, destination, size, reach, reserved, {"ignore_entity": traveler})
	return "" if error.is_empty() else "That teleport destination is not available: %s" % error

## Review 066 R1 / Batch 076: forced-movement step legality. A legal start is
## held to full footprint legality. A start that is already illegal (legacy
## overlap) gets a narrow escape allowance: it may keep moving through creature
## overlap only. Terrain is never waived: every cell of its footprint must be on
## the map and enterable (PlacementRules.footprint_terrain_error), so a Huge
## body cannot pass through or land in a wall because its center fits.
static func forced_step_blocked(state, from_hex: Vector2i, to_hex: Vector2i, size: String, mover) -> bool:
	var ctx := {"ignore_entity": mover}
	if PlacementRules.legal_error(state, to_hex, to_hex, size, -1, [], ctx).is_empty(): return false
	if PlacementRules.legal_error(state, from_hex, from_hex, size, -1, [], ctx).is_empty(): return true
	return not PlacementRules.footprint_terrain_error(state, to_hex, size, ctx).is_empty()
