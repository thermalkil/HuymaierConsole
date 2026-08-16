# HUYMAIER_USER_3D_MODELS_RUNTIME_V7
# HUYMAIER_D3D11_GPU_SHELVES_V1
# Final Games 3D implementation. V6 remains loaded only for stable model-name,
# provider classification, Settings and action compatibility helpers.
Set-StrictMode -Version 2.0

$script:HcPlatformPresentationOwner='HuymaierGpuPlatformShelvesV7'
$script:HcGpuShelfCacheQuality=512
$script:HcGpuShelfCacheDir=Join-Path $script:DataDir '3D Model Cache'
$script:HcGpuShelfCompilerExe=Join-Path $script:BaseDir 'HuymaierGpuShelfAssetCompiler.exe'
$script:HcGpuShelfNativeDll=Join-Path $script:BaseDir 'HuymaierD3D11ShelfRenderer.dll'
$script:HcGpuShelfRuntimeReady=$false
$script:HcGpuShelfCompileQueue=New-Object System.Collections.ArrayList
$script:HcGpuShelfCompileProcess=$null
$script:HcGpuShelfCompileCard=$null
$script:HcGpuShelfCompileTimer=$null
$script:HcGpuShelfGroups=@{}
$script:HcGpuShelfGeneration=0

function Initialize-HcGpuShelfRuntime {
    if($script:HcGpuShelfRuntimeReady){return $true}
    try{
        if(-not(Test-Path -LiteralPath $script:HcGpuShelfNativeDll -PathType Leaf)){throw 'HuymaierD3D11ShelfRenderer.dll is missing.'}
        if(-not(Test-Path -LiteralPath $script:HcGpuShelfCompilerExe -PathType Leaf)){throw 'HuymaierGpuShelfAssetCompiler.exe is missing.'}
        New-Item -ItemType Directory -Force -Path $script:HcGpuShelfCacheDir|Out-Null
        if(($env:PATH -split ';') -notcontains $script:BaseDir){$env:PATH=$script:BaseDir+';'+$env:PATH}
        if(-not(Initialize-HcLiveModelAssembly)){throw 'HuymaierLiveModel3D.dll could not be loaded.'}
        $type=[type]::GetType('HuymaierConsole.Modeling.D3D11ShelfSurface, HuymaierLiveModel3D',$false)
        if($null-eq$type){
            try{$type=[HuymaierConsole.Modeling.D3D11ShelfSurface]}catch{}
        }
        if($null-eq$type){throw 'D3D11ShelfSurface type is unavailable.'}
        $script:HcGpuShelfRuntimeReady=$true
        try{Write-Log 'D3D11 GPU shelf runtime initialized.'}catch{}
        return $true
    }catch{
        try{Write-Log ('D3D11 GPU shelf runtime unavailable; retaining compatibility visuals: '+$_.Exception.Message) 'WARN'}catch{}
        return $false
    }
}

function Get-HcGpuShelfCachePath([string]$ModelPath){
    if([string]::IsNullOrWhiteSpace($ModelPath)){return $null}
    $name=[IO.Path]::GetFileName($ModelPath)
    if([string]::IsNullOrWhiteSpace($name)){return $null}
    return (Join-Path $script:HcGpuShelfCacheDir ($name+'.hc3d'))
}

function Test-HcGpuShelfCacheCurrent([string]$ModelPath,[string]$CachePath){
    if(-not(Test-Path -LiteralPath $ModelPath -PathType Leaf)-or-not(Test-Path -LiteralPath $CachePath -PathType Leaf)){return $false}
    $stream=$null;$reader=$null
    try{
        $source=Get-Item -LiteralPath $ModelPath -ErrorAction Stop
        $stream=[IO.File]::Open($CachePath,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::ReadWrite)
        $reader=New-Object IO.BinaryReader($stream)
        $magic=-join$reader.ReadChars(4)
        if($magic-ne'HC3D'){return $false}
        if($reader.ReadInt32()-ne1){return $false}
        if($reader.ReadInt64()-ne[int64]$source.Length){return $false}
        if($reader.ReadInt64()-ne[int64]$source.LastWriteTimeUtc.Ticks){return $false}
        return ($reader.ReadInt32()-eq[int]$script:HcGpuShelfCacheQuality)
    }catch{return $false}
    finally{if($reader){$reader.Dispose()}elseif($stream){$stream.Dispose()}}
}

