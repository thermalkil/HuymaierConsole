# Huymaier Console unified library and game-detail experience.
# Loaded after the base shell functions so these definitions intentionally
# replace the v0.15 rail-based library helpers.

$script:SelectedGameEntry = $null
$script:GameReturnSubPage = 'PlatformLibrary'
$script:GameReturnAction = 0
$script:GameReturnScrollOffset = 0.0
$script:GamePropertiesCategory = 'General'
$script:GameModalMode = ''
$script:GameModalButtons = @()
$script:GameModalEntries = @()
$script:GameModalSelected = 0
$script:GameModalDestinations = @()
$script:GameModalLocationPurpose = ''
$script:GameModalSelectedDestination = $null
$script:HcMainMenuButtons = @()
$script:HcMainMenuEntries = @()
$script:HcMainMenuSelected = 0

function Get-HcSafeText {
    param($Value,[string]$Default='')
    if($null -eq $Value){return $Default}
    $text=[string]$Value
    if([string]::IsNullOrWhiteSpace($text)){return $Default}
    return $text.Trim()
}

function Test-HcUsefulGameName {
    param([string]$Name)
    if([string]::IsNullOrWhiteSpace($Name)){return $false}
    $trim=$Name.Trim()
    if($trim -match '^\d{6,}$'){return $false}
    if($trim -match '^(?i)(game|unknown|untitled)$'){return $false}
    return $true
}

function Get-HcNormalizedName {
    param([string]$Name)
    if([string]::IsNullOrWhiteSpace($Name)){return ''}
    return (($Name.ToLowerInvariant() -replace '[™®©]','' -replace '[^a-z0-9]+',' ').Trim())
}

function Get-HcCanonicalGameId {
    param($Entry,[string]$Platform='')
    if($null -eq $Entry){return ''}
    $source=Get-HcSafeText (Get-EntryProperty $Entry 'Provider' (Get-EntryProperty $Entry 'Source' $Platform)) $Platform
    $id=Get-HcSafeText (Get-EntryProperty $Entry 'ProviderGameId' '') ''
    if(-not $id){$id=Get-HcSafeText (Get-EntryProperty $Entry 'Id' '') ''}
    if($id -and $source){
        $prefix=[regex]::Escape($source)
        $id=$id -replace "^(?i)${prefix}:",''
    }
    if($id -and $Platform){
        $prefix=[regex]::Escape($Platform)
        $id=$id -replace "^(?i)${prefix}:",''
    }
    if(-not $id){$id=Get-HcSafeText (Get-EntryProperty $Entry 'LaunchTarget' (Get-EntryProperty $Entry 'Path' '')) ''}
    if(-not $id){return ''}
    return ((Get-HcSafeText $source $Platform).ToLowerInvariant()+'|'+$id.ToLowerInvariant())
}

function Convert-HcGameEntry {
    param($Entry,[string]$Platform='')
    if($null -eq $Entry){return $null}
    $provider=Get-HcSafeText (Get-EntryProperty $Entry 'Provider' '') ''
    $source=Get-HcSafeText (Get-EntryProperty $Entry 'Source' $provider) $Platform
    if(-not $source){$source=$Platform}
    $providerId=Get-HcSafeText (Get-EntryProperty $Entry 'ProviderGameId' '') ''
    $rawId=Get-HcSafeText (Get-EntryProperty $Entry 'Id' '') ''
    if(-not $providerId -and $provider){
        $providerId=$rawId -replace ('^(?i)'+[regex]::Escape($provider)+':'),''
    }
    $installed=[bool](Get-EntryProperty $Entry 'Installed' $true)
    $path=Get-HcSafeText (Get-EntryProperty $Entry 'Path' '') ''
    $installPath=Get-HcSafeText (Get-EntryProperty $Entry 'InstallPath' $path) $path
    $launch=Get-HcSafeText (Get-EntryProperty $Entry 'LaunchTarget' '') ''
    $art=Get-HcSafeText (Get-EntryProperty $Entry 'ArtworkPath' '') ''
    return [pscustomobject]@{
        Id=$(if($providerId){$providerId}else{$rawId})
        Name=Get-HcSafeText (Get-EntryProperty $Entry 'Name' 'Game') 'Game'
        Source=$source
        Provider=$provider
        ProviderGameId=$providerId
        Installed=$installed
        ProviderInstalled=[bool](Get-EntryProperty $Entry 'ProviderInstalled' $(if($provider){$installed}else{$false}))
        InstallPath=$installPath
        Path=$path
        LaunchTarget=$launch
        Arguments=Get-EntryProperty $Entry 'Arguments' @()
        ArtworkPath=$art
        HeroArtworkPath=Get-HcSafeText (Get-EntryProperty $Entry 'HeroArtworkPath' '') ''
        ArtworkUrl=Get-HcSafeText (Get-EntryProperty $Entry 'ArtworkUrl' '') ''
        Description=Get-HcSafeText (Get-EntryProperty $Entry 'Description' '') ''
        SizeText=Get-HcSafeText (Get-EntryProperty $Entry 'SizeText' '') ''
        InstallSizeBytes=Get-EntryProperty $Entry 'InstallSizeBytes' 0
        UpdateAvailable=[bool](Get-EntryProperty $Entry 'UpdateAvailable' $false)
        Platform=Get-HcSafeText (Get-EntryProperty $Entry 'Platform' '') ''
        PlatformId=Get-HcSafeText (Get-EntryProperty $Entry 'PlatformId' '') ''
        PlatformSlug=Get-HcSafeText (Get-EntryProperty $Entry 'PlatformSlug' '') ''
        PlaytimeMinutes=Get-EntryProperty $Entry 'PlaytimeMinutes' 0
        CloudStatus=Get-HcSafeText (Get-EntryProperty $Entry 'CloudStatus' '') ''
        ControllerSupport=Get-HcSafeText (Get-EntryProperty $Entry 'ControllerSupport' '') ''
    }
}

function Merge-HcGameEntry {
    param($Existing,$Incoming,[string]$Platform='')
    if($null -eq $Existing){return Convert-HcGameEntry $Incoming $Platform}
    if($null -eq $Incoming){return Convert-HcGameEntry $Existing $Platform}
    $a=Convert-HcGameEntry $Existing $Platform
    $b=Convert-HcGameEntry $Incoming $Platform
    $installed=([bool]$a.Installed -or [bool]$b.Installed)
    $name=if(Test-HcUsefulGameName ([string]$b.Name)){[string]$b.Name}elseif(Test-HcUsefulGameName ([string]$a.Name)){[string]$a.Name}else{[string]$b.Name}
    $provider=if($b.Provider){$b.Provider}else{$a.Provider}
    $providerId=if($b.ProviderGameId){$b.ProviderGameId}else{$a.ProviderGameId}
    $launch=if($a.LaunchTarget -and [bool]$a.Installed){$a.LaunchTarget}elseif($b.LaunchTarget){$b.LaunchTarget}else{$a.LaunchTarget}
    $path=if($a.Path -and [bool]$a.Installed){$a.Path}elseif($b.Path){$b.Path}else{$a.Path}
    $installPath=if($a.InstallPath -and [bool]$a.Installed){$a.InstallPath}elseif($b.InstallPath){$b.InstallPath}else{$a.InstallPath}
    $art=if($b.ArtworkPath -and (Test-Path -LiteralPath $b.ArtworkPath -PathType Leaf)){$b.ArtworkPath}elseif($a.ArtworkPath){$a.ArtworkPath}else{$b.ArtworkPath}
    $hero=if($b.HeroArtworkPath){$b.HeroArtworkPath}else{$a.HeroArtworkPath}
    return [pscustomobject]@{
        Id=$(if($providerId){$providerId}elseif($b.Id){$b.Id}else{$a.Id})
        Name=$name
        Source=$(if($b.Source){$b.Source}else{$a.Source})
        Provider=$provider
        ProviderGameId=$providerId
        Installed=$installed
        ProviderInstalled=([bool]$a.ProviderInstalled -or [bool]$b.ProviderInstalled)
        InstallPath=$installPath
        Path=$path
        LaunchTarget=$launch
        Arguments=$(if(@($a.Arguments).Count -gt 0){$a.Arguments}else{$b.Arguments})
        ArtworkPath=$art
        HeroArtworkPath=$hero
        ArtworkUrl=$(if($b.ArtworkUrl){$b.ArtworkUrl}else{$a.ArtworkUrl})
        Description=$(if($b.Description){$b.Description}else{$a.Description})
        SizeText=$(if($b.SizeText){$b.SizeText}else{$a.SizeText})
        InstallSizeBytes=$(if([double]$b.InstallSizeBytes -gt 0){$b.InstallSizeBytes}else{$a.InstallSizeBytes})
        UpdateAvailable=([bool]$a.UpdateAvailable -or [bool]$b.UpdateAvailable)
        Platform=$(if($b.Platform){$b.Platform}else{$a.Platform})
        PlatformId=$(if($b.PlatformId){$b.PlatformId}else{$a.PlatformId})
        PlatformSlug=$(if($b.PlatformSlug){$b.PlatformSlug}else{$a.PlatformSlug})
        PlaytimeMinutes=$(if([double]$b.PlaytimeMinutes -gt 0){$b.PlaytimeMinutes}else{$a.PlaytimeMinutes})
        CloudStatus=$(if($b.CloudStatus){$b.CloudStatus}else{$a.CloudStatus})
        ControllerSupport=$(if($b.ControllerSupport){$b.ControllerSupport}else{$a.ControllerSupport})
    }
}

function Add-HcMergedGame {
    param([System.Collections.ArrayList]$Items,[hashtable]$IndexById,[hashtable]$IndexByName,$Entry,[string]$Platform='')
    if($null -eq $Entry){return}
    $normalized=Convert-HcGameEntry $Entry $Platform
    if($null -eq $normalized){return}
    $name=[string]$normalized.Name
    if(-not (Test-HcUsefulGameName $name)){return}
    $idKey=Get-HcCanonicalGameId $normalized $Platform
    $nameKey=(Get-HcSafeText $normalized.Source $Platform).ToLowerInvariant()+'|'+(Get-HcNormalizedName $name)
    $index=-1
    if($idKey -and $IndexById.ContainsKey($idKey)){$index=[int]$IndexById[$idKey]}
    elseif($nameKey -and $IndexByName.ContainsKey($nameKey)){$index=[int]$IndexByName[$nameKey]}
    if($index -ge 0){
        $merged=Merge-HcGameEntry $Items[$index] $normalized $Platform
        $Items[$index]=$merged
        $newId=Get-HcCanonicalGameId $merged $Platform
        $newName=(Get-HcSafeText $merged.Source $Platform).ToLowerInvariant()+'|'+(Get-HcNormalizedName ([string]$merged.Name))
        if($newId){$IndexById[$newId]=$index}
        if($newName){$IndexByName[$newName]=$index}
    }else{
        $index=$Items.Count
        [void]$Items.Add($normalized)
        if($idKey){$IndexById[$idKey]=$index}
        if($nameKey){$IndexByName[$nameKey]=$index}
    }
}

function Test-HcProviderGameVisible{
    param($Entry,[string]$Provider)
    if($null -eq $Entry){return $false}
    if(-not [string]::Equals($Provider,'Epic',[StringComparison]::OrdinalIgnoreCase)){return $true}
    $name=[string](Get-EntryProperty $Entry 'Name' (Get-EntryProperty $Entry 'app_title' ''))
    $id=[string](Get-EntryProperty $Entry 'Id' (Get-EntryProperty $Entry 'app_name' ''))
    $combined="$name`n$id`n$([string](Get-EntryProperty $Entry 'Description' ''))`n$([string](Get-EntryProperty $Entry 'InstallPath' ''))`n$([string](Get-EntryProperty $Entry 'LaunchTarget' ''))";try{$combined+="`n"+($Entry|ConvertTo-Json -Depth 8 -Compress)}catch{}
    if($combined -match '(?im)^(Unreal Engine|Unreal Editor|Twinmotion|RealityCapture|MetaHuman|Quixel Bridge|Fab|Epic Online Services|Unreal Datasmith|Unreal Marketplace)\b'){return $false}
    if($combined -match '(?i)\b(UE_[45]\.[0-9]+|UnrealEditor|UE4Editor|Marketplace Asset|Engine Plugin|Editor Plugin|Asset Pack|Content Pack|Starter Content|Content Examples|Feature Pack|SDK|Mod Kit|Editor Symbols|Debug Symbols|Source Code|Marketplace Content|Engine Content|Plugin Content|Dev-Marketplace|Marketplace-Windows|UEFN|VaultCache)\b'){return $false}
    return $true
}

function Get-ProviderGames {
    param([string]$Provider,[switch]$InstalledOnly,[switch]$AvailableOnly)
    $node=Get-ProviderCatalogNode $Provider
    $items=New-Object System.Collections.ArrayList
    $byId=@{};$byName=@{}
    foreach($raw in @(Get-EntryProperty $node 'Games' @())){
        if(-not (Test-HcProviderGameVisible $raw $Provider)){continue}
        $entry=Convert-HcGameEntry $raw $Provider
        $entry.Provider=$Provider;$entry.Source=$Provider;$entry.ProviderGameId=[string](Get-EntryProperty $raw 'Id' $entry.ProviderGameId);$entry.ProviderInstalled=[bool](Get-EntryProperty $raw 'Installed' $false)
        Add-HcMergedGame $items $byId $byName $entry $Provider
    }
    $result=New-Object System.Collections.ArrayList
    foreach($game in @($items)){
        $installed=[bool](Get-EntryProperty $game 'Installed' $false)
        if($InstalledOnly -and -not $installed){continue}
        if($AvailableOnly -and $installed){continue}
        [void]$result.Add($game)
    }
    return [object[]]$result.ToArray()
}

function Convert-ProviderGameToLaunchEntry {
    param($Game)
    return Convert-HcGameEntry $Game ([string](Get-EntryProperty $Game 'Provider' ''))
}

function Get-PlatformGames {
    param([string]$Platform)
    $items=New-Object System.Collections.ArrayList;$byId=@{};$byName=@{}
    foreach($entry in @(Get-AllGameHubEntries|Where-Object{[string]::Equals([string](Get-EntryProperty $_ 'Source' 'Custom'),$Platform,[StringComparison]::OrdinalIgnoreCase)})){
        $local=Convert-HcGameEntry $entry $Platform
        $local.Installed=$true
        Add-HcMergedGame $items $byId $byName $local $Platform
    }
    if((Get-Command Test-DirectProviderPlatform -ErrorAction SilentlyContinue) -and (Test-DirectProviderPlatform $Platform)){
        foreach($providerGame in @(Get-ProviderGames $Platform -InstalledOnly)){Add-HcMergedGame $items $byId $byName $providerGame $Platform}
    }
    return [object[]]$items.ToArray()
}

function Get-PlatformLibraryGames {
    param([string]$Platform)
    $items=New-Object System.Collections.ArrayList;$byId=@{};$byName=@{}
    foreach($entry in @(Get-AllGameHubEntries|Where-Object{[string]::Equals([string](Get-EntryProperty $_ 'Source' 'Custom'),$Platform,[StringComparison]::OrdinalIgnoreCase)})){
        if(-not (Test-HcProviderGameVisible $entry $Platform)){continue}
        $local=Convert-HcGameEntry $entry $Platform;$local.Installed=$true
        Add-HcMergedGame $items $byId $byName $local $Platform
    }
    if((Get-Command Test-DirectProviderPlatform -ErrorAction SilentlyContinue) -and (Test-DirectProviderPlatform $Platform)){
        foreach($providerGame in @(Get-ProviderGames $Platform)){Add-HcMergedGame $items $byId $byName $providerGame $Platform}
    }
    return [object[]]$items.ToArray()
}

function Render-PlatformLibrary {
    $script:GameHubLaunchEntries=@()
    $all=@(Get-PlatformLibraryGames $script:SelectedGamePlatform|Sort-Object {[string](Get-EntryProperty $_ 'Name')})
    $heading=New-Object System.Windows.Controls.TextBlock
    $heading.Text="$($script:SelectedGamePlatform) Library"
    $heading.FontSize=28;$heading.FontWeight='Bold';$heading.Foreground='#F5F7FB';$heading.Margin='0,0,0,3'
    [void]$script:ActionPanel.Children.Add($heading)
    $sub=New-Object System.Windows.Controls.TextBlock
    $installedCount=@($all|Where-Object{[bool](Get-EntryProperty $_ 'Installed' $false)}).Count
    $sub.Text="$($all.Count) owned  •  $installedCount installed  •  Scroll vertically"
    $sub.FontSize=13;$sub.Foreground='#AAB7C9';$sub.Margin='0,0,0,16'
    [void]$script:ActionPanel.Children.Add($sub)
    if($all.Count -eq 0){
        $empty=New-Object System.Windows.Controls.Border;$empty.Height=150;$empty.CornerRadius=14;$empty.Background='#7A101827';$empty.BorderBrush='#2B3A51';$empty.BorderThickness=1
        $tb=New-Object System.Windows.Controls.TextBlock;$tb.Text="No $($script:SelectedGamePlatform) games are imported yet.";$tb.FontSize=17;$tb.Foreground='#AAB7C9';$tb.VerticalAlignment='Center';$tb.HorizontalAlignment='Center';$empty.Child=$tb
        [void]$script:ActionPanel.Children.Add($empty);return
    }
    $wrap=New-Object System.Windows.Controls.WrapPanel
    $wrap.Orientation='Horizontal';$wrap.HorizontalAlignment='Stretch';$wrap.Margin='0,0,0,28'
    $available=[double]$script:ActionScrollViewer.ActualWidth
    if($available -lt 700){$available=1720}
    $columns=[math]::Max(1,[math]::Floor(($available-12)/240.0))
    for($i=0;$i -lt $all.Count;$i++){
        $entry=$all[$i]
        $global=$script:GameHubLaunchEntries.Count
        $script:GameHubLaunchEntries+=$entry
        $button=New-HomeCard $entry "hub-game:$global" 'Library'
        $button.Width=198;$button.Height=286;$button.Margin='0,0,16,16'
        [void]$wrap.Children.Add($button)
        $script:ActionButtons+=$button
        $script:CurrentActions+=(New-Action "hub-game:$global" ([string](Get-EntryProperty $entry 'Name' 'Game')))
    }
    [void]$script:ActionPanel.Children.Add($wrap)
    for($start=0;$start -lt $all.Count;$start+=$columns){
        $count=[math]::Min($columns,$all.Count-$start)
        $script:HomeRows+=,[pscustomobject]@{Start=$start;Count=$count;Platform=$false;LibraryGrid=$true}
    }
}

function Get-HcSelectedGame {
    return $script:SelectedGameEntry
}

function Open-HcGameDetail {
    param($Entry,[switch]$PreserveReturn)
    if($null -eq $Entry){return}
    if(-not $PreserveReturn){
        $script:GameReturnSubPage=$script:SubPage
        $script:GameReturnAction=$script:SelectedAction
        try{$script:GameReturnScrollOffset=[double]$script:ActionScrollViewer.VerticalOffset}catch{$script:GameReturnScrollOffset=0}
    }
    $script:SelectedGameEntry=Convert-HcGameEntry $Entry $script:SelectedGamePlatform
    $script:SubPage='GameDetail';$script:SelectedAction=0;$script:NavigationLayer='Content'
    Render-Page
}

function New-HcDetailButton {
    param([string]$Id,[string]$TitleText,[string]$Subtitle='', [double]$Width=260,[switch]$Accent)
    $button=New-Object System.Windows.Controls.Button
    $button.Tag=$Id;$button.Width=$Width;$button.Height=92;$button.Margin='0,0,16,0';$button.Padding='16,12';$button.HorizontalContentAlignment='Stretch';$button.VerticalContentAlignment='Center';$button.RenderTransformOrigin='0.5,0.5';$button.Cursor='Hand'
    $button.Background=$(if($Accent){'#E8CF28'}else{'#CC151D2A'});$button.Foreground=$(if($Accent){'#111722'}else{'White'});$button.BorderBrush=$(if($Accent){'#FFF484'}else{'#41516A'});$button.BorderThickness='1'
    $button.Template=[Windows.Markup.XamlReader]::Parse('<ControlTemplate xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" TargetType="Button"><Border Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="14" Padding="{TemplateBinding Padding}"><ContentPresenter/></Border></ControlTemplate>')
    $stack=New-Object System.Windows.Controls.StackPanel
    $titleBlock=New-Object System.Windows.Controls.TextBlock;$titleBlock.Text=$TitleText;$titleBlock.FontSize=21;$titleBlock.FontWeight='Bold';$titleBlock.Foreground=$(if($Accent){'#10151E'}else{'White'});$stack.Children.Add($titleBlock)|Out-Null
    if($Subtitle){$sub=New-Object System.Windows.Controls.TextBlock;$sub.Text=$Subtitle;$sub.FontSize=11;$sub.Foreground=$(if($Accent){'#4D4A18'}else{'#AEBBD0'});$sub.Margin='0,5,0,0';$sub.TextTrimming='CharacterEllipsis';$stack.Children.Add($sub)|Out-Null}
    $button.Content=$stack
    $button.Add_Click({param($sender,$eventArgs)Set-KeyboardActive;Invoke-UiFeedback 'Confirm';Invoke-Action ([string]$sender.Tag)})
    $button.Add_MouseEnter({param($sender,$eventArgs)if(-not(Test-HcMouseHoverAllowed)){return};Set-KeyboardActive;$idx=[array]::IndexOf($script:ActionButtons,$sender);if($idx -ge 0){$script:SelectedAction=$idx;Update-ActionVisuals}})
    return $button
}

