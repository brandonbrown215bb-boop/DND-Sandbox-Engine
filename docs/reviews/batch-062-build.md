# Batch 062 build: mode costs outside combat

Card Q-20261021-154157-efcb. Queue item 4. Stacked on #33 (batch-061-summon-timing @ 793e90c, accepted by Runtime Reviewer, not merged), because #25-#33 are still open and this edits the 057 mode-cost code.

## Finish line (verbatim)
Grok Bot: "Modes that cost an action can be activated outside combat."
Brandon: "Yes."

## Design
- **Explicit context, not a null budget.** `ModeControls.outside_combat()` returns a `ModeControls.OutsideCombat` marker. A null budget still means "no context given" and keeps 057's `not_in_combat` refusal, so no existing caller changes meaning.
- **`cost_error` with the outside context:** refuses `in_combat` while `GameManager.current_state` is COMBAT (the combat HUD must pay from the turn budget), and `incapacitated` for an incapacitated or dead owner. Otherwise there is no action economy to check.
- **`apply` with the outside context:** all 052/057 checks run first (cancel, stale token, unoffered act, unknown option, merged/suppressed gate). The act itself charges the use exactly once (`FeatureModeRules.activate`), as before. The declared cost is recorded on the receipt as `cost_outside_combat` and nothing is spent from any budget. Reselect/switch spend no use, as in 057.
- **Room path:** new `LocalRoomModes` (called from `LocalRoomView.refresh`) adds a "RoomModeRow" to the local-room panel: an offer list ("Activate: Mode: Rush Stance (2/2 uses) (Bonus Action; no turn outside combat)") and a "Use mode" button that opens Cancel plus exactly the offered options. Cancel, a superseded popup, a changed actor or a changed token spend nothing. Incapacitated owners and exhausted uses get no offer. Successful acts go through `LocalRoomView._result` (log, save flush, refresh) with 0 seconds.
- **Combat carry-over:** mode state is the same `feature_modes` record; an outside activation is active when combat starts, combat offers reselect (paying its Action from the turn budget) and no second activation.
- ADR-0018: no per-ID branches; costs stay the authored `costs` object. No SRD text is cited: I found no SRD 5.2.1 passage stating how Action costs apply outside combat, so none is quoted.

## Checklist
- (a) Refuse before paying: logic covers cancelled, stale, incapacitated, no-uses and in-combat attempts with the outside context, plus 057's null refusal; state unchanged. The scenario uses the real room panel: Cancel, a superseded popup answer, a pending answer after the owner became Stunned, and no uses left all spend nothing.
- (b) No new saved record or field. Logic asserts `FeatureModeRules.saved_error` is clean and the save has no outside-combat marker.
- (c) `outside_combat`, `OutsideCombat` and the new `cost_error`/`apply` branches are called by `LocalRoomModes.offers/answer`; `LocalRoomModes.refresh` is called by `LocalRoomView.refresh`, `open` by its "Use mode" button.
- (d) Real `SaveManager.save_game`/`load_game` in `batch_062_mode_costs_outside_flow`: the use and active mode survive; combat then starts on the loaded party and carries the mode. No cache clearing.
- (e) Merged/suppressed gate: a suppressed copy is refused outside combat (logic).
- Legacy: undeclared-cost modes stay free outside combat; 057 scenario and checks pass unchanged; no save format change.

## Counts
- Baseline 793e90c (fresh worktree, imported twice): logic 5596/0, 58 check scripts.
- Branch (imported twice): logic 5604 passed, 0 failed (+8, all 062), 59 check scripts, 0 failed.
- Scenarios 031-062, one at a time: 32/32 passed (new: `batch_062_mode_costs_outside_flow`, 11 assertions). `batch_056_created_initiative_flow` failed once in the sequential run ("dead owner: the hounds take their declared 'none' turns", only Hound 1 acted) and passed on 3 reruns on the branch; baseline passed 4/4. 062 does not touch initiative or created-actor code, so I read it as intermittent, but it is flagged for review.
- 0 SCRIPT/Parse/Compile errors in all logs.

## Limits
- Outside combat a costed act takes 0 seconds of campaign time; no time cost is invented.
- Only the local room panel offers modes outside combat; the overworld and character sheet have no mode controls yet.
- Group recipients (`targets` > 1) are not chosen in the room; the room activates on the actor only, as the combat HUD does.
- Switch windows open on combat events, so switch is rarely offered outside combat.

## Carried limits
- 059 review: bodies are consumed before placement.
- 058: mixed-size summons and Find Familiar type choice documented only.
- 060: Reaction and Magic action are not costs yet (queue items 6 and 5).
- 061: no core SRD summon spell converted to `after_owner`.
