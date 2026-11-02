## G2 regressions: class skill/tool choices at creation with per-source tool ownership.
class_name ClassToolProficiencyChecks
extends RefCounted

static func run(check: Callable) -> void:
	var druid := make("druid")
	check.call(druid.tool_proficiencies == ["herbalism_kit"] and druid.tool_proficiency_sources == {"herbalism_kit": ["class:druid"]}, "Druid creation grants Herbalism Kit proficiency owned by the Druid class")
	check.call(druid.inventory.count_item("herbalism_kit") == 0 and CheckHelpRules.owns(druid, "tool", "herbalism_kit"), "Druid proficiency does not require or create the kit item and is usable for Help")
	var rogue := make("rogue")
	check.call(rogue.tool_proficiencies == ["thieves_tools"] and rogue.tool_proficiency_sources == {"thieves_tools": ["class:rogue"]} and rogue.skill_proficiencies.size() >= 4, "Rogue creation grants chosen skills and class-owned Thieves' Tools")
	check.call(not ClassProgression.grant_tool_proficiency(rogue, "thieves_tools", "class:rogue"), "Repeating the same source grant is refused")
	check.call(ClassProgression.grant_tool_proficiency(rogue, "thieves_tools", "background:criminal") and rogue.tool_proficiencies.count("thieves_tools") == 1 and rogue.tool_proficiency_sources["thieves_tools"] == ["class:rogue", "background:criminal"], "Rogue and Criminal both own Thieves' Tools without a duplicate proficiency")
	check.call(not ClassProgression.grant_tool_proficiency(rogue, "dagger", "feat:x") and not ClassProgression.grant_tool_proficiency(rogue, "lute", "bogus:x"), "Non-tool items and unknown source kinds are refused")
	var fighter := make("fighter")
	fighter.inventory.add_item("thieves_tools")
	check.call(not CheckHelpRules.owns(fighter, "tool", "thieves_tools") and fighter.tool_proficiencies.is_empty(), "Owning tools is not proficiency")
	var monk_choices := ClassProgression.default_creation_choices("monk", "human")
	monk_choices["tools"] = ["flute"]
	var monk := Character.new()
	monk.initialize("Monk", "human", "monk", AbilityScores.new(), "equipment", monk_choices)
	check.call(monk.tool_proficiencies == ["flute"] and monk.tool_proficiency_sources == {"flute": ["class_choice:monk"]} and monk.inventory.count_item("flute") == 0, "Monk chooses one instrument proficiency without receiving the item")
	var bad := monk_choices.duplicate(true)
	bad["tools"] = ["flute", "lute"]
	check.call(not ClassProgression.creation_choices_error("monk", "human", bad).is_empty(), "Monk must choose exactly one tool")
	bad["tools"] = ["thieves_tools"]
	check.call(not ClassProgression.creation_choices_error("monk", "human", bad).is_empty(), "Monk refuses a tool outside its list")
	bad = ClassProgression.default_creation_choices("rogue", "human")
	bad["skills"] = [bad["skills"][0], bad["skills"][0], bad["skills"][1], bad["skills"][2]]
	var refused := Character.new()
	refused.initialize("Refused", "human", "rogue", AbilityScores.new(), "equipment", bad)
	check.call(refused.character_name.is_empty() and refused.tool_proficiencies.is_empty(), "Duplicate Rogue skill choices refuse before any grant")
	var saved := monk.to_dict()
	var restored := Character.new()
	restored.from_dict(JSON.parse_string(JSON.stringify(saved)))
	check.call(ClassProgression.saved_choices_error(saved).is_empty() and restored.tool_proficiencies == ["flute"] and restored.tool_proficiency_sources == {"flute": ["class_choice:monk"]} and restored.inventory.to_dict() == monk.inventory.to_dict(), "Monk tool ownership round-trips without replaying grants")
	saved = rogue.to_dict()
	restored.from_dict(JSON.parse_string(JSON.stringify(saved)))
	check.call(ClassProgression.saved_choices_error(saved).is_empty() and restored.tool_proficiency_sources["thieves_tools"].size() == 2 and restored.inventory.count_item("thieves_tools") == rogue.inventory.count_item("thieves_tools"), "Two-source Thieves' Tools reload once with both owners and no extra item")
	var stale := monk.to_dict()
	stale["creation_choices"]["tools"] = ["lute"]
	check.call(not ClassProgression.saved_choices_error(stale).is_empty(), "A stale saved Monk choice is refused at load preflight")
	stale = druid.to_dict()
	stale["tool_proficiency_sources"] = {"herbalism_kit": ["class:rogue"]}
	check.call(not ClassProgression.saved_choices_error(stale).is_empty(), "A source naming another class is refused")
	stale = druid.to_dict()
	stale["tool_proficiency_sources"] = {"herbalism_kit": ["class:druid", "class:druid"]}
	check.call(not ClassProgression.saved_choices_error(stale).is_empty(), "Duplicate saved sources are refused")
	var legacy := druid.to_dict()
	legacy.erase("tool_proficiency_sources")
	legacy.erase("creation_choices")
	legacy["tool_proficiencies"] = []
	restored.from_dict(legacy)
	check.call(ClassProgression.saved_choices_error(legacy).is_empty() and restored.tool_proficiencies.is_empty() and restored.tool_proficiency_sources.is_empty(), "Legacy Druid saves load without a retroactive Herbalism grant")

	# Reviewer repro (PR #74): pre-G2 Bard DTO keeps choices and instrument
	# proficiencies but has no sources key; load -> save must still validate.
	var bard_choices := {"skills": ["Performance", "Persuasion", "Stealth"], "tools": ["lute", "flute", "viol"], "instrument": "drum", "equipment": "equipment"}
	var bard := Character.new()
	bard.initialize("Legacy Bard", "elf", "bard", AbilityScores.new(), "equipment", bard_choices)
	var old_bard := bard.to_dict()
	old_bard.erase("tool_proficiency_sources")
	check.call(ClassProgression.saved_choices_error(old_bard).is_empty(), "Pre-G2 Bard save with retained instrument choices passes preflight")
	var loaded_bard := Character.new()
	loaded_bard.from_dict(JSON.parse_string(JSON.stringify(old_bard)))
	var resaved := loaded_bard.to_dict()
	check.call(ClassProgression.saved_choices_error(resaved).is_empty(), "Loaded pre-G2 Bard save validates again on its next save: %s" % ClassProgression.saved_choices_error(resaved))
	check.call(loaded_bard.tool_proficiencies == ["lute", "flute", "viol"] and loaded_bard.creation_choices == bard_choices and loaded_bard.tool_proficiency_sources.is_empty() and loaded_bard.inventory.to_dict() == bard.inventory.to_dict(), "Legacy Bard grants are retained without replay or invented sources")
	var reloaded := Character.new()
	reloaded.from_dict(JSON.parse_string(JSON.stringify(resaved)))
	check.call(ClassProgression.saved_choices_error(reloaded.to_dict()).is_empty() and reloaded.tool_proficiencies == loaded_bard.tool_proficiencies, "Legacy Bard survives a second save/reload cycle")
	var forged := bard.to_dict()
	forged["tool_proficiency_sources"] = {"lute": ["class_choice:bard"], "flute": ["class_choice:bard"]}
	check.call(not ClassProgression.saved_choices_error(forged).is_empty(), "A post-G2 save missing a chosen tool's source is still refused")


static func make(class_id: String) -> Character:
	var c := Character.new()
	c.initialize("G2 " + class_id, "human", class_id, AbilityScores.new(), "equipment", ClassProgression.default_creation_choices(class_id, "human"))
	return c
