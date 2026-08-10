# Huymaier Console storefront hub and native keyboard module.
# Dot-sourced by HuymaierConsole.ps1 so all functions share the shell script scope.

function Get-StorefrontDefinitions {
    return @(
        [pscustomobject]@{
            Id='Steam'; Name='Steam'; Glyph='STEAM'; WingetId='Valve.Steam'; StoreSource='';
            OfficialUrl='https://store.steampowered.com/about/'; DirectUrl='https://cdn.akamai.steamstatic.com/client/installer/SteamSetup.exe';
            FileName='SteamSetup.exe'; AppxName=''; LaunchUri=''; ProcessName='steam';
            UninstallPattern='Steam';
            Paths=@(
                '${env:ProgramFiles(x86)}\Steam\steam.exe',
                '$env:ProgramFiles\Steam\steam.exe'
            )
        },
        [pscustomobject]@{
            Id='Epic'; Name='Epic Games'; Glyph='EPIC'; WingetId='EpicGames.EpicGamesLauncher'; StoreSource='';
            OfficialUrl='https://store.epicgames.com/download'; DirectUrl='';
            FileName='EpicGamesLauncherInstaller.msi'; AppxName=''; LaunchUri='com.epicgames.launcher://apps/'; ProcessName='EpicGamesLauncher';
            UninstallPattern='Epic Games Launcher';
            Paths=@(
                '$env:ProgramFiles\Epic Games\Launcher\Portal\Binaries\Win64\EpicGamesLauncher.exe',
                '${env:ProgramFiles(x86)}\Epic Games\Launcher\Portal\Binaries\Win64\EpicGamesLauncher.exe'
            )
        },
        [pscustomobject]@{
            Id='GOG'; Name='GOG GALAXY'; Glyph='GOG'; WingetId='GOG.Galaxy'; StoreSource='';
            OfficialUrl='https://www.gog.com/galaxy'; DirectUrl='';
            FileName='GOG_Galaxy_Setup.exe'; AppxName=''; LaunchUri='goggalaxy://open'; ProcessName='GalaxyClient';
            UninstallPattern='GOG GALAXY';
            Paths=@(
                '${env:ProgramFiles(x86)}\GOG Galaxy\GalaxyClient.exe',
                '$env:ProgramFiles\GOG Galaxy\GalaxyClient.exe'
            )
        },
        [pscustomobject]@{
            Id='EA'; Name='EA app'; Glyph='EA'; WingetId='ElectronicArts.EADesktop'; StoreSource='';
            OfficialUrl='https://www.ea.com/ea-app'; DirectUrl='https://origin-a.akamaihd.net/EA-Desktop-Client-Download/installer-releases/EAappInstaller.exe';
            FileName='EAappInstaller.exe'; AppxName=''; LaunchUri='origin2://'; ProcessName='EADesktop';
            UninstallPattern='EA app|EA Desktop';
            Paths=@(
                '$env:ProgramFiles\Electronic Arts\EA Desktop\EA Desktop\EADesktop.exe',
                '${env:ProgramFiles(x86)}\Electronic Arts\EA Desktop\EA Desktop\EADesktop.exe'
            )
        },
        [pscustomobject]@{
            Id='Ubisoft'; Name='Ubisoft Connect'; Glyph='UBI'; WingetId='Ubisoft.Connect'; StoreSource='';
            OfficialUrl='https://www.ubisoft.com/en-us/ubisoft-connect/download'; DirectUrl='';
            FileName='UbisoftConnectInstaller.exe'; AppxName=''; LaunchUri='uplay://open'; ProcessName='UbisoftConnect';
            UninstallPattern='Ubisoft Connect|Ubisoft Game Launcher';
            Paths=@(
                '${env:ProgramFiles(x86)}\Ubisoft\Ubisoft Game Launcher\UbisoftConnect.exe',
                '$env:ProgramFiles\Ubisoft\Ubisoft Game Launcher\UbisoftConnect.exe'
            )
        },
        [pscustomobject]@{
            Id='Xbox'; Name='Xbox'; Glyph='XBOX'; WingetId='9MV0B5HZVK9Z'; StoreSource='msstore';
            OfficialUrl='https://www.xbox.com/en-US/apps/xbox-app-on-pc'; DirectUrl='';
            FileName='XboxApp.msix'; AppxName='Microsoft.GamingApp'; LaunchUri='xbox:'; ProcessName='XboxPcApp';
            UninstallPattern='Xbox';
            Paths=@()
        },
        [pscustomobject]@{
            Id='BattleNet'; Name='Battle.net'; Glyph='B.NET'; WingetId=''; StoreSource='';
            OfficialUrl='https://www.blizzard.com/apps/battle.net/desktop'; DirectUrl='https://downloader.battle.net/download/getInstallerForGame?os=win&version=LIVE&gameProgram=BATTLENET_APP';
            FileName='Battle.net-Setup.exe'; AppxName=''; LaunchUri='battlenet://'; ProcessName='Battle.net';
            UninstallPattern='Battle.net';
            Paths=@(
                '${env:ProgramFiles(x86)}\Battle.net\Battle.net Launcher.exe',
                '$env:ProgramFiles\Battle.net\Battle.net Launcher.exe'
            )
        },
        [pscustomobject]@{
            Id='Rockstar'; Name='Rockstar Games'; Glyph='R*'; WingetId='RockstarGames.Launcher'; StoreSource='';
            OfficialUrl='https://socialclub.rockstargames.com/rockstar-games-launcher'; DirectUrl='';
            FileName='Rockstar-Games-Launcher.exe'; AppxName=''; LaunchUri='rockstar-games-launcher://'; ProcessName='Launcher';
            UninstallPattern='Rockstar Games Launcher';
            Paths=@(
                '$env:ProgramFiles\Rockstar Games\Launcher\Launcher.exe',
                '${env:ProgramFiles(x86)}\Rockstar Games\Launcher\Launcher.exe'
            )
        },
        [pscustomobject]@{
            Id='Amazon'; Name='Amazon Games'; Glyph='AMZN'; WingetId='Amazon.Games'; StoreSource='';
            OfficialUrl='https://www.amazon.com/gp/help/customer/display.html?nodeId=TQ1wROUN7BTxoTBbAk'; DirectUrl='https://download.amazongames.com/AmazonGamesSetup.exe';
            FileName='AmazonGamesSetup.exe'; AppxName=''; LaunchUri=''; ProcessName='Amazon Games';
            UninstallPattern='Amazon Games';
            Paths=@(
                '$env:LOCALAPPDATA\Amazon Games\App\Amazon Games.exe',
                '$env:ProgramFiles\Amazon Games\App\Amazon Games.exe',
                '${env:ProgramFiles(x86)}\Amazon Games\App\Amazon Games.exe'
            )
        }
    )
}

