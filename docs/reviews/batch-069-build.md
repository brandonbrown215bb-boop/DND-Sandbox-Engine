# Batch 069 build: S-032/S-196 unknown-weight room placement

Card Q-20261020-230919-ac39. Based on `batch-068-exact-contents` (includes reviewer commit 6696880), because PR #40 is still open.

## Finish line (verbatim)
"Unknown-weight room placement (S-032/S-196): stop treating missing measurements as known. Volume stays partial."

Slice row (docs/planning/vocabulary-slices.md): "Fix unknown-weight room placement (ac39); keep volume explicitly partial until 65fc has source-backed measurements."

## Design
See [unknown measurements](../mechanics/unknown-measurements.md).
- `RoomMeasurements` (new): `legacy_invented`, `known_fields`, `migrate_dungeon`, `describe_object`, `describe_item`, `physical_error`. Production callers: `LocalRoomRules.placed_item` (Place), `LocalRoomRules.interact` take/inspect, `CombatObjectRules._make_item_object`, `SaveManager._deserialize_dungeon_state` / `_apply_campaign_ledger`, `InventoryCopies.record_state_error`, room **Inspect item**.
- Room **Inspect** no longer shows the engine defaults "wood"/"Small": absent facts read `unknown material, unknown size, unknown weight`.
- `ContainerRules._fits`: an unmeasured item already inside a weight/volume-limited compartment refuses the check instead of counting as 0 lb.
- Legacy: pre-d450b24 `placed:` copies stamped `mixed`/`Tiny`/`item weight else 1 lb` are migrated on load (idempotent) and at re-placement/combat/take; only facts missing from the item data are cleared. Authored objects are untouched.
- Costs: Place refusal (occupied cell) spends no time and moves nothing; Inspect is free; Take moves the copy once and a replayed take is refused with no time. Place/Take have no chooser, so there is no cancel path to test.
- Durability: no new saved fields; `state.physical` is now validated through `InventoryCopies.record_state_error` (absent = unknown). No item effects change, so the merged/suppressed gate is not involved. Covered formats: active dungeon state and dungeon snapshot migration (logic), real save/load and fresh-process reload (scenarios).

## Validation (Godot 4.7.2, import twice)
- Logic: **6033 passed, 0 failed** (base ~6012; new checks in `Batch069Checks`). No SCRIPT/Parse/Compile errors.
- Scenarios: `batch_069_unknown_weight_flow` PASSED, `batch_069_unknown_weight_reload` (fresh process) PASSED. Related: `batch_043_container_curse_flow`, `batch_044_parts_magic_flow`, `batch_048_item_types_measurements_flow`, `batch_068_exact_contents_flow`, `batch_068_exact_contents_reload`, `projected_vessel_flow`: all PASSED.

## PARTIAL
- Volume (65fc): no item volumes; volume-limited compartments refuse unmeasured items.
- Room-object container `put` keeps its pre-existing `capacity` count default of 20 and does not weigh contents.
- No character carry/encumbrance total exists, so no carry check consumes weight.

## Open questions
- Should the room container count default (20 when `capacity` is absent) be removed per "no engine defaults" (refuse when unauthored)? That changes authored rooms lacking `capacity`.
