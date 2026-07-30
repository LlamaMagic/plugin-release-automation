[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string] $TemplatePath,

    [Parameter(Mandatory)]
    [string] $OutputPath,

    [Parameter(Mandatory)]
    [string] $ProductId,

    [Parameter(Mandatory)]
    [string] $ProjectFile,

    [Parameter(Mandatory)]
    [string] $ReactorProjectFile,

    [Parameter(Mandatory)]
    [string] $AutomationRef,

    [Parameter(Mandatory)]
    [bool] $WebhookEnabled
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$template = Get-Content -LiteralPath $TemplatePath -Raw
$replacements = [ordered]@{
    '__PRODUCT_ID__' = $ProductId
    '__PROJECT_FILE__' = $ProjectFile
    '__REACTOR_PROJECT_FILE__' = $ReactorProjectFile
    '__AUTOMATION_REF__' = $AutomationRef
    '__WEBHOOK_ENABLED__' = $WebhookEnabled.ToString().ToLowerInvariant()
}
foreach ($entry in $replacements.GetEnumerator()) {
    $template = $template.Replace($entry.Key, $entry.Value)
}

if ($template -match '__[A-Z_]+__') {
    throw "Generated workflow still contains an unresolved template token: $($Matches[0])"
}

$resolvedOutput = [System.IO.Path]::GetFullPath($OutputPath)
[System.IO.Directory]::CreateDirectory((Split-Path -Parent $resolvedOutput)) | Out-Null
[System.IO.File]::WriteAllText($resolvedOutput, $template, [System.Text.UTF8Encoding]::new($false))

[pscustomobject]@{
    ProductId = $ProductId
    OutputPath = $resolvedOutput
    AutomationRef = $AutomationRef
    WebhookEnabled = $WebhookEnabled
}
