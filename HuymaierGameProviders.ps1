# Huymaier Console direct game-provider integration.
# Loaded by HuymaierConsole.ps1. The main shell supplies UI helpers such as
# New-Action, New-HomeCard, Render-Page, Start-NativeFilePicker and Save-Config.

function Get-GameProviderDefinitions {
    return @(
        [pscustomobject]@{Id='Epic';Name='Epic Games';Backend='Legendary';Description='Direct Epic library management through Legendary.';Glyph='EPIC'},
        [pscustomobject]@{Id='GOG';Name='GOG';Backend='gogdl';Description='Direct GOG downloads through gogdl.';Glyph='GOG'},
        [pscustomobject]@{Id='Amazon';Name='Amazon Games';Backend='Nile';Description='Direct Amazon Games management through Nile.';Glyph='AMZN'},
        [pscustomobject]@{Id='Recomps';Name='Recomps';Backend='Native';Description='Launch native recomp builds from a user-selected folder.';Glyph='RECOMP'}
    )
}

function Get-GameProviderDefinition {
    param([string]$Provider)
    foreach($definition in @(Get-GameProviderDefinitions)){
        if([string]::Equals([string]$definition.Id,$Provider,[StringComparison]::OrdinalIgnoreCase) -or
           [string]::Equals([string]$definition.Name,$Provider,[StringComparison]::OrdinalIgnoreCase)){
            return $definition
        }
    }
    return $null
}

function Test-DirectProviderPlatform {
    param([string]$Platform)
    return $null -ne (Get-GameProviderDefinition $Platform)
}

function Read-GameProviderState {
    $fallback=[pscustomobject]@{Busy=$false;Provider='';Mode='';Phase='Ready';Message='Direct game providers are ready.';Progress=-1;Error='';GameId='';GameName='';WorkerPid=0;Updated='';DownloadedBytes=0;TotalBytes=0;InstallSizeBytes=0;DownloadSpeedBytesPerSec=0;EtaSeconds=-1;TelemetryUpdated=''}
    if(-not (Test-Path -LiteralPath $script:ProviderStatePath -PathType Leaf)){$script:ProviderState=$fallback;return $fallback}
    try{$script:ProviderState=Get-Content -Raw -LiteralPath $script:ProviderStatePath|ConvertFrom-Json}catch{$script:ProviderState=$fallback}
    return $script:ProviderState
}

function Read-GameProviderCatalog {
    $fallback=[pscustomobject]@{Providers=@();Updated=''}
    if(-not (Test-Path -LiteralPath $script:ProviderCatalogPath -PathType Leaf)){$script:ProviderCatalog=$fallback;return $fallback}
    try{$script:ProviderCatalog=Get-Content -Raw -LiteralPath $script:ProviderCatalogPath|ConvertFrom-Json}catch{$script:ProviderCatalog=$fallback}
    return $script:ProviderCatalog
}

function Get-ProviderCatalogNode {
    param([string]$Provider)
    if([string]::Equals($Provider,'Recomps',[StringComparison]::OrdinalIgnoreCase)){
        $root=''
        foreach($entry in @($script:Config.ProviderInstallRoots)){
            if($null-ne$entry-and[string]::Equals([string](Get-EntryProperty $entry 'Provider' ''),'Recomps',[StringComparison]::OrdinalIgnoreCase)){$root=[string](Get-EntryProperty $entry 'Path' '');break}
        }
        $games=@()
        if(Get-Command Get-HcRecompGames -ErrorAction SilentlyContinue){$games=@(Get-HcRecompGames)}
        return [pscustomobject]@{Id='Recomps';Name='Recomps';Backend='Native';ToolReady=$true;Authenticated=$true;ToolPath='';Status=$(if($root){'Native recomp folder: '+$root}else{'Choose a Recomps root folder.'});Error='';Games=$games;Updated=(Get-Date).ToString('o')}
    }
    if($null -eq $script:ProviderCatalog){Read-GameProviderCatalog|Out-Null}
    foreach($node in @(Get-EntryProperty $script:ProviderCatalog 'Providers' @())){
        if([string]::Equals([string](Get-EntryProperty $node 'Id' ''),$Provider,[StringComparison]::OrdinalIgnoreCase)){return $node}
    }
    $definition=Get-GameProviderDefinition $Provider
    return [pscustomobject]@{
        Id=$Provider
        Name=$(if($definition){[string]$definition.Name}else{$Provider})
        Backend=$(if($definition){[string]$definition.Backend}else{'Provider'})
        ToolReady=$false
        Authenticated=$false
        ToolPath=''
        Status='Backend is not installed.'
        Error=''
        Games=@()
        Updated=''
    }
}

