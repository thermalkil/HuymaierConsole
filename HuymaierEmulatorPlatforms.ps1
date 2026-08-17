# Huymaier Console emulator-platform host.
# Loaded after the shared game-experience module so emulator platforms can
# participate in the existing Platforms rail without replacing storefront code.

$script:EmulatorPlatformRegistryPath = Join-Path $script:BaseDir 'EmulatorPlatforms\platform-registry.json'
$script:EmulatorPlatformRegistryCache = $null
$script:EmulatorPlatformRegistryStamp = [datetime]::MinValue
$script:EmulatorShellProcesses = @{}
$script:NativePlatformRetryAfter = [datetime]::MinValue
$script:NativePlatformActive = $false
$script:NativePlatformDeferredResumePending = $false

function Suspend-HcRuntimeForNativePlatform {
    if($script:NativePlatformActive){return}
    $script:NativePlatformActive=$true
    $script:NativePlatformDeferredResumePending=$false
    foreach($name in @('MainGamepadTimer','MainSystemTimer','MainClockTimer')){
        try{
            $timer=Get-Variable -Name $name -Scope Script -ValueOnly -ErrorAction SilentlyContinue
            if($null -ne $timer){$timer.Stop()}
        }catch{}
    }
    try{if(Get-Command Stop-PlatformBackgroundAnimations -ErrorAction SilentlyContinue){Stop-PlatformBackgroundAnimations}}catch{}
    try{
        if($script:FpsMonitorStarted -and ('HuymaierConsole.Native.FrameRateMonitor' -as [type])){
            [HuymaierConsole.Native.FrameRateMonitor]::Stop()
            $script:NativePlatformResumeFps=$true
            $script:FpsMonitorStarted=$false
        }else{$script:NativePlatformResumeFps=$false}
    }catch{$script:NativePlatformResumeFps=$false}
}

function Resume-HcDeferredRuntimeFromNativePlatform {
    $script:NativePlatformDeferredResumePending=$false
    try{
        $timer=Get-Variable -Name MainSystemTimer -Scope Script -ValueOnly -ErrorAction SilentlyContinue
        if($null -ne $timer){$timer.Start()}
    }catch{}
    try{if(Get-Command Set-BackgroundAnimationState -ErrorAction SilentlyContinue){Set-BackgroundAnimationState}}catch{}
    try{if(Get-Command Set-FpsCounterState -ErrorAction SilentlyContinue){Set-FpsCounterState}}catch{}
}

function Resume-HcRuntimeFromNativePlatform {
    $script:NativePlatformActive=$false
    # Controller input and the visible clock are latency-sensitive. Restore them
    # immediately; system polling, animated backgrounds and FPS hooks wait for a
    # background dispatcher turn so they cannot hitch the first navigation input.
    foreach($name in @('MainClockTimer','MainGamepadTimer')){
        try{
            $timer=Get-Variable -Name $name -Scope Script -ValueOnly -ErrorAction SilentlyContinue
            if($null -ne $timer){$timer.Start()}
        }catch{}
    }
    if($script:NativePlatformDeferredResumePending){return}
    $script:NativePlatformDeferredResumePending=$true
    $resumeDeferred=[Action]{Resume-HcDeferredRuntimeFromNativePlatform}
    try{
        if($null -ne $script:Window){
            [void]$script:Window.Dispatcher.BeginInvoke([System.Windows.Threading.DispatcherPriority]::Background,$resumeDeferred)
        }else{Resume-HcDeferredRuntimeFromNativePlatform}
    }catch{Resume-HcDeferredRuntimeFromNativePlatform}
}

