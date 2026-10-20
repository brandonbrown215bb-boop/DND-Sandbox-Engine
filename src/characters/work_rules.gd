class_name WorkRules
extends RefCounted
## S-066 qualified work/study progress on exact item copies.
## Item policy "work": {required_seconds, daily_seconds, participants?, concentration?, on_interrupt}.
## Only eligible time accrues: the copy is carried at hand by its worker, every
## named participant is a conscious party member, the worker is not holding a
## spell's concentration when the policy demands full attention, and no more than
## daily_seconds accrue per campaign day (the rest of the day is rest). Leaving
## (stopping, losing the copy, a participant dropping out, combat) follows the
## authored on_interrupt policy: "keep" keeps progress, "reset" loses it.

const DAY := 86400

static func policy(definition_id: String) -> Dictionary:
	var p: Variant = DataLoader.get_item(definition_id).get("work", {})
	return p if p is Dictionary else {}

static func _whole(v: Variant, minimum: int, maximum: int) -> bool:
	return (v is int or v is float) and is_finite(float(v)) and float(v) == floorf(float(v)) and int(v) >= minimum and int(v) <= maximum

static func policy_error(p: Variant) -> String:
	if not p is Dictionary or p.keys().any(func(k): return str(k) not in ["required_seconds", "daily_seconds", "participants", "concentration", "on_interrupt"]): return "work policy is invalid"
	if not _whole(p.get("required_seconds"), 1, 31536000): return "work needs a whole positive required_seconds"
	if not _whole(p.get("daily_seconds"), 1, DAY): return "work daily_seconds must be 1-86400"
	if p.has("participants") and not _whole(p.participants, 1, 6): return "work participants must be 1-6"
	if p.has("concentration") and not p.concentration is bool: return "work concentration must be true or false"
	if str(p.get("on_interrupt", "")) not in ["keep", "reset"]: return "work on_interrupt must be keep or reset"
	return ""

static func progress(record: Dictionary) -> int:
	return int(record.get("state", {}).get("work_progress_seconds", 0))

static func is_active(record: Dictionary) -> bool:
	return bool(record.get("state", {}).get("work_active", false))

static func is_complete(record: Dictionary) -> bool:
	var p := policy(str(record.get("definition_id", "")))
	return not p.is_empty() and progress(record) >= int(p.required_seconds)

static func _carried(actor: Character, id: String) -> bool:
	return actor != null and actor.inventory.owned_instances().any(func(c): return str(c.instance_id) == id)

static func _party_member(id: String) -> Character:
	var c: Variant = PartyManager.characters.get(id, null)
	return c if c is Character else null

## Why accrual is not eligible right now ("" when it is).
static func eligibility_error(actor: Character, record: Dictionary) -> String:
	var p := policy(str(record.get("definition_id", "")))
	if p.is_empty(): return "That item has no work."
	if not _carried(actor, str(record.get("instance_id", ""))): return "The worker no longer has the work at hand."
	var people: Array = record.get("state", {}).get("work_participants", [actor.character_id])
	if people.is_empty() or str(people[0]) != actor.character_id: return "Someone else started this work."
	for id in people:
		var c := _party_member(str(id))
		if c == null or not c.is_alive or c.current_hp <= 0 or c.has_condition("incapacitated"): return "A participant has left the work."
		if bool(p.get("concentration", false)) and not c.concentrating_on.is_empty(): return "The work needs full attention; concentration on a spell breaks it."
	if people.size() < int(p.get("participants", 1)): return "This work needs %d participants." % int(p.get("participants", 1))
	if bool(p.get("concentration", false)) and not actor.concentrating_on.is_empty(): return "The work needs full attention; concentration on a spell breaks it."
	return ""

