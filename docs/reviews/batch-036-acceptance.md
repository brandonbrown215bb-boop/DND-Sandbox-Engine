# Batch 036 review: source-end aftermath (S-086) and last-charge aftermath (S-060)

Independent review by Runtime Reviewer, 2026-10-20. This reviews PR #3 (`batch-036-s086-s060`). The original head was `c43b43b` on the stale base `7c559c8`. I rebased it onto `origin/batch-035-s130-s126` @ `22bee04`, which includes the 035 R1/R2 fixes, and it became `c3b0576` with no conflicts and authorship kept. Reviewer commits on top:
- `d99730d` adds the N1 harness card
- `e107817` adds the stress cases
- `b767252` is fix R1

**Recommendation: ACCEPT after R1.** This is reviewer evidence. Counts change only on owner acceptance.

## Findings

| # | Severity | Finding | Status |
|---|---|---|---|
| R1 | **Defect (blocking)** | S-060 settled only inside `Inventory.spend_instance_charges`, but the generic S-135 item-charge spell payment never called it. Both the action cast (`SpellCastResources.commit_spell_resource`) and the reaction cast (`SpellPermissionRules.spend_reaction`) changed `state.charges` directly. A catalog item with both `spell_permissions` and `last_charge_aftermath` would reach 0 charges on a real cast with **no aftermath**. The finish line says "after a real spend", so a boundary that no real data-driven spend reaches does not meet it. RS1 failed on `c3b0576` (charges 0, not degraded). | Fixed in `b767252`. Both payment sites now spend through the exact-copy boundary. A failed spend refuses the action cast before any cost, with a log line and pending state cleared; the reaction path returns `{}`. RS1 proves it on the real `spend_reaction` route with the fixture `fixture:b036_review_ring`. |
| W1 | Weak spot (builder-flagged) | The scenario still spends through the inventory API directly. The native Wand of Magic Missiles path is ID-branched and unconverted, which is acceptable because its own d20 destruction is unchanged and cannot double-settle. After R1, the generic production path exists and is covered at logic level (reaction route). The action-cast route is covered only by regressions (`batch_021` 21/0, `batch_029` 37/0, the same as before the fix). | Not reject-level after R1. A UI-driven item-charge cast in the 036 scenario would be the next strengthening. |
| (a) | Checked | The 034 `_is_magic` change makes a copy's own boolean `state.magical` take precedence. No production code writes `state.magical` except degradation, so legacy copies without the flag fall back to definition `magical`/`rarity` exactly as before (RS5). S-119 `destroyed_except_magic` now destroys a degraded rod and keeps a magic wand (RS6). The `batch_034` scenario is 10/0. S-093 is untouched. | OK |
| S-130 | Checked | 036 does not touch `MaxHpSourceRules`. The rebase had no conflicts. 035 logic (including the ST1–ST9 stress cases) and the 035 scenario (9/0) pass on the rebased stack. | No interaction |
| P | Correction to my 034 doc | S-093 is a **P3** slice, not P4. The 034 proposal "P4 15/25" should read P3 +1 and P4 +1. | Noted here |

## Stress cases (`Batch036Checks.review_stress`, 12 assertions)

- **RS1:** an equipped ring's real item-charge reaction payment takes the last charge and settles the declared degrade once.
- **RS2:** an empty copy offers no item-charge payment. A forced stale selection is refused before any cost: the reaction is kept and charges stay at 0.
- **RS3:** over-spend, zero and negative spends are refused and charges are unchanged. A non-final spend consumes an injected roll without settling.
- **RS4:** dawn recovery clamps at maximum. A destroyed copy cannot spend, and dawn recovery cannot bring it back.
- **RS5:** legacy copies without the flag keep definition-based magic, and a true flag still counts.
- **RS6:** S-119 dust with `destroyed_except_magic` destroys the degraded copy and keeps the magic wand.
- **RS7:** a duplicate S-086 removal does not fire the aftermath again.

SRD 5.2.1: the last-charge d20, destroyed on a 1, matches wand wording. A degraded copy no longer recovers, and recovery never exceeds `maximum_charges`.

## Check-group execution (N1)

Every log has 0 `SCRIPT ERROR` lines. All 41 `*Checks` classes are referenced by the runner or a parent group. The runner prints only failures, so there are no per-group pass counts. Totals reconcile exactly instead:
- 035 reviewed: 4854
- plus 036 builder checks: 28, giving 4882
- plus reviewer stress: 12, giving 4894

The 4893+1 pre-fix and 4894+0 post-fix totals are consistent. Card `Q-20261020-122658-cafa` tracks making the harness fail on a dropped group.

## Evidence (Godot 4.7.2, `/tmp/rev_wt036`)

| Run | Rebased `c3b0576` | + review commits |
|---|---|---|
| Import | exit 0 | exit 0 |
| Logic | 4882 / 0 | **4894 / 0** (4893 / 1 with stress before R1) |
| batch_036_end_and_charge_flow | 7 / 0 | 7 / 0 |
| batch_035_profile_max_hp_flow | 9 / 0 | 9 / 0 |
| batch_034 / 033 / 032 / 031 / shared_spell | 10 / 70 / 33 / 25 / 67, 0 failed | same |
| batch_029_interruption_flow / batch_021_spell_permissions_flow | 37 / 0, 21 / 0 | 37 / 0, 21 / 0 |
| downed_area_damage_flow | 1 failed | 1 failed, identical to clean `origin/main` |
| party_recovery_flow | 2 failed | 2 failed, identical to clean `origin/main` |

## Proposed updates on owner acceptance (after 034 → VS-113/114 and 035 → VS-115/116)

- Registry: S-086 becomes `Verified (VS-117; shared-spell source records)` and S-060 becomes `Verified (VS-118; exact-copy spend boundary incl. item-charge spell payments)`.
- Counts: **118/226 accepted, 108 remain**. Both slices are P2, so P2 rises by 2.
- Update the roadmap.md and docs/operations/current.md checkpoints to match.
- Limits:
  - S-086: shared-spell hosts only; no automatic death/destruction reasons; damage and condition follow-ups only.
  - S-060: `keep_properties` is recorded, not enforced; the Wand of Magic Missiles stays native.
  - V-043, V-056 and V-079 remain partial.
