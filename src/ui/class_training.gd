## Shared progression UI. Choice state lives on Character, never in this panel.
class_name ClassTraining
extends VBoxContainer

static func setup_hint(c: Character) -> String:
	if c == null:
		return ""
	if c.class_id == "wizard":
		if c.wizard_spellbook.is_empty():
			return "Record your starter spells in the spellbook, then choose your cantrips and prepared spells under Class Progression."
		if c.spell_choices_pending:
			return "Choose your cantrips and prepared spells from your recorded spellbook under Class Progression."
	if c.has_feature("druid_wild_shape") and DruidRules.known_form_ids(c).is_empty():
		return "Learn an eligible Beast form under Class Progression before using Wild Shape."
	return ""

func configure(c: Character, refresh: Callable) -> void:
	add_theme_constant_override("separation", 8)
	var title := Label.new()
	title.text = "Class Progression"
	add_child(title)
	var guidance := setup_hint(c)
	if not guidance.is_empty():
		var note := Label.new()
		note.text = guidance + (" Set this up outside combat." if GameManager.current_state == GameManager.GameState.COMBAT else "")
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		add_child(note)
	if c.has_feature("barbarian_relentless_rage"):
		var relentless := CheckBox.new()
		relentless.text = "Use Relentless Rage when dropped to 0 HP"
		relentless.tooltip_text = "Choose before taking damage. Each attempt raises the next save DC by 5 until a rest. Turning this off skips the attempt and leaves its DC unchanged."
		relentless.button_pressed = c.barbarian_relentless_rage_enabled
		relentless.toggled.connect(func(enabled: bool): c.barbarian_relentless_rage_enabled = enabled)
		add_child(relentless)
	var subclass := DataLoader.get_subclass(c.subclass_id)
	if not subclass.is_empty():
		var label := Label.new()
		label.text = "Subclass: %s" % subclass["name"]
		add_child(label)
	if GameManager.current_state == GameManager.GameState.COMBAT:
		return
	_build_wild_shape_form_choices(c, refresh)
	var available := DataLoader.get_subclasses_for_class(c.class_id)
	if c.subclass_id.is_empty() and c.level >= int(DataLoader.get_character_class(c.class_id).get("subclass_level", 3)) and not available.is_empty():
		var row := HBoxContainer.new()
		add_child(row)
		var options := OptionButton.new()
		for choice in available:
			options.add_item(str(choice["name"]))
		row.add_child(options)
		var button := Button.new()
		button.text = "Choose subclass"
		button.pressed.connect(func():
			if ClassProgression.choose_subclass(c, str(available[options.selected]["id"])):
				refresh.call()
		)
		row.add_child(button)
	if c.class_id != "fighter" and c.has_feature_effect("weapon_mastery"):
		_build_weapon_mastery(c, refresh)
	for feature_id in ClassProgression.pending_feature_choices(c):
		_build_feature_choice(c, feature_id, refresh)
	for feature_id in ClassProgression.pending_skill_choices(c):
		_build_skill_choice(c, feature_id, refresh)
	for feature_id in ClassProgression.pending_skill_expertise_choices(c):
		_build_skill_expertise_choice(c, feature_id, refresh)
	for feature_id in ClassProgression.pending_epic_boon_choices(c):
		_build_epic_boon_choice(c, feature_id, refresh)
	if c.class_id == "wizard":
		_build_wizard_spellbook(c, refresh)
		_build_wizard_mastery_choices(c, refresh)
		_build_wizard_signature_choices(c, refresh)
		_build_wizard_spell_copy(c, refresh)
		_build_wizard_rituals(c, refresh)
	if c.class_id == "warlock":
		_build_warlock_invocations(c, refresh)
		_build_warlock_arcanum(c, refresh)
	if c.class_id == "sorcerer" and c.has_feature("sorcerer_font_of_magic"):
		_build_sorcerer_font_of_magic(c, refresh)
	if c.class_id == "sorcerer" and (c.sorcerer_metamagic_pending > 0 or c.sorcerer_metamagic_replacement_available):
		_build_sorcerer_metamagic(c, refresh)
	if not c.get_spellcasting_feature_id().is_empty():
		_build_spell_selection(c, refresh)
	var pending := ClassProgression.pending_improvements(c)
	if pending.is_empty():
		return
	var status := Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(status)
	var row := HBoxContainer.new()
	add_child(row)
	var first := OptionButton.new()
	var second := OptionButton.new()
	for ability in AbilityScores.ABILITIES:
		first.add_item(ability)
		second.add_item(ability)
	first.tooltip_text = "Same ability twice gives +2. Different abilities give +1 each. Maximum 20."
	row.add_child(first)
	row.add_child(second)
	var button := Button.new()
	button.text = "Apply +1 each (%d pending)" % pending.size()
	button.pressed.connect(func():
		if ClassProgression.improve_scores(c, AbilityScores.ABILITIES[first.selected], AbilityScores.ABILITIES[second.selected]):
			refresh.call()
		else:
			status.text = "Choose abilities that will stay at 20 or below. Your improvement is still available."
	)
	row.add_child(button)


