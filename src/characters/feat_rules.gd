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
	if str(data.get("category", "")) not in CATEGORIES: return "Feat category must be origin, general, fighting_style or epic_boon"
	if data.has("repeatable") and not data.repeatable is bool: return "Feat repeatable must be a boolean"
	if bool(data.get("repeatable", false)) and not data.get("features", []).is_empty(): return "A repeatable feat cannot own mode/upgrade features (their ids would collide)"
	var pre: Variant = data.get("prerequisite", {})
	if not pre is Dictionary: return "Feat prerequisite must be an object"
	for key in pre:
		if str(key) not in ["level", "abilities_any"]: return "Feat prerequisite supports only level and abilities_any"
	if pre.has("level") and not FeatureModeRules._int(pre.level, 1, 20): return "Feat prerequisite level must be 1-20"
	if pre.has("abilities_any"):
		var any: Variant = pre.abilities_any
		if not any is Dictionary or any.is_empty(): return "Feat abilities_any must map abilities to minimum scores"
		for ability in any:
			if str(ability) not in AbilityScores.ABILITIES or not FeatureModeRules._int(any[ability], 1, 30): return "Feat abilities_any must map abilities to minimum scores"
	return ""

## Feats owned through choices: the creation origin feat and level-up feat picks.
static func chosen(origin_feat: String, feature_choices: Variant) -> Array[String]:
	var out: Array[String] = []
	if not origin_feat.is_empty(): out.append(origin_feat)
	if feature_choices is Dictionary:
		for id in feature_choices:
			var picked: Variant = feature_choices[id]
			if picked is Array and picked.size() == 1 and picked[0] is String and str(picked[0]).begins_with(PREFIX): out.append(str(picked[0]).trim_prefix(PREFIX))
	return out

static func owned(c: Character) -> Array[String]:
	var out: Array[String] = []
	for id in DataLoader.get_race(c.race_id).get("feats", []): out.append(str(id))
	out.append_array(chosen(c.origin_feat, c.feature_choices))
	return out

## Why this feat cannot be taken now ("" when it can). category="" means any.
static func eligibility_error(c: Character, feat_id: String, category: String) -> String:
	var feat := DataLoader.get_feat(feat_id)
	if feat.is_empty(): return "Unknown feat."
	if not category.is_empty() and str(feat.get("category", "")) != category: return "%s is not a %s feat." % [feat.get("name", feat_id), category.replace("_", " ")]
	if not bool(feat.get("repeatable", false)) and feat_id in owned(c): return "You already have %s." % feat.get("name", feat_id)
	var pre: Dictionary = feat.get("prerequisite", {})
	if c.level < int(pre.get("level", 1)): return "%s requires level %d." % [feat.get("name", feat_id), int(pre.level)]
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
		if eligibility_error(c, str(id), category).is_empty(): out.append(str(id))
	return out

## Character creation: the Origin feat, once, before the character joins the party.
static func choose_origin(c: Character, feat_id: String) -> Dictionary:
	if not c.origin_feat.is_empty(): return {"success": false, "message": "An Origin feat is already chosen."}
	var error := eligibility_error(c, feat_id, "origin")
	if not error.is_empty(): return {"success": false, "message": error}
	c.origin_feat = feat_id
	OwnedFeatureSources.sync(c)
	return {"success": true, "message": "%s gained." % DataLoader.get_feat(feat_id).get("name", feat_id)}

## Level-up: spend one pending Ability Score Improvement on a feat instead.
static func choose_level_feat(c: Character, feat_id: String) -> Dictionary:
	var pending := ClassProgression.pending_improvements(c)
	if pending.is_empty(): return {"success": false, "message": "No Ability Score Improvement is waiting."}
	var error := eligibility_error(c, feat_id, "")
	if not error.is_empty(): return {"success": false, "message": error}
	c.feature_choices[pending[0]] = [PREFIX + feat_id]
	if c.class_id == "fighter": c.fighter_training["asi_spent"] = int(c.fighter_training.get("asi_spent", 0)) + 1
	OwnedFeatureSources.sync(c)
	return {"success": true, "message": "%s gained." % DataLoader.get_feat(feat_id).get("name", feat_id)}

## Save check: chosen feats exist, fit their slot and are not duplicated.
static func saved_error(dto: Dictionary) -> String:
	var origin: Variant = dto.get("origin_feat", "")
	if not origin is String: return "Origin feat is invalid"
	if not origin.is_empty() and str(DataLoader.get_feat(origin).get("category", "")) != "origin": return "Origin feat '%s' is unknown or not an Origin feat" % origin
	var level := int(dto.get("level", 1))
	var seen := {}
	for id in DataLoader.get_race(str(dto.get("race_id", ""))).get("feats", []): seen[str(id)] = true
	var choices: Variant = dto.get("feature_choices", {})
	var picks := chosen(origin, choices)
	for feat_id in picks:
		var feat := DataLoader.get_feat(feat_id)
		if feat.is_empty(): return "Chosen feat '%s' is unknown" % feat_id
		if level < int(feat.get("prerequisite", {}).get("level", 1)): return "Chosen feat '%s' needs a higher level" % feat_id
		if seen.has(feat_id) and not bool(feat.get("repeatable", false)): return "Feat '%s' is taken more than once" % feat_id
		seen[feat_id] = true
	return ""
