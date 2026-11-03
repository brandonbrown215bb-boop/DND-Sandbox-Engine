class_name ClassSkillSelectionChecks
extends RefCounted
## PR C: class skill selection at creation for Barbarian, Fighter, Paladin,
## Ranger, Sorcerer, Warlock and Wizard through the G2 picker. Counts and lists
## are SRD 5.2.1 Core <Class> Traits (srd.txt lines in comments).

const SRD := {
	"barbarian": [2, ["Animal Handling", "Athletics", "Intimidation", "Nature", "Perception", "Survival"]], # 1735-1737
	"fighter": [2, ["Acrobatics", "Animal Handling", "Athletics", "History", "Insight", "Intimidation", "Persuasion", "Perception", "Survival"]], # 2844-2848
	"paladin": [2, ["Athletics", "Insight", "Intimidation", "Medicine", "Persuasion", "Religion"]], # 3177-3181
	"ranger": [3, ["Animal Handling", "Athletics", "Insight", "Investigation", "Nature", "Perception", "Stealth", "Survival"]], # 3417-3420
	"sorcerer": [2, ["Arcana", "Deception", "Insight", "Intimidation", "Persuasion", "Religion"]], # 3818-3822
	"warlock": [2, ["Arcana", "Deception", "History", "Intimidation", "Investigation", "Nature", "Religion"]], # 4187-4190
	"wizard": [2, ["Arcana", "History", "Insight", "Investigation", "Medicine", "Nature", "Religion"]], # 4604-4606
}

static func make(race: String, class_id: String, skills: Array, equipment := "equipment") -> Character:
	var c := Character.new()
	c.initialize("C " + class_id, race, class_id, AbilityScores.new(), equipment, {"skills": skills, "tools": [], "equipment": equipment})
	return c

static func run(check: Callable) -> void:
	for class_id in SRD:
		var data := DataLoader.get_character_class(class_id)
		var contract: Dictionary = data.get("skill_choices", {})
		var picks: Array = SRD[class_id][1].slice(0, SRD[class_id][0])
		var c := make("human", class_id, picks)
		var once: bool = picks.all(func(s): return c.skill_proficiencies.count(s) == 1)
		check.call(ClassProgression.uses_creation_choices(class_id) and int(contract.get("pick", 0)) == SRD[class_id][0] and contract.get("from", []) == SRD[class_id][1] and c.class_id == class_id and once and c.creation_choices.get("skills", []) == picks and ClassProgression.saved_creation_error(c.to_dict()).is_empty(), "PR C %s: SRD count/list, picks granted once, recorded, save-valid" % class_id)
		var bad := [picks.slice(0, picks.size() - 1), [picks[0]] + picks.slice(0, picks.size() - 1), picks.slice(0, picks.size() - 1) + ["Sleight of Hand"]]
		check.call(bad.all(func(b): return not ClassProgression.creation_choices_error(class_id, "human", {"skills": b, "tools": [], "equipment": "equipment"}).is_empty()) and make("human", class_id, bad[1]).class_id.is_empty(), "PR C %s: short, duplicate and off-list picks refused before anything is granted" % class_id)
	# Species duplicates: elf Perception cannot be a Ranger/Fighter/Barbarian pick.
	check.call(["ranger", "fighter", "barbarian"].all(func(id): return not ClassProgression.creation_choices_error(id, "elf", {"skills": ["Perception"] + SRD[id][1].filter(func(s): return s != "Perception").slice(0, SRD[id][0] - 1), "tools": [], "equipment": "equipment"}).is_empty()), "PR C species-provided Perception is refused as a class pick")
	# Barbarian A/B equipment through the generic contract (SRD 1741-1745).
	var gold := make("human", "barbarian", ["Athletics", "Survival"], "gold")
	var kit := make("human", "barbarian", ["Athletics", "Survival"], "equipment")
	check.call(gold.inventory.gold == 75 and kit.inventory.gold == 15 and gold.creation_choices.equipment == "gold" and ClassProgression.saved_creation_error(gold.to_dict()).is_empty(), "PR C Barbarian keeps option B 75 GP / option A 15 GP with class picks")
	_fighter(check)
	_cross_sources(check)
	_legacy(check)

