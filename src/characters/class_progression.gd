## Class/subclass selection and saved ability-improvement entitlements.
## Acquisition applies permanent changes; reconstruction only restores membership.
class_name ClassProgression
extends RefCounted

## Creation choices use class data; older saves without them retain their state.
static func default_creation_choices(class_id: String, race_id: String) -> Dictionary:
	var data := DataLoader.get_character_class(class_id)
	var skills: Array = data.get("skill_choices", {}).get("from", []).duplicate()
	var racial: Array = DataLoader.get_race(race_id).get("proficiencies", [])
	skills = skills.filter(func(skill): return skill not in racial)
	return {"skills": skills.slice(0, int(data.get("skill_choices", {}).get("pick", 0))), "tools": data.get("tool_choices", {}).get("from", []).slice(0, int(data.get("tool_choices", {}).get("pick", 0))), "instrument": "lute", "equipment": "equipment"}


static func creation_choices_error(class_id: String, race_id: String, choices: Dictionary) -> String:
	var data := DataLoader.get_character_class(class_id)
	for pair in [["skills", "skill_choices"], ["tools", "tool_choices"]]:
		var values: Variant = choices.get(pair[0], [])
		var contract: Dictionary = data.get(pair[1], {})
		if not values is Array or values.size() != int(contract.get("pick", 0)):
			return "Choose exactly %d %s." % [int(contract.get("pick", 0)), pair[0]]
		var seen := []
		for value in values:
			if not value is String or value not in contract.get("from", []) or value in seen:
				return "Choose distinct valid %s." % pair[0]
			if pair[0] == "skills" and value in DataLoader.get_race(race_id).get("proficiencies", []):
				return "Choose a skill your species does not already provide."
			seen.append(value)
	if choices.get("equipment", "") not in ["equipment", "gold"]:
		return "Choose equipment or starting gold."
	if class_id == "bard" and choices.get("equipment", "") == "equipment" and choices.get("instrument", "") not in data.get("tool_choices", {}).get("from", []):
		return "Choose a starting Musical Instrument."
	return ""


static func saved_creation_error(dto: Dictionary) -> String:
	var tools: Variant = dto.get("tool_proficiencies", [])
	if not tools is Array:
		return "Tool proficiencies are not an array"
	var seen := []
	for tool in tools:
		if not tool is String or tool.is_empty() or tool in seen or DataLoader.get_item(tool).get("type", "") != "tool":
			return "Tool proficiency is invalid"
		seen.append(tool)
	if not dto.has("creation_choices"):
		return ""
	var choices: Variant = dto["creation_choices"]
	if not choices is Dictionary:
		return "Creation choices are not an object"
	if choices.is_empty():
		return ""
	var error := creation_choices_error(str(dto.get("class_id", "")), str(dto.get("race_id", "")), choices)
	if not error.is_empty():
		return error
	if not dto.get("skill_proficiencies", []) is Array:
		return "Skill proficiencies are not an array"
	for skill in choices.get("skills", []):
		if skill not in dto.get("skill_proficiencies", []):
			return "Saved creation skill proficiency is missing"
	for tool in choices.get("tools", []):
		if tool not in tools:
			return "Saved creation tool proficiency is missing"
	return ""

static func improvement_ids(c: Character) -> Array[String]:
	var ids: Array[String] = []
	for feature in c.features:
		for effect in feature.get("effects", []):
			if effect.get("type", "") == "asi":
				ids.append(str(feature["id"]))
	return ids

static func pending_improvements(c: Character) -> Array[String]:
	var pending: Array[String] = []
	for id in improvement_ids(c):
		if not c.feature_choices.has(id):
			pending.append(id)
	return pending

static func skill_choice_ids(c: Character) -> Array[String]:
	var ids: Array[String] = []
	for feature in c.features:
		for effect in feature.get("effects", []):
			if effect.get("type", "") == "skill_proficiency_choice":
				ids.append(str(feature["id"]))
	return ids

static func pending_skill_choices(c: Character) -> Array[String]:
	var pending: Array[String] = []
	for id in skill_choice_ids(c):
		if not c.feature_choices.has(id):
			pending.append(id)
	return pending

static func skill_expertise_choice_ids(c: Character) -> Array[String]:
	var ids: Array[String] = []
	for feature in c.features:
		for effect in feature.get("effects", []):
			if effect.get("type", "") == "skill_expertise_choice":
				ids.append(str(feature["id"]))
	return ids

static func pending_skill_expertise_choices(c: Character) -> Array[String]:
	var pending: Array[String] = []
	for id in skill_expertise_choice_ids(c):
		if not c.feature_choices.has(id):
			pending.append(id)
	return pending


static func feature_choice_ids(c: Character) -> Array[String]:
	var ids: Array[String] = []
	for feature in c.features:
		for effect in feature.get("effects", []):
			if effect.get("type", "") == "feature_choice":
				ids.append(str(feature["id"]))
	return ids


static func pending_feature_choices(c: Character) -> Array[String]:
	var pending: Array[String] = []
	for id in feature_choice_ids(c):
		if not c.feature_choices.has(id):
			pending.append(id)
	return pending


static func feature_choice_effect(c: Character, feature_id: String) -> Dictionary:
	var feature := c.get_feature(feature_id)
	for effect in feature.get("effects", []):
		if effect.get("type", "") == "feature_choice":
			return effect
	return {}


static func selected_feature_effects(c: Character) -> Array[Dictionary]:
	var selected_effects: Array[Dictionary] = []
	for feature_id in feature_choice_ids(c):
		var choice: Variant = c.feature_choices.get(feature_id, [])
		if not choice is Array or choice.is_empty():
			continue
		var effect := feature_choice_effect(c, feature_id)
		for chosen_id in choice:
			for option in effect.get("options", []):
				if str(option.get("id", "")) == str(chosen_id):
					for option_effect in option.get("effects", []):
						selected_effects.append(option_effect)
	selected_effects.append_array(WarlockRules.selected_invocation_effects(c))
	return selected_effects


static func selected_feature_effects_of_type(c: Character, effect_type: String) -> Array[Dictionary]:
	var matches: Array[Dictionary] = []
	if c == null:
		return matches
	for feature in c.features:
		for effect in feature.get("effects", []) + feature.get("passive_effects", []):
			if str(effect.get("type", "")) == effect_type:
				var source_ids: Array[String] = []
				var source_id := str(feature.get("source_instance_id", ""))
				if not source_id.is_empty():
					source_ids.append(source_id)
				elif effect.has("use_limit") and feature.has("resource_pool") and feature["resource_pool"] is Dictionary and feature["resource_pool"].has("id"):
					source_ids = ResourcePoolRules.source_instance_ids(c, str(feature["resource_pool"]["id"]))
				else:
					source_ids.append(str(feature.get("id", "")))
				for exact_source_id in source_ids:
					var declared_effect: Dictionary = effect.duplicate(true)
					declared_effect["feature_id"] = str(feature.get("id", ""))
					declared_effect["feature_name"] = str(feature.get("name", feature.get("id", "")))
					declared_effect["source_instance_id"] = exact_source_id
					if feature.has("resource_pool") and feature["resource_pool"] is Dictionary and feature["resource_pool"].has("id"):
						declared_effect["resource_pool_definition_id"] = str(feature["resource_pool"]["id"])
					matches.append(declared_effect)
	for effect in selected_feature_effects(c):
		if str(effect.get("type", "")) == effect_type:
			matches.append(effect)
	return matches



static func _choice_class_matches(primary_class: String, allocation: Dictionary, required_class: String) -> bool:
	return int(allocation.get(required_class, 0)) > 0 if not allocation.is_empty() else primary_class == required_class


static func available_feature_options(c: Character, feature_id: String, candidate_choices: Array = []) -> Array[Dictionary]:
	var available: Array[Dictionary] = []
	if c == null:
		return available
	var effect := feature_choice_effect(c, feature_id)
	if effect.is_empty():
		return available
	var current_choices: Array = c.feature_choices.get(feature_id, [])
	var allow_duplicates := bool(effect.get("allow_duplicates", false))
	for option in effect.get("options", []):
		var opt_id := str(option.get("id", ""))
		if opt_id.is_empty():
			continue
		if not allow_duplicates and not bool(option.get("repeatable", false)):
			if opt_id in current_choices or opt_id in candidate_choices:
				continue
		if option.has("minimum_level") and c.level < int(option["minimum_level"]):
			continue
		if option.has("class_id") and not _choice_class_matches(c.class_id, c.class_levels, str(option["class_id"])):
			continue
		if option.has("when") and not SharedStepExecutor.evaluate_actor_predicate(option["when"], c):
			continue
		var reqs_met := true
		for req_choice in option.get("requires_choices", []):
			var req_found := false
			if req_choice in candidate_choices:
				req_found = true
			else:
				for existing_f_id in c.feature_choices:
					if req_choice in c.feature_choices[existing_f_id]:
						req_found = true
						break
			if not req_found:
				reqs_met = false
				break
		if not reqs_met:
			continue
		available.append(option)
	return available


