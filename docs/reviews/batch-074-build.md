# Batch 074 build: S-066 work-site location and helper proximity

Done-means: "Work-site location and helper proximity (S-066): checked when helpers join and when time advances, with the interruption policy applied across long clock jumps."

Status: PARTIAL. See [contract](../mechanics/work-sites.md).

## Changes
- `WorkRules`: `site` policy validation, `location`, `site_error`, start/join site checks, `join_options`, pause/interrupt settlement at the span boundary with an exact lapse in long jumps, and `site_record_error` for saves.
- `GameManager.advance_campaign_time` reports settlement messages as notifications.
- Local room view:
  - "Join work" now uses a confirmation menu, re-checked at confirm.
  - New "Wait 8 hours" control.
- Fixtures: data/fixtures/batch_074 (loom: pause, 10 ft, 1 h limit, reset; kiln: interrupt, 0 ft, keep).

## Evidence (Godot 4.7.2, headless)
- Import ×2: no SCRIPT/Parse/Compile errors.
- Logic suite: 6177 passed, 0 failed (batch 073 baseline 6154). Batch074Checks covers:
  - policy mutations
  - unknown location
  - 15 ft vs exactly 10 ft
  - pause/resume
  - a 2-day jump lapsing at since+3600
  - a present multi-day jump
  - kiln interrupt with keep
  - leaving the room
  - legacy site-less work
  - JSON DTO round trip
  - record defects
  - legacy record load
- Scenarios (real controls):
  - `batch_074_work_site_flow` PASS: start, refuse at 15 ft with no change or time, dismiss, stale offer refused at confirm, join at 10 ft, Wait 8 h credits 28800, step away then 8 h resets, rejoin, pause, real save/load.
  - `batch_074_work_site_reload` PASS: fresh process load, then a 2-day jump applies the reset at exactly away_since + 3600.
- Regression scenarios PASS: batch_046_work_rescue_flow, batch_064_mode_duration_flow, batch_066_travel_placement_flow.

## Notes / open questions
- Joining has no cost, so "refuse before paying" means no state or clock change. No once-only join costs exist to test.
- PARTIAL:
  - Overworld and travel locations are unknown.
  - In-jump movement is not modelled.
  - Combat-grid positions are unused.
  - The site is the start cell, not a room object.
- The "Wait 8 hours" control was added so the clock can be advanced through the UI.
