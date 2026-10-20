## Source-owned replacements and finite, receipt-based consequences.
class_name DamageResponseRules
extends RefCounted

const FIELD := "damage_response"
const TYPES := ["acid", "bludgeoning", "cold", "fire", "force", "lightning", "necrotic", "piercing", "poison", "psychic", "radiant", "slashing", "thunder"]
const MEASURES := ["raw", "prevented", "absorbed", "resolved", "hp_loss"]

static func policy_error(value: Variant) -> String:
	if not value is Dictionary or value.is_empty(): return "Damage response requires a policy."
	var kind := str(value.get("kind", ""))
	if kind not in ["replace", "counter_damage", "counter_heal"]: return "Unsupported damage response kind."
	var allowed := ["kind", "damage_type", "stage", "measure", "numerator", "denominator", "rounding", "cap"]
	if kind == "replace":
		allowed.append_array(["immunity", "operation", "limit"])
		var stage := str(value.get("stage", ""))
		if stage not in ["incoming", "resolved"]: return "Replacement stage must be incoming or resolved."
		if str(value.get("immunity", "")) != ("before" if stage == "incoming" else "after"): return "Replacement must declare its stage's immunity interaction."
		if str(value.get("measure", "")) not in (["raw", "stage_amount"] if stage == "incoming" else ["resolved"]): return "Replacement measure is unavailable at its stage."
		if str(value.get("operation", "")) not in ["absorb", "heal"]: return "Replacement operation must absorb or heal."
		if value.has("limit") and not _integer(value.limit, 1, 100000): return "Replacement limit must be a positive integer."
	else:
		allowed.append_array(["recipient", "feedback", "max_depth", "response_type"])
		if str(value.get("stage", "")) != "settled" or str(value.get("measure", "")) not in MEASURES: return "Countereffects require an explicit settled measure."
		if str(value.get("recipient", "")) not in ["self", "origin"]: return "Countereffect recipient must be self or origin."
		if str(value.get("feedback", "")) != "once_per_source_per_root" or not _integer(value.get("max_depth"), 1, 8): return "Countereffects require finite source/root feedback and a depth from 1 to 8."
		if kind == "counter_damage" and str(value.get("response_type", "")) not in TYPES: return "Counter-damage requires a damage type."
		if kind == "counter_heal" and value.has("response_type"): return "Healing cannot declare a damage type."
	for key in value:
		if key not in allowed: return "Unsupported damage response field: %s." % key
	if str(value.get("damage_type", "")) not in TYPES: return "Damage response requires one qualifying type."
	if not _integer(value.get("numerator"), 1, 20) or not _integer(value.get("denominator"), 1, 20): return "Damage response ratio integers must be from 1 through 20."
	if str(value.get("rounding", "")) not in ["floor", "ceil"]: return "Damage response requires explicit rounding."
	if value.has("cap") and not _integer(value.cap, 0, 100000): return "Damage response cap must be a nonnegative integer."
	return ""

