## Batch 049 (card Q-20261020-154337-209c, Reviewer F1): species, the feats a
## species grants, and exact equipped/attuned item copies acquire declared
## mode_choice / rule_upgrade features through one resolver. The same resolver
## serves live actors and save DTOs, so reload rebuilds exactly what is owned
## and never stacks a source twice. Class/subclass features keep their own host.
class_name OwnedFeatureSources
extends RefCounted

const TYPES := ["mode_choice", "rule_upgrade"]
const MAX_FEATURES := 4
const MAX_FEATS := 4

static func definition_error(data: Dictionary, content_type: String) -> String:
	if content_type == "race" and data.has("feats"):
		var feats: Variant = data.feats
		if not feats is Array or feats.size() > MAX_FEATS: return "Species feats must be an array of up to four feat ids"
		var seen := {}
		for feat_id in feats:
			if not feat_id is String or str(feat_id).is_empty() or seen.has(feat_id): return "Species feats need unique feat ids"
			seen[feat_id] = true
	if not data.has("features"): return ""
	var features: Variant = data.features
	if not features is Array: return "%s features must be an array" % content_type.capitalize()
	var ids := {}
	var owned: Array = []
	for feature in features:
		if feature is Dictionary and str(feature.get("type", "")) in TYPES: owned.append(feature)
		elif content_type != "race": return "%s features support only mode_choice and rule_upgrade" % content_type.capitalize()
	if owned.size() > MAX_FEATURES: return "%s declares more than four mode/upgrade features" % content_type.capitalize()
	for feature in owned:
		var id := str(feature.get("id", ""))
		if id.is_empty() or "@" in id or ids.has(id): return "%s features need unique ids without '@'" % content_type.capitalize()
		ids[id] = true
	for feature in owned:
		var error := FeatureModeRules.validate_rule(feature) if feature.type == "mode_choice" else RuleUpgradeRules.validate_rule(feature, ids if content_type == "item" else {})
		if feature.has("source_instance_id"): error = "feature cannot declare source_instance_id"
		if not error.is_empty(): return "Feature '%s': %s" % [feature.get("id", ""), error]
	return ""

static func _typed(list: Variant) -> Array:
	var out: Array = []
	if list is Array:
		for feature in list:
			if feature is Dictionary and str(feature.get("type", "")) in TYPES: out.append(feature.duplicate(true))
	return out

## An item's features belong to one exact copy: ids are namespaced by the
## instance id and its own upgrades follow that namespace.
static func item_features(item: Dictionary, instance_id: String) -> Array:
	var local := {}
	for feature in _typed(item.get("features", [])): local[str(feature.id)] = true
	var out: Array = []
	for feature in _typed(item.get("features", [])):
		feature["id"] = "%s@%s" % [feature.id, instance_id]
		feature["source_instance_id"] = instance_id
		if feature.type == "rule_upgrade" and local.has(str(feature.rule)): feature["rule"] = "%s@%s" % [feature.rule, instance_id]
		out.append(feature)
	return out

## Features owned by species, species-granted feats and the given equipped
## copies. records/equipped_ids come from a live inventory or a save DTO.
static func declared(race_id: String, character_id: String, records: Dictionary, equipped_ids: Array) -> Array:
	var race := DataLoader.get_race(race_id)
	var out := _typed(race.get("features", []))
	for feat_id in race.get("feats", []):
		out.append_array(_typed(DataLoader.get_feat(str(feat_id)).get("features", [])))
	var ids: Array = equipped_ids.map(func(id): return str(id))
	ids.sort()
	var seen := {}
	for id in ids:
		var record: Variant = records.get(id, {})
		if seen.has(id) or not record is Dictionary: continue
		var definition_id := str(record.get("definition_id", ""))
		if seen.has("def:" + definition_id): continue # A second copy of one item never stacks its features.
		var item := DataLoader.get_item(definition_id)
		var state: Variant = record.get("state", {})
		if bool(item.get("requires_attunement", false)) and (not state is Dictionary or str(state.get("attuned_to", "")) != character_id): continue
		seen[id] = true
		if item.has("features"): seen["def:" + definition_id] = true
		out.append_array(item_features(item, id))
	return out

## Save-DTO view used by FeatureModeRules.declared_features for validation.
static func declared_in(data: Dictionary) -> Array:
	var inventory: Variant = data.get("inventory", {})
	var copies: Variant = inventory.get("copies", {}) if inventory is Dictionary else {}
	if not copies is Dictionary: copies = {}
	var records: Variant = copies.get("records", {})
	var equipped: Variant = copies.get("equipped", {})
	return declared(str(data.get("race_id", "")), str(data.get("character_id", "")), records if records is Dictionary else {}, equipped.values() if equipped is Dictionary else [])