func _build_wild_shape_form_choices(c: Character, refresh: Callable) -> void:
	if c.class_id != "druid" or c.level < 2:
		return
	var known := DruidRules.known_form_ids(c)
	var capacity := DruidRules.known_form_capacity(c)
	var heading := Label.new()
	heading.text = "Wild Shape Forms: %d/%d known" % [known.size(), capacity]
	add_child(heading)
	var eligible := DruidRules.eligible_form_options(c)
	if DruidRules.pending_known_form_count(c) > 0:
		var learn_row := HBoxContainer.new()
		add_child(learn_row)
		var form_selector := OptionButton.new()
		for form in eligible:
			var id := str(form.get("id", ""))
			if id in known:
				continue
			form_selector.add_item(str(form.get("name", id)))
			form_selector.set_item_metadata(form_selector.item_count - 1, id)
		learn_row.add_child(form_selector)
		var learn_button := Button.new()
		learn_button.text = "Learn Beast form (%d remaining)" % DruidRules.pending_known_form_count(c)
		learn_button.pressed.connect(func():
			if form_selector.selected >= 0 and DruidRules.learn_form(c, str(form_selector.get_item_metadata(form_selector.selected))):
				refresh.call()
		)
		learn_row.add_child(learn_button)
	if int(c.feature_uses.get(DruidRules.FORM_REPLACEMENT_RESOURCE_ID, 0)) <= 0 or known.is_empty():
		return
	var replace_row := HBoxContainer.new()
	add_child(replace_row)
	var old_selector := OptionButton.new()
	for id in known:
		var form := DruidRules.form_data(id)
		old_selector.add_item(str(form.get("name", id)))
		old_selector.set_item_metadata(old_selector.item_count - 1, id)
	replace_row.add_child(old_selector)
	var new_selector := OptionButton.new()
	for form in eligible:
		var id := str(form.get("id", ""))
		if id in known:
			continue
		new_selector.add_item(str(form.get("name", id)))
		new_selector.set_item_metadata(new_selector.item_count - 1, id)
	replace_row.add_child(new_selector)
	var replace_button := Button.new()
	replace_button.text = "Replace one form after Long Rest"
	replace_button.pressed.connect(func():
		if old_selector.selected < 0 or new_selector.selected < 0:
			return
		var old_id := str(old_selector.get_item_metadata(old_selector.selected))
		var new_id := str(new_selector.get_item_metadata(new_selector.selected))
		if DruidRules.replace_known_form(c, old_id, new_id):
			refresh.call()
	)
	replace_row.add_child(replace_button)


func _build_skill_choice(c: Character, feature_id: String, refresh: Callable) -> void:
	var feature := c.get_feature(feature_id)
	var effect: Dictionary = {}
	for candidate in feature.get("effects", []):
		if candidate.get("type", "") == "skill_proficiency_choice":
			effect = candidate
	var options: Array = effect.get("options", [])
	var count := int(effect.get("count", 1))
	var title := Label.new()
	title.text = "%s: choose %d skill%s" % [feature.get("name", "Skill Proficiency"), count, "s" if count != 1 else ""]
	add_child(title)
	var row := HBoxContainer.new()
	add_child(row)
	var selectors: Array[OptionButton] = []	
	for index in count:
		var selected := OptionButton.new()
		for skill in options:
			if skill not in c.skill_proficiencies:
				selected.add_item(str(skill))
		row.add_child(selected)
		selectors.append(selected)
	var button := Button.new()
	button.text = "Choose skill"
	button.pressed.connect(func():
		var skills: Array[String] = []
		for selected in selectors:
			if selected.selected < 0:
				return
			skills.append(selected.get_item_text(selected.selected))
		if ClassProgression.choose_skill_proficiency(c, feature_id, skills):
			refresh.call()
	)
	row.add_child(button)


