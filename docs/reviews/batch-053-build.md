# Batch 053 build: S-121/S-122 legal placement

Card Q-20261021-040420-1903. Base origin/main 31db360 (PRs #20-#24 merged), not stacked.

## Finish line
"Legal placement for created creatures and projected items. Replace the fixed spawn offsets with actual legal destinations. Check occupied cells, walls, plane and clearance; reserve separate spaces for multiple creatures; recheck when the player confirms. Apply the authored failure/payment policy when there's nowhere to go. Done means: normal player controls demonstrate successful placement, blocked placement, cancellation, stale choices and multiple creatures without overlapping or double payment."

## Design
- **`PlacementRules`** (src/combat/placement_rules.gd)
  - A destination is legal when `PhysicalFactsRules.is_space_available` accepts it. That covers grid tile, passable/blocked geometry, room wall, plane, clearance, living occupants (ally lists, monster lists and grid entities) and blocking objects.
  - A legal destination must also be within the authored range, must not be the origin, and must not already be reserved.
  - Functions: `candidates` (nearest first), `reserve` (distinct cells for N arrivals, or none), `confirm_error` (recheck at confirmation).
- **Authored policy:** the `create_actor` effect takes an optional `placement {range_hexes 1-24, no_space refuse|spend, choose bool}`, validated by `SharedSpell.content_error`.
  - Default when unauthored: range 1, `refuse`, no prompt.
- **Cast flow:** `SpellCastChoices.choose_placement` is the last step of `SpellCastPreparation.validate_and_choose`, so it runs before any slot or action payment.
  - With `choose`, there is one popup per creature: "Place <name> i of N", listing Cancel plus the legal cells, with cells already reserved this cast excluded.
  - Cancel/close: nothing is spent.
  - Stale (a newer placement popup, or `commit_guard` fails because the turn ended): nothing is spent.
  - All picks are rechecked at confirmation. If one became illegal, the cast is refused and nothing is spent.
  - No legal space: `refuse` refuses before payment. `spend` pays once and the shared effect creates nothing, with no source record.
- **Picks:** they are carried only on the cast's spell copy (`_placement`) and are never saved.
- **Entering combat:** `CombatState._attach_created_actors` gives `CreatedActorRules.attach` a production caller after a successful cast.
  - Each actor enters at its confirmed cell if that cell is still legal, otherwise at the nearest legal cell in range, otherwise not at all (never overlapping).
- **Item projections:** `ItemProjectionRules.attach` replaces its fixed offset with the nearest legal adjacent cell, or none.

## Checklist
- (a) Refusals happen before payment.
  - The scenario asserts slots are unchanged after Cancel, after answering a superseded popup, after answering a popup after its turn ended, after a confirmation recheck, and after a walled-in `refuse`.
  - It asserts exactly one slot is paid for the two-creature cast and for the `spend` failure.
- (b) No new saved record. Picks are transient, and the scenario asserts `_placement` is not in the saved character. Created actors keep their existing validated `created_actors` record.
- (c) Production callers:
  - `validate_and_choose` → `choose_placement` → `PlacementRules`.
  - `_finish_spell_cast` → `cast.attach_created_actors` → `CreatedActorRules.attach`.
  - `SharedSpell` create_actor path → `spend` policy.
  - The loader → `policy_error`.
- (d) A real save and load keeps the wardens.
- Merged/suppressed gate: not relevant. Placement adds no item feature, mode or benefit.

## Changed earlier scenario
- 039 previously had to attach its warden by hand. The cast now places it, so the follow-up attach adds nobody. The assertion checks the warden is present exactly once (10 ok, unchanged count).

## Counts
- Fresh main baseline 31db360 (imported twice): 5498/0.
- Branch: 5508/0 (+10), 50 check scripts, 0 failed.
- Scenarios 031-053 pass one at a time with the #24 scenario gate. 053: 11 ok.

## Limits
- Single-cell bodies only. Multi-cell footprints (Large+) are not modeled (the vocabulary row's explicit scope note).
- S-121's other half is not built: exit placement *before a save/outcome settles* (engulf/swallow exits). This batch covers arrival/creation and projection entry.
- Item projections have no player placement picker or authored range yet (nearest legal adjacent cell). Projection itself still has no normal player control (unchanged).
- Placement is combat-only. Out-of-combat creation has no grid and is unchanged.
- S-155 is not included.
