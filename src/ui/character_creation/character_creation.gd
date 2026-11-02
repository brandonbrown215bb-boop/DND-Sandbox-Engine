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
var _ability_generation_method := "point_buy"
var _ability_generation_seed := 0
var _ability_generation_results: Array[int] = []
var _ability_generation_assignments: Array[String] = []
var _stat_method_row_added := false
var _generation_assignment_row: HBoxContainer
var _generation_assignment_controls: Array[OptionButton] = []
var _standard_method_button: Button
var _random_method_button: Button
var _point_buy_method_button: Button
var selected_equipment: Array[String] = []
var barbarian_starting_equipment_choice := "equipment"
var cleric_creation_choices := {"skills": ["", ""], "tools": [], "equipment": "equipment"}
var cleric_divine_order := ""
var bard_creation_choices := {"skills": ["", "", ""], "tools": ["", "", ""], "instrument": "", "equipment": "equipment"}
## G2: source-defined skill/tool picks for other classes that opt in by data.
var class_creation_choices := {}

# List of loaded data
var races_data: Array = []
var classes_data: Array = []
var _name_input: LineEdit
var _detail_title: Label
var _detail_text: RichTextLabel
var _live_summary: Label
var _step_buttons: Array[Button] = []
const CLASS_INTROS := {
	"barbarian": "A fierce frontline warrior whose rage fuels strength and endurance.",
	"bard": "A versatile performer who supports allies with inspiration and magic.",
	"cleric": "A divine spellcaster who protects the party and channels sacred power.",
	"druid": "A guardian of nature who blends primal magic with animal forms.",
	"fighter": "A weapon specialist with durable defenses and flexible combat training.",
	"monk": "A mobile martial artist who turns discipline into swift strikes.",
	"paladin": "An armored champion who combines weapon attacks with divine magic.",
	"ranger": "A wilderness hunter who mixes tracking, weapon skill, and nature magic.",
	"rogue": "A precise opportunist who relies on agility, skills, and well-timed attacks.",
	"sorcerer": "An innate spellcaster who shapes magic through personal power.",
	"warlock": "A pact-bound spellcaster whose patron grants distinctive arcane gifts.",
	"wizard": "A scholarly spellcaster who builds a broad repertoire through a spellbook."
}

func _ready() -> void:
	_build_grimoire_spread()
	# Connect buttons
	btn_back.pressed.connect(_on_back_pressed)
	btn_next.pressed.connect(_on_next_pressed)
	btn_rand.pressed.connect(_on_randomize_pressed)

	races_data = DataLoader.get_all_races()
	classes_data = DataLoader.get_all_classes()

	# Start with Player 0
	current_player_idx = 0
	_start_player_creation()


func _build_grimoire_spread() -> void:
	var profile := UiThemeProfile.current()
	profile.apply(self)
	profile.style(self)
	$Background.color = profile.color("surface/base")
	var outer := $Panel/MarginContainer/VBoxContainer
	step_label.hide()
	var steps := HBoxContainer.new()
	outer.add_child(steps)
	outer.move_child(steps, 1)
	for index in 5:
		var button := Button.new()
		button.text = ["Species", "Class", "Abilities", "Equipment", "Review"][index]
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size.y = 44
		button.pressed.connect(func():
			if index <= int(current_step):
				current_step = index as CreationStep
				_update_step_ui()
		)
		steps.add_child(button)
		_step_buttons.append(button)
	var area := $Panel/MarginContainer/VBoxContainer/ContentArea
	var spread := HBoxContainer.new()
	spread.add_theme_constant_override("separation", 24)
	spread.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(spread)
	outer.move_child(spread, 3)
	area.reparent(spread)
	area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	area.size_flags_stretch_ratio = 1.5
	area.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	spread.add_child(VSeparator.new())
	var page := PanelContainer.new()
	page.theme_type_variation = "OverlayPanel"
	page.custom_minimum_size.x = 360
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spread.add_child(page)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	page.add_child(box)
	var label := Label.new()
	label.text = "Character name"
	box.add_child(label)
	_name_input = LineEdit.new()
	_name_input.custom_minimum_size.y = 44
	_name_input.max_length = 48
	_name_input.text_changed.connect(func(value):
		selected_name = value
		_check_next_step_validity()
		_refresh_spread()
	)
	box.add_child(_name_input)
	box.add_child(HSeparator.new())
	_detail_title = Label.new()
	_detail_title.theme_type_variation = "TitleLabel"
	box.add_child(_detail_title)
	_detail_text = RichTextLabel.new()
	_detail_text.bbcode_enabled = true
	_detail_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(_detail_text)
	_live_summary = Label.new()
	_live_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_live_summary)
	race_grid.columns = 2
	class_grid.columns = 2
	for grid in [race_grid, class_grid]:
		grid.add_theme_constant_override("v_separation", 8)
	var frame := GrimoireFrame.new()
	frame.prominent = true
	$Panel.add_child(frame)
	btn_next.theme_type_variation = "PrimaryButton"
	$Panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	resized.connect(_resize_spread)
	_resize_spread()

func _resize_spread() -> void:
	$Panel.size = Vector2(minf(1280, size.x - 48), minf(840, size.y - 48))
	$Panel.position = (size - $Panel.size) / 2


