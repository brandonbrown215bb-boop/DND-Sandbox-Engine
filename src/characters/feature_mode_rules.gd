## S-103: a declared mode chosen at a rest or activation boundary.
## The selected mode owns its grants; choosing again replaces them. Permanent
## progression choices stay in feature_choices and never pass through here.
class_name FeatureModeRules
extends RefCounted

const BOUNDARIES := ["rest", "activation"]
const RESTS := ["short_rest", "long_rest"]
const END_REASONS := ["short_rest", "long_rest", "zero_hp", "incapacitated"]
const DICE := ["d4", "d6", "d8", "d10", "d12"]
## S-104: declared events that open a one-use window to switch the active mode.
const SWITCH_EVENTS := ["hit", "turn_start"]
const RULE_KEYS := ["id", "name", "type", "description", "boundary", "rest", "modes", "uses", "uses_per", "duration_seconds", "die", "targets", "end_on", "allow_reselect", "switch_events", "source_instance_id", "recharge_while", "costs", "activation_seconds"]
const STATE_KEYS := ["mode", "open", "active", "remaining_seconds", "activation_serial", "rolled", "recipients", "event_serial", "window"]

static func _int(v: Variant, lo: int, hi: int) -> bool:
	return (v is int or v is float) and is_finite(float(v)) and float(v) == floorf(float(v)) and int(v) >= lo and int(v) <= hi

## allow_dawn: item copies may recover at dawn (SRD 5.2.1 p.206 "The Next Dawn").
static func validate_rule(f: Variant, allow_dawn: bool = false) -> String:
	if not f is Dictionary: return "mode_choice must be an object"
	for key in f:
		if str(key) not in RULE_KEYS: return "mode_choice has unknown field '%s'" % key
	if str(f.get("boundary", "")) not in BOUNDARIES: return "mode_choice boundary must be rest or activation"
	var modes: Variant = f.get("modes")
	if not modes is Array or modes.size() < 2 or modes.size() > 6: return "mode_choice requires two to six modes"
	var modes_error := modes_list_error(modes)
	if not modes_error.is_empty(): return modes_error
	if f.boundary == "rest":
		if str(f.get("rest", "")) not in RESTS: return "rest mode_choice requires rest short_rest or long_rest"
		for key in ["uses", "uses_per", "duration_seconds", "die", "targets", "end_on", "allow_reselect", "switch_events", "recharge_while", "costs", "activation_seconds"]:
			if f.has(key): return "rest mode_choice cannot declare activation field '%s'" % key
		return ""
	if f.has("switch_events") and not switch_events_error(f.switch_events).is_empty(): return switch_events_error(f.switch_events)
	return _activation_error(f, allow_dawn)

static func switch_events_error(value: Variant) -> String:
	if not value is Array or value.size() > SWITCH_EVENTS.size(): return "switch_events must be an array of hit or turn_start"
	var seen := {}
	for e in value:
		if not e is String or e not in SWITCH_EVENTS or seen.has(e): return "switch_events contains an unknown or repeated event"
		seen[e] = true
	return ""

static func modes_list_error(modes: Variant) -> String:
	var seen := {}
	for mode in modes:
		if not mode is Dictionary or mode.size() != 2 or not mode.get("id", "") is String or str(mode.get("id", "")).is_empty() or seen.has(mode.id): return "mode_choice modes require unique ids and benefits"
		var benefit_error := SourceBenefitRules.benefits_error(mode.get("benefits"))
		if not benefit_error.is_empty(): return "mode '%s': %s" % [mode.id, benefit_error]
		seen[mode.id] = true
	return ""