function Get-HcGpuShelfDimensions {
    $screenHeight=1080.0
    try{$screenHeight=[double][System.Windows.SystemParameters]::PrimaryScreenHeight}catch{}
    if($screenHeight-lt720){$screenHeight=720}
    $provider=[math]::Max(300,[math]::Min(620,[math]::Round($screenHeight*.32)))
    $console=[math]::Max(360,[math]::Min(760,[math]::Round($screenHeight*.38)))
    [pscustomobject]@{Providers=$provider;Consoles=$console}
}

function Get-HcGpuShelfGroup([string]$Key){
    if([string]::IsNullOrWhiteSpace($Key)-or-not$script:HcGpuShelfGroups.ContainsKey($Key)){return $null}
    return $script:HcGpuShelfGroups[$Key]
}

function Get-HcGpuShelfSelectedCardForGroup([string]$Key){
    $group=Get-HcGpuShelfGroup $Key
    if($null-eq$group-or$group.Cards.Count-le0){return $null}
    $index=[math]::Max(0,[math]::Min($group.Cards.Count-1,[int]$group.SelectedLocalIndex))
    return $group.Cards[$index]
}

function Get-HcGpuShelfSelectedCard {
    if(-not$script:Hc3DShelfMounted){return $null}
    foreach($card in @($script:Hc3DShelfCards)){
        if($null-ne$card-and[int]$card.ActionIndex-eq[int]$script:SelectedAction){return $card}
    }
    return $null
}

# Keep the stable V6 viewer/action helpers working against the V7 card list.
function Get-Hc3DShelfSelectedCard { return (Get-HcGpuShelfSelectedCard) }
function Get-Hc3DShelfGroup([string]$Key){return (Get-HcGpuShelfGroup $Key)}
function Get-Hc3DShelfSelectedCardForGroup([string]$Key){return (Get-HcGpuShelfSelectedCardForGroup $Key)}

function Load-HcGpuShelfCard($Card){
    if($null-eq$Card-or[string]::IsNullOrWhiteSpace([string]$Card.CachePath)){return $false}
    $group=Get-HcGpuShelfGroup ([string]$Card.Group)
    if($null-eq$group-or$null-eq$group.Surface){return $false}
    try{
        if($group.Surface.LoadModel([int]$Card.ActionIndex,[string]$Card.CachePath)){
            $Card.GpuReady=$true;$Card.Failed=$false
            try{$Card.Icon.Opacity=0.0}catch{}
            try{Write-Log ('GPU shelf model ready: '+$Card.Platform+' cache='+[IO.Path]::GetFileName([string]$Card.CachePath))}catch{}
            return $true
        }
    }catch{try{Write-Log ('GPU shelf load failed for '+$Card.Platform+': '+$_.Exception.Message) 'WARN'}catch{}}
    return $false
}

function Start-HcGpuShelfCompilerTimer {
    if($script:HcGpuShelfCompileTimer){if(-not$script:HcGpuShelfCompileTimer.IsEnabled){$script:HcGpuShelfCompileTimer.Start()};return}
    $timer=New-Object System.Windows.Threading.DispatcherTimer
    $timer.Interval=[TimeSpan]::FromMilliseconds(180)
    $timer.Add_Tick({try{Update-HcGpuShelfCompilerQueue}catch{try{Write-Log ('GPU shelf compiler tick failed: '+$_.Exception.Message) 'ERROR'}catch{}}})
    $script:HcGpuShelfCompileTimer=$timer;$timer.Start()
}

function Queue-HcGpuShelfCache($Card){
    if($null-eq$Card-or[string]::IsNullOrWhiteSpace([string]$Card.Path)){return}
    $Card.CachePath=Get-HcGpuShelfCachePath ([string]$Card.Path)
    if(Test-HcGpuShelfCacheCurrent ([string]$Card.Path) ([string]$Card.CachePath)){
        [void](Load-HcGpuShelfCard $Card);return
    }
    foreach($queued in @($script:HcGpuShelfCompileQueue)){if($queued-and[int]$queued.ActionIndex-eq[int]$Card.ActionIndex){return}}
    if($script:HcGpuShelfCompileCard-and[int]$script:HcGpuShelfCompileCard.ActionIndex-eq[int]$Card.ActionIndex){return}
    [void]$script:HcGpuShelfCompileQueue.Add($Card)
    Start-HcGpuShelfCompilerTimer
}

