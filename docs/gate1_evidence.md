# Gate 1 evidence

> Historical snapshot, not current priority or acceptance. See the
> [documentation map](README.md) for current authority. Findings, counts,
> gate decisions and execution orders below apply to the dated snapshot;
> reproduce relevant behavior before reopening a defect or reusing a claim.

Historical recovery evidence. See [current checkpoint](operations/current.md)
for the supported source revision and latest validation; counts below are dated.

Gate 1 was complete at the historical 521-assertion baseline. Project-context
parsing, production boot, isolated scenarios, bounded timeouts, result markers,
disposable persistence roots, and unexpected engine-error handling all pass.
The Bardic Inspiration fixture now seeds only its test input while keeping the
production attack and reaction path intact.

## Historical working-tree validation (2026-08-10)

Two consecutive complete Windows runs against
`Godot 4.7.stable.official.5b4e0cb0f` produced the same result:

| Run | Result |
|---|---|
| 1 | Bootstrap, parse, boot, `521 passed, 0 failed`, all 17 integration scenarios, and `OVERALL: ALL TESTS PASSED`; exit `0`. |
| 2 | Same result: bootstrap, parse, boot, `521 passed, 0 failed`, all 17 integration scenarios, and `OVERALL: ALL TESTS PASSED`; exit `0`. |

The fixed fixture seeds the global d20 immediately before the attack, keeps the
target AC at `0`, and still calls `CombatAction.resolve_weapon_attack` with the
optional Bardic Inspiration reaction enabled. It therefore proves grant,
optional spend, bonus application, and die removal without allowing a natural 1
to bypass the reaction.

## Validation environment

- Engine: `Godot 4.7.stable.official.5b4e0cb0f`
- Project: Godot 4.7, GL Compatibility
- DataLoader: 14 classes, 9 races, 233 items, 198 spells, 453 monsters, 4 event tables, 1 campaign
- Cache-free project bootstrap: pass
- Parse gate: 56 scripts loaded
- Supported Windows runner: `run_tests.ps1`
- Compatibility-only shell runner: `run_tests.sh` (not Gate 1 evidence)

## Full Windows run

The portable executable was supplied as the runner argument. The completed run
returned exit code `0`. Per-case logs were written to the runner-owned temporary
directory; the durable evidence is the enumerated result below.

| Check | Result |
|---|---|
| Cache-free project bootstrap | Pass - `PROJECT BOOTSTRAP PASSED` |
| Project-context parse | Pass - `PARSE GATE PASSED: 56 scripts loaded` |
| Production boot | Pass - `BOOT GATE PASSED: main scene settled for 3.0 seconds` |
| Logic suite | Pass - `521 passed, 0 failed` on both runs |
| Integration scenarios | Pass on both runs - `combat`, `party_combat`, `crown_smoke`, `combat_ai_loop`, `combat_victory`, `combat_defeat`, `overworld`, `main_menu_load`, `dungeon`, `event_dialog`, `character_creation`, `shop`, `save_load`, `combat_resolution`, `event_choice_resolution`, `event_dialog_choice_click`, `character_sheet` |
| Overall runner | Pass on both runs - `OVERALL: ALL TESTS PASSED`, exit `0` |

Each scenario ran in its own Godot process. Windows `APPDATA` and
`LOCALAPPDATA` were redirected to disposable per-scenario roots; the shell
runner uses disposable `XDG_*` roots for the same contract.

## Failure controls exercised

- The parse gate loads scripts from a running project scene, so autoload and
  `class_name` dependencies resolve in project context. A missing script load
  is reported as a parse-gate failure.
- Before parsing, a recovery-mode editor scan creates the ignored `.godot`
  class-name and import caches required by a first run. Editor plugins remain
  disabled during this bootstrap, and the step has its own timeout and marker.
- Every case has a hard timeout and explicit marker. A timeout is a failure;
  the runner continues enumerating later cases and reports their markers.
- The Windows helper owns raw Godot stream capture and propagates Godot's real
  exit code. This avoids the null `Process.ExitCode` produced by Windows
  PowerShell 5 when `Start-Process` also owns output redirection.
- On Windows, timeout cleanup terminates the console wrapper and its child
  process tree so a timed-out case cannot leave an orphaned Godot process.
- Generic Godot `ERROR:` output, parse errors, invalid calls, leaked test-owned
  nodes, and resource errors fail a case.
- The host emits `Failed to read the root certificate store`; that exact
  platform warning is the only allowlisted error line. The intentionally
  negative inventory and missing-event checks emit warnings, not errors.

## Decision

`DONE` for the working tree reviewed on that date. The focused logic suite passed three
consecutive times, and the complete supported Windows runner passed twice with
every named scenario and exit code `0`.
