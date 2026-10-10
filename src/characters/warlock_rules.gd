## Saved Warlock invocation and Mystic Arcanum progression.
class_name WarlockRules
extends RefCounted

static func invocation_capacity(at_level: int) -> int:
	var table: Dictionary = DataLoader.get_character_class("warlock").get("eldritch_invocations_by_level", {})
	var capacity := 0
	for key in table:
		if int(key) <= at_level:
			capacity = maxi(capacity, int(table[key]))
	return capacity


static func invocation_options(c: Character) -> Array:
	return DataLoader.get_character_class("warlock").get("eldritch_invocation_options", [])


static func has_invocation(c: Character, invocation_id: String) -> bool:
	if c == null or c.class_id != "warlock":
		return false
	for selection_id in c.warlock_invocations:
		if str(selection_id).split(":")[0] == invocation_id:
			return true
	return false


static func _known_damage_cantrips(c: Character, attack_roll_only: bool = false) -> Array[String]:
	var result: Array[String] = []
	for spell_id in c.known_spells:
		var spell := DataLoader.get_spell(spell_id)
		if int(spell.get("level", -1)) != 0 or not spell.has("damage"):
			continue
		if attack_roll_only and str(spell.get("attack_type", "none")) not in ["ranged_spell", "melee_spell"]:
			continue
		result.append(spell_id)
	return result


static func available_invocation_selections(c: Character, candidate_selections: Array[String] = []) -> Array[String]:
	var choices: Array[String] = []
	if c == null or c.class_id != "warlock":
		return choices
	for option in invocation_options(c):
		var option_id := str(option.get("id", ""))
		var spells_available := true
		for effect in option.get("effects", []):
			if str(effect.get("type", "")) in ["spell_free_cast", "always_prepared_spells"]:
				for spell_id in effect.get("spells", []):
					if not SpellSupport.is_available(DataLoader.get_spell(str(spell_id))):
						spells_available = false
		if not spells_available and option_id not in c.warlock_invocations:
			continue
		if c.level < int(option.get("minimum_level", 1)):
			continue
		var requires: Array = option.get("requires_invocations", [])
		var has_requirements := true
		for required_id in requires:
			var has_req: bool = c.warlock_invocations.any(func(value): return str(value).split(":")[0] == str(required_id)) or candidate_selections.any(func(value): return str(value).split(":")[0] == str(required_id))
			if not has_req:
				has_requirements = false
		if not has_requirements:
			continue
		if bool(option.get("choose_damage_cantrip", false)):
			var cantrips := _known_damage_cantrips(c, bool(option.get("requires_attack_roll", false)))
			for spell_id in cantrips:
				var selection_id := "%s:%s" % [option_id, spell_id]
				# Keep existing choices in the list so a level-up can retain them.
				if selection_id not in c.warlock_invocations:
					choices.append(selection_id)
				else:
					choices.append(selection_id)
		else:
			choices.append(option_id)
	return choices


static func choose_invocations(c: Character, selection_ids: Array[String]) -> bool:
	if c == null or c.class_id != "warlock" or selection_ids.size() != invocation_capacity(c.level):
		return false
	var allowed := available_invocation_selections(c, selection_ids)
	var unique: Dictionary = {}
	for selection_id in selection_ids:
		if selection_id not in allowed or unique.has(selection_id):
			return false
		unique[selection_id] = true
	var removed := 0
	for old_id in c.warlock_invocations:
		if old_id not in selection_ids:
			removed += 1
	if removed > 1 or (removed > 0 and not c.warlock_invocation_replacement_available):
		return false
	# Do not allow a dependent invocation to survive removal of its prerequisite.
	for selection_id in selection_ids:
		var option_id := selection_id.split(":")[0]
		for option in invocation_options(c):
			if str(option.get("id", "")) != option_id:
				continue
			for required_id in option.get("requires_invocations", []):
				if not selection_ids.any(func(value): return str(value).split(":")[0] == str(required_id)):
					return false
	c.warlock_invocations = selection_ids.duplicate()
	c.warlock_invocation_pending = 0
	c.warlock_invocation_replacement_available = false
	ClassProgression.apply_feature_choice_grants(c)
	c.refresh_spell_selection_from_choices()
	return true


