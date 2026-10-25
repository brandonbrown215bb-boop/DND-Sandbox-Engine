class_name SharedInitiativeChecks
extends RefCounted

const OWNER := "fixture:renamed_owner_chorus"
const ROLLED := "fixture:renamed_roll_chorus"

static func load_fixtures() -> void:
	if DataLoader.get_spell(OWNER).is_empty():
		DataLoader._load_json_file("res://data/fixtures/shared_initiative/spells/renamed_choruses.json", "spell")

static func make(owner: Character, spell_id: String, tag: String) -> Array:
	var spell := DataLoader.get_spell(spell_id)
	var source := "spell:%s:%s" % [owner.character_id, tag]
	CreatedActorRules.create(owner, {"source_id": source, "caster_id": owner.character_id, "spell_id": spell_id, "concentration": false, "conditions": []}, spell.effects[0].template, 1, spell)
	return CreatedActorRules.actors(owner).filter(func(a): return a.get_meta("created_source_id") == source)

static func ids(tracker: InitiativeTracker) -> Array:
	return tracker.combatants.map(func(c): return str(c.id))

static func run(check: Callable) -> void:
	load_fixtures()
	check.call(DataLoader.get_load_errors().is_empty() and not DataLoader.get_spell(ROLLED).is_empty(), "Shared-count renamed JSON fixtures load through the production loader")
	var bad := [{"initiative": "shared_count"}, {"initiative": "shared_count", "initiative_group": "all"}, {"initiative": "own", "initiative_group": "roll"}, {"initiative_group": "owner"}, {"initiative": "shared_count", "initiative_group": {"count": "owner"}}]
	check.call(bad.all(func(p): return not CreatedCommandRules.policy_error(p).is_empty()), "Shared-count missing, unknown, mistyped and misplaced grouping policies refuse")
	var owner := Batch031Checks._character("shared_counts", 30)
	var a := make(owner, OWNER, "a")
	var b := make(owner, OWNER, "b")
	var battle := Batch056Checks.battle(owner, [])
	CreatedActorSchedulingChecks.place(battle, owner, [b[1], a[1], b[0], a[0]])
	var expected := [owner.character_id, a[0].character_id, a[1].character_id, b[0].character_id, b[1].character_id, "b056_goblin"]
	check.call(ids(battle.tracker) == expected and battle.tracker.shared_groups.size() == 2 and battle.tracker.combatants.slice(0, 5).all(func(c): return int(c.roll) == 15), "Shared-count two distinct source groups share the owner's count and sort by source/member identity")
	battle.tracker.mark_turn_started()
	battle.tracker.next_turn()
	battle.tracker.mark_turn_started()
	battle.active_character = a[0]
	battle.budget = {"action": 1, "bonus_action": 1}
	CreatedCommandRules.take_turn(battle, CreatedCommandRules._entity(battle, a[0].character_id))
	var before := battle.budget.duplicate()
	# Rebuild the complete active group: the started member is consumed, while
	# its already-enrolled sibling must keep its pending turn this round.
	for member in a.slice(0, 2): battle.tracker.remove_combatant(member.character_id)
	for member in [a[1], a[0]]: CreatedCommandRules.join_initiative(battle, owner, member)
	battle.tracker.next_turn()
	check.call(battle.tracker.get_active().id == a[1].character_id and battle.budget == before and before.action == 0 and before.bonus_action == 1, "Shared-count active group rebuild cannot replay its spent member or skip its pending sibling or refill a budget")
	# A previously absent sibling and a new source at this count both wait.
	CreatedActorSchedulingChecks.place(battle, owner, [a[2]])
	var c := make(owner, OWNER, "c")
	CreatedActorSchedulingChecks.place(battle, owner, c)
	var seen := []
	for _i in 8:
		var current: Dictionary = battle.tracker.get_active()
		seen.append(str(current.id))
		battle.tracker.mark_turn_started()
		if battle.tracker.next_turn(): break
	check.call(seen == [a[1].character_id, b[0].character_id, b[1].character_id, "b056_goblin"], "Shared-count late sibling and newly added same-count group receive no retroactive turns")
	battle.tracker.next_turn()
	check.call(battle.tracker.current_round == 2 and battle.tracker.get_active().id == a[0].character_id, "Shared-count deferred members join the normal deterministic order next round")
	a[1].is_alive = false
	a[1].current_hp = 0
	CreatedCommandRules.reconcile(battle)
	check.call(not ids(battle.tracker).has(a[1].character_id) and ids(battle.tracker).has(a[2].character_id) and ids(battle.tracker).has(b[0].character_id), "Shared-count dead member leaves initiative without removing its siblings or another source group")
	_rolled(check)
	_unrelated_count(check)
	_orphan_source_duration(check)

