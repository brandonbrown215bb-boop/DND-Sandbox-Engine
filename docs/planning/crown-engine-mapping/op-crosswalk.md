# Candidate operation crosswalk

Checked against source on 2026-11-09. The candidates' `authored_operations` names
are only authoring intent (186 unique names). The executable drafts already use real
ops: every `runtime_draft.definition` uses only `SharedSpell` `FIELDS`/`EFFECTS`.

About 87 authored names restate an op the engine already has. When implementing
one, use the existing op below. Don't register the candidate name as a new op.
A name that isn't listed here and doesn't appear in the
[engine vocabulary](../../mechanics/README.md) is genuinely new. Give it one
shared name across spells, features, items and creatures.

## Use the existing op

| Candidate names | Existing op |
|---|---|
| `save_damage`, `save_then_condition`, `save_damage_and_*`, `save_then_*`, `save_outcome_benefit`, `*_damage_and_ignition`, `attack_then_next_roll_grant`, `attack_and_heal_from_damage`, `attack_and_light_source`, `per_recipient_condition_or_attitude`, `outline_area_targets`, `choose_save_gated_curse` | Ordered `steps` (`attack`/`save`/`damage`/`effect`) with `gate`, plus `area_selection` and `grant_condition` |
| `grant_maximum_and_current_hp` | `max_hp_source` (`kind: increase`, `raise_current`) |
| `reduce_max_hp` (creature riders) | `max_hp_source` (`kind: reduction`) |
| `grant_ac_bonus`, `grant_speed_bonus`, `grant_recipient_benefits`, AC part of `reaction_defense` | `grant_source_benefits` (other recipients need BENEFIT work). Don't add another AC carrier |
| `grant_ac_floor`, `grant_base_ac_option` | `ac_floor`, `set_base_ac` / `unarmored_defense` |
| `grant_chosen_resistance` | `grant_damage_response` |
| `grant_chosen_skill_bonus`, `grant_chosen_check_advantage` | `ability_check_numeric_bonus`, `ability_check_advantage` |
| `grant_sense`, `grant_special_visibility` | `darkvision`, `vision_bonus`, `blindsight`, `truesight` |
| `grant_hit_rider`, `post_hit_recurring_damage`, `post_hit_source`, `post_hit_restraint` | `weapon_damage_rider` / `bonus_damage` |
| `grant_exact_weapon_option`, `grant_exact_weapon_upgrade` | `attack_profile` |
| `teleport_actor` | `teleport` |
| `reaction_damage`, `reaction_defense` | `reaction_triggers` (`on_damaged_by_creature`, `on_hit_by_attack`) |
| `interrupt_qualifying_cast` | `cast_interruption_rules` |
| `choose_condition_to_end`, `end_condition_and_grant_protection`, `end_curses` | `remove_condition` (+ `grant_damage_response`), curse removal |
| `choose_utility_effect`, `choose_element_effect`, `choose_cast_time_effect` | `mode_choice` |
| `create_bound_companion`, `create_bound_mount`, `create_temporary_mount`, `create_task_force`, `create_manipulator`, `create_or_renew_actors`, `create_moving_spectral_pack`, `create_action_origin_force` | `create_actor` (+ `exclusive_bond`) |
| `choose_form_benefit`, `project_mist_form` | `actor_projection` |
| `grant_linked_protection` | `grant_damage_link` |
| `attach_object_light`, `create_sunlight_source`, `create_darkness_source`, `create_controlled_lights` | `light_source` |
| `create_*_volume`, `*_terrain`, `*_hazard`, `create_poison_cloud`, `create_moving_damage_aura`, `create_selective_wind_wall`, `create_directional_wind`, `grant_live_aura` | `room_area` / `area_selection` with spatial triggers (`entry`, `start_turn`, `end_turn`) |
| `lock_exact_object`, `unlock_exact_object`, `interact_with_lock` | `locked` / `lock_dc` object facts (`CombatObjectRules`) |
| `resolve_authored_check`, `settle_ordered_branch`, `weighted_table_selection`, `start_authored_encounter`, `offer_authored_shop`, `instantiate_exact_room_object`, `grant_room_loot_once`, `use_existing_map` | Event `skill_check`, `success`/`failure` effects, `EventSystem.roll_event` weights, `start_combat`, `shop`, `room_object`, `give_item`, `reveal_map` |
| `poison_save`, `paralyze_save` (creature riders) | `save` step + `grant_condition` |
| `authored_attack_sequence` (Multiattack) | Existing extra-attack units, not a monster-only path |

