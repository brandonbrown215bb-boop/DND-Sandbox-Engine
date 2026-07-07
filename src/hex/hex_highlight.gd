## Hex Highlight
## Visual overlay for hex tiles showing movement range, attack range, etc.
## Drawn as a child of HexGrid.
class_name HexHighlight
extends Node2D

## Different highlight categories for layered rendering.
enum HighlightType {
	MOVEMENT,    # Blue - where the character can move
	ATTACK,      # Red - where attacks can reach
	SPELL,       # Purple - spell targeting area
	PATH,        # Yellow - the selected movement path
	SELECTED,    # White - the currently selected hex
}

## Colors for each highlight type.
const HIGHLIGHT_COLORS := {
	HighlightType.MOVEMENT: Color(0.3, 0.5, 0.9, 0.3),
	HighlightType.ATTACK: Color(0.9, 0.2, 0.2, 0.3),
	HighlightType.SPELL: Color(0.7, 0.3, 0.9, 0.3),
	HighlightType.PATH: Color(0.9, 0.8, 0.2, 0.4),
	HighlightType.SELECTED: Color(1.0, 1.0, 1.0, 0.5),
}

## Border colors for each highlight type (brighter).
const HIGHLIGHT_BORDER_COLORS := {
	HighlightType.MOVEMENT: Color(0.3, 0.5, 0.9, 0.7),
	HighlightType.ATTACK: Color(0.9, 0.2, 0.2, 0.7),
	HighlightType.SPELL: Color(0.7, 0.3, 0.9, 0.7),
	HighlightType.PATH: Color(0.9, 0.8, 0.2, 0.8),
	HighlightType.SELECTED: Color(1.0, 1.0, 1.0, 0.9),
}

## Active highlights: type -> Array[Vector2i]
var _highlights: Dictionary = {}


## Set the highlighted hexes for a given type.
func set_highlight(type: HighlightType, hexes: Array[Vector2i]) -> void:
	_highlights[type] = hexes
	queue_redraw()


## Clear a specific highlight type.
func clear_highlight(type: HighlightType) -> void:
	_highlights.erase(type)
	queue_redraw()


## Clear all highlights.
func clear_all() -> void:
	_highlights.clear()
	queue_redraw()


## Check if any hex in a highlight type contains the given coordinate.
func is_highlighted(coord: Vector2i, type: HighlightType) -> bool:
	if type not in _highlights:
		return false
	return coord in _highlights[type]


func _draw() -> void:
	# Draw highlights by type (order matters for layering)
	var draw_order := [
		HighlightType.MOVEMENT,
		HighlightType.ATTACK,
		HighlightType.SPELL,
		HighlightType.PATH,
		HighlightType.SELECTED,
	]

	for type in draw_order:
		if type not in _highlights:
			continue
		var fill_color: Color = HIGHLIGHT_COLORS[type]
		var border_color: Color = HIGHLIGHT_BORDER_COLORS[type]
		for coord in _highlights[type]:
			var center := HexUtils.hex_to_pixel(coord)
			var points := _get_hex_points(center, HexUtils.HEX_SIZE - 2.0)
			draw_colored_polygon(points, fill_color)
			for i in 6:
				draw_line(points[i], points[(i + 1) % 6], border_color, 2.0)


## Generate the pointy-top hex polygon vertices.
func _get_hex_points(center: Vector2, size: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in 6:
		var angle := deg_to_rad(60.0 * i - 30.0)
		points.append(center + Vector2(cos(angle), sin(angle)) * size)
	return points
