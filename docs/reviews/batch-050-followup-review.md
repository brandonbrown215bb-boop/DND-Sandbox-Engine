# Batch 050 follow-up post-merge review (9453530 / a5d56c6 / a495177, merged in ab7b773)

**Verdict: ACCEPT after R1.** Reviewer: runtime-reviewer, worktree /tmp/rev_wt050f, base main ab99926. Fix branch `review-a5d56c6`.

Scope note: a5d56c6 itself only edits the quest card. The code is 9453530 (dawn anywhere, `recharge_while`) plus a495177 (owned capacity through refresh, reload and rests; attached children; equipped vs attuned). I reviewed all three.

## Totals (N1)
- The builder reported 5437/0 for 9453530. Main ab99926 (with a495177) gives **5449/0** on Linux. That is the right base; 5437 is stale.
- Review head: **5461/0** (+12 R050F). 0 SCRIPT ERROR. `run_tests.sh` exits 0 when green.
- Scenarios 042, 049 and 050 pass after R1 (10/9/12 ok, 0 FAIL, 0 SCRIPT ERROR).

## Defect
- **R1: dawn skipped item copies projected into an actor (S-165).** `recover_dawn` walked only `inventory.copies.records`. A projected copy lives in `actor.item_projections[id].copy` and was never refilled. A spent dawn blade animated over a dawn stayed at 1, and kept 1 when it reverted. That contradicts "wherever the copy is". Fix: `recover_dawn` also runs `recover_dawn_records` over each projection's copy, including its nested contents. Probe F3 failed before the fix (got 1) and passes after it.

## Verified (src/review_050f_checks.gd)
- **050 R1 owned_view is intact.** Review050 S3/S4 still pass, and a495177 extends owned capacity to sync, reload and rests (S5, S8).
- **F1, through the real `GameManager.advance_campaign_time`, not direct calls:**
  - a copy in the party pack recharges;
  - a copy in an unloaded dungeon snapshot room refills to its remembered Deep max 3;
  - a copy inside a backpack lying in an unloaded room recharges.
- **No double recharge.** The same room reachable as both the live room and `transition_context.local_room` ends at max 2, never higher. Refill is set-to-max, so reaching a copy twice is idempotent by construction.
- **F2, save/load.** A room stamp survives a JSON round trip. A pickup honours it (3), and a character reload keeps 3 uses and the option.
- **F4, loader.** These `recharge_while` values are refused: `["equipped"]`, `1`, `""`, `"Equipped"`, and the field on a long-rest power or a rest choice.
- No per-ID branches.

## Known limits (not fixed here)
- **Room records are not validated at save load.** Only duplicate ownership is checked (`InventoryCopies`, rooms loop); this predates 050. A forged stamp is clamped to the copy maximum on pickup by `sync`, so it is bounded.
- **Only `PartyManager.characters` get dawn.** Actors outside the party roster (if any ever hold copies) are not walked.
- `copy_max` counts only the item's own upgrades. That is correct for an unheld copy.

## Windows integration with current main — 2026-10-21

Integrated after PRs #25–37 without changing the production fix. A focused
independent review found no breaking issue. Full Windows logic passed **5,685/0**;
the 042 projected-item, 049 owned-source and 050 playtest scenarios passed.
The strengthened 042 check advances the real campaign clock, saves through
SaveManager and reloads an injured projected actor with the same exact ID, 7 HP,
three recharged uses and its remembered Deep option. Reversion and re-equipping
preserve those uses and return exactly one copy. The first added assertion used
a backpack-only count after equipping; correcting it to count owned copies and
check the equipped ID passed. This was a test correction, not a runtime repair.
Raw logs remain in ignored `.artifacts/`; no catalog conversion or broader
projection controls are claimed.
