# Huymaier Console v0.26.2 runtime layer.
# Loaded by HuymaierColorPicker.ps1 after the v0.26.1 customization wrappers.
# This keeps v0.26.1 frozen while layering controller-first layout editing,
# Steam game management, provider telemetry, and shared card typography fixes.

$script:HcV0262BaseGetPageDefinition=${function:Get-PageDefinition}
$script:HcV0262BaseInvokeAction=${function:Invoke-Action}
$script:HcV0262BaseGetGameHubPlatforms=${function:Get-GameHubPlatforms}
$script:HcV0262BaseNewPlatformCard=${function:New-PlatformCard}
$script:HcV0262BaseAddPlatformRail=${function:Add-PlatformRail}
$script:HcV0262BaseMoveHomeHorizontal=${function:Move-HomeHorizontal}
$script:HcV0262BaseInvokeSelectedAction=${function:Invoke-SelectedAction}
$script:HcV0262BaseHandleBack=${function:Handle-Back}
$script:HcV0262BaseApplyControllerNavigation=${function:Apply-ControllerNavigation}
$script:HcV0262BaseInvokeSecondaryAction=$(if(Get-Command Invoke-SecondaryAction -ErrorAction SilentlyContinue){${function:Invoke-SecondaryAction}}else{$null})
$script:HcV0262BaseUpdateActionVisuals=${function:Update-ActionVisuals}
$script:HcV0262BaseNewModeChoiceButton=$(if(Get-Command New-HcModeChoiceButton -ErrorAction SilentlyContinue){${function:New-HcModeChoiceButton}}else{$null})
$script:HcV0262BaseGetGameProviderDefinitions=${function:Get-GameProviderDefinitions}
$script:HcV0262BaseGetProviderInstallRoot=${function:Get-ProviderInstallRoot}
$script:HcV0262BaseStartGameProviderWorker=${function:Start-GameProviderWorker}
$script:HcV0262BaseGetPlatformCountSummary=${function:Get-PlatformCountSummary}
$script:HcV0262BaseUpdateActiveDownloadVisuals=$(if(Get-Command Update-HcActiveDownloadVisuals -ErrorAction SilentlyContinue){${function:Update-HcActiveDownloadVisuals}}else{$null})
$script:HcV0262BaseProviderSupportsMove=$(if(Get-Command Test-HcProviderSupportsMove -ErrorAction SilentlyContinue){${function:Test-HcProviderSupportsMove}}else{$null})

$script:HcGamesLayoutEditMode=$false
$script:HcGamesLayoutGrabbed=$false
$script:HcLayoutLastMask=0
$script:HcSteamRefreshRequestedAt=[datetime]::MinValue
$script:HcSteamWorkerPath=Join-Path $script:BaseDir 'HuymaierSteamWorker.ps1'
$script:HcProviderProgressWorkerPath=Join-Path $script:BaseDir 'HuymaierProviderProgressWorker.ps1'

function Initialize-HcV0262Config {
    Add-HcCustomizationConfigProperty 'GamesPlatformOrder' @()
    Add-HcCustomizationConfigProperty 'GamesHiddenPlatforms' @()
    Add-HcCustomizationConfigProperty 'GamesPlatformSizes' @()
    Add-HcCustomizationConfigProperty 'GamesTileDefaultSize' 'Normal'
    $script:Config.GamesPlatformOrder=Convert-ToStableArray $script:Config.GamesPlatformOrder
    $script:Config.GamesHiddenPlatforms=Convert-ToStableArray $script:Config.GamesHiddenPlatforms
    $script:Config.GamesPlatformSizes=Convert-ToStableArray $script:Config.GamesPlatformSizes
    if([string](Get-EntryProperty $script:Config 'GamesTileDefaultSize' 'Normal') -notin @('Small','Normal','Large','Extra Large')){$script:Config.GamesTileDefaultSize='Normal'}
}

