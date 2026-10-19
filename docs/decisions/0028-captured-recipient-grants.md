# ADR-0028: Captured recipient grants

Date: 2026-10-17
Status: Accepted bounded direction and S-082 implementation (VS-63); S-083 consumer extension accepted in ADR-0029 (VS-64)

## Decision and reason

Keep transferred grants on the receiving Character, separate from the giver's
remaining pool. A committed transfer captures giver/source/recipient identity,
generation values, consumer permission, recipient use cost and campaign deadline.
Later giver progression or source removal cannot rewrite that independent gift.
Reuse ResourcePoolRules for exactly one original quantity payment, existing
CombatTurnBudget/Character Reaction ownership for recipient spending, and the
production CombatCommand/Features menu route for both operations.

One shared die is rolled only after the entire recipient selection validates;
each beneficiary retains the same face and consumes its own grant once. An
existing captured pool die moves with its original payload and no additional
roll. Giver-owned transfer serials survive pool removal. Once a source transfers
captured dice, retain its die serial high-water mark across removal/reacquisition
so acquisition cannot regenerate transferred identities.

The combat host owns transient exact-object requests. Saving keeps only committed
recipient records and giver serial state. Preflight validates both existing DTO
paths plus cross-actor shared value, serial and die-ownership links before
replacing a session. Existing fields default empty for older saves, retaining
existing namespaces and permitted checkpoints. No acquisition replay, migration,
mid-combat save permission or new service is introduced.

## Acceptance boundary

Batch P uses loaded neutral/renamed class definitions, living willing Character
combat recipients, one-quantity pool payment, and explicit own-turn recipient
Action/Bonus Action/Reaction commands. Consumers are self-healing and normal
Temporary HP; formula tokens/permissions are those bounded single-use benefits,
not casting rights or pre-roll replacement tokens. Actual controls, unchanged
captured-pool regressions, distinct-process recovery, original expiry, serial
continuation and malformed-save refusal provide the evidence for independent
S-082 acceptance as VS-63. Batch P left S-083 partial because its rolled bonus
consumer was missing. ADR-0029 extends this consumer boundary with the shared
captured weapon-attack bonus and recipient Reaction, independently accepted as
VS-64 in [Batch Q review](../../.artifacts/planning/vocabulary-reports/batch-Q-review.md).
S-051's existing acceptance is reused rather than counted again. See
the [independent review](../../.artifacts/planning/vocabulary-reports/batch-P-review.md).

This extends ADR-0018's source ownership and ADR-0027's captured dice without
superseding their current host, new-dice-only progression or save boundaries.
Broader transfer origins, other roll consumers/interventions and catalog
conversion remain separate capabilities. The current authoring contract is
[captured grants](../mechanics/captured-grants.md).
