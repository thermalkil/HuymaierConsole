# Huymaier Console v0.26.1 external game/app overlay and process-wide Guide arbiter.
# Quick Access remains inside Huymaier Console. The physical Guide/Home system
# button is global; local Menu/Start, View/Back, and Share/Create remain distinct.

$script:HcGameBarTimer=$null
$script:HcExternalGuideDown=$false
$script:HcGameBarBackupPath=Join-Path $script:DataDir 'xbox-gamebar-backup.json'
$script:HcWindowsRestorePath=Join-Path $script:BaseDir 'Restore-HuymaierWindowsSettings.ps1'
$script:HcSystemGuideType=$null
$script:HcSystemGuideMethod=$null

function Get-HcRegistryBackupValue {
    param([string]$Path,[string]$Name)
    $exists=$false;$value=$null
    try{
        if(Test-Path -LiteralPath $Path){
            $item=Get-ItemProperty -LiteralPath $Path -Name $Name -ErrorAction SilentlyContinue
            if($null -ne $item -and $null -ne $item.PSObject.Properties[$Name]){$exists=$true;$value=$item.$Name}
        }
    }catch{}
    return [pscustomobject]@{Path=$Path;Name=$Name;Exists=$exists;Value=$value}
}

function Restore-HcXboxGameBarSuppression {
    try{
        if(Test-Path -LiteralPath $script:HcWindowsRestorePath -PathType Leaf){& $script:HcWindowsRestorePath -Quiet}
    }catch{Write-Log "Xbox Game Bar controller-setting restore failed: $($_.Exception.Message)" 'WARN'}
}

function Set-HcXboxGameBarSuppression {
    try{
        Restore-HcXboxGameBarSuppression
        $path='HKCU:\Software\Microsoft\GameBar'
        $name='UseNexusForGameBarEnabled'
        $backup=Get-HcRegistryBackupValue $path $name
        $backup|ConvertTo-Json -Depth 4|Set-Content -LiteralPath $script:HcGameBarBackupPath -Encoding UTF8
        if(-not(Test-Path -LiteralPath $path)){New-Item -Path $path -Force|Out-Null}
        Set-ItemProperty -LiteralPath $path -Name $name -Value 0 -Type DWord -Force

        $runOnce='HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce'
        if(-not(Test-Path -LiteralPath $runOnce)){New-Item -Path $runOnce -Force|Out-Null}
        $cmd='powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "'+$script:HcWindowsRestorePath+'" -Quiet'
        Set-ItemProperty -LiteralPath $runOnce -Name 'HuymaierConsoleRestoreGameBar' -Value $cmd -Type String -Force
        Write-Log 'Windows controller-to-Xbox-Game-Bar capture was disabled while Huymaier Console is running.'
    }catch{Write-Log "Xbox Game Bar controller suppression failed: $($_.Exception.Message)" 'WARN'}
}

function Initialize-HcSystemGuideReflection {
    if($null -ne $script:HcSystemGuideMethod){return}
    try{
        $nativeVariable=Get-Variable -Name HuymaierNativeBridge -ErrorAction SilentlyContinue
        if($null -eq $nativeVariable -or $null -eq $nativeVariable.Value){return}
        $assembly=$nativeVariable.Value.GetType().Assembly
        $type=$assembly.GetType('HuymaierConsole.NativeApp.HuymaierSystemButtonBridge',$false)
        if($null -eq $type){return}
        $flags=[Reflection.BindingFlags]::Static -bor [Reflection.BindingFlags]::NonPublic
        $method=$type.GetMethod('ConsumeGuidePress',$flags)
        if($null -ne $method){$script:HcSystemGuideType=$type;$script:HcSystemGuideMethod=$method}
    }catch{}
}

function Get-HcGameInputGuideEdge {
    try{
        Initialize-HcSystemGuideReflection
        if($null -eq $script:HcSystemGuideMethod){return $false}
        return [bool]$script:HcSystemGuideMethod.Invoke($null,$null)
    }catch{return $false}
}

function Get-HcRawSystemGuidePressed {
    try{
        $controllers=Convert-ToStableArray ([Windows.Gaming.Input.RawGameController,Windows.Gaming.Input,ContentType=WindowsRuntime]::RawGameControllers)
        foreach($raw in $controllers){
            if($null -eq $raw){continue}
            $name='';try{$name=[string]$raw.DisplayName}catch{}
            if(Test-IsMouseLikeControllerName $name){continue}
            $buttonCount=[int]$raw.ButtonCount
            if($buttonCount -le 0 -or $buttonCount -gt 256){continue}
            $switchCount=[int]$raw.SwitchCount;$axisCount=[int]$raw.AxisCount
            $buttons=New-Object 'System.Boolean[]' $buttonCount
            $switchType=[Windows.Gaming.Input.GameControllerSwitchPosition,Windows.Gaming.Input,ContentType=WindowsRuntime]
            $switches=[Array]::CreateInstance($switchType,[math]::Max(0,$switchCount))
            $axes=New-Object 'System.Double[]' ([math]::Max(0,$axisCount))
            [void]$raw.GetCurrentReading($buttons,$switches,$axes)
            for($i=0;$i -lt $buttonCount;$i++){
                if(-not $buttons[$i]){continue}
                $label='';try{$label=[string]$raw.GetButtonLabel([int]$i)}catch{}
                if($label -match '^(XboxGuide|Guide|Home|PS)$'){return $true}
            }
        }
    }catch{}
    return $false
}

