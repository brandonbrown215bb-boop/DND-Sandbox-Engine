# Forensic Audit Remediation Strategy & Specification

**Document Version**: 1.0.0  
**Author**: Explorer 4 (`teamwork_preview_explorer`)  
**Date**: 2026-08-10  
**Target Artifacts**:  
- `src/generate_feature_matrix.py`  
- `docs/quarantined_features_remediation_plan.md`  

---

## 1. Executive Summary & Root Cause Analysis

### 1.1 Background
The Forensic Auditor (`auditor_1`) issued an **INTEGRITY VIOLATION** verdict on `docs/quarantined_features_remediation_plan.md` due to an inventory discrepancy and script-to-documentation desynchronization involving the Monk feature `monk_unarmored_defense`.

### 1.2 Root Cause Analysis
1. **Script Desynchronization (`src/generate_feature_matrix.py`)**:  
   `src/generate_feature_matrix.py` maintains an internal dictionary `CURATED_FEATURE_EFFECTS` to match the curated features defined in `src/autoload/data_loader.gd`. While `data_loader.gd` line 59 contains:
   ```gdscript
   "monk_unarmored_defense": {"type": "passive", "effects": [{"type": "unarmored_defense"}]},
   ```
   `src/generate_feature_matrix.py` omitted `"monk_unarmored_defense"` from its `CURATED_FEATURE_EFFECTS` dictionary (33 entries vs 34 in `data_loader.gd`).

2. **Metrics Mismatch**:  
   Because `monk_unarmored_defense` was missing from `generate_feature_matrix.py`, running `python src/generate_feature_matrix.py` classified `monk_unarmored_defense` as `quarantined` instead of `mechanics-backed`, reporting:
   - **Mechanics-backed**: 35 (instead of 36)
   - **Quarantined**: 158 (instead of 157)  
   This directly contradicted `docs/quarantined_features_remediation_plan.md` Section 1.1, which claimed **36 mechanics-backed** and **157 quarantined** features.

3. **Documentation Ambiguity (`docs/quarantined_features_remediation_plan.md`)**:  
   Section 4.7 (Monk Taxonomy Table) cataloged all 17 quarantined Monk features, but did not explicitly account for `monk_unarmored_defense` among the 7 mechanics-backed features for Monk, creating ambiguity for audit verification.

---

## 2. Tripartite Synchronization Analysis

### 2.1 Complete Monk Feature Inventory (`data/core/classes/monk.json`)
`data/core/classes/monk.json` defines **24 total feature records** across levels 1 through 5.

| Level | Feature ID | Status in `DataLoader.gd` | Audit Taxonomy Status |
|---|---|---|---|
| 1 | `monk_martial_arts` | Mechanics-Backed (Curated) | Excluded from Quarantined Table (Active) |
| 1 | `monk_unarmored_defense` | **Mechanics-Backed (Curated)** | **Excluded from Quarantined Table (Active)** |
| 1 | `monk_bonus_unarmed_strike` | Mechanics-Backed (Curated) | Excluded from Quarantined Table (Active) |
| 1 | `monk_dexterous_attacks` | Quarantined | Tier 1: Immediate Curation Candidate |
| 1 | `monk_martial_arts_die` | Quarantined | Tier 1: Immediate Curation Candidate |
| 2 | `monk_dedicated_weapon` | Quarantined | Tier 4: Narrative / Non-Combat Ribbon |
| 2 | `monk_flurry_of_blows` | Mechanics-Backed (Curated) | Excluded from Quarantined Table (Active) |
| 2 | `monk_ki` | Quarantined | Tier 3: Subsystem-Quarantined |
| 2 | `monk_patient_defense` | Mechanics-Backed (Curated) | Excluded from Quarantined Table (Active) |
| 2 | `monk_step_of_the_wind` | Mechanics-Backed (Curated) | Excluded from Quarantined Table (Active) |
| 2 | `monk_unarmored_movement` | Quarantined | Tier 1: Immediate Curation Candidate |
| 2 | `monk_monk's_focus` | Quarantined | Tier 3: Subsystem-Quarantined |
| 2 | `monk_uncanny_metabolism` | Quarantined | Tier 1: Immediate Curation Candidate |
| 3 | `monk_deflect_missiles` | Quarantined | Tier 2: Vocabulary Extension Candidate |
| 3 | `monk_ki-fueled_attack` | Quarantined | Tier 1: Immediate Curation Candidate |
| 3 | `monk_monastic_tradition` | Quarantined | Tier 3: Subsystem-Quarantined |
| 3 | `monk_deflect_attacks` | Quarantined | Tier 2: Vocabulary Extension Candidate |
| 3 | `monk_monk_subclass` | Quarantined | Tier 3: Subsystem-Quarantined |
| 4 | `monk_ability_score_improvement` | Quarantined | Tier 1: Immediate Curation Candidate |
| 4 | `monk_quickened_healing` | Quarantined | Tier 1: Immediate Curation Candidate |
| 4 | `monk_slow_fall` | Quarantined | Tier 2: Vocabulary Extension Candidate |
| 5 | `monk_extra_attack` | Mechanics-Backed (Curated) | Excluded from Quarantined Table (Active) |
| 5 | `monk_focused_aim` | Quarantined | Tier 2: Vocabulary Extension Candidate |
| 5 | `monk_stunning_strike` | Quarantined | Tier 2: Vocabulary Extension Candidate |

