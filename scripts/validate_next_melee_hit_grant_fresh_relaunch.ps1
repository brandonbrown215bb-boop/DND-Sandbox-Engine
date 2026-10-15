[CmdletBinding()]
param([Parameter(Position = 0)][string]$GodotPath)

$ErrorActionPreference = "Stop"
$Project = Split-Path -Parent $PSScriptRoot
$runnerPathValue = $env:Path
[Environment]::SetEnvironmentVariable("PATH", $null, "Process")
[Environment]::SetEnvironmentVariable("Path", $runnerPathValue, "Process")
if ([string]::IsNullOrWhiteSpace($GodotPath)) { $GodotPath = $env:GODOT_BIN }
if ([string]::IsNullOrWhiteSpace($GodotPath) -or -not (Test-Path -LiteralPath $GodotPath -PathType Leaf)) {
    throw "Pass the Godot 4.7 console executable or set GODOT_BIN."
}

$runRoot = Join-Path $Project (".artifacts\tests\next-melee-hit-grant-relaunch-" + [guid]::NewGuid().ToString("N"))
$userData = Join-Path $runRoot "user-data"
New-Item -ItemType Directory -Force -Path $userData | Out-Null
$arguments = @("--headless", "--path", ('"' + $Project + '"'), "res://scenes/next_melee_hit_grant_fresh_relaunch.tscn")
$previousAppData = $env:APPDATA
$previousLocalAppData = $env:LOCALAPPDATA
$previousPhase = $env:NEXT_MELEE_HIT_GRANT_RELAUNCH_PHASE
$env:APPDATA = $userData
$env:LOCALAPPDATA = $userData

function Invoke-ProbePhase([string]$Phase) {
    $env:NEXT_MELEE_HIT_GRANT_RELAUNCH_PHASE = $Phase
    $stdout = Join-Path $runRoot ("$Phase.stdout.log")
    $stderr = Join-Path $runRoot ("$Phase.stderr.log")
    $process = Start-Process -FilePath $GodotPath -WorkingDirectory $Project -ArgumentList $arguments `
        -RedirectStandardOutput $stdout -RedirectStandardError $stderr -WindowStyle Hidden -PassThru
    $processId = $process.Id
    if (-not $process.WaitForExit(60000)) {
        Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
        throw "$Phase phase timed out. See $stdout and $stderr"
    }
    $process.WaitForExit()
    $text = ""
    if (Test-Path -LiteralPath $stdout) { $text += Get-Content -Raw -LiteralPath $stdout }
    if (Test-Path -LiteralPath $stderr) { $text += "`n" + (Get-Content -Raw -LiteralPath $stderr) }
    if ($process.ExitCode -ne 0 -or $text -match "SCRIPT ERROR|Parse Error|Compile Error|\[NextMeleeHitGrantFreshRelaunchProbe\]") {
        throw "$Phase phase failed. See $stdout and $stderr"
    }
    $marker = if ($Phase -eq "prepare") { "NEXT MELEE HIT GRANT FRESH PREPARED:" } else { "NEXT MELEE HIT GRANT FRESH RELAUNCH PASSED:" }
    if ($text -notmatch [regex]::Escape($marker)) { throw "$Phase phase missed its success marker. See $stdout and $stderr" }
    return @{ Id = $processId; Text = $text }
}

try {
    $prepare = Invoke-ProbePhase "prepare"
    $recover = Invoke-ProbePhase "recover"
    if ($prepare.Id -eq $recover.Id) { throw "Prepare and recover unexpectedly reused process ID $($prepare.Id)." }
} finally {
    $env:APPDATA = $previousAppData
    $env:LOCALAPPDATA = $previousLocalAppData
    if ($null -eq $previousPhase) { Remove-Item Env:NEXT_MELEE_HIT_GRANT_RELAUNCH_PHASE -ErrorAction SilentlyContinue } else { $env:NEXT_MELEE_HIT_GRANT_RELAUNCH_PHASE = $previousPhase }
}

Write-Output "NEXT_MELEE_HIT_GRANT_FRESH_RELAUNCH_OK"
Write-Output "RUN_ROOT=$runRoot"
Write-Output "PREPARE_PID=$($prepare.Id)"
Write-Output "RECOVER_PID=$($recover.Id)"
$prepare.Text -split "`r?`n" | Where-Object { $_ -match "NEXT MELEE HIT GRANT" }
$recover.Text -split "`r?`n" | Where-Object { $_ -match "NEXT MELEE HIT GRANT" }
