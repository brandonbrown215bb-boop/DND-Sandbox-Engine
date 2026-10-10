class_name VttShell
extends Control

## One desktop composition; scene HUDs still own action availability and intent.
signal board_rect_changed(rect: Rect2)
static var activity_open := true
static var selected_slot := ""
var active_character: Character
var help_text := "":
	set(value):
		help_text = value
		if _action_guidance != null:
			_action_guidance.text = value
var _action_guidance: Label
var board: Control
var party_list: VBoxContainer
var activity_panel: Control
var activity_tab: Button
var inspector: PopupPanel
var _camera: Camera2D
var _last_rect := Rect2()
var _menu: PopupPanel
var _turn_status: Label
var _combat_scene: Node

func _ready() -> void:
	UiThemeProfile.current().apply(self)
	UiThemeProfile.current().style(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var context := get_node("ContextBar") as Control
	activity_panel = get_node("ActivityRail") as Control
	var dock := get_node("ActionDock") as Control
	var legacy_party := get_node_or_null("PartyRail") as Control
	if legacy_party == null:
		legacy_party = get_node("Sidebar") as Control
	legacy_party.hide()
	var layout := VBoxContainer.new()
	layout.name = "Layout"
	layout.add_theme_constant_override("separation", 0)
	layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(layout)
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	context.reparent(layout)
	_reset_region(context, Vector2(0, 48))
	context.theme_type_variation = "ShellPanel"
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 0)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout.add_child(row)
	var rail := PanelContainer.new()
	rail.name = "CompactPartyRail"
	rail.theme_type_variation = "ShellPanel"
	rail.custom_minimum_size.x = 72
	row.add_child(rail)
	party_list = VBoxContainer.new()
	party_list.add_theme_constant_override("separation", int(UiThemeProfile.current().spacing.get("small", 6)))
	rail.add_child(party_list)
	var middle := VBoxContainer.new()
	middle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	middle.add_theme_constant_override("separation", 0)
	middle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(middle)
	board = Control.new()
	board.name = "BoardSlot"
	board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	middle.add_child(board)
	_action_guidance = get_node_or_null("HintLabel") as Label
	if _action_guidance != null:
		_action_guidance.reparent(middle)
		_reset_region(_action_guidance, Vector2(0, 40))
		_action_guidance.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_action_guidance.add_theme_font_size_override("font_size", 14)
		_action_guidance.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_action_guidance.text = help_text
		_action_guidance.show()
	dock.reparent(middle)
	_reset_region(dock, Vector2(0, 72))
	dock.mouse_filter = Control.MOUSE_FILTER_STOP
	activity_panel.reparent(row)
	_reset_region(activity_panel, Vector2(320, 0))
	activity_panel.theme_type_variation = "ShellPanel"
	activity_tab = Button.new()
	activity_tab.text = "‹"
	activity_tab.tooltip_text = "Open Chronicle"
	activity_tab.custom_minimum_size.x = 48
	activity_tab.pressed.connect(func(): set_activity_open(true))
	row.add_child(activity_tab)
	var activity_title := activity_panel.find_child("ActivityTitle", true, false) as Label
	if activity_title == null:
		activity_title = activity_panel.find_child("RailTitle", true, false) as Label
	if activity_title != null:
		activity_title.text = "Chronicle"
		activity_title.theme_type_variation = "HeadingLabel"
	var close := Button.new()
	close.text = "›"
	close.tooltip_text = "Collapse Chronicle"
	close.pressed.connect(func(): set_activity_open(false))
	close.custom_minimum_size = Vector2(40, 40)
	activity_title.get_parent().add_child(close)
	var dice := activity_panel.find_child("DiceRollDisplay", true, false) as Control
	if dice != null:
		dice.hide()
		# Retain the node for legacy hide calls, outside the visible rail.
		dice.reparent(self)
		if dice is DiceRollDisplay: dice.presentation_enabled = false
	_build_menu(context, legacy_party)
	_configure_dock(dock, context)
	for surface in [context, activity_panel]:
		var frame := GrimoireFrame.new()
		surface.add_child(frame)
	var scene := get_parent().get_parent()
	_combat_scene = scene if scene.get("turn_budget") != null else null
	_camera = scene.get_node_or_null("Camera2D") as Camera2D
	board.resized.connect(_geometry_changed)
	resized.connect(_geometry_changed)
	PartyManager.party_changed.connect(refresh_party)
	PlayerManager.active_player_changed.connect(func(_index): refresh_party())
	refresh_party()
	set_activity_open(activity_open)
	call_deferred("_geometry_changed")

