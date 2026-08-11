# System Verification Survey Report

**Author**: Explorer 3 (teamwork_preview_explorer)  
**Date**: 2026-08-10  
**Scope**: Matrix Scripts (`src/generate_feature_matrix.py`), Unit Validation Suite (`src/validate_and_test.py`), Engine Quarantine Mechanics (`src/autoload/data_loader.gd`), ADR & Architectural Inventory (`docs/`), and Shared Questboard (`.questboard/`).

---

## 1. Executive Summary

This survey examines the codebase's feature matrix generation pipeline, validation test infrastructure, subsystem quarantine boundaries, and architecture decisions. 

Key Findings:
1. **Quarantine Execution**: `DataLoader` (`src/autoload/data_loader.gd`) actively filters out unsupported class features at runtime during `_sanitize_class_features`. Any feature lacking an explicit `effects` array or `resolver` field (and not registered in `CURATED_FEATURE_EFFECTS`) is logged with a warning and stripped from player-facing data.
2. **Matrix Reporting**: `src/generate_feature_matrix.py` mirrors the runtime `CURATED_FEATURE_EFFECTS` dictionary to categorize all 193 class feature records across 14 class JSONs into `mechanics-backed` vs `quarantined`.
3. **Offline Validation Infrastructure**: `src/validate_and_test.py` is a standalone Python runner that validates Hex grid math, dice string tokenization, JSON schema compliance across `data/core/`, core D&D 5e rule mechanics formulas, and Character DTO serialization key symmetry. Both `validate_and_test.py` and `generate_feature_matrix.py` execute cleanly with exit code 0.
4. **Subsystem ADRs**: ADR-0002 details the quarantine status and proposed contract for Druid Wild Shape (`wolf` form only, temp HP absorption, safe save boundaries). Mystic Psionics has no engine primitives and remains subsystem-quarantined. Non-combat ribbons (e.g. `thieves_cant`, `druidic`) are quarantined to avoid UI clutter.
5. **Questboard State**: `.questboard/` tracks active activity history work and review gates. Parked quest `Q-20260810-010133-85ce` explicitly preserves Wild Shape quarantine until explicitly unparked.

---

## 2. Feature Matrix Computation & Quarantine Mechanism

### 2.1 Feature Matrix Generation (`src/generate_feature_matrix.py`)

`src/generate_feature_matrix.py` scans `data/core/classes/*.json` (14 class files: Artificer, Barbarian, Bard, Cleric, Druid, Fighter, Monk, Mystic, Paladin, Ranger, Rogue, Sorcerer, Warlock, Wizard) up to level 5.

- **Curated Dictionary Mirror**: The script defines `CURATED_FEATURE_EFFECTS` (lines 23–57), mapping feature IDs (e.g. `fighter_second_wind`, `barbarian_rage`, `rogue_sneak_attack`) to curated effect descriptions.
- **Classification Logic** (`feature_rows()`, lines 126–156):
  ```python
  if effects or resolver:
      status = "mechanics-backed"
  elif curated_effect:
      status = "mechanics-backed"
  else:
      status = "quarantined"
  ```
- **Output Statistics**: Reports exposure summary, per-record coverage, collision IDs across JSON registries, and markdown tables consumable by project documentation (`docs/feature_matrix.md`).

### 2.2 Godot Engine Runtime Quarantine (`src/autoload/data_loader.gd`)

At runtime in Godot, `DataLoader` processes content files through a multi-pass pipeline:
1. `_curate_feature_effects(data)` (lines 427–444): Merges definitions from `CURATED_FEATURE_EFFECTS` into class features if `effects` is empty.
2. `_sanitize_class_features(data, source)` (lines 405–425): Inspects every feature in `features_by_level`.
   ```gdscript
   var has_effects: bool = feature.get("effects", []) is Array and not feature.get("effects", []).is_empty()
   var has_resolver := not str(feature.get("resolver", "")).is_empty()
   if not has_effects and not has_resolver:
       _validation_warnings.append("Rejected unsupported effectless feature '%s' in %s" % [feature.get("id", ""), source])
       continue
   kept.append(feature)
   ```
3. **Quarantine Outcome**: Features failing both conditions are excluded from `features_by_level` stored in `DataLoader.classes`. Consequently, `Character.level_up()` and player UI components never receive or expose uncurated features.

---

## 3. Unit Validation & Testing Infrastructure

### 3.1 Python Unit Test Suite (`src/validate_and_test.py`)

`src/validate_and_test.py` is a lightweight, zero-dependency Python script designed for instant local execution and CI sanity checks. It comprises 5 distinct test classes:

| Test Class | Scope & Verification |
|---|---|
| `HexUtilsTest` | Verifies axial coordinate math, 6-direction neighbor generation, and distance calculation (`dq, dr, ds` max distance). |
| `DiceParserTest` | Verifies tokenization of dice strings including sign collapsing (`+-`, `--`), uppercase conversion, and variable modifiers (e.g. `2d8+STR-1d4`). |
| `JSONValidator` | Validates structural integrity and required schema keys for `classes`, `races`, `items`, `spells`, `monsters`, `events`, and `campaigns` under `data/core/`. Also verifies tile coordinates (`q`, `r`, `terrain`) in campaign maps. |
| `CoreRPGMechanicsTest` | Unit tests 10 core 5e mechanics implementations: Wizard Arcane Recovery formula `(level+1)//2`, Concentration DC formula `max(10, dmg//2)`, Sneak Attack advantage/ally rules, condition roll modifiers (advantage/disadvantage), Prone target melee vs ranged advantage/disadvantage, Evasion save damage halving/negation, Shield reaction AC +5, Uncanny Dodge damage halving, Sleep spell HP pool targeting, and Opportunity Attack movement triggers. |
| `SaveLoadSerializationTest` | Validates key symmetry between Character `to_dict` serializer outputs and `from_dict` deserializer inputs to prevent save data corruption or lost attributes. |

