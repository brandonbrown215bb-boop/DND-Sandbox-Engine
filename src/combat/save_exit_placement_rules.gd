## S-121: settle a successful save's required exit before applying its result.
class_name SaveExitPlacementRules
extends RefCounted

const KEYS := ["range_hexes", "choose", "no_space_outcome", "clearance_feet"]
const NO_SPACE_OUTCOMES := ["failure", "preserve"]

static func policy_error(value: Variant) -> String:
	if not value is Dictionary: return "save_exit_placement must be an object."
	for key in value:
		if str(key) not in KEYS: return "save_exit_placement has unknown field '%s'." % str(key)
	if not value.has("no_space_outcome") or str(value.no_space_outcome) not in NO_SPACE_OUTCOMES:
		return "save_exit_placement requires no_space_outcome failure or preserve."
	if value.has("range_hexes") and not CreatedActorRules._int(value.range_hexes, 0, 24):
		return "save_exit_placement range_hexes must be 0-24."
	if value.has("choose") and not value.choose is bool: return "save_exit_placement choose must be a boolean."
	if value.has("clearance_feet") and (not value.clearance_feet is int or int(value.clearance_feet) < 0):
		return "save_exit_placement clearance_feet must be a non-negative integer."
	return ""

static func actor_position(host: SpellCastContext, actor) -> Variant:
	if host == null: return null
	for player in host.players:
		var participant = player.get("character")
		if actor is Character and participant is Character and participant == actor: return player.get("hex_position", null)
	if actor is Character and not host.ground_room.is_empty():
		var saved: Variant = host.ground_room.get("party_positions", {}).get(actor.character_id, null)
		if saved is Array and saved.size() >= 2: return Vector2i(int(saved[0]), int(saved[1]))
	for monster in host.monsters:
		if actor is Dictionary and monster is Dictionary and is_same(monster, actor): return monster.get("hex_position", null)
	return null

static func _legal_error(host: SpellCastContext, actor, origin: Vector2i, hex: Vector2i, size: String, plane: String, clearance: int) -> String:
	var room: Dictionary = host.ground_room if not host.ground_room.is_empty() else LocalRoomCombat.room()
	if not room.is_empty() and PhysicalFactsRules.get_plane(room) != plane: return "The represented room is on a different plane."
	var state := {"_placement_grid": host.grid, "_placement_players": host.players, "monsters": host.monsters, "room": room, "plane": plane, "placement_plane": plane}
	return PlacementRules.legal_error(state, origin, hex, size, -1, [], {"ignore_entity": actor, "clearance_feet": clearance})

static func candidates(host: SpellCastContext, actor, origin: Vector2i, size: String, plane: String, policy: Dictionary) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var reach := int(policy.get("range_hexes", 1))
	for hex in HexUtils.get_hexes_in_range(origin, reach):
		if hex == origin: continue
		if _legal_error(host, actor, origin, hex, size, plane, int(policy.get("clearance_feet", 0))).is_empty(): result.append(hex)
	result.sort_custom(func(a, b): return [HexUtils.get_distance(origin, a), a.x, a.y] < [HexUtils.get_distance(origin, b), b.x, b.y])
	return result

static func chosen_error(host: SpellCastContext, actor, origin: Vector2i, hex: Vector2i, size: String, plane: String, policy: Dictionary) -> String:
	if HexUtils.get_distance(origin, hex) > int(policy.get("range_hexes", 1)): return "The chosen exit is outside the declared range."
	return _legal_error(host, actor, origin, hex, size, plane, int(policy.get("clearance_feet", 0)))
