# Work sites and helper proximity (S-066; PARTIAL)

Source: SRD 5.2.1 downtime/crafting work is done in one place, with helpers present. The engine adds no defaults (ADR-0018). Only an item's authored `work.site` declaration turns on these checks.

## Data
`work.site` = `{within_feet, on_away, away_limit_seconds?}`
- `within_feet`: a whole number, a multiple of 5, from 0 to 1000.
- `on_away`: `"pause"` or `"interrupt"`.
- `away_limit_seconds`: a whole number. Required for `pause` and forbidden for `interrupt`. No other keys are allowed.

## Location
`WorkRules.location(id)` reads `GameManager.active_dungeon_state`: the dungeon, the current local room and the participant's party position. No room, no position, or being contained means the location is unknown. An unknown location never satisfies proximity.

## Behaviour
- **Start** refuses an unknown location. It records `state.work_site` = {dungeon_id, room_id, position}, the exact start cell.
- **Join** (the Local room "Join work" control, through a confirmation menu) refuses:
  - incapacitated helpers
  - helpers whose location is unknown or in a different room
  - helpers farther than `within_feet` (hex distance × 5 ft)
  These checks run again at confirmation. Joining has no cost, so a refusal leaves state and the clock unchanged.
- **Accrual** (`settle` from `advance_campaign_time`): positions are constant within a span, so the span start is the boundary.
  - Anyone away under `interrupt`: the declared keep/reset policy applies at the span start.
  - Anyone away under `pause`: the pause starts at the span start (`work_away_since`). The policy applies only once the absence is **past** `away_limit_seconds` (strictly greater: `now > since + away_limit_seconds`); an absence of exactly the limit is allowed and keeps progress. The clock is whole seconds, so the lapse is recorded at `since + away_limit_seconds + 1`, even inside a long jump. Otherwise the span is not credited.
  - Return: the pause clears, and the return span itself is not credited.
- Existing single-job, rest-interruption, helper-concentration and participant-loss checks are unchanged. Site-less work (including legacy saves) behaves as before.

## Authored policy (Batch 082, #46 ruling)
Brandon's ruling: "the wording is 'past 1 hour': reset only after more than one hour; exactly one hour is allowed. Make the code, description and boundary checks agree. This is an authored interruption policy, not a universal crafting rule."
- The threshold is the item's own `away_limit_seconds`; the engine has no default limit.
- An item description that states the limit must say "past" that duration (the fixture loom: "an absence past 1 hour loses all progress").
- Items without `work.site`, or with `on_away: "interrupt"`, have no away-time reset rule.

## Saves
`work_site` and `work_away_since` are validated by `site_record_error`. Records without a site still load.

## PARTIAL
- Overworld and travel locations are unknown, so site work cannot run there.
- Movement inside a single clock jump is not modelled.
- Combat-grid positions are not used.
- The work site is the carried item's start cell, not a room object.
