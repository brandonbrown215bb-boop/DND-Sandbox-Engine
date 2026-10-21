## Batch 052 (card Q-20261021-004820-732c): the player-facing view and the one
## entry point the HUD uses for owned mode_choice rules and exclusive upgrade
## options. Every request carries the token it was offered with; a request whose
## token no longer matches (stale popup) is refused before anything is spent.
class_name ModeControls
extends RefCounted

const KINDS := ["activate", "choose", "reselect", "switch", "alternative"]

## Batch 062 (queue item 4, Brandon: "Yes."): the explicit outside-combat context.
## Outside initiative there is no turn budget, so a declared action/bonus_action
## cost has nothing to spend; uses are still charged once by the act itself.
## A null budget still means "no context given" and keeps 057's not_in_combat refusal.
class OutsideCombat:
	extends RefCounted

static func outside_combat() -> OutsideCombat:
	return OutsideCombat.new()

## Owned mode_choice rules, once each, in feature order.
static func rows(actor: Character) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if actor == null: return out
	FeatureModeRules.refresh(actor)
	var seen := {}
	for feature in actor.features:
		if feature.get("type", "") != "mode_choice" or seen.has(str(feature.id)): continue
		seen[str(feature.id)] = true
		out.append(row(actor, str(feature.id)))
	return out

static func row(actor: Character, feature_id: String) -> Dictionary:
	var feature := actor.get_feature(feature_id)
	var owned := FeatureModeRules.owned_rule(actor, feature_id)
	var live := FeatureModeRules.rule(actor, feature_id)
	var state: Dictionary = actor.feature_modes.get(feature_id, {})
	var copy := str(feature.get("source_instance_id", ""))
	var reason := ""
	if live.is_empty():
		reason = "merged" if not copy.is_empty() and ActorProjectionRules.merged(actor, copy) else "suppressed"
	var r := owned if live.is_empty() else live
	# Review 052 R1: an Incapacitated owner is offered nothing at the activation boundary.
	if reason.is_empty() and str(r.get("boundary", "")) == "activation" and FeatureModeRules.incapacitated(actor): reason = "incapacitated"
	var out := {
		"feature_id": feature_id, "name": str(feature.get("name", feature_id)), "boundary": str(r.get("boundary", "")),
		"available": reason.is_empty(), "reason": reason, "source_instance_id": copy,
		"modes": r.get("modes", []).map(func(m): return str(m.id)),
		"active": bool(state.get("active", false)), "mode": str(state.get("mode", "")),
		"open": bool(state.get("open", true)), "remaining_seconds": int(state.get("remaining_seconds", 0)),
		"window": str(state.get("window", {}).get("event", "")),
		"uses": 0, "max_uses": 0, "alternatives": alternatives(actor, feature_id),
		"token": token(actor, feature_id),
	}
	if out.boundary == "activation":
		var pool := str(feature.get("resource_id", feature_id))
		out.uses = int(actor.feature_uses.get(pool, 0))
		out.max_uses = maxi(0, actor.get_feature_max_uses(pool))
	out["actions"] = actions(out, r)
	return out

## Exclusive upgrade groups owned for this rule: [{group, chosen, options}].
static func alternatives(actor: Character, feature_id: String) -> Array:
	var out: Array = []
	var resolved := RuleUpgradeRules._resolve(actor, feature_id)
	var groups: Array = resolved.alternatives.keys()
	groups.sort()
	for group in groups:
		out.append({"group": str(group), "chosen": resolved.alternatives[group].chosen, "options": resolved.alternatives[group].options.duplicate()})
	return out

## What the player may press now. Unavailable (merged/suppressed) copies offer nothing.
static func actions(row_data: Dictionary, r: Dictionary) -> Array[String]:
	var out: Array[String] = []
	if not row_data.available: return out
	if row_data.boundary == "rest":
		if row_data.open: out.append("choose")
	elif row_data.active:
		if bool(r.get("allow_reselect", false)): out.append("reselect")
		if not str(row_data.window).is_empty(): out.append("switch")
	elif int(row_data.uses) > 0:
		out.append("activate")
	if not row_data.active and not row_data.alternatives.is_empty(): out.append("alternative")
	return out