static func selected_invocation_effects(c: Character) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if c == null or c.class_id != "warlock":
		return result
	for selection_id in c.warlock_invocations:
		var parts := str(selection_id).split(":", false, 1)
		var option_id := parts[0]
		for option in invocation_options(c):
			if str(option.get("id", "")) != option_id:
				continue
			for declared in option.get("effects", []):
				var effect: Dictionary = declared.duplicate(true)
				if parts.size() > 1:
					effect["spell_ids"] = [parts[1]]
					effect["invocation_selection"] = selection_id
				result.append(effect)
	return result


static func arcanum_spells(c: Character, spell_level: int) -> Array[String]:
	var result: Array[String] = []
	if c == null or c.class_id != "warlock":
		return result
	var ids: Array = DataLoader.get_character_class("warlock").get("mystic_arcanum_spell_ids", {}).get(str(spell_level), [])
	for spell_id in ids:
		var spell := DataLoader.get_spell(str(spell_id))
		if not spell.is_empty() and int(spell.get("level", -1)) == spell_level and (SpellSupport.is_available(spell) or spell_id in c.warlock_mystic_arcanum.values()):
			result.append(str(spell_id))
	return result


static func choose_mystic_arcanum(c: Character, spell_level: int, spell_id: String) -> bool:
	if c == null or c.class_id != "warlock" or spell_id not in arcanum_spells(c, spell_level):
		return false
	var key := str(spell_level)
	var is_new_choice := spell_level in c.warlock_arcanum_pending_levels
	var is_replacement := c.warlock_mystic_arcanum.has(key) and c.warlock_arcanum_replacement_available
	if not is_new_choice and not is_replacement:
		return false
	if spell_id in c.warlock_mystic_arcanum.values():
		return false
	c.warlock_mystic_arcanum[key] = spell_id
	c.warlock_arcanum_uses[key] = 1
	if is_new_choice:
		c.warlock_arcanum_pending_levels.erase(spell_level)
	else:
		c.warlock_arcanum_replacement_available = false
	if spell_id not in c.known_spells:
		c.known_spells.append(spell_id)
	return true


static func arcanum_cast_level(c: Character, spell_id: String) -> int:
	if c == null or c.class_id != "warlock":
		return 0
	for key in c.warlock_mystic_arcanum:
		if str(c.warlock_mystic_arcanum[key]) == spell_id and int(c.warlock_arcanum_uses.get(str(key), 0)) > 0:
			return int(key)
	return 0


static func spend_arcanum_cast(c: Character, spell_id: String) -> bool:
	var spell_level := arcanum_cast_level(c, spell_id)
	if spell_level <= 0:
		return false
	c.warlock_arcanum_uses[str(spell_level)] = 0
	return true


## Dark One's Blessing: Temporary HP gained when reducing an enemy to 0 HP.
static func dark_ones_blessing_temp_hp(c: Character) -> int:
	if c == null:
		return 0
	return maxi(1, c.level + c.ability_scores.get_ability_modifier("CHA"))


static func apply_dark_ones_blessing(c: Character) -> int:
	if c == null or not c.has_feature("fiend_dark_ones_blessing"):
		return 0
	var thp := dark_ones_blessing_temp_hp(c)
	if thp > c.temp_hp:
		c.temp_hp = thp
	return thp


## Dark One's Own Luck: Add 1d10 to a failed check or save, uses = max(1, CHA) per Long Rest.
static func dark_ones_own_luck(c: Character, total: int, dc: int = -1) -> Dictionary:
	if c == null or not c.has_feature("fiend_dark_ones_own_luck"):
		return {"total": total, "bonus": 0, "spent": false}
	var pool := "fiend_dark_ones_own_luck"
	if int(c.feature_uses.get(pool, 0)) <= 0:
		return {"total": total, "bonus": 0, "spent": false}
	var bonus := Dice.roll(10, c)
	c.use_feature(pool)
	var new_total := total + bonus
	return {"total": new_total, "bonus": bonus, "spent": true}


