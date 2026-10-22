# Batch 060 acceptance (runtime-reviewer)

Verdict: ACCEPT, no defects. Head reviewed: 9ec18fa (stacked on #31 a280d47). Review commit adds stress tests only.

## Runs (worktree /tmp/rev_wt060, imported twice)
- Logic suite: 5585/0 at 9ec18fa (matches the builder). 5588/0 with the review stress tests (+3).
- Scenarios 031-060, one at a time: 30/30 SCENARIO PASSED.
- N1: 0 SCRIPT ERROR across logic and scenario logs.

## Checks
- Finish line ("The cost of commanding a summon should be definable in the data (free, Bonus Action, etc.)"): met. `command.cost` and per-order `order_costs` on the creature template; `free` = `none`.
- Invalid values: `policy_error` refuses unknown/non-string costs (incl. `FREE`, `" free"`, null, `reaction`, `magic_action`), empty or non-object `order_costs`, unknown orders and orders the creature lacks. At runtime an invalid policy falls back wholesale to the 055 default (Bonus Action) via `policy()` (stress-tested).
- Override: `cost()` reads `order_costs[order]`, then `cost`, then `bonus_action`. One resolver feeds check, pay and HUD label, so the HUD cost cannot drift from what is spent.
- Free commands: skip check and payment; once-per-actor-per-turn still enforced; a second actor may take its own free order (stress-tested).
- Mixed spending: an Action spent by one hound blocks a second Action order but not a free Dodge; Bonus Action and reaction untouched (stress-tested).
- Refuse-before-pay: wrong turn, stunned owner, stale id, unaffordable order, cancelled/superseded menu all spend nothing (builder tests + scenario).
- Incapacitated owner: refused before cost (055 gate, retested here).
- ADR-0018: no per-ID branches.
- Legacy: absent keys → Bonus Action for every order; no save-format change.

## Defects
- None.

## Notes (not defects)
- 058 mixed casts compare whole policies, so `{"cost":"free"}` and `{"cost":"none"}` count as different policies and a mix using both is refused at load. Conservative; authors should pick one spelling.

## Decisions for Brandon
- Default command cost stays Bonus Action (SRD summon spells). Confirm, or should data omitted default differently?
- Reaction / Magic action as command costs are refused until their queue items land. OK?
