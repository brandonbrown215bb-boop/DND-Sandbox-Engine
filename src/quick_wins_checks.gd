class_name QuickWinsChecks
extends RefCounted

static func load_fixtures() -> void:
	Batch051Checks.load_fixtures()
	DataLoader._load_json_file("res://data/fixtures/quick_wins/items.json", "item")
	DataLoader._load_json_file("res://data/fixtures/quick_wins/feats.json", "feat")
	DataLoader._load_json_file("res://data/fixtures/quick_wins/spells.json", "spell")

static func target() -> Dictionary:
	return {"id":"quick_target", "name":"Quick target", "current_hp":200, "max_hp":200, "is_alive":true, "armor_class":-100, "conditions":{}, "ability_scores":{"DEX":10}}

static func run(check: Callable) -> void:
	load_fixtures()
	check.call(DataLoader.get_load_errors().is_empty(), "Quick wins fixtures load through production validation: %s" % str(DataLoader.get_load_errors()))
	_generation(check)
	_feats(check)
	_ranges(check)
	_budget(check)
	_armor(check)

static func _generation(check: Callable) -> void:
	var rolled := AbilityScores.roll_generation(123456)
	check.call(rolled == AbilityScores.roll_generation(123456) and rolled.all(func(v): return v >= 3 and v <= 18), "S242 seeded 4d6-drop-lowest is repeatable and bounded")
	var assignments := ["CHA","WIS","INT","CON","DEX","STR"]
	var receipt := {"method":"random_4d6", "seed":123456, "results":rolled, "assigned_abilities":assignments}
	var dto := {"creation_choices":{"ability_generation":receipt}}
	check.call(AbilityScores.saved_generation_error(JSON.parse_string(JSON.stringify(dto))).is_empty() and AbilityScores.assign_generation(rolled, assignments).scores.STR == rolled[5], "S242 assignment and generation receipt survive JSON without rerolling")
	var actor := Batch051Checks.fresh("quick_generation_roundtrip")
	var plain_results: Array = []
	plain_results.append_array(rolled)
	actor.creation_choices["ability_generation"] = {"method":"random_4d6", "seed":123456, "results":plain_results, "assigned_abilities":assignments.duplicate()}
	var restored := Character.new()
	restored.from_dict(JSON.parse_string(JSON.stringify(actor.to_dict())))
	check.call(restored.creation_choices == actor.creation_choices, "S242 restores integer generation metadata and equal creation choices without rerolling")
	receipt.results[0] += 1
	check.call(not AbilityScores.saved_generation_error(dto).is_empty(), "S242 altered seeded rolls are refused")
	receipt.results = AbilityScores.roll_generation(123456)
	receipt.assigned_abilities[0] = "STR"
	check.call(not AbilityScores.saved_generation_error(dto).is_empty(), "S242 duplicate score assignments are refused")

static func _feats(check: Callable) -> void:
	var c := Batch051Checks.fresh("quick_feats")
	check.call("fixture:distinct_origin|arcane" in FeatRules.options(c, "origin") and FeatRules.choose_origin(c, "fixture:distinct_origin|arcane").success, "S233 parameterized Origin feats are offered and acquired")
	while c.level < 4: c.level_up()
	check.call(FeatRules.choose_level_feat(c, "fixture:distinct_origin|divine").success and "fixture:distinct_origin|arcane" not in FeatRules.options(c, "") and "fixture:distinct_origin|primal" in FeatRules.options(c, ""), "S233 repeats permit different parameters and exclude the Origin choice")
	var dto: Dictionary = JSON.parse_string(JSON.stringify(c.to_dict()))
	check.call(ClassProgression.saved_choices_error(dto).is_empty(), "S233 distinct repeats pass saved choice validation")
	for key in dto.feature_choices:
		if dto.feature_choices[key] == ["feat:fixture:distinct_origin|divine"]: dto.feature_choices[key] = ["feat:fixture:distinct_origin|arcane"]
	check.call(not FeatRules.saved_error(dto).is_empty(), "S233 save validation rejects repeated parameter across Origin and improvement")
	check.call(FeatRules.eligibility_error(c, "fixture:trained_feat", "").is_empty(), "S233 class level and named class feature qualify together")
	var gated := Batch051Checks.fresh("quick_gate")
	check.call(not FeatRules.eligibility_error(gated, "fixture:trained_feat", "").is_empty(), "S233 total level cannot substitute for required class levels")
	FeatRules.choose_origin(gated, Batch051Checks.VIGIL)
	while gated.level < 4: gated.level_up()
	check.call(FeatRules.choose_level_feat(gated, "fixture:watch_feat").success and FeatRules.saved_error(gated.to_dict()).is_empty(), "S233 named feature from an owned feat qualifies live and after save")
	var spoof := gated.to_dict()
	spoof.origin_feat = ""
	spoof["features"] = [{"id":Batch051Checks.WATCH}]
	check.call(not FeatRules.saved_error(spoof).is_empty(), "S233 arbitrary saved feature claims cannot satisfy prerequisites")
	check.call(not FeatRules.choose_level_feat(gated, "").success and not FeatRules.choose_level_feat(gated, "|arcane").success, "S233 malformed selections refuse without crashing")

