## S-084: data-only parameter upgrades to an owned rule. The catalog record is
## never edited; effective() returns an upgraded copy derived from owned
## upgrade features each time, so reloads cannot stack a change twice.
class_name RuleUpgradeRules
extends RefCounted

const RULE_KEYS := ["id", "name", "type", "description", "rule", "changes", "exclusive_group", "source_instance_id"]
const PARAMETERS := ["uses", "targets", "die", "end_on", "modes", "switch_events", "attack_count", "base_ac"]
## Batch 070 (S-084/S-085): consumers outside mode rules. attack_count sets the
## extra_attack count of the target passive rule; base_ac replaces the target's
## unarmored_defense calculation. Both are alternatives (SRD 5.2.1 "Only One Base
## AC"; Extra Attack from several features doesn't stack), so they require an
## exclusive_group and the owner chooses one; no engine default supplies a value.
const CONSUMER_PARAMETERS := ["attack_count", "base_ac"]
const ABILITIES := ["STR", "DEX", "CON", "INT", "WIS", "CHA"]
const MIN_MODES := 2

static func validate_rule(f: Variant, declared_ids: Dictionary = {}) -> String:
	if not f is Dictionary: return "rule_upgrade must be an object"
	for key in f:
		if str(key) not in RULE_KEYS: return "rule_upgrade has unknown field '%s'" % key
	var target := str(f.get("rule", ""))
	if target.is_empty() or target == str(f.get("id", "")): return "rule_upgrade requires another rule id"
	var consumer_only: bool = f.get("changes") is Dictionary and not f.changes.is_empty() and f.changes.keys().all(func(k): return str(k) in CONSUMER_PARAMETERS)
	# Batch 070: a consumer upgrade names a passive rule its owner already has (e.g. a class Extra Attack), never a local item rule.
	if not declared_ids.is_empty() and not declared_ids.has(target) and not consumer_only: return "rule_upgrade targets an undeclared rule '%s'" % target
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
			"switch_events":
				var op := str(c.keys()[0])
				if op not in ["add", "remove"] or not FeatureModeRules.switch_events_error(c[op]).is_empty() or c[op].is_empty(): return "rule_upgrade switch_events requires add or remove events"
			"modes":
				var op := str(c.keys()[0])
				if op == "add":
					if not c.add is Array or c.add.is_empty() or c.add.size() > 4 or not FeatureModeRules.modes_list_error(c.add).is_empty(): return "rule_upgrade modes add requires one to four valid modes"
				elif op == "remove":
					if not c.remove is Array or c.remove.is_empty() or c.remove.size() > 4 or c.remove.any(func(m): return not m is String or str(m).is_empty()): return "rule_upgrade modes remove requires mode ids"
				else: return "rule_upgrade modes requires add or remove"
			"attack_count":
				if not c.has("set") or not FeatureModeRules._int(c.get("set"), 1, 3): return "rule_upgrade attack_count requires set 1-3"
			"base_ac":
				var formula_error := base_ac_error(c.get("set"))
				if not formula_error.is_empty(): return formula_error
	var consumers: Array = changes.keys().filter(func(k): return str(k) in CONSUMER_PARAMETERS)
	if not consumers.is_empty():
		if consumers.size() != changes.size(): return "rule_upgrade attack_count/base_ac cannot be mixed with mode changes"
		if not f.has("exclusive_group"): return "rule_upgrade attack_count/base_ac requires an exclusive_group (choose one)"
	if f.has("exclusive_group") and (not f.exclusive_group is String or str(f.exclusive_group).is_empty()): return "exclusive_group must be a nonempty string"
	return ""

