## S-103: a declared mode chosen at a rest or activation boundary.
## The selected mode owns its grants; choosing again replaces them. Permanent
## progression choices stay in feature_choices and never pass through here.
class_name FeatureModeRules
extends RefCounted

const BOUNDARIES := ["rest", "activation"]
const RESTS := ["short_rest", "long_rest"]
const END_REASONS := ["short_rest", "long_rest", "zero_hp", "incapacitated"]
const DICE := ["d4", "d6", "d8", "d10", "d12"]
const RULE_KEYS := ["id", "name", "type", "description", "boundary", "rest", "modes", "uses", "uses_per", "duration_seconds", "die", "targets", "end_on", "allow_reselect", "source_instance_id"]
const STATE_KEYS := ["mode", "open", "active", "remaining_seconds", "activation_serial", "rolled", "recipients"]

static func _int(v: Variant, lo: int, hi: int) -> bool:
	return (v is int or v is float) and is_finite(float(v)) and float(v) == floorf(float(v)) and int(v) >= lo and int(v) <= hi

static func validate_rule(f: Variant) -> String:
	if not f is Dictionary: return "mode_choice must be an object"
	for key in f:
		if str(key) not in RULE_KEYS: return "mode_choice has unknown field '%s'" % key
	if str(f.get("boundary", "")) not in BOUNDARIES: return "mode_choice boundary must be rest or activation"
	var modes: Variant = f.get("modes")
	if not modes is Array or modes.size() < 2 or modes.size() > 6: return "mode_choice requires two to six modes"
	var seen := {}
	for mode in modes:
		if not mode is Dictionary or mode.size() != 2 or not mode.get("id", "") is String or str(mode.get("id", "")).is_empty() or seen.has(mode.id): return "mode_choice modes require unique ids and benefits"
		var benefit_error := SourceBenefitRules.benefits_error(mode.get("benefits"))
		if not benefit_error.is_empty(): return "mode '%s': %s" % [mode.id, benefit_error]
		seen[mode.id] = true
	if f.boundary == "rest":
		if str(f.get("rest", "")) not in RESTS: return "rest mode_choice requires rest short_rest or long_rest"
		for key in ["uses", "uses_per", "duration_seconds", "die", "targets", "end_on", "allow_reselect"]:
			if f.has(key): return "rest mode_choice cannot declare activation field '%s'" % key
		return ""
	if f.has("rest"): return "activation mode_choice cannot declare rest"
	if not _int(f.get("uses"), 1, 20) or str(f.get("uses_per", "")) not in RESTS: return "activation mode_choice requires uses 1-20 and uses_per short_rest or long_rest"
	if not _int(f.get("duration_seconds"), 6, 86400): return "activation mode_choice requires duration_seconds 6-86400"
	if f.has("die") and str(f.die) not in DICE: return "activation mode_choice die must be d4-d12"
	if f.has("targets") and not _int(f.targets, 1, 6): return "activation mode_choice targets must be 1-6"
	if f.has("allow_reselect") and not f.allow_reselect is bool: return "allow_reselect must be a boolean"
	return end_on_error(f.get("end_on", []))

static func end_on_error(value: Variant) -> String:
	if not value is Array or value.size() > END_REASONS.size(): return "end_on must be an array of end reasons"
	var seen := {}
	for reason in value:
		if not reason is String or reason not in END_REASONS or seen.has(reason): return "end_on contains an unknown or repeated reason"
		seen[reason] = true
	return ""

static func rule(actor: Character, feature_id: String) -> Dictionary:
	var feature := actor.get_feature(feature_id)
	if feature.get("type", "") != "mode_choice": return {}
	return RuleUpgradeRules.effective(actor, feature)

static func _mode(r: Dictionary, mode_id: String) -> Dictionary:
	for mode in r.get("modes", []):
		if mode.id == mode_id: return mode
	return {}

