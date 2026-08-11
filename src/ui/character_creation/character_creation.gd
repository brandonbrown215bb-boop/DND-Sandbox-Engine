## Character Creation State UI Controller
## Coordinates the step-by-step hot-seat character creation for all players.
## Steps: Race -> Class -> Ability Scores (Point Buy) -> Equipment -> Summary.
extends Control

# Step enums
enum CreationStep { RACE, CLASS, STATS, EQUIPMENT, SUMMARY }

# Node references
@onready var title_label: Label = $Panel/MarginContainer/VBoxContainer/Header/TitleLabel
@onready var step_label: Label = $Panel/MarginContainer/VBoxContainer/Header/StepLabel
@onready var current_player_label: Label = $Panel/MarginContainer/VBoxContainer/Header/CurrentPlayerLabel

# Step panels
@onready var race_panel: ScrollContainer = $Panel/MarginContainer/VBoxContainer/ContentArea/RacePanel
@onready var class_panel: ScrollContainer = $Panel/MarginContainer/VBoxContainer/ContentArea/ClassPanel
@onready var stats_panel: MarginContainer = $Panel/MarginContainer/VBoxContainer/ContentArea/StatsPanel
@onready var equip_panel: ScrollContainer = $Panel/MarginContainer/VBoxContainer/ContentArea/EquipPanel
@onready var summary_panel: PanelContainer = $Panel/MarginContainer/VBoxContainer/ContentArea/SummaryPanel

# Card lists / Grids
@onready var race_grid: GridContainer = $Panel/MarginContainer/VBoxContainer/ContentArea/RacePanel/RaceGrid
@onready var class_grid: GridContainer = $Panel/MarginContainer/VBoxContainer/ContentArea/ClassPanel/ClassGrid
@onready var equip_list: VBoxContainer = $Panel/MarginContainer/VBoxContainer/ContentArea/EquipPanel/EquipList

# Stat inputs (point buy)
@onready var stat_points_label: Label = $Panel/MarginContainer/VBoxContainer/ContentArea/StatsPanel/VBoxContainer/PointsLabel
@onready var stat_rows: VBoxContainer = $Panel/MarginContainer/VBoxContainer/ContentArea/StatsPanel/VBoxContainer/StatRows

# Summary Info
@onready var summary_name_label: Label = $Panel/MarginContainer/VBoxContainer/ContentArea/SummaryPanel/VBoxContainer/GridContainer/ValName
@onready var summary_race_label: Label = $Panel/MarginContainer/VBoxContainer/ContentArea/SummaryPanel/VBoxContainer/GridContainer/ValRace
@onready var summary_class_label: Label = $Panel/MarginContainer/VBoxContainer/ContentArea/SummaryPanel/VBoxContainer/GridContainer/ValClass
@onready var summary_stats_label: RichTextLabel = $Panel/MarginContainer/VBoxContainer/ContentArea/SummaryPanel/VBoxContainer/GridContainer/ValStats
@onready var summary_equip_label: RichTextLabel = $Panel/MarginContainer/VBoxContainer/ContentArea/SummaryPanel/VBoxContainer/GridContainer/ValEquip

# Navigation
@onready var btn_back: Button = $Panel/MarginContainer/VBoxContainer/Footer/BtnBack
@onready var btn_next: Button = $Panel/MarginContainer/VBoxContainer/Footer/BtnNext
@onready var btn_rand: Button = $Panel/MarginContainer/VBoxContainer/Footer/BtnRand

# Internal tracking state
var current_player_idx: int = 0
var current_step: CreationStep = CreationStep.RACE

# Temporary selections for the active player being built
var selected_name: String = ""
var selected_race_id: String = ""
var selected_class_id: String = ""
var selected_stats: AbilityScores = AbilityScores.new()
var selected_equipment: Array[String] = []

# List of loaded data
var races_data: Array = []
var classes_data: Array = []

func _ready() -> void:
	# Connect buttons
	btn_back.pressed.connect(_on_back_pressed)
	btn_next.pressed.connect(_on_next_pressed)
	btn_rand.pressed.connect(_on_randomize_pressed)

	races_data = DataLoader.get_all_races()
	classes_data = DataLoader.get_all_classes()

	# Start with Player 0
	current_player_idx = 0
	_start_player_creation()


