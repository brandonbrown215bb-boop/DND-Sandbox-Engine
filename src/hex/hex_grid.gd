## Hex Grid
## Manages the grid of hex tiles, providing access by coordinate, rendering,
## and integration with HexUtils for pathfinding and queries.
class_name HexGrid
extends Node2D

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
var hover_color := Color(1.0, 1.0, 1.0, 0.7)

## Width of hex outlines.
var outline_width := 2.0

## Entities currently on the grid (players, monsters) to be drawn.
## Each is a Dictionary: {"hex_position": Vector2i, "color": Color, "is_player": bool}
var entities: Array[Dictionary] = []


func _ready() -> void:
	# Ensure we receive input events
	set_process_input(true)


func _input(event: InputEvent) -> void:
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
		_draw_hex_filled(center, HexUtils.HEX_SIZE - 1.0, tile.get_color(), tile.is_revealed)

		# Draw location name if present
		if tile.is_revealed and not tile.location_name.is_empty():
			# Name rendering is handled by Label nodes; this is just the hex shape

			pass

	# Draw highlights (movement range, attack range, etc.)
	for coord in _highlighted_hexes:
		var center := HexUtils.hex_to_pixel(coord)
		var color: Color = _highlighted_hexes[coord]
		_draw_hex_outline(center, HexUtils.HEX_SIZE - 1.0, color, outline_width + 1.0)

	# Draw hover outline
	if _hovered_hex in tiles:
		var center := HexUtils.hex_to_pixel(_hovered_hex)
		_draw_hex_outline(center, HexUtils.HEX_SIZE - 1.0, hover_color, outline_width)

	# Draw entities
	var coords_count := {}
	var coords_index := {}
	for entity in entities:
		var coord: Vector2i = entity.get("hex_position", Vector2i.ZERO)
		coords_count[coord] = coords_count.get(coord, 0) + 1
	
	for entity in entities:
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
			
			var color: Color = entity.get("color", Color.WHITE)
			draw_circle(center, 12.0, color)
			draw_circle(center, 12.0, Color.BLACK, false, 2.0)
			
			var is_player: bool = entity.get("is_player", false)
			if not is_player:
				draw_circle(center, 5.0, Color.DARK_RED)
			else:
				draw_circle(center, 5.0, Color.WHITE)

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
						intent_text = mdict.get("intent", "")
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
	return tiles[coord].is_passable()


## Get the movement cost of a hex (for pathfinding callback).
func get_hex_cost(coord: Vector2i) -> float:
	if coord not in tiles:
		return INF
	return tiles[coord].get_movement_cost()


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
