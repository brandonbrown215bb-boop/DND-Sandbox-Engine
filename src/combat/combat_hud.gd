## Combat HUD Controller
## Manages combat interfaces: action selection, spell registers, logs, and initiative track.
class_name CombatHUD
extends CanvasLayer

signal action_selected(action_type: String, extra_data: Dictionary)

signal settings_pressed
signal sheet_pressed

# Node references
@onready var action_panel: PanelContainer = $MarginContainer/HBoxContainer/ControlArea/VBoxContainer/ActionMenu
@onready var btn_attack: Button = $MarginContainer/HBoxContainer/ControlArea/VBoxContainer/ActionMenu/GridContainer/BtnAttack
@onready var btn_spell: Button = $MarginContainer/HBoxContainer/ControlArea/VBoxContainer/ActionMenu/GridContainer/BtnSpell
@onready var btn_dodge: Button = $MarginContainer/HBoxContainer/ControlArea/VBoxContainer/ActionMenu/GridContainer/BtnDodge
@onready var btn_end_turn: Button = $MarginContainer/HBoxContainer/ControlArea/VBoxContainer/ActionMenu/GridContainer/BtnEndTurn

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
@onready var weapon_info: Label = $MarginContainer/HBoxContainer/Sidebar/ScrollContainer/WeaponInfo
@onready var initiative_bar: RichTextLabel = $MarginContainer/HBoxContainer/ControlArea/VBoxContainer/InitiativePanel/InitiativeBar
@onready var hint_label: Label = $MarginContainer/HBoxContainer/ControlArea/VBoxContainer/HintLabel
@onready var log_text: RichTextLabel = $MarginContainer/HBoxContainer/ControlArea/VBoxContainer/LogBox/LogText

var active_character: Character
var spells_registered: Array[Dictionary] = []
var features_registered: Array[Dictionary] = []


func _ready() -> void:
	# Connect base buttons
	btn_attack.pressed.connect(func(): action_selected.emit("attack", {}))
	btn_dodge.pressed.connect(func(): action_selected.emit("dodge", {}))
	btn_end_turn.pressed.connect(func(): action_selected.emit("end_turn", {}))

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

	# Start hidden
	spell_menu.visible = false
	feature_menu.visible = false
	clear_logs()


## Clear all logs.
func clear_logs() -> void:
	if log_text != null:
		log_text.text = ""


## Add a log entry.
func add_log(msg: String) -> void:
	if log_text == null: return
	log_text.text += msg + "\n"
	# Auto scroll
	var scroll = log_text.get_v_scroll_bar()
	if scroll:
		scroll.value = scroll.max_value


## Enable or disable character controls.
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


## Draw/update the HUD.
func update_hud(active_char: Character, tracker: InitiativeTracker) -> void:
	active_character = active_char
	_update_initiative_list(tracker)
	_update_sidebar_stats()
	_update_weapon_info(active_char)
	
	# Disable spell casting if character has no spells
	if active_char != null:
		var has_spells := not active_char.known_spells.is_empty()
		if not has_spells:
			var cls_data := DataLoader.get_character_class(active_char.class_id)
			if cls_data != null:
				var cantrips: Array = cls_data.get("cantrips_known", [])
				var spells_table: Dictionary = cls_data.get("spells_known_by_level", {})
				var has_table_spells := false
				for lvl in spells_table:
					if not spells_table[lvl].is_empty():
						has_table_spells = true
						break
				has_spells = not cantrips.is_empty() or has_table_spells
		btn_spell.disabled = not has_spells

		# Disable features button if character has no active features
		var has_active := false
		for f in active_char.features:
			if f.get("type", "") == "active":
				has_active = true
				break
		btn_features.disabled = not has_active


func _update_initiative_list(tracker: InitiativeTracker) -> void:
	var init_text := "[b]Initiative Order:[/b]\n"
	for i in tracker.combatants.size():
		var c := tracker.combatants[i]
		var pointer := " ➔ " if i == tracker.active_index else "    "
		var color := "yellow" if c["is_player"] else "red"
		init_text += "%s[color=%s]%s[/color] (Roll: %d)\n" % [pointer, color, c["name"], c["roll"]]
	initiative_bar.text = init_text


