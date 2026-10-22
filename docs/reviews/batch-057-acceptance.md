# Batch 057 acceptance: mode activation action costs (Q-20261021-060241-19d0)

**Verdict: accept.** PR #29 at 7f6b159 (stacked on #28, 210dc54). No defects found, no review commits to code.

## Runs (reviewer, /tmp/rev_wt057, Godot 4.7.2, imported twice)
- Logic suite alone: 5551 passed, 0 failed (matches builder; baseline 5541, +10).
- Scenarios 031-057 run one at a time: 27/27 SCENARIO PASSED.
- N1: 0 `SCRIPT ERROR` in logic logs or any scenario log.

## Finish line check
- Spends declared action and use exactly once: cost checked by `ModeControls.cost_error` before the act, paid once only after `FeatureModeRules` act returns success. Spent uses, suppressed/merged (049 R1) and incapacitated (052 R1) refuse inside or before the act, so neither is charged.
- Cancelled, stale, wrong-turn, incapacitated, unaffordable: all refused before any spend (logic + scenario).
- Reselect/switch pay their own declared cost, spend no use; loader refuses `reselect` cost without `allow_reselect`, `switch` cost without `switch_events`, and any `costs` on rest-boundary modes.
- HUD shows "(Bonus Action)" and disables unpayable rows with the reason.
- Shared budget: costs go through the same `turn_budget` as 055/056 summon commands, so a Bonus Action used on a command makes a bonus-action mode unaffordable and vice versa. `can_pay_mode_cost` refuses mid-cast / mid attack-substitution.
- Default: undeclared costs stay free (finish line requires this). No per-ID branches. No new saved state, so legacy saves are unaffected.
- Only production caller of the act functions is `ModeControls.apply` (HUD); no bypass.

## SRD 5.2.1
- Magic action: "Cast a spell, use a magic item, or use a magical feature" (p.10).
- "It usually takes a Magic action to activate a magic item" (p.206).

## Decisions for Brandon
1. **Outside combat**, a costed activation is refused (`not_in_combat`); free ones still work. Should costed modes instead be usable freely out of combat?
2. **Magic action**: `costs` accepts only `action`/`bonus_action`/`none`, not the engine's existing `magic_action`. SRD magic-item activations are Magic actions; add `magic_action` as a cost type?
3. **`hit` switch windows** with a declared cost open on the attacker's turn, so they are always refused `wrong_turn`. Fine as authored, or should reaction-timed switches use a Reaction cost?
