[CmdletBinding()]
param([Parameter(Position = 0)][string]$GodotPath)

$ErrorActionPreference = "Stop"
$Project = Split-Path -Parent $PSScriptRoot
$runnerPathValue = $env:Path
[Environment]::SetEnvironmentVariable("PATH", $null, "Process")
[Environment]::SetEnvironmentVariable("Path", $runnerPathValue, "Process")
if ([string]::IsNullOrWhiteSpace($GodotPath)) { $GodotPath = $env:GODOT_BIN }
if ([string]::IsNullOrWhiteSpace($GodotPath)) { $GodotPath = Join-Path $Project ".artifacts\tools\godot\Godot_v4.7-stable_win64_console.exe" }
if (-not (Test-Path -LiteralPath $GodotPath -PathType Leaf)) { throw "Pass an existing Godot 4.7 console executable or configure GODOT_BIN." }
$GodotPath = (Get-Item -LiteralPath $GodotPath).FullName
$runRoot = Join-Path $Project (".artifacts\tests\batch-024-relaunch-" + [guid]::NewGuid().ToString("N"))
$userData = Join-Path $runRoot "user-data"
New-Item -ItemType Directory -Force -Path $userData | Out-Null
$previousAppData = $env:APPDATA
$previousLocalAppData = $env:LOCALAPPDATA
$previousPhase = $env:BATCH_024_RELAUNCH_PHASE
$env:APPDATA = $userData
$env:LOCALAPPDATA = $userData

function Invoke-ProbePhase([string]$Phase) {
    $env:BATCH_024_RELAUNCH_PHASE = $Phase
    $stdout = Join-Path $runRoot "$Phase.stdout.log"
    $stderr = Join-Path $runRoot "$Phase.stderr.log"
    $godotLog = Join-Path $runRoot "$Phase.godot.log"
    $helper = Join-Path $Project "scripts\invoke_godot_case.ps1"
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $helper -GodotPath $GodotPath -Project $Project `
        -Mode Scene -Scene "res://scenes/batch_024_fresh_relaunch.tscn" -GodotLogPath $godotLog `
        -StdoutPath $stdout -StderrPath $stderr
    $exitCode = $LASTEXITCODE
    $text = ""
    if (Test-Path -LiteralPath $stdout) { $text += Get-Content -Raw -LiteralPath $stdout }
    if (Test-Path -LiteralPath $stderr) { $text += "`n" + (Get-Content -Raw -LiteralPath $stderr) }
    if ($exitCode -ne 0 -or $text -match "SCRIPT ERROR|Parse Error|Compile Error|ERROR:|\[Batch024FreshRelaunchProbe\]") { throw "$Phase phase failed (exit=$exitCode). See $stdout and $stderr" }
    $marker = if ($Phase -eq "prepare") { "BATCH 024 FRESH PREPARED:" } else { "BATCH 024 FRESH RELAUNCH PASSED:" }
    if ($text -notmatch [regex]::Escape($marker)) { throw "$Phase phase missed its success marker. See $stdout and $stderr" }
    return @{ Text = $text }
}

try {
    $prepare = Invoke-ProbePhase "prepare"
    $recover = Invoke-ProbePhase "recover"
} finally {
    $env:APPDATA = $previousAppData
    $env:LOCALAPPDATA = $previousLocalAppData
    if ($null -eq $previousPhase) { Remove-Item Env:BATCH_024_RELAUNCH_PHASE -ErrorAction SilentlyContinue } else { $env:BATCH_024_RELAUNCH_PHASE = $previousPhase }
}

Write-Output "BATCH_024_FRESH_RELAUNCH_OK"
Write-Output "RUN_ROOT=$runRoot"
$prepare.Text -split "`r?`n" | Where-Object { $_ -match "BATCH 024" }
$recover.Text -split "`r?`n" | Where-Object { $_ -match "BATCH 024" }
