## Source-owned bounded numeric pools. Definitions stay immutable; mutable uses
## live on the exact owning Character under the exact source-instance identity.
class_name ResourcePoolRules
extends RefCounted

const MAX_CAPACITY := 100
const SUPPORTED_DIE_SIZES := [4, 6, 8, 10, 12, 20]
const REST_RECOVERY_MODES := ["restore_fixed", "restore_to_capacity"]
const REST_RECOVERY_TRIGGERS := ["short_rest_completed", "long_rest_completed"]


static func definition_error(definition: Dictionary) -> String:
	for field in ["resource_id", "uses", "uses_by_level", "uses_ability", "uses_per", "minimum_uses", "short_rest_recovery"]:
		if definition.has(field):
			return "A resource-pool definition cannot also declare legacy resource field '%s'." % field
	var pool: Variant = definition.get("resource_pool", {})
	if not pool is Dictionary or pool.is_empty():
		return "Resource pool definition is required."
	if not pool.get("id", "") is String or str(pool.get("id", "")).strip_edges().is_empty():
		return "Resource pool requires a nonempty definition ID."
	if not pool.has("capacity_formula") or pool["capacity_formula"] is String:
		return "Resource pool requires a capacity formula."
	var formula_error := SharedStepExecutor.formula_content_error(pool["capacity_formula"])
	if not formula_error.is_empty():
		return "Invalid resource pool capacity formula: %s" % formula_error
	var actor_formula_error := _actor_formula_error(pool["capacity_formula"])
	if not actor_formula_error.is_empty():
		return actor_formula_error
	if not pool.has("initial_quantity") or not _integer(pool["initial_quantity"], 0, MAX_CAPACITY):
		return "Resource pool initial_quantity must be an integer from 0 to 100."
	if pool.has("die_size"):
		if not _integer(pool["die_size"], 1, 20) or int(pool["die_size"]) not in SUPPORTED_DIE_SIZES:
			return "Resource-pool die_size must be an explicitly authored supported die size."
		var spend_choice: Variant = pool.get("spend_choice", {})
		if not spend_choice is Dictionary:
			return "A dice pool requires a bounded spend_choice with minimum and maximum quantities."
		for field in spend_choice:
			if field not in ["minimum", "maximum"]:
				return "Dice-pool spend_choice contains an unsupported field."
		if not _integer(spend_choice.get("minimum", null), 1, MAX_CAPACITY) or not _integer(spend_choice.get("maximum", null), 1, MAX_CAPACITY) or int(spend_choice["minimum"]) > int(spend_choice["maximum"]):
			return "Dice-pool spend_choice quantities must be positive and ordered from 1 to 100."
	elif pool.has("spend_choice"):
		return "Only a dice pool can declare spend_choice."
	var recovery: Variant = pool.get("recovery", {})
	if not recovery is Dictionary:
		return "Resource pool recovery must map completed-rest triggers to policies."
	for trigger in recovery:
		if not trigger is String or str(trigger) not in REST_RECOVERY_TRIGGERS:
			return "Resource pool recovery uses an unsupported completed-rest trigger."
		var policy: Variant = recovery[trigger]
		if not policy is Dictionary:
			return "Resource pool recovery policies must be objects."
		for field in policy:
			if field not in ["mode", "amount"]:
				return "Resource pool recovery policy contains an unsupported field."
		var mode := str(policy.get("mode", ""))
		if mode not in REST_RECOVERY_MODES:
			return "Resource pool recovery mode must be restore_fixed or restore_to_capacity."
		if mode == "restore_fixed":
			if not _integer(policy.get("amount", null), 1, MAX_CAPACITY):
				return "Fixed resource-pool recovery amount must be an integer from 1 to 100."
		elif policy.has("amount"):
			return "restore_to_capacity resource-pool recovery does not accept an amount."
	return ""


