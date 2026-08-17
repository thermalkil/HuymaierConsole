param()
Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'

$root=Split-Path -Parent $PSScriptRoot
$corePath=Join-Path $root 'HuymaierConsole.ps1'
$customPath=Join-Path $root 'HuymaierCustomization.ps1'
$shellPath=Join-Path $root 'HuymaierShellRedesign.ps1'
$cursorPath=Join-Path $root 'HuymaierUnifiedCursor.ps1'
foreach($path in @($corePath,$customPath,$shellPath,$cursorPath)){if(-not(Test-Path -LiteralPath $path -PathType Leaf)){throw "Required v0.30.8 background-task source missing: $path"}}
$utf8Bom=New-Object Text.UTF8Encoding($true)

# ---------------------------------------------------------------------------
# Core XAML/runtime hook: render a persistent non-interactive task HUD directly
# below the clock and feed it from the existing FileSystemWatcher dirtiness map.
# The HUD never polls JSON files itself.
# ---------------------------------------------------------------------------
$core=[IO.File]::ReadAllText($corePath,[Text.Encoding]::UTF8).Replace("`r`n","`n")
if($core -notmatch 'HUYMAIER_V0308_BACKGROUND_TASK_HUD_V1'){
    $headerAnchor=@'
            <Grid Grid.Row="0">
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="Auto"/>
                </Grid.ColumnDefinitions>
'@
    $headerReplacement=@'
            <!-- HUYMAIER_V0308_BACKGROUND_TASK_HUD_V1 -->
            <Grid Grid.Row="0" Panel.ZIndex="1600">
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="Auto"/>
                </Grid.ColumnDefinitions>
'@
    if(-not $core.Contains($headerAnchor)){throw 'Background-task header XAML anchor missing.'}
    $core=$core.Replace($headerAnchor,$headerReplacement)

    $clockAnchor=@'
                <StackPanel Grid.Column="1" HorizontalAlignment="Right" VerticalAlignment="Center">
                    <TextBlock x:Name="ClockText" Text="--:--" FontSize="25" FontWeight="SemiBold" HorizontalAlignment="Right"/>
                    <TextBlock x:Name="ControllerText" Text="Keyboard / Mouse" FontSize="12" Foreground="#AAB8CC" HorizontalAlignment="Right"/>
                    <TextBlock x:Name="FpsText" Text="FPS --" Visibility="Collapsed" FontSize="12" FontWeight="SemiBold" Foreground="#E7C45E" HorizontalAlignment="Right" Margin="0,3,0,0"/>
                </StackPanel>
'@
    $clockReplacement=@'
                <StackPanel Grid.Column="1" HorizontalAlignment="Right" VerticalAlignment="Top">
                    <TextBlock x:Name="ClockText" Text="--:--" FontSize="25" FontWeight="SemiBold" HorizontalAlignment="Right"/>
                    <TextBlock x:Name="ControllerText" Text="Keyboard / Mouse" FontSize="12" Foreground="#AAB8CC" HorizontalAlignment="Right"/>
                    <TextBlock x:Name="FpsText" Text="FPS --" Visibility="Collapsed" FontSize="12" FontWeight="SemiBold" Foreground="#E7C45E" HorizontalAlignment="Right" Margin="0,3,0,0"/>
                    <Border x:Name="BackgroundTaskHud" Visibility="Collapsed" IsHitTestVisible="False" Width="410" HorizontalAlignment="Right" Margin="0,8,0,0" Padding="12,9" Background="#EE0A101A" BorderBrush="#506077" BorderThickness="1" CornerRadius="10" Panel.ZIndex="1700">
                        <StackPanel x:Name="BackgroundTaskPanel"/>
                    </Border>
                </StackPanel>
'@
    if(-not $core.Contains($clockAnchor)){throw 'Background-task clock XAML anchor missing.'}
    $core=$core.Replace($clockAnchor,$clockReplacement)

    $namesAnchor="'ClockText','ControllerText','FpsText','NavPanel'"
    $namesReplacement="'ClockText','ControllerText','FpsText','BackgroundTaskHud','BackgroundTaskPanel','NavPanel'"
    if(-not $core.Contains($namesAnchor)){throw 'Background-task named-control anchor missing.'}
    $core=$core.Replace($namesAnchor,$namesReplacement)

    $runtimeAnchor=@'
            Update-HcRuntimeStateEvents
            Invoke-HcIncrementalConsoleCountRefresh
'@
    $runtimeReplacement=@'
            Update-HcRuntimeStateEvents
            # Artwork progress is presentation state, not a library mutation. Consume
            # its watcher event independently so the HUD can update without polling.
            if(Test-HcRuntimePathDirty $script:ArtworkStatePath){
                try{$script:HcBackgroundArtworkState=Read-ArtworkState}catch{$script:HcBackgroundArtworkState=$null}
            }
            if(Get-Command Update-HcBackgroundTaskHud -ErrorAction SilentlyContinue){Update-HcBackgroundTaskHud}
            Invoke-HcIncrementalConsoleCountRefresh
'@
    if(-not $core.Contains($runtimeAnchor)){throw 'Background-task runtime watcher anchor missing.'}
    $core=$core.Replace($runtimeAnchor,$runtimeReplacement)
    [IO.File]::WriteAllText($corePath,$core.Replace("`n","`r`n"),$utf8Bom)
}

