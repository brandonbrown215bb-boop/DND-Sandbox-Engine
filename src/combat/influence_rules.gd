## Bounded visible-gesture Influence against exact creatures in captured rooms.
class_name InfluenceRules
extends RefCounted

const SKILLS := {"Intimidation":"CHA", "Performance":"CHA", "Animal Handling":"WIS", "Persuasion":"CHA", "Deception":"CHA"}


static func definition_error(monster: Dictionary) -> String:
	if not monster.has("influence"): return ""
	var rule: Variant = monster.influence
	if not rule is Dictionary: return "Influence needs an authored profile."
	for key in rule:
		if key not in ["attitude", "manipulates_objects", "requests"]: return "Unsupported Influence profile field."
	if rule.get("attitude", "indifferent") not in ["friendly", "indifferent", "hostile"] or not rule.get("manipulates_objects") is bool or not rule.manipulates_objects: return "Influence needs a valid attitude and declared object manipulation."
	if not monster.get("ability_scores") is Dictionary or not ResourcePoolRules._integer(monster.ability_scores.get("INT"), 1, 1000): return "Influence needs the creature's actual Intelligence score."
	if monster.has("free_hands") and not ResourcePoolRules._integer(monster.free_hands, 0, 100): return "Influence free hands must be represented as an integer."
	if monster.has("plane") and not _text(monster.plane): return "Influence needs a valid represented plane."
	var requests: Variant = rule.get("requests")
	if not requests is Array or requests.is_empty() or requests.size() > 32: return "Influence needs 1-32 authored requests."
	var ids := {}
	for request in requests:
		if not request is Dictionary or request.size() != 4: return "Influence requests need id, label, outcome and approaches."
		for key in ["id", "label"]:
			if not _text(request.get(key)): return "Influence request identity or label is invalid."
		if ids.has(request.id): return "Influence request identity is duplicated."
		ids[request.id] = true
		var outcome: Variant = request.get("outcome")
		if not outcome is Dictionary or outcome.size() != 2 or outcome.get("action") not in ["open", "close"] or not _text(outcome.get("object_id")): return "Influence outcomes need an exact object and open/close action."
		var approaches: Variant = request.get("approaches")
		if not approaches is Array or approaches.is_empty() or approaches.size() > 16: return "Influence needs 1-16 authored approaches."
		var ways := {}
		for approach in approaches:
			if not approach is Dictionary or approach.size() not in [5, 6]: return "Influence approaches need id, label, skill, disposition, reason and optional spoken mode."
			for key in ["id", "label", "reason"]:
				if not _text(approach.get(key)): return "Influence approach identity, description or motivation is invalid."
			var spoken: bool = str(approach.get("mode", "gesture")) == "spoken"
			if ways.has(approach.id) or not SKILLS.has(approach.get("skill")) or approach.get("disposition") not in ["willing", "unwilling", "hesitant"] or (approach.has("mode") and not spoken) or (spoken and approach.skill not in ["Persuasion", "Deception"]) or (not spoken and approach.skill in ["Persuasion", "Deception"]): return "Influence approach identity, communication mode, skill or disposition is invalid."
			ways[approach.id] = true
			if approach.skill == "Animal Handling" and str(monster.get("creature_type", "")).to_lower() not in ["beast", "monstrosity"]: return "Animal Handling Influence needs a Beast or Monstrosity."
	return ""


static func _text(value: Variant) -> bool:
	return value is String and not value.strip_edges().is_empty() and value.length() <= 4000


static func request_for(profile: Dictionary, id: String) -> Dictionary:
	for request in profile.get("requests", []):
		if request.id == id: return request
	return {}


static func approach_for(request: Dictionary, id: String) -> Dictionary:
	for approach in request.get("approaches", []):
		if approach.id == id: return approach
	return {}