static func acquire(character: Character, definition: Dictionary, source_instance_id: String) -> Dictionary:
	var error := definition_error(definition)
	if not error.is_empty():
		return {"success": false, "message": error}
	if character == null or character.character_id.strip_edges().is_empty():
		return {"success": false, "message": "A pool requires an identified owning actor."}
	if source_instance_id.strip_edges().is_empty():
		return {"success": false, "message": "A pool requires an exact source-instance identity."}
	if character.numeric_resource_pools.has(source_instance_id):
		return {"success": false, "message": "That source instance already owns a resource pool."}
	var capacity_result := SharedStepExecutor.evaluate_actor_formula(definition["resource_pool"]["capacity_formula"], character)
	if not capacity_result.get("success", false) or not _integer(capacity_result.get("value", null), 0, MAX_CAPACITY):
		return {"success": false, "message": "Resource pool capacity must resolve to an integer from 0 to 100."}
	var capacity := int(capacity_result["value"])
	var initial := int(definition["resource_pool"]["initial_quantity"])
	if initial > capacity:
		return {"success": false, "message": "Initial quantity cannot exceed calculated capacity."}
	var owned_pool := {
		"owner_id": character.character_id,
		"source_instance_id": source_instance_id,
		"definition_id": str(definition["resource_pool"]["id"]),
		"capacity": capacity,
		"current": initial,
	}
	if definition["resource_pool"].has("die_size"):
		owned_pool["die_size"] = int(definition["resource_pool"]["die_size"])
		owned_pool["activation_serial"] = 0
	character.numeric_resource_pools[source_instance_id] = owned_pool
	return {"success": true, "pool": character.numeric_resource_pools[source_instance_id].duplicate(true)}


static func recalculate_capacity(character: Character, definition: Dictionary, source_instance_id: String) -> Dictionary:
	var error := definition_error(definition)
	if not error.is_empty():
		return {"success": false, "message": error}
	var owned := _owned_pool(character, source_instance_id)
	if owned.is_empty() or str(owned.get("definition_id", "")) != str(definition["resource_pool"]["id"]):
		return {"success": false, "message": "The exact source instance does not own this pool definition."}
	var capacity_result := SharedStepExecutor.evaluate_actor_formula(definition["resource_pool"]["capacity_formula"], character)
	if not capacity_result.get("success", false) or not _integer(capacity_result.get("value", null), 0, MAX_CAPACITY):
		return {"success": false, "message": "Resource pool capacity must resolve to an integer from 0 to 100."}
	var capacity := int(capacity_result["value"])
	owned["capacity"] = capacity
	owned["current"] = mini(int(owned["current"]), capacity)
	character.numeric_resource_pools[source_instance_id] = owned
	return {"success": true, "pool": owned.duplicate(true)}


static func availability(character: Character, source_instance_id: String) -> Dictionary:
	var owned := _owned_pool(character, source_instance_id)
	if owned.is_empty():
		return {"available": false, "current": 0, "capacity": 0, "message": "The exact source instance has no pool."}
	return {"available": int(owned["current"]) > 0, "current": int(owned["current"]), "capacity": int(owned["capacity"]), "owner_id": str(owned["owner_id"]), "source_instance_id": source_instance_id}


static func source_instance_ids(character: Character, definition_id: String) -> Array[String]:
	var source_ids: Array[String] = []
	if character == null or definition_id.strip_edges().is_empty():
		return source_ids
	for source_instance_id in character.numeric_resource_pools:
		var owned := _owned_pool(character, str(source_instance_id))
		if str(owned.get("definition_id", "")) == definition_id:
			source_ids.append(str(source_instance_id))
	source_ids.sort()
	return source_ids


static func spend(character: Character, source_instance_id: String, amount: int = 1) -> Dictionary:
	if amount < 1 or amount > MAX_CAPACITY:
		return {"success": false, "message": "Pool spend must be an integer from 1 to 100."}
	var owned := _owned_pool(character, source_instance_id)
	if owned.is_empty():
		return {"success": false, "message": "The exact source instance has no pool."}
	if int(owned["current"]) < amount:
		return {"success": false, "message": "The resource pool is depleted."}
	owned["current"] = int(owned["current"]) - amount
	character.numeric_resource_pools[source_instance_id] = owned
	return {"success": true, "current": int(owned["current"]), "capacity": int(owned["capacity"])}


