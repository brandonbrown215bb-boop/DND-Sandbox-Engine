# Ranger (2024 SRD 5.2.1)

> Partial behavior/migration snapshot. Dated evidence and catalog counts
> below apply to their original audit, not automatic acceptance of the
> current tree. [Roadmap](../../roadmap.md) selects work;
> [ADR-0018](../decisions/0018-shared-data-driven-rules-runtime.md) governs
> new rule execution. Existing named helpers are transitional.

The base-class progression is read from `data/core/classes/ranger.json`. Spell
records are intentionally limited to the Ranger's three currently curated
choices: Hunter's Mark, Cure Wounds, and Misty Step. This is not a complete
Ranger spell list. Subclass features live in separate records and are outside
this base-class pass.

| Level | 2024 feature | Current behavior |
|---:|---|---|
| 1 | Spellcasting, Favored Enemy, Weapon Mastery | Prepared Wisdom half-caster slots and capacity; Hunter's Mark always prepared with two free Long Rest casts; shared saved weapon mastery. Spell selection is a three-spell curated subset. |
| 2 | Deft Explorer, Fighting Style | Shared skill Expertise choice; four available fighting styles through the common saved-choice UI. Language choices and other 2024 styles are not modeled. |
| 3 | Ranger Subclass | Selection is at level 3; no Ranger subclass records currently ship. |
| 4 | Ability Score Improvement | Shared ASI choice. |
| 5 | Extra Attack; Favored Enemy improvement | Shared Extra Attack; Hunter's Mark free-cast capacity rises to three. |
| 6 | Roving | Shared +10-foot speed effect without Heavy armor. Climb and swim speeds are not modeled. |
| 7 | Subclass feature | Subclass progression is not currently available for Ranger. |
| 8 | Ability Score Improvement | Shared ASI choice. |
| 9 | Expertise; Favored Enemy improvement | Two additional shared Expertise choices; Hunter's Mark free-cast capacity rises to four. |
| 10 | Tireless | Shared Magic-action temporary HP (1d8 + Wisdom modifier), with Wisdom-based Long Rest uses. Reducing Exhaustion on a Short Rest is not modeled. |
| 11 | Subclass feature | Subclass progression is not currently available for Ranger. |
| 12 | Ability Score Improvement | Shared ASI choice. |
| 13 | Relentless Hunter; Favored Enemy improvement | Shared spell-specific concentration protection preserves Hunter's Mark after damage; free-cast capacity rises to five. |
| 14 | Nature's Veil | Bonus Action grants Invisible until the end of the Ranger's next turn; uses equal Wisdom modifier (minimum 1) and refresh on Long Rest. The two-turn condition timer expires at the end of the Ranger's next turn. Attacks against an unperceived invisible creature have Disadvantage; attacks from an invisible attacker have Advantage. Known hexes remain targetable for attacks in this tactical game, while spells tagged as requiring sight reject unseen targets. The focused combat scenario confirms attack Advantage/Disadvantage and duration through the next turn. |
| 15 | Subclass feature | Subclass progression is not currently available for Ranger. |
| 16 | Ability Score Improvement | Shared ASI choice. |
| 17 | Precise Hunter; Favored Enemy improvement | Shared condition-based attack advantage applies to Hunter's Mark's target; free-cast capacity rises to six. |
| 18 | Feral Senses | Shared Blindsight perception checks detect invisible creatures within 30 feet, remove invisibility attack modifiers within that range, and satisfy spell target sight requirements in range. The focused combat scenario confirms sight-required targeting at 30 feet and rejection at 35 feet. Its test-only Ranger spell choice uses Charm Person to exercise the shared sight boundary; Charm Person is not added to the Ranger spell list. Total Cover and general vision are not modeled. |
| 19 | Epic Boon | Shared Epic Boon choice UI; choice restrictions and outcomes remain limited to the common supported options. |
| 20 | Foe Slayer | Shared spell-damage die override raises Hunter's Mark from 1d6 to 1d10. |

