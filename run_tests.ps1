[CmdletBinding()]
param(
    [Parameter(Position = 0)][string]$GodotPath,
    [ValidateSet("all", "logic", "integration")]
    [string]$Suite = "all",
    [string]$Scenario = ""
)

$ErrorActionPreference = "Stop"
$Project = Split-Path -Parent $MyInvocation.MyCommand.Path

# The Codex host can expose both PATH and Path with different casing. Windows
# treats environment keys case-insensitively, and Start-Process rejects that
# duplicate pair before it can launch Godot. Collapse it to one process-local
# key without changing the user's persistent environment.
$runnerPathValue = $env:Path
[Environment]::SetEnvironmentVariable("PATH", $null, "Process")
[Environment]::SetEnvironmentVariable("Path", $runnerPathValue, "Process")

if ([string]::IsNullOrWhiteSpace($GodotPath)) { $GodotPath = $env:GODOT_BIN }
if ([string]::IsNullOrWhiteSpace($GodotPath)) {
    $command = Get-Command godot -ErrorAction SilentlyContinue
    if ($null -eq $command) { $command = Get-Command godot4 -ErrorAction SilentlyContinue }
    if ($null -ne $command) { $GodotPath = $command.Source }
}
if ([string]::IsNullOrWhiteSpace($GodotPath)) {
    Write-Error "Godot 4.7.x was not found. Set GODOT_BIN or pass the portable executable as arg 1."
    exit 2
}
if (-not (Test-Path -LiteralPath $GodotPath -PathType Leaf)) {
    Write-Error "Godot binary was not found: $GodotPath"
    exit 2
}

