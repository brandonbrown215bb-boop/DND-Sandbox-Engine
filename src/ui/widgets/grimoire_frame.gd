class_name GrimoireFrame
extends Node2D

## Reusable, input-transparent ornament. Layout remains owned by containers.
@export var prominent := false
var size := Vector2.ZERO

func _ready() -> void:
	var surface := get_parent() as Control
	if surface != null:
		surface.resized.connect(_follow_surface)
	_follow_surface()

func _follow_surface() -> void:
	var surface := get_parent() as Control
	if surface != null:
		size = surface.size
		queue_redraw()

func _draw() -> void:
	var profile := UiThemeProfile.current()
	var brass := profile.color("accent/primary")
	brass.a = 0.8 if prominent else 0.45
	var rect := Rect2(Vector2(3, 3), size - Vector2(6, 6))
	draw_rect(rect, brass, false, 1)
	if prominent:
		draw_rect(rect.grow(-5), Color(brass, 0.28), false, 1)
	if profile.ornament == null:
		return
	var corner_size := Vector2(36, 36) if prominent else Vector2(26, 26)
	for corner in [Vector2.ZERO, Vector2(size.x, 0), size, Vector2(0, size.y)]:
		var index := [Vector2.ZERO, Vector2(size.x, 0), size, Vector2(0, size.y)].find(corner)
		draw_set_transform(corner, index * PI / 2)
		draw_texture_rect(profile.ornament, Rect2(Vector2.ZERO, corner_size), false, brass)
	draw_set_transform(Vector2.ZERO)
