param(
    [switch]$Windowed
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Xaml
try { Add-Type -AssemblyName System.Runtime.WindowsRuntime -ErrorAction SilentlyContinue } catch { }

$script:AppVersion = '0.26.0'
$script:AppName = 'Huymaier Console'
$script:DataDir = Join-Path $env:LOCALAPPDATA 'Huymaier Console'
$script:ConfigPath = Join-Path $script:DataDir 'config.json'
$script:LogDir = Join-Path $script:DataDir 'Logs'
$script:BaseDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$script:NativeDisplayPath = Join-Path $script:BaseDir 'HuymaierNativeDisplay.cs'
$script:NativeAudioPath = Join-Path $script:BaseDir 'HuymaierNativeAudio.cs'
$script:NativeInputPath = Join-Path $script:BaseDir 'HuymaierNativeInput.cs'
$script:NativePerformancePath = Join-Path $script:BaseDir 'HuymaierPerformance.cs'
$script:UpdateWorkerPath = Join-Path $script:BaseDir 'HuymaierUpdateWorker.ps1'
$script:DriverWorkerPath = Join-Path $script:BaseDir 'HuymaierDriverWorker.ps1'
$script:LibraryWorkerPath = Join-Path $script:BaseDir 'HuymaierLibraryWorker.ps1'
$script:StorefrontModulePath = Join-Path $script:BaseDir 'HuymaierStorefronts.ps1'
$script:StorefrontWorkerPath = Join-Path $script:BaseDir 'HuymaierStorefrontWorker.ps1'
$script:ProviderModulePath = Join-Path $script:BaseDir 'HuymaierGameProviders.ps1'
$script:ProviderWorkerPath = Join-Path $script:BaseDir 'HuymaierGameProviderWorker.ps1'
$script:ArtworkWorkerPath = Join-Path $script:BaseDir 'HuymaierArtworkWorker.ps1'
$script:Ps3LibraryWorkerPath = Join-Path $script:BaseDir 'HuymaierPs3LibraryWorker.ps1'
$script:Ps2LibraryWorkerPath = Join-Path $script:BaseDir 'HuymaierPs2LibraryWorker.ps1'
$script:Ps1LibraryWorkerPath = Join-Path $script:BaseDir 'HuymaierPs1LibraryWorker.ps1'
$script:NativeConsoleLibraryWorkerPath = Join-Path $script:BaseDir 'HuymaierNativeConsoleLibraryWorker.ps1'
$script:GameExperienceModulePath = Join-Path $script:BaseDir 'HuymaierGameExperience.ps1'
$script:ShellRedesignModulePath = Join-Path $script:BaseDir 'HuymaierShellRedesign.ps1'
$script:EmulatorPlatformsModulePath = Join-Path $script:BaseDir 'HuymaierEmulatorPlatforms.ps1'
$script:WebBrowserModulePath = Join-Path $script:BaseDir 'HuymaierWebBrowser.ps1'
$script:GameBarModulePath = Join-Path $script:BaseDir 'HuymaierGameBar.ps1'
$script:NavItems = @('Home','Games','Apps','Web','Downloads','Import','File Explorer','Settings','Power')
$script:SelectedTab = 0
$script:SelectedAction = 0
$script:NavigationLayer = 'Content'
$script:NavigationReturnAction = 0
$script:PreferredRailColumn = 0
$script:SliderControls = @{}
$script:CurrentActions = @()
$script:NavButtons = @()
$script:ActionButtons = @()
$script:DetectedBrowsers = @()
$script:LastPromptFamily = 'Keyboard'
$script:ConnectedControllerName = 'Keyboard / Mouse'
$script:LastGamepadMask = 0
$script:LastDirection = ''
$script:NextDirectionAt = [datetime]::MinValue
$script:ControllerInputGuardUntil = [datetime]::MinValue
$script:LastControllerSignature = ''
$script:LastKeyboardInputAt = Get-Date
$script:GamepadApiAvailable = $false
$script:RawGamepadApiAvailable = $false
$script:LegacyGamepadApiAvailable = $false
$script:RawHidGamepadApiAvailable = $false
$script:RawInputSource = $null
$script:RawInputHook = $null
$script:IsClosing = $false
$script:LastRawControllerErrorAt = [datetime]::MinValue
$script:LegacyControllerCenters = @{}
$script:LegacyControllerNeutralCounts = @{}
$script:NativeControllerNeutralCounts = @{}
$script:SubPage = ''
$script:UpdateStatePath = Join-Path $script:DataDir 'windows-update-state.json'
$script:UpdateState = $null
$script:UpdateStateSignature = ''
$script:DriverStatePath = Join-Path $script:DataDir 'driver-state.json'
$script:DriverState = $null
$script:DriverStateSignature = ''
$script:Displays = @()
$script:DisplayIndex = 0
$script:DisplayModes = @()
$script:PendingWidth = 0
$script:PendingHeight = 0
$script:PendingFrequency = 0
$script:DisplayPreviousMode = $null
$script:DisplayPendingConfirmation = $false
$script:DisplayConfirmUntil = [datetime]::MinValue
$script:MusicPlayer = $null
$script:MusicPath = Join-Path $script:BaseDir 'Assets\HuymaierOrchestralTheme.wav'
$script:SfxPaths = @{
    Navigate = Join-Path $script:BaseDir 'Assets\Navigate.wav'
    Tab = Join-Path $script:BaseDir 'Assets\Tab.wav'
    Confirm = Join-Path $script:BaseDir 'Assets\Confirm.wav'
    Back = Join-Path $script:BaseDir 'Assets\Back.wav'
}
$script:SfxPlayers = @{}
$script:ActiveGamepadIndex = 0
$script:HomeRows = @()
$script:SelectedGamePlatform = 'Steam'
$script:FsePackageName = 'Huymaier.Console.FSE.Home'
$script:FseRegisterScript = Join-Path $script:BaseDir 'Register-HuymaierFSEHome.ps1'
$script:GameHubPlatforms = @()
$script:GameHubLaunchEntries = @()
$script:AudioEndpoints = @()
$script:AudioIndex = 0
$script:BluetoothDevices = @()
$script:DeviceRefreshAt = [datetime]::MinValue
$script:InitialScanTimer = $null
$script:LibraryStatePath = Join-Path $script:DataDir 'library-scan-state.json'
$script:LibraryResultPath = Join-Path $script:DataDir 'library-scan-result.json'
$script:LibraryState = $null
$script:LibraryStateSignature = ''
$script:LibraryResultSignature = ''
try { if (Test-Path -LiteralPath $script:LibraryResultPath -PathType Leaf) { $script:LibraryResultSignature = (Get-Item -LiteralPath $script:LibraryResultPath).LastWriteTimeUtc.Ticks.ToString() } } catch { }
$script:FileBrowserPath = ''
$script:FileBrowserMode = 'Browse'
$script:FileBrowserStore = ''
$script:FileBrowserEntryType = ''
$script:FileBrowserReturnTab = 0
$script:FileBrowserReturnSubPage = ''
$script:FileBrowserEntries = @()
$script:FileBrowserPage = 0
$script:FileBrowserPageSize = 80
$script:PendingConfirmation = $null
$script:ConsoleNotice = ''
$script:StorefrontStatePath = Join-Path $script:DataDir 'storefront-state.json'
$script:StorefrontDownloadDir = Join-Path $script:DataDir 'Installers'
$script:StorefrontState = $null
$script:StorefrontStateSignature = ''
$script:StorefrontCatalog = @()
$script:StorefrontCatalogAt = [datetime]::MinValue
$script:ProviderRoot = Join-Path $script:DataDir 'GameProviders'
$script:ProviderToolRoot = Join-Path $script:ProviderRoot 'Tools'
$script:ProviderArtworkRoot = Join-Path $script:ProviderRoot 'Artwork'
$script:ProviderStatePath = Join-Path $script:ProviderRoot 'provider-state.json'
$script:ProviderCatalogPath = Join-Path $script:ProviderRoot 'provider-catalog.json'
$script:ProviderState = $null
$script:ProviderCatalog = $null
$script:ProviderStateSignature = ''
$script:LastArtworkProviderRefreshToken = ''
$script:ProviderCatalogSignature = ''
$script:ProviderGameEntries = @()
$script:SelectedProviderGame = $null
$script:ProviderWorkerProcess = $null
$script:LastProviderWorkerStartUtc = [datetime]::MinValue
$script:ProviderMovePending = $false
$script:ArtworkCacheRoot = Join-Path $script:DataDir 'ArtworkCache'
$script:ArtworkStatePath = Join-Path $script:DataDir 'artwork-state.json'
$script:ArtworkResultPath = Join-Path $script:DataDir 'artwork-result.json'
$script:ArtworkStateSignature = ''
$script:ArtworkResultSignature = ''
try { if (Test-Path -LiteralPath $script:ArtworkResultPath -PathType Leaf) { $script:ArtworkResultSignature = (Get-Item -LiteralPath $script:ArtworkResultPath).LastWriteTimeUtc.Ticks.ToString() } } catch { }
$script:ArtworkWorkerProcess = $null
$script:ArtworkContinuationTimer = $null
$script:ArtworkScanPlatform = ''
$script:PendingArtworkPlatform = ''
$script:Ps3SummaryPath = Join-Path $script:DataDir 'EmulatorPlatforms\PS3\library-summary.json'
$script:Ps3SummarySignature = ''
$script:Ps3SummaryWorkerProcess = $null
$script:LastPs3SummaryStartAt = [datetime]::MinValue
$script:Ps2SummaryPath = Join-Path $script:DataDir 'EmulatorPlatforms\PS2\library-summary.json'
$script:Ps2SummarySignature = ''
$script:Ps2SummaryWorkerProcess = $null
$script:LastPs2SummaryStartAt = [datetime]::MinValue
$script:Ps1SummaryPath = Join-Path $script:DataDir 'EmulatorPlatforms\PS1\library-summary.json'
$script:Ps1SummarySignature = ''
$script:Ps1SummaryWorkerProcess = $null
$script:LastPs1SummaryStartAt = [datetime]::MinValue
$script:NativeConsoleSummaryProcesses = @{}
$script:NativeConsoleSummaryLastStart = @{}
$script:NativeConsoleSummarySignatures = @{}
$script:NextConsoleCountRefreshAt = [datetime]::MinValue
$script:ImageSourceCache = @{}
$script:ImageSourceCacheOrder = New-Object System.Collections.ArrayList
$script:ShelfEntries = @()
$script:ShelfTitleText = $null
$script:ShelfDetailText = $null
# Keep every shelf state field defined even while the shared cinematic renderer
# replaces the old preview UI. This prevents strict-mode failures during
# controller hot-plug, restart recovery, or a page rebuild.
$script:ShelfGalleryPaths = @()
$script:ShelfPreviewIndex = 0
$script:ShelfPreviewImage = $null
$script:ShelfPreviewCountText = $null
$script:ShelfPreviewThumbPanel = $null
$script:LastArtworkWorkerStartAt = [datetime]::MinValue
$script:PreventAutoCloseUntil = [datetime]::MinValue
$script:AllowWindowClose = $false
$script:ControllerCursorHidden = $false
$script:IgnoreMouseMoveUntil = [datetime]::MinValue
$script:ControllerParkedCursorPosition = [long]0
$script:LastMousePoint = $null
$script:LastPhysicalCursorPosition = [long]0
$script:LastPhysicalMouseAt = [datetime]::MinValue
$script:FpsMonitorStarted = $false
$script:PlatformAnimationsRunning = $false
$script:KeyboardOverlay = $null
$script:KeyboardActive = $false
$script:KeyboardMode = ''
$script:KeyboardContext = $null
$script:KeyboardShift = $false
$script:KeyboardRowsPanel = $null
$script:KeyboardButtonRows = @()
$script:KeyboardRow = 0
$script:KeyboardColumn = 0
$script:KeyboardPage = 'Letters'
$script:HcBrowserOverlay = $null
$script:HcBrowserHost = $null
$script:HcBrowserWebView = $null
$script:HcBrowserReady = $false
$script:HcBrowserActive = $false
$script:HcBrowserFocusArea = 'Web'
$script:HcBrowserToolbarRequested = $false
$script:HcBrowserAuthTimer = $null
$script:BuiltInMusic = @{
    Orchestral = Join-Path $script:BaseDir 'Assets\HuymaierOrchestralTheme.wav'
    Power = Join-Path $script:BaseDir 'Assets\HuymaierPowerTheme.wav'
}

New-Item -ItemType Directory -Force -Path $script:DataDir, $script:LogDir, $script:StorefrontDownloadDir, $script:ProviderRoot, $script:ProviderToolRoot, $script:ProviderArtworkRoot, $script:ArtworkCacheRoot | Out-Null

try {
    if (Test-Path $script:NativeDisplayPath) { Add-Type -Path $script:NativeDisplayPath -ErrorAction Stop }
} catch { }
try {
    if (Test-Path $script:NativeAudioPath) { Add-Type -Path $script:NativeAudioPath -ErrorAction Stop }
} catch { }
try {
    if (Test-Path $script:NativeInputPath) { Add-Type -Path $script:NativeInputPath -ErrorAction Stop }
} catch { }
try {
    if (Test-Path $script:NativePerformancePath) { Add-Type -Path $script:NativePerformancePath -ReferencedAssemblies @('System.dll','System.Core.dll','WindowsBase.dll','PresentationCore.dll') -ErrorAction Stop }
} catch { }

function Write-Log {
    param([string]$Message, [string]$Level = 'INFO')
    try {
        $path = Join-Path $script:LogDir "$(Get-Date -Format 'yyyy-MM-dd').log"
        "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff') [$Level] $Message" | Add-Content -Path $path -Encoding UTF8
    } catch { }
}


try {
    Set-Item -Path Function:global:Write-Log -Value ${function:Write-Log} -Force
} catch { }

function Set-ConsoleNotice {

    param([string]$Message,[string]$Level='INFO')
    $script:ConsoleNotice=$Message
    Write-Log $Message $Level
    try { if($null -ne $script:PageSubtitle -and $script:PageSubtitle.Visibility -eq 'Visible'){$script:PageSubtitle.Text=$Message} } catch { }
}

function Convert-ToStableArray {
    param($Value)
    $buffer = New-Object System.Collections.ArrayList
    if ($null -ne $Value) {
        try {
            foreach ($item in $Value) { [void]$buffer.Add($item) }
        } catch {
            [void]$buffer.Add($Value)
        }
    }
    return ,([object[]]$buffer.ToArray())
}

function New-DefaultConfig {
    [pscustomobject]@{
        BrowserName = ''
        BrowserPath = ''
        BrowserMode = 'Fullscreen'
        PromptOverride = 'Auto'
        StartWithWindows = $false
        CustomGames = @()
        CustomApps = @()
        MusicEnabled = $true
        MusicVolume = 30
        DynamicBackground = $true
        UiSoundsEnabled = $true
        HapticsEnabled = $true
        MusicTheme = 'Orchestral'
        CustomMusicPath = ''
        ImportedGames = @()
        RecentGames = @()
        RecentApps = @()
        StorefrontRoots = @()
        StorefrontInstallOverrides = @()
        QuickMenuPosition = 'Bottom'
        ProviderInstallRoots = @()
        LibraryScanCompleted = $false
        LibrarySchemaVersion = 1
        KeyboardTheme = 'Huymaier'
        ShowFpsCounter = $false
        OnlineArtworkEnabled = $true
        PlatformBackgroundsEnabled = $true
        FavoriteGames = @()
    }
}

function Load-Config {
    $defaults = New-DefaultConfig
    if ( -not (Test-Path $script:ConfigPath)) { return $defaults }
    try {
        $loaded = Get-Content -Raw -Path $script:ConfigPath | ConvertFrom-Json
        foreach ($name in @('BrowserName','BrowserPath','BrowserMode','PromptOverride','StartWithWindows','CustomGames','CustomApps','MusicEnabled','MusicVolume','DynamicBackground','UiSoundsEnabled','HapticsEnabled','MusicTheme','CustomMusicPath','ImportedGames','RecentGames','RecentApps','StorefrontRoots','StorefrontInstallOverrides','QuickMenuPosition','ProviderInstallRoots','LibraryScanCompleted','LibrarySchemaVersion','KeyboardTheme','ShowFpsCounter','OnlineArtworkEnabled','PlatformBackgroundsEnabled','FavoriteGames')) {
            if ($null -ne $loaded.PSObject.Properties[$name]) {
                $defaults.$name = $loaded.$name
            }
        }
    } catch {
        Write-Log "Config load failed: $($_.Exception.Message)" 'WARN'
    }
    # PowerShell can unwrap JSON/argument collections into $null or a scalar.
    # Keep every persisted list array-shaped so first-run, one-item, and many-item
    # machines take the same code paths under StrictMode.
    foreach ($collectionName in @('CustomGames','CustomApps','ImportedGames','RecentGames','RecentApps','StorefrontRoots','StorefrontInstallOverrides','ProviderInstallRoots','FavoriteGames')) {
        $defaults.$collectionName = Convert-ToStableArray $defaults.$collectionName
    }
    return $defaults
}

function Save-Config {
    try {
        $script:Config | ConvertTo-Json -Depth 8 | Set-Content -Path $script:ConfigPath -Encoding UTF8
    } catch {
        Write-Log "Config save failed: $($_.Exception.Message)" 'ERROR'
    }
}

$script:Config = Load-Config

if (Test-Path -LiteralPath $script:StorefrontModulePath) {
    try { . $script:StorefrontModulePath }
    catch { Write-Log "Storefront module load failed: $($_.Exception.Message)" 'ERROR' }
}

if (Test-Path -LiteralPath $script:ProviderModulePath) {
    try { . $script:ProviderModulePath }
    catch { Write-Log "Game provider module load failed: $($_.Exception.Message)" 'ERROR' }
}

function Parse-ExecutableFromCommand {
    param([string]$Command)
    if ([string]::IsNullOrWhiteSpace($Command)) { return $null }
    $expanded = [Environment]::ExpandEnvironmentVariables($Command.Trim())
    if ($expanded -match '^\s*"([^"]+\.exe)"') { return $matches[1] }
    if ($expanded -match '^\s*([^\s]+\.exe)') { return $matches[1] }
    return $null
}

function Get-InstalledBrowsers {
    $found = New-Object System.Collections.Generic.List[object]
    $roots = @(
        'HKCU:\Software\Clients\StartMenuInternet',
        'HKLM:\Software\Clients\StartMenuInternet',
        'HKLM:\Software\WOW6432Node\Clients\StartMenuInternet'
    )

    foreach ($root in $roots) {
        if ( -not (Test-Path $root)) { continue }
        foreach ($child in Get-ChildItem $root -ErrorAction SilentlyContinue) {
            try {
                $name = $child.GetValue('')
                if ([string]::IsNullOrWhiteSpace($name)) { $name = $child.PSChildName }
                $commandKey = Join-Path $child.PSPath 'shell\open\command'
                if ( -not (Test-Path $commandKey)) { continue }
                $command = (Get-Item $commandKey).GetValue('')
                $exe = Parse-ExecutableFromCommand $command
                if ($exe -and (Test-Path $exe)) {
                    $found.Add([pscustomobject]@{ Name = [string]$name; Path = [string]$exe })
                }
            } catch { }
        }
    }

    $fallbacks = @(
        @{ Name='Microsoft Edge'; Paths=@("$env:ProgramFiles (x86)\Microsoft\Edge\Application\msedge.exe", "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe") },
        @{ Name='Google Chrome'; Paths=@("$env:ProgramFiles\Google\Chrome\Application\chrome.exe", "$env:ProgramFiles (x86)\Google\Chrome\Application\chrome.exe", "$env:LOCALAPPDATA\Google\Chrome\Application\chrome.exe") },
        @{ Name='Mozilla Firefox'; Paths=@("$env:ProgramFiles\Mozilla Firefox\firefox.exe", "$env:ProgramFiles (x86)\Mozilla Firefox\firefox.exe") },
        @{ Name='Brave'; Paths=@("$env:ProgramFiles\BraveSoftware\Brave-Browser\Application\brave.exe", "$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\Application\brave.exe") },
        @{ Name='Opera GX'; Paths=@("$env:LOCALAPPDATA\Programs\Opera GX\launcher.exe") },
        @{ Name='Opera'; Paths=@("$env:LOCALAPPDATA\Programs\Opera\launcher.exe") },
        @{ Name='Vivaldi'; Paths=@("$env:LOCALAPPDATA\Vivaldi\Application\vivaldi.exe", "$env:ProgramFiles\Vivaldi\Application\vivaldi.exe") }
    )

    foreach ($entry in $fallbacks) {
        foreach ($path in $entry.Paths) {
            if ($path -and (Test-Path $path)) {
                $found.Add([pscustomobject]@{ Name = $entry.Name; Path = $path })
                break
            }
        }
    }

    $deduped = Convert-ToStableArray ($found | Group-Object { $_.Path.ToLowerInvariant() } | ForEach-Object { $_.Group[0] } | Sort-Object Name)
    return $deduped
}

function Ensure-BrowserSelection {
    $script:DetectedBrowsers = Convert-ToStableArray (Get-InstalledBrowsers)
    if ($script:Config.BrowserPath -and (Test-Path $script:Config.BrowserPath)) { return }
    if ($script:DetectedBrowsers.Count -gt 0) {
        $script:Config.BrowserName = $script:DetectedBrowsers[0].Name
        $script:Config.BrowserPath = $script:DetectedBrowsers[0].Path
        Save-Config
    }
}

Ensure-BrowserSelection

function Get-EntryProperty {
    param($Object, [string]$Name, $Default = '')
    if ($null -eq $Object) { return $Default }
    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property -or $null -eq $property.Value) { return $Default }
    return $property.Value
}

function Add-UniquePath {
    param([System.Collections.ArrayList]$List, $Path)
    if ($null -eq $Path) { return }
    if ($Path -is [System.Array]) {
        foreach ($part in $Path) { Add-UniquePath $List $part }
        return
    }
    $text = [string]$Path
    if ([string]::IsNullOrWhiteSpace($text)) { return }
    try { $full = [IO.Path]::GetFullPath([Environment]::ExpandEnvironmentVariables($text.Trim())) } catch { $full = $text.Trim() }
    foreach ($item in $List) {
        if ([string]::Equals([string]$item,$full,[StringComparison]::OrdinalIgnoreCase)) { return }
    }
    [void]$List.Add($full)
}

function Get-ConfiguredRoots {
    param([string]$Store)
    foreach ($entry in @($script:Config.StorefrontRoots)) {
        if ($null -eq $entry) { continue }
        $entryStore = [string](Get-EntryProperty $entry 'Store' '')
        $entryPath = [string](Get-EntryProperty $entry 'Path' '')
        if ($entryStore -eq $Store -and -not [string]::IsNullOrWhiteSpace($entryPath)) { $entryPath }
    }
}

function Add-StorefrontLocation {
    param([ValidateSet('Steam','Epic','GOG','EA','Ubisoft','Xbox','Battle.net','Rockstar','Amazon','Generic')][string]$Store)
    Start-NativeFilePicker -Mode 'PickFolder' -Store $Store -ReturnTab 5
}

function Get-SteamLibraryRoots {
    $roots = New-Object System.Collections.ArrayList
    foreach ($key in @('HKCU:\\Software\\Valve\\Steam','HKLM:\\SOFTWARE\\WOW6432Node\\Valve\\Steam','HKLM:\\SOFTWARE\\Valve\\Steam')) {
        try {
            $props = Get-ItemProperty $key -ErrorAction Stop
            foreach ($name in @('SteamPath','InstallPath')) { if ($props.PSObject.Properties[$name]) { Add-UniquePath $roots ([string]$props.$name) } }
        } catch { }
    }
    foreach ($root in @(Get-ConfiguredRoots 'Steam')) { Add-UniquePath $roots ([string]$root) }
    $seed = @($roots)
    foreach ($root in $seed) {
        $vdf = Join-Path $root 'steamapps\\libraryfolders.vdf'
        if ( -not (Test-Path $vdf)) { continue }
        try {
            $text = Get-Content -Raw $vdf
            foreach ($match in [regex]::Matches($text,'"path"\s+"([^"]+)"')) {
                Add-UniquePath $roots ($match.Groups[1].Value -replace '\\\\','\\')
            }
        } catch { }
    }
    return ,([object[]]$roots.ToArray())
}

function Get-SteamArtwork {
    param([string]$Root,[string]$AppId)
    $artRoots=New-Object System.Collections.ArrayList
    Add-UniquePath $artRoots $Root
    foreach($key in @('HKCU:\Software\Valve\Steam','HKLM:\SOFTWARE\WOW6432Node\Valve\Steam','HKLM:\SOFTWARE\Valve\Steam')){
        try{$props=Get-ItemProperty $key -ErrorAction Stop;foreach($name in @('SteamPath','InstallPath')){if($props.PSObject.Properties[$name]){Add-UniquePath $artRoots ([string]$props.$name)}}}catch{}
    }
    foreach($artRoot in $artRoots){
        foreach($candidate in @(
            (Join-Path $artRoot "appcache\librarycache\${AppId}_library_600x900.jpg"),
            (Join-Path $artRoot "appcache\librarycache\${AppId}_library_600x900.png"),
            (Join-Path $artRoot "appcache\librarycache\$AppId\library_600x900.jpg"),
            (Join-Path $artRoot "appcache\librarycache\$AppId\library_600x900.png")
        )){if(Test-Path $candidate){return $candidate}}
        $userdata=Join-Path $artRoot 'userdata'
        if(Test-Path $userdata){
            foreach($user in Get-ChildItem $userdata -Directory -ErrorAction SilentlyContinue){
                $grid=Join-Path $user.FullName 'config\grid'
                foreach($extension in @('jpg','png','webp','jpeg')){
                    $candidate=Join-Path $grid "${AppId}p.$extension"
                    if(Test-Path $candidate){return $candidate}
                }
            }
        }
    }
    return ''
}

function Import-SteamGames {
    param([System.Collections.ArrayList]$Target)
    foreach ($root in @(Get-SteamLibraryRoots)) {
        $steamapps = Join-Path $root 'steamapps'
        if ( -not (Test-Path $steamapps)) { continue }
        foreach ($manifest in Get-ChildItem $steamapps -Filter 'appmanifest_*.acf' -File -ErrorAction SilentlyContinue) {
            try {
                $text = Get-Content -Raw $manifest.FullName
                $appid = [regex]::Match($text,'"appid"\s+"([^"]+)"').Groups[1].Value
                $name = [regex]::Match($text,'"name"\s+"([^"]+)"').Groups[1].Value
                $dir = [regex]::Match($text,'"installdir"\s+"([^"]+)"').Groups[1].Value
                if ( -not $appid -or -not $name) { continue }
                [void]$Target.Add([pscustomobject]@{
                    Id="Steam:$appid"; Name=$name; Source='Steam'; LaunchTarget="steam://rungameid/$appid";
                    Path=(Join-Path $steamapps "common\\$dir"); ArtworkPath=(Get-SteamArtwork $root $appid)
                })
            } catch { }
        }
    }
}

function Test-EpicInstalledManifestGame {
    param($Item)
    if($null -eq $Item){return $false}
    $name=[string](Get-EntryProperty $Item 'DisplayName')
    $install=[string](Get-EntryProperty $Item 'InstallLocation')
    $exe=[string](Get-EntryProperty $Item 'LaunchExecutable')
    $app=[string](Get-EntryProperty $Item 'AppName')
    $combined=("$name`n$install`n$exe`n$app").ToLowerInvariant()
    if([string]::IsNullOrWhiteSpace($name) -or [string]::IsNullOrWhiteSpace($install)){return $false}
    # Epic writes engine, editor, Marketplace and developer-tool manifests into
    # the same directory as games. Keep actual games (including Unreal
    # Tournament), but exclude products that are not launchable games.
    if($combined -match '(?i)[\\/](ue_[0-9][^\\/]*|engine|directxredist|epicgameslauncher)[\\/]'){return $false}
    if($exe -match '(?i)(UnrealEditor|UE4Editor|EpicGamesLauncher|BuildPatchTool|CrashReportClient)\.exe'){return $false}
    if($name -match '(?i)^(Unreal Engine|Unreal Editor|Twinmotion|RealityCapture|MetaHuman|Quixel Bridge|Fab|Epic Online Services|Unreal Datasmith|Unreal Marketplace)\b'){return $false}
    if($name -match '(?i)\b(Plugin|Asset Pack|Content Pack|Starter Content|Content Examples|Feature Pack|SDK|Mod Kit|Editor Symbols|Debug Symbols|Source Code)\b'){return $false}
    $build=[string](Get-EntryProperty $Item 'BuildVersion');$namespace=[string](Get-EntryProperty $Item 'CatalogNamespace')
    if(("$build`n$namespace`n$combined") -match '(?i)(Dev-Marketplace|Marketplace-Windows|UE[45]\+Dev-Marketplace|VaultCache|UEFN)'){return $false}
    return $true
}

function Import-EpicGames {
    param([System.Collections.ArrayList]$Target)
    $roots = New-Object System.Collections.ArrayList
    Add-UniquePath $roots "$env:ProgramData\\Epic\\EpicGamesLauncher\\Data\\Manifests"
    foreach ($root in @(Get-ConfiguredRoots 'Epic')) { Add-UniquePath $roots ([string]$root) }
    foreach ($root in $roots) {
        if ( -not (Test-Path $root)) { continue }
        foreach ($file in Get-ChildItem $root -Filter '*.item' -File -Recurse -ErrorAction SilentlyContinue) {
            try {
                $item = Get-Content -Raw $file.FullName | ConvertFrom-Json
                if(-not (Test-EpicInstalledManifestGame $item)){continue}
                $name = [string](Get-EntryProperty $item 'DisplayName')
                $install = [string](Get-EntryProperty $item 'InstallLocation')
                $exeRel = [string](Get-EntryProperty $item 'LaunchExecutable')
                if ( -not $name -or -not $install) { continue }
                $exe = if ($exeRel) { Join-Path $install $exeRel } else { '' }
                if ($exe -and -not (Test-Path $exe)) { $exe='' }
                $catalog = [string](Get-EntryProperty $item 'CatalogItemId')
                $appName = [string](Get-EntryProperty $item 'AppName')
                $target = if ($appName) { "com.epicgames.launcher://apps/$appName?action=launch&silent=true" } elseif ($exe) { $exe } else { '' }
                if ( -not $target) { continue }
                [void]$Target.Add([pscustomobject]@{ Id="Epic:${catalog}:$appName"; Name=$name; Source='Epic'; LaunchTarget=$target; Path=$install; ArtworkPath='' })
            } catch { }
        }
    }
}

function Import-GogGames {
    param([System.Collections.ArrayList]$Target)
    $roots = New-Object System.Collections.ArrayList
    foreach ($root in @(Get-ConfiguredRoots 'GOG')) { Add-UniquePath $roots ([string]$root) }
    foreach ($keyRoot in @('HKLM:\\SOFTWARE\\WOW6432Node\\GOG.com\\Games','HKLM:\\SOFTWARE\\GOG.com\\Games')) {
        if ( -not (Test-Path $keyRoot)) { continue }
        foreach ($key in Get-ChildItem $keyRoot -ErrorAction SilentlyContinue) {
            try {
                $props=Get-ItemProperty $key.PSPath
                $name=[string]$props.gameName; $id=[string]$key.PSChildName; $path=[string]$props.path
                $exe=[string]$props.exe
                if ($exe -and -not [IO.Path]::IsPathRooted($exe)) { $exe=Join-Path $path $exe }
                if ($name -and $exe -and (Test-Path $exe)) { [void]$Target.Add([pscustomobject]@{Id="GOG:$id";Name=$name;Source='GOG';LaunchTarget=$exe;Path=$path;ArtworkPath=''}) }
                Add-UniquePath $roots $path
            } catch { }
        }
    }
    foreach ($root in $roots) {
        if ( -not (Test-Path $root)) { continue }
        foreach ($info in Get-ChildItem $root -Filter 'goggame-*.info' -File -Recurse -ErrorAction SilentlyContinue) {
            try {
                $g=Get-Content -Raw $info.FullName|ConvertFrom-Json
                $name=[string](Get-EntryProperty $g 'name'); $id=[string](Get-EntryProperty $g 'gameId')
                $task=@(Get-EntryProperty $g 'playTasks' @()) | Where-Object { [string](Get-EntryProperty $_ 'category') -eq 'game' } | Select-Object -First 1
                $exe=[string](Get-EntryProperty $task 'path'); if ($exe -and -not [IO.Path]::IsPathRooted($exe)) { $exe=Join-Path $info.DirectoryName $exe }
                if ($name -and $exe -and (Test-Path $exe)) { [void]$Target.Add([pscustomobject]@{Id="GOG:$id";Name=$name;Source='GOG';LaunchTarget=$exe;Path=$info.DirectoryName;ArtworkPath=''}) }
            } catch { }
        }
    }
}

function Import-UbisoftGames {
    param([System.Collections.ArrayList]$Target)
    foreach ($root in @('HKLM:\\SOFTWARE\\WOW6432Node\\Ubisoft\\Launcher\\Installs','HKLM:\\SOFTWARE\\Ubisoft\\Launcher\\Installs')) {
        if ( -not (Test-Path $root)) { continue }
        foreach ($key in Get-ChildItem $root -ErrorAction SilentlyContinue) {
            try {
                $props=Get-ItemProperty $key.PSPath; $id=[string]$key.PSChildName; $path=[string]$props.InstallDir
                if ($path) { [void]$Target.Add([pscustomobject]@{Id="Ubisoft:$id";Name=(Split-Path $path -Leaf);Source='Ubisoft';LaunchTarget="uplay://launch/$id/0";Path=$path;ArtworkPath=''}) }
            } catch { }
        }
    }
}

function Import-RegisteredStoreGames {
    param([System.Collections.ArrayList]$Target)
    $stores=@(
        [pscustomobject]@{Source='Battle.net';Publisher='Blizzard|Activision Blizzard'},
        [pscustomobject]@{Source='Rockstar';Publisher='Rockstar Games'},
        [pscustomobject]@{Source='Amazon';Publisher='Amazon Games'}
    )
    foreach($root in @('HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall','HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall')){
        if( -not (Test-Path $root)){continue}
        foreach($key in Get-ChildItem $root -ErrorAction SilentlyContinue){
            try{
                $props=Get-ItemProperty $key.PSPath;$publisher=[string]$props.Publisher;$match=$null
                foreach($store in $stores){if ($publisher -match $store.Publisher){$match=$store;break}}
                if ($null -eq $match){continue}
                $name=[string]$props.DisplayName;$install=[string]$props.InstallLocation;$icon=[string]$props.DisplayIcon
                if($icon){$icon=$icon.Trim('"');if($icon -match '^(.*?\.exe)'){$icon=$matches[1]}}
                $exe = if ($icon -and (Test-Path $icon)) { $icon } else { '' }
                if ( -not $exe -and $install -and (Test-Path $install)) { $candidate = Get-ChildItem $install -Filter '*.exe' -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -notmatch 'unins|setup|crash|report' } | Select-Object -First 1; if ($candidate) { $exe = $candidate.FullName } }
                if ($name -and $exe) {[void]$Target.Add([pscustomobject]@{Id="$($match.Source):$($key.PSChildName)";Name=$name;Source=$match.Source;LaunchTarget=$exe;Path=$install;ArtworkPath=''})}
            }catch{}
        }
    }
}

function Import-EAGames {
    param([System.Collections.ArrayList]$Target)
    foreach($root in @('HKLM:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Uninstall','HKLM:\\SOFTWARE\\WOW6432Node\\Microsoft\\Windows\\CurrentVersion\\Uninstall')){
        if( -not (Test-Path $root)){continue}
        foreach($key in Get-ChildItem $root -ErrorAction SilentlyContinue){
            try{
                $props=Get-ItemProperty $key.PSPath
                $publisher=[string]$props.Publisher
                if($publisher -notmatch 'Electronic Arts|EA Swiss|EA Games'){continue}
                $name=[string]$props.DisplayName;$install=[string]$props.InstallLocation;$icon=[string]$props.DisplayIcon
                if($icon){$icon=$icon.Trim('"');if($icon -match '^(.*?\\.exe)'){ $icon=$matches[1] }}
                $exe = if ($icon -and (Test-Path $icon)) { $icon } else { '' }
                if ( -not $exe -and $install -and (Test-Path $install)) { $candidate = Get-ChildItem $install -Filter '*.exe' -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -notmatch 'unins|setup|crash|report' } | Select-Object -First 1; if ($candidate) { $exe = $candidate.FullName } }
                if ($name -and $exe) {[void]$Target.Add([pscustomobject]@{Id="EA:$($key.PSChildName)";Name=$name;Source='EA';LaunchTarget=$exe;Path=$install;ArtworkPath=''})}
            }catch{}
        }
    }
    foreach($root in @(Get-ConfiguredRoots 'EA')){
        if( -not (Test-Path $root)){continue}
        foreach ($exe in (Get-ChildItem $root -Filter '*.exe' -File -Recurse -ErrorAction SilentlyContinue | Where-Object { $_.Name -notmatch 'unins|setup|crash|report|launcherhelper' } | Select-Object -First 250)) {
            [void]$Target.Add([pscustomobject]@{Id="EA:$($exe.FullName.ToLowerInvariant())";Name=$exe.BaseName;Source='EA';LaunchTarget=$exe.FullName;Path=$exe.DirectoryName;ArtworkPath=''})
        }
    }
}

function Import-XboxGames {
    param([System.Collections.ArrayList]$Target)
    $roots=New-Object System.Collections.ArrayList
    Add-UniquePath $roots "$env:SystemDrive\\XboxGames"
    foreach($root in @(Get-ConfiguredRoots 'Xbox')){Add-UniquePath $roots ([string]$root)}
    foreach($root in $roots){
        if( -not (Test-Path $root)){continue}
        foreach($config in Get-ChildItem $root -Filter 'MicrosoftGame.Config' -File -Recurse -ErrorAction SilentlyContinue){
            try{
                [xml]$xml=Get-Content -Raw $config.FullName
                $name='';try{$name=[string]$xml.Game.ShellVisuals.DefaultDisplayName}catch{};if ( -not $name) {$name=$config.Directory.Parent.Name}
                $helper=Join-Path $config.DirectoryName 'gamelaunchhelper.exe'
                $exe='';try{$exeName=[string]$xml.Game.Executable.Name;if($exeName){$exe=Join-Path $config.DirectoryName $exeName}}catch{}
                $targetPath = if (Test-Path $helper) { $helper } elseif ($exe -and (Test-Path $exe)) { $exe } else { '' }
                if($targetPath){[void]$Target.Add([pscustomobject]@{Id="Xbox:$($config.Directory.Parent.Name)";Name=$name;Source='Xbox';LaunchTarget=$targetPath;Path=$config.DirectoryName;ArtworkPath=''})}
            }catch{}
        }
    }
}

function Import-GenericRoots {
    param([System.Collections.ArrayList]$Target)
    foreach ($entry in @($script:Config.StorefrontRoots)) {
        $store=[string](Get-EntryProperty $entry 'Store'); if ($store -ne 'Generic') { continue }
        $root=[string](Get-EntryProperty $entry 'Path'); if ( -not (Test-Path $root)) { continue }
        foreach ($exe in (Get-ChildItem $root -Filter '*.exe' -File -Recurse -ErrorAction SilentlyContinue | Where-Object { $_.Name -notmatch 'unins|setup|crash|report|launcherhelper|unitycrash' } | Select-Object -First 250)) {
            $id="${store}:$($exe.FullName.ToLowerInvariant())"
            [void]$Target.Add([pscustomobject]@{Id=$id;Name=$exe.BaseName;Source=$store;LaunchTarget=$exe.FullName;Path=$exe.DirectoryName;ArtworkPath=''})
        }
    }
}

function New-DefaultLibraryState {
    [pscustomobject]@{
        Busy = $false
        Phase = 'Ready'
        Message = 'Choose Scan libraries to refresh installed games.'
        ImportedCount = @($script:Config.ImportedGames).Count
        Error = ''
        UpdatedAt = ''
    }
}

function Read-LibraryState {
    if ( -not (Test-Path $script:LibraryStatePath)) {
        if ($null -eq $script:LibraryState) { $script:LibraryState = New-DefaultLibraryState }
        return
    }
    try { $script:LibraryState = Get-Content -Raw -LiteralPath $script:LibraryStatePath | ConvertFrom-Json }
    catch { Write-Log "Library state read failed: $($_.Exception.Message)" 'WARN' }
}

function Apply-LibraryResult {
    if ( -not (Test-Path $script:LibraryResultPath)) { return }
    try {
        $signature = (Get-Item -LiteralPath $script:LibraryResultPath).LastWriteTimeUtc.Ticks.ToString()
        if ($signature -eq $script:LibraryResultSignature) { return }
        $script:LibraryResultSignature = $signature
        $result = Get-Content -Raw -LiteralPath $script:LibraryResultPath | ConvertFrom-Json
        $games = New-Object System.Collections.ArrayList
        foreach ($game in @($result.Games)) { if ($null -ne $game) { [void]$games.Add($game) } }
        $needsEpicProviderMigration = [int](Get-EntryProperty $script:Config 'LibrarySchemaVersion' 0) -lt 4
        $script:Config.ImportedGames = [object[]]$games.ToArray()
        $script:Config.LibraryScanCompleted = $true
        $script:Config.LibrarySchemaVersion = 4
        Save-Config
        Write-Log "Library scan imported $($games.Count) game(s)."
        try{Clear-HcGameDataCache -DropPersistent}catch{}
        # A completed explicit library rescan is one of the only events allowed to
        # refresh cover art. Normal startup/navigation/controller reconnects remain cache-only.
        try{Start-OnlineArtworkScan -ResetCursor -Force}catch{}
        if($needsEpicProviderMigration -and (Get-Command Start-GameProviderWorker -ErrorAction SilentlyContinue)){
            try{
                $epicNode=Get-ProviderCatalogNode 'Epic'
                if($null -ne $epicNode -and [bool](Get-EntryProperty $epicNode 'Authenticated' $false)){
                    Write-Log 'v0.25.2 migration: refreshing Epic provider catalog to purge Unreal Marketplace/assets from the persisted owned library.'
                    Start-GameProviderWorker 'Refresh' 'Epic'
                }
            }catch{Write-Log "Epic provider migration refresh could not start: $($_.Exception.Message)" 'WARN'}
        }
        if ($script:SelectedTab -in @(0,1,5)) { Render-Page }
    } catch { Write-Log "Library result apply failed: $($_.Exception.Message)" 'WARN' }
}


function Read-ArtworkState {
    if(-not (Test-Path -LiteralPath $script:ArtworkStatePath -PathType Leaf)){return $null}
    try{return Get-Content -Raw -LiteralPath $script:ArtworkStatePath|ConvertFrom-Json}catch{return $null}
}

function Start-OnlineArtworkScan {
    param([switch]$ResetCursor,[switch]$Force,[string]$Platform='')
    if(-not [bool]$script:Config.OnlineArtworkEnabled){return}
    if(-not (Test-Path -LiteralPath $script:ArtworkWorkerPath -PathType Leaf)){return}

    # Only one artwork process may own the cache/result files at a time. If a
    # different platform is selected while one is active, remember it and run
    # that platform next instead of loading artwork on the Platforms screen.
    try{
        if($script:ArtworkWorkerProcess -and -not $script:ArtworkWorkerProcess.HasExited){
            if($Platform -and -not [string]::Equals($Platform,$script:ArtworkScanPlatform,[StringComparison]::OrdinalIgnoreCase)){$script:PendingArtworkPlatform=$Platform}
            return
        }
    }catch{}

    # A hard exit or controller-triggered application crash can leave Busy=true
    # behind. Trust it only while its recorded worker PID is still alive.
    $state=Read-ArtworkState
    if($state -and [bool](Get-EntryProperty $state 'Busy' $false)){
        $workerAlive=$false
        try{
            $workerPid=[int](Get-EntryProperty $state 'WorkerPid' 0)
            if($workerPid -gt 0){$null=Get-Process -Id $workerPid -ErrorAction Stop;$workerAlive=$true}
        }catch{$workerAlive=$false}
        if($workerAlive){return}
        Write-Log 'Clearing stale artwork-worker state from a previous interrupted session.' 'WARN'
        Remove-Item -LiteralPath $script:ArtworkStatePath -Force -ErrorAction SilentlyContinue
    }

    if($ResetCursor){
        Remove-Item -LiteralPath $script:ArtworkResultPath -Force -ErrorAction SilentlyContinue
        $script:ArtworkResultSignature=''
    }elseif(-not $Force -and ((Get-Date)-$script:LastArtworkWorkerStartAt).TotalSeconds -lt 5){
        return
    }

    try{
        $powershell="$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
        $script:ArtworkScanPlatform=[string]$Platform
        $platformArg=if($Platform){' -Platform "'+($Platform -replace '"','')+'"'}else{''}
        $args='-NoLogo -NoProfile -ExecutionPolicy Bypass -File "'+$script:ArtworkWorkerPath+'" -ConfigPath "'+$script:ConfigPath+'" -ProviderCatalogPath "'+$script:ProviderCatalogPath+'" -CacheDir "'+$script:ArtworkCacheRoot+'" -StatePath "'+$script:ArtworkStatePath+'" -ResultPath "'+$script:ArtworkResultPath+'"'+$platformArg
        $script:ArtworkWorkerProcess=Start-Process -FilePath $powershell -ArgumentList $args -WindowStyle Hidden -PassThru
        $script:LastArtworkWorkerStartAt=Get-Date
        Write-Log $(if($Platform){"Online box-art worker started for $Platform."}else{'Online box-art worker started.'})
    }catch{Write-Log "Artwork worker start failed: $($_.Exception.Message)" 'WARN'}
}

function Apply-OnlineArtworkResult {
    if(-not (Test-Path -LiteralPath $script:ArtworkResultPath -PathType Leaf)){return}
    try{
        $signature=(Get-Item -LiteralPath $script:ArtworkResultPath).LastWriteTimeUtc.Ticks.ToString()
        if($signature -eq $script:ArtworkResultSignature){return}
        $script:ArtworkResultSignature=$signature
        $result=Get-Content -Raw -LiteralPath $script:ArtworkResultPath|ConvertFrom-Json
        $downloaded=[int](Get-EntryProperty $result 'Downloaded' 0)
        $hasMore=[bool](Get-EntryProperty $result 'HasMore' $false)
        $resultPlatform=[string](Get-EntryProperty $result 'Platform' '')
        $byId=@{};$providerItems=New-Object System.Collections.ArrayList
        foreach($item in @(Get-EntryProperty $result 'Items' @())){
            if($null -eq $item){continue}
            $id=[string](Get-EntryProperty $item 'Id' '')
            $art=[string](Get-EntryProperty $item 'ArtworkPath' '')
            $hero=[string](Get-EntryProperty $item 'HeroArtworkPath' '')
            if($id -and (($art -and (Test-Path -LiteralPath $art -PathType Leaf)) -or ($hero -and (Test-Path -LiteralPath $hero -PathType Leaf)))){$byId[$id]=$item}
            if([string](Get-EntryProperty $item 'Provider' '')){[void]$providerItems.Add($item)}
        }

        $configChanged=$false
        foreach($collectionName in @('ImportedGames','CustomGames','RecentGames')){
            foreach($entry in @($script:Config.$collectionName)){
                if($null -eq $entry){continue}
                $id=[string](Get-EntryProperty $entry 'Id' '')
                $item=$null
                if($id -and $byId.ContainsKey($id)){$item=$byId[$id]}
                if($null -eq $item){
                    $source=[string](Get-EntryProperty $entry 'Source' '')
                    $providerId=$id
                    if($source -and $providerId -and $providerId -notmatch '^[^:]+:'){$providerId=$source+':'+$providerId}
                    if($providerId -and $byId.ContainsKey($providerId)){$item=$byId[$providerId]}
                }
                if($null -eq $item){continue}
                $art=[string](Get-EntryProperty $item 'ArtworkPath' '')
                $hero=[string](Get-EntryProperty $item 'HeroArtworkPath' '')
                if($art -and (Test-Path -LiteralPath $art -PathType Leaf)){
                    if($entry.PSObject.Properties['ArtworkPath']){$entry.ArtworkPath=$art}else{$entry|Add-Member -NotePropertyName ArtworkPath -NotePropertyValue $art}
                    $configChanged=$true
                }
                if($hero -and (Test-Path -LiteralPath $hero -PathType Leaf)){
                    if($entry.PSObject.Properties['HeroArtworkPath']){$entry.HeroArtworkPath=$hero}else{$entry|Add-Member -NotePropertyName HeroArtworkPath -NotePropertyValue $hero}
                    $configChanged=$true
                }
            }
        }
        if($configChanged){Save-Config}

        $providerChanged=$false
        if($providerItems.Count -gt 0 -and (Test-Path -LiteralPath $script:ProviderCatalogPath -PathType Leaf)){
            $catalog=Read-GameProviderCatalog
            foreach($resultItem in @($providerItems)){
                $provider=[string](Get-EntryProperty $resultItem 'Provider' '')
                $gameId=[string](Get-EntryProperty $resultItem 'ProviderGameId' '')
                if(-not $gameId){$full=[string](Get-EntryProperty $resultItem 'Id' '');if($provider -and $full -match ('^(?i)'+[regex]::Escape($provider)+':(.+)$')){$gameId=$matches[1]}}
                if(-not $provider -or -not $gameId){continue}
                foreach($node in @(Get-EntryProperty $catalog 'Providers' @())){
                    if(-not [string]::Equals([string](Get-EntryProperty $node 'Id' ''),$provider,[StringComparison]::OrdinalIgnoreCase)){continue}
                    foreach($game in @(Get-EntryProperty $node 'Games' @())){
                        if(-not [string]::Equals([string](Get-EntryProperty $game 'Id' ''),$gameId,[StringComparison]::OrdinalIgnoreCase)){continue}
                        $art=[string](Get-EntryProperty $resultItem 'ArtworkPath' '')
                        $hero=[string](Get-EntryProperty $resultItem 'HeroArtworkPath' '')
                        if($art -and (Test-Path -LiteralPath $art -PathType Leaf)){if($game.PSObject.Properties['ArtworkPath']){$game.ArtworkPath=$art}else{$game|Add-Member -NotePropertyName ArtworkPath -NotePropertyValue $art};$providerChanged=$true}
                        if($hero -and (Test-Path -LiteralPath $hero -PathType Leaf)){if($game.PSObject.Properties['HeroArtworkPath']){$game.HeroArtworkPath=$hero}else{$game|Add-Member -NotePropertyName HeroArtworkPath -NotePropertyValue $hero};$providerChanged=$true}
                    }
                }
            }
            if($providerChanged){
                $tmp=$script:ProviderCatalogPath+'.artwork.tmp'
                ConvertTo-Json -InputObject $catalog -Depth 30|Set-Content -LiteralPath $tmp -Encoding UTF8
                Move-Item -LiteralPath $tmp -Destination $script:ProviderCatalogPath -Force
                $script:ProviderCatalog=$catalog
                try{$script:ProviderCatalogSignature=(Get-Item -LiteralPath $script:ProviderCatalogPath).LastWriteTimeUtc.Ticks.ToString()}catch{}
            }
        }

        if($configChanged -or $providerChanged){
            Write-Log "Applied $($byId.Count) online artwork result(s)."
            try{Clear-HcGameDataCache -DropPersistent}catch{}
            if($script:SelectedTab -in @(0,1) -and $script:SubPage -ne 'PlatformLibrary'){Render-Page}
        }
        if($hasMore -and [bool]$script:Config.OnlineArtworkEnabled){
            try{
                if($null -ne $script:ArtworkContinuationTimer){$script:ArtworkContinuationTimer.Stop()}
                $script:ArtworkContinuationTimer=New-Object System.Windows.Threading.DispatcherTimer
                $script:ArtworkContinuationTimer.Interval=[TimeSpan]::FromSeconds(1.5)
                $continuePlatform=$resultPlatform
                $continueHandler={try{$script:ArtworkContinuationTimer.Stop();Start-OnlineArtworkScan -Platform $continuePlatform}catch{}}.GetNewClosure()
                $script:ArtworkContinuationTimer.Add_Tick($continueHandler)
                $script:ArtworkContinuationTimer.Start()
            }catch{}
        }elseif($script:PendingArtworkPlatform){
            $pending=[string]$script:PendingArtworkPlatform
            $script:PendingArtworkPlatform=''
            Start-OnlineArtworkScan -ResetCursor -Platform $pending
        }
    }catch{Write-Log "Artwork result apply failed: $($_.Exception.Message)" 'WARN'}
}

function Start-LibraryScan {
    Read-LibraryState
    if ($script:LibraryState -and [bool]$script:LibraryState.Busy) { return }
    if ( -not (Test-Path $script:LibraryWorkerPath)) {
        Write-Log 'Library worker is missing.' 'ERROR'
        return
    }
    try {
        $state = [pscustomobject]@{ Busy=$true; Phase='Starting'; Message='Preparing storefront discovery.'; ImportedCount=@($script:Config.ImportedGames).Count; Error=''; UpdatedAt=(Get-Date).ToString('o') }
        $state | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $script:LibraryStatePath -Encoding UTF8
        $script:LibraryState = $state
        $powershell = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
        $arguments = '-NoLogo -NoProfile -ExecutionPolicy Bypass -File "' + $script:LibraryWorkerPath + '" -ConfigPath "' + $script:ConfigPath + '" -StatePath "' + $script:LibraryStatePath + '" -ResultPath "' + $script:LibraryResultPath + '"'
        Start-Process -FilePath $powershell -ArgumentList $arguments -WindowStyle Hidden | Out-Null
        Write-Log 'Background library scan started.'
        Render-Page
    } catch {
        Write-Log "Unable to start library scan: $($_.Exception.Message)" 'ERROR'
    }
}

function Scan-InstalledLibraries { Start-LibraryScan }

function Add-ToRecent {
    param([ValidateSet('Game','App')][string]$Kind, $Entry)
    $recent=New-Object System.Collections.ArrayList
    $source = if ($Kind -eq 'Game') { @($script:Config.RecentGames) } else { @($script:Config.RecentApps) }
    $name=[string](Get-EntryProperty $Entry 'Name')
    $target=[string](Get-EntryProperty $Entry 'LaunchTarget' (Get-EntryProperty $Entry 'Path'))
    $provider=[string](Get-EntryProperty $Entry 'Provider' '')
    $providerGameId=[string](Get-EntryProperty $Entry 'ProviderGameId' (Get-EntryProperty $Entry 'Id' ''))
    $uniqueKey=if($provider -and $providerGameId){"provider:${provider}:${providerGameId}"}else{$target}
    foreach ($old in $source) {
        $oldProvider=[string](Get-EntryProperty $old 'Provider' '')
        $oldProviderGameId=[string](Get-EntryProperty $old 'ProviderGameId' (Get-EntryProperty $old 'Id' ''))
        $oldKey=if($oldProvider -and $oldProviderGameId){"provider:${oldProvider}:${oldProviderGameId}"}else{[string](Get-EntryProperty $old 'LaunchTarget' (Get-EntryProperty $old 'Path'))}
        if ( -not ([string]::Equals($oldKey,$uniqueKey,[StringComparison]::OrdinalIgnoreCase))) { [void]$recent.Add($old) }
    }
    $new=[pscustomobject]@{
        Id=[string](Get-EntryProperty $Entry 'Id' $providerGameId);Name=$name; LaunchTarget=$target; Arguments=@(Get-EntryProperty $Entry 'Arguments' @());
        Source=[string](Get-EntryProperty $Entry 'Source' $(if($Kind -eq 'Game'){'Custom'}else{'App'}));
        Provider=$provider;ProviderGameId=$providerGameId;InstallPath=[string](Get-EntryProperty $Entry 'InstallPath' '');
        ArtworkPath=[string](Get-EntryProperty $Entry 'ArtworkPath'); LastLaunched=(Get-Date).ToString('o'); Kind=$Kind
    }
    $buffer=New-Object System.Collections.ArrayList; [void]$buffer.Add($new)
    foreach ($old in $recent) { if ($buffer.Count -ge 16) { break }; [void]$buffer.Add($old) }
    if ($Kind -eq 'Game') { $script:Config.RecentGames=[object[]]$buffer.ToArray() } else { $script:Config.RecentApps=[object[]]$buffer.ToArray() }
    Save-Config
}

function Start-RecentEntry {
    param($Entry)
    $target=[string](Get-EntryProperty $Entry 'LaunchTarget' (Get-EntryProperty $Entry 'Path'))
    if ( -not $target) { return }
    if (Test-Path $target) { Start-ExternalProcess $target @(Get-EntryProperty $Entry 'Arguments' @()) }
    elseif ($target -match '^[a-zA-Z][a-zA-Z0-9+.-]*:') { Start-UriOrShellTarget $target }
    else { Set-ConsoleNotice 'This recent item is no longer available.' 'WARN' }
}

function Get-PromptFamily {
    if ($script:Config.PromptOverride -and $script:Config.PromptOverride -ne 'Auto') {
        return [string]$script:Config.PromptOverride
    }
    return $script:LastPromptFamily
}

function New-PromptLabel {
    param([string]$Text)
    $label = New-Object System.Windows.Controls.TextBlock
    $label.Text = $Text
    $label.FontSize = 14
    $label.Foreground = '#D7DFEA'
    $label.VerticalAlignment = 'Center'
    $label.MinHeight = 22
    $label.Padding = '0,1,0,3'
    $label.Margin = '7,0,18,0'
    return $label
}

function New-KeycapPrompt {
    param([string]$Text, [double]$MinWidth = 34)
    $border = New-Object System.Windows.Controls.Border
    $border.MinWidth = $MinWidth
    $border.Height = 27
    $border.CornerRadius = 6
    $border.BorderThickness = 1
    $border.BorderBrush = '#718096'
    $border.Background = '#141E2D'
    $border.Padding = '8,1,8,1'
    $border.Margin = '0,0,0,0'
    $textBlock = New-Object System.Windows.Controls.TextBlock
    $textBlock.Text = $Text
    $textBlock.FontSize = 11
    $textBlock.FontWeight = 'SemiBold'
    $textBlock.Foreground = '#F5F7FB'
    $textBlock.HorizontalAlignment = 'Center'
    $textBlock.VerticalAlignment = 'Center'
    $textBlock.Padding = '0,0,0,2'
    $border.Child = $textBlock
    return $border
}

function New-LetterPrompt {
    param([string]$Letter, [string]$Fill, [string]$Foreground = '#08101D')
    $grid = New-Object System.Windows.Controls.Grid
    $grid.Width = 27
    $grid.Height = 27
    $ellipse = New-Object System.Windows.Shapes.Ellipse
    $ellipse.Fill = $Fill
    $ellipse.Stroke = '#E9EEF6'
    $ellipse.StrokeThickness = 1
    $grid.Children.Add($ellipse) | Out-Null
    $text = New-Object System.Windows.Controls.TextBlock
    $text.Text = $Letter
    $text.FontSize = 13
    $text.FontWeight = 'Bold'
    $text.Foreground = $Foreground
    $text.HorizontalAlignment = 'Center'
    $text.VerticalAlignment = 'Center'
    $text.Padding = '0,0,0,2'
    $grid.Children.Add($text) | Out-Null
    return $grid
}

function New-PlayStationPrompt {
    param([ValidateSet('Cross','Circle','Triangle','Square','Options')] [string]$Shape)
    if ($Shape -eq 'Options') { return New-KeycapPrompt 'OPTIONS' 62 }

    $grid = New-Object System.Windows.Controls.Grid
    $grid.Width = 28
    $grid.Height = 28
    $canvas = New-Object System.Windows.Controls.Canvas
    $canvas.Width = 28
    $canvas.Height = 28
    $grid.Children.Add($canvas) | Out-Null

    switch ($Shape) {
        'Cross' {
            foreach ($geometry in @('M 6,6 L 22,22','M 22,6 L 6,22')) {
                $path = New-Object System.Windows.Shapes.Path
                $path.Data = [System.Windows.Media.Geometry]::Parse($geometry)
                $path.Stroke = '#67B7E1'
                $path.StrokeThickness = 2.6
                $path.StrokeStartLineCap = 'Round'
                $path.StrokeEndLineCap = 'Round'
                $canvas.Children.Add($path) | Out-Null
            }
        }
        'Circle' {
            $ellipse = New-Object System.Windows.Shapes.Ellipse
            $ellipse.Width = 18
            $ellipse.Height = 18
            $ellipse.Stroke = '#F26D7D'
            $ellipse.StrokeThickness = 2.4
            [System.Windows.Controls.Canvas]::SetLeft($ellipse,5)
            [System.Windows.Controls.Canvas]::SetTop($ellipse,5)
            $canvas.Children.Add($ellipse) | Out-Null
        }
        'Triangle' {
            $path = New-Object System.Windows.Shapes.Path
            $path.Data = [System.Windows.Media.Geometry]::Parse('M 14,4 L 24,22 L 4,22 Z')
            $path.Stroke = '#62D5A4'
            $path.Fill = [System.Windows.Media.Brushes]::Transparent
            $path.StrokeThickness = 2.2
            $path.StrokeLineJoin = 'Round'
            $canvas.Children.Add($path) | Out-Null
        }
        'Square' {
            $rect = New-Object System.Windows.Shapes.Rectangle
            $rect.Width = 17
            $rect.Height = 17
            $rect.Stroke = '#D58AD8'
            $rect.StrokeThickness = 2.2
            [System.Windows.Controls.Canvas]::SetLeft($rect,5.5)
            [System.Windows.Controls.Canvas]::SetTop($rect,5.5)
            $canvas.Children.Add($rect) | Out-Null
        }
    }
    return $grid
}

function Add-PromptPair {
    param($Icon, [string]$Text)
    if ($null -eq $script:PromptPanel) { return }
    $script:PromptPanel.Children.Add($Icon) | Out-Null
    $script:PromptPanel.Children.Add((New-PromptLabel $Text)) | Out-Null
}

function Render-PromptFooter {
    if ($null -eq $script:PromptPanel) { return }
    $script:PromptPanel.Children.Clear()
    $family = Get-PromptFamily
    $secondary=''
    try{$secondary=[string](Get-StorefrontSecondaryLabel)}catch{}
    if($secondary -notin @('Manage','Install')){$secondary=''}
    switch ($family) {
        'PlayStation' {
            Add-PromptPair (New-PlayStationPrompt 'Cross') 'Select'
            Add-PromptPair (New-PlayStationPrompt 'Circle') 'Back'
            if($secondary){Add-PromptPair (New-PlayStationPrompt 'Square') $secondary}
            Add-PromptPair (New-KeycapPrompt 'PS' 34) 'Quick Access'
            Add-PromptPair (New-PlayStationPrompt 'Options') 'Power'
        }
        'Nintendo' {
            Add-PromptPair (New-LetterPrompt 'A' '#F4F6FA') 'Select'
            Add-PromptPair (New-LetterPrompt 'B' '#F4F6FA') 'Back'
            if($secondary){Add-PromptPair (New-LetterPrompt 'X' '#F4F6FA') $secondary}
            Add-PromptPair (New-KeycapPrompt 'HOME' 48) 'Quick Access'
            Add-PromptPair (New-KeycapPrompt '+') 'Power'
        }
        'Steam' {
            Add-PromptPair (New-LetterPrompt 'A' '#7ECF75') 'Select'
            Add-PromptPair (New-LetterPrompt 'B' '#E66B6B') 'Back'
            if($secondary){Add-PromptPair (New-LetterPrompt 'X' '#65AEE8') $secondary}
            Add-PromptPair (New-KeycapPrompt 'STEAM' 52) 'Quick Access'
        }
        'Xbox' {
            Add-PromptPair (New-LetterPrompt 'A' '#73C86B') 'Select'
            Add-PromptPair (New-LetterPrompt 'B' '#E56565') 'Back'
            if($secondary){Add-PromptPair (New-LetterPrompt 'X' '#65AEE8') $secondary}
            Add-PromptPair (New-KeycapPrompt 'XBOX' 48) 'Quick Access'
            Add-PromptPair (New-KeycapPrompt 'MENU' 48) 'Power'
        }
        default {
            Add-PromptPair (New-KeycapPrompt 'ENTER' 54) 'Select'
            Add-PromptPair (New-KeycapPrompt 'ESC' 42) 'Back'
            Add-PromptPair (New-KeycapPrompt 'F10' 42) 'Windowed'
        }
    }
}

function Test-IsMouseLikeControllerName {
    param([string]$Name)
    if ([string]::IsNullOrWhiteSpace($Name)) { return $false }
    $normalized = $Name.ToLowerInvariant()
    return ($normalized -match 'swiftpoint|\bz2\b|mouse|trackball|touchpad|trackpad|spacemouse|3dconnexion|pointing device')
}

function Get-FamilyFromRawController {
    param($Raw)
    if ($null -eq $Raw) { return 'Xbox' }
    $name = ''
    $vid = 0
    try { $name = ([string]$Raw.DisplayName).ToLowerInvariant() } catch { }
    try { $vid = [int]$Raw.HardwareVendorId } catch { }

    if ($vid -eq 0x054C -or $name -match 'dualsense|dualshock|playstation|sony interactive|wireless controller') { return 'PlayStation' }
    if ($vid -eq 0x057E -or $name -match 'nintendo|switch pro|joy-con|pro controller') { return 'Nintendo' }
    if ($vid -eq 0x28DE -or $name -match 'steam controller|steam deck|valve') { return 'Steam' }
    if ($vid -eq 0x045E -or $name -match 'xbox|xinput|microsoft') { return 'Xbox' }
    return 'Xbox'
}

function Get-ControllerSnapshot {
    $snapshot = [pscustomobject]@{
        Gamepads = @()
        Raw = @()
        Hid = @()
        Legacy = @()
        HidDiagnostics = ''
    }
    try {
        $snapshot.Gamepads = Convert-ToStableArray ([Windows.Gaming.Input.Gamepad,Windows.Gaming.Input,ContentType=WindowsRuntime]::Gamepads)
        $script:GamepadApiAvailable = $true
    } catch {
        $script:GamepadApiAvailable = $false
    }
    try {
        $snapshot.Raw = Convert-ToStableArray ([Windows.Gaming.Input.RawGameController,Windows.Gaming.Input,ContentType=WindowsRuntime]::RawGameControllers)
        $script:RawGamepadApiAvailable = $true
    } catch {
        $script:RawGamepadApiAvailable = $false
    }
    try {
        if ('HuymaierConsole.Native.RawHidController' -as [type]) {
            $snapshot.Hid = Convert-ToStableArray ([HuymaierConsole.Native.RawHidController]::GetSnapshots())
            $snapshot.HidDiagnostics = [HuymaierConsole.Native.RawHidController]::GetDiagnostics()
            $script:RawHidGamepadApiAvailable = [HuymaierConsole.Native.RawHidController]::IsRegistered()
        }
    } catch {
        $script:RawHidGamepadApiAvailable = $false
    }
    try {
        if ('HuymaierConsole.Native.LegacyJoystick' -as [type]) {
            $snapshot.Legacy = Convert-ToStableArray ([HuymaierConsole.Native.LegacyJoystick]::GetSnapshots())
            $script:LegacyGamepadApiAvailable = $true
        }
    } catch {
        $script:LegacyGamepadApiAvailable = $false
    }
    return $snapshot
}

function Get-FamilyFromLegacyController {
    param($Controller)
    $name=''
    try{$name=([string]$Controller.Name).ToLowerInvariant()}catch{}
    if($name -match 'dualsense|dualshock|wireless controller|playstation|sony'){return 'PlayStation'}
    if($name -match 'nintendo|switch|joy-con'){return 'Nintendo'}
    if($name -match 'steam|valve'){return 'Steam'}
    return 'Xbox'
}

function Get-LegacyControllerVirtualState {
    param($Controller)
    $result=[pscustomobject]@{Mask=0;Direction='';Activity=$false;Eligible=$true}
    if($null -eq $Controller){return $result}
    try{
        $name='';try{$name=[string]$Controller.Name}catch{}
        if(Test-IsMouseLikeControllerName $name){$result.Eligible=$false;return $result}

        $buttons=[uint32]$Controller.Buttons
        $family=Get-FamilyFromLegacyController $Controller
        if($buttons -ne 0){$result.Activity=$true}
        if($family -eq 'PlayStation'){
            if(($buttons -band (1 -shl 1)) -ne 0){$result.Mask=$result.Mask -bor 4}
            if(($buttons -band (1 -shl 0)) -ne 0){$result.Mask=$result.Mask -bor 16}
            if(($buttons -band (1 -shl 2)) -ne 0){$result.Mask=$result.Mask -bor 8}
            if(($buttons -band (1 -shl 3)) -ne 0){$result.Mask=$result.Mask -bor 32}
            if(($buttons -band (1 -shl 9)) -ne 0){$result.Mask=$result.Mask -bor 1}
            if(($buttons -band (1 -shl 12)) -ne 0){$result.Mask=$result.Mask -bor 2}
            if(($buttons -band (1 -shl 4)) -ne 0){$result.Mask=$result.Mask -bor 1024}
            if(($buttons -band (1 -shl 5)) -ne 0){$result.Mask=$result.Mask -bor 2048}
        }elseif($family -eq 'Nintendo'){
            if(($buttons -band 1) -ne 0){$result.Mask=$result.Mask -bor 8}
            if(($buttons -band 2) -ne 0){$result.Mask=$result.Mask -bor 4}
            if(($buttons -band (1 -shl 3)) -ne 0){$result.Mask=$result.Mask -bor 16}
            if(($buttons -band (1 -shl 2)) -ne 0){$result.Mask=$result.Mask -bor 32}
            if(($buttons -band (1 -shl 9)) -ne 0){$result.Mask=$result.Mask -bor 1}
            if(($buttons -band (1 -shl 4)) -ne 0){$result.Mask=$result.Mask -bor 1024}
            if(($buttons -band (1 -shl 5)) -ne 0){$result.Mask=$result.Mask -bor 2048}
        }else{
            if(($buttons -band 1) -ne 0){$result.Mask=$result.Mask -bor 4}
            if(($buttons -band 2) -ne 0){$result.Mask=$result.Mask -bor 8}
            if(($buttons -band (1 -shl 2)) -ne 0){$result.Mask=$result.Mask -bor 16}
            if(($buttons -band (1 -shl 3)) -ne 0){$result.Mask=$result.Mask -bor 32}
            if(($buttons -band (1 -shl 7)) -ne 0){$result.Mask=$result.Mask -bor 1}
            if(($buttons -band (1 -shl 4)) -ne 0){$result.Mask=$result.Mask -bor 1024}
            if(($buttons -band (1 -shl 5)) -ne 0){$result.Mask=$result.Mask -bor 2048}
        }

        $pov=[uint32]$Controller.Pov
        $hasPov=($pov -ne 65535 -and $pov -ne 4294967295)
        if($hasPov){
            $result.Activity=$true
            if($pov -ge 31500 -or $pov -le 4500){$result.Direction='Up'}
            elseif($pov -gt 4500 -and $pov -lt 13500){$result.Direction='Right'}
            elseif($pov -ge 13500 -and $pov -le 22500){$result.Direction='Down'}
            elseif($pov -gt 22500 -and $pov -lt 31500){$result.Direction='Left'}
        }

        if(-not $result.Direction){
            $x=[double]$Controller.X;$y=[double]$Controller.Y
            $id='';try{$id=[string]$Controller.Id}catch{}
            $key="$id|$name"
            if(-not $script:LegacyControllerCenters.ContainsKey($key)){
                $script:LegacyControllerCenters[$key]=[pscustomobject]@{X=$x;Y=$y}
                $script:LegacyControllerNeutralCounts[$key]=0
            }
            $center=$script:LegacyControllerCenters[$key]
            $dx=$x-[double]$center.X;$dy=$y-[double]$center.Y
            $nearNeutral=([math]::Abs($dx) -lt 4500 -and [math]::Abs($dy) -lt 4500 -and $buttons -eq 0 -and -not $hasPov)
            if($nearNeutral){
                $script:LegacyControllerNeutralCounts[$key]=[math]::Min(8,([int]$script:LegacyControllerNeutralCounts[$key]+1))
                # Slowly track harmless center drift without following intentional movement.
                $center.X=([double]$center.X*0.96)+($x*0.04);$center.Y=([double]$center.Y*0.96)+($y*0.04)
            }
            $armed=([int]$script:LegacyControllerNeutralCounts[$key] -ge 3)
            if($armed){
                if($dx -lt -12000){$result.Direction='Left'}
                elseif($dx -gt 12000){$result.Direction='Right'}
                elseif($dy -lt -12000){$result.Direction='Up'}
                elseif($dy -gt 12000){$result.Direction='Down'}
                if($result.Direction){$result.Activity=$true}
            }
        }
    }catch{}
    return $result
}

function Set-ActiveInputFamily {
    param([string]$Family, [string]$ControllerName)
    if ([string]::IsNullOrWhiteSpace($Family)) { $Family = 'Xbox' }
    if ([string]::IsNullOrWhiteSpace($ControllerName)) { $ControllerName = "$Family controller" }
    # Device names supplied by HID drivers can contain NUL/control characters.
    # Sanitise them before passing the string into WPF text elements.
    $ControllerName=([regex]::Replace($ControllerName,'[\x00-\x1F\x7F]',' ')).Trim()
    if($ControllerName.Length -gt 96){$ControllerName=$ControllerName.Substring(0,96)}
    $changed = ($script:LastPromptFamily -ne $Family) -or ($script:ConnectedControllerName -ne $ControllerName)
    $script:LastPromptFamily = $Family
    $script:ConnectedControllerName = $ControllerName
    if ($changed) { try{Update-Footer}catch{} }
}

function Set-KeyboardActive {
    $script:LastKeyboardInputAt = Get-Date
    if ($script:Config.PromptOverride -eq 'Auto') {
        Set-ActiveInputFamily 'Keyboard' 'Keyboard / Mouse'
    }
}

function Test-ConsoleHasInputFocus {
    try { return ($null -ne $script:Window -and [bool]$script:Window.IsActive) } catch { return $false }
}

function Hide-ConsoleCursor {
    if($script:ControllerCursorHidden){return}
    try{
        $script:IgnoreMouseMoveUntil=(Get-Date).AddMilliseconds(450)
        $script:LastPhysicalMouseAt=[datetime]::MinValue
        if('HuymaierConsole.Native.NativeCursorRouter' -as [type]){
            [HuymaierConsole.Native.NativeCursorRouter]::ParkTopRight()
            $script:ControllerParkedCursorPosition=[HuymaierConsole.Native.NativeCursorRouter]::GetCursorPosition()
            $script:LastPhysicalCursorPosition=$script:ControllerParkedCursorPosition
        }
        [System.Windows.Input.Mouse]::OverrideCursor=[System.Windows.Input.Cursors]::None
        $script:ControllerCursorHidden=$true
    }catch{}
}

function Show-ConsoleCursor {
    if(-not $script:ControllerCursorHidden){return}
    try{
        [System.Windows.Input.Mouse]::OverrideCursor=$null
        $script:ControllerCursorHidden=$false
        $script:ControllerParkedCursorPosition=[long]0
    }catch{}
}

# Mouse hover must never steal selection merely because controller scrolling moved
# a WPF element underneath a stationary cursor.  Only a physically moved/clicked
# mouse may reactivate hover navigation after controller input has hidden the cursor.
function Test-HcMouseHoverAllowed {
    if(-not $script:ControllerCursorHidden){return $true}
    try{
        if('HuymaierConsole.Native.NativeCursorRouter' -as [type]){
            $position=[HuymaierConsole.Native.NativeCursorRouter]::GetCursorPosition()
            if($position -ne [long]$script:ControllerParkedCursorPosition -and [HuymaierConsole.Native.NativeCursorRouter]::MovedFrom([long]$script:ControllerParkedCursorPosition,3)){
                $script:LastPhysicalCursorPosition=$position
                $script:LastPhysicalMouseAt=Get-Date
                Show-ConsoleCursor
                Set-KeyboardActive
                return $true
            }
        }
    }catch{}
    return $false
}

function Send-ConsoleToBackground {
    param([int]$CloseGuardSeconds=12)
    $script:PreventAutoCloseUntil=(Get-Date).AddSeconds([math]::Max(2,$CloseGuardSeconds))
    $script:LastGamepadMask=0
    $script:LastDirection=''
    $script:NextDirectionAt=[datetime]::MinValue
    try{$script:Window.Topmost=$false}catch{}
}

function Set-FpsCounterState {
    try{
        $enabled=[bool]$script:Config.ShowFpsCounter
        if($null -ne $script:FpsText){$script:FpsText.Visibility=$(if($enabled){'Visible'}else{'Collapsed'})}
        if('HuymaierConsole.Native.FrameRateMonitor' -as [type]){
            if($enabled -and -not $script:FpsMonitorStarted){[HuymaierConsole.Native.FrameRateMonitor]::Start();$script:FpsMonitorStarted=$true}
            elseif(-not $enabled -and $script:FpsMonitorStarted){[HuymaierConsole.Native.FrameRateMonitor]::Stop();$script:FpsMonitorStarted=$false}
        }
    }catch{Write-Log "FPS monitor state failed: $($_.Exception.Message)" 'WARN'}
}

function Toggle-FpsCounter {
    $script:Config.ShowFpsCounter=-not [bool]$script:Config.ShowFpsCounter
    Save-Config
    Set-FpsCounterState
    Render-Page
}

function Get-PlatformTheme {
    param([string]$Platform)
    $key=([string]$Platform).ToLowerInvariant()
    switch -Regex($key){
        '^steam$' { return [pscustomobject]@{Base1='#071A2B';Base2='#123C61';Accent1='#66C0F4';Accent2='#1B91D0';Brand='STEAM';Motif='GAMEPAD NETWORK'} }
        '^gog$' { return [pscustomobject]@{Base1='#170B2A';Base2='#4D176A';Accent1='#D68BFF';Accent2='#7D3FBE';Brand='GOG';Motif='DRM-FREE LIBRARY'} }
        '^epic$' { return [pscustomobject]@{Base1='#090B0E';Base2='#30343A';Accent1='#F4F4F4';Accent2='#5A8CFF';Brand='EPIC';Motif='EPIC GAMES'} }
        '^xbox$' { return [pscustomobject]@{Base1='#06150A';Base2='#0E4A22';Accent1='#72D54A';Accent2='#107C10';Brand='XBOX';Motif='XBOX LIBRARY'} }
        '^ps5$' { return [pscustomobject]@{Base1='#F5F7FC';Base2='#10141B';Accent1='#1677FF';Accent2='#B9D8FF';Brand='PLAYSTATION 5';Motif='FUTURE FLOW'} }
        '^ps4$' { return [pscustomobject]@{Base1='#020A2A';Base2='#0649A9';Accent1='#4DB9FF';Accent2='#145FCC';Brand='PLAYSTATION 4';Motif='BLUE HORIZON'} }
        '^ps3$' { return [pscustomobject]@{Base1='#01030A';Base2='#103A69';Accent1='#73D9FF';Accent2='#204E94';Brand='PLAYSTATION 3';Motif='XMB WAVE'} }
        '^ps2$' { return [pscustomobject]@{Base1='#02030A';Base2='#101C55';Accent1='#496CFF';Accent2='#1634A6';Brand='PLAYSTATION 2';Motif='DIGITAL TOWERS'} }
        '^ps1$|^playstation$' { return [pscustomobject]@{Base1='#171A20';Base2='#5A6070';Accent1='#D8DEE8';Accent2='#2B70D6';Brand='PLAYSTATION';Motif='CLASSIC ORBIT'} }
        '^psp$' { return [pscustomobject]@{Base1='#080A12';Base2='#1B4970';Accent1='#67D8FF';Accent2='#5E8CB8';Brand='PSP';Motif='PORTABLE WAVE'} }
        '^switch$|^nintendo' { return [pscustomobject]@{Base1='#2A0508';Base2='#E60012';Accent1='#FFFFFF';Accent2='#FF6A73';Brand='NINTENDO';Motif='PLAY TOGETHER'} }
        '^wii u$|^wii$' { return [pscustomobject]@{Base1='#071C26';Base2='#1A95B8';Accent1='#E9FBFF';Accent2='#50CBE8';Brand='WII';Motif='MOTION FLOW'} }
        '^gamecube$' { return [pscustomobject]@{Base1='#100A27';Base2='#4A32A8';Accent1='#B7A5FF';Accent2='#6751D6';Brand='GAMECUBE';Motif='CUBIC SPACE'} }
        '^dreamcast$' { return [pscustomobject]@{Base1='#17100A';Base2='#6B2B08';Accent1='#FF8A22';Accent2='#D64A00';Brand='DREAMCAST';Motif='SPIRAL ENERGY'} }
        '^amazon$' { return [pscustomobject]@{Base1='#061725';Base2='#173E5B';Accent1='#FFB347';Accent2='#27B9E8';Brand='AMAZON GAMES';Motif='PRIME LIBRARY'} }
        default { return [pscustomobject]@{Base1='#07101D';Base2='#263A5C';Accent1='#E7C45E';Accent2='#4F79AE';Brand=([string]$Platform).ToUpperInvariant();Motif='HUYMAIER PLATFORM'} }
    }
}

function Set-PlatformBackground {
    param([bool]$Active)
    if($null -eq $script:PlatformBackdrop){return}
    $show=$Active -and [bool]$script:Config.PlatformBackgroundsEnabled
    $script:PlatformBackdrop.Visibility=$(if($show){'Visible'}else{'Collapsed'})
    if($null -ne $script:DynamicBackdrop){$script:DynamicBackdrop.Opacity=$(if($show){0.12}else{0.96})}
    if(-not $show){Stop-PlatformBackgroundAnimations;return}
    Start-PlatformBackgroundAnimations
    $theme=Get-PlatformTheme $script:SelectedGamePlatform
    try{
        $brush=New-Object System.Windows.Media.LinearGradientBrush
        $brush.StartPoint='0,0';$brush.EndPoint='1,1'
        $brush.GradientStops.Add((New-Object System.Windows.Media.GradientStop -ArgumentList ([System.Windows.Media.ColorConverter]::ConvertFromString($theme.Base1)),0.0))
        $brush.GradientStops.Add((New-Object System.Windows.Media.GradientStop -ArgumentList ([System.Windows.Media.ColorConverter]::ConvertFromString($theme.Base2)),1.0))
        $script:PlatformBase.Fill=$brush
        $script:PlatformGlowOne.Fill=(New-Object System.Windows.Media.SolidColorBrush -ArgumentList ([System.Windows.Media.ColorConverter]::ConvertFromString($theme.Accent1)))
        $script:PlatformGlowTwo.Fill=(New-Object System.Windows.Media.SolidColorBrush -ArgumentList ([System.Windows.Media.ColorConverter]::ConvertFromString($theme.Accent2)))
        $script:PlatformWaveOne.Stroke=(New-Object System.Windows.Media.SolidColorBrush -ArgumentList ([System.Windows.Media.ColorConverter]::ConvertFromString($theme.Accent1)))
        $script:PlatformWaveTwo.Stroke=(New-Object System.Windows.Media.SolidColorBrush -ArgumentList ([System.Windows.Media.ColorConverter]::ConvertFromString($theme.Accent2)))
        $script:PlatformRing.Stroke=(New-Object System.Windows.Media.SolidColorBrush -ArgumentList ([System.Windows.Media.ColorConverter]::ConvertFromString($theme.Accent1)))
        $script:PlatformBrandText.Text=$theme.Brand
        $script:PlatformMotifText.Text=$theme.Motif
        if($null -ne $script:PlatformPlayStationGlyphs){
            $psPlatform = ([string]$script:SelectedGamePlatform) -match '^(?i)(ps|playstation)'
            $script:PlatformPlayStationGlyphs.Visibility = $(if($psPlatform){'Visible'}else{'Collapsed'})
        }
    }catch{}
}

function Start-PlatformBackgroundAnimations {
    if($null -eq $script:PlatformBackdrop -or $script:PlatformAnimationsRunning){return}
    Start-ElementAnimation $script:PlatformGlowOneTransform ([System.Windows.Media.TranslateTransform]::XProperty) -170 220 19 $true
    Start-ElementAnimation $script:PlatformGlowOneTransform ([System.Windows.Media.TranslateTransform]::YProperty) -80 130 23 $true
    Start-ElementAnimation $script:PlatformGlowTwoTransform ([System.Windows.Media.TranslateTransform]::XProperty) 210 -190 27 $true
    Start-ElementAnimation $script:PlatformGlowTwoTransform ([System.Windows.Media.TranslateTransform]::YProperty) 120 -130 21 $true
    Start-ElementAnimation $script:PlatformWaveOneTransform ([System.Windows.Media.TranslateTransform]::XProperty) -190 210 22 $true
    Start-ElementAnimation $script:PlatformWaveTwoTransform ([System.Windows.Media.TranslateTransform]::XProperty) 180 -220 29 $true
    Start-ElementAnimation $script:PlatformRingTransform ([System.Windows.Media.RotateTransform]::AngleProperty) 0 360 70 $false
    $script:PlatformAnimationsRunning=$true
}

function Stop-PlatformBackgroundAnimations {
    if(-not $script:PlatformAnimationsRunning){return}
    try{
        $script:PlatformGlowOneTransform.BeginAnimation([System.Windows.Media.TranslateTransform]::XProperty,$null)
        $script:PlatformGlowOneTransform.BeginAnimation([System.Windows.Media.TranslateTransform]::YProperty,$null)
        $script:PlatformGlowTwoTransform.BeginAnimation([System.Windows.Media.TranslateTransform]::XProperty,$null)
        $script:PlatformGlowTwoTransform.BeginAnimation([System.Windows.Media.TranslateTransform]::YProperty,$null)
        $script:PlatformWaveOneTransform.BeginAnimation([System.Windows.Media.TranslateTransform]::XProperty,$null)
        $script:PlatformWaveTwoTransform.BeginAnimation([System.Windows.Media.TranslateTransform]::XProperty,$null)
        $script:PlatformRingTransform.BeginAnimation([System.Windows.Media.RotateTransform]::AngleProperty,$null)
    }catch{}
    $script:PlatformAnimationsRunning=$false
}

function Get-BrowserArguments {
    param([string]$Path, [string]$Mode)
    $leaf = [IO.Path]::GetFileName($Path).ToLowerInvariant()
    if ($Mode -eq 'Normal') { return @() }

    $isPrivate = ($Mode -eq 'Private Fullscreen')
    if ($leaf -eq 'msedge.exe') {
        if ($isPrivate) { return @('--inprivate','--start-fullscreen') }
        return @('--start-fullscreen')
    }
    if ($leaf -in @('chrome.exe','brave.exe','vivaldi.exe','launcher.exe','opera.exe')) {
        if ($isPrivate) { return @('--incognito','--start-fullscreen') }
        return @('--start-fullscreen')
    }
    if ($leaf -eq 'firefox.exe') {
        if ($isPrivate) { return @('-private-window') }
        return @('-kiosk')
    }
    return @()
}

function Start-ExternalProcess {
    param([string]$Path, [string[]]$Arguments = @(), [string]$WorkingDirectory = '', [switch]$KeepConsoleForeground)
    try {
        if ( -not $WorkingDirectory) { $WorkingDirectory = Split-Path -Parent $Path }
        $startParams = @{ FilePath = $Path; WorkingDirectory = $WorkingDirectory; PassThru = $true }
        if ($Arguments -and $Arguments.Count -gt 0 -and -not ([string]::IsNullOrWhiteSpace(($Arguments -join '')))) {
            $startParams.ArgumentList = $Arguments
        }
        $process=Start-Process @startParams
        if(-not $KeepConsoleForeground){Send-ConsoleToBackground}
        Write-Log "Launched: $Path $($Arguments -join ' ')"
        return $process
    } catch {
        Set-ConsoleNotice "Unable to launch ${Path}: $($_.Exception.Message)" 'ERROR'
        Write-Log "Launch failed: $Path :: $($_.Exception.Message)" 'ERROR'
        return $null
    }
}

function Start-UriOrShellTarget {
    param([string]$Target)
    try {
        Start-Process $Target | Out-Null
        Send-ConsoleToBackground
    } catch {
        Set-ConsoleNotice "Unable to open ${Target}: $($_.Exception.Message)" 'ERROR'
    }
}

function Set-StartWithWindows {
    param([bool]$Enable)
    $runKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
    $launcher = Join-Path $script:BaseDir 'HuymaierConsole.exe'
    if(-not (Test-Path -LiteralPath $launcher)){$launcher=Join-Path $script:BaseDir 'Launch-HuymaierConsole.cmd'}
    try {
        if ($Enable) {
            New-Item -Path $runKey -Force | Out-Null
            Set-ItemProperty -Path $runKey -Name 'HuymaierConsole' -Value ('"' + $launcher + '"')
        } else {
            Remove-ItemProperty -Path $runKey -Name 'HuymaierConsole' -ErrorAction SilentlyContinue
        }
        $script:Config.StartWithWindows = $Enable
        Save-Config
    } catch {
        Set-ConsoleNotice "Could not change startup behavior: $($_.Exception.Message)" 'ERROR'
    }
}

function Add-CustomEntry {
    param([ValidateSet('Game','App')] [string]$Type)
    Start-NativeFilePicker -Mode 'PickExecutable' -EntryType $Type -ReturnTab $(if($Type -eq 'Game'){5}else{2})
}

function Cycle-Browser {
    if ($script:DetectedBrowsers.Count -eq 0) {
        Ensure-BrowserSelection
    }
    if ($script:DetectedBrowsers.Count -eq 0) {
        Set-ConsoleNotice 'No registered web browsers were detected.' 'WARN'
        return
    }

    $index = -1
    for ($i = 0; $i -lt $script:DetectedBrowsers.Count; $i++) {
        if ($script:DetectedBrowsers[$i].Path -eq $script:Config.BrowserPath) { $index = $i; break }
    }
    $index = ($index + 1) % $script:DetectedBrowsers.Count
    $script:Config.BrowserName = $script:DetectedBrowsers[$index].Name
    $script:Config.BrowserPath = $script:DetectedBrowsers[$index].Path
    Save-Config
    Render-Page
}

function Cycle-BrowserMode {
    $modes = @('Normal','Fullscreen','Private Fullscreen')
    $index = [array]::IndexOf($modes, [string]$script:Config.BrowserMode)
    if ($index -lt 0) { $index = 0 }
    $script:Config.BrowserMode = $modes[($index + 1) % $modes.Count]
    Save-Config
    Render-Page
}

function Cycle-PromptOverride {
    $values = @('Auto','Xbox','PlayStation','Nintendo','Steam','Keyboard')
    $index = [array]::IndexOf($values, [string]$script:Config.PromptOverride)
    if ($index -lt 0) { $index = 0 }
    $script:Config.PromptOverride = $values[($index + 1) % $values.Count]
    Save-Config
    Render-Page
    Update-Footer
}


function New-DefaultUpdateState {
    [pscustomobject]@{
        Phase = 'Not scanned'
        Message = 'Choose Scan for updates to check Microsoft Update.'
        Busy = $false
        UpdateCount = 0
        Updates = @()
        RebootRequired = $false
        Error = ''
        ResultCode = 0
        UpdatedAt = ''
    }
}

function Read-UpdateState {
    if ( -not (Test-Path $script:UpdateStatePath)) {
        if ($null -eq $script:UpdateState) { $script:UpdateState = New-DefaultUpdateState }
        return
    }
    try {
        $raw = Get-Content -Raw -Path $script:UpdateStatePath | ConvertFrom-Json
        $script:UpdateState = $raw
    } catch {
        Write-Log "Update state read failed: $($_.Exception.Message)" 'WARN'
    }
}

function Start-UpdateWorker {
    param([ValidateSet('Scan','Install')] [string]$Action)
    Read-UpdateState
    if ($script:UpdateState -and [bool]$script:UpdateState.Busy) { return }
    if ( -not (Test-Path $script:UpdateWorkerPath)) {
        Set-ConsoleNotice 'The Windows Update worker is missing from this installation.' 'ERROR'
        return
    }

    $quotedWorker = '"' + $script:UpdateWorkerPath + '"'
    $quotedState = '"' + $script:UpdateStatePath + '"'
    $arguments = "-NoLogo -NoProfile -ExecutionPolicy Bypass -File $quotedWorker -Action $Action -StatePath $quotedState"
    try {
        if ($Action -eq 'Install') {
            Start-Process "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -ArgumentList $arguments -Verb RunAs -WindowStyle Hidden | Out-Null
        } else {
            Start-Process "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -ArgumentList $arguments -WindowStyle Hidden | Out-Null
        }
        $script:UpdateState = New-DefaultUpdateState
        $script:UpdateState.Phase = $(if ($Action -eq 'Scan') { 'Scanning' } else { 'Preparing' })
        $script:UpdateState.Message = $(if ($Action -eq 'Scan') { 'Checking Windows Update...' } else { 'Preparing updates. Approve the Windows administrator prompt if shown.' })
        $script:UpdateState.Busy = $true
        Render-Page
    } catch {
        Set-ConsoleNotice "Windows Update could not start: $($_.Exception.Message)" 'ERROR'
    }
}

function Get-UpdateHeroText {
    Read-UpdateState
    $state = $script:UpdateState
    $parts = New-Object System.Collections.Generic.List[string]
    $parts.Add([string]$state.Message)
    if ($state.Error) { $parts.Add("Error: $($state.Error)") }
    $updates = @($state.Updates)
    if ($updates.Count -gt 0) {
        $parts.Add('')
        $limit = [math]::Min(5, $updates.Count)
        for ($i=0; $i -lt $limit; $i++) {
            $suffix = if ($updates[$i].KB) { " ($($updates[$i].KB))" } else { '' }
            $parts.Add("- $($updates[$i].Title)$suffix")
        }
        if ($updates.Count -gt $limit) { $parts.Add("- plus $($updates.Count - $limit) more") }
    }
    return ($parts -join "`n")
}


function New-DefaultDriverState {
    [pscustomobject]@{
        Phase = 'Not scanned'
        Message = 'Choose Scan for driver updates to detect hardware and query Windows Update.'
        Busy = $false
        DriverCount = 0
        DisplayDriverCount = 0
        UpdateCount = 0
        Drivers = @()
        DisplayDrivers = @()
        Updates = @()
        RebootRequired = $false
        Error = ''
        ResultCode = 0
        LastAction = ''
        UpdatedAt = ''
    }
}

function Read-DriverState {
    if ( -not (Test-Path $script:DriverStatePath)) {
        if ($null -eq $script:DriverState) { $script:DriverState = New-DefaultDriverState }
        return
    }
    try {
        $raw = Get-Content -Raw -Path $script:DriverStatePath | ConvertFrom-Json
        $script:DriverState = $raw
    } catch {
        Write-Log "Driver state read failed: $($_.Exception.Message)" 'WARN'
    }
}

function Start-DriverWorker {
    param(
        [ValidateSet('Scan','InstallUpdates','InstallUpdate','InstallPackage')][string]$Action,
        [string]$PackagePath='',
        [string]$UpdateId=''
    )
    Read-DriverState
    if ($script:DriverState -and [bool](Get-EntryProperty $script:DriverState 'Busy' $false)) { return }
    if ( -not (Test-Path $script:DriverWorkerPath)) {
        Set-ConsoleNotice 'The native driver-management worker is missing from this installation.' 'ERROR'
        return
    }

    $quotedWorker='"'+$script:DriverWorkerPath+'"'
    $quotedState='"'+$script:DriverStatePath+'"'
    $arguments="-NoLogo -NoProfile -ExecutionPolicy Bypass -File $quotedWorker -Action $Action -StatePath $quotedState"
    if($Action -eq 'InstallPackage'){
        $escaped=[string]$PackagePath
        $escaped=$escaped.Replace('"','\"')
        $arguments += ' -PackagePath "'+$escaped+'"'
    }
    if($Action -eq 'InstallUpdate' -and $UpdateId){$arguments += ' -UpdateId "'+$UpdateId+'"'}
    try {
        Write-Log "Driver worker requested: Action=$Action$(if($PackagePath){' Package='+$PackagePath}else{''})"
        $requiresAdmin=$Action -in @('InstallUpdates','InstallUpdate','InstallPackage')
        if($requiresAdmin){
            Start-Process "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -ArgumentList $arguments -Verb RunAs -WindowStyle Hidden | Out-Null
        }else{
            Start-Process "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -ArgumentList $arguments -WindowStyle Hidden | Out-Null
        }
        $script:DriverState=New-DefaultDriverState
        $script:DriverState.Phase=$(if($Action -eq 'Scan'){'Scanning'}else{'Preparing'})
        $script:DriverState.Message=$(switch($Action){
            'Scan' {'Detecting hardware and checking Windows Update for driver updates...'}
            'InstallUpdates' {'Preparing recommended driver updates. Approve the Windows administrator prompt if shown.'}
            'InstallUpdate' {'Preparing the selected driver update. Approve the Windows administrator prompt if shown.'}
            'InstallPackage' {"Preparing signed driver packages from $PackagePath. Approve the Windows administrator prompt if shown."}
        })
        $script:DriverState.Busy=$true
        Render-Page
    }catch{
        Set-ConsoleNotice "Driver management could not start: $($_.Exception.Message)" 'ERROR'
    }
}

function Get-DriverHeroText {
    Read-DriverState
    $state=$script:DriverState
    $parts=New-Object System.Collections.Generic.List[string]
    $parts.Add([string](Get-EntryProperty $state 'Message' 'Driver management is ready.'))
    if([string](Get-EntryProperty $state 'Error' '')){$parts.Add("Error: $([string](Get-EntryProperty $state 'Error' ''))")}
    $gpus=@(Get-EntryProperty $state 'DisplayDrivers' @())
    if($gpus.Count -gt 0){
        $parts.Add('')
        foreach($gpu in ($gpus|Select-Object -First 3)){
            $name=[string](Get-EntryProperty $gpu 'DeviceName' 'Graphics adapter')
            $version=[string](Get-EntryProperty $gpu 'Version' '')
            $provider=[string](Get-EntryProperty $gpu 'Provider' '')
            $parts.Add("GPU: $name`n$provider  |  Driver $version")
        }
    }
    $updates=@(Get-EntryProperty $state 'Updates' @())
    if($updates.Count -gt 0){
        $parts.Add('')
        $parts.Add('Recommended updates:')
        foreach($update in ($updates|Select-Object -First 4)){$parts.Add("- $([string](Get-EntryProperty $update 'Title' 'Driver update'))")}
        if($updates.Count -gt 4){$parts.Add("- plus $($updates.Count-4) more")}
    }
    return ($parts -join "`n")
}

function Open-DriverPackagePicker {
    Start-NativeFilePicker -Mode 'PickFolder' -Store 'Driver Package' -EntryType 'DriverPackage' -ReturnTab 7 -StartPath (Join-Path $env:USERPROFILE 'Downloads')
}

function Refresh-DisplayState {
    try {
        $script:Displays = Convert-ToStableArray ([HuymaierConsole.Native.DisplayBridge]::GetDisplays())
    } catch {
        $script:Displays = @()
        Write-Log "Display enumeration failed: $($_.Exception.Message)" 'WARN'
        return
    }
    if ($script:Displays.Count -eq 0) { return }
    if ($script:DisplayIndex -lt 0 -or $script:DisplayIndex -ge $script:Displays.Count) {
        $script:DisplayIndex = 0
        for ($i=0; $i -lt $script:Displays.Count; $i++) {
            if ($script:Displays[$i].Primary) { $script:DisplayIndex = $i; break }
        }
    }
    $display = $script:Displays[$script:DisplayIndex]
    $script:DisplayModes = Convert-ToStableArray ([HuymaierConsole.Native.DisplayBridge]::GetModes([string]$display.DeviceName))
    if ($script:PendingWidth -le 0 -or $script:PendingHeight -le 0) {
        $script:PendingWidth = [int]$display.Width
        $script:PendingHeight = [int]$display.Height
        $script:PendingFrequency = [int]$display.Frequency
    }
}

function Get-SelectedDisplay {
    if ($script:Displays.Count -eq 0) { Refresh-DisplayState }
    if ($script:Displays.Count -eq 0) { return $null }
    return $script:Displays[$script:DisplayIndex]
}

function Get-DisplayHdrStatus {
    $display = Get-SelectedDisplay
    if ($null -eq $display) { return $null }
    try { return [HuymaierConsole.Native.DisplayBridge]::GetHdrStatus([string]$display.DeviceName) } catch { return $null }
}

function Cycle-DisplayTarget {
    if ($script:Displays.Count -eq 0) { Refresh-DisplayState }
    if ($script:Displays.Count -eq 0) { return }
    $script:DisplayIndex = ($script:DisplayIndex + 1) % $script:Displays.Count
    $display = $script:Displays[$script:DisplayIndex]
    $script:PendingWidth = [int]$display.Width
    $script:PendingHeight = [int]$display.Height
    $script:PendingFrequency = [int]$display.Frequency
    Refresh-DisplayState
    Render-Page
}

function Get-ResolutionChoices {
    $choices = New-Object System.Collections.Generic.List[object]
    $seen = @{}
    foreach ($mode in @($script:DisplayModes)) {
        $key = "$($mode.Width)x$($mode.Height)"
        if ( -not $seen.ContainsKey($key)) {
            $seen[$key] = $true
            $choices.Add([pscustomobject]@{ Width=[int]$mode.Width; Height=[int]$mode.Height })
        }
    }
    return [object[]]$choices.ToArray()
}

function Cycle-DisplayResolution {
    $choices = @(Get-ResolutionChoices)
    if ($choices.Count -eq 0) { return }
    $current = -1
    for ($i=0; $i -lt $choices.Count; $i++) {
        if ($choices[$i].Width -eq $script:PendingWidth -and $choices[$i].Height -eq $script:PendingHeight) { $current=$i; break }
    }
    $choice = $choices[($current + 1) % $choices.Count]
    $script:PendingWidth = [int]$choice.Width
    $script:PendingHeight = [int]$choice.Height
    $rates = Convert-ToStableArray ($script:DisplayModes | Where-Object { $_.Width -eq $script:PendingWidth -and $_.Height -eq $script:PendingHeight } | Select-Object -ExpandProperty Frequency -Unique | Sort-Object)
    if ($rates.Count -gt 0 -and $rates -notcontains $script:PendingFrequency) { $script:PendingFrequency = [int]$rates[-1] }
    Render-Page
}

function Cycle-DisplayRefreshRate {
    $rates = Convert-ToStableArray ($script:DisplayModes | Where-Object { $_.Width -eq $script:PendingWidth -and $_.Height -eq $script:PendingHeight } | Select-Object -ExpandProperty Frequency -Unique | Sort-Object)
    if ($rates.Count -eq 0) { return }
    $index = [array]::IndexOf($rates, $script:PendingFrequency)
    if ($index -lt 0) { $index = 0 }
    $script:PendingFrequency = [int]$rates[($index + 1) % $rates.Count]
    Render-Page
}

function Apply-PendingDisplayMode {
    $display = Get-SelectedDisplay
    if ($null -eq $display) { return }
    $script:DisplayPreviousMode = [pscustomobject]@{
        DeviceName = [string]$display.DeviceName
        Width = [int]$display.Width
        Height = [int]$display.Height
        Frequency = [int]$display.Frequency
    }
    try {
        $result = [HuymaierConsole.Native.DisplayBridge]::ApplyMode([string]$display.DeviceName, $script:PendingWidth, $script:PendingHeight, $script:PendingFrequency)
        if ($result -ne 0) {
            Set-ConsoleNotice "Windows rejected this display mode. Result code: $result" 'WARN'
            return
        }
        $script:DisplayPendingConfirmation = $true
        $script:DisplayConfirmUntil = (Get-Date).AddSeconds(15)
        Refresh-DisplayState
        Render-Page
    } catch {
        Set-ConsoleNotice "Unable to change the display mode: $($_.Exception.Message)" 'ERROR'
    }
}

function Keep-DisplayMode {
    $script:DisplayPendingConfirmation = $false
    $script:DisplayPreviousMode = $null
    Refresh-DisplayState
    Render-Page
}

function Revert-DisplayMode {
    if ($null -ne $script:DisplayPreviousMode) {
        try {
            [void][HuymaierConsole.Native.DisplayBridge]::ApplyMode([string]$script:DisplayPreviousMode.DeviceName, [int]$script:DisplayPreviousMode.Width, [int]$script:DisplayPreviousMode.Height, [int]$script:DisplayPreviousMode.Frequency)
        } catch { }
    }
    $script:DisplayPendingConfirmation = $false
    $script:DisplayPreviousMode = $null
    Refresh-DisplayState
    if ($script:Displays.Count -gt 0) {
        $display = $script:Displays[$script:DisplayIndex]
        $script:PendingWidth = [int]$display.Width
        $script:PendingHeight = [int]$display.Height
        $script:PendingFrequency = [int]$display.Frequency
    }
    Render-Page
}

function Toggle-DisplayHdr {
    $display = Get-SelectedDisplay
    $status = Get-DisplayHdrStatus
    if ($null -eq $display -or $null -eq $status -or -not $status.Supported) { return }
    try {
        $result = [HuymaierConsole.Native.DisplayBridge]::SetHdrState([string]$display.DeviceName, ( -not [bool]$status.Enabled))
        if ($result -ne 0) {
            Set-ConsoleNotice "Windows could not change HDR. Result code: $result" 'WARN'
        }
        Start-Sleep -Milliseconds 300
        Refresh-DisplayState
        Render-Page
    } catch {
        Set-ConsoleNotice "Unable to change HDR: $($_.Exception.Message)" 'ERROR'
    }
}

function Get-WindowsEffectiveDisplayScalePercent {
    try {
        if ($null -ne $script:Window) {
            $dpi = [System.Windows.Media.VisualTreeHelper]::GetDpi($script:Window)
            if ($dpi.DpiScaleX -gt 0) { return [int][math]::Round([double]$dpi.DpiScaleX * 100.0) }
        }
    } catch { }
    return 100
}

function Get-WindowsConfiguredDisplayScalePercent {
    $effective = Get-WindowsEffectiveDisplayScalePercent
    try {
        $desktop = Get-ItemProperty -LiteralPath 'HKCU:\Control Panel\Desktop' -ErrorAction Stop
        $logPixels = $null
        try { $logPixels = [int]$desktop.LogPixels } catch { }
        if ($null -ne $logPixels -and $logPixels -ge 96 -and $logPixels -le 480) {
            return [int][math]::Round([double]$logPixels * 100.0 / 96.0)
        }
    } catch { }
    return $effective
}

function Set-WindowsDisplayScalePercent {
    param([int]$Percent)
    if ($Percent -lt 100 -or $Percent -gt 500) {
        Set-ConsoleNotice 'Windows display scale must be between 100% and 500%.' 'ERROR'
        return
    }
    try {
        $desktop = 'HKCU:\Control Panel\Desktop'
        $dpi = [int][math]::Round(96.0 * $Percent / 100.0)
        $props = Get-ItemProperty -LiteralPath $desktop -ErrorAction Stop
        if ($props.PSObject.Properties.Name -contains 'LogPixels') { Set-ItemProperty -LiteralPath $desktop -Name 'LogPixels' -Value $dpi -Force }
        else { New-ItemProperty -LiteralPath $desktop -Name 'LogPixels' -PropertyType DWord -Value $dpi -Force | Out-Null }
        if ($props.PSObject.Properties.Name -contains 'Win8DpiScaling') { Set-ItemProperty -LiteralPath $desktop -Name 'Win8DpiScaling' -Value 1 -Force }
        else { New-ItemProperty -LiteralPath $desktop -Name 'Win8DpiScaling' -PropertyType DWord -Value 1 -Force | Out-Null }
        Write-Log "Windows display scale configured to $Percent% ($dpi DPI). Windows sign-out is required for full application."
        Set-ConsoleNotice "Windows scale set to $Percent%. Sign out of Windows to apply it fully." 'INFO'
    } catch {
        Write-Log "Windows display scale change failed: $($_.Exception.ToString())" 'ERROR'
        Set-ConsoleNotice "Display scale change failed: $($_.Exception.Message)" 'ERROR'
    }
}

function Start-ElementAnimation {
    param($Target, $Property, [double]$From, [double]$To, [double]$Seconds, [bool]$AutoReverse)
    if ($null -eq $Target) { return }
    try {
        $animation = New-Object System.Windows.Media.Animation.DoubleAnimation
        $animation.From = $From
        $animation.To = $To
        $animation.Duration = New-Object System.Windows.Duration -ArgumentList ([TimeSpan]::FromSeconds($Seconds))
        $animation.AutoReverse = $AutoReverse
        $animation.RepeatBehavior = [System.Windows.Media.Animation.RepeatBehavior]::Forever
        $animation.EasingFunction = New-Object System.Windows.Media.Animation.SineEase
        $Target.BeginAnimation($Property, $animation)
    } catch {
        Write-Log "Background animation failed: $($_.Exception.Message)" 'WARN'
    }
}

function Set-BackgroundAnimationState {
    if ($null -eq $script:DynamicBackdrop) { return }
    $enabled = [bool]$script:Config.DynamicBackground
    $script:DynamicBackdrop.Visibility = $(if ($enabled) { 'Visible' } else { 'Collapsed' })
    if ( -not $enabled) { return }

    # The v0.3 backdrop deliberately crosses the entire viewport. Motion is
    # slow enough for couch use, but strong enough to remain visible behind UI.
    Start-ElementAnimation $script:DynamicBackdrop ([System.Windows.UIElement]::OpacityProperty) 0.88 1.0 9 $true
    Start-ElementAnimation $script:GoldGlowTransform ([System.Windows.Media.TranslateTransform]::XProperty) -110 150 16 $true
    Start-ElementAnimation $script:GoldGlowTransform ([System.Windows.Media.TranslateTransform]::YProperty) -70 110 21 $true
    Start-ElementAnimation $script:BlueGlowTransform ([System.Windows.Media.TranslateTransform]::XProperty) 130 -170 23 $true
    Start-ElementAnimation $script:BlueGlowTransform ([System.Windows.Media.TranslateTransform]::YProperty) 100 -120 19 $true
    Start-ElementAnimation $script:RingTransform ([System.Windows.Media.RotateTransform]::AngleProperty) 0 360 58 $false
    Start-ElementAnimation $script:RingTwoTransform ([System.Windows.Media.RotateTransform]::AngleProperty) 360 0 86 $false
    Start-ElementAnimation $script:RibbonOneTransform ([System.Windows.Media.TranslateTransform]::XProperty) -150 180 18 $true
    Start-ElementAnimation $script:RibbonTwoTransform ([System.Windows.Media.TranslateTransform]::XProperty) 190 -210 25 $true
    Start-ElementAnimation $script:RibbonThreeTransform ([System.Windows.Media.TranslateTransform]::YProperty) -90 125 22 $true
    Start-ElementAnimation $script:ConstellationTransform ([System.Windows.Media.TranslateTransform]::XProperty) -70 100 31 $true
    Start-ElementAnimation $script:ConstellationTransform ([System.Windows.Media.TranslateTransform]::YProperty) 45 -70 27 $true

    $starSeconds = @(2.8,3.4,4.2,3.1,5.0,3.8,4.6,2.9)
    $stars = @($script:StarOne,$script:StarTwo,$script:StarThree,$script:StarFour,$script:StarFive,$script:StarSix,$script:StarSeven,$script:StarEight)
    for ($i=0; $i -lt $stars.Count; $i++) {
        Start-ElementAnimation $stars[$i] ([System.Windows.UIElement]::OpacityProperty) 0.18 0.92 $starSeconds[$i] $true
    }
}

function Initialize-UiFeedback {
    foreach ($name in @('Navigate','Tab','Confirm','Back')) {
        $path = [string]$script:SfxPaths[$name]
        if ( -not (Test-Path $path)) { continue }
        try {
            $player = New-Object System.Windows.Media.MediaPlayer
            $player.Open([uri]$path)
            $player.Volume = 0.62
            $script:SfxPlayers[$name] = $player
        } catch {
            Write-Log "UI sound '$name' initialization failed: $($_.Exception.Message)" 'WARN'
        }
    }
}

function Play-UiSound {
    param([ValidateSet('Navigate','Tab','Confirm','Back')][string]$Kind)
    if ( -not [bool]$script:Config.UiSoundsEnabled) { return }
    try {
        if ( -not $script:SfxPlayers.ContainsKey($Kind)) { Initialize-UiFeedback }
        $player = $script:SfxPlayers[$Kind]
        if ($null -ne $player) {
            $player.Stop()
            $player.Position = [TimeSpan]::Zero
            $player.Play()
        }
    } catch { }
}

function Invoke-ControllerPulse {
    param([ValidateSet('Navigate','Tab','Confirm','Back')][string]$Kind)
    if ( -not [bool]$script:Config.HapticsEnabled) { return }
    if ((Get-PromptFamily) -eq 'Keyboard') { return }
    try {
        $snap = Get-ControllerSnapshot
        if ($snap.Gamepads.Count -eq 0) {
            foreach($raw in $snap.Raw){
                try{
                    $controllers=Convert-ToStableArray $raw.SimpleHapticsControllers
                    foreach($haptic in $controllers){
                        $feedback=Convert-ToStableArray $haptic.SupportedFeedback
                        if($feedback.Count -gt 0){
                            $strength=if($Kind -eq 'Confirm'){0.34}elseif($Kind -eq 'Back'){0.22}else{0.14}
                            $duration=if($Kind -eq 'Confirm'){[TimeSpan]::FromMilliseconds(32)}else{[TimeSpan]::FromMilliseconds(18)}
                            $haptic.SendHapticFeedbackForDuration($feedback[0],[double]$strength,$duration)
                            return
                        }
                    }
                }catch{}
            }
            return
        }
        $index = [math]::Max(0, [math]::Min($script:ActiveGamepadIndex, $snap.Gamepads.Count - 1))
        $gamepad = $snap.Gamepads[$index]
        $left = 0.0; $right = 0.0; $duration = 16
        switch ($Kind) {
            'Navigate' { $left = 0.035; $right = 0.07; $duration = 12 }
            'Tab'      { $left = 0.055; $right = 0.11; $duration = 18 }
            'Confirm'  { $left = 0.12;  $right = 0.22; $duration = 32 }
            'Back'     { $left = 0.08;  $right = 0.14; $duration = 24 }
        }
        $vibrationType = [Windows.Gaming.Input.GamepadVibration,Windows.Gaming.Input,ContentType=WindowsRuntime]
        $pulse = [Activator]::CreateInstance($vibrationType)
        $pulse.LeftMotor = [double]$left
        $pulse.RightMotor = [double]$right
        $pulse.LeftTrigger = 0.0
        $pulse.RightTrigger = 0.0
        $gamepad.Vibration = $pulse
        Start-Sleep -Milliseconds $duration
        $off = [Activator]::CreateInstance($vibrationType)
        $gamepad.Vibration = $off
    } catch {
        # Some raw HID drivers expose navigation but no Windows Gamepad
        # vibration channel. They still receive audio feedback.
    }
}

function Invoke-UiFeedback {
    param([ValidateSet('Navigate','Tab','Confirm','Back')][string]$Kind)
    Play-UiSound $Kind
    Invoke-ControllerPulse $Kind
}

function Toggle-UiSounds {
    $script:Config.UiSoundsEnabled = -not [bool]$script:Config.UiSoundsEnabled
    Save-Config
    if ([bool]$script:Config.UiSoundsEnabled) { Play-UiSound 'Confirm' }
    Render-Page
}

function Toggle-Haptics {
    $script:Config.HapticsEnabled = -not [bool]$script:Config.HapticsEnabled
    Save-Config
    if ([bool]$script:Config.HapticsEnabled) { Invoke-ControllerPulse 'Confirm' }
    Render-Page
}

function Get-SelectedMusicPath {
    $theme=[string]$script:Config.MusicTheme
    if ($theme -eq 'Custom') {
        $custom=[string]$script:Config.CustomMusicPath
        if ($custom -and (Test-Path $custom)) { return $custom }
        $script:Config.MusicTheme='Orchestral'
        Save-Config
    }
    if ($script:BuiltInMusic.ContainsKey($theme) -and (Test-Path $script:BuiltInMusic[$theme])) { return [string]$script:BuiltInMusic[$theme] }
    return [string]$script:BuiltInMusic.Orchestral
}

function Initialize-BackgroundMusic {
    try { if ($null -ne $script:MusicPlayer) { $script:MusicPlayer.Stop(); $script:MusicPlayer.Close() } } catch { }
    $script:MusicPlayer=$null
    $script:MusicPath=Get-SelectedMusicPath
    if ( -not (Test-Path $script:MusicPath)) { return }
    try {
        $script:MusicPlayer=New-Object System.Windows.Media.MediaPlayer
        $script:MusicPlayer.Open([uri]$script:MusicPath)
        $script:MusicPlayer.Volume=[math]::Max(0.0,[math]::Min(1.0,([int]$script:Config.MusicVolume/100.0)))
        $script:MusicPlayer.Add_MediaEnded({ try { $script:MusicPlayer.Position=[TimeSpan]::Zero; if([bool]$script:Config.MusicEnabled -and $script:Window.IsActive){$script:MusicPlayer.Play()} } catch{} })
        if([bool]$script:Config.MusicEnabled){$script:MusicPlayer.Play()}
    } catch { Write-Log "Background music initialization failed: $($_.Exception.Message)" 'WARN' }
}

function Update-BackgroundMusic {
    if($null -eq $script:MusicPlayer){Initialize-BackgroundMusic}
    if($null -eq $script:MusicPlayer){return}
    try{
        $script:MusicPlayer.Volume=[math]::Max(0.0,[math]::Min(1.0,([int]$script:Config.MusicVolume/100.0)))
        if([bool]$script:Config.MusicEnabled -and $script:Window.IsActive){$script:MusicPlayer.Play()}else{$script:MusicPlayer.Pause()}
    }catch{}
}

function Toggle-BackgroundMusic { $script:Config.MusicEnabled= -not [bool]$script:Config.MusicEnabled; Save-Config; Update-BackgroundMusic; Render-Page }
function Cycle-MusicVolume {
    $levels=@(10,20,30,40,55,70,85,100); $current=[int]$script:Config.MusicVolume; $next=$levels[0]
    for($i=0;$i -lt $levels.Count;$i++){if($levels[$i] -gt $current){$next=$levels[$i];break};if($i -eq $levels.Count-1){$next=$levels[0]}}
    $script:Config.MusicVolume=$next;Save-Config;Update-BackgroundMusic;Render-Page
}
function Cycle-MusicTheme {
    $themes=@('Orchestral','Power','Custom'); $available=New-Object System.Collections.ArrayList
    foreach($theme in $themes){if($theme -ne 'Custom' -or ([string]$script:Config.CustomMusicPath -and (Test-Path ([string]$script:Config.CustomMusicPath)))){[void]$available.Add($theme)}}
    $index=[array]::IndexOf([object[]]$available.ToArray(),[string]$script:Config.MusicTheme);if ($index -lt 0) { $index = 0 }
    $script:Config.MusicTheme=[string]$available[($index+1)%$available.Count];Save-Config;Initialize-BackgroundMusic;Render-Page
}
function Import-CustomMusic {
    Start-NativeFilePicker -Mode 'PickAudio' -EntryType 'Music' -ReturnTab 7
}

function Toggle-DynamicBackground { $script:Config.DynamicBackground= -not [bool]$script:Config.DynamicBackground;Save-Config;Set-BackgroundAnimationState;Render-Page }

function Refresh-AudioState {
    $items = New-Object System.Collections.ArrayList
    $defaultId = ''
    try { $defaultId = [string][HuymaierConsole.Native.AudioBridge]::GetDefaultEndpointId() } catch { }
    try {
        $root = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\MMDevices\Audio\Render'
        if (Test-Path $root) {
            foreach ($key in Get-ChildItem $root -ErrorAction SilentlyContinue) {
                try {
                    $stateValue = 0
                    try { $stateValue = [int](Get-ItemPropertyValue -LiteralPath $key.PSPath -Name 'DeviceState' -ErrorAction Stop) } catch { }
                    if (($stateValue -band 1) -eq 0) { continue }
                    $propertiesPath = Join-Path $key.PSPath 'Properties'
                    $name = ''
                    if (Test-Path $propertiesPath) {
                        $props = Get-ItemProperty -LiteralPath $propertiesPath -ErrorAction SilentlyContinue
                        foreach ($property in $props.PSObject.Properties) {
                            if ($property.Name -match '\},14$' -and -not [string]::IsNullOrWhiteSpace([string]$property.Value)) { $name=[string]$property.Value; break }
                        }
                    }
                    if ( -not $name) { $name = 'Audio output' }
                    $id = [string]$key.PSChildName
                    [void]$items.Add([pscustomobject]@{ Id=$id; Name=$name; IsDefault=[string]::Equals($id,$defaultId,[StringComparison]::OrdinalIgnoreCase); State=$stateValue })
                } catch { }
            }
        }
    } catch { Write-Log "Audio endpoint registry enumeration failed: $($_.Exception.Message)" 'WARN' }
    $script:AudioEndpoints = [object[]]$items.ToArray()
    $script:AudioIndex = 0
    for($i=0;$i -lt $script:AudioEndpoints.Count;$i++){if([bool]$script:AudioEndpoints[$i].IsDefault){$script:AudioIndex=$i;break}}
}
function Get-AudioVolume { try{return [int][math]::Round([HuymaierConsole.Native.AudioBridge]::GetMasterVolume()*100)}catch{return 0} }
function Get-AudioMute { try{return [bool][HuymaierConsole.Native.AudioBridge]::GetMute()}catch{return $false} }
function Adjust-AudioVolume { param([int]$Delta);$value=[math]::Max(0,[math]::Min(100,(Get-AudioVolume)+$Delta));try{[HuymaierConsole.Native.AudioBridge]::SetMasterVolume($value/100.0)}catch{};Render-Page }
function Toggle-AudioMute { try{[HuymaierConsole.Native.AudioBridge]::SetMute( -not (Get-AudioMute))}catch{};Render-Page }
function Cycle-AudioOutput {
    Refresh-AudioState
    if ($script:AudioEndpoints.Count -lt 2) { Render-Page; return }
    $next=($script:AudioIndex+1)%$script:AudioEndpoints.Count
    $endpoint=$script:AudioEndpoints[$next]
    try {
        if([HuymaierConsole.Native.AudioBridge]::SetDefaultEndpoint([string]$endpoint.Id)){
            Start-Sleep -Milliseconds 120
            Refresh-AudioState
        }
    } catch { Write-Log "Audio output switch failed: $($_.Exception.Message)" 'WARN' }
    Render-Page
}

function Refresh-DeviceState {
    $items=New-Object System.Collections.ArrayList
    try {
        $devices=Get-CimInstance Win32_PnPEntity -ErrorAction Stop | Where-Object { $_.Present -ne $false -and ($_.PNPClass -in @('Bluetooth','HIDClass','Keyboard','Mouse','AudioEndpoint') -or $_.Name -match 'Bluetooth|Controller|Gamepad|DualSense|DualShock|Xbox|Nintendo|Steam') }
        foreach($device in $devices|Sort-Object PNPClass,Name){
            [void]$items.Add([pscustomobject]@{Name=[string]$device.Name;Class=[string]$device.PNPClass;Status=[string]$device.Status;DeviceId=[string]$device.DeviceID})
        }
    } catch { Write-Log "Device enumeration failed: $($_.Exception.Message)" 'WARN' }
    $script:BluetoothDevices=[object[]]$items.ToArray();$script:DeviceRefreshAt=Get-Date
}
function Format-FileSize {
    param([long]$Bytes)
    if ($Bytes -ge 1GB) { return ('{0:N1} GB' -f ($Bytes/1GB)) }
    if ($Bytes -ge 1MB) { return ('{0:N1} MB' -f ($Bytes/1MB)) }
    if ($Bytes -ge 1KB) { return ('{0:N0} KB' -f ($Bytes/1KB)) }
    return "$Bytes B"
}

function Get-FileBrowserItems {
    $items = New-Object System.Collections.ArrayList
    if ([string]::IsNullOrWhiteSpace($script:FileBrowserPath)) {
        foreach ($drive in Get-PSDrive -PSProvider FileSystem -ErrorAction SilentlyContinue | Sort-Object Name) {
            if ( -not $drive.Root) { continue }
            $free = ''; try { if ($null -ne $drive.Free) { $free = "$(Format-FileSize ([long]$drive.Free)) free" } } catch { }
            [void]$items.Add([pscustomobject]@{ Type='Drive'; Name="$($drive.Name):"; FullName=[string]$drive.Root; Description=$free; Extension=''; Length=0 })
        }
    } else {
        try {
            $children = Get-ChildItem -LiteralPath $script:FileBrowserPath -ErrorAction Stop
            foreach ($entry in ($children | Where-Object { $_.PSIsContainer } | Sort-Object Name)) {
                [void]$items.Add([pscustomobject]@{ Type='Directory'; Name=$entry.Name; FullName=$entry.FullName; Description='Folder'; Extension=''; Length=0 })
            }
            $allowed = @()
            if ($script:FileBrowserMode -eq 'PickExecutable') { $allowed=@('.exe','.lnk','.url') }
            elseif ($script:FileBrowserMode -eq 'PickAudio') { $allowed=@('.wav','.mp3','.wma','.m4a','.aac') }
            if ($script:FileBrowserMode -eq 'PickFolder') { return [object[]]$items.ToArray() }
            foreach ($entry in ($children | Where-Object { -not $_.PSIsContainer } | Sort-Object Name)) {
                $extension = [string]$entry.Extension
                if ($allowed.Count -gt 0 -and $extension.ToLowerInvariant() -notin $allowed) { continue }
                [void]$items.Add([pscustomobject]@{ Type='File'; Name=$entry.Name; FullName=$entry.FullName; Description="$(Format-FileSize ([long]$entry.Length))  |  $($entry.LastWriteTime.ToString('g'))"; Extension=$extension; Length=[long]$entry.Length })
            }
        } catch { Write-Log "Native file browser could not read '$($script:FileBrowserPath)': $($_.Exception.Message)" 'WARN' }
    }
    return [object[]]$items.ToArray()
}

function Start-NativeFilePicker {
    param(
        [ValidateSet('Browse','PickFolder','PickExecutable','PickAudio')][string]$Mode='Browse',
        [string]$Store='',
        [string]$EntryType='',
        [int]$ReturnTab=-1,
        [string]$StartPath=''
    )
    $script:FileBrowserMode=$Mode
    $script:FileBrowserStore=$Store
    $script:FileBrowserEntryType=$EntryType
    $script:FileBrowserReturnTab=if($ReturnTab -ge 0){$ReturnTab}else{$script:SelectedTab}
    $script:FileBrowserReturnSubPage=$script:SubPage
    $script:FileBrowserPage=0
    if ($StartPath -and (Test-Path -LiteralPath $StartPath -PathType Container)) { $script:FileBrowserPath=$StartPath }
    elseif ($Mode -eq 'Browse') { if ( -not $script:FileBrowserPath) { $script:FileBrowserPath='' } }
    else { $script:FileBrowserPath=$env:USERPROFILE }
    if ($Mode -eq 'Browse') {
        $script:SubPage=''
        Set-Tab 6
    } else {
        $script:SubPage='FilePicker'
        $script:SelectedAction=0
        Render-Page
    }
}

function Complete-NativeFolderSelection {
    if ([string]::IsNullOrWhiteSpace($script:FileBrowserPath) -or -not (Test-Path -LiteralPath $script:FileBrowserPath -PathType Container)) { return }
    $path=[string]$script:FileBrowserPath
    $store=[string]$script:FileBrowserStore
    if($script:FileBrowserEntryType -eq 'ProviderInstall' -and (Get-Command Complete-ProviderFolderSelection -ErrorAction SilentlyContinue)){Complete-ProviderFolderSelection $path|Out-Null;return}
    if($script:FileBrowserEntryType -eq 'ProviderMove' -and (Get-Command Complete-ProviderMoveFolderSelection -ErrorAction SilentlyContinue)){Complete-ProviderMoveFolderSelection $path|Out-Null;return}
    if($script:FileBrowserEntryType -eq 'DriverPackage'){$script:SelectedTab=$script:FileBrowserReturnTab;$script:SubPage='Drivers';$script:SelectedAction=0;Start-DriverWorker 'InstallPackage' $path;Render-Page;Update-NavVisuals;return}
    $items=New-Object System.Collections.ArrayList
    foreach($existing in @($script:Config.StorefrontRoots)){if($null -ne $existing){[void]$items.Add($existing)}}
    $duplicate=$false
    foreach($existing in $items){
        if([string](Get-EntryProperty $existing 'Store' '') -eq $store -and [string]::Equals([string](Get-EntryProperty $existing 'Path' ''),$path,[StringComparison]::OrdinalIgnoreCase)){$duplicate=$true;break}
    }
    if( -not $duplicate){[void]$items.Add([pscustomobject]@{Store=$store;Path=$path})}
    $script:Config.StorefrontRoots=[object[]]$items.ToArray()
    Save-Config
    $script:SelectedTab=$script:FileBrowserReturnTab
    $script:SubPage=''
    $script:SelectedAction=0
    Start-LibraryScan
    Render-Page
    Update-NavVisuals
}

function Complete-NativeFileSelection {
    param($Entry)
    if ($null -eq $Entry -or [string](Get-EntryProperty $Entry 'Type') -ne 'File') { return }
    $path=[string](Get-EntryProperty $Entry 'FullName')
    if ( -not (Test-Path -LiteralPath $path -PathType Leaf)) { return }
    if ($script:FileBrowserMode -eq 'PickExecutable') {
        $type=[string]$script:FileBrowserEntryType
        $entry=[pscustomobject]@{
            Name=[IO.Path]::GetFileNameWithoutExtension($path)
            Path=$path
            Arguments=''
            LaunchTarget=$path
            Source=$(if($type -eq 'Game'){'Custom'}else{'App'})
            ArtworkPath=''
        }
        $returnTab=$script:FileBrowserReturnTab
        $returnSubPage=$script:FileBrowserReturnSubPage
        $script:SelectedTab=$returnTab
        $script:SubPage=$returnSubPage
        if($script:SubPage -eq 'FilePicker'){$script:SubPage=''}
        $script:SelectedAction=0
        Render-Page
        Update-NavVisuals
        Show-NativeKeyboard -Title "Name this $type" -InitialText ([string]$entry.Name) -Mode 'NameCustomEntry' -Context ([pscustomobject]@{Type=$type;Entry=$entry})
        return
    } elseif ($script:FileBrowserMode -eq 'PickAudio') {
        $script:Config.CustomMusicPath=$path
        $script:Config.MusicTheme='Custom'
        Save-Config
        Initialize-BackgroundMusic
    }
    $script:SelectedTab=$script:FileBrowserReturnTab
    $script:SubPage=$script:FileBrowserReturnSubPage
    if($script:SubPage -eq 'FilePicker'){$script:SubPage=''}
    $script:SelectedAction=0
    Render-Page
    Update-NavVisuals
}

function Cancel-NativeFilePicker {
    $script:SelectedTab=$script:FileBrowserReturnTab
    $script:SubPage=$script:FileBrowserReturnSubPage
    if($script:SubPage -eq 'FilePicker'){$script:SubPage=''}
    $script:SelectedAction=0
    Render-Page
    Update-NavVisuals
}

function Get-NativeFilePage {
    $script:FileBrowserEntries=@(Get-FileBrowserItems)
    $actions=New-Object System.Collections.Generic.List[object]
    if($script:FileBrowserMode -eq 'PickFolder' -and -not [string]::IsNullOrWhiteSpace($script:FileBrowserPath)){$actions.Add((New-Action 'file-confirm-folder' "Use this folder" $script:FileBrowserPath))}
    if( -not [string]::IsNullOrWhiteSpace($script:FileBrowserPath)){
        if($script:FileBrowserMode -in @('Browse','PickFolder')){$actions.Add((New-Action 'file-new-folder' 'Create folder' 'Use the native controller keyboard to name it.'))}
        $actions.Add((New-Action 'file-up' 'Up one level' (Split-Path -Parent $script:FileBrowserPath)))
        $actions.Add((New-Action 'file-root' 'This PC' 'Show drives and mapped network locations.'))
    }
    $total=$script:FileBrowserEntries.Count
    $maxPage=if($total -gt 0){[math]::Floor(($total-1)/$script:FileBrowserPageSize)}else{0}
    if($script:FileBrowserPage -gt $maxPage){$script:FileBrowserPage=$maxPage}
    if($script:FileBrowserPage -gt 0){$actions.Add((New-Action 'file-page-prev' 'Previous page' "Page $($script:FileBrowserPage) of $($maxPage+1)"))}
    $start=$script:FileBrowserPage*$script:FileBrowserPageSize
    $end=[math]::Min($total,$start+$script:FileBrowserPageSize)
    for($i=$start;$i -lt $end;$i++){
        $entry=$script:FileBrowserEntries[$i]
        $prefix=if($entry.Type -eq 'Drive'){'DRIVE'}elseif($entry.Type -eq 'Directory'){'FOLDER'}else{'FILE'}
        $actions.Add((New-Action "file-entry:$i" "$prefix  $($entry.Name)" $entry.Description))
    }
    if($script:FileBrowserPage -lt $maxPage){$actions.Add((New-Action 'file-page-next' 'Next page' "Page $($script:FileBrowserPage+2) of $($maxPage+1)"))}
    if($script:FileBrowserMode -ne 'Browse'){$actions.Add((New-Action 'file-cancel' 'Cancel' 'Return without selecting anything.'))}
    $title=if($script:FileBrowserMode -eq 'PickFolder'){"Choose $($script:FileBrowserStore) location"}elseif($script:FileBrowserMode -eq 'PickExecutable'){"Choose $($script:FileBrowserEntryType)"}elseif($script:FileBrowserMode -eq 'PickAudio'){'Choose background music'}else{'File Explorer'}
    $subtitle=if($script:FileBrowserMode -eq 'Browse'){'Browse drives, folders, network shares, and files without leaving Huymaier Console.'}else{'Controller-first native picker. No Windows dialog is opened.'}
    if([string]::IsNullOrWhiteSpace($script:FileBrowserPath)){$hero='THIS PC'}else{$hero=Split-Path -Leaf $script:FileBrowserPath;if(-not $hero){$hero=$script:FileBrowserPath}}
    return [pscustomobject]@{Title=$title;Subtitle=$subtitle;Hero=$hero.ToUpperInvariant();HeroText=$(if($script:FileBrowserPath){$script:FileBrowserPath}else{'Local drives and mapped locations'});Actions=([object[]]$actions.ToArray())}
}

function Request-NativeConfirmation {
    param([string]$Action,[string]$Question)
    $script:PendingConfirmation=[pscustomobject]@{Action=$Action;Question=$Question;ReturnTab=$script:SelectedTab;ReturnSubPage=$script:SubPage}
    $script:SubPage='Confirm'
    $script:SelectedAction=0
    Render-Page
}

function Complete-NativeConfirmation {
    param([bool]$Accepted)
    $pending=$script:PendingConfirmation
    if($null -eq $pending){return}
    $script:PendingConfirmation=$null
    $script:SelectedTab=[int]$pending.ReturnTab
    $script:SubPage=[string]$pending.ReturnSubPage
    if( -not $Accepted){Render-Page;Update-NavVisuals;return}
    $action=[string]$pending.Action
    if($action -like 'provider-uninstall:*' -and (Get-Command Complete-ProviderConfirmation -ErrorAction SilentlyContinue)){if(Complete-ProviderConfirmation $action){return}}
    if($action -match '^storefront-uninstall:(.+)$'){
        $storeId=[string]$matches[1]
        $script:SubPage=''
        Start-StorefrontWorker 'Uninstall' $storeId
        Render-Page
        Update-NavVisuals
        return
    }
    switch($action){
        'update-restart'{Start-Process 'shutdown.exe' -ArgumentList '/r','/t','0'|Out-Null}
        'display-scale-signout'{Start-Process 'shutdown.exe' -ArgumentList '/l'|Out-Null}
        'sleep'{Start-Process 'rundll32.exe' -ArgumentList 'powrprof.dll,SetSuspendState 0,1,0'|Out-Null}
        'restart-pc'{Start-Process 'shutdown.exe' -ArgumentList '/r','/t','0'|Out-Null}
        'shutdown-pc'{Start-Process 'shutdown.exe' -ArgumentList '/s','/t','0'|Out-Null}
    }
}

function Handle-Back {
    if((Get-Command Handle-HcGameExperienceBack -ErrorAction SilentlyContinue) -and (Handle-HcGameExperienceBack)){return}
    if($script:NavigationLayer -eq 'Navigation'){ Invoke-UiFeedback 'Back'; return }
    if ($script:KeyboardActive) { Invoke-UiFeedback 'Back'; Close-NativeKeyboard $false; return }
    if ($script:SubPage -like 'Storefront:*') { Invoke-UiFeedback 'Back'; $script:SubPage=''; $script:SelectedAction=0; Render-Page; return }
    if ($script:SubPage -eq 'FilePicker') { Invoke-UiFeedback 'Back'; Cancel-NativeFilePicker; return }
    if ($script:SubPage -eq 'Confirm') { Invoke-UiFeedback 'Back'; Complete-NativeConfirmation $false; return }
    if ($script:SelectedTab -eq 6 -and -not $script:SubPage -and -not [string]::IsNullOrWhiteSpace($script:FileBrowserPath)) {
        Invoke-UiFeedback 'Back'
        $parent=Split-Path -Parent $script:FileBrowserPath
        if($parent -and $parent -ne $script:FileBrowserPath){$script:FileBrowserPath=$parent}else{$script:FileBrowserPath=''}
        $script:FileBrowserPage=0;$script:SelectedAction=0;Render-Page;return
    }
    if ($script:SelectedTab -eq 1 -and $script:SubPage -eq 'ProviderGame') { Invoke-UiFeedback 'Back';$script:SubPage='ProviderStore';$script:SelectedAction=0;Render-Page;return }
    if ($script:SelectedTab -eq 1 -and $script:SubPage -eq 'ProviderStore') { Invoke-UiFeedback 'Back';$script:SubPage='PlatformChoice';$script:SelectedAction=0;Render-Page;return }
    if ($script:SelectedTab -eq 1 -and $script:SubPage -in @('PlatformHome','PlatformShelf','PlatformLibrary')) {
        Invoke-UiFeedback 'Back'
        $script:SubPage = 'PlatformChoice'
        $script:SelectedAction = 0
        Render-Page
        return
    }
    if ($script:SelectedTab -eq 1 -and $script:SubPage -eq 'PlatformChoice') {
        Invoke-UiFeedback 'Back'
        $script:SubPage = ''
        $script:SelectedAction = 0
        Render-Page
        return
    }
    if ($script:SubPage) {
        Invoke-UiFeedback 'Back'
        $script:SubPage = ''
        $script:SelectedAction = 0
        Render-Page
        return
    }
    Invoke-UiFeedback 'Back'
    Focus-TopNavigation
}

function Invoke-Action {
    param([string]$Id)
    if((Get-Command Invoke-GameProviderAction -ErrorAction SilentlyContinue) -and (Invoke-GameProviderAction $Id)){return}
    if((Get-Command Invoke-HcGameExperienceAction -ErrorAction SilentlyContinue) -and (Invoke-HcGameExperienceAction $Id)){return}
    switch -Regex ($Id) {
        '^nav:(\d+)$' { $script:NavigationLayer='Content'; Set-Tab ([int]$matches[1]); return }
        '^storefront:(.+)$' {
            $storeId=[string]$matches[1]
            $item=Get-StorefrontCatalogItem $storeId
            if($null -ne $item -and [bool]$item.Installed){Open-Storefront $storeId}
            else{Set-ConsoleNotice 'Press X or Square to install this storefront from its official source.' 'INFO';Render-Page}
            return
        }
        '^storefront-open:(.+)$' { Open-Storefront ([string]$matches[1]); return }
        '^storefront-install:(.+)$' { Start-StorefrontWorker 'Install' ([string]$matches[1]); Render-Page; return }
        '^storefront-uninstall:(.+)$' {
            $storeId=[string]$matches[1]
            $item=Get-StorefrontCatalogItem $storeId
            $name=if($null -ne $item){[string]$item.Name}else{$storeId}
            Request-NativeConfirmation "storefront-uninstall:$storeId" "Uninstall $name using its registered Windows uninstall method?"
            return
        }
        '^game:(\d+)$' { $item=@($script:Config.CustomGames)[[int]$matches[1]];if($item){Add-ToRecent 'Game' $item;Start-RecentEntry $item};return }
        '^app:(\d+)$' { $item=@($script:Config.CustomApps)[[int]$matches[1]];if($item){Add-ToRecent 'App' $item;Start-RecentEntry $item};return }
        '^imported-game:(\d+)$' { $item=@($script:Config.ImportedGames)[[int]$matches[1]];if($item){Add-ToRecent 'Game' $item;Start-RecentEntry $item};return }
        '^recent-game:(\d+)$' { $item=@($script:Config.RecentGames)[[int]$matches[1]];if($item){Add-ToRecent 'Game' $item;if((Get-Command Invoke-ProviderGameLaunchEntry -ErrorAction SilentlyContinue) -and (Invoke-ProviderGameLaunchEntry $item)){}else{Start-RecentEntry $item}};return }
        '^recent-app:(\d+)$' { $item=@($script:Config.RecentApps)[[int]$matches[1]];if($item){Add-ToRecent 'App' $item;Start-RecentEntry $item};return }
        '^hub-game:(\d+)$' {
            $index=[int]$matches[1]
            if($index -ge 0 -and $index -lt $script:GameHubLaunchEntries.Count){
                $item=$script:GameHubLaunchEntries[$index]
                $provider=[string](Get-EntryProperty $item 'Provider' '')
                $installed=[bool](Get-EntryProperty $item 'Installed' $true)
                if($provider -and -not $installed -and (Get-Command Get-ProviderGames -ErrorAction SilentlyContinue)){
                    $gameId=[string](Get-EntryProperty $item 'ProviderGameId' (Get-EntryProperty $item 'Id' ''))
                    $match=@(Get-ProviderGames $provider|Where-Object{[string](Get-EntryProperty $_ 'Id' '') -eq $gameId}|Select-Object -First 1)
                    if($match.Count -gt 0){$script:SelectedGamePlatform=$provider;$script:SelectedProviderGame=$match[0];$script:SubPage='ProviderGame';$script:SelectedAction=0;Render-Page;return}
                }
                Add-ToRecent 'Game' $item
                if((Get-Command Invoke-ProviderGameLaunchEntry -ErrorAction SilentlyContinue) -and (Invoke-ProviderGameLaunchEntry $item)){}else{Start-RecentEntry $item}
                Render-Page
            }
            return
        }
        '^platform-select:(\d+)$' {
            $index=[int]$matches[1]
            if($index -ge 0 -and $index -lt $script:GameHubPlatforms.Count){
                $script:SelectedGamePlatform=[string]$script:GameHubPlatforms[$index]
                # v0.25.2: platform selection is cache-only. Artwork updates only after an explicit rescan/provider refresh.
                $script:SubPage='PlatformChoice'
                $script:SelectedAction=0
                Render-Page
            }
            return
        }
        '^file-entry:(\d+)$' {
            $index=[int]$matches[1];if($index -lt 0 -or $index -ge $script:FileBrowserEntries.Count){return};$entry=$script:FileBrowserEntries[$index];$type=[string](Get-EntryProperty $entry 'Type')
            if($type -in @('Drive','Directory')){$script:FileBrowserPath=[string](Get-EntryProperty $entry 'FullName');$script:FileBrowserPage=0;$script:SelectedAction=0;Render-Page}
            elseif($script:FileBrowserMode -eq 'Browse'){Start-UriOrShellTarget ([string](Get-EntryProperty $entry 'FullName'))}
            else{Complete-NativeFileSelection $entry};return
        }
        '^remove-root:(\d+)$' {
            $index=[int]$matches[1];$roots=@($script:Config.StorefrontRoots)
            if($index -ge 0 -and $index -lt $roots.Count){$buffer=New-Object System.Collections.ArrayList;for($i=0;$i -lt $roots.Count;$i++){if($i -ne $index -and $null -ne $roots[$i]){[void]$buffer.Add($roots[$i])}};$script:Config.StorefrontRoots=[object[]]$buffer.ToArray();Save-Config;Start-LibraryScan;Render-Page};return
        }
    }
    if($Id -match '^driver-install-update:(.+)$'){
        $updateId=[string]$matches[1]
        if($updateId){Start-DriverWorker 'InstallUpdate' '' $updateId}
        return
    }
    switch ($Id) {
        'noop' { return }
        'platform-home' { $script:SubPage='PlatformHome';$script:SelectedAction=0;Render-Page }
        'platform-shelf' { $script:SubPage='PlatformShelf';$script:SelectedAction=0;Render-Page }
        'platform-library' { $script:SubPage='PlatformLibrary';$script:SelectedAction=0;Render-Page }
        'platform-store' { $script:SubPage='ProviderStore';$script:SelectedAction=0;Render-Page }
        'platform-steam-bigpicture' { Start-SteamBigPicture }
        'fse-home-settings' { $script:SubPage='FSEHome';$script:SelectedAction=0;Render-Page }
        'fse-register' { Start-FseRegistration $false }
        'fse-remove' { Start-FseRegistration $true }
        'fse-chooser' { Open-FseHomeChooser }
        'add-game' { Add-CustomEntry 'Game' }
        'add-app' { Add-CustomEntry 'App' }
        'launch-browser' { if(Get-Command Open-HuymaierBrowser -ErrorAction SilentlyContinue){Open-HuymaierBrowser 'https://www.google.com' 'Web'}elseif($script:Config.BrowserPath -and (Test-Path $script:Config.BrowserPath)){Start-ExternalProcess $script:Config.BrowserPath @(Get-BrowserArguments $script:Config.BrowserPath $script:Config.BrowserMode)}else{Set-Tab 7} }
        'choose-browser' { Cycle-Browser }
        'browser-mode' { Cycle-BrowserMode }
        'prompt-override' { Cycle-PromptOverride }
        'startup-toggle' { Set-StartWithWindows ( -not [bool]$script:Config.StartWithWindows); Render-Page }
        'controller-diagnostics' { $script:SubPage='Controllers';$script:SelectedAction=0;Render-Page }
        'controllers-refresh' { Render-Page }
        'controller-test-haptics' { Invoke-ControllerPulse 'Confirm' }
        'music-toggle' { Toggle-BackgroundMusic }
        'music-volume' { Cycle-MusicVolume }
        'music-volume-slider' { Adjust-SelectedSlider 5 }
        'music-theme' { Cycle-MusicTheme }
        'music-import' { Import-CustomMusic }
        'background-toggle' { Toggle-DynamicBackground }
        'ui-sounds-toggle' { Toggle-UiSounds }
        'haptics-toggle' { Toggle-Haptics }
        'keyboard-theme' { Cycle-KeyboardTheme }
        'keyboard-preview' { Show-NativeKeyboard -Title 'Keyboard preview' -InitialText 'Huymaier Console' -Mode 'Preview' -Context $null }
        'fps-toggle' { Toggle-FpsCounter }
        'online-artwork-toggle' { $script:Config.OnlineArtworkEnabled=-not [bool]$script:Config.OnlineArtworkEnabled;Save-Config;Render-Page }
        'artwork-refresh' { Start-OnlineArtworkScan -ResetCursor;Set-ConsoleNotice 'Missing box art is being refreshed in the background.' 'INFO';Render-Page }
        'platform-background-toggle' { $script:Config.PlatformBackgroundsEnabled=-not [bool]$script:Config.PlatformBackgroundsEnabled;Save-Config;Render-Page }
        'open-downloads' { $script:FileBrowserPath=Join-Path $env:USERPROFILE 'Downloads';$script:FileBrowserMode='Browse';Set-Tab 6 }
        'open-thispc' { $script:FileBrowserPath='';$script:FileBrowserMode='Browse';Set-Tab 6 }
        'open-userfolder' { $script:FileBrowserPath=$env:USERPROFILE;$script:FileBrowserMode='Browse';Set-Tab 6 }
        'file-root' { $script:FileBrowserPath='';$script:FileBrowserPage=0;$script:SelectedAction=0;Render-Page }
        'file-up' { $parent=Split-Path -Parent $script:FileBrowserPath;if($parent -and $parent -ne $script:FileBrowserPath){$script:FileBrowserPath=$parent}else{$script:FileBrowserPath=''};$script:FileBrowserPage=0;$script:SelectedAction=0;Render-Page }
        'file-page-prev' { $script:FileBrowserPage=[math]::Max(0,$script:FileBrowserPage-1);$script:SelectedAction=0;Render-Page }
        'file-page-next' { $script:FileBrowserPage++;$script:SelectedAction=0;Render-Page }
        'file-confirm-folder' { Complete-NativeFolderSelection }
        'file-new-folder' { Show-NativeKeyboard -Title 'Create folder' -InitialText 'New Folder' -Mode 'CreateFolder' -Context $null }
        'file-cancel' { Cancel-NativeFilePicker }
        'open-update-panel' { $script:SubPage='Updates';$script:SelectedAction=0;Read-UpdateState;Render-Page }
        'driver-settings' { $script:SubPage='Drivers';$script:SelectedAction=0;Read-DriverState;Render-Page }
        'driver-scan' { Start-DriverWorker 'Scan' }
        'driver-install-updates' { Start-DriverWorker 'InstallUpdates' }
        'driver-install-package' { Open-DriverPackagePicker }
        'driver-reset' { Remove-Item $script:DriverStatePath -Force -ErrorAction SilentlyContinue;$script:DriverState=New-DefaultDriverState;$script:DriverStateSignature='';Render-Page }
        'driver-restart' { Request-NativeConfirmation 'update-restart' 'Restart Windows now to finish installing drivers?' }
        'update-scan' { Start-UpdateWorker 'Scan' }
        'update-install' { Start-UpdateWorker 'Install' }
        'update-reset' { Remove-Item $script:UpdateStatePath -Force -ErrorAction SilentlyContinue;$script:UpdateState=New-DefaultUpdateState;$script:UpdateStateSignature='';Render-Page }
        'update-restart' { Request-NativeConfirmation 'update-restart' 'Restart Windows now to finish installing updates?' }
        'open-display-panel' { try{$script:SubPage='Display';$script:SelectedAction=0;Write-Log 'Opening native Display & HDR page.';Refresh-DisplayState;Render-Page}catch{$script:SubPage='';Write-Log "Display & HDR page failed: $($_.Exception.Message)" 'ERROR';Render-Page} }
        'display-target' { Cycle-DisplayTarget }
        'display-resolution' { Cycle-DisplayResolution }
        'display-refresh' { Cycle-DisplayRefreshRate }
        'display-apply' { Apply-PendingDisplayMode }
        'display-keep' { Keep-DisplayMode }
        'display-revert' { Revert-DisplayMode }
        'display-hdr' { Toggle-DisplayHdr }
        'display-scale' { if(Get-Command Show-HcChoicePopup -ErrorAction SilentlyContinue){$scale=Get-WindowsConfiguredDisplayScalePercent;Show-HcChoicePopup 'Windows display scale' @('100%','125%','150%','175%','200%','225%','250%','300%','350%','400%','450%','500%') "$scale%" 'DisplayScale'}else{Set-ConsoleNotice 'Display scale chooser is unavailable.' 'ERROR'} }
        'display-scale-signout' { Request-NativeConfirmation 'display-scale-signout' 'Sign out of Windows now to apply the new display scale?' }
        'subpage-back' { Handle-Back }
        'sound-settings' { $script:SubPage='Audio';$script:SelectedAction=0;Refresh-AudioState;Render-Page }
        'audio-output' { Cycle-AudioOutput }
        'audio-up' { Adjust-AudioVolume 5 }
        'audio-down' { Adjust-AudioVolume -5 }
        'audio-volume-slider' { Adjust-SelectedSlider 5 }
        'audio-mute' { Toggle-AudioMute }
        'bluetooth-settings' { $script:SubPage='Devices';$script:SelectedAction=0;Refresh-DeviceState;Render-Page }
        'devices-refresh' { Refresh-DeviceState;Render-Page }
        'devices-add' { Start-UriOrShellTarget 'ms-settings:bluetooth' }
        'scan-libraries' { Start-LibraryScan }
        'add-steam-root' { Add-StorefrontLocation 'Steam' }
        'add-epic-root' { Add-StorefrontLocation 'Epic' }
        'add-gog-root' { Add-StorefrontLocation 'GOG' }
        'add-ea-root' { Add-StorefrontLocation 'EA' }
        'add-ubisoft-root' { Add-StorefrontLocation 'Ubisoft' }
        'add-xbox-root' { Add-StorefrontLocation 'Xbox' }
        'add-battlenet-root' { Add-StorefrontLocation 'Battle.net' }
        'add-rockstar-root' { Add-StorefrontLocation 'Rockstar' }
        'add-amazon-root' { Add-StorefrontLocation 'Amazon' }
        'add-generic-root' { Add-StorefrontLocation 'Generic' }
        'confirm-yes' { Complete-NativeConfirmation $true }
        'confirm-no' { Complete-NativeConfirmation $false }
        'restart-shell' { $script:AllowWindowClose=$true;$launcher=Join-Path $script:BaseDir 'Launch-HuymaierConsole.cmd';Start-Process $launcher|Out-Null;$script:Window.Close() }
        'sleep' { Request-NativeConfirmation 'sleep' 'Put this PC to sleep now?' }
        'restart-pc' { Request-NativeConfirmation 'restart-pc' 'Restart this PC now?' }
        'shutdown-pc' { Request-NativeConfirmation 'shutdown-pc' 'Shut down this PC now?' }
        'exit-console' { $script:AllowWindowClose=$true;$script:Window.Close() }
    }
}

function New-Action {
    param([string]$Id, [string]$Title, [string]$Description = '', [string]$Kind = 'Action', [int]$Value = 0)
    [pscustomobject]@{ Id=$Id; Title=$Title; Description=$Description; Kind=$Kind; Value=$Value }
}

function New-SliderAction {
    param([string]$Id,[string]$Title,[int]$Value,[string]$Description='Use Left/Right to adjust.')
    New-Action $Id $Title $Description 'Slider' ([math]::Max(0,[math]::Min(100,$Value)))
}

function Get-PageDefinition {
    param([int]$Index)
    if(Get-Command Get-GameProviderPageDefinition -ErrorAction SilentlyContinue){$providerPage=Get-GameProviderPageDefinition;if($null -ne $providerPage){return $providerPage}}
    if($script:SubPage -eq 'FilePicker'){return Get-NativeFilePage}
    if($script:SubPage -eq 'Confirm'){
        $question=if($script:PendingConfirmation){[string]$script:PendingConfirmation.Question}else{'Continue?'}
        return [pscustomobject]@{Title='Confirm action';Subtitle='This action affects the Windows system.';Hero='ARE YOU SURE?';HeroText=$question;Actions=@((New-Action 'confirm-yes' 'Yes, continue'),(New-Action 'confirm-no' 'No, go back'))}
    }
    switch ($Index) {
        0 { return [pscustomobject]@{Title='Home';Subtitle='';Hero='';HeroText='';Actions=@()} }
        1 {
            $all=Get-AllGameHubEntries
            return [pscustomobject]@{Title='Games';Subtitle="$($all.Count) non-Steam title(s) across platform libraries.";Hero='PLATFORM LIBRARY';HeroText='Select a platform, then browse Recently Played and Random Picks from left to right.';Actions=@()}
        }
        2 {
            if($script:SubPage -like 'Storefront:*'){
                $storeId=[string]$script:SubPage.Substring('Storefront:'.Length)
                $item=Get-StorefrontCatalogItem $storeId
                if($null -eq $item){$script:SubPage='';return [pscustomobject]@{Title='Apps';Subtitle='Storefront management.';Hero='STOREFRONT';HeroText='The selected storefront is unavailable.';Actions=@((New-Action 'subpage-back' 'Back to Apps'))}}
                $actions=New-Object System.Collections.Generic.List[object]
                if([bool]$item.Installed){
                    $actions.Add((New-Action "storefront-open:$storeId" "Open $($item.Name)" ([string]$item.Path)))
                    $actions.Add((New-Action "storefront-uninstall:$storeId" "Uninstall $($item.Name)" 'Uses the registered Windows package or vendor uninstaller.'))
                }else{
                    $actions.Add((New-Action "storefront-install:$storeId" "Install $($item.Name)" 'Downloads only from the official publisher source or Microsoft WinGet.'))
                }
                $actions.Add((New-Action 'subpage-back' 'Back to Apps'))
                return [pscustomobject]@{
                    Title=[string]$item.Name
                    Subtitle='Storefront management inside Huymaier Console.'
                    Hero=$(if([bool]$item.Installed){'INSTALLED'}else{'NOT INSTALLED'})
                    HeroText=$(if([bool]$item.Installed){"Ready to open.`n$([string]$item.Path)"}else{'Install from the official storefront source.'})
                    Actions=([object[]]$actions.ToArray())
                }
            }
            return [pscustomobject]@{Title='Apps';Subtitle='Storefronts and couch-friendly Windows applications.';Hero='APPLICATION HUB';HeroText='Select a storefront to open it. Press X or Square to install or manage it.';Actions=@()}
        }
        3 { return [pscustomobject]@{Title='Web';Subtitle='Native controller browser with persistent sessions and the full Huymaier keyboard.';Hero='HUYMAIER WEB';HeroText='Browse, sign in, and manage integrations without leaving the console.';Actions=@((New-Action 'launch-browser' 'Open native browser' 'Controller-ready WebView2 browser'),(New-Action 'keyboard-preview' 'Full keyboard preview' 'Letters, numbers, punctuation, symbols, and URL keys'),(New-Action 'choose-browser' 'External browser fallback' $script:Config.BrowserName))} }
        4 {
            if($script:SubPage -eq 'Updates'){
                Read-UpdateState;$state=$script:UpdateState;$actions=New-Object System.Collections.Generic.List[object]
                if( -not [bool]$state.Busy){$actions.Add((New-Action 'update-scan' 'Scan for updates'));if([int]$state.UpdateCount -gt 0){$actions.Add((New-Action 'update-install' "Install $($state.UpdateCount) update(s)"))};if([bool]$state.RebootRequired){$actions.Add((New-Action 'update-restart' 'Restart to finish updates'))};if($state.Error -or [int]$state.ResultCode -lt 0){$actions.Add((New-Action 'update-reset' 'Clear update error'))}}else{$actions.Add((New-Action 'noop' "$($state.Phase)..." 'Windows Update is working in the background.'))}
                $actions.Add((New-Action 'subpage-back' 'Back to Downloads'))
                return [pscustomobject]@{Title='Windows Update';Subtitle='Scan and install without opening Windows Settings.';Hero=$(if([bool]$state.Busy){[string]$state.Phase}elseif([bool]$state.RebootRequired){'RESTART REQUIRED'}elseif([int]$state.UpdateCount -gt 0){"$($state.UpdateCount) UPDATE(S) READY"}else{'WINDOWS UPDATE'});HeroText=(Get-UpdateHeroText);Actions=([object[]]$actions.ToArray())}
            }
            $downloadActions=New-Object System.Collections.Generic.List[object];foreach($providerAction in @(Get-ProviderDownloadPageActions)){if($null -ne $providerAction){$downloadActions.Add($providerAction)}};$downloadActions.Add((New-Action 'open-downloads' 'Browse Downloads' (Join-Path $env:USERPROFILE 'Downloads')));$downloadActions.Add((New-Action 'open-update-panel' 'Windows Update' 'Scan, install, and restart inside Huymaier Console.'));$providerState=Read-GameProviderState;$providerBusy=$providerState -and [bool](Get-EntryProperty $providerState 'Busy' $false);return [pscustomobject]@{Title='Downloads';Subtitle='Game installs, provider jobs, and Windows maintenance.';Hero=$(if($providerBusy){[string](Get-EntryProperty $providerState 'Phase' 'WORKING').ToUpperInvariant()}else{'DOWNLOAD CENTER'});HeroText=$(if($providerBusy){[string](Get-EntryProperty $providerState 'Message' 'Provider operation in progress.')}else{'Native provider downloads and Windows maintenance appear here.'});Actions=([object[]]$downloadActions.ToArray())}
        }
        5 {
            Read-LibraryState;$actions=New-Object System.Collections.Generic.List[object];$state=$script:LibraryState
            if($state -and [bool]$state.Busy){$actions.Add((New-Action 'noop' "$($state.Phase)..." ([string]$state.Message)))}else{$actions.Add((New-Action 'scan-libraries' 'Scan all installed libraries' 'Runs in a background worker so controller navigation remains responsive.'))}
            $actions.Add((New-Action 'add-steam-root' 'Add Steam location'));$actions.Add((New-Action 'add-epic-root' 'Add Epic location'));$actions.Add((New-Action 'add-gog-root' 'Add GOG location'));$actions.Add((New-Action 'add-ea-root' 'Add EA location'));$actions.Add((New-Action 'add-ubisoft-root' 'Add Ubisoft location'));$actions.Add((New-Action 'add-xbox-root' 'Add Xbox location'));$actions.Add((New-Action 'add-battlenet-root' 'Add Battle.net location'));$actions.Add((New-Action 'add-rockstar-root' 'Add Rockstar location'));$actions.Add((New-Action 'add-amazon-root' 'Add Amazon Games location'));$actions.Add((New-Action 'add-generic-root' 'Add other game location'));$actions.Add((New-Action 'add-game' 'Add individual game'));$actions.Add((New-Action 'add-app' 'Add Windows application'))
            $roots=@($script:Config.StorefrontRoots);for($i=0;$i -lt $roots.Count;$i++){if($null -ne $roots[$i]){$actions.Add((New-Action "remove-root:$i" "Remove: $(Get-EntryProperty $roots[$i] 'Store' 'Library')" ([string](Get-EntryProperty $roots[$i] 'Path' ''))))}}
            $count=@($script:Config.ImportedGames).Count;$status=if($state){[string]$state.Message}else{'Ready'}
            return [pscustomobject]@{Title='Library Import';Subtitle='Automatic storefront discovery and multiple locations per service.';Hero=$(if($state -and [bool]$state.Busy){'SCANNING'}else{"$count GAMES FOUND"});HeroText="$status`nConfigured locations: $($roots.Count)";Actions=([object[]]$actions.ToArray())}
        }
        6 { $script:FileBrowserMode='Browse';return Get-NativeFilePage }
        7 {
            if($script:SubPage -eq 'Display'){
                Refresh-DisplayState;$display=Get-SelectedDisplay;if($null -eq $display){return [pscustomobject]@{Title='Display & HDR';Subtitle='Native display controls are unavailable.';Hero='NO ACTIVE DISPLAY';HeroText='No active display was returned.';Actions=@((New-Action 'subpage-back' 'Back to Settings'))}}
                $hdr=Get-DisplayHdrStatus;$hdrLabel=if($null -eq $hdr -or -not $hdr.Supported){'Unsupported'}elseif($hdr.Enabled){'On'}else{'Off'};$actions=New-Object System.Collections.Generic.List[object]
                if($script:DisplayPendingConfirmation){$seconds=[math]::Max(0,[math]::Ceiling(($script:DisplayConfirmUntil-(Get-Date)).TotalSeconds));$actions.Add((New-Action 'display-keep' "Keep this display mode ($seconds)"));$actions.Add((New-Action 'display-revert' 'Revert display mode'))}else{$actions.Add((New-Action 'display-target' "Display: $($display.FriendlyName)"));$actions.Add((New-Action 'display-resolution' "Resolution: $($script:PendingWidth) x $($script:PendingHeight)"));$actions.Add((New-Action 'display-refresh' "Refresh rate: $($script:PendingFrequency) Hz"));$effectiveScale=Get-WindowsEffectiveDisplayScalePercent;$configuredScale=Get-WindowsConfiguredDisplayScalePercent;$scaleLabel=$(if($effectiveScale -ne $configuredScale){"Scale: $effectiveScale% → $configuredScale% after sign out"}else{"Scale: $effectiveScale%"});$actions.Add((New-Action 'display-scale' $scaleLabel 'Change the native Windows account display scale.'));if($effectiveScale -ne $configuredScale){$actions.Add((New-Action 'display-scale-signout' 'Sign out to apply display scale' "Windows is currently using $effectiveScale%; $configuredScale% is configured."))};$actions.Add((New-Action 'display-apply' 'Apply display mode' '15-second automatic rollback.'));$actions.Add((New-Action 'display-hdr' "HDR: $hdrLabel"))};$actions.Add((New-Action 'subpage-back' 'Back to Settings'))
                return [pscustomobject]@{Title='Display & HDR';Subtitle='Native resolution, refresh rate, Windows scale, and HDR controls.';Hero=$display.FriendlyName.ToUpperInvariant();HeroText="Current: $($display.Width) x $($display.Height) at $($display.Frequency) Hz`nHDR: $hdrLabel";Actions=([object[]]$actions.ToArray())}
            }
            if($script:SubPage -eq 'Drivers'){
                Read-DriverState
                $state=$script:DriverState
                $busy=[bool](Get-EntryProperty $state 'Busy' $false)
                $updateCount=[int](Get-EntryProperty $state 'UpdateCount' 0)
                $driverCount=[int](Get-EntryProperty $state 'DriverCount' 0)
                $gpus=@(Get-EntryProperty $state 'DisplayDrivers' @())
                $actions=New-Object System.Collections.Generic.List[object]
                if($busy){
                    $actions.Add((New-Action 'noop' "$([string](Get-EntryProperty $state 'Phase' 'Working'))..." 'Driver management is working in the background.'))
                }else{
                    $actions.Add((New-Action 'driver-scan' 'Scan for driver updates' 'Detect installed signed drivers and check the Windows Update driver channel.'))
                    if($updateCount -gt 0){$actions.Add((New-Action 'driver-install-updates' "Install $updateCount recommended driver update(s)" 'Uses Windows Update Agent and requires administrator approval.'))}
                    $actions.Add((New-Action 'driver-install-package' 'Install local driver package' 'Choose a folder containing signed .inf packages; subfolders are included.'))
                    if([bool](Get-EntryProperty $state 'RebootRequired' $false)){$actions.Add((New-Action 'driver-restart' 'Restart to finish driver installation'))}
                    if([string](Get-EntryProperty $state 'Error' '')){$actions.Add((New-Action 'driver-reset' 'Clear driver error'))}
                }
                foreach($gpu in ($gpus|Select-Object -First 4)){
                    $name=[string](Get-EntryProperty $gpu 'DeviceName' 'Graphics adapter')
                    $version=[string](Get-EntryProperty $gpu 'Version' '')
                    $provider=[string](Get-EntryProperty $gpu 'Provider' '')
                    $date=[string](Get-EntryProperty $gpu 'DriverDate' '')
                    $actions.Add((New-Action 'noop' $name "$provider  |  Driver $version$(if($date){'  |  '+$date}else{''})"))
                }
                foreach($update in (@(Get-EntryProperty $state 'Updates' @())|Select-Object -First 8)){
                    $title=[string](Get-EntryProperty $update 'Title' 'Driver update')
                    $manufacturer=[string](Get-EntryProperty $update 'Manufacturer' '')
                    $version=[string](Get-EntryProperty $update 'Version' '')
                    $details=@($manufacturer,$version)|Where-Object{$_}
                    $updateId=[string](Get-EntryProperty $update 'UpdateId' '');$actions.Add((New-Action $(if($updateId){"driver-install-update:$updateId"}else{'noop'}) "UPDATE  $title" ($(if($details.Count -gt 0){($details -join '  |  ')+'  |  Select to install only this driver.'}else{'Select to install only this driver.'}))))
                }
                $actions.Add((New-Action 'subpage-back' 'Back to Settings'))
                $hero=if($busy){[string](Get-EntryProperty $state 'Phase' 'WORKING').ToUpperInvariant()}elseif($updateCount -gt 0){"$updateCount DRIVER UPDATE(S)"}elseif($gpus.Count -gt 0){'GRAPHICS & DRIVERS'}else{'DRIVER MANAGER'}
                return [pscustomobject]@{Title='Drivers & Hardware';Subtitle='Native graphics and device-driver maintenance without leaving Huymaier Console.';Hero=$hero;HeroText=(Get-DriverHeroText);Actions=([object[]]$actions.ToArray())}
            }
            if($script:SubPage -eq 'Controllers'){$snap=Get-ControllerSnapshot;$actions=New-Object System.Collections.Generic.List[object];$actions.Add((New-Action 'controllers-refresh' 'Refresh connected gamepads' "$($snap.Gamepads.Count) gamepad(s), $($snap.Raw.Count) raw controller(s), $($snap.Hid.Count) HID controller(s), $($snap.Legacy.Count) DirectInput controller(s)."));$actions.Add((New-Action 'controller-test-haptics' 'Test controller haptics'));$actions.Add((New-Action 'prompt-override' "Button prompts: $($script:Config.PromptOverride)"));for($i=0;$i -lt $snap.Hid.Count;$i++){$hid=$snap.Hid[$i];$name='PlayStation Controller';try{$name=[string]$hid.Name}catch{};$actions.Add((New-Action 'noop' $name "PlayStation via $([string]$hid.Connection)"))};for($i=0;$i -lt $snap.Raw.Count;$i++){$raw=$snap.Raw[$i];$name='Game Controller';try{$name=[string]$raw.DisplayName}catch{};$actions.Add((New-Action 'noop' $name (Get-FamilyFromRawController $raw)))};for($i=0;$i -lt $snap.Legacy.Count;$i++){$legacy=$snap.Legacy[$i];$name='DirectInput Controller';try{$name=[string]$legacy.Name}catch{};$actions.Add((New-Action 'noop' $name "$(Get-FamilyFromLegacyController $legacy) via Bluetooth/DirectInput"))};$actions.Add((New-Action 'subpage-back' 'Back to Settings'));return [pscustomobject]@{Title='Controllers';Subtitle='Connected gamepads inside Huymaier Console.';Hero='GAMEPAD HUB';HeroText="$($snap.Raw.Count + $snap.Hid.Count + $snap.Legacy.Count) physical input path(s) detected.`n$($snap.HidDiagnostics)";Actions=([object[]]$actions.ToArray())}}
            if($script:SubPage -eq 'Audio'){Refresh-AudioState;$volume=Get-AudioVolume;$mute=Get-AudioMute;$default=if($script:AudioEndpoints.Count -gt 0){$script:AudioEndpoints[$script:AudioIndex].Name}else{'No output detected'};return [pscustomobject]@{Title='Audio';Subtitle='Native master volume, mute, and output controls.';Hero=$default.ToUpperInvariant();HeroText="Master volume: $volume%`nMuted: $(if($mute){'Yes'}else{'No'})`nOutputs: $($script:AudioEndpoints.Count)";Actions=@((New-Action 'audio-output' "Output: $default"),(New-SliderAction 'audio-volume-slider' 'Master volume' $volume 'Use Left/Right to adjust.'),(New-Action 'audio-mute' $(if($mute){'Unmute audio'}else{'Mute audio'})),(New-Action 'subpage-back' 'Back to Settings'))}}
            if($script:SubPage -eq 'Devices'){if((Get-Date)-$script:DeviceRefreshAt -gt [TimeSpan]::FromSeconds(10)){Refresh-DeviceState};$actions=New-Object System.Collections.Generic.List[object];$actions.Add((New-Action 'devices-refresh' 'Refresh devices' "$($script:BluetoothDevices.Count) device(s)."));$actions.Add((New-Action 'devices-add' 'Pair Bluetooth device' 'Windows owns the secure pairing surface; device status remains here.'));foreach($device in (@($script:BluetoothDevices)|Select-Object -First 30)){$actions.Add((New-Action 'noop' $device.Name "$($device.Class)  |  $($device.Status)"))};$actions.Add((New-Action 'subpage-back' 'Back to Settings'));return [pscustomobject]@{Title='Bluetooth & Devices';Subtitle='Connected controllers, audio, Bluetooth, keyboards, and mice.';Hero='DEVICE HUB';HeroText="$($script:BluetoothDevices.Count) device(s) shown natively.";Actions=([object[]]$actions.ToArray())}}
            if($script:SubPage -eq 'FSEHome'){$status=Get-FseHomeStatus;$actions=New-Object System.Collections.Generic.List[object];if($status.Registered){$actions.Add((New-Action 'fse-chooser' 'Choose Huymaier Console as home app' 'Opens the Windows Xbox Mode home-app chooser.'));$actions.Add((New-Action 'fse-remove' 'Remove Xbox Mode home-app registration'))}else{$actions.Add((New-Action 'fse-register' 'Register Huymaier Console as a home app' 'Requires administrator approval and Windows Developer Mode.'))};$actions.Add((New-Action 'subpage-back' 'Back to Settings'));return [pscustomobject]@{Title='Xbox Mode / FSE Home';Subtitle='Make Huymaier Console selectable alongside Xbox on supported Windows 11 builds.';Hero=$(if($status.Registered){'REGISTERED'}else{'NOT REGISTERED'});HeroText=$(if($status.Registered){'Huymaier Console is installed as a supported gaming home-app candidate. Use Choose home app in Windows Xbox Mode settings to select it.'}else{'Register the optional package identity, then select Huymaier Console under Settings > Gaming > Xbox mode > Choose home app.'});Actions=([object[]]$actions.ToArray())}}
            $browserLabel=if($script:Config.BrowserName){$script:Config.BrowserName}else{'No browser detected'}
            return [pscustomobject]@{Title='Settings';Subtitle='Personalize and manage the console.';Hero='SYSTEM SETTINGS';HeroText="Prompts: $($script:Config.PromptOverride)  |  Browser: $browserLabel";Actions=@((New-Action 'fse-home-settings' 'Xbox Mode / FSE Home' 'Choose Huymaier Console alongside Xbox on supported Windows 11 builds.'),(New-Action 'open-display-panel' 'Display & HDR'),(New-Action 'driver-settings' 'Drivers & Hardware' 'Graphics, chipset, audio, network, and other signed device drivers.'),(New-Action 'sound-settings' 'Audio'),(New-Action 'bluetooth-settings' 'Bluetooth & Devices'),(New-Action 'controller-diagnostics' 'Controllers'),(New-Action 'choose-browser' "Browser: $browserLabel"),(New-Action 'browser-mode' "Browser launch: $($script:Config.BrowserMode)"),(New-Action 'prompt-override' "Button prompts: $($script:Config.PromptOverride)"),(New-Action 'background-toggle' $(if($script:Config.DynamicBackground){'Dynamic background: On'}else{'Dynamic background: Off'})),(New-Action 'music-toggle' $(if($script:Config.MusicEnabled){'Console music: On'}else{'Console music: Off'})),(New-Action 'music-theme' "Music theme: $($script:Config.MusicTheme)"),(New-Action 'music-import' 'Import background music'),(New-SliderAction 'music-volume-slider' 'Music volume' ([int]$script:Config.MusicVolume) 'Use Left/Right to adjust.'),(New-Action 'ui-sounds-toggle' $(if($script:Config.UiSoundsEnabled){'Interface sounds: On'}else{'Interface sounds: Off'})),(New-Action 'haptics-toggle' $(if($script:Config.HapticsEnabled){'Controller haptics: On'}else{'Controller haptics: Off'})),(New-Action 'keyboard-theme' "Keyboard theme: $($script:Config.KeyboardTheme)"),(New-Action 'keyboard-preview' 'Preview native keyboard'),(New-Action 'fps-toggle' $(if($script:Config.ShowFpsCounter){'Performance counter: On'}else{'Performance counter: Off'}) 'Shows the live rendering FPS in the top-right corner.'),(New-Action 'platform-background-toggle' $(if($script:Config.PlatformBackgroundsEnabled){'Platform backgrounds: On'}else{'Platform backgrounds: Off'})),(New-Action 'online-artwork-toggle' $(if($script:Config.OnlineArtworkEnabled){'Online box art: On'}else{'Online box art: Off'})),(New-Action 'artwork-refresh' 'Refresh missing box art'),(New-Action 'startup-toggle' $(if($script:Config.StartWithWindows){'Start with Windows: On'}else{'Start with Windows: Off'})))}
        }
        8 { return [pscustomobject]@{Title='Power';Subtitle='System and recovery controls.';Hero='POWER & RECOVERY';HeroText='Power confirmations stay inside Huymaier Console.';Actions=@((New-Action 'restart-shell' 'Restart Huymaier Console'),(New-Action 'sleep' 'Sleep'),(New-Action 'restart-pc' 'Restart PC'),(New-Action 'shutdown-pc' 'Shut down PC'),(New-Action 'exit-console' 'Exit to Windows'))} }
    }
}

function Get-FseHomeStatus {
    $registered=$false
    $package=$null
    try{$package=Get-AppxPackage -Name $script:FsePackageName -ErrorAction SilentlyContinue|Select-Object -First 1;if($null -ne $package){$registered=$true}}catch{}
    return [pscustomobject]@{Registered=$registered;Package=$package}
}

function Start-FseRegistration {
    param([bool]$Remove)
    if(-not (Test-Path -LiteralPath $script:FseRegisterScript)){
        Set-ConsoleNotice 'The Xbox Mode home-app registration helper is missing.' 'ERROR'
        Render-Page
        return
    }
    try{
        $args=@('-NoLogo','-NoProfile','-ExecutionPolicy','Bypass','-File',('"'+$script:FseRegisterScript+'"'))
        if($Remove){$args+=('-Remove')}
        $process=Start-Process "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -Verb RunAs -ArgumentList $args -Wait -PassThru
        if($null -eq $process){
            Set-ConsoleNotice 'Windows did not start the Xbox Mode registration helper.' 'ERROR'
        }elseif([int]$process.ExitCode -eq 0){
            if($Remove){Set-ConsoleNotice 'Huymaier Console was removed from the Xbox Mode home-app candidates.' 'INFO'}
            else{Set-ConsoleNotice 'Huymaier Console was registered as an Xbox Mode home-app candidate.' 'INFO'}
        }else{
            Set-ConsoleNotice "Xbox Mode registration failed with exit code $($process.ExitCode). The detailed error was written to the Huymaier Console log." 'ERROR'
        }
        Render-Page
    }catch{
        Set-ConsoleNotice "Xbox Mode registration did not complete: $($_.Exception.Message)" 'ERROR'
        Render-Page
    }
}

function Open-FseHomeChooser {
    try{Start-Process 'ms-settings:gaming-xboxmode'|Out-Null}
    catch{try{Start-Process 'ms-settings:gaming'|Out-Null}catch{Set-ConsoleNotice 'Unable to open the Windows Gaming settings chooser.' 'ERROR';Render-Page}}
}

function Set-Tab {
    param([int]$Index)
    if ($Index -lt 0) { $Index = $script:NavItems.Count - 1 }
    if ($Index -ge $script:NavItems.Count) { $Index = 0 }
    $script:SelectedTab = $Index
    $script:SubPage = ''
    $script:SelectedAction = 0
    $script:PreferredRailColumn = 0
    Render-Page
    Update-NavVisuals
}

function Focus-TopNavigation {
    if((Get-Command Show-HcMainMenu -ErrorAction SilentlyContinue) -and $null -ne $script:MainMenuOverlay){
        if(-not (Test-HcMainMenuVisible)){Show-HcMainMenu}
        return
    }
    if($script:NavigationLayer -ne 'Navigation'){$script:NavigationReturnAction=$script:SelectedAction}
    $script:NavigationLayer='Navigation'
    Update-NavVisuals
    Update-ActionVisuals
    Update-Footer
}

function Enter-ContentNavigation {
    $script:NavigationLayer='Content'
    if($script:ActionButtons.Count -gt 0){$script:SelectedAction=[math]::Max(0,[math]::Min($script:ActionButtons.Count-1,$script:NavigationReturnAction))}
    Update-NavVisuals
    Update-ActionVisuals
    Update-Footer
}

function Update-NavVisuals {
    for ($i=0; $i -lt $script:NavButtons.Count; $i++) {
        $button = $script:NavButtons[$i]
        if ($i -eq $script:SelectedTab) {
            $button.Background = '#D9B94F'
            $button.Foreground = '#08101D'
            $button.BorderBrush = $(if($script:NavigationLayer -eq 'Navigation'){'#FFFFFF'}else{'#FFE081'})
            $button.BorderThickness = $(if($script:NavigationLayer -eq 'Navigation'){'3'}else{'1'})
            try { $button.Content.Tag.Stroke = '#101722' } catch { }
        } else {
            $button.Background = '#151D2B'
            $button.Foreground = '#EAF0F8'
            $button.BorderBrush = '#31425D'
            $button.BorderThickness = '1'
            try { $button.Content.Tag.Stroke = '#EEF3FA' } catch { }
        }
    }
}


function Get-AncestorScrollViewer {
    param($Element,[switch]$Horizontal)
    try{
        $node=$Element
        while($null -ne $node){
            $node=[System.Windows.Media.VisualTreeHelper]::GetParent($node)
            if($node -is [System.Windows.Controls.ScrollViewer]){
                if($Horizontal){
                    if($node.HorizontalScrollBarVisibility -ne [System.Windows.Controls.ScrollBarVisibility]::Disabled){return $node}
                }else{
                    if($node.VerticalScrollBarVisibility -ne [System.Windows.Controls.ScrollBarVisibility]::Disabled){return $node}
                }
            }
        }
    }catch{}
    return $null
}

function Ensure-SelectedActionVisible {
    if($script:NavigationLayer -ne 'Content' -or $script:ActionButtons.Count -eq 0){return}
    if($script:SelectedAction -lt 0 -or $script:SelectedAction -ge $script:ActionButtons.Count){return}
    $button=$script:ActionButtons[$script:SelectedAction]
    try{
        $horizontal=Get-AncestorScrollViewer $button -Horizontal
        if($null -ne $horizontal -and $horizontal -ne $script:ActionScrollViewer -and $horizontal.ViewportWidth -gt 0){
            $point=$button.TransformToAncestor($horizontal).Transform((New-Object System.Windows.Point 0,0))
            $left=[double]$point.X;$right=$left+[double]$button.ActualWidth;$padding=18.0
            if($left -lt $padding){$horizontal.ScrollToHorizontalOffset([math]::Max(0,$horizontal.HorizontalOffset+$left-$padding))}
            elseif($right -gt ($horizontal.ViewportWidth-$padding)){$horizontal.ScrollToHorizontalOffset([math]::Max(0,$horizontal.HorizontalOffset+$right-$horizontal.ViewportWidth+$padding))}
        }
    }catch{}
    try{
        if($null -ne $script:ActionScrollViewer -and $script:ActionScrollViewer.ViewportHeight -gt 0){
            $point=$button.TransformToAncestor($script:ActionScrollViewer).Transform((New-Object System.Windows.Point 0,0))
            $top=[double]$point.Y;$bottom=$top+[double]$button.ActualHeight;$padding=18.0
            if($top -lt $padding){$script:ActionScrollViewer.ScrollToVerticalOffset([math]::Max(0,$script:ActionScrollViewer.VerticalOffset+$top-$padding))}
            elseif($bottom -gt ($script:ActionScrollViewer.ViewportHeight-$padding)){$script:ActionScrollViewer.ScrollToVerticalOffset([math]::Max(0,$script:ActionScrollViewer.VerticalOffset+$bottom-$script:ActionScrollViewer.ViewportHeight+$padding))}
        }
    }catch{}
}

function Update-ActionVisuals {
    if($script:ActionButtons.Count -eq 0){return}
    $script:SelectedAction=[math]::Max(0,[math]::Min($script:ActionButtons.Count-1,$script:SelectedAction))
    for($i=0;$i -lt $script:ActionButtons.Count;$i++){
        $button=$script:ActionButtons[$i]
        if($i -eq $script:SelectedAction -and $script:NavigationLayer -eq 'Content'){$button.BorderBrush='#F2D36B';$button.BorderThickness='3';$button.Opacity=1.0;try{$scale=if($script:SubPage -eq 'PlatformShelf'){1.065}else{1.025};$button.RenderTransform=(New-Object System.Windows.Media.ScaleTransform -ArgumentList $scale,$scale)}catch{}}
        else{$button.BorderBrush='#33445E';$button.BorderThickness='1';$button.Opacity=$(if($script:SubPage -eq 'PlatformShelf'){0.46}else{0.88});try{$button.RenderTransform=(New-Object System.Windows.Media.ScaleTransform -ArgumentList 1.0,1.0)}catch{}}
    }
    if($script:NavigationLayer -eq 'Content'){
        Ensure-SelectedActionVisible
        if($script:SubPage -eq 'PlatformShelf'){Update-ShelfSelection}
    }
}

function Get-ExecutableIconSource {
    param($Path)
    if ($Path -is [System.Array]) { $Path = @($Path | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) } | Select-Object -First 1) }
    $Path = [string]$Path
    if ( -not $Path -or -not (Test-Path $Path) -or [IO.Path]::GetExtension($Path) -ne '.exe') { return $null }
    try{
        Add-Type -AssemblyName System.Drawing -ErrorAction SilentlyContinue
        $icon=[System.Drawing.Icon]::ExtractAssociatedIcon($Path)
        if($null -eq $icon){return $null}
        $source=[System.Windows.Interop.Imaging]::CreateBitmapSourceFromHIcon($icon.Handle,[System.Windows.Int32Rect]::Empty,[System.Windows.Media.Imaging.BitmapSizeOptions]::FromWidthAndHeight(128,128))
        $source.Freeze();$icon.Dispose();return $source
    }catch{return $null}
}


function Get-ImageSourceFromPath {
    param([string]$Path,[int]$DecodeWidth=0)
    if([string]::IsNullOrWhiteSpace($Path) -or -not (Test-Path -LiteralPath $Path -PathType Leaf)){return $null}
    try{
        $item=Get-Item -LiteralPath $Path -ErrorAction Stop
        $key=([string]$item.FullName).ToLowerInvariant()+'|'+$item.LastWriteTimeUtc.Ticks+'|'+$DecodeWidth
        if($script:ImageSourceCache.ContainsKey($key)){return $script:ImageSourceCache[$key]}
        $bitmap=New-Object System.Windows.Media.Imaging.BitmapImage
        $bitmap.BeginInit()
        $bitmap.CacheOption=[System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad
        $bitmap.CreateOptions=([System.Windows.Media.Imaging.BitmapCreateOptions]::PreservePixelFormat -bor [System.Windows.Media.Imaging.BitmapCreateOptions]::IgnoreImageCache)
        if($DecodeWidth -gt 0){$bitmap.DecodePixelWidth=$DecodeWidth}
        $bitmap.UriSource=[uri]$item.FullName
        $bitmap.EndInit();$bitmap.Freeze()
        $script:ImageSourceCache[$key]=$bitmap
        [void]$script:ImageSourceCacheOrder.Add($key)
        while($script:ImageSourceCacheOrder.Count -gt 700){
            $oldKey=[string]$script:ImageSourceCacheOrder[0]
            $script:ImageSourceCacheOrder.RemoveAt(0)
            if($script:ImageSourceCache.ContainsKey($oldKey)){$script:ImageSourceCache.Remove($oldKey)}
        }
        return $bitmap
    }catch{return $null}
}

function Get-PlatformIconPath {
    param([string]$Platform)
    $key=(([string]$Platform).ToLowerInvariant() -replace '[^a-z0-9]+','')
    $file=switch -Regex($key){
        '^steam'{'steam.png';break}
        '^epic'{'epic.png';break}
        '^gog'{'gog.png';break}
        '^xbox|microsoftstore'{'xbox.png';break}
        '^ea|origin'{'ea.png';break}
        '^ubisoft|uplay'{'ubisoft.png';break}
        '^battlenet|blizzard'{'battlenet.png';break}
        '^rockstar'{'rockstar.png';break}
        '^amazon'{'amazon.png';break}
        '^psp|playstationportable'{'psp.png';break}
        '^ps1|playstation1|playstation$'{'ps1.png';break}
        '^ps2|playstation2'{'ps2.png';break}
        '^ps3|playstation3'{'ps3.png';break}
        '^ps4|playstation4'{'ps4.png';break}
        '^ps5|playstation5'{'ps5.png';break}
        '^switch|nintendoswitch'{'switch.png';break}
        '^wiiu'{'wiiu.png';break}
        '^wii'{'wii.png';break}
        '^gamecube|nintendogamecube'{'gamecube.png';break}
        '^dreamcast|segadreamcast'{'dreamcast.png';break}
        default{'generic.png'}
    }
    $path=Join-Path $script:BaseDir ("Assets\\Platforms\\"+$file)
    if(Test-Path -LiteralPath $path -PathType Leaf){return $path}
    return ''
}

function New-PlatformIconImage {
    param([string]$Platform,[double]$Size=76)
    $image=New-Object System.Windows.Controls.Image
    $image.Width=$Size;$image.Height=$Size;$image.Stretch='Uniform';$image.HorizontalAlignment='Center';$image.VerticalAlignment='Center';$image.IsHitTestVisible=$false
    $source=Get-ImageSourceFromPath (Get-PlatformIconPath $Platform)
    if($null -ne $source){$image.Source=$source}
    return $image
}

function Get-ModeIconPath {
    param([string]$Mode)
    $name=switch($Mode){'Home'{'mode-home.png'}'Shelf'{'mode-shelf.png'}'Library'{'mode-library.png'}default{'mode-store.png'}}
    $path=Join-Path $script:BaseDir ("Assets\\Platforms\\"+$name)
    if(Test-Path -LiteralPath $path -PathType Leaf){return $path}
    return ''
}

function New-HomeCard {
    param($Entry,[string]$Id,[string]$Kind)
    $button=New-Object System.Windows.Controls.Button;$button.Tag=$Id;$button.Width=198;$button.Height=286;$button.Margin='0,0,16,12';$button.Padding='0';$button.HorizontalContentAlignment='Stretch';$button.VerticalContentAlignment='Stretch';$button.Background='#B5121B2A';$button.BorderBrush='#33445E';$button.BorderThickness='1';$button.RenderTransformOrigin='0.5,0.5';$button.Cursor='Hand'
    $template=[Windows.Markup.XamlReader]::Parse('<ControlTemplate xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" TargetType="Button"><Border Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="14" ClipToBounds="True"><ContentPresenter/></Border></ControlTemplate>');$button.Template=$template
    $grid=New-Object System.Windows.Controls.Grid
    $installed=[bool](Get-EntryProperty $Entry 'Installed' $true)
    $art=[string](Get-EntryProperty $Entry 'ArtworkPath' (Get-EntryProperty $Entry 'HeroArtworkPath' ''))
    if(-not $art -or -not (Test-Path -LiteralPath $art -PathType Leaf)){$art=[string](Get-EntryProperty $Entry 'HeroArtworkPath' '')}
    $artSource=Get-ImageSourceFromPath $art 420
    if($null -ne $artSource){$image=New-Object System.Windows.Controls.Image;$image.Source=$artSource;$image.Stretch='UniformToFill';$image.SnapsToDevicePixels=$true;$image.Opacity=$(if($installed){1.0}else{0.30});$grid.Children.Add($image)|Out-Null}
    if($grid.Children.Count -eq 0){
        $bg=New-Object System.Windows.Shapes.Rectangle;$brush=New-Object System.Windows.Media.LinearGradientBrush;$brush.StartPoint='0,0';$brush.EndPoint='1,1';$brush.GradientStops.Add((New-Object System.Windows.Media.GradientStop -ArgumentList ([System.Windows.Media.ColorConverter]::ConvertFromString('#263A5C')),0.0));$brush.GradientStops.Add((New-Object System.Windows.Media.GradientStop -ArgumentList ([System.Windows.Media.ColorConverter]::ConvertFromString('#0D1421')),1.0));$bg.Fill=$brush;$grid.Children.Add($bg)|Out-Null
        $target=[string](Get-EntryProperty $Entry 'LaunchTarget' (Get-EntryProperty $Entry 'Path'))
        $isAppCard=($Id -match '^(app|recent-app|storefront)') -or ($Kind -match '(?i)Apps')
        $iconSource=if($isAppCard){Get-ExecutableIconSource $target}else{$null}
        if($null -ne $iconSource){
            $iconImage=New-Object System.Windows.Controls.Image;$iconImage.Source=$iconSource;$iconImage.Width=104;$iconImage.Height=104;$iconImage.HorizontalAlignment='Center';$iconImage.VerticalAlignment='Center';$iconImage.Margin='0,0,0,30';$grid.Children.Add($iconImage)|Out-Null
        }else{
            $sourceName=[string](Get-EntryProperty $Entry 'Source' $Kind)
            $case=New-Object System.Windows.Controls.Border;$case.Width=132;$case.Height=166;$case.CornerRadius=10;$case.HorizontalAlignment='Center';$case.VerticalAlignment='Center';$case.Margin='0,0,0,34';$case.Background='#42111B2D';$case.BorderBrush='#66E7C45E';$case.BorderThickness='1.5'
            $caseGrid=New-Object System.Windows.Controls.Grid
            $platformIcon=New-PlatformIconImage $sourceName 74;$platformIcon.Opacity=.84;$caseGrid.Children.Add($platformIcon)|Out-Null
            $pending=New-Object System.Windows.Controls.TextBlock;$pending.Text=$(if($isAppCard){'APPLICATION'}else{'ARTWORK PENDING'});$pending.FontSize=9;$pending.FontWeight='SemiBold';$pending.Foreground='#E7C45E';$pending.HorizontalAlignment='Center';$pending.VerticalAlignment='Bottom';$pending.Margin='8,0,8,14';$caseGrid.Children.Add($pending)|Out-Null
            $case.Child=$caseGrid;$grid.Children.Add($case)|Out-Null
        }
    }
    if(-not $installed){
        $disabledShade=New-Object System.Windows.Shapes.Rectangle;$disabledShade.Fill='#94000000';$grid.Children.Add($disabledShade)|Out-Null
        $installBadge=New-Object System.Windows.Controls.Border;$installBadge.HorizontalAlignment='Right';$installBadge.VerticalAlignment='Top';$installBadge.Margin='0,11,11,0';$installBadge.Padding='9,5';$installBadge.CornerRadius=8;$installBadge.Background='#E7C45E';$installBadge.BorderBrush='#FFF1A6';$installBadge.BorderThickness='1'
        $installText=New-Object System.Windows.Controls.TextBlock;$installText.Text='INSTALL';$installText.FontSize=10;$installText.FontWeight='Bold';$installText.Foreground='#111722';$installBadge.Child=$installText;$grid.Children.Add($installBadge)|Out-Null
    }
    $shade=New-Object System.Windows.Shapes.Rectangle;$shade.VerticalAlignment='Bottom' ;$shade.Height=112;$shadeBrush=New-Object System.Windows.Media.LinearGradientBrush;$shadeBrush.StartPoint='0,0';$shadeBrush.EndPoint='0,1';$shadeBrush.GradientStops.Add((New-Object System.Windows.Media.GradientStop -ArgumentList ([System.Windows.Media.ColorConverter]::ConvertFromString('#00101820')),0.0));$shadeBrush.GradientStops.Add((New-Object System.Windows.Media.GradientStop -ArgumentList ([System.Windows.Media.ColorConverter]::ConvertFromString('#F60A101A')),1.0));$shade.Fill=$shadeBrush;$grid.Children.Add($shade)|Out-Null
    $textPanel=New-Object System.Windows.Controls.StackPanel;$textPanel.VerticalAlignment='Bottom';$textPanel.Margin='13,0,13,13'
    $title=New-Object System.Windows.Controls.TextBlock;$title.Text=[string](Get-EntryProperty $Entry 'Name');$title.FontSize=16;$title.FontWeight='SemiBold';$title.Foreground='White';$title.TextWrapping='Wrap';$title.TextTrimming='CharacterEllipsis';$title.MinHeight=46;$title.MaxHeight=52;$title.Padding='0,1,0,4';$title.LineStackingStrategy='MaxHeight';$textPanel.Children.Add($title)|Out-Null
    $source=New-Object System.Windows.Controls.TextBlock;$source.Text=$(if($installed){[string](Get-EntryProperty $Entry 'Source' $Kind)}else{'Not installed • Select to manage'});$source.FontSize=11;$source.Foreground='#D8C36A';$source.Margin='0,3,0,0';$source.Padding='0,1,0,3';$source.MinHeight=20;$source.TextTrimming='CharacterEllipsis';$textPanel.Children.Add($source)|Out-Null;$grid.Children.Add($textPanel)|Out-Null
    $button.Content=$grid
    $button.Add_Click({param($sender,$eventArgs)try{Set-KeyboardActive;Invoke-UiFeedback 'Confirm';Invoke-Action ([string]$sender.Tag)}catch{Write-Log "Home action failed: $($_.Exception.Message)" 'ERROR'}})
    $button.Add_MouseEnter({param($sender,$eventArgs)if(-not(Test-HcMouseHoverAllowed)){return};Set-KeyboardActive;$idx=[array]::IndexOf($script:ActionButtons,$sender);if ($idx -ge 0) {$script:SelectedAction=$idx;Update-ActionVisuals}})
    return $button
}

function Add-HomeRail {
    param([string]$Title,[object[]]$Entries,[string]$Prefix,[string]$EmptyText)
    $Entries = Convert-ToStableArray $Entries
    $heading=New-Object System.Windows.Controls.TextBlock;$heading.Text=$Title;$heading.FontSize=22;$heading.FontWeight='SemiBold';$heading.Margin='0,0,0,10';$heading.Foreground='#F5F7FB';$script:ActionPanel.Children.Add($heading)|Out-Null
    if($Entries.Count -eq 0){$empty=New-Object System.Windows.Controls.Border;$empty.Height=112;$empty.CornerRadius=14;$empty.Background='#7A101827';$empty.BorderBrush='#2B3A51';$empty.BorderThickness=1;$empty.Margin='0,0,0,22';$tb=New-Object System.Windows.Controls.TextBlock;$tb.Text=$EmptyText;$tb.FontSize=16;$tb.Foreground='#AAB7C9';$tb.VerticalAlignment='Center';$tb.HorizontalAlignment='Center';$empty.Child=$tb;$script:ActionPanel.Children.Add($empty)|Out-Null;$script:HomeRows+=,[pscustomobject]@{Start=$script:ActionButtons.Count;Count=0};return}
    $start=$script:ActionButtons.Count;$row=New-Object System.Windows.Controls.StackPanel;$row.Orientation='Horizontal'
    for($i=0;$i -lt $Entries.Count;$i++){$button=New-HomeCard $Entries[$i] "${Prefix}:$i" $Title;$row.Children.Add($button)|Out-Null;$script:ActionButtons+=$button;$script:CurrentActions += (New-Action "${Prefix}:$i" ([string](Get-EntryProperty $Entries[$i] 'Name')))}
    $scroll=New-Object System.Windows.Controls.ScrollViewer;$scroll.HorizontalScrollBarVisibility='Hidden';$scroll.VerticalScrollBarVisibility='Disabled';$scroll.PanningMode='HorizontalOnly';$scroll.Content=$row;$scroll.Margin='0,0,0,16';$script:ActionPanel.Children.Add($scroll)|Out-Null;$script:HomeRows+=,[pscustomobject]@{Start=$start;Count=$Entries.Count}
}


function Get-AllGameHubEntries {
    $items=New-Object System.Collections.ArrayList
    foreach($game in @($script:Config.ImportedGames)){
        if($null -eq $game){continue}
        $source=[string](Get-EntryProperty $game 'Source' 'Game')
        [void]$items.Add($game)
    }
    foreach($game in @($script:Config.CustomGames)){if($null -ne $game){[void]$items.Add($game)}}
    return [object[]]$items.ToArray()
}

function Get-GameHubPlatforms {
    $seen=@{};$result=New-Object System.Collections.ArrayList
    [void]$result.Add('Steam');$seen['steam']=$true
    foreach($direct in @('Epic','GOG','Amazon')){[void]$result.Add($direct);$seen[$direct.ToLowerInvariant()]=$true}
    $preferred=@('GOG','Epic','Xbox','EA','Ubisoft','Battle.net','Rockstar','Amazon','PS3','PS2','PS1','N64','GameCube','Wii','Wii U','Switch','Original Xbox','Xbox 360','PSP','Dreamcast','Custom','Generic')
    $available=New-Object System.Collections.ArrayList
    foreach($game in @(Get-AllGameHubEntries)){
        $source=[string](Get-EntryProperty $game 'Source' 'Custom')
        if([string]::IsNullOrWhiteSpace($source)){$source='Custom'}
        $key=$source.ToLowerInvariant();if(-not $seen.ContainsKey($key)){[void]$available.Add($source);$seen[$key]=$true}
    }
    foreach($name in $preferred){foreach($source in @($available)){if([string]::Equals([string]$source,$name,[StringComparison]::OrdinalIgnoreCase)){[void]$result.Add([string]$source)}}}
    foreach($source in @($available|Sort-Object)){if(-not (@($result)|Where-Object{[string]::Equals([string]$_,[string]$source,[StringComparison]::OrdinalIgnoreCase)})){[void]$result.Add([string]$source)}}
    return [object[]]$result.ToArray()
}

function Find-SteamExecutable {
    foreach($key in @('HKCU:\Software\Valve\Steam','HKLM:\SOFTWARE\WOW6432Node\Valve\Steam','HKLM:\SOFTWARE\Valve\Steam')){
        try{
            $p=Get-ItemProperty $key -ErrorAction Stop
            foreach($name in @('SteamExe','SteamPath','InstallPath')){
                if($p.PSObject.Properties[$name]){
                    $value=[string]$p.$name
                    if($value){
                        if(Test-Path -LiteralPath $value -PathType Container){$value=Join-Path $value 'steam.exe'}
                        if(Test-Path -LiteralPath $value -PathType Leaf){return $value}
                    }
                }
            }
        }catch{}
    }
    foreach($candidate in @("${env:ProgramFiles(x86)}\Steam\steam.exe","$env:ProgramFiles\Steam\steam.exe")){
        if($candidate -and (Test-Path -LiteralPath $candidate -PathType Leaf)){return $candidate}
    }
    return ''
}

function Get-SteamBigPictureEntry {
    $steamPath=Find-SteamExecutable
    if($steamPath){
        return [pscustomobject]@{Id='Steam:BigPicture';Name='Steam Big Picture';Source='Steam';LaunchTarget=$steamPath;Arguments=@('-gamepadui');Path=$steamPath;ArtworkPath=''}
    }
    return [pscustomobject]@{Id='Steam:BigPicture';Name='Steam Big Picture';Source='Steam';LaunchTarget='steam://open/bigpicture';Arguments=@();Path='';ArtworkPath=''}
}

function Start-SteamBigPicture {
    $entry=Get-SteamBigPictureEntry
    Add-ToRecent 'App' $entry
    $steamPath=[string](Get-EntryProperty $entry 'Path')
    $launched=$false
    Send-ConsoleToBackground 20

    if($steamPath -and (Test-Path -LiteralPath $steamPath -PathType Leaf)){
        try{
            Start-Process -FilePath $steamPath -ArgumentList @('-bigpicture') -WorkingDirectory (Split-Path -Parent $steamPath)|Out-Null
            Write-Log "Requested Steam Big Picture: $steamPath -bigpicture"
            $launched=$true
        }catch{Write-Log "Steam -bigpicture launch failed: $($_.Exception.Message)" 'WARN'}

        # Re-send the modern Gamepad UI URI after Steam has had time to create
        # its window. A dispatcher timer avoids blocking the console UI thread.
        try{
            $steamRetry=New-Object System.Windows.Threading.DispatcherTimer
            $steamRetry.Interval=[TimeSpan]::FromSeconds(2.2)
            $steamRetry.Add_Tick({
                try{
                    $steamRetry.Stop()
                    if($steamPath -and (Test-Path -LiteralPath $steamPath -PathType Leaf)){
                        Start-Process -FilePath $steamPath -ArgumentList @('steam://open/gamepadui') -WorkingDirectory (Split-Path -Parent $steamPath)|Out-Null
                        Write-Log 'Sent delayed Steam Gamepad UI request.'
                    }
                }catch{Write-Log "Delayed Steam Gamepad UI request failed: $($_.Exception.Message)" 'WARN'}
            }.GetNewClosure())
            $steamRetry.Start()
        }catch{}
    }

    try{
        Start-Process 'steam://open/bigpicture'|Out-Null
        Write-Log 'Sent Steam Big Picture protocol request.'
        $launched=$true
    }catch{Write-Log "Steam Big Picture protocol launch failed: $($_.Exception.Message)" 'WARN'}

    if(-not $launched){Set-ConsoleNotice 'Steam could not be launched in Big Picture mode.' 'ERROR';Render-Page}
}

function Get-PlatformGameMergeKey {
    param($Entry,[string]$Platform)
    $key=[string](Get-EntryProperty $Entry 'ProviderGameId' '')
    if(-not $key){$key=[string](Get-EntryProperty $Entry 'Id' (Get-EntryProperty $Entry 'LaunchTarget' (Get-EntryProperty $Entry 'Path' '')))}
    if($key -and $Platform -and $key -match ('^(?i)'+[regex]::Escape($Platform)+':(.+)$')){$key=$matches[1]}
    return $(if($key){$key.Trim().ToLowerInvariant()}else{''})
}

function Get-PlatformGames {
    param([string]$Platform)
    $items=New-Object System.Collections.ArrayList;$indexByKey=@{}
    foreach($entry in @(Get-AllGameHubEntries|Where-Object{[string]::Equals([string](Get-EntryProperty $_ 'Source' 'Custom'),$Platform,[StringComparison]::OrdinalIgnoreCase)})){
        $key=Get-PlatformGameMergeKey $entry $Platform
        if($key){$indexByKey[$key]=$items.Count}
        [void]$items.Add($entry)
    }
    if((Get-Command Test-DirectProviderPlatform -ErrorAction SilentlyContinue) -and (Test-DirectProviderPlatform $Platform)){
        foreach($providerGame in @(Get-ProviderGames $Platform -InstalledOnly)){
            $providerEntry=Convert-ProviderGameToLaunchEntry $providerGame
            $lookup=Get-PlatformGameMergeKey $providerEntry $Platform
            if($lookup -and $indexByKey.ContainsKey($lookup)){
                $index=[int]$indexByKey[$lookup]
                if(Get-Command Merge-HcGameEntry -ErrorAction SilentlyContinue){$items[$index]=Merge-HcGameEntry $items[$index] $providerEntry $Platform}else{$items[$index]=$providerEntry}
            }else{
                if($lookup){$indexByKey[$lookup]=$items.Count}
                [void]$items.Add($providerEntry)
            }
        }
    }
    return [object[]]$items.ToArray()
}

function Get-PlatformLibraryGames {
    param([string]$Platform)
    $items=New-Object System.Collections.ArrayList;$indexByKey=@{}
    foreach($entry in @(Get-PlatformGames $Platform)){
        $key=Get-PlatformGameMergeKey $entry $Platform
        if($key){$indexByKey[$key]=$items.Count}
        [void]$items.Add($entry)
    }
    if((Get-Command Test-DirectProviderPlatform -ErrorAction SilentlyContinue) -and (Test-DirectProviderPlatform $Platform)){
        foreach($providerGame in @(Get-ProviderGames $Platform)){
            $entry=Convert-ProviderGameToLaunchEntry $providerGame
            $key=Get-PlatformGameMergeKey $entry $Platform
            if($key -and $indexByKey.ContainsKey($key)){
                $index=[int]$indexByKey[$key]
                if(Get-Command Merge-HcGameEntry -ErrorAction SilentlyContinue){$items[$index]=Merge-HcGameEntry $items[$index] $entry $Platform}else{$items[$index]=$entry}
            }
            else{if($key){$indexByKey[$key]=$items.Count};[void]$items.Add($entry)}
        }
    }
    return [object[]]$items.ToArray()
}

function Get-PlatformRecentGames {
    param([string]$Platform)
    return [object[]]@($script:Config.RecentGames|Where-Object{[string]::Equals([string](Get-EntryProperty $_ 'Source' 'Custom'),$Platform,[StringComparison]::OrdinalIgnoreCase) -and [bool](Get-EntryProperty $_ 'Installed' $true)}|Select-Object -First 12)
}

function Read-Ps3LibrarySummary {
    if(-not (Test-Path -LiteralPath $script:Ps3SummaryPath -PathType Leaf)){return $null}
    try{return Get-Content -Raw -LiteralPath $script:Ps3SummaryPath|ConvertFrom-Json}catch{return $null}
}

function Start-Ps3LibrarySummaryScan {
    if(-not (Test-Path -LiteralPath $script:Ps3LibraryWorkerPath -PathType Leaf)){return}
    try{if($script:Ps3SummaryWorkerProcess -and -not $script:Ps3SummaryWorkerProcess.HasExited){return}}catch{}
    if(((Get-Date)-$script:LastPs3SummaryStartAt).TotalSeconds -lt 8){return}
    try{
        $settingsPath=Join-Path $script:DataDir 'EmulatorPlatforms\PS3\settings.json'
        $defaultPath=Join-Path $script:BaseDir 'EmulatorPlatforms\PS3\settings.default.json'
        $powershell="$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
        $args='-NoLogo -NoProfile -ExecutionPolicy Bypass -File "'+$script:Ps3LibraryWorkerPath+'" -SettingsPath "'+$settingsPath+'" -DefaultSettingsPath "'+$defaultPath+'" -ResultPath "'+$script:Ps3SummaryPath+'"'
        $script:Ps3SummaryWorkerProcess=Start-Process -FilePath $powershell -ArgumentList $args -WindowStyle Hidden -PassThru
        $script:LastPs3SummaryStartAt=Get-Date
        Write-Log 'Background PS3 game-count scan started.'
    }catch{Write-Log "PS3 game-count scan could not start: $($_.Exception.Message)" 'WARN'}
}

function Read-Ps2LibrarySummary {
    if(-not (Test-Path -LiteralPath $script:Ps2SummaryPath -PathType Leaf)){return $null}
    try{return Get-Content -Raw -LiteralPath $script:Ps2SummaryPath|ConvertFrom-Json}catch{return $null}
}

function Start-Ps2LibrarySummaryScan {
    if(-not (Test-Path -LiteralPath $script:Ps2LibraryWorkerPath -PathType Leaf)){return}
    try{if($script:Ps2SummaryWorkerProcess -and -not $script:Ps2SummaryWorkerProcess.HasExited){return}}catch{}
    if(((Get-Date)-$script:LastPs2SummaryStartAt).TotalSeconds -lt 8){return}
    try{
        $settingsPath=Join-Path $script:DataDir 'EmulatorPlatforms\PS2\settings.json'
        $defaultPath=Join-Path $script:BaseDir 'EmulatorPlatforms\PS2\settings.default.json'
        $powershell="$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
        $args='-NoLogo -NoProfile -ExecutionPolicy Bypass -File "'+$script:Ps2LibraryWorkerPath+'" -SettingsPath "'+$settingsPath+'" -DefaultSettingsPath "'+$defaultPath+'" -ResultPath "'+$script:Ps2SummaryPath+'"'
        $script:Ps2SummaryWorkerProcess=Start-Process -FilePath $powershell -ArgumentList $args -WindowStyle Hidden -PassThru
        $script:LastPs2SummaryStartAt=Get-Date
        Write-Log 'Background PS2 game-count scan started.'
    }catch{Write-Log "PS2 game-count scan could not start: $($_.Exception.Message)" 'WARN'}
}

function Read-Ps1LibrarySummary {
    if(-not (Test-Path -LiteralPath $script:Ps1SummaryPath -PathType Leaf)){return $null}
    try{return Get-Content -Raw -LiteralPath $script:Ps1SummaryPath|ConvertFrom-Json}catch{return $null}
}

function Start-Ps1LibrarySummaryScan {
    if(-not (Test-Path -LiteralPath $script:Ps1LibraryWorkerPath -PathType Leaf)){return}
    try{if($script:Ps1SummaryWorkerProcess -and -not $script:Ps1SummaryWorkerProcess.HasExited){return}}catch{}
    if(((Get-Date)-$script:LastPs1SummaryStartAt).TotalSeconds -lt 8){return}
    try{
        $settingsPath=Join-Path $script:DataDir 'EmulatorPlatforms\PS1\settings.json'
        $defaultPath=Join-Path $script:BaseDir 'EmulatorPlatforms\PS1\settings.default.json'
        $powershell="$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
        $args='-NoLogo -NoProfile -ExecutionPolicy Bypass -File "'+$script:Ps1LibraryWorkerPath+'" -SettingsPath "'+$settingsPath+'" -DefaultSettingsPath "'+$defaultPath+'" -ResultPath "'+$script:Ps1SummaryPath+'"'
        $script:Ps1SummaryWorkerProcess=Start-Process -FilePath $powershell -ArgumentList $args -WindowStyle Hidden -PassThru
        $script:LastPs1SummaryStartAt=Get-Date
        Write-Log 'Background PS1 game-count scan started.'
    }catch{Write-Log "PS1 game-count scan could not start: $($_.Exception.Message)" 'WARN'}
}

function Get-NativeConsolePlatformFolder {
    param([string]$PlatformId)
    switch($PlatformId.ToUpperInvariant()){
        'N64' { return 'N64' }
        'GAMECUBE' { return 'GameCube' }
        'WII' { return 'Wii' }
        'WIIU' { return 'WiiU' }
        'SWITCH' { return 'Switch' }
        'XBOX' { return 'Xbox' }
        'XBOX360' { return 'Xbox360' }
        default { return $PlatformId }
    }
}

function Read-NativeConsoleLibrarySummary {
    param([string]$PlatformId)
    $path=Join-Path $script:DataDir ("EmulatorPlatforms\"+$PlatformId.ToUpperInvariant()+"\library-summary.json")
    if(-not(Test-Path -LiteralPath $path -PathType Leaf)){return $null}
    try{return Get-Content -Raw -LiteralPath $path|ConvertFrom-Json}catch{return $null}
}

function Start-NativeConsoleLibrarySummaryScan {
    param([string]$PlatformId)
    if(-not(Test-Path -LiteralPath $script:NativeConsoleLibraryWorkerPath -PathType Leaf)){return}
    $id=$PlatformId.ToUpperInvariant()
    try{if($script:NativeConsoleSummaryProcesses.ContainsKey($id) -and $script:NativeConsoleSummaryProcesses[$id] -and -not $script:NativeConsoleSummaryProcesses[$id].HasExited){return}}catch{}
    $last=[datetime]::MinValue
    if($script:NativeConsoleSummaryLastStart.ContainsKey($id)){try{$last=[datetime]$script:NativeConsoleSummaryLastStart[$id]}catch{}}
    if(((Get-Date)-$last).TotalSeconds -lt 30){return}
    try{
        $folder=Get-NativeConsolePlatformFolder $id
        $settingsPath=Join-Path $script:DataDir ("EmulatorPlatforms\"+$id+"\settings.json")
        $defaultPath=Join-Path $script:BaseDir ("EmulatorPlatforms\"+$folder+"\settings.default.json")
        $resultPath=Join-Path $script:DataDir ("EmulatorPlatforms\"+$id+"\library-summary.json")
        $powershell="$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
        $args='-NoLogo -NoProfile -ExecutionPolicy Bypass -File "'+$script:NativeConsoleLibraryWorkerPath+'" -PlatformId "'+$id+'" -SettingsPath "'+$settingsPath+'" -DefaultSettingsPath "'+$defaultPath+'" -ResultPath "'+$resultPath+'"'
        $script:NativeConsoleSummaryProcesses[$id]=Start-Process -FilePath $powershell -ArgumentList $args -WindowStyle Hidden -PassThru
        $script:NativeConsoleSummaryLastStart[$id]=Get-Date
    }catch{Write-Log ("$id game-count scan could not start: "+$_.Exception.Message) 'WARN'}
}

function Get-PlatformCountSummary {
    param([string]$Platform)
    if([string]::Equals($Platform,'PS1',[StringComparison]::OrdinalIgnoreCase) -or [string]::Equals($Platform,'PlayStation 1',[StringComparison]::OrdinalIgnoreCase) -or [string]::Equals($Platform,'PlayStation',[StringComparison]::OrdinalIgnoreCase)){
        Start-Ps1LibrarySummaryScan
        $summary=Read-Ps1LibrarySummary
        # v0.25.2: keep the previous count visible while a throttled background
        # refresh checks configured libraries for newly added or removed games.
        $summaryError=if($null -ne $summary){[string](Get-EntryProperty $summary 'Error' '')}else{''}
        if($null -ne $summary -and -not $summaryError){$value=[int](Get-EntryProperty $summary 'Count' 0);return [pscustomobject]@{Installed=$value;Owned=$value;Pending=$false}}
        return [pscustomobject]@{Installed=0;Owned=0;Pending=$false}
    }
    if([string]::Equals($Platform,'PS2',[StringComparison]::OrdinalIgnoreCase) -or [string]::Equals($Platform,'PlayStation 2',[StringComparison]::OrdinalIgnoreCase)){
        Start-Ps2LibrarySummaryScan
        $summary=Read-Ps2LibrarySummary
        $summaryError=if($null -ne $summary){[string](Get-EntryProperty $summary 'Error' '')}else{''}
        if($null -ne $summary -and -not $summaryError){
            $value=[int](Get-EntryProperty $summary 'Count' 0)
            return [pscustomobject]@{Installed=$value;Owned=$value;Pending=$false}
        }
        return [pscustomobject]@{Installed=0;Owned=0;Pending=$false}
    }
    if([string]::Equals($Platform,'PS3',[StringComparison]::OrdinalIgnoreCase) -or [string]::Equals($Platform,'PlayStation 3',[StringComparison]::OrdinalIgnoreCase)){
        Start-Ps3LibrarySummaryScan
        $summary=Read-Ps3LibrarySummary
        $summaryError=if($null -ne $summary){[string](Get-EntryProperty $summary 'Error' '')}else{''}
        if($null -ne $summary -and -not $summaryError){
            $value=[int](Get-EntryProperty $summary 'Count' 0)
            return [pscustomobject]@{Installed=$value;Owned=$value;Pending=$false}
        }
        return [pscustomobject]@{Installed=0;Owned=0;Pending=$false}
    }
    # Native multi-console shells persist their own cache. Read that file
    # directly so the platform rail remains instant and never rescans merely to
    # produce a count badge.
    try{
        if(Get-Command Get-HcEmulatorPlatformEntry -ErrorAction SilentlyContinue){
            $nativeEntry=Get-HcEmulatorPlatformEntry $Platform
            if($null -ne $nativeEntry){
                $nativeId=[string](Get-EntryProperty $nativeEntry 'id' '')
                if($nativeId -and $nativeId -notin @('ps1','ps2','ps3')){
                    $id=$nativeId.ToUpperInvariant()
                    Start-NativeConsoleLibrarySummaryScan $id
                    $summary=Read-NativeConsoleLibrarySummary $id
                    $summaryError=if($null -ne $summary){[string](Get-EntryProperty $summary 'Error' '')}else{''}
                    if($null -ne $summary -and -not $summaryError){
                        $value=[int](Get-EntryProperty $summary 'Count' 0)
                        return [pscustomobject]@{Installed=$value;Owned=$value;Pending=$false}
                    }
                    $nativeCache=Join-Path $script:DataDir ("EmulatorPlatforms\"+$id+"\library-cache.json")
                    if(Test-Path -LiteralPath $nativeCache -PathType Leaf){
                        $cachedGames=@(Get-Content -Raw -LiteralPath $nativeCache|ConvertFrom-Json)
                        return [pscustomobject]@{Installed=$cachedGames.Count;Owned=$cachedGames.Count;Pending=$true}
                    }
                    return [pscustomobject]@{Installed=0;Owned=0;Pending=$true}
                }
            }
        }
    }catch{}
    $installed=@(Get-PlatformGames $Platform).Count
    $owned=@(Get-PlatformLibraryGames $Platform).Count
    return [pscustomobject]@{Installed=$installed;Owned=$owned;Pending=$false}
}

function New-PlatformCard {
    param([string]$Platform,[int]$Index)
    $button=New-Object System.Windows.Controls.Button;$button.Tag="platform-select:$Index";$button.Width=152;$button.Height=148;$button.Margin='0,0,15,10';$button.Padding='0';$button.Background='#160A1220';$button.BorderBrush='#20364D';$button.BorderThickness='1';$button.RenderTransformOrigin='0.5,0.5';$button.Cursor='Hand'
    $button.Template=[Windows.Markup.XamlReader]::Parse('<ControlTemplate xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" TargetType="Button"><Border Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="18" ClipToBounds="True"><ContentPresenter/></Border></ControlTemplate>')
    $grid=New-Object System.Windows.Controls.Grid;$grid.Margin='12,10,12,9';$grid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition -Property @{Height='*'}));$grid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition -Property @{Height='Auto'}));$grid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition -Property @{Height='Auto'}))
    $theme=Get-PlatformTheme $Platform
    $iconBorder=New-Object System.Windows.Controls.Border;$iconBorder.Width=92;$iconBorder.Height=92;$iconBorder.CornerRadius=46;$iconBorder.HorizontalAlignment='Center';$iconBorder.VerticalAlignment='Center';$iconBorder.BorderBrush=$theme.Accent1;$iconBorder.BorderThickness='1.5';$iconBorder.Background='#260C1422';[System.Windows.Controls.Grid]::SetRow($iconBorder,0)
    $iconBorder.Child=New-PlatformIconImage $Platform 64;$grid.Children.Add($iconBorder)|Out-Null
    $label=New-Object System.Windows.Controls.TextBlock;$label.Text=$Platform;$label.FontSize=14;$label.FontWeight='SemiBold';$label.Foreground='White';$label.Margin='2,8,2,0';$label.HorizontalAlignment='Center';$label.TextTrimming='CharacterEllipsis';[System.Windows.Controls.Grid]::SetRow($label,1);$grid.Children.Add($label)|Out-Null
    $countSummary=Get-PlatformCountSummary $Platform;$installedCount=[int]$countSummary.Installed;$ownedCount=[int]$countSummary.Owned
    $count=New-Object System.Windows.Controls.TextBlock;$count.Text=$(if([bool]$countSummary.Pending){'SCANNING…'}elseif($ownedCount -gt $installedCount){"$installedCount INSTALLED • $ownedCount OWNED"}else{"$installedCount GAMES"});$count.FontSize=9;$count.FontWeight='SemiBold';$count.Foreground='#94A6BE';$count.Margin='0,3,0,0';$count.HorizontalAlignment='Center';[System.Windows.Controls.Grid]::SetRow($count,2);$grid.Children.Add($count)|Out-Null
    $button.Content=$grid
    $button.Add_Click({param($sender,$eventArgs)Invoke-UiFeedback 'Confirm';Invoke-Action ([string]$sender.Tag)})
    $button.Add_MouseEnter({param($sender,$eventArgs)if(-not(Test-HcMouseHoverAllowed)){return};Set-KeyboardActive;$idx=[array]::IndexOf($script:ActionButtons,$sender);if($idx -ge 0){$script:SelectedAction=$idx;Update-ActionVisuals}})
    return $button
}

function Add-PlatformRail {
    $headingPanel=New-Object System.Windows.Controls.StackPanel;$headingPanel.Orientation='Horizontal';$headingPanel.Margin='0,0,0,12'
    $heading=New-Object System.Windows.Controls.TextBlock;$heading.Text='Choose a platform';$heading.FontSize=22;$heading.FontWeight='SemiBold';$heading.Foreground='#F5F7FB';$heading.VerticalAlignment='Center';$headingPanel.Children.Add($heading)|Out-Null
    $hint=New-Object System.Windows.Controls.TextBlock;$hint.Text='  Select a platform to open Home, Shelf, Library, or game management.';$hint.FontSize=12;$hint.Foreground='#91A3BA';$hint.VerticalAlignment='Center';$hint.Margin='10,4,0,0';$headingPanel.Children.Add($hint)|Out-Null;$script:ActionPanel.Children.Add($headingPanel)|Out-Null
    $start=$script:ActionButtons.Count;$row=New-Object System.Windows.Controls.StackPanel;$row.Orientation='Horizontal';$row.Margin='2,0,20,0'
    for($i=0;$i -lt $script:GameHubPlatforms.Count;$i++){$button=New-PlatformCard ([string]$script:GameHubPlatforms[$i]) $i;$row.Children.Add($button)|Out-Null;$script:ActionButtons+=$button;$script:CurrentActions+=(New-Action "platform-select:$i" ([string]$script:GameHubPlatforms[$i]))}
    $scroll=New-Object System.Windows.Controls.ScrollViewer;$scroll.HorizontalScrollBarVisibility='Hidden';$scroll.VerticalScrollBarVisibility='Disabled';$scroll.PanningMode='HorizontalOnly';$scroll.Content=$row;$scroll.Margin='0,0,0,18';$script:ActionPanel.Children.Add($scroll)|Out-Null;$script:HomeRows+=,[pscustomobject]@{Start=$start;Count=$script:GameHubPlatforms.Count;Platform=$true}

    $recentAll=@($script:Config.RecentGames|Where-Object{$null -ne $_}|Select-Object -First 10)
    if($recentAll.Count -gt 0){Add-GameHubRail 'Continue Playing' $recentAll ''}
    $allEntries=@(Get-AllGameHubEntries|Where-Object{$null -ne $_})
    if($allEntries.Count -gt 0){$picks=if($allEntries.Count -gt 10){@($allEntries|Get-Random -Count 10)}else{$allEntries};Add-GameHubRail 'Across Your Libraries' $picks ''}
}

function Add-GameHubRail {
    param([string]$Title,[object[]]$Entries,[string]$EmptyText)
    $Entries = Convert-ToStableArray $Entries
    $heading=New-Object System.Windows.Controls.TextBlock;$heading.Text=$Title;$heading.FontSize=22;$heading.FontWeight='SemiBold';$heading.Margin='0,0,0,10';$heading.Foreground='#F5F7FB';$script:ActionPanel.Children.Add($heading)|Out-Null
    if($Entries.Count -eq 0){$empty=New-Object System.Windows.Controls.Border;$empty.Height=96;$empty.CornerRadius=14;$empty.Background='#7A101827';$empty.BorderBrush='#2B3A51';$empty.BorderThickness=1;$empty.Margin='0,0,0,20';$tb=New-Object System.Windows.Controls.TextBlock;$tb.Text=$EmptyText;$tb.FontSize=16;$tb.Foreground='#AAB7C9';$tb.VerticalAlignment='Center';$tb.HorizontalAlignment='Center';$empty.Child=$tb;$script:ActionPanel.Children.Add($empty)|Out-Null;$script:HomeRows+=,[pscustomobject]@{Start=$script:ActionButtons.Count;Count=0;Platform=$false};return}
    $start=$script:ActionButtons.Count;$row=New-Object System.Windows.Controls.StackPanel;$row.Orientation='Horizontal'
    foreach($entry in $Entries){$launchIndex=$script:GameHubLaunchEntries.Count;$script:GameHubLaunchEntries+=$entry;$button=New-HomeCard $entry "hub-game:$launchIndex" $Title;$row.Children.Add($button)|Out-Null;$script:ActionButtons+=$button;$script:CurrentActions+=(New-Action "hub-game:$launchIndex" ([string](Get-EntryProperty $entry 'Name')))}
    $scroll=New-Object System.Windows.Controls.ScrollViewer;$scroll.HorizontalScrollBarVisibility='Hidden';$scroll.VerticalScrollBarVisibility='Disabled';$scroll.PanningMode='HorizontalOnly';$scroll.Content=$row;$scroll.Margin='0,0,0,15';$script:ActionPanel.Children.Add($scroll)|Out-Null;$script:HomeRows+=,[pscustomobject]@{Start=$start;Count=$Entries.Count;Platform=$false}
}

function Add-PlatformChoiceRail {
    $header=New-Object System.Windows.Controls.StackPanel;$header.Orientation='Horizontal';$header.Margin='0,0,0,16'
    $iconFrame=New-Object System.Windows.Controls.Border;$iconFrame.Width=58;$iconFrame.Height=58;$iconFrame.CornerRadius=18;$iconFrame.Background='#350B1422';$iconFrame.BorderBrush='#60E7C45E';$iconFrame.BorderThickness='1';$iconFrame.Child=New-PlatformIconImage $script:SelectedGamePlatform 39;$header.Children.Add($iconFrame)|Out-Null
    $headerText=New-Object System.Windows.Controls.StackPanel;$headerText.Margin='14,1,0,0';$platformTitle=New-Object System.Windows.Controls.TextBlock;$platformTitle.Text=$script:SelectedGamePlatform;$platformTitle.FontSize=29;$platformTitle.FontWeight='Bold';$platformTitle.Foreground='#F5F7FB';$headerText.Children.Add($platformTitle)|Out-Null;$platformSub=New-Object System.Windows.Controls.TextBlock;$platformSub.Text='Choose how you want to browse this platform.';$platformSub.FontSize=13;$platformSub.Foreground='#94A6BE';$platformSub.Margin='0,3,0,0';$headerText.Children.Add($platformSub)|Out-Null;$header.Children.Add($headerText)|Out-Null;$script:ActionPanel.Children.Add($header)|Out-Null
    $start=$script:ActionButtons.Count
    $row=New-Object System.Windows.Controls.StackPanel;$row.Orientation='Horizontal';$row.Margin='0,0,20,0'
    $platformChoices=New-Object System.Collections.ArrayList
    [void]$platformChoices.Add([pscustomobject]@{Id='platform-home';Title='Home';Subtitle='Recent games and quick picks.';Mode='Home'})
    [void]$platformChoices.Add([pscustomobject]@{Id='platform-shelf';Title='Shelf';Subtitle='Large horizontal case-art view.';Mode='Shelf'})
    [void]$platformChoices.Add([pscustomobject]@{Id='platform-library';Title='Library';Subtitle='Browse the complete owned library; uninstalled games are dimmed.';Mode='Library'})
    if([string]::Equals($script:SelectedGamePlatform,'Steam',[StringComparison]::OrdinalIgnoreCase)){[void]$platformChoices.Add([pscustomobject]@{Id='platform-steam-bigpicture';Title='Steam Big Picture';Subtitle='Open the full Steam Gamepad UI while Huymaier Console stays active in the background.';Mode='Store'})}
    if((Get-Command Test-DirectProviderPlatform -ErrorAction SilentlyContinue) -and (Test-DirectProviderPlatform $script:SelectedGamePlatform)){[void]$platformChoices.Add([pscustomobject]@{Id='platform-store';Title='Install & Manage';Subtitle='Install, update, repair, move, and remove.';Mode='Store'})}
    foreach($choice in ([object[]]$platformChoices.ToArray())){
        $button=New-Object System.Windows.Controls.Button;$button.Tag=$choice.Id;$button.Width=236;$button.Height=162;$button.Margin='0,0,18,10';$button.Padding='0';$button.Background='#8D101927';$button.BorderBrush='#33445E';$button.BorderThickness='1';$button.RenderTransformOrigin='0.5,0.5';$button.Cursor='Hand'
        $button.Template=[Windows.Markup.XamlReader]::Parse('<ControlTemplate xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" TargetType="Button"><Border Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="17" ClipToBounds="True"><ContentPresenter/></Border></ControlTemplate>')
        $grid=New-Object System.Windows.Controls.Grid;$grid.Margin='18,15,18,14';$grid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition -Property @{Height='58'}));$grid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition -Property @{Height='Auto'}));$grid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition -Property @{Height='*'}))
        $modeImage=New-Object System.Windows.Controls.Image;$modeImage.Width=48;$modeImage.Height=48;$modeImage.HorizontalAlignment='Left';$modeImage.Source=Get-ImageSourceFromPath (Get-ModeIconPath $choice.Mode);[System.Windows.Controls.Grid]::SetRow($modeImage,0);$grid.Children.Add($modeImage)|Out-Null
        $title=New-Object System.Windows.Controls.TextBlock;$title.Text=$choice.Title;$title.FontSize=22;$title.FontWeight='Bold';$title.Foreground='White';$title.Margin='0,7,0,0';[System.Windows.Controls.Grid]::SetRow($title,1);$grid.Children.Add($title)|Out-Null
        $subtitle=New-Object System.Windows.Controls.TextBlock;$subtitle.Text=$choice.Subtitle;$subtitle.FontSize=12;$subtitle.Foreground='#AEBBD0';$subtitle.TextWrapping='Wrap';$subtitle.LineHeight=17;$subtitle.MaxHeight=36;$subtitle.Margin='0,5,0,0';[System.Windows.Controls.Grid]::SetRow($subtitle,2);$grid.Children.Add($subtitle)|Out-Null
        $button.Content=$grid
        $button.Add_Click({param($sender,$eventArgs)Invoke-UiFeedback 'Confirm';Invoke-Action ([string]$sender.Tag)})
        $button.Add_MouseEnter({param($sender,$eventArgs)if(-not(Test-HcMouseHoverAllowed)){return};Set-KeyboardActive;$idx=[array]::IndexOf($script:ActionButtons,$sender);if($idx -ge 0){$script:SelectedAction=$idx;Update-ActionVisuals}})
        $row.Children.Add($button)|Out-Null;$script:ActionButtons+=$button;$script:CurrentActions+=(New-Action $choice.Id $choice.Title $choice.Subtitle)
    }
    $scroll=New-Object System.Windows.Controls.ScrollViewer;$scroll.HorizontalScrollBarVisibility='Hidden';$scroll.VerticalScrollBarVisibility='Disabled';$scroll.PanningMode='HorizontalOnly';$scroll.Content=$row;$script:ActionPanel.Children.Add($scroll)|Out-Null
    $script:HomeRows+=,[pscustomobject]@{Start=$start;Count=$platformChoices.Count;Platform=$false}
}

function Render-PlatformHome {
    $script:GameHubLaunchEntries=@()
    $recent=Get-PlatformRecentGames $script:SelectedGamePlatform
    $all=Get-PlatformGames $script:SelectedGamePlatform
    $recentTargets=@{};foreach($entry in $recent){$recentTargets[[string](Get-EntryProperty $entry 'LaunchTarget' (Get-EntryProperty $entry 'Path'))]=$true}
    $remaining=@($all|Where-Object{-not $recentTargets.ContainsKey([string](Get-EntryProperty $_ 'LaunchTarget' (Get-EntryProperty $_ 'Path')))})
    $random=if($remaining.Count -gt 12){@($remaining|Get-Random -Count 12)}else{@($remaining)}
    Add-GameHubRail "$($script:SelectedGamePlatform) - Recently Played" $recent "No recently played $($script:SelectedGamePlatform) titles yet."
    Add-GameHubRail 'Random Picks' $random "No additional $($script:SelectedGamePlatform) titles are available."
}


function New-ShelfCard {
    param($Entry,[string]$Id)
    $button=New-HomeCard $Entry $Id 'Shelf'
    $button.Width=198;$button.Height=286;$button.Margin='0,14,20,18'
    return $button
}

function Update-ShelfSelection {
    if($script:SubPage -ne 'PlatformShelf' -or $script:ShelfEntries.Count -eq 0){return}
    $index=[math]::Max(0,[math]::Min($script:SelectedAction,$script:ShelfEntries.Count-1))
    $entry=$script:ShelfEntries[$index]
    if($null -ne $script:ShelfTitleText){
        $script:ShelfTitleText.Text=[string](Get-EntryProperty $entry 'Name' 'Game')
    }
    if($null -ne $script:ShelfDetailText){
        $source=[string](Get-EntryProperty $entry 'Source' $script:SelectedGamePlatform)
        $installed=[string](Get-EntryProperty $entry 'InstallPath' (Get-EntryProperty $entry 'Path' ''))
        $description=[string](Get-EntryProperty $entry 'Description' '')
        $size=[string](Get-EntryProperty $entry 'SizeText' '')
        $status=if($installed){'Installed'}else{'Ready to launch'}
        if(-not $description){ $description = "$status  ·  $source" }
        $details=@($description)
        if($size){ $details += $size }
        if($installed){ $details += $installed }
        $script:ShelfDetailText.Text = ($details -join "`n")
    }
    $script:ShelfGalleryPaths=@(Get-EntryArtworkGalleryPaths $entry)
    $script:ShelfPreviewIndex=0
    Update-ShelfArtworkPreview
}


function Get-EntryArtworkGalleryPaths {
    param($Entry)
    $paths = New-Object System.Collections.ArrayList
    $roots = New-Object System.Collections.ArrayList
    foreach($property in @('ArtworkPath','HeroArtworkPath','IconPath','BoxArtPath','ImagePath')){
        $candidate=[string](Get-EntryProperty $Entry $property '')
        if($candidate -and (Test-Path -LiteralPath $candidate -PathType Leaf)){
            if(-not (@($paths) -contains $candidate)){[void]$paths.Add($candidate)}
            try{[void]$roots.Add((Split-Path -Parent $candidate))}catch{}
        }
    }
    $primary=if($paths.Count -gt 0){[string]$paths[0]}else{''}
    $gamePath = [string](Get-EntryProperty $Entry 'Path' '')
    if($gamePath){
        try{
            if(Test-Path -LiteralPath $gamePath -PathType Container){ [void]$roots.Add($gamePath) }
            elseif(Test-Path -LiteralPath $gamePath -PathType Leaf){ [void]$roots.Add((Split-Path -Parent $gamePath)) }
        }catch{}
    }
    foreach($root in @($roots|Select-Object -Unique)){
        if(-not $root -or -not (Test-Path -LiteralPath $root -PathType Container)){ continue }
        try{
            $files = Get-ChildItem -LiteralPath $root -File -ErrorAction SilentlyContinue | Where-Object { $_.Extension -match '^(?i)\.(jpg|jpeg|png|webp)$' } | Sort-Object Name
            foreach($file in @($files | Select-Object -First 10)){
                if(-not (@($paths) -contains $file.FullName)){ [void]$paths.Add($file.FullName) }
            }
        }catch{}
    }
    return ,([object[]]$paths.ToArray())
}

function Update-ShelfArtworkPreview {
    if($null -eq $script:ShelfPreviewImage){ return }
    $gallery=@($script:ShelfGalleryPaths)
    if($gallery.Count -eq 0){
        try{ $script:ShelfPreviewImage.Source = $null }catch{}
        if($null -ne $script:ShelfPreviewCountText){ $script:ShelfPreviewCountText.Text = 'No additional artwork' }
        if($null -ne $script:ShelfPreviewThumbPanel){ $script:ShelfPreviewThumbPanel.Children.Clear() }
        return
    }
    if($script:ShelfPreviewIndex -lt 0 -or $script:ShelfPreviewIndex -ge $gallery.Count){ $script:ShelfPreviewIndex = 0 }
    try{ $script:ShelfPreviewImage.Source = Get-ImageSourceFromPath ([string]$gallery[$script:ShelfPreviewIndex]) }catch{}
    if($null -ne $script:ShelfPreviewCountText){ $script:ShelfPreviewCountText.Text = ('Artwork {0} / {1}   ·   LB/RB cycle' -f ($script:ShelfPreviewIndex + 1), $gallery.Count) }
    if($null -ne $script:ShelfPreviewThumbPanel){
        $script:ShelfPreviewThumbPanel.Children.Clear()
        for($i=0;$i -lt $gallery.Count -and $i -lt 6;$i++){
            $thumbBorder=New-Object System.Windows.Controls.Border
            $thumbBorder.Width=74;$thumbBorder.Height=42;$thumbBorder.CornerRadius=8;$thumbBorder.Margin='0,0,8,0';$thumbBorder.BorderThickness='2';$thumbBorder.BorderBrush=$(if($i -eq $script:ShelfPreviewIndex){'#F2D36B'}else{'#44FFFFFF'});$thumbBorder.Background='#12000000'
            $thumb=New-Object System.Windows.Controls.Image
            $thumb.Stretch='UniformToFill';$thumb.Source=Get-ImageSourceFromPath ([string]$gallery[$i])
            $thumbBorder.Child=$thumb
            [void]$script:ShelfPreviewThumbPanel.Children.Add($thumbBorder)
        }
    }
}

function Move-ShelfArtworkPreview {
    param([int]$Delta)
    if($script:SubPage -ne 'PlatformShelf'){ return $false }
    $gallery=@($script:ShelfGalleryPaths)
    if($gallery.Count -le 1){ return $false }
    $script:ShelfPreviewIndex = ($script:ShelfPreviewIndex + $Delta)
    if($script:ShelfPreviewIndex -lt 0){ $script:ShelfPreviewIndex = $gallery.Count - 1 }
    if($script:ShelfPreviewIndex -ge $gallery.Count){ $script:ShelfPreviewIndex = 0 }
    Update-ShelfArtworkPreview
    Invoke-UiFeedback 'Tab'
    return $true
}

function Render-PlatformShelf {
    $script:GameHubLaunchEntries=@()
    $script:ShelfEntries=@(Get-PlatformGames $script:SelectedGamePlatform|Sort-Object {[string](Get-EntryProperty $_ 'Name')})
    if($script:ShelfEntries.Count -eq 0){Add-GameHubRail "$($script:SelectedGamePlatform) Shelf" @() "No $($script:SelectedGamePlatform) games are imported yet.";return}

    $info=New-Object System.Windows.Controls.Border
    $info.Height=188;$info.CornerRadius=18;$info.Background='#76080D16';$info.BorderBrush='#3BFFFFFF';$info.BorderThickness='1';$info.Padding='24,18,24,18';$info.Margin='0,0,0,14'
    $infoGrid=New-Object System.Windows.Controls.Grid
    $infoGrid.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition -Property @{Width='*'}))
    $infoGrid.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition -Property @{Width='Auto'}))
    $textPanel=New-Object System.Windows.Controls.StackPanel;$textPanel.VerticalAlignment='Top'
    $eyebrow=New-Object System.Windows.Controls.TextBlock;$eyebrow.Text="$($script:SelectedGamePlatform.ToUpperInvariant())  SHELF";$eyebrow.FontSize=12;$eyebrow.FontWeight='Bold';$eyebrow.Foreground='#E7C45E';$textPanel.Children.Add($eyebrow)|Out-Null
    $script:ShelfTitleText=New-Object System.Windows.Controls.TextBlock;$script:ShelfTitleText.FontSize=30;$script:ShelfTitleText.FontWeight='Bold';$script:ShelfTitleText.Foreground='White';$script:ShelfTitleText.Margin='0,6,0,0';$script:ShelfTitleText.TextWrapping='Wrap';$script:ShelfTitleText.MaxWidth=880;$script:ShelfTitleText.MaxHeight=78;$textPanel.Children.Add($script:ShelfTitleText)|Out-Null
    $script:ShelfDetailText=New-Object System.Windows.Controls.TextBlock;$script:ShelfDetailText.FontSize=13;$script:ShelfDetailText.Foreground='#D2DBE8';$script:ShelfDetailText.Margin='0,8,0,0';$script:ShelfDetailText.TextWrapping='Wrap';$script:ShelfDetailText.MaxWidth=930;$script:ShelfDetailText.MaxHeight=60;$textPanel.Children.Add($script:ShelfDetailText)|Out-Null
    $script:ShelfPreviewCountText=New-Object System.Windows.Controls.TextBlock;$script:ShelfPreviewCountText.FontSize=12;$script:ShelfPreviewCountText.Foreground='#9EB1C9';$script:ShelfPreviewCountText.Margin='0,10,0,0';$textPanel.Children.Add($script:ShelfPreviewCountText)|Out-Null
    $infoGrid.Children.Add($textPanel)|Out-Null

    $badge=New-Object System.Windows.Controls.Border;$badge.CornerRadius=16;$badge.BorderBrush='#55FFFFFF';$badge.BorderThickness='1';$badge.Background='#36000000';$badge.Padding='22,12';$badge.VerticalAlignment='Top';[System.Windows.Controls.Grid]::SetColumn($badge,1)
    $badgeStack=New-Object System.Windows.Controls.StackPanel;$badgeStack.Orientation='Horizontal';$badgeIcon=New-PlatformIconImage $script:SelectedGamePlatform 28;$badgeStack.Children.Add($badgeIcon)|Out-Null;$badgeText=New-Object System.Windows.Controls.TextBlock;$badgeText.Text=$script:SelectedGamePlatform.ToUpperInvariant();$badgeText.FontSize=14;$badgeText.FontWeight='Bold';$badgeText.Foreground='White';$badgeText.VerticalAlignment='Center';$badgeText.Margin='9,0,0,0';$badgeStack.Children.Add($badgeText)|Out-Null;$badge.Child=$badgeStack;$infoGrid.Children.Add($badge)|Out-Null
    $info.Child=$infoGrid;$script:ActionPanel.Children.Add($info)|Out-Null

    $previewWrap=New-Object System.Windows.Controls.Border
    $previewWrap.Height=118;$previewWrap.CornerRadius=18;$previewWrap.Background='#44000000';$previewWrap.BorderBrush='#32FFFFFF';$previewWrap.BorderThickness='1';$previewWrap.Padding='16';$previewWrap.Margin='0,0,0,210'
    $previewGrid=New-Object System.Windows.Controls.Grid
    $previewGrid.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition -Property @{Width='200'}))
    $previewGrid.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition -Property @{Width='*'}))
    $script:ShelfPreviewImage=New-Object System.Windows.Controls.Image;$script:ShelfPreviewImage.Stretch='UniformToFill';$script:ShelfPreviewImage.Margin='0';$script:ShelfPreviewImage.HorizontalAlignment='Stretch';$script:ShelfPreviewImage.VerticalAlignment='Stretch'
    $previewImageBorder=New-Object System.Windows.Controls.Border;$previewImageBorder.CornerRadius=12;$previewImageBorder.ClipToBounds=$true;$previewImageBorder.Child=$script:ShelfPreviewImage;$previewGrid.Children.Add($previewImageBorder)|Out-Null
    $previewTextPanel=New-Object System.Windows.Controls.StackPanel;$previewTextPanel.Margin='18,0,0,0';[System.Windows.Controls.Grid]::SetColumn($previewTextPanel,1)
    $previewLabel=New-Object System.Windows.Controls.TextBlock;$previewLabel.Text='ARTWORK PREVIEW';$previewLabel.FontSize=11;$previewLabel.FontWeight='Bold';$previewLabel.Foreground='#E7C45E';$previewTextPanel.Children.Add($previewLabel)|Out-Null
    $previewSub=New-Object System.Windows.Controls.TextBlock;$previewSub.Text='Use LB/RB to browse available cover and game art.';$previewSub.FontSize=13;$previewSub.Foreground='#D8E0ED';$previewSub.Margin='0,6,0,0';$previewTextPanel.Children.Add($previewSub)|Out-Null
    $script:ShelfPreviewThumbPanel=New-Object System.Windows.Controls.StackPanel;$script:ShelfPreviewThumbPanel.Orientation='Horizontal';$script:ShelfPreviewThumbPanel.Margin='0,14,0,0';$previewTextPanel.Children.Add($script:ShelfPreviewThumbPanel)|Out-Null
    $previewGrid.Children.Add($previewTextPanel)|Out-Null
    $previewWrap.Child=$previewGrid;$script:ActionPanel.Children.Add($previewWrap)|Out-Null

    $start=$script:ActionButtons.Count;$row=New-Object System.Windows.Controls.StackPanel;$row.Orientation='Horizontal';$row.Margin='14,0,30,0';$row.VerticalAlignment='Bottom'
    for($i=0;$i -lt $script:ShelfEntries.Count;$i++){
        $globalIndex=$script:GameHubLaunchEntries.Count
        $entry=$script:ShelfEntries[$i]
        $script:GameHubLaunchEntries+=$entry
        $button=New-ShelfCard $entry "hub-game:$globalIndex"
        $row.Children.Add($button)|Out-Null;$script:ActionButtons+=$button;$script:CurrentActions+=(New-Action "hub-game:$globalIndex" ([string](Get-EntryProperty $entry 'Name')))
    }
    $scroll=New-Object System.Windows.Controls.ScrollViewer;$scroll.HorizontalScrollBarVisibility='Hidden';$scroll.VerticalScrollBarVisibility='Disabled';$scroll.PanningMode='HorizontalOnly';$scroll.Content=$row;$scroll.Margin='0,0,0,6';$script:ActionPanel.Children.Add($scroll)|Out-Null
    $script:HomeRows+=,[pscustomobject]@{Start=$start;Count=$script:ShelfEntries.Count;Platform=$false}
    Update-ShelfSelection
}

function Render-PlatformLibrary {
    $script:GameHubLaunchEntries=@()
    $all=@(Get-PlatformLibraryGames $script:SelectedGamePlatform|Sort-Object {[string](Get-EntryProperty $_ 'Name')})
    if($all.Count -eq 0){Add-GameHubRail "$($script:SelectedGamePlatform) Library" @() "No $($script:SelectedGamePlatform) games are imported yet.";return}
    $shelfSize=18
    for($offset=0;$offset -lt $all.Count;$offset+=$shelfSize){
        $count=[math]::Min($shelfSize,$all.Count-$offset)
        $shelf=@($all[$offset..($offset+$count-1)])
        $title=if($offset -eq 0){"$($script:SelectedGamePlatform) Library"}else{"More $($script:SelectedGamePlatform) Games"}
        Add-GameHubRail $title $shelf ''
    }
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
        default { Add-PlatformRail }
    }
}

function Render-Page {
    if($null -eq $script:PageTitle){return}
    $page=Get-PageDefinition $script:SelectedTab;$script:ActionPanel.Children.Clear();$script:ActionButtons=@();$script:CurrentActions=@();$script:HomeRows=@();$script:SliderControls=@{}
    $isHome = ($script:SelectedTab -eq 0 -and -not $script:SubPage)
    $isGames = ($script:SelectedTab -eq 1 -and $script:SubPage -ne 'ProviderGame')
    $isApps = ($script:SelectedTab -eq 2 -and -not $script:SubPage)
    if($isHome){
        $script:PageTitle.Visibility='Collapsed';$script:PageSubtitle.Visibility='Collapsed';$script:HeroPanel.Visibility='Collapsed';[System.Windows.Controls.Grid]::SetColumnSpan($script:MainListArea,2);$script:MainListArea.Margin='0'
        Add-HomeRail 'Recently Launched Games' (Convert-ToStableArray $script:Config.RecentGames) 'recent-game' 'Launch a game and it will appear here.'
        Add-HomeRail 'Recently Launched Apps' (Convert-ToStableArray $script:Config.RecentApps) 'recent-app' 'Launch an app and it will appear here.'
    }elseif($isGames){
        $script:PageTitle.Visibility='Collapsed';$script:PageSubtitle.Visibility='Collapsed';$script:HeroPanel.Visibility='Collapsed';[System.Windows.Controls.Grid]::SetColumnSpan($script:MainListArea,2);$script:MainListArea.Margin='0'
        Render-GamesHub
    }elseif($isApps){
        $script:PageTitle.Visibility='Collapsed';$script:PageSubtitle.Visibility='Collapsed';$script:HeroPanel.Visibility='Collapsed';[System.Windows.Controls.Grid]::SetColumnSpan($script:MainListArea,2);$script:MainListArea.Margin='0'
        Render-AppsHub
    }else{
        # The old prototype-only Current Experience/Safe Prototype panel reserved
        # almost a quarter of the screen and could reappear as a large empty dark
        # column after returning from a native platform. Keep every normal page
        # full-width; page title/subtitle remain above the controller-friendly list.
        $script:PageTitle.Visibility='Visible';$script:PageSubtitle.Visibility='Visible';$script:HeroPanel.Visibility='Collapsed';[System.Windows.Controls.Grid]::SetColumnSpan($script:MainListArea,2);$script:MainListArea.Margin='0'
        $script:PageTitle.Text=$page.Title;$script:PageSubtitle.Text=$(if($script:ConsoleNotice){$message=$script:ConsoleNotice;$script:ConsoleNotice='';$message}else{$page.Subtitle});$script:HeroTitle.Text=$page.Hero;$script:HeroText.Text=$page.HeroText;$script:CurrentActions=Convert-ToStableArray $page.Actions
        foreach($action in $script:CurrentActions){
            $button=New-Object System.Windows.Controls.Button;$button.Style=$script:Window.FindResource('ActionButtonStyle');$button.Tag=$action.Id;$button.Margin='0,0,0,10';$button.HorizontalContentAlignment='Stretch'
            $grid=New-Object System.Windows.Controls.Grid;$grid.Margin='3';$grid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition -Property @{Height='Auto'}));$grid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition -Property @{Height='Auto'}));$grid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition -Property @{Height='Auto'}))
            $title=New-Object System.Windows.Controls.TextBlock;$title.Text=$action.Title;$title.FontSize=18;$title.FontWeight='SemiBold';$title.Foreground='White';$title.TextWrapping='Wrap';$title.LineHeight=23;$title.LineStackingStrategy='BlockLineHeight';$title.Padding='0,1,0,2';[System.Windows.Controls.Grid]::SetRow($title,0);$grid.Children.Add($title)|Out-Null
            if([string](Get-EntryProperty $action 'Kind' '') -eq 'Slider'){
                $sliderGrid=New-Object System.Windows.Controls.Grid;$sliderGrid.Margin='0,10,0,4';$sliderGrid.Width=430;$sliderGrid.HorizontalAlignment='Left';$sliderGrid.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition -Property @{Width='340'}));$sliderGrid.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition -Property @{Width='70'}));[System.Windows.Controls.Grid]::SetRow($sliderGrid,1)
                $slider=New-Object System.Windows.Controls.Slider;$slider.Minimum=0;$slider.Maximum=100;$slider.Value=[int](Get-EntryProperty $action 'Value' 0);$slider.IsHitTestVisible=$false;$slider.Width=330;$slider.HorizontalAlignment='Left';$slider.Height=22;$slider.VerticalAlignment='Center';$sliderGrid.Children.Add($slider)|Out-Null
                $valueText=New-Object System.Windows.Controls.TextBlock;$valueText.Text=([int](Get-EntryProperty $action 'Value' 0)).ToString()+'%';$valueText.FontSize=16;$valueText.FontWeight='Bold';$valueText.Foreground='#F2D36B';$valueText.HorizontalAlignment='Right';$valueText.VerticalAlignment='Center';[System.Windows.Controls.Grid]::SetColumn($valueText,1);$sliderGrid.Children.Add($valueText)|Out-Null
                $grid.Children.Add($sliderGrid)|Out-Null
                $script:SliderControls[[string]$action.Id]=[pscustomobject]@{Slider=$slider;Text=$valueText}
            }
            $desc=New-Object System.Windows.Controls.TextBlock;$desc.Text=$action.Description;$desc.FontSize=13;$desc.Margin='0,5,0,1';$desc.Foreground='#AEBBD0';$desc.TextWrapping='Wrap';$desc.LineHeight=18;$desc.LineStackingStrategy='BlockLineHeight';$desc.MaxHeight=78;[System.Windows.Controls.Grid]::SetRow($desc,2);$grid.Children.Add($desc)|Out-Null;$button.Content=$grid
            $button.Add_Click({param($sender,$eventArgs)try{Set-KeyboardActive;Invoke-UiFeedback 'Confirm';Invoke-Action ([string]$sender.Tag)}catch{Set-ConsoleNotice "Action failed: $($_.Exception.Message)" 'ERROR'}})
            $button.Add_MouseEnter({param($sender,$eventArgs)if(-not(Test-HcMouseHoverAllowed)){return};Set-KeyboardActive;$idx=[array]::IndexOf($script:ActionButtons,$sender);if ($idx -ge 0) {$script:SelectedAction=$idx;Update-ActionVisuals}})
            $script:ActionPanel.Children.Add($button)|Out-Null;$script:ActionButtons+=$button
        }
    }
    if($script:SelectedAction -ge $script:ActionButtons.Count){$script:SelectedAction=0};Update-ActionVisuals;Update-NavVisuals;Update-Footer
    $platformActive=($script:SelectedTab -eq 1 -and $script:SubPage -in @('PlatformChoice','PlatformHome','PlatformShelf','PlatformLibrary','ProviderStore','ProviderGame'))
    Set-PlatformBackground $platformActive
}


function Update-Footer {
    try{
        if ($null -eq $script:PromptPanel) { return }
        Render-PromptFooter
        $family = Get-PromptFamily
        if($null -ne $script:ControllerText -and $null -ne $script:ControllerText.PSObject.Properties['Text']){
            $script:ControllerText.Text = "$($script:ConnectedControllerName)  -  $family prompts"
        }
    }catch{
        # A controller can arrive while the page visual tree is being replaced.
        # Never let that transient WPF race terminate the input dispatcher.
        if(((Get-Date)-$script:LastRawControllerErrorAt).TotalSeconds -gt 5){
            $script:LastRawControllerErrorAt=Get-Date
            Write-Log "Controller footer update skipped: $($_.Exception.Message)" 'WARN'
        }
    }
}

function Show-ControllerDiagnostics { $script:SubPage='Controllers';$script:SelectedAction=0;Render-Page }

function Use-HorizontalRailNavigation {
    if($script:SelectedTab -eq 0 -and -not $script:SubPage){return $true}
    if($script:SelectedTab -eq 1 -and $script:SubPage -ne 'ProviderGame'){return $true}
    if($script:SelectedTab -eq 2 -and -not $script:SubPage){return $true}
    return $false
}

function Get-ActiveHomeRow {
    foreach($candidate in $script:HomeRows){
        if($candidate.Count -gt 0 -and $script:SelectedAction -ge $candidate.Start -and $script:SelectedAction -lt ($candidate.Start + $candidate.Count)){return $candidate}
    }
    return $null
}

function Move-HomeHorizontal { param([int]$Delta)
    if($script:ActionButtons.Count -eq 0){return}
    $row=Get-ActiveHomeRow
    if($null -eq $row){$row=@($script:HomeRows|Where-Object{$_.Count -gt 0}|Select-Object -First 1);if($null -eq $row){return};$script:SelectedAction=$row.Start}
    $local=$script:SelectedAction-$row.Start
    $next=[math]::Max(0,[math]::Min($row.Count-1,$local+$Delta))
    if($next -ne $local){$script:PreferredRailColumn=$next;Invoke-UiFeedback 'Navigate';$script:SelectedAction=$row.Start+$next;Update-ActionVisuals}
}

function Move-HomeVertical { param([int]$Delta)
    $active=-1
    for($i=0;$i -lt $script:HomeRows.Count;$i++){if($script:HomeRows[$i].Count -gt 0 -and $script:SelectedAction -ge $script:HomeRows[$i].Start -and $script:SelectedAction -lt ($script:HomeRows[$i].Start+$script:HomeRows[$i].Count)){$active=$i;break}}
    if($active -lt 0){return}
    $target=$active+$Delta
    while($target -ge 0 -and $target -lt $script:HomeRows.Count -and $script:HomeRows[$target].Count -eq 0){$target+=$Delta}
    if($target -lt 0 -or $target -ge $script:HomeRows.Count){return}
    $column=[math]::Max(0,$script:PreferredRailColumn)
    $script:SelectedAction=$script:HomeRows[$target].Start+[math]::Min($column,$script:HomeRows[$target].Count-1)
    Invoke-UiFeedback 'Navigate'
    Update-ActionVisuals
}

function Move-Tab {
    param([int]$Delta)
    # Top-level pages are selected only from the visible Menu/Guide overlay.
    if((Get-Command Show-HcMainMenu -ErrorAction SilentlyContinue) -and -not (Test-HcMainMenuVisible)){Show-HcMainMenu}
}

function Move-Action {
    param([int]$Delta)
    if ($script:ActionButtons.Count -eq 0) { return }
    $next=[math]::Max(0,[math]::Min($script:ActionButtons.Count-1,$script:SelectedAction+$Delta))
    if($next -eq $script:SelectedAction){return}
    Invoke-UiFeedback 'Navigate'
    $script:SelectedAction=$next
    Update-ActionVisuals
}

function Get-SelectedActionObject {
    if($script:SelectedAction -lt 0 -or $script:SelectedAction -ge $script:CurrentActions.Count){return $null}
    return $script:CurrentActions[$script:SelectedAction]
}

function Adjust-SelectedSlider {
    param([int]$Delta)
    $action=Get-SelectedActionObject
    if($null -eq $action -or [string](Get-EntryProperty $action 'Kind' '') -ne 'Slider'){return $false}
    $value=0
    switch([string]$action.Id){
        'music-volume-slider' {
            $value=[math]::Max(0,[math]::Min(100,([int]$script:Config.MusicVolume)+$Delta));$script:Config.MusicVolume=$value;Save-Config;Update-BackgroundMusic
        }
        'audio-volume-slider' {
            $value=[math]::Max(0,[math]::Min(100,(Get-AudioVolume)+$Delta));try{[HuymaierConsole.Native.AudioBridge]::SetMasterVolume($value/100.0)}catch{}
        }
        default{return $false}
    }
    try{$action.Value=$value}catch{}
    try{$control=$script:SliderControls[[string]$action.Id];if($control){$control.Slider.Value=$value;$control.Text.Text=($value.ToString()+'%')}}catch{}
    Invoke-UiFeedback 'Navigate'
    return $true
}

function Invoke-SelectedAction {
    if ($script:CurrentActions.Count -eq 0) { return }
    if ($script:SelectedAction -lt 0 -or $script:SelectedAction -ge $script:CurrentActions.Count) { return }
    Invoke-UiFeedback 'Confirm'
    Invoke-Action $script:CurrentActions[$script:SelectedAction].Id
}

function Toggle-WindowMode {
    if ($script:Window.WindowState -eq 'Maximized' -and $script:Window.WindowStyle -eq 'None') {
        $script:Window.WindowStyle = 'SingleBorderWindow'
        $script:Window.ResizeMode = 'CanResize'
        $script:Window.WindowState = 'Normal'
        $script:Window.Width = 1280
        $script:Window.Height = 760
        $script:Window.WindowStartupLocation = 'CenterScreen'
    } else {
        $script:Window.WindowStyle = 'None'
        $script:Window.ResizeMode = 'NoResize'
        $script:Window.WindowState = 'Maximized'
    }
}

function Is-NewButtonPress {
    param([int]$Mask, [int]$Flag)
    return (($Mask -band $Flag) -ne 0 -and ($script:LastGamepadMask -band $Flag) -eq 0)
}


function Get-RawControllerVirtualState {
    param($Raw)
    $result = [pscustomobject]@{ Mask = 0; Direction = ''; Activity = $false; Eligible = $true }
    if ($null -eq $Raw) { return $result }
    try {
        $displayName = ''
        try { $displayName = [string]$Raw.DisplayName } catch { }
        if (Test-IsMouseLikeControllerName $displayName) { $result.Eligible = $false; return $result }
        $buttonCount = [int]$Raw.ButtonCount
        $switchCount = [int]$Raw.SwitchCount
        $axisCount = [int]$Raw.AxisCount
        $buttons = New-Object 'System.Boolean[]' $buttonCount
        $switchType = [Windows.Gaming.Input.GameControllerSwitchPosition,Windows.Gaming.Input,ContentType=WindowsRuntime]
        $switches = [Array]::CreateInstance($switchType, $switchCount)
        $axes = New-Object 'System.Double[]' $axisCount
        [void]$Raw.GetCurrentReading($buttons, $switches, $axes)

        $rawFamily = Get-FamilyFromRawController $Raw
        for ($i = 0; $i -lt $buttonCount; $i++) {
            if ( -not $buttons[$i]) { continue }
            $result.Activity = $true
            $label = ''
            try { $label = [string]$Raw.GetButtonLabel([int]$i) } catch { }
            switch -Regex ($label) {
                '^(XboxA|LetterA|Cross)$' { $result.Mask = $result.Mask -bor 4; continue }
                '^(XboxB|LetterB|Circle)$' { $result.Mask = $result.Mask -bor 8; continue }
                '^(XboxX|LetterX|Square)$' { $result.Mask = $result.Mask -bor 16; continue }
                '^(XboxY|LetterY|Triangle)$' { $result.Mask = $result.Mask -bor 32; continue }
                '^(XboxMenu|XboxStart|Menu|Start|Options)$' { $result.Mask = $result.Mask -bor 1; continue }
                '^(XboxGuide|Guide|Home|PS|PlayStation)$' { $result.Mask = $result.Mask -bor 2; continue }
                '^(XboxView|View|Back|Share|Create)$' { $result.Mask = $result.Mask -bor 4096; continue }
                '^(XboxLeftBumper|LeftBumper|LetterL)$' { $result.Mask = $result.Mask -bor 1024; continue }
                '^(XboxRightBumper|RightBumper|LetterR)$' { $result.Mask = $result.Mask -bor 2048; continue }
                '(XboxUp|^Up$)' { $result.Direction = 'Up'; continue }
                '(XboxDown|^Down$)' { $result.Direction = 'Down'; continue }
                '(XboxLeft|^Left$)' { $result.Direction = 'Left'; continue }
                '(XboxRight|^Right$)' { $result.Direction = 'Right'; continue }
            }

            # Some HID drivers expose no labels. These conservative index
            # fallbacks cover the common native reports for each family.
            if ([string]::IsNullOrWhiteSpace($label) -or $label -eq 'None') {
                if ($rawFamily -eq 'PlayStation') {
                    if ($i -eq 1) { $result.Mask = $result.Mask -bor 4 }
                    elseif ($i -eq 2) { $result.Mask = $result.Mask -bor 8 }
                    elseif ($i -eq 0) { $result.Mask = $result.Mask -bor 16 }
                    elseif ($i -eq 3) { $result.Mask = $result.Mask -bor 32 }
                    elseif ($i -eq 9) { $result.Mask = $result.Mask -bor 1 }
                    elseif ($i -eq 12) { $result.Mask = $result.Mask -bor 2 }
                    elseif ($i -eq 4) { $result.Mask = $result.Mask -bor 1024 }
                    elseif ($i -eq 5) { $result.Mask = $result.Mask -bor 2048 }
                } elseif ($rawFamily -eq 'Nintendo') {
                    if ($i -eq 1) { $result.Mask = $result.Mask -bor 4 }
                    elseif ($i -eq 0) { $result.Mask = $result.Mask -bor 8 }
                    elseif ($i -eq 3) { $result.Mask = $result.Mask -bor 16 }
                    elseif ($i -eq 2) { $result.Mask = $result.Mask -bor 32 }
                    elseif ($i -eq 9) { $result.Mask = $result.Mask -bor 1 }
                    elseif ($i -eq 4) { $result.Mask = $result.Mask -bor 1024 }
                    elseif ($i -eq 5) { $result.Mask = $result.Mask -bor 2048 }
                } else {
                    if ($i -eq 0) { $result.Mask = $result.Mask -bor 4 }
                    elseif ($i -eq 1) { $result.Mask = $result.Mask -bor 8 }
                    elseif ($i -eq 2) { $result.Mask = $result.Mask -bor 16 }
                    elseif ($i -eq 3) { $result.Mask = $result.Mask -bor 32 }
                    elseif ($i -eq 7) { $result.Mask = $result.Mask -bor 1 }
                    elseif ($i -eq 4) { $result.Mask = $result.Mask -bor 1024 }
                    elseif ($i -eq 5) { $result.Mask = $result.Mask -bor 2048 }
                }
            }
        }

        for ($i = 0; $i -lt $switchCount; $i++) {
            $position = [string]$switches.GetValue($i)
            if ($position -and $position -ne 'Center') { $result.Activity = $true }
            switch -Regex ($position) {
                '^Up' { $result.Direction = 'Up'; break }
                '^Down' { $result.Direction = 'Down'; break }
                'Left$' { $result.Direction = 'Left'; break }
                'Right$' { $result.Direction = 'Right'; break }
            }
        }

        # RawGameController axes are normalized to 0..1. Use only axes that
        # appear centered to avoid treating resting triggers as thumbsticks.
        if ( -not $result.Direction -and $axisCount -ge 2) {
            $x = [double]$axes[0]
            $y = [double]$axes[1]
            $xCentered = ($x -ge 0.32 -and $x -le 0.68)
            $yCentered = ($y -ge 0.32 -and $y -le 0.68)
            if ($yCentered -and $x -gt 0.78) { $result.Direction = 'Right'; $result.Activity = $true }
            elseif ($yCentered -and $x -lt 0.22) { $result.Direction = 'Left'; $result.Activity = $true }
            elseif ($xCentered -and $y -gt 0.78) { $result.Direction = 'Down'; $result.Activity = $true }
            elseif ($xCentered -and $y -lt 0.22) { $result.Direction = 'Up'; $result.Activity = $true }
        }
    } catch {
        if (((Get-Date) - $script:LastRawControllerErrorAt).TotalSeconds -ge 30) {
            $script:LastRawControllerErrorAt = Get-Date
            Write-Log "Raw controller read failed: $($_.Exception.Message)" 'WARN'
        }
    }
    return $result
}

function Apply-ControllerNavigation {
    param([int]$Mask, [string]$Direction)
    if((Get-Date) -lt $script:ControllerInputGuardUntil){$script:LastGamepadMask=0;$script:LastDirection='';$script:NextDirectionAt=[datetime]::MinValue;return}
    if(-not (Test-ConsoleHasInputFocus)){$script:LastGamepadMask=0;$script:LastDirection='';$script:NextDirectionAt=[datetime]::MinValue;return}
    # Guide/Home is the one global controller command. It must escape any local
    # keyboard/modal/browser surface and focus Huymaier Quick Access.
    if(Is-NewButtonPress $Mask 2){
        try{if($script:KeyboardActive){Close-NativeKeyboard $false}}catch{}
        try{if((Get-Command Close-HcChoicePopup -ErrorAction SilentlyContinue) -and (Test-HcChoicePopupVisible)){Close-HcChoicePopup}}catch{}
        if(Get-Command Show-HcMainMenu -ErrorAction SilentlyContinue){Show-HcMainMenu}else{Focus-TopNavigation}
        $script:LastGamepadMask=$Mask
        return
    }
    if($script:KeyboardActive){Apply-NativeKeyboardNavigation $Mask $Direction;return}
    if((Get-Command Handle-HcChoicePopupController -ErrorAction SilentlyContinue) -and (Handle-HcChoicePopupController $Mask $Direction)){return}
    if((Get-Command Handle-HcBrowserController -ErrorAction SilentlyContinue) -and (Handle-HcBrowserController $Mask $Direction)){return}
    if((Get-Command Handle-HcMainMenuController -ErrorAction SilentlyContinue) -and (Handle-HcMainMenuController $Mask $Direction)){return}
    if((Get-Command Handle-HcGameModalController -ErrorAction SilentlyContinue) -and (Handle-HcGameModalController $Mask $Direction)){return}

    if($script:NavigationLayer -eq 'Navigation'){
        # The legacy hidden top-navigation layer no longer cycles pages.
        $script:NavigationLayer='Content'
        if((Get-Command Show-HcMainMenu -ErrorAction SilentlyContinue) -and -not (Test-HcMainMenuVisible)){Show-HcMainMenu}
        $script:LastDirection='';$script:NextDirectionAt=[datetime]::MinValue;$script:LastGamepadMask=$Mask
        return
    }

    $now=Get-Date
    if($Direction){
        if($Direction -ne $script:LastDirection -or $now -ge $script:NextDirectionAt){
            switch($Direction){
                'Left'  { if(-not (Adjust-SelectedSlider -5)){if(Use-HorizontalRailNavigation){Move-HomeHorizontal -1}} }
                'Right' { if(-not (Adjust-SelectedSlider 5)){if(Use-HorizontalRailNavigation){Move-HomeHorizontal 1}} }
                'Up'    { if(Use-HorizontalRailNavigation){Move-HomeVertical -1}else{Move-Action -1} }
                'Down'  { if(Use-HorizontalRailNavigation){Move-HomeVertical 1}else{Move-Action 1} }
            }
            $isNewDirection=($Direction -ne $script:LastDirection)
            $script:LastDirection=$Direction
            $script:NextDirectionAt=$now.AddMilliseconds($(if($isNewDirection){360}else{125}))
        }
    }else{$script:LastDirection='';$script:NextDirectionAt=[datetime]::MinValue}

    if(Is-NewButtonPress $Mask 4){Invoke-SelectedAction}
    if(Is-NewButtonPress $Mask 8){Handle-Back}
    if(Is-NewButtonPress $Mask 16){Invoke-SecondaryAction}
    if(Is-NewButtonPress $Mask 1){Invoke-UiFeedback 'Confirm';Set-Tab 8}
    # LB/RB belonged to the retired shelf-art preview strip. Do not call its
    # legacy handler while the shared cinematic shelf is active.
    if($script:SubPage -eq 'PlatformShelf' -and $null -ne $script:ShelfPreviewImage){
        if(Is-NewButtonPress $Mask 1024){[void](Move-ShelfArtworkPreview -1)}
        if(Is-NewButtonPress $Mask 2048){[void](Move-ShelfArtworkPreview 1)}
    }
    $script:LastGamepadMask=$Mask
}

function Process-Gamepads {
    if((Get-Date) -lt $script:ControllerInputGuardUntil){
        $script:LastGamepadMask=0;$script:LastDirection='';$script:NextDirectionAt=[datetime]::MinValue
        try{if('HuymaierConsole.NativeApp.NativeConsoleNavigation' -as [type]){[HuymaierConsole.NativeApp.NativeConsoleNavigation]::Reset()}}catch{}
        return
    }
    if(-not (Test-ConsoleHasInputFocus)){
        $script:LastGamepadMask=0;$script:LastDirection='';$script:NextDirectionAt=[datetime]::MinValue
        try{if('HuymaierConsole.NativeApp.NativeConsoleNavigation' -as [type]){[HuymaierConsole.NativeApp.NativeConsoleNavigation]::Reset()}}catch{}
        return
    }
    # v0.24.11 uses one neutral-armed physical controller source at a time.
    # This prevents mouse/joystick hybrids such as Swiftpoint Z/Z2 from being
    # combined with a DualSense and producing a permanently held direction.
    if('HuymaierConsole.NativeApp.NativeConsoleNavigation' -as [type]){
        try{
            $nativeCommand=[HuymaierConsole.NativeApp.NativeConsoleNavigation]::Poll()
            if([bool]$nativeCommand.Active){
                $family=[string]$nativeCommand.Family
                if($family -eq 'Gamepad'){$family='Xbox'}
                Set-ActiveInputFamily $family ([string]$nativeCommand.Name)
                Hide-ConsoleCursor
            }
            $nativeMask=0;$nativeDirection=''
            switch([string]$nativeCommand.Command){
                'Left' {$nativeDirection='Left'}
                'Right' {$nativeDirection='Right'}
                'Up' {$nativeDirection='Up'}
                'Down' {$nativeDirection='Down'}
                'Confirm' {$nativeMask=4}
                'Back' {$nativeMask=8}
                'Guide' {$nativeMask=2}
                'LeftShoulder' {$nativeMask=1024}
                'RightShoulder' {$nativeMask=2048}
            }
            Apply-ControllerNavigation $nativeMask $nativeDirection
            return
        }catch{Write-Log "Native controller routing failed; using compatibility input: $($_.Exception.Message)" 'WARN'}
    }
    $snap = Get-ControllerSnapshot

    $hidMask=0;$hidDirection='';$hidActive=$false;$hidController=$null;$hidConnected=$false
    foreach($hid in $snap.Hid){
        try{
            $age=((Get-Date).ToUniversalTime()-[datetime]$hid.LastSeenUtc).TotalMilliseconds
            if($age -le 3000){$hidConnected=$true}
            if($age -gt 350){continue}
            $hidMask=$hidMask -bor [int]$hid.Mask
            $hidKey="hid:$([string]$hid.DeviceHandle)"
            if(-not $script:NativeControllerNeutralCounts.ContainsKey($hidKey)){$script:NativeControllerNeutralCounts[$hidKey]=0}
            if(-not [string]$hid.Direction){$script:NativeControllerNeutralCounts[$hidKey]=[math]::Min(8,([int]$script:NativeControllerNeutralCounts[$hidKey]+1))}
            if([string]$hid.Direction -and [int]$script:NativeControllerNeutralCounts[$hidKey] -ge 3){$hidDirection=[string]$hid.Direction}
            if([bool]$hid.Activity){$hidActive=$true;$hidController=$hid}
        }catch{}
    }
    # A connected native Sony HID owns navigation even while idle. Without
    # this ownership rule, a mouse that exposes a DirectInput joystick (for
    # example Swiftpoint Z/Z2) can take over whenever the DualSense is neutral.
    if($hidConnected){
        $name='DualSense Wireless Controller'
        try{
            $displayHid=if($hidController){$hidController}else{$snap.Hid[0]}
            if([string]$displayHid.Name){$name=[string]$displayHid.Name}
        }catch{}
        Set-ActiveInputFamily 'PlayStation' $name
        if($hidActive){Hide-ConsoleCursor}
        Apply-ControllerNavigation $hidMask $hidDirection
        $signature="$($snap.Gamepads.Count)|$($snap.Raw.Count)|$($snap.Hid.Count)|$($snap.Legacy.Count)"
        if($signature -ne $script:LastControllerSignature){$script:LastControllerSignature=$signature;Update-Footer}
        return
    }

    if ($snap.Gamepads.Count -eq 0) {
        $rawMask = 0
        $rawDirection = ''
        $rawActive = $false
        $rawActiveController = $null
        $rawEligibleCount = 0
        foreach ($raw in $snap.Raw) {
            $state = Get-RawControllerVirtualState $raw
            if(-not [bool]$state.Eligible){continue}
            $rawEligibleCount++
            $rawMask = $rawMask -bor [int]$state.Mask
            if ($state.Direction) { $rawDirection = [string]$state.Direction }
            if ($state.Activity) { $rawActive = $true; $rawActiveController = $raw }
        }

        $legacyMask=0;$legacyDirection='';$legacyActive=$false;$legacyController=$null;$legacyEligibleCount=0
        if(-not $rawActive){
            foreach($legacy in $snap.Legacy){
                $state=Get-LegacyControllerVirtualState $legacy
                if(-not [bool]$state.Eligible){continue}
                $legacyEligibleCount++
                $legacyMask=$legacyMask -bor [int]$state.Mask
                if($state.Direction){$legacyDirection=[string]$state.Direction}
                if($state.Activity){$legacyActive=$true;$legacyController=$legacy}
            }
        }

        if ($rawActive) {
            $family = Get-FamilyFromRawController $rawActiveController
            $name = 'Raw Game Controller'
            try { $name = [string]$rawActiveController.DisplayName } catch { }
            Set-ActiveInputFamily $family $name
            Hide-ConsoleCursor
            Apply-ControllerNavigation $rawMask $rawDirection
        } elseif($legacyActive){
            $family=Get-FamilyFromLegacyController $legacyController
            $name='Game Controller';try{$name=[string]$legacyController.Name}catch{}
            Set-ActiveInputFamily $family $name
            Hide-ConsoleCursor
            Apply-ControllerNavigation $legacyMask $legacyDirection
        } else {
            if ($rawEligibleCount -eq 0 -and $legacyEligibleCount -eq 0 -and $script:Config.PromptOverride -eq 'Auto' -and ((Get-Date) - $script:LastKeyboardInputAt).TotalSeconds -gt 1) {
                Set-ActiveInputFamily 'Keyboard' 'Keyboard / Mouse'
            }
            Apply-ControllerNavigation 0 ''
        }

        $signature = "0|$($snap.Raw.Count)|$($snap.Hid.Count)|$($snap.Legacy.Count)"
        if ($signature -ne $script:LastControllerSignature) {
            $script:LastControllerSignature = $signature
            Update-Footer
        }
        return
    }

    $combinedMask = 0
    $direction = ''
    $activeIndex = 0
    $activityDetected = $false

    for ($i=0; $i -lt $snap.Gamepads.Count; $i++) {
        try {
            $reading = $snap.Gamepads[$i].GetCurrentReading()
            $mask = [int]$reading.Buttons
            # Windows.Gaming.Input bit 2 is View/Back, not the Xbox system Guide button.
            $mask = $mask -band (-bnot 2)
            $combinedMask = $combinedMask -bor $mask
            $x = [double]$reading.LeftThumbstickX
            $y = [double]$reading.LeftThumbstickY
            if ($mask -ne 0 -or [math]::Abs($x) -gt 0.35 -or [math]::Abs($y) -gt 0.35) {
                $activeIndex = $i
                $script:ActiveGamepadIndex = $i
                $activityDetected = $true
            }
            if (($mask -band 256) -ne 0 -or $x -lt -0.65) { $direction = 'Left' }
            elseif (($mask -band 512) -ne 0 -or $x -gt 0.65) { $direction = 'Right' }
            elseif (($mask -band 64) -ne 0 -or $y -gt 0.65) { $direction = 'Up' }
            elseif (($mask -band 128) -ne 0 -or $y -lt -0.65) { $direction = 'Down' }
        } catch { }
    }

    if ($activityDetected) {
        $raw = $null
        foreach ($candidate in $snap.Raw) {
            $candidateState = Get-RawControllerVirtualState $candidate
            if ($candidateState.Activity) { $raw = $candidate; break }
        }
        if ($null -eq $raw -and $snap.Raw.Count -gt 0) {
            $knownPhysical = Convert-ToStableArray ($snap.Raw | Where-Object { (Get-FamilyFromRawController $_) -ne 'Xbox' })
            if ($knownPhysical.Count -gt 0) { $raw = $knownPhysical[0] }
            elseif ($activeIndex -lt $snap.Raw.Count) { $raw = $snap.Raw[$activeIndex] }
            else { $raw = $snap.Raw[0] }
        }
        $family = Get-FamilyFromRawController $raw
        $name = 'Game Controller'
        try { if ($raw) { $name = [string]$raw.DisplayName } } catch { }
        Set-ActiveInputFamily $family $name
        Hide-ConsoleCursor
    }

    Apply-ControllerNavigation $combinedMask $direction
    $signature = "$($snap.Gamepads.Count)|$($snap.Raw.Count)|$($snap.Hid.Count)|$($snap.Legacy.Count)"
    if ($signature -ne $script:LastControllerSignature) {
        $script:LastControllerSignature = $signature
        Update-Footer
    }
}

function New-NavIcon {
    param([string]$Name)
    $data = switch ($Name) {
        'Home'          { 'M3,10 L12,3 L21,10 L21,21 L14,21 L14,14 L10,14 L10,21 L3,21 Z' }
        'Games'         { 'M7,8 L17,8 C19.5,8 21,10 21.5,13 L22,17 C22.4,19.2 20.2,20.5 18.5,19 L16,17 L8,17 L5.5,19 C3.8,20.5 1.6,19.2 2,17 L2.5,13 C3,10 4.5,8 7,8 Z M7,11 L7,15 M5,13 L9,13 M16.5,12 L16.5,12.1 M19,14.5 L19,14.6' }
        'Apps'          { 'M3,3 H10 V10 H3 Z M14,3 H21 V10 H14 Z M3,14 H10 V21 H3 Z M14,14 H21 V21 H14 Z' }
        'Web'           { 'M12,3 A9,9 0 1 1 11.99,3 M3,12 H21 M12,3 C8,7 8,17 12,21 M12,3 C16,7 16,17 12,21' }
        'Downloads'     { 'M12,3 V15 M7,10 L12,15 L17,10 M4,20 H20' }
        'Import'        { 'M12,3 V15 M7,10 L12,15 L17,10 M4,19 H20 M5,22 H19' }
        'File Explorer' { 'M3,6 H10 L12,8 H21 V20 H3 Z M3,10 H21' }
        'Settings'      { 'M12,2 L14,4 L17,3 L18,6 L21,7 L20,10 L22,12 L20,14 L21,17 L18,18 L17,21 L14,20 L12,22 L10,20 L7,21 L6,18 L3,17 L4,14 L2,12 L4,10 L3,7 L6,6 L7,3 L10,4 Z M12,8 A4,4 0 1 1 11.99,8' }
        'Power'         { 'M12,3 V12 M6.2,6.2 A8,8 0 1 0 17.8,6.2' }
        default         { 'M4,4 H20 V20 H4 Z' }
    }
    $view = New-Object System.Windows.Controls.Viewbox
    $view.Width = 29
    $view.Height = 29
    $path = New-Object System.Windows.Shapes.Path
    $path.Data = [System.Windows.Media.Geometry]::Parse($data)
    $path.Stroke = '#EEF3FA'
    $path.Fill = 'Transparent'
    $path.StrokeThickness = 1.8
    $path.StrokeLineJoin = 'Round'
    $path.StrokeStartLineCap = 'Round'
    $path.StrokeEndLineCap = 'Round'
    $path.Width = 24
    $path.Height = 24
    $path.Stretch = 'Uniform'
    $view.Child = $path
    $view.Tag = $path
    return $view
}

if (Test-Path -LiteralPath $script:GameExperienceModulePath) {
    try { . $script:GameExperienceModulePath }
    catch { Write-Log "Game experience module load failed: $($_.Exception.Message)" 'ERROR' }
}
if (Test-Path -LiteralPath $script:ShellRedesignModulePath) {
    try { . $script:ShellRedesignModulePath }
    catch { Write-Log "Shell redesign module load failed: $($_.Exception.Message)" 'ERROR' }
}
if (Test-Path -LiteralPath $script:EmulatorPlatformsModulePath) {
    try { . $script:EmulatorPlatformsModulePath }
    catch { Write-Log "Emulator platform module load failed: $($_.Exception.Message)" 'ERROR' }
}
if (Test-Path -LiteralPath $script:WebBrowserModulePath) {
    try { . $script:WebBrowserModulePath }
    catch { Write-Log "Native browser module load failed: $($_.Exception.Message)" 'ERROR' }
}
if (Test-Path -LiteralPath $script:GameBarModulePath) {
    try { . $script:GameBarModulePath }
    catch { Write-Log "Huymaier Game Bar module load failed: $($_.Exception.Message)" 'ERROR' }
}

$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        x:Name="RootWindow"
        Title="Huymaier Console"
        WindowStyle="None"
        ResizeMode="NoResize"
        WindowState="Maximized"
        Background="#060A12"
        Foreground="#F5F7FB"
        FontFamily="Segoe UI Variable Display, Segoe UI"
        UseLayoutRounding="True"
        SnapsToDevicePixels="True"
        TextOptions.TextFormattingMode="Display"
        TextOptions.TextRenderingMode="ClearType">
    <Window.Resources>
        <Style TargetType="ScrollBar"><Setter Property="Opacity" Value="0"/><Setter Property="Width" Value="0"/><Setter Property="Height" Value="0"/><Setter Property="IsHitTestVisible" Value="False"/></Style>
        <Style x:Key="NavButtonStyle" TargetType="Button">
            <Setter Property="Width" Value="62"/>
            <Setter Property="Height" Value="58"/>
            <Setter Property="MinWidth" Value="62"/>
            <Setter Property="Margin" Value="0,0,12,0"/>
            <Setter Property="Padding" Value="0"/>
            <Setter Property="Background" Value="#151D2B"/>
            <Setter Property="Foreground" Value="#EAF0F8"/>
            <Setter Property="BorderBrush" Value="#2B3850"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="NavBorder" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="15">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="NavBorder" Property="Opacity" Value="0.88"/></Trigger>
                            <Trigger Property="IsPressed" Value="True"><Setter TargetName="NavBorder" Property="Opacity" Value="0.72"/></Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
        <Style x:Key="ActionButtonStyle" TargetType="Button">
            <Setter Property="MinHeight" Value="104"/>
            <Setter Property="Padding" Value="18,16"/>
            <Setter Property="Background" Value="#111A28"/>
            <Setter Property="Foreground" Value="#EAF0F8"/>
            <Setter Property="BorderBrush" Value="#26354A"/>
            <Setter Property="BorderThickness" Value="2"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="ActionBorder" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="12" Padding="{TemplateBinding Padding}">
                            <ContentPresenter HorizontalAlignment="{TemplateBinding HorizontalContentAlignment}" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="ActionBorder" Property="Opacity" Value="0.92"/></Trigger>
                            <Trigger Property="IsPressed" Value="True"><Setter TargetName="ActionBorder" Property="Opacity" Value="0.75"/></Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
    </Window.Resources>

    <Grid x:Name="RootGrid">
        <Grid.Background>
            <RadialGradientBrush Center="0.18,0.15" GradientOrigin="0.18,0.15" RadiusX="1.1" RadiusY="1.1">
                <GradientStop Color="#1A2A44" Offset="0"/>
                <GradientStop Color="#09111E" Offset="0.42"/>
                <GradientStop Color="#05080E" Offset="1"/>
            </RadialGradientBrush>
        </Grid.Background>

        <Grid x:Name="DynamicBackdrop" IsHitTestVisible="False" Opacity="0.96" ClipToBounds="True">
            <Viewbox Stretch="Fill">
                <Canvas Width="1920" Height="1080">
                    <Rectangle Width="1920" Height="1080">
                        <Rectangle.Fill>
                            <LinearGradientBrush StartPoint="0,0" EndPoint="1,1">
                                <GradientStop Color="#181F3658" Offset="0"/>
                                <GradientStop Color="#00131D2D" Offset="0.42"/>
                                <GradientStop Color="#201C3154" Offset="1"/>
                            </LinearGradientBrush>
                        </Rectangle.Fill>
                    </Rectangle>

                    <Ellipse Width="960" Height="960" Canvas.Left="-350" Canvas.Top="-420">
                        <Ellipse.Fill><RadialGradientBrush><GradientStop Color="#70D6B64F" Offset="0"/><GradientStop Color="#28C8A84E" Offset="0.48"/><GradientStop Color="#00C8A84E" Offset="1"/></RadialGradientBrush></Ellipse.Fill>
                        <Ellipse.RenderTransform><TranslateTransform x:Name="GoldGlowTransform"/></Ellipse.RenderTransform>
                    </Ellipse>
                    <Ellipse Width="1180" Height="1180" Canvas.Left="1100" Canvas.Top="280">
                        <Ellipse.Fill><RadialGradientBrush><GradientStop Color="#694474C2" Offset="0"/><GradientStop Color="#24315F9D" Offset="0.55"/><GradientStop Color="#00315F9D" Offset="1"/></RadialGradientBrush></Ellipse.Fill>
                        <Ellipse.RenderTransform><TranslateTransform x:Name="BlueGlowTransform"/></Ellipse.RenderTransform>
                    </Ellipse>

                    <Path Data="M-180,870 C300,350 760,1040 2100,280" StrokeThickness="115" Opacity="0.22">
                        <Path.Stroke><LinearGradientBrush StartPoint="0,0" EndPoint="1,0"><GradientStop Color="#00E7C45E" Offset="0"/><GradientStop Color="#B8E7C45E" Offset="0.42"/><GradientStop Color="#123B73B3" Offset="1"/></LinearGradientBrush></Path.Stroke>
                        <Path.RenderTransform><TranslateTransform x:Name="RibbonOneTransform"/></Path.RenderTransform>
                    </Path>
                    <Path Data="M-220,260 C420,850 1120,60 2140,700" StrokeThickness="92" Opacity="0.18">
                        <Path.Stroke><LinearGradientBrush StartPoint="0,0" EndPoint="1,0"><GradientStop Color="#003B73B3" Offset="0"/><GradientStop Color="#A05283D2" Offset="0.54"/><GradientStop Color="#18E7C45E" Offset="1"/></LinearGradientBrush></Path.Stroke>
                        <Path.RenderTransform><TranslateTransform x:Name="RibbonTwoTransform"/></Path.RenderTransform>
                    </Path>
                    <Path Data="M120,1180 C420,520 930,390 1780,-120" Stroke="#38597DB8" StrokeThickness="38" Opacity="0.22">
                        <Path.RenderTransform><TranslateTransform x:Name="RibbonThreeTransform"/></Path.RenderTransform>
                    </Path>

                    <Grid Width="760" Height="760" Canvas.Left="1320" Canvas.Top="-320" RenderTransformOrigin="0.5,0.5">
                        <Grid.RenderTransform><RotateTransform x:Name="RingTransform"/></Grid.RenderTransform>
                        <Ellipse Margin="15" Stroke="#5F79A4D9" StrokeThickness="2.5" StrokeDashArray="3,8"/>
                        <Ellipse Margin="108" Stroke="#70E7C45E" StrokeThickness="1.8" StrokeDashArray="1,12"/>
                        <Ellipse Margin="205" Stroke="#405B84B7" StrokeThickness="1.3"/>
                    </Grid>
                    <Grid Width="560" Height="560" Canvas.Left="-190" Canvas.Top="610" RenderTransformOrigin="0.5,0.5">
                        <Grid.RenderTransform><RotateTransform x:Name="RingTwoTransform"/></Grid.RenderTransform>
                        <Ellipse Margin="20" Stroke="#4EE7C45E" StrokeThickness="2" StrokeDashArray="4,12"/>
                        <Ellipse Margin="112" Stroke="#384D7BB5" StrokeThickness="2"/>
                    </Grid>

                    <Canvas Width="1920" Height="1080">
                        <Canvas.RenderTransform><TranslateTransform x:Name="ConstellationTransform"/></Canvas.RenderTransform>
                        <Path Data="M330,220 L540,320 L760,170 L990,300 L1220,210 L1450,360 L1650,190" Stroke="#334F79AE" StrokeThickness="1.5" StrokeDashArray="3,9"/>
                        <Ellipse x:Name="StarOne" Width="8" Height="8" Canvas.Left="326" Canvas.Top="216" Fill="#F7DA76"/>
                        <Ellipse x:Name="StarTwo" Width="5" Height="5" Canvas.Left="538" Canvas.Top="318" Fill="#B8DCFF"/>
                        <Ellipse x:Name="StarThree" Width="7" Height="7" Canvas.Left="756" Canvas.Top="166" Fill="#F7DA76"/>
                        <Ellipse x:Name="StarFour" Width="4" Height="4" Canvas.Left="988" Canvas.Top="298" Fill="#B8DCFF"/>
                        <Ellipse x:Name="StarFive" Width="9" Height="9" Canvas.Left="1216" Canvas.Top="206" Fill="#F7DA76"/>
                        <Ellipse x:Name="StarSix" Width="5" Height="5" Canvas.Left="1448" Canvas.Top="358" Fill="#B8DCFF"/>
                        <Ellipse x:Name="StarSeven" Width="7" Height="7" Canvas.Left="1646" Canvas.Top="186" Fill="#F7DA76"/>
                        <Ellipse x:Name="StarEight" Width="4" Height="4" Canvas.Left="1080" Canvas.Top="720" Fill="#B8DCFF"/>
                    </Canvas>
                </Canvas>
            </Viewbox>
        </Grid>


        <Grid x:Name="PlatformBackdrop" IsHitTestVisible="False" Visibility="Collapsed" ClipToBounds="True">
            <Viewbox Stretch="Fill">
                <Canvas Width="1920" Height="1080">
                    <Rectangle x:Name="PlatformBase" Width="1920" Height="1080" Fill="#07101D"/>
                    <Ellipse x:Name="PlatformGlowOne" Width="1050" Height="1050" Canvas.Left="-420" Canvas.Top="-410" Fill="#66C0F4" Opacity="0.24">
                        <Ellipse.Effect><BlurEffect Radius="100"/></Ellipse.Effect>
                        <Ellipse.RenderTransform><TranslateTransform x:Name="PlatformGlowOneTransform"/></Ellipse.RenderTransform>
                    </Ellipse>
                    <Ellipse x:Name="PlatformGlowTwo" Width="1300" Height="1300" Canvas.Left="1040" Canvas.Top="260" Fill="#1B91D0" Opacity="0.22">
                        <Ellipse.Effect><BlurEffect Radius="120"/></Ellipse.Effect>
                        <Ellipse.RenderTransform><TranslateTransform x:Name="PlatformGlowTwoTransform"/></Ellipse.RenderTransform>
                    </Ellipse>
                    <Path x:Name="PlatformWaveOne" Data="M-260,790 C270,260 760,1030 2200,230" Stroke="#66C0F4" StrokeThickness="92" Opacity="0.16">
                        <Path.RenderTransform><TranslateTransform x:Name="PlatformWaveOneTransform"/></Path.RenderTransform>
                    </Path>
                    <Path x:Name="PlatformWaveTwo" Data="M-240,260 C390,900 1200,90 2200,760" Stroke="#1B91D0" StrokeThickness="58" Opacity="0.18">
                        <Path.RenderTransform><TranslateTransform x:Name="PlatformWaveTwoTransform"/></Path.RenderTransform>
                    </Path>
                    <Grid Width="820" Height="820" Canvas.Left="1280" Canvas.Top="-340" RenderTransformOrigin="0.5,0.5" Opacity="0.32">
                        <Grid.RenderTransform><RotateTransform x:Name="PlatformRingTransform"/></Grid.RenderTransform>
                        <Ellipse x:Name="PlatformRing" Margin="20" Stroke="#66C0F4" StrokeThickness="3" StrokeDashArray="2,11"/>
                        <Ellipse Margin="130" Stroke="#66C0F4" StrokeThickness="1.5" StrokeDashArray="1,16"/>
                        <Ellipse Margin="260" Stroke="#FFFFFF" StrokeThickness="1" Opacity="0.34"/>
                    </Grid>
                    <Canvas x:Name="PlatformPlayStationGlyphs" Canvas.Left="115" Canvas.Top="780" Opacity="0.18">
                        <Ellipse Width="115" Height="115" Stroke="#FFFFFF" StrokeThickness="8"/>
                        <Rectangle Width="104" Height="104" Canvas.Left="170" Canvas.Top="8" Stroke="#FFFFFF" StrokeThickness="8"/>
                        <Path Data="M350,108 L405,8 L460,108 Z" Stroke="#FFFFFF" StrokeThickness="8" Fill="Transparent"/>
                        <Path Data="M535,12 L625,102 M625,12 L535,102" Stroke="#FFFFFF" StrokeThickness="8"/>
                    </Canvas>
                    <StackPanel Canvas.Left="112" Canvas.Top="125" Opacity="0.28">
                        <TextBlock x:Name="PlatformBrandText" Text="PLATFORM" FontSize="82" FontWeight="Bold" Foreground="#FFFFFF"/>
                        <TextBlock x:Name="PlatformMotifText" Text="HUYMAIER PLATFORM" FontSize="17" FontWeight="SemiBold" Foreground="#FFFFFF" Margin="4,8,0,0"/>
                    </StackPanel>
                    <Rectangle Width="1920" Height="1080" Fill="#44000000"/>
                </Canvas>
            </Viewbox>
        </Grid>

        <Grid x:Name="ShellContent" Margin="44,30,44,26">
            <Grid.RowDefinitions>
                <RowDefinition Height="72"/>
                <RowDefinition Height="0"/>
                <RowDefinition Height="*"/>
                <RowDefinition Height="48"/>
            </Grid.RowDefinitions>

            <Grid Grid.Row="0">
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="Auto"/>
                </Grid.ColumnDefinitions>
                <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                    <Border Width="48" Height="48" CornerRadius="24" BorderBrush="#E7C45E" BorderThickness="2" Background="#0D1726">
                        <TextBlock Text="H" FontSize="25" FontWeight="Bold" Foreground="#E7C45E" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                    </Border>
                    <StackPanel Margin="14,0,0,0" VerticalAlignment="Center">
                        <TextBlock Text="HUYMAIER CONSOLE" FontSize="25" FontWeight="Bold"/>
                        <TextBlock Text="WINDOWS 11 FULL-SCREEN EXPERIENCE" FontSize="11" Foreground="#99A8BF"/>
                    </StackPanel>
                </StackPanel>
                <StackPanel Grid.Column="1" HorizontalAlignment="Right" VerticalAlignment="Center">
                    <TextBlock x:Name="ClockText" Text="--:--" FontSize="25" FontWeight="SemiBold" HorizontalAlignment="Right"/>
                    <TextBlock x:Name="ControllerText" Text="Keyboard / Mouse" FontSize="12" Foreground="#AAB8CC" HorizontalAlignment="Right"/>
                    <TextBlock x:Name="FpsText" Text="FPS --" Visibility="Collapsed" FontSize="12" FontWeight="SemiBold" Foreground="#E7C45E" HorizontalAlignment="Right" Margin="0,3,0,0"/>
                </StackPanel>
            </Grid>

            <ScrollViewer Grid.Row="1" Visibility="Collapsed" HorizontalScrollBarVisibility="Hidden" VerticalScrollBarVisibility="Disabled">
                <StackPanel x:Name="NavPanel" Orientation="Horizontal" VerticalAlignment="Center"/>
            </ScrollViewer>

            <Grid Grid.Row="2" Margin="0,12,0,12">
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="1.55*"/>
                    <ColumnDefinition Width="0.45*"/>
                </Grid.ColumnDefinitions>

                <Grid x:Name="MainListArea" Margin="0,0,22,0">
                    <Grid.RowDefinitions>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="*"/>
                    </Grid.RowDefinitions>
                    <TextBlock x:Name="PageTitle" FontSize="38" FontWeight="Bold" TextWrapping="Wrap" Padding="0,2,0,2"/>
                    <TextBlock x:Name="PageSubtitle" Grid.Row="1" Margin="0,6,0,16" FontSize="15" Foreground="#AEBBD0" TextWrapping="Wrap" Padding="0,1,0,2"/>
                    <ScrollViewer x:Name="ActionScrollViewer" Grid.Row="2" VerticalScrollBarVisibility="Hidden" HorizontalScrollBarVisibility="Disabled" PanningMode="VerticalOnly">
                        <StackPanel x:Name="ActionPanel"/>
                    </ScrollViewer>
                </Grid>

                <Border x:Name="HeroPanel" Grid.Column="1" CornerRadius="16" BorderBrush="#6F5C2B" BorderThickness="1.2" Background="#A80D1522" Padding="22">
                    <Grid>
                        <Grid.RowDefinitions>
                            <RowDefinition Height="*"/>
                            <RowDefinition Height="Auto"/>
                        </Grid.RowDefinitions>
                        <StackPanel VerticalAlignment="Center">
                            <TextBlock Text="CURRENT EXPERIENCE" FontSize="12" Foreground="#C8A84E" FontWeight="SemiBold"/>
                            <TextBlock x:Name="HeroTitle" Margin="0,10,0,12" FontSize="25" FontWeight="Bold" TextWrapping="Wrap"/>
                            <Rectangle Height="3" Width="90" HorizontalAlignment="Left" Fill="#C8A84E" RadiusX="2" RadiusY="2"/>
                            <TextBlock x:Name="HeroText" Margin="0,16,0,0" FontSize="14" Foreground="#BAC5D6" TextWrapping="Wrap" LineHeight="26"/>
                        </StackPanel>
                        <Border Grid.Row="1" Margin="0,24,0,0" Background="#121C2B" BorderBrush="#2A3A52" BorderThickness="1" CornerRadius="12" Padding="16">
                            <StackPanel>
                                <TextBlock Text="SAFE PROTOTYPE MODE" FontSize="12" Foreground="#E7C45E" FontWeight="SemiBold"/>
                                <TextBlock Text="Explorer is not replaced. Press Ctrl + Shift + F12 at any time to exit." Margin="0,5,0,0" FontSize="13" Foreground="#9EADC2" TextWrapping="Wrap"/>
                            </StackPanel>
                        </Border>
                    </Grid>
                </Border>
            </Grid>

            <Grid Grid.Row="3">
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="Auto"/>
                </Grid.ColumnDefinitions>
                <StackPanel x:Name="PromptPanel" Orientation="Horizontal" VerticalAlignment="Center"/>
                <TextBlock Grid.Column="1" VerticalAlignment="Center" Text="HUYMAIER FSE  v0.26.0" FontSize="12" Foreground="#77869C"/>
            </Grid>
        </Grid>

        <Grid x:Name="MainMenuOverlay" Visibility="Collapsed" Background="#54000000" Panel.ZIndex="1300">
            <Border x:Name="MainMenuFrame" Height="128" HorizontalAlignment="Stretch" VerticalAlignment="Bottom" Margin="26,22,26,22" Background="#F2080B10" BorderBrush="#434D5C" BorderThickness="1.5" CornerRadius="20" Padding="10">
                <Grid>
                    <ScrollViewer x:Name="MainMenuScroll" HorizontalScrollBarVisibility="Hidden" VerticalScrollBarVisibility="Disabled" PanningMode="HorizontalOnly">
                        <StackPanel x:Name="MainMenuPanel" Orientation="Horizontal" HorizontalAlignment="Center"/>
                    </ScrollViewer>
                </Grid>
            </Border>
        </Grid>

        <Grid x:Name="GameModalOverlay" Visibility="Collapsed" Background="#C2000000" Panel.ZIndex="100">
            <Border Width="680" MaxHeight="820" HorizontalAlignment="Center" VerticalAlignment="Center" Background="#F2080A0D" BorderBrush="#4D5663" BorderThickness="1.5" CornerRadius="18" Padding="26">
                <Grid>
                    <Grid.RowDefinitions>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="*"/>
                    </Grid.RowDefinitions>
                    <TextBlock x:Name="GameModalTitle" FontSize="28" FontWeight="Bold" Foreground="White" TextWrapping="Wrap"/>
                    <TextBlock x:Name="GameModalSubtitle" Grid.Row="1" Margin="0,8,0,20" FontSize="14" Foreground="#B8C3D2" TextWrapping="Wrap"/>
                    <ScrollViewer Grid.Row="2" VerticalScrollBarVisibility="Hidden" HorizontalScrollBarVisibility="Disabled" PanningMode="VerticalOnly">
                        <StackPanel x:Name="GameModalPanel"/>
                    </ScrollViewer>
                </Grid>
            </Border>
        </Grid>
    </Grid>
</Window>
'@

try {
    [xml]$xml = $xaml
    $reader = New-Object System.Xml.XmlNodeReader $xml
    $script:Window = [Windows.Markup.XamlReader]::Load($reader)

    foreach ($name in @('ClockText','ControllerText','FpsText','NavPanel','PageTitle','PageSubtitle','ActionPanel','HeroTitle','HeroText','HeroPanel','MainListArea','PromptPanel','DynamicBackdrop','GoldGlowTransform','BlueGlowTransform','RingTransform','RingTwoTransform','RibbonOneTransform','RibbonTwoTransform','RibbonThreeTransform','ConstellationTransform','StarOne','StarTwo','StarThree','StarFour','StarFive','StarSix','StarSeven','StarEight','PlatformBackdrop','PlatformBase','PlatformGlowOne','PlatformGlowTwo','PlatformWaveOne','PlatformWaveTwo','PlatformRing','PlatformBrandText','PlatformMotifText','PlatformGlowOneTransform','PlatformGlowTwoTransform','PlatformWaveOneTransform','PlatformWaveTwoTransform','PlatformRingTransform','PlatformPlayStationGlyphs','ActionScrollViewer','RootGrid','ShellContent','MainMenuOverlay','MainMenuFrame','MainMenuScroll','MainMenuPanel','GameModalOverlay','GameModalTitle','GameModalSubtitle','GameModalPanel')) {
        Set-Variable -Scope Script -Name $name -Value $script:Window.FindName($name)
    }

    $iconPath = Join-Path $script:BaseDir 'HuymaierConsole.ico'
    if (Test-Path $iconPath) {
        try { $script:Window.Icon = [System.Windows.Media.Imaging.BitmapFrame]::Create([uri]$iconPath) } catch { }
    }

    if ($Windowed) {
        $script:Window.WindowStyle = 'SingleBorderWindow'
        $script:Window.ResizeMode = 'CanResize'
        $script:Window.WindowState = 'Normal'
        $script:Window.Width = 1280
        $script:Window.Height = 760
        $script:Window.WindowStartupLocation = 'CenterScreen'
    }

    for ($i=0; $i -lt $script:NavItems.Count; $i++) {
        $button = New-Object System.Windows.Controls.Button
        $button.Style = $script:Window.FindResource('NavButtonStyle')
        $button.Content = New-NavIcon $script:NavItems[$i]
        $button.ToolTip = $script:NavItems[$i]
        $button.Tag = $i
        $button.Add_Click({ param($sender,$eventArgs)
            try { Set-KeyboardActive; Invoke-UiFeedback 'Tab'; Set-Tab ([int]$sender.Tag) }
            catch { Write-Log "Navigation failed: $($_.Exception.ToString())" 'ERROR' }
        })
        $button.Add_MouseEnter({if(-not(Test-HcMouseHoverAllowed)){return}; Set-KeyboardActive })
        $script:NavPanel.Children.Add($button) | Out-Null
        $script:NavButtons += $button
    }

    $script:Window.Add_PreviewKeyDown({
        param($sender,$eventArgs)
        if($script:KeyboardActive){
            switch($eventArgs.Key){
                'Left' { Move-NativeKeyboard 'Left';$eventArgs.Handled=$true }
                'Right' { Move-NativeKeyboard 'Right';$eventArgs.Handled=$true }
                'Up' { Move-NativeKeyboard 'Up';$eventArgs.Handled=$true }
                'Down' { Move-NativeKeyboard 'Down';$eventArgs.Handled=$true }
                'Enter' { Invoke-NativeKeyboardSelected;$eventArgs.Handled=$true }
                'Escape' { Close-NativeKeyboard $false;$eventArgs.Handled=$true }
                'Back' { Invoke-NativeKeyboardKey 'BACKSPACE';$eventArgs.Handled=$true }
                'Delete' { Invoke-NativeKeyboardKey 'BACKSPACE';$eventArgs.Handled=$true }
                'Space' { Invoke-NativeKeyboardKey 'SPACE';$eventArgs.Handled=$true }
            }
            if($eventArgs.Handled){return}
        }
        if((Get-Command Handle-HcChoicePopupKey -ErrorAction SilentlyContinue) -and (Handle-HcChoicePopupKey $eventArgs.Key)){$eventArgs.Handled=$true;return}
        if((Get-Command Handle-HcBrowserKey -ErrorAction SilentlyContinue) -and (Handle-HcBrowserKey $eventArgs.Key)){$eventArgs.Handled=$true;return}
        if((Get-Command Handle-HcMainMenuKey -ErrorAction SilentlyContinue) -and (Handle-HcMainMenuKey $eventArgs.Key)){$eventArgs.Handled=$true;return}
        if((Get-Command Handle-HcGameModalKey -ErrorAction SilentlyContinue) -and (Handle-HcGameModalKey $eventArgs.Key)){$eventArgs.Handled=$true;return}
        if($eventArgs.Key -eq 'F1' -and (Get-Command Show-HcMainMenu -ErrorAction SilentlyContinue)){Set-KeyboardActive;Show-HcMainMenu;$eventArgs.Handled=$true;return}
        Set-KeyboardActive
        if($script:NavigationLayer -eq 'Navigation'){
            $script:NavigationLayer='Content'
            if((Get-Command Show-HcMainMenu -ErrorAction SilentlyContinue) -and -not (Test-HcMainMenuVisible)){Show-HcMainMenu}
            $eventArgs.Handled=$true
        }else{
            switch ($eventArgs.Key) {
                'Left'   { if(-not (Adjust-SelectedSlider -5)){if(Use-HorizontalRailNavigation){Move-HomeHorizontal -1}};$eventArgs.Handled=$true }
                'Right'  { if(-not (Adjust-SelectedSlider 5)){if(Use-HorizontalRailNavigation){Move-HomeHorizontal 1}};$eventArgs.Handled=$true }
                'Up'     { if (Use-HorizontalRailNavigation){Move-HomeVertical -1}else{Move-Action -1};$eventArgs.Handled=$true }
                'Down'   { if (Use-HorizontalRailNavigation){Move-HomeVertical 1}else{Move-Action 1};$eventArgs.Handled=$true }
                'Enter'  { Invoke-SelectedAction; $eventArgs.Handled = $true }
                'Space'  { Invoke-SelectedAction; $eventArgs.Handled = $true }
                'X'      { Invoke-SecondaryAction; $eventArgs.Handled = $true }
                'Escape' { Handle-Back; $eventArgs.Handled = $true }
                'F10'    { Toggle-WindowMode; $eventArgs.Handled = $true }
            }
        }
        if ($eventArgs.Key -eq 'F12' -and [System.Windows.Input.Keyboard]::Modifiers.HasFlag([System.Windows.Input.ModifierKeys]::Control) -and [System.Windows.Input.Keyboard]::Modifiers.HasFlag([System.Windows.Input.ModifierKeys]::Shift)) {
            $script:AllowWindowClose=$true
            $script:Window.Close()
            $eventArgs.Handled = $true
        }
    })
    $script:Window.Add_PreviewTextInput({
        param($sender,$eventArgs)
        if($script:KeyboardActive -and -not [string]::IsNullOrEmpty([string]$eventArgs.Text)){
            if(Get-Command Set-NativeKeyboardBuffer -ErrorAction SilentlyContinue){Set-NativeKeyboardBuffer ((Get-NativeKeyboardBuffer)+[string]$eventArgs.Text)}else{$script:KeyboardTextBox.Text += [string]$eventArgs.Text}
            try{$script:KeyboardTextBox.CaretIndex=$script:KeyboardTextBox.Text.Length}catch{}
            $eventArgs.Handled=$true
        }
    })
    $script:Window.Add_PreviewMouseDown({
        $script:IgnoreMouseMoveUntil=[datetime]::MinValue
        $script:LastPhysicalMouseAt=Get-Date
        try{if('HuymaierConsole.Native.NativeCursorRouter' -as [type]){$script:LastPhysicalCursorPosition=[HuymaierConsole.Native.NativeCursorRouter]::GetCursorPosition()}}catch{}
        Show-ConsoleCursor;Set-KeyboardActive
    })
    $script:Window.Add_PreviewMouseMove({param($sender,$eventArgs)
        try{
            if((Get-Date) -lt $script:IgnoreMouseMoveUntil){return}
            $physicalMoved=$true
            if('HuymaierConsole.Native.NativeCursorRouter' -as [type]){
                $position=[HuymaierConsole.Native.NativeCursorRouter]::GetCursorPosition()
                if($script:ControllerCursorHidden){
                    $physicalMoved=[HuymaierConsole.Native.NativeCursorRouter]::MovedFrom([long]$script:ControllerParkedCursorPosition,3)
                }elseif($script:LastPhysicalCursorPosition -ne 0){
                    $physicalMoved=[HuymaierConsole.Native.NativeCursorRouter]::MovedFrom([long]$script:LastPhysicalCursorPosition,2)
                }
                if(-not $physicalMoved){return}
                $script:LastPhysicalCursorPosition=$position
            }
            $point=$eventArgs.GetPosition($script:Window)
            $script:LastMousePoint=$point
            $script:LastPhysicalMouseAt=Get-Date
            Show-ConsoleCursor;Set-KeyboardActive
        }catch{}
    })

    Initialize-NativeKeyboardOverlay
    if(Get-Command Initialize-HuymaierWebBrowser -ErrorAction SilentlyContinue){Initialize-HuymaierWebBrowser}

    $script:LastControllerDeviceChangeLogUtc=[datetime]::MinValue
    $script:Window.Add_SourceInitialized({
        try{
            if('HuymaierConsole.Native.RawHidController' -as [type]){
                $helper=New-Object System.Windows.Interop.WindowInteropHelper($script:Window)
                $hwnd=$helper.Handle
                $script:RawInputSource=[System.Windows.Interop.HwndSource]::FromHwnd($hwnd)
                $script:RawInputHook=[System.Windows.Interop.HwndSourceHook]{
                    param([IntPtr]$hookHwnd,[int]$message,[IntPtr]$wParam,[IntPtr]$lParam,[ref]$handled)
                    if($message -eq 0x00FF){
                        try{[HuymaierConsole.Native.RawHidController]::ProcessInput($lParam)}catch{}
                        $handled.Value=$false
                    }elseif($message -eq 0x00FE){
                        try{
                            [HuymaierConsole.Native.RawHidController]::ProcessDeviceChange($wParam,$lParam)
                            if('HuymaierConsole.NativeApp.NativeConsoleNavigation' -as [type]){[HuymaierConsole.NativeApp.NativeConsoleNavigation]::NotifyDeviceChange()}
                            $script:LastGamepadMask=0;$script:LastDirection='';$script:NextDirectionAt=[datetime]::MinValue
                            $now=Get-Date
                            $script:ControllerInputGuardUntil=$now.AddMilliseconds(750)
                            if(($now-$script:LastControllerDeviceChangeLogUtc).TotalMilliseconds -ge 750){
                                $script:LastControllerDeviceChangeLogUtc=$now
                                Write-Log ('Controller hot-plug burst safely queued: {0}' -f $wParam.ToInt32())
                            }
                        }catch{}
                        $handled.Value=$false
                    }
                    return [IntPtr]::Zero
                }
                if($null -ne $script:RawInputSource){$script:RawInputSource.AddHook($script:RawInputHook)}
                if([HuymaierConsole.Native.RawHidController]::Register($hwnd)){Write-Log 'Native Raw Input HID controller path registered.'}else{Write-Log 'Native Raw Input HID registration failed.' 'WARN'}
            }
        }catch{Write-Log "Native Raw Input initialization failed: $($_.Exception.Message)" 'WARN'}
    })

    $script:Window.Add_Activated({$script:LastGamepadMask=0;$script:LastDirection='';$script:NextDirectionAt=[datetime]::MinValue;if((Get-Date) -ge $script:ControllerInputGuardUntil){$script:ControllerInputGuardUntil=(Get-Date).AddMilliseconds(350)};try{if('HuymaierConsole.NativeApp.NativeConsoleNavigation' -as [type]){[HuymaierConsole.NativeApp.NativeConsoleNavigation]::Reset()}}catch{};Update-BackgroundMusic})
    $script:Window.Add_Deactivated({$script:LastGamepadMask=0;$script:LastDirection='';$script:NextDirectionAt=[datetime]::MinValue;if ($null -ne $script:MusicPlayer) { try { $script:MusicPlayer.Pause() } catch { } } })

    $clockTimer = New-Object System.Windows.Threading.DispatcherTimer
    $clockTimer.Interval = [TimeSpan]::FromSeconds(1)
    $clockTimer.Add_Tick({ $script:ClockText.Text = (Get-Date -Format 'h:mm tt') })
    $clockTimer.Start()
    $script:MainClockTimer=$clockTimer

    $systemTimer = New-Object System.Windows.Threading.DispatcherTimer
    $systemTimer.Interval = [TimeSpan]::FromSeconds(1)
    $systemTimer.Add_Tick({
        try {
            if (Test-Path $script:LibraryStatePath) {
                $libraryStateSignature=(Get-Item -LiteralPath $script:LibraryStatePath).LastWriteTimeUtc.Ticks.ToString()
                if($libraryStateSignature -ne $script:LibraryStateSignature){$script:LibraryStateSignature=$libraryStateSignature;Read-LibraryState;if($script:SelectedTab -eq 5){Render-Page}}
            }
            Apply-LibraryResult
            Apply-OnlineArtworkResult
            if(Test-Path -LiteralPath $script:Ps3SummaryPath -PathType Leaf){
                $ps3SummarySignature=(Get-Item -LiteralPath $script:Ps3SummaryPath).LastWriteTimeUtc.Ticks.ToString()
                if($ps3SummarySignature -ne $script:Ps3SummarySignature){
                    $script:Ps3SummarySignature=$ps3SummarySignature
                    if($script:SelectedTab -eq 1 -and -not $script:SubPage){Render-Page}
                }
            }
            if(Test-Path -LiteralPath $script:Ps1SummaryPath -PathType Leaf){
                $ps1SummarySignature=(Get-Item -LiteralPath $script:Ps1SummaryPath).LastWriteTimeUtc.Ticks.ToString()
                if($ps1SummarySignature -ne $script:Ps1SummarySignature){$script:Ps1SummarySignature=$ps1SummarySignature;if($script:SelectedTab -eq 1 -and -not $script:SubPage){Render-Page}}
            }
            if(Test-Path -LiteralPath $script:Ps2SummaryPath -PathType Leaf){
                $ps2SummarySignature=(Get-Item -LiteralPath $script:Ps2SummaryPath).LastWriteTimeUtc.Ticks.ToString()
                if($ps2SummarySignature -ne $script:Ps2SummarySignature){
                    $script:Ps2SummarySignature=$ps2SummarySignature
                    if($script:SelectedTab -eq 1 -and -not $script:SubPage){Render-Page}
                }
            }
            if($script:SelectedTab -eq 1 -and -not $script:SubPage -and (Get-Date) -ge $script:NextConsoleCountRefreshAt){
                $script:NextConsoleCountRefreshAt=(Get-Date).AddSeconds(30)
                Start-Ps1LibrarySummaryScan;Start-Ps2LibrarySummaryScan;Start-Ps3LibrarySummaryScan
                foreach($nativeId in @('N64','GAMECUBE','WII','WIIU','SWITCH','XBOX','XBOX360')){Start-NativeConsoleLibrarySummaryScan $nativeId}
            }
            foreach($nativeId in @('N64','GAMECUBE','WII','WIIU','SWITCH','XBOX','XBOX360')){
                $nativeSummaryPath=Join-Path $script:DataDir ("EmulatorPlatforms\"+$nativeId+"\library-summary.json")
                if(Test-Path -LiteralPath $nativeSummaryPath -PathType Leaf){
                    $sig=(Get-Item -LiteralPath $nativeSummaryPath).LastWriteTimeUtc.Ticks.ToString()
                    $oldSig=if($script:NativeConsoleSummarySignatures.ContainsKey($nativeId)){[string]$script:NativeConsoleSummarySignatures[$nativeId]}else{''}
                    if($sig -ne $oldSig){
                        $script:NativeConsoleSummarySignatures[$nativeId]=$sig
                        if($oldSig -and $script:SelectedTab -eq 1 -and -not $script:SubPage){Render-Page;break}
                    }
                }
            }
            if (Test-Path $script:StorefrontStatePath) {
                $storefrontSignature=(Get-Item -LiteralPath $script:StorefrontStatePath).LastWriteTimeUtc.Ticks.ToString()
                if($storefrontSignature -ne $script:StorefrontStateSignature){
                    $script:StorefrontStateSignature=$storefrontSignature
                    Read-StorefrontState
                    $script:StorefrontCatalogAt=[datetime]::MinValue
                    if($script:SelectedTab -in @(1,4)){Render-Page}
                }
            }
            if (Test-Path $script:ProviderStatePath) {
                $providerStateSignature=(Get-Item -LiteralPath $script:ProviderStatePath).LastWriteTimeUtc.Ticks.ToString()
                if($providerStateSignature -ne $script:ProviderStateSignature){
                    $script:ProviderStateSignature=$providerStateSignature
                    $providerState=Read-GameProviderState
                    # Provider refresh is an explicit library mutation. Refresh only that
                    # provider's missing cover art after the provider job completes.
                    try{
                        $mode=[string](Get-EntryProperty $providerState 'Mode' '')
                        $provider=[string](Get-EntryProperty $providerState 'Provider' '')
                        $busy=[bool](Get-EntryProperty $providerState 'Busy' $false)
                        $error=[string](Get-EntryProperty $providerState 'Error' '')
                        $phase=[string](Get-EntryProperty $providerState 'Phase' '')
                        $updated=[string](Get-EntryProperty $providerState 'Updated' (Get-EntryProperty $providerState 'UpdatedAt' ''))
                        $token=$provider+'|'+$mode+'|'+$phase+'|'+$updated
                        if(-not $busy -and -not $error -and [string]::Equals($mode,'Refresh',[StringComparison]::OrdinalIgnoreCase) -and $provider -and $token -ne $script:LastArtworkProviderRefreshToken){
                            $script:LastArtworkProviderRefreshToken=$token
                            Start-OnlineArtworkScan -ResetCursor -Force -Platform $provider
                        }
                    }catch{Write-Log "Provider-refresh artwork trigger failed: $($_.Exception.Message)" 'WARN'}
                    if($script:SelectedTab -eq 4 -and -not $script:SubPage -and $busy -and [string]::Equals($mode,'Install',[StringComparison]::OrdinalIgnoreCase) -and (Get-Command Update-HcActiveDownloadVisuals -ErrorAction SilentlyContinue)){
                        # v0.25.4: live transfer telemetry updates once per second. Update the
                        # existing download card in place so controller focus/scroll position
                        # is not reset by a full page rebuild every time Legendary reports data.
                        if(-not (Update-HcActiveDownloadVisuals $providerState)){Render-Page}
                    }elseif($script:SelectedTab -in @(1,4)){Render-Page}
                }
            }
            if (Test-Path $script:ProviderCatalogPath) {
                $providerCatalogSignature=(Get-Item -LiteralPath $script:ProviderCatalogPath).LastWriteTimeUtc.Ticks.ToString()
                if(-not $script:ProviderCatalogSignature){
                    # First observation during startup is cache-only. It must not destroy
                    # the persisted shelf/library index merely because the timer has now
                    # seen the existing catalog file for the first time.
                    $script:ProviderCatalogSignature=$providerCatalogSignature
                    Read-GameProviderCatalog|Out-Null
                }elseif($providerCatalogSignature -ne $script:ProviderCatalogSignature){
                    $script:ProviderCatalogSignature=$providerCatalogSignature
                    Read-GameProviderCatalog|Out-Null
                    try{Clear-HcGameDataCache -DropPersistent}catch{}
                    if($script:SelectedTab -eq 1){Render-Page}
                }
            }
            if (Test-Path $script:UpdateStatePath) {
                $signature = (Get-Item $script:UpdateStatePath).LastWriteTimeUtc.Ticks.ToString()
                if ($signature -ne $script:UpdateStateSignature) {
                    $script:UpdateStateSignature = $signature
                    Read-UpdateState
                    if (($script:SelectedTab -eq 7 -and $script:SubPage -eq 'WindowsUpdate') -or ($script:SelectedTab -eq 4 -and $script:SubPage -eq 'Updates')) { Render-Page }
                }
            }
            if (Test-Path $script:DriverStatePath) {
                $driverSignature = (Get-Item $script:DriverStatePath).LastWriteTimeUtc.Ticks.ToString()
                if ($driverSignature -ne $script:DriverStateSignature) {
                    $script:DriverStateSignature = $driverSignature
                    Read-DriverState
                    try{Write-Log ("Driver state: Phase={0}; Drivers={1}; Updates={2}; Reboot={3}; Message={4}" -f ([string](Get-EntryProperty $script:DriverState 'Phase' '')),([int](Get-EntryProperty $script:DriverState 'DriverCount' 0)),([int](Get-EntryProperty $script:DriverState 'UpdateCount' 0)),([bool](Get-EntryProperty $script:DriverState 'RebootRequired' $false)),([string](Get-EntryProperty $script:DriverState 'Message' '')))}catch{}
                    if ($script:SelectedTab -eq 7 -and $script:SubPage -eq 'Drivers') { Render-Page }
                }
            }
            if((Get-Variable -Name HcConsoleUpdateStatePath -Scope Script -ErrorAction SilentlyContinue) -and (Test-Path -LiteralPath $script:HcConsoleUpdateStatePath)){
                try{
                    $hcUpdateSignature=(Get-Item -LiteralPath $script:HcConsoleUpdateStatePath).LastWriteTimeUtc.Ticks.ToString()
                    if($hcUpdateSignature -ne $script:HcConsoleUpdateStateSignature){$script:HcConsoleUpdateStateSignature=$hcUpdateSignature;Read-HcConsoleUpdateState|Out-Null;if($script:SelectedTab -eq 7 -and $script:SubPage -eq 'ConsoleUpdate'){Render-Page}}
                }catch{Write-Log "Huymaier Console update-state observer failed: $($_.Exception.Message)" 'WARN'}
            }
            if(Get-Command Update-HcDownloadHistory -ErrorAction SilentlyContinue){try{Update-HcDownloadHistory}catch{Write-Log "Download history observer failed: $($_.Exception.Message)" 'WARN'}}
            if([bool]$script:Config.ShowFpsCounter -and $null -ne $script:FpsText -and ('HuymaierConsole.Native.FrameRateMonitor' -as [type])){$script:FpsText.Text=('FPS {0:N0}' -f [HuymaierConsole.Native.FrameRateMonitor]::Fps)}
            if ($script:DisplayPendingConfirmation) {
                if ((Get-Date) -ge $script:DisplayConfirmUntil) {
                    Revert-DisplayMode
                } elseif ($script:SelectedTab -eq 7 -and $script:SubPage -eq 'Display') {
                    Render-Page
                }
            }
        } catch { }
    })
    $systemTimer.Start()
    $script:MainSystemTimer=$systemTimer

    $gamepadTimer = New-Object System.Windows.Threading.DispatcherTimer
    $gamepadTimer.Interval = [TimeSpan]::FromMilliseconds(16)
    $gamepadTimer.Add_Tick({ try { Process-Gamepads } catch { Write-Log "Gamepad poll: $($_.Exception.Message)" 'WARN' } })
    $gamepadTimer.Start()
    $script:MainGamepadTimer=$gamepadTimer

    if(Get-Command Initialize-HuymaierGameBar -ErrorAction SilentlyContinue){Initialize-HuymaierGameBar}

    $script:Window.Add_Closing({
        param($sender,$eventArgs)
        if(-not $script:AllowWindowClose -and (Get-Date) -lt $script:PreventAutoCloseUntil){$eventArgs.Cancel=$true;Write-Log 'Prevented unintended console close after external launch.' 'WARN';return}
        try{if(Get-Command Stop-HuymaierGameBar -ErrorAction SilentlyContinue){Stop-HuymaierGameBar};if('HuymaierConsole.NativeApp.NativeConsoleNavigation' -as [type]){[HuymaierConsole.NativeApp.NativeConsoleNavigation]::Shutdown()}}catch{}
        $script:IsClosing = $true
        try { $clockTimer.Stop(); $systemTimer.Stop(); $gamepadTimer.Stop(); if(Get-Command Stop-HuymaierWebBrowser -ErrorAction SilentlyContinue){Stop-HuymaierWebBrowser}; if ($null -ne $script:InitialScanTimer) { $script:InitialScanTimer.Stop() };if($null -ne $script:ArtworkContinuationTimer){$script:ArtworkContinuationTimer.Stop()};Stop-PlatformBackgroundAnimations;if($script:FpsMonitorStarted -and ('HuymaierConsole.Native.FrameRateMonitor' -as [type])){[HuymaierConsole.Native.FrameRateMonitor]::Stop();$script:FpsMonitorStarted=$false};if($null -ne $script:RawInputSource -and $null -ne $script:RawInputHook){$script:RawInputSource.RemoveHook($script:RawInputHook)} } catch { }
        try { if ($null -ne $script:MusicPlayer) { $script:MusicPlayer.Stop(); $script:MusicPlayer.Close() } } catch { }
        try { foreach ($player in $script:SfxPlayers.Values) { $player.Stop(); $player.Close() } } catch { }
        Save-Config
        Write-Log 'Huymaier Console closed.'
    })

    Set-BackgroundAnimationState
    Set-FpsCounterState
    Initialize-UiFeedback
    Initialize-BackgroundMusic
    Update-NavVisuals
    Render-Page
    if ( -not [bool]$script:Config.LibraryScanCompleted -or [int](Get-EntryProperty $script:Config 'LibrarySchemaVersion' 0) -lt 4) {
        $script:InitialScanTimer = New-Object System.Windows.Threading.DispatcherTimer
        $script:InitialScanTimer.Interval = [TimeSpan]::FromMilliseconds(700)
        $script:InitialScanTimer.Add_Tick({
            try { $script:InitialScanTimer.Stop(); Start-LibraryScan }
            catch { Write-Log "Initial library scan failed: $($_.Exception.Message)" 'WARN' }
        })
        $script:InitialScanTimer.Start()
    }
    # Do not start online artwork while the Platforms view is loading.
    $script:ClockText.Text = (Get-Date -Format 'h:mm tt')
    Update-Footer
    Write-Log "Huymaier Console v$($script:AppVersion) started."
    $script:Window.ShowDialog() | Out-Null
}
catch {
    $fatalDetails=$_.Exception.ToString()
    try{if($_.InvocationInfo -and $_.InvocationInfo.PositionMessage){$fatalDetails += "`nInvocation: $($_.InvocationInfo.PositionMessage)"}}catch{}
    try{if($_.ScriptStackTrace){$fatalDetails += "`nScript stack:`n$($_.ScriptStackTrace)"}}catch{}
    Write-Log "Fatal startup error: $fatalDetails" 'FATAL'
    [System.Windows.MessageBox]::Show("Huymaier Console could not start.`n`n$($_.Exception.Message)`n`nA log was saved to:`n$script:LogDir", $script:AppName, 'OK', 'Error') | Out-Null
    exit 1
}
