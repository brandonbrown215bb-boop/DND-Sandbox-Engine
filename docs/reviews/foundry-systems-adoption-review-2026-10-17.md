# Foundry systems worth adopting

Reviewed 2026-10-17 against Foundry 14.369 and dnd5e 6.0.6 from the supplied
portable installation. This extends the [import and wall plan](../planning/foundry-adoption.md).
It is research for selected work, not a new delivery sequence or acceptance claim.

Foundry is most useful as a collection of worked examples for our remaining
mechanics. The strongest additions are suppression without deletion, shared
recovery settlement, source-owned aura benefits, invocation-specific spell
profiles, form policies and parameterized summons. These can save substantial
design and content-mapping work. They do not supply our ordered execution,
automatic creature decisions or durable once-only settlement.

## What to use first

The batch numbers below refer to the existing [018–030 outline](../planning/vocabulary-batches-018-030.md),
not a proposal to reorder it. Slice finish lines remain in the [registry](../planning/vocabulary-slices.md).

| Opportunity | What it saves us | Where it fits | Recommendation |
|---|---|---|---|
| Suppression keeps the original effect and clock | Avoids reconstructing effects and accidentally refreshing them | Batch 020; S-074/S-075, later S-203 | Adopt the mechanism; track each suppressing source explicitly |
| Recovery events feed one settlement path | Avoids separate dawn, rest, item and activity recovery implementations | Batch 024/S-063; S-070/S-071 | Extend our existing pool/rest owners |
| Aura membership differs from creature movement | Prevents moving/appearing auras from pretending the creature walked | Batch 020/S-080; S-184 | Adopt the event distinction and source-owned grants |
| A granted spell gets an invocation-specific profile | Reuses one spell body with the granting item's ability, DC, components and payment | Batch 021, later S-140/S-141/S-148 | Translate into our invocation context |
| Dice transformations operate on terms and run once | Avoids multiplying fixed bonuses, costs or already transformed dice | Batch 025/S-123–S-125 | Borrow the stage boundaries for our supported formulas |
| Form eligibility and retained statistics are separate policies | Gives a concrete checklist for Wild Shape/Polymorph and equipment exceptions | S-163/S-164 | Adopt policy data; retain our original actor identity |
| Summon formulas distinguish owner, template and invocation | Makes one template serve different casters without editing the catalog | S-154/S-155 | Adopt captured contexts and per-copy creation |
| One enchantment owns its changes and child permissions | Makes cleanup remove only one source's projected abilities | S-126/S-127, S-148/S-149 | Reuse our source carriers for the ownership |

## Effects, time and rests

### Suppression is a mask, not removal

Effect preparation computes suppression from conditions, immunity, antimagic,
item state and inactive origins; suppressed effects are skipped when applying
changes. The original effect document remains. See
`module/data/abstract/active-effect-data-model.mjs:50,178`,
`module/data/active-effect/condition.mjs:56` and
`module/documents/active-effect.mjs:190,627`.

Our useful version retains the exact effect, deadline and every suppressing
source, then derives whether its benefits apply. Ending one suppressor must not
end another or restart the effect. This is particularly valuable for S-074/S-075
and later magical-property suppression. Foundry's condition-immunity behavior
is an implementation example, not authority that every immunity clause must
suppress an already acquired condition.

### Clock, turn and rest producers can share recovery settlement

Calendar handling counts crossed midnight/sunrise/sunset events and routes them
to item recovery. Items and child activities use the same spent-use recovery
wrapper; NPC turn recharge reaches that wrapper too. See
`module/data/calendar/calendar-data.mjs:309–403`,
`module/data/item/templates/activities.mjs:345–385` and
`module/data/shared/uses-field.mjs:187–236`.

Extend `src/combat/combat_pool_recovery.gd` and `src/characters/rest_rules.gd`
with event producers and exact occurrences rather than replacing accepted
S-007/S-062. Capture the relevant clock interval and declared recovery policy;
settle the exact pool once. Foundry uses first-matching recovery profiles and
bounded formulas across skipped time. Neither policy is universally correct
for all of our content. Its strict hour-boundary comparison also leaves exact
sunrise endpoints worth testing; that is a static edge, not a reproduced bug.