func _start_player_creation() -> void:

	var player := PlayerManager.get_player(current_player_idx)
	current_player_label.text = "%s's Character Creation" % player.get("name", "Player")
	
	# Generate a random default name matching player index
	selected_name = "Hero %d" % (current_player_idx + 1)
	selected_race_id = ""
	selected_class_id = ""
	selected_stats = AbilityScores.new()
	selected_equipment.clear()

	current_step = CreationStep.RACE
	_update_step_ui()


func _update_step_ui() -> void:
	# Hide all step panels
	race_panel.visible = false
	class_panel.visible = false
	stats_panel.visible = false
	equip_panel.visible = false
	summary_panel.visible = false

	# Configure footer buttons
	btn_back.disabled = (current_step == CreationStep.RACE)
	btn_next.text = "Next" if current_step != CreationStep.SUMMARY else "Confirm Character"
	
	# Validate step transitions
	_check_next_step_validity()

	match current_step:
		CreationStep.RACE:
			step_label.text = "Step 1: Choose Race"
			race_panel.visible = true
			_build_race_selection_ui()
		CreationStep.CLASS:
			step_label.text = "Step 2: Choose Class"
			class_panel.visible = true
			_build_class_selection_ui()
		CreationStep.STATS:
			step_label.text = "Step 3: Distribute Ability Scores (Point Buy)"
			stats_panel.visible = true
			_build_stats_point_buy_ui()
		CreationStep.EQUIPMENT:
			step_label.text = "Step 4: Starting Equipment"
			equip_panel.visible = true
			_build_equipment_ui()
		CreationStep.SUMMARY:
			step_label.text = "Step 5: Review Summary"
			summary_panel.visible = true
			_build_summary_ui()


func _check_next_step_validity() -> void:
	var is_valid := false
	match current_step:
		CreationStep.RACE:
			is_valid = not selected_race_id.is_empty()
		CreationStep.CLASS:
			is_valid = not selected_class_id.is_empty()
		CreationStep.STATS:
			is_valid = selected_stats.is_valid_point_buy()
		CreationStep.EQUIPMENT:
			is_valid = true # Equipment choice is automatically populated/valid
		CreationStep.SUMMARY:
			is_valid = true
	
	btn_next.disabled = not is_valid


# --- UI Builders ---

func _build_race_selection_ui() -> void:
	# Clear grid
	for child in race_grid.get_children():
		child.queue_free()

	for race in races_data:
		var race_id: String = race["id"]
		var panel := PanelContainer.new()
		panel.custom_minimum_size = Vector2(250, 300)
		
		# Set styling/theme later, for now simple layouts
		var vbox := VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 10)
		panel.add_child(vbox)

		var name_lbl := Label.new()
		name_lbl.text = race.get("name", "")
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(name_lbl)

		var desc_lbl := RichTextLabel.new()
		desc_lbl.bbcode_enabled = true
		desc_lbl.text = race.get("description", "")
		desc_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
		vbox.add_child(desc_lbl)

		var select_btn := Button.new()
		select_btn.text = "Select" if selected_race_id != race_id else "Selected"
		select_btn.disabled = (selected_race_id == race_id)
		select_btn.pressed.connect(func():
			selected_race_id = race_id
			_update_step_ui()
		)
		vbox.add_child(select_btn)

		race_grid.add_child(panel)


func _build_class_selection_ui() -> void:
	# Clear grid
	for child in class_grid.get_children():
		child.queue_free()

	for cls in classes_data:
		var class_id: String = cls["id"]
		var panel := PanelContainer.new()
		panel.custom_minimum_size = Vector2(250, 300)
		
		var vbox := VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 10)
		panel.add_child(vbox)

		var name_lbl := Label.new()
		name_lbl.text = cls.get("name", "")
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(name_lbl)

		var desc_lbl := RichTextLabel.new()
		desc_lbl.bbcode_enabled = true
		desc_lbl.text = cls.get("description", "")
		desc_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
		vbox.add_child(desc_lbl)

		var select_btn := Button.new()
		select_btn.text = "Select" if selected_class_id != class_id else "Selected"
		select_btn.disabled = (selected_class_id == class_id)
		select_btn.pressed.connect(func():
			selected_class_id = class_id
			_update_step_ui()
		)
		vbox.add_child(select_btn)

		class_grid.add_child(panel)