function Start-HcGpuShelfCompile($Card){
    if($null-eq$Card){return}
    $args='--model "'+([string]$Card.Path).Replace('"','\"')+'" --cache "'+([string]$Card.CachePath).Replace('"','\"')+'" --size '+[int]$script:HcGpuShelfCacheQuality
    try{
        $script:HcGpuShelfCompileProcess=Start-Process -FilePath $script:HcGpuShelfCompilerExe -ArgumentList $args -WindowStyle Hidden -PassThru
        $script:HcGpuShelfCompileCard=$Card
        try{Write-Log ('GPU shelf cache compiling: '+$Card.Platform)}catch{}
    }catch{
        $Card.Failed=$true;$script:HcGpuShelfCompileProcess=$null;$script:HcGpuShelfCompileCard=$null
        try{Write-Log ('GPU shelf cache compiler launch failed for '+$Card.Platform+': '+$_.Exception.Message) 'WARN'}catch{}
    }
}

function Update-HcGpuShelfCompilerQueue {
    if($script:HcGpuShelfCompileProcess){
        try{$script:HcGpuShelfCompileProcess.Refresh()}catch{}
        if(-not$script:HcGpuShelfCompileProcess.HasExited){return}
        $card=$script:HcGpuShelfCompileCard;$code=-1
        try{$code=[int]$script:HcGpuShelfCompileProcess.ExitCode}catch{}
        try{$script:HcGpuShelfCompileProcess.Dispose()}catch{}
        $script:HcGpuShelfCompileProcess=$null;$script:HcGpuShelfCompileCard=$null
        if($null-ne$card){
            if($code-eq0-and(Test-HcGpuShelfCacheCurrent ([string]$card.Path) ([string]$card.CachePath))){[void](Load-HcGpuShelfCard $card)}
            else{$card.Failed=$true;try{Write-Log ('GPU shelf cache compile failed for '+$card.Platform+' exit='+$code) 'WARN'}catch{}}
        }
        Update-HcGpuShelfLayout
    }
    if($script:HcGpuShelfCompileQueue.Count-gt0-and-not$script:HcGpuShelfCompileProcess){
        $next=$script:HcGpuShelfCompileQueue[0];$script:HcGpuShelfCompileQueue.RemoveAt(0);Start-HcGpuShelfCompile $next
    }
    if($script:HcGpuShelfCompileQueue.Count-eq0-and-not$script:HcGpuShelfCompileProcess){try{$script:HcGpuShelfCompileTimer.Stop()}catch{}}
}

function Reset-Hc3DShelfRuntime {
    $script:HcGpuShelfGeneration++
    try{if($script:Hc3DShelfLoadTimer){$script:Hc3DShelfLoadTimer.Stop()}}catch{}
    try{if($script:Hc3DShelfSpinTimer){$script:Hc3DShelfSpinTimer.Stop()}}catch{}
    foreach($group in @($script:HcGpuShelfGroups.Values)){try{if($group.Surface){$group.Surface.Dispose()}}catch{}}
    $script:HcGpuShelfGroups=@{}
    $script:Hc3DShelfGroups=@{}
    $script:Hc3DShelfCards=New-Object System.Collections.ArrayList
    $script:Hc3DShelfMounted=$false
    $script:Hc3DShelfDetail=$null
}

function Get-HcGpuCardMetrics($Group,[int]$Distance,[bool]$Focused){
    $shelf=[double]$Group.Height
    if($Distance-eq0){$h=$shelf*$(if($Focused){.78}else{.70});$ratio=1.46}
    elseif($Distance-eq1){$h=$shelf*.62;$ratio=1.42}
    else{$h=$shelf*.52;$ratio=1.38}
    $h=[math]::Max(170,$h);$w=$h*$ratio
    [pscustomobject]@{Width=$w;Height=$h;VisualHeight=[math]::Max(105,$h-58)}
}