function Render-HcGameDetail {
    $game=Get-HcSelectedGame
    if($null -eq $game){
        $tb=New-Object System.Windows.Controls.TextBlock;$tb.Text='The selected game is no longer available.';$tb.FontSize=24;$tb.Foreground='White';$script:ActionPanel.Children.Add($tb)|Out-Null;return
    }
    $name=[string](Get-EntryProperty $game 'Name' 'Game')
    $provider=[string](Get-EntryProperty $game 'Provider' (Get-EntryProperty $game 'Source' $script:SelectedGamePlatform))
    $installed=[bool](Get-EntryProperty $game 'Installed' $false)
    $art=[string](Get-EntryProperty $game 'HeroArtworkPath' (Get-EntryProperty $game 'ArtworkPath' ''))

    $hero=New-Object System.Windows.Controls.Border
    $hero.Height=500;$hero.CornerRadius=18;$hero.ClipToBounds=$true;$hero.Background='#111821';$hero.BorderBrush='#35445A';$hero.BorderThickness='1';$hero.Margin='0,0,0,0'
    $heroGrid=New-Object System.Windows.Controls.Grid
    $source=Get-ImageSourceFromPath $art
    if($null -ne $source){$image=New-Object System.Windows.Controls.Image;$image.Source=$source;$image.Stretch='UniformToFill';$image.Opacity=.78;$heroGrid.Children.Add($image)|Out-Null}
    else{$fallback=New-Object System.Windows.Shapes.Rectangle;$brush=New-Object System.Windows.Media.LinearGradientBrush;$brush.StartPoint='0,0';$brush.EndPoint='1,1';$brush.GradientStops.Add((New-Object System.Windows.Media.GradientStop -ArgumentList ([System.Windows.Media.ColorConverter]::ConvertFromString('#293B5C')),0));$brush.GradientStops.Add((New-Object System.Windows.Media.GradientStop -ArgumentList ([System.Windows.Media.ColorConverter]::ConvertFromString('#070B12')),1));$fallback.Fill=$brush;$heroGrid.Children.Add($fallback)|Out-Null}
    $shade=New-Object System.Windows.Shapes.Rectangle;$shadeBrush=New-Object System.Windows.Media.LinearGradientBrush;$shadeBrush.StartPoint='0,0';$shadeBrush.EndPoint='0,1';$shadeBrush.GradientStops.Add((New-Object System.Windows.Media.GradientStop -ArgumentList ([System.Windows.Media.ColorConverter]::ConvertFromString('#17000000')),0));$shadeBrush.GradientStops.Add((New-Object System.Windows.Media.GradientStop -ArgumentList ([System.Windows.Media.ColorConverter]::ConvertFromString('#E9000000')),1));$shade.Fill=$shadeBrush;$heroGrid.Children.Add($shade)|Out-Null
    $providerBadge=New-Object System.Windows.Controls.Border;$providerBadge.HorizontalAlignment='Left';$providerBadge.VerticalAlignment='Top';$providerBadge.Margin='22';$providerBadge.Padding='14,8';$providerBadge.CornerRadius=10;$providerBadge.Background='#C8000000';$providerBadge.BorderBrush='#55FFFFFF';$providerBadge.BorderThickness='1'
    $providerText=New-Object System.Windows.Controls.TextBlock;$providerText.Text=$provider.ToUpperInvariant();$providerText.FontSize=12;$providerText.FontWeight='Bold';$providerText.Foreground='#F2D36B';$providerBadge.Child=$providerText;$heroGrid.Children.Add($providerBadge)|Out-Null
    $titleStack=New-Object System.Windows.Controls.StackPanel;$titleStack.VerticalAlignment='Bottom';$titleStack.HorizontalAlignment='Center';$titleStack.Margin='42,0,42,34'
    $title=New-Object System.Windows.Controls.TextBlock;$title.Text=$name;$title.FontSize=40;$title.FontWeight='Bold';$title.Foreground='White';$title.TextAlignment='Center';$title.TextWrapping='Wrap';$title.Effect=New-Object System.Windows.Media.Effects.DropShadowEffect -Property @{BlurRadius=10;ShadowDepth=2;Opacity=.8};$titleStack.Children.Add($title)|Out-Null
    $status=New-Object System.Windows.Controls.TextBlock;$status.Text=$(if($installed){'INSTALLED'}else{'AVAILABLE TO INSTALL'});$status.FontSize=12;$status.FontWeight='Bold';$status.Foreground='#E7C45E';$status.HorizontalAlignment='Center';$status.Margin='0,9,0,0';$titleStack.Children.Add($status)|Out-Null
    $heroGrid.Children.Add($titleStack)|Out-Null;$hero.Child=$heroGrid;$script:ActionPanel.Children.Add($hero)|Out-Null

    $panel=New-Object System.Windows.Controls.Border;$panel.Background='#E60D131C';$panel.BorderBrush='#3D4D64';$panel.BorderThickness='1';$panel.CornerRadius='0,0,18,18';$panel.Padding='22,18';$panel.Margin='0,-1,0,22'
    $panelGrid=New-Object System.Windows.Controls.Grid;$panelGrid.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition -Property @{Width='Auto'}));$panelGrid.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition -Property @{Width='*'}));$panelGrid.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition -Property @{Width='Auto'}))
    $primary=New-HcDetailButton $(if($installed){'game-primary-play'}else{'game-primary-install'}) $(if($installed){'▶  Play'}else{'↓  Install'}) $(if($installed){'Start the game'}else{'Choose a drive and install'}) 290 -Accent
    $primaryLabel=if($installed){'Play'}else{'Install'}
    $panelGrid.Children.Add($primary)|Out-Null;$script:ActionButtons+=$primary;$script:CurrentActions+=(New-Action ([string]$primary.Tag) $primaryLabel)
    $meta=New-Object System.Windows.Controls.StackPanel;$meta.Orientation='Horizontal';$meta.VerticalAlignment='Center';$meta.Margin='26,0,22,0';[System.Windows.Controls.Grid]::SetColumn($meta,1)
    $playtime=[double](Get-EntryProperty $game 'PlaytimeMinutes' 0);$playText=if($playtime -gt 0){if($playtime -ge 60){'{0:N1} hours' -f ($playtime/60)}else{"$([int]$playtime) minutes"}}else{'Not tracked'}
    foreach($pair in @(@('PLAY TIME',$playText),@('SOURCE',$provider),@('STATUS',$(if($installed){'Ready'}else{'Not installed'})))){
        $cell=New-Object System.Windows.Controls.StackPanel;$cell.Margin='0,0,34,0';$label=New-Object System.Windows.Controls.TextBlock;$label.Text=$pair[0];$label.FontSize=11;$label.FontWeight='Bold';$label.Foreground='#AAB7C9';$cell.Children.Add($label)|Out-Null;$value=New-Object System.Windows.Controls.TextBlock;$value.Text=$pair[1];$value.FontSize=17;$value.FontWeight='SemiBold';$value.Foreground='White';$value.Margin='0,5,0,0';$cell.Children.Add($value)|Out-Null;$meta.Children.Add($cell)|Out-Null
    }
    $panelGrid.Children.Add($meta)|Out-Null
    $manage=New-HcDetailButton 'game-open-settings' '⚙  Manage' 'Game options' 170
    [System.Windows.Controls.Grid]::SetColumn($manage,2);$panelGrid.Children.Add($manage)|Out-Null;$script:ActionButtons+=$manage;$script:CurrentActions+=(New-Action 'game-open-settings' 'Manage')
    $panel.Child=$panelGrid;$script:ActionPanel.Children.Add($panel)|Out-Null
    $script:HomeRows+=,[pscustomobject]@{Start=0;Count=2;Platform=$false;GameDetail=$true}

    $description=[string](Get-EntryProperty $game 'Description' '')
    if($description){$desc=New-Object System.Windows.Controls.TextBlock;$desc.Text=$description;$desc.FontSize=15;$desc.Foreground='#C7D0DE';$desc.TextWrapping='Wrap';$desc.LineHeight=24;$desc.Margin='8,0,8,28';$script:ActionPanel.Children.Add($desc)|Out-Null}
}

function New-HcPropertyButton {
    param([string]$Id,[string]$TitleText,[string]$Subtitle='')
    $button=New-Object System.Windows.Controls.Button;$button.Tag=$Id;$button.Style=$script:Window.FindResource('ActionButtonStyle');$button.MinHeight=78;$button.Margin='0,0,0,10';$button.HorizontalContentAlignment='Stretch'
    $stack=New-Object System.Windows.Controls.StackPanel;$titleBlock=New-Object System.Windows.Controls.TextBlock;$titleBlock.Text=$TitleText;$titleBlock.FontSize=17;$titleBlock.FontWeight='SemiBold';$titleBlock.Foreground='White';$stack.Children.Add($titleBlock)|Out-Null
    if($Subtitle){$sub=New-Object System.Windows.Controls.TextBlock;$sub.Text=$Subtitle;$sub.FontSize=12;$sub.Foreground='#AEBBD0';$sub.Margin='0,5,0,0';$sub.TextWrapping='Wrap';$stack.Children.Add($sub)|Out-Null}
    $button.Content=$stack;$button.Add_Click({param($sender,$eventArgs)Invoke-UiFeedback 'Confirm';Invoke-Action ([string]$sender.Tag)});$button.Add_MouseEnter({param($sender,$eventArgs)if(-not(Test-HcMouseHoverAllowed)){return};Set-KeyboardActive;$idx=[array]::IndexOf($script:ActionButtons,$sender);if($idx -ge 0){$script:SelectedAction=$idx;Update-ActionVisuals}})
    return $button
}

function Add-HcPropertyAction {
    param($Panel,[string]$Id,[string]$Title,[string]$Subtitle='')
    $button=New-HcPropertyButton $Id $Title $Subtitle;$Panel.Children.Add($button)|Out-Null;$script:ActionButtons+=$button;$script:CurrentActions+=(New-Action $Id $Title $Subtitle)
}

function Render-HcGameProperties {
    $game=Get-HcSelectedGame;if($null -eq $game){return}
    $name=[string](Get-EntryProperty $game 'Name' 'Game');$installed=[bool](Get-EntryProperty $game 'Installed' $false);$provider=[string](Get-EntryProperty $game 'Provider' (Get-EntryProperty $game 'Source' 'Game'))
    $outer=New-Object System.Windows.Controls.Grid;$outer.MinHeight=680;$outer.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition -Property @{Width='320'}));$outer.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition -Property @{Width='*'}))
    $left=New-Object System.Windows.Controls.Border;$left.Background='#E830343A';$left.Padding='26,22';$left.Margin='0,0,16,0';$left.CornerRadius=16
    $leftStack=New-Object System.Windows.Controls.StackPanel;$gameTitle=New-Object System.Windows.Controls.TextBlock;$gameTitle.Text=$name;$gameTitle.FontSize=24;$gameTitle.FontWeight='Bold';$gameTitle.Foreground='White';$gameTitle.TextWrapping='Wrap';$gameTitle.Margin='0,0,0,18';$leftStack.Children.Add($gameTitle)|Out-Null
    $categories=@('General','Updates','Installed Files','Game Versions & Betas','Controller','DLC / Add-ons','Privacy','Customization')
    for($i=0;$i -lt $categories.Count;$i++){
        $category=$categories[$i];$button=New-Object System.Windows.Controls.Button;$button.Tag="game-prop-category:$category";$button.Height=56;$button.Margin='0,0,0,4';$button.Padding='14,8';$button.HorizontalContentAlignment='Left';$button.Content=$category;$button.FontSize=16;$button.Foreground='White';$button.Background=$(if($category -eq $script:GamePropertiesCategory){'#315C78'}else{'#00333A44'});$button.BorderThickness='0';$button.Cursor='Hand'
        $button.Template=[Windows.Markup.XamlReader]::Parse('<ControlTemplate xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" TargetType="Button"><Border Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="8" Padding="{TemplateBinding Padding}"><ContentPresenter HorizontalAlignment="{TemplateBinding HorizontalContentAlignment}" VerticalAlignment="Center"/></Border></ControlTemplate>')
        $button.Add_Click({param($sender,$eventArgs)Invoke-UiFeedback 'Confirm';Invoke-Action ([string]$sender.Tag)});$button.Add_MouseEnter({param($sender,$eventArgs)if(-not(Test-HcMouseHoverAllowed)){return};Set-KeyboardActive;$idx=[array]::IndexOf($script:ActionButtons,$sender);if($idx -ge 0){$script:SelectedAction=$idx;Update-ActionVisuals}})
        $leftStack.Children.Add($button)|Out-Null;$script:ActionButtons+=$button;$script:CurrentActions+=(New-Action ([string]$button.Tag) $category)
    }
    $left.Child=$leftStack;$outer.Children.Add($left)|Out-Null
    $right=New-Object System.Windows.Controls.Border;$right.Background='#DD20242A';$right.Padding='32,28';$right.CornerRadius=16;[System.Windows.Controls.Grid]::SetColumn($right,1)
    $rightScroll=New-Object System.Windows.Controls.ScrollViewer;$rightScroll.VerticalScrollBarVisibility='Hidden';$rightScroll.HorizontalScrollBarVisibility='Disabled';$rightScroll.PanningMode='VerticalOnly'
    $content=New-Object System.Windows.Controls.StackPanel;$heading=New-Object System.Windows.Controls.TextBlock;$heading.Text=$script:GamePropertiesCategory;$heading.FontSize=30;$heading.FontWeight='Bold';$heading.Foreground='White';$heading.Margin='0,0,0,22';$content.Children.Add($heading)|Out-Null
    $path=[string](Get-EntryProperty $game 'InstallPath' (Get-EntryProperty $game 'Path' ''));$size=[string](Get-EntryProperty $game 'SizeText' '')
    switch($script:GamePropertiesCategory){
        'General' {
            Add-HcPropertyAction $content 'noop' "Provider: $provider" $(if($installed){'Installed and available to launch.'}else{'Owned but not installed.'})
            Add-HcPropertyAction $content 'game-toggle-favorite' $(if(Test-HcGameFavorite $game){'Remove from Favorites'}else{'Add to Favorites'}) 'Favorites are available across platform views.'
            Add-HcPropertyAction $content 'game-launch-options' 'Launch options' 'Enter per-game command-line arguments for supported local games.'
        }
        'Updates' {
            if($installed -and $provider -and $provider -ne 'HES'){Add-HcPropertyAction $content 'game-update' 'Check / Apply Update' 'Use the native provider backend.'}
            else{Add-HcPropertyAction $content 'noop' 'Updates are managed by the source platform' 'No native update action is available for this title.'}
        }
        'Installed Files' {
            if($installed){
                Add-HcPropertyAction $content 'noop' $(if($size){"Installed size: $size"}else{'Installed files'}) $(if($path){$path}else{'Install location unavailable.'})
                if($path){Add-HcPropertyAction $content 'game-browse-files' 'Browse local files' $path}
                if($provider -and $provider -ne 'HES'){Add-HcPropertyAction $content 'game-verify' 'Verify integrity / Repair' 'Checks local files and repairs missing or changed content.';if(Test-HcProviderSupportsMove $provider){Add-HcPropertyAction $content 'game-move' 'Move install folder' 'Choose another drive or configured library location.'};Add-HcPropertyAction $content 'game-uninstall' 'Uninstall' 'Remove the installed game after confirmation.'}
            }else{
                Add-HcPropertyAction $content 'game-primary-install' 'Install' $(if($size){"Download size: $size"}else{'Choose a destination and begin installation.'})
                Add-HcPropertyAction $content 'game-install-location' 'Choose install location' (Get-ProviderInstallRoot $provider)
            }
        }
        'Game Versions & Betas' { Add-HcPropertyAction $content 'noop' 'Default release channel' 'Alternate versions appear here when supplied by the provider.' }
        'Controller' { Add-HcPropertyAction $content 'noop' 'Use console controller defaults' 'Per-game controller overrides appear here when the provider exposes them.' }
        'DLC / Add-ons' { Add-HcPropertyAction $content 'noop' 'Owned add-ons' 'DLC and add-on details appear here when supplied by the platform.' }
        'Privacy' { Add-HcPropertyAction $content 'noop' 'Game visibility' 'Privacy controls appear here when supported by the source platform.' }
        'Customization' { Add-HcPropertyAction $content 'game-toggle-favorite' $(if(Test-HcGameFavorite $game){'Remove from Favorites'}else{'Add to Favorites'}) 'Customize how this game appears in Huymaier Console.' }
    }
    $back=New-HcPropertyButton 'game-properties-back' 'Back to game' 'Return to the game detail page.';$back.Margin='0,18,0,0';$content.Children.Add($back)|Out-Null;$script:ActionButtons+=$back;$script:CurrentActions+=(New-Action 'game-properties-back' 'Back to game')
    $rightScroll.Content=$content;$right.Child=$rightScroll;$outer.Children.Add($right)|Out-Null;$script:ActionPanel.Children.Add($outer)|Out-Null
}

function Render-GamesHub {
    $script:GameHubPlatforms=Get-GameHubPlatforms
    if($script:GameHubPlatforms.Count -eq 0){$script:GameHubPlatforms=@('Steam')}
    if(-not (@($script:GameHubPlatforms)|Where-Object{[string]::Equals([string]$_,$script:SelectedGamePlatform,[StringComparison]::OrdinalIgnoreCase)})){$script:SelectedGamePlatform=[string]$script:GameHubPlatforms[0]}
    $script:GameHubLaunchEntries=@()
    switch($script:SubPage){
        'PlatformChoice' { Add-PlatformChoiceRail }
        'PlatformHome' { Render-PlatformHome }
        'PlatformShelf' { Render-PlatformShelf }
        'PlatformLibrary' { Render-PlatformLibrary }
        'ProviderStore' { Render-GameProviderStore $script:SelectedGamePlatform }
        'GameDetail' { Render-HcGameDetail }
        'GameProperties' { Render-HcGameProperties }
        default { Add-PlatformRail }
    }
}

function Use-HorizontalRailNavigation {
    if($script:SelectedTab -eq 0 -and -not $script:SubPage){return $true}
    if($script:SelectedTab -eq 1 -and $script:SubPage -in @('','PlatformChoice','PlatformHome','PlatformShelf','PlatformLibrary','GameDetail')){return $true}
    if($script:SelectedTab -eq 2 -and -not $script:SubPage){return $true}
    return $false
}

function Get-HcFavoriteKey {
    param($Game)
    $key=Get-HcCanonicalGameId $Game ([string](Get-EntryProperty $Game 'Source' $script:SelectedGamePlatform))
    if(-not $key){$key=(Get-HcNormalizedName ([string](Get-EntryProperty $Game 'Name' 'Game')))}
    return $key
}

function Test-HcGameFavorite {
    param($Game)
    $key=Get-HcFavoriteKey $Game
    return @($script:Config.FavoriteGames) -contains $key
}

function Toggle-HcGameFavorite {
    param($Game)
    $key=Get-HcFavoriteKey $Game;if(-not $key){return}
    $list=New-Object System.Collections.ArrayList;$found=$false
    foreach($item in @($script:Config.FavoriteGames)){if([string]::Equals([string]$item,$key,[StringComparison]::OrdinalIgnoreCase)){$found=$true}else{[void]$list.Add([string]$item)}}
    if(-not $found){[void]$list.Add($key)}
    $script:Config.FavoriteGames=[object[]]$list.ToArray();Save-Config
    Set-ConsoleNotice $(if($found){'Removed from Favorites.'}else{'Added to Favorites.'}) 'INFO'
}

