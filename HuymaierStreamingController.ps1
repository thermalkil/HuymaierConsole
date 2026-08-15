# Huymaier Console shared controller-cursor runtime.
# Loaded after HuymaierWebBrowser.ps1, HuymaierShellRedesign.ps1 and
# HuymaierAppLibrary.ps1.  It keeps normal shell navigation unchanged while
# providing smooth pointer surfaces for Web and native streaming applications.

Set-StrictMode -Version 2.0
$script:HcStreamingCursorHostPath=Join-Path $script:BaseDir 'HuymaierStreamingCursorHost.exe'
$script:HcStreamingArtworkRoot=Join-Path $script:DataDir 'AppArtwork'
$script:HcSmoothBrowserCursorLastAt=[datetime]::MinValue
$script:HcBrowserDriveLastX=0.0
$script:HcBrowserDriveLastY=0.0
$script:HcBrowserDriveLastSpeed=0.0
$script:HcBrowserDriveLastSentAt=[datetime]::MinValue
$script:HcBrowserDriveActive=$false
$script:HcStreamingBaseGetPageDefinition=${function:Get-PageDefinition}
$script:HcStreamingBaseAdjustSelectedSlider=${function:Adjust-SelectedSlider}
$script:HcStreamingBaseStartManagedApp=${function:Start-HcManagedApp}
$script:HcStreamingBaseAddNativeCatalogApp=${function:Add-HcNativeCatalogApp}
$script:HcStreamingBaseAddControllerCatalogApp=${function:Add-HcControllerCatalogApp}
$script:HcStreamingBaseBrowserController=${function:Handle-HcBrowserController}
$script:HcStreamingBaseBrowserToolbarVisuals=${function:Update-HcBrowserToolbarVisuals}
New-Item -ItemType Directory -Force -Path $script:HcStreamingArtworkRoot|Out-Null

function Initialize-HcControllerCursorSettings {
    $changed=$false
    if($null -eq $script:Config.PSObject.Properties['ControllerCursorSpeed']){
        $script:Config|Add-Member -NotePropertyName ControllerCursorSpeed -NotePropertyValue 100 -Force
        $changed=$true
    }
    $speed=100
    try{$speed=[int]$script:Config.ControllerCursorSpeed}catch{}
    $clamped=[math]::Max(40,[math]::Min(200,$speed))
    if($clamped -ne $speed){$script:Config.ControllerCursorSpeed=$clamped;$changed=$true}
    if($changed){Save-Config}
}

function Get-HcControllerCursorSpeed {
    Initialize-HcControllerCursorSettings
    try{return [math]::Max(40,[math]::Min(200,[int]$script:Config.ControllerCursorSpeed))}catch{return 100}
}

function Get-HcGameInputPointerState {
    try{
        if('HuymaierConsole.NativeApp.HuymaierPointerInput' -as [type]){
            return [HuymaierConsole.NativeApp.HuymaierPointerInput]::GetState()
        }
    }catch{}
    return $null
}

function Convert-HcCursorAxis {
    param([double]$Value)
    $deadzone=0.14
    $magnitude=[math]::Abs($Value)
    if($magnitude -le $deadzone){return 0.0}
    $normalized=[math]::Min(1.0,($magnitude-$deadzone)/(1.0-$deadzone))
    $curved=[math]::Pow($normalized,1.65)
    if($Value -lt 0){return -$curved}
    return $curved
}

function Move-HcBrowserVirtualCursorDelta {
    param([double]$X,[double]$Y)
    if(-not(Get-Command Install-HcBrowserVirtualCursorScript -ErrorAction SilentlyContinue)){return}
    Install-HcBrowserVirtualCursorScript
    $ci=[Globalization.CultureInfo]::InvariantCulture
    $dx=$X.ToString('0.###',$ci)
    $dy=$Y.ToString('0.###',$ci)
    Invoke-HcBrowserScriptAsync "window.__hcCursorMove?window.__hcCursorMove($dx,$dy):false"
}