function Get-StorefrontDefinition {
    param([string]$Id)
    foreach ($definition in Get-StorefrontDefinitions) {
        if ([string]::Equals([string]$definition.Id,$Id,[StringComparison]::OrdinalIgnoreCase)) {
            return $definition
        }
    }
    return $null
}

function Expand-StorefrontPath {
    param([string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path)) { return '' }
    $expanded = $ExecutionContext.InvokeCommand.ExpandString($Path)
    return [Environment]::ExpandEnvironmentVariables($expanded)
}

function Get-UninstallRecords {
    $records = New-Object System.Collections.ArrayList
    $roots = @(
        'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall',
        'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall',
        'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall'
    )
    foreach ($root in $roots) {
        if (-not (Test-Path -LiteralPath $root)) { continue }
        foreach ($key in Get-ChildItem -LiteralPath $root -ErrorAction SilentlyContinue) {
            try {
                $item = Get-ItemProperty -LiteralPath $key.PSPath -ErrorAction Stop
                $name = [string]$item.DisplayName
                if ([string]::IsNullOrWhiteSpace($name)) { continue }
                [void]$records.Add([pscustomobject]@{
                    DisplayName=$name
                    DisplayVersion=[string]$item.DisplayVersion
                    InstallLocation=[string]$item.InstallLocation
                    DisplayIcon=[string]$item.DisplayIcon
                    QuietUninstallString=[string]$item.QuietUninstallString
                    UninstallString=[string]$item.UninstallString
                    ProductCode=[string]$key.PSChildName
                })
            } catch { }
        }
    }
    return [object[]]$records.ToArray()
}

function Get-StorefrontStatus {
    param($Definition,[object[]]$UninstallRecords)
    if ($null -eq $Definition) {
        return [pscustomobject]@{Installed=$false;Path='';UninstallString='';Version='';Status='Not installed'}
    }

    if ([string]$Definition.AppxName) {
        try {
            $package = Get-AppxPackage -Name ([string]$Definition.AppxName) -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($null -ne $package) {
                return [pscustomobject]@{
                    Installed=$true
                    Path=[string]$package.InstallLocation
                    UninstallString='APPX'
                    Version=[string]$package.Version
                    Status='Installed'
                }
            }
        } catch { }
    }

    $path = ''
    foreach ($candidateTemplate in @($Definition.Paths)) {
        $candidate = Expand-StorefrontPath ([string]$candidateTemplate)
        if ($candidate -and (Test-Path -LiteralPath $candidate -PathType Leaf)) {
            $path = $candidate
            break
        }
    }

    $uninstall = ''
    $version = ''
    foreach ($record in @($UninstallRecords)) {
        if ($null -eq $record) { continue }
        if ([string]$record.DisplayName -match [string]$Definition.UninstallPattern) {
            if ([string]$record.QuietUninstallString) { $uninstall=[string]$record.QuietUninstallString }
            elseif ([string]$record.UninstallString) { $uninstall=[string]$record.UninstallString }
            $version=[string]$record.DisplayVersion
            if (-not $path) {
                $icon=[string]$record.DisplayIcon
                if ($icon) {
                    $icon=$icon.Trim('"')
                    if ($icon -match '^(.*?\.exe)') { $icon=$matches[1] }
                    if (Test-Path -LiteralPath $icon -PathType Leaf) { $path=$icon }
                }
                if (-not $path -and [string]$record.InstallLocation) {
                    foreach ($exeName in @(
                        'steam.exe','EpicGamesLauncher.exe','GalaxyClient.exe','EADesktop.exe',
                        'UbisoftConnect.exe','Battle.net Launcher.exe','Launcher.exe','Amazon Games.exe'
                    )) {
                        $candidate=Join-Path ([string]$record.InstallLocation) $exeName
                        if (Test-Path -LiteralPath $candidate -PathType Leaf) { $path=$candidate;break }
                    }
                }
            }
            break
        }
    }

    $installed = ($path -ne '' -or $uninstall -ne '')
    return [pscustomobject]@{
        Installed=$installed
        Path=$path
        UninstallString=$uninstall
        Version=$version
        Status=$(if($installed){'Installed'}else{'Not installed'})
    }
}

function Refresh-StorefrontCatalog {
    $records = @(Get-UninstallRecords)
    $catalog = New-Object System.Collections.ArrayList
    foreach ($definition in Get-StorefrontDefinitions) {
        $status = Get-StorefrontStatus $definition $records
        [void]$catalog.Add([pscustomobject]@{
            Id=[string]$definition.Id
            Name=[string]$definition.Name
            Glyph=[string]$definition.Glyph
            Definition=$definition
            Installed=[bool]$status.Installed
            Path=[string]$status.Path
            UninstallString=[string]$status.UninstallString
            Version=[string]$status.Version
            Status=[string]$status.Status
        })
    }
    $script:StorefrontCatalog=[object[]]$catalog.ToArray()
    $script:StorefrontCatalogAt=Get-Date
}

