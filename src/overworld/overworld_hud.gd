## Overworld HUD Controller
## Displays party statuses, turn status, active player, logs, and handles End Turn requests.
class_name OverworldHUD
extends BaseHUD

signal end_turn_pressed
signal companion_roster_visibility_changed(is_open: bool)

# Node references
@onready var player_list_container: VBoxContainer = $MarginContainer/HBoxContainer/Sidebar/ScrollContainer/PlayerList
@onready var active_player_name: Label = $MarginContainer/HBoxContainer/MainArea/Header/MarginContainer/VBoxContainer/ActivePlayerName
@onready var active_player_stats: Label = $MarginContainer/HBoxContainer/MainArea/Header/MarginContainer/VBoxContainer/ActivePlayerStats
@onready var objective_label: Label = $MarginContainer/HBoxContainer/MainArea/Header/MarginContainer/VBoxContainer/ObjectiveLabel
@onready var btn_end_turn: Button = $MarginContainer/HBoxContainer/Sidebar/BtnEndTurn
@onready var btn_companions: Button = $MarginContainer/HBoxContainer/Sidebar/BtnCompanions
@onready var btn_rest: Button = $MarginContainer/HBoxContainer/Sidebar/BtnRest
@onready var btn_save: Button = $MarginContainer/HBoxContainer/Sidebar/BtnSave
@onready var btn_menu: Button = $MarginContainer/HBoxContainer/Sidebar/BtnMenu
@onready var btn_settings: Button = $MarginContainer/HBoxContainer/Sidebar/BtnSettings
@onready var btn_sheet: Button = $MarginContainer/HBoxContainer/Sidebar/BtnSheet
@onready var companion_overlay: Control = $CompanionOverlay
@onready var companion_panel: CompanionRosterPanel = $CompanionOverlay/Center/CompanionRosterPanel


func _ready() -> void:
	btn_end_turn.pressed.connect(func(): end_turn_pressed.emit())
	btn_companions.pressed.connect(open_companion_roster)
	btn_rest.pressed.connect(func(): rest_pressed.emit())
	btn_save.pressed.connect(func(): save_pressed.emit())
	btn_menu.pressed.connect(func(): menu_pressed.emit())
	btn_settings.pressed.connect(func(): settings_pressed.emit())
	btn_sheet.pressed.connect(func(): sheet_pressed.emit())
	companion_panel.close_requested.connect(close_companion_roster)
	companion_panel.lifecycle_changed.connect(_on_companion_lifecycle_changed)
	PlayerManager.device_binding_changed.connect(_on_device_binding_changed)
	log_text = $MarginContainer/HBoxContainer/MainArea/LogBox/LogText
	clear_logs()
	update_hud()


## Refresh HUD elements with current player and party information.
## (log_text, clear_logs(), add_log() inherited from BaseHUD.)
func update_hud() -> void:
	_update_party_sidebar()
	_update_active_player_display()
	_update_objective()
	btn_companions.disabled = PartyManager.get_companion_ids().is_empty()


func open_companion_roster() -> void:
	companion_panel.refresh()
	companion_overlay.show()
	_set_underlay_controls_disabled(true)
	companion_roster_visibility_changed.emit(true)


func close_companion_roster() -> void:
	companion_overlay.hide()
	_set_underlay_controls_disabled(false)
	companion_roster_visibility_changed.emit(false)


func is_companion_roster_open() -> bool:
	return companion_overlay.visible


func _set_underlay_controls_disabled(disabled: bool) -> void:
	for button in [btn_end_turn, btn_companions, btn_rest, btn_save, btn_menu, btn_settings, btn_sheet]:
		button.disabled = disabled
	if not disabled:
		btn_companions.disabled = PartyManager.get_companion_ids().is_empty()


func _on_companion_lifecycle_changed(message: String) -> void:
	update_hud()
	add_log("[color=khaki]%s[/color]" % message)