func _update_sidebar_stats() -> void:
	if active_character == null:
		info_label.text = "No active character."
		return

	var text := "Active Turn:\n[b]%s[/b]\n" % active_character.character_name
	text += "Level %d %s\n" % [active_character.level, DataLoader.get_character_class(active_character.class_id).get("name", "")]
	text += "HP: %d / %d\n" % [active_character.current_hp, active_character.max_hp]
	text += "AC: %d\n" % active_character.get_ac()
	text += "Speed: %d hexes\n\n" % active_character.speed

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
			var max_uses = f.get("uses", 1)
			text += "- %s: %d/%d uses\n" % [f.get("name", f_id), current_uses, max_uses]
	if has_uses:
		text += "\n"

	# Active conditions
	if not active_character.conditions.is_empty():
		text += "Conditions:\n"
		for cond in active_character.conditions:
			text += "- %s (%d turns)\n" % [cond, active_character.conditions[cond]]

	info_label.text = text


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

func _show_spell_selection() -> void:
	if active_character == null: return
	
	action_panel.visible = false
	spell_menu.visible = true
	spell_list.clear()
	spells_registered.clear()

	# Retrieve list of spells known
	var list_spells: Array = active_character.known_spells.duplicate()
	
	# Fetch Wizard starting cantrips/spells if relevant
	var wiz_class := DataLoader.get_character_class(active_character.class_id)
	var cantrips: Array = wiz_class.get("cantrips_known", [])
	for c_id in cantrips:
		if c_id not in list_spells:
			list_spells.append(c_id)

	# Wizard spells known
	var spells_known_table: Dictionary = wiz_class.get("spells_known_by_level", {})
	for lvl in spells_known_table:
		var list_at_lvl: Array = spells_known_table[lvl]
		for s_id in list_at_lvl:
			# Wizard must have slot capacity to cast
			if s_id not in list_spells:
				list_spells.append(s_id)

	for s_id in list_spells:
		var spell_data := DataLoader.get_spell(s_id)
		if spell_data.is_empty(): continue

		var lvl: int = int(spell_data.get("level", 0))
		var lvl_str := "Cantrip" if lvl == 0 else "Lvl %d" % lvl
		var display_name := "%s (%s) - %s" % [spell_data.get("name", s_id), lvl_str, spell_data.get("damage_type", "utility")]
		
		# Gray out if no spell slots left
		var disabled := false
		if lvl > 0:
			var slot_key := str(lvl)
			var current_slots: int = active_character.spell_slots.get(slot_key, 0)
			if current_slots <= 0:
				disabled = true
				display_name += " [No slots]"

		spell_list.add_item(display_name)
		var item_idx := spell_list.get_item_count() - 1
		spell_list.set_item_disabled(item_idx, disabled)
		spells_registered.append(spell_data)


func _hide_spell_selection() -> void:
	spell_menu.visible = false
	action_panel.visible = true


func _on_spell_selected(index: int) -> void:
	if index < 0 or index >= spells_registered.size(): return
	var spell := spells_registered[index]
	_hide_spell_selection()
	action_selected.emit("cast_spell", {"spell": spell})


# --- Feature Selection panel ---

func _show_feature_selection() -> void:
	if active_character == null: return
	
	action_panel.visible = false
	feature_menu.visible = true
	feature_list.clear()
	features_registered.clear()

	for f in active_character.features:
		if f.get("type", "") != "active": continue

		var f_id = f["id"]
		var current_uses: int = active_character.feature_uses.get(f_id, 0)
		var max_uses: int = f.get("uses", 1)
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
	feature_menu.visible = false
	action_panel.visible = true


func _on_feature_selected(index: int) -> void:
	if index < 0 or index >= features_registered.size(): return
	var feature := features_registered[index]
	_hide_feature_selection()
	action_selected.emit("use_feature", {"feature": feature})
