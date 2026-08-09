# Gate 1 evidence

Gate 1 is complete. The test result is trustworthy for the current named
contracts: project-context parsing, production boot, isolated scenarios,
bounded timeouts, result markers, disposable persistence roots, and unexpected
engine errors treated as failures.

## Validation environment

- Engine: `Godot 4.7.stable.official.5b4e0cb0f`
- Project: Godot 4.7, GL Compatibility
- DataLoader: 14 classes, 9 races, 232 items, 198 spells, 453 monsters, 4 event tables, 1 campaign
- Parse gate: 51 scripts loaded
- Supported Windows runner: `run_tests.ps1`
- Compatibility-only shell runner: `run_tests.sh` (not Gate 1 evidence)

## Full Windows run

The portable executable was supplied as the runner argument. The completed run
returned exit code `0`. Per-case logs were written to the runner-owned temporary
directory; the durable evidence is the enumerated result below.

| Check | Result |
|---|---|
| Project-context parse | Pass - `PARSE GATE PASSED: 51 scripts loaded` |
| Production boot | Pass - `BOOT GATE PASSED: main scene settled for 3.0 seconds` |
| Logic suite | Pass - `263 passed, 0 failed` |
| `combat` | Pass |
| `combat_ai_loop` | Pass |
| `combat_victory` | Pass |
| `overworld` | Pass |
| `main_menu_load` | Pass |
| `dungeon` | Pass |
| `event_dialog` | Pass |
| `character_creation` | Pass |
| `shop` | Pass |
| `save_load` | Pass |
| `combat_resolution` | Pass |
| `event_choice_resolution` | Pass |
| `event_dialog_choice_click` | Pass |
| `character_sheet` | Pass |
| Overall runner | Pass - `OVERALL: ALL TESTS PASSED`, exit `0` |

Each scenario ran in its own Godot process. Windows `APPDATA` and
`LOCALAPPDATA` were redirected to disposable per-scenario roots; the shell
runner uses disposable `XDG_*` roots for the same contract.

## Failure controls exercised

- The parse gate loads scripts from a running project scene, so autoload and
  `class_name` dependencies resolve in project context. A missing script load
  is reported as a parse-gate failure.
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

`DONE`. The current 263-assertion logic suite remains green. The earlier
242-assertion note was stale, and the random-hit assertion was made
deterministic so the reported count is stable. All named scenarios have pass
markers, and no unexplained Godot error remains in the full run.
