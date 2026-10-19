class_name BatchLChecks
extends RefCounted

static func load_fixtures() -> void:
	for kind in ["class", "item", "spell"]:
		var filename := "classes" if kind == "class" else str(kind) + "s"
		DataLoader._load_json_file("res://data/fixtures/batch_l/%s.json" % filename, kind)

static func actor(suffix: String = "plain") -> Character:
	var c := Character.new()
	var scores := AbilityScores.new()
	scores.from_dict({"STR":14,"DEX":14,"CON":14,"INT":14,"WIS":14,"CHA":14})
	c.initialize("Carrier tester", "human", "fixture:l_class_" + suffix, scores)
	c.character_id = "carrier_%s_%d" % [suffix, c.get_instance_id()]
	if c.spell_choices_pending: ClassProgression.choose_spell_selection(c, ["fixture:l_spell_" + suffix, "fixture:l_spell_focus"])
	c.spell_slots = {"1":4}
	return c

static func select(menu: OptionButton, id: String) -> bool:
	for index in menu.item_count:
		if str(menu.get_item_metadata(index)) == id:
			menu.select(index)
			menu.item_selected.emit(index)
			return true
	return false

static func choice_control(c: Character, suffix: String, check: Callable, replace: bool = false) -> void:
	var panel := ClassTraining.new()
	var feature := "fixture:l_choice_" + suffix
	if replace: panel._build_feature_choice_replacement(c, feature, func(): pass)
	else: panel._build_feature_choice(c, feature, func(): pass)
	check.call(panel.get_child_count() == 1, "L controls: progression choice row exists " + suffix)
	if panel.get_child_count() == 1:
		var row := panel.get_child(0)
		var selector: OptionButton = row.get_child(1 if replace else 0)
		check.call(select(selector, ("l_empty_" if replace else "l_grant_") + suffix), "L controls: actual option selector offers selection " + suffix)
		var button: Button = row.get_child(2 if replace else 1)
		button.pressed.emit()
		check.call(c.feature_choices.get(feature, []) == [("l_empty_" if replace else "l_grant_") + suffix], "L controls: actual Choose/Replace commits selection " + suffix)
		var before := c.to_dict().duplicate(true)
		button.pressed.emit()
		check.call(c.to_dict() == before, "L controls: stale progression button cannot replay " + suffix)
	panel.free()

static func equipment_control(c: Character, copy_id: String, slot: Inventory.Slot, check: Callable, stow: bool = false) -> void:
	var panel := ClassTraining.new()
	panel._build_source_equipment(c, func(): pass)
	var found := false
	for child in panel.get_children():
		if stow and child is Button and child.text.contains(copy_id):
			child.pressed.emit()
			found = true
			break
		if not stow and child is HBoxContainer and str(child.get_child(0).text).contains(copy_id):
			for button in child.get_children():
				if button is Button and button.text == "Equip %s" % str(Inventory.Slot.keys()[slot]).capitalize():
					button.pressed.emit()
					found = true
					break
	check.call(found and (c.inventory.equipped_instance_id(slot) != copy_id if stow else c.inventory.equipped_instance_id(slot) == copy_id), "L controls: exact copy Equip/Stow button " + copy_id)
	panel.free()