var _stat_row_refs: Dictionary = {}  # ability -> {val: Label, dec: Button, inc: Button}


func _build_stats_point_buy_ui() -> void:
	# Build the stat rows ONCE. Rapid + / - clicks must not destroy and
	# recreate the buttons (queue_free mid-click storm drops every click but
	# the first). We keep stable references and only refresh their labels /
	# disabled state in _refresh_stats_ui().
	if not _stat_row_refs.is_empty():
		_refresh_stats_ui()
		return

	var remaining_points := AbilityScores.POINT_BUY_TOTAL - selected_stats.get_point_buy_cost()
	stat_points_label.text = "Remaining Points: %d / %d" % [remaining_points, AbilityScores.POINT_BUY_TOTAL]

	for ability in AbilityScores.ABILITIES:
		var val := selected_stats.get_score(ability)
		var mod := AbilityScores.get_modifier(val)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 15)

		var lbl_name := Label.new()
		lbl_name.text = ability
		lbl_name.custom_minimum_size = Vector2(60, 0)
		row.add_child(lbl_name)

		var btn_dec := Button.new()
		btn_dec.text = "-"
		btn_dec.custom_minimum_size = Vector2(30, 30)
		btn_dec.pressed.connect(func():
			selected_stats.set_score(ability, selected_stats.get_score(ability) - 1)
			_refresh_stats_ui()
		)
		row.add_child(btn_dec)

		var lbl_val := Label.new()
		lbl_val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl_val.custom_minimum_size = Vector2(80, 0)
		row.add_child(lbl_val)

		var btn_inc := Button.new()
		btn_inc.text = "+"
		btn_inc.custom_minimum_size = Vector2(30, 30)
		btn_inc.pressed.connect(func():
			selected_stats.set_score(ability, selected_stats.get_score(ability) + 1)
			_refresh_stats_ui()
		)
		row.add_child(btn_inc)

		stat_rows.add_child(row)
		_stat_row_refs[ability] = {"val": lbl_val, "dec": btn_dec, "inc": btn_inc}

	_refresh_stats_ui()


## Update the stat row labels / disabled states in place (no rebuild), so
## rapid clicks on the same + / - button all register.
func _refresh_stats_ui() -> void:
	var remaining_points := AbilityScores.POINT_BUY_TOTAL - selected_stats.get_point_buy_cost()
	stat_points_label.text = "Remaining Points: %d / %d" % [remaining_points, AbilityScores.POINT_BUY_TOTAL]
	for ability in AbilityScores.ABILITIES:
		var refs: Dictionary = _stat_row_refs.get(ability, {})
		if refs.is_empty():
			continue
		var val := selected_stats.get_score(ability)
		var mod := AbilityScores.get_modifier(val)
		refs["val"].text = "%d (%s)" % [val, AbilityScores.format_modifier(mod)]
		refs["dec"].disabled = (val <= 8)
		var cost_now = AbilityScores.POINT_BUY_COSTS.get(val, 0)
		var cost_next = AbilityScores.POINT_BUY_COSTS.get(val + 1, 999)
		var cost_diff = cost_next - cost_now
		refs["inc"].disabled = (val >= 15 or remaining_points < cost_diff)
	_check_next_step_validity()


func _build_equipment_ui() -> void:
	# Clear list
	for child in equip_list.get_children():
		child.queue_free()

	# In streamlined 5e, equipment is pre-determined by class start_equipment JSON
	var cls := DataLoader.get_character_class(selected_class_id)
	var gear_list: Array = cls.get("starting_equipment", [])

	selected_equipment.clear()
	for gear_id in gear_list:
		selected_equipment.append(str(gear_id))

	var info_lbl := Label.new()
	info_lbl.text = "Your class provides the following starting gear:"
	equip_list.add_child(info_lbl)

	for gear_id in selected_equipment:
		var item := DataLoader.get_item(gear_id)
		var item_name: String = item.get("name", gear_id)
		var item_desc: String = item.get("description", "")
		
		var panel := PanelContainer.new()
		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 20)
		panel.add_child(hbox)

		var name_lbl := Label.new()
		name_lbl.text = item_name
		name_lbl.custom_minimum_size = Vector2(150, 0)
		hbox.add_child(name_lbl)

		var desc_lbl := Label.new()
		desc_lbl.text = item_desc
		desc_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		hbox.add_child(desc_lbl)

		equip_list.add_child(panel)


