# Batch 068 acceptance: S-196/S-210 exact contents and parts (PR #40)

Reviewer: Runtime Reviewer. Card Q-20261025-093505-d15c (claimed until 2026-10-26 04:36 CDT). Reviewed head 52d1d6c, stacked on batch-067-weapon-damage-choice 7487c73.

Finish line (verbatim): "Exact container contents and attached parts (S-196/S-210): explicit selection, demonstrated with two eligible copies."

## Verdict: ACCEPT, no defects. S-196/S-210 PARTIAL as declared (worn hosts not in the room selector, combat controls unwired, nested containers refused).

## Verified
- Exact identity: every option carries instance/container/host ids plus compartment/socket; apply paths (stow_into, take_out, attach_into, detach_part) act on that id only. No first-match fallback once options exist; the fallback (stow/retrieve_last/attach_any/detach_last) runs only when options are empty and then only reports the refusal. Review test: copies differing only in charges/upgrades keep their own state; the twin is untouched.
- Stale: take_out and detach_part recheck that exact id is still in that compartment/socket; stow_into/attach_into go through put()/attach(), which revalidate ownership, fit and capacity before take_instance. Menu serial ignores replays and superseded menus; an acting-character change refuses.
- Capacity/weight: put_error runs _fits before anything moves. Review test: over-capacity compartments aren't offered and a forged pick refuses with the inventory unchanged.
- Single option applies directly (review test that the options list is length 1 in that case; the flow covers 2+).
- crit_range 21 (29c5f8d): set on the test actor only and restored right after the call; natural 20 can't reach 21, so AC 1000 forces a miss. No production change.
- record_state_error: no new nested record shapes; saved_error checks pass in the 068 logic and real save/load scenarios. Legacy saves are unaffected (no schema change).
- No per-ID branches.

## projected_vessel_flow edit
Sound, but slightly weak: the picked copy (`loaded`) is also the last stowed, so a last-out fallback would pass too, and the menu opening wasn't asserted. The final assert still fails if the wrong copy moves (it checks `loaded` is back and `child` remains). Review added an assert that the exact menu opens with 2 items.

## Tests
- Logic: 6012 passed, 0 failed (6008 builder + 4 review), 0 SCRIPT ERROR.
- Scenarios, each run alone, all pass with 0 SCRIPT ERROR: batch_066_travel_placement_flow, batch_067_weapon_damage_choice_flow/_reload, batch_068_exact_contents_flow/_reload, projected_vessel_flow, item_form_return_flow, item_lifecycle_controls_flow, batch_043_container_curse_flow, batch_044_parts_magic_flow, batch_048_item_types_measurements_flow. None is on the main failure list; no regressions.

## Open
- An older exact menu stays visible after a newer one opens (its picks are ignored); cosmetic.
- Cards for worn hosts in the room selector, combat wiring, nested containers.
