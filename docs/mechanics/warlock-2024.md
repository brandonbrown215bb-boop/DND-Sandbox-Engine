# Warlock 2024 progression

> Partial behavior/migration snapshot. Dated evidence and catalog counts
> below apply to their original audit, not automatic acceptance of the
> current tree. [Roadmap](../../roadmap.md) selects work;
> [ADR-0018](../decisions/0018-shared-data-driven-rules-runtime.md) governs
> new rule execution. Existing named helpers are transitional.

**Rules authority:** [D&D Beyond Basic Rules, Warlock](https://www.dndbeyond.com/sources/dnd/br-2024/character-classes#Warlock).
**SRD basis:** 5.2.1. The class record lists the Warlock's levels 1–20 features,
Charisma spellcasting capacities, invocation counts, Pact Magic slot counts and
slot levels, and the subclass feature levels. Subclass features are delegated
via DataLoader to `data/core/subclasses/fiend_patron.json`.

## Implemented with shared rules

- **Pact Magic:** Uses shared spellcasting capacity, spell choice, slot casting,
  Short Rest/Long Rest recovery, and level-keyed slot tables.
- **Magical Cunning & Eldritch Master:** Magical Cunning uses shared Pact Magic
  slot recovery with once per Long Rest feature use (recovers half max slots, rounded up).
  At level 20, Eldritch Master scales this recovery to all 4 Pact Magic slots.
- **Contact Patron (Level 9):** `contact_other_plane` is always prepared,
  grants 1 free cast per Long Rest, and automatically succeeds on the DC 15
  Intelligence saving throw, taking 0 psychic damage and avoiding incapacitation.
- **Fiend Patron Subclass (`fiend_patron.json`):**
  - **Level 3 - Dark One's Blessing:** Gains temporary Hit Points equal to Warlock
    level + Charisma modifier (minimum 1) when reducing an enemy to 0 Hit Points,
    or when an ally reduces an enemy within 10 feet (2 hexes) to 0 Hit Points.
  - **Level 3, 5, 7, 9 - Fiend Spells:** Always prepared spells granted at level
    thresholds (`burning_hands`, `command`, `scorching_ray`, `suggestion`,
    `fireball`, `stinking_cloud`, `fire_shield`, `wall_of_fire`).
  - **Level 6 - Dark One's Own Luck:** Adds 1d10 to a failed ability check or saving
    throw; pool equal to Charisma modifier (minimum 1) per Long Rest.
  - **Level 10 - Fiendish Resilience:** Choose resistance to any damage type except
    Force during rest; incoming damage of the chosen type is halved. Selection
    persists across save/reload.
  - **Level 14 - Hurl Through Hell:** On attack hit, target is banished through the
    Lower Planes, taking 8d10 psychic damage and the Incapacitated condition until
    the end of your next turn (Fiends take no psychic damage but are incapacitated).
    Usable once per Long Rest, or recharged by expending a level 5 Pact Magic slot.
- **Eldritch Invocations Suite (22 Invocations):**
  - Complete SRD 5.2.1 catalog supported: Agonizing Blast, Armor of Shadows,
    Ascendant Step, Beguiling Influence, Devil's Sight, Devouring Blade, Eldritch Mind,
    Eldritch Smite, Eldritch Spear, Fiendish Vigor, Lifedrinker, Mask of Many Faces,
    Misty Visions, One with Shadows, Otherworldly Leap, Pact of the Blade,
    Pact of the Tome, Repelling Blast, Thirsting Blade, Visions of Distant Realms,
    Whispers of the Grave, Witch Sight.
  - **Pact of the Blade:** Uses Charisma for weapon attack rolls and damage modifiers,
    and supports necrotic, psychic, radiant, or physical damage type selection.
  - **Thirsting Blade & Devouring Blade:** Extra Attack grants 1 extra attack at level 5
    and 2 extra attacks (3 attacks total) at level 12.
  - **Eldritch Smite:** Expends a Pact Magic slot on a pact weapon hit to deal
    `(1 + slot_level)d8` force damage and knock the target Prone (unless Gargantuan).
  - **Lifedrinker:** Expends one Hit Die on hit to heal `1d8 + CON` modifier, and deals
    necrotic/psychic/radiant weapon damage.
  - **Repelling Blast:** Pushes targets 10 feet (2 hexes) away on a hit with the chosen
    cantrip.
  - **Fiendish Vigor:** At-will `false_life` granting maximum 12 temporary Hit Points.
  - **At-will utility spells:** Free casts for `mage_armor`, `disguise_self`,
    `silent_image`, `invisibility`, `levitate`, `jump`, `speak_with_dead`, `arcane_eye`.
  - **Senses:** Blindsight and truesight/darkvision capabilities via Witch Sight,
    Devil's Sight, and Blindsight effects.
- **Mystic Arcanum:** Spells levels 6, 7, 8, and 9 chosen from curated spell lists,
  tracked with individual 1/Long Rest cast pools, and replaceable on level-up.
- **Ability Score Improvements & Epic Boons:** Standard shared progression paths at
  levels 4, 8, 12, 16, and 19.
- **Persistence & Save/Reload:** Complete schema-2 lossless roundtrip serialization
  for invocations, pact weapon damage type, fiendish resilience type, arcanum choices,
  and resource uses.

<a id="srd-feature-inventory"></a>

## SRD 5.2.1 feature inventory — 2026-10-26

Static source/inventory pass, not a rules audit or gameplay proof. SRD headings were read from `SRD_CC_v5.2.1.pdf` (pages are PDF page numbers) and matched by name/level to `data/core/classes/warlock.json` and `data/core/subclasses/fiend_patron.json`. Repo status is the [feature matrix](../feature_matrix.md) exposure label / record `rules_status`. Registry slice is shown only where the slice registry names this feature or its generic consumer; `unassigned` means no documented owning slice. V-IDs are the [checklist](../reviews/dnd-code-vocabulary-gap-checklist.md) rows citing this feature as an example; they are open requirements, not owning slices. **Reviewed** means an SRD clause review recorded in the [slice registry](../planning/vocabulary-slices.md); every other row is unreviewed, whatever its `rules_status` says. Rows absent from repo data are not filled from memory.

SRD subclass: **Fiend Patron** — present as `fiend_patron`.

| Kind | Lvl | SRD feature / repo record | SRD | Repo ID | Repo status | V-IDs | Registry slice (documented limit) | Review |
|---|---:|---|---|---|---|---|---|---|
| class | 1 | Eldritch Invocations | p.70 | `warlock_eldritch_invocations` | mechanics-backed / 2024-partial | — | unassigned | Unreviewed |
| class | 1 | Pact Magic | p.71 | `warlock_pact_magic` | mechanics-backed / 2024-partial | — | unassigned | Unreviewed |
| class | 2 | Magical Cunning | p.72 | `warlock_magical_cunning` | mechanics-backed / 2024-partial | — | unassigned | Unreviewed |
| class | 3 | Warlock Subclass | p.72 | (subclass choice) | repo uses `subclass_level` = 3 | — | unassigned | Unreviewed |
| class | 4 | Ability Score Improvement | p.72 | `warlock_ability_improvement_4`, `warlock_ability_improvement_8`, `warlock_ability_improvement_12`, `warlock_ability_improvement_16` | mechanics-backed / 2024-supported | — | S-049/S-050/S-084/S-085/S-103/S-104 (fixture-only Origin/ASI feat acquisition; feat content, prerequisites, ability benefits, Fighting Style grants, level-19 feat path open) | Unreviewed |
| class | 9 | Contact Patron | p.72 | `warlock_contact_patron` | mechanics-backed / 2024-supported | — | unassigned | Unreviewed |
| class | 11 | Mystic Arcanum | p.72 | `warlock_mystic_arcanum_6`, `warlock_mystic_arcanum_7`, `warlock_mystic_arcanum_8`, `warlock_mystic_arcanum_9` | mechanics-backed / 2024-supported | — | unassigned | Unreviewed |
| class | 19 | Epic Boon | p.72 | `warlock_epic_boon` | mechanics-backed / 2024-partial | — | S-049/S-050/S-084/S-085/S-103/S-104 (fixture-only Origin/ASI feat acquisition; feat content, prerequisites, ability benefits, Fighting Style grants, level-19 feat path open) | Unreviewed |
| class | 20 | Eldritch Master | p.72 | `warlock_eldritch_master` | quarantined / 2024-partial | — | unassigned | Unreviewed |
| subclass | 3 | Dark One’s Blessing | p.76 | `fiend_dark_ones_blessing` | mechanics-backed / 2024-supported | — | unassigned | Unreviewed |
| subclass | 3 | Fiend Spells | p.76 | `fiend_spells_3`, `fiend_spells_5`, `fiend_spells_7`, `fiend_spells_9` | mechanics-backed / 2024-supported | — | unassigned | Unreviewed |
| subclass | 6 | Dark One’s Own Luck | p.76 | `fiend_dark_ones_own_luck` | mechanics-backed / 2024-supported | — | unassigned | Unreviewed |
| subclass | 10 | Fiendish Resilience | p.76 | `fiend_fiendish_resilience` | mechanics-backed / 2024-supported | — | unassigned | Unreviewed |
| subclass | 14 | Hurl Through Hell | p.76 | `fiend_hurl_through_hell` | mechanics-backed / 2024-supported | V-068 | unassigned | Unreviewed |