static func _ranges(check: Callable) -> void:
	var c := Batch051Checks.fresh("quick_ranges")
	c.ability_scores.dexterity = 13
	var bow := DataLoader.get_item("fixture:banded_bow")
	bow.attack_distance = 5
	var long_hit := CombatAction.resolve_weapon_attack(c, target(), bow)
	check.call(CombatAction.weapon_range_hexes(bow) == 12 and bool(long_hit.activity_roll.disadvantage), "S250 authored maximum opens targeting and long range imposes Disadvantage")
	bow.attack_distance = 13
	check.call(not CombatAction.resolve_weapon_attack(c, target(), bow).get("success", true), "S250 beyond maximum refuses before rolling")
	bow.attack_distance = 4
	c.ability_scores.dexterity = 12
	var heavy := CombatAction.resolve_weapon_attack(c, target(), bow)
	check.call(bool(heavy.activity_roll.disadvantage), "S250 Heavy ranged weapon requires DEX 13")
	c.ability_scores.dexterity = 13
	var boundary := CombatAction.resolve_weapon_attack(c, target(), bow)
	check.call(not bool(boundary.activity_roll.disadvantage), "S250 normal range and Heavy threshold are inclusive")
	var thrown := DataLoader.get_item("fixture:banded_thrower")
	thrown.attack_distance = 6
	c.ability_scores.strength = 18
	c.ability_scores.dexterity = 10
	var strength_throw := CombatAction.resolve_weapon_attack(c, target(), thrown)
	c.ability_scores.strength = 10
	c.ability_scores.dexterity = 18
	var dex_throw := CombatAction.resolve_weapon_attack(c, target(), thrown)
	check.call(strength_throw.activity_roll.modifiers.map(func(m): return m.value) == dex_throw.activity_roll.modifiers.map(func(m): return m.value), "S250 thrown finesse preserves best STR or DEX selection")
	thrown.properties = ["thrown"]
	var plain_throw := CombatAction.resolve_weapon_attack(c, target(), thrown)
	check.call(plain_throw.activity_roll.modifiers[0].label == "STR", "S250 thrown weapon without finesse keeps STR even when DEX is higher")
	var melee := {"id":"fixture:heavy_melee", "name":"Heavy Melee", "type":"weapon", "properties":["heavy"], "ability":"STR", "damage":"1d6", "damage_type":"slashing", "range":1}
	c.ability_scores.strength = 12
	var weak := CombatAction.resolve_weapon_attack(c, target(), melee)
	c.ability_scores.strength = 13
	var strong := CombatAction.resolve_weapon_attack(c, target(), melee)
	check.call(weak.activity_roll.disadvantage and not strong.activity_roll.disadvantage, "S250 melee Heavy requires STR 13 independently of DEX")

