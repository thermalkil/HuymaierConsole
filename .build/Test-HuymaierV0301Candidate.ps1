param(
    [Parameter(Mandatory=$true)][string]$StageRoot,
    [Parameter(Mandatory=$true)][string]$ValidationPath
)
Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'

function Require-File([string]$Relative){
    $path=Join-Path $StageRoot $Relative
    if(-not(Test-Path -LiteralPath $path -PathType Leaf)){throw "v0.30.1 required file missing: $Relative"}
    return $path
}
function Require-Text([string]$Relative,[string[]]$Needles){
    $path=Require-File $Relative
    $raw=Get-Content -Raw -LiteralPath $path -Encoding UTF8
    foreach($needle in $Needles){if($raw.IndexOf($needle,[StringComparison]::Ordinal) -lt 0){throw "$Relative missing v0.30.1 invariant: $needle"}}
    return $raw
}
function Assert-Ps51Parse([string]$Relative){
    $path=Require-File $Relative
    $tokens=$null;$errors=$null
    [void][Management.Automation.Language.Parser]::ParseFile($path,[ref]$tokens,[ref]$errors)
    if($errors.Count){throw "$Relative failed Windows PowerShell 5.1 parse: "+(($errors|ForEach-Object{"line $($_.Extent.StartLineNumber): $($_.Message)"}) -join '; ')}
}

$validation=Get-Content -Raw -LiteralPath $ValidationPath -Encoding UTF8|ConvertFrom-Json
if([string]$validation.version -ne '0.30.1'){throw "Candidate validation version is $($validation.version), expected 0.30.1."}
if([string]$validation.asset -ne 'HC0301.zip'){throw "Candidate validation asset is $($validation.asset), expected HC0301.zip."}
if([string]::IsNullOrWhiteSpace([string]$validation.sha256) -or [string]$validation.sha256 -notmatch '^[0-9a-fA-F]{64}$'){throw 'Candidate validation SHA-256 is missing or malformed.'}

$manifest=Get-Content -Raw -LiteralPath (Require-File 'manifest.json') -Encoding UTF8|ConvertFrom-Json
if([string]$manifest.version -ne '0.30.1'){throw 'Candidate manifest is not v0.30.1.'}
if([string]$manifest.baseVersion -ne '0.3.0'){throw 'v0.30.1 candidate does not identify public v0.3.0 as its base.'}
if([string]$manifest.build -ne 'brightness-fan-motion-self-update-rc1'){throw 'v0.30.1 build identity is not brightness-fan-motion-self-update-rc1.'}

$core=Require-Text 'HuymaierConsole.ps1' @("`$script:AppVersion = '0.30.1'",'HUYMAIER_UNIFIED_CURSOR_RUNTIME_V2','HuymaierUser3DModels.ps1')
$bootstrap=Require-Text 'HuymaierBootstrap.ps1' @("`$script:ExpectedConsoleVersion='0.30.1'",'Assert-HuymaierInstallIntegrity','HuymaierUser3DModels.ps1')
$installerCore=Require-Text 'HuymaierInstallerCore.ps1' @("`$script:InstallVersion='0.30.1'",'install-incomplete.json')
$installer=Require-Text 'Install-HuymaierConsole.ps1' @("param([string]`$InstallRoot,[string]`$Version='0.30.1')","-Version '0.30.1'",'SilentUpdate')
$appx=Require-Text 'FSEPackage\AppxManifest.xml' @('Version="0.30.1.0"')

$userModels=Require-Text 'HuymaierUser3DModels.ps1' @(
    'HUYMAIER_V0301_BRIGHTNESS_0_200_AND_FAN_MOTION_V1',
    '[math]::Max(0,[math]::Min(200,[int]$script:Config.PlatformModelBrightness))',
    "'3D model brightness' ([int]`$script:Config.PlatformModelBrightness) 'Adjust lighting for both the Games 3D shelves and the full-screen model viewer.' 0 200"
)
if($userModels -match "platform-model-brightness-slider'.*50 250"){throw 'Legacy 50-250 3D-model brightness range survived staging.'}

$hostSource=Require-Text 'Native\HuymaierD3D11ShelfHost.cs' @(
    'HUYMAIER_D3D11_SHELF_HOST_V3_BOUNDED_FAN_MOTION',
    'FanPeriodSeconds = 8.0',
    'FanPhaseAmplitude = 0.75f',
    '-FanPhaseAmplitude * (float)Math.Sin',
    'Math.Max(0.0, Math.Min(200.0, percent))'
)
if($hostSource.Contains('float phase = (float)renderClock.Elapsed.TotalSeconds;')){throw 'Legacy continuous 360-degree turntable phase survived staging.'}

