# Downloads-page overrides for concurrent direct-provider transfers.
# Loaded after HuymaierShellRedesign.ps1 so the multi-card renderer owns the
# final Downloads surface while reusing its completion-history helpers.

Set-StrictMode -Version 2.0
$script:HcBaseEtaText=${function:Get-HcEtaText}
$script:HcActiveDownloadVisuals=@{}

function Get-HcEtaText {
    param($State)
    if($null -ne $State -and (Get-Command Get-HcProviderTransferEtaText -ErrorAction SilentlyContinue)){
        $transferId=[string](Get-EntryProperty $State 'TransferId' '')
        $provider=[string](Get-EntryProperty $State 'Provider' '')
        if($transferId -or $provider -in @('Epic','GOG','Amazon')){return Get-HcProviderTransferEtaText $State}
    }
    return (& $script:HcBaseEtaText $State)
}

function Get-HcActiveDownloadStates {
    $items=New-Object System.Collections.ArrayList
    if(Get-Command Get-GameProviderActiveTransfers -ErrorAction SilentlyContinue){foreach($state in @(Get-GameProviderActiveTransfers)){if($null -ne $state){[void]$items.Add($state)}}}
    if($null -ne $script:StorefrontState -and [bool](Get-EntryProperty $script:StorefrontState 'Busy' $false) -and [string]::Equals([string](Get-EntryProperty $script:StorefrontState 'Mode' ''),'Install',[StringComparison]::OrdinalIgnoreCase)){
        if($null -eq $script:StorefrontState.PSObject.Properties['TransferId']){$script:StorefrontState|Add-Member -NotePropertyName TransferId -NotePropertyValue 'storefront' -Force}
        [void]$items.Add($script:StorefrontState)
    }
    return [object[]]$items.ToArray()
}
function Get-HcDownloadVisualKey {
    param($State)
    $id=[string](Get-EntryProperty $State 'TransferId' '')
    if($id){return $id}
    return (([string](Get-EntryProperty $State 'Provider' (Get-EntryProperty $State 'StoreId' 'download')))+'|'+([string](Get-EntryProperty $State 'GameId' (Get-EntryProperty $State 'Name' 'item')))).ToLowerInvariant()
}
function Get-HcDownloadStateNumbers {
    param($State)
    $phase=[string](Get-EntryProperty $State 'Phase' (Get-EntryProperty $State 'Status' 'Downloading'))
    $installing=[string]::Equals($phase,'Installing',[StringComparison]::OrdinalIgnoreCase)
    $current=if($installing){[int64](Get-EntryProperty $State 'InstallProcessedBytes' (Get-EntryProperty $State 'DownloadedBytes' 0))}else{[int64](Get-EntryProperty $State 'DownloadedBytes' 0)}
    $total=if($installing){[int64](Get-EntryProperty $State 'InstallSizeBytes' (Get-EntryProperty $State 'TotalBytes' 0))}else{[int64](Get-EntryProperty $State 'TotalBytes' 0)}
    $rate=if($installing){[double](Get-EntryProperty $State 'InstallSpeedBytesPerSec' (Get-EntryProperty $State 'TransferSpeedBytesPerSec' (Get-EntryProperty $State 'DownloadSpeedBytesPerSec' 0)))}else{[double](Get-EntryProperty $State 'DownloadSpeedBytesPerSec' (Get-EntryProperty $State 'TransferSpeedBytesPerSec' 0))}
    $progress=[int](Get-EntryProperty $State 'Progress' -1)
    if($progress -lt 0 -and $total -gt 0){$progress=[int][math]::Min(99,[math]::Round(($current/[double]$total)*100))}
    return [pscustomobject]@{Phase=$phase;Current=$current;Total=$total;Rate=$rate;Progress=$progress}
}
function Set-HcDownloadCardValues {
    param($Controls,$State)
    if($null -eq $Controls -or $null -eq $State){return}
    $numbers=Get-HcDownloadStateNumbers $State
    $name=[string](Get-EntryProperty $State 'GameName' (Get-EntryProperty $State 'Name' (Get-EntryProperty $State 'Provider' 'Active download')))
    $provider=[string](Get-EntryProperty $State 'Provider' (Get-EntryProperty $State 'StoreId' ''))
    $eta=Get-HcEtaText $State
    $Controls.Title.Text=$name
    $Controls.Phase.Text=$(if($provider){$provider+'  •  '+$numbers.Phase+'  •  '+$eta}else{$numbers.Phase+'  •  '+$eta})
    $Controls.Progress.Value=[math]::Max(0,[math]::Min(100,$numbers.Progress))
    $amount=if($numbers.Total -gt 0){"$(Format-HcTransferBytes $numbers.Current) of $(Format-HcTransferBytes $numbers.Total)"}elseif($numbers.Current -gt 0){Format-HcTransferBytes $numbers.Current}else{'Measuring activity…'}
    $rateText=Format-HcTransferRate $numbers.Rate
    $pieces=New-Object System.Collections.ArrayList;if($numbers.Progress -ge 0){[void]$pieces.Add(("$($numbers.Progress)%"))};if($amount){[void]$pieces.Add($amount)};if($rateText){[void]$pieces.Add($rateText)}
    $Controls.Stats.Text=($pieces -join '  •  ')
    $source=[string](Get-EntryProperty $State 'TelemetrySource' '')
    $message=[string](Get-EntryProperty $State 'Message' '')
    if([bool](Get-EntryProperty $State 'EtaEstimated' $false) -and $source){$message=$message+$(if($message){'  •  '}else{''})+$source}
    $Controls.Message.Text=$message
}
function Add-HcActiveDownloadCard {
    param($State)
    $key=Get-HcDownloadVisualKey $State
    $border=New-Object System.Windows.Controls.Border;$border.Background='#B5101928';$border.BorderBrush='#445977';$border.BorderThickness='1';$border.CornerRadius=18;$border.Padding='22';$border.Margin='0,0,0,16'
    $stack=New-Object System.Windows.Controls.StackPanel
    $title=New-Object System.Windows.Controls.TextBlock;$title.FontSize=24;$title.FontWeight='Bold';$title.Foreground='White';$stack.Children.Add($title)|Out-Null
    $phase=New-Object System.Windows.Controls.TextBlock;$phase.FontSize=13;$phase.Foreground='#AEBBD0';$phase.Margin='0,6,0,12';$stack.Children.Add($phase)|Out-Null
    $bar=New-Object System.Windows.Controls.ProgressBar;$bar.Minimum=0;$bar.Maximum=100;$bar.Height=18;$stack.Children.Add($bar)|Out-Null
    $stats=New-Object System.Windows.Controls.TextBlock;$stats.FontSize=14;$stats.FontWeight='SemiBold';$stats.Foreground='#D7E1EF';$stats.Margin='0,10,0,0';$stack.Children.Add($stats)|Out-Null
    $message=New-Object System.Windows.Controls.TextBlock;$message.FontSize=12;$message.Foreground='#91A3BA';$message.Margin='0,6,0,0';$message.TextWrapping='Wrap';$stack.Children.Add($message)|Out-Null
    $controls=[pscustomobject]@{Title=$title;Phase=$phase;Progress=$bar;Stats=$stats;Message=$message}
    $script:HcActiveDownloadVisuals[$key]=$controls
    Set-HcDownloadCardValues $controls $State
    $border.Child=$stack;$script:ActionPanel.Children.Add($border)|Out-Null
}
function Update-HcActiveDownloadVisuals {
    param($Active)
    if($null -eq $script:HcActiveDownloadVisuals){return $false}
    $states=@(Get-HcActiveDownloadStates)
    if($states.Count -ne $script:HcActiveDownloadVisuals.Count){return $false}
    foreach($state in $states){$key=Get-HcDownloadVisualKey $state;if(-not $script:HcActiveDownloadVisuals.ContainsKey($key)){return $false};Set-HcDownloadCardValues $script:HcActiveDownloadVisuals[$key] $state}
    return $true
}

