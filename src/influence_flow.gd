class_name InfluenceFlow
extends RefCounted

const SLOT := "influence"
const PLAYER_SLOT := "influence_players"


static func fixtures() -> void:
	DataLoader._load_json_file("res://data/fixtures/ordinary_actions/influence_monsters.json", "monster")
	var source: Dictionary = DataLoader.get_monster("fixture:gesture_sentry")
	for request in source.get("influence", {}).get("requests", []):
		if request.id == "gate":
			if InfluenceRules.approach_for(request, "spoken_persuade").is_empty(): request.approaches.append({"id":"spoken_persuade", "label":"Appeal for cooperation", "skill":"Persuasion", "disposition":"hesitant", "reason":"A spoken appeal may persuade the sentry to cooperate.", "mode":"spoken"})
			if InfluenceRules.approach_for(request, "spoken_deceive").is_empty(): request.approaches.append({"id":"spoken_deceive", "label":"Deceive the sentry", "skill":"Deception", "disposition":"willing", "reason":"A spoken deception gets the sentry to cooperate.", "mode":"spoken"})
			if InfluenceRules.approach_for(request, "spoken_unwilling").is_empty(): request.approaches.append({"id":"spoken_unwilling", "label":"Make a hollow promise", "skill":"Deception", "disposition":"unwilling", "reason":"The sentry refuses a promise that would abandon its post.", "mode":"spoken"})
		elif request.id == "close_gate" and InfluenceRules.approach_for(request, "spoken_deceive").is_empty():
			request.approaches.append({"id":"spoken_deceive", "label":"Deceive the sentry", "skill":"Deception", "disposition":"willing", "reason":"A spoken deception gets the sentry to cooperate.", "mode":"spoken"})


