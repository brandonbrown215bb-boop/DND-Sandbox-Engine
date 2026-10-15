# Owned post-roll ability-check modifiers

## Pre-roll roll-mode policy (S-091)

Loaded EventDialog ability checks may add or restrict Advantage/Disadvantage
before the original d20. A passive source declares one of these operations:

```json
{
  "type": "ability_check_roll_mode",
  "id": "steady_reading",
  "domain": "event_skill_check",
  "mode": "advantage",
  "ability": "INT",
  "skill": "Investigation",
  "task_id": "survey_archive",
  "purpose_id": "locate_nest",
  "source_event_id": "fixture:survey_map_event",
  "source_check_id": "read_map_check"
}
```

The mode grant matches every listed context field exactly, including the loaded
originating event and check. `skill` may be the empty string for an ability-only
check. A renamed definition works by changing its authored context fields and
loaded references; runtime behavior never branches on a feature ID.

A `ability_check_roll_mode_policy` uses that same exact context and names
`operation: "cancel"` or `"prohibit"`, plus `mode`. It may list
`exempt_source_definition_ids`, which are feature definition IDs whose
contributions survive that policy, or `exempt_source_instance_ids` to exempt
only specific generated instances. The author must update definition references
when renaming an exempt definition. Runtime matching binds each contribution to
its owner, source definition and exact source instance (or the feature
definition when the source has no instance ID).

Resolution order is fixed:

1. At the actual Roll commitment, read currently owned and enabled sources and
   match them to the authoritative check context. The eligibility query itself
   is pure; it never rolls, pays or changes state. The roll reads again, so a
   source removed after an earlier query contributes nothing.
2. Apply every matching cancel/prohibit policy to each same-mode authored grant
   independently. A grant exempted by that policy survives it. If several
   policies apply, a grant survives only when every applicable policy exempts
   it. The captured receipt records each grant, exact source provenance, its
   active/canceled/prohibited status and the suppressing policy sources.
3. Duplicate surviving grants of the same mode still produce one Advantage or
   Disadvantage roll, with all source contributions retained in the receipt.
   If both modes survive (including ordinary/native sources), pass both flags
   to `RollTokenRules`; its normal D20 resolution cancels them to one die.
   Otherwise it rolls the one surviving mode, or Normal when neither survives.

The check result exposes `roll_mode` and `roll_mode_contributors`. This field is
the mode chosen for the original test. A pre-roll token replacement still uses
the normal token resolver and reports `roll_details.mode: "replaced"`; replacing
the natural result does not rewrite the captured roll mode. S-105 continues to
use the captured `roll_mode` for a declared whole-test reroll.

This slice covers the loaded EventDialog ability-check route only. It does not
add roll modes to weapon attacks, saves, other EventDialog variants or every
host. Policies act on authored roll-mode contributions; existing native
advantage/disadvantage sources continue through their existing rules and the
engine's normal opposite-mode cancellation. No reroll or token generation is
added.

Focused development coverage lives in `CheckContextChecks`: duplicate grants,
opposite-mode cancellation, selective cancel/prohibition with an exempt source,
nonmatching renamed context, pure query and source removal before commitment.

The current bounded operation applies one optional fixed or single-die bonus to
a failed, actually rolled ability check in a loaded `EventDialog` skill-check
or choice-check, including a check with an ability but no skill. An omitted or
empty skill is carried as an unskilled check; a nonempty unsupported skill is
rejected. It runs after that dialog's native check choices and before
the loaded success/failure consequences. The captured natural d20, modifier,
DC, check context and prior native bonus data stay on the returned result; the
bonus changes only the final total and success flag.

A passive feature can declare `ability_check_numeric_bonus` with
`domain: "event_skill_check"`, exact ability, skill, `task_id`, `purpose_id`,
`required_tool_id`, `source_event_id` and `source_check_id`, plus either a
fixed `amount` from 1–20 or one supported `die_size`, a pool `cost` and a
`payment_policy` (`pay_on_choice` or `pay_on_converted_success`). The loaded
event/check record supplies the check facts. `required_tool_id` matches the
tool named by that check; it does not claim the character physically carried
or used that tool. The feature's identity selects no runtime branch. Only a
matching, currently owned feature source pool can be offered.

