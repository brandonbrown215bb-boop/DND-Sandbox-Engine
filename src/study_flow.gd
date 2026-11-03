class_name StudyFlow
extends RefCounted


static func objects() -> Array:
	return JSON.parse_string(FileAccess.get_file_as_string("res://data/fixtures/ordinary_actions/study_objects.json"))


static func recollections() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://data/fixtures/ordinary_actions/study_recollections.json"))


static func logic(check: Callable) -> void:
	var actor := PerceptionChecks.actor("scholar")
	var helper := PerceptionChecks.actor("scholar_helper")
	actor.ability_scores.intelligence = 50
	actor.known_languages.assign(["Common"])
	helper.known_languages.assign(["Common"])
	helper.skill_proficiencies.assign(["Arcana"])
	var definition: Dictionary = recollections()
	definition["id"] = "study-room"
	definition["name"] = "Study room"
	definition["objects"] = objects()
	var room := LocalRoomRules.create(definition, [actor, helper])
	var source := LocalRoomRules.get_object(room, "fixture:survey_stone")
	var other := LocalRoomRules.get_object(room, "fixture:renamed_stone")
	var grid := PerceptionChecks.grid()
	for member in [actor, helper]: grid.add_entity({"character":member, "hex_position":LocalRoomRules.coord(room.party_positions[member.character_id])})
	grid.perception_participants = grid.entities.duplicate()
	check.call(DungeonPersistence.local_error(room).is_empty() and StudyRules.answers(room, actor).is_empty(), "S237 authored Study questions start valid and their answers stay unknown")
	var result := StudyRules.room_study(room, actor, str(source.id), "not_authored", grid, [actor, helper])
	check.call(result.get("unknown", false) and result.seconds == 0 and not result.has("check"), "S237 unrepresented Study questions stay explicit unknown without fake success or payment")
	result = StudyRules.room_recollection(room, actor, "unlisted_memory", grid, [actor, helper])
	check.call(result.get("unknown", false) and result.seconds == 0 and not result.has("check"), "OA-10 unknown recollection question stays unknown without rolling or charging")
	var verbal_grant: Dictionary = CheckHelpRules.grant_room(room, helper, actor, "skill", "Arcana", [actor, helper], grid, true)
	check.call(verbal_grant.success, "OA-09 communication-eligible proficient helper can grant expiring verbal check assistance")
	helper.known_languages.clear()
	result = StudyRules.room_recollection(room, actor, "guarded_memory", grid, [actor, helper])
	check.call(not result.check.advantage and not result.success and actor.combat_check_help.size() == 1, "OA-09 ununderstood verbal Help cannot apply to its authored task or be consumed")
	helper.known_languages.assign(["Common"])
	grid.get_tile(Vector2i.ZERO).custom_properties["blocks_sound"] = true
	result = StudyRules.room_recollection(room, actor, "guarded_memory", grid, [actor, helper])
	check.call(not result.check.advantage and actor.combat_check_help.size() == 1, "OA-09 obstructed speech cannot apply its assistance or consume the grant")
	grid.get_tile(Vector2i.ZERO).custom_properties["blocks_sound"] = false
	result = StudyRules.room_recollection(room, actor, "unrelated_memory", grid, [actor, helper])
	check.call(not result.check.advantage and actor.combat_check_help.size() == 1, "OA-09 unrelated checks neither consume nor inherit pending verbal Help")
	var old_clock: int = int(GameManager.campaign_elapsed_seconds)
	GameManager.campaign_elapsed_seconds = int(actor.combat_check_help[0].expires_at_seconds)
	result = StudyRules.room_recollection(room, actor, "expired_memory", grid, [actor, helper])
	check.call(not result.check.advantage and actor.combat_check_help.is_empty(), "OA-09 expired verbal Help is discarded before a matching check")
	GameManager.campaign_elapsed_seconds = old_clock
	verbal_grant = CheckHelpRules.grant_room(room, helper, actor, "skill", "Arcana", [actor, helper], grid, true)
	actor.add_condition("poisoned", 10)
	result = StudyRules.room_recollection(room, actor, "old_oath", grid, [actor, helper])
	actor.remove_condition("poisoned")
	check.call(verbal_grant.success and result.success and result.seconds == 6 and result.check.ability == "INT" and result.check.roll_mode == "normal" and actor.combat_check_help.is_empty() and StudyRules.recollection_known(room, actor, "old_oath"), "OA-09 matching declared verbal Help composes with Poisoned Disadvantage and is consumed once; OA-10 records real Intelligence recollection knowledge")
	result = StudyRules.room_recollection(room, actor, "old_oath", grid, [actor, helper])
	check.call(result.remembered and result.seconds == 0 and not result.has("check") and StudyRules.recollection_answers(room, actor).size() == 1, "OA-10 learned recall is free and supplies the authored answer")
	result = StudyRules.room_recollection(room, helper, "failed_memory", grid, [actor, helper])
	check.call(not result.success and result.seconds == 6 and not StudyRules.recollection_known(room, helper, "failed_memory") and not str(result.message).contains("Ilyra"), "OA-10 failed recollection costs the room interval but does not disclose the answer")
	var saved_recollection_character := actor.to_dict()
	var restored_recollection_character := Character.new()
	restored_recollection_character.from_dict(JSON.parse_string(JSON.stringify(saved_recollection_character)))
	check.call(restored_recollection_character.known_recollections == actor.known_recollections and not StudyRules.saved_recollections_error({"known_recollections":{"study-room":["old_oath", "old_oath"]}}).is_empty(), "OA-10 exact observer memory receipt round-trips and duplicate saved facts are rejected")
	CheckHelpRules.grant_room(room, helper, actor, "skill", "Arcana", [actor, helper], grid)
	result = StudyRules.room_study(room, actor, str(source.id), "spiral", grid, [actor, helper])
	check.call(result.success and result.seconds == 6 and result.check.ability == "INT" and result.check.advantage and actor.combat_check_help.is_empty() and StudyRules.known(source, actor, "spiral") and not StudyRules.known(other, actor, "spiral") and not StudyRules.known(source, helper, "spiral"), "S237 real Intelligence Study consumes matching physical Help and learns only the exact source/question/observer")
	result = StudyRules.room_study(room, actor, str(source.id), "spiral", grid, [actor, helper])
	check.call(result.get("remembered", false) and result.seconds == 0 and not result.has("check") and source.studied_by.spiral.size() == 1, "S237 recalling an already learned answer rolls and spends nothing without duplicate receipts")
	result = StudyRules.room_study(room, actor, str(source.id), "age", grid, [actor, helper])
	check.call(not result.success and result.seconds == 6 and not StudyRules.known(source, actor, "age") and not str(result.message).contains("northern surveyors"), "S237 failed Study pays its real attempt and never exposes the authored answer")
	for id in ["seam", "lichen", "rite"]:
		result = StudyRules.room_study(room, actor, str(source.id), id, grid, [actor, helper])
		check.call(result.success and result.check.ability == "INT" and StudyRules.known(source, actor, id), "S237 Study uses the authored Intelligence knowledge skill: " + id)
	room.party_positions[actor.character_id] = [2,0]
	result = StudyRules.room_study(room, actor, str(other.id), "spiral", grid, [actor, helper])
	check.call(result.seconds == 0 and not result.has("check"), "S237 out-of-reach Study refuses before roll or cost")
	room.party_positions[actor.character_id] = [0,0]
	room.party_altitudes[actor.character_id] = 20
	check.call(StudyRules.room_study(room, actor, str(other.id), "spiral", grid, [actor, helper]).seconds == 0, "S237 Study rechecks actual vertical reach")
	room.party_altitudes[actor.character_id] = 0
	other["plane"] = "ethereal"
	check.call(StudyRules.room_study(room, actor, str(other.id), "spiral", grid, [actor, helper]).seconds == 0, "S237 Study cannot learn across planes")
	other.erase("plane")
	actor.add_condition("blinded", 10)
	check.call(StudyRules.room_study(room, actor, str(other.id), "spiral", grid, [actor, helper]).seconds == 0, "S237 observation Study requires actual sight")
	actor.remove_condition("blinded")
	other["discovery"] = {"dc":15, "range_feet":5}
	check.call(StudyRules.room_study(room, actor, str(other.id), "spiral", grid, [actor, helper]).seconds == 0, "S237 a forged undiscovered source ID cannot reveal knowledge")
	other.erase("discovery")
	source["removed"] = true
	check.call(StudyRules.answers(room, actor).size() == 5 and StudyRules.answers(room, helper).is_empty(), "S237 learned information remains remembered after its source is removed")
	source["removed"] = false
	var corrupt := room.duplicate(true)
	corrupt.objects[0].studied_by.spiral.append(actor.character_id)
	check.call(not DungeonPersistence.local_error(corrupt).is_empty(), "S237 duplicate Study observers refuse save preflight")
	corrupt = room.duplicate(true); corrupt.objects[0].studied_by["unrepresented"] = [actor.character_id]
	check.call(not DungeonPersistence.local_error(corrupt).is_empty(), "S237 orphaned Study question receipts refuse save preflight")
	corrupt = room.duplicate(true); corrupt.objects[0].erase("study")
	check.call(not DungeonPersistence.local_error(corrupt).is_empty(), "S237 Study receipts without their authored source questions refuse save preflight")
	corrupt = room.duplicate(true); corrupt.objects[0].study[0].skill = "Perception"
	check.call(not DungeonPersistence.local_error(corrupt).is_empty(), "S237 invalid Study skill definitions refuse save preflight")
	grid.free()


