# Huymaier Console v0.25.6 shell/provider stabilization.
# Loaded after HuymaierGameExperience.ps1 and before HuymaierEmulatorPlatforms.ps1.
# EmulatorPlatforms intentionally gets the final platform-select interception so
# emulator console cards retain their native direct-entry behavior.

$script:HcShellStorefrontIds=@('Steam','Epic','GOG','EA','Ubisoft','Xbox','BattleNet','Rockstar','Amazon')
$script:HcShellRecentGames=@()
$script:HcShellRecentApps=@()
$script:HcShellRandomPicks=@()
$script:HcWindowsApps=@()
$script:HcWindowsAppsAt=[datetime]::MinValue
$script:HcAppGameIdentityAt=[datetime]::MinValue
$script:HcAppGameNames=@{}
$script:HcAppGameTargets=@{}
$script:HcAppGameIdentitySignature=''
$script:HcChoiceOverlay=$null
$script:HcChoiceButtons=@()
$script:HcChoiceOptions=@()
$script:HcChoiceSelected=0
$script:HcChoiceSetting=''
$script:HcChoicePreviousFocus=$null
$script:HcDownloadHistoryPath=Join-Path $script:DataDir 'download-history.json'
$script:HcDownloadHistory=@()
$script:HcDownloadObserved=@{}
$script:HcConsoleUpdateWorkerPath=Join-Path $script:BaseDir 'HuymaierConsoleUpdateWorker.ps1'
$script:HcSelfUpdaterPath=Join-Path $script:BaseDir 'HuymaierSelfUpdater.ps1'
$script:HcConsoleUpdateStatePath=Join-Path $script:DataDir 'console-update-state.json'
$script:HcConsoleUpdateState=$null
$script:HcConsoleUpdateStateSignature=''

function Read-HcConsoleUpdateState {
    if(Test-Path -LiteralPath $script:HcConsoleUpdateStatePath){
        try{$script:HcConsoleUpdateState=Get-Content -LiteralPath $script:HcConsoleUpdateStatePath -Raw -Encoding UTF8|ConvertFrom-Json}catch{}
    }
    if($null -eq $script:HcConsoleUpdateState){$script:HcConsoleUpdateState=[pscustomobject]@{Phase='Ready';Message='Choose Check for Huymaier Console updates.';Busy=$false;CurrentVersion=$script:AppVersion;LatestVersion='';UpdateAvailable=$false;DownloadedBytes=0;TotalBytes=0;Percent=0;LocalPath='';Sha256='';Error=''}}
    return $script:HcConsoleUpdateState
}
function Start-HcConsoleUpdateWorker {
    param([ValidateSet('Scan','Download')][string]$Action)
    if(-not (Test-Path -LiteralPath $script:HcConsoleUpdateWorkerPath)){Set-ConsoleNotice 'The Huymaier Console update worker is missing.' 'ERROR';return}
    $state=Read-HcConsoleUpdateState;if([bool](Get-EntryProperty $state 'Busy' $false)){return}
    try{
        $worker='"'+$script:HcConsoleUpdateWorkerPath+'"';$statePath='"'+$script:HcConsoleUpdateStatePath+'"'
        $arguments="-NoLogo -NoProfile -ExecutionPolicy Bypass -File $worker -Action $Action -StatePath $statePath -CurrentVersion $($script:AppVersion) -Repository thermalkil/HuymaierConsole"
        Start-Process -FilePath "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -ArgumentList $arguments -WindowStyle Hidden|Out-Null
        Write-Log "Huymaier Console update worker requested: Action=$Action"
    }catch{Set-ConsoleNotice "Huymaier Console update worker could not start: $($_.Exception.Message)" 'ERROR'}
}
function Format-HcUpdateBytes([long]$Bytes){if($Bytes -ge 1GB){return ('{0:N2} GB' -f ($Bytes/1GB))};if($Bytes -ge 1MB){return ('{0:N1} MB' -f ($Bytes/1MB))};if($Bytes -ge 1KB){return ('{0:N0} KB' -f ($Bytes/1KB))};return "$Bytes B"}
function Start-HcConsoleSelfUpdate {
    $state=Read-HcConsoleUpdateState;$package=[string](Get-EntryProperty $state 'LocalPath' '')
    if(-not $package -or -not (Test-Path -LiteralPath $package -PathType Leaf)){Set-ConsoleNotice 'Download the Huymaier Console update before installing it.' 'WARN';return}
    if(-not (Test-Path -LiteralPath $script:HcSelfUpdaterPath)){Set-ConsoleNotice 'The Huymaier Console self-updater is missing.' 'ERROR';return}
    try{
        Write-Log "Launching self-updater for $package"
        $helper='"'+$script:HcSelfUpdaterPath+'"';$pkg='"'+$package.Replace('"','\"')+'"';$install='"'+$script:BaseDir.Replace('"','\"')+'"'
        $arguments="-NoLogo -NoProfile -ExecutionPolicy Bypass -File $helper -PackagePath $pkg -ParentProcessId $PID -InstallRoot $install"
        Start-Process -FilePath "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -ArgumentList $arguments -WindowStyle Hidden|Out-Null
        $script:AllowWindowClose=$true;$script:Window.Close()
    }catch{Set-ConsoleNotice "Self-update could not start: $($_.Exception.Message)" 'ERROR'}
}

function Get-HcStorefrontDefinitionByPlatform {
    param([string]$Platform)
    if(-not $Platform){return $null}
    foreach($definition in @(Get-StorefrontDefinitions)){
        $id=[string](Get-EntryProperty $definition 'Id' '')
        $name=[string](Get-EntryProperty $definition 'Name' '')
        $aliases=@($id,$name)
        switch($id){
            'Epic' {$aliases+=@('Epic Games')}
            'BattleNet' {$aliases+=@('Battle.net','BattleNet')}
            'Rockstar' {$aliases+=@('Rockstar Games')}
            'Amazon' {$aliases+=@('Amazon Games')}
            'EA' {$aliases+=@('EA app')}
            'Xbox' {$aliases+=@('Microsoft Gaming App','Xbox App')}
        }
        foreach($alias in $aliases){if($alias -and [string]::Equals([string]$alias,$Platform,[StringComparison]::OrdinalIgnoreCase)){return $definition}}
    }
    return $null
}
function Get-HcStorefrontIdByPlatform {param([string]$Platform);$d=Get-HcStorefrontDefinitionByPlatform $Platform;if($null -eq $d){return ''};return [string](Get-EntryProperty $d 'Id' '')}
function Test-HcStorefrontPlatform {param([string]$Platform);return ($null -ne (Get-HcStorefrontDefinitionByPlatform $Platform))}
function Get-HcStorefrontDisplayPlatform {param($Definition);$id=[string](Get-EntryProperty $Definition 'Id' '');switch($id){'Epic'{'Epic';break}'BattleNet'{'Battle.net';break}'Rockstar'{'Rockstar';break}'Amazon'{'Amazon';break}'EA'{'EA';break}'Xbox'{'Xbox';break}default{$id}}}

# Always expose implemented PC storefronts on Games, even when not installed.
$script:Hc250BaseGetGameHubPlatforms=${function:Get-GameHubPlatforms}
function Get-GameHubPlatforms {
    $result=New-Object System.Collections.ArrayList;$seen=@{}
    foreach($definition in @(Get-StorefrontDefinitions)){
        $name=Get-HcStorefrontDisplayPlatform $definition
        if(-not $name){continue};$key=$name.ToLowerInvariant();if(-not $seen.ContainsKey($key)){[void]$result.Add($name);$seen[$key]=$true}
    }
    foreach($platform in @(& $script:Hc250BaseGetGameHubPlatforms)){
        $name=[string]$platform
        if(-not $name -or $name -in @('Custom','Generic','HES')){continue}
        if(Test-HcStorefrontPlatform $name){continue}
        $key=$name.ToLowerInvariant();if(-not $seen.ContainsKey($key)){[void]$result.Add($name);$seen[$key]=$true}
    }
    return [object[]]$result.ToArray()
}

# Honor a user-selected existing storefront installation folder.
$script:Hc250BaseGetStorefrontStatus=${function:Get-StorefrontStatus}
function Get-StorefrontStatus {
    param($Definition,[object[]]$UninstallRecords)
    $status=& $script:Hc250BaseGetStorefrontStatus $Definition $UninstallRecords
    if([bool](Get-EntryProperty $status 'Installed' $false)){return $status}
    $id=[string](Get-EntryProperty $Definition 'Id' '')
    foreach($override in @($script:Config.StorefrontInstallOverrides)){
        if($null -eq $override -or -not [string]::Equals([string](Get-EntryProperty $override 'Store' ''),$id,[StringComparison]::OrdinalIgnoreCase)){continue}
        $root=[string](Get-EntryProperty $override 'Path' '')
        if(-not $root -or -not (Test-Path -LiteralPath $root)){continue}
        $launcher=''
        if(Test-Path -LiteralPath $root -PathType Leaf){$launcher=$root}
        else{
            $exeNames=switch($id){
                'Steam' {@('steam.exe')}
                'Epic' {@('EpicGamesLauncher.exe')}
                'GOG' {@('GalaxyClient.exe')}
                'EA' {@('EADesktop.exe')}
                'Ubisoft' {@('UbisoftConnect.exe','upc.exe')}
                'BattleNet' {@('Battle.net Launcher.exe','Battle.net.exe')}
                'Rockstar' {@('Launcher.exe')}
                'Amazon' {@('Amazon Games.exe')}
                default {@()}
            }
            foreach($exe in $exeNames){
                try{$match=Get-ChildItem -LiteralPath $root -Filter $exe -File -Recurse -ErrorAction SilentlyContinue|Select-Object -First 1;if($null -ne $match){$launcher=$match.FullName;break}}catch{}
            }
            if(-not $launcher -and $id -eq 'Xbox'){$launcher=$root}
        }
        return [pscustomobject]@{Installed=$true;Path=$launcher;UninstallString='';Version='';Status='Installed (located by user)'}
    }
    return $status
}

# Normal Steam opening is restored; Big Picture remains a separate Manage option.
$script:Hc250BaseOpenStorefront=${function:Open-Storefront}
function Open-Storefront {
    param([string]$StoreId)
    if(-not [string]::Equals($StoreId,'Steam',[StringComparison]::OrdinalIgnoreCase)){& $script:Hc250BaseOpenStorefront $StoreId;return}
    $item=Get-StorefrontCatalogItem 'Steam'
    if($null -eq $item -or -not [bool](Get-EntryProperty $item 'Installed' $false)){Set-ConsoleNotice 'Steam is not installed.' 'WARN';return}
    $path=[string](Get-EntryProperty $item 'Path' '')
    try{
        if($path -and (Test-Path -LiteralPath $path -PathType Leaf)){Start-ExternalProcess $path @();Add-ToRecent 'App' ([pscustomobject]@{Name='Steam';Path=$path;LaunchTarget=$path;Arguments=@();Source='Storefront';ArtworkPath=''});return}
        Start-UriOrShellTarget 'steam://open/main'
    }catch{Set-ConsoleNotice "Steam could not be opened: $($_.Exception.Message)" 'ERROR'}
}

