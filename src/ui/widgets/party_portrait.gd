class_name PartyPortrait
extends Control

var character: Character
var is_current := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _draw() -> void:
	if character == null: return
	var center := size / 2
	var radius := minf(size.x, size.y) / 2 - 5
	if not HexArt.draw_token(self, center, radius, {"character": character, "is_player":true}):
		draw_circle(center, radius, UiThemeProfile.current().color("surface/overlay"))
	var ring := UiThemeProfile.current().color("focus/ring" if is_current else "border/strong")
	draw_circle(center, radius + 2, ring, false, 1.5)
