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
