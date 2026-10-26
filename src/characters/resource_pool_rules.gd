## Source-owned bounded numeric pools. Definitions stay immutable; mutable uses
## live on the exact owning Character under the exact source-instance identity.
class_name ResourcePoolRules
extends RefCounted

## Short-lived result-payment reservations live only while an owned roll/choice
## is being settled. They deliberately do not change the saved pool quantity.
static var _payment_reservations: Dictionary = {}
static var _payment_reservation_serial: int = 0

const MAX_CAPACITY := 100
const SUPPORTED_DIE_SIZES := [4, 6, 8, 10, 12, 20]
const REST_RECOVERY_MODES := ["restore_fixed", "restore_to_capacity"]
const REST_RECOVERY_TRIGGERS := ["short_rest_completed", "long_rest_completed"]
const CAMPAIGN_RECOVERY_TRIGGERS := ["dawn", "dusk", "cooldown"]


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
		if not die_size_error(pool["die_size"]).is_empty():
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
	if pool.has("capture_policy") or pool.has("upgrade_policy"):
		if not pool.has("die_size") or pool.get("capture_policy") != "on_acquire" or pool.get("upgrade_policy") != "new_dice_only":
			return "Captured pools require dice, capture_policy on_acquire and upgrade_policy new_dice_only."
	var recovery: Variant = pool.get("recovery", {})
	if not recovery is Dictionary:
		return "Resource pool recovery must map completed-rest triggers to policies."
	for trigger in recovery:
		if trigger in CombatPoolRecovery.TRIGGERS:
			var combat_error := CombatPoolRecovery.policy_error(recovery[trigger])
			if not combat_error.is_empty(): return combat_error
			if pool.has("die_size"): return "Combat-event recovery currently requires a numeric pool."
			continue
		if trigger in CAMPAIGN_RECOVERY_TRIGGERS:
			var timed_error := campaign_policy_error(str(trigger), recovery[trigger])
			if not timed_error.is_empty(): return timed_error
			if pool.has("die_size"): return "Campaign-time recovery currently requires a numeric pool."
			continue
		if not trigger is String or str(trigger) not in REST_RECOVERY_TRIGGERS:
			return "Resource pool recovery uses an unsupported rest or campaign-time trigger."
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


static func campaign_policy_error(trigger: String, raw_policy: Variant) -> String:
	if not raw_policy is Dictionary:
		return "Campaign-time recovery policies must be objects."
	var policy: Dictionary = raw_policy
	var allowed := ["mode", "amount", "amount_dice"]
	if trigger == "cooldown": allowed.append("cooldown_seconds")
	for field in policy:
		if field not in allowed: return "Campaign-time recovery policy contains unsupported field '%s'." % str(field)
	var mode := str(policy.get("mode", ""))
	if mode not in ["restore_fixed", "restore_to_capacity"]:
		return "Campaign-time recovery mode must be restore_fixed or restore_to_capacity."
	if trigger == "cooldown" and not _integer(policy.get("cooldown_seconds", null), 1, 2147483647):
		return "Cooldown recovery requires a positive cooldown_seconds value."
	if mode == "restore_to_capacity":
		if policy.has("amount") or policy.has("amount_dice"):
			return "restore_to_capacity does not accept an amount or amount_dice."
		return ""
	if policy.has("amount") == policy.has("amount_dice"):
		return "restore_fixed requires exactly one of amount or amount_dice."
	if policy.has("amount") and not _integer(policy.amount, 1, MAX_CAPACITY):
		return "Fixed campaign-time recovery amount must be an integer from 1 to 100."
	if policy.has("amount_dice"):
		var dice: Variant = policy.amount_dice
		if not dice is Dictionary or dice.size() != 2 or not _integer(dice.get("count", null), 1, 10) or not _integer(dice.get("faces", null), 2, 100):
			return "Rolled campaign-time recovery requires count and faces within supported limits."
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
	var timed_recovery: Dictionary = definition.resource_pool.get("recovery", {})
	var cooldown_policy: Dictionary = timed_recovery.get("cooldown", {})
	if not cooldown_policy.is_empty():
		owned_pool["cooldown_seconds"] = int(cooldown_policy.cooldown_seconds)
		owned_pool["cooldown_ready_at_seconds"] = 0
	owned_pool["recovery_occurrences"] = {}
	if definition["resource_pool"].has("die_size"):
		var die := evaluate_die_size(definition["resource_pool"]["die_size"], character)
		if not die.get("success", false): return {"success":false,"message":"Source die progression is unavailable."}
		owned_pool["die_size"] = int(die.value)
		owned_pool["activation_serial"] = 0
		if definition.resource_pool.has("capture_policy"):
			owned_pool["capture_policy"] = "on_acquire"
			owned_pool["upgrade_policy"] = "new_dice_only"
			owned_pool["die_serial"] = int(character.transferred_die_serials.get(source_instance_id, 0))
			owned_pool["captured_dice"] = []
			if int(owned_pool.die_serial) > 2147483647 - initial: return {"success":false, "message":"Transferred die identity limit reached."}
			_append_captured_dice(character, owned_pool, initial)
	character.numeric_resource_pools[source_instance_id] = owned_pool
	return {"success": true, "pool": character.numeric_resource_pools[source_instance_id].duplicate(true)}


