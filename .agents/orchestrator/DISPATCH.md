## 2026-08-10T22:01:03Z

Perform a deep architectural review and taxonomy audit of all 157 quarantined/effectless class feature records in data/core/classes/. Produce a comprehensive remediation specification document mapping every feature to its 5e rules mechanics, required effect vocabulary, and proposed CURATED_FEATURE_EFFECTS dictionary definitions for data_loader.gd.

Key requirements:
1. Examine all 157 quarantined class feature records across 14 character classes. Categorize every feature into one of 4 tiers (Immediate Curation Candidates, Vocabulary Extension Candidates, Subsystem-Quarantined, Narrative/Non-Combat Ribbons).
2. For Tiers 1 and 2, verify 5e rules mechanics and document exact proposed Dictionary structure for CURATED_FEATURE_EFFECTS in src/autoload/data_loader.gd.
3. Subsystem-blocked features must document specific blocking dependencies/ADRs.
4. Narrative/ribbon features must be categorized to remain quarantined from combat action menus.
5. Deliver complete report at docs/quarantined_features_remediation_plan.md.
6. Ensure python src/generate_feature_matrix.py and python src/validate_and_test.py run cleanly with exit code 0.
