param([string]$StageRoot='.')
Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
$root=(Resolve-Path -LiteralPath $StageRoot).Path
function Require([bool]$Condition,[string]$Message){if(-not$Condition){throw $Message}}
function Read-Hc([string]$Relative){$path=Join-Path $root $Relative;if(-not(Test-Path -LiteralPath $path -PathType Leaf)){throw "Required file missing: $Relative"};[IO.File]::ReadAllText($path,[Text.Encoding]::UTF8)}
function Parse-Hc([string]$Relative){$path=Join-Path $root $Relative;$tokens=$null;$errors=$null;[void][Management.Automation.Language.Parser]::ParseFile($path,[ref]$tokens,[ref]$errors);if($errors.Count){throw (($errors|ForEach-Object{"${Relative}:$($_.Extent.StartLineNumber):$($_.Extent.StartColumnNumber) $($_.Message)"})-join"`n")}}
foreach($file in @('HuymaierConsole.ps1','HuymaierSettingsStore.ps1','HuymaierCustomization.ps1','HuymaierConsoleModelPresentation.ps1','HuymaierBootstrap.ps1','Install-HuymaierConsole.ps1','HuymaierInstallerCore.ps1','HuymaierColorPicker.ps1','HuymaierV0262Runtime.ps1','HuymaierV0262ProviderRuntime.ps1','HuymaierV0262Hardening.ps1')){Parse-Hc $file}
$core=Read-Hc 'HuymaierConsole.ps1';$store=Read-Hc 'HuymaierSettingsStore.ps1';$custom=Read-Hc 'HuymaierCustomization.ps1';$model=Read-Hc 'HuymaierConsoleModelPresentation.ps1';$bootstrap=Read-Hc 'HuymaierBootstrap.ps1';$installer=Read-Hc 'Install-HuymaierConsole.ps1';$installerCore=Read-Hc 'HuymaierInstallerCore.ps1';$picker=Read-Hc 'HuymaierColorPicker.ps1';$providerCompat=Read-Hc 'HuymaierV0262ProviderRuntime.ps1'
Require ($core.Contains('HUYMAIER_V0308_SETTINGS_STORE_CORE_V5')) 'Core settings-store marker is missing.'
Require ($core.Contains('Merge-HcPersistedConfig -Defaults $defaults -Loaded $loaded')) 'Core config loader is not using dynamic property merge.'
Require (-not $core.Contains("foreach (`$name in @('BrowserName','BrowserPath'")) 'Legacy config property allowlist is still active.'
Require ($core.Contains('Write-HcConfigAtomic -Path $script:ConfigPath -Config $script:Config -Depth 16')) 'Core config save is not atomic/deep.'
Require ($core.Contains('ConfigSchemaVersion = 2')) 'Config schema v2 default is missing.'
Require ($core.Contains('ConsoleBrightness = 100')) 'Console brightness is not a first-class persisted default.'
Require ($core.Contains('Flush-HcModelEditorAutoSave')) 'Shutdown does not flush pending model settings.'
Require ($store.Contains('function Merge-HcPersistedConfig')) 'Settings merge function missing.'
Require ($store.Contains('function Write-HcConfigAtomic')) 'Atomic settings writer missing.'
Require ($custom.Contains("Add-HcCustomizationConfigProperty 'ConsoleBrightness' 100")) 'Customization brightness default is missing.'
Require (-not ($custom -match 'persistedBrightness|Get-Content -Raw -LiteralPath \$script:ConfigPath')) 'Customization still contains the old raw-config brightness workaround.'
Require ($model.Contains('HUYMAIER_V0308_MODEL_SETTINGS_AUTOSAVE_V5')) 'Model editor auto-save marker missing.'
Require ($model.Contains('Queue-HcModelEditorAutoSave;Update-HcGpuModelViewerItem')) 'Model adjustments are not queued for persistence.'
Require ($model.Contains('Save-HcModelViewSnapshotToConfig $script:HcModelEditorOriginalView')) 'Model Cancel does not persist the restored original snapshot.'
Require ($bootstrap.Contains("Label='Central settings persistence store'")) 'Bootstrap does not preflight the settings store.'
Require ($installer.Contains("'HuymaierSettingsStore.ps1'")) 'Installer startup cache omits the settings store.'
Require ($installerCore.Contains('HUYMAIER_V0308_SETTINGS_STORE_REQUIRED_V5')) 'Installer required payload omits settings store.'
Require ($picker.Contains("Join-Path `$script:BaseDir 'HuymaierV0262Runtime.ps1'")) 'Cleanup audit lost the active v0.26.2 runtime loader.'
Require ($picker.Contains("Join-Path `$script:BaseDir 'HuymaierV0262ProviderRuntime.ps1'")) 'Cleanup audit lost the active provider compatibility loader.'
Require ($providerCompat.Contains("Join-Path `$script:BaseDir 'HuymaierV0262Hardening.ps1'")) 'Cleanup audit lost the active hardening loader.'

