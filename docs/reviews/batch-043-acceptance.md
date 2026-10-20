# Batch 043 review: exact container contents (S-196) and persistent curses (S-202)

Independent review by Runtime Reviewer on 2026-10-20 of PR #11 (`batch-043-s196-s202`). The head is `65e918c` on 042 at `1e055f0` (verified ancestor). Reviewer commits are `2bd3854` (stress cases, the reviewer pouch fixture and the post-load combat probe) and `7c7b19e` (R1–R3).

**Recommendation: ACCEPT S-196 and S-202 after R1–R3.** The post-load "hang" is a harness artifact. The real game path reaches combat. This is reviewer evidence; counts change only on owner acceptance.

## Findings

| # | Severity | Finding | Status |
|---|---|---|---|
| R1 | Defect (weak spot 3) | `ContainerRules.saved_error` checked only identity and limits for contained copies. Their item state skipped the per-copy rules that carried copies get (ration fraction, charges, degraded state, attunement shape, cursed flag), so a tampered save with a contained copy holding `food_remaining_daily_fraction: 7` or `charges: -5` passed both SaveManager paths and loaded corrupt state, which `Take out` then put back in the backpack (RC1). | Fixed: the per-copy checks moved into `InventoryCopies.record_state_error`, which is used for carried and contained copies. |
| R2 | Defect (weak spot 1, SRD) | Attuned copies could not be stowed. SRD 5.2.1 ends attunement only through its own rules (no longer meeting prerequisites, 24 hours at 100+ ft, death, or a Short Rest to end it voluntarily). Putting a ring in a bag does not end it. Lifting the refusal naively would have hidden the copy from the three-item count. | Fixed: uncursed attuned copies stow and stay attuned. `attune_instance` and the saved check count contained attunements, including the Ring of Protection duplicate (RC3/RC4). Cursed copies stay refused (RC6), which matches the curse rules. **Bonded** copies stay refused: a limit pending your decision on 042 F1 (container triggers), not a finish-line miss, since S-196's finish line covers category and limits, not bonds. |
| R3 | Defect (weak spot 2, SRD) | `destroy_instance` on a container erased its record, so every contained copy vanished, magic items included. Ordinary containers do not destroy their contents. Even SRD Disintegrate spares magic items. | Fixed: destroying a container spills its exact child copies back to the holder. Anything that does not fit stays in the returned record. The Bag of Holding (contents to the Astral Plane) is not modeled; it would be declared behavior on that item later. |
| C1 | Checked (weak spot 4) | Reproduced the harness hang: after `SaveManager.load_game` (not test mode), `GameManager.change_state` replaces the current scene, which is the harness itself. The harness coroutine then never resumes, and the scenario times out (exit 124). The real path is fine. The scenario now detaches the harness as current scene before loading, lets the real load bring up Overworld, then calls `GameManager.change_state(COMBAT, ...)`. The Combat scene reaches a player turn with the loaded party. | Not a game defect; the scenario keeps the real-path probe |
| C2 | Checked (Remove Curse) | SRD 5.2.1 Remove Curse (data/core text): "all curses affecting one creature or object end. If the object is a cursed magic item, its curse remains, but the spell breaks its owner's attunement…". It has **no higher-level effect**. The slot-4 requirement is **not sourced**: it exists only as fixture data (`fixture:b043_hex_blade`, `break.min_slot_level: 4`), and no core item declares a `curse` policy. The vocabulary (exact break spell and minimum slot) is legitimate for content that declares it. Undeclared SRD cursed items such as the Sword of Vengeance keep the SRD route: a 3rd-level cast breaks attunement (RC7). Breaking clears attunement and the copy re-curses on re-attunement, which matches "its curse remains". | OK; any real content using `min_slot_level` must cite its source |
| F1 | Known limit | Core SRD gear has no `weight` or `volume` (for example, `rations`), so compartments that declare `max_weight` or `max_volume` refuse all core gear. Only count- or type-limited compartments take real items. | Card with the F3 loader item-type work |
| F2 | Known limit | No nested containers. There is no HUD compartment chooser (first fit, last out). Room containers are separate. | Documented |
| N1 | Checked | Full logic on `65e918c` is 5214/0 = 5182 + 32. After review it is 5223/0 = 5214 + 9. 0 `SCRIPT ERROR`; all 75 group lines run. RX/RY/RZ/RQ are green. | OK |

## Stress cases (`Batch043Checks.review_stress`, 9 assertions)

- **RC1/RC2:** tampered contained state (ration fraction, negative charges) is refused, and a clean save validates (failed before R1).
- **RC3:** an attuned copy can be stowed, stays attuned, counts toward the limit, and its save validates (failed before R2).
- **RC4:** a hidden fourth attunement inside a container is refused (failed before R2).
- **RC5:** destroying an ordinary container keeps its contents with the holder (failed before R3).
- **RC6:** a cursed copy is refused before it moves.
- **RC7:** an undeclared SRD cursed item breaks at slot 3 as before.
- **RC8:** an over-weight put changes nothing.
- **Scenario:** the real post-load combat transition reaches a player turn.

## Runs on `7c7b19e`

| Run | Result |
|---|---|
| import | 0 |
| logic | 5223 passed, 0 failed, 0 SCRIPT ERROR |
| 021 / 029 / 031 / 032 / 033 / 034 / 035 / 036 / 037 / 038 / 039 / 040 / 041 / 042 / 043 | 21 / 37 / 25 / 33 / 70 / 10 / 9 / 7 / 11 / 7 / 10 / 13 / 11 / 9 / 11 ok, 0 failed |
| shared_spell_flow | 67 ok, 0 failed |
| downed_area_damage_flow / party_recovery_flow | 1 / 2 failures, identical to main |

## Proposed registry change (on owner acceptance)

- S-196 becomes `Verified (VS-131; exact contents in declared compartments)`, P8 (+1).
- S-202 becomes `Verified (VS-132; persistent declared curses and exact breaking)`, P8 (+1).
- Counts: +2 on top of 040–042's outcomes.
