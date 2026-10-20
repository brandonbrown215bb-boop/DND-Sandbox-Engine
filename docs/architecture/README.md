# Architecture

This maps current code ownership. [ADR-0018](../decisions/0018-shared-data-driven-rules-runtime.md)
owns the target shared runtime; the [roadmap](../../roadmap.md) chooses work.
[Mechanics](../mechanics/README.md) owns authoring syntax and supported hosts;
the [slice registry](../planning/vocabulary-slices.md) owns verified boundaries.
The class and creature designs are target specifications, not executable syntax.

## Runtime and content

Godot 4.7/GDScript is the production runtime. `scenes/main.tscn` starts the
game; autoloads under `src/autoload/` retain cross-scene services and state.
Python handles importing, inventories and structure, not a second rules engine.

`DataLoader` reads sorted content directories under `data/core/` and `data/mods/`.
Stable IDs identify definitions; duplicate winners and replacements are explicit
in the central manifest. Curated winning fields remain authoritative while
approved sources fill missing fields. Classes and parent-linked subclasses have
separate registries. See [content loading and editor integration](../content_pipeline.md).

Named class helpers, curated dictionaries, native spell branches and fixed AI
profiles still make rule decisions for unmigrated content. They are migration
inputs, not the pattern for new rules. One migrated action has one execution
owner; supported definitions must work without registering their identity.

## Execution owners

| Boundary | Existing owner and responsibility |
|---|---|
| Encounter and turn flow | `CombatState` coordinates input, bindings, initiative and cast sequence; `CombatTurnBudget` owns action quantities. |
| Spell controls | `SpellCast*` modules own selection, validation, choices, resources, targeting, movement, reactions, results and areas. See the [module map](../../src/spells/README.md). |
| Shared spell programs | `SharedSpell` validates flat payloads; `SharedStepExecutor` executes ordered operations and per-target gates. Flat payloads use automatic, attack or save delivery; mixed attack/save programs use ordered steps. |
| Damage and aftermath | `CombatAction` settles typed weapon and spell damage, reductions, Temporary HP, HP loss, concentration and defeat. Derived damage must not replay parent attacks or payments. |
| Damage links/responses | `DamageLinkRules` distributes one post-reduction occurrence across fixed source-owned recipients; `DamageResponseRules` validates incoming replacements and settled counters. Root/source/depth receipts bound feedback. |
| Child actions | `CombatChildActions` owns transient paid-parent identity, child quantities, chooser state and once-only receipts; ordinary strike/spell/movement paths execute the children. |
| Timed sources and events | `SpellEffects` owns cast identity, clocks and cleanup; `SpellEncounterLifecycle` owns repeat-save scheduling. `source_end_rules` consumes canonical attack, cast, movement, status, equipment, range and damage events. |
| Areas | `CombatSpellZones` owns spatial/turn triggers; terrain and conjuration modules retain native policies for unmigrated content. `LocalRoomSharedSpells` reuses shared execution for bounded exploration casts. |
| Progression | `ClassProgression` owns choices and dependencies; `ClassTraining` revalidates confirmation. `PermanentProgressionRules` owns opt-in starting/multiclass and permanent grant receipts. |
| Resources | `ResourcePoolRules` owns exact-source quantities, capacity, captured dice and exchanges. `RestRules` settles successful rest recovery; `CombatPoolRecovery` owns transient initiative/turn recovery receipts. |
| Casting sources | `SpellPermissionRules` derives class/book/feature/item-copy permissions; `SpellRepertoireRules` owns source-specific preparation; `SpellSlotRules` owns combined ordinary, Pact and fixed-level pools. |
| Stat and aura projections | `SourceBenefitRules`, `ProtectionRules`, `TemporaryHPRules` and `AuraProtectionRules` own derived benefits and source/recipient choices. `AuraRules` publishes live combat membership. |
| Party contributions | `CapturedGrantRules`, `PartyInterventionRules` and `PartyAllocationRules` own committed gifts, helper payments and transient allocations. |
| Ability checks | `EventDialog` captures loaded event/check identity; `EventResolver` settles canonical DC/consequences. `Inventory` supplies benefits from exact owned tool copies. |

`SpellCastContext`, `SpellResolutionContext`, pending choices and callback
generations are transient. Continuations retain settled roll faces, source
payments and original cast costs; resume must not replay them. Source validation
precedes new RNG or costs. Stale choices decline or refuse without affecting a
newer request. Explicit `Character.class_levels` supplies per-class formulas
separately from total level, proficiency and selected slot.

## Important host boundaries

Shared source-end events are verified on their documented combat hosts;
exploration range triggers and arbitrary external condition removal aren't
implied. Effects remain timed and source-owned while suppressed. Direct
Character auras retain distinct giver/bearer/recipient identity; combat exit
clears live membership without erasing timed entry receipts.

Damage links and responses currently use incoming monster weapons and player
flat/ordered shared spells. Recipients settle their own defenses, concentration
and defeat. Extra typed packets retain their settlement history when Temporary
HP absorbs them; later healing does not undo an earlier knockout. Optional
choices on other controllers remain outside those hosts. See [shared spells](../mechanics/shared-spells.md).

