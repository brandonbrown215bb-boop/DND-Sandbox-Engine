class_name CreatedActorSchedulingFlow
extends RefCounted

static func _combat_id(combat: Node, actor: Character) -> String:
	for i in combat.player_entities.size():
		var e: Dictionary = combat.player_entities[i]
		if e.character == actor: return str(e.get("combat_id", "player_%d" % i))
	return ""

static func _order(combat: Node, owner: Character, ally: Character) -> void:
	combat.tracker.clear()
	combat._spell_boundary_rounds.clear()
	combat.tracker.add_combatant(_combat_id(combat, owner), owner.character_name, true, owner, 30, 14)
	combat.tracker.add_combatant(_combat_id(combat, ally), ally.character_name, true, ally, 20, 14)
	var enemy: Dictionary = combat.monster_entities[0]
	combat.tracker.add_combatant(str(enemy.id), str(enemy.name), false, enemy, 10, 10)
	combat.tracker.sort_initiative()
	for e in combat.player_entities:
		if e.get("is_created_actor", false): CreatedCommandRules.join_initiative(combat, owner, e.character)

static func _until_ally(h: Node, combat: Node, ally: Character) -> Array:
	var seen := []
	for _f in 600:
		var actor: Variant = combat.active_combatant.get("entity")
		if actor is Character and actor != ally and actor.has_meta("created_source_id"):
			if seen.is_empty() or seen[-1] != actor.character_id: seen.append(actor.character_id)
		if combat.active_character == ally: return seen
		await h.get_tree().process_frame
	h._assert(false, "Created scheduling reaches the next ally without stalling")
	return seen