## Fiendish Resilience: Choose damage resistance (any except Force).
static func choose_fiendish_resilience(c: Character, damage_type: String) -> bool:
	if c == null or not c.has_feature("fiend_fiendish_resilience"):
		return false
	var valid_types := ["acid", "bludgeoning", "cold", "fire", "lightning", "necrotic", "piercing", "poison", "psychic", "radiant", "slashing", "thunder"]
	if damage_type not in valid_types:
		return false
	c.fiendish_resilience_type = damage_type
	return true


static func has_fiendish_resilience(c: Character, damage_type: String) -> bool:
	if c == null or not c.has_feature("fiend_fiendish_resilience") or damage_type == "force":
		return false
	var active_type := c.fiendish_resilience_type if not c.fiendish_resilience_type.is_empty() else "fire"
	return damage_type == active_type


## Hurl Through Hell: Transport target through the Lower Planes on attack hit.
static func resolve_hurl_through_hell(attacker: Character, target_entity) -> Dictionary:
	if attacker == null or not attacker.has_feature("fiend_hurl_through_hell") or target_entity == null:
		return {"success": false, "damage": 0, "message": "Hurl Through Hell is unavailable."}
	var pool := "fiend_hurl_through_hell"
	var has_use := int(attacker.feature_uses.get(pool, 1)) > 0
	if not has_use:
		var slot_spent := false
		for slot_lvl in [5, 4, 3, 2, 1]:
			var key := str(slot_lvl)
			if int(attacker.spell_slots.get(key, 0)) > 0:
				attacker.spell_slots[key] -= 1
				slot_spent = true
				break
		if not slot_spent:
			return {"success": false, "damage": 0, "message": "No uses or Pact Magic spell slots remain for Hurl Through Hell."}
	else:
		attacker.feature_uses[pool] = 0

	var creature_type := ""
	if target_entity is Character:
		creature_type = target_entity.get_creature_type()
	elif target_entity is Dictionary:
		creature_type = str(target_entity.get("creature_type", ""))

	var is_fiend := creature_type == "fiend"
	var actual := 0
	if not is_fiend:
		var rolled := Dice.parse_dice_string("8d10")
		var settlement := CombatAction.resolve_damage(target_entity, rolled, "psychic")
		actual = int(settlement.get("damage", 0))

	if target_entity is Character:
		target_entity.add_condition("incapacitated", 1)
	elif target_entity is Dictionary:
		var conds: Dictionary = target_entity.get("conditions", {})
		conds["incapacitated"] = 1
		target_entity["conditions"] = conds

	var target_name: String = target_entity.character_name if target_entity is Character else str(target_entity.get("name", "Target"))
	var msg := "Hurl Through Hell deals %d psychic damage to %s and incapacitates it." % [actual, target_name] if not is_fiend else "Hurl Through Hell incapacitates %s; as a Fiend, it takes no psychic damage." % target_name
	return {
		"success": true,
		"damage": actual,
		"damage_formula": "8d10" if not is_fiend else "0",
		"damage_type": "psychic",
		"is_fiend": is_fiend,
		"message": msg
	}


static func recharge_hurl_through_hell_with_slot(c: Character) -> bool:
	if c == null or not c.has_feature("fiend_hurl_through_hell"):
		return false
	var pool := "fiend_hurl_through_hell"
	if int(c.feature_uses.get(pool, 1)) > 0:
		return false
	for slot_lvl in [5, 4, 3, 2, 1]:
		var key := str(slot_lvl)
		if int(c.spell_slots.get(key, 0)) > 0:
			c.spell_slots[key] -= 1
			c.feature_uses[pool] = 1
			return true
	return false