The class remains partial overall because its spell list is curated, several
language and Fighting Style options are absent, and subclass records do not
ship. Blindsight currently models perception against invisibility in combat;
the game has no line-of-sight or hidden-location system. Feature status in the
class record distinguishes supported behavior from those gaps. Rules reference:
[2024 Basic Rules, Ranger](https://www.dndbeyond.com/sources/dnd/br-2024/character-classes).

<a id="srd-feature-inventory"></a>

## SRD 5.2.1 feature inventory — 2026-10-26

Static source/inventory pass, not a rules audit or gameplay proof. SRD headings were read from `SRD_CC_v5.2.1.pdf` (pages are PDF page numbers) and matched by name/level to `data/core/classes/ranger.json`. Repo status is the [feature matrix](../feature_matrix.md) exposure label / record `rules_status`. Registry slice is shown only where the slice registry names this feature or its generic consumer; `unassigned` means no documented owning slice. V-IDs are the [checklist](../reviews/dnd-code-vocabulary-gap-checklist.md) rows citing this feature as an example; they are open requirements, not owning slices. **Reviewed** means an SRD clause review recorded in the [slice registry](../planning/vocabulary-slices.md); every other row is unreviewed, whatever its `rules_status` says. Rows absent from repo data are not filled from memory.

SRD subclass: **Hunter** — absent from repo data.

| Kind | Lvl | SRD feature / repo record | SRD | Repo ID | Repo status | V-IDs | Registry slice (documented limit) | Review |
|---|---:|---|---|---|---|---|---|---|
| class | 1 | Spellcasting | p.57 | `ranger_spellcasting` | mechanics-backed / 2024-partial | — | unassigned | Unreviewed |
| class | 1 | Favored Enemy | p.58 | `ranger_favored_enemy` | mechanics-backed / 2024-supported | — | unassigned | Unreviewed |
| class | 1 | Weapon Mastery | p.58 | `ranger_weapon_mastery` | mechanics-backed / 2024-supported | — | unassigned | Unreviewed |
| class | 2 | Deft Explorer | p.59 | `ranger_deft_explorer` | mechanics-backed / 2024-partial | — | unassigned | Unreviewed |
| class | 2 | Fighting Style | p.59 | `ranger_fighting_style` | mechanics-backed / 2024-partial | — | S-049/S-050/S-084/S-085/S-103/S-104 (fixture-only Origin/ASI feat acquisition; feat content, prerequisites, ability benefits, Fighting Style grants, level-19 feat path open) | Unreviewed |
| class | 3 | Ranger Subclass | p.59 | `ranger_subclass` | quarantined / reference-only | — | unassigned | Unreviewed |
| class | 4 | Ability Score Improvement | p.59 | `ranger_ability_improvement_4`, `ranger_ability_improvement_8`, `ranger_ability_improvement_12`, `ranger_ability_improvement_16` | mechanics-backed / 2024-supported | — | S-049/S-050/S-084/S-085/S-103/S-104 (fixture-only Origin/ASI feat acquisition; feat content, prerequisites, ability benefits, Fighting Style grants, level-19 feat path open) | Unreviewed |
| class | 5 | Extra Attack | p.59 | `ranger_extra_attack` | mechanics-backed / 2024-supported | — | S-084 (PARTIAL: exclusive Extra Attack count consumer accepted; source-backed class conversion open) | Unreviewed |
| class | 6 | Roving | p.59 | `ranger_roving` | mechanics-backed / 2024-partial | — | unassigned | Unreviewed |
| class | 9 | Expertise | p.59 | `ranger_expertise` | mechanics-backed / 2024-supported | — | unassigned | Unreviewed |
| class | 10 | Tireless | p.59 | `ranger_tireless` | mechanics-backed / 2024-partial | — | unassigned | Unreviewed |
| class | 13 | Relentless Hunter | p.59 | `ranger_relentless_hunter` | mechanics-backed / 2024-supported | — | unassigned | Unreviewed |
| class | 14 | Nature’s Veil | p.59 | `ranger_natures_veil` | mechanics-backed / 2024-supported | — | unassigned | Unreviewed |
| class | 17 | Precise Hunter | p.59 | `ranger_precise_hunter` | mechanics-backed / 2024-supported | — | unassigned | Unreviewed |
| class | 18 | Feral Senses | p.59 | `ranger_feral_senses` | mechanics-backed / 2024-supported | — | unassigned | Unreviewed |
| class | 19 | Epic Boon | p.59 | `ranger_epic_boon` | mechanics-backed / 2024-partial | — | S-049/S-050/S-084/S-085/S-103/S-104 (fixture-only Origin/ASI feat acquisition; feat content, prerequisites, ability benefits, Fighting Style grants, level-19 feat path open) | Unreviewed |
| class | 20 | Foe Slayer | p.59 | `ranger_foe_slayer` | mechanics-backed / 2024-supported | V-055 | unassigned | Unreviewed |
| repo-only class | 7 | Ranger Subclass Feature | Placeholder for subclass level; SRD subclass body not in repo | `ranger_subclass_feature_7` | quarantined / reference-only | — | unassigned | Unreviewed |
| repo-only class | 11 | Ranger Subclass Feature | Placeholder for subclass level; SRD subclass body not in repo | `ranger_subclass_feature_11` | quarantined / reference-only | — | unassigned | Unreviewed |
| repo-only class | 15 | Ranger Subclass Feature | Placeholder for subclass level; SRD subclass body not in repo | `ranger_subclass_feature_15` | quarantined / reference-only | — | unassigned | Unreviewed |
| subclass | 3 | Hunter’s Lore | p.61 | — | absent | — | unassigned | Unreviewed (absent) |
| subclass | 3 | Hunter’s Prey | p.61 | — | absent | — | unassigned | Unreviewed (absent) |
| subclass | 7 | Defensive Tactics | p.61 | — | absent | — | unassigned | Unreviewed (absent) |
| subclass | 11 | Superior Hunter’s Prey | p.61 | — | absent | — | unassigned | Unreviewed (absent) |
| subclass | 15 | Superior Hunter’s Defense | p.61 | — | absent | — | unassigned | Unreviewed (absent) |
