# Huymaier Console v0.26.1 external game/app overlay.
# Quick Access remains inside Huymaier Console. This module owns only the
# external-app Game Bar and its Guide-button watcher.

$script:HcGameBarTimer=$null
$script:HcExternalGuideDown=$false
$script:HcGameBarBackupPath=Join-Path $script:DataDir 'xbox-gamebar-backup.json'
$script:HcWindowsRestorePath=Join-Path $script:BaseDir 'Restore-HuymaierWindowsSettings.ps1'

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
        # First recover a setting left suppressed by an abnormal prior exit.
        Restore-HcXboxGameBarSuppression
        $path='HKCU:\Software\Microsoft\GameBar'
        $name='UseNexusForGameBarEnabled'
        $backup=Get-HcRegistryBackupValue $path $name
        $backup|ConvertTo-Json -Depth 4|Set-Content -LiteralPath $script:HcGameBarBackupPath -Encoding UTF8
        if(-not(Test-Path -LiteralPath $path)){New-Item -Path $path -Force|Out-Null}
        Set-ItemProperty -LiteralPath $path -Name $name -Value 0 -Type DWord -Force

        # Crash/reboot recovery. Normal shutdown removes this entry after
        # restoring the original setting; if the process dies, Windows runs the
        # helper at the next sign-in.
        $runOnce='HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce'
        if(-not(Test-Path -LiteralPath $runOnce)){New-Item -Path $runOnce -Force|Out-Null}
        $cmd='powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "'+$script:HcWindowsRestorePath+'" -Quiet'
        Set-ItemProperty -LiteralPath $runOnce -Name 'HuymaierConsoleRestoreGameBar' -Value $cmd -Type String -Force
        Write-Log 'Windows controller-to-Xbox-Game-Bar capture was disabled while Huymaier Console is running.'
    }catch{Write-Log "Xbox Game Bar controller suppression failed: $($_.Exception.Message)" 'WARN'}
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

function Test-HcAnyConsoleWindowActive {
    try{
        foreach($window in @([System.Windows.Application]::Current.Windows)){
            if($null -ne $window -and [bool]$window.IsActive){return $true}
        }
    }catch{}
    return $false
}

function Initialize-HuymaierGameBar {
    try{
        if(-not('HuymaierConsole.NativeApp.HuymaierGameBarHost' -as [type])){
            Write-Log 'Native Huymaier Game Bar host is unavailable.' 'WARN'
            return
        }
        [HuymaierConsole.NativeApp.HuymaierGameBarHost]::Initialize($script:Window)
        [HuymaierConsole.NativeApp.HuymaierGameBarHost]::SetScalePercent([int](Get-EntryProperty $script:Config 'GameBarScale' 100))
        Set-HcXboxGameBarSuppression
        if($null -ne $script:HcGameBarTimer){try{$script:HcGameBarTimer.Stop()}catch{}}
        $timer=New-Object System.Windows.Threading.DispatcherTimer
        $timer.Interval=[TimeSpan]::FromMilliseconds(24)
        $timer.Add_Tick({
            try{
                if($null -eq $script:Window){return}

                # Any active Huymaier WPF surface is internal. This prevents the
                # external watcher from consuming Guide while a native PS/Xbox-
                # style child interface owns foreground focus.
                if(Test-HcAnyConsoleWindowActive){
                    $script:HcExternalGuideDown=$false
                    return
                }

                $command=''
                try{
                    if('HuymaierConsole.NativeApp.NativeConsoleNavigation' -as [type]){
                        $native=[HuymaierConsole.NativeApp.NativeConsoleNavigation]::Poll()
                        $command=[string]$native.Command
                    }
                }catch{}
                $rawGuide=Get-HcRawSystemGuidePressed
                $rawGuideEdge=($rawGuide -and -not $script:HcExternalGuideDown)
                $script:HcExternalGuideDown=$rawGuide

                $visible=[HuymaierConsole.NativeApp.HuymaierGameBarHost]::IsVisible
                if($visible){
                    if($command){[HuymaierConsole.NativeApp.HuymaierGameBarHost]::ProcessCommand($command)}
                    elseif($rawGuideEdge){[HuymaierConsole.NativeApp.HuymaierGameBarHost]::ProcessCommand('Guide')}
                    return
                }
                if($command -eq 'Guide' -or $rawGuideEdge){
                    [HuymaierConsole.NativeApp.HuymaierGameBarHost]::Show()
                    Write-Log 'Huymaier Game Bar opened over the foreground game/app.'
                }
            }catch{Write-Log "Huymaier Game Bar input watcher recovered: $($_.Exception.Message)" 'WARN'}
        })
        $timer.Start()
        $script:HcGameBarTimer=$timer
        Write-Log 'Huymaier Game Bar external Guide-button watcher started.'
    }catch{Write-Log "Huymaier Game Bar initialization failed: $($_.Exception.Message)" 'ERROR'}
}

function Stop-HuymaierGameBar {
    try{if($null -ne $script:HcGameBarTimer){$script:HcGameBarTimer.Stop()}}catch{}
    $script:HcGameBarTimer=$null
    try{if('HuymaierConsole.NativeApp.HuymaierGameBarHost' -as [type]){[HuymaierConsole.NativeApp.HuymaierGameBarHost]::Hide()}}catch{}
    Restore-HcXboxGameBarSuppression
}