## A data-authored base AC calculation: base + listed ability modifiers, and
## whether a shield is allowed. Every field is required.
static func base_ac_error(value: Variant) -> String:
	if not value is Dictionary or value.size() != 3 or not value.has("base") or not value.has("abilities") or not value.has("allows_shield"): return "rule_upgrade base_ac requires set {base, abilities, allows_shield}"
	if not FeatureModeRules._int(value.base, 0, 20): return "rule_upgrade base_ac base must be 0-20"
	if not value.abilities is Array or value.abilities.is_empty() or value.abilities.size() > 3: return "rule_upgrade base_ac abilities must list one to three abilities"
	var seen := {}
	for a in value.abilities:
		if not a is String or a not in ABILITIES or seen.has(a): return "rule_upgrade base_ac abilities must be unique ability ids"
		seen[a] = true
	if not value.allows_shield is bool: return "rule_upgrade base_ac allows_shield must be true or false"
	return ""

static func _effect_of(actor: Character, feature: Dictionary, effect_type: String) -> Dictionary:
	for effect in actor._feature_effects(feature):
		if str(effect.get("type", "")) == effect_type: return effect
	return {}

## Batch 070 (S-084): the Extra Attack count after owned attack_count upgrades.
## The class host already folds non-stacking sources into actor.extra_attacks;
## an applied upgrade replaces its target rule's own count, so the change is the
## difference. Merged/suppressed copies apply nothing (upgrades_for gate).
static func extra_attacks(actor: Character) -> int:
	if actor == null: return 0
	var total := actor.extra_attacks
	var seen := {}
	for feature in actor.features:
		var id := str(feature.get("id", ""))
		var effect := _effect_of(actor, feature, "extra_attack")
		if effect.is_empty() or seen.has(id) or not OwnedFeatureSources.copy_active(actor, feature): continue
		seen[id] = true
		for upgrade in _resolve(actor, id).applying:
			if upgrade.changes.has("attack_count"): total += int(upgrade.changes.attack_count.set) - int(effect.get("count", 1))
	return maxi(0, total)

## Batch 070 (S-085): the chosen base AC alternative for an unarmored_defense
## rule, or {} when none applies. Returns {base, abilities, allows_shield, upgrade}.
static func base_ac_formula(actor: Character, feature: Dictionary) -> Dictionary:
	if actor == null or not OwnedFeatureSources.copy_active(actor, feature): return {}
	for upgrade in _resolve(actor, str(feature.get("id", ""))).applying:
		if upgrade.changes.has("base_ac"):
			var out: Dictionary = upgrade.changes.base_ac.set.duplicate(true)
			out["upgrade"] = str(upgrade.id)
			return out
	return {}

## True when an owned upgrade has exclusive options for this passive consumer.
static func consumer_target(actor: Character, feature: Dictionary) -> bool:
	if feature.get("type", "") != "passive": return false
	if _effect_of(actor, feature, "extra_attack").is_empty() and _effect_of(actor, feature, "unarmored_defense").is_empty(): return false
	return upgrades_for(actor, str(feature.get("id", ""))).any(func(u): return u.changes.keys().any(func(k): return str(k) in CONSUMER_PARAMETERS))

static func _key(rule_id: String, group: String) -> String:
	return rule_id + "|" + group

## S-085: owned upgrades in one exclusive group are alternatives, never stacked.
## Returns the applying upgrades plus {group: {chosen, options}}.
static func _resolve(actor: Character, rule_id: String) -> Dictionary:
	var applying: Array = []
	var groups := {}
	for upgrade in upgrades_for(actor, rule_id):
		var group := str(upgrade.get("exclusive_group", ""))
		if group.is_empty(): applying.append(upgrade)
		else:
			if not groups.has(group): groups[group] = []
			groups[group].append(upgrade)
	var alternatives := {}
	for group in groups:
		var options: Array = groups[group]
		var chosen: Dictionary = options[0]
		var wanted := str(actor.rule_alternatives.get(_key(rule_id, group), ""))
		for option in options:
			if str(option.id) == wanted: chosen = option
		applying.append(chosen)
		alternatives[group] = {"chosen": str(chosen.id), "options": options.map(func(o): return str(o.id))}
	applying.sort_custom(func(x, y): return str(x.id) < str(y.id))
	return {"applying": applying, "alternatives": alternatives}

