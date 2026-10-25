# Batch 079 acceptance (PR #52) - Runtime Reviewer

**Verdict: ACCEPT (partial, as declared). No code fixes.** Judged against the finish line as the builder quotes it in the PR (builder-quoted; original ruling not seen).

## Evidence (head 2221b7f)
- Logic: 6270 passed, 0 failed (+24). No SCRIPT ERROR.
- Scenarios (one at a time), all pass, 0 SCRIPT ERROR: batch_079_max_hp_stacking_flow, batch_079_max_hp_stacking_reload, batch_071_monster_max_hp_flow, batch_071_monster_max_hp_reload, batch_035_profile_max_hp_flow, batch_039_created_actor_flow. Full set not run.
- Headless stress script (not committed) against MaxHpSourceRules.

## Focus areas
1. **Legacy boundary: holds.** `validate_rule(rule, true)` is called only from `apply()`. DataLoader (monster attacks) and SharedSpell validation call it without the flag, so new data needs `combine` (and `accumulate` on reductions). The flag can't be set from data: a `legacy` key in the rule fails on the missing combine policy, and the field is unknown anyway. Unknown `combine` is refused even on the legacy path. A non-bool `accumulate` is refused.
2. **Tie-break: deterministic.** `applied_seq` = max over the actor's sources + 1. Equal strength goes to the newest (verified). Legacy entries (0) lose ties to any new entry. Two legacy entries fall back to dictionary order, which survives JSON save/load. Removing the newest source lets the next one reuse its number, but it's still above every remaining source, so no wrong tie. Saved values are range-checked (1..1e9) and cast to int on restore.
3. **Over-heal: correct.** 20/20: +5 then a 10 replaces it, giving 25/25 and then 30/30 (net +5, not +10). Partial 12/30: 22/40. At 0 HP: max rises, current stays 0, no revive. Dead monsters are refused. Removing the winner goes to the next best and clamps current to the new max without healing. The max floor is unchanged from 071 (1, or 0 only through zero_limit).
- Same instance id re-applied refreshes and becomes newest. Matching is by rule_id plus kind; display names aren't used. No per-ID branches (ADR-0018). The refusal path has no cost.

## Open decisions for Brandon
- Should refreshing the same instance make it "newest" for ties? (Current behavior: yes.)
- Temp HP isn't touched by max-HP changes. Confirm that's intended (SRD: temp HP is separate).

## Proposed counts
Logic 6270/0. Card Q-20261025-222012-483e is ready for acceptance.