func _refresh_spread() -> void:
	if _detail_text == null: return
	var race := DataLoader.get_race(selected_race_id)
	var cls := DataLoader.get_character_class(selected_class_id)
	var selection: Dictionary = race if current_step == CreationStep.RACE else cls
	_detail_title.text = str(selection.get("name", "Your adventurer"))
	_detail_text.text = str(selection.get("description", "Select an option to see what it gives your character."))
	if current_step == CreationStep.RACE:
		var benefits: Array[String] = []
		for ability in race.get("ability_bonuses", {}):
			benefits.append("%s +%s" % [ability, race.ability_bonuses[ability]])
		if not benefits.is_empty(): _detail_text.text += "\n\n" + ", ".join(benefits)
	elif not cls.is_empty():
		_detail_text.text = str(CLASS_INTROS.get(selected_class_id, cls.get("description", "")))
		var armor: Array = cls.get("armor_proficiencies", [])
		_detail_text.text += "\n\nPrimary ability: %s\nHit die: %s\nArmor training: %s" % [cls.get("primary_ability", "See class details"), cls.get("hit_die", ""), ", ".join(armor) if not armor.is_empty() else "None"]
		var gear: Array[String] = []
		for id in _starting_gear_ids():
			gear.append(str(DataLoader.get_item(id).get("name", id)))
		_detail_text.text += "\n\nStarting equipment\n" + ", ".join(gear)
	_live_summary.text = "%s\n%s · %s\n%s" % [selected_name, race.get("name", "Species pending"), cls.get("name", "Class pending"), "Starting gear: %d items" % _starting_gear_ids().size()]


func _start_player_creation() -> void:

	var player := PlayerManager.get_player(current_player_idx)
	current_player_label.text = "%s's Character Creation" % player.get("name", "Player")
	
	# Generate a random default name matching player index
	selected_name = "Hero %d" % (current_player_idx + 1)
	_name_input.text = selected_name
	selected_race_id = ""
	selected_class_id = ""
	selected_stats = AbilityScores.new()
	_ability_generation_method = "point_buy"
	_ability_generation_seed = 0
	_ability_generation_results.clear()
	_ability_generation_assignments.clear()
	selected_origin_feat = ""
	origin_feat_picks = []
	if _generation_assignment_row != null: _generation_assignment_row.hide()
	selected_equipment.clear()
	barbarian_starting_equipment_choice = "equipment"
	cleric_creation_choices = {"skills": ["", ""], "tools": [], "equipment": "equipment"}
	cleric_divine_order = ""
	bard_creation_choices = {"skills": ["", "", ""], "tools": ["", "", ""], "instrument": "", "equipment": "equipment"}
	class_creation_choices = {}

	current_step = CreationStep.RACE
	_update_step_ui()


func _update_step_ui() -> void:
	var previous_focus := get_viewport().gui_get_focus_owner()
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
			step_label.text = "Step 4: Skills, Instruments and Equipment" if selected_class_id == "bard" else "Step 4: Divine Order, Skills and Equipment" if selected_class_id == "cleric" else "Step 4: Starting Equipment"
			equip_panel.visible = true
			_build_equipment_ui()
			_refresh_spread()
		CreationStep.SUMMARY:
			step_label.text = "Step 5: Review Summary"
			summary_panel.visible = true
			_build_summary_ui()
	for index in _step_buttons.size():
		if index == CreationStep.EQUIPMENT:
			_step_buttons[index].text = "Training & gear" if selected_class_id in ["bard", "cleric"] else "Equipment"
		_step_buttons[index].disabled = index > int(current_step)
		_step_buttons[index].theme_type_variation = "PrimaryButton" if index == int(current_step) else "Button"
	_refresh_spread()
	if is_instance_valid(previous_focus) and previous_focus.is_visible_in_tree():
		previous_focus.grab_focus()


func _check_next_step_validity() -> void:
	var is_valid := false
	match current_step:
		CreationStep.RACE:
			is_valid = not selected_race_id.is_empty()
		CreationStep.CLASS:
			is_valid = not selected_class_id.is_empty()
		CreationStep.STATS:
			is_valid = _ability_choice_error().is_empty()
		CreationStep.EQUIPMENT:
			is_valid = _ability_choice_error().is_empty() and _creation_choice_error().is_empty()
		CreationStep.SUMMARY:
			is_valid = _ability_choice_error().is_empty() and _creation_choice_error().is_empty()
	
	btn_next.disabled = not is_valid
	if selected_name.strip_edges().is_empty():
		btn_next.disabled = true


# --- UI Builders ---

func _build_race_selection_ui() -> void:
	if race_grid.get_child_count() > 0:
		for button in race_grid.get_children():
			button.theme_type_variation = "PrimaryButton" if button.get_meta("choice_id") == selected_race_id else "Button"
		return
	for record in races_data:
		var id := str(record.get("id", ""))
		var button := Button.new()
		button.text = str(record.get("name", id))
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size = Vector2(0, 48)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.theme_type_variation = "PrimaryButton" if selected_race_id == id else "Button"
		button.set_meta("choice_id", id)
		button.tooltip_text = str(record.get("description", ""))
		button.pressed.connect(func():
			selected_race_id = id
			_update_step_ui()
		)
		race_grid.add_child(button)


