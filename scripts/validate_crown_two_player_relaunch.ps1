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
if ([string]::IsNullOrWhiteSpace($GodotPath)) { throw "Pass Godot 4.7 console executable or set GODOT_BIN." }
if (-not (Test-Path -LiteralPath $GodotPath -PathType Leaf)) { throw "Godot executable not found: $GodotPath" }

$runRoot = Join-Path ([IO.Path]::GetTempPath()) ("top-down-party-game-crown-two-player-" + [guid]::NewGuid().ToString("N"))
$userData = Join-Path $runRoot "user-data"
$prepareOut = Join-Path $runRoot "prepare.stdout.log"
$prepareErr = Join-Path $runRoot "prepare.stderr.log"
$recoverOut = Join-Path $runRoot "recover.stdout.log"
$recoverErr = Join-Path $runRoot "recover.stderr.log"
New-Item -ItemType Directory -Force -Path $userData | Out-Null

$previousAppData = $env:APPDATA
$previousLocalAppData = $env:LOCALAPPDATA
$previousPhase = $env:CROWN_TWO_PLAYER_PHASE
$env:APPDATA = $userData
$env:LOCALAPPDATA = $userData
$env:CROWN_TWO_PLAYER_PHASE = "prepare"
$arguments = @("--headless", "--path", ('"' + $Project + '"'), "--script", "res://src/crown_two_player_relaunch_probe.gd")
try {
    $prepare = Start-Process -FilePath $GodotPath -WorkingDirectory $Project -ArgumentList $arguments `
        -RedirectStandardOutput $prepareOut -RedirectStandardError $prepareErr -WindowStyle Hidden -PassThru
    $prepareDeadline = [DateTime]::UtcNow.AddSeconds(60)
    $prepareText = ""
    while ([DateTime]::UtcNow -lt $prepareDeadline -and $prepareText -notmatch "CROWN TWO-PLAYER PREPARED:") {
        Start-Sleep -Milliseconds 100
        if (Test-Path -LiteralPath $prepareOut) { $prepareText = Get-Content -Raw -LiteralPath $prepareOut }
        if (Test-Path -LiteralPath $prepareErr) { $prepareText += Get-Content -Raw -LiteralPath $prepareErr }
    }
    if ($prepareText -notmatch "CROWN TWO-PLAYER PREPARED:") {
        if (-not $prepare.HasExited) { Stop-Process -Id $prepare.Id -Force -ErrorAction SilentlyContinue }
        throw "Two-player Crown prepare phase did not commit. See $prepareOut and $prepareErr"
    }
    if (-not $prepare.HasExited) { Stop-Process -Id $prepare.Id -Force -ErrorAction SilentlyContinue }

    $env:CROWN_TWO_PLAYER_PHASE = "recover"
    $recover = Start-Process -FilePath $GodotPath -WorkingDirectory $Project -ArgumentList $arguments `
        -RedirectStandardOutput $recoverOut -RedirectStandardError $recoverErr -WindowStyle Hidden -PassThru
    $recoveryDeadline = [DateTime]::UtcNow.AddSeconds(60)
    $recoverText = ""
    while ([DateTime]::UtcNow -lt $recoveryDeadline -and $recoverText -notmatch "CROWN TWO-PLAYER RELAUNCH PASSED:") {
        Start-Sleep -Milliseconds 100
        if (Test-Path -LiteralPath $recoverOut) { $recoverText = Get-Content -Raw -LiteralPath $recoverOut }
        if (Test-Path -LiteralPath $recoverErr) { $recoverText += Get-Content -Raw -LiteralPath $recoverErr }
    }
    if ($recoverText -notmatch "CROWN TWO-PLAYER RELAUNCH PASSED:") {
        if (-not $recover.HasExited) { Stop-Process -Id $recover.Id -Force -ErrorAction SilentlyContinue }
        throw "Two-player Crown recovery did not emit its success marker. See $recoverOut and $recoverErr"
    }
    if (-not $recover.HasExited) { Stop-Process -Id $recover.Id -Force -ErrorAction SilentlyContinue }
} finally {
    $env:APPDATA = $previousAppData
    $env:LOCALAPPDATA = $previousLocalAppData
    if ($null -eq $previousPhase) { Remove-Item Env:CROWN_TWO_PLAYER_PHASE -ErrorAction SilentlyContinue } else { $env:CROWN_TWO_PLAYER_PHASE = $previousPhase }
}

Write-Output "CROWN TWO-PLAYER RELAUNCH PASSED"
Write-Output "RUN_ROOT=$runRoot"
$recoverText -split "`r?`n" | Where-Object { $_ -match "CROWN TWO-PLAYER RECOVERED|CROWN TWO-PLAYER RELAUNCH PASSED" }