function Set-HcBrowserAnalogDrive {
    param([double]$X,[double]$Y,[double]$PixelsPerSecond)
    if(-not(Get-Command Install-HcBrowserVirtualCursorScript -ErrorAction SilentlyContinue)){return}
    Install-HcBrowserVirtualCursorScript
    $ci=[Globalization.CultureInfo]::InvariantCulture
    $xText=$X.ToString('0.####',$ci)
    $yText=$Y.ToString('0.####',$ci)
    $speedText=$PixelsPerSecond.ToString('0.##',$ci)
    $scriptText=@"
(()=>{if(!window.__hcCursor)return false;
if(!window.__hcCursorDriveState){
  window.__hcCursorDriveState={x:0,y:0,speed:0,last:performance.now(),raf:0};
  const tick=(now)=>{
    const s=window.__hcCursorDriveState;
    let dt=(now-s.last)/1000;s.last=now;
    if(dt<0||dt>0.05)dt=0.016;
    if((Math.abs(s.x)>0.0001||Math.abs(s.y)>0.0001)&&window.__hcCursor){
      window.__hcCursor.x+=s.x*s.speed*dt;
      window.__hcCursor.y+=s.y*s.speed*dt;
      if(window.__hcCursorRender)window.__hcCursorRender();
    }
    s.raf=requestAnimationFrame(tick);
  };
  window.__hcCursorDrive=(x,y,speed)=>{const s=window.__hcCursorDriveState;s.x=x;s.y=y;s.speed=speed;return true;};
  window.__hcCursorDriveState.raf=requestAnimationFrame(tick);
}
return window.__hcCursorDrive($xText,$yText,$speedText);
})()
"@
    Invoke-HcBrowserScriptAsync $scriptText
    $script:HcBrowserDriveLastX=$X
    $script:HcBrowserDriveLastY=$Y
    $script:HcBrowserDriveLastSpeed=$PixelsPerSecond
    $script:HcBrowserDriveLastSentAt=Get-Date
    $script:HcBrowserDriveActive=([math]::Abs($X) -gt 0.0001 -or [math]::Abs($Y) -gt 0.0001)
}

function Stop-HcBrowserAnalogDrive {
    if(-not $script:HcBrowserDriveActive -and $script:HcBrowserDriveLastSpeed -eq 0.0){return}
    try{
        if(Get-Command Invoke-HcBrowserScriptAsync -ErrorAction SilentlyContinue){
            Invoke-HcBrowserScriptAsync 'window.__hcCursorDrive?window.__hcCursorDrive(0,0,0):false'
        }
    }catch{}
    $script:HcBrowserDriveLastX=0.0
    $script:HcBrowserDriveLastY=0.0
    $script:HcBrowserDriveLastSpeed=0.0
    $script:HcBrowserDriveLastSentAt=Get-Date
    $script:HcBrowserDriveActive=$false
}

function Scroll-HcBrowserVirtualCursorDelta {
    param([double]$X,[double]$Y)
    if(-not(Get-Command Install-HcBrowserVirtualCursorScript -ErrorAction SilentlyContinue)){return}
    Install-HcBrowserVirtualCursorScript
    $ci=[Globalization.CultureInfo]::InvariantCulture
    $dx=$X.ToString('0.###',$ci)
    $dy=$Y.ToString('0.###',$ci)
    Invoke-HcBrowserScriptAsync "window.__hcCursorScroll?window.__hcCursorScroll($dx,$dy):false"
}

