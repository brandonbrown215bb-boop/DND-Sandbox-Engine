# ADR-0012: Focused spell resolution and encounter lifetime modules

> Migration scope (2026-10-09): [ADR-0018](0018-shared-data-driven-rules-runtime.md)
> governs new rule execution. Named modules below describe current owners,
> not permanent native handlers for content policy. Identity, ordering,
> cost and compatibility guarantees remain constraints. Dated implementation
> and validation statements describe this ADR's original snapshot.

Status: Accepted, 2026-10-06. The owner authorized continued spell decomposition
until additions have focused, maintainable homes.

Follow-on decision: [ADR-0017](0017-shared-json-spell-execution.md) establishes
shared JSON composition as the default for spell additions and migration,
including ordered attack/save sequences. The module split below remains useful,
but splitting files alone does not meet the content-authoring requirement.

## Problem

The area and early casting extractions left spell-specific resolution,
selection, effect application and cleanup spread across the large combat
controller and shared action script. Adding a spell still required finding
distant branches and checking their resource and lifetime ordering.

## Decision

Complete the responsibility split using small, explicit modules in `src/spells`:

- Selection, validation/choices, resources, targeting, movement, reactions,
  markers, results and area creation each have a cast module. Preparation and
  the controller retain a visible ordered sequence.
- `SpellResolver` preserves shared validation, resource handling, Counterspell
  and dispatch. Separate attack, save and projectile resolvers reuse shared
  damage helpers. Direct control, healing and ward results have focused homes.
- `SpellEffectApplication` applies resolved effects in their existing order.
  Pushes await area-entry triggers before applying subsequent payloads.
- `SpellEffects` keeps generic ownership, clocks, removal and reconciliation.
  Benefit grants/queries and saved-record validation are separate modules.
- Encounter expiry, repeat saves, concentration cleanup and delayed damage
  live in `SpellEncounterLifecycle`. Detection and Identify live in
  `SpellEncounterPerception`. Marker creation and expiry share their module.
- The area modules from ADR-0010 retain their ownership. Enemy area movement
  costs now live with their spatial queries.

`CombatState` keeps input, encounter bindings, turn sequencing and shared combat
callbacks. `CombatAction` keeps weapon/general combat rules and forwards its
existing spell API. Existing entry points and signatures are retained.

`SpellCastContext` carries a transient player request and stage results.
`SpellResolutionContext` carries one target's shared resolver inputs. Neither
is serialized. Modules receive explicit encounter references and callbacks;
they do not receive the full controller. There is no new interpreter, service,
dependency or registration framework.

The [spell extension guide](../../src/spells/README.md) maps each responsibility
to its module and explains where a new spell belongs.

## Invariants

Preserve cast stage order, target order, single resource commitment, reaction
decisions and awaited prompts. Preserve effect source IDs, captured repeat-save
DCs, concentration ownership, turn-trigger deduplication and plain saved effect
records. Legacy saves and the 2024 save namespace are unchanged. This refactor
does not change spell availability or claim that additional content is supported.

## Validation and limits

Godot parser/boot checks, focused spell/effect/combat/persistence logic checks
and live encounter scenarios exercise the production paths. A cast-stage
regression check covers a push through an area with an awaited save decision.
Source comparison additionally verifies preserved unrelated methods and copied
resolution, grant, save-validation and lifetime statements; it does not replace
gameplay checks.

Failures and random encounter-fixture issues from the original extraction
batch are historical, not carried-forward current blockers. The latest
checkpoint records current accepted evidence. This decision completed the
responsibility split; it does not authorize a wholesale CombatState extraction
or fixes to unrelated class mechanics.
