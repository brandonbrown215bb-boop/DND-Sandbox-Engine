[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)][string]$GodotPath,
    [string]$SourceRoot = ""
)

$ErrorActionPreference = "Stop"
if ([string]::IsNullOrWhiteSpace($SourceRoot)) {
    $SourceRoot = Split-Path -Parent $PSScriptRoot
}
$source = (Resolve-Path -LiteralPath $SourceRoot).Path
if (-not (Test-Path -LiteralPath $GodotPath -PathType Leaf)) {
    throw "Godot binary was not found: $GodotPath"
}

$copyRoot = Join-Path ([IO.Path]::GetTempPath()) ("top-down-party-game-clean-{0}" -f [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $copyRoot | Out-Null

# This is deliberately a copy from the current source tree, not a copy of
# editor state. It is the clone-equivalent check available before a commit is
# published: no .git metadata, Godot import cache, Codex state, save roots, or
# generated build outputs are carried into the validation tree.
$excludedDirectories = @(".git", ".godot", ".import", ".codex", ".agents", "builds", "exports", "saves")
$robocopyArguments = @($source, $copyRoot, "/E", "/R:1", "/W:1", "/NFL", "/NDL", "/NP")
foreach ($directory in $excludedDirectories) {
    $robocopyArguments += @("/XD", (Join-Path $source $directory))
}
& robocopy @robocopyArguments | Out-Host
if ($LASTEXITCODE -gt 7) {
    throw "Clean source copy failed with robocopy exit code $LASTEXITCODE"
}

$runner = Join-Path $copyRoot "run_tests.ps1"
if (-not (Test-Path -LiteralPath $runner -PathType Leaf)) {
    throw "Clean copy is missing run_tests.ps1: $copyRoot"
}

& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $runner $GodotPath -Suite all
$testExitCode = $LASTEXITCODE
$result = [pscustomobject]@{
    CleanCopy = $copyRoot
    GodotPath = (Resolve-Path -LiteralPath $GodotPath).Path
    TestExitCode = $testExitCode
    Passed = ($testExitCode -eq 0)
}
$result | Format-List

Write-Host "Clean copy retained at $copyRoot for inspection; remove it after review."
if ($testExitCode -ne 0) {
    exit $testExitCode
}
