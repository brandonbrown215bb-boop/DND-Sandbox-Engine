# Batch 052 acceptance: HUD mode and upgrade controls (card Q-20261021-004820-732c)

Reviewer: runtime-reviewer. PR #23, builder head 320e70c, stacked on #21 (6537e97). Worktree /tmp/rev_wt052.

## Verdict
**ACCEPT after R1** (this branch). One real defect fixed. Scenario harness gap fixed separately (below).

## R1: incapacitated owners could burn activation uses (fixed, 98dfb5c)
`ModeControls.actions` offered "Activate" to a Stunned/Incapacitated owner, and `FeatureModeRules.activate` had no
incapacitation check. Repro (T1 on builder head): stunned fighter, Tide Surge 2/2 → HUD apply succeeded, a direct
activate succeeded, uses 0/2; the rule declares `end_on: incapacitated`, so `refresh` ends each activation at once:
two uses spent for nothing. SRD 5.2.1 Incapacitated: the creature can't take any action, Bonus Action or Reaction.
Fix: `FeatureModeRules.incapacitated()`; `activate` refuses `"incapacitated"` before `use_feature`; `ModeControls.row`
marks activation-boundary rows unavailable (reason `incapacitated`), so the HUD lists them disabled. Rest-boundary
choices are untouched. Generic (no per-ID branch, ADR-0018).

## Stress checks (src/review_052_checks.gd, all green)
- T1 incapacitated (R1 above; red on 320e70c).
- T2 double-click: the same token answered twice applies once; second is `stale`.
- T3 two identical blades: two rows, separate pools; activating one leaves the other offered at full uses (050).
- T4 popup offered inside a merged form is `stale` after the form ends; a fresh offer works.
- T5 switching the upgrade back through the HUD caps held uses (038 R1).
- T6 feat-owned modes (051 Origin + level feat) round-trip and reselect without spending.
Also confirmed by reading: refusals all precede `use_feature`/`choose_alternative`; cancel/closed popup/superseded
popup/changed active character spend nothing (`request_mode_control`); no new save shapes; no per-ID branches.
Wrong turn: the HUD rejects answers if `active_character != owner`; `ModeControls.apply` itself has no turn check
(it is only reachable from the HUD), acceptable.

## Scenario harness gap (builder report): reproduced and fixed, separate PR
Scratch scenario (not committed): `_assert(true)`, then `null.explode()`, then `_assert(false)`. Before: log shows
`SCRIPT ERROR: Invalid call...`, then `SCENARIO PASSED: scratch_mid_error`, exit 0. After: `[FAIL] 1 SCRIPT ERROR(s)
during the scenario aborted harness code`, `SCENARIO FAILED`, exit 1.
Fix (commit 1b22df7, branch review-052-scenario-gate, PR against `harness-fail-unparseable-checks` / #20): the
viewport harness registers `ScriptErrorCounter` and fails the scenario on any script error. It lives on #20 because
`ScriptErrorCounter` exists only at #20 head a93e6db (my cafa R1); this stack sits on #20's older 70ba454, and a copy
of the class here would be a duplicate `class_name` parse error once #20 merges. `run_tests.sh` already greps
SCRIPT ERROR for its 15 listed scenarios; the batch 031-052 scenarios are run directly and had no gate.
Validated on a scratch merge of this branch + the harness branch: full run_tests.sh ALL TESTS PASSED (logic 5484/0,
15 listed scenarios), and batch scenarios 031-052 all PASSED with 0 SCRIPT ERROR. No false failures.

## Counts (N1)
- Builder head 320e70c, imported twice: logic 5477/0, CHECK SCRIPT GATE 48 scripts 0 failed, 0 SCRIPT ERROR; scenarios 031-052 all PASSED, 0 SCRIPT ERROR (052: 9 ok).
- After R1: 5483/0 (+6 = T1-T6), 49 check scripts, 0 SCRIPT ERROR. T1 and T3 (setup) went red first; T1 red is the defect.
- Scratch merge with the harness PR: 5484/0 (+1 is the cafa probe already on #20).

## Decisions for Brandon
1. Activation economy: mode activations spend no action/Bonus Action (builder limit). SRD features of this shape usually cost a Bonus Action. Needs a card once real SRD mode content lands.
2. R1 refuses activation while Incapacitated for every activation rule, not only those with `end_on: incapacitated`. Reselect/switch of an already-active mode are not gated (they spend nothing). Confirm.
3. Merge order: #20 (+ harness PR) → #21 → #23.
