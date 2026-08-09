# Huymaier Console emulator-platform host.
# Loaded after the shared game-experience module so emulator platforms can
# participate in the existing Platforms rail without replacing storefront code.

$script:EmulatorPlatformRegistryPath = Join-Path $script:BaseDir 'EmulatorPlatforms\platform-registry.json'
$script:EmulatorPlatformRegistryCache = $null
$script:EmulatorPlatformRegistryStamp = [datetime]::MinValue
$script:EmulatorShellProcesses = @{}
$script:NativePlatformRetryAfter = [datetime]::MinValue
$script:NativePlatformActive = $false

function Suspend-HcRuntimeForNativePlatform {
    if($script:NativePlatformActive){return}
    $script:NativePlatformActive=$true
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

function Resume-HcRuntimeFromNativePlatform {
    $script:NativePlatformActive=$false
    foreach($name in @('MainClockTimer','MainSystemTimer','MainGamepadTimer')){
        try{
            $timer=Get-Variable -Name $name -Scope Script -ValueOnly -ErrorAction SilentlyContinue
            if($null -ne $timer){$timer.Start()}
        }catch{}
    }
    try{if(Get-Command Set-BackgroundAnimationState -ErrorAction SilentlyContinue){Set-BackgroundAnimationState}}catch{}
    try{if(Get-Command Set-FpsCounterState -ErrorAction SilentlyContinue){Set-FpsCounterState}}catch{}
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
                        # The main Console window and its visual tree stay alive behind
                        # the modal native platform. Do not rebuild the page on return:
                        # doing so raced deferred Library/artwork work and caused some
                        # systems to crash or restore with a squeezed/empty right column.
                        Resume-HcRuntimeFromNativePlatform
                        try{
                            if('HuymaierConsole.NativeApp.NativeWindowActivation' -as [type]){
                                [HuymaierConsole.NativeApp.NativeWindowActivation]::Restore($script:Window)
                            }else{$script:Window.Activate()|Out-Null;$script:Window.Focus()|Out-Null}
                        }catch{}
                        $script:ControllerInputGuardUntil=[datetime]::Now.AddMilliseconds(450)
                        if($script:NativePlatformOpenQuickAccess -and (Get-Command Show-HcMainMenu -ErrorAction SilentlyContinue)){Show-HcMainMenu;Write-Log "Guide/Home returned from $($script:NativePlatformReturnName) to Huymaier Quick Access."}
                        $script:NativePlatformOpenQuickAccess=$false
                        Write-Log "Closed native emulator platform interface: $($script:NativePlatformReturnName); existing Console view restored in place."
                    }
                    try{[void]$script:Window.Dispatcher.BeginInvoke([System.Windows.Threading.DispatcherPriority]::ContextIdle,$restore)}
                    catch{Resume-HcRuntimeFromNativePlatform}
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
            if(Test-HcEmulatorPlatform $platform){
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
