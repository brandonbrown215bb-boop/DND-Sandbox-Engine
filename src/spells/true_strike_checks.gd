## Focused resolver checks for the SRD 5.2.1 True Strike weapon attack.
class_name TrueStrikeChecks
extends RefCounted


static func _wizard() -> Character:
	var scores := AbilityScores.new()
	scores.from_dict({"STR": 8, "DEX": 10, "CON": 14, "INT": 16, "WIS": 12, "CHA": 10})
	var wizard := Character.new()
	wizard.initialize("True Strike test", "human", "wizard", scores)
	return wizard


static func _target() -> Dictionary:
	return {
		"id": "true-strike-target",
		"name": "True Strike target",
		"is_alive": true,
		"current_hp": 100,
		"max_hp": 100,
		"temp_hp": 0,
		"armor_class": -100,
		"creature_type": "humanoid",
		"conditions": {},
		"damage_resistances": ["bludgeoning"],
	}


static func run(check: Callable) -> void:
	var spell := DataLoader.get_spell("true_strike")
	var club := DataLoader.get_item("club")
	check.call(SpellSupport.is_available(spell) and spell.get("rules_source", "") == "SRD 5.2.1" and int(spell.get("range", -1)) == 0, "True Strike loads the curated SRD 5.2.1 self-range record and is castable")
	var wizard := _wizard()
	check.call(wizard.is_proficient_with_weapon(club) and int(club.get("value", 0)) >= 1, "A Wizard's Simple Weapon proficiency and a valued Club meet True Strike's material requirement")
	var component_inventory := Inventory.new()
	component_inventory.add_item("component_pouch")
	check.call(not component_inventory.has_required_spell_component(spell, "wizard"), "A pouch cannot replace True Strike's required equipped weapon")
	component_inventory.remove_item("component_pouch")
	component_inventory.equipped[Inventory.Slot.WEAPON] = "club"
	component_inventory.equipped[Inventory.Slot.SHIELD] = "shield"
	check.call(component_inventory.available_spellcasting_hands() == 0 and component_inventory.has_required_spell_component(spell, "wizard"), "True Strike uses its weapon as the Material component and its weapon hand for the Somatic component without a pouch")
	check.call(CombatAction.true_strike_bonus_damage(4).is_empty() and CombatAction.true_strike_bonus_damage(5) == "1d6" and CombatAction.true_strike_bonus_damage(11) == "2d6" and CombatAction.true_strike_bonus_damage(17) == "3d6", "True Strike's extra Radiant damage scales at character levels 5, 11, and 17")
	var profile := club.duplicate(true)
	profile["_true_strike"] = true
	profile["ability"] = wizard.get_spellcasting_ability()
	profile["damage_type"] = "bludgeoning"
	var target := _target()
	var result: Dictionary = {}
	for _attempt in 50:
		target = _target()
		result = CombatAction.resolve_weapon_attack(wizard, target, profile, false, false, {}, {"formula": "1d6", "type": "radiant", "label": "True Strike Radiant"})
		if bool(result.get("hit", false)):
			break
	var attack_modifiers: Array = result.get("activity_roll", {}).get("modifiers", [])
	var uses_intelligence := attack_modifiers.any(func(modifier): return str(modifier.get("label", "")) == "INT" and int(modifier.get("value", 0)) == 3)
	var damage_components: Array = result.get("damage_components", [])
	var settled_bludgeoning := damage_components.any(func(component): return str(component.get("type", "")) == "bludgeoning")
	var settled_radiant := damage_components.any(func(component): return str(component.get("type", "")) == "radiant" and str(component.get("formula", "")) == "1d6")
	var component_total := 0
	for component in damage_components:
		component_total += int(component.get("value", 0))
	check.call(result.get("hit", false) and uses_intelligence, "True Strike rolls its weapon attack using the Wizard's spellcasting ability")
	check.call(result.get("damage", 0) >= 1 and settled_bludgeoning and settled_radiant and component_total == int(result.get("damage", 0)), "True Strike settles resisted weapon damage and extra Radiant damage by their separate types")
	check.call(str(result.get("activity_damage", {}).get("additional_damage_formula", "")) == "1d6" and str(result.get("activity_damage", {}).get("additional_damage_type", "")) == "radiant", "True Strike activity damage retains its Radiant formula and type")
