# Batch 082 build: S-066 past-1-hour interruption boundary (#46 follow-up)

Stacked on `batch-081-declared-fallback` (PR #54, incl. reviewer commits 82218e0, db3e54a).

Done means (Brandon's ruling, verbatim): "the wording is 'past 1 hour': reset only after more than one hour; exactly one hour is allowed. Make the code, description and boundary checks agree. This is an authored interruption policy, not a universal crafting rule."

## Changes
- `WorkRules.settle`: paused site work lapses only when `now > away_since + away_limit_seconds` (was `>=`). With a whole-second clock, the lapse is recorded at `away_since + away_limit_seconds + 1`. Exactly the limit keeps progress.
- The threshold stays the item's own authored `work.site.away_limit_seconds`; no engine default. Site-less work and `on_away: "interrupt"` sites have no away/reset limit (interrupt sites still refuse a declared limit).
- Code comment, `docs/mechanics/work-sites.md` and the S-066 registry row now say "past" and describe it as per-site authored policy. The fixture loom's description already says "an absence past 1 hour loses all progress"; checks assert it matches the 3600 s limit.
- Batch 074 boundary assertions updated from `+3600` to `+3601` (no other 074 behaviour changed).
- Fold-in (#54 nit): `settle_death` fallback damage must contain a die (a bare "5" is refused).

## Evidence
- Imported twice; no SCRIPT/Parse/Compile errors.
- Logic: 6333 passed, 0 failed (+14: `Batch082Checks`).
  - 3599 s and 3600 s away keep progress and resume; 3601 s and 3660 s reset at away_since + 3601.
  - One jump ending exactly at the limit is allowed; one more second resets.
  - JSON round trip: exactly 1 hour kept, past it resets.
  - No site policy: no reset rule; interrupt sites refuse an away limit.
  - Flat "5" fallback refused; PWK 12d12 still valid.
- Scenarios: `batch_082_interruption_boundary_flow` PASS (real Start/Join/Wait 8 hours controls: exactly 60 min away keeps progress, 61 min resets, description matches, real save/load mid-pause), `batch_082_interruption_boundary_reload` PASS (fresh process: remaining time reaches exactly the limit → kept; +1 s → reset), `batch_074_work_site_flow` PASS, `batch_074_work_site_reload` PASS, `batch_081_declared_fallback_flow` PASS.

## PARTIAL (unchanged)
- Overworld/travel locations are unknown, so site work cannot run there.
- Movement inside a single clock jump is not modelled.
- Combat-grid positions are not used; the site is the start cell, not a room object.
- Description/limit agreement is checked for authored fixtures, not machine-validated for every item description.
