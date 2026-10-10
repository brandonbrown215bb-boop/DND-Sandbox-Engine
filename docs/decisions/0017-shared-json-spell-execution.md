# ADR-0017: Compose spells through shared JSON execution

Status: Accepted, 2026-10-09. The owner prioritized this work after reviewing
the repeated cost of adding spell-specific wiring.
Partially superseded by [ADR-0018](0018-shared-data-driven-rules-runtime.md):
dedicated native handlers are transitional for unmigrated mechanics, not
the target extension mechanism. Mixed-check requirements and the current
simple authoring contract remain.

Clarified 2026-10-09: shared composition is the development direction;
the first implementation's attack/save exclusion is temporary.

## Problem

Splitting spell code into files made it easier to locate, but adding content
still required repeated spell-ID branches in availability, execution, effects
and persistence. That defeats the project's JSON-moddable sandbox purpose and
increases the owner's cost of adding and maintaining spells.

## Architectural direction

Shared, data-driven execution is the default for new spell mechanics and
continued migration of existing spells. A spell describes a composition of
reusable targeting, checks, payloads and lifetime rules. Adding a spell using
implemented operations must require content/class-list changes, without
spell-ID branches in the engine. When an operation is missing, implement and
verify that reusable operation before adding spells that depend on it.

Attack rolls and saving throws are composable checks, not mutually exclusive
spell categories. Shared execution must be able to express ordered steps such
as an attack followed by a save on hit, an attack followed by an area save on
either hit or miss, and a save that enables a subsequent attack. Each step
must specify its own targets, prerequisites and affected payloads. A save
against a secondary condition must not cancel damage already resolved by the
attack; a missed attack must not suppress an independently declared area step.

Results must remain distinct by step and target. Follow-up conditions refer to
the relevant hit/save result, rather than one cast-wide `hit` or `saved` flag.
The whole sequence remains one cast: action, slot, components and cast-wide
resources commit once; reactions and Metamagic occur at their appropriate
boundaries. Awaited choices/rerolls resume the pending step without replaying
completed damage or effects. Timed payloads retain their source identity,
captured DC, concentration and existing save/lifetime invariants.

Use the smallest explicit sequence and conditions needed by actual spells.
This decision does not require a general scripting language, new framework or
replacement of the working attack/save resolvers. Existing simple records
should remain valid when sequences are added. Existing dedicated handlers remain for unmigrated mechanics while shared
replacements are verified. A unique mechanic must ultimately be expressed
as data using generic capabilities; combining familiar operations is never
a reason to create another per-spell handler.

## Implemented first contract

Ordinary spell records declare `execution: "shared"`. Their existing target,
delivery, damage/scaling, resource and component fields remain authoritative.
`SharedSpell` validates the supported composition and applies healing,
Temporary HP, source-owned condition grants and condition removal. Damage,
attack rolls, saving throws, reactions and Metamagic reuse the existing
resolvers and ordered cast stages. Presentation does not apply those payloads
a second time. Deferred Empowered damage finishes before payload application.

Availability follows supported operations, not spell ID membership. Invalid
shared content fails loading, and invalid runtime casts refuse before costs.
Timed shared records use the existing plain source/caster identities,
concentration replacement, combat boundaries, campaign clock and schema-2 save
preflight/reconciliation. Installed content is required to restore a mod spell.

Local-room exploration discovers eligible prepared shared spells from data.
Single/self party spells and single-object damage spells reuse the resolver,
range/line-of-sight/component checks and room object transactions. Area and
multi-target shared exploration controls are not part of this version; those
spells remain available through their ordinary combat controls.

Unmigrated exceptional spells currently retain dedicated trusted handlers. This contract
currently does not implement summons, movement, ongoing spatial hazards, arbitrary
modifier languages or executable mod scripts. Extend a shared operation when
its real behavior can be represented, rather than registering a new spell ID
as a substitute for implementing that behavior.

The current validator accepts automatic, attack or saving-throw delivery and
rejects a record combining `attack_type` with `save`. `on_spell_hit` and
`on_failed_save` gate effects against that single delivery result; they do not
create another check. A spell may already have a timed grant with a later
`repeat_save`, but that is not a general mixed-check sequence. Ordered mixed
attack/save execution is required by the direction above and remains
unimplemented. Do not present the current exclusion as a permanent design
rule or enable both fields without defining their ordering and effect scope.

## Acceptance for mixed-check execution

Before declaring sequences supported, production-path checks must cover:

- Hit/miss followed by a gated save and successful/failed-save payloads,
  preserving the attack's own damage.
- An independent area save after both attack outcomes, including the original
  target and nearby targets with separate results.
- A save enabling a later attack, plus cancellation/interruption and deferred
  rerolls without duplicate costs, checks, damage or condition grants.
- New JSON IDs exercising these compositions through normal selection and
  casting, with existing simple definitions and timed save/load behavior
  remaining valid.

Examples in the authoring guide must distinguish executable syntax from planned
behavior until this acceptance is met.

## Compatibility

No save namespace or schema migration. Existing legacy spell records continue
through their existing handlers. Twelve winning core definitions now declare
shared execution: Fire Bolt, Burning Hands, Fireball, Acid Splash, Cure Wounds,
Healing Word, Hold Person, Inflict Wounds, Poison Spray, Sacred Flame, Shield of
Faith and Cone of Cold. Their definitions retain existing rules limitations.

Tests load namespaced fixtures through the production loader; those examples
are not installed in the normal catalog. The live `shared_spell_flow` checks
learning/preparation, actual controls, costs, downed-target selection,
concentration, repeat saves, disk reload and common clock expiry. See the
current checkpoint for run evidence and verification limits.