static func room_controls(h: Node, view: LocalRoomView) -> void:
	var actor := view.characters[0] as Character
	var helper := view.characters[1] as Character
	var room_definition: Dictionary = recollections()
	room_definition["objects"] = objects()
	room_definition["recollections"].append({"id":"memory", "question":"What route did the surveyors promise to keep open?", "skill":"Arcana", "dc":15, "answer":"They promised to keep the north road open.", "verbal_help":true})
	var loaded: Dictionary = LocalRoomRules.create(room_definition, [actor, helper])
	view.state.recollections = loaded.recollections.duplicate(true)
	view.state.objects.append_array(loaded.objects)
	view.state.party_positions[actor.character_id] = [0,0]
	view.state.party_positions[helper.character_id] = [1,0]
	helper.skill_proficiencies.assign(["Arcana"])
	actor.known_languages.assign(["Common"])
	helper.known_languages.assign(["Common"])
	WorldSearchFlow.select_actor(view, 1)
	for index in view.help_choices.item_count:
		if view.help_choices.get_item_metadata(index).name == "Arcana": view.help_choices.select(index)
	view.help_recipients.select(0)
	view.help_button.pressed.emit()
	WorldSearchFlow.select_actor(view, 0)
	for index in view.objects.item_count:
		if view.objects.get_item_metadata(index) == "fixture:survey_stone": view.objects.select(index)
	view.objects.item_selected.emit(view.objects.selected)
	for index in view.study_topics.item_count:
		if str(view.study_topics.get_item_metadata(index)) == "spiral": view.study_topics.select(index)
	view.study_topics.item_selected.emit(view.study_topics.selected)
	var started: int = int(GameManager.campaign_elapsed_seconds)
	h._assert(view.study_topics.item_count == 11 and not view.study_button.disabled and not view.knowledge.text.contains("ward against flame"), "S237 actual room Study offers authored questions while keeping unlearned answers out of knowledge")
	actor.ability_scores.intelligence = 50
	view.study_button.pressed.emit()
	var source := LocalRoomRules.get_object(view.state, "fixture:survey_stone")
	h._assert(StudyRules.known(source, actor, "spiral") and actor.combat_check_help.is_empty() and view.knowledge.text.contains("ward against flame") and int(GameManager.campaign_elapsed_seconds) == started + 6, "S237 actual room Study button consumes matching Help, learns its answer and pays six seconds once: " + str(view.last_action_result.get("message", "")))
	view.study_button.pressed.emit()
	h._assert(int(GameManager.campaign_elapsed_seconds) == started + 6 and source.get("studied_by", {}).get("spiral", []).size() == 1, "S237 actual known-answer recall is free and cannot duplicate knowledge")
	WorldSearchFlow.select_actor(view, 1)
	h._assert(not view.knowledge.text.contains("ward against flame"), "S237 switching room observers does not give away another character's knowledge")
	WorldSearchFlow.select_actor(view, 0)
	view.study_topics.select(1)
	view.study_button.pressed.emit()
	h._assert(int(GameManager.campaign_elapsed_seconds) == started + 12 and not view.knowledge.text.contains("northern surveyors"), "S237 actual failed Study button pays once and leaves the answer unknown")
	WorldSearchFlow.select_actor(view, 1)
	view.help_modes.select(1)
	view.grid.get_tile(Vector2i.ZERO).custom_properties["blocks_sound"] = false
	view.grid.get_tile(Vector2i(1,0)).custom_properties["blocks_sound"] = false
	for index in view.help_choices.item_count:
		if view.help_choices.get_item_metadata(index).name == "Arcana": view.help_choices.select(index)
	view.help_recipients.select(0)
	view.help_button.pressed.emit()
	view.help_modes.select(0)
	h._assert(actor.combat_check_help.size() == 1 and int(GameManager.campaign_elapsed_seconds) == started + 18, "OA-09 actual room controls pay once and grant declared-language verbal Help: " + str(view.last_action_result.get("message", "")))
	WorldSearchFlow.select_actor(view, 0)
	for index in view.study_topics.item_count:
		if str(view.study_topics.get_item_metadata(index)) == "recollection:memory": view.study_topics.select(index)
	view.study_topics.item_selected.emit(view.study_topics.selected)
	view.grid.get_tile(Vector2i.ZERO).custom_properties["blocks_sound"] = false
	view.grid.get_tile(Vector2i(1,0)).custom_properties["blocks_sound"] = false
	view.study_button.pressed.emit()
	view.refresh()
	h._assert(StudyRules.recollection_known(view.state, actor, "memory") and view.knowledge.text.contains("north road") and view.last_action_result.get("check", {}).get("advantage", false) and actor.combat_check_help.is_empty() and int(GameManager.campaign_elapsed_seconds) == started + 24, "OA-09 actual room task consumes declared verbal Help with Advantage once; OA-10 recollection Study costs one interval: " + str(view.last_action_result.get("message", "")))
	view.study_button.pressed.emit()
	h._assert(int(GameManager.campaign_elapsed_seconds) == started + 24, "OA-10 actual recollection recall is free after learning")
	await h.get_tree().process_frame