function Update-HcGpuShelfLayoutForGroup($Group,[bool]$Focused){
    if($null-eq$Group){return}
    $selected=[int]$Group.SelectedLocalIndex
    for($i=0;$i-lt$Group.Cards.Count;$i++){
        $card=$Group.Cards[$i];$distance=[math]::Abs($i-$selected);$metrics=Get-HcGpuCardMetrics $Group $distance $Focused
        $card.Button.Width=$metrics.Width;$card.Button.Height=$metrics.Height;$card.VisualHost.Height=$metrics.VisualHeight
        $card.Button.Opacity=$(if($distance-eq0){1.0}elseif($distance-eq1){.82}else{.58})
        $card.Button.BorderBrush=$(if($distance-eq0-and$Focused){'#F2D36B'}elseif($distance-eq0){'#8D7741'}else{'#40516A'})
        $card.Button.BorderThickness=$(if($distance-eq0-and$Focused){'3'}elseif($distance-eq0){'2'}else{'1'})
        $card.Label.FontSize=$(if($distance-eq0){[math]::Max(14,[math]::Min(21,$metrics.Height*.07))}else{[math]::Max(12,[math]::Min(17,$metrics.Height*.065))})
        $card.Count.FontSize=$(if($distance-eq0){10}else{9})
    }
    try{$Group.Row.UpdateLayout();$Group.Scroll.UpdateLayout();$Group.Container.UpdateLayout()}catch{}
    foreach($card in @($Group.Cards)){
        if($null-eq$card-or-not$card.GpuReady){continue}
        try{
            $point=$card.VisualHost.TranslatePoint((New-Object System.Windows.Point 0,0),$Group.Container)
            $w=[double]$card.VisualHost.ActualWidth;if($w-le1){$w=[double]$card.Button.Width-12}
            $h=[double]$card.VisualHost.ActualHeight;if($h-le1){$h=[double]$card.VisualHost.Height}
            $visible=($point.X+$w-gt0-and$point.X-lt$Group.Container.ActualWidth-and$point.Y+$h-gt0-and$point.Y-lt$Group.Container.ActualHeight)
            $scale=0.55+(([math]::Max(50,[math]::Min(200,[int]$script:Config.PlatformModelScale))-50.0)/150.0)*0.15
            [void]$Group.Surface.SetItem([int]$card.ActionIndex,$point.X,$point.Y,$w,$h,$scale,([int]$card.ShelfIndex-eq$selected),$visible)
        }catch{}
    }
    $selectedCard=Get-HcGpuShelfSelectedCardForGroup ([string]$Group.Key)
    if($Group.Header){$Group.Header.Text=$(if($selectedCard){$Group.Title+'   •   '+$selectedCard.Platform}else{$Group.Title});$Group.Header.Foreground=$(if($Focused){'#E7C45E'}else{'#D8E0EA'})}
}

function Center-HcGpuShelfSelection($Card){
    if($null-eq$Card){return};$group=Get-HcGpuShelfGroup ([string]$Card.Group);if($null-eq$group){return}
    try{$group.Row.UpdateLayout();$group.Scroll.UpdateLayout();$point=$Card.Button.TranslatePoint((New-Object System.Windows.Point 0,0),$group.Row);$target=[double]$point.X+([double]$Card.Button.ActualWidth/2)-([double]$group.Scroll.ViewportWidth/2);$group.Scroll.ScrollToHorizontalOffset([math]::Max(0,$target))}catch{}
}

function Update-HcGpuShelfLayout {
    if(-not$script:Hc3DShelfMounted){return}
    $focused=Get-HcGpuShelfSelectedCard
    if($focused){$focusGroup=Get-HcGpuShelfGroup ([string]$focused.Group);if($focusGroup){$focusGroup.SelectedLocalIndex=[int]$focused.ShelfIndex};$script:SelectedGamePlatform=[string]$focused.Platform}
    foreach($key in @('Providers','Consoles')){$group=Get-HcGpuShelfGroup $key;if($group){Update-HcGpuShelfLayoutForGroup $group ($focused-and[string]::Equals([string]$focused.Group,$key,[StringComparison]::OrdinalIgnoreCase))}}
    if($script:Hc3DShelfDetail){$script:Hc3DShelfDetail.Text='Left/Right browse   •   Up/Down switch shelf   •   A/Cross open   •   X/Square full-screen model'}
    if($focused){Center-HcGpuShelfSelection $focused}
}

function Update-Hc3DShelfSelection { Update-HcGpuShelfLayout }