func _build_class_selection_ui() -> void:
	if class_grid.get_child_count() > 0:
		for button in class_grid.get_children():
			button.theme_type_variation = "PrimaryButton" if button.get_meta("choice_id") == selected_class_id else "Button"
		return
	for record in classes_data:
		var id := str(record.get("id", ""))
		var button := Button.new()
		button.text = str(record.get("name", id))
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.icon = UiThemeProfile.current().icons.get("spell" if not record.get("spell_list_ids", []).is_empty() else "attack")
		button.custom_minimum_size = Vector2(0, 48)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.theme_type_variation = "PrimaryButton" if selected_class_id == id else "Button"
		button.set_meta("choice_id", id)
		button.tooltip_text = str(CLASS_INTROS.get(id, record.get("description", "")))
		button.pressed.connect(func():
			if selected_class_id != id:
				bard_creation_choices = {"skills": ["", "", ""], "tools": ["", "", ""], "instrument": "", "equipment": "equipment"}
				cleric_creation_choices = {"skills": ["", ""], "tools": [], "equipment": "equipment"}
				cleric_divine_order = ""
				class_creation_choices = {}
			selected_class_id = id
			_update_step_ui()
		)
		class_grid.add_child(button)


var _stat_row_refs: Dictionary = {}  # ability -> {val: Label, dec: Button, inc: Button}


func _build_stats_point_buy_ui() -> void:
	# Build the stat rows ONCE. Rapid + / - clicks must not destroy and
	# recreate the buttons (queue_free mid-click storm drops every click but
	# the first). We keep stable references and only refresh their labels /
	# disabled state in _refresh_stats_ui().
	if not _stat_row_refs.is_empty():
		_refresh_stats_ui()
		return
	if not _stat_method_row_added:
		var method_row := HBoxContainer.new()
		_point_buy_method_button = Button.new()
		_point_buy_method_button.text = "Point Buy"
		_point_buy_method_button.pressed.connect(func(): _apply_point_buy_method())
		method_row.add_child(_point_buy_method_button)
		_standard_method_button = Button.new()
		_standard_method_button.text = "Use Standard Array"
		_standard_method_button.pressed.connect(func(): _apply_ability_array(AbilityScores.STANDARD_ARRAY, "standard_array", 0))
		method_row.add_child(_standard_method_button)
		_random_method_button = Button.new()
		_random_method_button.text = "Roll 4d6, drop lowest"
		_random_method_button.pressed.connect(func():
			_ability_generation_seed = int(Time.get_unix_time_from_system()) ^ randi()
			_ability_generation_results = AbilityScores.roll_generation(_ability_generation_seed)
			_apply_ability_array(_ability_generation_results, "random_4d6", _ability_generation_seed)
		)
		method_row.add_child(_random_method_button)
		stat_rows.add_child(method_row)
		stat_rows.move_child(method_row, 0)
		_generation_assignment_row = HBoxContainer.new()
		_generation_assignment_row.visible = false
		for result_index in 6:
			var assignment := OptionButton.new()
			assignment.name = "GenerationAssignment%d" % result_index
			for ability in AbilityScores.ABILITIES: assignment.add_item(ability)
			var assigned_ability: String = _ability_generation_assignments[result_index] if result_index < _ability_generation_assignments.size() else AbilityScores.ABILITIES[result_index]
			assignment.select(AbilityScores.ABILITIES.find(assigned_ability))
			assignment.item_selected.connect(func(_selected): _apply_generation_assignment())
			_generation_assignment_controls.append(assignment)
			_generation_assignment_row.add_child(assignment)
		stat_rows.add_child(_generation_assignment_row)
		stat_rows.move_child(_generation_assignment_row, 1)
		_stat_method_row_added = true
		var allowed_methods: Array = GameManager.active_campaign.get("ability_generation_methods", ["point_buy", "standard_array", "random_4d6"])
		_point_buy_method_button.disabled = "point_buy" not in allowed_methods
		_standard_method_button.disabled = "standard_array" not in allowed_methods
		_random_method_button.disabled = "random_4d6" not in allowed_methods

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
		btn_dec.custom_minimum_size = Vector2(44, 44)
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
		btn_inc.custom_minimum_size = Vector2(44, 44)
		btn_inc.pressed.connect(func():
			selected_stats.set_score(ability, selected_stats.get_score(ability) + 1)
			_refresh_stats_ui()
		)
		row.add_child(btn_inc)

		stat_rows.add_child(row)
		_stat_row_refs[ability] = {"val": lbl_val, "dec": btn_dec, "inc": btn_inc}

	_refresh_stats_ui()


func _apply_ability_array(scores: Array, method: String, seed_value: int) -> void:
	if scores.size() != 6: return
	if method not in GameManager.active_campaign.get("ability_generation_methods", ["point_buy", "standard_array", "random_4d6"]): return
	# The roll button passes our own results array; copy it before clearing state.
	var captured_scores := scores.duplicate()
	_ability_generation_method = method
	_ability_generation_seed = seed_value
	_ability_generation_results.clear()
	for score in captured_scores: _ability_generation_results.append(int(score))
	_ability_generation_assignments.clear()
	for ability in AbilityScores.ABILITIES: _ability_generation_assignments.append(ability)
	for index in _generation_assignment_controls.size(): _generation_assignment_controls[index].select(index)
	_generation_assignment_row.visible = true
	_apply_generation_assignment()


