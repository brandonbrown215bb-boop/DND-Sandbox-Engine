## Combat Action Resolver
## Implements D&D 5e combat mechanics: attack rolls, spellcasting, healing, and AC protection.
class_name CombatAction
extends RefCounted


## Resolve a basic weapon attack.
## Returns a result dictionary describing the hit, miss, crit, damage, and logs.
static func resolve_weapon_attack(attacker: Character, target_entity, weapon_data: Dictionary, advantage: bool = false, disadvantage: bool = false) -> Dictionary:
	var ability: String = weapon_data.get("ability", "STR")
	
	# Roll attack
	var attack_result := attacker.make_attack_roll(ability, advantage, disadvantage)
	if attack_result["is_miss"]:
		return {"hit": false, "message": "Miss! (Natural 1)"}

	# Check target AC
	var target_ac := 10
	if target_entity is Character:
		target_ac = target_entity.get_ac()
	elif target_entity is Dictionary:
		target_ac = int(target_entity.get("armor_class", 10))

	var is_crit := bool(attack_result["is_crit"])
	var is_hit: bool = is_crit or (attack_result["total"] >= target_ac)
	var reaction_msg := ""

	# Check reaction Shield spell for Player Character target
	if is_hit and not is_crit and target_entity is Character:
		if target_entity.reaction_available and "shield" in target_entity.known_spells and target_entity.spell_slots.get("1", 0) > 0:
			target_entity.reaction_available = false
			target_entity.spell_slots["1"] -= 1
			target_entity.add_condition("shield", 1)
			target_ac = target_entity.get_ac()
			is_hit = attack_result["total"] >= target_ac
			reaction_msg = "[color=cyan]%s casts Shield as a reaction! AC increases to %d.[/color]\n" % [target_entity.character_name, target_ac]

	if not is_hit:
		return {
			"hit": false,
			"attack_roll": attack_result["total"],
			"message": reaction_msg + "Miss! Attack roll %d vs AC %d" % [attack_result["total"], target_ac]
		}

	# Roll damage
	var damage_str: String = weapon_data.get("damage", "1d4")
	var damage_type: String = weapon_data.get("damage_type", "bludgeoning")
	
	var mod := attacker.ability_scores.get_ability_modifier(ability)
	var modifiers := {"STR": mod, "DEX": mod}
	
	var damage_roll := Dice.parse_dice_string(damage_str, modifiers)
	
	# Crits double damage dice
	if attack_result["is_crit"]:
		# Roll damage dice a second time
		damage_roll += Dice.parse_dice_string(damage_str, {"STR": 0, "DEX": 0})

	# Uncanny Dodge Reaction
	if target_entity is Character and target_entity.reaction_available and target_entity.has_feature("uncanny_dodge"):
		target_entity.reaction_available = false
		damage_roll = int(floor(float(damage_roll) / 2.0))
		reaction_msg += "[color=cyan]%s uses Uncanny Dodge as a reaction to halve the incoming damage![/color]\n" % target_entity.character_name

	# Apply damage
	var actual_dealt := 0
	if target_entity is Character:
		actual_dealt = target_entity.take_damage(damage_roll)
	elif target_entity is Dictionary:
		var hp: int = int(target_entity.get("current_hp", 10))
		actual_dealt = mini(damage_roll, hp)
		target_entity["current_hp"] = hp - actual_dealt

	var crit_prefix := "CRITICAL HIT! " if attack_result["is_crit"] else ""
	return {
		"hit": true,
		"crit": attack_result["is_crit"],
		"damage": actual_dealt,
		"damage_type": damage_type,
		"attack_roll": attack_result["total"],
		"message": reaction_msg + "%sHit! (%d vs AC %d) Dealing %d %s damage." % [crit_prefix, attack_result["total"], target_ac, actual_dealt, damage_type]
	}


