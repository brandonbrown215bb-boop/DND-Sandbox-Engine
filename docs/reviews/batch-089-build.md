# Batch 089 build evidence: spell data corrections

- Branch: batch-089-spell-data-corrections, from origin/main ede0a3c. Audit source: audit/spells @ 74aa034.
- Changed: data/core/spells/{imported,srd_additional,core}_spells.json (63 records, edited per record), src/test_runner.gd (Command assertion corrected to SRD 5.2.1, plus one new data check), and docs/audits/spells.md (status section).
- Godot 4.7.2: imported twice before each run, then `TEST_SUITE=logic`.
  - Baseline (main ede0a3c): RESULTS 6414 passed, 0 failed, ALL TESTS PASSED.
  - Branch: RESULTS 6415 passed, 0 failed, ALL TESTS PASSED.
  - SCRIPT/Parse/Compile errors in import and test logs: 0 for both.
- The first branch run included the D-09 class-list edits and failed 8 approved-inventory assertions. Those edits were reverted, and D-09 is now BLOCKED (see spells.md).
- Status for each D-item is in docs/audits/spells.md under "Batch 089".
