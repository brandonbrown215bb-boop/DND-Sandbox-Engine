# Character- and object-anchored restraint tethers

Shared spells use `bind_tether` to bind individually selected creatures to an
anchor. Character anchors require `concentration: true`; object anchors use the
spell's declared duration without requiring a living caster or concentration.
Use the ordinary `base_targets`/upcast target controls; the selected count is
capped by the tether's `capacity` (1–4) before payment. Capacity is a maximum,
not an instruction to cast again for each victim.

```json
{
  "type": "bind_tether",
  "condition": "restrained",
  "range_hexes": 3,
  "escape": ["STR", "DEX"],
  "capacity": 2,
  "on_failed_save": true,
  "rescue": ["STR"],
  "hp": 5
}
```

`range_hexes` is 1–30. `escape` declares Strength/Athletics and/or
Dexterity/Acrobatics checks against the original cast's save DC. Optional
`rescue` declares those same choices for another creature; optional `hp`
(1–100) permits its melee weapon/attack damage to cut the tether. A victim
escapes for itself; the anchor cannot rescue its own victim.

One cast pays once and makes an independent initial save for each selected
recipient. Failed recipients retain distinct relations beneath the original
source. Successful saves and condition immunity create no relation. Each
relation retains its victim kind/ID, Character anchor ID, range, escape checks,
DC and remaining tether HP. Conditions and effect timers still use the parent
cast source, with its original concentration lifetime.

`Character.tethers` maps relation IDs to records. Group records carry
`source_id`; their key includes the parent, victim kind and stable victim ID.
Existing source-keyed single-recipient save records remain readable. No save
migration or new checkpoint is introduced.

An effect may instead declare `"anchor": "object"`. It uses the same selected
creature targets and capacity. For each failed save, the room binds that victim
to the nearest live object on the same plane and within `range_hexes`; ties use
the stable object ID. No eligible object means that recipient gets no tether.
The room object keeps the exact relation under `tethers`, including the victim,
caster/source attribution, stable anchor ID, current position, plane, HP, DC,
escape choices and optional relation HP. Object anchors do not require
concentration and do not get removed when the caster falls or ends another
concentration. Their condition source still follows the spell's declared
duration.

Room Escape, Rescue and Cut controls use the same exact relation keys for both
anchor kinds. Moving an object uses its existing room record; only relations
that become out of range or cross planes snap. Object damage updates its HP and
immediately releases the relations on that destroyed object. Rescue checks and
melee cuts affect only the selected relation and preserve unrelated conditions.
The room and party checkpoint validators cross-check each object relation
against its exact victim source. Old room objects and Character tether records
remain valid without migration.

Combat anchor selection and range release read live encounter positions, even
when the room checkpoint still has an earlier position. Checkpoint validation
uses the complete world ledger, rejects missing/foreign/duplicated anchors and
requires whole-number relation HP, DC and range before replacing the session.

`TetherRules.binding()` exposes both `source` (parent) and `relation` (exact
selection). Escape/rescue accept that relation key and return `source_id` and
`relation_id` separately. An omitted selection works only for one eligible
relation. A group parent ID, wrong victim, or stale relation refuses before a
roll, damage or payment. Combat chooses the victim through the existing hex
controls, then offers exact relations when ambiguous; rescue also offers its
eligible check/cut routes. Room Escape/Rescue/Cut buttons use the same keys.
Open choices recheck their captured actor, victim and selected relation.

Escape, rescue, cutting, range breaks and recipient-source loss release only
the affected relation. Siblings retain their HP, condition and remaining time.
Ending concentration or removing the parent source from the caster removes
the remaining group; repeated cleanup cannot repeat recipient end effects.
Encounter-only monster relations end with the encounter while persistent
Character siblings can continue to the existing checkpoint. Save validation
checks each persistent relation against its exact victim's original source;
restore rebuilds references without casting, repaying or reapplying effects.

Room casting still uses its existing single-recipient cast entry point; the
multi-recipient casting control is the combat host. Object anchors use the
existing room object movement and damage controls.
The [slice registry](../planning/vocabulary-slices.md#character-tether-groups)
owns the verified boundary and checks.