## Choose an owned alternative; refused while the upgraded activation is active.
static func choose_alternative(actor: Character, rule_id: String, group: String, upgrade_id: String) -> bool:
	var resolved := _resolve(actor, rule_id)
	if not resolved.alternatives.has(group) or upgrade_id not in resolved.alternatives[group].options: return false
	if bool(actor.feature_modes.get(rule_id, {}).get("active", false)): return false
	actor.rule_alternatives[_key(rule_id, group)] = upgrade_id
	# Review R1: a lower new maximum clamps held uses now, exactly as a reload would.
	var pool := str(actor.get_feature(rule_id).get("resource_id", rule_id))
	if actor.feature_uses.has(pool): actor.feature_uses[pool] = clampi(int(actor.feature_uses[pool]), 0, maxi(0, actor.get_feature_max_uses(pool)))
	if not actor._base_ac_alternative().is_empty(): actor._recalculate_ac() # Batch 070: a base AC alternative takes effect now, as a reload would.
	return true

static func saved_error(data: Dictionary) -> String:
	var choices: Variant = data.get("rule_alternatives", {})
	if not choices is Dictionary or choices.size() > 16: return "rule alternatives are invalid"
	var features := FeatureModeRules.declared_features(data)
	for key in choices:
		var parts := str(key).split("|")
		var found := false
		for feature in features:
			if parts.size() == 2 and feature.get("type", "") == "rule_upgrade" and feature.get("rule", "") == parts[0] and feature.get("exclusive_group", "") == parts[1] and feature.get("id", "") == choices[key]: found = true
		if not found: return "rule alternative is not an owned option"
	return ""

static func restore(actor: Character, data: Dictionary) -> void:
	var choices: Variant = data.get("rule_alternatives", {})
	actor.rule_alternatives = choices.duplicate(true) if choices is Dictionary and saved_error(data).is_empty() else {}

## Review 050 R1: the owned view counts a suppressed or merged copy's upgrades.
## Activation and benefits stay gated; only end predicates and dawn maxima use it.
static var _owned_view := false

static func owned_view(fn: Callable) -> Variant:
	var prior := _owned_view
	_owned_view = true
	var out: Variant = fn.call()
	_owned_view = prior
	return out

static func upgrades_for(actor: Character, rule_id: String) -> Array:
	var by_id := {}
	for feature in actor.features:
		if feature.get("type", "") == "rule_upgrade" and feature.get("rule", "") == rule_id and (_owned_view or OwnedFeatureSources.copy_active(actor, feature)): # Batch 050: suppressed "features" covers upgrades too.
			by_id[str(feature.id)] = feature # One owned upgrade applies once.
	var ids := by_id.keys()
	ids.sort()
	return ids.map(func(id): return by_id[id])

static func effective(actor: Character, feature: Dictionary) -> Dictionary:
	if actor == null or feature.is_empty(): return feature
	var resolved := _resolve(actor, str(feature.get("id", "")))
	var upgrades: Array = resolved.applying
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
		if changes.has("switch_events"):
			var events: Array = out.get("switch_events", []).duplicate()
			for e in changes.switch_events.get("add", []):
				if e not in events: events.append(e)
			for e in changes.switch_events.get("remove", []):
				events.erase(e)
			out["switch_events"] = events
		if changes.has("modes"):
			var modes: Array = out.get("modes", []).duplicate(true)
			for mode in changes.modes.get("add", []):
				if not modes.any(func(m): return m.id == mode.id): modes.append(mode.duplicate(true))
			out["modes"] = modes
		applied.append(str(upgrade.id))
	# Removals run after every addition so upgrade order cannot matter.
	for upgrade in upgrades:
		for mode_id in upgrade.changes.get("modes", {}).get("remove", []):
			var kept: Array = out.get("modes", []).filter(func(m): return m.id != mode_id)
			if kept.size() >= MIN_MODES: out["modes"] = kept # Never fewer than two legal modes.
	out["applied_upgrades"] = applied
	if not resolved.alternatives.is_empty(): out["alternatives"] = resolved.alternatives
	return out
