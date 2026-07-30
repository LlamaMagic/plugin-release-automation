[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string] $ConfigPath,

    [Parameter(Mandatory)]
    [string] $ProductId,

    [Parameter(Mandatory)]
    [string] $RepositoryRoot,

    [Parameter(Mandatory)]
    [string] $BuildOutputDirectory,

    [Parameter(Mandatory)]
    [string] $Version,

    [Parameter(Mandatory)]
    [string] $ReleaseOutputDirectory,

    [string] $AssemblyPath,

    [string] $PandaAuthPath
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Resolve-RequiredPath {
    param(
        [Parameter(Mandatory)]
        [string] $Path,

        [Parameter(Mandatory)]
        [string] $Description,

        [switch] $Directory
    )

    if (-not (Test-Path -LiteralPath $Path -PathType $(if ($Directory) { 'Container' } else { 'Leaf' }))) {
        throw "$Description was not found: $Path"
    }

    return (Resolve-Path -LiteralPath $Path).Path
}

$resolvedConfigPath = Resolve-RequiredPath -Path $ConfigPath -Description 'Product configuration'
$resolvedRepositoryRoot = Resolve-RequiredPath -Path $RepositoryRoot -Description 'Repository root' -Directory
$resolvedBuildOutput = Resolve-RequiredPath -Path $BuildOutputDirectory -Description 'Build output directory' -Directory

$parsedVersion = $null
if (-not [System.Version]::TryParse($Version, [ref] $parsedVersion)) {
    throw "Version must be a numeric System.Version value such as 1.2.3 or 1.2.3.4: $Version"
}

$configuration = Get-Content -LiteralPath $resolvedConfigPath -Raw | ConvertFrom-Json
$product = $configuration.products.PSObject.Properties[$ProductId].Value
if ($null -eq $product) {
    throw "Product '$ProductId' is not defined in $resolvedConfigPath"
}

if ([string]::IsNullOrWhiteSpace($AssemblyPath)) {
    $AssemblyPath = Join-Path $resolvedBuildOutput "$($product.projectName).dll"
}
if ([string]::IsNullOrWhiteSpace($PandaAuthPath)) {
    $PandaAuthPath = Join-Path $resolvedBuildOutput 'PandaAuth.dll'
}

$resolvedAssemblyPath = Resolve-RequiredPath -Path $AssemblyPath -Description 'Plugin assembly'
$resolvedPandaAuthPath = Resolve-RequiredPath -Path $PandaAuthPath -Description 'PandaAuth assembly'
$loaderTemplatePath = Join-Path $resolvedRepositoryRoot $product.loaderTemplate
$resolvedLoaderTemplatePath = Resolve-RequiredPath -Path $loaderTemplatePath -Description 'Loader template'

$resolvedReleaseOutput = [System.IO.Path]::GetFullPath($ReleaseOutputDirectory)
[System.IO.Directory]::CreateDirectory($resolvedReleaseOutput) | Out-Null

$stagingRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("panda-plugin-package-" + [guid]::NewGuid().ToString('N'))
[System.IO.Directory]::CreateDirectory($stagingRoot) | Out-Null

try {
    Copy-Item -LiteralPath $resolvedAssemblyPath -Destination (Join-Path $stagingRoot "$ProductId.dll")
    Copy-Item -LiteralPath $resolvedPandaAuthPath -Destination (Join-Path $stagingRoot 'PandaAuth.dll')

    $loader = Get-Content -LiteralPath $resolvedLoaderTemplatePath -Raw
    $loader = $loader.Replace('__TARGET__', $ProductId).Replace('__VERSION__', $Version)
    [System.IO.File]::WriteAllText(
        (Join-Path $stagingRoot "$($ProductId)Loader.cs"),
        $loader,
        [System.Text.UTF8Encoding]::new($false)
    )
    [System.IO.File]::WriteAllText(
        (Join-Path $stagingRoot 'Version.txt'),
        $Version,
        [System.Text.ASCIIEncoding]::new()
    )

    foreach ($file in $product.additionalFiles) {
        $sourcePath = Join-Path $resolvedRepositoryRoot ([string] $file.source)
        $resolvedSourcePath = Resolve-RequiredPath -Path $sourcePath -Description "Additional package file '$($file.source)'"
        $destinationPath = Join-Path $stagingRoot ([string] $file.destination)
        $destinationParent = Split-Path -Parent $destinationPath
        [System.IO.Directory]::CreateDirectory($destinationParent) | Out-Null
        Copy-Item -LiteralPath $resolvedSourcePath -Destination $destinationPath
    }

    $actualEntries = @(
        Get-ChildItem -LiteralPath $stagingRoot -File -Recurse |
            ForEach-Object {
                $_.FullName.Substring($stagingRoot.Length).
                    TrimStart([char[]] @('\', '/')).
                    Replace('\', '/')
            } |
            Sort-Object
    )
    $expectedEntries = @($product.archiveEntries | ForEach-Object { [string] $_ } | Sort-Object)

    $difference = Compare-Object -ReferenceObject $expectedEntries -DifferenceObject $actualEntries
    if ($difference) {
        $details = $difference | ForEach-Object { "$($_.SideIndicator) $($_.InputObject)" }
        throw "Staged package does not match the configured artifact contract:`n$($details -join "`n")"
    }

    $archivePath = Join-Path $resolvedReleaseOutput "$ProductId-$Version.zip"
    if (Test-Path -LiteralPath $archivePath) {
        Remove-Item -LiteralPath $archivePath -Force
    }

    Compress-Archive -Path (Join-Path $stagingRoot '*') -DestinationPath $archivePath -CompressionLevel Optimal

    $hash = (Get-FileHash -LiteralPath $archivePath -Algorithm SHA256).Hash.ToLowerInvariant()
    $hashPath = "$archivePath.sha256"
    [System.IO.File]::WriteAllText(
        $hashPath,
        "$hash  $([System.IO.Path]::GetFileName($archivePath))`n",
        [System.Text.ASCIIEncoding]::new()
    )

    [pscustomobject]@{
        ProductId = $ProductId
        Version = $Version
        ArchivePath = $archivePath
        Sha256Path = $hashPath
        Sha256 = $hash
    }
}
finally {
    $resolvedStagingRoot = [System.IO.Path]::GetFullPath($stagingRoot)
    $resolvedSystemTemp = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath())
    if (-not $resolvedStagingRoot.StartsWith($resolvedSystemTemp, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to remove unexpected staging path: $resolvedStagingRoot"
    }
    if (Test-Path -LiteralPath $resolvedStagingRoot) {
        Remove-Item -LiteralPath $resolvedStagingRoot -Recurse -Force
    }
}
