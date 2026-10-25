## Production data and renamed-ID checks for Conversion Batch 002.
class_name ConversionBatch002Checks
extends RefCounted

static func actor(id: String, klass: String = "wizard", level: int = 11) -> Character:
	var c := Character.new()
	var scores := AbilityScores.new()
	scores.from_dict({"STR": 12, "DEX": 12, "CON": 14, "INT": 18, "WIS": 16, "CHA": 16})
	c.initialize(id, "human", klass, scores)
	c.character_id = id
	while c.level < level: c.level_up()
	return c

static func run(check: Callable) -> void:
	var records: Array[Dictionary] = []
	for id in ["cure_wounds", "healing_word", "hold_monster", "circle_of_death"]:
		var spell := DataLoader.get_spell(id)
		check.call(not spell.is_empty() and SharedSpell.uses(spell) and SharedSpell.content_error(spell).is_empty(), "Conversion 002: %s is production-loaded shared data" % id)
		records.append(spell.duplicate(true))
	check.call(records[0].get("target_creature_type_exclusions", []).is_empty() and records[1].get("target_creature_type_exclusions", []).is_empty(), "Conversion 002: Cure Wounds and Healing Word have no imported creature-type exclusions")
	var hold := records[2]
	check.call(hold.get("level", 0) == 5 and hold.get("range", 0) == 18 and hold.get("duration_seconds", 0) == 60 and hold.get("classes", []) == ["bard", "sorcerer", "warlock", "wizard"] and hold.get("upcast", {}).get("starting_level", 0) == 5 and hold.get("upcast", {}).get("additional_targets_per_level", 0) == 1 and hold.get("repeat_save", "") == "WIS", "Conversion 002: Hold Monster matches its complete SRD level, range, duration, access, repeat save and upcast")
	var circle := records[3]
	check.call(circle.get("level", 0) == 6 and circle.get("range", 0) == 30 and circle.get("area_radius", 0) == 12 and circle.get("area_selection", {}).is_empty() and circle.get("effects", []).any(func(e): return e.get("type", "") == "area_selection" and e.get("shape", "") == "sphere" and e.get("radius", 0) == 12) and circle.get("save", "") == "CON" and circle.get("damage", "") == "8d8" and circle.get("upcast", {}).get("damage_per_level", "") == "2d8" and circle.get("material_component_cost", 0) == 500 and circle.get("material_component_item_id", "") == "black_pearl_powder_500gp", "Conversion 002: Circle of Death matches SRD range, sphere, save, damage, upcast and priced component")
	var renamed: Array[Dictionary] = []
	for spell in records:
		var copy := spell.duplicate(true)
		for key in copy.keys():
			if str(key).begins_with("_"): copy.erase(key)
		copy.id = "conversion002:" + str(copy.id)
		copy.name = "Renamed " + str(copy.name)
		renamed.append(copy)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.artifacts/conversion-batch-002"))
	var path := "res://.artifacts/conversion-batch-002/renamed-spells.json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		check.call(false, "Conversion 002: renamed JSON can be staged for the production loader")
		return
	file.store_string(JSON.stringify(renamed))
	file.close()
	DataLoader._load_json_file(path, "spell")
	check.call(DataLoader.get_load_errors().is_empty(), "Conversion 002: renamed definitions pass the production content loader")
	var caster := actor("conversion002-caster")
	caster.spell_slots["5"] = 2
	caster.spell_slots["6"] = 2
	for id in ["hold_monster", "circle_of_death"]:
		var copy := DataLoader.get_spell("conversion002:" + id)
		check.call(SharedSpell.uses(copy) and SharedSpell.content_error(copy).is_empty(), "Conversion 002: renamed %s has no ID-specific registration" % id)
		DataLoader.spells.erase(copy.id)
		DataLoader._registered_sources.get("spell", {}).erase(copy.id)
	var fiend := {"id":"conversion002-fiend", "name":"Fiend", "creature_type":"fiend", "current_hp":80, "max_hp":80, "is_alive":true, "conditions":{}, "saving_throw_bonuses":{"WIS":-100}, "ability_scores":{}}
	var renamed_hold := renamed[2]
	var held := CombatAction.resolve_spell(caster, fiend, renamed_hold, false, {}, [], 5, 30)
	var source := str(held.get("effect_cast", {}).get("source_id", ""))
	check.call(held.get("success", false) and not held.get("saved", true) and CombatAction.is_paralyzed(fiend) and not source.is_empty(), "Conversion 002: renamed Hold Monster executes its ordinary failed-save condition path")
	fiend["saving_throw_bonuses"]["WIS"] = 1000
	var repeat := CombatAction.resolve_hold_monster_repeat_save(fiend, 14, source)
	check.call(repeat.get("saved", false) and not CombatAction.is_paralyzed(fiend) and SpellEffects.records(fiend).is_empty(), "Conversion 002: renamed Hold Monster repeat success cleans its exact source")
	var cure := renamed[0]
	var healing_word := renamed[1]
	var all_types_eligible := true
	for kind in ["construct", "undead"]:
		var creature := {"id":"conversion002-%s" % kind, "name":kind.capitalize(), "creature_type":kind, "current_hp":1, "max_hp":50, "is_alive":true, "conditions":{}, "spell_effects":{}, "condition_sources":{}, "healing_suppressed":false}
		all_types_eligible = all_types_eligible and CombatAction.validate_spell_target(caster, creature, cure).get("success", false) and CombatAction.validate_spell_target(caster, creature, healing_word).get("success", false)
	check.call(all_types_eligible, "Conversion 002: both renamed healing spells accept eligible Constructs and Undead")
	var dead := actor("conversion002-dead", "fighter")
	dead.is_alive = false
	dead.current_hp = 0
	dead.death_save_failures = 3
	check.call(not SpellCastTargeting.can_target_downed(dead, cure) and not SpellCastTargeting.can_target_downed(dead, healing_word), "Conversion 002: dead creatures do not become downed healing targets")
	for spell in renamed:
		DataLoader.spells.erase(spell.id)
		DataLoader._registered_sources.get("spell", {}).erase(spell.id)
	print("CONVERSION_BATCH_002_CHECKS_COMPLETE")
