# ADR-0015: Keep party remains and recovery on the original character

> Migration scope (2026-10-09): [ADR-0018](0018-shared-data-driven-rules-runtime.md)
> governs new rule execution. Named modules below describe current owners,
> not permanent native handlers for content policy. Identity, ordering,
> cost and compatibility guarantees remain constraints. Dated implementation
> and validation statements describe this ADR's original snapshot.

Status: Accepted, 2026-10-08. Implements the authorized Wave 4 party-body
foundation for Crown. It does not complete Wave 4 or certify every death spell.

The old `is_alive` field also means able to act: an unconscious character at
zero HP has it set to false. Treating this field as death let ordinary healing,
Long Rests and level-ups restore characters who had actually died.

Keep that existing field for compatibility. `Character.is_dead()` and
`is_downed()` distinguish the states explicitly. Actual death records a corpse
on the same Character, with the original character ID, a monotonically
increasing death generation, campaign timestamp, cause, remains, missing parts,
and explicit recovery restrictions. `revival_willing` is an owner-controlled
policy, accessible on the sheet and room recovery panel. Revival keeps the
party slot, class grants and inventory; it clears the corpse after successful
eligibility checks. Missing parts remain recorded on the living Character.

`CorpseRules` owns this narrow record and the death/revival eligibility rules.
`LocalRoomBodies` performs the room transaction; combat uses existing spell
preflight, resource and result boundaries. Both reject ineligible targets before
spending. Ordinary healing, consumables, rest, Aid and level-up healing cannot
revive the dead. Death ends Concentration and item attunement, including cursed
attunement, without deleting equipment. Other ongoing conditions retain their
existing lifetimes. Revival reduces Exhaustion by one.

The first version carries remains with the original party member's slot; it
does not introduce a corpse inventory or independently movable world body.
The party member's room/encounter position supplies the Touch location. NPC and
monster corpses, dropping/transporting bodies, arbitrary dismemberment and
automatic decay are outside this slice. Recorded missing parts/restrictions
support authored injuries and later recovery integrations, but do not yet alter
weapon handling or individual limb statistics.

Gentle Repose stores a ten-day preservation interval and previously accumulated
protected seconds. Recasting settles the preceding interval, then extends
protection; it never resets elapsed unprotected death age. Exploration casts
start preservation at completion. Combat advances the durable campaign clock
six seconds per completed round while keeping existing combat effect/light
ticks; it does not call the exploration effect tick a second time.

Stabilization resets both death-save counters and rolls a saved one-to-four-hour
recovery deadline. The campaign clock restores 1 HP at that deadline; further
damage cancels it. Existing Stable saves without that field retain their prior
stable state and remain healable; loading does not reroll a new deadline.

Keep schema 2 and the 2024 namespace. New fields are optional for existing
schema-2 saves. Old actual deaths with no recorded time receive an unknown
timestamp, never a newly eligible Revivify minute. SaveManager checks body
identity, life-state consistency, bounds and preservation clocks against the
saved campaign clock before writing/loading. Legacy namespaces remain untouched.

See [party recovery clauses and limits](../mechanics/party-recovery-2024.md)
and [Wave 4 acceptance](../mechanics/wave4-acceptance.md) for scope and evidence.