static func _budget(check: Callable) -> void:
	var c := Batch051Checks.fresh("quick_budget")
	var spell := DataLoader.get_spell("fixture:budget_light")
	var victim := target()
	var first := CombatAction.resolve_spell(c, victim, spell)
	var source := str(first.get("effect_cast", {}).get("source_id", ""))
	check.call(first.get("damage", 0) == 20 and c.spell_effects.get(source, {}).get("damage_budget_total", 0) == 20, "S272 ordinary damage-only cast retains exact budget owner")
	SpellEffects.prune(c)
	var other := CombatAction.resolve_spell(c, victim, spell)
	check.call(c.spell_effects.size() == 2 and c.spell_effects[source].damage_budget_total == 20 and other.effect_cast.source_id != source, "S272 prune retains budget and same-definition casts count separately")
	var continued := spell.duplicate(true)
	continued["_effect_cast"] = first.effect_cast
	victim["damage_resistances"] = ["radiant"]
	CombatAction.resolve_spell(c, victim, continued)
	check.call(c.spell_effects[source].damage_budget_total == 30, "S272 resistance counts final damage on the exact reused source")
	victim["damage_immunities"] = ["radiant"]
	var immune := CombatAction.resolve_spell(c, victim, continued)
	check.call(immune.get("damage", -1) == 0 and c.spell_effects[source].damage_budget_total == 30, "S272 immunity contributes zero to the source budget")
	victim.erase("damage_immunities")
	var dto: Dictionary = JSON.parse_string(JSON.stringify(c.to_dict()))
	check.call(SpellEffects.saved_state_error(dto).is_empty(), "S272 partial budget is valid checkpoint state")
	var stripped := dto.duplicate(true)
	stripped.spell_effects[source].erase("source_end_rules")
	stripped.spell_effects[source].erase("damage_budget_total")
	check.call(not SpellEffects.saved_state_error(stripped).is_empty(), "S272 removing budget fields from checkpoint is refused")
	var restored := Character.new()
	restored.from_dict(dto)
	continued._effect_cast = restored.spell_effects[source]
	victim.erase("damage_resistances")
	CombatAction.resolve_spell(restored, victim, continued)
	var last := CombatAction.resolve_spell(restored, victim, continued)
	var refused := CombatAction.resolve_spell(restored, victim, continued)
	check.call(last.get("damage", 0) == 20 and not restored.spell_effects.has(source) and restored.spell_effects.size() == 1 and not refused.get("success", true), "S272 crossing 60 at 70 deals full last hit, ends only its source, and refuses stale reuse")
	var save_spell := DataLoader.get_spell("fixture:budget_light_renamed")
	var saver := target()
	saver.ability_scores.DEX = 100
	saver["damage_resistances"] = ["radiant"]
	var saved := CombatAction.resolve_spell(c, saver, save_spell)
	check.call(saved.get("saved", false) and saved.get("damage", 0) == 5 and c.spell_effects.get(str(saved.effect_cast.source_id), {}).get("damage_budget_total", 0) == 5, "S272 successful save then resistance counts five final damage")
	var ordered_target := target()
	ordered_target.conditions = {"paralyzed":1}
	var ordered := CombatAction.resolve_spell(c, ordered_target, DataLoader.get_spell("fixture:budget_ordered"))
	check.call(ordered.get("success", false) and ordered_target.current_hp == 170 and not c.spell_effects.has(str(ordered.get("effect_cast", {}).get("source_id", ""))), "S272 crossing cap preserves both damage components of the final occurrence and skips subsequent steps")
	var benefit := CombatAction.resolve_spell(c, c, DataLoader.get_spell("fixture:budget_benefit"))
	var benefit_source := str(benefit.get("effect_cast", {}).get("source_id", ""))
	check.call(c.spell_effects.get(benefit_source, {}).has("source_benefits") and SourceBenefitRules.total(c, "AC") == 2 and SpellEffects.saved_state_error(c.to_dict()).is_empty(), "S272 budget owner composes with a source benefit without blocking its payload")
	CombatAction.resolve_damage(target(), 20, "fire", {"damage_source_instance_id":benefit_source}, false, false, c)
	check.call(not c.spell_effects.has(benefit_source) and SourceBenefitRules.total(c, "AC") == 0, "S272 budget ending removes the source benefit with its counter")
	var defender := Batch051Checks.fresh("quick_counter")
	var mirror := CombatAction.resolve_spell(defender, defender, DataLoader.get_spell("fixture:budget_mirror"))
	var mirror_source := str(mirror.get("effect_cast", {}).get("source_id", ""))
	var offense := CombatAction.resolve_spell(c, defender, DataLoader.get_spell("fixture:budget_fire"))
	check.call(not defender.spell_effects.has(mirror_source) and c.spell_effects.get(str(offense.get("effect_cast", {}).get("source_id", "")), {}).get("damage_budget_total", 0) == 20, "S272 counter-damage settles its own budget independently of deferred incoming spell packets")

static func _armor(check: Callable) -> void:
	check.call(Inventory.armor_change_seconds({"type":"armor","armor_type":"light"}, true) == 60 and Inventory.armor_change_seconds({"type":"armor","armor_type":"medium"}, true) == 300 and Inventory.armor_change_seconds({"type":"armor","armor_type":"heavy"}, true) == 600 and Inventory.armor_change_seconds({"type":"armor","armor_type":"heavy"}, false) == 300, "S252 don/doff table uses campaign seconds")
