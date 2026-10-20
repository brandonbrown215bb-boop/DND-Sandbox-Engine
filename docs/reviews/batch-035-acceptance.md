# Batch 035 review: source-owned maximum HP (S-130) and scoped attack/cast profiles (S-126)

Independent review by Runtime Reviewer on 2026-10-20. PR #2 (`batch-035-s130-s126`), head `7c559c8`, base `e3efcad`. Reviewed in an isolated worktree with reviewer commits `d071dcf` (stress cases), `6a15b52` (R1) and `da24891` (R2).

**Recommendation: ACCEPT after R1 and R2.** This is reviewer evidence. Counts change only on owner acceptance.

## Findings

| # | Severity | Finding | Status |
|---|---|---|---|
| R1 | **Defect (blocking)** | S-130 removal reverted each source's *stored* applied delta against the current maximum. When a later source was floor-clamped, removals drifted. In ST2 (max 10, +5 increase, then a 20 reduction clamped to 1), removing both left **max 15, a permanent +5 HP**. In ST1 (10, then -8 and -5 clamped to -1), removing the first left 9 instead of 5. This breaks the finish line "equivalent sources cannot revoke one another / exact revert". Both cases failed on `7c559c8`. | Fixed in `6a15b52`. Applied deltas are now re-derived from the natural base (max minus the net of all sources) on every apply, remove and periodic event. Increases apply in full. Reductions apply in ownership order up to the strictest declared floor. The DTO shape is unchanged. |
| R2 | Test weakness | The scenario's no-profile control asserted only `hp == 500` against a slashing-immune target. An attack command that never fired or missed would also pass, so the control proved nothing. | Fixed in `da24891`. A positive control shows the same unprofiled command lands (500 to 494). A negative control shows the profiled attack is fully stopped by fire immunity, so its type is exactly `fire`. |
| N1 | Harness note (not fixed) | A parse error in a checks file dropped that group but the logic run still reported `0 failed`, because the group's checks simply didn't run. Builders should compare assertion counts and grep for `SCRIPT ERROR`. | Out of scope; recommend a separate card. |

## Stress cases (`Batch035Checks.review_stress`, 22 assertions)

ST1 stacked reductions under the floor, then removal order. ST2 increase plus an over-floor reduction, removed in both orders (drift). ST3 a `raise_current` increase, smaller non-accumulating re-apply (no stack/shrink), and removal clamping current HP. ST4 an increase does not revive a 0-HP actor. ST5 refusal before cost: an Aura-protected reduction and a malformed amount create no entry and change nothing. ST6 a legacy DTO without `max_hp_sources` validates and restores the natural max; a contradictory increase DTO is refused. ST7 a reload with clamped sources reverts exactly. ST8 periodic growth stops at the floor, and a Long Rest cure restores the exact natural max. ST9 a profile is owner-scoped and does not mutate the catalog longsword.

## Verified

- ADR-0018: there are two shared modules and no content-ID branching. Consumers only copy or route declared data. `tools/content_editor/` was not touched.
- S-126: first-source replacement and summed additive bonuses, with unnamed fields inherited. An unoffered type choice is ignored, condition gating applies, and the spell DC is school-scoped. `_save_dc_override` still has the final say. The catalog is unchanged.
- Legacy saves: the field is optional, and both SaveManager DTO routes validate before replacing live state.

## Evidence (Godot 4.7.2)

| Run | `7c559c8` | + review commits |
|---|---|---|
| Import | exit 0 | exit 0 |
| Logic suite | 4834 / 0 | **4854 / 0** (stress ST1 and ST2 fail before R1: 4852 / 2) |
| batch_035_profile_max_hp_flow | 7 / 0 | **9 / 0** |
| batch_034 / 033 / 032 / 031 / shared_spell | 10 / 70 / 33 / 25 / 67, 0 failed | same |
| downed_area_damage_flow | 1 failed | 1 failed, identical to clean `origin/main` |
| party_recovery_flow | 2 failed | 2 failed, identical to clean `origin/main` |

## Proposed updates on owner acceptance (after Batch 034 = VS-113/114)

- Registry: S-130 becomes `Verified (VS-115; source-owned max-HP deltas, monster-rider consumer)` and S-126 becomes `Verified (VS-116; weapon fields and spell save DC)`.
- Counts: **116/226 accepted, 110 remain**. P4 goes from 15/25 to **17/25** (S-126 and S-130 are both P4).
- Update the roadmap.md and docs/operations/current.md checkpoints to match.
- Subsets and limits: S-130 has no class/spell/item acquisition wiring and no Dictionary creatures; `reduce_max_hp` is not migrated; S-131 is not covered. S-126 has no spell attack bonus, range or components, and no type picker UI. V-024 and V-095 remain partial.
