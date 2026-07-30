[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string] $AssemblyInfoPath,

    [Parameter(Mandatory)]
    [string] $Version
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$parsedVersion = $null
if (-not [System.Version]::TryParse($Version, [ref] $parsedVersion)) {
    throw "Version must be a numeric System.Version value such as 1.2.3 or 1.2.3.4: $Version"
}

$resolvedPath = (Resolve-Path -LiteralPath $AssemblyInfoPath).Path
$content = Get-Content -LiteralPath $resolvedPath -Raw

$assemblyVersionPattern = '(?m)^\s*\[assembly:\s*AssemblyVersion\("[^"]+"\)\s*\]\s*$'
$assemblyFileVersionPattern = '(?m)^\s*\[assembly:\s*AssemblyFileVersion\("[^"]+"\)\s*\]\s*$'

if ($content -notmatch $assemblyVersionPattern) {
    throw "AssemblyVersion was not found in $resolvedPath"
}

$content = [regex]::Replace($content, $assemblyVersionPattern, "[assembly: AssemblyVersion(`"$Version`")]")
if ($content -match $assemblyFileVersionPattern) {
    $content = [regex]::Replace(
        $content,
        $assemblyFileVersionPattern,
        "[assembly: AssemblyFileVersion(`"$Version`")]"
    )
}
else {
    $content = $content.TrimEnd() + "`r`n[assembly: AssemblyFileVersion(`"$Version`")]`r`n"
}

[System.IO.File]::WriteAllText($resolvedPath, $content, [System.Text.UTF8Encoding]::new($false))
Write-Host "Set assembly version in $resolvedPath to $Version"
