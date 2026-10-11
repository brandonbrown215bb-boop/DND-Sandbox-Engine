## Combat HUD Controller
## Manages combat interfaces: action selection, spell registers, logs, and initiative track.
class_name CombatHUD
extends BaseHUD

signal action_selected(action_type: String, extra_data: Dictionary)
signal cancel_pressed
signal movement_mode_selected(mode: String)
signal flight_altitude_delta(delta_feet: int)

func _resolve_node(primary: String, fallback: String = "", fallback2: String = "") -> Node:
	for p in [primary, fallback, fallback2]:
		if not p.is_empty():
			if has_node(p):
				return get_node(p)
			if has_node("Root/" + p):
				return get_node("Root/" + p)
	return find_child(primary.get_file(), true, false)

# Node references
@onready var action_panel: PanelContainer = _resolve_node("ActionDock/DockBox/ActionMenu", "MarginContainer/HBoxContainer/ControlArea/VBoxContainer/ActionMenu") as PanelContainer
@onready var btn_attack: Button = _resolve_node("ActionDock/DockBox/ActionMenu/Margin/GridContainer/BtnAttack", "MarginContainer/HBoxContainer/ControlArea/VBoxContainer/ActionMenu/GridContainer/BtnAttack") as Button
@onready var btn_spell: Button = _resolve_node("ActionDock/DockBox/ActionMenu/Margin/GridContainer/BtnSpell", "MarginContainer/HBoxContainer/ControlArea/VBoxContainer/ActionMenu/GridContainer/BtnSpell") as Button
@onready var btn_dodge: Button = _resolve_node("ActionDock/DockBox/ActionMenu/Margin/GridContainer/BtnDodge", "MarginContainer/HBoxContainer/ControlArea/VBoxContainer/ActionMenu/GridContainer/BtnDodge") as Button
@onready var btn_end_turn: Button = _resolve_node("ActionDock/DockBox/ActionMenu/Margin/GridContainer/BtnEndTurn", "MarginContainer/HBoxContainer/ControlArea/VBoxContainer/ActionMenu/GridContainer/BtnEndTurn") as Button
@onready var btn_cancel: Button = _resolve_node("ActionDock/DockBox/ActionMenu/Margin/GridContainer/BtnCancel", "MarginContainer/HBoxContainer/ControlArea/VBoxContainer/ActionMenu/GridContainer/BtnCancel") as Button

@onready var spell_menu: PanelContainer = _resolve_node("ActionDock/DockBox/SpellMenu", "MarginContainer/HBoxContainer/ControlArea/VBoxContainer/SpellMenu") as PanelContainer
@onready var spell_list: ItemList = _resolve_node("ActionDock/DockBox/SpellMenu/Margin/VBox/SpellList", "MarginContainer/HBoxContainer/ControlArea/VBoxContainer/SpellMenu/SpellList") as ItemList
@onready var btn_cancel_spell: Button = _resolve_node("ActionDock/DockBox/SpellMenu/Margin/VBox/BtnCancelSpell", "MarginContainer/HBoxContainer/ControlArea/VBoxContainer/SpellMenu/BtnCancelSpell") as Button

@onready var btn_features: Button = _resolve_node("ActionDock/DockBox/ActionMenu/Margin/GridContainer/BtnFeatures", "MarginContainer/HBoxContainer/ControlArea/VBoxContainer/ActionMenu/GridContainer/BtnFeatures") as Button
@onready var btn_settings: Button = _resolve_node("ContextBar/Margin/HBox/RightBox/BtnSettings", "MarginContainer/HBoxContainer/ControlArea/VBoxContainer/BtnSettings") as Button
@onready var btn_sheet: Button = _resolve_node("ContextBar/Margin/HBox/RightBox/BtnSheet", "MarginContainer/HBoxContainer/ControlArea/VBoxContainer/BtnSheet") as Button
@onready var feature_menu: PanelContainer = _resolve_node("ActionDock/DockBox/FeatureMenu", "MarginContainer/HBoxContainer/ControlArea/VBoxContainer/FeatureMenu") as PanelContainer
@onready var feature_list: ItemList = _resolve_node("ActionDock/DockBox/FeatureMenu/Margin/VBox/FeatureList", "MarginContainer/HBoxContainer/ControlArea/VBoxContainer/FeatureMenu/FeatureList") as ItemList
@onready var btn_cancel_features: Button = _resolve_node("ActionDock/DockBox/FeatureMenu/Margin/VBox/BtnCancelFeatures", "MarginContainer/HBoxContainer/ControlArea/VBoxContainer/FeatureMenu/BtnCancelFeatures") as Button

@onready var info_label: Label = _resolve_node("Sidebar/Margin/ScrollContainer/SidebarContent/EntityInfo", "MarginContainer/HBoxContainer/Sidebar/ScrollContainer/SidebarContent/EntityInfo") as Label
@onready var entity_hp_bar = _resolve_node("Sidebar/Margin/ScrollContainer/SidebarContent/EntityHpBar", "MarginContainer/HBoxContainer/Sidebar/ScrollContainer/SidebarContent/EntityHpBar")
@onready var weapon_info: Label = _resolve_node("Sidebar/Margin/ScrollContainer/SidebarContent/WeaponInfo", "MarginContainer/HBoxContainer/Sidebar/ScrollContainer/SidebarContent/WeaponInfo") as Label
@onready var initiative_bar: RichTextLabel = _resolve_node("ContextBar/Margin/HBox/InitiativePanel/InitiativeBar", "MarginContainer/HBoxContainer/ControlArea/VBoxContainer/InitiativePanel/InitiativeBar") as RichTextLabel
@onready var hint_label: Label = _resolve_node("HintLabel", "ContextBar/Margin/HBox/LeftBox/HintLabel", "MarginContainer/HBoxContainer/ControlArea/VBoxContainer/HintLabel") as Label
@onready var mode_banner: Label = _resolve_node("ContextBar/Margin/HBox/LeftBox/ModeBanner", "MarginContainer/HBoxContainer/ControlArea/VBoxContainer/ModeBanner") as Label
@onready var dice_display: Node = null

## Rook's Touch: combat UI mode state machine. Centralizes the scattered
## show/hide of action menu vs spell/feature panels so the player always
## knows what state they're in (the banner makes it legible).
enum Mode { SELECT, SPELL, FEATURE }
var current_mode := Mode.SELECT

var active_character: Character
var spells_registered: Array[Dictionary] = []
var features_registered: Array[Dictionary] = []
var turn_budget: CombatTurnBudget = null
var light_marker_active := false
var mage_hand_active := false
var movement_mode_picker: OptionButton
var flight_altitude_label: Label
var flight_up_button: Button
var flight_down_button: Button


static func decision_prompt_labels(owner_label: String, reaction_id: String, ok_title: String = "", window_title: String = "") -> Dictionary:
	var real_reactions := ["uncanny_dodge", "shield", "counterspell", "opportunity_attack", "deflect_attacks"]
	if window_title.is_empty():
		window_title = ("Reaction — %s" if reaction_id in real_reactions else "Optional Feature — %s") % owner_label
	if ok_title.is_empty():
		ok_title = "Use Reaction" if reaction_id in real_reactions else "Confirm"
	return {"ok_title": ok_title, "window_title": window_title}


## Ask the owning local player whether to spend a reaction. The prompt is
## deliberately in-shell and names the seat so companion ownership is clear.
## Headless test mode declines immediately rather than waiting for input.
func request_reaction(owner_label: String, reaction_id: String, detail: String, decision_prompt: String = "Use this reaction?", ok_title: String = "", window_title: String = "") -> bool:
	if GameManager.test_mode:
		return false
	var labels := decision_prompt_labels(owner_label, reaction_id, ok_title, window_title)

	var dialog := ConfirmationDialog.new()
	dialog.title = labels["window_title"]
	dialog.dialog_text = "%s\n\n%s\n\n%s" % [owner_label, detail, decision_prompt]
	dialog.ok_button_text = labels["ok_title"]
	dialog.cancel_button_text = "Decline"
	add_child(dialog)
	ModalSurface.watch_window(dialog)
	dialog.popup_centered(Vector2i(460, 220))
	var decision := {"done": false, "accepted": false}
	dialog.confirmed.connect(func():
		decision["accepted"] = true
		decision["done"] = true
	)
	dialog.canceled.connect(func(): decision["done"] = true)
	dialog.close_requested.connect(func(): decision["done"] = true)
	var timeout := get_tree().create_timer(8.0)
	while not decision["done"] and timeout.time_left > 0.0:
		await get_tree().process_frame
	if not decision["done"]:
		add_log("[color=gray]%s feature prompt timed out and was declined.[/color]" % owner_label)
	dialog.hide()
	dialog.queue_free()
	return bool(decision["accepted"])


func _ready() -> void:
	# Connect base buttons
	btn_attack.pressed.connect(func(): action_selected.emit("attack", {}))
	btn_dodge.pressed.connect(func(): action_selected.emit("dodge", {}))
	btn_end_turn.pressed.connect(func(): action_selected.emit("end_turn", {}))
	btn_cancel.pressed.connect(_cancel_selection)

	# Connect spell panel
	btn_spell.pressed.connect(_show_spell_selection)
	btn_cancel_spell.pressed.connect(_cancel_selection)
	spell_list.item_selected.connect(_on_spell_selected)
	_connect_cancel_filter(spell_menu)

	# Connect features panel
	btn_features.pressed.connect(_show_feature_selection)
	btn_cancel_features.pressed.connect(_cancel_selection)
	feature_list.item_selected.connect(_on_feature_selected)
	_connect_cancel_filter(feature_menu)
	btn_settings.pressed.connect(func(): settings_pressed.emit())
	btn_sheet.pressed.connect(func(): sheet_pressed.emit())
	var right_box := _resolve_node("ContextBar/Margin/HBox/RightBox") as HBoxContainer
	if right_box != null:
		movement_mode_picker = OptionButton.new()
		movement_mode_picker.name = "MovementModePicker"
		movement_mode_picker.custom_minimum_size.x = 132
		movement_mode_picker.tooltip_text = "Choose the movement speed used this turn."
		right_box.add_child(movement_mode_picker)
		movement_mode_picker.item_selected.connect(func(index: int): movement_mode_selected.emit(str(movement_mode_picker.get_item_metadata(index))))
		flight_altitude_label = Label.new()
		flight_altitude_label.name = "FlightAltitudeLabel"
		right_box.add_child(flight_altitude_label)
		flight_up_button = Button.new()
		flight_up_button.name = "FlyUpButton"
		flight_up_button.text = "+5 ft"
		flight_up_button.tooltip_text = "Spend 5 feet of Fly Speed to gain 5 feet of altitude."
		right_box.add_child(flight_up_button)
		flight_up_button.pressed.connect(func(): flight_altitude_delta.emit(5))
		flight_down_button = Button.new()
		flight_down_button.name = "FlyDownButton"
		flight_down_button.text = "-5 ft"
		flight_down_button.tooltip_text = "Spend 5 feet of Fly Speed to lose 5 feet of altitude."
		right_box.add_child(flight_down_button)
		flight_down_button.pressed.connect(func(): flight_altitude_delta.emit(-5))
		flight_altitude_label.visible = false
		flight_up_button.visible = false
		flight_down_button.visible = false

	# Assign the inherited log_text (declared in BaseHUD, not re-declared here).
	log_text = _resolve_node("ActivityRail/Margin/ActivityContent/LogBox/LogText", "MarginContainer/HBoxContainer/ControlArea/VBoxContainer/LogBox/LogText") as RichTextLabel

	# Dice roll display: docked in the right activity rail, hide it on demand.
	dice_display = find_child("DiceRollDisplay", true, false)

	# Start in SELECT mode with the banner set.
	set_mode(Mode.SELECT)
	clear_logs()


func _connect_cancel_filter(node: Node) -> void:
	if node is Control:
		if not node.gui_input.is_connected(_on_child_gui_input):
			node.gui_input.connect(_on_child_gui_input)
	for child in node.get_children():
		_connect_cancel_filter(child)


func _on_child_gui_input(event: InputEvent) -> void:
	if is_cancel_event(event):
		_cancel_selection()
		get_viewport().set_input_as_handled()


static func is_cancel_event(event: InputEvent) -> bool:
	if event == null:
		return false
	if event.is_action_pressed("ui_cancel"):
		return true
	if event is InputEventKey and event.pressed and not event.echo:
		return event.keycode == KEY_ESCAPE
	return false


static func _is_cancel_event(event: InputEvent) -> bool:
	return is_cancel_event(event)


## Esc / escape-hatch handling: back out of any sub-menu to SELECT, AND cancel
## any in-progress combat targeting (attack/spell) via cancel_pressed.
func _input(event: InputEvent) -> void:
	if _is_cancel_event(event) and not ModalSurface.blocks_world():
		_cancel_selection()
		get_viewport().set_input_as_handled()