. (Join-Path $root 'HuymaierSettingsStore.ps1')
$temp=Join-Path ([IO.Path]::GetTempPath()) ('hc-settings-test-'+[guid]::NewGuid().ToString('N'));New-Item -ItemType Directory -Force -Path $temp|Out-Null
try{
    $path=Join-Path $temp 'config.json'
    $defaults=[pscustomobject]@{ConfigSchemaVersion=2;Known='default';ConsoleBrightness=100;TheGamesDbApiKey='';SteamGridDbApiKey='';PlatformModelDefaultViews=@()}
    $loaded=[pscustomobject]@{Known='persisted';ConsoleBrightness=170;TheGamesDbApiKey='tgdb-test-key';SteamGridDbApiKey='sgdb-test-key';SyntheticModuleSetting=[pscustomobject]@{Enabled=$true;Mode='PersistMe'};PlatformModelDefaultViews=@([pscustomobject]@{Key='ps3.glb';Platform='PS3';LightPercent=240;KeyLightPercent=330;LightAzimuth=27;LightElevation=41;LightDistance=6.5;LightAimXPercent=15;LightAimYPercent=-10;ConeDegrees=75;ConeSoftnessPercent=35;FalloffPercent=80;LightTemperature=7200;AmbientPercent=180;SpecularPercent=260;HighlightSizePercent=175;FanPercent=50})}
    $merged=Merge-HcPersistedConfig -Defaults $defaults -Loaded $loaded
    Require ([string]$merged.Known-eq'persisted') 'Known property did not merge.';Require ([int]$merged.ConsoleBrightness-eq170) 'ConsoleBrightness did not merge.';Require ($null-ne$merged.PSObject.Properties['SyntheticModuleSetting']) 'Unknown module-owned property was dropped.'
    Require (Write-HcConfigAtomic -Path $path -Config $merged -Depth 16) 'Atomic settings write did not report success.';$roundTrip=Read-HcPersistedConfig -Path $path
    Require ([int]$roundTrip.ConsoleBrightness-eq170) 'ConsoleBrightness did not survive round trip.';Require ([string]$roundTrip.TheGamesDbApiKey-eq'tgdb-test-key') 'TheGamesDB key did not survive round trip.';Require ([string]$roundTrip.SteamGridDbApiKey-eq'sgdb-test-key') 'SteamGridDB key did not survive round trip.';Require ([string]$roundTrip.SyntheticModuleSetting.Mode-eq'PersistMe') 'Synthetic module-owned setting did not survive round trip.'
    $view=@($roundTrip.PlatformModelDefaultViews)[0];foreach($pair in @(@('LightPercent',240),@('KeyLightPercent',330),@('LightAzimuth',27),@('LightElevation',41),@('LightTemperature',7200),@('AmbientPercent',180),@('SpecularPercent',260),@('HighlightSizePercent',175),@('FanPercent',50))){Require ([int]$view.($pair[0]) -eq [int]$pair[1]) ("Advanced model setting did not survive: "+$pair[0])}
    Require (@(Get-ChildItem -LiteralPath $temp -File -Filter '*.tmp' -ErrorAction SilentlyContinue).Count-eq0) 'Atomic settings writer leaked temporary files.';Require (-not(Test-Path -LiteralPath ($path+'.replace-backup'))) 'Atomic settings writer leaked replacement backup.'
}finally{Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue}
Write-Host 'v0.30.8 settings persistence/model auto-save/cleanup audit validation passed.'
