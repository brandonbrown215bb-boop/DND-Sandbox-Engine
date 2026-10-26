# Batch 086 build — S-121/S-122 Find Steed arrival placement

Stacked on `batch-085-cast-local-transforms` (PR #58). Card Q-20261026-061340-f50f.

## Finish line (verbatim)

> Finish that specific arrival host using the existing factory and placement rules. Prove full-footprint placement, blocked-space costs, cancellation, stale selection, and persistent actor recovery. Leave multi-target/planar travel for another job.

## What changed

- Data (ADR-0018): `find_steed.summoned_creature` declares `size: large` and
  `placement {range_hexes: 6, no_space: refuse, choose: true}` (SRD 5.2.1: a
  Large steed appears in an unoccupied space within range). `DataLoader` validates
  it through `SummonArrivalRules.data_error`. No per-ID branches.
- `SummonArrivalRules` (new) reads that spec and calls the existing
  `PlacementRules.legal_error` / `candidates` for the whole footprint, ignoring only
  the owner's previous steed body. `PlacementRules.candidates` gained an optional
  `context_overrides` pass-through.
- Spell path: the old center-only check in `spell_cast_validation` is replaced by
  `SpellCastMovement.refuse_arrival_destination`; `_execute_selected_spell`
  rechecks it right after the teleport recheck and **before** metamagic/slot payment.
- Factory: `_add_find_steed_entity` uses the data size, refuses an explicit space
  that does not fit, discards a saved room position whose footprint no longer fits,
  and recovers onto the nearest full-footprint candidate.
- Harness local-room mount fixture now spawns its steed via `recovery_candidates`
  (a Large body adjacent to its owner overlaps).

## Cost rule

Refused space (validation or pre-payment recheck): no slot, no Action, the cast
stays pending. Cancel: nothing spent. Successful arrival: one level-2 slot and the Action.

## Evidence

- Logic: `Batch086Checks` (combat group) — data spec/validation, open vs adjacent,
  wall under an edge cell, range + override, map edge, other creature, own vs other
  steed, recovery distance.
- `batch_086_find_steed_arrival_flow` (real spell menu + hex clicks, level-5
  paladin): wall-edge refused unspent; caster-overlap refused unspent; Cancel
  unspent; space blocked after the spell was chosen refused unspent; legal space
  places the Large steed and spends slot+Action once; recovery onto the nearest
  full-footprint space; real SaveManager save/load.
- `batch_086_find_steed_arrival_reload` (separate process): load, combat start
  recovers the steed on a full-footprint space with the saved HP.

## PARTIAL

- Multi-target and planar arrival (left for another job by the finish line).
- Exploration-mode steed occupancy (`LocalRoomRules.find_steed_position`) is still center-based.
- If creation failed after payment (grid changed between the pre-payment recheck and
  creation; no current host does this) the slot stays spent.
- The "stale selection" scenario changes the grid between choosing the spell and
  clicking; the pre-payment recheck itself is covered by code path, not by an
  injected mid-resolution change (no await exists between validation and payment
  for Find Steed).
- The room-stored-position recovery branch is not directly scenario-tested.

## Follow-on fix: mount/dismount reach

A legally placed Large steed's center is never adjacent to its rider, so
`_toggle_find_steed_mount` now measures "within 5 feet" to the nearest footprint cell
(`SummonArrivalRules.body_distance`) and dismounts onto a space adjacent to the body.
The `local_room_object_flow` fixture assertion was updated to match. That scenario
still has two failures ("Combat movement modes ..." and "uphill cost") which fail
identically on the base branch `batch-085-cast-local-transforms` (pre-existing, not touched).
