[CmdletBinding()]
param(
    [Parameter(Position = 0)][string]$GodotPath,
    [ValidateSet("all", "logic", "integration")]
    [string]$Suite = "all",
    [string[]]$Scenario = @(),
    [ValidateSet("all", "data", "spells", "effects", "barbarian", "bard", "cleric", "combat", "conditions", "classes", "persistence", "world", "ui", "check_context")]
    [string[]]$LogicGroup = @("all")
)

$ErrorActionPreference = "Stop"
$Project = Split-Path -Parent $MyInvocation.MyCommand.Path
if ($Suite -eq "integration" -and ($LogicGroup.Count -ne 1 -or $LogicGroup[0] -ne "all")) {
    throw "-LogicGroup requires -Suite logic or all."
}

# The Codex host can expose both PATH and Path with different casing. Windows
# treats environment keys case-insensitively, and Start-Process rejects that
# duplicate pair before it can launch Godot. Collapse it to one process-local
# key without changing the user's persistent environment.
$runnerPathValue = $env:Path
[Environment]::SetEnvironmentVariable("PATH", $null, "Process")
[Environment]::SetEnvironmentVariable("Path", $runnerPathValue, "Process")

if ([string]::IsNullOrWhiteSpace($GodotPath)) { $GodotPath = $env:GODOT_BIN }
if ([string]::IsNullOrWhiteSpace($GodotPath)) {
    # The owner's portable engine lives here even when fresh chats have no
    # GODOT_BIN or Godot entry on PATH. Keep explicit overrides authoritative.
    $projectGodotPath = Join-Path $Project ".artifacts\tools\godot\Godot_v4.7-stable_win64_console.exe"
    if (Test-Path -LiteralPath $projectGodotPath -PathType Leaf) { $GodotPath = $projectGodotPath }
}
if ([string]::IsNullOrWhiteSpace($GodotPath)) {
    $command = Get-Command godot -ErrorAction SilentlyContinue
    if ($null -eq $command) { $command = Get-Command godot4 -ErrorAction SilentlyContinue }
    if ($null -ne $command) { $GodotPath = $command.Source }
}
if ([string]::IsNullOrWhiteSpace($GodotPath)) {
    Write-Error "Godot 4.7.x was not found. Checked .artifacts\tools\godot\Godot_v4.7-stable_win64_console.exe and PATH; set GODOT_BIN or pass -GodotPath for an existing executable."
    exit 2
}
if (-not (Test-Path -LiteralPath $GodotPath -PathType Leaf)) {
    Write-Error "Godot binary was not found: $GodotPath"
    exit 2
}
$GodotPath = (Get-Item -LiteralPath $GodotPath).FullName
Write-Host "Godot: $GodotPath"