static func logic(check: Callable) -> void:
	fixtures()
	var actor := PerceptionChecks.actor("influencer")
	var other := PerceptionChecks.actor("other_influencer")
	var monster := DataLoader.get_monster("fixture:gesture_sentry").duplicate(true)
	check.call(not monster.is_empty(), "S237 Influence fixture loads through production monster validation: " + str(DataLoader.get_load_errors()))
	if monster.is_empty(): return
	monster.merge({"id":"monster_0", "monster_id":monster.id, "encounter_index":0, "hex_position":Vector2i(1,0), "is_alive":true, "current_hp":100, "conditions":{}, "condition_sources":{}})
	var grid := PerceptionChecks.grid()
	var context := {"grid":grid, "actor_position":Vector2i.ZERO, "participants":[{"character":actor, "hex_position":Vector2i.ZERO}, monster]}
	actor.known_languages.assign(["Common", "Elvish"])
	other.known_languages.assign(["Common"])
	monster["languages"] = ["Goblin"]
	check.call(CommunicationRules.can_communicate(actor, other, Vector2i.ZERO, Vector2i(1,0), grid, {}) and CommunicationRules.shared_language(actor, other) == "Common", "OA-08 actual language overlap permits speech only when the represented listener understands it")
	check.call(not CommunicationRules.can_communicate(actor, monster, Vector2i.ZERO, Vector2i(1,0), grid, {}) and CommunicationRules.shared_language(actor, monster).is_empty(), "OA-08 hearing a voice does not grant unknown or unshared language comprehension")
	monster["languages"] = ["Common"]
	monster["plane"] = "ethereal"
	check.call(not CommunicationRules.can_communicate(actor, monster, Vector2i.ZERO, Vector2i(1,0), grid, {}), "OA-08 spoken language cannot cross planes")
	monster.erase("plane")
	other.add_condition("deafened", 10)
	check.call(not CommunicationRules.can_communicate(actor, other, Vector2i.ZERO, Vector2i(1,0), grid, {}), "OA-08 Deafened listener cannot hear speech")
	other.remove_condition("deafened")
	actor.add_condition("silenced", 10)
	check.call(not CommunicationRules.can_communicate(actor, other, Vector2i.ZERO, Vector2i(1,0), grid, {}), "OA-08 a silenced speaker cannot produce spoken communication")
	actor.remove_condition("silenced")
	var stale_listener: Dictionary = {"languages":["Common"], "is_alive":false, "current_hp":0}
	check.call(not CommunicationRules.can_communicate(actor, stale_listener, Vector2i.ZERO, Vector2i(1,0), grid, {}), "OA-08 a stale/dead listener cannot receive speech")
	grid.get_tile(Vector2i(1,0)).custom_properties["blocks_sound"] = true
	check.call(not CommunicationRules.can_communicate(actor, other, Vector2i.ZERO, Vector2i(1,0), grid, {}), "OA-08 represented sound obstruction blocks speech")
	grid.get_tile(Vector2i(1,0)).custom_properties["blocks_sound"] = false
	check.call(not CommunicationRules.can_communicate(actor, other, Vector2i.ZERO, Vector2i(2,0), grid, {}, 5), "OA-08 declared communication range is enforced")
	check.call(not CommunicationRules.can_communicate(actor, other, Vector2i.ZERO, Vector2i(1,0), grid, {}, 0), "OA-08 an unavailable listener range refuses speech")
	var saved_languages := actor.to_dict()
	var restored_actor := Character.new()
	restored_actor.from_dict(JSON.parse_string(JSON.stringify(saved_languages)))
	check.call(restored_actor.known_languages == actor.known_languages and CommunicationRules.saved_languages_error({"character_id":"fixture", "known_languages":["Common", "Common"]}) != "", "OA-08 durable language knowledge round-trips and duplicate saved facts fail validation")
	var way: Dictionary = monster.influence.requests[0].approaches[1]
	monster.influence.attitude = "friendly"
	var result := InfluenceRules.roll(actor, monster, way, context)
	check.call(result.advantage and result.dc == 18 and result.ability == "CHA", "S237 Influence uses actual creature Intelligence for DC and Friendly Advantage")
	actor.add_condition("poisoned", 10)
	result = InfluenceRules.roll(actor, monster, way, context)
	check.call(result.roll_mode == "normal", "S237 Friendly Influence Advantage cancels actual Poisoned Disadvantage")
	actor.remove_condition("poisoned")
	monster.influence.attitude = "hostile"
	check.call(InfluenceRules.roll(actor, monster, way, context).disadvantage, "S237 Hostile Influence actually rolls with Disadvantage")
	CombatAction.apply_condition(monster, "charmed", 100, actor.character_id)
	check.call(InfluenceRules.roll(actor, monster, way, context).roll_mode == "normal" and InfluenceRules.roll(other, monster, way, {}).disadvantage, "S237 only the actual charmer cancels Hostile Influence Disadvantage")
	var beast := DataLoader.get_monster("fixture:lever_monstrosity").duplicate(true)
	beast.influence.attitude = "indifferent"
	beast.ability_scores.INT = 4
	CombatAction.apply_condition(beast, "charmed", 100, actor.character_id)
	result = InfluenceRules.roll(actor, beast, beast.influence.requests[0].approaches[0], context)
	check.call(result.ability == "WIS" and result.dc == 15 and result.advantage, "S237 Animal Handling uses Wisdom/default DC 15 and actual charmer social Advantage")
	var bad := DataLoader.get_monster("fixture:gesture_sentry").duplicate(true)
	bad.influence.requests[0].approaches[0].skill = "Persuasion"
	check.call(not InfluenceRules.definition_error(bad).is_empty(), "S237 unsupported language-based Influence refuses content validation")
	bad = DataLoader.get_monster("fixture:gesture_sentry").duplicate(true); bad.influence.requests[0].outcome.action = "unlock"
	check.call(not InfluenceRules.definition_error(bad).is_empty(), "S237 undeclared world effects cannot masquerade as Influence outcomes")
	var source: Dictionary = DataLoader.get_monster("fixture:gesture_sentry")
	var numeric: Dictionary = source.influence.requests[0].duplicate(true)
	numeric.id = "1"; numeric.approaches = [numeric.approaches[1].duplicate(true)]; numeric.approaches[0].id = "1"
	source.influence.requests.append(numeric)
	var row := {"encounter_index":0, "monster_id":"fixture:gesture_sentry", "actor_id":actor.character_id, "request_id":"1", "approach_id":"1", "result":"failed", "retry_at":86400}
	var room := {"encounter_monsters":["fixture:gesture_sentry"], "influence_attempts":[row]}
	check.call(InfluenceRules.ledger_error(room).is_empty(), "S237 explicit string request/approach identities validate in source-pinned receipts")
	var clock := int(GameManager.campaign_elapsed_seconds)
	GameManager.campaign_elapsed_seconds = 86399
	check.call(not InfluenceRules.availability(room, monster, actor, "1", "1").is_empty() and InfluenceRules.availability(room, monster, other, "1", "1").is_empty(), "S237 failed Influence cooldown belongs to its exact actor and remains active before the deadline")
	GameManager.campaign_elapsed_seconds = 86400
	check.call(InfluenceRules.availability(room, monster, actor, "1", "1").is_empty(), "S237 failed Influence permits a new attempt at the inclusive 24-hour deadline")
	GameManager.campaign_elapsed_seconds = clock
	row.request_id = 1
	check.call(not InfluenceRules.ledger_error(room).is_empty(), "S237 numeric saved request identity cannot bypass exact retry matching")
	row.request_id = "1"; row.approach_id = 1
	check.call(not InfluenceRules.ledger_error(room).is_empty(), "S237 numeric saved approach identity cannot bypass exact retry matching")
	row.approach_id = "1"; room.influence_attempts.append(row.duplicate(true))
	check.call(not InfluenceRules.ledger_error(room).is_empty(), "S237 duplicate Influence attempts refuse save validation")
	source.influence.requests.pop_back()
	grid.free()


