## Batch 065 (queue item 6). Brandon: "If something costs a reaction like
## 'Hellish Rebuke', then it should be able to happen on a defined trigger from
## the data." The data supplies the trigger; the engine sets NO default trigger
## for any reaction. A spell or mode without a declared `reaction_trigger` is
## never offered automatically by this path (ADR-0018: no per-ID branches).
##
## A trigger is {"event": <EVENTS>, "range_feet"?: 5..1000, "requires_sight"?: bool}.
## SRD 5.2.1 wording the vocabulary covers:
## - Hellish Rebuke: "Reaction, which you take in response to taking damage from
##   a creature that you can see within 60 feet of yourself" -> on_damaged_by_creature.
## - Shield: "Reaction, which you take when you are hit by an attack roll" -> on_hit_by_attack.
## - on_attacked: the reactor is the target of an attack roll (before the roll).
## - on_hit_with_attack: the reactor's own attack roll hits (the 057/062 costed
##   on-hit mode switch).
class_name ReactionTriggers
extends RefCounted

const EVENTS := ["on_attacked", "on_hit_by_attack", "on_damaged_by_creature", "on_hit_with_attack"]
const KEYS := ["event", "range_feet", "requires_sight"]
## The S-104 switch window each mode trigger fires through (switch_events).
const MODE_WINDOW_EVENTS := {"on_hit_with_attack": "hit"}

static var _serial := 0

static func trigger_error(value: Variant) -> String:
	if not value is Dictionary: return "reaction_trigger must be an object"
	for key in value:
		if str(key) not in KEYS: return "reaction_trigger has unknown key '%s'" % key
	if not value.get("event") is String or str(value.get("event")) not in EVENTS: return "reaction_trigger.event must be one of %s" % ", ".join(EVENTS)
	if value.has("range_feet"):
		var r: Variant = value.range_feet
		if not (r is int or r is float) or float(r) != float(int(r)) or int(r) < 5 or int(r) > 1000 or int(r) % 5 != 0: return "reaction_trigger.range_feet must be whole feet from 5 to 1000 in steps of 5"
	if value.has("requires_sight") and not value.requires_sight is bool: return "reaction_trigger.requires_sight must be true or false"
	return ""

## A spell's reaction trigger. Only reaction-time spells may declare one.
static func spell_trigger_error(spell: Dictionary) -> String:
	if not spell.has("reaction_trigger"): return ""
	if str(spell.get("casting_time", "")) != "reaction": return "reaction_trigger requires casting_time reaction"
	return trigger_error(spell.reaction_trigger)

## A mode rule's reaction trigger: required by, and only allowed with, a
## reaction switch cost, and it must fire through a declared switch event.
static func mode_trigger_error(rule: Dictionary) -> String:
	var c: Variant = rule.get("costs", {})
	var reaction_costs := []
	if c is Dictionary:
		for act in c:
			if str(c[act]) == "reaction": reaction_costs.append(str(act))
	if reaction_costs.is_empty():
		return "reaction_trigger requires a reaction cost" if rule.has("reaction_trigger") else ""
	if reaction_costs != ["switch"]: return "only costs.switch may be reaction"
	if not rule.has("reaction_trigger"): return "costs.switch reaction requires a declared reaction_trigger (no default trigger)"
	var err := trigger_error(rule.reaction_trigger)
	if not err.is_empty(): return err
	var window := str(MODE_WINDOW_EVENTS.get(str(rule.reaction_trigger.event), ""))
	if window.is_empty() or window not in rule.get("switch_events", []): return "a mode reaction_trigger must be on_hit_with_attack with switch_events hit"
	return ""

## One trigger event. distance_feet < 0 means unknown (range filters then refuse).
static func make_event(kind: String, reactor: Character, source: Variant, distance_feet: int, source_visible: bool) -> Dictionary:
	_serial += 1
	return {"kind": kind, "reactor": reactor, "source": source, "distance_feet": distance_feet, "source_visible": source_visible, "serial": _serial, "open": true}

