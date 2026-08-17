Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'

# Provider-neutral telemetry helpers for Downloads. These functions intentionally
# consume only backend output and explicit paths Huymaier already owns. They do
# not inspect arbitrary process memory/handles or hook provider processes.

function Convert-HcTelemetrySizeToBytes {
    param([double]$Value,[string]$Unit)
    $u=([string]$Unit).Trim().ToUpperInvariant()
    switch($u){
        'B'   {return [int64]$Value}
        'KB'  {return [int64]($Value*1KB)}
        'KIB' {return [int64]($Value*1KB)}
        'MB'  {return [int64]($Value*1MB)}
        'MIB' {return [int64]($Value*1MB)}
        'GB'  {return [int64]($Value*1GB)}
        'GIB' {return [int64]($Value*1GB)}
        'TB'  {return [int64]($Value*1TB)}
        'TIB' {return [int64]($Value*1TB)}
        default{return [int64]0}
    }
}

function Get-HcSmoothedTelemetryRate {
    param([double]$PreviousBytesPerSec,[double]$InstantBytesPerSec,[double]$Weight=0.28)
    $weight=[math]::Max(0.05,[math]::Min(0.90,$Weight))
    if($InstantBytesPerSec -le 0){return [math]::Max(0.0,$PreviousBytesPerSec*0.85)}
    if($PreviousBytesPerSec -le 0){return [double]$InstantBytesPerSec}
    return [double](($PreviousBytesPerSec*(1.0-$weight))+($InstantBytesPerSec*$weight))
}

function Get-HcTelemetryEtaSeconds {
    param([int64]$CurrentBytes,[int64]$TotalBytes,[double]$BytesPerSecond,[int]$Progress=-1,[double]$ElapsedSeconds=0)
    if($TotalBytes -gt 0 -and $BytesPerSecond -gt 1){
        return [int64][math]::Ceiling([math]::Max(0,[double]$TotalBytes-[double]$CurrentBytes)/$BytesPerSecond)
    }
    if($Progress -gt 0 -and $Progress -lt 100 -and $ElapsedSeconds -gt 0){
        return [int64][math]::Ceiling(($ElapsedSeconds/$Progress)*(100-$Progress))
    }
    return [int64]-1
}

function Format-HcTelemetryBytes {
    param([int64]$Bytes)
    if($Bytes -ge 1TB){return ('{0:N2} TB' -f ($Bytes/1TB))}
    if($Bytes -ge 1GB){return ('{0:N2} GB' -f ($Bytes/1GB))}
    if($Bytes -ge 1MB){return ('{0:N1} MB' -f ($Bytes/1MB))}
    if($Bytes -ge 1KB){return ('{0:N0} KB' -f ($Bytes/1KB))}
    return ('{0} B' -f [math]::Max(0,$Bytes))
}

function Format-HcTelemetrySpeed {
    param([double]$BytesPerSecond)
    if($BytesPerSecond -ge 1GB){return ('{0:N2} GB/s' -f ($BytesPerSecond/1GB))}
    if($BytesPerSecond -ge 1MB){return ('{0:N1} MB/s' -f ($BytesPerSecond/1MB))}
    if($BytesPerSecond -ge 1KB){return ('{0:N0} KB/s' -f ($BytesPerSecond/1KB))}
    if($BytesPerSecond -gt 0){return ('{0:N0} B/s' -f $BytesPerSecond)}
    return 'Measuring speed…'
}

function Format-HcTelemetryEta {
    param([int64]$Seconds)
    if($Seconds -lt 0){return 'Calculating ETA…'}
    $span=[TimeSpan]::FromSeconds([math]::Max(0,$Seconds))
    if($span.TotalHours -ge 1){return ('ETA {0}:{1:00}:{2:00}' -f [int]$span.TotalHours,$span.Minutes,$span.Seconds)}
    return ('ETA {0}:{1:00}' -f [int]$span.TotalMinutes,$span.Seconds)
}

