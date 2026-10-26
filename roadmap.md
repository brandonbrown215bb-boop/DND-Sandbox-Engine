# Roadmap

Build one shared, data-driven D&D 2024 rules engine in Godot. JSON describes
rules; code interprets reusable operations and supplies world access. Prepared
content using completed capabilities must run without content-ID branches.
[ADR-0018](docs/decisions/0018-shared-data-driven-rules-runtime.md) owns this direction;
[ADR-0023](docs/decisions/0023-vocabulary-first-delivery-and-bounded-world-judgment.md)
retains vocabulary-first delivery, current save priorities, and Wish/illusion policy.

## Current work

Continue the engine backlog in the [slice registry](docs/planning/vocabulary-slices.md).
It owns requirements, prerequisites, completion status, counts and verified limits.
The selected work is the [merged-slice completion queue](docs/planning/vocabulary-slices.md#merged-slice-completion-queue):
finish the missing controls and target/source wiring from Batches 034–046, and
build the specific world capabilities those implementations still need. Reuse
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
own their remaining scope. Continue the unresolved gameplay investigations or
S-141 duration/concentration; do not reassign the delivered subsets. Counts stay
151 accepted of 231 defined engine slices; the [core rules/conditions audit](docs/mechanics/core-rules-status.md)
added S-235–S-239 (V-100/V-101) and maps rests, senses and Reaction budgets to existing rows.

The [first Crown conversion batch](docs/planning/vocabulary-slices.md#conversion-batch-001)
resolves ten candidates: three shared spell conversions, one already generic
class feature and six blocked candidates. It enables no additional spells and
adds no engine-slice completions. S-121's combat save-exit host is now verified;
continue with the remaining S-121/S-122 travel hosts.

S-121 now settles numeric save exits in combat and local-room exploration;
S-122 now validates represented overworld travel arrivals against live map
space and plane, and combat/room creation checks full size-based footprints,
mixed-size policies and combat-created summon room positions. Still needs to be
done from that queue: broader general-travel arrival consumers.
S-157 now supports exact-source groups on
the owner's count or one group roll, retaining separate member turns and budgets
without replay on late arrival or rebuild. S-157/S-158 retain linked-actor scheduling after owner
removal and on encounter entry with a downed/dead owner who has no initiative
entry. Real catalog conversions, Find Familiar's
creature-type choice, overworld/sheet mode controls, group mode recipients and
end-early controls also remain. Outside-combat activation time is displayed but does not advance the
campaign clock. Reaction commands and reaction delivery through additional
attack/damage routes remain unfinished; Hellish Rebuke still has no supported
cast permission. Do not reassign delivered pickers, command identities or costs.

The owner's instruction to review, fix and merge accepts the reviewed work when
that workflow completes. Record acceptance and its bounded limits in the slice
registry; do not add a separate owner sign-off after merging.

Start the ready assignments in that queue without waiting for a new engine
framework. The [item-control continuation](docs/planning/vocabulary-slices.md#item-projection-controls)
exposes exact-copy Bond/Release and Project/Dismiss in combat and persistent
rooms, including authored costs, placement failures and checkpoint recovery.
Continue the remaining general-travel placement hosts (S-121/S-122). S-166 now
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