static func recalculate_capacity(character: Character, definition: Dictionary, source_instance_id: String) -> Dictionary:
	var error := definition_error(definition)
	if not error.is_empty():
		return {"success": false, "message": error}
	var owned := _owned_pool(character, source_instance_id)
	if owned.is_empty() or str(owned.get("definition_id", "")) != str(definition["resource_pool"]["id"]):
		return {"success": false, "message": "The exact source instance does not own this pool definition."}
	if owned.has("captured_dice") != definition.resource_pool.has("capture_policy"):
		return {"success": false, "message": "Pool capture policy cannot change after acquisition."}
	var capacity_result := SharedStepExecutor.evaluate_actor_formula(definition["resource_pool"]["capacity_formula"], character)
	if not capacity_result.get("success", false) or not _integer(capacity_result.get("value", null), 0, MAX_CAPACITY):
		return {"success": false, "message": "Resource pool capacity must resolve to an integer from 0 to 100."}
	var capacity := int(capacity_result["value"])
	if definition.resource_pool.has("die_size"):
		var die := evaluate_die_size(definition.resource_pool.die_size, character)
		if not die.get("success", false): return {"success":false,"message":"Source die progression is unavailable."}
		owned["die_size"] = int(die.value)
	owned["capacity"] = capacity
	owned["current"] = mini(int(owned["current"]), capacity)
	if owned.has("captured_dice"):
		owned["captured_dice"].resize(int(owned.current))
	character.numeric_resource_pools[source_instance_id] = owned
	return {"success": true, "pool": owned.duplicate(true)}


static func availability(character: Character, source_instance_id: String) -> Dictionary:
	var owned := _owned_pool(character, source_instance_id)
	if owned.is_empty():
		return {"available": false, "current": 0, "reserved": 0, "spendable": 0, "capacity": 0, "message": "The exact source instance has no pool."}
	var reserved := _reserved_quantity(character, source_instance_id)
	var spendable := maxi(0, int(owned["current"]) - reserved)
	return {"available": spendable > 0, "current": int(owned["current"]), "reserved": reserved, "spendable": spendable, "capacity": int(owned["capacity"]), "owner_id": str(owned["owner_id"]), "source_instance_id": source_instance_id}


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
	if int(owned["current"]) - _reserved_quantity(character, source_instance_id) < amount:
		return {"success": false, "message": "The resource pool has insufficient unreserved uses."}
	owned["current"] = int(owned["current"]) - amount
	if int(owned.get("cooldown_seconds", 0)) > 0:
		var now_seconds := int(GameManager.campaign_elapsed_seconds) if GameManager != null else 0
		owned["cooldown_ready_at_seconds"] = now_seconds + int(owned.cooldown_seconds)
	var captured: Array = []
	if owned.has("captured_dice"):
		captured = owned.captured_dice.slice(0, amount).duplicate(true)
		owned["captured_dice"] = owned.captured_dice.slice(amount)
	character.numeric_resource_pools[source_instance_id] = owned
	return {"success": true, "current": int(owned["current"]), "capacity": int(owned["capacity"]), "captured_dice": captured}


## Reserve keeps the exact quantity unavailable to sibling uses without
## changing the pool. Requests are transient and must be settled or cleared.
static func spend_selected_dice(character: Character, source_instance_id: String, die_ids: Array) -> Dictionary:
	var owned := _owned_pool(character, source_instance_id)
	if owned.is_empty() or not owned.has("captured_dice") or die_ids.is_empty() or die_ids.size() > int(owned.current) - _reserved_quantity(character, source_instance_id): return {"success":false}
	var selected: Array = []
	for id in die_ids:
		var found := false
		for die in owned.captured_dice:
			if die.die_id == id:
				if die in selected: return {"success":false}
				selected.append(die)
				found = true
		if not found: return {"success":false}
	owned.current = int(owned.current) - selected.size()
	owned.captured_dice = owned.captured_dice.filter(func(die): return die.die_id not in die_ids)
	character.numeric_resource_pools[source_instance_id] = owned
	return {"success":true, "current":owned.current, "captured_dice":selected.duplicate(true)}


static func reserve_payment(character: Character, source_instance_id: String, amount: int) -> Dictionary:
	if amount < 1 or amount > MAX_CAPACITY:
		return {"success": false, "message": "Pool reservation must be an integer from 1 to 100."}
	var owned := _owned_pool(character, source_instance_id)
	if owned.has("captured_dice"):
		return {"success": false, "message": "Captured dice cannot be reserved as numeric payments."}
	if owned.is_empty() or str(owned.get("owner_id", "")) != character.character_id:
		return {"success": false, "message": "The exact source instance has no owned pool."}
	if int(owned.get("current", 0)) - _reserved_quantity(character, source_instance_id) < amount:
		return {"success": false, "message": "The selected pool has insufficient unreserved uses."}
	_payment_reservation_serial += 1
	var reservation_id := "pool_payment_%d_%d" % [character.get_instance_id(), _payment_reservation_serial]
	var reservation := {
		"reservation_id": reservation_id,
		"owner": character,
		"owner_id": character.character_id,
		"source_instance_id": source_instance_id,
		"definition_id": str(owned.get("definition_id", "")),
		"amount": amount,
		"state": "reserved",
	}
	_payment_reservations[reservation_id] = reservation
	return {"success": true, "reservation": reservation.duplicate(false), "current": int(owned["current"]), "reserved": _reserved_quantity(character, source_instance_id), "spendable": maxi(0, int(owned["current"]) - _reserved_quantity(character, source_instance_id))}


