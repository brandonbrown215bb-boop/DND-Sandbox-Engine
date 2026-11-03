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
	_package_checks(check)
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


## Owned item copies (backpack plus equipped) by definition id.
static func owned(c: Character) -> Dictionary:
	var counts := {}
	for record in c.inventory.owned_instances():
		var id := str(record.get("definition_id", ""))
		counts[id] = int(counts.get(id, 0)) + 1
	return counts


const DRUID_A := {"leather_armor": 1, "shield": 1, "druidic_focus_quarterstaff": 1, "sickle": 1, "explorers_pack": 1, "herbalism_kit": 1}
const FOCUS := "druidic_focus_quarterstaff"
const PACK := {"backpack": 1, "bedroll": 1, "oil_flask": 2, "rations": 10, "rope": 1, "tinderbox": 1, "torch": 10, "waterskin": 1}


## SRD 5.2.1 Druid A / Monk A remaining clauses (srd.txt 2500-2504, 2972-2978):
## Explorer's Pack through the same starting_equipment data path.
static func _package_checks(check: Callable) -> void:
	var dc := ClassProgression.default_creation_choices("druid", "human")
	var druid := Character.new()
	druid.initialize("Package Druid", "human", "druid", AbilityScores.new(), "equipment", dc)
	check.call(owned(druid) == DRUID_A and druid.inventory.gold == 9, "Druid option A owns exactly Leather Armor, Shield, one Explorer's Pack, one Herbalism Kit and 9 GP (%s)" % str(owned(druid)))
	check.call(not owned(druid).has("quarterstaff") and not owned(druid).has("wooden_staff") and druid.inventory.get_weapon() == FOCUS and druid.inventory.get_equipped(Inventory.Slot.SHIELD) == "shield" and druid.inventory.backpack.count("sickle") == 1, "Druid A holds the real Druidic Focus (Quarterstaff) as first weapon beside the Shield and carries the later Sickle; no ordinary Quarterstaff or Wooden Staff stand-in")
	_focus_checks(check, druid)
	var smith := _monk("smiths_tools", "equipment")
	check.call(owned(smith) == {"spear": 1, "dagger": 5, "smiths_tools": 1, "explorers_pack": 1} and smith.inventory.gold == 11, "Monk option A owns exactly Spear, 5 Daggers, the chosen tool, one Explorer's Pack and 11 GP (%s)" % str(owned(smith)))
	var gold_monk := _monk("lyre", "gold")
	var gc := ClassProgression.default_creation_choices("druid", "human")
	gc["equipment"] = "gold"
	var gold_druid := Character.new()
	gold_druid.initialize("Gold Druid", "human", "druid", AbilityScores.new(), "gold", gc)
	check.call(owned(gold_monk).is_empty() and owned(gold_druid).is_empty() and gold_monk.inventory.gold == 50 and gold_druid.inventory.gold == 50, "Option B (50 GP) owns no pack or other item")
	for c in [druid, smith]:
		var pack_id := ""
		for record in c.inventory.backpack_instances():
			if str(record.definition_id) == "explorers_pack": pack_id = str(record.instance_id)
		var before := owned(c)
		var result: Dictionary = c.inventory.expand_pack_instance(pack_id)
		var after := owned(c)
		var ok: bool = result.get("success", false) and int(result.get("contents_added", 0)) == 27 and not after.has("explorers_pack")
		for id in PACK:
			ok = ok and int(after.get(id, 0)) == int(before.get(id, 0)) + int(PACK[id])
		check.call(ok, "%s: the granted Explorer's Pack expands through the pack control into its exact SRD contents" % c.class_id)
		var again: Dictionary = c.inventory.expand_pack_instance(pack_id)
		check.call(not again.get("success", true) and owned(c) == after, "%s: a spent pack cannot be expanded twice" % c.class_id)
		var restored := Character.new()
		restored.from_dict(c.to_dict())
		check.call(owned(restored) == after and restored.inventory.gold == c.inventory.gold, "%s: restore keeps the expanded contents exactly, with no pack replay" % c.class_id)
	var neutral := DataLoader.get_character_class("druid").duplicate(true)
	neutral["id"] = "kit_package_probe"
	neutral["name"] = "Kit Package Probe"
	DataLoader.classes["kit_package_probe"] = neutral
	var probe := Character.new()
	probe.initialize("Probe", "human", "kit_package_probe", AbilityScores.new(), "equipment", ClassProgression.default_creation_choices("kit_package_probe", "human"))
	check.call(owned(probe) == DRUID_A and probe.inventory.gold == 9, "A neutral renamed class with the same data gets the same package (no class-ID branch)")
	DataLoader.classes.erase("kit_package_probe")


