# Batch 090 build evidence: item data corrections

- Branch: batch-090-item-data-corrections, stacked on batch-089-spell-data-corrections (bbe3a91). Audit source: audit/items @ 4221f89.
- Changed: data/core/items/consumables.json, data/core/items/imported_magic_consumables.json, one new data check in src/test_runner.gd, and docs/audits/items.md (status section).
- Godot 4.7.2: imported twice, then `TEST_SUITE=logic`. Branch result: RESULTS 6416 passed, 0 failed, ALL TESTS PASSED.
  - For comparison: main 6414 / 0; Batch 089 6415 / 0.
  - SCRIPT/Parse/Compile errors in import and test logs: 0.
- Status for each item is in docs/audits/items.md under "Batch 090".
