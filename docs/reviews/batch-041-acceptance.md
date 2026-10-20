# Batch 041 review: exclusive bonds (S-161) and equipment in forms (S-164)

Independent review by Runtime Reviewer on 2026-10-20 of PR #9 (`batch-041-s161-s164`). The head is `5ae1ba2` on 040 at `54968f1` (verified ancestor). Reviewer commits are `bd79621` (stress cases), `172fbcc` (R1–R4 and scenario) and `f0724e6` (builder check aligned with R1).

**Recommendation: ACCEPT S-161 and S-164 after R1–R4.** F1 (no HUD equipment chooser) is a known limit shared with 040 F2, not a blocker. This is reviewer evidence; counts change only on owner acceptance.

## Findings

| # | Severity | Finding | Status |
|---|---|---|---|
| R1 | Defect (refusal after cost) | The equipment-policy refusals (several policies with no choice, or a choice on a projection that declares none) happened inside the effect, after the slot was paid. RZ1/RZ2 left the slot at 0. The builder scenario's HUD cast "changed nothing" but spent the slot; asserted, it fails on `5ae1ba2`. | Fixed: `ActorProjectionRules.cast_error` (resolver and HUD validation, from 040 R1) now carries the equipment refusals. The scenario and the builder check assert the slot is unspent. |
| R2 | Defect (merged suppression leak) | Enumerated item effect paths over equipped copies: `SourceBenefitRules.query` (covered), `has_equipped_attuned_item` and ring of protection (covered), `SpellPermissionRules` (two loops; **not covered**), `CastInterruptionRules.is_recipient_negated` item `incoming_negation_rule` (**not covered**). A merged charge ring still granted its spell permission and charges (RZ3, 1/1/1), and a merged negation talisman still negated spells (RZ4). | Fixed: both paths skip merged copies; `worn` keeps them (RZ4). Item charges are reached only through those permissions, so they are covered. |
| R3 | Defect (S-161 × S-163) | `BondRules.prune` treated a bond whose rule is missing from the live `features` as unowned. An S-163 projection that suppresses features therefore **ended every bond**, on the next `bonded()` query or save, and reversion did not bring them back (RZ6: during=[], after=[]). That breaks "bonds end only when the exact target is no longer owned". | Fixed: a bond whose source feature is not live is kept. Saves still require the class to declare it (`saved_error`). |
| R4 | Hardening (weak spot 3) | Production callers of legacy `equip(slot, id)`: `ui/fighter_training.gd` (backpack id, so it routes through `equip_instance` and was already blocked) and `add_starting_equipment` (unowned, at creation only). No load, loot, companion or HUD path uses it; load restores `copies` directly. No production caller could don in a form, but the `allow_unowned` branch bypassed the guard. | `equip()` now refuses in a merged or dropped form too (RZ5) |
| F1 | Known limit (weak spot 2) | There is no HUD equipment-policy chooser, so multi-policy projections are uncastable in play; they are now refused before cost. The finish line says "Choose legal equipment policy". The choice exists and is enforced as a cast decision, and single-policy content is automatic. This is the same gap as the 040 F2 form choice. | Recommend one shared cast-decision chooser card for both |
| F2 | Known limit | HUD weapon attacks in any form still use the equipped weapon (the S-163 form attack is a profile only), so a merged weapon can still be swung. Carried tools count toward tool bonuses (backpack plus equipped). | Carry with the 040 form-attack limit |
| F3 | Checked (weak spot 1) | The scenario cleared its bond before saving. It now recruits a fixture-class companion, bonds a dagger copy, and does a real in-session `SaveManager` save and load: the loaded companion is a new object holding the same bond on the same copy. | OK |
| N1 | Checked | Full logic on `5ae1ba2` is 5139/0 = 5106 + 33. After review it is 5147/0 = 5139 + 8. 0 `SCRIPT ERROR`; all 75 group lines run. 040 RY1–RY8 and 039 RX are green. | OK |

## Stress cases (`Batch041Checks.review_stress`, 8 assertions)

- **RZ1/RZ2:** equipment-policy refusals come before cost (failed before R1).
- **RZ3/RZ4:** merged spell permissions and negation are suppressed, worn keeps them, and reversion restores them (failed before R2).
- **RZ5:** legacy `equip` (owned and unowned) is refused in a dropped form.
- **RZ6:** a feature-suppressing projection keeps a bond through query, save and reversion (failed before R3).
- **RZ7:** a copy unequipped by the dropped policy stays owned and bonded.
- **RZ8:** reversion does not re-equip; the copy can be donned again.

## Runs on `172fbcc` (logic re-run on `f0724e6`)

| Run | Result |
|---|---|
| import | 0 |
| logic | 5147 passed, 0 failed, 0 SCRIPT ERROR |
| 021 / 029 / 031 / 032 / 033 / 034 / 035 / 036 / 037 / 038 / 039 / 040 / 041 | 21 / 37 / 25 / 33 / 70 / 10 / 9 / 7 / 11 / 7 / 10 / 13 / 11 ok, 0 failed |
| shared_spell_flow | 67 ok, 0 failed |
| downed_area_damage_flow / party_recovery_flow | 1 / 2 failures, identical to main |

## Proposed registry change (on owner acceptance)

- S-161 becomes `Verified (VS-127; exclusive exact-copy/actor bond)`, P6 (+1).
- S-164 becomes `Verified (VS-128; merged/worn/dropped equipment in forms)`, P6 (+1).
- Counts follow 040's outcome: **+2** on top of it (128/226 if 040 is fully accepted).
