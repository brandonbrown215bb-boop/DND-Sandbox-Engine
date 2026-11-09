## CXM-04 / S-231: background acquisition at creation (SRD 5.2.1 p.83).
## A background gives +2/+1 or +1/+1/+1 among its three listed abilities (no
## score above 20), its fixed Origin feat, two skills, a fixed or chosen tool
## proficiency, and its equipment or 50 GP. Character.initialize grants it once;
## restore replays nothing. A character with a background takes no legacy
## species ability bonuses.
class_name BackgroundRules
extends RefCounted

static func definition_error(data: Dictionary) -> String:
	var abilities: Variant = data.get("ability_options", [])
	if not abilities is Array or abilities.size() != 3 or DataLoader._unique_count(abilities) != 3 or abilities.any(func(a): return a not in AbilityScores.ABILITIES): return "Background ability_options must list three distinct abilities"
	var skills: Variant = data.get("skills", [])
	if not skills is Array or skills.size() != 2 or DataLoader._unique_count(skills) != 2 or skills.any(func(s): return s not in DataLoader.VALID_SKILLS): return "Background skills must list two distinct valid skills"
	if not data.get("origin_feat", null) is String or str(FeatRules.selection(data.origin_feat).feat_id).is_empty(): return "Background origin_feat must be a feat id"
	var grants: Variant = data.get("tool_proficiency_grants", [])
	if not _ids(grants) or grants.size() != DataLoader._unique_count(grants): return "Background tool_proficiency_grants must list distinct tool ids"
	if data.has("tool_choices"):
		var choice: Variant = data.tool_choices
		if not choice is Dictionary or not _ids(choice.get("from", null)) or not _whole(choice.get("pick", null)) or int(choice.pick) < 1 or int(choice.pick) > choice.from.size() or choice.from.size() != DataLoader._unique_count(choice.from) or choice.from.any(func(id): return id in grants): return "Background tool_choices must pick from distinct tool ids not already granted"
	if data.has("starting_equipment_includes_tool_choice") and (not data.starting_equipment_includes_tool_choice is bool or (data.starting_equipment_includes_tool_choice and not data.has("tool_choices"))): return "starting_equipment_includes_tool_choice must be a boolean and requires tool_choices"
	if not _ids(data.get("starting_equipment", [])): return "Background starting_equipment must list item ids"
	for key in ["starting_gold", "starting_gold_alternative"]:
		if not _whole(data.get(key, null)): return "Background %s must be a whole number of GP" % key
	return ""

## Checked once every layer is loaded: the feat, tools and items must exist.
static func reference_error(data: Dictionary) -> String:
	var picked := FeatRules.selection(str(data.origin_feat))
	var feat := DataLoader.get_feat(str(picked.feat_id))
	var parameters: Array = feat.get("repeatable_parameter_options", [])
	if str(feat.get("category", "")) != "origin" or (parameters.is_empty() != str(picked.parameter).is_empty()) or (not parameters.is_empty() and picked.parameter not in parameters): return "Background '%s' needs a loaded Origin feat with a legal parameter, not '%s'" % [data.id, data.origin_feat]
	# shortcut: a background's feat is granted without picks; add picks to background_choices when a background grants Skilled.
	if feat.has("proficiency_choices"): return "Background '%s' cannot grant '%s': Origin feats with proficiency choices are not supported on backgrounds" % [data.id, data.origin_feat]
	for tool_id in data.get("tool_proficiency_grants", []) + data.get("tool_choices", {}).get("from", []):
		if DataLoader.get_item(str(tool_id)).get("type", "") != "tool": return "Background '%s' references missing tool '%s'" % [data.id, tool_id]
	for item_id in data.get("starting_equipment", []):
		if DataLoader.get_item(str(item_id)).is_empty(): return "Background '%s' references missing item '%s'" % [data.id, item_id]
	return ""

## Why these picks are not a legal background acquisition ("" when they are).
## choices: {"abilities": {ability: 1 or 2}, "tools": [tool ids], "equipment": "equipment" or "gold"}.
static func choices_error(background_id: String, choices: Dictionary) -> String:
	var data := DataLoader.get_background(background_id)
	if data.is_empty(): return "Choose a background."
	var increases: Variant = choices.get("abilities", {})
	var values: Array = []
	if increases is Dictionary:
		for ability in increases:
			values.append(int(increases[ability]) if ability in data.ability_options and _whole(increases[ability]) else 0)
	values.sort()
	if values != [1, 2] and values != [1, 1, 1]: return "Choose +2 and +1, or +1 to all three, among %s." % ", ".join(data.ability_options)
	var tools: Variant = choices.get("tools", [])
	var contract: Dictionary = data.get("tool_choices", {})
	if not tools is Array or tools.size() != int(contract.get("pick", 0)) or tools.size() != DataLoader._unique_count(tools) or tools.any(func(id): return id not in contract.get("from", [])): return "Choose your background tool proficiency."
	if choices.get("equipment", "") not in ["equipment", "gold"]: return "Choose your background's equipment or %d GP." % int(data.starting_gold_alternative)
	return ""

