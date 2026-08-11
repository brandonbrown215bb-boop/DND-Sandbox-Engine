# Project: Quarantined Class Features Remediation Plan

## Architecture
- Engine: Godot 4.x / GDScript + Python validation tooling.
- Core Data Files: `data/core/classes/*.json` (14 character classes: barbarian, bard, cleric, druid, fighter, monk, mystic, paladin, ranger, rogue, sorcerer, warlock, wizard, artificer).
- Core Autoload Data Loader: `src/autoload/data_loader.gd` (contains `CURATED_FEATURE_EFFECTS` dictionary and feature resolution logic).
- Matrix & Test Scripts: `src/generate_feature_matrix.py`, `src/validate_and_test.py`.
- Documentation Output: `docs/quarantined_features_remediation_plan.md`.

## Feature Inventory
| # | Feature | Description | Milestone | Source |
|---|---------|-------------|-----------|--------|
| 1 | 14-Class Feature Audit & Taxonomy | Examine all 157 quarantined class features across 14 classes and classify into 4 tiers | M1 | survey |
| 2 | 5E Rules Verification & Dictionary Specs | Specify proposed `CURATED_FEATURE_EFFECTS` for Tiers 1 and 2 | M2 | user_req |
| 3 | Subsystem & Narrative Ribbon Boundaries | Document blocking ADRs/subsystems for Tier 3 and non-combat ribbons for Tier 4 | M3 | user_req |
| 4 | Remediation Plan Markdown Artifact | Deliver comprehensive report at `docs/quarantined_features_remediation_plan.md` | M4 | user_req |
| 5 | Validation & Test Suite Execution | Ensure python `src/generate_feature_matrix.py` and `src/validate_and_test.py` exit with 0 | M5 | user_req |

## Milestones
| # | Name | Scope | Dependencies | Status |
|---|------|-------|-------------|--------|
| 1 | Feature Audit & Taxonomy | Enumerate all 157 features across 14 class JSONs into 4 tiers | none | IN_PROGRESS |
| 2 | Curation Specification | Map Tiers 1 & 2 features to 5e rules and GDScript `CURATED_FEATURE_EFFECTS` | M1 | PLANNED |
| 3 | Subsystem & Ribbon Boundaries | Detail ADR dependencies for Tier 3 & ribbon tag system for Tier 4 | M1 | PLANNED |
| 4 | Remediation Plan Synthesis | Write full remediation specification to `docs/quarantined_features_remediation_plan.md` | M2, M3 | PLANNED |
| 5 | Script Execution & Verification | Run matrix generation script and test runner to ensure exit code 0 | M4 | PLANNED |

## Code Layout
- Documentation: `docs/quarantined_features_remediation_plan.md`
- Data Loader: `src/autoload/data_loader.gd`
- Class Data: `data/core/classes/*.json`
- Validation Scripts: `src/generate_feature_matrix.py`, `src/validate_and_test.py`
