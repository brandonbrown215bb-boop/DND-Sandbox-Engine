class_name BatchKChecks
extends RefCounted

static func run(check: Callable) -> void:
	var neutral_record: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/fixtures/batch_k_choices.json"))
	var renamed_record: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/fixtures/batch_k_choices_renamed.json"))
	var validator: Node = DataLoader.get_script().new()
	check.call(validator._validate_content(neutral_record, "class", "batch-k"), "Batch K neutral progression choices validate through DataLoader")
	check.call(validator._validate_content(renamed_record, "class", "batch-k-renamed"), "Batch K renamed progression choices validate through DataLoader")

	# Loader refusal mutations
	for mutation in ["bad_count", "fractional_count", "bad_pick", "fractional_pick", "conflicting_counts", "bad_duplicates", "bad_min_level", "fractional_level", "bad_requires", "bad_when", "target_when", "wrong_fact_type"]:
		var invalid := neutral_record.duplicate(true)
		var feat: Dictionary = invalid.features_by_level["1"][1]
		var eff: Dictionary = feat.effects[0]
		match mutation:
			"bad_count": eff.count = 0
			"fractional_count": eff.count = 1.5
			"bad_pick":
				eff.erase("count")
				eff.pick = -1
			"fractional_pick": eff.pick = 1.5
			"conflicting_counts": eff.pick = 1
			"bad_duplicates": eff.allow_duplicates = "yes"
			"bad_min_level": eff.options[0].minimum_level = 25
			"fractional_level": eff.options[0].minimum_level = 1.5
			"bad_requires": eff.options[0].requires_choices = [""]
			"bad_when": eff.options[4].when = {"fact": "unknown_fact", "eq": 1}
			"target_when": eff.options[4].when = {"not": {"fact": "target.current_hp", "gt": 0}}
			"wrong_fact_type": eff.options[4].when = {"fact": "actor.level", "eq": "1"}
		check.call(not validator._validate_content(invalid, "class", "batch-k-invalid"), "Batch K loader refuses mutation: " + mutation)
	var alias_record := neutral_record.duplicate(true)
	alias_record.features_by_level["1"][1].effects[0].count = 2.0
	alias_record.features_by_level["1"][1].effects[0].pick = 2.0
	alias_record.features_by_level["1"][1].effects[0].options[0].minimum_level = 1.0
	check.call(validator._validate_content(alias_record, "class", "batch-k-integral-aliases"), "K8: agreeing integral JSON count/pick/level values remain valid")
	validator.free()
	DataLoader.classes[neutral_record["id"]] = neutral_record

	# S-045: Filtered progression choice acquisition
	var actor := Character.new()
	actor.character_id = "k:hero"
	actor.class_id = "fixture:batch_k"
	actor.level = 1
	actor.ability_scores = AbilityScores.new()
	actor.features.assign(neutral_record.features_by_level["1"])
	actor.weapon_proficiencies = ["simple"]
	actor.armor_proficiencies = ["light"]

	# Count enforcement: k_invocations requires exactly 2 options
	check.call(not ClassProgression.choose_feature_options(actor, "fixture:k_invocations", ["k_armor_of_shadows"]), "Choice acquisition refuses fewer options than declared count")
	check.call(not ClassProgression.choose_feature_options(actor, "fixture:k_invocations", ["k_armor_of_shadows", "k_agonizing_blast", "k_thirsting_blade"]), "Choice acquisition refuses more options than declared count")
	check.call(actor.feature_choices.is_empty(), "Failed choice acquisition leaves feature_choices untouched")

	# Level filter: k_lifedrinker requires level 3
	check.call(not ClassProgression.choose_feature_options(actor, "fixture:k_invocations", ["k_armor_of_shadows", "k_lifedrinker"]), "Choice acquisition refuses option when level requirement is unmet")

	# Fact predicate filter: k_veteran_ward requires actor.level >= 2
	check.call(not ClassProgression.choose_feature_options(actor, "fixture:k_invocations", ["k_armor_of_shadows", "k_veteran_ward"]), "Choice acquisition refuses option when fact predicate is unsatisfied")

	# Prerequisite filter: k_thirsting_blade requires k_blade
	check.call(not ClassProgression.choose_feature_options(actor, "fixture:k_invocations", ["k_armor_of_shadows", "k_thirsting_blade"]), "Choice acquisition refuses option when prerequisite choice is missing")

	# Pick k_blade for k_boon
	check.call(ClassProgression.choose_feature_option(actor, "fixture:k_boon", "k_blade"), "Single choice acquisition succeeds for k_boon")
	check.call("martial" in actor.weapon_proficiencies, "Pact of the Blade grants martial weapon proficiency")

	# Duplication policy: non-repeatable option cannot be duplicated
	check.call(not ClassProgression.choose_feature_options(actor, "fixture:k_invocations", ["k_armor_of_shadows", "k_armor_of_shadows"]), "Choice acquisition refuses duplicates on non-repeatable option")

	# Repeatable option can be picked multiple times
	var actor_repeatable := Character.new()
	actor_repeatable.character_id = "k:repeatable"
	actor_repeatable.class_id = "fixture:batch_k"
	actor_repeatable.level = 1
	actor_repeatable.ability_scores = AbilityScores.new()
	actor_repeatable.features.assign(neutral_record.features_by_level["1"])
	check.call(ClassProgression.choose_feature_options(actor_repeatable, "fixture:k_invocations", ["k_agonizing_blast", "k_agonizing_blast"]), "Choice acquisition allows duplicate of repeatable option")

	# Successful acquisition of k_invocations with dependent option
	check.call(ClassProgression.choose_feature_options(actor, "fixture:k_invocations", ["k_thirsting_blade", "k_armor_of_shadows"]), "Choice acquisition succeeds when prerequisites and filters are met")
	check.call(actor.extra_attacks == 1, "Thirsting blade grants Extra Attack")
	check.call("medium" in actor.armor_proficiencies, "Armor of Shadows grants medium armor proficiency")

	# S-046: Replace choices with dependent grants
	# Attempt to replace k_blade with k_tome while k_thirsting_blade depends on it: MUST REFUSE
	var refusal := ClassProgression.can_replace_feature_option(actor, "fixture:k_boon", "k_blade", "k_tome")
	check.call(not bool(refusal.get("allowed", true)), "Replacement is refused when another active choice depends on the replaced option")
	check.call(not ClassProgression.replace_feature_option(actor, "fixture:k_boon", "k_blade", "k_tome"), "replace_feature_option refuses without modifying choices")
	check.call(actor.feature_choices["fixture:k_boon"] == ["k_blade"], "Option remains selected after refused replacement")
	check.call("martial" in actor.weapon_proficiencies and actor.extra_attacks == 1, "No partial revocation of grants on refused replacement")

	# Safe replacement of option without dependents: k_armor_of_shadows -> k_agonizing_blast
	check.call(ClassProgression.replace_feature_option(actor, "fixture:k_invocations", "k_armor_of_shadows", "k_agonizing_blast"), "Safe replacement succeeds for option without dependents")
	check.call("k_agonizing_blast" in actor.feature_choices["fixture:k_invocations"] and "k_armor_of_shadows" not in actor.feature_choices["fixture:k_invocations"], "Replaced option updated in feature_choices")
	check.call("medium" not in actor.armor_proficiencies, "Grants from replaced option are revoked")
	check.call("martial" in actor.weapon_proficiencies and actor.extra_attacks == 1, "Grants from unreplaced options remain intact")

	# Exact source preservation: if actor had martial from race/class as well, replacing k_blade when safe preserves martial
	var dual_source_actor := Character.new()
	dual_source_actor.character_id = "k:dual"
	dual_source_actor.class_id = "fighter"
	dual_source_actor.level = 1
	dual_source_actor.ability_scores = AbilityScores.new()
	dual_source_actor.features.assign(neutral_record.features_by_level["1"])
	dual_source_actor.weapon_proficiencies = ["simple", "martial"]
	check.call(ClassProgression.choose_feature_option(dual_source_actor, "fixture:k_boon", "k_blade"), "Dual source actor picks k_blade")
	check.call("martial" in dual_source_actor.weapon_proficiencies, "Martial proficiency present from fighter base and choice")
	check.call(ClassProgression.replace_feature_option(dual_source_actor, "fixture:k_boon", "k_blade", "k_tome"), "Replace k_blade with k_tome when no dependents exist")
	check.call("martial" in dual_source_actor.weapon_proficiencies, "Martial proficiency retained from Fighter base after k_blade is replaced")

	# Save preflight validation
	var valid_dto := {
		"class_id": "fixture:batch_k",
		"level": 1,
		"feature_choices": {
			"fixture:k_boon": ["k_blade"],
			"fixture:k_invocations": ["k_thirsting_blade", "k_armor_of_shadows"]
		}
	}
	check.call(ClassProgression.saved_choices_error(valid_dto).is_empty(), "Valid Batch K saved choices pass preflight error check")

	var orphaned_dto := {
		"class_id": "fixture:batch_k",
		"level": 1,
		"feature_choices": {
			"fixture:k_boon": ["k_tome"],
			"fixture:k_invocations": ["k_thirsting_blade", "k_armor_of_shadows"]
		}
	}
	check.call(not ClassProgression.saved_choices_error(orphaned_dto).is_empty(), "Saved choices preflight rejects orphaned dependent choice")

	var bad_count_dto := {
		"class_id": "fixture:batch_k",
		"level": 1,
		"feature_choices": {
			"fixture:k_boon": ["k_blade"],
			"fixture:k_invocations": ["k_thirsting_blade"]
		}
	}
	check.call(not ClassProgression.saved_choices_error(bad_count_dto).is_empty(), "Saved choices preflight rejects incorrect option count")
	_repair_regressions(check, neutral_record)
	DataLoader.classes.erase(neutral_record["id"])


