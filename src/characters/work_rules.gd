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
## Batch 074 (S-066): an optional authored "site" ties the work to the exact
## represented room cell where it starts: {within_feet, on_away, away_limit_seconds?}.
## Every participant must stand in that room within within_feet of the site when
## joining and for every span of time that accrues; an unknown location never
## satisfies it. on_away "interrupt" applies on_interrupt at the start of the first
## span spent away; "pause" accrues nothing while anyone is away and applies
## on_interrupt only once the absence is PAST away_limit_seconds (strictly more
## than the limit; an absence of exactly the limit is allowed), even inside one
## long clock jump. The clock is whole seconds, so the lapse lands at
## away_since + away_limit_seconds + 1. The span in which everyone returns is
## still away time. Batch 082 (#46 ruling): this is the item's authored per-site
## interruption policy, not a universal crafting rule; work without a site has
## no away/reset rule at all.

const DAY := 86400

static func policy(definition_id: String) -> Dictionary:
	var p: Variant = DataLoader.get_item(definition_id).get("work", {})
	return p if p is Dictionary else {}

static func _whole(v: Variant, minimum: int, maximum: int) -> bool:
	return (v is int or v is float) and is_finite(float(v)) and float(v) == floorf(float(v)) and int(v) >= minimum and int(v) <= maximum

static func policy_error(p: Variant) -> String:
	if not p is Dictionary or p.keys().any(func(k): return str(k) not in ["required_seconds", "daily_seconds", "participants", "concentration", "on_interrupt", "site"]): return "work policy is invalid"
	if not _whole(p.get("required_seconds"), 1, 31536000): return "work needs a whole positive required_seconds"
	if not _whole(p.get("daily_seconds"), 1, DAY): return "work daily_seconds must be 1-86400"
	if p.has("participants") and not _whole(p.participants, 1, 6): return "work participants must be 1-6"
	if p.has("concentration") and not p.concentration is bool: return "work concentration must be true or false"
	if str(p.get("on_interrupt", "")) not in ["keep", "reset"]: return "work on_interrupt must be keep or reset"
	if p.has("site"): return site_policy_error(p.site)
	return ""

## Batch 074: every site field is authored; nothing is defaulted.
static func site_policy_error(site: Variant) -> String:
	if not site is Dictionary: return "work site must be an object"
	if site.keys().any(func(k): return str(k) not in ["within_feet", "on_away", "away_limit_seconds"]): return "work site has an unknown field"
	if not _whole(site.get("within_feet"), 0, 1000) or int(site.within_feet) % 5 != 0: return "work site within_feet must be a whole multiple of 5 from 0 to 1000"
	var away := str(site.get("on_away", ""))
	if not site.get("on_away") is String or away not in ["pause", "interrupt"]: return "work site on_away must be pause or interrupt"
	if away == "pause" and not _whole(site.get("away_limit_seconds"), 1, 31536000): return "paused work site needs a whole away_limit_seconds"
	if away == "interrupt" and site.has("away_limit_seconds"): return "interrupting work site cannot declare away_limit_seconds"
	return ""

static func site_policy(record: Dictionary) -> Dictionary:
	var site: Variant = policy(str(record.get("definition_id", ""))).get("site", {})
	return site if site is Dictionary else {}

## The represented location of a party member: the active dungeon's current
## local room and that member's cell there. Empty when unknown.
static func location(character_id: String) -> Dictionary:
	var dungeon: Dictionary = GameManager.active_dungeon_state
	var room_id := str(dungeon.get("local_room_id", ""))
	if room_id.is_empty(): return {}
	var room: Variant = dungeon.get("local_rooms", {}).get(room_id, null)
	if not room is Dictionary: return {}
	var position: Variant = room.get("party_positions", {}).get(character_id, null)
	if not position is Array or position.size() != 2: return {}
	if not ContainmentRules.relation(room, "character", character_id).is_empty(): return {}
	return {"dungeon_id": str(dungeon.get("dungeon_id", "")), "room_id": room_id, "position": [int(position[0]), int(position[1])]}