## Refusal before anything changes.
static func start_error(actor: Character, id: String) -> String:
	if not _carried(actor, id): return "Carry that item to work on it."
	var record := actor.inventory.get_instance(id)
	var p := policy(str(record.get("definition_id", "")))
	if p.is_empty(): return "That item has no work."
	if is_active(record): return "That work is already underway."
	if is_complete(record): return "That work is already complete."
	var draft := record.duplicate(true)
	draft.state["work_participants"] = [actor.character_id]
	var error := eligibility_error(actor, draft)
	if not error.is_empty() and not error.begins_with("This work needs"): return error
	return ""

static func start(actor: Character, id: String) -> Dictionary:
	var error := start_error(actor, id)
	if not error.is_empty(): return {"success": false, "message": error}
	var record := actor.inventory.get_instance(id)
	record.state["work_active"] = true
	record.state["work_participants"] = [actor.character_id]
	actor.inventory.update_instance(record)
	var p := policy(str(record.definition_id))
	var need := int(p.get("participants", 1))
	return {"success": true, "seconds": 0, "message": "%s starts work on %s (%d of %d seconds done%s)." % [actor.character_name, _name(record), progress(record), int(p.required_seconds), "; needs %d participants" % need if need > 1 else ""]}

## A conscious party member joins the worker's active work.
static func join_error(helper: Character, worker: Character, id: String) -> String:
	if helper == null or worker == null or helper == worker: return "Choose another character's work to join."
	if not helper.is_alive: return "An unconscious character cannot work."
	if not _carried(worker, id): return "That work is not at hand."
	var record := worker.inventory.get_instance(id)
	if not is_active(record): return "That work is not underway."
	var people: Array = record.state.get("work_participants", [])
	if helper.character_id in people: return "Already working on it."
	if people.size() >= 6: return "No room for more participants."
	return ""

static func join(helper: Character, worker: Character, id: String) -> Dictionary:
	var error := join_error(helper, worker, id)
	if not error.is_empty(): return {"success": false, "message": error}
	var record := worker.inventory.get_instance(id)
	var people: Array = record.state.get("work_participants", []).duplicate()
	people.append(helper.character_id)
	record.state["work_participants"] = people
	worker.inventory.update_instance(record)
	return {"success": true, "seconds": 0, "message": "%s joins the work on %s." % [helper.character_name, _name(record)]}

## The worker's first active work copy, for the HUD.
static func active_id(worker: Character) -> String:
	if worker == null: return ""
	for record in worker.inventory.owned_instances():
		if is_active(record): return str(record.instance_id)
	return ""

## Leaving: progress is kept or lost per the authored policy.
static func _interrupt(record: Dictionary, reason: String) -> Dictionary:
	var p := policy(str(record.definition_id))
	var state: Dictionary = record.state
	var lost := 0
	if str(p.get("on_interrupt", "keep")) == "reset":
		lost = progress(record)
		state.erase("work_progress_seconds") # The day's worked time still counts against the daily allowance.
	state.erase("work_active")
	state.erase("work_participants")
	record["state"] = state
	return {"instance_id": str(record.instance_id), "interrupted": true, "reason": reason, "lost_seconds": lost, "kept_seconds": progress(record)}

static func stop(actor: Character, id: String) -> Dictionary:
	if not _carried(actor, id): return {"success": false, "message": "Carry that item to stop its work."}
	var record := actor.inventory.get_instance(id)
	if not is_active(record): return {"success": false, "message": "That work is not underway."}
	var r := _interrupt(record, "stopped")
	actor.inventory.update_instance(record)
	return {"success": true, "seconds": 0, "receipt": r, "message": "Work on %s stops; %d seconds kept, %d lost." % [_name(record), int(r.kept_seconds), int(r.lost_seconds)]}

## Combat interrupts every active work of this actor.
static func interrupt_all(actor: Character, reason: String) -> Array:
	var receipts: Array = []
	if actor == null: return receipts
	for record in actor.inventory.owned_instances():
		if not is_active(record) or policy(str(record.definition_id)).is_empty(): continue
		receipts.append(_interrupt(record, reason))
		actor.inventory.update_instance(record)
	return receipts