static func actor(class_id: String) -> Character:
	var scores := AbilityScores.new()
	scores.from_dict({"STR":14, "DEX":14, "CON":14, "INT":12, "WIS":16, "CHA":16})
	var c := Character.new()
	c.initialize("Batch K", "human", class_id, scores)
	c.character_id = "fixture_hero"
	return c


static func full_save(c: Character) -> Dictionary:
	var save: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/fixtures/save_v2_2024.json"))
	save.party.characters["fixture_hero"] = c.to_dict()
	save.players[0].character = c.to_dict()
	return save


static func train_spells(c: Character) -> bool:
	var selected: Array[String] = []
	selected.append_array(c.get_spell_option_ids(true).slice(0, c.get_spellcasting_capacity("cantrips")))
	selected.append_array(c.get_spell_option_ids(false).slice(0, c.get_spellcasting_capacity("prepared_spells")))
	return ClassProgression.choose_spell_selection(c, selected)


static func _repair_regressions(check: Callable, neutral: Dictionary) -> void:
	var original_cleric: Dictionary = DataLoader.classes["cleric"]
	var original_fighter: Dictionary = DataLoader.classes["fighter"]
	var c := actor("cleric")
	check.call(ClassProgression.choose_feature_option(c, "cleric_divine_order", "thaumaturge"), "K5: existing catalog choice acquired")
	check.call(not ClassProgression.can_replace_feature_option(c, "cleric_divine_order", "thaumaturge", "protector").allowed, "K5: absent replacement permission refuses")
	var cleric_record := original_cleric.duplicate(true)
	cleric_record.features_by_level["1"][1].effects[0].allow_replacement = true
	DataLoader.classes["cleric"] = cleric_record
	c = actor("cleric")
	check.call(ClassProgression.choose_feature_option(c, "cleric_divine_order", "thaumaturge") and train_spells(c), "K1: explicitly replaceable spell grant trained")
	check.call(SaveManager._validate_save_data(full_save(c)).is_empty(), "K1: original trained full save is valid")
	var before := c.to_dict().duplicate(true)
	check.call(not ClassProgression.replace_feature_option(c, "cleric_divine_order", "thaumaturge", "protector"), "K1: capacity loss refuses while trained cantrip depends on it")
	check.call(c.to_dict() == before, "K1: refused replacement preserves all character state")
	check.call(SaveManager._validate_save_data(full_save(c)).is_empty(), "K1: refused replacement remains saveable")
	c = actor("cleric")
	check.call(ClassProgression.choose_feature_option(c, "cleric_divine_order", "protector") and train_spells(c), "K1: ordinary capacity trained")
	check.call(ClassProgression.replace_feature_option(c, "cleric_divine_order", "protector", "thaumaturge"), "K1: capacity increase safely replaces")
	check.call(c.spell_choices_pending and SaveManager._validate_save_data(full_save(c)).is_empty(), "K1: capacity increase opens pending training and remains saveable")
	# A list expansion is also a grant supporting training, even without extra capacity.
	cleric_record.features_by_level["1"][1].effects[0].options[0].effects.append({"type":"spell_list_expansion", "spell_lists":["wizard"]})
	c = actor("cleric")
	ClassProgression.choose_feature_option(c, "cleric_divine_order", "protector")
	var spells: Array[String] = c.get_spell_option_ids(true).slice(0, c.get_spellcasting_capacity("cantrips"))
	spells.append("magic_missile")
	for spell_id in c.get_spell_option_ids(false):
		if spell_id != "magic_missile" and spells.size() < 7: spells.append(spell_id)
	check.call(ClassProgression.choose_spell_selection(c, spells), "K1: train spell provided by choice-owned list expansion")
	before = c.to_dict().duplicate(true)
	check.call(not ClassProgression.replace_feature_option(c, "cleric_divine_order", "protector", "thaumaturge") and c.to_dict() == before, "K1: loss of trained spell list refuses without mutation")
	for edge in ["leveled_only", "unearned_feature"]:
		var edge_record := cleric_record.duplicate(true)
		var expansion := {"id":"fixture:k_other_expansion", "name":"Other expansion", "type":"passive", "effects":[{"type":"spell_list_expansion", "spell_lists":["wizard"], "level_1_plus_only":edge == "leveled_only"}]}
		edge_record.features_by_level["1" if edge == "leveled_only" else "2"].append(expansion)
		DataLoader.classes["cleric"] = edge_record
		c = actor("cleric")
		if edge == "unearned_feature":
			c.level = 2
			c.class_levels = {"cleric":1, "fighter":1}
		ClassProgression.choose_feature_option(c, "cleric_divine_order", "protector")
		spells.clear()
		spells.append("fire_bolt")
		for spell_id in c.get_spell_option_ids(true):
			if spell_id != "fire_bolt" and spells.size() < 3: spells.append(spell_id)
		spells.append_array(c.get_spell_option_ids(false).slice(0, c.get_spellcasting_capacity("prepared_spells")))
		check.call(ClassProgression.choose_spell_selection(c, spells), "K1: expanded cantrip trains for " + edge)
		before = c.to_dict().duplicate(true)
		check.call(not ClassProgression.replace_feature_option(c, "cleric_divine_order", "protector", "thaumaturge") and c.to_dict() == before, "K1: unrelated expansion cannot authorize cantrip loss: " + edge)
	DataLoader.classes["cleric"] = cleric_record

	# Repeated selections contribute once per occurrence to both runtime and saved capacity.
	cleric_record.features_by_level["1"][1].effects[0].count = 2
	cleric_record.features_by_level["1"][1].effects[0].options[1].repeatable = true
	c = actor("cleric")
	check.call(ClassProgression.choose_feature_options(c, "cleric_divine_order", ["thaumaturge", "thaumaturge"]) and train_spells(c), "K2: repeated multi-pick spell capacity trains normally")
	check.call(c.get_spellcasting_capacity("cantrips") == 5 and SaveManager._validate_save_data(full_save(c)).is_empty(), "K2: all repeated spell capacity grants pass full-save preflight")
	var restored := Character.new()
	restored.from_dict(c.to_dict())
	check.call(restored.known_spells == c.known_spells and restored.get_spellcasting_capacity("cantrips") == 5, "K2: repeated capacity and trained spells restore without new grants")
	DataLoader.classes["cleric"] = original_cleric

	var fighter_record := original_fighter.duplicate(true)
	var skill_feature: Dictionary = neutral.features_by_level["1"][0].duplicate(true)
	skill_feature.effects[0].options[0].effects = [{"type":"proficiency_grant", "skill_proficiencies":["Athletics"]}]
	fighter_record.features_by_level["1"].append(skill_feature)
	DataLoader.classes["fighter"] = fighter_record
	c = actor("fighter")
	check.call("Athletics" in c.fighter_training.skills and c.creation_choices.is_empty(), "K3: Fighter training independently owns Athletics")
	check.call(ClassProgression.choose_feature_option(c, "fixture:k_boon", "k_blade") and ClassProgression.replace_feature_option(c, "fixture:k_boon", "k_blade", "k_tome"), "K3: overlapping skill choice acquired and replaced")
	check.call("Athletics" in c.skill_proficiencies and "Perception" in c.skill_proficiencies, "K3: replacement preserves both Fighter training skills")
	check.call(SaveManager._validate_save_data(full_save(c)).is_empty(), "K3: preserved Fighter full save remains valid")
	DataLoader.classes["fighter"] = original_fighter

	var record := neutral.duplicate(true)
	record.features_by_level["1"][1].effects[0].options[1].class_id = "fighter"
	DataLoader.classes[record.id] = record
	c = actor(record.id)
	c.level = 2
	c.class_levels = {str(record.id):1, "fighter":1}
	check.call(ClassProgression.choose_feature_options(c, "fixture:k_invocations", ["k_armor_of_shadows", "k_agonizing_blast"]), "K4: represented secondary class permits acquisition")
	check.call(SaveManager._validate_save_data(full_save(c)).is_empty(), "K4: secondary class eligibility agrees with full-save preflight")
	restored = Character.new()
	restored.from_dict(c.to_dict())
	check.call(restored.class_levels == c.class_levels and restored.feature_choices == c.feature_choices and "medium" in restored.armor_proficiencies, "K4: represented allocation and filtered choices restore")
	var invalid := c.to_dict().duplicate(true)
	invalid.class_levels = {str(record.id):2}
	check.call(not ClassProgression.saved_choices_error(invalid).is_empty(), "K4: absent secondary class refuses saved option")
	invalid = c.to_dict().duplicate(true)
	invalid.feature_choices["fixture:k_invocations"] = ["k_veteran_ward", "k_agonizing_blast"]
	invalid.level = 1
	invalid.class_levels.clear()
	check.call(not ClassProgression.saved_choices_error(invalid).is_empty(), "K7: saved fact-gated choice refuses an unmet actor level")
	DataLoader.classes[record.id] = neutral

	c = actor(record.id)
	check.call(not SharedStepExecutor.evaluate_actor_predicate({"not":{"fact":"target.current_hp", "gt":0}}, c), "K7: unavailable target context never grants through negation")
	c.character_id = ""
	check.call(not SharedStepExecutor.evaluate_actor_predicate({"not":{"fact":"actor.id", "eq":"missing"}}, c), "K7: unavailable actor identity stays unknown under negation")
	c.character_id = "fixture_hero"
	check.call(SharedStepExecutor.evaluate_actor_predicate({"all":[{"fact":"actor.level", "eq":1}, {"not":{"fact":"actor.id", "eq":"other"}}]}, c), "K7: supported typed nested actor facts still qualify")


