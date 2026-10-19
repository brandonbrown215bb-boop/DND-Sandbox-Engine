# ADR-0026: Derive bounded benefits from their existing carriers

Date: 2026-10-16
Status: Accepted bounded direction and behavior (VS-59/60), independently reviewed

## Decision

For the bounded fixed AC/walking-speed payload, reuse item-copy identity,
progression feature/selection-occurrence identity, and SpellEffects cast serials.
Read equipped items and selected progression benefits rather than copying their
additions into permanent Character stats. Cast payloads use the existing timed
spell record and cleanup. All three hosts expose the same source receipts and
stat consumers through SourceBenefitRules.

A progression source identifies an entitlement/selected occurrence, not a new
generation each time an option is selected. Independent repeated selection slots
remain distinct. This projection has no accumulated uses, timer or acquisition
side effect requiring another acquisition ledger. If later work needs such state,
it must define that state and lifetime explicitly instead of reusing the derived
entitlement as a fresh timed instance.

The bounded operation adds all eligible independent authored sources. Named rule
nonstacking and other combination policies remain unsupported. Self-only flat
spell carriers are a checked host boundary, not general cross-actor grants.

## Reason and retained guarantees

The actual carriers already own identity and removal. Storing derived bonuses a
second time would allow stale grants after equipment/replacement and replay on
load. Preserve ADR-0018's shared runtime and exact sources, ADR-0013's item-copy
ownership, and ADR-0004's save boundary. Validate saved cast payloads and original
identities before replacing a session; restore existing state without acquisition.
No prior ADR is superseded. See the [authoring contract](../mechanics/source-benefit-carriers.md)
for executable syntax, controls and limitations.
