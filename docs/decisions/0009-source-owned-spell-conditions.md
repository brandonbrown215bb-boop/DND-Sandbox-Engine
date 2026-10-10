# ADR-0009: Source-owned spell effects

Date: 2026-10-05
Status: Accepted; availability extended by [ADR-0017](0017-shared-json-spell-execution.md)

## Problem and decision

Conditions keyed only by name or caster expired on the wrong creature's turn
and allowed one repeat save or Concentration cleanup to erase another cast.
Each cast therefore owns a stable source record: caster ID, monotonic cast
serial, spell ID, grants, captured save DC, lifetime/turn boundary and
Concentration relationship. Releasing one source removes only its grants;
overlapping nonstacking benefits remain independently owned.

`SpellEffects` owns lifecycle/reconciliation with focused benefit and
persistence modules. Turn advancement is deduplicated at its declared boundary;
repeat saves use the captured DC. Concentration replacement/loss, death,
incapacitation and loss of all targets follow the same source cleanup path.
Durable party effects advance on campaign time between scenes.

Persist plain records and reconstruct references from stable IDs. Validate
source/caster relationships and bounds before changing the session. Optional
fields retain earlier schema-2 compatibility; do not replay grants on load.
Unmodeled monster/NPC persistence is not implied by encounter effects.

## Availability and evolution

`SpellSupport` remains the current availability boundary. Native slices retain
an explicit list; shared definitions are enabled by validated operations under
ADR-0017. No per-ID registration is needed for new ordinary shared spells.
Inventory and class membership alone do not establish executable behavior;
unavailable actions refuse before slot/action/component costs.

The original enumerated spell batch and its old visibility/component gaps
were an implementation snapshot, not permanent restrictions. Current clauses
and limits live in [mechanics](../README.md) and source. Follow
[ADR-0018](0018-shared-data-driven-rules-runtime.md) when extending the target
language: generic source-owned state replaces native benefit policy, preserving
these lifetime, exactly-once and save guarantees.