function Update-HcSmoothBrowserPointer {
    $state=Get-HcGameInputPointerState
    if($null -eq $state -or -not [bool]$state.Available){
        Stop-HcBrowserAnalogDrive
        return $false
    }

    # One radial deadzone/curve preserves the real stick angle, so diagonals
    # are simultaneous rather than decomposed into alternating X/Y steps.
    $rawX=[double]$state.LeftX
    $rawY=-[double]$state.LeftY
    $magnitude=[math]::Sqrt(($rawX*$rawX)+($rawY*$rawY))
    $x=0.0;$y=0.0
    if($magnitude -gt 0.14){
        $normalized=[math]::Min(1.0,($magnitude-0.14)/(1.0-0.14))
        $curved=[math]::Pow($normalized,1.55)
        if($magnitude -gt 0.000001){
            $x=($rawX/$magnitude)*$curved
            $y=($rawY/$magnitude)*$curved
        }
    }

    $speed=[double](Get-HcControllerCursorSpeed)
    $maxPixelsPerSecond=1500.0*($speed/100.0)
    $now=Get-Date
    $changed=([math]::Abs($x-$script:HcBrowserDriveLastX) -ge 0.018 -or
              [math]::Abs($y-$script:HcBrowserDriveLastY) -ge 0.018 -or
              [math]::Abs($maxPixelsPerSecond-$script:HcBrowserDriveLastSpeed) -ge 1.0)
    $heartbeat=($script:HcBrowserDriveLastSentAt -eq [datetime]::MinValue -or
                ($now-$script:HcBrowserDriveLastSentAt).TotalMilliseconds -ge 250)
    $neutralChanged=(([math]::Abs($x) -le 0.0001 -and [math]::Abs($y) -le 0.0001) -and $script:HcBrowserDriveActive)
    if($changed -or $heartbeat -or $neutralChanged){
        Set-HcBrowserAnalogDrive $x $y $maxPixelsPerSecond
    }

    # Pointer motion is integrated by requestAnimationFrame in-page. Keep only
    # right-stick scrolling on the PowerShell poll loop.
    $dt=0.016
    if($script:HcSmoothBrowserCursorLastAt -ne [datetime]::MinValue){
        $dt=($now-$script:HcSmoothBrowserCursorLastAt).TotalSeconds
        if($dt -le 0 -or $dt -gt 0.1){$dt=0.016}
    }
    $script:HcSmoothBrowserCursorLastAt=$now
    $sx=Convert-HcCursorAxis ([double]$state.RightX)
    $sy=Convert-HcCursorAxis ([double]$state.RightY)
    if([math]::Abs($sx) -gt 0.0001 -or [math]::Abs($sy) -gt 0.0001){
        Scroll-HcBrowserVirtualCursorDelta ($sx*900.0*$dt) (-$sy*1050.0*$dt)
    }
    return $true
}

function Handle-HcBrowserController {
    param([int]$Mask,[string]$Direction)
    if(-not $script:HcBrowserActive){
        Stop-HcBrowserAnalogDrive
        return $false
    }
    if((Get-Command Test-HcMainMenuVisible -ErrorAction SilentlyContinue) -and (Test-HcMainMenuVisible)){
        Stop-HcBrowserAnalogDrive
        return $false
    }

    if($script:HcBrowserFocusArea -eq 'Toolbar'){
        Stop-HcBrowserAnalogDrive
        $script:HcSmoothBrowserCursorLastAt=[datetime]::MinValue
        $handled=& $script:HcStreamingBaseBrowserController $Mask $Direction
        if(-not $script:HcBrowserActive){Stop-HcBrowserAnalogDrive}
        return $handled
    }

    $analog=Update-HcSmoothBrowserPointer
    if(-not $analog -and $Direction){
        $now=Get-Date
        if($Direction -ne $script:LastDirection -or $now -ge $script:NextDirectionAt){
            if(Get-Command Move-HcBrowserVirtualCursor -ErrorAction SilentlyContinue){Move-HcBrowserVirtualCursor $Direction}
            $isNew=($Direction -ne $script:LastDirection)
            $script:LastDirection=$Direction
            $script:NextDirectionAt=$now.AddMilliseconds($(if($isNew){90}else{28}))
        }
    }elseif(-not $Direction){
        $script:LastDirection=''
        $script:NextDirectionAt=[datetime]::MinValue
    }

    if(Is-NewButtonPress $Mask 4){Open-HcBrowserCursorKeyboard $true $false}
    if(Is-NewButtonPress $Mask 8){Invoke-HcBrowserToolbarAction 'Back'}
    if(Is-NewButtonPress $Mask 16){Invoke-HcBrowserControllerType}
    if(Is-NewButtonPress $Mask 32){$script:HcBrowserToolbarIndex=4;Set-HcBrowserFocusArea 'Toolbar'}
    if(Is-NewButtonPress $Mask 1024){Invoke-HcBrowserToolbarAction 'Back'}
    if(Is-NewButtonPress $Mask 2048){Invoke-HcBrowserToolbarAction 'Forward'}
    if(Is-NewButtonPress $Mask 1){$script:HcBrowserToolbarIndex=4;Set-HcBrowserFocusArea 'Toolbar'}
    if(Is-NewButtonPress $Mask 2){if(Get-Command Show-HcMainMenu -ErrorAction SilentlyContinue){Show-HcMainMenu}}
    $script:LastGamepadMask=$Mask
    return $true
}