Owned zero-HP replacement uses the existing `SharedStepExecutor` event adapter
before defeat. Character and Dictionary hosts retain native Death Ward and
Relentless Rage precedence. Primary weapon poison riders share the original
authorization's consumed flag. Character attempts, lifetime totals and completed-
rest resets are durable; Dictionary history is encounter-local. Both full-save
DTO routes validate latest receipt/reset consistency. Linked/counter optional
pickers, post-roll rescue, general destruction, forms and revival remain open.

Source carriers support fixed additive AC/walking speed on exact equipped
copies, passive progression occurrences and automatic self-casts. Movement
refresh retains spent distance. Named nonstacking, other recipients, arbitrary
payloads and forms remain separate capabilities. Stat protection queries don't
mutate underlying permanent scores; progression uses those underlying values.

Opt-in permanent progression preserves primary weapon/armor/skill choices and
permanent grant receipts. Native secondary features, subclass/casting progression
and catalog conversion remain separate. Source-specific casting retains exact
ability, preparation, component and payment ownership. Ritual time is normal
casting time plus ten minutes; effects start after successful clock settlement.
Broader targeted/spatial/ordered rituals require their own controls.

Numeric exchanges can pay with ordinary/Pact slots, captured dice or exact
backpack-copy quantities and fill numeric pools on eligible actors. Both sides
validate before mutation; same-pool aliases and missing copies refuse. Other
destinations and conditional/post-roll exchanges remain outside this host.

Loaded event checks retain task/purpose/origin and exact tool matching. Owned
post-roll bonuses and rerolls keep their captured receipts, floor stages and
payment policy. Direct/unidentified checks don't automatically gain that host.
Encounter projections preserve represented vulnerability, senses, proficiency
and fly/climb speeds, but don't invent missing source fields or general flight AI.
Countercharm supports flat shared Frightened saves and native Charmed saves;
shared Charmed grants and Gnomish Cunning aren't supplied by that connection.

## Party, world and durable identity

`PlayerManager` owns logical local seats; `PartyManager` owns four stable party
slots, companions and leadership. Physical devices are transient. The current
campaign uses shared-keyboard play. Commands resolve owned production records,
so HUD-supplied metadata cannot decide costs or grant abilities.

`LocalRoomRules` owns plain room/object transactions; `LocalRoomView` controls
exploration; `LocalRoomCombat` binds/captures the same geometry and objects.
`DungeonPersistence` validates room snapshots; GameManager retains visited
dungeons. `InventoryCopies` separates exact-copy identity from definitions and
validates transfer destinations before removing sources.

GameManager owns campaign time. Completed combat rounds advance six seconds;
exploration, travel, casting and rests declare durations. Source-owned effects
and room areas expire on that clock, including unloaded snapshots.
`CombatPerception` supplies modeled illumination, senses and wall LOS. Exact
volumes, cover and unmodeled observers remain gaps. Room/combat floor, altitude
and movement modes do not certify every spell, footprint or form.

Owned familiar/steed records retain identity, HP and lifetime independently of
encounter projections and party slots. `CorpseRules` distinguishes death from
unconscious zero HP while keeping character identity and gear.
`CreatedCreatureRules` keeps lasting Undead existence separate from expiring
control. Animate Objects still lacks validated normal casting, initiative,
commands and room integration; Finger of Death's created Zombie, reversible
forms and authored NPC/illusion interactions remain unfinished. See [world and
spell foundations](../mechanics/spell-foundations.md) for concrete limits.

## Persistence and presentation

`SaveManager` validates complete plain DTOs before changing live managers.
Schema 2 uses `ruleset_id: dnd-2024-srd-5.2.1` and `user://saves/dnd2024/`.
Legacy `user://saves/` files are incompatible and never automatically migrated.
Safe writes use temporary/backup files. Saving is limited to overworld and
explicit dungeon-entry checkpoints; combat, events, transitions and active
local rooms are unsaveable. Durable changes enter the next allowed checkpoint.

Reconstruction restores choices and remaining resources without replaying
permanent grants. Optional fields retain older schema-2 compatibility; missing
required content refuses before replacing the session. Pending workflows and
a generic future rules-state envelope aren't serialized. ADR-0023 removes
blanket migration planning as a prerequisite, not correct ownership/time wiring.

The grimoire VTT shell reads resolver-owned arithmetic. `ActivityHistory` keeps
at most 200 campaign records with stable sequence IDs. Widgets reveal recorded
results without rerolling. Invalid optional activity history can be omitted
diagnostically without rejecting an otherwise valid campaign.

## Map integration

Future wall import should retain world-coordinate segments aligned with one map
image and the hex overlay, with separate movement and sight restrictions. Reuse
existing doors, A*, terrain and turn budgets. A shared segment query must serve
player/AI paths, actual movement and visibility; door state changes refresh all.

The first sample should cover a solid wall, a see-through blocking window,
closed/open/locked doors, corners, narrow passages and creature clearance.
Resolve map origin/scale and segments bisecting hexes; whole blocked cells aren't
equivalent thin walls. Refused movement spends no distance; supported door state
recovers at existing checkpoints. This aligns with S-179/S-184/S-185/S-190 without
finishing their broader scopes. Sound/light attenuation, directional restrictions,
levels/surfaces, moving barriers and arbitrary scripts remain separate work.