static func make_room(party: Array) -> Dictionary:
	var cells: Array = []
	for position in HexUtils.get_hexes_in_range(Vector2i.ZERO, 4): cells.append([position.x, position.y])
	return LocalRoomRules.create({"id":"fixture:influence_room", "name":"Gesture hall", "ambient_light":"bright", "cells":cells, "walls":[], "exits":[[-3,0]], "party_spawns":[[-1,0],[-2,0],[-1,1],[-2,1]], "monster_spawns":[[0,0],[1,0],[1,-1]], "encounter_monsters":["fixture:gesture_sentry", "fixture:renamed_gesture_sentry", "fixture:lever_monstrosity"], "objects":[
		{"id":"fixture:influence_gate", "name":"Influence gate", "kind":"door", "position":[0,1], "hp":20, "max_hp":20, "locked":false, "open":false, "contents":[], "interaction_noise":{"open":{"volume":"loud", "range_feet":60}}},
		{"id":"fixture:influence_latch", "name":"Latch box", "kind":"container", "position":[1,-1], "hp":20, "max_hp":20, "locked":false, "open":false, "contents":[]}
	]}, party)


static func attempt(h: Node, state: CombatState, actor: Character, monster: Dictionary, answers: Array, mutation: Callable = Callable()) -> Dictionary:
	h._p_focus(state, actor)
	await OrdinaryActionFlow.choose(h, state, "influence")
	h._assert(state.pending_action_type == "ordinary_influence" and state.turn_budget.can_spend("action"), "S237 actual Actions menu reaches unpaid Influence target selection")
	return await OrdinaryWorldActionFlow.choices(h, state, func(): await state._on_hex_clicked(monster.hex_position), answers, mutation)