static func choose_feature_options(c: Character, feature_id: String, option_ids: Array[String]) -> bool:
	if c == null or feature_id not in pending_feature_choices(c):
		return false
	var effect := feature_choice_effect(c, feature_id)
	if effect.is_empty():
		return false
	var expected_count := int(effect.get("count", effect.get("pick", 1)))
	if option_ids.size() != expected_count:
		return false
	var allow_duplicates := bool(effect.get("allow_duplicates", false))
	var seen: Dictionary = {}
	var options_by_id: Dictionary = {}
	for opt in effect.get("options", []):
		options_by_id[str(opt.get("id", ""))] = opt

	for opt_id in option_ids:
		if not options_by_id.has(opt_id):
			return false
		var opt: Dictionary = options_by_id[opt_id]
		if not allow_duplicates and not bool(opt.get("repeatable", false)) and seen.has(opt_id):
			return false
		seen[opt_id] = true
		if opt.has("minimum_level") and c.level < int(opt["minimum_level"]):
			return false
		if opt.has("class_id") and not _choice_class_matches(c.class_id, c.class_levels, str(opt["class_id"])):
			return false
		if opt.has("when") and not SharedStepExecutor.evaluate_actor_predicate(opt["when"], c):
			return false
		for req in opt.get("requires_choices", []):
			var req_met := false
			if req in option_ids:
				req_met = true
			else:
				for existing_f_id in c.feature_choices:
					if req in c.feature_choices[existing_f_id]:
						req_met = true
						break
			if not req_met:
				return false

	c.feature_choices[feature_id] = option_ids.duplicate()
	_apply_feature_choice_grants(c)
	return true


static func choose_feature_option(c: Character, feature_id: String, option_id: String) -> bool:
	return choose_feature_options(c, feature_id, [option_id])


static func can_replace_feature_option(c: Character, feature_id: String, old_option_id: String, new_option_id: String) -> Dictionary:
	if c == null or not c.feature_choices.has(feature_id):
		return {"allowed": false, "reason": "Character does not have this feature choice"}
	var current_choices: Array = c.feature_choices[feature_id]
	if old_option_id not in current_choices:
		return {"allowed": false, "reason": "Old option is not currently selected"}
	if old_option_id == new_option_id:
		return {"allowed": false, "reason": "New option must be different from old option"}
	var effect := feature_choice_effect(c, feature_id)
	if effect.is_empty():
		return {"allowed": false, "reason": "Feature choice definition not found"}
	if not bool(effect.get("allow_replacement", false)):
		return {"allowed": false, "reason": "Replacement is not permitted for this feature"}

	var options_by_id: Dictionary = {}
	for opt in effect.get("options", []):
		options_by_id[str(opt.get("id", ""))] = opt
	if not options_by_id.has(new_option_id):
		return {"allowed": false, "reason": "New option is not in available options"}

	var new_opt: Dictionary = options_by_id[new_option_id]
	var allow_duplicates := bool(effect.get("allow_duplicates", false))
	if not allow_duplicates and not bool(new_opt.get("repeatable", false)) and new_option_id in current_choices:
		return {"allowed": false, "reason": "New option is already selected"}

	if new_opt.has("minimum_level") and c.level < int(new_opt["minimum_level"]):
		return {"allowed": false, "reason": "Level prerequisite not met for new option"}
	if new_opt.has("class_id") and not _choice_class_matches(c.class_id, c.class_levels, str(new_opt["class_id"])):
		return {"allowed": false, "reason": "Class prerequisite not met for new option"}
	if new_opt.has("when") and not SharedStepExecutor.evaluate_actor_predicate(new_opt["when"], c):
		return {"allowed": false, "reason": "Predicate requirement not met for new option"}
	var proposed := c.feature_choices.duplicate(true)
	proposed[feature_id][current_choices.find(old_option_id)] = new_option_id
	# Validate the resulting selections, including another occurrence of a repeated prerequisite.
	for f_id in proposed:
		var f_effect := feature_choice_effect(c, f_id)
		var f_options: Dictionary = {}
		for opt in f_effect.get("options", []):
			f_options[str(opt.get("id", ""))] = opt
		for ch in proposed[f_id]:
			var active_opt: Dictionary = f_options.get(str(ch), {})
			for req in active_opt.get("requires_choices", []):
				if not proposed.values().any(func(selected): return req in selected):
					return {"allowed": false, "reason": "Active choice '%s' requires '%s'" % [ch, req]}
	# Spell capacity/list grants can support existing training without an explicit requires_choices field.
	var class_data := DataLoader.get_character_class(c.class_id)
	var subclass := DataLoader.get_subclass(c.subclass_id)
	for feature in c.features:
		for spell_effect in c._feature_effects(feature):
			if spell_effect.get("type", "") != "spellcasting" or not proposed.has(str(feature.get("id", ""))):
				continue
			var spell_error := _saved_spell_choice_error(proposed[str(feature.id)], spell_effect, class_data, subclass, c.level, proposed, true, c.wizard_spellbook, c.get_class_level())
			if not spell_error.is_empty():
				return {"allowed": false, "reason": "Replacement would invalidate trained spells: " + spell_error}

	return {"allowed": true, "reason": ""}


static func _revoke_feature_option_grants(c: Character, feature_id: String, old_option_id: String) -> void:
	if c == null:
		return
	var f_effect := feature_choice_effect(c, feature_id)
	var old_effects: Array = []
	for opt in f_effect.get("options", []):
		if opt is Dictionary and str(opt.get("id", "")) == old_option_id:
			old_effects = opt.get("effects", [])
			break
	if old_effects.is_empty():
		return

	var class_data := DataLoader.get_character_class(c.class_id)
	var race_data := DataLoader.get_race(c.race_id)

	for effect in old_effects:
		if not effect is Dictionary or effect.get("type", "") != "proficiency_grant":
			continue

		for w in effect.get("weapon_proficiencies", []):
			var w_str := str(w)
			var keep := PermanentProgressionRules.retains(c, "weapon_proficiencies", w_str)
			if w_str in class_data.get("weapon_proficiencies", []):
				keep = true
			if not keep:
				for trait_val in race_data.get("traits", []):
					if trait_val is Dictionary:
						for r_eff in trait_val.get("effects", []):
							if r_eff is Dictionary and r_eff.get("type", "") == "weapon_proficiency" and w_str in r_eff.get("weapons", []):
								keep = true
								break
					if keep:
						break
			if not keep:
				for feature in c.features:
					for f_eff in c._feature_effects(feature):
						if f_eff.get("type", "") == "proficiency_grant" and w_str in f_eff.get("weapon_proficiencies", []):
							keep = true
							break
					if keep:
						break
			if not keep:
				for act_eff in selected_feature_effects(c):
					if act_eff.get("type", "") == "proficiency_grant" and w_str in act_eff.get("weapon_proficiencies", []):
						keep = true
						break
			if not keep:
				c.weapon_proficiencies.erase(w_str)

		for a in effect.get("armor_proficiencies", []):
			var a_str := str(a)
			var keep := PermanentProgressionRules.retains(c, "armor_proficiencies", a_str)
			if a_str in class_data.get("armor_proficiencies", []):
				keep = true
			if not keep:
				for trait_val in race_data.get("traits", []):
					if trait_val is Dictionary:
						for r_eff in trait_val.get("effects", []):
							if r_eff is Dictionary and r_eff.get("type", "") == "armor_proficiency" and a_str in r_eff.get("armor", []):
								keep = true
								break
					if keep:
						break
			if not keep:
				for feature in c.features:
					for f_eff in c._feature_effects(feature):
						if f_eff.get("type", "") == "proficiency_grant" and a_str in f_eff.get("armor_proficiencies", []):
							keep = true
							break
					if keep:
						break
			if not keep:
				for act_eff in selected_feature_effects(c):
					if act_eff.get("type", "") == "proficiency_grant" and a_str in act_eff.get("armor_proficiencies", []):
						keep = true
						break
			if not keep:
				c.armor_proficiencies.erase(a_str)

		for s in effect.get("skill_proficiencies", []):
			var s_str := str(s)
			var keep := PermanentProgressionRules.retains(c, "skill_proficiencies", s_str)
			if s_str in race_data.get("proficiencies", []):
				keep = true
			if not keep and s_str in c.creation_choices.get("skills", []):
				keep = true
			if not keep and c.class_id == "fighter" and s_str in c.fighter_training.get("skills", []):
				keep = true
			if not keep:
				for feature_id_check in skill_choice_ids(c):
					if s_str in c.feature_choices.get(feature_id_check, []):
						keep = true
						break
			if not keep:
				for feature in c.features:
					for f_eff in c._feature_effects(feature):
						if f_eff.get("type", "") == "proficiency_grant" and s_str in f_eff.get("skill_proficiencies", []):
							keep = true
							break
					if keep:
						break
			if not keep:
				for act_eff in selected_feature_effects(c):
					if act_eff.get("type", "") == "proficiency_grant" and s_str in act_eff.get("skill_proficiencies", []):
						keep = true
						break
			if not keep:
				c.skill_proficiencies.erase(s_str)