## Why this character is not at the work site ("" when within reach).
static func site_error(record: Dictionary, character_id: String) -> String:
	var site := site_policy(record)
	if site.is_empty(): return ""
	var here := location(character_id)
	var c := _party_member(character_id)
	var who := c.character_name if c != null else "A participant"
	if here.is_empty(): return "%s has no represented location, so cannot be at the work site." % who
	var at: Variant = record.get("state", {}).get("work_site", null)
	if not at is Dictionary: return "That work has no recorded site."
	if str(here.dungeon_id) != str(at.get("dungeon_id", "")) or str(here.room_id) != str(at.get("room_id", "")): return "%s is not in the work site's room." % who
	var feet := HexUtils.get_distance(LocalRoomRules.coord(here.position), LocalRoomRules.coord(at.position)) * 5
	if feet > int(site.within_feet): return "%s is %d feet from the work site; the work needs %d feet or less." % [who, feet, int(site.within_feet)]
	return ""

static func _away_error(record: Dictionary) -> String:
	for id in record.get("state", {}).get("work_participants", []):
		var error := site_error(record, str(id))
		if not error.is_empty(): return error
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

## Review 046 R1: a character works on one thing at a time; the same hours never accrue on two works.
static func busy_on(character_id: String, holders: Array = []) -> String:
	var people: Array = holders if not holders.is_empty() else PartyManager.characters.values()
	for holder in people:
		if not holder is Character: continue
		for record in holder.inventory.owned_instances():
			if is_active(record) and character_id in record.get("state", {}).get("work_participants", []): return str(record.instance_id)
	return ""

## Refusal before anything changes.
static func start_error(actor: Character, id: String) -> String:
	if not _carried(actor, id): return "Carry that item to work on it."
	if not busy_on(actor.character_id, [actor] + PartyManager.characters.values()).is_empty() and not is_active(actor.inventory.get_instance(id)): return "You are already working on something else."
	var record := actor.inventory.get_instance(id)
	var p := policy(str(record.get("definition_id", "")))
	if p.is_empty(): return "That item has no work."
	if is_active(record): return "That work is already underway."
	if is_complete(record): return "That work is already complete."
	var draft := record.duplicate(true)
	draft.state["work_participants"] = [actor.character_id]
	var error := eligibility_error(actor, draft)
	if not error.is_empty() and not error.begins_with("This work needs"): return error
	if not site_policy(record).is_empty() and location(actor.character_id).is_empty(): return "This work needs a site; %s has no represented location." % actor.character_name
	return ""

static func start(actor: Character, id: String) -> Dictionary:
	var error := start_error(actor, id)
	if not error.is_empty(): return {"success": false, "message": error}
	var record := actor.inventory.get_instance(id)
	record.state["work_active"] = true
	record.state["work_participants"] = [actor.character_id]
	if not site_policy(record).is_empty(): record.state["work_site"] = location(actor.character_id) # Batch 074: the exact start cell.
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
	if not busy_on(helper.character_id, [helper, worker] + PartyManager.characters.values()).is_empty(): return "You are already working on something else." # Review 046 R1.
	if people.size() >= 6: return "No room for more participants."
	if helper.current_hp <= 0 or ["incapacitated", "unconscious", "paralyzed", "petrified", "stunned"].any(func(c): return helper.has_condition(c)): return "An incapacitated character cannot work." # Review 074 R1: implied Incapacitated counts.
	return site_error(record, helper.character_id) # Batch 074: checked at the join, before anything changes.

static func join(helper: Character, worker: Character, id: String) -> Dictionary:
	var error := join_error(helper, worker, id)
	if not error.is_empty(): return {"success": false, "message": error}
	var record := worker.inventory.get_instance(id)
	var people: Array = record.state.get("work_participants", []).duplicate()
	people.append(helper.character_id)
	record.state["work_participants"] = people
	worker.inventory.update_instance(record)
	return {"success": true, "seconds": 0, "message": "%s joins the work on %s." % [helper.character_name, _name(record)]}