static func ledger_error(room: Dictionary) -> String:
	var rows: Variant = room.get("influence_attempts", [])
	if not rows is Array or rows.size() > 1000: return "Influence attempt records are malformed."
	var seen := {}
	var fulfilled := {}
	for row in rows:
		if not row is Dictionary or row.size() != 7: return "Influence attempts need exact source, actor, request, approach, result and deadline."
		if not ResourcePoolRules._integer(row.get("encounter_index"), 0, room.get("encounter_monsters", []).size() - 1): return "Influence attempt creature index is invalid."
		if row.get("monster_id") != room.encounter_monsters[int(row.encounter_index)] or not _text(row.get("actor_id")) or not _text(row.get("request_id")) or not _text(row.get("approach_id")) or row.get("result") not in ["failed", "fulfilled"] or not ResourcePoolRules._integer(row.get("retry_at"), 0, 1000000000000): return "Influence attempt identity, result or deadline is invalid."
		var definition: Dictionary = DataLoader.get_monster(str(row.monster_id))
		if not definition_error(definition).is_empty(): return "Influence attempt has no valid source profile."
		var request := request_for(definition.get("influence", {}), str(row.get("request_id", "")))
		var approach := approach_for(request, str(row.get("approach_id", "")))
		if request.is_empty() or approach.is_empty(): return "Influence attempt references an unknown request or approach."
		if row.result == "fulfilled" and int(row.retry_at) != 0: return "Fulfilled Influence cannot retain a retry deadline."
		if (row.result == "fulfilled" and approach.disposition == "unwilling") or (row.result == "failed" and (approach.disposition != "hesitant" or int(row.retry_at) == 0)): return "Influence receipt contradicts its authored disposition."
		var key := [int(row.encounter_index), row.actor_id, row.request_id, row.approach_id]
		if seen.has(key): return "Influence attempt is duplicated."
		seen[key] = true
		var source := [int(row.encounter_index), row.request_id]
		if row.result == "fulfilled":
			if fulfilled.has(source): return "Influence fulfillment is duplicated."
			fulfilled[source] = true
	return ""


static func availability(room: Dictionary, monster: Dictionary, actor: Character, request_id: String, approach_id: String) -> String:
	for row in room.get("influence_attempts", []):
		if row.encounter_index != monster.encounter_index or row.request_id != request_id: continue
		if row.result == "fulfilled": return "That creature has already fulfilled this request."
		if row.actor_id == actor.character_id and row.approach_id == approach_id and int(GameManager.campaign_elapsed_seconds) < int(row.retry_at): return "The 24-hour retry delay for this approach has not ended."
	return ""


static func target_error(state, actor: Character, room: Dictionary, monster: Dictionary, position: Vector2i) -> String:
	if room.is_empty() or not is_same(LocalRoomCombat.room(), room): return "Influence needs this encounter's captured room."
	if monster.is_empty() or not state.monster_entities.any(func(candidate): return is_same(candidate, monster)) or monster.get("hex_position") != position or not monster.get("is_alive", false) or int(monster.get("current_hp", 0)) <= 0 or CombatAction.is_incapacitated(monster): return "That exact creature is no longer able and present."
	var reason := definition_error(monster)
	if not reason.is_empty(): return reason
	if not monster.has("influence"): return "Unknown: this creature has no authored requests."
	var index: Variant = monster.get("encounter_index")
	if not ResourcePoolRules._integer(index, 0, room.get("encounter_monsters", []).size() - 1) or room.encounter_monsters[int(index)] != monster.get("monster_id"): return "Influence needs an exact represented encounter creature."
	if actor == null or not actor.is_alive or CombatAction.is_incapacitated(actor): return "You cannot Influence now."
	var entity: Dictionary = state.ready_actions.owner_entity(state, actor)
	if entity.is_empty() or not ContainmentRules.relation(room, "character", actor.character_id).is_empty(): return "Choose a present character outside containment."
	if PhysicalFactsRules.get_plane(actor, room) != PhysicalFactsRules.get_plane(monster, room): return "The creature is on another plane."
	var origin: Vector2i = entity.hex_position
	var altitude := int(entity.get("altitude_feet", LocalRoomRules.elevation_feet(room, origin)))
	var target_altitude := int(monster.get("altitude_feet", LocalRoomRules.elevation_feet(room, position)))
	if HexUtils.get_distance(origin, position) > 6 or abs(altitude - target_altitude) > 30: return "Move within 30 feet to communicate."
	if not state.hex_grid.has_tile(position): return "The creature has no represented space."
	var gesture_ok: bool = CombatPerception.can_see_target(actor, monster, origin, position, state.hex_grid) and CombatPerception.can_see_target(monster, actor, position, origin, state.hex_grid)
	var spoken_ok: bool = false
	for request in monster.influence.get("requests", []):
		for approach in request.get("approaches", []):
			if str(approach.get("mode", "gesture")) == "spoken" and CommunicationRules.eligibility_error(actor, monster, origin, position, state.hex_grid, room).is_empty():
				spoken_ok = true
				break
		if spoken_ok: break
	if not gesture_ok and not spoken_ok: return "You need visible gestures or a language the creature understands and an open sound route."
	return ledger_error(room)


