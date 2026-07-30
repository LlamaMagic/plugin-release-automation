[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string] $AssemblyInfoPath,

    [Parameter(Mandatory)]
    [string] $Version,

    [string] $ReleaseDateUtc
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$parsedVersion = $null
if (-not [System.Version]::TryParse($Version, [ref] $parsedVersion)) {
    throw "Version must be a numeric System.Version value such as 1.2.3 or 1.2.3.4: $Version"
}

$resolvedPath = (Resolve-Path -LiteralPath $AssemblyInfoPath).Path
$content = Get-Content -LiteralPath $resolvedPath -Raw

if ([string]::IsNullOrWhiteSpace($ReleaseDateUtc)) {
    $repositoryRoot = (& git -C (Split-Path -Parent $resolvedPath) rev-parse --show-toplevel 2>$null)
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($repositoryRoot)) {
        throw "Could not resolve the Git repository containing $resolvedPath"
    }

    $ReleaseDateUtc = (& git -C $repositoryRoot show -s --format=%cI HEAD 2>$null)
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($ReleaseDateUtc)) {
        throw "Could not resolve the source commit timestamp for $resolvedPath"
    }
}

$parsedReleaseDate = [DateTimeOffset]::MinValue
if (-not [DateTimeOffset]::TryParse(
    $ReleaseDateUtc,
    [Globalization.CultureInfo]::InvariantCulture,
    [Globalization.DateTimeStyles]::RoundtripKind,
    [ref] $parsedReleaseDate
)) {
    throw "ReleaseDateUtc must be an ISO-8601 timestamp: $ReleaseDateUtc"
}
$normalizedReleaseDateUtc = $parsedReleaseDate.UtcDateTime.ToString(
    'O',
    [Globalization.CultureInfo]::InvariantCulture
)

$assemblyVersionPattern = '(?m)^\s*\[assembly:\s*AssemblyVersion\("[^"]+"\)\s*\]\s*$'
$assemblyFileVersionPattern = '(?m)^\s*\[assembly:\s*AssemblyFileVersion\("[^"]+"\)\s*\]\s*$'
$releaseDateMetadataPattern = '(?m)^\s*\[assembly:\s*AssemblyMetadata\("PandaReleaseDateUtc",\s*"[^"]*"\)\s*\]\s*$'

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

if ($content -match $releaseDateMetadataPattern) {
    $content = [regex]::Replace(
        $content,
        $releaseDateMetadataPattern,
        "[assembly: AssemblyMetadata(`"PandaReleaseDateUtc`", `"$normalizedReleaseDateUtc`")]"
    )
}
else {
    $content = $content.TrimEnd() +
        "`r`n[assembly: AssemblyMetadata(`"PandaReleaseDateUtc`", `"$normalizedReleaseDateUtc`")]`r`n"
}

[System.IO.File]::WriteAllText($resolvedPath, $content, [System.Text.UTF8Encoding]::new($false))
Write-Host "Set assembly version in $resolvedPath to $Version with release date $normalizedReleaseDateUtc"