## Rebuild the acquired features on a live actor. Called after restore and on
## every equip/attune change. Features whose source left end their saved mode
## state and alternatives; use pools stay keyed by source so re-acquiring the
## same copy cannot refill them. restoring=true never grants fresh uses.
static func sync(actor: Character, restoring: bool = false) -> Array:
	if actor == null or actor.inventory == null: return []
	var records: Dictionary = actor.inventory.copies.records
	# Read the copy ledger as-is: re-syncing mid-drop/destroy would resurrect the copy.
	var wanted := declared(actor.race_id, actor.character_id, actor.inventory.copies.records, actor.inventory.copies.equipped.values())
	# Review 049 R2: an item's spent uses belong to the copy, not the wearer.
	# A copy leaving this actor stamps its pool on the record, so a give, sell
	# or trade cannot hand over a refilled item.
	var wanted_ids := {}
	for feature in wanted: wanted_ids[str(feature.id)] = true
	for feature in actor.features:
		var fid := str(feature.get("id", ""))
		var copy := str(feature.get("source_instance_id", ""))
		if not actor.acquired_features.has(fid) or wanted_ids.has(fid) or copy.is_empty() or not records.get(copy) is Dictionary: continue
		var pool := str(feature.get("resource_id", fid))
		if feature.get("type", "") != "mode_choice" or not actor.feature_uses.has(pool): continue
		var state: Dictionary = records[copy].get("state", {})
		var held: Dictionary = state.get("feature_uses", {})
		held[pool] = maxi(0, int(actor.feature_uses[pool]))
		state["feature_uses"] = held
		records[copy]["state"] = state
	var kept: Array[Dictionary] = []
	var present := {}
	for feature in actor.features:
		if actor.acquired_features.has(str(feature.get("id", ""))): continue
		kept.append(feature)
		present[str(feature.get("id", ""))] = true
	var acquired := {}
	var added: Array = []
	for feature in wanted:
		var id := str(feature.id)
		if present.has(id): continue # One owner per id: a class grant or earlier source wins.
		present[id] = true
		kept.append(feature)
		acquired[id] = true
		if not actor.acquired_features.has(id): added.append(id)
	actor.features = kept
	actor.acquired_features = acquired
	for id in actor.feature_modes.keys():
		if not present.has(str(id)): actor.feature_modes.erase(id)
	for key in actor.rule_alternatives.keys():
		if not present.has(str(key).get_slice("|", 0)): actor.rule_alternatives.erase(key)
	for id in acquired:
		var feature := actor.get_feature(str(id))
		if feature.get("type", "") != "mode_choice" or feature.get("boundary", "") != "activation": continue
		var pool := str(feature.get("resource_id", id))
		var maximum := maxi(0, actor.get_feature_max_uses(pool))
		var copy := str(feature.get("source_instance_id", ""))
		var record: Variant = records.get(copy) if not copy.is_empty() else null
		if record is Dictionary and record.get("state", {}).get("feature_uses", {}).has(pool):
			# Review 049 R2: the copy's own stamped pool wins over this actor's ledger and a fresh grant.
			actor.feature_uses[pool] = clampi(int(record.state.feature_uses[pool]), 0, maximum)
			record.state.feature_uses.erase(pool)
			if record.state.feature_uses.is_empty(): record.state.erase("feature_uses")
		elif actor.feature_uses.has(pool) or restoring: actor.feature_uses[pool] = clampi(int(actor.feature_uses.get(pool, 0)), 0, maximum)
		else: actor.feature_uses[pool] = maximum
	return added

## Review 049 R1: a merged copy, or one whose "features" magic is suppressed or
## destroyed, keeps its owned rules and state but they grant and allow nothing.
static func copy_active(actor: Character, feature: Dictionary) -> bool:
	var copy := str(feature.get("source_instance_id", ""))
	if copy.is_empty(): return true
	return not ActorProjectionRules.merged(actor, copy) and MagicPropertyRules.active(actor, copy, "features")

## Review 049 R2: a copy's stamped pool names only its own namespaced activation
## modes and holds a whole number no larger than the item can ever grant.
static func record_error(record: Dictionary) -> String:
	var state: Variant = record.get("state", {})
	if not state is Dictionary or not state.has("feature_uses"): return ""
	var held: Variant = state.feature_uses
	if not held is Dictionary or held.is_empty() or held.size() > MAX_FEATURES: return "item feature uses are malformed"
	var item := DataLoader.get_item(str(record.get("definition_id", "")))
	var pools := {}
	for feature in item_features(item, str(record.get("instance_id", ""))):
		if feature.type == "mode_choice" and feature.get("boundary", "") == "activation": pools[str(feature.get("resource_id", feature.id))] = true
	for pool in held:
		var n: Variant = held[pool]
		if not pools.has(str(pool)) or not (n is int or n is float) or not is_finite(float(n)) or float(n) != floorf(float(n)) or int(n) < 0 or int(n) > 100: return "item feature uses name an unowned pool or an invalid count"
	return ""
