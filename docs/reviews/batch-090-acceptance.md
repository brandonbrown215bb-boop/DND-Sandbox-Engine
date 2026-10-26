# Batch 090 Acceptance: Item data corrections (PR #68)

Reviewer: Runtime Reviewer. Head reviewed: 6e3a0af, stacked on #67 at bbe3a91. Verdict: **ACCEPTED (partial, as labelled)**.

## SRD 5.2.1 checks (srd.txt)
| Row | SRD | Result |
|---|---|---|
| D-3: Potion of Healing is a Bonus Action to drink or administer | 6005-6008 | PASS. The "administer" half is honestly marked BLOCKED. |
| D-3: greater, superior and supreme healing | 15170-15183 (table) | PASS: these are potions of the same family. |
| D-2: Potion of Poison does 4d6 Poison, DC 13 CON, Poisoned for 1 hour | 15177-15187 | PASS for the damage. The duration of 600 turns is right because event_resolver.gd:489 counts in turns. The save gate is honestly marked BLOCKED. |
| D-1: Poison Resistance no longer applies Poisoned | Potion of Resistance, 15188 | PASS. It now matches the other Resistance stubs. |
| D-4, D-5, D-6, D-7, D-8 | n/a | These are audit-correction or BLOCKED rows. Their reasons check out, including the D-8 double-roll risk. |

## Checks
- **ADR-0018:** the only src change is in test_runner.gd. combat_state.gd:5222 and 5587 read `action_cost` generically. PASS.
- **Legacy saves:** only values changed, and items are resolved by ID at use. The save_load scenario passes.
- **Status honesty:** every partial row names its remainder. Judged against the builder-quoted finish lines.
- **Import twice:** 0 SCRIPT ERROR.
- **Logic suite:** 6416/0 at the head, as the builder claimed. 6417/0 with the reviewer stress assert.
- **Scenarios:** shop, save_load and combat_resolution all pass, with 0 SCRIPT ERROR.

## Reviewer commit
- Added a stress assert covering the greater and superior healing Bonus Action and the Potion of Poison 4d6 poison damage.

## Restack note
When this branch is rebased onto #67's a3e808d, it picks up docs/audits/.gdignore. That stops the spell-inventory.csv translation import. The combined logic count becomes 6418.
