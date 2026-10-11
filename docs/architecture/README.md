# Architecture

Current boundaries inspected 2026-10-09. This is an implementation map,
not a rules-completion claim. [ADR-0018](../decisions/0018-shared-data-driven-rules-runtime.md)
owns the target architecture; [roadmap](../../roadmap.md) selects the work.

## Runtime and content

Godot 4.7/GDScript is the production runtime. `scenes/main.tscn` starts the
game. Autoloads under `src/autoload/` retain cross-scene services and state.
Python imports/inventories inspect JSON and source; they are not a second
rules implementation or gameplay oracle.

`DataLoader` loads sorted content-type directories under `data/core/` and
`data/mods/`. Stable IDs select records; every collision needs an explicit
winner/replacement in `data/content_manifest.json`. Curated winning fields
remain authoritative while approved imported descriptions fill missing fields.
Base classes and parent-linked subclasses have separate registries.
Unsupported records remain unavailable; accepted loader shape is not proof
that every described trait executes. See [content pipeline](../content_pipeline.md).

Today, class-specific helpers, curated dictionaries, spell dispatch branches
and fixed AI profiles still make rule decisions. `ClassFeature` offers a
bounded self-activation contract; `ClassProgression` shares some choices but
retains named-class paths. `AIController` selects native behavior profiles and
`AICommand` accepts a bounded command vocabulary. These are migration starting
points, not the intended extensibility boundary.

## Current spell execution

`execution: "shared"` uses `SharedSpell` validation and ordinary payloads
without registering each spell ID. The current contract supports automatic,
attack **or** save delivery, typed damage, healing, Temporary HP, condition
grants/removal, targeting geometry and bounded scaling. Combining attack and
save fields on one flat payload is rejected. Explicit ordered `steps` compose
attack, save, damage and effect operations with per-target gates through
`SharedStepExecutor` ([ADR-0019](../decisions/0019-shared-ordered-execution-and-zero-hp-replacement.md)).
Pre-roll replacement, damage rerolls and concentration reactions resume at the
pending actor and step while retaining settled effects and cast-wide costs.

`CombatState` coordinates input, encounter bindings, turn order and the cast
sequence. Focused `SpellCast*` modules own selection, validation/choices,
resources, targeting, movement, reactions, markers, results and areas.
`SpellResolver` dispatches existing attack/save/projectile and special result
families; `CombatAction` also owns shared weapon and typed-damage settlement.
`SpellCastContext` and `SpellResolutionContext` are transient, never save data.
The [spell module map](../../src/spells/README.md) locates current code.

`SpellEffects` owns cast sources, clocks and cleanup. Benefits and persistence
have focused modules. `SpellEncounterLifecycle` coordinates repeat saves and
encounter expiry; `CombatSpellZones` owns spatial/turn triggers and source-owned
areas. Terrain/conjuration modules retain existing native spell policy.
`LocalRoomSharedSpells` reuses shared resolution for bounded exploration casts.
New shared capabilities should replace native policy progressively without
duplicating damage or cost. Availability and full rules support are distinct.

## Party, world and durable identities

`PlayerManager` owns logical local seats. `PartyManager` owns four stable party
slots, characters, companions and leadership. Physical devices are transient;
shared-keyboard play is the current boundary ([ADR-0001](../decisions/0001-shared-keyboard-hot-seat.md)).
Combat commands resolve owned production records, so HUD-supplied metadata
cannot determine costs or grant abilities. `CombatTurnBudget` owns shared budgets.

Authored local rooms reuse dungeon geometry and HUDs. `LocalRoomRules` owns
plain room/object transactions, `LocalRoomView` controls exploration and
`LocalRoomCombat` binds/captures the same cells and objects. `DungeonPersistence`
validates snapshots; GameManager retains visited dungeons instead of regenerating
them. `InventoryCopies` separates per-copy state/identity from catalog projections;
transfers validate destinations before removing sources ([ADR-0013](../decisions/0013-local-rooms-and-item-copies.md)).

GameManager owns the campaign clock/ledger. Combat advances six seconds per
completed round; authored exploration, travel, casting and rests declare their
durations. Source-owned durable effects and room areas expire on that clock,
including unloaded snapshots. `CombatPerception` shares modeled illumination,
senses and wall LOS; exact volumes, cover and unmodeled observers remain gaps.
Floor/altitude and movement modes exist in bounded room/combat paths; their
presence does not certify every movement spell or form.

Owner-bound familiar/steed records retain identity, HP and lifetime separately
from encounter Character projections. They remain outside party slots and
cannot prevent a party wipe ([ADR-0014](../decisions/0014-owned-creature-lifecycle.md)).
`CorpseRules` distinguishes actual death from unconscious zero HP on the
original party Character; revival keeps identity and gear
([ADR-0015](../decisions/0015-party-corpses-and-recovery.md)).
`CreatedCreatureRules` uses a campaign ledger: lasting Undead existence is
independent of creator life and expiring control. Encounter projection settles
HP/position back to the ledger ([ADR-0016](../decisions/0016-created-undead-existence-and-control.md)).
Animate Objects hooks remain unfinished; see [current status](../operations/current.md).

## Persistence and presentation

`SaveManager` validates complete plain DTOs before changing live managers.
Current schema 2 uses `ruleset_id: dnd-2024-srd-5.2.1` and
`user://saves/dnd2024/`. Legacy `user://saves/` files are listed as incompatible
and never automatically migrated. Safe writes use temporary/backup files.
Saving is limited to overworld and explicit dungeon-entry checkpoints;
combat, events, transitions and active local rooms are unsaveable. Durable
world changes enter the next allowed checkpoint ([ADR-0004](../decisions/0004-staged-2024-rules-and-save-boundary.md)).

Reconstruction restores saved choices and remaining resources without replaying
permanent grants. Optional fields preserve older schema-2 compatibility; missing
required content rejects before replacing the session. A generic future rules
state envelope and pending-workflow serialization are not implemented.
Do not infer mid-decision save support from proposed continuation objects.

The shared desktop VTT shell uses the grimoire presentation. `ActivityHistory`
keeps at most 200 campaign records with stable sequence IDs. Domain resolvers
publish final arithmetic; UI widgets reveal it without rerolling or recomputing.
Versioned activity records have bounded validation; invalid activity history
can be omitted diagnostically without rejecting an otherwise readable campaign.
See [ADR-0003](../decisions/0003-player-vtt-shell-and-activity-history.md).

## Migration contract

Use one typed data runtime shared across rule domains. Generic operations may
query the world, roll, branch, choose, modify, grant, spawn or transition; they
must not dispatch on content identity. Definitions stay separate from mutable
instances, sources, owners/controllers and encounter projections. Each migrated
action has one execution owner, with costs/results committed once across prompts.

Retain existing loading, command, damage, world and save boundaries as adapters
where useful. Do not make another interpreter for monsters or another rules
engine in Python. Add only the capability needed by a verified rule. A missing
observable world capability can require a generic adapter; a unique content ID
does not justify a native handler. Existing helpers may maintain unmigrated
behavior until the shared replacement is accepted.

The [class design](data-driven-2024-class-execution-plan.md) and
[creature design](data-driven-2024-monster-execution-plan.md) contain proposed
language, source gaps and adversarial cases. They are not executable schemas.
Versioning, migrations and fictional adjudication require concrete acceptance
before release. [Testing](../testing.md) owns validation practice; dated gate
reports and reviews supply historical evidence only.
