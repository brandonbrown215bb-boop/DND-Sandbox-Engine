# ADR-0029: Party roll contributions and allocations

Date: 2026-10-17
Status: Accepted bounded implementation (VS-64/65/66/67, independent Batch Q review)

## Decision and reason

Extend the existing captured weapon-attack choice with a recipient's shared
captured gift or another willing party Character's fixed numeric contribution.
The contributing Character owns its Reaction and exact source payment; the
original attack request retains the natural roll, defender, AC, action payment
and continuation. Reuse ordinary attack settlement instead of replaying attacks
or creating another roll interpreter. Bind exact source objects as well as IDs
so removal/reacquisition while a chooser is open cannot revive old authority.

Keep allocation in one transient combat request. Validate the complete recipient,
amount and exact-die selection before applying consequences. Fixed budgets and
selected captured dice pay only on valid confirmation. A rolled total pays its
one source quantity/action when revealed; cancel/refusal forfeits that total.
This explicit policy prevents free repeated reveals. Selected dice spend their
actual identities, retaining the unselected ordered pool subset and its serials.

## Acceptance and retained guarantees

The bounded production hosts are the Features/source allocation menus and
normal player weapon Attack/Extra Attack. Neutral and renamed loaded data,
actual controls, exact payments, stale/replay refusal and fresh-process recovery
are required evidence. Independent review accepts S-083's shared captured bonus
as VS-64 before dependent S-097's fixed helping modifier as VS-65; S-101/S-102
integer and rolled/exact-dice allocations are VS-66/67. The slice's one supported
intervention operation does not certify defensive/outcome/reroll/token operations.
The [review](../../.artifacts/planning/vocabulary-reports/batch-Q-review.md) owns
the production evidence; no broad capability or catalog completion follows from this ADR.

ADR-0018's shared runtime, ADR-0027's captured source identities and ADR-0028's
recipient/giver ownership and independent deadlines remain binding. This extends
ADR-0028's consumer list and supersedes its S-083-partial acceptance status with a
shared captured weapon-attack bonus; it does not
make a gift a casting permission or natural-result replacement token. Completed
changes reuse existing Character/pool/save fields and preflight. Requests remain
transient, legacy namespaces remain, and no mid-combat/mid-choice save, migration,
new service, content-ID branch or catalog conversion is introduced.

Other roll hosts, defense/reroll/token interventions, broader actor origins,
range/sense predicates and arbitrary allocation effects remain separate work.
The [authoring contract](../mechanics/party-intervention-and-allocation.md) owns
the implemented syntax, policies and precise limits.