func _build_summary_ui() -> void:
	var race_data := DataLoader.get_race(selected_race_id)
	var class_data := DataLoader.get_character_class(selected_class_id)

	summary_name_label.text = selected_name
	summary_race_label.text = race_data.get("name", "")
	summary_class_label.text = class_data.get("name", "")

	# Render stats list
	var stats_text := ""
	for ability in AbilityScores.ABILITIES:
		var base := selected_stats.get_score(ability)
		
		# Show racial bonus if any
		var racial_bonus: int = int(race_data.get("ability_bonuses", {}).get(ability, 0))
		var total := base + racial_bonus
		var mod := AbilityScores.get_modifier(total)

		stats_text += "%s: %d (%s) " % [ability, total, AbilityScores.format_modifier(mod)]
		if racial_bonus > 0:
			stats_text += "[color=green](+%d Race)[/color]" % racial_bonus
		stats_text += "\n"
	
	summary_stats_label.text = stats_text

	# Render items list
	var equip_text := ""
	for gear_id in selected_equipment:
		var item := DataLoader.get_item(gear_id)
		equip_text += "- %s (%s)\n" % [item.get("name", gear_id), item.get("description", "")]
	summary_equip_label.text = equip_text


# --- Navigation handlers ---

func _on_back_pressed() -> void:
	if current_step > CreationStep.RACE:
		current_step = (current_step - 1) as CreationStep
		_update_step_ui()


func _on_next_pressed() -> void:
	if current_step < CreationStep.SUMMARY:
		current_step = (current_step + 1) as CreationStep
		_update_step_ui()
	else:
		# Save character for the current player
		_confirm_and_save_character()


func _confirm_and_save_character() -> void:
	var character := Character.new()
	character.initialize(selected_name, selected_race_id, selected_class_id, selected_stats.duplicate_scores())
	
	PlayerManager.set_player_character(current_player_idx, character)
	PartyManager.register_player_character(current_player_idx, character)
	print("[CharacterCreation] Saved character for player %d: %s (%s %s)" % [current_player_idx, selected_name, character.race_id, character.class_id])

	# Advance to next player or complete creation state
	if current_player_idx < PlayerManager.get_player_count() - 1:
		current_player_idx += 1
		_start_player_creation()
	else:
		# All players finished! Transition to overworld
		GameManager.on_character_creation_complete()


func _on_randomize_pressed() -> void:
	# Random name
	var prefixes := ["Thorin", "Alustriel", "Gimble", "Varis", "Lydia", "Brog", "Eldrin", "Sariel"]
	var suffixes := ["Stonebender", "Windrider", "Fireheart", "Shadowalker", "Oakshield", "Doomsmith"]
	selected_name = "%s %s" % [prefixes.pick_random(), suffixes.pick_random()]

	# Random race & class
	var random_race: Dictionary = races_data.pick_random()
	var random_class: Dictionary = classes_data.pick_random()
	selected_race_id = random_race["id"]
	selected_class_id = random_class["id"]

	# Distribute stats randomly but validly using standard array
	var scores := AbilityScores.STANDARD_ARRAY.duplicate()
	scores.shuffle()
	
	selected_stats = AbilityScores.new()
	for i in AbilityScores.ABILITIES.size():
		selected_stats.set_score(AbilityScores.ABILITIES[i], scores[i])

	# Select starting equipment
	selected_equipment.clear()
	var gear_list: Array = random_class.get("starting_equipment", [])
	for gear_id in gear_list:
		selected_equipment.append(str(gear_id))

	# Advance straight to the summary page to show the results
	current_step = CreationStep.SUMMARY
	_update_step_ui()