func _cancel_selection() -> void:
	cancel_pressed.emit()
	set_mode(Mode.SELECT)
	show_hint("Click a highlighted hex to move, or choose Attack or Spell. End Turn when finished.")


## The cost is selected now; nothing is spent until the caller accepts it.
func request_divine_smite(character: Character, owner_label: String, target_name: String) -> Dictionary:
	if GameManager.test_mode:
		return {}
	var options: Array[Dictionary] = []
	var labels: Array[String] = []
	if character.has_free_spell_cast("divine_smite"):
		options.append({"free_cast": true, "slot_level": 1})
		labels.append("Free cast — once per Long Rest")
	var levels: Array[int] = []
	for key in character.spell_slots:
		if int(key) >= 1 and int(character.spell_slots[key]) > 0:
			levels.append(int(key))
	levels.sort()
	for level in levels:
		options.append({"free_cast": false, "slot_level": level})
		labels.append("Level %d slot (%d remaining)" % [level, int(character.spell_slots[str(level)])])
	if options.is_empty():
		return {}
	var dialog := ConfirmationDialog.new()
	dialog.title = "Divine Smite — %s" % owner_label
	dialog.ok_button_text = "Cast Smite"
	dialog.cancel_button_text = "Decline"
	var content := VBoxContainer.new()
	var explanation := Label.new()
	explanation.text = "Hit %s. Cast Divine Smite using your Bonus Action?" % target_name
	content.add_child(explanation)
	var costs := OptionButton.new()
	for label in labels:
		costs.add_item(label)
	content.add_child(costs)
	dialog.add_child(content)
	add_child(dialog)
	ModalSurface.watch_window(dialog)
	var decision := {"done": false, "index": -1}
	dialog.confirmed.connect(func():
		decision["index"] = costs.selected
		decision["done"] = true
	)
	dialog.canceled.connect(func(): decision["done"] = true)
	dialog.close_requested.connect(func(): decision["done"] = true)
	dialog.popup_centered(Vector2i(540, 180))
	while not decision["done"]:
		await get_tree().process_frame
	dialog.hide()
	dialog.queue_free()
	return options[int(decision["index"])] if int(decision["index"]) >= 0 else {}


## Clear all logs.
## Enable or disable character controls.
## (log_text, clear_logs(), add_log() inherited from BaseHUD.)
func set_controls_disabled(disabled: bool) -> void:
	btn_attack.disabled = disabled
	btn_spell.disabled = disabled
	btn_features.disabled = disabled
	btn_dodge.disabled = disabled
	btn_end_turn.disabled = disabled
	if movement_mode_picker != null:
		movement_mode_picker.disabled = disabled
	if flight_up_button != null:
		flight_up_button.disabled = disabled or flight_up_button.disabled
	if flight_down_button != null:
		flight_down_button.disabled = disabled or flight_down_button.disabled


func set_movement_modes(character: Character, selected_mode: String, speed_overrides: Dictionary = {}) -> void:
	if movement_mode_picker == null:
		return
	movement_mode_picker.clear()
	for mode in ["walk", "climb", "swim", "fly"]:
		var speed_feet := int(speed_overrides.get(mode, character.movement_speed_feet(mode))) if character != null else 0
		if speed_feet <= 0:
			continue
		movement_mode_picker.add_item("%s · %d ft" % [mode.capitalize(), speed_feet])
		movement_mode_picker.set_item_metadata(movement_mode_picker.item_count - 1, mode)
		if mode == selected_mode:
			movement_mode_picker.select(movement_mode_picker.item_count - 1)
	movement_mode_picker.visible = movement_mode_picker.item_count > 1
	if movement_mode_picker.selected < 0 and movement_mode_picker.item_count > 0:
		movement_mode_picker.select(0)
	var room := LocalRoomCombat.room()
	var has_local_flight := character != null and not room.is_empty() and int(speed_overrides.get("fly", character.movement_speed_feet("fly"))) > 0
	var has_local_levitation := character != null and not room.is_empty() and SpellEffects.has_spell(character, "levitate")
	if flight_altitude_label != null:
		flight_altitude_label.visible = has_local_flight or has_local_levitation
		flight_up_button.visible = has_local_flight or has_local_levitation
		flight_down_button.visible = has_local_flight or has_local_levitation
		if has_local_flight or has_local_levitation:
			var position := LocalRoomRules.coord(room.get("party_positions", {}).get(character.character_id, [0, 0]))
			var altitude := LocalRoomRules.altitude_feet(room, character.character_id)
			var floor_feet := LocalRoomRules.elevation_feet(room, position)
			flight_altitude_label.text = "Alt %d / %d ft" % [altitude, LocalRoomRules.ceiling_feet(room, position)]
			flight_up_button.text = "Up 5 ft" if has_local_levitation else "Fly up 5 ft"
			flight_down_button.text = "Down 5 ft" if has_local_levitation else "Fly down 5 ft"
			flight_up_button.disabled = (selected_mode != "fly" if has_local_flight else false) or altitude + 10 > LocalRoomRules.ceiling_feet(room, position)
			flight_down_button.disabled = (selected_mode != "fly" if has_local_flight else false) or altitude <= floor_feet


## Show a contextual hint banner (dismissible guidance on first turns).
func show_hint(msg: String) -> void:
	mode_banner.tooltip_text = msg
	if get_node_or_null("Root") is VttShell:
		$Root.help_text = msg
		return
	if hint_label == null: return
	hint_label.text = msg
	hint_label.visible = true


## Hide the hint banner.
func hide_hint() -> void:
	if get_node_or_null("Root") is VttShell:
		return
	if hint_label == null: return
	hint_label.visible = false


## Hide the dice-roll overlay immediately (e.g. when an attack is cancelled
## while the previous roll is still fading, so it doesn't linger over the board).
func hide_dice() -> void:
	if dice_display != null and dice_display.has_method("hide"):
		dice_display.visible = false


## Set the combat UI mode. Centralizes panel visibility so the player
## always sees one coherent state. The banner echoes it.
func set_mode(m: Mode) -> void:
	current_mode = m
	action_panel.visible = (m == Mode.SELECT) or get_node_or_null("Root") is VttShell
	spell_menu.visible = (m == Mode.SPELL)
	feature_menu.visible = (m == Mode.FEATURE)
	match m:
		Mode.SELECT: mode_banner.text = "● SELECT — choose an action"
		Mode.SPELL:
			mode_banner.text = "● SPELL — pick a spell (Esc/Cancel to back out)"
			show_hint("Choose a spell. Its costs and targeting instructions appear before casting. Esc/Cancel to back out.")
		Mode.FEATURE:
			mode_banner.text = "● FEATURE — pick a class feature"
			show_hint("Choose a class feature. Unavailable choices explain their requirements. Esc/Cancel to back out.")
	# Brief emphasis pulse so the mode change reads at a glance.
	if mode_banner != null and is_instance_valid(mode_banner) and not Settings.reduce_ui_motion:
		var t := create_tween()
		t.tween_property(mode_banner, "modulate:a", 0.35, 0.0)
		t.tween_property(mode_banner, "modulate:a", 1.0, UiThemeProfile.current().feedback_duration)


## Draw/update the HUD.
func update_hud(active_char: Character, tracker: InitiativeTracker) -> void:
	active_character = active_char
	if get_node_or_null("Root") is VttShell:
		$Root.active_character = active_char
		$Root.refresh_party()
	set_mode(Mode.SELECT)
	_clear_spell_selection()
	show_hint("Click a highlighted hex to move, or choose Attack or Spell. End Turn when finished." if active_char != null else "Enemy turn — waiting for the next player.")
	_update_initiative_list(tracker)
	if active_char == null:
		mode_banner.text = "Enemy turn · " + str(tracker.get_active().get("name", "Resolving"))
	_update_sidebar_stats()
	_update_weapon_info(active_char)
	
	# Character.known_spells is the ownership boundary. Class tables describe
	# progression access; they are not an alternate per-turn spell inventory.
	btn_spell.disabled = active_char == null or active_char.known_spells.is_empty() or not DruidRules.can_cast_spells(active_char)
	btn_attack.disabled = active_char != null and active_char.class_id == "familiar"
	btn_spell.tooltip_text = "No spells available for this character." if btn_spell.disabled else "Choose a spell; its costs are shown before casting."
	btn_attack.tooltip_text = "Familiars cannot make weapon attacks." if btn_attack.disabled else "Choose a target for your equipped weapon."
	if not btn_attack.disabled:
		btn_attack.tooltip_text = weapon_info.text + "\nChoose a target for your equipped weapon."

	if active_char != null:
		# Disable features button if character has no active features
		var has_active := not FamiliarRules.state(active_char).is_empty()
		for f in active_char.features:
			if f.get("type", "") in ["active", "triggered"]:
				has_active = true
				break
		if active_char.class_id == "familiar":
			has_active = true
		if SpellEffects.goodberry_count_for_party(PartyManager.characters.values()) > 0:
			has_active = true
		btn_features.disabled = not has_active
		btn_features.tooltip_text = "No active class features available." if not has_active else "Choose a class feature; unavailable choices explain their requirements."


func _update_initiative_list(tracker: InitiativeTracker) -> void:
	var encounter := find_child("EncounterLabel", true, false) as Label
	if encounter != null:
		encounter.text = "Combat · Round %d" % tracker.current_round
	# Compact single-line strip: active combatant leads with a ➔, others follow.
	# Players gold, monsters red. Keeps the turn order legible without eating
	# vertical space (Rook's Touch: one row, not a stacked list).
	var chips: Array[String] = []
	for i in tracker.combatants.size():
		var c := tracker.combatants[i]
		var lead := "➔ " if i == tracker.active_index else ""
		var color := UiThemeProfile.current().color("accent/primary" if c["is_player"] else "state/danger").to_html()
		chips.append("%s[color=%s]%s[/color]" % [lead, color, c["name"]])
	initiative_bar.text = "[b]Order:[/b]  " + "  ›  ".join(chips)
	initiative_bar.tooltip_text = initiative_bar.get_parsed_text()


func _update_sidebar_stats() -> void:
	if active_character == null:
		info_label.text = "No active character."
		return

	var text := "Active Turn:\n%s\n" % active_character.character_name
	text += "Level %d %s\n" % [active_character.level, DataLoader.get_character_class(active_character.class_id).get("name", "")]
	text += "HP: %d / %d\n" % [active_character.current_hp, active_character.max_hp]
	text += "AC: %d\n" % active_character.get_ac()
	text += "Speed: %d hexes\n\n" % active_character.get_speed()
	if active_character.get_max_focus_points() > 0:
		text += "Focus: %d / %d\n\n" % [active_character.get_focus_points(), active_character.get_max_focus_points()]

	# List spell slots remaining
	if not active_character.spell_slots.is_empty():
		text += "Spell Slots:\n"
		for lvl in active_character.spell_slots:
			text += "Level %s: %d slots\n" % [lvl, active_character.spell_slots[lvl]]
		text += "\n"

	# List active class feature uses
	var has_uses := false
	for f in active_character.features:
		if f.get("type", "") == "active":
			if not has_uses:
				text += "Class Features:\n"
				has_uses = true
			var f_id = f["id"]
			var current_uses = active_character.feature_uses.get(f_id, 0)
			var max_uses = active_character.get_feature_max_uses(str(f_id), f)
			text += "- %s: %d/%d uses\n" % [f.get("name", f_id), current_uses, max_uses]
	if has_uses:
		text += "\n"

	var roll_token_lines := RollTokenRules.summary_lines(active_character)
	if not roll_token_lines.is_empty():
		text += "Roll Tokens:\n"
		for token_line in roll_token_lines:
			text += "- %s\n" % token_line
		text += "\n"

	var ward_lines := WardRules.summary_lines(active_character)
	if not ward_lines.is_empty():
		text += "Damage Wards:\n"
		for ward_line in ward_lines:
			text += "- %s\n" % ward_line
		text += "\n"

	# Active conditions
	if not active_character.conditions.is_empty():
		text += "Conditions:\n"
		for cond in active_character.conditions:
			text += "- %s (%d turns)\n" % [cond, active_character.conditions[cond]]

	info_label.text = text

	if entity_hp_bar != null and active_character != null:
		entity_hp_bar.configure("HP", active_character.max_hp)
		entity_hp_bar.set_value(active_character.current_hp)


## Show the active character's equipped weapon and its range in the sidebar.
func _update_weapon_info(active_char: Character) -> void:
	if weapon_info == null:
		return
	if active_char == null:
		weapon_info.text = "Weapon: —"
		return

	var weapon_id: String = active_char.inventory.get_weapon()
	var weapon := DataLoader.get_item(weapon_id)
	if weapon.is_empty():
		weapon_info.text = "Weapon: (unarmed)"
		return

	var w_range: int = int(weapon.get("range", 1))
	var reach_label := "melee (reach 1)" if w_range <= 1 else "range %d hexes" % w_range
	weapon_info.text = "Weapon: %s (%s)" % [weapon.get("name", weapon_id), reach_label]