function Get-HcOrderedGamePlatforms {
    $raw=New-Object System.Collections.ArrayList;$seen=@{}
    foreach($platform in @(& $script:HcV0262BaseGetGameHubPlatforms)){
        $name=[string]$platform;if(-not $name){continue};$key=$name.ToLowerInvariant();if(-not $seen.ContainsKey($key)){$seen[$key]=$true;[void]$raw.Add($name)}
    }
    $ordered=New-Object System.Collections.ArrayList;$used=@{}
    foreach($wanted in @(Get-EntryProperty $script:Config 'GamesPlatformOrder' @())){
        $wantedName=[string]$wanted;if(-not $wantedName){continue}
        foreach($platform in @($raw)){
            if([string]::Equals([string]$platform,$wantedName,[StringComparison]::OrdinalIgnoreCase)){$key=([string]$platform).ToLowerInvariant();if(-not $used.ContainsKey($key)){[void]$ordered.Add([string]$platform);$used[$key]=$true};break}
        }
    }
    foreach($platform in @($raw)){$key=([string]$platform).ToLowerInvariant();if(-not $used.ContainsKey($key)){[void]$ordered.Add([string]$platform);$used[$key]=$true}}
    return [object[]]$ordered.ToArray()
}
function Test-HcPlatformHidden {param([string]$Platform);foreach($item in @(Get-EntryProperty $script:Config 'GamesHiddenPlatforms' @())){if([string]::Equals([string]$item,$Platform,[StringComparison]::OrdinalIgnoreCase)){return $true}};return $false}
function Get-GameHubPlatforms {
    Initialize-HcV0262Config
    $all=@(Get-HcOrderedGamePlatforms)
    if($script:HcGamesLayoutEditMode){return $all}
    return @($all|Where-Object{-not(Test-HcPlatformHidden ([string]$_))})
}