static func replace_feature_option(c: Character, feature_id: String, old_option_id: String, new_option_id: String) -> bool:
	var check := can_replace_feature_option(c, feature_id, old_option_id, new_option_id)
	if not bool(check.get("allowed", false)):
		return false
	var list: Array = c.feature_choices[feature_id].duplicate()
	var idx := list.find(old_option_id)
	if idx < 0:
		return false
	list[idx] = new_option_id
	c.feature_choices[feature_id] = list
	_revoke_feature_option_grants(c, feature_id, old_option_id)
	_apply_feature_choice_grants(c)
	return true


static func _apply_feature_choice_grants(c: Character) -> void:
	if c == null:
		return
	for effect in selected_feature_effects(c):
		if effect.get("type", "") != "proficiency_grant":
			continue
		for proficiency in effect.get("weapon_proficiencies", []):
			if str(proficiency) not in c.weapon_proficiencies:
				c.weapon_proficiencies.append(str(proficiency))
		for proficiency in effect.get("armor_proficiencies", []):
			if str(proficiency) not in c.armor_proficiencies:
				c.armor_proficiencies.append(str(proficiency))
		for proficiency in effect.get("skill_proficiencies", []):
			if str(proficiency) not in c.skill_proficiencies:
				c.skill_proficiencies.append(str(proficiency))

	var base_extra := 0
	for feature in c.features:
		for effect in c._feature_effects(feature):
			if effect.get("type", "") == "extra_attack":
				base_extra += int(effect.get("count", 1))
	var choice_extra := 0
	for effect in selected_feature_effects(c):
		if effect.get("type", "") == "extra_attack":
			choice_extra = maxi(choice_extra, int(effect.get("count", 1)))
	c.extra_attacks = maxi(base_extra, choice_extra)
	var spellcasting_id := c.get_spellcasting_feature_id()
	if not spellcasting_id.is_empty() and c.feature_choices.has(spellcasting_id):
		var cantrips := 0
		var prepared := 0
		for spell_id in c.feature_choices[spellcasting_id]:
			if int(DataLoader.get_spell(str(spell_id)).get("level", 0)) == 0: cantrips += 1
			else: prepared += 1
		if cantrips < c.get_spellcasting_capacity("cantrips") or prepared < c.get_spellcasting_capacity("prepared_spells"):
			c.spell_choices_pending = true


static func apply_feature_choice_grants(c: Character) -> void:
	_apply_feature_choice_grants(c)


static func choose_spell_selection(c: Character, spell_ids: Array[String]) -> bool:
	if c == null or not c.spell_choices_pending:
		return false
	var feature_id := c.get_spellcasting_feature_id()
	if feature_id.is_empty():
		return false
	var cantrip_capacity := c.get_spellcasting_capacity("cantrips")
	var prepared_capacity := c.get_spellcasting_capacity("prepared_spells")
	var allowed_cantrips := c.get_spell_option_ids(true)
	var allowed_spells := c.get_spell_option_ids(false)
	var chosen_cantrips: Array[String] = []
	var chosen_spells: Array[String] = []
	var seen: Array[String] = []
	for spell_id in spell_ids:
		if spell_id in seen:
			return false
		seen.append(spell_id)
		if spell_id in allowed_cantrips:
			chosen_cantrips.append(spell_id)
		elif spell_id in allowed_spells:
			chosen_spells.append(spell_id)
		else:
			return false
	# Missing catalog entries must not make available choices impossible to save.
	if chosen_cantrips.size() != mini(cantrip_capacity, allowed_cantrips.size()) or chosen_spells.size() != mini(prepared_capacity, allowed_spells.size()):
		return false
	var previous: Variant = c.feature_choices.get(feature_id, [])
	if previous is Array and not previous.is_empty() and (c.level > 1 or c.class_id == "cleric"):
		var old_cantrips := 0
		var old_spells := 0
		for spell_id in previous:
			var spell: Dictionary = DataLoader.get_spell(str(spell_id))
			if int(spell.get("level", 0)) == 0:
				old_cantrips += 1
			else:
				old_spells += 1
		var removed_cantrips := 0
		var removed_spells := 0
		for spell_id in previous:
			if spell_id in seen:
				continue
			if int(DataLoader.get_spell(str(spell_id)).get("level", 0)) == 0:
				removed_cantrips += 1
			else:
				removed_spells += 1
		if c.class_id == "cleric":
			if c.cleric_spells_trained and (removed_cantrips > (1 if c.cleric_cantrip_replacement_available else 0) or (removed_spells > 0 and not c.cleric_preparation_free_change)):
				return false
		elif c.class_id == "wizard" and c.wizard_memorize_spell_pending:
			if removed_cantrips != 0 or removed_spells != 1:
				return false
		elif not (c.class_id == "wizard" and c.wizard_preparation_free_change) and (removed_cantrips > 1 or removed_spells > 1):
			return false
		if chosen_cantrips.size() < mini(old_cantrips, cantrip_capacity) or chosen_spells.size() < mini(old_spells, prepared_capacity):
			return false
	c.feature_choices[feature_id] = seen.duplicate()
	c.refresh_spell_selection_from_choices()
	c.spell_choices_pending = chosen_cantrips.size() < cantrip_capacity or chosen_spells.size() < prepared_capacity
	if c.class_id == "cleric":
		c.cleric_spells_trained = true
	c.cleric_preparation_free_change = false
	c.cleric_cantrip_replacement_available = false
	c.wizard_preparation_free_change = false
	c.wizard_memorize_spell_pending = false
	return true


static func choose_wizard_spellbook(c: Character, spell_ids: Array[String]) -> bool:
	if c == null or c.class_id != "wizard" or c.wizard_spellbook_pending <= 0 or spell_ids.is_empty() or spell_ids.size() > c.wizard_spellbook_pending:
		return false
	var allowed: Array[String] = []
	for spell in DataLoader.get_castable_spell_list_options(c.get_spell_list_ids()):
		var spell_id := str(spell.get("id", ""))
		var spell_level := int(spell.get("level", -1))
		if spell_level > 0 and spell_level <= c.get_max_spell_slot_level() and spell_id not in c.wizard_spellbook:
			allowed.append(spell_id)
	var seen: Array[String] = []
	for spell_id in spell_ids:
		if spell_id not in allowed or spell_id in seen:
			return false
		seen.append(spell_id)
	c.wizard_spellbook.append_array(seen)
	c.wizard_spellbook_pending -= seen.size()
	c.refresh_spell_selection_from_choices()
	return true


static func wizard_spellbook_feature_options(c: Character, spell_level: int, require_action: bool = true) -> Array[String]:
	var options: Array[String] = []
	if c == null or c.class_id != "wizard" or spell_level not in [1, 2, 3]:
		return options
	for spell_id in c.wizard_spellbook:
		var spell := DataLoader.get_spell(spell_id)
		if SpellSupport.is_available(spell) and int(spell.get("level", -1)) == spell_level and (not require_action or str(spell.get("casting_time", "action")) == "action"):
			options.append(spell_id)
	return options


static func choose_wizard_spell_mastery(c: Character, spell_level: int, spell_id: String) -> bool:
	if c == null or c.class_id != "wizard" or not c.has_feature("wizard_spell_mastery") or spell_level not in [1, 2]:
		return false
	var key := str(spell_level)
	if spell_id not in wizard_spellbook_feature_options(c, spell_level):
		return false
	if c.wizard_spell_mastery.has(key):
		if not c.wizard_mastery_replacement_available or c.wizard_spell_mastery[key] == spell_id:
			return false
		c.wizard_mastery_replacement_available = false
	c.wizard_spell_mastery[key] = spell_id
	c.refresh_spell_selection_from_choices()
	return true