$worker=Require-Text 'HuymaierConsoleUpdateWorker.ps1' @(
    'function Get-HcComparableVersion',
    "return [version]'0.26.5'",
    'Select-PackageAsset -Release $release -VersionText $latestVersionText',
    "`$expected='HC'+`$digits+'.zip'",
    "'HuymaierConsole/'+`$CurrentVersion",
    "`$sidecarPath=`$target+'.sha256'",
    'Downloaded update ZIP does not match the SHA-256 published with the GitHub Release.'
)

$tokens=$null;$errors=$null
$workerAst=[Management.Automation.Language.Parser]::ParseInput($worker,[ref]$tokens,[ref]$errors)
if($errors.Count){throw 'Staged updater worker failed PowerShell parse.'}
foreach($name in @('Parse-Version','Get-HcComparableVersion')){
    $definition=$workerAst.Find({param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq $name},$true)
    if($null -eq $definition){throw "Staged updater missing helper $name"}
    . ([scriptblock]::Create($definition.Extent.Text))
}
if((Get-HcComparableVersion 'v0.3.0') -ne [version]'0.26.5'){throw 'Staged updater lost the v0.3.0/public legacy alias.'}
if(-not((Get-HcComparableVersion 'v0.30.1') -gt (Get-HcComparableVersion '0.26.2'))){throw 'Staged updater cannot order legacy v0.26.2 below v0.30.1.'}
if(-not((Get-HcComparableVersion 'v0.30.1') -gt (Get-HcComparableVersion 'v0.3.0'))){throw 'Staged updater cannot order public v0.3.0 below v0.30.1.'}

$selfUpdater=Require-Text 'HuymaierSelfUpdater.ps1' @(
    "`$sidecar=`$PackagePath+'.sha256'",
    'Wait-HcProcessExit -Id $ParentProcessId -TimeoutSeconds 90',
    "'-SilentUpdate'",
    'Downloaded update ZIP does not match the SHA-256 published with the release.',
    "Start-Process -FilePath `$relaunch -WorkingDirectory `$InstallRoot"
)
$shell=Require-Text 'HuymaierShellRedesign.ps1' @(
    "'console-update-download' {Start-HcConsoleUpdateWorker 'Download';return `$true}",
    "'console-update-install' {Start-HcConsoleSelfUpdate;return `$true}",
    '-ParentProcessId $PID -InstallRoot $install',
    '$script:AllowWindowClose=$true;$script:Window.Close()'
)

foreach($relative in @('HuymaierConsole.ps1','HuymaierBootstrap.ps1','HuymaierInstallerCore.ps1','Install-HuymaierConsole.ps1','HuymaierConsoleUpdateWorker.ps1','HuymaierSelfUpdater.ps1','HuymaierShellRedesign.ps1','HuymaierUser3DModels.ps1')){Assert-Ps51Parse $relative}

$exePath=Require-File 'HuymaierConsole.exe'
try{$assembly=[Reflection.Assembly]::LoadFile([IO.Path]::GetFullPath($exePath))}catch{throw "Could not load staged HuymaierConsole.exe: $($_.Exception.Message)"}
$stamp=$assembly.GetType('HuymaierConsole.NativeApp.HuymaierBuildStamp',$false)
if($null -eq $stamp){throw 'Staged native host has no HuymaierBuildStamp.'}
$flags=[Reflection.BindingFlags]::Public -bor [Reflection.BindingFlags]::Static
$versionField=$stamp.GetField('Version',$flags);$architectureField=$stamp.GetField('Architecture',$flags)
$nativeVersion=if($null -ne $versionField){[string]$versionField.GetValue($null)}else{''}
$nativeArch=if($null -ne $architectureField){[string]$architectureField.GetValue($null)}else{''}
if($nativeVersion -ne '0.30.1' -or $nativeArch -ne 'x64'){throw "Staged native build stamp mismatch: $nativeVersion/$nativeArch"}

foreach($required in @('checksums.sha256','SHA256SUMS.txt','HuymaierGameInputBridge.dll','Restore-HuymaierWindowsSettings.ps1')){[void](Require-File $required)}
if((Get-Content -Raw -LiteralPath (Join-Path $StageRoot 'checksums.sha256')) -ne (Get-Content -Raw -LiteralPath (Join-Path $StageRoot 'SHA256SUMS.txt'))){throw 'Staged internal checksum manifests diverged.'}
foreach($forbidden in @('.development','.source','.release','.github','.build','Docs')){if(Test-Path -LiteralPath (Join-Path $StageRoot $forbidden)){throw "Developer-only directory survived v0.30.1 package: $forbidden"}}
if(@(Get-ChildItem -LiteralPath $StageRoot -File -Filter 'BUILD-VALIDATION*.txt' -ErrorAction SilentlyContinue).Count){throw 'Historical BUILD-VALIDATION files survived v0.30.1 package.'}

Write-Host 'v0301CandidateVersionIdentityGate: success'
Write-Host 'v0301CandidateBrightnessAndFanGate: success'
Write-Host 'v0301CandidateSelfUpdateGate: success'
Write-Host 'v0301CandidatePackageHygieneGate: success'