# Batch 064 build: outside-combat mode duration

Card Q-20261021-165220-8e8b. Follow-up to 062. Stacked on #35 (batch-063-magic-action-cost @ 7545de5, accepted by Runtime Reviewer, not merged), because #25-#35 are still open and this edits the 062/063 mode cost code.

## Finish line (verbatim)
Brandon (relayed by Grok Bot): "Using a mode outside combat should take the time the casting time in its data says. There's no hour tracker in the game yet, so record or expose that duration from the data, don't invent a clock, and mark the time-passing part as partial."

## Also recorded: Brandon's ruling on summon defaults
Brandon (relayed by Grok Bot): summon turn order and command cost come from each spell's data; core SRD summons get no default. "We're only building the blocks for the data to be read and operated off of." The 061 limit "no core SRD summon spell converted to `after_owner`" (and the 060 command-cost default question) is therefore **resolved as by design**, not open work.

## Design
- **Field.** `mode_choice` rules have no existing activation-time field (`duration_seconds` is how long the mode lasts; spells' `casting_time`/`cast_time_seconds` apply to spells only, and a mode's source feat has none). Added optional `activation_seconds`: an object of `activate`/`reselect`/`switch` -> whole seconds, 1-86400 (same unit and range as a spell's `cast_time_seconds`). `FeatureModeRules.validate_rule` refuses a non-object, empty object, unknown act, non-integer, string or out-of-range value, and a `rest` mode declaring it.
- **Read.** `FeatureModeRules.activation_seconds(actor, feature_id, act)`: the declared value; else one 6-second round if the act declares a cost (`action`, `bonus_action`, `magic`; SRD 5.2.1 round of about 6 seconds, matching `ClassProgression._spell_casting_time_seconds`); else 0. Read from the live (upgraded) rule, no per-ID branches (ADR-0018).
- **Receipt.** Outside combat, a successful act with a nonzero time adds `activation_seconds` and `time_advanced: false` to the receipt. In combat the receipt is unchanged (the turn budget is the time).
- **Room panel.** Offer text gets ` [takes 10 min; time not advanced]`; the success log gets ` (takes 10 min; time not advanced)`. Existing "(Bonus Action; no turn outside combat)" text is unchanged.
- **Clock decision.** The room already has a production time path: `LocalRoomView._result` calls `GameManager.advance_campaign_time(result.seconds)` (equipping passes 6 s). Per the finish line ("don't invent a clock", "record or expose") and the task, 064 does **not** feed the mode time into it; `LocalRoomModes.answer` still passes `seconds: 0`. Wiring it is a one-line change if Brandon wants mode use to spend campaign time.

## PARTIAL
Time passing for outside-combat modes is **PARTIAL**: the duration is read, validated, shown and returned, but no clock advances, nothing else (rests, durations, other characters) waits on it, and the mode's own `duration_seconds` countdown is not reduced by the activation time.

## Checklist
- (a) Refuse before paying: cancelled, stale, incapacitated and in-combat outside attempts spend nothing, report no time and leave `campaign_elapsed_seconds` unchanged (logic); the room Cancel spends nothing and passes no time (scenario).
- (b) No new saved record or field; `FeatureModeRules.saved_error` clean; saves do not contain `activation_seconds`.
- (c) `activation_seconds` is called by `ModeControls.apply` and `LocalRoomModes.offers`; `duration_label` by `LocalRoomModes.offers/answer`; `activation_seconds_error` by `validate_rule`.
- (d) Real `SaveManager.save_game`/`load_game` in `batch_064_mode_duration_flow`: use, active mode and the unadvanced clock survive. No cache clearing.
- (e) No item-granted effect added; the fixture is a feat. The 049/057 merged/suppressed gate still runs (in `row`/`actions`) before any time is reported.
- Legacy: free undeclared modes report no time; 057 Rush validates; no save format change.

## Counts
- Baseline 7545de5 (imported): logic 5619 passed, 0 failed, 60 check scripts.
- Branch (imported twice): logic 5631 passed, 0 failed (+12, all 064), 61 check scripts, 0 failed.
- Scenarios 031-064, one at a time: 34/34 passed (new: `batch_064_mode_duration_flow`, 5 assertions). 0 SCRIPT/Parse errors.

## Limits
- PARTIAL time passing (above). No campaign clock is advanced.
- Undeclared costed acts default to one 6 s round; no core SRD mode declares `activation_seconds` yet (fixture only).
- Duration labels are not localized.

## Carried limits
- 059 review: bodies are consumed before placement.
- 058: mixed-size summons and Find Familiar type choice documented only.
- 060: Reaction is not a cost yet (queue item 6).
- 061: no core SRD summon default — resolved as by design (Brandon's ruling above).
- 062: only the local room panel offers modes outside combat.
