# Druid support and gaps

> Partial behavior/migration snapshot. Dated evidence and catalog counts
> below apply to their original audit, not automatic acceptance of the
> current tree. [Roadmap](../../roadmap.md) selects work;
> [ADR-0018](../decisions/0018-shared-data-driven-rules-runtime.md) governs
> new rule execution. Existing named helpers are transitional.

Rules reference: [2024 Basic Rules, Druid](https://www.dndbeyond.com/sources/dnd/br-2024/character-classes) and [Beast stat blocks](https://www.dndbeyond.com/sources/dnd/br-2024/creature-stat-blocks/).
This is the base-class progression; subclass features are a separate scope.

## Levels 1–20

| Druid level | Base-class features or progression | Status |
|---:|---|---|
| 1 | Spellcasting; Druidic; Primal Order | Spellcasting uses the shared casting capacity and saved spell-choice paths. Primal Order uses the shared choice for Magician or Warden. Druidic is reference-only because languages are not represented in character state. |
| 2 | Wild Shape; Wild Companion | Wild Shape has saved known-form choices and shared Short Rest recovery. Wild Companion summons a saved Fey familiar as a Magic action, paid by a spell slot or Wild Shape use. |
| 3 | Druid subclass | Shared subclass-selection level; Circle features are separate scope. |
| 4 | Ability Score Improvement | Uses shared saved ability-improvement entitlement. Wild Shape gains two known-form choices and the CR 1/2 limit. |
| 5 | Wild Resurgence | Uses the shared spell-slot/resource exchange path. It restores an empty Wild Shape pool once per turn or converts one use into a level-1 slot once per Long Rest. |
| 6 | Subclass feature; Wild Shape uses increase to 3 | Subclass progression is separate. Resource capacity is data-driven. |
| 7 | Elemental Fury | Saved choice reuses the shared feature-choice path. Potent Spellcasting adds Wisdom to Druid cantrip damage; Primal Strike adds a chosen elemental damage rider once per turn on a hit. |
| 8 | Ability Score Improvement; Wild Shape forms gain flight and higher CR | Shared ability improvement; Wild Shape gains two known-form choices, CR 1 forms, and access to forms with a Fly Speed. The shared world now models bounded flight/altitude; complete Wild Shape form integration is not certified. |
| 9 | Spell progression | Data-driven spell slots and prepared capacity. |
| 10 | Subclass feature; cantrip capacity increases | Subclass progression is separate; shared spellcasting table controls capacity. |
| 11 | Spell progression | Data-driven. |
| 12 | Ability Score Improvement | Uses shared saved ability-improvement entitlement. |
| 13 | Spell progression | Data-driven. |
| 14 | Subclass feature | Subclass progression is separate. |
| 15 | Improved Elemental Fury | Primal Strike scales to 2d8; Potent Spellcasting adds 300 feet to eligible Druid cantrip ranges through the shared scaling paths. |
| 16 | Ability Score Improvement | Uses shared saved ability-improvement entitlement. |
| 17 | Wild Shape uses increase to 4 | Data-driven resource capacity. |
| 18 | Beast Spells | While shaped, permits eligible spells without priced or consumed material components; component metadata is only enforced when present on the spell record. |
| 19 | Epic Boon | Uses the shared saved Epic Boon choice. |
| 20 | Archdruid | Recovers one Wild Shape use at Initiative when empty. Nature Magician can exchange 1–4 Wild Shape uses for a level 2/4/6/8 slot once per Long Rest, for either Primal Order. Longevity has no gameplay effect. |

## Implemented Druid slice

Druid's 2024 spellcasting table now declares Wisdom, cantrip and prepared spell
capacity at every level, and the full-caster spell-slot rows. Its class spell
catalog is still a curated subset of the official list. Primal Order stores
Magician or Warden in the shared feature-choice field. Magician adds a cantrip
slot and Wisdom-based Arcana/Nature check bonus; Warden grants Martial weapons
and Medium Armor training.

The old class data included optional 2014 features and spell-known records.
Those were removed or replaced in the 2024 progression. Wild Shape resource
uses scale to three at level 6 and four at level 17, recover one use on a
Short Rest and all uses on a Long Rest. The Character Sheet saves up to 4/6/8
learned forms, offers eligible forms by level/Challenge Rating/Fly Speed, and
lets the Druid replace one learned form after a Long Rest. The curated list
includes the four recommended forms and additional Beasts through CR 1. Wild
Shape spends a use, grants Druid-level temporary Hit Points, applies form
AC/speed/physical scores, records the form for saves, and supports Bonus Action
reversion. It also reverts on incapacitation, unconsciousness, death, or a
Long Rest. Form attacks use their curated attack bonuses and damage; Wolf Pack
Tactics, the Wolf prone rider, Spider poison, and creature skill modifiers use
the same combat/check boundaries as other features. Spells are blocked while
shaped. Level-5 Wild Resurgence restores one Wild Shape use from any available
spell slot when the pool is empty, once during that Druid turn; its reverse
exchange restores a level-1 slot once between Long Rests. Both exchanges use
the class resource and spell-slot state already owned by Character.

Wild Companion supports Cat, Owl, Rat, and Spider stat blocks. In combat the
familiar has its own initiative, can move, Dodge, and use Help to grant
Advantage on the next allied attack against an adjacent target. It cannot
attack or cast spells, and drops out of the encounter if defeated. The chosen
form is stored on the Druid and reappears in later encounters until a Long Rest.
Later owned-creature work adds borrowed senses, supported Touch delivery and
authored check Help for those four forms, with stable HP/presence and correct
ordinary-versus-Wild-Companion lifetimes. See the
[Find Familiar contract](find-familiar-2024.md) for accepted paths and gaps.

Elemental Fury stores Potent Spellcasting or Primal Strike in the common
feature-choice state. Potent Spellcasting adds Wisdom to Druid cantrip damage;
at level 15, a shared range modifier extends Druid cantrips with at least a
10-foot range by 300 feet. Primal Strike prompts for Cold, Fire, Lightning, or
Thunder on a weapon/Beast attack hit, deals 1d8 once per turn, and scales to
2d8 at level 15.

Beast Spells permits spellcasting while shaped at level 18. It rejects spells
whose loaded records declare a material cost or consumed material; spells with
no component metadata pass this eligibility check because the current catalog
does not consistently record those details. Components still need catalog
coverage for full rules accuracy. Archdruid restores one Wild Shape use at
Initiative only when the pool is empty. Nature Magician is a free action once
per Long Rest, available to either Primal Order; the player selects
1–4 Wild Shape uses to exchange for a level 2, 4, 6, or 8 slot. The existing
slot-capacity checks reject exchanges that cannot fit.

This remains partial rules coverage. Wild Shape-specific lifetime outside
combat, Beast size, special traits, save proficiencies and equipment rules
are not fully certified by this audit. A general campaign clock and bounded
flight/altitude now exist; that does not establish complete form behavior. Some stat-block riders that depend on movement or multiattack are not
implemented. The
Crown-band Wolf-only
proposal is withdrawn in [ADR-0002](../decisions/0002-wild-shape-crown-band.md).

The Druid record explicitly sets subclass selection at level 3 and has feature
entries for the full 1–20 progression, including progression-only levels. The
level-19 Epic Boon and level-4/8/12/16 ability-improvement choices use the
existing shared saved-choice paths. Focused checks cover level-1 spell capacity,
both Primal Order options, and Wild Shape resource scaling and recovery. Ice
Knife is also available as a curated level-1 spell; its attack and 5-foot
Dexterity-save burst resolve on both hits and misses in the combat viewport.