## Commit charges the reserved exact source; refund only releases its lock.
static func settle_payment_reservation(reservation_id: String, commit: bool) -> Dictionary:
	if reservation_id.is_empty() or not _payment_reservations.has(reservation_id):
		return {"success": false, "message": "Unknown or already-settled payment reservation."}
	var reservation: Dictionary = _payment_reservations[reservation_id]
	if bool(reservation.get("source_lost", false)):
		_payment_reservations.erase(reservation_id)
		return {"success": false, "message": "The reserved source pool was removed; no payment was charged."}
	var owner = reservation.get("owner")
	var source_id := str(reservation.get("source_instance_id", ""))
	var pool := _owned_pool(owner, source_id) if owner is Character and is_instance_valid(owner) else {}
	if pool.is_empty() or str(pool.get("definition_id", "")) != str(reservation.get("definition_id", "")):
		_payment_reservations.erase(reservation_id)
		return {"success": false, "message": "The reserved source pool no longer exists; no payment was charged."}
	if commit:
		if int(pool.get("current", 0)) < int(reservation.get("amount", 0)):
			_payment_reservations.erase(reservation_id)
			return {"success": false, "message": "The reserved source can no longer pay; no payment was charged."}
		pool["current"] = int(pool["current"]) - int(reservation["amount"])
		owner.numeric_resource_pools[source_id] = pool
		reservation["state"] = "committed"
		var current := int(pool["current"])
		_payment_reservations.erase(reservation_id)
		return {"success": true, "state": "committed", "owner_id": str(reservation.get("owner_id", "")), "source_instance_id": source_id, "definition_id": str(reservation.get("definition_id", "")), "amount": int(reservation.get("amount", 0)), "current": current}
	reservation["state"] = "refunded"
	_payment_reservations.erase(reservation_id)
	return {"success": true, "state": "refunded", "owner_id": str(reservation.get("owner_id", "")), "source_instance_id": source_id, "definition_id": str(reservation.get("definition_id", "")), "amount": int(reservation.get("amount", 0)), "current": int(pool.get("current", 0))}


static func clear_payment_reservations() -> void:
	_payment_reservations.clear()


static func _reserved_quantity(character: Character, source_instance_id: String) -> int:
	var total := 0
	for reservation in _payment_reservations.values():
		if reservation.get("owner") == character and str(reservation.get("source_instance_id", "")) == source_instance_id and str(reservation.get("state", "")) == "reserved" and not bool(reservation.get("source_lost", false)):
			total += int(reservation.get("amount", 0))
	return total