function Get-ProviderGames {
    param([string]$Provider,[switch]$InstalledOnly,[switch]$AvailableOnly)
    $node=Get-ProviderCatalogNode $Provider
    $items=New-Object System.Collections.ArrayList
    $legacyEpicCatalog=$false;$trustedEpicNames=@{};$trustedEpicIds=@{}
    if([string]::Equals($Provider,'Epic',[StringComparison]::OrdinalIgnoreCase) -and [int](Get-EntryProperty $node 'SchemaVersion' 0) -lt 2){
        $legacyEpicCatalog=$true
        foreach($installedGame in @($script:Config.ImportedGames)){
            if(-not [string]::Equals([string](Get-EntryProperty $installedGame 'Source' (Get-EntryProperty $installedGame 'Provider' '')),'Epic',[StringComparison]::OrdinalIgnoreCase)){continue}
            $n=[string](Get-EntryProperty $installedGame 'Name' '');if($n){$trustedEpicNames[$n.ToLowerInvariant()]=$true}
            $id=[string](Get-EntryProperty $installedGame 'Id' '');if($id){if($id.StartsWith('Epic:',[StringComparison]::OrdinalIgnoreCase)){$id=$id.Substring(5)};$trustedEpicIds[$id.ToLowerInvariant()]=$true}
        }
    }
    foreach($game in @(Get-EntryProperty $node 'Games' @())){
        if($null -eq $game){continue}
        if([string]::Equals($Provider,'Epic',[StringComparison]::OrdinalIgnoreCase)){
            $epicName=[string](Get-EntryProperty $game 'Name' '');$epicId=[string](Get-EntryProperty $game 'Id' '');$epicText=$epicName+"`n"+$epicId+"`n"+[string](Get-EntryProperty $game 'Description' '')+"`n"+[string](Get-EntryProperty $game 'InstallPath' '')+"`n"+[string](Get-EntryProperty $game 'LaunchTarget' '');try{$epicText+="`n"+($game|ConvertTo-Json -Depth 8 -Compress)}catch{}
            if($epicText -match '(?im)^(Unreal Engine|Unreal Editor|Twinmotion|RealityCapture|MetaHuman|Quixel Bridge|Fab|Epic Online Services|Unreal Datasmith|Unreal Marketplace)\b'){continue}
            if($epicText -match '(?i)\b(UE_[45]\.[0-9]+|UnrealEditor|UE4Editor|Marketplace Asset|Engine Plugin|Editor Plugin|Asset Pack|Content Pack|Starter Content|Content Examples|Feature Pack|SDK|Mod Kit|Editor Symbols|Debug Symbols|Source Code|Marketplace Content|Engine Content|Plugin Content|Dev-Marketplace|Marketplace-Windows|UEFN|VaultCache)\b'){continue}
            # Old provider catalogs did not retain Legendary's Marketplace metadata.
            # Until the automatic v0.25.1 refresh replaces that cache, expose only
            # entries corroborated by the freshly scanned installed Epic library.
            if($legacyEpicCatalog){
                $trusted=$false
                if($epicName -and $trustedEpicNames.ContainsKey($epicName.ToLowerInvariant())){$trusted=$true}
                if(-not $trusted -and $epicId -and $trustedEpicIds.ContainsKey($epicId.ToLowerInvariant())){$trusted=$true}
                if(-not $trusted){continue}
            }
        }
        $installed=[bool](Get-EntryProperty $game 'Installed' $false)
        if($InstalledOnly -and -not $installed){continue}
        if($AvailableOnly -and $installed){continue}
        [void]$items.Add($game)
    }
    return [object[]]$items.ToArray()
}

function Get-ProviderInstallRoot {
    param([string]$Provider)
    foreach($entry in @($script:Config.ProviderInstallRoots)){
        if($null -ne $entry -and [string]::Equals([string](Get-EntryProperty $entry 'Provider' ''),$Provider,[StringComparison]::OrdinalIgnoreCase)){
            $path=[string](Get-EntryProperty $entry 'Path' '')
            if($path){return $path}
        }
    }
    $driveRoot='C:\'
    try{
        $best=Get-PSDrive -PSProvider FileSystem -ErrorAction SilentlyContinue|Where-Object{$_.Root -and $null -ne $_.Free}|Sort-Object Free -Descending|Select-Object -First 1
        if($best -and $best.Root){$driveRoot=[string]$best.Root}
    }catch{}
    return (Join-Path $driveRoot (Join-Path 'Games' $Provider))
}

function Set-ProviderInstallRoot {
    param([string]$Provider,[string]$Path)
    if([string]::IsNullOrWhiteSpace($Provider) -or [string]::IsNullOrWhiteSpace($Path)){return}
    $list=New-Object System.Collections.ArrayList
    $replaced=$false
    foreach($entry in @($script:Config.ProviderInstallRoots)){
        if($null -eq $entry){continue}
        if([string]::Equals([string](Get-EntryProperty $entry 'Provider' ''),$Provider,[StringComparison]::OrdinalIgnoreCase)){
            [void]$list.Add([pscustomobject]@{Provider=$Provider;Path=$Path});$replaced=$true
        }else{[void]$list.Add($entry)}
    }
    if(-not $replaced){[void]$list.Add([pscustomobject]@{Provider=$Provider;Path=$Path})}
    $script:Config.ProviderInstallRoots=[object[]]$list.ToArray()
    Save-Config
}

function Complete-ProviderFolderSelection {
    param([string]$Path)
    if([string]::IsNullOrWhiteSpace($Path)){return $false}
    $provider=[string]$script:FileBrowserStore
    Set-ProviderInstallRoot $provider $Path
    $script:SelectedTab=$script:FileBrowserReturnTab
    $script:SubPage=$script:FileBrowserReturnSubPage
    if($script:SubPage -eq 'FilePicker'){$script:SubPage='ProviderGame'}
    $script:SelectedAction=0
    Set-ConsoleNotice "$provider install location set to $Path" 'INFO'
    Render-Page
    Update-NavVisuals
    return $true
}

function Get-ProviderWorkerArguments {
    param([string]$Mode,[string]$Provider,[string]$GameId='',[string]$GameName='',[string]$InstallPath='',[string]$AuthCode='')
    $args=@(
        '-NoLogo','-NoProfile','-ExecutionPolicy','Bypass','-File',('"'+$script:ProviderWorkerPath+'"'),
        '-Mode',$Mode,'-Provider',$Provider,
        '-DataDir',('"'+$script:DataDir+'"'),
        '-StatePath',('"'+$script:ProviderStatePath+'"'),
        '-CatalogPath',('"'+$script:ProviderCatalogPath+'"'),
        '-ToolRoot',('"'+$script:ProviderToolRoot+'"'),
        '-ArtworkRoot',('"'+$script:ProviderArtworkRoot+'"')
    )
    if($GameId){$args+=@('-GameId',('"'+$GameId.Replace('"','')+'"'))}
    if($GameName){$args+=@('-GameName',('"'+$GameName.Replace('"','')+'"'))}
    if($InstallPath){$args+=@('-InstallPath',('"'+$InstallPath.Replace('"','')+'"'))}
    if($AuthCode){$args+=@('-AuthCode',('"'+$AuthCode.Replace('"','')+'"'))}
    return $args
}

