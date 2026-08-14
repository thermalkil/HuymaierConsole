param(
    [Parameter(Mandatory=$true)][string]$ProviderModulePath,
    [Parameter(Mandatory=$true)][string]$ProviderWorkerPath,
    [Parameter(Mandatory=$true)][string]$ProgressWorkerPath,
    [Parameter(Mandatory=$true)][string]$BootstrapPath,
    [Parameter(Mandatory=$true)][string]$ShellRedesignPath
)

Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
foreach($path in @($ProviderModulePath,$ProviderWorkerPath,$ProgressWorkerPath,$BootstrapPath,$ShellRedesignPath)){if(-not(Test-Path -LiteralPath $path -PathType Leaf)){throw "Provider concurrency transform input missing: $path"}}

# Load the concurrent state layer after the legacy provider module so only
# Install/Update behavior is overridden. Other provider operations retain their
# known-good implementation.
$provider=Get-Content -Raw -LiteralPath $ProviderModulePath -Encoding UTF8
if($provider -notmatch 'HUYMAIER_PROVIDER_CONCURRENCY_V1'){
    $provider += @'

# HUYMAIER_PROVIDER_CONCURRENCY_V1
$concurrencyModule=Join-Path $script:BaseDir 'HuymaierProviderConcurrency.ps1'
if(Test-Path -LiteralPath $concurrencyModule -PathType Leaf){. $concurrencyModule}
'@
    Set-Content -LiteralPath $ProviderModulePath -Value $provider -Encoding UTF8
}

# Load the multi-card Downloads renderer after ShellRedesign has defined its
# completion ledger and base transfer UI functions.
$shell=Get-Content -Raw -LiteralPath $ShellRedesignPath -Encoding UTF8
if($shell -notmatch 'HUYMAIER_PROVIDER_CONCURRENCY_UI_V1'){
    $shell += @'

# HUYMAIER_PROVIDER_CONCURRENCY_UI_V1
$concurrencyUi=Join-Path $script:BaseDir 'HuymaierProviderConcurrencyUi.ps1'
if(Test-Path -LiteralPath $concurrencyUi -PathType Leaf){. $concurrencyUi}
'@
    Set-Content -LiteralPath $ShellRedesignPath -Value $shell -Encoding UTF8
}

