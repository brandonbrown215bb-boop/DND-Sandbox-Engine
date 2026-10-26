# Sorcerer (2024 SRD 5.2.1)

> Partial behavior/migration snapshot. Dated evidence and catalog counts
> below apply to their original audit, not automatic acceptance of the
> current tree. [Roadmap](../../roadmap.md) selects work;
> [ADR-0018](../decisions/0018-shared-data-driven-rules-runtime.md) governs
> new rule execution. Existing named helpers are transitional.

The class record in `data/core/classes/sorcerer.json` now covers the 2024
progression through level 20, including full spell slots, cantrip and prepared
spell capacity, level-based Sorcery Points, Innate Sorcery, Sorcerous
Restoration, ASIs, and Epic Boon.

| Level | 2024 feature | Current behavior |
|---:|---|---|
| 1 | Spellcasting, Innate Sorcery | Shared Charisma spell selection/slots and two-use Bonus Action Innate Sorcery. The spell list is an eight-spell subset; class spell attack/save effects are partial. |
| 2 | Font of Magic, Metamagic | Convert available spell slots into an equal number of Sorcery Points without exceeding the pool maximum (no action). Create level 1–5 spell slots using the SRD point cost/level table (Bonus Action); created slots disappear on Long Rest. Combat exposes both operations. Character training saves Metamagic choices; Careful, Distant, Empowered, Extended, Heightened, Quickened, Seeking, Subtle, Transmuted, and Twinned currently have combat effects. Careful lets you choose up to your Charisma modifier (minimum one) affected creatures that automatically succeed on the spell save and take no damage. Extended doubles explicit spell durations of at least one minute (maximum 24 hours), doubles supported timed effect durations, and grants Advantage on Concentration saves for that spell. Quickened costs 2 points, changes an action spell to a Bonus Action spell, and enforces the 2024 restriction on level-1+ spells cast before or after it that turn. Subtle removes verbal, somatic, and free material components from the currently tagged Sorcerer spells; costly or consumed Material components remain. Component-free casts cannot be counterspelled during the casting window. Transmuted applies to spells with a single eligible damage type in the supported spell data; Seeking rerolls a missed single spell attack and spends its point only when the reroll is used. Twinned costs 1 point and adds a target when the spell gains targets from a higher-level slot; Charm Person is currently the supported example and is limited to humanoids. |
| 3 | Sorcerer Subclass | Subclass selection is at level 3; no Sorcerer subclass records currently ship. |
| 4 | Ability Score Improvement | Shared ASI choice; cantrip capacity also increases. |
| 5 | Sorcerous Restoration | Shared Short Rest recovery restores up to half your level in Sorcery Points once per Long Rest. |
| 6 | Subclass feature | Subclass record unavailable. |
| 7 | Sorcery Incarnate | If Innate Sorcery has no uses remaining, its Bonus Action can be used again for 2 Sorcery Points. While active, apply up to two implemented Metamagic options to one spell. |
| 8 | Ability Score Improvement | Shared ASI choice. |
| 9 | — | Spell slots, prepared spells, and Sorcery Points advance through their shared tables. |
| 10 | Metamagic | Choose two more options. |
| 11 | — | Spell slots, prepared spells, and Sorcery Points advance through their shared tables. |
| 12 | Ability Score Improvement | Shared ASI choice. |
| 13 | — | Spell slots, prepared spells, and Sorcery Points advance through their shared tables. |
| 14 | Subclass feature | Subclass record unavailable. |
| 15 | — | Spell slots, prepared spells, and Sorcery Points advance through their shared tables. |
| 16 | Ability Score Improvement | Shared ASI choice. |
| 17 | Metamagic | Choose two more options. |
| 18 | Subclass feature | Subclass record unavailable. |
| 19 | Epic Boon | Shared Epic Boon choice UI; supported outcomes remain limited to common options. |
| 20 | Arcane Apotheosis | While Innate Sorcery is active, one Metamagic option each turn can waive its Sorcery Point cost. |

