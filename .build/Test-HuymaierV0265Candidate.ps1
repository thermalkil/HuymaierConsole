param(
    [Parameter(Mandatory=$true)][string]$StageRoot,
    [Parameter(Mandatory=$true)][string]$ValidationPath
)
Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'

function Require-Text([string]$Relative,[string[]]$Needles){
    $path=Join-Path $StageRoot $Relative
    if(-not(Test-Path -LiteralPath $path -PathType Leaf)){throw "v0.26.5 required file missing: $Relative"}
    $raw=Get-Content -Raw -LiteralPath $path -Encoding UTF8
    foreach($needle in $Needles){if($raw -notmatch [regex]::Escape($needle)){throw "$Relative missing v0.26.5 invariant: $needle"}}
    return $raw
}

$manifest=Get-Content -Raw -LiteralPath (Join-Path $StageRoot 'manifest.json') -Encoding UTF8|ConvertFrom-Json
if([string]$manifest.version -ne '0.26.5'){throw 'Candidate manifest is not v0.26.5.'}
if([string]$manifest.baseVersion -ne '0.26.4'){throw 'v0.26.5 candidate does not identify v0.26.4 as its feature base.'}
if([string]$manifest.build -ne 'performance-downloads-rc1'){throw 'Candidate manifest is not performance-downloads-rc1.'}
if([string]$manifest.builtFrom -ne 'HC262.zip'){throw 'v0.26.5 candidate no longer records the published HC262.zip package staging baseline.'}

$core=Require-Text 'HuymaierConsole.ps1' @(
    "`$script:AppVersion = '0.26.5'",
    'Startup timing: entering ShowDialog at',
    'Startup timing: first rendered frame at',
    'Startup timing: deferred shell services ready at',
    '$script:Window.Add_ContentRendered',
    "'HuymaierConsole.Native.DisplayBridge' -as [type]",
    "'HuymaierConsole.Native.AudioBridge' -as [type]",
    "'HuymaierConsole.Native.LegacyJoystick' -as [type]",
    "'HuymaierConsole.Native.FrameRateMonitor' -as [type]"
)
$bootstrap=Require-Text 'HuymaierBootstrap.ps1' @(
    "`$script:ExpectedConsoleVersion='0.26.5'",
    'startup-preflight-v1.json',
    'Test-PowerShellPreflightCache',
    'Start-ProviderTelemetryWatch',
    "@('Epic','GOG','Amazon')"
)
$installerCore=Require-Text 'HuymaierInstallerCore.ps1' @(
    "`$script:InstallVersion='0.26.5'"
)
$installerEntry=Require-Text 'Install-HuymaierConsole.ps1' @(
    'Write-HuymaierStartupPreflightCache',
    "ValidationSource='installer'"
)
$appx=Require-Text 'FSEPackage\AppxManifest.xml' @('Version="0.26.5.0"')

$nativeGameInput=Require-Text 'Native\HuymaierConsole.GameInput.cs' @(
    'public static class HuymaierBuildStamp',
    'public const string Version = "0.26.5";',
    'public const string Architecture = "x64";'
)
$native=Require-Text 'Native\HuymaierConsole.ConsolePlatforms.cs' @(
    'IsNintendoLibraryOwnedPath',
    'IsNintendoRawDiscForCurrentShell',
    'header[0x18] == 0x5D',
    'header[0x1C] == 0xC2',
    'if (!IsNintendoLibraryOwnedPath(path)) continue;'
)
if($native -match 'LeftShoulder[^\r\n]{0,200}SwitchPage' -or $native -match 'RightShoulder[^\r\n]{0,200}SwitchPage'){throw 'LB/RB shoulder buttons switch ordinary native platform pages in v0.26.5.'}

