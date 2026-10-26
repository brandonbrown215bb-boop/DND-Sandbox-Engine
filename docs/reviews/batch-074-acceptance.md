# Batch 074 acceptance review (S-066 item work sites) — Runtime Reviewer

Done-means (verbatim): "Work-site location and helper proximity (S-066): checked when helpers join and when time advances, with the interruption policy applied across long clock jumps."

Verdict: ACCEPT after R1 (PARTIAL as declared). Reviewed cdffafa on base 4a77ab7.

## Defect
- R1 (ba1fda8): `join_error` only checked the literal `incapacitated` condition, so a Stunned, Paralyzed, Unconscious or Petrified helper in range could join (0/4 refused). It now refuses any condition that includes Incapacitated. The new check fails without the fix.

## Requested confirmations
- (a) Wait 8 hours: it only advances the campaign clock through `advance_campaign_time`. It grants no long or short rest, removes no exhaustion, and expiring effects end on the normal path. It exists only in the room view, so it isn't offered in combat. It is NOT gated on hostiles in the room or on an incapacitated party (open decision).
- (b) Join work: it always confirms and is rechecked at the pick, so a stale offer is refused. Incapacitated helpers are refused (after R1).
- (c) No join cost: this matches SRD 5.2.1. Helpers share the work time, and progress accrues only while the work is actually being done.

## Verified
Pause time is measured from the original `work_away_since` across several jumps and across save/load. The lapse is at since+limit. Reset loses all progress, keep keeps it. Progress is stored on the item, so a helper rejoining can't count it twice. The resume span credits nothing. Legacy work without a site is unchanged. Saved-state validation covers the site and away fields. There are no per-ID branches.
Exact boundary: `now >= since + limit` lapses, so being away exactly 1h resets, while the fixture text says "past 1 hour" (open decision).

## Tests
Logic 6178/0 (base 6177/0). Scenarios batch_074_work_site_flow, batch_074_work_site_reload, 046_work_rescue, 064, 066, save_load and dungeon pass. cleric_divine_intervention_recovery_rests and numeric_pool_rest_recovery_acceptance fail identically on base 4a77ab7, so they are not regressions. No SCRIPT ERROR.