function Get-StorefrontCatalogItem {
    param([string]$Id)
    if ($null -eq $script:StorefrontCatalog -or ((Get-Date)-$script:StorefrontCatalogAt).TotalSeconds -gt 10) {
        Refresh-StorefrontCatalog
    }
    foreach ($item in @($script:StorefrontCatalog)) {
        if ([string]::Equals([string]$item.Id,$Id,[StringComparison]::OrdinalIgnoreCase)) { return $item }
    }
    return $null
}

function Read-StorefrontState {
    if (-not (Test-Path -LiteralPath $script:StorefrontStatePath)) {
        $script:StorefrontState=$null
        return
    }
    try {
        $script:StorefrontState=Get-Content -Raw -LiteralPath $script:StorefrontStatePath | ConvertFrom-Json
    } catch {
        Write-Log "Storefront state read failed: $($_.Exception.Message)" 'WARN'
    }
}

function Start-StorefrontWorker {
    param([ValidateSet('Install','Uninstall')][string]$Mode,[string]$StoreId)
    $definition=Get-StorefrontDefinition $StoreId
    if ($null -eq $definition) {
        Set-ConsoleNotice "Unknown storefront: $StoreId" 'ERROR'
        return
    }
    if (-not (Test-Path -LiteralPath $script:StorefrontWorkerPath)) {
        Set-ConsoleNotice 'The storefront installer worker is missing.' 'ERROR'
        return
    }
    $arguments=@(
        '-NoLogo','-NoProfile','-ExecutionPolicy','Bypass',
        '-File',('"'+$script:StorefrontWorkerPath+'"'),
        '-Mode',$Mode,
        '-StoreId',([string]$definition.Id),
        '-Name',('"'+([string]$definition.Name).Replace('"','\"')+'"'),
        '-WingetId',('"'+([string]$definition.WingetId).Replace('"','\"')+'"'),
        '-StoreSource',('"'+([string]$definition.StoreSource).Replace('"','\"')+'"'),
        '-OfficialUrl',('"'+([string]$definition.OfficialUrl).Replace('"','\"')+'"'),
        '-DirectUrl',('"'+([string]$definition.DirectUrl).Replace('"','\"')+'"'),
        '-FileName',('"'+([string]$definition.FileName).Replace('"','\"')+'"'),
        '-AppxName',('"'+([string]$definition.AppxName).Replace('"','\"')+'"'),
        '-UninstallPattern',('"'+([string]$definition.UninstallPattern).Replace('"','\"')+'"'),
        '-StatePath',('"'+$script:StorefrontStatePath+'"'),
        '-DownloadDir',('"'+$script:StorefrontDownloadDir+'"')
    )
    try {
        Start-Process "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -ArgumentList $arguments -WindowStyle Hidden | Out-Null
        $script:StorefrontStateSignature=''
        Set-ConsoleNotice "$Mode started for $($definition.Name)." 'INFO'
    } catch {
        Set-ConsoleNotice "$Mode could not start for $($definition.Name): $($_.Exception.Message)" 'ERROR'
    }
}

function Open-Storefront {
    param([string]$StoreId)
    $item=Get-StorefrontCatalogItem $StoreId
    if ($null -eq $item -or -not [bool]$item.Installed) {
        Set-ConsoleNotice 'This storefront is not installed. Press X or Square to install it.' 'INFO'
        Render-Page
        return
    }
    $definition=$item.Definition
    try {
        if ([string]$definition.Id -eq 'Steam') {
            Start-SteamBigPicture
            return
        }
        if ([string]$definition.LaunchUri) {
            try { Start-Process ([string]$definition.LaunchUri) | Out-Null; return } catch { }
        }
        if ([string]$item.Path -and (Test-Path -LiteralPath ([string]$item.Path) -PathType Leaf)) {
            Start-ExternalProcess ([string]$item.Path) @()
            Add-ToRecent 'App' ([pscustomobject]@{
                Name=[string]$definition.Name;Path=[string]$item.Path;LaunchTarget=[string]$item.Path;
                Arguments=@();Source='Storefront';ArtworkPath=''
            })
            return
        }
        Set-ConsoleNotice "$($definition.Name) is installed, but its launcher could not be located." 'ERROR'
    } catch {
        Set-ConsoleNotice "$($definition.Name) could not be opened: $($_.Exception.Message)" 'ERROR'
    }
}

function Get-StorefrontSecondaryButtonName {
    $family=Get-PromptFamily
    switch($family){
        'PlayStation' { return 'SQUARE' }
        'Nintendo' { return 'X' }
        'Steam' { return 'X' }
        'Xbox' { return 'X' }
        default { return 'X' }
    }
}

function Get-StorefrontSecondaryLabel {
    if ($script:SelectedTab -ne 2 -or $script:ActionButtons.Count -eq 0) { return 'Search' }
    if ($script:SelectedAction -lt 0 -or $script:SelectedAction -ge $script:ActionButtons.Count) { return 'Search' }
    $id=[string]$script:ActionButtons[$script:SelectedAction].Tag
    if ($id -match '^storefront:(.+)$') {
        $item=Get-StorefrontCatalogItem ([string]$matches[1])
        if ($null -ne $item -and [bool]$item.Installed) { return 'Manage' }
        return 'Install'
    }
    return 'Search'
}

function Invoke-SecondaryAction {
    if ($script:KeyboardActive) {
        Invoke-NativeKeyboardKey 'BACKSPACE'
        return
    }
    if ($script:SelectedTab -eq 2 -and $script:ActionButtons.Count -gt 0 -and $script:SelectedAction -ge 0 -and $script:SelectedAction -lt $script:ActionButtons.Count) {
        $id=[string]$script:ActionButtons[$script:SelectedAction].Tag
        if ($id -match '^storefront:(.+)$') {
            $storeId=[string]$matches[1]
            $item=Get-StorefrontCatalogItem $storeId
            if ($null -ne $item -and [bool]$item.Installed) {
                $script:SubPage="Storefront:$storeId"
                $script:SelectedAction=0
                Render-Page
            } else {
                Start-StorefrontWorker 'Install' $storeId
                Render-Page
            }
            return
        }
    }
}