func _update_party_sidebar() -> void:
	# Clear sidebar list
	for child in player_list_container.get_children():
		child.queue_free()

	# Build status cards from the active party, including companions. Local
	# seats are ownership metadata; they are not the party roster.
	var party_members := PartyManager.get_active_party_members()
	var active_idx := PlayerManager.active_player_index
	
	for member in party_members:
		var char_data: Character = member.get("character")
		if char_data == null:
			continue
		var owner_index := int(member.get("owner_player_index", -1))
		var slot_id := str(member.get("slot_id", ""))
		var player := PlayerManager.get_player(owner_index) if owner_index >= 0 else {}

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
		var leader_mark := "★ " if slot_id == PartyManager.leader_slot_id else ""
		var seat_label := "Seat %d" % (owner_index + 1) if owner_index >= 0 else "Unassigned"
		name_lbl.text = "%s%s (%s) · %s" % [leader_mark, char_data.character_name, DataLoader.get_character_class(char_data.class_id).get("name", "Class"), seat_label]
		if owner_index == active_idx:
			name_lbl.text = "➔ " + name_lbl.text
			# Add subtle active color
			name_lbl.add_theme_color_override("font_color", Color.YELLOW)
		else:
			name_lbl.add_theme_color_override("font_color", player.get("color", Color.WHITE))
		vbox.add_child(name_lbl)
		if owner_index >= 0:
			var input_lbl := Label.new()
			input_lbl.text = PlayerManager.get_input_status(owner_index)
			input_lbl.add_theme_color_override("font_color", Color.LIGHT_GRAY if PlayerManager.is_player_connected(owner_index) else Color.ORANGE)
			vbox.add_child(input_lbl)

		var leader_button := Button.new()
		leader_button.text = "Leader" if slot_id == PartyManager.leader_slot_id else "Set leader"
		leader_button.disabled = slot_id == PartyManager.leader_slot_id
		leader_button.pressed.connect(_on_leader_button_pressed.bind(slot_id))
		vbox.add_child(leader_button)

		if bool(member.get("is_companion", false)) and PlayerManager.get_player_count() > 0:
			var assignment := OptionButton.new()
			assignment.text = "Assign companion"
			for seat in PlayerManager.get_player_count():
				assignment.add_item("Seat %d" % (seat + 1), seat)
			assignment.selected = owner_index if owner_index >= 0 else 0
			assignment.item_selected.connect(_on_assignment_selected.bind(slot_id, assignment))
			vbox.add_child(assignment)

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


func _on_leader_button_pressed(slot_id: String) -> void:
	if PartyManager.set_leader(slot_id):
		update_hud()


func _on_assignment_selected(index: int, slot_id: String, assignment: OptionButton) -> void:
	if PartyManager.assign_slot_to_seat(slot_id, index):
		update_hud()


func _on_device_binding_changed(_player_index: int, _device_id: int, _connected: bool) -> void:
	update_hud()


func _update_active_player_display() -> void:
	var player := PlayerManager.get_active_player()
	var char_data: Character = player.get("character")
	if char_data == null: return

	active_player_name.text = "Current Turn: %s" % char_data.character_name
	active_player_name.add_theme_color_override("font_color", player.get("color", Color.WHITE))
	
	active_player_stats.text = "Race: %s | Level: %d | Speed: %d hexes | %s" % [
		DataLoader.get_race(char_data.race_id).get("name", ""),
		char_data.level,
		char_data.get_speed(),
		PlayerManager.get_input_status(PlayerManager.active_player_index)
	]


## Show the active campaign objective (demo arc) so the player knows the goal.
func _update_objective() -> void:
	if objective_label == null:
		return
	var objectives := GameManager.get_campaign_objectives()
	if objectives.is_empty():
		objective_label.text = "Objective: Free roam"
		return
	objective_label.text = "Objective: " + " • ".join(objectives)
