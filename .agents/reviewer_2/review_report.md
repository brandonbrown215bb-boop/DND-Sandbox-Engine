# Comprehensive Review Report: Quarantined Class Features Remediation Plan

**Reviewer**: Reviewer 2 (`teamwork_preview_reviewer`)  
**Date**: 2026-08-11  
**Target Document**: `docs/quarantined_features_remediation_plan.md`  
**Verdict**: **APPROVE**

---

## 1. Executive Summary

This independent review evaluated `docs/quarantined_features_remediation_plan.md`, focusing on:
1. The **157 Quarantined Feature Taxonomy & Audit Metrics**.
2. The **6 Engine Effect Vocabulary Extension Specifications**.
3. Subsystem boundaries (**Wild Shape ADR-0002**, **Mystic Psionics**, **Infusions**, **Subclasses**).
4. **Narrative Ribbon Tagging** and combat HUD protection.
5. GDScript Dictionary schema validity and compatibility with `src/autoload/data_loader.gd` and `src/events/event_resolver.gd`.
6. Independent script execution of `src/generate_feature_matrix.py` and `src/validate_and_test.py`.
7. Adversarial audit for integrity violations (hardcoded test bypasses, dummy implementations, self-certification, fabricated logs).

The plan is thorough, 100% cataloged across 157 quarantined features, architecturally sound, and verified by test execution.

---

## 2. Review Findings & Schema Analysis

### [Minor] Finding 1: Parameter Key Naming Discrepancy for Resource Operations

- **What**: In `src/events/event_resolver.gd` (lines 143 and 152), resource spending and restoration expect `effect.get("resource_id", effect.get("feature_id", ""))`. However, several proposed GDScript snippets in `docs/quarantined_features_remediation_plan.md` (e.g., Monk `uncanny_metabolism`, `quickened_healing`, `focused_aim`, Sorcerer `magical_guidance`) use `"resource": "ki"` or `"resource": "focus_points"`.
- **Where**: `docs/quarantined_features_remediation_plan.md` (Sections 4.7 & 4.12) vs `src/events/event_resolver.gd` (lines 143, 152).
- **Why**: If implemented into `data_loader.gd` without adjusting `event_resolver.gd` or the snippets, `EventResolver` would resolve `resource_id` as empty.
- **Suggestion**: During Phase 1/Phase 2 implementation, update `event_resolver.gd` to check `effect.get("resource_id", effect.get("resource", effect.get("feature_id", "")))` or standardize snippet payload keys to `"resource_id"`.

---

## 3. Subsystem Boundary & Ribbon Tagging Audit

### 3.1 Wild Shape Subsystem Boundary (ADR-0002)
- **Status**: **VERIFIED / COMPLIANT**
- **Analysis**: Features `druid_wild_shape` and `druid_wild_shape_improvement` are correctly assigned to **Tier 3 (Subsystem-Quarantined)** citing ADR-0002 (`docs/decisions/0002-wild-shape-crown-band.md`). The plan avoids premature implementation before the Wolf-only form contract and temporary HP absorption boundary are integrated into `Character` and `CombatState`.

### 3.2 Mystic Psionics Subsystem Boundary
- **Status**: **VERIFIED / COMPLIANT**
- **Analysis**: All 6 core psionic features (`mystic_mystic_order`, `mystic_psionic_disciplines_and_talents`, `mystic_psionics`, `mystic_using_a_discipline`, `mystic_mystical_recovery`, `mystic_mystic_order_feature`) are placed in **Tier 3 (Subsystem-Quarantined)** until a dedicated Psionics energy pool / discipline activation system is developed.

### 3.3 Narrative Ribbon Tagging
- **Status**: **VERIFIED / COMPLIANT**
- **Analysis**: Exactly **28 non-combat/utility features** across 14 classes (e.g. `rogue_thieves'_cant`, `druid_druidic`, `artificer_magical_tinkering`, `wizard_scholar`) are assigned to **Tier 4**. The plan specifies tagging them with `"type": "narrative_ribbon"`, ensuring they remain preserved for character sheet inspection while filtered out from combat action UI menus.

---

## 4. Verified Claims Matrix

| Claim | Verification Method | Status | Notes |
|---|---|---|---|
| 157 quarantined features audited across 14 classes | Cross-checked table in Sec 1.1 against Sec 4 class tables | **PASS** | 42 T1 + 20 T2 + 67 T3 + 28 T4 = 157. Total features = 193 (36 mechanics-backed). |
| `python src/generate_feature_matrix.py` exits 0 | Executed `python src/generate_feature_matrix.py` | **PASS** | Output generated cleanly; processed 193 records. |
| `python src/validate_and_test.py` exits 0 | Executed `python src/validate_and_test.py` | **PASS** | Hex math, dice parser, RPG mechanics, save/load serialization, and JSON validation all PASSED. |
| ADR-0002 Wild Shape contract alignment | Inspected `docs/decisions/0002-wild-shape-crown-band.md` | **PASS** | Quarantined in Tier 3 until Wolf form contract is merged. |
| GDScript Dictionary syntax correctness | Syntax check of code blocks in Section 4 | **PASS** | All snippets are valid GDScript dictionary literals. |

---

## 5. Adversarial Audit & Stress-Test Challenge Analysis

### 5.1 Integrity Violation Checks
1. **Hardcoded Test Results / Shortcuts**: Checked `src/validate_and_test.py` and `src/generate_feature_matrix.py`. Tests evaluate live hex math, regex tokenizer parsing, dictionary keys, and JSON files in `data/core/`. No hardcoded bypasses found.
2. **Dummy / Facade Implementations**: Verified that the plan does not propose empty or dummy `effects` arrays for Tier 1/2 features. All proposed snippets contain fully specified effect payloads (type, action_cost, uses, uses_per, effects, resource_formula).
3. **Self-Certifying Work**: Verification commands were run independently during this review session and confirmed exit code 0.

### 5.2 Edge Case & Stress Testing
- **Dice Expression Parsing**: Validated that proposed dice formulas (`"1d10+DEX+monk_level"`, `"1d8+WIS"`, `"2d8+2"`, `"5*monk_level"`) match the regex patterns supported by `DiceParserTest` and `DataLoader._validate_nested_values`.
- **Resource Recovery Overlap**: Identified minor schema key variation (`resource` vs `resource_id`) in Section 2 findings to ensure smooth execution when code merge occurs.

---

## 6. Conclusion & Recommendation

`docs/quarantined_features_remediation_plan.md` is **APPROVED**. The remediation plan provides a clear, mathematically complete, and architecturally sound roadmap for restoring quarantined class features to full engine functionality across four phased releases.
