# Batch 078 build: S-032/S-196 declared capacity and SRD weights (#41 follow-up)

Card Q-20261025-215046-3f47. Stacked on `batch-077-per-swing-choice` 2a2a3d3 (PR #50, including reviewer commit 2a2a3d3).

## Done means (Brandon's ruling, verbatim)
"stop presenting the default 20 as a real container capacity. Use declared capacities, and keep any temporary technical limit separate and labeled. Fill in documented weights but don't invent them; the SRD lists the bell as '—' (p.95)."

## Design
- **Declared capacity (ADR-0018):** a room container's `capacity` is data. `RoomMeasurements.declared_capacity` returns it or `null` (undeclared). The `int(object.get("capacity", 20))` default in `LocalRoomRules.interact` `put` is gone.
- **Technical limit, separate and labeled:** `RoomMeasurements.TECHNICAL_CONTENTS_LIMIT` (20) bounds stored records for every container. Refusal text: "Engine technical limit reached (20 items; not a game rule)." It never reads as a capacity, and it still applies to a container declaring more than 20.
- **Production callers:** room **Put** button → `LocalRoomRules.interact("put")` → `RoomMeasurements.put_error`. Room **Inspect** on a container appends `capacity N items (declared)` or `capacity undeclared; engine technical limit 20 items (not a game rule)`.
- **SRD weights:** 47 `weight` values added only where SRD 5.2.1 prints one: weapons.json (37, p.91), armor.json (4, p.92), consumables.json (5, p.95), artificer_tools.json (`ball_bearings`, p.95). Every value is listed with its page in the manifest `docs/mechanics/srd-item-weights.md`. `bell`, `antitoxin`, `basic_poison` (p.95 `—`) and `sling` (p.91 `—`) stay unknown.
- **Legacy saves:** no new saved field and nothing stamped. A container saved without `capacity` validates (`DungeonPersistence.local_error`) and reads as undeclared. `batch_069_unknown_weight_flow`/`_reload` (legacy 1 lb stamp migration) still pass.
- **#50 nit (recheck reach after the damage-type answer):** not folded in. The answer returns through the async damage-type menu in `CombatState`; a correct recheck needs a held-swing path for "target moved out of reach", which is not a trivial change. Left for a separate fix.

## Validation (Godot 4.7.2, imported twice, sequential, no concurrent Godot)
- Logic: **6246 passed, 0 failed** (+10 from `Batch078Checks` over 077's 6236). No SCRIPT/Parse/Compile errors in import, logic or scenario logs.
- Scenarios:

  | Scenario | Result |
  |---|---|
  | `batch_078_declared_capacity_flow` (new) | PASSED, 0 FAIL |
  | `batch_069_unknown_weight_flow` | PASSED, 0 FAIL |
  | `batch_069_unknown_weight_reload` | PASSED, 0 FAIL |
  | `batch_077_per_swing_choice_flow` | PASSED, 0 FAIL |

- The new scenario uses the real room controls in `ruins_of_ashvale` room 1: Inspect item shows the Bell's weight unknown and the Dagger's 1 lb; Inspect shows declared capacity and, for an undeclared box, no 20 but a labeled technical limit; Put stows one Dagger into a capacity-1 box and refuses the second with the copy still held; the room state with a capacity-less container round-trips through saved validation.
- Logic checks also cover: the technical-limit refusal and its label, the limit staying separate from a declared capacity of 40, Sling `—` unknown, Chain Mail 55 lb, Dart 1/4 lb.

## PARTIAL (still open)
- Pack weights (SRD p.95 prints totals) not filled: packs expand into contents and need a no-double-count rule.
- Imported non-colliding base items (breastplate, padded armor, etc.), magic items, tools and the remaining consumables were not audited for weights.
- Room `put` counts items only; no weight-based container capacity; no carry/encumbrance totals.
- Volume remains PARTIAL (card 65fc).
- Slice status unchanged.
