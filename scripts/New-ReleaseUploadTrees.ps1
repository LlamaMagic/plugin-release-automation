[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string] $ArchivePath,

    [Parameter(Mandatory)]
    [string] $Sha256Path,

    [Parameter(Mandatory)]
    [string] $ProductId,

    [Parameter(Mandatory)]
    [string] $Version,

    [Parameter(Mandatory)]
    [ValidateSet('staging', 'production')]
    [string] $Destination,

    [Parameter(Mandatory)]
    [string] $ObjectPrefix,

    [Parameter(Mandatory)]
    [string] $OutputRoot
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$archive = (Resolve-Path -LiteralPath $ArchivePath).Path
$checksum = (Resolve-Path -LiteralPath $Sha256Path).Path
$root = [System.IO.Path]::GetFullPath($OutputRoot)
$channel = if ($Destination -eq 'production') { 'stable' } else { 'staging' }
$prefix = $ObjectPrefix.Trim([char[]] @('\', '/'))
$versionedRelativePath = "$prefix/$ProductId/$channel/$Version"
$archiveName = [System.IO.Path]::GetFileName($archive)

if (Test-Path -LiteralPath $root) {
    throw "Upload tree output already exists: $root"
}

$r2Root = Join-Path $root 'r2'
$cosRoot = Join-Path $root 'cos'

function Copy-ReleaseFile {
    param(
        [Parameter(Mandatory)]
        [string] $Source,

        [Parameter(Mandatory)]
        [string] $TreeRoot,

        [Parameter(Mandatory)]
        [string] $RelativePath
    )

    $destination = Join-Path $TreeRoot $RelativePath
    [System.IO.Directory]::CreateDirectory((Split-Path -Parent $destination)) | Out-Null
    Copy-Item -LiteralPath $Source -Destination $destination
}

foreach ($treeRoot in @($r2Root, $cosRoot)) {
    Copy-ReleaseFile -Source $archive -TreeRoot $treeRoot -RelativePath "$versionedRelativePath/$archiveName"
    Copy-ReleaseFile -Source $checksum -TreeRoot $treeRoot -RelativePath "$versionedRelativePath/$archiveName.sha256"
}

if ($Destination -eq 'production') {
    $versionFile = Join-Path $root 'Version.txt'
    [System.IO.Directory]::CreateDirectory($root) | Out-Null
    [System.IO.File]::WriteAllText($versionFile, $Version, [System.Text.ASCIIEncoding]::new())

    foreach ($treeRoot in @($r2Root, $cosRoot)) {
        Copy-ReleaseFile -Source $archive -TreeRoot $treeRoot -RelativePath "$prefix/$ProductId/$ProductId.zip"
        Copy-ReleaseFile -Source $checksum -TreeRoot $treeRoot -RelativePath "$prefix/$ProductId/$ProductId.zip.sha256"
        Copy-ReleaseFile -Source $versionFile -TreeRoot $treeRoot -RelativePath "$prefix/$ProductId/Version.txt"
    }

    # Preserve the existing Tencent updater paths while the new prefixed paths are adopted.
    Copy-ReleaseFile -Source $archive -TreeRoot $cosRoot -RelativePath "$ProductId/$ProductId.zip"
    Copy-ReleaseFile -Source $checksum -TreeRoot $cosRoot -RelativePath "$ProductId/$ProductId.zip.sha256"
    Copy-ReleaseFile -Source $versionFile -TreeRoot $cosRoot -RelativePath "$ProductId/Version.txt"
}

[pscustomobject]@{
    R2Root = $r2Root
    CosRoot = $cosRoot
    VersionedObjectKey = "$versionedRelativePath/$archiveName"
    VersionedChecksumKey = "$versionedRelativePath/$archiveName.sha256"
    Channel = $channel
}
