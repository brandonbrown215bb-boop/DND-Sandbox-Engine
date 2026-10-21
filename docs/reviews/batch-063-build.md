# Batch 063 build: Magic action cost

Card Q-20261021-160904-32e9. Queue item 5. Stacked on #34 (batch-062-mode-costs-outside-combat @ 322e2f7, accepted by Runtime Reviewer, not merged), because #25-#34 are still open and this edits the 057/060/062 cost code.

## Finish line (verbatim)
Grok Bot: "Add the Magic action as a cost option (SRD p.206)."
Brandon: "Yes."

## SRD 5.2.1 (checked against SRD_CC_v5.2.1.pdf; no SRD text is stored in the repo)
- p.185, Rules Glossary, "Magic [Action]": "When you take the Magic action, you cast a spell that has a casting time of an action or use a feature or magic item that requires a Magic action to be activated."
- p.10, Actions table: "Magic | Cast a spell, use a magic item, or use a magical feature."
- p.206, "Activating a Magic Item": "It usually takes a Magic action to activate a magic item." (This is the page the proposal cited; the action itself is defined on p.185.)
- p.48, Fighter, Action Surge: "you can take one additional action, except the Magic action."

## Design
- **Shared vocabulary.** `CombatTurnBudget.AUTHORED_COSTS` maps authored costs to the budget kind they spend: `action`, `bonus_action`, and new `magic` -> `magic_action`. `budget_kind()` and `cost_label()` are used by both `ModeControls` (057/062) and `CreatedCommandRules` (060). `FeatureModeRules.COST_TYPES` and `CreatedCommandRules.COSTS` accept `magic`; everything else (including the internal `magic_action` spelling, case and whitespace variants, `reaction`) is still refused at load.
- **Distinct kind, decided from the code.** The budget already had a separate `magic_action` kind: it spends the Action (`action_available = false`, `has_acted_this_turn`) but cannot be paid by an Action Surge extra action (SRD p.48; existing fighter checks), and spell casting, Channel Divinity, Divine Intervention, familiar and zone moves already spend it. So `magic` spends `magic_action`, not `action`. Every costed mode receipt now carries `cost_kind` (the budget kind: `magic_action`, `action`, `bonus_action`) next to the authored `cost`, for features that care. No per-ID branches (ADR-0018).
- **HUD.** Combat feature list and the room panel use the shared label: "(Magic action)" and "(Magic action; no turn outside combat)". Command rows read "(Magic action)". Existing labels (Action, Bonus Action, Free) are unchanged.
- **Outside combat.** 062 rules unchanged: no action is spent, `cost_outside_combat` records `magic`, the use is charged once.

## Checklist
- (a) Refuse before paying: logic on the real `CombatTurnBudget` covers cancelled, stale, wrong-turn, incapacitated, no-Action and surge-only attempts for a Magic-action mode, and no-Action/surge-only plus a second Magic-action command; nothing spent. Scenario: the real combat HUD row is disabled `[unaffordable]` with no Action left (only a surge action) and a forced apply spends neither use, surge nor Bonus Action.
- (b) No new saved record or field; `FeatureModeRules.saved_error` and `CreatedActorRules.saved_record_error` clean; saves do not contain `magic_action`.
- (c) `budget_kind` is called by `ModeControls.cost_error/apply` and `CreatedCommandRules.command_error/issue`; `cost_label` by `CombatHud`, `LocalRoomModes` and `CreatedCommandRules.cost_label`.
- (d) Real `SaveManager.save_game`/`load_game` in `batch_063_magic_action_cost_flow`: use, active mode and authored cost survive. No cache clearing.
- (e) No item-granted effect added; the 057 merged/suppressed gate path is unchanged and still runs before any cost check.
- Legacy: undeclared command costs stay Bonus Action; 057 Rush validates; no save format change.

## Counts
- Baseline 322e2f7 (imported twice): logic 5606 passed, 0 failed, 59 check scripts.
- Branch (imported twice): logic 5617 passed, 0 failed (+11, all 063), 60 check scripts, 0 failed.
- Scenarios 031-063, one at a time: 33/33 passed (new: `batch_063_magic_action_cost_flow`, 6 assertions). 0 SCRIPT/Parse errors.

## Limits
- No core SRD content is switched to a `magic` mode or command cost; fixtures only.
- `cost_kind` is recorded on mode receipts; command results return a message only (the spend itself goes through the `magic_action` budget kind). No "on taking the Magic action" trigger exists yet; reaction triggers are queue item 6.
- The Magic action command/mode labels are not localized.

## Carried limits
- 059 review: bodies are consumed before placement.
- 058: mixed-size summons and Find Familiar type choice documented only.
- 060: Reaction is not a cost yet (queue item 6).
- 061: no core SRD summon spell converted to `after_owner`.
- 062: outside combat a costed act takes 0 seconds; only the local room panel offers modes outside combat.
