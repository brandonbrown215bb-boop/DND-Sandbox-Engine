class_name UiThemeProfile
extends Resource

## Presentation-only profile. Screens consume roles, never profile IDs.
@export var profile_id := "grimoire"
@export var display_name := "The Grimoire"
@export var ui_theme: Theme
@export var colors: Dictionary = {}
@export var spacing: Dictionary = {"small": 6, "medium": 12, "large": 24}
@export var icons: Dictionary = {}
@export var ornament: Texture2D
@export var feedback_duration := 0.12

static var _current: UiThemeProfile

static func current() -> UiThemeProfile:
	if _current == null:
		_current = load("res://theme/grimoire_profile.tres") as UiThemeProfile
	return _current

static func use_profile(profile: UiThemeProfile) -> void:
	_current = profile

func color(role: String) -> Color:
	return colors.get(role, Color.WHITE)

func apply(control: Control) -> void:
	control.theme = ui_theme
	control.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	RenderingServer.set_default_clear_color(color("surface/base"))

func style(control: Control) -> void:
	# Remove legacy per-node chrome overrides so profiles remain authoritative.
	if control.owner != null:
		for property in control.get_property_list():
			var property_name := str(property.name)
			if property_name.begins_with("theme_override_colors/"):
				control.remove_theme_color_override(property_name.get_slice("/", 1))
	if control is Label:
		var old_size := control.get_theme_font_size("font_size")
		if control.has_theme_font_size_override("font_size"):
			control.remove_theme_font_size_override("font_size")
		if old_size >= 20 or "Title" in str(control.name) or "Heading" in str(control.name):
			control.theme_type_variation = "TitleLabel"
	elif control is Button:
		control.custom_minimum_size.y = maxf(40, control.custom_minimum_size.y)
	for child in control.get_children():
		if child is Control:
			style(child)
