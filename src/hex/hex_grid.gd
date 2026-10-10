## Hex Grid
## Manages the grid of hex tiles, providing access by coordinate, rendering,
## and integration with HexUtils for pathfinding and queries.
class_name HexGrid
extends Node2D

const SURFACE_LABELS := {"acid": "ACID", "mud": "MUD", "snow": "SNOW", "quicksand": "QUICK", "lava": "LAVA"}
const SURFACE_TINTS := {
	"acid": Color(0.55, 0.82, 0.24, 0.58),
	"mud": Color(0.36, 0.27, 0.17, 0.62),
	"snow": Color(0.69, 0.84, 0.91, 0.65),
	"quicksand": Color(0.80, 0.62, 0.33, 0.64),
	"lava": Color(0.92, 0.24, 0.08, 0.68),
}

## Emitted when a hex tile is clicked.
signal hex_clicked(coord: Vector2i)

## Emitted when the mouse hovers over a new hex.
signal hex_hovered(coord: Vector2i)

## All tiles in the grid, keyed by axial coordinate.
var tiles: Dictionary = {}  # Dictionary[Vector2i, HexTile]

## Currently highlighted hexes (for movement range, attack range, etc.)
var _highlighted_hexes: Dictionary = {}  # Dictionary[Vector2i, Color]

## The hex the mouse is currently hovering over.
var _hovered_hex: Vector2i = Vector2i(99999, 99999)

## Outline color for the hovered hex.
var hover_color := Color(1.0, 0.85, 0.4, 0.85)

## Width of hex outlines.
var outline_width := 2.0

## Entities currently on the grid (players, monsters) to be drawn.
## Each is a Dictionary: {"hex_position": Vector2i, "color": Color, "is_player": bool}
var entities: Array[Dictionary] = []
var selected_object_id := ""

## Source-keyed areas that add one movement point to each affected hex.
var difficult_terrain_sources: Dictionary = {}

## Source-keyed absolute movement costs for effects such as Plant Growth.
var movement_cost_override_sources: Dictionary = {}


func _ready() -> void:
	# Ensure we receive input events
	set_process_input(true)


func _unhandled_input(event: InputEvent) -> void:
	if not is_processing_input() or ModalSurface.blocks_world():
		return
	var shell := get_parent().find_child("Root", true, false) as VttShell
	if shell != null and not shell.allows_world_point(get_viewport().get_mouse_position()):
		return
	if event is InputEventMouseMotion:
		var local_pos := get_local_mouse_position()
		var hex_coord := HexUtils.pixel_to_hex(local_pos)
		if hex_coord != _hovered_hex:
			_hovered_hex = hex_coord
			hex_hovered.emit(hex_coord)
			queue_redraw()

	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			var local_pos := get_local_mouse_position()
			var hex_coord := HexUtils.pixel_to_hex(local_pos)
			if hex_coord in tiles:
				hex_clicked.emit(hex_coord)


