#Requires -Version 7
<#
Checks Legend's explicit-local convention in files or directories of AHK sources.
Parameters and explicitly declared static variables already have their own scope.
This is a conservative source check for the function/accessor syntax used here,
not an AHK compiler; Run-Tests.ps1 retains the generated #Warn validation too.
#>
param([Parameter(Mandatory, Position = 0, ValueFromRemainingArguments = $true)][string[]]$Path)

$ErrorActionPreference = 'Stop'

function Get-SourceFiles([string[]]$InputPath) {
    foreach ($item in $InputPath) {
        if (Test-Path -LiteralPath $item -PathType Container) {
            Get-ChildItem -LiteralPath $item -Filter *.ahk -File
        } elseif (Test-Path -LiteralPath $item -PathType Leaf) {
            Get-Item -LiteralPath $item
        } else {
            throw "source path not found: $item"
        }
    }
}

function Remove-AhkCommentsAndStrings([string]$Source) {
    # Keep line breaks so declarations and function headers remain line anchored.
    $pattern = '"(?:[^"`]|`.)*"|''(?:[^''`]|`.)*''|(?m)^[\t ]*/\*[\s\S]*?^[\t ]*\*/|;[^\r\n]*'
    return [regex]::Replace($Source, $pattern, { param($match) $match.Value -replace '[^\r\n]', ' ' })
}

function Get-DeclaredNames([string]$Declaration) {
    # Split only at top-level commas: initializer expressions are not declarations.
    $depth = 0
    $start = 0
    for ($index = 0; $index -le $Declaration.Length; $index++) {
        if ($index -eq $Declaration.Length -or ($Declaration[$index] -eq ',' -and $depth -eq 0)) {
            $part = $Declaration.Substring($start, $index - $start)
            if ($part -match '^\s*&?([a-z_]\w*)') { $Matches[1] }
            $start = $index + 1
        } elseif ($Declaration[$index] -in '(', '[', '{') {
            $depth++
        } elseif ($Declaration[$index] -in ')', ']', '}') {
            $depth--
        }
    }
}

function Get-IntroducedNames([string]$Body) {
    $names = [Collections.Generic.SortedSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    $patterns = @(
        '(?<![.\w])([a-z_]\w*)\s*(?::=|\+=|-=|\.=|\*=|//=|/=|\|=|&=|\^=|>>>=|>>=|<<=)',
        '\bfor\s+([a-z_]\w*)',
        '\bfor\s*(?:[a-z_]\w*)?\s*,\s*([a-z_]\w*)\s+in\b',
        '\bcatch\s+(?:[a-z_]\w*\s+)?as\s+([a-z_]\w*)',
        # A VarRef starts an expression (e.g. a call argument or assignment RHS).
        # Binary AND follows a completed operand and must not introduce its RHS.
        '(?:^|[(,\[?:=]|\breturn\b)\s*&\s*([a-z_]\w*)'
    )
    foreach ($pattern in $patterns) {
        foreach ($match in [regex]::Matches($Body, $pattern, 'IgnoreCase')) {
            [void]$names.Add($match.Groups[1].Value)
        }
    }
    return $names
}

$problems = @()
foreach ($file in Get-SourceFiles $Path) {
    $source = Remove-AhkCommentsAndStrings (Get-Content -LiteralPath $file.FullName -Raw)
    $lines = $source -split '\r?\n'
    for ($start = 0; $start -lt $lines.Count; $start++) {
        $header = [regex]::Match($lines[$start], '^\s*(?:static\s+)?(?<name>[a-z_]\w*)\((?<params>.*?)\)\s*(?<body>\{|=>)', 'IgnoreCase')
        if (!$header.Success) {
            $header = [regex]::Match($lines[$start], '^\s*(?<name>get|set)\s*(?<body>\{)', 'IgnoreCase')
        }
        if (!$header.Success) { continue }

        $declared = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
        foreach ($parameter in Get-DeclaredNames $header.Groups['params'].Value) { [void]$declared.Add($parameter) }
        if ($header.Groups['name'].Value -eq 'set') { [void]$declared.Add('value') }
        $body = $lines[$start].Substring($header.Length)
        if ($header.Groups['body'].Value -eq '{') {
            $depth = 1
            for ($lineIndex = $start; $lineIndex -lt $lines.Count; $lineIndex++) {
                $line = if ($lineIndex -eq $start) { $body } else { $lines[$lineIndex] }
                $depth += ([regex]::Matches($line, '\{').Count - [regex]::Matches($line, '\}').Count)
                if ($lineIndex -gt $start) { $body += "`n$line" }
                if ($depth -eq 0) { break }
            }
            if ($depth -ne 0) { throw "$($file.Name):$($header.Groups['name'].Value): unclosed function body" }
            $start = $lineIndex
        }
        foreach ($declaration in [regex]::Matches($body, '(?m)^\s*(?:local|static)\s+([^\r\n]+)', 'IgnoreCase')) {
            foreach ($name in Get-DeclaredNames $declaration.Groups[1].Value) { [void]$declared.Add($name) }
        }
        foreach ($name in Get-IntroducedNames $body) {
            if (!$declared.Contains($name)) {
                $problems += "$($file.Name):$($header.Groups['name'].Value): undeclared local $name"
            }
        }
    }
}

foreach ($problem in $problems) { Write-Output $problem }
if ($problems.Count) { exit 1 }
exit 0
