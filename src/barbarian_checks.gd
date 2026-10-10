## Small production regressions for the Barbarian acceptance pass.
class_name BarbarianChecks
extends RefCounted

static func run(check: Callable) -> void:
	_remaining_choices(check)
	var rage := _character(1)
	var feature := rage.get_feature("barbarian_rage")
	var budget := CombatTurnBudget.new()
	var uses := int(rage.feature_uses["barbarian_rage"])
	check.call(ClassFeature.execute(rage, feature, null, budget).get("success", false) and not budget.bonus_action_available and int(rage.feature_uses["barbarian_rage"]) == uses - 1, "Entering Rage spends one use and one Bonus Action")
	rage.tick_conditions()
	budget.reset(rage)
	rage.feature_uses["barbarian_rage"] = 0
	check.call(ClassFeature.availability(rage, feature, budget).get("available", false), "An active Rage can be extended with no Rage uses left")
	var extension := ClassFeature.execute(rage, feature, null, budget)
	check.call(extension.get("rage_extended", false) and not budget.bonus_action_available and int(rage.feature_uses["barbarian_rage"]) == 0 and int(rage.conditions.get("raging", 0)) == 2, "Extending Rage spends only the Bonus Action")
	check.call(not ClassFeature.execute(rage, feature, null, budget).get("success", false), "A spent Bonus Action cannot extend Rage again")
	rage.tick_conditions()
	rage.tick_conditions()
	check.call(not rage.has_condition("raging") and rage.get_modifier("stat", "damage:rage") == 0, "Rage and damage bonus end together without upkeep")
	for target_level in [1, 15]:
		var capped := _character(target_level)
		ClassFeature.execute(capped, capped.get_feature("barbarian_rage"))
		for turn in 99:
			BarbarianRules.maintain_rage(capped)
			capped.tick_conditions()
		var loaded := Character.new()
		loaded.from_dict(JSON.parse_string(JSON.stringify(capped.to_dict())))
		check.call(loaded.has_condition("raging"), "Level %d Rage survives reload with one turn remaining" % target_level)
		BarbarianRules.maintain_rage(loaded)
		loaded.tick_conditions()
		check.call(not loaded.has_condition("raging") and loaded.get_modifier("stat", "damage:rage") == 0, "Level %d Rage reaches the ten-minute cap despite upkeep and reload" % target_level)
	var incapacitated := _character(1)
	ClassFeature.execute(incapacitated, incapacitated.get_feature("barbarian_rage"))
	incapacitated.add_condition("paralyzed", 2)
	incapacitated.tick_conditions()
	check.call(not incapacitated.has_condition("raging"), "Paralyzed includes Incapacitated and ends ordinary Rage")
	var danger := _character(2)
	check.call(danger._has_saving_throw_advantage("DEX"), "Danger Sense grants Dexterity save Advantage while conscious")
	danger.add_condition("stunned", 2)
	check.call(not danger._has_saving_throw_advantage("DEX"), "Stunned includes Incapacitated and disables Danger Sense")
	var persistent := _character(15)
	ClassFeature.execute(persistent, persistent.get_feature("barbarian_rage"))
	persistent.add_condition("paralyzed", 2)
	persistent.tick_conditions()
	check.call(persistent.has_condition("raging"), "Persistent Rage survives conscious incapacitation")
	persistent.long_rest()
	check.call(not persistent.has_condition("raging"), "A Long Rest ends an active Rage")
	var reckless := _character(5)
	check.call(reckless.get_speed() == reckless.speed + 2, "Fast Movement grants ten feet without Heavy armor")
	reckless.inventory.equip(Inventory.Slot.BODY, "chain_mail", true)
	check.call(reckless.get_speed() == reckless.speed, "Heavy armor removes Fast Movement")
	reckless.inventory.unequip(Inventory.Slot.BODY)
	CombatAction.activate_reckless_attack(reckless)
	var target := {"name": "Target", "armor_class": -100, "current_hp": 10000, "is_alive": true, "conditions": {}}
	var thrown := {"ability": "STR", "damage": "1+STR", "damage_type": "piercing", "range": 4}
	var first := CombatAction.resolve_weapon_attack(reckless, target, thrown)
	var second := CombatAction.resolve_weapon_attack(reckless, target, thrown)
	check.call(first.get("activity_roll", {}).get("advantage", false) and second.get("activity_roll", {}).get("advantage", false), "Reckless applies to every Strength attack, including thrown attacks")
	thrown["ability"] = "DEX"
	check.call(not CombatAction.resolve_weapon_attack(reckless, target, thrown).get("activity_roll", {}).get("advantage", true), "Reckless does not grant Dexterity attack Advantage")
	var slowed := {"speed": 8}
	var other := _character(9)
	BarbarianRules.apply_brutal_strike_effects(reckless, slowed, ["hamstring"])
	BarbarianRules.apply_brutal_strike_effects(other, slowed, ["hamstring"])
	check.call(int(slowed["speed"]) == 5, "The newest Hamstring replaces the earlier reduction instead of stacking")
	BarbarianRules.clear_turn_effects(reckless, [slowed])
	check.call(int(slowed["speed"]) == 5, "The old Hamstring owner's turn cannot remove the replacement")
	BarbarianRules.clear_turn_effects(other, [slowed])
	check.call(int(slowed["speed"]) == 8, "Hamstring expiry restores the original Speed")
	var blessed_staggered := {"conditions": {"blessed": 10}, "barbarian_staggered_saves": true}
	seed(41)
	var expected := mini(Dice.roll(20), Dice.roll(20)) + Dice.roll(4)
	seed(41)
	check.call(BarbarianRules.roll_monster_save(blessed_staggered, "WIS") == expected and not blessed_staggered.has("barbarian_staggered_saves"), "Staggering selects the lower d20 before adding Bless and consumes one save")
	var champion := _character(20)
	var restored := Character.new()
	restored.from_dict(JSON.parse_string(JSON.stringify(champion.to_dict())))
	check.call(restored.ability_scores.to_dict() == champion.ability_scores.to_dict(), "Primal Champion score increases do not replay on reload")
	champion.feature_uses["barbarian_rage"] = 0
	champion.short_rest()
	check.call(int(champion.feature_uses["barbarian_rage"]) == 1, "A Short Rest recovers exactly one Rage")
	champion.long_rest()
	check.call(int(champion.feature_uses["barbarian_rage"]) == 6, "A Long Rest restores the level-20 Rage pool")
	CombatAction.active_turn_actor_id = 0