# Each transfer gets its own redirected provider-output pair so simultaneous
# progress monitors cannot accidentally parse another game's backend output.
$worker=Get-Content -Raw -LiteralPath $ProviderWorkerPath -Encoding UTF8
if($worker -notmatch 'HUYMAIER_PROVIDER_TRANSFER_STATE_V1'){
    $started='$startedAt=(Get-Date).ToString(''o'')'
    if(-not $worker.Contains($started)){throw 'Provider concurrency transform could not find worker start marker.'}
    $worker=$worker.Replace($started,$started+"`r`n# HUYMAIER_PROVIDER_TRANSFER_STATE_V1`r`n`$script:TransferId=([IO.Path]::GetFileNameWithoutExtension(`$StatePath) -replace '^transfer-','')")

    $stateNeedle='GameId=$GameId;GameName=$GameName;WorkerPid=$PID;StartedAt=$startedAt;Updated=(Get-Date).ToString(''o'');'
    if(-not $worker.Contains($stateNeedle)){throw 'Provider concurrency transform could not find Write-State identity fields.'}
    $stateReplacement='TransferId=$script:TransferId;StatePath=$StatePath;GameId=$GameId;GameName=$GameName;InstallPath=$InstallPath;WorkerPid=$PID;StartedAt=$startedAt;Updated=(Get-Date).ToString(''o'');'
    $worker=$worker.Replace($stateNeedle,$stateReplacement)

    $speedNeedle='InstallSizeBytes=[int64]$script:TransferInstallSizeBytes;DownloadSpeedBytesPerSec=[double]$script:TransferSpeedBytesPerSec;'
    if($worker.Contains($speedNeedle)){$worker=$worker.Replace($speedNeedle,'InstallSizeBytes=[int64]$script:TransferInstallSizeBytes;DownloadSpeedBytesPerSec=[double]$script:TransferSpeedBytesPerSec;TransferSpeedBytesPerSec=[double]$script:TransferSpeedBytesPerSec;')}

    $outNeedle='$outFile=Join-Path $env:TEMP ("huymaier-provider-out-"+[guid]::NewGuid().ToString(''N'')+''.txt'')'
    $errNeedle='$errFile=Join-Path $env:TEMP ("huymaier-provider-err-"+[guid]::NewGuid().ToString(''N'')+''.txt'')'
    if(-not $worker.Contains($outNeedle) -or -not $worker.Contains($errNeedle)){throw 'Provider concurrency transform could not find captured-output paths.'}
    $worker=$worker.Replace($outNeedle,'$captureId=([string]$script:TransferId -replace ''[^A-Za-z0-9_-]'','''');if(-not $captureId){$captureId=[guid]::NewGuid().ToString(''N'')};$outFile=Join-Path $env:TEMP ("huymaier-provider-out-"+$captureId+''.txt'')')
    $worker=$worker.Replace($errNeedle,'$errFile=Join-Path $env:TEMP ("huymaier-provider-err-"+$captureId+''.txt'')')

    $catalogNeedle='function Read-Catalog{if(Test-Path -LiteralPath $CatalogPath){try{return Get-Content -Raw -LiteralPath $CatalogPath|ConvertFrom-Json}catch{}};return [pscustomobject]@{Providers=@();Updated=''''}}'
    if(-not $worker.Contains($catalogNeedle)){throw 'Provider concurrency transform could not find catalog read function.'}
    $lockHelper=@'
function Invoke-ProviderSharedStateLock{
    param([scriptblock]$Action)
    $mutex=$null;$acquired=$false
    try{
        $mutex=New-Object Threading.Mutex($false,'Local\HuymaierConsole.ProviderSharedState')
        try{$acquired=$mutex.WaitOne(30000)}catch[Threading.AbandonedMutexException]{$acquired=$true}
        if(-not $acquired){throw 'Timed out waiting for the provider state lock.'}
        return & $Action
    }finally{
        if($acquired -and $null -ne $mutex){try{$mutex.ReleaseMutex()}catch{}}
        if($null -ne $mutex){try{$mutex.Dispose()}catch{}}
    }
}
'@
    $worker=$worker.Replace($catalogNeedle,$catalogNeedle+"`r`n"+$lockHelper.TrimEnd())

    $saveProviderPattern='(?m)^function Save-ProviderNode\{.*\}$'
    if(-not [regex]::IsMatch($worker,$saveProviderPattern)){throw 'Provider concurrency transform could not find Save-ProviderNode.'}
    $saveProvider=@'
function Save-ProviderNode{
    param($Node)
    Invoke-ProviderSharedStateLock {
        $catalog=Read-Catalog;$nodes=New-Object System.Collections.ArrayList;$done=$false
        foreach($existing in @(Get-Prop $catalog 'Providers' @())){if([string]::Equals([string](Get-Prop $existing 'Id' ''),$Provider,[StringComparison]::OrdinalIgnoreCase)){[void]$nodes.Add($Node);$done=$true}else{[void]$nodes.Add($existing)}}
        if(-not $done){[void]$nodes.Add($Node)}
        Write-AtomicJson $CatalogPath ([pscustomobject]@{Providers=[object[]]$nodes.ToArray();Updated=(Get-Date).ToString('o')})
    }|Out-Null
}
'@
    $worker=[regex]::Replace($worker,$saveProviderPattern,[Text.RegularExpressions.MatchEvaluator]{param($m)$saveProvider.TrimEnd()},1)

    $saveManagedPattern='(?m)^function Save-ManagedInstall\{.*\}$'
    $removeManagedPattern='(?m)^function Remove-ManagedInstall\{.*\}$'
    if(-not [regex]::IsMatch($worker,$saveManagedPattern) -or -not [regex]::IsMatch($worker,$removeManagedPattern)){throw 'Provider concurrency transform could not find managed-install mutation functions.'}
    $saveManaged=@'
function Save-ManagedInstall{
    param([string]$Id,[string]$Name,[string]$Path)
    Invoke-ProviderSharedStateLock {
        $items=New-Object System.Collections.ArrayList;$done=$false
        foreach($item in @(Read-ManagedInstalls)){if([string](Get-Prop $item 'Provider' '') -eq $Provider -and [string](Get-Prop $item 'Id' '') -eq $Id){[void]$items.Add([pscustomobject]@{Provider=$Provider;Id=$Id;Name=$Name;Path=$Path;Updated=(Get-Date).ToString('o')});$done=$true}else{[void]$items.Add($item)}}
        if(-not $done){[void]$items.Add([pscustomobject]@{Provider=$Provider;Id=$Id;Name=$Name;Path=$Path;Updated=(Get-Date).ToString('o')})}
        Write-AtomicJson $managedPath ([object[]]$items.ToArray())
    }|Out-Null
}
'@
    $removeManaged=@'
function Remove-ManagedInstall{
    param([string]$Id)
    Invoke-ProviderSharedStateLock {
        $items=New-Object System.Collections.ArrayList
        foreach($item in @(Read-ManagedInstalls)){if(-not ([string](Get-Prop $item 'Provider' '') -eq $Provider -and [string](Get-Prop $item 'Id' '') -eq $Id)){[void]$items.Add($item)}}
        Write-AtomicJson $managedPath ([object[]]$items.ToArray())
    }|Out-Null
}
'@
    $worker=[regex]::Replace($worker,$saveManagedPattern,[Text.RegularExpressions.MatchEvaluator]{param($m)$saveManaged.TrimEnd()},1)
    $worker=[regex]::Replace($worker,$removeManagedPattern,[Text.RegularExpressions.MatchEvaluator]{param($m)$removeManaged.TrimEnd()},1)
    Set-Content -LiteralPath $ProviderWorkerPath -Value $worker -Encoding UTF8
}

# Progress workers filter redirected output by TransferId, while keeping the old
# broad scan as compatibility behavior when no transfer id was supplied.
$progress=Get-Content -Raw -LiteralPath $ProgressWorkerPath -Encoding UTF8
if($progress -notmatch 'HUYMAIER_PROVIDER_PROGRESS_TRANSFER_ID_V1'){
    $providerParam='(?m)^(\s*\[Parameter\(Mandatory=\$true\)\]\[ValidateSet\([^\r\n]+\)\]\[string\]\$Provider,\r?)$'
    if(-not [regex]::IsMatch($progress,$providerParam)){throw 'Provider concurrency transform could not find progress-worker provider parameter.'}
    $progress=[regex]::Replace($progress,$providerParam,'$1'+"`n    # HUYMAIER_PROVIDER_PROGRESS_TRANSFER_ID_V1`n    [string]`$TransferId='',",1)
    $tailNeedle='$files=Get-ChildItem -LiteralPath $env:TEMP -File -ErrorAction SilentlyContinue|Where-Object{$_.Name -match ''^huymaier-provider-(out|err)-.*\.txt$'' -and $_.LastWriteTimeUtc -ge $tempCutoff}|Sort-Object LastWriteTimeUtc -Descending|Select-Object -First 6'
    if(-not $progress.Contains($tailNeedle)){throw 'Provider concurrency transform could not find progress-worker output scan.'}
    $tailReplacement='$capturePattern=if($TransferId){''^huymaier-provider-(out|err)-''+[regex]::Escape($TransferId)+''\.txt$''}else{''^huymaier-provider-(out|err)-.*\.txt$''}' + "`r`n        " + '$files=Get-ChildItem -LiteralPath $env:TEMP -File -ErrorAction SilentlyContinue|Where-Object{$_.Name -match $capturePattern -and $_.LastWriteTimeUtc -ge $tempCutoff}|Sort-Object LastWriteTimeUtc -Descending|Select-Object -First 6'
    $progress=$progress.Replace($tailNeedle,$tailReplacement)
    Set-Content -LiteralPath $ProgressWorkerPath -Value $progress -Encoding UTF8
}

# The new transfer coordinator owns fallback telemetry per state file. Prevent
# the legacy single-state watcher from launching a second coordinator against
# provider-state.json.
$bootstrap=Get-Content -Raw -LiteralPath $BootstrapPath -Encoding UTF8
if($bootstrap -notmatch 'HUYMAIER_CONCURRENT_PROVIDER_COORDINATOR_V1'){
    $call="    Start-ProviderTelemetryWatch`r`n"
    if(-not $bootstrap.Contains($call)){$call="    Start-ProviderTelemetryWatch`n"}
    if(-not $bootstrap.Contains($call)){throw 'Provider concurrency transform could not find bootstrap telemetry-watch call.'}
    $replacement="    # HUYMAIER_CONCURRENT_PROVIDER_COORDINATOR_V1 - per-transfer coordinator starts on demand.`r`n"
    $bootstrap=$bootstrap.Replace($call,$replacement)
    Set-Content -LiteralPath $BootstrapPath -Value $bootstrap -Encoding UTF8
}