function Get-HcProviderOutputTelemetry {
    param([string]$Text,[string]$DefaultPhase='Downloading')
    $result=[ordered]@{
        Phase=$DefaultPhase;Progress=-1;CurrentBytes=[int64]0;TotalBytes=[int64]0;
        InstallSizeBytes=[int64]0;SpeedBytesPerSec=[double]0;EtaSeconds=[int64]-1;
        HasNativeProgress=$false;HasNativeSpeed=$false;HasNativeEta=$false
    }
    if([string]::IsNullOrWhiteSpace($Text)){return [pscustomobject]$result}

    $phaseMatches=[regex]::Matches($Text,'(?im)\b(installing|extracting|unpacking|decompressing|applying|finalizing|finalising|verifying|writing files)\b')
    if($phaseMatches.Count -gt 0){$result.Phase='Installing'}
    elseif([regex]::IsMatch($Text,'(?im)\b(downloading|fetching|transferring)\b')){$result.Phase='Downloading'}

    $percentMatches=[regex]::Matches($Text,'(?im)(?:progress[^0-9]{0,20})?([0-9]{1,3}(?:\.[0-9]+)?)\s*%')
    if($percentMatches.Count -gt 0){
        $candidate=[double]::Parse($percentMatches[$percentMatches.Count-1].Groups[1].Value,[Globalization.CultureInfo]::InvariantCulture)
        if($candidate -ge 0 -and $candidate -le 100){$result.Progress=[int][math]::Round($candidate);$result.HasNativeProgress=$true}
    }

    $pairMatches=[regex]::Matches($Text,'(?im)([0-9]+(?:\.[0-9]+)?)\s*(B|KB|KiB|MB|MiB|GB|GiB|TB|TiB)\s*(?:/|of)\s*([0-9]+(?:\.[0-9]+)?)\s*(B|KB|KiB|MB|MiB|GB|GiB|TB|TiB)')
    if($pairMatches.Count -gt 0){
        $m=$pairMatches[$pairMatches.Count-1]
        $result.CurrentBytes=Convert-HcTelemetrySizeToBytes ([double]::Parse($m.Groups[1].Value,[Globalization.CultureInfo]::InvariantCulture)) $m.Groups[2].Value
        $result.TotalBytes=Convert-HcTelemetrySizeToBytes ([double]::Parse($m.Groups[3].Value,[Globalization.CultureInfo]::InvariantCulture)) $m.Groups[4].Value
    }

    $downloadMatches=[regex]::Matches($Text,'(?im)download(?:ed| size)?[^0-9]{0,24}([0-9]+(?:\.[0-9]+)?)\s*(B|KB|KiB|MB|MiB|GB|GiB|TB|TiB)')
    if($downloadMatches.Count -gt 0 -and $result.CurrentBytes -le 0){
        $m=$downloadMatches[$downloadMatches.Count-1]
        $result.CurrentBytes=Convert-HcTelemetrySizeToBytes ([double]::Parse($m.Groups[1].Value,[Globalization.CultureInfo]::InvariantCulture)) $m.Groups[2].Value
    }

    $totalMatches=[regex]::Matches($Text,'(?im)(?:download size|total(?: size)?)[^0-9]{0,24}([0-9]+(?:\.[0-9]+)?)\s*(B|KB|KiB|MB|MiB|GB|GiB|TB|TiB)')
    if($totalMatches.Count -gt 0 -and $result.TotalBytes -le 0){
        $m=$totalMatches[$totalMatches.Count-1]
        $result.TotalBytes=Convert-HcTelemetrySizeToBytes ([double]::Parse($m.Groups[1].Value,[Globalization.CultureInfo]::InvariantCulture)) $m.Groups[2].Value
    }

    $installMatches=[regex]::Matches($Text,'(?im)install(?:ed)? size[^0-9]{0,24}([0-9]+(?:\.[0-9]+)?)\s*(B|KB|KiB|MB|MiB|GB|GiB|TB|TiB)')
    if($installMatches.Count -gt 0){
        $m=$installMatches[$installMatches.Count-1]
        $result.InstallSizeBytes=Convert-HcTelemetrySizeToBytes ([double]::Parse($m.Groups[1].Value,[Globalization.CultureInfo]::InvariantCulture)) $m.Groups[2].Value
    }

    $speedMatches=[regex]::Matches($Text,'(?im)([0-9]+(?:\.[0-9]+)?)\s*(B|KB|KiB|MB|MiB|GB|GiB)\s*/\s*s')
    if($speedMatches.Count -gt 0){
        $m=$speedMatches[$speedMatches.Count-1]
        $result.SpeedBytesPerSec=[double](Convert-HcTelemetrySizeToBytes ([double]::Parse($m.Groups[1].Value,[Globalization.CultureInfo]::InvariantCulture)) $m.Groups[2].Value)
        $result.HasNativeSpeed=$result.SpeedBytesPerSec -gt 0
    }

    $etaMatches=[regex]::Matches($Text,'(?im)ETA\s*[:=-]?\s*(?:(\d+):)?(\d{1,2}):(\d{2})')
    if($etaMatches.Count -gt 0){
        $m=$etaMatches[$etaMatches.Count-1]
        $hours=0
        if($m.Groups[1].Success){$hours=[int]$m.Groups[1].Value}
        $result.EtaSeconds=[int64](($hours*3600)+([int]$m.Groups[2].Value*60)+[int]$m.Groups[3].Value)
        $result.HasNativeEta=$true
    }

    if($result.Progress -lt 0 -and $result.TotalBytes -gt 0 -and $result.CurrentBytes -ge 0){
        $result.Progress=[int][math]::Min(99,[math]::Round(($result.CurrentBytes/[double]$result.TotalBytes)*100))
    }
    return [pscustomobject]$result
}