func _build_skill_expertise_choice(c: Character, feature_id: String, refresh: Callable) -> void:
	var feature := c.get_feature(feature_id)
	var count := 2
	var allowed_skills: Array = []
	for effect in feature.get("effects", []):
		if effect.get("type", "") == "skill_expertise_choice":
			count = int(effect.get("count", 2))
			allowed_skills = effect.get("allowed_skills", [])
	var title := Label.new()
	title.text = "%s: choose %d proficient skill%s" % [feature.get("name", "Expertise"), count, "s" if count != 1 else ""]
	add_child(title)
	var already_expert: Array = []
	for choice_id in ClassProgression.skill_expertise_choice_ids(c):
		already_expert.append_array(c.feature_choices.get(choice_id, []))
	var available: Array[String] = []
	for skill in c.skill_proficiencies:
		if skill not in already_expert and (allowed_skills.is_empty() or skill in allowed_skills):
			available.append(skill)
	var row := HBoxContainer.new()
	add_child(row)
	var selectors: Array[OptionButton] = []
	for index in count:
		var selected := OptionButton.new()
		for skill in available:
			selected.add_item(skill)
		row.add_child(selected)
		selectors.append(selected)
	var button := Button.new()
	button.text = "Choose expertise"
	button.pressed.connect(func():
		var skills: Array[String] = []
		for selected in selectors:
			if selected.selected < 0:
				return
			skills.append(selected.get_item_text(selected.selected))
		if ClassProgression.choose_skill_expertise(c, feature_id, skills):
			refresh.call()
	)
	row.add_child(button)


func _build_epic_boon_choice(c: Character, feature_id: String, refresh: Callable) -> void:
	var feature := c.get_feature(feature_id)
	var options: Array = []
	var abilities_by_option: Dictionary = {}
	for effect in feature.get("effects", []):
		if effect.get("type", "") == "epic_boon_choice":
			options = effect.get("options", [])
			abilities_by_option = effect.get("ability_scores_by_option", {})
	var row := HBoxContainer.new()
	add_child(row)
	var boon := OptionButton.new()
	var labels := {"combat_prowess": "Boon of Combat Prowess", "irresistible_offense": "Boon of Irresistible Offense", "spell_recall": "Boon of Spell Recall"}
	for option in options:
		boon.add_item(str(labels.get(option, option)))
		boon.set_item_metadata(boon.item_count - 1, option)
	row.add_child(boon)
	var ability := OptionButton.new()
	var add_ability_options := func(selected_boon: String) -> void:
		ability.clear()
		var required: Array = abilities_by_option.get(selected_boon, [])
		for score in AbilityScores.ABILITIES:
			if c.ability_scores.get_score(score) < 30 and (required.is_empty() or score in required):
				ability.add_item(score)
	add_ability_options.call(str(boon.get_item_metadata(boon.selected)) if boon.selected >= 0 else "")
	boon.item_selected.connect(func(index: int): add_ability_options.call(str(boon.get_item_metadata(index))))
	row.add_child(ability)
	var button := Button.new()
	button.text = "%s: choose a boon" % feature.get("name", "Epic Boon")
	button.pressed.connect(func():
		if boon.selected < 0 or ability.selected < 0:
			return
		if ClassProgression.choose_epic_boon(c, feature_id, str(boon.get_item_metadata(boon.selected)), ability.get_item_text(ability.selected)):
			refresh.call()
	)
	row.add_child(button)


func _build_weapon_mastery(c: Character, refresh: Callable) -> void:
	var choices: Array = c.weapon_masteries
	var weapons := FighterRules.eligible_mastery_weapons(c)
	var capacity := c.get_weapon_mastery_capacity()
	var summary := Label.new()
	summary.text = "Weapon Mastery: %d/%d selected%s" % [choices.size(), capacity, " — " + ", ".join(choices) if not choices.is_empty() else ""]
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(summary)
	var swap_count := int(c.feature_uses.get("weapon_mastery_swaps", 0))
	if swap_count > 0:
		for index in choices.size():
			var row := HBoxContainer.new()
			add_child(row)
			var selected := OptionButton.new()
			for weapon_id in weapons:
				selected.add_item(str(DataLoader.get_item(weapon_id).get("name", weapon_id)))
				selected.set_item_metadata(selected.item_count - 1, weapon_id)
			selected.select(maxi(0, weapons.find(str(choices[index]))))
			row.add_child(selected)
			var button := Button.new()
			button.text = "Replace mastery"
			button.pressed.connect(func():
				var weapon_id := str(selected.get_item_metadata(selected.selected))
				if FighterRules.choose_mastery(c, weapon_id, index):
					refresh.call()
			)
			row.add_child(button)
	if choices.size() < capacity:
		var row := HBoxContainer.new()
		add_child(row)
		var selected := OptionButton.new()
		for weapon_id in weapons:
			if weapon_id in choices:
				continue
			selected.add_item(str(DataLoader.get_item(weapon_id).get("name", weapon_id)))
			selected.set_item_metadata(selected.item_count - 1, weapon_id)
		row.add_child(selected)
		var button := Button.new()
		button.text = "Train a weapon"
		button.pressed.connect(func():
			if selected.selected >= 0 and FighterRules.choose_mastery(c, str(selected.get_item_metadata(selected.selected))):
				refresh.call()
		)
		row.add_child(button)


