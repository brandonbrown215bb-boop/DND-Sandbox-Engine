## S-084: data-only parameter upgrades to an owned rule. The catalog record is
## never edited; effective() returns an upgraded copy derived from owned
## upgrade features each time, so reloads cannot stack a change twice.
class_name RuleUpgradeRules
extends RefCounted

const RULE_KEYS := ["id", "name", "type", "description", "rule", "changes", "source_instance_id"]
const PARAMETERS := ["uses", "targets", "die", "end_on"]

static func validate_rule(f: Variant, declared_ids: Dictionary = {}) -> String:
	if not f is Dictionary: return "rule_upgrade must be an object"
	for key in f:
		if str(key) not in RULE_KEYS: return "rule_upgrade has unknown field '%s'" % key
	var target := str(f.get("rule", ""))
	if target.is_empty() or target == str(f.get("id", "")): return "rule_upgrade requires another rule id"
	if not declared_ids.is_empty() and not declared_ids.has(target): return "rule_upgrade targets an undeclared rule '%s'" % target
	var changes: Variant = f.get("changes")
	if not changes is Dictionary or changes.is_empty(): return "rule_upgrade requires changes"
	for key in changes:
		var c: Variant = changes[key]
		if str(key) not in PARAMETERS or not c is Dictionary or c.size() != 1: return "rule_upgrade change '%s' is unsupported" % key
		match str(key):
			"uses", "targets":
				if not FeatureModeRules._int(c.get("add"), 1, 5): return "rule_upgrade %s requires add 1-5" % key
			"die":
				if str(c.get("set", "")) not in FeatureModeRules.DICE: return "rule_upgrade die requires set d4-d12"
			"end_on":
				var op := str(c.keys()[0])
				if op not in ["add", "remove"] or not FeatureModeRules.end_on_error(c[op]).is_empty() or c[op].is_empty(): return "rule_upgrade end_on requires add or remove reasons"
	return ""

static func upgrades_for(actor: Character, rule_id: String) -> Array:
	var by_id := {}
	for feature in actor.features:
		if feature.get("type", "") == "rule_upgrade" and feature.get("rule", "") == rule_id:
			by_id[str(feature.id)] = feature # One owned upgrade applies once.
	var ids := by_id.keys()
	ids.sort()
	return ids.map(func(id): return by_id[id])

static func effective(actor: Character, feature: Dictionary) -> Dictionary:
	if actor == null or feature.is_empty(): return feature
	var upgrades := upgrades_for(actor, str(feature.get("id", "")))
	if upgrades.is_empty(): return feature
	var out := feature.duplicate(true)
	var applied: Array = []
	for upgrade in upgrades:
		var changes: Dictionary = upgrade.changes
		if changes.has("uses"): out["uses"] = int(out.get("uses", 1)) + int(changes.uses.add)
		if changes.has("targets"): out["targets"] = int(out.get("targets", 1)) + int(changes.targets.add)
		if changes.has("die"): out["die"] = str(changes.die.set)
		if changes.has("end_on"):
			var reasons: Array = out.get("end_on", []).duplicate()
			for reason in changes.end_on.get("add", []):
				if reason not in reasons: reasons.append(reason)
			for reason in changes.end_on.get("remove", []):
				reasons.erase(reason)
			out["end_on"] = reasons
		applied.append(str(upgrade.id))
	out["applied_upgrades"] = applied
	return out
