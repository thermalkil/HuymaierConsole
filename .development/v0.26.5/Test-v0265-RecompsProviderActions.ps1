Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
$root=(Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$providers=Join-Path $root 'HuymaierGameProviders.ps1'
$v7=Join-Path $root 'HuymaierGpuPlatformShelves.ps1'
foreach($p in @($providers,$v7)){if(-not(Test-Path -LiteralPath $p -PathType Leaf)){throw "Recomps provider action source missing: $p"}}
$providerText=Get-Content -Raw -LiteralPath $providers -Encoding UTF8
$v7Text=Get-Content -Raw -LiteralPath $v7 -Encoding UTF8
foreach($n in @("Id='Recomps'","Backend='Native'","provider-recomps-folder","provider-refresh:Recomps","provider-recomps-open-folder","[string]::Equals(`$provider,'Recomps'","Start-ExternalProcess `$target")){if($providerText.IndexOf($n,[StringComparison]::Ordinal)-lt0){throw "Recomps provider action contract missing: $n"}}
foreach($n in @("Provider='Recomps'","InstallPath=`$exe.DirectoryName","InstallPath=`$dir.FullName")){if($v7Text.IndexOf($n,[StringComparison]::Ordinal)-lt0){throw "Recomps discovery/provider contract missing: $n"}}

$temp=Join-Path $(if($env:RUNNER_TEMP){$env:RUNNER_TEMP}else{[IO.Path]::GetTempPath()}) ('hc-recomps-actions-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $temp|Out-Null
try{
    $gameDir=Join-Path $temp 'Zelda64Recompiled';New-Item -ItemType Directory -Force -Path $gameDir|Out-Null
    $exe=Join-Path $gameDir 'Zelda64Recompiled.exe';New-Item -ItemType File -Force -Path $exe|Out-Null
    $script:Config=[pscustomobject]@{ProviderInstallRoots=@([pscustomobject]@{Provider='Recomps';Path=$temp});HesServerUrl='';BrowserPath='';BrowserMode='Fullscreen'}
    $script:ProviderCatalog=$null;$script:ProviderState=$null;$script:ProviderCatalogPath=Join-Path $temp 'catalog.json';$script:ProviderStatePath=Join-Path $temp 'state.json';$script:ProviderWorkerPath=Join-Path $temp 'missing-worker.ps1';$script:ProviderToolRoot=$temp;$script:ProviderArtworkRoot=$temp;$script:DataDir=$temp;$script:SelectedGamePlatform='Recomps';$script:SelectedProviderGame=$null;$script:FileBrowserStore='';$script:FileBrowserReturnTab=1;$script:FileBrowserReturnSubPage='ProviderStore';$script:SubPage='ProviderStore';$script:SelectedTab=1;$script:SelectedAction=0;$script:HcRecompCacheUntil=[datetime]::Now.AddHours(1);$script:HcRecompCache=@('stale')
    $script:PickerCapture=$null;$script:LaunchCapture=$null;$script:NoticeCapture='';$script:RenderCount=0
    function Get-EntryProperty {param($Object,[string]$Name,$Default=$null);if($null-eq$Object){return $Default};$prop=$Object.PSObject.Properties[$Name];if($null-eq$prop){return $Default};return $prop.Value}
    function Save-Config {}
    function Set-ConsoleNotice {param([string]$Message,[string]$Level='INFO');$script:NoticeCapture=$Message}
    function Render-Page {$script:RenderCount++}
    function Update-NavVisuals {}
    function Set-Tab {param([int]$Index);$script:SelectedTab=$Index}
    function New-Action {param([string]$Id,[string]$Label='',[string]$Description='');[pscustomobject]@{Id=$Id;Label=$Label;Description=$Description}}
    function Start-NativeFilePicker {param([string]$Mode,[string]$Store,[string]$EntryType,[int]$ReturnTab=-1,[string]$StartPath='');$script:PickerCapture=[pscustomobject]@{Mode=$Mode;Store=$Store;EntryType=$EntryType;ReturnTab=$ReturnTab;StartPath=$StartPath}}
    function Start-ExternalProcess {param([string]$Path,[string[]]$Arguments=@());$script:LaunchCapture=[pscustomobject]@{Path=$Path;Arguments=$Arguments};return $true}
    function Start-UriOrShellTarget {param([string]$Target);throw "Recomps unexpectedly used URI/shell launch: $Target"}
    function Get-HcRecompGames {return @([pscustomobject]@{Id=('Recomps:'+$exe.ToLowerInvariant());Name='Zelda64Recompiled';Source='Recomps';Provider='Recomps';ProviderGameId=('Recomps:'+$exe.ToLowerInvariant());LaunchTarget=$exe;Path=$gameDir;InstallPath=$gameDir;ArtworkPath='';Installed=$true;Description='Native recomp test'})}
    . $providers

    $definition=Get-GameProviderDefinition 'Recomps'
    if($null-eq$definition-or$definition.Backend-ne'Native'){throw 'Recomps is not a first-class Native provider definition.'}
    $node=Get-ProviderCatalogNode 'Recomps'
    if(-not[bool]$node.ToolReady-or-not[bool]$node.Authenticated-or@($node.Games).Count-ne1){throw 'Recomps provider catalog node is not locally ready with discovered games.'}

    if(-not(Invoke-GameProviderAction 'provider-recomps-folder')){throw 'Recomps folder action was not handled.'}
    if($null-eq$script:PickerCapture-or$script:PickerCapture.Mode-ne'PickFolder'-or$script:PickerCapture.Store-ne'Recomps'-or$script:PickerCapture.EntryType-ne'ProviderInstall'-or$script:PickerCapture.ReturnTab-ne1-or$script:PickerCapture.StartPath-ne$temp){throw 'Recomps folder action did not route to the native provider folder picker.'}

    $script:HcRecompCacheUntil=[datetime]::Now.AddHours(1);$script:HcRecompCache=@('stale');$script:RenderCount=0
    if(-not(Invoke-GameProviderAction 'provider-refresh:Recomps')){throw 'Recomps refresh action was not handled.'}
    if(@($script:HcRecompCache).Count-ne0-or$script:HcRecompCacheUntil-ne[datetime]::MinValue-or$script:RenderCount-lt1){throw 'Recomps refresh did not invalidate discovery cache and repaint the provider.'}

    $game=@(Get-HcRecompGames)[0]
    $entry=Convert-ProviderGameToLaunchEntry $game
    if($entry.Provider-ne'Recomps'-or$entry.LaunchTarget-ne$exe-or$entry.InstallPath-ne$gameDir){throw 'Recomps launch entry lost provider/executable/install-path identity.'}
    if(-not(Invoke-ProviderGameLaunchEntry $entry)){throw 'Recomps native launch action was not handled.'}
    if($null-eq$script:LaunchCapture-or$script:LaunchCapture.Path-ne$exe){throw 'Recomps launch did not directly invoke the discovered native executable.'}
    if(Test-Path -LiteralPath $script:ProviderStatePath){throw 'Recomps native launch incorrectly entered the direct-provider worker/state pipeline.'}

    $script:SelectedProviderGame=$game
    $page=Get-GameProviderPageDefinition
    $ids=@($page.Actions|ForEach-Object{[string]$_.Id})
    foreach($required in @('provider-game-launch','provider-recomps-open-folder','provider-game-back')){if($ids-notcontains$required){throw "Recomps game page action missing: $required"}}
    foreach($forbidden in @('provider-game-update','provider-game-verify','provider-game-uninstall','provider-game-install','provider-game-location')){if($ids-contains$forbidden){throw "Recomps game page exposed backend-only action: $forbidden"}}

    Write-Host 'recompsFirstClassProviderGate: success'
    Write-Host 'recompsNativeFolderPickerActionGate: success'
    Write-Host 'recompsRefreshWithoutWorkerGate: success'
    Write-Host 'recompsDirectNativeExeLaunchGate: success'
    Write-Host 'recompsNativeGamePageActionsGate: success'
}finally{Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue}