func _build_spell_selection(c: Character, refresh: Callable) -> void:
	var feature_id := c.get_spellcasting_feature_id()
	var old_choices: Array = c.feature_choices.get(feature_id, [])
	var cantrip_options := c.get_spell_option_ids(true)
	var spell_options := c.get_spell_option_ids(false)
	var cantrip_count := c.get_spellcasting_capacity("cantrips")
	var prepared_count := c.get_spellcasting_capacity("prepared_spells")
	var heading := Label.new()
	heading.text = "Spells: %d/%d cantrips, %d/%d prepared" % [
		old_choices.filter(func(id): return int(DataLoader.get_spell(str(id)).get("level", -1)) == 0).size(),
		cantrip_count,
		old_choices.size() - old_choices.filter(func(id): return int(DataLoader.get_spell(str(id)).get("level", -1)) == 0).size(),
		prepared_count,
	]
	add_child(heading)
	if not c.spell_choices_pending:
		return
	var selected_ids: Array[String] = []
	var selectors: Array[OptionButton] = []
	for slot_kind in ["Cantrip", "Prepared"]:
		var count := cantrip_count if slot_kind == "Cantrip" else prepared_count
		var options: Array[String] = cantrip_options if slot_kind == "Cantrip" else spell_options
		if options.size() < count:
			var note := Label.new()
			note.text = "%d %s choice(s) remain pending until more eligible spells are available." % [count - options.size(), slot_kind.to_lower()]
			note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			add_child(note)
		for index in mini(count, options.size()):
			var row := HBoxContainer.new()
			add_child(row)
			var label := Label.new()
			label.text = "%s %d" % [slot_kind, index + 1]
			label.custom_minimum_size.x = 92
			row.add_child(label)
			var selector := OptionButton.new()
			selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			for spell_id in options:
				var spell: Dictionary = DataLoader.get_spell(spell_id)
				var available := SpellSupport.is_available(spell)
				selector.add_item(str(spell.get("name", spell_id)) + ("" if available else " [Unavailable]"))
				selector.set_item_metadata(selector.item_count - 1, spell_id)
				selector.set_item_disabled(selector.item_count - 1, not available)
				if not available:
					selector.get_popup().set_item_tooltip(selector.item_count - 1, SpellSupport.availability(spell)["reason"])
			row.add_child(selector)
			var previous_spell := ""
			for spell_id in old_choices:
				var spell: Dictionary = DataLoader.get_spell(str(spell_id))
				var is_cantrip := int(spell.get("level", -1)) == 0
				if is_cantrip != (slot_kind == "Cantrip") or spell_id in selected_ids or spell_id not in options:
					continue
				previous_spell = str(spell_id)
				break
			if previous_spell.is_empty():
				for spell_id in options:
					if spell_id not in selected_ids and SpellSupport.is_available(DataLoader.get_spell(spell_id)):
						previous_spell = spell_id
						break
			if not previous_spell.is_empty():
				selector.select(options.find(previous_spell))
				selected_ids.append(previous_spell)
			selectors.append(selector)
	var status := Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(status)
	var button := Button.new()
	button.text = "Memorize one spell after Short Rest" if c.class_id == "wizard" and c.wizard_memorize_spell_pending else ("Prepare spells after Long Rest" if (c.class_id == "wizard" and c.wizard_preparation_free_change) or (c.class_id == "cleric" and c.cleric_preparation_free_change) else "Choose spells")
	button.pressed.connect(func():
		var choices: Array[String] = []
		for selector in selectors:
			if selector.selected < 0:
				status.text = "Select a spell in every row."
				return
			choices.append(str(selector.get_item_metadata(selector.selected)))
		if ClassProgression.choose_spell_selection(c, choices):
			refresh.call()
		else:
			status.text = "The selected spell list is invalid or changes too many existing spells."
	)
	add_child(button)