function New-StorefrontCard {
    param($Item)
    $button=New-Object System.Windows.Controls.Button
    $button.Tag="storefront:$($Item.Id)"
    $button.Width=220
    $button.Height=205
    $button.Margin='0,0,20,8'
    $button.Padding='0'
    $button.Background='#B5101826'
    $button.BorderBrush='#33445E'
    $button.BorderThickness='1'
    $button.Cursor='Hand'
    $button.RenderTransformOrigin='0.5,0.5'
    $button.Template=[Windows.Markup.XamlReader]::Parse('<ControlTemplate xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" TargetType="Button"><Border Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="18" ClipToBounds="True"><ContentPresenter/></Border></ControlTemplate>')

    $grid=New-Object System.Windows.Controls.Grid
    $grid.Margin='20'
    $grid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition))
    $grid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition))
    $grid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition))

    $icon=New-Object System.Windows.Controls.Border
    $icon.Width=86;$icon.Height=86;$icon.CornerRadius=24
    $icon.Background='#17243A';$icon.BorderBrush='#6F5C2B';$icon.BorderThickness='1.5'
    $icon.HorizontalAlignment='Center'
    $glyph=New-Object System.Windows.Controls.TextBlock
    $glyph.Text=[string]$Item.Glyph;$glyph.FontSize=20;$glyph.FontWeight='Bold'
    $glyph.Foreground='#F2D36B';$glyph.HorizontalAlignment='Center';$glyph.VerticalAlignment='Center'
    $icon.Child=$glyph
    [System.Windows.Controls.Grid]::SetRow($icon,0);$grid.Children.Add($icon)|Out-Null

    $name=New-Object System.Windows.Controls.TextBlock
    $name.Text=[string]$Item.Name;$name.FontSize=19;$name.FontWeight='SemiBold';$name.Foreground='White'
    $name.HorizontalAlignment='Center';$name.Margin='0,13,0,0'
    [System.Windows.Controls.Grid]::SetRow($name,1);$grid.Children.Add($name)|Out-Null

    $status=New-Object System.Windows.Controls.TextBlock
    $busy=$false
    if($null -ne $script:StorefrontState){
        try{$busy=[bool]$script:StorefrontState.Busy -and [string]::Equals([string]$script:StorefrontState.StoreId,[string]$Item.Id,[StringComparison]::OrdinalIgnoreCase)}catch{}
    }
    $secondary=Get-StorefrontSecondaryButtonName
    if($busy){$status.Text=[string]$script:StorefrontState.Message;$status.Foreground='#F2D36B'}
    elseif([bool]$Item.Installed){$status.Text="OPEN  |  $secondary MANAGE";$status.Foreground='#87D39B'}
    else{$status.Text="$secondary  INSTALL";$status.Foreground='#AAB7C9'}
    $status.FontSize=12;$status.FontWeight='SemiBold';$status.HorizontalAlignment='Center';$status.Margin='0,9,0,0'
    [System.Windows.Controls.Grid]::SetRow($status,2);$grid.Children.Add($status)|Out-Null
    $button.Content=$grid
    $button.Add_Click({
        param($sender,$eventArgs)
        Set-KeyboardActive
        Invoke-UiFeedback 'Confirm'
        Invoke-Action ([string]$sender.Tag)
    })
    $button.Add_MouseEnter({
        param($sender,$eventArgs)
        if(-not(Test-HcMouseHoverAllowed)){return}
        Set-KeyboardActive
        $index=[array]::IndexOf($script:ActionButtons,$sender)
        if($index -ge 0){$script:SelectedAction=$index;Update-ActionVisuals;Update-Footer}
    })
    return $button
}

function Add-StorefrontRail {
    if($null -eq $script:StorefrontCatalog -or ((Get-Date)-$script:StorefrontCatalogAt).TotalSeconds -gt 10){Refresh-StorefrontCatalog}
    $heading=New-Object System.Windows.Controls.TextBlock
    $heading.Text='Game Storefronts'
    $heading.FontSize=25;$heading.FontWeight='SemiBold';$heading.Margin='0,0,0,12';$heading.Foreground='#F5F7FB'
    $script:ActionPanel.Children.Add($heading)|Out-Null

    $start=$script:ActionButtons.Count
    $row=New-Object System.Windows.Controls.StackPanel
    $row.Orientation='Horizontal'
    foreach($item in @($script:StorefrontCatalog)){
        $button=New-StorefrontCard $item
        $row.Children.Add($button)|Out-Null
        $script:ActionButtons+=$button
        $script:CurrentActions+=(New-Action "storefront:$($item.Id)" ([string]$item.Name) ([string]$item.Status))
    }
    $scroll=New-Object System.Windows.Controls.ScrollViewer
    $scroll.HorizontalScrollBarVisibility='Hidden';$scroll.VerticalScrollBarVisibility='Disabled';$scroll.PanningMode='HorizontalOnly'
    $scroll.Content=$row;$scroll.Margin='0,0,0,22'
    $script:ActionPanel.Children.Add($scroll)|Out-Null
    $script:HomeRows+=,[pscustomobject]@{Start=$start;Count=@($script:StorefrontCatalog).Count;Platform=$false}
}

function Render-AppsHub {
    Add-StorefrontRail
    Add-HomeRail 'Your Apps' (Convert-ToStableArray $script:Config.CustomApps) 'app' 'Add an application from Library Import and it will appear here.'
}

# ---------------- Native controller keyboard ----------------