function Test-ProviderWorkerProcessActive {
    try{
        if($null -ne $script:ProviderWorkerProcess){
            $script:ProviderWorkerProcess.Refresh()
            if(-not $script:ProviderWorkerProcess.HasExited){return $true}
        }
    }catch{}
    return $false
}
function Write-ProviderLaunchState {
    param([bool]$Busy,[string]$Mode,[string]$Provider,[string]$GameId,[string]$GameName,[string]$Message,[int]$WorkerPid=0,[string]$Error='')
    try{
        $launchState=[pscustomobject]@{Busy=$Busy;Provider=$Provider;Mode=$Mode;Phase=$(if($Busy){'Starting'}else{'Failed'});Message=$Message;Progress=$(if($Busy){0}else{-1});Error=$Error;GameId=$GameId;GameName=$GameName;WorkerPid=$WorkerPid;Updated=(Get-Date).ToString('o')}
        $tempPath="$($script:ProviderStatePath).ui.tmp"
        ConvertTo-Json -InputObject $launchState -Depth 6|Set-Content -LiteralPath $tempPath -Encoding UTF8
        Move-Item -LiteralPath $tempPath -Destination $script:ProviderStatePath -Force
        $script:ProviderState=$launchState
    }catch{}
}
function Start-GameProviderWorker {
    param([string]$Mode,[string]$Provider,[string]$GameId='',[string]$GameName='',[string]$InstallPath='',[string]$AuthCode='')
    if(-not (Test-Path -LiteralPath $script:ProviderWorkerPath -PathType Leaf)){
        Set-ConsoleNotice 'The direct-provider worker is missing.' 'ERROR';return
    }
    if(Test-ProviderWorkerProcessActive){
        Set-ConsoleNotice 'A provider operation is already running. Wait for it to finish before starting another.' 'WARN';return
    }
    $state=Read-GameProviderState
    if($state -and [bool](Get-EntryProperty $state 'Busy' $false)){
        $workerPid=[int](Get-EntryProperty $state 'WorkerPid' 0)
        $workerAlive=$false
        if($workerPid -gt 0){try{Get-Process -Id $workerPid -ErrorAction Stop|Out-Null;$workerAlive=$true}catch{}}
        if($workerAlive){
            Set-ConsoleNotice "A provider operation is already running: $([string](Get-EntryProperty $state 'Message' 'Working'))." 'WARN';return
        }
        # Recover an orphaned busy marker left by a terminated worker.
        Write-ProviderLaunchState $false ([string](Get-EntryProperty $state 'Mode' '')) ([string](Get-EntryProperty $state 'Provider' '')) ([string](Get-EntryProperty $state 'GameId' '')) ([string](Get-EntryProperty $state 'GameName' '')) 'The previous provider task ended unexpectedly.' 0 'Orphaned provider state cleared.'
    }
    $now=[DateTime]::UtcNow
    if($null -ne $script:LastProviderWorkerStartUtc -and ($now-$script:LastProviderWorkerStartUtc).TotalMilliseconds -lt 1500){
        Set-ConsoleNotice 'Please wait a moment before starting another provider operation.' 'WARN';return
    }
    $script:LastProviderWorkerStartUtc=$now
    if(-not $InstallPath){$InstallPath=Get-ProviderInstallRoot $Provider}
    Write-ProviderLaunchState $true $Mode $Provider $GameId $GameName "Starting $Provider $Mode..." 0
    try{
        $powershell="$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
        $process=Start-Process -FilePath $powershell -ArgumentList (Get-ProviderWorkerArguments $Mode $Provider $GameId $GameName $InstallPath $AuthCode) -WindowStyle Hidden -PassThru
        $script:ProviderWorkerProcess=$process
        Write-Log "Direct provider worker started: $Provider / $Mode / $GameName"
        Set-ConsoleNotice "${Provider}: ${Mode} started in the background." 'INFO'
    }catch{
        Write-ProviderLaunchState $false $Mode $Provider $GameId $GameName "Unable to start $Provider $Mode." 0 $_.Exception.Message
        Set-ConsoleNotice "Unable to start $Provider provider task: $($_.Exception.Message)" 'ERROR'
    }
}

function Stop-GameProviderWorker {
    try{
        $state=Read-GameProviderState
        $workerPid=[int](Get-EntryProperty $state 'WorkerPid' 0)
        if($workerPid -gt 0){Stop-Process -Id $workerPid -Force -ErrorAction SilentlyContinue}
        if($script:ProviderWorkerProcess -and -not $script:ProviderWorkerProcess.HasExited){$script:ProviderWorkerProcess.Kill()}
        $cancelState=[pscustomobject]@{Busy=$false;Provider=[string](Get-EntryProperty $state 'Provider' '');Mode=[string](Get-EntryProperty $state 'Mode' '');Phase='Cancelled';Message='Provider operation cancelled. Partial files may be retained for resume.';Progress=-1;Error='Cancelled by user';GameId=[string](Get-EntryProperty $state 'GameId' '');GameName=[string](Get-EntryProperty $state 'GameName' '');WorkerPid=0;Updated=(Get-Date).ToString('o')}
        ConvertTo-Json -InputObject $cancelState -Depth 6|Set-Content -LiteralPath $script:ProviderStatePath -Encoding UTF8
        Set-ConsoleNotice 'Provider operation cancelled. Partial download data may be retained for resume.' 'WARN'
    }catch{Set-ConsoleNotice "Unable to cancel provider operation: $($_.Exception.Message)" 'ERROR'}
}

function Convert-ProviderGameToLaunchEntry {
    param($Game)
    if($null -eq $Game){return $null}
    return [pscustomobject]@{
        Id=[string](Get-EntryProperty $Game 'Id' '')
        Name=[string](Get-EntryProperty $Game 'Name' 'Game')
        Source=[string](Get-EntryProperty $Game 'Provider' 'Game')
        Provider=[string](Get-EntryProperty $Game 'Provider' '')
        ProviderGameId=[string](Get-EntryProperty $Game 'Id' '')
        Installed=[bool](Get-EntryProperty $Game 'Installed' $false)
        InstallPath=[string](Get-EntryProperty $Game 'InstallPath' '')
        ArtworkPath=[string](Get-EntryProperty $Game 'ArtworkPath' '')
        LaunchTarget=[string](Get-EntryProperty $Game 'LaunchTarget' '')
        Path=''
        Arguments=@()
    }
}

