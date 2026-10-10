class_name ModalSurface
extends ColorRect

## Shared input shield and focus policy, independent of each dialog's task.
static var _surfaces: Array[WeakRef] = []
static var _windows: Array[WeakRef] = []
var content: Control
var dismiss: Callable
var _was_open := false
var _opener: WeakRef
var _opened_at := 0
var center_in_play_area := false
static var _open_counter := 0

static func install(target: Control, close: Callable = Callable(), centered: bool = false) -> ModalSurface:
	var shield := ModalSurface.new()
	shield.content = target
	shield.dismiss = close
	shield.center_in_play_area = centered
	target.get_parent().add_child(shield)
	target.get_parent().move_child(shield, target.get_index())
	return shield

static func blocks_world() -> bool:
	for reference in _windows:
		var window = reference.get_ref()
		if window != null and window.visible: return true
	return _top_surface() != null

static func watch_window(window: Window) -> void:
	window.theme = UiThemeProfile.current().ui_theme
	window.wrap_controls = true
	_windows = _windows.filter(func(reference): return reference.get_ref() != null)
	_windows.append(weakref(window))

static func _top_surface() -> ModalSurface:
	var top: ModalSurface
	var rank := -INF
	for index in range(_surfaces.size() - 1, -1, -1):
		var reference := _surfaces[index]
		var shield = reference.get_ref()
		if shield != null and is_instance_valid(shield.content) and shield.content.is_visible_in_tree():
			var layer: CanvasLayer = shield.content.get_canvas_layer_node()
			var current_rank: float = (layer.layer if layer != null else 0) * 1000000 + shield._opened_at
			if current_rank > rank:
				top = shield
				rank = current_rank
	return top

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	color = Color(UiThemeProfile.current().color("surface/base"), 0.82)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_surfaces.append(weakref(self))
	_surfaces = _surfaces.filter(func(reference): return reference.get_ref() != null)
	var profile := UiThemeProfile.current()
	profile.apply(content)
	profile.style(content)
	var frame := GrimoireFrame.new()
	frame.prominent = true
	var frame_parent: Control = content
	if not content is PanelContainer:
		var panels := content.find_children("*", "PanelContainer", true, false)
		if not panels.is_empty(): frame_parent = panels[0]
	frame_parent.theme_type_variation = "OverlayPanel" if frame_parent is PanelContainer else frame_parent.theme_type_variation
	frame_parent.add_child(frame)

func _process(_delta: float) -> void:
	if not is_instance_valid(content):
		queue_free()
		return
	var open := content.is_visible_in_tree()
	visible = open
	if open and center_in_play_area:
		_center_content()
	if open and not _was_open:
		_open_counter += 1
		_opened_at = _open_counter
		var focus := get_viewport().gui_get_focus_owner()
		_opener = weakref(focus) if focus != null else null
		var controls := _focusable(content)
		if not controls.is_empty() and _top_surface() == self:
			controls[0].grab_focus()
	elif not open and _was_open and _opener != null:
		var opener = _opener.get_ref()
		if opener != null and opener.is_visible_in_tree():
			opener.grab_focus()
	_was_open = open


func _center_content() -> void:
	var available := get_viewport_rect().grow(-12)
	var ancestor: Node = content.get_parent()
	while ancestor != null:
		var shell := ancestor.find_child("Root", true, false) as VttShell
		if shell != null and shell.board != null:
			var board_rect := shell.board.get_global_rect().grow(-12)
			if board_rect.size.x >= content.get_combined_minimum_size().x and board_rect.size.y >= content.get_combined_minimum_size().y:
				available = board_rect
			break
		ancestor = ancestor.get_parent()
	content.set_anchors_preset(Control.PRESET_TOP_LEFT)
	content.size = content.get_combined_minimum_size().max(Vector2(560, 280)).min(available.size)
	content.global_position = available.position + (available.size - content.size) / 2

func _input(event: InputEvent) -> void:
	if _top_surface() != self: return
	if not is_instance_valid(content) or not content.is_visible_in_tree():
		return
	if event.is_action_pressed("ui_cancel"):
		if not dismiss.is_null():
			dismiss.call()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_focus_next") or event.is_action_pressed("ui_focus_prev"):
		var controls := _focusable(content)
		if controls.is_empty():
			return
		var index := controls.find(get_viewport().gui_get_focus_owner())
		var direction := -1 if event.is_action_pressed("ui_focus_prev") else 1
		controls[posmod(index + direction, controls.size())].grab_focus()
		get_viewport().set_input_as_handled()

func _focusable(node: Node) -> Array[Control]:
	var result: Array[Control] = []
	if node is Control and node.is_visible_in_tree() and node.focus_mode == Control.FOCUS_ALL:
		if not node is BaseButton or not node.disabled:
			result.append(node)
	for child in node.get_children():
		result.append_array(_focusable(child))
	return result
