# Batch 063 acceptance: Magic action cost (PR #35)

Reviewer: Runtime Reviewer. Card Q-20261021-160904-32e9 (claimed until 2026-10-22 11:15 CDT). Reviewed head 31ed8a4, stacked on 322e2f7.

Finish line (verbatim): Grok Bot: "Add the Magic action as a cost option (SRD p.206)." Brandon: "Yes."

## Verdict: ACCEPT, no product defects

## Verified
- Distinct kind is right. `magic` -> `magic_action`: CombatTurnBudget.can_spend("magic_action") needs action_available and ignores surge_actions; spend() clears the Action, sets has_acted_this_turn, never touches surge. Mapping `magic` to plain `action` would let Action Surge pay it, which the SRD forbids. Spell casting already uses this kind, so a spell and a Magic-action mode/command can't both be paid in one turn.
- Paid once: second Magic-action mode/command refused; with Action + surge, the Magic cost takes the Action and leaves the surge action for a plain Action (review check).
- Outside combat (062): receipt carries cost_outside_combat = magic, no `cost`, no budget touched, use charged once.
- Refusal before cost: cost_error/command_error run before any spend; issue() re-checks via _spend_action_cost and reports "Nothing was spent." In a real CombatState a cast child frame or attack substitution makes _spend_action_cost refuse non-matching invocations, so nothing leaks.
- Per-order costs: order_costs accepts magic; attack=magic / dodge=free resolve independently (review check).
- Lowercase refusal text: repo-wide grep finds no matcher on "No Bonus action"/"No action is available" text outside the 060/063 checks; 060's begins_with("No ") style checks still pass. Old text (price.replace("_"," ")) and new text (cost_label().to_lower()) are identical for action and bonus_action; only "No magic action..." is new.
- Loader refuses magic_action, Magic, MAGIC, " magic", reaction. No saved field added; saves contain no magic_action; legacy undeclared command cost stays Bonus Action.
- ADR-0018: no per-ID branches.

## SRD
- Checked from memory; no SRD 5.2.1 PDF found on the box. Action Surge "except the Magic action" and the Magic action definition match the 2024 rules. Page numbers p.48, p.185, p.10, p.206 are UNCONFIRMED by this review.

## Review commits
- Two stress checks in batch_063_checks (Action+surge split; per-order magic/free).

## Counts
- Logic: 5619 passed, 0 failed (5617 claimed + 2 review), 0 SCRIPT ERROR. Scenarios 031-063 one at a time: 33/33, 0 SCRIPT ERROR.

## Open decisions (Brandon)
- No core SRD feature/summon uses `magic` yet (fixtures only). Which content should switch (e.g. magic-item activations)?
- Command results carry no cost_kind (modes do). Add it if a future "on taking the Magic action" trigger needs it.