## Resting participants leave their own work and any work they were helping.
static func interrupt_participant(actor: Character, reason: String) -> void:
	var workers: Array = PartyManager.characters.values()
	if actor not in workers: workers.append(actor)
	for worker in workers:
		if not worker is Character: continue
		for record in worker.inventory.owned_instances():
			if is_active(record) and actor.character_id in record.state.get("work_participants", []):
				_interrupt(record, reason)
				worker.inventory.update_instance(record)

## Settle loss at the actual transfer/drop boundary, before the copy can return.
static func on_removed(record: Dictionary) -> void:
	if is_active(record): _interrupt(record, "copy_removed")

## Accrue eligible elapsed time; `now` is the campaign clock after the span.
static func settle(actor: Character, elapsed: int, now: int) -> Array:
	var receipts: Array = []
	if actor == null or elapsed <= 0: return receipts
	for record in actor.inventory.owned_instances():
		var p := policy(str(record.definition_id))
		if p.is_empty() or not is_active(record): continue
		var error := eligibility_error(actor, record)
		if error.begins_with("This work needs"): continue # Waiting for helpers: nothing accrues, nothing is lost.
		if not error.is_empty():
			receipts.append(_interrupt(record, error))
			actor.inventory.update_instance(record)
			continue
		var state: Dictionary = record.state
		var t := now - elapsed
		var done := progress(record)
		while t < now and done < int(p.required_seconds):
			var day := floori(float(t) / DAY)
			var day_end := mini(now, (day + 1) * DAY)
			if int(state.get("work_day", -1)) != day:
				state["work_day"] = day
				state["work_day_seconds"] = 0
			var room := int(p.daily_seconds) - int(state.work_day_seconds)
			var add := mini(mini(room, day_end - t), int(p.required_seconds) - done)
			if add > 0:
				done += add
				state["work_day_seconds"] = int(state.work_day_seconds) + add
			t = day_end
		state["work_progress_seconds"] = done
		if done >= int(p.required_seconds):
			state.erase("work_active")
			state.erase("work_participants")
			receipts.append({"instance_id": str(record.instance_id), "complete": true})
		record["state"] = state
		actor.inventory.update_instance(record)
	return receipts

static func _name(record: Dictionary) -> String:
	return str(DataLoader.get_item(str(record.get("definition_id", ""))).get("name", "the work"))

static func record_error(record: Variant) -> String:
	if not record is Dictionary or not record.get("state") is Dictionary: return ""
	var state: Dictionary = record.state
	var keys := ["work_active", "work_participants", "work_progress_seconds", "work_day", "work_day_seconds"]
	if not keys.any(func(k): return state.has(k)): return ""
	var p := policy(str(record.get("definition_id", "")))
	if p.is_empty(): return "work progress is saved on an item without a work policy"
	if state.has("work_progress_seconds") and not _whole(state.work_progress_seconds, 0, int(p.required_seconds)): return "work progress is invalid"
	if state.has("work_active") and (not state.work_active is bool or not bool(state.work_active)): return "work flag is invalid"
	if state.has("work_active") != state.has("work_participants"): return "active work needs its participants"
	if state.has("work_participants"):
		var people: Variant = state.work_participants
		if not people is Array or people.is_empty() or people.size() > 6 or people.any(func(x): return not x is String or str(x).is_empty()) or people.size() != _unique(people): return "work participants are invalid"
		if progress(record) >= int(p.required_seconds): return "completed work cannot be active"
	if state.has("work_day") != state.has("work_day_seconds"): return "work day ledger is incomplete"
	if state.has("work_day") and (not _whole(state.work_day, 0, 100000000) or not _whole(state.work_day_seconds, 0, int(p.daily_seconds))): return "work day ledger is invalid"
	return ""

static func _unique(values: Array) -> int:
	var seen := {}
	for v in values: seen[str(v)] = true
	return seen.size()