$bootstrapTimeout = if ($env:BOOTSTRAP_TIMEOUT_SECONDS) { [int]$env:BOOTSTRAP_TIMEOUT_SECONDS } else { 120 }
$parseTimeout = if ($env:PARSE_TIMEOUT_SECONDS) { [int]$env:PARSE_TIMEOUT_SECONDS } else { 60 }
$bootTimeout = if ($env:BOOT_TIMEOUT_SECONDS) { [int]$env:BOOT_TIMEOUT_SECONDS } else { 30 }
$logicTimeout = if ($env:LOGIC_TIMEOUT_SECONDS) { [int]$env:LOGIC_TIMEOUT_SECONDS } else { 300 }
$scenarioTimeout = if ($env:SCENARIO_TIMEOUT_SECONDS) { [int]$env:SCENARIO_TIMEOUT_SECONDS } else { 60 }
if ($env:TEST_LOG_DIR) {
    $logDirectory = $env:TEST_LOG_DIR
    New-Item -ItemType Directory -Force -Path $logDirectory | Out-Null
} else {
    # Keep generated logs and disposable Godot profiles inside the writable
    # project. Sandbox Temp/profile paths may not permit the engine's safe saves.
    $logDirectory = Join-Path $Project (".artifacts\tests\{0}" -f [guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Force -Path $logDirectory | Out-Null
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
    -TimeoutSeconds $bootstrapTimeout -Mode "EditorBootstrap")) { Write-Host ">> Stopped: project bootstrap failed. Logs: $logDirectory"; exit 1 }
if (-not (Invoke-GodotCase "parse_gate" "res://scenes/parse_gate.tscn" "PARSE GATE PASSED" $parseTimeout)) { Write-Host ">> Stopped: project parsing failed. Logs: $logDirectory"; exit 1 }
if (-not (Invoke-GodotCase "boot_gate" "res://scenes/boot_gate.tscn" "BOOT GATE PASSED" $bootTimeout)) { Write-Host ">> Stopped: project boot failed. Logs: $logDirectory"; exit 1 }
$runLogic = $Suite -in @("all", "logic")
$runIntegration = $Suite -in @("all", "integration")
if ($runLogic) {
    $logicMarker = if ($LogicGroup -contains "all") { "ALL TESTS PASSED" } else { "SELECTED LOGIC TESTS PASSED" }
    if (-not (Invoke-GodotCase "logic" "res://scenes/test_runner.tscn" $logicMarker $logicTimeout @("--logic-groups=$($LogicGroup -join ',')"))) { $failed = $true }
}
if ($runIntegration) {
	$scenarios = @("playtest_fixes", "combat", "party_combat", "crown_smoke", "crown_balance_fixture", "combat_ai_loop", "combat_victory", "combat_defeat", "final_encounter_round_trip", "mixed_mechanics_encounter", "spell_effect_lifetime", "jump_spell_movement", "ranger_action_flow", "ranger_natures_veil_blindsight", "wizard_capstone_cast_modes", "monk_action_flow", "fighter_second_wind", "fighter_progression", "class_building_blocks", "barbarian_action_flow", "barbarian_choice_flow", "bard_action_flow", "bard_creation_flow", "cleric_creation_flow", "cleric_action_flow", "cleric_strike_flow", "core12_shared_rules", "core12_audit_repairs", "rogue_devious_strikes", "sorcerer_subtle_spell", "sleep_spell_flow", "blindness_deafness_spell_flow", "grease_spell_flow", "spike_growth_spell_flow", "entangle_spell_flow", "black_tentacles_spell_flow", "wall_of_fire_spell_flow", "sleet_storm_spell_flow", "cloud_of_daggers_spell_flow", "cloudkill_spell_flow", "conjure_animals_spell_flow", "conjure_celestial_spell_flow", "conjure_elemental_spell_flow", "conjure_fey_spell_flow", "conjure_minor_elementals_spell_flow", "conjure_woodland_beings_spell_flow", "spirit_guardians_spell_flow", "aura_of_life_spell_flow", "beacon_of_hope_spell_flow", "divine_favor_spell_flow", "death_ward_spell_flow", "sanctuary_spell_flow", "heroism_spell_flow", "magic_weapon_spell_flow", "enhance_ability_spell_flow", "charm_person_spell_flow", "charm_monster_spell_flow", "faerie_fire_spell_flow", "fog_cloud_spell_flow", "darkness_spell_flow", "antilife_shell_spell_flow", "freedom_of_movement_spell_flow", "darkvision_spell_flow", "see_invisibility_spell_flow", "detect_magic_spell_flow", "blur_spell_flow", "detect_evil_and_good_spell_flow", "detect_poison_and_disease_spell_flow", "identify_spell_flow", "goodberry_spell_flow", "true_seeing_spell_flow", "invisibility_spell_flow", "moonbeam_spell_flow", "plant_growth_spell_flow", "barkskin_spell_flow", "mage_armor_spell_flow", "true_strike_spell_flow", "mass_cure_wounds_flow", "mass_healing_word_flow", "sorcerer_twinned_spell", "wand_magic_missiles_flow", "wand_last_charge_destruction_flow", "portable_light_source_combat_flow", "chain_lightning_target_identity_flow", "chain_lightning_mixed_targets_flow", "meteor_swarm_object_area_flow", "fire_area_object_ignition_flow", "sunburst_spell_flow", "overworld", "companion_lifecycle", "crown_composition_solo_two", "crown_composition_three_four", "main_menu_load", "dungeon", "event_dialog", "crown_event_fairy_ring", "dungeon_reentry_round_trip", "character_creation", "normal_creation_matrix", "shop", "save_load", "action_resource_round_trip", "combat_resolution", "event_choice_resolution", "event_dialog_choice_click", "character_sheet", "character_sheet_contexts", "character_value_audit")
	$scenarios += "spell_cast_stage_flow", "post_roll_die_bonus_flow"
    $scenarios += "combat_light_visibility_flow"
	$scenarios += "local_room_object_flow"
	$scenarios += "shared_spell_flow", "shared_spell_p1_flow", "shared_numeric_pool_flow", "shared_numeric_breakpoint_flow", "shared_timed_numeric_grant_flow", "shared_timed_numeric_cooldown_flow", "shared_timed_temporary_hp_flow", "shared_next_melee_hit_grant_flow", "shared_dice_pool_flow", "shared_numeric_pool_exchange_flow", "shared_combat_use_limits_flow", "shared_spell_normal_controls_flow", "failed_save_numeric_bonus_flow", "shared_spell_attack_bonus_flow", "weapon_attack_numeric_bonus_flow", "attack_result_adjustment_flow", "roll_token_normal_controls_flow", "ward_normal_controls_flow", "short_rest_arcane_recovery_normal_controls_flow", "numeric_pool_rest_recovery_normal_controls_flow"
	$scenarios += "check_context_flow", "shared_fact_predicate_flow", "shared_entity_binding_flow", "s026_relationship_willingness_flow", "shared_prior_result_identity_flow", "shared_margin_hp_gate_flow", "shared_spell_outcome_maps_flow", "shared_spell_malformed_outcome_preflight_flow"
	$scenarios += "wave_three_foundations_flow", "owned_creature_lifecycle_flow",
    "find_familiar_exploration_flow", "party_recovery_flow", "downed_area_damage_flow", "created_undead_flow"
    if ($Scenario.Count -gt 0) {
        foreach ($selectedScenario in $Scenario) {
            if ($scenarios -notcontains $selectedScenario) { Write-Error "Unknown integration scenario: $selectedScenario" }
        }
        $scenarios = @($Scenario | Select-Object -Unique)
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
Write-Host ">> OVERALL: REQUESTED TESTS PASSED"
exit 0