function Get-HcMainMenuEntries {
    return @(
        [pscustomobject]@{Title='Home';Icon='⌂';Tab=0;Mode='Tab'},
        [pscustomobject]@{Title='Games';Icon='▦';Tab=1;Mode='Tab'},
        [pscustomobject]@{Title='Apps';Icon='◈';Tab=2;Mode='Tab'},
        [pscustomobject]@{Title='Downloads';Icon='↓';Tab=4;Mode='Tab'},
        [pscustomobject]@{Title='Settings';Icon='⚙';Tab=7;Mode='Tab'},
        [pscustomobject]@{Title='Power';Icon='⏻';Tab=8;Mode='Tab'}
    )
}
function New-HcMainMenuButton {
    param($Entry,[int]$Index)
    $button=New-Object System.Windows.Controls.Button
    $button.Tag=$Index;$button.Width=122;$button.Height=92;$button.Margin='5';$button.Padding='7';$button.Background='#E90A0E15';$button.BorderBrush='#384355';$button.BorderThickness='1';$button.Cursor='Hand';$button.RenderTransformOrigin='0.5,0.5'
    $button.Template=[Windows.Markup.XamlReader]::Parse('<ControlTemplate xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" TargetType="Button"><Border Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="15" Padding="{TemplateBinding Padding}"><ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/></Border></ControlTemplate>')
    $stack=New-Object System.Windows.Controls.StackPanel;$stack.HorizontalAlignment='Center';$stack.VerticalAlignment='Center'
    $icon=New-Object System.Windows.Controls.TextBlock;$icon.Text=[string]$Entry.Icon;$icon.FontSize=29;$icon.FontWeight='Bold';$icon.HorizontalAlignment='Center';$icon.Foreground='White';$stack.Children.Add($icon)|Out-Null
    $title=New-Object System.Windows.Controls.TextBlock;$title.Text=[string]$Entry.Title;$title.FontSize=12;$title.FontWeight='SemiBold';$title.HorizontalAlignment='Center';$title.Margin='0,7,0,0';$title.Foreground='#E6EDF6';$stack.Children.Add($title)|Out-Null
    $button.Content=$stack
    $button.Add_Click({param($sender,$eventArgs)$script:HcMainMenuSelected=[int]$sender.Tag;Update-HcMainMenuVisuals;Invoke-HcMainMenuSelected})
    $button.Add_MouseEnter({param($sender,$eventArgs)if(-not(Test-HcMouseHoverAllowed)){return};Set-KeyboardActive;$script:HcMainMenuSelected=[int]$sender.Tag;Update-HcMainMenuVisuals})
    return $button
}
function Update-HcMainMenuVisuals {
    for($i=0;$i -lt @($script:HcMainMenuButtons).Count;$i++){
        $button=$script:HcMainMenuButtons[$i]
        if($i -eq $script:HcMainMenuSelected){$button.Background='#E4CE64';$button.BorderBrush='#FFF0A0';$button.BorderThickness='2';try{$button.Content.Children[0].Foreground='#111722';$button.Content.Children[1].Foreground='#111722'}catch{}}
        else{$button.Background='#E90A0E15';$button.BorderBrush='#384355';$button.BorderThickness='1';try{$button.Content.Children[0].Foreground='White';$button.Content.Children[1].Foreground='#E6EDF6'}catch{}}
    }
    try{$script:HcMainMenuButtons[$script:HcMainMenuSelected].BringIntoView()}catch{}
}
function Apply-HcQuickMenuLayout {
    if($null -eq $script:MainMenuFrame -or $null -eq $script:MainMenuPanel){return}
    $position=[string](Get-EntryProperty $script:Config 'QuickMenuPosition' 'Bottom')
    if($position -notin @('Bottom','Top','Left','Right')){$position='Bottom'}
    $vertical=$position -in @('Left','Right')
    $script:MainMenuPanel.Orientation=$(if($vertical){'Vertical'}else{'Horizontal'})
    $script:MainMenuPanel.HorizontalAlignment=$(if($vertical){'Stretch'}else{'Center'})
    $script:MainMenuPanel.VerticalAlignment=$(if($vertical){'Center'}else{'Stretch'})
    $script:MainMenuFrame.HorizontalAlignment=$(if($position -eq 'Left'){'Left'}elseif($position -eq 'Right'){'Right'}else{'Stretch'})
    $script:MainMenuFrame.VerticalAlignment=$(if($position -eq 'Top'){'Top'}elseif($position -eq 'Bottom'){'Bottom'}else{'Stretch'})
    if($vertical){$script:MainMenuFrame.Width=154;$script:MainMenuFrame.Height=[double]::NaN;$script:MainMenuFrame.Margin='24,26,24,26';$script:MainMenuScroll.HorizontalScrollBarVisibility='Disabled';$script:MainMenuScroll.VerticalScrollBarVisibility='Hidden';$script:MainMenuScroll.PanningMode='VerticalOnly'}
    else{$script:MainMenuFrame.Width=[double]::NaN;$script:MainMenuFrame.Height=128;$script:MainMenuFrame.Margin='26,22,26,22';$script:MainMenuScroll.HorizontalScrollBarVisibility='Hidden';$script:MainMenuScroll.VerticalScrollBarVisibility='Disabled';$script:MainMenuScroll.PanningMode='HorizontalOnly'}
}
function Show-HcMainMenu {
    if($null -eq $script:MainMenuOverlay){Focus-TopNavigation;return};if(Test-HcMainMenuVisible){Close-HcMainMenu;return};if(Test-HcGameModalVisible){Close-HcGameModal}
    $script:HcMainMenuEntries=@(Get-HcMainMenuEntries);$script:HcMainMenuButtons=@();$script:HcMainMenuSelected=0
    for($i=0;$i -lt $script:HcMainMenuEntries.Count;$i++){if([int]$script:HcMainMenuEntries[$i].Tab -eq [int]$script:SelectedTab){$script:HcMainMenuSelected=$i;break}}
    Apply-HcQuickMenuLayout;$script:MainMenuPanel.Children.Clear()
    for($i=0;$i -lt $script:HcMainMenuEntries.Count;$i++){$b=New-HcMainMenuButton $script:HcMainMenuEntries[$i] $i;$script:MainMenuPanel.Children.Add($b)|Out-Null;$script:HcMainMenuButtons+=$b}
    $script:NavigationLayer='Content';$script:MainMenuOverlay.Visibility='Visible';Set-HcShellBlur $true;Update-HcMainMenuVisuals;Update-Footer
}
function Handle-HcMainMenuController {
    param([int]$Mask,[string]$Direction)
    if(-not (Test-HcMainMenuVisible)){return $false};$pos=[string](Get-EntryProperty $script:Config 'QuickMenuPosition' 'Bottom');$vertical=$pos -in @('Left','Right');$now=Get-Date
    if($Direction){if($Direction -ne $script:LastDirection -or $now -ge $script:NextDirectionAt){if(($vertical -and $Direction -eq 'Up') -or (-not $vertical -and $Direction -eq 'Left')){Move-HcMainMenuSelection -1}elseif(($vertical -and $Direction -eq 'Down') -or (-not $vertical -and $Direction -eq 'Right')){Move-HcMainMenuSelection 1};$isNew=($Direction -ne $script:LastDirection);$script:LastDirection=$Direction;$script:NextDirectionAt=$now.AddMilliseconds($(if($isNew){340}else{120}))}}else{$script:LastDirection='';$script:NextDirectionAt=[datetime]::MinValue}
    if(Is-NewButtonPress $Mask 4){Invoke-HcMainMenuSelected};if((Is-NewButtonPress $Mask 8) -or (Is-NewButtonPress $Mask 2)){Invoke-UiFeedback 'Back';Close-HcMainMenu};$script:LastGamepadMask=$Mask;return $true
}
function Handle-HcMainMenuKey {
    param($Key);if(-not (Test-HcMainMenuVisible)){return $false};$pos=[string](Get-EntryProperty $script:Config 'QuickMenuPosition' 'Bottom');$vertical=$pos -in @('Left','Right')
    switch([string]$Key){'Left'{if(-not $vertical){Move-HcMainMenuSelection -1}else{return $false}}'Right'{if(-not $vertical){Move-HcMainMenuSelection 1}else{return $false}}'Up'{if($vertical){Move-HcMainMenuSelection -1}else{return $false}}'Down'{if($vertical){Move-HcMainMenuSelection 1}else{return $false}}'Enter'{Invoke-HcMainMenuSelected}'Space'{Invoke-HcMainMenuSelected}'Escape'{Close-HcMainMenu}'F1'{Close-HcMainMenu}default{return $false}};return $true
}

# Games root: provider/console list only. No Continue Playing / Across Your Libraries.
function Add-PlatformRail {
    $heading=New-Object System.Windows.Controls.TextBlock;$heading.Text='Games';$heading.FontSize=29;$heading.FontWeight='Bold';$heading.Foreground='#F5F7FB';$heading.Margin='0,0,0,4';$script:ActionPanel.Children.Add($heading)|Out-Null
    $sub=New-Object System.Windows.Controls.TextBlock;$sub.Text='Storefronts and console platforms';$sub.FontSize=13;$sub.Foreground='#91A3BA';$sub.Margin='0,0,0,18';$script:ActionPanel.Children.Add($sub)|Out-Null
    $start=$script:ActionButtons.Count;$wrap=New-Object System.Windows.Controls.WrapPanel;$wrap.Orientation='Horizontal';$wrap.Margin='2,0,0,20'
    for($i=0;$i -lt $script:GameHubPlatforms.Count;$i++){$platform=[string]$script:GameHubPlatforms[$i];$button=New-PlatformCard $platform $i;if(Test-HcStorefrontPlatform $platform){$id=Get-HcStorefrontIdByPlatform $platform;$item=Get-StorefrontCatalogItem $id;if($null -eq $item -or -not [bool](Get-EntryProperty $item 'Installed' $false)){$button.Opacity=.38;$button.ToolTip='Not installed'}};$wrap.Children.Add($button)|Out-Null;$script:ActionButtons+=$button;$script:CurrentActions+=(New-Action "platform-select:$i" $platform)}
    $scroll=New-Object System.Windows.Controls.ScrollViewer;$scroll.VerticalScrollBarVisibility='Hidden';$scroll.HorizontalScrollBarVisibility='Disabled';$scroll.Content=$wrap;$script:ActionPanel.Children.Add($scroll)|Out-Null
    $columns=8;try{$w=[double]$script:ActionScrollViewer.ActualWidth;if($w -gt 500){$columns=[math]::Max(4,[math]::Floor($w/170))}}catch{}
    for($r=0;$r -lt $script:GameHubPlatforms.Count;$r+=$columns){$script:HomeRows+=,[pscustomobject]@{Start=$start+$r;Count=[math]::Min($columns,$script:GameHubPlatforms.Count-$r);Platform=$true}}
}

$script:Hc250BaseAddPlatformChoiceRail=${function:Add-PlatformChoiceRail}
function New-HcModeChoiceButton {param([string]$Id,[string]$Title,[string]$Subtitle,[string]$Mode='Store')
    $button=New-Object System.Windows.Controls.Button;$button.Tag=$Id;$button.Width=244;$button.Height=170;$button.Margin='0,0,18,12';$button.Padding='0';$button.Background='#8D101927';$button.BorderBrush='#33445E';$button.BorderThickness='1';$button.RenderTransformOrigin='0.5,0.5';$button.Cursor='Hand'
    $button.Template=[Windows.Markup.XamlReader]::Parse('<ControlTemplate xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" TargetType="Button"><Border Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="17" ClipToBounds="True"><ContentPresenter/></Border></ControlTemplate>')
    $grid=New-Object System.Windows.Controls.Grid;$grid.Margin='18,15,18,14';$grid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition -Property @{Height='56'}));$grid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition -Property @{Height='Auto'}));$grid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition -Property @{Height='*'}))
    $img=New-Object System.Windows.Controls.Image;$img.Width=46;$img.Height=46;$img.HorizontalAlignment='Left';$img.Source=Get-ImageSourceFromPath (Get-ModeIconPath $Mode);[System.Windows.Controls.Grid]::SetRow($img,0);$grid.Children.Add($img)|Out-Null
    $tb=New-Object System.Windows.Controls.TextBlock;$tb.Text=$Title;$tb.FontSize=22;$tb.FontWeight='Bold';$tb.Foreground='White';$tb.Margin='0,7,0,0';[System.Windows.Controls.Grid]::SetRow($tb,1);$grid.Children.Add($tb)|Out-Null
    $st=New-Object System.Windows.Controls.TextBlock;$st.Text=$Subtitle;$st.FontSize=12;$st.Foreground='#AEBBD0';$st.TextWrapping='Wrap';$st.LineHeight=17;$st.MaxHeight=38;$st.Margin='0,5,0,0';[System.Windows.Controls.Grid]::SetRow($st,2);$grid.Children.Add($st)|Out-Null;$button.Content=$grid
    $button.Add_Click({param($sender,$e)Invoke-UiFeedback 'Confirm';Invoke-Action ([string]$sender.Tag)});$button.Add_MouseEnter({param($sender,$e)if(-not(Test-HcMouseHoverAllowed)){return};Set-KeyboardActive;$idx=[array]::IndexOf($script:ActionButtons,$sender);if($idx -ge 0){$script:SelectedAction=$idx;Update-ActionVisuals}});return $button
}
function Add-PlatformChoiceRail {
    if(-not (Test-HcStorefrontPlatform $script:SelectedGamePlatform)){return (& $script:Hc250BaseAddPlatformChoiceRail)}
    $definition=Get-HcStorefrontDefinitionByPlatform $script:SelectedGamePlatform;$id=[string](Get-EntryProperty $definition 'Id' '');$item=Get-StorefrontCatalogItem $id;$installed=($null -ne $item -and [bool](Get-EntryProperty $item 'Installed' $false))
    $header=New-Object System.Windows.Controls.StackPanel;$header.Orientation='Horizontal';$header.Margin='0,0,0,20';$icon=New-PlatformIconImage $script:SelectedGamePlatform 55;$header.Children.Add($icon)|Out-Null;$text=New-Object System.Windows.Controls.StackPanel;$text.Margin='15,0,0,0';$title=New-Object System.Windows.Controls.TextBlock;$title.Text=$script:SelectedGamePlatform;$title.FontSize=30;$title.FontWeight='Bold';$title.Foreground='White';$text.Children.Add($title)|Out-Null;$state=New-Object System.Windows.Controls.TextBlock;$state.Text=$(if($installed){'Installed storefront'}else{'Not installed'});$state.FontSize=13;$state.Foreground=$(if($installed){'#A8D8B3'}else{'#CDA7A7'});$text.Children.Add($state)|Out-Null;$header.Children.Add($text)|Out-Null;$script:ActionPanel.Children.Add($header)|Out-Null
    $choices=if($installed){@(@('platform-shelf','Shelf','Installed games with cover art.','Shelf'),@('platform-library','Library','Entire available library; install or manage individual titles.','Library'),@('platform-storefront-manage','Manage','Open, account, refresh, locations, install state and storefront options.','Store'))}else{@(@('storefront-install-selected','Install','Install from the official publisher source.','Store'),@('storefront-find-selected','Find Installation','Point Huymaier Console to an existing installation folder.','Store'))}
    $start=$script:ActionButtons.Count;$row=New-Object System.Windows.Controls.StackPanel;$row.Orientation='Horizontal'
    foreach($c in $choices){$b=New-HcModeChoiceButton $c[0] $c[1] $c[2] $c[3];$row.Children.Add($b)|Out-Null;$script:ActionButtons+=$b;$script:CurrentActions+=(New-Action $c[0] $c[1] $c[2])};$script:ActionPanel.Children.Add($row)|Out-Null;$script:HomeRows+=,[pscustomobject]@{Start=$start;Count=$choices.Count;Platform=$false}
}