func _draw() -> void:
	# Draw all tiles
	for coord in tiles:
		var tile: HexTile = tiles[coord]
		var center := HexUtils.hex_to_pixel(coord)
		var points := _get_hex_points(center, HexUtils.HEX_SIZE - 1.0)
		if not HexArt.draw_tile(self, center, HexUtils.HEX_SIZE - 1.0, tile, points):
			_draw_hex_filled(center, HexUtils.HEX_SIZE - 1.0, tile.get_color(), tile.is_revealed)
		var surface := str(tile.custom_properties.get("surface", "ground"))
		if tile.is_revealed and SURFACE_LABELS.has(surface):
			draw_colored_polygon(points, SURFACE_TINTS[surface])
			var surface_text := str(SURFACE_LABELS[surface])
			var surface_font := ThemeDB.fallback_font
			var surface_size := surface_font.get_string_size(surface_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 9)
			draw_string(surface_font, center + Vector2(-surface_size.x / 2.0, 3.0), surface_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 9, Color(0.08, 0.07, 0.05))

		if bool(tile.custom_properties.get("blocks_movement", false)):
			draw_colored_polygon(points, Color(0.21, 0.22, 0.25))
		if str(tile.custom_properties.get("ambient_illumination", "bright")) == "dark":
			var illumination := CombatPerception.illumination_level_at(self, coord)
			var darkness_alpha := 0.62 if illumination == "dark" else 0.2 if illumination == "dim" else 0.0
			if darkness_alpha > 0.0:
				draw_colored_polygon(points, Color(0.015, 0.02, 0.045, darkness_alpha))
		var elevation := int(tile.custom_properties.get("elevation_feet", 0))
		if elevation != 0 and tile.is_revealed:
			var elevation_text := "%+d ft" % elevation
			var elevation_font := ThemeDB.fallback_font
			var elevation_size := elevation_font.get_string_size(elevation_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 10)
			draw_string(elevation_font, center + Vector2(-elevation_size.x / 2.0, 22.0), elevation_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 10, Color(0.96, 0.91, 0.72))
		if tile.custom_properties.has("wall_height_feet") and tile.is_revealed:
			var wall_text := "%s %d ft" % [str(tile.custom_properties.get("wall_material", "stone")).capitalize(), int(tile.custom_properties["wall_height_feet"])]
			var wall_font := ThemeDB.fallback_font
			var wall_size := wall_font.get_string_size(wall_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 9)
			draw_string(wall_font, center + Vector2(-wall_size.x / 2.0, -16.0), wall_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 9, Color(0.8, 0.83, 0.88))
		# Draw location name if present
		if tile.is_revealed and not tile.location_name.is_empty():
			# Name rendering is handled by Label nodes; this is just the hex shape
			pass

	# Draw highlights (movement range, attack range, etc.)
	for coord in _difficult_terrain_hexes():
		if coord in tiles:
			var center := HexUtils.hex_to_pixel(coord)
			var points := _get_hex_points(center, HexUtils.HEX_SIZE - 1.0)
			HexArt.draw_highlight(self, center, HexUtils.HEX_SIZE - 1.0, Color(0.55, 0.38, 0.72, 0.38), 1.5, points)
	for coord in _movement_cost_override_hexes():
		if coord in tiles:
			var center := HexUtils.hex_to_pixel(coord)
			var points := _get_hex_points(center, HexUtils.HEX_SIZE - 1.0)
			HexArt.draw_highlight(self, center, HexUtils.HEX_SIZE - 1.0, Color(0.28, 0.62, 0.34, 0.38), 1.5, points)
	for coord in _highlighted_hexes:
		var center := HexUtils.hex_to_pixel(coord)
		var color: Color = _highlighted_hexes[coord]
		var points := _get_hex_points(center, HexUtils.HEX_SIZE - 1.0)
		HexArt.draw_highlight(self, center, HexUtils.HEX_SIZE - 1.0, color, outline_width + 1.0, points)

	# Draw hover outline
	if _hovered_hex in tiles:
		var center := HexUtils.hex_to_pixel(_hovered_hex)
		_draw_hex_outline(center, HexUtils.HEX_SIZE - 1.0, hover_color, outline_width)

	# Draw entities
	# Objects always precede tokens, regardless of insertion order. Keep their
	# outer edge visible when an actor occupies the same space.
	# Collect actor entities per hex coordinate to detect shared spaces
	var actors_by_coord: Dictionary = {}
	for entity in entities:
		if entity.has("world_object"):
			continue
		var coord: Vector2i = entity.get("hex_position", Vector2i.ZERO)
		if not actors_by_coord.has(coord):
			actors_by_coord[coord] = []
		actors_by_coord[coord].append(entity)

	for entity in entities:
		if not entity.has("world_object"):
			continue
		var coord: Vector2i = entity.get("hex_position", Vector2i.ZERO)
		if coord not in tiles or not tiles[coord].is_revealed:
			continue
		var has_actor: bool = actors_by_coord.has(coord) and not actors_by_coord[coord].is_empty()
		var object: Dictionary = entity["world_object"]
		var position := HexUtils.hex_to_pixel(coord)
		var marker := Rect2(position - Vector2(17, 15), Vector2(34, 30))
		var marker_color: Color = Color(0.62, 0.43, 0.22) if object.get("locked", false) else Color(0.8, 0.7, 0.4)
		if has_actor:
			# When an actor occupies the same hex, draw the object marker as a floor
			# indicator (faint fill with 2px border) so the actor token remains primary.
			draw_rect(marker, Color(marker_color.r, marker_color.g, marker_color.b, 0.35))
			draw_rect(marker, marker_color, false, 2.0)
		else:
			draw_rect(marker, marker_color)
		if bool(object.get("burning", false)):
			draw_rect(marker.grow(2), Color(1.0, 0.32, 0.08), false, 3)
			var fire_pos := position + Vector2(-12, 24 if has_actor else 27)
			draw_string(ThemeDB.fallback_font, fire_pos, "FIRE", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1.0, 0.6, 0.2))
		if coord == _hovered_hex or str(object.get("id", "")) == selected_object_id:
			var name_text := str(object.get("name", "Object"))
			var label_size := ThemeDB.fallback_font.get_string_size(name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12)
			# When an actor is present, offset the object label below the hex (y + 28)
			# so it does not collide with the character's HP bar (y - 22) or intent preview (y - 34).
			var label_position := object_label_position(position, label_size.x, has_actor)
			draw_rect(Rect2(label_position + Vector2(-3, -13), label_size + Vector2(6, 16)), Color(0.04, 0.04, 0.06, 0.95))
			draw_rect(Rect2(label_position + Vector2(-3, -13), label_size + Vector2(6, 16)), marker_color, false, 1.0)
			draw_string(ThemeDB.fallback_font, label_position, name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)
	var coords_count := {}
	var coords_index := {}
	for entity in entities:
		if entity.has("world_object"):
			continue
		var coord: Vector2i = entity.get("hex_position", Vector2i.ZERO)
		coords_count[coord] = coords_count.get(coord, 0) + 1
	
	for entity in entities:
		if entity.has("world_object"):
			continue
		var coord: Vector2i = entity.get("hex_position", Vector2i.ZERO)
		if coord in tiles:
			var tile: HexTile = tiles[coord]
			if not tile.is_revealed:
				continue
			
			var center := HexUtils.hex_to_pixel(coord)
			var count: int = coords_count[coord]
			if count > 1:
				var idx: int = coords_index.get(coord, 0)
				coords_index[coord] = idx + 1
				var angle := (2.0 * PI / count) * idx
				center += Vector2(cos(angle), sin(angle)) * 12.0
			
			if not HexArt.draw_token(self, center, 13.0, entity):
				var color: Color = entity.get("color", Color.WHITE)
				draw_circle(center, 12.0, color)
				draw_circle(center, 12.0, Color.BLACK, false, 2.0)

				var is_player: bool = entity.get("is_player", false)
				if not is_player:
					draw_circle(center, 5.0, Color.DARK_RED)
				else:
					draw_circle(center, 5.0, Color.WHITE)
				if bool(entity.get("is_steed", false)):
					draw_string(ThemeDB.fallback_font, center + Vector2(-3.5, 3.5), "S", HORIZONTAL_ALIGNMENT_LEFT, 8.0, 9, Color.BLACK)

			# --- HP bar above the token ---
			var hp_cur: int = -1
			var hp_max: int = -1
			if entity.has("character"):
				var ch: Character = entity["character"]
				hp_cur = ch.current_hp
				hp_max = ch.max_hp
			elif entity.has("monster"):
				var md: Dictionary = entity["monster"]
				hp_cur = int(md.get("current_hp", -1))
				hp_max = int(md.get("max_hp", -1))
			if hp_max > 0 and hp_cur >= 0:
				var bar_w: float = 26.0
				var bar_h: float = 4.0
				var bar_y: float = center.y - 22.0
				var bar_x: float = center.x - bar_w / 2.0
				var frac: float = clamp(float(hp_cur) / float(hp_max), 0.0, 1.0)
				# Background
				draw_rect(Rect2(bar_x, bar_y, bar_w, bar_h), Color(0.1, 0.1, 0.12, 0.85))
				# Fill (green -> yellow -> red by fraction)
				var hp_color: Color
				if frac > 0.5:
					hp_color = Color(0.3, 0.85, 0.35)
				elif frac > 0.25:
					hp_color = Color(0.95, 0.8, 0.2)
				else:
					hp_color = Color(0.9, 0.25, 0.2)
				draw_rect(Rect2(bar_x, bar_y, bar_w * frac, bar_h), hp_color)
				# Outline
				draw_rect(Rect2(bar_x, bar_y, bar_w, bar_h), Color(0.0, 0.0, 0.0, 0.9), false, 1.0)


			# Retrieve active conditions
			var entity_conditions := {}
			if entity.has("character"):
				var c: Character = entity["character"]
				entity_conditions = c.conditions
			elif entity.has("player_index"):
				var player_idx: int = entity["player_index"]
				var player_dict := PlayerManager.get_player(player_idx)
				var char_data: Character = player_dict.get("character")
				if char_data != null:
					entity_conditions = char_data.conditions
			elif entity.has("monster"):
				var m: Dictionary = entity["monster"]
				entity_conditions = m.get("conditions", {})

			# Draw condition indicators
			if not entity_conditions.is_empty():
				var cond_names = entity_conditions.keys()
				var cond_count = cond_names.size()
				for c_idx in cond_count:
					var cond_name: String = cond_names[c_idx]
					var dot_color := Color.GRAY
					match cond_name:
						"poisoned": dot_color = Color.GREEN
						"blinded": dot_color = Color.BLACK
						"stunned": dot_color = Color.YELLOW
						"prone": dot_color = Color.SADDLE_BROWN
						"hidden": dot_color = Color.DARK_ORCHID
						"dodging": dot_color = Color.SKY_BLUE
						"disengaging": dot_color = Color.AQUAMARINE
					
					var offset_angle: float = (2.0 * PI / cond_count) * c_idx
					var dot_pos := center + Vector2(cos(offset_angle), sin(offset_angle)) * 14.0
					draw_circle(dot_pos, 3.5, dot_color)
					draw_circle(dot_pos, 3.5, Color.BLACK, false, 1.0)

					# --- Enemy intent preview (P1 readability) ---
					var intent_text: String = ""
					if entity.has("monster"):
						var mdict: Dictionary = entity["monster"]
						intent_text = str(mdict.get("intent_text", ""))
					elif entity.has("intent"):
						intent_text = entity.get("intent", "")
					if not intent_text.is_empty():
						var fnt := ThemeDB.fallback_font
						var fs := 11
						var tpos := Vector2(center.x, center.y - 34.0)
						var tsize := fnt.get_string_size(intent_text, HORIZONTAL_ALIGNMENT_CENTER, -1, fs)
						# Badge background
						draw_rect(Rect2(tpos.x - tsize.x / 2.0 - 3.0, tpos.y - 2.0, tsize.x + 6.0, fs + 4.0), Color(0.08, 0.08, 0.12, 0.85))
						draw_rect(Rect2(tpos.x - tsize.x / 2.0 - 3.0, tpos.y - 2.0, tsize.x + 6.0, fs + 4.0), Color(1.0, 0.5, 0.3, 0.9), false, 1.0)
						draw_string(fnt, tpos, intent_text, HORIZONTAL_ALIGNMENT_CENTER, -1, fs, Color(1.0, 0.8, 0.6))


