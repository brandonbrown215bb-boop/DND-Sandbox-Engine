# Batch 077 acceptance review: S-127 per-swing damage choice (PR #50)

Reviewer: runtime-reviewer. Head reviewed: dd52b51 (code 0190bf3). Card Q-20261025-213314-2114.

## Verdict: ACCEPT (PARTIAL, as declared). No code fixes needed.

Finish line, as the builder quoted it in the PR. The reviewer did not see Brandon's original message: "ask on every swing for a choice that applies to one attack. Carry it across the Attack action only when the feature says it lasts that long. Fix the bug where the choice is made on the first swing and later swings silently fall back to normal damage."
- Met. Every Extra Attack swing calls `_extra_swing_damage_choice`. A rule carries only when it declares `choice_duration: attack_action`. Dismissing the menu, or giving a stale answer, holds the swing and logs it; there is no fallback.

## Held-swing audit (code read, combat_state.gd)
- **Not lost and not doubled.** On `held`, the loop breaks *before* `remaining_attack_swings -= 1`. Nothing is rolled, so there's no damage. The next click consumes it exactly once.
- **No reuse after the action ends.** `_start_combat_turn` zeroes `remaining_attack_swings` and `attack_action_damage_choice`. A fresh Attack-action spend also clears the carry.
- **Target dies.** The loop breaks on `is_alive` before asking. The stale check after the answer also covers death and removal.
- **Target moves out of reach.** The range check runs before the menu opens. *Nit:* range isn't rechecked after the await. That's harmless on the player's own turn, since nothing moves during the menu.
- **attack_action carry.** It's checked again against the source, the duration and the options on every use (`carried_choice`). A forged or cross-source record is refused (unit-tested).
- **Legacy data.** A missing key is read as `attack`. A bad duration, or a duration without choices, is refused by `validate_rule`.
- **Saves.** No new field. Both `remaining_attack_swings` and the carry are in memory only (pre-existing). `batch_067_weapon_damage_choice_reload` passes.
- **Refusal before cost.** A held swing spends nothing. The first-swing stale path returns before `_spend_action_cost`.
- **ADR-0018.** No per-ID branches. Everything is driven by the data key.
- **SRD 5.2.1 (from memory, page unconfirmed).** Moving or acting between Extra Attack swings is legal, so a held swing that's resumed later in the same turn isn't an exploit.

## Evidence (Godot 4.7.2, /tmp/rev_wt077)
- Import was run twice. Godot aborted at exit, as on prior batches, with 0 SCRIPT/Parse errors.
- Logic: **6236 passed, 0 failed**. The check-script gate passed (84 scripts, 0 failed).
- Scenarios, each run on its own, all PASSED with 0 FAIL and 0 SCRIPT ERROR:
  - batch_077_per_swing_choice_flow
  - batch_067_weapon_damage_choice_flow
  - batch_067_weapon_damage_choice_reload
  - barbarian_action_flow
  - monk_action_flow
- No regressions against the known main failures (batch-066).

## Proposed count update
Logic 6225 -> 6236 (+11 Batch077Checks). Add one new scenario: batch_077_per_swing_choice_flow.

## Open for Brandon
- No production content declares `attack_action` yet. Which features should declare it?
- Cards for:
  - choice hosting for opportunity attacks, Light off-hand attacks, Cleave and created-creature attacks;
  - item-granted profiles.
- Merge order: #48, then #49, then #50.
