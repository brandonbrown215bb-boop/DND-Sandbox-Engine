# Batch 040 review: aftermath successor (S-120) and reversible actor projection (S-163)

Independent review by Runtime Reviewer on 2026-10-20 of PR #8 (`batch-040-s120-s163`). The head is `ed251b3` on 039 at `087f382` (verified ancestor). Reviewer commits are `e7d8bbe` (stress cases) and `eb1f830` (R1/R2).

**Recommendation: S-163 ACCEPT after R1. S-120 ACCEPT after R2 only if the owner narrows its finish line to actor successors (F1); otherwise hold.** This is reviewer evidence; counts change only on owner acceptance.

## Findings

| # | Severity | Finding | Status |
|---|---|---|---|
| R1 | Defect (refusal after cost) | `ActorProjectionRules.apply` refused only inside the effect, after `SpellResolver` spent the slot (and, in combat, after the cast pipeline replaced concentration). A multi-form cast with no selection and a second projection while one is active each **spent the slot and did nothing**. RY1/RY2 failed (slot 0). The builder's scenario cast the two-form spell and never checked the slot; with the slot asserted it failed on `ed251b3`. | Fixed in `eb1f830`. `ActorProjectionRules.cast_error` (same refusals: another projection, Wild Shape, missing form) runs in `SpellResolver` before payment and in `SpellCastValidation.validate_actor` before the HUD pipeline. The scenario now asserts the slot is unspent. |
| R2 | Defect | Successor cache for creature-record hosts keyed the instance on `hash(corpse_id)` = `creature:<id>`. Monster ids are `monster_%d` per encounter, so the next encounter's `monster_0` dying to the same carrier got the **earlier encounter's destroyed successor** (RY4: hp 0, not placed). | Fixed in `eb1f830`: a new settlement drops cached actors for the new record's ids. Character hosts still rebuild on host change (RY5). |
| F1 | Finish-line gap (owner decision) | S-120's finish line is "Create the declared **actor/object/hazard** ... with exclusions and retained/disposed gear as specified". Only actors are modeled. Gear only follows S-119's policy. Placement covers party-side sources only, and policies carried by monster attack dictionaries are refused. The actor path meets the finish line: real-cast creation once, at the actual hex, with exclusions, identity, revival refusal and save/reload. Object/hazard successors are missing. | Narrow S-120 to actor successors and file object/hazard successors as a new slice, or hold S-120 |
| F2 | Known limit | S-163 form selection exists only as the cast decision `_projection_form_id`. No HUD path offers it, so multi-form content is uncastable in play (it is now refused before cost). Single-form projection works end to end. | Carry to a form-choice UI (S-155-style) |
| F3 | Known limit (checked) | Wild Shape: `DruidRules` is untouched (parked Q-20260810-010133-85ce). A projection is refused while shaped, before cost (RY3; the existing beast-form casting block already stopped it, and R1 adds an explicit check). A saved actor holding both is refused. This is a documented exclusion, not a finish-line miss: S-163's finish line is the shared projection, and Wild Shape migration is the parked card's job. | OK |
| F4 | Checked | 039 R1 survived the `instance()` refactor and rebase. RX1/RX2 pass, RY6 mirrors them on the 040 head, and successor hosts rebuild on host change across a real in-session `SaveManager` load with no cache clear (scenario, RY5). | OK |
| N1 | Checked | The builder reran only the combat group after the hex fix. A full logic run on `ed251b3` gives 5098/0 = 5061 + 37. After review it is 5106/0 = 5098 + 8. 0 `SCRIPT ERROR` in every run; 75 group lines are identical before and after. | OK |

## Stress cases (`Batch040Checks.review_stress`, 8 assertions)

- **RY1–RY3:** no form selection, a second projection, and Wild Shape are each refused before the slot is spent (RY1/RY2 failed before R1).
- **RY4:** a same-id creature in a later encounter gets a fresh successor (failed before R2).
- **RY5:** a reloaded Character host rebuilds its successor at the saved HP.
- **RY6:** the 039 R1 created-actor rebuild still holds.
- **RY7:** `SpellEffects.remove` reverts once; a repeated removal is a no-op.
- **RY8:** a refused projection leaves no source record.

## Runs on `eb1f830`

| Run | Result |
|---|---|
| import | 0 |
| logic | 5106 passed, 0 failed, 0 SCRIPT ERROR |
| 021 / 029 / 031 / 032 / 033 / 034 / 035 / 036 / 037 / 038 / 039 / 040 | 21 / 37 / 25 / 33 / 70 / 10 / 9 / 7 / 11 / 7 / 10 / 13 ok, 0 failed |
| shared_spell_flow | 67 ok, 0 failed |
| downed_area_damage_flow / party_recovery_flow | 1 / 2 failures, identical to main |

## Proposed registry change (on owner acceptance)

- S-163 becomes `Verified (VS-125; reversible retained-stat projection, single selectable form per cast)`, P6 (+1).
- S-120: if narrowed, `Verified (VS-126; aftermath successor actor)`, P4 (+1), plus a new Planned slice for object/hazard successors. Otherwise S-120 stays Planned.
- Counts: **126/226** if both are accepted, **125/226** if S-120 is held.