func _reset_region(region: Control, minimum: Vector2) -> void:
	region.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	region.custom_minimum_size = minimum
	region.size_flags_horizontal = Control.SIZE_FILL
	region.size_flags_vertical = Control.SIZE_FILL

func _build_menu(context: Control, legacy_party: Control) -> void:
	_menu = PopupPanel.new()
	_menu.name = "GlobalMenu"
	_menu.theme = theme
	add_child(_menu)
	ModalSurface.watch_window(_menu)
	var box := VBoxContainer.new()
	_menu.add_child(box)
	var right := context.find_child("RightBox", true, false)
	for child in right.get_children():
		if child is Button:
			child.reparent(box)
			child.custom_minimum_size = Vector2(220, 44)
			child.pressed.connect(_menu.hide)
	var help := Button.new()
	help.text = "How to play"
	help.custom_minimum_size = Vector2(220, 44)
	help.pressed.connect(func():
		_menu.hide()
		_show_help()
	)
	box.add_child(help)
	var companions := legacy_party.find_child("BtnCompanions", true, false)
	if companions != null:
		companions.reparent(box)
		companions.pressed.connect(_menu.hide)
	var button := Button.new()
	button.name = "GlobalMenuButton"
	button.text = "Menu"
	button.icon = UiThemeProfile.current().icons.get("menu")
	button.custom_minimum_size = Vector2(96, 40)
	right.add_child(button)
	button.pressed.connect(func(): _menu.popup(Rect2i(Vector2i(size.x - 252, 48), Vector2i(240, 0))))
	var left := context.find_child("LeftBox", true, false)
	for child in left.get_children():
		if child is Label:
			child.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			child.custom_minimum_size.x = 0
			child.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			if str(child.name) == "Divider": child.hide()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var objective := context.find_child("ObjectiveLabel", true, false) as Label
	if objective != null:
		objective.get_parent().theme_type_variation = "ShellPanel"
		objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		objective.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
		objective.tooltip_text = objective.text

func _configure_dock(dock: Control, context: Control) -> void:
	var dock_box := dock.get_node("DockBox") as Control
	if dock_box is VBoxContainer:
		dock_box.add_theme_constant_override("separation", 0)
	else:
		dock_box.theme_type_variation = "ShellPanel"
	var action_menu := dock.find_child("ActionMenu", true, false) as Control
	if action_menu != null:
		action_menu.theme_type_variation = "ShellPanel"
		var margin := action_menu.get_node("Margin") as MarginContainer
		margin.add_theme_constant_override("margin_top", 3)
		margin.add_theme_constant_override("margin_bottom", 4)
	var initiative := context.find_child("InitiativePanel", true, false) as Control
	if initiative != null:
		var status_row := HBoxContainer.new()
		status_row.custom_minimum_size.y = 20
		dock_box.add_child(status_row)
		dock_box.move_child(status_row, 0)
		_turn_status = Label.new()
		_turn_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_turn_status.size_flags_stretch_ratio = 2.6
		_turn_status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		_turn_status.add_theme_font_size_override("font_size", 15)
		status_row.add_child(_turn_status)
		initiative.reparent(status_row)
		initiative.size_flags_stretch_ratio = 1.0
		initiative.theme_type_variation = "ShellPanel"
		initiative.custom_minimum_size.y = 20
		var strip := initiative.find_child("InitiativeBar", true, false) as RichTextLabel
		strip.custom_minimum_size.y = 20
		strip.fit_content = false
		strip.add_theme_font_size_override("normal_font_size", 14)
	for button_name in ["BtnAttack", "BtnSpell", "BtnFeatures", "BtnDodge", "BtnRest", "BtnEndTurn", "BtnCancel"]:
		var button := dock.find_child(button_name, true, false) as Button
		if button != null:
			var key: String = {"BtnAttack":"attack", "BtnSpell":"spell", "BtnFeatures":"features", "BtnDodge":"dodge", "BtnRest":"rest", "BtnEndTurn":"end_turn", "BtnCancel":"cancel"}[button_name]
			button.icon = UiThemeProfile.current().icons.get(key)
			button.custom_minimum_size.y = 44
			if button_name == "BtnEndTurn":
				button.theme_type_variation = "PrimaryButton"
				button.get_parent().move_child(button, button.get_parent().get_child_count() - 1)
	var stats := dock.find_child("ActivePlayerStats", true, false) as Label
	if stats != null:
		stats.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		stats.custom_minimum_size.x = 0
	for name in ["SpellMenu", "FeatureMenu"]:
		var selection := dock.find_child(name, true, false) as Control
		if selection != null:
			selection.reparent(self)
			selection.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
			selection.position = Vector2(84, size.y - 360)
			selection.size = Vector2(500, 260)
			selection.theme_type_variation = "OverlayPanel"

