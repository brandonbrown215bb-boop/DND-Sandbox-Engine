## Physical obstruction on the represented flat hex ray, independent of sight.
class_name CoverRules
extends RefCounted

const DEGREES := {"none":0, "half":1, "three_quarters":2, "total":3}

static func source_plane(source, grid: HexGrid) -> String:
	var actual: Variant = source.feature_uses.get("monster_source", source) if source is Character else source
	return PhysicalFactsRules.get_plane(actual, {"plane":grid.cover_plane if grid != null else "material"})

static func degree(origin: Vector2i, destination: Vector2i, grid: HexGrid, ray_plane: String = "") -> int:
	if grid == null or origin == destination: return 0
	var strongest := 0
	if ray_plane.is_empty(): ray_plane = grid.cover_plane
	for cell in Targeting.line_cells(origin, destination):
		if cell == origin or cell == destination or not grid.has_tile(cell): continue
		if ray_plane != grid.cover_plane: continue
		var properties: Dictionary = grid.get_tile(cell).custom_properties
		# A malformed physical declaration fails closed, never opens a ray.
		var cover := int(DEGREES.get(str(properties.get("cover", "none")), 3))
		if bool(properties.get("blocks_sight", false)): cover = 3
		strongest = maxi(strongest, cover)
	# Living creatures on an intermediate footprint supply Half Cover. Light/illusion markers do not.
	for participant in grid.cover_participants:
		var actor: Variant = participant.get("character", participant)
		if not (actor.is_alive if actor is Character else bool(actor.get("is_alive", false))): continue
		if PhysicalFactsRules.get_plane(actor, {"plane":grid.cover_plane}) != ray_plane: continue
		var position: Vector2i = participant.get("hex_position", Vector2i.ZERO)
		if position == origin or position == destination: continue
		var size: String = actor.get_creature_size() if actor is Character else str(actor.get("size", "Medium"))
		for offset in PlacementRules.footprint(size):
			var cell: Vector2i = position + offset
			if cell != origin and cell != destination and cell in Targeting.line_cells(origin, destination): strongest = maxi(strongest, 1)
	return strongest

static func blocks_target(origin: Vector2i, destination: Vector2i, grid: HexGrid, ray_plane: String = "") -> bool:
	return degree(origin, destination, grid, ray_plane) == 3

static func effect_origin(cast: SpellCastContext, destination: Vector2i) -> Vector2i:
	if cast.target_type not in ["area", "cone"] and str(cast.spell.get("target", "")) != "cone": return cast.spell_origin
	if str(cast.area_selection.get("shape", "")) in ["cone", "cube", "emanation"] or str(cast.spell.get("target", "")) == "cone": return cast.spell_origin
	if str(cast.area_selection.get("shape", "")) == "line": return cast.target_coord
	var centers: Array = [cast.target_coord]
	if int(cast.spell.get("area_point_count", 1)) > 1: centers.append_array(cast.command_selection)
	var best := cast.target_coord
	var best_degree := 4
	for center in centers:
		if centers.size() > 1 and HexUtils.get_distance(center, destination) > int(cast.area_selection.get("radius", 2)): continue
		var cover := degree(center, destination, cast.grid, source_plane(cast.caster, cast.grid))
		if cover < best_degree:
			best = center
			best_degree = cover
	return best

## Room geometry is refreshed by LocalRoomCombat before offers and resolution.
## A cover token describes the obstacle's occupied cross-section on this ray;
## it is never a creature status or an assertion from an action command.
static func room_degree(room: Dictionary, cell: Vector2i) -> String:
	var strongest := 0
	if LocalRoomRules.has_wall(room, cell):
		var height := LocalRoomRules.wall_height_feet(room, cell)
		strongest = 3 if height >= 5 else 2 if height >= 4 else 1 if height >= 3 else 0
		for wall in room.get("wall_details", []):
			if LocalRoomRules.coord(wall.get("position", [])) == cell and wall.has("cover"):
				strongest = maxi(strongest, int(DEGREES.get(str(wall.cover), 3)))
	for object in room.get("objects", []):
		if bool(object.get("removed", false)) or int(object.get("hp", 1)) <= 0: continue
		if PhysicalFactsRules.get_plane(object, room) != PhysicalFactsRules.get_plane(room): continue
		if LocalRoomRules.coord(object.position) != cell or not ContainmentRules.relation(room, "object", str(object.id)).is_empty(): continue
		if str(object.get("kind", "")) == "door":
			if not bool(object.get("open", false)): strongest = 3
		elif object.has("cover"):
			strongest = maxi(strongest, int(DEGREES.get(str(object.cover), 3)))
	return DEGREES.find_key(strongest)

static func exemption_error(source: Dictionary) -> String:
	if not source.has("ignore_cover"): return ""
	if not source.ignore_cover is Array or source.ignore_cover.is_empty(): return "ignore_cover must list partial cover degrees."
	var seen := []
	for token in source.ignore_cover:
		if token not in ["half", "three_quarters"] or token in seen: return "ignore_cover accepts distinct half/three_quarters degrees only."
		seen.append(token)
	return ""

static func bonus(decisions: Dictionary, source: Dictionary = {}, saving_throw: bool = false) -> int:
	var spatial: Dictionary = decisions.get("spell_visibility", decisions.get("weapon_visibility", {}))
	var grid: HexGrid = spatial.get("grid")
	if grid == null: return 0
	var origin: Vector2i = spatial.get("effect_origin", spatial.get("caster_position", Vector2i.ZERO))
	var destination: Vector2i = spatial.get("target_position", Vector2i.ZERO)
	var cover := degree(origin, destination, grid, str(spatial.get("effect_plane", grid.cover_plane)))
	if saving_throw and bool(source.get("ignore_cover_on_save", false)): return 0
	if ("half" if cover == 1 else "three_quarters" if cover == 2 else "total") in source.get("ignore_cover", []): return 0
	return 2 if cover == 1 else 5 if cover == 2 else 0

static func save_bonus(ability: String, decisions: Dictionary) -> int:
	return bonus(decisions, decisions.get("cover_source", {}), true) if ability.to_upper() == "DEX" and decisions.has("cover_source") else 0