static func _activation_error(f: Dictionary, allow_dawn: bool = false) -> String:
	if f.has("rest"): return "activation mode_choice cannot declare rest"
	if not _int(f.get("uses"), 1, 20) or str(f.get("uses_per", "")) not in (RESTS + ["dawn"] if allow_dawn else RESTS): return "activation mode_choice requires uses 1-20 and uses_per short_rest or long_rest%s" % (" or dawn" if allow_dawn else "")
	# Batch 050 fix: an item's text may make dawn recharge depend on being worn or attuned.
	if f.has("recharge_while") and (not allow_dawn or str(f.get("uses_per", "")) != "dawn" or str(f.recharge_while) not in ["equipped", "attuned"]): return "recharge_while must be equipped or attuned on a dawn item power"
	if not _int(f.get("duration_seconds"), 6, 86400): return "activation mode_choice requires duration_seconds 6-86400"
	if f.has("die") and str(f.die) not in DICE: return "activation mode_choice die must be d4-d12"
	if f.has("targets") and not _int(f.targets, 1, 6): return "activation mode_choice targets must be 1-6"
	if f.has("allow_reselect") and not f.allow_reselect is bool: return "allow_reselect must be a boolean"
	if f.has("costs"):
		var cost_error := costs_error(f.costs)
		if not cost_error.is_empty(): return cost_error
		if f.costs.has("reselect") and not bool(f.get("allow_reselect", false)): return "costs.reselect requires allow_reselect"
		if f.costs.has("switch") and not f.has("switch_events"): return "costs.switch requires switch_events"
	if f.has("activation_seconds"):
		var time_error := activation_seconds_error(f.activation_seconds)
		if not time_error.is_empty(): return time_error
	return end_on_error(f.get("end_on", []))

## Batch 057: authored combat-budget costs per activation-boundary act.
## Omitted acts (or no costs at all) stay free, as every fixture was before.
const COST_ACTS := ["activate", "reselect", "switch"]
const COST_TYPES := ["action", "bonus_action", "magic", "none"] # Batch 063: magic = the Magic action.

static func costs_error(value: Variant) -> String:
	if not value is Dictionary or value.is_empty(): return "costs must be an object of activate/reselect/switch"
	for act in value:
		if str(act) not in COST_ACTS: return "costs has unknown act '%s'" % act
		if not value[act] is String or str(value[act]) not in COST_TYPES: return "costs.%s must be action, bonus_action, magic or none" % act
	return ""

## The declared cost of one act on the live rule ("none" when undeclared).
static func cost(actor: Character, feature_id: String, act: String) -> String:
	var c: Variant = rule(actor, feature_id).get("costs", {})
	return str(c.get(act, "none")) if c is Dictionary else "none"

## Batch 064 (Brandon: "Using a mode outside combat should take the time the
## casting time in its data says."): optional authored activation time per act,
## in whole seconds (1-86400, the same unit and range as a spell's
## cast_time_seconds). An act without a declared time takes the time its
## declared cost names: action, bonus_action and magic are one 6-second round
## (SRD 5.2.1 "Combat": a round is about 6 seconds), none takes no time.
const ROUND_SECONDS := 6

static func activation_seconds_error(value: Variant) -> String:
	if not value is Dictionary or value.is_empty(): return "activation_seconds must be an object of activate/reselect/switch seconds"
	for act in value:
		if str(act) not in COST_ACTS: return "activation_seconds has unknown act '%s'" % act
		if not _int(value[act], 1, 86400): return "activation_seconds.%s must be whole seconds from 1 to 86400" % act
	return ""

## The data-declared time an act takes (0 when it declares none and is free).
static func activation_seconds(actor: Character, feature_id: String, act: String) -> int:
	if act not in COST_ACTS: return 0
	var t: Variant = rule(actor, feature_id).get("activation_seconds", {})
	if t is Dictionary and t.has(act): return int(t[act])
	return 0 if cost(actor, feature_id, act) == "none" else ROUND_SECONDS

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
	if not OwnedFeatureSources.copy_active(actor, feature): return {} # Review 049 R1: merged/suppressed copies grant nothing.
	return RuleUpgradeRules.effective(actor, feature)

## Batch 050 bug 2: the owned rule even while its copy is suppressed or merged.
## End predicates read this, so a suppressed power still ends on schedule.
static func owned_rule(actor: Character, feature_id: String) -> Dictionary:
	var feature := actor.get_feature(feature_id)
	if feature.get("type", "") != "mode_choice": return {}
	return RuleUpgradeRules.owned_view(func(): return RuleUpgradeRules.effective(actor, feature)) # Review 050 R1.

const INCAPACITATING := ["incapacitated", "unconscious", "paralyzed", "petrified", "stunned"]