# --- Spell Selection panel ---

func _clear_spell_selection() -> void:
	spells_registered.clear()
	spell_list.clear()


func _show_spell_selection() -> void:
	if active_character == null: return
	
	set_mode(Mode.SPELL)
	_clear_spell_selection()
	var setup := ClassTraining.setup_hint(active_character)
	if not setup.is_empty():
		show_hint(setup + " Open the character sheet outside combat to set this up.")

	# The active Character owns the complete per-turn spell inventory.
	var list_spells: Array = active_character.known_spells.duplicate()

	for s_id in list_spells:
		var spell_data := DataLoader.get_spell(s_id)
		if spell_data.is_empty(): continue

		var lvl: int = int(spell_data.get("level", 0))
		var lvl_str := "Cantrip" if lvl == 0 else "Lvl %d" % lvl
		var display_name := "%s (%s) - %s" % [spell_data.get("name", s_id), lvl_str, spell_data.get("damage_type", "utility")]
		var support := SpellSupport.availability(spell_data)
		if not support["available"]:
			spell_list.add_item(display_name + " [Unavailable]")
			var unavailable_index := spell_list.get_item_count() - 1
			spell_list.set_item_disabled(unavailable_index, true)
			spell_list.set_item_tooltip(unavailable_index, str(support["reason"]))
			spells_registered.append(spell_data)
			continue
		var arcanum_level := WarlockRules.arcanum_cast_level(active_character, str(s_id))
		var free_cast := active_character.free_spell_cast_feature(str(s_id)) if lvl > 0 else {}
		var free_cast_available := lvl > 0 and (not free_cast.is_empty() or arcanum_level > 0)
		
		# Gray out if no spell slots left
		var disabled := false
		if str(spell_data.get("trigger", "")) == "after_melee_weapon_or_unarmed_hit":
			disabled = true
			display_name += " [Cast after a melee hit]"
		if str(spell_data.get("casting_time", "action")) == "reaction":
			disabled = true
			display_name += " [Reaction only]"
		if lvl > 0:
			var slot_key := str(CombatAction.get_spell_slot_level(active_character, spell_data))
			var current_slots: int = active_character.spell_slots.get(slot_key, 0)
			var wizard_feature_cast := active_character.class_id == "wizard" and str(free_cast.get("feature_id", "")) in ["wizard_spell_mastery", "wizard_signature_spells"]
			if wizard_feature_cast and not disabled and (current_slots > 0 or bool(free_cast.get("effect", {}).get("at_will", false))):
				var free_spell := spell_data.duplicate(true)
				free_spell["_wizard_free_cast"] = true
				spell_list.add_item("%s (%s) — Cast without a slot" % [spell_data.get("name", s_id), lvl_str])
				var free_index := spell_list.get_item_count() - 1
				spell_list.set_item_disabled(free_index, false)
				spells_registered.append(free_spell)
				if current_slots > 0:
					var slot_spell := spell_data.duplicate(true)
					slot_spell["_force_spell_slot"] = true
					spell_list.add_item("%s (%s) — Use a spell slot" % [spell_data.get("name", s_id), lvl_str])
					var slot_index := spell_list.get_item_count() - 1
					spells_registered.append(slot_spell)
				continue
			var requires_arcanum := active_character.class_id == "warlock" and lvl > 5 and not free_cast_available
			if requires_arcanum or (current_slots <= 0 and not free_cast_available):
				disabled = true
				display_name += " [No eligible Arcanum]" if requires_arcanum else " [No slots]"
			elif free_cast_available:
				display_name += " [Free cast available]"

		spell_list.add_item(display_name)
		var item_idx := spell_list.get_item_count() - 1
		spell_list.set_item_disabled(item_idx, disabled)
		spells_registered.append(spell_data)


func _hide_spell_selection() -> void:
	set_mode(Mode.SELECT)


func _on_spell_selected(index: int) -> void:
	if index < 0 or index >= spells_registered.size(): return
	if spell_list.is_item_disabled(index): return
	var spell := spells_registered[index]
	_hide_spell_selection()
	action_selected.emit("cast_spell", {"spell": spell})


# --- Feature Selection panel ---