static func exchange(character: Character, payment_source_id: String, restoration_source_id: String, payment_definition_id: String, payment_amount: int, restoration_definition_id: String, restoration_amount: int, commit: bool = true, allow_party_recipient: bool = false) -> Dictionary:
	if character == null or payment_source_id.strip_edges().is_empty() or restoration_source_id.strip_edges().is_empty():
		return {"success": false, "message": "An exchange requires exact payment and restoration sources."}
	var slot_payment := _slot_exchange_source(payment_source_id)
	var using_slot := not slot_payment.is_empty()
	var inventory_payment := _inventory_exchange_source(payment_source_id)
	var using_inventory := payment_source_id.begins_with("inventory-copies:")
	var using_pool := not using_slot and not using_inventory
	if not using_slot and payment_source_id == restoration_source_id:
		return {"success": false, "message": "Payment and restoration require different source instances."}
	if payment_definition_id.strip_edges().is_empty() or restoration_definition_id.strip_edges().is_empty() or not _integer(payment_amount, 1, MAX_CAPACITY) or not _integer(restoration_amount, 1, MAX_CAPACITY):
		return {"success": false, "message": "The authored exchange must name two pools and fixed positive quantities."}
	var destination := _party_pool_destination(restoration_source_id)
	var restoration_character: Character = character
	var exact_restoration_source_id := restoration_source_id
	if not destination.is_empty():
		if not allow_party_recipient:
			return {"success": false, "message": "This exchange does not allow another party member as recipient."}
		restoration_character = PartyManager.characters.get(str(destination.character_id)) as Character
		exact_restoration_source_id = str(destination.source_instance_id)
		if restoration_character == null or not _is_active_party_character(restoration_character):
			return {"success": false, "message": "The selected restoration recipient is no longer in the active party."}
	if using_pool and restoration_character == character and exact_restoration_source_id == payment_source_id:
		return {"success": false, "message": "Payment and restoration require different source instances."}
	var restoration := _owned_pool(restoration_character, exact_restoration_source_id)
	var payment := _owned_pool(character, payment_source_id) if using_pool else {}
	if using_inventory:
		if not payment_definition_id.begins_with("inventory:") or inventory_payment.size() != payment_amount or DataLoader.get_item(payment_definition_id.trim_prefix("inventory:")).is_empty():
			return {"success": false, "message": "Choose the exact authored inventory quantity."}
		character.inventory.copies.sync(character.inventory)
		for instance_id in inventory_payment:
			if not _inventory_exchange_eligible(character, instance_id, payment_definition_id.trim_prefix("inventory:")):
				return {"success": false, "message": "A selected payment copy is no longer eligible in this backpack."}
	if restoration.is_empty() or (using_pool and payment.is_empty()) or (using_pool and str(payment.get("owner_id", "")) != character.character_id) or str(restoration.get("owner_id", "")) != restoration_character.character_id:
		return {"success": false, "message": "Both exact pool sources must belong to their selected actors."}
	if (using_pool and str(payment.get("definition_id", "")) != payment_definition_id) or (using_slot and payment_definition_id != "spell_slots:%s" % slot_payment.pool_id) or str(restoration.get("definition_id", "")) != restoration_definition_id:
		return {"success": false, "message": "A selected source does not own the authored exchange pool."}
	for owned in ([payment, restoration] if using_pool else [restoration]):
		if not _integer(owned.get("capacity", null), 0, MAX_CAPACITY) or not _integer(owned.get("current", null), 0, MAX_CAPACITY) or int(owned["current"]) > int(owned["capacity"]):
			return {"success": false, "message": "A selected pool source has invalid numeric state."}
	if (using_pool and payment.has("die_size") and (not payment.has("captured_dice") or payment.get("captured_dice", []).size() != int(payment.get("current", 0)))) or restoration.has("die_size"):
		return {"success": false, "message": "Dice exchanges require captured payment dice and a numeric destination pool."}
	if (using_slot and SpellSlotRules.remaining(character, str(slot_payment.pool_id), int(slot_payment.level)) < payment_amount) or (using_pool and int(payment.get("current", 0)) - _reserved_quantity(character, payment_source_id) < payment_amount):
		return {"success": false, "message": "The selected payment pool has insufficient uses."}
	if int(restoration.get("capacity", 0)) - int(restoration.get("current", 0)) < restoration_amount:
		return {"success": false, "message": "The selected restoration pool lacks room for the full amount."}
	var payment_after := payment.duplicate(true)
	var restoration_after := restoration.duplicate(true)
	if using_pool: payment_after["current"] = int(payment["current"]) - payment_amount
	restoration_after["current"] = int(restoration["current"]) + restoration_amount
	if commit:
		if using_slot:
			for _index in payment_amount:
				if not SpellSlotRules.spend(character, str(slot_payment.pool_id), int(slot_payment.level)):
					return {"success": false, "message": "The selected spell-slot pool changed before commitment."}
		elif using_inventory:
			# All copies and the full destination were checked above. No await or
			# callbacks occur between validation and these ordinary backpack removals.
			for instance_id in inventory_payment:
				character.inventory.take_instance(instance_id, "destruction")
		else:
			if payment.has("captured_dice"):
				payment_after["captured_dice"] = payment.captured_dice.slice(payment_amount).duplicate(true)
			character.numeric_resource_pools[payment_source_id] = payment_after
		restoration_character.numeric_resource_pools[exact_restoration_source_id] = restoration_after
	var payment_current := int(payment_after.get("current", 0))
	if using_slot: payment_current = SpellSlotRules.remaining(character, str(slot_payment.pool_id), int(slot_payment.level))
	if using_inventory: payment_current = character.inventory.count_item(payment_definition_id.trim_prefix("inventory:")) - (0 if commit else payment_amount)
	return {"success": true, "payment_current": payment_current, "restoration_current": int(restoration_after["current"]), "payment_source_instance_id": payment_source_id, "restoration_source_instance_id": exact_restoration_source_id, "restoration_character_id": restoration_character.character_id, "captured_dice_spent": payment.captured_dice.slice(0, payment_amount).duplicate(true) if payment.has("captured_dice") else [], "inventory_copies_spent": inventory_payment.duplicate()}


static func exchange_restoration_sources(character: Character, payment_source_id: String, exchange_definition: Dictionary) -> Array[String]:
	var result: Array[String] = []
	var allow_party := str(exchange_definition.get("restoration_recipient", "self")) == "party_member"
	for recipient in _exchange_recipients(character, allow_party):
		for source_id in source_instance_ids(recipient, str(exchange_definition.get("restoration_pool_id", ""))):
			var choice_id := source_id if recipient == character else _party_pool_token(recipient.character_id, source_id)
			var check := exchange(character, payment_source_id, choice_id, str(exchange_definition.get("payment_pool_id", "")), int(exchange_definition.get("payment_quantity", 0)), str(exchange_definition.get("restoration_pool_id", "")), int(exchange_definition.get("restoration_quantity", 0)), false, allow_party)
			if check.get("success", false): result.append(choice_id)
	return result


