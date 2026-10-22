# Batch 057: mode activation action costs

## Finish line (Brandon, verbatim)

> Real action costs for mode activation. Mode buttons currently spend feature uses but no Action/Bonus Action. Add authored costs through the existing combat budget, preserving current free fixture behavior when no cost is declared. Done means: an activation spends its declared action and use exactly once. Cancelled, stale, wrong-turn, incapacitated and unaffordable attempts spend neither. Reselecting or switching follows the declared policy. Unlocks: real mode-based features using the new controls.

- **Card:** Q-20261021-060241-19d0.
- **Base:** batch-056-created-initiative (210dc54), because #25-#28 are still open.
- **Also filed, not built:** Q-20261021-060241-0ca9 (ready). Mid-round save/load loses turn order because the initiative tracker is unsaved.

## Design
- **Authored costs:** an activation-boundary `mode_choice` may declare `costs: {activate?, reselect?, switch?}`.
  - Each value is `action`, `bonus_action` or `none`.
  - An omitted act, or no `costs` at all, stays free, which is the existing fixture behaviour.
  - The loader refuses:
    - unknown acts or cost types, and an empty `costs`
    - `reselect` without `allow_reselect`
    - `switch` without `switch_events`
    - any `costs` on a rest-boundary mode
- **Paying a cost:** `ModeControls.apply(..., budget)` keeps 052's checks first: cancel, stale token, unoffered action, unknown option, and the merged/suppressed gate. For a costed act, `cost_error` then refuses:
  - `not_in_combat`
  - `wrong_turn` (the budget's active character isn't the owner)
  - `incapacitated`
  - `unaffordable`, via `CombatState.can_pay_mode_cost`: the plain turn budget only, never mid-cast or mid attack-substitution.

  Only after the existing `FeatureModeRules` act succeeds is the declared cost paid, once, through `_spend_action_cost`. The use is still spent once by `activate`, as before.
- **Reselect and switch:** each pays its own declared cost and spends no use. Both follow the existing policy (`allow_reselect`, the switch window).
- **HUD:**
  - The row shows the cost, for example "(Bonus Action)".
  - An unpayable act is offered disabled with its reason.
  - Popup answers pass the combat state as the budget.
  - Cancelled, superseded and wrong-turn answers keep 052's "nothing was spent".

## Checklist
- **(a) Refuse before pay:** cancelled, stale, wrong-turn, incapacitated, unaffordable and out-of-combat attempts spend neither the use nor the budget. Logic and scenario both check this, and a valid activation spends its Bonus Action and its use exactly once.
- **(b) Saved data:** no new saved state. Costs are authored rule data, checked by `validate_rule` on load and for owned copies.
- **(c) Production callers:**
  - `FeatureModeRules.cost` and `costs_error`: called by `ModeControls` and `validate_rule`.
  - `ModeControls.cost` and `cost_error`: called by the HUD and `apply`.
  - `can_pay_mode_cost`: called by `cost_error`.
  - `_mode_budget`: called by the HUD.
- **(d) Real persistence:** the scenario saves and loads through SaveManager. The use, the mode and the authored cost all survive.
- **Merged/suppressed gate:** a suppressed copy is refused before any cost check and spends neither.

## Counts
- Logic: the baseline at 210dc54 is 5541 passed, 0 failed (fresh worktree, imported twice). The branch is 5551 passed, 0 failed (10 new checks).
- Scenarios 031-057: all 27 passed, run one at a time. 057 has 11 of 11 checks passing.

## Limits
- Fixture content only. No real feature has been converted yet; that is the work this unlocks.
- Costs can't be paid outside combat: a costed act refuses with `not_in_combat`. Free modes are unchanged everywhere.
- Upgrades can't change costs. Costs come from the owned rule as the upgrades resolve it, and `RuleUpgradeRules` has no cost operations.
- Untouched: 055's default command cost, the option cap, mixed kinds, S-120, disposal, S-165/S-166 and tether capacity.
