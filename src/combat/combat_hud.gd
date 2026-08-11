## Combat HUD Controller
## Manages combat interfaces: action selection, spell registers, logs, and initiative track.
class_name CombatHUD
extends BaseHUD

signal action_selected(action_type: String, extra_data: Dictionary)
signal cancel_pressed

# Node references
@onready var action_panel: PanelContainer = $MarginContainer/HBoxContainer/ControlArea/VBoxContainer/ActionMenu
@onready var btn_attack: Button = $MarginContainer/HBoxContainer/ControlArea/VBoxContainer/ActionMenu/GridContainer/BtnAttack
@onready var btn_spell: Button = $MarginContainer/HBoxContainer/ControlArea/VBoxContainer/ActionMenu/GridContainer/BtnSpell
@onready var btn_dodge: Button = $MarginContainer/HBoxContainer/ControlArea/VBoxContainer/ActionMenu/GridContainer/BtnDodge
@onready var btn_end_turn: Button = $MarginContainer/HBoxContainer/ControlArea/VBoxContainer/ActionMenu/GridContainer/BtnEndTurn
@onready var btn_cancel: Button = $MarginContainer/HBoxContainer/ControlArea/VBoxContainer/ActionMenu/GridContainer/BtnCancel

@onready var spell_menu: PanelContainer = $MarginContainer/HBoxContainer/ControlArea/VBoxContainer/SpellMenu
@onready var spell_list: ItemList = $MarginContainer/HBoxContainer/ControlArea/VBoxContainer/SpellMenu/SpellList
@onready var btn_cancel_spell: Button = $MarginContainer/HBoxContainer/ControlArea/VBoxContainer/SpellMenu/BtnCancelSpell

@onready var btn_features: Button = $MarginContainer/HBoxContainer/ControlArea/VBoxContainer/ActionMenu/GridContainer/BtnFeatures
@onready var btn_settings: Button = $MarginContainer/HBoxContainer/ControlArea/VBoxContainer/BtnSettings
@onready var btn_sheet: Button = $MarginContainer/HBoxContainer/ControlArea/VBoxContainer/BtnSheet
@onready var feature_menu: PanelContainer = $MarginContainer/HBoxContainer/ControlArea/VBoxContainer/FeatureMenu
@onready var feature_list: ItemList = $MarginContainer/HBoxContainer/ControlArea/VBoxContainer/FeatureMenu/FeatureList
@onready var btn_cancel_features: Button = $MarginContainer/HBoxContainer/ControlArea/VBoxContainer/FeatureMenu/BtnCancelFeatures

@onready var info_label: Label = $MarginContainer/HBoxContainer/Sidebar/ScrollContainer/EntityInfo
@onready var entity_hp_bar = $MarginContainer/HBoxContainer/Sidebar/ScrollContainer/EntityHpBar
@onready var weapon_info: Label = $MarginContainer/HBoxContainer/Sidebar/ScrollContainer/WeaponInfo
@onready var initiative_bar: RichTextLabel = $MarginContainer/HBoxContainer/ControlArea/VBoxContainer/InitiativePanel/InitiativeBar
@onready var hint_label: Label = $MarginContainer/HBoxContainer/ControlArea/VBoxContainer/HintLabel
@onready var mode_banner: Label = $MarginContainer/HBoxContainer/ControlArea/VBoxContainer/ModeBanner
@onready var dice_display: Node = null

## Rook's Touch: combat UI mode state machine. Centralizes the scattered
## show/hide of action menu vs spell/feature panels so the player always
## knows what state they're in (the banner makes it legible).
enum Mode { SELECT, SPELL, FEATURE }
var current_mode := Mode.SELECT

var active_character: Character
var spells_registered: Array[Dictionary] = []
var features_registered: Array[Dictionary] = []


## Ask the owning local player whether to spend a reaction. The prompt is
## deliberately in-shell and names the seat so companion ownership is clear.
## Headless test mode declines immediately rather than waiting for input.
func request_reaction(owner_label: String, reaction_id: String, detail: String, decision_prompt: String = "Use this reaction?") -> bool:
	if GameManager.test_mode:
		return false
	var dialog := ConfirmationDialog.new()
	dialog.title = "Reaction — %s" % owner_label
	dialog.dialog_text = "%s\n\n%s\n\n%s" % [owner_label, detail, decision_prompt]
	dialog.ok_button_text = "Use Reaction"
	dialog.cancel_button_text = "Decline"
	add_child(dialog)
	dialog.popup_centered(Vector2i(460, 220))
	var resolved := false
	var accepted := false
	dialog.confirmed.connect(func():
		accepted = true
		resolved = true
	)
	dialog.canceled.connect(func(): resolved = true)
	dialog.close_requested.connect(func(): resolved = true)
	var timeout := get_tree().create_timer(8.0)
	while not resolved and timeout.time_left > 0.0:
		await get_tree().process_frame
	if not resolved:
		add_log("[color=gray]%s reaction timed out and was declined.[/color]" % owner_label)
	dialog.queue_free()
	return accepted


