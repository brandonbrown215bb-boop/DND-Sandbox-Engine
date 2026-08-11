# True fresh-clone validation

This is the Gate 8 publication check. It is different from
`scripts/validate_clean_copy.ps1`: the clean-copy script is useful evidence for
an uncommitted worktree, but it is not proof that the published repository can
be cloned and run without workstation state.

## Required inputs

- A published repository URL and the exact candidate commit SHA.
- A portable Godot 4.7.x console executable outside the clone.
- A new clone directory and a separate temporary directory for captured logs.
- No pre-existing Godot profile, save directory, editor cache, or Codex state
  copied into the clone.

## Procedure

Run from a PowerShell session that has not changed the repository under test:

```powershell
$candidateUrl = 'https://example.invalid/owner/repository.git'
$candidateSha = '<published-commit-sha>'
$cloneRoot = Join-Path $env:TEMP ('top-down-party-game-fresh-' + [guid]::NewGuid().ToString('N'))
$logRoot = Join-Path $env:TEMP ('top-down-party-game-fresh-logs-' + [guid]::NewGuid().ToString('N'))
$godotPath = 'C:\path\to\Godot_v4.7-stable_win64_console.exe'

git clone $candidateUrl $cloneRoot
Set-Location $cloneRoot
$actualSha = (git rev-parse HEAD).Trim()
if ($actualSha -ne $candidateSha) { throw "Expected $candidateSha, got $actualSha" }

New-Item -ItemType Directory -Force -Path $logRoot | Out-Null
$godotVersion = (& $godotPath --version 2>&1 | Out-String).Trim()
$env:TEST_LOG_DIR = $logRoot
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\run_tests.ps1 $godotPath -Suite all
$exitCode = $LASTEXITCODE

[pscustomobject]@{
    PublishedSha = $actualSha
    GodotVersion = $godotVersion
    CloneRoot = $cloneRoot
    LogRoot = $logRoot
    TestExitCode = $exitCode
    Passed = ($exitCode -eq 0)
} | Format-List
if ($exitCode -ne 0) { exit $exitCode }
```

The command must be run from the clone. Do not substitute the source worktree,
`validate_clean_copy.ps1`, an editor-launched project, or a clone that already
contains `.godot`, `.import`, `saves`, `APPDATA`, or `LOCALAPPDATA` state.
`run_tests.ps1` creates disposable per-case Windows profile roots; retain the
printed log directory until the result has been reviewed.

## Evidence to record

Record the candidate URL, exact SHA, Godot version, clone path, log path, full
command, exit code, named scenario markers, and any warnings. The supported
certificate-store warning may be present; generic Godot errors, parse errors,
resource errors, missing markers, timeouts, and non-zero exits fail the check.
Confirm that the full run includes `crown_smoke`, the composition scenarios,
fresh-save boundaries, defeat/completion, and the complete Gate 1 matrix.

This publication checklist does not require a manual start-to-finish campaign.
If someone chooses to run the optional Crown sampler or a friend run, record any
developer intervention or player-facing gap as a focused defect.