## Generate the pointy-top hex polygon vertices.
func _get_hex_points(center: Vector2, size: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in 6:
		var angle := deg_to_rad(60.0 * i - 30.0)  # Pointy-top: first vertex at -30°
		points.append(center + Vector2(cos(angle), sin(angle)) * size)
	return points


## Draw a filled hexagon.
func _draw_hex_filled(center: Vector2, size: float, color: Color, revealed: bool) -> void:
	if not revealed:
		# Fog of war: dark hex
		color = Color(0.12, 0.12, 0.15, 1.0)
	var points := _get_hex_points(center, size)
	draw_colored_polygon(points, color)
	# Subtle border
	var border_color := color.darkened(0.3)
	for i in 6:
		draw_line(points[i], points[(i + 1) % 6], border_color, 1.0)


## Draw a hex outline (no fill).
func _draw_hex_outline(center: Vector2, size: float, color: Color, width: float) -> void:
	var points := _get_hex_points(center, size)
	for i in 6:
		draw_line(points[i], points[(i + 1) % 6], color, width)


## Load the grid from an array of tile data dictionaries (from campaign JSON).
func load_from_data(tile_data_array: Array) -> void:
	tiles.clear()
	for data in tile_data_array:
		var tile := HexTile.from_dict(data)
		tiles[tile.coord] = tile
	queue_redraw()


## Get the tile at a given coordinate, or null if none exists.
func get_tile(coord: Vector2i) -> HexTile:
	return tiles.get(coord)


## Check if a coordinate has a tile.
func has_tile(coord: Vector2i) -> bool:
	return coord in tiles


## Add a tile to the grid.
func add_tile(tile: HexTile) -> void:
	tiles[tile.coord] = tile
	queue_redraw()


## Remove a tile from the grid.
func remove_tile(coord: Vector2i) -> void:
	tiles.erase(coord)
	queue_redraw()


func clear_entities() -> void:
	entities.clear()
	queue_redraw()


func add_entity(entity: Dictionary) -> void:
	entities.append(entity)
	queue_redraw()


func map_to_local(coord: Vector2i) -> Vector2:
	return HexUtils.hex_to_pixel(coord)


## Set the highlight for specific hexes (e.g., movement range).
func set_highlights(hexes: Dictionary) -> void:
	_highlighted_hexes = hexes
	queue_redraw()


## Clear all highlights.
func clear_highlights() -> void:
	_highlighted_hexes.clear()
	queue_redraw()


## Add a single highlight.
func add_highlight(coord: Vector2i, color: Color) -> void:
	_highlighted_hexes[coord] = color
	queue_redraw()


## Clear a single highlighted hex (used for path-preview teardown).
func clear_highlight(coord: Vector2i) -> void:
	if _highlighted_hexes.has(coord):
		_highlighted_hexes.erase(coord)
		queue_redraw()


## Number of currently highlighted hexes.
func get_highlight_count() -> int:
	return _highlighted_hexes.size()


## Reveal a tile (remove fog of war).
func reveal_tile(coord: Vector2i) -> void:
	if coord in tiles:
		tiles[coord].is_revealed = true
		queue_redraw()


## Reveal all tiles within a radius of a center hex.
func reveal_radius(center: Vector2i, radius: int) -> void:
	var hexes := HexUtils.get_hexes_in_range(center, radius)
	for hex_coord in hexes:
		if hex_coord in tiles:
			tiles[hex_coord].is_revealed = true
			tiles[hex_coord].is_visible = true
	queue_redraw()


## Reset visibility (is_visible) for all tiles. Called at start of each turn
## before recalculating what's currently visible.
func reset_visibility() -> void:
	for coord in tiles:
		tiles[coord].is_visible = false


## Check if a hex is passable (for pathfinding callback).
func is_hex_passable(coord: Vector2i) -> bool:
	if coord not in tiles:
		return false
	if bool(tiles[coord].custom_properties.get("blocks_movement", false)):
		return false
	return tiles[coord].is_passable()


## Get the movement cost of a hex (for pathfinding callback).
func get_hex_cost(coord: Vector2i, ignore_difficult_terrain: bool = false) -> float:
	if coord not in tiles:
		return INF
	var terrain_cost: float = tiles[coord].get_movement_cost() + (1.0 if not ignore_difficult_terrain and is_difficult_terrain(coord) else 0.0)
	var override_cost := _movement_cost_override_for(coord)
	return maxf(terrain_cost, override_cost)


func add_difficult_terrain(source_id: String, coords: Array[Vector2i]) -> void:
	if source_id.is_empty():
		return
	difficult_terrain_sources[source_id] = coords.duplicate()
	queue_redraw()


func remove_difficult_terrain(source_id: String) -> void:
	if difficult_terrain_sources.erase(source_id):
		queue_redraw()


func add_movement_cost_override(source_id: String, coords: Array[Vector2i], cost: float) -> void:
	if source_id.is_empty() or cost <= 0.0:
		return
	var costs: Dictionary = {}
	for coord in coords:
		costs[coord] = cost
	movement_cost_override_sources[source_id] = costs
	queue_redraw()


func remove_movement_cost_override(source_id: String) -> void:
	if movement_cost_override_sources.erase(source_id):
		queue_redraw()


func _movement_cost_override_for(coord: Vector2i) -> float:
	var result := 0.0
	for costs in movement_cost_override_sources.values():
		result = maxf(result, float(costs.get(coord, 0.0)))
	return result


func _movement_cost_override_hexes() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for costs in movement_cost_override_sources.values():
		for coord in costs:
			if coord not in result:
				result.append(coord)
	return result


func is_difficult_terrain(coord: Vector2i) -> bool:
	for coords in difficult_terrain_sources.values():
		if coord in coords:
			return true
	return false


func _difficult_terrain_hexes() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for coords in difficult_terrain_sources.values():
		for coord in coords:
			if coord not in result:
				result.append(coord)
	return result


## Find a path between two hexes on this grid.
func find_path(start: Vector2i, goal: Vector2i) -> Array[Vector2i]:
	return HexUtils.find_path(start, goal, is_hex_passable, get_hex_cost)


## Get all reachable hexes from a position within a movement budget.
func get_reachable(start: Vector2i, budget: float) -> Dictionary:
	return HexUtils.get_reachable(start, budget, is_hex_passable, get_hex_cost)


## Get all tiles that are starting positions.
func get_start_tiles() -> Array[HexTile]:
	var starts: Array[HexTile] = []
	for coord in tiles:
		if tiles[coord].is_start:
			starts.append(tiles[coord])
	return starts


## Generate a simple procedural hex map (for testing or procedural campaigns).
func generate_procedural(width: int, height: int) -> void:
	tiles.clear()
	var terrain_weights := {
		HexTile.TerrainType.PLAINS: 40,
		HexTile.TerrainType.FOREST: 25,
		HexTile.TerrainType.MOUNTAIN: 15,
		HexTile.TerrainType.WATER: 10,
		HexTile.TerrainType.SWAMP: 5,
		HexTile.TerrainType.DESERT: 5,
	}

	var total_weight := 0
	for w in terrain_weights.values():
		total_weight += w

	for r in range(-height / 2, height / 2 + 1):
		var r_offset := int(floor(float(r) / 2.0))
		for q in range(-r_offset - width / 2, -r_offset + width / 2 + 1):
			var tile := HexTile.new()
			tile.coord = Vector2i(q, r)

			# Weighted random terrain selection
			var roll := randi_range(1, total_weight)
			var cumulative := 0
			for terrain_type in terrain_weights:
				cumulative += terrain_weights[terrain_type]
				if roll <= cumulative:
					tile.terrain = terrain_type
					break

			tiles[tile.coord] = tile

	# Set center tile as start
	if Vector2i.ZERO in tiles:
		tiles[Vector2i.ZERO].is_start = true
		tiles[Vector2i.ZERO].terrain = HexTile.TerrainType.TOWN
		tiles[Vector2i.ZERO].location_name = "Starting Town"

	queue_redraw()


static func object_label_position(hex_pixel: Vector2, label_width: float, has_actor: bool) -> Vector2:
	return hex_pixel + Vector2(-label_width / 2.0, 28.0 if has_actor else -32.0)
