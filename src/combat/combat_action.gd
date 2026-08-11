## Combat Action Resolver
## Implements D&D 5e combat mechanics: attack rolls, spellcasting, healing, and AC protection.
class_name CombatAction
extends RefCounted


## Apply one already-validated movement step for either a player or monster.
## Path legality and opportunity attacks stay with CombatState, while this
## boundary owns the shared position mutation and result shape.
static func resolve_movement_step(entity_dict: Dictionary, from_hex: Vector2i, to_hex: Vector2i) -> Dictionary:
	if entity_dict.is_empty() or not entity_dict.has("hex_position"):
		return {"success": false, "from": from_hex, "to": to_hex, "message": "Movement needs a positioned entity."}
	if entity_dict["hex_position"] != from_hex:
		return {"success": false, "from": from_hex, "to": to_hex, "message": "Movement path is stale."}
	entity_dict["hex_position"] = to_hex
	return {"success": true, "from": from_hex, "to": to_hex, "message": "Movement step resolved."}


## Resolve Lay on Hands against a living or downed allied character.
## The caller supplies the amount requested; the pool and missing HP cap it.
static func resolve_lay_on_hands(caster: Character, target: Character, requested_amount: int) -> Dictionary:
	if caster == null or target == null or requested_amount <= 0:
		return {"success": false, "healing": 0, "message": "Lay on Hands needs a valid healing target."}
	var pool := int(caster.feature_uses.get("paladin_lay_on_hands", 0))
	var missing := maxi(0, target.max_hp - target.current_hp)
	var healing := mini(requested_amount, mini(pool, missing))
	if healing <= 0:
		return {"success": false, "healing": 0, "message": "%s has no wounds Lay on Hands can restore." % target.character_name}
	target.current_hp += healing
	target.is_alive = true
	caster.feature_uses["paladin_lay_on_hands"] = pool - healing
	return {"success": true, "healing": healing, "message": "%s restores %d hit points to %s." % [caster.character_name, healing, target.character_name]}


## Resolve a monk bonus unarmed strike through the normal weapon attack boundary.
static func resolve_unarmed_attack(attacker: Character, target_entity) -> Dictionary:
	if attacker == null or target_entity == null:
		return {"hit": false, "damage": 0, "message": "Unarmed Strike needs a valid target."}
	var damage_die := "1d4"
	if attacker.level >= 17:
		damage_die = "1d10"
	elif attacker.level >= 11:
		damage_die = "1d8"
	elif attacker.level >= 5:
		damage_die = "1d6"
	return resolve_weapon_attack(attacker, target_entity, {
		"ability": "DEX",
		"damage": damage_die,
		"damage_type": "bludgeoning",
		"range": 1,
	})


## Resolve the two unarmed strikes granted by Monk Flurry of Blows.
static func resolve_flurry_of_blows(attacker: Character, target_entity) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	for strike_index in 2:
		if target_entity is Character and not target_entity.is_alive:
			break
		if target_entity is Dictionary and not target_entity.get("is_alive", true):
			break
		results.append(resolve_unarmed_attack(attacker, target_entity))
		if target_entity is Dictionary and int(target_entity.get("current_hp", 0)) <= 0:
			target_entity["is_alive"] = false
	return results


## Activate Barbarian Reckless Attack for the current turn.
## The marker lasts through the rest of the round so monster attacks gain
## advantage, then CombatState clears it when the barbarian's next turn starts.
static func activate_reckless_attack(attacker: Character) -> Dictionary:
	if attacker == null or not attacker.has_feature("barbarian_reckless_attack"):
		return {"success": false, "message": "Reckless Attack is unavailable."}
	if int(attacker.feature_uses.get("barbarian_reckless_attack_used_this_turn", 0)) > 0:
		return {"success": false, "message": "Reckless Attack was already chosen this turn."}
	attacker.feature_uses["barbarian_reckless_attack_used_this_turn"] = 1
	attacker.add_condition("reckless_attack", 2)
	return {"success": true, "message": "%s attacks recklessly until their next turn." % attacker.character_name}


