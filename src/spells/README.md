# Working on spells

Spell implementation is split by the work it does. Start with the relevant
module below; the combat controller keeps the ordered cast sequence and input
handling. Existing controller and `CombatAction` entry points forward to these
modules so callers do not need to know the file layout.

| Work | Location |
| --- | --- |
| Spell selection, slot choice and Metamagic prompts before targeting | `SpellCastSelection` |
| Eligibility, creature/component checks and geometry validation | `SpellCastValidation` |
| Spell-specific choices during casting | `SpellCastChoices` |
| Order of early validation/choices | `SpellCastPreparation` |
| Commit Metamagic, slots, free casts and Divine Intervention | `SpellCastResources` |
| Range, visibility, areas, selected creatures and projectile allocation | `SpellCastTargeting` |
| Teleports and Find Steed cast completion | `SpellCastMovement` |
| Cast-wide reaction decisions and concentration preparation | `SpellCastReactions` |
| Marker creation and expiry, plus Message completion | `SpellCastMarkers` |
| Per-creature result handling, True Strike integration and cast completion | `SpellCastResults` |
| Create areas after resolving their initial targets | `SpellCastAreas` |
| Shared spell validation, Counterspell and ordered resolver dispatch | `SpellResolver` |
| Saving throws, attacks or separate darts/rays | `SpellSaveResolver`, `SpellAttackResolver`, `SpellProjectileResolver` |
| Spell scaling, damage rolls, rerolls and damage settlement | `SpellDamageRolls` |
| Special direct control, healing or ward results | `SpellControlResolver`, `SpellHealingResolver`, `SpellWardResolver` |
| Apply a resolved spell's conditions, payloads and pushes | `SpellEffectApplication` |
| Source ownership, clocks, removal and concentration reconciliation | `SpellEffects` |
| Spell-specific benefit grants and queries | `SpellEffectBenefits` |
| Validate and serialize saved effect records | `SpellEffectPersistence` |
| Encounter expiry, repeat saves, delayed damage and concentration cleanup | `SpellEncounterLifecycle` |
| Detection refresh and Identify contact/completion | `SpellEncounterPerception` |
| Area ownership, spatial queries, movement/turn triggers and cleanup | `CombatSpellZones` |
| Terrain, obscuration and hazard areas | `SpellZoneTerrain` |
| Spirits and caster-centered emanations | `SpellZoneConjurations` |

Small existing `*_rules.gd` files own the represented details of their utility
spells, such as a light marker or an Animal Messenger delivery. Reuse those
boundaries when changing that spell.

## Adding or changing a spell

For ordinary spells, start with the [shared JSON contract](../../docs/mechanics/shared-spells.md).
`execution: "shared"` routes supported combinations through the existing
pipeline without per-spell availability, payload or lifetime registration.
`SharedSpell` owns validation and ordinary payload application. The modules
below locate current native behavior. Under
[ADR-0018](../../docs/decisions/0018-shared-data-driven-rules-runtime.md), extend
generic operations for new mechanics; existing exceptional handlers are
transitional, not the target authoring contract.

`requires_target_sight` controls visual eligibility. Keep physical line of
sight independent: an unseen target may be legal for an attack spell, while
an intervening wall still blocks the cast. `SpellCastResults` supplies transient
`spell_visibility` grid/position decisions to attack and projectile resolvers
so natural darkness and creature senses determine unseen attack modifiers.
These decisions are live context, never saved state.

1. Check its content record and executable support status first. Registry or
   class-list membership alone does not establish working gameplay.
2. For ordinary supported damage, save or healing behavior, use the existing
   data fields and shared resolution path. Add code only for behavior that
   those fields do not already express.
3. Implement a missing generic check/workflow/payload capability at the
   appropriate existing boundary. Keep step/target results and timing explicit.
   Do not add a native dispatch branch for a new spell ID. When maintaining an
   unmigrated handler, preserve its existing choices and order until the shared
   replacement has production acceptance.
4. For a timed benefit or condition, use a cast-owned source record. Extend
   shared grant/query operations instead of registering a new spell ID. Reuse
   the existing lifetime and removal machinery in `SpellEffects`. Extend saved-record validation if the
   record gains persisted fields. Do not serialize either context object.
5. For an area, keep its creation, triggers and removal in its area family.
   Connect initial-target handling and area creation through the existing cast
   stages. Keep turn-trigger deduplication and captured DC/source ownership.
6. Add a production check for the important behavior: resource spending,
   targeting, reactions, cleanup or disk-save round-trip as applicable. Tests
   in Python validate content structure; Godot checks prove gameplay.

`SpellCastContext` is one transient player cast request with encounter bindings,
stage results and explicit controller callbacks. `SpellResolutionContext` is
the smaller request for resolving one creature. Modules receive those bounded
inputs, rather than the whole combat controller. Shared weapon rules, turn
budgets, initiative, input and scene redraws retain their existing owners.

## Ordering that must stay explicit

The player execution sequence is preparation, Metamagic commit, late choices,
spell-resource commit, movement, reaction collection, markers, target
collection, effect preparation, target results, areas and completion. Selection
prompts happen before that sequence. Some existing late choices occur after
resource spending; changing their cancellation behavior is a separate gameplay
change.

Per-target resource spending stays disabled when the player cast has already
committed its resource. Counterspell is offered once for a multi-target cast.
Preserve awaited prompts and movement triggers: a push through an area must
finish its entry saves before subsequent spell payloads or cast completion.

See [ADR-0012](../../docs/decisions/0012-focused-spell-resolution-and-lifecycle.md)
for the boundaries and preserved save behavior.
