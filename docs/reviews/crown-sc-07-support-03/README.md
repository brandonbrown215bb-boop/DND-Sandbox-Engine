# SC-07 support 03: S247 condition_recovery_flow bisect and fix

## Bisect (condition_recovery_flow, each tip run twice)
| Tip | Result |
|---|---|
| #93 82e1b47, #92 ed30c5f, #94 e2211e7, #95 cf7ef22 | ok ok |
| **#96 3853fe2 (SC-05 support 03)** | FAIL FAIL (first failing) |
| #97 e899572 | FAIL FAIL |

Deterministic, not flaky; introduced in our stack.

## Cause
#96 correctly changed `save_advantage_if_fighting_target` from "target is a monster Dictionary" to the SRD meaning: the target is an opposed initiative combatant of the caster (`SpellSaveResolver.is_fighting_caster_side`), and that needs `cast.spatial_host.tracker`. The S247 fixture built a host-less `SpellResolutionContext`, so the save advantage no longer applied, Restrained Disadvantage stood alone (2 dice), and the assert that expects 1 die failed. The engine behavior is right and the fixture was stale. No engine change.

## Fix
`src/condition_recovery_flow.gd`: S247 now casts through a `SpellCastContext` host that carries the live combat `tracker`. It also asserts both sides:
- Host-less (not fighting): Restrained Disadvantage alone, 2 dice.
- Hosted, with opposed combatants: `is_fighting_caster_side` is true and Advantage cancels Disadvantage, 1 die.

## Proof
- `logs/condition_recovery_flow_run{1,2,3}.log`: PASSED ×3.
- `logs/logic_suite.log`: 6936 passed, 0 failed.
- No saved-data or CSV change.

## Limits
Test-only fix. It adds no new spell conversion.
