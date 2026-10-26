## Batch 081 (#45 follow-up). Brandon: "Support explicit object destruction
## separately from creature death, reusing the existing destruction handling."
## A shared effect {"type": "destroy_object", "policy": {...}} reduces an object
## resolution target to 0 HP; CombatObjectRules.sync_resolution_target then runs
## the existing CombatObjectRules.settle_destruction (spill contents, open
## doors/containers, containment, tethers). Creatures are never valid targets.
## Every value comes from the policy; there are no engine defaults:
##   id:      nonempty string (receipt identity)
##   cause:   nonempty string (recorded on the object as destroyed_cause)
##   magical: "refuse"  — magic objects are not eligible ("allow" is PARTIAL:
##            the combat object route only reaches nonmagical, unworn objects)
class_name ObjectDestructionRules
extends RefCounted

const KEYS := ["id", "cause", "magical"]

static func policy_error(policy: Variant) -> String:
	if not policy is Dictionary: return "destroy_object policy must be an object"
	for key in policy:
		if str(key) not in KEYS: return "destroy_object policy has unknown field '%s'" % str(key)
	for key in ["id", "cause"]:
		if not policy.get(key) is String or str(policy.get(key)).is_empty(): return "destroy_object %s must be a nonempty string" % key
	if str(policy.get("magical", "")) != "refuse": return "destroy_object magical must be refuse (allow is not supported yet)"
	return ""

static func _is_object(target) -> bool:
	return target is Dictionary and bool(target.get("is_object", false))

## Pre-cost eligibility. Empty string = eligible.
static func target_error(target, policy: Dictionary) -> String:
	if not _is_object(target): return "Only an object can be destroyed this way."
	var name := str(target.get("name", "That object"))
	var world: Dictionary = target.get("world_object", target)
	if int(target.get("current_hp", target.get("hp", 1))) <= 0 or bool(world.get("removed", false)) or int(world.get("hp", 1)) <= 0: return "%s is already destroyed." % name
	if bool(world.get("worn", false)) or bool(world.get("carried", false)) or not str(world.get("worn_by", "")).is_empty() or not str(world.get("carried_by", "")).is_empty(): return "%s is worn or carried and not affected." % name
	if str(policy.get("magical", "")) == "refuse" and CombatObjectRules.is_magical(world): return "%s is magical and not affected." % name
	return ""

## Pre-cost refusal for a spell carrying destroy_object effects.
static func cast_error(target, spell: Dictionary) -> String:
	for effect in spell.get("effects", []):
		if effect is Dictionary and str(effect.get("type", "")) == "destroy_object":
			var error := target_error(target, effect.get("policy", {}))
			if not error.is_empty(): return error
	return ""

## Destroy once on the resolution target; the caller's sync settles the world object.
static func destroy(target, policy: Dictionary, source_instance_id: String) -> Dictionary:
	var error := target_error(target, policy)
	if not error.is_empty(): return {"applied": false, "reason": error}
	target["current_hp"] = 0
	var world: Variant = target.get("world_object", null)
	if world is Dictionary:
		world["destroyed_cause"] = str(policy.cause)
		world["destroyed_by_policy"] = str(policy.id)
		if not source_instance_id.is_empty(): world["destroyed_source"] = source_instance_id
	return {"applied": true, "policy_id": str(policy.id), "cause": str(policy.cause), "object_id": str(target.get("id", ""))}