static func exchange(character: Character, payment_source_id: String, restoration_source_id: String, payment_definition_id: String, payment_amount: int, restoration_definition_id: String, restoration_amount: int, commit: bool = true) -> Dictionary:
	if character == null or payment_source_id.strip_edges().is_empty() or restoration_source_id.strip_edges().is_empty():
		return {"success": false, "message": "An exchange requires exact payment and restoration sources."}
	if payment_source_id == restoration_source_id:
		return {"success": false, "message": "Payment and restoration require different source instances."}
	if payment_definition_id.strip_edges().is_empty() or restoration_definition_id.strip_edges().is_empty() or not _integer(payment_amount, 1, MAX_CAPACITY) or not _integer(restoration_amount, 1, MAX_CAPACITY):
		return {"success": false, "message": "The authored exchange must name two pools and fixed positive quantities."}
	var payment := _owned_pool(character, payment_source_id)
	var restoration := _owned_pool(character, restoration_source_id)
	if payment.is_empty() or restoration.is_empty() or str(payment.get("owner_id", "")) != character.character_id or str(restoration.get("owner_id", "")) != character.character_id:
		return {"success": false, "message": "Both exact pool sources must belong to this actor."}
	if str(payment.get("definition_id", "")) != payment_definition_id or str(restoration.get("definition_id", "")) != restoration_definition_id:
		return {"success": false, "message": "A selected source does not own the authored exchange pool."}
	for owned in [payment, restoration]:
		if not _integer(owned.get("capacity", null), 0, MAX_CAPACITY) or not _integer(owned.get("current", null), 0, MAX_CAPACITY) or int(owned["current"]) > int(owned["capacity"]):
			return {"success": false, "message": "A selected pool source has invalid numeric state."}
	if payment.has("die_size") or restoration.has("die_size"):
		return {"success": false, "message": "Exchanges support numeric pools only."}
	if int(payment.get("current", 0)) < payment_amount:
		return {"success": false, "message": "The selected payment pool has insufficient uses."}
	if int(restoration.get("capacity", 0)) - int(restoration.get("current", 0)) < restoration_amount:
		return {"success": false, "message": "The selected restoration pool lacks room for the full amount."}
	var payment_after := payment.duplicate(true)
	var restoration_after := restoration.duplicate(true)
	payment_after["current"] = int(payment["current"]) - payment_amount
	restoration_after["current"] = int(restoration["current"]) + restoration_amount
	if commit:
		character.numeric_resource_pools[payment_source_id] = payment_after
		character.numeric_resource_pools[restoration_source_id] = restoration_after
	return {"success": true, "payment_current": int(payment_after["current"]), "restoration_current": int(restoration_after["current"]), "payment_source_instance_id": payment_source_id, "restoration_source_instance_id": restoration_source_id}


