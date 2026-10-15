# ADR-0018: One shared data-driven rules runtime

Date: 2026-10-09
Status: Accepted direction; implementation staged

> [ADR-0023](0023-vocabulary-first-delivery-and-bounded-world-judgment.md)
> clarifies vocabulary-first delivery, bounded illusion/campaign Wish behavior
> and current save priorities. Compatibility planning and a universal GM
> workflow are not prerequisites for ordinary capability work.

## Context

The owner is moving toward data-driven engines and requested reconciliation
of documentation, including ADRs, so agents do not perpetuate past choices.
ADR-0017 already requires shared spell composition. The class and creature
designs expose the same need for staged decisions, costs, source-owned state
and world interaction. Separate native handlers leave JSON descriptive and
make each new rule an engine edit.

## Decision

Build one in-process typed rules runtime shared by classes, creatures, spells
and interacting content. Definitions express behavior, restrictions, choices,
resource/recovery policy and interactions as data. GDScript interprets generic
operations and supplies observable world capabilities. Python remains import,
inventory and structural tooling.

A new definition using available capabilities must work through loading,
selection, commands, UI and persistence without native branches or registration
for its identity. Renaming IDs and updating data references must preserve
behavior. A genuinely missing world capability can require one generic
primitive/adapter; uniqueness of a rule is not an exception to the data boundary.

Use pure queries, explicit ordered steps and source-owned runtime state as
needed. Keep results separate per step/target; define reaction and replacement
order explicitly. Costs and effects commit once across suspension/resume.
Unknown operations, incompatible extensions and missing capabilities fail
before unintended expenditure or session mutation. No arbitrary executable mod
scripts, second monster interpreter, external rules service or new dependency
is authorized by this decision.

Reuse current loader, owned commands, budgets, typed-damage settlement, world
identities and SaveManager where semantics fit. Migrate in small production
slices; one action has one execution owner. Old helpers remain for unmigrated
behavior and regression repairs until replacement is accepted. They are not
the default for new mechanics, nor a fallback in a pack advertised as fully
data-driven. Do not require a wholesale combat extraction before the first proof.

## Supersession and retained decisions

- ADR-0006's permission to keep unusual class rules in trusted native helpers
  is superseded for the target runtime. Its current activation/resource,
  no-replayed-grant and save-compatibility guarantees remain.
- ADR-0017's dedicated-handler exception is likewise transitional; ordered
  mixed checks remain required. The current simple JSON schema still applies
  until a validated extension is implemented.
- ADR-0010/0011/0012 module splits describe existing organization. They do not
  authorize rule-ID dispatch as the final architecture. ADR-0011's initial
  three-module split was completed by ADR-0012.
- ADR-0002's unaccepted old Wolf-only contract is withdrawn. Future forms need
  verified current-source semantics and data-defined projections.
- Party ownership, durable world/source identity, resolver-owned activity and
  ADR-0004's save isolation remain constraints. Native module locations in
  other ADRs are current owners, not permanent homes for content policy.

## Acceptance and limits

The [roadmap](../../roadmap.md) selects the first shared proof and subsequent
dependency cohorts. Production Godot checks must demonstrate a new/renamed
JSON definition, hard temporal interaction, exactly-once choices/costs/results,
source-preserving cleanup and recovery of any newly durable state. Inventory
counts, helper calls alone and schema validation do not establish support.

The [class design](../architecture/data-driven-2024-class-execution-plan.md)
and [creature design](../architecture/data-driven-2024-monster-execution-plan.md)
are working specifications, not accepted executable syntax, a blanket
implementation schedule or full-catalog certification. Pin actual rule clauses
and source corrections before converting each mechanic. Follow ADR-0023 for
represented fiction, observer-specific illusions and campaign-authored Wish
outcomes; unrepresented open-ended outcomes remain explicit gaps.

This decision accepts direction, not a finished interpreter. It does not
authorize legacy conversion, a new save namespace/schema, mid-combat or
mid-decision saves, or rewriting unrelated save files. ADR-0023 removes blanket
compatibility/version planning as a prerequisite while retaining correct state
and existing checkpoint boundaries. Current accepted
runtime evidence and open work stay in the [checkpoint](../operations/current.md).