static func choose_wizard_signature_spells(c: Character, spell_ids: Array[String]) -> bool:
	if c == null or c.class_id != "wizard" or not c.has_feature("wizard_signature_spells") or not c.wizard_signature_spells.is_empty() or spell_ids.size() != 2:
		return false
	var eligible := wizard_spellbook_feature_options(c, 3, false)
	var selected: Array[String] = []
	for spell_id in spell_ids:
		if spell_id not in eligible or spell_id in selected:
			return false
		selected.append(spell_id)
	c.wizard_signature_spells.assign(selected)
	for spell_id in selected:
		c.feature_uses["wizard_signature_spell:%s" % spell_id] = 1
	c.refresh_spell_selection_from_choices()
	return true


## Copying requires a real Wizard source book, a destination book, and the
## 50-gp-per-spell-level transcription cost. The game has no downtime clock;
## the result includes the SRD time requirement for the owner-facing UI.
static func copy_wizard_spell(destination: Character, source: Character, spell_id: String) -> Dictionary:
	if destination == null or source == null or destination == source or destination.class_id != "wizard" or source.class_id != "wizard":
		return {"success": false, "message": "Copying requires two different Wizards."}
	if not destination.has_feature("wizard_ritual_adept") or not destination.inventory.has_item("spellbook") or not source.inventory.has_item("spellbook"):
		return {"success": false, "message": "Both Wizards must have their spellbooks."}
	if spell_id in destination.wizard_spellbook:
		return {"success": false, "message": "That spell is already in your spellbook."}
	if spell_id not in source.wizard_spellbook:
		return {"success": false, "message": "The source Wizard has not recorded that spell."}
	var spell := DataLoader.get_spell(spell_id)
	var spell_level := int(spell.get("level", 0))
	var on_wizard_list := false
	if not SpellSupport.is_available(spell):
		return {"success": false, "message": SpellSupport.availability(spell)["reason"]}
	for option in DataLoader.get_spell_list_options(destination.get_spell_list_ids()):
		if str(option.get("id", "")) == spell_id:
			on_wizard_list = true
			break
	if spell.is_empty() or spell_level < 1 or spell_level > destination.get_max_spell_slot_level() or not on_wizard_list:
		return {"success": false, "message": "That spell is not a valid Wizard spell level for this character."}
	var cost := 50 * spell_level
	if destination.inventory.gold < cost:
		return {"success": false, "message": "Copying %s costs %d gp." % [spell.get("name", spell_id), cost]}
	destination.inventory.gold -= cost
	destination.wizard_spellbook.append(spell_id)
	destination.refresh_spell_selection_from_choices()
	return {"success": true, "cost": cost, "hours": 2 * spell_level, "message": "%s copied %s into the spellbook for %d gp (%d hours of transcription)." % [destination.character_name, spell.get("name", spell_id), cost, 2 * spell_level]}


static func cast_wizard_ritual(c: Character, spell_id: String) -> Dictionary:
	return cast_ritual(c, spell_id)


static func _spell_casting_time_seconds(spell: Dictionary) -> int:
	if spell.has("cast_time_seconds"):
		return clampi(int(spell.cast_time_seconds), 1, 86400)
	match str(spell.get("casting_time", "action")):
		"minute": return 60
		"hour": return 3600
		"action", "bonus_action", "reaction": return 6
		_: return 6


static func ritual_host_error(spell: Dictionary) -> String:
	if spell.has("steps"):
		return "This ritual needs an exploration control for its ordered steps."
	if str(spell.get("target", "single")) != "self" or spell.has("damage") or spell.has("save") or str(spell.get("attack_type", "none")) != "none":
		return "This ritual needs a target or room control; the character sheet supports self rituals."
	if not SharedSpell.uses(spell):
		if not SpellEffects.manages(spell) or spell.get("effects", []).is_empty():
			return "This ritual needs its dedicated exploration control."
		for effect in spell.get("effects", []):
			if effect.get("type", "") != "grant_condition": return "This ritual needs its dedicated exploration control."
	return ""


static func cast_ritual(c: Character, spell_id: String, permission_id: String = "", expected_permission: Dictionary = {}) -> Dictionary:
	if c == null:
		return {"success": false, "message": "Ritual casting needs a caster."}
	if GameManager.current_state == GameManager.GameState.COMBAT:
		return {"success": false, "message": "Ritual casting takes longer than a combat turn and cannot be completed in combat."}
	if CombatAction.is_incapacitated(c) or c.is_dead():
		return {"success": false, "message": "You cannot cast a ritual in this state."}
	var spell := DataLoader.get_spell(spell_id)
	var spell_level := int(spell.get("level", 0))
	if spell.is_empty() or spell_level < 1 or not bool(spell.get("ritual", false)):
		return {"success": false, "message": "That spell is not an eligible ritual."}
	var eligible := SpellPermissionRules.ritual_permissions(c, spell)
	var ritual_only_sources := eligible.filter(func(row): return bool(row.get("ritual_only", false)))
	if permission_id.is_empty() and ritual_only_sources.size() == 1: eligible = ritual_only_sources
	if permission_id.is_empty() and eligible.size() != 1:
		return {"success": false, "message": "Choose one spell source for this ritual."}
	var permission: Dictionary = {}
	for candidate in eligible:
		if permission_id.is_empty() or str(candidate.get("id", "")) == permission_id:
			permission = candidate
			break
	if permission.is_empty(): return {"success": false, "message": "That spell source cannot cast this ritual."}
	if not expected_permission.is_empty() and permission != expected_permission:
		return {"success": false, "message": "That ritual source changed. Reopen the character sheet and select it again."}
	var host_error := ritual_host_error(spell)
	if not host_error.is_empty(): return {"success":false,"message":host_error}
	var source_class := str(permission.get("class_id", c.class_id))
	if not c.inventory.has_required_spell_component(spell, source_class):
		return {"success": false, "message": "The spell's required components are unavailable."}
	var cast_spell := spell.duplicate(true)
	cast_spell["_source_permission_id"] = str(permission.id)
	cast_spell["_source_permissions"] = eligible.duplicate(true)
	cast_spell["_spellcasting_ability"] = str(permission.ability)
	cast_spell["_ritual_cast"] = true
	var ritual_extra_seconds := clampi(int(permission.get("ritual_time_seconds", 600)), 600, 86400)
	var ritual_seconds := mini(86400, _spell_casting_time_seconds(spell) + ritual_extra_seconds)
	var context := SpellCastContext.new()
	context.caster = c
	context.spell = cast_spell
	context.ritual_seconds = ritual_seconds
	context.component_instance_id = c.inventory.required_spell_component_instance(spell)
	var result := CombatAction.resolve_spell(c, c, cast_spell, false, {}, [], 0, -1, context)
	if bool(result.get("success", false)):
		if not SharedSpell.uses(cast_spell):
			result = SharedSpell.apply(c, c, cast_spell, result)
		if bool(spell.get("concentration", false)):
			c.concentrating_on = {"spell_id":spell_id,"effect_source":str(result.get("effect_cast", {}).get("source_id", "")),"targets":[c]}
		result["ritual_seconds"] = ritual_seconds
		result["message"] = "%s (ritual; no spell slot used; takes %d minutes total). %s" % [spell.get("name", spell_id), int(ceil(float(ritual_seconds) / 60.0)), result.get("message", "")]
	return result


static func choose_sorcerer_metamagic(c: Character, option_ids: Array[String]) -> bool:
	if c == null or c.class_id != "sorcerer" or c.sorcerer_metamagic_pending <= 0 or option_ids.size() != c.sorcerer_metamagic_pending:
		return false
	var seen: Array[String] = []
	for option_id in option_ids:
		if not SorcererRules.metamagic_options().has(option_id) or option_id in c.sorcerer_metamagic_choices or option_id in seen:
			return false
		seen.append(option_id)
	c.sorcerer_metamagic_choices.append_array(seen)
	c.sorcerer_metamagic_pending = 0
	return true


static func replace_sorcerer_metamagic(c: Character, old_option: String, new_option: String) -> bool:
	if c == null or c.class_id != "sorcerer" or not c.sorcerer_metamagic_replacement_available:
		return false
	if old_option not in c.sorcerer_metamagic_choices or not SorcererRules.metamagic_options().has(new_option):
		return false
	if new_option in c.sorcerer_metamagic_choices:
		return false
	c.sorcerer_metamagic_choices[c.sorcerer_metamagic_choices.find(old_option)] = new_option
	c.sorcerer_metamagic_replacement_available = false
	return true

