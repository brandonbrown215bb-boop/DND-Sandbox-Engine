## Encounter-local recovery windows. Only CombatState emits the real boundaries.
class_name CombatPoolRecovery
extends RefCounted

const TRIGGERS := ["initiative_rolled", "turn_started"]
var _seen: Dictionary = {}
var _pending: Dictionary = {}
var _serial := 0
var receipts: Array[Dictionary] = []

static func policy_error(policy: Variant) -> String:
	if not policy is Dictionary: return "Combat recovery policy must be an object."
	for field in policy:
		if field not in ["mode", "amount_formula", "choice_group"]: return "Unsupported combat recovery field."
	if policy.get("mode") not in ["restore_fixed", "restore_to_capacity", "restore_to_floor"]:
		return "Combat recovery requires fixed, capacity or floor mode."
	if policy.has("choice_group") and (not policy.choice_group is String or str(policy.choice_group).strip_edges().is_empty()):
		return "Recovery choice_group must be a nonempty string."
	if policy.mode == "restore_to_capacity":
		return "Fill recovery cannot declare an amount." if policy.has("amount_formula") else ""
	var formula: Variant = policy.get("amount_formula")
	var error := SharedStepExecutor.formula_content_error(formula)
	if not error.is_empty(): return error
	error = ResourcePoolRules._actor_formula_error(formula)
	if not error.is_empty(): return error
	if (formula is int or formula is float) and not ResourcePoolRules._integer(formula, 1, 100):
		return "Recovery amount must be an integer from 1 to 100."
	return ""

static func policy_amount(policy: Dictionary, actor: Character) -> Dictionary:
	if not policy_error(policy).is_empty(): return {"success":false}
	if policy.mode == "restore_to_capacity": return {"success":true,"value":0}
	var result := SharedStepExecutor.evaluate_actor_formula(policy.amount_formula, actor)
	if not result.get("success", false) or not ResourcePoolRules._integer(result.get("value"), 1, 100):
		return {"success":false}
	return result

func clear() -> void:
	_pending.clear()
	_seen.clear()
	receipts.clear()
	# Serial deliberately never rewinds; an answer from a cleared window stays stale.

func begin(actor: Character, trigger: String, occurrence: int) -> Array[Dictionary]:
	var requests: Array[Dictionary] = []
	if actor == null or not actor.is_alive or actor.is_dead() or trigger not in TRIGGERS or occurrence < 0:
		return requests
	var key := "%s:%d" % [trigger, occurrence]
	var seen: Dictionary = _seen.get(actor, {})
	if seen.has(key): return requests
	seen[key] = true
	_seen[actor] = seen
	var groups: Dictionary = {}
	var sources: Dictionary = {}
	for feature in actor.features:
		if not feature is Dictionary or not feature.has("resource_pool") or not ResourcePoolRules.definition_error(feature).is_empty(): continue
		var policy: Dictionary = feature.resource_pool.get("recovery", {}).get(trigger, {})
		var amount := policy_amount(policy, actor)
		if not amount.get("success", false): continue
		for source_id in ResourcePoolRules.source_instance_ids(actor, str(feature.resource_pool.id)):
			if feature.has("source_instance_id") and str(feature.source_instance_id) != source_id: continue
			if sources.has(source_id): continue
			sources[source_id] = true
			var pool: Dictionary = actor.numeric_resource_pools[source_id]
			var offer := {"feature":feature,"definition":feature.duplicate(true),"pool":pool,"capacity":int(pool.capacity),"source_id":source_id,"amount":int(amount.value)}
			if not _has_room(pool, policy, int(amount.value)): continue
			if not policy.has("choice_group"):
				_commit(actor, trigger, occurrence, offer)
				continue
			var group := str(policy.choice_group)
			if not groups.has(group): groups[group] = []
			groups[group].append(offer)
	for group in groups:
		_serial += 1
		var request_id := "pool_recovery:%d" % _serial
		var offers: Array = groups[group]
		var public_offers: Array[Dictionary] = []
		for index in offers.size():
			var offer: Dictionary = offers[index]
			public_offers.append({"selection_id":str(index),"source_instance_id":offer.source_id,"label":"%s / %s" % [str(offer.feature.get("name", "Pool")),str(offer.source_id)],"mode":str(offer.definition.resource_pool.recovery[trigger].mode),"amount":offer.amount,"current":int(offer.pool.current),"capacity":int(offer.pool.capacity)})
		_pending[request_id] = {"actor":actor,"trigger":trigger,"occurrence":occurrence,"offers":offers}
		requests.append({"request_id":request_id,"owner_id":actor.character_id,"trigger":trigger,"group":str(group),"offers":public_offers})
	return requests

func settle(request_id: String, actor: Character, selection_id: String) -> Dictionary:
	var window: Dictionary = _pending.get(request_id, {})
	if window.is_empty() or window.actor != actor:
		return {"success":false,"message":"Stale or wrong-owner recovery request."}
	if selection_id.is_empty():
		_pending.erase(request_id)
		return {"success":true,"declined":true}
	var index := -1
	for candidate in window.offers.size():
		if selection_id == str(candidate): index = candidate
	if index < 0: return {"success":false,"message":"Unknown recovery option."}
	_pending.erase(request_id)
	return _commit(actor, str(window.trigger), int(window.occurrence), window.offers[index])

func _commit(actor: Character, trigger: String, occurrence: int, offer: Dictionary) -> Dictionary:
	var present := false
	for feature in actor.features:
		if is_same(feature, offer.feature) and feature == offer.definition: present = true
	var pool: Dictionary = actor.numeric_resource_pools.get(offer.source_id, {})
	if not present or not actor.is_alive or actor.is_dead() or not is_same(pool, offer.pool) or int(pool.get("capacity", -1)) != int(offer.capacity):
		return {"success":false,"message":"The selected recovery source changed or was removed."}
	var result := ResourcePoolRules.recover_combat(actor, offer.feature, str(offer.source_id), trigger, int(offer.amount))
	if result.get("success", false):
		result["occurrence"] = occurrence
		receipts.append(result.duplicate(true))
	return result

static func _has_room(pool: Dictionary, policy: Dictionary, amount: int) -> bool:
	if int(pool.current) >= int(pool.capacity): return false
	return policy.mode != "restore_to_floor" or int(pool.current) < mini(int(pool.capacity), amount)
