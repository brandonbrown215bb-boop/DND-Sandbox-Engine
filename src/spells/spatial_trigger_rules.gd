## Data-defined spatial scopes. The exact area owns both limits and delivery receipts.
class_name SpatialTriggerRules
extends RefCounted

const EVENTS := ["entry", "crossing", "start_turn", "end_turn", "first_approach", "area_enter"]
const BOUNDARIES := ["event", "turn", "actor_turn", "source_turn", "lifetime"]
static var event_serial := 0
static var runtime_prefix := "runtime:%d:%d:" % [OS.get_process_id(), Time.get_ticks_usec()]

static func next_event() -> String:
	event_serial += 1
	return runtime_prefix + str(event_serial)

static func mark_created(area: Dictionary) -> void:
	area["created_runtime_event"] = runtime_prefix + str(event_serial)

static func policies_error(value: Variant) -> String:
	if not value is Array or value.is_empty() or value.size() > 12: return "Spatial triggers require 1-12 policies"
	var ids := {}
	for policy in value:
		if not policy is Dictionary: return "Invalid spatial policy"
		for key in policy:
			if key not in ["id", "events", "boundary", "limit"]: return "Unsupported spatial policy field: " + str(key)
		if not policy.get("id") is String or str(policy.id).is_empty() or ids.has(policy.id): return "Spatial policy IDs must be distinct"
		ids[policy.id] = true
		if not policy.get("events") is Array or policy.events.is_empty(): return "Spatial policy needs events"
		var seen := {}
		for event in policy.events:
			if event not in EVENTS or seen.has(event): return "Invalid or repeated spatial event"
			seen[event] = true
		if policy.get("boundary") not in BOUNDARIES or not SourceEndAftermathRules._int(policy.get("limit"), 1, 100): return "Invalid spatial limit/boundary"
		if "first_approach" in policy.events and (policy.boundary == "event" or int(policy.limit) != 1): return "First approach needs a one-use turn or lifetime boundary"
	return ""

static func state_error(area: Dictionary) -> String:
	var error := policies_error(area.get("trigger_policies"))
	if not error.is_empty(): return error
	for field in ["trigger_receipts", "trigger_limits"]:
		if not area.get(field, {}) is Dictionary or area.get(field, {}).size() > 10000: return "Invalid spatial trigger ledger"
	for key in area.get("trigger_receipts", {}):
		if not key is String or area.trigger_receipts[key] != "done": return "Finish spatial trigger delivery before saving"
		var parts: Variant = JSON.parse_string(key)
		if not parts is Array or parts.size() != 3 or not parts.all(func(part): return part is String and not part.is_empty() and part.length() <= 1024): return "Invalid spatial event receipt"
		if not area.trigger_policies.any(func(policy): return policy.id == parts[0]): return "Spatial receipt has no declared policy"
	for key in area.get("trigger_limits", {}):
		var row: Variant = area.trigger_limits[key]
		if not key is String or not row is Dictionary or not row.get("boundary") is String or not SourceEndAftermathRules._int(row.get("count"), 1, 100): return "Invalid spatial limit receipt"
		var parts: Variant = JSON.parse_string(key)
		if not parts is Array or parts.size() != 2 or not parts.all(func(part): return part is String and not part.is_empty()): return "Invalid spatial actor limit"
		var policy: Array = area.trigger_policies.filter(func(p): return p.id == parts[0])
		if policy.is_empty() or int(row.count) > int(policy[0].limit) or str(row.boundary).is_empty(): return "Spatial limit exceeds its declaration"
	return ""

## Reserve before any effect or await. All events in one policy share its limit.
static func claim(area: Dictionary, actor_id: String, events: Array, event_id: String, clocks: Dictionary) -> Array[Dictionary]:
	var deliveries: Array[Dictionary] = []
	if actor_id.is_empty() or event_id.is_empty() or area.get("_trigger_ended", false) or not policies_error(area.get("trigger_policies")).is_empty(): return deliveries
	# A delayed callback from before this source existed is not a new entry.
	var offset := event_id.find(runtime_prefix)
	var birth := str(area.get("created_runtime_event", ""))
	if offset >= 0 and birth.begins_with(runtime_prefix) and int(event_id.substr(offset).trim_prefix(runtime_prefix)) <= int(birth.trim_prefix(runtime_prefix)): return deliveries
	var room_prefix := str(area.get("created_room_event_prefix", ""))
	if not room_prefix.is_empty() and event_id.begins_with(room_prefix) and int(event_id.trim_prefix(room_prefix)) <= int(area.get("created_room_event_serial", 0)): return deliveries
	var receipts: Dictionary = area.get("trigger_receipts", {})
	var limits: Dictionary = area.get("trigger_limits", {})
	for policy in area.trigger_policies:
		var matches: Array = policy.events.filter(func(event): return event in events)
		if matches.is_empty(): continue
		var receipt := JSON.stringify([policy.id, actor_id, event_id])
		if receipts.has(receipt) or receipts.size() >= 10000: continue
		var boundary := "lifetime"
		match str(policy.boundary):
			"event": boundary = event_id
			"turn": boundary = str(clocks.get("turn", ""))
			"actor_turn": boundary = str(clocks.get("actors", {}).get(actor_id, clocks.get("initial_actor", "")))
			"source_turn": boundary = str(clocks.get("actors", {}).get(str(area.get("caster_id", "")), clocks.get("initial_actor", "")))
		if boundary.is_empty(): continue # Missing clocks never invent a reset.
		var limit_key := JSON.stringify([policy.id, actor_id])
		var used: Dictionary = limits.get(limit_key, {})
		var count := int(used.get("count", 0)) if used.get("boundary") == boundary else 0
		# Remember even suppressed callbacks so an old event cannot acquire a later turn.
		receipts[receipt] = "done"
		if count >= int(policy.limit): continue
		limits[limit_key] = {"boundary": boundary, "count": count + 1}
		receipts[receipt] = "pending"
		var delivery := area.duplicate(false)
		delivery["_trigger_owner"] = area
		delivery["_trigger_receipt"] = receipt
		delivery["trigger_event"] = matches[0]
		deliveries.append(delivery)
	area["trigger_receipts"] = receipts
	area["trigger_limits"] = limits
	return deliveries

## A repeated delivery or a removed source cannot settle again.
static func settle(delivery: Dictionary) -> bool:
	var owner: Dictionary = delivery.get("_trigger_owner", {})
	var receipt := str(delivery.get("_trigger_receipt", ""))
	if owner.is_empty() or owner.get("_trigger_ended", false) or owner.get("trigger_receipts", {}).get(receipt) != "pending": return false
	owner.trigger_receipts[receipt] = "done"
	return true

static func movement_events(was_inside: bool, is_inside: bool) -> Array:
	var events: Array = []
	if not was_inside and is_inside: events.append("entry")
	if was_inside != is_inside: events.append("crossing")
	if is_inside: events.append("first_approach")
	return events