function Invoke-ProviderGameLaunchEntry {
    param($Entry)
    $provider=[string](Get-EntryProperty $Entry 'Provider' '')
    $gameId=[string](Get-EntryProperty $Entry 'ProviderGameId' (Get-EntryProperty $Entry 'Id' ''))
    if(-not $provider -or -not $gameId){return $false}
    if([string]::Equals($provider,'Recomps',[StringComparison]::OrdinalIgnoreCase)){
        $target=[string](Get-EntryProperty $Entry 'LaunchTarget' '')
        if(-not $target-or-not(Test-Path -LiteralPath $target -PathType Leaf)){Set-ConsoleNotice 'The selected recomp executable could not be found.' 'ERROR';return $false}
        Start-ExternalProcess $target @()|Out-Null
        return $true
    }
    if([string]::Equals($provider,'HES',[StringComparison]::OrdinalIgnoreCase)){
        $target=[string](Get-EntryProperty $Entry 'LaunchTarget' '')
        if(-not $target){$base=[string](Get-EntryProperty $script:Config 'HesServerUrl' 'http://localhost:6099');$target=$base.TrimEnd('/')+"/rom/$gameId"}
        $browser=[string](Get-EntryProperty $script:Config 'BrowserPath' '')
        if($browser -and (Test-Path -LiteralPath $browser -PathType Leaf)){
            $args=New-Object System.Collections.ArrayList
            foreach($arg in @(Get-BrowserArguments $browser ([string](Get-EntryProperty $script:Config 'BrowserMode' 'Fullscreen')))){[void]$args.Add($arg)}
            [void]$args.Add($target)
            Start-ExternalProcess $browser ([string[]]$args.ToArray())|Out-Null
        }else{Start-UriOrShellTarget $target}
        return $true
    }
    $name=[string](Get-EntryProperty $Entry 'Name' 'Game')
    Start-GameProviderWorker 'Launch' $provider $gameId $name (Get-ProviderInstallRoot $provider)
    return $true
}

function New-ProviderControlCard {
    param([string]$Id,[string]$Glyph,[string]$Title,[string]$Subtitle)
    $button=New-Object System.Windows.Controls.Button
    $button.Tag=$Id;$button.Width=330;$button.MinHeight=220;$button.Margin='0,0,18,8';$button.Padding='0';$button.Background='#B5121B2A';$button.BorderBrush='#33445E';$button.BorderThickness='1';$button.RenderTransformOrigin='0.5,0.5';$button.Cursor='Hand'
    $button.Template=[Windows.Markup.XamlReader]::Parse('<ControlTemplate xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" TargetType="Button"><Border Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="18" ClipToBounds="False"><ContentPresenter/></Border></ControlTemplate>')
    $grid=New-Object System.Windows.Controls.Grid;$grid.Margin='20,16,20,18';$grid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition -Property @{Height='Auto'}));$grid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition -Property @{Height='Auto'}));$grid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition -Property @{Height='Auto'}))
    $g=New-Object System.Windows.Controls.TextBlock;$g.Text=$Glyph;$g.FontSize=13;$g.FontWeight='Bold';$g.Foreground='#F2D36B';[System.Windows.Controls.Grid]::SetRow($g,0);$grid.Children.Add($g)|Out-Null
    $t=New-Object System.Windows.Controls.TextBlock;$t.Text=$Title;$t.FontSize=22;$t.FontWeight='Bold';$t.Foreground='White';$t.Margin='0,10,0,0';$t.TextWrapping='Wrap';$t.MaxHeight=84;[System.Windows.Controls.Grid]::SetRow($t,1);$grid.Children.Add($t)|Out-Null
    $s=New-Object System.Windows.Controls.TextBlock;$s.Text=$Subtitle;$s.FontSize=13;$s.Foreground='#AEBBD0';$s.TextWrapping='Wrap';$s.Margin='0,8,0,0';$s.MaxHeight=88;[System.Windows.Controls.Grid]::SetRow($s,2);$grid.Children.Add($s)|Out-Null
    $button.Content=$grid
    $button.Add_Click({param($sender,$eventArgs)Invoke-UiFeedback 'Confirm';Invoke-Action ([string]$sender.Tag)})
    $button.Add_MouseEnter({param($sender,$eventArgs)if(-not(Test-HcMouseHoverAllowed)){return};Set-KeyboardActive;$idx=[array]::IndexOf($script:ActionButtons,$sender);if($idx -ge 0){$script:SelectedAction=$idx;Update-ActionVisuals}})
    return $button
}

