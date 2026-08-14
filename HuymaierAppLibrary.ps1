# Huymaier Console curated Apps library.
# Loaded after HuymaierShellRedesign.ps1 (and its provider concurrency UI)
# so Apps is an explicit, removable console library instead of a Start-menu dump.

Set-StrictMode -Version 2.0
$script:HcAppCategoryOrder=@('Streaming','Music','Video','Utilities','Tools','Browsers','Communication','Productivity','Launchers','Other')
$script:HcSelectedCatalogId=''
$script:HcSelectedManagedAppIndex=-1
$script:HcAppInstallRoot=Join-Path $script:DataDir 'AppInstalls'
$script:HcAppInstallWorkerPath=Join-Path $script:BaseDir 'HuymaierAppInstallWorker.ps1'
$script:HcAppInstallRefreshTimer=$null
$script:HcAppInstallSignatures=@{}
$script:HcAppCompletedObserved=@{}
New-Item -ItemType Directory -Force -Path $script:HcAppInstallRoot|Out-Null

function Set-HcAppObjectProperty {
    param($Object,[string]$Name,$Value)
    if($null -eq $Object -or [string]::IsNullOrWhiteSpace($Name)){return $false}
    try{
        $property=$Object.PSObject.Properties[$Name]
        if($null -eq $property){$Object|Add-Member -NotePropertyName $Name -NotePropertyValue $Value -Force;return $true}
        if(-not [object]::Equals($property.Value,$Value)){$property.Value=$Value;return $true}
    }catch{}
    return $false
}

function Get-HcAppCategory {
    param($Entry)
    $explicit=[string](Get-EntryProperty $Entry 'Category' '')
    if($explicit -and $script:HcAppCategoryOrder -contains $explicit){return $explicit}
    $name=([string](Get-EntryProperty $Entry 'Name' '')).ToLowerInvariant()
    $source=([string](Get-EntryProperty $Entry 'Source' '')).ToLowerInvariant()
    if($name -match 'netflix|disney\+|prime video|hulu|paramount|peacock|plex|twitch|crunchyroll|youtube tv|hbo|max'){return 'Streaming'}
    if($name -match 'spotify|apple music|itunes|musicbee|foobar|tidal|deezer|winamp|pandora'){return 'Music'}
    if($name -match 'vlc|mpv|potplayer|media player|movies.*tv|handbrake|video|photos'){return 'Video'}
    if($name -match 'edge|chrome|firefox|opera|brave|vivaldi|browser'){return 'Browsers'}
    if($name -match 'discord|teams|slack|zoom|skype|telegram|whatsapp|signal'){return 'Communication'}
    if($name -match 'word|excel|powerpoint|onenote|office|notion|obsidian|acrobat|libreoffice'){return 'Productivity'}
    if($name -match 'steam|epic|gog|galaxy|ea app|ubisoft|battle\.net|amazon games|xbox app|launcher' -or $source -match 'storefront|launcher'){return 'Launchers'}
    if($name -match 'visual studio|vscode|github desktop|putty|winscp|filezilla|obs studio|blender|developer|sdk'){return 'Tools'}
    if($name -match 'calculator|notepad|paint|snipping|terminal|powershell|explorer|7-zip|7zip|winrar|settings|utility|utilities'){return 'Utilities'}
    return 'Other'
}

function Initialize-HcAppMetadata {
    $changed=$false
    foreach($app in @($script:Config.CustomApps)){
        if($null -eq $app){continue}
        $category=Get-HcAppCategory $app
        if(Set-HcAppObjectProperty $app 'Category' $category){$changed=$true}
        $web=[string](Get-EntryProperty $app 'WebUrl' '')
        $mode=[string](Get-EntryProperty $app 'PreferredLaunchMode' '')
        if(-not $mode){if($web){$mode='Controller'}else{$mode='Native'};if(Set-HcAppObjectProperty $app 'PreferredLaunchMode' $mode){$changed=$true}}
    }
    if($changed){Save-Config}
}

function Get-HcCuratedAppCatalog {
    return @(
        [pscustomobject]@{Id='netflix';Name='Netflix';Category='Streaming';WebUrl='https://www.netflix.com';StoreId='9WZDNCRFJ3TJ';NativeMatch='Netflix'},
        [pscustomobject]@{Id='disneyplus';Name='Disney+';Category='Streaming';WebUrl='https://www.disneyplus.com';StoreId='9NXQXXLFST89';NativeMatch='Disney+'},
        [pscustomobject]@{Id='primevideo';Name='Prime Video';Category='Streaming';WebUrl='https://www.primevideo.com';StoreId='9P6RC76MSMMJ';NativeMatch='Prime Video'},
        [pscustomobject]@{Id='hulu';Name='Hulu';Category='Streaming';WebUrl='https://www.hulu.com';StoreId='9WZDNCRFJ3L1';NativeMatch='Hulu'},
        [pscustomobject]@{Id='paramountplus';Name='Paramount+';Category='Streaming';WebUrl='https://www.paramountplus.com';StoreId='9WZDNCRFJ0WK';NativeMatch='Paramount+'},
        [pscustomobject]@{Id='plex';Name='Plex';Category='Streaming';WebUrl='https://app.plex.tv';StoreId='XP9CDQW6ML4NQN';NativeMatch='Plex'},
        [pscustomobject]@{Id='spotify';Name='Spotify';Category='Music';WebUrl='https://open.spotify.com';StoreId='9NCBCSZSJRSB';NativeMatch='Spotify'},
        [pscustomobject]@{Id='youtube';Name='YouTube';Category='Streaming';WebUrl='https://www.youtube.com';StoreId='';NativeMatch='YouTube'},
        [pscustomobject]@{Id='twitch';Name='Twitch';Category='Streaming';WebUrl='https://www.twitch.tv';StoreId='';NativeMatch='Twitch'},
        [pscustomobject]@{Id='peacock';Name='Peacock';Category='Streaming';WebUrl='https://www.peacocktv.com';StoreId='';NativeMatch='Peacock'}
    )
}