function Get-HcPlatformSizePreset {
    param([string]$Platform)
    foreach($entry in @(Get-EntryProperty $script:Config 'GamesPlatformSizes' @())){if($null -ne $entry -and [string]::Equals([string](Get-EntryProperty $entry 'Platform' ''),$Platform,[StringComparison]::OrdinalIgnoreCase)){return [string](Get-EntryProperty $entry 'Size' 'Normal')}}
    return [string](Get-EntryProperty $script:Config 'GamesTileDefaultSize' 'Normal')
}
function Set-HcPlatformSizePreset {
    param([string]$Platform,[string]$Size)
    if($Size -notin @('Small','Normal','Large','Extra Large')){return}
    $list=New-Object System.Collections.ArrayList;$done=$false
    foreach($entry in @(Get-EntryProperty $script:Config 'GamesPlatformSizes' @())){
        if($null -eq $entry){continue}
        if([string]::Equals([string](Get-EntryProperty $entry 'Platform' ''),$Platform,[StringComparison]::OrdinalIgnoreCase)){[void]$list.Add([pscustomobject]@{Platform=$Platform;Size=$Size});$done=$true}else{[void]$list.Add($entry)}
    }
    if(-not $done){[void]$list.Add([pscustomobject]@{Platform=$Platform;Size=$Size})}
    $script:Config.GamesPlatformSizes=[object[]]$list.ToArray();Save-Config
}
function Get-HcPlatformCardMetrics {
    param([string]$Size)
    switch($Size){
        'Small' {return [pscustomobject]@{Width=122;Height=122;Margin='0,0,12,9';Icon=68;Image=46;Label=12;Count=8}}
        'Large' {return [pscustomobject]@{Width=190;Height=180;Margin='0,0,18,12';Icon=110;Image=76;Label=16;Count=10}}
        'Extra Large' {return [pscustomobject]@{Width=234;Height=216;Margin='0,0,20,14';Icon=136;Image=94;Label=18;Count=11}}
        default {return [pscustomobject]@{Width=152;Height=148;Margin='0,0,15,10';Icon=92;Image=64;Label=14;Count=9}}
    }
}
function New-PlatformCard {
    param([string]$Platform,[int]$Index)
    $button=& $script:HcV0262BaseNewPlatformCard $Platform $Index
    if($null -eq $button){return $button}
    try{
        $metrics=Get-HcPlatformCardMetrics (Get-HcPlatformSizePreset $Platform)
        $button.Width=$metrics.Width;$button.MinWidth=$metrics.Width;$button.Height=$metrics.Height;$button.MinHeight=$metrics.Height;$button.Margin=$metrics.Margin
        $grid=$button.Content
        if($null -ne $grid -and $grid.Children.Count -ge 3){
            $icon=$grid.Children[0];$label=$grid.Children[1];$count=$grid.Children[2]
            try{$icon.Width=$metrics.Icon;$icon.Height=$metrics.Icon;if($null -ne $icon.Child){$icon.Child.Width=$metrics.Image;$icon.Child.Height=$metrics.Image}}catch{}
            try{$label.FontSize=$metrics.Label;$label.TextWrapping='Wrap';$label.TextTrimming='None';$label.TextAlignment='Center';$label.MinHeight=[math]::Ceiling($metrics.Label*1.45)}catch{}
            try{$count.FontSize=$metrics.Count;$count.TextWrapping='Wrap';$count.TextAlignment='Center'}catch{}
        }
        if($script:HcGamesLayoutEditMode -and (Test-HcPlatformHidden $Platform)){$button.Opacity=.25;$button.ToolTip='Hidden outside Edit Layout mode'}
    }catch{}
    return $button
}
function Add-PlatformRail {
    & $script:HcV0262BaseAddPlatformRail
    if(-not $script:HcGamesLayoutEditMode){return}
    try{
        if($script:ActionPanel.Children.Count -gt 1 -and $script:ActionPanel.Children[1] -is [System.Windows.Controls.TextBlock]){$script:ActionPanel.Children[1].Text='EDIT LAYOUT  •  A select/place  •  Left/Right move  •  LB/RB resize  •  X hide/show  •  B save & exit'}
        foreach($button in @($script:ActionButtons)){try{$button.FocusVisualStyle=$null}catch{}}
        $maxWidth=152;foreach($platform in @($script:GameHubPlatforms)){$maxWidth=[math]::Max($maxWidth,(Get-HcPlatformCardMetrics (Get-HcPlatformSizePreset ([string]$platform))).Width+22)}
        $columns=6;try{$w=[double]$script:ActionScrollViewer.ActualWidth;if($w -gt 500){$columns=[math]::Max(1,[math]::Floor($w/$maxWidth))}}catch{}
        $script:HomeRows=@();for($r=0;$r -lt $script:GameHubPlatforms.Count;$r+=$columns){$script:HomeRows+=,[pscustomobject]@{Start=$r;Count=[math]::Min($columns,$script:GameHubPlatforms.Count-$r);Platform=$true}}
    }catch{}
}
function Save-HcGamesPlatformOrder {
    $script:Config.GamesPlatformOrder=[object[]]@($script:GameHubPlatforms);Save-Config
}
function Move-HcGamesLayoutItem {
    param([int]$Delta)
    $count=@($script:GameHubPlatforms).Count;if($count -le 1){return}
    $index=[math]::Max(0,[math]::Min($count-1,$script:SelectedAction));$target=$index+$Delta;if($target -lt 0 -or $target -ge $count){return}
    $list=New-Object System.Collections.ArrayList;foreach($p in @($script:GameHubPlatforms)){[void]$list.Add([string]$p)}
    $temp=$list[$index];$list[$index]=$list[$target];$list[$target]=$temp;$script:Config.GamesPlatformOrder=[object[]]$list.ToArray();Save-Config
    Render-Page;$script:SelectedAction=$target;Update-ActionVisuals;Invoke-UiFeedback 'Navigate'
}
function Change-HcSelectedPlatformSize {
    param([int]$Delta)
    if(-not $script:HcGamesLayoutEditMode -or $script:SelectedAction -lt 0 -or $script:SelectedAction -ge @($script:GameHubPlatforms).Count){return}
    $platform=[string]$script:GameHubPlatforms[$script:SelectedAction];$sizes=@('Small','Normal','Large','Extra Large');$current=Get-HcPlatformSizePreset $platform;$idx=[array]::IndexOf($sizes,$current);if($idx -lt 0){$idx=1};$next=[math]::Max(0,[math]::Min($sizes.Count-1,$idx+$Delta));if($next -eq $idx){return};Set-HcPlatformSizePreset $platform $sizes[$next];Render-Page;Update-ActionVisuals;Invoke-UiFeedback 'Navigate'
}
function Toggle-HcSelectedPlatformHidden {
    if(-not $script:HcGamesLayoutEditMode -or $script:SelectedAction -lt 0 -or $script:SelectedAction -ge @($script:GameHubPlatforms).Count){return}
    $platform=[string]$script:GameHubPlatforms[$script:SelectedAction];$list=New-Object System.Collections.ArrayList;$was=$false
    foreach($item in @(Get-EntryProperty $script:Config 'GamesHiddenPlatforms' @())){if([string]::Equals([string]$item,$platform,[StringComparison]::OrdinalIgnoreCase)){$was=$true}else{[void]$list.Add([string]$item)}}
    if(-not $was){[void]$list.Add($platform)};$script:Config.GamesHiddenPlatforms=[object[]]$list.ToArray();Save-Config;Render-Page;Update-ActionVisuals;Invoke-UiFeedback 'Confirm'
}
function Exit-HcGamesLayoutEditor {
    $script:HcGamesLayoutEditMode=$false;$script:HcGamesLayoutGrabbed=$false;$script:HcLayoutLastMask=0;$script:SelectedTab=7;$script:SubPage='CustomizationLayout';$script:SelectedAction=0;Render-Page;Update-NavVisuals
}
function Move-HomeHorizontal {param([int]$Delta);if($script:HcGamesLayoutEditMode -and $script:HcGamesLayoutGrabbed){Move-HcGamesLayoutItem $Delta;return};& $script:HcV0262BaseMoveHomeHorizontal $Delta}
function Invoke-SelectedAction {
    if($script:HcGamesLayoutEditMode -and $script:SelectedAction -ge 0 -and $script:SelectedAction -lt @($script:GameHubPlatforms).Count){$script:HcGamesLayoutGrabbed=-not $script:HcGamesLayoutGrabbed;Invoke-UiFeedback 'Confirm';Update-ActionVisuals;return}
    & $script:HcV0262BaseInvokeSelectedAction
}
function Handle-Back {
    if($script:HcGamesLayoutEditMode){if($script:HcGamesLayoutGrabbed){$script:HcGamesLayoutGrabbed=$false;Invoke-UiFeedback 'Back';Update-ActionVisuals}else{Exit-HcGamesLayoutEditor};return}
    & $script:HcV0262BaseHandleBack
}
if($null -ne $script:HcV0262BaseInvokeSecondaryAction){
    function Invoke-SecondaryAction {if($script:HcGamesLayoutEditMode){Toggle-HcSelectedPlatformHidden;return};& $script:HcV0262BaseInvokeSecondaryAction}
}
function Apply-ControllerNavigation {
    param([int]$Mask,[string]$Direction)
    if($script:HcGamesLayoutEditMode){
        $new=$Mask -band (-bnot $script:HcLayoutLastMask)
        if(($new -band 1024) -ne 0){Change-HcSelectedPlatformSize -1}
        if(($new -band 2048) -ne 0){Change-HcSelectedPlatformSize 1}
        if(($new -band 16) -ne 0){Toggle-HcSelectedPlatformHidden}
        $script:HcLayoutLastMask=$Mask
        $forward=$Mask -band (-bnot (1024 -bor 2048 -bor 16))
        & $script:HcV0262BaseApplyControllerNavigation $forward $Direction
        return
    }
    $script:HcLayoutLastMask=0;& $script:HcV0262BaseApplyControllerNavigation $Mask $Direction
}

