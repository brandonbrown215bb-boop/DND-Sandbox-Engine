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

$runRoot = Join-Path ([IO.Path]::GetTempPath()) ("top-down-party-game-gate3-fresh-" + [guid]::NewGuid().ToString("N"))
$userData = Join-Path $runRoot "user-data"
$prepareOut = Join-Path $runRoot "prepare.stdout.log"
$prepareErr = Join-Path $runRoot "prepare.stderr.log"
$recoverOut = Join-Path $runRoot "recover.stdout.log"
$recoverErr = Join-Path $runRoot "recover.stderr.log"
New-Item -ItemType Directory -Force -Path $userData | Out-Null

$env:APPDATA = $userData
$env:LOCALAPPDATA = $userData
$env:GATE3_PHASE = "prepare"
$arguments = @("--headless", "--path", ('"' + $Project + '"'), "--script", "res://src/fresh_relaunch_probe.gd")
$prepare = Start-Process -FilePath $GodotPath -WorkingDirectory $Project -ArgumentList $arguments `
    -RedirectStandardOutput $prepareOut -RedirectStandardError $prepareErr -WindowStyle Hidden -PassThru

$prepareDeadline = [DateTime]::UtcNow.AddSeconds(60)
$prepareText = ""
while ([DateTime]::UtcNow -lt $prepareDeadline -and $prepareText -notmatch "FRESH PREPARED:") {
    Start-Sleep -Milliseconds 100
    if (Test-Path -LiteralPath $prepareOut) { $prepareText = Get-Content -Raw -LiteralPath $prepareOut }
    if (Test-Path -LiteralPath $prepareErr) { $prepareText += Get-Content -Raw -LiteralPath $prepareErr }
}
if ($prepareText -notmatch "FRESH PREPARED:") {
    if (-not $prepare.HasExited) { Stop-Process -Id $prepare.Id -Force -ErrorAction SilentlyContinue }
    throw "Fresh-relaunch prepare phase did not commit. See $prepareOut and $prepareErr"
}

# The prepare probe is intentionally held open so the host can terminate it
# before launching recovery in a separate process.
if (-not $prepare.HasExited) {
    Stop-Process -Id $prepare.Id -Force -ErrorAction SilentlyContinue
}
$savePath = Join-Path $userData "Godot\app_userdata\Top Down Party Game\saves\dnd2024\gate3_fresh_relaunch.sav"
if (-not (Test-Path -LiteralPath $savePath -PathType Leaf)) {
    $savePath = Get-ChildItem -LiteralPath $userData -File -Recurse -Filter "gate3_fresh_relaunch.sav" -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty FullName
}
if ([string]::IsNullOrWhiteSpace($savePath) -or -not (Test-Path -LiteralPath $savePath -PathType Leaf)) {
    throw "Fresh-relaunch save was not found under $userData"
}

$env:GATE3_PHASE = "recover"
$recover = Start-Process -FilePath $GodotPath -WorkingDirectory $Project -ArgumentList $arguments `
    -RedirectStandardOutput $recoverOut -RedirectStandardError $recoverErr -WindowStyle Hidden -PassThru
$recoveryDeadline = [DateTime]::UtcNow.AddSeconds(60)
$recoverText = ""
while ([DateTime]::UtcNow -lt $recoveryDeadline -and $recoverText -notmatch "FRESH RELAUNCH PASSED:") {
    Start-Sleep -Milliseconds 100
    if (Test-Path -LiteralPath $recoverOut) { $recoverText = Get-Content -Raw -LiteralPath $recoverOut }
    if (Test-Path -LiteralPath $recoverErr) { $recoverText += Get-Content -Raw -LiteralPath $recoverErr }
}
if ($recoverText -notmatch "FRESH RELAUNCH PASSED:") {
    if (-not $recover.HasExited) { Stop-Process -Id $recover.Id -Force -ErrorAction SilentlyContinue }
    throw "Fresh-relaunch recovery did not emit its success marker. See $recoverOut and $recoverErr"
}
if (-not $recover.HasExited) {
    Stop-Process -Id $recover.Id -Force -ErrorAction SilentlyContinue
}

Write-Output "FRESH RELAUNCH PASSED"
Write-Output "RUN_ROOT=$runRoot"
$recoverText -split "`r?`n" | Where-Object { $_ -match "RECOVERED_|FRESH RELAUNCH PASSED" }