function Get-HcCatalogEntry {
    param([string]$Id)
    foreach($entry in @(Get-HcCuratedAppCatalog)){if([string]::Equals([string]$entry.Id,$Id,[StringComparison]::OrdinalIgnoreCase)){return $entry}}
    return $null
}

function Find-HcPinnedCatalogAppIndex {
    param([string]$CatalogId)
    for($i=0;$i -lt @($script:Config.CustomApps).Count;$i++){
        $app=@($script:Config.CustomApps)[$i]
        if($null -ne $app -and [string]::Equals([string](Get-EntryProperty $app 'CatalogId' ''),$CatalogId,[StringComparison]::OrdinalIgnoreCase)){return $i}
    }
    return -1
}

function Find-HcInstalledCatalogWindowsApp {
    param($Catalog)
    if($null -eq $Catalog){return $null}
    $match=([string]$Catalog.NativeMatch).ToLowerInvariant()
    if(-not $match){return $null}
    try{
        foreach($app in @(Get-StartApps -ErrorAction SilentlyContinue)){
            $name=[string](Get-EntryProperty $app 'Name' '')
            $id=[string](Get-EntryProperty $app 'AppID' '')
            if(-not $name -or -not $id){continue}
            $lower=$name.ToLowerInvariant()
            if($lower -eq $match -or $lower.StartsWith($match+' ') -or $lower.StartsWith($match+' -')){
                return [pscustomobject]@{Name=$name;AppUserModelId=$id;LaunchTarget=('shell:AppsFolder\'+$id)}
            }
        }
    }catch{}
    return $null
}

function Add-HcControllerCatalogApp {
    param($Catalog,[switch]$Launch)
    if($null -eq $Catalog){return}
    $index=Find-HcPinnedCatalogAppIndex ([string]$Catalog.Id)
    if($index -lt 0){
        $entry=[pscustomobject]@{Name=[string]$Catalog.Name;Path='';Arguments=@();LaunchTarget=[string]$Catalog.WebUrl;AppUserModelId='';Source='Huymaier Controller App';ArtworkPath='';Category=[string]$Catalog.Category;CatalogId=[string]$Catalog.Id;WebUrl=[string]$Catalog.WebUrl;NativeStoreId=[string]$Catalog.StoreId;PreferredLaunchMode='Controller'}
        $script:Config.CustomApps=@($script:Config.CustomApps)+@($entry)
        Save-Config
        $index=@($script:Config.CustomApps).Count-1
    }else{
        $entry=@($script:Config.CustomApps)[$index]
        Set-HcAppObjectProperty $entry 'WebUrl' ([string]$Catalog.WebUrl)|Out-Null
        Set-HcAppObjectProperty $entry 'Category' ([string]$Catalog.Category)|Out-Null
        Set-HcAppObjectProperty $entry 'CatalogId' ([string]$Catalog.Id)|Out-Null
        Set-HcAppObjectProperty $entry 'NativeStoreId' ([string]$Catalog.StoreId)|Out-Null
        Set-HcAppObjectProperty $entry 'PreferredLaunchMode' 'Controller'|Out-Null
        Save-Config
    }
    if($Launch){Start-HcManagedApp @($script:Config.CustomApps)[$index]}
}

function Add-HcNativeCatalogApp {
    param($Catalog,[switch]$Launch)
    if($null -eq $Catalog){return $false}
    $installed=Find-HcInstalledCatalogWindowsApp $Catalog
    if($null -eq $installed){return $false}
    $index=Find-HcPinnedCatalogAppIndex ([string]$Catalog.Id)
    if($index -lt 0){
        $entry=[pscustomobject]@{Name=[string]$Catalog.Name;Path='';Arguments=@();LaunchTarget=[string]$installed.LaunchTarget;AppUserModelId=[string]$installed.AppUserModelId;Source='Microsoft Store';ArtworkPath='';Category=[string]$Catalog.Category;CatalogId=[string]$Catalog.Id;WebUrl=[string]$Catalog.WebUrl;NativeStoreId=[string]$Catalog.StoreId;PreferredLaunchMode='Native'}
        $script:Config.CustomApps=@($script:Config.CustomApps)+@($entry)
        $index=@($script:Config.CustomApps).Count-1
    }else{
        $entry=@($script:Config.CustomApps)[$index]
        Set-HcAppObjectProperty $entry 'AppUserModelId' ([string]$installed.AppUserModelId)|Out-Null
        Set-HcAppObjectProperty $entry 'LaunchTarget' ([string]$installed.LaunchTarget)|Out-Null
        Set-HcAppObjectProperty $entry 'Source' 'Microsoft Store'|Out-Null
        Set-HcAppObjectProperty $entry 'Category' ([string]$Catalog.Category)|Out-Null
        Set-HcAppObjectProperty $entry 'WebUrl' ([string]$Catalog.WebUrl)|Out-Null
        Set-HcAppObjectProperty $entry 'NativeStoreId' ([string]$Catalog.StoreId)|Out-Null
        Set-HcAppObjectProperty $entry 'PreferredLaunchMode' 'Native'|Out-Null
    }
    Save-Config
    if($Launch){Start-HcManagedApp @($script:Config.CustomApps)[$index]}
    return $true
}

function Start-HcManagedApp {
    param($Entry)
    if($null -eq $Entry){return}
    $name=[string](Get-EntryProperty $Entry 'Name' 'App')
    $mode=[string](Get-EntryProperty $Entry 'PreferredLaunchMode' 'Native')
    $web=[string](Get-EntryProperty $Entry 'WebUrl' '')
    $aumid=[string](Get-EntryProperty $Entry 'AppUserModelId' '')
    try{Add-ToRecent 'App' $Entry}catch{}
    if([string]::Equals($mode,'Controller',[StringComparison]::OrdinalIgnoreCase) -and $web){
        if(Get-Command Open-HuymaierBrowser -ErrorAction SilentlyContinue){Open-HuymaierBrowser $web $name;try{Set-HcBrowserFocusArea 'Web'}catch{};return}
    }
    if($aumid){Start-HcWindowsApp $Entry;return}
    if($web -and ([string](Get-EntryProperty $Entry 'Source' '') -match 'Controller App|Streaming')){if(Get-Command Open-HuymaierBrowser -ErrorAction SilentlyContinue){Open-HuymaierBrowser $web $name;try{Set-HcBrowserFocusArea 'Web'}catch{};return}}
    Start-RecentEntry $Entry
}

function Remove-HcManagedApp {
    param([int]$Index)
    $apps=@($script:Config.CustomApps)
    if($Index -lt 0 -or $Index -ge $apps.Count){return}
    $removed=$apps[$Index]
    $next=New-Object System.Collections.ArrayList
    for($i=0;$i -lt $apps.Count;$i++){if($i -ne $Index){[void]$next.Add($apps[$i])}}
    $script:Config.CustomApps=[object[]]$next.ToArray()
    $catalogId=[string](Get-EntryProperty $removed 'CatalogId' '')
    $aumid=[string](Get-EntryProperty $removed 'AppUserModelId' '')
    $target=[string](Get-EntryProperty $removed 'LaunchTarget' (Get-EntryProperty $removed 'Path' ''))
    $recent=New-Object System.Collections.ArrayList
    foreach($item in @($script:Config.RecentApps)){
        $same=$false
        if($catalogId -and [string]::Equals([string](Get-EntryProperty $item 'CatalogId' ''),$catalogId,[StringComparison]::OrdinalIgnoreCase)){$same=$true}
        if(-not $same -and $aumid -and [string]::Equals([string](Get-EntryProperty $item 'AppUserModelId' ''),$aumid,[StringComparison]::OrdinalIgnoreCase)){$same=$true}
        if(-not $same -and $target -and [string]::Equals([string](Get-EntryProperty $item 'LaunchTarget' (Get-EntryProperty $item 'Path' '')),$target,[StringComparison]::OrdinalIgnoreCase)){$same=$true}
        if(-not $same){[void]$recent.Add($item)}
    }
    $script:Config.RecentApps=[object[]]$recent.ToArray();Save-Config
    Set-ConsoleNotice (([string](Get-EntryProperty $removed 'Name' 'App'))+' removed from Huymaier Console. The Windows app was not uninstalled.') 'INFO'
}

function Get-HcAppInstallStatePath {param([string]$CatalogId);return (Join-Path $script:HcAppInstallRoot (('app-'+($CatalogId -replace '[^A-Za-z0-9_-]','_'))+'.json'))}
function Read-HcAppInstallState {
    param([string]$CatalogId)
    $path=Get-HcAppInstallStatePath $CatalogId
    if(-not(Test-Path -LiteralPath $path -PathType Leaf)){return $null}
    try{return (Get-Content -Raw -LiteralPath $path -Encoding UTF8|ConvertFrom-Json)}catch{return $null}
}
function Get-HcAppInstallStates {
    $items=New-Object System.Collections.ArrayList
    try{foreach($file in @(Get-ChildItem -LiteralPath $script:HcAppInstallRoot -Filter 'app-*.json' -File -ErrorAction SilentlyContinue)){try{$state=Get-Content -Raw -LiteralPath $file.FullName -Encoding UTF8|ConvertFrom-Json;if($null -ne $state){[void]$items.Add($state)}}catch{}}}catch{}
    return [object[]]$items.ToArray()
}
function Format-HcAppInstallEta {
    param($State)
    $eta=[int64](Get-EntryProperty $State 'EtaSeconds' -1)
    if($eta -lt 0){return 'Calculating ETA...'}
    $span=[TimeSpan]::FromSeconds($eta)
    if($span.TotalHours -ge 1){return ('About {0}h {1}m remaining' -f [math]::Floor($span.TotalHours),$span.Minutes)}
    if($span.TotalMinutes -ge 1){return ('About {0} min remaining' -f [math]::Ceiling($span.TotalMinutes))}
    return ('About {0} sec remaining' -f [math]::Max(1,[math]::Ceiling($span.TotalSeconds)))
}

function Start-HcAppInstallRefreshTimer {
    if($null -eq $script:HcAppInstallRefreshTimer){
        $timer=New-Object System.Windows.Threading.DispatcherTimer
        $timer.Interval=[TimeSpan]::FromMilliseconds(700)
        $timer.Add_Tick({
            try{
                $changed=$false;$busy=$false
                foreach($state in @(Get-HcAppInstallStates)){
                    $id=[string](Get-EntryProperty $state 'CatalogId' '')
                    if([bool](Get-EntryProperty $state 'Busy' $false)){$busy=$true}
                    $path=Get-HcAppInstallStatePath $id
                    $sig='';try{$sig=(Get-Item -LiteralPath $path -ErrorAction Stop).LastWriteTimeUtc.Ticks.ToString()}catch{}
                    if($id -and (-not $script:HcAppInstallSignatures.ContainsKey($id) -or $script:HcAppInstallSignatures[$id] -ne $sig)){$script:HcAppInstallSignatures[$id]=$sig;$changed=$true}
                    if($id -and [string]::Equals([string](Get-EntryProperty $state 'Phase' ''),'Complete',[StringComparison]::OrdinalIgnoreCase) -and -not $script:HcAppCompletedObserved.ContainsKey($id)){
                        $script:HcAppCompletedObserved[$id]=$true
                        $catalog=Get-HcCatalogEntry $id
                        if($null -ne $catalog){[void](Add-HcNativeCatalogApp $catalog)}
                    }
                }
                if($changed -and (($script:SelectedTab -eq 2 -and $script:SubPage -in @('AppsStore','AppCatalogDetail','AppsManage','AppManageDetail')) -or $script:SelectedTab -eq 4)){Render-Page}
                if(-not $busy){$script:HcAppInstallRefreshTimer.Stop()}
            }catch{Write-Log ('App install refresh recovered: '+$_.Exception.Message) 'WARN'}
        })
        $script:HcAppInstallRefreshTimer=$timer
    }
    $script:HcAppInstallRefreshTimer.Start()
}

function Start-HcNativeCatalogInstall {
    param($Catalog)
    if($null -eq $Catalog -or [string]::IsNullOrWhiteSpace([string]$Catalog.StoreId)){Set-ConsoleNotice 'This app currently uses Controller Mode because no verified native Microsoft Store package is configured.' 'INFO';return}
    if(-not(Test-Path -LiteralPath $script:HcAppInstallWorkerPath -PathType Leaf)){Set-ConsoleNotice 'The native app install worker is missing.' 'ERROR';return}
    $state=Read-HcAppInstallState ([string]$Catalog.Id)
    if($null -ne $state -and [bool](Get-EntryProperty $state 'Busy' $false)){Set-ConsoleNotice (([string]$Catalog.Name)+' is already installing.') 'INFO';Start-HcAppInstallRefreshTimer;return}
    $path=Get-HcAppInstallStatePath ([string]$Catalog.Id)
    try{
        $powershell="$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
        $worker='"'+$script:HcAppInstallWorkerPath.Replace('"','')+'"'
        $stateArg='"'+$path.Replace('"','')+'"'
        $nameArg='"'+([string]$Catalog.Name).Replace('"','')+'"'
        $args="-NoLogo -NoProfile -ExecutionPolicy Bypass -File $worker -CatalogId $($Catalog.Id) -Name $nameArg -StoreId $($Catalog.StoreId) -StatePath $stateArg"
        Start-Process -FilePath $powershell -ArgumentList $args -WindowStyle Hidden|Out-Null
        $script:HcAppCompletedObserved.Remove([string]$Catalog.Id)
        Start-HcAppInstallRefreshTimer
        Set-ConsoleNotice (([string]$Catalog.Name)+' native installation started. It will also appear under Downloads.') 'INFO'
    }catch{Set-ConsoleNotice ('Native app installation could not start: '+$_.Exception.Message) 'ERROR'}
}

function Add-HcAppsCardRows {
    param([int]$Start,[int]$Count)
    if($Count -le 0){return}
    $columns=8
    try{$w=[double]$script:ActionScrollViewer.ActualWidth;if($w -gt 500){$columns=[math]::Max(4,[math]::Floor($w/214))}}catch{}
    for($r=0;$r -lt $Count;$r+=$columns){$script:HomeRows+=,[pscustomobject]@{Start=$Start+$r;Count=[math]::Min($columns,$Count-$r);Platform=$false}}
}

function Render-HcAppsRoot {
    Initialize-HcAppMetadata
    $heading=New-Object System.Windows.Controls.TextBlock;$heading.Text='Apps';$heading.FontSize=30;$heading.FontWeight='Bold';$heading.Foreground='White';$heading.Margin='0,0,0,4';$script:ActionPanel.Children.Add($heading)|Out-Null
    $sub=New-Object System.Windows.Controls.TextBlock;$sub.Text='Your curated console app library';$sub.FontSize=13;$sub.Foreground='#91A3BA';$sub.Margin='0,0,0,18';$script:ActionPanel.Children.Add($sub)|Out-Null

    $utilityWrap=New-Object System.Windows.Controls.WrapPanel;$utilityWrap.Orientation='Horizontal';$utilityStart=$script:ActionButtons.Count
    foreach($utility in @(@('apps-add','Add App','+'),@('apps-store','App Store','↓'),@('apps-manage','Manage Apps','⚙'),@('apps-browser','Web Browser','◎'),@('apps-files','File Browser','▱'))){
        $b=New-HcUtilityCard $utility[0] $utility[1] $utility[2];$utilityWrap.Children.Add($b)|Out-Null;$script:ActionButtons+=$b;$script:CurrentActions+=(New-Action $utility[0] $utility[1])
    }
    $script:ActionPanel.Children.Add($utilityWrap)|Out-Null;Add-HcAppsCardRows $utilityStart ($script:ActionButtons.Count-$utilityStart)

    $pairs=New-Object System.Collections.ArrayList
    for($i=0;$i -lt @($script:Config.CustomApps).Count;$i++){
        $app=@($script:Config.CustomApps)[$i]
        if($null -eq $app -or (Test-HcAppIsRecognizedGame $app)){continue}
        [void]$pairs.Add([pscustomobject]@{Index=$i;Entry=$app;Category=(Get-HcAppCategory $app)})
    }
    foreach($category in $script:HcAppCategoryOrder){
        $categoryApps=@($pairs|Where-Object{$_.Category -eq $category})
        if($categoryApps.Count -eq 0){continue}
        $label=New-Object System.Windows.Controls.TextBlock;$label.Text=$category;$label.FontSize=20;$label.FontWeight='SemiBold';$label.Foreground='#E7C45E';$label.Margin='0,22,0,8';$script:ActionPanel.Children.Add($label)|Out-Null
        $wrap=New-Object System.Windows.Controls.WrapPanel;$wrap.Orientation='Horizontal';$start=$script:ActionButtons.Count
        foreach($pair in $categoryApps){$app=$pair.Entry;$index=[int]$pair.Index;$b=New-HomeCard $app "app:$index" 'Apps';$wrap.Children.Add($b)|Out-Null;$script:ActionButtons+=$b;$script:CurrentActions+=(New-Action "app:$index" ([string](Get-EntryProperty $app 'Name' 'App')))}
        $script:ActionPanel.Children.Add($wrap)|Out-Null;Add-HcAppsCardRows $start ($script:ActionButtons.Count-$start)
    }
    if($pairs.Count -eq 0){$empty=New-Object System.Windows.Controls.TextBlock;$empty.Text='No apps pinned yet. Choose Add App or App Store.';$empty.FontSize=16;$empty.Foreground='#91A3BA';$empty.Margin='0,28,0,0';$script:ActionPanel.Children.Add($empty)|Out-Null}
}

$script:HcAppBaseGetPageDefinition=${function:Get-PageDefinition}
function Get-PageDefinition {
    param([int]$Index)
    if($Index -eq 2 -and $script:SubPage -eq 'AppsStore'){
        $actions=New-Object System.Collections.ArrayList
        foreach($app in @(Get-HcCuratedAppCatalog)){$native=if([string]$app.StoreId){'Native + Controller Mode'}else{'Controller Mode'};[void]$actions.Add((New-Action ('app-catalog:'+[string]$app.Id) ([string]$app.Name) (([string]$app.Category)+'  •  '+$native)))}
        [void]$actions.Add((New-Action 'apps-back' 'Back to Apps'))
        return [pscustomobject]@{Title='App Store';Subtitle='Curated controller-friendly applications. Native installs use verified Microsoft Store product IDs when available.';Hero='APPS';HeroText='Install native streaming/music apps or add their controller-first Huymaier web mode.';Actions=[object[]]$actions.ToArray()}
    }
    if($Index -eq 2 -and $script:SubPage -eq 'AppCatalogDetail'){
        $catalog=Get-HcCatalogEntry $script:HcSelectedCatalogId
        if($null -eq $catalog){$script:SubPage='AppsStore';return Get-PageDefinition 2}
        $actions=New-Object System.Collections.ArrayList
        $pinned=Find-HcPinnedCatalogAppIndex ([string]$catalog.Id)
        [void]$actions.Add((New-Action ('app-catalog-controller:'+[string]$catalog.Id) $(if($pinned -ge 0){'Open / prefer Controller Mode'}else{'Add & open Controller Mode'}) 'Huymaier full-screen WebView2 with console cursor and on-screen keyboard.'))
        if([string]$catalog.StoreId){
            $installed=Find-HcInstalledCatalogWindowsApp $catalog
            $state=Read-HcAppInstallState ([string]$catalog.Id)
            if($null -ne $installed){[void]$actions.Add((New-Action ('app-catalog-native:'+[string]$catalog.Id) 'Open / prefer Native App' 'Launch the Microsoft Store app and keep Controller Mode as a fallback.'))}
            elseif($null -ne $state -and [bool](Get-EntryProperty $state 'Busy' $false)){$progress=[int](Get-EntryProperty $state 'Progress' 0);$detail=if($progress -gt 0){"$progress%  •  $(Format-HcAppInstallEta $state)"}else{'Installing  •  Calculating ETA...'};[void]$actions.Add((New-Action 'noop' 'Native App Installing' $detail))}
            else{[void]$actions.Add((New-Action ('app-catalog-install:'+[string]$catalog.Id) 'Install Native App' 'Download and install the verified Microsoft Store package without leaving Huymaier Console.'))}
        }
        [void]$actions.Add((New-Action 'app-catalog-back' 'Back to App Store'))
        return [pscustomobject]@{Title=[string]$catalog.Name;Subtitle=([string]$catalog.Category+' app');Hero=([string]$catalog.Name).ToUpperInvariant();HeroText='Choose native Windows mode or Huymaier Controller Mode.';Actions=[object[]]$actions.ToArray()}
    }
    if($Index -eq 2 -and $script:SubPage -eq 'AppsManage'){
        Initialize-HcAppMetadata;$actions=New-Object System.Collections.ArrayList
        for($i=0;$i -lt @($script:Config.CustomApps).Count;$i++){$app=@($script:Config.CustomApps)[$i];if($null -eq $app -or (Test-HcAppIsRecognizedGame $app)){continue};$category=Get-HcAppCategory $app;$mode=[string](Get-EntryProperty $app 'PreferredLaunchMode' 'Native');[void]$actions.Add((New-Action "app-manage:$i" ([string](Get-EntryProperty $app 'Name' 'App')) ($category+'  •  '+$mode)))}
        [void]$actions.Add((New-Action 'apps-back' 'Back to Apps'))
        return [pscustomobject]@{Title='Manage Apps';Subtitle='Remove apps from Huymaier Console, change categories, or choose native/controller launch mode.';Hero='APP LIBRARY';HeroText='Removing an app here never uninstalls it from Windows.';Actions=[object[]]$actions.ToArray()}
    }
    if($Index -eq 2 -and $script:SubPage -eq 'AppManageDetail'){
        $i=[int]$script:HcSelectedManagedAppIndex;$apps=@($script:Config.CustomApps);if($i -lt 0 -or $i -ge $apps.Count){$script:SubPage='AppsManage';return Get-PageDefinition 2};$app=$apps[$i];$name=[string](Get-EntryProperty $app 'Name' 'App');$category=Get-HcAppCategory $app;$mode=[string](Get-EntryProperty $app 'PreferredLaunchMode' 'Native');$web=[string](Get-EntryProperty $app 'WebUrl' '')
        $actions=New-Object System.Collections.ArrayList;[void]$actions.Add((New-Action "app-launch-managed:$i" 'Launch' ($mode+' mode')));[void]$actions.Add((New-Action "app-category:$i" ('Category: '+$category) 'Choose where this app appears.'));if($web){[void]$actions.Add((New-Action "app-mode:$i" ('Launch Mode: '+$mode) 'Native uses the Windows app when available; Controller uses Huymaier WebView2.'))};[void]$actions.Add((New-Action "app-remove:$i" 'Remove from Huymaier Console' 'Does not uninstall the Windows application.'));[void]$actions.Add((New-Action 'app-detail-back' 'Back to Manage Apps'))
        return [pscustomobject]@{Title=$name;Subtitle='App management';Hero=$category.ToUpperInvariant();HeroText='Curated app metadata and launch behavior.';Actions=[object[]]$actions.ToArray()}
    }
    if($Index -eq 2 -and $script:SubPage -eq 'AppCategoryPicker'){
        $i=[int]$script:HcSelectedManagedAppIndex;$actions=New-Object System.Collections.ArrayList;foreach($category in $script:HcAppCategoryOrder){[void]$actions.Add((New-Action ("app-set-category:$i:$category") $category))};[void]$actions.Add((New-Action 'app-category-back' 'Back'))
        return [pscustomobject]@{Title='App Category';Subtitle='Choose a category for this app.';Hero='CATEGORIES';HeroText=($script:HcAppCategoryOrder -join '  •  ');Actions=[object[]]$actions.ToArray()}
    }
    if($Index -eq 2 -and $script:SubPage -eq 'AppModePicker'){
        $i=[int]$script:HcSelectedManagedAppIndex
        return [pscustomobject]@{Title='Launch Mode';Subtitle='Choose how this app opens from Huymaier Console.';Hero='CONTROLLER OR NATIVE';HeroText='Controller Mode uses the full-screen Huymaier browser wrapper.';Actions=@((New-Action "app-set-mode:$i:Native" 'Native' 'Use the installed Windows application.'),(New-Action "app-set-mode:$i:Controller" 'Controller Mode' 'Use the Huymaier browser cursor and on-screen keyboard.'),(New-Action 'app-category-back' 'Back'))}
    }
    return (& $script:HcAppBaseGetPageDefinition $Index)
}

$script:HcAppBaseInvokeAction=${function:Invoke-Action}
function Invoke-Action {
    param([string]$Id)
    switch -Regex($Id){
        '^app:(\d+)$' {$i=[int]$matches[1];$apps=@($script:Config.CustomApps);if($i -ge 0 -and $i -lt $apps.Count){Start-HcManagedApp $apps[$i]};return}
        '^home-recent-app:(\d+)$' {$i=[int]$matches[1];if($i -ge 0 -and $i -lt @($script:HcShellRecentApps).Count){Start-HcManagedApp @($script:HcShellRecentApps)[$i]};return}
        '^app-add-windows:(\d+)$' {$i=[int]$matches[1];$script:HcWindowsApps=@(Get-HcWindowsApps);if($i -ge 0 -and $i -lt $script:HcWindowsApps.Count){$a=$script:HcWindowsApps[$i];$exists=@($script:Config.CustomApps|Where-Object{[string]::Equals([string](Get-EntryProperty $_ 'AppUserModelId' ''),[string]$a.AppUserModelId,[StringComparison]::OrdinalIgnoreCase)}).Count -gt 0;if(-not $exists){$entry=[pscustomobject]@{Name=[string]$a.Name;AppUserModelId=[string]$a.AppUserModelId;LaunchTarget=[string]$a.LaunchTarget;Path='';Arguments=@();Source='Windows App';ArtworkPath='';Category=(Get-HcAppCategory $a);PreferredLaunchMode='Native';WebUrl='';CatalogId=''};$script:Config.CustomApps=@($script:Config.CustomApps)+@($entry);Save-Config};$script:SubPage='';$script:SelectedAction=0;Render-Page};return}
        '^app-manage:(\d+)$' {$script:HcSelectedManagedAppIndex=[int]$matches[1];$script:SubPage='AppManageDetail';$script:SelectedAction=0;Render-Page;return}
        '^app-launch-managed:(\d+)$' {$i=[int]$matches[1];$apps=@($script:Config.CustomApps);if($i -ge 0 -and $i -lt $apps.Count){Start-HcManagedApp $apps[$i]};return}
        '^app-remove:(\d+)$' {Remove-HcManagedApp ([int]$matches[1]);$script:HcSelectedManagedAppIndex=-1;$script:SubPage='AppsManage';$script:SelectedAction=0;Render-Page;return}
        '^app-category:(\d+)$' {$script:HcSelectedManagedAppIndex=[int]$matches[1];$script:SubPage='AppCategoryPicker';$script:SelectedAction=0;Render-Page;return}
        '^app-mode:(\d+)$' {$script:HcSelectedManagedAppIndex=[int]$matches[1];$script:SubPage='AppModePicker';$script:SelectedAction=0;Render-Page;return}
        '^app-set-category:(\d+):(.+)$' {$i=[int]$matches[1];$category=[string]$matches[2];$apps=@($script:Config.CustomApps);if($i -ge 0 -and $i -lt $apps.Count -and $script:HcAppCategoryOrder -contains $category){Set-HcAppObjectProperty $apps[$i] 'Category' $category|Out-Null;Save-Config};$script:HcSelectedManagedAppIndex=$i;$script:SubPage='AppManageDetail';$script:SelectedAction=0;Render-Page;return}
        '^app-set-mode:(\d+):(Native|Controller)$' {$i=[int]$matches[1];$mode=[string]$matches[2];$apps=@($script:Config.CustomApps);if($i -ge 0 -and $i -lt $apps.Count){if($mode -eq 'Controller' -and -not [string](Get-EntryProperty $apps[$i] 'WebUrl' '')){Set-ConsoleNotice 'This app has no Controller Mode web target yet.' 'WARN'}else{Set-HcAppObjectProperty $apps[$i] 'PreferredLaunchMode' $mode|Out-Null;Save-Config}};$script:HcSelectedManagedAppIndex=$i;$script:SubPage='AppManageDetail';$script:SelectedAction=0;Render-Page;return}
        '^app-catalog:(.+)$' {$script:HcSelectedCatalogId=[string]$matches[1];$script:SubPage='AppCatalogDetail';$script:SelectedAction=0;Render-Page;return}
        '^app-catalog-controller:(.+)$' {$catalog=Get-HcCatalogEntry ([string]$matches[1]);if($null -ne $catalog){Add-HcControllerCatalogApp $catalog -Launch};return}
        '^app-catalog-install:(.+)$' {$catalog=Get-HcCatalogEntry ([string]$matches[1]);if($null -ne $catalog){Start-HcNativeCatalogInstall $catalog;Render-Page};return}
        '^app-catalog-native:(.+)$' {$catalog=Get-HcCatalogEntry ([string]$matches[1]);if($null -ne $catalog){if(-not(Add-HcNativeCatalogApp $catalog -Launch)){Start-HcNativeCatalogInstall $catalog}};return}
    }
    switch($Id){
        'apps-store' {$script:SubPage='AppsStore';$script:SelectedAction=0;Render-Page;return}
        'apps-manage' {$script:SubPage='AppsManage';$script:SelectedAction=0;Render-Page;return}
        'app-catalog-back' {$script:SubPage='AppsStore';$script:SelectedAction=0;Render-Page;return}
        'app-detail-back' {$script:SubPage='AppsManage';$script:SelectedAction=0;Render-Page;return}
        'app-category-back' {$script:SubPage='AppManageDetail';$script:SelectedAction=0;Render-Page;return}
    }
    & $script:HcAppBaseInvokeAction $Id
}

$script:HcAppBaseRecentAvailable=${function:Test-HcRecentAppAvailable}
function Test-HcRecentAppAvailable {
    param($Entry)
    if($null -eq $Entry){return $false}
    $catalogId=[string](Get-EntryProperty $Entry 'CatalogId' '')
    if($catalogId){return (Find-HcPinnedCatalogAppIndex $catalogId) -ge 0}
    $web=[string](Get-EntryProperty $Entry 'WebUrl' '')
    if($web){return $true}
    $target=[string](Get-EntryProperty $Entry 'LaunchTarget' (Get-EntryProperty $Entry 'Path' ''))
    if($target -and $target -match '^https?://'){return $true}
    if($target -and -not($target -match '^shell:AppsFolder')){return (Test-Path -LiteralPath $target)}
    $aumid=[string](Get-EntryProperty $Entry 'AppUserModelId' '')
    if($aumid){foreach($app in @($script:Config.CustomApps)){if([string]::Equals([string](Get-EntryProperty $app 'AppUserModelId' ''),$aumid,[StringComparison]::OrdinalIgnoreCase)){return $true}};return $false}
    return (& $script:HcAppBaseRecentAvailable $Entry)
}

# Include native app downloads in the same multi-card Downloads surface used by game providers.
if(Get-Command Get-HcActiveDownloadStates -ErrorAction SilentlyContinue){
    $script:HcAppBaseGetActiveDownloadStates=${function:Get-HcActiveDownloadStates}
    function Get-HcActiveDownloadStates {
        $items=New-Object System.Collections.ArrayList
        foreach($state in @(& $script:HcAppBaseGetActiveDownloadStates)){if($null -ne $state){[void]$items.Add($state)}}
        foreach($state in @(Get-HcAppInstallStates)){
            if($null -eq $state -or -not [bool](Get-EntryProperty $state 'Busy' $false)){continue}
            Set-HcAppObjectProperty $state 'TransferId' ('appstore-'+[string](Get-EntryProperty $state 'CatalogId' 'app'))|Out-Null
            Set-HcAppObjectProperty $state 'Provider' 'Microsoft Store'|Out-Null
            Set-HcAppObjectProperty $state 'Mode' 'Install'|Out-Null
            Set-HcAppObjectProperty $state 'GameName' ([string](Get-EntryProperty $state 'Name' 'App'))|Out-Null
            [void]$items.Add($state)
        }
        return [object[]]$items.ToArray()
    }
}
if(Get-Command Update-HcDownloadHistory -ErrorAction SilentlyContinue){
    $script:HcAppBaseUpdateDownloadHistory=${function:Update-HcDownloadHistory}
    function Update-HcDownloadHistory {
        & $script:HcAppBaseUpdateDownloadHistory
        foreach($state in @(Get-HcAppInstallStates)){
            if($null -eq $state -or [bool](Get-EntryProperty $state 'Busy' $false)){continue}
            if(-not [string]::Equals([string](Get-EntryProperty $state 'Phase' ''),'Complete',[StringComparison]::OrdinalIgnoreCase)){continue}
            $id=[string](Get-EntryProperty $state 'CatalogId' 'app');$name=[string](Get-EntryProperty $state 'Name' 'App');$started=[string](Get-EntryProperty $state 'StartedAt' '');$completed=[string](Get-EntryProperty $state 'Updated' '')
            if($completed){Add-HcDownloadCompletion $name 'Microsoft Store' $started $completed ('microsoft-store|install|'+$id+'|'+$started).ToLowerInvariant()}
        }
        Prune-HcDownloadHistory
    }
}

Initialize-HcAppMetadata