## Detect nearby celestial, fiend, and undead monster records for Paladin Divine Sense.
## Monster creature types come from curated production data, never name matching.
static func resolve_divine_sense(caster: Character, monsters: Array, origin: Vector2i, max_distance: int = 12) -> Dictionary:
	if caster == null or not caster.has_feature("paladin_divine_sense"):
		return {"success": false, "target_ids": [], "message": "Divine Sense is unavailable."}
	var detection_types: Array = ["celestial", "fiend", "undead"]
	var feature_data: Dictionary = caster.get_feature("paladin_divine_sense")
	for effect in feature_data.get("effects", []):
		if effect.get("type", "") == "divine_sense" and effect.get("creature_types", []) is Array:
			detection_types = effect.get("creature_types", [])
			break
	var target_ids: Array[String] = []
	var target_labels: Array[String] = []
	for monster in monsters:
		if not monster is Dictionary or not monster.get("is_alive", true):
			continue
		var creature_type := str(monster.get("creature_type", ""))
		if creature_type not in detection_types:
			continue
		if HexUtils.get_distance(origin, monster.get("hex_position", Vector2i.ZERO)) > max_distance:
			continue
		var target_id := str(monster.get("id", ""))
		if target_id.is_empty():
			continue
		target_ids.append(target_id)
		target_labels.append("%s (%s)" % [monster.get("name", target_id), creature_type])
	caster.feature_uses["paladin_divine_sense_targets"] = target_ids
	return {"success": true, "target_ids": target_ids, "labels": target_labels, "message": "Divine Sense detects: %s." % ", ".join(target_labels) if not target_labels.is_empty() else "Divine Sense detects no nearby celestial, fiend, or undead."}


## Give an ally one Bardic Inspiration die they can spend on their next attack.
static func resolve_bardic_inspiration(caster: Character, target: Character) -> Dictionary:
	if caster == null or target == null or caster == target or not caster.has_feature("bard_bardic_inspiration"):
		return {"success": false, "message": "Bardic Inspiration needs another valid ally."}
	if target.feature_uses.has("bardic_inspiration_die"):
		return {"success": false, "message": "%s already has Bardic Inspiration." % target.character_name}
	if not caster.use_feature("bard_bardic_inspiration"):
		return {"success": false, "message": "%s has no Bardic Inspiration uses remaining." % caster.character_name}
	var die := "1d8" if caster.level >= 5 else "1d6"
	target.feature_uses["bardic_inspiration_die"] = die
	target.feature_uses["bardic_inspiration_source"] = caster.character_name
	return {"success": true, "die": die, "message": "%s grants %s Bardic Inspiration (%s)." % [caster.character_name, target.character_name, die]}


## Consume the held Bardic Inspiration die and return its rolled bonus.
static func consume_bardic_inspiration(target: Character) -> Dictionary:
	if target == null or not target.feature_uses.has("bardic_inspiration_die"):
		return {"success": false, "bonus": 0, "message": "No Bardic Inspiration die is held."}
	var die := str(target.feature_uses.get("bardic_inspiration_die", "1d6"))
	var bonus := Dice.parse_dice_string(die)
	target.feature_uses.erase("bardic_inspiration_die")
	target.feature_uses.erase("bardic_inspiration_source")
	return {"success": true, "bonus": bonus, "die": die, "message": "%s adds Bardic Inspiration (%d)." % [target.character_name, bonus]}


## Mark a monster for a ranger's concentration-bound Favored Foe feature.
static func resolve_favored_foe_mark(attacker: Character, target_entity: Dictionary) -> Dictionary:
	if attacker == null or target_entity.is_empty() or not attacker.has_feature("ranger_favored_foe"):
		return {"success": false, "message": "Favored Foe needs a valid ranger and target."}
	var target_id := str(target_entity.get("id", ""))
	if target_id.is_empty():
		return {"success": false, "message": "Favored Foe target has no stable combat identity."}
	var conditions: Dictionary = target_entity.get("conditions", {})
	conditions["favored_foe"] = 10
	target_entity["conditions"] = conditions
	attacker.feature_uses["ranger_favored_foe_target_id"] = target_id
	attacker.concentrating_on = {
		"spell_id": "ranger_favored_foe",
		"targets": [],
		"effects": []
	}
	return {"success": true, "target_id": target_id, "message": "%s marks %s as a Favored Foe." % [attacker.character_name, target_entity.get("name", "the target")]}


