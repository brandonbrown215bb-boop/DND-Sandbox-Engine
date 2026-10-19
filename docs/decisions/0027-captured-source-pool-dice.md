# ADR-0027: Captured source-pool dice

Date: 2026-10-17
Status: Accepted bounded implementation (VS-61, independent Batch M review)

## Decision and reason

Extend the existing source-owned dice pool with an opt-in `capture_policy:
"on_acquire"` and explicit `upgrade_policy: "new_dice_only"`. Capture each
available die once when acquired or recovered. Retain its owner, exact source,
monotonic source-local identity, face, original size and generation level in
the existing Character pool DTO. Equal faces are separate dice.

Capacity and future die sizes reuse the existing declared formula tables.
Recalculation preserves remaining dice and does not refill. Shrink keeps the
oldest remaining dice up to capacity. Recovery adds only vacant quantities;
new dice use the recalculated size. Existing dice keep their captured size and
face across progression, rest, and checkpoint recovery.

The existing self-healing activation spends the oldest selected quantity and
uses those captured faces without another roll. Its normal quantity menu shows
the faces and original sizes before spending. There is no new roll interpreter,
transfer mechanism or resource service.

## Ownership and compatibility

Omitting both policies preserves roll-on-spend behavior. Partial or unknown
policies refuse definition validation. Capture policy cannot be switched on an
existing pool by recalculation/recovery. Numeric exchanges and numeric payment
reservations cannot consume captured pools. Exact source removal removes that
source's inventory; identities are scoped to that source occurrence.

Allowed checkpoints retain remaining dice and serials without acquisition or
RNG replay. Both full-save DTO paths validate faces, sizes, quantities, order,
identities and policy before replacing live state. The authored class/subclass
pool policy also detects stripped captured metadata. Existing save namespaces,
legacy isolation and checkpoint boundaries remain unchanged. No migration or
mid-decision saving is added.

## Acceptance boundary and earlier decisions

This extends ADR-0018's shared runtime and ADR-0024's explicit class-level tables.
Their definition/source ownership and no-refill guarantees remain binding, as
do ADR-0004/0023's checkpoint boundaries. It supersedes no existing decision.

S-051 evidence must show neutral and changed definitions, actual feature and
rest controls, equal-face identity, mixed-size retained generations, refusal
before expenditure, and separate-process recovery/malformed-save refusal.
The [independent review](../../.artifacts/planning/vocabulary-reports/batch-M-review.md)
accepts S-051 as VS-61 within this boundary. Transfers, arbitrary die selection, new
roll consumers, replacement tokens, and alternative upgrade policies remain
separate extensions. ADR-0028/VS-63 subsequently adds transfer; ADR-0029/VS-64/67
adds shared captured weapon-attack bonuses and exact-die HP/Temporary HP allocation.
Those extensions retain this decision's source, identity, progression and save guarantees.
