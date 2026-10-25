class_name SharedInitiativeFlow
extends RefCounted

static func _members(owner: Character, source: String) -> Array:
	return CreatedActorRules.actors(owner).filter(func(a): return a.get_meta("created_source_id") == source)

static func _cast(owner: Character, spell_id: String) -> Dictionary:
	return SpellResolver.resolve(owner, owner, DataLoader.get_spell(spell_id), true, {}, [], 1)

static func _withdraw(combat: Node, member: Character) -> void:
	combat.tracker.remove_combatant(member.character_id)
	combat.player_entities = combat.player_entities.filter(func(e): return e.get("character") != member)

static func _observe_until_ally(h: Node, combat: Node, ally: Character) -> Array:
	var seen := []
	var previous: Character = null
	var previous_duration := 0
	var started := Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < 8000:
		var actor: Variant = combat.active_combatant.get("entity")
		if actor is Character and actor.has_meta("created_source_id") and not seen.has(actor.character_id):
			if previous != null:
				h._assert(int(previous.conditions.get("restrained", 0)) == maxi(0, previous_duration - 1), "Shared-count previous member reaches its own condition end boundary before the next member starts")
			seen.append(actor.character_id)
			h._assert(not combat._can_spend_action_cost("action") and combat._can_spend_action_cost("bonus_action") and actor.reaction_available, "Shared count member spends its own Action and retains its own Bonus Action/reaction: " + actor.character_id)
			previous = actor
			previous_duration = int(actor.conditions.get("restrained", 0))
		if actor is Character and actor == ally and combat.active_character == ally: return seen
		await h.get_tree().process_frame
	h._assert(false, "Shared count reaches the following ally without stalling")
	return seen

