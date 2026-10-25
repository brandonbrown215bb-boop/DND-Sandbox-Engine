class_name CreatedActorSchedulingChecks
extends RefCounted

const WARDENS := "fixture:orphan_wardens"
const WATCH := "fixture:linked_orphan_watch"

static func load_fixtures() -> void:
	Batch056Checks.load_fixtures()
	if DataLoader.get_spell(WARDENS).is_empty():
		DataLoader._load_json_file("res://data/fixtures/created_actor_scheduling/spells/pack.json", "spell")

static func place(battle, owner: Character, made: Array) -> void:
	for a in made:
		battle.player_entities.append({"name": a.character_name, "character": a, "combat_id": a.character_id, "hex_position": Vector2i(1, 0), "is_created_actor": true, "created_owner_id": owner.character_id})
		CreatedCommandRules.join_initiative(battle, owner, a)

static func run(check: Callable) -> void:
	load_fixtures()
	check.call(DataLoader.get_load_errors().is_empty(), "Created scheduling fixtures load without errors")
	for timing in [WARDENS, Batch056Checks.HOUNDS]:
		for phase in ["before", "during", "after"]:
			_removal(check, timing, phase)
	_unavailable_entry(check)
	_cleanup(check)
	_concentration_removal(check)
	_recovery(check)
	_history(check)

static func _removal(check: Callable, spell: String, phase: String) -> void:
	var owner := Batch031Checks._character("schedule_%s_%s" % [spell, phase], 30)
	var made := Batch056Checks.make(owner, spell, "persistent")
	var battle := Batch056Checks.battle(owner, [])
	battle.tracker.combatants[0].id = "player_7"
	battle.player_entities[0].combat_id = "player_7"
	place(battle, owner, made)
	var anchor: Dictionary = battle.tracker.combatants[0]
	var serial := CombatAction.active_turn_serial + 1
	CombatAction.active_turn_serial = serial
	var paid := CreatedCommandRules.issue(battle, owner, made[0].character_id, "dodge") if phase == "during" else {}
	for a in made: a.add_condition("restrained", 3)
	if phase == "after":
		CreatedCommandRules.apply_defaults(battle, owner)
		battle.tracker.next_turn()
	var prior_active := str(battle.tracker.get_active().id)
	owner.current_hp = 0
	owner.is_alive = false
	battle.tracker.remove_combatant("player_7")
	check.call(anchor.get("scheduling_only", false) and str(battle.tracker.get_active().id) == prior_active and bool(anchor.has_acted) == (phase == "after"), "Scheduling %s %s removal retains the exact slot and round history" % [spell, phase])
	if phase != "after":
		if spell == WARDENS:
			var acted := CreatedCommandRules.apply_defaults(battle, owner)
			check.call(acted.size() == (1 if phase == "during" else 2) and made.all(func(a): return int(a.conditions.restrained) == 2), "Scheduling %s removal ticks each owner-turn actor once and never repeats a paid order" % phase)
			if phase == "during": check.call(paid.success and CombatAction.active_turn_serial == serial and int(made[0].conditions.dodging) == 1, "Scheduling interrupted command retains its original serial and single Dodge")
		battle.tracker.next_turn()
	if spell == Batch056Checks.HOUNDS:
		var seen := []
		for _i in 2:
			var c: Dictionary = battle.tracker.get_active()
			seen.append(str(c.id))
			battle.active_character = c.entity
			battle.budget = {"action": 1, "bonus_action": 1}
			CreatedCommandRules.take_turn(battle, CreatedCommandRules._entity(battle, str(c.id)))
			c.entity.tick_conditions()
			battle.tracker.next_turn()
		check.call(seen == made.map(func(a): return a.character_id) and made.all(func(a): return int(a.conditions.restrained) == 2) and battle.budget.action == 0 and battle.budget.bonus_action == 1, "Scheduling %s removal keeps both after-owner turns and their own budgets" % phase)
	check.call(str(battle.tracker.get_active().id) == "b056_goblin", "Scheduling %s %s removal does not skip the next combatant" % [spell, phase])
	battle.tracker.next_turn()
	check.call(battle.tracker.current_round == 2 and battle.tracker.get_active() == anchor, "Scheduling %s %s removal supplies exactly one next-round anchor" % [spell, phase])
	# Re-entry never inserts another owner or replenishes any action budget.
	var budget: Dictionary = battle.budget.duplicate()
	battle.tracker.add_combatant("player_7", owner.character_name, true, owner, 99, 99)
	check.call(battle.tracker.combatants.filter(func(c): return c.entity is Character and c.entity == owner).size() == 1 and not anchor.get("scheduling_only", false) and anchor.roll == 15 and battle.budget == budget, "Scheduling explicit re-entry reuses the original identity, initiative and budgets")

static func _unavailable_entry(check: Callable) -> void:
	for dead in [false, true]:
		var owner := Batch031Checks._character("schedule_entry_%s" % dead, 30)
		var wardens := Batch056Checks.make(owner, WARDENS, "wardens")
		var hounds := Batch056Checks.make(owner, Batch056Checks.HOUNDS, "hounds")
		owner.current_hp = 0
		owner.is_alive = false
		owner.death_save_failures = 3 if dead else 0
		var battle := Batch056Checks.battle(owner, [])
		battle.tracker.remove_combatant(owner.character_id)
		place(battle, owner, wardens + hounds)
		var anchors: Array = battle.tracker.combatants.filter(func(c): return c.get("scheduling_only", false))
		check.call(anchors.size() == 1 and anchors[0].created_actor_dependents.size() == 4 and anchors[0].id == owner.character_id and Batch056Checks.order(battle) == ["Goblin", owner.character_name, "Hound 1", "Hound 2"], "Scheduling encounter entry with %s owner creates one shared end-of-round anchor" % ["dead" if dead else "downed"])
		battle.tracker.sort_initiative_preserving_active()
		check.call(Batch056Checks.order(battle) == ["Goblin", owner.character_name, "Hound 1", "Hound 2"] and hounds.all(func(a): return CreatedCommandRules.behaviour(owner, a) == ("none" if dead else "attack_nearest")), "Scheduling unavailable entry preserves declared policies and contiguous followers after sorting")