function Update-HcBrowserToolbarVisuals {
    & $script:HcStreamingBaseBrowserToolbarVisuals
    try{
        if($script:HcBrowserActive -and $script:HcBrowserFocusArea -eq 'Web' -and $null -ne $script:HcBrowserFooterText){
            $script:HcBrowserFooterText.Text=('WEB CURSOR   Left Stick Move   Right Stick Scroll   A Click / Type   X Keyboard   Y Top Bar   B Back   Cursor Speed '+(Get-HcControllerCursorSpeed)+'%')
        }
    }catch{}
}

function Get-HcAppxArtworkCandidate {
    param([string]$AppUserModelId)
    if([string]::IsNullOrWhiteSpace($AppUserModelId) -or $AppUserModelId -notmatch '!'){return ''}
    $family=$AppUserModelId.Split('!')[0]
    try{
        $package=Get-AppxPackage -ErrorAction SilentlyContinue|Where-Object{[string]::Equals([string]$_.PackageFamilyName,$family,[StringComparison]::OrdinalIgnoreCase)}|Select-Object -First 1
        if($null -eq $package -or [string]::IsNullOrWhiteSpace([string]$package.InstallLocation)){return ''}
        $assets=Join-Path ([string]$package.InstallLocation) 'Assets'
        if(-not(Test-Path -LiteralPath $assets -PathType Container)){return ''}
        $candidates=@(Get-ChildItem -LiteralPath $assets -Recurse -File -ErrorAction SilentlyContinue|Where-Object{$_.Extension -match '^\.(png|jpg|jpeg|ico)$' -and $_.Name -match '(?i)logo|square|icon'}|Sort-Object Length -Descending)
        if($candidates.Count -gt 0){return [string]$candidates[0].FullName}
    }catch{}
    return ''
}

function Copy-HcStreamingArtworkToCache {
    param([string]$Source,[string]$Key)
    if(-not $Source -or -not(Test-Path -LiteralPath $Source -PathType Leaf)){return ''}
    try{
        $safe=if($Key){$Key -replace '[^A-Za-z0-9_-]','_'}else{'app'}
        $ext=[IO.Path]::GetExtension($Source)
        if(-not $ext){$ext='.png'}
        $target=Join-Path $script:HcStreamingArtworkRoot ($safe+$ext.ToLowerInvariant())
        Copy-Item -LiteralPath $Source -Destination $target -Force
        return $target
    }catch{return ''}
}