$bootstrapTimeout = if ($env:BOOTSTRAP_TIMEOUT_SECONDS) { [int]$env:BOOTSTRAP_TIMEOUT_SECONDS } else { 120 }
$parseTimeout = if ($env:PARSE_TIMEOUT_SECONDS) { [int]$env:PARSE_TIMEOUT_SECONDS } else { 60 }
$bootTimeout = if ($env:BOOT_TIMEOUT_SECONDS) { [int]$env:BOOT_TIMEOUT_SECONDS } else { 30 }
$logicTimeout = if ($env:LOGIC_TIMEOUT_SECONDS) { [int]$env:LOGIC_TIMEOUT_SECONDS } else { 300 }
$scenarioTimeout = if ($env:SCENARIO_TIMEOUT_SECONDS) { [int]$env:SCENARIO_TIMEOUT_SECONDS } else { 60 }
if ($env:TEST_LOG_DIR) {
    $logDirectory = $env:TEST_LOG_DIR
    New-Item -ItemType Directory -Force -Path $logDirectory | Out-Null
} else {
    $logDirectory = Join-Path ([IO.Path]::GetTempPath()) ("top-down-party-game-tests-{0}" -f [guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Path $logDirectory | Out-Null
}

function Quote-ProcessArgument([string]$Value) {
    if ($Value -notmatch '[\s"]') { return $Value }
    return '"' + $Value.Replace('"', '\"') + '"'
}

function Invoke-GodotCase {
    param(
        [string]$Name,
        [string]$Scene,
        [string]$Marker,
        [int]$TimeoutSeconds,
        [string[]]$ExtraArguments = @(),
        [ValidateSet("Scene", "EditorBootstrap")][string]$Mode = "Scene"
    )
    $stdoutPath = Join-Path $logDirectory ("{0}.stdout.log" -f $Name)
    $stderrPath = Join-Path $logDirectory ("{0}.stderr.log" -f $Name)
    $godotLogPath = Join-Path $logDirectory ("{0}.godot.log" -f $Name)
    $userDataDirectory = Join-Path $logDirectory ("{0}.user-data" -f $Name)
    New-Item -ItemType Directory -Force -Path $userDataDirectory | Out-Null
    $helperPath = Join-Path $Project "scripts\invoke_godot_case.ps1"
    $extraArgumentsEncoded = [Convert]::ToBase64String(
        [Text.Encoding]::UTF8.GetBytes(($ExtraArguments -join "`n"))
    )
    $arguments = @(
        "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $helperPath,
        "-GodotPath", $GodotPath,
        "-Project", $Project,
        "-Mode", $Mode,
        "-GodotLogPath", $godotLogPath,
        "-StdoutPath", $stdoutPath,
        "-StderrPath", $stderrPath
    )
    if ($Mode -eq "EditorBootstrap") { $arguments += @("-SuccessMarker", $Marker) }
    if (-not [string]::IsNullOrWhiteSpace($Scene)) { $arguments += @("-Scene", $Scene) }
    if (-not [string]::IsNullOrEmpty($extraArgumentsEncoded)) {
        $arguments += @("-ExtraArgumentsEncoded", $extraArgumentsEncoded)
    }
    $argumentLine = (($arguments | ForEach-Object { Quote-ProcessArgument $_ }) -join " ")
    Write-Host ""
    Write-Host "=================================================================="
    Write-Host ">> Running: $Name"
    Write-Host "    Scene: $Scene"
    Write-Host "    Log:   $stdoutPath"
    Write-Host "=================================================================="
    # Godot maps user:// through APPDATA on Windows. Point both Windows
    # profile roots at a disposable per-scenario directory so saves/settings
    # cannot consume or alter a developer profile and every scenario starts
    # with a clean persistence surface.
    $previousAppData = $env:APPDATA
    $previousLocalAppData = $env:LOCALAPPDATA
    $env:APPDATA = $userDataDirectory
    $env:LOCALAPPDATA = $userDataDirectory
    try {
        # PowerShell 5 can lose Process.ExitCode when Start-Process owns output
        # redirection. A small child wrapper owns the files and propagates the
        # real Godot exit code to this supervisor.
        $process = Start-Process -FilePath "powershell.exe" -WorkingDirectory $Project `
            -ArgumentList $argumentLine -WindowStyle Hidden -PassThru
        $timedOut = -not $process.WaitForExit($TimeoutSeconds * 1000)
    } finally {
        $env:APPDATA = $previousAppData
        $env:LOCALAPPDATA = $previousLocalAppData
    }
    if ($timedOut) {
        # The console executable owns a separate Godot process on Windows.
        # Terminate the exact process tree so a timeout cannot strand a child
        # process or produce a delayed native crash dialog.
        $taskkill = Join-Path $env:SystemRoot "System32\taskkill.exe"
        $cleanup = Start-Process -FilePath $taskkill -ArgumentList @("/PID", $process.Id, "/T", "/F") `
            -WindowStyle Hidden -Wait -PassThru
        if ($cleanup.ExitCode -ne 0 -and -not $process.HasExited) {
            Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
        }
        $null = $process.WaitForExit(5000)
        $exitCode = 124
    } else {
        $process.Refresh()
        $exitCode = $process.ExitCode
        if ($null -eq $exitCode) { $exitCode = 125 }
    }
    $output = ""
    if (Test-Path -LiteralPath $stdoutPath) { $output += Get-Content -Raw -LiteralPath $stdoutPath }
    if (Test-Path -LiteralPath $stderrPath) { $output += Get-Content -Raw -LiteralPath $stderrPath }
    Write-Host $output
    $engineErrors = @($output -split "`r?`n" | Where-Object {
        ($_ -match '(^|\s)(ERROR:|SCRIPT ERROR|Parse Error|Nonexistent function|Invalid call|Invalid get index|Cannot infer)') -and
        ($_ -notmatch 'Failed to read the root certificate store')
    })
    if ($timedOut) { Write-Host ">> $Name`: FAILED (timed out after ${TimeoutSeconds}s)"; return $false }
    if ($exitCode -ne 0) { Write-Host ">> $Name`: FAILED (Godot exit code $exitCode)"; return $false }
    if ($engineErrors.Count -gt 0) {
        Write-Host ">> $Name`: FAILED (unexpected Godot engine error)"
        $engineErrors | ForEach-Object { Write-Host "    $_" }
        return $false
    }
    if ($output.IndexOf($Marker, [StringComparison]::Ordinal) -lt 0) {
        Write-Host ">> $Name`: FAILED (missing result marker: $Marker)"
        return $false
    }
    Write-Host ">> $Name`: PASSED"
    return $true
}

$failed = $false
if (-not (Invoke-GodotCase -Name "project_bootstrap" -Scene "" -Marker "PROJECT BOOTSTRAP PASSED" `
    -TimeoutSeconds $bootstrapTimeout -Mode "EditorBootstrap")) { $failed = $true }
if (-not (Invoke-GodotCase "parse_gate" "res://scenes/parse_gate.tscn" "PARSE GATE PASSED" $parseTimeout)) { $failed = $true }
if (-not (Invoke-GodotCase "boot_gate" "res://scenes/boot_gate.tscn" "BOOT GATE PASSED" $bootTimeout)) { $failed = $true }
$runLogic = $Suite -in @("all", "logic")
$runIntegration = $Suite -in @("all", "integration")
if ($runLogic) {
    if (-not (Invoke-GodotCase "logic" "res://scenes/test_runner.tscn" "ALL TESTS PASSED" $logicTimeout)) { $failed = $true }
}
if ($runIntegration) {
	$scenarios = @("combat", "party_combat", "crown_smoke", "crown_balance_fixture", "combat_ai_loop", "combat_victory", "combat_defeat", "final_encounter_round_trip", "mixed_mechanics_encounter", "ranger_action_flow", "overworld", "companion_lifecycle", "crown_composition_solo_two", "crown_composition_three_four", "main_menu_load", "dungeon", "event_dialog", "crown_event_fairy_ring", "dungeon_reentry_round_trip", "character_creation", "normal_creation_matrix", "shop", "save_load", "action_resource_round_trip", "combat_resolution", "event_choice_resolution", "event_dialog_choice_click", "character_sheet", "character_sheet_contexts", "character_value_audit")
    if (-not [string]::IsNullOrWhiteSpace($Scenario)) {
        if ($scenarios -notcontains $Scenario) { Write-Error "Unknown integration scenario: $Scenario" }
        $scenarios = @($Scenario)
    }
    foreach ($scenario in $scenarios) {
        if ($scenario -eq "normal_creation_matrix") {
            $previousMatrixProbe = $env:RUN_NORMAL_CREATION_MATRIX
            $env:RUN_NORMAL_CREATION_MATRIX = "1"
            try {
                if (-not (Invoke-GodotCase $scenario "res://scenes/main.tscn" "NORMAL CREATION MATRIX PASSED: 1, 2, 3, and 4 players" $scenarioTimeout)) { $failed = $true }
            } finally {
                $env:RUN_NORMAL_CREATION_MATRIX = $previousMatrixProbe
            }
        } else {
            $marker = "SCENARIO PASSED: $scenario"
            if (-not (Invoke-GodotCase $scenario "res://scenes/viewport_harness.tscn" $marker $scenarioTimeout @("--scenario=$scenario"))) { $failed = $true }
        }
    }
}
Write-Host ""
Write-Host ">> Test logs retained at: $logDirectory"
if ($failed) { Write-Host ">> OVERALL: FAILED"; exit 1 }
Write-Host ">> OVERALL: ALL TESTS PASSED"
exit 0
