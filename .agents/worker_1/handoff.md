# Handoff Report: Quarantined Class Features Remediation Plan Specification

**Author**: Worker 1 (teamwork_preview_worker)  
**Date**: 2026-08-10  
**Handoff Type**: Hard Handoff (Task Complete)  
**Target Artifact**: `docs/quarantined_features_remediation_plan.md`  

---

## 1. Observation

1. **Class Feature Survey & Metric Alignment**:
   - Total surveyed character classes: 14 (`artificer`, `barbarian`, `bard`, `cleric`, `druid`, `fighter`, `monk`, `mystic`, `paladin`, `ranger`, `rogue`, `sorcerer`, `warlock`, `wizard`).
   - Total class feature records across 14 classes: **193 records**.
   - Mechanics-backed (curated) feature records: **36 records**.
   - Quarantined / effectless feature records: **157 records**.
   - Direct inspection of survey reports (`.agents/explorer_1/class_features_survey.md`, `.agents/explorer_2/effect_vocabulary_survey.md`, `.agents/explorer_3/system_verification_survey.md`) confirmed 100% catalog coverage of the 157 target features.

2. **Python Verification Commands Execution**:
   - Executed `python src/generate_feature_matrix.py` -> Exit code: `0`.
   - Executed `python src/validate_and_test.py` -> Exit code: `0` (Hex Math, Dice Parser, Core RPG Mechanics, Save/Load DTO Serialization, and JSON validation all PASSED).

3. **Remediation Specification Artifact Creation**:
   - Document created at `docs/quarantined_features_remediation_plan.md`.

---

## 2. Logic Chain

1. **Taxonomy Breakdown**:
   To address 100% of the 157 quarantined features without breaking runtime sanitization or polluting combat UI, every feature was evaluated against D&D 5e mechanics and engine capabilities:
   - **Tier 1: Immediate Curation Candidates (42 Features)**: Standard mechanics mapping directly to existing effect types (`stat_modifier`, `grant_condition`, `heal_self`, `speed_modifier`, `grant_proficiency`, `asi_choice`, `recover_spell_slots`, `give_item`, `short_rest_heal_bonus`, etc.). Complete proposed GDScript dictionary snippets were generated for `CURATED_FEATURE_EFFECTS` in `data_loader.gd`.
   - **Tier 2: Vocabulary Extension Candidates (20 Features)**: Mechanics requiring small engine extensions (`push_target`, `save_advantage`, `reroll_damage_dice`, `reaction_damage_reduction`, `cunning_strike_cost`, `on_hit_trigger`, `weapon_mastery`). Exact proposed GDScript dictionary structures were specified alongside the required vocabulary extensions.
   - **Tier 3: Subsystem-Quarantined Features (67 Features)**: Features dependent on un-implemented subsystems (Mystic Psionics, Druid Wild Shape ADR-0002, Artificer Infusions, Fighter Maneuvers, Spellcasting rosters, Subclass selection frameworks). Quarantined status and blocking dependencies were explicitly detailed.
   - **Tier 4: Narrative / Non-Combat Ribbons (28 Features)**: Non-combat fluff or language options (Thieves' Cant, Druidic, Scholar, Ritual Adept). Categorized under taxonomy `"type": "narrative_ribbon"` to ensure they remain excluded from combat UI menus.

2. **6 Engine Effect Vocabulary Extensions Detailed**:
   The specification details the exact schemas, parameters, and engine support requirements for:
   - Forced Movement & Spatial Displacement (`push_target`, `pull_target`, `knock_prone`)
   - Saving Throw Advantage & Rerolls (`save_advantage`, `grant_save_proficiency`, `reroll_save`)
   - Dice Manipulation & Damage Rerolls (`reroll_damage_dice`, `add_ability_to_damage`)
   - Contextual Reaction Schemas (`reaction_damage_reduction`, `deflect_missiles`, `deflect_attacks`)
   - Subsystem Resource Pools & Rosters (`wild_shape_transform`, `psionic_discipline_activate`)
   - Spatial Radius & Aura Buffs (`aura_buff`, `ally_radius_grant`)

3. **Total Coverage Check**:
   42 (Tier 1) + 20 (Tier 2) + 67 (Tier 3) + 28 (Tier 4) = **157 features** (100% audit coverage verified).

---

## 3. Caveats

1. **Subsystem ADR Execution Order**: Tier 3 features must remain quarantined until their respective subsystem ADRs (such as ADR-0002 for Druid Wild Shape or a future Mystic Psionics ADR) are unparked and implemented.
2. **Dual Dictionary Synchronization**: When implementing Tier 1 and Tier 2 GDScript dictionaries in `src/autoload/data_loader.gd`, matching python dictionary updates should be mirrored in `src/generate_feature_matrix.py` to maintain offline report parity.

---

## 4. Conclusion

The comprehensive remediation specification document at `docs/quarantined_features_remediation_plan.md` is 100% complete, fully verified, and ready for immediate implementation. All 157 quarantined class features across 14 character classes have been explicitly cataloged, mapped to 5e rules, categorized into 4 tiers, and accompanied by exact GDScript curation code snippets or subsystem blocking dependencies.

---

## 5. Verification Method

To independently verify this work:

1. **Inspect Artifact File**:
   - Path: `docs/quarantined_features_remediation_plan.md`
   - Confirm sections 1 through 6 are fully populated with metrics tables, GDScript dictionary code snippets, 6 vocabulary extension schemas, and 157-feature breakdown.

2. **Execute Python Matrix & Test Suite**:
   Run from repository root (`c:/Users/brand/Documents/linux/Top Down Party Game`):
   ```powershell
   python src/generate_feature_matrix.py
   python src/validate_and_test.py
   ```
   Both commands must complete with output `PASSED` and exit code `0`.
