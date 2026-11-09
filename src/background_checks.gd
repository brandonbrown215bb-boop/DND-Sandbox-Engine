class_name BackgroundChecks
extends RefCounted
## CXM-04 / S-231: background acquisition at creation (SRD 5.2.1 p.83).

const BASE := {"STR": 15, "DEX": 14, "CON": 13, "INT": 12, "WIS": 10, "CHA": 8}

static func class_choices(class_id: String, race_id: String, background_id: String) -> Dictionary:
	var choices := ClassProgression.default_creation_choices(class_id, race_id)
	var taken: Array = DataLoader.get_background(background_id).get("skills", []) + DataLoader.get_race(race_id).get("proficiencies", [])
	var contract: Dictionary = DataLoader.get_character_class(class_id).get("skill_choices", {})
	choices["skills"] = contract.get("from", []).filter(func(skill): return skill not in taken).slice(0, int(contract.get("pick", 0)))
	return choices

static func make(class_id: String, background_id: String, picks: Dictionary, scores_dict: Dictionary = BASE, race_id: String = "human") -> Character:
	var scores := AbilityScores.new()
	scores.from_dict(scores_dict)
	var c := Character.new()
	c.initialize("BG %s %s" % [background_id, class_id], race_id, class_id, scores, "equipment", class_choices(class_id, race_id, background_id), background_id, picks)
	return c

static func picks(abilities: Dictionary, tools: Array = [], equipment: String = "equipment") -> Dictionary:
	return {"abilities": abilities, "tools": tools, "equipment": equipment}

## Copies of an item carried anywhere: backpack, equipped, or inside a Quiver.
static func carried(c: Character, item_id: String) -> int:
	var count := c.inventory.count_item(item_id) + c.inventory.equipped.values().count(item_id)
	for record in c.inventory.backpack_instances():
		if record.definition_id == "quiver": count += ContainerRules.contents(c.inventory, str(record.instance_id), "pieces").filter(func(r): return r.definition_id == item_id).size()
	return count

static func _loads(data: Dictionary) -> bool:
	var before := DataLoader._load_errors.size()
	var ok: bool = DataLoader._validate_content(data, "background", "cxm04_probe")
	DataLoader._load_errors.resize(before)
	return ok

static func run(check: Callable) -> void:
	_definitions(check)
	_acquisition(check)
	_refusals(check)
	_saves(check)

static func _definitions(check: Callable) -> void:
	check.call(DataLoader.get_load_errors().is_empty() and DataLoader.get_all_backgrounds().map(func(b): return b.id) == ["acolyte", "criminal", "sage", "soldier"], "CXM-04 the four SRD backgrounds load: %s" % str(DataLoader.get_load_errors()))
	var soldier: Dictionary = DataLoader.get_background("soldier").duplicate(true)
	soldier.erase("_source")
	soldier.erase("_source_record")
	var renamed := soldier.duplicate(true)
	renamed["id"] = "fixture:cxm04_veteran"
	var two_abilities := soldier.duplicate(true)
	two_abilities["ability_options"] = ["STR", "DEX"]
	var one_skill := soldier.duplicate(true)
	one_skill["skills"] = ["Athletics"]
	var overlap := soldier.duplicate(true)
	overlap["tool_proficiency_grants"] = ["dice_set"]
	var no_gold := soldier.duplicate(true)
	no_gold.erase("starting_gold_alternative")
	var no_feat := soldier.duplicate(true)
	no_feat.erase("origin_feat")
	check.call(_loads(renamed) and not _loads(two_abilities) and not _loads(one_skill) and not _loads(overlap) and not _loads(no_gold) and not _loads(no_feat), "CXM-04 loader accepts a renamed background and refuses bad abilities, skills, tool overlap, missing GP and a missing feat")
	var skilled := soldier.duplicate(true)
	skilled["origin_feat"] = "skilled"
	var unknown_feat := soldier.duplicate(true)
	unknown_feat["origin_feat"] = "cxm04_missing"
	var bad_parameter := soldier.duplicate(true)
	bad_parameter["origin_feat"] = "magic_initiate|bard"
	var bad_item := soldier.duplicate(true)
	bad_item["starting_equipment"] = ["cxm04_missing"]
	check.call(BackgroundRules.reference_error(soldier).is_empty() and [skilled, unknown_feat, bad_parameter, bad_item].all(func(b): return not BackgroundRules.reference_error(b).is_empty()), "CXM-04 references to a pick feat, unknown feat, illegal parameter or missing item are load errors")
	var probe := Character.new()
	probe.level = 4
	var offered := FeatRules.options(probe, "origin") + FeatRules.options(probe, "")
	check.call(["alert", "magic_initiate", "savage_attacker"].all(func(id): return DataLoader.get_feat(id).get("category", "") == "origin") and not offered.any(func(id): return str(id).get_slice("|", 0) in ["alert", "magic_initiate", "savage_attacker"]) and "skilled" in offered, "CXM-04 background Origin feats load but effects-pending feats are not offered as picks")
	check.call(BackgroundRules.ability_spreads("soldier").size() == 7 and BackgroundRules.ability_spreads("soldier").all(func(s): return BackgroundRules.choices_error("soldier", picks(s, ["dice_set"])).is_empty()), "CXM-04 every listed +2/+1 and +1/+1/+1 spread is legal")

