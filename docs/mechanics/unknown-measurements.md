# Unknown measurements in room placement (S-032/S-196, Batch 069)

Finish line: "Unknown-weight room placement (S-032/S-196): stop treating missing measurements as known. Volume stays partial."

## Contract
- An item's `weight` (lb) and `volume` (cu. ft.) and a room object's `material`, `size` and `weight_lb` are data facts. **Absence means unknown.** The engine never substitutes 0 lb, 1 lb, "Tiny", "Small", "wood" or "mixed".
- Placement (`LocalRoomRules.placed_item`, the room **Place** button) and combat projection (`CombatObjectRules.make_dropped_item` / `make_owned_item`) copy only facts present in item data or the copy's saved `state.physical`.
- **Take** stores only the object's real facts on the copy (`state.physical`).
- **Inspect** (room object) reports `unknown material`, `unknown size`, `unknown weight` for absent facts; **Inspect item** reports `Weight: N lb` or `Weight: unknown`, and volume as unknown/PARTIAL.
- Weight limits: `PhysicalFactsRules.evaluate_physical_eligibility` already refuses unknown mass for `max_mass_lb`/`min_mass_lb` (`reject_unknown` may only be `true`). `ContainerRules._fits` now also refuses when an item **already inside** a weight- or volume-limited compartment has no recorded measure, instead of counting it as 0. The production caller is `put` (Stow) and `saved_error`.
- No policy for unknowns is invented: an unknown measure refuses the limit check, with a message naming the missing fact. Data may supply the measure; there is no engine fallback number.

## Legacy saves (`RoomMeasurements`)
Builds before d450b24 stamped every dropped copy (`placed:` identity) with `material: "mixed"`, `size: "Tiny"`, `weight_lb: item.weight else 1`. That exact three-value stamp on a `placed:` object or on a copy's `state.physical` whose `object_id` is `placed:` is recognized as legacy invention; each stamped fact the item definition does not record is removed:
- on load (`SaveManager._deserialize_dungeon_state` for the active dungeon, `_apply_campaign_ledger` for dungeon snapshots), via `RoomMeasurements.migrate_dungeon` (idempotent);
- on re-placement, combat projection and take, via `RoomMeasurements.known_fields`.
Authored room objects (no `placed:` identity) and placed copies whose values differ from the stamp are data and are never changed. This is a format signature, not a per-ID branch (ADR-0018).

## Saved validation
`InventoryCopies.record_state_error` → `RoomMeasurements.physical_error`: a saved `state.physical.weight_lb` must be a finite non-negative number, `material`/`size` non-empty text; absent is valid (unknown). Legacy saves (numbers/strings) keep loading.

## PARTIAL
- Volume: no SRD item volumes are loaded (card 65fc); volume-limited compartments refuse every unmeasured item.
- Room container `put` still uses an authored `capacity` count with a pre-existing default of 20 when absent; it does not weigh contents.
- Characters have no carry/encumbrance total, so no carry check consumes weight.
- The legacy signature cannot distinguish a deliberately saved mixed/Tiny/stamp-equal value on a `placed:` copy (none is authored by any current code path).
