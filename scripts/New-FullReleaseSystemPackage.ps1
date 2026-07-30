[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string] $WorkspaceRoot,

    [Parameter(Mandatory)]
    [string] $PluginRoot,

    [Parameter(Mandatory)]
    [string] $OutputPath
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Invoke-Git {
    param(
        [Parameter(Mandatory)]
        [string] $Repository,

        [Parameter(Mandatory)]
        [string[]] $Arguments
    )

    $safeDirectory = $Repository.Replace('\', '/')
    $output = & git -c "safe.directory=$safeDirectory" -C $Repository @Arguments 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "git $($Arguments -join ' ') failed in ${Repository}:`n$($output -join "`n")"
    }
    return @($output)
}

function Copy-RelativeFile {
    param(
        [Parameter(Mandatory)]
        [string] $SourceRoot,

        [Parameter(Mandatory)]
        [string] $RelativePath,

        [Parameter(Mandatory)]
        [string] $DestinationRoot
    )

    $source = Join-Path $SourceRoot $RelativePath
    if (-not (Test-Path -LiteralPath $source -PathType Leaf)) {
        return
    }

    $destination = Join-Path $DestinationRoot $RelativePath
    $destinationParent = Split-Path -Parent $destination
    [System.IO.Directory]::CreateDirectory($destinationParent) | Out-Null
    Copy-Item -LiteralPath $source -Destination $destination
}

function Write-Utf8NoBom {
    param(
        [Parameter(Mandatory)]
        [string] $Path,

        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string] $Content
    )

    $parent = Split-Path -Parent $Path
    [System.IO.Directory]::CreateDirectory($parent) | Out-Null
    [System.IO.File]::WriteAllText($Path, $Content, [System.Text.UTF8Encoding]::new($false))
}

$resolvedWorkspace = (Resolve-Path -LiteralPath $WorkspaceRoot).Path
$resolvedPluginRoot = (Resolve-Path -LiteralPath $PluginRoot).Path
$resolvedOutput = [System.IO.Path]::GetFullPath($OutputPath)
$allowedOutputRoot = [System.IO.Path]::GetFullPath((Join-Path $resolvedWorkspace 'handoff'))

if (-not $resolvedOutput.StartsWith($allowedOutputRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Output must stay under the workspace handoff directory: $allowedOutputRoot"
}

$products = @(
    [pscustomobject]@{ Id = 'PandaFarmer'; Repo = 'PandaFarmer'; Project = 'PandaFarmer.csproj'; Reactor = 'PandaFarmer.nrproj' },
    [pscustomobject]@{ Id = 'PandaFarmerWPF'; Repo = 'PandaFarmerWPF'; Project = 'PandaFarmerWPF.csproj'; Reactor = 'PandaFarmer.nrproj' },
    [pscustomobject]@{ Id = 'PandaTripleTriad'; Repo = 'PandaTripleTriad'; Project = 'PandaTripleTriad.csproj'; Reactor = 'PandaTripleTriad.nrproj' },
    [pscustomobject]@{ Id = 'AnimaWeapons'; Repo = 'AnimaWeapons'; Project = 'AnimaWeapons.csproj'; Reactor = 'AnimaWeapons.nrproj' },
    [pscustomobject]@{ Id = 'MandervilleWeapons'; Repo = 'MandervilleWeapons'; Project = 'MandervilleWeapons.csproj'; Reactor = 'MandervilleWeapons.nrproj' },
    [pscustomobject]@{ Id = 'ZodiacWeapons'; Repo = 'ZodiacWeapons'; Project = 'ZodiacWeapons.csproj'; Reactor = 'ZodiacWeapons.nrproj' },
    [pscustomobject]@{ Id = 'RelicWeapons'; Repo = 'RelicWeapons'; Project = 'RelicWeapons.csproj'; Reactor = 'PandaFarmer.nrproj' },
    [pscustomobject]@{ Id = 'SplendorousTools'; Repo = 'SplendorousTools'; Project = 'SplendorousTools.csproj'; Reactor = 'SplendorousTools.nrproj' },
    [pscustomobject]@{ Id = 'BeastTribes'; Repo = 'BeastTribesPlugin'; Project = 'BeastTribes.csproj'; Reactor = 'BeastTribes.nrproj' }
)

$stagingRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("full-release-system-" + [guid]::NewGuid().ToString('N'))
[System.IO.Directory]::CreateDirectory($stagingRoot) | Out-Null

try {
    $automationDestination = Join-Path $stagingRoot 'automation-repository'
    [System.IO.Directory]::CreateDirectory($automationDestination) | Out-Null

    $trackedFiles = Invoke-Git -Repository $resolvedWorkspace -Arguments @('ls-files')
    foreach ($relativePath in $trackedFiles) {
        if ([string]::IsNullOrWhiteSpace($relativePath)) {
            continue
        }
        Copy-RelativeFile -SourceRoot $resolvedWorkspace -RelativePath $relativePath -DestinationRoot $automationDestination
    }

    $bundlePath = Join-Path $stagingRoot 'automation-repository.bundle'
    & git -c "safe.directory=$($resolvedWorkspace.Replace('\', '/'))" -C $resolvedWorkspace bundle create $bundlePath --all
    if ($LASTEXITCODE -ne 0) {
        throw 'Failed to create the automation repository Git bundle.'
    }

    $repoStates = @()
    foreach ($product in $products) {
        $repository = Join-Path $resolvedPluginRoot $product.Repo
        $resolvedRepository = (Resolve-Path -LiteralPath $repository).Path
        $destination = Join-Path $stagingRoot ("plugin-integration\" + $product.Id)
        [System.IO.Directory]::CreateDirectory($destination) | Out-Null

        $branch = (Invoke-Git -Repository $resolvedRepository -Arguments @('branch', '--show-current')) -join ''
        $head = (Invoke-Git -Repository $resolvedRepository -Arguments @('rev-parse', 'HEAD')) -join ''
        $remote = (Invoke-Git -Repository $resolvedRepository -Arguments @('remote', 'get-url', 'origin')) -join ''
        $status = (Invoke-Git -Repository $resolvedRepository -Arguments @('status', '--short', '--branch')) -join "`n"
        $diff = (Invoke-Git -Repository $resolvedRepository -Arguments @('diff', '--binary', '--no-ext-diff')) -join "`n"
        $cachedDiff = (Invoke-Git -Repository $resolvedRepository -Arguments @('diff', '--cached', '--binary', '--no-ext-diff')) -join "`n"

        # A deleted MasterKey value would otherwise appear in a patch. Never package it.
        $diff = [regex]::Replace($diff, '(?s)<MasterKey>.*?</MasterKey>', '<MasterKey>[REDACTED]</MasterKey>')
        $cachedDiff = [regex]::Replace($cachedDiff, '(?s)<MasterKey>.*?</MasterKey>', '<MasterKey>[REDACTED]</MasterKey>')

        Write-Utf8NoBom -Path (Join-Path $destination 'git-status.txt') -Content ($status + "`n")
        Write-Utf8NoBom -Path (Join-Path $destination 'working-tree.patch') -Content ($diff + "`n")
        Write-Utf8NoBom -Path (Join-Path $destination 'staged.patch') -Content ($cachedDiff + "`n")

        $integrationFiles = @(
            $product.Project,
            $product.Reactor,
            'Loader.cs',
            'Properties\AssemblyInfo.cs',
            'packages.config',
            'NuGet.config',
            'Directory.Build.props',
            'Directory.Build.targets',
            'global.json'
        )
        foreach ($relativePath in $integrationFiles) {
            Copy-RelativeFile -SourceRoot $resolvedRepository -RelativePath $relativePath -DestinationRoot $destination
        }

        $workflowRoot = Join-Path $resolvedRepository '.github\workflows'
        if (Test-Path -LiteralPath $workflowRoot -PathType Container) {
            foreach ($workflow in Get-ChildItem -LiteralPath $workflowRoot -File) {
                if ($workflow.Extension -in @('.yml', '.yaml')) {
                    Copy-RelativeFile `
                        -SourceRoot $resolvedRepository `
                        -RelativePath (".github\workflows\" + $workflow.Name) `
                        -DestinationRoot $destination
                }
            }
        }

        $repoStates += [pscustomobject]@{
            productId = $product.Id
            localRepository = $resolvedRepository
            branch = $branch
            head = $head
            remote = $remote
            status = $status
        }
    }

    $authRoot = Join-Path $resolvedPluginRoot 'Auth'
    $authWorkflow = '.gitea\workflows\release-auth.yaml'
    Copy-RelativeFile `
        -SourceRoot $authRoot `
        -RelativePath $authWorkflow `
        -DestinationRoot (Join-Path $stagingRoot 'panda-auth-reference')

    $automationHead = (Invoke-Git -Repository $resolvedWorkspace -Arguments @('rev-parse', 'HEAD')) -join ''
    $automationStatus = (Invoke-Git -Repository $resolvedWorkspace -Arguments @('status', '--short', '--branch')) -join "`n"

    $readme = @"
# Full Plugin Release System Package

Generated: $([DateTimeOffset]::Now.ToString('u'))

This package contains:

- the complete tracked `LlamaMagic/plugin-release-automation` working tree;
- a Git bundle containing the automation repository's full history, branches, and tags;
- the current integration files for all nine scoped plugins;
- redacted working-tree and staged patches plus Git state for each plugin;
- the existing Panda Auth Reactor release workflow as a reference;
- plans, artifact contracts, required configuration, validation, and handoff documents.

Security exclusions:

- no `license.v3lic` or encoded runner license;
- no webhook credential;
- no embedded Reactor MasterKey value;
- no build outputs, NuGet caches, VPS files, or prior handoff ZIPs;
- no complete proprietary plugin source tree.

Automation HEAD: $automationHead

Use `automation-repository.bundle` to recreate the automation Git repository:

``````
git clone automation-repository.bundle plugin-release-automation
``````

The `plugin-integration` directory is sufficient to review and reapply every release-system change
without packaging the plugins' unrelated source code.
"@
    Write-Utf8NoBom -Path (Join-Path $stagingRoot 'README.md') -Content $readme

    $state = [pscustomobject]@{
        generatedAt = [DateTimeOffset]::Now.ToString('o')
        automation = [pscustomobject]@{
            repository = 'https://github.com/LlamaMagic/plugin-release-automation'
            head = $automationHead
            status = $automationStatus
        }
        products = $repoStates
    }
    Write-Utf8NoBom `
        -Path (Join-Path $stagingRoot 'REPOSITORY_STATE.json') `
        -Content ($state | ConvertTo-Json -Depth 8)

    $forbiddenFilePatterns = @(
        'license.v3lic',
        '*.pfx',
        '*.p12',
        '*.pem',
        '*.snk'
    )
    foreach ($pattern in $forbiddenFilePatterns) {
        $forbiddenFiles = @(Get-ChildItem -LiteralPath $stagingRoot -Recurse -File -Filter $pattern)
        if ($forbiddenFiles.Count -gt 0) {
            throw "Forbidden credential file was staged: $($forbiddenFiles[0].FullName)"
        }
    }

    $textExtensions = @('.md', '.txt', '.json', '.yml', '.yaml', '.xml', '.csproj', '.nrproj', '.ps1', '.patch', '.cs')
    foreach ($file in Get-ChildItem -LiteralPath $stagingRoot -Recurse -File) {
        if ($file.Extension -notin $textExtensions) {
            continue
        }
        $text = Get-Content -LiteralPath $file.FullName -Raw
        if ($text -match '(?m)^[+\- ]*\s*<MasterKey>(?!\[REDACTED\])[^<]+</MasterKey>\s*$') {
            throw "Embedded Reactor MasterKey found in package staging: $($file.FullName)"
        }
        if ($text -match '(?i)Webhook_key\s*=') {
            throw "Literal webhook credential assignment found in package staging: $($file.FullName)"
        }
    }

    $manifestFiles = @(
        Get-ChildItem -LiteralPath $stagingRoot -Recurse -File |
            Sort-Object FullName |
            ForEach-Object {
                [pscustomobject]@{
                    path = $_.FullName.Substring($stagingRoot.Length).
                        TrimStart([char[]] @('\', '/')).
                        Replace('\', '/')
                    length = $_.Length
                    sha256 = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
                }
            }
    )
    Write-Utf8NoBom `
        -Path (Join-Path $stagingRoot 'MANIFEST.json') `
        -Content (([pscustomobject]@{ files = $manifestFiles }) | ConvertTo-Json -Depth 5)

    $outputParent = Split-Path -Parent $resolvedOutput
    [System.IO.Directory]::CreateDirectory($outputParent) | Out-Null
    if (Test-Path -LiteralPath $resolvedOutput) {
        Remove-Item -LiteralPath $resolvedOutput -Force
    }

    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [System.IO.Compression.ZipFile]::CreateFromDirectory(
        $stagingRoot,
        $resolvedOutput,
        [System.IO.Compression.CompressionLevel]::Optimal,
        $false
    )

    $archiveHash = (Get-FileHash -LiteralPath $resolvedOutput -Algorithm SHA256).Hash.ToLowerInvariant()
    Write-Utf8NoBom `
        -Path "$resolvedOutput.sha256" `
        -Content "$archiveHash  $([System.IO.Path]::GetFileName($resolvedOutput))`n"

    [pscustomobject]@{
        ArchivePath = $resolvedOutput
        Sha256Path = "$resolvedOutput.sha256"
        Sha256 = $archiveHash
        FileCount = $manifestFiles.Count + 1
        ProductCount = $products.Count
    }
}
finally {
    $resolvedStaging = [System.IO.Path]::GetFullPath($stagingRoot)
    $systemTemp = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath())
    if (-not $resolvedStaging.StartsWith($systemTemp, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to remove unexpected staging path: $resolvedStaging"
    }
    if (Test-Path -LiteralPath $resolvedStaging) {
        Remove-Item -LiteralPath $resolvedStaging -Recurse -Force
    }
}
