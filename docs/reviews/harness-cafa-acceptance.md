# Harness gate acceptance (card Q-20261020-122658-cafa, PR #20)

**Verdict: ACCEPT after R1 and R2.** Reviewer: runtime-reviewer, worktree /tmp/rev_wt020, builder head 70ba454. The review commits follow this doc.

The builder's gate alone did not meet the card. A runtime error in a check still produced "ALL TESTS PASSED" from the runner, and a parse error or missing file cost a 5-minute hang.

## Injection matrix (Linux, Godot 4.7.2, scratch edits never committed, one run at a time)
| Injection | 70ba454 (builder) | Review head |
|---|---|---|
| Green | 5440/0, runner exit 0, wrapper exit 0, OVERALL PASSED | 5441/0, exit 0, OVERALL PASSED |
| Parse error (`func broken(:` appended to batch_050_checks.gd) | parse_gate FAILED, then **logic hung 300 s**; wrapper exit 1 after **321 s** | parse_gate FAILED, wrapper stops; exit 1 in **15 s** |
| Missing check file (review_050_checks.gd removed) | the same, because test_runner.gd stops compiling: exit 1 after **321 s** | exit 1 in **15 s** |
| Runtime error in `Batch050Checks.run` init (`null.explode()`) | runner printed **"RESULTS: 5418 passed, 0 failed / ALL TESTS PASSED"**, Godot exit 0, 22 checks silently dropped. Only the wrapper's log grep turned it red. | runner `[FAIL] 1 SCRIPT ERROR(s) ... batch_050_checks.gd:32`, RESULTS 5419/1, TESTS FAILED, Godot exit 1, OVERALL FAILED |

## Defects
- **R1: a runtime error in a check still reported a pass from the runner.** A SCRIPT ERROR aborts that check function and drops the rest of the group. The runner counts only the asserts that ran, so it printed ALL TESTS PASSED and exited 0. That is the card's exact symptom, moved from parse time to run time. CheckScriptGate tests only `can_instantiate()`, so it cannot see this. Any direct runner use (CI wrappers that check the exit code only, `--logic-groups` runs, a bare Godot invocation) was fooled.
  - Fix: `ScriptErrorCounter` (a Godot 4.5+ `Logger`), registered with `OS.add_logger` at runner start. `_report` turns any SCRIPT ERROR into a failure that names the first one.
  - A regression check feeds the logger one engine error and one script error and expects a count of 1.
  - The green run has 0 SCRIPT ERROR, so nothing legitimate trips it.
- **R2: the known hang was 300 s (LOGIC_TIMEOUT_SECONDS) on every parse error or missing check file.** parse_gate had already failed in about 15 s, but `run_tests.sh` went on to launch a runner that could not compile. `run_tests.ps1` already stops after a parse_gate failure; `run_tests.sh` now does the same. That bounds the failure to the parse gate (about 15 s).
  - A bare `godot ... test_runner.tscn` with a broken runner still idles. A scene whose root script does not compile cannot quit itself, so that is not fixable in GDScript.

## Notes
- In practice, CheckScriptGate's "failed to load/parse" path is reachable only for a check file that loads but cannot instantiate while the runner still compiles. A real parse error or missing class breaks test_runner.gd itself, and the pre-existing parse_gate catches that. The gate's real value is the wrapper's required `CHECK SCRIPT GATE: N ..., 0 failed` marker, and that part is sound.
- Totals: 70ba454 is **5440/0** (confirmed; builder's claim holds). The review head is **5441/0** (+1). 0 SCRIPT ERROR.
- The branch is based on a5d56c6, not main. It merges cleanly with main ab99926, which carries a495177's +12, so expect about 5453 after merge.
- The first run after a fresh worktree `--import` can show LogPanel/grimoire_profile.tres failures, because the import segfaults before engraved-corner.svg is imported. A second `--import` clears it. This is environment-only and not caused by this PR.
- No per-ID branches. tools/content_editor untouched.

## Count updates
None (harness only).