function Read-HcEmulatorPlatformRegistry {
    if(-not (Test-Path -LiteralPath $script:EmulatorPlatformRegistryPath -PathType Leaf)){
        return [pscustomobject]@{schemaVersion=1;platforms=@()}
    }
    try{
        $stamp=(Get-Item -LiteralPath $script:EmulatorPlatformRegistryPath -ErrorAction Stop).LastWriteTimeUtc
        if($null -eq $script:EmulatorPlatformRegistryCache -or $stamp -ne $script:EmulatorPlatformRegistryStamp){
            $script:EmulatorPlatformRegistryCache=Get-Content -Raw -LiteralPath $script:EmulatorPlatformRegistryPath|ConvertFrom-Json
            $script:EmulatorPlatformRegistryStamp=$stamp
        }
        return $script:EmulatorPlatformRegistryCache
    }catch{
        Write-Log "Emulator platform registry could not be read: $($_.Exception.Message)" 'ERROR'
        return [pscustomobject]@{schemaVersion=1;platforms=@()}
    }
}

function Get-HcEmulatorPlatformEntries {
    $registry=Read-HcEmulatorPlatformRegistry
    return [object[]]@((Get-EntryProperty $registry 'platforms' @())|Where-Object{[bool](Get-EntryProperty $_ 'enabled' $true)}|Sort-Object {[int](Get-EntryProperty $_ 'sortOrder' 1000)})
}

function Get-HcEmulatorPlatformEntry {
    param([string]$Platform)
    if([string]::IsNullOrWhiteSpace($Platform)){return $null}
    foreach($entry in @(Get-HcEmulatorPlatformEntries)){
        foreach($candidate in @(
            [string](Get-EntryProperty $entry 'id' ''),
            [string](Get-EntryProperty $entry 'name' ''),
            [string](Get-EntryProperty $entry 'displayName' ''),
            [string](Get-EntryProperty $entry 'menuName' ''),
            [string](Get-EntryProperty $entry 'backend' '')
        )){
            if($candidate -and [string]::Equals($candidate,$Platform,[StringComparison]::OrdinalIgnoreCase)){return $entry}
        }
        foreach($alias in @(Get-EntryProperty $entry 'aliases' @())){
            if([string]::Equals([string]$alias,$Platform,[StringComparison]::OrdinalIgnoreCase)){return $entry}
        }
    }
    return $null
}

function Test-HcEmulatorPlatform {
    param([string]$Platform)
    return $null -ne (Get-HcEmulatorPlatformEntry $Platform)
}

function Get-HcEmulatorPlatformMenuEntry {
    param([string]$Platform)
    if([string]::IsNullOrWhiteSpace($Platform)){return $null}
    foreach($entry in @(Get-HcEmulatorPlatformEntries)){
        foreach($candidate in @(
            [string](Get-EntryProperty $entry 'name' ''),
            [string](Get-EntryProperty $entry 'displayName' ''),
            [string](Get-EntryProperty $entry 'menuName' '')
        )){
            if($candidate -and [string]::Equals($candidate,$Platform,[StringComparison]::OrdinalIgnoreCase)){return $entry}
        }
        foreach($alias in @(Get-EntryProperty $entry 'aliases' @())){
            if([string]::Equals([string]$alias,$Platform,[StringComparison]::OrdinalIgnoreCase)){return $entry}
        }
    }
    return $null
}

function Test-HcEmulatorPlatformMenuName {
    param([string]$Platform)
    return $null -ne (Get-HcEmulatorPlatformMenuEntry $Platform)
}

