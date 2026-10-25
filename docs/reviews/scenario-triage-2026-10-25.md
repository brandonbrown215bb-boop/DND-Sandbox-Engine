# Scenario triage: main vs #47 (2026-10-25) — PARTIAL

Status: **interim**. The serial driver is still running on the build box (one Godot process at a time, 180 s timeout per scenario, about 15 s per run). This report covers the first 46 of 228 main scenarios and 45 of 247 #47 scenarios, in alphabetical order (through `batch_054_*`). It will be updated when the run completes.

- main: `origin/main`. #47: `origin/batch-075-linked-removal` @ 1d05d7f (includes eee958b).
- Scenario list: the `match` block in `_run_scenario` (`src/viewport_harness.gd`). main has 228 scenarios. #47 has 247, which adds 19 `batch_066`–`batch_075` scenarios.
- Logs: `/workspace/triage_logs/{main,047}/<scenario>.log`. CSV: `/workspace/triage_logs/summary.csv`.

## Totals so far
| side | run | pass | fail |
|---|---|---|---|
| main | 46 | 40 | 6 |
| #47 | 45 | 39 | 6 |

**Diff:** no new failures on #47 and none fixed. Every failure so far fails the same way on both sides. `attack_result_adjustment_flow` shows 29 failed checks on #47 against 28 on main, from the same root cause.

## Failures and categories
| scenario | main | #47 | cat | cause |
|---|---|---|---|---|
| attack_result_adjustment_flow | FAIL | FAIL | A | `combat_state.gd:1187` `_run_monster_ai` assigns `active_combatant["entity"]` (a Character Object) to a `Dictionary`. Monster AI runs while a player is the active combatant, and the script error aborts the rest of the flow (about 28 cascaded checks). Production code has no guard. The scenario's turn setup may be what provokes it. |
| barkskin_spell_flow | FAIL | FAIL | A (data) | There are two `barkskin` definitions: `srd_additional_spells.json` (bonus action, AC 17) and `imported_spells.json` (action, AC 16, the 2014 text). The legacy record wins, so the cast uses the wrong action economy and AC. |
| barbarian_choice_flow | FAIL | FAIL | B | `viewport_harness.gd:804`: `monster_entities[1]` is accessed but the fixture spawns only one monster (the "Invalid access of index '1'" family). |
| action_history_flow | FAIL | FAIL | A/B (open) | The real HUD spell menu never opens (`opened=false`), so no cast or bonus action is recorded. 5 checks fail. Needs a closer look: either a spell-menu control path regression or a stale control lookup. |
| bard_action_flow | FAIL | FAIL | B (likely) | `_answer_class_dialog(..., "Power Word Heal", false)` finds no "stand up" prompt for the healed Prone ally. Either the prompt label changed or the prompt is no longer offered (if so, that's A). |
| batch_020_suppression_aura_flow | FAIL | FAIL | A/B (open) | The real movement click leaving the aura does not restore the unexpired condition. Re-entering does suppress it. |

Category counts so far: A 2, A/B undetermined 2, B 2 (one of them likely), C 0 (no timeouts), D 0 (no flakes rerun yet).

## Shared root causes (so far)
- `combat_state.gd:1187` (monster AI invoked with a non-monster active combatant): 1 scenario so far. Expect more in combat flows.
- Duplicate legacy spell records in `imported_spells.json` shadowing SRD 2024 records: 1 scenario so far (Barkskin). Likely affects other spells.
- Fixture monster count (index '1'): 1 so far.

## Environment notes
- Every run logs `WARNING: [DataLoader] Rejected 25 unsupported effectless feature records`. This is noise, not a failure.
- After the runs, `git checkout -- docs/reviews/*.translation` is done in both worktrees.
