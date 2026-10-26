# Batch 066 acceptance: S-121/S-122 travel placement (PR #38)

Reviewer: Runtime Reviewer. Card Q-20261025-044851-d47e (claimed until 2026-10-26 02:44 CDT). Reviewed head 1e07f56, based on main d450b24.

Finish line (verbatim): "Finish travel exit and arrival placement (S-121/S-122). Extend the remaining travel hosts using the existing placement rules. Illegal destinations must refuse cleanly; captured outcomes and costs must settle once."

## Verdict: ACCEPT after R1, S-121 still PARTIAL

The arrival half is done for combat teleport, room Misty Step and forced-movement steps. The exit half (engulf/swallow escape) still has no host, so S-121 is **not** done (same ruling as 053; card Q-20261021-043117-1c72 stays open).

## R1 (fixed in c64785c)
03e2aad refused a forced step only when the start position was legal. Once a body's start was illegal (for example a legacy overlap), every later step skipped all checks, so a push could move it into a wall or off the map. Now: a legal start is held to full-footprint legality, as before. An illegal start may still pass through creature overlap (the barbarian_action_flow case), but its center can never enter a wall, an impassable cell or an off-map cell. Edge cells of a Large or larger footprint stay lenient, as they were before 066, because barbarian_action_flow pushes a Huge target partly off its small fixture grid and asserts that it lands there. Four tests added.

## Verified
- Refused before cost: out of range, unseen (when requires_sight is set), any cell of a Large occupant's footprint, wall, off-map, the same space, and no authored distance. The combat recheck runs after the option popups and before commit_metamagic/commit_spell_resource. The room host checks before spend_spell_slot and refuses an Incapacitated caster through _room_spell_caster_error.
- Settles once: teleport_settled guards the resolver, and the room path spends one slot and then refuses a second cast.
- ADR-0018: no per-ID branches in the new rules. The room host is still gated to misty_step (existing code, flagged by the builder).
- Legacy: no new saved fields. The legacy teleport_distance_feet fallback was dropped, but no data uses it. The loader now refuses a teleport effect with no distance, which could break third-party data (none in the repo).
- SRD (from memory, no PDF): Misty Step is a Bonus Action, 30 ft, to an unoccupied space you can see. Distance 6 and requires_sight true match.

## Scenario baseline (229, one at a time per worktree, .godot cleared, imported twice)
- main d450b24: 70 failed. PR 1e07f56: 72 failed. The diff (batch_056_created_initiative_flow, batch_057_mode_costs_flow, fighter_progression, shared_initiative_flow, wall_of_fire_spell_flow) is all flakes: each one gives the same result on main and the PR when rerun alone. fighter_progression fails on both (combat_state.gd:2942, active_character is null). batch_066_travel_placement_flow fails on main only because the scenario doesn't exist there. **No regressions.**
- The main failures are **real breakage on main, not the environment.** They reproduce after clearing .godot and importing twice. 59 of them are assertion failures, mostly in the real spell-picker/slot-spend UI flows (for example action_history_flow, barkskin, death_ward, chain_lightning). 9 are harness SCRIPT ERRORs, "Invalid access of index '1'", where fixtures assume the encounter has at least 2 monsters. This is a separate blocker for Brandon, not fixed here. The main failures: action_history_flow attack_result_adjustment_flow barbarian_choice_flow bard_action_flow barkskin_spell_flow batch_020_suppression_aura_flow batch_057_mode_costs_flow batch_066_travel_placement_flow batch_i_review_flow beacon_of_hope_spell_flow chain_lightning_mixed_targets_flow chain_lightning_target_identity_flow child_group_flow class_level_table_flow cleric_action_flow cleric_strike_flow cloud_of_daggers_spell_flow conjure_celestial_spell_flow core12_shared_rules damage_history_flow darkvision_spell_flow death_ward_spell_flow detect_evil_and_good_spell_flow detect_poison_and_disease_spell_flow divine_favor_spell_flow enhance_ability_spell_flow faerie_fire_spell_flow failed_save_numeric_bonus_flow fire_area_object_ignition_flow formula_number_flow goodberry_spell_flow grease_spell_flow heroism_spell_flow identify_spell_flow invisibility_spell_flow jump_spell_movement local_room_object_flow mage_armor_spell_flow magic_weapon_spell_flow mass_cure_wounds_flow meteor_swarm_object_area_flow mixed_mechanics_encounter post_roll_die_bonus_flow ranger_action_flow ranger_natures_veil_blindsight result_reducer_continuation_flow result_reducer_flow roll_token_normal_controls_flow s026_relationship_willingness_flow s029_save_context_flow sanctuary_spell_flow see_invisibility_spell_flow shared_distance_predicate_flow shared_entity_binding_flow shared_fact_predicate_flow shared_margin_hp_gate_flow shared_next_melee_hit_grant_flow shared_prior_result_identity_flow shared_spell_attack_bonus_flow shared_spell_normal_controls_flow shared_spell_outcome_maps_flow shared_spell_p1_flow sleep_spell_flow sorcerer_subtle_spell sorcerer_twinned_spell spell_cast_stage_flow spirit_guardians_spell_flow true_strike_spell_flow ward_normal_controls_flow wizard_capstone_cast_modes 

## Counts
- Logic: 5962 passed, 0 failed (5958 builder + 4 review), 0 SCRIPT ERROR. batch_066_travel_placement_flow, barbarian_action_flow and s121_exit_placement_flow pass on c64785c.

## Open decisions (Brandon)
- Should an illegal-start push be held to full-footprint terrain legality? Today only its center is. That would change barbarian_action_flow's off-grid expectation.
- Main is red: 70 of 229 scenarios fail. Who triages it, and should it block merges?
- Find Steed center-only arrival, multi-target and planar teleports, and a room host beyond Misty Step: should each get a card?