func _apply_generation_assignment() -> void:
	var assignments: Array = []
	for control in _generation_assignment_controls: assignments.append(str(control.get_item_text(control.selected)))
	_ability_generation_assignments.assign(assignments)
	var result := AbilityScores.assign_generation(_ability_generation_results, assignments)
	if not bool(result.get("success", false)):
		stat_points_label.text = str(result.get("message", "Assign each generated score once."))
		btn_next.disabled = true
		return
	_ability_generation_assignments.clear()
	for ability in assignments: _ability_generation_assignments.append(str(ability))
	for ability in AbilityScores.ABILITIES: selected_stats.set_score(ability, int(result.scores[ability]))
	_refresh_stats_ui()


func _ability_generation_record() -> Dictionary:
	# Durable choices use plain arrays, matching their JSON-restored form.
	var results: Array = []
	results.append_array(_ability_generation_results)
	var assignments: Array = []
	if _ability_generation_method != "point_buy": assignments.append_array(_ability_generation_assignments)
	return {"method": _ability_generation_method, "seed": _ability_generation_seed, "results": results, "assigned_abilities": assignments}


func _apply_point_buy_method() -> void:
	if "point_buy" not in GameManager.active_campaign.get("ability_generation_methods", ["point_buy", "standard_array", "random_4d6"]): return
	_ability_generation_method = "point_buy"
	_ability_generation_seed = 0
	_ability_generation_results.clear()
	_ability_generation_assignments.clear()
	_generation_assignment_row.visible = false
	selected_stats = AbilityScores.new()
	_refresh_stats_ui()


## Update the stat row labels / disabled states in place (no rebuild), so
## rapid clicks on the same + / - button all register.
func _refresh_stats_ui() -> void:
	if _generation_assignment_row != null:
		_generation_assignment_row.visible = _ability_generation_method != "point_buy"
		for index in _generation_assignment_controls.size():
			var control := _generation_assignment_controls[index]
			var assigned: String = _ability_generation_assignments[index] if index < _ability_generation_assignments.size() else AbilityScores.ABILITIES[index]
			control.select(AbilityScores.ABILITIES.find(assigned))
			control.tooltip_text = "Assign score %d" % _ability_generation_results[index] if index < _ability_generation_results.size() else ""
	var remaining_points := AbilityScores.POINT_BUY_TOTAL - selected_stats.get_point_buy_cost()
	stat_points_label.text = "Remaining Points: %d / %d" % [remaining_points, AbilityScores.POINT_BUY_TOTAL] if _ability_generation_method == "point_buy" else ("Standard Array: %s" % ", ".join(AbilityScores.ABILITIES.map(func(a): return str(selected_stats.get_score(a)))) if _ability_generation_method == "standard_array" else "Seeded rolls: %s (seed %d)" % [", ".join(_ability_generation_results.map(func(v): return str(v))), _ability_generation_seed])
	for ability in AbilityScores.ABILITIES:
		var refs: Dictionary = _stat_row_refs.get(ability, {})
		if refs.is_empty():
			continue
		var val := selected_stats.get_score(ability)
		var mod := AbilityScores.get_modifier(val)
		refs["val"].text = "%d (%s)" % [val, AbilityScores.format_modifier(mod)]
		refs["dec"].disabled = _ability_generation_method != "point_buy" or val <= 8
		var cost_now = AbilityScores.POINT_BUY_COSTS.get(val, 0)
		var cost_next = AbilityScores.POINT_BUY_COSTS.get(val + 1, 999)
		var cost_diff = cost_next - cost_now
		refs["inc"].disabled = _ability_generation_method != "point_buy" or val >= 15 or remaining_points < cost_diff
	_check_next_step_validity()
	_refresh_spread()
	var allowed_methods: Array = GameManager.active_campaign.get("ability_generation_methods", ["point_buy", "standard_array", "random_4d6"])
	if _point_buy_method_button != null: _point_buy_method_button.disabled = "point_buy" not in allowed_methods
	if _standard_method_button != null: _standard_method_button.disabled = "standard_array" not in allowed_methods
	if _random_method_button != null: _random_method_button.disabled = "random_4d6" not in allowed_methods
	var error := _ability_choice_error()
	if not error.is_empty(): stat_points_label.text = error


func _ability_choice_error() -> String:
	if _ability_generation_method not in GameManager.active_campaign.get("ability_generation_methods", ["point_buy", "standard_array", "random_4d6"]): return "Choose an ability method permitted by this campaign."
	if _ability_generation_method == "point_buy": return "" if selected_stats.is_valid_point_buy() else "Choose valid point-buy scores."
	var record := _ability_generation_record()
	var error := AbilityScores.saved_generation_error({"creation_choices": {"ability_generation": record}})
	if not error.is_empty(): return "Assign each generated score to a different ability."
	var assigned := AbilityScores.assign_generation(_ability_generation_results, _ability_generation_assignments)
	return "" if assigned.get("scores", {}) == selected_stats.to_dict() else "Assign all six generated scores."


func _creation_choices() -> Dictionary:
	var choices: Dictionary = cleric_creation_choices if selected_class_id == "cleric" else bard_creation_choices if selected_class_id == "bard" else _class_choices()
	choices["ability_generation"] = _ability_generation_record()
	return choices