function Start-HcEmulatorPlatform {
    param([string]$Platform)
    $entry=Get-HcEmulatorPlatformEntry $Platform
    if($null -eq $entry){return $false}
    $platformId=[string](Get-EntryProperty $entry 'id' '')
    if(-not $platformId){
        Set-ConsoleNotice "$Platform does not have a configured native interface." 'ERROR'
        return $true
    }
    $platformRoot=Join-Path $script:BaseDir ("EmulatorPlatforms\"+$platformId.ToUpperInvariant())
    try{
        $isPs3=$platformId -ieq 'ps3'
        $isPs2=$platformId -ieq 'ps2'
        $isPs1=$platformId -ieq 'ps1'
        $nativeTypeName=if($isPs3){'HuymaierConsole.NativeApp.Ps3XmbWindow'}elseif($isPs2){'HuymaierConsole.NativeApp.Ps2BbnWindow'}elseif($isPs1){'HuymaierConsole.NativeApp.Ps1ClassicWindow'}else{'HuymaierConsole.NativeApp.ConsolePlatformWindow'}
        if([datetime]::UtcNow -lt $script:NativePlatformRetryAfter){return $true}

        # HuymaierConsole.exe publishes a concrete bridge object into this
        # runspace. This is more reliable than PowerShell type-name lookup for
        # classes compiled into the entry executable. Keep reflection as a
        # compatibility fallback for an already-running native host.
        $nativeBridge=Get-Variable -Name HuymaierNativeBridge -ValueOnly -ErrorAction SilentlyContinue
        $nativeType=$null
        if($null -eq $nativeBridge){
            try{$nativeType=[System.Reflection.Assembly]::GetEntryAssembly().GetType($nativeTypeName,$false,$false)}catch{}
            if($null -eq $nativeType){
                try{
                    $nativeType=[AppDomain]::CurrentDomain.GetAssemblies()|ForEach-Object{$_.GetType($nativeTypeName,$false,$false)}|Where-Object{$null -ne $_}|Select-Object -First 1
                }catch{}
            }
        }
        if($null -eq $nativeBridge -and $null -eq $nativeType){
            $script:NativePlatformRetryAfter=[datetime]::UtcNow.AddSeconds(3)
            Set-ConsoleNotice "The native $Platform view was not registered in the current Huymaier Console process. Close Huymaier Console and run the v0.25.6 installer once." 'ERROR'
            Write-Log "Native $Platform bridge/type was not visible to the hosted PowerShell runspace." 'ERROR'
            Render-Page
            return $true
        }
        $script:LastGamepadMask=0
        $script:LastDirection=''
        $script:NextDirectionAt=[datetime]::MinValue
        Suspend-HcRuntimeForNativePlatform
        try{
            # Keep the main window alive as the owner instead of hiding and
            # reconstructing it. The fullscreen owned XMB covers it, while
            # WPF handles modal activation and return safely in one process.
            if($null -ne $nativeBridge){
                if($isPs3){[void]$nativeBridge.ShowPs3Xmb($platformRoot,$script:BaseDir,$script:Window)}
                elseif($isPs2){[void]$nativeBridge.ShowPs2Bbn($platformRoot,$script:BaseDir,$script:Window)}
                elseif($isPs1){[void]$nativeBridge.ShowPs1Classic($platformRoot,$script:BaseDir,$script:Window)}
                else{[void]$nativeBridge.ShowConsolePlatform($platformRoot,$script:BaseDir,$platformId,$script:Window)}
            }else{
                $constructorArgs=if($isPs3 -or $isPs2 -or $isPs1){[object[]]@($platformRoot,$script:BaseDir)}else{[object[]]@($platformRoot,$script:BaseDir,$platformId)}
                $nativeWindow=[Activator]::CreateInstance($nativeType,$constructorArgs)
                try{$nativeWindow.Owner=$script:Window}catch{}
                [void]$nativeWindow.ShowDialog()
            }
        }finally{
            $script:LastGamepadMask=0
            $script:LastDirection=''
            $script:NextDirectionAt=[datetime]::MinValue
            $script:ControllerInputGuardUntil=[datetime]::Now.AddMilliseconds(750)
            try{if('HuymaierConsole.NativeApp.NativeConsoleNavigation' -as [type]){[HuymaierConsole.NativeApp.NativeConsoleNavigation]::Reset()}}catch{}
            try{
                if('HuymaierConsole.Native.RawHidController' -as [type]){
                    $mainHelper=New-Object System.Windows.Interop.WindowInteropHelper($script:Window)
                    [void][HuymaierConsole.Native.RawHidController]::Register($mainHelper.Handle)
                }
            }catch{}
            if($null -ne $script:Window){
                $script:NativePlatformReturnName=[string]$Platform
                $script:NativePlatformOpenQuickAccess=$false
                try{if($null -ne $nativeBridge -and $nativeBridge.ConsumeQuickAccessRequest()){$script:NativePlatformOpenQuickAccess=$true}}catch{}
                $restore=[Action]{
                    # Focus and input ownership must return before any polling,
                    # animation, FPS, library, artwork or provider work resumes.
                    try{
                        if('HuymaierConsole.NativeApp.NativeWindowActivation' -as [type]){
                            [HuymaierConsole.NativeApp.NativeWindowActivation]::Restore($script:Window)
                        }else{$script:Window.Activate()|Out-Null;$script:Window.Focus()|Out-Null}
                    }catch{}
                    Resume-HcRuntimeFromNativePlatform
                    $script:ControllerInputGuardUntil=[datetime]::Now.AddMilliseconds(225)
                    $pickerHandled=$false
                    try{if(Get-Command Invoke-HcNativeConsolePickerRequest -ErrorAction SilentlyContinue){$pickerHandled=[bool](Invoke-HcNativeConsolePickerRequest -Platform $script:NativePlatformReturnName)}}catch{Write-Log "Native console picker handoff failed: $($_.Exception.Message)" 'ERROR'}
                    if($pickerHandled){$script:NativePlatformOpenQuickAccess=$false;return}
                    if($script:NativePlatformOpenQuickAccess -and (Get-Command Show-HcMainMenu -ErrorAction SilentlyContinue)){Show-HcMainMenu;Write-Log "Guide/Home returned from $($script:NativePlatformReturnName) to Huymaier Quick Access."}
                    $script:NativePlatformOpenQuickAccess=$false
                    Write-Log "Closed native emulator platform interface: $($script:NativePlatformReturnName); shell input restored before deferred background runtime."
                }
                try{[void]$script:Window.Dispatcher.BeginInvoke([System.Windows.Threading.DispatcherPriority]::Input,$restore)}
                catch{
                    try{$script:Window.Activate()|Out-Null;$script:Window.Focus()|Out-Null}catch{}
                    Resume-HcRuntimeFromNativePlatform
                }
            }else{Resume-HcRuntimeFromNativePlatform}
        }
        return $true
    }catch{
        Resume-HcRuntimeFromNativePlatform
        Set-ConsoleNotice "$Platform could not be opened: $($_.Exception.Message)" 'ERROR'
        Write-Log "Native emulator platform launch failed for ${Platform}: $($_.Exception.ToString())" 'ERROR'
        try{
            if($null -ne $script:Window){$script:Window.Activate()|Out-Null;$script:Window.Focus()|Out-Null}
        }catch{}
        Render-Page
    }
    return $true
}

$script:EmulatorPlatformPickerRequest = $null

function Get-HcEmulatorPlatformSettingsPath {
    param([Parameter(Mandatory=$true)][string]$PlatformId)
    $id=$PlatformId.Trim().ToUpperInvariant()
    return Join-Path (Join-Path $env:LOCALAPPDATA 'Huymaier Console\EmulatorPlatforms') (Join-Path $id 'settings.json')
}

function Read-HcEmulatorPlatformSettingsObject {
    param([Parameter(Mandatory=$true)][string]$PlatformId)
    $path=Get-HcEmulatorPlatformSettingsPath $PlatformId
    if(Test-Path -LiteralPath $path -PathType Leaf){
        try{return Get-Content -Raw -LiteralPath $path -Encoding UTF8|ConvertFrom-Json}catch{}
    }
    $default=Join-Path $script:BaseDir ("EmulatorPlatforms\{0}\settings.default.json" -f $PlatformId.Trim().ToUpperInvariant())
    if(Test-Path -LiteralPath $default -PathType Leaf){try{return Get-Content -Raw -LiteralPath $default -Encoding UTF8|ConvertFrom-Json}catch{}}
    return [pscustomobject]@{}
}

function Set-HcJsonProperty {
    param([Parameter(Mandatory=$true)]$Object,[Parameter(Mandatory=$true)][string]$Name,$Value)
    $property=$Object.PSObject.Properties[$Name]
    if($null -eq $property){$Object|Add-Member -NotePropertyName $Name -NotePropertyValue $Value -Force}else{$Object.$Name=$Value}
}

function Save-HcEmulatorPlatformSettingsObject {
    param([Parameter(Mandatory=$true)][string]$PlatformId,[Parameter(Mandatory=$true)]$Settings)
    $path=Get-HcEmulatorPlatformSettingsPath $PlatformId
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $path)|Out-Null
    $Settings|ConvertTo-Json -Depth 30|Set-Content -LiteralPath $path -Encoding UTF8
    return $path
}

