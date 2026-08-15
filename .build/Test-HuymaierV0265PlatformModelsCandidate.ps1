param(
    [Parameter(Mandatory=$true)][string]$StageRoot,
    [Parameter(Mandatory=$true)][string]$ValidationPath
)
Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
foreach($required in @('HuymaierConsole.ps1','HuymaierPlatformModels.ps1','HuymaierModelPreviewWorker.exe','HuymaierBootstrap.ps1','Install-HuymaierConsole.ps1','Assets\Models\model-map.json','EmulatorPlatforms\platform-registry.json')){if(-not(Test-Path -LiteralPath (Join-Path $StageRoot $required) -PathType Leaf)){throw "Staged platform-model payload missing: $required"}}
$core=Get-Content -Raw -LiteralPath (Join-Path $StageRoot 'HuymaierConsole.ps1') -Encoding UTF8
$runtime=Get-Content -Raw -LiteralPath (Join-Path $StageRoot 'HuymaierPlatformModels.ps1') -Encoding UTF8
$bootstrap=Get-Content -Raw -LiteralPath (Join-Path $StageRoot 'HuymaierBootstrap.ps1') -Encoding UTF8
$installer=Get-Content -Raw -LiteralPath (Join-Path $StageRoot 'Install-HuymaierConsole.ps1') -Encoding UTF8
$map=Get-Content -Raw -LiteralPath (Join-Path $StageRoot 'Assets\Models\model-map.json') -Encoding UTF8|ConvertFrom-Json
$registry=Get-Content -Raw -LiteralPath (Join-Path $StageRoot 'EmulatorPlatforms\platform-registry.json') -Encoding UTF8|ConvertFrom-Json

foreach($needle in @('HUYMAIER_PLATFORM_3D_MODELS_RUNTIME_V1','PlatformModelsModulePath','Platform 3D model module load failed')){if(-not $core.Contains($needle)){throw "Staged core missing platform-model contract: $needle"}}
foreach($needle in @('HUYMAIER_PLATFORM_3D_MODELS_PREFLIGHT_V1','Platform 3D model runtime')){if(-not $bootstrap.Contains($needle)){throw "Staged bootstrap missing platform-model contract: $needle"}}
foreach($needle in @('HUYMAIER_PLATFORM_3D_MODELS_INSTALLER_CACHE_V1','HuymaierPlatformModels.ps1')){if(-not $installer.Contains($needle)){throw "Staged installer missing platform-model contract: $needle"}}
foreach($needle in @("@('Icons','3D Models')",'platform-visual-style','HuymaierModelPreviewWorker.exe','Request-HcModelPreview','3DModelCache')){if(-not $runtime.Contains($needle)){throw "Staged platform-model runtime missing: $needle"}}
if($runtime -notmatch "(?s)function New-PlatformCard.+Get-HcPlatformVisualStyle.+3D Models.+Resolve-HcPlatformModelPath"){throw '3D model card override is not active in the staged runtime.'}
if($runtime -notmatch "(?s)function Add-PlatformRail.+Reset-HcModelPreviewPageState"){throw '3D model page queue reset is missing.'}

$keys=@{};foreach($p in @($map.models.PSObject.Properties)){$keys[[string]$p.Name.ToLowerInvariant()]=[string]$p.Value}
foreach($provider in @('Steam','Epic','GOG','EA','Ubisoft','Xbox App','Battle.net','Rockstar','Amazon Games')){if(-not $keys.ContainsKey($provider.ToLowerInvariant())){throw "Staged model map missing provider $provider"}}

# Runtime platform matching is intentionally alias-based. Validate the staged map
# against the same registry-visible identities instead of requiring decorative
# literal labels such as "Nintendo Wii" when the canonical runtime key is "Wii".
foreach($platform in @($registry.platforms|Where-Object{[bool]$_.enabled})){
    $aliases=New-Object System.Collections.ArrayList
    foreach($value in @([string]$platform.name,[string]$platform.displayName,[string]$platform.menuName,[string]$platform.id)){if($value){[void]$aliases.Add($value)}}
    foreach($value in @($platform.aliases)){if($value){[void]$aliases.Add([string]$value)}}
    $covered=$false
    foreach($alias in @($aliases)){
        if($keys.ContainsKey(([string]$alias).ToLowerInvariant())){$covered=$true;break}
    }
    if(-not $covered){throw "Staged model map has no runtime alias for enabled platform $([string]$platform.id) / $([string]$platform.name)"}
}

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
