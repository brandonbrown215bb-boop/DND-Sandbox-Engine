# Batch 083 acceptance review (PR #56, S-162, #47 follow-up)

Verdict: ACCEPT (PARTIAL). Judged against Brandon's ruling as quoted by the builder.

- Diff d5bf285..945d5cb: docs, quest card, batch_083_checks.gd and its test_runner hook only. No game code changed and no `consume` cause exists in src. Consumption sites pass "destruction" (eee958b; inventory.gd:787, local_room_shared_spells.gd:114, batch_075 `_consumption` check).
- R1 (docs): vocabulary-slices.md line 325 ("Linked-copy loss reasons" row) still said "attach/consume/fuel removals carry no cause". Fixed to match: only attach has no cause, consumption passes `destruction`, and a consume cause is deferred.
- Dice: dice.gd:90 (`maximum_dice_string`) and :140 (`parse_dice_details`) both `replace(" ", "")`, so they remove every space, not just trim the ends. Builder's claim holds. The builder's rolling check only asserted 12..144, which a misread flat "12" also satisfies. Added two review checks that inspect dice_terms: "12 d12" rolls 12d12, and "2 d8 + 4" rolls 2d8 with total = dice + 4.
- Runs: import x2 clean; logic 6338/0 (+2 review checks over the builder's 6336); batch_075_linked_removal_flow and _reload PASS; no SCRIPT ERROR.

Proposed counts if accepted: logic 6338/0.
