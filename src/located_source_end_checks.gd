class_name LocatedSourceEndChecks
extends RefCounted

const SPELL := "fixture:located_mark"
const FEAT := "fixture:located_mode_feat"
const MODE := "fixture:located_mode"
const ITEM := "fixture:located_copy"
const RENAMED_ITEM := "fixture:located_copy_renamed"
const ACTOR_SPELL := "fixture:located_actor"
const RENAMED_ACTOR_SPELL := "fixture:located_actor_renamed"

static func load_fixtures() -> void:
	if not DataLoader.get_spell(SPELL).is_empty(): return
	DataLoader._load_json_file("res://data/fixtures/located_source_end/spells/marks.json", "spell")
	DataLoader._load_json_file("res://data/fixtures/located_source_end/spells/actors.json", "spell")
	DataLoader._load_json_file("res://data/fixtures/located_source_end/feats/afterglow.json", "feat")
	DataLoader._load_json_file("res://data/fixtures/located_source_end/items/items.json", "item")
	if SPELL not in DataLoader.classes["wizard"].get("spell_list_ids", []): DataLoader.classes["wizard"].spell_list_ids.append(SPELL)
	if ACTOR_SPELL not in DataLoader.classes["wizard"].get("spell_list_ids", []): DataLoader.classes["wizard"].spell_list_ids.append(ACTOR_SPELL)

static func kit(actor: Character) -> void:
	while actor.level < 4: actor.level_up()
	FeatRules.choose_level_feat(actor, FEAT)

static func room(actor: Character) -> Dictionary:
	return LocalRoomRules.create({"id": "located-proof", "name": "Aftermath room", "cells": [[0, 0], [1, 0], [2, 0]], "walls": [], "exits": [[2, 0]], "party_spawns": [[0, 0]], "monster_spawns": [], "objects": [], "encounter_monsters": [], "plane": "material"}, [actor])

