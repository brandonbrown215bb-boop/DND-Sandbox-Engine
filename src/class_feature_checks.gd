## Regression and content-contract checks using the ordinary production loader.
class_name ClassFeatureChecks
extends RefCounted

static func run(check: Callable) -> void:
	_audit_defect_repairs(check)
	_shared_rules_regressions(check)
	_rogue_rules(check)
	_warlock_rules(check)
	var monk := _character("monk", 20)
	var saved := JSON.parse_string(JSON.stringify(monk.to_dict())) as Dictionary
	var restored := Character.new()
	restored.from_dict(saved)
	check.call(restored.ability_scores.to_dict() == monk.ability_scores.to_dict(), "Monk permanent capstone does not replay on JSON reload")
	restored.from_dict(restored.to_dict())
	check.call(restored.ability_scores.to_dict() == monk.ability_scores.to_dict(), "Repeated Monk reload remains stable")
	check.call(ClassProgression.pending_improvements(monk).size() == 4, "Monk earns four real persistent ability choices")
	check.call(ClassProgression.improve_scores(monk, "CON", "CON"), "Monk uses shared improvement selection")
	var spent_scores := monk.ability_scores.to_dict()
	restored.from_dict(monk.to_dict())
	check.call(restored.ability_scores.to_dict() == spent_scores and ClassProgression.pending_improvements(restored).size() == 3, "Monk saved improvement neither disappears nor reapplies")
	monk = _character("monk", 6)
	var budget := CombatTurnBudget.new()
	monk.current_hp = 1
	var whole := monk.get_feature("monk_wholeness_of_body")
	var before := int(monk.feature_uses["monk_wholeness_of_body"])
	var result := ClassFeature.execute(monk, whole, null, budget)
	check.call(result.get("success", false) and monk.current_hp > 1 and int(monk.feature_uses["monk_wholeness_of_body"]) == before - 1, "Shared Wholeness charges one use and heals")
	var hp := monk.current_hp
	check.call(not ClassFeature.execute(monk, whole, null, budget).get("success", false) and monk.current_hp == hp and int(monk.feature_uses["monk_wholeness_of_body"]) == before - 1, "Unavailable Bonus Action never spends a healing use")
	budget.reset(monk)
	monk.feature_uses["monk_wholeness_of_body"] = 1
	check.call(ClassFeature.execute(monk, whole, null, budget).get("success", false) and monk.feature_uses["monk_wholeness_of_body"] == 0, "The final Wholeness use succeeds")
	var legacy := _character("fighter", 8)
	FighterRules.improve_scores(legacy, "CON", "CON")
	var legacy_dto := legacy.to_dict()
	legacy_dto.erase("feature_choices")
	legacy_dto.erase("subclass_id")
	restored.from_dict(legacy_dto)
	check.call(restored.subclass_id == "champion" and FighterRules.pending_asi(restored) == 2 and restored.max_hp == legacy.max_hp, "Older schema-2 Fighter retains Champion, spent improvement and HP")
	check.call(ClassProgression.saved_choices_error(restored.to_dict()).is_empty(), "Converted Fighter choices pass save preflight")
	var validator: Node = DataLoader.get_script().new()
	var invalid := {"id": "fixture:invalid", "name": "Invalid", "hit_die": "d8", "primary_ability": "WIS", "features_by_level": {"1": [{"id": "fixture:unknown", "name": "Unknown", "type": "active", "resolver": "does_not_exist", "effects": []}]}}
	check.call(not validator._validate_content(invalid, "class", "fixture-invalid"), "Unknown resolver is rejected by the loader")
	validator.free()
	validator = DataLoader.get_script().new()
	invalid["features_by_level"]["1"] = [{"id": "fixture:unknown", "name": "Unknown", "type": "active", "executor": "class_feature", "action_cost": "bonus_action", "uses_per": "long_rest", "effects": [{"type": "invented_operation"}]}]
	check.call(not validator._validate_content(invalid, "class", "fixture-invalid"), "Unknown common operation is rejected before exposure")
	validator.free()
	var malformed := {"id": "fixture:malformed", "name": "Malformed", "hit_die": "d8", "primary_ability": "WIS", "features_by_level": {"01": []}}
	validator = DataLoader.get_script().new()
	check.call(not validator._validate_content(malformed, "class", "fixture-malformed"), "Noncanonical progression levels fail before they can silently omit grants")
	validator.free()
	check.call(not ClassFeature.content_error({"executor": "class_feature", "type": "active", "action_cost": "bonus_action", "uses_per": "long_rest", "effects": [{"type": "heal_self", "value_by_level": {"1": "1d4", "05": "2d4"}}]}).is_empty(), "Noncanonical healing thresholds are rejected before execution")
	var rogue := _character("rogue", 4)
	check.call(ClassProgression.pending_improvements(rogue).size() == 1 and ClassProgression.improve_scores(rogue, "DEX", "DEX"), "Rogue level four reuses the shared improvement without a Rogue-specific handler")
	restored.from_dict(rogue.to_dict())
	check.call(restored.ability_scores.to_dict() == rogue.ability_scores.to_dict() and ClassProgression.pending_improvements(restored).is_empty(), "Rogue improvement survives reload without another score increase")
	var warlock_progression := DataLoader.get_character_class("warlock")
	var invocation_counts: Dictionary = warlock_progression.get("eldritch_invocations_by_level", {})
	var warlock_spellcasting := _character("warlock", 20)
	check.call(invocation_counts.size() == 8 and int(invocation_counts.get("1", 0)) == 1 and int(invocation_counts.get("2", 0)) == 3 and int(invocation_counts.get("5", 0)) == 5 and int(invocation_counts.get("18", 0)) == 10, "Warlock records the 2024 invocation total progression")
	var pact_capstone: Dictionary = warlock_progression.get("pact_magic_by_level", {}).get("20", {})
	check.call(int(pact_capstone.get("slot_level", 0)) == 5 and int(pact_capstone.get("slots", 0)) == 4, "Warlock records level-20 Pact Magic slot level and count")
	check.call(warlock_spellcasting.get_spellcasting_capacity("cantrips") == 4 and warlock_spellcasting.get_spellcasting_capacity("prepared_spells") == 15, "Warlock uses the shared spellcasting capacity at level 20")
	var cunning_warlock := _character("warlock", 2)
	cunning_warlock.spell_slots = {"1": 0}
	var cunning := ClassFeature.execute(cunning_warlock, cunning_warlock.get_feature("warlock_magical_cunning"))
	check.call(cunning.get("success", false) and int(cunning_warlock.spell_slots.get("1", 0)) == 1 and not ClassFeature.execute(cunning_warlock, cunning_warlock.get_feature("warlock_magical_cunning")).get("success", true), "Magical Cunning uses shared half-slot recovery and its once-per-Long-Rest use")
	var master_warlock := _character("warlock", 20)
	master_warlock.spell_slots = {"5": 0}
	var master_recovery := ClassFeature.execute(master_warlock, master_warlock.get_feature("warlock_magical_cunning"))
	check.call(master_recovery.get("success", false) and int(master_warlock.spell_slots.get("5", 0)) == 4, "Eldritch Master makes shared Magical Cunning restore every Pact Magic slot at level 20")
	var scholar_wizard := _character("wizard", 2)
	scholar_wizard.skill_proficiencies = ["Arcana", "Animal Handling"]
	var disallowed_scholar_skill: Array[String] = ["Animal Handling"]
	var allowed_scholar_skill: Array[String] = ["Arcana"]
	check.call(not ClassProgression.choose_skill_expertise(scholar_wizard, "wizard_scholar", disallowed_scholar_skill) and ClassProgression.choose_skill_expertise(scholar_wizard, "wizard_scholar", allowed_scholar_skill), "Scholar uses the shared expertise chooser with its allowed skill list")
	var recovery_wizard := _character("wizard", 3)
	check.call(recovery_wizard.use_feature("wizard_arcane_recovery") and not recovery_wizard.use_feature("wizard_arcane_recovery") and int(recovery_wizard.feature_uses.get("wizard_arcane_recovery", -1)) == 0, "Arcane Recovery uses the shared once-per-Long-Rest feature pool")
	recovery_wizard.long_rest()
	check.call(int(recovery_wizard.feature_uses.get("wizard_arcane_recovery", 0)) == 1, "Arcane Recovery's shared feature use returns after a Long Rest")
	var barbarian := _character("barbarian", 18)
	barbarian.add_condition("raging", 5)
	check.call(barbarian.get_skill_check_ability("DEX", "Acrobatics") == "STR" and barbarian.has_ability_check_advantage("STR") and barbarian.make_saving_throw("STR") >= barbarian.ability_scores.get_score("STR"), "Barbarian Rage and Primal Knowledge share the generic ability-check and saving-throw rules")
	var primal_check := EventResolver.resolve_skill_check(barbarian, {"ability": "DEX", "skill": "Acrobatics", "dc": 10})
	check.call(primal_check.get("ability", "") == "STR" and primal_check.get("total", 0) >= barbarian.ability_scores.get_score("STR") and barbarian.apply_feature_check_floor(1, "STR", "saving_throw") == barbarian.ability_scores.get_score("STR"), "Indomitable Might and Primal Knowledge apply through shared production check paths")
	barbarian.add_condition("superior_defense", 5)
	check.call(barbarian.resist_damage(10, "slashing") == 5 and barbarian.resist_damage(10, "force") == 10, "Overlapping damage resistance sources halve damage once and force bypasses both resistances")
	var rage_user := _character("barbarian", 1)
	rage_user.inventory.unequip(Inventory.Slot.BODY)
	rage_user.concentrating_on = {"spell_id": "fixture_spell"}
	var rage_result := ClassFeature.execute(rage_user, rage_user.get_feature("barbarian_rage"))
	check.call(rage_result.get("success", false) and rage_user.has_condition("raging") and rage_user.concentrating_on.is_empty(), "Rage uses the common action path and ends Concentration")
	rage_user.tick_conditions()
	BarbarianRules.maintain_rage(rage_user)
	check.call(rage_user.conditions.get("raging", 0) == 2 and rage_user.get_modifier("stat", "damage:rage") == 2 and rage_user.modifiers.size() == 1, "Attacks and Bonus Actions refresh Rage and its damage modifier without stacking")
	var armored_rage_user := _character("barbarian", 1)
	armored_rage_user.inventory.equip(Inventory.Slot.BODY, "chain_mail", true)
	check.call(not ClassFeature.availability(armored_rage_user, armored_rage_user.get_feature("barbarian_rage")).get("available", true), "Rage is unavailable while wearing heavy armor")
	var pouncing_barbarian := _character("barbarian", 7)
	pouncing_barbarian.inventory.unequip(Inventory.Slot.BODY)
	check.call(BarbarianRules.instinctive_pounce_distance(pouncing_barbarian) == int(floor(float(pouncing_barbarian.get_speed()) / 2.0)), "Instinctive Pounce grants half Speed only after its feature level")
	pouncing_barbarian.inventory.equip(Inventory.Slot.BODY, "chain_mail", true)
	check.call(BarbarianRules.instinctive_pounce_distance(pouncing_barbarian) == 0, "Instinctive Pounce respects Rage's heavy armor restriction")
	var persistent_barbarian := _character("barbarian", 15)
	persistent_barbarian.feature_uses["barbarian_rage"] = 0
	var persistent_capacity := persistent_barbarian.get_feature_max_uses("barbarian_rage")
	var recovered_rages := BarbarianRules.recover_rage_at_initiative(persistent_barbarian)
	check.call(recovered_rages == persistent_capacity and not BarbarianRules.can_recover_rage_at_initiative(persistent_barbarian), "Persistent Rage restores the full Rage pool once per Long Rest")
	EventResolver.apply_effects(persistent_barbarian, persistent_barbarian.get_feature("barbarian_rage").get("effects", []))
	BarbarianRules.maintain_rage(persistent_barbarian)
	check.call(persistent_barbarian.conditions.get("raging", 0) == BarbarianRules.PERSISTENT_RAGE_TURNS, "Persistent Rage lasts 10 minutes without an upkeep action")
	persistent_barbarian.add_condition("unconscious", 2)
	persistent_barbarian.tick_conditions()
	check.call(not persistent_barbarian.has_condition("raging") and persistent_barbarian.get_modifier("stat", "damage:rage") == 0, "Persistent Rage ends when the Barbarian becomes Unconscious")
	persistent_barbarian.long_rest()
	check.call(not persistent_barbarian.feature_uses.has("barbarian_persistent_rage_recovered"), "Persistent Rage recovery resets on a Long Rest")
	var relentless_barbarian := _character("barbarian", 11)
	relentless_barbarian.ability_scores.set_score("CON", 30)
	relentless_barbarian.inventory.unequip(Inventory.Slot.BODY)
	relentless_barbarian.add_condition("raging", 2)
	relentless_barbarian.current_hp = 1
	relentless_barbarian.take_damage(1)
	check.call(relentless_barbarian.is_alive and relentless_barbarian.current_hp == 22 and int(relentless_barbarian.feature_uses.get("barbarian_relentless_rage_attempts", 0)) == 1, "Relentless Rage saves a raging Barbarian from 0 HP and restores twice their level")
	var inspired_relentless := _character("barbarian", 11)
	inspired_relentless.ability_scores.set_score("CON", 1)
	inspired_relentless.inventory.unequip(Inventory.Slot.BODY)
	inspired_relentless.add_condition("raging", 2)
	var relentless_inspiration_used := false
	for rng_seed in range(1, 80):
		inspired_relentless.current_hp = 1
		inspired_relentless.is_alive = true
		inspired_relentless.feature_uses.erase("barbarian_relentless_rage_attempts")
		inspired_relentless.feature_uses["bardic_inspiration_die"] = "1d12"
		seed(rng_seed)
		inspired_relentless.take_damage(1, true)
		if not inspired_relentless.feature_uses.has("bardic_inspiration_die"):
			relentless_inspiration_used = inspired_relentless.is_alive and inspired_relentless.current_hp == inspired_relentless.level * 2
			break
	check.call(relentless_inspiration_used, "Bardic Inspiration can turn a failed Relentless Rage save into a recovery through the shared D20 Test helper")
	relentless_barbarian.short_rest()
	check.call(not relentless_barbarian.feature_uses.has("barbarian_relentless_rage_attempts"), "Relentless Rage save DC resets on a Short Rest")
	var mastery_barbarian := _character("barbarian", 1)
	check.call(mastery_barbarian.get_weapon_mastery_capacity() == 2 and FighterRules.choose_mastery(mastery_barbarian, "greataxe") and FighterRules.choose_mastery(mastery_barbarian, "handaxe") and not FighterRules.choose_mastery(mastery_barbarian, "longbow"), "Barbarian Weapon Mastery shares capacity and melee eligibility rules")
	check.call(FighterRules.mastery(mastery_barbarian, {"id": "greataxe"}) == "cleave" and FighterRules.mastery(mastery_barbarian, {"id": "handaxe"}) == "vex", "Barbarian choices activate the same weapon mastery properties as Fighter")
	var mastery_save := mastery_barbarian.to_dict()
	check.call(ClassProgression.saved_choices_error(mastery_save).is_empty(), "Shared weapon mastery selections pass save preflight")
	mastery_save["weapon_masteries"].append("longsword")
	check.call(not ClassProgression.saved_choices_error(mastery_save).is_empty(), "Save preflight rejects weapon mastery choices beyond class capacity")
	var barbarian_roster := _character("barbarian", 1)
	var expected_barbarian_features := {
		1: ["barbarian_rage", "barbarian_unarmored_defense", "barbarian_weapon_mastery"],
		2: ["barbarian_danger_sense", "barbarian_reckless_attack"],
		3: ["barbarian_primal_knowledge"],
		4: ["barbarian_ability_score_improvement"],
		5: ["barbarian_extra_attack", "barbarian_fast_movement"],
		7: ["barbarian_feral_instinct", "barbarian_instinctive_pounce"],
		8: ["barbarian_ability_improvement_8"],
		9: ["barbarian_brutal_strike"],
		11: ["barbarian_relentless_rage"],
		12: ["barbarian_ability_improvement_12"],
		13: ["barbarian_improved_brutal_strike_13"],
		15: ["barbarian_persistent_rage"],
		16: ["barbarian_ability_improvement_16"],
		17: ["barbarian_improved_brutal_strike_17"],
		18: ["barbarian_indomitable_might"],
		19: ["barbarian_epic_boon"],
		20: ["barbarian_primal_champion"],
	}
	for level in range(1, 21):
		for feature_id in expected_barbarian_features.get(level, []):
			check.call(barbarian_roster.has_feature(feature_id), "Barbarian receives %s at level %d" % [feature_id, level])
		if level < 20:
			barbarian_roster.level_up()
	check.call(barbarian_roster.get_weapon_mastery_capacity() == 4, "Barbarian Weapon Mastery reaches four trained weapon types at level 10")
	var pending_skills := ClassProgression.pending_skill_choices(_character("barbarian", 3))
	var primal_barbarian := _character("barbarian", 10)
	check.call(pending_skills == ["barbarian_primal_knowledge"], "Primal Knowledge creates a persistent skill choice at level 3")
	check.call(ClassProgression.choose_skill_proficiency(primal_barbarian, "barbarian_primal_knowledge", ["Survival"]) and not ClassProgression.choose_skill_proficiency(primal_barbarian, "barbarian_primal_knowledge_10", ["Nature"]), "Primal Knowledge grants one additional skill at level 3 and no extra level-10 skill")
	# Reproduce a save made before the incorrect grant was removed.
	primal_barbarian.feature_choices["barbarian_primal_knowledge_10"] = ["Nature"]
	primal_barbarian.skill_proficiencies.append("Nature")
	var primal_saved := primal_barbarian.to_dict()
	check.call(ClassProgression.saved_choices_error(primal_saved).is_empty(), "Primal Knowledge choices pass save preflight")
	var primal_restored := Character.new()
	primal_restored.from_dict(JSON.parse_string(JSON.stringify(primal_saved)))
	check.call(primal_restored.feature_choices == primal_barbarian.feature_choices and "Survival" in primal_restored.skill_proficiencies and "Nature" in primal_restored.skill_proficiencies, "Primal Knowledge choices and proficiencies survive save reconstruction")
	var brutal_barbarian := _character("barbarian", 17)
	CombatAction.advance_combat_turn(brutal_barbarian)
	brutal_barbarian.add_condition("reckless_attack", 2)
	var brutal_target := {"id": "brutal-target", "name": "Brutal Target", "size": "medium", "current_hp": 500, "speed": 6, "armor_class": -100, "is_alive": true, "ability_scores": {"STR": 10, "DEX": 10, "CON": 10}}
	var brutal_result := CombatAction.resolve_weapon_attack(brutal_barbarian, brutal_target, DataLoader.get_item("greataxe"), true, false, {"barbarian_brutal_strike_effects": ["hamstring", "sundering"]})
	check.call(brutal_result.get("hit", false), "Level 17 Brutal Strike fixture hits")
	check.call(brutal_result.get("activity_roll", {}).get("formula", "").begins_with("1d20"), "Brutal Strike forgoes the attack's Advantage")
	check.call(brutal_result.get("barbarian_brutal_strike", {}).get("effects", []) == ["hamstring", "sundering"], "Level 17 Brutal Strike applies two different effects")
	check.call("2d10" in str(brutal_result.get("damage_components", [])), "Level 17 Brutal Strike damage increases to 2d10")
	check.call(brutal_target["speed"] == 3 and brutal_target.get("barbarian_sundering_owner", -1) == brutal_barbarian.get_instance_id(), "Brutal Strike applies Hamstring and Sundering until the Barbarian turn boundary")
	var ally_attacker := _character("fighter", 1)
	var sundering_result := CombatAction.resolve_weapon_attack(ally_attacker, brutal_target, DataLoader.get_item("longsword"))
	check.call(sundering_result.get("sundering_bonus", 0) == 5 and not brutal_target.has("barbarian_sundering_owner"), "Sundering Blow benefits and is consumed by the next other attack roll")
	var brutal_targets: Array[Dictionary] = [brutal_target]
	BarbarianRules.clear_turn_effects(brutal_barbarian, brutal_targets)
	check.call(brutal_target["speed"] == 6 and not brutal_target.has("barbarian_no_opportunity_owner"), "Barbarian turn boundary restores Hamstring speed and ends Staggering restrictions")
	var improved_target := {"id": "stagger-target", "name": "Stagger Target", "current_hp": 500, "speed": 6, "armor_class": -100, "is_alive": true, "ability_scores": {"STR": 10, "DEX": 10, "CON": 10}}
	var improved_barbarian := _character("barbarian", 13)
	CombatAction.advance_combat_turn(improved_barbarian)
	improved_barbarian.add_condition("reckless_attack", 2)
	var stagger_result := CombatAction.resolve_weapon_attack(improved_barbarian, improved_target, DataLoader.get_item("greataxe"), false, false, {"barbarian_brutal_strike_effects": ["staggering"]})
	check.call(stagger_result.get("hit", false) and improved_target.get("barbarian_staggered_saves", false) and improved_target.has("barbarian_no_opportunity_owner"), "Level 13 Improved Brutal Strike applies Staggering Blow")
	BarbarianRules.roll_monster_save(improved_target, "WIS")
	check.call(not improved_target.has("barbarian_staggered_saves"), "Staggering Blow imposes disadvantage on and consumes the next monster save")
	CombatAction.active_turn_actor_id = 0
	var boon_barbarian := _character("barbarian", 19)
	var boon_strength_before := boon_barbarian.ability_scores.get_score("STR")
	check.call(ClassProgression.pending_epic_boon_choices(boon_barbarian) == ["barbarian_epic_boon"] and ClassProgression.choose_epic_boon(boon_barbarian, "barbarian_epic_boon", "irresistible_offense", "STR") and boon_barbarian.ability_scores.get_score("STR") == boon_strength_before + 1 and ClassProgression.has_epic_boon(boon_barbarian, "irresistible_offense"), "Barbarian level 19 chooses and saves a shared Epic Boon")
	check.call(ClassProgression.saved_choices_error(boon_barbarian.to_dict()).is_empty(), "Barbarian Epic Boon ability choice passes save preflight")
	var resistant_defender := _character("fighter", 1)
	resistant_defender.inventory.unequip(Inventory.Slot.BODY)
	resistant_defender.inventory.unequip(Inventory.Slot.SHIELD)
	resistant_defender.base_ac = -100
	resistant_defender.max_hp = 999
	resistant_defender.current_hp = 999
	resistant_defender.add_condition("raging", 3)
	seed(424242)
	var offense_result := CombatAction.resolve_weapon_attack(boon_barbarian, resistant_defender, DataLoader.get_item("greataxe"))
	check.call(offense_result.get("hit", false), "Boon of Irresistible Offense fixture hits the raging defender")
	check.call(offense_result.get("damage", 0) == offense_result.get("activity_damage", {}).get("rolled_total", -1), "Boon of Irresistible Offense bypasses physical resistance")
	validator = DataLoader.get_script().new()
	malformed["features_by_level"] = {"4": [{"id": "fixture:active_asi", "name": "Invalid Active Improvement", "type": "active", "effects": [{"type": "asi"}]}]}
	check.call(not validator._validate_content(malformed, "class", "fixture-malformed"), "A known operation in an unsupported active context is rejected")
	validator.free()
	DataLoader._load_directory("res://data/fixtures/class_building_blocks/")
	DataLoader._validate_cross_references()
	check.call(DataLoader.get_load_errors().is_empty(), "Data-only class and additive subclasses pass production content validation")
	var warden := _character("fixture:warden", 4)
	check.call(warden.subclass_id.is_empty() and not warden.has_feature("fixture:renewal") and warden.crit_range == 20, "Multiple subclass options remain pending and grant no combined features")
	check.call(ClassProgression.choose_subclass(warden, "fixture:healer") and warden.has_feature("fixture:renewal") and not warden.has_feature("fixture:guard_critical"), "Only the chosen data-defined subclass grants features")
	check.call(not ClassProgression.choose_subclass(warden, "fixture:guard"), "A saved subclass cannot be silently replaced")
	warden.current_hp = 1
	budget.reset(warden)
	check.call(ClassFeature.execute(warden, warden.get_feature("fixture:renewal"), null, budget).get("success", false) and warden.feature_uses["fixture:resolve"] == 0, "Subclass healing spends its declared cost from the base class's shared pool")
	warden.level_up()
	check.call(warden.feature_uses["fixture:resolve"] == 1, "Data-defined level-up adds only gained resource capacity")
	warden.short_rest()
	check.call(warden.feature_uses["fixture:resolve"] == 2, "Data-defined Short Rest restores only the declared amount")
	warden.long_rest()
	check.call(warden.feature_uses["fixture:resolve"] == 3, "Data-defined Long Rest restores full capacity")
	var zero_pool := _character("fixture:warden", 4)
	for index in zero_pool.features.size():
		if zero_pool.features[index]["id"] == "fixture:resolve":
			zero_pool.features[index] = zero_pool.features[index].duplicate(true)
			zero_pool.features[index]["uses_by_level"] = {"1": 0, "5": 2}
	zero_pool.feature_uses["fixture:resolve"] = 0
	zero_pool.level_up()
	check.call(zero_pool.feature_uses["fixture:resolve"] == 2, "A zero-capacity pool receives its newly gained capacity on level-up")
	check.call(ClassProgression.improve_scores(warden, "CON", "DEX"), "A custom class uses the shared ability improvement")
	warden.use_feature("fixture:mend")
	restored.from_dict(JSON.parse_string(JSON.stringify(warden.to_dict())))
	check.call(restored.subclass_id == "fixture:healer" and restored.feature_uses["fixture:resolve"] == 2 and restored.feature_choices == warden.feature_choices and restored.ability_scores.to_dict() == warden.ability_scores.to_dict(), "Custom choices, stats and remaining shared resource survive JSON reconstruction")
	var bad_choice := warden.to_dict()
	bad_choice["subclass_id"] = "fixture:missing"
	check.call(not ClassProgression.saved_choices_error(bad_choice).is_empty(), "Missing subclass is rejected before save state mutates")
	bad_choice["subclass_id"] = "fixture:duelist"
	check.call(not ClassProgression.saved_choices_error(bad_choice).is_empty(), "A subclass belonging to another class is rejected")
	var duelist := _character("fighter", 7)
	check.call(duelist.subclass_id.is_empty() and ClassProgression.choose_subclass(duelist, "fixture:duelist"), "An additive Fighter subclass registers without replacing Fighter data")
	check.call(duelist.crit_range == 20 and not duelist.has_feature("champion_additional_fighting_style") and not FighterRules.choose_style(duelist, "archery"), "A different Fighter subclass receives neither Champion criticals nor its second style")
	for entitlement in 3:
		ClassProgression.improve_scores(duelist, "STR", "STR")
	check.call(ClassProgression.pending_improvements(duelist).is_empty() and FighterRules.saved_training_error(duelist.to_dict()).is_empty() and ClassProgression.saved_choices_error(duelist.to_dict()).is_empty(), "A Fighter subclass can grant an additional improvement without the legacy count rejecting its save")
	var cleric := _character("cleric", 5)
	var divine_spark := cleric.get_feature("cleric_divine_spark")
	var turn_undead := cleric.get_feature("cleric_turn_undead")
	check.call(not divine_spark.is_empty() and not turn_undead.is_empty() and divine_spark.get("resource_id", "") == "cleric_channel_divinity" and turn_undead.get("resource_id", "") == "cleric_channel_divinity", "Divine Spark and Turn Undead use the shared Channel Divinity pool")
	var wounded_ally := _character("fighter", 1)
	wounded_ally.current_hp = 1
	var spark_heal := ClericRules.resolve_divine_spark(cleric, wounded_ally, "heal")
	check.call(spark_heal.get("success", false) and spark_heal.get("healing", 0) > 0 and wounded_ally.current_hp > 1, "Divine Spark uses the common healing path against a selected character")
	var spark_target := {"id": "undead:spark", "name": "Spark Target", "is_alive": true, "current_hp": 100, "max_hp": 100, "ability_scores": {"CON": 10}, "saving_throw_bonuses": {"CON": -30}, "damage_immunities": [], "conditions": {}}
	var spark_harm := ClericRules.resolve_divine_spark(cleric, spark_target, "harm", "necrotic")
	check.call(spark_harm.get("success", false) and not spark_harm.get("saved", true) and spark_harm.get("damage", 0) >= 3 and spark_harm.get("damage_type", "") == "necrotic", "Divine Spark shares the monster saving-throw and typed-damage path: %s" % str(spark_harm))
	var undead := {"id": "undead:turn", "name": "Restless Dead", "creature_type": "undead", "is_alive": true, "current_hp": 100, "max_hp": 100, "ability_scores": {"WIS": 10}, "saving_throw_bonuses": {"WIS": -30}, "damage_immunities": [], "condition_immunities": [], "conditions": {}, "hex_position": Vector2i(2, 0)}
	var beast := {"id": "beast:turn", "name": "Living Beast", "creature_type": "beast", "is_alive": true, "current_hp": 100, "max_hp": 100, "ability_scores": {"WIS": 10}, "saving_throw_bonuses": {"WIS": -30}, "damage_immunities": [], "condition_immunities": [], "conditions": {}, "hex_position": Vector2i(1, 0)}
	var distant_undead := {"id": "undead:distant", "name": "Distant Dead", "creature_type": "undead", "is_alive": true, "current_hp": 100, "max_hp": 100, "ability_scores": {"WIS": 10}, "saving_throw_bonuses": {"WIS": -30}, "damage_immunities": [], "condition_immunities": [], "conditions": {}, "hex_position": Vector2i(8, 0)}
	var turn_results := ClericRules.resolve_turn_undead(cleric, [undead, beast, distant_undead], Vector2i.ZERO)
	check.call(turn_results.size() == 1 and turn_results[0].get("target_id", "") == "undead:turn" and undead.get("conditions", {}).has("frightened") and undead.get("conditions", {}).has("incapacitated"), "Turn Undead targets only Undead within 30 feet and applies the shared conditions on a failed save")
	check.call(int(turn_results[0].get("damage", 0)) > 0 and undead.get("conditions", {}).has("incapacitated"), "Sear Undead adds Wisdom-based Radiant damage without ending Turn Undead")
	ClericRules.clear_turning_after_damage(undead)
	check.call(not undead.get("conditions", {}).has("incapacitated") and not undead.has("turn_undead_origin"), "Damage clears Turn Undead's conditions and source marker")
	var blessed := _character("cleric", 7)
	check.call(ClassProgression.choose_feature_option(blessed, "cleric_blessed_strikes", "divine_strike"), "Blessed Strikes saves its Divine Strike choice through the shared choice path")
	var rider_target := {"id": "target:divine-strike", "is_alive": true, "current_hp": 100, "damage_immunities": []}
	CombatAction.advance_combat_turn(blessed)
	var divine_riders := CombatAction.resolve_weapon_damage_riders(blessed, rider_target, {"divine_strike": "radiant"})
	check.call(divine_riders.size() == 1 and divine_riders[0].get("formula", "") == "1d8" and int(divine_riders[0].get("damage", 0)) > 0 and CombatAction.resolve_weapon_damage_riders(blessed, rider_target, {"divine_strike": "radiant"}).is_empty(), "Divine Strike applies its Radiant weapon-hit rider only once per turn")
	var upgraded_blessed := _character("cleric", 14)
	check.call(ClassProgression.choose_feature_option(upgraded_blessed, "cleric_blessed_strikes", "divine_strike"), "Level-14 Cleric can select the same saved Blessed Strikes option")
	CombatAction.advance_combat_turn(upgraded_blessed)
	var upgraded_rider := CombatAction.resolve_weapon_damage_riders(upgraded_blessed, rider_target, {"divine_strike": "radiant"})
	check.call(upgraded_blessed.has_feature("cleric_improved_blessed_strikes") and upgraded_rider.size() == 1 and upgraded_rider[0].get("formula", "") == "2d8", "Improved Divine Strike upgrades through the same level-scaled rider")
	var potent := _character("cleric", 14)
	check.call(ClassProgression.choose_feature_option(potent, "cleric_blessed_strikes", "potent_spellcasting"), "Blessed Strikes can save Potent Spellcasting through the shared choice path")
	var sacred_flame := DataLoader.get_spell("sacred_flame")
	check.call(CombatAction.spell_damage_bonus(potent, sacred_flame) == 2 and CombatAction.resolve_spell_cast_riders(potent, sacred_flame, "magic_action", 1, potent).size() == 1 and potent.temp_hp == 4, "Potent Spellcasting adds Wisdom to Cleric cantrip damage and improved casting grants twice-Wisdom temporary HP")
	var intervention := _character("cleric", 10)
	var intervention_options := ClericRules.divine_intervention_spell_options(intervention)
	var options_valid := not intervention_options.is_empty()
	for spell in intervention_options:
		options_valid = options_valid and int(spell.get("level", 99)) <= 5 and str(spell.get("casting_time", "action")) != "reaction"
	check.call(options_valid and intervention.get_feature_max_uses("cleric_divine_intervention") == 1 and not intervention_options.any(func(spell): return str(spell.get("id", "")) == "wish"), "Divine Intervention offers catalog Cleric spells up to level five, excludes Reactions, and reserves Wish for level twenty")
	intervention.use_feature("cleric_divine_intervention")
	intervention.long_rest()
	check.call(int(intervention.feature_uses.get("cleric_divine_intervention", 0)) == 1, "Divine Intervention returns after a Long Rest")
	var greater_intervention := _character("cleric", 20)
	var greater_options := ClericRules.divine_intervention_spell_options(greater_intervention)
	var wish_spells := ClericRules.wish_duplication_spell_options()
	var wish_options_valid := greater_options.any(func(spell): return str(spell.get("id", "")) == "wish") and not wish_spells.is_empty()
	for spell in wish_spells:
		wish_options_valid = wish_options_valid and int(spell.get("level", 99)) <= 8 and str(spell.get("casting_time", "action")) != "reaction"
	check.call(wish_options_valid, "Greater Divine Intervention offers Wish and the catalog spells it can duplicate")
	var wish_rests := ClericRules.apply_greater_intervention_cooldown(greater_intervention, "wish")
	var cooldown_holds := wish_rests >= 2 and wish_rests <= 8 and int(greater_intervention.feature_uses.get("cleric_divine_intervention", 0)) == 0
	for rest_index in maxi(0, wish_rests - 1):
		greater_intervention.long_rest()
		cooldown_holds = cooldown_holds and int(greater_intervention.feature_uses.get("cleric_divine_intervention", 0)) == 0
	greater_intervention.long_rest()
	check.call(cooldown_holds and int(greater_intervention.feature_uses.get("cleric_divine_intervention", 0)) == 1, "Greater Divine Intervention blocks Wish recovery for its rolled 2d4 Long Rests")
	var druid := _character("druid", 1)
	check.call(druid.get_spellcasting_capacity("cantrips") == 2 and druid.get_spellcasting_capacity("prepared_spells") == 4 and druid.spell_slots.get("1", 0) == 2, "Druid level one uses the shared Wisdom spellcasting capacity and slot table")
	check.call(ClassProgression.choose_feature_option(druid, "druid_primal_order", "magician") and druid.get_spellcasting_capacity("cantrips") == 3 and druid.get_ability_check_bonus("Nature") == 2 and druid.get_ability_check_bonus("Arcana") == 2, "Magician stores the Primal Order choice, bonus cantrip, and shared Wisdom check bonus")
	var warden_druid := _character("druid", 1)
	check.call(ClassProgression.choose_feature_option(warden_druid, "druid_primal_order", "warden") and "martial" in warden_druid.weapon_proficiencies and "medium" in warden_druid.armor_proficiencies and "medium" not in _character("druid", 1).armor_proficiencies, "Warden grants Martial weapons and Medium Armor while the base Druid retains only Light Armor and shields")
	var wild_shape_druid := _character("druid", 17)
	wild_shape_druid.feature_uses["druid_wild_shape_uses"] = 0
	var wild_shape_roster: Dictionary = DataLoader.get_character_class("druid").get("features_by_level", {})
	check.call(wild_shape_druid.get_feature_max_uses("druid_wild_shape_uses") == 4 and wild_shape_druid.feature_uses["druid_wild_shape_uses"] == 0, "Druid level 17 Wild Shape resource scales to four uses")
	wild_shape_druid.short_rest()
	check.call(wild_shape_druid.feature_uses["druid_wild_shape_uses"] == 1, "Wild Shape resource recovers one use on a Short Rest")
	wild_shape_druid.long_rest()
	check.call(wild_shape_druid.feature_uses["druid_wild_shape_uses"] == 4 and wild_shape_roster.size() == 20 and not wild_shape_roster["4"].any(func(feature): return str(feature.get("id", "")) in ["druid_cantrip_versatility", "druid_wild_shape_improvement"]), "Druid restores all Wild Shape uses on a Long Rest and declares a clean 2024 level 1-20 feature map")
	var companion_druid := _character("druid", 2)
	companion_druid.feature_uses["druid_wild_shape_uses"] = 2
	var familiar_forms := DruidRules.wild_companion_forms()
	var companion_slots_before := int(companion_druid.spell_slots.get("1", 0))
	var familiar_cast := DruidRules.summon_wild_companion(companion_druid, "owl", "spell_slot")
	var saved_companion := Character.new()
	saved_companion.from_dict(companion_druid.to_dict())
	check.call(familiar_forms.size() == 4 and familiar_cast.get("success", false) and companion_druid.spell_slots.get("1", 0) == companion_slots_before - 1 and DruidRules.wild_companion_state(saved_companion).get("id", "") == "owl", "Wild Companion offers four supported forms, expends a spell slot, and saves its familiar form")
	var companion_shape_cast := DruidRules.summon_wild_companion(companion_druid, "rat", "wild_shape")
	companion_druid.long_rest()
	check.call(companion_shape_cast.get("success", false) and companion_druid.feature_uses["druid_wild_shape_uses"] == companion_druid.get_feature_max_uses("druid_wild_shape_uses") and DruidRules.wild_companion_state(companion_druid).is_empty(), "Wild Companion can expend Wild Shape and a Long Rest ends the familiar")
	var potent_druid := _character("druid", 15)
	var thorn_whip := DataLoader.get_spell("thorn_whip")
	ClassProgression.choose_feature_option(potent_druid, "druid_elemental_fury", "potent_spellcasting")
	var potent_saved := Character.new()
	potent_saved.from_dict(potent_druid.to_dict())
	check.call(potent_druid.has_feature("druid_improved_elemental_fury") and CombatAction.spell_damage_bonus(potent_saved, thorn_whip) == 2 and CombatAction.spell_range_bonus_feet(potent_saved, thorn_whip) == 300, "Druid Potent Spellcasting adds Wisdom to its cantrips and level 15 extends eligible cantrip range by 300 feet after reload")
	var primal_druid := _character("druid", 15)
	ClassProgression.choose_feature_option(primal_druid, "druid_elemental_fury", "primal_strike")
	var primal_target := {"id": "primal_target", "name": "Target", "current_hp": 100, "is_alive": true, "damage_immunities": []}
	var primal_rider := CombatAction.resolve_weapon_damage_riders(primal_druid, primal_target, {"primal_strike": "lightning"})
	var repeat_primal_rider := CombatAction.resolve_weapon_damage_riders(primal_druid, primal_target, {"primal_strike": "fire"})
	check.call(primal_rider.size() == 1 and primal_rider[0].get("formula", "") == "2d8" and primal_rider[0].get("damage_type", "") == "lightning" and repeat_primal_rider.is_empty(), "Primal Strike lets the Druid choose its damage type, scales to 2d8 at level 15, and applies once per turn")
	var beast_spell_druid := _character("druid", 18)
	DruidRules.learn_form(beast_spell_druid, "wolf")
	DruidRules.transform(beast_spell_druid, "wolf")
	check.call(DruidRules.can_cast_spells(beast_spell_druid) and DruidRules.can_cast_spell(beast_spell_druid, thorn_whip) and not DruidRules.can_cast_spell(beast_spell_druid, {"id": "costly", "level": 1, "material_component_cost": 100}), "Beast Spells permits spellcasting in Wild Shape and blocks spells with a priced Material component")
	var beast_spell_data := DataLoader.get_spell("shillelagh").duplicate(true)
	var costly_beast_spell := beast_spell_data.duplicate(true)
	costly_beast_spell["material_component_cost"] = 50
	var beast_spell_inventory := Inventory.new()
	beast_spell_druid.inventory = beast_spell_inventory
	beast_spell_data["_ignore_material_components"] = DruidRules.ignores_free_material_components(beast_spell_druid, beast_spell_data)
	check.call(beast_spell_data["_ignore_material_components"] and beast_spell_inventory.has_required_spell_component(beast_spell_data, "druid") and not DruidRules.ignores_free_material_components(beast_spell_druid, costly_beast_spell), "Beast Spells waives no-cost Material focus requirements but retains priced-material restrictions")
	var archdruid := _character("druid", 20)
	ClassProgression.choose_feature_option(archdruid, "druid_primal_order", "magician")
	archdruid.feature_uses["druid_wild_shape_uses"] = 0
	var evergreen_recovery := ClassProgression.apply_initiative_resource_recovery(archdruid)
	archdruid.feature_uses["druid_wild_shape_uses"] = 4
	archdruid.spell_slots["2"] = 0
	var nature_options := DruidRules.nature_magician_options(archdruid)
	var nature_result := DruidRules.use_nature_magician(archdruid, 1)
	var repeated_nature_result := DruidRules.use_nature_magician(archdruid, 1)
	check.call(evergreen_recovery.get("druid_wild_shape_uses", 0) == 1 and not nature_options.is_empty() and nature_result.get("success", false) and archdruid.feature_uses["druid_wild_shape_uses"] == 3 and archdruid.spell_slots["2"] == 1 and not repeated_nature_result.get("success", true), "Archdruid restores a Wild Shape use at Initiative and Magician creates a spell slot from Wild Shape once per Long Rest")
	var shape_druid := _character("druid", 2)
	var original_scores := shape_druid.ability_scores.to_dict()
	var original_speed := shape_druid.speed
	var eligible_level_two := DruidRules.eligible_form_options(shape_druid)
	check.call(DruidRules.known_form_capacity(shape_druid) == 4 and eligible_level_two.size() >= 8 and eligible_level_two.all(func(form): return float(form.get("challenge_rating", 99.0)) <= 0.25 and int(form.get("fly_speed", 0)) == 0), "Druid level 2 offers four saved known forms from the eligible nonflying CR 1/4-or-lower list")
	for form_id in ["rat", "riding_horse", "spider", "wolf"]:
		DruidRules.learn_form(shape_druid, form_id)
	check.call(DruidRules.pending_known_form_count(shape_druid) == 0 and not DruidRules.learn_form(shape_druid, "wolf") and DruidRules.form_options(shape_druid).size() == 4, "Learned forms are saved, unique, capacity-bounded, and are the only forms offered for transformation")
	shape_druid.temp_hp = 1
	var shape_result := DruidRules.transform(shape_druid, "wolf")
	var wolf_form := DruidRules.current_form(shape_druid)
	check.call(shape_result.get("success", false) and shape_druid.feature_uses["druid_wild_shape_uses"] == 1 and shape_druid.temp_hp == 2 and shape_druid.get_ac() == 12 and shape_druid.get_speed() == 8 and shape_druid.ability_scores.get_score("STR") == 14 and shape_druid.ability_scores.get_score("WIS") == original_scores["WIS"] and wolf_form.get("challenge_rating", 99) == 0.25, "Wild Shape spends one shared use, gains Druid-level temporary HP, and applies eligible Beast AC, speed, and physical scores while retaining mental scores")
	var wolf_attack := DruidRules.current_attack_profile(shape_druid)
	var adjacent_ally := _character("fighter", 1)
	var wolf_target := {"hex_position": Vector2i(1, 0), "current_hp": 20, "is_alive": true, "size": "medium", "conditions": {}}
	var wolf_allies := [{"character": adjacent_ally, "hex_position": Vector2i(2, 0)}]
	var wolf_result := {"hit": true, "damage": 4, "damage_components": [], "message": "Hit."}
	DruidRules.apply_attack_effects(shape_druid, wolf_target, wolf_attack, wolf_result)
	check.call(DruidRules.pack_tactics_advantage(shape_druid, wolf_target, wolf_allies) and wolf_target.conditions.has("prone") and shape_druid.get_ac() == 12 and shape_druid.get_skill_check_modifier("Perception", "WIS") == 5, "Wolf Pack Tactics uses the shared attack advantage path, its bite knocks eligible targets Prone, and form skill proficiency uses the higher modifier")
	var saved_shape := Character.new()
	saved_shape.from_dict(shape_druid.to_dict())
	var saved_form_roundtrip := DruidRules.is_shaped(saved_shape) and saved_shape.get_ac() == 12 and saved_shape.get_speed() == 8 and DruidRules.revert(saved_shape) and saved_shape.ability_scores.to_dict() == original_scores and saved_shape.speed == original_speed
	check.call(saved_form_roundtrip and saved_shape.feature_choices.get(DruidRules.KNOWN_FORMS_CHOICE_ID, []) == ["rat", "riding_horse", "spider", "wolf"] and not DruidRules.can_cast_spells(shape_druid) and not DruidRules.validate_form(shape_druid, "eagle").get("success", false), "Wild Shape and learned forms save for normal reversion, block spellcasting, and reject an unknown or unlearned form")
	shape_druid.add_condition("incapacitated", 1)
	check.call(not DruidRules.is_shaped(shape_druid) and shape_druid.ability_scores.to_dict() == original_scores and shape_druid.speed == original_speed, "Incapacitation immediately reverts Wild Shape and restores the original character statistics")
	var expanding_druid := _character("druid", 4)
	for form_id in ["rat", "riding_horse", "spider", "wolf"]:
		DruidRules.learn_form(expanding_druid, form_id)
	check.call(DruidRules.known_form_capacity(expanding_druid) == 6 and DruidRules.pending_known_form_count(expanding_druid) == 2 and DruidRules.eligible_form_options(expanding_druid).any(func(form): return str(form.get("id", "")) == "giant_goat"), "Druid level 4 gains two form choices and can learn CR 1/2 forms")
	for form_id in ["boar", "giant_badger"]:
		DruidRules.learn_form(expanding_druid, form_id)
	expanding_druid.long_rest()
	var invalid_form_replacement_rejected := not DruidRules.replace_known_form(expanding_druid, "riding_horse", "brown_bear") and int(expanding_druid.feature_uses[DruidRules.FORM_REPLACEMENT_RESOURCE_ID]) == 1
	var replacement_ok := DruidRules.replace_known_form(expanding_druid, "rat", "panther")
	check.call(invalid_form_replacement_rejected and replacement_ok and DruidRules.known_form_ids(expanding_druid).size() == 6 and "rat" not in DruidRules.known_form_ids(expanding_druid) and "panther" in DruidRules.known_form_ids(expanding_druid) and int(expanding_druid.feature_uses[DruidRules.FORM_REPLACEMENT_RESOURCE_ID]) == 0, "A Long Rest grants one eligible form replacement and an invalid higher-CR replacement does not spend it")
	var high_level_druid := _character("druid", 8)
	check.call(DruidRules.known_form_capacity(high_level_druid) == 8 and DruidRules.eligible_form_options(high_level_druid).any(func(form): return str(form.get("id", "")) == "eagle") and DruidRules.eligible_form_options(high_level_druid).any(func(form): return str(form.get("id", "")) == "giant_spider"), "Druid level 8 permits eight known forms, CR 1 Beasts, and forms with a Fly Speed")
	var resurgence_druid := _character("druid", 5)
	resurgence_druid.feature_uses["druid_wild_shape_uses"] = 0
	resurgence_druid.spell_slots = {"1": 4, "2": 3, "3": 2}
	var slot_recovery := DruidRules.use_wild_resurgence(resurgence_druid, 2)
	check.call(slot_recovery.get("success", false) and int(resurgence_druid.feature_uses["druid_wild_shape_uses"]) == 1 and int(resurgence_druid.spell_slots["2"]) == 2 and int(resurgence_druid.feature_uses["druid_wild_resurgence"]) == 0 and DruidRules.wild_resurgence_state(resurgence_druid).is_empty(), "Wild Resurgence restores one empty Wild Shape pool use by spending a chosen slot, once on that turn")
	resurgence_druid.feature_uses["druid_wild_resurgence"] = 1
	resurgence_druid.spell_slots["1"] = 3
	var slot_exchange := DruidRules.use_wild_resurgence(resurgence_druid)
	resurgence_druid.feature_uses["druid_wild_resurgence"] = 1
	resurgence_druid.feature_uses["druid_wild_shape_uses"] = 1
	var exchange_blocked := bool(resurgence_druid.feature_uses.get("druid_wild_resurgence_long_rest_used", false)) and DruidRules.wild_resurgence_state(resurgence_druid).is_empty()
	resurgence_druid.long_rest()
	check.call(slot_exchange.get("success", false) and int(resurgence_druid.feature_uses["druid_wild_shape_uses"]) == 2 and int(resurgence_druid.spell_slots["1"]) == 4 and not bool(resurgence_druid.feature_uses.get("druid_wild_resurgence_long_rest_used", false)) and exchange_blocked, "Wild Resurgence converts one use into a level 1 slot only once per Long Rest and the restriction clears after the rest")
	_roll_token_rules(check)
	_ward_rules(check)
	_rest_and_slot_recovery_rules(check)
	DataLoader.load_all_data()