## Empty picks sized from the selected class's skill_choices/tool_choices.
func _class_choices() -> Dictionary:
	if class_creation_choices.is_empty():
		var data := DataLoader.get_character_class(selected_class_id)
		var skills: Array = []
		var tools: Array = []
		skills.resize(int(data.get("skill_choices", {}).get("pick", 0)))
		skills.fill("")
		var preset := ClassProgression.preset_creation_skills(selected_class_id, selected_race_id)
		for index in mini(preset.size(), skills.size()):
			skills[index] = preset[index]
		tools.resize(int(data.get("tool_choices", {}).get("pick", 0)))
		tools.fill("")
		class_creation_choices = {"skills": skills, "tools": tools, "equipment": "equipment"}
	return class_creation_choices


func _creation_choice_error() -> String:
	var error := _class_choice_error()
	return error if not error.is_empty() else _origin_feat_error()


func _class_choice_error() -> String:
	if PermanentProgressionRules.enabled(selected_class_id):
		var error := PermanentProgressionRules.definition_error(DataLoader.get_character_class(selected_class_id))
		if not error.is_empty(): return error
		if not PermanentProgressionRules.can_fit(Character.new(), PermanentProgressionRules.expected_receipts([selected_class_id])):
			return "Starting equipment will not fit in the backpack. Choose another class."
		return ""
	if selected_class_id == "cleric" and cleric_divine_order not in ["protector", "thaumaturge"]:
		return "Choose your Divine Order."
	return ClassProgression.creation_choices_error(selected_class_id, selected_race_id, _creation_choices()) if ClassProgression.uses_creation_choices(selected_class_id) else ""


func _starting_gear_ids() -> Array:
	if PermanentProgressionRules.enabled(selected_class_id):
		var gear: Array = []
		if not PermanentProgressionRules.definition_error(DataLoader.get_character_class(selected_class_id)).is_empty(): return gear
		for receipt in PermanentProgressionRules.expected_receipts([selected_class_id]).values():
			for grant in receipt.grants:
				if grant.type == "equipment_grant":
					for _copy in int(grant.quantity): gear.append(grant.item_id)
		return gear
	if _equipment_mode() == "gold":
		return []
	var gear: Array = ClassProgression.creation_starting_equipment(selected_class_id, _creation_choices() if ClassProgression.uses_creation_choices(selected_class_id) else {})
	if selected_class_id == "bard" and not str(bard_creation_choices["instrument"]).is_empty():
		gear.append(str(bard_creation_choices["instrument"]))
	return gear


## Equipment-versus-GP option: Barbarian keeps its own selector; other
## creation-choice classes read the generic class-data choice.
func _equipment_mode() -> String:
	if selected_class_id == "barbarian":
		return barbarian_starting_equipment_choice
	return str(_creation_choices()["equipment"]) if ClassProgression.uses_creation_choices(selected_class_id) else "equipment"


func _starting_gold() -> int:
	if selected_class_id == "barbarian":
		return 75 if barbarian_starting_equipment_choice == "gold" else 15
	var data := DataLoader.get_character_class(selected_class_id)
	return int(data.get("starting_gold_alternative", 0)) if _creation_choices()["equipment"] == "gold" else int(data.get("starting_gold", 0))


func _instrument_names(ids: Array) -> Array[String]:
	var names: Array[String] = []
	for id in ids:
		names.append(str(DataLoader.get_item(str(id)).get("name", id)))
	return names


## Batch 051: Origin feat (SRD 5.2.1 p.83), offered when Origin feats are loaded.
## G4: no feat is preselected (there is no background step yet), and a feat with
## proficiency_choices (Skilled, p.87) shows one picker per pick.
var selected_origin_feat := ""
var origin_feat_picks: Array = []

func _origin_feat_probe() -> Character:
	# Reviewer: build the probe exactly as Confirm builds the character, so every
	# creation grant (e.g. the Fighter's Athletics/Perception) is already held.
	var probe := Character.new()
	if selected_stats == null or selected_race_id.is_empty() or selected_class_id.is_empty() or (PermanentProgressionRules.enabled(selected_class_id) and not _class_choice_error().is_empty()):
		probe.level = 1
		probe.race_id = selected_race_id
		probe.ability_scores = selected_stats.duplicate_scores() if selected_stats != null else AbilityScores.new()
		for skill in DataLoader.get_race(selected_race_id).get("proficiencies", []): probe.skill_proficiencies.append(str(skill))
		return probe
	probe.initialize(selected_name, selected_race_id, selected_class_id, selected_stats.duplicate_scores(), _equipment_mode(), _creation_choices() if ClassProgression.uses_creation_choices(selected_class_id) else {})
	if selected_class_id == "cleric": ClassProgression.choose_feature_option(probe, "cleric_divine_order", cleric_divine_order)
	return probe

func _origin_feat_pick_dict() -> Dictionary:
	var choice: Dictionary = DataLoader.get_feat(str(FeatRules.selection(selected_origin_feat).feat_id)).get("proficiency_choices", {}) if not selected_origin_feat.is_empty() else {}
	var picks := {"skills": [], "tools": []}
	for value in origin_feat_picks:
		if str(value) in choice.get("skills", []): picks.skills.append(str(value))
		else: picks.tools.append(str(value))
	if choice.is_empty(): return {}
	return picks

func _origin_feat_error() -> String:
	if selected_origin_feat.is_empty(): return ""
	var choice: Dictionary = DataLoader.get_feat(str(FeatRules.selection(selected_origin_feat).feat_id)).get("proficiency_choices", {})
	if choice.is_empty(): return ""
	if origin_feat_picks.size() != int(choice.pick) or origin_feat_picks.has(""): return "Choose %d skills or tools for your Origin feat." % int(choice.pick)
	return FeatRules.proficiency_picks_error(_origin_feat_probe(), str(FeatRules.selection(selected_origin_feat).feat_id), _origin_feat_pick_dict())