function Get-KeyboardThemePalette {
    param([string]$Theme)
    switch($Theme){
        'Light' { return [pscustomobject]@{Overlay='#D9F2F4F8';Panel='#FFF5F7FA';Key='#FFFFFFFF';KeyBorder='#FF8A98AA';Text='#FF101722';Accent='#FF2B66B1';Selected='#FFE6B94D'} }
        'High Contrast' { return [pscustomobject]@{Overlay='#F0000000';Panel='#FF000000';Key='#FF000000';KeyBorder='#FFFFFFFF';Text='#FFFFFFFF';Accent='#FFFFFF00';Selected='#FFFFFF00'} }
        default { return [pscustomobject]@{Overlay='#D90A0F18';Panel='#FF101827';Key='#FF17243A';KeyBorder='#FF3B4D68';Text='#FFF4F6FA';Accent='#FFE7C45E';Selected='#FFE7C45E'} }
    }
}

function Initialize-NativeKeyboardOverlay {
    if($null -eq $script:Window -or $null -ne $script:KeyboardOverlay){return}
    $root=$script:Window.Content
    if($null -eq $root -or -not ($root -is [System.Windows.Controls.Grid])){return}

    $overlay=New-Object System.Windows.Controls.Grid
    $overlay.Visibility='Collapsed'
    $overlay.HorizontalAlignment='Stretch';$overlay.VerticalAlignment='Stretch'
    [System.Windows.Controls.Panel]::SetZIndex($overlay,1200)

    $shade=New-Object System.Windows.Shapes.Rectangle
    $shade.Fill='#D90A0F18'
    $overlay.Children.Add($shade)|Out-Null

    $panel=New-Object System.Windows.Controls.Border
    $panel.Width=1460;$panel.MaxHeight=900;$panel.Padding='30';$panel.CornerRadius=24
    $panel.HorizontalAlignment='Center';$panel.VerticalAlignment='Center'
    $panel.Background='#FF101827';$panel.BorderBrush='#FFE7C45E';$panel.BorderThickness='2'
    $overlay.Children.Add($panel)|Out-Null

    $stack=New-Object System.Windows.Controls.StackPanel
    $panel.Child=$stack

    $titleBlock=New-Object System.Windows.Controls.TextBlock
    $titleBlock.Text='Enter text';$titleBlock.FontSize=28;$titleBlock.FontWeight='Bold';$titleBlock.Foreground='White'
    $stack.Children.Add($titleBlock)|Out-Null

    $inputBox=New-Object System.Windows.Controls.TextBox
    $inputBox.Margin='0,18,0,22';$inputBox.Height=58;$inputBox.FontSize=24;$inputBox.Padding='14,8'
    $inputBox.Background='#FF0A111D';$inputBox.Foreground='White';$inputBox.BorderBrush='#FF52647C';$inputBox.BorderThickness='1.5'
    $stack.Children.Add($inputBox)|Out-Null

    $rowsPanel=New-Object System.Windows.Controls.StackPanel
    $rowsPanel.HorizontalAlignment='Center'
    $stack.Children.Add($rowsPanel)|Out-Null

    $hint=New-Object System.Windows.Controls.TextBlock
    $hint.Text='A / Cross: key   B / Circle: cancel   X / Square: backspace   123 / #+= / ABC: keyboard pages   PASTE: clipboard'
    $hint.Margin='0,20,0,0';$hint.FontSize=14;$hint.Foreground='#AEBBD0';$hint.HorizontalAlignment='Center'
    $stack.Children.Add($hint)|Out-Null

    $root.Children.Add($overlay)|Out-Null

    $script:KeyboardOverlay=$overlay
    $script:KeyboardShade=$shade
    $script:KeyboardPanel=$panel
    $script:KeyboardTitle=$titleBlock
    $script:KeyboardTextBox=$inputBox
    $script:KeyboardRowsPanel=$rowsPanel
    $script:KeyboardHint=$hint
    Build-NativeKeyboardKeys
}

