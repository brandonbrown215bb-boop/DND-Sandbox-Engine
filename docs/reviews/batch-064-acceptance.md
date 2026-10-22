# Batch 064 acceptance: outside-combat mode duration (PR #36)

Reviewer: Runtime Reviewer. Card Q-20261021-165220-8e8b (claimed until 2026-10-22 11:53 CDT). Reviewed head 58caae6, stacked on 7545de5.

Finish line (verbatim): Brandon (relayed by Grok Bot): "Using a mode outside combat should take the time the casting time in its data says. There's no hour tracker in the game yet, so record or expose that duration from the data, don't invent a clock, and mark the time-passing part as partial."

## Verdict: ACCEPT, no product defects

## PARTIAL time
- Not advancing time is what the finish line asks for ("don't invent a clock", "mark the time-passing part as partial"). PARTIAL is correct, not a reason to reject. LocalRoomModes.answer passes seconds 0 to _result. GameManager.advance_campaign_time exists (equip passes 6 s), so turning it on is a one-line change once Brandon wants it.

## Verified
- Validation: {}, a bare 600, unknown act, 0, 86401, 1.5, "10 minutes" and -6 are all refused. 6.0 is accepted, as it must be because JSON parses numbers as floats. A rest mode declaring the field is refused.
- Default: an undeclared act with a cost of action, bonus_action or magic takes 6 s. A free (none) undeclared act takes 0 s and adds no time to the receipt or label.
- Refuse before cost: seconds are read only after cost_error. Refused acts (cancelled, stale, stunned, in combat) add no time, spend no use and leave the clock unchanged.
- In combat: the receipt is unchanged (only an OutsideCombat budget gets the time).
- Saves: there is no new saved field and saves don't contain activation_seconds, so legacy saves load unchanged. The scenario does a real save and load.
- ADR-0018: no per-ID branches.

## Review commits
- (e) is now tested with an item. New fixture data/fixtures/batch_064/items/slow_circlet.json is an equipped, attuned item copy whose mode declares activate 60 s at an Action cost. A live copy reports 60 s. A merged copy and a suppressed copy are refused ("unavailable") with uses unchanged and no time reported, and the room offers nothing for them.

## Counts
- Logic: 5633 passed, 0 failed (5631 claimed + 2 review), 0 SCRIPT ERROR. Scenarios 031-064 one at a time: 34/34, 0 SCRIPT ERROR.

## Open decisions (Brandon)
- Should outside-combat mode use advance the campaign clock (the one-line wire-up)?
- Should the activation time count down the mode's own duration_seconds?
- No core SRD mode declares activation_seconds yet (fixtures only).
