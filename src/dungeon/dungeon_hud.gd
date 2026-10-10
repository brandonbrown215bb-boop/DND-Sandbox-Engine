class_name DungeonHUD
extends BaseHUD

## Dungeon HUD Controller
## Room-by-room crawl HUD. Not turn-based, so it has NO End Turn control and
## does not inherit OverworldHUD's turn-based affordances. Extends BaseHUD for
## the shared system row (Rest / Save / Menu / Settings / Sheet) and log
## plumbing.
##
## Pattern H from UI_OVERHAUL_RESEARCH.md — the real split. The old
## "DungeonHUD extends OverworldHUD + hide btn_end_turn" smell is gone; the
## End Turn button no longer exists in the dungeon scene at all.

func _resolve_node(primary: String, fallback: String = "", fallback2: String = "") -> Node:
	for p in [primary, fallback, fallback2]:
		if not p.is_empty():
			if has_node(p):
				return get_node(p)
			if has_node("Root/" + p):
				return get_node("Root/" + p)
	return find_child(primary.get_file(), true, false)

@onready var player_list_container: VBoxContainer = _resolve_node("PartyRail/Margin/RailBox/ScrollContainer/PlayerList", "MarginContainer/HBoxContainer/Sidebar/ScrollContainer/PlayerList") as VBoxContainer

@onready var objective_label: Label = _resolve_node("ContextBar/Margin/HBox/ObjectivePanel/ObjectiveLabel", "MarginContainer/HBoxContainer/MainArea/Header/MarginContainer/VBoxContainer/ObjectiveLabel") as Label
@onready var active_player_name: Label = _resolve_node("ContextBar/Margin/HBox/LeftBox/ActivePlayerName", "MarginContainer/HBoxContainer/MainArea/Header/MarginContainer/VBoxContainer/ActivePlayerName") as Label
@onready var btn_rest: Button = _resolve_node("ActionDock/DockBox/Margin/HBox/BtnRest", "MarginContainer/HBoxContainer/Sidebar/BtnRest") as Button
@onready var btn_save: Button = _resolve_node("ContextBar/Margin/HBox/RightBox/BtnSave", "MarginContainer/HBoxContainer/Sidebar/BtnSave") as Button
@onready var btn_menu: Button = _resolve_node("ContextBar/Margin/HBox/RightBox/BtnMenu", "MarginContainer/HBoxContainer/Sidebar/BtnMenu") as Button
@onready var btn_settings: Button = _resolve_node("ContextBar/Margin/HBox/RightBox/BtnSettings", "MarginContainer/HBoxContainer/Sidebar/BtnSettings") as Button
@onready var btn_sheet: Button = _resolve_node("ContextBar/Margin/HBox/RightBox/BtnSheet", "MarginContainer/HBoxContainer/Sidebar/BtnSheet") as Button

func _ready() -> void:
	btn_rest.pressed.connect(func(): rest_pressed.emit())
	btn_save.pressed.connect(func(): save_pressed.emit())
	btn_menu.pressed.connect(func(): menu_pressed.emit())
	btn_settings.pressed.connect(func(): settings_pressed.emit())
	btn_sheet.pressed.connect(func(): sheet_pressed.emit())
	log_text = _resolve_node("ActivityRail/Margin/ActivityContent/LogBox/LogText", "MarginContainer/HBoxContainer/MainArea/LogBox/LogText") as RichTextLabel
	clear_logs()
	update_hud()

## Refresh the dungeon HUD: party cards (StatBars) + objective banner.
## (Rook's Touch: minimal crawl UI — no action grid, no End Turn.)
func update_hud() -> void:
	if get_node_or_null("Root") is VttShell:
		$Root.active_character = PlayerManager.get_active_player().get("character")
		$Root.refresh_party()
	_update_party_sidebar()
	_update_objective()

func _update_party_sidebar() -> void:
	if player_list_container == null:
		return
	for child in player_list_container.get_children():
		child.queue_free()

	var player_count := PlayerManager.get_player_count()
	var active_idx := PlayerManager.active_player_index

	for i in player_count:
		var player := PlayerManager.get_player(i)
		var char_data: Character = player.get("character")
		if char_data == null:
			continue

		var card := PanelContainer.new()
		var vbox := VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 5)
		card.add_child(vbox)

		# HP bar (Rook's Touch: visual vitals, not text-only)
		var hp_bar = load("res://scenes/ui/stat_bar.tscn").instantiate()
		vbox.add_child(hp_bar)
		hp_bar.configure("HP", char_data.max_hp)
		hp_bar.set_value(char_data.current_hp)

		var name_lbl := Label.new()
		name_lbl.text = "%s (%s)" % [char_data.character_name, DataLoader.get_character_class(char_data.class_id).get("name", "Class")]
		if i == active_idx:
			name_lbl.text = "➔ " + name_lbl.text
			name_lbl.add_theme_color_override("font_color", UiThemeProfile.current().color("accent/primary"))
		else:
			name_lbl.add_theme_color_override("font_color", UiThemeProfile.current().color("text/primary"))
		vbox.add_child(name_lbl)

		var hp_lbl := Label.new()
		hp_lbl.text = "HP: %d / %d | Gold: %d | Level %d" % [char_data.current_hp, char_data.max_hp, char_data.inventory.gold, char_data.level]
		vbox.add_child(hp_lbl)

		if not char_data.conditions.is_empty():
			var cond_lbl := Label.new()
			var conds_str := "Conditions: "
			for cond in char_data.conditions:
				conds_str += "%s (%d) " % [cond, char_data.conditions[cond]]
			cond_lbl.text = conds_str
			cond_lbl.add_theme_color_override("font_color", UiThemeProfile.current().color("state/danger"))
			vbox.add_child(cond_lbl)

		player_list_container.add_child(card)

func _update_objective() -> void:
	if objective_label == null:
		return
	var win_cond: Dictionary = GameManager.get_win_condition()
	if win_cond.is_empty():
		objective_label.text = "Objective: Free roam"
		return
	var goals: Array = win_cond.get("goals", [])
	var parts: Array[String] = []
	for g in goals:
		match g.get("type", ""):
			"defeat_monster":
				var m_id: String = g.get("monster_id", "?")
				var md: Dictionary = DataLoader.get_monster(m_id)
				var name: String = md.get("name", m_id) if not md.is_empty() else m_id
				parts.append("Defeat %s" % name)
			"collect_item":
				var i_id: String = g.get("item_id", "?")
				var it: Dictionary = DataLoader.get_item(i_id)
				var iname: String = it.get("name", i_id) if not it.is_empty() else i_id
				parts.append("Find %s" % iname)
			"reach_tile":
				parts.append("Reach the objective")
			_:
				parts.append(g.get("type", "objective"))
	objective_label.text = "Objective: " + " • ".join(parts)