## Resolve casting a spell.
## Supports single-target, healing, and saving-throw based spells.
static func resolve_spell(caster: Character, target_entity, spell_data: Dictionary, deduct_slot: bool = false) -> Dictionary:
	var spell_level: int = int(spell_data.get("level", 0))

	# Deduct spell slot if leveled spell
	if deduct_slot and spell_level > 0:
		var slot_key := str(spell_level)
		var current_slots: int = caster.spell_slots.get(slot_key, 0)
		if current_slots <= 0:
			return {"success": false, "message": "No level %d spell slots remaining!" % spell_level}
		caster.spell_slots[slot_key] = current_slots - 1

	# Counterspell reaction check
	if target_entity is Character and target_entity.reaction_available and "counterspell" in target_entity.known_spells and target_entity.spell_slots.get("3", 0) > 0:
		target_entity.reaction_available = false
		target_entity.spell_slots["3"] -= 1
		return {
			"success": false,
			"message": "[color=cyan]%s casts Counterspell as a reaction! %s's spell is interrupted and fails.[/color]" % [target_entity.character_name, caster.character_name]
		}

	var is_save_based: bool = spell_data.has("save")
	if is_save_based:
		var save_ability: String = spell_data.get("save", "DEX")
		var save_dc := 8 + caster.ability_scores.get_ability_modifier("INT") + caster.proficiency_bonus
		
		# Roll save for target
		var save_roll := 0
		if target_entity is Character:
			save_roll = target_entity.make_saving_throw(save_ability)
		elif target_entity is Dictionary:
			# Monster stats
			var monster_scores: Dictionary = target_entity.get("ability_scores", {})
			var score: int = int(monster_scores.get(save_ability, 10))
			var modifier := AbilityScores.get_modifier(score)
			save_roll = Dice.roll(20) + modifier

		var saved := save_roll >= save_dc
		
		# Roll damage
		var damage_str: String = spell_data.get("damage", "1d6")
		var damage_type: String = spell_data.get("damage_type", "fire")
		var base_dmg := Dice.parse_dice_string(damage_str)
		
		var has_evasion := false
		if target_entity is Character and target_entity.has_feature("evasion") and save_ability == "DEX":
			has_evasion = true

		if saved:
			if has_evasion:
				base_dmg = 0
			elif spell_data.get("half_on_save", false):
				base_dmg = int(floor(float(base_dmg) / 2.0))
			else:
				base_dmg = 0
		else:
			if has_evasion and spell_data.get("half_on_save", false):
				base_dmg = int(floor(float(base_dmg) / 2.0))

		# Apply damage
		var actual := 0
		if base_dmg > 0:
			if target_entity is Character:
				actual = target_entity.take_damage(base_dmg)
			elif target_entity is Dictionary:
				var hp: int = int(target_entity.get("current_hp", 10))
				actual = mini(base_dmg, hp)
				target_entity["current_hp"] = hp - actual

		var msg := ""
		if saved:
			msg = "%s succeeded on %s save (DC %d) taking %d %s damage." % [target_entity.get("name", "Target"), save_ability, save_dc, actual, damage_type]
		else:
			msg = "%s failed %s save (DC %d) taking %d %s damage." % [target_entity.get("name", "Target"), save_ability, save_dc, actual, damage_type]
		
		return {"success": true, "damage": actual, "message": msg}

	else:
		# Standard spell attack roll
		var spell_stat := "INT" # Wizards use INT
		var attack_result := caster.make_attack_roll(spell_stat)
		
		var target_ac := 10
		if target_entity is Character:
			target_ac = target_entity.get_ac()
		elif target_entity is Dictionary:
			target_ac = int(target_entity.get("armor_class", 10))

		var is_crit := bool(attack_result["is_crit"])
		var is_hit: bool = is_crit or (attack_result["total"] >= target_ac)
		var reaction_msg := ""

		# Shield Reaction Spell
		if is_hit and not is_crit and target_entity is Character:
			if target_entity.reaction_available and "shield" in target_entity.known_spells and target_entity.spell_slots.get("1", 0) > 0:
				target_entity.reaction_available = false
				target_entity.spell_slots["1"] -= 1
				target_entity.add_condition("shield", 1)
				target_ac = target_entity.get_ac()
				is_hit = attack_result["total"] >= target_ac
				reaction_msg = "[color=cyan]%s casts Shield as a reaction! AC increases to %d.[/color]\n" % [target_entity.character_name, target_ac]

		if not is_hit:
			return {"success": true, "hit": false, "message": reaction_msg + "Spell missed! Ranged spell attack %d vs AC %d" % [attack_result["total"], target_ac]}

		var damage_str: String = spell_data.get("damage", "1d10")
		var damage_type: String = spell_data.get("damage_type", "fire")
		var base_dmg := Dice.parse_dice_string(damage_str)

		if attack_result["is_crit"]:
			base_dmg += Dice.parse_dice_string(damage_str)

		# Uncanny Dodge Reaction
		if target_entity is Character and target_entity.reaction_available and target_entity.has_feature("uncanny_dodge"):
			target_entity.reaction_available = false
			base_dmg = int(floor(float(base_dmg) / 2.0))
			reaction_msg += "[color=cyan]%s uses Uncanny Dodge as a reaction to halve incoming damage![/color]\n" % target_entity.character_name

		var actual := 0
		if target_entity is Character:
			actual = target_entity.take_damage(base_dmg)
		elif target_entity is Dictionary:
			var hp: int = int(target_entity.get("current_hp", 10))
			actual = mini(base_dmg, hp)
			target_entity["current_hp"] = hp - actual

		return {
			"success": true,
			"hit": true,
			"damage": actual,
			"message": reaction_msg + "Spell Hit! Dealing %d %s damage." % [actual, damage_type]
		}
