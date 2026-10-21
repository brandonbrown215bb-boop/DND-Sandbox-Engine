# Harness: fail on unparseable check files (card Q-20261020-122658-cafa)

Base: #16-#19 open, so stacked on `batch-050-playtest-fixes` @ a5d56c6.

## Change
- `CheckScriptGate` (src/check_script_gate.gd): finds every `XxxChecks` class the logic runner names in its own source, resolves its path from the global class list, loads it, and fails any that is missing or cannot instantiate (parse/compile failure).
- `test_runner.gd` runs the gate first: each bad script is an `[FAIL] check script X failed to parse or compile`, so RESULTS shows failures, TESTS FAILED prints and the exit code is 1. It prints `CHECK SCRIPT GATE: N registered check scripts, M failed`.
- `run_tests.sh` / `run_tests.ps1`: the logic case also requires `CHECK SCRIPT GATE: … 0 failed` in the log, so a runner that never reached the gate (for example the runner itself failing to compile and hanging until timeout) is reported red with a named reason.

## Regression
- `_test_check_script_gate`: a simulated load failure (null) and an uncompiled GDScript with broken source (never reloaded, so no engine error is printed) both fail the gate; a good script passes; the live runner registers 45 classes. No broken file is committed.
- Manual proof (not committed): a type error appended to batch_050_checks.gd → runner `RESULTS: 5413 passed, 2 failed`, exit 1, wrapper OVERALL FAILED. A hard syntax error → runner cannot start; the wrapper times out and fails on the missing gate line.

## Counts
- a5d56c6 baseline 5437/0 → 5440/0 (+3). `TEST_SUITE=logic bash run_tests.sh` OVERALL ALL TESTS PASSED.

## Limit
- When the runner script itself cannot compile, the standalone scene still idles until the wrapper timeout. The wrappers fail loudly; a bare `godot … test_runner.tscn` run does not exit by itself.