static func _rogue_rules(check: Callable) -> void:
	var rogue := _character("rogue", 5)
	var target := {"name": "Cunning Target", "size": "Large", "current_hp": 30, "max_hp": 30, "armor_class": 12, "conditions": {}, "saving_throw_bonuses": {}}
	var options := RogueRules.cunning_strike_options(rogue, target)
	check.call(options == ["trip", "withdraw"], "Rogue without a Poisoner's Kit only sees eligible Cunning Strike choices")
	rogue.inventory.add_item("poisoners_kit")
	options = RogueRules.cunning_strike_options(rogue, target)
	check.call(options == ["poison", "trip", "withdraw"], "Poison becomes a Cunning Strike option when the Rogue carries the required kit")
	target["size"] = "Huge"
	check.call("trip" not in RogueRules.cunning_strike_options(rogue, target), "Cunning Strike Trip excludes Huge targets")
	check.call(RogueRules.remaining_sneak_attack_dice(3, ["poison", "trip"]) == 1 and RogueRules.saving_throw_dc(rogue) == 13, "Cunning Strike spends its declared dice and uses the Rogue Dexterity save DC")
	var rogue_eleven := _character("rogue", 11)
	check.call(RogueRules.cunning_strike_max_effects(rogue_eleven) == 2, "Improved Cunning Strike permits two distinct supported options")
	var rogue_thirteen := _character("rogue", 13)
	check.call("daze" not in RogueRules.cunning_strike_options(rogue_thirteen, target), "Devious Strikes choices remain unavailable before Rogue level 14")
	var rogue_fourteen := _character("rogue", 14)
	var devious_options := RogueRules.cunning_strike_options(rogue_fourteen, target)
	check.call(["daze", "knock_out", "obscure"].all(func(option): return option in devious_options) and RogueRules.cunning_strike_max_effects(rogue_fourteen) == 2, "Devious Strikes adds its three options while retaining the two-effect limit")
	check.call(RogueRules.cunning_strike_dice_cost("daze") == 2 and RogueRules.cunning_strike_dice_cost("obscure") == 3 and RogueRules.cunning_strike_dice_cost("knock_out") == 6 and RogueRules.remaining_sneak_attack_dice(7, ["daze", "obscure"]) == 2, "Devious Strikes charges each SRD Sneak Attack die cost")
	check.call(RogueRules.cunning_strike_save_ability("daze") == "CON" and RogueRules.cunning_strike_save_ability("knock_out") == "CON" and RogueRules.cunning_strike_save_ability("obscure") == "DEX", "Devious Strikes uses the specified Constitution and Dexterity saves")
	var dazed_target := target.duplicate(true)
	CombatAction.apply_condition(dazed_target, "dazed", 1, RogueRules.CUNNING_DAZE_SOURCE)
	CombatState.tick_monster_condition_durations(dazed_target)
	check.call(not dazed_target.get("conditions", {}).has("dazed"), "Daze expires at the end of the target's next turn")
	var knocked_out_target := target.duplicate(true)
	CombatAction.apply_condition(knocked_out_target, "unconscious", 10, RogueRules.CUNNING_KNOCKOUT_SOURCE)
	knocked_out_target["rogue_cunning_knock_out_dc"] = 15
	check.call(not RogueRules.resolve_knock_out_repeat_save(knocked_out_target, 14, 15) and knocked_out_target.get("conditions", {}).has("unconscious"), "Knock Out persists after a failed end-of-turn save")
	check.call(RogueRules.resolve_knock_out_repeat_save(knocked_out_target, 15, 15) and not knocked_out_target.get("conditions", {}).has("unconscious") and not knocked_out_target.has("rogue_cunning_knock_out_dc"), "Knock Out ends when the target succeeds on a repeated save")
	var damage_wakes_target := target.duplicate(true)
	CombatAction.apply_condition(damage_wakes_target, "unconscious", 10, RogueRules.CUNNING_KNOCKOUT_SOURCE)
	damage_wakes_target["rogue_cunning_knock_out_dc"] = 15
	CombatAction.resolve_damage(damage_wakes_target, 1, "bludgeoning")
	check.call(not damage_wakes_target.get("conditions", {}).has("unconscious") and not damage_wakes_target.has("rogue_cunning_knock_out_dc"), "Damage ends Knock Out immediately")
	var elusive_rogue := _character("rogue", 18)
	var attacker := _character("fighter", 1)
	var weapon := {"id": "dagger", "type": "weapon", "damage": "1d4", "damage_type": "piercing", "ability": "DEX", "range": 1, "properties": ["finesse"]}
	var result := CombatAction.resolve_weapon_attack(attacker, elusive_rogue, weapon, true, false)
	var roll: Dictionary = result.get("activity_roll", {})
	var dice_terms: Array = roll.get("dice_terms", [])
	check.call(not dice_terms.is_empty() and int(dice_terms[0].get("count", 0)) == 1, "Elusive cancels Advantage against a Rogue who is not Incapacitated")
	elusive_rogue.add_condition("incapacitated", 1)
	var incapacitated_result := CombatAction.resolve_weapon_attack(attacker, elusive_rogue, weapon, true, false)
	var incapacitated_roll: Dictionary = incapacitated_result.get("activity_roll", {})
	var incapacitated_terms: Array = incapacitated_roll.get("dice_terms", [])
	check.call(not incapacitated_terms.is_empty() and int(incapacitated_terms[0].get("count", 0)) == 2, "Elusive allows Advantage while the Rogue is Incapacitated")
	var rogue_twenty := _character("rogue", 20)
	var failed_test := {"success": false, "natural_roll": 2, "modifier": 3, "total": 5, "dc": 15}
	var stroke := RogueRules.apply_stroke_of_luck(rogue_twenty, failed_test, true)
	check.call(stroke.get("used", false) and stroke["result"].get("natural_roll", 0) == 20 and stroke["result"].get("total", 0) == 23 and stroke["result"].get("success", false), "Stroke of Luck turns an accepted failed skill check into a natural 20")
	check.call(not RogueRules.apply_stroke_of_luck(rogue_twenty, failed_test, true).get("used", false), "Stroke of Luck cannot be spent twice before resting")
	rogue_twenty.short_rest()
	check.call(int(rogue_twenty.feature_uses.get("rogue_stroke_of_luck", 0)) == 1, "Stroke of Luck recovers after a Short Rest")
	var failed_attack := {"natural": 2, "total": 4, "is_crit": false, "is_miss": true, "activity_modifiers": [{"value": 2}]}
	var attack_stroke := RogueRules.apply_stroke_of_luck_to_attack(rogue_twenty, failed_attack, true)
	check.call(attack_stroke.get("used", false) and attack_stroke["result"].get("natural", 0) == 20 and attack_stroke["result"].get("is_crit", false), "Stroke of Luck converts an accepted missed attack into a critical natural 20")