func _ready() -> void:
	# Connect base buttons
	btn_attack.pressed.connect(func(): action_selected.emit("attack", {}))
	btn_dodge.pressed.connect(func(): action_selected.emit("dodge", {}))
	btn_end_turn.pressed.connect(func(): action_selected.emit("end_turn", {}))
	btn_cancel.pressed.connect(func(): cancel_pressed.emit())

	# Connect spell panel
	btn_spell.pressed.connect(_show_spell_selection)
	btn_cancel_spell.pressed.connect(_hide_spell_selection)
	spell_list.item_selected.connect(_on_spell_selected)

	# Connect features panel
	btn_features.pressed.connect(_show_feature_selection)
	btn_cancel_features.pressed.connect(_hide_feature_selection)
	feature_list.item_selected.connect(_on_feature_selected)
	btn_settings.pressed.connect(func(): settings_pressed.emit())
	btn_sheet.pressed.connect(func(): sheet_pressed.emit())

	# Assign the inherited log_text (declared in BaseHUD, not re-declared here).
	log_text = $MarginContainer/HBoxContainer/ControlArea/VBoxContainer/LogBox/LogText

	# Dice roll overlay is a sibling node; hide it on demand (e.g. when an
	# attack is cancelled mid-roll-fade so it doesn't linger over the board).
	dice_display = get_node_or_null("DiceRollDisplay")

	# Start in SELECT mode with the banner set.
	set_mode(Mode.SELECT)
	clear_logs()


## Esc / escape-hatch handling: back out of any sub-menu to SELECT, AND cancel
## any in-progress combat targeting (attack/spell) via cancel_pressed.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		cancel_pressed.emit()
		if current_mode != Mode.SELECT:
			set_mode(Mode.SELECT)


## Clear all logs.
## Enable or disable character controls.
## (log_text, clear_logs(), add_log() inherited from BaseHUD.)
func set_controls_disabled(disabled: bool) -> void:
	btn_attack.disabled = disabled
	btn_spell.disabled = disabled
	btn_features.disabled = disabled
	btn_dodge.disabled = disabled
	btn_end_turn.disabled = disabled


## Show a contextual hint banner (dismissible guidance on first turns).
func show_hint(msg: String) -> void:
	if hint_label == null: return
	hint_label.text = msg
	hint_label.visible = true


## Hide the hint banner.
func hide_hint() -> void:
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
	action_panel.visible = (m == Mode.SELECT)
	spell_menu.visible = (m == Mode.SPELL)
	feature_menu.visible = (m == Mode.FEATURE)
	match m:
		Mode.SELECT: mode_banner.text = "● SELECT — choose an action"
		Mode.SPELL: mode_banner.text = "● SPELL — pick a spell (Esc/Cancel to back out)"
		Mode.FEATURE: mode_banner.text = "● FEATURE — pick a class feature"
	# Brief emphasis pulse so the mode change reads at a glance.
	if mode_banner != null and is_instance_valid(mode_banner):
		var t := create_tween()
		t.tween_property(mode_banner, "modulate:a", 0.35, 0.0)
		t.tween_property(mode_banner, "modulate:a", 1.0, 0.25)


## Draw/update the HUD.
func update_hud(active_char: Character, tracker: InitiativeTracker) -> void:
	active_character = active_char
	set_mode(Mode.SELECT)
	_clear_spell_selection()
	_update_initiative_list(tracker)
	_update_sidebar_stats()
	_update_weapon_info(active_char)
	
	# Character.known_spells is the ownership boundary. Class tables describe
	# progression access; they are not an alternate per-turn spell inventory.
	btn_spell.disabled = active_char == null or active_char.known_spells.is_empty()

	if active_char != null:
		# Disable features button if character has no active features
		var has_active := false
		for f in active_char.features:
			if f.get("type", "") == "active":
				has_active = true
				break
		btn_features.disabled = not has_active