static func run(h: Node) -> void:
	h._enter_test("influence_flow")
	h._setup_mixed_world()
	fixtures()
	var party: Array = PartyManager.characters.values()
	var room := make_room(party)
	GameManager.current_state = GameManager.GameState.COMBAT
	GameManager.transition_context = {"terrain":"plains", "monster_ids":room.encounter_monsters, "local_room":room}
	var state: CombatState = await h._spawn_scene("res://scenes/combat.tscn", 0.4)
	h._assert(state.monster_entities.size() == 3, "S237 loaded Influence definitions spawn through the actual encounter factory")
	if state.monster_entities.size() != 3:
		h._teardown_scene(state); h._exit_test(); return
	var actor: Character = state.player_entities[0].character
	var helper: Character = state.player_entities[1].character
	var monster: Dictionary = state.monster_entities[0]
	var second: Dictionary = state.monster_entities[1]
	var gate := LocalRoomRules.get_object(room, "fixture:influence_gate")
	var latch := LocalRoomRules.get_object(room, "fixture:influence_latch")
	h._assert(monster.has("influence") and monster.encounter_index == 0 and second.plane == "ethereal" and second.free_hands == 0, "S237 production monster spawn preserves loaded requests, exact slot, plane and free hands")
	h._assert(not InfluenceRules.targets(state, actor).values().any(func(group): return group.has(second)), "S237 loaded other-plane NPC cannot be influenced from this plane")
	actor.ability_scores.charisma = 50
	actor.ability_scores.wisdom = 50
	actor.known_languages.assign(["Common"])
	h._assert(InfluenceRules.definition_error(DataLoader.get_monster("fixture:gesture_sentry")).is_empty(), "OA-11 loaded spoken Persuasion/Deception approaches remain source-data validated")
	helper.skill_proficiencies.assign(["Intimidation", "Performance"])
	await attempt(h, state, actor, monster, [])
	h._assert(state.turn_budget.can_spend("action") and not gate.open and room.get("influence_attempts", []).is_empty(), "S237 cancelled Influence request pays nothing and makes no social outcome")
	await attempt(h, state, actor, monster, ["Open the gate"], func(): state.turn_budget.spend("action"))
	h._assert(not gate.open and room.get("influence_attempts", []).is_empty(), "S237 lost Action during request choice cannot produce a free outcome")
	var old_attitude: String = monster.influence.attitude
	await attempt(h, state, actor, monster, ["Open the gate"], func(): monster.influence.attitude = "friendly")
	h._assert(state.turn_budget.can_spend("action") and not gate.open, "S237 changed authored social facts invalidate an old question before payment")
	monster.influence.attitude = old_attitude
	h._p_focus(state, actor)
	await OrdinaryActionFlow.choose(h, state, "influence")
	monster.hex_position = Vector2i(0,-1)
	await state._on_hex_clicked(Vector2i.ZERO)
	h._assert(state.turn_budget.can_spend("action") and not gate.open, "S237 stale highlighted NPC cell cannot follow a moved creature")
	monster.hex_position = Vector2i.ZERO; state._update_grid_entities()
	gate.interaction_noise.open.range_feet = 0
	await attempt(h, state, actor, monster, ["Open the gate", "Offer the ritual greeting (Performance)"])
	h._assert(state.turn_budget.can_spend("action") and not gate.open and room.get("influence_attempts", []).is_empty(), "S237 malformed NPC object noise refuses before outcome, roll or payment")
	gate.interaction_noise.open.range_feet = 60
	CheckHelpRules.grant(helper, actor, "skill", "Performance")
	await attempt(h, state, actor, monster, ["Open the gate", "Mock the oath (Performance)"])
	h._assert(not state.turn_budget.can_spend("action") and not gate.open and actor.combat_check_help.size() == 1 and room.get("influence_attempts", []).is_empty(), "S237 authored Unwilling response pays Action but never rolls, consumes Help or complies")
	actor.combat_check_help.clear()
	actor.ability_scores.charisma = -100
	CheckHelpRules.grant(helper, actor, "skill", "Intimidation")
	var started := int(GameManager.campaign_elapsed_seconds)
	await attempt(h, state, actor, monster, ["Open the latch box", "Make a threatening gesture (Intimidation)"])
	h._assert(not state.turn_budget.can_spend("action") and not latch.open and actor.combat_check_help.is_empty() and int(room.influence_attempts[0].retry_at) == started + 86400, "S237 hesitant failure consumes its real check/Help/Action and stores the 24-hour exact-source retry")
	actor.ability_scores.charisma = 50
	await attempt(h, state, actor, monster, ["Open the latch box", "Make a threatening gesture (Intimidation)"])
	h._assert(state.turn_budget.can_spend("action") and not latch.open and room.influence_attempts.size() == 1, "S237 failed same-way retry refuses before roll, outcome or another payment")
	actor.known_languages.clear()
	await attempt(h, state, actor, monster, ["Open the gate", "Appeal for cooperation (Persuasion)"])
	h._assert(state.turn_budget.can_spend("action") and not gate.open and room.influence_attempts.size() == 1, "OA-11 spoken Influence refuses an unshared language before check, settlement or payment")
	actor.known_languages.assign(["Common"])
	await attempt(h, state, actor, monster, ["Open the gate", "Make a hollow promise (Deception)"])
	h._assert(not state.turn_budget.can_spend("action") and not gate.open and room.influence_attempts.size() == 1, "OA-11 understood spoken Deception that the creature finds repugnant pays its Action but cannot comply or consume an outcome")
	state.turn_budget.reset(actor, state.player_entities)
	await ReadyActionFlow.declare(h, state, helper, {"kind":"ordinary", "action":"dodge"}, {"event":"sound", "side":"enemy", "actor_id":str(monster.id)})
	CheckHelpRules.grant(helper, actor, "skill", "Performance")
	var result := await attempt(h, state, actor, monster, ["Open the gate", "Appeal for cooperation (Persuasion)"])
	h._assert(gate.open and state.hex_grid.is_hex_passable(Vector2i(0,1)) and not state.turn_budget.can_spend("action") and actor.combat_check_help.size() == 1 and room.influence_attempts.back().approach_id == "spoken_persuade" and room.influence_attempts.back().result == "fulfilled" and result.prompts == 1 and not helper.reaction_available, "OA-11 ordinary spoken Persuasion resolves its actual check, opens the real gate, preserves unrelated Help and publishes sound")
	state.turn_budget.reset(actor, state.player_entities)
	actor.combat_check_help.clear()
	second.plane = "material"; state._update_grid_entities()
	await attempt(h, state, actor, second, ["Open the gate", "Offer the ritual greeting (Performance)"])
	h._assert(state.turn_budget.can_spend("action") and room.influence_attempts.size() == 2, "S237 actual zero free hands refuses NPC manipulation without payment or borrowed fulfillment")
	await ReadyActionFlow.declare(h, state, actor, {"kind":"ordinary", "action":"influence"}, {"event":"action", "side":"ally", "actor_id":helper.character_id})
	h._p_focus(state, helper)
	await OrdinaryWorldActionFlow.choices(h, state, func(): await state._on_hud_action("ordinary_action", {"action":"dash"}), [], Callable(), monster.hex_position)
	h._assert(actor.reaction_available and state.ready_actions.held.has(actor.character_id), "S237 cancelled readied Influence preserves its held response and Reaction")
	h._p_focus(state, helper)
	await OrdinaryWorldActionFlow.choices(h, state, func(): await state._on_hud_action("ordinary_action", {"action":"dash"}), ["Close the gate", "Deceive the sentry (Deception)"], Callable(), monster.hex_position)
	h._assert(not gate.open and not actor.reaction_available and not state.turn_budget.can_spend("action") and room.influence_attempts.size() == 3, "OA-11 readied spoken Deception uses OA-08 language eligibility and closes the real door with its owner's Reaction")
	await attempt(h, state, actor, monster, ["Open the gate", "Offer the ritual greeting (Performance)"])
	h._assert(not gate.open and state.turn_budget.can_spend("action") and room.influence_attempts.size() == 3, "S237 fulfilled request cannot replay its world effect after another operation changed the door")
	h._assert(InfluenceRules.ledger_error(room).is_empty() and DungeonPersistence.local_error(room).is_empty(), "S237 settled Influence outcomes/cooldowns form valid room checkpoint state")
	LocalRoomCombat.capture(state.player_entities)
	h._teardown_scene(state)
	GameManager.current_state = GameManager.GameState.DUNGEON
	GameManager.transition_context = {"dungeon_id":"ruins_of_ashvale"}
	GameManager.active_dungeon_state.clear()
	var dungeon: DungeonState = await h._spawn_scene("res://scenes/dungeon.tscn", 0.2)
	dungeon.local_rooms["1"] = room
	dungeon.party_position = Vector2i.ZERO
	dungeon._save_dungeon_state_to_manager()
	h._assert(SaveManager.save_game(SLOT), "S237 allowed entrance checkpoint persists actual Influence door and retry receipts")
	var dto := SaveManager._read_save(SLOT)
	var bad := dto.duplicate(true)
	bad.active_dungeon_state.local_rooms["1"].influence_attempts[0].request_id = 1
	h._assert(not SaveManager._validate_save_data(bad).is_empty(), "S237 malformed saved Influence identities refuse before session replacement")
	dto.erase("party")
	h._assert(SaveManager._validate_save_data(dto).is_empty(), "S237 player-only Influence checkpoint passes ordinary preflight")
	var file := FileAccess.open(SaveManager.SAVE_DIR + PLAYER_SLOT + ".sav", FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify(dto)); file.close()
	h._assert(file != null, "S237 player-only Influence checkpoint is available to the fresh process")
	file = FileAccess.open("user://influence_expected.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"pid":OS.get_process_id(), "clock":GameManager.campaign_elapsed_seconds, "actor_id":actor.character_id, "receipts":room.influence_attempts}))
	file.close()
	h._teardown_scene(dungeon)
	h._exit_test()


static func reload(h: Node) -> void:
	h._enter_test("influence_reload")
	fixtures()
	var expected: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("user://influence_expected.json"))
	for slot in [SLOT, PLAYER_SLOT]:
		PlayerManager.reset(); PartyManager.reset(); GameManager.active_dungeon_state.clear()
		h._assert(OS.get_process_id() != int(expected.pid) and SaveManager.load_game(slot), "S237 Influence checkpoint recovers into a genuinely fresh process: " + slot)
		var room: Dictionary = GameManager.active_dungeon_state.local_rooms["1"]
		h._assert(room.influence_attempts == expected.receipts and int(GameManager.campaign_elapsed_seconds) == int(expected.clock) and not LocalRoomRules.get_object(room, "fixture:influence_gate").open, "S237 fresh load preserves exact Influence receipts, clock and later door state without replay")
		GameManager.current_state = GameManager.GameState.COMBAT
		GameManager.transition_context = {"terrain":"plains", "monster_ids":room.encounter_monsters, "local_room":room}
		var state: CombatState = await h._spawn_scene("res://scenes/combat.tscn", 0.3)
		var actor: Character = state.player_entities[0].character
		var monster: Dictionary = state.monster_entities[0]
		h._assert(actor.character_id == expected.actor_id and actor.known_languages.has("Common") and monster.encounter_index == 0, "OA-08 fresh load restores the actor's declared language with the original Influence participant and encounter slot")
		await attempt(h, state, actor, monster, ["Open the latch box", "Make a threatening gesture (Intimidation)"])
		h._assert(state.turn_budget.can_spend("action") and room.influence_attempts == expected.receipts, "S237 fresh encounter cannot evade the saved failed-approach cooldown")
		await attempt(h, state, actor, monster, ["Open the gate", "Offer the ritual greeting (Performance)"])
		h._assert(state.turn_budget.can_spend("action") and not LocalRoomRules.get_object(room, "fixture:influence_gate").open and int(GameManager.campaign_elapsed_seconds) == int(expected.clock), "S237 recovered fulfilled request cannot replay a door effect or charge again")
		h._teardown_scene(state)
	h._exit_test()
