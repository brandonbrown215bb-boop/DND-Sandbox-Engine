## Class tool items (SRD 5.2.1 Druid/Monk Starting Equipment option A): one
## generic data path, item copy separate from proficiency, granted once.
class_name ClassToolItemChecks
extends RefCounted

static func run(check: Callable) -> void:
	var smith := _monk("smiths_tools", "equipment")
	var lyre := _monk("lyre", "equipment")
	check.call(smith.inventory.count_item("smiths_tools") == 1 and smith.inventory.count_item("lyre") == 0 and smith.tool_proficiency_sources == {"smiths_tools": ["class_choice:monk"]} and smith.inventory.gold == 11, "Monk with Smith's Tools gets exactly that one item, its proficiency and 11 GP")
	check.call(lyre.inventory.count_item("lyre") == 1 and lyre.inventory.count_item("smiths_tools") == 0 and lyre.tool_proficiency_sources == {"lyre": ["class_choice:monk"]}, "Monk with a Lyre gets exactly that one item")
	var gold_monk := _monk("lyre", "gold")
	check.call(gold_monk.inventory.count_item("lyre") == 0 and gold_monk.inventory.count_item("spear") == 0 and gold_monk.inventory.gold == 50 and gold_monk.tool_proficiency_sources == {"lyre": ["class_choice:monk"]}, "Monk option B (50 GP) gives no tool item but keeps the chosen proficiency")
	var druid_choices := ClassProgression.default_creation_choices("druid", "human")
	druid_choices["equipment"] = "gold"
	var gold_druid := Character.new()
	gold_druid.initialize("Gold Druid", "human", "druid", AbilityScores.new(), "gold", druid_choices)
	check.call(gold_druid.inventory.count_item("herbalism_kit") == 0 and gold_druid.inventory.gold == 50 and gold_druid.tool_proficiency_sources == {"herbalism_kit": ["class:druid"]}, "Druid option B (50 GP) gives no kit; Herbalism proficiency stays")
	var bogus := ClassProgression.default_creation_choices("monk", "human")
	bogus["equipment"] = "pack"
	check.call(not ClassProgression.creation_choices_error("monk", "human", bogus).is_empty(), "An unknown equipment option is refused")
	var before := JSON.stringify(smith.inventory.to_dict())
	smith.initialize("Again", "human", "monk", AbilityScores.new(), "equipment", ClassProgression.default_creation_choices("monk", "human"))
	check.call(JSON.stringify(smith.inventory.to_dict()) == before and smith.character_name != "Again", "Repeating creation on a confirmed character is refused without a second item")
	var restored := Character.new()
	restored.from_dict(smith.to_dict())
	check.call(JSON.stringify(restored.inventory.to_dict()) == before and restored.tool_proficiency_sources == smith.tool_proficiency_sources, "Restore keeps the exact item copy and source without replay")
	var dropped := smith.to_dict()
	dropped["inventory"] = Inventory.new().to_dict()
	var after_drop := Character.new()
	after_drop.from_dict(dropped)
	check.call(after_drop.inventory.count_item("smiths_tools") == 0 and after_drop.tool_proficiencies == ["smiths_tools"], "A save without the item (old save or item sold) is not regranted on load; proficiency is independent")
	# Review: the loader refuses a malformed declaration.
	var no_choices := DataLoader.get_character_class("monk").duplicate(true)
	no_choices["id"] = "fixture:tool_item_no_choices"
	no_choices.erase("tool_choices")
	var not_bool := DataLoader.get_character_class("monk").duplicate(true)
	not_bool["id"] = "fixture:tool_item_not_bool"
	not_bool["starting_equipment_includes_tool_choice"] = "yes"
	var errors_before: int = DataLoader._load_errors.size()
	var accepted_a: bool = DataLoader._validate_semantics(no_choices, "class", "tool item review")
	var accepted_b: bool = DataLoader._validate_semantics(not_bool, "class", "tool item review")
	var added: Array = DataLoader._load_errors.slice(errors_before)
	DataLoader._load_errors.resize(errors_before)
	check.call(not accepted_a and not accepted_b and added.filter(func(e): return "starting_equipment_includes_tool_choice" in str(e)).size() == 2, "The loader refuses a tool-item declaration without tool_choices or as a non-boolean (%s)" % str(added))
	# Neutral renamed class: same declaration, no class-ID branch.
	var neutral := DataLoader.get_character_class("monk").duplicate(true)
	neutral["id"] = "tool_item_probe"
	neutral["name"] = "Tool Item Probe"
	DataLoader.classes["tool_item_probe"] = neutral
	var choices := ClassProgression.default_creation_choices("tool_item_probe", "human")
	choices["tools"] = ["cooks_utensils"]
	var probe := Character.new()
	probe.initialize("Probe", "human", "tool_item_probe", AbilityScores.new(), "equipment", choices)
	check.call(probe.inventory.count_item("cooks_utensils") == 1 and probe.tool_proficiency_sources == {"cooks_utensils": ["class_choice:tool_item_probe"]}, "A neutral renamed class using the same declaration gets its chosen tool item")
	neutral.erase("starting_equipment_includes_tool_choice")
	var plain := Character.new()
	plain.initialize("Plain", "human", "tool_item_probe", AbilityScores.new(), "equipment", choices)
	check.call(plain.inventory.count_item("cooks_utensils") == 0 and plain.tool_proficiencies == ["cooks_utensils"], "Without the declaration the same class gets proficiency only")
	DataLoader.classes.erase("tool_item_probe")


static func _monk(tool: String, mode: String) -> Character:
	var choices := ClassProgression.default_creation_choices("monk", "human")
	choices["tools"] = [tool]
	choices["equipment"] = mode
	var c := Character.new()
	c.initialize("Monk " + tool, "human", "monk", AbilityScores.new(), mode, choices)
	return c