func _update_initiative_list(tracker: InitiativeTracker) -> void:
	# Compact single-line strip: active combatant leads with a ➔, others follow.
	# Players gold, monsters red. Keeps the turn order legible without eating
	# vertical space (Rook's Touch: one row, not a stacked list).
	var chips: Array[String] = []
	for i in tracker.combatants.size():
		var c := tracker.combatants[i]
		var lead := "➔ " if i == tracker.active_index else ""
		var color := "gold" if c["is_player"] else "indianred"
		chips.append("%s[color=%s]%s[/color]" % [lead, color, c["name"]])
	initiative_bar.text = "[b]Order:[/b]  " + "  ›  ".join(chips)


func _update_sidebar_stats() -> void:
	if active_character == null:
		info_label.text = "No active character."
		return

	var text := "Active Turn:\n[b]%s[/b]\n" % active_character.character_name
	text += "Level %d %s\n" % [active_character.level, DataLoader.get_character_class(active_character.class_id).get("name", "")]
	text += "HP: %d / %d\n" % [active_character.current_hp, active_character.max_hp]
	text += "AC: %d\n" % active_character.get_ac()
	text += "Speed: %d hexes\n\n" % active_character.get_speed()

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

	# The active Character owns the complete per-turn spell inventory.
	var list_spells: Array = active_character.known_spells.duplicate()

	for s_id in list_spells:
		var spell_data := DataLoader.get_spell(s_id)
		if spell_data.is_empty(): continue

		var lvl: int = int(spell_data.get("level", 0))
		var lvl_str := "Cantrip" if lvl == 0 else "Lvl %d" % lvl
		var display_name := "%s (%s) - %s" % [spell_data.get("name", s_id), lvl_str, spell_data.get("damage_type", "utility")]
		
		# Gray out if no spell slots left
		var disabled := false
		if str(spell_data.get("casting_time", "action")) == "reaction":
			disabled = true
			display_name += " [Reaction only]"
		if lvl > 0:
			var slot_key := str(CombatAction.get_spell_slot_level(active_character, spell_data))
			var current_slots: int = active_character.spell_slots.get(slot_key, 0)
			if current_slots <= 0:
				disabled = true
				display_name += " [No slots]"

		spell_list.add_item(display_name)
		var item_idx := spell_list.get_item_count() - 1
		spell_list.set_item_disabled(item_idx, disabled)
		spells_registered.append(spell_data)


func _hide_spell_selection() -> void:
	set_mode(Mode.SELECT)


func _on_spell_selected(index: int) -> void:
	if index < 0 or index >= spells_registered.size(): return
	var spell := spells_registered[index]
	_hide_spell_selection()
	action_selected.emit("cast_spell", {"spell": spell})


# --- Feature Selection panel ---

func _show_feature_selection() -> void:
	if active_character == null: return
	
	set_mode(Mode.FEATURE)
	feature_list.clear()

	for f in active_character.features:
		if f.get("type", "") != "active": continue

		var f_id = f["id"]
		var current_uses: int = active_character.feature_uses.get(f_id, 0)
		var max_uses: int = active_character.get_feature_max_uses(str(f_id), f)
		var uses_per: String = f.get("uses_per", "combat")
		var display_name := "%s (%d/%d uses per %s)" % [f.get("name", f_id), current_uses, max_uses, uses_per]
		
		# Gray out if no uses left
		var disabled := current_uses <= 0
		if disabled:
			display_name += " [No uses]"

		feature_list.add_item(display_name)
		var item_idx := feature_list.get_item_count() - 1
		feature_list.set_item_disabled(item_idx, disabled)
		features_registered.append(f)


func _hide_feature_selection() -> void:
	set_mode(Mode.SELECT)


func _on_feature_selected(index: int) -> void:
	if index < 0 or index >= features_registered.size(): return
	var feature := features_registered[index]
	_hide_feature_selection()
	if feature.get("id", "") in ["rogue_cunning_action", "monk_step_of_the_wind"]:
		var selected_action := await request_movement_bonus_action(feature.get("id", "") == "rogue_cunning_action")
		if selected_action.is_empty():
			return
		feature = feature.duplicate(true)
		feature["selected_action"] = selected_action
	action_selected.emit("use_feature", {"feature": feature})


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
	var resolved := false
	var selected := ""
	menu.id_pressed.connect(func(id: int):
		selected = {1: "dash", 2: "disengage", 3: "hide"}.get(id, "") if include_hide else {1: "dash", 2: "disengage"}.get(id, "")
		resolved = true
	)
	menu.popup_hide.connect(func(): resolved = true)
	var timeout := get_tree().create_timer(8.0)
	while not resolved and timeout.time_left > 0.0:
		await get_tree().process_frame
	menu.queue_free()
	return selected