static func exchange_restoration_sources(character: Character, payment_source_id: String, exchange_definition: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for restoration_source_id in source_instance_ids(character, str(exchange_definition.get("restoration_pool_id", ""))):
		var check := exchange(character, payment_source_id, restoration_source_id, str(exchange_definition.get("payment_pool_id", "")), int(exchange_definition.get("payment_quantity", 0)), str(exchange_definition.get("restoration_pool_id", "")), int(exchange_definition.get("restoration_quantity", 0)), false)
		if check.get("success", false):
			result.append(restoration_source_id)
	return result


static func exchange_payment_sources(character: Character, exchange_definition: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for payment_source_id in source_instance_ids(character, str(exchange_definition.get("payment_pool_id", ""))):
		if not exchange_restoration_sources(character, payment_source_id, exchange_definition).is_empty():
			result.append(payment_source_id)
	return result


static func begin_dice_activation(character: Character, source_instance_id: String, amount: int) -> Dictionary:
	var owned := _owned_pool(character, source_instance_id)
	if owned.is_empty() or not owned.has("die_size") or not _integer(owned.get("activation_serial", null), 0, 2147483647):
		return {"success": false, "message": "The exact source does not own a valid dice pool."}
	if int(owned["activation_serial"]) >= 2147483647:
		return {"success": false, "message": "This dice-pool source has reached its activation limit."}
	var pool_spend := spend(character, source_instance_id, amount)
	if not pool_spend.get("success", false):
		return pool_spend
	owned = _owned_pool(character, source_instance_id)
	owned["activation_serial"] = int(owned["activation_serial"]) + 1
	character.numeric_resource_pools[source_instance_id] = owned
	return {
		"success": true,
		"die_size": int(owned["die_size"]),
		"owner_id": str(owned["owner_id"]),
		"source_instance_id": source_instance_id,
		"activation_id": "%s:%d" % [source_instance_id, int(owned["activation_serial"])],
		"current": int(owned["current"]),
	}


static func recover(character: Character, definition: Dictionary, source_instance_id: String, trigger: String) -> Dictionary:
	var error := definition_error(definition)
	if not error.is_empty():
		return {"success": false, "message": error}
	if character == null or source_instance_id.strip_edges().is_empty():
		return {"success": false, "message": "Pool recovery requires its exact owning actor and source instance."}
	if trigger not in REST_RECOVERY_TRIGGERS:
		return {"success": false, "message": "Unsupported completed-rest trigger."}
	var pool_definition: Dictionary = definition["resource_pool"]
	var recovery: Dictionary = pool_definition.get("recovery", {})
	var policy: Dictionary = recovery.get(trigger, {})
	if policy.is_empty():
		return {"success": false, "message": "No recovery policy is defined for this completed rest."}
	var owned := _owned_pool(character, source_instance_id)
	if owned.is_empty() or str(owned.get("definition_id", "")) != str(pool_definition["id"]):
		return {"success": false, "message": "The exact source instance does not own this resource pool."}
	var before := int(owned["current"])
	var recovered := 0
	if str(policy["mode"]) == "restore_to_capacity":
		owned["current"] = int(owned["capacity"])
		recovered = int(owned["capacity"]) - before
	else:
		owned["current"] = mini(int(owned["capacity"]), before + int(policy["amount"]))
		recovered = int(owned["current"]) - before
	character.numeric_resource_pools[source_instance_id] = owned
	return {
		"success": true,
		"owner_id": character.character_id,
		"source_instance_id": source_instance_id,
		"definition_id": str(pool_definition["id"]),
		"trigger": trigger,
		"recovered": recovered,
		"current": int(owned["current"]),
		"capacity": int(owned["capacity"]),
	}


static func remove(character: Character, source_instance_id: String) -> bool:
	if character == null:
		return false
	var owned := _owned_pool(character, source_instance_id)
	if owned.is_empty():
		return false
	character.numeric_resource_pools.erase(source_instance_id)
	character.remove_campaign_modifiers_from_source(source_instance_id)
	character.remove_campaign_modifier_cooldowns_from_source(source_instance_id)
	character.remove_next_melee_hit_grants_from_source(source_instance_id)
	character.remove_timed_temporary_hp_grants_from_source(source_instance_id)
	return true


static func saved_state_error(character_data: Dictionary) -> String:
	if not character_data.has("numeric_resource_pools"):
		return ""
	var pools: Variant = character_data["numeric_resource_pools"]
	if not pools is Dictionary:
		return "Saved numeric resource pools must be an object."
	var owner_id := str(character_data.get("character_id", ""))
	for source_instance_id in pools:
		var pool: Variant = pools[source_instance_id]
		if not pool is Dictionary:
			return "Saved numeric resource pool must be an object."
		if str(source_instance_id).strip_edges().is_empty() or str(pool.get("source_instance_id", "")) != str(source_instance_id) or str(pool.get("owner_id", "")) != owner_id:
			return "Saved numeric resource pool owner/source identity is invalid."
		if str(pool.get("definition_id", "")).strip_edges().is_empty():
			return "Saved numeric resource pool definition ID is missing."
		if not _integer(pool.get("capacity", null), 0, MAX_CAPACITY) or not _integer(pool.get("current", null), 0, MAX_CAPACITY) or int(pool["current"]) > int(pool["capacity"]):
			return "Saved numeric resource pool quantity is outside its capacity."
		if pool.has("die_size"):
			if not _integer(pool["die_size"], 1, 20) or int(pool["die_size"]) not in SUPPORTED_DIE_SIZES or not _integer(pool.get("activation_serial", null), 0, 2147483647):
				return "Saved dice-pool metadata is invalid."
	return ""


static func _owned_pool(character: Character, source_instance_id: String) -> Dictionary:
	if character == null or source_instance_id.strip_edges().is_empty():
		return {}
	var pool: Variant = character.numeric_resource_pools.get(source_instance_id, {})
	if not pool is Dictionary or str(pool.get("owner_id", "")) != character.character_id or str(pool.get("source_instance_id", "")) != source_instance_id:
		return {}
	return pool.duplicate(true)


static func _integer(value: Variant, minimum: int, maximum: int) -> bool:
	return not value is bool and (value is int or value is float) and is_finite(float(value)) and float(value) == floor(float(value)) and int(value) >= minimum and int(value) <= maximum


static func _actor_formula_error(value: Variant) -> String:
	if value is String:
		return "Resource pool capacity formulas cannot roll dice."
	if value is int or value is float:
		return ""
	if not value is Dictionary:
		return "Resource pool capacity formula contains an unsupported value."
	if value.has("result") or value.has("selected_slot_level"):
		return "Resource pool capacity formulas require actor-only values."
	if str(value.get("op", "")) == "breakpoint_lookup":
		return _actor_formula_error(value.get("input"))
	if value.has("caster_level") or value.has("caster_proficiency_bonus") or value.has("caster_class_level") or value.has("caster_ability_modifier"):
		return ""
	var left_error := _actor_formula_error(value.get("left"))
	if not left_error.is_empty():
		return left_error
	return _actor_formula_error(value.get("right"))