# ---------------------------------------------------------------------------
# Active shell refresh: never race a fresh library import against an artwork
# scan. The artwork pass begins only after Apply-LibraryResult consumes the new
# library snapshot.
# ---------------------------------------------------------------------------
$shell=[IO.File]::ReadAllText($shellPath,[Text.Encoding]::UTF8).Replace("`r`n","`n")
$oldRefresh="'^storefront-manage-refresh:(.+)$' {if(Get-Command Clear-HcGameDataCache -ErrorAction SilentlyContinue){Clear-HcGameDataCache};Start-LibraryScan;Start-OnlineArtworkScan -ResetCursor;Set-ConsoleNotice 'Library and missing artwork refresh started.' 'INFO';Render-Page;return}"
$newRefresh="'^storefront-manage-refresh:(.+)$' {Start-HcLibraryAndArtworkRefresh;return}"
if($shell.Contains($oldRefresh)){$shell=$shell.Replace($oldRefresh,$newRefresh);[IO.File]::WriteAllText($shellPath,$shell.Replace("`n","`r`n"),$utf8Bom)}
elseif(-not $shell.Contains($newRefresh)){throw 'Sequenced library/artwork refresh shell anchor missing.'}

# ---------------------------------------------------------------------------
# Final customization layer: common task descriptors/UI, cumulative artwork
# counters, sequenced refresh coordinator, and explicit API-key persistence.
# This is deliberately presentation/coordinator code; workers keep owning work.
# ---------------------------------------------------------------------------
$custom=[IO.File]::ReadAllText($customPath,[Text.Encoding]::UTF8).Replace("`r`n","`n")
if($custom -notmatch 'HUYMAIER_V0308_BACKGROUND_TASK_COORDINATOR_V1'){
    $insertAnchor="$script:HcColorPickerModulePath=Join-Path $script:BaseDir 'HuymaierColorPicker.ps1'"
    if(-not $custom.Contains($insertAnchor)){throw 'Background-task customization insertion anchor missing.'}
    $block=@'
# HUYMAIER_V0308_BACKGROUND_TASK_COORDINATOR_V1
# One top-right presentation path for background work. Existing workers remain
# authoritative and publish state; this layer only coordinates and renders it.
$script:HcArtworkRefreshAfterLibrary=$false
$script:HcArtworkTaskScanned=0
$script:HcArtworkTaskResolved=0
$script:HcArtworkTaskDownloaded=0
$script:HcArtworkTaskRemaining=-1
$script:HcArtworkTaskResultToken=''
$script:HcBackgroundArtworkState=$null
$script:HcBackgroundHudSignature=''
try{$script:HcBackgroundArtworkState=Read-ArtworkState}catch{}

function Get-HcBackgroundTaskUpdatedAt {
    param($State)
    if($null -eq $State){return [datetime]::MinValue}
    $raw=[string](Get-EntryProperty $State 'Updated' (Get-EntryProperty $State 'UpdatedAt' ''))
    if(-not $raw){return [datetime]::MinValue}
    try{return [datetime]::Parse($raw)}catch{return [datetime]::MinValue}
}
function Add-HcBackgroundTaskFromState {
    param([System.Collections.ArrayList]$List,[string]$Title,$State,[switch]$ShowTerminal)
    if($null -eq $State){return}
    $busy=[bool](Get-EntryProperty $State 'Busy' $false)
    $error=[string](Get-EntryProperty $State 'Error' '')
    $phase=[string](Get-EntryProperty $State 'Phase' '')
    $updated=Get-HcBackgroundTaskUpdatedAt $State
    $age=if($updated -eq [datetime]::MinValue){999999.0}else{((Get-Date)-$updated).TotalSeconds}
    $terminalPhase=$phase -in @('Complete','Completed','Failed','Error')
    $show=$busy -or ($error -and $age -le 20) -or ($ShowTerminal -and $terminalPhase -and $age -le 8)
    if(-not $show){return}
    $progress=[int](Get-EntryProperty $State 'Progress' -1)
    if(-not $busy -and -not $error -and $progress -lt 0){$progress=100}
    $message=[string](Get-EntryProperty $State 'Message' $(if($phase){$phase}else{$Title}))
    [void]$List.Add([pscustomobject]@{Title=$Title;Detail=$message;Busy=$busy;Error=$error;Progress=$progress;Updated=$updated})
}
function Get-HcBackgroundTasks {
    $tasks=New-Object System.Collections.ArrayList
    if($script:HcArtworkRefreshAfterLibrary){
        [void]$tasks.Add([pscustomobject]@{Title='Artwork refresh';Detail='Queued — waiting for the library scan to finish.';Busy=$true;Error='';Progress=-1;Updated=Get-Date})
    }
    $art=$script:HcBackgroundArtworkState
    if($null -ne $art){
        $busy=[bool](Get-EntryProperty $art 'Busy' $false)
        $error=[string](Get-EntryProperty $art 'Error' '')
        $updated=Get-HcBackgroundTaskUpdatedAt $art
        $age=if($updated -eq [datetime]::MinValue){999999.0}else{((Get-Date)-$updated).TotalSeconds}
        if($busy -or ($error -and $age -le 20) -or ((-not $busy) -and -not $error -and $age -le 8)){
            $progress=[int](Get-EntryProperty $art 'Progress' -1)
            $detail=[string](Get-EntryProperty $art 'Message' 'Artwork worker is running.')
            if(-not $busy -and -not $error -and $script:HcArtworkTaskScanned -gt 0){
                $remaining=$(if($script:HcArtworkTaskRemaining -ge 0){" · $($script:HcArtworkTaskRemaining) remaining"}else{''})
                $detail="Complete · $($script:HcArtworkTaskResolved) cover(s) resolved · $($script:HcArtworkTaskScanned) scanned$remaining"
                $progress=100
            }elseif($script:HcArtworkTaskScanned -gt 0){
                $detail += " · $($script:HcArtworkTaskResolved) resolved / $($script:HcArtworkTaskScanned) scanned"
            }
            if([string]::IsNullOrWhiteSpace([string](Get-EntryProperty $script:Config 'TheGamesDbApiKey' ''))){$detail += ' · TheGamesDB key not configured'}
            [void]$tasks.Add([pscustomobject]@{Title='Artwork refresh';Detail=$detail;Busy=$busy;Error=$error;Progress=$progress;Updated=$updated})
        }
    }
    Add-HcBackgroundTaskFromState $tasks 'Library scan' $script:LibraryState -ShowTerminal
    $providerTitle='Game provider'
    try{$providerName=[string](Get-EntryProperty $script:ProviderState 'Provider' '');if($providerName){$providerTitle+=' · '+$providerName}}catch{}
    Add-HcBackgroundTaskFromState $tasks $providerTitle $script:ProviderState -ShowTerminal
    $storeTitle='Storefront task'
    try{$storeName=[string](Get-EntryProperty $script:StorefrontState 'Store' (Get-EntryProperty $script:StorefrontState 'Provider' ''));if($storeName){$storeTitle+=' · '+$storeName}}catch{}
    Add-HcBackgroundTaskFromState $tasks $storeTitle $script:StorefrontState -ShowTerminal
    Add-HcBackgroundTaskFromState $tasks 'Windows Update' $script:UpdateState -ShowTerminal
    return [object[]]$tasks.ToArray()
}
function New-HcBackgroundTaskRow {
    param($Task)
    $wrap=New-Object System.Windows.Controls.StackPanel
    $wrap.Margin='0,0,0,7'
    $top=New-Object System.Windows.Controls.Grid
    $top.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition -Property @{Width='*'}))
    $top.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition -Property @{Width='Auto'}))
    $title=New-Object System.Windows.Controls.TextBlock;$title.Text=[string]$Task.Title;$title.FontSize=12;$title.FontWeight='Bold';$title.Foreground='#F5F7FB';$top.Children.Add($title)|Out-Null
    $pct=New-Object System.Windows.Controls.TextBlock;$pct.FontSize=11;$pct.Foreground='#E7C45E';$pct.Margin='10,0,0,0';$pct.HorizontalAlignment='Right';[System.Windows.Controls.Grid]::SetColumn($pct,1)
    if([string]$Task.Error){$pct.Text='FAILED'}elseif([int]$Task.Progress -ge 0){$pct.Text=([math]::Max(0,[math]::Min(100,[int]$Task.Progress))).ToString()+'%'}else{$pct.Text='WORKING'}
    $top.Children.Add($pct)|Out-Null;$wrap.Children.Add($top)|Out-Null
    $detail=New-Object System.Windows.Controls.TextBlock;$detail.Text=$(if([string]$Task.Error){[string]$Task.Error}else{[string]$Task.Detail});$detail.FontSize=11;$detail.Foreground=$(if([string]$Task.Error){'#FFB3B3'}else{'#AEBBD0'});$detail.TextWrapping='Wrap';$detail.MaxWidth=380;$detail.Margin='0,2,0,4';$wrap.Children.Add($detail)|Out-Null
    $bar=New-Object System.Windows.Controls.ProgressBar;$bar.Height=5;$bar.Minimum=0;$bar.Maximum=100;$bar.Background='#26354A';$bar.Foreground=$(if(Get-Command New-HcSolidBrush -ErrorAction SilentlyContinue){New-HcSolidBrush (Get-HcAccentColor)}else{'#E7C45E'});$bar.BorderThickness=0
    if([bool]$Task.Busy -and [int]$Task.Progress -lt 0){$bar.IsIndeterminate=$true}else{$bar.Value=[math]::Max(0,[math]::Min(100,[int]$Task.Progress))}
    $wrap.Children.Add($bar)|Out-Null
    return $wrap
}
function Update-HcBackgroundTaskHud {
    if($null -eq $script:BackgroundTaskHud -or $null -eq $script:BackgroundTaskPanel){return}
    $tasks=@(Get-HcBackgroundTasks)
    $signature=''
    try{$signature=($tasks|Select-Object Title,Detail,Busy,Error,Progress|ConvertTo-Json -Depth 4 -Compress)}catch{$signature=[string]$tasks.Count}
    if([string]::Equals($signature,$script:HcBackgroundHudSignature,[StringComparison]::Ordinal)){return}
    $script:HcBackgroundHudSignature=$signature
    $script:BackgroundTaskPanel.Children.Clear()
    if($tasks.Count -eq 0){$script:BackgroundTaskHud.Visibility='Collapsed';return}
    $heading=New-Object System.Windows.Controls.TextBlock;$heading.Text='BACKGROUND TASKS';$heading.FontSize=10;$heading.FontWeight='Bold';$heading.Foreground='#8798B1';$heading.Margin='0,0,0,6';$script:BackgroundTaskPanel.Children.Add($heading)|Out-Null
    $limit=[math]::Min(3,$tasks.Count)
    for($i=0;$i -lt $limit;$i++){$script:BackgroundTaskPanel.Children.Add((New-HcBackgroundTaskRow $tasks[$i]))|Out-Null}
    if($tasks.Count -gt $limit){$more=New-Object System.Windows.Controls.TextBlock;$more.Text=('+'+($tasks.Count-$limit)+' more background task(s)');$more.FontSize=10;$more.Foreground='#8798B1';$script:BackgroundTaskPanel.Children.Add($more)|Out-Null}
    $script:BackgroundTaskHud.Visibility='Visible'
}

