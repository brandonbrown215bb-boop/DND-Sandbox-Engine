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
	_bar.max_value = 1
	_bar.show_percentage = false

## Configure the bar. `color` tints the fill (vitals green / mana blue / etc).
func configure(label: String, max_value: int, color: Color = Color(0.42, 0.70, 0.38)) -> void:
	if _bar == null or _name == null:
		return
	_max = max(1, max_value)
	_bar.max_value = _max
	_name.text = label
	_set_fill_color(color)
	_label.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95))

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
		var col := Color(0.42, 0.70, 0.38)
		if r <= 0.25:
			col = Color(0.78, 0.30, 0.28)
		elif r <= 0.5:
			col = Color(0.85, 0.65, 0.30)
		_set_fill_color(col)
