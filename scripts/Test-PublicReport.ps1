[CmdletBinding()]
param(
    [Parameter()]
    [string]$SiteRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")),

    [switch]$RequireMainReport
)

$ErrorActionPreference = 'Stop'

function Assert-ReportHtml {
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string]$Description
    )

    $content = Get-Content -LiteralPath $Path -Raw
    if ($content -notmatch '(?i)<!doctype html>') {
        throw "$Description is not a complete HTML document: $Path"
    }
    if ($content -notmatch 'Content-Security-Policy') {
        throw "$Description is missing its restrictive Content-Security-Policy: $Path"
    }
    if ($content -match '(?i)raw evidence|open retained artifact|local path') {
        throw "$Description appears to expose raw scanner evidence: $Path"
    }
    if ($content -match '(?i)[a-z]:\\') {
        throw "$Description appears to expose a local filesystem path: $Path"
    }
    if ($content -match '(?i)href=["'']\s*(?:javascript|data):') {
        throw "$Description contains an unsafe link target: $Path"
    }
}

$resolvedRoot = (Resolve-Path -LiteralPath $SiteRoot).Path
$indexPath = Join-Path $resolvedRoot 'index.html'
$reportsPath = Join-Path $resolvedRoot 'reports'
$trendPath = Join-Path $resolvedRoot 'trend/index.html'
$historyPath = Join-Path $resolvedRoot 'data/main-metrics-history.json'

if (-not (Test-Path -LiteralPath $indexPath -PathType Leaf)) {
    throw "The public report index is missing: $indexPath"
}

Assert-ReportHtml -Path $indexPath -Description 'The public report index'

if (-not (Test-Path -LiteralPath $trendPath -PathType Leaf)) {
    throw "The public metrics trend page is missing: $trendPath"
}

Assert-ReportHtml -Path $trendPath -Description 'The public metrics trend page'

if (Test-Path -LiteralPath $historyPath -PathType Leaf) {
    $history = Get-Content -LiteralPath $historyPath -Raw | ConvertFrom-Json
    if ($history.schemaVersion -ne 1 -or $null -eq $history.snapshots) {
        throw "The public metrics history has an unsupported schema: $historyPath"
    }

    $snapshots = @($history.snapshots)
    if (@($snapshots | Where-Object { $_.branch -ne 'main' }).Count -gt 0) {
        throw "The public metrics history contains a non-main snapshot: $historyPath"
    }
    if (@($snapshots.commit | Sort-Object -Unique).Count -ne $snapshots.Count) {
        throw "The public metrics history contains duplicate commits: $historyPath"
    }

    $historyContent = Get-Content -LiteralPath $historyPath -Raw
    if ($historyContent -match '(?i)review this credential|raw evidence|[a-z]:\\') {
        throw "The public metrics history appears to expose raw scanner evidence: $historyPath"
    }
}

$reportFiles = @(Get-ChildItem -LiteralPath $reportsPath -Directory -ErrorAction SilentlyContinue |
    ForEach-Object { Join-Path $_.FullName 'index.html' } |
    Where-Object { Test-Path -LiteralPath $_ -PathType Leaf })

if ($RequireMainReport -and -not ($reportFiles | Where-Object { $_ -match '[\\/]main[\\/]index\.html$' })) {
    throw 'The public report site must contain reports/main/index.html.'
}

foreach ($reportPath in $reportFiles) {
    Assert-ReportHtml -Path $reportPath -Description 'A public branch report'
    $content = Get-Content -LiteralPath $reportPath -Raw
    if ($content -notmatch 'sleepedit-report-branch' -or $content -notmatch 'sleepedit-report-state') {
        throw "A public branch report is missing required branch metadata: $reportPath"
    }
}

Write-Host "Validated $($reportFiles.Count) public report(s), the report index, and the metrics trend page."