function Render-HcStorefrontManage {
    $definition=Get-HcStorefrontDefinitionByPlatform $script:SelectedGamePlatform;if($null -eq $definition){$script:SubPage='PlatformChoice';Add-PlatformChoiceRail;return};$id=[string](Get-EntryProperty $definition 'Id' '');$item=Get-StorefrontCatalogItem $id
    $heading=New-Object System.Windows.Controls.TextBlock;$heading.Text="$($script:SelectedGamePlatform) Manage";$heading.FontSize=30;$heading.FontWeight='Bold';$heading.Foreground='White';$heading.Margin='0,0,0,6';$script:ActionPanel.Children.Add($heading)|Out-Null
    $path=[string](Get-EntryProperty $item 'Path' '');$sub=New-Object System.Windows.Controls.TextBlock;$sub.Text=$(if($path){$path}else{'Manage the storefront without leaving the Games hub.'});$sub.FontSize=13;$sub.Foreground='#9DAFC5';$sub.TextWrapping='Wrap';$sub.Margin='0,0,0,18';$script:ActionPanel.Children.Add($sub)|Out-Null
    $defs=New-Object System.Collections.ArrayList;[void]$defs.Add(@("storefront-manage-open:$id","Open $($script:SelectedGamePlatform)",'Launch the storefront normally.'))
    if($id -eq 'Steam'){[void]$defs.Add(@('platform-steam-bigpicture','Steam Big Picture','Open Steam Gamepad UI while Huymaier Console stays running in the background.'))}
    if((Get-Command Test-DirectProviderPlatform -ErrorAction SilentlyContinue) -and (Test-DirectProviderPlatform $script:SelectedGamePlatform)){[void]$defs.Add(@("storefront-manage-account:$id",'Account & Library Integration','Sign in, pair, or manage the existing provider integration.'))}
    [void]$defs.Add(@("storefront-manage-refresh:$id",'Refresh Library & Artwork','Refresh installed/uninstalled titles, counts and missing cover art.'))
    [void]$defs.Add(@("storefront-manage-location:$id",'Library Locations / Import','Add an existing game-library folder for this storefront.'))
    [void]$defs.Add(@("storefront-manage-find:$id",'Find Storefront Installation','Change the launcher installation folder used by Huymaier Console.'))
    [void]$defs.Add(@("storefront-manage-uninstall:$id","Uninstall $($script:SelectedGamePlatform)",'Use the registered Windows/package uninstall method.'))
    $start=$script:ActionButtons.Count;foreach($d in @($defs)){$b=New-HcModeChoiceButton $d[0] $d[1] $d[2] 'Store';$b.Width=360;$b.Height=142;$script:ActionPanel.Children.Add($b)|Out-Null;$script:ActionButtons+=$b;$script:CurrentActions+=(New-Action $d[0] $d[1] $d[2]);$script:HomeRows+=,[pscustomobject]@{Start=$script:ActionButtons.Count-1;Count=1;Platform=$false}}
}

$script:Hc250BaseRenderGamesHub=${function:Render-GamesHub}
function Render-GamesHub {
    $script:GameHubPlatforms=Get-GameHubPlatforms;if($script:GameHubPlatforms.Count -eq 0){$script:GameHubPlatforms=@('Steam')};$script:GameHubLaunchEntries=@()
    if($script:SubPage -eq 'StorefrontManage'){Render-HcStorefrontManage;return}
    & $script:Hc250BaseRenderGamesHub
}

# Windows installed application discovery for Apps. Games and storefronts are excluded.
function Convert-HcAppIdentityText {param([string]$Value);if(-not $Value){return ''};return ([regex]::Replace($Value.ToLowerInvariant(),'[^a-z0-9]+','')).Trim()}
function Refresh-HcAppGameIdentity {
    $signature=''
    try{$signature=(@($script:Config.ImportedGames).Count.ToString()+'|'+@($script:Config.RecentGames).Count.ToString()+'|'+$(if(Test-Path -LiteralPath $script:LibraryResultPath){(Get-Item -LiteralPath $script:LibraryResultPath).LastWriteTimeUtc.Ticks}else{0}))}catch{$signature=(Get-Date).Ticks.ToString()}
    if($script:HcAppGameNames.Count -gt 0 -and $signature -eq $script:HcAppGameIdentitySignature -and ((Get-Date)-$script:HcAppGameIdentityAt).TotalSeconds -lt 90){return}
    $names=@{};$targets=@{}
    $addGame={param($game)
        if($null -eq $game){return}
        $name=Convert-HcAppIdentityText ([string](Get-EntryProperty $game 'Name' ''));if($name){$names[$name]=$true}
        foreach($target in @([string](Get-EntryProperty $game 'LaunchTarget' ''),[string](Get-EntryProperty $game 'Path' ''),[string](Get-EntryProperty $game 'InstallPath' ''))){if($target){$targets[$target.ToLowerInvariant()]=$true}}
    }
    # ImportedGames is the authoritative installed-library scan and is cheap to
    # inspect. Include recents as a defensive alias source for provider titles.
    foreach($game in @($script:Config.ImportedGames)){& $addGame $game}
    foreach($game in @($script:Config.RecentGames)){& $addGame $game}
    try{$mapResult=Get-HcInstalledGameMap;foreach($game in @($mapResult.Entries)){& $addGame $game}}catch{}
    $script:HcAppGameNames=$names;$script:HcAppGameTargets=$targets;$script:HcAppGameIdentityAt=Get-Date;$script:HcAppGameIdentitySignature=$signature
}

function Test-HcAppIsRecognizedGame {param($Entry)
    if($null -eq $Entry){return $false};Refresh-HcAppGameIdentity
    $name=Convert-HcAppIdentityText ([string](Get-EntryProperty $Entry 'Name' ''));if($name -and $script:HcAppGameNames.ContainsKey($name)){return $true}
    $aumid=[string](Get-EntryProperty $Entry 'AppUserModelId' '')
    # Classic Steam shortcuts registered in Start expose Steam.App.<appid>.
    if($aumid -match '(?i)^Steam\.App\.\d+$|steam://rungameid/|com\.epicgames\.launcher://apps/|goggalaxy://openGameView/'){return $true}
    foreach($target in @([string](Get-EntryProperty $Entry 'LaunchTarget' ''),[string](Get-EntryProperty $Entry 'Path' ''))){
        if(-not $target){continue}
        $lower=$target.ToLowerInvariant();if($script:HcAppGameTargets.ContainsKey($lower)){return $true}
        if($lower -match '^(steam://rungameid/|com\.epicgames\.launcher://apps/|goggalaxy://openGameView/|xbox-games:|gamingservices:)'){return $true}
    }
    return $false
}

