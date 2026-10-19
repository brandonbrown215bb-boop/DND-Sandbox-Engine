# ADR-0025: Rider limits follow the actual roll or active grant

Date: 2026-10-16
Status: Accepted bounded implementation (VS-54/55/56, independent Batch J review)

## Decision and reason

Extend the existing numeric-pool weapon-hit rider rather than adding another
combat interpreter. Own-turn and first-round eligibility are independent of the
declared use limit. Initiative supplies the round; refreshing an action budget
does not erase it. Round locks identify the actual actor, source and option.

A per-roll allowance belongs to the production settled weapon hit, actual actor
and target objects, and captured weapon profile. Copies and caller-supplied IDs
cannot create another allowance. These receipts and round locks are transient;
they clear at their combat boundaries and are never save data.
Completing rider resolution closes that hit even when no option qualifies.
A later activation or replenishment cannot reopen the completed hit.

For the bounded active-instance host, use the existing source-owned timed AC
modifier's `grant_instance_id`. Its `used_rider_options` list records the option
already consumed on that grant. A new roll or combat does not reset it. Removing
or expiring the grant removes its lock; a later activation has a new grant ID.
Persisting this small list on the grant prevents a safe-checkpoint reload from
granting another use. It adds no second durable ownership structure.

A declared parent matching a real weapon or Opportunity Attack can waive the
one numeric rider-pool payment while its exact source's timed grant is active.
The waiver cannot supply the parent Action/Reaction or bypass the option lock,
eligibility or another source's cost. An empty owned pool can supply this waived
use; a missing or mismatched source cannot.

## Compatibility and boundaries

Existing saves omit `used_rider_options` and mean no consumed options. New saves
preflight the bounded unique identifier list with the existing owner/source/
grant/deadline checks before replacing live state. Existing 2024/legacy save
namespaces, checkpoint rules and grant clocks remain. No migration, mid-combat
saving or acquisition replay is added.

This extends ADR-0018's shared source/cost ownership and retains ADR-0004's save
boundary. It does not supersede other decisions. General event subscriptions,
other roll hosts, other active-effect carriers, payment substitutions, dice
inventories and catalog conversion remain outside this implementation.

Acceptance requires real attack/feature/Reaction controls, independent exact
sources and renamed loaded definitions, replay/refusal controls, original costs,
and fresh-process recovery plus malformed full-save refusal. Current receipts
and remaining host limitations belong to the Batch J review/checkpoint,
not this decision.
