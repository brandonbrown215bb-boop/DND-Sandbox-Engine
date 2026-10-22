## S-121/S-122 (Batch 053): legal destinations for created and projected actors.
## A destination is legal when PhysicalFactsRules.is_space_available accepts it
## (grid tile, passable, no room wall, plane, clearance, no living occupant, no
## blocking object), it lies within the authored range of the origin, and no
## other actor of the same operation has reserved it. Single-cell bodies only.
class_name PlacementRules
extends RefCounted

const POLICY_KEYS := ["range_hexes", "no_space", "choose"]
## refuse: no legal space refuses before any cost. spend: the cost is paid and nothing is created.
const NO_SPACE := ["refuse", "spend"]
const DEFAULT := {"range_hexes": 1, "no_space": "refuse", "choose": false}

static func policy_error(p: Variant) -> String:
	if not p is Dictionary: return "placement must be an object"
	for key in p:
		if str(key) not in POLICY_KEYS: return "placement has unknown field '%s'" % key
	if p.has("range_hexes") and not CreatedActorRules._int(p.range_hexes, 1, 24): return "placement range_hexes must be 1-24"
	if p.has("no_space") and str(p.no_space) not in NO_SPACE: return "placement no_space must be refuse or spend"
	if p.has("choose") and not p.choose is bool: return "placement choose must be a boolean"
	return ""

## Authored policy, with the conservative default (adjacent, refuse, no prompt).
static func policy(effect: Dictionary) -> Dictionary:
	var out := DEFAULT.duplicate()
	var p: Variant = effect.get("placement", {})
	if p is Dictionary and policy_error(p).is_empty(): out.merge(p, true)
	return out

static func _context(state) -> Dictionary:
	var ctx := {}
	if state == null: return ctx
	if "player_entities" in state: ctx["players"] = state.player_entities
	elif "players" in state: ctx["players"] = state.players
	if "monster_entities" in state: ctx["monsters"] = state.monster_entities
	elif "monsters" in state: ctx["monsters"] = state.monsters
	ctx["room"] = state.room if "room" in state and state.room is Dictionary else LocalRoomCombat.room()
	ctx["plane"] = PhysicalFactsRules.get_plane(ctx.room, GameManager.transition_context)
	if "plane" in state: ctx["plane"] = str(state.plane)
	if "objects" in state: ctx["objects"] = state.objects
	return ctx

static func _grid(state) -> HexGrid:
	if state == null: return null
	if "hex_grid" in state: return state.hex_grid
	if "grid" in state: return state.grid
	return null

## "" when this hex is a legal destination, otherwise the reason.
static func legal_error(state, origin: Vector2i, hex: Vector2i, size: String, range_hexes: int, reserved: Array = []) -> String:
	if hex in reserved: return "Position %s is already reserved for another arrival." % str(hex)
	if HexUtils.get_distance(origin, hex) > range_hexes or hex == origin: return "Position %s is out of placement range." % str(hex)
	var ctx := _context(state)
	var plane := str(ctx.get("plane", PhysicalFactsRules.DEFAULT_PLANE))
	if state != null and "caster" in state and state.caster is Character:
		plane = PhysicalFactsRules.get_plane(state.caster, ctx)
	else:
		for entity in ctx.get("players", []):
			if entity.get("hex_position") == origin:
				plane = PhysicalFactsRules.get_plane(entity.get("character"), ctx)
				break
	var space := PhysicalFactsRules.is_space_available(_grid(state), hex, size, plane, ctx)
	return "" if bool(space.get("available", false)) else str(space.get("reason", "No space."))

## Legal destinations nearest first (ties by coordinate), excluding reserved ones.
static func candidates(state, origin: Vector2i, size: String, range_hexes: int, reserved: Array = []) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for hex in HexUtils.get_hexes_in_range(origin, range_hexes):
		if legal_error(state, origin, hex, size, range_hexes, reserved).is_empty(): out.append(hex)
	out.sort_custom(func(x, y): return [HexUtils.get_distance(origin, x), x.x, x.y] < [HexUtils.get_distance(origin, y), y.x, y.y])
	return out

## Distinct destinations for count arrivals, or [] when there are not enough.
static func reserve(state, origin: Vector2i, size: String, range_hexes: int, count: int, reserved: Array = []) -> Array[Vector2i]:
	var taken: Array = reserved.duplicate()
	var out: Array[Vector2i] = []
	for i in count:
		var options := candidates(state, origin, size, range_hexes, taken)
		if options.is_empty(): return [] as Array[Vector2i]
		out.append(options[0])
		taken.append(options[0])
	return out

## Recheck chosen destinations at confirmation: each still legal and distinct.
static func confirm_error(state, origin: Vector2i, size: String, range_hexes: int, picks: Array) -> String:
	var seen: Array = []
	for hex in picks:
		var e := legal_error(state, origin, hex, size, range_hexes, seen)
		if not e.is_empty(): return e
		seen.append(hex)
	return ""

static func encode(picks: Array) -> Array:
	return picks.map(func(h): return [h.x, h.y])

static func decode(raw: Variant) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if raw is Array:
		for p in raw:
			if p is Array and p.size() == 2: out.append(Vector2i(int(p[0]), int(p[1])))
	return out
