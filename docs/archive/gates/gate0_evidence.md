# Gate 0 evidence

> **Archived material.** This preserves a past snapshot, not current instructions.
> Read the [current checkpoint](../../operations/current.md) and [roadmap](../../../roadmap.md) before acting.


> Historical snapshot, not current priority or acceptance. See the
> [documentation map](../../README.md) for current authority. Findings, counts,
> gate decisions and execution orders below apply to the dated snapshot;
> reproduce relevant behavior before reopening a defect or reusing a claim.

## Baseline

- Repository HEAD at validation start: `11e70321ad14`
- Engine: `Godot 4.7.stable.official.5b4e0cb0f`
- Project feature setting: Godot 4.7, GL Compatibility
- DataLoader: 14 classes, 9 races, 232 items, 198 spells, 453 monsters, 4 event tables, 1 campaign
- Parse gate: 51 source scripts loaded
- Logic suite: 242 passed, 0 assertion failures; engine teardown errors remain

## Commands

```powershell
python src/generate_feature_matrix.py
$env:GODOT_BIN = 'C:\path\to\Godot_v4.7-stable_win64_console.exe'
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\run_tests.ps1
```

The portable executable path above is illustrative. The runner accepts `GODOT_BIN`, an explicit argument, or `godot`/`godot4` on `PATH`; no developer-specific path is required by the repository.

## Gate results

| Check | Result |
|---|---|
| Parse gate | Pass — `PARSE GATE PASSED: 51 scripts loaded` |
| Production boot | Pass — `BOOT GATE PASSED: main scene settled for 3.0 seconds` |
| Logic assertions | Pass — 242 passed, 0 failed |
| Fresh viewport processes | Pass for `combat`, `combat_ai_loop`, `overworld`, `dungeon`, `event_dialog`, `character_creation`, `shop`, `combat_resolution`, `event_choice_resolution`, `event_dialog_choice_click`, and `character_sheet` assertions |
| `combat_victory` | Fail — timed out after 20 seconds during overworld bootstrap |
| `main_menu_load` | Fail — Load button remained disabled with a saved quicksave |
| `save_load` | Fail — harness expected a load from a `MAIN_MENU` save that SaveManager rejected as non-resumable |
| Engine hygiene | Fail — logic resource leaks; character-sheet add-child race and RID leaks |

The Windows host warning `Failed to read the root certificate store` is allowlisted as environment noise. Generic engine errors, leak/resource messages, timeouts, missing markers, and failed assertions are not allowlisted.

Disposable runner logs stay in the OS temporary directory unless `TEST_LOG_DIR`
is explicitly set. The tracked `dogfood-output/` screenshots are intentional
fixtures; Godot's `.godot/` cache and local `.vscode/` configuration are
ignored and are not evidence. The obsolete root-level `combat_err.txt` and
`vp_err.txt` diagnostics were removed and are ignored if recreated.

## Decision

`DONE`. Gate 0 inventory is complete: the feature matrix, Crown band, and confirmed defect register are reproducible and linked from the repository documentation. The campaign is not claimed complete; the remaining open P0/P1 defects remain owned work for later gates.