static func _acquisition(check: Callable) -> void:
	# Soldier, +2/+1, equipment: exact scores (no human +1s), skills, matching Gaming Set, kit and GP.
	var soldier := make("wizard", "soldier", picks({"STR": 2, "CON": 1}, ["dragonchess_set"]))
	var wizard_gold := ClassProgression.creation_starting_gold("wizard", {"equipment": "equipment"})
	check.call(soldier.background_id == "soldier" and soldier.ability_scores.to_dict() == {"STR": 17, "DEX": 14, "CON": 14, "INT": 12, "WIS": 10, "CHA": 8} and soldier.max_hp == 6 + 2, "CXM-04 Soldier +2 STR/+1 CON applies exactly, before HP, with no species bonus: %s hp %d" % [str(soldier.ability_scores.to_dict()), soldier.max_hp])
	check.call(soldier.origin_feat == "savage_attacker" and soldier.skill_proficiencies.count("Athletics") == 1 and soldier.skill_proficiencies.count("Intimidation") == 1 and soldier.tool_proficiency_sources.get("dragonchess_set", []) == ["background:soldier"] and "dice_set" not in soldier.tool_proficiencies, "CXM-04 Soldier grants its feat, two skills and only the chosen Gaming Set proficiency")
	check.call(carried(soldier, "dragonchess_set") == 1 and carried(soldier, "dice_set") == 0 and carried(soldier, "spear") == 1 and carried(soldier, "shortbow") == 1 and carried(soldier, "arrows") == 20 and carried(soldier, "quiver") == 1 and carried(soldier, "healers_kit") == 1 and carried(soldier, "travelers_clothes") == 1 and soldier.inventory.gold == wizard_gold + 14, "CXM-04 Soldier option A is the exact kit with the matching Gaming Set and 14 GP on top of the class GP (gold %d)" % soldier.inventory.gold)
	var before := soldier.to_dict()
	soldier.initialize("Again", "human", "wizard", AbilityScores.new(), "equipment", {}, "acolyte", picks({"INT": 2, "WIS": 1}))
	check.call(JSON.stringify(soldier.to_dict()) == JSON.stringify(before), "CXM-04 a confirmed character cannot acquire a background again")
	# +1/+1/+1 and the 50 GP option: no background items at all.
	var rich := make("wizard", "soldier", picks({"STR": 1, "DEX": 1, "CON": 1}, ["dice_set"], "gold"))
	check.call(rich.ability_scores.to_dict() == {"STR": 16, "DEX": 15, "CON": 14, "INT": 12, "WIS": 10, "CHA": 8} and rich.inventory.gold == wizard_gold + 50 and carried(rich, "spear") == 0 and carried(rich, "dice_set") == 0 and rich.tool_proficiency_sources.get("dice_set", []) == ["background:soldier"], "CXM-04 +1/+1/+1 with 50 GP gives no kit but keeps the proficiency")
	var acolyte := make("fighter", "acolyte", picks({"WIS": 2, "CHA": 1}))
	check.call(acolyte.origin_feat == "magic_initiate|cleric" and "Insight" in acolyte.skill_proficiencies and "Religion" in acolyte.skill_proficiencies and acolyte.tool_proficiency_sources.get("calligraphers_supplies", []) == ["background:acolyte"] and carried(acolyte, "parchment") == 10 and carried(acolyte, "book") == 1 and carried(acolyte, "holy_symbol") == 1 and carried(acolyte, "robe") == 1 and carried(acolyte, "calligraphers_supplies") == 1, "CXM-04 Acolyte fixes Magic Initiate (Cleric), its skills, tool and kit")
	var sage := make("fighter", "sage", picks({"INT": 1, "WIS": 1, "CON": 1}))
	check.call(sage.origin_feat == "magic_initiate|wizard" and "Arcana" in sage.skill_proficiencies and "History" in sage.skill_proficiencies and carried(sage, "parchment") == 8 and carried(sage, "quarterstaff") == 1, "CXM-04 Sage fixes Magic Initiate (Wizard) with 8 Parchment")
	var criminal := make("rogue", "criminal", picks({"DEX": 2, "INT": 1}))
	check.call(criminal.origin_feat == "alert" and criminal.tool_proficiencies.count("thieves_tools") == 1 and criminal.tool_proficiency_sources.get("thieves_tools", []) == ["class:rogue", "background:criminal"] and carried(criminal, "pouch") == 2 and carried(criminal, "crowbar") == 1 and carried(criminal, "dagger") == 4, "CXM-04 Rogue Criminal holds Thieves' Tools once from two sources and both Dagger pairs")
	# Legacy boundary: no background keeps the species bonuses and nothing else.
	var legacy := make("wizard", "", {})
	check.call(legacy.background_id.is_empty() and legacy.background_choices.is_empty() and legacy.ability_scores.get_score("STR") == 16 and legacy.origin_feat.is_empty() and BackgroundRules.saved_error(legacy.to_dict()).is_empty(), "CXM-04 a character made without a background keeps legacy species bonuses")
	# Every class kit plus every background kit fits the backpack.
	var tight: Array = []
	for class_data in DataLoader.get_all_classes():
		for option in ClassProgression.equipment_options(class_data.id):
			var choices := ClassProgression.default_creation_choices(class_data.id, "human")
			choices["equipment"] = option
			for background in DataLoader.get_all_backgrounds():
				var spread: Dictionary = BackgroundRules.ability_spreads(background.id)[0]
				var error := BackgroundRules.creation_error(background.id, picks(spread, background.get("tool_choices", {}).get("from", []).slice(0, 1)), AbilityScores.new(), "human", [], ClassProgression.creation_starting_equipment(class_data.id, choices))
				if not error.is_empty(): tight.append("%s/%s/%s: %s" % [class_data.id, option, background.id, error])
	check.call(tight.is_empty(), "CXM-04 every class kit and background kit fit together: %s" % str(tight))