## Batch 074: the joinable offers shown by the room's Join work control.
static func join_options(helper: Character, people: Array) -> Array:
	var options: Array = []
	for worker in people:
		if not worker is Character or worker == helper: continue
		var id := active_id(worker)
		if not id.is_empty(): options.append({"worker": worker, "instance_id": id, "label": "Join %s's work on %s" % [worker.character_name, _name(worker.inventory.get_instance(id))]})
	return options

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
	state.erase("work_site")
	state.erase("work_away_since")
	record["state"] = state
	return {"instance_id": str(record.instance_id), "interrupted": true, "reason": reason, "lost_seconds": lost, "kept_seconds": progress(record), "message": "Work on %s is interrupted (%s); %d seconds kept, %d lost." % [_name(record), reason, progress(record), lost]}

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
		# Batch 074: positions hold for the whole span; away time never accrues.
		var site := site_policy(record)
		if not site.is_empty():
			var away := _away_error(record)
			if not away.is_empty():
				if str(site.on_away) == "interrupt":
					var cut := _interrupt(record, away)
					cut["at"] = t
					receipts.append(cut)
					actor.inventory.update_instance(record)
					continue
				var since := int(state.get("work_away_since", t))
				var limit := since + int(site.away_limit_seconds)
				if now > limit: # "past" the authored limit: exactly the limit is allowed.
					var lapse := _interrupt(record, "away past %d seconds: %s" % [int(site.away_limit_seconds), away])
					lapse["at"] = limit + 1
					receipts.append(lapse)
				else:
					state["work_away_since"] = since
					record["state"] = state
					receipts.append({"instance_id": str(record.instance_id), "paused": true, "away_since": since, "message": "Work on %s pauses: %s" % [_name(record), away]})
				actor.inventory.update_instance(record)
				continue
			if state.has("work_away_since"):
				# The span in which everyone came back is still away time.
				state.erase("work_away_since")
				record["state"] = state
				actor.inventory.update_instance(record)
				receipts.append({"instance_id": str(record.instance_id), "resumed": true, "message": "Everyone is back at the work site; work on %s resumes." % _name(record)})
				continue
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
			state.erase("work_site")
			receipts.append({"instance_id": str(record.instance_id), "complete": true})
		record["state"] = state
		actor.inventory.update_instance(record)
	return receipts

static func _name(record: Dictionary) -> String:
	return str(DataLoader.get_item(str(record.get("definition_id", ""))).get("name", "the work"))

static func record_error(record: Variant) -> String:
	if not record is Dictionary or not record.get("state") is Dictionary: return ""
	var state: Dictionary = record.state
	var keys := ["work_active", "work_participants", "work_progress_seconds", "work_day", "work_day_seconds", "work_site", "work_away_since"]
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
	return site_record_error(state, p)

## Batch 074: a saved site is the exact start cell; away time only under pause.
static func site_record_error(state: Dictionary, p: Dictionary) -> String:
	var site: Variant = p.get("site", null)
	if site == null:
		return "work site is saved on work without a site policy" if state.has("work_site") or state.has("work_away_since") else ""
	if state.has("work_active") != state.has("work_site"): return "active site work needs its site"
	if state.has("work_site"):
		var at: Variant = state.work_site
		if not at is Dictionary or at.keys().size() != 3 or not at.get("dungeon_id") is String or not at.get("room_id") is String or str(at.room_id).is_empty(): return "work site is invalid"
		var pos: Variant = at.get("position")
		if not pos is Array or pos.size() != 2 or not _whole(pos[0], -100000, 100000) or not _whole(pos[1], -100000, 100000): return "work site position is invalid"
	if state.has("work_away_since"):
		if not state.has("work_site") or str(site.get("on_away", "")) != "pause": return "work away time needs paused site work"
		if not _whole(state.work_away_since, 0, 100000000000): return "work away time is invalid"
	return ""

## Review 046 R1: across a saved party, nobody participates in two active works.
static func party_error(character_dtos: Array) -> String:
	var seen := {}
	for dto in character_dtos:
		if not dto is Dictionary: continue
		var records: Variant = dto.get("inventory", {}).get("copies", {}).get("records", {})
		if not records is Dictionary: continue
		for record in records.values():
			if not record is Dictionary or not record.get("state") is Dictionary or not bool(record.state.get("work_active", false)): continue
			for id in record.state.get("work_participants", []):
				if seen.has(str(id)): return "a character works on two things at once"
				seen[str(id)] = true
	return ""

static func _unique(values: Array) -> int:
	var seen := {}
	for v in values: seen[str(v)] = true
	return seen.size()