func set_activity_open(open: bool) -> void:
	activity_open = open
	activity_panel.visible = open
	activity_tab.visible = not open
	call_deferred("_geometry_changed")

func _geometry_changed() -> void:
	if activity_panel == null or board == null:
		return
	activity_panel.custom_minimum_size.x = 380 if size.x > 1600 else 320
	var rect := board.get_global_rect()
	if rect != _last_rect:
		_last_rect = rect
		board_rect_changed.emit(rect)
	for name in ["SpellMenu", "FeatureMenu"]:
		var selection := find_child(name, true, false) as Control
		if selection != null:
			selection.position = Vector2(rect.position.x + 12, rect.end.y - 270)
	_update_camera()

func _process(_delta: float) -> void:
	_update_camera()
	if _turn_status != null and _combat_scene != null:
		var actor := active_character
		var budget: CombatTurnBudget = _combat_scene.get("turn_budget")
		if actor == null:
			_turn_status.text = "Enemy turn"
		else:
			_turn_status.text = "%s · Action %s · Bonus %s · Reaction %s · Move %s" % [actor.character_name.left(14), "✓" if budget.can_spend("action") else "–", "✓" if budget.bonus_action_available else "–", "✓" if actor.reaction_available else "–", snappedf(float(_combat_scene.get("remaining_speed")), 0.5)]
			if actor.get_max_focus_points() > 0:
				_turn_status.text += " · Focus %d/%d" % [actor.get_focus_points(), actor.get_max_focus_points()]
		_turn_status.tooltip_text = _turn_status.text

func _update_camera() -> void:
	if _camera != null and board != null:
		_camera.offset = (get_viewport_rect().size / 2 - board.get_global_rect().get_center()) / _camera.zoom

func allows_world_point(point: Vector2) -> bool:
	return board.get_global_rect().has_point(point) and not ModalSurface.blocks_world() and not _menu.visible and (inspector == null or not inspector.visible)

func refresh_party() -> void:
	if party_list == null:
		return
	for child in party_list.get_children():
		party_list.remove_child(child)
		child.queue_free()
	var slot_number := 0
	for member in PartyManager.get_active_party_members():
		var character: Character = member.get("character")
		if character == null:
			continue
		slot_number += 1
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 2)
		party_list.add_child(box)
		var slot := str(member.get("slot_id", ""))
		var owner := int(member.get("owner_player_index", -1))
		var button := Button.new()
		button.custom_minimum_size = Vector2(64, 54)
		button.text = ""
		button.clip_text = true
		button.tooltip_text = "%s · %s\nHP %d/%d\n%s" % [character.character_name, DataLoader.get_character_class(character.class_id).get("name", ""), character.current_hp, character.max_hp, ", ".join(character.conditions.keys())]
		button.theme_type_variation = "PrimaryButton" if character == active_character else "Button"
		button.pressed.connect(func():
			selected_slot = slot
			refresh_party()
			_show_inspector(character)
		)
		box.add_child(button)
		var portrait := PartyPortrait.new()
		portrait.character = character
		portrait.is_current = character == active_character
		if slot == selected_slot:
			button.add_theme_stylebox_override("normal", theme.get_stylebox("focus", "Button"))
		button.add_child(portrait)
		portrait.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var caption := Label.new()
		caption.text = "%d %s" % [slot_number, character.character_name.left(6)]
		caption.tooltip_text = character.character_name
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		box.add_child(caption)
		if portrait.is_current or slot == selected_slot:
			var marker := Label.new()
			marker.text = "▶" if portrait.is_current else "◇"
			marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
			button.add_child(marker)
			marker.position = Vector2(4, 2)
		var hp := Label.new()
		hp.text = "%d/%d" % [character.current_hp, character.max_hp]
		hp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(hp)
		var meter := ProgressBar.new()
		meter.custom_minimum_size.y = 5
		meter.max_value = max(1, character.max_hp)
		meter.value = character.current_hp
		meter.show_percentage = false
		box.add_child(meter)
		if PlayerManager.get_player_count() > 1:
			var seat := Label.new()
			seat.text = "P%d%s" % [owner + 1, " *" if owner == PlayerManager.active_player_index else ""]
			seat.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			seat.theme_type_variation = "MutedLabel"
			box.add_child(seat)
		if character.current_hp <= 0 or not character.conditions.is_empty():
			var status := Label.new()
			status.text = "Down" if character.current_hp <= 0 else "• Status"
			status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			box.add_child(status)

