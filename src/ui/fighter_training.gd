## Fighter choices stay on the Character Sheet, so an interrupted level-up
## never loses an unspent improvement. Mutations use the production rules.
class_name FighterTraining
extends VBoxContainer

var character: Character
var refresh: Callable
var status: Label

func configure(c: Character, on_change: Callable) -> void:
	c._recalculate_ac()
	character = c
	refresh = on_change
	add_theme_constant_override("separation", 8)
	var title := Label.new()
	title.text = "Fighter Training"
	title.add_theme_color_override("font_color", UiThemeProfile.current().color("state/info"))
	add_child(title)
	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.add_theme_color_override("font_color", UiThemeProfile.current().color("state/warning"))
	add_child(status)
	var text := Label.new()
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.text = "Styles: %s\nMastery: %s (%d/%d)\nHeroic Inspiration: %s" % [", ".join(c.fighter_training.get("styles", [])), ", ".join(c.fighter_training.get("masteries", [])), c.fighter_training.get("masteries", []).size(), FighterRules.mastery_capacity(c.level), "ready" if c.heroic_inspiration else "none"]
	add_child(text)
	# These are deliberate resource preferences, visible before they spend.
	_preference("Automatically use Indomitable after a failed save", "auto_indomitable", true)
	_preference("Use Heroic Inspiration to reroll a missed weapon attack", "auto_inspiration", false)
	_preference("Use Inspiration on my next die at or below half its maximum", "inspiration_any_die", false)
	if c.fighter_training.get("boon", "") == "combat_prowess":
		_preference("Use Peerless Aim to turn a missed attack into a hit", "auto_peerless", true)
	if c.has_feature("fighter_tactical_master"):
		var mastery_row := HBoxContainer.new()
		add_child(mastery_row)
		var label := Label.new()
		label.text = "Next weapon mastery:"
		mastery_row.add_child(label)
		var property := _options(mastery_row, ["weapon", "push", "sap", "slow"])
		property.select(["weapon", "push", "sap", "slow"].find(c.fighter_training.get("tactical_master", "weapon")))
		property.item_selected.connect(func(index: int): c.fighter_training["tactical_master"] = ["weapon", "push", "sap", "slow"][index])
	if GameManager.current_state == GameManager.GameState.COMBAT:
		return
	if c.fighter_training.get("creation", false):
		var skills: Array = DataLoader.get_character_class("fighter").get("skill_choices", {}).get("from", [])
		var row := HBoxContainer.new()
		add_child(row)
		var first := _options(row, skills)
		var second := _options(row, skills)
		first.select(skills.find(c.fighter_training.get("skills", ["Athletics", "Perception"])[0]))
		second.select(skills.find(c.fighter_training.get("skills", ["Athletics", "Perception"])[1]))
		_button(row, "Choose two Fighter skills", func():
			if FighterRules.choose_skills(c, skills[first.selected], skills[second.selected]):
				refresh.call()
		)
	_build_styles()
	_build_masteries()
	_build_equipment()
	if c.level >= 19 and str(c.fighter_training.get("boon", "")).is_empty():
		var row := HBoxContainer.new()
		add_child(row)
		var ability := _options(row, AbilityScores.ABILITIES)
		_button(row, "Combat Prowess: +1 and Peerless Aim", func():
			if FighterRules.choose_boon(c, AbilityScores.ABILITIES[ability.selected]):
				refresh.call()
			else:
				status.text = "Choose an ability below 30. Your Epic Boon is still available."
		)

func _preference(label: String, key: String, fallback: bool) -> void:
	var toggle := CheckButton.new()
	toggle.text = label
	toggle.button_pressed = bool(character.fighter_training.get(key, fallback))
	toggle.toggled.connect(func(value: bool): character.fighter_training[key] = value)
	add_child(toggle)

func _build_styles() -> void:
	var styles: Array = character.fighter_training.get("styles", [])
	if character.fighter_training.get("style_swap", false):
		for i in styles.size():
			var row := HBoxContainer.new()
			add_child(row)
			var selected := _options(row, FighterRules.STYLES)
			selected.select(FighterRules.STYLES.find(styles[i]))
			_button(row, "Replace style %d" % (i + 1), func():
				if FighterRules.choose_style(character, FighterRules.STYLES[selected.selected], i):
					refresh.call()
			)
	if character.has_feature("champion_additional_fighting_style") and styles.size() < 2:
		var row := HBoxContainer.new()
		add_child(row)
		var selected := _options(row, FighterRules.STYLES)
		_button(row, "Add Champion's second style", func():
			if FighterRules.choose_style(character, FighterRules.STYLES[selected.selected]):
				refresh.call()
		)

func _build_masteries() -> void:
	var choices: Array = character.fighter_training.get("masteries", [])
	var weapons := FighterRules.available_weapons()
	if int(character.fighter_training.get("mastery_swaps", 0)) > 0:
		for i in choices.size():
			var row := HBoxContainer.new()
			add_child(row)
			var selected := _options(row, weapons)
			selected.select(weapons.find(choices[i]))
			_button(row, "Replace mastery %d" % (i + 1), func():
				if FighterRules.choose_mastery(character, weapons[selected.selected], i):
					refresh.call()
			)
	if choices.size() < FighterRules.mastery_capacity(character.level):
		var row := HBoxContainer.new()
		add_child(row)
		var selected := _options(row, weapons)
		_button(row, "Train another weapon", func():
			if FighterRules.choose_mastery(character, weapons[selected.selected]):
				refresh.call()
		)

func _build_equipment() -> void:
	var weapons: Array[String] = []
	for id in character.inventory.backpack:
		if DataLoader.get_item(id).get("type", "") == "weapon" and id not in weapons:
			weapons.append(id)
	if not weapons.is_empty():
		var row := HBoxContainer.new()
		add_child(row)
		var selected := _options(row, weapons)
		for slot in [Inventory.Slot.WEAPON, Inventory.Slot.OFFHAND]:
			_button(row, "Equip" if slot == Inventory.Slot.WEAPON else "Off hand (Light)", func():
				var id := weapons[selected.selected]
				if character.inventory.can_equip(slot, id):
					character.inventory.equip(slot, id)
					refresh.call()
			)
	for slot in [Inventory.Slot.SHIELD, Inventory.Slot.OFFHAND]:
		if character.inventory.is_slot_equipped(slot):
			_button(self, "Stow %s" % character.inventory.get_equipped(slot), func():
				character.inventory.unequip(slot)
				refresh.call()
			)

func _options(parent: Node, choices: Array) -> OptionButton:
	var menu := OptionButton.new()
	for choice in choices:
		menu.add_item(str(choice).replace("_", " ").capitalize())
	parent.add_child(menu)
	return menu

func _button(parent: Node, label: String, action: Callable) -> void:
	var button := Button.new()
	button.text = label
	button.pressed.connect(action)
	parent.add_child(button)
