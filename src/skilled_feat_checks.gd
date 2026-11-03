class_name SkilledFeatChecks
extends RefCounted
## G4: Skilled (SRD 5.2.1 p.87, Origin, Repeatable) and any feat declaring
## proficiency_choices. Each acquisition is its own instance (origin or the ASI
## feature it replaced) owning its picks as feat:<id>@<instance>.

const SKILLED := "skilled"
const DRILLED := "fixture:g4_drilled"

static func load_fixtures() -> void:
	if DataLoader.get_feat(DRILLED).is_empty(): DataLoader._load_json_file("res://data/fixtures/g4/feats.json", "feat")

static func fresh(id: String) -> Character:
	return Batch031Checks._character(id, 40)

static func _free_skills(c: Character, n: int) -> Array:
	var out := []
	for skill in DataLoader.get_feat(SKILLED).proficiency_choices.skills:
		if skill not in c.skill_proficiencies and out.size() < n: out.append(skill)
	return out

static func _loads(data: Dictionary) -> bool:
	var before := DataLoader._load_errors.size()
	var ok: bool = DataLoader._validate_content(data, "feat", "g4_probe")
	DataLoader._load_errors.resize(before)
	return ok

static func run(check: Callable) -> void:
	load_fixtures()
	_definition(check)
	_origin(check)
	_repeat(check)
	_reload(check)
	_tamper(check)
	_neutral(check)
	_fighter_training(check)
	_held_tool(check)
	_gaming_sets(check)
	_missing_feat_tool(check)

static func _definition(check: Callable) -> void:
	var feat := DataLoader.get_feat(SKILLED)
	var choice: Dictionary = feat.get("proficiency_choices", {})
	var tools_real: bool = choice.get("tools", []).all(func(t): return DataLoader.get_item(str(t)).get("type", "") == "tool")
	check.call(feat.get("category", "") == "origin" and bool(feat.get("repeatable", false)) and feat.get("features", [1]).is_empty() and int(choice.get("pick", 0)) == 3 and choice.skills.size() == DataLoader.VALID_SKILLS.size() and choice.tools.size() == 37 and tools_real, "G4 core Skilled is a repeatable Origin feat: 3 picks from all 18 skills and 37 SRD tool records (incl. 4 Gaming Sets)")
	var base := {"id": "g4p", "name": "P", "category": "origin", "repeatable": true, "features": []}
	var bad := []
	for pc in [{"pick": 0, "skills": ["Arcana"]}, {"pick": 2, "skills": ["Arcana"]}, {"pick": 1, "skills": ["Flying"]}, {"pick": 1, "skills": ["Arcana", "Arcana"]}, {"pick": 1, "skills": ["Arcana"], "extra": 1}, {"pick": 1, "tools": [3]}, "three"]:
		var d := base.duplicate(true)
		d["proficiency_choices"] = pc
		bad.append(_loads(d))
	var good := base.duplicate(true)
	good["proficiency_choices"] = {"pick": 1, "skills": ["Arcana"]}
	check.call(_loads(good) and not bad.has(true), "G4 loader refuses zero/oversized picks, unknown or duplicate skills, extra keys and non-string tools: %s" % str(bad))

static func _origin(check: Callable) -> void:
	var c := fresh("g4_origin")
	var skills_before := c.skill_proficiencies.duplicate()
	var held: String = c.skill_proficiencies[0] if not c.skill_proficiencies.is_empty() else ""
	var free := _free_skills(c, 2)
	var refusals := [
		FeatRules.choose_origin(c, SKILLED),
		FeatRules.choose_origin(c, SKILLED, {"skills": free, "tools": []}),
		FeatRules.choose_origin(c, SKILLED, {"skills": [free[0], free[0]], "tools": ["flute"]}),
		FeatRules.choose_origin(c, SKILLED, {"skills": free, "tools": ["rope_hempen"]}),
		FeatRules.choose_origin(c, SKILLED, {"skills": [free[0], "Flying"], "tools": ["flute"]}),
		FeatRules.choose_origin(c, SKILLED, {"skills": free, "tools": ["flute", "lute"]}),
	]
	if not held.is_empty(): refusals.append(FeatRules.choose_origin(c, SKILLED, {"skills": [held, free[0]], "tools": ["flute"]}))
	check.call(refusals.all(func(r): return not r.success) and c.origin_feat.is_empty() and c.feat_proficiency_choices.is_empty() and c.skill_proficiencies == skills_before and "flute" not in c.tool_proficiencies, "G4 Skilled refuses missing, short, duplicate, off-list, unknown, oversized and already-held picks all-or-nothing")
	var ok := FeatRules.choose_origin(c, SKILLED, {"skills": free, "tools": ["flute"]})
	check.call(ok.success and c.origin_feat == SKILLED and free.all(func(s): return c.skill_proficiencies.count(s) == 1) and c.tool_proficiency_sources.get("flute", []) == ["feat:skilled@origin"] and c.feat_proficiency_choices == {"origin": {"feat_id": SKILLED, "skills": free, "tools": ["flute"]}}, "G4 Origin Skilled grants two skills and a tool once, owned by feat:skilled@origin")
	var t := fresh("g4_tools")
	var tools_only := FeatRules.choose_origin(t, SKILLED, {"skills": [], "tools": ["thieves_tools", "lute", "cooks_utensils"]})
	check.call(tools_only.success and t.skill_proficiencies == fresh("g4_tools_probe").skill_proficiencies and ["thieves_tools", "lute", "cooks_utensils"].all(func(x): return t.tool_proficiency_sources.get(x, []) == ["feat:skilled@origin"]), "G4 any combination is legal: three tools and no skills")

