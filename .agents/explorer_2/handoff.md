# Handoff Report - Explorer 2 (Data Loader & Effect Vocabulary Survey)

## 1. Observation

1. **`CURATED_FEATURE_EFFECTS` Dictionary Definition**:
   * File: `src/autoload/data_loader.gd` (lines 42–108).
   * Exact size: 34 curated feature entries defined as GDScript Dictionary literals.
   * Example verbatim entries:
     ```gdscript
     "fighter_second_wind": {"effects": [{"type": "heal_self", "value": "1d10+level"}], "uses_per": "rest"},
     "barbarian_rage": {"effects": [
         {"type": "grant_condition", "condition": "raging", "duration": 10},
         {"type": "stat_modifier", "key": "damage:physical", "amount": 2, "duration": 10}
     ], "uses_per": "rest", "action_cost": "bonus_action"},
     "paladin_lay_on_hands": {"effects": [
         {"type": "lay_on_hands", "pool": "level_times_five"}
     ], "uses": 1, "uses_per": "rest", "action_cost": "action", "resource_formula": "level*5"},
     ```

2. **Curation & Sanitization Logic**:
   * File: `src/autoload/data_loader.gd` (lines 415–444).
   * `_curate_feature_effects`: Injects `CURATED_FEATURE_EFFECTS[feature_id]` into features with empty `effects` arrays.
   * `_sanitize_class_features`: Strips features without `effects` or `resolver`, logging warnings:
     ```gdscript
     if not has_effects and not has_resolver:
         _validation_warnings.append("Rejected unsupported effectless feature '%s' in %s" % [feature.get("id", ""), source])
         continue
     ```

3. **Runtime Execution Stack**:
   * `src/characters/character.gd` (lines 175–188, 425–438, 469–475): Manages `_apply_passive_feature`, AC calculations (`_recalculate_ac`), resource initialization (`get_feature_max_uses`), and rest recovery.
   * `src/characters/class_feature.gd` (lines 9–51): Static `execute()` handles `heal_self` and `grant_extra_action`, delegating others to `EventResolver._apply_single_effect()`.
   * `src/events/event_resolver.gd` (lines 6–13, 88–273): Declares `SUPPORTED_EFFECT_TYPES` (35 types) and applies state changes (`take_damage`, `heal`, `add_condition`, `add_modifier`, etc.).
   * `src/combat/combat_state.gd` (lines 393–400, 672, 977, 995, 1019, 1255, 1635–1657): Hooks feature triggers for `sneak_attack`, `divine_smite`, `reckless_attack`, `favored_foe`, `uncanny_dodge`, and `sorcerer_metamagic`.

4. **Matrix & Verification Scripts**:
   * `src/generate_feature_matrix.py` (lines 23–57): Contains a Python copy of `CURATED_FEATURE_EFFECTS` dictionary mapping IDs to effect strings for matrix generation.
   * Tool command output: `python src/generate_feature_matrix.py` and `python src/validate_and_test.py` both completed with exit code `0`.

---

## 2. Logic Chain

1. **Observation 1 & 2** establish that `data_loader.gd` uses `CURATED_FEATURE_EFFECTS` to hydrate class features loaded from JSON. Features lacking `effects` or `resolver` are rejected during `_sanitize_class_features`, meaning all candidate features must be assigned valid `effects` in `CURATED_FEATURE_EFFECTS` to become mechanics-backed.
2. **Observation 3** establishes that feature execution spans 3 layers: passive stat application in `character.gd`, active action dispatch in `class_feature.gd`/`event_resolver.gd`, and contextual trigger evaluation in `combat_state.gd`.
3. **Observation 3 & Survey Catalog** reveal that while 35 effect types are currently supported, D&D 5e mechanics across the 157 quarantined features require 6 missing vocabulary capability areas (forced movement, saving throw advantage/rerolls, damage dice manipulation, reaction trigger schemas, subsystem pools, spatial aura modifiers).
4. **Observation 4** demonstrates that updating `CURATED_FEATURE_EFFECTS` in `data_loader.gd` (and synchronizing `generate_feature_matrix.py`) enables quarantined features to transition cleanly to `mechanics-backed` status while passing unit tests.

---

## 3. Caveats

* **No Code Modifications**: As a read-only Explorer, no source code in `src/` was modified. All analysis was conducted via direct code inspection and script execution.
* **Engine Scope**: Subsystem-blocked features (such as Mystic Psionics and Druid Wild Shape rosters) rely on unbuilt external subsystems rather than simple dictionary effect entries.

---

## 4. Conclusion

`src/autoload/data_loader.gd` provides a deterministic curation interface (`CURATED_FEATURE_EFFECTS`) that maps raw class feature IDs to executable engine effect dictionaries.

To remediate the 157 quarantined class features:
* **Tier 1 Candidates** can be curated immediately using existing supported vocabulary (`stat_modifier`, `grant_condition`, `heal_self`, `extra_attack`, `grant_extra_action`, `recover_spell_slots`, `give_item`, `reaction`, etc.).
* **Tier 2 Candidates** require small, targeted vocabulary extensions in `EventResolver.gd` / `combat_state.gd` (specifically `save_advantage`, `push_target`, `reroll_damage_dice`, and reaction triggers).
* **Tiers 3 & 4 Candidates** should remain quarantined or tagged as narrative ribbons to prevent combat UI pollution.

The survey report is fully documented at `.agents/explorer_2/effect_vocabulary_survey.md`.

---

## 5. Verification Method

To independently verify these findings and test execution:

1. **Run Python Verification Command**:
   ```powershell
   python src/generate_feature_matrix.py
   python src/validate_and_test.py
   ```
   *Expected Result*: Both commands execute without errors and return exit code `0`.

2. **Inspect Survey Report File**:
   View `.agents/explorer_2/effect_vocabulary_survey.md` for full tabular breakdown of `CURATED_FEATURE_EFFECTS` and effect vocabulary taxonomy.