function New-HcGpuShelfCard([string]$Platform,[int]$PlatformIndex,[string]$Group,[int]$ShelfIndex,[int]$ActionIndex){
    $button=New-Object System.Windows.Controls.Button
    $button.Tag=('platform-select:'+$PlatformIndex);$button.Width=240;$button.Height=200;$button.Margin='9,5';$button.Padding='7'
    $button.Background='#260B111C';$button.BorderBrush='#40516A';$button.BorderThickness='1';$button.Cursor='Hand';$button.RenderTransformOrigin='0.5,0.5'
    $button.Template=[Windows.Markup.XamlReader]::Parse('<ControlTemplate xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" TargetType="Button"><Border Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="16" Padding="{TemplateBinding Padding}" ClipToBounds="False"><ContentPresenter HorizontalAlignment="Stretch" VerticalAlignment="Stretch"/></Border></ControlTemplate>')
    $grid=New-Object System.Windows.Controls.Grid;$grid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition -Property @{Height='*'}));$grid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition -Property @{Height='Auto'}));$grid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition -Property @{Height='Auto'}))
    $visualHost=New-Object System.Windows.Controls.Border;$visualHost.Background='Transparent';$visualHost.BorderThickness='0';$visualHost.Height=140;$visualHost.HorizontalAlignment='Stretch';$visualHost.VerticalAlignment='Stretch';$visualHost.ClipToBounds=$false
    $icon=New-PlatformIconImage $Platform 108;$icon.HorizontalAlignment='Center';$icon.VerticalAlignment='Center';$visualHost.Child=$icon;[System.Windows.Controls.Grid]::SetRow($visualHost,0);$grid.Children.Add($visualHost)|Out-Null
    $label=New-Object System.Windows.Controls.TextBlock;$label.Text=$Platform;$label.FontSize=13;$label.FontWeight='SemiBold';$label.Foreground='White';$label.HorizontalAlignment='Center';$label.TextAlignment='Center';$label.TextTrimming='CharacterEllipsis';$label.Margin='3,3,3,0';[System.Windows.Controls.Grid]::SetRow($label,1);$grid.Children.Add($label)|Out-Null
    $summary=Get-PlatformCountSummary $Platform;$count=New-Object System.Windows.Controls.TextBlock;$count.Text=$(if([bool]$summary.Pending){'SCANNING…'}elseif([int]$summary.Owned-gt[int]$summary.Installed){([int]$summary.Installed).ToString()+' INSTALLED • '+([int]$summary.Owned).ToString()+' OWNED'}else{([int]$summary.Installed).ToString()+' GAMES'});$count.FontSize=9;$count.FontWeight='SemiBold';$count.Foreground='#94A6BE';$count.HorizontalAlignment='Center';$count.Margin='2,2,2,1';[System.Windows.Controls.Grid]::SetRow($count,2);$grid.Children.Add($count)|Out-Null
    $button.Content=$grid
    $button.Add_Click({param($sender,$eventArgs)try{Set-KeyboardActive;Invoke-UiFeedback 'Confirm';Invoke-Action ([string]$sender.Tag)}catch{try{Write-Log ('GPU shelf platform action failed: '+$_.Exception.Message) 'ERROR'}catch{}}})
    $button.Add_MouseEnter({param($sender,$eventArgs)if(-not(Test-HcMouseHoverAllowed)){return};Set-KeyboardActive;$idx=[array]::IndexOf($script:ActionButtons,$sender);if($idx-ge0){$script:SelectedAction=$idx;Update-ActionVisuals}})
    $path=Resolve-HcShelfModelPath $Platform $Group;$cache=$(if($path){Get-HcGpuShelfCachePath $path}else{$null})
    if(-not$path){$button.ToolTip='A/Cross Open platform   •   Add a matching GLB to enable the 3D shelf model'}else{$button.ToolTip='A/Cross Open platform   •   X/Square View 3D model'}
    [pscustomobject]@{ActionIndex=$ActionIndex;PlatformIndex=$PlatformIndex;ShelfIndex=$ShelfIndex;Group=$Group;Platform=$Platform;Button=$button;VisualHost=$visualHost;Icon=$icon;Label=$label;Count=$count;Path=$path;CachePath=$cache;GpuReady=$false;Failed=$false;View=$null;Loading=$false}
}