$script:HcV0308TasksBaseStartArtwork=${function:Start-OnlineArtworkScan}
function Start-OnlineArtworkScan {
    param([switch]$ResetCursor,[switch]$Force,[string]$Platform='',[string]$GameId='',[string]$GameName='')
    if($ResetCursor){
        $script:HcArtworkTaskScanned=0;$script:HcArtworkTaskResolved=0;$script:HcArtworkTaskDownloaded=0;$script:HcArtworkTaskRemaining=-1;$script:HcArtworkTaskResultToken=''
    }
    & $script:HcV0308TasksBaseStartArtwork -ResetCursor:$ResetCursor -Force:$Force -Platform $Platform -GameId $GameId -GameName $GameName
}
$script:HcV0308TasksBaseApplyArtwork=${function:Apply-OnlineArtworkResult}
function Apply-OnlineArtworkResult {
    & $script:HcV0308TasksBaseApplyArtwork
    try{
        if(-not(Test-Path -LiteralPath $script:ArtworkResultPath -PathType Leaf)){return}
        $result=Get-Content -Raw -LiteralPath $script:ArtworkResultPath -Encoding UTF8|ConvertFrom-Json
        $token=[string](Get-EntryProperty $result 'Updated' '')
        if(-not $token){$token=(Get-Item -LiteralPath $script:ArtworkResultPath).LastWriteTimeUtc.Ticks.ToString()}
        if($token -eq $script:HcArtworkTaskResultToken){return}
        $script:HcArtworkTaskResultToken=$token
        $script:HcArtworkTaskScanned += [int](Get-EntryProperty $result 'Scanned' 0)
        $script:HcArtworkTaskResolved += @(Get-EntryProperty $result 'Items' @()).Count
        $script:HcArtworkTaskDownloaded += [int](Get-EntryProperty $result 'Downloaded' 0)
        $script:HcArtworkTaskRemaining=[int](Get-EntryProperty $result 'Remaining' -1)
        $script:HcBackgroundHudSignature=''
    }catch{Write-Log "Background-task artwork accounting recovered: $($_.Exception.Message)" 'WARN'}
}