static func _remaining_choices(check: Callable) -> void:
	var actor := _character(11)
	actor.add_condition("reckless_attack", 2)
	var weapon := DataLoader.get_item("greataxe")
	var target := {"name": "Choice Target", "armor_class": -100, "current_hp": 10000, "is_alive": true, "conditions": {}}
	CombatAction.advance_combat_turn()
	var refused := CombatAction.resolve_weapon_attack(actor, target, weapon, true, false, {"barbarian_brutal_strike_effects": ["hamstring"]})
	check.call(not refused.has("barbarian_brutal_strike") and int(actor.feature_uses.get("barbarian_brutal_strike_used_this_turn", 0)) == 0, "An off-turn attack cannot commit Brutal Strike")
	CombatAction.advance_combat_turn(actor)
	actor.add_condition("poisoned", 2)
	check.call(not BarbarianRules.brutal_strike_eligible(actor, weapon), "Poisoned blocks Brutal Strike before its choice is offered")
	actor.remove_condition("poisoned")
	# This check needs a hit; the separate natural-one case below protects misses.
	FighterChecks._seed_die(20, 10)
	var brutal := CombatAction.resolve_weapon_attack(actor, target, weapon, true, false, {"barbarian_brutal_strike_effects": ["hamstring"]})
	check.call(brutal.has("barbarian_brutal_strike") and not brutal.get("activity_roll", {}).get("advantage", true), "Own-turn Brutal Strike forgoes Reckless Advantage")
	check.call(not BarbarianRules.brutal_strike_eligible(actor, weapon), "A committed Brutal Strike cannot repeat on another swing")
	actor.feature_uses["barbarian_brutal_strike_used_this_turn"] = 0
	FighterChecks._seed_die(20, 1)
	var missed := CombatAction.resolve_weapon_attack(actor, target, weapon, true, false, {"barbarian_brutal_strike_effects": ["hamstring"]})
	check.call(not missed.get("hit", true) and int(actor.feature_uses["barbarian_brutal_strike_used_this_turn"]) == 1, "A missed chosen attack still consumes the turn's Brutal Strike")
	ClassFeature.execute(actor, actor.get_feature("barbarian_rage"))
	actor.tick_conditions()
	BarbarianRules.roll_monster_save(target, "CON", actor)
	check.call(int(actor.conditions.get("raging", 0)) == 2, "Forcing an initial enemy save extends active Rage")
	actor.tick_conditions()
	BarbarianRules.roll_monster_save(target, "CON")
	check.call(int(actor.conditions.get("raging", 0)) == 1, "An automatic repeat save does not extend Rage")
	var skill := {"ability": "DEX", "skill": "Acrobatics", "dc": 10, "use_primal_knowledge": false}
	check.call(EventResolver.resolve_skill_check(actor, skill)["ability"] == "DEX", "Declining Primal Knowledge keeps the normal ability")
	skill["use_primal_knowledge"] = true
	check.call(EventResolver.resolve_skill_check(actor, skill)["ability"] == "STR", "Choosing Primal Knowledge uses Strength while Rage remains active")
	actor.barbarian_relentless_rage_enabled = false
	actor.current_hp = 1
	actor.take_damage(1)
	check.call(not actor.is_alive and not actor.feature_uses.has("barbarian_relentless_rage_attempts"), "Declining Relentless Rage leaves its DC unchanged and takes the zero-HP outcome")
	var loaded := Character.new()
	loaded.from_dict(JSON.parse_string(JSON.stringify(actor.to_dict())))
	check.call(not loaded.barbarian_relentless_rage_enabled, "Relentless Rage policy survives JSON reload")
	var old_save := actor.to_dict()
	old_save.erase("barbarian_relentless_rage_enabled")
	loaded.from_dict(old_save)
	check.call(loaded.barbarian_relentless_rage_enabled, "Older saves retain the prior enabled Relentless Rage behavior")
	old_save["barbarian_relentless_rage_enabled"] = "always"
	check.call(not ClassProgression.saved_choices_error(old_save).is_empty(), "Save preflight rejects a malformed Relentless Rage policy")
	var raging := _character(1)
	ClassFeature.execute(raging, raging.get_feature("barbarian_rage"))
	raging.add_condition("stunned", 2)
	check.call(not raging.has_condition("raging") and raging.get_modifier("stat", "damage:rage") == 0, "Incapacitation ends ordinary Rage immediately when applied")
	var defender := _character(2)
	CombatAction.activate_reckless_attack(defender)
	check.call(CombatAction.resolve_weapon_attack(_character(1), defender, weapon).get("activity_roll", {}).get("advantage", false), "Attack resolvers grant Advantage against a Reckless target")
	var unarmed := CombatAction.unarmed_attack_profile(defender)
	check.call(unarmed["damage"] == "1+STR" and unarmed["damage_type"] == "bludgeoning", "Barbarian unarmed Attack uses one plus Strength damage")
	var equipment := _character(1)
	check.call(equipment.inventory.gold == 15 and equipment.inventory.count_item("handaxe") == 4 and equipment.inventory.count_item("explorers_pack") == 1, "Barbarian equipment start grants four Handaxes, the Explorer pack and 15 GP")
	var gold := Character.new()
	gold.initialize("Gold start", "human", "barbarian", equipment.ability_scores, "gold")
	check.call(gold.inventory.gold == 75 and gold.inventory.backpack.is_empty() and gold.inventory.equipped.is_empty(), "Barbarian gold start grants 75 GP without class equipment")
	CombatAction.active_turn_actor_id = 0


static func _character(target_level: int) -> Character:
	var scores := AbilityScores.new()
	scores.from_dict({"STR": 16, "DEX": 14, "CON": 14, "INT": 10, "WIS": 10, "CHA": 10})
	var character := Character.new()
	character.initialize("Barbarian Fixture", "human", "barbarian", scores)
	while character.level < target_level:
		character.level_up()
	character.inventory.unequip(Inventory.Slot.BODY)
	return character
