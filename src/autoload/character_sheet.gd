## Character Sheet
## Autoloaded singleton that renders an overlay of a character's full
## stats/variables. Reachable from overworld, dungeon, and combat. Pass any
## Character (e.g. the active player's) to show_sheet(); show_active() shows the
## current PlayerManager active character.
##
## The overlay is a CanvasLayer (drawn above scene HUDs). It does NOT pause the
## tree, so the player reads and closes on their own time.
extends Node

signal sheet_opened(character: Character)
signal sheet_closed

var _layer: CanvasLayer = null
var _content: VBoxContainer = null
var _title: Label = null
var _open_char: Character = null

## Standard D&D 5e skills -> governing ability.
const SKILLS := [
	"Acrobatics", "Animal Handling", "Arcana", "Athletics", "Deception",
	"History", "Insight", "Intimidation", "Investigation", "Medicine",
	"Nature", "Perception", "Performance", "Persuasion", "Religion",
	"Sleight of Hand", "Stealth", "Survival",
]
const SKILL_ABILITY := {
	"Acrobatics": "DEX", "Animal Handling": "WIS", "Arcana": "INT",
	"Athletics": "STR", "Deception": "CHA", "History": "INT",
	"Insight": "WIS", "Intimidation": "CHA", "Investigation": "INT",
	"Medicine": "WIS", "Nature": "INT", "Perception": "WIS",
	"Performance": "CHA", "Persuasion": "CHA", "Religion": "INT",
	"Sleight of Hand": "DEX", "Stealth": "DEX", "Survival": "WIS",
}


func _ensure_layer() -> void:
	if _layer != null:
		return
	_layer = CanvasLayer.new()
	_layer.name = "CharacterSheetLayer"
	_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	_layer.layer = 128  # above scene HUD and Settings (Settings uses 100)
	get_tree().root.add_child(_layer)

	var center := CenterContainer.new()
	_layer.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(780, 640)
	center.add_child(panel)

	var outer := MarginContainer.new()
	outer.add_theme_constant_override("margin_left", 16)
	outer.add_theme_constant_override("margin_right", 16)
	outer.add_theme_constant_override("margin_top", 16)
	outer.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(outer)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	outer.add_child(vbox)

	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 22)
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title.add_theme_color_override("font_color", UiThemeProfile.current().color("text/primary"))
	vbox.add_child(_title)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 6)
	scroll.add_child(_content)

	var close_btn := Button.new()
	close_btn.text = "Close (Esc)"
	close_btn.pressed.connect(close_sheet)
	vbox.add_child(close_btn)
	panel.theme_type_variation = "OverlayPanel"
	ModalSurface.install(center, close_sheet)


## Whether the sheet overlay is currently open.
func is_open() -> bool:
	return _open_char != null


## Show the sheet for a specific character.
func show_sheet(character: Character) -> void:
	if character == null:
		return
	_ensure_layer()
	_open_char = character
	_populate(character)
	UiThemeProfile.current().style(_content)
	_layer.visible = true
	sheet_opened.emit(character)


## Show the sheet for the active PlayerManager character (overworld/dungeon).
func show_active() -> void:
	if PlayerManager == null or PlayerManager.get_player_count() == 0:
		return
	var player: Dictionary = PlayerManager.get_active_player()
	var char_data: Character = player.get("character")
	show_sheet(char_data)


## Close the sheet.
func close_sheet() -> void:
	if _layer != null:
		_layer.visible = false
	_open_char = null
	sheet_closed.emit()


## Release the lazily-created overlay for isolated engine tests. Production
## keeps the layer hidden for reuse between opens.
func teardown_for_tests() -> void:
	if not GameManager.test_mode:
		return
	if _layer != null:
		_layer.queue_free()
	_layer = null
	_content = null
	_title = null
	_open_char = null


func _unhandled_input(event: InputEvent) -> void:
	if _open_char != null and event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and key.keycode == KEY_ESCAPE:
			close_sheet()


