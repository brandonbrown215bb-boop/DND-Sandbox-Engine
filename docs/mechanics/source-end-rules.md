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

## Located end continuations

Shared spell records and self-recipient activation modes from class, subclass,
species or feat definitions can declare `end_aftermath`. Each removal captures
the exact `source_id`, producer definition, caster, recipient, end reason, cause,
ending source record and `final_location` **before** removing grants or reverting
a projection. Location includes plane, room ID, hex position, elevation and
altitude. Combat Characters use the live encounter positions; room Characters
use the room position map. Unknown location stays explicitly unknown.

Immediate `effects` retain the existing damage/condition behavior. Alternatively,
an entry can declare ordered `children`, an explicit `cancel_policy` (`skip` or
`stop`) and optional `delay_seconds` (0–86400):

```json
"end_aftermath": [{
  "id": "afterglow",
  "reasons": ["expired"],
  "delay_seconds": 12,
  "cancel_policy": "skip",
  "children": [
    {"id": "mend", "type": "heal", "amount": 4, "choose": true},
    {"id": "remnant", "type": "room_object", "kind": "loose", "name": "Cooling remnant", "hp": 7},
    {"id": "embers", "type": "room_area", "kind": "entry_damage", "trigger_scope": "entry", "amount": 3, "damage_type": "fire", "radius_hexes": 0, "duration_seconds": 120, "trigger_limit": 1}
  ]
}]
```

Spell expiry is `expired`; mode expiry retains the existing exact reason
`duration`. Exact item copies and each created actor now publish through the same
captured event/continuation path. Item identity includes its owner, copy ID and
form serial; created-actor identity uses its exact actor ID and parent source.
The form's last location is captured before the copy returns or is destroyed,
or before an actor leaves its room/encounter. An item form's death does not by
itself destroy its original copy: `on_zero_hp` controls that separate outcome.
`expired`, `dismissed`, `destroyed` and `death` remain separate reason keys.
Source removal ends each still-live created actor independently; already-ended
actors retain their once-only identity. No item projection timer is authored
yet; a caller ending an item form supplies its actual reason.

A lethal item return waiting for bag/ground space retains its captured end time
and complete final location across checkpoints. Later return settlement queues
its children in that original represented room, including a dormant room, without
recapturing the owner's new position. This host uses unique represented room IDs;
cross-dungeon rooms sharing an ID need broader world addressing. A stale created
actor callback whose parent source has already gone cannot publish a second end.

Located children require a represented room recipient before activation/cast
payment. The room stores `source_end_continuations` independently of the
diagnostic event ring. Delay deadlines use captured campaign time. Observation
and resumed choices always use the captured location, even after the recipient
moves. A source without a represented ending room cannot create world children.
Area duration starts when the child actually creates the area.

`CombatChildActions` supplies child selection/completion/cancellation state.
Automatic children execute in declaration order; `choose: true` exposes Continue
and Cancel controls in the local room. Skip cancels just that child and resumes
siblings; stop abandons the remaining children. Neither repeats source costs,
reactivates the source, or refunds its use. Stale answers refuse. Missing healing
recipients and full room object/area records leave an automatic child retryable
without blocking checkpoints. Decisions must finish before saving; waiting
timers and completed receipts survive existing entrance/overworld checkpoints.

Healing targets the captured Character recipient. Loose objects use
`LocalRoomRules` and retain ordinary object HP/damage behavior. Entry hazards use
`LocalRoomAreas`; room movement and `CombatSpellZones` entry delivery apply the
declared flat typed damage. The cap is **per creature for that area's lifetime**.
Standing inside, movement within the area, crossing a boundary without an entry,
turn start/end, appearance and teleport arrival do not add triggers. Wrong-plane
entry does not spend the cap. Crossing/turn scopes and other hazard kinds refuse
at definition validation.

Each successor has a child identity distinct from its ending parent. Parent
cleanup does not remove successors; area expiry and ordinary object damage own
their subsequent lifecycle. Saved receipts pin the declaration, reason, origin,
remaining children and successor provenance. Active rooms and their dormant
dungeon snapshots are not independently ticked as two worlds.

Rest/group modes, non-room end locations and combat choice controls remain
unsupported by this continuation. Item-copy and created-actor producers use the
same room children as shared spells and self modes. Actor successors and other
hazard/object kinds remain outside this slice. The neutral/renamed fixtures
prove generic definition lookup, not catalog conversion or every source rule.
