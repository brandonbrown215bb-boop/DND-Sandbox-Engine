# Owned post-roll ability-check modifiers

## Optional event filters

For `ability_check_roll_mode`, `ability_check_roll_mode_policy`,
`ability_check_numeric_bonus` and event-domain `ability_check_mandatory_reroll`,
`task_id`, `purpose_id`, `source_event_id` and `source_check_id` are optional
filters. Omit a filter to leave that fact unrestricted. Present filters must be
nonempty strings (task/purpose/check use identifier tokens), combine with AND,
and require the corresponding actual check fact. Empty, null or malformed
values do not mean unrestricted. Existing exact-context definitions retain their
restrictions. `check_floor` and contextual tool bonuses retain their separate
exact-context contracts.

Ability, skill and tool eligibility retain their existing semantics: exact
ability; empty/omitted skill selects an ability-only check; empty/omitted
`required_tool_id` selects a check without a declared tool. This change does not
add an all-abilities or all-skills selector. A feature authored for Investigation
can now work across loaded Investigation events without naming every table ID.

Loaded EventDialog checks with unique IDs carry verified origin even without
`check_context`; no task/purpose is invented. If a copied popup omits context
that the loaded record declares, the loaded facts are restored. Loaded DC,
check, consequences and exact-source spending remain authoritative. Unidentified
legacy/direct checks do not gain the owned post-roll route. Concrete event
references must exist; a combined event/check reference must identify a unique
compatible loaded check. Partial task/purpose/check selectors can span tables.

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

The mode grant matches every declared context filter exactly; omitted filters
are unrestricted as described above. `skill` may be the empty string for an ability-only
check. A renamed definition works by changing its authored context fields and
loaded references; runtime behavior never branches on a feature ID.