function Update-HcEmulatorPlatformPathSetting {
    param([Parameter(Mandatory=$true)]$Request,[Parameter(Mandatory=$true)][string]$SelectedPath)
    $id=([string](Get-EntryProperty $Request 'platformId' '')).Trim().ToUpperInvariant()
    $action=[string](Get-EntryProperty $Request 'action' '')
    if(-not $id -or -not $action){throw 'The emulator picker request is incomplete.'}
    $settings=Read-HcEmulatorPlatformSettingsObject $id
    switch($id){
        'PS1' {
            switch($action){
                'PrimaryEmulator' {Set-HcJsonProperty $settings 'duckStationPath' $SelectedPath}
                'DataRoot' {Set-HcJsonProperty $settings 'dataRoot' $SelectedPath}
                'GameFolder' {$items=@(Get-EntryProperty $settings 'gameFolders' @());if($SelectedPath -notin $items){$items+=,$SelectedPath};Set-HcJsonProperty $settings 'gameFolders' ([object[]]$items)}
                'Ambience' {Set-HcJsonProperty $settings 'ambienceAudioPath' $SelectedPath}
                default {throw "Unsupported PS1 picker action: $action"}
            }
        }
        'PS2' {
            switch($action){
                'PrimaryEmulator' {Set-HcJsonProperty $settings 'pcsx2Path' $SelectedPath;Set-HcJsonProperty $settings 'installationMode' 'External'}
                'DataRoot' {Set-HcJsonProperty $settings 'pcsx2DataPath' $SelectedPath}
                'GameFolder' {$items=@(Get-EntryProperty $settings 'libraryRoots' @());if($SelectedPath -notin $items){$items+=,$SelectedPath};Set-HcJsonProperty $settings 'libraryRoots' ([object[]]$items)}
                default {throw "Unsupported PS2 picker action: $action"}
            }
        }
        'PS3' {
            switch($action){
                'PrimaryEmulator' {Set-HcJsonProperty $settings 'rpcs3Path' $SelectedPath;Set-HcJsonProperty $settings 'installationMode' 'External'}
                'DataRoot' {Set-HcJsonProperty $settings 'rpcs3DataPath' $SelectedPath}
                'GameFolder' {$items=@(Get-EntryProperty $settings 'libraryRoots' @());if($SelectedPath -notin $items){$items+=,$SelectedPath};Set-HcJsonProperty $settings 'libraryRoots' ([object[]]$items)}
                default {throw "Unsupported PS3 picker action: $action"}
            }
        }
        default {
            switch($action){
                'PrimaryEmulator' {Set-HcJsonProperty $settings 'emulatorPath' $SelectedPath}
                'FallbackEmulator' {Set-HcJsonProperty $settings 'fallbackEmulatorPath' $SelectedPath}
                'DataRoot' {Set-HcJsonProperty $settings 'emulatorDataPath' $SelectedPath}
                'GameFolder' {$items=@(Get-EntryProperty $settings 'gameFolders' @());if($SelectedPath -notin $items){$items+=,$SelectedPath};Set-HcJsonProperty $settings 'gameFolders' ([object[]]$items)}
                'Ambience' {Set-HcJsonProperty $settings 'ambiencePath' $SelectedPath;Set-HcJsonProperty $settings 'ambienceEnabled' $true}
                default {throw "Unsupported emulator picker action: $action"}
            }
            Set-HcJsonProperty $settings 'schemaVersion' 6
        }
    }
    [void](Save-HcEmulatorPlatformSettingsObject $id $settings)
}

