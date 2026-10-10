# Documentation map

The project is moving toward one data-driven rules runtime. Existing named
helpers describe the migration starting point, not the design to repeat.

| Need | Read |
|---|---|
| Current priorities and delivery order | [Roadmap](../roadmap.md) |
| Latest accepted runtime evidence and unfinished work | [Current checkpoint](operations/current.md) |
| Current code boundaries and migration constraints | [Architecture](architecture/README.md) |
| Durable decisions, including supersession | [ADR index](decisions/README.md) |
| JSON authoring that works today | [Modding guide](modding_guide.md), [shared spells](mechanics/shared-spells.md) |
| Loading, collisions and import promotion | [Content pipeline](content_pipeline.md) |
| Development and proportionate verification | [Development](operations/development.md), [testing](testing.md), [runner contract](operations/validation.md) |
| Supported behavior and remaining clauses | [Behavior contracts](mechanics/README.md); [spell status](mechanics/spell-status.md) |
| Player presentation and visual evidence | [UI contract](ui/PLAYER_UI_CONTRACT.md), [visual acceptance](ui/VISUAL_ACCEPTANCE.md) |
| Rules-runtime design detail | [Class design](architecture/data-driven-2024-class-execution-plan.md), [creature design](architecture/data-driven-2024-monster-execution-plan.md) |

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

`gate0_evidence.md` through `gate8_evidence.md`, `defect_register.md`,
`CHANGELOG.md`, dated playtests and `reviews/` retain observations from named
snapshots. They do not set priorities, certify the current working tree, or
restore old gate blockers. Closed findings require reproduction before reopening.
The foundation wave documents retain useful capability gaps; their old wave
order no longer overrides the roadmap.

Inventory JSON and generated matrices describe records, not gameplay proof.
Raw third-party extracts and `.agents/` logs are references, not instructions.

## Keeping this small

Update the relevant contract when behavior changes. Replace the current
checkpoint instead of appending a diary. Keep one latest evidence summary with
its commands/log locators and explicit limits; raw run logs belong in ignored
artifacts. Put durable reasons in an ADR, changing its status and index when
superseded. Keep changed requirements in their owning document rather than
copying them into every guide. See [documentation maintenance](operations/documentation.md).
