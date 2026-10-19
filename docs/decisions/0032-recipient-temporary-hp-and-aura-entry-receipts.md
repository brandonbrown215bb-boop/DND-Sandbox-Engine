# ADR-0032: Recipient Temporary HP and aura entry receipts

Date: 2026-10-18
Status: Accepted bounded direction and S-078/S-079/S-081 implementation (VS-84/85/86)

## Decision and reason

Keep a settled Temporary HP grant on its recipient, with separate supplier,
source, monotonic supplier serial, original payload and campaign deadline.
The supplier's current amount or level is not a substitute for the captured
grant. A recipient may retain existing HP or replace it with a smaller incoming
grant. Retaining/canceling does not pay, refill or reset either grant.
Linked fixed AC/save benefits are derived from surviving qualifying HP;
replacement, depletion, explicit source removal and expiry end that relationship.

Keep chosen aura entry receipts separately from live spatial membership.
Membership-only benefits query current positions and bearer eligibility; combat
exit clears that transient membership without deleting timed entry receipts.
Explicit once-per-source timed entry benefits retain their original deadline
after exit; their receipts survive expiry and reload to prevent reacquisition.
Choose one exact source per nonstacking group, retaining independent groups.
These facts extend the existing Character, aura, feature, command and save owners.

## Compatibility and acceptance boundary

ADR-0018's data-driven shared runtime and ADR-0023's bounded delivery still
govern. ADR-0028's captured gifts are separate consumers; existing keep-higher
spell/gift/allocation paths are not silently changed by this new opt-in feature.
No new save namespace, automatic migration or combat-decision checkpoint is added.
Both full-save DTO routes validate settled state and participant links before
live replacement. Existing source ownership and cost guarantees remain binding.

Production Godot controls, renamed loaded fixtures and distinct-process recovery
must establish the bounded behavior. Builder checks do not count as independent
slice acceptance. Monster hosts, transferred bearers, arbitrary benefit payloads,
turn-relative lingering timers and resettable aura entry uses remain separate work.
The mechanics contract owns syntax; the build report owns transient evidence.

Independent [Batch 027 review](../../.artifacts/planning/vocabulary-reports/batch-027-review.md)
accepts these three bounded slices after repairing combat-exit membership cleanup.