static func run(check: Callable) -> void:
	load_fixtures()
	check.call(DataLoader.get_load_errors().is_empty(), "Located end fixture spell and mode load through ordinary data validation")
	var previous := GameManager.transition_context
	var previous_state := GameManager.current_state
	var previous_clock := GameManager.campaign_elapsed_seconds
	GameManager.current_state = GameManager.GameState.DUNGEON
	var actor := Batch031Checks._character("located-end", 30)
	kit(actor)
	var state := room(actor)
	GameManager.transition_context = {"local_room": state}
	actor.current_hp = 10
	var cast := CombatAction.resolve_spell(actor, actor, DataLoader.get_spell(SPELL), false)
	var source := str(cast.get("effect_cast", {}).get("source_id", ""))
	check.call(cast.get("success", false) and not source.is_empty() and actor.spell_effects.has(source), "Located shared spell uses real resolver and retains the exact source")
	var event := SpellEffects.remove(actor, source, "expired")
	check.call(event.get("recipient_id") == actor.character_id and event.final_location.position == [0, 0] and event.final_location.plane == "material" and not actor.spell_effects.has(source) and not actor.has_condition("blessed"), "Capture exact source/recipient/plane/location before removing its condition grants")
	state.party_positions[actor.character_id] = [2, 0]
	state.plane = "ethereal"
	check.call(LocatedSourceEndRules.observe(state, [actor]).is_empty() and state.objects.is_empty(), "Delayed observation cannot run before the captured deadline")
	GameManager.campaign_elapsed_seconds += 12
	var requests := LocatedSourceEndRules.observe(state, [actor])
	check.call(requests.size() == 1 and not DungeonPersistence.local_error(state).is_empty(), "Due child yields one decision; checkpoints refuse unresolved decisions")
	var request: Dictionary = requests[0] if not requests.is_empty() else {}
	var canceled := LocatedSourceEndRules.answer(state, str(request.get("invocation", "")), "mend", false, [actor])
	var pending: Dictionary = state.source_end_continuations.values()[0]
	check.call(canceled.get("success", false) and actor.current_hp == 10 and pending.remaining.is_empty() and pending.receipts.size() == 3 and state.objects.size() == 1 and state.areas.size() == 1, "Skip cancellation resumes siblings once without healing or replaying the parent")
	check.call(state.objects[0].position == [0, 0] and state.areas[0].center == [0, 0] and state.objects[0].plane == "material" and state.objects[0].id != source and state.areas[0].id != source and state.objects[0].id != state.areas[0].id, "Actual object/area successors keep captured origin/plane and distinct identities after movement")
	check.call(not LocatedSourceEndRules.answer(state, str(request.get("invocation", "")), "mend", true, [actor]).get("success", false) and SpellEffects.remove(actor, source, "destroyed").is_empty(), "Stale child answers and repeated source cleanup cannot replay children")
	check.call(DungeonPersistence.local_error(state).is_empty(), "Completed continuation and world successors pass room DTO validation: " + DungeonPersistence.local_error(state))
	var wrong_plane := LocalRoomAreas.enter(state, actor.character_id, Vector2i(1, 0), Vector2i.ZERO, int(GameManager.campaign_elapsed_seconds), "ethereal")
	var right_plane := LocalRoomAreas.enter(state, actor.character_id, Vector2i(1, 0), Vector2i.ZERO, int(GameManager.campaign_elapsed_seconds), "material")
	var hazard_results := LocalRoomRules.resolve_area_entries(right_plane, actor)
	var repeat_entry := LocalRoomAreas.enter(state, actor.character_id, Vector2i(1, 0), Vector2i.ZERO, int(GameManager.campaign_elapsed_seconds), "material")
	check.call(wrong_plane.is_empty() and hazard_results.size() == 1 and actor.current_hp == 7 and repeat_entry.is_empty(), "Actual entry hazard damages once; wrong-plane entry does not consume its trigger")
	actor.current_hp = 10
	var object_damage := CombatObjectRules.apply_damage(state.objects[0], 2, "force")
	check.call(object_damage == 2 and int(state.objects[0].hp) == 5, "Successor is an actual damageable room object")
	var restored: Dictionary = JSON.parse_string(JSON.stringify(state))
	LocatedSourceEndRules.observe(restored, [actor])
	check.call(restored.objects.size() == 1 and restored.areas.size() == 1 and actor.current_hp == 10 and DungeonPersistence.local_error(restored).is_empty(), "Plain checkpoint restore retains consumed children without replay")
	for defect in ["cursor", "reason", "origin", "hazard", "producer"]:
		var bad: Dictionary = restored.duplicate(true)
		var p: Dictionary = bad.source_end_continuations.values()[0]
		match defect:
			"cursor": p.remaining = DataLoader.get_spell(SPELL).end_aftermath[0].children.duplicate(true)
			"reason": p.event.end_reason = "dismissed"
			"origin": p.event.final_location.position = [999, 999]
			"hazard": bad.areas[0].amount = 99
			"producer": p.event.source_kind = "item"
		check.call(not DungeonPersistence.local_error(bad).is_empty(), "Saved source-end %s tampering refuses before load" % defect)
	for field in ["cells", "areas", "objects"]:
		var malformed: Dictionary = restored.duplicate(true)
		malformed[field] = [null] if field == "cells" else {}
		check.call(not DungeonPersistence.local_error(malformed).is_empty(), "Malformed %s refuses cleanly before continuation validation" % field)
	# A full room pauses automatic creation without leaving an invisible decision.
	var blocked: Dictionary = restored.duplicate(true)
	var blocked_pending: Dictionary = blocked.source_end_continuations.values()[0]
	blocked_pending.receipts = [blocked_pending.receipts[0]]
	blocked_pending.remaining = DataLoader.get_spell(SPELL).end_aftermath[0].children.slice(1).duplicate(true)
	blocked.objects = []
	blocked.areas = []
	for index in 200: blocked.objects.append({"id": "full:%d" % index, "name": "Full", "kind": "loose", "position": [1, 0], "contents": []})
	LocatedSourceEndRules.observe(blocked, [actor])
	check.call(not LocatedSourceEndRules.pending_choice(blocked) and blocked_pending.remaining.size() == 2 and DungeonPersistence.local_error(blocked).is_empty(), "Automatic capacity failure keeps a checkpointable remaining child, with no invisible choice")
	blocked.objects.pop_back()
	LocatedSourceEndRules.observe(blocked, [actor])
	check.call(blocked_pending.remaining.is_empty() and blocked.areas.size() == 1, "Freed capacity resumes automatic siblings once")
	# Reason-specific real source removal: neither branch borrows expiry children.
	for reason in ["dismissed", "destroyed"]:
		var again := CombatAction.resolve_spell(actor, actor, DataLoader.get_spell(SPELL), false)
		var next_source := str(again.get("effect_cast", {}).get("source_id", ""))
		var ended := SpellEffects.remove(actor, next_source, reason)
		LocatedSourceEndRules.observe(state, [actor])
		check.call(ended.get("end_reason") == reason and state.areas.size() == 1 and (actor.current_hp == 12 if reason == "dismissed" else state.objects.size() == 2), "Exact %s event selects only its declared continuation" % reason)
	# Self mode is a separate producer. Exact time is retained across a large clock jump.
	var activated := FeatureModeRules.activate(actor, MODE, "guard")
	var start := int(GameManager.campaign_elapsed_seconds)
	GameManager.campaign_elapsed_seconds += 30
	SpellEffects.advance_time([actor], 30)
	var mode_pending := {}
	for p in state.source_end_continuations.values():
		if p.event.source_kind == "mode": mode_pending = p
	check.call(activated.get("success", false) and not mode_pending.is_empty() and int(mode_pending.event.ended_at_seconds) == start + 6 and mode_pending.event.end_reason == "duration" and not actor.feature_modes[MODE].active and int(actor.feature_uses[MODE]) == 3, "Real mode expiry captures exact deadline, source state and one use across a long clock step")
	var mode_requests := LocatedSourceEndRules.observe(state, [actor])
	if not mode_requests.is_empty(): LocatedSourceEndRules.answer(state, mode_requests[0].invocation, "mend", true, [actor])
	check.call(actor.current_hp == 16 and state.areas.size() == 2, "Accepted mode child heals once and creates its own world successors")
	FeatureModeRules.activate(actor, MODE, "stride")
	var stopped := FeatureModeRules.end(actor, MODE, "zero_hp")
	var stop_requests := LocatedSourceEndRules.observe(state, [actor])
	if not stop_requests.is_empty(): LocatedSourceEndRules.answer(state, stop_requests[0].invocation, "mend", false, [actor])
	check.call(stopped.source_end.end_reason == "zero_hp" and state.areas.size() == 2 and actor.current_hp == 16, "Stop cancellation abandons remaining siblings without reviving the ended mode")
	check.call(LocatedSourceEndRules.saved_producers_error([state]).is_empty(), "Captured upgraded end_on reason remains valid against the historical mode producer")
	actor.feature_modes.erase(MODE) # Reacquiring a feature must not reuse a consumed source identity.
	var reacquired := FeatureModeRules.activate(actor, MODE, "guard")
	var reacquired_end := FeatureModeRules.end(actor, MODE, "zero_hp")
	var reacquired_requests := LocatedSourceEndRules.observe(state, [actor])
	if not reacquired_requests.is_empty(): LocatedSourceEndRules.answer(state, reacquired_requests[0].invocation, "mend", false, [actor])
	check.call(reacquired.get("success", false) and int(reacquired.get("activation_serial", 0)) == 3 and reacquired_end.source_end.source_id != mode_pending.event.source_id, "Reacquired mode uses a fresh source identity instead of colliding with old continuation receipts")
	var malformed_mode := state.duplicate(true)
	for p in malformed_mode.source_end_continuations.values():
		if p.event.source_kind == "mode": p.event.record.end_aftermath = {}; break
	check.call(not DungeonPersistence.local_error(malformed_mode).is_empty(), "Malformed captured mode declaration rejects cleanly")
	for scope in ["crossing", "turn_start", "turn_end"]:
		var bad: Array = DataLoader.get_spell(SPELL).end_aftermath.duplicate(true)
		bad[0].children[2].trigger_scope = scope
		check.call(not SourceEndAftermathRules.validate(bad).is_empty(), "Unsupported hazard trigger scope %s refuses" % scope)
	var group: Dictionary = DataLoader.get_feat(FEAT).features[0].duplicate(true)
	group.targets = 2
	check.call(not FeatureModeRules.validate_rule(group).is_empty(), "Unsupported group mode producer refuses explicitly")
	check.call(not FeatureModeRules.validate_rule(DataLoader.get_feat(FEAT).features[0], true).is_empty(), "Item-owned mode end producer refuses before installation")
	_exact_copy_actor_producers(check)
	_pending_copy_origin(check)
	_snapshot_once(check, actor)
	GameManager.transition_context = {}
	var slots := actor.spell_slots.duplicate()
	var refused := CombatAction.resolve_spell(actor, actor, DataLoader.get_spell(SPELL), true)
	check.call(not refused.get("success", false) and actor.spell_slots == slots, "Unavailable located host refuses before slot payment")
	GameManager.transition_context = previous
	GameManager.current_state = previous_state
	GameManager.campaign_elapsed_seconds = previous_clock