func _build_wizard_spellbook(c: Character, refresh: Callable) -> void:
	var known := Label.new()
	var names: Array[String] = []
	for spell_id in c.wizard_spellbook:
		names.append(str(DataLoader.get_spell(spell_id).get("name", spell_id)))
	known.text = "Spellbook: %d recorded%s" % [c.wizard_spellbook.size(), " — " + ", ".join(names) if not names.is_empty() else ""]
	known.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(known)
	if c.wizard_spellbook_pending <= 0:
		return
	var eligible: Array[String] = []
	for spell in DataLoader.get_castable_spell_list_options(c.get_spell_list_ids()):
		var id := str(spell.get("id", ""))
		var spell_level := int(spell.get("level", -1))
		if spell_level > 0 and spell_level <= c.get_max_spell_slot_level() and id not in c.wizard_spellbook:
			eligible.append(id)
	var selectors: Array[OptionButton] = []
	if eligible.size() < c.wizard_spellbook_pending:
		var note := Label.new()
		note.text = "%d spellbook choices remain pending until more eligible Wizard spells are available. You can prepare recorded spells now." % (c.wizard_spellbook_pending - eligible.size())
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		add_child(note)
	for index in mini(c.wizard_spellbook_pending, eligible.size()):
		var row := HBoxContainer.new()
		add_child(row)
		var label := Label.new()
		label.text = "Learn Wizard spell %d" % (index + 1)
		label.custom_minimum_size.x = 150
		row.add_child(label)
		var selector := OptionButton.new()
		selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		for id in eligible:
			selector.add_item(str(DataLoader.get_spell(id).get("name", id)))
			selector.set_item_metadata(selector.item_count - 1, id)
		selector.select(index)
		row.add_child(selector)
		selectors.append(selector)
	var status := Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(status)
	var learn := Button.new()
	learn.text = "Record %d spell%s in spellbook" % [selectors.size(), "s" if selectors.size() != 1 else ""]
	learn.disabled = selectors.is_empty()
	learn.pressed.connect(func():
		var choices: Array[String] = []
		for selector in selectors:
			if selector.selected < 0:
				status.text = "Select a spell in each row."
				return
			choices.append(str(selector.get_item_metadata(selector.selected)))
		if ClassProgression.choose_wizard_spellbook(c, choices):
			refresh.call()
		else:
			status.text = "Choose distinct Wizard spells no higher than your current spell level."
	)
	add_child(learn)


func _build_wizard_mastery_choices(c: Character, refresh: Callable) -> void:
	if not c.has_feature("wizard_spell_mastery"):
		return
	for spell_level in [1, 2]:
		var selected_spell_level: int = int(spell_level)
		var key := str(spell_level)
		var replacing := c.wizard_spell_mastery.has(key)
		if replacing and not c.wizard_mastery_replacement_available:
			continue
		var options := ClassProgression.wizard_spellbook_feature_options(c, spell_level)
		if replacing:
			options.erase(str(c.wizard_spell_mastery[key]))
		if options.is_empty():
			continue
		var row := HBoxContainer.new()
		add_child(row)
		var selector := OptionButton.new()
		for spell_id in options:
			selector.add_item(str(DataLoader.get_spell(spell_id).get("name", spell_id)))
			selector.set_item_metadata(selector.item_count - 1, spell_id)
		row.add_child(selector)
		var status := Label.new()
		row.add_child(status)
		var button := Button.new()
		button.text = ("Replace level %d Spell Mastery after Long Rest" if replacing else "Choose level %d Spell Mastery") % selected_spell_level
		button.pressed.connect(func():
			if selector.selected >= 0 and ClassProgression.choose_wizard_spell_mastery(c, selected_spell_level, str(selector.get_item_metadata(selector.selected))):
				refresh.call()
			else:
				status.text = "Choose an eligible spell from the spellbook."
		)
		row.add_child(button)


func _build_wizard_signature_choices(c: Character, refresh: Callable) -> void:
	if not c.has_feature("wizard_signature_spells") or not c.wizard_signature_spells.is_empty():
		return
	var options := ClassProgression.wizard_spellbook_feature_options(c, 3, false)
	if options.size() < 2:
		return
	var selectors: Array[OptionButton] = []
	for index in 2:
		var row := HBoxContainer.new()
		add_child(row)
		var label := Label.new()
		label.text = "Signature Spell %d" % (index + 1)
		row.add_child(label)
		var selector := OptionButton.new()
		for spell_id in options:
			selector.add_item(str(DataLoader.get_spell(spell_id).get("name", spell_id)))
			selector.set_item_metadata(selector.item_count - 1, spell_id)
		row.add_child(selector)
		selectors.append(selector)
	var status := Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(status)
	var button := Button.new()
	button.text = "Choose Signature Spells"
	button.pressed.connect(func():
		if selectors.any(func(selector): return selector.selected < 0):
			status.text = "Choose two level 3 action spells from your spellbook."
			return
		var selected: Array[String] = []
		for selector in selectors:
			selected.append(str(selector.get_item_metadata(selector.selected)))
		if ClassProgression.choose_wizard_signature_spells(c, selected):
			refresh.call()
		else:
			status.text = "Choose two distinct level 3 action spells from your spellbook."
	)
	add_child(button)


