[CmdletBinding()]
param(
    [Parameter(Position = 0)][string]$GodotPath
)

$ErrorActionPreference = "Stop"
$Project = Split-Path -Parent $PSScriptRoot

# Windows treats PATH and Path as one environment key, while PowerShell's
# Start-Process can surface both and reject the launch. Match run_tests.ps1.
$runnerPathValue = $env:Path
[Environment]::SetEnvironmentVariable("PATH", $null, "Process")
[Environment]::SetEnvironmentVariable("Path", $runnerPathValue, "Process")

if ([string]::IsNullOrWhiteSpace($GodotPath)) { $GodotPath = $env:GODOT_BIN }
if ([string]::IsNullOrWhiteSpace($GodotPath)) { throw "Pass Godot 4.7 console executable or set GODOT_BIN." }
if (-not (Test-Path -LiteralPath $GodotPath -PathType Leaf)) { throw "Godot executable not found: $GodotPath" }

$runRoot = Join-Path ([IO.Path]::GetTempPath()) ("top-down-party-game-gate3-" + [guid]::NewGuid().ToString("N"))
$userData = Join-Path $runRoot "user-data"
$marker = Join-Path $runRoot "backup-ready.marker"
$prepareOut = Join-Path $runRoot "prepare.stdout.log"
$prepareErr = Join-Path $runRoot "prepare.stderr.log"
$recoverOut = Join-Path $runRoot "recover.stdout.log"
$recoverErr = Join-Path $runRoot "recover.stderr.log"
New-Item -ItemType Directory -Force -Path $userData | Out-Null

$env:APPDATA = $userData
$env:LOCALAPPDATA = $userData
$env:GATE3_SAVE_INTERRUPT_MARKER = $marker
$env:GATE3_SAVE_INTERRUPT_SLOT = "gate3_interrupt"
$env:GATE3_PHASE = "prepare"

$arguments = @("--headless", "--path", ('"' + $Project + '"'), "--script", "res://src/save_interruption_probe.gd")
$prepare = Start-Process -FilePath $GodotPath -WorkingDirectory $Project -ArgumentList $arguments `
    -RedirectStandardOutput $prepareOut -RedirectStandardError $prepareErr -WindowStyle Hidden -PassThru

$deadline = [DateTime]::UtcNow.AddSeconds(60)
while (-not (Test-Path -LiteralPath $marker) -and -not $prepare.HasExited -and [DateTime]::UtcNow -lt $deadline) {
    Start-Sleep -Milliseconds 50
    $prepare.Refresh()
}
if (-not (Test-Path -LiteralPath $marker)) {
    if (-not $prepare.HasExited) { Stop-Process -Id $prepare.Id -Force -ErrorAction SilentlyContinue }
    throw "Save interruption marker was not reached. See $prepareOut and $prepareErr"
}

$taskkill = Join-Path $env:SystemRoot "System32\taskkill.exe"
$kill = Start-Process -FilePath $taskkill -ArgumentList @("/PID", $prepare.Id, "/T", "/F") -WindowStyle Hidden -Wait -PassThru
$prepare.WaitForExit(5000) | Out-Null

$saveFiles = @(Get-ChildItem -LiteralPath $userData -File -Recurse -ErrorAction SilentlyContinue | Where-Object { $_.Name -like "gate3_interrupt.sav*" })
$primary = @($saveFiles | Where-Object { $_.Name -eq "gate3_interrupt.sav" })
$backup = @($saveFiles | Where-Object { $_.Name -eq "gate3_interrupt.sav.bak" })
$temp = @($saveFiles | Where-Object { $_.Name -eq "gate3_interrupt.sav.tmp" })
if ($primary.Count -ne 0 -or $backup.Count -ne 1 -or $temp.Count -ne 1) {
    throw "Unexpected interrupted save files. primary=$($primary.Count) backup=$($backup.Count) temp=$($temp.Count). Root: $userData"
}

$env:GATE3_PHASE = "recover"
Remove-Item Env:GATE3_SAVE_INTERRUPT_MARKER -ErrorAction SilentlyContinue
Remove-Item Env:GATE3_SAVE_INTERRUPT_SLOT -ErrorAction SilentlyContinue
$recover = Start-Process -FilePath $GodotPath -WorkingDirectory $Project -ArgumentList $arguments `
    -RedirectStandardOutput $recoverOut -RedirectStandardError $recoverErr -WindowStyle Hidden -PassThru
