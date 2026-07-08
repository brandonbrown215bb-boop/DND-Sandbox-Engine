## Theme builder (run once, headless). Generates res://theme/main_theme.tres.
## Rook's Touch: dark "tabletop" — charcoal panels, warm gold accent,
## parchment text, red danger / green vitals.
extends SceneTree

func _initialize() -> void:
	var theme := Theme.new()

	# ---- Palette ----
	var ink        := Color(0.92, 0.88, 0.78)   # parchment text
	var ink_dim    := Color(0.62, 0.60, 0.54)
	var panel_bg   := Color(0.12, 0.12, 0.14, 0.94)
	var panel_edge := Color(0.30, 0.28, 0.24, 1)
	var gold       := Color(0.85, 0.65, 0.30)
	var gold_dim   := Color(0.55, 0.42, 0.20)
	var danger     := Color(0.78, 0.30, 0.28)
	var vitals     := Color(0.42, 0.70, 0.38)
	var active_blue := Color(0.55, 0.72, 0.92)

	theme.default_font_size = 16

	# ---- Panel style ----
	var panel := StyleBoxFlat.new()
	panel.bg_color = panel_bg
	panel.border_color = panel_edge
	panel.set_border_width_all(1)
	panel.set_corner_radius_all(8)
	panel.set_content_margin_all(10)

	# ---- Button style (normal / hover / pressed) ----
	var btn := StyleBoxFlat.new()
	btn.bg_color = Color(0.20, 0.20, 0.24, 1)
	btn.border_color = gold_dim
	btn.set_border_width_all(1)
	btn.set_corner_radius_all(6)
	btn.set_content_margin_all(8)

	var btn_hover := StyleBoxFlat.new()
	btn_hover.bg_color = Color(0.28, 0.26, 0.22, 1)
	btn_hover.border_color = gold
	btn_hover.set_border_width_all(1)
	btn_hover.set_corner_radius_all(6)
	btn_hover.set_content_margin_all(8)

	var btn_pressed := StyleBoxFlat.new()
	btn_pressed.bg_color = Color(0.14, 0.13, 0.12, 1)
	btn_pressed.border_color = gold
	btn_pressed.set_border_width_all(2)
	btn_pressed.set_corner_radius_all(6)
	btn_pressed.set_content_margin_all(8)

	# ---- Button type ----
	theme.set_type_variation("Button", "Button")
	theme.set_stylebox("normal", "Button", btn)
	theme.set_stylebox("hover", "Button", btn_hover)
	theme.set_stylebox("pressed", "Button", btn_pressed)
	theme.set_color("font_color", "Button", ink)
	theme.set_color("font_hover_color", "Button", gold)
	theme.set_color("font_pressed_color", "Button", gold)
	theme.set_font_size("font_size", "Button", 16)

	# ---- Panel type ----
	theme.set_stylebox("panel", "Panel", panel)
	theme.set_stylebox("normal", "PanelContainer", panel)

	# ---- Label type ----
	theme.set_color("default_color", "Label", ink)
	theme.set_font_size("font_size", "Label", 16)

	# ---- RichTextLabel ----
	theme.set_color("default_color", "RichTextLabel", ink)
	theme.set_font_size("font_size", "RichTextLabel", 15)

	# ---- ProgressBar ----
	var pb_bg := StyleBoxFlat.new()
	pb_bg.bg_color = Color(0.08, 0.08, 0.09, 1)
	pb_bg.set_corner_radius_all(4)
	var pb_fill := StyleBoxFlat.new()
	pb_fill.bg_color = vitals
	pb_fill.set_corner_radius_all(4)
	theme.set_stylebox("normal", "ProgressBar", pb_bg)
	theme.set_stylebox("fill", "ProgressBar", pb_fill)

	# ---- Title label variation ----
	theme.set_type_variation("TitleLabel", "Label")
	theme.set_color("default_color", "TitleLabel", gold)
	theme.set_font_size("font_size", "TitleLabel", 20)

	var err := ResourceSaver.save(theme, "res://theme/main_theme.tres")
	if err != OK:
		push_error("Theme save failed: %d" % err)
	else:
		print("Theme saved: res://theme/main_theme.tres")
	quit()
