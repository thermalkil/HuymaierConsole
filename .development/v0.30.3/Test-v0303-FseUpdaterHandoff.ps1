Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
$root=(Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$hostPath=Join-Path $root 'HuymaierFSEHost.cs'
$updaterPath=Join-Path $root 'HuymaierSelfUpdater.ps1'
$shellPath=Join-Path $root 'HuymaierShellRedesign.ps1'
foreach($p in @($hostPath,$updaterPath,$shellPath)){if(-not(Test-Path -LiteralPath $p -PathType Leaf)){throw "Required updater source missing: $p"}}

$host=[IO.File]::ReadAllText($hostPath,[Text.Encoding]::UTF8)
$updater=[IO.File]::ReadAllText($updaterPath,[Text.Encoding]::UTF8)
$shell=[IO.File]::ReadAllText($shellPath,[Text.Encoding]::UTF8)

foreach($needle in @(
    'HUYMAIER_FSE_HOST',
    'HuymaierConsoleFseUpdate.lock',
    'WaitForUpdateHandoff',
    'if (File.Exists(handoffPath))',
    'continue;'
)){
    if($host.IndexOf($needle,[StringComparison]::Ordinal) -lt 0){throw "FSE host handoff contract missing: $needle"}
}
foreach($needle in @(
    '[switch]$FseManaged',
    '[string]$HandoffPath',
    "HuymaierConsoleFseUpdate.lock",
    'if($relaunch -and -not $FseManaged)',
    'Windows FSE host owns post-update relaunch.',
    'Remove-Item -LiteralPath $HandoffPath -Force'
)){
    if($updater.IndexOf($needle,[StringComparison]::Ordinal) -lt 0){throw "Self-updater FSE handoff contract missing: $needle"}
}
foreach($needle in @(
    'HUYMAIER_V0303_FSE_UPDATE_HANDOFF_V1',
    "GetEnvironmentVariable('HUYMAIER_FSE_HOST')",
    "HuymaierConsoleFseUpdate.lock",
    '-FseManaged -HandoffPath',
    '$script:AllowWindowClose=$true;$script:Window.Close()'
)){
    if($shell.IndexOf($needle,[StringComparison]::Ordinal) -lt 0){throw "Shell FSE handoff contract missing: $needle"}
}

# The host must not immediately return the console exit code after an update
# handoff. It must wait for the updater to clear the lock and then continue the
# launch loop, while desktop self-update remains updater-owned.
if($host -notmatch 'if \(File\.Exists\(handoffPath\)\)[\s\S]{0,500}WaitForUpdateHandoff\(handoffPath\);[\s\S]{0,120}continue;'){throw 'FSE host does not wait and relaunch after the update handoff.'}
if($updater -notmatch 'if\(\$relaunch -and -not \$FseManaged\)[\s\S]{0,300}Start-Process'){throw 'Desktop updater relaunch path was not preserved.'}

$tokens=$null;$errors=$null
[void][Management.Automation.Language.Parser]::ParseFile($updaterPath,[ref]$tokens,[ref]$errors)
if(@($errors).Count){throw 'HuymaierSelfUpdater.ps1 failed Windows PowerShell parsing.'}
$tokens=$null;$errors=$null
[void][Management.Automation.Language.Parser]::ParseFile($shellPath,[ref]$tokens,[ref]$errors)
if(@($errors).Count){throw 'Transformed HuymaierShellRedesign.ps1 failed Windows PowerShell parsing.'}

Write-Host 'fseUpdaterHandoffGate: success'
Write-Host 'fseUpdaterOldRuntimeRelaunchBlockGate: success'
Write-Host 'desktopUpdaterRelaunchPreservedGate: success'
Write-Host 'fseUpdaterPs51ParseGate: success'