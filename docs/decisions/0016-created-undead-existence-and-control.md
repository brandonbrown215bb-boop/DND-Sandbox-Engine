# ADR-0016: Separate created Undead existence from obedience

> Migration scope (2026-10-09): [ADR-0018](0018-shared-data-driven-rules-runtime.md)
> governs new rule execution. Named modules below describe current owners,
> not permanent native handlers for content policy. Identity, ordering,
> cost and compatibility guarantees remain constraints. Dated implementation
> and validation statements describe this ADR's original snapshot.

Status: Accepted, 2026-10-08. Implements the bounded Crown Animate Dead
foundation; animated objects and Finger of Death remain separate integrations.

Animate Dead creates a lasting creature whose control expires. Storing it only
on a living caster or treating the control timer as a summon lifetime would
delete it on death/expiry or restore its HP on the next encounter.

Keep a plain campaign-level `created_creatures` ledger with stable serial IDs,
source body identity, creator ID, curated form, HP, room position, standing
order and separate creation/control timestamps. `existence_until: -1` means
this creature has no spell expiry; zero HP ends its living presence. Records
remain independent of the creator's party slot or life state.

`CreatedCreatureRules` owns eligibility, creation, renewal, stat projections and
save validation. `LocalRoomCreated` provides existing room controls.
`CreatedCreatureCombat` adds encounter actors and executes supported orders
through shared movement, weapon damage and initiative. Controlled actors take
their own turns outside the four party slots. Control expiry converts the same
initiative entry to a hostile actor without a new roll or HP restoration.
Encounter completion captures both friendly and hostile creature HP/position.

The first version creates one Skeleton or Zombie with a level-3 slot, renews
up to four nearby controlled Undead, and provides attack/Dodge and room
follow/stay orders. A selected enemy defines an attack task; encounter exit
completes that task. Uncontrolled creatures remain in their last room, use the
existing aggressive enemy AI and can be faced even after the original room
encounter was cleared. Following only relocates controlled creatures when the
owner enters an authored local room; overworld encounters are not supported.

Eligible bodies are authored Small/Medium Humanoid remains or recorded party
corpses. Gentle Repose refuses animation before cost. An animated world body
is consumed; a party corpse retains its original Character/equipment but gains
an explicit recovery restriction. The new Undead uses its curated equipment,
not the party inventory. This is a first-version restriction, not a complete
revival-after-transformation rules claim.

Keep schema 2 and the 2024 namespace. Optional ledger fields default to an empty
ledger for older saves. Validation checks uniqueness, HP, 24-hour intervals,
timestamps and known saved dungeon/room cells before manager mutation. The
ledger does not serialize encounter conditions, equipment changes or spell
effects on created actors. Those remain explicit limits; loading must not
silently claim their persistence. No legacy conversion is introduced.

See [Animate Dead clauses and limits](../mechanics/animate-dead-2024.md) and
[creature and body requirements](../mechanics/spell-foundations.md#wave-4--creatures-bodies-forms-and-social-interaction).
