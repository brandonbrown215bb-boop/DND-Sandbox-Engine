# Data-driven gameplay roadmap

Owner direction reconciled 2026-10-12. Build one shared in-process rules
runtime for classes, creatures, spells and their interactions. JSON defines
rule behavior; GDScript interprets supported operations and bridges to the
world. New content using those operations must not require native branches
for its class, creature, spell or feature ID.

[ADR-0018](docs/decisions/0018-shared-data-driven-rules-runtime.md) owns this
direction. [ADR-0023](docs/decisions/0023-vocabulary-first-delivery-and-bounded-world-judgment.md)
records the owner's vocabulary-first delivery, time/rest, illusion and Wish
decisions. [ADR-0017](docs/decisions/0017-shared-json-spell-execution.md) requires
ordered mixed spell checks. The [current checkpoint](docs/operations/current.md)
records accepted evidence and unfinished work; the Quest Board owns the exact
next action. The class and creature design documents supply requirements and
stress cases, not two separate engines or mandatory up-front module scaffolds.

## Starting point

The initial shared-runtime proof is already accepted in the
[current checkpoint](docs/operations/current.md): ordinary shared spells,
ordered spell/zero-HP execution, roll tokens, wards and rest slot recovery have
bounded production evidence. Reuse those pieces; do not schedule that same proof
again. Their broader generality remains partial.