func _show_feature_selection() -> void:
	if active_character == null: return
	
	set_mode(Mode.FEATURE)
	feature_list.clear()
	features_registered.clear()
	var held_wand_id := active_character.inventory.equipped_instance_id(Inventory.Slot.HANDS)
	var held_wand := active_character.inventory.get_instance(held_wand_id)
	if str(held_wand.get("definition_id", "")) == "wand_of_magic_missiles":
		var charges := int(held_wand.get("state", {}).get("charges", 0))
		for charge_count in range(1, mini(3, charges) + 1):
			var disabled := turn_budget != null and not turn_budget.can_spend("magic_action")
			feature_list.add_item("Wand of Magic Missiles (%d charge%s, Magic Action)%s" % [charge_count, "" if charge_count == 1 else "s", " [Unavailable]" if disabled else ""])
			feature_list.set_item_disabled(feature_list.get_item_count() - 1, disabled)
			features_registered.append({"id": "wand_of_magic_missiles_activate", "instance_id": held_wand_id, "charges": charge_count, "type": "active"})
	var berries_available := SpellEffects.goodberry_count_for_party(PartyManager.characters.values())
	if berries_available > 0:
		var berry_disabled := turn_budget != null and not turn_budget.can_spend("bonus_action")
		feature_list.add_item("Eat Goodberry (%d remaining, Bonus Action)" % berries_available + (" [Unavailable]" if berry_disabled else ""))
		feature_list.set_item_disabled(feature_list.get_item_count() - 1, berry_disabled)
		feature_list.set_item_tooltip(feature_list.get_item_count() - 1, "A party member can eat one magically created berry to regain 1 Hit Point.")
		features_registered.append({"id": "goodberry_eat", "name": "Eat Goodberry", "type": "active", "action_cost": "bonus_action"})
	if light_marker_active:
		feature_list.add_item("Dismiss Light (Action)")
		features_registered.append({"id": "dismiss_light", "name": "Dismiss Light", "type": "active", "action_cost": "action"})
	if SpellEffects.has_spell(active_character, "detect_magic"):
		var detect_disabled := turn_budget != null and not turn_budget.can_spend("magic_action")
		feature_list.add_item("Inspect Magic Auras (Magic Action)" + (" [Unavailable]" if detect_disabled else ""))
		feature_list.set_item_disabled(feature_list.get_item_count() - 1, detect_disabled)
		feature_list.set_item_tooltip(feature_list.get_item_count() - 1, "Spend a Magic action to reveal schools on nearby modeled magical effects.")
		features_registered.append({"id": "detect_magic_inspect", "name": "Inspect Magic Auras", "type": "active", "action_cost": "magic_action"})
	if mage_hand_active:
		var control_disabled := turn_budget != null and not turn_budget.can_spend("magic_action")
		feature_list.add_item("Control Mage Hand (Magic Action)" + (" [Unavailable]" if control_disabled else ""))
		feature_list.set_item_disabled(feature_list.get_item_count() - 1, control_disabled)
		feature_list.set_item_tooltip(feature_list.get_item_count() - 1, "Move the spectral hand up to 30 feet, keeping it within 30 feet of you.")
		features_registered.append({"id": "mage_hand_control", "name": "Control Mage Hand", "type": "active", "action_cost": "magic_action"})
		feature_list.add_item("Dismiss Mage Hand (Magic Action)" + (" [Unavailable]" if control_disabled else ""))
		feature_list.set_item_disabled(feature_list.get_item_count() - 1, control_disabled)
		features_registered.append({"id": "mage_hand_dismiss", "name": "Dismiss Mage Hand", "type": "active", "action_cost": "magic_action"})
	if str(active_character.concentrating_on.get("spell_id", "")) == "dancing_lights":
		var move_disabled := turn_budget != null and not turn_budget.can_spend("bonus_action")
		feature_list.add_item("Move Dancing Lights (Bonus Action)" + (" [Unavailable]" if move_disabled else ""))
		feature_list.set_item_disabled(feature_list.get_item_count() - 1, move_disabled)
		feature_list.set_item_tooltip(feature_list.get_item_count() - 1, "Move the linked lights up to 60 feet. They must remain within 120 feet of you.")
		features_registered.append({"id": "dancing_lights_move", "name": "Move Dancing Lights", "type": "active", "action_cost": "bonus_action"})
	if str(active_character.concentrating_on.get("spell_id", "")) == "moonbeam":
		var moonbeam_move_disabled := turn_budget != null and not turn_budget.can_spend("magic_action")
		feature_list.add_item("Move Moonbeam (Magic Action)" + (" [Unavailable]" if moonbeam_move_disabled else ""))
		feature_list.set_item_disabled(feature_list.get_item_count() - 1, moonbeam_move_disabled)
		feature_list.set_item_tooltip(feature_list.get_item_count() - 1, "Move the Moonbeam Cylinder up to 60 feet. Available on later turns while you concentrate.")
		features_registered.append({"id": "moonbeam_move", "name": "Move Moonbeam", "type": "active", "action_cost": "magic_action"})
	if str(active_character.concentrating_on.get("spell_id", "")) == "cloud_of_daggers":
		var daggers_move_disabled := turn_budget != null and not turn_budget.can_spend("magic_action")
		feature_list.add_item("Move Cloud of Daggers (Magic Action)" + (" [Unavailable]" if daggers_move_disabled else ""))
		feature_list.set_item_disabled(feature_list.get_item_count() - 1, daggers_move_disabled)
		feature_list.set_item_tooltip(feature_list.get_item_count() - 1, "On a later turn, teleport the 5-foot Cube up to 30 feet.")
		features_registered.append({"id": "cloud_of_daggers_move", "name": "Move Cloud of Daggers", "type": "active", "action_cost": "magic_action"})
	if str(active_character.concentrating_on.get("spell_id", "")) == "conjure_animals":
		var animals_disabled := not bool(active_character.feature_uses.get("conjure_animals_moved_this_turn", false)) or bool(active_character.feature_uses.get("conjure_animals_pack_moved_this_turn", false))
		feature_list.add_item("Move Conjure Animals Pack (Free)" + (" [Move first]" if not bool(active_character.feature_uses.get("conjure_animals_moved_this_turn", false)) else " [Used]" if animals_disabled else ""))
		feature_list.set_item_disabled(feature_list.get_item_count() - 1, animals_disabled)
		feature_list.set_item_tooltip(feature_list.get_item_count() - 1, "After you move on your turn, move the spectral pack up to 30 feet to an unoccupied space.")
		features_registered.append({"id": "conjure_animals_move", "name": "Move Conjure Animals Pack", "type": "active"})
	if str(active_character.concentrating_on.get("spell_id", "")) == "conjure_celestial":
		var celestial_disabled := not bool(active_character.feature_uses.get("conjure_celestial_moved_this_turn", false)) or bool(active_character.feature_uses.get("conjure_celestial_pillar_moved_this_turn", false))
		feature_list.add_item("Move Conjure Celestial Pillar (Free)" + (" [Move first]" if not bool(active_character.feature_uses.get("conjure_celestial_moved_this_turn", false)) else " [Used]" if celestial_disabled else ""))
		feature_list.set_item_disabled(feature_list.get_item_count() - 1, celestial_disabled)
		feature_list.set_item_tooltip(feature_list.get_item_count() - 1, "After you move on your turn, move the pillar up to 30 feet once per turn.")
		features_registered.append({"id": "conjure_celestial_move", "name": "Move Conjure Celestial Pillar", "type": "active"})
	if str(active_character.concentrating_on.get("spell_id", "")) == "conjure_fey":
		var fey_move_disabled := turn_budget != null and not turn_budget.can_spend("bonus_action")
		feature_list.add_item("Teleport Conjure Fey Spirit (Bonus Action)" + (" [Unavailable]" if fey_move_disabled else ""))
		feature_list.set_item_disabled(feature_list.get_item_count() - 1, fey_move_disabled)
		feature_list.set_item_tooltip(feature_list.get_item_count() - 1, "On a later turn, teleport the spirit up to 30 feet to an unoccupied space and make its melee spell attack.")
		features_registered.append({"id": "conjure_fey_move", "name": "Teleport Conjure Fey Spirit", "type": "active", "action_cost": "bonus_action"})
	if str(active_character.concentrating_on.get("spell_id", "")) == "conjure_woodland_beings":
		var disengage_disabled := turn_budget != null and not turn_budget.can_spend("bonus_action")
		feature_list.add_item("Disengage (Bonus Action)" + (" [Unavailable]" if disengage_disabled else ""))
		feature_list.set_item_disabled(feature_list.get_item_count() - 1, disengage_disabled)
		feature_list.set_item_tooltip(feature_list.get_item_count() - 1, "Conjure Woodland Beings lets you take the Disengage action as a Bonus Action.")
		features_registered.append({"id": "conjure_woodland_beings_disengage", "name": "Disengage", "type": "active", "action_cost": "bonus_action"})
	if active_character.class_id == "sorcerer" and active_character.has_feature("sorcerer_sorcery_points"):
		var conversion_levels := SorcererRules.available_slot_conversion_levels(active_character)
		var conversion_disabled := conversion_levels.is_empty()
		feature_list.add_item("Font of Magic: Convert Slot to Points (Free)" + (" [Unavailable]" if conversion_disabled else ""))
		feature_list.set_item_disabled(feature_list.get_item_count() - 1, conversion_disabled)
		feature_list.set_item_tooltip(feature_list.get_item_count() - 1, "Expend a spell slot and gain Sorcery Points equal to its level. No action required.")
		features_registered.append({"id": "sorcerer_font_of_magic_convert", "name": "Convert Slot to Points", "type": "active"})
		var created_levels := SorcererRules.available_created_slot_levels(active_character)
		var creation_disabled := created_levels.is_empty() or (turn_budget != null and not turn_budget.can_spend("bonus_action"))
		feature_list.add_item("Font of Magic: Create Spell Slot (Bonus Action)" + (" [Unavailable]" if creation_disabled else ""))
		feature_list.set_item_disabled(feature_list.get_item_count() - 1, creation_disabled)
		feature_list.set_item_tooltip(feature_list.get_item_count() - 1, "Spend Sorcery Points to create a level 1–5 spell slot. The slot vanishes after a Long Rest.")
		features_registered.append({"id": "sorcerer_font_of_magic_create", "name": "Create Spell Slot", "type": "active"})

	for f in active_character.features:
		var resource_slot_effect: Dictionary = {}
		var ward_slot_effect: Dictionary = {}
		var has_rest_slot_recovery := false
		for effect in f.get("effects", []):
			if effect.get("type", "") == "resource_from_spell_slot":
				resource_slot_effect = effect
			elif effect.get("type", "") == "damage_ward_pool" and bool(effect.get("bonus_action_slot_recharge", false)):
				ward_slot_effect = effect
			elif effect.get("type", "") == "rest_slot_recovery":
				has_rest_slot_recovery = true
		if has_rest_slot_recovery:
			continue
		if f.get("type", "") != "active" and f.get("id", "") != "druid_wild_companion" and resource_slot_effect.is_empty() and ward_slot_effect.is_empty(): continue

		var f_id = f["id"]
		if f_id == "druid_wild_companion":
			var has_slot := false
			for remaining in active_character.spell_slots.values():
				if int(remaining) > 0:
					has_slot = true
					break
			var has_shape_use := int(active_character.feature_uses.get("druid_wild_shape_uses", 0)) > 0
			var disabled := not has_slot and not has_shape_use
			if turn_budget != null:
				disabled = disabled or not turn_budget.can_spend("magic_action")
			feature_list.add_item("Wild Companion (Magic Action)" + (" [No cost available]" if disabled else ""))
			feature_list.set_item_disabled(feature_list.get_item_count() - 1, disabled)
			features_registered.append(f)
			continue
		if f_id == "druid_nature_magician":
			var conversions := DruidRules.nature_magician_options(active_character)
			var disabled := conversions.is_empty()
			feature_list.add_item("Nature Magician (Free)" + (" [Unavailable]" if disabled else ""))
			feature_list.set_item_disabled(feature_list.get_item_count() - 1, disabled)
			features_registered.append(f)
			continue
		if f_id == "familiar_help":
			feature_list.add_item("Help (Action)")
			features_registered.append(f)
			continue
		if not resource_slot_effect.is_empty():
			var resource_id := str(resource_slot_effect.get("resource_id", ""))
			var current := int(active_character.feature_uses.get(resource_id, 0))
			var maximum := active_character.get_feature_max_uses(resource_id)
			var has_slot := false
			for remaining in active_character.spell_slots.values():
				if int(remaining) > 0:
					has_slot = true
					break
			var disabled := current >= maximum or not has_slot
			feature_list.add_item("%s (Free; %d/%d Inspiration)" % [f.get("name", f_id), current, maximum])
			var font_index := feature_list.get_item_count() - 1
			feature_list.set_item_disabled(font_index, disabled)
			feature_list.set_item_tooltip(font_index, "Spend one spell slot to regain one Bardic Inspiration use. No action required.")
			features_registered.append(f)
			continue
		if not ward_slot_effect.is_empty():
			var pool_id := str(f.get("id", ""))
			var ward_active := WardRules.has_active_ward(active_character, pool_id)
			var ward_current := WardRules.get_ward_hp(active_character, pool_id)
			var ward_max := WardRules.get_ward_max_hp(active_character, pool_id)
			var has_slot := false
			for slot_key in active_character.spell_slots:
				if int(slot_key) >= 1 and int(active_character.spell_slots[slot_key]) > 0:
					has_slot = true
					break
			var bonus_available := turn_budget == null or turn_budget.can_spend("bonus_action")
			var disabled := not ward_active or ward_current >= ward_max or not has_slot or not bonus_available
			var status_suffix := ""
			if not ward_active:
				status_suffix = " [Create ward first]"
			elif ward_current >= ward_max:
				status_suffix = " [At max HP]"
			elif not has_slot:
				status_suffix = " [No slots]"
			elif not bonus_available:
				status_suffix = " [Unavailable]"
			feature_list.add_item("%s: Expend Slot (Bonus Action; %d/%d HP)%s" % [f.get("name", f_id), ward_current, ward_max, status_suffix])
			var ward_index := feature_list.get_item_count() - 1
			feature_list.set_item_disabled(ward_index, disabled)
			feature_list.set_item_tooltip(ward_index, "As a Bonus Action, expend one spell slot to restore Hit Points to %s equal to twice the slot's level." % f.get("name", f_id))
			features_registered.append(f)
			continue
		var resource_id := str(f.get("resource_id", f_id))
		var current_uses: int = active_character.feature_uses.get(resource_id, 0)
		var max_uses: int = active_character.get_feature_max_uses(resource_id)
		var uses_per: String = f.get("uses_per", "combat")
		var display_name := "%s (%d/%d uses per %s)" % [f.get("name", f_id), current_uses, max_uses, uses_per]
		if resource_id != f_id:
			display_name = "%s (%d/%d %s)" % [f.get("name", f_id), current_uses, max_uses, "Channel Divinity" if resource_id in ["cleric_channel_divinity", "paladin_channel_divinity"] else "shared uses"]
		if f_id == "fighter_second_wind":
			display_name = "Second Wind %d/%d (Bonus)" % [current_uses, max_uses]
		elif f_id == "fighter_action_surge":
			display_name = "Action Surge %d/%d (Free)" % [current_uses, max_uses]
		
		# Gray out if no uses left
		var disabled: bool = current_uses < int(f.get("resource_cost", 1)) or (f_id == "fighter_action_surge" and active_character.feature_uses.get("fighter_action_surge_used", false))
		if f_id in ["cleric_divine_spark", "cleric_turn_undead"]:
			disabled = disabled or not ClericRules.channel_divinity_error(active_character).is_empty()
		if f_id == "druid_wild_resurgence":
			disabled = disabled or DruidRules.wild_resurgence_state(active_character).is_empty()
		if turn_budget != null and f.has("action_cost"):
			disabled = disabled or not turn_budget.can_spend(str(f.get("action_cost", "action")))
		if str(f_id).begins_with("monk_"):
			var focus_cost := int(f.get("focus_cost", 0))
			display_name = "%s%s" % [f.get("name", f_id), (" (%d Focus)" % focus_cost) if focus_cost > 0 else ""]
			if f_id == "monk_wholeness_of_body":
				display_name = "Wholeness of Body %d/%d (Bonus)" % [current_uses, max_uses]
			disabled = disabled or (focus_cost > 0 and active_character.get_focus_points() < focus_cost)
			if f_id == "monk_bonus_unarmed_strike":
				disabled = disabled or not active_character.can_use_martial_arts()
		if f_id == "druid_wild_shape" and DruidRules.is_shaped(active_character):
			display_name = "Return to normal form (Bonus Action)"
			disabled = turn_budget != null and not turn_budget.can_spend("bonus_action")
		else:
			if disabled:
				display_name += " [No uses]"
		if f.has("executor"):
			var available := ClassFeature.availability(active_character, f, turn_budget)
			disabled = not available["available"]
			display_name = "%s %d/%d (%s)" % [f.get("name", f_id), available["remaining"], available["maximum"], str(available["action_cost"]).replace("_", " ").capitalize()]
			if f_id == "barbarian_rage" and active_character.has_condition("raging"):
				display_name = "Extend Rage (Bonus Action)"
			if disabled:
				display_name += " [%s]" % available["reason"]

		feature_list.add_item(display_name)
		var item_idx := feature_list.get_item_count() - 1
		feature_list.set_item_disabled(item_idx, disabled)
		if f_id == "fighter_second_wind":
			feature_list.set_item_tooltip(item_idx, "Bonus Action: heal 1d10+%d HP. Short Rest restores one use; Long Rest restores all." % active_character.level)
		elif f_id == "monk_wholeness_of_body":
			feature_list.set_item_tooltip(item_idx, "Bonus Action: heal Martial Arts die (%s) + Wisdom modifier HP. Long Rest restores all uses." % active_character.get_martial_arts_die())
		else:
			feature_list.set_item_tooltip(item_idx, str(f.get("description", "")))
		features_registered.append(f)
	var familiar_record := FamiliarRules.state(active_character)
	for id in ["created_attack", "created_guard", "animated_attack", "animated_guard"]:
		var command := CreatedCreatureRules.command_feature(active_character, id)
		if command.is_empty(): continue
		feature_list.add_item("%s (Bonus Action)" % command["name"])
		feature_list.set_item_disabled(feature_list.item_count - 1, turn_budget != null and not turn_budget.can_spend("bonus_action"))
		features_registered.append(command)
	if not familiar_record.is_empty():
		for id in ["familiar_recall", "familiar_dismiss", "familiar_release", "familiar_senses"]:
			var command := FamiliarRules.command_feature(active_character, id)
			if command.is_empty(): continue
			var cost := str(command["action_cost"])
			feature_list.add_item("%s (%s)" % [command["name"], "Bonus Action" if cost == "bonus_action" else "Magic action"])
			feature_list.set_item_disabled(feature_list.item_count - 1, turn_budget != null and not turn_budget.can_spend(cost))
			features_registered.append(command)
	var steed_state := PaladinRules.find_steed_state(active_character)
	if not steed_state.is_empty() and int(steed_state.get("current_hp", 0)) > 0:
		var is_mounted := bool(steed_state.get("mounted", false))
		feature_list.add_item("Dismount Steed" if is_mounted else "Mount Steed")
		feature_list.set_item_tooltip(feature_list.get_item_count() - 1, "Mount or dismount during your move; spend half your Speed.")
		features_registered.append({"id": "toggle_find_steed_mount", "name": "Dismount Steed" if is_mounted else "Mount Steed", "type": "active"})
		if is_mounted:
			for steed_feature in PaladinRules.find_steed_features(steed_state):
				if str(steed_feature.get("action_cost", "")) != "bonus_action":
					continue
				var bonus_disabled := turn_budget != null and not turn_budget.can_spend("bonus_action")
				feature_list.add_item("Steed: %s (Bonus Action)%s" % [str(steed_feature.get("name", "Ability")), " [Unavailable]" if bonus_disabled else ""])
				feature_list.set_item_disabled(feature_list.get_item_count() - 1, bonus_disabled)
				features_registered.append(steed_feature.duplicate(true))


func _hide_feature_selection() -> void:
	set_mode(Mode.SELECT)


