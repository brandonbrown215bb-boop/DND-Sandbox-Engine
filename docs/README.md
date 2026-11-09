# Documentation map

Start with the owner's request and [roadmap](../roadmap.md), then read the
selected slice and technical reference. Source and production Godot checks decide
what runs; inventories, descriptions and planned syntax don't establish support.

| Need | Read |
|---|---|
| Complete Crown cross-set engine mapping, blockers and next bounded assignment | [Mapping and implementation queue](planning/crown-engine-mapping/README.md) |
| Crown map/dungeons, events, objects, hazards/supplies, objectives/rewards and spell/character world dependencies | [World/event/object candidates](planning/preparation/crown-world/README.md) |
| Current priority and delivery order | [Roadmap](../roadmap.md) |
| All 183 Crown spell candidates and their grouped mapping requirements | [Spell authoring folder](planning/preparation/crown-spells/README.md) |
| Crown classes/subclasses through 5, multiclass grants, invocations, Metamagic, species, backgrounds and feats | [Character/origin candidates](planning/preparation/crown-characters/README.md) |
| Starting equipment, full packs, ammunition, tool choices, focuses and background items | [Equipment candidates](planning/preparation/crown-equipment/README.md) |
| Remaining Crown shop/reward items, exact spell materials and physical creations | [Reachable-item candidates](planning/preparation/crown-reachable-items/README.md) |
| Crown encounters/companions, complete in-band creature forms, created actors and spell-owned effects | [Creature/actor candidates](planning/preparation/crown-creatures/README.md) |
| Slice requirements, prerequisites, status and verified boundaries | [Slice registry](planning/vocabulary-slices.md) |
| Broader capability requirements and source gaps | [Vocabulary checklist](reviews/dnd-code-vocabulary-gap-checklist.md) |
| Current code ownership and migration boundaries | [Architecture](architecture/README.md) |
| Executable JSON syntax and supported hosts | [Mechanics](mechanics/README.md), [modding guide](modding_guide.md) |
| Loading, source preparation and editor handoffs | [Content pipeline](content_pipeline.md) |
| Recovered local sources, prior reviews and Crown candidate drafts | [Source locations and limits](content_pipeline.md#recovered-local-inputs--2026-11-08), [Crown reconciliation](planning/crown-roadmap.md#authoring-reconciliation--2026-11-08) |
| Revised class source extracts | [2024 source view](../reference/2024/README.md) |
| Durable design decisions | [ADRs](decisions/README.md) |
| Commands and proportionate checks | [Development](operations/development.md), [testing](testing.md), [runner](operations/validation.md) |
| Spell-specific delivery limits | [Spell status](mechanics/spell-status.md) |
| UI behavior and selected visual references | [UI contract](ui/PLAYER_UI_CONTRACT.md), [visual checks](ui/VISUAL_ACCEPTANCE.md) |
| Detailed target engine specifications | [Class design](architecture/data-driven-2024-class-execution-plan.md), [creature design](architecture/data-driven-2024-monster-execution-plan.md) |

The design documents describe target capabilities, not executable syntax or
independent work queues. Existing named helpers are migration code under
ADR-0018. The slice registry distinguishes verified subsets from broad goals;
none of those statuses certifies every catalog consumer.

Update the reference whose behavior changed. Keep slice status in the registry,
code ownership in architecture, authoring limits in mechanics, and durable
reasons in ADRs. Summarize relevant checks in the conversation or an existing PR;
raw logs belong in ignored artifacts. Separate acceptance documents aren't needed.
Quest Board is optional coordination for concurrent work, not a task requirement.
Committed process history is available in Git rather than a second archive tree.

Historical audit judgments and their frozen source bindings remain under
`reviews/`; see [audit inputs and outputs](content_pipeline.md#historical-audit-inputs).
They are dated research, not current support certification or a queue to resume.