function Start-HcLibraryAndArtworkRefresh {
    $script:HcArtworkRefreshAfterLibrary=$true
    try{if(Get-Command Clear-HcGameDataCache -ErrorAction SilentlyContinue){Clear-HcGameDataCache}}catch{}
    Start-LibraryScan
    Set-ConsoleNotice 'Library scan started. Missing artwork will begin automatically when the fresh library is ready.' 'INFO'
    Write-Log 'Sequenced library -> missing-artwork refresh requested.'
    $script:HcBackgroundHudSignature=''
    Render-Page
}
$script:HcV0308TasksBaseApplyLibrary=${function:Apply-LibraryResult}
function Apply-LibraryResult {
    & $script:HcV0308TasksBaseApplyLibrary
    if($script:HcArtworkRefreshAfterLibrary){
        $script:HcArtworkRefreshAfterLibrary=$false
        Start-OnlineArtworkScan -ResetCursor -Force
        Set-ConsoleNotice 'Library scan complete. Missing artwork scan started.' 'INFO'
        Write-Log 'Sequenced missing-artwork refresh started after library import.'
        $script:HcBackgroundHudSignature=''
    }
}

# The active Settings page uses the native keyboard for API keys. Handle both
# key modes here at the final customization layer so a displayed Configured state
# always corresponds to a value that was actually persisted to config.json.
$script:HcV0308TasksBaseCompleteKeyboard=${function:Complete-NativeKeyboardInput}
function Complete-NativeKeyboardInput {
    param([string]$Mode,[string]$Value,$Context)
    if($Mode -in @('TheGamesDbApiKey','SteamGridDbApiKey')){
        $key=([string]$Value).Trim()
        if($null -eq $script:Config.PSObject.Properties[$Mode]){$script:Config|Add-Member -NotePropertyName $Mode -NotePropertyValue $key -Force}else{$script:Config.$Mode=$key}
        Save-Config
        $label=$(if($Mode -eq 'TheGamesDbApiKey'){'TheGamesDB'}else{'SteamGridDB'})
        Set-ConsoleNotice $(if($key){"$label API key saved."}else{"$label API key cleared."}) 'INFO'
        Render-Page
        return
    }
    & $script:HcV0308TasksBaseCompleteKeyboard $Mode $Value $Context
}