function Add-ProviderControlRail {
    param([string]$Provider)
    $definition=Get-GameProviderDefinition $Provider
    $node=Get-ProviderCatalogNode $Provider
    $heading=New-Object System.Windows.Controls.TextBlock;$heading.Text="$([string]$definition.Name) Management";$heading.FontSize=25;$heading.FontWeight='SemiBold';$heading.Margin='0,0,0,12';$heading.Foreground='#F5F7FB';$script:ActionPanel.Children.Add($heading)|Out-Null
    $start=$script:ActionButtons.Count;$row=New-Object System.Windows.Controls.StackPanel;$row.Orientation='Horizontal'
    $choices=@()
    $isHes=[string]::Equals($Provider,'HES',[StringComparison]::OrdinalIgnoreCase)
    $isRecomps=[string]::Equals($Provider,'Recomps',[StringComparison]::OrdinalIgnoreCase)
    if($isRecomps){
        $root=''
        foreach($entry in @($script:Config.ProviderInstallRoots)){if($null-ne$entry-and[string]::Equals([string](Get-EntryProperty $entry 'Provider' ''),'Recomps',[StringComparison]::OrdinalIgnoreCase)){$root=[string](Get-EntryProperty $entry 'Path' '');break}}
        $choices+=,[pscustomobject]@{Id='provider-recomps-folder';Glyph='FOLDER';Title=$(if($root){'Change Recomps Folder'}else{'Set Recomps Folder'});Subtitle=$(if($root){$root}else{'Choose the root folder containing native recomp builds.'})}
        $choices+=,[pscustomobject]@{Id='provider-refresh:Recomps';Glyph='SYNC';Title='Refresh Recomps';Subtitle='Rescan the configured folder for native recomp executables.'}
    }else{
    if($isHes){
        $server=[string](Get-EntryProperty $script:Config 'HesServerUrl' 'http://localhost:6099')
        $api=[string](Get-EntryProperty $script:Config 'HesApiUrl' '')
        $choices+=,[pscustomobject]@{Id='provider-hes-url';Glyph='WEB';Title='HES Web Address';Subtitle=$server}
        $choices+=,[pscustomobject]@{Id='provider-hes-api-url';Glyph='API';Title='HES API Address';Subtitle=$(if($api){$api}else{'Auto-detect; set the direct LAN RomM address if the web address uses Authentik.'})}
    }
    if(-not [bool](Get-EntryProperty $node 'ToolReady' $false)){
        $choices+=,[pscustomobject]@{Id="provider-setup:$Provider";Glyph='SETUP';Title=$(if($isHes){'Connect to HES'}else{"Install $([string]$definition.Backend)"});Subtitle=$(if($isHes){'Verify the configured HES server and prepare secure device pairing.'}else{'Install the optional direct-download backend.'})}
    }else{
        $authText=if([bool](Get-EntryProperty $node 'Authenticated' $false)){'Account connected'}else{'Connect account'}
        $authSubtitle=if($isHes){'Open HES in your browser, sign in, and approve this console.'}elseif([string]::Equals($Provider,'GOG',[StringComparison]::OrdinalIgnoreCase)){'Automatic GOG sign-in detects the completed browser redirect.'}else{'Provider-owned sign-in may appear when required.'}
        $choices+=,[pscustomobject]@{Id="provider-auth:$Provider";Glyph='ACCOUNT';Title=$authText;Subtitle=$authSubtitle}
        if($isHes){
            $choices+=,[pscustomobject]@{Id='provider-hes-pair-manual';Glyph='CODE';Title='Manual HES Pairing';Subtitle='Fallback: enter an eight-digit client pairing code generated in HES.'}
        }
        if([string]::Equals($Provider,'GOG',[StringComparison]::OrdinalIgnoreCase)){
            $choices+=,[pscustomobject]@{Id='provider-gog-auth-manual';Glyph='CODE';Title='GOG Manual Code';Subtitle='Fallback: sign in, copy the code from the final address, then paste it with the native keyboard.'}
        }
        $choices+=,[pscustomobject]@{Id="provider-refresh:$Provider";Glyph='SYNC';Title='Refresh Library';Subtitle=$(if($isHes){'Refresh HES titles, platforms, metadata, and artwork.'}else{'Refresh owned, installed, and update status.'})}
    }
    # HUYMAIER_RECOMPS_CONTROL_RAIL_END_V1
    }
    $choices+=,[pscustomobject]@{Id='provider-back';Glyph='BACK';Title='Platform Menu';Subtitle='Return to Home and Library choices.'}
    foreach($choice in $choices){$button=New-ProviderControlCard $choice.Id $choice.Glyph $choice.Title $choice.Subtitle;$row.Children.Add($button)|Out-Null;$script:ActionButtons+=$button;$script:CurrentActions+=(New-Action $choice.Id $choice.Title $choice.Subtitle)}
    $scroll=New-Object System.Windows.Controls.ScrollViewer;$scroll.HorizontalScrollBarVisibility='Hidden';$scroll.VerticalScrollBarVisibility='Disabled';$scroll.PanningMode='HorizontalOnly';$scroll.Content=$row;$scroll.Margin='0,0,0,20';$script:ActionPanel.Children.Add($scroll)|Out-Null
    $script:HomeRows+=,[pscustomobject]@{Start=$start;Count=$choices.Count;Platform=$false}
}

function Add-ProviderGameRail {
    param([string]$Title,[object[]]$Games,[string]$EmptyText)
    $Games = Convert-ToStableArray $Games
    $heading=New-Object System.Windows.Controls.TextBlock;$heading.Text=$Title;$heading.FontSize=25;$heading.FontWeight='SemiBold';$heading.Margin='0,0,0,12';$heading.Foreground='#F5F7FB';$script:ActionPanel.Children.Add($heading)|Out-Null
    if($Games.Count -eq 0){
        $empty=New-Object System.Windows.Controls.Border;$empty.Height=96;$empty.CornerRadius=14;$empty.Background='#7A101827';$empty.BorderBrush='#2B3A51';$empty.BorderThickness=1;$empty.Margin='0,0,0,20'
        $tb=New-Object System.Windows.Controls.TextBlock;$tb.Text=$EmptyText;$tb.FontSize=15;$tb.TextWrapping='Wrap';$tb.TextAlignment='Center';$tb.Margin='24,10';$tb.Foreground='#AAB7C9';$tb.VerticalAlignment='Center';$tb.HorizontalAlignment='Center';$empty.Child=$tb;$script:ActionPanel.Children.Add($empty)|Out-Null
        $script:HomeRows+=,[pscustomobject]@{Start=$script:ActionButtons.Count;Count=0;Platform=$false};return
    }
    $start=$script:ActionButtons.Count;$row=New-Object System.Windows.Controls.StackPanel;$row.Orientation='Horizontal'
    foreach($game in $Games){
        $index=$script:ProviderGameEntries.Count;$script:ProviderGameEntries+=$game
        $entry=Convert-ProviderGameToLaunchEntry $game
        $button=New-HomeCard $entry "provider-game:$index" $Title
        $row.Children.Add($button)|Out-Null;$script:ActionButtons+=$button;$script:CurrentActions+=(New-Action "provider-game:$index" ([string](Get-EntryProperty $game 'Name' 'Game')))
    }
    $scroll=New-Object System.Windows.Controls.ScrollViewer;$scroll.HorizontalScrollBarVisibility='Hidden';$scroll.VerticalScrollBarVisibility='Disabled';$scroll.PanningMode='HorizontalOnly';$scroll.Content=$row;$scroll.Margin='0,0,0,20';$script:ActionPanel.Children.Add($scroll)|Out-Null
    $script:HomeRows+=,[pscustomobject]@{Start=$start;Count=$Games.Count;Platform=$false}
}

function Render-GameProviderStore {
    param([string]$Provider)
    $script:ProviderGameEntries=@()
    Add-ProviderControlRail $Provider
    $node=Get-ProviderCatalogNode $Provider
    if(-not [bool](Get-EntryProperty $node 'ToolReady' $false)){return}
    $installed=@(Get-ProviderGames $Provider -InstalledOnly)
    $available=@(Get-ProviderGames $Provider -AvailableOnly)
    Add-ProviderGameRail 'Installed' $installed 'No games installed through this direct provider.'
    Add-ProviderGameRail 'Available to Install' $available 'Connect the account and refresh the library to show owned games.'
}

