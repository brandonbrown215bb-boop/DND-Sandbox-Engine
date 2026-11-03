class_name InsightSearchFlow
extends RefCounted


static func select_popup(h: Node, combat: CombatState, item_index: int) -> void:
	for _frame in 120:
		await h.get_tree().process_frame
		for child in combat.hud.get_children():
			if child is PopupMenu and child.visible:
				if item_index < child.item_count:
					child.id_pressed.emit(child.get_item_id(item_index))
				child.hide()
				return
	h._assert(false, "OA-06 expected an actual Search chooser PopupMenu")


static func choose_insight_search(h: Node, combat: CombatState, actor: Character) -> void:
	h._p_focus(combat, actor)
	await OrdinaryActionFlow.choose(h, combat, "search")
	await select_popup(h, combat, 0)
	for _frame in 3: await h.get_tree().process_frame


static func click_search_target(h: Node, combat: CombatState, position: Vector2i, choose_exact: bool = false) -> void:
	combat.call_deferred("_on_hex_clicked", position)
	if choose_exact: await select_popup(h, combat, 0)
	for _frame in 3: await h.get_tree().process_frame


static func cancel_exact_choice(h: Node, combat: CombatState, position: Vector2i) -> void:
	combat.call_deferred("_on_hex_clicked", position)
	for _frame in 120:
		await h.get_tree().process_frame
		for child in combat.hud.get_children():
			if child is PopupMenu and child.visible and str(child.title).begins_with("Search: choose the exact creature"):
				child.hide()
				for _wait in 3: await h.get_tree().process_frame
				return
	h._assert(false, "OA-06 co-located exact-target chooser is actually presented")


