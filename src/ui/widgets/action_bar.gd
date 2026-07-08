class_name ActionBar
extends HBoxContainer

## ActionBar — consistent, reusable bottom action row (Pattern E,
## UI_OVERHAUL_RESEARCH.md). Every gameplay screen gets the same bar at a fixed
## position with a consistent button order: primary actions, then secondary
## (spells/features), then system actions right-aligned.
##
## Buttons are icon + short label. Icons are OPTIONAL — pass a Texture2D and it
## shows; omit it and the button is label-only. This keeps the widget usable
## now (no art assets required) and ready for icons once an icon source is
## chosen (see UI_OVERHAUL_RESEARCH.md §6 open question 2).
##
## Usage:
##   var bar := ActionBar.new()
##   bar.add_action("rest", "Rest", rest_icon, func(): _on_rest_pressed())
##   bar.push_right()                      # pushes subsequent buttons right
##   bar.add_action("sheet", "Sheet", null, func(): CharacterSheet.show_active())
##   bar.action_pressed.connect(_on_action)   # alt: react to name signals

signal action_pressed(action_id: String)

const MIN_HIT := 40  # min 40-44px hit area (design-engineering checklist)

func _ready() -> void:
	alignment = BoxContainer.ALIGNMENT_BEGIN
	add_theme_constant_override("separation", 8)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL

## Add a button. `icon` may be null (label-only). `cb` is an optional Callable
## fired on press; or connect to `action_pressed` to dispatch by id centrally.
func add_action(action_id: String, label: String, icon: Texture2D = null, cb: Callable = Callable()) -> Button:
	var btn := Button.new()
	btn.name = "Action_%s" % action_id
	btn.text = label
	btn.custom_minimum_size = Vector2(MIN_HIT, MIN_HIT)
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if icon != null:
		btn.icon = icon
		btn.expand_icon = true
	btn.tooltip_text = label
	btn.pressed.connect(func(): _on_pressed(action_id))
	if not cb.is_null():
		btn.pressed.connect(cb)
	add_child(btn)
	return btn

## Push everything added after this to the right edge (system actions).
## (Named push_right to avoid colliding with BoxContainer.add_spacer(bool).)
func push_right() -> void:
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(sp)

## Programmatically fire an action (e.g. for tests or scripted UI).
func trigger(action_id: String) -> void:
	_on_pressed(action_id)

## Remove every child this bar created (buttons + spacers). Frees
## immediately (not queued) so callers can assert the cleared state at once.
func clear_actions() -> void:
	for c in get_children():
		remove_child(c)
		c.free()

func _on_pressed(action_id: String) -> void:
	action_pressed.emit(action_id)
