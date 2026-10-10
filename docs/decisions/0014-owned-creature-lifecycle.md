# ADR-0014: Keep owned creature identity separate from encounter projections

> Migration scope (2026-10-09): [ADR-0018](0018-shared-data-driven-rules-runtime.md)
> governs new rule execution. Named modules below describe current owners,
> not permanent native handlers for content policy. Identity, ordering,
> cost and compatibility guarantees remain constraints. Dated implementation
> and validation statements describe this ADR's original snapshot.

Status: Accepted, 2026-10-08

Crown already exposes Wild Companion and Find Steed. Rebuilding a familiar
from its form name at every encounter rerolled its Hit Points and used a
process-specific identity. A summon also needs to remain distinct from the
four party slots, so a living summon cannot prevent the party's defeat.

Keep the existing owner-bound records. `FamiliarRules` owns a familiar's
plain creature ID, owner ID, form, maximum/current HP, pocket presence, room
position, origin, creature type and lifetime inside the owner's saved feature
state. Wild Companion expires on a Long Rest; ordinary Find Familiar does not.
`PaladinRules` retains its existing steed record. Encounter Characters are
projections of those records, never new grants. Damage and final room cells
settle into the owner before encounter return. Do not add summons to the
party's position/altitude maps or campaign roster.

Validate both records before save writing or session mutation. Earlier 2024
schema-2 familiar form-only records reconstruct deterministic average HP
without resource use or gameplay dice; those old records contain no damage to
recover. This compatibility path does not migrate legacy rules/save namespaces.

Placement is checked before a new summon spends its class resource or action.
Pocket dismissal retains the familiar; recall retains its HP and, within the
same encounter, initiative. Zero HP or permanent release removes the bond.
The Druid's completed Long Rest removes even a pocketed Wild Companion.
Presence commands derive their canonical Magic action cost from the existing
bond at the command boundary, rather than trusting a HUD-supplied cost.
Removing a familiar also removes its source-owned Help marker.

Familiars retain their independent initiative and owner-seat control. The
bounded fallback for an owner who is downed or incapacitated is an automatic
Dodge turn. A steed survives a downed owner; disintegration or three failed
death saves ends its bond. Existing mounted controls remain in place. Both
summon types are excluded from the party-wipe survivor check.

Borrowed senses remain transient Character state. `CombatPerception` reads the
familiar's viewpoint, and the owner's next turn or loss of presence clears it.
`FamiliarSpellDelivery` changes only the Touch range origin. It preflights
before resources and commits the familiar's Reaction at the existing spell
resource boundary; the owner remains the caster. Authored exploration Help
applies directly to one check rather than creating a durable advantage token.

The current first version does not certify every familiar form or spell clause.
See [the clause checklist](../mechanics/find-familiar-2024.md) for supported
controls, the four curated forms and explicit limits. Other controlled creatures
and independent control expiry remain separate work. Room presence controls
use legal floor cells; independent familiar scouting is still open. Keep the
current safe-save restrictions.