An `ability_check_roll_mode_policy` uses those same optional filters and names
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
`domain: "event_skill_check"`, exact ability/skill/tool eligibility, optional
event filters as described above, plus either a
fixed `amount` from 1–20 or one supported `die_size`, a pool `cost` and a
`payment_policy` (`pay_on_choice`, `pay_on_converted_success`,
`pay_on_final_success`, or `pay_on_final_failure`). See the
[final-result payment contract](shared-resource-pools.md#final-result-payment-predicates-s-100)
for reservation and settlement. The loaded
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
ability-check hosts. S-106 adds the shared reroll policy to selected combat
test domains below; that does not widen this EventDialog context matcher.
Broader V-014/035 semantics remain open.

## Mandatory-new rerolls (S-105)

The S-105 build adds `ability_check_mandatory_reroll` to the same loaded
EventDialog ability-check host. It is authored on a passive feature with its
own numeric pool. The effect uses the same optional check filters plus
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


## Authored natural and final floors (S-038 / VS-45)

A passive feature can declare `check_floor`. It uses the existing singleton
feature-ID source identity on ordinary class acquisition, or an explicit exact
`source_instance_id` for independently owned copies:

```json
{
  "type": "check_floor", "id": "steady_reading",
  "domain": "event_skill_check", "stage": "natural_d20", "minimum": 8,
  "ability": "INT", "skill": "Investigation",
  "task_id": "survey_archive", "purpose_id": "locate_nest",
  "source_event_id": "fixture:survey_map_event", "source_check_id": "read_map_check"
}
```

`stage` is `natural_d20` or `final_total`; these are distinct operations.
`minimum` is an existing actor numeric formula, e.g.
`{"op":"add","left":10,"right":{"caster_ability_modifier":"INT"}}`.
Natural thresholds must evaluate to integers 1–20; final thresholds to −100–100.
Boolean/malformed/cast-only formulas and unknown fields reject. Loaded context
cross-reference validation checks the same exact event/check/ability/skill/task/
purpose used by roll modes. Missing/unavailable sources do not contribute.

The query is pure. It captures threshold and exact owner/definition/instance/
effect/domain/stage provenance before the original d20. Mode/token selection
produces the raw natural; authored and existing native natural floors then take
the maximum. Ordinary modifiers and Guidance follow, then the existing native
total-floor stage, native post-roll dice and the authored final floor. A later
owned numeric/die bonus is included in the subtotal before that final floor;
it is not added to a previously inflated floor. A mandatory-new reroll keeps the
captured thresholds/provenance/base modifier, reapplies the same stages and uses
its already-authored keep/reroll bonus-dice policy. It neither reevaluates the
floor formula nor charges native payments again. Natural Stroke replacement
clears the previous authored floor adjustment before final arithmetic resumes.

Receipts retain `raw_natural_roll`, effective `natural_roll`/`roll`, ordinary
`base_modifier`/`modifier`, `check_bonus_dice`, native floor fields, `floor_sources`,
`pre_floor_subtotal`, `authored_floor_adjustment` and final `total`. Multiple
independent sources remain in `floor_sources`; maximum floors do not sum.
The final EventDialog label exposes raw/effective/subtotal/adjustment and Close
retains the canonical receipt. Removing a source affects future queries, not
an already captured/settled test.

The explicit outcome policy is
`ability_check_numeric_comparison_no_automatic_1_or_20`: compare final total to
DC, including raw 1/20. This host has no attack critical or automatic-miss rule.
Attack/save floor domains reject; no floor is a success override or an authored
critical. Pending rolls/requests/receipts remain transient; floors do not add a
save field. Chosen old/new rerolls are documented separately below. Exact
production controls and retained native-floor evidence are in
[Batch G build/validation](../../.artifacts/planning/vocabulary-reports/batch-G-build-validation.md)
and the accepted [independent review](../../.artifacts/planning/vocabulary-reports/batch-G-review.md).

## Chosen old/new and combat-test rerolls (S-106 / S-225; VS-48/49)

`ability_check_mandatory_reroll` accepts `selection_policy` (`mandatory_new` or
`choose_old_or_new`), `new_roll_mode` (`captured`, `normal`, `advantage`, or
`disadvantage`), and optional `level_bonus_formula`. The formula is evaluated
for the owned Character when the eligible option is captured; the resulting
integer remains fixed while the choice is open. It does not read a live level
again after payment.

The existing `EventResolver.reroll_captured_skill_check` is the only reroll
arithmetic owner. It rerolls the captured natural or whole test, follows the
declared replacement mode and captured floor stages, and keeps already-rolled
bonus dice or rerolls precisely those bonuses according to `bonus_dice_policy`.
It never repeats roll-token or native decisions, modifiers, or the original
consequence. For `choose_old_or_new`, a second popup follows the reroll. The
source pays once before replacement dice; canceling the keep popup defaults to
the original. The full old and new receipts stay attached to the final result,
and the nested new-test receipt cannot recursively contain itself.
If the offered source disappears before purchase, the original check settles
normally without replacement dice or an old/new picker. The source and keep
popups track separate pending decisions so re-popup/teardown cancels their await.

The same effect declares one of the additional domains `weapon_attack`,
`shared_spell_attack`, or `shared_spell_save`; `ability` binds its exact attack
or save ability. Production consumers route normal weapon Attack/Extra Attack,
interactive flat/ordered shared-spell attacks, and shared-spell saving throws
through the common captured-test resolver. Attack natural 1 remains a miss and
the kept natural result is checked against the captured critical range. Saves
do not acquire natural-1/20 auto-outcomes. The original action, cast slot and
native payment remain paid once; earlier attacks/steps stay settled, and later
damage, riders and next-hit grants follow the final kept outcome. Both receipts
retain canonical target and captured AC/DC. Stale, replayed, wrong-occurrence,
source-lost and teardown answers cannot roll or pay again.
Combat keep stages retain canonical request ownership through the second popup;
kind, exact encounter participants and a newer request are checked before resume.
Attack rerolls retain all captured fixed contributions and signed bonus dice,
including Blade Ward penalties and pre-roll replacement provenance. The visible
activity uses the kept test's actual bonus-die faces and signed subtotals.
Weapon critical range is captured with the original profile; natural20-only
aftermath uses the final kept natural.

Exact supported routes, authoring examples, Godot commands and remaining limits
are recorded in the [Batch H build/validation report](../../.artifacts/planning/vocabulary-reports/batch-H-build-validation.md)
and accepted [independent review and repairs](../../.artifacts/planning/vocabulary-reports/batch-H-review.md).