static func _built() -> Character:
	var c := fresh("g4_repeat")
	var free := _free_skills(c, 3)
	FeatRules.choose_origin(c, SKILLED, {"skills": free, "tools": []})
	while c.level < 4: c.level_up()
	FeatRules.choose_level_feat(c, SKILLED, {"skills": _free_skills(c, 1), "tools": ["smiths_tools", "flute"]})
	return c

static func _repeat(check: Callable) -> void:
	var c := fresh("g4_repeat")
	var origin_skills := _free_skills(c, 3)
	FeatRules.choose_origin(c, SKILLED, {"skills": origin_skills, "tools": []})
	while c.level < 4: c.level_up()
	var pending := ClassProgression.pending_improvements(c)
	check.call(pending.size() == 1 and SKILLED in FeatRules.options(c, ""), "G4 an owned Skilled is still offered at an Ability Score Improvement (Repeatable)")
	var choices_before := c.feature_choices.duplicate(true)
	var bad := [FeatRules.choose_level_feat(c, SKILLED, {"skills": [origin_skills[0]], "tools": ["smiths_tools", "flute"]}), FeatRules.choose_level_feat(c, SKILLED, {"skills": [], "tools": []}), FeatRules.choose_level_feat(c, SKILLED)]
	check.call(bad.all(func(r): return not r.success) and c.feature_choices == choices_before and ClassProgression.pending_improvements(c) == pending and c.feat_proficiency_choices.size() == 1, "G4 a repeat that re-picks an owned skill or omits picks is refused and the improvement stays pending")
	var extra := _free_skills(c, 1)
	var took := FeatRules.choose_level_feat(c, SKILLED, {"skills": extra, "tools": ["smiths_tools", "flute"]})
	var instance := str(pending[0])
	check.call(took.success and ClassProgression.pending_improvements(c).is_empty() and c.feature_choices[instance] == ["feat:skilled"] and c.feat_proficiency_choices.keys().size() == 2 and c.feat_proficiency_choices[instance].skills == extra and c.tool_proficiency_sources.get("smiths_tools", []) == ["feat:skilled@" + instance] and c.skill_proficiencies.count(extra[0]) == 1 and FeatRules.owned(c).count(SKILLED) >= 1, "G4 the second Skilled is its own instance (feat:skilled@%s) with separate picks" % instance)

static func _reload(check: Callable) -> void:
	var c := _built()
	var dto: Dictionary = JSON.parse_string(JSON.stringify(c.to_dict()))
	check.call(ClassProgression.saved_choices_error(dto).is_empty(), "G4 a two-instance Skilled character passes save validation: %s" % ClassProgression.saved_choices_error(dto))
	var back := Character.new()
	back.from_dict(dto)
	var twice := Character.new()
	twice.from_dict(JSON.parse_string(JSON.stringify(back.to_dict())))
	for x in [back, twice]:
		check.call(x.feat_proficiency_choices == c.feat_proficiency_choices and x.skill_proficiencies == c.skill_proficiencies and x.tool_proficiencies == c.tool_proficiencies and x.tool_proficiency_sources == c.tool_proficiency_sources and x.origin_feat == SKILLED, "G4 reload keeps both instances, skills and tool owners exactly once (no replay)")
	var legacy: Dictionary = JSON.parse_string(JSON.stringify(fresh("g4_legacy").to_dict()))
	legacy.erase("feat_proficiency_choices")
	var old := Character.new()
	old.from_dict(legacy)
	check.call(ClassProgression.saved_choices_error(legacy).is_empty() and old.feat_proficiency_choices.is_empty(), "G4 a save from before G4 (no feat_proficiency_choices) still loads")
	# Removing another source of a Skilled skill keeps it (feat ownership).
	var r := fresh("g4_keep")
	var s := _free_skills(r, 3)
	FeatRules.choose_origin(r, SKILLED, {"skills": s, "tools": []})
	check.call(FeatRules.owns_skill(r, s[0]) and not FeatRules.owns_skill(r, "NotASkill"), "G4 feat instances report the skills they own")