static func _monk(tool: String, mode: String) -> Character:
	var choices := ClassProgression.default_creation_choices("monk", "human")
	choices["tools"] = [tool]
	choices["equipment"] = mode
	var c := Character.new()
	c.initialize("Monk " + tool, "human", "monk", AbilityScores.new(), mode, choices)
	return c


static func _spell(id: String) -> Dictionary:
	return DataLoader.get_spell(id)


## SRD 5.2.1 Druidic Focus (srd.txt 5877-5887), Quarterstaff (5478 table),
## Somatic/Material (6382-6407): the held focus's hand can perform Somatic
## components; Somatic-only spells still need a free hand; priced/consumed
## materials keep their exact-copy rules; carried gear is not held.
static func _focus_checks(check: Callable, druid: Character) -> void:
	var inv: Inventory = druid.inventory
	var water_walk := _spell("water_walk")
	var cure := _spell("cure_wounds")
	var revivify := _spell("revivify")
	var focus_item := DataLoader.get_item(FOCUS)
	check.call(str(focus_item.get("type", "")) == "weapon" and focus_item.get("damage", "") == "1d6" and "versatile" in focus_item.get("properties", []) and focus_item.get("versatile_damage", "") == "1d8" and int(focus_item.get("value", 0)) == 5 and float(focus_item.get("weight", 0)) == 4.0, "The Druidic Focus (Quarterstaff) is a declared Quarterstaff weapon (1d6 Bludgeoning, Versatile 1d8, 4 lb.) at the Wooden staff focus cost of 5 GP")
	check.call(inv.available_spellcasting_hands() == 0 and inv.held_spellcasting_focus("druid") == FOCUS and inv.has_required_spell_component(water_walk, "druid"), "Shield plus the held Druidic Focus casts a V/S/M spell: the focus hand performs Material and Somatic")
	check.call(not inv.has_required_spell_component(cure, "druid"), "Shield plus held focus refuses a Somatic-only (V, S) spell: it still needs a free hand")
	check.call(inv.held_spellcasting_focus("ranger") == FOCUS and inv.held_spellcasting_focus("wizard").is_empty() and not inv.has_required_spell_component(water_walk, "wizard"), "Ranger may use the Druidic Focus; a Wizard holding it has no compatible focus")
	var diamond := Character.new()
	diamond.initialize("Diamond Druid", "human", "druid", AbilityScores.new(), "equipment", ClassProgression.default_creation_choices("druid", "human"))
	check.call(not diamond.inventory.has_required_spell_component(revivify, "druid"), "A held focus does not replace Revivify's priced, consumed diamond")
	diamond.inventory.add_item("diamond_300gp")
	check.call(not diamond.inventory.has_required_spell_component(revivify, "druid"), "With the exact diamond but Shield plus focus held, Revivify still needs a free hand to access it")
	diamond.inventory.equipment_control_unequip(Inventory.Slot.SHIELD)
	check.call(diamond.inventory.has_required_spell_component(revivify, "druid") and not diamond.inventory.required_spell_component_instance(revivify).is_empty(), "Stowing the Shield frees a hand; Revivify then uses the exact diamond copy")
	# Equip the Sickle through the real control: the focus goes to the backpack and is no longer held.
	var sickle_id := ""
	for record in inv.backpack_instances():
		if str(record.definition_id) == "sickle": sickle_id = str(record.instance_id)
	var equipped_sickle: Dictionary = inv.equipment_control_equip(Inventory.Slot.WEAPON, sickle_id)
	check.call(equipped_sickle.get("success", false) and inv.get_weapon() == "sickle" and inv.backpack.has(FOCUS) and inv.held_spellcasting_focus("druid").is_empty() and not inv.has_required_spell_component(water_walk, "druid"), "Sickle plus Shield keeps the hand refusal; the stowed focus is carried, not held")
	inv.equipment_control_unequip(Inventory.Slot.SHIELD)
	check.call(inv.available_spellcasting_hands() == 1 and not inv.has_required_spell_component(water_walk, "druid"), "A free hand with the focus only in the backpack still has no held focus (no pouch)")
	var focus_id := ""
	for record in inv.backpack_instances():
		if str(record.definition_id) == FOCUS: focus_id = str(record.instance_id)
	var shield_id := ""
	for record in inv.backpack_instances():
		if str(record.definition_id) == "shield": shield_id = str(record.instance_id)
	check.call(inv.equipment_control_equip(Inventory.Slot.WEAPON, focus_id).get("success", false) and inv.equipment_control_equip(Inventory.Slot.SHIELD, shield_id).get("success", false) and inv.has_required_spell_component(water_walk, "druid") and owned(druid) == DRUID_A, "Re-equipping the focus and Shield restores legal focus casting with the exact same owned copies")
	var plain := Character.new()
	plain.initialize("Plain Staff Druid", "human", "druid", AbilityScores.new(), "gold", {})
	plain.inventory.add_item("quarterstaff")
	plain.inventory.add_item("shield")
	plain.inventory.equip(Inventory.Slot.WEAPON, "quarterstaff")
	plain.inventory.equip(Inventory.Slot.SHIELD, "shield")
	check.call(plain.inventory.held_spellcasting_focus("druid").is_empty() and not plain.inventory.has_required_spell_component(water_walk, "druid"), "An ordinary Quarterstaff is not a focus: Quarterstaff plus Shield is refused")
	# Neutral renamed item and class: same declarations, no ID branch or registration.
	var item_probe := focus_item.duplicate(true)
	item_probe["id"] = "focus_probe_staff"
	item_probe["name"] = "Focus Probe Staff"
	DataLoader.items["focus_probe_staff"] = item_probe
	var class_probe := DataLoader.get_character_class("druid").duplicate(true)
	class_probe["id"] = "focus_probe_class"
	class_probe["starting_equipment"] = ["shield", "focus_probe_staff", "sickle"]
	DataLoader.classes["focus_probe_class"] = class_probe
	var probe := Character.new()
	probe.initialize("Focus Probe", "human", "focus_probe_class", AbilityScores.new(), "equipment", ClassProgression.default_creation_choices("focus_probe_class", "human"))
	check.call(probe.inventory.get_weapon() == "focus_probe_staff" and probe.inventory.backpack.has("sickle") and probe.inventory.has_required_spell_component(water_walk, "focus_probe_class") and not probe.inventory.has_required_spell_component(cure, "focus_probe_class"), "A neutral renamed focus item and class work through the same declarations")
	class_probe.erase("spellcasting_focus_kinds")
	check.call(not probe.inventory.has_required_spell_component(water_walk, "focus_probe_class"), "Without the class focus-kind declaration the renamed staff is only a weapon")
	DataLoader.classes.erase("focus_probe_class")
	DataLoader.items.erase("focus_probe_staff")
	var bad_item := focus_item.duplicate(true)
	bad_item["id"] = "fixture:bad_focus_kind"
	bad_item["type"] = "tool"
	var bad_class := DataLoader.get_character_class("druid").duplicate(true)
	bad_class["id"] = "fixture:bad_focus_kinds"
	bad_class["spellcasting_focus_kinds"] = "druidic"
	var errors_before: int = DataLoader._load_errors.size()
	var ok_a: bool = DataLoader._validate_content(bad_item, "item", "focus review")
	var ok_b: bool = DataLoader._validate_content(bad_class, "class", "focus review")
	var added: Array = DataLoader._load_errors.slice(errors_before)
	DataLoader._load_errors.resize(errors_before)
	check.call(not ok_a and not ok_b and added.filter(func(e): return "spellcasting_focus_kind" in str(e)).size() == 2, "The loader refuses a focus kind on a non-weapon item and a non-list class focus declaration (%s)" % str(added))
	var restored := Character.new()
	restored.from_dict(druid.to_dict())
	check.call(owned(restored) == DRUID_A and restored.inventory.get_weapon() == FOCUS and restored.inventory.has_required_spell_component(water_walk, "druid"), "Restore keeps the held focus copy and its casting role without replay")
