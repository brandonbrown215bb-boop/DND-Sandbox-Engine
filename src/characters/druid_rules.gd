## Bounded production rules for Druid Wild Shape.
## Form statistics stay data-driven; only the rules that change Character state live here.
class_name DruidRules
extends RefCounted

const KNOWN_FORMS_CHOICE_ID := "druid_wild_shape_forms"
const FORM_REPLACEMENT_RESOURCE_ID := "druid_wild_shape_form_replacement"
const WILD_COMPANION_FORM_KEY := "druid_wild_companion_form"
const WILD_COMPANION_FORMS := ["cat", "owl", "rat", "spider"]


static func wild_companion_forms() -> Array[Dictionary]:
	var forms: Array[Dictionary] = []
	for form_id in WILD_COMPANION_FORMS:
		var form := DataLoader.get_monster(form_id)
		if not form.is_empty():
			forms.append(form)
	return forms


static func wild_companion_state(character: Character) -> Dictionary:
	if character == null or character.class_id != "druid" or not character.has_feature("druid_wild_companion"):
		return {}
	var form_id := str(character.feature_uses.get(WILD_COMPANION_FORM_KEY, ""))
	var form := DataLoader.get_monster(form_id)
	if form_id not in WILD_COMPANION_FORMS or form.is_empty():
		return {}
	if bool(FamiliarRules.state(character).get("pocket", false)):
		return {}
	return form


static func nature_magician_options(character: Character) -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	if character == null or character.class_id != "druid" or character.level < 20 or not character.has_feature("druid_nature_magician") or character.feature_uses.get("druid_nature_magician", 0) <= 0:
		return options
	var wild_shape_uses := int(character.feature_uses.get("druid_wild_shape_uses", 0))
	var slot_table: Dictionary = DataLoader.get_character_class("druid").get("spell_slots_by_character_level", {})
	var capacities: Array = slot_table.get(str(character.level), [])
	for uses in range(1, mini(4, wild_shape_uses) + 1):
		var spell_level := uses * 2
		if spell_level > 9 or spell_level > capacities.size():
			continue
		var capacity := int(capacities[spell_level - 1])
		var available := int(character.spell_slots.get(str(spell_level), 0))
		if capacity > available:
			options.append({"uses": uses, "spell_level": spell_level})
	return options


static func use_nature_magician(character: Character, uses: int) -> Dictionary:
	var option: Dictionary = {}
	for candidate in nature_magician_options(character):
		if int(candidate.get("uses", 0)) == uses:
			option = candidate
			break
	if option.is_empty() or not character.use_feature("druid_nature_magician"):
		return {"success": false, "message": "Nature Magician is unavailable or cannot create that spell slot."}
	var wild_key := "druid_wild_shape_uses"
	character.feature_uses[wild_key] = int(character.feature_uses.get(wild_key, 0)) - uses
	var slot_key := str(option["spell_level"])
	character.spell_slots[slot_key] = int(character.spell_slots.get(slot_key, 0)) + 1
	return {"success": true, "uses": uses, "spell_level": int(option["spell_level"]), "message": "Nature Magician converts %d Wild Shape use%s into a level %d spell slot." % [uses, "" if uses == 1 else "s", int(option["spell_level"])]}