Rest code collects actor/item updates, deletions, rolls and expiry into a result
before final application (`module/documents/actor/actor.mjs:2328–2418`). That
inspectable consequence list is useful for S-070/S-071. The entire Foundry rest
is not atomic: Hit Dice can already be spent earlier (`:2257,2272`), and hooks,
clock advancement and document updates remain separate. Rest interruption,
special durations and benefit-only recovery still need their own contracts.

Condition levels also provide a useful presentation example: one level derives
icons and cumulative statuses (`module/data/active-effect/condition.mjs:63,139`).
That can inform S-069's UI, but it does not replace source-specific counters,
repeat-save scheduling or transition history.

## Spell permissions, rolls and consequences

### A spell body can be reused through a source-specific wrapper

The Cast activity caches a spell under the granting activity, preserves source
identity, applies an enchantment and delegates to the ordinary spell use path.
Its invocation overrides include activation, duration, range, target, ability,
ignored properties and attack/DC settings. See
`module/documents/activity/cast.mjs:52–96,115–192`.
Linked-activity consumption stages parent costs separately and avoids charging
the same explicit target twice (`module/documents/activity/mixin.mjs:566–629,1247–1253`).

This is a concrete recipe for an item or innate permission casting an existing
spell without adding a second spell implementation. In our engine, retain the
granting acquisition/copy, spell definition, invocation overrides and exact
payment in the prepared invocation. Do not turn the cached spell into a newly
learned permanent spell. This helps Batch 021 and later cast-local changes and
children; it does not finish pending-cast rollback or interrupted parents.

### Keep dice, components and settlement stages distinct

Critical preparation has an explicit already-configured guard and transforms
dice terms separately from fixed numbers. Complex expressions retain operator
precedence and damage flavor (`module/dice/damage-roll.mjs:138–260`). Optional
numeric multiplication and powerful-critical settings are configurable variants,
not rules authority. For Batch 025, apply only the declared transformation to
eligible dice/components once, preserving cost dice and frozen siblings. Extend
the formula subset we actually support; importing a complete VTT dice language
is unnecessary.

Damage aggregation groups by type and, when requested, properties; the actual
application UI requests property-aware grouping
(`module/dice/aggregate-damage-rolls.mjs:20–40`,
`module/applications/components/damage-application.mjs:268–275`). Actor damage
calculation retains per-component adjustment flags before HP mutation
(`module/documents/actor/actor.mjs:785–813,855–965`). The useful idea is an
explainable calculation result feeding application and preview. Hooks mean the
calculation path is not proven side-effect-free.

Our accepted S-109/S-110 already preserve typed components and consequences;
do not rebuild them. Retain properties until bypass/resistance decisions and
extend the existing result for new consumers. Foundry's damage Apply handler
calls damage application on every click (`damage-application.mjs:601–611`);
the button does not establish our once-only occurrence contract.

Filters are another boundary to keep: Foundry compares arbitrary property paths
with ordinary JavaScript values (`module/filter.mjs:103–109,241–242`). A missing
comparison may become true under negation. Our closed fact vocabulary and
`PREDICATE_UNKNOWN` in `src/combat/shared_step_executor.gd` are preferable. Convert
only predicates whose facts and semantics we can represent; unsupported facts
must remain unavailable rather than silently enabling a benefit.

## Forms, summons and item projections

### Forms need two policies, and simple modes need less machinery

Selection profiles constrain level/CR/size/type/movement; a separate policy
defines retained, replaced and merged statistics, spells and effect origins.
Actual consumers handle abilities, saves, skills, features, HP, temporary HP,
AC and effects (`module/data/activity/transform-data.mjs:24`,
`module/data/settings/transformation-setting.mjs:23`,
`module/documents/actor/actor.mjs:2868–3053`). Use that as the S-163/S-164
authoring checklist, then check each rule against our selected authority.

Do not adopt replacement Actors and token switching (`actor.mjs:3097–3170`).
Reversion writes back an allowlist of HP, temporary HP and retained spell slots
(`:3242–3253`); this is not a general reconciliation of every copied item's spent
uses, contents or changed equipment. Our same-actor and no-refill promises are
stronger. Automatic HP/concentration-ending reversion was not established by
the traced transformation/reversion paths.

There is also a much smaller effect-only mode path. It identifies a selected
profile by activity UUID plus profile ID, removes only sibling modes of that
source, and batches changes (`module/documents/activity/transform.mjs:151,228–275`).
Borrow that for simple stances or modes before reaching for full monster-stat
projection. Reselecting a profile resets its duration in Foundry; our policy
must explicitly permit any reset.

