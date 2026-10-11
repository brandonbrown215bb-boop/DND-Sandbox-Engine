## Production death/revival and checkpoint behavior, rather than copied formulas.
class_name CorpseChecks
extends RefCounted

static func _character(name: String = "Body check") -> Character:
	var character := Character.new()
	character.initialize(name, "human", "fighter", AbilityScores.new())
	return character

static func run(check: Callable) -> void:
	var prior_time := GameManager.campaign_elapsed_seconds
	GameManager.campaign_elapsed_seconds = 100
	var member := _character()
	member.take_damage(member.current_hp)
	check.call(member.is_downed() and not member.is_dead() and member.corpse_state.is_empty() and CombatAction.is_incapacitated(member), "Zero HP is unconscious, not a corpse; it cannot act")
	check.call(member.heal(1) == 1 and member.is_alive and not member.has_condition("unconscious"), "Ordinary healing restores a downed living party member")
	member.inventory.add_item("ring_of_protection")
	var ring: Dictionary = member.inventory.backpack_instances().filter(func(record): return record["definition_id"] == "ring_of_protection").front()
	member.inventory.attune_instance(str(ring["instance_id"]), member.character_id)
	member.exhaustion_level = 2
	member.take_damage(member.current_hp + member.max_hp)
	var original := member.corpse_state.duplicate(true)
	check.call(member.is_dead() and not member.is_downed() and original.get("death_at_seconds") == 100 and original.get("cause") == "massive_damage", "Massive damage records the real campaign time and cause of death")
	check.call(str(member.inventory.get_instance(str(ring["instance_id"])).get("state", {}).get("attuned_to", "")).is_empty(), "Death ends item attunement without deleting the equipped or carried copy")
	check.call(member.heal(100) == 0, "Ordinary healing cannot revive a dead party member")
	member.long_rest()
	check.call(member.current_hp == 0 and member.corpse_state == original, "Long Rest cannot revive the dead or reset the original death clock")
	check.call(CorpseRules.target_error(member, "revivify", 160).is_empty() and not CorpseRules.target_error(member, "revivify", 161).is_empty(), "Revivify accepts the one-minute boundary and rejects an expired death")
	member.revival_willing = false
	check.call(not CorpseRules.revive(member, 100).get("success", false) and member.corpse_state == original, "A refusing spirit remains dead without a mutated corpse")
	member.revival_willing = true
	CorpseRules.preserve(member, 120)
	check.call(CorpseRules.effective_age(member, 50000) == 20 and CorpseRules.protected_from_undeath(member, 50000), "Gentle Repose pauses the existing death age and prevents becoming Undead")
	CorpseRules.preserve(member, 50000)
	check.call(CorpseRules.effective_age(member, 60000) == 20, "Recasting Gentle Repose extends protection without resetting elapsed death age")
	var serialized := member.to_dict()
	check.call(CorpseRules.saved_error(serialized).is_empty(), "Recorded corpse serializes as a valid optional schema-2 record")
	var restored := Character.new()
	restored.from_dict(serialized)
	check.call(restored.corpse_state == member.corpse_state and restored.character_id == member.character_id and CorpseRules.effective_age(restored, 60000) == 20, "Checkpoint reconstruction preserves corpse identity and preservation intervals")
	var revived := CorpseRules.revive(restored, 60000)
	check.call(revived.get("success", false) and restored.current_hp == 1 and restored.is_alive and restored.corpse_state.is_empty() and restored.exhaustion_level == 1 and restored.character_id == member.character_id and restored.inventory.has_item("ring_of_protection"), "Revival retains party identity, equipment and ongoing effects; reduces Exhaustion by one")
	GameManager.campaign_elapsed_seconds = 60000
	restored.take_damage(restored.current_hp + restored.max_hp)
	check.call(restored.corpse_state["corpse_id"] != original["corpse_id"] and restored.corpse_state["death_at_seconds"] == 60000, "A second death creates a new corpse generation and real death time")
	var expired := _character("Expired")
	CorpseRules.mark_dead(expired, "damage", "intact", 0)
	CorpseRules.preserve(expired, 100)
	check.call(not CorpseRules.target_error(expired, "revivify", 200).is_empty(), "Preserving an already expired corpse never makes Revivify eligible")
	check.call(CorpseRules.effective_age(expired, 864110) == 110 and not CorpseRules.protected_from_undeath(expired, 864100), "Preservation expiry resumes the original death clock and permits later undeath checks")
	for mutation in [{"corpse_id": "someone_else"}, {"death_at_seconds": 1.5}, {"remains": "living"}, {"preserved_seconds": -1}, {"preservation_until": 3}, {"missing_parts": ["arm", "arm"]}, {"recovery_restrictions": ["invented"]}]:
		var invalid := serialized.duplicate(true)
		invalid["corpse_state"].merge(mutation, true)
		check.call(not CorpseRules.saved_error(invalid).is_empty(), "Malformed corpse record refuses before load: %s" % str(mutation))
	for restriction in CorpseRules.RESTRICTIONS:
		var restricted := _character(restriction)
		CorpseRules.mark_dead(restricted, "damage", "intact", 100)
		restricted.corpse_state["recovery_restrictions"] = [restriction]
		check.call(not CorpseRules.target_error(restricted, "revivify", 100).is_empty(), "Revivify rejects explicit recovery restriction: %s" % restriction)
	var partial := _character("Missing hand")
	CorpseRules.mark_dead(partial, "damage", "partial", 100)
	partial.corpse_state["missing_parts"] = ["left_hand"]
	check.call(CorpseRules.revive(partial, 100).get("success", false) and "left_hand" in partial.body_missing_parts, "Non-vital missing parts do not prevent Revivify, which does not restore them")
	var dust := _character("Dust")
	CorpseRules.mark_dead(dust, "disintegrate", "dust", 100)
	dust.disintegrated = true
	check.call(not CorpseRules.target_error(dust, "revivify", 100).is_empty() and CorpseRules.target_error(dust, "gentle_repose", 100).is_empty(), "Dust can be preserved as remains but Revivify cannot restore it")
	var legacy := serialized.duplicate(true)
	legacy.erase("corpse_state")
	legacy.erase("body_death_serial")
	legacy.erase("revival_willing")
	restored.from_dict(legacy)
	check.call(restored.is_dead() and restored.corpse_state["death_at_seconds"] == -1 and not CorpseRules.target_error(restored, "revivify", 60000).is_empty(), "Earlier schema-2 dead characters retain death with an unknown time, never a newly eligible minute")
	legacy["death_save_failures"] = 0
	restored.from_dict(legacy)
	check.call(restored.is_downed() and restored.corpse_state.is_empty(), "Earlier schema-2 zero-HP characters without actual death remain recoverable by healing")
	member = _character("Critical at zero")
	member.take_damage(member.current_hp)
	member.take_damage(1, false, true)
	check.call(member.death_save_failures == 2 and not member.is_dead(), "A Critical Hit at zero HP causes two death failures")
	member.take_damage(1)
	check.call(member.is_dead() and not member.corpse_state.is_empty(), "Damage causing a third death failure records a corpse immediately")
	var stable := _character("Stable recovery")
	stable.take_damage(stable.current_hp)
	stable.death_save_failures = 2
	check.call(stable.stabilize() and stable.death_save_failures == 0 and stable.death_save_successes == 0, "Stabilization resets both death-save counters")
	var recovery_at := stable.stable_recovery_at_seconds
	check.call(recovery_at >= 63600 and recovery_at <= 74400, "Stable recovery rolls a one-to-four-hour campaign deadline once")
	var stable_copy := Character.new()
	stable_copy.from_dict(stable.to_dict())
	check.call(stable_copy.stable_recovery_at_seconds == recovery_at, "Stable recovery deadline survives reconstruction without rerolling")
	CorpseRules.advance_time(stable_copy, recovery_at - 1)
	check.call(stable_copy.current_hp == 0, "Stable recovery does not heal before the recorded deadline")
	CorpseRules.advance_time(stable_copy, recovery_at)
	check.call(stable_copy.current_hp == 1 and stable_copy.is_alive and not stable_copy.is_stable, "A Stable living creature wakes with 1 HP at its recorded deadline")
	stable.take_damage(1)
	check.call(stable.stable_recovery_at_seconds == 0 and not stable.is_stable and stable.death_save_failures == 1, "Further damage cancels Stable recovery and resumes death saves from zero")
	var ordinary := _character("Death save")
	ordinary.take_damage(ordinary.current_hp)
	ordinary.death_save_failures = 1
	FighterChecks._seed_die(20, 1)
	ordinary.make_death_save()
	check.call(ordinary.is_dead() and ordinary.corpse_state.get("cause") == "death_saves", "A natural-one production death save causing three failures records death")
	var downed_massive := _character("Downed massive damage")
	downed_massive.max_hp = 10
	downed_massive.take_damage(downed_massive.current_hp)
	downed_massive.death_save_failures = 1
	var downed_initial_serial := downed_massive.body_death_serial
	downed_massive.take_damage(10)
	check.call(downed_massive.is_dead() and downed_massive.corpse_state.get("cause") == "massive_damage" and downed_massive.body_death_serial == downed_initial_serial + 1, "Damage to a zero-HP character equaling or exceeding maximum HP causes instant death from massive damage")
	var already_dead_serial := downed_massive.body_death_serial
	var dead_damage := downed_massive.take_damage(10)
	check.call(dead_damage == 0 and downed_massive.is_dead() and downed_massive.body_death_serial == already_dead_serial, "Further damage to an already dead character deals 0 and preserves single corpse commitment")
	var downed_buffered := _character("Downed temp HP buffer")
	downed_buffered.max_hp = 10
	downed_buffered.take_damage(downed_buffered.current_hp)
	downed_buffered.temp_hp = 3
	downed_buffered.death_save_failures = 0
	var buffer_absorbed := downed_buffered.take_damage(2)
	check.call(buffer_absorbed == 0 and downed_buffered.temp_hp == 1 and downed_buffered.current_hp == 0 and downed_buffered.death_save_failures == 1 and not downed_buffered.is_dead(), "Damage absorbed by Temporary HP at zero HP depletes buffer and inflicts a death saving throw failure")
	var overflow_dealt := downed_buffered.take_damage(3)
	check.call(overflow_dealt == 2 and downed_buffered.temp_hp == 0 and downed_buffered.current_hp == 0 and downed_buffered.death_save_failures == 2 and not downed_buffered.is_dead(), "Damage overflowing Temporary HP at zero HP inflicts a second death saving throw failure")
	var downed_crit_absorbed := _character("Downed critical absorbed")
	downed_crit_absorbed.max_hp = 10
	downed_crit_absorbed.take_damage(downed_crit_absorbed.current_hp)
	downed_crit_absorbed.temp_hp = 5
	downed_crit_absorbed.death_save_failures = 0
	downed_crit_absorbed.take_damage(2, false, true)
	check.call(downed_crit_absorbed.temp_hp == 3 and downed_crit_absorbed.death_save_failures == 2 and not downed_crit_absorbed.is_dead(), "Critical damage fully absorbed by Temporary HP at zero HP inflicts two death saving throw failures")
	var downed_buffer_massive := _character("Downed buffer massive boundary")
	downed_buffer_massive.max_hp = 10
	downed_buffer_massive.take_damage(downed_buffer_massive.current_hp)
	downed_buffer_massive.temp_hp = 3
	downed_buffer_massive.take_damage(10)
	check.call(downed_buffer_massive.is_dead() and downed_buffer_massive.corpse_state.get("cause") == "massive_damage", "Damage equaling maximum HP at zero HP causes instant death even with a Temporary HP buffer")
	var downed_immune := _character("Downed zero damage")
	downed_immune.max_hp = 10
	downed_immune.take_damage(downed_immune.current_hp)
	downed_immune.death_save_failures = 1
	var zero_dmg := downed_immune.take_damage(0)
	check.call(zero_dmg == 0 and downed_immune.death_save_failures == 1 and not downed_immune.is_dead(), "Genuine zero damage dealt to a zero-HP character inflicts no failure")
	var downed_overflow_massive := _character("Downed overflow massive")
	downed_overflow_massive.max_hp = 10
	downed_overflow_massive.take_damage(downed_overflow_massive.current_hp)
	downed_overflow_massive.temp_hp = 3
	downed_overflow_massive.take_damage(13)
	check.call(downed_overflow_massive.is_dead() and downed_overflow_massive.corpse_state.get("cause") == "massive_damage", "Damage overflowing Temporary HP equaling maximum HP causes instant death at zero HP")
	var downed_replacement_actor := _character("Downed replacement bypass")
	downed_replacement_actor.max_hp = 15
	downed_replacement_actor.features.append({
		"id": "undead_fortitude",
		"type": "zero_hp_replacement",
		"trigger": "zero_hp",
		"save_ability": "CON",
		"dc_base": 5,
		"dc_add_damage": true,
		"replacement_hp": 1
	})
	downed_replacement_actor.take_damage(downed_replacement_actor.current_hp)
	downed_replacement_actor.current_hp = 0
	downed_replacement_actor.is_alive = false
	downed_replacement_actor.death_save_failures = 0
	FighterChecks._seed_die(20, 20)
	downed_replacement_actor.take_damage(1)
	check.call(downed_replacement_actor.current_hp == 0 and downed_replacement_actor.death_save_failures == 1, "Already-downed character never triggers zero-HP replacement on subsequent damage")
	var future := serialized.duplicate(true)
	future["corpse_state"]["preservation_started_at"] = 70000
	future["corpse_state"]["preservation_until"] = 934000
	check.call(not CorpseRules.saved_clock_error(future, 60000).is_empty(), "A corpse clock ahead of campaign time refuses save preflight")
	future = serialized.duplicate(true)
	future["corpse_state"]["preserved_seconds"] = 100000
	check.call(not CorpseRules.saved_clock_error(future, 60000).is_empty(), "Forged protection exceeding real time since death refuses save preflight")
	var caster := _character("Caster")
	caster.spell_slots = {"1": 1}
	var caster_slots := caster.spell_slots.duplicate()
	var target_error := CombatAction.resolve_spell(caster, member, DataLoader.get_spell("cure_wounds"), true)
	check.call(not target_error.get("success", false) and member.is_dead() and caster.spell_slots == caster_slots, "Ordinary spell resolution refuses a dead creature without spending the caster's slot")
	member.level_up()
	check.call(member.is_dead() and member.current_hp == 0, "A campaign level-up does not restore a dead party member")
	GameManager.campaign_elapsed_seconds = prior_time