func _build_wizard_spell_copy(c: Character, refresh: Callable) -> void:
	if c.class_id != "wizard" or GameManager.current_state == GameManager.GameState.COMBAT:
		return
	var sources: Array[Character] = []
	for member in PartyManager.get_active_party_members():
		var source: Character = member.get("character")
		if source != null and source != c and source.class_id == "wizard" and source.inventory.has_item("spellbook"):
			sources.append(source)
	if sources.is_empty():
		return
	var row := HBoxContainer.new()
	add_child(row)
	var source_selector := OptionButton.new()
	for source in sources:
		source_selector.add_item(source.character_name)
		source_selector.set_item_metadata(source_selector.item_count - 1, source.character_id)
	row.add_child(source_selector)
	var spell_selector := OptionButton.new()
	spell_selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spell_selector)
	var fill_spells := func(source_index: int) -> void:
		spell_selector.clear()
		if source_index < 0 or source_index >= sources.size():
			return
		var source: Character = sources[source_index]
		for id in source.wizard_spellbook:
			var spell := DataLoader.get_spell(id)
			if id in c.wizard_spellbook or int(spell.get("level", 0)) < 1 or int(spell.get("level", 0)) > c.get_max_spell_slot_level() or id not in c.get_spell_list_ids():
				continue
			spell_selector.add_item("%s (%d gp, %d hours)" % [spell.get("name", id), 50 * int(spell.get("level", 0)), 2 * int(spell.get("level", 0))])
			spell_selector.set_item_metadata(spell_selector.item_count - 1, id)
	source_selector.item_selected.connect(fill_spells)
	fill_spells.call(source_selector.selected)
	var status := Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(status)
	var copy := Button.new()
	copy.text = "Copy spell from party spellbook"
	copy.pressed.connect(func():
		if source_selector.selected < 0 or spell_selector.selected < 0:
			status.text = "Choose a source Wizard and a spell you do not know."
			return
		var source: Character = sources[source_selector.selected]
		var result := ClassProgression.copy_wizard_spell(c, source, str(spell_selector.get_item_metadata(spell_selector.selected)))
		status.text = str(result.get("message", "Spell copy failed."))
		if result.get("success", false):
			refresh.call()
	)
	add_child(copy)


func _build_wizard_rituals(c: Character, refresh: Callable) -> void:
	if not c.has_feature("wizard_ritual_adept"):
		return
	var rituals: Array[String] = []
	for spell_id in c.wizard_spellbook:
		var spell := DataLoader.get_spell(spell_id)
		if bool(spell.get("ritual", false)) and int(spell.get("level", 0)) <= c.get_max_spell_slot_level():
			rituals.append(spell_id)
	if rituals.is_empty():
		return
	var title := Label.new()
	title.text = "Rituals in your spellbook (10 extra minutes; no spell slot)"
	add_child(title)
	for spell_id in rituals:
		var row := HBoxContainer.new()
		add_child(row)
		var name := Label.new()
		name.text = str(DataLoader.get_spell(spell_id).get("name", spell_id))
		name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name)
		var cast := Button.new()
		cast.text = "Cast ritual"
		cast.pressed.connect(func():
			var result := ClassProgression.cast_wizard_ritual(c, spell_id)
			name.tooltip_text = str(result.get("message", ""))
			if bool(result.get("success", false)):
				refresh.call()
		)
		row.add_child(cast)


