## Real catalog conversions and the gaps discovered by the first mixed batch.
class_name ConversionBatch001Checks
extends RefCounted

static func actor(id: String, klass: String = "cleric", level: int = 1) -> Character:
	var c := Character.new()
	var scores := AbilityScores.new()
	scores.from_dict({"STR": 12, "DEX": 12, "CON": 14, "INT": 16, "WIS": 16, "CHA": 16})
	c.initialize(id, "human", klass, scores)
	c.character_id = id
	while c.level < level: c.level_up()
	return c

static func run(check: Callable) -> void:
	var renamed_definitions: Array = []
	for id in ["bless", "bane", "mass_healing_word"]:
		var definition := DataLoader.get_spell(id).duplicate(true)
		for key in definition.keys():
			if str(key).begins_with("_"): definition.erase(key)
		definition.id = "conversion001:" + id
		definition.name = "Renamed " + str(definition.name)
		renamed_definitions.append(definition)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.artifacts/conversion-batch-001"))
	var path := "res://.artifacts/conversion-batch-001/renamed-spells.json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		check.call(false, "Conversion 001: renamed JSON can be staged for the production loader")
		return
	file.store_string(JSON.stringify(renamed_definitions))
	file.close()
	DataLoader._load_json_file(path, "spell")
	check.call(DataLoader.get_load_errors().is_empty(), "Conversion 001: renamed JSON passes the production content loader")
	for id in ["bless", "bane", "mass_healing_word"]:
		var spell := DataLoader.get_spell(id)
		check.call(SharedSpell.uses(spell) and SharedSpell.content_error(spell).is_empty(), "Conversion 001: %s is executable shared data" % id)
		var renamed := DataLoader.get_spell("conversion001:" + id)
		var caster := actor("conversion-caster-" + id)
		var recipient := actor("conversion-recipient-" + id, "fighter")
		recipient.max_hp = 100
		recipient.current_hp = 1
		recipient.ability_scores.charisma = -100
		var result := CombatAction.resolve_spell(caster, recipient, renamed, false, {}, [], int(spell.level), 5)
		check.call(bool(result.get("success", false)) and (recipient.current_hp > 1 if id == "mass_healing_word" else recipient.has_condition("blessed" if id == "bless" else "baned")), "Conversion 001: renamed %s resolves without ID registration" % id)
		if id != "mass_healing_word":
			var source := str(result.get("effect_cast", {}).get("source_id", ""))
			check.call(not source.is_empty() and SpellEffects.records(recipient).size() == 1, "Conversion 001: %s applies one source, without a native second grant" % id)
			SpellEffects.remove(recipient, source)
		DataLoader.spells.erase(renamed.id)
		DataLoader._registered_sources.get("spell", {}).erase(renamed.id)
	_death_saves(check)
	_sources(check)
	_class_consumers(check)
	print("CONVERSION_BATCH_001_CHECKS_COMPLETE")

static func _death_saves(check: Callable) -> void:
	for natural in [1, 9, 20]:
		var c := actor("conversion-death-%d" % natural, "fighter")
		c.current_hp = 0
		c.is_alive = false
		c.add_condition("blessed", 10, "conversion-bless")
		FighterChecks._seed_die(20, natural)
		var result := c.make_death_save()
		check.call(int(result.get("bless_bonus", 0)) in range(1, 5) and int(result.total) == natural + int(result.get("bless_bonus", 0)), "Conversion 001: Bless reaches Death Save %d exactly once" % natural)
		check.call(c.death_save_failures == 2 if natural == 1 else c.current_hp == 1 if natural == 20 else c.death_save_successes == 1, "Conversion 001: Bless preserves natural-1/20 rules and can turn nine into success")
	var both := actor("conversion-both", "fighter")
	both.current_hp = 0
	both.is_alive = false
	both.add_condition("blessed", 10)
	both.add_condition("baned", 10)
	FighterChecks._seed_die(20, 10)
	var mixed := both.make_death_save()
	check.call(int(mixed.total) == int(mixed.natural) + int(mixed.get("bless_bonus", 0)) - int(mixed.bane_penalty), "Conversion 001: Bless and Bane both modify a Death Save")
	var veteran := actor("conversion-veteran", "fighter", 9)
	veteran.current_hp = 0
	veteran.is_alive = false
	veteran.add_condition("blessed", 10)
	var uses := int(veteran.feature_uses.fighter_indomitable)
	FighterChecks._seed_die(20, 9)
	var converted := veteran.make_death_save()
	check.call(int(converted.natural) == 9 and veteran.death_save_successes == 1 and int(veteran.feature_uses.fighter_indomitable) == uses, "Conversion 001: a Bless-converted Death Save success does not spend Indomitable")
	veteran.death_save_successes = 0
	FighterChecks._seed_die(20, 1)
	var rerolled := veteran.make_death_save()
	check.call(int(veteran.feature_uses.fighter_indomitable) == uses - 1 and int(rerolled.total) == int(rerolled.natural) + 9 + int(rerolled.bless_bonus), "Conversion 001: an Indomitable reroll applies only its final Bless die and Fighter bonus")
	randomize()

