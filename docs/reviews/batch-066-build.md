# Batch 066 build: S-121/S-122 travel exit and arrival placement

Card Q-20261025-044851-d47e. New queue item 1. Based on main d450b24 (every PR through #37 merged).

## Finish line (verbatim)
"Finish travel exit and arrival placement (S-121/S-122). Extend the remaining travel hosts using the existing placement rules. Illegal destinations must refuse cleanly; captured outcomes and costs must settle once."

## Existing placement studied
- `PlacementRules.legal_error` / `PhysicalFactsRules.is_space_available` (size-based footprint: tile, walls, plane, clearance, living occupants and their footprints, blocking objects), already used by combat/room creation controls and containment release.
- S-121 combat save-exit host (`s121_exit_placement_flow`) already verified; S-122 item-projection controls already delivered.

## Design
- **Vocabulary** (`src/combat/travel_placement_rules.gd`, `TravelPlacementRules`): a `teleport` effect declares `{"type": "teleport", "distance": <hexes 1-200>, "requires_sight": <bool>?}`. No engine default distance: the loader (`DataLoader`) refuses a teleport effect without `distance`, with unknown keys, or with a non-boolean `requires_sight`. Misty Step data gains its SRD 30 ft (6 hexes) and sight requirement.
- **Refusal order** (`destination_error`): no authored reach, same space, off-map, beyond reach, not visible (when declared), then `PlacementRules.legal_error` for the traveler's full footprint, ignoring its own body.
- **Combat teleport host:** checked at target validation and again in `_execute_selected_spell` after option popups and immediately before `commit_spell_resource`, so a destination that went stale refuses with slot and Bonus Action unspent. `SpellCastContext.teleport_settled` marks the arrival so the resolver never moves or charges an invocation twice.
- **Local-room teleport host** (`LocalRoomRules.cast_teleport` / `travel_destination_error`): same rules against `ContainmentRules.placement_state` (party, familiars, steeds, created creatures/actors, objects) before `spend_spell_slot`.
- **Forced movement host** (`CombatState._push_combat_target`: spell push, Push mastery, barbarian push): each step stops before a space whose full footprint is illegal. A body that already overlaps something at its start (legacy placement) is not trapped by that pre-existing overlap (fix 03e2aad, found by `barbarian_action_flow`).

## Hosts covered
- Combat save-exit (S-121, already verified, unchanged).
- Combat teleport (Misty Step and any data-authored `teleport` effect).
- Local-room teleport (Misty Step).
- Forced movement steps (spell push, Push mastery, barbarian Forceful Blow push).

## PARTIAL
- Engulf/swallow escape exits (card 1c72): no engulf or swallow host exists in the runtime, so no required escape space is resolved before such an outcome settles.
- Find Steed arrival still checks only its center cell.
- Multi-target and planar teleports are not hosted.
- `requires_sight` uses line of sight only; lighting, Blinded and invisibility are not consulted.
- The room host accepts only `misty_step`.

## Checklist
- Refuse cleanly before paying: no reach, same space, off-map, out of range, unseen, occupied/blocked footprint, and stale destination (became occupied after the choice) spend no slot and no action (logic + `batch_066_travel_placement_flow`).
- Settle once: a settled teleport invocation never moves or charges twice (logic).
- Durable: no new saved field; real `SaveManager.save_game`/`load_game` round trip in the scenario; legacy saves unchanged.
- Docs: `docs/mechanics/created-actors-and-placement.md` ("Teleport arrival (Batch 066)") and `docs/planning/vocabulary-slices.md` (S-121/S-122 boundary and building-block row) updated.

## Counts
- Baseline d450b24 (imported twice): logic 5941 passed, 0 failed.
- Branch (imported twice, head 03e2aad): logic 5958 passed, 0 failed (+17, all 066).
- Full scenario sweep (229 listed, one at a time, branch before fix): 159 passed / 70 failed. Baseline sweep reached 190 of 229 before it stopped: 125 passed / 65 failed.
- Of the 70 branch failures: 63 fail identically on baseline; 5 (`batch_i_review_flow`, `local_room_object_flow`, `mass_cure_wounds_flow`, `sorcerer_twinned_spell`, `true_strike_spell_flow`) also fail on a standalone baseline rerun; `tether_group_flow` passed on rerun (timeout, flaky); `barbarian_action_flow` was a real regression, fixed in 03e2aad and now passes.
- After the fix: `barbarian_action_flow`, `batch_066_travel_placement_flow`, `s121_exit_placement_flow`, `tether_group_flow`, `monk_action_flow`, `fighter_second_wind` pass; `fighter_progression` fails with the same pre-existing SCRIPT ERROR as baseline (`combat_state.gd:2942`, Nil `inventory`).
- SCRIPT/Parse/Compile errors: none from 066 code; the pre-existing SCRIPT ERRORs (harness index '1' on `Array[Dictionary]`, `combat_state.gd:2942`) appear identically on baseline.

## Carried limits
- 065: `on_hit_by_attack` fires after settlement (naming decision open with Brandon); 064 outside-combat mode time PARTIAL (no clock advanced).
- Main's scenario sweep has ~65 pre-existing failures in this environment; not addressed here.
