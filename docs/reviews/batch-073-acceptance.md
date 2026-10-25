# Batch 073 acceptance review (S-119 explicit death without damage)

Reviewer: Runtime Reviewer. PR #45, reviewed head 749c0e7. Card Q-20261025-115746-b8f6 claimed (runtime-reviewer, 4h expiry).

Finish line (verbatim): "Explicit death or destruction without damage (S-119): living, already-zero and ineligible targets, with no duplicate remains or effects."

## Verdict
ACCEPT after one small fix (e816f8b). Finish line met for single-target creatures; PARTIAL items as stated by the builder.

## Defect fixed
- R1 (e816f8b): explicit death on a monster record left temp_hp in place on a dead body (the 071 zero-limit death clears it; the character path clears it via CorpseRules.mark_dead). Now cleared. Review checks added: temp HP ignored by the limit and cleared; PC target goes through mark_dead (death_save_failures 3, concentration ended, serial 1); limit+1 HP refused before cost with the slot untouched.

## Verified
- SRD 5.2.1 (from memory, no PDF): Power Word Kill kills a creature with 100 HP or fewer, otherwise 12d12 psychic; Disintegrate reduced to 0 HP is disintegrated (dust, gear except magic). Contract fits; the PWK damage fallback and native conversions are PARTIAL.
- HP limit reads current_hp only; temp HP does not count (SRD says Hit Points; temp HP are not HP). Decision flagged below.
- Pre-cost: validate_creatures_and_components refuses before any slot is spent; settle_explicit rechecks at resolve and returns applied=false with no state change; no second charge path exists in the resolver.
- Death hooks: characters reuse CorpseRules.mark_dead (concentration, rage, wild shape, death saves); monsters reuse the 071 aftermath field. Monster-held concentration/summons on explicit death are no better or worse than the damage path.
- Incapacitated casters: unchanged generic cast gate; nothing new in this PR.
- Legacy saves: no new saved fields; cause_source absent still loads.
- No per-ID branches in src/combat or src/spells.

## Questboard
Q-20261021-172804-829a (065) had owner runtime-reviewer with claim_expires_at null: our stale 065 claim. Released via handoff (owner null, status review, next brandon). doctor healthy.

## Tests
Imports x2 clean. Logic 6157 passed / 0 failed (builder 6154 + 3 review checks). Scenarios one at a time, all pass, no SCRIPT ERROR: batch_073_explicit_death_flow, _reload, batch_034_aftermath_flow, batch_059_corpse_limit_flow, batch_071 flow/reload, batch_072 flow/reload. No regressions vs the 066 main failure list.

## Open decisions for Brandon
1. Temp HP and the HP limit: keep "current HP only" (SRD-literal) or count temp HP?
2. Monster concentration/summons on monster death: card for a shared death hook?
3. Cards for PWK 12d12 fallback, native Disintegrate/PWK conversion, objects, successors, multi-target?
