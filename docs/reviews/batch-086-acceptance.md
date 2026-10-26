# Batch 086 acceptance review (Runtime Reviewer)

PR #59, base 83cd466 (batch-085-cast-local-transforms), reviewed head 7239735. Card Q-20261026-061340-f50f.
The finish line is the one quoted in the PR body by Runtime Builder; Brandon's ruling was not checked against a primary source.

## Verdict: ACCEPT (partial, as declared)

## Evidence
- Two headless imports clean; logic 6399/0 (6398 + 1 reviewer check).
- Scenarios, one at a time, no SCRIPT ERROR: batch_086_find_steed_arrival_flow PASS, batch_086_find_steed_arrival_reload PASS, batch_076_footprint_terrain_flow PASS (base PASS).
- local_room_object_flow: head fails 2 (both movement: "Combat movement modes choose their saved speed..." and "Combat movement charges uphill cost..."), base fails 5 (the same 2 plus 3 room-object/Fog Cloud reload). The builder's "same on base" is understated: head is strictly better. The Find Steed mount/dismount assertion passes at head.

## Focus 1: mount/dismount reach (body_distance)
- SRD 5.2.1 (from memory, page unconfirmed): you mount a willing creature within 5 feet of you that is at least one size larger. Distance is measured between spaces, so nearest cell of a Large body is correct; centre-only was too strict.
- Scope: the only production callers are `_toggle_find_steed_mount` (mount range and dismount landing). No melee, opportunity attack, grapple/shove, Help, touch-spell, interact or pickup path calls it; it replaced only the centre `HexUtils.get_distance` in that function. Reach is not widened elsewhere.
- Applies to Find Steed steeds only (the only mount system).
- "One size larger" is NOT enforced, at base or head (pre-existing gap, not a regression).
- Fixture: setup now takes the nearest full-footprint spawn; the dismount assertion changed from centre distance == 1 to body distance == 1. That matches the new rule, not a loosening; it still forbids a landing inside the footprint (distance 0).

## Focus 2: injected change before payment
Find Steed has no option popup between target validation and payment, so live play can't change the grid between them; the recheck is defensive. Added a logic check: a legal Large arrival at (3,0), then a wall and then a creature injected into the footprint; `refuse_arrival_destination` refuses both, accepts once cleared, and the slot count is unchanged (2 -> 2). Code order confirmed: the recheck returns before `commit_metamagic`/`commit_spell_resource`. The live stale-selection step in the scenario (goblin moved in after choosing) refuses with slot 2/2 and Action available.

## Other
- Edge cases covered by builder checks and scenario: wall under an edge cell, off-map edge, creature overlap, caster overlap, out of range. Recovery is deterministic (PlacementRules.candidates sorts by distance, x, y) and uses full-footprint terrain legality.
- Legacy steed at a now-illegal spot: falls back to recovery; if no space fits, combat entry fails with a message and the saved steed state stays intact (not lost). Code read only; no real legacy save was loaded.
- ADR-0018: the `find_steed` id branch in spell validation is removed; size/placement come from data. `DataLoader.get_spell("find_steed")` remains in the existing steed-specific factory (pre-existing).

## Proposed count updates
Logic 6399/0.

## Open decisions for Brandon
1. Enforce "at least one size larger" for mounting? Not enforced today.
2. Exploration steed occupancy is still centre-only (declared partial): card it?
