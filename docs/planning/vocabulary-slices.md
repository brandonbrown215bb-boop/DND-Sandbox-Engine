# Vocabulary delivery slices

This registry owns slice IDs, requirements, prerequisites, completion status and
verified boundaries. The [vocabulary checklist](../reviews/dnd-code-vocabulary-gap-checklist.md)
owns broader V-series requirements and source gaps. The [roadmap](../../roadmap.md)
chooses work; completing a bounded slice doesn't close its broader parent or
certify converted catalog content.

## Count and scope

**226 defined slices: 151 verified, 75 not yet accepted.** Counts measure accepted
bounded implementations, not time, effort or completion of every clause in a row.
These totals include reviewed, repaired and merged Batches 034–065 through
2026-10-21, plus combat save-exit placement (VS-144), the bounded located source-end continuation (VS-145) and
exact item-form return (VS-146), Character/object tether groups (VS-147), and
actual containment occupancy/capacity (VS-148), internal harm/escape (VS-149),
moving containers/legal release (VS-150), and projected vessel contents/movement
(VS-151);
remaining limits are recorded below.

SRD 5.2.1 governs the staged core-12 target. Artificer, Mystic and later
supplements remain outside it. Missing rule bodies stay in source follow-up;
new source-backed requirements can change the denominator. Content translation
and individual-record correctness are separate work. Neutral/renamed fixtures
can prove engine capabilities through production paths without converting
catalog content as part of every slice.

| Phase | Defined | Verified | Not yet accepted |
|---|---:|---:|---:|
| P1 — Facts, results and grants | 34 | 34 | 0 |
| P2 — Pools, time and effect state | 50 | 41 | 9 |
| P3 — Rolls and decisions | 27 | 22 | 5 |
| P4 — Damage and consequences | 25 | 20 | 5 |
| P5 — Casting and action composition | 20 | 12 | 8 |
| P6 — Actors and forms | 23 | 17 | 6 |
| P7 — Space, perception and illusions | 19 | 1 | 18 |
| P8 — Physical items and bodies | 18 | 4 | 14 |
| P9 — Procedures and campaign outcomes | 10 | 0 | 10 |
| **Total** | **226** | **151** | **75** |

## How to use a row

- Treat the finish line as the observable implementation and production-verification boundary.
  Reuse existing execution owners and accepted proof; inspect source only enough
  to determine missing wiring when selecting the row. Planned does not mean the
  code has none of it. Some rows may need only a small extension plus acceptance.
- `After` lists the narrower slices needed first, not completion of entire phases
  or V-series parents. The parent checklist retains source examples, static hook
  hints and broader requirements. Those hints remain uncertain until checked.
  Match prerequisites to the selected behavior; don't demand a universal engine
  or wholesale combat extraction as a prerequisite.
- At build time use neutral/renamed data where relevant, the actual world hook
  and a focused development check. Production validation uses the real supported
  input/choice route for timing, result fields, once-only costs/effects and
  refusal/cleanup. Build and validation can share an owner-authorized chat;
  use focused independent review for shared combat rules or persistence changes.
  Reuse unaffected proof rather than running every green group again.
- Every new durable state belongs to its implementing slice: owner/source/recipient,
  exact payload, counters and clocks survive allowed checkpoints without replay;
  malformed loading refuses before replacing the session. Decisions/turn locks
  stay transient. V-057 is carried by these stateful slices, not a prerequisite
  migration framework or a new permission to save mid-combat.
- Human/source questions park only their affected row; continue independent ready
  work. Unknown facts/actions stay explicit. ADR-0023 governs observer-specific
  illusions, campaign outcomes/Wish and current save priorities.
- Check the selected implementation and its production evidence together. Fix
  reproduced defects before dependent work; batch size follows behavior. A
  separate acceptance report or owner-decision record isn't required.
- When the owner directs review, repair and merge, completing that workflow
  accepts the reviewed implementation; no second owner sign-off is required.
  Record its verified boundary and remaining work here. Acceptance does not
  implement missing clauses or close the broader V-series requirement.

## Current and next queue

The owner selected a completion plan for the missing behavior in merged Batches
034–046. Use the assignments below and their actual prerequisites. These are
continuations of existing slice scope, not new S-IDs or new acceptance claims.
The old numbered prompts and gate chains aren't queues to resume.

<a id="merged-slice-completion-queue"></a>

## Merged-slice completion queue — 2026-10-20

This queue scopes work that can start now and the engine pieces needed by its
dependent behavior. It is not a claim that all assignments fit into one day.
The accepted implementations and remaining limits are recorded in the next
section. Retain their proof; implement and verify the missing part only.

**Initial Grokbot handoffs have landed:** form/equipment chooser, proper
magic-item types/weight support, and species/species-feat/exact-item ownership.
The accepted boundaries and unfinished clauses are recorded below. Do not
reassign completed work or treat the larger queue as additional scope for those
jobs; continue the named follow-ups using the existing building blocks.

<a id="pr16-18-validation"></a>

### Accepted handoffs and playtest repairs: PRs #16–19