func _build_origin_feat_choice() -> void:
	var probe := _origin_feat_probe()
	var options := FeatRules.options(probe, "origin")
	if options.is_empty():
		selected_origin_feat = ""
		origin_feat_picks = []
		return
	if selected_origin_feat not in options:
		selected_origin_feat = ""
		origin_feat_picks = []
	var heading := Label.new()
	heading.text = "Choose your Origin feat"
	equip_list.add_child(heading)
	var picker := OptionButton.new()
	picker.name = "OriginFeatPicker"
	picker.add_item("No Origin feat")
	picker.set_item_metadata(0, "")
	for id in options:
		picker.add_item(FeatRules.label(id))
		picker.set_item_metadata(picker.item_count - 1, id)
		if id == selected_origin_feat: picker.select(picker.item_count - 1)
	picker.item_selected.connect(func(index: int):
		var chosen := str(picker.get_item_metadata(index))
		if chosen != selected_origin_feat: origin_feat_picks = []
		selected_origin_feat = chosen
		_build_equipment_ui()
		_check_next_step_validity()
	)
	equip_list.add_child(picker)
	var choice: Dictionary = DataLoader.get_feat(str(FeatRules.selection(selected_origin_feat).feat_id)).get("proficiency_choices", {}) if not selected_origin_feat.is_empty() else {}
	if choice.is_empty(): return
	if origin_feat_picks.size() != int(choice.pick):
		origin_feat_picks = []
		for _i in int(choice.pick): origin_feat_picks.append("")
	var status := Label.new()
	status.name = "OriginFeatProficiencyStatus"
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.text = _origin_feat_error()
	equip_list.add_child(status)
	for index in int(choice.pick):
		var selector := OptionButton.new()
		selector.name = "OriginFeatProficiency%d" % (index + 1)
		selector.add_item("Choose a skill or tool")
		selector.set_item_metadata(0, "")
		for value in choice.get("skills", []) + choice.get("tools", []):
			var is_skill: bool = value in choice.get("skills", [])
			selector.add_item(str(value) if is_skill else str(DataLoader.get_item(str(value)).get("name", value)))
			var item_index := selector.item_count - 1
			selector.set_item_metadata(item_index, str(value))
			if str(value) in (probe.skill_proficiencies if is_skill else probe.tool_proficiencies): selector.set_item_disabled(item_index, true)
			if origin_feat_picks[index] == str(value): selector.select(item_index)
		selector.item_selected.connect(func(item_index: int):
			origin_feat_picks[index] = str(selector.get_item_metadata(item_index))
			status.text = _origin_feat_error()
			_check_next_step_validity()
		)
		equip_list.add_child(selector)


func _build_class_creation_choices() -> void:
	var data := DataLoader.get_character_class(selected_class_id)
	var status := Label.new()
	status.name = "%sChoiceStatus" % selected_class_id.capitalize()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.text = _creation_choice_error()
	equip_list.add_child(status)
	if selected_class_id == "cleric":
		var order := OptionButton.new()
		order.name = "ClericDivineOrder"
		order.add_item("Choose Divine Order")
		order.set_item_metadata(0, "")
		for id in ["protector", "thaumaturge"]:
			order.add_item("Protector — Martial weapons and Heavy Armor" if id == "protector" else "Thaumaturge — extra cantrip and Arcana/Religion bonus")
			order.set_item_metadata(order.item_count - 1, id)
			if cleric_divine_order == id:
				order.select(order.item_count - 1)
		order.item_selected.connect(func(index: int):
			cleric_divine_order = str(order.get_item_metadata(index))
			status.text = _creation_choice_error()
			_check_next_step_validity()
		)
		equip_list.add_child(order)
	for field in (["skills", "tools"] if int(data.get("tool_choices", {}).get("pick", 0)) > 0 else ["skills"]):
		var heading := Label.new()
		heading.text = "Choose %d skills" % int(data["skill_choices"]["pick"]) if field == "skills" else "Choose three instrument proficiencies" if selected_class_id == "bard" else "Choose %d tool proficiency" % int(data["tool_choices"]["pick"])
		equip_list.add_child(heading)
		var values: Array = data["skill_choices" if field == "skills" else "tool_choices"]["from"]
		for index in int(data["skill_choices" if field == "skills" else "tool_choices"]["pick"]):
			var selector := OptionButton.new()
			selector.name = "%s%s%d" % [selected_class_id.capitalize(),"Skill" if field == "skills" else "Tool", index + 1]
			selector.add_item("Choose a skill" if field == "skills" else "Choose an instrument proficiency" if selected_class_id == "bard" else "Choose a tool proficiency")
			selector.set_item_metadata(0, "")
			for value in values:
				selector.add_item(str(value) if field == "skills" else str(DataLoader.get_item(value).get("name", value)))
				var item_index := selector.item_count - 1
				selector.set_item_metadata(item_index, value)
				if field == "skills" and value in DataLoader.get_race(selected_race_id).get("proficiencies", []):
					selector.set_item_disabled(item_index, true)
				if field == "tools" and value in data.get("tool_proficiency_grants", []):
					selector.set_item_disabled(item_index, true)
				if _creation_choices()[field][index] == value:
					selector.select(item_index)
			selector.item_selected.connect(func(item_index: int):
				_creation_choices()[field][index] = str(selector.get_item_metadata(item_index))
				status.text = _creation_choice_error()
				_check_next_step_validity()
			)
			equip_list.add_child(selector)
	if not data.has("starting_gold_alternative") or selected_class_id == "barbarian":
		return # Full equipment-pack choices are outside G2; Barbarian keeps its own A/B selector.
	var equipment := OptionButton.new()
	equipment.name = "%sStartingEquipment" % selected_class_id.capitalize()
	equipment.add_item("Equipment and %d GP" % int(data["starting_gold"]))
	equipment.add_item("%d GP" % int(data["starting_gold_alternative"]))
	equipment.select(1 if _creation_choices()["equipment"] == "gold" else 0)
	equipment.item_selected.connect(func(index: int):
		_creation_choices()["equipment"] = "gold" if index == 1 else "equipment"
		_build_equipment_ui()
		_check_next_step_validity()
		_refresh_spread()
	)
	equip_list.add_child(equipment)
	if selected_class_id == "bard" and _creation_choices()["equipment"] == "equipment":
		var instrument := OptionButton.new()
		instrument.name = "BardStartingInstrument"
		instrument.add_item("Choose your starting instrument")
		instrument.set_item_metadata(0, "")
		for id in data["tool_choices"]["from"]:
			instrument.add_item(str(DataLoader.get_item(id).get("name", id)))
			instrument.set_item_metadata(instrument.item_count - 1, id)
			if id == _creation_choices()["instrument"]:
				instrument.select(instrument.item_count - 1)
		instrument.item_selected.connect(func(index: int):
			_creation_choices()["instrument"] = str(instrument.get_item_metadata(index))
			_build_equipment_ui()
			_check_next_step_validity()
			_refresh_spread()
		)
		equip_list.add_child(instrument)


