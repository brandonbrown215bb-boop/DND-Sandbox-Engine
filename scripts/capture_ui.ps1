param(
    [string]$GodotPath = $env:GODOT_BIN,
    [switch]$Relaunch
)

# Production UI evidence; all writes stay in disposable repository profiles.
$ErrorActionPreference = 'Stop'
$taskRepo = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
if ([string]::IsNullOrWhiteSpace($GodotPath)) {
    $GodotPath = Join-Path $taskRepo '.artifacts/tools/godot/Godot_v4.7-stable_win64_console.exe'
}
$taskGodot = (Resolve-Path -LiteralPath $GodotPath).Path
$taskMode = if ($Relaunch) { 'relaunch' } else { 'captures' }
$taskOutput = Join-Path $taskRepo ".artifacts/grimoire-$taskMode"
$taskProfile = Join-Path $taskRepo ".artifacts/grimoire-$taskMode-profile"
New-Item -ItemType Directory -Force -Path $taskOutput, "$taskProfile/roaming", "$taskProfile/local" | Out-Null
$taskOldAppData = $env:APPDATA
$taskOldLocalData = $env:LOCALAPPDATA
$taskOldPhase = $env:UI_RELAUNCH_PHASE
$taskPathValue = $env:Path
try {
    $env:APPDATA = "$taskProfile/roaming"
    $env:LOCALAPPDATA = "$taskProfile/local"
    # Normalize Windows' duplicate PATH/Path entries before Start-Process.
    [Environment]::SetEnvironmentVariable('PATH', $null, 'Process')
    [Environment]::SetEnvironmentVariable('Path', $taskPathValue, 'Process')
    $taskPhases = if ($Relaunch) { @('prepare', 'recover') } else { @('capture') }
    foreach ($taskPhase in $taskPhases) {
        $env:UI_RELAUNCH_PHASE = if ($Relaunch) { $taskPhase } else { $null }
        $taskArgs = @('--path', '.', '--max-fps', '60', '--quit-after', '3000')
        if ($Relaunch) { $taskArgs += '--headless' }
        $taskArgs += @('--log-file', ".artifacts/grimoire-$taskMode/$taskPhase.godot.log", 'res://scenes/ui_polish_probe.tscn')
        $taskStdout = Join-Path $taskOutput "$taskPhase.stdout.log"
        $taskStderr = Join-Path $taskOutput "$taskPhase.stderr.log"
        $taskProcess = Start-Process -FilePath $taskGodot -ArgumentList $taskArgs -WorkingDirectory $taskRepo -WindowStyle Hidden -PassThru -RedirectStandardOutput $taskStdout -RedirectStandardError $taskStderr
        if (-not $taskProcess.WaitForExit(60000)) {
            Stop-Process -Id $taskProcess.Id
            throw "UI $taskPhase timed out; logs are in $taskOutput"
        }
        $taskText = (Get-Content -LiteralPath $taskStdout -Raw) + (Get-Content -LiteralPath $taskStderr -Raw)
        $taskMarker = if ($Relaunch) { "UI RELAUNCH ${taskPhase}: 0 failures" } else { 'UI POLISH PROBE: 0 failures' }
        if ($taskProcess.ExitCode -ne 0 -or -not $taskText.Contains($taskMarker) -or $taskText -match 'SCRIPT ERROR:|ERROR:|\[ui FAIL\]') {
            throw "UI $taskPhase failed; inspect $taskOutput"
        }
        Write-Output $taskMarker
    }
    Write-Output "Evidence: $taskOutput"
} finally {
    $env:APPDATA = $taskOldAppData
    $env:LOCALAPPDATA = $taskOldLocalData
    $env:UI_RELAUNCH_PHASE = $taskOldPhase
}
