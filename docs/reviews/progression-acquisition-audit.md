# Progression/Acquisition audit: creation and advancement (SRD 5.2.1)

Planning-only audit. It covers **acquisition and advancement**: species,
backgrounds, feats, subclass choice, multiclass requirements, proficiency
grants, and spell access/replacement. It asks how each is chosen, gated, granted,
replaced and saved, at creation and at level-up. What features and feats *do*
belongs to the Feature Auditor (PR #61). Where a clause has both parts, this
audit logs the grant or choice and that audit logs the effect.

No runtime code, data, availability or `enabled` value changed. The audit adds
only docs and a non-shipping export script under `tools/progression_audit/`.

## Provenance

| Item | Value |
|---|---|
| Base commit | `ede0a3cdfa66f21b0b3415f498c2e186e56a0db4` (origin/main, merge of PR #60) |
| Registry hash | sha256 of `DataLoader.get_registry_hash()` = `70a83cc74e530743e90f8fadc992bd0651f56b51cb84b06cd73fcaf22187845e` |
| Feats hash | `get_registry_hash()` omits feats, so they are hashed separately: `44136fa355b3678a1146ad16f7e8649e94fb4fc21fe77e8310c060f61caaff8a` (empty registry) |
| Layers / packs | `core_imported`, `core_curated`, `mods` / `core`, `crown`; 0 load errors; 25 rejected effectless-feature warnings |
| Export | `.artifacts/progression-acquisition/inventory.json` (gitignored, sha256 `d8586a4e…0322`) |
| Engine | Godot 4.7.2-stable, headless |
| Source | SRD 5.2.1 (CC-BY-4.0). Page numbers are printed pages, which equal PDF pages. |

Reproduce:

```sh
godot --headless --path . --import
godot --headless --path . res://tools/progression_audit/progression_inventory_export.tscn
```

All counts come from that production DataLoader run. The audit reuses no
historical count.

## Inventory (production registries vs SRD)

| Category | Production | SRD 5.2.1 | Reconciliation |
|---|---|---|---|
| Classes | 14 loaded; 12 offered at creation (`get_all_classes` hides artificer, mystic) | 12 | 12/12 present. Rules status: fighter `2024-supported`; monk and paladin `2024-partial`; 9 `transition-pending` |
| Subclasses | 5 | 12 (one per class) | 3 SRD: Champion, Warrior of the Open Hand, Fiend Patron. 2 non-SRD: Abjurer, Diviner. 9 SRD subclasses absent; 8 classes have none |
| Species | 9 | 9 (p.20) | 7 shared names. Goliath and Orc missing; Half-Elf and Half-Orc are non-SRD legacy records |
| Backgrounds | 0 (no content type) | 4 (Acolyte, Criminal, Sage, Soldier; p.83) | Entire category absent |
| Feats | 0 in production; fixtures only (`data/fixtures/batch_049…065`) | 17: 4 Origin, 2 General, 4 Fighting Style, 7 Epic Boon (pp.87–88) | Production 0/17 |
| Spells | 362 | n/a here | Class access via `CURATED_SPELL_ACCESS`; content correctness belongs to spell audits |

Data-shape findings (content corrections, not vocabulary):

- `subclass_level` is missing on barbarian, bard and cleric. Code defaults to 3, which matches the SRD.
- No production class carries `permanent_progression`, multiclass prerequisites, or multiclass proficiency subsets. Multiclassing is therefore unreachable in production even though the S-047/S-048 path is Verified.
- Class proficiency rows checked against each class's Core Traits table:
  - **Wizard skill list is wrong.** Data has Athletics, Acrobatics, Insight, Perception, History, Arcana, Stealth. SRD p.77 has Arcana, History, Insight, Investigation, Medicine, Nature, Religion.
  - Rogue skill list includes Performance, which is not on p.61.
  - Rogue weapons are `simple, martial`. SRD p.61 limits martial weapons to those with Finesse or Light.
  - Missing tool proficiencies: Druid Herbalism Kit (p.41), Rogue Thieves' Tools (p.61), Monk choice of one Artisan's Tool or Musical Instrument (p.49).
  - Cleric armor uses the token `shield`; other classes use `shields`.
  - Saving throws and skill pick counts match for all 12 classes.
- Species records use the 2014 shape:
  - `ability_bonuses` on elf, half-elf, half-orc and human. In SRD 5.2.1, ability increases come from the background (p.83).
  - Elf has a fixed Perception proficiency. Keen Senses is a choice of Insight, Perception or Survival (p.85).
  - Tiefling size is fixed `small`. The SRD lets the player choose Small or Medium (p.86); Human has the same choice (p.85).
  - Lineage, ancestry and legacy traits exist only as trait ids, with no choice data.

## Runtime acquisition paths (read-only survey)

- **Creation** (`character_creation.gd`) runs: species, class, point-buy, class creation choices (skills, bard instruments, equipment), Origin feat via `FeatRules.options(probe, "origin")`, equipment, summary. There is no background, language, species-choice or size step. Because the production feats registry is empty, the Origin feat picker never appears.
- **Level-up**: native `Character.level_up()` handles single-class levels and returns early when `class_levels` is set. It raises per-class pending choices:
  - wizard spellbook +2
  - sorcerer metamagic
  - warlock invocation and arcanum
  - cleric cantrip replacement
  - fighter style swap
  - `spell_choices_pending`

  It auto-selects a subclass only when exactly one is available.
- **Explicit progression**: `PermanentProgressionRules` (opt-in `permanent_progression`) handles starting vs multiclass grants, level HP and receipts. `available_classes()` checks only `enabled`, `definition_error` and an empty-features rule. **It has no ability-score prerequisite.**
- **Choices**: `ClassProgression.choose_subclass` gates on class and `subclass_level`. Feature options carry level, class and fact prerequisites. `class_training.gd` exposes these choices:
  - subclass
  - Weapon Mastery
  - feature choice and replacement
  - skill and expertise
  - Epic Boon ability
  - wizard spellbook
  - permanent level
- **Feats**: `FeatRules` prerequisites support only `level` and `abilities_any`. Saved feats are revalidated through `saved_error`.

## Decomposition and classification

Status key:
- **Covered**: a Verified slice/VS owns the behavior.
- **Covered-cap**: the capability is Verified, but production data or the creation route doesn't use it yet. This is content work, not new vocabulary.
- **Planned**: an existing non-accepted slice.
- **New**: added in this PR as a Planned row.
- **Judgment**: an owner choice under ADR-0023.

| # | Behavior (SRD cite) | Runtime today | Status |
|---|---|---|---|
| 1 | Choose class at creation; L1 traits: saves, skill pick N from list, weapons, armor, tools (class Core Traits pages) | Creation class step + skill picker | Covered (S-047/VS-68 starting grants); Covered-cap for the tool and skill data defects above |
| 2 | Ability scores: standard array / random / point-buy 27 (p.21) | Point-buy only | Judgment (generation method is a table option; record before adding) |
| 3 | Background: choose 1; +2/+1 or +1/+1/+1 among 3 listed abilities, max 20 (p.83) | Absent | **New S-231** |
| 4 | Background Origin feat grant (p.83) | Origin feat picker exists but isn't background-sourced | **New S-231** (grant); feat effect → Feature Auditor |
| 5 | Background 2 skills + 1 tool, a fixed tool or a category choice (p.83) | Absent | **New S-231** |
| 6 | Background equipment A or 50 GP; class equipment A/B(/C) or GP (p.83, class pages) | Class equipment step only | **New S-231** (background); class package Covered (S-047) |
| 7 | Languages: Common + 2 chosen (p.20) | Species `languages` fixed | **New S-232** |
| 8 | Species: choose 1 of 9; creature type, size, speed (p.20, pp.84–86) | 9 legacy records | Covered-cap (record selection exists; set and shape need content correction) |
| 9 | Species size choice: Human/Tiefling Small or Medium (pp.85–86) | Fixed size | **New S-232** |
| 10 | Species lineage/ancestry choice, including spellcasting ability chosen at selection: Draconic Ancestry, Elven Lineage, Gnomish Lineage, Giant Ancestry, Fiendish Legacy (pp.84–86) | Trait ids only, no choice | **New S-232** (choice route); grants reuse S-045/S-049 |
| 11 | Species character-level grants at 3 and 5 (Elven Lineage, Fiendish Legacy, Dragonborn flight, Goliath Large Form) (pp.84–86) | Not wired to species | Covered-cap (S-048/VS-69 level deltas; S-139/VS-80 fixed-level spell uses) |
| 12 | Species skill choice (Keen Senses) and Human Skillful + Versatile Origin feat (p.85) | Fixed Perception; no Human feat | **New S-232** |
| 13 | Feat category gating: Origin at creation, General at ASI levels, Epic Boon at 19 (pp.87–88) | `FeatRules.options(c, category)` with fixtures | Covered (VS-59/VS-60 bounded rows; S-049/S-050) |
| 14 | Feat prerequisites: level, ability ≥13 any-of (p.87) | Supported | Covered (bounded feat row; V-025) |
| 15 | Feat prerequisites: class (≥1 level), named feature (Fighting Style, Spellcasting) (pp.87–88) | Unsupported | **New S-233** |
| 16 | Repeatable feats, including repeat-with-distinct-parameter (Magic Initiate different list; Skilled) (p.87) | Not represented | **New S-233** |
| 17 | Magic Initiate: choose list and ability at acquisition; replace its level 1 spell on gaining a level (p.87) | Fixture route only | Covered-cap (S-137/VS-78 per-source replacement); S-233 for list distinctness |
| 18 | ASI at class levels 4/8/12/16 (19 → Epic Boon); ability max 20, or 30 for a boon (class tables, p.87) | ASI via feature effect `asi` and `asi_spent`; `pending_epic_boon_choices` | Covered (VS-59/60; V-026) |
| 19 | Subclass at class level 3, player choice (class pages, p.19) | `choose_subclass` gated by `subclass_level`; auto-pick when one option | Covered (S-045/VS-57). Content gap: 9 SRD subclasses |
| 20 | Subclass recorded when starting above level 3 (p.19, p.24) | No higher-level start | Judgment (Crown starts at L1; parked) |
| 21 | Gaining a level: choose class, HP fixed or roll, make offered choices, PB (p.23) | Native single-class; explicit path for allocations | Covered (S-048/VS-69; S-045) |
| 22 | XP thresholds by total level (p.23, p.25) | Milestone | Judgment (milestone advancement is a table option) |
| 23 | Multiclass prerequisite: 13+ in primary ability of the new class **and** every current class (p.24) | Not checked by `available_classes` | **New S-234** |
| 24 | Multiclass proficiency subsets per class (pp.28–77 "As a Multiclass Character") | Grant split exists, no production data | Covered-cap (S-047/VS-68) |
| 25 | Multiclass HP: level-1 maximum only at total level 1; Hit Dice pools per die type (p.25) | `level_hit_points` receipts | Covered (S-048/VS-69) |
| 26 | Multiclass PB and cantrip scaling by total level (p.25) | Total-level based | Covered (S-048) |
| 27 | Multiclass spellcasting: prepared per class; combined slot level (full + half rounded up); Pact separate (p.25) | Opt-in | Covered (S-137/VS-78, S-138/VS-79) |
| 28 | Spell access lists per class (class spell lists) | `CURATED_SPELL_ACCESS` | Covered-cap (content correctness is a spell-audit concern) |
| 29 | Prepared spell change on class level: Bard, Sorcerer, Warlock replace one (pp.32/65/72) | `spell_choices_pending`; S-137 opt-in | Covered (S-137/VS-78) |
| 30 | Prepared spell change on Long Rest: Cleric/Druid any, Wizard any from spellbook, Paladin/Ranger replace one (pp.37/42/78/54/58) | Cleric/wizard free-change flags | Covered (S-137 + S-103/VS-119) |
| 31 | Cantrip replacement: Bard/Cleric/Druid/Sorcerer/Warlock on level; Wizard on Long Rest (pp.32/36/42/64/71/77) | Cleric flag; others via S-137 | Covered (S-137/VS-78) |
| 32 | Wizard spellbook +2 per level (p.77) | `wizard spellbook +2` | Covered (S-045) |
| 33 | Expertise, Fighting Style, Weapon Mastery choices and their replacement cadence (class pages) | class_training; style swap; mastery Long Rest change | Covered (S-045/S-046/S-103; V-025, V-037) |
| 34 | Epic Boon/feat bonus beyond 20 (p.24) | L20 cap | Judgment (parked: over-20 play) |
| 35 | Choices persist and revalidate on load (V-057) | `saved_error`, receipts, `_saved_*_error` | Covered (VS-57/58/68/69; ADR-0030/0031 receipts) |

**Coverage:**

| Status | Rows |
|---|---|
| Covered | 15 |
| Covered-cap | 6 |
| New (4 planned slices S-231–S-234) | 11 |
| Judgment | 4 (2, 20, 22, 34) |

Two rows count in two buckets:
- Row 1 is Covered for the starting-grant route and Covered-cap for its data defects.
- Row 17 is Covered-cap for spell replacement and New (S-233) for list distinctness.

That makes 36 bucket entries across 35 rows. Every row has an owner.

## New planned slices (Progression/Acquisition)

| Slice | Parents | Scope | Depends on |
|---|---|---|---|
| S-231 — Background acquisition at creation | V-025, V-026, V-027, STA-01 | Background content type and creation step. The step grants the ability increase (+2/+1 or +1/+1/+1 from the 3 listed, cap 20), the Origin feat, 2 skills, a fixed tool or a category choice, and equipment A or GP. Receipts and saved validation follow existing grant receipts. | S-047, S-049, S-050 |
| S-232 — Species and language creation choices | V-025, V-027 | Selection-time choice routes: lineage, ancestry and legacy; spellcasting ability chosen at selection; size choice; species skill choice; Human Versatile Origin feat; Common + 2 languages. Character-level 3/5 grants reuse S-048 and S-139. | S-045, S-048, S-139 |
| S-233 — Feat prerequisite kinds and repeat rules | V-025 | Class-level and named-feature prerequisites (Fighting Style, Spellcasting), the repeatable flag, and distinct-parameter repeats (Magic Initiate list). Saved revalidation goes through `FeatRules.saved_error`. | S-049, S-050 |
| S-234 — Multiclass entry prerequisites | V-025, V-026 | Primary-ability requirement data per class (all-of / any-of). Check the new class and every current class before `available_classes` offers the class. Report the exact failing score. | S-047 |

ID note: open PR #62 claims S-227–S-230. This PR starts at S-231. The phase and
count tables in `vocabulary-slices.md` are left untouched so that concurrent
audit PRs don't conflict. Refresh them after the last of them merges.

## Next queue (suggested)

1. Content correction (no new vocabulary):
   - wizard and rogue skill lists
   - rogue weapon restriction
   - druid, rogue and monk tools
   - cleric `shields` token
   - `subclass_level` on 3 classes
2. S-234 multiclass prerequisites, then production `permanent_progression` data for the 12 classes (S-047 content).
3. S-231 backgrounds (4 SRD), which unlock Origin feat sourcing and move ability increases off species.
4. S-232 species choices, then the SRD species set (add Goliath and Orc; retire half-elf, half-orc and species `ability_bonuses`).
5. S-233 feat prerequisites, then production feats (17 SRD) through the existing fixture-proven routes.

## SRD design calls (follow-up, 2026-10-26)

The four rows previously marked "Judgment" (2, 20, 22, 34) are resolved here
from the SRD 5.2.1 text. Page numbers are printed pages of
`SRD_CC_v5.2.1.pdf`, which equal PDF pages. Each item records the SRD rule as
the requirement. Only the clause the SRD explicitly leaves to the GM is kept as
an ADR-0023 judgment item, quoted exactly.

New requirements use `PROPOSED-chargen-N` placeholders. They aren't S-IDs yet:
numbering and the shared registers (slices, checklist, roadmap, counts) are
deferred to the owner's merge pass.

### Row 2: ability score generation (p.21)

**Requirement.** "Determine your ability scores by using one of the following three methods."
- **Standard Array:** 15, 14, 13, 12, 10, 8.
- **Random Generation:** "Roll four d6s and record the total of the highest three dice", repeated for six numbers.
- **Point Cost:** 27 points, using the Ability Score Point Costs table.

The Standard Array by Class table is a placement suggestion, not a rule.

**Runtime:**
- `character_creation.gd` offers point-buy only (`AbilityScores.POINT_BUY_TOTAL`, `is_valid_point_buy`).
- Standard Array and Random Generation are missing.

**Classification:**
- Point Cost: Covered.
- Standard Array and Random Generation: **new gap → PROPOSED-chargen-1** (creation ability-generation methods: method choice, array assignment, seeded 4d6-drop-lowest ×6 with the result recorded and saved). Parents V-025 and V-057.

**Judgment residue (ADR-0023):** "Your GM might prefer you to use a particular one." In this game that becomes a campaign setting that may restrict which methods are offered. It needs an owner default, not a rules interpretation.

### Row 22: XP advancement (p.23, p.25)

**Requirement.** "A character who reaches a specified Experience Point total advances in capability. … When your XP total equals or exceeds a number in the Experience Points column, you reach the corresponding level."
- The Character Advancement table runs from 0 XP at level 1 to 355,000 XP at level 20 (p.23).
- Multiclass characters advance by **total** XP and total level (p.25).
- The SRD text contains no milestone rule; a search of `srd.txt` for "milestone" returns nothing.

**Runtime:**
- `Character.xp` is saved and loaded (character.gd:329, 2614, 2739).
- Level gain is not driven by thresholds; no XP award-to-level route was found.

**Classification:** **new gap → PROPOSED-chargen-2** (XP award and threshold advancement: award XP and raise level eligibility at table thresholds by total level, feeding the existing level-up and `pending_levels` routes, which are Covered under S-048/VS-69). Parents V-026 and V-057.

**Judgment:** none. The SRD gives no GM option here. Milestone leveling is not an SRD rule, so it is not a requirement. Any non-SRD milestone mode would be an owner extension, outside this audit.

### Row 20: starting at higher levels (p.24, p.19)

**Requirement:**
- Creation "uses the same character-creation steps outlined in this chapter and the rules for advancing beyond level 1".
- "You begin with the minimum amount of XP required to reach your starting level" (example: level 10 starts with 64,000 XP).
- Level 3+ starts record a subclass (p.19).
- Starting equipment comes from the Starting Equipment at Higher Levels table (p.24), by tier: 2–4, 5–10, 11–16 and 17–20 each set GP plus magic items by rarity.

**Runtime:** creation produces level 1 only.

**Classification:** **new gap → PROPOSED-chargen-3** (higher-level creation: repeat the level-up steps through the target level, including subclass, HP, the S-231 background and ASI/feat choices; set the minimum XP; apply the tier equipment and money). It depends on PROPOSED-chargen-2, S-045, S-048 and S-231.

**Judgment residue (ADR-0023):**
- "Your GM might start your group's characters at a level higher than 1." This is the campaign's start level (Crown currently starts at level 1).
- "The GM decides whether your character starts with more than the standard equipment for a level 1 character, possibly even one or more magic items. The Starting Equipment at Higher Levels table is a guide for the GM."
  - The table is explicitly a guide, so the actual equipment grant is a campaign setting with the table as the default.
  - The specific magic items are GM-chosen. The SRD gives only the rarity counts.

### Row 34: past level 20 and Epic Boons (p.24, p.88)

**Requirement:**
- Epic Boon at level 19 is a class feature. It is acquired through the Epic Boon feat category, with prerequisite Level 19+ (p.88).
- This part is already Covered: VS-59/VS-60 and `pending_epic_boon_choices`.
- Level 20 is the maximum level: the Character Advancement table ends at 20.

**Classification:**
- Level 19 Epic Boon: Covered.
- Post-20 bonus feats: **new gap, conditional → PROPOSED-chargen-4** (one feat per 30,000 XP above 355,000; any feat the level 20 character qualifies for, Epic Boons included). Active only when the campaign enables it. Depends on PROPOSED-chargen-2 and S-233.

**Judgment residue (ADR-0023):** "A GM can use feats as a form of advancement after characters reach level 20 … With this approach, each character gains one feat of their choice for every 30,000 XP the character earns above 355,000 XP. Epic Boon feats are especially appropriate for these bonus feats, but a player can choose any feat for which their level 20 character qualifies." (p.24) Whether the rule is enabled is the GM's call; its mechanics are fixed by the text.

### Revised coverage

| Status | Rows (36 bucket entries across 35 rows) |
|---|---|
| Covered | 17 (adds row 2 Point Cost, row 34 level 19 Epic Boon) |
| Covered-cap | 6 |
| New | 15 (11 → S-231–S-234; 4 → PROPOSED-chargen-1…4 from rows 2, 20, 22, 34) |
| Judgment | 0 whole rows; 3 quoted GM residues (method preference, start level/equipment, post-20 feats) |

### Slice ID collision check (2026-10-26 08:2x CDT)

What I checked:
- Every open PR (#61–#65) and every `origin` branch, diffed against main.
- Local worktrees `monster-audit`, `rules-audit`, `items-audit` and `gear-stager`.

Findings:
- #62 defines S-227–S-230.
- #64 (`audit/core-rules-conditions`) defines S-235–S-239 and V-100/V-101.
- #65 only mentions S-231 as a reference.
- The local `monster-audit` worktree (`docs/monster-statblock-audit`, unpushed) holds S-230/S-231 and V-100. The parent reports that Creature Stager will renumber.

Result: S-231–S-234 stay as published in #63. No new S- or V-IDs are added here; new requirements use PROPOSED-chargen-1…4.

Updated next queue, inserted after step 3:
- PROPOSED-chargen-2 (XP)
- PROPOSED-chargen-1 (generation methods)
- PROPOSED-chargen-3 (higher-level start)
- PROPOSED-chargen-4 (post-20 feats)