static func choose_skill_expertise(c: Character, feature_id: String, skills: Array[String]) -> bool:
	if feature_id not in pending_skill_expertise_choices(c):
		return false
	var feature := c.get_feature(feature_id)
	var effect: Dictionary = {}
	for candidate in feature.get("effects", []):
		if candidate.get("type", "") == "skill_expertise_choice":
			effect = candidate
	var count := int(effect.get("count", 2))
	var allowed_skills: Array = effect.get("allowed_skills", [])
	if skills.size() != count:
		return false
	var already_expert: Array = []
	for choice_id in skill_expertise_choice_ids(c):
		already_expert.append_array(c.feature_choices.get(choice_id, []))
	var seen: Array[String] = []
	for skill in skills:
		if skill not in c.skill_proficiencies or (not allowed_skills.is_empty() and skill not in allowed_skills) or skill in already_expert or skill in seen:
			return false
		seen.append(skill)
	c.feature_choices[feature_id] = skills.duplicate()
	return true

static func epic_boon_choice_ids(c: Character) -> Array[String]:
	var ids: Array[String] = []
	for feature in c.features:
		for effect in feature.get("effects", []):
			if effect.get("type", "") == "epic_boon_choice":
				ids.append(str(feature["id"]))
	return ids

static func pending_epic_boon_choices(c: Character) -> Array[String]:
	var pending: Array[String] = []
	for id in epic_boon_choice_ids(c):
		if c.feature_choices.has(id):
			continue
		# Preserve Fighter saves whose Combat Prowess was stored in the legacy
		# training field before feature choices became shared.
		if c.class_id == "fighter" and not str(c.fighter_training.get("boon", "")).is_empty():
			continue
		pending.append(id)
	return pending

static func choose_epic_boon(c: Character, feature_id: String, boon: String, ability: String) -> bool:
	if feature_id not in pending_epic_boon_choices(c) or ability not in AbilityScores.ABILITIES or c.ability_scores.get_permanent_score(ability) >= 30:
		return false
	var feature := c.get_feature(feature_id)
	var available: Array = []
	var required_abilities: Array = []
	for effect in feature.get("effects", []):
		if effect.get("type", "") == "epic_boon_choice":
			available = effect.get("options", [])
		required_abilities = effect.get("ability_scores_by_option", {}).get(boon, [])
	if boon not in available or (not required_abilities.is_empty() and ability not in required_abilities):
		return false
	increase_score(c, ability, 1)
	c.feature_choices[feature_id] = [boon, ability]
	if c.class_id == "fighter":
		c.fighter_training["boon"] = boon
		c.fighter_training["boon_ability"] = ability
	c._recalculate_ac()
	return true

static func has_epic_boon(c: Character, boon: String) -> bool:
	for feature_id in epic_boon_choice_ids(c):
		var choice: Variant = c.feature_choices.get(feature_id, [])
		if choice is Array and not choice.is_empty() and str(choice[0]) == boon:
			return true
	return c.class_id == "fighter" and str(c.fighter_training.get("boon", "")) == boon

static func apply_initiative_resource_recovery(c: Character) -> Dictionary:
	var recovered: Dictionary = {}
	if c == null:
		return recovered
	for feature in c.features:
		for effect in feature.get("effects", []) + feature.get("passive_effects", []):
			if effect.get("type", "") != "initiative_resource_recovery":
				continue
			var resource_id := str(effect.get("resource_id", ""))
			var maximum := c.get_feature_max_uses(resource_id)
			if resource_id.is_empty() or maximum < 0:
				continue
			var current := int(c.feature_uses.get(resource_id, maximum))
			var target := mini(maximum, int(effect.get("minimum", 1)))
			if current < target:
				recovered[resource_id] = target - current
				c.feature_uses[resource_id] = target
	return recovered

static func epic_boon_ability(c: Character, boon: String) -> String:
	for feature_id in epic_boon_choice_ids(c):
		var choice: Variant = c.feature_choices.get(feature_id, [])
		if choice is Array and choice.size() == 2 and str(choice[0]) == boon:
			return str(choice[1])
	if c.class_id == "fighter" and str(c.fighter_training.get("boon", "")) == boon:
		return str(c.fighter_training.get("boon_ability", ""))
	return ""

static func choose_skill_proficiency(c: Character, feature_id: String, skills: Array[String]) -> bool:
	if feature_id not in pending_skill_choices(c):
		return false
	var feature := c.get_feature(feature_id)
	var choice_effect: Dictionary = {}
	for effect in feature.get("effects", []):
		if effect.get("type", "") == "skill_proficiency_choice":
			choice_effect = effect
	var options: Array = choice_effect.get("options", [])
	var count := int(choice_effect.get("count", 1))
	if skills.size() != count:
		return false
	var seen: Array[String] = []
	for skill in skills:
		if skill not in options or skill in c.skill_proficiencies or skill in seen:
			return false
		seen.append(skill)
	for skill in skills:
		c.skill_proficiencies.append(skill)
	c.feature_choices[feature_id] = skills.duplicate()
	return true

static func improve_scores(c: Character, first: String, second: String) -> bool:
	var pending := pending_improvements(c)
	if pending.is_empty() or first not in AbilityScores.ABILITIES or second not in AbilityScores.ABILITIES:
		return false
	var gains := {first: 1}
	gains[second] = int(gains.get(second, 0)) + 1
	for ability in gains:
		if c.ability_scores.get_permanent_score(ability) + int(gains[ability]) > 20:
			return false
	for ability in gains:
		increase_score(c, ability, int(gains[ability]))
	c.feature_choices[pending[0]] = [first, second]
	if c.class_id == "fighter":
		c.fighter_training["asi_spent"] = int(c.fighter_training.get("asi_spent", 0)) + 1
	c._recalculate_ac()
	return true

static func increase_score(c: Character, ability: String, amount: int) -> void:
	var old_con := AbilityScores.get_modifier(c.ability_scores.get_permanent_score("CON"))
	var maxima := {}
	for feature in c.features:
		if feature.get("uses_ability", "") == ability:
			maxima[str(feature["id"])] = c.get_feature_max_uses(str(feature["id"]))
	c.ability_scores.set_score(ability, c.ability_scores.get_permanent_score(ability) + amount)
	for id in maxima:
		c.feature_uses[id] = mini(c.get_feature_max_uses(id), int(c.feature_uses.get(id, 0)) + maxi(0, c.get_feature_max_uses(id) - int(maxima[id])))
	if ability == "CON":
		var hp_gain := (AbilityScores.get_modifier(c.ability_scores.get_permanent_score("CON")) - old_con) * c.level
		c.max_hp += hp_gain
		c.current_hp += hp_gain


static func apply_fixed_score_increase(c: Character, effect: Dictionary) -> void:
	var scores: Dictionary = effect.get("scores", {})
	var maximum := int(effect.get("maximum", 20))
	for ability in scores:
		if str(ability).to_upper() not in AbilityScores.ABILITIES:
			continue
		var current := c.ability_scores.get_permanent_score(str(ability))
		var gained := mini(maxi(0, maximum - current), maxi(0, int(scores[ability])))
		if gained > 0:
			increase_score(c, str(ability), gained)
	c._recalculate_ac()

static func choose_subclass(c: Character, id: String) -> bool:
	var data := DataLoader.get_subclass(id)
	if data.is_empty() or (not c.subclass_id.is_empty() and c.subclass_id != id) or data.get("class_id", "") != c.class_id or c.level < int(DataLoader.get_character_class(c.class_id).get("subclass_level", 3)):
		return false
	c.subclass_id = id
	for gained_level in range(1, c.level + 1):
		c._unlock_features_for_level(gained_level)
	return true

static func restore_resource_from_spell_slot(c: Character, resource_id: String, slot_level: int, amount: int = 1) -> Dictionary:
	if c == null or resource_id.is_empty() or slot_level < 1 or amount < 1:
		return {"success": false, "message": "Choose a valid spell slot and resource."}
	var owned_conversion := false
	for feature in c.features:
		for effect in c._feature_effects(feature):
			if effect.get("type", "") == "resource_from_spell_slot" and str(effect.get("resource_id", "")) == resource_id and int(effect.get("amount", 1)) == amount:
				owned_conversion = true
	# Wild Resurgence owns its eligibility in the existing Druid resolver.
	# Preserve that caller without allowing an unearned Font conversion.
	if not owned_conversion and resource_id == "druid_wild_shape_uses" and amount == 1:
		var resurgence := DruidRules.wild_resurgence_state(c)
		owned_conversion = resurgence.get("mode", "") == "slot_to_wild_shape" and slot_level in resurgence.get("spell_slots", [])
	if not owned_conversion:
		return {"success": false, "message": "This spell-slot conversion is not owned."}
	var maximum := c.get_feature_max_uses(resource_id)
	var current := int(c.feature_uses.get(resource_id, maximum))
	if maximum < 0 or current >= maximum:
		return {"success": false, "message": "That resource is already full."}
	var slot_key := str(slot_level)
	if int(c.spell_slots.get(slot_key, 0)) <= 0:
		return {"success": false, "message": "No level %d spell slot remains." % slot_level}
	var restored := mini(amount, maximum - current)
	c.spell_slots[slot_key] = int(c.spell_slots[slot_key]) - 1
	c.feature_uses[resource_id] = current + restored
	return {"success": true, "restored": restored, "resource_id": resource_id, "slot_level": slot_level}