static func incapacitated(actor: Character) -> bool:
	return INCAPACITATING.any(func(c): return actor.has_condition(c))

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
	# Review 052 R1: an Incapacitated creature can't act (SRD 5.2.1 Conditions); refuse before the use is spent.
	if incapacitated(actor): return _receipt(false, "incapacitated")
	if not actor.use_feature(feature_id): return _receipt(false, "no_uses")
	var serial := int(actor.feature_modes.get(feature_id, {}).get("activation_serial", 0)) + 1
	var rolled := 0
	if r.has("die"):
		rolled = Dice.roll(int(str(r.die).trim_prefix("d")))
		for recipient in recipients:
			recipient.temp_hp = maxi(recipient.temp_hp, rolled)
	actor.feature_modes[feature_id] = {"mode": mode_id, "active": true, "remaining_seconds": int(r.duration_seconds), "activation_serial": serial, "rolled": rolled, "recipients": ids}
	return _receipt(true, "activated", {"die": str(r.get("die", "")), "rolled": rolled, "recipients": ids.duplicate(), "activation_serial": serial})

## S-104: an own declared event opens a one-switch window on matching active
## activations; any later event closes older windows. Already settled results
## (the hit that opened the window) are never recomputed.
static func on_event(actor: Character, event: String) -> Array:
	var opened: Array = []
	if actor == null or event not in SWITCH_EVENTS: return opened
	refresh(actor)
	for feature_id in actor.feature_modes.keys():
		var state: Dictionary = actor.feature_modes[feature_id]
		state.erase("window")
		if not bool(state.get("active", false)): continue
		if event not in rule(actor, str(feature_id)).get("switch_events", []): continue
		state["event_serial"] = int(state.get("event_serial", 0)) + 1
		state["window"] = {"event": event, "serial": int(state.event_serial)}
		opened.append(str(feature_id))
	return opened

static func switch(actor: Character, feature_id: String, mode_id: String, event: String) -> Dictionary:
	var r := rule(actor, feature_id)
	if r.is_empty() or r.boundary != "activation": return _receipt(false, "not_activation")
	refresh(actor)
	var state: Dictionary = actor.feature_modes.get(feature_id, {})
	if not bool(state.get("active", false)): return _receipt(false, "not_active")
	if state.get("window", {}).get("event", "") != event or event not in r.get("switch_events", []): return _receipt(false, "no_window")
	if _mode(r, mode_id).is_empty(): return _receipt(false, "unknown_mode")
	var previous := str(state.mode)
	if previous == mode_id: return _receipt(false, "same_mode")
	state["mode"] = mode_id # Uses, remaining time, serial and roll stay fixed.
	state.erase("window")
	return _receipt(true, "switched", {"replaced": previous, "event": event})

static func end(actor: Character, feature_id: String, reason: String) -> Dictionary:
	var state: Dictionary = actor.feature_modes.get(feature_id, {})
	if not bool(state.get("active", false)): return {}
	var r := owned_rule(actor, feature_id)
	if reason not in ["duration", "dismissed"] and reason not in r.get("end_on", []): return {}
	var ended := str(state.mode)
	state["active"] = false
	state["mode"] = ""
	state["remaining_seconds"] = 0
	state.erase("window")
	return {"feature_id": feature_id, "mode": ended, "reason": reason, "activation_serial": int(state.activation_serial)}

## End predicates are read from the live (possibly upgraded) rule.
static func refresh(actor: Character) -> Array:
	var ended: Array = []
	for feature_id in actor.feature_modes.keys():
		if not bool(actor.feature_modes[feature_id].get("active", false)): continue
		var e := {}
		if actor.current_hp <= 0:
			e = end(actor, feature_id, "zero_hp")
		if e.is_empty() and INCAPACITATING.any(func(c): return actor.has_condition(c)):
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
	var granted := {}
	var ordered: Array = actor.feature_modes.keys()
	ordered.sort()
	for feature_id in ordered:
		var state: Dictionary = actor.feature_modes[feature_id]
		var r := rule(actor, str(feature_id))
		var mode := _mode(r, str(state.get("mode", "")))
		if mode.is_empty() or (r.boundary == "activation" and not bool(state.get("active", false))): continue
		# Batch 050 bug 3: each identical copy keeps its own rule and uses, but
		# the same item's same power grants its benefit once.
		var copy := str(actor.get_feature(str(feature_id)).get("source_instance_id", ""))
		if not copy.is_empty():
			var stack_key := "%s|%s" % [actor.inventory.copies.records.get(copy, {}).get("definition_id", ""), str(feature_id).get_slice("@", 0)]
			if granted.has(stack_key): continue
			granted[stack_key] = true
		var identity := "mode:" + JSON.stringify([actor.character_id, feature_id, mode.id, int(state.get("activation_serial", 0))])
		out.append({"source_instance_id": identity, "definition_id": str(mode.id), "benefits": mode.benefits})
	return out