function Get-SelectedProviderGame {
    if($null -ne $script:SelectedProviderGame){return $script:SelectedProviderGame}
    return $null
}

function Get-GameProviderPageDefinition {
    if($script:SubPage -ne 'ProviderGame'){return $null}
    $game=Get-SelectedProviderGame
    if($null -eq $game){return [pscustomobject]@{Title='Game Management';Subtitle='The selected provider game is unavailable.';Hero='NO GAME SELECTED';HeroText='Return to the provider library and select a title.';Actions=@((New-Action 'provider-game-back' 'Back to provider library'))}}
    $provider=[string](Get-EntryProperty $game 'Provider' $script:SelectedGamePlatform)
    $name=[string](Get-EntryProperty $game 'Name' 'Game')
    $installed=[bool](Get-EntryProperty $game 'Installed' $false)
    $installPath=[string](Get-EntryProperty $game 'InstallPath' '')
    if(-not $installPath){$installPath=Get-ProviderInstallRoot $provider}
    $size=[string](Get-EntryProperty $game 'SizeText' '')
    $description=[string](Get-EntryProperty $game 'Description' '')
    if(-not $description){$description=if($installed){"Installed at $installPath"}else{"Ready to install to $installPath"}}
    if($size){$description+="`nSize: $size"}
    $actions=New-Object System.Collections.Generic.List[object]
    if([string]::Equals($provider,'Recomps',[StringComparison]::OrdinalIgnoreCase)){
        if($installed){
            $actions.Add((New-Action 'provider-game-launch' 'Launch' ('Start '+$name+' directly.')))
            $actions.Add((New-Action 'provider-recomps-open-folder' 'Open game folder' 'Open the discovered recomp build folder in Explorer.'))
        }
        $actions.Add((New-Action 'provider-game-back' 'Back to provider library'))
        return [pscustomobject]@{Title=$name;Subtitle='Native recomp';Hero=$(if($installed){'INSTALLED'}else{'NOT FOUND'});HeroText=$description;Actions=([object[]]$actions.ToArray())}
    }
    if($installed){
        $actions.Add((New-Action 'provider-game-launch' 'Launch' $(if([string]::Equals($provider,'HES',[StringComparison]::OrdinalIgnoreCase)){"Open $name from HES."}else{"Start $name through $provider."})))
        if([string]::Equals($provider,'HES',[StringComparison]::OrdinalIgnoreCase)){$actions.Add((New-Action 'provider-game-back' 'Back to provider library'));return [pscustomobject]@{Title=$name;Subtitle='HES library title';Hero='AVAILABLE';HeroText=$description;Actions=([object[]]$actions.ToArray())}}
        $actions.Add((New-Action 'provider-game-update' 'Check / Apply Update' 'Uses the provider backend and preserves the current installation.'))
        $actions.Add((New-Action 'provider-game-verify' 'Verify / Repair' 'Checks local files and repairs missing or changed content.'))
        if([string]::Equals($provider,'Epic',[StringComparison]::OrdinalIgnoreCase)){$actions.Add((New-Action 'provider-game-move' 'Move to another drive' 'Choose a new native library location.'))}
        $actions.Add((New-Action 'provider-game-uninstall' 'Uninstall' 'Removes the provider-managed installation after confirmation.'))
    }else{
        $actions.Add((New-Action 'provider-game-location' "Install location: $installPath" 'Choose a drive or library folder without opening Explorer.'))
        $actions.Add((New-Action 'provider-game-install' 'Install' 'Adds this game to the native Downloads queue.'))
    }
    $actions.Add((New-Action 'provider-game-back' 'Back to provider library'))
    return [pscustomobject]@{Title=$name;Subtitle="$provider direct game management";Hero=$(if($installed){'INSTALLED'}else{'AVAILABLE'});HeroText=$description;Actions=([object[]]$actions.ToArray())}
}