## choices_error plus the checks against the rest of creation: the score cap,
## class skill picks, a species-granted copy of the feat and backpack room.
static func creation_error(background_id: String, choices: Dictionary, scores: AbilityScores, race_id: String, class_skills: Array, class_items: Array) -> String:
	var error := choices_error(background_id, choices)
	if not error.is_empty(): return error
	var data := DataLoader.get_background(background_id)
	for ability in choices.abilities:
		if scores.get_permanent_score(str(ability)) + int(choices.abilities[ability]) > 20: return "%s cannot be raised above 20." % ability
	for skill in data.skills:
		if skill in class_skills: return "Your %s background already gives %s. Choose a different class skill." % [data.name, skill]
	var feat_id := str(FeatRules.selection(str(data.origin_feat)).feat_id)
	if feat_id in DataLoader.get_race(race_id).get("feats", []) and not bool(DataLoader.get_feat(feat_id).get("repeatable", false)): return "Your species already grants %s. Choose another background." % DataLoader.get_feat(feat_id).get("name", feat_id)
	var items := starting_items(background_id, choices)
	if not items.is_empty():
		var probe := Inventory.new() # The class kit lands first; the background kit must then fit whole.
		probe.add_starting_equipment(class_items)
		if probe.backpack.size() + items.size() > Inventory.MAX_BACKPACK_SIZE: return "Your class and background equipment will not fit in the backpack. Take the background's GP instead."
	return ""

## The seven legal increases: each ordered +2/+1 pair, then +1 to all three.
static func ability_spreads(background_id: String) -> Array:
	var options: Array = DataLoader.get_background(background_id).get("ability_options", [])
	var spreads: Array = []
	for two in options:
		for one in options:
			if two != one: spreads.append({two: 2, one: 1})
	if options.size() == 3: spreads.append({options[0]: 1, options[1]: 1, options[2]: 1})
	return spreads

static func starting_items(background_id: String, choices: Dictionary) -> Array:
	var data := DataLoader.get_background(background_id)
	if str(choices.get("equipment", "")) != "equipment": return []
	var items: Array = data.get("starting_equipment", []).duplicate()
	if data.get("starting_equipment_includes_tool_choice", false) == true: items.append_array(choices.get("tools", []))
	return items

static func starting_gold(background_id: String, choices: Dictionary) -> int:
	var data := DataLoader.get_background(background_id)
	return int(data.get("starting_gold_alternative" if str(choices.get("equipment", "")) == "gold" else "starting_gold", 0))

## Grants an already validated background to a character being created.
## The ability increases are applied earlier by Character.initialize, before HP.
static func apply(c: Character, background_id: String, choices: Dictionary) -> void:
	var data := DataLoader.get_background(background_id)
	c.background_id = background_id
	c.background_choices = {"abilities": {}, "tools": choices.tools.duplicate(), "equipment": str(choices.equipment)}
	for ability in choices.abilities: c.background_choices.abilities[str(ability)] = int(choices.abilities[ability])
	for skill in data.skills:
		if skill not in c.skill_proficiencies: c.skill_proficiencies.append(str(skill))
	for tool_id in data.get("tool_proficiency_grants", []) + choices.tools:
		ClassProgression.grant_tool_proficiency(c, str(tool_id), "background:%s" % background_id)
	c.inventory.add_starting_equipment(starting_items(background_id, choices))
	c.inventory.gold += starting_gold(background_id, choices)
	FeatRules.choose_origin(c, str(data.origin_feat))

## Save check: a saved background is loaded, its picks are legal, and its feat,
## skills and tool sources are still held. Saves without a background are legacy.
static func saved_error(dto: Dictionary) -> String:
	var id: Variant = dto.get("background_id", "")
	var choices: Variant = dto.get("background_choices", {})
	if not id is String or not choices is Dictionary: return "Background is invalid"
	if id.is_empty(): return "" if choices.is_empty() else "Background choices have no background"
	var data := DataLoader.get_background(id)
	if data.is_empty(): return "Background '%s' is unknown" % id
	if choices.size() != 3 or not choices_error(id, choices).is_empty(): return "Background choices are invalid"
	if dto.get("origin_feat", "") != data.origin_feat: return "Background Origin feat is missing"
	var skills: Variant = dto.get("skill_proficiencies", [])
	var sources: Variant = dto.get("tool_proficiency_sources", {})
	if not skills is Array or not sources is Dictionary: return "Background proficiency lists are invalid"
	for skill in data.skills:
		if skill not in skills: return "Background skill proficiency is missing"
	var source := "background:%s" % id
	var owned: Array = data.get("tool_proficiency_grants", []) + choices.tools
	for tool_id in owned:
		if not sources.get(tool_id, []) is Array or source not in sources.get(tool_id, []): return "Background tool proficiency source is missing"
	for tool_id in sources:
		if not sources[tool_id] is Array: continue
		for held in sources[tool_id]:
			if str(held).begins_with("background:") and (held != source or tool_id not in owned): return "Background tool proficiency source is stale"
	return ""

static func _ids(value: Variant) -> bool:
	return value is Array and not value.any(func(id): return not id is String or id.is_empty())

static func _whole(value: Variant) -> bool:
	return (value is int or value is float) and float(value) == floorf(float(value)) and float(value) >= 0
