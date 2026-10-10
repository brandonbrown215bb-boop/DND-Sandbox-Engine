class_name StatBar
extends PanelContainer

## Rook's Touch: a compact vitals bar — filled ProgressBar + centered
## tabular-number label. Color shifts by ratio via theme fill override.

@onready var _bar: ProgressBar = $Margin/VBox/Bar
@onready var _label: Label = $Margin/VBox/Bar/ValueLabel
@onready var _name: Label = $Margin/VBox/NameLabel

var _max := 1
var _low_is_danger := true

func _ready() -> void:
	_bar.min_value = 0
	_bar.max_value = _max
	_bar.show_percentage = false
	# Tabular numerals so "12/20" doesn't jitter width as digits change.
	# add_theme_font_features_override() does not exist in Godot 4.7 stable,
	# so we wrap the theme font in a FontVariation with the "tnum" OT feature.
	_apply_tnum()

## Wrap the resolved theme font in a FontVariation enabling tabular figures.
## No-op (and no error) if the theme font isn't available yet.
func _apply_tnum() -> void:
	if _label == null:
		return
	var base_font: Font = _label.get_theme_font("font")
	if base_font == null:
		return
	var fv := FontVariation.new()
	fv.base_font = base_font
	fv.opentype_features = {"tnum": 1}
	_label.add_theme_font_override("font", fv)

## Configure the bar. `color` tints the fill (vitals green / mana blue / etc).
func configure(label: String, max_value: int, color: Color = Color.TRANSPARENT) -> void:
	# Party cards configure this widget before it enters the scene tree.
	if _bar == null:
		_bar = get_node("Margin/VBox/Bar")
		_label = get_node("Margin/VBox/Bar/ValueLabel")
		_name = get_node("Margin/VBox/NameLabel")
	if _bar == null or _name == null:
		return
	_max = max(1, max_value)
	_bar.max_value = _max
	_name.text = label
	_set_fill_color(color if color.a > 0 else UiThemeProfile.current().color("state/success"))
	_label.add_theme_color_override("font_color", UiThemeProfile.current().color("text/primary"))

func _set_fill_color(c: Color) -> void:
	if _bar == null:
		return
	var fill := StyleBoxFlat.new()
	fill.bg_color = c
	fill.set_corner_radius_all(4)
	_bar.add_theme_stylebox_override("fill", fill)

func set_value(current: int) -> void:
	if _bar == null or _label == null:
		return
	var cur := clampi(current, 0, _max)
	_bar.value = cur
	_label.text = "%d/%d" % [cur, _max]
	# Ratio-based recolor (green -> amber -> red) when low is danger.
	if _low_is_danger:
		var r := float(cur) / float(_max)
		var col := UiThemeProfile.current().color("state/success")
		if r <= 0.25:
			col = UiThemeProfile.current().color("state/danger")
		elif r <= 0.5:
			col = UiThemeProfile.current().color("state/warning")
		_set_fill_color(col)