function Invoke-GameProviderAction {
    param([string]$Id)
    if($Id -match '^provider-game:(\d+)$'){
        $index=[int]$matches[1]
        if($index -ge 0 -and $index -lt $script:ProviderGameEntries.Count){$script:SelectedProviderGame=$script:ProviderGameEntries[$index];$script:SubPage='ProviderGame';$script:SelectedAction=0;Render-Page}
        return $true
    }
    if($Id -match '^provider-(setup|auth|refresh):(.+)$'){
        $actionName=[string]$matches[1]
        $provider=[string]$matches[2]
        if([string]::Equals($provider,'Recomps',[StringComparison]::OrdinalIgnoreCase)){
            if($actionName -eq 'refresh'){
                try{$script:HcRecompCacheUntil=[datetime]::MinValue;$script:HcRecompCache=@()}catch{}
                Render-Page
                Set-ConsoleNotice 'Recomps folder rescanned.' 'INFO'
            }
            return $true
        }
        if([string]::Equals($provider,'HES',[StringComparison]::OrdinalIgnoreCase)){
            $hesMode=switch($actionName){'setup'{'Setup'}'auth'{'Authenticate'}default{'Refresh'}}
            Start-GameProviderWorker $hesMode 'HES'
            Set-ConsoleNotice $(if($hesMode -eq 'Authenticate'){'Complete HES sign-in with the controller in the Huymaier browser.'}else{'Refreshing the HES platform index...'}) 'INFO'
            return $true
        }
        if($actionName -eq 'auth' -and [string]::Equals($provider,'GOG',[StringComparison]::OrdinalIgnoreCase)){
            # The provider worker prefers Huymaier Console's native controller
            # browser and keeps the existing Edge capture path as a fallback.
            Start-GameProviderWorker 'Authenticate' 'GOG'
            Set-Tab 4
            return $true
        }
        $mode=switch($actionName){'setup'{'Setup'}'auth'{'Authenticate'}default{'Refresh'}}
        Start-GameProviderWorker $mode $provider;Set-Tab 4;return $true
    }
    switch($Id){
        'provider-recomps-folder'{
            $root=''
            foreach($entry in @($script:Config.ProviderInstallRoots)){if($null-ne$entry-and[string]::Equals([string](Get-EntryProperty $entry 'Provider' ''),'Recomps',[StringComparison]::OrdinalIgnoreCase)){$root=[string](Get-EntryProperty $entry 'Path' '');break}}
            $picker=@{Mode='PickFolder';Store='Recomps';EntryType='ProviderInstall';ReturnTab=1}
            if($root){$picker.StartPath=$root}
            Start-NativeFilePicker @picker
            return $true
        }
        'provider-recomps-open-folder'{
            $game=Get-SelectedProviderGame
            $path=[string](Get-EntryProperty $game 'InstallPath' (Get-EntryProperty $game 'Path' ''))
            if($path-and(Test-Path -LiteralPath $path -PathType Container)){Start-Process explorer.exe -ArgumentList $path|Out-Null}
            return $true
        }
        'provider-hes-url'{
            $current=[string](Get-EntryProperty $script:Config 'HesServerUrl' 'http://localhost:6099')
            Show-NativeKeyboard -Title 'HES web address' -InitialText $current -Mode 'ProviderHesUrl' -Context $null
            return $true
        }
        'provider-hes-api-url'{
            $current=[string](Get-EntryProperty $script:Config 'HesApiUrl' '')
            Show-NativeKeyboard -Title 'Direct HES / RomM API address' -InitialText $current -Mode 'ProviderHesApiUrl' -Context $null
            return $true
        }
        'provider-hes-pair-manual'{
            Show-NativeKeyboard -Title 'Enter HES pairing code' -InitialText '' -Mode 'ProviderHesPairing' -Context $null
            Set-ConsoleNotice 'Generate a client pairing code in HES, then enter all eight digits here.' 'INFO'
            return $true
        }
        'provider-gog-auth-manual'{
            $gogUrl='https://auth.gog.com/auth?client_id=46899977096215655&redirect_uri=https%3A%2F%2Fembed.gog.com%2Fon_login_success%3Forigin%3Dclient&response_type=code&layout=client2'
            Show-NativeKeyboard -Title 'Paste GOG authorization code' -InitialText '' -Mode 'ProviderGogAuth' -Context $null
            Start-UriOrShellTarget $gogUrl
            Set-ConsoleNotice 'After GOG sign-in, copy the code value from the final browser address, return here, choose PASTE, then OK.' 'INFO'
            return $true
        }
        'provider-back'{$script:SubPage='PlatformChoice';$script:SelectedAction=0;Render-Page;return $true}
        'provider-game-back'{$script:SubPage='ProviderStore';$script:SelectedAction=0;Render-Page;return $true}
        'provider-game-location'{
            $game=Get-SelectedProviderGame;$provider=[string](Get-EntryProperty $game 'Provider' $script:SelectedGamePlatform)
            Start-NativeFilePicker -Mode PickFolder -Store $provider -EntryType 'ProviderInstall' -ReturnTab 1 -StartPath (Get-ProviderInstallRoot $provider)
            return $true
        }
        'provider-game-install'{
            $game=Get-SelectedProviderGame;$provider=[string](Get-EntryProperty $game 'Provider' $script:SelectedGamePlatform);$id=[string](Get-EntryProperty $game 'Id' '');$name=[string](Get-EntryProperty $game 'Name' 'Game')
            Start-GameProviderWorker 'Install' $provider $id $name (Get-ProviderInstallRoot $provider);Set-Tab 4;return $true
        }
        'provider-game-launch'{
            $game=Get-SelectedProviderGame;$entry=Convert-ProviderGameToLaunchEntry $game;Add-ToRecent 'Game' $entry;Invoke-ProviderGameLaunchEntry $entry|Out-Null;return $true
        }
        'provider-game-update'{
            $game=Get-SelectedProviderGame;$provider=[string](Get-EntryProperty $game 'Provider' $script:SelectedGamePlatform);Start-GameProviderWorker 'Update' $provider ([string](Get-EntryProperty $game 'Id' '')) ([string](Get-EntryProperty $game 'Name' 'Game')) ([string](Get-EntryProperty $game 'InstallPath' (Get-ProviderInstallRoot $provider)));Set-Tab 4;return $true
        }
        'provider-game-verify'{
            $game=Get-SelectedProviderGame;$provider=[string](Get-EntryProperty $game 'Provider' $script:SelectedGamePlatform);Start-GameProviderWorker 'Verify' $provider ([string](Get-EntryProperty $game 'Id' '')) ([string](Get-EntryProperty $game 'Name' 'Game')) ([string](Get-EntryProperty $game 'InstallPath' (Get-ProviderInstallRoot $provider)));Set-Tab 4;return $true
        }
        'provider-game-move'{
            $game=Get-SelectedProviderGame;$provider=[string](Get-EntryProperty $game 'Provider' $script:SelectedGamePlatform)
            $script:ProviderMovePending=$true
            Start-NativeFilePicker -Mode PickFolder -Store $provider -EntryType 'ProviderMove' -ReturnTab 1 -StartPath (Get-ProviderInstallRoot $provider);return $true
        }
        'provider-game-uninstall'{
            $game=Get-SelectedProviderGame;$provider=[string](Get-EntryProperty $game 'Provider' $script:SelectedGamePlatform);$id=[string](Get-EntryProperty $game 'Id' '');$name=[string](Get-EntryProperty $game 'Name' 'Game')
            Request-NativeConfirmation "provider-uninstall:${provider}:${id}" "Uninstall $name from $provider? Game files managed by the provider will be removed.";return $true
        }
        'provider-cancel'{Stop-GameProviderWorker;return $true}
    }
    return $false
}

function Complete-ProviderConfirmation {
    param([string]$Action)
    if($Action -notmatch '^provider-uninstall:([^:]+):(.+)$'){return $false}
    $provider=[string]$matches[1];$gameId=[string]$matches[2]
    $game=Get-SelectedProviderGame;$name=if($game){[string](Get-EntryProperty $game 'Name' 'Game')}else{'Game'}
    Start-GameProviderWorker 'Uninstall' $provider $gameId $name ([string](Get-EntryProperty $game 'InstallPath' (Get-ProviderInstallRoot $provider)))
    Set-Tab 4
    return $true
}

