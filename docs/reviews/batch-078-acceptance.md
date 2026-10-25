# Batch 078 acceptance (PR #51, S-032/S-196, #41 follow-up)

**Verdict: ACCEPT (PARTIAL as declared). No code fixes.** Judged against the builder-quoted ruling.

## Evidence (head e2aaa05)
- Logic: 6246 passed, 0 failed. No SCRIPT ERROR.
- Scenarios, run one at a time, all PASS: batch_078_declared_capacity_flow, batch_069_unknown_weight_flow/_reload, batch_077_per_swing_choice_flow, batch_075_linked_removal_flow, batch_068_exact_contents_flow, containment_flow.
- The only Put path is `local_room_rules.interact("put")`. `capacity, 20` is gone. `RoomMeasurements.put_error` runs before `inventory.remove_exact`, so it refuses before any cost: no item moves and no seconds pass. Inspect shows "declared" or "undeclared; engine technical limit 20 (not a game rule)".
- No other default-20 container path exists. The remaining `capacity` hits are tethers, containment, pools and bonds, which aren't related. Room load (local_room_rules.gd:32) copies contents without truncating, so legacy rooms over capacity keep every item. Only further Puts are refused.
- ADR-0018: no per-ID branches.
- Weights spot-checked from memory against SRD 5.2.1. Page numbers are unconfirmed because there is no PDF on the box. dagger 1, greatclub 10, dart 0.25, pike 18, heavy crossbow 18, warhammer 5 (2024 value), musket 10, chain mail 55, scale mail 45, shield 6, potion 0.5, ball bearings 2 and rope 5 all match. Nothing looks invented. I believe Sling, Bell, Antitoxin and Basic Poison are `—` in 5.2.1, so leaving them unknown is right (my recall, unconfirmed).

## Nits (non-blocking)
- A malformed `capacity` (string, negative, NaN) is silently treated as undeclared. It should be refused by validation instead of quietly going back to the technical limit.
- Nested containers are not modelled; Put only stows into room objects. That's a gap, not a regression.

## Proposed counts
Logic 6246/0. Card Q-20261025-215046-3f47 → accepted pending Brandon's merge (after #48, #49, #50).
