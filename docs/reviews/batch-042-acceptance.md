# Batch 042 review: linked-copy group fate (S-162) and exact item copy projection (S-165)

Independent review by Runtime Reviewer on 2026-10-20 of PR #10 (`batch-042-s162-s165`). The restacked head is `9ce9e5a` on 041 at `780c538` (verified ancestor). Reviewer commits are `0ef937e` (stress cases) and `7719163` (R1 and scenario).

**Recommendation: ACCEPT S-162 and S-165 after R1, with the owner decisions in F1/F2.** F3 (loader item types) blocks real SRD content for this vocabulary and should get its own card. This is reviewer evidence; counts change only on owner acceptance.

## Findings

| # | Severity | Finding | Status |
|---|---|---|---|
| R1 | Defect | A projected item actor reduced to 0 HP stayed projected. `ItemProjectionRules.settle` existed but nothing called it, so the exact copy was stranded in `item_projections` (still not in the inventory) and was saved that way. RQ3 failed. In the scenario a dead same-named actor also stayed on the field and absorbed the next attack by name. | Fixed in `7719163`: `Character.to_dict` settles after sync, and `attach` settles and removes stale projected entities before placement. The scenario adds an actual lethal monster hit followed by placement: the copy returns and the actor leaves. |
| C1 | Checked | Rebase conflict in `BondRules.prune`: 041 R3 is kept exactly (`if rule.is_empty(): live = true`). Item targets use `held()` (inventory or projected), and a suppressed rule never triggers `dispose_group` (RQ1). The 5de2a74/9ce9e5a rule (`ItemProjectionRules.project` refuses in an equipment-blocking form before any copy moves) is first in `project` after the duplicate check, ahead of every inventory call, and the builder check covers it. 041 RZ1–RZ8 are green. | OK |
| F1 | Owner decision (S-162 semantics) | `on_loss: dispose_group` treats **any** copy leaving the holder as loss: dropping, giving to a party member (RQ8), putting it in a container, placing it, or selling it (`take_instance` callers in `local_room_rules` and `shop`). The mates are destroyed and the moved copy survives. The finish line says "dispose ... deliberately". Stashing a copy in a chest is arguably not deliberate disposal. | Decide: keep as declared loss semantics, or narrow disposal to destruction/drop |
| F2 | Scope (weak spot 2) | Neither finish line mentions expiry or duration, so no timed expiry is not a miss. S-165's "temporary" form ends by `revert` or at 0 HP (after R1). Item projection has no source spell, so no concentration end path applies. Dismissal is `revert`, which has no production caller yet: `project`, `revert`, `attach` and `bond` are API and scenario only, like 041's bond queries. S-165 says "actor/**vessel**": only actors are modeled, which is the same scope pattern as 040 F1. | Narrow S-165 to actor projection (vessel to a later slice), or hold |
| F3 | Content blocker (weak spot 3) | The DataLoader item-type whitelist (`data_loader.gd:469`) is weapon/armor/shield/ring/wand/consumable/tool/currency/spell_component: no `wondrous`, `staff` or `rod`. SRD 5.2.1 Figurines of Wondrous Power, the natural S-165 content, are Wondrous Items. Real content would have to be typed `tool`, which gives tool semantics (tool checks at `data_loader.gd:599/1736`, `Inventory.skill_tool_bonus`). The fixtures use `tool`, so this vocabulary cannot carry real content honestly. | Flagged; not changed here (content editor untouched). Needs a loader item-type card |
| F4 | Known limit | Projected actors are named "<template> projected", so two copies of one item give identical names, and monster attacks target by name. | Carry with the HUD/command slice |
| F5 | Checked (weak spot 1) | The scenario now recruits a fixture-class companion, bonds two linked daggers, and does a real in-session `SaveManager` save and load. The loaded companion keeps the same bond, and a loss after the reload disposes exactly its mate. | OK |
| N1 | Checked | Full logic on `9ce9e5a` is 5174/0 = 5147 + 27. After review it is 5182/0 = 5174 + 8. 0 `SCRIPT ERROR`; all 75 group lines run. RX, RY and RZ are green. | OK |

## Stress cases (`Batch042Checks.review_stress`, 8 assertions)

- **RQ1:** a projection that suppresses features keeps the linked bond and disposes nothing (041 R3 after the rebase).
- **RQ2:** disposal affects only linked identities; an unlinked same-definition copy survives.
- **RQ3:** a destroyed projected actor returns its copy by the next save (failed before R1).
- **RQ4:** a projected copy cannot be taken, given or projected twice.
- **RQ5:** projecting and reverting a bonded copy keeps the bond and exactly one copy.
- **RQ6:** destroy-on-replace destroys exactly the released oldest copy.
- **RQ7:** reload keeps the bond on a projected copy, with no duplicate.
- **RQ8:** giving one linked copy away disposes its mate (F1 semantics, pinned).

## Runs on `7719163`

| Run | Result |
|---|---|
| import | 0 |
| logic | 5182 passed, 0 failed, 0 SCRIPT ERROR |
| 021 / 029 / 031 / 032 / 033 / 034 / 035 / 036 / 037 / 038 / 039 / 040 / 041 / 042 | 21 / 37 / 25 / 33 / 70 / 10 / 9 / 7 / 11 / 7 / 10 / 13 / 11 / 9 ok, 0 failed |
| shared_spell_flow | 67 ok, 0 failed |
| downed_area_damage_flow / party_recovery_flow | 1 / 2 failures, identical to main |

## Proposed registry change (on owner acceptance)

- S-162 becomes `Verified (VS-129; linked-copy replacement/group fate)`, P6 (+1).
- S-165, if narrowed, becomes `Verified (VS-130; exact item copy projects into actor)`, P6 (+1), plus a new slice for vessel projection.
- Counts: +2 on top of 040/041's outcomes.
