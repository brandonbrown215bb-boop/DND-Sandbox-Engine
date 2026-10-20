# ADR-0034: Source-owned zero-HP attempts

Date: 2026-10-19
Status: Accepted bounded direction and implementation (VS-111/112)

## Decision and reason

Extend ADR-0019's existing zero-HP event adapter and shared ordered executor.
Do not create a second resilience interpreter or encode feature names. Author
eligibility and formulas on the rule; retain attempt/reset receipts by exact
actor/source. Immutable policy snapshots keep removed/reacquired sources from
resetting their history. Completed rests reset even retained detached histories.
Existing numeric pools own payment and remain independent of attempt history.
The latest attempt receipt captures the source's reset count. Save validation
checks the declared increment and whether current attempts belong to that same
reset generation or a later completed rest; lifetime totals alone cannot prove
that the current DC count is consistent.

Use the owned spell damage continuation for optional source authorization.
Capture the live source reference and policy, then recheck at the actual zero-HP
boundary. Weapon authorization is collected before the attack roll. An answer
alone never acquires uses, rolls a save or increments history. The original
primary weapon riders retain that same authorization and consumed flag by
reference. Preserve settled
parent work and original failed-save zero-HP consequences.

## Compatibility and acceptance boundary

ADR-0019's single executor, actor identity, clamped HP, no resurrection,
transient continuations, save namespace and safe-checkpoint guarantees remain.
Its unconditional competing-rule refusal is narrowed: an explicit source choice
can disambiguate eligible optional siblings; ambiguous automatic rules refuse.
Native Death Ward and Relentless Rage retain their existing order. Legacy saves
without history default to empty; no migration or save rewrite is introduced.
A zero-HP history receipt must include its reset count and coherent before/after
counts. Incomplete unaccepted Batch 033 history is refused rather than interpreted
as a new attempt or reset.

Only represented massive damage supplies the outright-death exclusion here.
Other instant death/destruction and forms remain later work. New saving throws
use existing automatic save resolution; post-roll rescue choices are outside this
bounded host. Dictionary creature history is encounter-local; Character history
is durable and validated on both DTO paths. Owner-authorized
[acceptance](../reviews/batch-033-acceptance.md) records S-117/S-118 as VS-111/112
after independent review and repair re-review. See
[authoring](../mechanics/shared-spells.md#authored-zero-hp-eligibility-and-owned-attempts-batch-033-vs-111112-accepted)
for syntax and supported hosts. Broad V-020/V-088 remain partial.