static func _tamper(check: Callable) -> void:
	var dto: Dictionary = JSON.parse_string(JSON.stringify(_built().to_dict()))
	var asi := ""
	for key in dto.feat_proficiency_choices:
		if key != "origin": asi = key
	var cases := {}
	var d := dto.duplicate(true); d.feat_proficiency_choices.erase(asi); cases["missing instance"] = d
	d = dto.duplicate(true); d.feat_proficiency_choices.erase("origin"); cases["missing skills-only origin record"] = d
	d = dto.duplicate(true); d.feat_proficiency_choices["fixture:ghost"] = d.feat_proficiency_choices[asi].duplicate(true); cases["unearned instance"] = d
	d = dto.duplicate(true); d.feat_proficiency_choices[asi].tools.pop_back(); cases["short picks"] = d
	d = dto.duplicate(true); d.feat_proficiency_choices[asi].skills = [d.feat_proficiency_choices.origin.skills[0]]; cases["skill picked twice"] = d
	d = dto.duplicate(true); d.feat_proficiency_choices[asi].feat_id = DRILLED; cases["wrong feat"] = d
	d = dto.duplicate(true); d.skill_proficiencies.erase(d.feat_proficiency_choices.origin.skills[0]); cases["skill not held"] = d
	d = dto.duplicate(true); d.tool_proficiency_sources["flute"] = ["feat:skilled@origin"]; cases["tool owner swapped"] = d
	d = dto.duplicate(true); d.tool_proficiencies.append("lute"); d.tool_proficiency_sources["lute"] = ["feat:skilled@nowhere"]; cases["stale feat tool source"] = d
	d = dto.duplicate(true); d.feat_proficiency_choices = []; cases["not an object"] = d
	d = dto.duplicate(true); d.feature_choices.erase(asi); cases["feat removed, picks stale"] = d
	var accepted := []
	for name in cases:
		if ClassProgression.saved_choices_error(cases[name]).is_empty(): accepted.append(name)
	check.call(accepted.is_empty(), "G4 saves with missing, unearned, short, duplicated, wrong-feat, unheld, swapped, stale or malformed Skilled picks are refused: accepted %s" % str(accepted))

static func _neutral(check: Callable) -> void:
	var c := fresh("g4_neutral")
	var refused := FeatRules.choose_origin(c, DRILLED, {"skills": ["Survival"], "tools": ["lute"]})
	var ok := FeatRules.choose_origin(c, DRILLED, {"skills": ["Survival"], "tools": ["smiths_tools"]})
	var dto: Dictionary = JSON.parse_string(JSON.stringify(c.to_dict()))
	var back := Character.new()
	back.from_dict(dto)
	check.call(not refused.success and ok.success and c.tool_proficiency_sources.get("smiths_tools", []) == ["feat:%s@origin" % DRILLED] and ClassProgression.saved_choices_error(dto).is_empty() and back.feat_proficiency_choices == c.feat_proficiency_choices, "G4 a renamed neutral fixture feat (pick 2, own list) uses the same generic path and reloads")

## Reviewer: the pre-combat Fighter skill swap must not take or drop a feat's pick.
static func _fighter_training(check: Callable) -> void:
	var c := Character.new()
	c.initialize("G4 Fighter", "human", "fighter", AbilityScores.new(), "equipment", {})
	var took := FeatRules.choose_origin(c, SKILLED, {"skills": ["History", "Insight", "Stealth"], "tools": []})
	var refused: bool = not FighterRules.choose_skills(c, "History", "Survival") and c.fighter_training.skills == ["Athletics", "Perception"]
	var swapped: bool = FighterRules.choose_skills(c, "Survival", "Intimidation") and FighterRules.choose_skills(c, "Athletics", "Perception")
	check.call(took.success and refused and swapped and "History" in c.skill_proficiencies and "Survival" not in c.skill_proficiencies and FeatRules.saved_error(c.to_dict()).is_empty(), "Fighter creation skill swaps neither reuse nor strip a Skilled pick, and the save stays valid")

## Reviewer: a tool already held from another source is refused like a held skill.
static func _held_tool(check: Callable) -> void:
	var c := fresh("g4_held_tool")
	ClassProgression.grant_tool_proficiency(c, "flute", "background:g4_probe")
	var refused := FeatRules.choose_origin(c, SKILLED, {"skills": _free_skills(c, 2), "tools": ["flute"]})
	check.call(not refused.success and c.origin_feat.is_empty() and c.tool_proficiency_sources.get("flute", []) == ["background:g4_probe"], "G4 Skilled refuses a tool already held from another source")