## Everything a popup answer depends on; any change makes the answer stale.
static func token(actor: Character, feature_id: String) -> String:
	var feature := actor.get_feature(feature_id)
	var state: Dictionary = actor.feature_modes.get(feature_id, {})
	var pool := str(feature.get("resource_id", feature_id))
	return JSON.stringify([actor.character_id, feature_id, not FeatureModeRules.rule(actor, feature_id).is_empty(), bool(state.get("active", false)), str(state.get("mode", "")), bool(state.get("open", true)), int(state.get("activation_serial", 0)), int(state.get("event_serial", 0)), str(state.get("window", {}).get("event", "")), int(actor.feature_uses.get(pool, 0)), alternatives(actor, feature_id)])

static func label(r: Dictionary) -> String:
	var text := "Mode: %s" % r.name
	if r.boundary == "activation": text += " (%d/%d uses)" % [r.uses, r.max_uses]
	if r.active: text += " [%s, %ds left]" % [r.mode, r.remaining_seconds]
	elif r.boundary == "rest" and not str(r.mode).is_empty(): text += " [%s]" % r.mode
	if not r.available: text += " [Unavailable: %s]" % r.reason
	return text

## Option ids a kind offers (modes, or "group|upgrade" pairs).
static func options(r: Dictionary, kind: String) -> Array[String]:
	var out: Array[String] = []
	if kind == "alternative":
		for g in r.alternatives:
			for o in g.options:
				if o != g.chosen: out.append("%s|%s" % [g.group, o])
	else:
		for m in r.modes:
			if kind == "activate" or kind == "choose" or m != r.mode: out.append(m)
	return out

## Batch 057: the combat-budget cost of a kind ("none" for choose/alternative).
static func cost(actor: Character, feature_id: String, kind: String) -> String:
	return FeatureModeRules.cost(actor, feature_id, kind) if kind in FeatureModeRules.COST_ACTS else "none"

## Why a costed act can't be paid now ("" when it can, or when it is free).
## budget is the combat state (or null outside combat: no turn to pay from).
static func cost_error(actor: Character, feature_id: String, kind: String, budget: Object) -> String:
	var c := cost(actor, feature_id, kind)
	if c == "none": return ""
	if budget == null: return "not_in_combat"
	if budget is OutsideCombat:
		# Batch 062: no turn to pay from; refuse only while combat is running or the owner can't act.
		if GameManager.current_state == GameManager.GameState.COMBAT: return "in_combat"
		if FeatureModeRules.incapacitated(actor) or not actor.is_alive: return "incapacitated"
		return ""
	if budget.active_character != actor: return "wrong_turn"
	if FeatureModeRules.incapacitated(actor) or not actor.is_alive: return "incapacitated"
	if not budget.can_pay_mode_cost(c): return "unaffordable"
	return ""

## The single entry point for HUD answers. Refusals spend nothing.
## Batch 057: a declared cost is checked before the act and paid once after it succeeds.
static func apply(actor: Character, feature_id: String, kind: String, option: String, offered_token: String, budget: Object = null) -> Dictionary:
	if actor == null or kind not in KINDS: return {"success": false, "reason": "invalid"}
	if option.is_empty(): return {"success": false, "reason": "canceled"}
	if token(actor, feature_id) != offered_token: return {"success": false, "reason": "stale"}
	var r := row(actor, feature_id)
	if kind not in r.actions: return {"success": false, "reason": "unavailable"}
	if option not in options(r, kind): return {"success": false, "reason": "unknown_option"}
	var price := cost(actor, feature_id, kind)
	var refused := cost_error(actor, feature_id, kind, budget)
	if not refused.is_empty(): return {"success": false, "reason": refused}
	var done := {}
	match kind:
		"activate": done = FeatureModeRules.activate(actor, feature_id, option)
		"choose", "reselect": done = FeatureModeRules.choose(actor, feature_id, option)
		"switch": done = FeatureModeRules.switch(actor, feature_id, option, str(r.window))
	if not done.is_empty():
		if done.success and price != "none":
			if budget is OutsideCombat:
				done["cost_outside_combat"] = price # Batch 062: no action economy outside initiative.
			else:
				budget._spend_action_cost(price) # can_pay_mode_cost held just above; nothing ran in between.
				done["cost"] = price
		return done
	match kind:
		"alternative":
			var parts := option.split("|")
			var ok := RuleUpgradeRules.choose_alternative(actor, feature_id, parts[0], parts[1])
			return {"success": ok, "reason": "chosen" if ok else "refused"}
	return {"success": false, "reason": "invalid"}

static func kind_label(kind: String) -> String:
	return {"activate": "Activate", "choose": "Choose mode", "reselect": "Change mode", "switch": "Switch mode", "alternative": "Choose upgrade"}.get(kind, kind)