function Get-HcActualProviderGame {
    param($Entry)
    $provider=[string](Get-EntryProperty $Entry 'Provider' '')
    $id=[string](Get-EntryProperty $Entry 'ProviderGameId' (Get-EntryProperty $Entry 'Id' ''))
    if($provider -and $id){
        $match=@(Get-ProviderGames $provider|Where-Object{[string]::Equals([string](Get-EntryProperty $_ 'Id' ''),$id,[StringComparison]::OrdinalIgnoreCase)}|Select-Object -First 1)
        if($match.Count -gt 0){return Merge-HcGameEntry $match[0] $Entry $provider}
    }
    return Convert-HcGameEntry $Entry $provider
}

function Invoke-HcGamePlay {
    $game=Get-HcSelectedGame;if($null -eq $game){return}
    $entry=Convert-HcGameEntry $game $script:SelectedGamePlatform
    Add-ToRecent 'Game' $entry
    $target=[string](Get-EntryProperty $entry 'LaunchTarget' '')
    if($target){
        if((Get-Command Invoke-ProviderGameLaunchEntry -ErrorAction SilentlyContinue) -and [string](Get-EntryProperty $entry 'Provider' '') -and -not (Test-Path -LiteralPath $target -PathType Leaf)){
            if(Invoke-ProviderGameLaunchEntry $entry){return}
        }
        Start-RecentEntry $entry;return
    }
    if((Get-Command Invoke-ProviderGameLaunchEntry -ErrorAction SilentlyContinue) -and (Invoke-ProviderGameLaunchEntry $entry)){return}
    Set-ConsoleNotice 'No launch target is available for this game.' 'WARN';Render-Page
}

function Get-HcGameProviderAndId {
    $game=Get-HcSelectedGame
    return [pscustomobject]@{Game=$game;Provider=[string](Get-EntryProperty $game 'Provider' '');Id=[string](Get-EntryProperty $game 'ProviderGameId' (Get-EntryProperty $game 'Id' ''));Name=[string](Get-EntryProperty $game 'Name' 'Game')}
}


function Test-HcProviderSupportsMove {
    param([string]$Provider)
    return $Provider -in @('Epic','GOG')
}

function Get-HcDriveDestinations {
    param([string]$Provider)
    $items=New-Object System.Collections.ArrayList
    $seen=@{}
    $game=Get-HcSelectedGame
    $required=0.0
    try{$required=[double](Get-EntryProperty $game 'InstallSizeBytes' 0)}catch{$required=0.0}
    $configured=if($Provider){Get-ProviderInstallRoot $Provider}else{''}
    $installedPath=[string](Get-EntryProperty $game 'InstallPath' (Get-EntryProperty $game 'Path' ''))
    $installedRoot=''
    try{if($installedPath){$installedRoot=[IO.Path]::GetPathRoot($installedPath)}}catch{}
    $labels=@{}
    try{foreach($disk in @(Get-CimInstance Win32_LogicalDisk -Filter 'DriveType=3' -ErrorAction SilentlyContinue)){if($disk.DeviceID){$labels[[string]$disk.DeviceID]=[string]$disk.VolumeName}}}catch{}

    $candidates=New-Object System.Collections.ArrayList
    if($configured){[void]$candidates.Add($configured)}
    foreach($drive in @(Get-PSDrive -PSProvider FileSystem -ErrorAction SilentlyContinue|Where-Object{$_.Root -and $null -ne $_.Free}|Sort-Object Name)){
        $root=[string]$drive.Root
        $path=if($Provider){Join-Path $root (Join-Path 'Games' $Provider)}else{$root}
        [void]$candidates.Add($path)
    }

    foreach($pathValue in @($candidates)){
        $path=[string]$pathValue
        if([string]::IsNullOrWhiteSpace($path)){continue}
        try{$full=[IO.Path]::GetFullPath($path).TrimEnd('\\')}catch{$full=$path.TrimEnd('\\')}
        $key=$full.ToLowerInvariant()
        if($seen.ContainsKey($key)){continue}
        $seen[$key]=$true
        $root='';try{$root=[IO.Path]::GetPathRoot($full)}catch{}
        $device=if($root){$root.TrimEnd('\\')}else{$full}
        $label=$labels[$device];if(-not $label){$label='Local Drive'}
        $free=0.0
        try{$driveInfo=[IO.DriveInfo]::new($root);$free=[double]$driveInfo.AvailableFreeSpace}catch{
            try{$driveName=$device.TrimEnd(':');$psDrive=Get-PSDrive -Name $driveName -PSProvider FileSystem -ErrorAction Stop;$free=[double]$psDrive.Free}catch{$free=0.0}
        }
        $freeText=if($free -ge 1TB){'{0:N1} TB available' -f ($free/1TB)}else{'{0:N1} GB available' -f ($free/1GB)}
        $current=$false
        if($installedPath){
            try{$current=$installedPath.StartsWith($full,[StringComparison]::OrdinalIgnoreCase)}catch{$current=$false}
            if(-not $current -and $installedRoot -and $root){$current=[string]::Equals($installedRoot,$root,[StringComparison]::OrdinalIgnoreCase) -and [string]::Equals($full,$configured.TrimEnd('\\'),[StringComparison]::OrdinalIgnoreCase)}
        }elseif($configured){$current=[string]::Equals($full,$configured.TrimEnd('\\'),[StringComparison]::OrdinalIgnoreCase)}
        $enough=($required -le 0 -or $free -ge $required)
        $enabled=$enough
        if($script:GameModalLocationPurpose -eq 'Move' -and $current){$enabled=$false}
        $subtitle="$full  •  $freeText"
        if(-not $enough){$subtitle="$full  •  $freeText  •  Not enough space"}
        elseif($current){$subtitle="$full  •  $freeText  •  Current location"}
        [void]$items.Add([pscustomobject]@{Path=$full;Title="$label ($device)";Subtitle=$subtitle;Current=$current;Enabled=$enabled;FreeBytes=$free})
    }
    return [object[]]$items.ToArray()
}

function New-HcModalButton {
    param($Entry,[int]$Index)
    $button=New-Object System.Windows.Controls.Button;$button.Tag=$Index;$button.MinHeight=68;$button.Margin='0,0,0,8';$button.Padding='16,12';$button.HorizontalContentAlignment='Stretch';$button.Background='#050505';$button.Foreground='White';$button.BorderBrush='#242424';$button.BorderThickness='1';$button.Cursor='Hand';$button.IsEnabled=[bool](Get-EntryProperty $Entry 'Enabled' $true)
    $button.Template=[Windows.Markup.XamlReader]::Parse('<ControlTemplate xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" TargetType="Button"><Border Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="10" Padding="{TemplateBinding Padding}"><ContentPresenter HorizontalAlignment="{TemplateBinding HorizontalContentAlignment}" VerticalAlignment="Center"/></Border></ControlTemplate>')
    $stack=New-Object System.Windows.Controls.StackPanel;$title=New-Object System.Windows.Controls.TextBlock;$title.Text=[string](Get-EntryProperty $Entry 'Title' 'Option');$title.FontSize=18;$title.FontWeight='SemiBold';$title.Foreground='White';$stack.Children.Add($title)|Out-Null
    $subtitle=[string](Get-EntryProperty $Entry 'Subtitle' '');if($subtitle){$sub=New-Object System.Windows.Controls.TextBlock;$sub.Text=$subtitle;$sub.FontSize=12;$sub.Foreground='#AAB7C9';$sub.Margin='0,4,0,0';$sub.TextWrapping='Wrap';$stack.Children.Add($sub)|Out-Null}
    $button.Content=$stack
    $button.Add_Click({param($sender,$eventArgs)$script:GameModalSelected=[int]$sender.Tag;Update-HcGameModalVisuals;Invoke-HcGameModalSelected})
    $button.Add_MouseEnter({param($sender,$eventArgs)if(-not(Test-HcMouseHoverAllowed)){return};$script:GameModalSelected=[int]$sender.Tag;Update-HcGameModalVisuals})
    return $button
}

function Show-HcGameModal {
    param([string]$Mode)
    if($null -eq $script:GameModalOverlay){return}
    $game=Get-HcSelectedGame;if($null -eq $game){return}
    $installed=[bool](Get-EntryProperty $game 'Installed' $false);$provider=[string](Get-EntryProperty $game 'Provider' (Get-EntryProperty $game 'Source' ''))
    $entries=New-Object System.Collections.ArrayList;$title='Game Options';$subtitle=[string](Get-EntryProperty $game 'Name' 'Game')
    switch($Mode){
        'Settings' {
            $title=$subtitle
            [void]$entries.Add([pscustomobject]@{Id='modal-favorite';Title=$(if(Test-HcGameFavorite $game){'Remove from Favorites'}else{'Add to Favorites'});Subtitle='Pin this game across Huymaier Console.';Enabled=$true})
            [void]$entries.Add([pscustomobject]@{Id='modal-addto';Title='Add to';Subtitle='Collections and Favorites';Enabled=$true})
            [void]$entries.Add([pscustomobject]@{Id='modal-manage';Title='Manage  ›';Subtitle='Install, uninstall, move, verify, and browse files.';Enabled=$true})
            [void]$entries.Add([pscustomobject]@{Id='modal-properties';Title='Properties…';Subtitle='Open full game settings.';Enabled=$true})
            [void]$entries.Add([pscustomobject]@{Id='modal-cancel';Title='Cancel';Subtitle='';Enabled=$true})
        }
        'Manage' {
            $title='Manage';$subtitle=[string](Get-EntryProperty $game 'Name' 'Game')
            if($installed){
                [void]$entries.Add([pscustomobject]@{Id='game-play';Title='Play';Subtitle='Launch this game.';Enabled=$true})
                if($provider -and $provider -ne 'HES'){
                    [void]$entries.Add([pscustomobject]@{Id='game-update';Title='Check / Apply Update';Subtitle='Update through the native provider backend.';Enabled=$true})
                    [void]$entries.Add([pscustomobject]@{Id='game-verify';Title='Verify integrity / Repair';Subtitle='Repair missing or changed files.';Enabled=$true})
                    if(Test-HcProviderSupportsMove $provider){[void]$entries.Add([pscustomobject]@{Id='game-move';Title='Move install folder';Subtitle='Choose another drive or game library.';Enabled=$true})}
                }
                $path=[string](Get-EntryProperty $game 'InstallPath' (Get-EntryProperty $game 'Path' ''));if($path){[void]$entries.Add([pscustomobject]@{Id='game-browse-files';Title='Browse local files';Subtitle=$path;Enabled=$true})}
                if($provider -and $provider -ne 'HES'){[void]$entries.Add([pscustomobject]@{Id='game-uninstall';Title='Uninstall';Subtitle='Remove this installation.';Enabled=$true})}
            }else{
                [void]$entries.Add([pscustomobject]@{Id='game-primary-install';Title='Install';Subtitle='Choose a drive and begin installation.';Enabled=([bool]$provider)})
                [void]$entries.Add([pscustomobject]@{Id='game-install-location';Title='Choose install location';Subtitle=$(if($provider){Get-ProviderInstallRoot $provider}else{'No native provider available.'});Enabled=([bool]$provider)})
            }
            [void]$entries.Add([pscustomobject]@{Id='modal-settings-back';Title='Back';Subtitle='Return to game options.';Enabled=$true})
        }
        'AddTo' {
            $title='Add to';$subtitle=[string](Get-EntryProperty $game 'Name' 'Game')
            [void]$entries.Add([pscustomobject]@{Id='modal-favorite';Title=$(if(Test-HcGameFavorite $game){'Remove from Favorites'}else{'Favorites'});Subtitle='Toggle this game in Favorites.';Enabled=$true})
            [void]$entries.Add([pscustomobject]@{Id='modal-settings-back';Title='Back';Subtitle='Return to game options.';Enabled=$true})
        }
        'InstallLocation' {
            $title='Install Game';$subtitle="Select where $([string](Get-EntryProperty $game 'Name' 'Game')) should be installed."
            $script:GameModalDestinations=@(Get-HcDriveDestinations $provider);$script:GameModalLocationPurpose='Install'
            for($i=0;$i -lt $script:GameModalDestinations.Count;$i++){$d=$script:GameModalDestinations[$i];[void]$entries.Add([pscustomobject]@{Id="game-destination:$i";Title=$(if([bool]$d.Current){'✓  '+$d.Title}else{$d.Title});Subtitle=$d.Subtitle;Enabled=$d.Enabled})}
            [void]$entries.Add([pscustomobject]@{Id='modal-manage-back';Title='Cancel';Subtitle='Return to Manage.';Enabled=$true})
        }
        'MoveConfirm' {
            $title='Move Content';$size=[string](Get-EntryProperty $game 'SizeText' '');$subtitle="Select where $([string](Get-EntryProperty $game 'Name' 'Game'))$(if($size){" ($size)"}) should be moved."
            $chosen=$script:GameModalSelectedDestination
            [void]$entries.Add([pscustomobject]@{Id='game-move-target';Title=$(if($null -ne $chosen){[string]$chosen.Title}else{'Choose target drive / library'});Subtitle=$(if($null -ne $chosen){[string]$chosen.Subtitle}else{'Shows configured libraries and available free space.'});Enabled=$true})
            [void]$entries.Add([pscustomobject]@{Id='game-move-confirm';Title='Move';Subtitle='Begin moving the installed game.';Enabled=($null -ne $chosen -and [bool]$chosen.Enabled)})
            [void]$entries.Add([pscustomobject]@{Id='modal-manage-back';Title='Cancel';Subtitle='Return to Manage.';Enabled=$true})
        }
        'MoveLocation' {
            $title='Select Target Location';$size=[string](Get-EntryProperty $game 'SizeText' '');$subtitle="Choose the destination for $([string](Get-EntryProperty $game 'Name' 'Game'))$(if($size){" ($size)"})."
            $script:GameModalLocationPurpose='Move';$script:GameModalDestinations=@(Get-HcDriveDestinations $provider)
            for($i=0;$i -lt $script:GameModalDestinations.Count;$i++){$d=$script:GameModalDestinations[$i];[void]$entries.Add([pscustomobject]@{Id="game-destination:$i";Title=$(if([bool]$d.Current){'✓  '+$d.Title}else{$d.Title});Subtitle=$d.Subtitle;Enabled=$d.Enabled})}
            [void]$entries.Add([pscustomobject]@{Id='modal-move-confirm-back';Title='Cancel';Subtitle='Return to Move Content.';Enabled=$true})
        }
    }
    $script:GameModalMode=$Mode;$script:GameModalEntries=[object[]]$entries.ToArray();$script:GameModalSelected=0;$script:GameModalButtons=@()
    for($first=0;$first -lt $script:GameModalEntries.Count;$first++){if([bool](Get-EntryProperty $script:GameModalEntries[$first] 'Enabled' $true)){$script:GameModalSelected=$first;break}}
    $script:GameModalTitle.Text=$title;$script:GameModalSubtitle.Text=$subtitle;$script:GameModalPanel.Children.Clear()
    for($i=0;$i -lt $script:GameModalEntries.Count;$i++){$button=New-HcModalButton $script:GameModalEntries[$i] $i;$script:GameModalPanel.Children.Add($button)|Out-Null;$script:GameModalButtons+=$button}
    $script:GameModalOverlay.Visibility='Visible';Set-HcShellBlur $true;Update-HcGameModalVisuals
}

function Close-HcGameModal {
    if($null -ne $script:GameModalOverlay){$script:GameModalOverlay.Visibility='Collapsed'}
    if(-not (Test-HcMainMenuVisible)){Set-HcShellBlur $false}
    $script:GameModalMode='';$script:GameModalButtons=@();$script:GameModalEntries=@();$script:GameModalSelected=0
    Update-ActionVisuals
}

function Test-HcGameModalVisible {
    return ($null -ne $script:GameModalOverlay -and $script:GameModalOverlay.Visibility -eq 'Visible')
}

function Update-HcGameModalVisuals {
    for($i=0;$i -lt $script:GameModalButtons.Count;$i++){
        $button=$script:GameModalButtons[$i]
        if(-not $button.IsEnabled){$button.Opacity=.35;continue}
        if($i -eq $script:GameModalSelected){$button.Background='#D8CD75';$button.BorderBrush='#FFF3A8';$button.Foreground='#111722';try{$button.Content.Children[0].Foreground='#111722';if($button.Content.Children.Count -gt 1){$button.Content.Children[1].Foreground='#4D4A18'}}catch{}}
        else{$button.Background='#050505';$button.BorderBrush='#242424';$button.Foreground='White';$button.Opacity=1;try{$button.Content.Children[0].Foreground='White';if($button.Content.Children.Count -gt 1){$button.Content.Children[1].Foreground='#AAB7C9'}}catch{}}
    }
    try{$script:GameModalButtons[$script:GameModalSelected].BringIntoView()}catch{}
}

function Move-HcGameModalSelection {
    param([int]$Delta)
    if($script:GameModalButtons.Count -eq 0){return}
    $next=$script:GameModalSelected
    do{$next+=$Delta;if($next -lt 0){$next=$script:GameModalButtons.Count-1};if($next -ge $script:GameModalButtons.Count){$next=0}}while(-not $script:GameModalButtons[$next].IsEnabled -and $next -ne $script:GameModalSelected)
    if($next -ne $script:GameModalSelected){$script:GameModalSelected=$next;Invoke-UiFeedback 'Navigate';Update-HcGameModalVisuals}
}

function Invoke-HcProviderOperation {
    param([string]$Mode,[string]$InstallPath='')
    $info=Get-HcGameProviderAndId
    if(-not $info.Provider -or -not $info.Id){Set-ConsoleNotice 'This game is not connected to a native provider operation.' 'WARN';return}
    $script:SelectedProviderGame=Get-HcActualProviderGame $info.Game
    if(-not $InstallPath){$InstallPath=[string](Get-EntryProperty $info.Game 'InstallPath' (Get-ProviderInstallRoot $info.Provider))}
    Start-GameProviderWorker $Mode $info.Provider $info.Id $info.Name $InstallPath
    if($Mode -in @('Install','Update','Verify','Move','Uninstall')){Set-Tab 4}
}

function Invoke-HcGameModalSelected {
    if($script:GameModalSelected -lt 0 -or $script:GameModalSelected -ge $script:GameModalEntries.Count){return}
    $entry=$script:GameModalEntries[$script:GameModalSelected];if(-not [bool](Get-EntryProperty $entry 'Enabled' $true)){return}
    $id=[string](Get-EntryProperty $entry 'Id' '')
    Invoke-UiFeedback 'Confirm'
    switch -Regex($id){
        '^game-destination:(\d+)$' {
            $index=[int]$matches[1];if($index -lt 0 -or $index -ge $script:GameModalDestinations.Count){return}
            $destination=$script:GameModalDestinations[$index];$path=[string]$destination.Path;$info=Get-HcGameProviderAndId
            if($script:GameModalLocationPurpose -eq 'Move'){
                $script:GameModalSelectedDestination=$destination
                Show-HcGameModal 'MoveConfirm'
            }else{
                if($info.Provider){Set-ProviderInstallRoot $info.Provider $path}
                Close-HcGameModal
                Invoke-HcProviderOperation 'Install' $path
            }
            return
        }
    }
    switch($id){
        'modal-favorite' {Toggle-HcGameFavorite (Get-HcSelectedGame);Show-HcGameModal $(if($script:GameModalMode -eq 'AddTo'){'AddTo'}else{'Settings'})}
        'modal-addto' {Show-HcGameModal 'AddTo'}
        'modal-manage' {Show-HcGameModal 'Manage'}
        'modal-properties' {Close-HcGameModal;$script:SubPage='GameProperties';$script:GamePropertiesCategory='General';$script:SelectedAction=0;Render-Page}
        'modal-cancel' {Close-HcGameModal}
        'modal-settings-back' {Show-HcGameModal 'Settings'}
        'modal-manage-back' {Show-HcGameModal 'Manage'}
        'modal-move-confirm-back' {Show-HcGameModal 'MoveConfirm'}
        'game-play' {Close-HcGameModal;Invoke-HcGamePlay}
        'game-primary-install' {Show-HcGameModal 'InstallLocation'}
        'game-install-location' {Show-HcGameModal 'InstallLocation'}
        'game-update' {Close-HcGameModal;Invoke-HcProviderOperation 'Update'}
        'game-verify' {Close-HcGameModal;Invoke-HcProviderOperation 'Verify'}
        'game-move' {$script:GameModalSelectedDestination=$null;Show-HcGameModal 'MoveConfirm'}
        'game-move-target' {Show-HcGameModal 'MoveLocation'}
        'game-move-confirm' {$destination=$script:GameModalSelectedDestination;if($null -ne $destination){$path=[string]$destination.Path;$info=Get-HcGameProviderAndId;if($info.Provider){Set-ProviderInstallRoot $info.Provider $path};Close-HcGameModal;Invoke-HcProviderOperation 'Move' $path}}
        'game-browse-files' {Close-HcGameModal;$path=[string](Get-EntryProperty (Get-HcSelectedGame) 'InstallPath' (Get-EntryProperty (Get-HcSelectedGame) 'Path' ''));if($path){Start-UriOrShellTarget $path}}
        'game-uninstall' {Close-HcGameModal;$info=Get-HcGameProviderAndId;$script:SelectedProviderGame=Get-HcActualProviderGame $info.Game;Request-NativeConfirmation "provider-uninstall:$($info.Provider):$($info.Id)" "Uninstall $($info.Name) from $($info.Provider)?"}
    }
}