function Complete-HcEmulatorPlatformPicker {
    param([Parameter(Mandatory=$true)][string]$SelectedPath)
    $request=$script:EmulatorPlatformPickerRequest
    if($null -eq $request){return $false}
    $action=[string](Get-EntryProperty $request 'action' '')
    $platform=[string](Get-EntryProperty $request 'displayName' (Get-EntryProperty $request 'platformId' 'Console'))
    try{
        if($action -eq 'ExportSave'){
            $source=[string](Get-EntryProperty $request 'sourcePath' '')
            if(-not(Test-Path -LiteralPath $source)){throw 'The save to export no longer exists.'}
            if(-not(Test-Path -LiteralPath $SelectedPath -PathType Container)){throw 'Choose a destination folder.'}
            $name=[string](Get-EntryProperty $request 'suggestedName' (Split-Path -Leaf $source));if(-not $name){$name='Huymaier Save'}
            $target=Join-Path $SelectedPath $name
            if(Test-Path -LiteralPath $target){$target=Join-Path $SelectedPath ($name+'-'+(Get-Date -Format 'yyyyMMdd-HHmmss'))}
            if(Test-Path -LiteralPath $source -PathType Container){Copy-Item -LiteralPath $source -Destination $target -Recurse -Force}else{Copy-Item -LiteralPath $source -Destination $target -Force}
            Set-ConsoleNotice "$platform save exported." 'SUCCESS'
        }else{
            Update-HcEmulatorPlatformPathSetting -Request $request -SelectedPath $SelectedPath
            Set-ConsoleNotice "$platform settings updated." 'SUCCESS'
        }
    }catch{
        Set-ConsoleNotice "$platform selection could not be saved: $($_.Exception.Message)" 'ERROR'
        Write-Log "Emulator platform picker completion failed for ${platform}: $($_.Exception.ToString())" 'ERROR'
        return $true
    }finally{
        $script:EmulatorPlatformPickerRequest=$null
    }
    $script:SelectedTab=$script:FileBrowserReturnTab
    $script:SubPage=$script:FileBrowserReturnSubPage
    if($script:SubPage -eq 'FilePicker'){$script:SubPage=''}
    $script:SelectedAction=0
    try{Start-LibraryScan}catch{}
    Render-Page;Update-NavVisuals
    if($action -ne 'ExportSave'){
        $reopen=[string](Get-EntryProperty $request 'displayName' (Get-EntryProperty $request 'platformId' ''))
        if($reopen){try{[void](Start-HcEmulatorPlatform $reopen)}catch{Write-Log "Could not reopen $reopen after Huymaier picker: $($_.Exception.Message)" 'WARN'}}
    }
    return $true
}

