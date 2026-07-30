[CmdletBinding()]
param(
    [Parameter(Mandatory, ValueFromPipeline)]
    [string[]] $ProjectPath
)

begin {
    $ErrorActionPreference = 'Stop'
    Set-StrictMode -Version Latest
}

process {
    foreach ($path in $ProjectPath) {
        $resolvedPath = (Resolve-Path -LiteralPath $path).Path
        if ([System.IO.Path]::GetExtension($resolvedPath) -ne '.nrproj') {
            throw "Refusing to modify a non-Reactor project: $resolvedPath"
        }

        $content = Get-Content -LiteralPath $resolvedPath -Raw
        $pattern = '(?s)<MasterKey>.+?</MasterKey>'
        $matches = [regex]::Matches($content, $pattern)

        if ($matches.Count -eq 0) {
            if ($content -match '<MasterKey\s*/>') {
                Write-Host "Already sanitized: $resolvedPath"
                continue
            }
            throw "No Reactor MasterKey element was found in $resolvedPath"
        }
        if ($matches.Count -ne 1) {
            throw "Expected one Reactor MasterKey element in $resolvedPath; found $($matches.Count)."
        }

        $sanitized = [regex]::Replace($content, $pattern, '<MasterKey />')
        [System.IO.File]::WriteAllText(
            $resolvedPath,
            $sanitized,
            [System.Text.UTF8Encoding]::new($false)
        )
        Write-Host "Sanitized Reactor master key: $resolvedPath"
    }
}
