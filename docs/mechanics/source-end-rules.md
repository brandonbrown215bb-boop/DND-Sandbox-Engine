# Source-end rules (Batch 019)

Shared spells may declare `source_end_rules` when a granted effect ends on a
later event. Rules are copied onto the exact cast source when it is created;
the runtime removes only that source. This does not create an extra action or
change an event's action cost.

Supported events are `attack`, `cast`, `movement`, `status`, `equipment`,
`range`, and `damage`. A rule may filter the event actor with `actor: "any"`,
`"caster"`, or `"recipient"`. `cast` rules can filter `school`, `spell_id`,
and `paid_slot_level`; the latter is zero when no spell slot was spent.
`attack` rules can filter `action`. `status` rules filter `status` and
`state` (`applied` or `removed`). `equipment` rules filter the item definition
and state (`equipped`, `unequipped`, `dropped`, or `destroyed`). A `range` rule
with `maximum_range_feet` ends only after the tracked recipient is farther than
that distance from the source caster. A `damage` rule can set
`except_source_id: "this_source"` to ignore damage whose settled causal source
ID exactly matches this effect's source ID.

For example:

```json
"source_end_rules": [
  {"event": "cast", "actor": "recipient", "school": "abjuration", "paid_slot_level": 2},
  {"event": "damage", "except_source_id": "this_source"},
  {"event": "range", "maximum_range_feet": 30}
]
```

Cast events are published only after a cast finishes. Their transient facts
include school, spell ID, effective slot level, actual paid slot level,
completed status, invocation/action IDs, and the cast source ID. Source-end
receipts retain the exact ending reason and causal event; the in-process event
history is bounded to 128 entries and is not saved.

The verified event producers are the ordinary combat attack and cast owners,
Character status changes, inventory equipment controls, and represented combat
movement/range checks. The shared movement step publishes for both Character
actors and monster dictionaries. Range checks require the source caster and recipient to
be present in the active combat positions. Monster status removals that bypass
the shared condition/Character controls, exploration outside represented
combat positions, and catalog conversions have not been validated. The
neutral fixtures exercise the shared contract without claiming support for any
particular spell.
