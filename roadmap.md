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

## Parallel editor work

The owner requested two concurrent pipelines on 2026-10-18.
[Luna owns runtime/game integration; Antigravity owns the standalone editor and staged content](docs/planning/runtime-editor-parallel-pipelines.md).
The plan defines exclusive file ownership and explicit artifact handoffs.
Runtime slice order and acceptance remain as below; editor work can start with
existing records and supported contracts without waiting for all engine slices.
Keep one exact next action per pipeline on separate Quest Board cards.

## Proposed next batches: 018-030

The owner requested the next thirteen batch outlines after Q. The
[numbered batch plan](docs/planning/vocabulary-batches-018-030.md) proposes
39 existing slices, beginning with **018: S-047/S-048** for starting versus
multiclass acquisition and permanent progression. It then covers effect endings,
suppression/auras, casting permissions and slot accounting, resource exchange/
recovery, damage dice, repeat saves, linked protections, child actions, cast
interruption and physical movement facts. Its prerequisites are ordered against
the accepted 67-slice baseline; implementation selection and independent
acceptance remain separate. Historical A-Q names stay unchanged. Independent
[Batch 018 review](.artifacts/planning/vocabulary-reports/batch-018-review.md)
accepts S-047/S-048 as VS-68/69 after two bounded repairs. Batch 019 is accepted
as VS-70/71/72 after independent review repaired monster movement event
publication, and Batch 020 as VS-73/74/75 for directly owned Character combat
aura sources. The
current count is **106/226**, including accepted 024 recovery, 025 damage/healing
dice, 026 repeat-save
history, 027 protections, 028 substitutions/child continuations and 029 cast
interruption. [Current verification](.artifacts/planning/vocabulary-reports/batch-024-026-verification.md)
closes the reported 025/026 bugs and accepts 024/026; [025 completion review](.artifacts/planning/vocabulary-reports/batch-025-completion-review.md)
accepts the remaining dice/payment slices as VS-103–106. [028 review](.artifacts/planning/vocabulary-reports/batch-028-completion-review.md)
accepts its three completed slices. Batch 025's cost-dice edits, authored
healing rerolls, critical exclusions and payment replacement are accepted on
bounded hosts.
[029/030 review](.artifacts/planning/vocabulary-reports/batch-029-030-review.md)
retains repaired 029 and accepts 030 physical/space/movement as VS-100–102. V-050/V-053 remain partial.

## Starting point

The initial shared-runtime proof is already accepted in the
[current checkpoint](docs/operations/current.md): ordinary shared spells,
ordered spell/zero-HP execution, roll tokens, wards and rest slot recovery have
bounded production evidence. Reuse those pieces; do not schedule that same proof
again. Their broader generality remains partial.

The [vocabulary checklist](docs/reviews/dnd-code-vocabulary-gap-checklist.md)
retains 31 navigation families and 97 concrete V-series capabilities. Each
concrete row supplies a boundary, source examples, current status, likely hook and
dependencies. Its [106 checked subsets](docs/reviews/dnd-code-vocabulary-gap-checklist.md#checked-subsets-and-bounded-implementation)
record the accepted P1–P5 slices separately from the 97 broad requirements.
“Partial” or “uncertain” is not full capability completion. These
are building blocks to extend existing owners, not 97 new modules.

The [counted delivery plan](docs/planning/vocabulary-slices.md) maps every known
V-series requirement to **226 defined build/validation slices**: **106 verified,
120 not yet accepted** through the current independent reviews finalized on 2026-10-19. It owns slice IDs,
finish lines, prerequisites, phase counts and source follow-up. Count each slice
once even when several capabilities use it; the denominator measures defined
scope, not time or effort. Missing rule bodies can reveal additional work.

## Work order

Follow this sequence:

1. **Discover vocabulary.** Read descriptions and code enough to name distinct
   requirements. Consolidate repeated needs. No Godot, probes, catalog correctness
   ledger or content mutations. The completed discovery pass and remaining source
   gaps are recorded in the checklist.
2. **Build and production-validate the selected capability batch.** Implement
   shared operations and required world hooks, then exercise actual inputs,
   stages, results, choices/costs and source-owned state with bounded production
   Godot checks in the same owner-authorized work chat. Use small neutral examples
   as consumers; do not rewrite the spell/class/monster/item catalog.
3. **Review independently.** After the builder records commands, logs, receipts
   and limits, an independent review checks the source and production evidence,
   repairs reproduced defects and reconciles acceptance. Only then select the
   next batch.
4. **Translate content.** Convert definitions using the checked building blocks.
   Track separate content support; a verified building block does not certify
   every spell or class using it. Broader playing/usability checks follow useful
   content batches.

Testing is not part of discovery or roadmap preparation. Build and bounded
production validation are recorded together for an authorized batch; independent
review and acceptance remain separate. This sequence does not add a second engine
in Python.

## Accepted work and reuse

The [current checkpoint](docs/operations/current.md) records accepted behavior,
production evidence and exact host limits. The
[slice registry](docs/planning/vocabulary-slices.md) and
[checked subsets](docs/reviews/dnd-code-vocabulary-gap-checklist.md#checked-subsets-and-bounded-implementation)
retain the individual finish lines. Reuse those implementations and unchanged
proof; an open parent capability does not make its accepted subset new work.

The [historical batch narrative](docs/archive/planning/roadmap-accepted-batches-through-q.md)
preserves earlier receipts and status text. It is not a queue to resume. Current
proposals are batches 018-030 above; the Quest Board owns actual selection.

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
The locally inspected Foundry PHB/MM packs now supply candidate descriptions,
progression records and structured actions for selected source gaps. Use the
[Foundry adoption plan](docs/planning/foundry-adoption.md) to reuse that work;
Ravenloft remains optional later material. Source discovery and offline
conversion do not complete runtime slices or invalidate accepted evidence.
Do not resume the old all-record correctness audit. Missing source needed by a
chosen capability is resolved for that capability; unrelated catalog discovery
does not block work whose requirements are already concrete.

## Future map integration: walls and crossings

Add map walls as independent world-coordinate segments aligned with the map
image and our hex overlay, with separate movement and sight restrictions.
Doors use existing world-object open/closed/locked state. A shared boundary
query must serve player/AI paths, actual movement and visibility; door changes
refresh affected paths and sight. Reuse current A*, terrain and turn budgets.

Start with one small imported-map sample proving a solid wall, a window and an
openable door, including corners, narrow passages and creature clearance.
Rejected movement spends no distance; supported door state survives the existing
allowed checkpoint. Broader sound/light thresholds, directional restrictions,
levels/surfaces and arbitrary scene scripts are separate scope when needed.

This is future P7 world integration aligned with **S-179** (movement costs),
**S-184/S-185** (crossings/barriers) and **S-190** (observer obstruction).
Basic wall import does not by itself finish those broader slices. Coordinate
with Batch 030's physical/movement facts without expanding its three-slice
finish line into a full map importer. The
[adoption plan](docs/planning/foundry-adoption.md) records slice impacts and
the first sample's boundary. No implementation batch is selected here, and the
226-slice denominator and accepted counts remain unchanged.

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