function Handle-HcGameModalController {
    param([int]$Mask,[string]$Direction)
    if(-not (Test-HcGameModalVisible)){return $false}
    $now=Get-Date
    if($Direction){
        if($Direction -ne $script:LastDirection -or $now -ge $script:NextDirectionAt){
            if($Direction -eq 'Up'){Move-HcGameModalSelection -1}elseif($Direction -eq 'Down'){Move-HcGameModalSelection 1}
            $isNew=($Direction -ne $script:LastDirection);$script:LastDirection=$Direction;$script:NextDirectionAt=$now.AddMilliseconds($(if($isNew){360}else{125}))
        }
    }else{$script:LastDirection='';$script:NextDirectionAt=[datetime]::MinValue}
    if(Is-NewButtonPress $Mask 4){Invoke-HcGameModalSelected}
    if(Is-NewButtonPress $Mask 8){if($script:GameModalMode -in @('Manage','AddTo')){Show-HcGameModal 'Settings'}elseif($script:GameModalMode -eq 'MoveLocation'){Show-HcGameModal 'MoveConfirm'}elseif($script:GameModalMode -in @('InstallLocation','MoveConfirm')){Show-HcGameModal 'Manage'}else{Close-HcGameModal}}
    $script:LastGamepadMask=$Mask
    return $true
}

function Handle-HcGameModalKey {
    param($Key)
    if(-not (Test-HcGameModalVisible)){return $false}
    switch([string]$Key){
        'Up' {Move-HcGameModalSelection -1}
        'Down' {Move-HcGameModalSelection 1}
        'Enter' {Invoke-HcGameModalSelected}
        'Space' {Invoke-HcGameModalSelected}
        'Escape' {if($script:GameModalMode -in @('Manage','AddTo')){Show-HcGameModal 'Settings'}elseif($script:GameModalMode -eq 'MoveLocation'){Show-HcGameModal 'MoveConfirm'}elseif($script:GameModalMode -in @('InstallLocation','MoveConfirm')){Show-HcGameModal 'Manage'}else{Close-HcGameModal}}
        default {return $false}
    }
    return $true
}

function Restore-HcLibraryPosition {
    param([double]$Offset)
    try{
        $timer=New-Object System.Windows.Threading.DispatcherTimer;$timer.Interval=[TimeSpan]::FromMilliseconds(80)
        $timer.Add_Tick({try{$timer.Stop();$script:ActionScrollViewer.ScrollToVerticalOffset($Offset);Update-ActionVisuals}catch{}}.GetNewClosure());$timer.Start()
    }catch{}
}

function Set-HcShellBlur {
    param([bool]$Enabled)
    if($null -eq $script:ShellContent){return}
    try{
        if($Enabled){$effect=New-Object System.Windows.Media.Effects.BlurEffect;$effect.Radius=10;$script:ShellContent.Effect=$effect;$script:ShellContent.Opacity=.68}
        else{$script:ShellContent.Effect=$null;$script:ShellContent.Opacity=1.0}
    }catch{}
}

function Get-HcMainMenuEntries {
    return @(
        [pscustomobject]@{Title='Home';Icon='⌂';Tab=0;Subtitle='Recently played and quick access'},
        [pscustomobject]@{Title='Library';Icon='▦';Tab=1;Subtitle='Installed shelves and complete game library'},
        [pscustomobject]@{Title='Apps';Icon='◈';Tab=2;Subtitle='Storefronts and installed applications'},
        [pscustomobject]@{Title='Web';Icon='◎';Tab=3;Subtitle='Controller-friendly browser'},
        [pscustomobject]@{Title='Downloads';Icon='↓';Tab=4;Subtitle='Install, update, verify, and move progress'},
        [pscustomobject]@{Title='Import';Icon='＋';Tab=5;Subtitle='Discover local game libraries'},
        [pscustomobject]@{Title='File Explorer';Icon='▱';Tab=6;Subtitle='Browse files and folders'},
        [pscustomobject]@{Title='Settings';Icon='⚙';Tab=7;Subtitle='Display, audio, controllers, and console options'},
        [pscustomobject]@{Title='Power';Icon='⏻';Tab=8;Subtitle='Sleep, restart, shut down, or exit'}
    )
}

function New-HcMainMenuButton {
    param($Entry,[int]$Index)
    $button=New-Object System.Windows.Controls.Button
    $button.Tag=$Index;$button.Height=68;$button.Margin='0,0,0,7';$button.Padding='15,8';$button.HorizontalContentAlignment='Stretch';$button.Background='#080A0E';$button.Foreground='White';$button.BorderBrush='#252B35';$button.BorderThickness='1';$button.Cursor='Hand'
    $button.Template=[Windows.Markup.XamlReader]::Parse('<ControlTemplate xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" TargetType="Button"><Border Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="12" Padding="{TemplateBinding Padding}"><ContentPresenter HorizontalAlignment="{TemplateBinding HorizontalContentAlignment}" VerticalAlignment="Center"/></Border></ControlTemplate>')
    $grid=New-Object System.Windows.Controls.Grid;$grid.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition -Property @{Width='54'}));$grid.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition -Property @{Width='*'}))
    $icon=New-Object System.Windows.Controls.TextBlock;$icon.Text=[string]$Entry.Icon;$icon.FontSize=27;$icon.FontWeight='Bold';$icon.HorizontalAlignment='Center';$icon.VerticalAlignment='Center';$icon.Foreground='White';$grid.Children.Add($icon)|Out-Null
    $text=New-Object System.Windows.Controls.StackPanel;$text.Margin='12,0,0,0';[System.Windows.Controls.Grid]::SetColumn($text,1)
    $title=New-Object System.Windows.Controls.TextBlock;$title.Text=[string]$Entry.Title;$title.FontSize=19;$title.FontWeight='SemiBold';$title.Foreground='White';$text.Children.Add($title)|Out-Null
    $subtitle=New-Object System.Windows.Controls.TextBlock;$subtitle.Text=[string]$Entry.Subtitle;$subtitle.FontSize=11;$subtitle.Foreground='#99A8BA';$subtitle.Margin='0,3,0,0';$subtitle.TextTrimming='CharacterEllipsis';$text.Children.Add($subtitle)|Out-Null
    $grid.Children.Add($text)|Out-Null;$button.Content=$grid
    $button.Add_Click({param($sender,$eventArgs)$script:HcMainMenuSelected=[int]$sender.Tag;Update-HcMainMenuVisuals;Invoke-HcMainMenuSelected})
    $button.Add_MouseEnter({param($sender,$eventArgs)if(-not(Test-HcMouseHoverAllowed)){return};Set-KeyboardActive;$script:HcMainMenuSelected=[int]$sender.Tag;Update-HcMainMenuVisuals})
    return $button
}

function Test-HcMainMenuVisible {
    return ($null -ne $script:MainMenuOverlay -and $script:MainMenuOverlay.Visibility -eq 'Visible')
}

function Show-HcMainMenu {
    if($null -eq $script:MainMenuOverlay){Focus-TopNavigation;return}
    if(Test-HcMainMenuVisible){Close-HcMainMenu;return}
    if(Test-HcGameModalVisible){Close-HcGameModal}
    $script:HcMainMenuEntries=@(Get-HcMainMenuEntries);$script:HcMainMenuButtons=@();$script:HcMainMenuSelected=0
    for($i=0;$i -lt $script:HcMainMenuEntries.Count;$i++){if([int]$script:HcMainMenuEntries[$i].Tab -eq [int]$script:SelectedTab){$script:HcMainMenuSelected=$i;break}}
    $script:MainMenuPanel.Children.Clear()
    for($i=0;$i -lt $script:HcMainMenuEntries.Count;$i++){$button=New-HcMainMenuButton $script:HcMainMenuEntries[$i] $i;$script:MainMenuPanel.Children.Add($button)|Out-Null;$script:HcMainMenuButtons+=$button}
    $script:NavigationLayer='Content';$script:MainMenuOverlay.Visibility='Visible';Set-HcShellBlur $true;Update-HcMainMenuVisuals;Update-Footer
}

function Close-HcMainMenu {
    if($null -ne $script:MainMenuOverlay){$script:MainMenuOverlay.Visibility='Collapsed'}
    $script:HcMainMenuButtons=@();$script:HcMainMenuEntries=@();$script:NavigationLayer='Content'
    if(-not (Test-HcGameModalVisible)){Set-HcShellBlur $false}
    Update-ActionVisuals;Update-Footer
}

function Update-HcMainMenuVisuals {
    for($i=0;$i -lt $script:HcMainMenuButtons.Count;$i++){
        $button=$script:HcMainMenuButtons[$i]
        if($i -eq $script:HcMainMenuSelected){$button.Background='#D8CD75';$button.BorderBrush='#FFF3A8';$button.BorderThickness='2';try{$button.Content.Children[0].Foreground='#111722';$button.Content.Children[1].Children[0].Foreground='#111722';$button.Content.Children[1].Children[1].Foreground='#4D4A18'}catch{}}
        else{$button.Background='#080A0E';$button.BorderBrush='#252B35';$button.BorderThickness='1';try{$button.Content.Children[0].Foreground='White';$button.Content.Children[1].Children[0].Foreground='White';$button.Content.Children[1].Children[1].Foreground='#99A8BA'}catch{}}
    }
    try{$script:HcMainMenuButtons[$script:HcMainMenuSelected].BringIntoView()}catch{}
}

function Move-HcMainMenuSelection {
    param([int]$Delta)
    if($script:HcMainMenuButtons.Count -eq 0){return}
    $next=$script:HcMainMenuSelected+$Delta
    if($next -lt 0){$next=$script:HcMainMenuButtons.Count-1}
    if($next -ge $script:HcMainMenuButtons.Count){$next=0}
    if($next -ne $script:HcMainMenuSelected){$script:HcMainMenuSelected=$next;Invoke-UiFeedback 'Navigate';Update-HcMainMenuVisuals}
}

function Invoke-HcMainMenuSelected {
    if($script:HcMainMenuSelected -lt 0 -or $script:HcMainMenuSelected -ge $script:HcMainMenuEntries.Count){return}
    $tab=[int]$script:HcMainMenuEntries[$script:HcMainMenuSelected].Tab
    Invoke-UiFeedback 'Confirm';Close-HcMainMenu;Set-Tab $tab;$script:NavigationLayer='Content';Update-ActionVisuals
}

function Handle-HcMainMenuController {
    param([int]$Mask,[string]$Direction)
    if(-not (Test-HcMainMenuVisible)){return $false}
    $now=Get-Date
    if($Direction){
        if($Direction -ne $script:LastDirection -or $now -ge $script:NextDirectionAt){
            if($Direction -eq 'Up'){Move-HcMainMenuSelection -1}elseif($Direction -eq 'Down'){Move-HcMainMenuSelection 1}
            $isNew=($Direction -ne $script:LastDirection);$script:LastDirection=$Direction;$script:NextDirectionAt=$now.AddMilliseconds($(if($isNew){360}else{125}))
        }
    }else{$script:LastDirection='';$script:NextDirectionAt=[datetime]::MinValue}
    if(Is-NewButtonPress $Mask 4){Invoke-HcMainMenuSelected}
    if((Is-NewButtonPress $Mask 8) -or (Is-NewButtonPress $Mask 2)){Invoke-UiFeedback 'Back';Close-HcMainMenu}
    $script:LastGamepadMask=$Mask
    return $true
}

function Handle-HcMainMenuKey {
    param($Key)
    if(-not (Test-HcMainMenuVisible)){return $false}
    switch([string]$Key){
        'Up' {Move-HcMainMenuSelection -1}
        'Down' {Move-HcMainMenuSelection 1}
        'Enter' {Invoke-HcMainMenuSelected}
        'Space' {Invoke-HcMainMenuSelected}
        'Escape' {Close-HcMainMenu}
        'F1' {Close-HcMainMenu}
        default {return $false}
    }
    return $true
}

function Handle-HcGameExperienceBack {
    if(Test-HcMainMenuVisible){Invoke-UiFeedback 'Back';Close-HcMainMenu;return $true}
    if(Test-HcGameModalVisible){
        Invoke-UiFeedback 'Back'
        if($script:GameModalMode -in @('Manage','AddTo')){Show-HcGameModal 'Settings'}elseif($script:GameModalMode -eq 'MoveLocation'){Show-HcGameModal 'MoveConfirm'}elseif($script:GameModalMode -in @('InstallLocation','MoveConfirm')){Show-HcGameModal 'Manage'}else{Close-HcGameModal}
        return $true
    }
    if($script:SelectedTab -eq 1 -and $script:SubPage -eq 'GameProperties'){
        Invoke-UiFeedback 'Back';$script:SubPage='GameDetail';$script:SelectedAction=1;Render-Page;return $true
    }
    if($script:SelectedTab -eq 1 -and $script:SubPage -eq 'GameDetail'){
        Invoke-UiFeedback 'Back';$target=$script:GameReturnSubPage;$action=$script:GameReturnAction;$offset=$script:GameReturnScrollOffset;$script:SubPage=$target;$script:SelectedAction=$action;Render-Page;Restore-HcLibraryPosition $offset;return $true
    }
    return $false
}

function Invoke-HcGameExperienceAction {
    param([string]$Id)
    if($Id -match '^hub-game:(\d+)$'){
        $index=[int]$matches[1]
        if($index -ge 0 -and $index -lt $script:GameHubLaunchEntries.Count){Open-HcGameDetail $script:GameHubLaunchEntries[$index]}
        return $true
    }
    if($Id -match '^game-prop-category:(.+)$'){$script:GamePropertiesCategory=[string]$matches[1];$script:SelectedAction=0;Render-Page;return $true}
    switch($Id){
        'game-primary-play' {Invoke-HcGamePlay;return $true}
        'game-primary-install' {Show-HcGameModal 'InstallLocation';return $true}
        'game-open-settings' {Show-HcGameModal 'Settings';return $true}
        'game-toggle-favorite' {Toggle-HcGameFavorite (Get-HcSelectedGame);Render-Page;return $true}
        'game-launch-options' {Set-ConsoleNotice 'Per-game launch-option editing is staged for the next provider capability pass.' 'INFO';Render-Page;return $true}
        'game-update' {Invoke-HcProviderOperation 'Update';return $true}
        'game-verify' {Invoke-HcProviderOperation 'Verify';return $true}
        'game-move' {$script:GameModalSelectedDestination=$null;Show-HcGameModal 'MoveConfirm';return $true}
        'game-install-location' {Show-HcGameModal 'InstallLocation';return $true}
        'game-browse-files' {$path=[string](Get-EntryProperty (Get-HcSelectedGame) 'InstallPath' (Get-EntryProperty (Get-HcSelectedGame) 'Path' ''));if($path){Start-UriOrShellTarget $path};return $true}
        'game-uninstall' {$info=Get-HcGameProviderAndId;$script:SelectedProviderGame=Get-HcActualProviderGame $info.Game;Request-NativeConfirmation "provider-uninstall:$($info.Provider):$($info.Id)" "Uninstall $($info.Name) from $($info.Provider)?";return $true}
        'game-properties-back' {$script:SubPage='GameDetail';$script:SelectedAction=1;Render-Page;return $true}
    }
    return $false
}

function Get-StorefrontSecondaryLabel {
    if($script:SelectedTab -eq 1 -and $script:SubPage -in @('PlatformHome','PlatformShelf','PlatformLibrary')){return 'Manage'}
    if($script:SelectedTab -eq 1 -and $script:SubPage -eq 'GameDetail'){return 'Manage'}
    if($script:SelectedTab -ne 2 -or $script:ActionButtons.Count -eq 0){return 'Search'}
    if($script:SelectedAction -lt 0 -or $script:SelectedAction -ge $script:ActionButtons.Count){return 'Search'}
    $id=[string]$script:ActionButtons[$script:SelectedAction].Tag
    if($id -match '^storefront:(.+)$'){$item=Get-StorefrontCatalogItem ([string]$matches[1]);if($null -ne $item -and [bool]$item.Installed){return 'Manage'};return 'Install'}
    return 'Search'
}

function Invoke-SecondaryAction {
    if($script:KeyboardActive){Invoke-NativeKeyboardKey 'BACKSPACE';return}
    if($script:SelectedTab -eq 1){
        if($script:SubPage -eq 'GameDetail'){Show-HcGameModal 'Settings';return}
        if($script:SubPage -in @('PlatformHome','PlatformShelf','PlatformLibrary') -and $script:SelectedAction -ge 0 -and $script:SelectedAction -lt $script:ActionButtons.Count){
            $id=[string]$script:ActionButtons[$script:SelectedAction].Tag
            if($id -match '^hub-game:(\d+)$'){$index=[int]$matches[1];if($index -ge 0 -and $index -lt $script:GameHubLaunchEntries.Count){Open-HcGameDetail $script:GameHubLaunchEntries[$index];Show-HcGameModal 'Manage'};return}
        }
    }
    if($script:SelectedTab -eq 2 -and $script:ActionButtons.Count -gt 0 -and $script:SelectedAction -ge 0 -and $script:SelectedAction -lt $script:ActionButtons.Count){
        $id=[string]$script:ActionButtons[$script:SelectedAction].Tag
        if($id -match '^storefront:(.+)$'){$storeId=[string]$matches[1];$item=Get-StorefrontCatalogItem $storeId;if($null -ne $item -and [bool]$item.Installed){$script:SubPage="Storefront:$storeId";$script:SelectedAction=0;Render-Page}else{Start-StorefrontWorker 'Install' $storeId;Render-Page};return}
    }
}

# v0.17 shared performance and presentation layer. These definitions override
# the earlier helpers at runtime without changing provider-specific behavior.
$script:HcGameDataCache=@{}
$script:HcPersistentLibraryIndex=@{}
$script:HcPersistentLibraryIndexPath=Join-Path $script:DataDir 'library-view-cache.json'
$script:HcLibraryEntries=@()
$script:HcLibraryWrap=$null
$script:HcLibraryStatusText=$null
$script:HcLibraryRenderedCount=0
$script:HcLibraryColumns=1
$script:HcLibraryBatchSize=32
$script:HcLibraryAppending=$false
$script:HcLibraryScrollHandler=$null
$script:ShelfHeroImage=$null
$script:ShelfHeroFallback=$null
$script:ShelfMetaText=$null
$script:ShelfCountText=$null
# The v0.17 cinematic shelf does not expose the retired LB/RB artwork-preview
# state. Override its old handler so a controller event can never touch stale
# preview variables after a restart or visual-tree rebuild.
function Move-ShelfArtworkPreview { param([int]$Delta); return $false }

function Get-HcFileRevision {
    param([string]$Path)
    try{if($Path -and (Test-Path -LiteralPath $Path -PathType Leaf)){return (Get-Item -LiteralPath $Path).LastWriteTimeUtc.Ticks.ToString()}}catch{}
    return '0'
}

if($null -eq (Get-Variable -Name HcGameDataGeneration -Scope Script -ValueOnly -ErrorAction SilentlyContinue)){$script:HcGameDataGeneration=1}
function Get-HcGameDataRevision { return [string]$script:HcGameDataGeneration }