## Resolve the once-per-turn bonus damage from an active Favored Foe mark.
static func resolve_favored_foe_damage(attacker: Character, target_entity: Dictionary) -> Dictionary:
	if attacker == null or target_entity.is_empty() or not attacker.has_feature("ranger_favored_foe"):
		return {"success": false, "damage": 0, "message": "No Favored Foe damage applies."}
	var target_id := str(target_entity.get("id", ""))
	if str(attacker.feature_uses.get("ranger_favored_foe_target_id", "")) != target_id:
		return {"success": false, "damage": 0, "message": "Target is not the ranger's Favored Foe."}
	if not target_entity.get("conditions", {}).has("favored_foe") or int(attacker.feature_uses.get("ranger_favored_foe_used_this_turn", 0)) > 0:
		return {"success": false, "damage": 0, "message": "Favored Foe damage is unavailable this turn."}
	var dice := "1d4"
	if attacker.level >= 14:
		dice = "1d8"
	elif attacker.level >= 6:
		dice = "1d6"
	var rolled := Dice.parse_dice_string(dice)
	var hp := int(target_entity.get("current_hp", 0))
	var actual := mini(rolled, hp)
	target_entity["current_hp"] = hp - actual
	attacker.feature_uses["ranger_favored_foe_used_this_turn"] = 1
	return {"success": true, "damage": actual, "dice": dice, "message": "Favored Foe deals +%d %s damage." % [actual, dice]}


## Mark a monster for the concentration-bound Hunter's Mark spell.
static func resolve_hunters_mark(caster: Character, target_entity: Dictionary) -> Dictionary:
	if caster == null or target_entity.is_empty():
		return {"success": false, "message": "Hunter's Mark needs a valid target."}
	var target_id := str(target_entity.get("id", ""))
	if target_id.is_empty():
		return {"success": false, "message": "Hunter's Mark target has no stable combat identity."}
	var conditions: Dictionary = target_entity.get("conditions", {})
	conditions["hunters_mark"] = 10
	target_entity["conditions"] = conditions
	caster.feature_uses["hunters_mark_target_id"] = target_id
	caster.concentrating_on = {
		"spell_id": "hunters_mark",
		"targets": [],
		"effects": [{"type": "hunters_mark", "dice": "1d6", "duration": 10}],
	}
	return {"success": true, "target_id": target_id, "message": "%s marks %s as their quarry." % [caster.character_name, target_entity.get("name", "the target")]}


## Resolve Hunter's Mark's extra damage on every weapon hit against its target.
static func resolve_hunters_mark_damage(attacker: Character, target_entity: Dictionary) -> Dictionary:
	if attacker == null or target_entity.is_empty():
		return {"success": false, "damage": 0, "message": "No Hunter's Mark damage applies."}
	var target_id := str(target_entity.get("id", ""))
	if str(attacker.feature_uses.get("hunters_mark_target_id", "")) != target_id or not target_entity.get("conditions", {}).has("hunters_mark"):
		return {"success": false, "damage": 0, "message": "Target is not marked by Hunter's Mark."}
	var rolled := Dice.parse_dice_string("1d6")
	var hp := int(target_entity.get("current_hp", 0))
	var actual := mini(rolled, hp)
	target_entity["current_hp"] = hp - actual
	return {"success": true, "damage": actual, "dice": "1d6", "message": "Hunter's Mark deals +%d 1d6 damage." % actual}