static func _refusals(check: Callable) -> void:
	var bad: Array = [
		picks({"STR": 2, "DEX": 2}, ["dice_set"]), # two +2
		picks({"STR": 1, "DEX": 1}, ["dice_set"]), # only two +1
		picks({"STR": 2, "INT": 1}, ["dice_set"]), # INT is not a Soldier ability
		picks({"STR": 3}, ["dice_set"]),
		picks({"STR": 2, "DEX": 1}), # no Gaming Set chosen
		picks({"STR": 2, "DEX": 1}, ["lute"]), # not a Gaming Set
		picks({"STR": 2, "DEX": 1}, ["dice_set", "dragonchess_set"]),
		picks({"STR": 2, "DEX": 1}, ["dice_set"], "both"),
	]
	check.call(bad.all(func(p): return make("wizard", "soldier", p).class_id.is_empty()), "CXM-04 illegal ability spreads, tools or equipment options refuse the whole character")
	var capped := make("wizard", "soldier", picks({"STR": 2, "DEX": 1}, ["dice_set"]), {"STR": 19, "DEX": 14, "CON": 13, "INT": 12, "WIS": 10, "CHA": 8})
	var unknown := make("wizard", "cxm04_missing", picks({"STR": 2, "DEX": 1}))
	check.call(capped.class_id.is_empty() and capped.inventory.backpack.is_empty() and capped.inventory.gold == 0 and unknown.class_id.is_empty(), "CXM-04 an increase above 20 or an unknown background refuses before any grant")
	var scores := AbilityScores.new()
	scores.from_dict(BASE)
	var overlap := Character.new()
	var fighter_choices := ClassProgression.default_creation_choices("fighter", "human") # Athletics, Perception
	overlap.initialize("Overlap", "human", "fighter", scores, "equipment", fighter_choices, "soldier", picks({"STR": 2, "DEX": 1}, ["dice_set"]))
	check.call(overlap.class_id.is_empty() and "Athletics" in fighter_choices.skills, "CXM-04 a class skill pick the background already gives is refused")
	var fighter := make("fighter", "soldier", picks({"STR": 2, "DEX": 1}, ["dice_set"]))
	var held: Array = fighter.fighter_training.get("skills", []).duplicate()
	check.call(not fighter.class_id.is_empty() and not FighterRules.choose_skills(fighter, "Athletics", "History") and fighter.fighter_training.skills == held and fighter.skill_proficiencies.count("Athletics") == 1, "CXM-04 a Fighter cannot swap a training skill onto a background skill")