static func exchange_payment_sources(character: Character, exchange_definition: Dictionary) -> Array[String]:
	var result: Array[String] = []
	var slot_pool := str(exchange_definition.get("payment_pool_id", ""))
	if slot_pool.begins_with("inventory:"):
		var item_id := slot_pool.trim_prefix("inventory:")
		var quantity := int(exchange_definition.get("payment_quantity", 0))
		var copies: Array[String] = []
		character.inventory.copies.sync(character.inventory)
		for instance_id in character.inventory.copies.backpack:
			if _inventory_exchange_eligible(character, instance_id, item_id): copies.append(instance_id)
		if quantity > 0 and copies.size() >= quantity:
			var token := "inventory-copies:" + JSON.stringify(copies.slice(0, quantity))
			if not exchange_restoration_sources(character, token, exchange_definition).is_empty(): result.append(token)
		return result
	if slot_pool in ["spell_slots:ordinary", "spell_slots:pact"]:
		var pool_id := slot_pool.trim_prefix("spell_slots:")
		for row in SpellSlotRules.pool_rows(character):
			if str(row.pool_id) == pool_id and int(row.remaining) >= int(exchange_definition.get("payment_quantity", 0)):
				var token := _slot_exchange_token(pool_id, int(row.level))
				if not exchange_restoration_sources(character, token, exchange_definition).is_empty(): result.append(token)
		return result
	for payment_source_id in source_instance_ids(character, str(exchange_definition.get("payment_pool_id", ""))):
		if not exchange_restoration_sources(character, payment_source_id, exchange_definition).is_empty():
			result.append(payment_source_id)
	return result


static func exchange_restoration_label(character: Character, source_id: String) -> String:
	var destination := _party_pool_destination(source_id)
	if destination.is_empty(): return "Restore to %s" % source_id
	var recipient: Character = PartyManager.characters.get(str(destination.character_id)) as Character
	return "Restore to %s: %s" % [recipient.character_name if recipient != null else str(destination.character_id), str(destination.source_instance_id)]


static func _party_pool_token(character_id: String, source_instance_id: String) -> String:
	return "party-pool:" + JSON.stringify([character_id, source_instance_id])


static func _party_pool_destination(value: String) -> Dictionary:
	if not value.begins_with("party-pool:"): return {}
	var decoded: Variant = JSON.parse_string(value.trim_prefix("party-pool:"))
	if not decoded is Array or decoded.size() != 2 or str(decoded[0]).is_empty() or str(decoded[1]).is_empty(): return {}
	return {"character_id": str(decoded[0]), "source_instance_id": str(decoded[1])}


static func _exchange_recipients(character: Character, allow_party: bool) -> Array[Character]:
	var result: Array[Character] = [character]
	if allow_party:
		for member in PartyManager.get_active_characters():
			if member != null and not result.has(member): result.append(member)
	return result


static func _is_active_party_character(character: Character) -> bool:
	return PartyManager.get_active_characters().has(character)


static func exchange_payment_label(character: Character, source_id: String) -> String:
	var inventory := _inventory_exchange_source(source_id)
	if not inventory.is_empty():
		var item := character.inventory.get_instance(inventory[0])
		return "%d × %s (backpack)" % [inventory.size(), DataLoader.get_item(str(item.get("definition_id", ""))).get("name", "item")]
	var slot := _slot_exchange_source(source_id)
	if not slot.is_empty():
		return "%s level %d spell slot" % ["Pact" if str(slot.pool_id) == "pact" else "Ordinary", int(slot.level)]
	var pool := _owned_pool(character, source_id)
	return "%s (%d remaining)" % [source_id, int(pool.get("current", 0))]


static func _inventory_exchange_source(source_id: String) -> Array[String]:
	var result: Array[String] = []
	if not source_id.begins_with("inventory-copies:"): return result
	var decoded: Variant = JSON.parse_string(source_id.trim_prefix("inventory-copies:"))
	if not decoded is Array or decoded.is_empty() or decoded.size() > Inventory.MAX_BACKPACK_SIZE: return result
	for instance_id in decoded:
		if not instance_id is String or instance_id.is_empty() or result.has(instance_id): return []
		result.append(instance_id)
	return result


static func _inventory_exchange_eligible(character: Character, instance_id: String, item_id: String) -> bool:
	var record: Dictionary = character.inventory.copies.records.get(instance_id, {})
	return instance_id in character.inventory.copies.backpack and str(record.get("definition_id", "")) == item_id and not bool(record.get("state", {}).get("cursed_attunement", false))


static func _slot_exchange_token(pool_id: String, level: int) -> String:
	return "spell-slot/%s/%d" % [pool_id, level]