static func _receipt(ok: bool, reason: String, extra: Dictionary = {}) -> Dictionary:
	var out := {"success": ok, "reason": reason}
	out.merge(extra)
	return out

## Rest boundary: choose while open. Activation boundary: reselect while active if declared.
static func choose(actor: Character, feature_id: String, mode_id: String) -> Dictionary:
	var r := rule(actor, feature_id)
	if r.is_empty(): return _receipt(false, "not_owned")
	if _mode(r, mode_id).is_empty(): return _receipt(false, "unknown_mode")
	var state: Dictionary = actor.feature_modes.get(feature_id, {})
	var previous := str(state.get("mode", ""))
	if r.boundary == "rest":
		if not bool(state.get("open", true)): return _receipt(false, "boundary_closed")
		actor.feature_modes[feature_id] = {"mode": mode_id, "open": false}
		return _receipt(true, "chosen", {"replaced": previous})
	refresh(actor)
	state = actor.feature_modes.get(feature_id, {})
	if not bool(state.get("active", false)): return _receipt(false, "not_active")
	if not bool(r.get("allow_reselect", false)): return _receipt(false, "boundary_closed")
	if previous == mode_id: return _receipt(false, "same_mode")
	state["mode"] = mode_id # Parent use, remaining time and roll are unchanged.
	return _receipt(true, "reselected", {"replaced": previous})

## Spend the parent use once and choose the mode for this activation.
static func activate(actor: Character, feature_id: String, mode_id: String, recipients: Array = []) -> Dictionary:
	var r := rule(actor, feature_id)
	if r.is_empty() or r.boundary != "activation": return _receipt(false, "not_activation")
	if _mode(r, mode_id).is_empty(): return _receipt(false, "unknown_mode")
	refresh(actor)
	if bool(actor.feature_modes.get(feature_id, {}).get("active", false)): return _receipt(false, "already_active")
	if recipients.is_empty(): recipients = [actor]
	var ids: Array = []
	for recipient in recipients:
		if not recipient is Character or recipient.character_id in ids or recipient.is_dead(): return _receipt(false, "invalid_recipient")
		ids.append(recipient.character_id)
	if ids.size() > int(r.get("targets", 1)): return _receipt(false, "too_many_targets")
	if "zero_hp" in r.get("end_on", []) and actor.current_hp <= 0: return _receipt(false, "end_condition_met")
	if not actor.use_feature(feature_id): return _receipt(false, "no_uses")
	var serial := int(actor.feature_modes.get(feature_id, {}).get("activation_serial", 0)) + 1
	var rolled := 0
	if r.has("die"):
		rolled = Dice.roll(int(str(r.die).trim_prefix("d")))
		for recipient in recipients:
			recipient.temp_hp = maxi(recipient.temp_hp, rolled)
	actor.feature_modes[feature_id] = {"mode": mode_id, "active": true, "remaining_seconds": int(r.duration_seconds), "activation_serial": serial, "rolled": rolled, "recipients": ids}
	return _receipt(true, "activated", {"die": str(r.get("die", "")), "rolled": rolled, "recipients": ids.duplicate(), "activation_serial": serial})

static func end(actor: Character, feature_id: String, reason: String) -> Dictionary:
	var state: Dictionary = actor.feature_modes.get(feature_id, {})
	if not bool(state.get("active", false)): return {}
	var r := rule(actor, feature_id)
	if reason not in ["duration", "dismissed"] and reason not in r.get("end_on", []): return {}
	var ended := str(state.mode)
	state["active"] = false
	state["mode"] = ""
	state["remaining_seconds"] = 0
	return {"feature_id": feature_id, "mode": ended, "reason": reason, "activation_serial": int(state.activation_serial)}

## End predicates are read from the live (possibly upgraded) rule.
static func refresh(actor: Character) -> Array:
	var ended: Array = []
	for feature_id in actor.feature_modes.keys():
		if not bool(actor.feature_modes[feature_id].get("active", false)): continue
		var e := {}
		if actor.current_hp <= 0:
			e = end(actor, feature_id, "zero_hp")
		if e.is_empty() and actor.has_condition("incapacitated"):
			e = end(actor, feature_id, "incapacitated")
		if not e.is_empty():
			ended.append(e)
	return ended