static func run(check: Callable) -> void:
	load_fixtures()
	check.call(DataLoader.get_load_errors().is_empty(), "L: fixtures load through production DataLoader: " + str(DataLoader.get_load_errors()))
	if not DataLoader.get_load_errors().is_empty():
		DataLoader.load_all_data()
		return
	for suffix in ["plain", "changed"]:
		var c := actor(suffix)
		var amount := 2 if suffix == "plain" else 3
		var movement := 1 if suffix == "plain" else 2
		var base := c.get_ac()
		var speed := c.get_speed()
		var choice: String = "fixture:l_choice_" + str(suffix)
		check.call(ClassProgression.choose_feature_option(c, choice, "l_grant_" + suffix), "L: progression acquires declared benefits " + suffix)
		check.call(c.get_ac() == base + amount and c.get_speed() == speed + movement, "L: actual AC/movement consumers project progression " + suffix)
		for index in 2: c.inventory.add_item("fixture:l_ring_" + suffix)
		var copies := c.inventory.backpack_instances()
		check.call(c.inventory.equip_instance(Inventory.Slot.RING_1, copies[0].instance_id) and c.inventory.equip_instance(Inventory.Slot.RING_2, copies[1].instance_id), "L: equip two exact identical copies " + suffix)
		check.call(SourceBenefitRules.query(c).size() == 3 and c.get_ac() == base + amount * 3, "L: independent sources each project their authored addition " + suffix)
		var before := c.to_dict().duplicate(true)
		check.call(SourceBenefitRules.query(c) == SourceBenefitRules.query(c) and c.to_dict() == before, "L: repeated source queries mutate no state " + suffix)
		var other := actor(suffix)
		check.call(not c.inventory.equip_instance(Inventory.Slot.RING_1, "missing") and not other.inventory.equip_instance(Inventory.Slot.RING_1, copies[0].instance_id) and c.to_dict() == before, "L: stale/wrong-owner item selection refuses atomically " + suffix)
		var spell := DataLoader.get_spell("fixture:l_spell_" + suffix)
		var result := SpellResolver.resolve(c, c, spell, true)
		check.call(result.get("success", false) and c.spell_effects.size() == 1 and int(c.spell_slots["1"]) == 3, "L: production resolver pays one slot for one exact cast " + suffix + " " + JSON.stringify(result))
		if c.spell_effects.is_empty():
			DataLoader.load_all_data()
			return
		var first := str(c.spell_effects.keys()[0])
		SpellResolver.resolve(c, c, spell, true)
		check.call(c.spell_effects.size() == 2 and int(c.spell_slots["1"]) == 2 and c.get_ac() == base + amount * 5, "L: repeated independent casts keep distinct sources " + suffix)
		check.call(not SourceBenefitRules.grant(c, result.effect_cast, spell.effects[0].benefits) and c.spell_effects.size() == 2, "L: same cast acquisition replay adds no grant " + suffix)
		check.call(not SpellResolver.resolve(c, other, spell, true).get("success", true) and int(c.spell_slots["1"]) == 2, "L: invalid recipient refuses before payment " + suffix)
		var dto := c.to_dict().duplicate(true)
		check.call(SpellEffects.saved_state_error(dto).is_empty() and InventoryCopies.saved_error(dto.inventory).is_empty(), "L: ordinary saved carrier records validate " + suffix)
		var restored := Character.new()
		restored.from_dict(dto)
		check.call(SourceBenefitRules.query(restored) == SourceBenefitRules.query(c) and restored.get_ac() == c.get_ac() and restored.get_speed() == c.get_speed() and restored.spell_slots == c.spell_slots, "L: reconstruction preserves exact identities/values/costs without replay " + suffix)
		check.call(SourceBenefitRules.dismiss(c, first) and not SourceBenefitRules.dismiss(c, first) and c.spell_effects.size() == 1 and c.get_ac() == base + amount * 4, "L: exact cast dismissal/replay preserves siblings " + suffix)
		c.inventory.unequip(Inventory.Slot.RING_1)
		check.call(c.get_ac() == base + amount * 3 and SourceBenefitRules.query(c).size() == 3, "L: stow ends only that equipped copy " + suffix)
		check.call(ClassProgression.replace_feature_option(c, choice, "l_grant_" + suffix, "l_empty_" + suffix) and c.get_ac() == base + amount * 2, "L: replacement removes only progression entitlement " + suffix)
		SpellEffects.advance_time([c], int(spell.duration_seconds))
		check.call(c.spell_effects.is_empty() and c.get_ac() == base + amount and c.get_speed() == speed + movement, "L: original cast expiry leaves equipped sibling " + suffix)
		check.call(c.inventory.transfer_instance(copies[0].instance_id, other.inventory) and SourceBenefitRules.query(other).is_empty(), "L: transferred stowed copy grants nothing " + suffix)
		check.call(other.inventory.equip_instance(Inventory.Slot.RING_1, copies[0].instance_id) and SourceBenefitRules.query(other)[0].source_instance_id == copies[0].instance_id and SourceBenefitRules.query(other)[0].owner_id == other.character_id, "L: transfer retains copy identity with new owner " + suffix)
		check.call(not other.inventory.destroy_instance(copies[0].instance_id).is_empty() and SourceBenefitRules.query(other).is_empty(), "L: destruction ends exact source " + suffix)
		for mutation in ["payload", "owner", "duration", "concentration", "missing", "unknown_stat", "fractional"]:
			var bad := dto.duplicate(true)
			var record: Dictionary = bad.spell_effects.values()[0]
			match mutation:
				"payload": record.source_benefits[0].amount += 1
				"owner": record.caster_id = "other"
				"duration": record.remaining_seconds = int(spell.duration_seconds) + 1
				"concentration": record.concentration = true
				"missing": record.erase("source_benefits")
				"unknown_stat": record.source_benefits[0].stat = "unknown"
				"fractional": record.source_benefits[0].amount = 1.5
			check.call(not SpellEffects.saved_state_error(bad).is_empty(), "L: malformed saved carrier refuses " + suffix + ":" + mutation)
	var unidentified := actor()
	unidentified.character_id = ""
	var unidentified_before := unidentified.to_dict().duplicate(true)
	check.call(not SpellResolver.resolve(unidentified, unidentified, DataLoader.get_spell("fixture:l_spell_plain"), true).get("success", true) and unidentified.to_dict() == unidentified_before, "L: unidentified caster refuses before payment or acquisition")
	var floor_actor := actor()
	var extender := actor()
	extender.class_id = "sorcerer"
	extender.features.append({"id":"sorcerer_metamagic"})
	extender.sorcerer_metamagic_choices.assign(["extended_spell"])
	check.call(not SorcererRules.can_extend_spell(extender, DataLoader.get_spell("fixture:l_spell_plain")) and SorcererRules.can_extend_spell(extender, DataLoader.get_spell("barkskin")), "L: unsupported duration extension is unavailable before payment; ordinary Extended Spell remains eligible")
	ClassProgression.choose_feature_option(floor_actor, "fixture:l_choice_plain", "l_grant_plain")
	SpellEffects.grant_barkskin(floor_actor, SpellEffects.begin_cast(floor_actor, DataLoader.get_spell("barkskin")))
	check.call(floor_actor.get_ac() == 19, "L: additive AC benefit applies after existing AC floor")
	var passive := actor("passive")
	check.call(SourceBenefitRules.query(passive).size() == 1 and passive.get_ac() == passive.base_ac + 4 and passive.get_speed() == passive.speed + 2, "L: direct passive feature uses the same projection and exact entitlement")
	var passive_restored := Character.new()
	passive_restored.from_dict(passive.to_dict())
	check.call(SourceBenefitRules.query(passive_restored) == SourceBenefitRules.query(passive) and passive_restored.get_ac() == passive.get_ac(), "L: passive feature reconstruction retains entitlement without replay")
	var attuned := actor()
	attuned.inventory.add_item("fixture:l_ring_attuned")
	var copy_id := str(attuned.inventory.backpack_instances()[0].instance_id)
	attuned.inventory.equip_instance(Inventory.Slot.RING_1, copy_id)
	check.call(SourceBenefitRules.query(attuned).is_empty(), "L: equipped attunement-required copy grants nothing before attunement")
	check.call(attuned.inventory.attune_instance(copy_id, attuned.character_id).get("success", false) and SourceBenefitRules.query(attuned).size() == 1, "L: exact owned attunement enables carrier")
	check.call(attuned.inventory.unattune_instance(copy_id, attuned.character_id).get("success", false) and SourceBenefitRules.query(attuned).is_empty(), "L: removing exact attunement ends only that projection")
	var validator = DataLoader.get_script().new()
	var item := DataLoader.get_item("fixture:l_ring_plain")
	for value in [null, [], [{"stat":"AC","amount":1.5}], [{"stat":"AC","amount":true}], [{"stat":"AC","amount":0}], [{"stat":"AC","amount":11}], [{"stat":"unknown","amount":1}], [{"stat":"AC","amount":1,"extra":true}], [{"stat":"AC","amount":1},{"stat":"AC","amount":2}]]:
		var bad := item.duplicate(true)
		bad.source_benefits = value
		check.call(not validator._validate_content(bad, "item", "L malformed"), "L: loader refuses malformed item benefit " + str(value))
	var spell := DataLoader.get_spell("fixture:l_spell_plain")
	for mutation in ["target", "steps", "save", "gated", "duplicate"]:
		var bad := spell.duplicate(true)
		match mutation:
			"target": bad.target = "single"
			"steps": bad.steps = [{"type":"effect","effects":bad.effects}]
			"save": bad.save = "WIS"
			"gated": bad.effects[0].on_failed_save = true
			"duplicate": bad.effects.append(bad.effects[0].duplicate(true))
		check.call(not validator._validate_content(bad, "spell", "L unsupported host"), "L: unavailable carrier host refused at load " + mutation)
	validator.free()
	DataLoader.load_all_data()