static func _slot_exchange_source(source_id: String) -> Dictionary:
	var pieces := source_id.split("/")
	if pieces.size() != 3 or pieces[0] != "spell-slot" or pieces[1] not in ["ordinary", "pact"] or not pieces[2].is_valid_int(): return {}
	var level := int(pieces[2])
	return {"pool_id": pieces[1], "level": level} if level >= 1 and level <= 9 else {}


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
		"captured_dice": pool_spend.get("captured_dice", []),
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
	if owned.has("captured_dice") != pool_definition.has("capture_policy"):
		return {"success": false, "message": "Pool capture policy cannot change after acquisition."}
	return _apply_recovery(character, owned, policy, trigger, int(policy.get("amount", 0)))


static func recover_selected_quantity(character: Character, source_instance_id: String, definition_id: String, quantity: int, expected_current: int, expected_capacity: int) -> Dictionary:
	if character == null or source_instance_id.strip_edges().is_empty() or not _integer(quantity, 1, MAX_CAPACITY):
		return {"success":false,"message":"Selected recovery requires an exact source and positive quantity."}
	var owned := _owned_pool(character, source_instance_id)
	if owned.is_empty() or owned.has("die_size") or str(owned.get("definition_id", "")) != definition_id:
		return {"success":false,"message":"The selected exact numeric pool is no longer owned."}
	if int(owned.get("current", -1)) != expected_current or int(owned.get("capacity", -1)) != expected_capacity:
		return {"success":false,"message":"The selected exact pool changed while recovery was open."}
	if quantity > expected_capacity - expected_current:
		return {"success":false,"message":"Selected pool recovery exceeds its remaining capacity."}
	owned["current"] = expected_current + quantity
	character.numeric_resource_pools[source_instance_id] = owned
	return {"success":true,"owner_id":character.character_id,"source_instance_id":source_instance_id,"definition_id":definition_id,"before":expected_current,"recovered":quantity,"current":int(owned.current),"capacity":expected_capacity}


## The encounter owner captures and validates the event/selection; this owns quantities.
static func recover_combat(character: Character, definition: Dictionary, source_instance_id: String, trigger: String, captured_amount: int) -> Dictionary:
	if character == null or trigger not in CombatPoolRecovery.TRIGGERS or not definition_error(definition).is_empty():
		return {"success": false, "message": "Invalid combat recovery definition or actor."}
	var policy: Dictionary = definition.resource_pool.get("recovery", {}).get(trigger, {})
	var amount := CombatPoolRecovery.policy_amount(policy, character)
	if not amount.get("success", false) or int(amount.value) != captured_amount:
		return {"success": false, "message": "The captured recovery amount is no longer available."}
	var owned := _owned_pool(character, source_instance_id)
	if owned.is_empty() or owned.has("die_size") or str(owned.definition_id) != str(definition.resource_pool.id):
		return {"success": false, "message": "The exact recovery source is no longer owned."}
	return _apply_recovery(character, owned, policy, trigger, captured_amount)


static func _apply_recovery(character: Character, owned: Dictionary, policy: Dictionary, trigger: String, amount: int) -> Dictionary:
	var before := int(owned["current"])
	var after := int(owned.capacity)
	if str(policy.mode) == "restore_fixed": after = mini(int(owned.capacity), before + amount)
	elif str(policy.mode) == "restore_to_floor": after = maxi(before, mini(int(owned.capacity), amount))
	var requested := after - before
	if owned.has("captured_dice") and int(owned.die_serial) > 2147483647 - requested:
		return {"success": false, "message": "Captured dice identities exhausted."}
	var recovered := requested
	owned["current"] = after
	if owned.has("captured_dice"):
		_append_captured_dice(character, owned, recovered)
	character.numeric_resource_pools[str(owned.source_instance_id)] = owned
	return {
		"success": true,
		"owner_id": character.character_id,
		"source_instance_id": str(owned.source_instance_id),
		"definition_id": str(owned.definition_id),
		"trigger": trigger,
		"before": before,
		"recovered": recovered,
		"current": int(owned["current"]),
		"capacity": int(owned["capacity"]),
	}


## Settle authored dawn/dusk/cooldown recoveries at their scheduled campaign
## occurrence. The per-source cursor lives with the already-saved pool.
static func advance_campaign_recovery(character: Character, prior_seconds: int, current_seconds: int) -> Array[Dictionary]:
	var receipts: Array[Dictionary] = []
	if character == null or current_seconds <= prior_seconds: return receipts
	for source_id_variant in character.numeric_resource_pools.keys():
		var source_id := str(source_id_variant)
		var owned := _owned_pool(character, source_id)
		if owned.is_empty() or owned.has("die_size"): continue
		var definition := _find_pool_definition(character, str(owned.get("definition_id", "")))
		if definition.is_empty(): continue
		var recovery: Dictionary = definition.get("resource_pool", {}).get("recovery", {})
		for trigger in CAMPAIGN_RECOVERY_TRIGGERS:
			if not recovery.has(trigger): continue
			var policy: Dictionary = recovery[trigger]
			if trigger == "cooldown":
				var ready_at := int(owned.get("cooldown_ready_at_seconds", 0))
				if ready_at <= 0 or ready_at > current_seconds: continue
				var occurrence_key := "cooldown"
				if int(owned.get("recovery_occurrences", {}).get(occurrence_key, 0)) >= ready_at: continue
				var amount := _campaign_recovery_amount(character, policy)
				var receipt := _apply_recovery(character, owned, policy, trigger, amount)
				owned = _owned_pool(character, source_id)
				owned.recovery_occurrences[occurrence_key] = ready_at
				owned.cooldown_ready_at_seconds = 0
				character.numeric_resource_pools[source_id] = owned
				if receipt.get("success", false):
					receipt["occurrence_at_seconds"] = ready_at
					receipts.append(receipt)
			else:
				for occurrence_at in _daily_occurrences(trigger, prior_seconds, current_seconds):
					var last_at := int(owned.get("recovery_occurrences", {}).get(trigger, 0))
					if occurrence_at <= last_at: continue
					var rolled_amount := _campaign_recovery_amount(character, policy)
					var daily_receipt := _apply_recovery(character, owned, policy, trigger, rolled_amount)
					owned = _owned_pool(character, source_id)
					var cursors: Dictionary = owned.get("recovery_occurrences", {})
					cursors[trigger] = occurrence_at
					owned["recovery_occurrences"] = cursors
					character.numeric_resource_pools[source_id] = owned
					if daily_receipt.get("success", false):
						daily_receipt["occurrence_at_seconds"] = occurrence_at
						receipts.append(daily_receipt)
	return receipts


