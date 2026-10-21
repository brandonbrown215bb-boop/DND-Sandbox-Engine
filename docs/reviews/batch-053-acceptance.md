# Batch 053 acceptance: S-121/S-122 legal placement (PR #25)

Reviewer: runtime-reviewer. Reviewed head 4d1bdbc on main 31db360. Card Q-20261021-040420-1903.

## Verdict: ACCEPT (no defects found)

## Finish line, checked against the real control path
- Successful placement, blocked placement, Cancel, stale popups (superseded and after the turn ended), the confirmation recheck, and two creatures in distinct cells are all exercised through the HUD popup in scenario 053. Each refusal leaves the slots unchanged, and the two-creature cast pays one slot.
- Refusal before cost: `choose_placement` is the last step of `validate_and_choose`, before payment. `refuse` with no space spends nothing. `spend` pays once and creates nothing, as authored.
- Legality goes through `PhysicalFactsRules.is_space_available`, which checks tile, walls, blocking, plane, clearance by size and living occupants, plus range and reservation. Fallback is the nearest legal cell in the authored range, so the actor never overlaps or is put outside range. When `choose` is false this is a reasonable stand-in for "an unoccupied space you choose within range".
- No per-ID branches. The policy is authored on `create_actor.placement` and validated by the loader.
- Legacy saves: no new saved field, and an unauthored policy takes the default. The real save/load keeps the wardens, and `_placement` is not serialized.
- Scenario 039 edit: legitimate. The cast now attaches the warden, and the assertion is stricter (present exactly once, not re-added).
- Reviewer probe added to scenario 053: transient picks never leak onto the catalog spell dictionary (`DataLoader.get_spell` returns a reference). It passes.

## Totals (N1)
- Imported twice. Logic: 5508 passed, 0 failed, 50 check scripts, 0 SCRIPT ERROR. This matches the build doc.
- Scenarios 031-053 run one at a time: 23/23 SCENARIO PASSED, 0 SCRIPT ERROR. 053 has 12 ok (11 plus 1 reviewer probe).

## S-121 ruling
Exit-before-settle (engulf/swallow escape) is not built. The finish line only asks for creation/arrival placement, so this does not block acceptance. **S-121 must not be counted as done.** vocabulary-slices.md still lists S-121 and S-122 as Planned, which is correct for S-121. Mark S-122 verified when this merges; S-121 stays Planned, or at most partial: arrival half only. Recommend a follow-up card for the S-121 exit half.

## Limits carried
Single-cell footprints only. Item projections have no picker or authored range. Placement only applies in combat.