func _show_inspector(character: Character) -> void:
	if inspector != null:
		inspector.queue_free()
	inspector = PopupPanel.new()
	inspector.name = "PartyInspector"
	inspector.size = Vector2i(224, 320)
	inspector.theme = theme
	inspector.theme_type_variation = "OverlayPanel"
	add_child(inspector)
	ModalSurface.watch_window(inspector)
	var box := VBoxContainer.new()
	box.custom_minimum_size.x = 176
	inspector.add_child(box)
	var title := Label.new()
	title.text = character.character_name
	title.theme_type_variation = "HeadingLabel"
	title.size.x = 176
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(title)
	var info := Label.new()
	info.size.x = 176
	var visible_conditions: Array[String] = []
	for condition in character.conditions:
		visible_conditions.append("Exhaustion %d" % character.exhaustion_level if condition == "exhaustion" else str(condition))
	info.text = "Level %d %s\nHP %d / %d\nAC %d · %d hexes\n%s" % [character.level, DataLoader.get_character_class(character.class_id).get("name", ""), character.current_hp, character.max_hp, character.get_ac(), character.get_speed(), ", ".join(visible_conditions)]
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if character.get_max_focus_points() > 0:
		info.text += "\nFocus %d / %d" % [character.get_focus_points(), character.get_max_focus_points()]
	box.add_child(info)
	var sheet := Button.new()
	sheet.text = "Character sheet"
	sheet.pressed.connect(func():
		inspector.hide()
		CharacterSheet.show_sheet(character)
	)
	box.add_child(sheet)
	var close := Button.new()
	close.text = "Close"
	close.pressed.connect(inspector.hide)
	box.add_child(close)
	inspector.popup(Rect2i(72, 48, 224, 320))

func _show_help() -> void:
	var panel := PanelContainer.new()
	panel.theme_type_variation = "OverlayPanel"
	add_child(panel)
	panel.size = Vector2(620, 400)
	panel.position = (size - panel.size) / 2
	var box := VBoxContainer.new()
	panel.add_child(box)
	var title := Label.new()
	title.text = "At the Table"
	title.theme_type_variation = "TitleLabel"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var text := Label.new()
	text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.text = "Click a highlighted hex to move. In combat, choose Attack or Spell, then click a valid target. End Turn when finished; Escape or Cancel backs out before spending resources.\n\nInspect a party portrait for its full name and character sheet. ▶ marks the current actor; ◇ marks the inspected character. P* marks the active seat. Set up Wizard spells and Druid known forms under Class Progression outside combat.\n\nPan with WASD, arrow keys, or a right/middle mouse drag. Use the mouse wheel over the board to zoom.\n\nRead, focus, or pin Roll details in the Chronicle. New activity preserves your place while you read older entries.\n\n" + help_text
	box.add_child(text)
	var close := Button.new()
	close.text = "Return to play"
	close.pressed.connect(panel.queue_free)
	box.add_child(close)
	ModalSurface.install(panel, panel.queue_free)
