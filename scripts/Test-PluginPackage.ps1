[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string] $ConfigPath,

    [Parameter(Mandatory)]
    [string] $ProductId,

    [Parameter(Mandatory)]
    [string] $ArchivePath,

    [string] $ExpectedVersion
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

Add-Type -AssemblyName System.IO.Compression.FileSystem

$resolvedConfigPath = (Resolve-Path -LiteralPath $ConfigPath).Path
$resolvedArchivePath = (Resolve-Path -LiteralPath $ArchivePath).Path

$configuration = Get-Content -LiteralPath $resolvedConfigPath -Raw | ConvertFrom-Json
$product = $configuration.products.PSObject.Properties[$ProductId].Value
if ($null -eq $product) {
    throw "Product '$ProductId' is not defined in $resolvedConfigPath"
}

$archive = [System.IO.Compression.ZipFile]::OpenRead($resolvedArchivePath)
try {
    $actualEntries = @(
        $archive.Entries |
            Where-Object { -not [string]::IsNullOrEmpty($_.Name) } |
            ForEach-Object { $_.FullName.Replace('\', '/') } |
            Sort-Object
    )
    $expectedEntries = @($product.archiveEntries | ForEach-Object { [string] $_ } | Sort-Object)
    $difference = Compare-Object -ReferenceObject $expectedEntries -DifferenceObject $actualEntries

    if ($difference) {
        $details = $difference | ForEach-Object { "$($_.SideIndicator) $($_.InputObject)" }
        throw "Archive does not match the configured artifact contract:`n$($details -join "`n")"
    }

    if (-not [string]::IsNullOrWhiteSpace($ExpectedVersion)) {
        $versionEntry = $archive.GetEntry('Version.txt')
        $reader = [System.IO.StreamReader]::new($versionEntry.Open())
        try {
            $actualVersion = $reader.ReadToEnd().Trim()
        }
        finally {
            $reader.Dispose()
        }
        if ($actualVersion -ne $ExpectedVersion) {
            throw "Version.txt contains '$actualVersion'; expected '$ExpectedVersion'."
        }
    }
}
finally {
    $archive.Dispose()
}

$hash = (Get-FileHash -LiteralPath $resolvedArchivePath -Algorithm SHA256).Hash.ToLowerInvariant()
[pscustomobject]@{
    ProductId = $ProductId
    ArchivePath = $resolvedArchivePath
    EntryCount = $actualEntries.Count
    Sha256 = $hash
}