The [vocabulary checklist](docs/reviews/dnd-code-vocabulary-gap-checklist.md)
retains 31 navigation families and 97 concrete V-series capabilities. Each
concrete row supplies a boundary, source examples, current status, likely hook and
dependencies. Its [35 checked subsets](docs/reviews/dnd-code-vocabulary-gap-checklist.md#checked-subsets-and-bounded-implementation)
record the accepted P1/P2/P3 slices separately from the 97 broad requirements.
“Partial” or “uncertain” is not full capability completion. These
are building blocks to extend existing owners, not 97 new modules.

The [counted delivery plan](docs/planning/vocabulary-slices.md) maps every known
V-series requirement to **226 defined build/validation slices**: **35 verified,
191 not yet accepted** through S-098's 2026-10-14 acceptance. It owns slice IDs,
finish lines, prerequisites, phase counts and source follow-up. Count each slice
once even when several capabilities use it; the denominator measures defined
scope, not time or effort. Missing rule bodies can reveal additional work.

## Work order

Keep these activities separate:

1. **Discover vocabulary.** Read descriptions and code enough to name distinct
   requirements. Consolidate repeated needs. No Godot, probes, catalog correctness
   ledger or content mutations. The completed discovery pass and remaining source
   gaps are recorded in the checklist.
2. **Build a selected capability batch.** Implement shared operations and the
   required world hooks. Use small neutral examples as consumers; do not make
   rewriting the spell/class/monster/item catalog part of this task.
3. **Check that vocabulary.** After implementation, run a bounded production
   Godot validation of its actual inputs, stages, results, choices/costs and
   source-owned state. Check interactions with affected existing behavior. Mark
   the concrete capability complete only for the demonstrated boundary.
4. **Translate content.** Convert definitions using the checked building blocks.
   Track separate content support; a verified building block does not certify
   every spell or class using it. Broader playing/usability checks follow useful
   content batches.

Testing is not part of discovery or roadmap preparation. Implementation and
capability checks are separate task steps; unverified code is described honestly
until the checks happen. This sequence does not add a second engine in Python.

## Accepted vocabulary slices

The [current checkpoint](docs/operations/current.md) and checklist VS-01–17
record production evidence for these selected boundaries:

| Workstream | Checked building blocks | Remaining boundary |
|---|---|---|
| P1 facts/results (`V-001`, `V-002`, `V-006`, `V-007`, `V-011`) | Source-owner/wounded eligibility; one earlier Fire component's raw/resolved/HP-loss values; rounded aftermath; live caster inputs and captured selected-slot level; renamed data and continuation | Broader facts/relations, target/component combinations, result aggregation, tables, multiclass and other timing policies |
| P1/P2 sources and pools (`V-027`, `V-038`, `V-057`) | Independent exact-source numeric pools, formula capacity, spending, growth/shrink/removal, bounded one/two-die activation, authored recovery and allowed same-process checkpoint preservation | Source acquisition UI, broader grant domains, exchanges, other pool definitions, transferable/pre-rolled dice, class dice tables, post-success payment and fresh-process recovery of new state |
| P2 rest recovery (`V-044`, `V-048`) | Fixed Short Rest and capacity Long Rest recovery through actual controls; completion/eligibility/source boundaries and checkpoint reload | Other rest/eligibility policies, Hit Dice, rest-start expiry, Initiative/dawn/dusk and cooldowns |
| P2 use limits (`V-041`) | Weapon-hit rider once per combat turn, per target per combat turn, or per owner-turn interval; real turn progression and independent pool/lock commitment | UI target selection, own-turn-only restriction, round/roll/active-instance scopes and general event subscriptions |

Do not schedule these same build/acceptance slices again merely because their
broader V-series parent rows remain open. They are reusable bounded building
blocks, not certification of a whole phase or the content catalog.

## Accepted recent P2 extensions

The accepted exchange slice extends exact-source numeric pools with one data-authored
fixed exchange (`V-039`): spend two uses from one owned numeric source and
restore one use to a different owned source of the same actor, only when the
full restoration fits. It reuses the shared feature activation and exact-source
combat choice path. The neutral fixture and implementation boundary are in the
[shared pool contract](docs/mechanics/shared-resource-pools.md#bounded-numeric-pool-exchange--production-validated-2026-10-12).
Production acceptance is recorded as VS-11 in the
[vocabulary checklist](docs/reviews/dnd-code-vocabulary-gap-checklist.md#verified-subsets-to-mark-off).
It checked neutral and renamed definitions, exact source choices, one 2-for-1
commit, refusal boundaries and allowed-checkpoint reload. Spell slots, dice,
currency, conditional/post-roll payment, cross-actor transfers, catalog
conversion and other selectors/policies remain open. Reuse VS-01–17; do not
rerun accepted proof just because its parent rows remain open.

The selected follow-up for `V-041`, a bounded limit between the owner's turn
starts, is now production validated with neutral and renamed fixture data,
actual off-turn Opportunity Attacks and real initiative progression. The
focused Godot scenario and 727 class checks are recorded under VS-08 in the
[vocabulary checklist](docs/reviews/dnd-code-vocabulary-gap-checklist.md#verified-subsets-to-mark-off)
and the [current checkpoint](docs/operations/current.md). This closes only the
selected slice; own-turn-only restrictions, other timing scopes, general event
subscriptions and the broader `V-041` requirements remain open. The six
prepared build/validation prompts remain in the local
[prompt set](.artifacts/planning/next-p2-goals.md).

## Accepted effect-lifetime batch

VS-12 checks the source-owned timed AC self-grant; VS-13 checks the oldest
qualifying melee-hit grant with fixed typed damage; VS-14 checks optional
cooldown starting at expiry or voluntary dismissal. Each has separate
production acceptance and fresh-process state recovery. Combined review also
closed orphaned timed-state loading, exact-source cooldown cleanup and silent
partial application of duplicate grant operations. Broader matching, grant,
end-reason and accumulated-use policies remain open. Reuse this evidence rather
than repeating the [effect-lifetime prompt set](.artifacts/planning/next-p2-effect-goals.md).

## Accepted Temporary HP and formula/result batch

VS-15 binds remaining Temporary HP to its supplier; old expiry/removal preserves
later timed/untimed replacement. VS-16 adds deterministic numeric breakpoint
lookup; VS-17 sums one earlier typed damage measure across actual target outcomes
and heals once after the step. Separate production acceptance and combined review
passed, including constant-expression lookup and schema corrections. THP uses
the current keep-higher policy; replacement choices, linked benefits, dice tables
and general reducers remain open. Reuse the local [accepted prompt set](.artifacts/planning/next-vocabulary-values-and-temp-hp.md).

## Accepted P3 saving-throw decision batch

VS-18–20 accept an owned post-roll fixed bonus, both payment policies, and an
explicit success override for rolled failed shared-spell saves. Original roll
fields/DC, source selection, ordered/flat rider timing and successive choices
have retained production/regression evidence. Combined review closed the
snapshot/suspension defects listed in the checkpoint. Wider V-013/014/035,
other hosts/rolls and automatic outcomes remain open.

## Accepted P3 attack results and rolled bonuses

VS-21–23 extend the owned optional numeric bonus to normal player weapon Attack/
Extra Attack and flat/ordered shared-spell attacks, and add a captured source
die bonus to those attack and accepted save consumers. They retain natural-1/critical
rules, final hit reevaluation, both payment policies, original action/slot costs
and successive-choice continuations. One captured roll is settled once; calling
the complete attack resolver again is not a post-roll adjustment.

The six completed build/validation prompts are retained in the local
[attack decision set](.artifacts/planning/next-p3-attack-decisions.md). Reuse their
accepted evidence. Other attack hosts, defensive/third-party
changes and further roll domains stay in remaining scope; content conversion
remains separate.

The three pairs are accepted as VS-21–23 for fixed bonuses through normal
player Attack/Extra Attack and flat/ordered shared-spell attacks, plus captured
d6/d8 bonuses in those consumers and the accepted save choices. Combined review
closed canonical Stroke validation, invalid spell-source fallback and wrong-
domain Stroke settlement. Exact source costs, retained die receipts and actual
controls have focused evidence; wider roll hosts and catalogs remain open.

The accepted **S-028 → S-094 → S-105** trio covers purpose-aware checks,
owned fixed/die modifiers on failed ability checks, and declared mandatory-new
rerolls. Each received a build, separate validation and combined review. These reuse
accepted source/roll rules instead of converting named content catalogs.

S-028 is accepted as VS-24 for loaded EventDialog event/choice checks. Task,
purpose, optional tool and exact owned-tool benefit/source receipts survive the
real Roll and Close controls. Loaded records retain check/DC/consequence authority;
unrelated/no-tool/no-bonus checks remain ordinary. S-094 is accepted as VS-25:
fixed/die bonuses through loaded event-level and choice-owned skilled/ability-only
checks, both payment policies, retained native bonuses, completed replay refusal
and host cancellation. S-105 is accepted as VS-26 for mandatory-new natural/test
rerolls through that host. Declared mode/bonus policies, original/new receipts,
floor stages, source costs and one final consequence are proven; broader hosts
and choosing between old/new remain open. Combined review is complete.

The accepted prerequisite trio is **S-024 → S-025 → S-041**:
combine eligibility conditions, bind facts to the correct entities, and expose
actual roll/damage windows. S-024 and S-025 are accepted as VS-27/28. S-041
is accepted as VS-31 after its authored-consumer repair and independent
[review](docs/reviews/slice-acceptance-2026-10-14.md). S-091 remains VS-29 and
S-092 is restored as VS-30 after native-use and source-option conflict repairs.
The healing parser defect is fixed. Batch B **S-091/S-092/S-095** has passed
independent source/evidence review; S-095 is accepted as VS-32. S-034 is accepted
as VS-33 after fresh-chat reconciliation of its retained separate production
validation. S-043 is accepted as VS-34 after its separate production validation;
there are **35/226 accepted, 191 not yet accepted**. S-042 remains planned.
Batch C **S-034/S-043/S-098** passed independent review after targeted repairs;
the [review report](.artifacts/planning/vocabulary-reports/batch-C-review.md)
retains VS-33–35. **S-026 BUILD** is next with S-002 and S-025 already accepted;
S-099 remains later in the prompt queue and also requires S-026.
The [Batch B report](.artifacts/planning/vocabulary-reports/batch-B-review.md) records
the precise scope; the Quest Board owns the next action. Older prompts remain in the local
[facts and windows set](.artifacts/planning/next-facts-and-windows.md).

At the owner's request, the [next-26 prompt pack](docs/planning/vocabulary-next-26-prompts.md)
prepares S-025/S-041 plus eight following trios in dependency order. Its
S-091/S-092/S-095 and S-034/S-043/S-098 trios are now complete. The remaining queue covers relation,
history, formula/stat, reroll-consumer and damage-stage slices. Each selected row
has separate BUILD and VALIDATE prompts and each batch has a fresh-chat REVIEW.
The [shared workflow](docs/planning/vocabulary-prompt-workflow.md) lets separate
validation record precise acceptance before a dependent build, with independent
batch review of shared boundaries. No continuously supervising agent is required.

This explicit prompt-preparation request supersedes waiting for each trio's review
to write the next prompts. Execution still waits for actual prerequisites and the
preceding batch review; later selections are conditional on those findings.
Preparation adds no accepted scope, dispatches no workers and does not replace
the full counted plan. The prompt pack's preparation baseline was 28/226;
current acceptance is 32/226.

## Capability workstreams

This is the default progression. The prerequisite IDs in each checklist row
govern the selected batch: take a needed small prerequisite from another group
when necessary. Completing an entire group is not an entry gate for the next.
Every V-series entry is assigned once below so requirements cannot disappear
behind a broad family name.

| Group | Building blocks | Checklist ownership | Candidate consumers |
|---|---|---|---|
| P1 — Facts, results and grants | Facts, predicates, arithmetic, prior-result bindings, acquisition/source identity | V-001–011, V-025–027 | Reuse the checked facts/results/caster leaves above; extend a concrete remaining fact, relation or grant boundary when needed. |
| P2 — Pools, time and effect state | Resource ownership, recovery, scoped limits, active-use clocks, modes, expiry, durable state and history | V-038–057, V-081, V-088 | Generic rest/reset policies; once-per-target versus own-turn limits; next matching attack; cooldown after expiry. |
| P3 — Rolls and decisions | Pre/post-roll windows, outcome changes, success-based payment, allocations and choices | V-012–015, V-035–037, V-089–090 | Homing Strikes, Guided Strike, bounded healing allocation; reuse current tokens. |
| P4 — Damage and consequences | Damage components/stages, dice edits, sharing/absorption, zero-HP/aftermath, recovery restrictions and reflection | V-016–024, V-085, V-095, V-097 | Typed monster rider, damage-linked healing, a selected prevention or save-consequence rule. |
| P5 — Casting and action composition | Source casting permission/progression, cast-local changes, costs, target extensions, attack substitutions and stored/stolen spell state | V-028–034, V-084, V-087 | One cantrip-for-attack substitution; a limited casting permission; spell storage. |
| P6 — Actors and forms | Factories, commands, initiative/extra turns, bonds, retained-stat projections, restraint/containment/control and revival | V-058–067 | A source-defined companion command; Animate Objects through shared capabilities; one reversible form policy. |
| P7 — Space, perception and illusions | Destinations, movement/passengers, spatial triggers/barriers, observer knowledge and independent origins | V-068–075 | A tether/area interaction; bounded illusion discovery; alternate cast origin. |
| P8 — Physical items and bodies | Container/part state, work/crafting/repair, survival/air, body/age and magic-property lifecycle | V-076–079, V-091–094, V-096 | Exact-copy fuel/parts; object repair; one selected physical capability. |
| P9 — Procedures and campaign outcomes | Random procedures, delayed rewards/knowledge, executable campaign decisions and capability requirements | V-080, V-082–083, V-086 | A bounded table or completion reward; campaign-authored Wish outcome. |

Source gathering remains a separate later task: locate missing intended 2024
optional-feature/feat, common item and other rule bodies; add any distinct
building blocks, especially exceptions affecting illusion or Wish behavior.
Do not resume the old all-record correctness audit. Missing source needed by a
chosen capability is resolved for that capability; unrelated catalog discovery
does not block work whose requirements are already concrete.

## How content becomes available

Aim for reusable composition across the whole intended scope. A missing world
fact or action becomes an explicit capability requirement. Unsupported children
refuse before unintended cost or disclose the exact bounded approximation;
names and allowlists do not establish support.

The normal action stages resolve real interactions in the correct order.
Detailed conflicts are settled when selected rules need them. General conflict
theory and a universal GM workflow are not prerequisites for ordinary mechanics.

Illusion behavior separates suspicion, the decision to investigate, the selected
spell's discovery rule and knowledge retained by each observer. Intelligence may
influence investigation, with context; it does not automatically reveal truth.
Add only the concrete missing observation/interaction facts needed by that spell.

Wish has its supported ordinary uses plus applicable campaign-authored special
outcomes. Those outcomes must name executable requirements/effects. An unavailable
special outcome does not suppress supported ordinary uses. Spell-specific limits
and consequences still need source-backed handling when Wish is selected.

The longer-term class design covers twelve 2024 PHB classes, forty-eight
subclasses, levels 1–20 and multiclassing. The creature design targets a pinned
revised-rules catalog. These are target scopes, not current release claims.
Artificer, Mystic and later supplements remain separate/parked content.

## Carry-forward work

Animate Objects has partial, unvalidated hooks. Its normal cast module,
owner-following initiative, commands and room controls remain unfinished.
Finger of Death's created Zombie, reversible forms and authored NPC/illusion
interaction also remain open. Preserve this work; integrate it through the
shared capabilities when scheduled, rather than extending named handlers as
the default architecture. Do not expose unfinished paths based on an allowlist.

[Spell foundations](docs/mechanics/spell-foundations.md) and
[Wave 4 acceptance](docs/mechanics/wave4-acceptance.md) retain concrete world
gaps and bounded integration checks. Their historical wave sequence and
class-by-class order no longer choose the next implementation.

## Product and safety boundaries

- Crown remains a level 1–5 campaign with one to four shared-keyboard seats
  and four stable party slots. Higher-level fixtures prove mechanics without
  implying a new campaign. Full Crown readiness is not currently certified.
- The owner states there are no existing player campaigns. Save compatibility
  and migration frameworks do not choose priority or gate capability work.
  Keep source/recipient/use state and Short/Long Rest, minute/hour and campaign
  clocks connected. Existing locations/checkpoints remain; no destructive file
  work or automatic rewriting of unrelated saves is authorized.
- Unsupported mechanics stay unavailable or explicitly partial. Missing host
  capabilities refuse before cost or declare a precise supported approximation.
- Use bounded represented outcomes for fiction, observer-specific illusion
  discovery and executable campaign Wish options. A general human GM workflow
  remains an optional capability, not an up-front prerequisite. Unrepresented
  open-ended outcomes remain explicit gaps.
- Windows Godot checks own gameplay evidence. Python inventories own structure.
  Human sampling informs usability; it is not a repeated gate on every slice.
- Keep one obvious implementation card. No wholesale CombatState extraction
  or new service, dependency or framework is a prerequisite.

Controllers, networking, publication, friend runs, public-content clearance
and a new high-level campaign remain parked until wanted. The old Gates 0–8
remain historical evidence, not the active dependency chain. Packaging and
fresh-clone checks apply when a publication candidate is actually chosen.
