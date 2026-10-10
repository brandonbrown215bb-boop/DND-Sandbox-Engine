# ADR-0005: Extend Fighter progression through level 20

> Migration scope (2026-10-09): [ADR-0018](0018-shared-data-driven-rules-runtime.md)
> governs new rule execution. Named modules below describe current owners,
> not permanent native handlers for content policy. Identity, ordering,
> cost and compatibility guarantees remain constraints. Dated implementation
> and validation statements describe this ADR's original snapshot.

Date: 2026-10-03
Status: Accepted

The owner explicitly requested Fighter features at levels 1–20, extending this
class beyond ADR-0004's original level-5 mechanics milestone.

## Decision

Use SRD 5.2.1 Fighter and Champion progression. Keep saved choices on Character
and expose them in the existing Character Sheet. `FighterRules` owns training,
progression helpers and non-positional rules; CombatAction owns settled attacks;
CombatState owns prompts, positions and turn sequencing. No new rules service
or wholesale combat extraction is required.

Represent Action Surge as an additional restricted action in CombatTurnBudget.
Magic consumes the ordinary action. Resolve commands from production records
before spending resources, so caller-supplied costs cannot bypass restrictions.

Keep regular ability improvements and Combat Prowess as the implemented feat
choices. Unimplemented alternatives remain unavailable. Preserve spent pools
across levels, combat starts and save/load; only gained capacity or the specified
rest recovery adds uses. New training fields are validated before save loading
mutates active managers. Missing fields in earlier schema-2 saves receive defaults.

Crown's encounter and reward progression remains levels 1–5. Level-20 mechanics
do not imply a new campaign or complete tabletop/creation coverage. The mechanics
document records remaining interface and reaction limits.