func _populate(c: Character) -> void:
	if c.class_id == "fighter":
		c._recalculate_ac()
	_clear_content()
	_title.text = "%s  —  Lvl %d %s %s" % [
		c.character_name, c.level,
		DataLoader.get_race(c.race_id).get("name", c.race_id),
		DataLoader.get_character_class(c.class_id).get("name", c.class_id),
	]

	# --- Core vitals ---
	var vitals := "HP %d/%d   Temp %d   AC %d   Speed %d   Prof +%d" % [
		c.current_hp, c.max_hp, c.temp_hp, c.get_ac(), c.get_speed(), c.proficiency_bonus
	]
	if c.get_max_focus_points() > 0:
		vitals += "   Focus %d/%d" % [c.get_focus_points(), c.get_max_focus_points()]
	if DruidRules.is_shaped(c):
		vitals += "   Form: %s" % DruidRules.current_form(c).get("name", "Beast")
	_add_section("Vitals", [vitals])
	_add_section("Recovery", [CorpseRules.status(c, int(GameManager.campaign_elapsed_seconds))])
	var revival_choice := CheckBox.new()
	revival_choice.name = "RevivalWillingness"
	revival_choice.text = "Accept magical revival if I die"
	revival_choice.button_pressed = c.revival_willing
	revival_choice.toggled.connect(func(accepted): c.revival_willing = accepted)
	_content.add_child(revival_choice)
	if c.has_feature("druid_wild_shape"):
		var wild_shape_button := Button.new()
		wild_shape_button.text = "Return to normal form" if DruidRules.is_shaped(c) else "Use Wild Shape"
		wild_shape_button.tooltip_text = "Choose one of your learned Beast forms. Wild Shape uses recover through the normal Short Rest and Long Rest rules."
		wild_shape_button.pressed.connect(_choose_wild_shape_form.bind(c))
		_content.add_child(wild_shape_button)
	if not DataLoader.get_subclasses_for_class(c.class_id).is_empty() or not ClassProgression.improvement_ids(c).is_empty() or not ClassProgression.skill_choice_ids(c).is_empty() or not ClassProgression.epic_boon_choice_ids(c).is_empty() or c.has_feature_effect("weapon_mastery") or c.has_feature_effect("spellcasting"):
		var progression := ClassTraining.new()
		_content.add_child(progression)
		progression.configure(c, func(): _populate(c))
	if c.class_id == "fighter":
		var training := FighterTraining.new()
		_content.add_child(training)
		training.configure(c, func(): _populate(c))


	# --- Ability scores + modifiers ---
	var abil_lines: Array[String] = []
	for ab in AbilityScores.ABILITIES:
		var score: int = c.ability_scores.get_score(ab)
		var mod: int = c.ability_scores.get_ability_modifier(ab)
		abil_lines.append("%s %2d (%+d)" % [ab, score, mod])
	_add_section("Ability Scores", abil_lines)

	# --- Saving throws ---
	var save_lines: Array[String] = []
	for ab in AbilityScores.ABILITIES:
		var prof: bool = c.is_proficient_in_save(ab)
		var total := c.ability_scores.get_ability_modifier(ab) + (c.proficiency_bonus if prof else 0)
		save_lines.append("%s %+d%s" % [ab, total, " *" if prof else ""])
	_add_section("Saving Throws  (* proficient)", save_lines)

	# --- Skills ---
	var skill_lines: Array[String] = []
	for sk in SKILLS:
		var ab: String = SKILL_ABILITY.get(sk, "DEX")
		var prof_bonus := c.get_skill_proficiency_bonus(sk)
		var total := c.ability_scores.get_ability_modifier(ab) + prof_bonus + c.get_ability_check_bonus(sk)
		var marker := " **" if prof_bonus == c.proficiency_bonus * 2 else (" *" if prof_bonus > 0 else "")
		skill_lines.append("%-16s %+d%s" % [sk, total, marker])
	_add_section("Skills  (* proficient)", skill_lines)
	if not c.tool_proficiencies.is_empty():
		var tool_names: Array[String] = []
		for tool_id in c.tool_proficiencies:
			tool_names.append(str(DataLoader.get_item(tool_id).get("name", tool_id)))
		_add_section("Tool Proficiencies", tool_names)

	# --- Equipment ---
	var equip_lines: Array[String] = []
	var weapon_id: String = c.inventory.get_weapon()
	if not weapon_id.is_empty():
		var w := DataLoader.get_item(weapon_id)
		equip_lines.append("Weapon: %s (range %d)" % [w.get("name", weapon_id), int(w.get("range", 1))])
	var armor_id: String = c.inventory.get_armor()
	if not armor_id.is_empty():
		var a := DataLoader.get_item(armor_id)
		equip_lines.append("Armor: %s" % a.get("name", armor_id))
	var shield_id: String = c.inventory.get_equipped(Inventory.Slot.SHIELD)
	if not shield_id.is_empty():
		var s := DataLoader.get_item(shield_id)
		equip_lines.append("Shield: %s" % s.get("name", shield_id))
	var bp: Array = c.inventory.backpack
	if bp.size() > 0:
		equip_lines.append("Backpack (%d): %s" % [bp.size(), ", ".join(bp)])
	if equip_lines.is_empty():
		equip_lines.append("(none)")
	_add_section("Equipment  (Gold: %d)" % c.inventory.gold, equip_lines)

	# --- Conditions ---
	if c.conditions.is_empty():
		_add_section("Conditions", ["(none)"])
	else:
		var cond_lines: Array[String] = []
		for cond in c.conditions:
			if cond == "exhaustion":
				cond_lines.append("Exhaustion (level %d)" % c.exhaustion_level)
			else:
				cond_lines.append("%s (%d turns)" % [cond, int(c.conditions[cond])])
		_add_section("Conditions", cond_lines)

	# --- Spellcasting ---
	if c.spell_slots.is_empty() and c.known_spells.is_empty():
		_add_section("Spellcasting", ["(non-caster)"])
	else:
		var slot_lines: Array[String] = []
		for lvl in c.spell_slots:
			slot_lines.append("L%s slots: %d" % [lvl, int(c.spell_slots[lvl])])
		if slot_lines.is_empty():
			slot_lines.append("(no slots)")
		if c.has_feature_effect("spellcasting"):
			slot_lines.append("Spellcasting capacity: %d prepared, %d cantrips" % [c.get_spellcasting_capacity("prepared_spells"), c.get_spellcasting_capacity("cantrips")])
		_add_section("Spell Slots", slot_lines)
		if c.known_spells.size() > 0:
			_add_section("Available Spells", [", ".join(c.known_spells)])

	# --- Features + remaining uses ---
	if c.features.is_empty():
		_add_section("Features", ["(none)"])
	else:
		var feat_lines: Array[String] = []
		for feat in c.features:
			var fid: String = feat.get("id", "?")
			var name: String = feat.get("name", fid)
			var uses: int = c.feature_uses.get(fid, -1)
			var uses_str := ""
			if uses >= 0:
				uses_str = "  [%d left]" % uses
			feat_lines.append("%s%s" % [name, uses_str])
		_add_section("Class Features", feat_lines)


