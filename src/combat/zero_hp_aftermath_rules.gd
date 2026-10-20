## Shared zero-HP aftermath operations (S-093, S-119).
##
## Content declares the behavior; this module owns eligibility, ordering and
## receipts. No content ID is branched on here.
##
## S-093 `death_save_outcome` rules are source-owned Character features. At the
## start of an upcoming Death Save the first eligible rule declares an
## automatic success/failure/stabilization or cancels that save. No d20 is
## rolled and no numeric bonus/reroll choice is offered for that save.
##
## S-119 `zero_hp_aftermath` policies are carried by a damage source (shared
## spell, weapon or monster attack). When that damage reduces a living target
## to 0 HP, the target dies or is destroyed outright instead of the ordinary
## 0-HP route, with the declared remains/gear policy. The original actor keeps
## its identity; its corpse record retains the actual cause for revival checks.
class_name ZeroHpAftermathRules
extends RefCounted

const DEATH_SAVE_OUTCOMES := ["success", "failure", "stabilize", "cancel"]
const AFTERMATH_OUTCOMES := ["death", "destruction"]
const GEAR_POLICIES := ["retained", "destroyed", "destroyed_except_magic"]
const CAUSE_SOURCE_KEYS := ["policy_id", "outcome", "source_instance_id", "actor_id", "damage_type", "gear"]

# --- S-093 -----------------------------------------------------------------

static func validate_death_save_rule(rule: Dictionary) -> String:
	if str(rule.get("source_instance_id", "")).is_empty(): return "death_save_outcome needs source_instance_id"
	if str(rule.get("outcome", "")) not in DEATH_SAVE_OUTCOMES: return "death_save_outcome outcome must be one of %s" % str(DEATH_SAVE_OUTCOMES)
	if rule.get("roll", false) != false: return "death_save_outcome declares no roll; roll must be false"
	if rule.has("required_condition") and (not rule["required_condition"] is String or str(rule["required_condition"]).is_empty()): return "death_save_outcome required_condition is invalid"
	for key in ["min_failures", "max_failures"]:
		if rule.has(key) and (not (rule[key] is int or rule[key] is float) or float(rule[key]) != floor(float(rule[key])) or int(rule[key]) < 0 or int(rule[key]) > 2): return "death_save_outcome %s must be 0..2" % key
	return ""

static func death_save_rules(actor: Character) -> Array:
	var out: Array = []
	if actor == null: return out
	for feature in actor.features:
		if feature is Dictionary and str(feature.get("type", "")) == "death_save_outcome" and validate_death_save_rule(feature).is_empty():
			out.append(feature)
	return out

## First eligible rule for the actor's upcoming Death Save, or {}.
static func pending_death_save_rule(actor: Character) -> Dictionary:
	if actor == null or actor.current_hp > 0 or actor.is_stable or actor.is_dead() or actor.death_save_successes >= 3: return {}
	for rule in death_save_rules(actor):
		var condition := str(rule.get("required_condition", ""))
		if not condition.is_empty() and not actor.has_condition(condition): continue
		if actor.death_save_failures < int(rule.get("min_failures", 0)) or actor.death_save_failures > int(rule.get("max_failures", 2)): continue
		return rule
	return {}

## Apply the declared outcome before any d20/bonus; returns the save result.
static func resolve_automatic_death_save(actor: Character, rule: Dictionary) -> Dictionary:
	var outcome := str(rule.get("outcome", ""))
	var before := {"successes": actor.death_save_successes, "failures": actor.death_save_failures}
	match outcome:
		"success":
			actor.death_save_successes += 1
			if actor.death_save_successes >= 3: actor.stabilize()
		"failure":
			actor.death_save_failures = mini(3, actor.death_save_failures + 1)
			if actor.death_save_failures >= 3: CorpseRules.mark_dead(actor, "death_saves")
		"stabilize":
			actor.stabilize()
		"cancel":
			pass
	return {
		"rolled": false, "automatic": true, "canceled": outcome == "cancel", "outcome": outcome,
		"source_instance_id": str(rule.get("source_instance_id", "")),
		"successes": actor.death_save_successes, "failures": actor.death_save_failures,
		"before": before, "stable": actor.is_stable, "revived": actor.current_hp > 0,
		"bonus_offered": false,
	}

# --- S-119 -----------------------------------------------------------------

static func validate_policy(policy: Variant) -> String:
	if not policy is Dictionary: return "zero_hp_aftermath must be an object"
	if str(policy.get("id", "")).is_empty(): return "zero_hp_aftermath needs id"
	if str(policy.get("trigger", "")) != "reduced_to_zero": return "zero_hp_aftermath trigger must be reduced_to_zero"
	var outcome := str(policy.get("outcome", ""))
	if outcome not in AFTERMATH_OUTCOMES: return "zero_hp_aftermath outcome must be death or destruction"
	var remains := str(policy.get("remains", ""))
	if remains not in CorpseRules.REMAINS: return "zero_hp_aftermath remains is invalid"
	if outcome == "destruction" and remains != "destroyed": return "destruction requires destroyed remains"
	if outcome == "death" and remains == "destroyed": return "death cannot declare destroyed remains; use destruction"
	if str(policy.get("gear", "")) not in GEAR_POLICIES: return "zero_hp_aftermath gear must be one of %s" % str(GEAR_POLICIES)
	if str(policy.get("cause", "")).is_empty() or str(policy.get("cause", "")).length() > 80: return "zero_hp_aftermath cause is invalid"
	if policy.has("precedes_zero_hp_replacement") and not policy["precedes_zero_hp_replacement"] is bool: return "precedes_zero_hp_replacement must be boolean"
	if policy.has("successor"):
		var successor_error := AftermathSuccessorRules.policy_error(policy["successor"])
		if not successor_error.is_empty(): return successor_error
	if policy.has("excluded_creature_types") and (not policy["excluded_creature_types"] is Array or policy["excluded_creature_types"].any(func(v): return not v is String)): return "excluded_creature_types must be strings"
	return ""