[PR #16](https://github.com/brandonbrown215bb-boop/DND-Sandbox-Engine/pull/16),
[PR #17](https://github.com/brandonbrown215bb-boop/DND-Sandbox-Engine/pull/17),
[PR #18](https://github.com/brandonbrown215bb-boop/DND-Sandbox-Engine/pull/18)
and [PR #19](https://github.com/brandonbrown215bb-boop/DND-Sandbox-Engine/pull/19)
are merged and accepted within the boundaries below. The final repaired head
`a495177` and merged main `ab99926` have the same tree. Fixes and continuations
do not add vocabulary slices: the accepted count remains 138.

The supported Windows Godot runner passed 5,449 logic checks with zero failures.
Ten selected integrations passed; after the final rest-capacity fix, full logic
and the affected 049/050 save flows passed again. A focused independent reviewer
accepted the ownership, recovery and rest fixes. Raw logs and isolated probes
remain under ignored `.artifacts/reviews/`; the existing
[build note](../reviews/batch-050-build.md#rooks-final-review-corrections)
records the verified repairs.

| Assignment | Review boundary and remaining work |
|---|---|
| Form/equipment chooser — #16 | Accepted combat-HUD chooser, including cancellation, stale answers and chosen-form save/load. Native Wild Shape conversion and item-to-actor placement remain separate follow-ups; the ground continuation below replaces backpack set-aside. The chooser-before-actor-validation note remains open. |
| Item types/measurements — #17 | Accepted type support, 35 source-backed catalog weights and real backpack weight limits. Containers remain explicitly partial: volume is not enforced. Worn wondrous slots cover head/feet; staffs do not yet act as Quarterstaffs or generic focuses. Existing real staff/focus/figurine conversions remain separate. The S-164 shared room-copy placement payload now preserves unknown weight instead of inventing 1 lb.; broader measurement and volume guarantees remain bounded. |
| Species/feat/item modes/upgrades — #18 plus #19 | Accepted species/species-granted-feat acquisition and exact equipped/attuned item ownership. Equipped drops preserve spent uses; suppression/merging preserve owned capacity and still process ending conditions; identical copies keep separate pools; missing species feat references fail loading. PRs #21/#23 supply chosen Origin/ASI feat acquisition and combat mode/alternative controls within the bounded follow-up below; backgrounds, real feat content and missing feat mechanics remain unfinished. |

The copy remembers its chosen option across unequip, transfer and reload. Dawn
recovery reaches carried, contained, attached and saved-room copies, with separate
equipped/attuned requirements when declared. Acquired item powers recovering on
a rest retain their owned upgraded capacity while suppressed or merged. Copies
dropped mid-combat still miss dawn until returned to a room or inventory.
Identical copies retain separate pools even when their benefits must not stack.
Suppression must explicitly list `features` to mute item modes/upgrades; no SRD
spell conversion is claimed. The owner chose partial weight-only containers;
volume work remains Q-20261021-004820-65fc. These choices require no new sign-off.

<a id="pr20-24-validation"></a>

### Accepted harness and control follow-ups: PRs #20/#21/#23/#24

PRs #20/#24 make registered check load/compile failures and runtime script errors
fail the logic runner and viewport scenarios. The Windows wrappers still reject
missing success/gate markers. Injected runtime failures in each harness return
exit 1; valid scenarios retain their normal result.

PR #21 accepts fixture-backed Origin selection in creation and an eligible feat
instead of a pending ASI on the sheet. Ownership, modes and pools reconstruct
once. Final acceptance repairs saved ability prerequisites: malformed/unmet
permanent scores refuse before live session replacement. PR #23 accepts the
combat HUD mode/upgrade controls, exact-copy gates, cancellation and stale
answers. Final acceptance invalidates old popups when the owner leaves and later
regains the active turn. Fresh-process safe-save recovery retains chosen feats,
active mode/time, spent uses, exact copies and upgrade choices without replay.

PR #22 continues the existing item-source and projection slices: campaign dawn
also reaches the exact copy stored in an item-projection record. Its remembered
capacity, injured actor identity and recharged uses survive a real SaveManager
checkpoint, reversion and re-equipping. Projected copies remain unequipped for
`recharge_while` policy. This adds no slice or broader item-projection controls.

These are continuations: the verified slice count remains **138**. No playable
feat catalog is included. Creation currently offers a free Origin choice because
backgrounds are absent. Feat ability increases, class/feature prerequisites,
Fighting Style grants and the level-19 alternative feat path remain open. Mode
activation originally had no action cost in these fixtures; PRs #25–37 add
generic authored costs as recorded below. Existing reselect/switch semantics
remain. There is no overworld/sheet mode panel or end-early control. The
[source-carrier contract](../mechanics/source-benefit-carriers.md#modes-forms-and-exact-item-state)
owns the syntax and these limits. SRD feat work should stage complete source-backed
candidates and list missing operations before any promotion into loaded data.

Windows acceptance passed full logic and the selected 049/050/051/052, creation,
sheet-context and action-resource flows. The normal-creation matrix still has the
same 16 failures on unchanged main (outdated equipment/style/Artificer expectations);
it is not certified by this acceptance. Existing PR discussions retain exact
counts and the final regression/injection results; raw logs stay ignored.

### Ready assignments using existing building blocks

<a id="pr25-37-validation"></a>
#### PRs #25–37: reviewed subset and work remaining

PRs #25–37 are merged with the review repairs and accepted within the boundary
below. Acceptance of the bounded work does not require completing the remaining
scope. S-122 and S-155–S-158 add five accepted bounded implementations
(VS-139–VS-143); mode and reaction work continues existing slices. S-121 is
verified separately as VS-144 within the combat single-target save boundary;
its exploration and travel follow-ups remain open. The original requirements
and all listed follow-ups remain open.
Use the [created-actor contract](../mechanics/created-actors-and-placement.md)
and [mode contract](../mechanics/source-benefit-carriers.md#modes-forms-and-exact-item-state)
for executable syntax instead of the historical build reports.

| Area | Delivered subset | Still needs to be done; does not block this subset |
|---|---|---|
| <a id="vs-139"></a><a id="vs-140"></a><a id="vs-144"></a>S-121 / S-122 / S-155 | S-121 (VS-144): flat combat saves retain the captured roll, total and DC while the required exit settles before consequences; authored no-space results and conditional payment follow the final save once. Sanctuary and cast costs do not replay. The local-room spell host now binds actual room party coordinates, plane and grid; its highlighted map choice and cancel control resume through the same captured continuation, rechecking occupancy before consequences. S-122 (VS-139) and S-155 (VS-140): combat and room creation reserve and recheck complete size-based hex footprints. Mixed templates retain per-kind sizes, command and initiative policies; partial blocks reject the whole footprint. Persistent spell actors created in combat now capture their encounter cell on exit and restore it through exploration, later encounters and the allowed room checkpoint. Overworld random travel selects a legal tile on the travelers' represented plane; explicit unknown or illegal coordinates refuse without moving the party. Authored no-space refusal or spending creates no overlapping actor. | Item-projection controls are delivered in the [control continuation](#item-projection-controls); broader template parameter choices such as Find Familiar's creature type. Room creation adds no movement behavior or catalog conversions. |
| <a id="vs-141"></a>S-156 (VS-141) | Exact actor-ID command rows; authored per-order Action, Bonus Action, Magic action or free costs; range, ownership and affordability refusal; once-per-actor-per-owner-turn commands; Dodge/Attack and declared uncommanded defaults. | Additional orders, Reaction commands with their own trigger, real source-backed consumers. Legacy fallback costs/timing are compatibility behavior; new content must declare its own policy. |
| <a id="vs-142"></a><a id="vs-143"></a>S-157 / S-158 (VS-142/143) | Owner-turn, after-owner, independent and shared-count initiative. Exact-source groups use the owner's count or one group roll; each member retains its own turn, budgets and condition boundaries. Stable source/member ordering, per-count late-arrival deferral and encounter history prevent extra/replayed turns across removal or group rebuild. Owner state/control expiry overrides queued orders; living persistent sources survive loss of control. Hidden scheduling-only slots retain linked actors' defaults, condition ticks and source durations after owner removal; absent downed/dead owners receive one shared end-of-round anchor on encounter entry. Recovery/re-entry reuses the slot and round history. Saved sources re-enter encounters legally. | Broader autonomous orders/movement, hostile control conversion and catalog summon conversions. Group scope is one exact cast source; arbitrary cross-source grouping is unsupported. Live mid-combat tracker persistence is outside the supported save checkpoints. |
| Mode costs and controls | Declared activation/reselect/switch costs use the existing budget and preserve free undeclared fixtures. The local room panel uses the same state; authored activation time is exposed. | Catalog conversions, overworld/sheet panels, group-recipient choices and end-early controls. Campaign time passing for outside-combat activation remains partial; no clock advances. |
| Reaction triggers | Declared spell triggers and on-hit mode switches; confirmation rechecks live location, sight, turn, casting and target eligibility before payment. | Hellish Rebuke's actual cast permission; spell attacks, additional swings, opportunity attacks, areas, other damage sources and creature/monster reactors. After-hit triggers cannot alter the triggering attack; Shield retains its existing path. Area/creation/formula/spatial reaction hosts remain unsupported. |

The owner-removal continuation is covered by `CreatedActorSchedulingChecks` and
`created_actor_scheduling_flow`: removal before/during/after the owner's slot,
several actors and sources sharing it, downed/dead encounter entry, recovery and
re-entry, control expiry, concentration/source-duration cleanup, preserved next
actor work, and defeat with persistent summons. The source format and allowed
checkpoint boundary remain unchanged; no catalog conversion is claimed.

The shared-count continuation uses loaded renamed JSON consumers in
`SharedInitiativeChecks` and `shared_initiative_flow`: multiple members, separate
groups tied on a count, deterministic source/member order, distinct budgets and
condition ticks, death/source removal, late arrivals, active/empty-group rebuild,
settled-attack replay refusal and owner disconnect/resume. The production flow
also retains the removed owner's consumed anchor into the following round.
The [created-actor contract](../mechanics/created-actors-and-placement.md#exact-commands-and-turns)
defines source grouping, count closure and next-round admission.

Review regressions reproduce queued orders overriding expiry/death/incapacity,
unticked owner-turn conditions, summons preventing party defeat, projected-item
cleanup collisions, smaller material-capped records and invalid reaction payment.
Repairs also cover initial initiative ordering, chosen-template clearance, plane
context, stale remains and saved summon encounter entry. Windows logic and
production-control scenarios supply the acceptance checks; raw logs stay ignored.
Full Windows logic passed **5,672/0**, and all thirteen new 053–065 scenarios
passed. Separate-process SaveManager recovery retained exact actor IDs, injured
HP, control deadlines and a smaller material-capped mixed cast. Valid player-only
and party checkpoints passed preflight; malformed control deadlines refused in
both DTO paths. Existing owned-creature, created-undead and 052 mode-control
flows also passed. The older familiar-delivery check needed a real owned spell
grant/payment and slot-picker answer instead of a raw catalog command; unchanged
main reproduced its four original failures. This fixture repair preserves the
gameplay checks. No manual visual acceptance or catalog completion is implied.

<a id="conversion-batch-001"></a>

#### First Crown-focused content conversion batch — 2026-10-21

This is a ten-candidate content check, not additional engine slices. Authority:
[SRD 5.2.1](https://media.dndbeyond.com/compendium-images/srd/5.2/SRD_CC_v5.2.1.pdf),
with the selected Fighter/Barbarian reference views used to locate class clauses.
Promoted spells preserve IDs and class access in one curated manifest winner.
Incomplete replacement definitions remain outside loaded content; their existing
native paths stay in place. The source/operation map and drafts are ignored artifacts.

| Candidate | Result | Verified behavior or exact blocker; owning existing work and next acceptance check |
|---|---|---|
| Bless | Converted | Shared multi-target condition grant, paid Holy Symbol component, slot-scaled target cap and concentration. Existing bonus wiring now reaches Death Saves, preserves natural 1/20, and does not spend Indomitable on a Bless-converted success. Downed recipients are legal; dead recipients refuse. |
| Bane | Converted | Shared per-target CHA saves and penalties, sight, slot-scaled target count and source-owned concentration. Failed and successful recipients settle independently, including downed Characters. |
| Mass Healing Word | Converted | Shared selected-recipient healing, sight, six-target cap, Bonus Action, spellcasting modifier and upcast dice. First-recipient downed selection, actual-target visibility and prepayment recipient-cap checks reuse existing operations. |
| False Life | Blocked | SRD pp.73/129: Fiendish Vigor must maximize its free cast. That behavior remains an ID-specific native resolver branch; no existing permission-to-Temporary-HP dice transformation is connected. S-123/S-126/S-134/S-135: prove a renamed source's free cast grants 12 without rolling or spending a slot, alongside ordinary rolls/upcasting and keep-higher HP. Do not replace the native spell until both consumers work. |
| Shatter | Blocked | SRD p.161: the existing resolver already handles Construct save Disadvantage, but the shared field whitelist omits its parameter. The deeper gap is object delivery: the generic route chooses one object only on an otherwise empty cell and would roll a CON save. S-032/S-091/S-098/S-099: prove full damage to every eligible object, including several objects collocated with a creature, while excluding magical/worn/carried copies. Merely enabling the Construct field is insufficient. |
| Hellish Rebuke | Blocked | SRD p.140: the trigger concerns creature-caused damage, while the current host emits it only for monster weapon attacks on Characters. S-041/S-042/S-134/S-135: demonstrate weapon, spell and area creature damage, with live sight/range and cancel/stale no-payment checks. Real cast permission stays disabled until coverage works. |
| Ring of Protection | Blocked | SRD p.238 and attunement rules: AC plus saving throws and same-kind attunement must follow the exact worn/attuned copy. Saving bonuses and duplicate attunement still branch on the item ID; shared source benefits accept AC/speed only. S-049/S-050/S-203: a renamed item must grant both bonuses and enforce attunement without ID policy; test suppression/merging, transfer and checkpoint recovery. |
| Boots of Speed | Blocked | SRD p.214: doubling Speed, Opportunity Attack Disadvantage, ending/reactivating and ten cumulative minutes reset by Long Rest do not fit fixed additive mode benefits. S-050/S-064/S-091/S-103/S-179: prove a true toggle, changing base speed, pause/resume, exhaustion, worn/attuned ownership and rest recovery without restarting allowance. No partial boots definition is promoted. |
| Fighter: Second Wind | Blocked | SRD pp.47–48: healing activation, uses and rest recovery already use the common executor. The complete candidate still has native Tactical Mind resource and Tactical Shift feature-ID hooks. Preserve the original resource. S-006/S-094/S-126/S-146/S-179: renamed source and consumers must share expenditure/refund and Shift movement, with no extra action or recovery on reload. Existing common healing/recovery is verified, not counted as another conversion. |
| Barbarian: Fast Movement | Already generic | SRD p.29: existing `speed_bonus` plus `requires_no_heavy_armor` handles acquisition at level five and live equipment changes. Renamed feature identity retains behavior. No rewrite. |

The batch adds three shared spell definitions and no newly enabled spells.
Source ownership, costs and saved-record shapes stay on their existing paths;
native handlers remain for consumers not replaced here. No S-ID or verified-slice
count is added. S-121's combat save-exit host is now verified; S-122's item-projection controls are delivered in the [control continuation](#item-projection-controls); Batch 066 extends arrival placement to combat and local-room teleport (Misty Step, data-authored distance and sight) and forced-movement steps; Find Steed arrival, multi-target and planar teleports, and engulf/swallow escape exits (card 1c72; no host exists yet) remain PARTIAL in that branch. Batch 076 (#38 follow-up) checks every footprint cell against terrain and map bounds for forced-movement steps, including a start that already overlaps a creature (the escape allowance waives creature overlap only, never terrain); Find Steed arrival, multi-target/planar teleports and engulf/swallow exits are still PARTIAL. Batch 086 delivers Find Steed arrival: the whole Large footprint is checked through `PlacementRules` with data-authored range/no-space policy, refusals spend nothing, and a saved steed is recovered on a full-footprint space; exploration-mode steed occupancy, multi-target/planar teleports and engulf/swallow exits remain PARTIAL.

Acceptance checks: `ConversionBatch001Checks` and
`conversion_batch_001_flow`, the existing Mass Healing Word/effect-lifetime
controls, real SaveManager party/player-only preflight and separate-process
checkpoint recovery. Raw logs remain in `.artifacts/conversion-batch-001/` and
the runner's ignored test directories. The focused independent review checked
combat/recipient/payment wiring and saved-record compatibility. Full logic passed
5,717 checks with zero failures. All five affected live scenarios passed; the
effect-lifetime scenario passed separately after repairing its stale expectation
that the caster belongs in the external concentration-target list. A fresh
process recovered the same source with 47 seconds left and Second Wind still
spent, then expired the effect. A separate process also recovered the player-only
form of that actual checkpoint with the same assertions. Both saved DTOs passed
production preflight and rejected malformed durations before session mutation.

<a id="conversion-batch-002"></a>

#### Conversion Batch 002 — verified boundary (2026-10-22)

Keep the remaining S-122 placement hosts in the engine queue. This batch had four
fixed records: two native-to-shared replacements and two corrections to already
shared data. It adds no engine operations or slice completions.

| Record | Batch result | Verified boundary |
|---|---|---|
| Hold Monster | Converted | Shared failed-Wisdom-save paralysis, concentration, end-of-turn repeat saves, and one additional target per slot above level 5. Real picker verified independent failed/successful outcomes, one payment, exact-source cleanup and fresh-process recovery. |
| Circle of Death | Converted | Shared Sphere selection, Constitution save damage/half damage, upcast dice and reusable 500 GP black-pearl-powder component. Live cancellation, stale post-cancel answer, invalid center, mixed saves, one payment and retained component verified. |
| Cure Wounds | Corrected, already shared | Removed the imported Construct/Undead exclusions. Live casting revived a downed ally and paid one upcast slot/action; eligible Construct/Undead and dead-target handling checked. |
| Healing Word | Corrected, already shared | Removed the same imported exclusions. Live casting healed a visible ally with Bonus Action/slot payment; eligible Construct/Undead and dead-target handling checked. |

Authority: [SRD 5.2.1](https://media.dndbeyond.com/compendium-images/srd/5.2/SRD_CC_v5.2.1.pdf),
Circle of Death p.115, Cure Wounds p.121, Healing Word p.139 and Hold Monster
pp.140–141. The healing entries do not exclude Constructs or Undead.

Production inventory, captured before and after promotion: 362 spell IDs; 134
available both times; shared definitions increased from 15 to 17. Result: two
conversions (Hold Monster and Circle of Death), two corrections (Cure Wounds and
Healing Word), and zero newly enabled spells. Existing IDs and class lists remain
intact. Complete definitions and explicit manifest replacements live in
`data/core/spells/conversion_batch_002.json` and `data/content_manifest.json`.

Verified with the supported Windows Godot runner in serial isolated profiles:
production parse/boot, all spell logic checks, the real-control
`conversion_batch_002_flow`, renamed-ID production-loader and shared-operation
checks, and separate fresh processes loading both full-party and player-only
checkpoints. Both save DTOs passed production preflight. A focused independent
review found no shared combat or persistence defect.

Remaining limits: no object damage for Circle of Death; Circle's 60-foot area is
represented on the current hex grid; Hold Monster sight does not account for
terrain occlusion. Healing suppression and class-specific healing benefits were
not re-audited here. All four spells remain gameplay-partial, with full clause
audits open. These level-5/6 catalog records do not expand Crown's current
character-level 1–5 progression. No engine slice completion was added; retain
the existing S-122 placement hosts and six Batch 001 engine blockers in their
current assignments.

| Assignment | Owning slices | Concrete implementation and finish line |
|---|---|---|
| Form and equipment choices — delivered | S-163/S-164 | PRs #16/#19 complete the declared combat chooser. Do not reassign it. The ground-copy continuation below now covers persistent rooms and their encounters. |
| Exact target choices in existing controls — bounded delivery | S-127/S-168/S-169/S-196/S-210 | Accepted: exact tether escape/rescue/cut; authored weapon damage-type choices at activation or hit, per swing or explicitly per Attack action; exact compartment/content/socket/part selection in room and vessel-cargo controls. Reuse [attack profiles](../mechanics/attack-profiles.md) and [exact contents and parts](../mechanics/exact-contents-and-parts.md). Batch 087 adds Opportunity/Light/Nick/Cleave/created-creature turn choice hosts. Remaining (PARTIAL): S-156 commanded-actor and summon attack hosts, item-granted profiles, reach/mastery choices, worn/equipped hosts in the room selector, combat contents/parts controls and nested containers. |
| Remaining item measurements and roles — bounded delivery | S-032/S-196, supporting S-165 | Accepted: unknown physical facts through placement, take, inspection, projection and compartment checks; conservative legacy stamp recovery; declared room item-count capacity separate from the technical record limit; 47 additional [SRD weights](../mechanics/srd-item-weights.md). See [unknown measurements](../mechanics/unknown-measurements.md). Remaining: volume (65fc), room weight limits, carry/encumbrance totals, pack totals without double-counting, unaudited imported/tool/magic-item weights, staff focus roles and additional worn slots. Runtime/editor ownership remains unchanged. |
| Chosen feats and player mode/upgrade controls — bounded delivery | S-049/S-050/S-084/S-085/S-103/S-104 | PRs #21/#23 complete fixture-backed Origin/ASI feat acquisition and combat controls within the acceptance above. Next work is backgrounds/grants, missing feat prerequisites and ability benefits, and source-backed content staging. PRs #25–37 add the generic authored action costs; real mode content still needs conversion. Reuse existing ownership, controls and pools; do not reassign the completed wiring or promote incomplete feat shells. |
| Upgrade consumers beyond modes — bounded delivery | S-084/S-085, reusing S-039/S-021/S-146 | Accepted: owned exclusive Extra Attack counts and unarmored base-AC alternatives, removal/reversion and checkpoint recovery. Switching never refunds or adds swings to the current Attack action; a new action uses the new total. See [attack and AC upgrades](../mechanics/attack-and-ac-upgrades.md). Remaining: source-backed class/item conversions, choosing among all base-AC sources (including Mage Armor), armored formulas and reach/mastery consumers. Only the first unarmored-defense consumer is supported. Mid-combat saves remain outside allowed checkpoints. |
| Maximum-HP rules on monster records — bounded delivery | S-130/S-131 | Accepted: shared-spell grants on monster records, exact source removal, clamps and zero-maximum death; explicit combine/accumulate policies for new definitions; strongest request then newest tie within the declared rule identity; net-growth current-HP increases and legacy records. See [monster maximum HP](../mechanics/monster-max-hp-sources.md). Remaining: monster periodic/cure event producers and monster attacks applying these sources to monsters; broader source-backed conversions. Monster records are not saved mid-encounter; no new checkpoint was added. |
| Enforce item degradation and remaining properties — bounded delivery | S-060/S-203 | Accepted: exact-copy keep/loss through magical-property consumers, weapon attack/damage bonuses, declared destroy/degrade/nonmagical outcomes, independent copies and allowed checkpoint recovery. Missing legacy charges initialize only under the explicit data policy, including contained/attached and room-picked-up copies; existing zero charges never refill. See [last-charge properties](../mechanics/last-charge-property-loss.md). Remaining: complete staff conversions (Power class-restricted attunement, spells, saves/spell attacks, Retributive Strike and d20=20 regain; Striking per-hit spend), dice-shaped dawn recovery, ending existing attunement after all magic is lost, exact hand selection between identical equipped weapons, projection with aftermath, and native wand conversion. Staff data remains partial. |
| Explicit death/destruction without damage — bounded delivery | S-119, consuming S-043/S-117 | Accepted: authored creature death/destruction independent of damage, current-HP eligibility, at-zero policy, exact cause/remains and repeat refusal; declared above-limit damage fallback (Power Word Kill) and separate unattended nonmagical object destruction through existing world cleanup. See [explicit death](../mechanics/explicit-death.md). Remaining: successors/replacements and Death Ward instant-death negation, magical or worn/carried object destruction, other fallback triggers, pending damage choices inside ordered/combined fallback effects, native Disintegrate conversion and full multi-target interaction coverage. Follow the existing damage/death hook limits rather than assuming every death-producing route is complete. |
| Work eligibility at an actual location — bounded delivery | S-066 | Accepted: exact represented room start cell, helper proximity and incapacitation at start/join/accrual, authored keep/reset interruption across long clock jumps and allowed reload; a paused absence resets only past the declared limit, including a late return. See [work sites](../mechanics/work-sites.md). Remaining: overworld/travel location hosts, movement within one clock jump, combat positions and room-object sites. Wait 8 hours only advances the campaign clock; it is not a rest and has no hostile-room gate. |
| Linked-copy loss reasons — bounded delivery | S-162 | Accepted: give/stow/drop/sale/destruction/projection causes at exact-copy removal; only declared causes dispose linked mates; legacy any-loss behavior remains. Consumption, fuel, components and item payment use destruction. See [linked removal causes](../mechanics/linked-removal-causes.md). Remaining: bonded copies in carried containers (currently refused), bonded attachments (refused), live projection-disposal scenario and source-backed trigger clauses. A separate consume cause is deferred until content needs it. |

<a id="pr38-56-validation"></a>

### PR38–56 review boundary and remaining work

The ten initial integrations (Batches 066–075), scenario triage (#48), and
follow-up rulings (Batches 076–083) are accepted only within the delivered
boundaries in the assignment table above. No whole-slice completion or catalog
readiness is inferred from these fixtures; slice counts stay unchanged.
The existing roadmap and broader queue still choose the next work.

Merge review adds the Windows-runner registration missing from these branches:
selecting a new flow also runs its reload in a fresh process against the same
isolated profile. Selecting a reload prepares its flow first. The Linux triage's
nine isolated-reload failures were missing-input failures, not evidence of lost
saves. Windows results and merge repairs are recorded in the final PR description.

The [dated triage](../reviews/scenario-triage-2026-10-25.md) is a baseline
inventory, not a current all-green claim. Its remaining work is:

- R1 and representative R2/R3 fixture repairs are delivered in #57; see the
  [PR57–60 boundary](#pr57-60-validation). Production component and permission
  validation stays enforced. Barkskin's repaired fixture passes; this does not
  establish the old sweep's suspected duplicate-record diagnosis.
- Resolve R9: multi-target Heroism/Enhance Ability concentration cleanup, Bard
  decline-standing prompt, aura suppression exit, Identify's magic-item target,
  local-room movement modes/uphill cost, next-melee typed-grant consumption,
  the P1 repeated damage-request settlement and wizard free-cast context.
- R4–R6's round-field typo and stale asynchronous combat callbacks receive narrow
  merge repairs; this does not certify all encounter scheduling or old scenarios.
- Startup-only Linux hangs passed their single rerun. Reproduce them on the
  supported runner before treating them as gameplay failures. Full-sweep counts
  remain tied to the dated commits and platform in the report.

<a id="pr57-60-validation"></a>

### PR57–60 review boundary and the original four-job queue

PRs #57–60 deliver Batches 084–087 within the following boundaries. Review repairs
are carried on #60's final stack head. These extend accepted hosts and provide a
partial S-140 implementation; they add no whole-slice completions. Counts remain
**151 accepted / 75 remaining**. They do not certify the whole scenario inventory
or convert additional catalog content.

| Original job | Delivered and reviewed | Open work |
|---|---|---|
| 1. Stale scenario fixtures (#57) | Explicit two-monster setups; legal component pouch/free-hand setup; class-owned spell choices and permissioned HUD rows, with a missing row failing instead of casting a raw record. Supported Windows checks cover the repaired representatives. No game rule was weakened. | Other fixture ownership/content errors remain for supported-runner reproduction: the prior review found a missing Fireball menu row in `fire_area_object_ignition_flow` and an illegal Ranger Charm Person choice in `ranger_natures_veil_blindsight`. Investigate the gameplay failures below separately. The old Linux sweep and isolated-reload failures are historical evidence, not current Windows failures. |
| 2. Cast-local transformations, S-126/S-140 (#58) | Permissioned player HUD casts capture range, V/S component removal, school and Action/Bonus Action changes without catalog mutation. Compatible changes apply once; both timing directions use the transformed budget even after the original budget is spent. Wand activation now copies its catalog record. See [attack profiles](../mechanics/attack-profiles.md). | S-141 duration/concentration and created-actor parameters; costed profiles; reaction, exploration, AI and item-activation hosts; Material removal and native Metamagic conversion. The profile itself is free; its cast pays once. |
| 3. Find Steed arrival, S-121/S-122 (#59) | Chosen combat arrival checks the whole Large footprint before payment. Blocked/stale destinations and cancellation spend nothing; success pays once. Unmounted recovery chooses a legal footprint; mounted recovery permits its rider while refusing terrain/other bodies. Allowed save/load and paired fresh-process recovery retain the steed. See [placement](../mechanics/created-actors-and-placement.md). | Exploration steed occupancy remains center-based; room-stored-position fallback lacks a direct scenario; broader travel, multi-target and planar arrivals remain. Sized summoned arrivals reject automatic placement and paid no-space policies at load. A hypothetical failure after payment still retains the spent slot. |
| 4. Additional damage-choice routes, S-127 (#60) | Activation/hit choices reach Opportunity, Light/off-hand, Nick, Cleave and legacy created-creature turn attacks. Only Nick carries an Attack-action pick. Routes retain their own budgets; stale creature actions/turns/orders refuse before damage, and successful creature attacks spend their Action before hit settlement. See [attack profiles](../mechanics/attack-profiles.md). | S-156 commanded actors, other summon/monster attacks, item-granted profiles and reach/mastery choices. Dismissing the legacy creature menu ends that automatic turn with no attack; its Action remains unspent, with no retry or automatic Dodge added. |

The next fixture/gameplay investigation remains concentration cleanup for
multi-target Heroism/Enhance Ability, Bard's decline-standing prompt, aura exit,
Identify targeting, local-room movement modes/uphill costs, typed next-melee-hit
grant consumption, repeated P1 damage-request settlement and Wizard free-cast
context. These are separate from the repaired assignments; causes and current
pass/fail status require focused supported-runner reproduction. For new engine
work, continue S-141 or another explicit remaining host above rather than
rebuilding the four delivered subsets. Waterborne travel, vessel encounter
transfer, broader travel and source-backed content conversions remain separate.

Every runtime continuation retains the original closing requirement: real
input-path proof; focused independent review for shared combat/persistence;
fresh-process recovery when durable state changes; and an updated mechanics
contract plus slice boundary. Keep native paths until replacements cover their
actual content. The focused reviewer found no further blockers after the timing,
creature-budget/staleness and mounted-footprint repairs.

<a id="item-projection-controls"></a>

### Exact item projection/bond player controls — S-161/S-165/S-122 continuation

Combat Features and local-room controls now expose applicable item Bond/Release
and Project/Dismiss offers through existing `BondRules`, `ItemProjectionRules`,
exact-copy inventory and placement APIs. Full stable identities distinguish
identically named copies and forms. Source-declared bond requirements, item
attunement, held/unequipped eligibility, exact charges, action budgets and live
destinations are checked again before commitment. Cancel, closed/superseded
choices, stale ownership/forms, occupied destinations and unaffordable costs
refuse without payment. Authored automatic/chosen placement and explicit paid
no-space outcomes reuse S-122's failure policy. Dismissal uses S-166 legal return,
including the original copy and nested contents on room ground when the bag is full.

`item_lifecycle_controls_flow` drives the actual room buttons and combat Features
popups, including Godot's hide-before-selection ordering, two identical copies,
a world-origin source ID, cancellation, lost attunement/ownership, occupied
space, action/charge exhaustion, renamed definitions, automatic placement,
no-space costs and independent dismissal. An allowed checkpoint and fresh
process recover a living projected copy and a returned ground copy with spent
charges, nested contents and bonds intact. The existing item-return and room
creation checks retain their separate boundaries. No slice count is added.

This continuation covers single-cell item actors in combat and persistent rooms.
Actor-target bonds, charged projections with last-charge aftermath, broader vessel hosts,
cargo, containment and catalog conversion remain outside it. Room activation
spends charges without initiative budgets or campaign-clock advancement.

### Building blocks and where they fit

| Building block | Existing slices and prerequisites | Smallest useful delivery and what it unlocks |
|---|---|---|
| Legal placement before final settlement | S-121 after S-033/S-043; S-122 adds S-135; S-155 adds S-154 | Combat save-exit settlement is verified in VS-144. Combat and local-room creation controls reuse `PlacementRules` and `PhysicalFactsRules`; full size-based footprints and mixed-size per-kind factories are verified. Teleport arrival and forced-movement steps reuse the same rules (Batch 066); Find Steed arrival is delivered (Batch 086); continue with multi-target/planar arrival and exploration-mode steed occupancy (PARTIAL); item-projection controls are delivered in the [control continuation](#item-projection-controls). S-166 now supplies authored exact-copy returns and their no-space policy. Do not rebuild the delivered combat picker. |
| Created-actor commands, turns and control expiry | S-156 after S-154/S-026; S-157 then S-158 | Exact commands, costs, owner-turn/after-owner/independent/shared-count timings and declared owner/control defaults, including owner removal and unavailable-owner encounter entry, are delivered in the [PR25–37 boundary](#pr25-37-validation). Continue additional orders/autonomous movement and source-backed consumers. Reuse the existing identities/budgets. Animate Objects remains a separate complete conversion. |
| Located source-end continuation and world outcomes | S-086/S-087/S-120; reuse S-034/S-072/S-148/S-149; placement as needed | [VS-145](#located-source-end-continuation) delivers captured end events for shared spells and self activation modes, declared delayed heal/loose-object/entry-damage-area children, room controls, actual room/combat entry damage and checkpoint recovery without replay. Continue exact item/actor end producers, other object/hazard kinds and selected crossing/turn scopes separately; actor successors also consume command/initiative support. Do not replace the existing room/area/child owners with a general world framework. |
| Ground equipment keeps its exact copies | S-164 continuation after placement; reuse S-049 and existing room-copy transactions | Implemented for persistent rooms and their encounters: selected exact copies use shared room placement payloads, batched inventory removal and encounter-to-room capture at the actor's position. Preflight covers the whole transfer and pending ground capacity; contents, attachments, charges, curses and source links remain on the copy. Full-backpack, multi-copy, linked-loss, destruction/pickup, unchanged merged/worn and checkpoint recovery checks are `FormEquipmentGroundChecks` and `form_equipment_ground_flow` (with fresh-process recovery). Reversion neither recreates nor reclaims any dropped copy. Encounters without a captured persistent room refuse nonempty drops before costs; no new checkpoint or native Wild Shape conversion is claimed. |
| One source, several tether recipients; independent object anchors | S-144 plus S-168/S-169; object anchors consume the located-world-record work | [Tether groups](#character-tether-groups) retain distinct relations under one cast and payment. Character anchors keep their existing concentration lifetime; object anchors use stable room object ID/location/plane/HP and their declared spell duration. Exact escape/rescue/cut, per-anchor movement/destruction, stale rescue and supported checkpoint recovery are verified. |
| Item-form return, containment and vessels | S-166 verified in VS-146; S-170 verified in VS-148; S-171 verified in VS-149; S-172 verified in VS-150; S-167 verified in VS-151 | [Exact item-form return](#exact-item-form-return) declares HP reset, overflow, original destruction and legal bag/ground return, including full-inventory and blocked-return recovery. Actual capacity, admission/inspection and internal/external location are verified in [VS-148](#containment-occupancy). Internal harm/targeting and escape/rescue now use explicit eligibility and deferred release in [VS-149](#containment-internal-interactions). Moving containers and legal release are verified in [VS-150](#containment-movement-release). [VS-151](#projected-vessel-contents) carries exact cargo and real passengers through persistent-room movement, separate reversion/dismissal/destruction policies and legal retained/released endings. Inventory compartments never hold creatures. Waterborne/general travel, encounter transfer and source-backed catalog conversion remain separate. |
| Invocation-local profile and casting changes | S-126/S-127; S-140 after S-134/S-126; S-141 adds S-154 | Bounded player HUD range/components/school/timing changes and the additional attack-choice routes are delivered in the [PR57–60 boundary](#pr57-60-validation). Continue duration/concentration/created-actor parameters, other hosts, costed profiles and weapon reach/mastery. Apply changes at the proper selection/roll/lifetime stage to one invocation, not the catalog. Duration/concentration must reach source creation and cleanup; creature changes use S-154's template. Prove qualifying and unrelated casts side by side, compatible sources, later choices and no catalog mutation. Placement is a dependency only when the consumer creates or moves something. |

### Character and object tether groups — VS-147

<a id="vs-147"></a><a id="character-tether-groups"></a>

S-144's bounded Character-anchor continuation extends S-168/S-169. Shared
`bind_tether` definitions use the existing combat target controls, retain one
invocation/cast payment, settle independent initial saves and keep distinct
victim/relation identities beneath the original concentration source. Escape,
rescue checks and damage name the exact relation; releasing one recipient keeps
siblings' condition, HP and original remaining lifetime. Combat and room controls
offer exact choices where needed, and stale/foreign/parent-only selections
refuse before their action/time/damage. Source/concentration end cleans the
remaining group once. Encounter cleanup removes monster relations while keeping
persistent Character siblings saveable.

`TetherGroupChecks` covers paired and renamed shared fixtures, mixed initial
saves in either order, exact escape/rescue/damage/range release, external
recipient-source loss, repeated parent cleanup, malformed identities/HP/DC,
legacy source-keyed records and mixed Character/monster encounter cleanup.
`tether_group_flow` drives the actual two-pick cast and action/slot payment,
ambiguous combat escape/rescue and room stale/cut selectors, full-group save/load
and partial-group checkpoint. Its separate process restores original source,
remaining relation/HP/time and once-spent slot, retains the released victim's
absence, rejects stale/parent selection and cleans the recovered group once.
Object-anchor checks bind several victims across two existing room records, prove
no caster concentration dependency, move one anchor while preserving its sibling,
destroy another through the room strike control, reject a stale rescue choice,
and recover both object and Character relations in a fresh process.

The full logic suite and existing Batch 045/046 control scenarios remain green.

Verified boundary: Character and independent object anchors, existing
`restrained` condition, declared capacity 1–4 (two-recipient proof), exact
escape/rescue/melee cut routes, object location/plane/HP/movement/destruction
and existing checkpoints. Multi-recipient casting uses the combat host; room
casting retains its existing single-target entry point. Generic extensions of
other cast families, alternate origins and catalog conversion remain separate.
The [authoring contract](../mechanics/tethers.md) owns syntax and runtime APIs.

<a id="exact-item-form-return"></a>

### Exact item-form return — VS-146

S-166 is verified for one exact item copy projected into a single-cell actor.
Neutral and renamed JSON definitions declare full/preserved form HP, discarded
or original-copy overflow, independent voluntary/zero-HP return or destruction,
bag/ground priority and deferred no-space behavior. Production damage captures
overflow after temporary HP and zero-HP replacement; legal placement reuses
S-121 reservation/confirmation before transferring the original copy. A blocked
voluntary end keeps the live form. A blocked lethal return retains its exact
copy, settled original HP and captured room/plane/location, without damage replay.
Repeated and stale-activation ending callbacks preserve independent identical
forms and unrelated linked mates. Existing projection saves, dawn recovery and
native damage/inventory consumers retain their paths.

The supported Windows Godot checks exercise voluntary ending, lethal native
monster damage, overflow, declared original destruction, full backpack, blocked
ground, repeated callbacks and independent injured identical copies. Actual
safe saves and a fresh process recover both pending returns and save-time returns
into a dormant room, preserving exact ownership without replay. Pending DTO
validation reuses inventory, nested-copy and global ownership checks.

The [authoring contract](../mechanics/created-actors-and-placement.md#exact-item-form-return)
owns supported fields. Ground return requires a represented persistent room and
a distinct nearby cell, excluding the ending cell; unavailable ground defers.
Creature containment, passengers, vessel movement and catalog conversions remain
separate work; the [control continuation](#item-projection-controls) now exposes
supported item forms. This verifies S-166,
with the vessel extension verified separately in [VS-151](#projected-vessel-contents). S-170 occupancy is verified
separately in [VS-148](#containment-occupancy), with internal behavior in
[VS-149](#containment-internal-interactions); moving containers/legal release are verified in [VS-150](#containment-movement-release).

<a id="located-source-end-continuation"></a>

### Located source-end continuation — VS-145

S-086 now captures exact source/producer/recipient, reason/cause and final
plane/room/hex/elevation/altitude before grants are removed, projections revert
or created actors are removed. Shared spells, self activation modes, exact item
copies and created actors use the same final-event publication. S-087 runs declared ordered
healing, loose room objects and entry-damage areas from those captured events,
including campaign delays, skip/stop child cancellation and resumed siblings.
S-120 adds this bounded actual object/hazard branch; it does not certify all
actor/source death and destruction producers.

`LocatedSourceEndChecks` covers reason selection, delayed observation after
movement/plane changes, source cleanup, object damage, wrong-plane entry caps,
retry after room capacity failure, malformed checkpoints, upgraded mode end
predicates, reacquisition identities and active/dormant snapshot replay.
`located_source_end_flow` also checks loaded neutral and renamed item/actor
producers, two identical projected copies, separate created actors, repeated
death callbacks, expiry/dismissal/death reason selection, source cleanup and
delayed children after movement. Exact identities and producers validate in the
room save DTO; the fresh-process probe restores completed receipts and a waiting
timer, then settles its child once at the captured origin. Existing controls
exercise saved hazards through `CombatSpellZones` and capture a Character's live
combat position independently of a stale room checkpoint position.

The fixtures prove those producers without catalog conversion. Rest/group modes,
unrepresented ending locations and combat choice controls remain open. Item
forms do not yet declare automatic expiry timers; callers can publish the exact
`expired` end reason. Hazards are flat typed damage
on outside-to-inside entry with a per-creature lifetime cap; crossing, appearance,
teleport arrival and turn scopes are not covered. Object kinds beyond `loose`
and hazard kinds beyond `entry_damage` refuse. No catalog conversion is claimed.
Waiting timers/completed children are durable; unresolved decisions do not gain
checkpoint permission. [Authoring contract](../mechanics/source-end-rules.md#located-end-continuations).

### Recent continuation acceptance — 2026-10-23

Accepted within the boundaries above: combat save-exit placement (S-121), room
creation (S-122/S-155), created-actor scheduling/shared counts (S-157/S-158), exact
item controls (S-161/S-165), equipment ground drops (S-164), item-form return
(S-166), located aftermath (S-086/S-087/S-120), Character/object tether groups
(S-144/S-168/S-169), and Conversion Batches 001/002. No additional slice count.

Review repaired timed independent/rolled-group sources stopping their expiry
clock after owner removal or unavailable-owner entry. Their retained caster
clock does not change creature initiative. Room map clicks now wait for factory
confirmation, and switching actors cancels pending creation without payment.
The tether recovery scenario now suppresses only the load's scene transition,
keeping the real checkpoint guards enabled; it exits cleanly instead of tearing
down its own remaining controls. Conversion recovery modes now run automatically
through the supported runner. One focused independent reviewer checked the
combat/persistence paths and the final repairs.

Verification: supported Windows Godot parse/boot, full logic (5,910 passed),
13 affected/adjacent integration scenarios and nine fresh-process recovery checks,
plus documentation links/count consistency. No blocking defect remains in this
delivered subset. This continuation now captures persistent combat-created
summons into the room and restores their positions through exploration,
subsequent encounters and a fresh-process checkpoint. Remaining limits include
general-travel save exits, broader general-travel arrival, other
aftermath producers and full catalog/SRD clause audits.
No manual visual playtest,
mid-combat checkpoint or whole-campaign readiness is implied.

### Acceptance review — 2026-10-24

The current working-tree continuations of S-121/S-122, S-033/S-122/S-155,
S-086/S-087/S-120 and S-168/S-169 are accepted within their documented hosts.
This review adds no slice count. It repairs ordinary room healing/buff casts
being sent to the exit-only entry point, abandoned room exit choices, Large
save exits checking only their center cell, and malformed explicit travel
destinations falling back to random arrival.

Object tethers now select and enforce range against live combat positions.
SaveManager validates their relations against the complete world DTO before
replacing the session, rejecting missing/foreign/copied anchors and malformed
numeric fields. Deferred lethal item returns retain their captured end origin
and time through reload and room changes; stale created-actor callbacks cannot
publish a second end after their parent source is gone. A focused independent
review covered these shared combat and persistence repairs.

Verification: supported Windows Godot parse/boot and full logic **5,941 passed,
zero failed**; **10 affected/adjacent integration scenarios and five fresh-process
recovery checks passed** through the supported runner. Documentation links and
diff whitespace pass.

Nonblocking limits: S-121 remains flat single-target numeric saves in combat
and local rooms; general-travel exits and broader arrival hosts remain open.
Creation and required exits enforce size-based footprints, while ordinary
movement retains single-cell occupancy. Located children retain their existing
bounded object/hazard kinds and require unique represented room IDs across
dungeons; general world addressing remains outside this continuation. Tether
group casting uses combat controls; room casting remains single-target. These
checks certify no additional catalog conversion or whole-campaign readiness.

<a id="vs-148"></a>
<a id="containment-occupancy"></a>

### Actual containment occupancy and capacity

S-170 is verified through `containment_flow` and its separate-process recovery
probe. Neutral/renamed JSON policies declare actual Character and object
containers, allowed body kinds/sizes/types and count capacity. Room controls
admit and inspect exact occupants, including multiple occupants, equal-name
independent containers and loose objects holding exact gear copies. Carried
gear retains its creature owner. Inventory compartments do not grant creature
containment.

Admission rechecks actual body instances, actor, capacity and legal represented
locations before appending one relationship. Cancelled, repeated, switched,
replaced or stale choices refuse. Runtime and save preflight reject duplicate
occupancy and cycles. Internal bodies expose their parent rather than a room
position; shared physical/source-anchor queries and space occupancy do not use
their remembered entry cells as external locations.

Both full-party and player-only DTO paths preserve the exact graph, capacities
and gear through the existing entrance checkpoint and a fresh process. Recovery
reopens the actual room controls and inspects occupants, then re-saves/reloads
without replaying admission or copying gear, including an occupant downed after
entry. Malformed identities, capacities,
conflicting body representations and a party represented in another room refuse
before session replacement. Focused independent review repaired stale-choice,
entry-cell, object-damage, travel and DTO-validation bypasses.

This is a persistent-room Character/object host with count capacity. No catalog
conversion, encounter admission, standalone space container, weight/volume/air
model, release placement or occupied-container movement is claimed by S-170.
[VS-149](#containment-internal-interactions) adds internal harm/targeting and
escape/rescue. While occupancy exists, the room exposes admission, inspection,
those bounded interactions and uninvolved-character movement. [VS-150](#containment-movement-release) adds container movement, represented room travel and legal release. Encounter transfer and air remain separate; [VS-151](#projected-vessel-contents) extends this graph to room vessels. See the [authoring contract](../mechanics/containment.md).

<a id="vs-149"></a>
<a id="containment-internal-interactions"></a>
### Internal containment harm, eligibility and escape/rescue

S-171 extends delivered Character/object occupancy with authored periodic typed
damage, explicit individual target routes, and STR/DEX escape/rescue checks.
Both effect and container must allow an internal/external crossing; internal
location does not grant ordinary external attack/spell eligibility. External
area-step recipients exclude internal bodies. Neutral/renamed JSON definitions
use the same shared spell, damage, check and source machinery.

`containment_harm_flow` proves internal and external effects together, exact
selection between two equal-name occupants, distinct occupant/container/rescuer
identities, stale/cancelled/repeated confirmation refusal before time/slot costs,
repeated damage settlement, object and creature container loss, and preservation
of exact bodies/gear. Focused independent review repaired secondary-recipient,
self-area, cloned-object, source-validation and damage-history gaps.

Escape, rescue and destruction share the release request path. Successful checks
report settlement deferred and retain the exact occupant relationship and
receipt. Pending rows do not reroll, pay again or continue internal harm.
Destroyed containers remain represented until legal release exists; repeated
cleanup preserves prior escape/rescue reasons. The fresh-process probe restores
both active timers and pending releases through full-party and player-only
entrance checkpoints, reopens controls, resaves/reloads and continues active harm
once without replaying completed work. Malformed source/timer/release DTOs refuse
before session replacement.

This is a persistent-room host for individual flat effects and count-capacity
bodies. Nested boundary crossings, internal ordered/area/placement effects,
encounter transfer, air and catalog conversion remain open. Room vessels extend this graph in [VS-151](#projected-vessel-contents).
[VS-150](#containment-movement-release) extends this receipt path with legal release and moving containers; legacy policies without authored placement remain deferred.
See the [authoring contract](../mechanics/containment.md).

<a id="vs-150"></a>
<a id="containment-movement-release"></a>
### Moving containers and legal occupant release

S-172 extends the existing containment graph, room movement, object movement and
shared placement owners. Creature movement retains its ordinary Speed/path/time
costs; movable object containers carry their occupants. Character-rooted groups
travel between represented tactical rooms with exact nested objects, source IDs,
gear and pending receipts intact. Arrival reservation precedes travel time;
unrepresented destinations, stationary object containers holding party bodies,
ID collisions and insufficient space refuse without transfer.

Authored release policies define primary/fallback ranges and blocked behavior.
Escape/rescue confirmations reserve and recheck exact destinations before rolling
or spending time. Destruction and absolute campaign expiry reserve the entire
immediate occupant group before removing any relationship. One blocked footprint
keeps the group pending; it cannot partially free, overlap, delete or duplicate
bodies. Pending continuation rechecks exact identities, origins, rules and all
footprints. Nested contents remain attached to their immediate parent.

`containment_release_flow` proves several occupants, exact gear, nested graphs,
ordinary movement budgets, represented round-trip room travel, fallback/refusal,
stale and cancelled choices, one blocked destination, repeated expiry/destruction,
and active/pending entrance checkpoints. Its fresh-process probe restores both
full-party and player-only DTOs and actually finishes release without replaying
costs or losing nested contents. Independent review repaired expiry-clock,
footprint, stale movement and destination-coordinate gaps.

This is the persistent-room Character/object boundary. Encounter transfer,
general planar travel, standalone space containers, shared air
and catalog conversion remain separate. [VS-151](#projected-vessel-contents) adds room vessel movement/endings; vessel room-map travel and encounter transfer remain refused. Legacy policies lacking release placement
retain deferred receipts. No new checkpoint or combat save is introduced.
See the [authoring contract](../mechanics/containment.md).

<a id="projected-vessel-contents"></a>

### Projected vessel contents and movement — VS-151

S-167 extends the accepted exact item-form lifecycle and containment/release
owners. The original projected copy retains actual compartment cargo; actual
passengers retain their own bodies and gear through containment links to that
vessel. Persistent-room movement uses the shared path/Speed/time owner and
checks the vessel's full footprint. Two identical copies remain independent.

JSON separately declares cargo/passenger retain/release for reversion,
dismissal and destruction. The complete required release and original return
are reserved before mutation. Cargo release moves exact child copies to legal
room objects; retained cargo returns in the original. Passenger retention is
supported on a surviving ground original by retargeting the existing graph.
Destruction requires passenger release and cannot discard retained cargo.
Blocked voluntary endings preserve the live form; blocked destruction retains
settled HP/overflow, the original, exact cargo and passenger links for retry.

`projected_vessel_flow` proves actual projection/admission/cargo/movement/end
controls, identical loaded vessels, voluntary reversion, dismissal, destruction,
blocked passenger/cargo release, full-backpack ground return, retained ground
passengers, stale movement, remote-transfer refusal and repeated callbacks.
Regression checks cover actual physical-size overrides, ground-ID aliases,
empty pickup-record reuse, a full room with available backpack space, malformed
save links/policies and preflight preserving the live body/HP. Existing entrance
checkpoints and a fresh process restore active, pending and settled states in
both full-party and player-only saves without replay; recovered active and
pending endings are actually completed. Focused independent review repaired the
identity, placement and validation gaps before acceptance.

This is a persistent-room ground movement/endings boundary. Occupied vessel
room-map travel and all vessel encounter entry refuse. Waterborne propulsion,
general travel, air and real catalog conversion remain separate. A complete
source-backed consumer is required before real vessel catalog conversion;
neutral/renamed fixtures prove the reusable runtime only. See the
[authoring contract](../mechanics/projected-vessels.md).

### Assignment boundaries and completion checks

- The chooser, item types/measurements, modes/source ownership and the bounded
  PR25–37 controls have been handed off. Continue the remaining placement hosts. Monster maximum HP,
  degradation and explicit death can also start without the world branches, but
  give overlapping Character/inventory/combat edits a single owner at a time.
  Coordinate further pickers with the existing chooser owner. Extra Attack/AC
  upgrade consumers are a separate assignment from source ownership, even where
  they share S-084/S-085; they must not be silently added to that existing job.
- Reuse delivered created-actor authority and combat factory controls; complete
  the remaining placement hosts (item-projection controls are now delivered). Located source-end/world outcomes
  then feed ground drops, object anchors and hazard successors; vessel work
  follows reversion and containment. These are dependency branches, not a demand
  to finish P2 through P8 in order.
- Source-declared behavior stays in JSON with no content-ID registration. Use
  neutral/renamed fixtures for engine proof; pin SRD 5.2.1 clauses separately for
  real content. No new universal GM system, creature interpreter, pack service or
  save migration is a prerequisite. Native Wild Shape and catalog-wide conversion
  remain separate consumers after their replacements cover the actual rules.
- An assignment finishes with the real supported input/choice path, once-only
  costs/effects, cancel/stale/refusal/cleanup checks and an independent focused
  review for shared combat or persistence changes. Add both save DTO checks and
  fresh-process recovery when durable state changes; retain existing checkpoint
  limits. Run the supported Windows runner serially, using the affected logic
  groups/scenarios in [testing](../testing.md). Structural Python checks cannot
  certify gameplay. Update the owning mechanics contract and this registry's
  accepted boundary; do not increase the slice count for these continuations.

<a id="accepted-bounded-batches"></a>

## Accepted bounded implementations — Batches 034–046

Batches 034–046 add 26 accepted bounded implementations and production fixtures.
The owner's review, repair and merge instruction was acceptance of that work;
the former `Built; acceptance open` labels incorrectly required another sign-off.
The linked reviews retain their original findings and evidence; later ownership
and interruption repairs are reflected in the boundaries below. Original row
requirements remain intact: object/hazard successors in S-120,
the vessel branch of S-165 and other listed gaps remain follow-up
work. Acceptance neither silently narrows those requirements nor certifies catalog
content. Fixture numbers do not establish SRD rule correctness.

| Slices | Accepted evidence | Implemented boundary and remaining limit |
|---|---|---|
| <a id="vs-113"></a><a id="vs-114"></a>S-093 / S-119 | [VS-113/114: Batch 034 review](../reviews/batch-034-acceptance.md) | No-roll Death Saves and source-declared zero-HP damage aftermath. Threshold death without damage, already-zero targets and native Disintegrate conversion remain outside this host. |
| <a id="vs-115"></a><a id="vs-116"></a>S-130 / S-126 | [VS-115/116: Batch 035 review](../reviews/batch-035-acceptance.md) | Character-owned maximum-HP deltas, periodic/rest boundaries and monster riders; scoped weapon profiles and spell save DCs. Dictionary creatures, spell attack/range changes and a damage-type picker remain outside this host. |
| <a id="vs-117"></a><a id="vs-118"></a>S-086 / S-060 | [VS-117/118: Batch 036 review](../reviews/batch-036-acceptance.md) | Shared-spell source-end damage/condition follow-ups and exact-copy last-charge payment through the item-charge cast path. Other source kinds, located areas and fully enforced degraded-property retention remain open. |
| <a id="vs-119"></a><a id="vs-120"></a>S-103 / S-084 | [VS-119/120: Batch 037 review](../reviews/batch-037-acceptance.md) | Rest/activation mode grants and data-only parameter upgrades, with class/subclass saved ownership. Species, feat and item feature acquisition/reconstruction remains open. |
| <a id="vs-121"></a><a id="vs-122"></a>S-104 / S-085 | [VS-121/122: Batch 038 review](../reviews/batch-038-acceptance.md) | Declared hit/turn-start switch windows, mode additions/removals and exclusive upgrades. This is the mode-choice host, not general Extra Attack, AC or mastery replacement. |
| <a id="vs-123"></a><a id="vs-124"></a>S-154 / S-131 | [VS-123/124: Batch 039 review](../reviews/batch-039-acceptance.md) | Source-linked bounded actor templates and declared death when a Character's source-owned maximum HP reaches zero. Generic dictionary-creature persistence and broader creation clauses remain open. |
| <a id="vs-126"></a><a id="vs-125"></a>S-120 / S-163 | [VS-126/125: Batch 040 review](../reviews/batch-040-acceptance.md) | A declared successor actor tied to final death, plus reversible self projections retaining selected statistics and resources. Successor hazards/objects and native Wild Shape conversion remain open. |
| <a id="vs-127"></a><a id="vs-128"></a>S-161 / S-164 | [VS-127/128: Batch 041 review](../reviews/batch-041-acceptance.md) | Exact-copy/owned-actor bonds and merged/worn policies; the S-164 ground continuation above replaces backpack set-aside with actual persistent-room/combat drops. |
| <a id="vs-129"></a><a id="vs-130"></a>S-162 / S-165 | [VS-129/130: Batch 042 review](../reviews/batch-042-acceptance.md) | Declared linked-copy loss/replacement and one exact item copy projected into a combat actor. Identity, state and allowed checkpoints persist; fuller zero-HP overflow/reset policies belong to S-166. |
| <a id="vs-131"></a><a id="vs-132"></a>S-196 / S-202 | [VS-131/132: Batch 043 review](../reviews/batch-043-acceptance.md) | Exact non-nested compartment contents and declared curse removal/lingering policies. These do not establish arbitrary container nesting or every curse's source rules. |
| <a id="vs-133"></a><a id="vs-134"></a>S-210 / S-203 | [VS-133/134: Batch 044 review](../reviews/batch-044-acceptance.md) | Declared attached parts/required sets and listed magical-property suppression/destruction. Broader equipment properties need their own supported consumers. |
| <a id="vs-135"></a><a id="vs-136"></a>S-064 / S-168 | [VS-135/136: Batch 045 review](../reviews/batch-045-acceptance.md) | Carried-item active-time budgets and source-owned restraint tethers to a Character caster. Active storage refuses; [VS-147](#character-tether-groups) extends this to group recipients and independent object anchors. |
| <a id="vs-137"></a><a id="vs-138"></a>S-066 / S-169 | [VS-137/138: Batch 046 review](../reviews/batch-046-acceptance.md) | One qualified item job per participant, daily progress and immediate loss/rest interruption; declared tether rescue checks/damage. Helpers are party members without a spatial co-location check; [VS-147](#character-tether-groups) covers exact object and Character relations. |

The [mode/form/item state contract](../mechanics/source-benefit-carriers.md#modes-forms-and-exact-item-state)
records the repaired ownership and interruption rules. New fixtures should use
the existing modules instead of rebuilding these bounded hosts.

## Verified baseline

| Slice | Phase | Capability coverage | Accepted evidence | Finish line retained |
|---|---|---|---|---|
| S-001 — Boolean fact eligibility | P1 | V-001 | [VS-01](#vs-01) | Existing ordered fact comparisons; retain VS-01's exact allowlist. |
| S-002 — Current source-owner relationship | P1 | V-002 | [VS-02](#vs-02) | Retain the source-owner relation demonstrated by VS-02. |
| S-003 — One earlier typed damage component | P1 | V-006 | [VS-03](#vs-03) | Retain exact step/target/type and raw/resolved/HP-loss selectors. |
| S-004 — Arithmetic and captured caster/cast inputs | P1 | V-001, V-007 | [VS-04](#vs-04) | Retain current arithmetic, rounding, live caster and selected-slot leaves. |
| S-005 — Earlier-result gate across continuation | P1 | V-011 | [VS-05](#vs-05) | Retain demonstrated positive component gate through suspended work. |
| S-006 — Exact-source numeric pools | P2 | V-027, V-038 | [VS-06](#vs-06) | Retain exact source quantity, formula capacity, spend, growth/clamp/removal. |
| S-007 — Completed-rest numeric-pool recovery | P2 | V-044, V-048 | [VS-07](#vs-07) | Retain fixed Short Rest/fill Long Rest completion and actor eligibility. |
| S-008 — Combat-turn and owner-turn rider limits | P2 | V-004, V-041 | [VS-08](#vs-08) | Retain once-per-turn/target/owner-interval locks, including actual off-turn use. |
| S-009 — Numeric-pool checkpoint recovery | P2 | V-057 | [VS-09](#vs-09) | Retain validated allowed-checkpoint recovery without acquisition replay. |
| S-010 — Bounded owned dice activation | P2 | V-038 | [VS-10](#vs-10) | Retain accepted one/two-die activation and exact source costs. |
| S-011 — Fixed numeric-pool exchange | P2 | V-039 | [VS-11](#vs-11) | Retain exact-source 2-for-1 exchange and full-fit refusal. |
| S-012 — Source-owned timed numeric self-grant | P2 | V-027, V-049, V-057 | [VS-12](#vs-12) | Retain fixed AC self-grant, campaign expiry/removal and checkpoint identity. |
| S-013 — Next matching melee-hit grant | P2 | V-010, V-027, V-051, V-057 | [VS-13](#vs-13) | Retain oldest qualifying fixed typed grant and final-hit consumption. |
| S-014 — Cooldown after expiry/dismissal | P2 | V-045, V-056, V-057 | [VS-14](#vs-14) | Retain captured cooldown deadline and exact-source cleanup. |
| S-015 — Source-owned expiring Temporary HP | P2 | V-027, V-052, V-057 | [VS-15](#vs-15) | Retain keep-higher provenance, surviving amount and expiry/replacement. |
| S-016 — Deterministic numeric breakpoint lookup | P1 | V-007 | [VS-16](#vs-16) | Retain current formula inputs and deterministic numeric table values. |
| S-017 — Earlier-step typed damage sum | P1 | V-006, V-011 | [VS-17](#vs-17) | Retain one explicit measure/type across settled target outcomes. |
| S-018 — Owned fixed failed-save bonus | P3 | V-010, V-014 | [VS-18](#vs-18) | Retain one optional owner bonus before rolled shared-spell save consequences. |
| S-019 — Converted-success payment | P3 | V-035 | [VS-19](#vs-19) | Retain both existing save-bonus policies and upfront availability. |
| S-020 — Explicit failed-save success override | P3 | V-013 | [VS-20](#vs-20) | Retain numeric fields/DC and explicit success for one rolled owned save. |
| S-021 — Weapon Attack/Extra Attack post-roll bonus | P3 | V-010, V-014, V-035 | [VS-21](#vs-21) | Retain captured swings, final Shield result, once-only action/source costs. |
| S-022 — Flat/ordered shared-spell attack bonus | P3 | V-010, V-014, V-035 | [VS-22](#vs-22) | Current pair 2: actual spell controls, captured roll, final riders, original slot and following damage/ordered continuation once. |
| S-023 — Captured single source die bonus | P3 | V-014, V-035, V-038 | [VS-23](#vs-23) | One accepted d6/d8 bonus in the checked save/weapon/shared-attack domains; both payment policies, no die on query/refusal/replay, exact source and retained later-choice receipt. |
| S-024 — Boolean combinations and missing facts | P1 | V-001 | [VS-27](#vs-27) | Retain nested typed predicates and missing-safe three-valued eligibility on ordered shared-spell steps. |
| S-025 — Actor/action/item/source fact bindings | P1 | V-001 | [VS-28](#vs-28) | Retain exact actor, target, action, material copy, spell and source bindings through the combat shared-spell host and choice continuation. |
| S-028 — Purpose-aware checks and tools | P1 | V-003 | [VS-24](#vs-24) | Loaded EventDialog event/choice checks carry task, purpose and optional tool; an exact owned copy grants only its matching benefit, with ordinary no-tool/no-bonus checks and context/source receipt retained on closure. |
| S-094 — Owned post-roll ability-check modifier | P3 | V-014, V-035 | [VS-25](#vs-25) | Loaded EventDialog skilled/ability-only and choice-owned failed checks retain fixed/die adjustments, both payment policies, native bonuses, final closure receipts, completed replay refusal and host replacement/cancellation. |
| S-105 — Mandatory-new natural/test reroll | P3 | V-089 | [VS-26](#vs-26) | Loaded EventDialog event/choice checks keep the new natural or whole test even when worse; retain declared mode/bonus policy, original and new receipts, floor stages, exact source cost and one consequence, with stale-source/replay/lifecycle guards. |

## P1 — Facts, results and grants

| Slice | State | Capability coverage | Build and acceptance finish line | After |
|---|---|---|---|---|
| S-024 — Boolean combinations and missing facts | Verified (VS-27) | V-001 | Author nested AND/OR/NOT and typed comparisons; absent facts have an explicit result, with no silent truth or coerced values. | S-001 |
| S-025 — Actor/action/item/source fact bindings | Verified (VS-28) | V-001 | Bind the actual actor, target, action, item copy, spell and source; the same field name cannot read a different entity by accident. | S-024 |
| S-026 — Ally/enemy/willingness and giver relations | Verified (VS-36) | V-002 | Read represented ally/enemy relation and explicit willingness; charm/mark queries identify their exact giver rather than a condition name. | S-002, S-025 |
| S-027 — Distance to another actor or source | Verified (VS-37) | V-002 | Evaluate distance against an actual related actor/source; removal and moved participants change only live queries. | S-026 |
| S-029 — Required senses and causal save purpose | Verified (VS-38) | V-003 | Carry actual sensory requirements and avoid/end/maintain reasons; Constitution saves for different causes remain distinct. | S-028 |
| S-030 — Round and actor action history | Verified (VS-39) | V-004 | Read first round, first own turn and whether an actual target acted/was attacked since an explicit boundary; reset on the named event. | S-008 |
| S-031 — Damage-since-boundary history | Verified (VS-40) | V-004, V-006, V-057 | Track actual settled damage by actor/source and declared time/turn boundary; attempted, prevented and HP-loss amounts stay distinct. | S-030, S-003 |
| S-032 — Physical size/mass/material/equipment facts | Verified (VS-100; bounded represented combat host) | V-005 | Represent/query size, mass, material/thickness and worn/carried/fixed status on actual actors and copies; unknown values refuse eligible-only actions. | S-025 |
| S-033 — Plane and available-space facts | Verified (VS-101; represented combat, room and travel placement hosts) | V-005 | Represent actual plane/location and free space for a body or object; facts query placement without themselves moving or creating anything. | S-032 |
| S-034 — Prior-result identity and additional measures | Verified (VS-33) | V-006 | Bind selected step/target/component plus prevented, absorbed or healed quantity; result IDs survive a later choice without reading live HP as the receipt. | S-003, S-017 |
| S-035 — Declared multi-result reducers | Verified (VS-41) | V-006 | Sum/min/max only explicitly selected results/components, preserve rounding and handle empty selections explicitly; reuse existing sum for its accepted case. | S-034 |
| S-036 — Source die/choice inputs and capture policy | Verified (VS-43) | V-007 | Expose an exact source die and chosen numeric value to formulas; declared capture versus reevaluation survives source/actor changes. | S-016, S-023 |
| S-037 — Class-level inputs and declared progression tables | Verified (VS-44) | V-007 | Distinguish character level from each class level; bounded numeric/die-size tables select a declared row without inventing missing data. | S-036 |
| S-038 — Natural-d20 and final-total floors | Verified (VS-45) | V-008 | Apply a declared floor to natural or final total separately; retain provenance and ordinary critical/miss rules for the actual roll domain. | S-023 |
| S-039 — AC alternatives and score setting | Verified (VS-46) | V-009 | Choose among legal base AC formulas; score setting/floors/caps remain distinct from permanent increases and conditional additive modifiers. | S-024, S-004 |
| S-040 — Recipient choice and overlapping modifiers | Verified (VS-47) | V-009 | Apply declared stacking/exclusivity and let the recipient choose among incompatible equivalent protections; removal restores the still-owned alternative. | S-039 |
| S-041 — Authored roll/damage window context | Verified (VS-31) | V-010 | Expose declared before-roll, after-natural, provisional outcome and pre-/post-damage windows with exact kind/source/target receipt; answer one window once. | S-023, S-025 |
| S-042 — Cast-completion and source-end context | Verified (VS-70) | V-010 | Expose school, actual paid slot, completed cast and exact source-end reason to eligible consumers; emitted facts are not an automatic grant of another action. | S-041 |
| S-043 — Margin and post-settlement HP gates | Verified (VS-34) | V-011 | Branch on success/failure margin and settled HP/receipts; don't treat provisional roll or current unrelated HP as the final result. | S-005, S-034 |
| S-044 — All/any/count child-result gates | Verified (VS-42) | V-011 | Evaluate grouped attack/save results for the declared targets and steps; suspended children cannot prematurely satisfy all/any/count. | S-043, S-035 |
| S-045 — Filtered progression choice acquisition | Verified (VS-57) | V-025 | Acquire declared option count with level/class/fact filters and duplication policy through a real choice route; invalid choices pay/grant nothing. | S-024 |
| S-046 — Replace choices with dependent grants | Verified (VS-58) | V-025, V-027 | Replace an existing selection while validating its dependents; remove only the replaced exact source or refuse without partial revocation. | S-045, S-026 |
| S-047 — Starting versus multiclass grants | Verified (VS-68) | V-026, V-027 | Apply the declared proficiency/expertise/equipment grants once at the correct acquisition boundary; multiclass entry uses its own grant set. | S-045 |
| S-048 — Level-based permanent deltas | Verified (VS-69) | V-026, V-007, V-057 | Apply ability/max-HP/proficiency progression once, with class/character levels distinguished; checkpoint recovery must not replay the grant. | S-047, S-037 |
| S-049 — Item/cast/progression source carriers | Verified (VS-59) | V-027, V-057 | Attach reusable benefits to an exact item copy, cast or progression acquisition; removal/unequip ends that source only and allowed reload retains identities. | S-006, S-046 |
| S-050 — Benefit acquisition/removal through real controls | Verified (VS-60) | V-027 | Route class/item/cast acquisition and deliberate removal to the same source rules; independent identical sources remain independently queryable. | S-049 |

## P2 — Pools, time and effect state

| Slice | State | Capability coverage | Build and acceptance finish line | After |
|---|---|---|---|---|
| S-051 — Dice-pool progression and captured faces | Verified (VS-61) | V-038, V-007, V-057 | Use declared per-source capacity/die tables; retained rolled dice have distinct identities even for equal faces, and upgrades follow explicit snapshot policy. | S-010, S-036, S-037 |
| S-052 — Slot-to-pool exchange selectors | Verified (VS-82; numeric destinations) | V-039, V-031 | Select eligible exact slot/pool and declared quantities; fit and affordability validate before either side changes, preserving Pact versus ordinary slots. | S-011, S-135 |
| S-053 — Dice/quantity and cross-actor exchanges | Verified (VS-83; captured-dice/inventory payments) | V-039 | Exchange declared dice or represented inventory quantities between eligible sources/recipients atomically; no currency is invented solely for this slice. | S-052, S-051, S-026 |
| S-054 — Budgeted slot/pool recovery | Verified (VS-91; budgeted Character recovery) | V-040 | Choose expended quantities within a formula budget and exclusions; original pool identity and no-overcapacity rules survive cancellation or refusal. | S-007, S-137 |
| S-055 — Outcome-selected resource recovery | Verified (VS-92; actual paid-result recovery) | V-040 | Recover lowest eligible or lower-than-paid quantities from the actual result/slot, not a guessed caster level or another pool. | S-054, S-043 |
| S-056 — Own-turn, round and first-round limits | Verified (VS-54) | V-041, V-004 | Author own-turn eligibility and round/first-round limits separately from existing once-per-turn locks; off-turn actions cannot borrow an own-turn allowance. | S-008, S-030 |
| S-057 — Per-roll and per-active-instance limits | Verified (VS-55) | V-041 | Lock an option to one actual result/effect instance; an unrelated roll, duplicate source or new activation has its own identity. | S-056, S-041 |
| S-058 — Conditional payment waiver | Verified (VS-56) | V-042 | Waive only the declared cost for a qualifying parent action/source; other budgets and option locks still apply, with refusal before side effects. | S-023, S-056 |
| S-059 — Payment replacement and free die use | Verified (VS-106; bounded captured-die rider replacement) | V-042, V-023 | Substitute a declared payment or allowed free die without consuming the original pool; don't waive a sibling feature's cost or duplicate its roll. | S-058, S-051, S-123 |
| S-060 — Last-charge aftermath on exact copies | Verified (VS-118; exact-copy item-charge payments) | V-043, V-079 | After a real spend, trigger declared depletion roll/destruction/degradation on that exact copy once; preserve the declared surviving mundane properties. | S-049, S-042 |
| S-061 — Current versus lifetime capacity/overflow | Planned | V-043 | Keep cumulative received energy and current spendable energy separate; validate capacity, overflow outcome and any gain/spend aftermath once. | S-060, S-006 |
| S-062 — Turn-start/Initiative floor recovery | Verified (VS-62) | V-044, V-041 | Recover one/fill/up-to-floor at the declared actual event, with mutually exclusive choices and exact-source quantities; no refill from location changes. | S-007, S-056 |
| S-063 — Dawn/dusk/cooldown random recovery | Verified (VS-93; dawn/dusk/cooldown occurrences) | V-044, V-045 | Apply declared fixed or rolled recovery at campaign-time events; late observation/time jumps don't repeatedly roll or extend a captured cooldown. | S-062, S-014 |
| S-064 — Pause/resume cumulative active time | Verified (VS-135; carried-item cumulative active time) | V-045, V-057 | Accumulate qualified on-time across interruptions without restarting fuel/flight allowance; persisted source deadlines and cooldown start remain separate. | S-014, S-049 |
| S-065 — Cumulative distance allowance | Planned | V-045 | Spend actual eligible travel distance across pause/resume and mode changes; no charge for failed movement or fresh allowance on reactivation. | S-064, S-179 |
| S-066 — Qualified work/study progress | Verified (VS-137; one qualified item job per participant) | V-046, V-057 | Accumulate actual eligible work with proximity/concentration/participants and daily rest; leaving/interruption follows authored keep/reset policy. | S-064, S-032 |
| S-067 — Work deadline and paid-material interruption | Planned | V-046 | Enforce time window and qualified hours independently; expiry/interruption loses only specified progress/material and completion fires once. | S-066 |
| S-068 — Scheduled repeat saves | Verified (VS-94; turn/elapsed repeat saves) | V-047 | Declare target-turn or elapsed-time repetition and eligibility; each due attempt resolves once with its source/recipient and original purpose. | S-029, S-041 |
| S-069 — Counted saves and staged conditions | Verified (VS-95; counted staged conditions) | V-047, V-057 | Count qualifying successes/margins and transition/end linked conditions by explicit routes; other cures or source removal cannot erase unrelated stages. | S-068, S-043 |
| S-070 — Rest-start expiry and actor-specific duration | Planned | V-048 | Separate starting a rest, eligible elapsed duration, interruption and successful completion; authored Trance/duration rules don't grant benefits at start. | S-007, S-064 |
| S-071 — Benefit-only recovery and Hit Dice | Planned | V-048 | Apply immediate declared rest-like benefits without falsely emitting rest completion; select actual Hit Dice/cost/amount only for eligible actors. | S-070, S-054 |
| S-072 — Action/status/equipment/range termination | Verified (VS-71) | V-049 | End an exact source on declared attack/cast/movement/status/gear/range event, preserving sources that don't match and the actor whose event matters. | S-012, S-042, S-026 |
| S-073 — Causal damage exceptions to termination | Verified (VS-72) | V-049 | Use settled causal source identity to exempt only specified damage; ordinary unrelated damage still ends the grant when required. | S-072, S-034 |
| S-074 — Suppression without removing condition | Verified (VS-73) | V-050, V-057 | Mask qualifying condition effects while retaining original source/clock; suppression ending restores only unexpired conditions and never reacquires them. | S-072 |
| S-075 — Recipient/source-specific suppression | Verified (VS-74) | V-050 | Overlapping suppressors and eligible recipients are independent; movement/removal of one suppressor cannot restore a condition another still masks. | S-074, S-026 |
| S-076 — Next selected attack/result grant | Planned | V-051, V-014 | Match actor/target/attack kind and consume at the declared roll/hit boundary; nonmatching events retain the grant, and ordered sources consume only as declared. | S-013, S-057, S-026 |
| S-077 — Next own-source save or post-movement event | Planned | V-051 | Match the exact originating spell/movement and beneficiary; consume a captured grant only when its declared qualifying event occurs before expiry. | S-076, S-049 |
| S-078 — Temporary-HP replacement choice | Verified (VS-84; recipient Keep/Replace) | V-052, V-009 | Offer recipient choice between actual current and incoming Temporary HP without resetting the retained supplier/expiry; reject stale choices before replacement. | S-015, S-040 |
| S-079 — Cross-actor Temporary HP and linked benefit | Verified (VS-85; cross-actor linked AC/saves) | V-052, V-054, V-057 | Supplier and recipient differ; retain benefit only while that source's qualifying Temporary HP survives, with replacement/removal/expiry ending it exactly once. | S-078, S-082 |
| S-080 — Dynamic aura bearer/recipient membership | Verified (VS-75; directly owned Character aura host) | V-053 | Recompute eligible moving recipients, range and suppression using giver values separately from bearer/recipient; exit removes only benefits requiring membership. | S-027, S-075 |
| S-081 — Chosen aura and lingering entry benefits | Verified (VS-86; chosen aura and timed entry receipts) | V-053 | Choose overlapping aura protection and retain explicitly timed entry benefits after exit; entering twice cannot restart a use beyond its declared policy. | S-080, S-040 |
| S-082 — Captured die/token/permission transfer | Verified (VS-63) | V-054, V-057 | Give an exact recipient a source-linked captured grant; generation level/die/permission and expiry don't change when giver later levels or removes another grant. | S-051, S-049 |
| S-083 — Recipient use budgets and shared rolled value | Verified (VS-64; shared weapon-attack bonus) | V-054 | Recipient spends its own declared Reaction/action; a shared one-time rolled bonus is captured once and not independently rerolled for every beneficiary. | S-082, S-041 |
| S-084 — Rule parameter upgrades | Verified (VS-120; owned mode parameter upgrades) | V-055 | Change count/die/targets/end predicates of an existing owned rule through data once; don't mutate catalog data or duplicate the base benefit on reload. | S-036, S-049 |
| S-085 — Rule options and exclusive replacements | Verified (VS-122; mode options and parameter alternatives) | V-055, V-037 | Add/remove legal modes/permissions/masteries through source-owned upgrades; mutually exclusive Extra Attack/AC policies remain alternatives. | S-084, S-103 |
| S-086 — Source-end reason and located aftermath | Verified (VS-117/145; shared spells, self modes, exact items and created actors) | V-056 | Emit one final owned state/origin for expiry/dismissal/destruction/death; declared follow-up effects fire once and don't conflate end reasons. | S-014, S-072 |
| S-087 — Source-end child effect/timer continuation | Verified (VS-145; represented-room heal/object/entry-area children) | V-056 | Run a declared heal/hazard/timer from the captured end event, preserving final location and costs across any child choice; delayed end observation doesn't relocate it. | S-086, S-034 |
| S-088 — Ordered procedure position | Planned | V-081, V-057 | Retain exact next procedure step and choice/deadline across interruption, allowed reload and reset; sequence position isn't a use pool. | S-214, S-064 |
| S-089 — Remaining faces/cards and replacement | Planned | V-081 | Track exact remaining membership; equal faces/copies stay separate, with declared discard/replace/reset and no redraw on replay. | S-088, S-051 |
| S-090 — Escalating DC/chance and reset history | Verified (VS-96; owned repeat-save DC history) | V-088, V-057 | Calculate DC/risk from owned attempts; increment only at the stated attempted/accepted/result boundary and reset only at the declared event. | S-016, S-062, S-043 |

## P3 — Rolls and decisions

| Slice | State | Capability coverage | Build and acceptance finish line | After |
|---|---|---|---|---|
| S-091 — Declared Advantage/Disadvantage policy | Verified (VS-29) | V-012 | Add/cancel/forbid eligible modes with source exemptions before the roll; replacing a natural result does not count as changing its mode. | S-024, S-041 |
| S-092 — Explicit attack/save success and failure | Verified (VS-30) | V-013 | Force the declared hit/miss/save outcome at its authorized window while preserving numeric roll fields; no invented natural 20 or premature consequence. | S-020, S-041 |
| S-093 — No-roll outcome and Death Save cancellation | Verified (VS-113; Character no-roll Death Saves) | V-013 | Declare eligible automatic outcome/canceled upcoming Death Save before consequences; no d20 is rolled or numeric bonus offered when the rule says no roll. | S-092, S-117 |
| S-095 — Subtract total or change defending AC | Verified (VS-32) | V-014 | Offer a qualifying downward total/defensive AC change after a provisional hit; final miss prevents damage-side spending and exposes its new result. | S-023, S-041 |
| S-096 — Off-turn and creature-owned attack choices | Planned | V-014 | Extend the same operation to Opportunity/reaction attacks and data-owned creature sources through their actual control/AI routes; exact roll and budget ownership remain. | S-023, S-057, S-156 |
| S-097 — Another actor's optional roll intervention | Verified (VS-65; fixed helping weapon-attack modifier only) | V-014, V-013, V-035, V-089, V-090 | Select the legitimate helping/defending source and its budget for an already-supported modifier/outcome/reroll/token operation at its authorized window; wrong owners cannot settle, and follow-up actions share the same occurrence. | S-095, S-083 |
| S-098 — Independent save/miss damage and riders | Verified (VS-35) | V-015 | Choose damage scale and rider eligibility independently for each settled success/failure/miss; a half-damage miss doesn't grant a hit-only rider. | S-022, S-043 |
| S-099 — Evasion and chosen recipient exemptions | Verified (VS-50) | V-015 | Author eligibility and chosen target exceptions for the actual occurrence; one recipient's mapping cannot alter others or turn saved into a different roll. | S-098, S-026 |
| S-100 — Other declared result-payment predicates | Verified (VS-51) | V-035 | Commit/refund/reserve only the chosen resource when its explicit success/failure predicate matches; preserve required upfront funds and one final outcome across suspension. | S-019, S-094, S-043 |
| S-101 — One integer budget across recipients | Verified (VS-66; HP/Temporary HP) | V-036 | Choose eligible recipients and integer amounts under total/count/per-target caps; finalize once, with declared unspent/cancel policy and no partial payment on refusal. | S-023, S-026, S-036 |
| S-102 — Roll-derived and dice-count allocations | Verified (VS-67; HP/Temporary HP) | V-036, V-038 | Allocate one captured rolled total or selected owned dice among recipients; don't reroll per recipient or double-spend the original quantity. | S-101, S-051 |
| S-103 — Rest/per-activation mode choices | Verified (VS-119; class/subclass rest and activation modes) | V-037, V-025 | Select a declared mode at rest or activation and replace its owned grants; permanent progression choices remain different and parent use/lifetime doesn't restart. | S-045, S-049 |
| S-104 — Per-hit/turn-start mode switches | Verified (VS-121; declared hit and turn-start mode windows) | V-037 | Change only legal mode parameters at the declared hit/turn event; earlier settled outcomes and parent activation cost/deadline stay fixed. | S-103, S-056 |
| S-106 — Chosen old/new reroll with mode/bonus | Verified (VS-48) | V-089, V-012 | Offer old versus new only where declared; apply specified Advantage or level bonus to the new test without replaying spent tokens or effects. | S-105, S-091, S-037 |
| S-107 — Authored replacement-token generation/reset | Planned | V-090, V-013, V-057 | Generate/capture distinct visible/hidden owner tokens with declared reset and equal-face identities; reuse accepted pre-roll consumer, and reload cannot generate fresh values. | S-051, S-063 |
| S-108 — Post-roll natural-result token replacement | Planned | V-090, V-013 | Replace the natural result at a separately authorized failed/successful window using one exact token or fixed value; recompute totals/outcome without another d20. | S-107, S-041 |
| S-224 — Noncombat spell/check modifier choice hosts | Planned | V-014, V-013, V-035, V-089, V-090 | Route already-supported captured modifier/outcome/reroll/token choices in represented local-room/event exploration hosts; retain original actor/target/DC/AC and once-only costs across scene/control changes. | S-094, S-022, S-225, S-108, S-226 |
| S-225 — Weapon and shared-spell reroll consumers | Verified (VS-49) | V-089, V-012, V-014 | Reuse declared mandatory-new/chosen rerolls in actual weapon and flat/ordered shared-spell attack/save routes; preserve natural/critical rules, original profile/DC, token/source costs and later damage/step continuation. | S-105, S-106, S-022 |
| S-226 — Death Save and concentration roll choices | Planned | V-013, V-014, V-035, V-089, V-090 | Apply only source-authorized captured bonus/outcome/reroll/token operations to actually rolled Death Saves/concentration; preserve original failure/success policy, counters/zero-HP effects and earlier damage/cast payment once. | S-225, S-092, S-108, S-109 |

## P4 — Damage and consequences

| Slice | State | Capability coverage | Build and acceptance finish line | After |
|---|---|---|---|---|
| S-109 — Component versus whole-occurrence damage edits | Verified (VS-52) | V-016 | Apply declared fixed/formula reduction at the named incoming stage; retain component typing/overflow and record prevention before HP/aftereffects settle. | S-034, S-041 |
| S-110 — Precisely scoped mitigation bypass | Verified (VS-53) | V-016 | Bypass only declared resistance/immunity/ward/prevention layers for an eligible component; other layers and unrelated components still settle normally. | S-109 |
| S-111 — Linked split-damage settlement | Verified (VS-107; bounded damage hosts) | V-017 | Split one eligible incoming occurrence with declared rounding into actual recipients; preserve total, independent mitigation and original causal identity. | S-109, S-026 |
| S-112 — Redirect incoming damage to linked recipient | Verified (VS-108; bounded damage hosts) | V-017 | Transfer the declared share/all to another eligible actor without replaying attack/riders; missing recipient or refused choice follows declared fallback. | S-111 |
| S-113 — Incoming damage replacement/healing | Verified (VS-109; bounded damage hosts) | V-018 | Use qualifying raw/resolved amount at the specified stage to absorb/replace/heal, including declared immunity interaction; don't count prevented damage as HP loss. | S-109, S-034 |
| S-114 — Settled-damage countereffects and feedback limits | Verified (VS-110; bounded damage hosts) | V-018 | Create linked counter-damage/heal from actual taken/prevented amount, honoring declared recursion/causal limits so a response doesn't trigger itself forever. | S-113, S-034 |
| S-115 — Whole pending cast cancellation | Verified (VS-88) | V-019 | Cancel eligible pending spell effects by actual level/school/source, retaining specified spent costs and already-final facts; don't cancel unrelated casts. | S-135, S-042 |
| S-116 — One recipient's incoming effect negation | Verified (VS-90) | V-019 | Exclude only the qualifying recipient/step from an original cast, leaving other targets intact; reflection/retargeting remains a separate operation. | S-115, S-098 |
| S-117 — Authored zero-HP replacement eligibility | Verified (VS-111; bounded pre-defeat damage hosts) | V-020 | Reuse the existing zero-HP boundary with declared damage/critical/outright-death exclusions and replacement HP formula; intercept before unconsciousness/death. | S-004, S-109 |
| S-118 — Escalating-save zero-HP replacement | Verified (VS-112; exact source-owned attempt/reset history) | V-020, V-088 | At the same boundary resolve a declared save/DC history and increment/reset policy; failure uses original proposed outcome and success applies once. | S-117, S-090 |
| S-119 — Death/destruction distinct from ordinary HP loss | Verified (VS-114; source-declared zero-HP aftermath) | V-021 | Apply eligible instant death/destruction with declared gear/remains policy, preserving original identity and actual cause for later revival. | S-117, S-032 |
| S-120 — Aftermath successor actor or hazard | Verified (VS-126/145; actor successors and bounded source-end room objects/entry hazards) | V-021 | Create the declared actor/object/hazard from final death/destruction once at its actual location, with exclusions and retained/disposed gear as specified. | S-119, S-154 |
| S-121 — Required legal exit before outcome settlement | Verified (VS-144; combat and local-room single-target numeric saves) | V-022 | Choose/validate legal exit placement before final save/outcome; no space changes outcome only as authored, without premature movement or failed-save effects. Outcome-based bonus payment follows the final settled save. | S-033, S-043 |
| S-122 — Creation/arrival placement and failure costs | Verified (VS-139; combat/local-room creation, item controls, represented overworld random travel and size-based footprints) | V-022 | Validate required space before creation/arrival and apply the declared no-space cost/result; placement refusal never silently creates an overlapping actor. | S-121, S-135 |
| S-123 — Damage/healing dice removal and maximizing | Verified (VS-103; critical base-die cost boundary) | V-023 | Remove a declared dice quantity before rolling or maximize eligible dice; separate noncritical cost dice from critical/result multiplication. | S-010, S-034 |
| S-124 — Selected damage/healing dice rerolls | Verified (VS-104; authored healing policy and exact payment receipt) | V-023 | Reuse actual rolled-dice selection with declared eligibility/kept policy/count/cost; chosen dice reroll once and frozen siblings remain unchanged. | S-123 |
| S-125 — Critical and final-result multipliers | Verified (VS-105; explicit critical exclusion) | V-023 | Multiply the declared dice/component/result at its stated stage with explicit rounding; fixed bonuses, typed components and critical exclusions remain distinct. | S-123, S-109 |
| S-126 — Qualifying ability/die/type/attack/DC replacement | Verified (VS-116; weapon profiles and spell save DC; batch 085 extends spell profiles with S-140 cast fields) | V-024 | Build a scoped actual attack/cast profile with replaced/additive/inherited fields; chosen damage type or fixed attack/DC cannot mutate catalog or unrelated actions. | S-036, S-024 |
| S-127 — Reach/mastery and damage-type choice | Planned | V-024 | Offer legal per-hit/activation reach/mastery/type options for the qualifying profile; property source and selection timing remain explicit. Batch 067 boundary: damage-type choices at an authored `choice_window` are built (see [attack profiles](../mechanics/attack-profiles.md)); batch 077 hosts them per Extra Attack swing and batch 087 on Opportunity, Light/Nick, Cleave and created-creature turn attacks. PARTIAL: S-156 commanded actors, summon attacks, item-granted profiles; reach/mastery choices remain open. | S-126, S-103 |
| S-128 — Source-specific unrecoverable injury | Planned | V-085, V-057 | Record exact unhealable damage separately from other missing HP; ordinary heal/rest honors its amount, source cure removes only that restriction. | S-034, S-071, S-072 |
| S-129 — Unhealable damage through revival/recovery | Planned | V-085, V-067 | Apply declared injury policy to revival/allowed checkpoints while preserving healable deficits; source removal/cure restores eligibility without manufacturing healed HP. | S-128, S-176 |
| S-130 — Source-owned maximum-HP changes | Verified (VS-115; Character maximum-HP sources) | V-095, V-057 | Apply/remove source deltas or periodic reduction with current/max-HP clamps, floor and cure boundaries; equivalent sources cannot revoke one another. | S-048, S-109 |
| S-131 — Maximum-HP zero death/remains policy | Verified (VS-124; Character zero-maximum death) | V-095, V-021 | Use source-specific zero-limit death/remains behavior and recovery restrictions, distinct from current-HP zero and injury-specific healing blocks. | S-130, S-119 |
| S-132 — Redirect original incoming spell target | Planned | V-097 | Propose a legal alternate recipient for only the permitted original spell/step; retain original slot/parameters and settled earlier recipients, with no recast. | S-116, S-144 |
| S-133 — Reflection with declared caster policy | Planned | V-097 | Reflect using stated original-versus-reflector attack/DC/ownership, preserving causal identity and limits; redirected origin/recipient alone cannot choose new stats. | S-132, S-114 |

## P5 — Casting and action composition

| Slice | State | Capability coverage | Build and acceptance finish line | After |
|---|---|---|---|---|
| S-134 — Source-owned casting permission | Verified (VS-76) | V-028, V-027 | Offer prepared/book/item/innate permissions with their own spell, ability, level/list/component restrictions; eligibility is not merely knowledge of an ID. | S-049, S-045 |
| S-135 — Alternative slot/free/point casting payment | Verified (VS-77) | V-028, V-031 | Select one allowed permission/payment before invocation; one source's free use or point cost doesn't consume another source's slot or permit an unavailable child. | S-134, S-006 |
| S-136 — Ritual and component eligibility | Verified (VS-81) | V-028 | Apply source-specific ritual access, timing and components through actual casting routes; ritual-only access cannot become a normal action/slot permission. | S-134, S-028 |
| S-137 — Per-source repertoire/preparation replacement | Verified (VS-78) | V-029, V-057 | Keep each class/source list, ability, preparation limit and replacement boundary distinct; source removal/reload retains only actually acquired permissions. | S-134, S-037 |
| S-138 — Combined versus Pact slot progression | Verified (VS-79) | V-029 | Calculate declared multiclass rounding and class-specific contributions; ordinary slots, Pact slots and preparation limits remain separate. | S-137, S-037 |
| S-139 — Fixed-level/source spell uses | Verified (VS-80) | V-029 | Represent fixed-level limited permissions separately from payable slot pools; restoring/upcasting/selection obey that source's rules. | S-138, S-135 |
| S-140 — Cast-local school/range/components/timing | PARTIAL (batch 085: player HUD casts; range/V-S removal/school/Action↔Bonus Action; no costed profiles, reactions, AI, M removal; native Metamagic not migrated) | V-030 | Transform only qualifying invocation fields after selection, preserving catalog data and unrelated casts; multiple compatible source changes apply once. | S-134, S-126 |
| S-141 — Cast-local duration/concentration/summon parameters | Planned (follows batch 085; untouched there) | V-030 | Alter declared duration, concentration or created-actor values on that invocation; expiry and removal use its captured settings and source. | S-140, S-154 |
| S-142 — Interruption/failure reserve and refund | Verified (VS-87) | V-031 | Apply declared commit/refund policy to the actual interrupted/failed cast and source payment; empty effect does not automatically mean refund. | S-135, S-043 |
| S-143 — Stopping-spell success/failure cost policy | Verified (VS-89) | V-031 | Use the real stopping result to keep/refund eligible slot/use and consume/dispose exact item as declared; do not repay original target spell. | S-142, S-115 |
| S-144 — Extra eligible recipients in one cast | Verified (VS-147; Character-anchored tether groups) | V-032 | Add declared targets while retaining one invocation, original costs and independent per-target outcomes; refused extras cannot replay the original target. | S-134, S-026, S-022 |
| S-145 — One invocation's alternate cast origin | Planned | V-032, V-074 | Select a legal sensor/object/illusion origin while retaining actual caster senses, cost, source and targets; origin is not a second caster. | S-144, S-192 |
| S-146 — Attack/strike unit substitution | Verified (VS-97; Attack/Flurry substitutions) | V-033 | Treat current Attack/Flurry as explicit remaining units; one permitted spell/item/heal substitutes declared one/two units without a second action payment. | S-134, S-021 |
| S-147 — Companion command replaces attack unit | Planned | V-033, V-059 | Substitute a declared command unit for the owner's attack while checking real companion authority/availability; preserve both actors' remaining budgets. | S-146, S-156 |
| S-148 — Child actions inside parent budget | Verified (VS-98; declared combat children) | V-034 | Invoke declared strike/cast/move children from a parent Action/Bonus/Reaction using local cost waiver and classification, preserving original causal source. | S-146, S-058 |
| S-149 — Child-action choice and interrupted parent | Verified (VS-99; once-only child continuation) | V-034 | Resume a pending child exactly once and preserve remaining siblings/parent budgets; cancel/refusal follows explicit policy instead of restarting the parent. | S-148, S-022 |
| S-150 — Store an exact spell with original caster snapshot | Planned | V-084, V-057 | Charge an owned exact copy within capacity, suppressing normal effects; retain spell/paid level/DC/attack/ability and declared full-capacity waste policy. | S-135, S-049, S-138 |
| S-151 — Release stored spell once | Planned | V-084 | New holder chooses actual legal targets using stored numbers and declared ownership; release consumes only the selected stored entry and does not repay its original slot. | S-150, S-144 |
| S-152 — Temporary preparation theft and enemy prohibition | Planned | V-087, V-057 | A qualifying failed save grants exact spell permission and denies that enemy's matching spell for the captured deadline, without storing a cast or removing others' knowledge. | S-116, S-137, S-049 |
| S-153 — Theft expiry/source removal lifecycle | Planned | V-087 | Remove only the stolen permission/prohibition when its declared boundary ends; reload and repeated callbacks neither extend time nor revive old grants. | S-152, S-072 |

## P6 — Actors and forms

| Slice | State | Capability coverage | Build and acceptance finish line | After |
|---|---|---|---|---|
| S-154 — Parameterized created actor | Verified (VS-123; source-linked actor templates) | V-058, V-057 | Create a source-linked actor with declared AC/current/max HP/attack/DC template values and retained owner identity; forbidden template creation features are excluded. | S-032, S-036, S-049 |
| S-155 — Factory choices/count and creation refusal | Verified (VS-140; combat and room factories; broader choices remain) | V-058 | Select permitted template/options/count, validate actual space/exclusions before creation, and create only the declared actors with unique identities. | S-154, S-122 |
| S-156 — Command cost/range/default authority | Verified (VS-141; exact commands, costs and defaults) | V-059 | Issue legal commands to actually owned eligible creatures through control/AI routes; charge the declared owner action/Bonus once and apply default when uncommanded. | S-154, S-026 |
| S-157 — Owner-linked versus independent initiative | Verified (VS-142; owner-turn/after-owner/independent and exact-source shared counts) | V-059 | Schedule independent/owner-turn/after-owner/shared-count created actors with their own budgets; actor death/removal cannot replay or skip the owner's interrupted work. | S-156 |
| S-158 — Incapacity and control-expiry autonomy | Verified (VS-143; declared defaults and owner-removal scheduling) | V-059 | When owner is incapacitated or command/control expires, apply declared autonomous/default behavior without automatically destroying the existing actor. | S-157, S-072 |
| S-159 — Inserted extra turn | Planned | V-060 | Insert a full actor turn at a declared initiative position while retaining interrupted work and per-round history; an extra Action does not create a turn. | S-157, S-030, S-056 |
| S-160 — Off-turn and type-limited Reaction/action budgets | Planned | V-060 | Grant only declared extra Opportunity/legendary/child actions with their own reset/option locks; spending one cannot supply a general Reaction or own-turn Action. | S-156, S-057 |
| S-161 — Exclusive exact-copy/actor bond | Verified (VS-127; exact-copy and owned-actor bonds) | V-061, V-057 | Bind actual item/actor to owner with declared uniqueness/capacity and legal replacement; refusal preserves the previous bond and all other sources. | S-049, S-026 |
| S-162 — Linked-copy/group replacement lifecycle | Verified (VS-129; declared linked-copy loss and replacement) | V-061 | Replace/dispose specified old bonded copies or related group deliberately; removal/destruction affects only the linked identities and specified survivors. Consumption currently passes cause `destruction`; a dedicated consume cause is deferred until content needs it (Batch 083, #47 follow-up). | S-161, S-119 |
| S-163 — Reversible retained-stat actor projection | Verified (VS-125; reversible self projections) | V-062, V-057 | Apply selected form stats while retaining declared original HP/resources/type/mental/features; reversion restores the same actor without reacquiring or refilling sources. | S-154, S-039, S-084 |
| S-164 — Dropped/merged/worn equipment in forms | Verified (VS-128; merged/worn and persistent-room ground equipment policies) | V-062 | Choose legal equipment policy, suppress only merged exact-copy effects and route worn/dropped state correctly; reversion/unequip restores only remaining owned properties. | S-163, S-049 |
| S-165 — Exact item copy projects into actor/object | Verified (VS-130; item-to-actor projection and combat/room controls; room vessels in VS-151) | V-063, V-057 | Project one owned copy into declared temporary actor/vessel retaining original copy identity and contents; the temporary form cannot duplicate the item. | S-163, S-161 |
| S-166 — Item-form reversion HP/overflow/location | Verified (VS-146; exact actor copy, bag/nearby room-ground return) | V-063 | Apply declared reset/overflow and legal return location on ending/damage; destroy original only when specified, preserving unrelated linked copies. | S-165, S-121, S-109 |
| S-167 — Projected vessel contents and movement | Verified — [VS-151](#projected-vessel-contents) | V-063, V-076 | Cargo/occupants stay attached to the actual projected vessel across movement/reversion; release/retain contents follows declared space and container policy. | S-166, S-196, S-170 |
| S-168 — Actor/object grapple and restraint relation | Verified (VS-136, extended in VS-147; Character/object tether anchors) | V-064, V-057 | Bind actual captor, victim and anchor with range/restrictions; escape checks/actions refer to that tether and don't end another source's restraint. | S-026, S-028, S-072 |
| S-169 — Escape/rescue and destroyed-anchor cleanup | Verified (VS-138, extended in VS-147; declared tether rescue and damage) | V-064 | Route eligible rescue/damage/escape to the tether or object; destroying/moving its anchor releases only affected relations through their actual consequence route. | S-168, S-119 |
| S-170 — Containment occupancy and capacity | Verified — [VS-148](#containment-occupancy) | V-065, V-057 | Put eligible actual occupants/gear into declared creature/object/space capacity, distinguish internal from external location and retain exact occupants across reload. | S-168, S-033, S-196 |
| S-171 — Internal harm/targeting and escape/rescue | Verified — [VS-149](#containment-internal-interactions) | V-065 | Apply source-declared internal damage, target eligibility and escape/rescue to contained occupants; internal position doesn't make every external effect legal. | S-170, S-109, S-169 |
| S-172 — Moving container and legal occupant release | Verified — [VS-150](#containment-movement-release) | V-065 | Owner/container movement carries actual occupants; expiry/destruction/escape releases them using declared legal placement/fallback rather than overlapping or deleting them. | S-171, S-121 |
| S-173 — Controller/host and mixed-stat possession | Planned | V-066, V-057 | Keep controller and host identities/awareness distinct with declared mixed statistics; command and attack/effect routing target the specified entity. | S-163, S-156 |
| S-174 — Possession ending/control return and immunity | Planned | V-066 | Restore correct controller/host state on declared exit/death/source end; retain source-specific subsequent immunity without destroying either original identity. | S-173, S-072, S-086 |
| S-175 — Death/remains/soul revival eligibility | Planned | V-067, V-057 | Query real death time, preservation, remaining body, willing/free soul and restrictions; unknown eligibility cannot silently approve revival. | S-119, S-049 |
| S-176 — Distinct revival HP/repair/aftereffect policies | Planned | V-067 | Revive the same original actor using declared HP, body/condition repairs and aftereffects; count/pay actual use once, including canceled/refused choices. | S-175, S-135 |

## P7 — Space, perception and illusions

| Slice | State | Capability coverage | Build and acceptance finish line | After |
|---|---|---|---|---|
| S-177 — Known destinations and actual plane/location | Planned | V-068, V-057 | Represent declared known/unknown destination and plane with actual saved arrival/previous point; unknown names cannot create invented reachable places. | S-033, S-049 |
| S-178 — Temporary removal versus travel and return | Planned | V-068 | Move/remove actual eligible actors/passengers with declared return deadline and nearest-legal fallback; ordinary travel does not automatically promise a return. | S-177, S-121, S-086 |
| S-179 — Speed/mode and terrain/surface costs | Verified (VS-102; bounded represented combat host) | V-069 | Use declared walking/climbing/swimming/flying/hover speeds, terrain and actual hand/surface requirements; movement refusal spends no distance or unrelated mode. | S-032, S-033 |
| S-180 — Phasing/burrowing/pass-through occupancy | Planned | V-069 | Permit declared passage through eligible material/occupants without treating it as legal end space; unknown obstructions and forbidden surfaces still block. | S-179, S-032 |
| S-181 — Expired flight/fall/descent/shunt | Planned | V-069 | When movement permission ends, use actual position and declared controlled descent/fall/shunt; legal end placement precedes final consequences. | S-180, S-072, S-121 |
| S-182 — Linked willing passenger movement | Planned | V-070 | Select legal willing passengers and actual destinations within source limits; move one group once, retain carried identities and declared opportunity suppression. | S-179, S-026, S-121 |
| S-183 — Each beneficiary's Reaction movement | Planned | V-070 | Offer each eligible actor its own movement choice and Reaction cost; declined/used budgets and destinations remain independent through sequential choices. | S-182, S-083 |
| S-184 — Entry/crossing/turn/first-approach trigger scopes | Planned | V-071, V-041 | Distinguish actual entry/crossing/start/end/first approach and source/actor scope; moving the area and moving an actor are not always the same trigger. | S-179, S-057, S-042 |
| S-185 — Selective actor/effect barriers | Planned | V-071 | Block only declared actor types/effects across a real boundary with source exceptions; rejected movement/cast doesn't partially cross or settle payload. | S-184, S-032, S-098 |
| S-186 — Barrier placement over existing occupants | Planned | V-071 | Apply declared displacement/termination/pass-through when creating or moving a barrier over occupants; preserve legal destination, source and prior budgets. | S-185, S-121 |
| S-187 — Located nonoccupying image/sound/duplicate | Planned | V-072, V-057 | Create source-owned image/sound with location and identity but no creature occupancy/HP unless specified; ending it retains final origin for declared aftermath. | S-049, S-184 |
| S-188 — Per-observer suspicion/investigation/discovery | Planned | V-072, V-083, V-003, V-057 | Use declared context and Intelligence-influenced investigation, then the selected rule's actual discovery/interaction test; retain each observer's knowledge separately. | S-187, S-029, S-190, S-219 |
| S-189 — Constrained temporary illusion realization | Planned | V-072, V-076 | Realize an eligible represented object/bridge with actual collision and explicit harm/condition restrictions; duration/source end removes only that created object. | S-188, S-212, S-087 |
| S-190 — Observer-specific senses/light/obstruction | Planned | V-073 | Evaluate actual observer range/type/light/obstruction and source-specific vision exception; knowing a location isn't automatically seeing the creature. | S-029, S-032 |
| S-191 — Observer-relative concealment and invisible targets | Planned | V-073 | Apply Darkvision/Tremorsense/source-Darkness exceptions to eligible observers and targeting/rolls; one observer's discovery doesn't reveal it for everyone. | S-190, S-091 |
| S-192 — Independent perception/cast/effect origins | Planned | V-074 | Bind actual actor/sensor/illusion/object to only the authorized origin, retaining the real caster's senses when required; no origin implies shared omniscience. | S-190, S-049 |
| S-193 — Remote borrowed senses and delivery limits | Planned | V-074 | Let eligible observers borrow a linked sensor's specified senses/communication or touch-delivery route; exit/range/source loss restores normal restrictions. | S-192, S-026 |
| S-194 — Direction/location/identity-only disclosure | Planned | V-075 | Return only declared detection facts/nearest source/direction to the permitted observer; don't reveal the full actor sheet or concealed identity. | S-190, S-025 |
| S-195 — Masked thought/type/material detection rules | Planned | V-075 | Honor source-specific masks, thought permission and actual material/thickness limits; unavailable knowledge remains an explicit unknown. | S-194, S-032, S-219 |

## P8 — Physical items and bodies

| Slice | State | Capability coverage | Build and acceptance finish line | After |
|---|---|---|---|---|
| S-196 — Exact contents and mass/volume compartments | Verified (VS-131; non-nested exact compartment contents) | V-076, V-057 | Track actual copy contents with category/compartment/mass/volume limits; insertion/removal validates before moving anything and preserves identities on reload. | S-032, S-049 |
| S-197 — Liquid/portion/fuel quantities and overflow | Planned | V-076 | Consume/transfer actual quantities with declared portion/container constraints and overflow; cumulative active fuel time reuses its own budget rather than item count. | S-196, S-064 |
| S-198 — Recipe materials/time to exact output | Planned | V-077 | Validate required actual recipe/tools/materials and qualified completed work before creating output copies; interruption follows stated paid-material policy. | S-067, S-028, S-196 |
| S-199 — Completed work creates a real world change | Planned | V-077 | Run declared repair/door/pit/object change at the actual eligible location after work completes; recipe narration is not geometry or automatic item duplication. | S-198, S-212, S-033 |
| S-200 — Food/water/travel/environment exposure | Planned | V-078, V-057 | Track actual eligible cause-specific exposure and elapsed budget by actor; checkpoint recovery can't restart deprivation or count combat Exhaustion as travel exposure. | S-064, S-032 |
| S-201 — Exempt only declared survival consequence | Planned | V-078 | Apply food/water/travel/temperature exemptions to their exact cause and consumption policy; preserve other Exhaustion/hazard consequences. | S-200, S-029 |
| S-202 — Persistent curse and attunement restrictions | Verified (VS-132; declared persistent curse policies) | V-079 | Keep source-linked curse where declared after unequip, enforce legal voluntary unattunement/cure and exact breaking requirements; other item copies remain independent. | S-161, S-072 |
| S-203 — Magic-property suppression/restoration/destruction | Verified (VS-134; listed magical-property suppression/destruction) | V-079 | Suppress or destroy only specified magical properties with source/cause and retained mundane residuals; unsuppression restores still-owned eligible effects without reacquisition. | S-202, S-074, S-060 |
| S-204 — Shared occupant air supply | Planned | V-091, V-065, V-057 | Track available air and consumption by actual breathing occupants in container/environment; moving or reopening changes supply only as declared. | S-170, S-200 |
| S-205 — Breathing adaptations and suffocation | Planned | V-091 | Apply environment breathing/exemption to consumption and consequences, then declared suffocation progression per eligible actor; immunity to one hazard isn't universal. | S-204, S-201 |
| S-206 — Lost/attached body parts and functional effects | Planned | V-092, V-057 | Store actual missing/attached parts on the original actor and apply only declared functional restrictions; dropped parts retain identity for later repair/revival. | S-119, S-049 |
| S-207 — Conditional interrupted regrowth/restoration | Planned | V-092 | Restore eligible actual parts over declared qualified living-HP time; interruption resets/pauses as stated, and prosthetic attachment isn't biological regrowth. | S-206, S-066, S-176 |
| S-208 — Biological age versus campaign elapsed time | Planned | V-093, V-057 | Store actor biological age separately and apply declared age decrease/floor/rate or immunity to the actual event; campaign clock never rewinds. | S-064, S-037 |
| S-209 — Age-use cumulative chance/history | Planned | V-093, V-088 | Retain repeated-use history for age changes and calculate/apply declared chance once; restored source/checkpoint doesn't reset risk or reroll past outcome. | S-208, S-090, S-214 |
| S-210 — Attached parts and required sets | Verified (VS-133; exact attached parts and required sets) | V-094, V-057 | Bind actual gems/beads/shoes/weapons/adhesive with distinct copy identity and required set rules; partial removal disables only the declared dependent property. | S-161, S-196 |
| S-211 — Child-copy charges/removal/damage | Planned | V-094 | Each attached child retains its own charge/reset/damage state; casting destroys selected gem/bead only where declared and full group doesn't share one fake pool. | S-210, S-060, S-063 |
| S-212 — Repair an existing exact damaged object | Planned | V-096 | Restore eligible actual object HP/function with material/piece/location restrictions; no fresh-copy replacement, invented missing pieces or duplicated attachments. | S-032, S-049 |
| S-213 — Join retained pieces and preserve lost sections | Planned | V-096, V-094 | Join eligible existing pieces/rope sections while retaining missing length/parts and original identity; actual repaired geometry/properties reflect what remains. | S-212, S-210 |

## P9 — Procedures and campaign outcomes

| Slice | State | Capability coverage | Build and acceptance finish line | After |
|---|---|---|---|---|
| S-214 — Weighted table executes declared child procedure | Planned | V-080 | Roll a source-defined weighted table once and invoke supported child operations/templates on actual eligible targets; unavailable children refuse before unintended cost. | S-036, S-148 |
| S-215 — Controlled reroll/choose and nested tables | Planned | V-080 | Apply declared reroll/choose/forbidden-result/no-recursion policy with retained rolled choices; nested outcomes don't replay parent costs or settled children. | S-214, S-106 |
| S-216 — Real objective facts and once-only rewards | Planned | V-082, V-057 | Query actual collection/defeat/exploration progress and commit source-owned milestone/reward only after matching completion, retaining receipt across reload. | S-030, S-049, S-048 |
| S-217 — Child encounter/event completion continuation | Planned | V-082 | Bind pending reward to the actual spawned child event/encounter and original objective; leaving/repeating/canceling does not issue early/duplicate rewards. | S-216, S-149 |
| S-218 — Sender/listener/language and bounded communication | Planned | V-083 | Represent actual language/sender/listener and permitted communication range/type; telepathy or a message does not automatically grant knowledge or obedience. | S-026, S-193 |
| S-219 — Authored knowledge/attitude and explicit unknown | Planned | V-083, V-057 | Store declared per-actor knowledge/attitude/outcome facts and explicit campaign/owner judgment with source/permission; unrepresented questions remain unknown, with no universal GM system required. | S-025, S-218 |
| S-220 — Executable campaign-authored special outcome | Planned | V-083, V-086 | Select only available authored requirements/costs/effects and execute them once; unknown/unavailable special outcome keeps ordinary supported actions available. | S-219, S-222, S-149 |
| S-221 — Ordinary Wish procedure and consequences | Planned | V-083, V-086, V-028, V-031 | When selected, source-pin ordinary uses, restrictions and consequences; invoke only represented operations or legal duplicated spell permission, retaining costs/stress across the original invocation. | S-220, S-142, S-090 |
| S-222 — Referenced procedure capability closure | Planned | V-086 | Before offer/charge, derive needed operations/facts/choice routes/referenced children from supported data; report exact missing capability rather than silently skip an unknown operation. | S-134, S-214 |
| S-223 — Unsupported child and precise partial-support route | Planned | V-086 | Keep fully supported invocation distinct from explicit bounded approximation; actual selector/control respects child availability and no content-ID allowlist substitutes for missing behavior. | S-222 |

## Coverage crosswalk for all 97 parents

A slice can support several parents; count its S-ID once. A row here means
the requirement has an explicit destination, not that its broad capability
is accepted. Match final parent completion to the entire owning checklist
boundary and current source-backed clauses, not just the first working example.
V-057 additionally requires checkpoint acceptance inside every later stateful
row; its mapping below names explicit checkpoint-bearing slices.

| Capability | Counted slices carrying its scope |
|---|---|
| V-001 — Typed predicates and combinations | S-001, S-004, S-024, S-025 |
| V-002 — Actor/source relationships | S-002, S-026, S-027 |
| V-003 — Check purpose and required sense | S-028, S-029, S-188 |
| V-004 — Scoped action and damage history | S-008, S-030, S-031, S-056 |
| V-005 — Physical eligibility facts | S-032, S-033 |
| V-006 — Numeric references to prior results | S-003, S-017, S-031, S-034, S-035 |
| V-007 — Runtime formulas and tables | S-004, S-016, S-036, S-037, S-048, S-051 |
| V-008 — Natural-roll versus final-total floors | S-038 |
| V-009 — Modifier and base-stat combination | S-039, S-040, S-078 |
| V-010 — Resolution event facts and windows | S-013, S-018, S-021, S-022, S-041, S-042 |
| V-011 — Result predicates and cross-step gates | S-005, S-017, S-043, S-044 |
| V-012 — Pre-roll Advantage/Disadvantage policy | S-091, S-106, S-225 |
| V-013 — Natural result or automatic outcome replacement | S-020, S-092, S-093, S-097, S-107, S-108, S-224, S-226 |
| V-014 — Reevaluate a provisional result | S-018, S-021, S-022, S-023, S-076, S-094, S-095, S-096, S-097, S-224, S-225, S-226 |
| V-015 — Save and miss consequence remapping | S-098, S-099 |
| V-016 — Damage stages and scoped bypass | S-109, S-110 |
| V-017 — Split or transfer damage to another actor | S-111, S-112 |
| V-018 — Damage absorption and feedback control | S-113, S-114 |
| V-019 — Cancel a cast or negate a recipient | S-115, S-116 |
| V-020 — Replace a proposed zero-HP outcome | S-117, S-118 |
| V-021 — Destruction, death and aftermath | S-119, S-120, S-131 |
| V-022 — Outcome contingent on legal placement | S-121, S-122 |
| V-023 — Dice-level edits and result multipliers | S-059, S-123, S-124, S-125 |
| V-024 — Scoped attack/damage parameter replacement | S-126, S-127 |
| V-025 — Choice acquisition, replacement and prerequisites | S-045, S-046, S-103 |
| V-026 — Permanent progression grants | S-047, S-048 |
| V-027 — Grants owned by exact source instances | S-006, S-012, S-013, S-015, S-046, S-047, S-049, S-050, S-134 |
| V-028 — Casting permissions and alternative payment | S-134, S-135, S-136, S-221 |
| V-029 — Per-source repertoire and slot progression | S-137, S-138, S-139 |
| V-030 — Cast-local parameter transformations | S-140, S-141 |
| V-031 — Cast costs based on exact outcome | S-052, S-135, S-142, S-143, S-221 |
| V-032 — Extend targets or redirect origin for one invocation | S-144, S-145 |
| V-033 — Replace attack/strike units | S-146, S-147 |
| V-034 — Nested actions and local cost overrides | S-148, S-149 |
| V-035 — Optional payment after success or failure | S-019, S-021, S-022, S-023, S-094, S-097, S-100, S-224, S-226 |
| V-036 — Allocate one numeric pool across recipients | S-101, S-102 |
| V-037 — Choose modes at declared boundaries | S-085, S-103, S-104 |
| V-038 — Source-owned numeric and dice pools | S-006, S-010, S-023, S-051, S-102 |
| V-039 — Restore one resource by spending another | S-011, S-052, S-053 |
| V-040 — Budgeted and filtered recovery | S-054, S-055 |
| V-041 — Use locks with explicit scope and subject | S-008, S-056, S-057, S-062, S-184 |
| V-042 — Conditional free uses and cost replacement | S-058, S-059 |
| V-043 — Depletion and overflow consequences | S-060, S-061 |
| V-044 — Recovery event and amount policy | S-007, S-062, S-063 |
| V-045 — Active-use budget versus wall-clock duration | S-014, S-063, S-064, S-065 |
| V-046 — Work progress with deadlines and interruption | S-066, S-067 |
| V-047 — Repeat saves, counts and staged outcomes | S-068, S-069 |
| V-048 — Rest start, completion and benefit-only recovery | S-007, S-070, S-071 |
| V-049 — Source-linked termination predicates | S-012, S-072, S-073 |
| V-050 — Suppress a condition without removing it | S-074, S-075 |
| V-051 — Consume the next matching grant | S-013, S-076, S-077 |
| V-052 — Expiring Temporary HP and linked benefits | S-015, S-078, S-079 |
| V-053 — Dynamic aura membership and chosen beneficiary | S-080, S-081 |
| V-054 — Transfer a captured grant to another actor | S-079, S-082, S-083 |
| V-055 — Modify another rule's parameters or options | S-084, S-085 |
| V-056 — Aftermath on source end | S-014, S-086, S-087 |
| V-057 — Durable rule state at allowed checkpoints | S-009, S-012, S-013, S-014, S-015, S-031, S-048, S-049, S-051, S-064, S-066, S-069, S-074, S-079, S-082, S-088, S-090, S-107, S-128, S-130, S-137, S-150, S-152, S-154, S-161, S-163, S-165, S-168, S-170, S-173, S-175, S-177, S-187, S-188, S-196, S-200, S-204, S-206, S-208, S-210, S-216, S-219 |
| V-058 — Parameterized actor factory | S-154, S-155 |
| V-059 — Command authority and initiative relationship | S-147, S-156, S-157, S-158 |
| V-060 — Extra turns and off-turn action budgets | S-159, S-160 |
| V-061 — Exclusive bonds and linked replacements | S-161, S-162 |
| V-062 — Reversible actor statistics and equipment policy | S-163, S-164 |
| V-063 — Item-to-actor/object form lifecycle | S-165, S-166, S-167 |
| V-064 — Grapple, restraint and physical anchor relation | S-168, S-169 |
| V-065 — Containment, capacity and occupant movement | S-170, S-171, S-172, S-204 |
| V-066 — Possession and controller/host routing | S-173, S-174 |
| V-067 — Corpse eligibility and distinct revival policies | S-129, S-175, S-176 |
| V-068 — Destinations, planes and return-space policy | S-177, S-178 |
| V-069 — Movement modes, surfaces and end placement | S-179, S-180, S-181 |
| V-070 — Linked passenger and Reaction movement | S-182, S-183 |
| V-071 — Spatial triggers and selective barriers | S-184, S-185, S-186 |
| V-072 — Nonoccupying illusions and constrained realization | S-187, S-188, S-189 |
| V-073 — Observer-relative senses and concealment | S-190, S-191 |
| V-074 — Separate perception, cast and effect origins | S-145, S-192, S-193 |
| V-075 — Filtered detection and information permissions | S-194, S-195 |
| V-076 — Container quantities and capacity | S-167, S-189, S-196, S-197 |
| V-077 — Crafting and work completion transaction | S-198, S-199 |
| V-078 — Cause-specific survival exemptions | S-200, S-201 |
| V-079 — Curses, attunement and magic-property lifecycle | S-060, S-202, S-203 |
| V-080 — Weighted/random procedures and controlled selection | S-214, S-215 |
| V-081 — Sequence position and remaining membership | S-088, S-089 |
| V-082 — Campaign objectives and delayed rewards | S-216, S-217 |
| V-083 — Communication, knowledge and adjudicated facts | S-188, S-218, S-219, S-220, S-221 |
| V-084 — Store and release a spell with caster snapshot | S-150, S-151 |
| V-085 — Source-specific unrecoverable damage | S-128, S-129 |
| V-086 — Capability requirements for complete procedures | S-220, S-221, S-222, S-223 |
| V-087 — Steal temporary casting permission | S-152, S-153 |
| V-088 — Escalating DC or cumulative risk | S-090, S-118, S-209 |
| V-089 — Reroll with declared kept-result policy | S-097, S-105, S-106, S-224, S-225, S-226 |
| V-090 — Natural-result replacement tokens | S-097, S-107, S-108, S-224, S-226 |
| V-091 — Air supply and breathing eligibility | S-204, S-205 |
| V-092 — Body-part loss and restoration | S-206, S-207 |
| V-093 — Physical age and age-rate changes | S-208, S-209 |
| V-094 — Attached parts and child-copy identities | S-210, S-211, S-213 |
| V-095 — Owned maximum-HP changes | S-130, S-131 |
| V-096 — Repair actual object state | S-212, S-213 |
| V-097 — Redirect or reflect the original spell | S-132, S-133 |

## Source follow-up outside the capability denominator

These are four static source-discovery tasks, not four build/validation slices.
Preserve unknown bodies; no rule text is filled in from memory, and no Godot,
content conversion or individual-record correctness ledger belongs in them.

| Source task | Boundary | When needed |
|---|---|---|
| SRC-01 | Resolve intended 2024 maneuver, Metamagic, invocation, Fighting Style and Origin/Epic/other feat bodies absent from the selected source view; use identified local donors where available and name distinct requirements only. | Before converting those selections or claiming their vocabulary exhausted. |
| SRC-02 | Resolve missing common itemEntry, itemGroup, Hazard/Artifact/book references such as Ioun Stone, Dragon Scale Mail and Enspelled text; name distinct mechanical exceptions. | Before a selected item requirement depends on its missing body. |
| SRC-03 | Obtain/read missing intended revised spell and monster bodies/discriminators; preserve original scope and provenance, without promoting unloaded records. | Before using their clauses as requirements or claiming full corpus discovery. |
| SRC-04 | Read required repertoire/slot/progression tables and source-conflicting clauses for the selected vocabulary, including illusion/Wish exceptions. | Before implementation needs an unknown table/exception; no global fidelity audit prerequisite. |

Local Foundry PHB/MM donors have now been inventoried for descriptions,
progression, spell lists and structured actions; consult the
[Foundry adoption plan](../content_pipeline.md#source-findings-to-retain) before repeating a source search.
This changes where SRC-01/SRC-03/SRC-04 can obtain selected inputs, not their
completion status or the rules authority. SRC-02 is only helped for records
actually present; PHB/MM are not a complete magic-item source. Offline
conversion and map ingestion remain outside this capability denominator.
Future wall/crossing integration aligns with S-179/S-184/S-185/S-190 without
accepting or enlarging those rows here. No accepted slice is reopened merely
because another source format or broader consumer becomes available.

A new distinct requirement gets a V-series entry or a precise refinement, then
its own S-ID only if existing rows cannot express its finish line. Missing
bodies do not justify closing vocabulary discovery or excluding hard mechanics.

<a id="src-01-feature-inventory"></a>

### SRC-01 class feature, subclass and feat inventory — 2026-10-26

Static inventory against SRD 5.2.1 headings (PDF pages), for planning only. It
adds no slice, changes no availability and reviews no clause. Per-feature rows
live in each class audit's **SRD 5.2.1 feature inventory** section (for example
[Fighter](../mechanics/fighter-2024.md#srd-feature-inventory)). "Reviewed" means
an SRD clause review already recorded in this registry; only Conversion Batch
001's Fighter Second Wind (blocked) and Barbarian Fast Movement (already generic)
qualify. Repo `rules_status: 2024-supported` is not treated as review.

| Surface | SRD 5.2.1 headings | In repo data | Absent | Reviewed | Unreviewed |
|---|---:|---:|---:|---:|---:|
| Class features (12 classes) | 174 | 170 + 4 subclass-choice levels | 0 | 2 | 172 |
| SRD subclass features (12 subclasses) | 58 | 15 (Champion 6, Open Hand 4, Fiend 5) | 43 | 0 | 58 |
| Feats (Origin 4, General 2, Fighting Style 4, Epic Boon 7) | 17 | 0 in `data/core` (fixture feats only) | 17 | 0 | 17 |

Repo-only records: 32 class-feature records and 3 Open Hand placeholders have no
matching SRD heading. Most are level placeholders (`*_subclass_feature_N`),
ASI levels from the class tables, or splits named inside one SRD body (Monk
Flurry/Patient Defense/Step of the Wind, Cleric Divine Spark/Turn Undead, Mystic
Arcanum by level). Source gaps with no SRD heading found: `druid_wild_shape_uses`,
`paladin_channel_divinity_divine_sense`, `sorcerer_metamagic_improvement_10/17`,
`fiend_spells_3/5/7/9` (SRD has one Fiend Spells heading, p.76). Abjurer and
Diviner subclasses (10 records) are not SRD 5.2.1 subclasses and are outside
this authority; Bard has no `subclass_level`.

Missing SRD subclasses: Berserker p.30, Lore p.35, Life p.40, Land p.46,
Devotion pp.56–57, Hunter p.61, Thief p.64, Draconic pp.69–70, Evoker p.82.

| SRD feat | Category | SRD | Repo |
|---|---|---|---|
| Alert, Magic Initiate, Savage Attacker, Skilled | Origin | p.87 | absent from core; S-049/S-050 acquisition is fixture-only |
| Ability Score Improvement, Grappler | General | p.87 | absent as feats; class ASI features are records, not feat data |
| Archery, Defense, Great Weapon Fighting, Two-Weapon Fighting | Fighting Style | pp.87–88 | absent as feats; Fighter uses native `fighter_rules` styles |
| Boon of Combat Prowess, Dimensional Travel, Fate, Irresistible Offense, Spell Recall, the Night Spirit, Truesight | Epic Boon | p.88 | absent; class Epic Boon records have no feat catalog |

Owning slices are recorded only where this registry names the feature or its
consumer (S-084 Extra Attack, S-085 Unarmored Defense, S-049/S-050/S-084/S-085/S-103/S-104
feat acquisition, Batch 001 Second Wind blockers, S-122 Faithful Steed arrival);
all other rows are `unassigned`. Next step: SRD clause review per class, then
stage the missing subclasses and the 17 feat bodies as source-backed data.

## Updating the denominator

Preserve S-IDs. When a planned row is accepted, attach its new VS evidence and
change its state; do not add a second slice for that same row. A real scope split
gets new IDs and an explicitly superseded parent row excluded from the total.
A merge records its replacement IDs; don't silently delete remaining work.
Record discovered additions/splits and refresh the phase/count/coverage tables.
Keep live quest/session details on the Quest Board and orchestration queue,
rather than turning this baseline into an execution diary.

Planning reconciliation checked all 97 V-IDs, all 226 unique S-IDs, every named
slice prerequisite, and absence of prerequisite cycles. This is document
consistency only; it is not runtime or rules-fidelity validation.


## Verified subset boundaries

These retained boundaries and evidence pointers describe the accepted hosts.
They do not require replaying historical review workflows or certify all catalog
consumers. Broader V-series requirements stay in the vocabulary checklist.

<a id="vs-01"></a>

- [x] **VS-01 — Boolean fact eligibility (`V-001`).** Ordered effects combine
  `target.is_source_owner` and `target.is_wounded` with `all`; a full-HP owner
  receives no healing. Other boolean forms and broader fact domains remain
  outside this production proof. [Evidence](../../.artifacts/tests/873b0c000b234f1a9c52e42ce764df83/shared_spell_p1_flow.stdout.log).

<a id="vs-02"></a>

- [x] **VS-02 — Current source-owner relationship (`V-002`).** The aftermath
  selects and heals the wounded owner of the current spell source. Ally/enemy,
  willingness, charm/mark provenance and distance relations remain open.
  [Evidence](../../.artifacts/tests/873b0c000b234f1a9c52e42ce764df83/shared_spell_p1_flow.stdout.log).

<a id="vs-03"></a>

- [x] **VS-03 — Earlier typed damage component (`V-006`).** An ordered spell
  exposes one selected Fire component's raw, resolved and actual HP-loss values;
  normal, Resistance, Immunity, Temporary HP and overkill cases are checked.
  Arbitrary target/component combinations, prevented/healed amount selectors
  and aggregation remain open. [Evidence](../../.artifacts/tests/873b0c000b234f1a9c52e42ce764df83/shared_spell_p1_flow.stdout.log).

<a id="vs-04"></a>

- [x] **VS-04 — Bounded arithmetic and caster/cast inputs (`V-001`, `V-007`).**
  Half of the selected resolved component uses positive-divisor `floor_divide`.
  Five formula leaf kinds read caster character level, named own-class level,
  proficiency, Intelligence modifier and selected slot level. Renamed and free
  casts work; live caster values update after a pause while the selected slot
  stays captured. Multiclass progression, other class/ability combinations,
  tables, choices, source dice and broader timing policies remain open.
  [Arithmetic evidence](../../.artifacts/tests/873b0c000b234f1a9c52e42ce764df83/shared_spell_p1_flow.stdout.log),
  [input/timing evidence](../../.artifacts/tests/e9a7a89073ea49ed96694834ce587c58/shared_spell_p1_flow.stdout.log).

<a id="vs-05"></a>

- [x] **VS-05 — Positive earlier-result gate across continuation (`V-011`).**
  The authored aftermath reads the earlier target's positive resolved Fire
  component, including after genuine pending-damage resumption. Damage, healing,
  slot and Empowered cost settle once; callback replay refuses. Margins, grouped
  child outcomes and other result gates remain open.
  [Evidence](../../.artifacts/tests/873b0c000b234f1a9c52e42ce764df83/shared_spell_p1_flow.stdout.log).

<a id="vs-06"></a>

- [x] **VS-06 — Exact-source numeric pools (`V-027`, `V-038`).** Shared class
  features acquire/query/spend independent owner/source-instance pools, use
  formula capacity, retain quantity on growth, clamp on shrink and remove only
  the selected source. The combat feature menu carries the exact source through
  activation; neutral and renamed definitions work. The bounded dice-pool
  extension is checked at its limited VS-10 boundary. Source-acquisition UI,
  broader grant domains and exchanges remain open.
  [Evidence](../../.artifacts/tests/f53f61526df641ba82bcda1f553010ec/shared_numeric_pool_flow.stdout.log),
  [later combined regression](../../.artifacts/tests/26038762fe2948a4ad5521fe7eec6432/shared_numeric_pool_flow.stdout.log).

<a id="vs-07"></a>

- [x] **VS-07 — Completed-rest numeric-pool recovery (`V-044`, `V-048`).**
  Actual Overworld Short Rest restores a fixed quantity with a capacity cap;
  Dungeon Long Rest fills eligible exact-source pools without running the Short
  policy. Start/cancel/refusal, ordinary elapsed time, downed and unrelated pools,
  renamed data and checkpoint reload are checked. Other rest/eligibility
  policies, Hit Dice, rest-start expiry, Initiative/dawn/dusk and cooldowns remain
  open. [Evidence](../../.artifacts/tests/26038762fe2948a4ad5521fe7eec6432/numeric_pool_rest_recovery_normal_controls_flow.stdout.log).

<a id="vs-08"></a>

- [x] **VS-08 — Weapon-rider combat-turn and owner-turn-interval limits (`V-041`).**
  Once per combat turn and once per target per combat turn retain their
  independent actor/source/option locks and real initiative progression. The
  bounded `once_per_owner_turn_interval` form adds a separately reset owner
  lock: the pre-first-turn interval starts clear; an off-turn use blocks repeats
  through other actors' turns; only the owner's next turn start resets it.
  Same-source removal/reacquisition retains the lock, while source and option
  identities remain independent. Misses, failed eligibility, empty pools and
  locked options preserve the base attack and spend no additional use. UI target
  selection and general subscriptions remain open. VS-54/55 extend own-turn,
  round/roll/active-instance scopes below. Earlier combat-turn evidence:
  [rider scenario](../../.artifacts/tests/31bbd8579b194f46b3589b20a6b96517/shared_combat_use_limits_flow.stdout.log).
  Owner-interval production evidence:
  [focused scenario](../../.artifacts/tests/9973f2cacd994a55872977a7977104af/shared_combat_use_limits_flow.stdout.log);
  [727 class checks](../../.artifacts/tests/2cc5aa83b6564b30bfce4e9f36765413).
  These checked slices do not close V-041.

<a id="vs-09"></a>

- [x] **VS-09 — Numeric-pool checkpoints (`V-057`).** Production SaveManager
  preserves exact owner, source, definition, capacity and remaining quantity at
  existing allowed checkpoints without reacquisition or replayed rest recovery.
  This is same-process save/load; fresh-process recovery and other rule-state
  payloads remain open. Combat locks stay transient and combat remains unsaveable.
  [Pool evidence](../../.artifacts/tests/f53f61526df641ba82bcda1f553010ec/shared_numeric_pool_flow.stdout.log),
  [post-rest evidence](../../.artifacts/tests/26038762fe2948a4ad5521fe7eec6432/numeric_pool_rest_recovery_normal_controls_flow.stdout.log).

<a id="vs-10"></a>

- [x] **VS-10 — Bounded dice-pool extension (`V-038`).** Production Godot
  checks loaded neutral and renamed definitions, offered and cancelled the real
  one/two-d6 quantity choice, and matched healing to individual results after
  the selected count was paid at activation. Invalid and insufficient choices
  refused before payment, rolling or action cost; owner/source pools remained
  independent. Existing rest controls recovered counts without rolls, and
  allowed checkpoint reload retained owner/source/definition/die/count/serial
  without reacquisition or recovery replay. This path has no continuation to
  persist. Evidence: [combined Godot run](../../.artifacts/tests/59351e0151bc4045a0af82b9fe5f073b/shared_dice_pool_flow.stdout.log).
  Source acquisition UI, exchanges, transferable/pre-rolled dice, class dice
  tables, payment-after-success, catalog conversion, fresh-process recovery and
  broader V-038 coverage remain open. See the [pool contract](../mechanics/shared-resource-pools.md#bounded-dice-pool-extension--production-validated-2026-10-12).

<a id="vs-11"></a>

- [x] **VS-11 — Fixed numeric-pool exchange (`V-039`).** Production combat
  menus selected exact owned payment/restoration sources for neutral and renamed
  data; the authored 2-for-1 committed once and changed no unselected source.
  Cancellation at either choice, insufficient payment, full destination,
  same-source, another actor's source, removal after selection, replay and forged
  exchange parameters all refused without changing payment/restoration counts.
  Allowed checkpoint reload preserved exchanged counts without reacquisition or
  replay. Other resource types and policies remain open. [Combined evidence](../../.artifacts/tests/b35a6f698e8f48fb807b4bc82aa808d7/shared_numeric_pool_exchange_flow.stdout.log).

<a id="vs-12"></a>

- [x] **VS-12 — Source-owned timed numeric self-grant (`V-027`, `V-049`,
  `V-057`).** Neutral and renamed definitions loaded through production
  DataLoader and activated through the real combat feature menu. One numeric
  use paid for +2 AC; a duplicate source refused before extra payment. Separate
  sources retained additive modifiers across staggered deadlines, exact-source
  removal and unrelated modifiers. Checks covered just-before/exact/after
  minute and hour deadlines, turn ticks, real combat/exploration clock
  advancement, scene changes and a large jump past expiry. Distinct prepare and
  recover processes preserved owner/source/grant serial/payload/absolute
  deadline through an allowed checkpoint without replay or lifetime restart;
  malformed full-save preflight refused before session replacement. This proves
  only this numeric self-grant shape, not general condition/effect semantics or
  arbitrary durable state. [Production scenario](../../.artifacts/tests/dda2fafb854345deb66c201809c18779);
  [fresh-process recovery and malformed-save probe](../../.artifacts/tests/timed-numeric-grant-relaunch-0f1cceb0b6ac4904b444f1e2482cadb4).

<a id="vs-13"></a>

- [x] **VS-13 — Source-owned next-matching melee-hit grant (`V-051`, the final-hit
  portion of `V-010`, bounded `V-057`).** Neutral +2 Fire and renamed +3 Cold
  definitions loaded through production DataLoader and activated through the
  real feature menu, each charging one exact source pool use. Actual weapon
  resolution proved canceled targeting, misses, ranged hits and another actor
  preserve the grant; the oldest qualifying grant is consumed once before
  damage settlement, including a critical and a base hit that downs its target.
  Fixed +2 Fire is not doubled and passes through Fire resistance/immunity;
  renamed +3 Cold passes through Cold resistance. Replaying the old result's
  completion after rearming left the new grant pending and target HP unchanged.
  Two pending grants retained source order, payload and absolute deadline over
  an allowed checkpoint in distinct prepare/recover processes without payment
  or activation replay. Malformed full-save preflight refused before replacing
  the live session. Production also checked repeat-hit, exact-source removal,
  staggered expiry and large clock jump. This does not certify general event
  subscriptions, other matchers, generic result facts or arbitrary save state.
  [Production scenario](../../.artifacts/tests/4370e8a4ce7d4d1291bbdda17786aa86);
  [fresh-process probe](../../.artifacts/tests/next-melee-hit-grant-relaunch-286d5a6bdb03400eb9acdfab1481088b);
  [focused class checks](../../.artifacts/tests/662ae1319efa45d790cdebb865ab8861).

<a id="vs-14"></a>

- [x] **VS-14 — Optional timed-grant end cooldown (`V-045`, `V-056`, with
  `V-027`/`V-049`/`V-057`).** Neutral +2 AC/60/3600 and renamed +3 AC/120/7200 definitions loaded
  through production DataLoader and activated through the actual combat feature
  menu. Each paid one exact-source pool use; duplicate, cooldown-blocked and
  wrong-owner dismissal commands refused without extra pool/action cost. Free
  exact-source dismissal started its cooldown at current campaign time, while
  scheduled expiry used the grant's absolute deadline. The production check
  covered just-before/exact/after timing, independent sources, one source's
  Short Rest refill while its longer cooldown remained active, and a single jump
  past both deadlines. Repeated end and replay of an old end after reactivation
  did not extend a deadline or consume the fresh grant. Omitted/zero cooldown
  retained VS-12 behavior. Distinct prepare/recover processes preserved an
  active grant and a cooldown-only record with owner/source/grant IDs, captured
  payload, serial, pool counts and absolute times; recovery did not replay
  activation. Malformed full-save preflight refused before replacing the live
  session. Only expiry and voluntary dismissal start a cooldown. Exact-source
  removal clears the active grant without a cooldown; other end reasons are
  unsupported, and this does not establish arbitrary cooldown/event semantics.
  [Production scenario](../../.artifacts/tests/2b29a42808f848dcb577f74d69d88500);
  [fresh-process and malformed-save probe](../../.artifacts/tests/timed-numeric-cooldown-relaunch-1bd96120f7504b64a3e1933fbe653946).

<a id="vs-15"></a>

- [x] **VS-15 — Exact-source expiring Temporary HP (`V-027`, `V-052`, bounded
  `V-057`).** Neutral 10/60 and renamed 16/120 definitions loaded through
  production DataLoader and the real feature menu; one pool use paid once and
  duplicate activation refused before cost. Lower/equal timed offers and real
  False Life kept the current amount and provenance. Actual partial damage kept
  the owner tag, full absorption cleared it without regeneration, and staggered
  exact expiry/removal could not erase a newer timed or ordinary replacement.
  Real Ranger Tireless also replaced the timed buffer after partial damage;
  ordinary ability-scaled Temporary HP now uses the declared ability modifier
  and retains a larger active grant. Zero-HP damage retained existing death-save
  behavior, and Death Ward absorbed Temporary HP before its one-time replacement.
  Distinct prepare/recover processes retained remaining amount, owner/source/grant
  IDs, serial and absolute deadlines without replay; missing fields/deadlines and
  orphan sources were refused by full-save preflight before live replacement.
  Keep-higher is the only replacement policy checked. Replacement-choice UI,
  cross-actor grants, linked effects and broader spell/class domains remain open.
  [Production scenario](../../.artifacts/tests/6cca603c5a014e8d99288d0843682c46);
  [fresh-process probe](../../.artifacts/tests/timed-temporary-hp-relaunch-5fd6758079e74199b7c9812a74449492);
  [focused class checks](../../.artifacts/tests/3882353fdd354207a6b9407d99d84424).

<a id="vs-16"></a>

- [x] **VS-16 — Deterministic numeric breakpoint lookup (`V-007`).** Neutral
  and renamed tables with different integer thresholds and outputs passed
  production DataLoader and actual feature-menu activation. Capacity selected
  greatest-threshold-at-or-below values for exact, between, and above-last
  inputs; below-first and failed nested inputs failed explicitly. Growth did
  not refill, shrink clamped after rest, and repeated queries did not roll or
  spend. Empty, duplicate, unsorted, nonnumeric, and dice-input definitions were
  rejected by production loading before cost. An ordinary shared spell used the
  same lookup plus arithmetic evaluator. Dice/source-die tables, choices,
  multiclass progression, and broader capture policies remain open. [Focused
  production scenario](../../.artifacts/tests/8b686402e0fb4369b57cd6c75d0e91ca).

<a id="vs-17"></a>

- [x] **VS-17 — Explicit earlier-step typed damage sum (`V-006`, minimal
  `V-011`).** Neutral Fire/12 and renamed Cold/10 loaded through production
  DataLoader and shared ordered casting. Exact per-target raw/resolved/HP-loss
  measures stayed separate across overkill, resistance, Temporary HP and
  immunity; distinct runtime actors with one definition ID each counted once.
  Empty/all-skipped outcomes sum to zero, while absent/malformed outcomes fail.
  Invalid stage/component references refuse before slot payment. A positive
  HP-loss predicate gated one caster heal after all target outcomes. The real
  spell-slot cast resumed across three target-save choices, paid once, retained
  outcomes, healed once and refused replay without mutation. Other reducers,
  prevented/healing measures, broad result predicates and durable continuation
  saving remain open. [Focused production evidence](../../.artifacts/tests/191cf0f3ff60489ba179bd87b546381b).

<a id="vs-18"></a>

- [x] **VS-18 — Optional post-roll failed-save bonus (`V-014`, minimal
  `V-010`).** Production DataLoader loaded the neutral DEX/+5 and renamed
  CON/+7 features and their shared spells. The normal spell picker opened the
  actual post-roll source chooser; the original natural d20, existing modifier
  and DC were preserved. Two instances of one DEX definition were both offered,
  and selecting the second charged only its exact pool. The +5 and +7 bonuses
  each converted failure to success before damage; +5 also stayed failed when
  the original total plus bonus was below DC and still paid once. Decline,
  cancellation, natural success, wrong actor/target, forged selection, empty or
  removed source, and replay refused or left pools/outcomes unchanged. A pre-roll
  Portent choice resumed once through a multi-target cast; spell-slot payment
  and settled target damage did not repeat. Production CombatState teardown
  released settled chooser/HUD references. This covers one fixed bonus on the
  owner's rolled failed save against a shared spell in the combat HUD host.
  Automatic failures, other roll domains/hosts, cross-actor help, dice bonuses,
  reaction budgets and general post-roll editing remain open. [Focused production
  scenario with required bootstrap/parse/boot gates](../../.artifacts/tests/272bc7e14f9d4b3492985d1972f77d19);
  [focused development checks and clean shutdown](../../.artifacts/tests/64095b1874a54775b27e8d5a19990340).

<a id="vs-19"></a>

- [x] **VS-19 — Conditional payment on converted save success (`V-035`, only
  the payment-policy subset).** Production DataLoader loaded the explicit
  pay-on-choice and renamed pay-on-converted-success definitions into the real
  combat chooser. An empty conditional source was omitted; changing its balance
  to zero while the chooser was open refused settlement, and restoring the same
  source allowed the same live answer to complete. A +7 that still failed kept
  full damage and spent zero uses; a later roll converted by that source paid
  once and used half damage. The visible chooser named the conditional policy.
  Explicit pay-on-choice also charged on an accepted failure; omitted policy
  keeps the VS-18 default path. Distinct exact sources, stale/removed/forged
  refusal, decline/cancel, one cast-slot settlement, earlier target/Portent
  continuation, replay refusal and combat cleanup reuse VS-18's production
  scenario. Other policy conditions, roll domains/hosts, cross-actor choices,
  dice bonuses and general post-roll edits remain open; this does not check V-035
  as a whole. [Focused production scenario with required gates](../../.artifacts/tests/3c966e9690ae4d388a3eed5322347d26);
  [development checks](../../.artifacts/tests/1c2d0c5bf36f48eba701714fd518d58c).

<a id="vs-20"></a>

- [x] **VS-20 — Explicit success override for an owner's failed shared-spell
  save (`V-013`, narrow outcome subset).** Neutral DEX/cost-1 and renamed
  CON/cost-2 features loaded through production DataLoader and the combat spell
  picker. Accepting the real chooser made the save successful while preserving
  its natural d20, modifier, numeric total and captured DC. The explicit result
  drove half-damage mitigation and success/failure rider gates in ordered casts;
  a flat shared spell also waited for the chooser before applying its failed-save
  condition. Decline/cancel retained failure consequences without payment;
  already-successful legacy success-only, no-roll paralyzed, nonmatching,
  other-owner, empty, stale, removed and forged choices did not alter the result
  or spend a source. Numeric
  bonuses and both payment policies remain available as separate alternatives.
  A previous settled completion replayed while a fresh CON choice was pending
  left that request, both pools and target HP unchanged; the new choice then
  completed normally. Existing multi-target/Portent continuation settled the
  spell slot, earlier outcomes and damage once. Source selection remains one
  payment of the authored cost from one exact source and one modification per result. Forced failure, automatic
  outcomes without a roll, other roll domains/hosts, cross-actor help, general
  conflict precedence and catalog-wide support remain open; this does not check
  V-013 as a whole. Forced failure and general rolled outcomes are checked in VS-30, including
  its independently reviewed native-use and source-option conflict repairs. [Focused production scenario with bootstrap/parse/boot
  gates](../../.artifacts/tests/10c21f9d43cd48a0b7016eda80955c6e);
  [focused development checks, 978/0](../../.artifacts/tests/7e616a3d05634cafb29e9cae10a3f05b).

<a id="vs-21"></a>

- [x] **VS-21 — Optional post-roll weapon-attack bonus (`V-014`, minimal
  `V-010`, payment-policy slice of `V-035`).** Production DataLoader loaded
  neutral +5/cost-1 and renamed +8/cost-2 definitions. The actual player Attack
  control and Extra Attack each opened a chooser for a separately captured
  missed roll; selecting each exact source converted its swing once, charged
  only that source, and preserved a single Attack action payment and one d20
  per swing. The first hit consumed its armed next-hit grant only after final
  resolution; an old settled answer was refused while the Extra Attack choice
  remained usable. A stale unaffordable source answer was refused while its
  visible menu remained pending, then closing that menu settled the unchanged
  miss without damage or payment and retained the separately armed grant. The
  renamed converted-success source paid once on a final hit; the neutral
  pay-on-choice source paid once when chosen. A separate real Rogue Attack
  offered Stroke before any optional source, used the captured roll and native
  use once, and left the optional pool untouched. Focused development checks
  additionally cover Shield-adjusted final hit/payment, natural 1 and natural
  20 boundaries, forged/wrong-owner/replayed answers, and canonical target
  identity. This checks the normal player Attack/Extra Attack combat host and
  fixed numeric bonus only. Still-failed conditional payment, decline/cancel
  (beyond the production miss cancellation), other hosts, Opportunity Attacks,
  monster-owned bonuses, and shared-spell attack domains remain open; this does
  not check V-014/035 as a whole. [Focused production scenario with required
  gates](../../.artifacts/tests/258a67b64044400b9405460eebfa2cd9);
  [retained Shield/natural-result development checks, 838/0](../../.artifacts/tests/746d768aa31a42a6944ae8b88a66e613);
  [latest development checks after canonical Stroke repair, 841/0](../../.artifacts/tests/8545cd6719474f4bb5d1347b933a8299).

<a id="vs-22"></a>

- [x] **VS-22 — Optional post-roll bonus on shared-spell attacks (`V-014`,
  minimal `V-010`, payment-policy slice of `V-035`).** Production DataLoader
  loaded the neutral fixed +5/pay-on-choice and renamed +8/pay-on-converted-
  success definitions through the real spell picker, targeting controls and
  source chooser. A Portent-selected natural 9 converted a flat miss once with
  one spell-slot payment and one exact-source payment; a renamed +8 that still
  missed retained the result without payment. Natural 1 remained a miss and
  natural 20 remained an already-hit result without a chooser. The ordered
  renamed spell resumed both a pre-roll token and a later Empowered damage-dice
  chooser; its conditional source paid only for a final hit, while an ordered
  miss applied only its miss rider. The hit rider and damage waited for final
  settlement, the earlier ordered step remained recorded once, and replaying a
  completed flat answer did not settle or charge a newer ordered choice. Six
  casts spent six slots, and the four non-token attacks rolled one d20 apiece.
  This checks the real combat host for flat/ordered shared-spell attacks and
  fixed numeric bonuses; noninteractive callers retain ordinary resolution.
  Other spell hosts, other attack windows, die bonuses, and catalog-wide
  support remain open; this does not check V-014/035 as a whole. [Focused
  production scenario with bootstrap/parse/boot gates](../../.artifacts/tests/41ebf1088d3f45608d4db6798ec5fd4c);
  [focused spell development checks](../../.artifacts/tests/631f2a31408c41ecbaae002be6161fba).

<a id="vs-23"></a>

- [x] **VS-23 — One captured owned die bonus across checked roll choices
  (`V-014`, minimal `V-010`, payment-policy slice of `V-035`, source-die
  slice of `V-038`).** Production DataLoader loaded neutral d6/cost 1 and
  renamed d8/cost 2 sources. Real combat controls accepted the d6 on a failed
  DEX save and flat shared-spell attack; a renamed d8 remained a failed CON
  save without payment, converted a later CON save and an ordered shared-spell
  attack with conditional payment, and was offered for normal Attack/Extra
  Attack. Pay-on-choice still charged an accepted attack that missed;
  pay-on-converted-success charged only when the save or attack converted.
  The captured natural roll, save DC and attack AC remained unchanged. Query,
  Decline, stale metadata and replay did not roll or spend; a natural-1 weapon
  attack did not offer a die. An old completion left a newer chooser and its
  earlier step untouched. The ordered die receipt matched the actual source
  roll before and after the real damage choice, while ordinary damage dice
  were counted separately. A weapon-only Stroke helper refused a live shared-
  spell attack request before using the native feature or consuming the request;
  the actual Decline menu then settled the miss normally. A separate visible
  renamed spell chooser selected its offered d8 after that source was depleted;
  it paid/rolled nothing, finished only the captured miss and rider, cleared
  the pending request, and allowed the following valid cast. Real normal weapon
  Attack controls converted a captured miss to a hit with both d6/cost1
  pay-on-choice and d8/cost2 pay-on-converted-success. Each preserved its one
  d20, rolled only the selected die, paid its exact source, applied damage once,
  and refused replay. This certifies only
  the rolled-save, normal player weapon Attack/Extra Attack, and real combat
  flat/ordered shared-spell attack chooser paths. Other save/attack hosts,
  noninteractive callers, other roll windows and broader pool/payment behavior
  remain open; this does not close V-014/035/038. [Final focused production
  scenario with bootstrap/parse/boot gates](../../.artifacts/tests/ad3f0ddaaa89478881f5ea2fdee90721);
  [current spells logic group, 1001/0](../../.artifacts/tests/0a0afca82e60469a944f05278b6dc281);
  [affected classes group, 849/0](../../.artifacts/tests/0948178dfbd84aefaa58c1d1fe0f6343).

<a id="vs-24"></a>

- [x] **VS-24 — Purpose-aware owned-tool eligibility in loaded event checks
  (`V-003`).** Production DataLoader loaded neutral Surveyor's Tools and renamed
  Field Guide requirements. The real EventDialog Roll button and PlayerCommand
  path carried loaded event/check context for both an event-level skill check
  and a choice-owned check. The exact actor, task, purpose, originating event
  and check, item copy, effect, and backpack location survived into the closed
  `event_resolved.check_result`. Each enabled control executed one ordinary
  d20; an unloaded or ambiguous source executed none. A same-ability unrelated
  task, unknown purpose, different or missing tool, and another actor received
  no benefit. Removing one exact copy left the other copy eligible; removing
  both did not remove the Field Guide source. A no-tool context and an
  undeclared legacy check retained ordinary modifiers/DCs and consequences.
  Copied event/check/consequence fields did not replace loaded records. The
  selected check host charges no action/resource cost; each loaded outcome
  applied its authored gold consequence once. This checks only the loaded
  EventDialog host and its explicit task/purpose/tool/source fields. Local-room
  checks, sensory requirements, save purposes, post-roll choices, broader
  free-text interpretation and catalog-wide support remain open; V-003 remains
  partial. [Focused production scenario with bootstrap/parse/boot gates,
  37 assertions](../../.artifacts/tests/cb2fd72d5f044643a138bd11ad15f6e7);
  [focused development checks, 18/0](../../.artifacts/tests/e4b85fd4e79b45f59da411597d342ba5).

<a id="vs-25"></a>

- [x] **VS-25 — Optional post-roll ability-check bonus in the loaded EventDialog
  (`V-014`, payment-policy slice of `V-035`).** Production DataLoader loaded
  neutral fixed +5/cost1 and renamed d8/cost2 sources, plus ability-only fixed
  +4 and d6 alternatives. Real `BtnRoll`, native Inspiration confirmation,
  source PopupMenu and Close controls proved one original d20, captured natural,
  modifier, DC and context, no reroll for a fixed bonus, and exactly one die
  only after an accepted die choice. Converted success and remaining failure
  obeyed both pay-on-choice and pay-on-converted-success; upfront affordability
  blocked an underfunded source. The selected and unselected pools were checked
  around answers. Query, decline, empty, stale/depleted, removed, forged and
  replayed answers did not roll or spend; completed accepted-request replay was
  checked against dice, both pools, gold and receipt snapshots. A loaded
  choice-owned ability-only check used its real choice button, Roll, source menu
  and Close with one exact cost and one consequence. Pending consequences waited for the
  final result and Close carried the same receipt as the settled check. An
  underfunded source was unavailable under each payment policy. Native
  Inspiration was spent once and remained in the total before the optional
  bonus. Same-actor and other-actor re-popup and freeing a pending host canceled
  only that host's request; a newer/replacement chooser remained answerable.
  This certifies only the loaded EventDialog skill-check/choice-check host,
  including explicit ability-only checks. Death Saves, concentration,
  local-room and other check hosts, natural/test rerolls, other outcome edits
  and broader payment policies remain open; V-014/035 stay partial. [Focused
  production scenario with bootstrap/parse/boot gates, 69 assertions](../../.artifacts/tests/136995fdd7b64e9d884b127a223518c5).

<a id="vs-26"></a>

- [x] **VS-26 — Mandatory-new natural/test reroll in loaded EventDialog
  (`V-089` bounded subset).** Loaded neutral natural-only/keep and renamed
  whole-test/reroll sources use one implementation and share the post-roll menu
  with eligible numeric bonuses. Real choice, Roll, source menu, native
  Inspiration confirmation and Close controls proved failure-to-success and
  success-to-failure, keeping the new result even when worse. Normal,
  Advantage and Disadvantage preserve their declared replacement mode; the
  latter two emit one aggregate test containing two d20 faces. Original/new
  raw natural, bonus dice, DC/context, mode and floor stages remain explicit.
  A deliberately sub-floor replacement applies the captured floor before
  native Inspiration; rerolled native faces, scalar fields and visible total
  agree, with the original receipt and one prior native payment preserved.
  An accepted negative/no-floor reroll stays below zero. Natural-only retains
  nonrerolled bonus dice. One selected exact-source cost and one consequence
  settle, with no second modifier menu. Query, decline, underfunded,
  emptied/removed/stale, forged, unoffered and replayed answers cannot spend
  or roll replacement dice; completed replay preserves dice, both pools, gold
  and closed receipt. Host re-popup/teardown cancels only its own request.
  This accepts the represented loaded event/choice ability-check host only;
  weapon/save/other check hosts, automatic/no-roll results, old/new selection
  and further modifier passes remain open. V-089 stays partial. [Final actual
  controls, 107 assertions and direct Godot exit 0](../../.artifacts/tests/a74c2363968243108dacc86f68a9ff5b/check_context_flow_final);
  [bootstrap, 185-script parse and boot gates](../../.artifacts/tests/a74c2363968243108dacc86f68a9ff5b).

Combined VS-24–26 review closed loaded-record authority, independent no-tool
context, stale-host awaits, pure reroll preflight, floor/native-bonus ordering,
negative/no-floor arithmetic and result-presentation findings. Required actual
controls and clean current-source evidence are retained above. All broader
V-series parents retain their uncovered boundaries.

<a id="vs-27"></a>

- [x] **VS-27 — Nested typed shared fact predicates with missing-safe evaluation
  (`S-024`, bounded `V-001`).** Current-source review matched the retained BUILD
  and separate production validation. `SharedStepExecutor` supports nested
  `all`/`any`/`not` and one strict typed comparison against the existing fact
  allowlist. Missing values remain unknown through `not`; `all` and `any`
  preserve three-valued outcomes, so an unknown branch cannot grant eligibility
  by itself. Numeric zero, false and unavailable facts remain distinct.
  Malformed/unknown facts and wrong types fail definition validation before
  mutation. Loaded neutral and renamed spell fixtures exercise this through the
  real CombatHUD spell picker, cast command, target click and ordered
  step/effect settlement. The 11-assertion production scenario confirms live HP
  and source-owner changes, exact one-slot/Magic-action costs, effect receipts,
  pool/timed-modifier query purity, and menu/command refusal before cost or
  effect. This proves only ordered shared-spell step/effect eligibility in that
  combat host; broader bindings, other hosts and V-001 remain open. The known
  integral-JSON-number scalar-healing parser mismatch was reproduced and fixed
  during batch review; numeric-input regressions now protect this boundary. [Production
  scenario and required gates](../../.artifacts/tests/0a100c3d32f940e0963733ee0068fb4f);
  [focused development checks, 1008/0](../../.artifacts/tests/518f20b7b66f4fac89e05da449f01a91).

<a id="vs-28"></a>

- [x] **VS-28 — Actor/action/item/source fact bindings (`S-025`, bounded
  `V-001`).** The separate production route passes loaded neutral and renamed
  shared-spell definitions through the CombatHUD picker, target click, real
  Portent chooser and resumed resolution. It checks caster and target IDs,
  action kind/invocation, spell definition/invocation, source definition/owner/
  instance, and two exact same-definition consumed material copies. Each cast
  spends one slot and Magic Action, consumes only its captured copy and retains
  its own generated source receipt. Focused checks cover missing/wrong-kind
  identities, caller metadata spoofing, distinct source/copy IDs and a resumed
  call whose substituted caller actor/target cannot replace the captured host.
  This accepts the combat shared-spell host only; direct resolution lacks
  action/invocation/item-copy bindings, and broader V-001 remains open.
  [Actual-control scenario and gates](../../.artifacts/tests/8aba2a55df174f94ac708b5f2741b3f5);
  [focused spells logic, 1017/0](../../.artifacts/tests/ff3da86e36e14e0880de43264b33d92e).

<a id="vs-29"></a>

- [x] **VS-29 — Declared Advantage/Disadvantage policy (`S-091`, bounded
  `V-012`).** Loaded EventDialog event- and choice-owned ability checks apply
  authored Advantage/Disadvantage before the original d20. Duplicate grants of
  one mode retain separate source-instance provenance but use one two-face test;
  surviving opposite modes use the ordinary engine cancellation to one d20.
  Exact-context cancellation/prohibition suppresses only nonexempt contributions,
  recording both grant and policy sources. Pure eligibility reads do not roll or
  spend, and the actual Roll commitment rereads live sources, so removing a
  queried source returns the roll to Normal. The real loaded route retained the
  effective mode, exact contributors, natural result and closed receipt; a
  nonqualifying same-skill task remained Normal. Neutral and renamed definitions
  selected different modes/context without ID branches. Focused development
  covered duplicate/opposite/exempt/nonmatching cases and query purity. Existing
  S-105 mode provenance and pre-roll Portent natural replacement remained
  distinct: replacement reports `replaced` and does not rewrite the original
  mode. This accepts only the represented EventDialog ability-check route;
  attacks, saves, other hosts and broader V-012/S-106 remain open. [Direct
  actual-control run and required gates](../../.artifacts/tests/s091-check-context-direct);
  [runner token-replacement scenario](../../.artifacts/tests/e7aa7b8b9d2e46fa87bd9cf7d17a2a7b);
  [focused logic checks, 76/0](../../.artifacts/tests/70b543eec7d9482c8e07fe69dc743dee).

<a id="vs-30"></a>

- [x] **VS-30 — Explicit attack/save outcome overrides (`S-092`, bounded
  `V-013`).** Neutral cost-1 and renamed cost-2 source-owned definitions passed
  the real normal player Attack, single-target shared-spell attack, and rolled
  Character-target shared-spell save controls. Both hit/miss and save
  success/failure directions were selected. Natural 1/20, critical suppression
  on a forced natural-20 miss, unchanged numeric roll facts, exact source and
  payment receipts, stale/wrong-source refusals, once-only costs, and suspended
  ordered damage continuation were checked. Original action/slot cost and earlier
  ordered results settled once. The combat receipt retained the separate outcome
  and source provenance; the natural 1/20 remained numeric facts. Automatic/no-roll
  outcomes, canceled Death Saves, other save/attack hosts, cross-actor intervention,
  token replacement and catalog-wide support remain open; V-013 is partial.
  [Actual-control scenarios and required gates](../../.artifacts/planning/vocabulary-reports/S-092-validation.md);
  [focused spells logic, 1,033/0](../../.artifacts/tests/995db1031b034800bcda7c69ed3c6129).

  The later review repaired native-use ordering and rejects same-source,
  same-domain numeric/die/outcome conflicts in either declaration order. Actual
  weapon and spell forced-miss controls preserve unused Peerless Aim, while
  source cost and final consequences settle once. Acceptance is restored.
  [Full logic 3,332/0 and five actual-control scenarios with required gates](../../.artifacts/tests/bf854bf713dc498ab789ec6bb1a6cfe0).

<a id="vs-31"></a>

- [x] **VS-31 — Authored shared-spell attack window context (`S-041`, bounded
  `V-010`).** The real attack and damage owners emit exact occurrence/kind,
  actor/target, action/spell/source bindings and the five ordered windows:
  before-roll, after-natural, provisional outcome, pre-damage and post-damage.
  Each exposes only its available facts. Authored ordered attack effects and
  following riders now consume the current child receipt through the parent
  adapter, including after actual attack and Empowered damage choices. A fresh
  missed occurrence cannot reuse an earlier damage window; another recipient
  cannot inherit its facts. Save and standalone damage steps clear the attack
  context. Costs, earlier steps and effects settle once; stale/wrong-host/source
  answers refuse through the existing owners. This accepts single-target shared
  spell attacks and ordered attack steps only, with the existing primary damage
  component's raw/resolved/HP-loss fields. Other hosts, general subscriptions,
  cast/source-end windows and wider damage measures remain open. The same
  review repaired integral numeric healing/Temporary HP without changing dice,
  dictionary formulas or fractional refusal.
  [Independent review and fixes](https://github.com/brandonbrown215bb-boop/DND-Sandbox-Engine/blob/d823423d979f7c566d7511801bd560f5dafb95ee/docs/reviews/slice-acceptance-2026-10-14.md);
  [full logic and actual-control evidence](../../.artifacts/tests/bf854bf713dc498ab789ec6bb1a6cfe0).

<a id="vs-32"></a>

- [x] **VS-32 — Owned post-roll attack-total subtraction and local defending-AC
  adjustment (`S-095`, bounded `V-014`).** Loaded neutral amount-6/cost-1
  subtraction and renamed AC+2/cost-2 sources use the actual normal weapon
  Attack and interactive single-target flat/ordered shared-spell choosers.
  Final misses prevent damage; final hits settle damage after selection.
  The exact attacker/source/feature/pool/domain receipt preserves original
  natural, modifier, total, profile and AC alongside the final comparison.
  Defender AC stays unchanged. Pay-on-choice charges once; conditional payment
  charges only a final hit. Decline and removed/depleted sources finish the
  captured attack without adjustment payment. Wrong actor/window, stale answer
  and replay refuse; eleven attack occurrences roll eleven d20s, and each cast
  pays one slot. Natural 1/20 do not offer adjustments. Ordered prior results
  settle once and the receipt survives a following actual Empowered damage
  choice. A converted shared-spell miss retains its receipt in the pre-damage
  window. Review confirms miss exits precede next-hit grant consumption and
  damage-side resource use; no new runtime repair was required. Other hosts,
  cross-actor intervention, no-roll outcomes and Death Saves remain open.
  [Separate validation](../../.artifacts/planning/vocabulary-reports/S-095-validation.md);
  [actual controls and required gates](../../.artifacts/tests/e91a49d53fde44b78c95abc6ed5e21b6);
  [focused spells logic, 1,055/0](../../.artifacts/tests/39c9271a2365442fb58681279caeb6e8).

<a id="vs-33"></a>

- [x] **VS-33 — Exact prior-result identities and additional measures
  (`S-034`, bounded `V-006`).** Fresh-chat review reconciled the retained
  separate production validation before dependent S-043 BUILD. Loaded neutral
  and renamed ordered spells select the exact runtime target, step and typed
  component; repeated component types require an ID. Receipts distinguish raw,
  resolved, prevented, absorbed, HP loss and actual capped healing. Same-type
  actors remain separate, missing/malformed/future/wrong-step references refuse,
  and a settled receipt survives a later roll choice and live HP/source changes.
  Production validation used the real HUD picker and area target control and
  observed one slot/action per cast; the focused spells logic passed 1,064/0.
  `result_sum` remains the VS-17 raw/resolved/HP-loss sum. Cast-target selectors
  and malformed/unavailable cases are covered by focused checks; the real
  control exercised `target: same`. This accepts only the loaded ordered
  shared-spell boundary; broader hosts and reducers remain open.
  [Acceptance reconciliation](../../.artifacts/planning/vocabulary-reports/S-034-acceptance-review.md);
  [separate validation](../../.artifacts/planning/vocabulary-reports/S-034-validation.md);
  [retained production run](../../.artifacts/tests/bc96a70df880495695952b3b803bb8b9).

  [Batch C review](../../.artifacts/planning/vocabulary-reports/batch-C-review.md)
  retains VS-33 after repairing single-entry list component identities. Explicit
  IDs and type ordinals now survive mapped damage into later authored consumers;
  scalar step-derived identities are unchanged.

<a id="vs-34"></a>

- [x] **VS-34 — Numeric margin and settled-HP gates (`S-043`, bounded
  `V-011`).** Loaded neutral failed-save margin and renamed ordered HP-after-
  damage consumers use signed numeric margin and the exact HP snapshot at the
  selected completed settlement. Actual picker/save/target controls verified
  below/equal/above thresholds, S-092 forced outcomes with retained rolled
  margin, no-roll margin unavailability, and a later Empowered damage choice
  that pauses aftermath until settlement. HP probes distinguish the captured
  post-damage value from pre-damage HP, temporary-HP absorption, overkill,
  later healing/unrelated damage, a settled zero-damage receipt and missing or
  malformed/future selectors. Costs and ordered aftermath settle once.
  S-095 adjusted attack total/AC compatibility assertions passed; its recheck
  runner had an unrelated post-scenario monster-AI engine error, documented in
  the validation report. Only these loaded ordered shared-spell hosts are
  accepted; grouped gates and wider V-011 remain open.
  [Separate validation](../../.artifacts/planning/vocabulary-reports/S-043-validation.md);
  [production and focused evidence](../../.artifacts/tests/41ae6ec7c22a45ee88af9e499e2c4bf0).

  Batch C retains VS-34. Its combined real-control regression reads the selected
  mapped component only after that target's HP/margin gate qualifies. The clean
  later S-095 control run is retained in the Batch C report.

<a id="vs-35"></a>

- [x] **VS-35 — Independent save/miss damage and riders (`S-098`, bounded
  `V-015`).** Actual flat and ordered shared-spell attack/save controls used
  independent complete damage-scale and rider maps. A post-roll AC choice
  changed provisional hit to final miss without changing the roll; odd half
  damage retained the miss, then Resistance and Temporary HP settled in order
  with no hit-only rider. Flat and ordered two-target saves produced distinct
  success/failure damage, condition and HP results, and ordered continuation
  survived a following damage choice/step without early or duplicate effects
  or costs. Malformed maps refused before cast payment. Adjustment query,
  decline, wrong-owner/window, stale and replay behavior passed its actual
  control. Only loaded flat/ordered shared-spell attack/save routes are
  accepted; other hosts, standalone damage/effect steps and S-099 Evasion or
  recipient exemptions remain open.
  [Separate validation](../../.artifacts/planning/vocabulary-reports/S-098-validation.md);
  [actual controls and focused checks](../../.artifacts/tests/b0903136f9434f71bc1a18f37082547f).

  Batch C retains VS-35 after rejecting maps without an owning attack/save host
  before payment and repairing Uncanny Dodge's composition with zero/half hit
  scales. Focused spells passed 1,091/0 and the affected actual controls passed;
  the report distinguishes a repaired fixture initiative race from clean cases.

<a id="vs-36"></a>

- [x] **VS-36 — Ally/enemy/willingness and exact-giver relations (`S-026`, bounded
  `V-002`).** Actual Character Sheet choices for Unknown, Unwilling and Willing
  were consumed by loaded neutral/renamed shared-spell definitions through the
  CombatHUD picker and target click. Unknown stayed unavailable beneath `not`;
  represented ally and enemy cases selected distinct effects. Two givers' same-kind
  source records remained independent, and removing one exact source changed only
  its own query and consumer. Missing/ambiguous relationship membership returned
  unavailable at the production fact reader; no such membership is selectable as a
  combat target in the current UI. Save/load recovered willingness in a fresh process,
  and malformed values were refused before live-state replacement. The renamed mark
  consumer uses a generic exact source-owned record; native Hunter's Mark is not
  certified as a per-target source. General factions, social AI, free-text consent and
  broader V-002 remain open. [Separate validation](../../.artifacts/planning/vocabulary-reports/S-026-validation.md);
  [actual controls and gates](../../.artifacts/tests/0d5e70835a3d452f865c05e32d30a079).

<a id="vs-37"></a>

- [x] **VS-37 — Live located distance predicates (`S-027`, bounded `V-002`).**
  Loaded neutral actor-relative and renamed source-relative consumers execute
  through the real combat spell picker/target route. Axial center distance is
  measured in feet at 5 per hex, including exact 10-foot equality. Moving the
  actual target or exact placed zone changes eligibility; removing the zone is
  unavailable. Two same-definition actors/sources retain distinct endpoints.
  An existing save-choice pause proves subsequent predicates use live caster
  position, while settled effects remain once-only. Copied/removed actors cannot
  borrow old combat/room positions. Room lookup requires the current active
  party Character and has focused owner checks, not new room UI acceptance.
  The located-source fixture binds an existing zone through the internal cast
  adapter; arbitrary source selection, auras, elevation/path/footprint distance,
  movement and LOS operations remain open.
  [Independent review](../../.artifacts/planning/vocabulary-reports/batch-D-review.md);
  [actor/source controls](../../.artifacts/tests/0dbbdd7308fa4fb19050d062172eff2d/shared_distance_predicate_flow.stdout.log);
  [paused live-range controls](../../.artifacts/tests/b40c4f5c2e8642a0a436c67d7a132c0b/s029_save_context_flow.stdout.log).

<a id="vs-38"></a>

- [x] **VS-38 — Required senses and causal save context (`S-029`, bounded
  `V-003`).** Loaded flat and ordered shared-spell saves retain authored
  cause/purpose/origin-effect and canonical definition/owner/invocation/step
  receipts. Owned failed-save bonuses match ability plus authored cause/purpose
  and optional represented see/darkvision. Otherwise identical avoid/end,
  maintain and ordinary CON controls remain distinct; unknown hearing is
  unavailable. Darkvision requires usable sight as well as range. The real
  chooser rechecks live saving-actor position/grid against captured cast origin;
  changed sense/source, wrong owner, same-ID replacement and replay cannot pay
  for a different occurrence. Actual ordered controls retain one prelude,
  original save/DC and cast cost, settle accepted recovery once, and apply the
  original 5 damage once when lost sight forces decline. No new durable state.
  EventDialog sensory additions, other roll hosts, Death Saves/concentration
  choices, general perception and free-text inference remain open.
  [Independent review](../../.artifacts/planning/vocabulary-reports/batch-D-review.md);
  [final controls and focused 1131/0 checks](../../.artifacts/tests/b40c4f5c2e8642a0a436c67d7a132c0b).

<a id="vs-39"></a>

- [x] **VS-39 — Round and actor action history (`S-030`, bounded `V-004`).**
  Shared combat predicates distinguish first round, an actor's active first own
  turn, committed action and attacked-target history since combat-turn/owner-turn
  starts. Owner-turn facts are unavailable before that subject has a boundary,
  including under negation. Late round-two participants retain their own first
  turn. Cancel/refusal/query do not fabricate events; resolved misses count as
  attacks. Same-turn resume is idempotent; fresh encounters reset transient state.
  Actual loaded consumers retain exact recipients and once-only costs/effects.
  Narrow monster weapon controls additionally verify refused targets, off-turn
  hit/miss and recording after execution rather than AI intent. Other native
  commands/attack hosts and durable action history remain open. No new rider-lock
  or source-pool policy. [Final controls and gates](../../.artifacts/tests/f6c4e731558b41bcbf8a8e032836022f);
  [independent review](../../.artifacts/planning/vocabulary-reports/batch-E-review.md).

<a id="vs-40"></a>

- [x] **VS-40 — Exact-source damage history (`S-031`, bounded `V-004/006/057`).**
  Settled Character damage retains exact recipient, causal actor/source and raw,
  prevented, ward-plus-THP absorbed, pre-THP resolved and capped HP-loss measures.
  Combat-turn and target owner-turn baselines reset on actual starts. Bounded
  last-minute history keeps at most 128 source/second buckets, expires at age 60
  and survives allowed checkpoints with its absolute clock and identities.
  Direct casts allocate distinct sources; paused completion and replay cannot
  duplicate settlement. Loaded neutral/renamed controls, immunity/overkill and
  source/target isolation pass. Two fresh processes and production clock advances
  verify recovery, 59/60 equality, large jumps and malformed source/quantity/time
  refusal before live replacement. Dictionary-only/unattributed damage,
  arbitrary source/interval selectors and broader durable state remain open.
  [Recovery](../../.artifacts/tests/s031-damage-history-relaunch-a4de2f85c31a4bcc955ba0e3352b141c);
  [independent review](../../.artifacts/planning/vocabulary-reports/batch-E-review.md).

<a id="vs-41"></a>

- [x] **VS-41 — Explicit settled-result sum/min/max (`S-035`, bounded `V-006`).**
  Earlier settled attack/save/damage steps select exact runtime targets and
  typed component IDs once. Sum's empty policy is zero; empty min/max and
  missing/malformed/unfinished inputs are unavailable. Explicit misses without
  damage components are known empty selections; actual component zero is a
  value. Forward/ambiguous selections refuse before ordinary costs. Neutral and
  renamed actual casts produce different sum/min/max aftermath; the added real
  area cast selects two same-definition goblins and repeated fire components,
  excluding 19-point packets. Selected sum 11 rounds once to healing 5, min adds
  healing 2 and max grants 5 THP. Empowered suspension retains finalized input
  and once-only history/cost/aftermath through replay refusal. Existing VS-17 sum
  and VS-33 component absorption semantics remain. General collections remain open; grouped all/any/count is accepted separately
  as VS-42 below. [1158/0 logic and passing reducer cases](../../.artifacts/tests/bac96b5e3bfe4657a5778535730d0143)
  (combined runner's old action fixture failed, then passed separately above);
  [independent review](../../.artifacts/planning/vocabulary-reports/batch-E-review.md).

<a id="vs-42"></a>

- [x] **VS-42 — Completed all/any/count child groups (`S-044`, bounded `V-011`).**
  Ordered combat shared spells select explicit earlier attack/save steps and
  exact all/same/cast targets. Every selected step completes before any/count
  can pass; final flags include supported overrides. Repeated attempts and
  same-definition actors remain distinct. Empty and skipped policies are explicit;
  missing/unfinished/wrong-target groups remain unknown under negation. Actual
  loaded save controls prove count below/at/above, mixed all/any and skipped/empty
  policies; actual attack/Empowered controls prove suspension, final override,
  once-only costs/riders and stale/replay/teardown refusal. No durable fields or
  arbitrary action composition. [Independent acceptance and retained evidence](../../.artifacts/planning/vocabulary-reports/S-044-acceptance-review.md).

<a id="vs-43"></a>

- [x] **VS-43 — Source die/number formula inputs and timing (`S-036`, bounded `V-007`).**
  Exact transient cast inputs bind loaded integer bounds, owner/spell/invocation
  and captured/live actor parameters. Every number choice precedes parameter
  capture regardless of declaration order; review reproduced and repaired this
  timing defect. Actual lower/upper choices heal 2/4, captured WIS stays +1 and
  live WIS becomes +4 through Empowered damage; cancel/old answers/caller
  substitution cannot spend or supply a new input. The actual source-die attack
  consumer retains exact face 7/source/owner after removal, heals 14 once, refuses
  revalidated THP and repeats queries without RNG/payment. Save receipt code and
  existing bonus controls were inspected; no separate actual save-to-formula
  consumer is certified. No transferable dice inventory, new durable fields,
  progression tables or broad formula hosts. [Independent acceptance, repair and evidence](../../.artifacts/planning/vocabulary-reports/S-036-acceptance-review.md);
  [final numeric controls/gates](../../.artifacts/tests/917d53e5fbe8475daadd3063d94d888f).

<a id="vs-44"></a>

- [x] **VS-44 — Represented class levels and progression tables (`S-037`, bounded `V-007`).**
  Optional saved class allocations distinguish each known owned class from total
  level, proficiency and selected slot. Absent class is zero; malformed allocation
  is unavailable and invalid saves refuse before live replacement. Declared bounded
  numeric/die-size rows validate thresholds, supported dice and below-first policy.
  Actual feature/quantity/command controls roll two independent source dice;
  capacity growth preserves current, shrink clamps and neither refills nor resets
  activation serial. Actual spell controls retain captured rows5/7 while live
  rows become9/11 through later Empowered selection. Review repaired unavailable
  live-only inputs spending a slot/action; preparation now preflights every
  parameter before costs without capturing live values. Final actual class-table
  and numeric controls/gates pass; distinct fresh processes retain allocation and
  two spent pools, and five malformed full saves refuse. Primary restore is bounded;
  native leveling refuses explicit allocations. No full native multiclass grants/
  slots, leveling UI, transferable dice or broad formula hosts.
  [Independent Batch F review](../../.artifacts/planning/vocabulary-reports/batch-F-review.md);
  [final controls/gates](../../.artifacts/tests/cba950a9a99b41b6b80be713053392e0);
  [fresh-process recovery](../../.artifacts/tests/s037-class-levels-relaunch-9f300cfab84d4205a79debbc85ac3991).

<a id="vs-45"></a>

- [x] **VS-45 — Authored natural-d20 and final-total floors (`S-038`, bounded `V-008`).**
  Loaded EventDialog ability checks capture actor-formula thresholds and exact
  owner/definition/instance/effect provenance before RNG. Raw/effective natural,
  modifiers/bonus dice, native floor stage, pre-floor subtotal, authored uplift and
  final total remain distinct. Actual controls cover below/equal/above, natural1/20,
  signed modifiers, no-floor negative totals, Advantage/Disadvantage, independent
  sources and source removal. Mandatory-new rerolls retain captured thresholds
  and original receipts after source/stat changes without duplicate RNG/payment.
  This domain compares total/DC; attack/save floors, critical/outcome overrides
  and chosen old/new rerolls remain outside it. No new durable state.
  [Independent Batch G review](../../.artifacts/planning/vocabulary-reports/batch-G-review.md);
  [36-assertion actual floor controls/gates](../../.artifacts/tests/fea394f5f346441597ea5f630aaceb17).

<a id="vs-46"></a>

- [x] **VS-46 — Legal AC alternatives and permanent-preserving scores (`S-039`, bounded `V-009`).**
  Typed self-targeted numeric-pool feature protections compare eligible authored
  base AC with equipment/native AC by maximum, include a legal shield once and
  apply compatible additions afterward. Fixed set/floor/cap/add score operations
  project over permanent fields. Actual feature/equipment and monster weapon
  controls distinguish selected AC19/17 at attack total18, unknown equipment,
  removal/expiry and original source costs/clocks. Permanent fixed increases stay
  beneath a temporary setting. Review repaired temporary CON becoming permanent
  level-up HP and temporary scores changing Epic Boon eligibility/options; seeded
  progression and actual boon-panel regressions pass. Fresh-process saves retain
  permanent scores, grants and spent pools; malformed saves refuse before mutation.
  No item/aura grant host, form AC or temporary-CON HP adjustment is certified.
  [Independent review/repairs](../../.artifacts/planning/vocabulary-reports/batch-G-review.md);
  [40-assertion final protection controls/gates](../../.artifacts/tests/4e2b7113085e4e949bc68efb7698fbfe).

<a id="vs-47"></a>

- [x] **VS-47 — Exact recipient choice among overlapping protections (`S-040`, bounded `V-009`).**
  Declared stack/exclusive groups preserve exact equal-value grants and exclude
  incompatible benefits across definition IDs. Actual recipient popup chooses an
  exact still-owned grant for free. Equipment suppression retains preference;
  selected removal/expiry clears it and falls back to an original eligible source
  without acquisition, deadline restart or refill. Wrong actor, recipient/source
  loss, decline, mutated request, old generation, replay and teardown cannot change
  newer selection. Lasting selection/grants/four spent pools survive distinct
  fresh processes; pending menus do not. Fourteen malformed full-save cases reject
  before live replacement. Cross-actor auras and THP replacement remain open.
  [Independent review and final controls](../../.artifacts/planning/vocabulary-reports/batch-G-review.md);
  [retained fresh recovery](../../.artifacts/tests/batch-g-relaunch-4dcebe341d684e689b305385bbdd45d4).

<a id="vs-48"></a>

- [x] **VS-48 — Declared old/new EventDialog rerolls (`S-106`, bounded `V-089/V-012`).**
  Actual loaded event/check controls choose old/new for better/worse replacements,
  or retain mandatory-new policy. New-test mode and actor-formula bonus capture
  before payment; full original/replacement receipts retain floor stages, ordinary
  modifiers and bonus-dice policy. Cancel after dice retains old after one paid
  replacement. Source loss before purchase settles the original without an invalid
  keep menu, extra RNG or another consequence. Re-popup/teardown tracks the correct
  pending decision. No new durable state or another actor's intervention.
  [Independent review/repairs](../../.artifacts/planning/vocabulary-reports/batch-H-review.md);
  [final review controls and gates](../../.artifacts/tests/f8b8c3ab7e1b4f8e95566d47d68f106f).

<a id="vs-49"></a>

- [x] **VS-49 — Weapon and shared-spell reroll consumers (`S-225`, bounded `V-089/V-012/V-014`).**
  Actual normal Attack/Extra Attack, flat/ordered shared attacks and flat/ordered
  shared saves consume the common captured-test operation. Original AC/DC, fixed
  bonuses, signed Bless/Bane/Blade Ward dice, pre-roll token facts and weapon
  critical range survive. Final kept natural controls critical/damage/next-hit
  aftermath; visible bonus-die receipts use the kept faces. Paid keep stages
  retain canonical kind/actor/host/current-request ownership through continuation.
  Real shared-save old/new popups, wrong-kind answers and completed replay checks
  supplement mandatory-new save controls. Earlier swings/steps, following damage
  choice and original action/slot/native/source payments settle once. Off-turn,
  exploration, Death Save and concentration choice hosts remain outside this row.
  [Review and exact commands](../../.artifacts/planning/vocabulary-reports/batch-H-review.md);
  [47 review + 41 weapon + 54 shared-attack + 31 map assertions](../../.artifacts/tests/f8b8c3ab7e1b4f8e95566d47d68f106f).

<a id="vs-50"></a>

- [x] **VS-50 — Recipient damage maps and chosen exemptions (`S-099`, bounded `V-015`).**
  Character-owned success/failure maps match exact shared-save ability/cause/
  purpose/origin; native Evasion retains priority. Flat shared spells' actual
  caster popup selects bounded live area recipients. Authority belongs to the
  exact cast/invocation and recipient objects; forged decisions, copied IDs,
  replaced recipients, source loss, duplicate selections and another invocation
  grant no exemption. Same-definition targets retain independent save/damage/
  rider outcomes. Scaling floors before Resistance/THP; chosen zero damage leaves
  the original save and independent rider mapping intact. Decline spends only
  the original cast. No aura, universal Evasion, monster map catalog or ordered-
  step exemption declaration is certified; new choice state stays transient.
  [Independent review](../../.artifacts/planning/vocabulary-reports/batch-H-review.md);
  [final production controls](../../.artifacts/tests/f8b8c3ab7e1b4f8e95566d47d68f106f).

<a id="vs-51"></a>

- [x] **VS-51 — Final-result payment predicates (`S-100`, bounded `V-035`).**
  Selected exact numeric-pool sources reserve without pre-spending, require upfront
  funds, commit on declared final success/failure and refund mismatches/cancel.
  Real save chooser controls verify one-use/two-use costs, both matches and
  mismatches, captured roll/DC, independent pools and once-only original slot.
  Source loss/recreation, replay and teardown leave no charge or hidden lock.
  Shared attack paid flags match actual receipt/pool settlement. Reroll-specific
  payment predicates, cross-actor budgets and other roll hosts remain open.
  [Review and evidence](../../.artifacts/planning/vocabulary-reports/batch-I-review.md).

<a id="vs-52"></a>

- [x] **VS-52 — Component and whole-occurrence reductions (`S-109`, bounded `V-016`).**
  Fixed integers/actor-only formulas reduce scaled typed damage before mitigation.
  Exact component IDs survive flat/ordered attack/save/automatic-damage adapters;
  occurrence allocation follows authored component order, floors at zero and
  discards overflow. Raw/prevented/resolved/THP-absorbed/HP-loss stay distinct.
  Initially unavailable formulas refuse before slots/actions/RNG; canonical pending
  Empowered requests settle once and refuse wrong occurrence/stale/replay/teardown.
  Optional paid prevention and other damage hosts remain open.
  [Review and limits](../../.artifacts/planning/vocabulary-reports/batch-I-review.md).

<a id="vs-53"></a>

- [x] **VS-53 — Scoped mitigation bypass (`S-110`, bounded `V-016`).**
  Exact component/occurrence declarations independently select resistance,
  immunity, ward and the narrow Sphere prevention gate. Other layers, sibling
  components, later sources and THP retain normal settlement. Actual casting
  controls honor the damage-only typed-component save definition through either
  caster/target Sphere; ordinary spells remain blocked without costs. Pending
  Empowered policy remains canonical against forged display policy/new occurrences.
  Flat/other prevention, general monster/world damage and paid bypass remain open.
  [Independent review](../../.artifacts/planning/vocabulary-reports/batch-I-review.md).

<a id="vs-54"></a>

- [x] **VS-54 — Own-turn, round and first-round rider limits (`S-056`, bounded `V-041`, `V-004`).**
  Numeric-pool weapon-hit riders independently declare own-turn/first-round
  eligibility and once-per-round limits. Actual initiative supplies the round;
  extra turns and refreshed action budgets do not unlock an already used option.
  Real Attack/hex and off-turn controls preserve exact actor/source/option
  ownership, original Action and pool quantities. Renamed d6 data changes the
  own-turn policy. Other action hosts and general subscriptions remain open.
  [Independent review and production controls](../../.artifacts/planning/vocabulary-reports/batch-J-review.md).

<a id="vs-55"></a>

- [x] **VS-55 — Actual-roll and active-grant rider limits (`S-057`, bounded `V-041`).**
  Weapon riders bind actual actor/target objects and settled roll identity with
  captured weapon/critical profile. Independent exact sources retain separate
  allowances. Once-per-active-instance consumption belongs to the source's timed
  AC grant; used options survive allowed fresh-process checkpoints with the
  original grant/deadline and spent pool. Eight malformed full saves refuse
  before session replacement. Completed hits, including ineligible hits, cannot
  consume later grants through replay; new grants require new hits. Other roll
  hosts and active-effect carriers remain open.
  [Review, repair and retained recovery evidence](../../.artifacts/planning/vocabulary-reports/batch-J-review.md).

<a id="vs-56"></a>

- [x] **VS-56 — Exact-source conditional rider payment waiver (`S-058`, bounded `V-042`).**
  An owned active timed AC grant can waive its numeric rider's one-use payment
  for the declared ordinary weapon or Opportunity Attack parent. Actual controls
  work with an empty owned pool, preserve original Action/Reaction and activation
  payment, and still consume the option lock. Renamed data changes parent and die;
  sibling grants cannot waive another source. Payment substitutions, free dice
  inventory and other budgets/hosts remain open.
  [Independent review and receipts](../../.artifacts/planning/vocabulary-reports/batch-J-review.md).

<a id="vs-57"></a>

- [x] **VS-57 — Filtered progression choice acquisition (`S-045`, bounded `V-025`).**
  Real ClassTraining selectors acquire the declared count with level, represented
  class, typed stable actor facts, prerequisites and duplicate/repeatable rules.
  Pending dependent menus refresh; invalid or replayed choices grant nothing.
  Loader refuses malformed count/pick/level values and unsupported fact contexts.
  Neutral and renamed actual controls plus saved predicate/class eligibility
  and fresh-process multi-pick spell recovery pass.
  [Repairs, review and evidence](../../.artifacts/planning/vocabulary-reports/batch-K-repairs.md).

<a id="vs-58"></a>

- [x] **VS-58 — Safe opt-in progression replacement (`S-046`, bounded `V-025/V-027`).**
  Proposed selections validate explicit prerequisites and existing trained spell
  capacity/list dependencies before mutation. Cantrip versus leveled expansions
  and earned primary features stay distinct. Existing represented independent
  class/race/permanent/creation/skill/Fighter/active-option sources retain grants.
  Actual renamed/stale/replayed controls and eight malformed full-save refusal
  cases pass. General item/cast carriers, mode boundaries and full native
  multiclass acquisition remain open.
  [Repairs, review and evidence](../../.artifacts/planning/vocabulary-reports/batch-K-repairs.md).

<a id="vs-59"></a>

- [x] **VS-59 — Exact item/cast/progression carriers (`S-049`, bounded `V-027/V-057`).**
  The same fixed additive AC/walking-speed payload projects from exact equipped
  copies, passive progression entitlements/selected occurrences and timed flat
  automatic self-casts. Independent identical definitions retain separate source
  receipts; stow, replacement, destruction, expiry and concentration cleanup end
  only the applicable source. Derived stats do not become permanent bonuses.
  Fresh-process checkpoints retain original identities, payloads, spent slots and
  remaining time; both player and party DTOs refuse malformed carriers, including
  concentration pointing at an ordinary sibling cast, before session replacement.
  [Independent review, repairs and evidence](../../.artifacts/planning/vocabulary-reports/batch-L-review.md).

<a id="vs-60"></a>

- [x] **VS-60 — Real source acquisition/removal controls (`S-050`, bounded `V-027`).**
  Actual Choose/Replace, exact-copy Equip/Stow, ordinary spell selection/casting
  and exact-cast Dismiss controls use the same owned sources. Stale/wrong-kind
  commands refuse; original Action/slot costs settle once. Current-turn movement
  follows acquisition, dismissal and concentration loss without refunding spent
  distance after exhaustion, mode selection or Dash. Neutral/renamed fixtures
  change amounts and lifetimes through the same runtime. Fixed duration carriers
  do not offer unsupported Extended Spell; other recipients, general resource
  grants, named nonstacking policies, forms and catalog conversion remain open.
  [Independent review and actual-control receipts](../../.artifacts/planning/vocabulary-reports/batch-L-review.md).

<a id="vs-61"></a>

- [x] **VS-61 — Dice-pool progression and captured faces (`S-051`, bounded `V-038/V-007/V-057`).**
  Opt-in `on_acquire` / `new_dice_only` pools capture distinct owner/source/serial
  dice even for equal faces. Declared class-level capacity/size tables and explicit
  recalculation preserve retained faces/sizes without refill; shrink keeps oldest
  dice and completed rests generate only vacancies with new identities. Actual
  feature/quantity/command controls cancel without RNG or spend the oldest selected
  quantity and one authored action using stored faces. Sibling sources survive
  spending/removal. Numeric reservations/exchanges cannot consume captured dice.
  Fresh-process checkpoints retain mixed generations and serials without RNG;
  22 malformed full saves across both DTO paths refuse before session replacement.
  Retained evidence: 1182/0 class/persistence checks, 69/0 focused assertions
  (12 actual-control checks), 202-script parse/boot and existing dice/rest controls.
  Authored class/subclass pools and the existing self-healing consumer only;
  arbitrary die selection, transfers, other consumers/policies, leveling UI,
  tokens, exchanges and catalog conversion remain open. No gameplay rerun or
  runtime repair was needed on matched source during independent review.
  [Independent review and receipts](../../.artifacts/planning/vocabulary-reports/batch-M-review.md).

<a id="vs-62"></a>

- [x] **VS-62 — Turn-start/Initiative numeric-pool recovery (`S-062`, bounded `V-044/V-041`).**
  Actual settled Initiative and tracked turn-start events restore fixed/fill/floor
  quantities on exact numeric sources, clamped to owned capacity. Actor-only
  formulas require available integral values; location changes and capacity
  recalculation do not emit recovery. Eligible sources in a declared group are
  mutually exclusive or declined. Same-event entry, budget reset, stale/replayed
  choices, public metadata edits, changed definitions/formula results/capacity,
  wrong actor and removed/reacquired sources cannot commit another recovery.
  Actual controls prove Initiative choice, turn recovery, exact feature/source
  spending, blocked actions while pending, decline, next-own-turn recovery and
  teardown with zero recovery RNG/action cost. Retained evidence: 1227/0 earlier
  class/persistence checks; final 67/0 N assertions (20 actual-control checks),
  204-script parse/boot, Monk 61/0, numeric rest 19/0 and dice pool 18/0.
  Existing quantities persist without new DTO fields or checkpoint permission.
  Living Character player-entity hosts only; native resource conversion, combat
  dice recovery, cross-actor recovery, secondary option costs/effects, extra-turn
  hosts, random/time policies and catalog conversion remain outside acceptance.
  All sixteen source hashes match; no runtime repair or repeated gameplay run.
  [Independent review and receipts](../../.artifacts/planning/vocabulary-reports/batch-N-review.md).

<a id="vs-63"></a>

- [x] **VS-63 — Captured recipient grants (`S-082`, bounded `V-054/V-057`).**
  Exact captured pool dice move oldest-first with original face, size, generation
  and identity; formula tokens/permissions capture one self-benefit value.
  Original giver payment, recipient selection and immutable source/giver/recipient/
  group/deadline commit once through Features, CombatCommand and the recipient
  popup. Cancel, stale objects/sources/pools/definitions/turns/budgets, replay and
  teardown preserve costs and RNG. Later giver progression/removal leaves gifts
  intact; transferred-source high-water marks prevent die identity reuse after
  reacquisition. Recipient Action/Bonus Action/own-turn Reaction consumes each
  gift once for healing or ordinary Temporary HP. Both DTO paths and cross-actor
  links preflight before replacement; recovery retains original expiry and serials.
  Retained proof: final 1221/0 class checks, 138/0 P assertions (38 actual controls),
  207-script parse/boot; earlier 1328/0 classes/persistence and 69/0 M controls;
  distinct-process recovery with 30 malformed-save refusals. All 28 builder hashes
  matched before review; no runtime change or repeated gameplay run was needed.
  Batch P left S-083 partial; VS-64 below accepts Q's shared captured weapon-attack
  bonus consumer. VS-63 alone adds no roll replacement, casting permission,
  off-turn intervention, broader origins or catalog acceptance.
  [Independent review and receipts](../../.artifacts/planning/vocabulary-reports/batch-P-review.md).

<a id="vs-64"></a>

- [x] **VS-64 — Recipient budget and shared captured bonus (`S-083`, bounded `V-054`).**
  One transfer captures a single shared weapon-attack bonus face, one original
  giver quantity and independent source/group/recipient/deadline records. Each
  beneficiary selects that stored face in its missed normal Attack/Extra Attack,
  pays its own Reaction and consumes only its gift, without bonus RNG. Standalone
  HP commands cannot consume an attack gift. Actual controls prove both recipients;
  stale/expired/replayed/revoked answers cannot spend. Distinct-process recovery
  retains face 2 and deadline 60 at clock 17 after giver level/source removal.
  S-082/VS-63 and S-051/VS-61 remain accepted prerequisites. No other roll host,
  casting permission, replacement token or catalog certification is implied.
  [Independent Q review](../../.artifacts/planning/vocabulary-reports/batch-Q-review.md).

<a id="vs-65"></a>

- [x] **VS-65 — Another Character's fixed helping modifier (`S-097`, bounded `V-014/V-035`).**
  A willing conscious party helper contributes a fixed bonus to another Character's
  missed normal weapon Attack/Extra Attack. Its exact source object/definition/pool
  and its own Reaction pay once; a spent attacker Reaction does not prohibit help.
  Wrong owners, same-ID helper/source replacement, definition/budget/turn/clock
  changes and replay refuse before unintended payment/RNG/effects. Stale visible
  choices decline through the original request, retaining its roll/action and
  continuation; actual controls prove one helper payment and two original swings.
  This satisfies S-097's one already-supported operation with a fixed modifier;
  defensive, outcome, reroll and token interventions and other roll hosts remain
  unaccepted. No broad V-013/V-089/V-090 completion follows from the slice's mapping.
  [Independent Q review](../../.artifacts/planning/vocabulary-reports/batch-Q-review.md).

<a id="vs-66"></a>

- [x] **VS-66 — Integer allocation across recipients (`S-101`, bounded `V-036`).**
  Loaded neutral/changed Features/source controls allocate one fixed actor-formula
  total as integer HP/Temporary HP under recipient count, total and per-target caps.
  Validate the complete selection and exact actor/recipients/source/budget/turn/clock
  before one source quantity/action and any HP effect. Cancel/refusal pays nothing;
  declared forfeit/require-full remainder policies are checked. Duplicate, fractional,
  excess, stale and wrong-owner rows cannot partially settle. Actual plain 12 split
  4/3 heals HP 1 to 5/4; changed 8 split 4/3 grants keep-higher Temporary HP 4/3.
  Living combat Character hosts only; no half-max-HP or arbitrary effect policy.
  [Independent Q review](../../.artifacts/planning/vocabulary-reports/batch-Q-review.md).

<a id="vs-67"></a>

- [x] **VS-67 — Rolled total and exact retained-die allocation (`S-102`, bounded `V-036/V-038`).**
  One numeric source quantity/action buys one revealed d6/d8 total, split across
  recipients without reroll or further payment. Cancel/refusal forfeits that paid
  reveal. Captured-dice mode instead confirms exact owned die IDs without RNG,
  including non-prefix selections; per-recipient die-count and source spend bounds
  apply. Unselected ordered identities/faces remain in the pool. Both total and
  die modes validate all recipients before HP/Temporary HP consequences; requests
  stay transient. Recovery preserves the selected pool subset without regeneration;
  both DTO paths reject duplicate/quantity-mismatched dice before session replacement.
  Q evidence: retained 1358/0 class checks, 108/0 persistence, 138/0 P assertions
  (38 actual controls), distinct-process recovery and 14 malformed-save refusals;
  final 70/0 Q controls and 212-script parse/boot after a punctuation-only repair.
  No new durable field, save permission, catalog or broader allocation effect.
  [Independent Q review](../../.artifacts/planning/vocabulary-reports/batch-Q-review.md).

<a id="vs-68"></a>

- [x] **VS-68 — Starting versus multiclass permanent grants (`S-047`, bounded `V-026/V-027`).**
  Loaded opt-in class data grants distinct starting and multiclass proficiency,
  expertise and exact backpack equipment once through real creation and class-level
  controls. Returning to a class retains its original entry receipt. Full-grant
  capacity and stale-state checks refuse before mutation; oversized creation now
  explains refusal and cannot register a blank actor. Independent permanent
  proficiencies survive feature-choice replacement. Primary choices support only
  weapon/armor/skill arrays; secondary native feature tables must be empty.
  No native multiclass casting, subclasses or catalog certification.
  [Independent 018 review and repairs](../../.artifacts/planning/vocabulary-reports/batch-018-review.md).

<a id="vs-69"></a>

- [x] **VS-69 — Permanent class/character-level deltas (`S-048`, bounded `V-026/V-007/V-057`).**
  Ordered acquisitions distinguish each class allocation from total character
  level. Authored positive permanent ability/fixed max-HP gains and total-level
  proficiency execute once; CON uses underlying scores and existing retroactive
  HP arithmetic. Both acquired classes observe their character-level entries,
  while a sibling class cannot borrow primary class levels. Saved history,
  pending levels and exact receipts validate on both DTO paths; restore reads
  saved totals/items without applying grants. Removed starting gear stays removed.
  Final proof: 1543/0 class/persistence checks, 18 actual-control checks,
  215-script parse/boot and distinct-process recovery (20260/40480), 20 malformed
  full-save refusals, zero RNG. Fixed level HP, existing living full heal and
  explicit opt-in classes only; reversible HP effects/resources/casting remain open.
  [Independent 018 review and repairs](../../.artifacts/planning/vocabulary-reports/batch-018-review.md).

<a id="vs-70"></a>

- [x] **VS-70 — Cast-completion and source-end context (`S-042`, bounded `V-010`).**
  Successful shared combat casts publish school, spell identity, effective and
  paid slot, source, invocation/action and completion facts after resolution;
  source-end receipts retain the exact reason/cause. Publishing a fact grants no
  action. Focused Godot checks and the production spell lifetime scenario passed.
  Catalog consumers and exploration casting remain open.
  [Batch 019 review](../../.artifacts/planning/vocabulary-reports/batch-019-review.md).

<a id="vs-71"></a>

- [x] **VS-71 — Source-linked event termination (`S-072`, bounded `V-049`).**
  Shared spell rules match attack, completed cast, movement, Character status,
  inventory equipment and represented-combat range events; only the exact
  subscribed source ends. Player and monster movement publish from the shared
  step. Monster status-removal paths outside shared controls, exploration range
  and catalog conversions remain open. Final evidence: 1729/0 logic checks,
  215-script parse/boot and production spell lifetime scenario with 0 failures.
  [Batch 019 review](../../.artifacts/planning/vocabulary-reports/batch-019-review.md).

<a id="vs-72"></a>

- [x] **VS-72 — Exact causal damage exception (`S-073`, bounded `V-049`).**
  Settled damage retains its source-instance ID; `this_source` exempts only the
  matching source while unrelated damage ends the subscribed source and records
  the cause. Focused Godot checks cover both outcomes. End receipts are transient
  and bounded to 128 entries.
  [Batch 019 review](../../.artifacts/planning/vocabulary-reports/batch-019-review.md).

<a id="vs-73"></a>

- [x] **VS-73 — Suppression without removal (`S-074`, bounded `V-050/V-057`).**
  A source-owned condition remains stored with its original duration while
  suppressed; its clock advances, and an expired condition never returns on
  exit. [Batch 020 review](../../.artifacts/planning/vocabulary-reports/batch-020-review.md).

<a id="vs-74"></a>

- [x] **VS-74 — Independent suppressor ownership (`S-075`, bounded `V-050`).**
  Overlapping aura sources and recipients retain separate identities. Removing
  or moving one source does not expose a condition another source still masks.
  [Batch 020 review](../../.artifacts/planning/vocabulary-reports/batch-020-review.md).

<a id="vs-75"></a>

- [x] **VS-75 — Moving Character aura membership (`S-080`, bounded `V-053`).**
  The combat projection recomputes direct Character bearer/recipient distance;
  actual movement out and back across the authored radius restores and suppresses
  the same condition. Source and bearer are the same Character in this bounded
  host. [Batch 020 review](../../.artifacts/planning/vocabulary-reports/batch-020-review.md).

<a id="vs-76"></a>

- [x] **VS-76 — Source-owned casting permission (`S-134`, bounded `V-028/V-027`).**
  Prepared/book/item/innate sources retain their own spell, ability and
  restrictions; exact equipped/attuned item copies stay independent.

<a id="vs-77"></a>

- [x] **VS-77 — Exact casting permission/payment (`S-135`, bounded `V-028/V-031`).**
  Commands rebuild current owned permissions; forged pairings and stale policies
  refuse before costs. Slot/free/point/item payments retain their selected source.

<a id="vs-78"></a>

- [x] **VS-78 — Per-source preparation and replacement (`S-137`, bounded `V-029/V-057`).**
  Authored class opt-in supplies independent lists, class-level limits, abilities
  and spent replacement windows. Both full-save DTO paths validate receipts;
  distinct-process recovery does not reopen windows or refill exact item charges.

<a id="vs-79"></a>

- [x] **VS-79 — Combined ordinary versus Pact slots (`S-138`, bounded `V-029`).**
  Full/half-up contributions combine independently of Pact/preparation. Actual
  casts and Shield/Counterspell reactions pay the selected pool without fallback.

<a id="vs-80"></a>

- [x] **VS-80 — Fixed-level source spell uses (`S-139`, bounded `V-029`).**
  Existing Arcanum permissions retain fixed level/use and Long Rest recovery,
  separately from payable slot pools.

<a id="vs-81"></a>

- [x] **VS-81 — Source-specific ritual controls (`S-136`, bounded `V-028`).**
  Actual exploration controls select exact class/book/feature/item sources,
  components and normal-plus-ten-minute time. Ritual-only access never authorizes
  normal combat casting; post-delay interruption refuses completion.

<a id="vs-82"></a>

- [x] **VS-82 — Exact slot/pool exchange selectors (`S-052`, bounded `V-039/V-031`).**
  Ordinary/Pact or numeric-pool payments select exact sources and authored fixed
  quantities. Affordability and full numeric destination fit precede mutation.

<a id="vs-83"></a>

- [x] **VS-83 — Captured-dice/inventory and party exchange (`S-053`, bounded `V-039`).**
  Captured dice or exact eligible backpack copies pay numeric self/active-party
  destinations atomically. Cancellation, stale copies, full destinations and
  same-pool party aliases refuse intact; spent/unspent copy identities and both
  actors' quantities survive fresh-process recovery.

[Batches 021–023 independent acceptance](../../.artifacts/planning/vocabulary-reports/batch-021-023-acceptance-review.md)
owns VS-76–83 finish lines, source hashes, 2,837/0 affected logic, 21/20/41
actual-control assertions and retained/new distinct-process recovery evidence.
No broad V-series parent or catalog completion is implied.

<a id="vs-84"></a>

- [x] **VS-84 — Recipient Temporary HP replacement (`S-078`, bounded `V-052/V-009`).**
  Actual Keep/Replace controls use current HP, including smaller incoming grants.
  Keep/Cancel preserve the exact supplier, remaining HP and deadline without cost;
  stale HP/source/pool/clock/turn/generation answers refuse before payment.

<a id="vs-85"></a>

- [x] **VS-85 — Cross-actor linked Temporary HP (`S-079`, bounded `V-052/V-054/V-057`).**
  Exact supplier/source/recipient/serial and fixed AC/save benefits follow the
  surviving captured grant. Partial absorption retains it; depletion, replacement,
  exact source removal and expiry end it. Both save DTO paths validate before
  live replacement; distinct-process recovery retains partial HP and deadlines.

<a id="vs-86"></a>

- [x] **VS-86 — Chosen aura and timed entry benefits (`S-081`, bounded `V-053`).**
  Character combat recipients choose one exact source per nonstacking group.
  Membership protection ends outside range or on combat exit; fixed campaign-time
  once-per-source receipts retain their original deadline after exit/reentry/reload.
  Expired receipts prevent reacquisition. Owner equals bearer; broader hosts and
  entry reset policies remain open.

<a id="vs-87"></a>

- [x] **VS-87 — Interruption/failure reserve and refund (`S-142`, bounded `V-031`).**
  Upfront payment reservation captures slot, free-cast, item charge, or pool point
  payments upon invocation. Interruption and failure evaluate declared commit or refund
  policies, restoring spent resources on refund. Spells resolving with empty effect
  payloads commit payment by default unless explicit refund is authored.
  [Batch 029 review](../../.artifacts/planning/vocabulary-reports/batch-029-review.md).

<a id="vs-88"></a>

- [x] **VS-88 — Whole pending cast cancellation (`S-115`, bounded `V-019`).**
  Predicate filtering matches qualifying level, school, source, and spell ID allowlists;
  non-matching casts are preserved. Evaluates reaction contest (save, check, or none);
  successful cancellation marks the target cast as interrupted, settles payment per target
  interruption policy, and aborts further resolution without affecting bystanders.
  [Batch 029 review](../../.artifacts/planning/vocabulary-reports/batch-029-review.md).

<a id="vs-89"></a>

- [x] **VS-89 — Stopping-spell cost policy (`S-143`, bounded `V-031`).**
  Evaluates stopping outcome against declared on_success and on_failure branches to
  commit or refund the stopping caster's slot, reaction, or free cast, and dispose
  single-use item copies. A failed stop refunds or commits the stopping resource as
  authored and never repays or alters the original target spell.
  [Batch 029 review](../../.artifacts/planning/vocabulary-reports/batch-029-review.md).

<a id="vs-90"></a>

- [x] **VS-90 — One recipient's incoming effect negation (`S-116`, bounded `V-019`).**
  Evaluates negation rules on recipient features, equipped items, or runtime decisions.
  Excludes qualifying recipient from cast and stepped execution (`skipped: true, negated: true`)
  without damage or condition effects. Other targets in multi-target or area spells take full
  normal effect; reflection and retargeting remain distinct operations.
  [Batch 029 review](../../.artifacts/planning/vocabulary-reports/batch-029-review.md).

<a id="vs-91"></a>

- [x] **VS-91 — Budgeted slot/pool recovery (`S-054`).**
  Real rest controls retain exact sources, formula budgets, exclusions and capacity through cancellation/refusal.
  [Independent evidence](../../.artifacts/planning/vocabulary-reports/batch-024-026-verification.md).

<a id="vs-92"></a>

- [x] **VS-92 — Outcome-selected recovery (`S-055`).**
  Actual settled spell result and paid ordinary slot select only the eligible lower or lowest recovery.
  [Independent evidence](../../.artifacts/planning/vocabulary-reports/batch-024-026-verification.md).

<a id="vs-93"></a>

- [x] **VS-93 — Dawn/dusk/cooldown recovery (`S-063`).**
  Campaign boundaries settle exact-source occurrences once, including missed days and fresh-process recovery.
  [Independent evidence](../../.artifacts/planning/vocabulary-reports/batch-024-026-verification.md).

<a id="vs-94"></a>

- [x] **VS-94 — Scheduled repeat saves (`S-068`).**
  Represented target-turn and elapsed schedules retain recipient/source/purpose and resolve due attempts once; expiry wins equal deadlines.
  [Independent evidence](../../.artifacts/planning/vocabulary-reports/batch-024-026-verification.md).

<a id="vs-95"></a>

- [x] **VS-95 — Counted saves and staged conditions (`S-069`).**
  Owned success/margin history advances linked stages and survives recovery; malformed missing history refuses before session replacement.
  [Independent evidence](../../.artifacts/planning/vocabulary-reports/batch-024-026-verification.md).

<a id="vs-96"></a>

- [x] **VS-96 — Repeat-save DC history (`S-090`).**
  Declared failed-attempt DC increases and success reset retain exact source/recipient history. Broader cumulative-risk hosts remain open.
  [Independent evidence](../../.artifacts/planning/vocabulary-reports/batch-024-026-verification.md).

<a id="vs-97"></a>

- [x] **VS-97 — Attack/Flurry unit substitution (`S-146`).**
  Actual spell/item/self-heal controls replace one/two remaining units without another parent action payment; spell costs and exact copies remain independent.
  [Independent evidence](../../.artifacts/planning/vocabulary-reports/batch-028-completion-review.md).

<a id="vs-98"></a>

- [x] **VS-98 — Child actions inside a paid parent (`S-148`).**
  Declared single strikes, shared Action casts and ordinary movement use local action waivers with original parent invocation/source/classification. Reaction parents use the active actor only.
  [Independent evidence](../../.artifacts/planning/vocabulary-reports/batch-028-completion-review.md).

<a id="vs-99"></a>

- [x] **VS-99 — Child choice and interrupted continuation (`S-149`).**
  Real chooser/target/reaction controls settle children once, retain siblings and paid parent, apply explicit skip/stop cancellation, and refuse stale old-popup callbacks.
  [Independent evidence](../../.artifacts/planning/vocabulary-reports/batch-028-completion-review.md).

<a id="vs-100"></a>

- [x] **VS-100 — Represented physical eligibility (`S-032`).**
  Actual actor/object/copy facts preserve unknowns; required mass/material/status
  refuses before payment. Loaded object-target controls verify refusal/success.
<a id="vs-101"></a>

- [x] **VS-101 — Plane and available-space queries (`S-033`).**
  Read-only single-cell placement uses actual plane, occupants, objects and
  vertical clearance. Actual spatial-cast controls verify plane/clearance costs.
<a id="vs-102"></a>

- [x] **VS-102 — Combat speed/mode/surface costs (`S-179`).**
  Character movement controls retain distance through mode/Dash/prone changes,
  apply represented terrain/water costs and spend nothing on initial refusals.

[Batches 029/030 review and repairs](../../.artifacts/planning/vocabulary-reports/batch-029-030-review.md)
retains VS-87–90 and accepts VS-100–102 on the documented combat host. Final
proof: 3005/0 classes/spells, 37/0 Batch 029, 36/0 Batch 030 and 34/0 Batch 028
scenario assertions, bootstrap/244-script parse/boot, exit 0. The original 13
Batch 029 checks were helper calls, not button workflows. New actual input
controls and remaining host limits are identified separately in the review.

[Batch 027 independent review](../../.artifacts/planning/vocabulary-reports/batch-027-review.md)
accepts VS-84/85/86 separately after repairing stale membership on combat exit.
Final proof: 23/0 actual controls, 3/0 Batch 020 movement controls, 235-script
parse/boot; unchanged 1628/0 logic and distinct-process recovery with 24 malformed
full-save refusals are retained. Batches 024–026 are accepted on their verified hosts.

<a id="vs-103"></a>
<a id="vs-104"></a>
<a id="vs-105"></a>
<a id="vs-106"></a>

Independent [Batch 025 completion review](../../.artifacts/planning/vocabulary-reports/batch-025-completion-review.md)
accepts S-123/S-124/S-125 as VS-103/104/105 and dependent S-059 as VS-106.
Bounded checks cover critical base-die cost separation, authored heal reroll
selection/eligibility/keep/payment receipts, critical multiplier exclusion and
actual Attack payment replacement. These do not complete broad V-023 or V-042.

<a id="vs-107"></a>

- [x] **VS-107 — Linked split settlement (`S-111`, bounded `V-017`).**
  Declared post-reduction rounding conserves one occurrence across the fixed
  target/caster pair; each recipient settles its own defenses and concentration.
<a id="vs-108"></a>

- [x] **VS-108 — Linked redirection (`S-112`, bounded `V-017`).**
  Full/partial transfer, exact-source removal and stale/declined fallback preserve
  original attacks, riders, costs and ordered continuation once.
<a id="vs-109"></a>

- [x] **VS-109 — Incoming replacement/healing (`S-113`, bounded `V-018`).**
  Explicit incoming/resolved stages distinguish immunity, replacement, Ward,
  Temporary HP, HP loss and actual capped healing.
<a id="vs-110"></a>

- [x] **VS-110 — Settled countereffects (`S-114`, bounded `V-018`).**
  Captured measures drive derived damage/healing with exact actor/source/root
  and depth limits, independent siblings and later roots, and recipient aftermath.

Independent [031/032 acceptance](../../.artifacts/planning/vocabulary-reports/batch-031-032-acceptance-review.md) records the two acceptance repairs,
production controls, recovery and both full-save refusal paths. Hosts are incoming
monster weapons and player flat/ordered shared spells; other controllers and
catalog conversion remain unverified. V-017/V-018 remain partial.

<a id="vs-111"></a>

- [x] **VS-111 — Authored zero-HP eligibility (`S-117`, bounded `V-020`).**
  Shared Character/Dictionary replacement precedes defeat, with authored damage,
  critical and represented massive-death exclusions, condition/source eligibility
  and clamped HP formulas. Temporary HP and native precedence remain distinct.
<a id="vs-112"></a>

- [x] **VS-112 — Owned zero-HP save attempts (`S-118`, bounded `V-020`, `V-088`).**
  Exact actor/source DC, attempted/accepted/result increments and numeric-pool
  payment settle once. Completed rests reset detached histories; receipt/reset
  generations and lifetime totals validate on both full-save DTO paths and recover.

Owner-authorized [Batch 033 acceptance](https://github.com/brandonbrown215bb-boop/DND-Sandbox-Engine/blob/d823423d979f7c566d7511801bd560f5dafb95ee/docs/reviews/batch-033-acceptance.md) follows independent
review and repair re-review of primary poison-rider authorization and saved count
consistency. Verified hosts are primary incoming monster weapons (including poison
riders), player flat/ordered spells and automatic typed Dictionary rules. Optional
linked/counter pickers, other controllers, general instant death/destruction,
forms, revival and catalog conversion remain open. V-020/V-088 remain partial.

Batch D retains VS-36 after repairing exact participant identity in allegiance
queries, and accepts VS-37/38 after distance/sense repairs and independent
production controls. V-002 and V-003 remain partial.

Combined VS-18–20 review closed five stage/snapshot defects: spent Inspiration
is retained in the paused total, ordered save choices reach the chooser, a
following deferred damage choice retains the original continuation, flat
failure effects wait for the final save, and resume keeps the captured DC.
The development checks above cover Inspiration/changed-DC/deferred-damage
regressions; VS-20's clean production scenario covers real ordered/flat controls
and once-only payment/effects. Transient choices add no checkpoint permission.

Combined review verified the focused corrections: duplicate same-kind grant
operations refuse at content loading; tagged timed/cooldown state requires its
owned saved pool and deadline; exact-source removal clears only its own cooldown.
The extended full-save probe above refused orphaned sources/missing deadlines
before session replacement. [Focused class evidence: 779/0](../../.artifacts/tests/14659d0b264d4be5ba3eab380d51663c).

Combined VS-15–17 review also closed deterministic constant-expression lookup
rejection and schema omissions for lookup/sum forms. Nested cast-only actor
formulas now fail safely without a cast context. [Focused spells: 932/0 and
schema inventory](../../.artifacts/tests/49f742187a0f49f78de80e7212a91d3c).
The schema check covers syntax and targeted fragments/fixtures; a full JSON
Schema validator is unavailable. Production behavior is proved by Godot.