static func _exact_copy_actor_producers(check: Callable) -> void:
	var owner := Batch031Checks._character("located-producers", 30)
	var room_state := room(owner)
	var previous_context := GameManager.transition_context
	var previous_state := GameManager.current_state
	var previous_active := GameManager.active_dungeon_state
	var previous_characters := PartyManager.characters
	GameManager.current_state = GameManager.GameState.DUNGEON
	GameManager.transition_context = {"local_room": room_state}
	GameManager.active_dungeon_state = {"local_rooms": {"located-proof": room_state}, "local_room_id": "located-proof"}
	PartyManager.characters = {owner.character_id: owner}
	check.call(not DataLoader.get_item(ITEM).is_empty() and not DataLoader.get_spell(ACTOR_SPELL).is_empty() and not DataLoader.get_spell(RENAMED_ACTOR_SPELL).is_empty() and not DataLoader.get_item(RENAMED_ITEM).is_empty(), "Neutral and renamed item-copy/created-actor declarations load through normal definition validation")
	owner.inventory.add_item(ITEM)
	owner.inventory.add_item(ITEM)
	var copy_ids: Array = owner.inventory.copies.backpack.duplicate()
	var first_id := str(copy_ids[0])
	var second_id := str(copy_ids[1])
	var first_projected: bool = ItemProjectionRules.project(owner, first_id).projected
	var second_projected: bool = ItemProjectionRules.project(owner, second_id).projected
	room_state.created_actor_positions[ItemProjectionRules.actor_id(first_id)] = [0, 0]
	room_state.created_actor_positions[ItemProjectionRules.actor_id(second_id)] = [1, 0]
	var first_end := ItemProjectionRules.revert(owner, first_id, -1, "dismissed")
	var second_end := ItemProjectionRules.revert(owner, second_id, -1, "expired")
	owner.inventory.add_item(RENAMED_ITEM)
	var renamed_id := str(owner.inventory.copies.backpack[-1])
	var renamed_projected: bool = ItemProjectionRules.project(owner, renamed_id).projected
	room_state.created_actor_positions[ItemProjectionRules.actor_id(renamed_id)] = [2, 0]
	var renamed_end := ItemProjectionRules.revert(owner, renamed_id, -1, "destroyed")
	var item_events: Array = room_state.get("source_end_continuations", {}).values().filter(func(p): return p.event.source_kind == "item_copy")
	var exact_items: bool = first_projected and second_projected and renamed_projected and first_end.reverted and second_end.reverted and renamed_end.reverted and renamed_end.destroyed and item_events.size() == 3 and item_events[0].event.source_id != item_events[1].event.source_id and item_events.any(func(p): return p.event.end_reason == "dismissed" and p.event.final_location.position == [0, 0]) and item_events.any(func(p): return p.event.end_reason == "expired" and p.event.final_location.position == [1, 0]) and item_events.any(func(p): return p.event.end_reason == "destroyed" and p.event.definition_id == RENAMED_ITEM and p.event.final_location.position == [2, 0])
	room_state.party_positions[owner.character_id] = [2, 0]
	var actor_spell := DataLoader.get_spell(ACTOR_SPELL)
	var parent_source := "spell:%s:909" % owner.character_id
	var cast := {"source_id": parent_source, "spell_id": ACTOR_SPELL, "caster_id": owner.character_id, "remaining_seconds": 60, "expiry_phase": "end", "conditions": []}
	var template: Dictionary = CreatedActorRules._effect(actor_spell).template
	var created := CreatedActorRules.create(owner, cast, template, 1, actor_spell)
	var actors := CreatedActorRules.actors(owner)
	if actors.size() == 2:
		room_state.created_actor_positions[actors[0].character_id] = [0, 0]
		room_state.created_actor_positions[actors[1].character_id] = [1, 0]
		actors[0].current_hp = 0
		actors[0].is_alive = false
	var death := CreatedActorRules.end_actor(actors[0] if not actors.is_empty() else null, "death", {"damage_type": "fire"})
	CreatedActorRules.end_actor(actors[0] if not actors.is_empty() else null, "death", {"damage_type": "fire"})
	SpellEffects.remove(owner, parent_source, "expired", {"cause": "clock"})
	var ended_count := SpellEffects.source_end_events().size()
	var stale_death := CreatedActorRules.end_actor(actors[0] if not actors.is_empty() else null, "death")
	check.call(stale_death.is_empty() and SpellEffects.source_end_events().size() == ended_count, "Created actor stale death after parent expiry cannot publish another end reason or aftermath")
	var renamed_actor_spell := DataLoader.get_spell(RENAMED_ACTOR_SPELL)
	var renamed_parent := "spell:%s:910" % owner.character_id
	var renamed_cast := {"source_id": renamed_parent, "spell_id": RENAMED_ACTOR_SPELL, "caster_id": owner.character_id, "remaining_seconds": 60, "expiry_phase": "end", "conditions": []}
	var renamed_created := CreatedActorRules.create(owner, renamed_cast, CreatedActorRules._effect(renamed_actor_spell).template, 1, renamed_actor_spell)
	var renamed_actors := CreatedActorRules.actors(owner).filter(func(a): return str(a.get_meta("created_source_id", "")) == renamed_parent)
	for renamed_actor in renamed_actors:
		var renamed_position := [0, 0] if renamed_actors.find(renamed_actor) == 0 else [1, 0]
		room_state.created_actor_positions[renamed_actor.character_id] = renamed_position
		CreatedActorRules.end_actor(renamed_actor, "dismissed")
	SpellEffects.remove(owner, renamed_parent, "dismissed")
	var actor_events: Array = room_state.get("source_end_continuations", {}).values().filter(func(p): return p.event.source_kind == "created_actor")
	var deaths: Array = actor_events.filter(func(p): return p.event.end_reason == "death")
	var expiries: Array = actor_events.filter(func(p): return p.event.end_reason == "expired")
	var dismissals: Array = actor_events.filter(func(p): return p.event.end_reason == "dismissed")
	var clean: bool = actors.size() == 2 and created.get("created", false) and death.get("source_id", "") == actors[0].character_id and deaths.size() == 1 and expiries.size() == 1 and dismissals.size() == 2 and renamed_created.get("created", false) and actor_events.filter(func(p): return p.event.definition_id == RENAMED_ACTOR_SPELL).size() == 2 and not owner.spell_effects.has(parent_source) and not owner.spell_effects.has(renamed_parent) and not room_state.created_actor_positions.has(actors[1].character_id) and renamed_actors.all(func(a): return not room_state.created_actor_positions.has(a.character_id))
	var due_at := int(GameManager.campaign_elapsed_seconds)
	for pending in room_state.get("source_end_continuations", {}).values(): due_at = maxi(due_at, int(pending.due_at_seconds))
	GameManager.campaign_elapsed_seconds = due_at
	LocatedSourceEndRules.observe(room_state, [owner])
	var item_objects: Array = room_state.objects.filter(func(o): return o.get("name", "") in ["Copy spark", "Expired copy spark", "Renamed copy spark"])
	check.call(exact_items and item_objects.size() == 3 and item_objects.any(func(o): return o.name == "Copy spark" and o.position == [0, 0]) and item_objects.any(func(o): return o.name == "Expired copy spark" and o.position == [1, 0]) and item_objects.any(func(o): return o.name == "Renamed copy spark" and o.position == [2, 0]) and owner.inventory.get_instance(first_id).instance_id == first_id and owner.inventory.get_instance(second_id).instance_id == second_id and owner.inventory.get_instance(renamed_id).is_empty(), "Identical and renamed item copies keep distinct dismissal/expiry/destruction children and pre-reversion locations")
	var actor_objects: Array = room_state.objects.filter(func(o): return o.get("name", "") in ["Actor spark", "Expired actor spark", "Renamed actor spark"])
	var persistent: bool = DungeonPersistence.local_error(room_state).is_empty() and LocatedSourceEndRules.saved_producers_error([room_state]).is_empty()
	check.call(clean and actor_objects.size() == 4 and actor_objects.any(func(o): return o.name == "Actor spark" and o.position == [0, 0]) and actor_objects.any(func(o): return o.name == "Expired actor spark" and o.position == [1, 0]) and actor_objects.filter(func(o): return o.name == "Renamed actor spark").size() == 2 and persistent, "Created actor death, expiry and renamed-source dismissal remain distinct; duplicate death callbacks do not replay and saved producers validate: " + JSON.stringify({"created": created.get("created", false), "renamed_created": renamed_created.get("created", false), "event_count": actor_events.size(), "death": deaths.size(), "expiry": expiries.size(), "dismissal": dismissals.size(), "renamed_events": actor_events.filter(func(p): return p.event.definition_id == RENAMED_ACTOR_SPELL).size(), "object_names": actor_objects.map(func(o): return o.name), "clean": clean, "producer_error": LocatedSourceEndRules.saved_producers_error([room_state]), "room_error": DungeonPersistence.local_error(room_state)}))
	GameManager.transition_context = previous_context
	GameManager.current_state = previous_state
	GameManager.active_dungeon_state = previous_active
	PartyManager.characters = previous_characters

