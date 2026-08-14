param(
    [Parameter(Mandatory=$true)][string]$CatalogId,
    [Parameter(Mandatory=$true)][string]$Name,
    [Parameter(Mandatory=$true)][string]$StoreId,
    [Parameter(Mandatory=$true)][string]$StatePath
)

Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
$started=Get-Date
$outPath=Join-Path $env:TEMP ('huymaier-app-'+($CatalogId -replace '[^A-Za-z0-9_-]','_')+'-out.txt')
$errPath=Join-Path $env:TEMP ('huymaier-app-'+($CatalogId -replace '[^A-Za-z0-9_-]','_')+'-err.txt')

function Write-AppInstallState {
    param([string]$Phase,[bool]$Busy,[int]$Progress,[string]$Message,[string]$Error='')
    $eta=-1
    if($Busy -and $Progress -gt 1 -and $Progress -lt 100){
        $elapsed=((Get-Date)-$started).TotalSeconds
        if($elapsed -ge 2){$eta=[int64][math]::Max(1,[math]::Ceiling($elapsed*(100-$Progress)/$Progress))}
    }
    $state=[pscustomobject]@{
        CatalogId=$CatalogId
        Name=$Name
        StoreId=$StoreId
        Provider='Microsoft Store'
        Mode='Install'
        Phase=$Phase
        Busy=$Busy
        Progress=$Progress
        EtaSeconds=$eta
        Message=$Message
        Error=$Error
        StartedAt=$started.ToString('o')
        Updated=(Get-Date).ToString('o')
        WorkerPid=$PID
    }
    $directory=Split-Path -Parent $StatePath
    if($directory){New-Item -ItemType Directory -Force -Path $directory|Out-Null}
    $temp="$StatePath.$PID.tmp"
    $state|ConvertTo-Json -Depth 5|Set-Content -LiteralPath $temp -Encoding UTF8
    Move-Item -LiteralPath $temp -Destination $StatePath -Force
}

function Read-LatestProgress {
    $percent=0
    foreach($path in @($outPath,$errPath)){
        if(-not(Test-Path -LiteralPath $path -PathType Leaf)){continue}
        try{
            $text=Get-Content -Raw -LiteralPath $path -ErrorAction SilentlyContinue
            foreach($match in [regex]::Matches([string]$text,'(?<!\d)(\d{1,3})\s*%')){
                $value=[int]$match.Groups[1].Value
                if($value -ge 0 -and $value -le 100){$percent=$value}
            }
        }catch{}
    }
    return $percent
}

try{
    Remove-Item -LiteralPath $outPath,$errPath -Force -ErrorAction SilentlyContinue
    $winget=(Get-Command winget.exe -ErrorAction SilentlyContinue|Select-Object -First 1)
    if($null -eq $winget){throw 'Windows Package Manager (winget) is not available. Update App Installer from Microsoft Store.'}
    Write-AppInstallState 'Downloading' $true 0 'Preparing Microsoft Store download. Calculating ETA...'
    $arguments=@('install','--id',$StoreId,'--exact','--source','msstore','--accept-source-agreements','--accept-package-agreements','--disable-interactivity')
    $process=Start-Process -FilePath $winget.Source -ArgumentList $arguments -PassThru -WindowStyle Hidden -RedirectStandardOutput $outPath -RedirectStandardError $errPath
    try{$process.PriorityClass='BelowNormal'}catch{}
    $lastProgress=-1
    while(-not $process.HasExited){
        Start-Sleep -Milliseconds 650
        try{$process.Refresh()}catch{}
        $progress=Read-LatestProgress
        if($progress -ne $lastProgress){
            $phase=if($progress -ge 95){'Installing'}else{'Downloading'}
            $message=if($progress -gt 0){"$phase native app package."}else{'Microsoft Store is preparing the package. Calculating ETA...'}
            Write-AppInstallState $phase $true $progress $message
            $lastProgress=$progress
        }
    }
    $process.WaitForExit()
    if($process.ExitCode -ne 0){
        $details=''
        try{$details=(Get-Content -Raw -LiteralPath $errPath -ErrorAction SilentlyContinue).Trim()}catch{}
        if(-not $details){try{$details=(Get-Content -Raw -LiteralPath $outPath -ErrorAction SilentlyContinue).Trim()}catch{}}
        if($details.Length -gt 1200){$details=$details.Substring($details.Length-1200)}
        throw "winget exited with code $($process.ExitCode). $details"
    }
    Write-AppInstallState 'Complete' $false 100 'Native app installed successfully.'
    exit 0
}catch{
    Write-AppInstallState 'Error' $false 0 'Native app installation failed.' $_.Exception.Message
    exit 1
}
