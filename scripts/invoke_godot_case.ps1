[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$GodotPath,
    [Parameter(Mandatory = $true)][string]$Project,
    [ValidateSet("Scene", "EditorBootstrap")][string]$Mode = "Scene",
    [string]$Scene = "",
    [Parameter(Mandatory = $true)][string]$GodotLogPath,
    [Parameter(Mandatory = $true)][string]$StdoutPath,
    [Parameter(Mandatory = $true)][string]$StderrPath,
    [string]$SuccessMarker = "",
    [string]$ExtraArgumentsEncoded = ""
)

$ErrorActionPreference = "Stop"

try {
    $extraArguments = @()
    if (-not [string]::IsNullOrWhiteSpace($ExtraArgumentsEncoded)) {
        $decodedArguments = [Text.Encoding]::UTF8.GetString(
            [Convert]::FromBase64String($ExtraArgumentsEncoded)
        )
        if (-not [string]::IsNullOrEmpty($decodedArguments)) {
            $extraArguments = @($decodedArguments -split "`n")
        }
    }
    if ($Mode -eq "EditorBootstrap") {
        # A clean checkout has no ignored .godot class cache. Recovery mode
        # performs the editor's first scan without loading editor plugins.
        $arguments = @(
            "--headless", "--recovery-mode", "--editor", "--quit",
            "--log-file", $GodotLogPath, "--path", $Project
        ) + $extraArguments
    } else {
        if ([string]::IsNullOrWhiteSpace($Scene)) { throw "Scene mode requires -Scene" }
        $arguments = @("--headless", "--log-file", $GodotLogPath, "--path", $Project, $Scene) + $extraArguments
    }
    # Let cmd own raw stream redirection. Windows PowerShell 5 otherwise wraps
    # native stderr in a NativeCommandError record, which corrupts the captured
    # Godot log and obscures the real process result.
    $commandParts = @($GodotPath) + $arguments
    $commandLine = (($commandParts | ForEach-Object { '"' + $_.Replace('"', '""') + '"' }) -join " ")
    $commandLine += ' 1>"' + $StdoutPath.Replace('"', '""') + '"'
    $commandLine += ' 2>"' + $StderrPath.Replace('"', '""') + '"'
    $commandFile = Join-Path (Split-Path -Parent $StdoutPath) ("invoke-{0}.cmd" -f [guid]::NewGuid().ToString("N"))
    [IO.File]::WriteAllText(
        $commandFile,
        "@echo off`r`n$commandLine`r`nexit /b %ERRORLEVEL%`r`n",
        [Text.Encoding]::ASCII
    )
    try {
        & $env:ComSpec /d /c $commandFile
    } finally {
        Remove-Item -LiteralPath $commandFile -Force -ErrorAction SilentlyContinue
    }
    $exitCode = $LASTEXITCODE
    if ($null -eq $exitCode) { $exitCode = 125 }
    if ($exitCode -eq 0 -and -not [string]::IsNullOrWhiteSpace($SuccessMarker)) {
        [IO.File]::AppendAllText($StdoutPath, "`r`n$SuccessMarker`r`n", [Text.Encoding]::UTF8)
    }
    exit $exitCode
} catch {
    $_ | Out-File -LiteralPath $StderrPath -Append -Encoding utf8
    exit 126
}
