# Huymaier Console unified native cursor runtime.
# The gold Huymaier cursor temporarily replaces Windows' standard pointer while
# Huymaier owns foreground focus or a curated native streaming app is active.
# WebView uses the same OS pointer + Raw HID/GameInput movement as native apps.

Set-StrictMode -Version 2.0
$script:HcUnifiedCursorHostPath=Join-Path $script:BaseDir 'HuymaierUnifiedCursorHost.exe'
$script:HcUnifiedCursorStatePath=Join-Path $script:DataDir 'cursor-context.txt'
$script:HcUnifiedShellCursorProcess=$null
$script:HcUnifiedStreamingCursorProcess=$null
$script:HcUnifiedBaseOpenBrowser=${function:Open-HuymaierBrowser}
$script:HcUnifiedBaseCloseBrowser=${function:Close-HuymaierBrowser}
$script:HcUnifiedBaseSetBrowserFocusArea=${function:Set-HcBrowserFocusArea}
$script:HcUnifiedBaseBrowserController=${function:Handle-HcBrowserController}
$script:HcUnifiedBaseBrowserKey=${function:Handle-HcBrowserKey}
$script:HcUnifiedBaseBrowserToolbarVisuals=${function:Update-HcBrowserToolbarVisuals}
$script:HcUnifiedBaseAdjustSlider=${function:Adjust-SelectedSlider}
$script:HcUnifiedBaseHideConsoleCursor=${function:Hide-ConsoleCursor}

function Set-HcUnifiedCursorContext {
    param([ValidateSet('shell','browser-web','browser-toolbar')][string]$Mode)
    try{
        $directory=Split-Path -Parent $script:HcUnifiedCursorStatePath
        if(-not(Test-Path -LiteralPath $directory -PathType Container)){New-Item -ItemType Directory -Force -Path $directory|Out-Null}
        $tmp=$script:HcUnifiedCursorStatePath+'.tmp'
        [IO.File]::WriteAllText($tmp,$Mode,(New-Object Text.UTF8Encoding($false)))
        Move-Item -LiteralPath $tmp -Destination $script:HcUnifiedCursorStatePath -Force
    }catch{Write-Log ('Unified cursor context update failed: '+$_.Exception.Message) 'WARN'}
}

function Test-HcUnifiedCursorProcessAlive {
    param($Process)
    try{return $null -ne $Process -and -not $Process.HasExited}catch{return $false}
}

function Start-HcUnifiedShellCursorHost {
    if(-not(Test-Path -LiteralPath $script:HcUnifiedCursorHostPath -PathType Leaf)){return}
    if(Test-HcUnifiedCursorProcessAlive $script:HcUnifiedShellCursorProcess){return}
    try{
        $speed=Get-HcControllerCursorSpeed
        $argLine='--parent '+$PID+' --mode shell --speed '+$speed+' --state-file "'+$script:HcUnifiedCursorStatePath+'"'
        $script:HcUnifiedShellCursorProcess=Start-Process -FilePath $script:HcUnifiedCursorHostPath -ArgumentList $argLine -WindowStyle Hidden -PassThru
        Write-Log 'Unified Huymaier system cursor host started.'
    }catch{Write-Log ('Unified shell cursor host failed to start: '+$_.Exception.Message) 'WARN'}
}

function Restart-HcUnifiedShellCursorHost {
    try{if(Test-HcUnifiedCursorProcessAlive $script:HcUnifiedShellCursorProcess){$script:HcUnifiedShellCursorProcess.Kill()}}catch{}
    $script:HcUnifiedShellCursorProcess=$null
    Start-Sleep -Milliseconds 80
    Start-HcUnifiedShellCursorHost
}

function Start-HcUnifiedStreamingCursorHost {
    try{
        Get-Process -Name 'HuymaierStreamingCursorHost' -ErrorAction SilentlyContinue|Stop-Process -Force -ErrorAction SilentlyContinue
        if(Test-HcUnifiedCursorProcessAlive $script:HcUnifiedStreamingCursorProcess){try{$script:HcUnifiedStreamingCursorProcess.Kill()}catch{}}
        $speed=Get-HcControllerCursorSpeed
        $argLine='--parent '+$PID+' --mode streaming --speed '+$speed
        $script:HcUnifiedStreamingCursorProcess=Start-Process -FilePath $script:HcUnifiedCursorHostPath -ArgumentList $argLine -WindowStyle Hidden -PassThru
        return $true
    }catch{Write-Log ('Unified native streaming cursor host failed to start: '+$_.Exception.Message) 'ERROR';return $false}
}