static func _daily_occurrences(trigger: String, prior_seconds: int, current_seconds: int) -> Array[int]:
	var occurrences: Array[int] = []
	var offset := 21600 if trigger == "dawn" else 64800
	var day := floori(float(prior_seconds - offset) / 86400.0) + 1
	var due := day * 86400 + offset
	while due <= current_seconds:
		if due > prior_seconds: occurrences.append(due)
		due += 86400
	return occurrences


static func _campaign_recovery_amount(character: Character, policy: Dictionary) -> int:
	if str(policy.get("mode", "")) == "restore_to_capacity": return 0
	if policy.has("amount"): return int(policy.amount)
	var dice: Dictionary = policy.get("amount_dice", {})
	var total := 0
	for index in int(dice.get("count", 0)):
		total += Dice.roll(int(dice.get("faces", 0)), character)
	return maxi(1, total)


static func _find_pool_definition(character: Character, definition_id: String) -> Dictionary:
	for source in [DataLoader.get_character_class(character.class_id), DataLoader.get_subclass(character.subclass_id)]:
		for features in source.get("features_by_level", {}).values():
			for feature in features:
				if feature is Dictionary and str(feature.get("resource_pool", {}).get("id", "")) == definition_id:
					return feature.duplicate(true)
	return {}


static func remove(character: Character, source_instance_id: String) -> bool:
	if character == null:
		return false
	var owned := _owned_pool(character, source_instance_id)
	if owned.is_empty():
		return false
	for reservation_id in _payment_reservations.keys():
		var reservation: Dictionary = _payment_reservations[reservation_id]
		if reservation.get("owner") == character and str(reservation.get("source_instance_id", "")) == source_instance_id and str(reservation.get("state", "")) == "reserved":
			reservation["source_lost"] = true
			_payment_reservations[reservation_id] = reservation
	character.numeric_resource_pools.erase(source_instance_id)
	character.remove_campaign_modifiers_from_source(source_instance_id)
	character.remove_campaign_modifier_cooldowns_from_source(source_instance_id)
	character.remove_next_melee_hit_grants_from_source(source_instance_id)
	TemporaryHPRules.remove_source(character, source_instance_id)
	character.remove_timed_temporary_hp_grants_from_source(source_instance_id)
	ProtectionRules.remove_source(character,source_instance_id)
	return true


static func saved_state_error(character_data: Dictionary) -> String:
	if not character_data.has("numeric_resource_pools"):
		return ""
	var pools: Variant = character_data["numeric_resource_pools"]
	if not pools is Dictionary:
		return "Saved numeric resource pools must be an object."
	var owner_id := str(character_data.get("character_id", ""))
	var declared_pools: Dictionary = {}
	for source in [DataLoader.get_character_class(str(character_data.get("class_id", ""))), DataLoader.get_subclass(str(character_data.get("subclass_id", "")))]:
		for features in source.get("features_by_level", {}).values():
			for feature in features:
				if feature is Dictionary and feature.get("resource_pool") is Dictionary:
					declared_pools[str(feature.resource_pool.get("id", ""))] = feature.resource_pool
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
		if pool.has("cooldown_seconds") or pool.has("cooldown_ready_at_seconds"):
			if not _integer(pool.get("cooldown_seconds", null), 1, 2147483647) or not _integer(pool.get("cooldown_ready_at_seconds", null), 0, 2147483647):
				return "Saved resource-pool cooldown state is invalid."
		if pool.has("recovery_occurrences"):
			var occurrences: Variant = pool.recovery_occurrences
			if not occurrences is Dictionary: return "Saved resource-pool recovery occurrences are invalid."
			for trigger in occurrences:
				if trigger not in CAMPAIGN_RECOVERY_TRIGGERS or not _integer(occurrences[trigger], 1, 2147483647):
					return "Saved resource-pool recovery occurrence is invalid."
		if pool.has("die_size"):
			if not _integer(pool["die_size"], 1, 20) or int(pool["die_size"]) not in SUPPORTED_DIE_SIZES or not _integer(pool.get("activation_serial", null), 0, 2147483647):
				return "Saved dice-pool metadata is invalid."
		var captured_error := _captured_state_error(pool)
		if not captured_error.is_empty(): return captured_error
		var declared: Dictionary = declared_pools.get(str(pool.definition_id), {})
		var declared_recovery: Dictionary = declared.get("recovery", {})
		if declared_recovery.has("cooldown") != pool.has("cooldown_seconds"):
			return "Saved resource-pool cooldown policy does not match its definition."
		if pool.has("recovery_occurrences"):
			for trigger in pool.recovery_occurrences:
				if not declared_recovery.has(trigger): return "Saved recovery occurrence has no matching authored policy."
		if declared.has("capture_policy") != pool.has("captured_dice"):
			return "Saved pool capture policy does not match its owned definition."
	return ""


