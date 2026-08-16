Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
$root=(Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$runtime=Join-Path $root 'HuymaierUser3DModels.ps1'
$live=Join-Path $root 'HuymaierLivePlatformModels.ps1'
$optimizer=Join-Path $root '.build\Optimize-User3DModels.ps1'
$sourceList=Join-Path $root '.source\source-files.txt'
foreach($p in @($runtime,$live,$optimizer,$sourceList)){if(-not(Test-Path -LiteralPath $p -PathType Leaf)){throw "3D shelf source missing: $p"}}

foreach($ps in @($runtime,$live,$optimizer)){
    $tokens=$null;$errors=$null
    $ast=[Management.Automation.Language.Parser]::ParseFile($ps,[ref]$tokens,[ref]$errors)
    if(@($errors).Count){throw "$ps failed Windows PowerShell 5.1 parse: $(@($errors|ForEach-Object{$_.Message}) -join '; ')"}
    if($ps -in @($runtime,$live)){
        foreach($v in @($ast.FindAll({param($n)$n -is [Management.Automation.Language.VariableExpressionAst]},$true))){
            if([string]::Equals([string]$v.VariablePath.UserPath,'Host',[StringComparison]::OrdinalIgnoreCase)){throw "Active 3D runtime references reserved `$Host: $ps line $($v.Extent.StartLineNumber)"}
        }
    }
}
$text=Get-Content -Raw -LiteralPath $runtime -Encoding UTF8
function Need([string]$needle){if($text.IndexOf($needle,[StringComparison]::Ordinal)-lt0){throw "V5 3D shelf contract missing: $needle"}}
function Reject([string]$needle){if($text.IndexOf($needle,[StringComparison]::Ordinal)-ge0){throw "Retired 3D path survived V5 cleanup: $needle"}}
foreach($n in @(
'HUYMAIER_USER_3D_MODELS_RUNTIME_V5','HUYMAIER_3D_SHELF_BOUNDED_RESIDENCY_V1','HuymaierUser3DModelsV5',
"Join-Path `$script:DataDir '3D Models'",'README - Model Names.txt','Get-HcDetectedUser3DModelCount',
"`$script:SubPage-ne'Customization'",'Platform visuals: ','Icon card size','3D shelf model size','3D Models Folder - ',
'New-Hc3DShelfLiveModelView','Trim-Hc3DShelfResidency','Update-Hc3DShelfLoadQueue','Start-Hc3DShelfSpinTimer','Queue-Hc3DShelfNeighborhood','Center-Hc3DShelfSelection','Update-Hc3DShelfSelection','Add-Hc3DPlatformShelf',
'Textured 3D shelf ready:','Deferred redundant Games 3D shelf rebuild','textureResidency=3','Controller UI dispatch failed:'
)){Need $n}
foreach($n in @('HcUser3DCardQueue','Queue-HcUser3DCard','New-HcUserCardLiveModelView','HcLiveModelCard','Set-HcAtlasFallbackVisual')){Reject $n}

# Full-texture shelf loader: one-argument LiveModelView; never geometry-only card mode.
$viewStart=$text.IndexOf('function New-Hc3DShelfLiveModelView',[StringComparison]::Ordinal)
$viewEnd=$text.IndexOf('function Start-Hc3DShelfLoadTimer',$viewStart,[StringComparison]::Ordinal)
if($viewStart-lt0-or$viewEnd-le$viewStart){throw 'Could not isolate textured shelf constructor.'}
$viewScope=$text.Substring($viewStart,$viewEnd-$viewStart)
if(-not$viewScope.Contains('New-Object HuymaierConsole.Modeling.LiveModelView -ArgumentList @($Path)')){throw 'V5 shelf does not use the original textured GLB loader.'}
if($viewScope.Contains('@($Path,$true)')){throw 'V5 shelf still invokes geometry-only card mode.'}

# The 50..200 user slider maps to a rotation-safe 55..70% occupancy.
$frameStart=$text.IndexOf('function Set-Hc3DShelfViewFraming',[StringComparison]::Ordinal)
$frameEnd=$text.IndexOf('function New-Hc3DShelfLiveModelView',$frameStart,[StringComparison]::Ordinal)
$frame=$text.Substring($frameStart,$frameEnd-$frameStart)
foreach($n in @('$safeScale=55.0','150.0)*15.0','SetScalePercent($safeScale)')){if(-not$frame.Contains($n)){throw "Rotation-safe shelf framing missing: $n"}}

# Focus outside the shelf must not clamp to the first/last platform.
$focusStart=$text.IndexOf('function Get-Hc3DShelfSelectedLocalIndex',[StringComparison]::Ordinal)
$focusEnd=$text.IndexOf('function Set-Hc3DShelfViewFraming',$focusStart,[StringComparison]::Ordinal)
$focus=$text.Substring($focusStart,$focusEnd-$focusStart)
if(-not$focus.Contains('if($index-lt0-or$index-ge$script:Hc3DShelfCards.Count){return -1}')){throw 'Shelf focus boundary does not return -1 outside its action range.'}
if($focus.Contains('[math]::Max')-or$focus.Contains('[math]::Min')){throw 'Shelf focus boundary still clamps non-shelf actions into a platform selection.'}

# Selected + immediate neighbors only: at most three full textured scenes resident.
$trimStart=$text.IndexOf('function Trim-Hc3DShelfResidency',[StringComparison]::Ordinal)
$trimEnd=$text.IndexOf('function Update-Hc3DShelfLoadQueue',$trimStart,[StringComparison]::Ordinal)
$trim=$text.Substring($trimStart,$trimEnd-$trimStart)
foreach($n in @('Abs([int]$request.Card.Index-$Selected)-le1','Abs([int]$card.Index-$Selected)-le1','$card.VisualHost.Child=$card.Icon','$card.View=$null')){if(-not$trim.Contains($n)){throw "Bounded texture residency missing: $n"}}
$queueStart=$trimEnd;$queueEnd=$text.IndexOf('function Start-Hc3DShelfSpinTimer',$queueStart,[StringComparison]::Ordinal)
$queue=$text.Substring($queueStart,$queueEnd-$queueStart)
foreach($n in @('Abs([int]$card.Index-$selected)-gt1','$card.VisualHost.Child=$view','$card.View=$view','$card.VisualHost.Child=$card.Icon')){if(-not$queue.Contains($n)){throw "Lazy shelf loader contract missing: $n"}}
if($queue.Contains('Render-Page')){throw 'Lazy model attachment rebuilds the Games page.'}
$nearStart=$text.IndexOf('function Queue-Hc3DShelfNeighborhood',[StringComparison]::Ordinal)
$nearEnd=$text.IndexOf('function Center-Hc3DShelfSelection',$nearStart,[StringComparison]::Ordinal)
$near=$text.Substring($nearStart,$nearEnd-$nearStart)
if(-not$near.Contains('@(0,1,-1)')){throw 'Shelf neighborhood is not limited to selected + immediate neighbors.'}

# Turntable animation is transform-only and never rebuilds the page.
$spinStart=$text.IndexOf('function Start-Hc3DShelfSpinTimer',[StringComparison]::Ordinal)
$spinEnd=$text.IndexOf('function Queue-Hc3DShelfNeighborhood',$spinStart,[StringComparison]::Ordinal)
$spin=$text.Substring($spinStart,$spinEnd-$spinStart)
foreach($n in @('FromMilliseconds(50)','.Rotate(.60,0)','.Rotate(.22,0)','$distance-eq1')){if(-not$spin.Contains($n)){throw "Turntable animation missing: $n"}}
if($spin.Contains('Render-Page')){throw 'Turntable animation rebuilds the page.'}

# Selected platform is the large center shelf item.
$selectStart=$text.IndexOf('function Update-Hc3DShelfSelection',[StringComparison]::Ordinal)
$selectEnd=$text.IndexOf('function New-Hc3DShelfCard',$selectStart,[StringComparison]::Ordinal)
$select=$text.Substring($selectStart,$selectEnd-$selectStart)
foreach($n in @('Trim-Hc3DShelfResidency $selected','$card.Button.Width=470','$card.Button.Height=390','$card.VisualHost.Height=302','$distance-eq1','$distance-eq2','Center-Hc3DShelfSelection')){if(-not$select.Contains($n)){throw "Centered shelf selection missing: $n"}}

# Background data polling may update data, but may not destroy/recreate the active shelf.
$renderStart=$text.IndexOf('function Render-Page',[StringComparison]::Ordinal)
$renderEnd=$text.IndexOf('function Add-HcPlatformPresentationSettings',$renderStart,[StringComparison]::Ordinal)
$render=$text.Substring($renderStart,$renderEnd-$renderStart)
foreach($n in @('$script:Hc3DShelfMounted',"`$script:SelectedTab-eq1",'Deferred redundant Games 3D shelf rebuild','Reset-Hc3DShelfRuntime','HcUserModelsBaseRenderPage')){if(-not$render.Contains($n)){throw "Persistent shelf refresh boundary missing: $n"}}

$expected=@('Arcade.glb','Atari 2600.glb','Atari Lynx.glb','Epic Games.glb','Neo Geo Pocket Color.glb','Neo Geo.glb','Nintendo 3DS.glb','Nintendo 64.glb','Nintendo DS.glb','Nintendo DSI.glb','Nintendo Entertainment System.glb','Nintendo Game Boy Advance.glb','Nintendo Game Boy Color.glb','Nintendo Game Boy.glb','Nintendo GameCube.glb','Nintendo Switch.glb','Nintendo Wii U.glb','Nintendo Wii.glb','PlayStation 2.glb','PlayStation 3.glb','Playstation 4.glb','Playstation 5.glb','Sega Dreamcast.glb','Sega Genesis.glb','Sega Logo.glb','Sega Master System.glb','Sega Mega Drive.glb','Sega Saturn.glb','Sony Playstation Portable.glb','Sony Playstation Vita.glb','Sony PlayStation.glb','Steam.glb','Super Nintendo Entertainment System.glb','XBOX 360.glb','Xbox One.glb','Xbox.glb')
if($expected.Count-ne36){throw 'Original model filename contract changed.'};foreach($name in $expected){Need "'$name'"}
$opt=Get-Content -Raw -LiteralPath $optimizer -Encoding UTF8;foreach($n in @('HUYMAIER_USER_3D_MODELS_RUNTIME_LOAD_V1','HuymaierUser3DModels.ps1','HUYMAIER_USER_3D_MODELS_PREFLIGHT_V1','HUYMAIER_USER_3D_MODELS_INSTALLER_CACHE_V1')){if(-not$opt.Contains($n)){throw "3D model optimizer contract missing: $n"}}
$sources=@(Get-Content -LiteralPath $sourceList -Encoding UTF8);if($sources-notcontains'HuymaierUser3DModels.ps1'){throw 'Release source list omits V5 presentation owner.'};if($sources-contains'Native/HuymaierBuiltInModelGenerator.cs'){throw 'Release source list still includes retired generated GLB payload.'}

foreach($gate in @('platformModelUserFolderGate','platformModelOriginalNamingGate','platformModelCustomizationOnlyGate','platformModelTexturedShelfGate','platformModelBoundedTextureResidencyGate','platformModelShelfFocusBoundaryGate','platformModelLazyNeighborhoodGate','platformModelTurntableAnimationGate','platformModelCenteredSelectionGate','platformModelSafeFramingGate','platformModelBackgroundRefreshSuppressionGate','platformModelPresentationOwnershipGate','platformModelSettingsActionOwnershipGate','platformModelControllerUiBoundaryGate','platformModelReservedHostVariableGate','platformModelNoBundledGeneratorGate')){Write-Host ($gate+': success')}
