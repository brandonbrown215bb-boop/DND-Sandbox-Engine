# Spell slots, fixed-level uses and ritual casting (Batch 022)

Batch 022 adds a bounded runtime host for the slot and ritual clauses in
S-138/S-139/S-136, independently accepted as VS-79/80/81. The
[acceptance review](../../.artifacts/planning/vocabulary-reports/batch-021-023-acceptance-review.md)
owns final evidence and limits.

## Slot pools

Ordinary multiclass slots derive from acquired class levels and their declared
full- or half-caster progression. Half-caster levels round up before combining
with full-caster levels; the ordinary pool then follows the 2024 multiclass
spell-slot table through level 20. A single source continues to use its
declared class progression. Warlock Pact Magic does not contribute to that
ordinary pool.

Pact Magic has a separate pool and its own maximum slot level. Spellcasting
permissions may offer a Pact slot for a prepared spell from another casting
source, and the selected pool and level travel with the cast. Validation,
commit and refund address that exact pool. Cancelling before commitment spends
nothing. Shield and Counterspell reaction payment retain that same selected
pool, including when ordinary slots are empty; stale Pact selections refuse
without substitution. Short Rest restores Pact slots while retaining the ordinary pool.
Legacy single-class Warlock saves and cast selections continue to use their
existing slot field.

Mystic Arcanum is a fixed-level permission with a source use, not a slot. It
keeps its level and use separate from both pools and restores on Long Rest.

## Ritual access

Ritual casting requires a source-specific permission and an actual spell marked
as a ritual. It checks the selected source, spell level, ritual eligibility and
required components. Ritual-only permission cannot appear as ordinary slot
casting. A selected Wizard spellbook ritual is available without preparation;
it spends no slot and advances campaign time by the permission's additional
ritual time (ten minutes by default) plus the spell's normal casting time,
bounded to one day. Action, Bonus Action and Reaction casting times count as
six seconds; minute- and hour-long spells retain their normal casting time.

Outside combat, open the character sheet's Class Progression section. Each
ritual row names the spell, source and casting ability. Equipped/attuned item
copies get separate rows. The button captures that exact permission and
rebuilds it before casting; source loss or changed policy refuses without
switching to another row. Required materials/hands are checked again at the
button boundary. A successful cast refreshes the sheet and leaves its result
message visible. Combat exposes neither these controls nor normal payment
choices for ritual-only permissions.

Feature and item policies may explicitly set `ritual_allowed: true`;
`ritual_only: true` blocks every normal payment route. Ritual mode pays no
normal slot, free-cast use, points or item charges. It still consumes an
authored consumed Material component. Merely owning an item or preparing a
feature spell does not confer ritual access when that policy disallows it.

The sheet host supports flat self-targeted shared utility spells and existing
managed native condition payloads, including Detect Magic. Targeted, spatial,
ordered-step and other native rituals require their dedicated exploration
controls; their sheet buttons are disabled with an explanation. This repair
does not add a general target/room selector or convert catalog definitions.

Once validation succeeds, starting any ritual ends prior concentration,
including native spells without a managed source ID. The casting delay passes
before the new effect is created, so its duration starts at completion. If the
completed spell requires concentration, it becomes the new concentration.
Rituals resolve as an immediate exploration time advance. Clock settlement can
interrupt completion if the caster dies, becomes incapacitated, or loses its
source/components; elapsed time remains spent but material and effect do not
complete. A general interruption timeline and saved partial rituals are not
implemented.

## Evidence and limits

The [repair report](../../.artifacts/planning/vocabulary-reports/batch-022-repair-review.md)
supersedes the original build's ritual route/timing claims and records current
production checks. The current proof covers declared
full/half progression, ordinary plus Pact payment, secondary Pact-only pools,
Mystic Arcanum's fixed-level use, a Wizard book ritual, loaded feature/item
permissions, real source controls, components and concentration. It does not claim
general native multiclass feature acquisition, converted catalog sources,
multiple editable Wizard books, every class's ritual features or every spell's
component interactions. Existing feature authoring still controls which
classes and spells actually expose these permissions.