static func _sources(check: Callable) -> void:
	var first := actor("conversion-first")
	var second := actor("conversion-second")
	var target := actor("conversion-overlap", "fighter")
	var a := SpellEffects.begin_cast(first, DataLoader.get_spell("bless"))
	var b := SpellEffects.begin_cast(second, DataLoader.get_spell("bless"))
	SpellEffects.grant(target, a, "blessed")
	SpellEffects.grant(target, b, "blessed")
	check.call(target.condition_sources.get("blessed", {}).size() == 2, "Conversion 001: overlapping Bless retains two independent sources")
	seed(771)
	var two_sources := target.make_attack_roll()
	SpellEffects.remove(target, str(a.source_id))
	seed(771)
	var one_source := target.make_attack_roll()
	check.call(int(two_sources.total) == int(one_source.total), "Conversion 001: overlapping Bless does not add a second attack bonus die")
	check.call(target.has_condition("blessed") and SpellEffects.records(target).has(b.source_id), "Conversion 001: ending one Bless retains its sibling")
	SpellEffects.advance_time([target], 60)
	check.call(not target.has_condition("blessed"), "Conversion 001: the surviving Bless expires at its deadline")
	var failed := {"id": "conversion-failed", "name": "Failed", "is_alive": true, "current_hp": 10, "max_hp": 10, "conditions": {}, "saving_throw_bonuses": {"CHA": -1000}}
	var saved := failed.duplicate(true)
	saved.id = "conversion-saved"
	saved.saving_throw_bonuses.CHA = 1000
	var bane := DataLoader.get_spell("bane")
	check.call(not CombatAction.resolve_spell(first, failed, bane, false, {}, [], 2, 5).get("saved", true) and CombatAction.has_condition(failed, "baned"), "Conversion 001: failed Bane save grants its penalty")
	check.call(CombatAction.resolve_spell(first, saved, bane, false, {}, [], 2, 5).get("saved", false) and not CombatAction.has_condition(saved, "baned"), "Conversion 001: successful Bane save gets no penalty")

static func _class_consumers(check: Callable) -> void:
	var barbarian := actor("conversion-barbarian", "barbarian", 4)
	check.call(not barbarian.has_feature("barbarian_fast_movement") and barbarian.get_speed() == barbarian.speed, "Conversion 001: Fast Movement is absent before level five")
	barbarian.level_up()
	var feature := barbarian.get_feature("barbarian_fast_movement")
	feature.id = "conversion001:fast_movement"
	check.call(barbarian.get_speed() == barbarian.speed + 2, "Conversion 001: renamed Fast Movement remains data-driven")
	barbarian.inventory.equip(Inventory.Slot.BODY, "chain_mail", true)
	check.call(barbarian.get_speed() == barbarian.speed, "Conversion 001: Heavy Armor suppresses the actual Fast Movement bonus")
	barbarian.inventory.unequip(Inventory.Slot.BODY)
	check.call(barbarian.get_speed() == barbarian.speed + 2, "Conversion 001: removing Heavy Armor restores Fast Movement")
	var fighter := actor("conversion-fighter", "fighter", 5)
	fighter.max_hp = 100
	fighter.current_hp = 1
	var budget := CombatTurnBudget.new()
	budget.reset(fighter, [])
	var before := int(fighter.feature_uses.fighter_second_wind)
	var result := ClassFeature.execute(fighter, fighter.get_feature("fighter_second_wind"), null, budget)
	check.call(result.get("success", false) and fighter.current_hp in range(7, 17) and int(fighter.feature_uses.fighter_second_wind) == before - 1 and not budget.bonus_action_available, "Conversion 001: real Second Wind uses the common executor and its original budget/resource")
	fighter.feature_uses.fighter_second_wind = 1
	FighterChecks._seed_die(10, 10)
	var mind := FighterRules.tactical_mind(fighter, 9, 15)
	check.call(mind.spent and int(fighter.feature_uses.fighter_second_wind) == 0, "Conversion 001: Tactical Mind spends that same Second Wind resource")
	fighter.short_rest()
	check.call(int(fighter.feature_uses.fighter_second_wind) == 1, "Conversion 001: Short Rest restores one Second Wind use")
	fighter.long_rest()
	check.call(int(fighter.feature_uses.fighter_second_wind) == fighter.get_feature_max_uses("fighter_second_wind"), "Conversion 001: Long Rest fills the original Second Wind resource")
	randomize()
