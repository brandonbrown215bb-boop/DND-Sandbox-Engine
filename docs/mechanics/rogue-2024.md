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