**Execution Result**:
```
[Test] Running Hex Math tests... PASSED.
[Test] Running Dice Parser Tokenizer tests... PASSED.
[Test] Running Core RPG Mechanics & Rules tests... PASSED.
[Test] Running Save/Load Serialization schema tests... PASSED.
[Test] Starting JSON structural validation... PASSED.
[Test] ALL UNIT AND STRUCTURAL TESTS PASSED SUCCESSFULLY!
```

### 3.2 System Test Hierarchy & Godot Test Runner

The project employs a dual-layer test strategy:

1. **Python Layer (`validate_and_test.py`)**: Runs instantly without Godot binary. Verifies schema validity, math formulas, and DTO symmetry.
2. **Godot Engine Layer (`run_tests.ps1`)**: Windows PowerShell runner supervising Godot engine cases:
   - **Parse Gate** (`parse_gate.tscn`): Verifies Godot script compilation across `src/` and `scenes/`.
   - **Boot Gate** (`boot_gate.tscn`): Validates clean boot of `main.tscn`.
   - **Logic Suite** (`test_runner.tscn`): Executes Godot unit tests for data loader, combat actions, spellcasting, and save manager.
   - **Viewport Harness** (`viewport_harness.tscn`): Runs isolated GUI/scenario integration tests in fresh Godot processes.

---

## 4. Subsystem Dependencies & Quarantined Feature Boundaries

### 4.1 Subsystem Inventory & ADR Overview

| ADR / Document | Subsystem / Topic | Status & Quarantine Boundary |
|---|---|---|
| **ADR-0001 (Windows Host)** | Validation Environment | Windows is the authoritative validation host (`run_tests.ps1`). |
| **ADR-0001 (Shared Keyboard)**| Local Multiplayer | 1–4 logical seats sharing keyboard on 1 desktop view. |
| **ADR-0002 (Wild Shape)** | Druid Wild Shape | **Proposed / Quarantined**. Defines a strict Crown-band contract: `wolf` form only (`2d8+2` temp HP), bonus-action entry/dismissal, 10-round duration, 2 uses per rest, equipment preserved, no spellcasting/weapons while shaped, reversion on 0 temp HP. Mid-combat save of shaped state is prohibited. |
| **ADR-0003 (Player VTT Shell)**| UI & Activity History | Desktop VTT shell with 200-record persistent activity history DTO rail. |
| **Mystic Psionics Document** | Mystic Psionics | **Subsystem-Quarantined**. Mystic class features (`mystic_psionics`, `mystic_psionic_disciplines`) require a psionic energy pool and talent system not implemented in the engine. Remains quarantined under Tier 3. |
| **Spellcasting Contracts** | Spellcasting | Curated spell access restricted via `CURATED_SPELL_ACCESS` in `data_loader.gd`. Uncurated spells remain description-only or quarantined. |
| **Narrative / Non-Combat** | Fluff / Ribbon Features | Features like `thieves_cant`, `druidic`, `scholarly_nature`, `artificer_magical_tinkering` lack combat actions and are tagged for Tier 4 quarantine to avoid polluting combat action menus. |

---

## 5. Shared Questboard Analysis (`.questboard/`)

The repository uses `.questboard/` for agent/person task coordination.

- **Command executed**: `python .questboard/quest.py brief --actor "Explorer 3"`
- **Active Quest**:
  - `Q-20260811-025721-ff37`: Implement activity history DTO, bounded store, and save round trip (Rook).
- **Review Quests**:
  - Gate 5–8 readiness and audit decisions (`Q-20260810-010129-f2f2` through `Q-20260810-010139-1745`).
- **Relevant Parked Quest**:
  - `Q-20260810-010133-85ce`: **Decide the Crown-band Wild Shape contract**. (Note: "Keep Wild Shape quarantined. Unpark only if Pigeon wants to expose it and choose the small Crown-band contract.")

---

## 6. Recommendations for Feature Curation & Remediation

1. **Dual Dictionary Synchronicity**: When Explorer 1, Explorer 2, or an Implementer adds curated effect specifications, they must add matching definitions to both `CURATED_FEATURE_EFFECTS` in `src/autoload/data_loader.gd` AND `CURATED_FEATURE_EFFECTS` in `src/generate_feature_matrix.py`.
2. **Subsystem Quarantine Compliance**:
   - Mystic psionics features MUST remain in Tier 3 (Subsystem-Quarantined).
   - Druid Wild Shape (`druid_wild_shape`) MUST remain in Tier 3 unless ADR-0002 is explicitly accepted and implemented.
3. **Narrative Ribbon Compliance**: Narrative/non-combat features MUST be assigned to Tier 4 (Narrative / Non-Combat Ribbons) so they remain cleanly quarantined from combat action menus.
4. **Validation Integrity**: After creating `docs/quarantined_features_remediation_plan.md`, both `python src/generate_feature_matrix.py` and `python src/validate_and_test.py` MUST be executed to verify exit code 0 and clean execution.
