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
# A host with a global for every local name Legend assigns (collected from the source
# now, so new code is covered): under #Warn All, Legend must not warn "local has the
# same name as a global". Fix a failure by declaring the local (`local name`).
$names = [Collections.Generic.SortedSet[string]]::new()
foreach ($src in @(Join-Path $root 'Legend.ahk') + (Get-ChildItem (Join-Path $root 'src') -Filter *.ahk).FullName) {
    $text = Get-Content $src -Raw
    $text = $text -replace ';[^\r\n]*', '' -replace '"(?:[^"`]|`.)*"', '""' -replace "'(?:[^'``]|``.)*'", "''"
    $patterns = '(?<![.\w])([a-z_]\w*)\s*(?::=|\+=|-=|\.=|\*=|/=)', '\bfor\s+([a-z_]\w*)', '\bfor\s+[a-z_]\w*\s*,\s*([a-z_]\w*)\s+in\b',
        '\bcatch\s+\w*\s*as\s+([a-z_]\w*)', '&([a-z_]\w*)'
    foreach ($pattern in $patterns) {
        foreach ($m in [regex]::Matches($text, $pattern, 'None')) { [void]$names.Add($m.Groups[1].Value) }
    }
}
$names.ExceptWith([string[]]@('this', 'super'))
$hostFile = Join-Path ([IO.Path]::GetTempPath()) "legend-warn-host-$PID.ahk"
$lines = @('#Requires AutoHotkey v2.0', '#Warn All, StdOut')
$all = @($names)
for ($i = 0; $i -lt $all.Count; $i += 10) {
    $lines += 'global ' + (($all[$i..([Math]::Min($i + 9, $all.Count - 1))] | ForEach-Object { "$_ := 0" }) -join ', ')
}
$lines += "#Include `"$(Join-Path $root 'Legend.ahk')`""
Set-Content $hostFile $lines -Encoding UTF8
$check = & $AutoHotkey /ErrorStdOut /Validate $hostFile 2>&1 | Out-String
Remove-Item $hostFile -ErrorAction SilentlyContinue
if ($LASTEXITCODE -or $check -match 'Warning') { $failures += 1; Write-Host "validate all-names host ($($all.Count) globals) FAILED`n$check" }
else { Write-Host "validate all-names host ($($all.Count) globals) ok" }

# Every ```ahk block in README.md and docs/
& (Join-Path $PSScriptRoot 'Check-Docs.ps1') -AutoHotkey $AutoHotkey
$failures += $LASTEXITCODE
# Relative links and #anchors in README.md and docs/ (needs Python; skipped without it)
$python = Get-Command python -ErrorAction SilentlyContinue
if ($python) {
    Push-Location $root
    try { & $python.Source (Join-Path $PSScriptRoot 'check_links.py'); $failures += $LASTEXITCODE } finally { Pop-Location }
} else { Write-Host 'links: skipped (no python)' }
exit $failures
