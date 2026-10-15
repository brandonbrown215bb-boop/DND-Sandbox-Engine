# Validation

The supported developer loop is the Windows runner (historically Gate 1).
It runs project-context parsing,
production boot, the fast logic suite, and each named viewport scenario in a
fresh Godot process with a timeout, result marker, captured log, and isolated
save/settings data root.

The Windows runner first performs a recovery-mode editor scan, so the same
command works before a clean checkout has generated its ignored `.godot`
class/import caches. Recovery mode keeps editor plugins out of that bootstrap.

## Windows (supported gate)

The runner uses explicit `-GodotPath`, then `GODOT_BIN`, then the existing
project-local `.artifacts/tools/godot/Godot_v4.7-stable_win64_console.exe`, then
`godot`/`godot4` on PATH. It prints the resolved absolute path. Fresh chats on
this host do not need an environment variable or PATH change. An invalid explicit
path/environment override remains an error. The portable engine is ignored host
tooling, so another checkout must supply its own existing executable.

```powershell
$env:GODOT_BIN = 'C:\path\to\Godot_v4.7-stable_win64_console.exe'
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\run_tests.ps1
```

Before a shipping checkpoint, run the clone-equivalent clean-tree validation
from the repository root. It copies the current source tree without `.git`,
Godot import/editor caches, Codex state, saves, or build outputs, then runs the
full Windows gate from that copy:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate_clean_copy.ps1 `
  'C:\path\to\Godot_v4.7-stable_win64_console.exe'
```

The script prints the retained clean-copy path so a failed run can be inspected.
It is clone-equivalent evidence for an uncommitted worktree; a true fresh-clone
run remains required after the source is published. Use the
[true fresh-clone checklist](fresh_clone_validation.md) for that publication
check.

The runner also accepts the portable executable as its first argument. It redirects
`APPDATA` and `LOCALAPPDATA` to a
disposable per-scenario directory while Godot runs.

## Shell compatibility

```bash
GODOT_BIN=/path/to/godot bash ./run_tests.sh
```

The shell runner is retained for compatible environments and uses per-scenario
`XDG_*` data, config, cache, and state roots. It is not a supported-host Gate 1
requirement and native Linux execution is not required evidence. Set
`TEST_LOG_DIR` to retain logs at a chosen location; otherwise logs are created
under the operating system temporary directory.

## Targeted controls

```powershell
$env:PARSE_TIMEOUT_SECONDS = '10'
$env:SCENARIO_TIMEOUT_SECONDS = '1'
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\run_tests.ps1
```

For focused work, pass `-Suite logic` or `-Suite integration` to the
PowerShell runner. The compatibility shell runner accepts the matching
`TEST_SUITE=logic` or `TEST_SUITE=integration` environment variable.
`all` runs the complete current manifest. Fixed-seed campaign smoke is one
bounded integration scenario; old gate ownership does not certify full Crown
readiness or choose the current implementation priority.

A missing marker, assertion failure, unexpected Godot error, non-zero process
exit, or timeout fails the owning case. The Windows Godot build used on this
host emits `Failed to read the root certificate store`; that exact platform
warning is allowlisted. Test-owned leaks, resource errors, parse errors, and
generic `ERROR:` output are not allowlisted.
