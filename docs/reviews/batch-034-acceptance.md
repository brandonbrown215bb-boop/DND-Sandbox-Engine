# Batch 034 review: zero-HP aftermath (S-093, S-119)

Independent review by Runtime Reviewer, 2026-10-20, PR #1 (`batch-034-s093-s119`),
reviewed head `6454625`, plus reviewer repair `cc04662`.

**Recommendation: ACCEPT after repair R1.** This is reviewer evidence. Slice
counts change only on owner acceptance.

## Findings

| # | Severity | Finding | Status |
|---|---|---|---|
| R1 | Defect | S-119 `excluded_creature_types` read `type` on Dictionary creatures and `feature_uses.creature_type` on Characters. Live monster entities carry `creature_type` (CombatState spawn) and Characters carry `Character.creature_type`, so exclusions never fired in real combat. The fixture used raw `"type": "construct"`, which the unit check exercised directly and so passed. | Fixed in `cc04662`: reads `creature_type` (falls back to `type`), Character property (feature_uses override kept for steeds). Fixture now uses `creature_type`. Two regression checks added (live Dictionary and Character). |

No other defects found.

## Verified against finish lines and ADRs

- S-093: the first eligible `death_save_outcome` rule settles before any d20, advantage,
  roll-token, Bardic Inspiration or Stroke of Luck step, and CombatState offers no bonus
  prompt. `cancel` moves no counter. success/failure/stabilize reuse existing
  stabilization and `death_saves` death. Stateless, so no save field was added.
- S-119: the policy settles once after ordinary HP settlement, only for a living target going
  from >0 to 0 HP. The `hp_loss` receipt stays separate. The original actor/corpse identity
  is kept, and `cause_source` records the policy, source and damage type for revival. Dust
  and destroyed remains are refused by the existing `CorpseRules.target_error`.
- ADR-0018: there is one shared module and no content-ID branching. The carriers (shared
  spell field, weapon/monster attack) only copy the declared policy.
- Refusal before cost: malformed rules and policies are refused at load
  (`_sanitize_class_features`, `_validate_semantics`, including monster attacks), and
  runtime `policy_from` ignores invalid input. No payment is involved.
- Legacy saves: `cause_source` is optional. Absent means it loads. Present means it is validated,
  including whether destruction matches destroyed remains.
- SRD 5.2.1: 0 HP from an instant-death effect skips Death Saves. Massive damage in the same
  occurrence takes the declared cause without a second death serial. Native Death Ward still
  comes first, and `precedes_zero_hp_replacement` bypasses Relentless Rage only when declared.

## Evidence (Godot 4.7.2, isolated worktree)

| Run | PR head + R1 |
|---|---|
| Import | exit 0 |
| Logic suite | **4792 passed, 0 failed** (builder 4790 + 2 R1 regressions) |
| batch_034_aftermath_flow / 033 / 032 / 031 / shared_spell_flow | all pass, 0 failed |
| downed_area_damage_flow | 1 failed: identical assertion on clean `origin/main` |
| party_recovery_flow | 2 failed: identical two assertions on clean `origin/main` |

The baseline claim holds. Both failure lists diff empty against `origin/main`. These
failures pre-date Batch 034 and need their own card.

## Proposed updates on owner acceptance

- Registry: S-093 becomes `Verified (VS-113)` and S-119 becomes `Verified (VS-114)`.
- Counts: **114/226 accepted; 112 remain**. P4 goes from 13/25 to **15/25**.
- Update the checkpoint in roadmap.md and docs/operations/current.md to match.
- Checklist subsets: S-093 covers loaded class features on Characters only. S-119 covers
  shared spells, weapon attacks and monster attacks. V-013/V-021 remain partial, and S-120
  (successor actor) is not covered.
