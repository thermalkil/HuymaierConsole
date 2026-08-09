# Huymaier Console v0.26.0 external game/app overlay.
# Quick Access remains inside Huymaier Console. This module owns only the
# external-app Game Bar and its Guide-button watcher.

$script:HcGameBarTimer=$null
$script:HcExternalGuideDown=$false
$script:HcGameBarBackupPath=Join-Path $script:DataDir 'xbox-gamebar-backup.json'

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

function Set-HcXboxGameBarSuppression {
    try{
        $entries=@(
            [pscustomobject]@{Path='HKCU:\Software\Microsoft\GameBar';Name='UseNexusForGameBarEnabled';Value=0},
            [pscustomobject]@{Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR';Name='VKMToggleGameBar';Value=0},
            [pscustomobject]@{Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR';Name='AppCaptureEnabled';Value=0},
            [pscustomobject]@{Path='HKCU:\System\GameConfigStore';Name='GameDVR_Enabled';Value=0}
        )
        if(-not(Test-Path -LiteralPath $script:HcGameBarBackupPath -PathType Leaf)){
            $backup=New-Object System.Collections.ArrayList
            foreach($entry in $entries){[void]$backup.Add((Get-HcRegistryBackupValue $entry.Path $entry.Name))}
            $backup|ConvertTo-Json -Depth 5|Set-Content -LiteralPath $script:HcGameBarBackupPath -Encoding UTF8
        }
        foreach($entry in $entries){
            if(-not(Test-Path -LiteralPath $entry.Path)){New-Item -Path $entry.Path -Force|Out-Null}
            Set-ItemProperty -LiteralPath $entry.Path -Name $entry.Name -Value ([int]$entry.Value) -Type DWord -Force
        }
        Write-Log 'Windows Xbox Game Bar controller/shortcut capture was disabled for the Huymaier Game Bar replacement.'
    }catch{Write-Log "Xbox Game Bar suppression failed: $($_.Exception.Message)" 'WARN'}
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

function Initialize-HuymaierGameBar {
    try{
        if(-not('HuymaierConsole.NativeApp.HuymaierGameBarHost' -as [type])){
            Write-Log 'Native Huymaier Game Bar host is unavailable.' 'WARN'
            return
        }
        [HuymaierConsole.NativeApp.HuymaierGameBarHost]::Initialize($script:Window)
        Set-HcXboxGameBarSuppression
        if($null -ne $script:HcGameBarTimer){try{$script:HcGameBarTimer.Stop()}catch{}}
        $timer=New-Object System.Windows.Threading.DispatcherTimer
        $timer.Interval=[TimeSpan]::FromMilliseconds(24)
        $timer.Add_Tick({
            try{
                if($null -eq $script:Window){return}
                if([bool]$script:Window.IsActive){
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
}