function Import-HcPersistentLibraryIndex {
    $script:HcPersistentLibraryIndex=@{}
    if(-not (Test-Path -LiteralPath $script:HcPersistentLibraryIndexPath -PathType Leaf)){return}
    try{
        $payload=Get-Content -Raw -LiteralPath $script:HcPersistentLibraryIndexPath|ConvertFrom-Json
        if([int](Get-EntryProperty $payload 'SchemaVersion' 0) -ne 2){return}
        foreach($entry in @(Get-EntryProperty $payload 'Entries' @())){
            $key=[string](Get-EntryProperty $entry 'Key' '')
            if($key){$script:HcPersistentLibraryIndex[$key]=[object[]]@(Get-EntryProperty $entry 'Items' @())}
        }
    }catch{
        $script:HcPersistentLibraryIndex=@{}
        Write-Log "Persistent library index could not be loaded: $($_.Exception.Message)" 'WARN'
    }
}

function Save-HcPersistentLibraryIndex {
    try{
        $entries=New-Object System.Collections.ArrayList
        foreach($key in @($script:HcPersistentLibraryIndex.Keys|Sort-Object)){
            [void]$entries.Add([pscustomobject]@{Key=[string]$key;Items=[object[]]@($script:HcPersistentLibraryIndex[$key])})
        }
        $payload=[pscustomobject]@{SchemaVersion=2;UpdatedAt=(Get-Date).ToString('o');Entries=[object[]]$entries.ToArray()}
        $temp=$script:HcPersistentLibraryIndexPath+'.tmp'
        ConvertTo-Json -InputObject $payload -Depth 20 -Compress|Set-Content -LiteralPath $temp -Encoding UTF8
        Move-Item -LiteralPath $temp -Destination $script:HcPersistentLibraryIndexPath -Force
    }catch{Write-Log "Persistent library index could not be saved: $($_.Exception.Message)" 'WARN'}
}

function Set-HcPersistentLibraryItems {
    param([string]$Key,[object[]]$Items)
    if(-not $Key){return}
    $script:HcPersistentLibraryIndex[$Key]=[object[]]@($Items)
    Save-HcPersistentLibraryIndex
}

function Clear-HcGameDataCache {
    param([switch]$DropPersistent)
    $script:HcGameDataCache=@{}
    if($DropPersistent){
        $script:HcPersistentLibraryIndex=@{}
        Remove-Item -LiteralPath $script:HcPersistentLibraryIndexPath -Force -ErrorAction SilentlyContinue
    }
    $script:HcGameDataGeneration=[int]$script:HcGameDataGeneration+1
}

Import-HcPersistentLibraryIndex

function Get-PlatformGames {
    param([string]$Platform)
    $revision=Get-HcGameDataRevision
    $baseKey='installed|'+$Platform.ToLowerInvariant()
    $cacheKey=$baseKey+'|'+$revision
    if($script:HcGameDataCache.ContainsKey($cacheKey)){return [object[]]$script:HcGameDataCache[$cacheKey]}
    if($script:HcPersistentLibraryIndex.ContainsKey($baseKey)){
        $cached=[object[]]@($script:HcPersistentLibraryIndex[$baseKey])
        if([string]::Equals($Platform,'Epic',[StringComparison]::OrdinalIgnoreCase)){$cached=[object[]]@($cached|Where-Object{Test-HcProviderGameVisible $_ $Platform})}
        $script:HcGameDataCache[$cacheKey]=$cached
        return $cached
    }
    $items=New-Object System.Collections.ArrayList;$byId=@{};$byName=@{}
    foreach($entry in @(Get-AllGameHubEntries|Where-Object{[string]::Equals([string](Get-EntryProperty $_ 'Source' 'Custom'),$Platform,[StringComparison]::OrdinalIgnoreCase)})){
        if(-not (Test-HcProviderGameVisible $entry $Platform)){continue}
        $local=Convert-HcGameEntry $entry $Platform;$local.Installed=$true
        Add-HcMergedGame $items $byId $byName $local $Platform
    }
    if((Get-Command Test-DirectProviderPlatform -ErrorAction SilentlyContinue) -and (Test-DirectProviderPlatform $Platform)){
        foreach($providerGame in @(Get-ProviderGames $Platform -InstalledOnly)){Add-HcMergedGame $items $byId $byName $providerGame $Platform}
    }
    $result=[object[]]$items.ToArray()
    $script:HcGameDataCache[$cacheKey]=$result
    Set-HcPersistentLibraryItems $baseKey $result
    return $result
}

function Get-PlatformLibraryGames {
    param([string]$Platform)
    $revision=Get-HcGameDataRevision
    $baseKey='owned|'+$Platform.ToLowerInvariant()
    $cacheKey=$baseKey+'|'+$revision
    if($script:HcGameDataCache.ContainsKey($cacheKey)){return [object[]]$script:HcGameDataCache[$cacheKey]}
    if($script:HcPersistentLibraryIndex.ContainsKey($baseKey)){
        $cached=[object[]]@($script:HcPersistentLibraryIndex[$baseKey])
        if([string]::Equals($Platform,'Epic',[StringComparison]::OrdinalIgnoreCase)){$cached=[object[]]@($cached|Where-Object{Test-HcProviderGameVisible $_ $Platform})}
        $script:HcGameDataCache[$cacheKey]=$cached
        return $cached
    }
    $items=New-Object System.Collections.ArrayList;$byId=@{};$byName=@{}
    foreach($entry in @(Get-AllGameHubEntries|Where-Object{[string]::Equals([string](Get-EntryProperty $_ 'Source' 'Custom'),$Platform,[StringComparison]::OrdinalIgnoreCase)})){
        if(-not (Test-HcProviderGameVisible $entry $Platform)){continue}
        $local=Convert-HcGameEntry $entry $Platform;$local.Installed=$true
        Add-HcMergedGame $items $byId $byName $local $Platform
    }
    if((Get-Command Test-DirectProviderPlatform -ErrorAction SilentlyContinue) -and (Test-DirectProviderPlatform $Platform)){
        foreach($providerGame in @(Get-ProviderGames $Platform)){Add-HcMergedGame $items $byId $byName $providerGame $Platform}
    }
    $result=[object[]]$items.ToArray()
    $script:HcGameDataCache[$cacheKey]=$result
    Set-HcPersistentLibraryItems $baseKey $result
    return $result
}

function Get-HcPreferredCoverPath {
    param($Entry)
    foreach($property in @('BoxArtPath','ArtworkPath','ImagePath','IconPath','HeroArtworkPath')){
        $path=[string](Get-EntryProperty $Entry $property '')
        if($path -and (Test-Path -LiteralPath $path -PathType Leaf)){return $path}
    }
    return ''
}

function Get-HcPreferredHeroPath {
    param($Entry)
    foreach($property in @('HeroArtworkPath','ArtworkPath')){
        $path=[string](Get-EntryProperty $Entry $property '')
        if($path -and (Test-Path -LiteralPath $path -PathType Leaf)){return $path}
    }
    return ''
}

# v0.25.0: Shelf is not allowed to maintain an independent artwork identity.
# Hydrate every installed game from the corresponding Library record so both
# views use the same resolved cover/hero paths while retaining the installed
# entry's direct launch target and install path.
function Get-HcShelfEntries {
    param([string]$Platform)
    $installed=@(Get-PlatformGames $Platform)
    if($installed.Count -eq 0){return @()}
    $library=@(Get-PlatformLibraryGames $Platform)
    if($library.Count -eq 0){return [object[]]$installed}
    $byId=@{};$byName=@{}
    foreach($entry in $library){
        if($null -eq $entry){continue}
        $id=Get-HcCanonicalGameId $entry $Platform
        if($id){$byId[$id]=$entry}
        $nameKey=(Get-HcSafeText (Get-EntryProperty $entry 'Source' $Platform) $Platform).ToLowerInvariant()+'|'+(Get-HcNormalizedName ([string](Get-EntryProperty $entry 'Name' '')))
        if($nameKey -and $nameKey -ne '|'){$byName[$nameKey]=$entry}
    }
    $result=New-Object System.Collections.ArrayList
    foreach($entry in $installed){
        if($null -eq $entry){continue}
        $match=$null
        $id=Get-HcCanonicalGameId $entry $Platform
        if($id -and $byId.ContainsKey($id)){$match=$byId[$id]}
        if($null -eq $match){
            $nameKey=(Get-HcSafeText (Get-EntryProperty $entry 'Source' $Platform) $Platform).ToLowerInvariant()+'|'+(Get-HcNormalizedName ([string](Get-EntryProperty $entry 'Name' '')))
            if($nameKey -and $byName.ContainsKey($nameKey)){$match=$byName[$nameKey]}
        }
        $merged=if($null -ne $match){Merge-HcGameEntry $entry $match $Platform}else{Convert-HcGameEntry $entry $Platform}
        if($null -ne $merged){$merged.Installed=$true;[void]$result.Add($merged)}
    }
    return [object[]]$result.ToArray()
}

function New-HcShelfCard {
    param($Entry,[string]$Id)
    $button=New-Object System.Windows.Controls.Button
    $button.Tag=$Id;$button.Width=220;$button.Height=330;$button.Margin='0,12,20,18';$button.Padding='0';$button.HorizontalContentAlignment='Stretch';$button.VerticalContentAlignment='Stretch';$button.Background='#C60B1018';$button.BorderBrush='#33445E';$button.BorderThickness='1';$button.RenderTransformOrigin='0.5,0.5';$button.Cursor='Hand'
    $button.Template=[Windows.Markup.XamlReader]::Parse('<ControlTemplate xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" TargetType="Button"><Border Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="10" ClipToBounds="True"><ContentPresenter/></Border></ControlTemplate>')
    $grid=New-Object System.Windows.Controls.Grid
    $art=Get-HcPreferredCoverPath $Entry
    $source=Get-ImageSourceFromPath $art 520
    if($null -ne $source){$image=New-Object System.Windows.Controls.Image;$image.Source=$source;$image.Stretch='UniformToFill';$image.Opacity=.92;$grid.Children.Add($image)|Out-Null}
    else{
        $fallback=New-Object System.Windows.Controls.Border;$fallback.Background='#182536';$fallback.Child=New-PlatformIconImage ([string](Get-EntryProperty $Entry 'Source' $script:SelectedGamePlatform)) 54;$grid.Children.Add($fallback)|Out-Null
    }
    $shade=New-Object System.Windows.Shapes.Rectangle;$shade.VerticalAlignment='Bottom';$shade.Height=84
    $shadeBrush=New-Object System.Windows.Media.LinearGradientBrush;$shadeBrush.StartPoint='0,0';$shadeBrush.EndPoint='0,1'
    $shadeBrush.GradientStops.Add((New-Object System.Windows.Media.GradientStop -ArgumentList ([System.Windows.Media.ColorConverter]::ConvertFromString('#00101820')),0.0))
    $shadeBrush.GradientStops.Add((New-Object System.Windows.Media.GradientStop -ArgumentList ([System.Windows.Media.ColorConverter]::ConvertFromString('#F4080B11')),1.0));$shade.Fill=$shadeBrush;$grid.Children.Add($shade)|Out-Null
    $title=New-Object System.Windows.Controls.TextBlock;$title.Text=[string](Get-EntryProperty $Entry 'Name' 'Game');$title.FontSize=14;$title.FontWeight='SemiBold';$title.Foreground='White';$title.VerticalAlignment='Bottom';$title.Margin='14,0,14,14';$title.Padding='0,1,0,3';$title.TextTrimming='CharacterEllipsis';$grid.Children.Add($title)|Out-Null
    $button.Content=$grid
    $button.Add_Click({param($sender,$eventArgs)try{Set-KeyboardActive;Invoke-UiFeedback 'Confirm';Invoke-Action ([string]$sender.Tag)}catch{Write-Log "Shelf action failed: $($_.Exception.Message)" 'ERROR'}})
    $button.Add_MouseEnter({param($sender,$eventArgs)if(-not(Test-HcMouseHoverAllowed)){return};Set-KeyboardActive;$idx=[array]::IndexOf($script:ActionButtons,$sender);if($idx -ge 0){$script:SelectedAction=$idx;Update-ActionVisuals}})
    return $button
}

function Render-PlatformShelf {
    $script:GameHubLaunchEntries=@()
    $script:ShelfEntries=@(Get-HcShelfEntries $script:SelectedGamePlatform|Sort-Object {[string](Get-EntryProperty $_ 'Name')})
    if($script:ShelfEntries.Count -eq 0){Add-GameHubRail "$($script:SelectedGamePlatform) Shelf" @() "No installed $($script:SelectedGamePlatform) games are available yet.";return}

    $outer=New-Object System.Windows.Controls.Grid
    $height=[double]$script:ActionScrollViewer.ActualHeight;if($height -lt 650){$height=810}else{$height=[math]::Max(690,$height-10)}
    $outer.Height=$height
    $outer.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition -Property @{Height='*'}))
    $outer.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition -Property @{Height='380'}))

    $hero=New-Object System.Windows.Controls.Border;$hero.CornerRadius=20;$hero.ClipToBounds=$true;$hero.Background='#0B111A';$hero.BorderBrush='#30FFFFFF';$hero.BorderThickness='1';$hero.Margin='0,0,0,8'
    $heroGrid=New-Object System.Windows.Controls.Grid
    $script:ShelfHeroImage=New-Object System.Windows.Controls.Image;$script:ShelfHeroImage.Stretch='UniformToFill';$script:ShelfHeroImage.Opacity=.88;$heroGrid.Children.Add($script:ShelfHeroImage)|Out-Null
    $script:ShelfHeroFallback=New-Object System.Windows.Controls.Grid
    $fallbackBrush=New-Object System.Windows.Media.LinearGradientBrush;$fallbackBrush.StartPoint='0,0';$fallbackBrush.EndPoint='1,1';$theme=Get-PlatformTheme $script:SelectedGamePlatform
    $fallbackBrush.GradientStops.Add((New-Object System.Windows.Media.GradientStop -ArgumentList ([System.Windows.Media.ColorConverter]::ConvertFromString($theme.Base1)),0.0));$fallbackBrush.GradientStops.Add((New-Object System.Windows.Media.GradientStop -ArgumentList ([System.Windows.Media.ColorConverter]::ConvertFromString($theme.Base2)),1.0));$script:ShelfHeroFallback.Background=$fallbackBrush
    $fallbackStack=New-Object System.Windows.Controls.StackPanel;$fallbackStack.HorizontalAlignment='Center';$fallbackStack.VerticalAlignment='Center';$fallbackStack.Children.Add((New-PlatformIconImage $script:SelectedGamePlatform 126))|Out-Null
    $fallbackName=New-Object System.Windows.Controls.TextBlock;$fallbackName.Text=$script:SelectedGamePlatform.ToUpperInvariant();$fallbackName.FontSize=24;$fallbackName.FontWeight='Bold';$fallbackName.Foreground='#DDE7F5';$fallbackName.Margin='0,18,0,0';$fallbackName.HorizontalAlignment='Center';$fallbackStack.Children.Add($fallbackName)|Out-Null;$script:ShelfHeroFallback.Children.Add($fallbackStack)|Out-Null;$heroGrid.Children.Add($script:ShelfHeroFallback)|Out-Null

    $dim=New-Object System.Windows.Shapes.Rectangle;$dim.Fill='#3A000000';$heroGrid.Children.Add($dim)|Out-Null
    $bottomShade=New-Object System.Windows.Shapes.Rectangle;$bottomShade.VerticalAlignment='Bottom';$bottomShade.Height=285
    $bottomBrush=New-Object System.Windows.Media.LinearGradientBrush;$bottomBrush.StartPoint='0,0';$bottomBrush.EndPoint='0,1';$bottomBrush.GradientStops.Add((New-Object System.Windows.Media.GradientStop -ArgumentList ([System.Windows.Media.ColorConverter]::ConvertFromString('#00101820')),0.0));$bottomBrush.GradientStops.Add((New-Object System.Windows.Media.GradientStop -ArgumentList ([System.Windows.Media.ColorConverter]::ConvertFromString('#F406090D')),1.0));$bottomShade.Fill=$bottomBrush;$heroGrid.Children.Add($bottomShade)|Out-Null

    $platformBadge=New-Object System.Windows.Controls.Border;$platformBadge.HorizontalAlignment='Left';$platformBadge.VerticalAlignment='Top';$platformBadge.Margin='24,22,0,0';$platformBadge.Padding='12,7';$platformBadge.CornerRadius=10;$platformBadge.Background='#B0080B10';$platformBadge.BorderBrush='#44FFFFFF';$platformBadge.BorderThickness='1'
    $badgeStack=New-Object System.Windows.Controls.StackPanel;$badgeStack.Orientation='Horizontal';$badgeStack.Children.Add((New-PlatformIconImage $script:SelectedGamePlatform 22))|Out-Null;$badgeText=New-Object System.Windows.Controls.TextBlock;$badgeText.Text=$script:SelectedGamePlatform.ToUpperInvariant();$badgeText.FontSize=12;$badgeText.FontWeight='Bold';$badgeText.Foreground='White';$badgeText.VerticalAlignment='Center';$badgeText.Margin='8,0,0,0';$badgeText.Padding='0,1,0,2';$badgeStack.Children.Add($badgeText)|Out-Null;$platformBadge.Child=$badgeStack;$heroGrid.Children.Add($platformBadge)|Out-Null
    $script:ShelfCountText=New-Object System.Windows.Controls.TextBlock;$script:ShelfCountText.Text="$($script:ShelfEntries.Count) INSTALLED";$script:ShelfCountText.HorizontalAlignment='Right';$script:ShelfCountText.VerticalAlignment='Top';$script:ShelfCountText.Margin='0,27,26,0';$script:ShelfCountText.FontSize=12;$script:ShelfCountText.FontWeight='SemiBold';$script:ShelfCountText.Foreground='#E8EDF5';$script:ShelfCountText.Padding='0,1,0,3';$heroGrid.Children.Add($script:ShelfCountText)|Out-Null

    $info=New-Object System.Windows.Controls.StackPanel;$info.VerticalAlignment='Bottom';$info.Margin='32,0,32,30';$info.MaxWidth=1120;$info.HorizontalAlignment='Left'
    $script:ShelfTitleText=New-Object System.Windows.Controls.TextBlock;$script:ShelfTitleText.FontSize=42;$script:ShelfTitleText.FontWeight='Bold';$script:ShelfTitleText.Foreground='White';$script:ShelfTitleText.TextWrapping='Wrap';$script:ShelfTitleText.Padding='0,1,0,5';$script:ShelfTitleText.Effect=New-Object System.Windows.Media.Effects.DropShadowEffect -Property @{BlurRadius=12;ShadowDepth=2;Opacity=.75};$info.Children.Add($script:ShelfTitleText)|Out-Null
    $script:ShelfDetailText=New-Object System.Windows.Controls.TextBlock;$script:ShelfDetailText.FontSize=15;$script:ShelfDetailText.Foreground='#E0E6EF';$script:ShelfDetailText.Margin='0,8,0,0';$script:ShelfDetailText.TextWrapping='Wrap';$script:ShelfDetailText.MaxWidth=980;$script:ShelfDetailText.MaxHeight=54;$script:ShelfDetailText.Padding='0,1,0,4';$info.Children.Add($script:ShelfDetailText)|Out-Null
    $script:ShelfMetaText=New-Object System.Windows.Controls.TextBlock;$script:ShelfMetaText.FontSize=12;$script:ShelfMetaText.FontWeight='SemiBold';$script:ShelfMetaText.Foreground='#E7C45E';$script:ShelfMetaText.Margin='0,10,0,0';$script:ShelfMetaText.Padding='0,1,0,3';$info.Children.Add($script:ShelfMetaText)|Out-Null
    $heroGrid.Children.Add($info)|Out-Null;$hero.Child=$heroGrid;$outer.Children.Add($hero)|Out-Null

    $carouselBorder=New-Object System.Windows.Controls.Border;$carouselBorder.Background='#A0080B10';$carouselBorder.BorderBrush='#28FFFFFF';$carouselBorder.BorderThickness='1,0,0,0';$carouselBorder.CornerRadius=14;$carouselBorder.Padding='24,8,24,0';[System.Windows.Controls.Grid]::SetRow($carouselBorder,1)
    $row=New-Object System.Windows.Controls.StackPanel;$row.Orientation='Horizontal';$row.VerticalAlignment='Center'
    for($i=0;$i -lt $script:ShelfEntries.Count;$i++){
        $entry=$script:ShelfEntries[$i];$script:GameHubLaunchEntries+=$entry
        $button=New-HcShelfCard $entry "hub-game:$i";$row.Children.Add($button)|Out-Null;$script:ActionButtons+=$button;$script:CurrentActions+=(New-Action "hub-game:$i" ([string](Get-EntryProperty $entry 'Name')))
    }
    $scroll=New-Object System.Windows.Controls.ScrollViewer;$scroll.HorizontalScrollBarVisibility='Hidden';$scroll.VerticalScrollBarVisibility='Disabled';$scroll.PanningMode='HorizontalOnly';$scroll.Content=$row;$carouselBorder.Child=$scroll;$outer.Children.Add($carouselBorder)|Out-Null
    $script:ActionPanel.Children.Add($outer)|Out-Null
    $script:HomeRows+=,[pscustomobject]@{Start=0;Count=$script:ShelfEntries.Count;Platform=$false}
    Update-ShelfSelection
}

