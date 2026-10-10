## Production regressions for Cleric creation, effects, resources and reload.
class_name ClericChecks
extends RefCounted

static func character(level: int = 1) -> Character:
	var scores := AbilityScores.new()
	scores.from_dict({"STR": 14, "DEX": 12, "CON": 14, "INT": 10, "WIS": 16, "CHA": 10})
	var c := Character.new()
	c.initialize("Cleric fixture", "human", "cleric", scores)
	c.character_id = "fixture:cleric:%d" % c.get_instance_id()
	while c.level < level:
		c.level_up()
	return c


static func monster(id: String = "undead") -> Dictionary:
	return {"id": id, "name": id, "creature_type": "undead", "hex_position": Vector2i(1, 0), "is_alive": true, "current_hp": 100, "max_hp": 100, "ability_scores": {"WIS": -100, "CON": -100}, "conditions": {}}


static func run(check: Callable) -> void:
	var novice := character()
	check.call(novice.inventory.gold == 7 and novice.inventory.get_weapon() == "mace" and novice.inventory.get_armor() == "chain_shirt" and novice.inventory.count_item("holy_symbol") == 1 and novice.inventory.count_item("priests_pack") == 1, "Cleric equipment grants the SRD loadout and seven gold")
	check.call(novice.skill_proficiencies.has("History") and novice.skill_proficiencies.has("Insight") and "shield" in novice.armor_proficiencies, "Cleric defaults use legal class skills and Shield training")
	var scores := AbilityScores.new()
	scores.from_dict({"STR": 10, "DEX": 10, "CON": 10, "INT": 10, "WIS": 16, "CHA": 10})
	var choices := {"skills": ["Medicine", "Religion"], "equipment": "gold"}
	var gold := Character.new()
	gold.initialize("Gold Cleric", "human", "cleric", scores, "gold", choices)
	check.call(gold.inventory.gold == 110 and gold.inventory.backpack.is_empty() and gold.inventory.equipped.is_empty() and gold.skill_proficiencies == ["Medicine", "Religion"], "Chosen Cleric skills and the 110 GP alternative grant no class equipment")
	var malformed := gold.to_dict()
	malformed["creation_choices"]["skills"] = ["Religion", "Religion"]
	check.call(not ClassProgression.saved_choices_error(malformed).is_empty(), "Duplicate saved Cleric creation skills fail preflight")
	var restored := Character.new()
	restored.from_dict(JSON.parse_string(JSON.stringify(gold.to_dict())))
	check.call(restored.creation_choices == choices and restored.inventory.gold == 110 and restored.inventory.backpack.is_empty() and restored.inventory.equipped.is_empty(), "Cleric reload keeps chosen skills and cash without replaying equipment")
	var legacy := gold.to_dict()
	legacy.erase("creation_choices")
	legacy.erase("tool_proficiencies")
	restored.from_dict(legacy)
	check.call(restored.creation_choices.is_empty() and restored.inventory.gold == 110 and restored.inventory.backpack.is_empty() and restored.inventory.equipped.is_empty(), "Earlier Cleric saves retain their inventory and skills without retroactive grants")
	var prepared: Array[String] = novice.get_spell_option_ids(true).slice(0, 3)
	prepared.append_array(novice.get_spell_option_ids(false).slice(0, 4))
	check.call(ClassProgression.choose_spell_selection(novice, prepared), "Initial Cleric training chooses the supported cantrips and four prepared spells")
	var changed: Array[String] = prepared.duplicate()
	changed[3] = novice.get_spell_option_ids(false)[4]
	changed[4] = novice.get_spell_option_ids(false)[5]
	check.call(not ClassProgression.choose_spell_selection(novice, changed), "Cleric cannot change prepared spells before a Long Rest")
	novice.long_rest()
	check.call(ClassProgression.choose_spell_selection(novice, changed), "Long Rest permits replacing several prepared Cleric spells together")
	novice.long_rest()
	var swapped: Array[String] = changed.duplicate()
	swapped[0] = novice.get_spell_option_ids(true)[3]
	check.call(not ClassProgression.choose_spell_selection(novice, swapped), "Long Rest does not grant a cantrip replacement")
	novice.level_up()
	check.call(novice.cleric_cantrip_replacement_available, "A Cleric level grants one cantrip replacement opportunity")
	var training_dto := novice.to_dict()
	training_dto["cleric_preparation_free_change"] = "yes"
	check.call(not ClassProgression.saved_choices_error(training_dto).is_empty(), "Malformed Cleric preparation permission fails save preflight")
	ClassProgression.choose_feature_option(novice, "cleric_divine_order", "thaumaturge")
	check.call(novice.get_ability_check_bonus("Religion", "INT") == 3 and novice.get_ability_check_bonus("Religion", "STR") == 0, "Thaumaturge applies its bonus only to Intelligence Arcana or Religion checks")
	var cleric := character(18)
	cleric.feature_uses["cleric_channel_divinity"] = 0
	cleric.short_rest()
	check.call(cleric.feature_uses["cleric_channel_divinity"] == 1, "Short Rest restores one Channel Divinity use")
	cleric.long_rest()
	check.call(cleric.feature_uses["cleric_channel_divinity"] == 4, "Long Rest restores all four level-18 uses")
	var downed := character()
	downed.current_hp = 0
	downed.is_alive = false
	var spark := ClericRules.resolve_divine_spark(cleric, downed, "heal")
	check.call(spark.get("success", false) and downed.current_hp > 0 and downed.is_alive, "Divine Spark restores a downed creature with failed death saves below three")
	downed.is_alive = false
	downed.death_save_failures = 3
	check.call(not ClericRules.resolve_divine_spark(cleric, downed, "heal").get("success", true), "Divine Spark cannot resurrect a dead creature")
	var first := monster("first")
	var second := monster("second")
	ClericRules.resolve_turn_undead(cleric, [first, second], Vector2i.ZERO, ["first"], false)
	check.call(first.current_hp == 100 and first.conditions.has("incapacitated") and second.conditions.is_empty(), "Turn Undead respects selected creatures and declining Sear")
	var other := character(5)
	ClericRules.resolve_turn_undead(other, [first], Vector2i.ZERO, ["first"], false)
	CombatAction.apply_condition(first, "frightened", 2)
	cleric.add_condition("stunned", 2)
	ClericRules.reconcile_turning([first], [{"character": cleric, "hex_position": Vector2i.ZERO}, {"character": other, "hex_position": Vector2i(2, 0)}])
	check.call(first.turn_undead_casters.size() == 1 and first.turn_undead_origin == Vector2i(2, 0) and first.conditions.has("incapacitated"), "Incapacitating one turning caster preserves the other caster and follows its current position")
	other.is_alive = false
	ClericRules.reconcile_turning([first], [{"character": other}])
	check.call(not first.has("turn_undead_origin") and not first.conditions.has("incapacitated") and first.conditions.get("frightened", 0) == 2, "Caster death releases its turning while preserving ordinary fear")
	var seared := monster("seared")
	ClericRules.resolve_turn_undead(other, [seared], Vector2i.ZERO, ["seared"], true)
	check.call(seared.current_hp < 100 and seared.conditions.has("incapacitated"), "Sear deals Radiant damage without ending its turning")
	CombatAction.resolve_damage(seared, 1, "force")
	check.call(not seared.has("turn_undead_origin") and seared.conditions.is_empty(), "Subsequent ordinary damage ends all turning grants")
	var expired := monster("expired")
	ClericRules.resolve_turn_undead(cleric, [expired], Vector2i.ZERO, ["expired"], false)
	for turn in 10:
		CombatState.tick_monster_condition_durations(expired)
	ClericRules.reconcile_turning([expired], [{"character": cleric}])
	check.call(expired.conditions.is_empty() and not expired.has("turn_undead_origin"), "Turning expires through the combat condition clock")
	var strike := character(14)
	ClassProgression.choose_feature_option(strike, "cleric_blessed_strikes", "divine_strike")
	check.call(ClericRules.channel_divinity_error(gold).contains("Holy Symbol"), "A gold-start Cleric needs to acquire a Holy Symbol before Channel Divinity")
	var target := monster("strike")
	CombatAction.advance_combat_turn(strike)
	check.call(CombatAction.resolve_weapon_damage_riders(strike, target).is_empty(), "Declining Divine Strike leaves its use unspent")
	var rider := CombatAction.resolve_weapon_damage_riders(strike, target, {"divine_strike": "necrotic"})
	check.call(rider.size() == 1 and rider[0].formula == "2d8" and rider[0].damage_type == "necrotic", "Improved Divine Strike chooses Necrotic damage and scales to two dice")
	check.call(CombatAction.resolve_weapon_damage_riders(strike, target, {"divine_strike": "radiant"}).is_empty(), "An accepted Divine Strike spends its once-per-turn use")
	strike.feature_uses.erase("divine_strike_cleric_used_this_turn")
	CombatAction.advance_combat_turn(novice)
	check.call(CombatAction.resolve_weapon_damage_riders(strike, target, {"divine_strike": "radiant"}).is_empty(), "Off-turn hits cannot use Divine Strike")
	CombatAction.advance_combat_turn(strike)
	var critical := CombatAction.resolve_weapon_damage_riders(strike, target, {"divine_strike": "radiant"}, {}, true)
	check.call(critical.size() == 1 and critical[0].formula == "4d8", "Critical Divine Strike doubles its extra damage dice")
	var potent := character(14)
	ClassProgression.choose_feature_option(potent, "cleric_blessed_strikes", "potent_spellcasting")
	var flame := DataLoader.get_spell("sacred_flame")
	check.call(CombatAction.resolve_spell_cast_riders(potent, flame, "magic_action", 0, novice).is_empty() and CombatAction.resolve_spell_cast_riders(potent, DataLoader.get_spell("guidance"), "magic_action", 0, novice).is_empty(), "Nondamaging or saved cantrips do not grant vitality")
	CombatAction.resolve_spell_cast_riders(potent, flame, "bonus_action", 1, novice)
	check.call(novice.temp_hp == 6 and potent.temp_hp == 0, "Damaging Cleric cantrips can grant vitality to another creature even outside a Magic action")
	novice.temp_hp = 20
	CombatAction.resolve_spell_cast_riders(potent, flame, "magic_action", 1, novice)
	check.call(novice.temp_hp == 20, "Vitality never replaces a larger temporary HP pool")
	CombatAction.resolve_spell_cast_riders(potent, flame, "magic_action", 1, target)
	var hp_before := int(target.current_hp)
	CombatAction.resolve_damage(target, 5, "force")
	check.call(target.current_hp == hp_before and target.temp_hp == 1, "Creature vitality absorbs damage through the shared resolver")
	var greater := character(20)
	check.call(not ClericRules.wish_duplication_spell_options().any(func(spell): return str(spell.get("id", "")) in ["find_steed", "divine_smite"]), "Wish hides spells whose current resolver requires Paladin-owned state")
	var rests := ClericRules.apply_greater_intervention_cooldown(greater, "wish")
	var dto := JSON.parse_string(JSON.stringify(greater.to_dict())) as Dictionary
	check.call(ClericRules.saved_state_error(dto).is_empty() and rests >= 2 and rests <= 8, "Greater Divine Intervention saves a bounded rolled cooldown")
	restored.from_dict(dto)
	for rest in rests - 1:
		restored.long_rest()
	check.call(int(restored.feature_uses["cleric_divine_intervention"]) == 0, "Reloaded Wish cooldown survives every Long Rest before its last")
	restored.long_rest()
	check.call(int(restored.feature_uses["cleric_divine_intervention"]) == 1, "The final Long Rest restores Divine Intervention")
	for bad in [-1, 9, 1.5, "two", true]:
		dto["feature_uses"]["cleric_divine_intervention_recovery_rests"] = bad
		check.call(not ClassProgression.saved_choices_error(dto).is_empty(), "Invalid Wish cooldown fails preflight: %s" % str(bad))
	CombatAction.active_turn_actor_id = 0