func _on_feature_selected(index: int) -> void:
	if index < 0 or index >= features_registered.size(): return
	if feature_list.is_item_disabled(index): return
	var feature_owner := active_character
	var feature := features_registered[index]
	_hide_feature_selection()
	if str(feature.get("id", "")) == "wand_of_magic_missiles_activate":
		if active_character == feature_owner:
			action_selected.emit("activate_magic_item", {"instance_id": str(feature.get("instance_id", "")), "charges": int(feature.get("charges", 0))})
		return
	if str(feature.get("id", "")) == "toggle_find_steed_mount":
		if active_character == feature_owner:
			action_selected.emit("toggle_find_steed_mount", {})
		return
	if str(feature.get("id", "")) == "goodberry_eat":
		if active_character == feature_owner:
			action_selected.emit("eat_goodberry", {})
		return
	if str(feature.get("id", "")) == "dancing_lights_move":
		if active_character == feature_owner:
			action_selected.emit("move_dancing_lights", {})
		return
	if str(feature.get("id", "")) == "moonbeam_move":
		if active_character == feature_owner:
			action_selected.emit("move_moonbeam", {})
		return
	if str(feature.get("id", "")) == "cloud_of_daggers_move":
		if active_character == feature_owner:
			action_selected.emit("move_cloud_of_daggers", {})
		return
	if str(feature.get("id", "")) == "conjure_animals_move":
		if active_character == feature_owner:
			action_selected.emit("move_conjure_animals", {})
		return
	if str(feature.get("id", "")) == "conjure_celestial_move":
		if active_character == feature_owner:
			action_selected.emit("move_conjure_celestial", {})
		return
	if str(feature.get("id", "")) == "conjure_fey_move":
		if active_character == feature_owner:
			action_selected.emit("move_conjure_fey", {})
		return
	if str(feature.get("id", "")) == "conjure_woodland_beings_disengage":
		if active_character == feature_owner:
			action_selected.emit("conjure_woodland_beings_disengage", {})
		return
	if str(feature.get("id", "")) == "dismiss_light":
		if active_character == feature_owner:
			action_selected.emit("dismiss_light", {})
		return
	if str(feature.get("id", "")) == "detect_magic_inspect":
		if active_character == feature_owner:
			action_selected.emit("detect_magic_inspect", {})
		return
	if str(feature.get("id", "")) == "mage_hand_control":
		if active_character == feature_owner:
			action_selected.emit("control_mage_hand", {})
		return
	if str(feature.get("id", "")) == "mage_hand_dismiss":
		if active_character == feature_owner:
			action_selected.emit("dismiss_mage_hand", {})
		return
	if str(feature.get("id", "")) in ["sorcerer_font_of_magic_convert", "sorcerer_font_of_magic_create"]:
		var create_slot := str(feature.get("id", "")) == "sorcerer_font_of_magic_create"
		var slot_level := await request_sorcerer_font_slot_level(feature_owner, create_slot)
		if active_character == feature_owner and slot_level > 0:
			action_selected.emit("font_of_magic_create" if create_slot else "font_of_magic_convert", {"slot_level": slot_level})
		return
	if str(feature.get("id", "")) == "druid_wild_companion":
		var choice := await request_wild_companion_choice(active_character)
		if active_character == feature_owner and not choice.is_empty():
			action_selected.emit("use_feature", {"feature": feature, "wild_companion_choice": choice})
		return
	if str(feature.get("id", "")) == "druid_nature_magician":
		var uses_to_convert := await request_nature_magician_choice(active_character)
		if active_character == feature_owner and uses_to_convert > 0:
			action_selected.emit("use_feature", {"feature": feature, "wild_shape_uses": uses_to_convert})
		return
	var resource_slot_effect: Dictionary = {}
	var ward_slot_effect: Dictionary = {}
	for effect in feature.get("effects", []):
		if effect.get("type", "") == "resource_from_spell_slot":
			resource_slot_effect = effect
		elif effect.get("type", "") == "damage_ward_pool" and bool(effect.get("bonus_action_slot_recharge", false)):
			ward_slot_effect = effect
	if not resource_slot_effect.is_empty() or not ward_slot_effect.is_empty():
		var selected_slot := await request_spell_slot(active_character)
		if selected_slot <= 0:
			return
		feature = feature.duplicate(true)
		feature["selected_spell_slot_level"] = selected_slot
	elif feature.get("id", "") in ["monk_patient_defense", "monk_step_of_the_wind"]:
		var selected_option := await request_monk_bonus_action(str(feature["id"]))
		if selected_option.is_empty():
			return
		feature = feature.duplicate(true)
		feature["selected_action"] = selected_option
	elif feature.get("id", "") == "rogue_cunning_action":
		var selected_action := await request_movement_bonus_action(feature.get("id", "") == "rogue_cunning_action")
		if selected_action.is_empty():
			return
		feature = feature.duplicate(true)
		feature["selected_action"] = selected_action
	if active_character == feature_owner:
		action_selected.emit("use_feature", {"feature": feature})


func request_spell_slot(character: Character, minimum_level: int = 1) -> int:
	var slot_levels: Array[int] = []
	for key in character.spell_slots:
		if int(key) >= minimum_level and int(character.spell_slots[key]) > 0:
			slot_levels.append(int(key))
	slot_levels.sort()
	if slot_levels.is_empty():
		return 0
	if GameManager.test_mode:
		return slot_levels[0]
	var menu := PopupMenu.new()
	for level in slot_levels:
		menu.add_item("Level %d (%d remaining)" % [level, int(character.spell_slots[str(level)])], level)
	add_child(menu)
	var decision := {"slot_level": 0, "done": false}
	menu.id_pressed.connect(func(id: int):
		decision["slot_level"] = id
		decision["done"] = true
	)
	menu.popup_hide.connect(func(): decision["done"] = true)
	menu.popup_centered(Vector2i(300, 160))
	var timeout := get_tree().create_timer(15.0)
	while not decision["done"] and timeout.time_left > 0.0:
		await get_tree().process_frame
	menu.queue_free()
	return int(decision["slot_level"])


func request_sorcerer_font_slot_level(character: Character, create_slot: bool) -> int:
	var slot_levels := SorcererRules.available_created_slot_levels(character) if create_slot else SorcererRules.available_slot_conversion_levels(character)
	if slot_levels.is_empty():
		return 0
	if GameManager.test_mode:
		return slot_levels[0]
	var menu := PopupMenu.new()
	for level in slot_levels:
		if create_slot:
			menu.add_item("Create level %d slot (%d Sorcery Points)" % [level, int(SorcererRules.SLOT_POINT_COSTS[level])], level)
		else:
			menu.add_item("Convert level %d slot into %d Sorcery Point%s" % [level, level, "" if level == 1 else "s"], level)
	add_child(menu)
	var decision := {"slot_level": 0, "done": false}
	menu.id_pressed.connect(func(id: int):
		decision["slot_level"] = id
		decision["done"] = true
	)
	menu.popup_hide.connect(func(): decision["done"] = true)
	menu.popup_centered(Vector2i(360, 200))
	var timeout := get_tree().create_timer(15.0)
	while not decision["done"] and timeout.time_left > 0.0:
		await get_tree().process_frame
	menu.queue_free()
	return int(decision["slot_level"])


func request_wild_companion_choice(character: Character) -> Dictionary:
	var forms := DruidRules.wild_companion_forms()
	if forms.is_empty():
		return {}
	var form_id := str(forms[0].get("id", ""))
	if not GameManager.test_mode:
		var form_menu := PopupMenu.new()
		for index in forms.size():
			form_menu.add_item(str(forms[index].get("name", "Familiar")), index)
		add_child(form_menu)
		var form_decision := {"index": -1, "done": false}
		form_menu.id_pressed.connect(func(id: int):
			form_decision["index"] = id
			form_decision["done"] = true
		)
		form_menu.popup_hide.connect(func(): form_decision["done"] = true)
		form_menu.popup_centered(Vector2i(280, 180))
		while not form_decision["done"]:
			await get_tree().process_frame
		if int(form_decision["index"]) < 0 or int(form_decision["index"]) >= forms.size():
			form_menu.queue_free()
			return {}
		form_id = str(forms[int(form_decision["index"])].get("id", ""))
		form_menu.queue_free()
	var has_slot := false
	for remaining in character.spell_slots.values():
		if int(remaining) > 0:
			has_slot = true
			break
	var has_shape_use := int(character.feature_uses.get("druid_wild_shape_uses", 0)) > 0
	if not has_slot and not has_shape_use:
		return {}
	var cost := "spell_slot" if has_slot else "wild_shape"
	if not GameManager.test_mode and has_slot and has_shape_use:
		var cost_menu := PopupMenu.new()
		cost_menu.add_item("Expend a spell slot", 0)
		cost_menu.add_item("Expend a Wild Shape use", 1)
		add_child(cost_menu)
		var cost_decision := {"value": -1, "done": false}
		cost_menu.id_pressed.connect(func(id: int):
			cost_decision["value"] = id
			cost_decision["done"] = true
		)
		cost_menu.popup_hide.connect(func(): cost_decision["done"] = true)
		cost_menu.popup_centered(Vector2i(280, 120))
		while not cost_decision["done"]:
			await get_tree().process_frame
		if int(cost_decision["value"]) < 0:
			cost_menu.queue_free()
			return {}
		cost = "spell_slot" if int(cost_decision["value"]) == 0 else "wild_shape"
		cost_menu.queue_free()
	return {"form_id": form_id, "cost": cost}


func request_find_steed_choice(spell_data: Dictionary) -> Dictionary:
	var summon: Dictionary = spell_data.get("summoned_creature", {})
	var forms: Array = summon.get("forms", [])
	var creature_types: Array = summon.get("creature_types", [])
	if forms.is_empty() or creature_types.is_empty():
		return {}
	if GameManager.test_mode:
		return {"form": str(forms[0]), "creature_type": str(creature_types[0])}
	var options: Array[Dictionary] = []
	var menu := PopupMenu.new()
	for form in forms:
		for creature_type in creature_types:
			options.append({"form": str(form), "creature_type": str(creature_type)})
			menu.add_item("%s (%s)" % [str(form).capitalize(), str(creature_type).capitalize()], options.size() - 1)
	add_child(menu)
	var decision := {"index": -1, "done": false}
	menu.id_pressed.connect(func(id: int):
		decision["index"] = id
		decision["done"] = true
	)
	menu.popup_hide.connect(func(): decision["done"] = true)
	menu.popup_centered(Vector2i(300, 300))
	while not decision["done"]:
		await get_tree().process_frame
	var selected: Dictionary = {}
	var index := int(decision["index"])
	if index >= 0 and index < options.size():
		selected = options[index]
	menu.queue_free()
	return selected


func request_damage_type_choice(options: Array, label: String) -> String:
	if options.is_empty():
		return ""
	if GameManager.test_mode:
		return str(options[0])
	var menu := PopupMenu.new()
	for index in options.size():
		menu.add_item(str(options[index]).capitalize(), index)
	add_child(menu)
	var decision := {"index": -1, "done": false}
	menu.id_pressed.connect(func(id: int):
		decision["index"] = id
		decision["done"] = true
	)
	menu.popup_hide.connect(func(): decision["done"] = true)
	menu.popup_centered(Vector2i(260, 140))
	while not decision["done"]:
		await get_tree().process_frame
	var selected := ""
	if int(decision["index"]) >= 0 and int(decision["index"]) < options.size():
		selected = str(options[int(decision["index"])])
	menu.queue_free()
	return selected


func request_nature_magician_choice(character: Character) -> int:
	var options := DruidRules.nature_magician_options(character)
	if options.is_empty():
		return 0
	if GameManager.test_mode:
		return int(options[0].get("uses", 0))
	var menu := PopupMenu.new()
	for index in options.size():
		var option: Dictionary = options[index]
		menu.add_item("Expend %d Wild Shape use%s for a level %d slot" % [int(option["uses"]), "" if int(option["uses"]) == 1 else "s", int(option["spell_level"])], index)
	add_child(menu)
	var decision := {"index": -1, "done": false}
	menu.id_pressed.connect(func(id: int):
		decision["index"] = id
		decision["done"] = true
	)
	menu.popup_hide.connect(func(): decision["done"] = true)
	menu.popup_centered(Vector2i(350, 180))
	while not decision["done"]:
		await get_tree().process_frame
	var uses := 0
	if int(decision["index"]) >= 0 and int(decision["index"]) < options.size():
		uses = int(options[int(decision["index"])].get("uses", 0))
	menu.queue_free()
	return uses


func request_wild_shape_form(character: Character) -> String:
	var forms := DruidRules.form_options(character)
	if forms.is_empty():
		show_hint("No known eligible Beast forms. Open Class Progression outside combat and learn a form before using Wild Shape.")
		add_log("Wild Shape needs a known eligible Beast form; no use or action was spent.")
		return ""
	if GameManager.test_mode:
		return "__revert" if DruidRules.is_shaped(character) else str(forms[0].get("id", ""))
	var menu := PopupMenu.new()
	var item_forms: Dictionary = {}
	var next_id := 1
	if DruidRules.is_shaped(character):
		menu.add_item("Return to normal form (Bonus Action)", 0)
	for form in forms:
		menu.add_item("Become %s (Bonus Action)" % str(form.get("name", form.get("id", "Beast"))), next_id)
		item_forms[next_id] = str(form.get("id", ""))
		next_id += 1
	add_child(menu)
	var decision := {"form_id": "", "done": false}
	menu.id_pressed.connect(func(id: int):
		decision["form_id"] = "__revert" if id == 0 else str(item_forms.get(id, ""))
		decision["done"] = true
	)
	menu.popup_hide.connect(func(): decision["done"] = true)
	menu.popup_centered(Vector2i(340, 220))
	var timeout := get_tree().create_timer(15.0)
	while not decision["done"] and timeout.time_left > 0.0:
		await get_tree().process_frame
	menu.queue_free()
	return str(decision["form_id"])


