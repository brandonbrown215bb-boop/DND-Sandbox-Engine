## Camera Controller
## Handles panning (drag/keys), zoom (wheel), and centering on target positions.
class_name CameraController
extends Camera2D

@export var pan_speed := 500.0
@export var zoom_speed := 0.1
@export var min_zoom := 0.5
@export var max_zoom := 2.0

var _drag_start_pos := Vector2.ZERO
var _is_dragging := false
var target_position: Vector2

func _ready() -> void:
	target_position = position

func _process(delta: float) -> void:
	if _is_dragging and not Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE) and not Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		_is_dragging = false
	if ModalSurface.blocks_world():
		_is_dragging = false
		return
	var focus := get_viewport().gui_get_focus_owner()
	if focus is LineEdit or focus is TextEdit:
		return
	# WASD / Arrow keys panning
	var input_dir := Vector2.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		input_dir.y -= 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		input_dir.y += 1
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		input_dir.x -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		input_dir.x += 1
	
	if input_dir != Vector2.ZERO:
		target_position += input_dir.normalized() * pan_speed * delta / zoom.x
	
	# Smooth follow target position
	position = position.lerp(target_position, 0.15)

func _unhandled_input(event: InputEvent) -> void:
	if ModalSurface.blocks_world():
		return
	var shell := get_parent().find_child("Root", true, false) as VttShell
	if shell != null and not shell.allows_world_point(get_viewport().get_mouse_position()):
		return
	# Drag panning (Middle Mouse Button or Right Mouse Button)
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_MIDDLE or mb.button_index == MOUSE_BUTTON_RIGHT:
			if mb.pressed:
				_drag_start_pos = get_local_mouse_position()
				_is_dragging = true
			else:
				_is_dragging = false
		
		# Zooming
		elif mb.pressed:
			if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
				zoom = (zoom + Vector2(zoom_speed, zoom_speed)).clamp(Vector2(min_zoom, min_zoom), Vector2(max_zoom, max_zoom))
			elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				zoom = (zoom - Vector2(zoom_speed, zoom_speed)).clamp(Vector2(min_zoom, min_zoom), Vector2(max_zoom, max_zoom))

	elif event is InputEventMouseMotion and _is_dragging:
		var motion := event as InputEventMouseMotion
		# Offset target position by drag delta
		target_position -= motion.relative / zoom.x

func center_on(pos: Vector2) -> void:
	target_position = pos
	position = pos