static func _captured_state_error(pool: Dictionary) -> String:
	var tagged := pool.has("capture_policy") or pool.has("upgrade_policy") or pool.has("captured_dice") or pool.has("die_serial")
	if not tagged: return ""
	if not pool.has("die_size") or pool.get("capture_policy") != "on_acquire" or pool.get("upgrade_policy") != "new_dice_only" or not _integer(pool.get("die_serial"), 0, 2147483647):
		return "Saved captured-dice policy/serial is invalid."
	var dice: Variant = pool.get("captured_dice")
	if not dice is Array or dice.size() != int(pool.get("current", -1)) or dice.size() > MAX_CAPACITY:
		return "Saved captured dice do not match remaining quantity."
	var previous := 0
	for die in dice:
		if not die is Dictionary: return "Saved captured die must be an object."
		if not _integer(die.get("serial"), previous + 1, int(pool.die_serial)) or die.get("die_id") != "%s:%s:die:%d" % [pool.owner_id, pool.source_instance_id, int(die.get("serial", 0))]:
			return "Saved captured die identity/order is invalid."
		if die.get("owner_id") != pool.owner_id or die.get("source_instance_id") != pool.source_instance_id:
			return "Saved captured die belongs to another owner/source."
		if not _integer(die.get("die_size"), 1, 20) or int(die.die_size) not in SUPPORTED_DIE_SIZES or not _integer(die.get("face"), 1, int(die.die_size)) or not _integer(die.get("generation_level"), 1, 20):
			return "Saved captured die face/size/level is invalid."
		previous = int(die.serial)
	return ""


static func _append_captured_dice(character: Character, pool: Dictionary, quantity: int) -> void:
	for index in quantity:
		pool.die_serial = int(pool.die_serial) + 1
		if character.transferred_die_serials.has(pool.source_instance_id): character.transferred_die_serials[pool.source_instance_id] = int(pool.die_serial)
		pool.captured_dice.append({
			"die_id": "%s:%s:die:%d" % [character.character_id, pool.source_instance_id, int(pool.die_serial)],
			"serial": int(pool.die_serial), "owner_id": character.character_id,
			"source_instance_id": str(pool.source_instance_id), "generation_level": character.level,
			"die_size": int(pool.die_size), "face": Dice.roll(int(pool.die_size), character),
		})


static func _owned_pool(character: Character, source_instance_id: String) -> Dictionary:
	if character == null or source_instance_id.strip_edges().is_empty():
		return {}
	var pool: Variant = character.numeric_resource_pools.get(source_instance_id, {})
	if not pool is Dictionary or str(pool.get("owner_id", "")) != character.character_id or str(pool.get("source_instance_id", "")) != source_instance_id:
		return {}
	if not _captured_state_error(pool).is_empty(): return {}
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
	if value.has("input_value") or value.has("source_die") or value.has("result") or value.has("result_sum") or value.has("result_reduce") or value.has("selected_slot_level"):
		return "Resource pool capacity formulas require actor-only values."
	if str(value.get("op", "")) in ["breakpoint_lookup", "progression_lookup"]:
		return _actor_formula_error(value.get("input"))
	if value.has("caster_level") or value.has("caster_proficiency_bonus") or value.has("caster_class_level") or value.has("caster_ability_modifier"):
		return ""
	var left_error := _actor_formula_error(value.get("left"))
	if not left_error.is_empty():
		return left_error
	return _actor_formula_error(value.get("right"))


static func die_size_error(value: Variant) -> String:
	if _integer(value, 1, 20) and int(value) in SUPPORTED_DIE_SIZES: return ""
	if not value is Dictionary or value.get("op") != "progression_lookup" or value.get("value_type") != "die_size": return "A die size requires a supported integer or declared die_size progression table."
	var error := SharedStepExecutor.formula_content_error(value)
	return error if not error.is_empty() else _actor_formula_error(value)


static func evaluate_die_size(value: Variant, actor: Character) -> Dictionary:
	if not die_size_error(value).is_empty(): return {"success":false,"value":0}
	return SharedStepExecutor.evaluate_actor_formula(value, actor)
