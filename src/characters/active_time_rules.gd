class_name ActiveTimeRules
extends RefCounted
## S-064 pause/resume cumulative active time on exact item copies.
## Item policy "active_time": {budget_seconds, cooldown_seconds?}. Only active
## time is spent; pausing keeps the spent total, so resuming never restarts the
## allowance. Exhaustion records its own exact time; the cooldown starts there and
## a fresh allowance exists only after that cooldown (none when undeclared).

static func policy(definition_id: String) -> Dictionary:
	var p: Variant = DataLoader.get_item(definition_id).get("active_time", {})
	return p if p is Dictionary else {}

static func _whole(v: Variant, minimum: int) -> bool:
	return (v is int or v is float) and is_finite(float(v)) and float(v) == floorf(float(v)) and int(v) >= minimum

static func policy_error(p: Variant) -> String:
	if not p is Dictionary or p.keys().any(func(k): return str(k) not in ["budget_seconds", "cooldown_seconds"]): return "active_time policy is invalid"
	if not _whole(p.get("budget_seconds"), 1) or int(p.budget_seconds) > 31536000: return "active_time needs a whole positive budget_seconds"
	if p.has("cooldown_seconds") and (not _whole(p.cooldown_seconds, 1) or int(p.cooldown_seconds) > 31536000): return "active_time cooldown_seconds is invalid"
	return ""

static func used(record: Dictionary) -> int:
	return int(record.get("state", {}).get("active_used_seconds", 0))

static func is_active(record: Dictionary) -> bool:
	return bool(record.get("state", {}).get("active", false))

static func _owned(actor: Character, id: String) -> bool:
	return actor != null and actor.inventory.owned_instances().any(func(c): return str(c.instance_id) == id)

## Refusal before anything changes (the budget is the paid resource).
static func activate_error(actor: Character, id: String, now: int) -> String:
	if not _owned(actor, id): return "Carry that item to use it."
	var record := actor.inventory.get_instance(id)
	var p := policy(str(record.get("definition_id", "")))
	if p.is_empty(): return "That item has no active time."
	if is_active(record): return "That item is already active."
	var until := int(record.state.get("active_cooldown_until", -1))
	if until >= 0 and now < until: return "That item is recovering for %d more seconds." % (until - now)
	if until < 0 and used(record) >= int(p.budget_seconds): return "That item's active time is spent."
	return ""

static func activate(actor: Character, id: String, now: int) -> Dictionary:
	settle(actor, 0, now)
	var error := activate_error(actor, id, now)
	if not error.is_empty(): return {"success": false, "message": error}
	var record := actor.inventory.get_instance(id)
	record.state["active"] = true
	actor.inventory.update_instance(record)
	var p := policy(str(record.definition_id))
	return {"success": true, "seconds": 6, "remaining_seconds": int(p.budget_seconds) - used(record), "message": "%s is active (%d seconds left)." % [DataLoader.get_item(str(record.definition_id)).get("name", "Item"), int(p.budget_seconds) - used(record)]}

static func pause(actor: Character, id: String) -> Dictionary:
	if not _owned(actor, id): return {"success": false, "message": "Carry that item to use it."}
	var record := actor.inventory.get_instance(id)
	if not is_active(record): return {"success": false, "message": "That item is not active."}
	record.state["active"] = false
	actor.inventory.update_instance(record)
	return {"success": true, "seconds": 0, "message": "%s is paused with %d seconds spent." % [DataLoader.get_item(str(record.definition_id)).get("name", "Item"), used(record)]}

## Spend elapsed active time; `now` is the campaign clock after the elapsed span.
static func settle(actor: Character, elapsed: int, now: int) -> Array:
	var receipts: Array = []
	if actor == null: return receipts
	for record in actor.inventory.owned_instances():
		var p := policy(str(record.definition_id))
		if p.is_empty(): continue
		var state: Dictionary = record.state
		var changed := false
		if is_active(record) and elapsed > 0:
			var spend := mini(elapsed, int(p.budget_seconds) - used(record))
			state["active_used_seconds"] = used(record) + spend
			changed = true
			if int(state.active_used_seconds) >= int(p.budget_seconds):
				state["active"] = false
				var exhausted_at := now - elapsed + spend
				if p.has("cooldown_seconds"): state["active_cooldown_until"] = exhausted_at + int(p.cooldown_seconds)
				receipts.append({"instance_id": str(record.instance_id), "exhausted_at": exhausted_at})
		var until := int(state.get("active_cooldown_until", -1))
		if until >= 0 and now >= until:
			state.erase("active_cooldown_until")
			state.erase("active_used_seconds")
			changed = true
		if changed:
			record["state"] = state
			actor.inventory.update_instance(record)
	return receipts

## Item benefits of an active-time copy apply only while it is active.
static func benefits_on(record: Dictionary) -> bool:
	return policy(str(record.get("definition_id", ""))).is_empty() or is_active(record)

static func record_error(record: Variant) -> String:
	if not record is Dictionary or not record.get("state") is Dictionary: return ""
	var state: Dictionary = record.state
	if not (state.has("active") or state.has("active_used_seconds") or state.has("active_cooldown_until")): return ""
	var p := policy(str(record.get("definition_id", "")))
	if p.is_empty(): return "active time is saved on an item without an active_time policy"
	if state.has("active") and not state.active is bool: return "active time flag is invalid"
	if state.has("active_used_seconds") and (not _whole(state.active_used_seconds, 0) or int(state.active_used_seconds) > int(p.budget_seconds)): return "active time spent is invalid"
	if bool(state.get("active", false)) and used(record) >= int(p.budget_seconds): return "a spent item cannot be active"
	if state.has("active_cooldown_until"):
		if not p.has("cooldown_seconds") or not _whole(state.active_cooldown_until, 0) or bool(state.get("active", false)) or used(record) != int(p.budget_seconds): return "active time cooldown is invalid"
	return ""
