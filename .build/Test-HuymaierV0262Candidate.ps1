param(
    [Parameter(Mandatory=$true)][string]$StageRoot,
    [Parameter(Mandatory=$true)][string]$ValidationPath
)
Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'

function Require-Text {
    param([string]$Path,[string[]]$Needles,[string]$Label)
    if(-not(Test-Path -LiteralPath $Path -PathType Leaf)){throw "$Label is missing: $Path"}
    $text=Get-Content -Raw -LiteralPath $Path -Encoding UTF8
    foreach($needle in $Needles){if($text -notmatch [regex]::Escape($needle)){throw "$Label invariant is missing: $needle"}}
    return $text
}

$manifest=Get-Content -Raw -LiteralPath (Join-Path $StageRoot 'manifest.json') -Encoding UTF8|ConvertFrom-Json
if([string]$manifest.version -ne '0.26.2'){throw 'Packaged manifest is not v0.26.2.'}
if([string]$manifest.baseVersion -ne '0.26.1'){throw 'v0.26.2 does not identify v0.26.1 as its stable base.'}

$shell=Require-Text (Join-Path $StageRoot 'HuymaierConsole.ps1') @("`$script:AppVersion = '0.26.2'",'HuymaierCustomization.ps1') 'Main shell'
$bootstrap=Require-Text (Join-Path $StageRoot 'HuymaierBootstrap.ps1') @("`$script:ExpectedConsoleVersion='0.26.2'",'Assert-HuymaierInstallIntegrity') 'Bootstrap'
$installer=Require-Text (Join-Path $StageRoot 'HuymaierInstallerCore.ps1') @("`$script:InstallVersion='0.26.2'",'Assert-HcRollbackState','install-incomplete.json') 'Installer core'
$buildStamp=Require-Text (Join-Path $StageRoot 'Native\HuymaierConsole.GameInput.cs') @('public const string Version = "0.26.2";','public const string Architecture = "x64";') 'Native build stamp'
$nativeApp=Require-Text (Join-Path $StageRoot 'Native\HuymaierConsole.NativeApp.cs') @('return "0.26.2";','public static bool ConsumeGuideOnly()','HuymaierGameBarHost.BlocksNativeNavigation') 'Native host'
$appx=Require-Text (Join-Path $StageRoot 'FSEPackage\AppxManifest.xml') @('Version="0.26.2.0"','ProcessorArchitecture="x64"') 'FSE package manifest'

$gameBar=Require-Text (Join-Path $StageRoot 'HuymaierGameBar.ps1') @(
    'mainShellActive',
    'Huymaier Game Bar opened over a Huymaier-native console surface.',
    'Invoke-HcInternalGuide -ActiveWindow $script:Window',
    '[HuymaierConsole.NativeApp.HuymaierGameBarHost]::Show()'
) 'Game Bar native-surface routing'
$mainShellIndex=$gameBar.IndexOf('$mainShellActive')
$internalIndex=$gameBar.IndexOf('Invoke-HcInternalGuide -ActiveWindow $script:Window',$mainShellIndex)
$nativeOverlayIndex=$gameBar.IndexOf('Huymaier Game Bar opened over a Huymaier-native console surface.',$mainShellIndex)
if($mainShellIndex -lt 0 -or $internalIndex -lt $mainShellIndex -or $nativeOverlayIndex -lt $internalIndex){throw 'Game Bar main-shell/native-surface ownership order is not deterministic.'}

$custom=Require-Text (Join-Path $StageRoot 'HuymaierCustomization.ps1') @(
    "Show-HcColorPicker 'ShellBaseColor'",
    "Show-HcColorPicker 'AccentColor'",
    "Show-HcColorPicker 'AccentHighlightColor'",
    "Show-HcColorPicker 'DynamicPrimaryColor'",
    "Show-HcColorPicker 'DynamicSecondaryColor'",
    "Show-HcColorPicker 'DynamicTertiaryColor'"
) 'Customization color routing'
foreach($forbidden in @(
    "Open-HcCustomizationKeyboard 'ShellBaseColor'",
    "Open-HcCustomizationKeyboard 'AccentColor'",
    "Open-HcCustomizationKeyboard 'DynamicPrimaryColor'"
)){if($custom -match [regex]::Escape($forbidden)){throw "Normal color customization still requires keyboard hex entry: $forbidden"}}
$picker=Require-Text (Join-Path $StageRoot 'HuymaierColorPicker.ps1') @(
    'No color code typing required.',
    'HcColorPickerSwatchIndex',
    "'LeftShoulder'",
    "'RightShoulder'",
    "'Confirm'",
    "'Back'",
    'reference only',
    'HuymaierV0262Runtime.ps1',
    'HuymaierV0262ProviderRuntime.ps1'
) 'Controller color wheel'