## Close the event: any offer answered after this is stale.
static func close(event: Dictionary) -> void:
	event["open"] = false

## "" when the declared trigger matches the event and its filters pass.
static func filter_reason(reactor: Character, trigger: Variant, event: Dictionary) -> String:
	if not trigger is Dictionary or trigger.is_empty(): return "no_trigger"
	if event.get("reactor") != reactor or str(trigger.get("event", "")) != str(event.get("kind", "")): return "wrong_event"
	if not bool(event.get("open", false)): return "stale"
	if reactor == null or not reactor.is_alive or CombatAction.is_incapacitated(reactor): return "incapacitated"
	if not reactor.reaction_available: return "reaction_used"
	if trigger.has("range_feet") and (int(event.get("distance_feet", -1)) < 0 or int(event.distance_feet) > int(trigger.range_feet)): return "out_of_range"
	if bool(trigger.get("requires_sight", false)) and not bool(event.get("source_visible", false)): return "unseen"
	return ""

## Eligible offers for this event, each costing the reactor's Reaction.
static func offers(reactor: Character, event: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if reactor == null: return out
	for spell_id in SpellPermissionRules.spell_ids(reactor):
		var spell := DataLoader.get_spell(spell_id)
		if str(spell.get("casting_time", "")) != "reaction" or not spell.has("reaction_trigger"): continue
		if not filter_reason(reactor, spell.reaction_trigger, event).is_empty(): continue
		if not target_error(reactor, spell, event).is_empty(): continue
		if SpellPermissionRules.payment_choices(reactor, spell_id).is_empty(): continue
		out.append(_offer(reactor, event, "spell", spell_id, str(spell.get("name", spell_id)), ""))
	var window := ""
	for kind in MODE_WINDOW_EVENTS:
		if kind == str(event.get("kind", "")): window = str(MODE_WINDOW_EVENTS[kind])
	if not window.is_empty():
		for row in ModeControls.rows(reactor):
			var r := FeatureModeRules.rule(reactor, str(row.feature_id))
			if FeatureModeRules.cost(reactor, str(row.feature_id), "switch") != "reaction": continue
			if "switch" not in row.actions or str(row.window) != window: continue
			if not filter_reason(reactor, r.get("reaction_trigger", {}), event).is_empty(): continue
			out.append(_offer(reactor, event, "mode", str(row.feature_id), str(row.name), str(row.token)))
	return out

static func _offer(reactor: Character, event: Dictionary, kind: String, id: String, name: String, mode_token: String) -> Dictionary:
	var o := {"kind": kind, "id": id, "name": name, "cost": "reaction", "event_serial": int(event.serial), "mode_token": mode_token}
	o["token"] = token(reactor, o)
	return o

static func token(reactor: Character, offer: Dictionary) -> String:
	var t := ModeControls.token(reactor, str(offer.id)) if offer.kind == "mode" else str(SpellPermissionRules.payment_choices(reactor, str(offer.id)).size())
	return JSON.stringify([reactor.character_id, int(offer.event_serial), str(offer.kind), str(offer.id), t])

static func _refuse(reason: String) -> Dictionary:
	return {"success": false, "reason": reason, "reaction_spent": false}

static func target(reactor: Character, spell: Dictionary, event: Dictionary) -> Variant:
	return reactor if str(spell.get("target", "single")) == "self" else event.get("source")

## Run the normal target restrictions before spending a slot or Reaction.
## The paid marker permits this boundary's validation; this copy never resolves.
static func target_error(reactor: Character, spell: Dictionary, event: Dictionary) -> String:
	if reactor.has_condition("raging") or not DruidRules.can_cast_spell(reactor, spell): return "cannot_cast"
	var damage_error := SharedSpell.damage_policy_availability_error(spell, reactor)
	if not damage_error.is_empty(): return damage_error
	if str(spell.get("target", "single")) not in ["self", "single", "ally"]: return "unsupported_target"
	var recipient: Variant = target(reactor, spell, event)
	if not recipient is Character and not recipient is Dictionary: return "invalid_target"
	if (recipient is Character and recipient.is_dead()) or (recipient is Dictionary and not bool(recipient.get("is_alive", false))): return "invalid_target"
	var probe := spell.duplicate(true)
	probe["_reaction_trigger_paid"] = true
	var distance := 0 if is_same(recipient, reactor) else int(event.get("distance_feet", -1))
	var reach := CombatAction.spell_range_in_hexes(spell, reactor.level) * 5 + CombatAction.spell_range_bonus_feet(reactor, spell)
	if distance < 0 or distance > reach: return "out_of_range"
	if spell.has("physical_requirements"):
		var facts := PhysicalFactsRules.evaluate_physical_eligibility(recipient, spell.physical_requirements)
		if not facts.get("eligible", false): return str(facts.get("reason", "invalid_target"))
	# This reaction boundary has no location chooser/formula prompt or creation
	# host. Refuse those declarations rather than pay for a later host refusal.
	if spell.has("spatial_requirements") or not spell.get("formula_inputs", {}).is_empty() or SharedSpell.has_effect(spell, "create_actor") or SharedSpell.has_effect(spell, "actor_projection"): return "unsupported_reaction_host"
	if spell.has("steps"):
		var spatial_error := SharedStepExecutor.validate_spatial_context_for_steps(spell.steps, {})
		if not spatial_error.is_empty(): return spatial_error
	var checked := CombatAction.validate_spell_target(reactor, recipient, probe, distance)
	return "" if bool(checked.get("success", false)) else str(checked.get("message", "invalid_target"))

## Answer one offer. Every refusal spends nothing: cancelled prompt, stale
## trigger/offer, Reaction already used, Incapacitated, out of range, unseen.
## A spell pays its slot (and the Reaction) only here, on confirmation.
## choice: the payment row for a spell, the mode id for a mode switch.
static func confirm(reactor: Character, offer: Dictionary, event: Dictionary, accepted: bool, choice: Variant) -> Dictionary:
	if not accepted: return _refuse("canceled")
	if int(offer.get("event_serial", -1)) != int(event.get("serial", -2)) or not bool(event.get("open", false)): return _refuse("stale")
	if token(reactor, offer) != str(offer.get("token", "")): return _refuse("stale")
	if offer.kind == "spell":
		var spell := DataLoader.get_spell(str(offer.id))
		var why := filter_reason(reactor, spell.get("reaction_trigger", {}), event)
		if not why.is_empty(): return _refuse(why)
		var invalid_target := target_error(reactor, spell, event)
		if not invalid_target.is_empty(): return _refuse(invalid_target)
		if not choice is Dictionary or choice.is_empty(): return _refuse("canceled")
		var paid := SpellPermissionRules.spend_reaction(reactor, str(offer.id), {SpellPermissionRules.reaction_key(reactor, str(offer.id)): choice})
		if paid.is_empty(): return _refuse("unpaid")
		close(event)
		paid.spell["_reaction_trigger_paid"] = true # resolve_spell's reaction boundary: paid here, never again.
		paid.merge({"reason": "cast", "kind": "spell", "id": str(offer.id), "trigger": str(event.kind)}, true)
		return paid
	if offer.kind == "mode":
		var r := FeatureModeRules.rule(reactor, str(offer.id))
		var why := filter_reason(reactor, r.get("reaction_trigger", {}), event)
		if not why.is_empty(): return _refuse(why)
		var done := ModeControls.apply(reactor, str(offer.id), "switch", str(choice) if choice is String else "", str(offer.mode_token), ModeControls.reaction_payer())
		if not bool(done.get("success", false)):
			done["reaction_spent"] = false
			return done
		close(event)
		done.merge({"kind": "mode", "id": str(offer.id), "trigger": str(event.kind), "reaction_spent": true}, true)
		return done
	return _refuse("invalid")