function Get-HcKnownPathSize {
    param([string]$Path,[int]$MaxFiles=50000)
    if([string]::IsNullOrWhiteSpace($Path)){return [pscustomobject]@{Bytes=[int64]0;Files=0;Truncated=$false}}
    try{
        if(Test-Path -LiteralPath $Path -PathType Leaf){$item=Get-Item -LiteralPath $Path -ErrorAction Stop;return [pscustomobject]@{Bytes=[int64]$item.Length;Files=1;Truncated=$false}}
        if(-not(Test-Path -LiteralPath $Path -PathType Container)){return [pscustomobject]@{Bytes=[int64]0;Files=0;Truncated=$false}}
        [int64]$bytes=0;$count=0;$truncated=$false
        foreach($file in [IO.Directory]::EnumerateFiles($Path,'*',[IO.SearchOption]::AllDirectories)){
            try{$bytes+=(New-Object IO.FileInfo($file)).Length}catch{}
            $count++
            if($count -ge $MaxFiles){$truncated=$true;break}
        }
        return [pscustomobject]@{Bytes=$bytes;Files=$count;Truncated=$truncated}
    }catch{return [pscustomobject]@{Bytes=[int64]0;Files=0;Truncated=$false}}
}

function New-HcTransferTelemetryState {
    param([string]$Phase='Downloading',[int64]$InitialBytes=0)
    return [pscustomobject]@{
        Phase=$Phase;PhaseStartedUtc=[datetime]::UtcNow;LastSampleUtc=[datetime]::UtcNow;
        LastBytes=[int64]$InitialBytes;SmoothedBytesPerSec=[double]0;Progress=-1;EtaSeconds=[int64]-1
    }
}

function Update-HcTransferTelemetryState {
    param(
        [Parameter(Mandatory=$true)]$State,
        [int64]$CurrentBytes,
        [int64]$TotalBytes=0,
        [int]$NativeProgress=-1,
        [double]$NativeSpeedBytesPerSec=0,
        [int64]$NativeEtaSeconds=-1,
        [datetime]$NowUtc=([datetime]::UtcNow)
    )
    $elapsed=[math]::Max(0.2,($NowUtc-[datetime]$State.LastSampleUtc).TotalSeconds)
    $delta=[math]::Max(0,[double]$CurrentBytes-[double]$State.LastBytes)
    $instant=$delta/$elapsed
    $measured=Get-HcSmoothedTelemetryRate ([double]$State.SmoothedBytesPerSec) $instant
    if($NativeSpeedBytesPerSec -gt 0){$State.SmoothedBytesPerSec=$NativeSpeedBytesPerSec}else{$State.SmoothedBytesPerSec=$measured}
    if($NativeProgress -ge 0){$State.Progress=$NativeProgress}elseif($TotalBytes -gt 0){$State.Progress=[int][math]::Min(99,[math]::Round(($CurrentBytes/[double]$TotalBytes)*100))}
    if($NativeEtaSeconds -ge 0){$State.EtaSeconds=$NativeEtaSeconds}else{$State.EtaSeconds=Get-HcTelemetryEtaSeconds $CurrentBytes $TotalBytes ([double]$State.SmoothedBytesPerSec) ([int]$State.Progress) (($NowUtc-[datetime]$State.PhaseStartedUtc).TotalSeconds)}
    $State.LastBytes=[int64]$CurrentBytes
    $State.LastSampleUtc=$NowUtc
    return $State
}

function New-HcTelemetryMessage {
    param([string]$Phase,[int64]$CurrentBytes,[int64]$TotalBytes,[double]$SpeedBytesPerSec,[int64]$EtaSeconds)
    $amount='Measuring activity…'
    if($TotalBytes -gt 0){$amount=(Format-HcTelemetryBytes $CurrentBytes)+' / '+(Format-HcTelemetryBytes $TotalBytes)}
    elseif($CurrentBytes -gt 0){$amount=Format-HcTelemetryBytes $CurrentBytes}
    return ([string]$Phase+'  •  '+$amount+'  •  '+(Format-HcTelemetrySpeed $SpeedBytesPerSec)+'  •  '+(Format-HcTelemetryEta $EtaSeconds))
}