static func combat(h: Node, state: CombatState, actor: Character, helper: Character) -> void:
	var room := LocalRoomCombat.room()
	room.objects.append_array(LocalRoomRules.create({"id":"combat-study", "objects":objects(), "party_spawns":[[0,0],[1,0]]}, [actor, helper]).objects)
	var source := LocalRoomRules.get_object(room, "fixture:survey_stone")
	var other := LocalRoomRules.get_object(room, "fixture:renamed_stone")
	other["removed"] = true
	state.player_entities[0].hex_position = Vector2i.ZERO
	state.player_entities[1].hex_position = Vector2i(-1,0)
	actor.ability_scores.intelligence = 50
	helper.skill_proficiencies.assign(["Arcana"])
	state._update_grid_entities()
	await combat_study(h, state, actor, [])
	h._assert(state.turn_budget.can_spend("action") and StudyRules.answers(room, actor).is_empty(), "S237 cancelled combat Study spends nothing and learns nothing")
	h._p_focus(state, actor)
	await OrdinaryActionFlow.choose(h, state, "study")
	source.position = [1,0]
	await state._on_hex_clicked(Vector2i(0,1))
	h._assert(state.turn_budget.can_spend("action") and not StudyRules.known(source, actor, "spiral"), "S237 a source moved to another reachable cell cannot be studied through its stale highlighted cell")
	source.position = [0,1]
	state._update_grid_entities()
	await combat_study(h, state, actor, ["What does the spiral mean? (Arcana)"], func(): state.turn_budget.spend("action"))
	h._assert(not StudyRules.known(source, actor, "spiral"), "S237 lost Action during question choice cannot grant knowledge")
	var old_answer: String = source.study[0].answer
	await combat_study(h, state, actor, ["What does the spiral mean? (Arcana)"], func(): source.study[0].answer = "Changed question answer.")
	h._assert(state.turn_budget.can_spend("action") and not StudyRules.known(source, actor, "spiral"), "S237 changed authored question during the chooser refuses before cost or result")
	source.study[0].answer = old_answer
	await combat_study(h, state, actor, ["Who carved this stone? (History)"])
	h._assert(not state.turn_budget.can_spend("action") and not StudyRules.known(source, actor, "age"), "S237 actual failed combat Study spends its ordinary Action")
	CheckHelpRules.grant(helper, actor, "skill", "Arcana")
	await combat_study(h, state, actor, ["What does the spiral mean? (Arcana)"])
	h._assert(not state.turn_budget.can_spend("action") and StudyRules.known(source, actor, "spiral") and actor.combat_check_help.is_empty(), "S237 actual combat Study consumes matching Help, learns the exact answer and pays once")
	await combat_study(h, state, actor, ["What does the spiral mean? (Arcana)"])
	h._assert(state.turn_budget.can_spend("action") and source.studied_by.spiral.size() == 1, "S237 known combat answer is recalled without rolling or Action payment")
	other["removed"] = false
	state._update_grid_entities()
	await combat_study(h, state, actor, ["Renamed survey stone", "What does the spiral mean? (Arcana)"])
	h._assert(StudyRules.known(other, actor, "spiral") and other.studied_by.spiral.size() == 1 and str(state.hud.log_text.text).contains("water channel"), "S237 actual same-cell exact-source chooser resolves renamed data without borrowing another object's answer")
	other["removed"] = true
	await ReadyActionFlow.declare(h, state, actor, {"kind":"ordinary", "action":"study"}, {"event":"action", "side":"ally", "actor_id":helper.character_id})
	h._p_focus(state, helper)
	await OrdinaryWorldActionFlow.choices(h, state, func(): await state._on_hud_action("ordinary_action", {"action":"dash"}), [], Callable(), Vector2i(0,1))
	h._assert(actor.reaction_available and state.ready_actions.held.has(actor.character_id), "S237 cancelled readied Study question preserves held response and Reaction")
	h._p_focus(state, helper)
	await OrdinaryWorldActionFlow.choices(h, state, func(): await state._on_hud_action("ordinary_action", {"action":"dash"}), ["How is the seam arranged? (Investigation)"], Callable(), Vector2i(0,1))
	h._assert(StudyRules.known(source, actor, "seam") and not actor.reaction_available and not state.turn_budget.can_spend("action"), "S237 actual readied Study learns once using its owner's Reaction while preserving the triggering actor's spent Action")


static func combat_study(h: Node, state: CombatState, actor: Character, answers: Array, mutation: Callable = Callable()) -> void:
	h._p_focus(state, actor)
	await OrdinaryActionFlow.choose(h, state, "study")
	h._assert(state.pending_action_type == "ordinary_study" and state.turn_budget.can_spend("action"), "S237 actual Actions menu reaches unpaid Study source selection")
	await OrdinaryWorldActionFlow.choices(h, state, func(): await state._on_hex_clicked(Vector2i(0,1)), answers, mutation)