function Update-HcDownloadHistory {
    $states=New-Object System.Collections.ArrayList
    if(Get-Command Get-GameProviderTransfers -ErrorAction SilentlyContinue){foreach($state in @(Get-GameProviderTransfers)){if($null -ne $state){[void]$states.Add($state)}}}
    if($null -ne $script:StorefrontState){[void]$states.Add($script:StorefrontState)}
    foreach($state in @($states.ToArray())){
        if($null -eq $state -or [bool](Get-EntryProperty $state 'Busy' $false)){continue}
        if(-not [string]::Equals([string](Get-EntryProperty $state 'Mode' ''),'Install',[StringComparison]::OrdinalIgnoreCase)){continue}
        $progress=[int](Get-EntryProperty $state 'Progress' -1);if($progress -lt 100){continue}
        $status=[string](Get-EntryProperty $state 'Phase' (Get-EntryProperty $state 'Status' ''));if(-not [string]::Equals($status,'Complete',[StringComparison]::OrdinalIgnoreCase)){continue}
        if([string](Get-EntryProperty $state 'Error' '')){continue}
        $completed=[string](Get-EntryProperty $state 'Updated' (Get-EntryProperty $state 'UpdatedAt' ''));if(-not $completed){continue}
        $started=[string](Get-EntryProperty $state 'StartedAt' '')
        $provider=[string](Get-EntryProperty $state 'Provider' (Get-EntryProperty $state 'StoreId' (Get-EntryProperty $state 'Name' 'Storefront')))
        $name=[string](Get-EntryProperty $state 'GameName' (Get-EntryProperty $state 'Name' ''));if(-not $name){continue}
        $gameId=[string](Get-EntryProperty $state 'GameId' '');$transferId=[string](Get-EntryProperty $state 'TransferId' '')
        $eventKey=if($transferId){($provider+'|install|'+$gameId+'|'+$transferId).ToLowerInvariant()}else{($provider+'|install|'+$gameId+'|'+$name+'|'+$started).ToLowerInvariant()}
        Add-HcDownloadCompletion $name $provider $started $completed $eventKey
    }
    Prune-HcDownloadHistory
}

