## Batch 051 (card Q-20261021-004820-aaf1): ordinary feat acquisition.
## SRD 5.2.1 p.83: a background gives a specified Origin feat at creation.
## SRD 5.2.1 class "Ability Score Improvement" features (e.g. p.29): you gain the
## Ability Score Improvement feat or another feat of your choice for which you qualify.
## SRD 5.2.1 p.87 "Parts of a Feat": every feat has a category; you must meet
## its prerequisite (a level, an ability score); a feat can be taken only once
## unless it is Repeatable.
class_name FeatRules
extends RefCounted

const CATEGORIES := ["origin", "general", "fighting_style", "epic_boon"]
const PREFIX := "feat:"

static func definition_error(data: Dictionary) -> String:
	if "|" in str(data.get("id", "")): return "Feat ids cannot contain '|'"
	if str(data.get("category", "")) not in CATEGORIES: return "Feat category must be origin, general, fighting_style or epic_boon"
	if data.has("repeatable") and not data.repeatable is bool: return "Feat repeatable must be a boolean"
	if bool(data.get("repeatable", false)) and not data.get("features", []).is_empty(): return "A repeatable feat cannot own mode/upgrade features (their ids would collide)"
	var pre: Variant = data.get("prerequisite", {})
	if not pre is Dictionary: return "Feat prerequisite must be an object"
	for key in pre:
		if str(key) not in ["level", "abilities_any", "class_levels", "features_any"]: return "Feat prerequisite contains an unsupported requirement"
	if pre.has("level") and not FeatureModeRules._int(pre.level, 1, 20): return "Feat prerequisite level must be 1-20"
	if pre.has("abilities_any"):
		var any: Variant = pre.abilities_any
		if not any is Dictionary or any.is_empty(): return "Feat abilities_any must map abilities to minimum scores"
		for ability in any:
			if str(ability) not in AbilityScores.ABILITIES or not FeatureModeRules._int(any[ability], 1, 30): return "Feat abilities_any must map abilities to minimum scores"
	if pre.has("class_levels"):
		var classes: Variant = pre.class_levels
		if not classes is Dictionary or classes.is_empty(): return "Feat class_levels must map class ids to minimum levels"
		for class_id in classes:
			if DataLoader.get_character_class(str(class_id)).is_empty() or not FeatureModeRules._int(classes[class_id], 1, 20): return "Feat class_levels contains an invalid class or level"
	if pre.has("features_any"):
		var features: Variant = pre.features_any
		if not features is Array or features.is_empty(): return "Feat features_any must be a non-empty list"
		for feature_id in features:
			if not feature_id is String or str(feature_id).is_empty(): return "Feat features_any entries must be feature ids"
	if data.has("repeatable_parameter_options"):
		var parameters: Variant = data.repeatable_parameter_options
		if not bool(data.get("repeatable", false)) or not parameters is Array or parameters.is_empty(): return "repeatable_parameter_options requires a repeatable feat and a non-empty list"
		var seen := {}
		for parameter in parameters:
			if not parameter is String or str(parameter).is_empty() or "|" in str(parameter) or seen.has(str(parameter)): return "Repeatable feat parameters must be unique non-empty strings without '|'"
			seen[str(parameter)] = true
	return ""

## Feats owned through choices: the creation origin feat and level-up feat picks.
static func chosen(origin_feat: String, feature_choices: Variant) -> Array[String]:
	var out: Array[String] = []
	if not origin_feat.is_empty(): out.append(str(selection(origin_feat).feat_id))
	if feature_choices is Dictionary:
		for id in feature_choices:
			var picked: Variant = feature_choices[id]
			if picked is Array and picked.size() == 1 and picked[0] is String and str(picked[0]).begins_with(PREFIX): out.append(str(selection(str(picked[0]).trim_prefix(PREFIX)).feat_id))
	return out

static func owned(c: Character) -> Array[String]:
	var out: Array[String] = []
	for id in DataLoader.get_race(c.race_id).get("feats", []): out.append(str(id))
	out.append_array(chosen(c.origin_feat, c.feature_choices))
	return out

