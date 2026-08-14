param(
    [Parameter(Mandatory=$true)][string]$ConsolePath
)

Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
if(-not(Test-Path -LiteralPath $ConsolePath -PathType Leaf)){throw "Console source missing: $ConsolePath"}
$text=Get-Content -Raw -LiteralPath $ConsolePath -Encoding UTF8
if($text -match 'HUYMAIER_RUNTIME_HITCH_GUARD_V1'){return}

# Platform cards must be cache-only. Starting ten PowerShell summary workers
# while Render-Page builds the platform rail causes visible return/navigation
# hitches. Background count refresh is staggered below instead.
$start=$text.IndexOf('function Get-PlatformCountSummary {',[StringComparison]::Ordinal)
$end=$text.IndexOf('function New-PlatformCard {',[StringComparison]::Ordinal)
if($start -lt 0 -or $end -le $start){throw 'Runtime hitch transform could not isolate Get-PlatformCountSummary.'}
$segment=$text.Substring($start,$end-$start)
$segment=$segment.Replace('        Start-Ps1LibrarySummaryScan'+"`r`n",'        # Count refresh is scheduled outside Render-Page.'+"`r`n")
$segment=$segment.Replace('        Start-Ps2LibrarySummaryScan'+"`r`n",'        # Count refresh is scheduled outside Render-Page.'+"`r`n")
$segment=$segment.Replace('        Start-Ps3LibrarySummaryScan'+"`r`n",'        # Count refresh is scheduled outside Render-Page.'+"`r`n")
$segment=$segment.Replace('                    Start-NativeConsoleLibrarySummaryScan $id'+"`r`n",'                    # Count refresh is scheduled outside Render-Page.'+"`r`n")
$segment=$segment.Replace('        Start-Ps1LibrarySummaryScan'+"`n",'        # Count refresh is scheduled outside Render-Page.'+"`n")
$segment=$segment.Replace('        Start-Ps2LibrarySummaryScan'+"`n",'        # Count refresh is scheduled outside Render-Page.'+"`n")
$segment=$segment.Replace('        Start-Ps3LibrarySummaryScan'+"`n",'        # Count refresh is scheduled outside Render-Page.'+"`n")
$segment=$segment.Replace('                    Start-NativeConsoleLibrarySummaryScan $id'+"`n",'                    # Count refresh is scheduled outside Render-Page.'+"`n")
$text=$text.Substring(0,$start)+$segment+$text.Substring($end)

