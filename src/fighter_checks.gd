## Production-record checks for Fighter progression and previously unsafe
## resource/action boundaries. Called by the ordinary Godot logic runner.
class_name FighterChecks
extends RefCounted

static func run(check: Callable) -> void:
	var c := _fighter()
	for level in range(1, 21):
		check.call(c.level == level, "Fighter reaches level %d through normal progression" % level)
		check.call(c.get_feature_max_uses("fighter_second_wind") == (2 if level < 4 else (3 if level < 10 else 4)), "Second Wind capacity at level %d" % level)
		check.call(c.extra_attacks == (0 if level < 5 else (1 if level < 11 else (2 if level < 20 else 3))), "Attack count at level %d" % level)
		check.call(c.crit_range == (20 if level < 3 else (19 if level < 15 else 18)), "Champion weapon critical range at level %d" % level)
		if level >= 2:
			check.call(c.get_feature_max_uses("fighter_action_surge") == (2 if level >= 17 else 1), "Action Surge capacity at level %d" % level)
		if level >= 9:
			check.call(c.get_feature_max_uses("fighter_indomitable") == (3 if level >= 17 else (2 if level >= 13 else 1)), "Indomitable capacity at level %d" % level)
		var restored := Character.new()
		restored.from_dict(c.to_dict())
		check.call(restored.extra_attacks == c.extra_attacks and restored.crit_range == c.crit_range and restored.feature_uses == c.feature_uses, "Fighter level %d round-trip rebuilds features without duplicating or refilling" % level)
		if level < 20:
			c.level_up()
	c.level_up()
	check.call(c.level == 20, "Fighter cannot advance past 20")
	check.call(c.get_feature("fighter_tactical_shift").get("type") == "passive" and c.get_feature("fighter_indomitable").get("type") == "triggered", "Triggered features are not fake active buttons")
	check.call(FighterRules.pending_asi(c) == 6, "Six Fighter ability improvements remain available until selected")
	c.ability_scores.set_score("CON", 13)
	var old_hp := c.max_hp
	check.call(FighterRules.improve_scores(c, "CON", "DEX") and c.max_hp == old_hp + 20, "Constitution improvement adjusts every Fighter level's HP")
	c.ability_scores.set_score("STR", 20)
	check.call(not FighterRules.improve_scores(c, "STR", "STR") and FighterRules.pending_asi(c) == 5, "Illegal ability cap does not spend an improvement")
	check.call(FighterRules.choose_boon(c, "STR") and c.ability_scores.get_score("STR") == 21, "Level 19 Combat Prowess can exceed 20")
	check.call(not FighterRules.choose_boon(c, "DEX"), "Epic Boon cannot be taken twice")
	c.fighter_training["styles"] = ["defense"]
	check.call(FighterRules.choose_style(c, "archery") and not FighterRules.choose_style(c, "archery"), "Champion adds a different second style only")
	check.call(c.get_ac() == c.base_ac + 1 and c.get_attack_style_bonus(DataLoader.get_item("longbow")) == 2 and c.get_attack_style_bonus(DataLoader.get_item("longsword")) == 0, "Defense and Archery apply only to eligible equipment")
	c.inventory.unequip(Inventory.Slot.BODY)
	c._recalculate_ac()
	check.call(c.get_ac() == c.base_ac, "Defense gives no unarmored AC bonus")
	c.fighter_training["styles"] = ["great_weapon_fighting"]
	c.inventory.unequip(Inventory.Slot.SHIELD)
	var detail := {"dice_terms": [{"results": [1, 2, 5], "subtotal": 8}]}
	check.call(FighterRules.weapon_damage(c, DataLoader.get_item("greatsword"), detail) == 3 and detail["dice_terms"][0]["results"] == [3, 3, 5], "2024 Great Weapon Fighting raises 1s and 2s to 3")
	check.call(FighterRules.weapon_damage(c, DataLoader.get_item("longbow"), {"dice_terms": [{"results": [1], "subtotal": 1}]}) == 0, "Great Weapon Fighting never raises ranged damage")
	c.long_rest()
	check.call(FighterRules.choose_mastery(c, "scimitar", 0) and not FighterRules.choose_mastery(c, "dagger", 1), "Long Rest permits exactly one mastery replacement")
	check.call(FighterRules.choose_mastery(c, "warhammer") and FighterRules.mastery(c, DataLoader.get_item("warhammer")) == "push", "Higher-level capacity accepts a new weapon mastery")
	c.fighter_training["tactical_master"] = "sap"
	check.call(FighterRules.mastery(c, DataLoader.get_item("warhammer")) == "sap" and FighterRules.mastery(c, DataLoader.get_item("dagger")) == "", "Tactical Master replaces only a trained weapon property")
	c.feature_uses["fighter_second_wind"] = 1
	_seed_die(10, 10)
	var mind := FighterRules.tactical_mind(c, 9, 15)
	check.call(mind["total"] == 19 and mind["spent"] and c.feature_uses["fighter_second_wind"] == 0, "Tactical Mind spends Second Wind on a converted success")
	c.feature_uses["fighter_second_wind"] = 1
	_seed_die(10, 1)
	mind = FighterRules.tactical_mind(c, 1, 30)
	check.call(mind["total"] == 2 and not mind["spent"] and c.feature_uses["fighter_second_wind"] == 1, "Still-failed Tactical Mind keeps its Second Wind use")
	check.call(FighterRules.tactical_mind(c, 30, 30)["bonus"] == 0, "Tactical Mind cannot boost an already successful check")
	c.feature_uses["fighter_indomitable"] = 1
	c.fighter_training["auto_indomitable"] = true
	var save := c.saving_throw_to_dc("WIS", 100)
	check.call(save >= 21 and save <= 40 and c.feature_uses["fighter_indomitable"] == 0, "Failed save uses a new roll plus Fighter level and spends Indomitable even if still failed")
	c.feature_uses["fighter_indomitable"] = 1
	c.saving_throw_to_dc("WIS", -100)
	check.call(c.feature_uses["fighter_indomitable"] == 1, "Successful save does not spend Indomitable")
	c.short_rest()
	check.call(c.feature_uses["fighter_indomitable"] == 1 and c.feature_uses["fighter_action_surge"] == 2, "Short Rest restores Surge but not Indomitable")
	c.feature_uses["fighter_action_surge"] = 0
	c.reset_combat_features()
	check.call(c.feature_uses["fighter_action_surge"] == 0, "Starting combat never recharges Action Surge")
	c.long_rest()
	check.call(c.use_feature("fighter_action_surge") and not c.use_feature("fighter_action_surge") and c.feature_uses["fighter_action_surge"] == 1, "Level 17+ Surge still activates only once per turn")
	FighterRules.start_turn(c)
	check.call(c.use_feature("fighter_action_surge") and c.feature_uses["fighter_action_surge"] == 0, "Second Surge use belongs to a different turn")
	var budget := CombatTurnBudget.new()
	budget.grant_surge_action()
	check.call(budget.spend("action") and budget.spend("magic_action") and not budget.can_spend("action"), "Surging before acting preserves the ordinary Magic action")
	budget.reset()
	budget.spend("magic_action")
	budget.grant_surge_action()
	check.call(not budget.can_spend("magic_action") and budget.spend("action") and not budget.spend("action") and budget.bonus_action_available, "Surge grants exactly one non-Magic action without a Bonus Action")
	c.fighter_training["boon"] = ""
	c.feature_choices.erase("fighter_epic_boon")
	var target := {"id": "fighter-test-target", "armor_class": 999, "current_hp": 100, "is_alive": true}
	_seed_die(20, 1)
	var miss := CombatAction.resolve_weapon_attack(c, target, DataLoader.get_item("greatsword"))
	check.call(not miss["hit"] and "fighter-test-target" in c.fighter_studied_targets, "Actual missed attack arms Studied Attacks")
	check.call(FighterRules.attack_advantage(c, target) and not FighterRules.attack_advantage(c, target), "Studied advantage is consumed by only the next attack against its target")
	FighterRules.record_miss(c, target)
	FighterRules.start_turn(c)
	FighterRules.end_turn(c)
	check.call(not FighterRules.attack_advantage(c, target), "Unused Studied Attacks expires at the end of the next turn")
	c.fighter_training["tactical_master"] = "weapon"
	FighterRules.apply_mastery(c, target, DataLoader.get_item("greatsword"), miss)
	check.call(miss["damage"] == c.ability_scores.get_ability_modifier("STR"), "Graze deals ability damage after a miss")
	c.fighter_training["masteries"] = ["longsword", "longbow", "shortsword", "battleaxe"]
	FighterRules.apply_mastery(c, target, DataLoader.get_item("longsword"), {"hit": true, "damage": 1})
	FighterRules.apply_mastery(c, target, DataLoader.get_item("longbow"), {"hit": true, "damage": 1})
	FighterRules.apply_mastery(c, target, DataLoader.get_item("longbow"), {"hit": true, "damage": 1})
	check.call(not target.get("fighter_sap_sources", []).is_empty() and FighterRules.monster_speed(target) == 4, "Sap and non-stacking Slow apply from production weapons")
	var other := _fighter()
	FighterRules.apply_mastery(other, target, DataLoader.get_item("longsword"), {"hit": true, "damage": 1})
	FighterRules.clear_source_effects(c, [target])
	check.call(target.get("fighter_sap_sources", []).size() == 1 and FighterRules.monster_speed(target) == 6, "One Fighter's turn expires only that Fighter's mastery effects")
	c.heroic_inspiration = false
	c.current_hp = 1
	var healing := FighterRules.start_turn(c)
	check.call(c.heroic_inspiration and healing == 5 + c.ability_scores.get_ability_modifier("CON"), "Champion starts combat turns with Inspiration and Survivor healing")
	c.current_hp = 0
	c.is_alive = false
	check.call(FighterRules.start_turn(c) == 0 and c.current_hp == 0, "Survivor rally cannot heal at zero HP")
	_seed_die(20, 18)
	var death := c.make_death_save()
	check.call(death.get("revived", false) and c.current_hp == 1 and c.is_alive, "Survivor death-save 18 benefits from a natural 20")
	c.fighter_training["boon"] = "combat_prowess"
	c.feature_uses.erase("fighter_peerless_used")
	c.feature_uses.erase("epic_boon_combat_prowess_used")
	_seed_die(20, 1)
	var peerless := CombatAction.resolve_weapon_attack(c, target, DataLoader.get_item("longsword"))
	check.call(peerless["hit"] and not peerless["crit"], "Peerless Aim can turn a natural 1 into a noncritical hit")
	_seed_die(20, 1)
	check.call(not CombatAction.resolve_weapon_attack(c, target, DataLoader.get_item("longsword"))["hit"], "Peerless Aim cannot turn a second miss into a hit before the next turn")
	var dto := c.to_dict()
	var reload := Character.new()
	reload.from_dict(JSON.parse_string(JSON.stringify(dto)))
	check.call(reload.fighter_training == c.fighter_training and reload.ability_scores.to_dict() == c.ability_scores.to_dict() and reload.max_hp == c.max_hp, "Selected training, spent improvements, boon, scores and HP survive plain JSON reload")
	_seed_die(20, 18)
	check.call(not c.make_attack_roll("STR")["is_crit"], "Champion critical range never applies to spell attack rolls")
	var dual := _fighter()
	dual.inventory.unequip(Inventory.Slot.SHIELD)
	dual.inventory.add_item("scimitar")
	dual.inventory.equip(Inventory.Slot.WEAPON, "scimitar")
	check.call(not dual.inventory.can_equip(Inventory.Slot.OFFHAND, "scimitar"), "One owned weapon cannot be duplicated into both hands")
	dual.inventory.add_item("scimitar")
	check.call(dual.inventory.can_equip(Inventory.Slot.OFFHAND, "scimitar"), "Two owned copies of one Light weapon type can be wielded together")
	dual.inventory.equip(Inventory.Slot.OFFHAND, "scimitar")
	check.call(not dual.inventory.can_equip(Inventory.Slot.SHIELD, "shield") and not dual.inventory.can_equip(Inventory.Slot.WEAPON, "longsword"), "Light dual wielding cannot silently equip a shield or non-Light main weapon")
	var starting := Inventory.new()
	starting.add_starting_equipment(["shield", "longbow"])
	check.call(starting.get_weapon() == "longbow" and starting.has_item("shield") and not starting.is_slot_equipped(Inventory.Slot.SHIELD), "Two-handed starting equipment stows its shield without losing either item")
	c.feature_uses.erase("fighter_peerless_used")
	c.feature_uses.erase("epic_boon_combat_prowess_used")
	_seed_die(20, 1)
	var spell := CombatAction.resolve_spell(c, target, DataLoader.get_spell("fire_bolt"))
	check.call(spell.get("hit", false) and c.feature_uses.get("fighter_peerless_used", false), "Combat Prowess also turns a missed spell attack into a hit")
	c.heroic_inspiration = true
	c.fighter_training["inspiration_any_die"] = true
	_seed_die(6, 6)
	Dice.parse_dice_string("1d6", {}, c)
	check.call(c.heroic_inspiration and c.fighter_training["inspiration_any_die"], "Armed Inspiration leaves a high damage die and the resource unchanged")
	_seed_die(6, 1)
	Dice.parse_dice_string("1d6", {}, c)
	check.call(not c.heroic_inspiration and not c.fighter_training["inspiration_any_die"], "Any-die Inspiration rerolls a low damage die exactly once")
	c.heroic_inspiration = true
	c.fighter_training["inspiration_any_die"] = true
	_seed_die(20, 1)
	Dice.roll(20, other)
	check.call(c.heroic_inspiration, "Another character's roll cannot consume armed Fighter Inspiration")
	_seed_die(20, 1)
	var inspired_attack := c.make_attack_roll("STR")
	check.call(inspired_attack["roll_results"].size() == 2 and inspired_attack["roll_kept"] == [false, true] and not c.heroic_inspiration, "Inspired attack records both original and mandatory replacement die")
	var fallen := _fighter()
	for i in 8:
		fallen.level_up()
	fallen.current_hp = 0
	fallen.is_alive = false
	fallen.feature_uses["fighter_indomitable"] = 1
	for candidate in 10000:
		seed(candidate)
		if randi_range(1, 20) >= 10:
			continue
		if randi_range(1, 20) != 10:
			continue
		seed(candidate)
		break
	var death_reroll := fallen.make_death_save()
	check.call(death_reroll["natural"] == 10 and fallen.death_save_successes == 1 and fallen.death_save_failures == 0 and fallen.feature_uses["fighter_indomitable"] == 0, "Indomitable rerolls a failed death save before recording success or failure")
	randomize()

static func _fighter() -> Character:
	var scores := AbilityScores.new()
	scores.from_dict({"STR": 16, "DEX": 12, "CON": 14, "INT": 10, "WIS": 10, "CHA": 8})
	var c := Character.new()
	c.initialize("Fighter Checks", "human", "fighter", scores)
	return c

static func _seed_die(sides: int, wanted: int) -> void:
	for candidate in 10000:
		seed(candidate)
		if randi_range(1, sides) == wanted:
			seed(candidate)
			return
