# Batch 082 acceptance — S-066 past-1-hour boundary (#46 follow-up), PR #55

**Verdict: ACCEPT (partial as declared). No code fixes.** Reviewed head 3ff91dc against Brandon's ruling as quoted by the builder.

## Evidence
- Import x2 clean. Logic: 6333 passed, 0 failed, no SCRIPT ERROR.
- Scenarios (one at a time, no SCRIPT ERROR): PASS batch_082_interruption_boundary_flow/reload, batch_074_work_site_flow/reload, batch_081_declared_fallback_flow/reload, batch_046_work_rescue_flow, numeric_pool_rest_recovery_normal_controls_flow, short_rest_arcane_recovery_normal_controls_flow. FAIL cleric_divine_intervention_recovery_rests, numeric_pool_rest_recovery_acceptance — both already failing on the 074 base; not regressions.

## Focus areas
1. **Boundary.** `settle` uses `now > since + limit`; `at = limit + 1`. Clock is whole-second end to end: `settle(int, int)`, `work_away_since` read via `int()`, `away_limit_seconds` validated by `_whole` (1..31536000). No float time source reaches the comparison, so 3600.5 cannot occur. 3600 keeps, 3601 lapses (082 checks + 074 moved assertions). Reload/fresh-process lapse at since+3601 asserted. Legacy: a save already lapsed under `>=` has no active work/site left, so nothing un-lapses; a save paused exactly at the limit (only possible if saved mid-span) now keeps work until +3601 — that is the ruling, not a defect.
2. **074 unchanged.** The 074 diff is only `+3600`→`+3601` and message wording. Join-work incapacitation refusal untouched. No default limit (pause requires an authored limit; interrupt forbids one). Site-less work has no reset path.
3. **Dice check.** Gate = existing regex `^([0-9]{1,3}|[1-9][0-9]?d(4|6|8|10|12|20))([+][0-9]{1,3})?$` (spaces stripped) + new "contains d". The regex already rejected malformed dice; the new gate only removes bare constants.

| input | result |
|---|---|
| d, d12, 5d, dx, 1d, abc d, 0d12, 12d0 | refused (regex) |
| 5, 5+3 | refused (new d gate) |
| 12d12-5, 1d6+1d4 | refused (regex; no minus / multi-term) |
| 12d12+5, 2d8+4, " 12d12 " | pass; parser strip_edges handles padding |

Nothing malformed passes. Nit: internal spaces ("12 d12") pass validation; the parser only strips edges. Untested at runtime — worth a one-line `replace(" ","")` in a later batch.

Wording: no "at least"/`>=` near away_limit in code or docs. ADR-0018: no per-ID branches added. Refusal-before-cost unaffected (Join has no cost; fallback check is validation-time).

## Proposed counts
Logic 6333/0.