function Get-HcActiveConsoleWindow {
    try{
        foreach($window in @([System.Windows.Application]::Current.Windows)){
            if($null -ne $window -and [bool]$window.IsActive){return $window}
        }
    }catch{}
    return $null
}

function Invoke-HcInternalGuide {
    param($ActiveWindow)
    try{
        # Guide escapes one native/modal layer, matching the established console
        # navigation model, then opens/focuses Huymaier Quick Access. It never
        # substitutes for the local Menu/Start command.
        if($null -ne $ActiveWindow -and $null -ne $script:Window -and -not [object]::ReferenceEquals($ActiveWindow,$script:Window)){
            try{$ActiveWindow.Close()}catch{}
            try{
                $null=$script:Window.Dispatcher.BeginInvoke([Action]{
                    try{if(Get-Command Show-HcMainMenu -ErrorAction SilentlyContinue){Show-HcMainMenu}else{Focus-TopNavigation}}catch{}
                })
            }catch{}
            return
        }
        if(Get-Command Show-HcMainMenu -ErrorAction SilentlyContinue){Show-HcMainMenu}else{Focus-TopNavigation}
    }catch{Write-Log "Global Guide to Quick Access recovered: $($_.Exception.Message)" 'WARN'}
}

function Initialize-HuymaierGameBar {
    try{
        if(-not('HuymaierConsole.NativeApp.HuymaierGameBarHost' -as [type])){
            Write-Log 'Native Huymaier Game Bar host is unavailable.' 'WARN'
            return
        }
        [HuymaierConsole.NativeApp.HuymaierGameBarHost]::Initialize($script:Window)
        [HuymaierConsole.NativeApp.HuymaierGameBarHost]::SetScalePercent([int](Get-EntryProperty $script:Config 'GameBarScale' 100))
        Initialize-HcSystemGuideReflection
        Set-HcXboxGameBarSuppression
        if($null -ne $script:HcGameBarTimer){try{$script:HcGameBarTimer.Stop()}catch{}}

        $timer=New-Object System.Windows.Threading.DispatcherTimer
        $timer.Interval=[TimeSpan]::FromMilliseconds(24)
        $timer.Add_Tick({
            try{
                if($null -eq $script:Window){return}

                # Consume only the dedicated system Guide edge here. D-pad/A/B/
                # shoulders remain with the currently active local input router.
                $gameInputGuideEdge=Get-HcGameInputGuideEdge
                $rawGuide=Get-HcRawSystemGuidePressed
                $rawGuideEdge=($rawGuide -and -not $script:HcExternalGuideDown)
                $script:HcExternalGuideDown=$rawGuide
                $guideEdge=$gameInputGuideEdge -or $rawGuideEdge

                $activeInternal=Get-HcActiveConsoleWindow
                if($null -ne $activeInternal){
                    if($guideEdge){Invoke-HcInternalGuide -ActiveWindow $activeInternal}
                    return
                }

                # No Huymaier window owns foreground focus: the external Game
                # Bar may consume normal navigation through the shared router.
                $command=''
                try{
                    if('HuymaierConsole.NativeApp.NativeConsoleNavigation' -as [type]){
                        $native=[HuymaierConsole.NativeApp.NativeConsoleNavigation]::Poll()
                        $command=[string]$native.Command
                    }
                }catch{}

                $visible=[HuymaierConsole.NativeApp.HuymaierGameBarHost]::IsVisible
                if($visible){
                    if($guideEdge){[HuymaierConsole.NativeApp.HuymaierGameBarHost]::ProcessCommand('Guide')}
                    elseif($command){[HuymaierConsole.NativeApp.HuymaierGameBarHost]::ProcessCommand($command)}
                    return
                }
                if($guideEdge -or $command -eq 'Guide'){
                    [HuymaierConsole.NativeApp.HuymaierGameBarHost]::Show()
                    Write-Log 'Huymaier Game Bar opened over the foreground game/app.'
                }
            }catch{Write-Log "Huymaier Game Bar/global Guide watcher recovered: $($_.Exception.Message)" 'WARN'}
        })
        $timer.Start()
        $script:HcGameBarTimer=$timer
        Write-Log 'Huymaier Game Bar and process-wide Guide watcher started.'
    }catch{Write-Log "Huymaier Game Bar initialization failed: $($_.Exception.Message)" 'ERROR'}
}

function Stop-HuymaierGameBar {
    try{if($null -ne $script:HcGameBarTimer){$script:HcGameBarTimer.Stop()}}catch{}
    $script:HcGameBarTimer=$null
    try{if('HuymaierConsole.NativeApp.HuymaierGameBarHost' -as [type]){[HuymaierConsole.NativeApp.HuymaierGameBarHost]::Hide()}}catch{}
    Restore-HcXboxGameBarSuppression
}