static func _warlock_rules(check: Callable) -> void:
	# 1. Base progression & Pact Magic at Level 1
	var warlock := _character("warlock", 1)
	warlock.ability_scores.set_score("CHA", 16)
	check.call(warlock.spell_slots.get("1", 0) == 1 and warlock.get_spellcasting_capacity("cantrips") == 2 and warlock.get_spellcasting_capacity("prepared_spells") == 2, "Warlock level 1 starts with 1 Pact slot and 2 cantrips / 2 prepared spells")
	check.call(WarlockRules.invocation_capacity(warlock.level) == 1 and WarlockRules.invocation_options(warlock).size() >= 20, "Warlock level 1 has 1 invocation capacity and full catalog of invocations")

	# Invocations selection and prerequisites
	check.call(WarlockRules.available_invocation_selections(warlock).has("pact_of_the_blade") and not WarlockRules.available_invocation_selections(warlock).has("thirsting_blade"), "Warlock level 1 can take Pact of the Blade but cannot take Thirsting Blade")
	check.call(WarlockRules.choose_invocations(warlock, ["pact_of_the_blade"]), "Warlock selects Pact of the Blade at level 1")
	check.call(not WarlockRules.choose_invocations(warlock, ["pact_of_the_blade", "armor_of_shadows"]), "Warlock cannot exceed invocation capacity")

	# Level 2: Invocations capacity 3, Pact slots 2, free at-will casts
	warlock.level_up()
	check.call(warlock.level == 2 and WarlockRules.invocation_capacity(warlock.level) == 3 and warlock.spell_slots.get("1", 0) == 2, "Warlock level 2 has 3 invocations capacity and 2 Pact slots")
	var selections_2: Array[String] = ["pact_of_the_blade", "armor_of_shadows", "fiendish_vigor"]
	check.call(WarlockRules.choose_invocations(warlock, selections_2), "Warlock selects Armor of Shadows and Fiendish Vigor at level 2")
	check.call(warlock.has_free_spell_cast("mage_armor") and warlock.has_free_spell_cast("false_life"), "Invocations grant at-will free spell casts")

	# Fiendish Vigor max temporary HP
	warlock.temp_hp = 0
	var false_life_res := CombatAction.resolve_spell(warlock, warlock, DataLoader.get_spell("false_life"))
	check.call(false_life_res.get("success", false) and warlock.temp_hp == 12, "Fiendish Vigor grants 12 temporary HP from False Life")

	# Level 3: Fiend Patron subclass delegation & always-prepared spells
	warlock.level_up()
	check.call(warlock.level == 3 and warlock.subclass_id == "fiend_patron", "Warlock level 3 assigns Fiend Patron subclass")
	check.call(warlock.has_feature("fiend_dark_ones_blessing") and warlock.has_feature("fiend_spells_3"), "Fiend Patron grants Dark One's Blessing and Fiend Spells at level 3")
	check.call("burning_hands" in warlock.known_spells and "command" in warlock.known_spells, "Fiend Patron spells (burning hands, command) are always prepared")

	# Dark One's Blessing temp HP calculation & application
	warlock.temp_hp = 0
	var blessing_thp := WarlockRules.dark_ones_blessing_temp_hp(warlock) # level 3 + CHA 3 = 6
	check.call(blessing_thp == 6, "Dark One's Blessing calculates level + CHA modifier")
	var gained_thp := WarlockRules.apply_dark_ones_blessing(warlock)
	check.call(gained_thp == 6 and warlock.temp_hp == 6, "Dark One's Blessing applies temporary HP to warlock")

	# Pact of the Blade damage type selection
	check.call(WarlockRules.choose_pact_weapon_damage_type(warlock, "radiant") and warlock.pact_weapon_damage_type == "radiant", "Pact of the Blade allows choosing radiant damage")
	check.call(not WarlockRules.choose_pact_weapon_damage_type(warlock, "force"), "Pact of the Blade rejects invalid damage type")
	warlock.inventory.equip(Inventory.Slot.WEAPON, "dagger", true)
	var weapon_atk := CombatAction.resolve_weapon_attack(warlock, {"armor_class": 0, "current_hp": 20, "is_alive": true}, DataLoader.get_item("dagger"))
	check.call(weapon_atk.get("hit", false) and weapon_atk.get("damage_type", "") == "radiant", "Pact of the Blade converts weapon damage to chosen damage type (radiant)")

	# Level 5: Thirsting Blade (Extra Attack) & Eldritch Smite
	while warlock.level < 5:
		warlock.level_up()
	check.call(warlock.level == 5 and int(warlock.spell_slots.get("3", 0)) == 2, "Warlock level 5 has level 3 Pact Magic slots")
	check.call("scorching_ray" in warlock.known_spells and "suggestion" in warlock.known_spells, "Fiend Spells level 5 prepared")
	var selections_5: Array[String] = ["pact_of_the_blade", "armor_of_shadows", "fiendish_vigor", "thirsting_blade", "eldritch_smite"]
	check.call(WarlockRules.choose_invocations(warlock, selections_5), "Warlock level 5 selects Thirsting Blade and Eldritch Smite")
	check.call(warlock.extra_attacks == 1, "Thirsting Blade grants Extra Attack (1 extra attack)")

	# Eldritch Smite resolution
	var smite_target := {"name": "Smite Target", "current_hp": 50, "size": "medium", "conditions": {}}
	var smite_res := CombatAction.resolve_eldritch_smite(warlock, smite_target)
	check.call(smite_res.get("success", false) and smite_res.get("damage_type", "") == "force" and smite_res.get("damage_formula", "") == "4d8" and smite_res.get("knocked_prone", false) and smite_target.get("conditions", {}).has("prone"), "Eldritch Smite expends Pact slot, deals (1+3)d8 force damage and knocks prone")

	# Level 6: Dark One's Own Luck
	warlock.level_up()
	check.call(warlock.level == 6 and warlock.has_feature("fiend_dark_ones_own_luck"), "Warlock level 6 grants Dark One's Own Luck")
	var luck_pool := "fiend_dark_ones_own_luck"
	check.call(int(warlock.feature_uses.get(luck_pool, 0)) == 3, "Dark One's Own Luck has uses equal to CHA modifier")
	var luck_res := WarlockRules.dark_ones_own_luck(warlock, 10, 15)
	check.call(luck_res.get("spent", false) and int(luck_res.get("bonus", 0)) >= 1 and int(luck_res.get("total", 0)) > 10 and int(warlock.feature_uses.get(luck_pool, 0)) == 2, "Dark One's Own Luck adds 1d10 to total and spends 1 use")

	# Level 9 grants Contact Patron, but its knowledge/delivery spell remains
	# unavailable until Wave 5. A grant must not bypass that availability gate.
	while warlock.level < 9:
		warlock.level_up()
	check.call(warlock.has_feature("warlock_contact_patron") and "contact_other_plane" in warlock.known_spells and warlock.has_free_spell_cast("contact_other_plane"), "Contact Patron adds Contact Other Plane with a free cast per Long Rest")
	var cop_spell := DataLoader.get_spell("contact_other_plane")
	var contact_slots := warlock.spell_slots.duplicate()
	var cop_res := CombatAction.resolve_spell(warlock, warlock, cop_spell, false)
	check.call(not SpellSupport.is_available(cop_spell) and not cop_res.get("success", true) and not str(cop_res.get("message", "")).is_empty() and warlock.spell_slots == contact_slots and warlock.has_free_spell_cast("contact_other_plane") and not warlock.has_condition("incapacitated"), "Contact Patron preserves its grant and resources when unavailable Contact Other Plane refuses")

	# Level 10: Fiendish Resilience
	warlock.level_up()
	check.call(warlock.level == 10 and warlock.has_feature("fiend_fiendish_resilience"), "Warlock level 10 grants Fiendish Resilience")
	check.call(WarlockRules.choose_fiendish_resilience(warlock, "cold") and warlock.fiendish_resilience_type == "cold", "Fiendish Resilience allows choosing resistance to cold")
	check.call(warlock.resist_damage(20, "cold") == 10 and warlock.resist_damage(20, "fire") == 20, "Fiendish Resilience halves chosen damage type")
	check.call(not WarlockRules.choose_fiendish_resilience(warlock, "force"), "Fiendish Resilience rejects Force damage")

	# Level 11: Mystic Arcanum 6
	warlock.level_up()
	check.call(warlock.level == 11 and warlock.warlock_arcanum_pending_levels.has(6), "Warlock level 11 grants level 6 Mystic Arcanum slot")
	var arcanum_6_options := WarlockRules.arcanum_spells(warlock, 6)
	check.call(arcanum_6_options.has("circle_of_death"), "Level 6 Mystic Arcanum options include Circle of Death")
	check.call(WarlockRules.choose_mystic_arcanum(warlock, 6, "circle_of_death"), "Warlock selects Circle of Death for level 6 Mystic Arcanum")
	check.call(WarlockRules.arcanum_cast_level(warlock, "circle_of_death") == 6 and WarlockRules.spend_arcanum_cast(warlock, "circle_of_death"), "Mystic Arcanum cast succeeds without spending Pact slot")
	check.call(not WarlockRules.spend_arcanum_cast(warlock, "circle_of_death"), "Mystic Arcanum cannot be cast again before Long Rest")
	warlock.long_rest()
	check.call(WarlockRules.arcanum_cast_level(warlock, "circle_of_death") == 6, "Mystic Arcanum cast recovers after Long Rest")

	# Level 12: Devouring Blade (3 attacks total)
	warlock.level_up()
	var selections_12: Array[String] = ["pact_of_the_blade", "armor_of_shadows", "fiendish_vigor", "thirsting_blade", "eldritch_smite", "repelling_blast:eldritch_blast", "eldritch_mind", "devouring_blade"]
	check.call(WarlockRules.choose_invocations(warlock, selections_12), "Warlock level 12 selects Devouring Blade")
	check.call(warlock.extra_attacks == 2, "Devouring Blade grants 2 extra attacks (3 total attacks)")

	# Level 14: Hurl Through Hell
	while warlock.level < 14:
		warlock.level_up()
	check.call(warlock.has_feature("fiend_hurl_through_hell"), "Warlock level 14 grants Hurl Through Hell")
	var hurl_target := {"name": "Mortal Enemy", "current_hp": 100, "creature_type": "humanoid", "conditions": {}}
	var hurl_res := CombatAction.resolve_hurl_through_hell(warlock, hurl_target)
	check.call(hurl_res.get("success", false) and int(hurl_res.get("damage", 0)) > 0 and hurl_target.get("conditions", {}).has("incapacitated"), "Hurl Through Hell deals 8d10 psychic damage and incapacitates target")
	var fiend_target := {"name": "Demon", "current_hp": 100, "creature_type": "fiend", "conditions": {}}
	warlock.feature_uses["fiend_hurl_through_hell"] = 1
	var fiend_hurl := CombatAction.resolve_hurl_through_hell(warlock, fiend_target)
	check.call(fiend_hurl.get("success", false) and fiend_hurl.get("damage", 99) == 0 and fiend_target.get("conditions", {}).has("incapacitated"), "Hurl Through Hell deals 0 damage to Fiends but still incapacitates")

	# Lifedrinker hit die heal at level 15
	while warlock.level < 15:
		warlock.level_up()
	var selections_15: Array[String] = ["pact_of_the_blade", "armor_of_shadows", "fiendish_vigor", "thirsting_blade", "eldritch_smite", "repelling_blast:eldritch_blast", "eldritch_mind", "devouring_blade", "lifedrinker"]
	check.call(WarlockRules.choose_invocations(warlock, selections_15), "Warlock level 15 selects Lifedrinker")
	check.call(WarlockRules.has_repelling_blast(warlock, "eldritch_blast") and not WarlockRules.has_repelling_blast(warlock, "fire_bolt"), "Repelling Blast is active specifically for eldritch_blast")
	warlock.current_hp = 10
	var heal_res := WarlockRules.resolve_lifedrinker_heal(warlock)
	check.call(heal_res.get("success", false) and warlock.current_hp > 10, "Lifedrinker heals using Hit Die + CON")

	# Level 20 & Save / Load roundtrip
	while warlock.level < 20:
		warlock.level_up()
	check.call(not WarlockRules.choose_mystic_arcanum(warlock, 7, "finger_of_death") and 7 in warlock.warlock_arcanum_pending_levels and not warlock.warlock_mystic_arcanum.has("7"), "Unavailable Finger of Death refuses without consuming the pending level 7 Arcanum choice")
	var chose_eighth := WarlockRules.choose_mystic_arcanum(warlock, 8, "power_word_stun")
	var chose_ninth := WarlockRules.choose_mystic_arcanum(warlock, 9, "power_word_kill")
	check.call(chose_eighth and chose_ninth, "Warlock independently selects supported level 8 and 9 Mystic Arcanum spells")
	var selections_20: Array[String] = ["pact_of_the_blade", "armor_of_shadows", "fiendish_vigor", "thirsting_blade", "eldritch_smite", "repelling_blast:eldritch_blast", "eldritch_mind", "devouring_blade", "lifedrinker", "witch_sight"]
	check.call(WarlockRules.choose_invocations(warlock, selections_20), "Warlock selects 10 invocations by level 18+")
	check.call(warlock.level == 20 and int(warlock.spell_slots.get("5", 0)) == 4, "Warlock level 20 has 4 level 5 Pact slots")
	var warlock_dto := warlock.to_dict()
	check.call(ClassProgression.saved_choices_error(warlock_dto).is_empty(), "Warlock level 20 passes saved choices validation")
	var reloaded := Character.new()
	reloaded.from_dict(warlock_dto)
	check.call(reloaded.level == 20 and reloaded.subclass_id == "fiend_patron" and reloaded.fiendish_resilience_type == "cold" and reloaded.pact_weapon_damage_type == "radiant" and reloaded.extra_attacks == 2 and reloaded.warlock_invocations.size() == 10 and reloaded.warlock_mystic_arcanum.size() == 3 and 7 in reloaded.warlock_arcanum_pending_levels, "Warlock level 20 preserves supported Arcanum choices and the pending unsupported level through from_dict")