func request_deflect_target(candidates: Array[Dictionary]) -> int:
	if candidates.is_empty() or GameManager.test_mode:
		return -1
	var menu := PopupMenu.new()
	for index in candidates.size():
		menu.add_item("Redirect to %s (1 Focus)" % candidates[index].get("name", "enemy"), index)
	add_child(menu)
	var decision := {"selected": -1, "done": false}
	menu.id_pressed.connect(func(id: int):
		decision["selected"] = id
		decision["done"] = true
	)
	menu.popup_hide.connect(func(): decision["done"] = true)
	menu.popup_centered(Vector2i(360, 180))
	var timeout := get_tree().create_timer(8.0)
	while not decision["done"] and timeout.time_left > 0.0:
		await get_tree().process_frame
	menu.queue_free()
	return int(decision["selected"])


func request_lay_on_hands_conditions(conditions: Array[String], maximum: int) -> Array[String]:
	var selected: Array[String] = []
	if GameManager.test_mode or conditions.is_empty() or maximum <= 0:
		return selected
	var labels := {
		"poisoned": "Poisoned", "blinded": "Blinded", "charmed": "Charmed", "deafened": "Deafened",
		"frightened": "Frightened", "paralyzed": "Paralyzed", "stunned": "Stunned",
		"__done": "Finish selection",
	}
	while selected.size() < mini(maximum, conditions.size()):
		var options: Array[String] = []
		for condition in conditions:
			if condition not in selected:
				options.append(condition)
		options.append("__done")
		var choice := await _request_popup_choice("Lay on Hands: choose a condition to remove", options, labels)
		if choice.is_empty() or choice == "__done":
			break
		selected.append(choice)
	return selected


func request_abjure_foes_targets(candidates: Array[Dictionary], maximum: int) -> Array[String]:
	var selected: Array[String] = []
	if maximum <= 0 or candidates.is_empty():
		return selected
	if GameManager.test_mode:
		for index in mini(maximum, candidates.size()):
			selected.append(str(candidates[index].get("id", "")))
		return selected
	var labels: Dictionary = {"__done": "Finish target selection"}
	for candidate in candidates:
		labels[str(candidate.get("id", ""))] = str(candidate.get("name", "Creature"))
	while selected.size() < maximum:
		var options: Array[String] = []
		for candidate in candidates:
			var target_id := str(candidate.get("id", ""))
			if target_id not in selected:
				options.append(target_id)
		options.append("__done")
		var choice := await _request_popup_choice("Abjure Foes: choose target %d of up to %d" % [selected.size() + 1, maximum], options, labels)
		if choice.is_empty() or choice == "__done":
			break
		selected.append(choice)
	return selected


func request_spirit_guardians_exemptions(candidates: Array[Dictionary], seeded_ids: Array = []) -> Array[String]:
	var selected: Array[String] = []
	if GameManager.test_mode:
		var candidate_ids: Array[String] = []
		for candidate in candidates:
			candidate_ids.append(str(candidate.get("id", "")))
		for target_id in seeded_ids:
			if str(target_id) in candidate_ids:
				selected.append(str(target_id))
		return selected
	var labels: Dictionary = {"__done": "Finish selection"}
	for candidate in candidates:
		labels[str(candidate.get("id", ""))] = str(candidate.get("name", "Creature"))
	while true:
		var options: Array[String] = []
		for candidate in candidates:
			var target_id := str(candidate.get("id", ""))
			if target_id not in selected:
				options.append(target_id)
		options.append("__done")
		var choice := await _request_popup_choice("Spirit Guardians: choose creatures to leave unaffected", options, labels)
		if choice.is_empty() or choice == "__done":
			break
		selected.append(choice)
	return selected


func request_beacon_of_hope_targets(candidates: Array[Dictionary], seeded_ids: Array = []) -> Array[String]:
	var selected: Array[String] = []
	if GameManager.test_mode:
		var candidate_ids: Array[String] = []
		for candidate in candidates:
			candidate_ids.append(str(candidate.get("id", "")))
		for target_id in seeded_ids:
			if str(target_id) in candidate_ids:
				selected.append(str(target_id))
		return selected
	var labels: Dictionary = {"__done": "Finish selection"}
	for candidate in candidates:
		labels[str(candidate.get("id", ""))] = str(candidate.get("name", "Creature"))
	while true:
		var options: Array[String] = []
		for candidate in candidates:
			var target_id := str(candidate.get("id", ""))
			if target_id not in selected:
				options.append(target_id)
		options.append("__done")
		var choice := await _request_popup_choice("Beacon of Hope: choose any number of creatures within 30 feet", options, labels)
		if choice.is_empty() or choice == "__done":
			break
		selected.append(choice)
	return selected


func request_sorcerer_careful_spell_targets(caster: Character, candidates: Array[Dictionary]) -> Array[String]:
	var selected: Array[String] = []
	var maximum := SorcererRules.careful_spell_target_limit(caster)
	if candidates.is_empty() or maximum <= 0:
		return selected
	if GameManager.test_mode:
		for index in mini(maximum, candidates.size()):
			var target_id := str(candidates[index].get("id", ""))
			if not target_id.is_empty():
				selected.append(target_id)
		return selected
	var labels: Dictionary = {"__done": "Finish target selection"}
	for candidate in candidates:
		labels[str(candidate.get("id", ""))] = str(candidate.get("name", "Creature"))
	while selected.size() < maximum:
		var options: Array[String] = []
		for candidate in candidates:
			var target_id := str(candidate.get("id", ""))
			if not target_id.is_empty() and target_id not in selected:
				options.append(target_id)
		if options.is_empty():
			break
		options.append("__done")
		var choice := await _request_popup_choice("Careful Spell: choose a creature that automatically succeeds", options, labels)
		if choice.is_empty() or choice == "__done":
			break
		selected.append(choice)
	return selected


func request_empowered_spell_dice(caster: Character, details: Dictionary, max_dice_override: int = -1) -> Array[int]:
	var selected: Array[int] = []
	var dice := Dice.selectable_dice(details)
	var cha_mod := maxi(1, caster.ability_scores.get_ability_modifier("CHA"))
	var maximum := mini(max_dice_override, cha_mod) if max_dice_override > 0 else cha_mod
	if GameManager.test_mode:
		if not dice.is_empty():
			selected.append(0)
		return selected
	var labels := {"__done": "Finish selection (new rolls must stand)"}
	for index in dice.size():
		labels[str(index)] = "Die %d: d%d rolled %d" % [index + 1, dice[index]["sides"], dice[index]["value"]]
	while selected.size() < maximum:
		var options: Array[String] = []
		for index in dice.size():
			if index not in selected:
				options.append(str(index))
		if options.is_empty():
			break
		options.append("__done")
		var choice := await _request_popup_choice("Empowered Spell: choose up to %d damage dice" % maximum, options, labels)
		if choice.is_empty() or choice == "__done":
			break
		selected.append(int(choice))
	return selected


func request_barbarian_brutal_strike(character: Character) -> Array[String]:
	var available := BarbarianRules.brutal_strike_options(character)
	var needed := 2 if character.has_feature("barbarian_improved_brutal_strike_17") else 1
	if GameManager.test_mode:
		var defaults: Array[String] = ["hamstring"]
		if needed == 2:
			defaults.append("sundering")
		return defaults
	var labels := {"forceful": "Forceful Blow", "hamstring": "Hamstring Blow", "staggering": "Staggering Blow", "sundering": "Sundering Blow"}
	var selected: Array[String] = []
	for index in needed:
		var options: Array[String] = []
		for option in available:
			if option not in selected:
				options.append(option)
		var choice := await _request_popup_choice("Choose Brutal Strike effect %d of %d" % [index + 1, needed], options, labels)
		if choice.is_empty():
			return []
		selected.append(choice)
	return selected


func request_rogue_cunning_strike(character: Character, target: Dictionary, sneak_attack_dice: int) -> Array[String]:
	if GameManager.test_mode or character == null or sneak_attack_dice <= 0:
		return []
	var options := RogueRules.cunning_strike_options(character, target)
	var labels := {
		"poison": "Poison (1d6; Poisoner's Kit)",
		"trip": "Trip (1d6; Large or smaller)",
		"withdraw": "Withdraw (1d6; move without opportunity attacks)",
		"daze": "Daze (2d6; CON save)",
		"knock_out": "Knock Out (6d6; CON save)",
		"obscure": "Obscure (3d6; DEX save)"
	}
	var selected: Array[String] = []
	var remaining := sneak_attack_dice
	var max_effects := RogueRules.cunning_strike_max_effects(character)
	while selected.size() < max_effects and not options.is_empty():
		var affordable: Array[String] = []
		for option in options:
			if option not in selected and RogueRules.cunning_strike_dice_cost(option) <= remaining:
				affordable.append(option)
		if affordable.is_empty():
			break
		var choice := await _request_popup_choice("Choose Cunning Strike (%d Sneak Attack dice available)" % remaining, affordable, labels)
		if choice.is_empty():
			break
		selected.append(choice)
		remaining -= RogueRules.cunning_strike_dice_cost(choice)
	return selected


func _request_popup_choice(prompt: String, options: Array[String], labels: Dictionary) -> String:
	var menu := PopupMenu.new()
	menu.title = prompt
	for index in options.size():
		menu.add_item(str(labels.get(options[index], options[index])), index)
	add_child(menu)
	var decision := {"selected": -1, "done": false}
	menu.id_pressed.connect(func(id: int):
		decision["selected"] = id
		decision["done"] = true
	)
	menu.popup_hide.connect(func(): decision["done"] = true)
	menu.popup_centered(Vector2i(360, 180))
	var timeout := get_tree().create_timer(30.0)
	while not decision["done"] and timeout.time_left > 0.0:
		await get_tree().process_frame
	menu.queue_free()
	var selected := int(decision["selected"])
	return options[selected] if selected >= 0 and selected < options.size() else ""


func request_chain_lightning_target_choice(candidates: Array[Dictionary], seeded_target_id: String = "") -> String:
	if candidates.is_empty():
		return ""
	var ids: Array[String] = []
	var labels: Dictionary = {}
	for candidate in candidates:
		var candidate_id := str(candidate.get("id", ""))
		if candidate_id.is_empty():
			continue
		ids.append(candidate_id)
		labels[candidate_id] = "%s — %s" % [str(candidate.get("kind", "target")).capitalize(), str(candidate.get("label", "Target"))]
	if ids.is_empty():
		return ""
	if not seeded_target_id.is_empty():
		return seeded_target_id if seeded_target_id in ids else ""
	if ids.size() == 1 or GameManager.test_mode:
		return ids[0]
	return await _request_popup_choice("Chain Lightning: choose a creature or object", ids, labels)


func request_enhance_ability_choice(target_name: String, seeded_choice: String = "") -> String:
	var options: Array[String] = ["STR", "DEX", "INT", "WIS", "CHA"]
	if GameManager.test_mode:
		return seeded_choice.to_upper() if seeded_choice.to_upper() in options else "STR"
	var labels := {"STR": "Strength checks", "DEX": "Dexterity checks", "INT": "Intelligence checks", "WIS": "Wisdom checks", "CHA": "Charisma checks"}
	return await _request_popup_choice("Enhance Ability: choose an ability for %s" % target_name, options, labels)


func request_command_choice() -> String:
	var options: Array[String] = ["approach", "drop", "flee", "grovel", "halt"]
	if GameManager.test_mode:
		return "halt"
	return await _request_popup_choice("Choose the Command", options, {"approach": "Approach", "drop": "Drop", "flee": "Flee", "grovel": "Grovel", "halt": "Halt"})


func request_guidance_skill_choice() -> String:
	var skills: Array[String] = ["Acrobatics", "Animal Handling", "Arcana", "Athletics", "Deception", "History", "Insight", "Intimidation", "Investigation", "Medicine", "Nature", "Perception", "Performance", "Persuasion", "Religion", "Sleight of Hand", "Stealth", "Survival"]
	if GameManager.test_mode:
		return "Acrobatics"
	var labels: Dictionary = {}
	for skill in skills:
		labels[skill] = skill
	return await _request_popup_choice("Choose the skill for Guidance", skills, labels)


