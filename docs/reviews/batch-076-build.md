# Batch 076 build: S-121/S-122 footprint terrain fix (#38 follow-up)

Card Q-20261025-212240-01a9. Branch `batch-076-footprint-terrain`, stacked on `triage-scenarios-2026-10-25` (PR #48, head 728dd4e).

## Done means (Brandon's ruling, verbatim)
"Check the whole creature footprint against terrain and map bounds; a Huge creature must not pass through a wall because its center fits. Fix the barbarian_action_flow fixture that expects an off-map landing. Existing overlaps may get a narrow escape allowance, but terrain checks are never waived."

Brandon (4:13 PM CDT): "Yes, fix the one-goblin setup" (barbarian_choice_flow).

## What changed
- `PlacementRules.footprint_terrain_error(state, hex, size, ctx)` (new shared operation): every cell of the size-based footprint is checked for map bounds (tile present), passability/walls, room walls, plane, clearance and blocking objects; creature occupancy is excluded.
- `PhysicalFactsRules.is_space_available`: optional `ignore_occupants` context flag skips only the grid-entity occupant scan (used by the terrain-only query). Default behavior unchanged.
- `TravelPlacementRules.forced_step_blocked` (production caller: `CombatState._push_combat_target` - spell push, Push mastery, barbarian Forceful Blow): a legal start is still held to full footprint legality; an illegal (overlapping) start now gets only the escape allowance for creature overlap and must pass `footprint_terrain_error` for the whole footprint. Before this, only its center cell was tested against terrain, and edge cells could enter walls or leave the map.
- Teleport arrival (`destination_error`) already used the full footprint via `PlacementRules.legal_error`; new logic checks pin that for a Huge traveler (edge cell in a wall, edge cells off-map).
- Fixtures: `barbarian_action_flow` now lays a clear area covering the Huge target's whole radius-2 footprint along its push path, instead of a 5-hex corridor that relied on an off-map landing. `barbarian_choice_flow` now spawns the two goblins it positions (`monster_ids = ["goblin", "goblin"]`), removing the `viewport_harness.gd:804` index '1' error.
- No data or per-ID branches (ADR-0018); no saved fields added, legacy saves unaffected.

## Commands (Godot 4.7.2, sequential, never concurrent)
- `Godot_v4.7.2-stable_linux.x86_64 --headless --path . --import` x2: no SCRIPT/Parse/Compile errors.
- `TEST_SUITE=logic TEST_LOG_DIR=/tmp/tlogs076 bash run_tests.sh <godot>`: parse gate 420 scripts, boot gate, logic **6220 passed, 0 failed**.
- Baseline (triage-scenarios-2026-10-25 728dd4e, imported twice): logic 6210 passed, 0 failed. Delta **+10** (all Batch076FootprintChecks).
- Scenarios (`res://scenes/viewport_harness.tscn --scenario=<name>`): `batch_076_footprint_terrain_flow` PASSED, `barbarian_choice_flow` PASSED (failed on main and #47 in the triage), `barbarian_action_flow` PASSED, `batch_066_travel_placement_flow` PASSED, `s121_exit_placement_flow` PASSED. No SCRIPT/Parse/Compile errors in any log.

## New scenario: batch_076_footprint_terrain_flow
Live combat, production push host. A Huge creature whose next center cell is open but whose edge cell is a wall is refused (0 ft); with an overlapping start (escape allowance) the same wall still refuses; with the wall removed the overlapping start escapes 10 ft; a legal push from a legal start moves the full 10 ft; a push stops before its footprint would leave the map although the center would stay on it.

## Limits (still PARTIAL)
- Find Steed arrival checks only its center cell.
- Multi-target and planar teleports are not hosted; engulf/swallow exits have no host (card 1c72).
- The escape allowance still lets an overlapping body move through creature overlap (by ruling); objects are treated as terrain (never waived).
- Huge/Gargantuan targets are still exempt from size-limited pushes as before; the fix applies whenever a push host moves them (e.g. Forceful Blow).

## Source manifest
- src/combat/placement_rules.gd
- src/combat/physical_facts_rules.gd
- src/combat/travel_placement_rules.gd
- src/batch_076_footprint_checks.gd (new, logic)
- src/batch_076_footprint_controls.gd (new, scenario)
- src/test_runner.gd, src/viewport_harness.gd (registration + two fixture fixes)
- docs/mechanics/created-actors-and-placement.md, docs/planning/vocabulary-slices.md
- .questboard/quests/Q-20261025-212240-01a9.md