function Resolve-HcStreamingAppArtwork {
    param($Entry,[switch]$AllowOnline)
    if($null -eq $Entry){return ''}
    $existing=[string](Get-EntryProperty $Entry 'ArtworkPath' '')
    if($existing -and (Test-Path -LiteralPath $existing -PathType Leaf)){return $existing}
    $key=[string](Get-EntryProperty $Entry 'CatalogId' '')
    if(-not $key){$key=[string](Get-EntryProperty $Entry 'Name' 'app')}
    $aumid=[string](Get-EntryProperty $Entry 'AppUserModelId' '')
    $packageArt=Get-HcAppxArtworkCandidate $aumid
    if($packageArt){
        $cached=Copy-HcStreamingArtworkToCache $packageArt $key
        if($cached){Set-HcAppObjectProperty $Entry 'ArtworkPath' $cached|Out-Null;return $cached}
    }
    if($AllowOnline){
        $web=[string](Get-EntryProperty $Entry 'WebUrl' '')
        if($web){
            try{
                $uri=[uri]$web
                $favicon=('{0}://{1}/favicon.ico' -f $uri.Scheme,$uri.Host)
                $safe=$key -replace '[^A-Za-z0-9_-]','_'
                $target=Join-Path $script:HcStreamingArtworkRoot ($safe+'.ico')
                Invoke-WebRequest -UseBasicParsing -Uri $favicon -OutFile $target -TimeoutSec 5 -ErrorAction Stop
                if((Test-Path -LiteralPath $target -PathType Leaf) -and (Get-Item -LiteralPath $target).Length -gt 128){Set-HcAppObjectProperty $Entry 'ArtworkPath' $target|Out-Null;return $target}
                Remove-Item -LiteralPath $target -Force -ErrorAction SilentlyContinue
            }catch{}
        }
    }
    return ''
}

function Initialize-HcStreamingAppArtwork {
    $changed=$false
    foreach($app in @($script:Config.CustomApps)){
        if($null -eq $app){continue}
        $category=Get-HcAppCategory $app
        if($category -notin @('Streaming','Music')){continue}
        $before=[string](Get-EntryProperty $app 'ArtworkPath' '')
        $after=Resolve-HcStreamingAppArtwork $app
        if($after -and -not [string]::Equals($before,$after,[StringComparison]::OrdinalIgnoreCase)){$changed=$true}
    }
    if($changed){Save-Config}
}

