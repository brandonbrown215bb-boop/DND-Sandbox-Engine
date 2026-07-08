## Overworld HUD Controller
## Displays party statuses, turn status, active player, logs, and handles End Turn requests.
class_name OverworldHUD
extends BaseHUD

signal end_turn_pressed

# Node references
@onready var player_list_container: VBoxContainer = $MarginContainer/HBoxContainer/Sidebar/ScrollContainer/PlayerList
@onready var active_player_name: Label = $MarginContainer/HBoxContainer/MainArea/Header/MarginContainer/VBoxContainer/ActivePlayerName
@onready var active_player_stats: Label = $MarginContainer/HBoxContainer/MainArea/Header/MarginContainer/VBoxContainer/ActivePlayerStats
@onready var objective_label: Label = $MarginContainer/HBoxContainer/MainArea/Header/MarginContainer/VBoxContainer/ObjectiveLabel
@onready var btn_end_turn: Button = $MarginContainer/HBoxContainer/Sidebar/BtnEndTurn
@onready var btn_rest: Button = $MarginContainer/HBoxContainer/Sidebar/BtnRest
@onready var btn_save: Button = $MarginContainer/HBoxContainer/Sidebar/BtnSave
@onready var btn_menu: Button = $MarginContainer/HBoxContainer/Sidebar/BtnMenu
@onready var btn_settings: Button = $MarginContainer/HBoxContainer/Sidebar/BtnSettings
@onready var btn_sheet: Button = $MarginContainer/HBoxContainer/Sidebar/BtnSheet


func _ready() -> void:
	btn_end_turn.pressed.connect(func(): end_turn_pressed.emit())
	btn_rest.pressed.connect(func(): rest_pressed.emit())
	btn_save.pressed.connect(func(): save_pressed.emit())
	btn_menu.pressed.connect(func(): menu_pressed.emit())
	btn_settings.pressed.connect(func(): settings_pressed.emit())
	btn_sheet.pressed.connect(func(): sheet_pressed.emit())
	log_text = $MarginContainer/HBoxContainer/MainArea/LogBox/LogText
	clear_logs()
	update_hud()


## Refresh HUD elements with current player and party information.
## (log_text, clear_logs(), add_log() inherited from BaseHUD.)
func update_hud() -> void:
	_update_party_sidebar()
	_update_active_player_display()
	_update_objective()

func _update_party_sidebar() -> void:
	# Clear sidebar list
	for child in player_list_container.get_children():
		child.queue_free()

	# Build status bar for each player
	var player_count := PlayerManager.get_player_count()
	var active_idx := PlayerManager.active_player_index
	
	for i in player_count:
		var player := PlayerManager.get_player(i)
		var char_data: Character = player.get("character")
		if char_data == null: continue

		var card := PanelContainer.new()
		var vbox := VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 5)
		card.add_child(vbox)

		# HP bar (Rook's Touch: visual vitals, not text-only)
		var hp_bar = load("res://scenes/ui/stat_bar.tscn").instantiate()
		vbox.add_child(hp_bar)
		hp_bar.configure("HP", char_data.max_hp)
		hp_bar.set_value(char_data.current_hp)

		# Name & class
		var name_lbl := Label.new()
		name_lbl.text = "%s (%s)" % [char_data.character_name, DataLoader.get_character_class(char_data.class_id).get("name", "Class")]
		if i == active_idx:
			name_lbl.text = "➔ " + name_lbl.text
			# Add subtle active color
			name_lbl.add_theme_color_override("font_color", Color.YELLOW)
		else:
			name_lbl.add_theme_color_override("font_color", player.get("color", Color.WHITE))
		vbox.add_child(name_lbl)

		# HP Bar/Text
		var hp_lbl := Label.new()
		hp_lbl.text = "HP: %d / %d | Gold: %d | Level %d" % [char_data.current_hp, char_data.max_hp, char_data.inventory.gold, char_data.level]
		vbox.add_child(hp_lbl)

		# Show spell slots if any
		if not char_data.spell_slots.is_empty():
			var slots_lbl := Label.new()
			var slots_str := "Spell Slots: "
			var has_slots := false
			for lvl in char_data.spell_slots:
				slots_str += "L%s: %d  " % [lvl, char_data.spell_slots[lvl]]
				has_slots = true
			if has_slots:
				slots_lbl.text = slots_str
				slots_lbl.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
				vbox.add_child(slots_lbl)

		# Show active conditions
		if not char_data.conditions.is_empty():
			var cond_lbl := Label.new()
			var conds_str := "Conditions: "
			for cond in char_data.conditions:
				conds_str += "%s (%d) " % [cond, char_data.conditions[cond]]
			cond_lbl.text = conds_str
			cond_lbl.add_theme_color_override("font_color", Color(0.9, 0.4, 0.4))
			vbox.add_child(cond_lbl)

		player_list_container.add_child(card)


func _update_active_player_display() -> void:
	var player := PlayerManager.get_active_player()
	var char_data: Character = player.get("character")
	if char_data == null: return

	active_player_name.text = "Current Turn: %s" % char_data.character_name
	active_player_name.add_theme_color_override("font_color", player.get("color", Color.WHITE))
	
	active_player_stats.text = "Race: %s | Level: %d | Speed: %d hexes" % [
		DataLoader.get_race(char_data.race_id).get("name", ""),
		char_data.level,
		char_data.speed
	]


## Show the active campaign objective (demo arc) so the player knows the goal.
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