func _choose_wild_shape_form(character: Character) -> void:
	if character == null:
		return
	var forms := DruidRules.form_options(character)
	if forms.is_empty():
		var message := Label.new()
		message.text = "No known eligible Beast forms. Learn a form under Class Progression outside combat."
		message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_content.add_child(message)
		return
	if GameManager.test_mode:
		if DruidRules.is_shaped(character):
			DruidRules.revert(character)
		else:
			DruidRules.transform(character, str(forms[0].get("id", "")))
		_populate(character)
		return
	var menu := PopupMenu.new()
	var item_forms: Dictionary = {}
	var next_id := 1
	if DruidRules.is_shaped(character):
		menu.add_item("Return to normal form", 0)
	for form in forms:
		menu.add_item("Become %s" % str(form.get("name", form.get("id", "Beast"))), next_id)
		item_forms[next_id] = str(form.get("id", ""))
		next_id += 1
	_content.add_child(menu)
	menu.id_pressed.connect(func(id: int):
		if id == 0:
			DruidRules.revert(character)
		else:
			DruidRules.transform(character, str(item_forms.get(id, "")))
		_populate(character)
		menu.queue_free()
	)
	menu.popup_hide.connect(func(): menu.queue_free())
	menu.popup_centered(Vector2i(320, 200))


func _add_section(header: String, lines: Array[String]) -> void:
	var h := Label.new()
	h.text = header
	h.add_theme_color_override("font_color", UiThemeProfile.current().color("state/info"))
	_content.add_child(h)
	var body := Label.new()
	body.text = "\n".join(lines)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(body)


func _clear_content() -> void:
	for child in _content.get_children():
		child.queue_free()