### Summons separate owner values from template values

Summon creation combines caster data with a nested template context, captures
source/activity/profile/level/ability, then computes each spawned copy's changes.
Consumers cover proficiency, AC, HD, HP, temporary HP, size/type, attack, save
and damage/healing (`module/documents/activity/summon.mjs:157–181,254–459`).
The schema is in `module/data/activity/summon-data.mjs:22–67`.

That clears much of the field-mapping work for S-154/S-155: preserve the template,
capture invocation inputs and create independent exact identities. It is not
companion control. The traced path still uses manual placement, and its linked
actor option deliberately shares state (`summon.mjs:491–541`). Commands,
uncommanded behavior, initiative, legal space and universal cleanup remain
separate S-155–S-158 work.

### An owning enchantment can project statistics and child abilities

An enchantment attaches to an exact item with its source/profile metadata and
optional concentration dependency. It applies prepared changes without rewriting
base fields and can create rider activities, effects and items whose dependency
points back to that enchantment (`module/documents/activity/enchant.mjs:149–217`,
`module/documents/item.mjs:462–489,573–581`,
`module/data/active-effect/enchantment.mjs:254–334`). Cleanup groups the owned
children (`module/documents/active-effect.mjs:773–787,843–869`).

Use one projection receipt to own changed statistics and granted permissions,
extending our accepted S-049 carriers. This helps S-126/S-127 and S-148/S-149.
Displayed enchantment target counts are not demonstrated admission guards;
the Apply/drop path does not establish a hard target-capacity check. Manual
activation also does not establish automatic triggers or parent budget timing.

## Space, perception and world procedures

### Membership and travel are different events

Core distinguishes region enter/exit from move-in/move-out/move-within. Token
updates compare membership sets, while movement-specific events require passed
waypoints (`common/constants.mjs:2061–2116`,
`client/documents/token.mjs:2824–2859`). Region changes/deletion produce their
own exits and activation events (`client/documents/region.mjs:2437–2499`).

This is the right distinction for moving auras and newly created areas. Extend
`src/spells/combat_spell_zones.gd`; its movement/start/end/source-cleanup hosts
already exist. Keep our ordered settlement: Foundry region handlers dispatch
with `Promise.allSettled` (`region.mjs:2553–2559`), not an ordered rule program.

Aura behaviors filter disposition/size/type, create effects attributed to the
exact behavior and remove only that origin's copies on exit
(`module/data/region-behavior/apply-active-effect.mjs:24–87,149–191`). Geometry
can be stationary or token-attached while keeping caster/item origin separate
(`module/canvas/template-placement.mjs:87–177`). This is useful for S-080/S-184.
It does not establish lingering benefits, arbitrary predicates, linked-token
edge cases or full height/cover behavior; template code explicitly leaves
height and around-wall Fireball handling unfinished.

### Ask whether this observer detects this target

Detection separates enabled sense, observer/target status, range and obstruction
(`client/canvas/perception/detection-mode.mjs:88–186,363–373`). System blindsight
supplies a distinct policy (`module/canvas/detection-modes/blindsight.mjs:5–61`).
Use this query structure when extending `src/combat/combat_perception.gd` for
S-190/S-191. Canvas visibility unions the current user's active observers
(`client/canvas/groups/visibility.mjs:869–899`); it cannot serve as an individual
attacker's sight query. Tremorsense snippets also do not prove shared-surface
propagation, and detection outlines do not supply discovery memories or all
attack consequences. S-188/S-194 remain separate.

### Tables and portals can stay declarative

RollTable normalizes weighted ranges, supports drawn/no-replacement state and
bounds nested selection (`client/documents/roll-table.mjs:98–139,213–235,264–342`).
It returns result documents/chat; an Actor or spell reference is not automatically
an executed encounter or cast. Missing nested UUIDs are quietly skipped
(`:318–323`). Borrow row/reference shapes for S-214/S-215 while retaining chosen
outcomes, exact child settlement and missing-capability refusal under S-222/S-223.
Our `src/events/event_system.gd` already provides basic weighted selection.

Portal regions store destinations and relative/center/random arrival. Move-in
triggers distinguish displacement, and pending choices recheck source membership
(`client/data/region-behaviors/teleport-token.mjs:34–138,172–200`). That supports
simple imported Ravenloft links without executing arbitrary scripts. However,
arrival placement minimizes overlap over bounded attempts rather than proving
legal empty space (`client/documents/region.mjs:1978–2017`). S-177/S-184 and legal
arrival still need our checks; cross-scene partial-write recovery is unverified.

