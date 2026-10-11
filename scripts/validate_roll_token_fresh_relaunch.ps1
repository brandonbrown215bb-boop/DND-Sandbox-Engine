[CmdletBinding()]
param(
    [Parameter(Position = 0)][string]$GodotPath
)

$ErrorActionPreference = "Stop"
$Project = Split-Path -Parent $PSScriptRoot
$runnerPathValue = $env:Path
[Environment]::SetEnvironmentVariable("PATH", $null, "Process")
[Environment]::SetEnvironmentVariable("Path", $runnerPathValue, "Process")

if ([string]::IsNullOrWhiteSpace($GodotPath)) { $GodotPath = $env:GODOT_BIN }
if ([string]::IsNullOrWhiteSpace($GodotPath)) {
    $defaultCandidate = "C:\Users\brand\Downloads\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64_console.exe"
    if (Test-Path -LiteralPath $defaultCandidate -PathType Leaf) {
        $GodotPath = $defaultCandidate
    }
}
if ([string]::IsNullOrWhiteSpace($GodotPath)) { throw "Pass Godot 4.7 console executable or set GODOT_BIN." }
if (-not (Test-Path -LiteralPath $GodotPath -PathType Leaf)) { throw "Godot executable not found: $GodotPath" }

$runRoot = Join-Path $Project (".artifacts\tests\roll-token-relaunch-" + [guid]::NewGuid().ToString("N"))
$userData = Join-Path $runRoot "user-data"
$prepareOut = Join-Path $runRoot "prepare.stdout.log"
$prepareErr = Join-Path $runRoot "prepare.stderr.log"
$recoverOut = Join-Path $runRoot "recover.stdout.log"
$recoverErr = Join-Path $runRoot "recover.stderr.log"
New-Item -ItemType Directory -Force -Path $userData | Out-Null

