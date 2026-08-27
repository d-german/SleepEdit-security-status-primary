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
    if ($content -match "'unsafe-inline'") {
        throw "$Description permits unsafe inline content: $Path"
    }
    $style = [regex]::Match($content, '(?s)<style>(.*?)</style>').Groups[1].Value.Replace("`r`n", "`n")
    $declaredHash = [regex]::Match($content, "style-src 'sha256-([^']+)'").Groups[1].Value
    $actualHash = [Convert]::ToBase64String(
        [Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($style)))
    if (-not $declaredHash -or $declaredHash -ne $actualHash) {
        throw "$Description has an invalid inline stylesheet hash: $Path"
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

if (-not (Test-Path -LiteralPath $indexPath -PathType Leaf)) {
    throw "The public report index is missing: $indexPath"
}

Assert-ReportHtml -Path $indexPath -Description 'The public report index'



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

Write-Host "Validated $($reportFiles.Count) public report(s) and the report index."
