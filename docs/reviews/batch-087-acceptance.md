# Batch 087 acceptance review (Runtime Reviewer)

PR #60, base 6aa8924 (batch-086-find-steed-arrival), reviewed head 66eeee9. Card Q-20261026-064523-4895.
The finish line is the one quoted in the PR body by Runtime Builder; Brandon's ruling was not checked against a primary source.

## Verdict: ACCEPT (partial, as declared), with one reviewer commit (function-level checks, no engine change)

## Evidence
- Imports clean (no SCRIPT/Parse/Compile errors). Logic at 66eeee9: 6399/0. With the review checks: 6412/0 (+13).
- Scenarios, one at a time, all PASS with no SCRIPT ERROR: batch_087_choice_routes_flow (28 ok), batch_077_per_swing_choice_flow (14), batch_067_weapon_damage_choice_flow (10), batch_067_weapon_damage_choice_reload (1), batch_065_reaction_triggers_flow, batch_039_created_actor_flow, batch_055_created_commands_flow, batch_056_created_initiative_flow, created_undead_flow, batch_058_summon_lists_flow, batch_061_summon_timing_flow, attack_result_adjustment_flow, weapon_attack_numeric_bonus_flow, batch_070_attack_ac_upgrades_flow. No failures, so no base comparison was needed.
- Diff: src/combat touches only the new `_route_damage_choice`, Cleave in `_finish_fighter_attack`, `_offer_light_attack`, the player OA branch, and `CreatedCreatureCombat.take_turn`. `_extra_swing_damage_choice` and the Attack-action swing path (carry/reset at 895 and 3839) are unchanged.
- ADR-0018: no per-ID branches in the diff; choices come from `AttackProfileRules` data. No saved field was added.

## A. Function-level checks (added: src/review_087_checks.gd)
There were no existing logic checks that called the host. The new checks drive `_route_damage_choice` with a stub HUD and the batch_087 fixture rules. They cover these cases:
- With no rule, nothing is asked. An accepted pick returns the decision, and the host itself spends nothing (action, Bonus Action, Reaction and feature_uses are snapshotted).
- A dismissal returns `held`, logs "cancelled ... nothing was spent" and does not fall back. A stale `still_error` answer is held with nothing spent. A forged or unoffered type is refused. A rule that left before commit is refused by `activation_choice_error`.
- Carry: Nick (carry=true) reuses a same-source attack_action pick without a menu. Non-Nick routes ask even when a live record exists. A forged record for a per-attack rule doesn't carry, and neither does another source's record. A cleared record (a new action or turn) asks again. A hit-window rule defers to the hit settle with no activation menu.
- Per-route budget spending lives in the callers. It's covered by the real-UI batch_087 scenario: Light pick, dismiss and stale; Nick with no Bonus Action spent; Cleave dismiss keeps its use; OA pick and dismiss; zombie pick and dismiss. I read the callers: every one spends only after a non-held return.

## B. CreatedCreatureCombat.take_turn spends "attack_action" (pre-existing, not fixed)
- `CombatTurnBudget.can_spend("attack_action")` is false, so the spend is a no-op. The creature still gets exactly one attack, because take_turn returns and `_end_active_turn()` follows (combat_state.gd ~1020). It can't attack extra times and it doesn't lose an attack.
- Real effect: `_spend_action_cost` never calls `action_history.record_action`, so the condition facts `target.acted_since_combat_turn` and `target.acted_since_owner_turn` read false for a created creature that attacked. The Dodge branch spends "action" and is recorded. This is a narrow, pre-existing mismatch outside this finish line. Proposed card: spend "action" there and add a check that the fact reads true after an attack.

## Stress list
- OA timing: the mover is paused (`_check_opportunity_attacks_for_path` awaits each step), so movement can't finish while the menu is open. A dismissal keeps the Reaction, and that step's trigger closes when the loop moves on. Another OA in the same move needs a new leave-reach (re-enter, then leave), and that's a genuine new trigger. This matches SRD 5.2.1 (from memory, page unconfirmed): an OA is triggered when a creature you can see leaves your reach, and the Reaction is spent only if you attack.
- Light/Nick: `fighter_light_used` and the Bonus Action are set or spent only after a non-held return, and the recheck refuses a used Light or a missing Bonus Action. Nick never spends the Bonus Action. A dismissal returns without offering other candidates, so the attack can't be used twice.
- Cleave: `fighter_cleave_used` is set only after acceptance and is rechecked. The target must still be within 1 hex of the first target and in the weapon's reach from the attacker's live position. A dismissal breaks out of the loop with the use unspent.
- Created creature: a dismissal or stale answer makes no attack and the turn ends. "Nothing spent" is nominal, because the creature's turn is used up either way (see the open decision).
- The #50 nit about ordinary Attack not rechecking reach is already fixed (`_attack_choice_target_error`, from 046008f, before this PR).

## Open decisions for Brandon
1. Created creature: should dismissing its damage-type menu forfeit its attack for the turn (current), or should it Dodge or use the weapon's own type?
2. Card for B (acted_since facts after a created creature's attack)?

## Proposed count updates
Logic 6412/0.