static func _pending_copy_origin(check: Callable) -> void:
	var old_context := GameManager.transition_context
	var old_active := GameManager.active_dungeon_state
	var old_characters := PartyManager.characters
	var old_clock := GameManager.campaign_elapsed_seconds
	var owner := Batch031Checks._character("pending-located-copy")
	var origin := room(owner)
	GameManager.transition_context = {"local_room": origin}
	GameManager.active_dungeon_state = {"local_rooms": {origin.id: origin}}
	PartyManager.characters = {owner.character_id: owner}
	owner.inventory.add_item(ITEM)
	var id := str(owner.inventory.copies.backpack[-1])
	ItemProjectionRules.project(owner, id)
	origin.created_actor_positions[ItemProjectionRules.actor_id(id)] = [0, 0]
	ItemFormReturnChecks.fill(owner)
	origin.walls = [[1, 0], [2, 0]]
	ItemProjectionRules.actor(owner, id).take_damage(100)
	var captured_at := int(GameManager.campaign_elapsed_seconds)
	var dto: Dictionary = JSON.parse_string(JSON.stringify(owner.to_dict()))
	check.call(dto.item_projections.has(id) and ItemProjectionRules.saved_error(dto).is_empty(), "Blocked lethal item return retains checkpointable captured end facts")
	for defect in ["time", "origin"]:
		var bad := dto.duplicate(true)
		if defect == "time": bad.item_projections[id].ending.ended_at_seconds = -1
		else: bad.item_projections[id].ending.final_location.room_id = "foreign-room"
		check.call(not ItemProjectionRules.saved_error(bad).is_empty(), "Malformed pending item end %s refuses checkpoint validation" % defect)
	var restored := Character.new()
	restored.from_dict(dto)
	PartyManager.characters = {restored.character_id: restored}
	var next_room := room(restored)
	next_room.id = "pending-next-room"
	GameManager.active_dungeon_state.local_rooms[next_room.id] = next_room
	GameManager.transition_context = {"local_room": next_room}
	GameManager.campaign_elapsed_seconds += 60
	restored.inventory.take_instance(str(restored.inventory.backpack_instances()[0].instance_id))
	var settled := ItemProjectionRules.settle(restored)
	var queue: Array = origin.get("source_end_continuations", {}).values()
	check.call(settled == [id] and queue.size() == 1 and LocalRoomRules.coord(queue[0].event.final_location.position) == Vector2i.ZERO and queue[0].event.final_location.room_id == origin.id and int(queue[0].event.ended_at_seconds) == captured_at and next_room.get("source_end_continuations", {}).is_empty(), "Reloaded blocked item return settles its aftermath once in the captured dormant room with its original end time")
	if not queue.is_empty():
		var now := GameManager.campaign_elapsed_seconds
		GameManager.campaign_elapsed_seconds = int(queue[0].due_at_seconds)
		LocatedSourceEndRules.observe(origin, [restored])
		LocatedSourceEndRules.observe(origin, [restored])
		check.call(origin.objects.filter(func(object): return object.get("name") == "Dead copy spark" and LocalRoomRules.coord(object.position) == Vector2i.ZERO).size() == 1, "Recovered pending item death produces one actual child at the original room origin")
		GameManager.campaign_elapsed_seconds = now
	GameManager.transition_context = old_context
	GameManager.active_dungeon_state = old_active
	PartyManager.characters = old_characters
	GameManager.campaign_elapsed_seconds = old_clock