static func summon_wild_companion(character: Character, form_id: String, cost: String) -> Dictionary:
	if character == null or character.class_id != "druid" or not character.has_feature("druid_wild_companion"):
		return {"success": false, "message": "Wild Companion is unavailable."}
	if not character.is_alive or CombatAction.is_incapacitated(character):
		return {"success": false, "message": "You cannot summon a familiar right now."}
	if form_id not in WILD_COMPANION_FORMS or DataLoader.get_monster(form_id).is_empty():
		return {"success": false, "message": "Choose a supported familiar form."}
	if cost == "wild_shape":
		if int(character.feature_uses.get("druid_wild_shape_uses", 0)) <= 0 or not character.use_feature("druid_wild_shape"):
			return {"success": false, "message": "No Wild Shape uses remain."}
	elif cost == "spell_slot":
		var slot_level := 0
		for key in character.spell_slots:
			if int(character.spell_slots[key]) > 0 and (slot_level == 0 or int(key) < slot_level):
				slot_level = int(key)
		if slot_level <= 0:
			return {"success": false, "message": "No spell slots remain."}
		character.spell_slots[str(slot_level)] = int(character.spell_slots[str(slot_level)]) - 1
	else:
		return {"success": false, "message": "Choose a spell slot or Wild Shape use."}
	FamiliarRules.create(character, form_id)
	return {"success": true, "form": DataLoader.get_monster(form_id), "message": "Wild Companion summons a Fey %s." % str(DataLoader.get_monster(form_id).get("name", form_id))}


static func form_options(character: Character) -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	if character == null:
		return options
	for form_id in known_form_ids(character):
		var form := form_data(form_id)
		if not form.is_empty() and is_eligible_form(character, form):
			options.append(form)
	return options


static func eligible_form_options(character: Character) -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	if character == null or character.class_id != "druid" or character.level < 2:
		return options
	var max_cr := 0.25 if character.level < 4 else (0.5 if character.level < 8 else 1.0)
	var class_data := DataLoader.get_character_class("druid")
	for form in class_data.get("wild_shape_forms", []):
		if not form is Dictionary or not is_eligible_form(character, form):
			continue
		options.append(form)
	return options


static func is_eligible_form(character: Character, form: Dictionary) -> bool:
	if character == null or character.class_id != "druid" or character.level < 2:
		return false
	var max_cr := 0.25 if character.level < 4 else (0.5 if character.level < 8 else 1.0)
	return float(form.get("challenge_rating", 99.0)) <= max_cr and (character.level >= 8 or int(form.get("fly_speed", 0)) <= 0)


static func known_form_capacity(character: Character) -> int:
	if character == null or character.class_id != "druid" or character.level < 2:
		return 0
	return 4 if character.level < 4 else (6 if character.level < 8 else 8)


static func known_form_ids(character: Character) -> Array[String]:
	var ids: Array[String] = []
	if character == null:
		return ids
	var saved: Variant = character.feature_choices.get(KNOWN_FORMS_CHOICE_ID, [])
	if not saved is Array:
		return ids
	for value in saved:
		if ids.size() >= known_form_capacity(character):
			break
		var id := str(value)
		var form := form_data(id)
		if not id.is_empty() and id not in ids and not form.is_empty() and is_eligible_form(character, form):
			ids.append(id)
	return ids


static func pending_known_form_count(character: Character) -> int:
	return maxi(0, known_form_capacity(character) - known_form_ids(character).size())


static func learn_form(character: Character, form_id: String) -> bool:
	if character == null or character.class_id != "druid" or pending_known_form_count(character) <= 0:
		return false
	if form_id in known_form_ids(character):
		return false
	var form := form_data(form_id)
	if form.is_empty() or not is_eligible_form(character, form):
		return false
	var choices := known_form_ids(character)
	choices.append(form_id)
	character.feature_choices[KNOWN_FORMS_CHOICE_ID] = choices
	return true


static func replace_known_form(character: Character, old_form_id: String, new_form_id: String) -> bool:
	if character == null or character.class_id != "druid" or known_form_ids(character).is_empty():
		return false
	if int(character.feature_uses.get(FORM_REPLACEMENT_RESOURCE_ID, 0)) < 1:
		return false
	var choices := known_form_ids(character)
	var index := choices.find(old_form_id)
	var replacement := form_data(new_form_id)
	if index < 0 or old_form_id == new_form_id or replacement.is_empty() or not is_eligible_form(character, replacement):
		return false
	if new_form_id in choices:
		return false
	choices[index] = new_form_id
	character.feature_choices[KNOWN_FORMS_CHOICE_ID] = choices
	character.feature_uses[FORM_REPLACEMENT_RESOURCE_ID] = int(character.feature_uses[FORM_REPLACEMENT_RESOURCE_ID]) - 1
	return true


