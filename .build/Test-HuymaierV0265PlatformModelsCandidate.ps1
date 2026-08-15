param(
    [Parameter(Mandatory=$true)][string]$StageRoot,
    [Parameter(Mandatory=$true)][string]$ValidationPath
)
Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
foreach($required in @('HuymaierConsole.ps1','HuymaierPlatformModels.ps1','HuymaierModelPreviewWorker.exe','HuymaierBootstrap.ps1','Install-HuymaierConsole.ps1','Assets\Models\model-map.json')){if(-not(Test-Path -LiteralPath (Join-Path $StageRoot $required) -PathType Leaf)){throw "Staged platform-model payload missing: $required"}}
$core=Get-Content -Raw -LiteralPath (Join-Path $StageRoot 'HuymaierConsole.ps1') -Encoding UTF8
$runtime=Get-Content -Raw -LiteralPath (Join-Path $StageRoot 'HuymaierPlatformModels.ps1') -Encoding UTF8
$bootstrap=Get-Content -Raw -LiteralPath (Join-Path $StageRoot 'HuymaierBootstrap.ps1') -Encoding UTF8
$installer=Get-Content -Raw -LiteralPath (Join-Path $StageRoot 'Install-HuymaierConsole.ps1') -Encoding UTF8
$map=Get-Content -Raw -LiteralPath (Join-Path $StageRoot 'Assets\Models\model-map.json') -Encoding UTF8|ConvertFrom-Json

foreach($needle in @('HUYMAIER_PLATFORM_3D_MODELS_RUNTIME_V1','PlatformModelsModulePath','Platform 3D model module load failed')){if(-not $core.Contains($needle)){throw "Staged core missing platform-model contract: $needle"}}
foreach($needle in @('HUYMAIER_PLATFORM_3D_MODELS_PREFLIGHT_V1','Platform 3D model runtime')){if(-not $bootstrap.Contains($needle)){throw "Staged bootstrap missing platform-model contract: $needle"}}
foreach($needle in @('HUYMAIER_PLATFORM_3D_MODELS_INSTALLER_CACHE_V1','HuymaierPlatformModels.ps1')){if(-not $installer.Contains($needle)){throw "Staged installer missing platform-model contract: $needle"}}
foreach($needle in @("@('Icons','3D Models')",'platform-visual-style','HuymaierModelPreviewWorker.exe','Request-HcModelPreview','3DModelCache')){if(-not $runtime.Contains($needle)){throw "Staged platform-model runtime missing: $needle"}}
if($runtime -notmatch "(?s)function New-PlatformCard.+Get-HcPlatformVisualStyle.+3D Models.+Resolve-HcPlatformModelPath"){throw '3D model card override is not active in the staged runtime.'}
if($runtime -notmatch "(?s)function Add-PlatformRail.+Reset-HcModelPreviewPageState"){throw '3D model page queue reset is missing.'}

$keys=@{};foreach($p in @($map.models.PSObject.Properties)){$keys[[string]$p.Name.ToLowerInvariant()]=[string]$p.Value}
foreach($provider in @('Steam','Epic','GOG','EA','Ubisoft','Xbox App','Battle.net','Rockstar','Amazon Games')){if(-not $keys.ContainsKey($provider.ToLowerInvariant())){throw "Staged model map missing provider $provider"}}
foreach($platform in @('PS1','PS2','PS3','PS4','PSP','Vita','Nintendo 64','Nintendo GameCube','Nintendo Wii','Nintendo Wii U','Nintendo Switch','Original Xbox','Xbox 360','Sega Dreamcast','Sega Genesis','Sega Saturn','Atari 2600','Nintendo Entertainment System','Super Nintendo Entertainment System','Nintendo Game Boy','Nintendo Game Boy Color','Nintendo Game Boy Advance','Nintendo DS','Nintendo DSi','Nintendo 3DS','Sega CD','Sega 32X','Sega Game Gear','Sega Master System','TurboGrafx-16','Atari Lynx','Neo Geo Pocket Color','Metroid PrimeHack','Arcade')){if(-not $keys.ContainsKey($platform.ToLowerInvariant())){throw "Staged model map missing platform $platform"}}

$exe=Join-Path $StageRoot 'HuymaierModelPreviewWorker.exe'
$bytes=[IO.File]::ReadAllBytes($exe);if($bytes.Length -lt 512){throw 'Model preview worker is unexpectedly small.'}
$pe=[BitConverter]::ToInt32($bytes,0x3C);$machine=[BitConverter]::ToUInt16($bytes,$pe+4);if($machine -ne 0x8664){throw ('HuymaierModelPreviewWorker.exe is not x64 (machine 0x{0:X4}).' -f $machine)}

$validation=Get-Content -Raw -LiteralPath $ValidationPath -Encoding UTF8|ConvertFrom-Json
$validation|Add-Member -NotePropertyName platformModelSettingGate -NotePropertyValue 'success' -Force
$validation|Add-Member -NotePropertyName platformModelMapCoverageGate -NotePropertyValue 'success' -Force
$validation|Add-Member -NotePropertyName platformModelWorkerX64Gate -NotePropertyValue 'success' -Force
$validation|Add-Member -NotePropertyName platformModelLazyRenderGate -NotePropertyValue 'success' -Force
$validation|ConvertTo-Json -Depth 10|Set-Content -LiteralPath $ValidationPath -Encoding UTF8
Write-Host 'platformModelSettingGate: success'
Write-Host 'platformModelMapCoverageGate: success'
Write-Host 'platformModelWorkerX64Gate: success'
Write-Host 'platformModelLazyRenderGate: success'
