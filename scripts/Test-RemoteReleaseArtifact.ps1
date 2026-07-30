[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string] $Uri,

    [Parameter(Mandatory)]
    [ValidatePattern('^[a-fA-F0-9]{64}$')]
    [string] $ExpectedSha256,

    [ValidateRange(1, 20)]
    [int] $Attempts = 6,

    [ValidateRange(0, 30)]
    [int] $DelaySeconds = 5
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$temporaryPath = Join-Path ([System.IO.Path]::GetTempPath()) ("release-download-" + [guid]::NewGuid().ToString('N'))
try {
    $lastError = $null
    foreach ($attempt in 1..$Attempts) {
        try {
            # The immutable-object preflight can leave a negative CDN cache entry
            # immediately before upload. Use a unique query string so verification
            # reaches the newly uploaded object instead of that stale 404.
            $separator = if ($Uri.Contains('?')) { '&' } else { '?' }
            $requestUri = '{0}{1}release_verify={2}' -f
                $Uri,
                $separator,
                [guid]::NewGuid().ToString('N')
            Invoke-WebRequest `
                -Uri $requestUri `
                -Headers @{ 'Cache-Control' = 'no-cache' } `
                -OutFile $temporaryPath `
                -MaximumRedirection 5
            $lastError = $null
            break
        }
        catch {
            $lastError = $_
            if ($attempt -lt $Attempts) {
                Start-Sleep -Seconds $DelaySeconds
            }
        }
    }
    if ($null -ne $lastError) {
        throw $lastError
    }

    $actualHash = (Get-FileHash -LiteralPath $temporaryPath -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actualHash -ne $ExpectedSha256.ToLowerInvariant()) {
        throw "Remote artifact hash mismatch for $Uri. Expected $ExpectedSha256; found $actualHash."
    }

    [pscustomobject]@{
        Uri = $Uri
        Sha256 = $actualHash
        Bytes = (Get-Item -LiteralPath $temporaryPath).Length
    }
}
finally {
    $resolvedTemporaryPath = [System.IO.Path]::GetFullPath($temporaryPath)
    $systemTemp = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath())
    $systemTempPrefix = $systemTemp.TrimEnd([char[]] @('\', '/')) +
        [System.IO.Path]::DirectorySeparatorChar
    if (-not $resolvedTemporaryPath.StartsWith($systemTempPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to remove unexpected temporary path: $resolvedTemporaryPath"
    }
    if (Test-Path -LiteralPath $resolvedTemporaryPath) {
        Remove-Item -LiteralPath $resolvedTemporaryPath -Force
    }
}