## Pact of the Blade damage type selection: normal (empty), necrotic, psychic, or radiant.
static func choose_pact_weapon_damage_type(c: Character, damage_type: String) -> bool:
	if c == null or not has_invocation(c, "pact_of_the_blade"):
		return false
	if damage_type not in ["", "necrotic", "psychic", "radiant"]:
		return false
	c.pact_weapon_damage_type = damage_type
	return true


## Eldritch Smite: expend Pact Magic slot on pact weapon hit for (1 + slot_level)d8 force damage and prone.
static func resolve_eldritch_smite(attacker: Character, target_entity, slot_level: int = -1) -> Dictionary:
	if attacker == null or not has_invocation(attacker, "eldritch_smite") or target_entity == null:
		return {"success": false, "damage": 0, "message": "Eldritch Smite is unavailable."}
	var spent_slot_level := 0
	if slot_level > 0 and int(attacker.spell_slots.get(str(slot_level), 0)) > 0:
		attacker.spell_slots[str(slot_level)] -= 1
		spent_slot_level = slot_level
	else:
		for lvl in [5, 4, 3, 2, 1]:
			var key := str(lvl)
			if int(attacker.spell_slots.get(key, 0)) > 0:
				attacker.spell_slots[key] -= 1
				spent_slot_level = lvl
				break
	if spent_slot_level <= 0:
		return {"success": false, "damage": 0, "message": "No Pact Magic spell slots remain for Eldritch Smite."}

	var dice_count := 1 + spent_slot_level
	var rolled_damage := Dice.parse_dice_string("%dd8" % dice_count)
	var settlement := CombatAction.resolve_damage(target_entity, rolled_damage, "force")
	var actual := int(settlement.get("damage", 0))

	var size := str(target_entity.get("size", "medium")).to_lower() if target_entity is Dictionary else "medium"
	var knocked_prone := false
	if size not in ["gargantuan", "g"]:
		knocked_prone = true
		if target_entity is Character:
			target_entity.add_condition("prone", 99)
		elif target_entity is Dictionary and "prone" not in target_entity.get("condition_immunities", []):
			var conds: Dictionary = target_entity.get("conditions", {})
			conds["prone"] = 99
			target_entity["conditions"] = conds

	var target_name: String = target_entity.character_name if target_entity is Character else str(target_entity.get("name", "Target"))
	var prone_msg := " and knocks it Prone" if knocked_prone else ""
	return {
		"success": true,
		"damage": actual,
		"damage_formula": "%dd8" % dice_count,
		"damage_type": "force",
		"slot_level": spent_slot_level,
		"knocked_prone": knocked_prone,
		"message": "Eldritch Smite deals %d force damage to %s%s using a level %d Pact slot." % [actual, target_name, prone_msg, spent_slot_level]
	}


## Lifedrinker: expends one Hit Die to heal 1d8 + CON modifier.
static func resolve_lifedrinker_heal(c: Character) -> Dictionary:
	if c == null or not has_invocation(c, "lifedrinker"):
		return {"success": false, "healed": 0, "message": "Lifedrinker is unavailable."}
	var hit_die_sides := c._parse_hit_die(DataLoader.get_character_class("warlock").get("hit_die", "d8"))
	var con_mod := c.ability_scores.get_ability_modifier("CON")
	var roll := Dice.roll(hit_die_sides, c)
	var heal_amount := maxi(1, roll + con_mod)
	var actual := c.heal(heal_amount)
	return {
		"success": true,
		"roll": roll,
		"healed": actual,
		"message": "Lifedrinker heals %s for %d HP (roll %d + CON %d)." % [c.character_name, actual, roll, con_mod]
	}


## Repelling Blast: push target 10 feet (2 hexes) away on hit with cantrip.
static func has_repelling_blast(c: Character, cantrip_id: String = "") -> bool:
	if c == null or c.class_id != "warlock" or not has_invocation(c, "repelling_blast"):
		return false
	if cantrip_id.is_empty():
		return true
	for val in c.warlock_invocations:
		var parts := str(val).split(":", false, 1)
		if parts[0] == "repelling_blast" and (parts.size() == 1 or parts[1] == cantrip_id):
			return true
	return false