## Why this feat cannot be taken now ("" when it can). category="" means any.
static func eligibility_error(c: Character, feat_id: String, category: String, parameter: String = "") -> String:
	var feat := DataLoader.get_feat(feat_id)
	if feat.is_empty(): return "Unknown feat."
	if not category.is_empty() and str(feat.get("category", "")) != category: return "%s is not a %s feat." % [feat.get("name", feat_id), category.replace("_", " ")]
	var parameters: Array = feat.get("repeatable_parameter_options", [])
	if not parameters.is_empty() and parameter not in parameters: return "Choose a valid distinct option for %s." % feat.get("name", feat_id)
	if parameters.is_empty() and not parameter.is_empty(): return "%s has no repeatable parameter." % feat.get("name", feat_id)
	if not bool(feat.get("repeatable", false)) and feat_id in owned(c): return "You already have %s." % feat.get("name", feat_id)
	if not parameters.is_empty() and _chosen_parameter(c, feat_id, parameter): return "You already chose that %s option." % feat.get("name", feat_id)
	var pre: Dictionary = feat.get("prerequisite", {})
	if c.level < int(pre.get("level", 1)): return "%s requires level %d." % [feat.get("name", feat_id), int(pre.level)]
	for class_id in pre.get("class_levels", {}):
		var required_level := int(pre.class_levels[class_id])
		if c.get_class_level(str(class_id)) < required_level: return "%s requires %s level %d." % [feat.get("name", feat_id), str(class_id).capitalize(), required_level]
	if pre.has("features_any") and not pre.features_any.any(func(feature_id): return c.has_feature(str(feature_id))): return "%s requires one of: %s." % [feat.get("name", feat_id), ", ".join(pre.features_any)]
	if pre.has("abilities_any"):
		var met := false
		for ability in pre.abilities_any:
			if c.ability_scores.get_permanent_score(str(ability)) >= int(pre.abilities_any[ability]): met = true
		if not met: return "%s requires %s." % [feat.get("name", feat_id), " or ".join(pre.abilities_any.keys().map(func(a): return "%s %d+" % [a, int(pre.abilities_any[a])]))]
	return ""

static func options(c: Character, category: String) -> Array[String]:
	var out: Array[String] = []
	var ids: Array = DataLoader.feats.keys()
	ids.sort()
	for id in ids:
		var feat: Dictionary = DataLoader.get_feat(str(id))
		var parameters: Array = feat.get("repeatable_parameter_options", [])
		if parameters.is_empty():
			if eligibility_error(c, str(id), category).is_empty(): out.append(str(id))
		else:
			for parameter in parameters:
				if eligibility_error(c, str(id), category, str(parameter)).is_empty(): out.append("%s|%s" % [id, parameter])
	return out

## Character creation: the Origin feat, once, before the character joins the party.
static func choose_origin(c: Character, feat_id: String) -> Dictionary:
	if not c.origin_feat.is_empty(): return {"success": false, "message": "An Origin feat is already chosen."}
	var picked := selection(feat_id)
	var error := eligibility_error(c, picked.feat_id, "origin", picked.parameter)
	if not error.is_empty(): return {"success": false, "message": error}
	c.origin_feat = feat_id
	OwnedFeatureSources.sync(c)
	return {"success": true, "message": "%s gained." % label(feat_id)}

## Level-up: spend one pending Ability Score Improvement on a feat instead.
static func choose_level_feat(c: Character, feat_id: String) -> Dictionary:
	var pending := ClassProgression.pending_improvements(c)
	if pending.is_empty(): return {"success": false, "message": "No Ability Score Improvement is waiting."}
	var picked := selection(feat_id)
	var chosen_id := str(picked.feat_id)
	var parameter := str(picked.parameter)
	var error := eligibility_error(c, chosen_id, "", parameter)
	if not error.is_empty(): return {"success": false, "message": error}
	c.feature_choices[pending[0]] = [PREFIX + chosen_id + ("|" + parameter if not parameter.is_empty() else "")]
	if c.class_id == "fighter": c.fighter_training["asi_spent"] = int(c.fighter_training.get("asi_spent", 0)) + 1
	OwnedFeatureSources.sync(c)
	return {"success": true, "message": "%s gained." % DataLoader.get_feat(chosen_id).get("name", chosen_id)}

static func _chosen_parameter(c: Character, feat_id: String, parameter: String) -> bool:
	if not c.origin_feat.is_empty() and selection(c.origin_feat) == {"feat_id": feat_id, "parameter": parameter}: return true
	for choice in c.feature_choices.values():
		if not choice is Array: continue
		for picked in choice:
			var text := str(picked)
			if text.begins_with(PREFIX + feat_id + "|") and text.trim_prefix(PREFIX + feat_id + "|") == parameter: return true
	return false