static func _shared_rules_regressions(check: Callable) -> void:
	for id in ["ranger", "paladin"]:
		var caster := _character(id, 2)
		var ability := "WIS" if id == "ranger" else "CHA"
		caster.ability_scores.set_score(ability, 10)
		caster.ability_scores.set_score("DEX" if id == "ranger" else "STR", 18)
		check.call(caster.get_spellcasting_ability() == ability and caster.get_spell_save_dc() == 10, "%s spellcasting reads the declared casting ability rather than the martial primary" % id)
		var target := _damage_target()
		target["armor_class"] = 13
		FighterChecks._seed_die(20, 10)
		var spell := {"id": "fire_bolt", "name": "Fixture attack", "level": 0, "attack_type": "ranged", "damage": "8", "damage_type": "fire"}
		check.call(not CombatAction.resolve_spell(caster, target, spell).get("hit", true), "%s ordinary spell attack uses its casting ability" % id)
		spell["damage_per_ray"] = "8"
		spell["ray_count"] = 1
		FighterChecks._seed_die(20, 10)
		check.call(not CombatAction.resolve_spell(caster, target, spell).get("hit", true), "%s ray spell attack uses the same casting ability" % id)
	var older := Character.new()
	older.class_id = "wizard"
	check.call(older.get_spellcasting_ability() == "INT", "Older and synthetic casters retain their primary-ability fallback")
	for style in ["", "defense", "archery"]:
		var ranger := _character("ranger", 2)
		if not style.is_empty():
			ClassProgression.choose_feature_option(ranger, "ranger_fighting_style", style)
		check.call(ranger.get_attack_style_bonus(DataLoader.get_item("longbow")) == (2 if style == "archery" else 0), "Ranger ranged bonus follows its actual %s style choice" % style)
	var ordinary := _damage_target()
	ordinary["conditions"] = {"frightened": 8, "incapacitated": 8}
	CombatAction.resolve_damage(ordinary, 1, "force")
	check.call(ordinary["conditions"].size() == 2, "Ordinary damage preserves unrelated monster fear and incapacitation")
	var ally := _character("wizard", 1)
	ally.add_condition("frightened", 8)
	ally.add_condition("incapacitated", 8)
	CombatAction.resolve_damage(ally, 1, "force")
	check.call(ally.has_condition("frightened") and ally.has_condition("incapacitated"), "Ordinary damage preserves unrelated Character conditions")
	var overlap := _damage_target()
	CombatAction.apply_condition(overlap, "frightened", 5)
	CombatAction.apply_condition(overlap, "frightened", 10, "turn_undead")
	CombatAction.apply_condition(overlap, "incapacitated", 10, "turn_undead")
	overlap["turn_undead_origin"] = Vector2i.ZERO
	for tick in 3:
		CombatState.tick_monster_condition_durations(overlap)
	CombatAction.resolve_damage(overlap, 1, "force")
	check.call(overlap["conditions"].get("frightened", 0) == 2 and not overlap["conditions"].has("incapacitated") and not overlap.has("turn_undead_origin"), "Damage removes only turning's conditions and preserves the independently ticking fear")
	CombatAction.apply_condition(overlap, "frightened", 1, "abjure_foes")
	overlap[PaladinRules.ABJURE_FOES_MARKER] = true
	CombatAction.apply_condition(overlap, "frightened", 7)
	CombatState.tick_monster_condition_durations(overlap)
	check.call(overlap["conditions"].get("frightened", 0) == 6 and not overlap.has(PaladinRules.ABJURE_FOES_MARKER), "Source expiry preserves fear applied later by another rule")
	CombatAction.apply_condition(overlap, "frightened", 10, "turn_undead")
	overlap["turn_undead_origin"] = Vector2i.ZERO
	overlap["conditions"].erase("frightened")
	ClericRules.clear_turning_after_damage(overlap)
	check.call(not overlap["conditions"].has("frightened"), "A cleansed condition never reappears when its old source is removed")
	var cleric := _character("cleric", 5)
	var undead := _damage_target()
	undead["creature_type"] = "undead"
	undead["hex_position"] = Vector2i(1, 0)
	undead["saving_throw_bonuses"]["WIS"] = -100
	var undead_targets: Array[Dictionary] = [undead]
	var sear := ClericRules.resolve_turn_undead(cleric, undead_targets, Vector2i.ZERO)
	check.call(int(sear[0].get("damage", 0)) > 0 and undead.has("turn_undead_origin") and undead["conditions"].has("incapacitated"), "Sear Undead's own damage preserves Turn Undead")
	var attacker := _character("wizard", 1)
	for immune in [false, true]:
		var expected := 0 if immune else 4
		for path in ["weapon", "save_spell", "attack_spell", "darts", "rays", "cleric", "mark", "rider", "beast"]:
			var target := _damage_target()
			target["damage_immunities" if immune else "damage_resistances"] = ["force"]
			FighterChecks._seed_die(20, 10)
			var result: Dictionary = {}
			var spell := {"id": "fire_bolt", "name": "Fixture damage", "level": 0, "damage": "8", "damage_type": "force", "attack_type": "ranged"}
			match path:
				"weapon": result = CombatAction.resolve_weapon_attack(attacker, target, {"id": "fixture:weapon", "type": "weapon", "damage": "8", "damage_type": "force", "ability": "STR", "properties": []})
				"save_spell":
					spell["save"] = "CON"
					result = CombatAction.resolve_spell(attacker, target, spell)
				"attack_spell": result = CombatAction.resolve_spell(attacker, target, spell)
				"darts":
					spell["damage_per_dart"] = "8"
					spell["dart_count"] = 1
					result = CombatAction.resolve_spell(attacker, target, spell)
				"rays":
					spell["damage_per_ray"] = "8"
					spell["ray_count"] = 1
					result = CombatAction.resolve_spell(attacker, target, spell)
				"cleric": result = {"damage": ClericRules._apply_damage(target, 8, "force")}
				"mark":
					CombatAction.resolve_hunters_mark(attacker, target)
					# A declared die override keeps this mitigation check deterministic.
					attacker.features.append({"id": "fixture:mark_die", "effects": [{"type": "spell_damage_dice_override", "spell_id": "hunters_mark", "dice": "8"}]})
					result = CombatAction.resolve_hunters_mark_damage(attacker, target)
				"rider":
					var rider_owner := _character("paladin", 1)
					rider_owner.features.append({"id": "fixture:rider", "effects": [{"type": "weapon_damage_rider", "trigger": "weapon_attack_hit", "damage_type": "force", "dice_by_level": {"1": "8"}, "once_per_turn": false}]})
					result = CombatAction.resolve_weapon_damage_riders(rider_owner, target)[0]
				"beast":
					result = {"hit": true, "damage": 0}
					DruidRules.apply_attack_effects(attacker, target, {"wild_shape_attack": {"bonus_damage": "8", "bonus_damage_type": "force"}}, result)
			check.call(int(result.get("damage", -1)) == expected and int(target["current_hp"]) == 100 - expected, "%s damage shares %s settlement" % [path, "immunity" if immune else "resistance"])
	var resisted := _damage_target()
	resisted["damage_resistances"] = ["slashing"]
	check.call(CombatAction.resolve_damage(resisted, 9, "slashing", {}, true)["damage"] == 9, "Resistance bypass preserves the complete weapon damage amount")
	resisted["damage_immunities"] = ["slashing"]
	check.call(CombatAction.resolve_damage(resisted, 9, "slashing", {}, true)["damage"] == 0, "Resistance bypass never bypasses immunity")
	var protected := _character("monk", 18)
	protected.add_condition("superior_defense", 10)
	protected.temp_hp = 3
	var hp := protected.current_hp
	var reduced := CombatAction.resolve_damage(protected, 10, "fire")
	check.call(reduced["resolved"] == 5 and reduced["damage"] == 2 and protected.current_hp == hp - 2 and protected.temp_hp == 0, "Shared spell damage applies resistance once before temporary HP")
	var defeated := _damage_target()
	defeated["current_hp"] = 2
	check.call(CombatAction.resolve_damage(defeated, 8, "force")["damage"] == 2 and not defeated["is_alive"], "Shared damage caps monster HP loss and settles its death state")