static func targets(state, actor: Character) -> Dictionary:
	var result := {}
	for monster in state.monster_entities:
		var position: Vector2i = monster.hex_position
		if target_error(state, actor, LocalRoomCombat.room(), monster, position).is_empty():
			if not result.has(position): result[position] = []
			result[position].append(monster)
	return result


static func outcome_error(state, room: Dictionary, monster: Dictionary, object: Dictionary, outcome: Dictionary) -> String:
	if object.is_empty() or not is_same(LocalRoomRules.get_object(room, str(outcome.object_id)), object) or bool(object.get("removed", false)) or int(object.get("hp", 1)) <= 0 or object.get("kind") not in ["door", "container"]: return "The requested object is no longer available."
	if object.has("discovery"): return "Concealed objects need a creature discovery host before Influence can operate them."
	if ContainmentRules.involved(room, "object", str(object.id)) or PhysicalFactsRules.get_plane(monster, room) != PhysicalFactsRules.get_plane(object, room): return "The creature cannot reach that object across containment or planes."
	var origin: Vector2i = monster.hex_position
	var position := LocalRoomRules.coord(object.position)
	var altitude := int(monster.get("altitude_feet", LocalRoomRules.elevation_feet(room, origin)))
	var object_altitude := int(object.get("altitude_feet", LocalRoomRules.elevation_feet(room, position)))
	if HexUtils.get_distance(origin, position) > 1 or abs(altitude - object_altitude) > 5 or PhysicalFactsRules.get_free_hands(monster) < 1 or not Targeting.has_line_of_sight(origin, position, state.hex_grid): return "The creature must be able to manipulate the object within 5 feet."
	if outcome.action == "open" and (CombatObjectRules.is_locked(object, int(GameManager.campaign_elapsed_seconds)) or bool(object.get("barred", false)) or bool(object.get("stuck", false)) or bool(object.get("jammed", false))): return "The object cannot be opened normally."
	var sounds: Variant = object.get("interaction_noise", {})
	if not sounds is Dictionary: return "Object interaction_noise must map operations to sounds."
	if sounds.has(outcome.action): return CombatNoiseRules.error(sounds[outcome.action])
	return ""


## Profile attitude, read as Indifferent while a Hostile creature carries an
## attitude_indifferent marker; the profile is never rewritten, so the
## original attitude returns as soon as the marker ends.
static func effective_attitude(monster: Dictionary) -> String:
	var attitude := str(monster.get("influence", {}).get("attitude", "indifferent"))
	if attitude == "hostile" and not CombatAction.conditions_with_consequence(monster, "attitude_indifferent").is_empty():
		return "indifferent"
	return attitude


static func roll(actor: Character, monster: Dictionary, approach: Dictionary, context: Dictionary) -> Dictionary:
	var actual := context.duplicate()
	actual["social_target"] = monster
	actual["influence_action"] = true
	actual["influence_attitude"] = effective_attitude(monster)
	return EventResolver.resolve_skill_check(actor, {"ability":SKILLS[approach.skill], "skill":str(approach.skill), "dc":maxi(15, int(monster.get("ability_scores", {}).get("INT", 10)))}, {}, actual)