# Verify the build stamp in the exact compiled managed/native host that ships.
$exePath=Join-Path $StageRoot 'HuymaierConsole.exe'
if(-not(Test-Path -LiteralPath $exePath -PathType Leaf)){throw 'v0.26.5 compiled native host is missing.'}
try{$nativeAssembly=[Reflection.Assembly]::LoadFile([IO.Path]::GetFullPath($exePath))}catch{throw "Could not load compiled HuymaierConsole.exe for build-stamp verification: $($_.Exception.Message)"}
$stampType=$nativeAssembly.GetType('HuymaierConsole.NativeApp.HuymaierBuildStamp',$false)
if($null -eq $stampType){throw 'Compiled HuymaierConsole.exe has no HuymaierBuildStamp type.'}
$flags=[Reflection.BindingFlags]::Public -bor [Reflection.BindingFlags]::Static
$versionField=$stampType.GetField('Version',$flags)
$architectureField=$stampType.GetField('Architecture',$flags)
$compiledVersion=if($null -ne $versionField){[string]$versionField.GetValue($null)}else{''}
$compiledArchitecture=if($null -ne $architectureField){[string]$architectureField.GetValue($null)}else{''}
if($compiledVersion -ne '0.26.5' -or $compiledArchitecture -ne 'x64'){
    throw "Compiled native host build stamp mismatch. Native=$compiledVersion/$compiledArchitecture Expected=0.26.5/x64."
}
Write-Host "Compiled native host build stamp verified: $compiledVersion/$compiledArchitecture"

$providerModule=Require-Text 'HuymaierGameProviders.ps1' @(
    'Get-ProviderDownloadDisplay',
    'Format-ProviderDownloadEta',
    'InstallProcessedBytes',
    'InstallSpeedBytesPerSec',
    'Progress calculating…'
)
$providerWorker=Require-Text 'HuymaierGameProviderWorker.ps1' @(
    'Get-LegendaryTransferPhase',
    'Format-ProviderEtaValue',
    'Installing',
    'Calculating ETA',
    'Write-State $true $phase'
)
$progressWorker=Require-Text 'HuymaierProviderProgressWorker.ps1' @(
    "ValidateSet('Epic','GOG','Amazon')",
    'Read-ProviderOutputTail',
    'Start-WriteObservation',
    'Update-ObservedWriteBytes',
    'Incremental destination writes',
    'Calculating ETA'
)
if($progressWorker -match 'Directory\]::EnumerateFiles|Directory\.EnumerateFiles'){throw 'Release fallback telemetry reintroduced recursive install-tree rescans.'}
$coordinator=Require-Text 'HuymaierProviderTelemetryCoordinator.ps1' @(
    "@('Epic','GOG','Amazon')",
    "@('Install','Update')",
    'TelemetrySource',
    'InstallSpeedBytesPerSec',
    'TransferSpeedBytesPerSec'
)
if($coordinator -match [regex]::Escape("@('GOG','Amazon')")){throw 'Release telemetry coordinator still contains a GOG/Amazon-only activation path.'}

foreach($required in @('HuymaierProviderTelemetry.ps1','HuymaierProviderProgressWorker.ps1','HuymaierProviderTelemetryCoordinator.ps1')){
    if(-not(Test-Path -LiteralPath (Join-Path $StageRoot $required) -PathType Leaf)){throw "Telemetry payload missing from release stage: $required"}
}

# PS1/PS2/PS3 source presentation remains frozen from the validated v0.26.4 production source.
$realGit=(Get-Command git.exe -ErrorAction Stop).Source
$psChanges=@(& $realGit diff --name-only 91bd40877bd0d5ee5d0f86748a2356a446d75bc6 -- 'EmulatorPlatforms/PS1' 'EmulatorPlatforms/PS2' 'EmulatorPlatforms/PS3' 'Native/HuymaierConsole.Ps1.cs')
if($psChanges.Count){throw ('Frozen PS1/PS2/PS3 presentation source changed in v0.26.5: '+($psChanges -join ', '))}

$validation=Get-Content -Raw -LiteralPath $ValidationPath -Encoding UTF8|ConvertFrom-Json
$validation|Add-Member -NotePropertyName version0265ConsistencyGate -NotePropertyValue 'success' -Force
$validation|Add-Member -NotePropertyName nativeHostBuildStampGate -NotePropertyValue 'success' -Force
$validation|Add-Member -NotePropertyName startupPerformanceGate -NotePropertyValue 'success' -Force
$validation|Add-Member -NotePropertyName providerTelemetryGate -NotePropertyValue 'success' -Force
$validation|Add-Member -NotePropertyName nintendoOwnershipGate -NotePropertyValue 'success' -Force
$validation|Add-Member -NotePropertyName playStationPresentationFreezeGate -NotePropertyValue 'success' -Force
$validation|ConvertTo-Json -Depth 10|Set-Content -LiteralPath $ValidationPath -Encoding UTF8
Write-Host 'v0.26.5 release-shaped version, compiled native stamp, startup, provider telemetry, Nintendo ownership and PlayStation freeze gates passed.'
