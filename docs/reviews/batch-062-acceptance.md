# Batch 062 acceptance: costed modes outside combat (PR #34)

Reviewer: Runtime Reviewer. Card Q-20261021-154157-efcb (claimed until 2026-10-22 10:58 CDT). Reviewed head 5a1e3c6, stacked on 793e90c.

Finish line (verbatim): Grok Bot: "Modes that cost an action can be activated outside combat." Brandon: "Yes."

## Verdict: ACCEPT, no product defects

## Verified
- Refusal before cost: cancel, stale token, superseded popup, changed actor, incapacitated, dead (new review check), no uses left all return before FeatureModeRules runs. Entering combat while the popup is open: answer() calls apply(), which re-runs cost_error at press time and refuses in_combat.
- Use charged once by FeatureModeRules.activate; no budget is touched (receipt carries cost_outside_combat, not cost). 10 mixed activate/reselect presses charge exactly one use (review check).
- No combat dodge: only LocalRoomModes constructs OutsideCombat; the combat HUD still passes its turn budget, and OutsideCombat refuses while GameState is COMBAT.
- Carry-over: same feature_modes record; combat offers reselect (pays the Action), not a second activate.
- Save/load: no new field; real save/load in the scenario; legacy undeclared-cost modes stay free.
- ADR-0018: no per-ID branches.

## Flake verdict: test-timing flake, not a 061 ordering race
- batch_056_created_initiative_flow: 20/20 on 5a1e3c6, 20/20 on 793e90c, 15/15 after hardening. The order assertions never failed; only the "dead owner" turn-count did (only Hound 1 seen).
- Cause: _owner_round sampled active_combatant on a 20 ms timer. A declared-'none' hound turn does nothing and can begin and end between samples under load, so Hound 2 is not seen. Turn order itself was correct.
- Fix (06a573a): sample every process_frame with an 8 s wall-clock budget. Test-only.

## Review commits
- 06a573a flake hardening (above). 1ae0c67 two stress checks in batch_062_checks.

## Counts
- Logic: 5606 passed, 0 failed (5604 claimed + 2 review), 0 SCRIPT ERROR. Scenarios 031-062 one at a time: 32/32, 0 SCRIPT ERROR.

## Open decisions (Brandon)
- Should outside-combat use cost anything (e.g. a time tick) instead of being free of action economy? Today it is 0 seconds.
- The in_combat check keys off GameManager.current_state only; fine today, revisit if combat ever runs without that state.