static func restore_legacy_choices(c: Character, dto: Dictionary) -> void:
	if dto.has("feature_choices") or c.class_id != "fighter":
		return
	var ids := improvement_ids(c)
	var consumed := mini(ids.size(), int(c.fighter_training.get("asi_spent", 0)))
	for index in consumed:
		# Older saves contain final scores and an aggregate count, not the choices.
		c.feature_choices[ids[index]] = []

static func saved_choices_error(dto: Dictionary) -> String:
	var feat_error := FeatRules.saved_error(dto) # Batch 051: origin and level-up feats.
	if not feat_error.is_empty():
		return feat_error
	var creation_error := saved_creation_error(dto)
	if not creation_error.is_empty():
		return creation_error
	var cleric_error := ClericRules.saved_state_error(dto)
	if not cleric_error.is_empty():
		return cleric_error
	var inspiration_error := BardicInspirationRules.saved_state_error(dto)
	if not inspiration_error.is_empty():
		return inspiration_error
	if dto.has("barbarian_relentless_rage_enabled") and not dto["barbarian_relentless_rage_enabled"] is bool:
		return "Relentless Rage policy must be a boolean"
	var class_id := str(dto.get("class_id", ""))
	var data := DataLoader.get_character_class(class_id)
	var level := int(dto.get("level", 1))
	var allocation_error := Character.saved_class_levels_error(dto)
	if not allocation_error.is_empty(): return allocation_error
	var feature_level := int(dto.get("class_levels", {}).get(class_id, level))
	var subclass_id: Variant = dto.get("subclass_id", data.get("legacy_subclass", "") if level >= int(data.get("subclass_level", 3)) else "")
	if not subclass_id is String:
		return "Subclass selection is not an ID"
	var subclass := DataLoader.get_subclass(subclass_id)
	if not subclass_id.is_empty() and (subclass.get("class_id", "") != class_id or level < int(data.get("subclass_level", 3))):
		return "Selected subclass is missing or unavailable for this character"
	var roll_token_error := RollTokenRules.saved_state_error(dto, data, subclass, level)
	if not roll_token_error.is_empty():
		return roll_token_error
	var ward_error := WardRules.saved_state_error(dto, data, subclass, level)
	if not ward_error.is_empty():
		return ward_error
	var choices: Variant = dto.get("feature_choices", {})
	if not choices is Dictionary:
		return "Feature choices are not an object"
	if dto.has("spell_choices_pending") and not dto["spell_choices_pending"] is bool:
		return "Spell-choice pending status is invalid"
	var repertoire_error := SpellRepertoireRules.saved_error(dto)
	if not repertoire_error.is_empty(): return repertoire_error
	var wizard_spellbook: Variant = dto.get("wizard_spellbook", [])
	if class_id == "wizard":
		if not dto.has("wizard_spellbook"):
			wizard_spellbook = []
			var legacy_choices: Variant = choices.get(str(data.get("spellcasting_feature_id", "")), dto.get("known_spells", []))
			if legacy_choices is Array:
				for legacy_spell_id in legacy_choices:
					if int(DataLoader.get_spell(str(legacy_spell_id)).get("level", 0)) > 0 and legacy_spell_id not in wizard_spellbook:
						wizard_spellbook.append(str(legacy_spell_id))
		if not wizard_spellbook is Array:
			return "Wizard spellbook is not an array"
		var expected_learned := 6 + 2 * (feature_level - 1)
		var pending_book_spells := int(dto.get("wizard_spellbook_pending", maxi(0, expected_learned - wizard_spellbook.size())))
		if pending_book_spells < 0 or pending_book_spells > expected_learned or wizard_spellbook.size() + pending_book_spells < expected_learned:
			return "Wizard spellbook learning count is invalid"
		var allowed_book: Dictionary = {}
		var wizard_max_spell_level := _max_spell_slot_level(data, feature_level)
		for spell in DataLoader.get_spell_list_options(["wizard"]):
			var spell_level := int(spell.get("level", -1))
			if spell_level > 0 and spell_level <= wizard_max_spell_level:
				allowed_book[str(spell.get("id", ""))] = true
		var seen_book: Dictionary = {}
		for spell_id in wizard_spellbook:
			if not spell_id is String or not allowed_book.has(spell_id) or seen_book.has(spell_id):
				return "Wizard spellbook contains an invalid or duplicate spell"
			seen_book[spell_id] = true
		var mastery: Variant = dto.get("wizard_spell_mastery", {})
		if not mastery is Dictionary:
			return "Wizard Spell Mastery choices are invalid"
		for spell_level in mastery:
			if str(spell_level) not in ["1", "2"] or feature_level < 18 or str(mastery[spell_level]) not in wizard_spellbook:
				return "Wizard Spell Mastery choices are invalid"
			var mastery_spell := DataLoader.get_spell(str(mastery[spell_level]))
			if int(mastery_spell.get("level", -1)) != int(spell_level) or str(mastery_spell.get("casting_time", "action")) != "action":
				return "Wizard Spell Mastery requires an action spell at the matching level"
		var signature: Variant = dto.get("wizard_signature_spells", [])
		if not signature is Array or signature.size() > 2 or (not signature.is_empty() and feature_level < 20):
			return "Wizard Signature Spell choices are invalid"
		var seen_signature: Dictionary = {}
		for signature_id in signature:
			var signature_spell := DataLoader.get_spell(str(signature_id))
			if not signature_id is String or signature_id not in wizard_spellbook or seen_signature.has(signature_id) or int(signature_spell.get("level", -1)) != 3:
				return "Wizard Signature Spells require two distinct level 3 spells in the spellbook"
			seen_signature[signature_id] = true
	for field in ["cleric_spells_trained", "cleric_preparation_free_change", "cleric_cantrip_replacement_available", "wizard_preparation_free_change", "wizard_memorize_spell_pending", "wizard_mastery_replacement_available"]:
		if dto.has(field) and not dto[field] is bool:
			return "Wizard preparation state is invalid"
	if bool(dto.get("wizard_mastery_replacement_available", false)) and (class_id != "wizard" or feature_level < 18):
		return "Wizard Spell Mastery replacement is unearned"
	if class_id == "sorcerer":
		var metamagic: Variant = dto.get("sorcerer_metamagic_choices", [])
		var metamagic_capacity := SorcererRules.metamagic_capacity(level)
		if not metamagic is Array or metamagic.size() > metamagic_capacity:
			return "Sorcerer Metamagic choices are invalid"
		var seen_metamagic: Dictionary = {}
		for option in metamagic:
			if not SorcererRules.metamagic_options().has(str(option)) or seen_metamagic.has(str(option)):
				return "Sorcerer Metamagic choices are invalid"
			seen_metamagic[str(option)] = true
		var metamagic_pending := int(dto.get("sorcerer_metamagic_pending", maxi(0, metamagic_capacity - metamagic.size())))
		if metamagic_pending < 0 or metamagic.size() + metamagic_pending != metamagic_capacity:
			return "Sorcerer Metamagic choices are incomplete"
		if dto.has("sorcerer_metamagic_replacement_available") and not dto["sorcerer_metamagic_replacement_available"] is bool:
			return "Sorcerer Metamagic replacement state is invalid"
	if class_id == "warlock":
		var invocation_ids: Variant = dto.get("warlock_invocations", [])
		if not invocation_ids is Array:
			return "Warlock invocations are not an array"
		var invocation_capacity := _warlock_invocation_capacity(data, level)
		var invocation_pending := int(dto.get("warlock_invocation_pending", maxi(0, invocation_capacity - invocation_ids.size())))
		if invocation_pending < 0 or invocation_ids.size() + invocation_pending != invocation_capacity:
			return "Warlock invocation choices do not match the class capacity"
		var invocation_options: Array = data.get("eldritch_invocation_options", [])
		var known_spell_ids: Array = dto.get("known_spells", [])
		var seen_invocations: Dictionary = {}
		for selection in invocation_ids:
			if not selection is String or seen_invocations.has(selection):
				return "Warlock invocation selection is invalid or repeated"
			seen_invocations[selection] = true
			var parts := str(selection).split(":", false, 1)
			var option: Dictionary = invocation_options.filter(func(candidate): return str(candidate.get("id", "")) == parts[0]).front() if not invocation_options.filter(func(candidate): return str(candidate.get("id", "")) == parts[0]).is_empty() else {}
			if option.is_empty() or level < int(option.get("minimum_level", 1)):
				return "Warlock invocation is missing or its level prerequisite is unmet"
			if bool(option.get("choose_damage_cantrip", false)):
				var cantrip := DataLoader.get_spell(parts[1]) if parts.size() == 2 else {}
				if parts.size() != 2 or parts[1] not in known_spell_ids or int(cantrip.get("level", -1)) != 0 or not cantrip.has("damage") or (bool(option.get("requires_attack_roll", false)) and str(cantrip.get("attack_type", "none")) not in ["ranged_spell", "melee_spell"]):
					return "Warlock invocation requires an eligible known damage cantrip"
			elif parts.size() != 1:
				return "Warlock invocation contains an unexpected option parameter"
			if not bool(option.get("repeatable", false)) and invocation_ids.count(str(option.get("id", ""))) > 1:
				return "Warlock invocation cannot be selected more than once"
		for selection in invocation_ids:
			var selected_parts := str(selection).split(":", false, 1)
			var selected_option: Dictionary = invocation_options.filter(func(candidate): return str(candidate.get("id", "")) == selected_parts[0]).front()
			for required_invocation in selected_option.get("requires_invocations", []):
				if not invocation_ids.any(func(value): return str(value).split(":")[0] == str(required_invocation)):
					return "Warlock invocation prerequisite is not selected"
		var arcanum: Variant = dto.get("warlock_mystic_arcanum", {})
		if not arcanum is Dictionary:
			return "Warlock Mystic Arcanum choices are not an object"
		var arcanum_uses: Variant = dto.get("warlock_arcanum_uses", {})
		if not arcanum_uses is Dictionary:
			return "Warlock Mystic Arcanum uses are not an object"
		for spell_level_key in arcanum:
			var arcanum_level := int(spell_level_key)
			var candidate_spells: Array = data.get("mystic_arcanum_spell_ids", {}).get(str(arcanum_level), [])
			if str(arcanum_level) != str(spell_level_key) or arcanum_level not in [6, 7, 8, 9] or level < arcanum_level * 2 - 1 or arcanum[spell_level_key] not in candidate_spells or int(arcanum_uses.get(spell_level_key, 1)) not in [0, 1]:
				return "Warlock Mystic Arcanum choice or use count is invalid"
		var pending_arcanum: Variant = dto.get("warlock_arcanum_pending_levels", [])
		if not dto.has("warlock_arcanum_pending_levels"):
			pending_arcanum = []
			for arcanum_level in [6, 7, 8, 9]:
				if arcanum_level * 2 - 1 <= level and not arcanum.has(str(arcanum_level)):
					pending_arcanum.append(arcanum_level)
		if not pending_arcanum is Array or pending_arcanum.any(func(value): return int(value) not in [6, 7, 8, 9] or level < int(value) * 2 - 1 or arcanum.has(str(value))):
			return "Warlock Mystic Arcanum learning choices are invalid"
		for arcanum_level in [6, 7, 8, 9]:
			if arcanum_level * 2 - 1 <= level and not arcanum.has(str(arcanum_level)) and arcanum_level not in pending_arcanum:
				return "Warlock Mystic Arcanum choice is missing"
		for field in ["warlock_invocation_replacement_available", "warlock_arcanum_replacement_available"]:
			if dto.has(field) and not dto[field] is bool:
				return "Warlock replacement state is invalid"
	var entitled := {}
	var skill_entitlements := {}
	var boon_entitlements := {}
	var expertise_entitlements := {}
	var feature_choice_entitlements := {}
	var spell_entitlements := {}
	var saved_skill_choices: Array[String] = []
	var proficiencies: Array = dto.get("skill_proficiencies", [])
	var saved_expertise_choices: Array[String] = []
	var mastery_effect: Dictionary = {}
	var predicate_actor := Character.new()
	predicate_actor.character_id = str(dto.get("character_id", ""))
	predicate_actor.level = level
	for source in [data, subclass]:
		for level_key in source.get("features_by_level", {}):
			if int(level_key) > feature_level:
				continue
			for feature in source["features_by_level"][level_key]:
				for effect in feature.get("effects", []):
					if effect.get("type", "") == "asi":
						entitled[str(feature["id"])] = true
					if effect.get("type", "") == "weapon_mastery":
						mastery_effect = effect
					if effect.get("type", "") == "skill_proficiency_choice":
						skill_entitlements[str(feature["id"])] = effect
					if effect.get("type", "") == "epic_boon_choice":
						boon_entitlements[str(feature["id"])] = effect
					if effect.get("type", "") == "skill_expertise_choice":
						expertise_entitlements[str(feature["id"])] = effect
					if effect.get("type", "") == "spellcasting":
						spell_entitlements[str(feature["id"])] = effect
					if effect.get("type", "") == "feature_choice":
						feature_choice_entitlements[str(feature["id"])] = effect
	# Retain the obsolete level-10 grant only when reconstructing an existing save.
	var separate_spell_sources := {}
	for source in SpellRepertoireRules.sources_for(class_id, level, dto.get("class_levels", {})):
		spell_entitlements[source.id] = source
		separate_spell_sources[source.id] = true
	# New characters never receive this entitlement.
	if class_id == "barbarian" and level >= 10 and choices.has("barbarian_primal_knowledge_10"):
		skill_entitlements["barbarian_primal_knowledge_10"] = {"count": 1, "options": data.get("skill_choices", {}).get("from", [])}
	for id in choices:
		if (not entitled.has(id) and not skill_entitlements.has(id) and not boon_entitlements.has(id) and not expertise_entitlements.has(id) and not spell_entitlements.has(id) and not feature_choice_entitlements.has(id)) or not choices[id] is Array:
			return "Feature choice references a missing or unearned improvement"
		var abilities: Array = choices[id]
		if feature_choice_entitlements.has(id):
			var entitlement: Dictionary = feature_choice_entitlements[id]
			var expected_count := int(entitlement.get("count", entitlement.get("pick", 1)))
			if abilities.size() != expected_count:
				return "Feature option choice count must match the required count"
			var allowed_options: Dictionary = {}
			for option in entitlement.get("options", []):
				allowed_options[str(option.get("id", ""))] = option
			var allow_duplicates := bool(entitlement.get("allow_duplicates", false))
			var seen_choices := {}
			for chosen_item in abilities:
				if not chosen_item is String or not allowed_options.has(str(chosen_item)):
					return "Feature option choice contains an invalid option"
				var chosen_id := str(chosen_item)
				var opt: Dictionary = allowed_options[chosen_id]
				if not allow_duplicates and not bool(opt.get("repeatable", false)) and seen_choices.has(chosen_id):
					return "Feature option choice cannot contain duplicates"
				seen_choices[chosen_id] = true
				if opt.has("minimum_level") and level < int(opt["minimum_level"]):
					return "Feature option choice level prerequisite is not met"
				if opt.has("class_id") and not _choice_class_matches(class_id, dto.get("class_levels", {}), str(opt["class_id"])):
					return "Feature option choice class prerequisite is not met"
				if opt.has("when") and not SharedStepExecutor.evaluate_actor_predicate(opt["when"], predicate_actor):
					return "Feature option choice fact prerequisite is not met"
				for req_choice in opt.get("requires_choices", []):
					var req_met := false
					for other_id in choices:
						var other_list = choices[other_id]
						if other_list is Array and str(req_choice) in other_list:
							req_met = true
							break
					if not req_met:
						return "Feature option choice prerequisite is not selected"
			continue
		if spell_entitlements.has(id):
			if separate_spell_sources.has(id): continue # Validated against its own class level/list above.
			var spell_error := _saved_spell_choice_error(abilities, spell_entitlements[id], data, subclass, level, choices, bool(dto.get("spell_choices_pending", false)), wizard_spellbook if class_id == "wizard" else [], feature_level)
			if not spell_error.is_empty():
				return spell_error
			continue
		if boon_entitlements.has(id):
			var allowed_boons: Array = boon_entitlements[id].get("options", [])
			if abilities.size() != 2 or abilities[0] not in allowed_boons or not abilities[1] is String or abilities[1] not in AbilityScores.ABILITIES:
				return "Epic Boon choice must include a supported boon and ability score"
			var required_abilities: Array = boon_entitlements[id].get("ability_scores_by_option", {}).get(str(abilities[0]), [])
			if not required_abilities.is_empty() and abilities[1] not in required_abilities:
				return "Epic Boon choice uses an ability score that is not allowed for that boon"
			continue
		if expertise_entitlements.has(id):
			var expertise_count := int(expertise_entitlements[id].get("count", 2))
			if abilities.size() != expertise_count:
				return "Expertise choice has the wrong number of skills"
			var seen_expertise: Array = []
			for skill in abilities:
				if not skill is String or (skill not in saved_skill_choices and skill not in proficiencies) or skill in saved_expertise_choices or skill in seen_expertise:
					return "Expertise choice must reference distinct proficient skills"
				seen_expertise.append(skill)
				saved_expertise_choices.append(skill)
			continue
		if skill_entitlements.has(id):
			var options: Array = skill_entitlements[id].get("options", [])
			if abilities.size() != int(skill_entitlements[id].get("count", 1)):
				return "Skill feature choice has the wrong number of skills"
			var seen_skills: Array = []
			for skill in abilities:
				if not skill is String or skill not in options or skill in seen_skills or skill in saved_skill_choices:
					return "Skill feature choice contains an invalid or duplicate skill"
				seen_skills.append(skill)
				saved_skill_choices.append(skill)
			continue
		if abilities.is_empty() and class_id == "fighter":
			continue
		if entitled.has(id) and abilities.size() == 1 and abilities[0] is String and str(abilities[0]).begins_with(FeatRules.PREFIX):
			continue # Batch 051: this improvement was taken as a feat (checked by FeatRules.saved_error).
		if abilities.size() != 2:
			return "Ability improvement requires two ability choices"
		for ability in abilities:
			if not ability is String or ability not in AbilityScores.ABILITIES:
				return "Unknown ability improvement choice"
	if dto.has("feature_choices") and class_id == "fighter":
		var training: Variant = dto.get("fighter_training", {})
		var spent_improvements := 0
		for choice_id in choices:
			if entitled.has(choice_id):
				spent_improvements += 1
		if not training is Dictionary or spent_improvements != int(training.get("asi_spent", 0)):
			return "Fighter improvement choices disagree with spent entitlement"
	var legacy_masteries: Array = []
	var legacy_training: Variant = dto.get("fighter_training", {})
	if legacy_training is Dictionary:
		legacy_masteries = legacy_training.get("masteries", [])
	var mastery_choices: Variant = dto.get("weapon_masteries", legacy_masteries)
	if not mastery_choices is Array:
		return "Weapon mastery choices are not an array"
	if not mastery_effect.is_empty():
		var capacity_table: Dictionary = mastery_effect.get("capacity_by_level", {})
		var capacity := 0
		var threshold := 0
		for key in capacity_table:
			if int(key) <= level and int(key) > threshold:
				threshold = int(key)
		capacity = int(capacity_table.get(str(threshold), 0))
		var seen_weapons: Array[String] = []
		for mastery_id in mastery_choices:
			var id := str(mastery_id)
			var item := DataLoader.get_item(id)
			if id in seen_weapons or item.get("type", "") != "weapon" or (bool(mastery_effect.get("melee_only", false)) and "ranged" in item.get("properties", [])):
				return "Weapon mastery choices contain an invalid weapon"
			seen_weapons.append(id)
		if seen_weapons.size() > capacity:
			return "Weapon mastery choices exceed the class capacity"
	elif not mastery_choices.is_empty():
		return "Weapon mastery choices are not granted by this class"
	return ""