function Update-ShelfSelection {
    if($script:SubPage -ne 'PlatformShelf' -or $script:ShelfEntries.Count -eq 0){return}
    $index=[math]::Max(0,[math]::Min($script:SelectedAction,$script:ShelfEntries.Count-1))
    $entry=$script:ShelfEntries[$index]
    $name=[string](Get-EntryProperty $entry 'Name' 'Game')
    $description=[string](Get-EntryProperty $entry 'Description' '')
    if($description.Length -gt 260){$description=$description.Substring(0,257)+'...'}
    if(-not $description){$description='Select to open the game page, play, or manage the installation.'}
    $provider=[string](Get-EntryProperty $entry 'Source' $script:SelectedGamePlatform)
    $path=[string](Get-EntryProperty $entry 'InstallPath' (Get-EntryProperty $entry 'Path' ''))
    $size=[string](Get-EntryProperty $entry 'SizeText' '')
    $heroPath=Get-HcPreferredHeroPath $entry
    if($null -ne $script:ShelfHeroImage){$script:ShelfHeroImage.Source=Get-ImageSourceFromPath $heroPath 1600;$script:ShelfHeroImage.Visibility=$(if($heroPath){'Visible'}else{'Collapsed'})}
    if($null -ne $script:ShelfHeroFallback){$script:ShelfHeroFallback.Visibility=$(if($heroPath){'Collapsed'}else{'Visible'})}
    if($null -ne $script:ShelfTitleText){$script:ShelfTitleText.Text=$name}
    if($null -ne $script:ShelfDetailText){$script:ShelfDetailText.Text=$description}
    if($null -ne $script:ShelfMetaText){
        $meta=New-Object System.Collections.ArrayList;[void]$meta.Add($provider.ToUpperInvariant());[void]$meta.Add('INSTALLED')
        if($size){[void]$meta.Add($size)}
        if($path){try{[void]$meta.Add(([IO.Path]::GetPathRoot($path)).TrimEnd('\'))}catch{}}
        if(-not $heroPath){[void]$meta.Add('ARTWORK RESTORING')}
        $script:ShelfMetaText.Text=(@($meta)-join '  •  ')
    }
}

function Update-HcLibraryStatus {
    if($null -eq $script:HcLibraryStatusText){return}
    $installedCount=@($script:HcLibraryEntries|Where-Object{[bool](Get-EntryProperty $_ 'Installed' $false)}).Count
    $shown=[math]::Min($script:HcLibraryRenderedCount,$script:HcLibraryEntries.Count)
    $script:HcLibraryStatusText.Text="$($script:HcLibraryEntries.Count) owned  •  $installedCount installed  •  Showing $shown"
}

function Add-HcLibraryBatch {
    param([int]$MinimumCount=0)
    if($script:HcLibraryAppending -or $null -eq $script:HcLibraryWrap){return}
    if($script:HcLibraryRenderedCount -ge $script:HcLibraryEntries.Count){Update-HcLibraryStatus;return}
    $script:HcLibraryAppending=$true
    try{
        $target=[math]::Max($script:HcLibraryRenderedCount+$script:HcLibraryBatchSize,$MinimumCount)
        $target=[math]::Min($target,$script:HcLibraryEntries.Count)
        $startRowIndex=[math]::Floor($script:HcLibraryRenderedCount/[double]$script:HcLibraryColumns)
        for($i=$script:HcLibraryRenderedCount;$i -lt $target;$i++){
            $entry=$script:HcLibraryEntries[$i]
            $button=New-HomeCard $entry "hub-game:$i" 'Library';$button.Width=198;$button.Height=286;$button.Margin='0,0,16,16'
            [void]$script:HcLibraryWrap.Children.Add($button);$script:ActionButtons+=$button;$script:CurrentActions+=(New-Action "hub-game:$i" ([string](Get-EntryProperty $entry 'Name' 'Game')))
        }
        $script:HcLibraryRenderedCount=$target
        $script:HomeRows=@($script:HomeRows|Where-Object{-not [bool](Get-EntryProperty $_ 'LibraryGrid' $false)})
        for($start=0;$start -lt $script:HcLibraryRenderedCount;$start+=$script:HcLibraryColumns){
            $count=[math]::Min($script:HcLibraryColumns,$script:HcLibraryRenderedCount-$start)
            $script:HomeRows+=,[pscustomobject]@{Start=$start;Count=$count;Platform=$false;LibraryGrid=$true}
        }
        Update-HcLibraryStatus
    }finally{$script:HcLibraryAppending=$false}
}

function Render-PlatformLibrary {
    $script:HcLibraryEntries=@(Get-PlatformLibraryGames $script:SelectedGamePlatform|Sort-Object {[string](Get-EntryProperty $_ 'Name')})
    $script:GameHubLaunchEntries=[object[]]$script:HcLibraryEntries
    $script:HcLibraryRenderedCount=0;$script:HcLibraryWrap=$null;$script:HcLibraryStatusText=$null
    $heading=New-Object System.Windows.Controls.TextBlock;$heading.Text="$($script:SelectedGamePlatform) Library";$heading.FontSize=30;$heading.FontWeight='Bold';$heading.Foreground='#F5F7FB';$heading.Padding='0,1,0,4';$heading.Margin='0,0,0,2';[void]$script:ActionPanel.Children.Add($heading)
    $script:HcLibraryStatusText=New-Object System.Windows.Controls.TextBlock;$script:HcLibraryStatusText.FontSize=13;$script:HcLibraryStatusText.Foreground='#AAB7C9';$script:HcLibraryStatusText.Padding='0,1,0,3';$script:HcLibraryStatusText.Margin='0,0,0,16';[void]$script:ActionPanel.Children.Add($script:HcLibraryStatusText)
    if($script:HcLibraryEntries.Count -eq 0){
        $empty=New-Object System.Windows.Controls.Border;$empty.Height=150;$empty.CornerRadius=14;$empty.Background='#7A101827';$empty.BorderBrush='#2B3A51';$empty.BorderThickness=1
        $tb=New-Object System.Windows.Controls.TextBlock;$tb.Text="No $($script:SelectedGamePlatform) games are imported yet.";$tb.FontSize=17;$tb.Foreground='#AAB7C9';$tb.VerticalAlignment='Center';$tb.HorizontalAlignment='Center';$tb.Padding='0,1,0,4';$empty.Child=$tb;[void]$script:ActionPanel.Children.Add($empty);return
    }
    $available=[double]$script:ActionScrollViewer.ActualWidth;if($available -lt 700){$available=1720}
    $script:HcLibraryColumns=[math]::Max(1,[math]::Floor(($available-12)/240.0))
    $visibleRows=5;try{if($script:ActionScrollViewer.ActualHeight -gt 300){$visibleRows=[math]::Max(4,[math]::Ceiling($script:ActionScrollViewer.ActualHeight/302.0)+1)}}catch{}
    $script:HcLibraryBatchSize=[math]::Max($script:HcLibraryColumns*4,$script:HcLibraryColumns*$visibleRows)
    $script:HcLibraryWrap=New-Object System.Windows.Controls.WrapPanel;$script:HcLibraryWrap.Orientation='Horizontal';$script:HcLibraryWrap.HorizontalAlignment='Stretch';$script:HcLibraryWrap.Margin='0,0,0,28';[void]$script:ActionPanel.Children.Add($script:HcLibraryWrap)
    $minimum=[math]::Max($script:HcLibraryBatchSize,$script:SelectedAction+1);Add-HcLibraryBatch $minimum
    try{
        if($null -ne $script:HcLibraryScrollHandler){$script:ActionScrollViewer.Remove_ScrollChanged($script:HcLibraryScrollHandler)}
        $script:HcLibraryScrollHandler={param($sender,$eventArgs)try{if($script:SelectedTab -eq 1 -and $script:SubPage -eq 'PlatformLibrary' -and ($sender.VerticalOffset+$sender.ViewportHeight) -ge ($sender.ExtentHeight-520)){Add-HcLibraryBatch}}catch{}}
        $script:ActionScrollViewer.Add_ScrollChanged($script:HcLibraryScrollHandler)
    }catch{}
    Update-HcLibraryStatus
}

function Move-HomeVertical {
    param([int]$Delta)
    $active=-1
    for($i=0;$i -lt $script:HomeRows.Count;$i++){if($script:HomeRows[$i].Count -gt 0 -and $script:SelectedAction -ge $script:HomeRows[$i].Start -and $script:SelectedAction -lt ($script:HomeRows[$i].Start+$script:HomeRows[$i].Count)){$active=$i;break}}
    if($active -lt 0){return}
    if($script:SelectedTab -eq 1 -and $script:SubPage -eq 'PlatformLibrary' -and $Delta -gt 0 -and $active -ge ($script:HomeRows.Count-1) -and $script:HcLibraryRenderedCount -lt $script:HcLibraryEntries.Count){Add-HcLibraryBatch}
    $target=$active+$Delta
    while($target -ge 0 -and $target -lt $script:HomeRows.Count -and $script:HomeRows[$target].Count -eq 0){$target+=$Delta}
    if($target -lt 0 -or $target -ge $script:HomeRows.Count){return}
    $column=[math]::Max(0,$script:PreferredRailColumn)
    $script:SelectedAction=$script:HomeRows[$target].Start+[math]::Min($column,$script:HomeRows[$target].Count-1)
    Invoke-UiFeedback 'Navigate';Update-ActionVisuals
}


# -----------------------------------------------------------------------------
# Legacy HES code retained only for migration compatibility; v0.23.5 does not register or expose it.
# HES is a top-level console destination that first presents emulation platforms,
# rather than mixing ROMs into Windows storefront shelves.
# -----------------------------------------------------------------------------
$script:HesPlatformGroups=@()
$script:SelectedHesPlatformKey=''
$script:HesAutoRefreshAttempted=$false

function Test-HesCredentialFile{
    $path=Join-Path $script:DataDir 'GameProviders\Config\HES\client-token.dat'
    return Test-Path -LiteralPath $path -PathType Leaf
}
function Get-HesPlatformGroups{
    $groups=New-Object System.Collections.ArrayList
    $all=@(Get-ProviderGames 'HES')
    foreach($group in @($all|Group-Object { $id=[string](Get-EntryProperty $_ 'PlatformId' '');if($id){return $id};$slug=[string](Get-EntryProperty $_ 'PlatformSlug' '');if($slug){return $slug};return [string](Get-EntryProperty $_ 'Platform' 'Unknown') })){
        $members=@($group.Group)
        $marker=@($members|Where-Object{[bool](Get-EntryProperty $_ 'IsPlatformMarker' $false)}|Select-Object -First 1)
        $entries=@($members|Where-Object{-not [bool](Get-EntryProperty $_ 'IsPlatformMarker' $false)}|Sort-Object {[string](Get-EntryProperty $_ 'Name' 'Game')})
        $source=if($marker.Count -gt 0){$marker[0]}elseif($entries.Count -gt 0){$entries[0]}else{$null}
        if($null -eq $source){continue}
        $name=[string](Get-EntryProperty $source 'Platform' (Get-EntryProperty $source 'Name' 'Unknown platform'))
        $key=[string]$group.Name
        $reported=if($marker.Count -gt 0){[int](Get-EntryProperty $marker[0] 'PlatformGameCount' $entries.Count)}else{$entries.Count}
        $art='';$hero=''
        foreach($entry in @($source)+$entries){
            if(-not $art){$candidate=[string](Get-EntryProperty $entry 'ArtworkPath' '');if($candidate -and (Test-Path -LiteralPath $candidate -PathType Leaf)){$art=$candidate}}
            if(-not $hero){$candidate=[string](Get-EntryProperty $entry 'HeroArtworkPath' '');if($candidate -and (Test-Path -LiteralPath $candidate -PathType Leaf)){$hero=$candidate}}
            if($art -and $hero){break}
        }
        [void]$groups.Add([pscustomobject]@{
            Key=$key;Name=$name;Count=$reported;LoadedCount=$entries.Count;Loaded=($entries.Count -gt 0 -or $reported -eq 0);
            Games=[object[]]$entries;ArtworkPath=$art;HeroArtworkPath=$(if($hero){$hero}else{$art});Source='HES';Installed=$true
        })
    }
    return [object[]]@($groups.ToArray()|Sort-Object Name)
}
function Get-SelectedHesPlatformGroup{
    $script:HesPlatformGroups=@(Get-HesPlatformGroups)
    if($script:HesPlatformGroups.Count -eq 0){return $null}
    $match=@($script:HesPlatformGroups|Where-Object{[string]::Equals([string]$_.Key,[string]$script:SelectedHesPlatformKey,[StringComparison]::OrdinalIgnoreCase)}|Select-Object -First 1)
    if($match.Count -gt 0){return $match[0]}
    $script:SelectedHesPlatformKey=[string]$script:HesPlatformGroups[0].Key
    return $script:HesPlatformGroups[0]
}
function New-HesPlatformCard{
    param($Group,[int]$Index)
    $entry=[pscustomobject]@{Name=[string]$Group.Name;ArtworkPath=[string]$Group.ArtworkPath;HeroArtworkPath=[string]$Group.HeroArtworkPath;Source='HES';Installed=$true}
    $button=New-HomeCard $entry "hes-platform-select:$Index" 'HES Platforms'
    $button.Width=224;$button.Height=316;$button.Margin='0,0,18,18'
    try{
        $badge=New-Object System.Windows.Controls.TextBlock;$badge.Text="$($Group.Count) GAMES";$badge.FontSize=11;$badge.FontWeight='Bold';$badge.Foreground='#E7C45E';$badge.Margin='12,0,12,10';$badge.HorizontalAlignment='Left';$badge.VerticalAlignment='Bottom'
        if($button.Content -is [System.Windows.Controls.Grid]){$button.Content.Children.Add($badge)|Out-Null}
    }catch{}
    return $button
}
function New-HesUtilityButton{
    param([string]$Id,[string]$TitleText,[string]$SubtitleText)
    $button=New-Object System.Windows.Controls.Button
    $button.Tag=$Id;$button.Width=290;$button.Height=92;$button.Margin='0,0,14,12';$button.Padding='18,12';$button.HorizontalContentAlignment='Stretch';$button.Background='#E0141D2B';$button.BorderBrush='#4C6382';$button.BorderThickness='1.5';$button.Cursor='Hand'
    $button.Template=[Windows.Markup.XamlReader]::Parse('<ControlTemplate xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" TargetType="Button"><Border Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="14"><ContentPresenter/></Border></ControlTemplate>')
    $stack=New-Object System.Windows.Controls.StackPanel
    $titleBlock=New-Object System.Windows.Controls.TextBlock;$titleBlock.Text=$TitleText;$titleBlock.FontSize=17;$titleBlock.FontWeight='SemiBold';$titleBlock.Foreground='White';$titleBlock.Padding='0,1,0,3';$stack.Children.Add($titleBlock)|Out-Null
    $subtitleBlock=New-Object System.Windows.Controls.TextBlock;$subtitleBlock.Text=$SubtitleText;$subtitleBlock.FontSize=11;$subtitleBlock.Foreground='#B3C1D2';$subtitleBlock.TextWrapping='Wrap';$subtitleBlock.MaxHeight=38;$subtitleBlock.Padding='0,1,0,3';$stack.Children.Add($subtitleBlock)|Out-Null
    $button.Content=$stack
    $button.Add_Click({
        param($sender,$eventArgs)
        try{Invoke-UiFeedback 'Confirm';Invoke-Action ([string]$sender.Tag)}
        catch{Write-Log "HES action failed: $($_.Exception.Message)" 'ERROR';Set-ConsoleNotice "HES action failed: $($_.Exception.Message)" 'ERROR'}
    })
    $button.Add_MouseEnter({param($sender,$eventArgs)if(-not(Test-HcMouseHoverAllowed)){return};Set-KeyboardActive;$idx=[array]::IndexOf($script:ActionButtons,$sender);if($idx -ge 0){$script:SelectedAction=$idx;Update-ActionVisuals}})
    return $button
}
function Render-HesPlatforms{
    $script:HesPlatformGroups=@(Get-HesPlatformGroups);$script:GameHubLaunchEntries=@();if($script:HesPlatformGroups.Count -gt 0){$script:HesAutoRefreshAttempted=$false}
    $node=Get-ProviderCatalogNode 'HES';$authenticated=([bool](Get-EntryProperty $node 'Authenticated' $false) -or (Test-HesCredentialFile));$status=[string](Get-EntryProperty $node 'Status' $(if($authenticated){'HES credential stored. Refresh the platform index.'}else{'Not connected.'}));$error=[string](Get-EntryProperty $node 'Error' '')
    $heading=New-Object System.Windows.Controls.TextBlock;$heading.Text='Huymaier Entertainment System';$heading.FontSize=32;$heading.FontWeight='Bold';$heading.Foreground='#F5F7FB';$heading.Padding='0,1,0,5';$script:ActionPanel.Children.Add($heading)|Out-Null
    $subtitle=New-Object System.Windows.Controls.TextBlock;$hesReportedTotal=0;foreach($g in @($script:HesPlatformGroups)){$hesReportedTotal+=[int]$g.Count}
    $subtitle.Text=$(if($script:HesPlatformGroups.Count -gt 0){"$($script:HesPlatformGroups.Count) platforms  •  $hesReportedTotal games"}elseif($authenticated){$status}else{'Connect your HES account to browse emulation platforms.'});$subtitle.FontSize=14;$subtitle.Foreground=$(if($error){'#FF9A8E'}else{'#AAB7C9'});$subtitle.Padding='0,1,0,4';$subtitle.Margin='0,0,0,12';$script:ActionPanel.Children.Add($subtitle)|Out-Null
    # Authentication and refresh are primary HES actions. Keep them in a
    # dedicated high-contrast top panel so they cannot disappear into the page.
    $accountHeading=New-Object System.Windows.Controls.TextBlock
    $accountHeading.Text='HES ACCOUNT';$accountHeading.FontSize=12;$accountHeading.FontWeight='Bold';$accountHeading.Foreground='#E7C45E';$accountHeading.Margin='2,0,0,8'
    $script:ActionPanel.Children.Add($accountHeading)|Out-Null
    $quickStart=$script:ActionButtons.Count
    $quickBorder=New-Object System.Windows.Controls.Border
    $quickBorder.Background='#B90A111D';$quickBorder.BorderBrush='#5B6F8B';$quickBorder.BorderThickness='1.5';$quickBorder.CornerRadius=16;$quickBorder.Padding='16,14';$quickBorder.Margin='0,0,0,18'
    $quickRow=New-Object System.Windows.Controls.StackPanel
    $quickRow.Orientation='Horizontal'
    $quickDefs=@(
      @('provider-auth:HES',$(if($authenticated){'Reconnect HES Account'}else{'Connect HES Account'}),'Open the secure HES approval flow in the controller browser.'),
      @('provider-refresh:HES','Refresh HES Library','Reload the HES platform index and available games.')
    )
    foreach($d in $quickDefs){
        $button=New-HesUtilityButton $d[0] $d[1] $d[2]
        $button.Width=360;$button.Height=100;$button.Margin='0,0,16,0'
        $quickRow.Children.Add($button)|Out-Null
        $script:ActionButtons+=$button
        $script:CurrentActions+=(New-Action $d[0] $d[1] $d[2])
    }
    $quickBorder.Child=$quickRow
    $script:ActionPanel.Children.Add($quickBorder)|Out-Null
    $script:HomeRows+=,[pscustomobject]@{Start=$quickStart;Count=$quickDefs.Count;Platform=$false}

    if($authenticated -and $script:HesPlatformGroups.Count -eq 0 -and -not $script:HesAutoRefreshAttempted){
        $providerState=Read-GameProviderState
        $busy=($providerState -and [bool](Get-EntryProperty $providerState 'Busy' $false))
        if(-not $busy){$script:HesAutoRefreshAttempted=$true;Start-GameProviderWorker 'Refresh' 'HES';Set-ConsoleNotice 'Loading HES platforms...' 'INFO'}
    }
    if($script:HesPlatformGroups.Count -gt 0){
        $start=$script:ActionButtons.Count;$wrap=New-Object System.Windows.Controls.WrapPanel;$wrap.Orientation='Horizontal';$wrap.Margin='0,0,0,12'
        for($i=0;$i -lt $script:HesPlatformGroups.Count;$i++){$button=New-HesPlatformCard $script:HesPlatformGroups[$i] $i;$wrap.Children.Add($button)|Out-Null;$script:ActionButtons+=$button;$script:CurrentActions+=(New-Action "hes-platform-select:$i" ([string]$script:HesPlatformGroups[$i].Name))}
        $script:ActionPanel.Children.Add($wrap)|Out-Null
        $columns=[math]::Max(1,[math]::Floor(([math]::Max(900,$script:ActionScrollViewer.ActualWidth)-20)/242.0));for($row=0;$row -lt $script:HesPlatformGroups.Count;$row+=$columns){$script:HomeRows+=,[pscustomobject]@{Start=$start+$row;Count=[math]::Min($columns,$script:HesPlatformGroups.Count-$row);Platform=$false}}
    }else{
        $empty=New-Object System.Windows.Controls.Border;$empty.Height=180;$empty.CornerRadius=16;$empty.Background='#7A101827';$empty.BorderBrush='#2B3A51';$empty.BorderThickness=1;$empty.Margin='0,0,0,18'
        $tb=New-Object System.Windows.Controls.TextBlock;$tb.Text=$(if($error){"HES library refresh failed.`n$error"}elseif($authenticated){"HES is connected, but no games were imported. Refresh now; an empty response will no longer overwrite a populated catalog."}else{'Connect HES through the browser, then refresh the platform library.'});$tb.FontSize=16;$tb.Foreground='#B9C5D4';$tb.TextAlignment='Center';$tb.TextWrapping='Wrap';$tb.VerticalAlignment='Center';$tb.HorizontalAlignment='Center';$tb.MaxWidth=900;$tb.Padding='24';$empty.Child=$tb;$script:ActionPanel.Children.Add($empty)|Out-Null
    }
    $utilityHeading=New-Object System.Windows.Controls.TextBlock;$utilityHeading.Text='HES Connection';$utilityHeading.FontSize=21;$utilityHeading.FontWeight='SemiBold';$utilityHeading.Foreground='#F5F7FB';$utilityHeading.Margin='0,8,0,10';$script:ActionPanel.Children.Add($utilityHeading)|Out-Null
    $start=$script:ActionButtons.Count;$row=New-Object System.Windows.Controls.WrapPanel;$row.Orientation='Horizontal'
    $defs=@(
      @('hes-open-web','Open HES','Open the full HES web interface.'),
      @('hes-connection-settings','Connection Settings','Web address, direct API address, and manual pairing fallback.')
    )
    foreach($d in $defs){$button=New-HesUtilityButton $d[0] $d[1] $d[2];$row.Children.Add($button)|Out-Null;$script:ActionButtons+=$button;$script:CurrentActions+=(New-Action $d[0] $d[1] $d[2])}
    $script:ActionPanel.Children.Add($row)|Out-Null;$script:HomeRows+=,[pscustomobject]@{Start=$start;Count=$defs.Count;Platform=$false}
}
function Render-HesPlatformChoice{
    $group=Get-SelectedHesPlatformGroup;if($null -eq $group){$script:SubPage='HesPlatforms';Render-HesPlatforms;return}
    $heading=New-Object System.Windows.Controls.TextBlock;$heading.Text=[string]$group.Name;$heading.FontSize=34;$heading.FontWeight='Bold';$heading.Foreground='White';$heading.Margin='0,0,0,4';$heading.Padding='0,1,0,5';$script:ActionPanel.Children.Add($heading)|Out-Null
    $sub=New-Object System.Windows.Controls.TextBlock;$providerState=Read-GameProviderState;$loading=($providerState -and [bool](Get-EntryProperty $providerState 'Busy' $false) -and [string](Get-EntryProperty $providerState 'Provider' '') -eq 'HES' -and [string](Get-EntryProperty $providerState 'GameId' '') -eq [string]$group.Key);$sub.Text=$(if($loading){"Loading $($group.Name) games..."}elseif($group.Loaded){"$($group.LoadedCount) of $($group.Count) HES games cached"}else{"$($group.Count) HES games • Select Shelf or Library after loading completes"});$sub.FontSize=14;$sub.Foreground=$(if($loading){'#E7C45E'}else{'#AAB7C9'});$sub.Margin='0,0,0,18';$script:ActionPanel.Children.Add($sub)|Out-Null
    $start=$script:ActionButtons.Count;$row=New-Object System.Windows.Controls.StackPanel;$row.Orientation='Horizontal'
    foreach($d in @(@('hes-platform-shelf','Shelf','Installed games in a cinematic horizontal shelf.'),@('hes-platform-library','Library','Browse every game in one vertical grid.'),@('hes-platforms-back','All Platforms','Return to HES platform selection.'))){$button=New-HesUtilityButton $d[0] $d[1] $d[2];$button.Width=330;$button.Height=140;$row.Children.Add($button)|Out-Null;$script:ActionButtons+=$button;$script:CurrentActions+=(New-Action $d[0] $d[1] $d[2])}
    $script:ActionPanel.Children.Add($row)|Out-Null;$script:HomeRows+=,[pscustomobject]@{Start=$start;Count=3;Platform=$false}
}
function Get-HesSelectedPlatformGames{
    $group=Get-SelectedHesPlatformGroup;if($null -eq $group){return [object[]]@()};return [object[]]@($group.Games)
}
function Render-HcShelfEntries{
    param([object[]]$Entries,[string]$Title,[string]$EmptyText)
    $script:GameHubLaunchEntries=@();$script:ShelfEntries=@($Entries|Sort-Object {[string](Get-EntryProperty $_ 'Name' 'Game')})
    if($script:ShelfEntries.Count -eq 0){Add-GameHubRail $Title @() $EmptyText;return}
    $outer=New-Object System.Windows.Controls.Grid;$height=[double]$script:ActionScrollViewer.ActualHeight;if($height -lt 650){$height=810}else{$height=[math]::Max(690,$height-10)};$outer.Height=$height;$outer.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition -Property @{Height='*'}));$outer.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition -Property @{Height='146'}))
    $hero=New-Object System.Windows.Controls.Border;$hero.CornerRadius=16;$hero.Background='#101722';$hero.BorderBrush='#28FFFFFF';$hero.BorderThickness='1';$hero.ClipToBounds=$true;$heroGrid=New-Object System.Windows.Controls.Grid
    $script:ShelfHeroImage=New-Object System.Windows.Controls.Image;$script:ShelfHeroImage.Stretch='UniformToFill';$script:ShelfHeroImage.Opacity=.92;$heroGrid.Children.Add($script:ShelfHeroImage)|Out-Null
    $script:ShelfHeroFallback=New-Object System.Windows.Controls.Border;$script:ShelfHeroFallback.Background='#182536';$script:ShelfHeroFallback.Child=New-PlatformIconImage 'HES' 180;$heroGrid.Children.Add($script:ShelfHeroFallback)|Out-Null
    $shade=New-Object System.Windows.Shapes.Rectangle;$brush=New-Object System.Windows.Media.LinearGradientBrush;$brush.StartPoint='0,0';$brush.EndPoint='0,1';$brush.GradientStops.Add((New-Object System.Windows.Media.GradientStop -ArgumentList ([System.Windows.Media.ColorConverter]::ConvertFromString('#00101820')),0.15));$brush.GradientStops.Add((New-Object System.Windows.Media.GradientStop -ArgumentList ([System.Windows.Media.ColorConverter]::ConvertFromString('#F006090E')),1.0));$shade.Fill=$brush;$heroGrid.Children.Add($shade)|Out-Null
    $info=New-Object System.Windows.Controls.StackPanel;$info.VerticalAlignment='Bottom';$info.Margin='48,0,48,42'
    $script:ShelfTitleText=New-Object System.Windows.Controls.TextBlock;$script:ShelfTitleText.FontSize=42;$script:ShelfTitleText.FontWeight='Bold';$script:ShelfTitleText.Foreground='White';$script:ShelfTitleText.TextWrapping='Wrap';$script:ShelfTitleText.Padding='0,1,0,5';$info.Children.Add($script:ShelfTitleText)|Out-Null
    $script:ShelfDetailText=New-Object System.Windows.Controls.TextBlock;$script:ShelfDetailText.FontSize=15;$script:ShelfDetailText.Foreground='#E0E6EF';$script:ShelfDetailText.Margin='0,8,0,0';$script:ShelfDetailText.TextWrapping='Wrap';$script:ShelfDetailText.MaxWidth=980;$script:ShelfDetailText.MaxHeight=54;$script:ShelfDetailText.Padding='0,1,0,4';$info.Children.Add($script:ShelfDetailText)|Out-Null
    $script:ShelfMetaText=New-Object System.Windows.Controls.TextBlock;$script:ShelfMetaText.FontSize=12;$script:ShelfMetaText.FontWeight='SemiBold';$script:ShelfMetaText.Foreground='#E7C45E';$script:ShelfMetaText.Margin='0,10,0,0';$script:ShelfMetaText.Padding='0,1,0,3';$info.Children.Add($script:ShelfMetaText)|Out-Null
    $heroGrid.Children.Add($info)|Out-Null;$hero.Child=$heroGrid;$outer.Children.Add($hero)|Out-Null
    $carouselBorder=New-Object System.Windows.Controls.Border;$carouselBorder.Background='#A0080B10';$carouselBorder.BorderBrush='#28FFFFFF';$carouselBorder.BorderThickness='1,0,0,0';$carouselBorder.CornerRadius=14;$carouselBorder.Padding='14,5,14,0';[System.Windows.Controls.Grid]::SetRow($carouselBorder,1)
    $row=New-Object System.Windows.Controls.StackPanel;$row.Orientation='Horizontal';$row.VerticalAlignment='Center'
    for($i=0;$i -lt $script:ShelfEntries.Count;$i++){$entry=$script:ShelfEntries[$i];$script:GameHubLaunchEntries+=$entry;$button=New-HcShelfCard $entry "hub-game:$i";$row.Children.Add($button)|Out-Null;$script:ActionButtons+=$button;$script:CurrentActions+=(New-Action "hub-game:$i" ([string](Get-EntryProperty $entry 'Name' 'Game')))}
    $scroll=New-Object System.Windows.Controls.ScrollViewer;$scroll.HorizontalScrollBarVisibility='Hidden';$scroll.VerticalScrollBarVisibility='Disabled';$scroll.PanningMode='HorizontalOnly';$scroll.Content=$row;$carouselBorder.Child=$scroll;$outer.Children.Add($carouselBorder)|Out-Null;$script:ActionPanel.Children.Add($outer)|Out-Null;$script:HomeRows+=,[pscustomobject]@{Start=0;Count=$script:ShelfEntries.Count;Platform=$false};Update-ShelfSelection
}
function Render-HesPlatformShelf{$group=Get-SelectedHesPlatformGroup;if($null -eq $group){$script:SubPage='HesPlatforms';Render-HesPlatforms;return};$script:SelectedGamePlatform=[string]$group.Name;Render-HcShelfEntries (Get-HesSelectedPlatformGames) "$($group.Name) Shelf" "No games are available for $($group.Name)."}
function Render-HcLibraryEntries{
    param([object[]]$Entries,[string]$Title,[string]$EmptyText)
    $script:HcLibraryEntries=@($Entries|Sort-Object {[string](Get-EntryProperty $_ 'Name' 'Game')});$script:GameHubLaunchEntries=[object[]]$script:HcLibraryEntries;$script:HcLibraryRenderedCount=0;$script:HcLibraryWrap=$null;$script:HcLibraryStatusText=$null
    $heading=New-Object System.Windows.Controls.TextBlock;$heading.Text=$Title;$heading.FontSize=30;$heading.FontWeight='Bold';$heading.Foreground='#F5F7FB';$heading.Padding='0,1,0,4';$heading.Margin='0,0,0,2';$script:ActionPanel.Children.Add($heading)|Out-Null
    $script:HcLibraryStatusText=New-Object System.Windows.Controls.TextBlock;$script:HcLibraryStatusText.FontSize=13;$script:HcLibraryStatusText.Foreground='#AAB7C9';$script:HcLibraryStatusText.Padding='0,1,0,3';$script:HcLibraryStatusText.Margin='0,0,0,16';$script:ActionPanel.Children.Add($script:HcLibraryStatusText)|Out-Null
    if($script:HcLibraryEntries.Count -eq 0){$empty=New-Object System.Windows.Controls.Border;$empty.Height=150;$empty.CornerRadius=14;$empty.Background='#7A101827';$empty.BorderBrush='#2B3A51';$empty.BorderThickness=1;$tb=New-Object System.Windows.Controls.TextBlock;$tb.Text=$EmptyText;$tb.FontSize=17;$tb.Foreground='#AAB7C9';$tb.VerticalAlignment='Center';$tb.HorizontalAlignment='Center';$tb.Padding='0,1,0,4';$empty.Child=$tb;$script:ActionPanel.Children.Add($empty)|Out-Null;return}
    $available=[double]$script:ActionScrollViewer.ActualWidth;if($available -lt 700){$available=1720};$script:HcLibraryColumns=[math]::Max(1,[math]::Floor(($available-12)/240.0));$visibleRows=5;try{if($script:ActionScrollViewer.ActualHeight -gt 300){$visibleRows=[math]::Max(4,[math]::Ceiling($script:ActionScrollViewer.ActualHeight/302.0)+1)}}catch{};$script:HcLibraryBatchSize=[math]::Max($script:HcLibraryColumns*4,$script:HcLibraryColumns*$visibleRows)
    $script:HcLibraryWrap=New-Object System.Windows.Controls.WrapPanel;$script:HcLibraryWrap.Orientation='Horizontal';$script:HcLibraryWrap.HorizontalAlignment='Stretch';$script:HcLibraryWrap.Margin='0,0,0,28';$script:ActionPanel.Children.Add($script:HcLibraryWrap)|Out-Null;Add-HcLibraryBatch ([math]::Max($script:HcLibraryBatchSize,$script:SelectedAction+1))
    try{if($null -ne $script:HcLibraryScrollHandler){$script:ActionScrollViewer.Remove_ScrollChanged($script:HcLibraryScrollHandler)};$script:HcLibraryScrollHandler={param($sender,$eventArgs)try{if($script:SelectedTab -eq 1 -and $script:SubPage -in @('PlatformLibrary','HesPlatformLibrary') -and ($sender.VerticalOffset+$sender.ViewportHeight) -ge ($sender.ExtentHeight-520)){Add-HcLibraryBatch}}catch{}};$script:ActionScrollViewer.Add_ScrollChanged($script:HcLibraryScrollHandler)}catch{};Update-HcLibraryStatus
}
function Render-HesPlatformLibrary{$group=Get-SelectedHesPlatformGroup;if($null -eq $group){$script:SubPage='HesPlatforms';Render-HesPlatforms;return};$script:SelectedGamePlatform=[string]$group.Name;Render-HcLibraryEntries (Get-HesSelectedPlatformGames) "$($group.Name) Library" "No games are available for $($group.Name)."}