function Build-NativeKeyboardKeys {
    if($null -eq $script:KeyboardRowsPanel){return}
    $script:KeyboardRowsPanel.Children.Clear()
    $script:KeyboardButtonRows=@()
    if([string]::IsNullOrWhiteSpace([string]$script:KeyboardPage)){$script:KeyboardPage='Letters'}
    switch([string]$script:KeyboardPage){
        'Numbers' {$keyRows=@(
            @('1','2','3','4','5','6','7','8','9','0'),
            @('!','@','#','$','%','^','&','*','(',')'),
            @('-','_','=','+','[',']','{','}'),
            @(';',':',"'",'"',',','.','<','>'),
            @('/','?','\','|','`','~'),
            @('ABC','SYMBOLS','TAB','ENTER','SPACE','PASTE','BACKSPACE','CLEAR','OK','CANCEL')
        )}
        'Symbols' {$keyRows=@(
            @('€','£','¥','¢','₹','₩','₽','₿'),
            @('©','®','™','°','±','×','÷','•'),
            @('…','—','–','“','”','‘','’','§'),
            @('←','↑','↓','→','✓','★','♪','♥'),
            @('ABC','123','TAB','ENTER','SPACE','PASTE','BACKSPACE','CLEAR','OK','CANCEL')
        )}
        default {$script:KeyboardPage='Letters';$keyRows=@(
            @('1','2','3','4','5','6','7','8','9','0','-','='),
            @('Q','W','E','R','T','Y','U','I','O','P'),
            @('A','S','D','F','G','H','J','K','L'),
            @('Z','X','C','V','B','N','M'),
            @('SHIFT','123','SYMBOLS','TAB','ENTER','SPACE','PASTE','BACKSPACE','CLEAR','OK','CANCEL')
        )}
    }
    foreach($keyRow in $keyRows){
        $rowPanel=New-Object System.Windows.Controls.StackPanel
        $rowPanel.Orientation='Horizontal';$rowPanel.HorizontalAlignment='Center';$rowPanel.Margin='0,0,0,8'
        $buttons=New-Object System.Collections.ArrayList
        foreach($key in $keyRow){
            $button=New-Object System.Windows.Controls.Button
            $button.Tag=$key
            $button.Content=$(switch($key){'BACKSPACE'{'BACK'}'SYMBOLS'{'#+='}'SPACE'{'SPACE'}default{$key}})
            $button.Height=54
            if($key -eq 'SPACE'){$button.Width=300}
            elseif($key -in @('BACKSPACE','SYMBOLS','PASTE','CLEAR','CANCEL','ENTER')){$button.Width=118}
            elseif($key -in @('SHIFT','ABC','123')){$button.Width=96}
            elseif($key -eq 'OK'){$button.Width=92}
            else{$button.Width=76}
            $button.Margin='4';$button.FontSize=16;$button.FontWeight='SemiBold'
            $button.Add_Click({param($sender,$eventArgs)try{Invoke-NativeKeyboardKey ([string]$sender.Tag)}catch{Write-Log "Keyboard action failed: $($_.Exception.Message)" 'ERROR'}})
            $button.Add_MouseEnter({
                param($sender,$eventArgs)
                if(-not(Test-HcMouseHoverAllowed)){return}
                for($r=0;$r -lt $script:KeyboardButtonRows.Count;$r++){
                    $row=@($script:KeyboardButtonRows[$r])
                    $c=[array]::IndexOf($row,$sender)
                    if($c -ge 0){$script:KeyboardRow=$r;$script:KeyboardColumn=$c;Update-NativeKeyboardVisuals;break}
                }
            })
            $rowPanel.Children.Add($button)|Out-Null
            [void]$buttons.Add($button)
        }
        $script:KeyboardRowsPanel.Children.Add($rowPanel)|Out-Null
        $script:KeyboardButtonRows+=,([object[]]$buttons.ToArray())
    }
    Apply-NativeKeyboardTheme
}

function Apply-NativeKeyboardTheme {
    if($null -eq $script:KeyboardOverlay){return}
    $palette=Get-KeyboardThemePalette ([string]$script:Config.KeyboardTheme)
    $script:KeyboardShade.Fill=$palette.Overlay
    $script:KeyboardPanel.Background=$palette.Panel
    $script:KeyboardPanel.BorderBrush=$palette.Accent
    $script:KeyboardTitle.Foreground=$palette.Text
    $script:KeyboardTextBox.Background=$palette.Key
    $script:KeyboardTextBox.Foreground=$palette.Text
    $script:KeyboardTextBox.BorderBrush=$palette.KeyBorder
    $script:KeyboardHint.Foreground=$palette.Text
    foreach($row in @($script:KeyboardButtonRows)){
        foreach($button in @($row)){
            $button.Background=$palette.Key
            $button.Foreground=$palette.Text
            $button.BorderBrush=$palette.KeyBorder
            $button.BorderThickness='1'
        }
    }
    Update-NativeKeyboardVisuals
}

function Update-NativeKeyboardVisuals {
    if(-not $script:KeyboardActive){return}
    $palette=Get-KeyboardThemePalette ([string]$script:Config.KeyboardTheme)
    for($r=0;$r -lt $script:KeyboardButtonRows.Count;$r++){
        $row=@($script:KeyboardButtonRows[$r])
        for($c=0;$c -lt $row.Count;$c++){
            $button=$row[$c]
            if($r -eq $script:KeyboardRow -and $c -eq $script:KeyboardColumn){
                $button.BorderBrush=$palette.Selected;$button.BorderThickness='3'
                $scale=New-Object System.Windows.Media.ScaleTransform
                $scale.ScaleX=1.06;$scale.ScaleY=1.06
                $button.RenderTransform=$scale;$button.RenderTransformOrigin='0.5,0.5'
            }else{
                $button.BorderBrush=$palette.KeyBorder;$button.BorderThickness='1'
                $button.RenderTransform=[System.Windows.Media.Transform]::Identity
            }
        }
    }
}

function Show-NativeKeyboard {
    param([string]$Title,[string]$InitialText,[string]$Mode,$Context)
    Initialize-NativeKeyboardOverlay
    if($null -eq $script:KeyboardOverlay){return}
    if(-not ($script:KeyboardTitle -is [System.Windows.Controls.TextBlock]) -or -not ($script:KeyboardTextBox -is [System.Windows.Controls.TextBox])){
        Write-Log 'Native keyboard controls were invalid; rebuilding the keyboard overlay.' 'WARN'
        try{if($null -ne $script:KeyboardOverlay -and $null -ne $script:KeyboardOverlay.Parent){[void]$script:KeyboardOverlay.Parent.Children.Remove($script:KeyboardOverlay)}}catch{}
        $script:KeyboardOverlay=$null;$script:KeyboardTitle=$null;$script:KeyboardTextBox=$null;$script:KeyboardRowsPanel=$null
        Initialize-NativeKeyboardOverlay
    }
    if(-not ($script:KeyboardTitle -is [System.Windows.Controls.TextBlock]) -or -not ($script:KeyboardTextBox -is [System.Windows.Controls.TextBox])){
        Write-Log 'Native keyboard could not create valid text controls.' 'ERROR'
        return
    }
    $script:KeyboardActive=$true
    $script:KeyboardMode=$Mode
    $script:KeyboardContext=$Context
    $script:KeyboardSecure=([string]$Mode -in @('BrowserInputSecure','SteamGridDbApiKey'))
    $script:KeyboardSecureBuffer=$(if($script:KeyboardSecure){[string]$InitialText}else{''})
    $script:KeyboardShift=$false
    $script:KeyboardPage='Letters'
    Build-NativeKeyboardKeys
    $script:KeyboardRow=0;$script:KeyboardColumn=0
    try{
        $script:KeyboardTitle.Text=[string]$Title
        $script:KeyboardTextBox.Text=$(if($script:KeyboardSecure){([string]([char]0x2022))*$script:KeyboardSecureBuffer.Length}else{[string]$InitialText})
        $script:KeyboardOverlay.Visibility='Visible'
        Apply-NativeKeyboardTheme
        $script:KeyboardTextBox.Focus()|Out-Null;$script:KeyboardTextBox.CaretIndex=$script:KeyboardTextBox.Text.Length
    }catch{
        $script:KeyboardActive=$false
        try{$script:KeyboardOverlay.Visibility='Collapsed'}catch{}
        try{if($script:HcBrowserActive -and $null -ne $script:HcBrowserWebView){$script:HcBrowserWebView.Visibility='Visible'}}catch{}
        Write-Log "Native keyboard could not open: $($_.Exception.Message)" 'ERROR'
    }
}

function Close-NativeKeyboard {
    param([bool]$Commit)
    if(-not $script:KeyboardActive){return}
    $mode=[string]$script:KeyboardMode
    $context=$script:KeyboardContext
    $value=$(if($script:KeyboardSecure){[string]$script:KeyboardSecureBuffer}else{[string]$script:KeyboardTextBox.Text})
    $script:KeyboardActive=$false
    $script:KeyboardOverlay.Visibility='Collapsed'
    $script:KeyboardMode=''
    $script:KeyboardContext=$null
    $script:KeyboardSecure=$false;$script:KeyboardSecureBuffer=''
    if($script:HcBrowserActive -and $null -ne $script:HcBrowserWebView){try{$script:HcBrowserWebView.Visibility='Visible'}catch{}}
    if($Commit){
        Complete-NativeKeyboardInput $mode $value $context
    }
    Update-Footer
}

function Complete-NativeKeyboardInput {
    param([string]$Mode,[string]$Value,$Context)
    switch($Mode){
        'NameCustomEntry' {
            if($null -eq $Context){return}
            if([string]::IsNullOrWhiteSpace($Value)){$Value=[string](Get-EntryProperty $Context.Entry 'Name' 'Application')}
            $Context.Entry.Name=$Value.Trim()
            if([string]$Context.Type -eq 'Game'){
                $buffer=New-Object System.Collections.ArrayList
                foreach($old in @($script:Config.CustomGames)){if($null -ne $old){[void]$buffer.Add($old)}}
                [void]$buffer.Add($Context.Entry)
                $script:Config.CustomGames=[object[]]$buffer.ToArray()
            }else{
                $buffer=New-Object System.Collections.ArrayList
                foreach($old in @($script:Config.CustomApps)){if($null -ne $old){[void]$buffer.Add($old)}}
                [void]$buffer.Add($Context.Entry)
                $script:Config.CustomApps=[object[]]$buffer.ToArray()
            }
            Save-Config
            Set-ConsoleNotice "$Value was added." 'INFO'
            Render-Page
        }
        'SteamGridDbApiKey' {
            $key=([string]$Value).Trim()
            $script:Config.SteamGridDbApiKey=$key
            Save-Config
            Set-ConsoleNotice $(if($key){'SteamGridDB artwork key saved. Refresh missing box art to use it.'}else{'SteamGridDB artwork key cleared.'}) 'INFO'
            Render-Page
        }
        'CreateFolder' {
            if([string]::IsNullOrWhiteSpace($Value)){return}
            try{
                $newPath=Join-Path ([string]$script:FileBrowserPath) $Value.Trim()
                New-Item -ItemType Directory -Path $newPath -Force | Out-Null
                Set-ConsoleNotice "Folder created: $Value" 'INFO'
                $script:FileBrowserPage=0
                Render-Page
            }catch{Set-ConsoleNotice "Folder could not be created: $($_.Exception.Message)" 'ERROR';Render-Page}
        }
        'BrowserAddress' {
            $target=([string]$Value).Trim()
            if([string]::IsNullOrWhiteSpace($target)){return}
            if($target -notmatch '^[a-zA-Z][a-zA-Z0-9+.-]*://'){
                if($target -match '\s' -or $target -notmatch '^[^/]+\.[^/]+'){$target='https://www.google.com/search?q='+[uri]::EscapeDataString($target)}else{$target='https://'+$target}
            }
            try{$script:HcBrowserWebView.Visibility='Visible';$script:HcBrowserWebView.Source=[uri]$target}catch{Set-ConsoleNotice "Unable to navigate: $($_.Exception.Message)" 'ERROR'}
        }
        {$_ -in @('BrowserInput','BrowserInputSecure')} {
            if(Get-Command Set-HcBrowserInputValue -ErrorAction SilentlyContinue){Set-HcBrowserInputValue ([string]$Value)}
        }
        'ProviderGogAuth' {
            $code=([string]$Value).Trim()
            if([string]::IsNullOrWhiteSpace($code)){Set-ConsoleNotice 'No GOG authorization code was entered.' 'WARN';return}
            Start-GameProviderWorker 'Authenticate' 'GOG' '' '' (Get-ProviderInstallRoot 'GOG') $code
            Set-Tab 4
        }
        'ProviderHesUrl' {
            $url=([string]$Value).Trim().TrimEnd('/')
            if([string]::IsNullOrWhiteSpace($url)){Set-ConsoleNotice 'No HES server address was entered.' 'WARN';return}
            if($url -notmatch '^[a-zA-Z][a-zA-Z0-9+.-]*://'){$url='http://'+$url}
            $script:Config.HesServerUrl=$url
            Save-Config
            $script:ProviderCatalog=$null
            Set-ConsoleNotice "HES server set to $url. Choose Connect to HES to verify it." 'INFO'
            Render-Page
        }
        'ProviderHesApiUrl' {
            $url=([string]$Value).Trim().TrimEnd('/')
            if($url -and $url -notmatch '^[a-zA-Z][a-zA-Z0-9+.-]*://'){$url='http://'+$url}
            $script:Config.HesApiUrl=$url
            Save-Config
            $script:ProviderCatalog=$null
            Set-ConsoleNotice $(if($url){"Direct HES API set to $url. Choose Connect to HES to verify it."}else{'Direct HES API cleared. Automatic endpoint discovery will be used.'}) 'INFO'
            Render-Page
        }
        'ProviderHesPairing' {
            $code=([string]$Value -replace '[^0-9]','')
            if($code.Length -ne 8){Set-ConsoleNotice 'The HES pairing code must contain eight digits.' 'WARN';return}
            Start-GameProviderWorker 'Authenticate' 'HES' '' '' '' $code
            Set-Tab 4
        }
    }
}

function Get-NativeKeyboardBuffer {
    if($script:KeyboardSecure){return [string]$script:KeyboardSecureBuffer}
    return [string]$script:KeyboardTextBox.Text
}
function Set-NativeKeyboardBuffer {
    param([string]$Value)
    if($script:KeyboardSecure){$script:KeyboardSecureBuffer=$Value;$script:KeyboardTextBox.Text=([string]([char]0x2022))*$Value.Length}
    else{$script:KeyboardTextBox.Text=$Value}
}

function Invoke-NativeKeyboardKey {
    param([string]$Key)
    if(-not $script:KeyboardActive){return}
    switch($Key){
        'SHIFT' {$script:KeyboardShift=-not $script:KeyboardShift;return}
        'ABC' {$script:KeyboardPage='Letters';$script:KeyboardRow=0;$script:KeyboardColumn=0;Build-NativeKeyboardKeys;return}
        '123' {$script:KeyboardPage='Numbers';$script:KeyboardRow=0;$script:KeyboardColumn=0;Build-NativeKeyboardKeys;return}
        'SYMBOLS' {$script:KeyboardPage='Symbols';$script:KeyboardRow=0;$script:KeyboardColumn=0;Build-NativeKeyboardKeys;return}
        'SPACE' {Set-NativeKeyboardBuffer ((Get-NativeKeyboardBuffer)+[char]32)}
        'TAB' {Set-NativeKeyboardBuffer ((Get-NativeKeyboardBuffer)+[char]9)}
        'ENTER' {Set-NativeKeyboardBuffer ((Get-NativeKeyboardBuffer)+[Environment]::NewLine)}
        'BACKSPACE' {
            $text=Get-NativeKeyboardBuffer
            if($text.Length -gt 0){Set-NativeKeyboardBuffer ($text.Substring(0,$text.Length-1))}
        }
        'CLEAR' {Set-NativeKeyboardBuffer ''}
        'PASTE' {
            try{
                if([System.Windows.Clipboard]::ContainsText()){Set-NativeKeyboardBuffer ((Get-NativeKeyboardBuffer)+[System.Windows.Clipboard]::GetText())}
            }catch{}
        }
        'OK' {Invoke-UiFeedback 'Confirm';Close-NativeKeyboard $true;return}
        'CANCEL' {Invoke-UiFeedback 'Back';Close-NativeKeyboard $false;return}
        default {
            $value=$Key
            if(-not $script:KeyboardShift){$value=$value.ToLowerInvariant()}
            Set-NativeKeyboardBuffer ((Get-NativeKeyboardBuffer)+$value)
            if($script:KeyboardShift){$script:KeyboardShift=$false}
        }
    }
    try{$script:KeyboardTextBox.CaretIndex=$script:KeyboardTextBox.Text.Length}catch{}
}

function Move-NativeKeyboard {
    param([string]$Direction)
    if(-not $script:KeyboardActive -or $script:KeyboardButtonRows.Count -eq 0){return}
    $oldRow=$script:KeyboardRow;$oldColumn=$script:KeyboardColumn
    switch($Direction){
        'Left' {$script:KeyboardColumn=[math]::Max(0,$script:KeyboardColumn-1)}
        'Right' {$script:KeyboardColumn=[math]::Min(@($script:KeyboardButtonRows[$script:KeyboardRow]).Count-1,$script:KeyboardColumn+1)}
        'Up' {
            $script:KeyboardRow=[math]::Max(0,$script:KeyboardRow-1)
            $script:KeyboardColumn=[math]::Min(@($script:KeyboardButtonRows[$script:KeyboardRow]).Count-1,$script:KeyboardColumn)
        }
        'Down' {
            $script:KeyboardRow=[math]::Min($script:KeyboardButtonRows.Count-1,$script:KeyboardRow+1)
            $script:KeyboardColumn=[math]::Min(@($script:KeyboardButtonRows[$script:KeyboardRow]).Count-1,$script:KeyboardColumn)
        }
    }
    if($oldRow -ne $script:KeyboardRow -or $oldColumn -ne $script:KeyboardColumn){Invoke-UiFeedback 'Navigate';Update-NativeKeyboardVisuals}
}

function Invoke-NativeKeyboardSelected {
    if(-not $script:KeyboardActive){return}
    $row=@($script:KeyboardButtonRows[$script:KeyboardRow])
    if($script:KeyboardColumn -ge 0 -and $script:KeyboardColumn -lt $row.Count){
        Invoke-NativeKeyboardKey ([string]$row[$script:KeyboardColumn].Tag)
    }
}

function Apply-NativeKeyboardNavigation {
    param([int]$Mask,[string]$Direction)
    $now=Get-Date
    if($Direction){
        if($Direction -ne $script:LastDirection -or $now -ge $script:NextDirectionAt){
            Move-NativeKeyboard $Direction
            $script:LastDirection=$Direction
            $script:NextDirectionAt=$now.AddMilliseconds(190)
        }
    }else{
        $script:LastDirection=''
        $script:NextDirectionAt=[datetime]::MinValue
    }
    if(Is-NewButtonPress $Mask 4){Invoke-NativeKeyboardSelected}
    if(Is-NewButtonPress $Mask 8){Close-NativeKeyboard $false}
    if(Is-NewButtonPress $Mask 16){Invoke-NativeKeyboardKey 'BACKSPACE'}
    $script:LastGamepadMask=$Mask
}

function Cycle-KeyboardTheme {
    $themes=@('Huymaier','Light','High Contrast')
    $index=[array]::IndexOf($themes,[string]$script:Config.KeyboardTheme)
    if($index -lt 0){$index=0}
    $script:Config.KeyboardTheme=$themes[($index+1)%$themes.Count]
    Save-Config
    Apply-NativeKeyboardTheme
    Render-Page
}