function Start-HcNativeStreamingApp {
    param($Entry)
    if($null -eq $Entry){return}
    $id=[string](Get-EntryProperty $Entry 'AppUserModelId' '')
    if(-not $id){Set-ConsoleNotice 'This streaming app is not installed natively yet.' 'WARN';return}
    if(-not(Test-Path -LiteralPath $script:HcStreamingCursorHostPath -PathType Leaf)){Set-ConsoleNotice 'The native streaming controller host is missing.' 'ERROR';return}
    try{
        Get-Process -Name 'HuymaierStreamingCursorHost' -ErrorAction SilentlyContinue|Stop-Process -Force -ErrorAction SilentlyContinue
        $speed=Get-HcControllerCursorSpeed
        Start-Process -FilePath $script:HcStreamingCursorHostPath -ArgumentList @('--parent',$PID,'--speed',$speed) -WindowStyle Hidden|Out-Null
        Start-Process explorer.exe -ArgumentList ('shell:AppsFolder\'+$id)|Out-Null
        Send-ConsoleToBackground
        Write-Log ('Native streaming app launched with controller cursor: '+[string](Get-EntryProperty $Entry 'Name' 'App'))
    }catch{Set-ConsoleNotice ('Streaming app could not be opened: '+$_.Exception.Message) 'ERROR'}
}

function Start-HcManagedApp {
    param($Entry)
    if($null -eq $Entry){return}
    $mode=[string](Get-EntryProperty $Entry 'PreferredLaunchMode' 'Native')
    $aumid=[string](Get-EntryProperty $Entry 'AppUserModelId' '')
    $category=Get-HcAppCategory $Entry
    if([string]::Equals($mode,'Native',[StringComparison]::OrdinalIgnoreCase) -and $aumid -and $category -eq 'Streaming'){
        try{Add-ToRecent 'App' $Entry}catch{}
        Resolve-HcStreamingAppArtwork $Entry -AllowOnline|Out-Null
        Save-Config
        Start-HcNativeStreamingApp $Entry
        return
    }
    & $script:HcStreamingBaseStartManagedApp $Entry
}

function Add-HcNativeCatalogApp {
    param($Catalog,[switch]$Launch)
    $result=& $script:HcStreamingBaseAddNativeCatalogApp $Catalog
    if($result){
        $index=Find-HcPinnedCatalogAppIndex ([string]$Catalog.Id)
        if($index -ge 0){
            $entry=@($script:Config.CustomApps)[$index]
            Resolve-HcStreamingAppArtwork $entry -AllowOnline|Out-Null
            Set-HcAppObjectProperty $entry 'PreferredLaunchMode' 'Native'|Out-Null
            Set-HcAppObjectProperty $entry 'ControllerMouseEnabled' $true|Out-Null
            Set-HcAppObjectProperty $entry 'FullscreenPresentation' $true|Out-Null
            Save-Config
            if($Launch){Start-HcManagedApp $entry}
        }
    }
    return $result
}

function Add-HcControllerCatalogApp {
    param($Catalog,[switch]$Launch)
    & $script:HcStreamingBaseAddControllerCatalogApp $Catalog
    $index=Find-HcPinnedCatalogAppIndex ([string]$Catalog.Id)
    if($index -ge 0){
        $entry=@($script:Config.CustomApps)[$index]
        Resolve-HcStreamingAppArtwork $entry -AllowOnline|Out-Null
        Save-Config
        if($Launch){Start-HcManagedApp $entry}
    }
}

function Get-PageDefinition {
    param([int]$Index)
    $page=& $script:HcStreamingBaseGetPageDefinition $Index
    if($null -eq $page){return $page}
    if($Index -eq 7 -and $script:SubPage -eq 'Controllers'){
        $actions=New-Object System.Collections.ArrayList
        foreach($action in @($page.Actions)){
            if([string](Get-EntryProperty $action 'Id' '') -eq 'subpage-back'){
                [void]$actions.Add((New-SliderAction 'controller-cursor-speed-slider' 'Cursor speed' (Get-HcControllerCursorSpeed) 'Shared Web/native streaming pointer speed. Left/Right adjusts fine-control maximum velocity.' 40 200))
            }
            [void]$actions.Add($action)
        }
        $page.Actions=[object[]]$actions.ToArray()
    }
    if($Index -eq 2 -and $script:SubPage -eq 'AppCatalogDetail'){
        $catalog=Get-HcCatalogEntry $script:HcSelectedCatalogId
        if($null -ne $catalog){
            $installed=Find-HcInstalledCatalogWindowsApp $catalog
            $actions=New-Object System.Collections.ArrayList
            foreach($action in @($page.Actions)){
                $id=[string](Get-EntryProperty $action 'Id' '')
                if($null -ne $installed -and $id -match '^app-catalog-controller:'){continue}
                if($id -match '^app-catalog-native:'){
                    $action.Title='Open Native App'
                    $action.Description='Full-screen native presentation with smooth controller mouse, A/Cross click, right-stick scroll and X/Square keyboard.'
                }
                [void]$actions.Add($action)
            }
            $page.Actions=[object[]]$actions.ToArray()
            if($null -ne $installed){$page.HeroText='Native app mode uses the installed Windows streaming app directly; WebView is not involved.'}
        }
    }
    return $page
}

function Adjust-SelectedSlider {
    param([int]$Delta)
    $action=Get-SelectedActionObject
    if($null -ne $action -and [string](Get-EntryProperty $action 'Id' '') -eq 'controller-cursor-speed-slider'){
        $value=[math]::Max(40,[math]::Min(200,(Get-HcControllerCursorSpeed)+$Delta))
        $script:Config.ControllerCursorSpeed=$value
        Save-Config
        try{$action.Value=$value}catch{}
        try{$control=$script:SliderControls['controller-cursor-speed-slider'];if($control){$control.Slider.Value=$value;$control.Text.Text=($value.ToString()+'%')}}catch{}
        Invoke-UiFeedback 'Navigate'
        return $true
    }
    return (& $script:HcStreamingBaseAdjustSelectedSlider $Delta)
}

Initialize-HcControllerCursorSettings
Initialize-HcStreamingAppArtwork