func _build_equipment_ui() -> void:
	# Clear list
	for child in equip_list.get_children():
		equip_list.remove_child(child) # G4: rebuilt pickers keep their names.
		child.queue_free()
	if PermanentProgressionRules.enabled(selected_class_id) and not _creation_choice_error().is_empty():
		var status := Label.new()
		status.text = _creation_choice_error()
		status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		equip_list.add_child(status)

	# Keep class choices in this existing equipment step.
	var cls := DataLoader.get_character_class(selected_class_id)
	var gear_list: Array = _starting_gear_ids()
	if ClassProgression.uses_creation_choices(selected_class_id):
		_build_class_creation_choices()
	_build_origin_feat_choice()
	if selected_class_id == "barbarian":
		var choice := OptionButton.new()
		choice.name = "BarbarianStartingEquipment"
		choice.add_item("Equipment and 15 GP")
		choice.add_item("75 GP")
		choice.select(1 if barbarian_starting_equipment_choice == "gold" else 0)
		choice.item_selected.connect(func(index: int):
			barbarian_starting_equipment_choice = "gold" if index == 1 else "equipment"
			_build_equipment_ui()
			_refresh_spread()
		)
		equip_list.add_child(choice)
		if barbarian_starting_equipment_choice == "gold":
			gear_list = []

	selected_equipment.clear()
	for gear_id in gear_list:
		selected_equipment.append(str(gear_id))

	var info_lbl := Label.new()
	info_lbl.text = "Your class provides the following starting gear:"
	if selected_class_id in ["barbarian", "bard", "cleric"]:
		info_lbl.text = "Starting gold: %d GP" % _starting_gold()
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
			stats_text += "[color=%s](+%d Species)[/color]" % [UiThemeProfile.current().color("state/success").to_html(), racial_bonus]
		stats_text += "\n"
	
	summary_stats_label.text = stats_text

	selected_equipment.assign(_starting_gear_ids())
	if selected_class_id == "bard":
		summary_stats_label.text += "\nSkills: %s\nInstrument proficiencies: %s" % [", ".join(bard_creation_choices["skills"]), ", ".join(_instrument_names(bard_creation_choices["tools"]))]
	if selected_class_id == "cleric":
		summary_stats_label.text += "\nSkills: %s\nDivine Order: %s" % [", ".join(cleric_creation_choices["skills"]), cleric_divine_order.capitalize()]
	if selected_class_id not in ["bard", "cleric"] and ClassProgression.uses_creation_choices(selected_class_id):
		var tools: Array = class_data.get("tool_proficiency_grants", []).duplicate()
		tools.append_array(_class_choices()["tools"])
		summary_stats_label.text += "\nSkills: %s\nTool proficiencies: %s" % [", ".join(_class_choices()["skills"]), ", ".join(_instrument_names(tools))]
	# Render items list
	var equip_text := ""
	for gear_id in selected_equipment:
		var item := DataLoader.get_item(gear_id)
		equip_text += "- %s (%s)\n" % [item.get("name", gear_id), item.get("description", "")]
	summary_equip_label.text = equip_text
	if PermanentProgressionRules.enabled(selected_class_id) and not _creation_choice_error().is_empty():
		summary_equip_label.text += _creation_choice_error()
	if selected_class_id == "barbarian" or ClassProgression.uses_creation_choices(selected_class_id):
		summary_equip_label.text += "Gold: %d GP" % _starting_gold()


# --- Navigation handlers ---