func _build_sorcerer_font_of_magic(c: Character, refresh: Callable) -> void:
	var points := Label.new()
	points.text = "Sorcery Points: %d/%d" % [c.get_sorcery_points(), c.get_max_sorcery_points()]
	add_child(points)
	var conversion_row := HBoxContainer.new()
	add_child(conversion_row)
	var slot_selector := OptionButton.new()
	for key in c.spell_slots:
		if int(c.spell_slots[key]) > 0:
			slot_selector.add_item("Level %s (%d slots)" % [key, int(c.spell_slots[key])])
			slot_selector.set_item_metadata(slot_selector.item_count - 1, int(key))
	conversion_row.add_child(slot_selector)
	var convert := Button.new()
	convert.text = "Convert slot to points"
	convert.disabled = slot_selector.item_count == 0 or c.get_sorcery_points() >= c.get_max_sorcery_points()
	convert.pressed.connect(func():
		if slot_selector.selected >= 0:
			var result := SorcererRules.convert_slot_to_points(c, int(slot_selector.get_item_metadata(slot_selector.selected)))
			if result.get("success", false):
				refresh.call()
	)
	conversion_row.add_child(convert)
	var creation_row := HBoxContainer.new()
	add_child(creation_row)
	var create_selector := OptionButton.new()
	for slot_level in SorcererRules.SLOT_POINT_COSTS:
		if c.level >= int(SorcererRules.SLOT_MINIMUM_LEVELS[slot_level]) and slot_level <= c.get_max_spell_slot_level():
			create_selector.add_item("Level %d slot (%d points)" % [slot_level, int(SorcererRules.SLOT_POINT_COSTS[slot_level])])
			create_selector.set_item_metadata(create_selector.item_count - 1, slot_level)
	creation_row.add_child(create_selector)
	var create := Button.new()
	create.text = "Create spell slot"
	create.disabled = create_selector.item_count == 0
	create.tooltip_text = "Creating a slot takes a Bonus Action and it disappears after a Long Rest."
	create.pressed.connect(func():
		if create_selector.selected >= 0:
			var result := SorcererRules.create_spell_slot(c, int(create_selector.get_item_metadata(create_selector.selected)))
			if result.get("success", false):
				refresh.call()
	)
	creation_row.add_child(create)


func _build_sorcerer_metamagic(c: Character, refresh: Callable) -> void:
	var options := SorcererRules.metamagic_options()
	if c.sorcerer_metamagic_pending > 0:
		var title := Label.new()
		title.text = "Choose %d Metamagic options" % c.sorcerer_metamagic_pending
		add_child(title)
		var selectors: Array[OptionButton] = []
		for index in c.sorcerer_metamagic_pending:
			var row := HBoxContainer.new()
			add_child(row)
			var selector := OptionButton.new()
			for option_id in options:
				if option_id in c.sorcerer_metamagic_choices:
					continue
				selector.add_item(options[option_id])
				selector.set_item_metadata(selector.item_count - 1, option_id)
			row.add_child(selector)
			selectors.append(selector)
		var status := Label.new()
		add_child(status)
		var choose := Button.new()
		choose.text = "Save Metamagic choices"
		choose.pressed.connect(func():
			var chosen: Array[String] = []
			for selector in selectors:
				if selector.selected < 0:
					status.text = "Choose a different Metamagic option in every row."
					return
				chosen.append(str(selector.get_item_metadata(selector.selected)))
			if ClassProgression.choose_sorcerer_metamagic(c, chosen):
				refresh.call()
			else:
				status.text = "Those Metamagic options are not available."
		)
		add_child(choose)
	if c.sorcerer_metamagic_replacement_available and not c.sorcerer_metamagic_choices.is_empty():
		var replace_row := HBoxContainer.new()
		add_child(replace_row)
		var old_choice := OptionButton.new()
		for option_id in c.sorcerer_metamagic_choices:
			old_choice.add_item(str(options.get(option_id, option_id)))
			old_choice.set_item_metadata(old_choice.item_count - 1, option_id)
		replace_row.add_child(old_choice)
		var new_choice := OptionButton.new()
		for option_id in options:
			if option_id in c.sorcerer_metamagic_choices:
				continue
			new_choice.add_item(str(options[option_id]))
			new_choice.set_item_metadata(new_choice.item_count - 1, option_id)
		replace_row.add_child(new_choice)
		var replace := Button.new()
		replace.text = "Replace one Metamagic option"
		replace.pressed.connect(func():
			if old_choice.selected >= 0 and new_choice.selected >= 0 and ClassProgression.replace_sorcerer_metamagic(c, str(old_choice.get_item_metadata(old_choice.selected)), str(new_choice.get_item_metadata(new_choice.selected))):
				refresh.call()
		)
		replace_row.add_child(replace)