func request_animal_messenger_order(visited_locations: Array[Dictionary]) -> Dictionary:
	if visited_locations.is_empty():
		return {}
	if GameManager.test_mode:
		return {
			"destination_id": str(visited_locations[0].get("id", "")),
			"recipient": "the town guard",
			"message": "The party is on its way.",
		}
	var dialog := ConfirmationDialog.new()
	dialog.title = "Animal Messenger"
	dialog.ok_button_text = "Send"
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	var destination_label := Label.new()
	destination_label.text = "Previously visited destination"
	content.add_child(destination_label)
	var destination_picker := OptionButton.new()
	for location in visited_locations:
		destination_picker.add_item(str(location.get("name", location.get("id", "Location"))))
		destination_picker.set_item_metadata(destination_picker.item_count - 1, str(location.get("id", "")))
	content.add_child(destination_picker)
	var recipient_input := LineEdit.new()
	recipient_input.placeholder_text = "Recipient description (for example, the town guard)"
	recipient_input.max_length = 120
	content.add_child(recipient_input)
	var message_label := Label.new()
	message_label.text = "Message (up to 25 words)"
	content.add_child(message_label)
	var message_input := TextEdit.new()
	message_input.custom_minimum_size = Vector2(420, 100)
	message_input.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	content.add_child(message_input)
	dialog.add_child(content)
	add_child(dialog)
	var decision := {"done": false, "order": {}}
	dialog.confirmed.connect(func():
		var selected := destination_picker.get_selected()
		decision["order"] = {
			"destination_id": str(destination_picker.get_item_metadata(selected)) if selected >= 0 else "",
			"recipient": recipient_input.text,
			"message": message_input.text,
		}
		decision["done"] = true
	)
	dialog.canceled.connect(func(): decision["done"] = true)
	dialog.close_requested.connect(func(): decision["done"] = true)
	dialog.popup_centered(Vector2i(500, 400))
	var timeout := get_tree().create_timer(300.0)
	while not decision["done"] and timeout.time_left > 0.0:
		await get_tree().process_frame
	dialog.queue_free()
	return decision["order"]


func request_message_exchange(caster_name: String, target_name: String, target_owner_index: int) -> Dictionary:
	if GameManager.test_mode:
		return {"success": true, "message": "A test whisper.", "reply": ""}
	var seat_label := "Seat %d" % (target_owner_index + 1) if target_owner_index >= 0 else "the receiving player"
	var composer := ConfirmationDialog.new()
	composer.title = "Message · %s" % caster_name
	composer.dialog_text = "Write the whisper for %s. It will not appear in the Chronicle." % target_name
	composer.ok_button_text = "Send Whisper"
	composer.cancel_button_text = "Cancel"
	var message_input := TextEdit.new()
	message_input.custom_minimum_size = Vector2(440, 120)
	message_input.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	composer.add_child(message_input)
	add_child(composer)
	ModalSurface.watch_window(composer)
	var message_decision := {"done": false, "sent": false}
	composer.confirmed.connect(func():
		message_decision["sent"] = true
		message_decision["done"] = true
	)
	composer.canceled.connect(func(): message_decision["done"] = true)
	composer.close_requested.connect(func(): message_decision["done"] = true)
	composer.popup_centered(Vector2i(500, 270))
	while not message_decision["done"]:
		await get_tree().process_frame
	var message := str(message_input.text).strip_edges()
	composer.queue_free()
	if not bool(message_decision["sent"]):
		return {"success": false}

	var handoff_to_target := ConfirmationDialog.new()
	handoff_to_target.title = "Pass to %s" % seat_label
	handoff_to_target.dialog_text = "Pass the screen to %s. Continue only when they are ready to read the whisper." % seat_label
	handoff_to_target.ok_button_text = "Continue"
	handoff_to_target.cancel_button_text = "Cancel Cast"
	add_child(handoff_to_target)
	ModalSurface.watch_window(handoff_to_target)
	var target_ready := {"done": false, "accepted": false}
	handoff_to_target.confirmed.connect(func():
		target_ready["accepted"] = true
		target_ready["done"] = true
	)
	handoff_to_target.canceled.connect(func(): target_ready["done"] = true)
	handoff_to_target.close_requested.connect(func(): target_ready["done"] = true)
	handoff_to_target.popup_centered(Vector2i(440, 180))
	while not target_ready["done"]:
		await get_tree().process_frame
	handoff_to_target.queue_free()
	if not bool(target_ready["accepted"]):
		return {"success": false}

	var recipient_dialog := ConfirmationDialog.new()
	recipient_dialog.title = "Private Message for %s" % target_name
	recipient_dialog.dialog_text = message
	recipient_dialog.ok_button_text = "Reply"
	recipient_dialog.cancel_button_text = "No Reply"
	var reply_input := TextEdit.new()
	reply_input.placeholder_text = "Optional whisper reply"
	reply_input.custom_minimum_size = Vector2(440, 100)
	reply_input.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	recipient_dialog.add_child(reply_input)
	add_child(recipient_dialog)
	ModalSurface.watch_window(recipient_dialog)
	var recipient_decision := {"done": false, "replied": false}
	recipient_dialog.confirmed.connect(func():
		recipient_decision["replied"] = true
		recipient_decision["done"] = true
	)
	recipient_dialog.canceled.connect(func(): recipient_decision["done"] = true)
	recipient_dialog.close_requested.connect(func(): recipient_decision["done"] = true)
	recipient_dialog.popup_centered(Vector2i(500, 280))
	while not recipient_decision["done"]:
		await get_tree().process_frame
	var reply := str(reply_input.text).strip_edges() if recipient_decision["replied"] else ""
	recipient_dialog.queue_free()
	if reply.is_empty():
		return {"success": true, "message": message, "reply": ""}

	var handoff_to_caster := ConfirmationDialog.new()
	handoff_to_caster.title = "Pass back to %s" % caster_name
	handoff_to_caster.dialog_text = "Pass the screen back to %s to deliver the reply." % caster_name
	handoff_to_caster.ok_button_text = "Continue"
	add_child(handoff_to_caster)
	ModalSurface.watch_window(handoff_to_caster)
	var caster_ready := {"done": false}
	handoff_to_caster.confirmed.connect(func(): caster_ready["done"] = true)
	handoff_to_caster.canceled.connect(func(): caster_ready["done"] = true)
	handoff_to_caster.close_requested.connect(func(): caster_ready["done"] = true)
	handoff_to_caster.popup_centered(Vector2i(440, 170))
	while not caster_ready["done"]:
		await get_tree().process_frame
	handoff_to_caster.queue_free()
	var reply_dialog := AcceptDialog.new()
	reply_dialog.title = "Whisper Reply for %s" % caster_name
	reply_dialog.dialog_text = "%s replies:\n\n%s" % [target_name, reply]
	add_child(reply_dialog)
	ModalSurface.watch_window(reply_dialog)
	var reply_read := {"done": false}
	reply_dialog.confirmed.connect(func(): reply_read["done"] = true)
	reply_dialog.close_requested.connect(func(): reply_read["done"] = true)
	reply_dialog.popup_centered(Vector2i(440, 220))
	while not reply_read["done"]:
		await get_tree().process_frame
	reply_dialog.queue_free()
	return {"success": true, "message": message, "reply": reply}


func request_dancing_lights_form() -> Dictionary:
	if GameManager.test_mode:
		return {"success": true, "humanoid_form": false, "light_count": 4}
	var dialog := ConfirmationDialog.new()
	dialog.title = "Dancing Lights"
	dialog.dialog_text = "Choose how the spell appears. Each light sheds Dim Light in a 10-foot radius."
	dialog.ok_button_text = "Create Lights"
	dialog.cancel_button_text = "Cancel"
	var content := VBoxContainer.new()
	var count_label := Label.new()
	count_label.text = "Number of torch-size lights (up to four)"
	content.add_child(count_label)
	var count_picker := OptionButton.new()
	for count in range(1, 5):
		count_picker.add_item("%d light%s" % [count, "s" if count != 1 else ""])
		count_picker.set_item_metadata(count_picker.item_count - 1, count)
	count_picker.select(3)
	content.add_child(count_picker)
	var humanoid_button := Button.new()
	humanoid_button.text = "One Humanoid Form"
	content.add_child(humanoid_button)
	dialog.add_child(content)
	add_child(dialog)
	ModalSurface.watch_window(dialog)
	var decision := {"done": false, "humanoid_form": false, "light_count": 4, "success": false}
	dialog.confirmed.connect(func():
		decision["success"] = true
		decision["light_count"] = int(count_picker.get_item_metadata(count_picker.selected))
		decision["done"] = true
	)
	dialog.canceled.connect(func(): decision["done"] = true)
	dialog.close_requested.connect(func(): decision["done"] = true)
	humanoid_button.pressed.connect(func():
		decision["success"] = true
		decision["humanoid_form"] = true
		decision["light_count"] = 1
		decision["done"] = true
		dialog.hide()
	)
	dialog.popup_centered(Vector2i(460, 220))
	var timeout := get_tree().create_timer(30.0)
	while not decision["done"] and timeout.time_left > 0.0:
		await get_tree().process_frame
	dialog.hide()
	dialog.queue_free()
	return decision


func request_minor_illusion() -> Dictionary:
	if GameManager.test_mode:
		return {"success": true, "form": "sound", "description": "A test whisper"}
	var dialog := ConfirmationDialog.new()
	dialog.title = "Minor Illusion"
	dialog.dialog_text = "Create one sound or one object image within range. Images fit in a 5-foot Cube."
	dialog.ok_button_text = "Create Illusion"
	dialog.cancel_button_text = "Cancel"
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	var form_picker := OptionButton.new()
	form_picker.add_item("Sound")
	form_picker.set_item_metadata(0, "sound")
	form_picker.add_item("Object image")
	form_picker.set_item_metadata(1, "image")
	content.add_child(form_picker)
	var description_input := TextEdit.new()
	description_input.placeholder_text = "Describe the sound or object image"
	description_input.custom_minimum_size = Vector2(420, 100)
	description_input.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	content.add_child(description_input)
	dialog.add_child(content)
	add_child(dialog)
	ModalSurface.watch_window(dialog)
	var decision := {"done": false, "choice": {}}
	dialog.confirmed.connect(func():
		var selected := form_picker.get_selected()
		var form := str(form_picker.get_item_metadata(selected)) if selected >= 0 else ""
		var description := str(description_input.text).strip_edges()
		if form.is_empty() or description.is_empty():
			return
		decision["choice"] = {"success": true, "form": form, "description": description}
		decision["done"] = true
	)
	dialog.canceled.connect(func(): decision["done"] = true)
	dialog.close_requested.connect(func(): decision["done"] = true)
	dialog.popup_centered(Vector2i(500, 320))
	while not decision["done"]:
		await get_tree().process_frame
	dialog.queue_free()
	return decision["choice"]


func request_prestidigitation_effect() -> Dictionary:
	if GameManager.test_mode:
		return {"success": true, "effect_type": "magic_mark", "description": "A test rune"}
	var dialog := ConfirmationDialog.new()
	dialog.title = "Prestidigitation"
	dialog.dialog_text = "Choose an effect the combat grid can represent. Three non-instantaneous effects can be active at once."
	dialog.ok_button_text = "Cast"
	dialog.cancel_button_text = "Cancel"
	var content := VBoxContainer.new()
	var effect_picker := OptionButton.new()
	for choice in [
		{"label": "Harmless sensory flourish", "id": "sensory_effect"},
		{"label": "Magic mark on this space (1 hour)", "id": "magic_mark"},
		{"label": "Create a hand-sized trinket image", "id": "minor_creation"},
	]:
		effect_picker.add_item(str(choice["label"]))
		effect_picker.set_item_metadata(effect_picker.item_count - 1, str(choice["id"]))
	content.add_child(effect_picker)
	var description_input := TextEdit.new()
	description_input.placeholder_text = "Describe the effect"
	description_input.custom_minimum_size = Vector2(420, 100)
	description_input.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	content.add_child(description_input)
	dialog.add_child(content)
	add_child(dialog)
	ModalSurface.watch_window(dialog)
	var decision := {"done": false, "choice": {}}
	dialog.confirmed.connect(func():
		var selected := effect_picker.get_selected()
		var effect_type := str(effect_picker.get_item_metadata(selected)) if selected >= 0 else ""
		var description := str(description_input.text).strip_edges()
		if effect_type.is_empty() or description.is_empty():
			return
		decision["choice"] = {"success": true, "effect_type": effect_type, "description": description}
		decision["done"] = true
	)
	dialog.canceled.connect(func(): decision["done"] = true)
	dialog.close_requested.connect(func(): decision["done"] = true)
	dialog.popup_centered(Vector2i(500, 320))
	while not decision["done"]:
		await get_tree().process_frame
	dialog.queue_free()
	return decision["choice"]