static func wild_resurgence_state(character: Character) -> Dictionary:
	if character == null or character.class_id != "druid" or not character.has_feature("druid_wild_resurgence"):
		return {}
	if int(character.feature_uses.get("druid_wild_resurgence", 0)) <= 0:
		return {}
	var wild_uses := int(character.feature_uses.get("druid_wild_shape_uses", 0))
	if wild_uses <= 0:
		var available_slots: Array[int] = []
		for key in character.spell_slots:
			if int(character.spell_slots[key]) > 0:
				available_slots.append(int(key))
		available_slots.sort()
		return {"mode": "slot_to_wild_shape", "spell_slots": available_slots} if not available_slots.is_empty() else {}
	var slot_capacity := _spell_slot_capacity(character, 1)
	if bool(character.feature_uses.get("druid_wild_resurgence_long_rest_used", false)) or int(character.spell_slots.get("1", 0)) >= slot_capacity:
		return {}
	return {"mode": "wild_shape_to_slot", "spell_level": 1}


static func use_wild_resurgence(character: Character, slot_level: int = 0) -> Dictionary:
	var state := wild_resurgence_state(character)
	if state.is_empty():
		return {"success": false, "message": "Wild Resurgence is not available right now."}
	var mode := str(state.get("mode", ""))
	if mode == "slot_to_wild_shape":
		var allowed_slots: Array = state.get("spell_slots", [])
		if slot_level not in allowed_slots:
			return {"success": false, "message": "Choose an available spell slot."}
		var restored := ClassProgression.restore_resource_from_spell_slot(character, "druid_wild_shape_uses", slot_level)
		if not restored.get("success", false):
			return restored
		if not character.use_feature("druid_wild_resurgence"):
			# All validation and spending occur synchronously, so reaching this
			# branch means the owned feature record changed unexpectedly.
			return {"success": false, "message": "Wild Resurgence could not be committed."}
		return {"success": true, "mode": mode, "slot_level": slot_level, "message": "Wild Resurgence restores one Wild Shape use by spending a level %d spell slot." % slot_level}
	if mode == "wild_shape_to_slot":
		if not character.use_feature("druid_wild_shape"):
			return {"success": false, "message": "No Wild Shape uses remain."}
		if not character.use_feature("druid_wild_resurgence"):
			character.feature_uses["druid_wild_shape_uses"] += 1
			return {"success": false, "message": "Wild Resurgence could not be committed."}
		character.spell_slots["1"] = int(character.spell_slots.get("1", 0)) + 1
		character.feature_uses["druid_wild_resurgence_long_rest_used"] = true
		return {"success": true, "mode": mode, "slot_level": 1, "message": "Wild Resurgence restores a level 1 spell slot by spending one Wild Shape use."}
	return {"success": false, "message": "Wild Resurgence option is invalid."}


static func _spell_slot_capacity(character: Character, spell_level: int) -> int:
	if character == null or spell_level < 1:
		return 0
	var table: Dictionary = DataLoader.get_character_class(character.class_id).get("spell_slots_by_character_level", {})
	var counts: Array = table.get(str(character.level), [])
	return int(counts[spell_level - 1]) if counts.size() >= spell_level else 0


static func form_data(form_id: String) -> Dictionary:
	for form in DataLoader.get_character_class("druid").get("wild_shape_forms", []):
		if form is Dictionary and str(form.get("id", "")) == form_id:
			return form.duplicate(true)
	return {}


static func validate_form(character: Character, form_id: String) -> Dictionary:
	if character == null or character.class_id != "druid" or not character.has_feature("druid_wild_shape"):
		return {"success": false, "message": "Only a Druid with Wild Shape can transform."}
	for form in form_options(character):
		if str(form.get("id", "")) == form_id:
			return {"success": true, "form": form}
	return {"success": false, "message": "That Beast form is not one of your eligible learned forms."}