static func run(h: Node) -> void:
	h._enter_test("created_actor_scheduling_flow")
	h._setup_world()
	CreatedActorSchedulingChecks.load_fixtures()
	var ally: Character = PlayerManager.get_player(0).character
	var owner: Character = PlayerManager.get_player(1).character
	var spells := [CreatedActorSchedulingChecks.WARDENS, Batch056Checks.HOUNDS]
	SpellPermissionChecks.grant_slot_permission(owner, spells)
	owner.spell_slots = {"1": 4}
	for id in spells:
		var result := SpellResolver.resolve(owner, owner, DataLoader.get_spell(id), true, {}, [], 1)
		h._assert(result.get("success", false), "Created scheduling prepares persistent actors through the production spell resolver")
	var made := CreatedActorRules.actors(owner)
	var wardens := made.filter(func(a): return a.get_meta("created_spell_id") == CreatedActorSchedulingChecks.WARDENS)
	var hounds := made.filter(func(a): return a.get_meta("created_spell_id") == Batch056Checks.HOUNDS)
	wardens[0].current_hp = 17
	GameManager.current_state = GameManager.GameState.COMBAT
	var combat: Node = await h._spawn_scene("res://scenes/combat.tscn", 0.4)
	for _f in 600:
		if combat.active_combatant.get("is_player", false): break
		await h.get_tree().process_frame
	combat.monster_entities[0].attacks = []
	combat.monster_entities[0].current_hp = 1000
	combat.monster_entities[0].max_hp = 1000
	combat.monster_entities[0].hex_position = Vector2i(4, 4)
	h._assert(combat.player_entities.filter(func(e): return e.get("is_created_actor", false)).size() == 4, "Created scheduling encounter attaches all four existing actors")

	# Remove before the owner's first slot. The scheduling interval must not
	# start the owner, clear their locks, tick their conditions or replay work.
	_order(combat, owner, ally)
	owner.current_hp = 0
	owner.is_alive = false
	owner.add_condition("restrained", 3)
	owner.feature_uses["stunning_strike_used"] = true
	for a in made: a.add_condition("restrained", 3)
	var owner_starts: int = combat.action_history._turn_starts_by_actor.get(owner.character_id, 0)
	var owner_id := _combat_id(combat, owner)
	combat.tracker.remove_combatant(owner_id)
	combat._start_combat_turn()
	h._assert(combat.active_character == null and combat.current_player_idx == -1 and CombatAction.active_turn_actor_id == 0 and combat.action_history._turn_starts_by_actor.get(owner.character_id, 0) == owner_starts and int(owner.conditions.restrained) == 3 and owner.feature_uses.get("stunning_strike_used", false), "Created scheduling runs a neutral interval with no owner setup, condition tick or command authority")
	var seen := await _until_ally(h, combat, ally)
	h._assert(seen == hounds.map(func(a): return a.character_id) and made.all(func(a): return int(a.conditions.restrained) == 2) and combat._can_spend_action_cost("action") and combat._can_spend_action_cost("bonus_action"), "Created scheduling gives four actors one condition tick, both after-owner turns, and preserves the following ally's full budget")
	h._assert(not combat.hud.initiative_bar.get_parsed_text().contains(owner.character_name) and not SaveManager.get_save_block_reason().is_empty(), "Created scheduling hides the removed owner's initiative and keeps combat checkpoint refusal")

	# Healing after that slot was consumed restores its exact history. Re-entry
	# cannot replay the interrupted owner's Action or reset a spent budget.
	var slot: Dictionary = combat.tracker.combatants[0]
	owner.heal(10)
	CreatedCommandRules.reconcile(combat)
	h._assert(owner.is_alive and not slot.get("scheduling_only", false) and slot.has_acted and combat.active_character == ally, "Created scheduling healing restores the existing consumed owner slot without an extra turn")
	_order(combat, owner, ally)
	h._p_focus(combat, owner)
	combat.active_combatant = combat.tracker.get_active()
	combat.action_history.begin_turn(owner, combat.tracker.current_round)
	CombatAction.advance_combat_turn(owner, combat.tracker.current_round)
	CreatedCommandRules.start_owner_turn(combat, owner)
	combat._spend_action_cost("action")
	var paid := CreatedCommandRules.issue(combat, owner, wardens[0].character_id, "dodge")
	for a in made: a.add_condition("restrained", 3)
	owner.current_hp = 0
	owner.is_alive = false
	combat.tracker.remove_combatant(owner_id)
	var spent_serial := CombatAction.active_turn_serial
	combat._end_active_turn()
	seen = await _until_ally(h, combat, ally)
	h._assert(paid.success and int(wardens[0].conditions.dodging) == 1 and made.all(func(a): return int(a.conditions.restrained) == 2) and seen == hounds.map(func(a): return a.character_id) and CombatAction.active_turn_serial > spent_serial and combat._can_spend_action_cost("action"), "Created scheduling removal during a spent owner Action resolves its paid command and all sibling work once, then advances to the ally")
	h._teardown_scene(combat)
	await h.get_tree().process_frame
	combat = await h._spawn_scene("res://scenes/combat.tscn", 0.4)
	for _f in 600:
		if combat.active_character == ally: break
		await h.get_tree().process_frame
	var downed_anchors: Array = combat.tracker.combatants.filter(func(c): return c.get("scheduling_only", false))
	h._assert(not owner.is_alive and not owner.is_dead() and downed_anchors.size() == 1 and downed_anchors[0].created_actor_dependents.size() == 4, "Created scheduling actual encounter boot with already downed owner supplies the shared scheduling anchor")

	# Checkpoint uses the unchanged durable source format, then a fresh encounter
	# must reconstruct a dead-owner anchor without any saved initiative state.
	CorpseRules.mark_dead(owner, "scheduling_fixture")
	wardens[0].current_hp = 17
	CreatedActorRules.sync(owner)
	var expected_ids := made.map(func(a): return a.character_id)
	expected_ids.sort()
	var deadlines := {}
	for source in owner.spell_effects: deadlines[source] = int(owner.spell_effects[source].created_actors.control_until)
	h._teardown_scene(combat)
	await h.get_tree().process_frame
	GameManager.current_state = GameManager.GameState.OVERWORLD
	GameManager.game_in_progress = true
	var saved := SaveManager.get_save_block_reason().is_empty() and SaveManager.save_game("created_scheduling_checkpoint")
	var loaded := saved and SaveManager.load_game("created_scheduling_checkpoint")
	owner = PartyManager.characters.get(owner.character_id)
	ally = PlayerManager.get_player(0).character
	made = CreatedActorRules.actors(owner)
	var restored_ids := made.map(func(a): return a.character_id)
	restored_ids.sort()
	var restored_deadlines := {}
	for source in owner.spell_effects: restored_deadlines[source] = int(owner.spell_effects[source].created_actors.control_until)
	h._assert(loaded and restored_ids == expected_ids and made[0].current_hp == 17 and restored_deadlines == deadlines, "Created scheduling allowed checkpoint reload retains exact actor identities, HP and control deadlines (loaded=%s, HP=%s, IDs=%s, deadlines=%s)" % [loaded, made[0].current_hp, restored_ids == expected_ids, restored_deadlines == deadlines])
	GameManager.current_state = GameManager.GameState.COMBAT
	GameManager.transition_context = {"terrain": "plains", "monster_ids": ["goblin"]}
	combat = await h._spawn_scene("res://scenes/combat.tscn", 0.4)
	for _f in 600:
		if combat.active_character == ally: break
		await h.get_tree().process_frame
	var anchors: Array = combat.tracker.combatants.filter(func(c): return c.get("scheduling_only", false))
	h._assert(anchors.size() == 1 and anchors[0].created_actor_dependents.size() == 4 and combat.player_entities.filter(func(e): return e.get("is_created_actor", false)).size() == 4, "Created scheduling actual encounter boot with dead owner reconstructs one shared anchor and all four actors")
	# Put the end-of-round clock first to observe it through the real turn loop.
	combat.tracker.active_index = combat.tracker.combatants.find(anchors[0])
	combat.monster_entities[0].attacks = []
	combat.monster_entities[0].hex_position = Vector2i(4, 4)
	for a in made:
		a.remove_condition("dodging")
		a.add_condition("restrained", 3)
	combat._start_combat_turn()
	seen = await _until_ally(h, combat, ally)
	hounds = made.filter(func(a): return a.get_meta("created_spell_id") == Batch056Checks.HOUNDS)
	h._assert(seen == hounds.map(func(a): return a.character_id) and made.all(func(a): return not a.has_condition("dodging") and int(a.conditions.restrained) == 2), "Created scheduling dead-owner entry gives each actor its declared none behavior and one condition tick")

	# A recovered owner's expired control still cannot buy commands, but the
	# source and all living actors survive and receive the declared fallback.
	var revived := CorpseRules.revive(owner, int(GameManager.campaign_elapsed_seconds))
	owner.heal(10)
	CreatedCommandRules.reconcile(combat)
	h._assert(revived.get("success", false) and owner.is_alive and not owner.is_dead(), "Created scheduling production revival restores the same owner after dead-owner entry")
	for r in owner.spell_effects.values(): r.created_actors.control_until = GameManager.campaign_elapsed_seconds
	_order(combat, owner, ally)
	h._p_focus(combat, owner)
	combat.active_combatant = combat.tracker.get_active()
	CombatAction.advance_combat_turn(owner, combat.tracker.current_round)
	var price_before: bool = combat._can_spend_action_cost("bonus_action")
	var refused := CreatedCommandRules.issue(combat, owner, made[0].character_id, "dodge")
	combat.tracker.remove_combatant(_combat_id(combat, owner))
	combat._start_combat_turn()
	seen = await _until_ally(h, combat, ally)
	h._assert(not refused.success and price_before and made.all(func(a): return a.has_condition("dodging")) and CreatedActorRules.actors(owner).size() == 4, "Created scheduling expired control applies declared Dodge through both timings and preserves every source actor")

	# End another source during an after-owner creature's actual turn. The
	# persistent siblings keep their clock and the next ally still gets its work.
	combat.tracker.add_combatant(_combat_id(combat, owner), owner.character_name, true, owner, 30, 14)
	SpellPermissionChecks.grant_slot_permission(owner, [CreatedActorSchedulingChecks.WATCH])
	owner.spell_slots = {"1": 1}
	var watched := SpellResolver.resolve(owner, owner, DataLoader.get_spell(CreatedActorSchedulingChecks.WATCH), true, {}, [], 1)
	owner.concentrating_on = {"spell_id": CreatedActorSchedulingChecks.WATCH, "effect_source": watched.get("effect_cast", {}).get("source_id", ""), "targets": []}
	CreatedActorRules.attach(combat, owner, CreatedCommandRules._owner_hex(combat, owner))
	var watch := CreatedActorRules.actors(owner).filter(func(a): return a.get_meta("created_spell_id") == CreatedActorSchedulingChecks.WATCH)
	h._assert(watched.get("success", false) and watch.size() == 2, "Created scheduling prepares a second concentration source (%s)" % watched.get("message", ""))
	if watch.size() != 2:
		h._teardown_scene(combat)
		h._exit_test()
		return
	_order(combat, owner, ally)
	combat.tracker.remove_combatant(_combat_id(combat, owner))
	for i in combat.tracker.combatants.size():
		if str(combat.tracker.combatants[i].id) == watch[0].character_id: combat.tracker.active_index = i
	h._p_focus(combat, watch[0])
	combat.active_combatant = combat.tracker.get_active()
	SpellEffects.end_concentration(owner, combat._spell_effect_targets())
	combat._end_active_turn()
	await _until_ally(h, combat, ally)
	h._assert(watched.get("success", false) and CreatedActorRules.actors(owner).size() == 4 and not combat.tracker.combatants.any(func(c): return str(c.id) in watch.map(func(a): return a.character_id)) and combat.tracker.combatants[0].get("scheduling_only", false) and combat._can_spend_action_cost("action"), "Created scheduling concentration ending during a follower turn removes that source once, preserves persistent siblings and reaches the ally with its Action")

	# Timed sources must not become immortal just because their clock stopped
	# being a full owner turn. Exercise both supported owner expiry boundaries.
	for phase in ["start", "end"]:
		combat.tracker.add_combatant(_combat_id(combat, owner), owner.character_name, true, owner, 30, 14)
		owner.spell_slots = {"1": 1}
		var timed := SpellResolver.resolve(owner, owner, DataLoader.get_spell(CreatedActorSchedulingChecks.WARDENS), true, {}, [], 1)
		var timed_source := str(timed.get("effect_cast", {}).get("source_id", ""))
		owner.spell_effects[timed_source].remaining_seconds = 6
		owner.spell_effects[timed_source].expiry_phase = phase
		CreatedActorRules.attach(combat, owner, CreatedCommandRules._owner_hex(combat, owner))
		var fleeting := CreatedActorRules.actors(owner).filter(func(a): return a.get_meta("created_source_id") == timed_source)
		_order(combat, owner, ally)
		combat.tracker.remove_combatant(_combat_id(combat, owner))
		combat._start_combat_turn()
		await _until_ally(h, combat, ally)
		h._assert(timed.get("success", false) and not owner.spell_effects.has(timed_source) and CreatedActorRules.actors(owner).size() == 4 and not combat.player_entities.any(func(e): return e.character in fleeting) and combat._can_spend_action_cost("action"), "Created scheduling ages %s-phase timed sources and removes only their actors before advancing once" % phase)

	# Persistent creatures must never hold defeat open.
	owner.current_hp = 0
	owner.is_alive = false
	owner.death_save_failures = 3
	ally.current_hp = 0
	ally.is_alive = false
	ally.death_save_failures = 3
	h._assert(combat._check_battle_end_conditions() and combat._battle_ending and CreatedActorRules.actors(owner).size() == 4, "Created scheduling persistent summons do not prevent party defeat settlement")
	h._teardown_scene(combat)
	h._exit_test()
