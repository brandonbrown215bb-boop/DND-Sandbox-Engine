class_name Batch018Checks
extends RefCounted

static func load_fixtures() -> void:
	for suffix in ["plain", "changed", "secondary_plain", "secondary_changed"]:
		DataLoader._load_json_file("res://data/fixtures/batch_018/" + suffix + ".json", "class")

static func actor(suffix: String = "plain") -> Character:
	var c := Character.new()
	c.character_id = "018:" + suffix
	var scores := AbilityScores.new()
	scores.from_dict({"STR":12,"DEX":12,"CON":12,"INT":12,"WIS":12,"CHA":12})
	c.initialize("018 " + suffix,"human","fixture:018_" + suffix,scores)
	return c

static func run(check: Callable) -> void:
	load_fixtures()
	var record := DataLoader.get_character_class("fixture:018_plain").duplicate(true)
	check.call(not record.is_empty() and PermanentProgressionRules.definition_error(record).is_empty(), "018 loaded neutral permanent progression")
	var validator: Node = DataLoader.get_script().new()
	for mutation in ["shape","fraction","basis","duplicate","ability","effect","quantity","native","native_feature","unknown_field","skill","save"]:
		var bad := record.duplicate(true)
		match mutation:
			"shape": bad.permanent_progression.starting = {}
			"fraction": bad.permanent_progression.levels[0].at = 1.5
			"basis": bad.permanent_progression.levels[0].basis = "other"
			"duplicate": bad.permanent_progression.levels.append(bad.permanent_progression.levels[0].duplicate(true))
			"ability": bad.permanent_progression.levels[0].grants[0].ability = "NOPE"
			"effect": bad.permanent_progression.starting[0].type = "run_script"
			"quantity": bad.permanent_progression.starting[1].quantity = -1
			"native": bad.starting_equipment = ["dagger"]
			"native_feature": bad.features_by_level["1"][0].effects[0].type = "spellcasting"
			"unknown_field": bad.permanent_progression.starting[0].mystery = ["Stealth"]
			"skill": bad.permanent_progression.starting[0].expertise = ["Not a skill"]
			"save": bad.permanent_progression.starting[0].saving_throw_proficiencies = ["NOPE"]
		check.call(not validator._validate_content(bad,"class","018-invalid"), "018 malformed definition refuses: " + mutation)
	validator.free()
	for field in ["expertise", "tool_proficiencies", "saving_throw_proficiencies", "mystery"]:
		var bad := record.duplicate(true)
		bad.features_by_level["1"][0].effects[0].options[0].effects[0][field] = ["Stealth"]
		check.call(not PermanentProgressionRules.definition_error(bad).is_empty(), "018 choice refuses unsupported field: " + field)
	for suffix in ["plain", "changed"]:
		var c := actor(suffix)
		var skill := "Stealth" if suffix == "plain" else "Arcana"
		check.call(c.class_levels == {c.class_id:1} and c.inventory.backpack.count("dagger") == 1 and c.inventory.backpack.count("quarterstaff") == 0, "018 starting boundary grants only its gear " + suffix)
		check.call("heavy" in c.armor_proficiencies and c.get_skill_proficiency_bonus(skill) == 4 and "WIS" in c.saving_throw_proficiencies, "018 starting proficiencies and expertise reach actual queries " + suffix)
		var before := c.to_dict().duplicate(true)
		c.initialize("repeat","human",c.class_id,AbilityScores.new())
		check.call(c.to_dict() == before, "018 repeated initialization grants nothing " + suffix)
		check.call(ClassProgression.choose_feature_option(c,"fixture:018_choice_"+suffix,"overlap") and ClassProgression.replace_feature_option(c,"fixture:018_choice_"+suffix,"overlap","other"), "018 accepted choice acquisition/replacement remains usable " + suffix)
		check.call(skill in c.skill_proficiencies and "heavy" in c.armor_proficiencies, "018 replacement retains independent permanent grants " + suffix)
		c.level_up()
		var captured := c.permanent_progression.duplicate(true)
		check.call(c.level == 1 and int(captured.pending_levels) == 1, "018 milestone creates one unspent level " + suffix)
		var secondary: String = "fixture:018_secondary_"+suffix
		check.call(PermanentProgressionRules.advance(c,secondary,captured), "018 secondary class entry succeeds " + suffix)
		check.call(c.level == 2 and c.get_class_level() == 1 and c.get_class_level(secondary) == 1 and c.inventory.backpack.count("quarterstaff") == 2 and c.inventory.backpack.count("dagger") == 1 and "Nature" in c.skill_proficiencies, "018 multiclass uses distinct grants with exact class levels " + suffix)
		before = c.to_dict().duplicate(true)
		check.call(not PermanentProgressionRules.advance(c,secondary,captured) and c.to_dict() == before, "018 stale answer cannot replay acquisition " + suffix)
		c.level_up()
		var old_hp := c.max_hp
		var old_con := AbilityScores.get_modifier(c.ability_scores.get_permanent_score("CON"))
		check.call(PermanentProgressionRules.advance(c,c.class_id,c.permanent_progression.duplicate(true)), "018 primary level succeeds " + suffix)
		var base_hp := 5 if suffix == "plain" else 3
		var delta := 2 if suffix == "plain" else 4
		var con_delta := 3 if suffix == "plain" else 0
		check.call(c.max_hp == old_hp + base_hp + old_con + delta + con_delta + 6, "018 permanent CON/HP plus both owned character-level grants settle exactly " + suffix)
		check.call(c.get_class_level() == 2 and c.get_class_level(secondary) == 1 and not c.permanent_progression.receipts.has(secondary+"|level:class_two"), "018 character level never substitutes secondary class level " + suffix)
		var json_dto: Dictionary = JSON.parse_string(JSON.stringify(c.to_dict()))
		check.call(PermanentProgressionRules.saved_error(json_dto).is_empty(), "018 JSON numeric normalization preserves valid acquisition state " + suffix)
		var restored := Character.new()
		before = c.to_dict().duplicate(true)
		restored.from_dict(before)
		check.call(restored.to_dict() == before and PermanentProgressionRules.saved_error(before).is_empty(), "018 DTO restore replays no gear/stat grants " + suffix)
		for mutation in ["strip","history","receipt","allocation","pending","payload","proficiency"]:
			var bad := before.duplicate(true)
			match mutation:
				"strip": bad.erase("permanent_progression")
				"history": bad.permanent_progression.history[0] = secondary
				"receipt": bad.permanent_progression.receipts.erase(c.class_id+"|starting")
				"allocation": bad.class_levels[c.class_id] = 1
				"pending": bad.permanent_progression.pending_levels = 1.5
				"payload": bad.permanent_progression.receipts[c.class_id+"|starting"].grants = []
				"proficiency": bad.skill_proficiencies = []
			check.call(not PermanentProgressionRules.saved_error(bad).is_empty(), "018 malformed state refuses " + suffix + " " + mutation)
		c.level_up()
		while c.inventory.backpack.size() < Inventory.MAX_BACKPACK_SIZE: c.inventory.add_item("dagger")
		before = c.to_dict().duplicate(true)
		check.call(not PermanentProgressionRules.advance(c,c.class_id,c.permanent_progression.duplicate(true)) and c.to_dict() == before, "018 full inventory refuses entire level before deltas " + suffix)
		var veteran := actor(suffix)
		for _gain in 4:
			veteran.level_up()
			check.call(PermanentProgressionRules.advance(veteran,veteran.class_id,veteran.permanent_progression.duplicate(true)), "018 repeated real progression boundary " + suffix)
		check.call(veteran.level == 5 and veteran.proficiency_bonus == 3 and veteran.get_skill_proficiency_bonus(skill) == 6 and veteran.inventory.backpack.count("dagger") == 2, "018 total-level proficiency growth and expertise never reacquire gear " + suffix)
		var state := veteran.permanent_progression.duplicate(true)
		veteran.level_up()
		before = veteran.to_dict().duplicate(true)
		check.call(not PermanentProgressionRules.advance(veteran,"wizard",veteran.permanent_progression.duplicate(true)) and veteran.to_dict() == before, "018 unavailable native class refuses without spending " + suffix)
		GameManager.current_state = GameManager.GameState.COMBAT
		check.call(not PermanentProgressionRules.advance(veteran,veteran.class_id,veteran.permanent_progression.duplicate(true)) and veteran.to_dict() == before, "018 combat refuses permanent class choice " + suffix)
		GameManager.current_state = GameManager.GameState.OVERWORLD
		check.call(not PermanentProgressionRules.advance(veteran,veteran.class_id,state) and veteran.to_dict() == before, "018 old button cannot consume a newly awarded entitlement " + suffix)

		print("018 LOGIC RECEIPT: " + JSON.stringify({"suffix":suffix,"state":c.permanent_progression,"hp":c.max_hp,"scores":c.ability_scores.to_dict()}))

