# Roadmap

Build one shared, data-driven D&D 2024 rules engine in Godot. JSON describes
rules; code interprets reusable operations and supplies world access. Prepared
content using completed capabilities must run without content-ID branches.
[ADR-0018](docs/decisions/0018-shared-data-driven-rules-runtime.md) owns this direction;
[ADR-0023](docs/decisions/0023-vocabulary-first-delivery-and-bounded-world-judgment.md)
retains vocabulary-first delivery, current save priorities, and Wish/illusion policy.

## Current work

**CXM-01/S-249 exact ammunition now has a verified bounded runtime** using
existing copies, attack budgets and campaign clock. Actual attacks and one-minute
floor-half recovery pass the Windows runner, including both allowed DTOs in a
fresh process. See the [verified boundary](docs/planning/vocabulary-slices.md#exact-ammunition-spending-and-recovery)
and [ammunition contract](docs/mechanics/ammunition.md). Catalog promotion and
fired-ammo corrosion remain separate; continue with the remaining ordered
assignments. The first mapping entry is now delivered.

The **Crown cross-set engine mapping is complete as planning** in the
[mapping and clause ledger](docs/planning/crown-engine-mapping/README.md).
It reuses all six written sets: 608 indexed candidates plus multiclass, full
rules/blockers and dependency/acquisition links. The
[ordered bounded assignments](docs/planning/crown-engine-mapping/assignments.md)
begin with **CXM-01, exact ammunition spending/recovery (S-249)** (now delivered above), using existing
copies, budgets and clock; general liquids/fuel and whole parent slices are not
gates. [Unresolved source/policy decisions](docs/planning/crown-engine-mapping/unresolved.md)
hold only their affected consumers. The mapping pass ran structural/source/link checks,
not gameplay acceptance; that pass made no runtime, loaded-data or save changes.
Use this cross-set queue for the next implementation, retaining the older spell
queue's accepted work and exact partial limits. Native paths stay until covered.

The **final Crown world/event/object writing pass is complete** in the
[world candidate folder](docs/planning/preparation/crown-world/README.md):
74 candidates retain the 43-tile map, three dungeons, four tables and all
29 events/child events, generated traps/loot, nine tactical objects, hazards,
supplies, objectives, milestones and rewards. Full rules and previous candidate
sets are reused; all 183 spells and 79 characters plus multiclass have world
dependency routes. Blockers include unpaid bounty metadata and unproven monster
loot payment. Structural/source/link checks passed; nothing entered production
and no gameplay tests ran. The subsequent cross-set mapping is linked above.

The **Crown creature/actor writing pass is complete** in the
[creature candidate folder](docs/planning/preparation/crown-creatures/README.md):
94 records cover ten direct encounters, Aldric/Mira/Rowan, complete in-band
individual SRD form sets, created undead and spell-owned actors/effects, with
separate campaign/SRD identities. This includes four low-CR swarm blocks written
but held outside legal individual-form lists pending explicit adjudication.
Full rules, behavior plans, acquisition links, unchanged seeds and blockers stay
outside production. Structural/source/documentation checks passed; no engine
fixes, enabling or gameplay tests occurred. World/event/object candidates are now written above;
the cross-set mapping is linked above; monster loot metadata still does not prove
reward payment.

The **remaining reachable-item writing pass is complete** in the
[reachable-item folder](docs/planning/preparation/crown-reachable-items/README.md):
73 new candidates reuse 29 package-equipment candidates for shops, companions,
rewards, tactical contents, exact spell materials and physical creations.
All 183 spell Material requirements have a source-pinned map. Source mismatches
and engine blockers remain explicit; nothing was enabled or gameplay-tested.
The creature and world sets above are now written and mapped; runtime delivery remains.
The two item sets contain 178 distinct written candidates;
arbitrary crafting/dormant catalogs stay outside
this finite acquisition pass.

The **package-equipment writing pass is complete** in the
[equipment candidate folder](docs/planning/preparation/crown-equipment/README.md):
105 candidates cover starting alternatives from all twelve classes and four
backgrounds, six full packs, ammunition, legal tool choices, focuses and the
previously unresolved background items. Existing definitions remain pinned as
reuse seeds; blockers are recorded without engine fixes or production enabling.
The subsequent item and creature sets above are now written;
world candidates and the subsequent mapping are linked above; runtime delivery remains.

The owner-selected **Crown character/origin authoring pass is written** in the
[character candidate folder](docs/planning/preparation/crown-characters/README.md):
twelve classes and their SRD subclasses through level 5, multiclass grants,
22 eligible invocations, ten Metamagic options, nine species, four reused
backgrounds and ten feats. Full rules, operation plans, existing definitions and
recovered drafts stay outside production with explicit unsupported behavior.
No engine fixes or gameplay tests were part of this pass. The subsequent mapping
joins the written character, spell, item, creature and world requirements above.

The owner-selected **all-183-spell authoring pass is written** in the tracked
[Crown spell candidate folder](docs/planning/preparation/crown-spells/README.md).
It includes full source rules, structured effect plans, available shared drafts
and explicit unsupported/mapping requirements. Candidates are not loaded or
enabled; no engine fixes or gameplay tests were part of this pass. The subsequent
mapping groups related requirements across this complete set. The character/origin set above is also
written; subsequent item/creature sets above remain separate from spell execution.

The [2026-11-08 authoring reconciliation](docs/planning/crown-roadmap.md#authoring-reconciliation--2026-11-08)
distinguishes completed audits, existing candidate drafts and missing authored
content. Read it before selecting more conversion work: broad spell clause
discovery already exists. The spell candidate set above was written afterward;
the character/origin candidates above were written afterward too. The world/event/object, item and creature candidate sets linked above
were written after that reconciliation; catalog writing is complete, while
the cross-set mapping is linked above and runtime delivery remains.
It also locates the staged subclasses/backgrounds and checks the origins worktree.

The [Grokbot usage cutoff](docs/planning/crown-spell-conversion-queue.md#resume-here--grokbot-usage-cutoff-2026-11-04)
records the reviewed stack through #104, the held Bestow Curse PRs #105–106,
and the historical per-spell implementation next actions. It remains an engine
handoff; do not restart SC-01 or substitute it for the current authoring set.

The [2026-11-04 Crown spell conversion queue](docs/planning/crown-spell-conversion-queue.md)
assigns the original 169 native spell migrations to 46 ordered, stackable Grokbot PRs.
It includes missing reusable operations, source-backed data and production
checks. The owner directs continuous stacking without review, approval or
merge waits; the historical sequential Grokbot review cadence does not gate
this queue. Character/world work and the full Crown finish line remain below.

Finish the level-1–5 rules engine and real content needed by The Lost Crown using
the [Crown roadmap](docs/planning/crown-roadmap.md). Its
[content scope](docs/planning/crown-content-scope.md) pins the twelve SRD classes
and their in-band subclass packages, species/backgrounds/feats, 183 level-0–3
SRD spells, and Crown's reachable world consumers. The Crown condition/roll-host portion of S-235/S-246–S-248 is complete.
S-247 retains only level-17 Quivering Palm outside Crown. The
[S-237 ordinary action continuation](docs/planning/vocabulary-slices.md#ordinary-action-continuation)
records delivered combat actions, Ready, room Utilize/Search/Help, object Study,
gesture Influence and represented hearing/noise. S-237/S-238 remain incomplete
requirement umbrellas. Work now selects one
[bounded assignment](docs/planning/vocabulary-slices.md#ordinary-action-work-packages),
using the verified OA-01–OA-13 boundaries to select the next missing consumer.
[Prompts for separate chats](docs/planning/ordinary-action-chat-prompts.md)
retain the completed OA-01–OA-13 dispatches; they are not assignments to restart.
Use the registry's retained requirements for additional hosts and real consumers.
Independent movement, Hit Dice and character/content work may proceed when its
actual prerequisites are ready; completing all S-237/S-238 is not their gate.
The registry preserves the remaining requirements outside these assignments.
A working native path stays until its shared replacement covers the content;
it does not finish the shared engine migration by itself.

Crown's roadmap selects work; the slice registry still owns requirements,
prerequisites, acceptance and verified limits. A new gap required by named
in-scope content stays in Crown. Higher-level-only and unselected-content work
stays [below](#outside-crown). Do not make the whole engine denominator a gate
for finishing the campaign, or quietly reduce Crown's content to improve a count.

The [2026-11-03 integration update](docs/planning/crown-parallel-work.md#integrated-work--2026-11-03)
records merged acquisition work through PR #80, delivered OA-01–OA-13 and the
next equipment/Hit Dice split. Backgrounds and Draconic remain preparation;
production multiclassing remains unavailable. The older inventory and G1–G6
assignment descriptions are historical scope, not a fresh queue.

The [2026-11-01 local/Grokbot split](docs/planning/crown-parallel-work.md)
records the dated production inventory and bounded PR assignments. Its local
S-237 sequencing is superseded by the bounded assignments above; independent
character acquisition work still proceeds sequentially in its own shared files.
Open Hand Technique and the multiclass entry-gate implementation already exist;
their older inventory gaps must not become duplicate implementation tasks.

## Shared-engine backlog and accepted boundaries

Retain the engine backlog in the [slice registry](docs/planning/vocabulary-slices.md).
It owns requirements, prerequisites, completion status, counts and verified limits.
The [five independent quick wins](docs/planning/vocabulary-slices.md#five-quick-wins)
(S-250, S-242, S-233, S-252, S-272) now have verified engine boundaries;
catalog conversion and Guardian of Faith’s spatial trigger remain separate.
The [merged-slice completion queue](docs/planning/vocabulary-slices.md#merged-slice-completion-queue)
retains missing controls and target/source wiring from Batches 034–046 and the
specific world capabilities those implementations still need. The Crown roadmap
selects the relevant continuations from it. Reuse
completed pieces rather than repeating their proof because a broader requirement
remains open.

The initial Grokbot handoffs and playtest repairs landed in PRs #16–19.
PRs #20/#24 close the test-harness false-pass gaps; #21/#23 add bounded chosen-feat
acquisition and combat mode/upgrade controls. Their
[accepted boundaries](docs/planning/vocabulary-slices.md#pr20-24-validation)
retain fixture-only feat proof, missing backgrounds and feat mechanics, action
costs for real mode content, and volume/item measurement/role work. Do not
reassign completed chooser, ownership or control wiring.

PR #22 also repairs dawn recovery for exact projected item copies, preserving
their remembered capacity through save/load, reversion and re-equipping.

PRs #25–37 supply bounded combat placement/factory choices, exact created-creature
commands and turn policies, authored mode/command costs, room mode controls and
reaction triggers. Their review repairs and remaining work are tracked in the
[PR25–37 review boundary](docs/planning/vocabulary-slices.md#pr25-37-validation).
PRs #25–37 are merged with the review repairs and accepted within that boundary.
Unfinished scope below does not block acceptance of the delivered subset.

PRs #38–56 continue placement, attack choices, exact contents, item measurements,
attack/AC upgrades, maximum HP, last-charge properties, explicit death/object
destruction, work sites and linked-copy loss causes. Their [review boundary and
remaining work](docs/planning/vocabulary-slices.md#pr38-56-validation) own acceptance
and the unfinished hosts/content. The scenario triage also leaves existing
fixture repairs and unresolved gameplay failures; this stack is not an all-green
scenario certification. Reuse the delivered pieces instead of assigning them again.

PRs #57–60 cover the four follow-ups: stale scenario fixtures, bounded player-HUD
cast transformations, combat Find Steed arrival/recovery and additional weapon
damage-choice routes. The [reviewed boundary and original queue's open work](docs/planning/vocabulary-slices.md#pr57-60-validation)
own their remaining scope. Scope unresolved gameplay investigations and remaining
S-141 hosts to their named Crown consumers before selecting them; do not
reassign the delivered subsets. The
[condition lifetime continuation](docs/planning/vocabulary-slices.md#cast-lifetime-continuation)
supplies captured duration/concentration for flat shared condition HUD casts;
source-benefit/other lifetime owners and created-actor parameters remain open.
The [condition/roll-host recovery](docs/planning/vocabulary-slices.md#srd-condition-and-roll-host-spine)
accepts S-235/S-246/S-248 and finishes S-247’s Crown Open Hand consumers;
its level-17 Quivering Palm action/proof remains outside Crown.
The Heroism/Enhance Ability investigation repaired stale source-count assertions;
their concentration benefits and cleanup work. Counts are
163 accepted of 276 defined engine slices after the [exploration audit](docs/reviews/dnd-code-vocabulary-gap-checklist.md#exploration-and-world-procedures-audit--srd-521-2026-10-26)
added planned S-227–S-230 (travel pace/terrain, search, traps/locks) and the
[Progression/Acquisition audit](docs/reviews/progression-acquisition-audit.md) added planned S-231–S-234 and S-242–S-245;
the [core rules/conditions audit](docs/mechanics/core-rules-status.md) added S-235–S-239 (V-100/V-101) and maps rests, senses and Reaction budgets to existing rows.

The [SRC-01 feature inventory](docs/planning/vocabulary-slices.md#src-01-feature-inventory)
(batch 1) and its [batch-2 DataLoader export and clause decomposition](docs/planning/vocabulary-slices.md#src-01-batch-2)
are partial planning audits. Reviewed so far: 35 of 174 SRD class features, 6 of 58
subclass features, 0 of 17 feats (excluding the wave 2 Monk and Rogue clause reviews, which have not been recounted). They add two requirements:
[S-240/V-102 and S-241/V-103](docs/reviews/dnd-code-vocabulary-gap-checklist.md#src-01-batch-2-proposed)
(natural-roll outcome thresholds; granted/forced movement), included in the
276-slice count above. The [wave 2 audit integration](docs/planning/vocabulary-slices.md#wave-2-audit-slices) (spells, core rules batch 2, items, and the Monk/Rogue reviews) added planned S-246–S-276 and folded cover into S-238 and item jumps into S-239. It added no new V-IDs.

The [first Crown conversion batch](docs/planning/vocabulary-slices.md#conversion-batch-001)
resolves ten candidates: three shared spell conversions, one already generic
class feature and six blocked candidates. It enables no additional spells and
adds no engine-slice completions. S-121's combat save-exit host is now verified;
remaining S-121/S-122 travel hosts stay in the backlog, selected when required
by the scoped content.

S-121 now settles numeric save exits in combat and local-room exploration;
S-122 now validates represented overworld travel arrivals against live map
space and plane, and combat/room creation checks full size-based footprints,
mixed-size policies and combat-created summon room positions. Still needs to be
done from that queue: broader general-travel arrival consumers.
S-157 now supports exact-source groups on
the owner's count or one group roll, retaining separate member turns and budgets
without replay on late arrival or rebuild. S-157/S-158 retain linked-actor scheduling after owner
removal and on encounter entry with a downed/dead owner who has no initiative
entry. Real catalog conversions, remaining shared created-actor consumers,
overworld/sheet mode controls, group mode recipients and
end-early controls also remain. Outside-combat activation time is displayed but does not advance the
campaign clock. Reaction commands and reaction delivery through additional
attack/damage routes remain unfinished; Hellish Rebuke still has no supported
cast permission. Do not reassign delivered pickers, command identities or costs.

The owner's instruction to review, fix and merge accepts the reviewed work when
that workflow completes. Record acceptance and its bounded limits in the slice
registry; do not add a separate owner sign-off after merging.

Use ready assignments relevant to Crown without waiting for a new engine
framework. The [item-control continuation](docs/planning/vocabulary-slices.md#item-projection-controls)
exposes exact-copy Bond/Release and Project/Dismiss in combat and persistent
rooms, including authored costs, placement failures and checkpoint recovery.
Broader general-travel placement hosts (S-121/S-122) remain engine backlog. S-166 now
settles declared exact item-form HP/overflow/destruction and legal bag/nearby
room-ground return, including blocked/full-backpack recovery; its
[verified boundary](docs/planning/vocabulary-slices.md#exact-item-form-return)
keeps containment, passengers and vessel movement separate. The S-164 ground continuation now covers persistent
rooms and their encounters; encounters without a captured room refuse nonempty
drops before payment.
Reuse the delivered combat factory (S-155), command authority (S-156) and
bounded turn/default policies (S-157/S-158) for their remaining consumers.

Located aftermath now uses existing room objects, areas and source-end records
for shared spells, self activation modes, exact item copies and created actors:
delayed children retain their final origin and recover without replay
([VS-145 boundary](docs/planning/vocabulary-slices.md#located-source-end-continuation)).
Other hazard scopes remain separate work.
Character and independent object tether anchors are verified in
[VS-147](docs/planning/vocabulary-slices.md#character-tether-groups): group
recipients retain exact escape/rescue/damage selection, object movement and
destruction update only affected relations, and supported checkpoint recovery
preserves both anchor kinds (S-144/S-168/S-169). S-170 now supplies [actual containment occupancy/capacity](docs/planning/vocabulary-slices.md#containment-occupancy),
including room admission/inspection and exact checkpoint relationships. S-171 now supplies [internal harm/targeting and escape/rescue](docs/planning/vocabulary-slices.md#containment-internal-interactions)
with exact selection and explicit deferred release. S-172 now supplies [moving containers and legal release](docs/planning/vocabulary-slices.md#containment-movement-release), including represented room travel and blocked-release recovery. S-167 now supplies [projected vessel cargo/passengers](docs/planning/vocabulary-slices.md#projected-vessel-contents), persistent-room ground movement, separately declared endings and blocked-release recovery. Waterborne/general travel and source-backed catalog conversion remain separate. Cast-local parameter
changes (S-126/S-127/S-140/S-141) form an independent branch. The queue owns each
assignment's narrower dependencies and checks; this is not a whole-phase gate.

1. Discover any missing requirement needed by the selected capability.
2. Build and verify that capability through production Godot paths. Neutral or
   renamed fixtures are valid consumers; per-slice catalog conversion isn't required.
3. Prepare source-backed executable data and translate content using those pieces.
4. Replace native content paths once their replacements cover the content using them.
   A gap exposed during conversion becomes concrete engine work.

The standalone content editor can progress alongside runtime work using current
contracts. Its draft exports do not imply game installation support. Keep the
runtime/editor [ownership and handoff boundary](docs/content_pipeline.md#runtime-and-editor-handoff).
Quest Board is optional when concurrent work needs coordination.

S-190/S-191 now supply [bounded observer senses and concealment](docs/planning/vocabulary-slices.md#observer-senses-and-concealment),
including actual targeting/roll/AI consumers and per-observer Hidden location
discovery. Cover, remote-sensor controls, illusion investigation and general
Hide/Search remain separate.

S-184 now supplies [declared spatial trigger scopes](docs/planning/vocabulary-slices.md#spatial-trigger-scopes):
entry, crossing, first nearby movement, turn start/end and explicit area movement
have separate policies and exact source/actor/turn receipts. Selective barriers,
destructible sections and catalog conversion remain separate.

## Progression/Acquisition follow-up

The [Progression/Acquisition audit](docs/reviews/progression-acquisition-audit.md)
retains the broader acquisition backlog below. The Crown roadmap selects its
level-1–5 work; this list is not a competing execution order. S-233 and S-242
now have accepted engine boundaries, so continue their real content rather than
rebuilding those controls:
1. Content corrections: class skill and tool lists, the rogue weapon restriction and `subclass_level`.
2. Verify the existing S-234 multiclass entry gate; then extend the bounded
   progression host before production multiclass conversion. Class JSON opt-in
   alone cannot supply secondary features, subclasses, resources and casting.
3. S-231 backgrounds.
4. S-232 species choices and the SRD species set.
5. Production feats: ten Origin/General/Fighting Style feats for Crown; the seven Epic Boons remain broader work.
6. S-243 XP advancement, S-244 higher-level start, then S-245 post-20 feats (campaign-enabled). Crown keeps its existing level-1 start and milestones.

## Outside Crown

The [Crown scope rule](docs/planning/crown-roadmap.md#scope-and-finish-line)
selects named low-level consumers, not entire files, broad slices or phases.
Retain the following work here. None is a prerequisite merely because it shares
an owner with a Crown rule. If a reachable Crown spell, item, creature or feature
really needs a narrower part, document that consumer and bring that part into
the Crown queue; keep the remainder here.

| Standard-roadmap work | Scope retained outside Crown |
|---|---|
| Higher-level characters and spells | Level-17 Quivering Palm action/control and S-247 production-save proof remain here; inaccessible helper routing does not finish the slice.  Class/subclass features acquired at class levels 6–20, feats requiring those levels, seven Epic Boons, and spell levels 4–9 unless an actual Crown actor/item grants a specific procedure. Do not exclude the campaign's custom Lich King or shop potions by CR/rarity; actual reachable behavior stays in Crown. |
| Other progression modes — S-243/S-244/S-245 | XP award/threshold progression, starting above level 1 and post-20 advancement. Crown's existing milestone progression is retained. S-234 multiclass eligibility within total levels 1–5 belongs to Crown. |
| Higher-level feature consumers | S-147 consumers beyond Crown's in-band Pact of the Chain one-attack/familiar-Reaction substitution; that narrow consumer is assigned in the cross-set mapping. S-152/S-153 spell theft; S-159 inserted extra turns; S-182 passenger movement such as Monk's level-10 upgrade. Do not copy a later upgrade from a mixed-level audit row into a level-2 assignment. |
| Higher-level transformation/recovery | Full possession/control return (S-173/S-174), body-part loss/regrowth and aging procedures (S-206–S-208), and higher revival policies under S-175/S-176. Crown retains actual low-level protection, Gentle Repose/Revivify, form and corpse-interaction consumers without requiring every higher form. |
| Exceptional spells and world systems | S-268 freezing-surface occupants where only higher-level spells need it; S-270 guarded removal; S-271 accumulating delayed detonation; S-273 damageable multi-section walls; S-275 staged Control Weather; S-220/S-221 special outcomes/Wish. Low-level Druidcraft forecast information is still Crown work under represented knowledge; it is not a requirement for the complete weather simulator. |
| Unselected magic items | Dormant/unobtainable item definitions and their S-253–S-265 consumers: class-qualified attunement, scroll/staff/potion overrides, templates, worn periodic effects, weapon riders, study/tome effects, special item reactions, multi-day cooldowns and dice-shaped recharge. S-204 shared enclosed air and related physical systems remain here when only those unselected items require them. Pull in a specific power only with an actual Crown acquisition/creation path. Ordinary tools, supplied consumables, exact quantities and carrying rules remain Crown work. |
| Broader travel and maps | General planar/destination travel, unrelated vessel/waterborne/encounter-transfer hosts and map import beyond the represented Crown map/rooms. Low-level Blink, Rope Trick, flight, steed, familiar and Floating Disk consumers remain Crown work where named in its roadmap. |
| Additional sources/content/products | Artificer, Mystic, non-SRD supplements and additional subclasses; external pack ingestion and composable class-list additions; controllers, networking, publication, friend runs and a new campaign. Existing extra content remains a regression boundary without becoming a new milestone requirement. |

Source discovery stays task-sized: finish missing in-band SRD bodies needed by
the selected Crown package; retain higher-level/other-content SRC-01–SRC-04
follow-ups here. Unmapped clauses of **included** content are unfinished Crown
investigation, not grounds to mark them out of scope. No engine-wide acceptance
status or slice count changes merely because work is routed between roadmaps.

## Scope and deferred work

- SRD 5.2.1 governs the staged twelve-class milestone. Artificer, Mystic and later
  supplements remain outside it. Source gathering and content correctness are
  separate from engine completion.
- Crown remains a level 1–5 campaign for one to four shared-keyboard players and
  four stable party slots. Full campaign readiness isn't certified by slice tests.
- Owned creature/form controls, broader world/NPC/illusion interactions and
  unfinished Animate Objects integration retain their [documented limits](docs/mechanics/spell-foundations.md).
- External pack ingestion and composable class-list additions remain an
  [integration requirement](docs/content_pipeline.md#external-pack-integration), not an implemented API.
- Map wall/crossing import is future world integration. Reuse existing movement,
  geometry and visibility boundaries; see [map requirements](docs/architecture/README.md#map-integration).
- Keep existing save locations and checkpoint limits. Don't build migration or
  compatibility frameworks ahead of a feature that needs them.
- Controllers, networking, publication, friend runs and a new high-level campaign
  remain parked until wanted. Old gate sequences don't choose work.
