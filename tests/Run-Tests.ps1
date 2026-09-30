#Requires -Version 7
<#
Runs Legend's unit tests and syntax-checks the entry points. Exit code = number of failures.
#>
param([string]$AutoHotkey)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent

if (-not $AutoHotkey) {
    $AutoHotkey = @(
        (Get-Command AutoHotkey64.exe -ErrorAction SilentlyContinue).Source
        "$env:ProgramFiles\AutoHotkey\v2\AutoHotkey64.exe"
        "$env:USERPROFILE\scoop\apps\autohotkey\current\v2\AutoHotkey64.exe"
    ) | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1
}
if (-not $AutoHotkey) { throw 'AutoHotkey v2 not found; pass -AutoHotkey <path to AutoHotkey64.exe>' }

$failures = 0
$out = & $AutoHotkey /ErrorStdOut (Join-Path $PSScriptRoot 'Legend.Tests.ahk') 2>&1 | Out-String
Write-Host $out
if ($LASTEXITCODE) { $failures += [Math]::Max(1, $LASTEXITCODE) }

foreach ($file in @('Legend.ahk') + (Get-ChildItem (Join-Path $root 'examples') -Filter *.ahk | ForEach-Object { "examples\$($_.Name)" })) {
    $path = Join-Path $root $file
    if (-not (Test-Path $path)) { continue }
    $check = & $AutoHotkey /ErrorStdOut /Validate $path 2>&1 | Out-String
    if ($LASTEXITCODE) { $failures += 1; Write-Host "validate $file FAILED`n$check" }
    else { Write-Host "validate $file ok" }
}
# A host with short-named globals: Legend's locals must not trigger #Warn
$warnHost = Join-Path $PSScriptRoot 'fixtures\warn-host\WarnHost.ahk'
$check = & $AutoHotkey /ErrorStdOut /Validate $warnHost 2>&1 | Out-String
if ($LASTEXITCODE -or $check -match 'Warning') { $failures += 1; Write-Host "validate WarnHost FAILED`n$check" }
else { Write-Host 'validate fixtures\warn-host\WarnHost.ahk ok' }
exit $failures
