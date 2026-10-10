# ADR-0011: Initial player spell-cast split

Date: 2026-10-06
Status: Superseded by [ADR-0012](0012-focused-spell-resolution-and-lifecycle.md)

The first extraction split a large player-cast function into preparation,
resources and targeting, leaving a visible ordered controller sequence.
ADR-0012 completed the responsibility split. Use its module map and
[ADR-0018](0018-shared-data-driven-rules-runtime.md) for further work; the
initial three-module layout is no longer a target or unfinished prerequisite.

Retained guarantees: a transient cast context carries one request and stage
results; it is not save data. Validation, choices, resource commitment,
reactions and results have explicit order. Per-target handling does not pay
cast-wide costs again. Source ownership and awaited movement/area triggers
remain intact. The extraction preserved existing cancellation behavior;
some late choices still occur after resource spending, which needs separate
production verification when changed. A file split alone never establishes
data-only content authoring or new rules support.
