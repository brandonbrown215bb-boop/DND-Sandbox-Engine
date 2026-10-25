# Scenario triage: main vs #47 (2026-10-25)

Final report. Brandon's P1 ruling: triage main's scenario failures against #47 (top of the 066–075 stack), gameplay vs fixture.

- **main**: `origin/main` @ d450b24. **#47**: `batch-075-linked-removal` @ 1d05d7f. Both are detached worktrees: `/workspace/wt-triage-main`, `/workspace/wt-triage-047`.
- **Scenario list**: the `match` block in `_run_scenario` (`src/viewport_harness.gd`). main has 228 scenarios. #47 has 247, adding 19 `batch_066`–`batch_075` scenarios.
- **Logs** are on the build box, not in the repo: `/workspace/triage_logs/{main,047}/<scenario>.log`, the summary at `/workspace/triage_logs/summary.csv`, the reruns at `/workspace/triage_logs/rerun/`, and the diagnostic probes at `/workspace/probe/out/`.

## Commands
Every run was strictly serial: one Godot process at a time, checked with `pgrep` before each start.

1. **Full sweep** (`/workspace/triage_driver.sh`, 09:12–15:05 CDT). Each scenario got a fresh, then deleted, `XDG_DATA_HOME`/`XDG_CONFIG_HOME`:
   `XDG_DATA_HOME=$ud XDG_CONFIG_HOME=$ud timeout 180 godot --headless --path . res://scenes/viewport_harness.tscn --scenario=<name>`
   PASS means `SCENARIO PASSED` and rc 0. rc 124 is TIMEOUT.
2. **One rerun of each flaky candidate** (`/workspace/triage_rerun.sh`): the same command, run once only, for every TIMEOUT plus the one main-FAIL/#47-PASS case.
3. **Diagnostic HUD-log probes**, on main only, for 59 failing scenarios (`/workspace/probe/run.sh`). These are separate from the reruns and play no part in the flaky verdicts. They use an out-of-repo SceneTree script that extends `src/viewport_harness.gd` and prints the combat HUD log at scene teardown. No repo files were changed. They show the in-game refusal text that the scenario logs leave out.

## Totals
| side | scenarios | PASS | FAIL | TIMEOUT |
|---|---|---|---|---|
| main | 228 | 157 | 66 | 5 |
| #47 | 247 | 167 | 74 | 6 |

| main → #47 | count |
|---|---|
| PASS → PASS | 154 |
| FAIL → FAIL | 62 |
| FAIL → TIMEOUT | 3 |
| TIMEOUT → FAIL | 3 |
| TIMEOUT → PASS | 2 |
| PASS → TIMEOUT | 3 |
| FAIL → PASS | 1 |
| absent → PASS (new 066–075 scenarios) | 10 |
| absent → FAIL (new `*_reload` scenarios) | 9 |

That makes **83 distinct scenarios** that did not pass on at least one side: 71 on main and 80 on #47.

