param([string]$RepoRoot=(Split-Path -Parent (Split-Path -Parent $PSScriptRoot)))
Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'

$workerPath=Join-Path $RepoRoot 'HuymaierConsoleUpdateWorker.ps1'
$selfUpdaterPath=Join-Path $RepoRoot 'HuymaierSelfUpdater.ps1'
$shellPath=Join-Path $RepoRoot 'HuymaierShellRedesign.ps1'
foreach($path in @($workerPath,$selfUpdaterPath,$shellPath)){if(-not(Test-Path -LiteralPath $path -PathType Leaf)){throw "Missing updater source: $path"}}

$worker=Get-Content -Raw -LiteralPath $workerPath -Encoding UTF8
$selfUpdater=Get-Content -Raw -LiteralPath $selfUpdaterPath -Encoding UTF8
$shell=Get-Content -Raw -LiteralPath $shellPath -Encoding UTF8

# Parse the production worker and execute only its pure version helper functions.
$tokens=$null;$errors=$null
$ast=[Management.Automation.Language.Parser]::ParseInput($worker,[ref]$tokens,[ref]$errors)
if($errors.Count){throw ('HuymaierConsoleUpdateWorker.ps1 parse failed: '+(($errors|ForEach-Object{$_.Message}) -join '; '))}
foreach($name in @('Parse-Version','Get-HcComparableVersion')){
    $definition=$ast.Find({param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq $name},$true)
    if($null -eq $definition){throw "Missing production updater helper $name"}
    . ([scriptblock]::Create($definition.Extent.Text))
}

# The public v0.3.0 tag intentionally aliases the exact old v0.26.5 package.
# This gate prevents the version reset from making the update UI show a release
# while withholding the Download/Install action.
if((Get-HcComparableVersion 'v0.3.0') -ne [version]'0.26.5'){throw 'v0.3.0 is not mapped to the legacy v0.26.5 ordering point.'}
if(-not((Get-HcComparableVersion 'v0.3.0') -gt (Get-HcComparableVersion '0.26.2'))){throw 'A legacy v0.26.2 install would not consider public v0.3.0 newer.'}
if((Get-HcComparableVersion 'v0.3.0') -gt (Get-HcComparableVersion '0.26.5')){throw 'Exact v0.26.5 payload would incorrectly update to its v0.3.0 alias.'}
if(-not((Get-HcComparableVersion 'v0.30.1') -gt (Get-HcComparableVersion '0.26.2'))){throw 'Legacy v0.26.2 cannot update directly to v0.30.1.'}
if(-not((Get-HcComparableVersion 'v0.30.1') -gt (Get-HcComparableVersion 'v0.3.0'))){throw 'v0.30.1 is not newer than the public v0.3.0 baseline.'}

foreach($token in @(
    "'HuymaierConsole/'+`$CurrentVersion",
    'Select-PackageAsset -Release $release -VersionText $latestVersionText',
    "`$expected='HC'+`$digits+'.zip'",
    "`$sidecarPath=`$target+'.sha256'",
    'Downloaded update ZIP does not match the SHA-256 published with the GitHub Release.'
)){if(-not$worker.Contains($token)){throw "Missing updater download/integrity contract: $token"}}

foreach($token in @(
    "`$sidecar=`$PackagePath+'.sha256'",
    'Wait-HcProcessExit -Id $ParentProcessId -TimeoutSeconds 90',
    "'-SilentUpdate'",
    'Downloaded update ZIP does not match the SHA-256 published with the release.',
    "Start-Process -FilePath `$relaunch -WorkingDirectory `$InstallRoot"
)){if(-not$selfUpdater.Contains($token)){throw "Missing self-updater handoff/integrity contract: $token"}}

foreach($token in @(
    "'console-update-download' {Start-HcConsoleUpdateWorker 'Download';return `$true}",
    "'console-update-install' {Start-HcConsoleSelfUpdate;return `$true}",
    '-ParentProcessId $PID -InstallRoot $install',
    '$script:AllowWindowClose=$true;$script:Window.Close()'
)){if(-not$shell.Contains($token)){throw "Missing shell self-update activation contract: $token"}}

Write-Host 'consoleUpdateVersionResetBridgeGate: success'
Write-Host 'consoleUpdateLegacyTo0301Gate: success'
Write-Host 'consoleUpdateIntegrityAndHandoffGate: success'