## Resolve a basic weapon attack.
## Returns a result dictionary describing the hit, miss, crit, damage, and logs.
static func resolve_weapon_attack(attacker: Character, target_entity, weapon_data: Dictionary, advantage: bool = false, disadvantage: bool = false, reaction_decisions: Dictionary = {}) -> Dictionary:
	var ability: String = weapon_data.get("ability", "STR")
	
	# Roll attack
	var attack_result := attacker.make_attack_roll(ability, advantage, disadvantage, weapon_data)
	if attack_result["is_miss"]:
		return {"hit": false, "message": "Miss! (Natural 1)"}
	var bardic_bonus := 0
	var bardic_message := ""
	if attacker is Character and bool(reaction_decisions.get("bardic_inspiration", false)):
		var inspiration := consume_bardic_inspiration(attacker)
		if inspiration.get("success", false):
			bardic_bonus = int(inspiration.get("bonus", 0))
			attack_result["total"] += bardic_bonus
			bardic_message = " [color=cyan]%s[/color]" % inspiration.get("message", "Bardic Inspiration")

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
		if target_entity.reaction_available and "shield" in target_entity.known_spells and target_entity.spell_slots.get("1", 0) > 0 and _reaction_accepted("shield", reaction_decisions):
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
	if damage_type in ["bludgeoning", "piercing", "slashing"] and attacker is Character:
		damage_roll += attacker.get_modifier("stat", "damage:physical")
	
	# Crits double damage dice
	if attack_result["is_crit"]:
		# Roll damage dice a second time
		damage_roll += Dice.parse_dice_string(damage_str, {"STR": 0, "DEX": 0})

	# Uncanny Dodge Reaction
	if target_entity is Character and target_entity.reaction_available and (target_entity.has_feature("uncanny_dodge") or target_entity.has_feature("rogue_uncanny_dodge")) and _reaction_accepted("uncanny_dodge", reaction_decisions):
		target_entity.reaction_available = false
		damage_roll = int(floor(float(damage_roll) / 2.0))
		reaction_msg += "[color=cyan]%s uses Uncanny Dodge as a reaction to halve the incoming damage![/color]\n" % target_entity.character_name

	# Rage resistance applies to physical weapon damage.
	if target_entity is Character and target_entity.has_condition("raging") and damage_type in ["bludgeoning", "piercing", "slashing"]:
		damage_roll = int(floor(float(damage_roll) / 2.0))

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
		"bardic_bonus": bardic_bonus,
		"message": reaction_msg + bardic_message + "%sHit! (%d vs AC %d) Dealing %d %s damage." % [crit_prefix, attack_result["total"], target_ac, actual_dealt, damage_type]
	}


## Resolve production monster attack riders after the base attack hits.
## Monster data stays declarative; this boundary owns saves, conditions, and
## persistent target damage so AI and player-triggered fixtures share behavior.
static func resolve_monster_attack_effects(monster: Dictionary, target: Character, attack_data: Dictionary, attack_result: Dictionary) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	if monster.is_empty() or target == null or not attack_result.get("hit", false):
		return results
	for effect in attack_data.get("extra_effects", []):
		var effect_type := str(effect.get("type", ""))
		match effect_type:
			"poison_save", "restrain", "paralyze_save":
				var save_ability := str(effect.get("save", "CON"))
				var dc := int(effect.get("dc", 10))
				var save_total := target.make_saving_throw(save_ability)
				if save_total >= dc:
					results.append({"type": effect_type, "success": true, "message": "%s resists %s (%d vs DC %d)." % [target.character_name, effect_type.replace("_", " "), save_total, dc]})
					continue
				var duration := maxi(1, int(effect.get("duration", 1)))
				if effect_type == "poison_save":
					target.add_condition("poisoned", duration)
					var poison_damage := Dice.parse_dice_string(str(effect.get("damage", "1d6")))
					var actual_poison := target.take_damage(poison_damage)
					results.append({"type": effect_type, "success": false, "damage": actual_poison, "message": "%s is poisoned and takes %d poison damage." % [target.character_name, actual_poison]})
				elif effect_type == "restrain":
					target.add_condition("restrained", duration)
					results.append({"type": effect_type, "success": false, "message": "%s is restrained for %d turn(s)." % [target.character_name, duration]})
				else:
					target.add_condition("paralyzed", duration)
					results.append({"type": effect_type, "success": false, "message": "%s is paralyzed for %d turn(s)." % [target.character_name, duration]})
			"corrode_armor":
				target.add_modifier("stat", "AC", -1, int(effect.get("duration", 10)))
				results.append({"type": effect_type, "success": true, "message": "%s's armor corrodes (-1 AC)." % target.character_name})
			"reduce_max_hp":
				var reduction := int(attack_result.get("damage", 0))
				if str(effect.get("value", "")) != "damage_dealt":
					reduction = int(effect.get("value", reduction))
				target.max_hp = maxi(1, target.max_hp - maxi(0, reduction))
				target.current_hp = mini(target.current_hp, target.max_hp)
				results.append({"type": effect_type, "success": true, "value": reduction, "message": "%s loses %d maximum hit point(s)." % [target.character_name, reduction]})
	return results