# Keep the existing handlers available, then layer HES-specific behavior on top.
$script:Hc175BaseGameExperienceAction=${function:Invoke-HcGameExperienceAction}
function Invoke-HcGameExperienceAction{
    param([string]$Id)
    if($Id -match '^hes-platform-select:(\d+)$'){$index=[int]$matches[1];$script:HesPlatformGroups=@(Get-HesPlatformGroups);if($index -ge 0 -and $index -lt $script:HesPlatformGroups.Count){$group=$script:HesPlatformGroups[$index];$script:SelectedHesPlatformKey=[string]$group.Key;$script:SubPage='HesPlatformChoice';$script:SelectedAction=0;if(-not [bool]$group.Loaded -and [int]$group.Count -gt 0){Start-GameProviderWorker 'Refresh' 'HES' ([string]$group.Key) ([string]$group.Name);Set-ConsoleNotice "Loading $($group.Name) from HES..." 'INFO'};Render-Page};return $true}
    switch($Id){
      'hes-platform-shelf' {$group=Get-SelectedHesPlatformGroup;if($null -ne $group -and -not [bool]$group.Loaded -and [int]$group.Count -gt 0){Start-GameProviderWorker 'Refresh' 'HES' ([string]$group.Key) ([string]$group.Name);Set-ConsoleNotice "Loading $($group.Name) from HES..." 'INFO';return $true};$script:SubPage='HesPlatformShelf';$script:SelectedAction=0;Render-Page;return $true}
      'hes-platform-library' {$group=Get-SelectedHesPlatformGroup;if($null -ne $group -and -not [bool]$group.Loaded -and [int]$group.Count -gt 0){Start-GameProviderWorker 'Refresh' 'HES' ([string]$group.Key) ([string]$group.Name);Set-ConsoleNotice "Loading $($group.Name) from HES..." 'INFO';return $true};$script:SubPage='HesPlatformLibrary';$script:SelectedAction=0;Render-Page;return $true}
      'hes-platforms-back' {$script:SubPage='HesPlatforms';$script:SelectedAction=0;Render-Page;return $true}
      'hes-open-web' {$url=[string](Get-EntryProperty $script:Config 'HesServerUrl' 'https://games.huymaiers.com');if(Get-Command Open-HuymaierBrowser -ErrorAction SilentlyContinue){Open-HuymaierBrowser $url 'HES'}else{Start-UriOrShellTarget $url};return $true}
      'hes-connection-settings' {$script:SubPage='HesSettings';$script:SelectedAction=0;Render-Page;return $true}
    }
    return [bool](& $script:Hc175BaseGameExperienceAction $Id)
}
$script:Hc175BaseGameExperienceBack=${function:Handle-HcGameExperienceBack}
function Handle-HcGameExperienceBack{
    if(Test-HcMainMenuVisible -or Test-HcGameModalVisible -or $script:SubPage -in @('GameProperties','GameDetail')){return [bool](& $script:Hc175BaseGameExperienceBack)}
    if($script:SelectedTab -eq 1){
        switch($script:SubPage){
          'HesPlatformShelf' {Invoke-UiFeedback 'Back';$script:SubPage='HesPlatformChoice';$script:SelectedAction=0;Render-Page;return $true}
          'HesPlatformLibrary' {Invoke-UiFeedback 'Back';$script:SubPage='HesPlatformChoice';$script:SelectedAction=1;Render-Page;return $true}
          'HesPlatformChoice' {Invoke-UiFeedback 'Back';$script:SubPage='HesPlatforms';$script:SelectedAction=0;Render-Page;return $true}
          'HesSettings' {Invoke-UiFeedback 'Back';$script:SubPage='HesPlatforms';$script:SelectedAction=0;Render-Page;return $true}
          'HesPlatforms' {Invoke-UiFeedback 'Back';Show-HcMainMenu;return $true}
        }
    }
    return [bool](& $script:Hc175BaseGameExperienceBack)
}
function Get-HcMainMenuEntries{
    return @(
        [pscustomobject]@{Title='Home';Icon='⌂';Tab=0;Mode='Tab';Subtitle='Recently played and quick access'},
        [pscustomobject]@{Title='Library';Icon='▦';Tab=1;Mode='Library';Subtitle='PC storefront shelves and complete game library'},
        [pscustomobject]@{Title='Apps';Icon='◈';Tab=2;Mode='Tab';Subtitle='Storefronts and installed applications'},
        [pscustomobject]@{Title='Web';Icon='◎';Tab=3;Mode='Tab';Subtitle='Controller-friendly browser'},
        [pscustomobject]@{Title='Downloads';Icon='↓';Tab=4;Mode='Tab';Subtitle='Install, update, verify, and move progress'},
        [pscustomobject]@{Title='Import';Icon='＋';Tab=5;Mode='Tab';Subtitle='Discover local game libraries'},
        [pscustomobject]@{Title='File Explorer';Icon='▱';Tab=6;Mode='Tab';Subtitle='Browse files and folders'},
        [pscustomobject]@{Title='Settings';Icon='⚙';Tab=7;Mode='Tab';Subtitle='Display, audio, controllers, and console options'},
        [pscustomobject]@{Title='Power';Icon='⏻';Tab=8;Mode='Tab';Subtitle='Sleep, restart, shut down, or exit'}
    )
}
function Show-HcMainMenu{
    if($null -eq $script:MainMenuOverlay){Focus-TopNavigation;return};if(Test-HcMainMenuVisible){Close-HcMainMenu;return};if(Test-HcGameModalVisible){Close-HcGameModal}
    $script:HcMainMenuEntries=@(Get-HcMainMenuEntries);$script:HcMainMenuButtons=@();$script:HcMainMenuSelected=0
    for($i=0;$i -lt $script:HcMainMenuEntries.Count;$i++){$entry=$script:HcMainMenuEntries[$i];$mode=[string](Get-EntryProperty $entry 'Mode' 'Tab');if($script:SelectedTab -eq 1 -and $script:SubPage -like 'Hes*' -and $mode -eq 'HES'){$script:HcMainMenuSelected=$i;break};if(-($script:SelectedTab -eq 1 -and $script:SubPage -like 'Hes*') -and [int]$entry.Tab -eq [int]$script:SelectedTab -and $mode -ne 'HES'){$script:HcMainMenuSelected=$i;break}}
    $script:MainMenuPanel.Children.Clear();for($i=0;$i -lt $script:HcMainMenuEntries.Count;$i++){$button=New-HcMainMenuButton $script:HcMainMenuEntries[$i] $i;$script:MainMenuPanel.Children.Add($button)|Out-Null;$script:HcMainMenuButtons+=$button}
    $script:NavigationLayer='Content';$script:MainMenuOverlay.Visibility='Visible';Set-HcShellBlur $true;Update-HcMainMenuVisuals;Update-Footer
}
function Invoke-HcMainMenuSelected{
    if($script:HcMainMenuSelected -lt 0 -or $script:HcMainMenuSelected -ge $script:HcMainMenuEntries.Count){return}
    $entry=$script:HcMainMenuEntries[$script:HcMainMenuSelected];$tab=[int]$entry.Tab;$mode=[string](Get-EntryProperty $entry 'Mode' 'Tab');Invoke-UiFeedback 'Confirm';Close-HcMainMenu
    # Keep the embedded browser alive only while remaining on the Web page.
    if($script:HcBrowserActive -and -not ($mode -eq 'Tab' -and $tab -eq 3)){
        if(Get-Command Close-HuymaierBrowser -ErrorAction SilentlyContinue){Close-HuymaierBrowser}
    }
    if($mode -eq 'HES'){$script:SelectedTab=1;$script:SubPage='HesPlatforms';$script:SelectedAction=0;$script:PreferredRailColumn=0;Render-Page;Update-NavVisuals}
    else{Set-Tab $tab}
    $script:NavigationLayer='Content';Update-ActionVisuals
}
function Render-HesSettings{
    $heading=New-Object System.Windows.Controls.TextBlock;$heading.Text='HES Connection Settings';$heading.FontSize=30;$heading.FontWeight='Bold';$heading.Foreground='White';$heading.Margin='0,0,0,16';$script:ActionPanel.Children.Add($heading)|Out-Null
    $defs=@(
      @('provider-hes-url','HES Web Address',[string](Get-EntryProperty $script:Config 'HesServerUrl' 'https://games.huymaiers.com')),
      @('provider-hes-api-url','Direct RomM API Address',[string](Get-EntryProperty $script:Config 'HesApiUrl' '')),
      @('provider-hes-pair-manual','Manual Pairing Fallback','Enter an eight-digit RomM client pairing code.'),
      @('hes-platforms-back','Back to HES','Return to platform selection.')
    )
    $start=$script:ActionButtons.Count
    foreach($d in $defs){$button=New-HesUtilityButton $d[0] $d[1] $d[2];$button.Width=760;$script:ActionPanel.Children.Add($button)|Out-Null;$script:ActionButtons+=$button;$script:CurrentActions+=(New-Action $d[0] $d[1] $d[2]);$script:HomeRows+=,[pscustomobject]@{Start=$script:ActionButtons.Count-1;Count=1;Platform=$false}}
}
function Render-GamesHub{
    $script:GameHubPlatforms=Get-GameHubPlatforms;if($script:GameHubPlatforms.Count -eq 0){$script:GameHubPlatforms=@('Steam')};if(-not (@($script:GameHubPlatforms)|Where-Object{[string]::Equals([string]$_,$script:SelectedGamePlatform,[StringComparison]::OrdinalIgnoreCase)}) -and $script:SubPage -notlike 'Hes*'){$script:SelectedGamePlatform=[string]$script:GameHubPlatforms[0]};$script:GameHubLaunchEntries=@()
    switch($script:SubPage){
      'HesPlatforms' {Render-HesPlatforms}
      'HesPlatformChoice' {Render-HesPlatformChoice}
      'HesPlatformShelf' {Render-HesPlatformShelf}
      'HesPlatformLibrary' {Render-HesPlatformLibrary}
      'HesSettings' {Render-HesSettings}
      'PlatformChoice' {Add-PlatformChoiceRail}
      'PlatformHome' {Render-PlatformHome}
      'PlatformShelf' {Render-PlatformShelf}
      'PlatformLibrary' {Render-PlatformLibrary}
      'ProviderStore' {Render-GameProviderStore $script:SelectedGamePlatform}
      'GameDetail' {Render-HcGameDetail}
      'GameProperties' {Render-HcGameProperties}
      default {Add-PlatformRail}
    }
}
function Use-HorizontalRailNavigation{
    if($script:SelectedTab -eq 0 -and -not $script:SubPage){return $true}
    if($script:SelectedTab -eq 1 -and $script:SubPage -in @('','PlatformChoice','PlatformHome','PlatformShelf','PlatformLibrary','GameDetail','HesPlatforms','HesPlatformChoice','HesPlatformShelf','HesPlatformLibrary')){return $true}
    if($script:SelectedTab -eq 2 -and -not $script:SubPage){return $true};return $false
}
$script:Hc175BaseUpdateShelfSelection=${function:Update-ShelfSelection}
function Update-ShelfSelection{
    if($script:SubPage -notin @('PlatformShelf','HesPlatformShelf') -or @($script:ShelfEntries).Count -eq 0){return}
    $index=[math]::Max(0,[math]::Min($script:SelectedAction,$script:ShelfEntries.Count-1));$entry=$script:ShelfEntries[$index];$name=[string](Get-EntryProperty $entry 'Name' 'Game');$description=[string](Get-EntryProperty $entry 'Description' '');if($description.Length -gt 260){$description=$description.Substring(0,257)+'...'};if(-not $description){$description='Select to open the game page.'};$provider=[string](Get-EntryProperty $entry 'Source' 'HES');$size=[string](Get-EntryProperty $entry 'SizeText' '');$heroPath=Get-HcPreferredHeroPath $entry
    if($null -ne $script:ShelfHeroImage){$script:ShelfHeroImage.Source=Get-ImageSourceFromPath $heroPath 1600;$script:ShelfHeroImage.Visibility=$(if($heroPath){'Visible'}else{'Collapsed'})};if($null -ne $script:ShelfHeroFallback){$script:ShelfHeroFallback.Visibility=$(if($heroPath){'Collapsed'}else{'Visible'})};if($null -ne $script:ShelfTitleText){$script:ShelfTitleText.Text=$name};if($null -ne $script:ShelfDetailText){$script:ShelfDetailText.Text=$description};if($null -ne $script:ShelfMetaText){$meta=New-Object System.Collections.ArrayList;[void]$meta.Add($provider.ToUpperInvariant());[void]$meta.Add(([string](Get-EntryProperty $entry 'Platform' $script:SelectedGamePlatform)).ToUpperInvariant());if($size){[void]$meta.Add($size)};if(-not $heroPath){[void]$meta.Add('ARTWORK RESTORING')};$script:ShelfMetaText.Text=(@($meta)-join '  •  ')}
}

