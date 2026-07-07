## Battle Result Overlay
## Read-only payoff screen shown at the end of a tactical battle (victory or
## defeat). Built in code (no .tscn) so combat_state can summon it directly.
## Buttons: "Continue" -> resolves the combat normally; "Main Menu" -> abort to menu.
class_name BattleResultOverlay
extends CanvasLayer

signal resolved(result: String)  # emitted when the player dismisses the overlay

var _result: String = "victory"
var _background: ColorRect
var _panel: Panel
var _title: Label
var _subtitle: Label
var _btn_continue: Button
var _btn_menu: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 64

	_background = ColorRect.new()
	_background.color = Color(0.0, 0.0, 0.0, 0.6)
	_background.anchors_preset = Control.PRESET_FULL_RECT
	_background.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_background)

	_panel = Panel.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.custom_minimum_size = Vector2(440, 260)
	_panel.position = Vector2(-220, -130)
	add_child(_panel)

	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 42)
	_title.position = Vector2(20, 30)
	_title.size = Vector2(400, 70)
	_panel.add_child(_title)

	_subtitle = Label.new()
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_subtitle.position = Vector2(20, 110)
	_subtitle.size = Vector2(400, 60)
	_panel.add_child(_subtitle)

	_btn_continue = Button.new()
	_btn_continue.text = "Continue"
	_btn_continue.custom_minimum_size = Vector2(180, 44)
	_btn_continue.position = Vector2(40, 190)
	_btn_continue.pressed.connect(_on_continue)
	_panel.add_child(_btn_continue)

	_btn_menu = Button.new()
	_btn_menu.text = "Main Menu"
	_btn_menu.custom_minimum_size = Vector2(180, 44)
	_btn_menu.position = Vector2(240, 190)
	_btn_menu.pressed.connect(_on_menu)
	_panel.add_child(_btn_menu)


## Populate and present the overlay.
func show_result(result: String, subtitle: String = "") -> void:
	_result = result
	if result == "victory":
		_title.text = "VICTORY"
		_title.add_theme_color_override("font_color", Color(0.4, 1.0, 0.5))
		if subtitle.is_empty():
			subtitle = "The foes are broken. Your party stands."
	else:
		_title.text = "DEFEAT"
		_title.add_theme_color_override("font_color", Color(1.0, 0.35, 0.3))
		if subtitle.is_empty():
			subtitle = "The party has fallen. The crown remains lost."
	_subtitle.text = subtitle
	visible = true


func _on_continue() -> void:
	visible = false
	resolved.emit(_result)


func _on_menu() -> void:
	visible = false
	resolved.emit("menu")
