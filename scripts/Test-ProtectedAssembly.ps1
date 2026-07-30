[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string] $OriginalAssemblyPath,

    [Parameter(Mandatory)]
    [string] $ProtectedAssemblyPath
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$original = (Resolve-Path -LiteralPath $OriginalAssemblyPath).Path
$protected = (Resolve-Path -LiteralPath $ProtectedAssemblyPath).Path
$protectedInfo = Get-Item -LiteralPath $protected

if ($protectedInfo.Length -lt 1024) {
    throw "Protected assembly is unexpectedly small: $($protectedInfo.Length) bytes."
}

$stream = [System.IO.File]::OpenRead($protected)
try {
    if ($stream.ReadByte() -ne 0x4d -or $stream.ReadByte() -ne 0x5a) {
        throw 'Protected assembly does not have a Windows PE MZ header.'
    }
}
finally {
    $stream.Dispose()
}

$originalHash = (Get-FileHash -LiteralPath $original -Algorithm SHA256).Hash.ToLowerInvariant()
$protectedHash = (Get-FileHash -LiteralPath $protected -Algorithm SHA256).Hash.ToLowerInvariant()
if ($originalHash -eq $protectedHash) {
    throw 'Reactor output is byte-identical to the unprotected assembly.'
}

[pscustomobject]@{
    OriginalAssembly = $original
    ProtectedAssembly = $protected
    ProtectedSize = $protectedInfo.Length
    OriginalSha256 = $originalHash
    ProtectedSha256 = $protectedHash
}