function Get-PageDefinition {
    param([int]$Index)
    if($Index -eq 7 -and $script:SubPage -eq 'CustomizationLayout'){
        Initialize-HcV0262Config;$hidden=@(Get-EntryProperty $script:Config 'GamesHiddenPlatforms' @()).Count;$default=[string](Get-EntryProperty $script:Config 'GamesTileDefaultSize' 'Normal')
        return [pscustomobject]@{Title='Customization • Layout';Subtitle='Reorder, resize, hide, and restore console/storefront tiles with a controller.';Hero='GAMES LAYOUT';HeroText="Default tile size: $default  •  Hidden platforms: $hidden";Actions=@(
            (New-Action 'layout-edit-games' 'Edit Games layout' 'Open the Games page in controller-first layout mode.'),
            (New-Action 'layout-default-size' "Default tile size: $default" 'Cycle Small, Normal, Large, and Extra Large for platforms without an individual override.'),
            (New-Action 'layout-show-all' 'Show all platforms' 'Restore every hidden storefront and console tile.'),
            (New-Action 'layout-reset-games' 'Reset Games layout' 'Restore default order, visibility, and tile sizes.'),
            (New-Action 'layout-back-customization' 'Back to Customization'))}
    }
    $page=& $script:HcV0262BaseGetPageDefinition $Index
    if($Index -eq 7 -and $script:SubPage -eq 'Customization' -and $null -ne $page){
        $items=New-Object System.Collections.ArrayList;$inserted=$false
        foreach($a in @($page.Actions)){if(-not $inserted -and [string](Get-EntryProperty $a 'Id' '') -eq 'subpage-back'){[void]$items.Add((New-Action 'customization-layout' 'Layout' 'Reorder, hide/show, and resize Games platform tiles.'));$inserted=$true};[void]$items.Add($a)}
        if(-not $inserted){[void]$items.Add((New-Action 'customization-layout' 'Layout' 'Reorder, hide/show, and resize Games platform tiles.'))};$page.Actions=[object[]]$items.ToArray()
    }
    if($Index -eq 1 -and -not $script:SubPage -and $null -ne $page){try{$installed=@(Get-AllGameHubEntries).Count;$page.Subtitle="$installed installed title(s) across storefront and console libraries."}catch{}}
    return $page
}
function Invoke-Action {
    param([string]$Id)
    switch($Id){
        'customization-layout' {$script:SubPage='CustomizationLayout';$script:SelectedAction=0;Render-Page;return}
        'layout-edit-games' {$script:HcGamesLayoutEditMode=$true;$script:HcGamesLayoutGrabbed=$false;$script:HcLayoutLastMask=0;$script:SelectedTab=1;$script:SubPage='';$script:SelectedAction=0;Render-Page;Update-NavVisuals;return}
        'layout-default-size' {$sizes=@('Small','Normal','Large','Extra Large');$current=[string](Get-EntryProperty $script:Config 'GamesTileDefaultSize' 'Normal');$idx=[array]::IndexOf($sizes,$current);if($idx -lt 0){$idx=1};$script:Config.GamesTileDefaultSize=$sizes[($idx+1)%$sizes.Count];Save-Config;Render-Page;return}
        'layout-show-all' {$script:Config.GamesHiddenPlatforms=@();Save-Config;Render-Page;return}
        'layout-reset-games' {$script:Config.GamesPlatformOrder=@();$script:Config.GamesHiddenPlatforms=@();$script:Config.GamesPlatformSizes=@();$script:Config.GamesTileDefaultSize='Normal';Save-Config;Render-Page;return}
        'layout-back-customization' {$script:SubPage='Customization';$script:SelectedAction=0;Render-Page;return}
    }
    & $script:HcV0262BaseInvokeAction $Id
}

