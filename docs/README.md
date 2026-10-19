# Documentation map

The project is moving toward one data-driven rules runtime. Existing named
helpers describe the migration starting point, not the design to repeat.

Use this map to find the selected task's owner. Current work starts with the
roadmap and checkpoint; historical documents are physically separated under
[archive/](archive/README.md). Do not use an old gate, completed prompt or
generated inventory to choose the next implementation.

| Need | Read |
|---|---|
| Current priorities and delivery order | [Roadmap](../roadmap.md) |
| Concurrent runtime and editor ownership; Luna/Antigravity briefs | [Parallel pipelines](planning/runtime-editor-parallel-pipelines.md) |
| Latest accepted runtime evidence and unfinished work | [Current checkpoint](operations/current.md) |
| Current code boundaries and migration constraints | [Architecture](architecture/README.md) |
| Revised class reference extracts, separated from mixed-edition inputs | [2024 source view](../reference/2024/README.md) |
| Durable decisions, including supersession | [ADR index](decisions/README.md) |
| JSON authoring that works today | [Modding guide](modding_guide.md), [shared spells](mechanics/shared-spells.md) |
| Loading, collisions and import promotion | [Content pipeline](content_pipeline.md) |
| Development and proportionate verification | [Development](operations/development.md), [testing](testing.md), [runner contract](operations/validation.md) |
| Supported behavior and remaining clauses | [Behavior contracts](mechanics/README.md); [spell status](mechanics/spell-status.md) |
| Purpose-aware event checks and owned-tool authoring | [Check context](mechanics/purpose-aware-check-context.md) |
| Owned post-roll ability-check modifier authoring | [Check modifiers](mechanics/owned-ability-check-modifiers.md) |
| Starting/multiclass acquisition and permanent level gains | [Permanent progression](mechanics/permanent-progression.md) |
| Party roll contributions and allocations | [Party rules](mechanics/party-intervention-and-allocation.md) |
| Captured recipient gifts and use budgets | [Captured grants](mechanics/captured-grants.md) |
| Exact item/cast/progression benefit carriers | [Source carriers](mechanics/source-benefit-carriers.md) |
| Shared spell source-end authoring and event facts | [Source-end rules](mechanics/source-end-rules.md) |
| Casting sources, payment and independent preparation | [Spell permissions](mechanics/spell-permissions-and-preparation.md) |
| Attack/Flurry substitutions and paid child continuations | [Child action authoring](mechanics/attack-unit-substitution.md) |
| Combined spell slots, fixed-level uses and ritual access | [Spell slots and rituals](mechanics/spell-slots-and-ritual-casting.md) |
| Shared repeat-save scheduling, staged conditions and DC history | [Shared spells](mechanics/shared-spells.md#conditions-lifetime-and-other-supported-fields) |
| Source-owned AC/score protections and recipient selection | [Stat protections](mechanics/source-owned-stat-protections.md) |
| Player presentation and visual evidence | [UI contract](ui/PLAYER_UI_CONTRACT.md), [visual acceptance](ui/VISUAL_ACCEPTANCE.md) |
| Rules-runtime design detail | [Class design](architecture/data-driven-2024-class-execution-plan.md), [creature design](architecture/data-driven-2024-monster-execution-plan.md) |
| Code building blocks, checked subsets and remaining scope | [Vocabulary checklist](reviews/dnd-code-vocabulary-gap-checklist.md) |
| Post-Batch-F progress, consolidation and workflow assessment | [Progress review](reviews/vocabulary-progress-after-batch-f-2026-10-15.md) |
| Countable build/validation chunks, prerequisites and whole-scope denominator | [Vocabulary delivery slices](planning/vocabulary-slices.md) |
| Proposed next batches after Q, numbered 018-030 | [Numbered batch outline](planning/vocabulary-batches-018-030.md) |
| Foundry import guidance and source-backed subsystem opportunities | [Adoption plan](planning/foundry-adoption.md), [systems review](reviews/foundry-systems-adoption-review-2026-10-17.md) |
| Completed A-I fresh-chat prompts and retained build/review workflow | [Historical next-26 prompt pack](archive/planning/vocabulary-next-26-prompts.md), [prompt workflow](planning/vocabulary-prompt-workflow.md) |
| Dated runtime-gap research; reproduce relevant findings before treating them as current defects | [Wiring snapshot](reviews/dnd-runtime-wiring-map.md), [structural snapshot](reviews/dnd-data-runtime-gap-review.md), [description coverage](reviews/dnd-description-runtime-review.md) |

## Authority

Owner instructions take precedence. The roadmap chooses work; the Quest Board
records ownership and the exact next action. Accepted ADRs explain durable
decisions. Architecture describes current boundaries. Source and production
Godot checks determine what actually runs. A discrepancy is a documentation
or implementation defect to resolve, not permission to revive an older plan.

The two engine design documents are working specifications. Their direction is
accepted in [ADR-0018](decisions/0018-shared-data-driven-rules-runtime.md);
their proposed syntax, complete catalogs and phase plans are not implemented
or individually approved. Use the roadmap to select a small proof, rather than
executing both documents as independent projects.

## Historical material

[Archived gates and reports](archive/README.md), completed prompts and old
checkpoints retain observations from named snapshots. Dated `reviews/` research
also describes its named source, not the whole current working tree. None sets
priorities or restores old gate blockers. Closed findings require reproduction
before reopening. Foundation wave documents retain useful capability gaps;
their historical order does not override the roadmap.

Inventory JSON and generated matrices describe records, not gameplay proof.
Raw third-party extracts and `.agents/` logs are references, not instructions.

## Keeping this small

Update the relevant contract when behavior changes. Replace the current
checkpoint instead of appending a diary. Keep one latest evidence summary with
its commands/log locators and explicit limits; raw run logs belong in ignored
artifacts. Put durable reasons in an ADR, changing its status and index when
superseded. Keep changed requirements in their owning document rather than
copying them into every guide. See [documentation maintenance](operations/documentation.md).