static func _saves(check: Callable) -> void:
	var soldier := make("wizard", "soldier", picks({"STR": 2, "CON": 1}, ["dragonchess_set"]))
	var dto: Dictionary = JSON.parse_string(JSON.stringify(soldier.to_dict())) # disk round-trip: numbers become floats
	check.call(ClassProgression.saved_choices_error(dto).is_empty(), "CXM-04 a background character passes save preflight: %s" % ClassProgression.saved_choices_error(dto))
	var restored := Character.new()
	restored.from_dict(dto)
	check.call(restored.background_id == "soldier" and restored.background_choices == soldier.background_choices and restored.ability_scores.to_dict() == soldier.ability_scores.to_dict() and restored.inventory.gold == soldier.inventory.gold and carried(restored, "arrows") == 20 and carried(restored, "dragonchess_set") == 1 and restored.origin_feat == "savage_attacker" and restored.skill_proficiencies == soldier.skill_proficiencies and restored.tool_proficiency_sources == soldier.tool_proficiency_sources, "CXM-04 restore keeps the background and replays no increase, item, GP or feat")
	var tampered: Array = []
	for edit in [
		func(d): d.background_id = "cxm04_missing",
		func(d): d.background_choices.abilities = {"STR": 2, "DEX": 2},
		func(d): d.background_choices.tools = ["dice_set"],
		func(d): d.background_choices["extra"] = true,
		func(d): d.background_choices = {},
		func(d): d.origin_feat = "",
		func(d): d.origin_feat = "skilled",
		func(d): d.skill_proficiencies.erase("Athletics"),
		func(d): d.tool_proficiency_sources.dragonchess_set = ["feat:skilled@origin"],
		func(d): d.tool_proficiency_sources.dragonchess_set = ["background:soldier", "background:sage"],
		func(d): d.background_id = "",
	]:
		var copy: Dictionary = dto.duplicate(true)
		edit.call(copy)
		tampered.append(not ClassProgression.saved_choices_error(copy).is_empty())
	check.call(not tampered.has(false), "CXM-04 forged, stripped or stale background state is refused by save preflight: %s" % str(tampered))
