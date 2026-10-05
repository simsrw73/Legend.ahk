#Requires -Version 7
<#
Syntax-checks every ```ahk code block in README.md and docs/ (except docs/specs
and docs/plans) with AutoHotkey's /Validate, so the documentation can't drift
from the library. A block's `#Include ...Legend.ahk` line is pointed at this
repo; a block without one gets it added. Put <!-- fragment --> on the line
before a block that is deliberately incomplete to skip it.
Exit code = number of failing blocks.
#>
param([Parameter(Mandatory)][string]$AutoHotkey)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$legend = Join-Path $root 'Legend.ahk'
$work = Join-Path ([IO.Path]::GetTempPath()) "legend-docs-$PID"
New-Item -ItemType Directory -Force $work | Out-Null

$files = @(Get-Item (Join-Path $root 'README.md'))
$files += Get-ChildItem (Join-Path $root 'docs') -Recurse -Filter *.md |
    Where-Object { $_.FullName -notmatch '[\\/]docs[\\/](specs|plans)[\\/]' }

$failures = 0; $checked = 0
foreach ($file in $files) {
    $lines = Get-Content $file.FullName -Encoding UTF8
    $rel = [IO.Path]::GetRelativePath($root, $file.FullName)
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -notmatch '^\s*```ahk\s*$') { continue }
        $start = $i + 1
        $skip = $i -gt 0 -and $lines[$i - 1] -match '<!--\s*fragment\s*-->'
        $body = [Collections.Generic.List[string]]::new()
        for ($i = $start; $i -lt $lines.Count -and $lines[$i] -notmatch '^\s*```\s*$'; $i++) { $body.Add($lines[$i]) }
        if ($skip) { continue }
        $hasInclude = $false
        $code = foreach ($line in $body) {
            if ($line -match '^\s*#Include\s+.*Legend\.ahk\s*$') { $hasInclude = $true; "#Include `"$legend`"" } else { $line }
        }
        if (-not $hasInclude) { $code = @("#Include `"$legend`"") + $code }
        if (-not ($code -match '^\s*#Requires')) { $code = @('#Requires AutoHotkey v2.0') + $code }
        # Warnings catch names a block uses but never defines (a function from nowhere).
        # LocalSameAsGlobal is off: a doc's global named like one of Legend's locals
        # (page, key, name) warns inside Legend; see docs/troubleshooting.md.
        if (-not ($code -match '^\s*#Warn')) { $code = @('#Warn All, StdOut', '#Warn LocalSameAsGlobal, Off') + $code }
        $block = Join-Path $work ("{0}-{1}.ahk" -f ($rel -replace '[\\/.]', '_'), $start)
        Set-Content $block $code -Encoding UTF8
        $checked++
        $out = & $AutoHotkey /ErrorStdOut /Validate $block 2>&1 | Out-String
        if ($LASTEXITCODE -or $out -match 'Warning') {
            $failures++
            Write-Host "docs $rel line $start FAILED`n$out"
        }
    }
}
Remove-Item $work -Recurse -Force -ErrorAction SilentlyContinue
Write-Host "docs: $checked code blocks checked, $failures failed"
exit $failures