function Start-HcEmulatorInstall {
    param([Parameter(Mandatory=$true)]$Request)
    $id=([string](Get-EntryProperty $Request 'platformId' '')).Trim().ToUpperInvariant()
    $display=[string](Get-EntryProperty $Request 'displayName' $id)
    if(-not $id){return $false}
    $installer=Join-Path $script:BaseDir 'HuymaierEmulatorInstaller.ps1'
    if(-not(Test-Path -LiteralPath $installer -PathType Leaf)){Set-ConsoleNotice 'The Huymaier emulator installer is missing.' 'ERROR';return $true}
    $root=Join-Path (Join-Path $env:LOCALAPPDATA 'Huymaier Console') 'Emulators'
    try{
        Set-ConsoleNotice "Installing the latest supported $display emulator…" 'INFO';Render-Page
        $output=@()
        try{$output=@(& $installer -PlatformId $id -DestinationRoot $root -ConsoleRoot $script:BaseDir)}catch{throw}
        if(-not $?){throw 'The emulator installer script did not complete successfully.'}
        $json=$null
        foreach($line in @($output|ForEach-Object{[string]$_}|Where-Object{$_ -match '^\s*\{.*\}\s*$'})){
            try{$json=$line|ConvertFrom-Json}catch{}
        }
        if($null -eq $json -or [string]::IsNullOrWhiteSpace([string]$json.Executable)){throw 'The installer did not report the installed executable.'}
        $installRequest=[pscustomobject]@{platformId=$id;displayName=$display;action='PrimaryEmulator'}
        Update-HcEmulatorPlatformPathSetting -Request $installRequest -SelectedPath ([string]$json.Executable)
        Set-ConsoleNotice "$display emulator installed and connected." 'SUCCESS'
        try{Start-LibraryScan}catch{}
        Render-Page;Update-NavVisuals
        [void](Start-HcEmulatorPlatform $display)
    }catch{
        Set-ConsoleNotice "$display emulator installation failed: $($_.Exception.Message)" 'ERROR'
        Write-Log "Latest emulator installation failed for ${display}: $($_.Exception.ToString())" 'ERROR'
        Render-Page;Update-NavVisuals
    }
    return $true
}