static func _saved_spell_choice_error(choice: Array, effect: Dictionary, class_data: Dictionary, subclass: Dictionary, level: int, feature_choices: Dictionary, allow_incomplete: bool, wizard_spellbook: Array = [], feature_level: int = -1) -> String:
	var source_level := level if feature_level < 0 else feature_level
	var capacities: Dictionary = effect.get("capacity_by_level", {})
	var threshold := 0
	for key in capacities:
		if int(key) <= source_level and int(key) > threshold:
			threshold = int(key)
	if threshold == 0:
		return "Spellcasting choice has no capacity for this level"
	var capacity: Dictionary = capacities[str(threshold)]
	var expected_cantrips := int(capacity.get("cantrips", 0))
	var expected_prepared := int(capacity.get("prepared_spells", 0))
	var spell_lists: Array = effect.get("spell_lists", []).duplicate()
	var cantrip_lists: Array = [] if bool(effect.get("level_1_plus_only", false)) else spell_lists.duplicate()
	var granted_effects: Array = []
	for source in [class_data, subclass]:
		for level_key in source.get("features_by_level", {}):
			if int(level_key) > (level if feature_level < 0 else feature_level): continue
			for feature in source["features_by_level"][level_key]:
				for feature_effect in feature.get("effects", []) + feature.get("passive_effects", []):
					if feature_effect.get("type", "") != "feature_choice":
						granted_effects.append(feature_effect)
						continue
					var saved_options: Variant = feature_choices.get(str(feature.get("id", "")), [])
					if not saved_options is Array: continue
					for selected_id in saved_options:
						for option in feature_effect.get("options", []):
							if str(option.get("id", "")) == str(selected_id):
								granted_effects.append_array(option.get("effects", []))
	for grant in granted_effects:
		if grant.get("type", "") == "spellcasting_capacity_bonus":
			if grant.get("kind", "") == "cantrips": expected_cantrips += int(grant.get("amount", 0))
			elif grant.get("kind", "") == "prepared_spells": expected_prepared += int(grant.get("amount", 0))
		elif grant.get("type", "") == "spell_list_expansion":
			for list_id in grant.get("spell_lists", []):
				if list_id not in spell_lists: spell_lists.append(list_id)
				if not bool(grant.get("level_1_plus_only", false)) and list_id not in cantrip_lists: cantrip_lists.append(list_id)
	var allowed_cantrips: Dictionary = {}
	for spell in DataLoader.get_spell_list_options(cantrip_lists):
		if int(spell.get("level", -1)) == 0: allowed_cantrips[str(spell.get("id", ""))] = true
	var allowed: Dictionary = {}
	for spell in DataLoader.get_spell_list_options(spell_lists):
		var spell_id := str(spell.get("id", ""))
		if int(spell.get("level", -1)) != 0 or allowed_cantrips.has(spell_id): allowed[spell_id] = spell
	if str(class_data.get("id", "")) == "wizard":
		for spell_id in allowed.keys():
			if int(allowed[spell_id].get("level", -1)) > 0 and spell_id not in wizard_spellbook:
				allowed.erase(spell_id)
	var cantrip_count := 0
	var prepared_count := 0
	var seen: Dictionary = {}
	var maximum_slot_level := _max_spell_slot_level(class_data, source_level)
	for spell_id in choice:
		if not spell_id is String or seen.has(spell_id) or not allowed.has(spell_id):
			return "Spellcasting choice contains a duplicate or unavailable spell"
		seen[spell_id] = true
		var spell_level := int(allowed[spell_id].get("level", -1))
		if spell_level == 0:
			cantrip_count += 1
		elif spell_level > 0 and spell_level <= maximum_slot_level:
			prepared_count += 1
		else:
			return "Prepared spell is above the character's available spell level"
	if allow_incomplete:
		if cantrip_count > expected_cantrips or prepared_count > expected_prepared:
			return "Spellcasting choices exceed the character's cantrip or prepared spell capacity"
	elif cantrip_count != expected_cantrips or prepared_count != expected_prepared:
		return "Spellcasting choices do not match the character's cantrip and prepared spell capacity"
	return ""


static func _max_spell_slot_level(class_data: Dictionary, level: int) -> int:
	var pact: Dictionary = class_data.get("pact_magic_by_level", {}).get(str(level), {})
	if not pact.is_empty():
		return int(pact.get("slot_level", 0))
	var slots: Array = class_data.get("spell_slots_by_character_level", {}).get(str(level), [])
	for index in range(slots.size() - 1, -1, -1):
		if int(slots[index]) > 0:
			return index + 1
	return 0


static func _warlock_invocation_capacity(class_data: Dictionary, level: int) -> int:
	var maximum := 0
	for key in class_data.get("eldritch_invocations_by_level", {}):
		if int(key) <= level:
			maximum = maxi(maximum, int(class_data["eldritch_invocations_by_level"][key]))
	return maximum