function Complete-ProviderMoveFolderSelection {
    param([string]$Path)
    $game=Get-SelectedProviderGame
    if($null -eq $game){return $false}
    $provider=[string](Get-EntryProperty $game 'Provider' $script:SelectedGamePlatform)
    Set-ProviderInstallRoot $provider $Path
    Start-GameProviderWorker 'Move' $provider ([string](Get-EntryProperty $game 'Id' '')) ([string](Get-EntryProperty $game 'Name' 'Game')) $Path
    $script:ProviderMovePending=$false
    Set-Tab 4
    return $true
}

function Format-ProviderDownloadBytes {
    param([int64]$Bytes)
    if($Bytes -ge 1TB){return ('{0:N2} TB' -f ($Bytes/1TB))};if($Bytes -ge 1GB){return ('{0:N2} GB' -f ($Bytes/1GB))};if($Bytes -ge 1MB){return ('{0:N1} MB' -f ($Bytes/1MB))};if($Bytes -ge 1KB){return ('{0:N0} KB' -f ($Bytes/1KB))};return "$Bytes B"
}
function Format-ProviderDownloadSpeed {
    param([double]$BytesPerSecond)
    if($BytesPerSecond -le 0){return 'Measuring speedâ€¦'};if($BytesPerSecond -ge 1GB){return ('{0:N2} GB/s' -f ($BytesPerSecond/1GB))};if($BytesPerSecond -ge 1MB){return ('{0:N1} MB/s' -f ($BytesPerSecond/1MB))};if($BytesPerSecond -ge 1KB){return ('{0:N0} KB/s' -f ($BytesPerSecond/1KB))};return ('{0:N0} B/s' -f $BytesPerSecond)
}
function Format-ProviderDownloadEta {
    param([int64]$Seconds)
    if($Seconds -lt 0){return 'Calculating ETAâ€¦'};$span=[TimeSpan]::FromSeconds([math]::Max(0,$Seconds));if($span.TotalHours -ge 1){return ('ETA {0}:{1:00}:{2:00}' -f [int]$span.TotalHours,$span.Minutes,$span.Seconds)};return ('ETA {0}:{1:00}' -f [int]$span.TotalMinutes,$span.Seconds)
}
function Get-ProviderDownloadDisplay {
    param($State)
    $provider=[string](Get-EntryProperty $State 'Provider' 'Provider');$mode=[string](Get-EntryProperty $State 'Mode' '');$phase=[string](Get-EntryProperty $State 'Phase' 'Working')
    if($mode -in @('Install','Update') -and $phase -in @('Starting','Install','Update','Preparing download')){$phase='Downloading'}
    $progress=[int](Get-EntryProperty $State 'Progress' -1);$installing=[string]::Equals($phase,'Installing',[StringComparison]::OrdinalIgnoreCase)
    [int64]$current=if($installing){[int64](Get-EntryProperty $State 'InstallProcessedBytes' 0)}else{[int64](Get-EntryProperty $State 'DownloadedBytes' 0)}
    [int64]$total=if($installing){[int64](Get-EntryProperty $State 'InstallSizeBytes' 0)}else{[int64](Get-EntryProperty $State 'TotalBytes' 0)}
    [double]$speed=if($installing){[double](Get-EntryProperty $State 'InstallSpeedBytesPerSec' (Get-EntryProperty $State 'TransferSpeedBytesPerSec' 0))}else{[double](Get-EntryProperty $State 'DownloadSpeedBytesPerSec' (Get-EntryProperty $State 'TransferSpeedBytesPerSec' 0))}
    [int64]$eta=[int64](Get-EntryProperty $State 'EtaSeconds' -1)
    $amount=if($total -gt 0){"$(Format-ProviderDownloadBytes $current) / $(Format-ProviderDownloadBytes $total)"}elseif($current -gt 0){Format-ProviderDownloadBytes $current}else{'Measuring activityâ€¦'}
    $progressText=if($progress -ge 0){"$progress%"}else{'Progress calculatingâ€¦'}
    $detail="$provider  â€¢  $progressText  â€¢  $amount  â€¢  $(Format-ProviderDownloadSpeed $speed)  â€¢  $(Format-ProviderDownloadEta $eta)"
    return [pscustomobject]@{Phase=$phase;Detail=$detail}
}
function Get-ProviderDownloadPageActions {
    $state=Read-GameProviderState
    if($null -eq $state){return @()}
    $message=[string](Get-EntryProperty $state 'Message' '')
    if([bool](Get-EntryProperty $state 'Busy' $false)){
        $display=Get-ProviderDownloadDisplay $state;$game=[string](Get-EntryProperty $state 'GameName' '')
        $title=if($game){"$([string]$display.Phase): $game"}else{[string]$display.Phase}
        return @((New-Action 'noop' $title ([string]$display.Detail)),(New-Action 'provider-cancel' 'Cancel provider operation' 'Stops the background worker. Completed files are retained where supported.'))
    }
    $providerError=[string](Get-EntryProperty $state 'Error' '')
    if($providerError){
        $failedProvider=[string](Get-EntryProperty $state 'Provider' 'Provider')
        if([string]::Equals($failedProvider,'GOG',[StringComparison]::OrdinalIgnoreCase) -and $providerError -match '(?i)(not compatible|architecture|executable)'){
            return @(
                (New-Action 'provider-setup:GOG' 'Repair GOG backend' 'Replace the incompatible backend with the official Windows x86-64 build.'),
                (New-Action 'noop' 'Previous GOG error' $providerError)
            )
        }
        return @((New-Action 'noop' "${failedProvider}: $([string](Get-EntryProperty $state 'Phase' 'Failed'))" $providerError))
    }
    if($message){return @((New-Action 'noop' $message "$([string](Get-EntryProperty $state 'Provider' 'Provider')) provider"))}
    return @()
}

# HUYMAIER_PROVIDER_CONCURRENCY_V1
$concurrencyModule=Join-Path $script:BaseDir 'HuymaierProviderConcurrency.ps1'
if(Test-Path -LiteralPath $concurrencyModule -PathType Leaf){. $concurrencyModule}