function Invoke-HcNativeConsolePickerRequest {
    param([string]$Platform='')
    $requestPath=Join-Path (Join-Path $env:LOCALAPPDATA 'Huymaier Console\EmulatorPlatforms') 'picker-request.json'
    if(-not(Test-Path -LiteralPath $requestPath -PathType Leaf)){return $false}
    try{
        $request=Get-Content -Raw -LiteralPath $requestPath -Encoding UTF8|ConvertFrom-Json
        Remove-Item -LiteralPath $requestPath -Force -ErrorAction SilentlyContinue
        if($null -eq $request){return $false}
        $action=[string](Get-EntryProperty $request 'action' '')
        $id=[string](Get-EntryProperty $request 'platformId' '')
        $display=[string](Get-EntryProperty $request 'displayName' $(if($Platform){$Platform}else{$id}))
        if(-not $action -or -not $id){return $false}
        $script:EmulatorPlatformPickerRequest=$request
        $start=[string](Get-EntryProperty $request 'startPath' $env:USERPROFILE)
        if($start -and (Test-Path -LiteralPath $start -PathType Leaf)){$start=Split-Path -Parent $start}
        if(-not($start -and (Test-Path -LiteralPath $start -PathType Container))){$start=$env:USERPROFILE}
        switch($action){
            'PrimaryEmulator' {Start-NativeFilePicker -Mode PickExecutable -Store $display -EntryType 'EmulatorPlatform' -ReturnTab $script:SelectedTab -StartPath $start;return $true}
            'FallbackEmulator' {Start-NativeFilePicker -Mode PickExecutable -Store $display -EntryType 'EmulatorPlatform' -ReturnTab $script:SelectedTab -StartPath $start;return $true}
            'DataRoot' {Start-NativeFilePicker -Mode PickFolder -Store "$display emulator data" -EntryType 'EmulatorPlatform' -ReturnTab $script:SelectedTab -StartPath $start;return $true}
            'GameFolder' {Start-NativeFilePicker -Mode PickFolder -Store "$display game folder" -EntryType 'EmulatorPlatform' -ReturnTab $script:SelectedTab -StartPath $start;return $true}
            'Ambience' {Start-NativeFilePicker -Mode PickAudio -Store "$display ambience" -EntryType 'EmulatorPlatform' -ReturnTab $script:SelectedTab -StartPath $start;return $true}
            'ExportSave' {Start-NativeFilePicker -Mode PickFolder -Store "$display save export" -EntryType 'EmulatorPlatform' -ReturnTab $script:SelectedTab -StartPath $start;return $true}
            'InstallPrimaryEmulator' {$script:EmulatorPlatformPickerRequest=$null;return (Start-HcEmulatorInstall $request)}
            'OpenControllerSettings' {$script:EmulatorPlatformPickerRequest=$null;$script:SelectedTab=7;$script:SubPage='Controllers';$script:SelectedAction=0;Render-Page;Update-NavVisuals;return $true}
            default {$script:EmulatorPlatformPickerRequest=$null;Write-Log "Unknown native console picker request '$action' from $display." 'WARN';return $false}
        }
    }catch{
        try{Remove-Item -LiteralPath $requestPath -Force -ErrorAction SilentlyContinue}catch{}
        $script:EmulatorPlatformPickerRequest=$null
        Write-Log "Native console picker request could not be processed: $($_.Exception.ToString())" 'ERROR'
        Set-ConsoleNotice 'The console file-browser request could not be opened.' 'ERROR'
        return $false
    }
}

