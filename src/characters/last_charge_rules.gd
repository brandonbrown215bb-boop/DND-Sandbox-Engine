## Last-charge aftermath on exact item copies (S-060).
##
## An item definition may declare `last_charge_aftermath`. When a real spend
## takes that exact copy from charges > 0 to 0, the aftermath settles once for
## that spend: an optional declared roll, then destruction or degradation of
## that copy only. Degradation keeps the copy identity and every mundane field.
## Batch 072 (S-060/S-203): `keep_properties` names the MagicPropertyRules
## properties that survive; every other magical property the definition has is
## lost on that exact copy (read by MagicPropertyRules.active, so all property
## consumers obey it). The copy stays magical only if it keeps one. It no longer
## recovers charges. Loss is derived from the definition, so no extra state is
## saved and legacy degraded records keep loading.
class_name LastChargeRules
extends RefCounted

const OUTCOMES := ["destroy", "degrade"]

static func validate(policy: Variant) -> String:
	if not policy is Dictionary: return "last_charge_aftermath must be an object"
	if str(policy.get("outcome", "")) not in OUTCOMES: return "last_charge_aftermath outcome must be destroy or degrade"
	if policy.has("roll"):
		var roll: Variant = policy["roll"]
		if not roll is Dictionary or int(roll.get("die", 0)) not in [4, 6, 8, 10, 12, 20, 100] or not roll.get("trigger_on", null) is Array or roll.trigger_on.is_empty(): return "last_charge_aftermath roll is invalid"
		for face in roll.trigger_on:
			if not (face is int or face is float) or int(face) < 1 or int(face) > int(roll.die): return "last_charge_aftermath trigger face is invalid"
	if policy.has("keep_properties") and (not policy["keep_properties"] is Array or policy["keep_properties"].any(func(v): return not v is String)): return "last_charge_aftermath keep_properties must be strings"
	return ""

## Load-time check against the item definition: each kept name must be a known
## magical property that this item actually has. Unsupported names are refused.
static func definition_error(item: Dictionary) -> String:
	var policy: Variant = item.get("last_charge_aftermath", {})
	if not policy is Dictionary: return ""
	if str(policy.get("outcome", "")) != "degrade" and policy.has("keep_properties"): return "last_charge_aftermath keep_properties applies only to degrade"
	for name in policy.get("keep_properties", []):
		if str(name) not in MagicPropertyRules.PROPERTIES: return "last_charge_aftermath keep_properties names unsupported property '%s'" % str(name)
		if not MagicPropertyRules.definition_has(item, str(name)): return "last_charge_aftermath keeps property '%s' the item lacks" % str(name)
	return ""

## Magical properties the definition has that degradation keeps / loses.
static func kept_properties(definition_id: String) -> Array:
	var keep: Array = policy_for(definition_id).get("keep_properties", [])
	return MagicPropertyRules.PROPERTIES.filter(func(p): return p in keep and MagicPropertyRules.has_property(definition_id, p))

static func lost_properties(definition_id: String) -> Array:
	var keep: Array = policy_for(definition_id).get("keep_properties", [])
	return MagicPropertyRules.PROPERTIES.filter(func(p): return p not in keep and MagicPropertyRules.has_property(definition_id, p))

## Production query (MagicPropertyRules.active / _affected): this exact copy lost the property.
static func lost(record: Dictionary, property: String) -> bool:
	if not bool(record.get("state", {}).get("degraded", false)): return false
	var policy := policy_for(str(record.get("definition_id", "")))
	if policy.is_empty() or str(policy.outcome) != "degrade": return false
	return property not in policy.get("keep_properties", [])

static func policy_for(definition_id: String) -> Dictionary:
	var policy: Variant = DataLoader.get_item(definition_id).get("last_charge_aftermath", {})
	return policy if policy is Dictionary and not policy.is_empty() and validate(policy).is_empty() else {}

## Called by Inventory after a successful spend. Returns {} when nothing applies.
static func settle(inventory: RefCounted, instance_id: String, charges_before: int, charges_after: int, forced_roll: int = 0) -> Dictionary:
	if charges_before <= 0 or charges_after != 0: return {}
	var record: Dictionary = inventory.copies.records.get(instance_id, {})
	if record.is_empty(): return {}
	var definition_id := str(record.get("definition_id", ""))
	var policy := policy_for(definition_id)
	if policy.is_empty() or bool(record.get("state", {}).get("degraded", false)): return {}
	var receipt := {"instance_id": instance_id, "definition_id": definition_id, "outcome": str(policy.outcome), "rolled": false, "triggered": true}
	if policy.has("roll"):
		var face := forced_roll if forced_roll > 0 else Dice.roll(int(policy.roll.die))
		receipt.rolled = true
		receipt["roll"] = face
		receipt.triggered = policy.roll.trigger_on.any(func(f): return int(f) == face)
	if not receipt.triggered: return receipt
	if str(policy.outcome) == "destroy":
		receipt["destroyed"] = not inventory.destroy_instance(instance_id).is_empty()
	else:
		var state: Dictionary = record.get("state", {}).duplicate(true)
		state["degraded"] = true
		var kept := kept_properties(definition_id)
		state["magical"] = not kept.is_empty()
		record["state"] = state
		inventory.copies.records[instance_id] = record
		receipt["degraded"] = true
		receipt["kept_properties"] = kept
		receipt["lost_properties"] = lost_properties(definition_id)
		if inventory.has_method("_sync_owned_features"): inventory._sync_owned_features() # lost "features" stop granting now.
	return receipt

## Saved-state check for the degradation marker; absent keeps legacy saves valid.
static func saved_state_error(definition_id: String, state: Dictionary) -> String:
	if not state.has("degraded") and not state.has("magical"): return ""
	var policy := policy_for(definition_id)
	if policy.is_empty() or str(policy.outcome) != "degrade": return "item degradation state is invalid"
	if state.get("degraded", null) != true or state.get("magical", null) != (not kept_properties(definition_id).is_empty()) or int(state.get("charges", 0)) != 0: return "item degradation state is invalid"
	return ""