$previousAppData = $env:APPDATA
$previousLocalAppData = $env:LOCALAPPDATA
$previousPhase = $env:ROLL_TOKEN_RELAUNCH_PHASE
$env:APPDATA = $userData
$env:LOCALAPPDATA = $userData
$env:ROLL_TOKEN_RELAUNCH_PHASE = "prepare"
$arguments = @("--headless", "--path", ('"' + $Project + '"'), "res://scenes/roll_token_fresh_relaunch.tscn")
try {
    $prepare = Start-Process -FilePath $GodotPath -WorkingDirectory $Project -ArgumentList $arguments `
        -RedirectStandardOutput $prepareOut -RedirectStandardError $prepareErr -WindowStyle Hidden -PassThru
    $preparePid = $prepare.Id
    $prepareDeadline = [DateTime]::UtcNow.AddSeconds(60)
    while (-not $prepare.WaitForExit(100) -and [DateTime]::UtcNow -lt $prepareDeadline) {
        if (Test-Path -LiteralPath $prepareErr) {
            $errNow = Get-Content -Raw -LiteralPath $prepareErr
            if ($errNow -match "SCRIPT ERROR|Parse Error|Compile Error|\[RollTokenFreshRelaunchProbe\]") {
                Stop-Process -Id $prepare.Id -Force -ErrorAction SilentlyContinue
                throw "Roll token fresh-relaunch prepare phase emitted script or probe errors. See $prepareOut and $prepareErr"
            }
        }
    }
    if (-not $prepare.HasExited) {
        Stop-Process -Id $prepare.Id -Force -ErrorAction SilentlyContinue
        throw "Roll token fresh-relaunch prepare phase timed out after 60s. See $prepareOut and $prepareErr"
    }
    $prepare.WaitForExit()
    $prepareText = ""
    if (Test-Path -LiteralPath $prepareOut) { $prepareText += Get-Content -Raw -LiteralPath $prepareOut }
    if (Test-Path -LiteralPath $prepareErr) { $prepareText += "`n" + (Get-Content -Raw -LiteralPath $prepareErr) }
    if ($null -ne $prepare.ExitCode -and $prepare.ExitCode -ne 0) {
        throw "Roll token fresh-relaunch prepare phase exited with code $($prepare.ExitCode). See $prepareOut and $prepareErr"
    }
    if ($prepareText -match "SCRIPT ERROR|Parse Error|Compile Error|\[RollTokenFreshRelaunchProbe\]") {
        throw "Roll token fresh-relaunch prepare phase emitted script or probe errors. See $prepareOut and $prepareErr"
    }
    if ($prepareText -notmatch "ROLL TOKEN FRESH PREPARED:") {
        throw "Roll token fresh-relaunch prepare phase did not commit. See $prepareOut and $prepareErr"
    }

    $env:ROLL_TOKEN_RELAUNCH_PHASE = "recover"
    $recover = Start-Process -FilePath $GodotPath -WorkingDirectory $Project -ArgumentList $arguments `
        -RedirectStandardOutput $recoverOut -RedirectStandardError $recoverErr -WindowStyle Hidden -PassThru
    $recoverPid = $recover.Id
    $recoverDeadline = [DateTime]::UtcNow.AddSeconds(60)
    while (-not $recover.WaitForExit(100) -and [DateTime]::UtcNow -lt $recoverDeadline) {
        if (Test-Path -LiteralPath $recoverErr) {
            $errNow = Get-Content -Raw -LiteralPath $recoverErr
            if ($errNow -match "SCRIPT ERROR|Parse Error|Compile Error|\[RollTokenFreshRelaunchProbe\]") {
                Stop-Process -Id $recover.Id -Force -ErrorAction SilentlyContinue
                throw "Roll token fresh-relaunch recover phase emitted script or probe errors. See $recoverOut and $recoverErr"
            }
        }
    }
    if (-not $recover.HasExited) {
        Stop-Process -Id $recover.Id -Force -ErrorAction SilentlyContinue
        throw "Roll token fresh-relaunch recover phase timed out after 60s. See $recoverOut and $recoverErr"
    }
    $recover.WaitForExit()
    $recoverText = ""
    if (Test-Path -LiteralPath $recoverOut) { $recoverText += Get-Content -Raw -LiteralPath $recoverOut }
    if (Test-Path -LiteralPath $recoverErr) { $recoverText += "`n" + (Get-Content -Raw -LiteralPath $recoverErr) }
    if ($null -ne $recover.ExitCode -and $recover.ExitCode -ne 0) {
        throw "Roll token fresh-relaunch recover phase exited with code $($recover.ExitCode). See $recoverOut and $recoverErr"
    }
    if ($recoverText -match "SCRIPT ERROR|Parse Error|Compile Error|\[RollTokenFreshRelaunchProbe\]") {
        throw "Roll token fresh-relaunch recover phase emitted script or probe errors. See $recoverOut and $recoverErr"
    }
    if ($recoverText -notmatch "ROLL TOKEN FRESH RELAUNCH PASSED:") {
        throw "Roll token fresh-relaunch recovery did not emit its success marker. See $recoverOut and $recoverErr"
    }
    if ($preparePid -eq $recoverPid) {
        throw "Prepare and recover processes unexpectedly reported identical PID $preparePid"
    }
} finally {
    $env:APPDATA = $previousAppData
    $env:LOCALAPPDATA = $previousLocalAppData
    if ($null -eq $previousPhase) { Remove-Item Env:ROLL_TOKEN_RELAUNCH_PHASE -ErrorAction SilentlyContinue } else { $env:ROLL_TOKEN_RELAUNCH_PHASE = $previousPhase }
}

Write-Output "ROLL TOKEN FRESH RELAUNCH PASSED"
Write-Output "RUN_ROOT=$runRoot"
Write-Output "PREPARE_PID=$preparePid"
Write-Output "RECOVER_PID=$recoverPid"
$prepareText -split "`r?`n" | Where-Object { $_ -match "ROLL TOKEN" }
$recoverText -split "`r?`n" | Where-Object { $_ -match "ROLL TOKEN" }