func _build_warlock_invocations(c: Character, refresh: Callable) -> void:
	var capacity := WarlockRules.invocation_capacity(c.level)
	var title := Label.new()
	title.text = "Eldritch Invocations: %d/%d selected" % [c.warlock_invocations.size(), capacity]
	add_child(title)
	if capacity <= 0:
		return
	var available := WarlockRules.available_invocation_selections(c)
	var selectors: Array[OptionButton] = []
	for index in capacity:
		var row := HBoxContainer.new()
		add_child(row)
		var label := Label.new()
		label.text = "Invocation %d" % (index + 1)
		label.custom_minimum_size.x = 100
		row.add_child(label)
		var selector := OptionButton.new()
		selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		for selection_id in available:
			var option_id := selection_id.split(":")[0]
			var display := selection_id
			for option in WarlockRules.invocation_options(c):
				if str(option.get("id", "")) == option_id:
					display = "%s — %s" % [option.get("name", option_id), DataLoader.get_spell(selection_id.split(":")[1]).get("name", "") if selection_id.contains(":") else ""]
					if not selection_id.contains(":"):
						display = str(option.get("name", option_id))
					break
			selector.add_item(display)
			selector.set_item_metadata(selector.item_count - 1, selection_id)
		row.add_child(selector)
		selectors.append(selector)
		if index < c.warlock_invocations.size():
			var old_choice := c.warlock_invocations[index]
			for item_index in selector.item_count:
				if str(selector.get_item_metadata(item_index)) == old_choice:
					selector.select(item_index)
					break
	var status := Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(status)
	if c.warlock_invocations.size() != capacity:
		status.text = "Choose the new invocations. On a Warlock level-up, you may replace one prior choice."
	else:
		status.text = "You may replace one invocation after gaining a Warlock level."
	var choose := Button.new()
	choose.text = "Save invocation choices"
	choose.disabled = available.is_empty()
	choose.pressed.connect(func():
		var choices: Array[String] = []
		for selector in selectors:
			if selector.selected < 0:
				status.text = "Select an invocation in every row."
				return
			choices.append(str(selector.get_item_metadata(selector.selected)))
		if WarlockRules.choose_invocations(c, choices):
			refresh.call()
		else:
			status.text = "Check the level/cantrip prerequisites, avoid duplicates, and replace no more than one old option."
	)
	add_child(choose)


func _build_warlock_arcanum(c: Character, refresh: Callable) -> void:
	if c.warlock_arcanum_pending_levels.is_empty() and not c.warlock_arcanum_replacement_available:
		return
	var arcanum_levels := c.warlock_arcanum_pending_levels.duplicate()
	if c.warlock_arcanum_replacement_available:
		for key in c.warlock_mystic_arcanum:
			if int(key) not in arcanum_levels:
				arcanum_levels.append(int(key))
	arcanum_levels.sort()
	for spell_level in arcanum_levels:
		var row := HBoxContainer.new()
		add_child(row)
		var label := Label.new()
		label.text = "Mystic Arcanum level %d%s" % [spell_level, " (replace)" if c.warlock_mystic_arcanum.has(str(spell_level)) else ""]
		label.custom_minimum_size.x = 170
		row.add_child(label)
		var options := WarlockRules.arcanum_spells(c, spell_level)
		var selector := OptionButton.new()
		selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		for spell_id in options:
			selector.add_item(str(DataLoader.get_spell(spell_id).get("name", spell_id)))
			selector.set_item_metadata(selector.item_count - 1, spell_id)
		row.add_child(selector)
		var choose := Button.new()
		choose.text = "Choose / replace"
		choose.disabled = options.is_empty()
		choose.tooltip_text = "Choose a Warlock spell of this level. It has a separate once-per-Long-Rest cast."
		choose.pressed.connect(func():
			if selector.selected >= 0 and WarlockRules.choose_mystic_arcanum(c, spell_level, str(selector.get_item_metadata(selector.selected))):
				refresh.call()
		)
		row.add_child(choose)
		if options.is_empty():
			var unavailable := Label.new()
			unavailable.text = "No supported catalog spell exists at this Arcanum level."
			add_child(unavailable)


func _build_feature_choice(c: Character, feature_id: String, refresh: Callable) -> void:
	var feature := c.get_feature(feature_id)
	var effect := ClassProgression.feature_choice_effect(c, feature_id)
	var options: Array = effect.get("options", [])
	var row := HBoxContainer.new()
	add_child(row)
	var selected := OptionButton.new()
	for option in options:
		selected.add_item(str(option.get("name", option.get("id", "Option"))))
		selected.set_item_metadata(selected.item_count - 1, str(option.get("id", "")))
	row.add_child(selected)
	var button := Button.new()
	button.text = "%s: choose an option" % feature.get("name", "Class Feature")
	button.pressed.connect(func():
		if selected.selected >= 0 and ClassProgression.choose_feature_option(c, feature_id, str(selected.get_item_metadata(selected.selected))):
			refresh.call()
	)
	row.add_child(button)