**Totals**: 24 total records = **7 Mechanics-Backed** + **17 Quarantined**.

---

## 3. Exact Code & Documentation Remediation Specifications

### 3.1 Code Remediation Specification (`src/generate_feature_matrix.py`)

#### Target Location
`src/generate_feature_matrix.py`, lines 27–32.

#### Required Change
Add `"monk_unarmored_defense": "unarmored_defense:10+DEX+WIS without shield",` to `CURATED_FEATURE_EFFECTS`.

#### Exact Code Snippet Replacement

**Before**:
```python
    "barbarian_rage": "grant_condition+stat_modifier",
    "barbarian_unarmored_defense": "unarmored_defense:10+DEX+CON with shield",
    "barbarian_reckless_attack": "reckless_attack",
    "monk_patient_defense": "grant_condition",
    "monk_step_of_the_wind": "step_of_the_wind",
    "monk_martial_arts": "unarmed_attack",
```

**After**:
```python
    "barbarian_rage": "grant_condition+stat_modifier",
    "barbarian_unarmored_defense": "unarmored_defense:10+DEX+CON with shield",
    "barbarian_reckless_attack": "reckless_attack",
    "monk_patient_defense": "grant_condition",
    "monk_unarmored_defense": "unarmored_defense:10+DEX+WIS without shield",
    "monk_step_of_the_wind": "step_of_the_wind",
    "monk_martial_arts": "unarmed_attack",
```

---

### 3.2 Documentation Remediation Specification (`docs/quarantined_features_remediation_plan.md`)

#### Target Location
`docs/quarantined_features_remediation_plan.md`, Section 4.7 (Monk Taxonomy).

#### Required Change
Add an explicit explanatory note preceding the Section 4.7 table clarifying the 7 mechanics-backed features (specifically highlighting `monk_unarmored_defense` alongside `barbarian_unarmored_defense`).

#### Exact Markdown Text Replacement

**Before**:
```markdown
### 4.7 Monk (17 Quarantined Features)

| Feature ID | Level | Tier | 5e Rule Mechanics Summary | Proposed Curation / Quarantine Specification |
```

**After**:
```markdown
### 4.7 Monk (17 Quarantined Features)

> **Note on Mechanics-Backed Features**: Out of 24 total feature records in `data/core/classes/monk.json`, **7 features** are already mechanics-backed and active in `DataLoader.gd` (`monk_martial_arts`, `monk_unarmored_defense`, `monk_bonus_unarmed_strike`, `monk_patient_defense`, `monk_step_of_the_wind`, `monk_flurry_of_blows`, `monk_extra_attack`). The **17 quarantined features** requiring remediation are cataloged in the taxonomy table below.

| Feature ID | Level | Tier | 5e Rule Mechanics Summary | Proposed Curation / Quarantine Specification |
```

---

## 4. Verification Protocol

To verify that the remediation completely resolves the INTEGRITY VIOLATION and aligns code, tests, and documentation:

1. **Script Output Verification**:
   Execute:
   ```powershell
   python src/generate_feature_matrix.py
   ```
   **Expected Result**: The exposure summary line for class features MUST output exactly:
   ```
   | Class features | 36 | 0 | 157 | 0 |
   ```

2. **Automated Test Suite Verification**:
   Execute:
   ```powershell
   python src/validate_and_test.py
   ```
   **Expected Result**: All tests (Hex Math, Dice Parser, Core RPG Mechanics, Serialization, and JSON Schema Validation) must pass with exit code `0`.

3. **Tripartite Alignment Check**:
   - `src/autoload/data_loader.gd`: 34 feature entries in `CURATED_FEATURE_EFFECTS` (7 Monk features).
   - `src/generate_feature_matrix.py`: 34 feature entries in `CURATED_FEATURE_EFFECTS` (7 Monk features).
   - `docs/quarantined_features_remediation_plan.md`: Section 1.1 summary table reports 36 mechanics-backed & 157 quarantined features; Section 4.7 explicitly clarifies all 24 Monk features.