function Repair-HcModeChoiceTypography {param($Button);if($null -eq $Button){return};try{$Button.MinHeight=[math]::Max(170,[double]$Button.MinHeight);$grid=$Button.Content;if($grid -and $grid.Children.Count -ge 3){$title=$grid.Children[1];$sub=$grid.Children[2];$title.TextWrapping='Wrap';$title.TextTrimming='None';$title.LineHeight=30;$title.MinHeight=32;$title.Margin='0,4,0,2';$sub.LineHeight=17;$sub.MaxHeight=44}}catch{}}
if($null -ne $script:HcV0262BaseNewModeChoiceButton){function New-HcModeChoiceButton {param([string]$Id,[string]$Title,[string]$Subtitle,[string]$Mode='Store');$b=& $script:HcV0262BaseNewModeChoiceButton $Id $Title $Subtitle $Mode;Repair-HcModeChoiceTypography $b;return $b}}
function Update-ActionVisuals {
    & $script:HcV0262BaseUpdateActionVisuals
    foreach($button in @($script:ActionButtons)){try{$button.FocusVisualStyle=$null;if($button.Tag -and ([string]$button.Tag -like 'storefront-manage-*' -or [string]$button.Tag -like 'platform-*')){Repair-HcModeChoiceTypography $button}}catch{}}
    if($script:HcGamesLayoutEditMode -and $script:SelectedAction -ge 0 -and $script:SelectedAction -lt @($script:ActionButtons).Count){try{$b=$script:ActionButtons[$script:SelectedAction];$b.BorderThickness=$(if($script:HcGamesLayoutGrabbed){'4'}else{'3'});$b.BorderBrush=New-HcSolidBrush $(if($script:HcGamesLayoutGrabbed){Get-HcHighlightColor}else{Get-HcAccentColor})}catch{}}
}