## Apply Paladin Divine Smite after a confirmed melee hit.
## The caller owns the in-shell choice; this boundary owns slot consumption and
## radiant damage so direct and normal-path tests share the same mechanics.
static func resolve_divine_smite(caster: Character, target_entity, slot_level: int = 1) -> Dictionary:
	var bounded_level := clampi(slot_level, 1, 4)
	var slot_key := str(bounded_level)
	var available := int(caster.spell_slots.get(slot_key, 0))
	if available <= 0:
		return {"success": false, "damage": 0, "message": "No level %d spell slots remain for Divine Smite." % bounded_level}
	caster.spell_slots[slot_key] = available - 1
	var dice_count := mini(5, bounded_level + 1)
	var damage := Dice.parse_dice_string("%dd8" % dice_count)
	var actual := 0
	if target_entity is Character:
		actual = target_entity.take_damage(damage)
	elif target_entity is Dictionary:
		var hp := int(target_entity.get("current_hp", 0))
		actual = mini(damage, hp)
		target_entity["current_hp"] = hp - actual
	return {
		"success": true,
		"damage": actual,
		"damage_type": "radiant",
		"slot_level": bounded_level,
		"message": "Divine Smite deals %d radiant damage using a level %d spell slot." % [actual, bounded_level]
	}


## Validate the entity selected for a spell before spending a slot or action.
## Self and ally-only spells must not silently resolve against an invalid target.
static func validate_spell_target(caster: Character, target_entity, spell_data: Dictionary) -> Dictionary:
	if caster == null or spell_data.is_empty():
		return {"success": false, "message": "Spell needs a valid caster and spell record."}
	if str(spell_data.get("casting_time", "action")) == "reaction":
		return {"success": false, "message": "%s resolves only through its reaction boundary." % spell_data.get("name", "This spell")}
	var target_type := str(spell_data.get("target", "single"))
	match target_type:
		"self":
			if not target_entity is Character or target_entity != caster:
				return {"success": false, "message": "%s can only target its caster." % spell_data.get("name", "This spell")}
		"single_ally":
			if not target_entity is Character:
				return {"success": false, "message": "%s needs a living ally target." % spell_data.get("name", "This spell")}
	return {"success": true}