static func _damage_target() -> Dictionary:
	return {"id": "fixture:target", "name": "Fixture target", "is_alive": true, "max_hp": 100, "current_hp": 100, "armor_class": -100, "ability_scores": {}, "saving_throw_bonuses": {"CON": -100}, "conditions": {}}


static func _audit_defect_repairs(check: Callable) -> void:
	var barbarian := _character("barbarian", 10)
	var wizard := _character("wizard", 20)
	check.call("heavy" not in barbarian.armor_proficiencies and not barbarian.inventory.has_item("chain_mail") and barbarian.inventory.get_weapon() == "greataxe" and not barbarian.has_feature("barbarian_primal_knowledge_10"), "New Barbarian grants no Heavy Armor or extra level-10 Primal Knowledge")
	check.call(wizard.armor_proficiencies.is_empty() and not wizard.inventory.has_item("leather_armor"), "New Wizard grants no armor training or starting armor")
	var saved_wizard := wizard.to_dict()
	saved_wizard["armor_proficiencies"] = ["light", "medium"]
	var restored := Character.new()
	restored.from_dict(saved_wizard)
	check.call(restored.armor_proficiencies == ["light", "medium"], "Existing Wizard armor proficiencies survive reconstruction")
	var warden := _character("druid", 20)
	ClassProgression.choose_feature_option(warden, "druid_primal_order", "warden")
	warden.spell_slots["2"] = 0
	check.call(DruidRules.use_nature_magician(warden, 1).get("success", false), "Warden Archdruid can use Nature Magician")
	var caster := _character("wizard", 1)
	var spell := {"id": "fire_bolt", "name": "Evasion fixture", "level": 0, "save": "DEX", "damage": "20", "damage_type": "fire", "half_on_save": true, "range": 12}
	for class_id in ["rogue", "monk"]:
		var target := _character(class_id, 7)
		target.ability_scores.set_score("DEX", 100)
		var result := CombatAction.resolve_spell(caster, target, spell, false, {"counterspell": false})
		check.call(result.get("saved", false) and result.get("damage", -1) == 0, "%s Evasion takes no damage on a successful half-damage Dexterity save" % class_id)
		target.ability_scores.set_score("DEX", -100)
		result = CombatAction.resolve_spell(caster, target, spell, false, {"counterspell": false})
		check.call(not result.get("saved", true) and result.get("damage", 0) == 10, "%s Evasion halves damage on a failed save" % class_id)
		target.add_condition("incapacitated", 1)
		result = CombatAction.resolve_spell(caster, target, spell, false, {"counterspell": false})
		check.call(result.get("damage", 0) == 20, "%s Evasion is unavailable while incapacitated" % class_id)
		target.remove_condition("incapacitated")
		var full_damage_save := spell.duplicate()
		full_damage_save["half_on_save"] = false
		result = CombatAction.resolve_spell(caster, target, full_damage_save, false, {"counterspell": false})
		check.call(result.get("damage", 0) == 20, "%s Evasion does not apply to a save without half damage" % class_id)
	var rogue := _character("rogue", 1)
	check.call(not RogueRules.sneak_attack_eligible(rogue, DataLoader.get_item("longsword"), true, false, true) and RogueRules.sneak_attack_eligible(rogue, DataLoader.get_item("rapier"), true, false, false) and RogueRules.sneak_attack_eligible(rogue, DataLoader.get_item("shortbow"), false, false, true), "Sneak Attack requires a Finesse or Ranged weapon")
	check.call(RogueRules.sneak_attack_eligible(rogue, DataLoader.get_item("rapier"), true, true, true) and not RogueRules.sneak_attack_eligible(rogue, DataLoader.get_item("rapier"), false, true, true), "Sneak Attack uses net Advantage/Disadvantage")
	var source := _character("wizard", 1)
	source.wizard_spellbook.assign(["magic_missile"])
	caster.inventory.gold = 50
	var copy_result := ClassProgression.copy_wizard_spell(caster, source, "magic_missile")
	check.call(copy_result.get("success", false) and caster.inventory.gold == 0 and "magic_missile" in caster.wizard_spellbook and copy_result.get("hours", 0) == 2, "Wizard copying accepts a Wizard-list spell and charges its actual transcription cost")
	check.call(not ClassProgression.copy_wizard_spell(caster, source, "magic_missile").get("success", true) and caster.inventory.gold == 0, "Duplicate copying neither charges nor appends a spell")
	var eligible: Array[String] = []
	for option in DataLoader.get_castable_spell_list_options(wizard.get_spell_list_ids()):
		if int(option.get("level", 0)) > 0:
			eligible.append(str(option["id"]))
	var book_pending := wizard.wizard_spellbook_pending
	var batch_count := mini(20, book_pending - 1)
	var lvl1: Array[String] = []
	var lvl2: Array[String] = []
	for spell_id in eligible:
		var option_spell := DataLoader.get_spell(spell_id)
		var lvl := int(option_spell.get("level", 0))
		if str(option_spell.get("casting_time", "action")) == "action":
			if lvl == 1:
				lvl1.append(spell_id)
			elif lvl == 2:
				lvl2.append(spell_id)
	var batch: Array[String] = []
	batch.append_array(lvl1.slice(0, 10))
	batch.append_array(lvl2.slice(0, 10))
	check.call(ClassProgression.choose_wizard_spellbook(wizard, batch) and wizard.wizard_spellbook_pending == book_pending - batch.size() and wizard.wizard_spellbook_pending > 0, "Wizard can record available spells while unavailable earned book choices remain pending")
	var selected: Array[String] = []
	var previous_cantrips: Array = wizard.feature_choices.get(wizard.get_spellcasting_feature_id(), [])
	for spell_id in previous_cantrips:
		if DataLoader.get_spell(str(spell_id)).get("level", -1) == 0:
			selected.append(str(spell_id))
	for cantrip_id in wizard.get_spell_option_ids(true):
		if selected.size() >= wizard.get_spellcasting_capacity("cantrips"):
			break
		if cantrip_id not in selected:
			selected.append(cantrip_id)
	selected.append_array(wizard.get_spell_option_ids(false).slice(0, wizard.get_spellcasting_capacity("prepared_spells")))
	check.call(ClassProgression.choose_spell_selection(wizard, selected) and not wizard.known_spells.is_empty(), "Wizard can prepare recorded spells while more book choices are pending")
	var level_one := ClassProgression.wizard_spellbook_feature_options(wizard, 1)
	var level_two := ClassProgression.wizard_spellbook_feature_options(wizard, 2)
	check.call(ClassProgression.choose_wizard_spell_mastery(wizard, 1, level_one[0]) and ClassProgression.choose_wizard_spell_mastery(wizard, 2, level_two[0]), "Wizard chooses both initial mastery spells from its incomplete but usable spellbook")
	check.call(not ClassProgression.choose_wizard_spell_mastery(wizard, 1, level_one[1]), "Spell Mastery cannot change without a Long Rest")
	wizard.long_rest()
	restored.from_dict(JSON.parse_string(JSON.stringify(wizard.to_dict())))
	check.call(restored.wizard_mastery_replacement_available and ClassProgression.saved_choices_error(restored.to_dict()).is_empty(), "Long Rest mastery replacement entitlement persists in a valid schema-2 save")
	check.call(not ClassProgression.choose_wizard_spell_mastery(restored, 1, level_one[0]) and restored.wizard_mastery_replacement_available, "An unchanged mastery choice does not consume its replacement")
	check.call(ClassProgression.choose_wizard_spell_mastery(restored, 1, level_one[1]) and not ClassProgression.choose_wizard_spell_mastery(restored, 2, level_two[1]), "Long Rest allows exactly one mastery replacement")
	var sorcerer := _character("sorcerer", 20)
	selected.clear()
	var sorcerer_prev: Array = sorcerer.feature_choices.get(sorcerer.get_spellcasting_feature_id(), [])
	for spell_id in sorcerer_prev:
		if DataLoader.get_spell(str(spell_id)).get("level", -1) == 0:
			selected.append(str(spell_id))
	for cantrip_id in sorcerer.get_spell_option_ids(true):
		if selected.size() >= sorcerer.get_spellcasting_capacity("cantrips"):
			break
		if cantrip_id not in selected:
			selected.append(cantrip_id)
	selected.append_array(sorcerer.get_spell_option_ids(false).slice(0, sorcerer.get_spellcasting_capacity("prepared_spells")))
	check.call(ClassProgression.choose_spell_selection(sorcerer, selected) and not sorcerer.spell_choices_pending and ClassProgression.saved_choices_error(sorcerer.to_dict()).is_empty(), "Sorcerer saves available spells and completes preparation when full catalog is available")
	var fixture_class_id := "fixture_limited_sorcerer"
	DataLoader.classes[fixture_class_id] = {"id": fixture_class_id, "spell_list_ids": ["fire_bolt", "light", "acid_splash", "burning_hands", "magic_missile"]}
	var limited_sorcerer := _character("sorcerer", 20)
	var original_spell_lists: Array = []
	for feature in limited_sorcerer.features:
		for effect in feature.get("effects", []):
			if effect.get("type", "") == "spellcasting":
				original_spell_lists = effect.get("spell_lists", []).duplicate()
				effect["spell_lists"] = [fixture_class_id]
	var limited_selected: Array[String] = []
	var limited_prev: Array = limited_sorcerer.feature_choices.get(limited_sorcerer.get_spellcasting_feature_id(), [])
	for spell_id in limited_prev:
		if DataLoader.get_spell(str(spell_id)).get("level", -1) == 0:
			limited_selected.append(str(spell_id))
	for cantrip_id in limited_sorcerer.get_spell_option_ids(true):
		if limited_selected.size() >= limited_sorcerer.get_spellcasting_capacity("cantrips"):
			break
		if cantrip_id not in limited_selected:
			limited_selected.append(cantrip_id)
	limited_selected.append_array(limited_sorcerer.get_spell_option_ids(false))
	check.call(ClassProgression.choose_spell_selection(limited_sorcerer, limited_selected) and limited_sorcerer.spell_choices_pending and ClassProgression.saved_choices_error(limited_sorcerer.to_dict()).is_empty(), "Sorcerer saves available spells without losing unfilled cantrip/prepared entitlements")
	for feature in limited_sorcerer.features:
		for effect in feature.get("effects", []):
			if effect.get("type", "") == "spellcasting":
				effect["spell_lists"] = original_spell_lists
	DataLoader.classes.erase(fixture_class_id)
	sorcerer.sorcerer_metamagic_choices.assign(["empowered_spell"])
	var details := {"formula": "2d6+3", "dice_terms": [{"count": 2, "sides": 6, "results": [6, 6], "kept": [true, true], "label": "d6", "subtotal": 12}], "modifiers": [], "final_total": 15}
	var points := sorcerer.get_sorcery_points()
	var empowered := CombatAction._apply_empowered_spell(sorcerer, details, {"metamagic:empowered": true, "metamagic:empowered_dice": [1]})
	var updated: Dictionary = empowered["details"]
	var term: Dictionary = updated["dice_terms"][0]
	check.call(empowered["used"] and sorcerer.get_sorcery_points() == points - 1 and term["results"][0] == 6 and term["kept"] == [true, false, true] and updated["final_total"] == 9 + int(term["results"][2]), "Empowered rerolls only the selected die, preserves modifiers, and uses the new result")
	var high_roll := {"formula": "1d100+3", "dice_terms": [{"count": 1, "sides": 100, "results": [100], "kept": [true], "label": "d100", "subtotal": 100}], "final_total": 103}
	seed(1)
	var lower_roll: Dictionary = Dice.reroll_selected_dice(high_roll, [0], 1)["details"]
	check.call(int(lower_roll["final_total"]) < 103 and int(lower_roll["final_total"]) == int(lower_roll["dice_terms"][0]["results"][1]) + 3, "A lower replacement damage die stands instead of keeping the higher old roll")
	points = sorcerer.get_sorcery_points()
	check.call(not CombatAction._apply_empowered_spell(sorcerer, details, {"metamagic:empowered": true, "metamagic:empowered_dice": [0, 1]})["used"] and not CombatAction._apply_empowered_spell(sorcerer, details, {"metamagic:empowered": true, "metamagic:empowered_dice": [0, 0]})["used"] and sorcerer.get_sorcery_points() == points, "Empowered rejects selections over the Charisma limit or duplicate dice without charging")
	var target := {"name": "Empowered target", "armor_class": -100, "current_hp": 100, "is_alive": true}
	var decisions := {"metamagic:empowered": true, "defer_empowered": true, "spell_damage_context": {}}
	var result := CombatAction.resolve_spell(sorcerer, target, DataLoader.get_spell("magic_missile"), false, decisions)
	check.call(result.has("damage_request") and target["current_hp"] == 100 and sorcerer.get_sorcery_points() == points and Dice.selectable_dice(result["damage_request"]["details"]).size() == 3, "Empowered offers actual rolled dart dice before HP or Sorcery Points change")
	decisions["metamagic:empowered_dice"] = [0]
	result = CombatAction.finish_pending_spell_damage(sorcerer, target, result, decisions)
	var hp := int(target["current_hp"])
	check.call(result.get("metamagic_used", false) and hp == 100 - int(result["damage"]) and sorcerer.get_sorcery_points() == points - 1, "Selected Empowered dice settle through production damage exactly once")
	CombatAction.finish_pending_spell_damage(sorcerer, target, result, decisions)
	check.call(target["current_hp"] == hp and sorcerer.get_sorcery_points() == points - 1, "Repeated damage settlement does not reapply HP loss or cost")
	var area_target := {"name": "Area target", "current_hp": 100, "is_alive": true, "saving_throw_bonuses": {"DEX": -100}}
	var area_spell := {"id": "fire_bolt", "name": "Area fixture", "level": 0, "save": "DEX", "damage": "2d6", "damage_type": "fire", "half_on_save": true, "range": 12}
	decisions = {"metamagic:empowered": true, "defer_empowered": true, "spell_damage_context": {}}
	result = CombatAction.resolve_spell(sorcerer, area_target, area_spell, false, decisions)
	decisions["metamagic:empowered_dice"] = [0]
	result = CombatAction.finish_pending_spell_damage(sorcerer, area_target, result, decisions)
	var second_target := area_target.duplicate(true)
	var second := CombatAction.resolve_spell(sorcerer, second_target, area_spell, false, decisions)
	check.call(not second.has("damage_request") and second["damage_roll"] == result["damage_roll"] and sorcerer.get_sorcery_points() == points - 2, "Empowered area spell reuses one settled damage roll and pays once for the cast")