The fixed fixture uses +5 for the archive survey at one use paid when chosen.
The renamed fixture uses one d8 for the tidal-herb check at two uses paid only
when that die converts the result to success. The ability-only fixture uses a
fixed +4 and an alternative d6 for an unskilled estimate check, with separate
owned sources. A declined or stale-source choice
keeps the captured result. A die is rolled only after a selected source is
revalidated; conditional payment is zero when the final check still fails.
Duplicate modification on the same result, replay, a forged source answer, or
another actor's answer cannot spend the pool.

Production control acceptance used the actual EventDialog Roll, native-choice,
owned-source PopupMenu and Close controls. It demonstrated loaded event-level
skilled and ability-only checks, plus a choice-owned ability-only check through
its actual choice button and Roll control. It exercised fixed and single-die
bonuses, both payment policies, upfront affordability, unchanged captured
natural/modifier/DC/context, and a matching closed result receipt. Native
Inspiration remained in the captured result and was spent once before the
optional choice. Decline, empty, depleted, removed, forged and replayed answers
did not roll or spend; completed accepted-request replay was checked against
snapshots of dice, both source pools, gold and receipt. Pending consequences
waited for the final answer, and an underfunded source was not offered under
either payment policy. Host re-popup and teardown canceled only the old host's
request. Evidence is the 69-assertion `check_context_flow` production scenario
at `.artifacts/tests/136995fdd7b64e9d884b127a223518c5/`, with bootstrap, 185-script
parse and boot gates passing.

This operation currently covers the represented EventDialog host only. It does
not add Death Save, concentration, local-room, automatic no-roll, or other
ability-check hosts, and it does not add a reroll or outcome-replacement choice.
Broader V-014/035 semantics remain open.

## Mandatory-new rerolls (S-105)

The S-105 build adds `ability_check_mandatory_reroll` to the same loaded
EventDialog ability-check host. It is authored on a passive feature with its
own numeric pool. The effect names the same exact check context plus
`eligible_outcomes` (`failure`, `success`, or both), `reroll_mode`
(`natural_only` or `whole_test`), `bonus_dice_policy` (`keep` or `reroll`),
and a positive pool `cost`. The neutral fixture rerolls one failed natural d20
and keeps its already-rolled bonus dice for one use. The renamed fixture allows
either prior outcome, rerolls the whole captured test under its original
Advantage/Disadvantage mode, rerolls captured bonus dice, and costs two uses.

Numeric bonuses and mandatory rerolls appear as alternatives in one post-roll
menu when each qualifies. One accepted answer settles the captured test and
closes that menu; it does not open another modifier choice. Rerolling never
re-enters the check resolver or replays roll-token, Inspiration, Tactical Mind,
original action, or consequence costs. The accepted receipt keeps the original
raw kept natural, roll mode, floor stages, and old bonus-die results alongside
the new d20 and any declared rerolled bonus dice. A worse new result is still
final. A source whose eligibility/effect/funds changed while its menu was open
falls back to the original captured result without rolling or spending.

VS-26 accepts the bounded S-105 reroll through the loaded EventDialog. The
production acceptance used the choice button, Roll,
source PopupMenu, native Inspiration confirmation and Close controls. It
demonstrated natural-only/keep and whole-test/reroll behavior, including both
old failure to success and old success to failure, with the new result kept
even when worse. Normal, Advantage and Disadvantage d20 modes were exercised;
Advantage/Disadvantage each rolled one two-face test emission. A loaded
choice-owned check used the same path. The floor case deliberately kept the new
pre-floor subtotal below its captured total floor, then rerolled Guidance and
Bardic Inspiration; the current die faces, scalar fields, visible label and
final total agreed, while the original faces and one already-paid Inspiration
use remained in the receipt. A negative-modifier check stayed negative without
a floor. Query, decline, underfunded, emptied, removed, forged, unoffered,
stale and replayed answers did not spend or roll replacement dice. The actual
closed result retained the final receipt and one consequence; host replacement
or teardown canceled only the affected request.

The final actual-control run passed 107 assertions with Godot exit code 0 at
`.artifacts/tests/a74c2363968243108dacc86f68a9ff5b/check_context_flow_final/`.
Bootstrap, 185-script parse and boot gates passed in
`.artifacts/tests/a74c2363968243108dacc86f68a9ff5b/`. The only stderr output
was the existing DataLoader warning about 25 unsupported effectless feature
records. This certifies loaded EventDialog ability checks, including the
choice-owned check; it does not claim weapon attacks, saves, automatic/no-roll
results, old/new choice, another modifier pass or other check hosts. Broader
V-089 remains open.
