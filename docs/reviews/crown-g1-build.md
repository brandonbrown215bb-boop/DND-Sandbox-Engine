# Crown G1 build evidence: class metadata

Base: origin/main `bd54fa5` (planning snapshot 7ce30378). Branch `codex/crown-class-metadata`. Built by Runtime Builder on Linux.

## Changes (SRD 5.2.1 Core Traits)
- Wizard `skill_choices.from`: Arcana, History, Insight, Investigation, Medicine, Nature, Religion (srd.txt ~4604).
- Rogue `skill_choices.from`: removed Performance; now Acrobatics, Athletics, Deception, Insight, Intimidation, Investigation, Perception, Persuasion, Sleight of Hand, Stealth (srd.txt ~3640).
- Cleric `armor_proficiencies`: `shield` -> existing `shields` token (Light and Medium armor and Shields, srd.txt ~2205).
- Barbarian, Bard, Cleric: `"subclass_level": 3` ("Level 3: Barbarian/Bard/Cleric Subclass", srd.txt 1785, 2001, 2281). The loader default was already 3, so behavior is unchanged; the declaration is now explicit.
- `src/cleric_checks.gd`: expectation updated to `shields`. `src/class_feature_checks.gd`: new `_crown_class_metadata` (classes group, 18 assertions).

## Level-3 proof (Barbarian, Bard, Cleric)
For each class, with no subclass records loaded: a character levelled 1->3 through the production path reaches level 3 with an empty subclass and no error; `ClassProgression.choose_subclass(c, "champion")` returns false and leaves `to_dict()` unchanged; and a real `ClassTraining` panel configured for that character contains no "Choose subclass" button, so there is no empty picker or stuck screen. Result: all pass.

## Checks run (Linux, Godot 4.7.2-stable headless, sequentially)
- `--headless --path . --import`: no SCRIPT/Parse/Compile errors.
- `TEST_SUITE=logic bash run_tests.sh`: **6669 passed, 0 failed** (main baseline 6651/0; the +18 are the new G1 assertions). No SCRIPT/Parse/Compile errors in the logs.
- `normal_creation_matrix` (main.tscn, RUN_NORMAL_CREATION_MATRIX=1): PASSED, 1-4 players.
- viewport_harness scenarios: character_creation, cleric_creation_flow, bard_creation_flow, barbarian_choice_flow, cleric_action_flow, rogue_devious_strikes and character_sheet all PASSED.
- wizard_capstone_cast_modes: FAILED, "at-will Spell Mastery path remains separate from slot spending". It fails the same way on unmodified main on this Linux box, so this change did not cause it. Left for local verification.

## Limits
- Not run: `run_tests.ps1` / Windows Godot. That supported check is left to Brandon.
- Out of scope per G1: starting packages, tools, Rogue weapon restriction, native feature conversion, progression opt-in, and subclass records.
- No save-format change. Legacy saves still load: `legacy_subclass` and the subclass_level default are unchanged.

## Source manifest
data/core/classes/{wizard,rogue,cleric,barbarian,bard}.json, src/class_feature_checks.gd, src/cleric_checks.gd; SRD: /workspace/srd.txt (SRD 5.2.1).