$timerNeedle='    $systemTimer = New-Object System.Windows.Threading.DispatcherTimer'
if(-not $text.Contains($timerNeedle)){throw 'Runtime hitch transform could not find system timer.'}
$helper=@'
    # HUYMAIER_RUNTIME_HITCH_GUARD_V1
    # State files are observed once through FileSystemWatcher. The WPF timer
    # consumes queued changes instead of stat/read polling every JSON file once
    # per second on the UI thread.
    $script:HcRuntimeStateWatcher=$null
    $script:HcRuntimeStateSubscriptions=@()
    $script:HcRuntimeStateSource='Huymaier.RuntimeState.'+$PID
    $script:HcRuntimeDirty=@{}
    $script:HcDownloadHistoryDirty=$true
    $script:HcCountRefreshOrder=@('PS1','PS2','PS3','N64','GAMECUBE','WII','WIIU','SWITCH','XBOX','XBOX360')
    $script:HcCountRefreshIndex=0
    $script:HcNextCountWorkerAt=[datetime]::MinValue

    function Add-HcRuntimeDirtyPath {param([string]$Path);if($Path){try{$script:HcRuntimeDirty[[IO.Path]::GetFullPath($Path).ToLowerInvariant()]=$true}catch{$script:HcRuntimeDirty[$Path.ToLowerInvariant()]=$true}}}
    function Test-HcRuntimePathDirty {param([string]$Path);if(-not $Path){return $false};$key=$Path.ToLowerInvariant();try{$key=[IO.Path]::GetFullPath($Path).ToLowerInvariant()}catch{};if($script:HcRuntimeDirty.ContainsKey($key)){$script:HcRuntimeDirty.Remove($key);return $true};return $false}
    function Initialize-HcRuntimeStateWatcher {
        foreach($path in @($script:LibraryStatePath,$script:LibraryResultPath,$script:ArtworkStatePath,$script:ArtworkResultPath,$script:Ps1SummaryPath,$script:Ps2SummaryPath,$script:Ps3SummaryPath,$script:StorefrontStatePath,$script:ProviderStatePath,$script:ProviderCatalogPath,$script:UpdateStatePath,$script:DriverStatePath)){Add-HcRuntimeDirtyPath $path}
        try{
            $watcher=New-Object IO.FileSystemWatcher $script:DataDir,'*'
            $watcher.IncludeSubdirectories=$true;$watcher.NotifyFilter=[IO.NotifyFilters]::LastWrite -bor [IO.NotifyFilters]::Size -bor [IO.NotifyFilters]::FileName -bor [IO.NotifyFilters]::DirectoryName;$watcher.InternalBufferSize=32768
            foreach($eventName in @('Changed','Created','Renamed','Deleted')){$id=$script:HcRuntimeStateSource+'.'+$eventName;[void](Register-ObjectEvent -InputObject $watcher -EventName $eventName -SourceIdentifier $id);$script:HcRuntimeStateSubscriptions+=$id}
            $watcher.EnableRaisingEvents=$true;$script:HcRuntimeStateWatcher=$watcher
        }catch{Write-Log "Runtime state watcher could not start: $($_.Exception.Message)" 'WARN'}
    }
    function Update-HcRuntimeStateEvents {
        foreach($id in @($script:HcRuntimeStateSubscriptions)){
            foreach($evt in @(Get-Event -SourceIdentifier $id -ErrorAction SilentlyContinue)){
                try{
                    $full=[string]$evt.SourceEventArgs.FullPath
                    if($full){
                        $lower=$full.ToLowerInvariant()
                        if($lower -match '\\gameproviders\\transfers\\transfer-[^\\]+\.json$'){$script:HcDownloadHistoryDirty=$true}else{Add-HcRuntimeDirtyPath $full}
                        if($lower.EndsWith('provider-state.json') -or $lower.EndsWith('storefront-state.json') -or $lower.EndsWith('provider-transfers.json')){$script:HcDownloadHistoryDirty=$true}
                    }
                }catch{}
                try{Remove-Event -EventIdentifier $evt.EventIdentifier -ErrorAction SilentlyContinue}catch{}
            }
        }
    }
    function Stop-HcRuntimeStateWatcher {
        try{if($null -ne $script:HcRuntimeStateWatcher){$script:HcRuntimeStateWatcher.EnableRaisingEvents=$false}}catch{}
        foreach($id in @($script:HcRuntimeStateSubscriptions)){try{Unregister-Event -SourceIdentifier $id -ErrorAction SilentlyContinue}catch{};try{Get-Event -SourceIdentifier $id -ErrorAction SilentlyContinue|Remove-Event -ErrorAction SilentlyContinue}catch{}}
        try{if($null -ne $script:HcRuntimeStateWatcher){$script:HcRuntimeStateWatcher.Dispose()}}catch{}
        $script:HcRuntimeStateWatcher=$null;$script:HcRuntimeStateSubscriptions=@()
    }
    function Invoke-HcIncrementalConsoleCountRefresh {
        if($script:SelectedTab -ne 1 -or $script:SubPage){return}
        $now=Get-Date;if($now -lt $script:HcNextCountWorkerAt){return}
        if($script:HcCountRefreshIndex -ge $script:HcCountRefreshOrder.Count){$script:HcCountRefreshIndex=0;$script:HcNextCountWorkerAt=$now.AddSeconds(120);return}
        $id=[string]$script:HcCountRefreshOrder[$script:HcCountRefreshIndex];$script:HcCountRefreshIndex++
        switch($id){'PS1'{Start-Ps1LibrarySummaryScan}'PS2'{Start-Ps2LibrarySummaryScan}'PS3'{Start-Ps3LibrarySummaryScan}default{Start-NativeConsoleLibrarySummaryScan $id}}
        # One process start per interval avoids process-creation bursts on the UI thread.
        $script:HcNextCountWorkerAt=$now.AddSeconds(5)
    }
    Initialize-HcRuntimeStateWatcher

'@
$text=$text.Replace($timerNeedle,$helper+$timerNeedle)

$tickNeedle='    $systemTimer.Add_Tick({'+"`r`n"+'        try {'
if(-not $text.Contains($tickNeedle)){$tickNeedle='    $systemTimer.Add_Tick({'+"`n"+'        try {'}
if(-not $text.Contains($tickNeedle)){throw 'Runtime hitch transform could not find system timer tick.'}
$text=$text.Replace($tickNeedle,$tickNeedle+"`r`n            Update-HcRuntimeStateEvents`r`n            Invoke-HcIncrementalConsoleCountRefresh")