static func _cleanup(check: Callable) -> void:
	var owner := Batch031Checks._character("schedule_cleanup", 30)
	var persistent := Batch056Checks.make(owner, WARDENS, "persistent")
	var concentrating := Batch055Checks.pack(owner)
	owner.concentrating_on = {"effect_source": "spell:%s:b055" % owner.character_id}
	var battle := Batch056Checks.battle(owner, [])
	place(battle, owner, persistent + concentrating)
	battle.tracker.remove_combatant(owner.character_id)
	SpellEffects.end_concentration(owner, [owner])
	var gone := CreatedCommandRules.reconcile(battle)
	check.call(gone.size() == 2 and battle.tracker.combatants[0].created_actor_dependents.size() == 2 and CreatedActorRules.actors(owner) == persistent, "Scheduling concentration ending removes only its actors and preserves the shared clock")
	for a in persistent: a.is_alive = false
	CreatedCommandRules.reconcile(battle)
	battle.tracker.next_turn()
	check.call(battle.tracker.combatants.size() == 1 and str(battle.tracker.get_active().id) == "b056_goblin" and battle.tracker.current_round == 1, "Scheduling last living dependent removal releases the active anchor without replaying or skipping")

static func _recovery(check: Callable) -> void:
	var owner := Batch031Checks._character("schedule_recovery", 30)
	var made := Batch056Checks.make(owner, WARDENS, "persistent")
	var battle := Batch056Checks.battle(owner, made)
	owner.current_hp = 0
	owner.is_alive = false
	battle.tracker.remove_combatant(owner.character_id)
	battle.tracker.next_turn()
	owner.current_hp = 10
	owner.is_alive = true
	var active_id := str(battle.tracker.get_active().id)
	CreatedCommandRules.reconcile(battle)
	var anchor: Dictionary = battle.tracker.combatants[0]
	check.call(not anchor.get("scheduling_only", false) and anchor.has_acted and str(battle.tracker.get_active().id) == active_id and battle.tracker.current_round == 1, "Scheduling healing restores a consumed owner slot without granting an immediate turn")
	battle.tracker.next_turn()
	battle.active_character = owner
	CombatAction.active_turn_serial += 1
	var paid := CreatedCommandRules.issue(battle, owner, made[0].character_id, "dodge")
	check.call(paid.success and battle.spent == 1, "Scheduling recovered owner commands the same exact actor next round at the existing cost")
	var record: Dictionary = owner.spell_effects[made[0].get_meta("created_source_id")]
	record.created_actors.control_until = GameManager.campaign_elapsed_seconds
	CombatAction.active_turn_serial += 1
	var spent: int = battle.spent
	var expired := CreatedCommandRules.issue(battle, owner, made[1].character_id, "dodge")
	CreatedCommandRules.start_owner_turn(battle, owner)
	CreatedCommandRules.apply_defaults(battle, owner)
	check.call(not expired.success and battle.spent == spent and made.all(func(a): return a.has_condition("dodging")) and CreatedActorRules.actors(owner) == made, "Scheduling expired control refuses payment, applies declared Dodge, and preserves living actors")
	var dto: Dictionary = JSON.parse_string(JSON.stringify(owner.to_dict()))
	var back := Character.new()
	back.from_dict(dto)
	check.call(CreatedActorRules.saved_record_error(dto, dto.spell_effects.values()[0]).is_empty() and CreatedActorRules.actors(back).map(func(a): return a.character_id) == made.map(func(a): return a.character_id) and not JSON.stringify(dto).contains("scheduling_only"), "Scheduling checkpoints retain identities, HP and deadline with no live tracker fields")

static func _concentration_removal(check: Callable) -> void:
	for phase in ["anchor", "follower", "later"]:
		var owner := Batch031Checks._character("schedule_concentration_" + phase, 30)
		var made := Batch056Checks.make(owner, WATCH, "concentration")
		var battle := Batch056Checks.battle(owner, made)
		battle.tracker.remove_combatant(owner.character_id)
		battle.tracker.active_index = {"anchor": 0, "follower": 1, "later": 3}[phase]
		SpellEffects.end_concentration(owner, [owner])
		var gone := CreatedCommandRules.reconcile(battle)
		battle.tracker.next_turn()
		check.call(gone.size() == 2 and battle.tracker.combatants.size() == 1 and battle.tracker.get_active().id == "b056_goblin" and battle.tracker.current_round == (2 if phase == "later" else 1), "Scheduling concentration end with %s current releases the owner anchor and both followers without replay or skipped work" % phase)

static func _history(check: Callable) -> void:
	var owner := Batch031Checks._character("schedule_history", 30)
	var history := CombatActionHistory.new()
	history.begin_turn(owner, 1)
	history.record_action(owner)
	history.begin_scheduled_interval(2)
	check.call(history.current_round == 2 and not history.fact(owner, "target.first_own_turn").value and history.fact(owner, "target.acted_since_owner_turn").value and not history.fact(owner, "target.acted_since_combat_turn").value and history._turn_starts_by_actor[owner.character_id] == 1, "Scheduling interval resets combat facts without starting or replaying the owner's turn")