static func controls(h: Node) -> void:
	h._enter_test("batch_018_progression_flow")
	h._setup_world()
	load_fixtures()
	for suffix in ["plain","changed"]:
		PlayerManager.reset()
		PartyManager.reset()
		PlayerManager.add_player("018 Owner")
		PlayerManager.add_player("018 Next seat")
		GameManager.current_state = GameManager.GameState.CHARACTER_CREATION
		var creation: Node = await h._spawn_scene("res://scenes/ui/character_creation.tscn",0.2)
		creation.current_step = creation.CreationStep.CLASS
		creation._update_step_ui()
		var selected := false
		for card in creation.class_grid.get_children():
			if card is Button and card.get_meta("choice_id", "") == "fixture:018_"+suffix:
				card.pressed.emit()
				selected = true
		h._assert(selected and creation.selected_class_id == "fixture:018_"+suffix, "018 actual creation class card selects loaded class " + suffix)
		creation.selected_name = "018 Created " + suffix
		creation.selected_race_id = "human"
		creation.selected_stats.from_dict({"STR":12,"DEX":12,"CON":12,"INT":12,"WIS":12,"CHA":12})
		creation.current_step = creation.CreationStep.SUMMARY
		creation._update_step_ui()
		h._assert(creation.summary_equip_label.text.contains("Dagger"), "018 actual creation review displays authored gear " + suffix)
		creation.btn_next.pressed.emit()
		var c: Character = PlayerManager.get_player(0).get("character")
		h._assert(c != null and c.class_id == "fixture:018_"+suffix and c.inventory.backpack.count("dagger") == 1 and c.inventory.backpack.count("quarterstaff") == 0, "018 actual creation Confirm acquires starting-only grants " + suffix)
		h._teardown_scene(creation)
		GameManager.current_state = GameManager.GameState.OVERWORLD
		PartyManager.reset()
		PlayerManager.set_player_character(0,c)
		PartyManager.register_player_character(0,c)
		var campaign: Dictionary = GameManager.active_campaign.duplicate(true)
		campaign.milestones = [{"trigger":"018-control-"+suffix,"effects":[{"type":"level_up"}]}]
		GameManager.active_campaign = campaign
		GameManager.completed_milestones.clear()
		h._assert(GameManager.check_milestone("018-control-"+suffix) and not GameManager.check_milestone("018-control-"+suffix) and int(c.permanent_progression.pending_levels) == 1, "018 actual milestone awards once " + suffix)
		var panel := ClassTraining.new()
		h.add_child(panel)
		var refreshes: Array = []
		panel.configure(c,func(): refreshes.append(true))
		var options: OptionButton = panel.find_child("ProgressionClass",true,false)
		var button: Button = panel.find_child("AcquireClassLevel",true,false)
		var ids := PermanentProgressionRules.available_classes(c)
		options.select(ids.find("fixture:018_secondary_"+suffix))
		var before := c.to_dict().duplicate(true)
		panel.queue_free()
		await h.get_tree().process_frame
		h._assert(c.to_dict() == before, "018 closing level picker grants/pays nothing " + suffix)
		panel = ClassTraining.new()
		h.add_child(panel)
		panel.configure(c,func(): refreshes.append(true))
		options = panel.find_child("ProgressionClass",true,false)
		button = panel.find_child("AcquireClassLevel",true,false)
		options.select(ids.find("fixture:018_secondary_"+suffix))
		button.pressed.emit()
		h._assert(c.level == 2 and c.inventory.backpack.count("quarterstaff") == 2 and refreshes.size() == 1, "018 actual gain-class-level button acquires secondary grants once " + suffix)
		before = c.to_dict().duplicate(true)
		button.pressed.emit()
		h._assert(c.to_dict() == before and refreshes.size() == 1, "018 old real button cannot spend/grant again " + suffix)
		panel.queue_free()
		await h.get_tree().process_frame
		# The same UI gains primary class level two, with character level three triggers.
		c.level_up()
		panel = ClassTraining.new()
		h.add_child(panel)
		panel.configure(c,func(): refreshes.append(true))
		options = panel.find_child("ProgressionClass",true,false)
		button = panel.find_child("AcquireClassLevel",true,false)
		options.select(ids.find(c.class_id))
		button.pressed.emit()
		h._assert(c.level == 3 and c.get_class_level() == 2 and "History" in c.skill_proficiencies and int(c.permanent_progression.pending_levels) == 0, "018 actual primary-level control settles class/character grants " + suffix)
		print("018 CONTROL RECEIPT: " + JSON.stringify(c.to_dict()))
		panel.queue_free()
		await h.get_tree().process_frame
	# A valid authored grant can exceed the backpack's total capacity. Confirm
	# must leave the player uncreated rather than register initialize's blank actor.
	PlayerManager.reset()
	PartyManager.reset()
	PlayerManager.add_player("018 Refused owner")
	PlayerManager.add_player("018 Next seat")
	var original := DataLoader.get_character_class("fixture:018_plain").duplicate(true)
	var oversized := original.duplicate(true)
	oversized.permanent_progression.starting.append({"type":"equipment_grant", "item_id":"dagger", "quantity":20})
	oversized.permanent_progression.starting.append({"type":"equipment_grant", "item_id":"dagger", "quantity":20})
	DataLoader.classes[original.id] = oversized
	GameManager.current_state = GameManager.GameState.CHARACTER_CREATION
	var refused_creation: Node = await h._spawn_scene("res://scenes/ui/character_creation.tscn",0.2)
	refused_creation.selected_name = "018 Cannot fit"
	refused_creation.selected_race_id = "human"
	refused_creation.selected_class_id = original.id
	refused_creation.current_step = refused_creation.CreationStep.SUMMARY
	refused_creation._update_step_ui()
	refused_creation.btn_next.pressed.emit()
	h._assert(refused_creation.btn_next.disabled and refused_creation.summary_equip_label.text.contains("will not fit"), "018 oversized starting grant explains refusal and disables Confirm")
	refused_creation._confirm_and_save_character()
	h._assert(PlayerManager.get_player(0).get("character") == null and PartyManager.characters.is_empty() and refused_creation.current_player_idx == 0, "018 oversized starting grant cannot register a blank actor or advance creation")
	h._teardown_scene(refused_creation)
	DataLoader.classes[original.id] = original