static func select_option(selector: OptionButton, option_id: String) -> bool:
	for index in selector.item_count:
		if str(selector.get_item_metadata(index)) == option_id:
			selector.select(index)
			selector.item_selected.emit(index)
			return true
	return false


static func choice_controls(check: Callable) -> void:
	var neutral: Dictionary = DataLoader.classes["fixture:batch_k"]
	var record := neutral.duplicate(true)
	record.features_by_level["1"][1].effects[0].options[0].requires_choices = ["k_armor_of_shadows"]
	DataLoader.classes[record.id] = record
	var c := actor(record.id)
	var panel := ClassTraining.new()
	panel._build_feature_choice(c, "fixture:k_invocations", func(): pass)
	var row: HBoxContainer = panel.get_child(0)
	var first: OptionButton = row.get_child(0)
	var second: OptionButton = row.get_child(1)
	check.call(select_option(first, "k_armor_of_shadows"), "K6: first actual selector offers prerequisite")
	check.call(select_option(second, "k_thirsting_blade"), "K6: second actual selector refreshes to offer dependent")
	check.call(select_option(first, "k_agonizing_blast") and str(second.get_item_metadata(second.selected)).is_empty(), "K6: changing prerequisite clears dependent selection")
	check.call(select_option(first, "k_armor_of_shadows") and select_option(second, "k_thirsting_blade"), "K6: prerequisite and dependent can be selected again")
	var choose_button: Button = row.get_child(2)
	choose_button.pressed.emit()
	check.call(c.feature_choices.get("fixture:k_invocations", []) == ["k_armor_of_shadows", "k_thirsting_blade"] and c.extra_attacks == 1 and "medium" in c.armor_proficiencies, "K6: actual Choose button commits complete multi-pick grants")
	var before := c.to_dict().duplicate(true)
	choose_button.pressed.emit()
	check.call(c.to_dict() == before, "K6: replayed Choose button changes nothing")
	panel.free()
	DataLoader.classes[record.id] = neutral

	c = actor("fixture:batch_k_renamed")
	panel = ClassTraining.new()
	panel._build_feature_choice(c, "fixture:k_renamed_choice", func(): pass)
	row = panel.get_child(0)
	check.call(select_option(row.get_child(0), "k_renamed_alpha"), "K controls: renamed selection offered by actual picker")
	var button: Button = row.get_child(1)
	button.pressed.emit()
	check.call("heavy" in c.armor_proficiencies, "K controls: renamed Choose button grants armor")
	panel.free()
	panel = ClassTraining.new()
	panel._build_feature_choice_replacement(c, "fixture:k_renamed_choice", func(): pass)
	row = panel.get_child(0)
	check.call(select_option(row.get_child(1), "k_renamed_beta"), "K controls: renamed replacement offered")
	button = row.get_child(2)
	button.pressed.emit()
	check.call("heavy" not in c.armor_proficiencies and "Stealth" in c.skill_proficiencies and SaveManager._validate_save_data(full_save(c)).is_empty(), "K controls: actual renamed Replace removes only old grant and remains saveable")
	before = c.to_dict().duplicate(true)
	button.pressed.emit()
	check.call(c.to_dict() == before, "K controls: replayed renamed Replace changes nothing")
	panel.free()

	c = actor("cleric")
	ClassProgression.choose_feature_option(c, "cleric_divine_order", "thaumaturge")
	panel = ClassTraining.new()
	panel._build_feature_choice_replacement(c, "cleric_divine_order", func(): pass)
	check.call(panel.get_child_count() == 0, "K5: actual catalog panel hides undeclared replacement")
	panel.free()

	var original_cleric: Dictionary = DataLoader.classes["cleric"]
	var replaceable := original_cleric.duplicate(true)
	replaceable.features_by_level["1"][1].effects[0].allow_replacement = true
	DataLoader.classes["cleric"] = replaceable
	c = actor("cleric")
	ClassProgression.choose_feature_option(c, "cleric_divine_order", "thaumaturge")
	panel = ClassTraining.new()
	panel._build_feature_choice_replacement(c, "cleric_divine_order", func(): pass)
	row = panel.get_child(0)
	select_option(row.get_child(1), "protector")
	button = row.get_child(2)
	check.call(train_spells(c), "K1 controls: train dependent spells after replacement menu opened")
	before = c.to_dict().duplicate(true)
	button.pressed.emit()
	check.call(c.to_dict() == before and SaveManager._validate_save_data(full_save(c)).is_empty(), "K1 controls: stale actual Replace button refuses without state or save damage")
	panel.free()
	DataLoader.classes["cleric"] = original_cleric