## Smaller useful examples

| System | Mechanism to borrow | Boundary |
|---|---|---|
| Containers | Flat exact-copy IDs plus parent IDs; copy a subtree with a complete ID remap, reject self/descendant containment; derive recursive weight (`physical-item.mjs:19`, `container.mjs:110–175,218–248`, `item.mjs:1303–1334`, `base-actor-sheet.mjs:1745–1758,1821–1823`) | Helps S-196/S-167. Capacity descriptions are not mass/volume admission enforcement; cross-owner copy/delete is not an atomic transfer |
| Advancement | Remember exact granted/modified item/effect IDs and reverse only owned changes (`advancement/item-choice.mjs:117–293`, `advancement/modify-item.mjs:36–105`) | Reuse accepted S-045–S-048 receipts. A fallback fresh source copy must not refill a previously spent acquisition |
| Restricted action pools | Separate legendary/mythic/crew resources and explicit reset events (`module/config.mjs:1057`, `module/data/actor/npc.mjs:559`, `activity/mixin.mjs:566–570`) | Helps S-160. Ordinary Action/Bonus/Reaction labels are not demonstrated enforcement of every budget or off-turn window |

## What to retain from our own engine

Keep exact source/copy ownership, unavailable-fact refusal, ordered steps,
captured choices/results, source-specific cost settlement and allowed-checkpoint
saves. Foundry's manual chat controls, document hooks, GM ownership and optional
dependencies do not replace these contracts. Imported content is a new consumer
of our supported behavior, not acceptance of its description.

One concrete caution for Batch 019: HP-loss concentration prompting observes an
actor update, and some prompt buttons later call `actor.endConcentration()`
without retaining the original maintained effect
(`module/data/actor/templates/attributes.mjs:678–702`,
`module/data/chat-message/save-message-data.mjs:142–162`,
`module/documents/actor/actor.mjs:1130`). Static inspection therefore leaves a
stale prompt capable of targeting whatever concentration is current. This was
not reproduced live. Our implementation must bind to the original source and
final damage occurrence; do not copy a generic “end current concentration” button.

The checkpoint remains **69/226 accepted, 157 remaining**. No finished slice was
reopened, no upcoming finish line changed, and no runtime/importer was added.
Use the relevant recipe when its slice is selected; the research does not
justify a separate Foundry runtime or a roadmap detour.

## Evidence and limits

The local evidence directory is
`.artifacts/planning/foundry-deep-review-2026-10-17/`:

- `source-manifest.json` retains SHA-256 identities and 61 inert source copies
  (1,890,342 bytes). `module/` references above resolve under `sources/system/`;
  `client/` and `common/` resolve under `sources/core/`. Shorter item/advancement
  paths in the last table resolve under their `module/data/` or
  `module/documents/` owner described in `actors-inventory.md`.
- `time-effects.md`, `actors-inventory.md` and `world-procedures.md` retain
  detailed source chains, current-engine comparisons and unresolved cases.
- `rea-evidence.json` retains complete Evidence for two focused static analyses;
  `rea-summary.json` records selections and coverage. System parent:
  `ev_f7427fec775c7d37c0d42f1c9e0bf50146441fa2118345f36c73b35d15944def`
  (10 selected modules, 100,679 bytes, zero parse failures). Core parent:
  `ev_88e3cdc76b2355b27d0ec161b605f1fe24c46ff84aa8f9044540102447bedfe3`
  (6 selected modules, 217,829 bytes, zero parse failures).

Both REA graphs remain partial: 395 system and 644 client files are unselected
in those respective analyses; dynamic calls and unselected dependencies remain
unknown. Additional direct source inspection supplies the chains above. Earlier
review/module/wall evidence remains in its existing artifact directories.
System source was recovered inertly from the shipped source map; no bundle,
script or macro was executed. Package/system/bundle/source-map hashes still
match the initial investigation. The local copied source is research evidence,
not game content or a new redistributable dependency.

These findings establish static consumers and design opportunities. Live
multiplayer permissions/races, crash recovery, every rules exception, linked
multi-token actors, 3D area geometry and full gameplay correctness were not
verified. No Godot checks were needed for this documentation-only review;
production proof belongs to each selected implementation.