function Hide-HcBrowserJsCursorNow {
    try{
        if(Get-Command Invoke-HcBrowserScriptAsync -ErrorAction SilentlyContinue){
            Invoke-HcBrowserScriptAsync "(()=>{const n=document.getElementById('hc-virtual-cursor');if(n)n.style.display='none';if(window.__hcCursorDrive)window.__hcCursorDrive(0,0,0);return true})()"
        }
    }catch{}
}

# Browser Web content owns the real OS pointer through HuymaierUnifiedCursorHost.
# Do not let the shell's legacy controller path park that pointer in the corner
# while the native host is simultaneously moving it.
function Hide-ConsoleCursor {
    try{
        if($script:HcBrowserActive -and $script:HcBrowserFocusArea -eq 'Web'){
            Set-HcUnifiedCursorContext 'browser-web'
            if($script:ControllerCursorHidden){Show-ConsoleCursor}
            return
        }
    }catch{}
    & $script:HcUnifiedBaseHideConsoleCursor
}

# The old in-page cursor remains available only as dormant compatibility code.
# It must never render or move while the unified native pointer is installed.
function Show-HcBrowserVirtualCursor { Hide-HcBrowserJsCursorNow }
function Move-HcBrowserVirtualCursor { param([string]$Direction); Hide-HcBrowserJsCursorNow }
function Set-HcBrowserAnalogDrive { param([double]$X,[double]$Y,[double]$PixelsPerSecond); Hide-HcBrowserJsCursorNow }
function Stop-HcBrowserAnalogDrive { Hide-HcBrowserJsCursorNow }
function Update-HcSmoothBrowserPointer { Hide-HcBrowserJsCursorNow; return $true }

function Set-HcBrowserFocusArea {
    param([ValidateSet('Toolbar','Web')][string]$Area)
    & $script:HcUnifiedBaseSetBrowserFocusArea $Area
    Hide-HcBrowserJsCursorNow
    if($script:HcBrowserActive){
        if($Area -eq 'Web'){
            try{Show-ConsoleCursor}catch{}
            Set-HcUnifiedCursorContext 'browser-web'
        }else{Set-HcUnifiedCursorContext 'browser-toolbar'}
    }else{Set-HcUnifiedCursorContext 'shell'}
}

function Open-HuymaierBrowser {
    param([string]$Url='https://www.google.com',[string]$Title='Web')
    & $script:HcUnifiedBaseOpenBrowser $Url $Title
    if($script:HcBrowserActive){
        try{Show-ConsoleCursor}catch{}
        Set-HcUnifiedCursorContext 'browser-web'
        Hide-HcBrowserJsCursorNow
    }
    Start-HcUnifiedShellCursorHost
}

function Close-HuymaierBrowser {
    & $script:HcUnifiedBaseCloseBrowser
    Set-HcUnifiedCursorContext 'shell'
    Hide-HcBrowserJsCursorNow
}