func request_produce_flame_choice(has_flame: bool) -> String:
	if GameManager.test_mode:
		return "hurl" if has_flame else "create"
	if not has_flame:
		return "create"
	var dialog := Window.new()
	dialog.title = "Produce Flame"
	dialog.size = Vector2i(520, 150)
	var content := VBoxContainer.new()
	var prompt := Label.new()
	prompt.text = "Choose an action for the flame in your hand."
	content.add_child(prompt)
	var buttons := HBoxContainer.new()
	content.add_child(buttons)
	var choice := {"done": false, "value": ""}
	for option in [
		{"label": "Hurl Fire · Magic action", "id": "hurl"},
		{"label": "Create / replace · Bonus Action", "id": "create"},
		{"label": "Cancel", "id": ""},
	]:
		var button := Button.new()
		button.text = str(option["label"])
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_complete_produce_flame_choice.bind(choice, str(option["id"])))
		buttons.add_child(button)
	dialog.add_child(content)
	add_child(dialog)
	ModalSurface.watch_window(dialog)
	dialog.close_requested.connect(func(): choice["done"] = true)
	dialog.popup_centered(Vector2i(520, 150))
	while not choice["done"]:
		await get_tree().process_frame
	dialog.queue_free()
	return str(choice["value"])


func _complete_produce_flame_choice(choice: Dictionary, mode: String) -> void:
	choice["value"] = mode
	choice["done"] = true


func request_resistance_damage_type() -> String:
	var types: Array[String] = ["acid", "bludgeoning", "cold", "fire", "lightning", "necrotic", "piercing", "poison", "radiant", "slashing", "thunder"]
	if GameManager.test_mode:
		return "fire"
	var labels: Dictionary = {}
	for damage_type in types:
		labels[damage_type] = damage_type.capitalize()
	return await _request_popup_choice("Choose Resistance's damage type", types, labels)


func request_monk_bonus_action(feature_id: String) -> String:
	var defense := feature_id == "monk_patient_defense"
	if GameManager.test_mode:
		return "disengage" if defense else "dash"
	var menu := PopupMenu.new()
	menu.add_item("Disengage (free)" if defense else "Dash (free)", 1)
	menu.add_item("Disengage + Dodge (1 Focus)" if defense else "Dash + Disengage (1 Focus)", 2)
	menu.set_item_disabled(1, active_character == null or active_character.get_focus_points() < 1)
	add_child(menu)
	menu.popup_centered(Vector2i(320, 120))
	var decision := {"selected": "", "done": false}
	menu.id_pressed.connect(func(id: int):
		decision["selected"] = ("disengage" if defense else "dash") if id == 1 else ("disengage_dodge" if defense else "dash_disengage")
		decision["done"] = true
	)
	menu.popup_hide.connect(func(): decision["done"] = true)
	var timeout := get_tree().create_timer(8.0)
	while not decision["done"] and timeout.time_left > 0.0:
		await get_tree().process_frame
	menu.queue_free()
	return str(decision["selected"])


## Choose Divine Spark's healing or damage option and, for damage, its type.
func request_divine_spark_choice() -> Dictionary:
	if GameManager.test_mode:
		return {"mode": "heal", "damage_type": "radiant"}
	var mode := await _request_popup_choice("Choose Divine Spark's effect", ["heal", "harm"], {"heal": "Restore Hit Points", "harm": "Deal damage (saving throw)"})
	if mode.is_empty():
		return {}
	if mode == "heal":
		return {"mode": mode, "damage_type": "radiant"}
	var damage_type := await _request_popup_choice("Choose Divine Spark's damage", ["radiant", "necrotic"], {"radiant": "Radiant", "necrotic": "Necrotic"})
	return {} if damage_type.is_empty() else {"mode": mode, "damage_type": damage_type}


func request_conjure_celestial_light(target_name: String) -> String:
	if GameManager.test_mode:
		return "searing"
	return await _request_popup_choice("Choose a Conjure Celestial light for %s" % target_name, ["healing", "searing"], {"healing": "Healing Light", "searing": "Searing Light"})


func request_conjure_elemental_element() -> String:
	if GameManager.test_mode:
		return "air"
	return await _request_popup_choice("Choose the Conjure Elemental spirit's form", ["air", "earth", "fire", "water"], {"air": "Air (Lightning)", "earth": "Earth (Thunder)", "fire": "Fire (Fire)", "water": "Water (Cold)"})


func request_conjure_fey_attack_target(targets: Array) -> String:
	var options: Array[String] = []
	var labels: Dictionary = {}
	for target in targets:
		var target_id := str(target.get("id", ""))
		if target_id.is_empty():
			continue
		options.append(target_id)
		labels[target_id] = str(target.get("name", "The creature"))
	if options.is_empty():
		return ""
	if GameManager.test_mode:
		return options[0]
	return await _request_popup_choice("Choose a creature for Conjure Fey's melee spell attack", options, labels)


func request_identify_mode(seeded_mode: String = "") -> String:
	if GameManager.test_mode:
		return seeded_mode if seeded_mode in ["item", "creature"] else "item"
	return await _request_popup_choice("Identify an object or a creature?", ["item", "creature"], {"item": "An item you carry", "creature": "A creature you touch"})


func request_identify_item_choice(items: Array[Dictionary], seeded_item_id: String = "") -> String:
	var options: Array[String] = []
	var labels: Dictionary = {}
	for item in items:
		var item_id := str(item.get("id", ""))
		if item_id.is_empty():
			continue
		options.append(item_id)
		var state: Dictionary = item.get("copy_state", {})
		labels[item_id] = "%s%s" % [str(item.get("name", item_id)), " (%d charges)" % int(state["charges"]) if state.has("charges") else ""]
	if options.is_empty():
		return ""
	if GameManager.test_mode:
		return seeded_item_id if seeded_item_id in options else options[0]
	return await _request_popup_choice("Choose the item you touch throughout Identify's casting", options, labels)


func request_divine_intervention_spell(character: Character) -> Dictionary:
	var options := ClericRules.divine_intervention_spell_options(character)
	return await _request_spell_catalog_choice(options, "Choose a Cleric spell for Divine Intervention")


func request_wish_duplication_spell() -> Dictionary:
	var options := ClericRules.wish_duplication_spell_options()
	return await _request_spell_catalog_choice(options, "Choose a catalog spell (level 8 or lower) to duplicate with Wish")


func _request_spell_catalog_choice(options: Array[Dictionary], prompt: String) -> Dictionary:
	if options.is_empty():
		return {}
	if GameManager.test_mode:
		return options[0]
	var menu := PopupMenu.new()
	menu.title = prompt
	for index in options.size():
		var spell: Dictionary = options[index]
		menu.add_item("%s (Level %d)" % [str(spell.get("name", spell.get("id", "Spell"))), int(spell.get("level", 0))], index)
	add_child(menu)
	var decision := {"selected": -1, "done": false}
	menu.id_pressed.connect(func(id: int):
		decision["selected"] = id
		decision["done"] = true
	)
	menu.popup_hide.connect(func(): decision["done"] = true)
	menu.popup_centered(Vector2i(460, 520))
	var timeout := get_tree().create_timer(30.0)
	while not decision["done"] and timeout.time_left > 0.0:
		await get_tree().process_frame
	menu.queue_free()
	var selected := int(decision["selected"])
	return options[selected] if selected >= 0 and selected < options.size() else {}


## Select one of the three Cunning Action bonus-action options.
## Test mode chooses Dash so headless action routing remains bounded.
func request_cunning_action() -> String:
	return await request_movement_bonus_action(true)


## Select a bonus-action movement option. Cunning Action also exposes Hide;
## Step of the Wind is limited to Dash and Disengage.
func request_movement_bonus_action(include_hide: bool) -> String:
	if GameManager.test_mode:
		return "dash"
	var menu := PopupMenu.new()
	menu.add_item("Dash", 1)
	menu.add_item("Disengage", 2)
	if include_hide:
		menu.add_item("Hide", 3)
	add_child(menu)
	menu.popup_centered(Vector2i(260, 150))
	var decision := {"done": false, "selected": ""}
	menu.id_pressed.connect(func(id: int):
		decision["selected"] = {1: "dash", 2: "disengage", 3: "hide"}.get(id, "") if include_hide else {1: "dash", 2: "disengage"}.get(id, "")
		decision["done"] = true
	)
	menu.popup_hide.connect(func(): decision["done"] = true)
	var timeout := get_tree().create_timer(8.0)
	while not decision["done"] and timeout.time_left > 0.0:
		await get_tree().process_frame
	menu.queue_free()
	return str(decision["selected"])


func request_turn_undead_targets(candidates: Array[Dictionary]) -> Array[String]:
	var selected: Array[String] = []
	if GameManager.test_mode:
		for candidate in candidates:
			selected.append(str(candidate["id"]))
		return selected
	var labels: Dictionary = {"__done": "Turn selected creatures", "__cancel": "Cancel"}
	for candidate in candidates:
		labels[str(candidate["id"])] = str(candidate.get("name", "Undead"))
	while true:
		var options: Array[String] = []
		for candidate in candidates:
			var id := str(candidate["id"])
			if id not in selected:
				options.append(id)
		options.append_array(["__done", "__cancel"])
		var choice := await _request_popup_choice("Turn Undead: choose creatures within 30 feet", options, labels)
		if choice.is_empty() or choice == "__cancel":
			return []
		if choice == "__done":
			return selected
		selected.append(choice)
	return selected


func request_cleric_vitality_target(candidates: Array[Dictionary]) -> String:
	if candidates.is_empty():
		return ""
	if GameManager.test_mode:
		return str(candidates[0]["id"])
	var options: Array[String] = []
	var labels: Dictionary = {"__skip": "Skip temporary Hit Points"}
	for candidate in candidates:
		var id := str(candidate["id"])
		options.append(id)
		labels[id] = str(candidate["name"])
	options.append("__skip")
	return await _request_popup_choice("Potent Spellcasting: grant vitality within 60 feet", options, labels)


## Offer pre-roll d20 token replacement (e.g. Diviner Portent) before the roll is made.
## In test_mode without a seeded choice, returns {} so automated headless runs do not spend Portent dice.
func request_roll_token_replacement(roller_name: String, test_label: String, options: Array[Dictionary], seeded_token_id: String = "") -> Dictionary:
	if options.is_empty():
		return {}
	if not seeded_token_id.is_empty():
		for opt in options:
			if str(opt.get("token_id", "")) == seeded_token_id:
				return {
					"use_token": true,
					"owner": opt.get("owner"),
					"owner_id": str(opt.get("owner_id", "")),
					"pool_id": str(opt.get("pool_id", "")),
					"token_id": str(opt.get("token_id", "")),
					"value": int(opt.get("value", 0)),
				}
		return {}
	if GameManager.test_mode:
		return {}
	var owner_label := str(options[0].get("owner_name", "Player"))
	var source_label := str(options[0].get("source_name", "Portent"))
	var dialog := ConfirmationDialog.new()
	dialog.title = "%s — %s Replacement" % [owner_label, source_label]
	dialog.dialog_text = "Pass to %s.\n\n%s is about to make a %s.\nReplace the d20 roll before rolling?" % [owner_label, roller_name, test_label]
	dialog.ok_button_text = "Replace Roll"
	dialog.cancel_button_text = "Roll Normally"
	var content := VBoxContainer.new()
	var picker_label := Label.new()
	picker_label.text = "Select a stored roll token:"
	content.add_child(picker_label)
	var picker := OptionButton.new()
	picker.name = "RollTokenOptionPicker"
	for idx in options.size():
		var opt: Dictionary = options[idx]
		picker.add_item(str(opt.get("label", "Token #%d (%d)" % [idx + 1, int(opt.get("value", 1))])), idx)
		picker.set_item_metadata(idx, opt.duplicate(true))
	picker.select(0)
	content.add_child(picker)
	dialog.add_child(content)
	add_child(dialog)
	ModalSurface.watch_window(dialog)
	var decision := {"done": false, "accepted": false, "selected_index": 0}
	dialog.confirmed.connect(func():
		decision["accepted"] = true
		decision["selected_index"] = picker.selected
		decision["done"] = true
	)
	dialog.canceled.connect(func(): decision["done"] = true)
	dialog.close_requested.connect(func(): decision["done"] = true)
	dialog.popup_centered(Vector2i(460, 210))
	var timeout := get_tree().create_timer(15.0)
	while not decision["done"] and timeout.time_left > 0.0:
		await get_tree().process_frame
	var selected_idx := int(decision["selected_index"])
	# Release the exclusive modal before an ordered cast opens its next choice.
	dialog.hide()
	dialog.queue_free()
	if not bool(decision["accepted"]) or selected_idx < 0 or selected_idx >= options.size():
		return {}
	var chosen: Dictionary = options[selected_idx]
	return {
		"use_token": true,
		"owner": chosen.get("owner"),
		"owner_id": str(chosen.get("owner_id", "")),
		"pool_id": str(chosen.get("pool_id", "")),
		"token_id": str(chosen.get("token_id", "")),
		"value": int(chosen.get("value", 0)),
	}