## Combat ages source records at the active caster's start/end boundary; a
## scheduling-only owner slot supplies that boundary when its owner is absent.
## Rolled groups must retain a clock even when no owner-linked group exists.
static func _orphan_source_duration(check: Callable) -> void:
	for unavailable_entry in [false, true]:
		var owner := Batch031Checks._character("shared_orphan_duration_%s" % unavailable_entry, 30)
		var members := make(owner, ROLLED, "timed")
		var source := str(members[0].get_meta("created_source_id"))
		owner.spell_effects[source].remaining_seconds = 6
		owner.spell_effects[source].expiry_phase = "start"
		var battle := Batch056Checks.battle(owner, [] if unavailable_entry else members)
		owner.current_hp = 0
		owner.is_alive = false
		battle.tracker.remove_combatant(owner.character_id)
		if unavailable_entry: CreatedActorSchedulingChecks.place(battle, owner, members)
		var clock_state := {"tracker": battle.tracker, "_spell_boundary_rounds": {}}
		var targets: Array = [owner] + members
		# Dispatch the production source-boundary consumers for one complete
		# round, without creature actions or a second rules implementation.
		var slots: Array = battle.tracker.combatants.duplicate()
		for entry in slots:
			var caster: Variant = entry.entity
			if not caster is Character: continue
			if entry.get("scheduling_only", false):
				CreatedCommandRules.tick_sources(clock_state, caster, "start")
				CreatedCommandRules.tick_sources(clock_state, caster, "end")
			else:
				SpellEffects.tick_boundary(targets, SpellEffects.caster_id(caster), "start")
				SpellEffects.tick_boundary(targets, SpellEffects.caster_id(caster), "end")
		check.call(not owner.spell_effects.has(source) and CreatedActorRules.actors(owner).is_empty(), "Shared-count rolled-only timed source expires once with %s owner, without requiring another source's linked clock" % ["already absent" if unavailable_entry else "removed"])

static func _unrelated_count(check: Callable) -> void:
	var owner := Batch031Checks._character("shared_late_tie", 30)
	var members := make(owner, OWNER, "late")
	var battle := Batch056Checks.battle(owner, [])
	battle.tracker.combatants[1].roll = 15
	battle.tracker.combatants[1].dex = 99
	battle.tracker.sort_initiative()
	battle.tracker.mark_turn_started() # Unrelated goblin starts the same count.
	CreatedActorSchedulingChecks.place(battle, owner, members)
	battle.tracker.next_turn()
	var owner_next: bool = battle.tracker.get_active().id == owner.character_id
	battle.tracker.mark_turn_started()
	var wrapped: bool = battle.tracker.next_turn()
	check.call(owner_next and wrapped and battle.tracker.current_round == 2 and battle.tracker.combatants.filter(func(c): return c.has("shared_group")).all(func(c): return c.eligible_round == 2), "Shared-count first group arrival after an unrelated combatant with equal count/different DEX started waits a round without delaying the existing owner")

static func _rolled(check: Callable) -> void:
	var owner := Batch031Checks._character("shared_rolls", 30)
	var a := make(owner, ROLLED, "a")
	var b := make(owner, ROLLED, "b")
	var battle := Batch056Checks.battle(owner, [])
	var rolls := {"count": 0}
	var capture := func(result):
		if int(result.get("sides", 0)) == 20: rolls.count += 1
	Dice.dice_rolled.connect(capture)
	CreatedActorSchedulingChecks.place(battle, owner, [b[2], a[1], b[0], a[0], b[1], a[2]])
	var original: Dictionary = battle.tracker.shared_groups.duplicate(true)
	for member in a + b: battle.tracker.remove_combatant(member.character_id)
	for member in b + a: CreatedCommandRules.join_initiative(battle, owner, member)
	Dice.dice_rolled.disconnect(capture)
	check.call(rolls.count == 2 and battle.tracker.shared_groups == original and battle.tracker.combatants.filter(func(entry): return entry.has("shared_group")).all(func(entry): return entry.roll == original[entry.shared_group].roll), "Shared-count rolled groups roll once per exact source and empty-group reconstruction preserves both counts")
	# Pin a tie after observing the actual rolls, just as encounter fixtures pin
	# ordinary initiative. Neither source may absorb the other's members.
	for entry in battle.tracker.combatants:
		if entry.has("shared_group"): entry.roll = 12
	battle.tracker.sort_initiative_preserving_active()
	check.call(ids(battle.tracker) == [owner.character_id] + (a + b).map(func(member): return member.character_id) + ["b056_goblin"], "Shared-count separately rolled groups on an equal count retain deterministic contiguous member order")
