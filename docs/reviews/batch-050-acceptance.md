# Batch 050 acceptance (card Q-20261021-004820-e92f, PR #19)

**Verdict: ACCEPT after R1.** Reviewer: runtime-reviewer, worktree /tmp/rev_wt050, base 1daa946 -> builder head cf9dd29 -> review head (this commit).

## Bugs: do the regressions really reproduce?
I reverted each production fix on its own at cf9dd29 and ran `batch_050_playtest_fixes_flow`:
| Bug | Mutation (back to 1daa946 behavior) | Scenario result |
|---|---|---|
| 1 drop recharged | `inventory.gd` from 1daa946 (no `stamp_copy`) | FAIL "050 actual bug 1" |
| 2 suppressed power survived incapacitation | `end()` reads `rule()` again | FAIL "050 actual bug 2" |
| 3 second identical copy ignored | per-definition `seen["def:"]` skip restored | FAIL "050 actual bug 3" (+ SCRIPT ERROR on the missing pool) |
| 4 typo feat silent | single-file `missing_feat_error` removed | FAIL "050 actual bug 4" (errors `[]`) |
Each passes on cf9dd29. The scenario reproduces rather than masks.

## Rewritten 049 check
The old "two copies never stack" check now asserts that each copy owns its features once. That matches the card's bug 3 and SRD 5.2.1. "Multiple Items of the Same Kind" restricts only worn categories: footwear, gloves, bracers, armor, headwear and cloaks. Two daggers are not restricted. Uses are per copy; the item's uses belong to the item (p.206). Benefits are deduplicated in `FeatureModeRules.carriers` by definition|power, so two blades give +1 AC, not +2. Each copy still goes through `copy_active`, so 049 R1 (merged/suppressed) holds. Pools are stamped per copy, so 049 R2 (uses travel with a given copy) holds; stress S2 below covers it.

## SRD
- p.206 "The Next Dawn" is **correct**: PDF page 206, "Magic items often have charges or properties that recharge at the next dawn or some other specified time." No off-by-one this time.

## Defects
- **R1: a dawn during suppression or a merge permanently lost upgraded uses.** `recover_dawn` refilled to `get_feature_max_uses`. That path goes through `upgrades_for`, which is now gated by `copy_active`. A Deep Ward blade (max 3) refilled to 2 while suppressed or merged, and kept only 2 after the gate lifted. For the same reason, `owned_rule` was not actually the owned rule: an upgrade that adds or removes `end_on` was ignored while the copy was suppressed. That contradicts the build doc's bug 2 claim. Fix: `RuleUpgradeRules.owned_view(fn)` counts inactive copies' upgrades. It is used only by `owned_rule` (end predicates) and the dawn maximum. Activation and benefits stay gated. Stress S3 and S4 failed before the fix (dawn=2) and pass after it.

## Checklist
- No per-ID branches in the diff (data-driven `uses_per: dawn`, rejected for species and feats).
- Refusal before cost: suppressed activation is refused with the pool unchanged (builder's check; 049 refusals still hold).
- Nested `state.rule_alternatives` and `feature_uses` go through `InventoryCopies.record_state_error` -> `OwnedFeatureSources.record_error`; a forged foreign option is refused.
- Legacy saves: the unstamped legacy fixtures pass.

## Stress (src/review_050_checks.gd, +4)
- S1: spent uses survive a JSON save/load; dawn refills to the upgraded 3; three dawns never exceed 3.
- S2: a spent blade given away recharges at the new holder's dawn (carried, unworn), and its record stays valid.
- S3: suppression keeps the pool at 3; a dawn while suppressed refills to 3 (failed before R1).
- S4: a dawn while merged into a form refills to 3 (failed before R1).
- Real campaign-time dawn across a real save/load is already in the 050 scenario.

## Evidence (Godot 4.7.2, one run at a time)
- `--import` clean. Logic on cf9dd29: **5427/0** (confirmed). Review head: **5431/0** (+4 R050). 0 SCRIPT ERROR.
- Scenarios 031-050 and shared_spell_flow: ok counts match the build table exactly (050: 8; shared 67), 0 FAIL, 0 SCRIPT ERROR. Re-ran 037, 038, 041, 049 and 050 after R1: all pass.
- N1: a parse error in a new check file still printed "RESULTS: 5427 passed, 0 failed / ALL TESTS PASSED". Q-20261020-122658-cafa is still open and real.

## Count updates
None. This is a fix batch with no new vocabulary slices; counts stay as proposed in 047-049.

## Current boundary after the final review

The owner already chose separate pools and item-side dawn recovery. There is
no additional owner confirmation after successful review, repair and merge.
The later fix reaches rooms, containers and attached children; equipped and
attuned conditions are separate. The final Rook review repairs and checks are
recorded in [the existing build note](batch-050-build.md#rooks-final-review-corrections).
The 047 chooser-before-validate_actor note and mid-combat dropped-item dawn
limit remain open, alongside the separately tracked feat, HUD and volume work.