static func transform(character: Character, form_id: String) -> Dictionary:
	var validation := validate_form(character, form_id)
	if not validation.get("success", false):
		return validation
	if character.has_condition("moonbeam_shape_lock"):
		return {"success": false, "message": "You can't shape-shift until you leave the Moonbeam Cylinder."}
	var form: Dictionary = validation["form"]
	if int(character.feature_uses.get("druid_wild_shape_uses", 0)) < 1:
		return {"success": false, "message": "No Wild Shape uses remain."}
	if not character.use_feature("druid_wild_shape"):
		return {"success": false, "message": "No Wild Shape uses remain."}
	if is_shaped(character):
		revert(character)
	character.wild_shape_state = {
		"form_id": form_id,
		"original_ability_scores": character.ability_scores.to_dict(),
		"original_speed": character.speed,
		"equipment_mode": "merged"
	}
	var replacement := AbilityScores.new()
	replacement.from_dict(form.get("ability_scores", {}))
	for ability in ["INT", "WIS", "CHA"]:
		replacement.set_score(ability, character.ability_scores.get_score(ability))
	character.ability_scores = replacement
	character.speed = maxi(1, int(floor(float(form.get("speed_feet", 5)) / 5.0)))
	character.temp_hp = maxi(character.temp_hp, character.level)
	return {"success": true, "form": form, "temporary_hp": character.temp_hp}


static func revert(character: Character) -> bool:
	if not is_shaped(character):
		return false
	var state := character.wild_shape_state
	var original_scores: Variant = state.get("original_ability_scores", {})
	if original_scores is Dictionary and not original_scores.is_empty():
		var restored_scores := AbilityScores.new()
		restored_scores.from_dict(original_scores)
		character.ability_scores = restored_scores
	character.speed = maxi(0, int(state.get("original_speed", character.speed)))
	character.wild_shape_state.clear()
	return true


static func restore_saved_form(character: Character, saved_state: Variant) -> void:
	character.wild_shape_state.clear()
	if not saved_state is Dictionary or saved_state.is_empty():
		return
	var form_id := str(saved_state.get("form_id", ""))
	var form := form_data(form_id)
	var original_scores: Variant = saved_state.get("original_ability_scores", {})
	var original_speed: Variant = saved_state.get("original_speed", null)
	if character.class_id != "druid" or form.is_empty() or not original_scores is Dictionary or original_scores.size() != 6 or not (original_speed is int or original_speed is float):
		if original_scores is Dictionary and original_scores.size() == 6:
			var restored_scores := AbilityScores.new()
			restored_scores.from_dict(original_scores)
			character.ability_scores = restored_scores
		if original_speed is int or original_speed is float:
			character.speed = maxi(0, int(original_speed))
		return
	character.wild_shape_state = saved_state.duplicate(true)


static func is_shaped(character: Character) -> bool:
	return character != null and not character.wild_shape_state.is_empty()


static func current_form(character: Character) -> Dictionary:
	return form_data(str(character.wild_shape_state.get("form_id", ""))) if is_shaped(character) else {}


static func current_attack_profile(character: Character) -> Dictionary:
	var form := current_form(character)
	var attacks: Array = form.get("attacks", [])
	if attacks.is_empty() or not attacks[0] is Dictionary:
		return {}
	var attack: Dictionary = attacks[0]
	return {
		"id": "wild_shape_%s_%s" % [str(form.get("id", "beast")), str(attack.get("name", "attack")).to_snake_case()],
		"name": str(attack.get("name", "Beast Attack")),
		"type": "weapon",
		"weapon_type": "simple",
		"ability": str(attack.get("ability", "STR")),
		"attack_bonus_override": int(attack.get("attack_bonus", 0)),
		"damage": str(attack.get("damage", "1d4")),
		"damage_type": str(attack.get("damage_type", "bludgeoning")),
		"range": maxi(1, int(ceil(float(attack.get("range_feet", 5)) / 5.0))),
		"fixed_damage": bool(attack.get("fixed_damage", false)),
		"properties": [],
		"wild_shape_attack": attack.duplicate(true)
	}