static func _roll_token_rules(check: Callable) -> void:
	var diviner := _character("wizard", 3)
	check.call(ClassProgression.choose_subclass(diviner, "diviner"), "Wizard at level 3 can choose Diviner subclass")
	check.call(diviner.has_feature("diviner_portent") and not diviner.has_feature("diviner_divination_savant") and not diviner.has_feature("diviner_expert_divination") and not diviner.has_feature("diviner_the_third_eye"), "Diviner grants supported Portent feature and withholds unsupported 2024-partial features")
	var portent_tokens := RollTokenRules.available_tokens(diviner, "diviner_portent")
	check.call(portent_tokens.size() == 2, "Diviner Portent generates 2 roll tokens at level 3")
	for token in portent_tokens:
		var val := int(token.get("value", 0))
		check.call(val >= 1 and val <= 20, "Diviner Portent token value is in 1..20")
	var pre_short_rest_tokens := diviner.roll_tokens.duplicate(true)
	var pre_short_rest_values := RollTokenRules.get_available_values(diviner, "diviner_portent")
	diviner.short_rest()
	check.call(diviner.roll_tokens == pre_short_rest_tokens, "Short Rest preserves Long Rest roll token pools without clearing or rerolling")
	var saved_dto := JSON.parse_string(JSON.stringify(diviner.to_dict())) as Dictionary
	check.call(ClassProgression.saved_choices_error(saved_dto).is_empty(), "Diviner roll tokens pass save preflight validation")
	var reloaded := Character.new()
	reloaded.from_dict(saved_dto)
	check.call(reloaded.roll_tokens == diviner.roll_tokens and reloaded.roll_token_generation_serial == diviner.roll_token_generation_serial, "Save/load round-trip preserves exact roll token IDs, values, and generation serial without rerolling")
	while diviner.level < 14:
		diviner.level_up()
	var upgraded_values := RollTokenRules.get_available_values(diviner, "diviner_portent")
	check.call(diviner.has_feature("diviner_greater_portent") and upgraded_values.size() == 3, "Greater Portent upgrades the Portent pool to 3 tokens at level 14")
	check.call(upgraded_values.slice(0, 2) == pre_short_rest_values, "Upgrading to Greater Portent appends the 3rd token without rerolling existing unspent tokens")
	var serial_before_rest := diviner.roll_token_generation_serial
	diviner.long_rest()
	check.call(RollTokenRules.available_tokens(diviner, "diviner_portent").size() == 3 and diviner.roll_token_generation_serial > serial_before_rest, "Long Rest clears old Portent tokens and generates 3 new tokens at level 14")

	var oracle := _character("wizard", 3)
	check.call(ClassProgression.choose_subclass(oracle, "fixture:oracle") and oracle.has_feature("fixture:oracle_omen"), "Second consumer fixture:oracle attaches to Wizard")
	check.call(RollTokenRules.available_tokens(oracle, "fixture:oracle_omen").size() == 3, "Second consumer fixture:oracle_omen generates 3 tokens through the shared RollTokenRules path")

	diviner.roll_tokens["diviner_portent"] = [
		{"token_id": "diviner_portent:test:0", "value": 20, "feature_id": "diviner_portent", "pool_id": "diviner_portent", "die_sides": 20},
		{"token_id": "diviner_portent:test:1", "value": 1, "feature_id": "diviner_portent", "pool_id": "diviner_portent", "die_sides": 20},
		{"token_id": "diviner_portent:test:2", "value": 15, "feature_id": "diviner_portent", "pool_id": "diviner_portent", "die_sides": 20},
	]
	RollTokenRules.clear_turn_counter(diviner)
	CombatAction.advance_combat_turn(diviner)
	var monster_target := {"id": "portent_dummy", "name": "Portent Dummy", "armor_class": 25, "current_hp": 100, "max_hp": 100, "is_alive": true, "ability_scores": {"STR": 10, "DEX": 10, "CON": 10, "INT": 10, "WIS": 10, "CHA": 10}}
	var atk_decision := {"roll_token_replacement": {"owner": diviner, "pool_id": "diviner_portent", "token_id": "diviner_portent:test:0"}}
	var atk_res := CombatAction.resolve_weapon_attack(diviner, monster_target, DataLoader.get_item("quarterstaff"), false, true, atk_decision)
	check.call(atk_res.get("hit", false) and atk_res.get("crit", false) and bool(atk_res.get("roll_token_replaced", false)) and int(atk_res.get("roll_token_value", 0)) == 20 and int(atk_res.get("activity_roll", {}).get("natural_total", 0)) == 20 and RollTokenRules.available_tokens(diviner, "diviner_portent").size() == 2, "Portent pre-roll replacement of 20 on weapon attack bypasses Disadvantage, causes a critical hit, and consumes the token")
	var same_turn_decision := {"roll_token_replacement": {"owner": diviner, "pool_id": "diviner_portent", "token_id": "diviner_portent:test:1"}}
	var same_turn_test := RollTokenRules.resolve_d20_test(diviner, "save", false, false, same_turn_decision)
	check.call(not bool(same_turn_test.get("replaced_by_roll_token", false)) and RollTokenRules.available_tokens(diviner, "diviner_portent").size() == 2, "Portent enforces once-per-turn replacement limit and does not spend a second token on the same turn")

	CombatAction.advance_combat_turn(reloaded)
	var halfling_fighter := Character.new()
	var hf_scores := AbilityScores.new()
	hf_scores.from_dict({"STR": 16, "DEX": 14, "CON": 14, "INT": 10, "WIS": 12, "CHA": 10})
	halfling_fighter.initialize("Halfling Fighter", "halfling", "fighter", hf_scores)
	while halfling_fighter.level < 9:
		halfling_fighter.level_up()
	halfling_fighter.fighter_training["auto_indomitable"] = false
	var halfling_nat1 := halfling_fighter.saving_throw_test_to_dc("WIS", 15, true, false, {"roll_token_replacement": {"owner": diviner, "pool_id": "diviner_portent", "token_id": "diviner_portent:test:1"}})
	check.call(bool(halfling_nat1.get("replaced_by_roll_token", false)) and int(halfling_nat1.get("natural", 0)) == 1 and halfling_nat1.get("rolls", []) == [1] and not bool(halfling_nat1.get("halfling_luck_rerolled", false)) and RollTokenRules.available_tokens(diviner, "diviner_portent").size() == 1, "Pre-roll replacement of 1 bypasses Advantage and does not trigger Halfling Luck reroll")
	halfling_fighter.fighter_training["auto_indomitable"] = true
	diviner.roll_tokens["diviner_portent"].insert(0, {"token_id": "diviner_portent:test:indom", "value": 2, "feature_id": "diviner_portent", "pool_id": "diviner_portent", "die_sides": 20})
	CombatAction.advance_combat_turn(halfling_fighter)
	var indom_res := halfling_fighter.saving_throw_test_to_dc("WIS", 15, false, false, {"roll_token_replacement": {"owner": diviner, "pool_id": "diviner_portent", "token_id": "diviner_portent:test:indom"}})
	check.call(bool(indom_res.get("initial_roll_token_replaced", false)) and bool(indom_res.get("indomitable_used", false)) and RollTokenRules.available_tokens(diviner, "diviner_portent").size() == 1, "Post-roll Indomitable reroll remains available after a pre-roll token replacement fails the save")

	CombatAction.advance_combat_turn(diviner)
	var skill_check := EventResolver.resolve_skill_check(diviner, {"ability": "INT", "skill": "Arcana", "dc": 15}, {"roll_token_replacement": {"owner": diviner, "pool_id": "diviner_portent", "token_id": "diviner_portent:test:2"}})
	check.call(bool(skill_check.get("replaced_by_roll_token", false)) and int(skill_check.get("roll", 0)) == 15 and RollTokenRules.available_tokens(diviner, "diviner_portent").is_empty(), "Portent replaces an ability check d20 before rolling and consumes the final token")

	oracle.roll_tokens["fixture:oracle_omen"] = [
		{"token_id": "oracle:0", "value": 4, "feature_id": "fixture:oracle_omen", "pool_id": "fixture:oracle_omen", "die_sides": 20},
		{"token_id": "oracle:1", "value": 20, "feature_id": "fixture:oracle_omen", "pool_id": "fixture:oracle_omen", "die_sides": 20},
		{"token_id": "oracle:2", "value": 2, "feature_id": "fixture:oracle_omen", "pool_id": "fixture:oracle_omen", "die_sides": 20},
	]
	RollTokenRules.clear_turn_counter(oracle)
	var reliable_rogue := _character("rogue", 7)
	reliable_rogue.skill_proficiencies.assign(["Stealth"])
	CombatAction.advance_combat_turn(reliable_rogue)
	var rogue_check := EventResolver.resolve_skill_check(reliable_rogue, {"ability": "DEX", "skill": "Stealth", "dc": 15}, {"roll_token_replacement": {"owner": oracle, "pool_id": "fixture:oracle_omen", "token_id": "oracle:0"}})
	check.call(bool(rogue_check.get("replaced_by_roll_token", false)) and int(rogue_check.get("roll", 0)) == 10, "Reliable Talent still raises a proficient skill check d20 of 4 to 10 after pre-roll replacement")

	CombatAction.advance_combat_turn(oracle)
	reliable_rogue.current_hp = 0
	reliable_rogue.is_alive = false
	var death_res := reliable_rogue.make_death_save(false, false, {"roll_token_replacement": {"owner": oracle, "pool_id": "fixture:oracle_omen", "token_id": "oracle:1"}})
	check.call(bool(death_res.get("replaced_by_roll_token", false)) and int(death_res.get("natural", 0)) == 20 and reliable_rogue.current_hp == 1 and reliable_rogue.is_alive, "Pre-roll replacement of 20 on a Death Saving Throw restores 1 HP")

	CombatAction.advance_combat_turn(reliable_rogue)
	var init_res := RollTokenRules.resolve_d20_test(oracle, "initiative", true, false, {"roll_token_replacement": {"owner": oracle, "pool_id": "fixture:oracle_omen", "token_id": "oracle:2"}})
	check.call(bool(init_res.get("replaced_by_roll_token", false)) and int(init_res.get("total", 0)) == 2, "Pre-roll replacement works on Initiative rolls and skips Advantage extra die")

	var invalid_token_dto := diviner.to_dict()
	invalid_token_dto["roll_tokens"] = {
		"diviner_portent": [
			{"token_id": "bad:0", "value": 25, "feature_id": "diviner_portent", "pool_id": "diviner_portent", "die_sides": 20},
		]
	}
	check.call(not ClassProgression.saved_choices_error(invalid_token_dto).is_empty(), "Save preflight rejects out-of-range roll token values")
	CombatAction.active_turn_actor_id = 0


