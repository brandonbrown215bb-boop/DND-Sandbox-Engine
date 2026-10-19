# ADR-0024: Explicit represented class levels for shared formulas

Date: 2026-10-15
Status: Accepted bounded implementation — VS-44, independent Batch F review (2026-10-15)

## Decision and reason

Store optional `Character.class_levels` as known class IDs with positive integral
levels, including the primary class and summing to character level. Existing
single-class state with no allocation keeps its current meaning. An explicitly
absent class is zero; malformed allocation is unavailable. This gives formulas
actual per-class inputs without borrowing total level or introducing a leveling UI.

Declared deterministic progression tables select numeric or supported die-size
rows with explicit below-first policy. Captured/live inputs follow S-036's cast
boundary. Source-owned pools recalculate capacity/size explicitly without refill
or source reacquisition. New definition IDs use the same runtime.

## Compatibility and scope

Persist allocations in the existing Character DTO, validate player and party
copies before session replacement, and preserve exact spent pool quantities and
source identities. Keep allowed checkpoints, legacy handling and 2024 namespaces.
Restore primary features through actual primary level without secondary grant
acquisition. Native level-up refuses explicit allocations until an authored class
update route exists. Full multiclass features, grants and spell-slot rules are
outside this formula/pool slice; a represented allocation does not certify them.

## Acceptance boundary and earlier decisions

Require real loaded numeric/die-size consumers, independent class/source values,
changes around capture, no refill on growth/shrink, fresh-process recovery and
malformed-save refusal. The independent [Batch F review](../../.artifacts/planning/vocabulary-reports/batch-F-review.md)
accepts that boundary as VS-44, with actual numeric/die-size consumers, fresh-process
recovery and a repaired live-only pre-cost availability guard. Full native multiclass
rules remain outside this acceptance.
ADR-0018/0023 continue to govern data ownership and staged delivery; this adds a
bounded represented input, without superseding their rules or ADR-0004 saves.
