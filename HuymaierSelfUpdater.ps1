param(
    [Parameter(Mandatory=$true)][string]$PackagePath,
    [Parameter(Mandatory=$true)][int]$ParentProcessId,
    [string]$InstallRoot=(Join-Path $env:LOCALAPPDATA 'Huymaier Console')
)
Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'

$logRoot=Join-Path $env:LOCALAPPDATA 'Huymaier Console\Logs'
New-Item -ItemType Directory -Force -Path $logRoot|Out-Null
$log=Join-Path $logRoot ('self-update-'+(Get-Date -Format 'yyyyMMdd-HHmmss')+'.log')
$temp=Join-Path $env:TEMP ('HuymaierConsoleUpdate-'+[guid]::NewGuid().ToString('N'))
$mutex=$null
$ownsMutex=$false
$relaunch=''
$success=$false

function Log([string]$Message,[string]$Level='INFO'){
    try{Add-Content -LiteralPath $log -Value ((Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff')+" [$Level] "+$Message) -Encoding UTF8}catch{}
}

function Wait-HcProcessExit {
    param([int]$Id,[int]$TimeoutSeconds)
    $deadline=[DateTime]::UtcNow.AddSeconds($TimeoutSeconds)
    do{
        try{[void](Get-Process -Id $Id -ErrorAction Stop)}catch{return}
        Start-Sleep -Milliseconds 200
    }while([DateTime]::UtcNow -lt $deadline)
    throw "Timed out waiting for Huymaier Console PID $Id to exit."
}

function Assert-HcZipEntriesSafe {
    param([string]$Path)
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $archive=[IO.Compression.ZipFile]::OpenRead($Path)
    try{
        if($archive.Entries.Count -eq 0){throw 'Downloaded update ZIP is empty.'}
        foreach($entry in $archive.Entries){
            $name=[string]$entry.FullName
            if([string]::IsNullOrWhiteSpace($name)){continue}
            $normalized=$name.Replace('/','\')
            if([IO.Path]::IsPathRooted($normalized) -or $normalized -match '(^|\)\.\.(\|$)'){throw "Unsafe ZIP entry path: $name"}
        }
    }finally{$archive.Dispose()}
}

try{
    $created=$false
    $mutex=New-Object System.Threading.Mutex($true,'Local\HuymaierConsole.Updater',[ref]$created)
    $ownsMutex=$created
    if(-not $ownsMutex){throw 'Another Huymaier Console update is already running.'}

    Log "Waiting for Huymaier Console PID $ParentProcessId to exit."
    Wait-HcProcessExit -Id $ParentProcessId -TimeoutSeconds 90
    if(-not(Test-Path -LiteralPath $PackagePath -PathType Leaf)){throw "Downloaded update package is missing: $PackagePath"}

    $sidecar=$PackagePath+'.sha256'
    if(-not(Test-Path -LiteralPath $sidecar -PathType Leaf)){throw 'The published SHA-256 sidecar is missing; update installation is blocked.'}
    $line=Get-Content -LiteralPath $sidecar -Encoding ASCII|Select-Object -First 1
    if($line -notmatch '^([0-9a-fA-F]{64})(?:\s+.+)?$'){throw 'The published SHA-256 sidecar is invalid.'}
    $expected=$Matches[1].ToLowerInvariant()
    $actual=(Get-FileHash -LiteralPath $PackagePath -Algorithm SHA256).Hash.ToLowerInvariant()
    if($actual -ne $expected){throw 'Downloaded update ZIP does not match the SHA-256 published with the release.'}
    Log "Release SHA-256 verified: $actual"

    Assert-HcZipEntriesSafe -Path $PackagePath
    New-Item -ItemType Directory -Force -Path $temp|Out-Null
    Expand-Archive -LiteralPath $PackagePath -DestinationPath $temp -Force
    $installers=@(Get-ChildItem -LiteralPath $temp -Recurse -File -Filter 'Install-HuymaierConsole.ps1')
    if($installers.Count -ne 1){throw "Expected exactly one installer in the release ZIP; found $($installers.Count)."}
    $installer=$installers[0]

    # The v0.26.1+ installer owns the complete package transaction and rollback.
    # The updater deliberately does not maintain a second competing rollback
    # implementation.
    Log "Starting verified transactional installer: $($installer.FullName)"
    $proc=Start-Process -FilePath "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -ArgumentList @('-NoLogo','-NoProfile','-ExecutionPolicy','Bypass','-File',$installer.FullName,'-SilentUpdate') -Wait -PassThru -WindowStyle Hidden
    if($proc.ExitCode -ne 0){throw "Transactional installer exited with code $($proc.ExitCode)."}

    $exe=Join-Path $InstallRoot 'HuymaierConsole.exe'
    $marker=Join-Path $InstallRoot 'install-incomplete.json'
    if(-not(Test-Path -LiteralPath $exe -PathType Leaf)){throw 'Updated HuymaierConsole.exe is missing after installer success.'}
    if(Test-Path -LiteralPath $marker -PathType Leaf){throw 'Installer returned success while the incomplete-install marker still exists.'}
    $relaunch=$exe
    $success=$true
    Log 'Verified update transaction completed successfully.'
}catch{
    Log $_.Exception.Message 'ERROR'
    $old=Join-Path $InstallRoot 'HuymaierConsole.exe'
    $marker=Join-Path $InstallRoot 'install-incomplete.json'
    if((Test-Path -LiteralPath $old -PathType Leaf) -and -not(Test-Path -LiteralPath $marker -PathType Leaf)){$relaunch=$old}
}finally{
    Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue
    if($ownsMutex -and $null -ne $mutex){try{$mutex.ReleaseMutex()}catch{};$ownsMutex=$false}
    if($null -ne $mutex){try{$mutex.Dispose()}catch{};$mutex=$null}
}

# Release the updater gate before launching the new verified host. This avoids a
# relaunch race where the new process sees an update still in progress.
if($relaunch){Start-Sleep -Milliseconds 250;Start-Process -FilePath $relaunch -WorkingDirectory $InstallRoot|Out-Null}
if(-not $success){exit 1}
exit 0
