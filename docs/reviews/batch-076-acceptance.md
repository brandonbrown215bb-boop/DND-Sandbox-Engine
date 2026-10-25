# Batch 076 acceptance — S-121/S-122 footprint terrain (#38 follow-up)

PR #49, base `triage-scenarios-2026-10-25` (728dd4e), reviewed head c528ad6/417c0ed. Card Q-20261025-212240-01a9.

## Verdict: ACCEPT (PARTIAL as declared)

Finish line (Brandon, quoted in PR): whole footprint vs terrain and map bounds; Huge creature never passes a wall because its center fits; fix barbarian_action_flow off-map fixture; overlap escape allowance OK, terrain never waived. Met.

## Evidence
- `forced_step_blocked`: legal start -> full `legal_error`; illegal start -> `footprint_terrain_error` over every cell (bounds, passability, room wall, plane, clearance, objects). Old center-only "medium" check and the `"occupied" in reason` string hack are gone. Good.
- `ignore_occupants` defaults false; every other `is_space_available` caller is unchanged (pinned by a new check below and the existing 030 review check).
- ADR-0018: no per-ID branches. Refusal-before-cost: n/a (push is an effect resolved after the hit; refusal just stops the step). Legacy saves: no schema change.
- SRD 5.2.1 (from memory, page unconfirmed): a creature's space is its whole footprint; forced movement can't enter solid obstacles. Consistent.
- Fixtures: barbarian_choice_flow now spawns two goblins. The builder quotes Brandon's 4:13 PM CDT ruling "Yes, fix the one-goblin setup"; I couldn't independently see that message, so treat it as the builder's quote.

## Review commit
- Stress checks in `src/batch_076_footprint_checks.gd`: Large edge cell into wall, axial-diagonal push into wall/open, legal Large start into a creature's square, default occupant blocking vs explicit flag. All passed with no code change. No defects found.

## Runs
- Import x2 clean. Logic 6220/0 at PR head; 6225/0 with review checks.
- Scenarios (one at a time), all PASSED, no SCRIPT ERROR: batch_076_footprint_terrain_flow, barbarian_choice_flow, barbarian_action_flow, batch_066_travel_placement_flow, s121_exit_placement_flow.
- Base triage branch vs main: it adds the stacked 074/075 work plus the triage commits (3cc8959, 728dd4e), so it's not just main. It's PR #48 and needs to merge first.

## Nits / partials
- `ignore_occupants` skips only `grid.entities`; the `players`/`monsters` lists are still checked. `footprint_terrain_error` clears them, so it's correct, but the flag name overpromises.
- PARTIAL: Find Steed arrival checks only the center; multi-target and planar teleports; engulf exits (card 1c72).

## Proposed updates on merge
Registry: S-121/S-122 footprint-terrain row -> accepted (partial). Checklist: tick #38 follow-up. Checkpoint: logic count 6225. Roadmap: accepted batches +1 (076).