## Save check: chosen feats exist, fit their slot and are not duplicated.
static func saved_error(dto: Dictionary) -> String:
	var origin: Variant = dto.get("origin_feat", "")
	if not origin is String: return "Origin feat is invalid"
	if not origin.is_empty() and str(DataLoader.get_feat(str(selection(origin).feat_id)).get("category", "")) != "origin": return "Origin feat '%s' is unknown or not an Origin feat" % origin
	var level := int(dto.get("level", 1))
	var seen := {}
	for id in DataLoader.get_race(str(dto.get("race_id", ""))).get("feats", []): seen[str(id)] = true
	var choices: Variant = dto.get("feature_choices", {})
	var picks := _chosen_records(origin, choices)
	for picked in picks:
		var feat_id := str(picked.get("feat_id", ""))
		var parameter := str(picked.get("parameter", ""))
		var feat := DataLoader.get_feat(feat_id)
		if feat.is_empty(): return "Chosen feat '%s' is unknown" % feat_id
		var pre: Dictionary = feat.get("prerequisite", {})
		if level < int(pre.get("level", 1)): return "Chosen feat '%s' needs a higher level" % feat_id
		var saved_levels: Variant = dto.get("class_levels", {str(dto.get("class_id", "")): level})
		if not saved_levels is Dictionary: return "Chosen feat class levels are invalid"
		if saved_levels.is_empty(): saved_levels = {str(dto.get("class_id", "")): level}
		for class_id in pre.get("class_levels", {}):
			if int(saved_levels.get(str(class_id), 0)) < int(pre.class_levels[class_id]): return "Chosen feat '%s' class prerequisite is not met" % feat_id
		if pre.has("features_any"):
			var has_required := false
			for feature_id in pre.features_any:
				if _saved_has_feature(dto, str(feature_id)): has_required = true
			if not has_required: return "Chosen feat '%s' feature prerequisite is not met" % feat_id
		var parameters: Array = feat.get("repeatable_parameter_options", [])
		if not parameters.is_empty() and parameter not in parameters: return "Chosen feat '%s' repeat parameter is invalid" % feat_id
		if parameters.is_empty() and not parameter.is_empty(): return "Chosen feat '%s' has an unexpected repeat parameter" % feat_id
		if pre.has("abilities_any"):
			var saved_scores: Variant = dto.get("ability_scores", {})
			if not saved_scores is Dictionary: return "Chosen feat ability scores are invalid"
			for value in saved_scores.values():
				if not (value is int or value is float) or not is_finite(float(value)) or float(value) != floorf(float(value)): return "Chosen feat ability scores are invalid"
			var scores := AbilityScores.new()
			scores.from_dict(saved_scores) # The saved permanent scores, without projected/item bonuses.
			var met := false
			for ability in pre.abilities_any:
				if scores.get_permanent_score(str(ability)) >= int(pre.abilities_any[ability]): met = true
			if not met: return "Chosen feat '%s' ability prerequisite is not met" % feat_id
		var identity := feat_id + ("|" + parameter if not parameter.is_empty() else "")
		if (not bool(feat.get("repeatable", false)) and seen.has(feat_id)) or (not parameters.is_empty() and seen.has(identity)): return "Feat '%s' is taken more than once" % feat_id
		seen[feat_id] = true
		seen[identity] = true
	return ""

static func _chosen_records(origin_feat: String, feature_choices: Variant) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not origin_feat.is_empty(): out.append(selection(origin_feat))
	if feature_choices is Dictionary:
		for value in feature_choices.values():
			if not value is Array or value.size() != 1 or not value[0] is String or not str(value[0]).begins_with(PREFIX): continue
			out.append(selection(str(value[0]).trim_prefix(PREFIX)))
	return out

static func _saved_has_feature(dto: Dictionary, required_id: String) -> bool:
	for feature in FeatureModeRules.declared_features(dto):
		if str(feature.get("id", "")) == required_id: return true
	return false

static func selection(value: String) -> Dictionary:
	var parts := value.split("|", true)
	if parts.size() > 2 or parts[0].is_empty() or (parts.size() == 2 and parts[1].is_empty()): return {"feat_id": "", "parameter": ""}
	return {"feat_id": str(parts[0]), "parameter": str(parts[1]) if parts.size() == 2 else ""}

static func label(value: String) -> String:
	var picked := selection(value)
	var name := str(DataLoader.get_feat(picked.feat_id).get("name", picked.feat_id))
	return name + (" (%s)" % str(picked.parameter).capitalize() if not str(picked.parameter).is_empty() else "")
