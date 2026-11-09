# Crown rules-engine roadmap: levels 1–5

Finish the shared rules engine needed to play The Lost Crown from creation to
the level-5 finale. This is the selected campaign-sized queue. The
[main roadmap](../../roadmap.md#outside-crown) retains the wider engine backlog;
the [slice registry](vocabulary-slices.md) still owns S-IDs, prerequisites,
acceptance and verified limits. This document selects the relevant part of a
slice; it does not create a second acceptance count.

The [183-spell candidate set](preparation/crown-spells/README.md) and
[character/origin candidates](preparation/crown-characters/README.md) are now
written outside production loading. Start there for their authored definitions
and grouped mapping requirements. The earlier
[2026-11-08 reconciliation](#authoring-reconciliation--2026-11-08) locates the
inputs recovered before these passes. The
[package-equipment candidates](preparation/crown-equipment/README.md) now cover
the character packages and their dependencies. Remaining merchant/loot and
component consumers have a
[reachable-item writing pass](preparation/crown-reachable-items/README.md).
The [creature/actor candidates](preparation/crown-creatures/README.md) are now
written too. The final [world/event/object set](preparation/crown-world/README.md)
is now written outside production. Catalog writing is complete; cross-set engine
mapping is now recorded below; runtime delivery remains.

## Cross-set engine mapping — 2026-11-08

The [tracked mapping](crown-engine-mapping/README.md) covers all six written sets,
608 indexed candidates plus multiclass, their complete rule/operation/blocker
pointers and dependency/acquisition links. It reconciles current source/contracts
with verified registry boundaries; historical gap labels and proposed operation
names do not establish runtime truth. The
[ordered assignments](crown-engine-mapping/assignments.md) group shared engine
requirements once and separate content wiring, source facts, campaign policy and
missing production-path proof. [Unresolved decisions](crown-engine-mapping/unresolved.md)
remain explicit and block only affected consumers.

**CXM-01/S-249 is now delivered as a bounded ammunition runtime.** Existing
exact copies, budgets and campaign clock drive actual attacks and one-minute
floor-half recovery; both allowed DTOs pass fresh-process recovery. See the
[verified boundary](vocabulary-slices.md#exact-ammunition-spending-and-recovery).
Catalog promotion and fired-ammo corrosion remain separate; the remaining ordered
assignments stay queued. General liquids, all S-237/S-238, backgrounds and
multiclassing were not gates. The earlier mapping pass itself implemented nothing,
enabled no content and ran no Godot/gameplay checks; this subsequent delivery did.

Reuse accepted conditions/OA/placement/commands/forms/tethers/containment/rest,
casting and SC-01–SC-07 work. In-band Pact of the Chain specifically needs S-147's
one-attack command substitution; its higher-level remainder stays outside Crown.
Monster loot metadata still does not prove payment; bounty metadata still has no
established payment consumer. Dungeon-clear, generated-room, event and monster
settlement retain distinct routes. Native paths, legacy saves, source identities,
once-only costs/rewards and allowed checkpoints remain protected.

**Spell execution queue (2026-11-04 dispatch):** the
[Grokbot conversion stack](crown-spell-conversion-queue.md) assigns all 169
native spells at dispatch (81 refused, 88 enabled) to 46 stackable PRs, with
missing generic support and actual-content checks included. Its original
32-spell starting sweep and stacking directions are dispatch history; do not
restart it. The owner subsequently selected the all-spell candidate-writing
pass before further engine implementation/testing. The queue is an assignment plan, not a
readiness certification or a replacement for the finish line below.

## World/event/object candidates written — 2026-11-08

The [world candidate set](preparation/crown-world/README.md) retains 74 records:
the complete map and three dungeons, four tables/all 29 event and child-event
records, generated traps/loot, nine tactical objects, hazards/supplies, milestones,
objectives and rewards. Thirteen world procedures reuse full source context and
existing hosts; the dependency map covers all 183 spells and 79 character
candidates plus multiclass. Monster loot metadata still does not prove payment;
quest-board bounty metadata has no payment consumer. Routing, duration, quantity,
knowledge and settlement blockers remain explicit. Source/structure/link checks
passed; no production changes, engine fixes or gameplay checks occurred. This
closes Crown catalog writing, not cross-set engine mapping or runtime acceptance.

## Scope and finish line

The [spell handoff](crown-spell-conversion-queue.md#resume-here--grokbot-usage-cutoff-2026-11-04)
records the reviewed boundary through PR #104 and the subsequent support-10
repair of Bestow Curse #105–106. The local checkout inspected on 2026-11-08
includes that repair; Bestow Curse remains partial. SC-08 onward remains queued;
earlier partial consumers remain named in the CSV. This is not a fresh remote
PR/merge-status check.

- The existing Crown campaign: level 1 start, level 5 cap, one to four local
  players, four stable party slots, existing companions, map, three dungeons,
  milestones, encounters, shops, objectives and supported save checkpoints.
- All twelve SRD 5.2.1 classes through **total character level 5**, including
  their SRD subclass packages, legal multiclass combinations, class choices,
  level-4 ASI/feat choices and grants that arrive at character levels 3 and 5.
  Only the clauses available by that level belong here. A level-3 subclass
  record does not pull in its level-6/10/14/17 features.
- The nine SRD species, four backgrounds, four Origin feats, two General feats
  and four Fighting Style feats. The seven Epic Boons stay in the main roadmap.
  Include SRD invocation and Metamagic options whose prerequisites can be met
  in this band, rather than treating the current chooser's shorter list as scope.
- The **183 SRD spells at levels 0–3** pinned in the
  [content scope](crown-content-scope.md#spell-inventory). Enforce actual source,
  class, species, feat and slot permissions; a Paladin or Ranger does not gain
  level-3 spell slots just because those spells are in the engine scope.
- Ordinary equipment and tools required by those character packages, plus
  equipment, consumables, spell components, creatures and objects obtainable
  through Crown's shops, events, loot, forms, summons and spell-created outputs.
  A dormant item elsewhere in the registry is not automatically Crown content.
- Combat, room and overworld consumers of those rules, including checks,
  conditions, movement, rests, time, recovery, sensory/targeting rules and
  checkpoint persistence. Low spell level does not excuse missing world behavior.

There are two required finishes. **Engine completion** means the in-scope
clauses can be authored and executed through reusable data-driven operations
and actual world hooks, with neutral/renamed consumers proving independence
from spell, class, feature, item and monster IDs. **Playable Crown completion**
also needs the actual source-backed definitions, available controls and campaign
checks. Fixtures alone do not supply the content. Existing native behavior stays
while its replacement is incomplete; keeping that behavior is useful during the
work, but native-only execution does not close the engine migration requirement.

The scope is a content boundary, not a frozen number of engine slices. A newly
found requirement of an included rule remains Crown work. A requirement used
only above this band or by unselected content goes to the main roadmap. Record
the named consumer and missing behavior before expanding the queue. Shared
prerequisites need the relevant operation, not every unrelated clause of their
broader slice or phase. Do not substitute a reduced class/spell selection for
this finish line without an explicit scope change.

## Spell candidates written — 2026-11-08

All **183 scoped spells** now have tracked, source-backed candidate records in
[one authoring folder](preparation/crown-spells/README.md), with a complete ID
index. Each retains its SRD header/body, page/hash identity, structured effect
intent and explicit mapping requirements. Existing shared definitions and new
current-contract drafts/fragments are separate from proposed declarations that
the engine does not implement. Proposed operation names are not executable syntax
or instructions to create one handler per spell.

The [grouped extension file](preparation/crown-spells/required-extensions.json)
collects related spell requirements reused by the cross-set mapping above.
It distinguishes authoring needs from later runtime proof; it does not certify
that every referenced engine owner is absent. The candidate README owns the
written-set breakdown and its limits. No gameplay tests, engine fixes or
production enabling occurred. Native execution, spell delivery labels and slice
acceptance stay at their existing boundaries. The other Crown content sets
remain outside this completed spell-writing assignment.

## Creature and actor candidates written — 2026-11-08

The [creature set](preparation/crown-creatures/README.md) contains 94 records:
ten Crown encounters, three companions, 59 SRD blocks needed by forms/undead,
five additional encounter comparison blocks, four held swarm blocks and thirteen
spell-owned actor/effect records. It resolves 39 individual Wild Shape choices at
Druid 2–3, 46 at Druid 4–5, all 24 normal familiar forms and seven additional
Pact forms. Find Steed's three types share its own stat block; appearance is not
a monster selector. Complete rules, behavior plans, pinned source/donor inputs,
selection links and blockers remain outside production.

The [dependency map](preparation/crown-creatures/dependency-map.json) classifies
all 183 spells and the 79 character candidates plus multiclass supplement.
Campaign/SRD identities remain distinct, including custom Goblin Chief/Lich King
and simplified overlapping encounters. Swarm eligibility, companion origin
choices, boss ambiguities and shared-host requirements remain explicit.
Loot reuses the reachable-item findings/candidates; metadata is not proof of
payment. Structural, source/reference and documentation checks passed; no engine
fixes, gameplay checks, enabling or slice acceptance occurred. World/event/object
authoring remains; the dated reconciliation below is not a new missing-creature
assignment.

## Remaining reachable-item candidates written — 2026-11-08

The [reachable-item set](preparation/crown-reachable-items/README.md) adds 73
new candidates, reuses 29 package-equipment candidates and maps all 183 spells'
Material requirements. Source roots include shop leads, companions, campaign/
event/generated rewards, tactical contents/keys, direct-monster loot metadata
and physical character/spell/tool creations. The two item sets have 178 distinct
written candidates. Existing seeds, source differences and mapping blockers
remain explicit; no engine changes, gameplay checks, enabling or slice acceptance
occurred. Creature/world authoring and cross-set mapping are now linked above; runtime delivery remains. Unselected craft outcomes
and dormant magic catalogs are not silently pulled into this finite pass.

## Package equipment candidates written — 2026-11-08

The [equipment set](preparation/crown-equipment/README.md) writes 105 candidates
from all twelve class and four background packages, including every starting
alternative/GP amount, six complete packs, Arrows/Quiver, all legal tool choices,
focus forms and topic-bearing Books. Existing definitions and manifest choices
are retained as reuse inputs. The package map resolves candidate references;
it does not install items or implement acquisition. Blockers remain grouped
against existing owners. No engine fixes, gameplay tests, enabling or slice
acceptance occurred. This covers package equipment only; broader Crown
merchant/loot/component/creature/world candidates are now written above;
the cross-set mapping above selects actual engine and consumer work.

## Character and origin candidates written — 2026-11-08

The subsequent owner-selected character/origin writing pass supplies
[79 candidates](preparation/crown-characters/README.md): all twelve classes and
their SRD subclasses through total level 5, 22 eligible invocations, ten
Metamagic options, nine species, four adapted existing backgrounds and ten
feats. [Multiclass acquisition](preparation/crown-characters/multiclass.json)
includes every class's entry grants and the combined/Pact casting distinctions.
The set retains complete in-band source bodies, structured behavior plans,
source/hash identity, existing definitions and recovered subclass/Draconic
drafts, plus explicit unresolved mechanics and item/actor dependencies.

These files remain outside production. Their
[grouped requirements](preparation/crown-characters/required-extensions.json)
are mapping work, not new accepted engine slices or claims that existing generic
owners are absent. No engine fixes or gameplay tests were performed. The
reconciliation below records what existed **before** this authoring pass;
its missing-candidate findings for these character/origin sets are historical.
The package-equipment set above was written afterward. Remaining equipment,
creature and world candidates are now written above; cross-set mapping stays separate.

## Investigated baseline — 2026-10-29

A fresh headless **Windows Godot 4.7** production-DataLoader export of the current
working tree, without fixtures, reported 14 loaded classes (12 offered), five
subclasses, nine species, zero feats, 290 items, 362 spells and 481 monsters.
There were zero validation failures and 25 rejected effectless feature records.
This is inventory evidence, not a gameplay pass. Raw export, source extraction
and logs are ignored under `.artifacts/crown-roadmap-audit/`.

- All 183 scoped spell IDs are loaded. **102 are cast-available and 81 refused;
  14 use shared execution and 169 use native execution.** These are independent
  measures: availability and the execution field prove neither correctness nor
  complete shared behavior. The spell table pins each ID and its clause-audit
  batch so the backlog is not inferred from an enabled count.
- Only Champion, Fiend Patron and Warrior of the Open Hand are present from the
  twelve target SRD subclasses. The Open Hand level-3 feature list is empty in
  the loaded registry. The other nine packages are missing. Abjurer and Diviner
  remain existing extra content, not replacements for the missing SRD Evoker.
- Backgrounds have no production content type or creation step. Goliath and Orc
  are missing; Half-Elf and Half-Orc are the two legacy entries in the nine
  currently loaded species. Production feats are empty, despite accepted generic
  acquisition/prerequisite controls.
- Current class data still has the audited Wizard/Rogue skill-list errors,
  Rogue's unrestricted Martial proficiency, absent Druid/Monk tool grants and
  Cleric's singular `shield` token. Subclass-level fallbacks are not the same as
  explicit source-backed class data. No class currently opts into
  `permanent_progression`; multiclass acquisition remains a fixture-proven
  capability without production class data and the S-234 eligibility check.
- Crown's existing campaign loop, milestones and recovery already have bounded
  checks. They are reuse points, not work to rebuild. Historical mixed-mechanics
  scenario failures still need focused reproduction; a dated failure count is
  not a current defect diagnosis.
- Familiar form/type selection and borrowed-sight/touch-delivery already have
  native room/combat controls and a bounded contract. Older follow-up prose does
  not justify rebuilding those pickers. Check the remaining source-defined forms,
  missing hosts and shared-data integration against the actual controls.
- The existing `crown_smoke` intentionally shortcuts the first boss completion
  and gives the finale party 10,000 HP/1,000 base AC against a 1-HP boss.
  `final_encounter_round_trip` forces its victory state, and Crown relaunch
  probes stage progressed saves. These are valid transition/recovery checks,
  not evidence of a normal level-1–5 journey. The final ordinary-play check below
  remains required; there is no established full-campaign gameplay pass to reuse.
  See the actual scenarios in [the harness](../../src/viewport_harness.gd) and
  [relaunch preparation](../../src/crown_fresh_relaunch_probe.gd).

## Current integration — 2026-11-03

Merged main through PR #80 now supplies the G1–G4 acquisition work and its
follow-ups, including real Skilled, class skill/tool choices and Druid/Monk tool
items; G5/G6 remain non-loaded preparation. The baseline above is historical.
Production multiclassing, complete equipment packages, backgrounds/species and
full class/subclass content remain unfinished. OA-01–OA-13 and Thunderwave's
bounded player Action/Ready sound are delivered; S-237/S-238 remain open.
See the [current lane split](crown-parallel-work.md#integrated-work--2026-11-03)
and the registry for their exact limits. Do not reassign completed packages.

## Authoring reconciliation — 2026-11-08

Read-only content reconciliation at local `main` `2a19eb1d`, before this
documentation update. No new definitions, runtime changes or gameplay tests.
The dated inventory/integration sections above and delivery instructions below
retain their historical context; they are not a fresh list of unstarted work.

**Historical finding before authoring:** broad spell discovery already existed;
the complete candidate set did not. The subsequent
[spell-writing pass](#spell-candidates-written--2026-11-08) now supplies it.
Do not repeat the spell audit or rebuild inventories as a substitute for writing
the missing definitions. Reuse the source/clauses below, reconcile dated support
labels against current contracts, and retain every unsupported clause explicitly.
Passing a schema or having a description is not complete authoring or gameplay
acceptance. The owner's proposed data-first pass separates candidate authoring
from later implementation/testing; this earlier reconciliation did not perform
that pass. Its table below records the pre-authoring findings, not a new instruction
to rewrite the now-present spell candidates.

| Content | Existing material to reuse | Remaining authoring boundary |
|---|---|---|
| Spells | The [spell audit](../audits/spells.md) records decomposition of all 339 SRD spells; all 183 Crown IDs have audit-batch assignments in its [inventory](../audits/spell-inventory.csv). The [conversion CSV](crown-spell-conversion-queue.csv) assigns all 169 original native migrations. | No complete alternate candidate catalog was found. Current migration labels normalize to 21 converted, 5 partial, 2 blocked and 141 queued, separate from the original 14 shared spells. The CSV's first validator error is not a complete missing-clause list. Translate the queued definitions and carry forward the existing clause analysis; finish partial/blocked clauses and reconcile shared baseline limits too. |
| Base classes and eligible options | Twelve production class files, [class scope](crown-content-scope.md#classes-and-subclasses), [revised source view](../../reference/2024/README.md), mechanics contracts, SRC-01 and later Monk/Rogue reviews in the [registry](vocabulary-slices.md#src-01-feature-inventory). | Existing declarations mix shared effects, native behavior and descriptive records. Neither source review nor complete executable authoring is established for every in-band class clause, invocation, Metamagic option or multiclass grant. Extend these records from their source; do not start twelve new class catalogs. |
| Nine absent target subclasses | Local ignored `_staging/subclass-staging/staged/` and `_staging/staged/` contain Berserker, Lore, Life, Land, Devotion, Hunter, Thief, Draconic and Evoker drafts, with notes/extracts and archived variants. The newer [Draconic candidate](preparation/draconic-sorcery.candidate.json) and [source map](preparation/draconic-sorcery.md) explicitly account for missing HP/AC consumers. | Each of the two staging sets has 21 feature entries at levels 1–5; 14 are disabled with empty effects. Several descriptions are truncated. Archive inspection found the same in-band placeholder pattern, not a hidden finished catalog. Reuse identities, spell lists and source pointers; recover complete rule bodies and author the missing behavior. The three loaded target subclasses also retain their package/conversion gaps. |
| Backgrounds | All four [source-pinned candidate records](crown-backgrounds/candidates.json) and their [clause/contract map](crown-backgrounds/README.md) already exist. | Do not rewrite the four backgrounds. Resolve their explicit missing item references and dependent feat definitions, then translate/adapt the candidates when a production background contract exists. Their historical host findings need reconciliation, not blind reimplementation. |
| Species and feats | Nine production species records (including two legacy species), one production feat (`skilled`), [required sets](crown-content-scope.md#species-backgrounds-and-feats) and [acquisition audit](../reviews/progression-acquisition-audit.md). | No complete separate Crown species/feat candidate sets were found in the inspected preparation/staging/editor locations. Author Goliath/Orc, complete the seven existing target species' 2024 choices/grants, and supply the other nine Crown feats. Retain legacy records. A chooser or native Fighting Style is not a complete authored feat. |
| Equipment and reachable creatures/world content | Production item/monster/event/campaign records; [item audit](../audits/items.md); [monster inventory](../architecture/data-driven-2024-monster-inventory.json); [Crown acquisition/reachability scope](crown-content-scope.md#campaign-and-world-inventory). | These are substantial inputs, not a complete shared candidate pack. Reconcile only named Crown items, actors and outcomes, including dependencies exposed by new definitions. Creature/form sets and some class clauses still need source work; no complete item-by-item/creature-by-creature authoring or clause-coverage claim is established here. |

**Other locations checked:** `codex/crown-origins-luna` is a clean worktree at
`423ada68`, an ancestor of this checkout, with no additional tracked/untracked
origins changes. Its background and Draconic candidates are byte-identical to
the main checkout's copies. Its name is not evidence of outstanding origins
implementation. The content editor's inspected workspace/exports contain the
Ember example pack (including a Magic Missile example), not the missing Crown
catalog. They remain editor-owned examples. `_staging/` and its archives are
ignored local material, not durable production definitions or current authority.

The earlier production export at the same source revision reported all 183
Crown spell IDs, 41 shared/142 native and 108 available/75 refused. Those are
two independent partitions, not four completion buckets. No export or gameplay
check was rerun for this authoring reconciliation, and no engine-slice acceptance
changes. Hit Dice, Shatter's shared object damage, Chromatic Orb's leap, Open Hand
Technique and the delivered acquisition subsets must not become duplicate tasks.
S-071's Prayer of Healing continuation and the other recorded limits remain open.

### Wider recovery review — 2026-11-08

The follow-up review covered tracked documentation/source/data, ignored staging
and archives, retained research and patches, registered Git worktrees, the stash,
old project copies, Beckett's game snapshot and the retained remote attachment.
It screened inventories and compared relevant source; it did not read every
binary/log/profile, rerun gameplay or certify every historical finding.
Raw comparisons stay in ignored `.artifacts/forgotten-work-review/`.

**Source inputs had become harder to find than the unfinished work itself.**
The [recovered source map](../content_pipeline.md#recovered-local-inputs--2026-11-08)
now locates the local SRD, corrected Fighter/Wizard packet, PHB/MM donor exports,
converter correction review and older per-record adjudications. Use those inputs
before declaring required source unavailable or repeating their research. The
donor exports are source material, not the missing authored candidate catalog.

Retain these concrete consequences:

- **Spell and class discovery:** reuse the complete spell decomposition and
  the source reviews already embedded in the Monk/Rogue mechanics guides.
  The historical per-record adjudications retain further requirements/gap notes;
  their frozen runtime evidence must be reconciled, not treated as current proof.
- **World hosts already delivered:** OA-08–OA-11 include local declared-language
  speech, saved character language knowledge, verbal Help, authored recollection
  Study and spoken encounter Influence. OA-01–OA-07/OA-12–OA-13 retain their
  cover/Search/sound boundaries. Reuse the [ordinary-action contract](../mechanics/ordinary-actions.md)
  and loaded `data/fixtures/ordinary_actions/` examples when authoring real content.
  The [retained requirements](vocabulary-slices.md#ordinary-action-work-packages)
  distinguish additional world/NPC/written/overworld hosts from these delivered
  local capabilities. Do not restart their old chat prompts.
- **Alert needs more than an Origin-feat chooser.** The older corrected Foundry
  review identified its initiative exchange, but the current feat backlog named
  Alert without an explicit finish line for that behavior. The local SRD p.87
  confirms Initiative proficiency and an immediate willing-ally Initiative swap,
  with both actors in the same combat and neither Incapacitated. No swap owner
  was located in the current initiative source or slice requirements. Carry both
  clauses into the feat candidate and map the missing operation during authoring;
  this review adds no S-ID or acceptance claim.
- **Do not restore old fixes wholesale.** The stash is earlier Hit Dice work;
  current main contains the integrated implementation and subsequent validation
  repairs. The old spell-review working copy retains Bless/selection/persistence
  repairs already present or superseded in main, plus older Bestow Curse damage
  and duration handling. Differences are not proof of missing integration.
  Other inspected registered worktrees supply no newly discovered origins pack.
- **Old copies are mostly duplicate history.** Screening 22 `project.godot`
  snapshot roots (including an addon backup), plus Beckett's separate game copy,
  found no additional `src/` game-script or `data/core`/`data/mods` JSON paths
  absent from main. Four retired planning documents survive in old copies; their
  useful source/ownership boundaries are represented in the current content
  pipeline. Existing-file differences still need individual interpretation;
  this is not byte-for-byte equivalence or a claim that all old code is correct.
- **Retired queues are not current context.** Quest Board still has 43 cards
  marked active/ready/review, including historical delivered-subset assignments
  and a request for unsupported mid-combat saving. Old handoffs also send work
  back to completed acquisition/rest tasks. The roadmap/registry and allowed
  checkpoints win. Local artifact READMEs still link to removed
  `docs/operations/current.md`; use the recovered source map instead.
- **The editor and old reports do not close authoring.** The editor's VS-83
  contract is a pinned snapshot, not today's complete engine syntax. The retained
  deep-review attachment is an older audit, and its ZIP contains no game-data
  catalog. Preserve the editor-owned examples and consult current runtime
  contracts when preparing Crown candidates.

No files were moved/deleted, no stash/patch/worktree was applied, and no gameplay
tests ran for this review. Preserve the local inputs while turning selected
content into tracked candidates; folder cleanup must not erase their only copies.

## Delivery order

The [2026-11-01 review and local/Grokbot split](crown-parallel-work.md)
refreshes the inventory above and provides bounded parallel assignments. The
dated baseline's empty Open Hand feature and absent multiclass entry checks
have since changed; production multiclassing and full class packages remain
unfinished. Reuse those delivered pieces rather than implementing them again.

Finish the selected bounded assignment before expanding it. **S-237/S-238 are
requirement umbrellas, not one execution assignment.** Use their
[work packages](vocabulary-slices.md#ordinary-action-work-packages) and
[separate-chat prompts](ordinary-action-chat-prompts.md), using the verified OA-01–OA-13 boundaries to select the next missing consumer. Independent movement, Hit Dice, character and
content work can proceed when their actual prerequisites are ready; the whole
ordinary-action umbrella is not a gate. A completed package does not accept its
parent slice or waive the registry's retained requirements. Prioritize subsequent
ready assignments by the amount of scoped Crown content they unblock.
Build the prerequisites required by that slice without turning unrelated parts
of a prerequisite's broader scope into a second assignment.

Each step follows the existing sequence: settle the selected rule clauses,
implement/check missing generic operations, prepare executable definitions,
then replace covered native paths. Independent rows can proceed when their
actual prerequisites are ready. Do not wait for every spell or world system to
finish before completing an independent background or equipment improvement.

### 1. Finish ordinary combat and recovery

| Existing slices | Missing Crown behavior and next check |
|---|---|
| S-235, S-246–S-248 | Crown portion complete: shared conditions, late-created/group initiative, retained monster concentration, AI/check hosts and reachable level-3 Open Hand Topple/Push saves are verified through production flows and checkpoint recovery. S-235/S-246/S-248 are accepted; S-247 retains only level-17 Quivering Palm outside Crown. See the registry for exact boundaries. |
| S-237; relevant S-160 action/Reaction budgets | Reuse OA-01–OA-13's delivered [ordinary actions/Ready/Utilize](vocabulary-slices.md#ordinary-action-continuation), [room Search/Help](vocabulary-slices.md#room-search-continuation), [Study/recollection](../mechanics/ordinary-actions.md#study-and-authored-knowledge), local speech/verbal Help and [gesture/spoken Influence](../mechanics/ordinary-actions.md#influence-through-gestures-or-spoken-communication). Select additional work from the registry's [retained requirements](vocabulary-slices.md#ordinary-action-work-packages), not its completed package prompts: further sound producers/routes, discovery, written/overworld knowledge, world NPC controls and actual tool/item effects remain separate consumers. An extra restricted action must not become a general Action or Reaction. Search and social actions consume steps 5/6's represented facts and real outcomes. Completing the parent umbrella is not a prerequisite for independent rows. |
| S-236, S-239, S-241 | Grapple/Shove, exact escape/drag/end conditions, fallback climb/swim, crawl, voluntary stand, jumping and declared granted/forced movement. Check Champion's critical-hit movement, Fighter Tactical Shift, Rogue Withdraw with legal paths, correct budgets and declared Opportunity Attack policy. Open Hand Push now reuses the existing forced-movement owner for up to 15 feet without Opportunity Attacks; that narrow consumer does not accept all S-241 movement. Ordinary movement/terrain S-179 and exact tethers S-168/S-169 already exist. |
| S-238 | OA-01 reviews/repairs the delivered standing flat-grid obstruction host and its targeting, AC, DEX-save, exemption and Hide consumers. Reuse existing evidence; further posture/aperture/elevation geometry remains explicit work in the registry, not an automatic expansion of this assignment. S-190/S-191 already supply bounded senses/concealment. |
| S-071, reusing S-070 | Hit Dice pools, selection, healing, Long Rest recovery, mixed class die sizes and allowed reload are delivered within the [verified subset](vocabulary-slices.md#rest-start-expiry-duration). Remaining: Prayer of Healing's rest-like benefits without a false elapsed/completed rest event; its ten-minute casting, interruption and daily recipient limit need their actual hosts (S-066/S-067/S-014 continuation). Rest lifecycle/actor duration is already accepted. |
| S-096, S-224, S-226 and accepted roll owners | Finish only the needed off-turn attack, noncombat check, Death Save and Concentration choice routes. Compare with the existing S-093/S-094 and captured-roll/payment machinery. A declined, stale or ineligible choice must not spend resources, roll again or duplicate the consequence. |

The condition quartet's Crown boundary is delivered. Remaining action
and movement consumers reuse those condition semantics. See the
[current recovery boundary](vocabulary-slices.md#srd-condition-and-roll-host-spine),
[core rules contract](../mechanics/core-rules-status.md) and
[core-rules host audit](../audits/core-rules-2.md).

### 2. Complete character acquisition and level-ups

| Existing slices | Missing Crown behavior and next check |
|---|---|
| S-231 | Background content type, selection and exact once-only grants: ability increases, Origin feat, skills, tool and equipment/gold. Add Acolyte, Criminal, Sage and Soldier; prevent old species ability bonuses from stacking on new background increases. Back/Random/seat reset and checkpoint validation must retain the chosen source and grants. |
| S-232; S-045/S-048/S-139 reuse | Complete nine-species data and lineage/ancestry/legacy, size, language, skill and spellcasting-ability choices. Apply level-3/5 grants once at the correct character level. Preserve legacy saves; do not delete or silently rewrite their species. Druidic, Thieves' Cant and Ranger language grants must populate the existing saved language state used by OA-08 communication. |
| S-234; S-047/S-048/S-137/S-138 reuse | Verify the existing entry prerequisite code and class overrides; S-234 remains unaccepted. Production multiclassing also needs source-backed proficiency subsets and extensions to the bounded progression host, which currently refuses subclasses, most feature kinds and secondary classes with features. Class declarations alone cannot enable it. Check legal/illegal entry, total versus class level, HP, mixed slot/Pact progression, source preparation and reload without grants replaying. Crown's milestones still award total levels through 5; XP advancement is separate. |
| S-233/S-242 already accepted; S-049/S-050/S-084/S-085/S-103/S-104 reuse | Supply the ten in-band SRD feats and their effects, including Origin parameters, ASI/Grappler ability benefits and Fighting Style acquisition. Finish missing effect consumers rather than redoing prerequisite or generation controls. Validate level-4 choices, replacement cadence and exact ownership through real creation/training and fresh-process recovery. |
| Content corrections using existing owners | Reuse the delivered Wizard/Rogue skill-list corrections, Cleric `shields` token, subclass-level metadata and Druid/Monk/Rogue tool-grant subsets. Rogue's unrestricted Martial proficiency and complete starting packages still need source-backed correction/authoring. Check actual creation/sheet output against source; possessing a Thieves' Tools item is not the Rogue tool-proficiency grant. |

Use the [acquisition audit](../reviews/progression-acquisition-audit.md) for source
clauses and the registry for current status; that audit predates accepted S-233
and S-242. The [class-by-class scope](crown-content-scope.md#classes-and-subclasses)
owns the finite feature/package checklist for step 3.

### 3. Finish the twelve level-1–5 class and subclass packages

For each row in the content scope, map the source clauses to actual operations,
permissions, controls and lifetimes. Do not count an empty, quarantined or
native-only feature as shared-engine completion. There are no dedicated accepted
slice assignments for many of the missing subclass clauses yet: inspect their
named source body, reuse existing operations first, and add a registry requirement
only when a distinct generic capability is missing.

Priority consumers include Ranger Hunter's Mark and Hunter's Prey; Warlock Hex,
Fiend spells and eligible invocations; Monk Slow Fall, Deflect Attacks and Open
Hand Technique; the missing subclass spell grants and resource/Reaction effects;
Champion's critical threshold; and level-5 prepared-spell/Extra Attack upgrades.

Known reusable/unfinished boundaries are S-076/S-077 next-result grants,
S-084/S-085 parameter/AC upgrades, S-094 check modifiers, S-109/S-114 incoming
damage reduction/countereffects, S-123–S-127 cast/attack edits, S-134–S-142 spell
permission/payment/preparation/parameters, S-154–S-158 owned creatures,
S-163/S-164 forms/equipment, S-181 falling and S-240/S-241 threshold/movement.
The existing [Second Wind conversion blocker](vocabulary-slices.md#conversion-batch-001)
also needs Tactical Mind refund and Tactical Shift wired to the same resource.
These are continuations of existing owners, not a new class executor per class.

In particular, a generic pre-damage reduction and a generic post-damage
countereffect do not by themselves prove Deflect Attacks' optional Focus
payment, target/range/cover selection, damage type and save. Check the whole
declared sequence. Slow Fall must reach actual falling damage. A present
Open Hand subclass record must supply its level-3 technique.

Check each completed package at levels 1, 3, 4 and 5 through ordinary menus and
legal off-turn windows, with its actual choices and resources. Test allowed
reload when durable grants/state change. Keep class-level 6+ follow-ups in the
main roadmap even when their helpers share the same source file.

### 4. Complete the scoped spell engine and actual spell definitions

The 183-ID table is the work boundary, not just the 81 spells refused at dispatch.
Audit cast-available native spells too. Use the complete
[spell clause audit](../audits/spells.md) to locate requirements, then compare
with current owners; its old `Planned` labels do not override newer acceptance.

| Existing slices/owners | Concrete in-band consumers and missing boundary |
|---|---|
| S-041/S-042/S-134/S-135 continuation; S-160 | Hellish Rebuke, Counterspell, Feather Fall and hit-triggered smites need the actual qualifying damage/cast/fall/hit windows across player and monster routes, with legal reaction/bonus-action payment. Existing bounded reaction delivery is not every attack/spell/area route. |
| S-032/S-091/S-098/S-099 continuation | Reuse Shatter's delivered shared area-object damage from SC-03 support 06 within its recorded conversion boundary; do not restart that conversion. Burning Hands/Fireball retain their unworn flammable-object consumers. Preserve unknown material/equipment facts rather than inventing eligibility. |
| S-076/S-077/S-080/S-086/S-087; S-126/S-127/S-140/S-141 continuation | Hunter's Mark, Hex, Guiding Bolt, Haste, Enlarge/Reduce, Dragon's Breath, False Life/Fiendish Vigor, and timed multi-recipient benefits need their actual retarget, hit/save, attack-unit, parameter and lifetime hosts. Flat condition duration support does not establish benefit, actor, zone and item lifetimes. |
| S-267 | Chromatic Orb's matching-face leap and costed diamond are delivered within SC-04 support 01's recorded conversion boundary. Reuse that operation and evidence; broader slice acceptance is separate. |
| S-183/S-241/S-269 | Dissonant Whispers' recipient Reaction movement and Command/Fear compelled behavior need actual safe routes, budgets and correct Opportunity Attack rules. A Frightened condition flag does not execute Fear's movement. |
| S-180/S-181/S-185/S-186; S-121/S-122/S-170/S-172 continuation | Gaseous Form, Meld into Stone, Blink, Fly, Levitate, Wind Wall, Tiny Hut, Rope Trick and Floating Disk need their actual occupancy, fall/return, selective barrier, occupant and movement rules. Do not require planar travel everywhere or damageable high-level wall segments just to close a narrower low-level consumer. |
| S-154–S-158/S-162/S-163/S-164 continuation; S-178/S-192/S-193 | Find Familiar, Find Steed, Animate Dead, Unseen Servant, Phantom Steed, Spiritual Weapon and Wild Shape need their remaining choice, command, form, remote-origin, recall and exploration hosts. Reuse accepted placement/commands/turns and party recovery instead of restarting those systems. |
| S-187/S-188/S-189; S-190/S-191 continuation | Minor/Silent/Major Image, Disguise Self, Mirror Image and Phantasmal Force need located representations, per-observer discovery and actual selected interaction/effect outcomes. No universal AI or free-text GM is required; unsupported world outcomes must remain explicit. |
| S-194/S-195/S-218/S-219 | Detection/location, languages, Message/Sending, thought/attitude and Speak with Animals/Plants/Dead require represented targets, knowledge and communication. Add actual Crown-authored answers/interactions; do not enable a spell that only records that a conversation occurred. Augury needs the authored outcome and once-rolled repeated-use uncertainty (S-209/S-214 reuse as applicable). |
| S-197/S-199/S-200/S-205/S-212/S-213 | Create/Purify Food or Water, Goodberry, Plant Growth, Water Breathing/Alter Self and Mending need real quantities, environmental/breathing consumers, campaign outcomes and exact damaged-object repair/piece constraints. Do not substitute new objects for repairing an existing copy. |
| S-150/S-151; S-184/S-203 continuation | Glyph of Warding stores an exact eligible spell and releases it once at its real trigger; Arcane Lock/Knock, magical triggers and persistent room states must have working world controls and allowed checkpoint recovery. Existing room locks/areas are reuse points. |
| S-274/S-276; S-116/S-190 reuse | Darkness/Daylight overlap ending and Dispel Magic need captured cast levels, thresholds, higher-level checks and exact-source removal across condition/benefit/area/object owners. Accepted senses and generic negation alone do not establish spell-level dispelling. |

Rows are consumer groups, not extra S-IDs or universal prerequisite gates. Source
clauses that use an already accepted operation need executable data and a focused
consumer check. A distinct missing operation needs a slice/extension with a
concrete finish line. Some spells also need the action, information, equipment
and exploration work in other steps; those dependencies are shared, not repeated.

### 5. Finish equipment, exploration and Crown world consumers

| Existing slices/owners | Required Crown boundary and proof |
|---|---|
| S-249/S-251/S-266; S-196 continuation | Ammunition items, exact spending/recovery, free-hand/loading behavior, armor proficiency/Strength/Stealth restrictions and actual carried weight/size limits. Include equipped/carried/container contents without double-counting. Range/Heavy (S-250) and don/doff (S-252) are already accepted. |
| S-197/S-256/S-258; S-028/S-168/S-169/S-184 reuse | Fuel/portions, tool use, acid/holy-water/alchemist's-fire attack substitutions, Net, caltrops and ball bearings where the scoped equipment packages grant them. The current purchasable Net does ordinary weapon damage; it needs its real attack-replacement/restraint behavior. New pack contents must resolve to actual items and usable quantities. |
| S-227/S-228; S-065/S-179/S-200/S-219 reuse | Real travel time/pace, terrain, marching-order and survival checks on Crown's five-mile hexes; keep milestone level-ups. Check slow members/mounts, timed benefits, supplies, event delivery, interruption and allowed reload without duplicate distance/time or consequences. Campaign-authored navigation/foraging outcomes fill facts the SRD leaves to the campaign. |
| S-229/S-230; S-188/S-190/S-212 reuse | Actual local Search, hidden-object/trap discovery, key/tool/disarm/break routes and once-only state/costs. Crown has generated `trapped_chest` events and authored room doors/objects; a disconnected event roll is not a general spatial trap procedure. |
| S-216/S-217/S-218/S-219 relevant consumers | Reuse current objective/reward ledgers and event continuations; prove authored information, language, influence and any spell-conditioned objective can resolve against actual Crown actors/objects. Wrong location/recipient and an unfinished child event must not award knowledge or rewards. |

The current merchant predicate admits 64 items (pinned in the content scope),
including firearms and a lantern record that needs its actual light/fuel
path checked. Do not silently turn all 290 loaded items into mandatory content.
Preserve existing extras during development; resolve their availability or
campaign-specific rule policy before final acceptance. Dormant magic shells,
rarity alone and the existence of an item schema do not select the full magic
item backlog. If an in-scope consumer actually obtains an item power, pull its
specific S-253–S-265 requirement into this queue with that receipt.

### 6. Verify enemies, real content and the complete campaign

The [content scope](crown-content-scope.md#campaign-and-world-inventory) pins ten
direct Crown encounter monster IDs. Include the actual actors reachable through
forms, familiars, summons and created undead as those packages are completed.
Audit their loaded attacks/traits through shared operations too: Wight maximum-HP
loss, Spider poison/restraint, Zombie Fortitude, Ooze corrosion and Lich King
paralysis, spellcasting, turning resistance and Legendary Resistance. S-109–S-120,
S-130/S-131 and S-235/S-246–S-248 provide reuse points; a trait name/description
in JSON is not an executable grant. The custom CR-8 Lich King remains in Crown
because the campaign uses it, despite the party's level-5 cap. Preserve the
custom encounter; this is not a request to replace it with the SRD Lich.

Reproduce the remaining scenario investigations before assigning fixes. In
particular, separate the high-level Bard standing prompt and Ranger Nature's
Veil failures from low-level aura, Identify, movement/cost, typed hit-grant,
damage-settlement and Wizard casting failures. Scope follows the reproduced
consumer, not the scenario's filename. The repaired Heroism/Enhance Ability
source-count expectations and creation matrix are not new repair assignments.

Acceptance uses the supported [Windows runner](../testing.md), with the existing
tests appropriate to each changed behavior, not a fresh parallel harness:

1. Relevant logic groups and actual input-path checks for each engine capability;
   neutral/renamed definitions prove reusable execution. Review shared combat or
   persistence changes independently as required by AGENTS.md.
2. Actual source-backed class/subclass/feat/spell/equipment definitions exercise
   the same path, including cancellation, stale targets, once-only payment,
   condition/source cleanup and the correct actor's budgets.
3. Run existing `normal_creation_matrix`, relevant class action/creation flows,
   `core12_audit_repairs`, `mixed_mechanics_encounter`, `spell_effect_lifetime`
   and new focused regressions only where a missing/likely failure needs one.
   Triage mixed scenarios by clause/level; a high-level unrelated failure remains
   visible in the main backlog without pretending the scenario is all green.
4. Exercise `crown_smoke`, `crown_composition_solo_two`,
   `crown_composition_three_four`, `crown_balance_fixture` and
   `dungeon_reentry_round_trip`/`final_encounter_round_trip`, plus the existing Crown single-/two-player
   separate-process relaunch scripts. Verify level 1→5 milestones, choices at
   3/4/5, three fragments, final victory, defeat, safe save/reload, ownership and
   once-only rewards. Add the missing normal journey coverage in the existing
   harness: start from actual creation, earn the four milestones and three
   fragments, settle training/choices, rest and resume an allowed checkpoint,
   and defeat the actual finale through legal commands with normal stats,
   resources and rewards. No invulnerable party, 1-HP replacement boss, manual
   victory settlement or pre-staged completed milestones count as that proof.
   Existing isolated failure/transition fixtures keep their bounded purpose.
5. Observe a normal campaign run in the game for controls, encounter readability
   and pacing. Headless assertions do not certify visual/input usability or
   balance. Stop any play session started for this check.

Completion requires evidence for the full scope above, including the still
unmapped class/subclass/option clauses. There is no current claim that the
engine or campaign is complete, and no trustworthy remaining-slice percentage.
Finish behavior and its real consumers; update acceptance only in the slice
registry and per-content contracts/registers.

## Where to start next

Use the [cross-set mapping](crown-engine-mapping/README.md) and remaining
[bounded assignments](crown-engine-mapping/assignments.md). CXM-01 now has the
[verified S-249 runtime boundary](vocabulary-slices.md#exact-ammunition-spending-and-recovery).
Retain the six written candidate sets and accepted SC/OA work; catalog conversion
and remaining production-path proof stay separate.

The **Crown portion of S-235/S-246–S-248 is complete**; level-17 Quivering
Palm remains outside Crown. The Hit Dice subset is also delivered; Prayer of
Healing remains open. Before selecting further work, use the
[authoring reconciliation](#authoring-reconciliation--2026-11-08) to reuse existing
audits and candidates. Remaining ordinary actions/movement and character/content
work retain their bounded scope. Complete each ready character/spell package
through the sequence above. No universal engine, full SRD audit rerun, new save
framework, complete magic-item catalog or high-level class pass is a gate.
