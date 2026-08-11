# Orchestrator Plan

## Overview
Perform a comprehensive audit of all 157 quarantined class feature records in `data/core/classes/`, map them to 5e rules mechanics and `CURATED_FEATURE_EFFECTS` in `src/autoload/data_loader.gd`, detail subsystem dependencies and narrative ribbon tags, produce `docs/quarantined_features_remediation_plan.md`, and verify script execution (`src/generate_feature_matrix.py` and `src/validate_and_test.py`).

## Phases & Milestones
- **Phase 0: Survey & Codebase Investigation**
  - Dispatch Explorers to inspect `data/core/classes/`, `src/autoload/data_loader.gd`, `src/generate_feature_matrix.py`, `src/validate_and_test.py`, ADRs in `docs/decisions/`, and current test/matrix outputs.
- **Phase 1: Taxonomy & Feature Extraction**
  - Audit all 157 quarantined class features across 14 classes.
  - Categorize every feature into Tier 1 (Immediate Curation), Tier 2 (Vocabulary Extension), Tier 3 (Subsystem-Quarantined), Tier 4 (Narrative/Non-Combat Ribbons).
- **Phase 2: 5E Rules Verification & Dictionary Specification**
  - Formulate exact `CURATED_FEATURE_EFFECTS` dictionary entries for Tier 1 and Tier 2 features following `data_loader.gd` schema conventions.
- **Phase 3: Remediation Specification Deliverable**
  - Generate comprehensive Markdown report `docs/quarantined_features_remediation_plan.md`.
- **Phase 4: Verification & Matrix Script Validation**
  - Run `python src/generate_feature_matrix.py` and `python src/validate_and_test.py` via Workers/Reviewers/Auditor.
  - Verify zero errors and full 100% feature coverage.