function Render-HcDownloadsRoot {
    Read-StorefrontState;if(Get-Command Read-GameProviderState -ErrorAction SilentlyContinue){Read-GameProviderState|Out-Null};Update-HcDownloadHistory
    $script:HcActiveDownloadVisuals=@{}
    $heading=New-Object System.Windows.Controls.TextBlock;$heading.Text='Downloads';$heading.FontSize=30;$heading.FontWeight='Bold';$heading.Foreground='White';$heading.Margin='0,0,0,18';$script:ActionPanel.Children.Add($heading)|Out-Null
    $active=@(Get-HcActiveDownloadStates)
    if($active.Count -gt 0){
        $summary=New-Object System.Windows.Controls.TextBlock;$summary.Text=$(if($active.Count -eq 1){'1 active download / installation'}else{"$($active.Count) active downloads / installations"});$summary.FontSize=14;$summary.FontWeight='SemiBold';$summary.Foreground='#E7C45E';$summary.Margin='0,0,0,12';$script:ActionPanel.Children.Add($summary)|Out-Null
        foreach($state in $active){Add-HcActiveDownloadCard $state}
    }else{$idle=New-Object System.Windows.Controls.TextBlock;$idle.Text='No active downloads or installations.';$idle.FontSize=16;$idle.Foreground='#9DAFC5';$idle.Margin='0,0,0,24';$script:ActionPanel.Children.Add($idle)|Out-Null}

    $rh=New-Object System.Windows.Controls.TextBlock;$rh.Text='Recently Downloaded & Installed';$rh.FontSize=22;$rh.FontWeight='SemiBold';$rh.Foreground='White';$rh.Margin='0,12,0,10';$script:ActionPanel.Children.Add($rh)|Out-Null
    if(@($script:HcDownloadHistory).Count -eq 0){$empty=New-Object System.Windows.Controls.TextBlock;$empty.Text='Completed downloads from the last 7 days will appear here.';$empty.FontSize=13;$empty.Foreground='#91A3BA';$empty.Margin='0,3,0,0';$script:ActionPanel.Children.Add($empty)|Out-Null}
    foreach($record in @($script:HcDownloadHistory|Select-Object -First 20)){
        $b=New-Object System.Windows.Controls.Border;$b.Background='#76101927';$b.CornerRadius=12;$b.Padding='15,11';$b.Margin='0,0,0,8';$stack=New-Object System.Windows.Controls.StackPanel
        $n=New-Object System.Windows.Controls.TextBlock;$n.Text=[string](Get-EntryProperty $record 'Name' 'Download');$n.FontSize=16;$n.FontWeight='SemiBold';$n.Foreground='White';$stack.Children.Add($n)|Out-Null
        $provider=[string](Get-EntryProperty $record 'Provider' '');$completed=[string](Get-EntryProperty $record 'CompletedAt' '');$displayTime=$completed;try{$displayTime=([datetime]::Parse($completed)).ToString('ddd MMM d, h:mm tt')}catch{}
        $d=New-Object System.Windows.Controls.TextBlock;$d.Text=$(if($provider){$provider+'  •  Installed  •  '+$displayTime}else{'Installed  •  '+$displayTime});$d.FontSize=11;$d.Foreground='#91A3BA';$stack.Children.Add($d)|Out-Null;$b.Child=$stack;$script:ActionPanel.Children.Add($b)|Out-Null
    }
}