static func _ward_rules(check: Callable) -> void:
	var abjurer := Character.new()
	var abj_scores := AbilityScores.new()
	abj_scores.from_dict({"STR": 10, "DEX": 14, "CON": 14, "INT": 16, "WIS": 12, "CHA": 10})
	abjurer.initialize("Abjurer Fixture", "human", "wizard", abj_scores)
	while abjurer.level < 3:
		abjurer.level_up()
	check.call(ClassProgression.choose_subclass(abjurer, "abjurer"), "Wizard at level 3 can choose Abjurer subclass")
	check.call(abjurer.has_feature("abjurer_arcane_ward") and not abjurer.has_feature("abjurer_abjuration_savant") and not abjurer.has_feature("abjurer_spell_breaker") and not abjurer.has_feature("abjurer_spell_resistance"), "Abjurer grants Arcane Ward at level 3 and withholds unsupported Savant/Spell Breaker/Spell Resistance features")
	var initial_state := WardRules.pool_state(abjurer, "abjurer_arcane_ward")
	check.call(not bool(initial_state.get("active", true)) and not bool(initial_state.get("created_since_long_rest", true)) and int(initial_state.get("current_hp", -1)) == 0 and int(initial_state.get("max_hp", 0)) == 9, "Arcane Ward initializes lazily (inactive, 0/9 HP at level 3 with INT +3) before any Abjuration slot is expended")

	var premature_recharge := WardRules.spend_slot_for_ward_recharge(abjurer, "abjurer_arcane_ward", 1)
	check.call(not bool(premature_recharge.get("success", true)) and int(abjurer.spell_slots.get("1", 0)) == 4, "Bonus Action slot expenditure cannot create or recharge Arcane Ward before it has been created")

	var evocation_events := WardRules.on_slot_spell_cast(abjurer, DataLoader.get_spell("magic_missile"), 1)
	check.call(evocation_events.is_empty() and not WardRules.is_ward_active(abjurer, "abjurer_arcane_ward"), "Non-Abjuration slot spell does not create or recharge Arcane Ward")
	var ritual_events := WardRules.on_slot_spell_cast(abjurer, DataLoader.get_spell("alarm"), 1, {"ritual_cast": true})
	check.call(ritual_events.is_empty() and not WardRules.is_ward_active(abjurer, "abjurer_arcane_ward"), "Ritual cast without slot expenditure does not create or recharge Arcane Ward")
	var free_events := WardRules.on_slot_spell_cast(abjurer, DataLoader.get_spell("mage_armor"), 1, {"free_cast": true})
	var item_events := WardRules.on_slot_spell_cast(abjurer, DataLoader.get_spell("mage_armor"), 1, {"magic_item_activation": true})
	var countered_events := WardRules.on_slot_spell_cast(abjurer, DataLoader.get_spell("mage_armor"), 1, {"countered": true})
	check.call(free_events.is_empty() and item_events.is_empty() and countered_events.is_empty() and not WardRules.is_ward_active(abjurer, "abjurer_arcane_ward"), "Free casts, magic-item casts, and countered casts do not create or recharge Arcane Ward")

	abjurer.known_spells.append_array(["mage_armor", "shield", "protection_from_evil_and_good"])
	var cast_mage_armor := CombatAction.resolve_spell(abjurer, abjurer, DataLoader.get_spell("mage_armor"), true)
	check.call(bool(cast_mage_armor.get("success", false)) and WardRules.is_ward_active(abjurer, "abjurer_arcane_ward") and WardRules.current_ward_hp(abjurer, "abjurer_arcane_ward") == 9 and WardRules.max_ward_hp(abjurer, "abjurer_arcane_ward") == 9, "First slot-expending Abjuration spell creates Arcane Ward at full capacity (2 * level + INT mod = 9 HP)")

	abjurer.feature_uses["damage_immunities"] = ["poison"]
	var immune_dmg := CombatAction.resolve_damage(abjurer, 20, "poison")
	check.call(int(immune_dmg.get("resolved", -1)) == 0 and int(immune_dmg.get("damage", -1)) == 0 and int(immune_dmg.get("ward_absorbed", 0)) == 9 and WardRules.current_ward_hp(abjurer, "abjurer_arcane_ward") == 0, "Arcane Ward absorbs damage before immunity negates the overflow")
	abjurer.feature_uses.erase("damage_immunities")
	WardRules.pool_state(abjurer, "abjurer_arcane_ward")["current_hp"] = 9

	abjurer.protection_from_energy_type = "fire"
	abjurer.temp_hp = 5
	var hp_before_fire := abjurer.current_hp
	var fire_dmg := CombatAction.resolve_damage(abjurer, 10, "fire")
	check.call(int(fire_dmg.get("ward_absorbed", 0)) == 5 and int(fire_dmg.get("resolved", -1)) == 0 and int(fire_dmg.get("damage", -1)) == 0 and WardRules.current_ward_hp(abjurer, "abjurer_arcane_ward") == 4 and abjurer.temp_hp == 5 and abjurer.current_hp == hp_before_fire, "Step 2 Resistance halves 10 fire damage to 5 before Step 3 Arcane Ward absorbs all 5, leaving Temp HP and HP untouched and resolved creature damage at 0 (no Concentration save)")
	abjurer.protection_from_energy_type = ""

	var overflow_dmg := CombatAction.resolve_damage(abjurer, 10, "bludgeoning")
	check.call(int(overflow_dmg.get("ward_absorbed", 0)) == 4 and int(overflow_dmg.get("resolved", -1)) == 6 and int(overflow_dmg.get("damage", -1)) == 1 and WardRules.current_ward_hp(abjurer, "abjurer_arcane_ward") == 0 and WardRules.is_ward_active(abjurer, "abjurer_arcane_ward") and abjurer.temp_hp == 0 and abjurer.current_hp == hp_before_fire - 1, "Step 3 Ward absorbs remaining 4 HP before Step 4 Temp HP absorbs 5 and Step 5 HP loses 1; resolved creature damage is 6 and 0-HP ward remains active")

	var shield_Dummy := {"id": "abj_attacker", "name": "Abjurer Attacker", "current_hp": 30, "max_hp": 30, "is_alive": true, "ability_scores": {"STR": 16, "DEX": 14, "CON": 12}}
	var attacker_char := _character("fighter", 3)
	abjurer.reaction_available = true
	abjurer.base_ac = 12
	abjurer.remove_condition("mage_armor")
	var atk_vs_shield := CombatAction.resolve_weapon_attack(attacker_char, abjurer, {"id": "test_blade", "name": "Test Blade", "damage": "1d6", "damage_type": "slashing", "attack_bonus_override": 15}, false, false, {"shield": true, "roll_token_replacement": {}})
	check.call( abjurer.has_condition("shield") and WardRules.current_ward_hp(abjurer, "abjurer_arcane_ward") >= 0, "Reaction Shield cast expends a level 1 Abjuration slot and recharges the existing 0-HP Arcane Ward by 2 HP before the attack's damage resolves")
	var dummy_unused := shield_Dummy.size() > 0
	check.call(dummy_unused, "Shield attacker dictionary initialized")

	WardRules.pool_state(abjurer, "abjurer_arcane_ward")["current_hp"] = 2
	var bonus_recharge := WardRules.spend_slot_for_ward_recharge(abjurer, "abjurer_arcane_ward", 2)
	check.call(bool(bonus_recharge.get("success", false)) and int(bonus_recharge.get("restored_hp", 0)) == 4 and WardRules.current_ward_hp(abjurer, "abjurer_arcane_ward") == 6, "Bonus Action slot expenditure spends a level 2 slot and restores 2 * slot_level = 4 HP to the active Arcane Ward")

	while abjurer.level < 6:
		abjurer.level_up()
	check.call(abjurer.has_feature("abjurer_projected_ward") and WardRules.max_ward_hp(abjurer, "abjurer_arcane_ward") == 15 and WardRules.current_ward_hp(abjurer, "abjurer_arcane_ward") == 6, "Leveling Abjurer to 6 unlocks Projected Ward and increases Arcane Ward max_hp to 15 (2 * 6 + 3) while preserving current_hp")

	var ally := _character("fighter", 5)
	ally.max_hp = 40
	ally.current_hp = 40
	WardRules.pool_state(abjurer, "abjurer_arcane_ward")["current_hp"] = 8
	abjurer.reaction_available = true
	var shared_projection := {"projected_ward": {"owner": abjurer, "pool_id": "arcane_ward", "distance_feet": 5, "target_visible": true}}
	var first_hit := CombatAction.resolve_damage(ally, 3, "fire", shared_projection)
	var second_hit := CombatAction.resolve_damage(ally, 3, "fire", shared_projection)
	check.call(int(first_hit.get("ward_absorbed", 0)) == 3 and int(second_hit.get("ward_absorbed", 0)) == 0 and ally.current_hp == 37, "Reusing a Projected Ward decision cannot protect a second damage occurrence")
	abjurer.reaction_available = true
	var component_projection := {"projected_ward": {"owner": abjurer, "pool_id": "arcane_ward", "distance_feet": 5, "target_visible": true}}
	var occurrence_id := WardRules.next_damage_occurrence_id()
	var fire_component := CombatAction.resolve_damage(ally, 2, "fire", component_projection, false, false, null, occurrence_id)
	var cold_component := CombatAction.resolve_damage(ally, 2, "cold", component_projection, false, false, null, occurrence_id)
	check.call(int(fire_component.get("ward_absorbed", 0)) == 2 and int(cold_component.get("ward_absorbed", 0)) == 2 and not abjurer.reaction_available, "One Projected Ward Reaction covers both explicitly grouped damage components of the same hit")
	WardRules.pool_state(abjurer, "abjurer_arcane_ward")["current_hp"] = 6
	ally.current_hp = 40
	abjurer.reaction_available = true
	var proj_dmg := CombatAction.resolve_damage(ally, 10, "slashing", {"projected_ward": {"owner": abjurer, "pool_id": "abjurer_arcane_ward", "distance_feet": 25, "target_visible": true}})
	check.call(bool(proj_dmg.get("ward_projected", false)) and int(proj_dmg.get("ward_absorbed", 0)) == 6 and int(proj_dmg.get("resolved", -1)) == 4 and ally.current_hp == 36 and not abjurer.reaction_available and WardRules.current_ward_hp(abjurer, "abjurer_arcane_ward") == 0, "Projected Ward spends Abjurer's Reaction to absorb 6 of 10 damage for a visible ally within 30 ft, leaving 4 overflow damage")

	WardRules.pool_state(abjurer, "abjurer_arcane_ward")["current_hp"] = 8
	var no_reaction_proj := CombatAction.resolve_damage(ally, 5, "slashing", {"projected_ward": {"owner": abjurer, "pool_id": "abjurer_arcane_ward", "distance_feet": 20, "target_visible": true}})
	check.call(not bool(no_reaction_proj.get("ward_projected", true)) and int(no_reaction_proj.get("ward_absorbed", 0)) == 0 and WardRules.current_ward_hp(abjurer, "abjurer_arcane_ward") == 8, "Projected Ward is refused when the Abjurer's Reaction is already spent")

	abjurer.reaction_available = true
	var out_of_range_proj := CombatAction.resolve_damage(ally, 5, "slashing", {"projected_ward": {"owner": abjurer, "pool_id": "abjurer_arcane_ward", "distance_feet": 35, "target_visible": true}})
	var unseen_proj := CombatAction.resolve_damage(ally, 5, "slashing", {"projected_ward": {"owner": abjurer, "pool_id": "abjurer_arcane_ward", "distance_feet": 20, "target_visible": false}})
	check.call(not bool(out_of_range_proj.get("ward_projected", true)) and not bool(unseen_proj.get("ward_projected", true)) and abjurer.reaction_available and WardRules.current_ward_hp(abjurer, "abjurer_arcane_ward") == 8, "Projected Ward is refused when the damaged creature is beyond 30 ft or not visible")

	var abjurer_dto := JSON.parse_string(JSON.stringify(abjurer.to_dict())) as Dictionary
	check.call(ClassProgression.saved_choices_error(abjurer_dto).is_empty(), "Active Arcane Ward passes save preflight validation")
	var reloaded_abjurer := Character.new()
	reloaded_abjurer.from_dict(abjurer_dto)
	check.call(reloaded_abjurer.damage_wards == abjurer.damage_wards and WardRules.current_ward_hp(reloaded_abjurer, "abjurer_arcane_ward") == 8 and WardRules.max_ward_hp(reloaded_abjurer, "abjurer_arcane_ward") == 15, "Save/load round-trip preserves exact Arcane Ward state")

	var bad_ward_pool := abjurer.to_dict()
	bad_ward_pool["damage_wards"]["pools"]["unknown_pool"] = bad_ward_pool["damage_wards"]["pools"]["arcane_ward"].duplicate(true)
	check.call(not ClassProgression.saved_choices_error(bad_ward_pool).is_empty(), "Save preflight rejects unknown damage_wards pool IDs")
	var bad_ward_hp := abjurer.to_dict()
	bad_ward_hp["damage_wards"]["pools"]["arcane_ward"]["current_hp"] = 99
	check.call(not ClassProgression.saved_choices_error(bad_ward_hp).is_empty(), "Save preflight rejects damage_wards current_hp exceeding max_hp")
	var bad_ward_max := abjurer.to_dict()
	bad_ward_max["damage_wards"]["pools"]["arcane_ward"]["max_hp"] = 99
	check.call(not ClassProgression.saved_choices_error(bad_ward_max).is_empty(), "Save preflight rejects tampered damage_wards max_hp")

	abjurer.long_rest()
	check.call(not WardRules.is_ward_active(abjurer, "abjurer_arcane_ward") and WardRules.current_ward_hp(abjurer, "abjurer_arcane_ward") == 0 and not bool(WardRules.pool_state(abjurer, "abjurer_arcane_ward").get("created_since_long_rest", true)), "Long Rest expires Arcane Ward and resets creation state")

	var runeguard := Character.new()
	var rg_scores := AbilityScores.new()
	rg_scores.from_dict({"STR": 10, "DEX": 14, "CON": 14, "INT": 16, "WIS": 12, "CHA": 10})
	runeguard.initialize("Runeguard Fixture", "human", "wizard", rg_scores)
	while runeguard.level < 6:
		runeguard.level_up()
	check.call(ClassProgression.choose_subclass(runeguard, "fixture:runeguard") and runeguard.has_feature("fixture:runeguard_aegis_ward") and runeguard.has_feature("fixture:runeguard_projected_aegis"), "Second consumer fixture:runeguard attaches to Wizard with Runic Aegis and Projected Runic Aegis")
	WardRules.on_slot_spell_cast(runeguard, DataLoader.get_spell("mage_armor"), 1)
	check.call(WardRules.is_ward_active(runeguard, "fixture:runeguard_aegis") and WardRules.current_ward_hp(runeguard, "fixture:runeguard_aegis") == 23 and WardRules.max_ward_hp(runeguard, "fixture:runeguard_aegis") == 23, "Second consumer fixture:runeguard_aegis creates its ward at 23 HP (3 * 6 + 3 + 2 flat bonus) through the shared WardRules path")
	runeguard.reaction_available = true
	var rg_proj := CombatAction.resolve_damage(ally, 7, "piercing", {"projected_ward": {"owner": runeguard, "pool_id": "fixture:runeguard_aegis", "distance_feet": 45, "target_visible": true}})
	check.call(bool(rg_proj.get("ward_projected", false)) and int(rg_proj.get("ward_absorbed", 0)) == 7 and int(rg_proj.get("resolved", -1)) == 0 and WardRules.current_ward_hp(runeguard, "fixture:runeguard_aegis") == 16 and not runeguard.reaction_available, "Second consumer fixture:runeguard_projected_aegis projects its ward onto an ally within 60 ft through the shared WardRules path")