static func _fighter(check: Callable) -> void:
	var auto := Character.new()
	auto.initialize("Auto", "human", "fighter", AbilityScores.new())
	check.call(auto.fighter_training.skills == ["Athletics", "Perception"] and auto.creation_choices.get("skills", []) == ["Athletics", "Perception"] and auto.skill_proficiencies.count("Athletics") == 1, "PR C Fighter untouched picks keep automatic Athletics and Perception")
	var elf := Character.new()
	elf.initialize("Elf", "elf", "fighter", AbilityScores.new())
	check.call(ClassProgression.preset_creation_skills("fighter", "elf") == ["Athletics"] and elf.fighter_training.skills.size() == 2 and "Perception" not in elf.fighter_training.skills and elf.skill_proficiencies.count("Perception") == 1, "PR C elf Fighter default never spends a pick on species Perception")
	var c := make("human", "fighter", ["History", "Insight"])
	var picked: bool = c.fighter_training.skills == ["History", "Insight"] and "Athletics" not in c.skill_proficiencies and "Perception" not in c.skill_proficiencies
	var swapped := FighterRules.choose_skills(c, "Survival", "Athletics")
	check.call(picked and swapped and c.creation_choices.skills == ["Survival", "Athletics"] and "History" not in c.skill_proficiencies and FighterRules.saved_training_error(c.to_dict()).is_empty() and ClassProgression.saved_creation_error(c.to_dict()).is_empty(), "PR C Fighter picks are the training skills; pre-combat swap keeps picks and save in sync (2 class skills, not 4)")
	var e := make("elf", "fighter", ["Athletics", "History"])
	check.call(not FighterRules.choose_skills(e, "Perception", "History") and e.fighter_training.skills == ["Athletics", "History"], "PR C Fighter swap refuses a species-held skill")
	var took := FeatRules.choose_origin(c, "skilled", {"skills": ["Stealth", "Arcana", "History"], "tools": []})
	check.call(took.success and not FighterRules.choose_skills(c, "Stealth", "Insight") and c.creation_choices.skills == ["Survival", "Athletics"], "PR C/G4 Fighter swap still refuses Skilled-owned skills")
	var tampered := c.to_dict()
	tampered.creation_choices.skills = ["Acrobatics", "Insight"]
	check.call(not FighterRules.saved_training_error(tampered).is_empty(), "PR C save refuses Fighter class picks that disagree with training")

static func _cross_sources(check: Callable) -> void:
	for class_id in ["wizard", "fighter", "ranger"]:
		var picks: Array = SRD[class_id][1].slice(0, SRD[class_id][0])
		var c := make("human", class_id, picks)
		var dup := FeatRules.choose_origin(c, "skilled", {"skills": [picks[0], "Stealth" if class_id != "ranger" else "Arcana", "Deception"], "tools": []})
		check.call(not dup.success and c.origin_feat.is_empty() and c.skill_proficiencies.count(picks[0]) == 1, "PR C %s: Skilled refuses a skill already granted by class picks" % class_id)
	var b := make("human", "barbarian", ["Athletics", "Survival"])
	var before := b.skill_proficiencies.duplicate()
	check.call(b.skill_proficiencies.count("Athletics") == 1 and b.skill_proficiencies == before, "PR C Barbarian picks granted once")

static func _legacy(check: Callable) -> void:
	for class_id in SRD:
		var dto := {"class_id": class_id, "race_id": "human", "skill_proficiencies": [], "tool_proficiencies": [], "creation_choices": {"ability_generation": "standard_array"}}
		check.call(ClassProgression.saved_creation_error(dto).is_empty(), "PR C %s: pre-picker save (generation receipt only, no class skills) stays valid, nothing invented" % class_id)
