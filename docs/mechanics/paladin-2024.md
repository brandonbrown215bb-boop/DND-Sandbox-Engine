# Paladin support and gaps

> Partial behavior/migration snapshot. Dated evidence and catalog counts
> below apply to their original audit, not automatic acceptance of the
> current tree. [Roadmap](../../roadmap.md) selects work;
> [ADR-0018](../decisions/0018-shared-data-driven-rules-runtime.md) governs
> new rule execution. Existing named helpers are transitional.

Rules reference: [2024 Basic Rules, Paladin](https://www.dndbeyond.com/sources/dnd/br-2024/character-classes).
This document tracks the base class; Sacred Oath features are separate scope.

## Levels 1–20

| Paladin level | 2024 base-class progression | Current support |
|---:|---|---|
| 1 | Lay on Hands; Spellcasting; Weapon Mastery | Shared healing pool, Charisma spell preparation, and saved mastery choices are declared. Lay on Hands spends 5 pool points to remove Poisoned without also healing. |
| 2 | Fighting Style; Paladin’s Smite | Shared saved choice offers Archery, Defense, Great Weapon Fighting, Two-Weapon Fighting, or Blessed Warrior. The feat options reuse Fighter’s mechanics; Blessed Warrior grants two Cleric cantrips through shared spell-list and capacity paths. Divine Smite is always prepared and resolves after a melee weapon or Unarmed Strike hit as a Bonus Action. Its free Long Rest cast uses the saved shared pool; paid casts use shared spell-slot spending. Upcasting and extra damage against Fiends and Undead read from the spell record. |
| 3 | Channel Divinity; Paladin Subclass | Two uses, one-use Short Rest recovery, and the level-11 increase to three are declared. Divine Sense uses the shared pool and Bonus Action; it detects typed combat creatures out to 60 feet and refreshes their locations for 10 minutes. Consecrated/desecrated places and objects and exploration outside combat are not modeled. Shared subclass selection is at level 3; oath features are separate. |
| 4 | Ability Score Improvement | Shared saved improvement choice. |
| 5 | Extra Attack; Faithful Steed | Shared Extra Attack; Find Steed is always prepared and has one free cast per Long Rest via the shared free-cast effect. Casting chooses a rideable appearance and Celestial/Fey/Fiend type, creates a persistent ally in an unoccupied space, and saves its remaining HP. AC and HP scale with the spent spell slot; level 4+ stores a 60-foot Fly Speed. The shared attack resolver handles Otherworldly Slam, and each type has its own once-per-Long-Rest Bonus Action: Healing Touch, Fey Step, or Fell Glare. Life Bond copies spell healing to the steed when the Paladin is within 5 feet. Owner death and steed death remove the bond. Later shared movement adds mounted state, half-Speed mount/dismount, rider transport and bounded flight. Fey Step updates the mounted rider too. Full mounted/flight clauses remain uncertified. |
| 6 | Aura of Protection | The Paladin and nearby allies add the Paladin’s Charisma modifier (minimum +1) to saves within 10 feet. It ends while the Paladin is incapacitated. Overlapping auras do not stack. |
| 7 | Subclass feature | Supplied by the selected subclass when available. |
| 8 | Ability Score Improvement | Shared saved improvement choice. |
| 9 | Abjure Foes | A Magic action spends the shared Channel Divinity use and lets the player choose up to the Charisma modifier in foes within 60 feet. Targets make Wisdom saves against the Paladin spell DC; failures are Frightened for up to 10 rounds or until damaged. Later shared condition work blocks movement toward the visible source and applies its attack penalty, preserving source-specific removal. Full Frightened clauses remain uncertified. |
| 10 | Aura of Courage | The Paladin and allies within Aura of Protection are immune to Frightened while the Paladin is not incapacitated; a condition already present is suppressed in range and resumes on leaving. |
| 11 | Channel Divinity capacity increase; Radiant Strikes | Shared pool capacity increases to 3. Melee weapon hits add 1d8 Radiant damage through the shared damage-rider operation. |
| 12 | Ability Score Improvement | Shared saved improvement choice. |
| 13 | Spell progression | Half-caster slots are data-driven. |
| 14 | Restoring Touch | The existing Lay on Hands Bonus Action can also remove Blinded, Charmed, Deafened, Frightened, Paralyzed, and Stunned, spending 5 pool points per condition through the shared healing resolver. |
| 15 | Subclass feature | Supplied by the selected subclass when available. |
| 16 | Ability Score Improvement | Shared saved improvement choice. |
| 17 | Spell progression | Half-caster slots are data-driven. |
| 18 | Aura Expansion | Shared radius expansion increases Aura of Protection and Aura of Courage to 30 feet. |
| 19 | Epic Boon | Shared saved Epic Boon choice. |
| 20 | Subclass feature | Supplied by the selected subclass when available. |

## Implemented slice

The base-class record now follows the 2024 level table, including full
half-caster spell slots, prepared-spell capacity, level-3 subclass selection,
Channel Divinity, the level-11 use increase, and ability-improvement levels.
Class spell access is limited to 35 Paladin spell IDs present in the current
catalog; the official Paladin list is larger. Spell preparation and Weapon
Mastery use shared saved-choice paths. Fighting Style offers the four SRD
styles plus Blessed Warrior: the four styles reuse Fighter's existing combat
rules, while Blessed Warrior adds two cantrips and the Cleric list through
shared spell-capacity and spell-list effects. The existing Lay on Hands action
is a Bonus Action and its pool scales by Paladin level. Extra Attack, Find
Steed always-prepared access, the level-19 Epic Boon, and Radiant Strikes use
existing shared paths. Faithful Steed's free cast shares the saved spell-use
pool, while a narrow PaladinRules operation derives and saves the summoned
creature's slot-scaled stat block; CombatState materializes it as a party entity
and restores it for later combats. Its Slam uses the shared weapon attack
resolver; its creature-specific Bonus Action uses one saved Long Rest cooldown.
Life Bond shares actual healing from level-1-or-higher spells with the nearby
steed. Death cleanup removes the bond when either creature dies. Radiant Strikes
is not limited to once per turn and only applies to melee weapon attacks through
the current combat flow. Aura of
Protection, Aura of Courage, and level-18 Aura Expansion use one position-aware
shared aura path that feeds the common saving-throw and condition queries.
Divine Smite is a triggered spell whose rules data supplies its base dice,
upcast growth, and Fiend/Undead bonus; its dedicated resolver reuses shared slot
spending and character damage resistance.

Several unique combat effects remain disabled or partial until supported:
Find Steed's spell-specific actions, Life Bond healing, and death cleanup are
implemented through shared combat actions and a small PaladinRules operation.
Bounded mounted movement and flight now use shared movement/altitude; full
mount and flight rules are not certified. Divine Sense detects
celestial, fiend, and undead combat records using curated creature types,
refreshes locations at the Paladin's turns, and ends on incapacitation or after
100 six-second rounds. Consecrated/desecrated places and objects and exploration
outside combat are not modeled. Abjure Foes shares the Channel Divinity pool,
Magic action budget, spell-save DC, and Frightened condition. Target selection,
Wisdom saves, condition immunity, damage break, and duration work; the later shared path
blocks movement closer to its source and applies the visible-source attack
penalty. Broad Frightened/condition clauses still require individual acceptance.
Divine Sense is a listed Channel Divinity option here, not a separate level-1
feature. The 2014-only Divine Health, Martial Versatility, and Harness Divine
Power are excluded from this 2024 base-class record. A feature description
alone is not production support.

<a id="srd-feature-inventory"></a>

## SRD 5.2.1 feature inventory — 2026-10-26

Static source/inventory pass, not a rules audit or gameplay proof. SRD headings were read from `SRD_CC_v5.2.1.pdf` (pages are PDF page numbers) and matched by name/level to `data/core/classes/paladin.json`. Repo status is the [feature matrix](../feature_matrix.md) exposure label / record `rules_status`. Registry slice is shown only where the slice registry names this feature or its generic consumer; `unassigned` means no documented owning slice. V-IDs are the [checklist](../reviews/dnd-code-vocabulary-gap-checklist.md) rows citing this feature as an example; they are open requirements, not owning slices. **Reviewed** means an SRD clause review recorded in the [slice registry](../planning/vocabulary-slices.md); every other row is unreviewed, whatever its `rules_status` says. Rows absent from repo data are not filled from memory.

SRD subclass: **Oath of Devotion** — absent from repo data.

| Kind | Lvl | SRD feature / repo record | SRD | Repo ID | Repo status | V-IDs | Registry slice (documented limit) | Review |
|---|---:|---|---|---|---|---|---|---|
| class | 1 | Lay On Hands | p.53 | `paladin_lay_on_hands` | mechanics-backed / unset | — | unassigned | Unreviewed |
| class | 1 | Spellcasting | p.54 | `paladin_spellcasting` | mechanics-backed / 2024-supported | — | unassigned | Unreviewed |
| class | 1 | Weapon Mastery | p.54 | `paladin_weapon_mastery` | mechanics-backed / 2024-supported | — | unassigned | Unreviewed |
| class | 2 | Fighting Style | p.54 | `paladin_fighting_style` | mechanics-backed / 2024-supported | — | S-049/S-050/S-084/S-085/S-103/S-104 (fixture-only Origin/ASI feat acquisition; feat content, prerequisites, ability benefits, Fighting Style grants, level-19 feat path open) | Unreviewed |
| class | 2 | Paladin’s Smite | p.54 | `paladin_paladins_smite` | mechanics-backed / 2024-supported | — | unassigned | Unreviewed |
| class | 3 | Channel Divinity | p.54 | `paladin_channel_divinity` | mechanics-backed / 2024-supported | — | unassigned | Unreviewed |
| class | 3 | Paladin Subclass | p.55 | `paladin_sacred_oath` | quarantined / reference-only | — | unassigned | Unreviewed |
| class | 4 | Ability Score Improvement | p.55 | `paladin_ability_improvement_4`, `paladin_ability_improvement_8`, `paladin_ability_improvement_12`, `paladin_ability_improvement_16` | mechanics-backed / 2024-supported | — | S-049/S-050/S-084/S-085/S-103/S-104 (fixture-only Origin/ASI feat acquisition; feat content, prerequisites, ability benefits, Fighting Style grants, level-19 feat path open) | Unreviewed |
| class | 5 | Extra Attack | p.55 | `paladin_extra_attack` | mechanics-backed / 2024-supported | — | S-084 (PARTIAL: exclusive Extra Attack count consumer accepted; source-backed class conversion open) | Unreviewed |
| class | 5 | Faithful Steed | p.55 | `paladin_faithful_steed` | mechanics-backed / 2024-partial | — | S-122 continuation (Batch 086 Find Steed arrival; exploration occupancy PARTIAL) | Unreviewed |
| class | 6 | Aura of Protection | p.55 | `paladin_aura_of_protection` | mechanics-backed / 2024-supported | — | unassigned | Unreviewed |
| class | 9 | Abjure Foes | p.55 | `paladin_abjure_foes` | mechanics-backed / 2024-partial | — | unassigned | Unreviewed |
| class | 10 | Aura of Courage | p.55 | `paladin_aura_of_courage` | mechanics-backed / 2024-supported | — | unassigned | Unreviewed |
| class | 11 | Radiant Strikes | p.55 | `paladin_radiant_strikes` | mechanics-backed / 2024-supported | — | unassigned | Unreviewed |
| class | 14 | Restoring Touch | p.55 | `paladin_restoring_touch` | mechanics-backed / 2024-supported | — | unassigned | Unreviewed |
| class | 18 | Aura Expansion | p.55 | `paladin_aura_expansion` | mechanics-backed / 2024-supported | — | unassigned | Unreviewed |
| class | 19 | Epic Boon | p.55 | `paladin_epic_boon` | mechanics-backed / 2024-supported | — | S-049/S-050/S-084/S-085/S-103/S-104 (fixture-only Origin/ASI feat acquisition; feat content, prerequisites, ability benefits, Fighting Style grants, level-19 feat path open) | Unreviewed |
| repo-only class | 3 | Channel Divinity: Divine Sense | No SRD 5.2.1 heading found — source gap | `paladin_channel_divinity_divine_sense` | mechanics-backed / 2024-partial | — | unassigned | Unreviewed |
| repo-only class | 7 | Paladin Subclass Feature | Placeholder for subclass level; SRD subclass body not in repo | `paladin_subclass_7` | quarantined / reference-only | — | unassigned | Unreviewed |
| repo-only class | 15 | Paladin Subclass Feature | Placeholder for subclass level; SRD subclass body not in repo | `paladin_subclass_15` | quarantined / reference-only | — | unassigned | Unreviewed |
| repo-only class | 20 | Paladin Subclass Feature | Placeholder for subclass level; SRD subclass body not in repo | `paladin_subclass_20` | quarantined / reference-only | — | unassigned | Unreviewed |
| subclass | 3 | Oath of Devotion Spells | p.56 | — | absent | — | unassigned | Unreviewed (absent) |
| subclass | 3 | Sacred Weapon | p.56 | — | absent | — | unassigned | Unreviewed (absent) |
| subclass | 7 | Aura of Devotion | p.56 | — | absent | — | unassigned | Unreviewed (absent) |
| subclass | 15 | Smite of Protection | p.57 | — | absent | — | unassigned | Unreviewed (absent) |
| subclass | 20 | Holy Nimbus | p.57 | — | absent | — | unassigned | Unreviewed (absent) |