# Keep HES out of the normal PC storefront platform rail; it is reached from
# the dedicated top-level HES menu entry instead.
$script:Hc175BaseGetGameHubPlatforms=${function:Get-GameHubPlatforms}
function Get-GameHubPlatforms{
    return [object[]]@((& $script:Hc175BaseGetGameHubPlatforms)|Where-Object{-not [string]::Equals([string]$_,'HES',[StringComparison]::OrdinalIgnoreCase)})
}
$script:Hc175BaseSecondaryLabel=${function:Get-StorefrontSecondaryLabel}
function Get-StorefrontSecondaryLabel{
    if($script:SelectedTab -eq 1 -and $script:SubPage -in @('HesPlatformShelf','HesPlatformLibrary')){return 'Manage'}
    return [string](& $script:Hc175BaseSecondaryLabel)
}
$script:Hc175BaseSecondaryAction=${function:Invoke-SecondaryAction}
function Invoke-SecondaryAction{
    if($script:SelectedTab -eq 1 -and $script:SubPage -in @('HesPlatformShelf','HesPlatformLibrary') -and $script:SelectedAction -ge 0 -and $script:SelectedAction -lt $script:ActionButtons.Count){
        $id=[string]$script:ActionButtons[$script:SelectedAction].Tag
        if($id -match '^hub-game:(\d+)$'){$index=[int]$matches[1];if($index -ge 0 -and $index -lt $script:GameHubLaunchEntries.Count){Open-HcGameDetail $script:GameHubLaunchEntries[$index];Show-HcGameModal 'Manage'};return}
    }
    & $script:Hc175BaseSecondaryAction
}


# v0.23.5: show the Library immediately, then build cards and decode artwork in bounded batches.
$script:HcLibraryBuildGeneration=0
$script:HcLibraryArtworkQueue=New-Object System.Collections.Queue
$script:HcLibraryBuildTimer=$null
$script:HcLibraryArtworkTimer=$null
function New-HcDeferredLibraryCard {
    param($Entry,[int]$Index)
    $copy=[pscustomobject]@{}
    foreach($property in $Entry.PSObject.Properties){$copy|Add-Member -NotePropertyName $property.Name -NotePropertyValue $property.Value -Force}
    $path=Get-HcPreferredCoverPath $Entry
    foreach($name in @('ArtworkPath','IconPath','BoxArtPath','ImagePath')){if($copy.PSObject.Properties[$name]){$copy.$name=''}}
    $button=New-HomeCard $copy "hub-game:$Index" 'Library';$button.Width=220;$button.Height=330;$button.Margin='0,0,20,20'
    if($path){$script:HcLibraryArtworkQueue.Enqueue([pscustomobject]@{Button=$button;Path=$path})}
    return $button
}
function Start-HcLibraryArtworkPump {
    if($null -ne $script:HcLibraryArtworkTimer){try{$script:HcLibraryArtworkTimer.Stop()}catch{}}
    $script:HcLibraryArtworkGeneration=[int]$script:HcLibraryBuildGeneration
    $script:HcLibraryArtworkTimer=New-Object System.Windows.Threading.DispatcherTimer
    $script:HcLibraryArtworkTimer.Interval=[TimeSpan]::FromMilliseconds(16)
    $script:HcLibraryArtworkHandler={param($sender,$eventArgs)
        if(-not [object]::ReferenceEquals($sender,$script:HcLibraryArtworkTimer) -or $script:HcLibraryArtworkGeneration -ne $script:HcLibraryBuildGeneration -or $script:SelectedTab -ne 1 -or $script:SubPage -ne 'PlatformLibrary'){try{$sender.Stop()}catch{};return}
        if($script:HcLibraryArtworkQueue.Count -eq 0){try{$sender.Stop()}catch{};return}
        $job=$script:HcLibraryArtworkQueue.Dequeue();try{
            $source=Get-ImageSourceFromPath ([string]$job.Path) 420
            if($null -ne $source -and $job.Button.Content -is [System.Windows.Controls.Grid]){
                $grid=$job.Button.Content
                # Remove only the generated artwork-pending background/case; keep title, badges and shade.
                $remove=New-Object System.Collections.ArrayList
                foreach($child in @($grid.Children)){
                    if($child -is [System.Windows.Shapes.Rectangle] -and $child.VerticalAlignment -ne 'Bottom'){[void]$remove.Add($child);continue}
                    if($child -is [System.Windows.Controls.Border] -and $child.Width -eq 132 -and $child.Height -eq 166){[void]$remove.Add($child)}
                }
                foreach($child in @($remove)){[void]$grid.Children.Remove($child)}
                $image=New-Object System.Windows.Controls.Image;$image.Source=$source;$image.Stretch='UniformToFill';$image.Opacity=.96;$image.IsHitTestVisible=$false
                [void]$grid.Children.Insert(0,$image)
            }
        }catch{}
    }
    $script:HcLibraryArtworkTimer.Add_Tick($script:HcLibraryArtworkHandler)
    $script:HcLibraryArtworkTimer.Start()
}

function Add-HcLibraryBatch {
    param([int]$MinimumCount=0)
    if($script:HcLibraryAppending -or $null -eq $script:HcLibraryWrap){return}
    if($script:HcLibraryRenderedCount -ge $script:HcLibraryEntries.Count){Update-HcLibraryStatus;return}
    $script:HcLibraryAppending=$true
    try{
        $step=[math]::Max(1,$script:HcLibraryColumns)
        $target=[math]::Max($script:HcLibraryRenderedCount+$step,$MinimumCount)
        $target=[math]::Min($target,$script:HcLibraryEntries.Count)
        for($i=$script:HcLibraryRenderedCount;$i -lt $target;$i++){
            $button=New-HcDeferredLibraryCard $script:HcLibraryEntries[$i] $i
            [void]$script:HcLibraryWrap.Children.Add($button);$script:ActionButtons+=$button;$script:CurrentActions+=(New-Action "hub-game:$i" ([string](Get-EntryProperty $script:HcLibraryEntries[$i] 'Name' 'Game')))
        }
        $script:HcLibraryRenderedCount=$target
        $script:HomeRows=@($script:HomeRows|Where-Object{-not [bool](Get-EntryProperty $_ 'LibraryGrid' $false)})
        for($start=0;$start -lt $script:HcLibraryRenderedCount;$start+=$script:HcLibraryColumns){$script:HomeRows+=,[pscustomobject]@{Start=$start;Count=[math]::Min($script:HcLibraryColumns,$script:HcLibraryRenderedCount-$start);Platform=$false;LibraryGrid=$true}}
        Update-HcLibraryStatus
    }finally{$script:HcLibraryAppending=$false}
}
function Render-PlatformLibrary {
    $script:HcLibraryBuildGeneration++
    $script:HcLibraryActiveGeneration=[int]$script:HcLibraryBuildGeneration
    $script:HcLibraryActivePlatform=[string]$script:SelectedGamePlatform
    foreach($timerName in @('HcLibraryInitialTimer','HcLibraryBuildTimer','HcLibraryArtworkTimer')){try{$timer=Get-Variable -Name $timerName -Scope Script -ValueOnly -ErrorAction SilentlyContinue;if($null -ne $timer){$timer.Stop()}}catch{}}
    $script:HcLibraryArtworkQueue=New-Object System.Collections.Queue
    $script:HcLibraryEntries=@();$script:GameHubLaunchEntries=@();$script:HcLibraryRenderedCount=0;$script:HcLibraryWrap=$null;$script:HcLibraryStatusText=$null
    $heading=New-Object System.Windows.Controls.TextBlock;$heading.Text="$($script:HcLibraryActivePlatform) Library";$heading.FontSize=30;$heading.FontWeight='Bold';$heading.Foreground='#F5F7FB';$heading.Margin='0,0,0,2';[void]$script:ActionPanel.Children.Add($heading)
    $script:HcLibraryStatusText=New-Object System.Windows.Controls.TextBlock;$script:HcLibraryStatusText.Text='Loading library index...';$script:HcLibraryStatusText.FontSize=13;$script:HcLibraryStatusText.Foreground='#AAB7C9';$script:HcLibraryStatusText.Margin='0,0,0,16';[void]$script:ActionPanel.Children.Add($script:HcLibraryStatusText)
    $script:HcLibraryWrap=New-Object System.Windows.Controls.WrapPanel;$script:HcLibraryWrap.Orientation='Horizontal';$script:HcLibraryWrap.HorizontalAlignment='Stretch';$script:HcLibraryWrap.Margin='0,0,0,28';[void]$script:ActionPanel.Children.Add($script:HcLibraryWrap)

    # Let WPF render the page header before indexing, sorting, card creation or image decoding.
    $script:HcLibraryInitialTimer=New-Object System.Windows.Threading.DispatcherTimer
    $script:HcLibraryInitialTimer.Interval=[TimeSpan]::FromMilliseconds(16)
    $script:HcLibraryInitialHandler={param($sender,$eventArgs)
        try{$sender.Stop()}catch{}
        if(-not [object]::ReferenceEquals($sender,$script:HcLibraryInitialTimer) -or $script:HcLibraryActiveGeneration -ne $script:HcLibraryBuildGeneration -or $script:SelectedTab -ne 1 -or $script:SubPage -ne 'PlatformLibrary' -or -not [string]::Equals([string]$script:SelectedGamePlatform,[string]$script:HcLibraryActivePlatform,[StringComparison]::OrdinalIgnoreCase)){return}
        $raw=@(Get-PlatformLibraryGames $script:HcLibraryActivePlatform|Sort-Object {[string](Get-EntryProperty $_ 'Name' '')})
        $script:HcLibraryEntries=@($raw);$script:GameHubLaunchEntries=[object[]]$script:HcLibraryEntries
        if($script:HcLibraryEntries.Count -eq 0){
            $script:HcLibraryStatusText.Text='0 owned  •  0 installed'
            $empty=New-Object System.Windows.Controls.TextBlock;$empty.Text="No $($script:HcLibraryActivePlatform) games are imported yet.";$empty.FontSize=17;$empty.Foreground='#AAB7C9';[void]$script:HcLibraryWrap.Children.Add($empty);return
        }
        $available=[double]$script:ActionScrollViewer.ActualWidth;if($available -lt 700){$available=1720};$script:HcLibraryColumns=[math]::Max(1,[math]::Floor(($available-12)/240.0))
        Add-HcLibraryBatch $script:HcLibraryColumns
        Start-HcLibraryArtworkPump
        $script:HcLibraryBuildTimerGeneration=[int]$script:HcLibraryActiveGeneration
        $script:HcLibraryBuildTimer=New-Object System.Windows.Threading.DispatcherTimer;$script:HcLibraryBuildTimer.Interval=[TimeSpan]::FromMilliseconds(70)
        $script:HcLibraryBuildHandler={param($buildSender,$buildEventArgs)
            if(-not [object]::ReferenceEquals($buildSender,$script:HcLibraryBuildTimer) -or $script:HcLibraryBuildTimerGeneration -ne $script:HcLibraryBuildGeneration -or $script:SelectedTab -ne 1 -or $script:SubPage -ne 'PlatformLibrary'){try{$buildSender.Stop()}catch{};return}
            Add-HcLibraryBatch
            if($script:HcLibraryRenderedCount -ge [math]::Min($script:HcLibraryEntries.Count,$script:HcLibraryColumns*6)){try{$buildSender.Stop()}catch{}}
            if($script:HcLibraryArtworkQueue.Count -gt 0 -and ($null -eq $script:HcLibraryArtworkTimer -or -not $script:HcLibraryArtworkTimer.IsEnabled)){Start-HcLibraryArtworkPump}
        }
        $script:HcLibraryBuildTimer.Add_Tick($script:HcLibraryBuildHandler)
        $script:HcLibraryBuildTimer.Start()
        try{
            if($null -ne $script:HcLibraryScrollHandler){$script:ActionScrollViewer.Remove_ScrollChanged($script:HcLibraryScrollHandler)}
            $script:HcLibraryScrollHandler={param($scrollSender,$scrollEventArgs)try{if($script:HcLibraryActiveGeneration -ne $script:HcLibraryBuildGeneration -or $script:SelectedTab -ne 1 -or $script:SubPage -ne 'PlatformLibrary'){return};if(($scrollSender.VerticalOffset+$scrollSender.ViewportHeight) -ge ($scrollSender.ExtentHeight-520)){Add-HcLibraryBatch;if($script:HcLibraryArtworkQueue.Count -gt 0){Start-HcLibraryArtworkPump}}}catch{}}
            $script:ActionScrollViewer.Add_ScrollChanged($script:HcLibraryScrollHandler)
        }catch{}
        Update-HcLibraryStatus
    }
    $script:HcLibraryInitialTimer.Add_Tick($script:HcLibraryInitialHandler)
    $script:HcLibraryInitialTimer.Start()
}

