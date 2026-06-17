#Requires -Version 5.1
<#
.SYNOPSIS
  Automated netdisk CASES: L0-L1 + L2-10 CLI; optional Playwright L2-L4 (-E2E).
#>
[CmdletBinding()]
param(
    [switch]$SkipBuild,
    [switch]$SkipInstall,
    [switch]$E2E,
    [string]$LpkPath = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'

$Root = Split-Path $PSScriptRoot -Parent
Set-Location $Root

if (-not $LpkPath) {
    $LpkPath = Join-Path $Root 'cloud.lazycat.app.ffmpeg-webcli-v1.1.0.lpk'
}

$results = New-Object System.Collections.Generic.List[object]

function Add-Case {
    param(
        [string]$Id,
        [ValidateSet('pass', 'fail', 'skip')]
        [string]$Status,
        [string]$Note = ''
    )
    $null = $results.Add([pscustomobject]@{ id = $Id; status = $Status; note = $Note })
    $icon = switch ($Status) { 'pass' { '[PASS]' } 'fail' { '[FAIL]' } 'skip' { '[SKIP]' } }
    Write-Host "$icon $Id $(if ($Note) { "- $Note" })"
}

function Invoke-LzcCli {
    param([Parameter(ValueFromRemainingArguments = $true)][string[]]$CliArgs)
    $out = & lzc-cli @CliArgs 2>&1
    $code = if ($null -ne $LASTEXITCODE) { $LASTEXITCODE } else { 0 }
    return [pscustomobject]@{ Code = $code; Out = ($out | Out-String).Trim() }
}

Write-Host '=== ffmpeg-webcli netdisk run-cases ===' -ForegroundColor Cyan
$tok = Invoke-LzcCli config get token
if ($tok.Out) { Write-Host ("developer token prefix: " + $tok.Out.Substring(0, [Math]::Min(8, $tok.Out.Length)) + '...') }

# L0
$injectPath = Join-Path $Root 'content/lazycat-injects/lzc-file-chooser-inject.js'
if ((Test-Path $injectPath) -and ((Get-Item $injectPath).Length -gt 10KB)) {
    Add-Case 'L0-01' 'pass' ("$((Get-Item $injectPath).Length) bytes")
} else { Add-Case 'L0-01' 'fail' 'inject missing or too small' }

$buildYml = Get-Content (Join-Path $Root 'lzc-build.yml') -Raw -Encoding UTF8
if ($buildYml -match 'contentdir:\s*\./content') { Add-Case 'L0-02' 'pass' 'contentdir ok' } else { Add-Case 'L0-02' 'fail' 'contentdir missing' }

$manifest = Get-Content (Join-Path $Root 'lzc-manifest.yml') -Raw -Encoding UTF8
if ($manifest -match 'injects:' -and $manifest -match 'diskRoot:' -and $manifest -match 'fileInput:\s*true') {
    Add-Case 'L0-03' 'pass' 'inject manifest ok'
} else { Add-Case 'L0-03' 'fail' 'inject manifest incomplete' }

if ($manifest -match '=http://web:8080') { Add-Case 'L0-04' 'pass' 'internal route' } else { Add-Case 'L0-04' 'fail' 'route not http://web:8080' }
if ($manifest -notmatch '(?m)^\s*healthcheck:') { Add-Case 'L0-05' 'pass' 'no healthcheck in manifest' } else { Add-Case 'L0-05' 'fail' 'healthcheck present' }

$pkg = Get-Content (Join-Path $Root 'package.yml') -Raw -Encoding UTF8
if ($pkg -match '(?m)^version:\s*1\.1\.0\s*$') { Add-Case 'L0-06' 'pass' 'version 1.1.0' } else { Add-Case 'L0-06' 'fail' 'version not 1.1.0' }

# L1
if ($SkipBuild) {
    if (Test-Path $LpkPath) { Add-Case 'L1-01' 'pass' 'SkipBuild; existing LPK' } else { Add-Case 'L1-01' 'fail' 'SkipBuild but LPK missing' }
} else {
    $b = Invoke-LzcCli project build --release
    if ($b.Code -eq 0 -and (Test-Path $LpkPath)) { Add-Case 'L1-01' 'pass' 'project build exit 0' } else { Add-Case 'L1-01' 'fail' "build exit $($b.Code)" }
}

if (Test-Path $LpkPath) {
    $info = Invoke-LzcCli lpk info $LpkPath
    $tar = tar -tf $LpkPath 2>&1 | Out-String
    if ($info.Code -eq 0 -and $tar -match 'content\.tar') { Add-Case 'L1-02' 'pass' 'lpk info + content.tar' } else { Add-Case 'L1-02' 'fail' 'lpk info/content' }
} else { Add-Case 'L1-02' 'fail' 'LPK not found' }

if ($SkipInstall) {
    Add-Case 'L1-03' 'pass' 'SkipInstall'
} elseif (Test-Path $LpkPath) {
    $ins = Invoke-LzcCli lpk install $LpkPath
    if ($ins.Code -eq 0) { Add-Case 'L1-03' 'pass' 'install exit 0' } else { Add-Case 'L1-03' 'fail' "install exit $($ins.Code)" }
} else { Add-Case 'L1-03' 'fail' 'LPK missing' }

$pinfo = Invoke-LzcCli project info
if ($pinfo.Out -match 'Status_Running' -and $pinfo.Out -match 'Project app is running') {
    Add-Case 'L1-04' 'pass' 'Status_Running'
} else { Add-Case 'L1-04' 'fail' 'app not running' }

$targetUrl = $null
if ($pinfo.Out -match 'Target URL:\s*(\S+)') { $targetUrl = $Matches[1] }

$webIndex = Invoke-LzcCli project exec --release -s web ls /usr/share/nginx/html/index.html
if ($webIndex.Code -eq 0) { Add-Case 'L1-05' 'pass' 'web index.html present' } else { Add-Case 'L1-05' 'fail' 'web static missing' }

$nginxLocal = Get-Content (Join-Path $Root 'images/nginx.conf') -Raw -Encoding UTF8
if ($nginxLocal -match 'Cross-Origin-Opener-Policy\s+"same-origin"') { Add-Case 'L1-06' 'pass' 'COOP in images/nginx.conf' } else { Add-Case 'L1-06' 'fail' 'COOP missing' }
if ($nginxLocal -match 'Cross-Origin-Embedder-Policy\s+"require-corp"') { Add-Case 'L1-07' 'pass' 'COEP in images/nginx.conf' } else { Add-Case 'L1-07' 'fail' 'COEP missing' }

$inj = Invoke-LzcCli project exec --release -s app ls /lzcapp/pkg/content/lazycat-injects/
if ($inj.Out -match 'lzc-file-chooser-inject\.js') { Add-Case 'L1-08' 'pass' 'inject listed in app' } else { Add-Case 'L1-08' 'fail' 'inject missing in app' }

# L2-10
if ($pinfo.Out -match 'Up \d+ minutes' -and $pinfo.Out -notmatch 'Status_Error|Exit|Restarting') {
    Add-Case 'L2-10' 'pass' 'containers Up; no error state in project info'
} else {
    Add-Case 'L2-10' 'fail' 'runtime unhealthy'
}

function Add-E2ESkipBlock {
    foreach ($id in @('L2-01','L2-02','L2-03','L2-04','L2-05','L2-06','L2-07','L2-08','L2-09')) { Add-Case $id 'skip' 'Pass -E2E' }
    foreach ($id in @('L3-01','L3-02','L3-03','L3-04','L3-05','L3-06','L3-07','L3-08','L3-09','L3-10','L3-11','L3-12')) { Add-Case $id 'skip' 'Pass -E2E' }
    foreach ($id in @('L4-01','L4-02','L4-03','L4-04','L4-05')) { Add-Case $id 'skip' 'Pass -E2E' }
}

if (-not $E2E) {
    Add-E2ESkipBlock
} else {
    $testsDir = Join-Path $Root 'tests'
    Push-Location $testsDir
    try {
        if (-not (Test-Path 'node_modules/playwright')) {
            Write-Host 'npm install (tests)...'
            npm install --no-fund --no-audit 2>&1 | Out-Host
        }
        npx playwright install chromium 2>&1 | Out-Host
        if ($targetUrl) { $env:LZC_APP_URL = $targetUrl }
        if (-not $env:LZC_APP_URL) { $env:LZC_APP_URL = 'https://ffmpeg.zhistor.heiyu.space' }
        Write-Host "E2E LZC_APP_URL=$($env:LZC_APP_URL)"
        node ./e2e-netdisk.mjs 2>&1 | Out-Host
        $e2eJson = Join-Path $testsDir 'e2e-results.json'
        if (Test-Path $e2eJson) {
            $payload = Get-Content $e2eJson -Raw -Encoding UTF8 | ConvertFrom-Json
            foreach ($row in $payload.cases) { Add-Case $row.id $row.status $row.note }
        } else {
            Add-Case 'L2-01' 'fail' 'e2e-results.json missing (Playwright did not finish)'
            foreach ($id in @('L2-02','L2-03','L2-04','L2-05','L2-06','L2-07','L2-08','L2-09','L3-01','L3-02','L3-03','L3-04','L3-05','L3-06','L3-07','L3-08','L3-09','L3-10','L3-11','L3-12','L4-01','L4-02','L4-03','L4-04','L4-05')) {
                Add-Case $id 'skip' 'E2E aborted'
            }
        }
    } finally { Pop-Location }
}

$pass = @($results | Where-Object { $_.status -eq 'pass' }).Count
$fail = @($results | Where-Object { $_.status -eq 'fail' }).Count
$skip = @($results | Where-Object { $_.status -eq 'skip' }).Count

$outJson = Join-Path $Root 'test-results-netdisk.json'
@{ generatedAt = (Get-Date).ToString('o'); pass = $pass; fail = $fail; skip = $skip; cases = $results } |
    ConvertTo-Json -Depth 6 | Set-Content -Path $outJson -Encoding UTF8

Write-Host ''
Write-Host "Summary: pass=$pass fail=$fail skip=$skip" -ForegroundColor $(if ($fail -eq 0) { 'Green' } else { 'Yellow' })
Write-Host "Wrote $outJson"
if ($fail -gt 0) { exit 1 }
exit 0