function Handle-HcBrowserController {
    param([int]$Mask,[string]$Direction)
    if(-not $script:HcBrowserActive){Set-HcUnifiedCursorContext 'shell';return $false}
    if((Get-Command Test-HcMainMenuVisible -ErrorAction SilentlyContinue) -and (Test-HcMainMenuVisible)){Set-HcUnifiedCursorContext 'shell';return $false}

    if($script:HcBrowserFocusArea -eq 'Toolbar'){
        Set-HcUnifiedCursorContext 'browser-toolbar'
        $handled=& $script:HcUnifiedBaseBrowserController $Mask $Direction
        Hide-HcBrowserJsCursorNow
        return $handled
    }

    # Web content uses the real OS cursor. HuymaierUnifiedCursorHost handles
    # left-stick movement, A/Cross click, X/Square OSK and right-stick scroll.
    # Keep only browser-level commands here to avoid a second pointer path.
    try{Show-ConsoleCursor}catch{}
    Set-HcUnifiedCursorContext 'browser-web'
    Hide-HcBrowserJsCursorNow
    $script:LastDirection=''
    $script:NextDirectionAt=[datetime]::MinValue
    if(Is-NewButtonPress $Mask 8){Invoke-HcBrowserToolbarAction 'Back'}
    if(Is-NewButtonPress $Mask 32){$script:HcBrowserToolbarIndex=4;Set-HcBrowserFocusArea 'Toolbar'}
    if(Is-NewButtonPress $Mask 1024){Invoke-HcBrowserToolbarAction 'Back'}
    if(Is-NewButtonPress $Mask 2048){Invoke-HcBrowserToolbarAction 'Forward'}
    if(Is-NewButtonPress $Mask 1){$script:HcBrowserToolbarIndex=4;Set-HcBrowserFocusArea 'Toolbar'}
    if(Is-NewButtonPress $Mask 2){if(Get-Command Show-HcMainMenu -ErrorAction SilentlyContinue){Show-HcMainMenu}}
    $script:LastGamepadMask=$Mask
    return $true
}

function Handle-HcBrowserKey {
    param($Key)
    if(-not $script:HcBrowserActive){return $false}
    if($script:HcBrowserFocusArea -eq 'Toolbar'){return (& $script:HcUnifiedBaseBrowserKey $Key)}
    switch([string]$Key){
        'Escape' {Invoke-HcBrowserToolbarAction 'Back';return $true}
        'Back' {Invoke-HcBrowserToolbarAction 'Back';return $true}
        'F6' {Show-HcBrowserAddressKeyboard;return $true}
        'F5' {Invoke-HcBrowserToolbarAction 'Reload';return $true}
        'F1' {if(Get-Command Show-HcMainMenu -ErrorAction SilentlyContinue){Show-HcMainMenu};return $true}
        default {return $false}
    }
}

function Update-HcBrowserToolbarVisuals {
    & $script:HcUnifiedBaseBrowserToolbarVisuals
    Hide-HcBrowserJsCursorNow
    try{
        if($script:HcBrowserActive -and $null -ne $script:HcBrowserFooterText){
            if($script:HcBrowserFocusArea -eq 'Web'){$script:HcBrowserFooterText.Text=('NATIVE CURSOR   Left Stick Move   Right Stick Scroll   A Click   X Keyboard   Y Top Bar   B Back   Cursor Speed '+(Get-HcControllerCursorSpeed)+'%')}
        }
    }catch{}
}

function Start-HcNativeStreamingApp {
    param($Entry)
    if($null -eq $Entry){return}
    $id=[string](Get-EntryProperty $Entry 'AppUserModelId' '')
    if(-not $id){Set-ConsoleNotice 'This streaming app is not installed natively yet.' 'WARN';return}
    if(-not(Test-Path -LiteralPath $script:HcUnifiedCursorHostPath -PathType Leaf)){Set-ConsoleNotice 'The unified native cursor host is missing.' 'ERROR';return}
    try{
        if(-not(Start-HcUnifiedStreamingCursorHost)){Set-ConsoleNotice 'The native controller cursor could not be started.' 'ERROR';return}
        Start-Process explorer.exe -ArgumentList ('shell:AppsFolder\'+$id)|Out-Null
        Send-ConsoleToBackground
        Write-Log ('Native streaming app launched with unified cursor/fullscreen host: '+[string](Get-EntryProperty $Entry 'Name' 'App'))
    }catch{Set-ConsoleNotice ('Streaming app could not be opened: '+$_.Exception.Message) 'ERROR'}
}

function Adjust-SelectedSlider {
    param([int]$Delta)
    $action=Get-SelectedActionObject
    $isCursor=$null -ne $action -and [string](Get-EntryProperty $action 'Id' '') -eq 'controller-cursor-speed-slider'
    $result=& $script:HcUnifiedBaseAdjustSlider $Delta
    if($isCursor){Restart-HcUnifiedShellCursorHost}
    return $result
}

Set-HcUnifiedCursorContext 'shell'
Start-HcUnifiedShellCursorHost