## Resolve casting a spell.
## Supports single-target, healing, and saving-throw based spells.
static func resolve_spell(caster: Character, target_entity, spell_data: Dictionary, deduct_slot: bool = false, reaction_decisions: Dictionary = {}, reaction_observers: Array = [], slot_level_override: int = 0) -> Dictionary:
	var target_validation := validate_spell_target(caster, target_entity, spell_data)
	if not target_validation.get("success", false):
		return target_validation
	var spell_level: int = int(spell_data.get("level", 0))
	var slot_level_used: int = maxi(spell_level, slot_level_override)

	# Deduct spell slot if leveled spell
	if deduct_slot and spell_level > 0:
		var slot_result := spend_spell_slot(caster, spell_data)
		if not slot_result.get("success", false):
			return slot_result
		slot_level_used = int(slot_result.get("slot_level", spell_level))

	# Counterspell reaction check. Direct callers may still pass the target as
	# the counterspeller; combat state can provide an observer list when the
	# spell targets a monster or area.
	var counterspell_candidates: Array = []
	if target_entity is Character:
		counterspell_candidates.append(target_entity)
	for observer in reaction_observers:
		if observer is Character and observer not in counterspell_candidates:
			counterspell_candidates.append(observer)
	for observer in counterspell_candidates:
		if not observer.reaction_available or "counterspell" not in observer.known_spells or observer.spell_slots.get("3", 0) <= 0:
			continue
		var observer_key := "counterspell:%s" % observer.character_name
		var accepted := bool(reaction_decisions.get(observer_key, reaction_decisions.get("counterspell", true)))
		if not accepted:
			continue
		observer.reaction_available = false
		observer.spell_slots["3"] -= 1
		return {
			"success": false,
			"message": "[color=cyan]%s casts Counterspell as a reaction! %s's spell is interrupted and fails.[/color]" % [observer.character_name, caster.character_name]
		}


	if str(spell_data.get("id", "")) == "hunters_mark":
		return resolve_hunters_mark(caster, target_entity)

	if spell_data.has("damage_per_dart"):
		return _resolve_magic_missile(caster, target_entity, spell_data, reaction_decisions, slot_level_used)
	if spell_data.has("damage_per_ray"):
		return _resolve_scorching_ray(caster, target_entity, spell_data, reaction_decisions, slot_level_used)
	var has_damage_payload := spell_data.has("damage") or spell_data.has("damage_per_dart") or spell_data.has("damage_per_ray")
	if not has_damage_payload and not spell_data.has("save") and str(spell_data.get("attack_type", "none")) == "none":
		return {"success": true, "hit": true, "damage": 0, "message": "%s resolves without a damage roll." % spell_data.get("name", "Spell")}

	var is_save_based: bool = spell_data.has("save")
	if is_save_based:
		var save_ability: String = spell_data.get("save", "DEX")
		var save_stat := str(DataLoader.get_character_class(caster.class_id).get("primary_ability", "INT"))
		var save_dc := caster.get_spell_save_dc()
		
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
		var metamagic_result := _apply_empowered_spell(caster, damage_str, base_dmg, reaction_decisions)
		base_dmg = int(metamagic_result.get("damage", base_dmg))
		
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
		
		if metamagic_result.get("used", false):
			msg = "[color=magenta]Empowered Spell improves the damage roll.[/color] " + msg
		return {"success": true, "damage": actual, "metamagic_used": metamagic_result.get("used", false), "message": msg}

	else:
		# Standard spell attack roll
		var spell_stat := str(DataLoader.get_character_class(caster.class_id).get("primary_ability", "INT"))
		var attack_result := caster.make_attack_roll(spell_stat, caster.has_condition("innate_sorcery"))
		
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
			if target_entity.reaction_available and "shield" in target_entity.known_spells and target_entity.spell_slots.get("1", 0) > 0 and _reaction_accepted("shield", reaction_decisions):
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

		var metamagic_result := _apply_empowered_spell(caster, damage_str, base_dmg, reaction_decisions)
		base_dmg = int(metamagic_result.get("damage", base_dmg))
		var metamagic_message := "[color=magenta]Empowered Spell improves the damage roll.[/color] " if metamagic_result.get("used", false) else ""

		# Uncanny Dodge Reaction
		if target_entity is Character and target_entity.reaction_available and (target_entity.has_feature("uncanny_dodge") or target_entity.has_feature("rogue_uncanny_dodge")) and _reaction_accepted("uncanny_dodge", reaction_decisions):
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
			"metamagic_used": metamagic_result.get("used", false),
			"message": reaction_msg + metamagic_message + "Spell Hit! Dealing %d %s damage." % [actual, damage_type]
		}


static func _slot_key_for_spell(caster: Character, spell_level: int) -> String:
	var available_keys: Array[int] = []
	for key in caster.spell_slots.keys():
		if int(key) >= spell_level and int(caster.spell_slots[key]) > 0:
			available_keys.append(int(key))
	available_keys.sort()
	if not available_keys.is_empty():
		return str(available_keys[0])
	return str(spell_level)


static func _resolve_magic_missile(caster: Character, target_entity, spell_data: Dictionary, reaction_decisions: Dictionary = {}, slot_level: int = 0) -> Dictionary:
	var dart_count := int(spell_data.get("dart_count", 3))
	var base_level := int(spell_data.get("level", 1))
	var upcast: Dictionary = spell_data.get("upcast", {})
	dart_count += maxi(0, slot_level - base_level) * int(upcast.get("extra_darts_per_level", 0))
	var damage_per_dart := str(spell_data.get("damage_per_dart", "1d4+1")).replace(" ", "")
	var rolled_damage := 0
	for _dart in dart_count:
		rolled_damage += Dice.parse_dice_string(damage_per_dart)
	var metamagic_result := _apply_empowered_spell(caster, damage_per_dart, rolled_damage, reaction_decisions)
	var actual := _apply_spell_damage(target_entity, int(metamagic_result.get("damage", rolled_damage)))
	var metamagic_message := " Empowered Spell improves the damage roll." if metamagic_result.get("used", false) else ""
	return {
		"success": true,
		"hit": true,
		"damage": actual,
		"dart_count": dart_count,
		"metamagic_used": metamagic_result.get("used", false),
		"message": "%s hits automatically with %d darts for %d %s damage.%s" % [spell_data.get("name", "Magic Missile"), dart_count, actual, spell_data.get("damage_type", "force"), metamagic_message]
	}