static func request(state, actor: Character, monsters: Array, position: Vector2i, current: Callable, pay: Callable) -> Dictionary:
	var room := LocalRoomCombat.room()
	if not current.call(): return {"status":"stale"}
	monsters = monsters.filter(func(monster): return target_error(state, actor, room, monster, position).is_empty())
	if monsters.is_empty(): return {"status":"refused", "message":"Unknown or unavailable Influence target."}
	var monster: Dictionary = monsters[0]
	if monsters.size() > 1:
		var ids: Array[String] = []
		var labels := {}
		for candidate in monsters: ids.append(str(candidate.id)); labels[str(candidate.id)] = str(candidate.name)
		var picked: String = await state.hud._request_popup_choice("Influence: choose the exact creature", ids, labels)
		if picked.is_empty(): return {"status":"ignored"}
		if picked not in ids: return {"status":"stale"}
		monster = monsters[ids.find(picked)]
	if not current.call() or not target_error(state, actor, room, monster, position).is_empty(): return {"status":"stale"}
	var captured: Dictionary = monster.influence.duplicate(true)
	var ids: Array[String] = []
	var labels := {}
	for entry in captured.requests: ids.append(str(entry.id)); labels[str(entry.id)] = str(entry.label)
	var selected: String = await state.hud._request_popup_choice("Influence: choose a request", ids, labels)
	if selected.is_empty(): return {"status":"ignored"}
	if selected not in ids or not current.call() or not target_error(state, actor, room, monster, position).is_empty() or monster.influence != captured: return {"status":"stale"}
	var chosen := request_for(captured, selected)
	var object := LocalRoomRules.get_object(room, str(chosen.outcome.object_id))
	var object_position: Variant = object.get("position", []).duplicate()
	ids.clear(); labels = {}
	for way in chosen.approaches: ids.append(str(way.id)); labels[str(way.id)] = "%s (%s)" % [str(way.label), str(way.skill)]
	var way_id: String = await state.hud._request_popup_choice("Influence: choose your gesture", ids, labels)
	if way_id.is_empty(): return {"status":"ignored"}
	if way_id not in ids or not current.call() or not target_error(state, actor, room, monster, position).is_empty() or monster.influence != captured or object.get("position", []) != object_position: return {"status":"stale"}
	var unavailable := availability(room, monster, actor, selected, way_id)
	if not unavailable.is_empty(): return {"status":"refused", "message":unavailable}
	if room.get("influence_attempts", []).size() >= 1000: return {"status":"refused", "message":"This room has no Influence record capacity."}
	var reason := outcome_error(state, room, monster, object, chosen.outcome)
	if not reason.is_empty(): return {"status":"refused", "message":reason}
	var approach := approach_for(chosen, way_id)
	if str(approach.get("mode", "gesture")) == "spoken":
		reason = CommunicationRules.eligibility_error(actor, monster, state.ready_actions.owner_entity(state, actor).hex_position, position, state.hex_grid, room)
	else:
		var speaker_position: Vector2i = state.ready_actions.owner_entity(state, actor).hex_position
		if not CombatPerception.can_see_target(actor, monster, speaker_position, position, state.hex_grid) or not CombatPerception.can_see_target(monster, actor, position, speaker_position, state.hex_grid): reason = "Both creatures must actually see the gestures."
	if not reason.is_empty(): return {"status":"refused", "message":reason}
	var check := {}
	var complies: bool = approach.disposition == "willing"
	if approach.disposition == "hesitant":
		check = roll(actor, monster, approach, state._ability_check_context(actor, monster))
		complies = bool(check.success)
	# Guards, roll, consequence, receipt and payment are synchronous after choices.
	if complies:
		var adapter: Character = state._make_temp_monster_character(monster)
		var applied := LocalRoomRules.interact(room, str(object.id), str(chosen.outcome.action), adapter, "", {"actor_position":position})
		assert(applied.success, "Influence outcome was checked immediately before settlement")
	var paid := bool(pay.call())
	assert(paid, "Influence cost was checked immediately before synchronous settlement")
	if not room.has("influence_attempts"): room["influence_attempts"] = []
	if complies or not check.is_empty():
		var rows: Array = room.influence_attempts
		for old in rows.duplicate():
			if old.encounter_index == monster.encounter_index and old.actor_id == actor.character_id and old.request_id == selected and old.approach_id == way_id: rows.erase(old)
		rows.append({"encounter_index":int(monster.encounter_index), "monster_id":str(monster.monster_id), "actor_id":actor.character_id, "request_id":selected, "approach_id":way_id, "result":"fulfilled" if complies else "failed", "retry_at":0 if complies else int(GameManager.campaign_elapsed_seconds) + 86400})
	state._update_grid_entities()
	if str(approach.get("mode", "gesture")) == "spoken":
		var speaker_entity: Dictionary = state.ready_actions.owner_entity(state, actor)
		await state.ready_actions.publish(state, {"type":"sound", "actor":actor, "position":speaker_entity.get("hex_position", position), "noise":CommunicationRules.SPOKEN_SOUND.duplicate(true)})
	if complies and object.get("interaction_noise", {}).has(chosen.outcome.action):
		await state.ready_actions.publish(state, {"type":"sound", "actor":monster, "position":position, "noise":object.interaction_noise[chosen.outcome.action].duplicate(true)})
	var detail := "%s %d vs DC %d" % [str(approach.skill), int(check.total), int(check.dc)] if not check.is_empty() else "no check required"
	return {"status":"resolved", "success":complies, "check":check, "message":"%s: %s — %s; %s" % [str(monster.name), str(chosen.label), detail, "the creature complies." if complies else "the creature refuses."]}