static func policy_from(decisions: Dictionary) -> Dictionary:
	var policy: Variant = decisions.get("zero_hp_aftermath", {})
	return policy if policy is Dictionary and not policy.is_empty() and validate_policy(policy).is_empty() else {}

## True when the declared aftermath must preempt zero-HP replacements.
static func precedes_replacement(target, decisions: Dictionary) -> bool:
	var policy := policy_from(decisions)
	return not policy.is_empty() and bool(policy.get("precedes_zero_hp_replacement", false)) and _eligible_type(target, policy)

static func _eligible_type(target, policy: Dictionary) -> bool:
	var kind := ""
	if target is Dictionary: kind = str(target.get("creature_type", target.get("type", "")))
	elif target is Character: kind = str(target.feature_uses.get("creature_type", target.creature_type))
	return kind not in policy.get("excluded_creature_types", [])

static func _is_magic(record: Dictionary) -> bool:
	if record.get("state", {}).get("magical", null) is bool: return bool(record.state.magical)
	var definition := DataLoader.get_item(str(record.get("definition_id", "")))
	return bool(definition.get("magical", false)) or definition.has("rarity") or bool(record.get("state", {}).get("magical", false))

## Settle the aftermath once after HP settlement. Returns {} when ineligible.
static func settle(target, hp_before: int, alive_before: bool, damage_type: String, decisions: Dictionary, source_character: Character) -> Dictionary:
	var policy := policy_from(decisions)
	if policy.is_empty() or hp_before <= 0 or not alive_before or not _eligible_type(target, policy): return {}
	var hp_after: int = target.current_hp if target is Character else int(target.get("current_hp", 0))
	if hp_after > 0: return {}
	var cause_source := {
		"policy_id": str(policy.id), "outcome": str(policy.outcome),
		"source_instance_id": str(decisions.get("damage_source_instance_id", "")),
		"actor_id": str(decisions.get("damage_source_actor_id", source_character.character_id if source_character != null else "")),
		"damage_type": damage_type, "gear": str(policy.gear),
	}
	var receipt := {"applied": true, "policy_id": str(policy.id), "outcome": str(policy.outcome), "remains": str(policy.remains), "cause": str(policy.cause), "cause_source": cause_source, "destroyed_gear": [], "retained_gear": []}
	if target is Character:
		var already_dead: bool = not target.corpse_state.is_empty()
		receipt["identity"] = target.character_id
		var gear: Array = []
		for record in target.inventory.owned_instances(): gear.append(record.duplicate(true))
		CorpseRules.mark_dead(target, str(policy.cause), str(policy.remains))
		# Same-occurrence massive-damage death is replaced by the declared cause.
		target.corpse_state["cause"] = str(policy.cause)
		target.corpse_state["remains"] = str(policy.remains)
		target.corpse_state["cause_source"] = cause_source.duplicate(true)
		receipt["corpse_id"] = str(target.corpse_state.get("corpse_id", ""))
		receipt["replaced_same_occurrence_death"] = already_dead
		for record in gear:
			var id := str(record.get("instance_id", ""))
			var destroy := str(policy.gear) == "destroyed" or (str(policy.gear) == "destroyed_except_magic" and not _is_magic(record))
			if destroy and not target.inventory.destroy_instance(id).is_empty(): receipt.destroyed_gear.append(id)
			else: receipt.retained_gear.append(id)
	else:
		target["current_hp"] = 0
		target["is_alive"] = false
		target["zero_hp_aftermath"] = {"outcome": str(policy.outcome), "remains": str(policy.remains), "cause": str(policy.cause), "cause_source": cause_source.duplicate(true)}
		receipt["identity"] = str(target.get("id", ""))
	var successor := AftermathSuccessorRules.settle(target, policy, decisions, cause_source.actor_id)
	if not successor.is_empty(): receipt["successor"] = successor
	return receipt

## Saved-corpse cause detail validation; absent keeps legacy saves loading.
static func saved_cause_error(body: Dictionary) -> String:
	if not body.has("cause_source"): return ""
	var detail: Variant = body["cause_source"]
	if not detail is Dictionary: return "corpse cause source is invalid"
	for key in detail:
		if str(key) not in CAUSE_SOURCE_KEYS or not detail[key] is String or str(detail[key]).length() > 160: return "corpse cause source is invalid"
	if str(detail.get("outcome", "")) not in AFTERMATH_OUTCOMES or str(detail.get("policy_id", "")).is_empty(): return "corpse cause source is invalid"
	if (str(detail.outcome) == "destruction") != (str(body.get("remains", "")) == "destroyed"): return "corpse cause source contradicts remains"
	if str(detail.get("gear", "")) not in GEAR_POLICIES: return "corpse cause source is invalid"
	return ""