$recoveryStartTime = $recover.StartTime
$recoveryDeadline = [DateTime]::UtcNow.AddSeconds(60)
$recoverText = ""
while ([DateTime]::UtcNow -lt $recoveryDeadline -and $recoverText -notmatch "RECOVERY PASSED: prior valid backup restored in a fresh process") {
    Start-Sleep -Milliseconds 100
    $recover.Refresh()
    if (Test-Path -LiteralPath $recoverOut) { $recoverText = Get-Content -Raw -LiteralPath $recoverOut }
    if (Test-Path -LiteralPath $recoverErr) { $recoverText += Get-Content -Raw -LiteralPath $recoverErr }
}
if ($recoverText -notmatch "RECOVERY PASSED: prior valid backup restored in a fresh process") {
    $recover.Refresh()
    if (-not $recover.HasExited) { Stop-Process -Id $recover.Id -Force -ErrorAction SilentlyContinue }
    throw "Recovery failed to emit its success marker. See $recoverOut and $recoverErr"
}
$recover.Refresh()
if (-not $recover.HasExited) {
    # Godot's Windows console build can leave a paired GUI process behind
    # after SceneTree.quit(). Fire the exact process-tree kill asynchronously,
    # then clean up only Godot instances from this run if the pair lingers.
    Start-Process -FilePath $taskkill -ArgumentList @("/PID", $recover.Id, "/T", "/F") -WindowStyle Hidden | Out-Null
    $cleanupDeadline = [DateTime]::UtcNow.AddSeconds(5)
    while ([DateTime]::UtcNow -lt $cleanupDeadline) {
        Start-Sleep -Milliseconds 100
        $recover.Refresh()
        if ($recover.HasExited) { break }
    }
    if (-not $recover.HasExited) {
        Stop-Process -Id $recover.Id -Force -ErrorAction SilentlyContinue
    }
}
# The console executable can have a same-run GUI sibling with the non-console
# filename. Limit cleanup to Godot binaries in the supplied installation
# directory and start time so an unrelated Godot session is never touched.
$godotDirectory = (Resolve-Path -LiteralPath (Split-Path -Parent $GodotPath)).Path
$godotProcessNames = @('Godot_v4.7-stable_win64', 'Godot_v4.7-stable_win64_console')
$sameRunGodot = @(Get-Process -ErrorAction SilentlyContinue | Where-Object {
    $_.ProcessName -in $godotProcessNames -and
        $_.Path -like (Join-Path $godotDirectory 'Godot_v4.7-stable_win64*') -and
        $_.StartTime -ge $recoveryStartTime.AddSeconds(-2)
})
if ($sameRunGodot.Count -gt 0) {
    foreach ($candidate in $sameRunGodot) {
        try {
            [Diagnostics.Process]::GetProcessById([int]$candidate.Id).Kill()
        } catch {
            # The console tree may have exited between enumeration and cleanup.
        }
    }
}

Write-Output "SAVE INTERRUPTION PASSED"
Write-Output "RUN_ROOT=$runRoot"
Write-Output "PRIMARY_PRESENT=$($primary.Count -gt 0)"
Write-Output "BACKUP_PRESENT=$($backup.Count -eq 1)"
Write-Output "TEMP_PRESENT=$($temp.Count -eq 1)"
$recoverText -split "`r?`n" | Where-Object { $_ -match "RECOVERED_|RECOVERY PASSED" }
