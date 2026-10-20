# Architecture

This is an implementation map; the current checkpoint owns the latest accepted
evidence. It is not a rules-completion claim. [ADR-0018](../decisions/0018-shared-data-driven-rules-runtime.md)
owns the target architecture; [roadmap](../../roadmap.md) selects the work.
[ADR-0023](../decisions/0023-vocabulary-first-delivery-and-bounded-world-judgment.md)
clarifies vocabulary-first delivery, bounded illusions/campaign Wish and the
owner's current save priorities. Its planning decisions do not add runtime support.

## Owned zero-HP replacement (033; VS-111/112 accepted)

`SharedStepExecutor` extends the existing event adapter with source eligibility,
represented massive-death exclusions, shared HP/DC formulas and exact-source
attempt/reset/payment receipts. `Character` retains history and its lifetime
attempt high-water total. `RestRules` owns completed-rest resets, including
retained detached histories; both SaveManager DTO paths validate before restore.
Class acquisition copies typed rule occurrences so reacquisition invalidates old
transient authorizations without refunding durable history.

Optional primary-target spell damage reuses the owned damage continuation;
incoming monster weapons collect authorization before attack and share its
consumed flag with their primary riders. Saved receipts bind the latest attempt
to its reset generation, with count/receipt consistency checked before restore.
The actual zero-HP
boundary rechecks the live source, unchanged policy, eligibility and pool before
RNG. Attempted payment/history settle before the save; result payment reserves
its exact numeric quantity until success/failure. Native Death Ward/Relentless
Rage and existing damage/concentration owners keep their precedence. No new
interpreter, generic post-roll rescue menu or mid-action save point is added.
See [authoring](../mechanics/shared-spells.md#authored-zero-hp-eligibility-and-owned-attempts-batch-033-vs-111112-accepted),
[ADR-0034](../decisions/0034-source-owned-zero-hp-attempts.md) and the
[builder report](../../.artifacts/planning/vocabulary-reports/batch-033-build-validation.md).
The [acceptance record](../reviews/batch-033-acceptance.md) owns the verified
hosts and remaining limits; no catalog-wide support is implied.

## Shared damage links and responses (031/032; VS-107–110 accepted)

`DamageLinkRules` distributes one post-reduction occurrence between exact
source-owned recipients; `DamageResponseRules` validates timed replacement and
settled counter policies. `CombatAction` remains the typed settlement owner for
original and derived damage. Root/source/depth receipts bound feedback without
replaying attacks or payments. Existing monster-weapon and flat/ordered spell
controllers settle actual recipient concentration and defeat; executed extra
typed packets and captured knockout survive Temporary HP and later healing.

Ordinary SpellEffects records and existing save validators retain policy,
owner, recipient and deadline; causal state and pending callbacks stay transient.
See [authoring](../mechanics/shared-spells.md#linked-incoming-damage-batch-031-vs-107108-accepted)
and [independent acceptance](../../.artifacts/planning/vocabulary-reports/batch-031-032-acceptance-review.md) for production evidence and controller limits.
No broader damage host or catalog support is implied.

## Recipient HP and aura entries (027; VS-84/85/86 accepted)

`TemporaryHPRules` owns recipient decisions, exact supplier payment and captured
HP links. `AuraProtectionRules` owns source/recipient entry receipts and selection;
`AuraRules` publishes actual combat membership; CombatState clears it on scene
exit while retaining timed entry receipts. Character AC/save queries derive
fixed bonuses without acquiring state. SaveManager checks both DTO routes and
participant links before restore. See [authoring and bounded hosts](../mechanics/temporary-hp-and-entry-protections.md)
and [ADR-0032](../decisions/0032-recipient-temporary-hp-and-aura-entry-receipts.md).

## Paid parents and child continuations (028; VS-97–99)

`CombatChildActions` owns encounter-local parent identity, chooser state,
remaining children and exact-once receipts. CombatState's ordinary strike, spell
and movement paths execute those children with a local action waiver. Exact
Attack/Flurry quantities, item copies and self-healing uses keep their existing
owners. Weapon rider receipts and spell contexts retain parent source and
classification. Prepaid combat slots reach cancellation with their actual pool;
spell finish remains the owner of successful host Ward settlement. Awaited
callbacks revalidate the exact parent/child before touching controls. See
[authoring](../mechanics/attack-unit-substitution.md),
[ADR-0033](../decisions/0033-parent-action-child-continuations.md) and
[independent acceptance](../../.artifacts/planning/vocabulary-reports/batch-028-completion-review.md).

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

## Permanent progression (018; VS-68/69 accepted)

`PermanentProgressionRules` owns opt-in starting/multiclass and permanent level
grants on Character. Ordered class history distinguishes class and total levels;
exact entry receipts prevent acquisition replay. Milestones create pending levels,
and ClassTraining confirms one chosen class with stale-state and inventory-space
preflight. Existing ClassProgression owns score/CON arithmetic; inventory copies
and applied totals persist through current checkpoints. SaveManager validates
both DTO paths before restore. Primary passive proficiency choices are retained;
secondary native features, subclass/casting progression and catalog conversion
remain outside this host. See [authoring](../mechanics/permanent-progression.md)
and [ADR-0030](../decisions/0030-permanent-acquisition-receipts.md). Existing
native classes retain their current route. Independent
[review](../../.artifacts/planning/vocabulary-reports/batch-018-review.md) repaired
blank-character registration after a refused creation and rejected ignored
primary-choice fields; those choices support weapon/armor/skill arrays only.

## Casting sources and slot pools (021–022; VS-76–81 accepted)

`SpellPermissionRules` derives current class/book/feature/item-copy permissions.
Commands rebuild production spell data and preserve the selected source ability,
policy and allowed payment; resource commitment revalidates after choices.
`SpellRepertoireRules` owns opted-in per-source preparation and replacement
receipts, validated on both full-save DTO paths without acquisition replay.
`SpellSlotRules` combines supported full/half-up ordinary contributions while
retaining separate Pact pools and fixed-level Arcanum uses. Reaction casting
retains the selected pool through the same payment boundary.

Character-sheet exploration controls invoke exact source-specific rituals through
`ClassProgression`, with physical components, normal-plus-extra time and prior
concentration cleanup. Completion rechecks actor/source/components after clock
settlement; the effect begins afterward. The bounded host and production evidence
are in the [independent acceptance review](../../.artifacts/planning/vocabulary-reports/batch-021-023-acceptance-review.md),
[casting contract](../mechanics/spell-permissions-and-preparation.md) and
[slot/ritual contract](../mechanics/spell-slots-and-ritual-casting.md).

## Current class-feature resources

`ClassProgression` owns filtered passive feature-option acquisition and opt-in
replacement. Proposed selections are checked before mutation against explicit
prerequisites and trained spell capacity/list dependencies; retained sources
preserve their proficiencies. `ClassTraining` refreshes dependent pending picks
and revalidates stale buttons. Full-save preflight uses the same represented
class eligibility and every selected spell-grant occurrence, with separate
cantrip/leveled lists and earned primary features. Existing checkpoint storage
remains; see [progression choices](../mechanics/progression-choices.md).

`ResourcePoolRules` stores bounded numeric capacity/current quantities on the
owning Character under an exact source-instance ID. Shared `ClassFeature`
activation and its combat menu/command path carry that identity through
availability and spending. Capacity uses the shared formula evaluator; growth
does not refill and shrink clamps remaining quantity. SaveManager checkpoints
restore these quantities without acquisition replay.

Batch 023 extends the same feature/command/HUD exchange path with exact
ordinary/Pact slots, captured dice or eligible backpack-copy quantities as
payment. Numeric destinations may belong to self or an eligible active party
member. Both sides validate before synchronous mutation; stale copies never
substitute siblings, and resolved same-pool aliases refuse. Existing inventory
and pool DTOs preserve results at allowed checkpoints. VS-82/83 are independently
accepted; other destination types and conditional settlement remain outside this
host. See the [exchange contract](../mechanics/shared-resource-pools.md#bounded-resource-exchange--batch-023-accepted).

`RestRules` applies authored fixed/fill recovery after matching successful
Short/Long completion for currently eligible party actors. Source-owned
weapon-hit rider limits reuse CombatAction's actual active-turn serial and exact
actor/source/option/target keys. Their locks stay transient. These numeric-pool,
rest and rider slices have retained production evidence. Bounded dice activation,
numeric exchange, timed AC grants, next-melee-hit fixed typed grants and optional
expiry/dismissal cooldowns are also checked. Source-owned expiring Temporary HP,
numeric lookup and prior-step typed damage
totals now have bounded evidence too. Broader grant/acquisition domains,
other recovery/limit scopes and general subscriptions remain unfinished. See the [resource contract](../mechanics/shared-resource-pools.md)
and [checked subsets](../reviews/dnd-code-vocabulary-gap-checklist.md#verified-subsets-to-mark-off).

Batch 020 extends `AuraRules` membership to condition-only auras and retains
source/bearer/recipient identities in the live combat projection. Conditions
remain source-owned and keep ticking while suppressed; overlapping bearers
remain independent. Independent review accepts the direct Character aura host
as VS-73/74/75. Current host limits are recorded in the
[suppression and aura contract](../mechanics/condition-suppression-and-auras.md)
and [review report](../../.artifacts/planning/vocabulary-reports/batch-020-review.md).

Batch N adds `CombatPoolRecovery` as encounter-local state beside the existing
pool quantity owner. CombatState emits actual settled Initiative and tracked
turn-start boundaries; fixed/fill/floor policies and optional exclusive source
groups reuse ResourcePoolRules settlement. Same-event replay and stale source/
actor/definition choices refuse; pending menus/locks never enter saves. This
numeric Character-host boundary is accepted as VS-62 after independent
[source/evidence review](../../.artifacts/planning/vocabulary-reports/batch-N-review.md).
Native resource conversion, dice-pool combat recovery and recovery options with
secondary payments/effects remain separate work. See the
[authoring contract](../mechanics/shared-resource-pools.md#combat-boundary-recovery-vs-62-independent-review-accepted).

Batch J adds numeric-pool weapon-rider round/roll/active-grant limits and an
exact-source conditional pool-payment waiver. Initiative owns the round; action
budget refresh preserves that context. Settled weapon receipts bind the real
actor, target and captured weapon profile. Active-grant `used_rider_options`
persists on the existing timed AC modifier; transient roll/round locks do not.
Completed rider resolution closes the hit even when no option qualifies;
later grants cannot reopen it. Independent review accepts VS-54/55/56; see
[ADR-0025](../decisions/0025-source-owned-rider-occurrence-locks.md) and the
[authoring boundary](../mechanics/shared-resource-pools.md#batch-j-round-roll-active-instance-limits-and-numeric-payment-waiver).

Optional explicit `Character.class_levels` now supplies actual per-class formula
inputs separately from total level, proficiency and selected slot. Declared numeric
and die-size progression tables reuse the shared evaluator; exact pool capacity/
size recalculation preserves spent quantity. Allocations use existing checkpoint
preflight/recovery; this bounded behavior is accepted as VS-44 after independent
[Batch F review](../../.artifacts/planning/vocabulary-reports/batch-F-review.md).
Cast preparation preflights all parameter availability before costs, storing only
captured values; live consumption still reevaluates. This does not add full native multiclass acquisition or a
leveling UI; see [ADR-0024](../decisions/0024-explicit-class-level-formula-inputs.md)
and the [pool contract](../mechanics/shared-resource-pools.md).

Batch L adds `SourceBenefitRules` projections for fixed additive AC and walking
speed on exact equipped copies, passive progression/choice occurrences and flat
automatic self-casts. Item/choice benefits reuse existing identities rather than
mutating permanent stats; casts reuse timed SpellEffects records. Normal
Class Progression Equip/Stow and Choose/Replace controls, combat casting and
exact-cast Dismiss commands own changes. Saved cast payload/identity preflight
runs through the existing spell validator on both DTO paths. Independent review
accepts this bounded behavior as VS-59/60. Current-turn movement refreshes from
live speed while retaining spent distance, including after concentration loss. See [source carriers](../mechanics/source-benefit-carriers.md)
and [ADR-0026](../decisions/0026-derived-source-benefit-carriers.md) for the additive,
self-only and form limits.

Batch M's S-051 implementation extends the same `ResourcePoolRules` pool DTO
with opt-in captured faces and per-die source identities. Declared class-level
capacity/size tables remain the progression owner; recalculation changes future
dice while retained dice keep their original size/face. Existing feature quantity
controls spend oldest dice, and existing completed-rest recovery generates only
vacancies. Both full-save DTO paths validate captured state before replacement.
Independent review accepts S-051 as VS-61 within the existing self-healing
consumer and explicit recalculation boundary. See
[captured pool authoring](../mechanics/shared-resource-pools.md#captured-dice-inventory-vs-61-independent-review-accepted)
and [ADR-0027](../decisions/0027-captured-source-pool-dice.md).

Batch P adds `CapturedGrantRules` recipient-owned committed gifts and combat-local
transfer choices. `ResourcePoolRules` pays the giver once; each recipient uses
its own current-turn budget/Reaction from the Features menu. Exact captured dice,
formula permissions and one shared rolled value retain original source, group
and deadline through allowed checkpoints. Transferred die serial high-water marks
prevent regeneration after source reacquisition. Both DTO paths and cross-actor
links validate before replacement. Independent review accepts S-082 as VS-63.
Independent Batch Q review accepts S-083 as VS-64 for the shared captured
weapon-attack bonus. `PartyInterventionRules` adds exact-helper Reaction
and source payment to the existing weapon request; `PartyAllocationRules` owns
one transient fixed/rolled/exact-dice allocation through the combat Features
menu. S-097/S-101/S-102 are accepted as VS-65/66/67 for fixed helper bonuses and
HP/Temporary HP allocations. Completed state reuses existing Character/pool fields. Other intervention
hosts and casting permissions remain outside this boundary. See
[party authoring](../mechanics/party-intervention-and-allocation.md). See [captured grants](../mechanics/captured-grants.md)
and [ADR-0028](../decisions/0028-captured-recipient-grants.md).

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
The combat chooser also supports one owned post-roll failed-save modification:
a fixed total bonus with either payment policy, or an explicit success override
that preserves numeric roll fields. Snapshots retain spent Inspiration and DC;
ordered and flat effects wait for settlement, including a following deferred
damage choice. These are checked VS-18–20 subsets, not general roll editing.

VS-21 extends captured post-roll fixed bonuses to normal player weapon Attack
and Extra Attack. Each swing settles once before damage and hit-only grants;
the Attack action is paid once. Eligible native Stroke uses the validated
captured request before the source chooser. VS-22 checks the same authored
modifier on flat/ordered shared-spell attacks, with cast costs and successive
token/bonus/damage choices retained once. VS-23 accepts a captured single source
die in those attack and rolled-save consumers. Source validation precedes RNG;
the receipt survives later choices, and payment follows the final result policy.
The actual spell host finishes a selected-source refusal as a decline on the
same canonical roll, so an unavailable bonus cannot strand the cast. Weapon-
only native Stroke checks the canonical domain before spending. The trio has
passed combined review; broader hosts, domains and roll editing remain open.

Shared-spell attack windows are emitted by the existing roll/damage owners.
The ordered adapter binds the child attack's canonical receipt before authored
effects read it, including deferred settlement, and restricts it to that
recipient and occurrence. New untracked save/damage steps clear the attack
context. Explicit outcomes apply after native attack handling; source-domain
validation prevents ambiguous numeric/outcome choices. Shared healing accepts
integral JSON numeric scalars through the existing parser. These bounded
S-025/S-041/S-091/S-092 repairs and current production evidence are recorded in
the [acceptance review](../reviews/slice-acceptance-2026-10-14.md).

`CombatState` coordinates input, encounter bindings, turn order and the cast
sequence. Focused `SpellCast*` modules own selection, validation/choices,
resources, targeting, movement, reactions, markers, results and areas.
`SpellResolver` dispatches existing attack/save/projectile and special result
families; `CombatAction` also owns shared weapon and typed-damage settlement.
`SpellCastContext` and `SpellResolutionContext` are transient, never save data.
The [spell module map](../../src/spells/README.md) locates current code.

`SpellEffects` owns cast sources, clocks and cleanup. Benefits and persistence
have focused modules. `SpellEncounterLifecycle` dispatches target-turn repeat
saves; source-owned records also track elapsed-time deadlines, counted stages
and escalating DC history for shared definitions. `CombatSpellZones` owns spatial/turn triggers and source-owned
areas. Terrain/conjuration modules retain existing native spell policy.
`LocalRoomSharedSpells` reuses shared resolution for bounded exploration casts.
New shared capabilities should replace native policy progressively without
duplicating damage or cost. Shared timed effects can subscribe to canonical
attack, completed-cast, movement, status, equipment, range and settled-damage
events with `source_end_rules`; cleanup removes the matching source and keeps
an exact transient end receipt. This Batch 019 support awaits independent
acceptance and does not imply converted catalog consumers. See the
[authoring contract](../mechanics/source-end-rules.md). Availability and full
rules support are distinct.

## Current ability-check context

`EventDialog` resolves uniquely identified context-aware event/choice checks
from loaded `DataLoader` records. It passes task, purpose, optional required
tool and originating table/event/check to `EventResolver`; copied popup fields
cannot replace the check, DC or consequences. `Inventory` queries authored
contextual bonuses on the rolling actor's exact carried/equipped tool copies.
The result retains actor, context and exact item/effect/location through event
closure. No-tool/no-bonus checks remain ordinary; undeclared/direct checks retain
their existing route. This context is checked as VS-24. VS-25 adds one captured
owned fixed/die bonus to failed loaded skilled/ability-only and choice-owned
checks before consequences, using SpellDamageRolls' existing source requests and
payment semantics. EventDialog retains native bonuses and the final closed
receipt; popup generations/canonical actors guard stale awaits, and re-popup/
exit cancel only this host's requests/menu. Decisions remain transient and no
durable state is added. VS-26 adds mandatory-new natural/whole-test rerolls
as alternatives in that same post-roll menu. EventResolver preflights captured
receipts before payment or RNG and retains raw natural, original/new mode,
bonus-die provenance and explicit floor stages. Native payments are not replayed;
the worse new result still settles once. VS-48 adds declared old/new choice,
new-test mode and captured actor-formula bonus. Source loss before payment
settles the original; paid replacement rolls retain both full receipts. Further
hosts remain open. See the
[check context contract](../mechanics/purpose-aware-check-context.md) and
[owned modifier contract](../mechanics/owned-ability-check-modifiers.md).

VS-49 reuses that captured-test arithmetic for normal Attack/Extra Attack and
flat/ordered combat shared-spell attacks/saves. Paid keep stages remain canonical
requests with exact actor/host/kind/newer-request checks. Signed dice, fixed
contributions, original AC/DC and weapon critical range stay captured; the kept
natural controls damage and natural20-only aftermath. Visible bonus-die receipts
use the kept test's actual faces. VS-50 adds exact-context Character recipient
maps and flat shared-spell caster-chosen damage exemptions. Exemption authority
is transient state on the exact cast/invocation and recipient objects, not caller
decisions. Saves and independent riders remain unchanged; native Evasion retains
priority. See [Batch H review](../../.artifacts/planning/vocabulary-reports/batch-H-review.md)
for repairs, actual controls and remaining host limits. No durable state or new
save boundary was added.

VS-51 extends selected numeric-source payment with final-success/final-failure
reservations and canonical commit/refund receipts. VS-52/53 carry exact damage
component/occurrence reductions and selected mitigation layers through existing
shared spell adapters and pending damage settlement. Actor formula availability
is checked before costs; typed component receipts retain reduction separately
from mitigation and THP. Sphere bypass remains limited to damage-only ordered
typed-component save payloads, including the normal casting controls. Other
damage hosts and prevention policies remain open. See
[Batch I review](../../.artifacts/planning/vocabulary-reports/batch-I-review.md).

## Source-owned stat projections (Batch G; VS-45–47 accepted)

`CheckFloorRules` adds separately authored natural-d20/final-total floors to the
existing EventResolver/EventDialog check and mandatory-new reroll host. It reuses
shared actor formulas, source identities and captured receipts; attack/save floor
policies are unavailable. `ProtectionRules` owns typed timed self-protections on
Character numeric-pool sources, equipment eligibility, score/AC combination and
exact-grant recipient selection. AbilityScores retains permanent fields while
score/modifier reads project current eligible benefits. ClassProgression's
permanent increases still read/write underlying scores.

The existing feature picker/CombatCommand/common activation and recipient popup
own costs/choices. GameManager's campaign clock prunes the original deadlines;
ResourcePoolRules source removal cleans only matching grants. SaveManager checks
both DTO paths before restore; Character restores grants/selection without source
acquisition. Pending menus/generations stay transient. See the
[authoring contract](../mechanics/source-owned-stat-protections.md) and
[Batch G evidence](../../.artifacts/planning/vocabulary-reports/batch-G-build-validation.md).
The [independent review](../../.artifacts/planning/vocabulary-reports/batch-G-review.md)
also repaired level-up HP and Epic Boon eligibility/options reading temporary
scores: permanent progression now reads the underlying values. This adds no aura,
item-effect grant host, form policy, temporary-CON HP grant or new save boundary.

## Encounter projection and check-filter maintenance

Encounter monster dictionaries preserve declared vulnerability, represented
senses, proficiency and fly/climb speeds. Temporary casting Characters use the
same proficiency, sight and movement values; this does not supply source fields
that imported definitions lack or add general flying/climbing monster AI.
Countercharm's flat Frightened shared-save path uses the shared condition query
at both prompt and resolution, retaining existing native Charmed saves. Shared
Charmed grants remain unsupported. Initial class grants precede species additions,
so creation retains both weapon/armor proficiency sources.

Loaded check modifiers use optional task/purpose/event/check filters while the
check's DC, consequences and represented context still come from the canonical
record. Identified loaded checks without context retain verified origin without
invented task facts. Exact skill/tool matching and the existing floor/tool
contracts remain; see [optional filters](../mechanics/owned-ability-check-modifiers.md#optional-event-filters).

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
Compatibility frameworks and a universal adjudication interface do not gate
ordinary vocabulary work under ADR-0023. Correct state/time/rest wiring and
represented outcomes still require actual implementation and later validation.
[Testing](../testing.md) owns validation practice; dated gate
reports and reviews supply historical evidence only.