static func advance_time(actor: Character, seconds: int) -> void:
	if seconds <= 0: return
	for feature_id in actor.feature_modes.keys():
		var state: Dictionary = actor.feature_modes[feature_id]
		if not bool(state.get("active", false)): continue
		state.remaining_seconds = int(state.remaining_seconds) - seconds
		if int(state.remaining_seconds) <= 0: end(actor, feature_id, "duration")

static func on_rest(actor: Character, rest_kind: String) -> void:
	for feature_id in actor.feature_modes.keys():
		end(actor, feature_id, rest_kind)
	for feature in actor.features:
		if feature.get("type", "") == "mode_choice" and feature.get("boundary", "") == "rest" and feature.get("rest", "") == rest_kind and actor.feature_modes.has(feature.id):
			actor.feature_modes[feature.id]["open"] = true # The prior mode keeps its grants until replaced.

static func carriers(actor: Character) -> Array[Dictionary]:
	refresh(actor)
	var out: Array[Dictionary] = []
	for feature_id in actor.feature_modes:
		var state: Dictionary = actor.feature_modes[feature_id]
		var r := rule(actor, str(feature_id))
		var mode := _mode(r, str(state.get("mode", "")))
		if mode.is_empty() or (r.boundary == "activation" and not bool(state.get("active", false))): continue
		var identity := "mode:" + JSON.stringify([actor.character_id, feature_id, mode.id, int(state.get("activation_serial", 0))])
		out.append({"source_instance_id": identity, "definition_id": str(mode.id), "benefits": mode.benefits})
	return out

static func _declared(data: Dictionary, feature_id: String) -> Dictionary:
	var class_data := DataLoader.get_character_class(str(data.get("class_id", "")))
	for lvl in class_data.get("features_by_level", {}):
		if int(lvl) > int(data.get("level", 1)): continue
		for feature in class_data.features_by_level[lvl]:
			if feature.get("id", "") == feature_id and feature.get("type", "") == "mode_choice": return feature
	return {}

static func saved_error(data: Dictionary) -> String:
	var modes: Variant = data.get("feature_modes", {})
	if not modes is Dictionary or modes.size() > 16: return "feature modes are invalid"
	for feature_id in modes:
		var s: Variant = modes[feature_id]
		var f := _declared(data, str(feature_id))
		if f.is_empty() or not s is Dictionary: return "feature mode references an unowned rule"
		for key in s:
			if str(key) not in STATE_KEYS: return "feature mode has unknown field"
		var mode := str(s.get("mode", ""))
		if not mode.is_empty() and _mode(f, mode).is_empty(): return "feature mode is not declared"
		if f.boundary == "rest":
			if s.size() != 2 or not s.get("open") is bool or (mode.is_empty() and not s.open): return "rest feature mode is invalid"
			continue
		if not s.get("active") is bool or not _int(s.get("remaining_seconds"), 0, int(f.duration_seconds)) or not _int(s.get("activation_serial"), 1, 1000000) or not _int(s.get("rolled"), 0, 12) or not s.get("recipients") is Array or s.recipients.size() > 6:
			return "activation feature mode is invalid"
		if s.active == mode.is_empty() or (s.active and int(s.remaining_seconds) < 1): return "activation feature mode is invalid"
	return ""

static func restore(actor: Character, data: Dictionary) -> void:
	actor.feature_modes = data.get("feature_modes", {}).duplicate(true) if data.get("feature_modes", {}) is Dictionary and saved_error(data).is_empty() else {}
	for state in actor.feature_modes.values():
		for key in ["remaining_seconds", "activation_serial", "rolled"]:
			if state.has(key): state[key] = int(state[key])