# Route the live Paul's PC missing-art button through the sequenced coordinator.
$script:HcV0308TasksBaseInvokeAction=${function:Invoke-Action}
function Invoke-Action {
    param([string]$Id)
    if([string]::Equals($Id,'artwork-refresh',[StringComparison]::OrdinalIgnoreCase)){Start-HcLibraryAndArtworkRefresh;return}
    & $script:HcV0308TasksBaseInvokeAction $Id
}

'@
    $custom=$custom.Replace($insertAnchor,$block+$insertAnchor)
    [IO.File]::WriteAllText($customPath,$custom.Replace("`n","`r`n"),$utf8Bom)
}

# ---------------------------------------------------------------------------
# Diagnostic cleanup exposed by the user's RC4 log: File.Replace was being
# called with a null backup path on .NET Framework and flooded the log. Keep an
# atomic replacement with a real sibling backup and a Move-Item fallback.
# ---------------------------------------------------------------------------
$cursor=[IO.File]::ReadAllText($cursorPath,[Text.Encoding]::UTF8).Replace("`r`n","`n")
$badReplace='            [IO.File]::Replace($tmp,$script:HcUnifiedCursorStatePath,$null,$true)'
if($cursor.Contains($badReplace)){
    $safeReplace=@'
            # HUYMAIER_V0308_CURSOR_STATE_REPLACE_V1
            $backup=$script:HcUnifiedCursorStatePath+'.bak'
            try{
                [IO.File]::Replace($tmp,$script:HcUnifiedCursorStatePath,$backup,$true)
                Remove-Item -LiteralPath $backup -Force -ErrorAction SilentlyContinue
            }catch{
                Move-Item -LiteralPath $tmp -Destination $script:HcUnifiedCursorStatePath -Force
            }
'@
    $cursor=$cursor.Replace($badReplace,$safeReplace.TrimEnd("`r","`n"))
    [IO.File]::WriteAllText($cursorPath,$cursor.Replace("`n","`r`n"),$utf8Bom)
}elseif($cursor -notmatch 'HUYMAIER_V0308_CURSOR_STATE_REPLACE_V1'){throw 'Cursor-state replacement anchor missing.'}

Write-Host 'v0.30.8 background-task HUD, sequenced artwork refresh, API-key persistence, and cursor-state diagnostic cleanup applied.'