# Steam is exposed through the same native game-management contract used by the
# existing provider experience. Licensed install/uninstall work remains owned by
# the Steam client; Huymaier launches the Steam protocol and observes its state.
function Get-GameProviderDefinitions {
    $items=New-Object System.Collections.ArrayList;$hasSteam=$false
    foreach($d in @(& $script:HcV0262BaseGetGameProviderDefinitions)){if([string]::Equals([string](Get-EntryProperty $d 'Id' ''),'Steam',[StringComparison]::OrdinalIgnoreCase)){$hasSteam=$true};[void]$items.Add($d)}
    if(-not $hasSteam){[void]$items.Insert(0,[pscustomobject]@{Id='Steam';Name='Steam';Backend='Steam Client';Description='Native Steam library management through the installed Steam client.';Glyph='STEAM'})}
    return [object[]]$items.ToArray()
}
function Get-HcSteamRoots {
    $roots=New-Object System.Collections.ArrayList
    foreach($key in @('HKCU:\Software\Valve\Steam','HKLM:\SOFTWARE\WOW6432Node\Valve\Steam','HKLM:\SOFTWARE\Valve\Steam')){try{$p=Get-ItemProperty $key -ErrorAction Stop;foreach($n in @('SteamPath','InstallPath')){if($p.PSObject.Properties[$n]){[void]$roots.Add([string]$p.$n);break}}}catch{}}
    $unique=New-Object System.Collections.ArrayList;$seen=@{};foreach($root in @($roots)){if(-not $root){continue};$key=$root.ToLowerInvariant();if($seen[$key]){continue};$seen[$key]=$true;[void]$unique.Add($root);$v=Join-Path $root 'steamapps\libraryfolders.vdf';if(Test-Path -LiteralPath $v){try{$t=Get-Content -Raw -LiteralPath $v;foreach($m in [regex]::Matches($t,'"path"\s+"([^"]+)"')){$r=$m.Groups[1].Value -replace '\\\\','\';$rk=$r.ToLowerInvariant();if(-not $seen[$rk]){$seen[$rk]=$true;[void]$unique.Add($r)}}}catch{}}};return [object[]]$unique.ToArray()
}
function Get-HcSteamPrimaryLibrary {foreach($root in @(Get-HcSteamRoots)){if(Test-Path -LiteralPath (Join-Path $root 'steamapps') -PathType Container){return $root}};return ''}
function Get-ProviderInstallRoot {param([string]$Provider);if([string]::Equals($Provider,'Steam',[StringComparison]::OrdinalIgnoreCase)){$root=Get-HcSteamPrimaryLibrary;if($root){return $root};return 'C:\Program Files (x86)\Steam'};return (& $script:HcV0262BaseGetProviderInstallRoot $Provider)}
if($null -ne $script:HcV0262BaseProviderSupportsMove){function Test-HcProviderSupportsMove {param([string]$Provider);if([string]::Equals($Provider,'Steam',[StringComparison]::OrdinalIgnoreCase)){return $false};return [bool](& $script:HcV0262BaseProviderSupportsMove $Provider)}}
function Start-HcSteamWorker {
    param([string]$Mode,[string]$GameId='',[string]$GameName='')
    if(-not(Test-Path -LiteralPath $script:HcSteamWorkerPath -PathType Leaf)){Set-ConsoleNotice 'The Steam provider worker is missing.' 'ERROR';return}
    if(Get-Command Test-ProviderWorkerProcessActive -ErrorAction SilentlyContinue){if(Test-ProviderWorkerProcessActive){Set-ConsoleNotice 'A provider operation is already running.' 'WARN';return}}
    $id=$GameId -replace '^(?i)Steam:',''
    if(Get-Command Write-ProviderLaunchState -ErrorAction SilentlyContinue){Write-ProviderLaunchState $true $Mode 'Steam' $id $GameName "Starting Steam $Mode..." 0}
    $args=@('-NoLogo','-NoProfile','-ExecutionPolicy','Bypass','-File',('"'+$script:HcSteamWorkerPath+'"'),'-Mode',$Mode,'-GameId',('"'+$id.Replace('"','')+'"'),'-GameName',('"'+$GameName.Replace('"','')+'"'),'-DataDir',('"'+$script:DataDir+'"'),'-StatePath',('"'+$script:ProviderStatePath+'"'),'-CatalogPath',('"'+$script:ProviderCatalogPath+'"'))
    try{$p=Start-Process "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -ArgumentList $args -WindowStyle Hidden -PassThru;$script:ProviderWorkerProcess=$p;if($Mode -ne 'Refresh'){Set-ConsoleNotice "Steam $Mode started. Steam remains authoritative for licensing and destination selection." 'INFO'}}catch{Set-ConsoleNotice "Steam $Mode could not start: $($_.Exception.Message)" 'ERROR'}
}
function Get-HcProviderMonitorPath {param([string]$Provider,[string]$GameName,[string]$InstallPath);if([string]::Equals($Provider,'GOG',[StringComparison]::OrdinalIgnoreCase) -and $GameName){$safe=$GameName -replace '[<>:"/\\|?*]','_';return (Join-Path $InstallPath $safe)};return $InstallPath}
function Start-HcProviderProgressMonitor {
    param([string]$Provider,[string]$GameName,[string]$InstallPath,[int]$WorkerPid)
    if($WorkerPid -le 0 -or -not(Test-Path -LiteralPath $script:HcProviderProgressWorkerPath -PathType Leaf)){return}
    $watch=Get-HcProviderMonitorPath $Provider $GameName $InstallPath
    $args=@('-NoLogo','-NoProfile','-ExecutionPolicy','Bypass','-File',('"'+$script:HcProviderProgressWorkerPath+'"'),'-Provider',$Provider,'-StatePath',('"'+$script:ProviderStatePath+'"'),'-WatchPath',('"'+$watch.Replace('"','')+'"'),'-WorkerPid',$WorkerPid)
    try{Start-Process "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -ArgumentList $args -WindowStyle Hidden|Out-Null}catch{}
}
function Start-GameProviderWorker {
    param([string]$Mode,[string]$Provider,[string]$GameId='',[string]$GameName='',[string]$InstallPath='',[string]$AuthCode='')
    if([string]::Equals($Provider,'Steam',[StringComparison]::OrdinalIgnoreCase)){Start-HcSteamWorker $Mode $GameId $GameName;return}
    & $script:HcV0262BaseStartGameProviderWorker $Mode $Provider $GameId $GameName $InstallPath $AuthCode
    if($Mode -in @('Install','Update') -and $Provider -in @('GOG','Amazon')){try{$p=$script:ProviderWorkerProcess;if($null -ne $p){Start-HcProviderProgressMonitor $Provider $GameName $(if($InstallPath){$InstallPath}else{Get-ProviderInstallRoot $Provider}) $p.Id}}catch{}}
}
function Request-HcSteamCatalogRefresh {
    $now=[datetime]::UtcNow;if(($now-$script:HcSteamRefreshRequestedAt).TotalSeconds -lt 30){return};$script:HcSteamRefreshRequestedAt=$now
    try{$busy=$false;if(Get-Command Read-GameProviderState -ErrorAction SilentlyContinue){$state=Read-GameProviderState;$busy=($state -and [bool](Get-EntryProperty $state 'Busy' $false))};if(-not $busy){Start-HcSteamWorker 'Refresh'}}catch{}
}
function Get-PlatformCountSummary {
    param([string]$Platform)
    if([string]::Equals($Platform,'Steam',[StringComparison]::OrdinalIgnoreCase)){
        $installed=@(Get-PlatformGames 'Steam').Count;$owned=$installed;$pending=$false
        try{$node=Get-ProviderCatalogNode 'Steam';$games=@(Get-EntryProperty $node 'Games' @());if($games.Count -gt 0){$owned=[math]::Max($installed,$games.Count)}else{$pending=$true;Request-HcSteamCatalogRefresh}}catch{$pending=$true}
        return [pscustomobject]@{Installed=$installed;Owned=$owned;Pending=$pending}
    }
    return (& $script:HcV0262BaseGetPlatformCountSummary $Platform)
}
if($null -ne $script:HcV0262BaseUpdateActiveDownloadVisuals){
    function Update-HcActiveDownloadVisuals {
        param($Active)
        $ok=[bool](& $script:HcV0262BaseUpdateActiveDownloadVisuals $Active)
        if($ok -and $null -ne $script:HcDownloadProgressBar){$progress=[int](Get-EntryProperty $Active 'Progress' -1);$script:HcDownloadProgressBar.IsIndeterminate=($progress -lt 0 -and [bool](Get-EntryProperty $Active 'Busy' $false))}
        return $ok
    }
}

Initialize-HcV0262Config
