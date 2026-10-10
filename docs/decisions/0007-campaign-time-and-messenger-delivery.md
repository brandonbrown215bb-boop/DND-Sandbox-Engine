# ADR-0007: Campaign time for Animal Messenger

> Migration scope (2026-10-09): [ADR-0018](0018-shared-data-driven-rules-runtime.md)
> governs new rule execution. Named modules below describe current owners,
> not permanent native handlers for content policy. Identity, ordering,
> cost and compatibility guarantees remain constraints. Dated implementation
> and validation statements describe this ADR's original snapshot.

Status: Accepted, 2026-10-05.

## Context

Animal Messenger measures travel in miles per 24 hours and expires after a
duration measured in days. The overworld previously had no campaign clock, and
visited locations were not retained for use as spell destinations.

## Decision

- Store campaign time, visited locations, and active messenger deliveries in
  the existing GameManager campaign ledger and persist them through SaveManager.
- Use axial hex distance with a campaign-declared `miles_per_hex` value. The
  Lost Crown campaign sets that value to five miles per hex.
- Advance the clock by 24 hours after a full overworld round and eight hours
  after an eight-hour rest.
- Keep order validation, route progress, expiry, and delivery record validation
  in `AnimalMessengerRules`; keep UI prompts in CombatHUD and campaign ownership
  in GameManager.

## Consequences

The 25/50-mile daily travel rates now resolve against the existing map without
adding a separate route system. Campaign saves retain active travel and legacy
saves load with empty ledgers. Campaigns using a different map scale can set
their own miles per hex. Other effects do not use the campaign clock yet.
