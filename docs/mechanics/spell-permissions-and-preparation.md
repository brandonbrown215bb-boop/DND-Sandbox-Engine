# Spell permissions, payment and preparation (Batch 021 accepted)

S-134/S-135/S-137 are independently accepted as VS-76/77/78; see the
[acceptance review](../../.artifacts/planning/vocabulary-reports/batch-021-023-acceptance-review.md)
for final production evidence and bounded support.

`Character.get_spell_permissions(spell_id)` derives the current permissions from
the owning class spellcasting choice, the Wizard book, owned `always_prepared_spells`
and `spell_free_cast` features, selected invocation effects, and Warlock Mystic
Arcanum. The combat spell list shows a source-specific row. The selected source
and payment are copied onto the transient cast. The command rebuilds its spell
from production data without modifying the catalog. It rejects missing sources,
cross-source payments and malformed selections. The current permission and its
captured policy must still match before Metamagic or spell payment. Losing a
source, changing its cost, or exhausting its chosen payment refuses the cast.
No saved permission cache is needed; choices, ownership and uses remain authoritative.

Prepared class spells must be selected from that class's declared spell list.
Wizard leveled spells must be in both the book and current prepared choices;
cantrips remain learned through the class selection. Always-prepared and
innate/free-cast features retain their own feature identity and may declare
their own ability and eligibility limits. A spell ID in `known_spells` alone
does not establish a casting permission.

Spell permission effects may declare these optional fields:

- `ability`: an ability override for this source. Otherwise the owning class's
  spellcasting ability is used.
- `maximum_spell_level`: highest leveled spell this source permits.
- `spell_lists`: eligible list IDs, matched against the spell record's `classes`.
- `allowed_components`: if present, every component on the spell must appear in
  this list.
- `slot_payment_allowed`: whether this permission can use an eligible slot.
  Class/book/always-prepared permissions default to true; innate/free-cast
  permissions default to false.
- `point_payment`: optional `{ "resource_id": "...", "cost": N }`, or
  `cost_by_level` keyed by spell level. `sorcery_points` uses the existing
  Character pool; other IDs use that Character's matching feature-use pool.

`spell_free_cast` owns its own free-use source and exhaustion. If both free and
slot payments are authored for one permission, the player chooses one before
targeting. A selected source that is exhausted or no longer legal is refused;
the runtime does not substitute another source after the choice. Existing
Wizard Mastery/Signature and Mystic Arcanum remain their own selected payments.

Prepared and free effects in the same feature remain different permissions. A
prepared permission cannot borrow the free effect's ability or use. Shield and
Counterspell use the same source/payment choices, including exact free uses,
points and item charges. Their Reaction is spent only after payment succeeds.
Direct legacy resolver calls may omit selection metadata only for one unambiguous
permission/payment; a single slot permission uses its lowest affordable slot.
The actual reaction popup always captures the selected source and payment.

The selected ability reaches attack rolls, saves, retained/repeat-save DCs,
Character healing and source-dependent shared effect bonuses. Newly created
combat zones retain their selected DC; supported Fey/Celestial zone consumers
also retain their casting ability. Point casting plus Metamagic checks the whole
Sorcery Point cost before either spends. A stale free Metamagic choice refuses
instead of substituting paid points. Point payments are leveled spells only.

## Item permissions

An item may declare a bounded `spell_permissions` array. Each policy names
`spells`, `ability`, optional restrictions above, and an integer `charges` cost:

```json
"spell_permissions": [{
  "spells": ["practice_spell"],
  "ability": "INT",
  "maximum_spell_level": 1,
  "allowed_components": [],
  "charges": 1
}]
```

The item must be equipped, and attuned to the caster when required. Each copy
and policy occurrence has its own permission ID. The exact copy's existing
charge state pays; identical siblings cannot substitute. Item permissions default
to disallowing slots. Spell IDs need not occur in the caster's flattened known
list. These policies restrict ordinary spell components; they do not waive them.
The Wand's existing dedicated activation and last-charge policy are unchanged.

## Independent preparation

Class `spellcasting` effects can opt into `separate_repertoire: true`. Each
acquired class in `class_levels` then derives its own preparation controls from
that class's feature, ability, `spell_lists`, `capacity_by_level` and spell-level
table. The owning class level sets capacity and available spell levels, never
the combined character level. Primary legacy preparation/book controls remain
available for sources that have not opted in.

Choices reuse `feature_choices[feature_id]`. A small optional
`spell_repertoire_state[feature_id]` receipt records the last trained class
`level` and a `rest_open` boolean. `replacement` declares `level`, `long_rest`
or `fixed`; `replacement_count` limits removals per window (default one).
Initial training and filling available capacity do not borrow a sibling's
replacement permission. Training consumes only its own window; a completed
Long Rest opens only declared rest windows. Stale controls compare the original
source definition and level before mutation. Combat training is refused.

An optional `book_spells` list restricts that source's leveled options to its
authored book entries. The existing Wizard book still owns its actual recorded
spells and preparation, including source-specific component/level/payment limits.
Source removal removes that source's trained projection and receipt while
preserving other sources. Save validation checks lists, capacities, acquired
sources and receipt shape before either full-save DTO replaces the session.
Reload restores receipts without reopening spent windows or acquiring spells.

Current limits: independent preparation is verified for opted-in authored class
sources; existing core classes have not been converted to this policy. General
native multiclass feature acquisition and multiple editable Wizard books remain
outside the verified host. Combined ordinary/Pact slots, fixed-level Mystic
Arcanum uses and source-specific ritual permissions have a separate bounded
build in [slot and ritual casting](spell-slots-and-ritual-casting.md); those
checks do not certify every class or spell route. The item host requires
equipped copies; carried-only permissions and arbitrary component waivers are
not implemented. No catalog permission/payment sources were converted.

Batch build evidence is in the vocabulary report linked from
[`docs/operations/current.md`](../operations/current.md). Independent review
owns acceptance and any further limits.