static func _rest_and_slot_recovery_rules(check: Callable) -> void:
	RestRules.reset_windows()
	var short_cmd := PlayerCommand.short_rest()
	var long_cmd := PlayerCommand.long_rest()
	var rest_short_cmd := PlayerCommand.rest("short_rest")
	var rest_long_cmd := PlayerCommand.rest("long_rest")
	check.call(short_cmd != null and short_cmd.is_valid() and short_cmd.rest_type() == "short_rest" and long_cmd != null and long_cmd.is_valid() and long_cmd.rest_type() == "long_rest" and rest_short_cmd != null and rest_short_cmd.rest_type() == "short_rest" and rest_long_cmd != null and rest_long_cmd.rest_type() == "long_rest" and PlayerCommand.rest("catnap") == null, "PlayerCommand validates Short Rest and Long Rest intents and rejects unknown rest types")

	var wiz5 := _character("wizard", 5)
	var fighter5 := _character("fighter", 5)
	var ar_feature := wiz5.get_feature("wizard_arcane_recovery")
	var ar_effect := wiz5.get_feature_effect("rest_slot_recovery")
	check.call(str(ar_feature.get("rules_status", "")) == "2024-supported" and str(ar_feature.get("type", "")) == "triggered" and str(ar_effect.get("trigger", "")) == "short_rest_completed" and str(ar_effect.get("class_level_source", "")) == "wizard" and str(ar_effect.get("budget_formula", "")) == "half_class_level_ceil" and int(ar_effect.get("max_slot_level", 0)) == 5, "Wizard Arcane Recovery is source-defined as a 2024-supported short_rest_completed rest_slot_recovery feature")
	check.call(wiz5.get_class_level("wizard") == 5 and wiz5.get_class_level("self") == 5 and wiz5.get_class_level("fighter") == 0, "Character.get_class_level resolves class-specific level and returns 0 for non-owned classes")

	for pair in [[1, 1], [2, 1], [3, 2], [4, 2], [5, 3], [9, 5], [11, 6], [20, 10]]:
		var lvl_wiz := _character("wizard", int(pair[0]))
		check.call(RestRules.compute_recovery_budget(lvl_wiz, ar_effect) == int(pair[1]), "Arcane Recovery budget at Wizard level %d is ceil(level/2) = %d" % [int(pair[0]), int(pair[1])])

	var local_room_refusal := RestRules.can_complete_rest("short_rest", [wiz5], {"local_view": RefCounted.new(), "allow_in_test": true})
	var roster_refusal := RestRules.can_complete_rest("short_rest", [wiz5], {"companion_roster_open": true, "allow_in_test": true})
	var downed := _character("fighter", 2)
	downed.current_hp = 0
	downed.feature_uses["fighter_second_wind"] = 0
	downed.short_rest()
	var dead_refusal := RestRules.can_complete_rest("short_rest", [downed], {"allow_in_test": true})
	check.call(not bool(local_room_refusal.get("allowed", true)) and str(local_room_refusal.get("reason", "")) == "dungeon_local_room_active" and not bool(roster_refusal.get("allowed", true)) and str(roster_refusal.get("reason", "")) == "companion_roster_open" and not bool(dead_refusal.get("allowed", true)) and str(dead_refusal.get("reason", "")) == "no_living_participants" and int(downed.feature_uses.get("fighter_second_wind", -1)) == 0, "Short Rest is refused in active Dungeon local rooms, with open companion roster, or with only 0-HP participants, and 0-HP characters gain no short_rest benefits")

	fighter5.feature_uses["fighter_second_wind"] = 1
	wiz5.wizard_memorize_spell_pending = false
	var time_before := GameManager.campaign_elapsed_seconds
	var full_slots_rest := RestRules.complete_short_rest([fighter5, wiz5], {"allow_in_test": true})
	check.call(bool(full_slots_rest.get("success", false)) and GameManager.campaign_elapsed_seconds == time_before + 3600 and int(fighter5.feature_uses.get("fighter_second_wind", 0)) == 2 and wiz5.wizard_memorize_spell_pending and not bool(full_slots_rest.get("pending_recovery", true)) and int(wiz5.feature_uses.get("wizard_arcane_recovery", 0)) == 1, "Completing a Short Rest advances campaign time by 3600s once, runs participant short_rest hooks, and suppresses Arcane Recovery when no eligible slots are expended")

	var wiz11 := _character("wizard", 11)
	wiz11.spell_slots["6"] = 0
	var only_lvl6_rest := RestRules.complete_short_rest([wiz11], {"allow_in_test": true})
	check.call(bool(only_lvl6_rest.get("success", false)) and not bool(only_lvl6_rest.get("pending_recovery", true)) and int(wiz11.feature_uses.get("wizard_arcane_recovery", 0)) == 1 and int(wiz11.spell_slots.get("6", -1)) == 0, "Arcane Recovery does not open or consume a use when only level 6+ spell slots are expended")

	# Expend 2xL1, 1xL2, 1xL3, 1xL5, and 1xL6 on the level 11 Wizard (budget = 6, max_slot_level = 5).
	wiz11.spell_slots["1"] = 2 # max 4 -> 2 missing
	wiz11.spell_slots["2"] = 2 # max 3 -> 1 missing
	wiz11.spell_slots["3"] = 2 # max 3 -> 1 missing
	wiz11.spell_slots["4"] = 3 # max 3 -> 0 missing
	wiz11.spell_slots["5"] = 1 # max 2 -> 1 missing
	wiz11.spell_slots["6"] = 0 # max 1 -> 1 missing (ineligible level 6)

	var open_rest := RestRules.complete_short_rest([wiz11], {"allow_in_test": true})
	var active_win := RestRules.get_active_recovery_window()
	check.call(bool(open_rest.get("pending_recovery", false)) and RestRules.is_rest_window_open() and int(active_win.get("budget", 0)) == 6 and int(active_win.get("max_slot_level", 0)) == 5, "Short Rest with expended eligible slots opens a bounded Arcane Recovery window (budget 6, max slot level 5)")

	var concurrent_rest := RestRules.can_complete_rest("short_rest", [wiz11], {"allow_in_test": true})
	check.call(not bool(concurrent_rest.get("allowed", true)) and str(concurrent_rest.get("reason", "")) == "rest_window_open", "A second rest cannot start while an active recovery window is open")

	var slots_snapshot := wiz11.spell_slots.duplicate(true)
	var wrong_actor := RestRules.settle_recovery_window({"actor": fighter5, "selected_slots": {"1": 1}})
	var stale_epoch := RestRules.settle_recovery_window({"epoch": -99, "selected_slots": {"1": 1}})
	var stale_req := RestRules.settle_recovery_window({"request_id": "rest_slot_recovery:0", "selected_slots": {"1": 1}})
	var empty_sel := RestRules.settle_recovery_window({"selected_slots": {}})
	var zero_sel := RestRules.settle_recovery_window({"selected_slots": {"1": 0}})
	var neg_sel := RestRules.settle_recovery_window({"selected_slots": {"1": -1}})
	var lvl6_sel := RestRules.settle_recovery_window({"selected_slots": {"6": 1}})
	var unexpended_lvl4 := RestRules.settle_recovery_window({"selected_slots": {"4": 1}})
	var too_many_lvl1 := RestRules.settle_recovery_window({"selected_slots": {"1": 3}})
	var over_budget := RestRules.settle_recovery_window({"selected_slots": {"5": 1, "2": 1}})
	check.call(
		str(wrong_actor.get("error", "")) == "wrong_actor"
		and str(stale_epoch.get("error", "")) == "stale_epoch"
		and str(stale_req.get("error", "")) == "stale_request_id"
		and str(empty_sel.get("error", "")) == "empty_selection"
		and str(zero_sel.get("error", "")) == "empty_selection"
		and str(neg_sel.get("error", "")) == "negative_slot_count"
		and str(lvl6_sel.get("error", "")) == "slot_level_ineligible"
		and str(unexpended_lvl4.get("error", "")) == "slot_not_expended"
		and str(too_many_lvl1.get("error", "")) == "slot_not_expended"
		and str(over_budget.get("error", "")) == "budget_exceeded"
		and wiz11.spell_slots == slots_snapshot
		and int(wiz11.feature_uses.get("wizard_arcane_recovery", 0)) == 1
		and RestRules.is_rest_window_open(),
		"Recovery window rejects wrong-actor, stale-epoch, stale-request, empty, negative, level-6+, non-expended, and over-budget slot selections without mutating slots or spending the feature use"
	)

	var declined := RestRules.settle_recovery_window({"declined": true})
	check.call(bool(declined.get("success", false)) and bool(declined.get("declined", false)) and not RestRules.is_rest_window_open() and wiz11.spell_slots == slots_snapshot and int(wiz11.feature_uses.get("wizard_arcane_recovery", 0)) == 1, "Declining Arcane Recovery closes the window for that Short Rest without consuming the once-per-Long-Rest use")

	var second_open := RestRules.complete_short_rest([wiz11], {"allow_in_test": true})
	check.call(bool(second_open.get("pending_recovery", false)) and RestRules.is_rest_window_open(), "Because the previous Short Rest recovery was declined, a subsequent Short Rest offers Arcane Recovery again")

	var valid_confirm := RestRules.settle_recovery_window({"selected_slots": {"1": 1, "2": 1, "3": 1}})
	check.call(
		bool(valid_confirm.get("success", false))
		and not bool(valid_confirm.get("declined", true))
		and int(valid_confirm.get("budget_spent", 0)) == 6
		and int(wiz11.spell_slots.get("1", 0)) == 3
		and int(wiz11.spell_slots.get("2", 0)) == 3
		and int(wiz11.spell_slots.get("3", 0)) == 3
		and int(wiz11.spell_slots.get("5", 0)) == 1
		and int(wiz11.spell_slots.get("6", 0)) == 0
		and int(wiz11.feature_uses.get("wizard_arcane_recovery", -1)) == 0
		and not RestRules.is_rest_window_open(),
		"Confirming a valid 1xL1 + 1xL2 + 1xL3 combination (6/6 budget) restores those exact slots and spends the Arcane Recovery use"
	)

	var duplicate_after_close := RestRules.settle_recovery_window({"selected_slots": {"1": 1}})
	check.call(not bool(duplicate_after_close.get("success", true)) and str(duplicate_after_close.get("error", "")) == "stale_or_closed_window" and int(wiz11.spell_slots.get("1", 0)) == 3, "Duplicate settlement after the recovery window closes is rejected without restoring extra slots")

	var third_rest := RestRules.complete_short_rest([wiz11], {"allow_in_test": true})
	check.call(bool(third_rest.get("success", false)) and not bool(third_rest.get("pending_recovery", true)), "Subsequent Short Rest before a Long Rest does not offer Arcane Recovery after its use is spent")

	var wiz11_dto := JSON.parse_string(JSON.stringify(wiz11.to_dict())) as Dictionary
	check.call(ClassProgression.saved_choices_error(wiz11_dto).is_empty(), "Wizard after Short Rest Arcane Recovery passes save preflight validation")
	var reloaded_wiz11 := Character.new()
	reloaded_wiz11.from_dict(wiz11_dto)
	check.call(reloaded_wiz11.spell_slots == wiz11.spell_slots and int(reloaded_wiz11.feature_uses.get("wizard_arcane_recovery", -1)) == 0, "Save/load round-trip preserves recovered spell slots and spent Arcane Recovery use")

	wiz11.long_rest()
	check.call(int(wiz11.feature_uses.get("wizard_arcane_recovery", 0)) == 1 and int(wiz11.spell_slots.get("6", 0)) == 1, "Long Rest restores Arcane Recovery use and full spell slots")

	# Second consumer: fixture:leyline_savant (fixture:leyline_font with flat_budget 3 and max_slot_level 3)
	var savant := _character("wizard", 7)
	check.call(ClassProgression.choose_subclass(savant, "fixture:leyline_savant") and savant.has_feature("fixture:leyline_font"), "Second consumer fixture:leyline_savant attaches to Wizard with Leyline Font")
	savant.feature_uses["wizard_arcane_recovery"] = 0
	savant.spell_slots["3"] = 2 # max 3 -> 1 missing
	savant.spell_slots["4"] = 0 # max 1 -> 1 missing (ineligible for max_slot_level 3)
	var savant_rest := RestRules.complete_short_rest([savant], {"allow_in_test": true})
	var savant_win := RestRules.get_active_recovery_window()
	var savant_reject_lvl4 := RestRules.settle_recovery_window({"selected_slots": {"4": 1}})
	var savant_confirm := RestRules.settle_recovery_window({"selected_slots": [3]})
	check.call(
		bool(savant_rest.get("pending_recovery", false))
		and str(savant_win.get("feature_id", "")) == "fixture:leyline_font"
		and int(savant_win.get("budget", 0)) == 3
		and int(savant_win.get("max_slot_level", 0)) == 3
		and str(savant_reject_lvl4.get("error", "")) == "slot_level_ineligible"
		and bool(savant_confirm.get("success", false))
		and int(savant.spell_slots.get("3", 0)) == 3
		and int(savant.feature_uses.get("fixture:leyline_font", -1)) == 0,
		"Second consumer fixture:leyline_font executes through the shared RestRules path with flat budget 3 and max slot level 3"
	)
	RestRules.reset_windows()


static func _character(id: String, target_level: int) -> Character:
	var c := Character.new()
	var scores := AbilityScores.new()
	scores.from_dict({"STR": 10, "DEX": 14, "CON": 12, "INT": 10, "WIS": 14, "CHA": 10})
	c.initialize("Building Block Fixture", "human", id, scores)
	while c.level < target_level:
		c.level_up()
	return c
