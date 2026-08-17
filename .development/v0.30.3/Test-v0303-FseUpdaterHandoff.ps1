Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
$root=(Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$hostPath=Join-Path $root 'HuymaierFSEHost.cs'
$updaterPath=Join-Path $root 'HuymaierSelfUpdater.ps1'
$shellPath=Join-Path $root 'HuymaierShellRedesign.ps1'
foreach($p in @($hostPath,$updaterPath,$shellPath)){if(-not(Test-Path -LiteralPath $p -PathType Leaf)){throw "Required updater source missing: $p"}}

$hostText=[IO.File]::ReadAllText($hostPath,[Text.Encoding]::UTF8)
$updaterText=[IO.File]::ReadAllText($updaterPath,[Text.Encoding]::UTF8)
$shellText=[IO.File]::ReadAllText($shellPath,[Text.Encoding]::UTF8)

foreach($needle in @(
    'HUYMAIER_FSE_HOST',
    'HuymaierConsoleFseUpdate.lock',
    'WaitForUpdateHandoffToStart',
    'DateTime.UtcNow.AddSeconds(2)',
    'WaitForUpdateHandoff(handoffPath)',
    'continue;'
)){
    if($hostText.IndexOf($needle,[StringComparison]::Ordinal) -lt 0){throw "FSE host handoff contract missing: $needle"}
}
foreach($needle in @(
    "GetEnvironmentVariable('HUYMAIER_FSE_HOST')",
    '$isFseManaged=',
    "HuymaierConsoleFseUpdate.lock",
    '[IO.File]::WriteAllText($HandoffPath',
    'if($relaunch -and -not $isFseManaged)',
    'Windows FSE host owns post-update relaunch.',
    'Remove-Item -LiteralPath $HandoffPath -Force'
)){
    if($updaterText.IndexOf($needle,[StringComparison]::Ordinal) -lt 0){throw "Self-updater FSE handoff contract missing: $needle"}
}

# Preserve the already-proven desktop launch behavior: the shell starts the
# updater as a normal child process and then closes Console. In FSE mode that
# child inherits HUYMAIER_FSE_HOST=1 from Console, so no shell-source mutation is
# required for the handoff.
foreach($needle in @(
    'Start-Process -FilePath "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -ArgumentList $arguments -WindowStyle Hidden|Out-Null',
    '$script:AllowWindowClose=$true;$script:Window.Close()'
)){
    if($shellText.IndexOf($needle,[StringComparison]::Ordinal) -lt 0){throw "Existing self-update shell launch contract missing: $needle"}
}

if($hostText -notmatch 'WaitForUpdateHandoffToStart\(handoffPath\)[\s\S]{0,300}WaitForUpdateHandoff\(handoffPath\);[\s\S]{0,120}continue;'){throw 'FSE host does not wait and relaunch after the updater handoff.'}
if($updaterText -notmatch '\$isFseManaged=\(\[bool\]\$FseManaged -or [\s\S]{0,220}HUYMAIER_FSE_HOST'){throw 'Self-updater does not auto-detect the inherited FSE host environment.'}
if($updaterText -notmatch 'if\(\$relaunch -and -not \$isFseManaged\)[\s\S]{0,300}Start-Process'){throw 'Desktop updater relaunch path was not preserved.'}

function Assert-Ps51Parse([string]$Path,[string]$Label){
    $tokens=$null;$errors=$null
    [void][Management.Automation.Language.Parser]::ParseFile($Path,[ref]$tokens,[ref]$errors)
    if(@($errors).Count){
        $details=($errors|ForEach-Object{"line $($_.Extent.StartLineNumber), col $($_.Extent.StartColumnNumber): $($_.Message) :: $($_.Extent.Text)"}) -join '; '
        throw "$Label failed Windows PowerShell parsing: $details"
    }
}
Assert-Ps51Parse $updaterPath 'HuymaierSelfUpdater.ps1'
Assert-Ps51Parse $shellPath 'HuymaierShellRedesign.ps1'

Write-Host 'fseUpdaterHandoffGate: success'
Write-Host 'fseUpdaterInheritedEnvironmentGate: success'
Write-Host 'fseUpdaterOldRuntimeRelaunchBlockGate: success'
Write-Host 'desktopUpdaterRelaunchPreservedGate: success'
Write-Host 'fseUpdaterPs51ParseGate: success'