## Categories (one per scenario, 83 total)
| cat | meaning | count |
|---|---|---|
| A | real gameplay/runtime bug | **12**: 3 identified (R4, R5, fixed-on-#47) plus 9 provisional (R9, cause not established) |
| B | stale or wrong fixture/test expectation | **57**: R1 8, R2 16, R3 33 |
| C | harness/environment | **9** (R7) |
| D | flaky (passed on its single rerun) | **5** (R8) |

## Shared root causes
There are **8 shared root causes** (R1–R8). R9 holds the scenarios that are unresolved one-offs.

### R1 (B): `_setup_world` spawns one goblin, but the tests index a second monster. 8 scenarios.
`src/viewport_harness.gd` `_setup_world()` has used `"monster_ids": ["goblin"]` since b6c1058 (2026-10-14). Before that it spawned two goblins. Tests still read `combat.monster_entities[1]`, which gives `SCRIPT ERROR: Invalid access of index '1' on a base object of type 'Array[Dictionary]'`, or they assert `monster_entities.size() >= 2`.

The scenarios:
- `barbarian_choice_flow`
- `cleric_action_flow`
- `cleric_strike_flow`
- `core12_shared_rules`
- `detect_evil_and_good_spell_flow`
- `faerie_fire_spell_flow`
- `spell_cast_stage_flow`
- `sorcerer_twinned_spell` ("combat fixture provides two creatures for Twinned Spell"; its later checks also hit R3's "Invalid combat action.")

All eight fail the same way on both sides.

### R2 (B, probable): the component gate refuses fixture casters. 16 scenarios.
The probe HUD logs show the cast refused at `src/spells/spell_cast_validation.gd` with "<Spell> requires a free hand for spell components." or "...requires an available hand and a compatible focus or component pouch." Fixtures build casters with `_fresh_char(...)` and give them no focus, pouch or free hand. Batch 048 (1832305, 2026-10-20) made wand, staff and rod items occupy a hand. The rule itself matches SRD components, so the fixtures predate it.

The scenarios:
- `barkskin_spell_flow`
- `beacon_of_hope_spell_flow`
- `conjure_celestial_spell_flow` (also logs "Invalid combat action.")
- `darkvision_spell_flow`
- `death_ward_spell_flow`
- `detect_poison_and_disease_spell_flow`
- `divine_favor_spell_flow`
- `goodberry_spell_flow` (also logs "Invalid combat action.")
- `grease_spell_flow`
- `invisibility_spell_flow`
- `mage_armor_spell_flow`
- `magic_weapon_spell_flow`
- `sanctuary_spell_flow`
- `see_invisibility_spell_flow`
- `sleep_spell_flow`
- `spirit_guardians_spell_flow`

The interim report blamed `barkskin_spell_flow` on a duplicate `barkskin` record. `imported_spells.json` and `srd_additional_spells.json` do both define `barkskin`, but the logged failure is the component refusal: the cast never resolves. Whether the legacy record also wins was **not** verified.

### R3 (B): fixtures grant spells without the source-owned permission. 33 scenarios.
`SpellPermissionRules.for_spell` (squashed in with aee56c0, 2026-10-19) requires the spell in `feature_choices[<spellcasting feature>]`, and for wizards also in `wizard_spellbook`. Fixtures that only fill `known_spells` and `wizard_spellbook` get no permission. The symptoms:
- The HUD picker doesn't list the spell (`opened=false`, an empty HUD log, "Normal spell picker lists ..." fails), or
- `CombatCommand.from_hud_for_character` returns null and the HUD logs "Invalid combat action."

Most checks after the first failure are cascades. That includes `jump_spell_movement`'s "landing across impassable terrain", which never reaches movement.

Scenarios:
- **"Invalid combat action." in the probe log**:
  - `chain_lightning_mixed_targets_flow`
  - `chain_lightning_target_identity_flow`
  - `cloud_of_daggers_spell_flow`
  - `fire_area_object_ignition_flow`
  - `mass_cure_wounds_flow`
  - `meteor_swarm_object_area_flow`
  - `ranger_action_flow`
  - `ranger_natures_veil_blindsight`
  - `shared_fact_predicate_flow`
  - `sorcerer_subtle_spell`
  - `true_strike_spell_flow`
- **Picker never opens or lists the spell** (each of these fixtures sets `known_spells` but no `feature_choices`):
  - `action_history_flow`
  - `attack_result_adjustment_flow`
  - `batch_i_review_flow`
  - `child_group_flow`
  - `class_level_table_flow`
  - `damage_history_flow`
  - `failed_save_numeric_bonus_flow`
  - `formula_number_flow`
  - `jump_spell_movement`
  - `post_roll_die_bonus_flow`
  - `result_reducer_continuation_flow`
  - `result_reducer_flow`
  - `roll_token_normal_controls_flow`
  - `s026_relationship_willingness_flow`
  - `s029_save_context_flow`
  - `shared_distance_predicate_flow`
  - `shared_entity_binding_flow`
  - `shared_margin_hp_gate_flow`
  - `shared_prior_result_identity_flow`
  - `shared_spell_attack_bonus_flow`
  - `shared_spell_outcome_maps_flow`
  - `ward_normal_controls_flow`

The link from the missing `feature_choices` to each failure is inferred from the fixture code and the HUD symptom. It was not confirmed by patching a fixture.

### R4 (A): the monster drop command reads `tracker.round_number`. 1 scenario.
`combat_state.gd:1308` (1311 on #47) reads `tracker.round_number`, but `InitiativeTracker` only has `current_round`. Affects `mixed_mechanics_encounter`: 24 failures on both sides, after `Invalid access to property or key 'round_number'`.

### R5 (A, probable): the `_flash_hex` await continuation runs with no active character. 1 scenario.
After `await` 0.12 s, `_flash_hex` calls `_highlight_attack_targets()` while `pending_action_type == "attack"`. That reads `active_character.inventory` (line 2942) while `active_character` is null during an out-of-turn reaction. Affects `fighter_progression` on both sides.

### R6 (A, probable): the `_start_combat_turn` await doesn't revalidate before `_run_monster_ai`. No scenario is attributed to it alone.
After `await` 1.0 s, `_run_monster_ai()` assigns `active_combatant["entity"]` (a Character Object) to a `Dictionary`. That is `combat_state.gd:1187` on #47 and `:1184` on main. It is timing-dependent and only ever shows up as an extra error:
- `attack_result_adjustment_flow`: on the #47 sweep, 29 failures against main's 28. It did not appear on main's sweep or main's probe.
- `result_reducer_continuation_flow`: on the main probe, 3 failures against the sweep's 2.

The code is present on main as well, so this is **not** a #47 regression.

### R7 (C): reload scenarios lose user data under per-scenario isolation. 9 scenarios, #47 only (new).
`batch_067`–`batch_075` `*_reload` read the save slot and IDs (`user://batch_0NN_ids.*`) that their paired `*_flow` scenario wrote. The driver gave every scenario a fresh, then deleted, user dir, so that data was gone. 068 logs "Parse JSON failed".

The scenarios:
- `batch_067_weapon_damage_choice_reload`
- `batch_068_exact_contents_reload`
- `batch_069_unknown_weight_reload`
- `batch_070_attack_ac_upgrades_reload`
- `batch_071_monster_max_hp_reload`
- `batch_072_last_charge_reload`
- `batch_073_explicit_death_reload`
- `batch_074_work_site_reload`
- `batch_075_linked_removal_reload`

All 10 paired `*_flow` scenarios pass. These need a flow→reload run sharing one user dir. That was not done here.

### R8 (D): startup hangs. 5 scenarios.
The TIMEOUT logs contain only the `Godot Engine v4.7.2` banner. Elapsed times go up to 1181 s, well past the 180 s `timeout`, so the process hung before DataLoader loaded. Each passed on its single rerun.

| side | scenario | rerun |
|---|---|---|
| main | `character_creation` | PASS (9 s) |
| main | `projected_vessel_flow` | PASS (9 s) |
| #47 | `batch_g_protection_flow` | PASS (10 s) |
| #47 | `crown_composition_three_four` | PASS (12 s) |
| #47 | `monk_action_flow` | PASS (15 s) |

The same hang also hit 6 scenarios that really fail. Their single rerun failed, and each is categorised by its real cause above.

| side | scenario | rerun | real cause |
|---|---|---|---|
| main | `grease_spell_flow` | FAIL, 7 | R2 |
| main | `failed_save_numeric_bonus_flow` | FAIL, 52 | R3 |
| main | `class_level_table_flow` | FAIL, 8 | R3 |
| #47 | `conjure_celestial_spell_flow` | FAIL, 5 | R2 |
| #47 | `see_invisibility_spell_flow` | FAIL, 3 | R2 |
| #47 | `shared_spell_attack_bonus_flow` | FAIL, 40 | R3 |

### R9 (A, provisional): unresolved single-scenario failures. 9 scenarios.
The production path runs, but one or two assertions disagree. The logs don't establish whether the engine or the expectation is wrong. All fail identically on both sides.

| scenario | failing assertion / evidence |
|---|---|
| `heroism_spell_flow`, `enhance_ability_spell_flow` | Upcast effects apply to both targets and the slot is spent. Then the HUD logs "<caster>'s concentration ends.", and the check that concentration tracks 2 targets fails. The shape is the same in both, so the cause may be shared. |
| `bard_action_flow` | "The healed Prone recipient can decline standing". The HUD logs "Seat 1 - Audit Bard feature prompt timed out and was declined." The test's dialog answer did not find the prompt. |
| `batch_020_suppression_aura_flow` | The real movement click leaving the aura does not restore the unexpired condition. |
| `identify_spell_flow` | The "After one minute ... recorded description and charges" check fails. The HUD logs "Spellbook is not a magic item in its current record." |
| `local_room_object_flow` | 2 movement checks fail on both sides: mode/surface traversal (`climb_reachable=false fly_speed=false swim_allowed=false freedom=false`) and uphill cost. Main's sweep had 3 more failures (fire extinguish, area/Fog Cloud reload) that did not recur in main's probe run and are absent on #47. Those 3 are nondeterministic. |
| `shared_next_melee_hit_grant_flow` | "Fire immunity reduces the typed bonus to zero while consuming the matching grant once" |
| `shared_spell_p1_flow` | "P1 earlier resolved Fire component heals its wounded source owner by floor(component / 2) only". It warns `finish_pending_spell_damage refused: Request has already been settled.` |
| `wizard_capstone_cast_modes` | The at-will Spell Mastery cast starts, but `pending_spell_data` no longer carries `_wizard_free_cast` |

### Fixed on #47 (A): 1 scenario
`shared_spell_normal_controls_flow` failed on main in both the sweep and the rerun, with the same 9 B2A defeat/tracker checks. It passes on #47. #47 changes `zero_hp_aftermath_rules.gd` (+87) and `max_hp_source_rules.gd`, which is a likely but **unbisected** explanation.

## New on #47 (pass or absent on main, not passing on #47)
- **PASS → TIMEOUT**: `batch_g_protection_flow`, `crown_composition_three_four`, `monk_action_flow`. All three are R8 (flaky) and passed on rerun.
- **Absent → FAIL**: the 9 `*_reload` scenarios (R7, harness).
- No real gameplay regression was found. The only extra failure inside a shared failing scenario is R6's timing-dependent script error in `attack_result_adjustment_flow`, and that code is also on main.

## Relation to the #38 ruling ("check full footprint against terrain and fix barbarian fixture")
- The barbarian regression in #38's own sweep was `barbarian_action_flow` (a Huge target trapped when it starts overlapped). It **passes** on both main and #47 here.
- `barbarian_choice_flow` fails on both sides from **R1**, the single-goblin `_setup_world` fixture. It is a barbarian fixture failure, but it has nothing to do with footprint or terrain.
- No failure was traced to full-footprint terrain checks. The terrain-adjacent failures are:
  - `local_room_object_flow`'s movement-mode and uphill checks (R9, unresolved). They test single-cell `_player_can_enter`/`_player_reachable`/`_enemy_step_movement_cost`.
  - `jump_spell_movement`'s impassable-terrain landing, which is an R3 cascade.

## Environment notes
- Every run logs `WARNING: [DataLoader] Rejected 25 unsupported effectless feature records`. This is noise.
- **Translation checkout.** The interim report said `git checkout -- docs/reviews/*.translation` was done in both worktrees. In fact:
  - The driver ran it only in the main and #47 worktrees, with errors silenced.
  - No `*.translation` file is tracked anywhere in the repo (`git ls-files '*.translation'` is empty), so the command was a no-op.
  - Re-running it at 16:07 CDT in `wt-triage-main`, `wt-triage-047` and `wt-triage-report` returns `pathspec ... did not match any file(s) known to git` in each.
  - `git status --short` is clean in all three. Import left no tracked file modified.

## Limits
- One sweep per side, and one rerun per flaky candidate. Nothing else was rerun, so other nondeterminism may be hidden. `local_room_object_flow` shows some.
- The diagnostic probes ran on main only. #47 categories assume the same cause wherever the failing checks match. They do for every FAIL→FAIL scenario except `local_room_object_flow` (5 vs 2) and `attack_result_adjustment_flow` (28 vs 29), both explained above.
- No bisects. The commit attributions (b6c1058, 1832305, aee56c0) come from `git log` and code reading, not from bisect runs.
- R2 and R3 are B based on the fixture code and the in-game refusal text. No fixture was patched to prove the scenario then passes.
- R9's A is provisional.
- The R7 reload scenarios were not run paired with their flows.