func _on_back_pressed() -> void:
	if current_step > CreationStep.RACE:
		current_step = (current_step - 1) as CreationStep
		_update_step_ui()


func _on_next_pressed() -> void:
	_check_next_step_validity()
	if btn_next.disabled:
		return
	if current_step < CreationStep.SUMMARY:
		current_step = (current_step + 1) as CreationStep
		_update_step_ui()
	else:
		# Save character for the current player
		_confirm_and_save_character()


func _confirm_and_save_character() -> void:
	if not _ability_choice_error().is_empty():
		current_step = CreationStep.STATS
		_update_step_ui()
		return
	if not _creation_choice_error().is_empty():
		current_step = CreationStep.EQUIPMENT
		_update_step_ui()
		return
	var character := Character.new()
	character.initialize(selected_name, selected_race_id, selected_class_id, selected_stats.duplicate_scores(), _equipment_mode(), _creation_choices() if ClassProgression.uses_creation_choices(selected_class_id) else {})
	character.creation_choices["ability_generation"] = _ability_generation_record()
	if character.class_id != selected_class_id:
		return
	
	if selected_class_id == "cleric":
		ClassProgression.choose_feature_option(character, "cleric_divine_order", cleric_divine_order)
	if not selected_origin_feat.is_empty() and not FeatRules.choose_origin(character, selected_origin_feat, _origin_feat_pick_dict()).success:
		current_step = CreationStep.EQUIPMENT # Refused before the character joins the party.
		_update_step_ui()
		return
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
	if selected_name.begins_with("Hero ") or selected_name.strip_edges().is_empty():
		selected_name = "%s %s" % [prefixes.pick_random(), suffixes.pick_random()]
		_name_input.text = selected_name

	# Random race & class
	var random_race: Dictionary = races_data.pick_random()
	var random_class: Dictionary = classes_data.pick_random()
	selected_race_id = random_race["id"]
	selected_class_id = random_class["id"]

	# Randomize using a method permitted by this campaign.
	var allowed_methods: Array = GameManager.active_campaign.get("ability_generation_methods", ["point_buy", "standard_array", "random_4d6"])
	var scores: Array
	_ability_generation_results.clear()
	_ability_generation_assignments.clear()
	if "standard_array" in allowed_methods:
		_ability_generation_method = "standard_array"
		_ability_generation_seed = 0
		_ability_generation_results.assign(AbilityScores.STANDARD_ARRAY)
		scores = AbilityScores.STANDARD_ARRAY.duplicate()
		scores.shuffle()
		for score in _ability_generation_results:
			var ability_index := scores.find(score)
			_ability_generation_assignments.append(AbilityScores.ABILITIES[ability_index])
	elif "random_4d6" in allowed_methods:
		_ability_generation_method = "random_4d6"
		_ability_generation_seed = int(Time.get_unix_time_from_system()) ^ randi()
		_ability_generation_results = AbilityScores.roll_generation(_ability_generation_seed)
		scores = _ability_generation_results.duplicate()
		for ability in AbilityScores.ABILITIES: _ability_generation_assignments.append(ability)
	elif "point_buy" in allowed_methods:
		_ability_generation_method = "point_buy"
		_ability_generation_seed = 0
		scores = [15, 14, 12, 10, 10, 8]
		scores.shuffle()
	else:
		return
	
	selected_stats = AbilityScores.new()
	for i in AbilityScores.ABILITIES.size():
		selected_stats.set_score(AbilityScores.ABILITIES[i], scores[i])

	if selected_class_id == "bard":
		bard_creation_choices = ClassProgression.default_creation_choices("bard", selected_race_id)
		var skill_options: Array = random_class["skill_choices"]["from"].duplicate()
		var racial: Array = random_race.get("proficiencies", [])
		skill_options = skill_options.filter(func(skill): return skill not in racial)
		skill_options.shuffle()
		var tool_options: Array = random_class["tool_choices"]["from"].duplicate()
		tool_options.shuffle()
		bard_creation_choices["skills"] = skill_options.slice(0, 3)
		bard_creation_choices["tools"] = tool_options.slice(0, 3)
		bard_creation_choices["instrument"] = tool_options.pick_random()

	if selected_class_id == "cleric":
		cleric_creation_choices = ClassProgression.default_creation_choices("cleric", selected_race_id)
		cleric_divine_order = ["protector", "thaumaturge"].pick_random()
	if selected_class_id not in ["bard", "cleric"] and ClassProgression.uses_creation_choices(selected_class_id):
		class_creation_choices = {}
		var picks := _class_choices()
		var skill_pool: Array = random_class.get("skill_choices", {}).get("from", []).filter(func(skill): return skill not in random_race.get("proficiencies", []))
		skill_pool.shuffle()
		picks["skills"] = skill_pool.slice(0, picks["skills"].size())
		var tool_pool: Array = random_class.get("tool_choices", {}).get("from", []).filter(func(tool): return tool not in random_class.get("tool_proficiency_grants", []))
		tool_pool.shuffle()
		picks["tools"] = tool_pool.slice(0, picks["tools"].size())
	# Select starting equipment
	selected_equipment.clear()
	var gear_list: Array = _starting_gear_ids()
	for gear_id in gear_list:
		selected_equipment.append(str(gear_id))

	# Advance straight to the summary page to show the results
	current_step = CreationStep.SUMMARY
	_update_step_ui()
