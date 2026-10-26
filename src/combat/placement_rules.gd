## S-121/S-122 (Batch 053): legal destinations for created and projected actors.
## A destination is legal when PhysicalFactsRules.is_space_available accepts it
## (grid tile, passable, no room wall, plane, clearance, no living occupant, no
## blocking object), it lies within the authored range of the origin, and no
## other actor of the same operation has reserved it. Bodies use a supported
## axial hex disk derived from their authored size: radius 0/0/0/1/2/3.
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
	if state is Dictionary and state.get("_placement_players") is Array: ctx["players"] = state["_placement_players"]
	elif "player_entities" in state: ctx["players"] = state.player_entities
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
	if state is Dictionary and state.get("_placement_grid") is HexGrid: return state["_placement_grid"]
	if "hex_grid" in state: return state.hex_grid
	if "grid" in state: return state.grid
	return null

## Explicit supported footprint policy in axial coordinates. Large, Huge and
## Gargantuan bodies occupy complete radius-1, radius-2 and radius-3 disks.
static func footprint(size: String) -> Array[Vector2i]:
	var radius: int = {"tiny": 0, "small": 0, "medium": 0, "large": 1, "huge": 2, "gargantuan": 3}.get(size.to_lower(), -1)
	var cells: Array[Vector2i] = []
	if int(radius) < 0: return cells
	for q in range(-int(radius), int(radius) + 1):
		for r in range(maxi(-int(radius), -q - int(radius)), mini(int(radius), -q + int(radius)) + 1): cells.append(Vector2i(q, r))
	return cells

static func _size_at(size: Variant, index: int) -> String:
	return str(size[mini(index, size.size() - 1)]) if size is Array and not size.is_empty() else str(size)

static func _reserved_cells(reserved: Array, default_size: String) -> Array:
	var cells: Array = []
	for entry in reserved:
		var anchor: Vector2i = entry.get("hex", Vector2i.ZERO) if entry is Dictionary else entry
		var body_size := str(entry.get("size", default_size)) if entry is Dictionary else default_size
		for offset in footprint(body_size): cells.append(anchor + offset)
	return cells

## "" when this hex is a legal destination, otherwise the reason.
static func legal_error(state, origin: Vector2i, hex: Vector2i, size: String, range_hexes: int, reserved: Array = [], context_overrides: Dictionary = {}) -> String:
	if footprint(size).is_empty(): return "Body size is unknown."
	var prior_cells := _reserved_cells(reserved, size)
	if range_hexes >= 0 and (HexUtils.get_distance(origin, hex) > range_hexes or hex == origin): return "Position %s is out of placement range." % str(hex)
	var ctx := _context(state)
	ctx.merge(context_overrides, true)
	var plane := str(ctx.get("plane", PhysicalFactsRules.DEFAULT_PLANE))
	if state != null and "placement_plane" in state:
		plane = str(state.placement_plane)
	elif state != null and "caster" in state and state.caster is Character:
		plane = PhysicalFactsRules.get_plane(state.caster, ctx)
	else:
		for entity in ctx.get("players", []):
			if entity.get("hex_position") == origin:
				plane = PhysicalFactsRules.get_plane(entity.get("character"), ctx)
				break
	for cell in footprint(size):
		var destination := hex + cell
		if prior_cells.has(destination): return "Position %s overlaps another reserved footprint." % str(destination)
		for entity in ctx.get("players", []) + ctx.get("monsters", []):
			var actor: Variant = entity.get("character", entity)
			if is_same(actor, ctx.get("ignore_entity", null)): continue
			var alive: bool = actor.is_alive if actor is Character else bool(entity.get("is_alive", false))
			if not alive: continue
			var entity_hex: Vector2i = entity.get("hex_position", Vector2i(99999, 99999))
			var entity_size := PhysicalFactsRules.get_size(actor) if actor is Character else str(entity.get("size", "medium"))
			var occupied: Array = []
			for offset in footprint(entity_size): occupied.append(entity_hex + offset)
			if entity_hex != Vector2i(99999, 99999) and destination in occupied:
				return "Position %s is occupied by another creature's footprint." % str(destination)
		var space := PhysicalFactsRules.is_space_available(_grid(state), destination, size, plane, ctx)
		if not bool(space.get("available", false)): return str(space.get("reason", "No space."))
	return ""

## Batch 076 (#38 follow-up): terrain and map-bounds legality of EVERY cell of
## a size-based footprint, independent of creature occupancy. Tile presence
## (map bounds), passability/walls, room walls, plane and clearance are all
## checked; only other creatures are left out. "" when the whole footprint fits.
static func footprint_terrain_error(state, hex: Vector2i, size: String, context_overrides: Dictionary = {}) -> String:
	var ctx := context_overrides.duplicate()
	ctx["players"] = []
	ctx["monsters"] = []
	# Skips only grid.entities; the two empty lists above cover the rest.
	ctx["ignore_occupants"] = true
	return legal_error(state, hex, hex, size, -1, [], ctx)

## Legal destinations nearest first (ties by coordinate), excluding reserved ones.
static func candidates(state, origin: Vector2i, size: String, range_hexes: int, reserved: Array = [], context_overrides: Dictionary = {}) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for hex in HexUtils.get_hexes_in_range(origin, range_hexes):
		if legal_error(state, origin, hex, size, range_hexes, reserved, context_overrides).is_empty(): out.append(hex)
	out.sort_custom(func(x, y): return [HexUtils.get_distance(origin, x), x.x, x.y] < [HexUtils.get_distance(origin, y), y.x, y.y])
	return out

## Distinct destinations for count arrivals, or [] when there are not enough.
static func reserve(state, origin: Vector2i, size: Variant, range_hexes: int, count: int, reserved: Array = []) -> Array[Vector2i]:
	var taken: Array = reserved.duplicate()
	var out: Array[Vector2i] = []
	for i in count:
		var body_size := _size_at(size, i)
		var options := candidates(state, origin, body_size, range_hexes, taken)
		if options.is_empty(): return [] as Array[Vector2i]
		out.append(options[0])
		taken.append({"hex": options[0], "size": body_size})
	return out

## Recheck chosen destinations at confirmation: each still legal and distinct.
static func confirm_error(state, origin: Vector2i, size: Variant, range_hexes: int, picks: Array) -> String:
	var seen: Array = []
	for i in picks.size():
		var hex: Vector2i = picks[i]
		var body_size := _size_at(size, i)
		var e := legal_error(state, origin, hex, body_size, range_hexes, seen)
		if not e.is_empty(): return e
		seen.append({"hex": hex, "size": body_size})
	return ""

static func encode(picks: Array) -> Array:
	return picks.map(func(h): return [h.x, h.y])

static func decode(raw: Variant) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if raw is Array:
		for p in raw:
			if p is Array and p.size() == 2: out.append(Vector2i(int(p[0]), int(p[1])))
	return out
