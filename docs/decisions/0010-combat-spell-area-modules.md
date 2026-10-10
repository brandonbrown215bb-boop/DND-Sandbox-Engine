# ADR-0010: Separate combat spell-area mechanics from player orchestration

> Migration scope (2026-10-09): [ADR-0018](0018-shared-data-driven-rules-runtime.md)
> governs new rule execution. Named modules below describe current owners,
> not permanent native handlers for content policy. Identity, ordering,
> cost and compatibility guarantees remain constraints. Dated implementation
> and validation statements describe this ADR's original snapshot.

Status: Accepted, 2026-10-06. The owner authorized spell decomposition.

## Problem

Spell additions accumulated area creation, movement/turn triggers, saves and
concentration teardown in CombatState. A single area spell needed changes in
several distant parts of the controller, increasing the chance of missing a
trigger or removing another cast's effects.

## Decision

Extract the existing encounter-local area behavior into three modules:

- `CombatSpellZones` owns area records, source serials, spatial queries,
  movement/turn dispatch, expiration and area concentration cleanup.
- `SpellZoneTerrain` implements terrain, obscuration and hazard spell creation
  and trigger resolution, including Moonbeam and the two cloud hazards.
- `SpellZoneConjurations` implements conjured spirits and caster-centered
  emanations, including Spirit Guardians and Aura of Life.

The rules modules receive the bounded area context and explicit caster/cast
choices. They do not receive CombatState. CombatState retains input, targeting,
action costs, player choices and rendering. Narrow forwarding methods retain the
existing combat call sites and live-scenario entry points. Encounter bindings
refresh from current entity arrays so setup can replace those arrays safely.

CombatAction remains the shared spell and typed-damage resolver. Awaited
callbacks keep player save/attack decisions, concentration checks and enemy
defeat rewards in their existing combat paths and order. Area rules can request
their existing HUD choices and redraws through the bounded context.

Area cleanup uses the existing caster/source ownership policies. In particular,
ending Black Tentacles concentration preserves higher-slot nonconcentration
casts, and removing one area leaves other casts' condition and terrain sources.
No spell content, support status, saved-effect records or save schema changes.

## Limits

This is a bounded extraction of area spells, not a general spell interpreter.
Direct spell targeting, many non-area effects and class actions remain in
CombatState. Light markers retain their existing combat representation.
Existing geometry, visibility and encounter-lifetime limitations still apply.

Regression checks cover replaced entity arrays and overlapping cleanup ownership.
Existing Godot spell/effect/combat/persistence checks and live area-spell
scenarios provide the gameplay verification; Python extraction checks only
confirm that unrelated controller methods were preserved.