static func run(h: Node) -> void:
	h._enter_test("shared_initiative_flow")
	h._setup_world()
	SharedInitiativeChecks.load_fixtures()
	var ally: Character = PlayerManager.get_player(0).character
	var owner: Character = PlayerManager.get_player(1).character
	SpellPermissionChecks.grant_slot_permission(owner, [SharedInitiativeChecks.OWNER, SharedInitiativeChecks.ROLLED])
	owner.spell_slots = {"1": 8}
	var first := _cast(owner, SharedInitiativeChecks.OWNER)
	var second := _cast(owner, SharedInitiativeChecks.OWNER)
	var rolled := _cast(owner, SharedInitiativeChecks.ROLLED)
	var a := _members(owner, str(first.get("effect_cast", {}).get("source_id", "")))
	var b := _members(owner, str(second.get("effect_cast", {}).get("source_id", "")))
	var r := _members(owner, str(rolled.get("effect_cast", {}).get("source_id", "")))
	h._assert(first.get("success", false) and second.get("success", false) and rolled.get("success", false) and a.size() == 3 and b.size() == 3 and r.size() == 3 and owner.spell_slots["1"] == 5, "Renamed shared-count sources create nine distinct members through the production resolver and spend three slots")
	if a.size() != 3 or b.size() != 3 or r.size() != 3:
		h._exit_test()
		return
	# This source member has never entered initiative. It arrives alive only
	# after the other members' first count has finished.
	a[2].current_hp = 0
	a[2].is_alive = false
	GameManager.current_state = GameManager.GameState.COMBAT
	var combat: Node = await h._spawn_scene("res://scenes/combat.tscn", 0.4)
	for _frame in 600:
		if combat.active_combatant.get("is_player", false): break
		await h.get_tree().process_frame
	var enemy: Dictionary = combat.monster_entities[0]
	enemy.merge({"attacks": [], "current_hp": 1000, "max_hp": 1000, "armor_class": -100, "ac": -100, "hex_position": Vector2i(4, 4)}, true)
	# Establish reproducible encounter initiative through the normal tracker.
	# Record the actual group roll before pinning it between owner and ally.
	CreatedActorSchedulingFlow._order(combat, owner, ally)
	var rolled_source := str(r[0].get_meta("created_source_id"))
	var rolled_count: int = combat.tracker.shared_groups[rolled_source].roll
	combat.tracker.shared_groups[rolled_source].roll = 25
	for entry in combat.tracker.combatants:
		if entry.get("shared_group", "") == rolled_source: entry.roll = 25
	combat.tracker.sort_initiative_preserving_active()
	h._assert(rolled_count >= 2 and rolled_count <= 21 and combat.tracker.shared_groups.size() == 3 and combat.tracker.combatants.filter(func(c): return c.has("shared_group") and c.roll == 30).size() == 5, "Actual encounter has two separate source groups on the owner's count and one group with one rolled count")
	# Keep one member off the field until after its count has acted.
	for member in a + b + r: member.add_condition("restrained", 3)
	b[1].current_hp = 0
	b[1].is_alive = false
	CreatedCommandRules.reconcile(combat)
	combat._start_combat_turn()
	combat._on_hud_action("dodge", {})
	var paid := CreatedCommandRules.issue(combat, owner, a[0].character_id, "attack", str(enemy.id))
	var serial := CombatAction.active_turn_serial
	var starts: int = combat.action_history._turn_starts_by_actor.get(owner.character_id, 0)
	var action_event: int = combat.action_history._last_action_events.get(owner.character_id, -1)
	var seat: int = combat._get_current_owner_index()
	combat._on_device_binding_changed(seat, -1, false)
	# Sorting/rejoining during the interruption must not touch the paid order,
	# action history or owner budget. Resume uses the existing controller path.
	for member in b: combat.tracker.remove_combatant(member.character_id)
	for member in [b[2], b[0], a[1], a[0]]:
		CreatedCommandRules.join_initiative(combat, owner, member)
	combat.tracker.sort_initiative_preserving_active()
	combat._on_device_binding_changed(seat, -1, true)
	h._assert(paid.success and seat >= 0 and not combat._waiting_for_owner_rebind and CombatAction.active_turn_serial == serial and combat.action_history._turn_starts_by_actor.get(owner.character_id, 0) == starts and combat.action_history._last_action_events.get(owner.character_id, -2) == action_event and owner.has_condition("dodging") and not combat._can_spend_action_cost("action") and not combat._can_spend_action_cost("bonus_action"), "Owner disconnect/reconnect and regroup resume the settled Dodge and paid exact-member order without replay, another turn or budget refill")
	var attacks := {"count": 0}
	var capture := func(result):
		if int(result.get("sides", 0)) == 20: attacks.count += 1
	Dice.dice_rolled.connect(capture)
	combat._end_active_turn()
	# The first member has acted and is awaiting its actual end-turn boundary.
	# Rebuild its source while it is active; siblings retain pending turns.
	var active_member: Character = combat.active_character
	for member in a.slice(0, 2): combat.tracker.remove_combatant(member.character_id)
	for member in [a[1], a[0]]: CreatedCommandRules.join_initiative(combat, owner, member)
	h._assert(active_member == a[0] and not combat._can_spend_action_cost("action") and combat._can_spend_action_cost("bonus_action"), "Rebuilding the active shared group preserves the member's spent budget")
	var seen := await _observe_until_ally(h, combat, ally)
	var expected: Array = [a[0], a[1], b[0], b[2]] + r
	h._assert(seen == expected.map(func(member): return member.character_id) and expected.all(func(member): return int(member.conditions.restrained) == 2) and int(a[2].conditions.restrained) == 3 and int(b[1].conditions.restrained) == 3 and attacks.count == 1 and not a[0].has_condition("dodging") and not CreatedCommandRules._orders.has(a[0].character_id), "Actual shared counts run every eligible member once in deterministic source order, settle the paid attack once and tick only that member's conditions; dead/absent members get no turn")
	var settled_hp: int = enemy.current_hp
	h._assert(combat._can_spend_action_cost("action") and combat._can_spend_action_cost("bonus_action"), "Shared groups leave the following ally with both budgets")
	# Bring the previously absent member onto an already-consumed count, and
	# rebuild an entirely empty, already-settled group at the same time.
	var history: Dictionary = combat.action_history._turn_starts_by_actor.duplicate()
	var original_count: int = combat.tracker.shared_groups[rolled_source].roll
	for member in r: _withdraw(combat, member)
	a[2].current_hp = a[2].max_hp
	a[2].is_alive = true
	CreatedActorRules.attach(combat, owner, CreatedCommandRules._owner_hex(combat, owner))
	var newcomer := _cast(owner, SharedInitiativeChecks.OWNER)
	var newcomers := _members(owner, str(newcomer.get("effect_cast", {}).get("source_id", "")))
	CreatedActorRules.attach(combat, owner, CreatedCommandRules._owner_hex(combat, owner))
	var late_entries: Array = combat.tracker.combatants.filter(func(c): return str(c.id) == a[2].character_id or c.entity in newcomers)
	h._assert(late_entries.size() == 4 and late_entries.all(func(c): return c.eligible_round == 2) and combat.tracker.shared_groups[rolled_source].roll == original_count and combat.active_character == ally and combat.action_history._turn_starts_by_actor == history and combat._can_spend_action_cost("action"), "Actual late sibling/new source wait for round two; empty-group rebuild retains its count and cannot replay settled turns or touch the ally (late=%s cast=%s)" % [str(late_entries.map(func(c): return [c.id, c.eligible_round])), str(newcomer.get("success", false))])
	# Remove the owner now: the previous repair must keep the exact consumed
	# anchor, then use a neutral interval next round without starting the owner.
	var owner_id := CreatedActorSchedulingFlow._combat_id(combat, owner)
	owner.current_hp = 0
	owner.is_alive = false
	owner.death_save_failures = 3
	combat.tracker.remove_combatant(owner_id)
	owner.add_condition("restrained", 3)
	var owner_starts: int = combat.action_history._turn_starts_by_actor.get(owner.character_id, 0)
	# 'none' is the declared dead-owner fallback; each living member still
	# spends its own Action and reaches its own end-of-turn condition boundary.
	combat._end_active_turn()
	seen = await _observe_until_ally(h, combat, ally)
	var next_expected: Array = [a[0], a[1], a[2], b[0], b[2]] + newcomers + r
	Dice.dice_rolled.disconnect(capture)
	h._assert(combat.tracker.current_round == 2 and seen == next_expected.map(func(member): return member.character_id) and combat.action_history._turn_starts_by_actor.get(owner.character_id, 0) == owner_starts and int(owner.conditions.restrained) == 3 and int(a[2].conditions.restrained) == 2 and r.all(func(member): return int(member.conditions.restrained) == 1) and attacks.count == 1 and int(enemy.current_hp) == settled_hp, "Round two admits late members once, keeps rebuilt members to one new turn, never replays the settled attack, and preserves owner-removal scheduling with no owner turn or owner condition tick")
	# End only one source while the ally is active; its peers and their consumed
	# history survive, and no action or owner slot is replayed.
	var ended_source := str(a[0].get_meta("created_source_id"))
	owner.spell_effects.erase(ended_source)
	CreatedCommandRules.reconcile(combat)
	h._assert(not combat.tracker.combatants.any(func(c): return c.get("shared_group", "") == ended_source) and combat.tracker.combatants.any(func(c): return c.entity == b[0]) and combat.active_character == ally and combat._can_spend_action_cost("action"), "Ending one shared source removes only that group and preserves the active ally and sibling source")
	h._teardown_scene(combat)
	h._exit_test()