static func _integer(value: Variant, low: int, high: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floor(float(value)) and float(value) >= low and float(value) <= high

static func grant(target, cast: Dictionary, policy: Dictionary) -> bool:
	if target == null or not policy_error(policy).is_empty() or cast.is_empty(): return false
	var source := str(cast.get("source_id", ""))
	if source.is_empty() or actor_id(target).is_empty(): return false
	var owned := SpellEffects.records(target)
	var record: Dictionary = owned.get(source, cast.duplicate(true))
	record["recipient_id"] = actor_id(target)
	record[FIELD] = policy.duplicate(true)
	owned[source] = record
	if target is Dictionary: target["spell_effects"] = owned
	return true

## Create once per typed occurrence owner, share only within that occurrence.
static func begin(decisions: Dictionary, occurrence: int, source: Character) -> Dictionary:
	var out := decisions.duplicate()
	if not out.has("_damage_cause"):
		out["_damage_cause"] = {"root": occurrence, "serial": 0, "used": {}, "original_actor": str(decisions.get("damage_source_actor_id", actor_id(source))), "original_source": str(decisions.get("damage_source_instance_id", actor_id(source)))}
	return out

static func actor_id(actor) -> String:
	return actor.character_id if actor is Character else str(actor.get("id", "")) if actor is Dictionary else ""

static func _sources(target, damage_type: String, kind: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for source in SpellEffects.records(target):
		var record: Dictionary = SpellEffects.records(target)[source]
		var policy: Variant = record.get(FIELD)
		if not policy is Dictionary or not policy_error(policy).is_empty(): continue
		if str(record.get("source_id", "")) != str(source) or str(record.get("recipient_id", "")) != actor_id(target): continue
		if not str(source).begins_with("spell:%s:" % str(record.get("caster_id", ""))): continue
		# Definitions, never receipt/HUD metadata, own policy authority.
		if not definition_has_policy(DataLoader.get_spell(str(record.get("spell_id", ""))), policy): continue
		if str(policy.kind) != kind or str(policy.damage_type) != damage_type: continue
		out.append({"source": str(source), "policy": policy.duplicate(true)})
	out.sort_custom(func(a: Dictionary, b: Dictionary): return a.source < b.source)
	return out

static func definition_has_policy(definition: Dictionary, expected: Dictionary) -> bool:
	if not SharedSpell.uses(definition): return false
	var effects: Array = definition.get("effects", []).duplicate()
	for step in definition.get("steps", []):
		if step is Dictionary: effects.append_array(step.get("effects", []))
	for effect in effects:
		if effect is Dictionary and effect.get("type", "") == "grant_damage_response" and effect.get("policy", {}) == expected: return true
	return false

static func replacements(target, stage: String, amount: int, raw: int, damage_type: String, decisions: Dictionary) -> Dictionary:
	var remaining := amount
	var receipts: Array[Dictionary] = []
	for option in _sources(target, damage_type, "replace"):
		var policy: Dictionary = option.policy
		if str(policy.stage) != stage or remaining <= 0: continue
		var replaced := mini(remaining, int(policy.get("limit", remaining)))
		var measure := raw if str(policy.measure) == "raw" else remaining
		var healing := heal(target, scaled(measure, policy)) if str(policy.operation) == "heal" else 0
		remaining -= replaced
		var receipt := identity(target, str(option.source), decisions)
		receipt.merge({"stage": stage, "immunity": policy.immunity, "measure": policy.measure, "measured": measure, "replaced": replaced, "healed": healing, "requested_healing": scaled(measure, policy) if str(policy.operation) == "heal" else 0})
		receipts.append(receipt)
	return {"remaining": remaining, "receipts": receipts, "replaced": amount - remaining}

static func scaled(amount: int, policy: Dictionary) -> int:
	var value := int(Dice.apply_damage_multiplier(maxi(0, amount), int(policy.numerator), int(policy.denominator), str(policy.rounding)).get("value", 0))
	return mini(value, int(policy.get("cap", value)))

static func heal(target, amount: int) -> int:
	if target is Character: return target.heal(amount)
	if not target is Dictionary or CombatAction.is_healing_suppressed(target) or not bool(target.get("is_alive", true)): return 0
	var healed := mini(amount, maxi(0, int(target.get("max_hp", 0)) - int(target.get("current_hp", 0))))
	target["current_hp"] = int(target.get("current_hp", 0)) + healed
	return healed

static func identity(target, source: String, decisions: Dictionary) -> Dictionary:
	var cause: Dictionary = decisions["_damage_cause"]
	return {"root_occurrence_id": cause.root, "parent_consequence_id": int(decisions.get("_consequence_id", 0)), "original_cause_actor_id": cause.original_actor, "original_cause_source_id": cause.original_source, "reacting_source_instance_id": source, "reacting_actor_id": actor_id(target)}

static func counters(target, origin, damage_type: String, settled: Dictionary, decisions: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var options := _sources(target, damage_type, "counter_damage")
	options.append_array(_sources(target, damage_type, "counter_heal"))
	var cause: Dictionary = decisions["_damage_cause"]
	for option in options:
		var policy: Dictionary = option.policy
		# Earlier consequences may have ended another candidate's exact source.
		if SpellEffects.records(target).get(str(option.source), {}).get(FIELD, {}) != policy: continue
		var recipient = target if str(policy.recipient) == "self" else origin
		if recipient == null or actor_id(recipient).is_empty(): continue
		var measured := int(settled.get(str(policy.measure), 0))
		var amount := scaled(measured, policy)
		if amount <= 0: continue
		var key := "%s|%s" % [actor_id(target), option.source]
		var depth := int(decisions.get("_response_depth", 0))
		var receipt := identity(target, str(option.source), decisions)
		receipt.merge({"kind": policy.kind, "stage": "settled", "measure": policy.measure, "measured": measured, "amount": amount, "recipient_id": actor_id(recipient), "depth": depth + 1})
		if cause.used.has(key) or depth >= int(policy.max_depth):
			receipt["limited"] = true
			receipt["limit_reason"] = "source_already_used" if cause.used.has(key) else "max_depth"
			out.append(receipt)
			continue
		# Mark before recursion. A sibling's execution cannot reenter this source.
		cause.used[key] = true
		cause.serial = int(cause.serial) + 1
		receipt["consequence_id"] = int(cause.serial)
		if str(policy.kind) == "counter_heal":
			receipt["healed"] = heal(recipient, amount)
		else:
			var child := decisions.duplicate()
			child["_response_depth"] = depth + 1
			child["_consequence_id"] = int(cause.serial)
			child["_damage_response_child"] = true
			child.erase("_damage_link_child")
			child.erase("damage_link_source_instance_id")
			child.erase("damage_link_declined")
			child["damage_is_critical"] = false
			child["damage_source_actor_id"] = actor_id(target)
			child["damage_source_instance_id"] = str(option.source)
			child["_damage_origin"] = target
			var result := CombatAction.resolve_damage(recipient, amount, str(policy.response_type), child, false, false, target if target is Character else null, WardRules.next_damage_occurrence_id())
			receipt["damage_receipt"] = result
			# This reference is transient; no causal state enters spell/save records.
			if recipient is Character: receipt["recipient_actor"] = recipient
		out.append(receipt)
	return out