static func _resolve_scorching_ray(caster: Character, target_entity, spell_data: Dictionary, reaction_decisions: Dictionary, slot_level: int = 0) -> Dictionary:
	var ray_count := int(spell_data.get("ray_count", 3))
	var base_level := int(spell_data.get("level", 2))
	var upcast: Dictionary = spell_data.get("upcast", {})
	ray_count += maxi(0, slot_level - base_level) * int(upcast.get("extra_rays_per_level", 0))
	var damage_dice := str(spell_data.get("damage_per_ray", "2d6")).replace(" ", "")
	var target_ac := 10
	if target_entity is Character:
		target_ac = target_entity.get_ac()
	elif target_entity is Dictionary:
		target_ac = int(target_entity.get("armor_class", 10))
	var hits := 0
	var rolled_damage := 0
	for _ray in ray_count:
		var attack_result := caster.make_attack_roll(str(DataLoader.get_character_class(caster.class_id).get("primary_ability", "INT")), caster.has_condition("innate_sorcery"))
		if bool(attack_result.get("is_crit", false)) or int(attack_result.get("total", 0)) >= target_ac:
			hits += 1
			rolled_damage += Dice.parse_dice_string(damage_dice)
			if attack_result.get("is_crit", false):
				rolled_damage += Dice.parse_dice_string(damage_dice)
	if hits == 0:
		return {"success": true, "hit": false, "damage": 0, "ray_count": ray_count, "message": "%s misses all %d rays." % [spell_data.get("name", "Scorching Ray"), ray_count]}
	var metamagic_result := _apply_empowered_spell(caster, damage_dice, rolled_damage, reaction_decisions)
	var actual := _apply_spell_damage(target_entity, int(metamagic_result.get("damage", rolled_damage)))
	var metamagic_message := " Empowered Spell improves the damage roll." if metamagic_result.get("used", false) else ""
	return {
		"success": true,
		"hit": true,
		"damage": actual,
		"ray_count": ray_count,
		"rays_hit": hits,
		"metamagic_used": metamagic_result.get("used", false),
		"message": "%s hits with %d of %d rays for %d %s damage.%s" % [spell_data.get("name", "Scorching Ray"), hits, ray_count, actual, spell_data.get("damage_type", "fire"), metamagic_message]
	}


static func _apply_spell_damage(target_entity, amount: int) -> int:
	var bounded_amount := maxi(0, amount)
	if target_entity is Character:
		return target_entity.take_damage(bounded_amount)
	if target_entity is Dictionary:
		var hp := int(target_entity.get("current_hp", 0))
		var actual := mini(bounded_amount, hp)
		target_entity["current_hp"] = hp - actual
		return actual
	return 0


static func spend_spell_slot(caster: Character, spell_data: Dictionary) -> Dictionary:
	var spell_level: int = int(spell_data.get("level", 0))
	if spell_level <= 0:
		return {"success": true, "slot_level": 0}
	var slot_key := _slot_key_for_spell(caster, spell_level)
	var current_slots: int = caster.spell_slots.get(slot_key, 0)
	if current_slots <= 0:
		return {"success": false, "message": "No level %d spell slots remaining!" % spell_level}
	caster.spell_slots[slot_key] = current_slots - 1
	return {"success": true, "slot_level": int(slot_key)}


static func get_spell_slot_level(caster: Character, spell_data: Dictionary) -> int:
	var spell_level := int(spell_data.get("level", 0))
	if spell_level <= 0:
		return 0
	return int(_slot_key_for_spell(caster, spell_level))


static func _apply_empowered_spell(caster: Character, damage_dice: String, current_damage: int, reaction_decisions: Dictionary) -> Dictionary:
	if not bool(reaction_decisions.get("metamagic:empowered", false)) or not caster.has_feature("sorcerer_metamagic"):
		return {"damage": current_damage, "used": false}
	if not caster.spend_sorcery_points(1):
		return {"damage": current_damage, "used": false}
	var rerolled_damage := Dice.parse_dice_string(damage_dice)
	return {"damage": maxi(current_damage, rerolled_damage), "used": true}


static func _reaction_accepted(reaction_id: String, decisions: Dictionary) -> bool:
	# Existing direct resolver callers retain the deterministic automatic policy.
	# CombatState supplies an explicit decision map for owner-facing prompts.
	return bool(decisions.get(reaction_id, true))