static func pack_tactics_advantage(character: Character, target: Dictionary, allies: Array) -> bool:
	if "pack_tactics" not in current_form(character).get("traits", []):
		return false
	var target_hex: Vector2i = target.get("hex_position", Vector2i.ZERO)
	for ally in allies:
		var ally_character: Character = ally.get("character")
		if ally_character == null or ally_character == character or not ally_character.is_alive:
			continue
		if HexUtils.get_distance(target_hex, ally.get("hex_position", Vector2i.ZERO)) <= 1:
			return true
	return false


static func apply_attack_effects(character: Character, target: Dictionary, weapon: Dictionary, result: Dictionary) -> void:
	if not bool(result.get("hit", false)) or not weapon.has("wild_shape_attack") or not target.get("is_alive", false):
		return
	var attack: Dictionary = weapon.get("wild_shape_attack", {})
	var bonus_formula := str(attack.get("bonus_damage", ""))
	if not bonus_formula.is_empty():
		var bonus_type := str(attack.get("bonus_damage_type", "poison"))
		var rolled := Dice.parse_dice_string(bonus_formula, {}, character)
		var actual := int(CombatAction.resolve_damage(target, rolled, bonus_type)["damage"])
		result["damage"] = int(result.get("damage", 0)) + actual
		result.get_or_add("damage_components", []).append({"label": "%s (%s)" % [str(attack.get("name", "Beast attack")), bonus_type.capitalize()], "value": actual, "type": bonus_type, "formula": bonus_formula})
		result["message"] = str(result.get("message", "")) + " %s adds %d %s damage." % [str(attack.get("name", "Beast attack")), actual, bonus_type]
	if not target.get("is_alive", false):
		return
	var knock_prone_size := str(attack.get("knock_prone_size", ""))
	if not knock_prone_size.is_empty() and _size_rank(str(target.get("size", "medium"))) <= _size_rank(knock_prone_size):
		var conditions: Dictionary = target.get("conditions", {})
		conditions["prone"] = 1
		target["conditions"] = conditions
		result["message"] = str(result.get("message", "")) + " The target is knocked Prone."


static func _size_rank(size: String) -> int:
	return {"tiny": 0, "small": 1, "medium": 2, "large": 3, "huge": 4, "gargantuan": 5}.get(size.to_lower(), 2)


static func armor_class(character: Character) -> int:
	var form := current_form(character)
	if form.is_empty():
		return -1
	var ac := int(form.get("armor_class", 10)) + character.get_modifier("stat", "AC")
	if character.has_condition("shield"):
		ac += 5
	return ac


static func can_cast_spells(character: Character) -> bool:
	return not is_shaped(character) or character.class_id == "druid" and character.level >= 18 and character.has_feature("druid_beast_spells")


static func can_cast_spell(character: Character, spell_data: Dictionary) -> bool:
	if not can_cast_spells(character):
		return false
	if not is_shaped(character):
		return true
	return int(spell_data.get("material_component_cost", 0)) <= 0 and not bool(spell_data.get("material_component_consumed", false))


static func ignores_free_material_components(character: Character, spell_data: Dictionary) -> bool:
	return is_shaped(character) and character.class_id == "druid" and character.level >= 18 and character.has_feature("druid_beast_spells") and can_cast_spell(character, spell_data)


static func revert_for_incapacitation(character: Character) -> void:
	if is_shaped(character) and (character.has_condition("incapacitated") or character.has_condition("unconscious") or not character.is_alive):
		revert(character)