function Add-HcGpuShelfGroup([string]$Key,[string]$Title,[object[]]$Entries,[double]$Height){
    if($Entries.Count-le0){return}
    $header=New-Object System.Windows.Controls.TextBlock;$header.Text=$Title;$header.FontSize=17;$header.FontWeight='SemiBold';$header.Foreground='#D8E0EA';$header.Margin='8,3,0,3';$script:ActionPanel.Children.Add($header)|Out-Null
    $container=New-Object System.Windows.Controls.Grid;$container.Height=$Height;$container.ClipToBounds=$true;$container.Background='Transparent'
    $surface=$null;if(Initialize-HcGpuShelfRuntime){try{$surface=New-Object HuymaierConsole.Modeling.D3D11ShelfSurface;$surface.HorizontalAlignment='Stretch';$surface.VerticalAlignment='Stretch';$container.Children.Add($surface)|Out-Null}catch{try{Write-Log ('GPU shelf surface creation failed: '+$_.Exception.Message) 'WARN'}catch{}}}
    $row=New-Object System.Windows.Controls.StackPanel;$row.Orientation='Horizontal';$row.VerticalAlignment='Center';$row.Margin='14,0,14,0'
    $cards=New-Object System.Collections.ArrayList;$start=$script:ActionButtons.Count
    for($local=0;$local-lt$Entries.Count;$local++){$entry=$Entries[$local];$platform=[string]$entry.Platform;$platformIndex=[int]$entry.PlatformIndex;$actionIndex=$script:ActionButtons.Count;$card=New-HcGpuShelfCard $platform $platformIndex $Key $local $actionIndex;[void]$cards.Add($card);[void]$script:Hc3DShelfCards.Add($card);$row.Children.Add($card.Button)|Out-Null;$script:ActionButtons+=$card.Button;$script:CurrentActions+=(New-Action ('platform-select:'+$platformIndex) $platform)}
    $scroll=New-Object System.Windows.Controls.ScrollViewer;$scroll.Tag=$Key;$scroll.Height=$Height;$scroll.Background='Transparent';$scroll.HorizontalScrollBarVisibility='Hidden';$scroll.VerticalScrollBarVisibility='Disabled';$scroll.PanningMode='HorizontalOnly';$scroll.Content=$row;$scroll.HorizontalContentAlignment='Left';$scroll.VerticalContentAlignment='Center';$scroll.Add_ScrollChanged({param($sender,$eventArgs)try{Update-HcGpuShelfLayout}catch{}});$container.Children.Add($scroll)|Out-Null;$script:ActionPanel.Children.Add($container)|Out-Null
    $group=[pscustomobject]@{Key=$Key;Title=$Title;Start=$start;Cards=$cards;Row=$row;Scroll=$scroll;Header=$header;Container=$container;Surface=$surface;Height=$Height;SelectedLocalIndex=0};$script:HcGpuShelfGroups[$Key]=$group;$script:Hc3DShelfGroups[$Key]=$group;$script:HomeRows+=,[pscustomobject]@{Start=$start;Count=$cards.Count;Platform=$true}
    foreach($card in @($cards)){if($card.Path){Queue-HcGpuShelfCache $card}}
}

function Add-Hc3DPlatformShelf {
    Reset-Hc3DShelfRuntime;$script:Hc3DShelfMounted=$true
    $heading=New-Object System.Windows.Controls.TextBlock;$heading.Text='Games';$heading.FontSize=28;$heading.FontWeight='Bold';$heading.Foreground='White';$heading.Margin='0,0,0,0';$script:ActionPanel.Children.Add($heading)|Out-Null
    $script:Hc3DShelfDetail=New-Object System.Windows.Controls.TextBlock;$script:Hc3DShelfDetail.FontSize=10;$script:Hc3DShelfDetail.Foreground='#93A5BC';$script:Hc3DShelfDetail.Margin='8,0,0,5';$script:ActionPanel.Children.Add($script:Hc3DShelfDetail)|Out-Null
    $providers=New-Object System.Collections.ArrayList;$consoles=New-Object System.Collections.ArrayList
    for($i=0;$i-lt$script:GameHubPlatforms.Count;$i++){$platform=[string]$script:GameHubPlatforms[$i];$entry=[pscustomobject]@{Platform=$platform;PlatformIndex=$i};if(Test-HcStorefrontPlatform $platform){[void]$providers.Add($entry)}else{[void]$consoles.Add($entry)}}
    $dims=Get-HcGpuShelfDimensions;Add-HcGpuShelfGroup 'Providers' 'Providers' ([object[]]$providers.ToArray()) ([double]$dims.Providers);Add-HcGpuShelfGroup 'Consoles' 'Consoles' ([object[]]$consoles.ToArray()) ([double]$dims.Consoles)
    try{Write-Log ('D3D11 GPU dual shelves mounted: providers='+$providers.Count+' consoles='+$consoles.Count+' cacheQuality='+$script:HcGpuShelfCacheQuality+' heights='+$dims.Providers+'/'+$dims.Consoles)}catch{}
    Update-HcGpuShelfLayout
}

try{[void](Initialize-HcGpuShelfRuntime);Write-Log ('Platform presentation owner initialized: '+$script:HcPlatformPresentationOwner)}catch{}