## New mechanics: one shared name each

These are new, but each currently appears under several names across sets.

| Proposed name | Current candidate names |
|---|---|
| `create_illusion` | `choose_illusion`, `create_visual_illusion`, `create_multisensory_illusion`, `create_appearance_illusion`, `create_target_only_phantasm`, `mask_magical_classification` |
| `sense_facts` | `sense_magic`, `sense_located_facts`, `choose_thought_sense`, `locate_nearest_kind`, `locate_object`, `disclose_trap_danger`, `identify_touched_target`, `create_remote_sensor`, `grant_detection_exclusion`, `resolve_senses` |
| `communicate` / `grant_language` | `exchange_private_message`, `exchange_remote_message`, `deliver_message_by_actor`, `communicate_with_type`, `communicate_and_animate_plants`, `question_remains`, `grant_language_comprehension*`, `resolve_authored_omen`, `resolve_knowledge_social` |
| `stored_trigger` | `ward_entry`, `store_triggered_effect`, `store_triggered_message`, `ward_hostile_targeting`, `resolve_areas_wards`, `resolve_locks_traps` |
| `grant_action` / `restrict_budget` | `grant_bonus_action`, `grant_recipient_magic_action`, `create_hand_flame_and_action`, `create_held_spell_weapon`, `create_cloud_with_granted_bolts`, `create_transferable_attack_mark`, `grant_restricted_turn_benefits`, `restrict_target_budgets`, `command_next_turn`, `bind_authored_activity` |
| `measured_resource` | `create_measured_resources`, `choose_measured_water_effect`, `purify_measured_resources`, `create_consumable_batch`, `use_physical_stock`, `resolve_supplies`, equipment `light_fuel`/`oil` |
| `grant_movement_mode` | `grant_paid_movement_option`, `grant_surface_traversal`, `alter_fall`, `suspend_target`, `merge_with_stone`, `alternate_plane_by_turn`, `create_extradimensional_space`, `grant_respiration`, `resolve_access_movement` |
| `settle_once` (the CLEAR_REWARD delivery helper) | `apply_milestone_once`, `settle_dungeon_clear`, `resolve_boss_victory`, `defer_reward_until_victory`, `hold_unconsumed_reward_metadata`, `resolve_event_once`, `generate_once_then_restore` |

## Per-ID engine paths to retire

Shared replacements must remove these ID checks, not copy them:

- Weapon mastery map keyed by weapon ID: `src/characters/fighter_rules.gd:8`.
- `"hunters_mark"` hardcoded in the shared executor: `src/combat/shared_step_executor.gd:552`.
- Shield of Faith's +2 AC keyed to the condition name: `src/characters/character.gd:1617`, `src/combat/combat_action.gd:1748`. `blessed`, `baned`, `blurred`, `enfeebled`, `outlined` and `enthralled` are read the same way.
- Shillelagh keyed to the weapon definition ID: `src/characters/character.gd:388`.
- Focus compatibility keyed to item IDs: `src/characters/inventory.gd:171`.
- Per-spell native lists `MANAGED_SPELLS` / `PERSISTED_AREA_MARKER_SPELLS`: `src/spells/spell_effects.gd`.
- Class-ID `type` values in character seeds (`monk_bonus_action`, `stunning_strike`, `rogue_steady_aim`, `eldritch_smite`, `pact_weapon`, ...) are the only executable payload for those features today. They are comparison seeds, not the target syntax.
