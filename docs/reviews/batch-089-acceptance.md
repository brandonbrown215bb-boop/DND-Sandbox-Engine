# Batch 089 Acceptance — Spell data corrections (PR #67)

Reviewer: Runtime Reviewer · Head reviewed: bbe3a91 · Verdict: **ACCEPTED (partial, as labelled)**

## SRD 5.2.1 spot checks (srd.txt)
| Row/spell | SRD line | Result |
|---|---|---|
| Command (no creature-type exclusion; WIS; +1 target/slot) | 7144ff | PASS — no Undead exclusion in 5.2.1 text |
| Lesser Restoration bonus action | 9106 | PASS |
| Slow WIS, up to six | 10358 | PASS (40-ft Cube noted partial) |
| Wind Wall STR 4d8 Bludgeoning half | 11129 | PASS |
| Flame Strike 5d6 Fire + 5d6 Radiant DEX | 8218 | PASS |
| Earthquake Prone, no base damage | 7862 | PASS (D-40 partial) |
| Prismatic Wall Blinded on CON | 9839 | PASS (layers BLOCKED) |
| Storm of Vengeance 2d6 Thunder + Deafened | 10538 | PASS |
| Clairvoyance 10 minutes, 1 mile | 7047 | PASS |
| Enthrall concentration | 7932 | PASS |
| Calm Emotions CHA | 6954 | PASS |
| Transport via Plants | 10830 | PASS |
| Phantasmal Force 2d8 Psychic | 9620 | PASS |

## Checks
- ADR-0018: no src change outside test_runner.gd; no per-ID native branches. PASS.
- Legacy saves: values only, no field renames. save_load scenario passes. PASS.
- D-09 revert: no class JSON in diff; conflict with test_runner.gd:675 counts and data_loader.gd:26 CURATED_SPELL_ACCESS is real. BLOCKED is accurate.
- Command test (test_runner.gd:2119): still asserts WIS save, V component, upcast target, failed-save resolution. Not gutted.
- Status honesty (builder-quoted finish lines): FIXED-partial / BLOCKED rows state their remainders. No overclaim found.
- Import ×2 headless: 0 SCRIPT ERROR. Logic: 6415/0 at head; 6416/0 with reviewer stress assert.
- Scenarios shared_spell_flow, combat_resolution, save_load: PASS, 0 SCRIPT ERROR.

## Reviewer commit
- Defect: new docs/audits/spell-inventory.csv was imported by Godot as a csv_translation, generating 10 untracked `.translation` files plus a `.import` on every import. Fixed by adding docs/audits/.gdignore.
- Added a stress assert (Slow, Wind Wall, Storm of Vengeance, Earthquake, Command).

## Non-blocking notes
- earthquake has no area_radius (100 ft = 20 hexes); this predates the PR.
- wind_wall target is still "single" (it's a wall shape).

## Proposed counts
Registry/checkpoint: Batch 089 accepted-partial; logic baseline 6416. Note for #68: its builder count of 6416 becomes 6417 after a restack.
