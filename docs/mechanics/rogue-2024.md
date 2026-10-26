# Rogue (2024 SRD 5.2.1)

> Partial behavior/migration snapshot. Dated evidence and catalog counts
> below apply to their original audit, not automatic acceptance of the
> current tree. [Roadmap](../../roadmap.md) selects work;
> [ADR-0018](../decisions/0018-shared-data-driven-rules-runtime.md) governs
> new rule execution. Existing named helpers are transitional.

The class record in `data/core/classes/rogue.json` now lists the full 2024 base
progression through level 20. No Rogue subclass records currently ship.

| Level | 2024 feature | Current behavior |
|---:|---|---|
| 1 | Expertise, Sneak Attack, Thieves' Cant, Weapon Mastery | Two shared Expertise choices, level-scaled Sneak Attack, and two saved Weapon Masteries are available. Sneak Attack requires a Finesse or Ranged weapon and either net Advantage or a conscious adjacent ally without net Disadvantage. It is available once on each creature's turn, including Light attacks and Opportunity Attacks. Languages and Thieves' Tools proficiency are not represented. |
| 2 | Cunning Action | Shared Bonus Action path for Dash, Disengage, or Hide. |
| 3 | Rogue Subclass, Steady Aim | Steady Aim spends a Bonus Action, requires no movement earlier that turn, reduces remaining Speed to 0, and grants Advantage on the next weapon attack. Subclass records are unavailable. |
| 4 | Ability Score Improvement | Shared ASI choice. |
| 5 | Cunning Strike, Uncanny Dodge | Uncanny Dodge uses the common Reaction damage-halving path. On a Sneak Attack hit, Poison (requires a Poisoner's Kit), Trip (Large or smaller), and Withdraw can each trade one Sneak Attack die; Poison/Trip use the Rogue's Dexterity-based save DC. Poisoned targets repeat a Constitution save at the end of their turns. Withdraw offers immediate movement up to half Speed without Opportunity Attacks, including when Sneak Attack occurs off-turn. |
| 6 | Expertise | Two more saved shared Expertise choices. |
| 7 | Evasion, Reliable Talent | Shared Evasion applies to Dexterity saves that normally deal half damage on success: zero damage on success, half on failure, unavailable while Incapacitated. Reliable Talent floors proficient skill-check d20 rolls at 10. |
| 8 | Ability Score Improvement | Shared ASI choice. |
| 9 | Subclass feature | Subclass record unavailable. |
| 10 | Ability Score Improvement | Shared ASI choice. |
| 11 | Improved Cunning Strike | The picker permits two distinct affordable Cunning Strike effects and subtracts each option's Sneak Attack die cost before rolling the remaining Sneak Attack damage. |
| 12 | Ability Score Improvement | Shared ASI choice. |
| 13 | Subclass feature | Subclass record unavailable. |
| 14 | Devious Strikes | Adds Daze (2d6, CON save; target chooses only movement or an action on its next turn), Knock Out (6d6, CON save; Unconscious for up to 1 minute with an end-of-turn repeat save, ending on damage), and Obscure (3d6, DEX save; Blinded through the end of its next turn). The picker still permits at most two distinct effects. |
| 15 | Slippery Mind | Shared saving-throw proficiency operation grants Wisdom and Charisma proficiency. |
| 16 | Ability Score Improvement | Shared ASI choice. |
| 17 | Subclass feature | Subclass record unavailable. |
| 18 | Elusive | Enemy attack resolution cancels Advantage against the Rogue unless the Rogue is Incapacitated. |
| 19 | Epic Boon | Shared Epic Boon choice UI; outcomes and restrictions are limited to the common supported options. |
| 20 | Stroke of Luck | Once per Short Rest, the Rogue can turn a failed D20 Test into a d20 result of 20. The game offers it for event skill checks, weapon/spell attacks, spell saving throws, concentration saves, and the Rogue's death saves. It spends a use only when accepted on a failed test. |

Rogue remains partial overall. Cunning Strike supports Poison, Trip, Withdraw,
Daze, Knock Out, and Obscure; Knock Out end-of-turn saves and damage expiry are
handled for combat monsters. Stroke of Luck routes saving-throw failures
through an owner decision as well as event checks and attacks. The Godot logic
suite verifies the spell-save and death-save outcomes; owner-facing prompt
integration and the concentration-save prompt still need an in-engine scenario.
Thieves' Cant/tool
tracking and subclass records remain unavailable. Weapon proficiency data is
also broader than the 2024 Rogue's exact weapon list.
Rules reference: [2024 Basic Rules, Rogue](https://www.dndbeyond.com/sources/dnd/br-2024/character-classes).

<a id="srd-feature-inventory"></a>

## SRD 5.2.1 feature inventory — 2026-10-26

Static source/inventory pass, not a rules audit or gameplay proof. SRD headings were read from `SRD_CC_v5.2.1.pdf` (pages are PDF page numbers) and matched by name/level to `data/core/classes/rogue.json`. Repo status is the [feature matrix](../feature_matrix.md) exposure label / record `rules_status`. Registry slice is shown only where the slice registry names this feature or its generic consumer; `unassigned` means no documented owning slice. V-IDs are the [checklist](../reviews/dnd-code-vocabulary-gap-checklist.md) rows citing this feature as an example; they are open requirements, not owning slices. **Reviewed** means an SRD clause review recorded in the [slice registry](../planning/vocabulary-slices.md); every other row is unreviewed, whatever its `rules_status` says. Rows absent from repo data are not filled from memory.

SRD subclass: **Thief** — absent from repo data.

| Kind | Lvl | SRD feature / repo record | SRD | Repo ID | Repo status | V-IDs | Registry slice (documented limit) | Review |
|---|---:|---|---|---|---|---|---|---|
| class | 1 | Expertise | p.61 | `rogue_expertise` | mechanics-backed / 2024-supported | — | unassigned | Unreviewed |
| class | 1 | Sneak Attack | p.61 | `rogue_sneak_attack` | mechanics-backed / 2024-partial | — | unassigned | Unreviewed |
| class | 1 | Thieves’ Cant | p.62 | `rogue_thieves_cant` | quarantined / reference-only | — | unassigned | Unreviewed |
| class | 1 | Weapon Mastery | p.62 | `rogue_weapon_mastery` | mechanics-backed / 2024-supported | — | unassigned | Unreviewed |
| class | 2 | Cunning Action | p.62 | `rogue_cunning_action` | mechanics-backed / 2024-supported | — | unassigned | Unreviewed |
| class | 3 | Rogue Subclass | p.62 | `rogue_subclass` | quarantined / reference-only | — | unassigned | Unreviewed |
| class | 3 | Steady Aim | p.62 | `rogue_steady_aim` | mechanics-backed / 2024-supported | — | unassigned | Unreviewed |
| class | 4 | Ability Score Improvement | p.63 | `rogue_ability_improvement_4`, `rogue_ability_improvement_8`, `rogue_ability_improvement_10`, `rogue_ability_improvement_12`, `rogue_ability_improvement_16` | mechanics-backed / 2024-supported | — | S-049/S-050/S-084/S-085/S-103/S-104 (fixture-only Origin/ASI feat acquisition; feat content, prerequisites, ability benefits, Fighting Style grants, level-19 feat path open) | Unreviewed |
| class | 5 | Cunning Strike | p.63 | `rogue_cunning_strike` | mechanics-backed / 2024-partial | V-023 | unassigned | Unreviewed |
| class | 5 | Uncanny Dodge | p.63 | `rogue_uncanny_dodge` | mechanics-backed / 2024-supported | — | unassigned | Unreviewed |
| class | 7 | Reliable Talent | p.63 | `rogue_reliable_talent` | mechanics-backed / 2024-supported | V-008 | unassigned | Unreviewed |
| class | 7 | Evasion | p.63 | `rogue_evasion` | mechanics-backed / 2024-partial | — | unassigned | Unreviewed |
| class | 11 | Improved Cunning Strike | p.63 | `rogue_improved_cunning_strike` | mechanics-backed / 2024-supported | — | unassigned | Unreviewed |
| class | 14 | Devious Strikes | p.63 | `rogue_devious_strikes` | mechanics-backed / 2024-supported | — | unassigned | Unreviewed |
| class | 15 | Slippery Mind | p.63 | `rogue_slippery_mind` | mechanics-backed / 2024-supported | — | unassigned | Unreviewed |
| class | 18 | Elusive | p.63 | `rogue_elusive` | mechanics-backed / 2024-supported | V-012 | unassigned | Unreviewed |
| class | 19 | Epic Boon | p.63 | `rogue_epic_boon` | mechanics-backed / 2024-partial | — | S-049/S-050/S-084/S-085/S-103/S-104 (fixture-only Origin/ASI feat acquisition; feat content, prerequisites, ability benefits, Fighting Style grants, level-19 feat path open) | Unreviewed |
| class | 20 | Stroke of Luck | p.63 | `rogue_stroke_of_luck` | mechanics-backed / 2024-partial | V-090 | unassigned | Unreviewed |
| repo-only class | 6 | Expertise | Named inside an SRD feature body (repo split); page not resolved per clause | `rogue_expertise_6` | mechanics-backed / 2024-supported | — | unassigned | Unreviewed |
| repo-only class | 9 | Rogue Subclass Feature | Placeholder for subclass level; SRD subclass body not in repo | `rogue_subclass_feature_9` | quarantined / reference-only | — | unassigned | Unreviewed |
| repo-only class | 13 | Rogue Subclass Feature | Placeholder for subclass level; SRD subclass body not in repo | `rogue_subclass_feature_13` | quarantined / reference-only | — | unassigned | Unreviewed |
| repo-only class | 17 | Rogue Subclass Feature | Placeholder for subclass level; SRD subclass body not in repo | `rogue_subclass_feature_17` | quarantined / reference-only | — | unassigned | Unreviewed |
| subclass | 3 | Fast Hands | p.64 | — | absent | — | unassigned | Unreviewed (absent) |
| subclass | 3 | Second-Story Work | p.64 | — | absent | — | unassigned | Unreviewed (absent) |
| subclass | 9 | Supreme Sneak | p.64 | — | absent | — | unassigned | Unreviewed (absent) |
| subclass | 13 | Use Magic Device | p.64 | — | absent | — | unassigned | Unreviewed (absent) |
| subclass | 17 | Thief’s Reflexes | p.64 | — | absent | — | unassigned | Unreviewed (absent) |