## PR B: SRD 5.2.1 Gaming Set variants (Other Tools) are ordinary tool picks.
const GAMING_SETS := ["dice_set", "dragonchess_set", "playing_card_set", "three_dragon_ante_set"]

static func _gaming_sets(check: Callable) -> void:
	var tools: Array = DataLoader.get_feat(SKILLED).proficiency_choices.tools
	check.call(GAMING_SETS.all(func(t): return t in tools and DataLoader.get_item(t).get("type", "") == "tool" and str(DataLoader.get_item(t).get("name", "")).begins_with("Gaming Set (") and not DataLoader.get_item(t).has("weight")), "Skilled offers all four SRD Gaming Set variants as tool records; SRD weight '—' stays unknown (no weight key)")
	var c := fresh("gs_build")
	var origin := FeatRules.choose_origin(c, SKILLED, {"skills": _free_skills(c, 1), "tools": ["dice_set", "dragonchess_set"]})
	check.call(origin.success and c.tool_proficiencies.count("dice_set") == 1 and c.tool_proficiency_sources.get("dice_set", []) == ["feat:skilled@origin"] and c.inventory.count_item("dice_set") == 0 and CheckHelpRules.owns(c, "tool", "dice_set"), "Origin Skilled grants a Gaming Set once, owned by feat:skilled@origin, with no item")
	while c.level < 4: c.level_up()
	var pending := ClassProgression.pending_improvements(c)
	var before := c.tool_proficiency_sources.duplicate(true)
	var dup := [FeatRules.choose_level_feat(c, SKILLED, {"skills": _free_skills(c, 1), "tools": ["dice_set", "playing_card_set"]}), FeatRules.choose_level_feat(c, SKILLED, {"skills": _free_skills(c, 1), "tools": ["playing_card_set", "playing_card_set"]})]
	check.call(dup.all(func(r): return not r.success) and c.tool_proficiency_sources == before and ClassProgression.pending_improvements(c) == pending, "A repeat Skilled refuses an already-held or doubled Gaming Set all-or-nothing")
	var took := FeatRules.choose_level_feat(c, SKILLED, {"skills": [], "tools": ["playing_card_set", "three_dragon_ante_set", "lute"]})
	var asi := str(pending[0]) if not pending.is_empty() else ""
	check.call(took.success and c.tool_proficiency_sources.get("three_dragon_ante_set", []) == ["feat:skilled@" + asi] and GAMING_SETS.all(func(t): return c.tool_proficiencies.count(t) == 1), "The level-4 Skilled instance grants the other two Gaming Sets; all four held exactly once")
	var dto: Dictionary = JSON.parse_string(JSON.stringify(c.to_dict()))
	var back := Character.new()
	back.from_dict(dto)
	var twice := Character.new()
	twice.from_dict(JSON.parse_string(JSON.stringify(back.to_dict())))
	check.call(ClassProgression.saved_choices_error(dto).is_empty() and twice.tool_proficiencies == c.tool_proficiencies and twice.tool_proficiency_sources == c.tool_proficiency_sources and twice.feat_proficiency_choices == c.feat_proficiency_choices, "Gaming Set picks survive two save/reload round trips unchanged")
	var stolen := dto.duplicate(true)
	stolen.tool_proficiency_sources["dice_set"] = ["feat:skilled@" + asi]
	check.call(not ClassProgression.saved_choices_error(stolen).is_empty(), "A save that moves a Gaming Set to the other Skilled instance is refused")

## Reviewer G4 follow-up: the loader refuses a feat naming a missing or non-tool item.
static func _missing_feat_tool(check: Callable) -> void:
	var results := {}
	for tool_id in ["fixture:no_such_tool", "rations", "dice_set"]:
		var id := "fixture:g4_tool_probe"
		DataLoader.feats[id] = {"id": id, "name": "Probe", "category": "origin", "features": [], "proficiency_choices": {"pick": 1, "tools": [tool_id]}}
		var before := DataLoader._load_errors.size()
		DataLoader._validate_cross_references()
		var added: Array = DataLoader._load_errors.slice(before)
		DataLoader._load_errors.resize(before)
		DataLoader.feats.erase(id)
		results[tool_id] = added.has("Feat '%s' references missing tool '%s'" % [id, tool_id])
	check.call(not DataLoader.feats.has("fixture:g4_tool_probe"), "Loader tool probe leaves no probe feat behind")
	check.call(results["fixture:no_such_tool"] and results["rations"] and not results["dice_set"], "Loader refuses a feat tool choice that is missing or not a tool, and accepts a Gaming Set: %s" % str(results))
