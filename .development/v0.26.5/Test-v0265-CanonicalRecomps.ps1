Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
$root=(Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$v7=Join-Path $root 'HuymaierGpuPlatformShelves.ps1'
$registryPath=Join-Path $root 'EmulatorPlatforms\platform-registry.json'
$modelMapPath=Join-Path $root 'Assets\Models\model-map.json'
$userModels=Join-Path $root 'HuymaierUser3DModels.ps1'
foreach($p in @($v7,$registryPath,$modelMapPath,$userModels)){if(-not(Test-Path -LiteralPath $p -PathType Leaf)){throw "Canonical/Recomps test source missing: $p"}}

$tokens=$null;$errors=$null
[void][Management.Automation.Language.Parser]::ParseFile($v7,[ref]$tokens,[ref]$errors)
if(@($errors).Count){throw "V7 failed Windows PowerShell 5.1 parse: $(@($errors|ForEach-Object{$_.Message}) -join '; ')"}

$registry=Get-Content -Raw -LiteralPath $registryPath -Encoding UTF8|ConvertFrom-Json
$nes=@($registry.platforms|Where-Object{$_.id -eq 'nes'}|Select-Object -First 1)
$snes=@($registry.platforms|Where-Object{$_.id -eq 'snes'}|Select-Object -First 1)
if($nes.Count-ne1-or$snes.Count-ne1){throw 'NES/SNES central registry entries missing.'}
if([string]$nes[0].menuName-ne'Nintendo Entertainment System'){throw 'NES menuName is not canonical.'}
if([string]$snes[0].menuName-ne'Super Nintendo Entertainment System'){throw 'SNES menuName is not canonical.'}
foreach($alias in @('NES','Nintendo NES','Entertainment System','Nintendo Entertainment System')){if(@($nes[0].aliases)-notcontains$alias){throw "NES alias missing: $alias"}}
foreach($alias in @('SNES','Super NES','Super Nintendo','Super Entertainment System','Super Nintendo Entertainment System')){if(@($snes[0].aliases)-notcontains$alias){throw "SNES alias missing: $alias"}}

$modelMap=Get-Content -Raw -LiteralPath $modelMapPath -Encoding UTF8|ConvertFrom-Json
foreach($alias in @('NES','Nintendo NES','Entertainment System','Nintendo Entertainment System')){
    if([string]$modelMap.models.$alias-ne'atlas:nintendo-entertainment-system'){throw "NES model alias does not share canonical identity: $alias"}
}
foreach($alias in @('SNES','Super NES','Super Nintendo','Super Entertainment System','Super Nintendo Entertainment System')){
    if([string]$modelMap.models.$alias-ne'atlas:super-nintendo-entertainment-system'){throw "SNES model alias does not share canonical identity: $alias"}
}
if([string]$modelMap.models.Xbox-eq[string]$modelMap.models.'Original Xbox'){throw 'Xbox PC provider collapsed into Original Xbox model identity.'}
$userModelText=Get-Content -Raw -LiteralPath $userModels -Encoding UTF8
if($userModelText -notmatch "'xbox'\s*\{\[void\]\$names\.Add\('Xbox App\.glb'\)"){throw 'Xbox PC provider no longer prefers Xbox App.glb.'}

$tempRoot=$(if($env:RUNNER_TEMP){$env:RUNNER_TEMP}else{[IO.Path]::GetTempPath()})
$temp=Join-Path $tempRoot ('hc-recomps-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $temp|Out-Null
try{
    $game1=Join-Path $temp 'Zelda64Recompiled';$game2=Join-Path $temp 'MajorasMask';$helper=Join-Path $temp 'HelperOnly'
    New-Item -ItemType Directory -Force -Path $game1,(Join-Path $game2 'build\release'),$helper|Out-Null
    New-Item -ItemType File -Force -Path (Join-Path $game1 'Zelda64Recompiled.exe')|Out-Null
    New-Item -ItemType File -Force -Path (Join-Path $game1 'updater.exe')|Out-Null
    New-Item -ItemType File -Force -Path (Join-Path $game2 'build\release\MajorasMask.exe')|Out-Null
    New-Item -ItemType File -Force -Path (Join-Path $helper 'setup.exe')|Out-Null

    $script:DataDir=Join-Path $temp 'Data';New-Item -ItemType Directory -Force -Path $script:DataDir|Out-Null
    $script:BaseDir=$root
    $script:Config=[pscustomobject]@{ProviderInstallRoots=@([pscustomobject]@{Provider='Recomps';Path=$temp});PlatformModelScale=100}
    $script:SelectedGamePlatform='Entertainment System'
    $script:SubPage=''
    $script:PickerCapture=$null
    function Get-EntryProperty {param($Object,[string]$Name,$Default=$null);if($null-eq$Object){return $Default};$p=$Object.PSObject.Properties[$Name];if($null-eq$p){return $Default};return $p.Value}
    function New-Action {param([string]$Id,[string]$Label='',[string]$Description='');[pscustomobject]@{Id=$Id;Label=$Label;Description=$Description}}
    function Write-Log {param([string]$Message,[string]$Level='INFO')}
    function Get-GameHubPlatforms {return @('Steam','Epic','GOG','Amazon','Entertainment System','Super Entertainment System','Xbox','Original Xbox')}
    function Get-AllGameHubEntries {return @([pscustomobject]@{Id='Base:one';Name='Existing';Source='Steam';LaunchTarget='steam://run/1'})}
    function Test-HcStorefrontPlatform {param([string]$Platform);return ($Platform -in @('Steam','Epic','GOG','Amazon','Xbox'))}
    function Get-PageDefinition {param([int]$Index);if($Index-eq7){return [pscustomobject]@{Title='Settings';Actions=@((New-Action 'artwork-settings' 'Artwork'))}};return [pscustomobject]@{Title='Other';Actions=@()}}
    function Invoke-Action {param([string]$Id);$script:BaseInvoked=$Id}
    function Start-NativeFilePicker {param([string]$Mode,[string]$Store,[string]$EntryType,[int]$ReturnTab,[string]$StartPath='');$script:PickerCapture=[pscustomobject]@{Mode=$Mode;Store=$Store;EntryType=$EntryType;ReturnTab=$ReturnTab;StartPath=$StartPath}}

    . $v7

    foreach($alias in @('NES','Nintendo NES','Entertainment System','Nintendo Entertainment System')){if((Get-HcCanonicalPlatformName $alias)-ne'Nintendo Entertainment System'){throw "Runtime NES canonicalization failed: $alias"}}
    foreach($alias in @('SNES','Super NES','Super Nintendo','Super Entertainment System','Super Nintendo Entertainment System')){if((Get-HcCanonicalPlatformName $alias)-ne'Super Nintendo Entertainment System'){throw "Runtime SNES canonicalization failed: $alias"}}
    if((Get-HcCanonicalPlatformName 'Xbox')-ne'Xbox'){throw 'Xbox PC identity was canonicalized into hardware.'}

    $platforms=@(Get-GameHubPlatforms)
    foreach($required in @('Recomps','Nintendo Entertainment System','Super Nintendo Entertainment System','Xbox','Original Xbox')){if($platforms-notcontains$required){throw "Games platform list missing: $required"}}
    foreach($bad in @('Entertainment System','Super Entertainment System')){if($platforms-contains$bad){throw "Games platform list retained noncanonical name: $bad"}}
    if(-not(Test-HcStorefrontPlatform 'Recomps')){throw 'Recomps is not classified as a provider.'}
    if(-not(Test-HcStorefrontPlatform 'Xbox')){throw 'Xbox PC provider classification regressed.'}
    if(Test-HcStorefrontPlatform 'Original Xbox'){throw 'Original Xbox hardware was misclassified as a provider.'}

    $recomps=@(Get-HcRecompGames)
    if($recomps.Count-ne2){throw "Expected exactly two recomp games; found $($recomps.Count)."}
    $zelda=@($recomps|Where-Object{$_.Name-eq'Zelda64Recompiled'}|Select-Object -First 1)
    $majora=@($recomps|Where-Object{$_.Name-eq'MajorasMask'}|Select-Object -First 1)
    if($zelda.Count-ne1-or$majora.Count-ne1){throw 'Recomp folder-to-game discovery failed.'}
    foreach($entry in @($zelda[0],$majora[0])){if($entry.Source-ne'Recomps'-or-not$entry.Installed-or-not(Test-Path -LiteralPath $entry.LaunchTarget -PathType Leaf)){throw 'Recomp launch entry is incomplete.'}}
    if([IO.Path]::GetFileName([string]$zelda[0].LaunchTarget)-ne'Zelda64Recompiled.exe'){throw 'Recomp executable preference selected updater/helper instead of the game.'}

    $all=@(Get-AllGameHubEntries)
    if(@($all|Where-Object{$_.Source-eq'Recomps'}).Count-ne2){throw 'Recomp games were not merged into the Games library.'}
    $settings=Get-PageDefinition 7
    $recompAction=@($settings.Actions|Where-Object{$_.Id-eq'recomps-root'}|Select-Object -First 1)
    if($recompAction.Count-ne1-or[string]$recompAction[0].Description-ne$temp){throw 'Recomps folder setting is missing or not bound to the configured root.'}
    Invoke-Action 'recomps-root'
    if($null-eq$script:PickerCapture-or$script:PickerCapture.Mode-ne'PickFolder'-or$script:PickerCapture.Store-ne'Recomps'-or$script:PickerCapture.EntryType-ne'ProviderInstall'-or$script:PickerCapture.StartPath-ne$temp){throw 'Recomps folder action did not route through the native provider folder picker.'}

    Write-Host 'platformCanonicalNesSnesGate: success'
    Write-Host 'platformCanonicalLegacyAliasGate: success'
    Write-Host 'platformCanonicalModelResolverGate: success'
    Write-Host 'platformXboxProviderHardwareIsolationGate: success'
    Write-Host 'recompsProviderClassificationGate: success'
    Write-Host 'recompsFolderDiscoveryGate: success'
    Write-Host 'recompsNativeLaunchEntryGate: success'
    Write-Host 'recompsSettingsFolderPickerGate: success'
}finally{
    Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue
}
