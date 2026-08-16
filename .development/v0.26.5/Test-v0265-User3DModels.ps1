Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
$root=(Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$runtime=Join-Path $root 'HuymaierUser3DModels.ps1'
$liveRuntime=Join-Path $root 'HuymaierLivePlatformModels.ps1'
$optimizer=Join-Path $root '.build\Optimize-User3DModels.ps1'
$sourceList=Join-Path $root '.source\source-files.txt'
foreach($p in @($runtime,$liveRuntime,$optimizer,$sourceList)){if(-not(Test-Path -LiteralPath $p -PathType Leaf)){throw "User 3D Models source missing: $p"}}
foreach($ps in @($runtime,$liveRuntime,$optimizer)){
    $tokens=$null;$errors=$null;$ast=[Management.Automation.Language.Parser]::ParseFile($ps,[ref]$tokens,[ref]$errors)
    if(@($errors).Count){throw "$ps failed Windows PowerShell 5.1 parse: $(@($errors|ForEach-Object{$_.Message}) -join '; ')"}
    if($ps -in @($runtime,$liveRuntime)){
        foreach($variable in @($ast.FindAll({param($node)$node -is [Management.Automation.Language.VariableExpressionAst]},$true))){
            if([string]::Equals([string]$variable.VariablePath.UserPath,'Host',[StringComparison]::OrdinalIgnoreCase)){throw "Reserved PowerShell automatic variable `$Host is referenced by active 3D runtime: $ps line $($variable.Extent.StartLineNumber)"}
        }
    }
}
$text=Get-Content -Raw -LiteralPath $runtime -Encoding UTF8
foreach($needle in @(
    'HUYMAIER_USER_3D_MODELS_RUNTIME_V5',"Join-Path `$script:DataDir '3D Models'","Join-Path `$script:BaseDir '3D Models'",'README - Model Names.txt','Get-HcDetectedUser3DModelCount',
    "`$script:SubPage-ne'Customization'",'Platform visuals: ','Icon card size','3D shelf model size','3D Models Folder - ','HcPlatformPresentationOwner','HuymaierUser3DModelsV5',
    'HcModelsBaseNewPlatformCard','HcModelsBaseAddPlatformRail','HcUserModelsBaseAdjustSelectedSlider','HcUserModelsBaseApplyControllerNavigation','HcUserModelsBaseUpdateActionVisuals','HcUserModelsBaseRenderPage',
    'Reset-Hc3DShelfRuntime','New-Hc3DShelfLiveModelView','Start-Hc3DShelfLoadTimer','Queue-Hc3DShelfCard','Update-Hc3DShelfLoadQueue','Start-Hc3DShelfSpinTimer','Queue-Hc3DShelfNeighborhood',
    'Center-Hc3DShelfSelection','Update-Hc3DShelfSelection','New-Hc3DShelfCard','Add-Hc3DPlatformShelf','Set-Hc3DShelfViewFraming','Textured 3D shelf ready:','Deferred redundant Games 3D shelf rebuild','Controller UI dispatch failed:'
)){if(-not$text.Contains($needle)){throw "User 3D Models V5 shelf contract missing: $needle"}}
foreach($forbidden in @('Set-HcAtlasFallbackVisual','HcUser3DCardQueue','Reset-HcUser3DCardQueue','Start-HcUser3DCardTimer','Queue-HcUser3DCard','Update-HcUser3DCardQueue','New-HcUserCardLiveModelView','HcLiveModelCard','Loading live 3D model')){if($text.Contains($forbidden)){throw "Retired V4 per-card presentation path survived V5 shelf cleanup: $forbidden"}}
if($text.Contains("Join-Path `$script:BaseDir 'Assets\\Models\\Live'")){throw 'User 3D Models runtime must not prefer bundled live-model payloads.'}

$viewStart=$text.IndexOf('function New-Hc3DShelfLiveModelView',[StringComparison]::Ordinal);$loadStart=$text.IndexOf('function Start-Hc3DShelfLoadTimer',[math]::Max(0,$viewStart),[StringComparison]::Ordinal)
if($viewStart-lt0-or$loadStart-le$viewStart){throw 'Could not isolate V5 textured shelf view constructor.'}
$viewScope=$text.Substring($viewStart,$loadStart-$viewStart)
foreach($needle in @('New-Object HuymaierConsole.Modeling.LiveModelView -ArgumentList @($Path)','Set-Hc3DShelfViewFraming')){if(-not$viewScope.Contains($needle)){throw "V5 textured shelf view missing: $needle"}}
if($viewScope.Contains('@($Path,$true)')){throw 'V5 shelf still invokes the geometry-only card-mode constructor instead of the original textured loader.'}

$loadQueueStart=$text.IndexOf('function Update-Hc3DShelfLoadQueue',[StringComparison]::Ordinal);$spinStart=$text.IndexOf('function Start-Hc3DShelfSpinTimer',[math]::Max(0,$loadQueueStart),[StringComparison]::Ordinal)
if($loadQueueStart-lt0-or$spinStart-le$loadQueueStart){throw 'Could not isolate V5 shelf lazy loader.'}
$loadScope=$text.Substring($loadQueueStart,$spinStart-$loadQueueStart)
foreach($needle in @('New-Hc3DShelfLiveModelView','$card.VisualHost.Child=$view','$card.View=$view','$card.VisualHost.Child=$card.Icon','HcUser3DReadyCount++','HcUser3DFailedCount++')){if(-not$loadScope.Contains($needle)){throw "V5 shelf loader missing fallback/attachment contract: $needle"}}
if($loadScope.Contains('Render-Page')){throw 'V5 lazy model loader must not rebuild the Games page while attaching a model.'}

$spinEnd=$text.IndexOf('function Queue-Hc3DShelfNeighborhood',[math]::Max(0,$spinStart),[StringComparison]::Ordinal)
if($spinStart-lt0-or$spinEnd-le$spinStart){throw 'Could not isolate V5 turntable timer.'}
$spinScope=$text.Substring($spinStart,$spinEnd-$spinStart)
foreach($needle in @('FromMilliseconds(50)','.Rotate(.60,0)','.Rotate(.22,0)')){if(-not$spinScope.Contains($needle)){throw "V5 turntable animation contract missing: $needle"}}
if($spinScope.Contains('Render-Page')){throw 'V5 turntable animation illegally rebuilds the page instead of rotating Viewport3D transforms.'}

$neighborStart=$text.IndexOf('function Queue-Hc3DShelfNeighborhood',[StringComparison]::Ordinal);$centerStart=$text.IndexOf('function Center-Hc3DShelfSelection',[math]::Max(0,$neighborStart),[StringComparison]::Ordinal)
if($neighborStart-lt0-or$centerStart-le$neighborStart){throw 'Could not isolate V5 shelf neighborhood loader.'}
$neighborScope=$text.Substring($neighborStart,$centerStart-$neighborStart)
foreach($needle in @('@(0,1,-1,2,-2)','Queue-Hc3DShelfCard')){if(-not$neighborScope.Contains($needle)){throw "V5 neighborhood loading contract missing: $needle"}}

$selectionStart=$text.IndexOf('function Update-Hc3DShelfSelection',[StringComparison]::Ordinal);$cardFactoryStart=$text.IndexOf('function New-Hc3DShelfCard',[math]::Max(0,$selectionStart),[StringComparison]::Ordinal)
if($selectionStart-lt0-or$cardFactoryStart-le$selectionStart){throw 'Could not isolate V5 shelf selection layout.'}
$selectionScope=$text.Substring($selectionStart,$cardFactoryStart-$selectionStart)
foreach($needle in @('$card.Button.Width=470','$card.Button.Height=390','$card.VisualHost.Height=302','$distance-eq1','$distance-eq2','Center-Hc3DShelfSelection','Queue-Hc3DShelfNeighborhood','Start-Hc3DShelfSpinTimer')){if(-not$selectionScope.Contains($needle)){throw "V5 centered/enlarged shelf contract missing: $needle"}}

$framingStart=$text.IndexOf('function Set-Hc3DShelfViewFraming',[StringComparison]::Ordinal);$viewFn=$text.IndexOf('function New-Hc3DShelfLiveModelView',[math]::Max(0,$framingStart),[StringComparison]::Ordinal)
if($framingStart-lt0-or$viewFn-le$framingStart){throw 'Could not isolate V5 safe shelf framing.'}
$framingScope=$text.Substring($framingStart,$viewFn-$framingStart)
foreach($needle in @('$safeScale=55.0','150.0)*29.0','SetScalePercent($safeScale)')){if(-not$framingScope.Contains($needle)){throw "V5 safe non-clipping framing contract missing: $needle"}}

$shelfStart=$text.IndexOf('function Add-Hc3DPlatformShelf',[StringComparison]::Ordinal);$platformCardStart=$text.IndexOf('function New-PlatformCard',[math]::Max(0,$shelfStart),[StringComparison]::Ordinal)
if($shelfStart-lt0-or$platformCardStart-le$shelfStart){throw 'Could not isolate V5 Games 3D shelf construction.'}
$shelfScope=$text.Substring($shelfStart,$platformCardStart-$shelfStart)
foreach($needle in @('$script:Hc3DShelfMounted=$true','$script:Hc3DShelfStart=$script:ActionButtons.Count','$scroll.Height=430','HorizontalScrollBarVisibility=','New-Hc3DShelfCard','platform-select:','HomeRows','Update-Hc3DShelfSelection')){if(-not$shelfScope.Contains($needle)){throw "V5 Games shelf construction missing: $needle"}}

$cardStart=$text.IndexOf('function New-PlatformCard',[StringComparison]::Ordinal);$railStart=$text.IndexOf('function Add-PlatformRail',[math]::Max(0,$cardStart),[StringComparison]::Ordinal)
if($cardStart-lt0-or$railStart-le$cardStart){throw 'Could not isolate V5 icon-mode New-PlatformCard implementation.'}
$cardScope=$text.Substring($cardStart,$railStart-$cardStart)
foreach($needle in @('$button=& $script:HcUserModelsBaseNewPlatformCard',"(Get-HcPlatformVisualStyle)-eq'Icons'",'PlatformIconScale')){if(-not$cardScope.Contains($needle)){throw "V5 icon card fallback contract missing: $needle"}}
if($cardScope.Contains('LiveModelView')-or$cardScope.Contains('Queue-Hc3DShelfCard')){throw 'V5 New-PlatformCard still attempts to own 3D shelf model construction.'}
$railEnd=$text.IndexOf('function Update-ActionVisuals',[math]::Max(0,$railStart),[StringComparison]::Ordinal);$railScope=$text.Substring($railStart,$railEnd-$railStart)
foreach($needle in @("(Get-HcPlatformVisualStyle)-eq'3D Models'",'Add-Hc3DPlatformShelf','HcUserModelsBaseAddPlatformRail')){if(-not$railScope.Contains($needle)){throw "V5 rail dispatch contract missing: $needle"}}

$renderStart=$text.IndexOf('function Render-Page',[StringComparison]::Ordinal);$settingsStart=$text.IndexOf('function Add-HcPlatformPresentationSettings',[math]::Max(0,$renderStart),[StringComparison]::Ordinal)
if($renderStart-lt0-or$settingsStart-le$renderStart){throw 'Could not isolate V5 persistent-shelf Render-Page boundary.'}
$renderScope=$text.Substring($renderStart,$settingsStart-$renderStart)
foreach($needle in @('$script:Hc3DShelfMounted',"`$script:SelectedTab-eq1",'Deferred redundant Games 3D shelf rebuild','Reset-Hc3DShelfRuntime','HcUserModelsBaseRenderPage')){if(-not$renderScope.Contains($needle)){throw "V5 background-refresh suppression contract missing: $needle"}}

$actionStart=$text.IndexOf('function Invoke-Action',[StringComparison]::Ordinal);$sliderStart=$text.IndexOf('function Adjust-SelectedSlider',[math]::Max(0,$actionStart),[StringComparison]::Ordinal)
if($actionStart-lt0-or$sliderStart-le$actionStart){throw 'Could not isolate V5 platform settings action owner.'};$actionScope=$text.Substring($actionStart,$sliderStart-$actionStart)
foreach($needle in @("'platform-visual-style'","'platform-icon-scale-slider'","'platform-model-scale-slider'","'open-3d-models-folder'",'Save-Config','Render-Page')){if(-not$actionScope.Contains($needle)){throw "V5 settings action owner missing: $needle"}}
$navStart=$text.IndexOf('function Apply-ControllerNavigation',[StringComparison]::Ordinal);if($navStart-lt0){throw 'V5 controller UI dispatch boundary is missing.'};$navScope=$text.Substring($navStart);foreach($needle in @('& $script:HcUserModelsBaseApplyControllerNavigation','Controller UI dispatch failed:')){if(-not$navScope.Contains($needle)){throw "V5 controller UI dispatch boundary missing: $needle"}}

$expected=@('Arcade.glb','Atari 2600.glb','Atari Lynx.glb','Epic Games.glb','Neo Geo Pocket Color.glb','Neo Geo.glb','Nintendo 3DS.glb','Nintendo 64.glb','Nintendo DS.glb','Nintendo DSI.glb','Nintendo Entertainment System.glb','Nintendo Game Boy Advance.glb','Nintendo Game Boy Color.glb','Nintendo Game Boy.glb','Nintendo GameCube.glb','Nintendo Switch.glb','Nintendo Wii U.glb','Nintendo Wii.glb','PlayStation 2.glb','PlayStation 3.glb','Playstation 4.glb','Playstation 5.glb','Sega Dreamcast.glb','Sega Genesis.glb','Sega Logo.glb','Sega Master System.glb','Sega Mega Drive.glb','Sega Saturn.glb','Sony Playstation Portable.glb','Sony Playstation Vita.glb','Sony PlayStation.glb','Steam.glb','Super Nintendo Entertainment System.glb','XBOX 360.glb','Xbox One.glb','Xbox.glb')
foreach($name in $expected){if(-not$text.Contains("'$name'")){throw "Original model filename is missing from V5 user folder guide: $name"}}
if($expected.Count-ne36){throw 'Expected original model filename count changed.'}

$opt=Get-Content -Raw -LiteralPath $optimizer -Encoding UTF8
foreach($needle in @('HUYMAIER_USER_3D_MODELS_RUNTIME_LOAD_V1','HuymaierUser3DModels.ps1','HUYMAIER_USER_3D_MODELS_PREFLIGHT_V1','HUYMAIER_USER_3D_MODELS_INSTALLER_CACHE_V1')){if(-not$opt.Contains($needle)){throw "User 3D Models optimizer contract missing: $needle"}}
$sources=@(Get-Content -LiteralPath $sourceList -Encoding UTF8);if($sources-notcontains'HuymaierUser3DModels.ps1'){throw 'Release source list does not include HuymaierUser3DModels.ps1.'};if($sources-contains'Native/HuymaierBuiltInModelGenerator.cs'){throw 'Release source list still includes the retired built-in GLB generator.'}

Write-Host 'platformModelUserFolderGate: success'
Write-Host 'platformModelOriginalNamingGate: success'
Write-Host 'platformModelCustomizationOnlyGate: success'
Write-Host 'platformModelTexturedShelfGate: success'
Write-Host 'platformModelLazyNeighborhoodGate: success'
Write-Host 'platformModelTurntableAnimationGate: success'
Write-Host 'platformModelCenteredSelectionGate: success'
Write-Host 'platformModelSafeFramingGate: success'
Write-Host 'platformModelBackgroundRefreshSuppressionGate: success'
Write-Host 'platformModelPresentationOwnershipGate: success'
Write-Host 'platformModelSettingsActionOwnershipGate: success'
Write-Host 'platformModelControllerUiBoundaryGate: success'
Write-Host 'platformModelReservedHostVariableGate: success'
Write-Host 'platformModelNoBundledGeneratorGate: success'