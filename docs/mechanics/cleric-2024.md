# Cleric base-class wiring and remaining limits

> Partial behavior/migration snapshot. Dated evidence and catalog counts
> below apply to their original audit, not automatic acceptance of the
> current tree. [Roadmap](../../roadmap.md) selects work;
> [ADR-0018](../decisions/0018-shared-data-driven-rules-runtime.md) governs
> new rule execution. Existing named helpers are transitional.

Rules authority: [SRD 5.2.1, pages 36–40](https://media.dndbeyond.com/compendium-images/srd/5.2/SRD_CC_v5.2.1.pdf).
This audit covers base-class behavior through level 20. Subclasses, the full
spell catalog and full feats/boons are separate scope. The remaining repairs
in this audit are implemented; use the retained checks below and current source
when assessing those dated results.

## Feature status

| Level | Feature | Production behavior |
|---:|---|---|
| 1 | Core traits and creation | Choose two of History, Insight, Medicine, Persuasion and Religion; choose Divine Order; choose Chain Shirt, Shield, Mace, Holy Symbol, Priest’s Pack and 7 GP, or 110 GP. Review, Back, Random and next-seat reset retain the right choices. |
| 1 | Spellcasting | Wisdom casting, supported cantrip/prepared choices and level 1–20 capacity/slot tables. Initial recommendations can be replaced during first training. Long Rest reopens the whole prepared list; gaining a level permits one cantrip replacement. Permissions survive reload. |
| 1 | Divine Order | Creation or sheet chooses Protector’s Martial weapons/Heavy Armor or Thaumaturge’s extra cantrip and Wisdom bonus (minimum +1) on Intelligence Arcana/Religion checks. |
| 2 | Channel Divinity | Two uses; three at 6, four at 18. Short Rest restores one; Long Rest restores all. The action menu and execution require a carried Holy Symbol, a conscious caster, remaining uses and a Magic action. |
| 2 | Divine Spark | Another visible creature within 30 feet; heal or Constitution-save Radiant/Necrotic damage. A downed ally can be healed; dead/disintegrated creatures cannot. Dice scale at 7/13/18. Invalid targets and cancelled choices spend nothing. |
| 2 | Turn Undead | Select Undead within 30 feet, then confirm. Failed Wisdom saves grant source-owned Frightened/Incapacitated for the combat condition clock. Fleeing follows the caster’s current position. Damage, expiry, caster death or incapacitation release the owned grants; another caster and ordinary conditions remain independent. |
| 3 | Subclass | Separate registry/choice boundary; no Cleric subclass is certified by this pass. |
| 4/8/12/16 | Ability improvements | Shared saved improvement entitlements; full general feat alternatives remain outside this pass. |
| 5 | Sear Undead | Optional prompt. One Wisdom-modifier d8 roll (minimum one die) damages selected failed-save Undead without ending turning. |
| 7 | Blessed Strikes: Divine Strike | Optional after a weapon hit on the Cleric’s own turn; choose Radiant/Necrotic. Declining keeps it available for a later hit, including a Light follow-up. One use per own turn; off-turn attacks cannot use it. Critical hits double rider dice. |
| 7 | Blessed Strikes: Potent Spellcasting | Adds Wisdom to Cleric cantrip damage through the shared spell resolver. |
| 10 | Divine Intervention | Actual feature/catalog picker casts an available Cleric spell of level 5 or lower, excluding Reactions, as one Magic action. No preparation, slot or Material expenditure is required. Target/choice rejection occurs before feature spending. Rest restores one use. |
| 14 | Improved Blessed Strikes | Divine Strike becomes 2d8. After a Cleric cantrip actually deals damage, optional vitality can grant twice Wisdom temporary HP to self or another creature within 60 feet. Nondamaging spells, misses/saves with zero damage and immunity grant none; larger temporary HP pools are preserved. |
| 19 | Epic Boon | Shared curated saved boon choices; full feat/boon catalog is separate scope. |
| 20 | Greater Divine Intervention | Real Wish menu duplicates available non-Reaction spells through level 8 across class lists, with no slot/Material cost. A rolled 2d4 Long Rest cooldown survives disk reload and is validated before any manager mutation. |

## Persistence and engine boundaries

Creation uses the existing saved `creation_choices` and `feature_choices`.
Reload restores exact inventory/cash without replaying grants. Earlier saves
without these optional creation fields retain their skills, items and gold;
they acquire no retroactive gear. Cleric training permissions are optional
Boolean fields in schema 2. Earlier saves can confirm their existing/default
spell selection once, then use the normal rest/level permissions. Cooldown
records reject fractions, Boolean/string values, out-of-range counts and
availability contradicting an active cooldown. Player and party DTOs both
pass preflight before live state changes. Legacy save namespaces are untouched.

Turning ownership is combat-local monster state, with one condition source
per Cleric. Ordinary damage clears turning, while Sear explicitly preserves it.
The existing condition clock ticks at the affected creature’s turn boundary;
this is a ten-turn approximation of one minute rather than a continuous clock.
Overlapping turning retains independent grants; the most recent surviving
caster supplies the fleeing origin. Terrain occlusion and full visibility
remain absent. Divine Spark uses Blindness/Invisible handling and existing
Blindsight perception. Pointing at/presenting a carried Holy Symbol is modeled;
free hands, worn focus variants and general spell component enforcement are not.

The Priest’s Pack stays a carried bundle. Its contents are not individual
usable supplies, so its listed Holy Water cannot independently fund another
spell. Inventory gear can be bought through the existing shop. Creature vitality
uses the shared temporary-HP damage boundary for Characters and combat monsters.

The executable spell catalog remains curated. Unavailable entries stay disabled;
missing options remain visibly pending on the sheet. Thaumaturgy, Mending and
Spare the Dying are still unavailable, so high-level Clerics cannot fill every
cantrip capacity yet. No new spells were needed to wire these class actions.
Wish’s other outcomes, Reaction duplication, custom reality changes and stress
rules are not implemented. Full feat/boon alternatives and Life Domain remain
separate work. These accepted base-action paths do not claim whole-class SRD
certification or full integration/manual acceptance.

## Remaining scope

Keep the creation/preparation, turning, optional riders and Intervention checks
when migrating these rules. Unimplemented subclass/feat/spell clauses remain
partial as listed above. The old instruction to move directly into a Druid
native-helper audit is retired; the shared-runtime roadmap chooses priority.

<a id="srd-feature-inventory"></a>

## SRD 5.2.1 feature inventory — 2026-10-26

Static source/inventory pass, not a rules audit or gameplay proof. SRD headings were read from `SRD_CC_v5.2.1.pdf` (pages are PDF page numbers) and matched by name/level to `data/core/classes/cleric.json`. Repo status is the [feature matrix](../feature_matrix.md) exposure label / record `rules_status`. Registry slice is shown only where the slice registry names this feature or its generic consumer; `unassigned` means no documented owning slice. V-IDs are the [checklist](../reviews/dnd-code-vocabulary-gap-checklist.md) rows citing this feature as an example; they are open requirements, not owning slices. **Reviewed** means an SRD clause review recorded in the [slice registry](../planning/vocabulary-slices.md); every other row is unreviewed, whatever its `rules_status` says. Rows absent from repo data are not filled from memory.

SRD subclass: **Life Domain** — absent from repo data.

| Kind | Lvl | SRD feature / repo record | SRD | Repo ID | Repo status | V-IDs | Registry slice (documented limit) | Review |
|---|---:|---|---|---|---|---|---|---|
| class | 1 | Spellcasting | p.36 | `cleric_spellcasting` | mechanics-backed / unset | — | unassigned | Unreviewed |
| class | 1 | Divine Order | p.37 | `cleric_divine_order` | mechanics-backed / unset | — | unassigned | Unreviewed |
| class | 2 | Channel Divinity | p.37 | `cleric_channel_divinity` | mechanics-backed / unset | — | unassigned | Unreviewed |
| class | 3 | Cleric Subclass | p.37 | `cleric_cleric_subclass` | quarantined / unset | — | unassigned | Unreviewed |
| class | 4 | Ability Score Improvement | p.37 | `cleric_ability_score_improvement`, `cleric_ability_improvement_8`, `cleric_ability_improvement_12`, `cleric_ability_improvement_16` | mechanics-backed / 2024-supported | — | S-049/S-050/S-084/S-085/S-103/S-104 (fixture-only Origin/ASI feat acquisition; feat content, prerequisites, ability benefits, Fighting Style grants, level-19 feat path open) | Unreviewed |
| class | 5 | Sear Undead | p.37 | `cleric_sear_undead` | mechanics-backed / unset | — | unassigned | Unreviewed |
| class | 7 | Blessed Strikes | p.38 | `cleric_blessed_strikes` | mechanics-backed / unset | — | unassigned | Unreviewed |
| class | 10 | Divine Intervention | p.38 | `cleric_divine_intervention` | mechanics-backed / unset | — | unassigned | Unreviewed |
| class | 14 | Improved Blessed Strikes | p.38 | `cleric_improved_blessed_strikes` | mechanics-backed / unset | — | unassigned | Unreviewed |
| class | 19 | Epic Boon | p.38 | `cleric_epic_boon` | mechanics-backed / unset | — | S-049/S-050/S-084/S-085/S-103/S-104 (fixture-only Origin/ASI feat acquisition; feat content, prerequisites, ability benefits, Fighting Style grants, level-19 feat path open) | Unreviewed |
| class | 20 | Greater Divine Intervention | p.38 | `cleric_greater_divine_intervention` | mechanics-backed / unset | — | unassigned | Unreviewed |
| repo-only class | 2 | Divine Spark | Named inside an SRD feature body (repo split); page not resolved per clause | `cleric_divine_spark` | mechanics-backed / unset | — | unassigned | Unreviewed |
| repo-only class | 2 | Turn Undead | Named inside an SRD feature body (repo split); page not resolved per clause | `cleric_turn_undead` | mechanics-backed / unset | V-049 | unassigned | Unreviewed |
| subclass | 3 | Life Domain Spells | p.40 | — | absent | — | unassigned | Unreviewed (absent) |
| subclass | 3 | Disciple of Life | p.40 | — | absent | — | unassigned | Unreviewed (absent) |
| subclass | 3 | Preserve Life | p.40 | — | absent | V-036 | unassigned | Unreviewed (absent) |
| subclass | 6 | Blessed Healer | p.40 | — | absent | — | unassigned | Unreviewed (absent) |
| subclass | 17 | Supreme Healing | p.40 | — | absent | — | unassigned | Unreviewed (absent) |
