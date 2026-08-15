Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
$root=(Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$runtime=Join-Path $root 'HuymaierUser3DModels.ps1'
$optimizer=Join-Path $root '.build\Optimize-User3DModels.ps1'
$sourceList=Join-Path $root '.source\source-files.txt'
foreach($p in @($runtime,$optimizer,$sourceList)){if(-not(Test-Path -LiteralPath $p -PathType Leaf)){throw "User 3D Models source missing: $p"}}
foreach($ps in @($runtime,$optimizer)){$tokens=$null;$errors=$null;[void][Management.Automation.Language.Parser]::ParseFile($ps,[ref]$tokens,[ref]$errors);if(@($errors).Count){throw "$ps failed Windows PowerShell 5.1 parse: $(@($errors|ForEach-Object{$_.Message}) -join '; ')"}}
$text=Get-Content -Raw -LiteralPath $runtime -Encoding UTF8
foreach($needle in @('HUYMAIER_USER_3D_MODELS_RUNTIME_V3',"Join-Path `$script:DataDir '3D Models'","Join-Path `$script:BaseDir '3D Models'",'README - Model Names.txt','Get-HcDetectedUser3DModelCount',"`$script:SubPage -ne 'Customization'","@('platform-visual-style','platform-icon-scale-slider','platform-model-scale-slider','open-3d-models-folder','3d-models-detected')",'Platform visuals: ','Icon card size','3D model size','3D Models Folder - ','Missing or failed GLBs keep the normal icon','Always construct the proven original icon card first','Reset-HcUser3DCardQueue','Start-HcUser3DCardTimer','Queue-HcUser3DCard','Update-HcUser3DCardQueue','New-HcUserCardLiveModelView','HcLiveModelCard','GeometryCount','VertexCount','Loading live 3D model','Bypass the retired static-preview rail wrapper')){if(-not $text.Contains($needle)){throw "User 3D Models runtime contract missing: $needle"}}
if($text.Contains('Set-HcAtlasFallbackVisual')){throw 'User 3D Models runtime must not substitute the static atlas for missing GLBs.'}
if($text.Contains("Join-Path `$script:BaseDir 'Assets\\Models\\Live'")){throw 'User 3D Models runtime must not prefer bundled live-model payloads.'}
$cardStart=$text.IndexOf('function New-PlatformCard',[StringComparison]::Ordinal)
$railStart=$text.IndexOf('function Add-PlatformRail',[math]::Max(0,$cardStart),[StringComparison]::Ordinal)
if($cardStart-lt0-or$railStart-le$cardStart){throw 'Could not isolate final user New-PlatformCard implementation.'}
$cardScope=$text.Substring($cardStart,$railStart-$cardStart)
if($cardScope.Contains('New-HcUserCardLiveModelView')){throw 'New-PlatformCard must not synchronously construct GLB scenes; it should queue them after the page exists.'}
if(-not $cardScope.Contains('Queue-HcUser3DCard')){throw 'New-PlatformCard does not queue the live 3D upgrade.'}
$queueStart=$text.IndexOf('function Update-HcUser3DCardQueue',[StringComparison]::Ordinal)
$cardFn=$text.IndexOf('function New-PlatformCard',[math]::Max(0,$queueStart),[StringComparison]::Ordinal)
if($queueStart-lt0-or$cardFn-le$queueStart){throw 'Could not isolate lazy card queue implementation.'}
$queueScope=$text.Substring($queueStart,$cardFn-$queueStart)
foreach($needle in @('$oldChild=$null','New-HcUserCardLiveModelView','if($null -eq $view){return}','$host.Child=$view','if($null -ne $oldChild){$host.Child=$oldChild}')){if(-not $queueScope.Contains($needle)){throw "Lazy card queue does not preserve icon fallback around live attachment: $needle"}}
$expected=@('Arcade.glb','Atari 2600.glb','Atari Lynx.glb','Epic Games.glb','Neo Geo Pocket Color.glb','Neo Geo.glb','Nintendo 3DS.glb','Nintendo 64.glb','Nintendo DS.glb','Nintendo DSI.glb','Nintendo Entertainment System.glb','Nintendo Game Boy Advance.glb','Nintendo Game Boy Color.glb','Nintendo Game Boy.glb','Nintendo GameCube.glb','Nintendo Switch.glb','Nintendo Wii U.glb','Nintendo Wii.glb','PlayStation 2.glb','PlayStation 3.glb','Playstation 4.glb','Playstation 5.glb','Sega Dreamcast.glb','Sega Genesis.glb','Sega Logo.glb','Sega Master System.glb','Sega Mega Drive.glb','Sega Saturn.glb','Sony Playstation Portable.glb','Sony Playstation Vita.glb','Sony PlayStation.glb','Steam.glb','Super Nintendo Entertainment System.glb','XBOX 360.glb','Xbox One.glb','Xbox.glb')
foreach($name in $expected){if(-not $text.Contains("'$name'")){throw "Original model filename is missing from user folder guide: $name"}}
if($expected.Count -ne 36){throw 'Expected original model filename count changed.'}
$opt=Get-Content -Raw -LiteralPath $optimizer -Encoding UTF8
foreach($needle in @('HUYMAIER_USER_3D_MODELS_RUNTIME_LOAD_V1','HuymaierUser3DModels.ps1','HUYMAIER_USER_3D_MODELS_PREFLIGHT_V1','HUYMAIER_USER_3D_MODELS_INSTALLER_CACHE_V1')){if(-not $opt.Contains($needle)){throw "User 3D Models optimizer contract missing: $needle"}}
$sources=@(Get-Content -LiteralPath $sourceList -Encoding UTF8)
if($sources -notcontains 'HuymaierUser3DModels.ps1'){throw 'Release source list does not include HuymaierUser3DModels.ps1.'}
if($sources -contains 'Native/HuymaierBuiltInModelGenerator.cs'){throw 'Release source list still includes the retired built-in GLB generator.'}
Write-Host 'platformModelUserFolderGate: success'
Write-Host 'platformModelOriginalNamingGate: success'
Write-Host 'platformModelCustomizationOnlyGate: success'
Write-Host 'platformModelIconFallbackOnlyGate: success'
Write-Host 'platformModelLazyCardQueueGate: success'
Write-Host 'platformModelNoBundledGeneratorGate: success'