The class is partial overall because the spell catalog and subclass records
remain curated/incomplete. Twinned's current production path supports
upcast-target metadata on Charm Person. A focused Godot combat viewport scenario
verified the owner prompt, selection of two humanoids, an independent Wisdom
save for each target, and the Sorcery Point, spell slot, and Magic action costs.
Metamagic choices and one replacement opportunity on Sorcerer level-up are
saved and validated. The curated Sorcerer spell choices now include Ice Knife;
its piercing attack and separate cold burst after either hit or miss are
verified in the mixed-combat viewport scenario. Disintegrate is available as a
level-6 choice and its saving throw, upcast damage, disintegration marker, and
healing restriction use the shared production path. Rules reference:
[2024 Basic Rules, Sorcerer](https://www.dndbeyond.com/sources/dnd/br-2024/character-classes).

Empowered Spell displays the actual rolled damage dice and lets the owner
select up to their Charisma modifier (minimum one) for replacement. Constants,
unselected dice, and discarded Inspiration dice are preserved. Each new roll
stands even if lower. Damage and the Sorcery Point cost settle only after a
valid selection; cancelling the picker spends no point. Critical damage,
Magic Missile darts, and successful Scorching Ray damage retain all their dice.
Area spells share one settled damage roll and one Empowered cost across their
targets. Training permits saving the available spell catalog while missing
cantrip/prepared choices remain pending.

<a id="srd-feature-inventory"></a>

## SRD 5.2.1 feature inventory — 2026-10-26

Static source/inventory pass, not a rules audit or gameplay proof. SRD headings were read from `SRD_CC_v5.2.1.pdf` (pages are PDF page numbers) and matched by name/level to `data/core/classes/sorcerer.json`. Repo status is the [feature matrix](../feature_matrix.md) exposure label / record `rules_status`. Registry slice is shown only where the slice registry names this feature or its generic consumer; `unassigned` means no documented owning slice. V-IDs are the [checklist](../reviews/dnd-code-vocabulary-gap-checklist.md) rows citing this feature as an example; they are open requirements, not owning slices. **Reviewed** means an SRD clause review recorded in the [slice registry](../planning/vocabulary-slices.md); every other row is unreviewed, whatever its `rules_status` says. Rows absent from repo data are not filled from memory.

SRD subclass: **Draconic Sorcery** — absent from repo data.

| Kind | Lvl | SRD feature / repo record | SRD | Repo ID | Repo status | V-IDs | Registry slice (documented limit) | Review |
|---|---:|---|---|---|---|---|---|---|
| class | 1 | Spellcasting | p.64 | `sorcerer_spellcasting` | mechanics-backed / 2024-partial | — | unassigned | Unreviewed |
| class | 1 | Innate Sorcery | p.65 | `sorcerer_innate_sorcery` | mechanics-backed / 2024-partial | — | unassigned | Unreviewed |
| class | 2 | Font of Magic | p.66 | `sorcerer_font_of_magic` | mechanics-backed / 2024-partial | — | unassigned | Unreviewed |
| class | 2 | Metamagic | p.66 | `sorcerer_metamagic` | mechanics-backed / 2024-partial | V-042 | unassigned | Unreviewed |
| class | 3 | Sorcerer Subclass | p.66 | `sorcerer_subclass` | quarantined / reference-only | — | unassigned | Unreviewed |
| class | 4 | Ability Score Improvement | p.66 | `sorcerer_ability_improvement_4`, `sorcerer_ability_improvement_8`, `sorcerer_ability_improvement_12`, `sorcerer_ability_improvement_16` | mechanics-backed / 2024-supported | — | S-049/S-050/S-084/S-085/S-103/S-104 (fixture-only Origin/ASI feat acquisition; feat content, prerequisites, ability benefits, Fighting Style grants, level-19 feat path open) | Unreviewed |
| class | 5 | Sorcerous Restoration | p.66 | `sorcerer_sorcerous_restoration` | mechanics-backed / 2024-supported | — | unassigned | Unreviewed |
| class | 7 | Sorcery Incarnate | p.66 | `sorcerer_sorcery_incarnate` | mechanics-backed / 2024-partial | — | unassigned | Unreviewed |
| class | 19 | Epic Boon | p.66 | `sorcerer_epic_boon` | mechanics-backed / 2024-partial | — | S-049/S-050/S-084/S-085/S-103/S-104 (fixture-only Origin/ASI feat acquisition; feat content, prerequisites, ability benefits, Fighting Style grants, level-19 feat path open) | Unreviewed |
| class | 20 | Arcane Apotheosis | p.66 | `sorcerer_arcane_apotheosis` | mechanics-backed / 2024-partial | — | unassigned | Unreviewed |
| repo-only class | 2 | Sorcery Points | Named inside an SRD feature body (repo split); page not resolved per clause | `sorcerer_sorcery_points` | mechanics-backed / 2024-supported | — | unassigned | Unreviewed |
| repo-only class | 6 | Sorcerer Subclass Feature | Placeholder for subclass level; SRD subclass body not in repo | `sorcerer_subclass_feature_6` | quarantined / reference-only | — | unassigned | Unreviewed |
| repo-only class | 10 | Metamagic Improvement | No SRD 5.2.1 heading found — source gap | `sorcerer_metamagic_improvement_10` | mechanics-backed / 2024-supported | — | unassigned | Unreviewed |
| repo-only class | 14 | Sorcerer Subclass Feature | Placeholder for subclass level; SRD subclass body not in repo | `sorcerer_subclass_feature_14` | quarantined / reference-only | — | unassigned | Unreviewed |
| repo-only class | 17 | Metamagic Improvement | No SRD 5.2.1 heading found — source gap | `sorcerer_metamagic_improvement_17` | mechanics-backed / 2024-supported | — | unassigned | Unreviewed |
| repo-only class | 18 | Sorcerer Subclass Feature | Placeholder for subclass level; SRD subclass body not in repo | `sorcerer_subclass_feature_18` | quarantined / reference-only | — | unassigned | Unreviewed |
| subclass | 3 | Draconic Resilience | p.69 | — | absent | — | unassigned | Unreviewed (absent) |
| subclass | 3 | Draconic Spells | p.70 | — | absent | — | unassigned | Unreviewed (absent) |
| subclass | 6 | Elemental Affinity | p.70 | — | absent | — | unassigned | Unreviewed (absent) |
| subclass | 14 | Dragon Wings | p.70 | — | absent | — | unassigned | Unreviewed (absent) |
| subclass | 18 | Dragon Companion | p.70 | — | absent | — | unassigned | Unreviewed (absent) |
