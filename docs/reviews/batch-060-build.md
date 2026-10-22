# Batch 060 build: S-156 command cost

Card Q-20261021-143345-aee2. Stacked on #31 (batch-059-corpse-limit @ a280d47, accepted by Runtime Reviewer, not merged), because #25-#31 are still open and this edits the 055/056 command code.

## Finish line (Brandon, verbatim)
"The cost of commanding a summon should be definable in the data (free, Bonus Action, etc.)."

## Design
- **`command.cost`** (055 field, widened). Values: `bonus_action`, `action`, `none`, and `free` (an authored synonym for `none`). This is the 057 mode cost vocabulary (`FeatureModeRules.COST_TYPES`: action, bonus_action, none) plus `free`.
- **`command.order_costs`** (new, optional). Per-order override, e.g. `{"cost": "free", "order_costs": {"attack": "action"}}`: Dodge is free, Attack costs an Action. Keys must be declared orders the creature can actually be given; values use the same vocabulary.
- **Per kind.** `command` already lives on each creature template, so each kind declares its own cost. 058 mixed casts still require one shared command policy across the kinds in a cast (unchanged).
- **Resolution.** `CreatedCommandRules.cost(policy, order)` → `order_costs[order]`, else `cost`, else the 055 default `bonus_action`; `free` resolves to `none`. Used by `command_error` (check), `issue` (pay) and the HUD (label).
- **Free commands** skip both the check and the payment, so no Action, Bonus Action or reaction is touched. The once-per-actor-per-turn rule still applies.
- **HUD.** Each command row shows its own order's cost via `CreatedCommandRules.cost_label`: "(Free)", "(Action)", "(Bonus Action)". Unaffordable rows are disabled with the reason, e.g. "[No action is available to command.]".
- **Loader.** `policy_error` refuses unknown costs (including `reaction` and `magic_action`), non-string costs, empty or non-object `order_costs`, unknown orders, and costs for orders the creature lacks.
- ADR-0018: no per-ID branches; everything comes from the template JSON. No SRD citation is needed: this is a building block, not a rule value.

## Checklist
- (a) Refuse before paying. Logic and the real HUD scenario both assert that nothing is spent for: an unaffordable Action-cost order (no Action left, Bonus Action untouched), the wrong turn (another creature active), an incapacitated (stunned) owner, a stale actor id, a cancelled target popup and a superseded target popup. The current answer then pays exactly one Action.
- (b) No new saved record or field. The cost is read from the template at command time; `saved_record_error` is asserted unchanged.
- (c) Production callers: `CreatedActorRules.template_error` → `policy_error`; `command_error`/`issue` → `cost`; `CombatHUD` command rows → `cost` + `cost_label`.
- (d) Real `SaveManager.save_game`/`load_game` in the scenario: both hounds reload and still resolve their declared cost. No cache clearing.
- (e) Merged/suppressed item gate: not relevant; no item-granted effects.
- Legacy: absent `cost`/`order_costs` keep 055's Bonus Action for every order (asserted on `{}` and on the 055 pack fixture). All 055/056 scenarios pass unchanged. No save format change.

## Counts
- Baseline a280d47 (fresh worktree, imported twice): logic 5576/0.
- Branch (imported twice): logic 5585 passed, 0 failed (+9, all 060).
- Scenarios 031-060, one at a time: 30/30 SCENARIO PASSED (new: `batch_060_command_cost_flow`, 13 assertions).
- 0 SCRIPT/Parse/Compile errors in all logs.

## Limits
- Reaction and Magic action are not command costs yet. They are queue items 6 (reaction triggers) and 5 (Magic action as a cost option); the loader refuses them until then.
- Orders are still only attack and dodge (055).
- Mixed casts share one command policy (058), so per-kind costs apply across casts, not within one mixed cast.
- Fixture only (`fixture:b060_hounds`); no core spell changes its command cost.

## Carried limits
- From 059 review: bodies are consumed using the factory count before `attach_created_actors`. If placement ever places fewer creatures than the count, bodies would be over-consumed. Latent only while 053 placement is all-or-nothing.
- From 058: mixed-size summons unsupported; Find Familiar creature-type choice has no building block. Documented only, no cards.