function Get-HcWindowsApps {
    Refresh-HcAppGameIdentity
    if($script:HcWindowsApps.Count -gt 0 -and ((Get-Date)-$script:HcWindowsAppsAt).TotalMinutes -lt 5){$script:HcWindowsApps=@($script:HcWindowsApps|Where-Object{-not (Test-HcAppIsRecognizedGame $_)});return [object[]]$script:HcWindowsApps}
    $items=New-Object System.Collections.ArrayList
    try{
        foreach($app in @(Get-StartApps -ErrorAction SilentlyContinue|Sort-Object Name)){
            $name=[string](Get-EntryProperty $app 'Name' '');$id=[string](Get-EntryProperty $app 'AppID' '')
            if(-not $name -or -not $id){continue}
            if($name -match '(?i)^(Steam|Epic Games|GOG GALAXY|EA app|Ubisoft Connect|Xbox|Battle\.net|Rockstar Games Launcher|Amazon Games)$'){continue}
            $entry=[pscustomobject]@{Name=$name;AppUserModelId=$id;LaunchTarget=('shell:AppsFolder\'+$id);Source='Windows App';ArtworkPath='';Installed=$true}
            if(Test-HcAppIsRecognizedGame $entry){continue}
            [void]$items.Add($entry)
        }
    }catch{}
    $script:HcWindowsApps=[object[]]$items.ToArray();$script:HcWindowsAppsAt=Get-Date;return [object[]]$script:HcWindowsApps
}
function Start-HcWindowsApp {param($Entry);$id=[string](Get-EntryProperty $Entry 'AppUserModelId' '');if(-not $id){return};try{Start-Process explorer.exe -ArgumentList ('shell:AppsFolder\'+$id)|Out-Null;Send-ConsoleToBackground}catch{Set-ConsoleNotice "App could not be opened: $($_.Exception.Message)" 'ERROR'}}
function Test-HcRecentAppAvailable {param($Entry);$aumid=[string](Get-EntryProperty $Entry 'AppUserModelId' '');if($aumid){return (@(Get-HcWindowsApps|Where-Object{[string]::Equals([string](Get-EntryProperty $_ 'AppUserModelId' ''),$aumid,[StringComparison]::OrdinalIgnoreCase)}).Count -gt 0)};$target=[string](Get-EntryProperty $Entry 'LaunchTarget' (Get-EntryProperty $Entry 'Path' ''));if(-not $target){return $false};if($target -match '^[a-zA-Z][a-zA-Z0-9+.-]*:'){return $true};return (Test-Path -LiteralPath $target)}
function Test-HcGameEntryAvailable {
    param($Game)
    if($null -eq $Game){return $false}
    if(-not [bool](Get-EntryProperty $Game 'Installed' $true)){return $false}
    $target=[string](Get-EntryProperty $Game 'LaunchTarget' (Get-EntryProperty $Game 'Path' ''))
    $installPath=[string](Get-EntryProperty $Game 'InstallPath' '')
    # Storefront protocol launches (steam://, goggalaxy://, shell:, etc.) are
    # valid when the provider marks the title installed. Filesystem-backed
    # titles must still exist, which automatically prunes removed ROMs/games.
    if($target -and $target -match '^[a-zA-Z][a-zA-Z0-9+.-]*:'){return $true}
    if($target){return (Test-Path -LiteralPath $target)}
    if($installPath){return (Test-Path -LiteralPath $installPath)}
    return $true
}
function Get-HcInstalledGameMap {
    $map=@{};$all=New-Object System.Collections.ArrayList
    foreach($platform in @(Get-GameHubPlatforms)){
        try{foreach($game in @(Get-PlatformGames ([string]$platform))){if(-not (Test-HcGameEntryAvailable $game)){continue};[void]$all.Add($game);$provider=[string](Get-EntryProperty $game 'Provider' (Get-EntryProperty $game 'Source' ''));$id=[string](Get-EntryProperty $game 'ProviderGameId' (Get-EntryProperty $game 'Id' ''));$target=[string](Get-EntryProperty $game 'LaunchTarget' (Get-EntryProperty $game 'Path' ''));$name=[string](Get-EntryProperty $game 'Name' '');foreach($key in @($(if($provider -and $id){"p|$($provider.ToLowerInvariant())|$($id.ToLowerInvariant())"}),$(if($target){'t|'+$target.ToLowerInvariant()}),$(if($name){'n|'+$name.ToLowerInvariant()}))){if($key){$map[$key]=$game}}}}catch{}
    }
    return [pscustomobject]@{Map=$map;Entries=[object[]]$all.ToArray()}
}
function Resolve-HcRecentGame {param($Recent,$InstalledMap);$provider=[string](Get-EntryProperty $Recent 'Provider' (Get-EntryProperty $Recent 'Source' ''));$id=[string](Get-EntryProperty $Recent 'ProviderGameId' (Get-EntryProperty $Recent 'Id' ''));$target=[string](Get-EntryProperty $Recent 'LaunchTarget' (Get-EntryProperty $Recent 'Path' ''));$name=[string](Get-EntryProperty $Recent 'Name' '');foreach($key in @($(if($provider -and $id){"p|$($provider.ToLowerInvariant())|$($id.ToLowerInvariant())"}),$(if($target){'t|'+$target.ToLowerInvariant()}),$(if($name){'n|'+$name.ToLowerInvariant()}))){if($key -and $InstalledMap.ContainsKey($key)){return $InstalledMap[$key]}};if($target -and (Test-Path -LiteralPath $target)){return $Recent};return $null}

function Add-HcHomeActionBar {
    $defs=@(@('Games','▦'),@('Apps','◈'),@('Downloads','↓'),@('Settings','⚙'),@('Power','⏻'))
    $heading=New-Object System.Windows.Controls.TextBlock;$heading.Text='Home';$heading.FontSize=30;$heading.FontWeight='Bold';$heading.Foreground='White';$heading.Margin='0,0,0,12';$script:ActionPanel.Children.Add($heading)|Out-Null
    $start=$script:ActionButtons.Count;$row=New-Object System.Windows.Controls.StackPanel;$row.Orientation='Horizontal';$row.Margin='0,0,0,18'
    for($i=0;$i -lt $defs.Count;$i++){
        $button=New-Object System.Windows.Controls.Button;$button.Tag="home-action:$i";$button.Width=194;$button.Height=86;$button.Margin='0,0,14,0';$button.Padding='14,8';$button.Background='#9A101927';$button.BorderBrush='#34465F';$button.BorderThickness='1';$button.Cursor='Hand';$button.RenderTransformOrigin='0.5,0.5';$button.Template=[Windows.Markup.XamlReader]::Parse('<ControlTemplate xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" TargetType="Button"><Border Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="14" Padding="{TemplateBinding Padding}"><ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/></Border></ControlTemplate>')
        $panel=New-Object System.Windows.Controls.StackPanel;$panel.Orientation='Horizontal';$panel.VerticalAlignment='Center';$glyph=New-Object System.Windows.Controls.TextBlock;$glyph.Text=$defs[$i][1];$glyph.FontSize=27;$glyph.FontWeight='Bold';$glyph.Foreground='#E7C45E';$glyph.VerticalAlignment='Center';$panel.Children.Add($glyph)|Out-Null;$label=New-Object System.Windows.Controls.TextBlock;$label.Text=$defs[$i][0];$label.FontSize=17;$label.FontWeight='SemiBold';$label.Foreground='White';$label.Margin='11,0,0,0';$label.VerticalAlignment='Center';$panel.Children.Add($label)|Out-Null;$button.Content=$panel
        $button.Add_Click({param($sender,$e)Invoke-UiFeedback 'Confirm';Invoke-Action ([string]$sender.Tag)});$button.Add_MouseEnter({param($sender,$e)if(-not(Test-HcMouseHoverAllowed)){return};Set-KeyboardActive;$idx=[array]::IndexOf($script:ActionButtons,$sender);if($idx -ge 0){$script:SelectedAction=$idx;Update-ActionVisuals}});$row.Children.Add($button)|Out-Null;$script:ActionButtons+=$button;$script:CurrentActions+=(New-Action "home-action:$i" $defs[$i][0])
    }
    $script:ActionPanel.Children.Add($row)|Out-Null;$script:HomeRows+=,[pscustomobject]@{Start=$start;Count=$defs.Count;Platform=$false}
}

function New-HcUtilityCard {param([string]$Id,[string]$Title,[string]$Glyph,[string]$Subtitle='')
    $entry=[pscustomobject]@{Name=$Title;Source='App';Installed=$true;ArtworkPath=''};$button=New-HomeCard $entry $Id 'Apps';try{$grid=$button.Content;$badge=New-Object System.Windows.Controls.TextBlock;$badge.Text=$Glyph;$badge.FontSize=56;$badge.FontWeight='Bold';$badge.Foreground='#E7C45E';$badge.HorizontalAlignment='Center';$badge.VerticalAlignment='Center';$badge.Margin='0,0,0,36';$grid.Children.Add($badge)|Out-Null}catch{};return $button
}
function Render-HcAppsRoot {
    $heading=New-Object System.Windows.Controls.TextBlock;$heading.Text='Apps';$heading.FontSize=30;$heading.FontWeight='Bold';$heading.Foreground='White';$heading.Margin='0,0,0,4';$script:ActionPanel.Children.Add($heading)|Out-Null;$sub=New-Object System.Windows.Controls.TextBlock;$sub.Text='Windows applications and Huymaier utilities';$sub.FontSize=13;$sub.Foreground='#91A3BA';$sub.Margin='0,0,0,18';$script:ActionPanel.Children.Add($sub)|Out-Null
    $script:HcAppsDisplay=@();$wrap=New-Object System.Windows.Controls.WrapPanel;$wrap.Orientation='Horizontal';$start=$script:ActionButtons.Count
    foreach($utility in @(@('apps-add','Add App','+'),@('apps-browser','Web Browser','◎'),@('apps-files','File Browser','▱'))){$b=New-HcUtilityCard $utility[0] $utility[1] $utility[2];$wrap.Children.Add($b)|Out-Null;$script:ActionButtons+=$b;$script:CurrentActions+=(New-Action $utility[0] $utility[1])}
    for($i=0;$i -lt @($script:Config.CustomApps).Count;$i++){$app=@($script:Config.CustomApps)[$i];if($null -eq $app -or (Test-HcAppIsRecognizedGame $app)){continue};$b=New-HomeCard $app "app:$i" 'Apps';$wrap.Children.Add($b)|Out-Null;$script:ActionButtons+=$b;$script:CurrentActions+=(New-Action "app:$i" ([string](Get-EntryProperty $app 'Name' 'App')))}
    $script:HcWindowsApps=@(Get-HcWindowsApps);for($i=0;$i -lt $script:HcWindowsApps.Count;$i++){$app=$script:HcWindowsApps[$i];$alreadyPinned=@($script:Config.CustomApps|Where-Object{[string]::Equals([string](Get-EntryProperty $_ 'AppUserModelId' ''),[string]$app.AppUserModelId,[StringComparison]::OrdinalIgnoreCase)}).Count -gt 0;if($alreadyPinned){continue};$b=New-HomeCard $app "windows-app:$i" 'Apps';$wrap.Children.Add($b)|Out-Null;$script:ActionButtons+=$b;$script:CurrentActions+=(New-Action "windows-app:$i" ([string]$app.Name))}
    $scroll=New-Object System.Windows.Controls.ScrollViewer;$scroll.VerticalScrollBarVisibility='Hidden';$scroll.HorizontalScrollBarVisibility='Disabled';$scroll.Content=$wrap;$script:ActionPanel.Children.Add($scroll)|Out-Null
    $count=$script:ActionButtons.Count-$start;$columns=8;try{$w=[double]$script:ActionScrollViewer.ActualWidth;if($w -gt 500){$columns=[math]::Max(4,[math]::Floor($w/214))}}catch{};for($r=0;$r -lt $count;$r+=$columns){$script:HomeRows+=,[pscustomobject]@{Start=$start+$r;Count=[math]::Min($columns,$count-$r);Platform=$false}}
}

function Format-HcTransferBytes {
    param([int64]$Bytes)
    if($Bytes -ge 1GB){return ('{0:N2} GB' -f ($Bytes/1GB))}
    if($Bytes -ge 1MB){return ('{0:N1} MB' -f ($Bytes/1MB))}
    if($Bytes -ge 1KB){return ('{0:N0} KB' -f ($Bytes/1KB))}
    return "$Bytes B"
}
function Format-HcTransferRate {
    param([double]$BytesPerSecond)
    if($BytesPerSecond -le 0){return ''}
    if($BytesPerSecond -ge 1GB){return ('{0:N2} GB/s' -f ($BytesPerSecond/1GB))}
    if($BytesPerSecond -ge 1MB){return ('{0:N1} MB/s' -f ($BytesPerSecond/1MB))}
    if($BytesPerSecond -ge 1KB){return ('{0:N0} KB/s' -f ($BytesPerSecond/1KB))}
    return ('{0:N0} B/s' -f $BytesPerSecond)
}
function Get-HcEtaText {
    param($State)
    $backendEta=[int64](Get-EntryProperty $State 'EtaSeconds' -1)
    if($backendEta -ge 0){
        $remaining=[TimeSpan]::FromSeconds($backendEta)
        if($remaining.TotalHours -ge 1){return ('{0}h {1}m remaining' -f [math]::Floor($remaining.TotalHours),$remaining.Minutes)}
        if($remaining.TotalMinutes -ge 1){return ('{0} min {1} sec remaining' -f [math]::Floor($remaining.TotalMinutes),$remaining.Seconds)}
        return ('{0} sec remaining' -f [math]::Max(0,[math]::Ceiling($remaining.TotalSeconds)))
    }
    $progress=[int](Get-EntryProperty $State 'Progress' -1);$startedText=[string](Get-EntryProperty $State 'StartedAt' '')
    if($progress -le 1 -or $progress -ge 100 -or -not $startedText){return 'Calculating ETA…'}
    try{$started=[datetime]::Parse($startedText);$elapsed=(Get-Date)-$started;if($elapsed.TotalSeconds -lt 2){return 'Calculating ETA…'};$remaining=[TimeSpan]::FromSeconds($elapsed.TotalSeconds*(100-$progress)/$progress);if($remaining.TotalHours -ge 1){return ('About {0}h {1}m remaining' -f [math]::Floor($remaining.TotalHours),$remaining.Minutes)};if($remaining.TotalMinutes -ge 1){return ('About {0} min remaining' -f [math]::Ceiling($remaining.TotalMinutes))};return ('About {0} sec remaining' -f [math]::Max(1,[math]::Ceiling($remaining.TotalSeconds)))}catch{return 'Calculating ETA…'}
}
function Convert-HcDownloadTime {param([string]$Value);if(-not $Value){return $null};try{return [datetime]::Parse($Value)}catch{return $null}}
function Prune-HcDownloadHistory {
    $cutoff=(Get-Date).AddDays(-7)
    $valid=New-Object System.Collections.ArrayList;$seen=@{}
    foreach($record in @($script:HcDownloadHistory)){
        if($null -eq $record){continue}
        if(-not [string]::Equals([string](Get-EntryProperty $record 'Mode' ''),'Install',[StringComparison]::OrdinalIgnoreCase)){continue}
        if(-not [string]::Equals([string](Get-EntryProperty $record 'Status' ''),'Complete',[StringComparison]::OrdinalIgnoreCase)){continue}
        $completed=[string](Get-EntryProperty $record 'CompletedAt' (Get-EntryProperty $record 'Updated' ''))
        $dt=Convert-HcDownloadTime $completed;if($null -eq $dt -or $dt -lt $cutoff){continue}
        $key=[string](Get-EntryProperty $record 'EventKey' '')
        if(-not $key){$key=(([string](Get-EntryProperty $record 'Provider' ''))+'|'+([string](Get-EntryProperty $record 'Name' ''))+'|'+$completed).ToLowerInvariant()}
        if($seen.ContainsKey($key)){continue};$seen[$key]=$true
        [void]$valid.Add([pscustomobject]@{Name=[string](Get-EntryProperty $record 'Name' 'Download');Provider=[string](Get-EntryProperty $record 'Provider' '');Mode='Install';Status='Complete';StartedAt=[string](Get-EntryProperty $record 'StartedAt' '');CompletedAt=$completed;EventKey=$key})
    }
    $script:HcDownloadHistory=@($valid.ToArray()|Sort-Object {[datetime]::Parse([string]$_.CompletedAt)} -Descending|Select-Object -First 20)
}
function Import-HcDownloadHistory {
    $script:HcDownloadHistory=@()
    if(Test-Path -LiteralPath $script:HcDownloadHistoryPath){try{$script:HcDownloadHistory=@(Get-Content -Raw -LiteralPath $script:HcDownloadHistoryPath|ConvertFrom-Json)}catch{$script:HcDownloadHistory=@()}}
    Prune-HcDownloadHistory
}
function Save-HcDownloadHistory {try{Prune-HcDownloadHistory;$script:HcDownloadHistory|ConvertTo-Json -Depth 8|Set-Content -LiteralPath $script:HcDownloadHistoryPath -Encoding UTF8}catch{}}
function Add-HcDownloadCompletion {param([string]$Name,[string]$Provider,[string]$StartedAt,[string]$CompletedAt,[string]$EventKey)
    if(-not $Name -or -not $CompletedAt){return};if(-not $EventKey){$EventKey=($Provider+'|'+$Name+'|'+$StartedAt+'|'+$CompletedAt).ToLowerInvariant()}
    if($script:HcDownloadObserved.ContainsKey($EventKey)){return};$script:HcDownloadObserved[$EventKey]=$true
    $record=[pscustomobject]@{Name=$Name;Provider=$Provider;Mode='Install';Status='Complete';StartedAt=$StartedAt;CompletedAt=$CompletedAt;EventKey=$EventKey}
    $script:HcDownloadHistory=@($record)+@($script:HcDownloadHistory|Where-Object{[string](Get-EntryProperty $_ 'EventKey' '') -ne $EventKey})
    Save-HcDownloadHistory
}
function Import-HcDownloadHistoryFromProviderLogs {
    # Backfill genuine provider installs from the last seven days so installs that
    # completed before this ledger revision (for example an Epic download) are not lost.
    try{
        $cutoff=(Get-Date).AddDays(-7)
        $logDir=Join-Path $script:DataDir 'Logs';if(-not(Test-Path -LiteralPath $logDir -PathType Container)){return}
        foreach($file in @(Get-ChildItem -LiteralPath $logDir -Filter 'provider-*.log' -File -ErrorAction SilentlyContinue|Where-Object{$_.LastWriteTime -ge $cutoff})){
            foreach($line in @(Get-Content -LiteralPath $file.FullName -ErrorAction SilentlyContinue)){
                $m=[regex]::Match([string]$line,'^(?<date>\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}(?:\.\d+)?) \[INFO\] \[(?<provider>[^/\]]+)/Install\] Complete - Install completed for (?<name>.+?)\.?$')
                if(-not $m.Success){continue}
                $dt=$null;try{$dt=[datetime]::Parse($m.Groups['date'].Value)}catch{};if($null -eq $dt -or $dt -lt $cutoff){continue}
                $completed=$dt.ToString('o');$provider=$m.Groups['provider'].Value.Trim();$name=$m.Groups['name'].Value.Trim().TrimEnd('.')
                Add-HcDownloadCompletion $name $provider '' $completed (('log|'+$provider+'|'+$name+'|'+$completed).ToLowerInvariant())
            }
        }
    }catch{try{Write-Log "Download-history log backfill failed: $($_.Exception.Message)" 'WARN'}catch{}}
}
function Update-HcDownloadHistory {
    foreach($state in @($script:ProviderState,$script:StorefrontState)){
        if($null -eq $state -or [bool](Get-EntryProperty $state 'Busy' $false)){continue}
        $mode=[string](Get-EntryProperty $state 'Mode' '');if(-not [string]::Equals($mode,'Install',[StringComparison]::OrdinalIgnoreCase)){continue}
        $progress=[int](Get-EntryProperty $state 'Progress' -1);if($progress -lt 100){continue}
        $status=[string](Get-EntryProperty $state 'Phase' (Get-EntryProperty $state 'Status' ''));if(-not [string]::Equals($status,'Complete',[StringComparison]::OrdinalIgnoreCase)){continue}
        if([string](Get-EntryProperty $state 'Error' '')){continue}
        $completed=[string](Get-EntryProperty $state 'Updated' (Get-EntryProperty $state 'UpdatedAt' ''));if(-not $completed){continue}
        $started=[string](Get-EntryProperty $state 'StartedAt' '')
        $provider=[string](Get-EntryProperty $state 'Provider' (Get-EntryProperty $state 'StoreId' (Get-EntryProperty $state 'Name' 'Storefront')))
        $name=[string](Get-EntryProperty $state 'GameName' (Get-EntryProperty $state 'Name' ''))
        if(-not $name){continue}
        $gameId=[string](Get-EntryProperty $state 'GameId' '')
        $eventKey=($provider+'|install|'+$gameId+'|'+$name+'|'+$started).ToLowerInvariant()
        Add-HcDownloadCompletion $name $provider $started $completed $eventKey
    }
    Prune-HcDownloadHistory
}
function Update-HcActiveDownloadVisuals {
    param($Active)
    if($null -eq $Active -or $null -eq $script:HcDownloadProgressBar){return $false}
    try{
        $name=[string](Get-EntryProperty $Active 'GameName' (Get-EntryProperty $Active 'Name' (Get-EntryProperty $Active 'Provider' 'Active download')))
        $provider=[string](Get-EntryProperty $Active 'Provider' '')
        $phase=[string](Get-EntryProperty $Active 'Phase' (Get-EntryProperty $Active 'Status' 'Working'))
        $progress=[int](Get-EntryProperty $Active 'Progress' 0)
        $downloaded=[int64](Get-EntryProperty $Active 'DownloadedBytes' 0)
        $total=[int64](Get-EntryProperty $Active 'TotalBytes' 0)
        $rate=[double](Get-EntryProperty $Active 'DownloadSpeedBytesPerSec' 0)
        if($null -ne $script:HcDownloadTitleText){$script:HcDownloadTitleText.Text=$name}
        if($null -ne $script:HcDownloadPhaseText){$script:HcDownloadPhaseText.Text=$(if($provider){$provider+'  •  '+$phase+'  •  '+(Get-HcEtaText $Active)}else{$phase+'  •  '+(Get-HcEtaText $Active)})}
        $script:HcDownloadProgressBar.Value=[math]::Max(0,[math]::Min(100,$progress))
        $amountText=if($total -gt 0){"$(Format-HcTransferBytes $downloaded) of $(Format-HcTransferBytes $total)"}elseif($downloaded -gt 0){Format-HcTransferBytes $downloaded}else{''}
        $rateText=Format-HcTransferRate $rate
        $pieces=New-Object System.Collections.ArrayList
        if($progress -ge 0){[void]$pieces.Add(("$progress%"))}
        if($amountText){[void]$pieces.Add($amountText)}
        if($rateText){[void]$pieces.Add($rateText)}
        if($null -ne $script:HcDownloadStatsText){$script:HcDownloadStatsText.Text=($pieces -join '  •  ')}
        if($null -ne $script:HcDownloadMessageText){$script:HcDownloadMessageText.Text=[string](Get-EntryProperty $Active 'Message' '')}
        return $true
    }catch{return $false}
}
function Render-HcDownloadsRoot {
    Read-StorefrontState;if(Get-Command Read-GameProviderState -ErrorAction SilentlyContinue){Read-GameProviderState};Update-HcDownloadHistory
    $script:HcDownloadTitleText=$null;$script:HcDownloadPhaseText=$null;$script:HcDownloadProgressBar=$null;$script:HcDownloadStatsText=$null;$script:HcDownloadMessageText=$null
    $heading=New-Object System.Windows.Controls.TextBlock;$heading.Text='Downloads';$heading.FontSize=30;$heading.FontWeight='Bold';$heading.Foreground='White';$heading.Margin='0,0,0,18';$script:ActionPanel.Children.Add($heading)|Out-Null
    $active=$null;if($null -ne $script:ProviderState -and [bool](Get-EntryProperty $script:ProviderState 'Busy' $false) -and [string]::Equals([string](Get-EntryProperty $script:ProviderState 'Mode' ''),'Install',[StringComparison]::OrdinalIgnoreCase)){$active=$script:ProviderState}elseif($null -ne $script:StorefrontState -and [bool](Get-EntryProperty $script:StorefrontState 'Busy' $false) -and [string]::Equals([string](Get-EntryProperty $script:StorefrontState 'Mode' ''),'Install',[StringComparison]::OrdinalIgnoreCase)){$active=$script:StorefrontState}
    if($null -ne $active){
        $border=New-Object System.Windows.Controls.Border;$border.Background='#B5101928';$border.BorderBrush='#445977';$border.BorderThickness='1';$border.CornerRadius=18;$border.Padding='22';$border.Margin='0,0,0,26'
        $stack=New-Object System.Windows.Controls.StackPanel
        $script:HcDownloadTitleText=New-Object System.Windows.Controls.TextBlock;$script:HcDownloadTitleText.FontSize=24;$script:HcDownloadTitleText.FontWeight='Bold';$script:HcDownloadTitleText.Foreground='White';$stack.Children.Add($script:HcDownloadTitleText)|Out-Null
        $script:HcDownloadPhaseText=New-Object System.Windows.Controls.TextBlock;$script:HcDownloadPhaseText.FontSize=13;$script:HcDownloadPhaseText.Foreground='#AEBBD0';$script:HcDownloadPhaseText.Margin='0,6,0,12';$stack.Children.Add($script:HcDownloadPhaseText)|Out-Null
        $script:HcDownloadProgressBar=New-Object System.Windows.Controls.ProgressBar;$script:HcDownloadProgressBar.Minimum=0;$script:HcDownloadProgressBar.Maximum=100;$script:HcDownloadProgressBar.Height=18;$stack.Children.Add($script:HcDownloadProgressBar)|Out-Null
        $script:HcDownloadStatsText=New-Object System.Windows.Controls.TextBlock;$script:HcDownloadStatsText.FontSize=14;$script:HcDownloadStatsText.FontWeight='SemiBold';$script:HcDownloadStatsText.Foreground='#D7E1EF';$script:HcDownloadStatsText.Margin='0,10,0,0';$stack.Children.Add($script:HcDownloadStatsText)|Out-Null
        $script:HcDownloadMessageText=New-Object System.Windows.Controls.TextBlock;$script:HcDownloadMessageText.FontSize=12;$script:HcDownloadMessageText.Foreground='#91A3BA';$script:HcDownloadMessageText.Margin='0,6,0,0';$script:HcDownloadMessageText.TextWrapping='Wrap';$stack.Children.Add($script:HcDownloadMessageText)|Out-Null
        [void](Update-HcActiveDownloadVisuals $active)
        $border.Child=$stack;$script:ActionPanel.Children.Add($border)|Out-Null
    }
    else{$idle=New-Object System.Windows.Controls.TextBlock;$idle.Text='No active downloads or installations.';$idle.FontSize=16;$idle.Foreground='#9DAFC5';$idle.Margin='0,0,0,24';$script:ActionPanel.Children.Add($idle)|Out-Null}
    $rh=New-Object System.Windows.Controls.TextBlock;$rh.Text='Recently Downloaded & Installed';$rh.FontSize=22;$rh.FontWeight='SemiBold';$rh.Foreground='White';$rh.Margin='0,0,0,10';$script:ActionPanel.Children.Add($rh)|Out-Null
    if(@($script:HcDownloadHistory).Count -eq 0){$empty=New-Object System.Windows.Controls.TextBlock;$empty.Text='Completed downloads from the last 7 days will appear here.';$empty.FontSize=13;$empty.Foreground='#91A3BA';$empty.Margin='0,3,0,0';$script:ActionPanel.Children.Add($empty)|Out-Null}
    foreach($record in @($script:HcDownloadHistory|Select-Object -First 20)){$b=New-Object System.Windows.Controls.Border;$b.Background='#76101927';$b.CornerRadius=12;$b.Padding='15,11';$b.Margin='0,0,0,8';$stack=New-Object System.Windows.Controls.StackPanel;$n=New-Object System.Windows.Controls.TextBlock;$n.Text=[string](Get-EntryProperty $record 'Name' 'Download');$n.FontSize=16;$n.FontWeight='SemiBold';$n.Foreground='White';$stack.Children.Add($n)|Out-Null;$provider=[string](Get-EntryProperty $record 'Provider' '');$completed=[string](Get-EntryProperty $record 'CompletedAt' '');$displayTime=$completed;try{$displayTime=([datetime]::Parse($completed)).ToString('ddd MMM d, h:mm tt')}catch{};$d=New-Object System.Windows.Controls.TextBlock;$d.Text=$(if($provider){$provider+'  •  Installed  •  '+$displayTime}else{'Installed  •  '+$displayTime});$d.FontSize=11;$d.Foreground='#91A3BA';$stack.Children.Add($d)|Out-Null;$b.Child=$stack;$script:ActionPanel.Children.Add($b)|Out-Null}
}
Import-HcDownloadHistory
Import-HcDownloadHistoryFromProviderLogs

# Centered controller-friendly choice popup used by multi-option settings.
# Initialize every popup field explicitly because StrictMode treats an unset script variable as an error.
$script:HcChoiceOverlay=$null
$script:HcChoiceButtons=@()
$script:HcChoiceOptions=@()
$script:HcChoiceSelected=0
$script:HcChoiceSetting=''
function Test-HcChoicePopupVisible {return ($null -ne $script:HcChoiceOverlay -and $script:HcChoiceOverlay.Visibility -eq 'Visible')}
function Update-HcChoicePopupVisuals {
    for($i=0;$i -lt @($script:HcChoiceButtons).Count;$i++){
        $b=$script:HcChoiceButtons[$i]
        $label=$(if($i -lt @($script:HcChoiceOptions).Count){[string]$script:HcChoiceOptions[$i]}else{''})
        if($i -eq $script:HcChoiceSelected){
            $b.Content=('▶  '+$label);$b.Background='#FFE7C45E';$b.Foreground='#FF10151D';$b.BorderBrush='#FFFFF0A0';$b.BorderThickness='2';$b.FontWeight='Bold';$b.Opacity=1.0
        }else{
            $b.Content=('    '+$label);$b.Background='#F21A2433';$b.Foreground='#FFF4F7FB';$b.BorderBrush='#FF43536A';$b.BorderThickness='1';$b.FontWeight='SemiBold';$b.Opacity=.92
        }
        try{$b.InvalidateVisual();$b.UpdateLayout()}catch{}
    }
}
function Close-HcChoicePopup {
    if($null -ne $script:HcChoiceOverlay){try{$script:RootGrid.Children.Remove($script:HcChoiceOverlay)|Out-Null}catch{}}
    $script:HcChoiceOverlay=$null;$script:HcChoiceButtons=@();$script:HcChoiceOptions=@();$script:HcChoiceSelected=0;$script:HcChoiceSetting='';Set-HcShellBlur $false;Update-Footer;try{if($null -ne $script:HcChoicePreviousFocus){[System.Windows.Input.Keyboard]::Focus($script:HcChoicePreviousFocus)|Out-Null}}catch{};$script:HcChoicePreviousFocus=$null
}
function Invoke-HcChoicePopupSelected {
    if($script:HcChoiceSelected -lt 0 -or $script:HcChoiceSelected -ge @($script:HcChoiceOptions).Count){return}
    $value=[string]$script:HcChoiceOptions[$script:HcChoiceSelected]
    switch($script:HcChoiceSetting){
        'QuickMenuPosition' {$script:Config.QuickMenuPosition=$value;Save-Config;Apply-HcQuickMenuLayout}
        'KeyboardTheme' {$script:Config.KeyboardTheme=$value;Save-Config;try{Apply-NativeKeyboardTheme}catch{}}
        'PromptOverride' {$script:Config.PromptOverride=$value;Save-Config;Update-Footer}
        'MusicTheme' {$script:Config.MusicTheme=$value;Save-Config;Initialize-BackgroundMusic}
        'DisplayScale' {
            $pct=0
            if([int]::TryParse(($value -replace '[^0-9]',''),[ref]$pct)){Set-WindowsDisplayScalePercent $pct}
        }
    }
    Invoke-UiFeedback 'Confirm';Close-HcChoicePopup;Render-Page
}
function Show-HcChoicePopup {param([string]$Title,[object[]]$Options,[string]$Current,[string]$Setting)
    try{
        if($null -eq $script:RootGrid){throw 'The root overlay grid is not initialized.'}
        if(Test-HcChoicePopupVisible){Close-HcChoicePopup}
        $script:HcChoiceOptions=Convert-ToStableArray $Options;$script:HcChoiceSetting=$Setting;$idx=[array]::IndexOf($script:HcChoiceOptions,$Current);$script:HcChoiceSelected=$(if($idx -ge 0){$idx}else{0})
        $script:HcChoicePreviousFocus=[System.Windows.Input.Keyboard]::FocusedElement;$overlay=New-Object System.Windows.Controls.Grid;$overlay.Background='#96000000';$overlay.IsHitTestVisible=$true;$overlay.Focusable=$true;[System.Windows.Input.KeyboardNavigation]::SetDirectionalNavigation($overlay,[System.Windows.Input.KeyboardNavigationMode]::None);[System.Windows.Input.KeyboardNavigation]::SetTabNavigation($overlay,[System.Windows.Input.KeyboardNavigationMode]::None);[System.Windows.Controls.Panel]::SetZIndex($overlay,9000)
        $card=New-Object System.Windows.Controls.Border;$card.Width=560;$card.Padding='28';$card.Background='#F20B111B';$card.BorderBrush='#596A83';$card.BorderThickness='1.5';$card.CornerRadius=20;$card.HorizontalAlignment='Center';$card.VerticalAlignment='Center';$card.IsHitTestVisible=$true
        $stack=New-Object System.Windows.Controls.StackPanel;$titleBlock=New-Object System.Windows.Controls.TextBlock;$titleBlock.Text=$Title;$titleBlock.FontSize=27;$titleBlock.FontWeight='Bold';$titleBlock.Foreground='White';$titleBlock.Margin='0,0,0,18';$stack.Children.Add($titleBlock)|Out-Null
        $choiceTemplate=[Windows.Markup.XamlReader]::Parse('<ControlTemplate xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" TargetType="Button"><Border Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="11" Padding="{TemplateBinding Padding}"><ContentPresenter HorizontalAlignment="{TemplateBinding HorizontalContentAlignment}" VerticalAlignment="Center"/></Border></ControlTemplate>');$script:HcChoiceButtons=@();for($i=0;$i -lt $script:HcChoiceOptions.Count;$i++){$b=New-Object System.Windows.Controls.Button;$b.Template=$choiceTemplate;$b.Tag=$i;$b.Content=('    '+[string]$script:HcChoiceOptions[$i]);$b.Height=58;$b.Margin='0,0,0,8';$b.Padding='18,8';$b.HorizontalContentAlignment='Left';$b.FontSize=18;$b.Cursor='Hand';$b.Focusable=$false;$b.IsTabStop=$false;$b.Add_Click({param($sender,$e)$script:HcChoiceSelected=[int]$sender.Tag;Update-HcChoicePopupVisuals;Invoke-HcChoicePopupSelected});$stack.Children.Add($b)|Out-Null;$script:HcChoiceButtons+=$b}
        $hint=New-Object System.Windows.Controls.TextBlock;$hint.Text='D-pad  Select     A / Enter  Apply     B / Back  Cancel';$hint.FontSize=12;$hint.Foreground='#94A5BC';$hint.Margin='0,10,0,0';$stack.Children.Add($hint)|Out-Null;$card.Child=$stack;$overlay.Children.Add($card)|Out-Null
        $script:RootGrid.Children.Add($overlay)|Out-Null;$script:HcChoiceOverlay=$overlay;Set-HcShellBlur $true;Update-HcChoicePopupVisuals;Update-Footer
        # Clear the activation edge that opened the popup, then make the popup the
        # explicit focus scope. This prevents the underlying Settings page from
        # consuming D-pad/A/B while the chooser is visible.
        $script:LastGamepadMask=0;$script:LastDirection='';$script:NextDirectionAt=[datetime]::MinValue
        try{$script:ControllerInputGuardUntil=[datetime]::MinValue;$overlay.Focus()|Out-Null;[System.Windows.Input.Keyboard]::Focus($overlay)|Out-Null}catch{}
        Write-Log "Opened centered choice popup: $Title ($($script:HcChoiceOptions -join ', '))."
    }catch{
        $script:HcChoiceOverlay=$null
        Write-Log "Choice popup failed for ${Title}: $($_.Exception.ToString())" 'ERROR'
        Set-ConsoleNotice "$Title options could not open. See the Huymaier Console log." 'ERROR'
        Render-Page
    }
}

function Move-HcChoicePopup {
    param([int]$Delta)
    $count=@($script:HcChoiceOptions).Count
    if((-not (Test-HcChoicePopupVisible)) -or $count -eq 0){return}
    $script:HcChoiceSelected=($script:HcChoiceSelected+$Delta+$count)%$count
    # Use the same validated navigation feedback token as the rest of the shell.
    # A feedback/audio failure must never abort selection movement or repaint.
    try{Invoke-UiFeedback 'Navigate'}catch{Write-Log "Choice popup navigation feedback recovered: $($_.Exception.Message)" 'WARN'}
    try{Update-HcChoicePopupVisuals}catch{Write-Log "Choice popup visual refresh recovered: $($_.Exception.Message)" 'WARN'}
}
function Handle-HcChoicePopupController {param([int]$Mask,[string]$Direction);if(-not(Test-HcChoicePopupVisible)){return $false};$now=Get-Date;if($Direction){if($Direction -ne $script:LastDirection -or $now -ge $script:NextDirectionAt){if($Direction -in @('Up','Left')){Move-HcChoicePopup -1}elseif($Direction -in @('Down','Right')){Move-HcChoicePopup 1};$isNew=$Direction -ne $script:LastDirection;$script:LastDirection=$Direction;$script:NextDirectionAt=$now.AddMilliseconds($(if($isNew){330}else{120}))}}else{$script:LastDirection='';$script:NextDirectionAt=[datetime]::MinValue};if(Is-NewButtonPress $Mask 4){Invoke-HcChoicePopupSelected}elseif((Is-NewButtonPress $Mask 8)-or(Is-NewButtonPress $Mask 2)){Invoke-UiFeedback 'Back';Close-HcChoicePopup};$script:LastGamepadMask=$Mask;return $true}
function Handle-HcChoicePopupNativeCommand {param([string]$Command);if(-not(Test-HcChoicePopupVisible)){return $false};switch($Command){'Up'{Move-HcChoicePopup -1}'Left'{Move-HcChoicePopup -1}'Down'{Move-HcChoicePopup 1}'Right'{Move-HcChoicePopup 1}'Confirm'{Invoke-HcChoicePopupSelected}'Back'{Invoke-UiFeedback 'Back';Close-HcChoicePopup}'Guide'{Invoke-UiFeedback 'Back';Close-HcChoicePopup;if(Get-Command Show-HcMainMenu -ErrorAction SilentlyContinue){Show-HcMainMenu}}};return $true}
function Handle-HcChoicePopupKey {param($Key);if(-not(Test-HcChoicePopupVisible)){return $false};switch([string]$Key){'Up'{Move-HcChoicePopup -1}'Left'{Move-HcChoicePopup -1}'Down'{Move-HcChoicePopup 1}'Right'{Move-HcChoicePopup 1}'Enter'{Invoke-HcChoicePopupSelected}'Space'{Invoke-HcChoicePopupSelected}'Escape'{Close-HcChoicePopup}'Back'{Close-HcChoicePopup}default{return $false}};return $true}

# Reorganized Settings pages.
$script:Hc250BaseGetPageDefinition=${function:Get-PageDefinition}
function Get-PageDefinition {
    param([int]$Index)
    if($Index -eq 2 -and $script:SubPage -eq 'AppsAdd'){
        return [pscustomobject]@{
            Title='Add App';Subtitle='Add an application without leaving the controller interface.';Hero='ADD APP';HeroText='Choose an executable or select an app already registered with Windows.'
            Actions=@(
                (New-Action 'app-add-executable' 'Choose executable with File Browser'),
                (New-Action 'app-add-windows' 'Choose installed Windows app'),
                (New-Action 'apps-back' 'Back to Apps')
            )
        }
    }
    if($Index -eq 2 -and $script:SubPage -eq 'WindowsAppsPicker'){
        $script:HcWindowsApps=@(Get-HcWindowsApps)
        $actions=New-Object System.Collections.ArrayList
        for($i=0;$i -lt $script:HcWindowsApps.Count;$i++){
            $app=$script:HcWindowsApps[$i]
            [void]$actions.Add((New-Action "app-add-windows:$i" ([string]$app.Name) ([string]$app.AppUserModelId)))
        }
        [void]$actions.Add((New-Action 'apps-back' 'Back to Apps'))
        return [pscustomobject]@{Title='Installed Windows Apps';Subtitle='Choose an app to pin to Huymaier Console Apps.';Hero='WINDOWS APPS';HeroText="$($script:HcWindowsApps.Count) application(s) available.";Actions=[object[]]$actions.ToArray()}
    }
    if($Index -eq 7){
        if($script:SubPage -eq 'ConsoleSettings'){
            $actions=@(
                (New-Action 'fse-home-settings' 'Xbox Mode / FSE Home'),
                (New-Action 'prompt-override' "Button prompts: $($script:Config.PromptOverride)"),
                (New-Action 'haptics-toggle' $(if($script:Config.HapticsEnabled){'Controller haptics: On'}else{'Controller haptics: Off'})),
                (New-Action 'platform-background-toggle' $(if($script:Config.PlatformBackgroundsEnabled){'Platform backgrounds: On'}else{'Platform backgrounds: Off'})),
                (New-Action 'online-artwork-toggle' $(if($script:Config.OnlineArtworkEnabled){'Online box art: On'}else{'Online box art: Off'})),
                (New-Action 'artwork-refresh' 'Refresh missing box art'),
                (New-Action 'quick-menu-position' "Quick Access location: $($script:Config.QuickMenuPosition)"),
                (New-SliderAction 'gamebar-scale-slider' 'Game Bar scale' ([int]$script:Config.GameBarScale) 'Use Left/Right to adjust the centered overlay.' 70 140),
                (New-Action 'startup-toggle' $(if($script:Config.StartWithWindows){'Start with Windows: On'}else{'Start with Windows: Off'})),
                (New-Action 'subpage-back' 'Back to Settings')
            )
            return [pscustomobject]@{Title='Huymaier Console';Subtitle='Operational console, input, startup, artwork, and Quick Access settings.';Hero='CONSOLE SETTINGS';HeroText='System behavior stays here. Appearance, dynamic theme, music, and navigation sounds are under Customization.';Actions=$actions}
        }
        if($script:SubPage -eq 'UpdatesHub'){
            return [pscustomobject]@{Title='Updates';Subtitle='Windows and hardware maintenance.';Hero='UPDATES';HeroText='Keep Windows and signed device drivers current without leaving Huymaier Console.';Actions=@((New-Action 'windows-update-settings' 'Windows Update'),(New-Action 'driver-settings' 'Driver Updates'),(New-Action 'console-update-settings' 'Huymaier Console Update' 'Check GitHub Releases for a newer Huymaier Console build.'),(New-Action 'subpage-back' 'Back to Settings'))}
        }
        if($script:SubPage -eq 'WindowsUpdate'){
            Read-UpdateState;$state=$script:UpdateState;$actions=New-Object System.Collections.Generic.List[object]
            $busy=[bool](Get-EntryProperty $state 'Busy' $false);$count=[int](Get-EntryProperty $state 'UpdateCount' 0);$phase=[string](Get-EntryProperty $state 'Phase' 'Ready')
            if($busy){$actions.Add((New-Action 'noop' "$phase..." ([string](Get-EntryProperty $state 'Message' 'Windows Update is working.'))))}
            else{
                $actions.Add((New-Action 'update-scan' 'Scan again' 'Check Microsoft Update for available Windows updates.'))
                if($count -gt 0){$actions.Add((New-Action 'update-install' "Install $count update(s)" 'Download and install the updates shown on this page. Administrator approval may be required.'))}
                if([bool](Get-EntryProperty $state 'RebootRequired' $false)){$actions.Add((New-Action 'update-restart' 'Restart PC to finish updates' 'Restart Windows now to complete pending update installation.'))}
                if([string](Get-EntryProperty $state 'Error' '') -or [int](Get-EntryProperty $state 'ResultCode' 0) -lt 0){$actions.Add((New-Action 'update-reset' 'Clear update error'))}
            }
            foreach($update in (@(Get-EntryProperty $state 'Updates' @())|Select-Object -First 12)){$title=[string](Get-EntryProperty $update 'Title' 'Windows update');$kb=[string](Get-EntryProperty $update 'KB' '');$actions.Add((New-Action 'noop' $title $(if($kb){$kb}else{'Available Windows update'})))}
            $actions.Add((New-Action 'subpage-back' 'Back to Updates'))
            $hero=if($busy){$phase.ToUpperInvariant()}elseif($count -gt 0){"$count UPDATE(S) AVAILABLE"}elseif([string](Get-EntryProperty $state 'Error' '')){'UPDATE ERROR'}else{'WINDOWS IS UP TO DATE'}
            return [pscustomobject]@{Title='Windows Update';Subtitle='Scan, review, install, and restart without leaving Huymaier Console.';Hero=$hero;HeroText=(Get-UpdateHeroText);Actions=[object[]]$actions.ToArray()}
        }
        if($script:SubPage -eq 'Drivers'){
            Read-DriverState;$state=$script:DriverState;$actions=New-Object System.Collections.Generic.List[object]
            $busy=[bool](Get-EntryProperty $state 'Busy' $false);$count=[int](Get-EntryProperty $state 'UpdateCount' 0);$phase=[string](Get-EntryProperty $state 'Phase' 'Ready');$gpus=@(Get-EntryProperty $state 'DisplayDrivers' @())
            if($busy){$actions.Add((New-Action 'noop' "$phase..." ([string](Get-EntryProperty $state 'Message' 'Driver Update is working.'))))}
            else{
                $actions.Add((New-Action 'driver-scan' 'Scan again' 'Detect hardware and check the Windows Update driver channel.'))
                if($count -gt 0){$actions.Add((New-Action 'driver-install-updates' "Install $count recommended driver update(s)" 'Install all recommended signed driver updates. Administrator approval is required.'))}
                $actions.Add((New-Action 'driver-install-package' 'Install local driver package' 'Choose a folder containing signed .inf packages.'))
                if([bool](Get-EntryProperty $state 'RebootRequired' $false)){$actions.Add((New-Action 'driver-restart' 'Restart PC to finish driver updates' 'Restart Windows now to complete pending driver installation.'))}
                if([string](Get-EntryProperty $state 'Error' '')){$actions.Add((New-Action 'driver-reset' 'Clear driver error'))}
            }
            foreach($gpu in ($gpus|Select-Object -First 4)){$name=[string](Get-EntryProperty $gpu 'DeviceName' 'Graphics adapter');$version=[string](Get-EntryProperty $gpu 'Version' '');$provider=[string](Get-EntryProperty $gpu 'Provider' '');$date=[string](Get-EntryProperty $gpu 'DriverDate' '');$actions.Add((New-Action 'noop' $name "$provider  |  Driver $version$(if($date){'  |  '+$date}else{''})"))}
            foreach($update in (@(Get-EntryProperty $state 'Updates' @())|Select-Object -First 12)){$title=[string](Get-EntryProperty $update 'Title' 'Driver update');$manufacturer=[string](Get-EntryProperty $update 'Manufacturer' '');$version=[string](Get-EntryProperty $update 'Version' '');$updateId=[string](Get-EntryProperty $update 'UpdateId' '');$details=@($manufacturer,$version)|Where-Object{$_};$actions.Add((New-Action $(if($updateId){"driver-install-update:$updateId"}else{'noop'}) $title ($details -join '  | ')))}
            $actions.Add((New-Action 'subpage-back' 'Back to Updates'))
            $hero=if($busy){$phase.ToUpperInvariant()}elseif($count -gt 0){"$count DRIVER UPDATE(S)"}elseif([string](Get-EntryProperty $state 'Error' '')){'DRIVER ERROR'}else{'DRIVERS ARE CURRENT'}
            return [pscustomobject]@{Title='Driver Updates';Subtitle='Scan, review, and install signed graphics and device-driver updates.';Hero=$hero;HeroText=(Get-DriverHeroText);Actions=[object[]]$actions.ToArray()}
        }
        if($script:SubPage -eq 'ConsoleUpdate'){
            $state=Read-HcConsoleUpdateState;$actions=New-Object System.Collections.Generic.List[object]
            $busy=[bool](Get-EntryProperty $state 'Busy' $false);$phase=[string](Get-EntryProperty $state 'Phase' 'Ready');$latest=[string](Get-EntryProperty $state 'LatestVersion' '');$available=[bool](Get-EntryProperty $state 'UpdateAvailable' $false);$local=[string](Get-EntryProperty $state 'LocalPath' '');$error=[string](Get-EntryProperty $state 'Error' '')
            if($busy){
                $details=[string](Get-EntryProperty $state 'Message' 'Working...');$done=[long](Get-EntryProperty $state 'DownloadedBytes' 0);$total=[long](Get-EntryProperty $state 'TotalBytes' 0);$pct=[double](Get-EntryProperty $state 'Percent' 0)
                if($phase -eq 'Downloading' -and $total -gt 0){$details+=("  |  {0} / {1}  |  {2:N1}%" -f (Format-HcUpdateBytes $done),(Format-HcUpdateBytes $total),$pct)}
                $actions.Add((New-Action 'noop' "$phase..." $details))
            }else{
                $actions.Add((New-Action 'console-update-scan' 'Check for updates' 'Query the latest GitHub Release for thermalkil/HuymaierConsole.'))
                if($available -and (-not $local -or -not (Test-Path -LiteralPath $local))){$actions.Add((New-Action 'console-update-download' "Download v$latest" 'Download the release package into the Huymaier Console update cache.'))}
                if($available -and $local -and (Test-Path -LiteralPath $local)){$actions.Add((New-Action 'console-update-install' "Install v$latest and restart Console" 'Close Huymaier Console, install the downloaded release, and relaunch automatically.'))}
            }
            if($latest){$actions.Add((New-Action 'noop' "Latest release: v$latest" ([string](Get-EntryProperty $state 'PublishedAt' ''))))}
            if([string](Get-EntryProperty $state 'Sha256' '')){$actions.Add((New-Action 'noop' 'Downloaded package verified locally' ('SHA-256 '+[string](Get-EntryProperty $state 'Sha256' ''))))}
            if($error){$actions.Add((New-Action 'noop' 'Update check error' $error))}
            $actions.Add((New-Action 'subpage-back' 'Back to Updates'))
            $hero=if($busy){$phase.ToUpperInvariant()}elseif($error){'UPDATE CHECK FAILED'}elseif($available -and $local -and (Test-Path -LiteralPath $local)){'READY TO INSTALL'}elseif($available){"V$latest AVAILABLE"}elseif($latest){'CONSOLE IS UP TO DATE'}else{'CONSOLE UPDATE'}
            $heroText=[string](Get-EntryProperty $state 'Message' 'Check GitHub Releases for a newer Huymaier Console build.')
            return [pscustomobject]@{Title='Huymaier Console Update';Subtitle='Check, download, install, and relaunch Huymaier Console from GitHub Releases.';Hero=$hero;HeroText=$heroText;Actions=[object[]]$actions.ToArray()}
        }
        if($script:SubPage -eq 'Devices'){
            $page=& $script:Hc250BaseGetPageDefinition $Index
            $actions=@((New-Action 'wifi-open' 'Wi-Fi & Networks' 'Open the Windows secure network chooser.'))+@($page.Actions)
            return [pscustomobject]@{Title='Bluetooth / Wi-Fi';Subtitle='Wireless networks and paired devices.';Hero='WIRELESS';HeroText='Connect to Wi-Fi and pair Bluetooth devices without changing the Huymaier Console shell.';Actions=$actions}
        }
        if(-not $script:SubPage){
            return [pscustomobject]@{Title='Settings';Subtitle='System and Huymaier Console settings.';Hero='SETTINGS';HeroText='Choose a category.';Actions=@((New-Action 'open-display-panel' 'Display'),(New-Action 'sound-settings' 'Audio'),(New-Action 'bluetooth-settings' 'Bluetooth / Wi-Fi'),(New-Action 'controller-diagnostics' 'Controllers'),(New-Action 'console-settings' 'Huymaier Console'),(New-Action 'updates-hub' 'Updates'))}
        }
    }
    return (& $script:Hc250BaseGetPageDefinition $Index)
}

# Render wrapper gives Home, Apps, and Downloads their new layouts while the
# original renderer remains authoritative everywhere else (including Power).
$script:Hc250BaseRenderPage=${function:Render-Page}
function Render-Page {
    if($null -eq $script:PageTitle){return}
    if($script:SelectedTab -eq 0 -and -not $script:SubPage){
        $script:ActionPanel.Children.Clear();$script:ActionButtons=@();$script:CurrentActions=@();$script:HomeRows=@();$script:SliderControls=@{};$script:PageTitle.Visibility='Collapsed';$script:PageSubtitle.Visibility='Collapsed';$script:HeroPanel.Visibility='Collapsed';[System.Windows.Controls.Grid]::SetColumnSpan($script:MainListArea,2);$script:MainListArea.Margin='0'
        $installed=Get-HcInstalledGameMap;$script:HcShellRecentGames=@();foreach($r in @($script:Config.RecentGames)){if($null -eq $r){continue};$resolved=Resolve-HcRecentGame $r $installed.Map;if($null -ne $resolved){$script:HcShellRecentGames+=$resolved}};$script:HcShellRecentGames=@($script:HcShellRecentGames|Select-Object -First 12)
        $script:HcShellRecentApps=@($script:Config.RecentApps|Where-Object{$_ -and (Test-HcRecentAppAvailable $_)}|Select-Object -First 12);$installedEntries=Convert-ToStableArray (Get-EntryProperty $installed 'Entries' @());$script:HcShellRandomPicks=if($installedEntries.Count -gt 12){@($installedEntries|Get-Random -Count 12)}else{@($installedEntries)}
        Add-HcHomeActionBar
        Add-HomeRail 'Recently Launched Games' $script:HcShellRecentGames 'home-recent-game' 'Launch a game and it will appear here.';Add-HomeRail 'Recently Launched Apps' $script:HcShellRecentApps 'home-recent-app' 'Launch an app and it will appear here.';Add-HomeRail 'Random Picks' $script:HcShellRandomPicks 'home-random-game' 'Installed games will appear here.'
        if($script:SelectedAction -ge $script:ActionButtons.Count){$script:SelectedAction=0};Update-ActionVisuals;Update-NavVisuals;Update-Footer;Set-PlatformBackground $false;return
    }
    if($script:SelectedTab -eq 2 -and -not $script:SubPage){$script:ActionPanel.Children.Clear();$script:ActionButtons=@();$script:CurrentActions=@();$script:HomeRows=@();$script:SliderControls=@{};$script:PageTitle.Visibility='Collapsed';$script:PageSubtitle.Visibility='Collapsed';$script:HeroPanel.Visibility='Collapsed';[System.Windows.Controls.Grid]::SetColumnSpan($script:MainListArea,2);$script:MainListArea.Margin='0';Render-HcAppsRoot;if($script:SelectedAction -ge $script:ActionButtons.Count){$script:SelectedAction=0};Update-ActionVisuals;Update-NavVisuals;Update-Footer;Set-PlatformBackground $false;return}
    if($script:SelectedTab -eq 4 -and -not $script:SubPage){$script:ActionPanel.Children.Clear();$script:ActionButtons=@();$script:CurrentActions=@();$script:HomeRows=@();$script:SliderControls=@{};$script:PageTitle.Visibility='Collapsed';$script:PageSubtitle.Visibility='Collapsed';$script:HeroPanel.Visibility='Collapsed';[System.Windows.Controls.Grid]::SetColumnSpan($script:MainListArea,2);$script:MainListArea.Margin='0';Render-HcDownloadsRoot;Update-NavVisuals;Update-Footer;Set-PlatformBackground $false;return}
    & $script:Hc250BaseRenderPage
}

$script:Hc250BaseCompleteNativeFolderSelection=${function:Complete-NativeFolderSelection}
function Complete-NativeFolderSelection {
    if($script:FileBrowserEntryType -in @('StorefrontInstall','StorefrontLibrary')){
        if([string]::IsNullOrWhiteSpace($script:FileBrowserPath) -or -not (Test-Path -LiteralPath $script:FileBrowserPath -PathType Container)){return};$path=[string]$script:FileBrowserPath;$store=[string]$script:FileBrowserStore
        if($script:FileBrowserEntryType -eq 'StorefrontInstall'){$list=New-Object System.Collections.ArrayList;foreach($x in @($script:Config.StorefrontInstallOverrides)){if($x -and -not [string]::Equals([string](Get-EntryProperty $x 'Store' ''),$store,[StringComparison]::OrdinalIgnoreCase)){[void]$list.Add($x)}};[void]$list.Add([pscustomobject]@{Store=$store;Path=$path});$script:Config.StorefrontInstallOverrides=[object[]]$list.ToArray()}
        $rootStore=$store;$definition=Get-StorefrontDefinition $store;if($null -ne $definition){$rootStore=Get-HcStorefrontDisplayPlatform $definition};$roots=New-Object System.Collections.ArrayList;foreach($x in @($script:Config.StorefrontRoots)){if($x){[void]$roots.Add($x)}};if(-not (@($roots)|Where-Object{[string]::Equals([string](Get-EntryProperty $_ 'Store' ''),$rootStore,[StringComparison]::OrdinalIgnoreCase) -and [string]::Equals([string](Get-EntryProperty $_ 'Path' ''),$path,[StringComparison]::OrdinalIgnoreCase)})){[void]$roots.Add([pscustomobject]@{Store=$rootStore;Path=$path})};$script:Config.StorefrontRoots=[object[]]$roots.ToArray();Save-Config;Refresh-StorefrontCatalog;Start-LibraryScan;$script:SelectedTab=1;$script:SubPage=$(if($script:FileBrowserEntryType -eq 'StorefrontInstall'){'PlatformChoice'}else{'StorefrontManage'});$script:SelectedAction=0;Render-Page;Update-NavVisuals;return
    }
    & $script:Hc250BaseCompleteNativeFolderSelection
}

function Invoke-HcShellCriticalAction {param([string]$Id)
    switch($Id){
        'updates-hub' {Write-Log 'Settings navigation: Updates hub opened.';$script:SubPage='UpdatesHub';$script:SelectedAction=0;Render-Page;return $true}
        'windows-update-settings' {Write-Log 'Settings navigation: Windows Update page opened.';$script:SubPage='WindowsUpdate';$script:SelectedAction=0;Read-UpdateState;Render-Page;if(-not [bool](Get-EntryProperty $script:UpdateState 'Busy' $false)){Start-UpdateWorker 'Scan'};return $true}
        'driver-settings' {Write-Log 'Settings navigation: Driver Updates page opened.';$script:SubPage='Drivers';$script:SelectedAction=0;Read-DriverState;Render-Page;if(-not [bool](Get-EntryProperty $script:DriverState 'Busy' $false)){Start-DriverWorker 'Scan'};return $true}
        'console-update-settings' {Write-Log 'Settings navigation: Huymaier Console Update page opened.';$script:SubPage='ConsoleUpdate';$script:SelectedAction=0;Read-HcConsoleUpdateState|Out-Null;Render-Page;if(-not [bool](Get-EntryProperty $script:HcConsoleUpdateState 'Busy' $false)){Start-HcConsoleUpdateWorker 'Scan'};return $true}
        'console-update-scan' {Start-HcConsoleUpdateWorker 'Scan';return $true}
        'console-update-download' {Start-HcConsoleUpdateWorker 'Download';return $true}
        'console-update-install' {Start-HcConsoleSelfUpdate;return $true}
        'quick-menu-position' {Write-Log 'Settings action: opening Quick Access location chooser.';Show-HcChoicePopup 'Quick Access location' @('Bottom','Top','Left','Right') ([string](Get-EntryProperty $script:Config 'QuickMenuPosition' 'Bottom')) 'QuickMenuPosition';return $true}
        'keyboard-theme' {Write-Log 'Settings action: opening keyboard theme chooser.';Show-HcChoicePopup 'Keyboard theme' @('Huymaier','Light','High Contrast') ([string](Get-EntryProperty $script:Config 'KeyboardTheme' 'Huymaier')) 'KeyboardTheme';return $true}
        'prompt-override' {Write-Log 'Settings action: opening button prompt chooser.';Show-HcChoicePopup 'Button prompts' @('Auto','Xbox','PlayStation','Nintendo','Steam','Keyboard') ([string](Get-EntryProperty $script:Config 'PromptOverride' 'Auto')) 'PromptOverride';return $true}
        'music-theme' {
            $themes=New-Object System.Collections.ArrayList
            $customPath=[string](Get-EntryProperty $script:Config 'CustomMusicPath' '')
            foreach($theme in @('Orchestral','Power','Custom')){
                if($theme -ne 'Custom' -or ($customPath -and (Test-Path -LiteralPath $customPath))){[void]$themes.Add($theme)}
            }
            Write-Log 'Settings action: opening music theme chooser.'
            Show-HcChoicePopup 'Music theme' ([object[]]$themes.ToArray()) ([string](Get-EntryProperty $script:Config 'MusicTheme' 'Orchestral')) 'MusicTheme'
            return $true
        }
        'display-scale' {$scale=Get-WindowsConfiguredDisplayScalePercent;Write-Log "Settings action: opening Windows display scale chooser. Current/configured=$scale%.";Show-HcChoicePopup 'Windows display scale' @('100%','125%','150%','175%','200%','225%','250%','300%','350%','400%','450%','500%') "$scale%" 'DisplayScale';return $true}
        'subpage-back' {if($script:SelectedTab -eq 7 -and $script:SubPage -in @('WindowsUpdate','Drivers','ConsoleUpdate')){$script:SubPage='UpdatesHub';$script:SelectedAction=0;Render-Page;return $true}}
    }
    return $false
}

$script:Hc250BaseInvokeAction=${function:Invoke-Action}
function Invoke-Action {
    param([string]$Id)
    if(Invoke-HcShellCriticalAction $Id){return}
    switch -Regex($Id){
        '^home-action:(\d+)$' {$tabs=@(1,2,4,7,8);$i=[int]$matches[1];if($i -ge 0 -and $i -lt $tabs.Count){Set-Tab $tabs[$i]};return}
        '^home-recent-game:(\d+)$' {$i=[int]$matches[1];if($i -ge 0 -and $i -lt $script:HcShellRecentGames.Count){$g=$script:HcShellRecentGames[$i];Add-ToRecent 'Game' $g;if((Get-Command Invoke-ProviderGameLaunchEntry -ErrorAction SilentlyContinue) -and (Invoke-ProviderGameLaunchEntry $g)){}else{Start-RecentEntry $g}};return}
        '^home-recent-app:(\d+)$' {$i=[int]$matches[1];if($i -ge 0 -and $i -lt $script:HcShellRecentApps.Count){$a=$script:HcShellRecentApps[$i];Add-ToRecent 'App' $a;if([string](Get-EntryProperty $a 'AppUserModelId' '')){Start-HcWindowsApp $a}else{Start-RecentEntry $a}};return}
        '^home-random-game:(\d+)$' {$i=[int]$matches[1];if($i -ge 0 -and $i -lt $script:HcShellRandomPicks.Count){$g=$script:HcShellRandomPicks[$i];Add-ToRecent 'Game' $g;if((Get-Command Invoke-ProviderGameLaunchEntry -ErrorAction SilentlyContinue) -and (Invoke-ProviderGameLaunchEntry $g)){}else{Start-RecentEntry $g}};return}
        '^windows-app:(\d+)$' {$i=[int]$matches[1];if($i -ge 0 -and $i -lt $script:HcWindowsApps.Count){$a=$script:HcWindowsApps[$i];Add-ToRecent 'App' $a;Start-HcWindowsApp $a};return}
        '^app-add-windows:(\d+)$' {$i=[int]$matches[1];if($i -ge 0 -and $i -lt $script:HcWindowsApps.Count){$a=$script:HcWindowsApps[$i];$exists=@($script:Config.CustomApps|Where-Object{[string]::Equals([string](Get-EntryProperty $_ 'AppUserModelId' ''),[string]$a.AppUserModelId,[StringComparison]::OrdinalIgnoreCase)}).Count -gt 0;if(-not $exists){$entry=[pscustomobject]@{Name=[string]$a.Name;AppUserModelId=[string]$a.AppUserModelId;LaunchTarget=[string]$a.LaunchTarget;Path='';Arguments=@();Source='Windows App';ArtworkPath=''};$script:Config.CustomApps=@($script:Config.CustomApps)+@($entry);Save-Config};$script:SubPage='';$script:SelectedAction=0;Render-Page};return}
        '^storefront-manage-open:(.+)$' {Open-Storefront ([string]$matches[1]);return}
        '^storefront-manage-uninstall:(.+)$' {$id=[string]$matches[1];$item=Get-StorefrontCatalogItem $id;$name=[string](Get-EntryProperty $item 'Name' $id);Request-NativeConfirmation "storefront-uninstall:$id" "Uninstall $name using its registered Windows uninstall method?";return}
        '^storefront-manage-account:(.+)$' {$script:SubPage='ProviderStore';$script:SelectedAction=0;Render-Page;return}
        '^storefront-manage-refresh:(.+)$' {if(Get-Command Clear-HcGameDataCache -ErrorAction SilentlyContinue){Clear-HcGameDataCache};Start-LibraryScan;Start-OnlineArtworkScan -ResetCursor;Set-ConsoleNotice 'Library and missing artwork refresh started.' 'INFO';Render-Page;return}
        '^storefront-manage-location:(.+)$' {$id=[string]$matches[1];Start-NativeFilePicker -Mode PickFolder -Store $id -EntryType StorefrontLibrary -ReturnTab 1;return}
        '^storefront-manage-find:(.+)$' {$id=[string]$matches[1];Start-NativeFilePicker -Mode PickFolder -Store $id -EntryType StorefrontInstall -ReturnTab 1;return}
    }
    switch($Id){
        'platform-storefront-manage' {$script:SubPage='StorefrontManage';$script:SelectedAction=0;Render-Page;return}
        'storefront-install-selected' {$id=Get-HcStorefrontIdByPlatform $script:SelectedGamePlatform;if($id){Start-StorefrontWorker 'Install' $id;Render-Page};return}
        'storefront-find-selected' {$id=Get-HcStorefrontIdByPlatform $script:SelectedGamePlatform;if($id){Start-NativeFilePicker -Mode PickFolder -Store $id -EntryType StorefrontInstall -ReturnTab 1};return}
        'apps-add' {$script:SubPage='AppsAdd';$script:SelectedAction=0;Render-Page;return}
        'apps-browser' {Set-Tab 3;return}
        'apps-files' {$script:FileBrowserPath='';$script:FileBrowserMode='Browse';Set-Tab 6;return}
        'app-add-executable' {Add-CustomEntry 'App';return}
        'app-add-windows' {$script:SubPage='WindowsAppsPicker';$script:SelectedAction=0;Render-Page;return}
        'apps-back' {$script:SelectedTab=2;$script:SubPage='';$script:SelectedAction=0;Render-Page;Update-NavVisuals;return}
        'console-settings' {$script:SubPage='ConsoleSettings';$script:SelectedAction=0;Render-Page;return}
        'wifi-open' {Start-UriOrShellTarget 'ms-availablenetworks:';return}
    }
    & $script:Hc250BaseInvokeAction $Id
}

# HUYMAIER_PROVIDER_CONCURRENCY_UI_V1
$concurrencyUi=Join-Path $script:BaseDir 'HuymaierProviderConcurrencyUi.ps1'
if(Test-Path -LiteralPath $concurrencyUi -PathType Leaf){. $concurrencyUi}