$replacements=@{
    '            if (Test-Path $script:LibraryStatePath) {'='            if ((Test-HcRuntimePathDirty $script:LibraryStatePath) -and (Test-Path $script:LibraryStatePath)) {';
    '            Apply-LibraryResult'='            if(Test-HcRuntimePathDirty $script:LibraryResultPath){Apply-LibraryResult}';
    '            Apply-OnlineArtworkResult'='            if(Test-HcRuntimePathDirty $script:ArtworkResultPath){Apply-OnlineArtworkResult}';
    '            if(Test-Path -LiteralPath $script:Ps3SummaryPath -PathType Leaf){'='            if((Test-HcRuntimePathDirty $script:Ps3SummaryPath) -and (Test-Path -LiteralPath $script:Ps3SummaryPath -PathType Leaf)){';
    '            if(Test-Path -LiteralPath $script:Ps1SummaryPath -PathType Leaf){'='            if((Test-HcRuntimePathDirty $script:Ps1SummaryPath) -and (Test-Path -LiteralPath $script:Ps1SummaryPath -PathType Leaf)){';
    '            if(Test-Path -LiteralPath $script:Ps2SummaryPath -PathType Leaf){'='            if((Test-HcRuntimePathDirty $script:Ps2SummaryPath) -and (Test-Path -LiteralPath $script:Ps2SummaryPath -PathType Leaf)){';
    '            if (Test-Path $script:StorefrontStatePath) {'='            if ((Test-HcRuntimePathDirty $script:StorefrontStatePath) -and (Test-Path $script:StorefrontStatePath)) {';
    '            if (Test-Path $script:ProviderStatePath) {'='            if ((Test-HcRuntimePathDirty $script:ProviderStatePath) -and (Test-Path $script:ProviderStatePath)) {';
    '            if (Test-Path $script:ProviderCatalogPath) {'='            if ((Test-HcRuntimePathDirty $script:ProviderCatalogPath) -and (Test-Path $script:ProviderCatalogPath)) {';
    '            if (Test-Path $script:UpdateStatePath) {'='            if ((Test-HcRuntimePathDirty $script:UpdateStatePath) -and (Test-Path $script:UpdateStatePath)) {';
    '            if (Test-Path $script:DriverStatePath) {'='            if ((Test-HcRuntimePathDirty $script:DriverStatePath) -and (Test-Path $script:DriverStatePath)) {';
    '                if(Test-Path -LiteralPath $nativeSummaryPath -PathType Leaf){'='                if((Test-HcRuntimePathDirty $nativeSummaryPath) -and (Test-Path -LiteralPath $nativeSummaryPath -PathType Leaf)){';
    '            if(Get-Command Update-HcDownloadHistory -ErrorAction SilentlyContinue){try{Update-HcDownloadHistory}catch{Write-Log "Download history observer failed: $($_.Exception.Message)" ''WARN''}}'='            if($script:HcDownloadHistoryDirty -and (Get-Command Update-HcDownloadHistory -ErrorAction SilentlyContinue)){$script:HcDownloadHistoryDirty=$false;try{Update-HcDownloadHistory}catch{Write-Log "Download history observer failed: $($_.Exception.Message)" ''WARN''}}'
}
foreach($old in $replacements.Keys){if($text.Contains($old)){$text=$text.Replace($old,$replacements[$old])}}

# Remove the old 30-second burst that launched every summary worker together.
$burst='(?s)            if\(\$script:SelectedTab -eq 1 -and -not \$script:SubPage -and \(Get-Date\) -ge \$script:NextConsoleCountRefreshAt\)\{.*?            \}\r?\n            foreach\(\$nativeId in @\(''N64'',''GAMECUBE'',''WII'',''WIIU'',''SWITCH'',''XBOX'',''XBOX360''\)\)\{'
$m=[regex]::Match($text,$burst)
if($m.Success){
    $replacement='            foreach($nativeId in @(''N64'',''GAMECUBE'',''WII'',''WIIU'',''SWITCH'',''XBOX'',''XBOX360'')){' 
    $text=$text.Substring(0,$m.Index)+$replacement+$text.Substring($m.Index+$m.Length)
}else{throw 'Runtime hitch transform could not remove the console-count process burst.'}

# Dispose the watcher with the rest of the runtime services.
$closing='try { $clockTimer.Stop(); $systemTimer.Stop(); $gamepadTimer.Stop();'
if($text.Contains($closing)){$text=$text.Replace($closing,'try { $clockTimer.Stop(); $systemTimer.Stop(); $gamepadTimer.Stop(); Stop-HcRuntimeStateWatcher;')}
else{throw 'Runtime hitch transform could not find shell shutdown timer cleanup.'}

Set-Content -LiteralPath $ConsolePath -Value $text -Encoding UTF8