static func _snapshot_once(check: Callable, actor: Character) -> void:
	var previous_active := GameManager.active_dungeon_state
	var previous_snapshots := GameManager.dungeon_snapshots
	var previous_characters := PartyManager.characters
	var previous_context := GameManager.transition_context
	var state := room(actor)
	GameManager.active_dungeon_state = {"dungeon_id": "located-snapshot-proof", "rooms": [], "party_position": [0, 0], "local_rooms": {"1": state}, "local_room_id": "1"}
	GameManager.transition_context = {"local_room": state}
	PartyManager.characters = {actor.character_id: actor}
	actor.current_hp = 10
	var cast := CombatAction.resolve_spell(actor, actor, DataLoader.get_spell(SPELL), false)
	SpellEffects.remove(actor, str(cast.effect_cast.source_id), "dismissed")
	GameManager.dungeon_snapshots = {"located-snapshot-proof": SaveManager._serialize_dungeon_state(GameManager.active_dungeon_state)}
	GameManager.advance_campaign_time(1)
	check.call(actor.current_hp == 12 and state.source_end_continuations.values()[0].remaining.is_empty(), "Active room plus dormant snapshot observe one automatic heal, not two")
	GameManager.active_dungeon_state = {}
	GameManager.transition_context = {}
	GameManager.advance_campaign_time(1)
	check.call(actor.current_hp == 12 and GameManager.dungeon_snapshots["located-snapshot-proof"].local_rooms["1"].source_end_continuations.values()[0].remaining.is_empty(), "Dormant dungeon retains consumed automatic child after leaving without replay")
	GameManager.active_dungeon_state = previous_active
	GameManager.dungeon_snapshots = previous_snapshots
	PartyManager.characters = previous_characters
	GameManager.transition_context = previous_context
