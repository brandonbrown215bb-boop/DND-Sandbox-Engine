# DISPATCH for Worker 2: Forensic Remediation & Script Synchronization

## Objective
Apply the exact code and documentation updates specified in `.agents/explorer_4/remediation_strategy.md` to resolve the Forensic Auditor's `INTEGRITY VIOLATION`.

## Mandatory Integrity Warning
DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A teamwork_preview_auditor will independently verify your work.

## Task Details
1. Read `.agents/explorer_4/remediation_strategy.md`.
2. Edit `src/generate_feature_matrix.py`:
   - Add `"monk_unarmored_defense": "unarmored_defense:10+DEX+WIS without shield",` to `CURATED_FEATURE_EFFECTS` dictionary (around line 28).
3. Edit `docs/quarantined_features_remediation_plan.md`:
   - Add the note to Section 4.7 clarifying the 7 mechanics-backed Monk features and 17 quarantined features.
4. Run `python src/generate_feature_matrix.py` and verify it outputs `| Class features | 36 | 0 | 157 | 0 |`.
5. Run `python src/validate_and_test.py` and verify exit code is 0.
6. Write your handoff report to `.agents/worker_2/handoff.md`.
