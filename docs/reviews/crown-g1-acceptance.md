# Crown G1 acceptance review (Runtime Reviewer)

PR #72, branch codex/crown-class-metadata, base main bd54fa5, reviewed head d5033db. Builder evidence: [crown-g1-build.md](crown-g1-build.md).

## Verdict: ACCEPT. No reviewer code change; this file is the only reviewer commit.

## Evidence (Linux, Godot 4.7.2-stable headless)
- Imported twice with no SCRIPT/Parse/Compile errors. Logic: **6669/0** (main 6651/0; +18 are the G1 assertions).
- Scenarios, run one at a time, all PASS: character_creation, cleric_creation_flow, bard_creation_flow, barbarian_choice_flow, rogue_devious_strikes, character_sheet.
- wizard_capstone_cast_modes FAILS with the identical assertion on PR and on unmodified main bd54fa5: "at-will Spell Mastery path remains separate from slot spending". Main is no better, so this is pre-existing and not caused by G1.
- Not run: `run_tests.ps1` / Windows Godot. That check is left to Brandon.

## A. Core Traits data vs srd.txt
- Wizard: "Choose 2: Arcana, History, Insight, Investigation, Medicine, Nature, or Religion" (srd.txt, Core Wizard Traits). data/core/classes/wizard.json matches exactly; the old Athletics/Acrobatics/Perception/Stealth entries are gone.
- Rogue: "Choose 4: Acrobatics, Athletics, Deception, Insight, Intimidation, Investigation, Perception, Persuasion, Sleight of Hand, or Stealth". No Performance; rogue.json matches.
- Cleric: "Light and Medium armor and Shields". `shields` is the same token fighter/paladin use and the only one permanent_progression_rules.gd:63 accepts; cleric.json now matches.
- Barbarian/Bard/Cleric `subclass_level: 3` matches "Level 3: … Subclass". The loader default was already 3, so behavior is unchanged.

## B. Level-3 no-picker stress (reviewer probe, not committed)
For each of barbarian, bard, cleric at level 3, gold set to 77: `ClassProgression.choose_subclass` with "", "champion", "nonexistent", the class ID itself and three plausible own-class IDs (college_of_lore, life_domain, path_of_the_berserker) all returned false. `to_dict()` was byte-identical afterwards, and gold was unchanged. The refusal is the first guard in class_progression.gd:934, before any state is written. Level 3→4 then succeeds with an empty subclass. No subclass records exist for these classes, so having no picker is correct; the builder's ClassTraining panel check confirms there is no empty "Choose subclass" button.

## C. ADR-0018 and saves
- Data-only change plus checks; no class-ID branch, no new saved field, no loader change. Compliant.
- Legacy restore (Character.from_dict): a cleric with old `"shield"`, a rogue with Performance and a wizard with Athletics/Stealth all restore unchanged with no error. The data change doesn't migrate them: an old cleric keeps the `"shield"` token. Nothing in src consumes armor_proficiencies for shield benefit today, so this is harmless; note it for whoever adds Shield-training checks (see #73 gap 1).

## Nits (non-blocking)
- No migration of old `"shield"` tokens or now-illegal skills on legacy characters (intentional per "no save-format change").
