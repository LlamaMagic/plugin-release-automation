[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string] $ArchivePath
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$resolvedArchive = (Resolve-Path -LiteralPath $ArchivePath).Path
$sidecarPath = "$resolvedArchive.sha256"
if (-not (Test-Path -LiteralPath $sidecarPath -PathType Leaf)) {
    throw "SHA-256 sidecar was not found: $sidecarPath"
}

$expectedArchiveHash = ((Get-Content -LiteralPath $sidecarPath -Raw).Trim() -split '\s+')[0]
$actualArchiveHash = (Get-FileHash -LiteralPath $resolvedArchive -Algorithm SHA256).Hash.ToLowerInvariant()
if ($actualArchiveHash -ne $expectedArchiveHash.ToLowerInvariant()) {
    throw "Archive hash mismatch. Expected $expectedArchiveHash; found $actualArchiveHash."
}

$extractionRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("verify-release-system-" + [guid]::NewGuid().ToString('N'))
[System.IO.Directory]::CreateDirectory($extractionRoot) | Out-Null

try {
    Expand-Archive -LiteralPath $resolvedArchive -DestinationPath $extractionRoot

    $requiredPaths = @(
        'README.md',
        'MANIFEST.json',
        'REPOSITORY_STATE.json',
        'automation-repository.bundle',
        'automation-repository\GITHUB_RELEASE_AUTOMATION_PLAN.md',
        'automation-repository\config\products.json',
        'automation-repository\.github\workflows\reusable-plugin-ci.yml',
        'automation-repository\.github\workflows\self-test.yml',
        'automation-repository\scripts\New-FullReleaseSystemPackage.ps1',
        'automation-repository\scripts\Test-FullReleaseSystemPackage.ps1',
        'panda-auth-reference\.gitea\workflows\release-auth.yaml'
    )
    foreach ($relativePath in $requiredPaths) {
        $path = Join-Path $extractionRoot $relativePath
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
            throw "Required package file is missing: $relativePath"
        }
    }

    $state = Get-Content -LiteralPath (Join-Path $extractionRoot 'REPOSITORY_STATE.json') -Raw |
        ConvertFrom-Json
    if (@($state.products).Count -ne 9) {
        throw "Expected repository state for nine products; found $(@($state.products).Count)."
    }

    $productIds = @(
        'PandaFarmer',
        'PandaFarmerWPF',
        'PandaTripleTriad',
        'AnimaWeapons',
        'MandervilleWeapons',
        'ZodiacWeapons',
        'RelicWeapons',
        'SplendorousTools',
        'BeastTribes'
    )
    foreach ($productId in $productIds) {
        $productRoot = Join-Path $extractionRoot ("plugin-integration\" + $productId)
        foreach ($name in @('git-status.txt', 'working-tree.patch', 'staged.patch')) {
            if (-not (Test-Path -LiteralPath (Join-Path $productRoot $name) -PathType Leaf)) {
                throw "Integration state is incomplete for ${productId}: $name"
            }
        }
        $reactorProjects = @(Get-ChildItem -LiteralPath $productRoot -File -Filter '*.nrproj')
        if ($reactorProjects.Count -ne 1) {
            throw "Expected one Reactor project for $productId; found $($reactorProjects.Count)."
        }
    }

    $manifest = Get-Content -LiteralPath (Join-Path $extractionRoot 'MANIFEST.json') -Raw |
        ConvertFrom-Json
    foreach ($entry in $manifest.files) {
        $path = Join-Path $extractionRoot ([string] $entry.path)
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
            throw "Manifest file is missing: $($entry.path)"
        }
        $file = Get-Item -LiteralPath $path
        if ($file.Length -ne [long] $entry.length) {
            throw "Manifest length mismatch: $($entry.path)"
        }
        $hash = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($hash -ne [string] $entry.sha256) {
            throw "Manifest hash mismatch: $($entry.path)"
        }
    }

    $actualFiles = @(
        Get-ChildItem -LiteralPath $extractionRoot -Recurse -File |
            Where-Object { $_.FullName -ne (Join-Path $extractionRoot 'MANIFEST.json') }
    )
    if ($actualFiles.Count -ne @($manifest.files).Count) {
        throw "Manifest file count mismatch. Manifest: $(@($manifest.files).Count); actual: $($actualFiles.Count)."
    }

    $bundlePath = Join-Path $extractionRoot 'automation-repository.bundle'
    $bundleOutput = & git bundle verify $bundlePath 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "Automation Git bundle failed verification:`n$($bundleOutput -join "`n")"
    }

    $forbiddenFilePatterns = @('license.v3lic', '*.pfx', '*.p12', '*.pem', '*.snk')
    foreach ($pattern in $forbiddenFilePatterns) {
        $matches = @(Get-ChildItem -LiteralPath $extractionRoot -Recurse -File -Filter $pattern)
        if ($matches.Count -gt 0) {
            throw "Forbidden credential file is present: $($matches[0].FullName)"
        }
    }

    $textExtensions = @('.md', '.txt', '.json', '.yml', '.yaml', '.xml', '.csproj', '.nrproj', '.ps1', '.patch', '.cs')
    foreach ($file in Get-ChildItem -LiteralPath $extractionRoot -Recurse -File) {
        if ($file.Extension -notin $textExtensions) {
            continue
        }
        $text = Get-Content -LiteralPath $file.FullName -Raw
        if ($text -match '(?m)^[+\- ]*\s*<MasterKey>(?!\[REDACTED\])[^<]+</MasterKey>\s*$') {
            throw "Embedded Reactor MasterKey found: $($file.FullName)"
        }
        if ($text -match '(?i)Webhook_key\s*=') {
            throw "Literal webhook credential assignment found: $($file.FullName)"
        }
    }

    [pscustomobject]@{
        ArchivePath = $resolvedArchive
        Sha256 = $actualArchiveHash
        ManifestFileCount = @($manifest.files).Count
        ProductCount = @($state.products).Count
        GitBundleVerified = $true
        CredentialScanPassed = $true
    }
}
finally {
    $resolvedExtraction = [System.IO.Path]::GetFullPath($extractionRoot)
    $systemTemp = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath())
    if (-not $resolvedExtraction.StartsWith($systemTemp, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to remove unexpected extraction path: $resolvedExtraction"
    }
    if (Test-Path -LiteralPath $resolvedExtraction) {
        Remove-Item -LiteralPath $resolvedExtraction -Recurse -Force
    }
}