static func run(h: Node) -> void:
	h._enter_test("insight_search_flow")
	h._setup_mixed_world()
	DataLoader._load_json_file("res://data/fixtures/ordinary_actions/influence_monsters.json", "monster")
	var party: Array = PartyManager.characters.values()
	var room := InfluenceFlow.make_room(party)
	GameManager.current_state = GameManager.GameState.COMBAT
	GameManager.transition_context = {"terrain":"plains", "monster_ids":room.encounter_monsters, "local_room":room}
	var combat: CombatState = await h._spawn_scene("res://scenes/combat.tscn", 0.4)
	var actor: Character = combat.player_entities[0].character
	var helper: Character = combat.player_entities[1].character
	var monster: Dictionary = combat.monster_entities[0]
	var second: Dictionary = combat.monster_entities[2]
	actor.ability_scores.wisdom = 40
	actor.skill_proficiencies.append("Insight")
	combat.player_entities[0].hex_position = Vector2i(-1, 0)
	combat.player_entities[1].hex_position = Vector2i(-2, 0)
	monster.hex_position = Vector2i.ZERO
	second.hex_position = Vector2i.ZERO
	combat._update_grid_entities()
	h._p_focus(combat, actor)
	combat._reset_turn_action_economy()
	await choose_insight_search(h, combat, actor)
	h._assert(combat.pending_action_type == "ordinary_insight_search" and combat.turn_budget.can_spend("action"), "OA-06 Actions/Search reaches exact live creature targeting without paying")
	await click_search_target(h, combat, Vector2i.ZERO, true)
	h._assert(not combat.turn_budget.can_spend("action") and InsightSearchRules.known(room, monster, actor), "OA-06 successful Insight Search reveals the authored clue to this observer and pays once")
	h._assert(not InsightSearchRules.known(room, second, actor), "OA-06 exact live encounter identity prevents another co-located creature's clue from leaking")
	var checkpoint_room: Dictionary = JSON.parse_string(JSON.stringify(room))
	h._assert(DungeonPersistence.local_error(checkpoint_room).is_empty() and InsightSearchRules.known(checkpoint_room, monster, actor), "OA-06 room receipt survives existing plain-state checkpoint serialization without adding a combat save")
	h._assert(InsightSearchRules.known(room, monster, helper) == false and room.get("insight_search_discoveries", []).size() == 1, "OA-06 observer-specific knowledge is not granted to the rest of the party")
	var shell: VttShell = combat.hud.get_node("Root")
	shell._show_inspector(actor)
	var actor_info: Label = shell.inspector.find_child("CharacterInfo", true, false) as Label
	h._assert(actor_info.text.contains("anxious to protect someone behind it") and not combat.hud.log_text.text.contains("anxious to protect someone behind it"), "OA-06 authored clue is available only in the searcher's observer-specific field notes, not the shared Chronicle")
	shell._show_inspector(helper)
	var helper_info: Label = shell.inspector.find_child("CharacterInfo", true, false) as Label
	h._assert(not helper_info.text.contains("anxious to protect someone behind it"), "OA-06 another character's inspector cannot reveal the searcher's clue")
	h._p_focus(combat, helper)
	combat._reset_turn_action_economy()
	await choose_insight_search(h, combat, helper)
	await cancel_exact_choice(h, combat, Vector2i.ZERO)
	h._assert(combat.turn_budget.can_spend("action") and not InsightSearchRules.known(room, monster, helper), "OA-06 cancelling the exact-creature popup spends no Action and records no clue")
	# Matching Help must reach the same real Insight check owner.
	actor.combat_check_help.clear()
	helper.skill_proficiencies.append("Insight")
	h._p_focus(combat, helper)
	combat._reset_turn_action_economy()
	combat.hud.ordinary_actions_button.pressed.emit()
	var help_menu: PopupMenu = combat.hud.get_node("OrdinaryActionsMenu")
	help_menu.id_pressed.emit(OrdinaryActionRules.ACTIONS.find("help_check")); help_menu.hide()
	var picked_help := false
	for _frame in 120:
		await h.get_tree().process_frame
		for child in combat.hud.get_children():
			if not child is PopupMenu or not child.visible or not str(child.title).begins_with("Help:"): continue
			for index in child.item_count:
				if child.get_item_text(index) == "Insight (skill)":
					child.id_pressed.emit(child.get_item_id(index)); child.hide(); picked_help = true; break
		if picked_help: break
	await h.get_tree().process_frame
	await combat._on_hex_clicked(combat.player_entities[0].hex_position)
	h._assert(picked_help and not combat.turn_budget.can_spend("action") and actor.combat_check_help.size() == 1, "OA-06 matching Help: Insight is granted through actual Actions and owned-proficiency controls")
	# Distinct observer and creature; deterministic success consumes that exact matching help.
	combat.player_entities[0].hex_position = Vector2i(-1, 0)
	monster.hex_position = Vector2i(0, 0)
	second.hex_position = Vector2i(1, 0)
	combat._update_grid_entities()
	h._p_focus(combat, actor)
	combat._reset_turn_action_economy()
	await choose_insight_search(h, combat, actor)
	await click_search_target(h, combat, second.hex_position)
	h._assert(not combat.turn_budget.can_spend("action") and actor.combat_check_help.is_empty(), "OA-06 the actual Wisdom (Insight) Search consumes matching Help and settles one Action")
	# Failed checks pay once but disclose and remember no clue.
	var failed_actor: Character = combat.player_entities[2].character
	combat.hud.clear_logs()
	failed_actor.ability_scores.wisdom = 1
	failed_actor.skill_proficiencies.clear()
	FighterChecks._seed_die(20, 1)
	combat.player_entities[2].hex_position = Vector2i(-1, 0)
	monster.hex_position = Vector2i.ZERO
	combat._update_grid_entities()
	h._p_focus(combat, failed_actor)
	combat._reset_turn_action_economy()
	await choose_insight_search(h, combat, failed_actor)
	await click_search_target(h, combat, monster.hex_position)
	h._assert(not combat.turn_budget.can_spend("action") and not InsightSearchRules.known(room, monster, failed_actor), "OA-06 failed Insight Search pays exactly one Action without a knowledge receipt")
	h._assert(not combat.hud.log_text.text.contains("anxious to protect someone behind it"), "OA-06 a failed check reveals no authored information")
	# Cancel, stale exact selection and inaccessible source all refuse before payment.
	var cancel_actor: Character = combat.player_entities[3].character
	h._p_focus(combat, cancel_actor)
	combat._reset_turn_action_economy()
	await choose_insight_search(h, combat, cancel_actor)
	combat._cancel_pending_action()
	h._assert(combat.turn_budget.can_spend("action") and combat.pending_action_type.is_empty(), "OA-06 cancelling target selection is free and clears its transient target")
	h._p_focus(combat, cancel_actor)
	await choose_insight_search(h, combat, cancel_actor)
	var original_position: Vector2i = monster.hex_position
	monster.hex_position = Vector2i(5, 0)
	await click_search_target(h, combat, original_position)
	h._assert(combat.turn_budget.can_spend("action") and not InsightSearchRules.known(room, monster, cancel_actor), "OA-06 moved/stale exact creature cannot settle or disclose")
	monster.hex_position = original_position
	var far: Vector2i = combat.player_entities[3].hex_position + Vector2i(8, 0)
	var access_error := InsightSearchRules.target_error(combat, cancel_actor, room, monster, far)
	h._assert(not access_error.is_empty() and combat.turn_budget.can_spend("action"), "OA-06 source/access guard refuses an unrepresented or out-of-reach creature before payment")
	var payment_refusal: Dictionary = await InsightSearchRules.request(combat, cancel_actor, [monster], original_position, func() -> bool: return true, func() -> bool: return false)
	h._assert(payment_refusal.get("status") == "refused" and not InsightSearchRules.known(room, monster, cancel_actor), "OA-06 a failed final Action settlement cannot leave a success receipt or disclose a clue")
	var clue_copy: Dictionary = monster.insight_search.duplicate(true)
	monster.erase("insight_search")
	var no_clue_error := InsightSearchRules.target_error(combat, cancel_actor, room, monster, original_position)
	monster["insight_search"] = clue_copy
	h._assert(not no_clue_error.is_empty(), "OA-06 a live encounter monster without an authored clue is not a Search source")
	var impostor: Dictionary = monster.duplicate(true)
	h._assert(not InsightSearchRules.target_error(combat, cancel_actor, room, impostor, original_position).is_empty(), "OA-06 a copied/non-live dictionary cannot impersonate the exact encounter creature")
	monster["is_alive"] = false
	var dead_error := InsightSearchRules.target_error(combat, cancel_actor, room, monster, original_position)
	monster["is_alive"] = true
	h._assert(not dead_error.is_empty(), "OA-06 a defeated creature is not an Insight Search source")
	monster["plane"] = "ethereal"
	var plane_error := InsightSearchRules.target_error(combat, cancel_actor, room, monster, original_position)
	monster.erase("plane")
	h._assert(not plane_error.is_empty(), "OA-06 Insight Search cannot cross planes")
	var ledger := {"encounter_monsters":["fixture:gesture_sentry"], "party_positions":{actor.character_id:[0,0]}, "insight_search_discoveries":[{"encounter_index":0, "monster_id":"fixture:gesture_sentry", "observer_id":actor.character_id}]}
	h._assert(InsightSearchRules.ledger_error(ledger).is_empty(), "OA-06 observer receipt is valid at the room's allowed checkpoint boundary")
	ledger.insight_search_discoveries.append(ledger.insight_search_discoveries[0].duplicate(true))
	h._assert(not InsightSearchRules.ledger_error(ledger).is_empty(), "OA-06 duplicate observer receipt refuses malformed checkpoint state")
	ledger.insight_search_discoveries = [ledger.insight_search_discoveries[0].duplicate(true)]
	ledger.insight_search_discoveries[0].observer_id = "unknown_observer"
	h._assert(not InsightSearchRules.ledger_error(ledger).is_empty(), "OA-06 unknown observer identity refuses malformed checkpoint state")
	var malformed_ledger: Dictionary = ledger.duplicate(true)
	malformed_ledger["encounter_monsters"] = "not-an-array"
	h._assert(not InsightSearchRules.ledger_error(malformed_ledger).is_empty(), "OA-06 malformed encounter source collection refuses validation without invalid indexing")
	h._teardown_scene(combat)
	h._exit_test()