# HES was retired from Huymaier Console in v0.24.11. Keep migration tolerant
# by filtering any stale provider or imported-library markers at the UI boundary.
if(Get-Command Get-GameProviderDefinitions -ErrorAction SilentlyContinue){
    $script:HcEmulatorBaseProviderDefinitions=${function:Get-GameProviderDefinitions}
    function Get-GameProviderDefinitions {
        return [object[]]@((& $script:HcEmulatorBaseProviderDefinitions)|Where-Object{
            -not [string]::Equals([string](Get-EntryProperty $_ 'Id' ''),'HES',[StringComparison]::OrdinalIgnoreCase)
        })
    }
}

if(Get-Command Get-HcMainMenuEntries -ErrorAction SilentlyContinue){
    $script:HcEmulatorBaseMainMenuEntries=${function:Get-HcMainMenuEntries}
    function Get-HcMainMenuEntries {
        return [object[]]@((& $script:HcEmulatorBaseMainMenuEntries)|Where-Object{
            -not [string]::Equals([string](Get-EntryProperty $_ 'Mode' ''),'HES',[StringComparison]::OrdinalIgnoreCase) -and
            -not [string]::Equals([string](Get-EntryProperty $_ 'Title' ''),'HES',[StringComparison]::OrdinalIgnoreCase)
        })
    }
}

$script:HcEmulatorBaseGetGameHubPlatforms=${function:Get-GameHubPlatforms}
function Get-GameHubPlatforms {
    $items=New-Object System.Collections.ArrayList
    $seen=@{}
    foreach($platform in @(& $script:HcEmulatorBaseGetGameHubPlatforms)){
        $name=[string]$platform
        if(-not $name -or [string]::Equals($name,'HES',[StringComparison]::OrdinalIgnoreCase)){continue}
        $key=$name.ToLowerInvariant()
        if(-not $seen.ContainsKey($key)){[void]$items.Add($name);$seen[$key]=$true}
    }
    foreach($entry in @(Get-HcEmulatorPlatformEntries)){
        $name=[string](Get-EntryProperty $entry 'menuName' (Get-EntryProperty $entry 'name' (Get-EntryProperty $entry 'displayName' (Get-EntryProperty $entry 'id' 'Emulator'))))
        if(-not $name){continue}
        $key=$name.ToLowerInvariant()
        if(-not $seen.ContainsKey($key)){[void]$items.Add($name);$seen[$key]=$true}
    }
    return [object[]]$items.ToArray()
}

$script:HcEmulatorBaseInvokeAction=${function:Invoke-Action}
function Invoke-Action {
    param([string]$Id)
    if((Get-Command Invoke-HcShellCriticalAction -ErrorAction SilentlyContinue) -and (Invoke-HcShellCriticalAction $Id)){return}
    if($Id -match '^platform-select:(\d+)$'){
        $index=[int]$matches[1]
        if($index -ge 0 -and $index -lt $script:GameHubPlatforms.Count){
            $platform=[string]$script:GameHubPlatforms[$index]
            if(Test-HcEmulatorPlatformMenuName $platform){
                $script:SelectedGamePlatform=$platform
                # Native emulator interfaces scan their own local metadata/artwork
                # only after selection; do not start the general online worker.
                $script:SelectedAction=$index
                [void](Start-HcEmulatorPlatform $platform)
                return
            }
        }
    }
    & $script:HcEmulatorBaseInvokeAction $Id
}