$runtime=Require-Text (Join-Path $StageRoot 'HuymaierV0262Runtime.ps1') @(
    'GamesPlatformOrder','GamesHiddenPlatforms','GamesPlatformSizes','GamesTileDefaultSize',
    'layout-edit-games','layout-default-size','layout-show-all','layout-reset-games',
    "@('Small','Normal','Large','Extra Large')",
    'Move-HcGamesLayoutItem','Toggle-HcSelectedPlatformHidden','Change-HcSelectedPlatformSize',
    'MinHeight=[math]::Max(170',
    "Id='Steam';Name='Steam';Backend='Steam Client'",
    'Start-HcSteamWorker','Get-PlatformCountSummary'
) 'v0.26.2 runtime'
$hardening=Require-Text (Join-Path $StageRoot 'HuymaierV0262Hardening.ps1') @(
    'Get-HcGamesLayoutColumnCount',
    "'Up' {$delta=-(Get-HcGamesLayoutColumnCount)}",
    "'Down' {$delta=(Get-HcGamesLayoutColumnCount)}",
    'Test-HcAnyProviderOperationActive',
    'fresh marker as busy'
) 'Layout/provider hardening'
$providerRuntime=Require-Text (Join-Path $StageRoot 'HuymaierV0262ProviderRuntime.ps1') @(
    'provider-progress.json','ProgressPath','Get-HcProviderProgressOverlay',
    'Merge-HcProviderProgressForDisplay','IsIndeterminate','Observed writes',
    'HuymaierV0262Hardening.ps1'
) 'Provider progress bridge'

$steam=Require-Text (Join-Path $StageRoot 'HuymaierSteamWorker.ps1') @(
    'steam://install/','steam://uninstall/','steam://validate/','steam://rungameid/',
    'libraryfolders.vdf','appmanifest_*.acf','BytesToDownload','BytesDownloaded',
    'BytesToStage','BytesStaged','steamapps\downloading\','Refresh-SteamCatalog',
    "Provider='Steam'"
) 'Steam provider worker'
$sidecar=Require-Text (Join-Path $StageRoot 'HuymaierProviderProgressWorker.ps1') @(
    "ValidateSet('GOG','Amazon')",'ProgressPath','Observed install writes','Get-ObservedWriteBytes',
    'This sidecar never writes provider-state.json'
) 'GOG/Amazon telemetry sidecar'
if($sidecar -match [regex]::Escape('Move-Item -LiteralPath $tmp -Destination $StatePath')){throw 'Progress sidecar can overwrite authoritative provider-state.json.'}

# The v0.26.1 storefront import fix remains release-blocking in v0.26.2.
$pickerStart=$shell.IndexOf('function Start-NativeFilePicker')
$pickerEnd=$shell.IndexOf('function Complete-NativeFolderSelection',$pickerStart)
$tabIndex=$shell.IndexOf('$script:SelectedTab=6',$pickerStart)
$subPageIndex=$shell.IndexOf('$script:SubPage=''FilePicker''',$pickerStart)
if($pickerStart -lt 0 -or $pickerEnd -lt 0 -or $tabIndex -lt $pickerStart -or $tabIndex -ge $pickerEnd -or $subPageIndex -lt $tabIndex -or $subPageIndex -ge $pickerEnd){throw 'The fixed storefront/native folder-picker routing regressed in v0.26.2.'}

$validation=Get-Content -Raw -LiteralPath $ValidationPath -Encoding UTF8|ConvertFrom-Json
$validation|Add-Member -NotePropertyName nativeSurfaceGameBarGate -NotePropertyValue 'success' -Force
$validation|Add-Member -NotePropertyName controllerColorWheelGate -NotePropertyValue 'success' -Force
$validation|Add-Member -NotePropertyName gamesLayoutCustomizationGate -NotePropertyValue 'success' -Force
$validation|Add-Member -NotePropertyName steamProviderGate -NotePropertyValue 'success' -Force
$validation|Add-Member -NotePropertyName multiProviderProgressGate -NotePropertyValue 'success' -Force
$validation|Add-Member -NotePropertyName actionCardTypographyGate -NotePropertyValue 'success' -Force
$validation|Add-Member -NotePropertyName versionConsistencyGate -NotePropertyValue 'success' -Force
$validation|Add-Member -NotePropertyName storefrontImportRegressionGate -NotePropertyValue 'success' -Force
$validation|ConvertTo-Json -Depth 8|Set-Content -LiteralPath $ValidationPath -Encoding UTF8
Write-Host 'v0.26.2 release-shaped feature gates passed.'
