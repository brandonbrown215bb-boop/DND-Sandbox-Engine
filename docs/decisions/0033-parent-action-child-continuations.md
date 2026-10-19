# ADR-0033: Encounter-local child actions within a paid parent

Date: 2026-10-18
Status: Bounded implementation; acceptance in Batch 028 review

## Decision

Use the existing combat strike, spell and movement owners to resolve declared
children. `CombatChildActions` owns only the transient parent source/invocation,
remaining children, selection and settled receipts. One parent pays its own
Action, Bonus Action or Reaction and feature use once. Child action waivers are
local to that invocation; spell resources and ordinary movement still pay.

Preserve independent remaining Attack/Flurry units for opted-in substitutions.
Canonical weapon receipts and spell contexts carry parent classification and
causal identity alongside the child's own identity. Awaited choices revalidate
actor, turn, source and exact continuation before changing state. Unsupported
children refuse before parent payment. Explicit skip/stop cancellation retains
the paid parent and cannot restart settled children.

## Why

Shared actions need to compose existing production behavior without adding
native branches for each authored sequence or granting an unrelated action
budget. Keeping continuation state with combat makes ownership and cleanup clear.

## Bounds and retained decisions

This host is the active living Character in combat. Reaction parents use that
actor's current Reaction; general off-turn triggers remain separate. Parent
state is transient and is never a new save field. ADR-0018's shared runtime,
exact source identity and single execution owner remain binding. Existing save
locations, legacy isolation and allowed checkpoints are unchanged. No earlier
ADR is superseded. The authoring contract and current evidence own exact limits;
this decision is not catalog acceptance.