## Match the membership rebuilt by Character.from_dict: class/subclass levels
## plus OwnedFeatureSources (species, species feats, exact item copies).
static func declared_features(data: Dictionary) -> Array:
	var class_data := DataLoader.get_character_class(str(data.get("class_id", "")))
	var allocation: Dictionary = data.get("class_levels", {})
	var level := int(allocation.get(str(data.get("class_id", "")), 0)) if not allocation.is_empty() else int(data.get("level", 1))
	var subclass_id := str(data.get("subclass_id", class_data.get("legacy_subclass", "") if int(data.get("level", 1)) >= int(class_data.get("subclass_level", 3)) else ""))
	var out: Array = []
	for definition in [class_data, DataLoader.get_subclass(subclass_id)]:
		for lvl in definition.get("features_by_level", {}):
			if int(lvl) <= level: out.append_array(definition.features_by_level[lvl])
	out.append_array(OwnedFeatureSources.declared_in(data)) # Batch 049: species, feats, exact equipped/attuned copies.
	return out

static func _declared(data: Dictionary, feature_id: String) -> Dictionary:
	for feature in declared_features(data):
		if feature.get("id", "") == feature_id and feature.get("type", "") == "mode_choice": return feature
	return {}

## Catalog modes plus modes any owned-level upgrade can add (S-085).
static func _declared_modes(data: Dictionary, feature_id: String, f: Dictionary) -> Array:
	var ids: Array = f.get("modes", []).map(func(m): return m.id)
	for feature in declared_features(data):
		if feature.get("type", "") == "rule_upgrade" and feature.get("rule", "") == feature_id:
			for m in feature.get("changes", {}).get("modes", {}).get("add", []): ids.append(m.id)
	return ids

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
		if not mode.is_empty() and mode not in _declared_modes(data, str(feature_id), f): return "feature mode is not declared"
		if f.boundary == "rest":
			if s.size() != 2 or not s.get("open") is bool or (mode.is_empty() and not s.open): return "rest feature mode is invalid"
			continue
		if not s.get("active") is bool or not _int(s.get("remaining_seconds"), 0, int(f.duration_seconds)) or not _int(s.get("activation_serial"), 1, 1000000) or not _int(s.get("rolled"), 0, 12) or not s.get("recipients") is Array or s.recipients.size() > 6:
			return "activation feature mode is invalid"
		if s.has("event_serial") and not _int(s.event_serial, 0, 1000000): return "activation feature mode is invalid"
		if s.has("window"):
			var w: Variant = s.window
			if not w is Dictionary or w.size() != 2 or str(w.get("event", "")) not in SWITCH_EVENTS or not _int(w.get("serial"), 1, int(s.get("event_serial", 0))) or not s.active: return "feature mode switch window is invalid"
		if s.active == mode.is_empty() or (s.active and int(s.remaining_seconds) < 1): return "activation feature mode is invalid"
	return ""

static func restore(actor: Character, data: Dictionary) -> void:
	actor.feature_modes = data.get("feature_modes", {}).duplicate(true) if data.get("feature_modes", {}) is Dictionary and saved_error(data).is_empty() else {}
	for state in actor.feature_modes.values():
		for key in ["remaining_seconds", "activation_serial", "rolled", "event_serial"]:
			if state.has(key): state[key] = int(state[key])
		if state.has("window"): state.window.serial = int(state.window.serial)
