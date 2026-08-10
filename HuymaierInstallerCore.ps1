param(
    [Parameter(Mandatory=$true)][string]$PackageRoot,
    [switch]$SilentUpdate
)
Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'

$script:InstallVersion='0.26.1'
$script:Destination=Join-Path $env:LOCALAPPDATA 'Huymaier Console'
$script:InstallLogRoot=Join-Path $script:Destination 'Logs'
New-Item -ItemType Directory -Force -Path $script:InstallLogRoot|Out-Null
$script:InstallLogPath=Join-Path $script:InstallLogRoot ('install-v{0}-{1}.log' -f $script:InstallVersion,(Get-Date -Format 'yyyyMMdd-HHmmss'))
$script:TranscriptLogPath=Join-Path $script:InstallLogRoot ('transcript-v{0}-{1}.log' -f $script:InstallVersion,(Get-Date -Format 'yyyyMMdd-HHmmss'))
$script:TranscriptStarted=$false
$script:TransactionStarted=$false
$script:TransactionCommitted=$false
$script:Backup=$null
$script:NewMap=@{}
$script:OldMap=@{}
$script:LegacyManagedPaths=@(
    'HuymaierGuideInput.cs',
    'HuymaierGuideBridge.dll',
    'HuymaierConsoleUpdate.ps1',
    'HuymaierConsoleApplyUpdate.ps1',
    'Native\GuideBridge\HuymaierGuideBridge.cpp'
)
$script:InstallerMutex=$null
$script:OwnsInstallerMutex=$false

function Write-InstallerRecord {
    param([string]$Message,[string]$Level='INFO')
    $line='{0} [{1}] {2}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff'),$Level,$Message
    try{Add-Content -LiteralPath $script:InstallLogPath -Value $line -Encoding UTF8}catch{}
    try{
        if($Level -eq 'ERROR'){Write-Host $line -ForegroundColor Red}
        elseif($Level -eq 'WARN'){Write-Host $line -ForegroundColor Yellow}
        else{Write-Host $line}
    }catch{}
}

function Get-HcSafeRelativePath {
    param([string]$Root,[string]$Relative)
    if([string]::IsNullOrWhiteSpace($Relative)){throw 'Package manifest contains an empty path.'}
    $relativePath=$Relative.Replace('/','\')
    if([IO.Path]::IsPathRooted($relativePath)){throw "Package manifest contains a rooted path: $Relative"}
    if($relativePath -match '(^|\)\.\.(\|$)'){throw "Package manifest contains path traversal: $Relative"}
    $rootFull=[IO.Path]::GetFullPath($Root).TrimEnd('\')
    $full=[IO.Path]::GetFullPath((Join-Path $rootFull $relativePath))
    if(-not $full.StartsWith($rootFull+'\',[StringComparison]::OrdinalIgnoreCase)){throw "Package path escapes the package root: $Relative"}
    return $relativePath
}

function Get-HcChecksumMap {
    param([string]$Root)
    $primary=Join-Path $Root 'checksums.sha256'
    $compat=Join-Path $Root 'SHA256SUMS.txt'
    if(-not(Test-Path -LiteralPath $primary -PathType Leaf) -or -not(Test-Path -LiteralPath $compat -PathType Leaf)){throw 'Package checksum manifests are missing.'}
    $primaryText=Get-Content -Raw -LiteralPath $primary -Encoding UTF8
    $compatText=Get-Content -Raw -LiteralPath $compat -Encoding UTF8
    if($primaryText -ne $compatText){throw 'checksums.sha256 and SHA256SUMS.txt do not agree.'}
    $map=@{}
    foreach($line in @($primaryText -split "`r?`n")){
        if([string]::IsNullOrWhiteSpace($line)){continue}
        if($line -notmatch '^([0-9a-fA-F]{64})\s{2}(.+)$'){throw "Invalid checksum row: $line"}
        $relative=Get-HcSafeRelativePath -Root $Root -Relative $Matches[2]
        if($map.ContainsKey($relative)){throw "Duplicate package path in checksum manifest: $relative"}
        $map[$relative]=$Matches[1].ToLowerInvariant()
    }
    if($map.Count -eq 0){throw 'Package checksum manifest is empty.'}
    return $map
}

function Get-HcPeMachine {
    param([string]$Path)
    $stream=[IO.File]::Open($Path,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::ReadWrite)
    try{
        $reader=New-Object IO.BinaryReader($stream)
        if($stream.Length -lt 64){throw "PE file is too small: $Path"}
        $stream.Position=0x3c
        $peOffset=$reader.ReadInt32()
        if($peOffset -lt 0 -or ($peOffset+6) -gt $stream.Length){throw "Invalid PE header offset: $Path"}
        $stream.Position=$peOffset
        if($reader.ReadUInt32() -ne 0x00004550){throw "Invalid PE signature: $Path"}
        return $reader.ReadUInt16()
    }finally{$stream.Dispose()}
}

function Assert-HcPackage {
    param([string]$Root,[string]$ExpectedVersion)
    $manifestPath=Join-Path $Root 'manifest.json'
    if(-not(Test-Path -LiteralPath $manifestPath -PathType Leaf)){throw 'manifest.json is missing from the package.'}
    $manifest=Get-Content -Raw -LiteralPath $manifestPath -Encoding UTF8|ConvertFrom-Json
    $actualVersion=[string]$manifest.version
    if(-not [string]::Equals($actualVersion,$ExpectedVersion,[StringComparison]::OrdinalIgnoreCase)){throw "Package version mismatch: expected $ExpectedVersion, found $actualVersion"}

    $map=Get-HcChecksumMap -Root $Root
    foreach($relative in $map.Keys){
        $path=Join-Path $Root $relative
        if(-not(Test-Path -LiteralPath $path -PathType Leaf)){throw "Checksummed package payload is missing: $relative"}
        $actual=(Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
        if($actual -ne $map[$relative]){throw "Package checksum mismatch: $relative"}
    }
    foreach($file in @(Get-ChildItem -LiteralPath $Root -Recurse -File -ErrorAction Stop)){
        $relative=$file.FullName.Substring($Root.TrimEnd('\').Length).TrimStart('\')
        if($relative -in @('checksums.sha256','SHA256SUMS.txt')){continue}
        if(-not $map.ContainsKey($relative)){throw "Unchecksummed package payload is not allowed: $relative"}
    }
    foreach($required in @('HuymaierConsole.exe','HuymaierGameInputBridge.dll','HuymaierBootstrap.ps1','HuymaierConsole.ps1','HuymaierGameBar.ps1','HuymaierSelfUpdater.ps1','HuymaierConsoleUpdateWorker.ps1','HuymaierInstallerCore.ps1','Restore-HuymaierWindowsSettings.ps1','manifest.json')){
        if(-not $map.ContainsKey($required)){throw "Required managed payload is missing from the checksum manifest: $required"}
    }
    foreach($binary in @('HuymaierConsole.exe','HuymaierGameInputBridge.dll','FSEPackage\HuymaierFSEHost.exe')){
        $path=Join-Path $Root $binary
        if(-not(Test-Path -LiteralPath $path -PathType Leaf)){throw "Required x64 binary is missing: $binary"}
        $machine=Get-HcPeMachine -Path $path
        if($machine -ne 0x8664){throw ('{0} is not x64 (PE machine 0x{1:X4}).' -f $binary,$machine)}
    }

    $parseFailures=New-Object System.Collections.Generic.List[string]
    foreach($scriptFile in @(Get-ChildItem -LiteralPath $Root -Recurse -File|Where-Object{$_.Extension -in @('.ps1','.psm1','.psd1')})){
        $tokens=$null;$parseErrors=$null
        [void][System.Management.Automation.Language.Parser]::ParseFile($scriptFile.FullName,[ref]$tokens,[ref]$parseErrors)
        foreach($parseError in @($parseErrors)){[void]$parseFailures.Add(('{0} line {1}, column {2}: {3}' -f $scriptFile.FullName,$parseError.Extent.StartLineNumber,$parseError.Extent.StartColumnNumber,$parseError.Message))}
    }
    if($parseFailures.Count -gt 0){throw "PowerShell source validation failed:`r`n$($parseFailures -join "`r`n")"}
    return $map
}

function Test-HcFilesIdentical {
    param([string]$Source,[string]$Destination)
    if(-not(Test-Path -LiteralPath $Source -PathType Leaf) -or -not(Test-Path -LiteralPath $Destination -PathType Leaf)){return $false}
    try{
        if((Get-Item -LiteralPath $Source).Length -ne (Get-Item -LiteralPath $Destination).Length){return $false}
        return ((Get-FileHash -LiteralPath $Source -Algorithm SHA256).Hash -eq (Get-FileHash -LiteralPath $Destination -Algorithm SHA256).Hash)
    }catch{return $false}
}

function Copy-HcFileWithRetry {
    param([string]$Source,[string]$Destination)
    if(Test-HcFilesIdentical -Source $Source -Destination $Destination){Write-InstallerRecord "Unchanged managed payload retained: $Destination";return}
    $parent=Split-Path -Parent $Destination;if($parent){New-Item -ItemType Directory -Force -Path $parent|Out-Null}
    $last=$null
    for($attempt=1;$attempt -le 40;$attempt++){
        try{Copy-Item -LiteralPath $Source -Destination $Destination -Force -ErrorAction Stop;return}catch{$last=$_.Exception;if($attempt -lt 40){Start-Sleep -Milliseconds 250}}
    }
    throw "Could not replace managed file after 10 seconds: $Destination. $($last.Message)"
}

function Stop-HcConsoleProcesses {
    $processes=@(Get-Process -Name 'HuymaierConsole' -ErrorAction SilentlyContinue|Where-Object{$_.Id -ne $PID})
    if($processes.Count -eq 0){return}
    Write-InstallerRecord ('Closing {0} running Huymaier Console process(es) before transaction.' -f $processes.Count)
    $processes|Stop-Process -Force -ErrorAction SilentlyContinue
    $deadline=[DateTime]::UtcNow.AddSeconds(10)
    do{Start-Sleep -Milliseconds 150;$remaining=@(Get-Process -Name 'HuymaierConsole' -ErrorAction SilentlyContinue|Where-Object{$_.Id -ne $PID})}while($remaining.Count -gt 0 -and [DateTime]::UtcNow -lt $deadline)
    if($remaining.Count -gt 0){throw 'HuymaierConsole.exe is still running and the installation cannot be changed safely.'}
}

function Read-HcInstalledMap {
    param([string]$Root)
    try{if(Test-Path -LiteralPath (Join-Path $Root 'checksums.sha256') -PathType Leaf){return Get-HcChecksumMap -Root $Root}}catch{Write-InstallerRecord "Previous installed checksum manifest could not be trusted; repair will use the new manifest plus known legacy paths. $($_.Exception.Message)" 'WARN'}
    return @{}
}

function Backup-HcManagedFiles {
    param([string]$InstallRoot,[hashtable]$NewMap,[hashtable]$OldMap,[string[]]$LegacyPaths)
    $backupRoot=Join-Path $env:TEMP ('HuymaierConsoleInstallBackup-'+[guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Force -Path $backupRoot|Out-Null
    $seen=@{}
    $paths=New-Object System.Collections.Generic.List[string]
    foreach($relative in @($NewMap.Keys)+@($OldMap.Keys)+@($LegacyPaths)+@('checksums.sha256','SHA256SUMS.txt','install-incomplete.json')){
        if([string]::IsNullOrWhiteSpace([string]$relative)){continue}
        $key=([string]$relative).ToLowerInvariant();if($seen.ContainsKey($key)){continue};$seen[$key]=$true
        $src=Join-Path $InstallRoot ([string]$relative)
        if(Test-Path -LiteralPath $src -PathType Leaf){
            $dst=Join-Path $backupRoot ([string]$relative)
            New-Item -ItemType Directory -Force -Path (Split-Path -Parent $dst)|Out-Null
            Copy-Item -LiteralPath $src -Destination $dst -Force -ErrorAction Stop
            [void]$paths.Add([string]$relative)
        }
    }
    return [pscustomobject]@{Root=$backupRoot;Files=[string[]]$paths.ToArray()}
}

function Restore-HcTransaction {
    param([string]$InstallRoot,[hashtable]$NewMap,[hashtable]$OldMap,[string[]]$LegacyPaths,$Backup)
    Write-InstallerRecord 'Rolling back incomplete installation transaction.' 'WARN'
    Stop-HcConsoleProcesses
    $markerPath=Join-Path $InstallRoot 'install-incomplete.json'
    $remove=@{}
    foreach($relative in @($NewMap.Keys)+@($OldMap.Keys)+@($LegacyPaths)+@('checksums.sha256','SHA256SUMS.txt')){
        if([string]::IsNullOrWhiteSpace([string]$relative)){continue};$remove[([string]$relative).ToLowerInvariant()]=[string]$relative
    }
    foreach($relative in $remove.Values){Remove-Item -LiteralPath (Join-Path $InstallRoot $relative) -Force -Recurse -ErrorAction SilentlyContinue}

    $hadPriorMarker=$false
    if($null -ne $Backup){$hadPriorMarker=@($Backup.Files) -contains 'install-incomplete.json'}
    if($null -ne $Backup -and (Test-Path -LiteralPath $Backup.Root)){
        foreach($relative in @($Backup.Files|Where-Object{$_ -ne 'install-incomplete.json'})){
            $src=Join-Path $Backup.Root $relative
            $dst=Join-Path $InstallRoot $relative
            New-Item -ItemType Directory -Force -Path (Split-Path -Parent $dst)|Out-Null
            Copy-Item -LiteralPath $src -Destination $dst -Force -ErrorAction Stop
        }
        if($hadPriorMarker){Copy-Item -LiteralPath (Join-Path $Backup.Root 'install-incomplete.json') -Destination $markerPath -Force -ErrorAction Stop}
        else{Remove-Item -LiteralPath $markerPath -Force -ErrorAction SilentlyContinue}
    }
    Write-InstallerRecord 'Rollback completed; prior incomplete-state semantics restored.' 'WARN'
}

trap {
    $failure=$_
    $details=[string]$failure.Exception.Message
    try{if($failure.InvocationInfo.PositionMessage){$details+="`r`n`r`n$($failure.InvocationInfo.PositionMessage)"}}catch{}
    try{if($failure.ScriptStackTrace){$details+="`r`n`r`nScript stack:`r`n$($failure.ScriptStackTrace)"}}catch{}
    Write-InstallerRecord $details 'ERROR'
    $rollbackSucceeded=$false
    if($script:TransactionStarted -and -not $script:TransactionCommitted){
        try{Restore-HcTransaction -InstallRoot $script:Destination -NewMap $script:NewMap -OldMap $script:OldMap -LegacyPaths $script:LegacyManagedPaths -Backup $script:Backup;$rollbackSucceeded=$true}catch{Write-InstallerRecord "ROLLBACK FAILED; incomplete marker is intentionally retained: $($_.Exception.Message)" 'ERROR'}
    }
    if(-not $SilentUpdate){
        try{
            Add-Type -AssemblyName System.Windows.Forms -ErrorAction SilentlyContinue
            [System.Windows.Forms.MessageBox]::Show("Huymaier Console installation failed safely.`r`n`r`n$details`r`n`r`nLog:`r`n$script:InstallLogPath",'Huymaier Console Installer',[System.Windows.Forms.MessageBoxButtons]::OK,[System.Windows.Forms.MessageBoxIcon]::Error)|Out-Null
        }catch{}
    }
    if($rollbackSucceeded -and $null -ne $script:Backup){Remove-Item -LiteralPath $script:Backup.Root -Recurse -Force -ErrorAction SilentlyContinue}
    if($script:TranscriptStarted){try{Stop-Transcript|Out-Null}catch{}}
    if($script:OwnsInstallerMutex -and $null -ne $script:InstallerMutex){try{$script:InstallerMutex.ReleaseMutex()}catch{}}
    if($null -ne $script:InstallerMutex){try{$script:InstallerMutex.Dispose()}catch{}}
    exit 1
}

try{Start-Transcript -LiteralPath $script:TranscriptLogPath -Force|Out-Null;$script:TranscriptStarted=$true}catch{}
Write-InstallerRecord "Installer v$script:InstallVersion started from $PackageRoot"

$created=$false
$script:InstallerMutex=[System.Threading.Mutex]::new($true,'Local\HuymaierConsole.Installer',[ref]$created)
$script:OwnsInstallerMutex=$created
if(-not $script:OwnsInstallerMutex){throw 'Another Huymaier Console installer/update transaction is already running.'}

$PackageRoot=[IO.Path]::GetFullPath($PackageRoot)
New-Item -ItemType Directory -Force -Path $script:Destination|Out-Null

# Zero installed bytes are mutated before the complete extracted package passes
# closed-manifest, hash, architecture, version, and PowerShell parser checks.
$script:NewMap=Assert-HcPackage -Root $PackageRoot -ExpectedVersion $script:InstallVersion
Write-InstallerRecord ('Package integrity passed for {0} managed payload files.' -f $script:NewMap.Count)

Stop-HcConsoleProcesses
try{
    $restore=Join-Path $PackageRoot 'Restore-HuymaierWindowsSettings.ps1'
    if(Test-Path -LiteralPath $restore -PathType Leaf){& $restore -Quiet}
}catch{Write-InstallerRecord "Prior Windows-setting recovery reported: $($_.Exception.Message)" 'WARN'}

$script:OldMap=Read-HcInstalledMap -Root $script:Destination
$script:Backup=Backup-HcManagedFiles -InstallRoot $script:Destination -NewMap $script:NewMap -OldMap $script:OldMap -LegacyPaths $script:LegacyManagedPaths
Write-InstallerRecord ('Rollback snapshot captured {0} existing managed files.' -f @($script:Backup.Files).Count)

$marker=Join-Path $script:Destination 'install-incomplete.json'
[ordered]@{version=$script:InstallVersion;startedAtUtc=[DateTime]::UtcNow.ToString('o');source=$PackageRoot}|ConvertTo-Json|Set-Content -LiteralPath $marker -Encoding UTF8
$script:TransactionStarted=$true
Write-InstallerRecord 'Persistent installation-incomplete marker created.'

foreach($relative in $script:OldMap.Keys){if(-not $script:NewMap.ContainsKey($relative)){Remove-Item -LiteralPath (Join-Path $script:Destination $relative) -Force -Recurse -ErrorAction SilentlyContinue}}
foreach($relative in $script:LegacyManagedPaths){if(-not $script:NewMap.ContainsKey($relative)){Remove-Item -LiteralPath (Join-Path $script:Destination $relative) -Force -Recurse -ErrorAction SilentlyContinue}}

foreach($relative in @($script:NewMap.Keys|Sort-Object)){
    Copy-HcFileWithRetry -Source (Join-Path $PackageRoot $relative) -Destination (Join-Path $script:Destination $relative)
}
Copy-HcFileWithRetry -Source (Join-Path $PackageRoot 'checksums.sha256') -Destination (Join-Path $script:Destination 'checksums.sha256')
Copy-HcFileWithRetry -Source (Join-Path $PackageRoot 'SHA256SUMS.txt') -Destination (Join-Path $script:Destination 'SHA256SUMS.txt')

foreach($relative in $script:NewMap.Keys){
    $path=Join-Path $script:Destination $relative
    if(-not(Test-Path -LiteralPath $path -PathType Leaf)){throw "Installed managed payload is missing: $relative"}
    $actual=(Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
    if($actual -ne $script:NewMap[$relative]){throw "Installed managed payload checksum mismatch: $relative"}
}
if((Get-Content -Raw -LiteralPath (Join-Path $script:Destination 'checksums.sha256') -Encoding UTF8) -ne (Get-Content -Raw -LiteralPath (Join-Path $script:Destination 'SHA256SUMS.txt') -Encoding UTF8)){throw 'Installed checksum manifests diverged.'}
Remove-Item -LiteralPath $marker -Force -ErrorAction Stop
$script:TransactionCommitted=$true
Write-InstallerRecord 'Installed payload verified; installation transaction committed.'

$gameInputVersion='3.5.262'
$gameInputMsi=Join-Path $script:Destination 'Tools\GameInput\GameInputRedist.msi'
$gameInputMarker=Join-Path $script:Destination 'gameinput-redist.version'
$installedGameInput=''
try{if(Test-Path -LiteralPath $gameInputMarker -PathType Leaf){$installedGameInput=(Get-Content -Raw -LiteralPath $gameInputMarker).Trim()}}catch{}
if((Test-Path -LiteralPath $gameInputMsi -PathType Leaf) -and $installedGameInput -ne $gameInputVersion){
    try{
        Write-InstallerRecord "Installing Microsoft GameInput redistributable $gameInputVersion. Windows may request administrator approval."
        $args='/i "'+$gameInputMsi+'" /qn /norestart'
        $proc=Start-Process -FilePath "$env:SystemRoot\System32\msiexec.exe" -ArgumentList $args -Verb RunAs -Wait -PassThru
        if($proc.ExitCode -notin @(0,3010,1638)){throw "GameInput installer returned $($proc.ExitCode)."}
        Set-Content -LiteralPath $gameInputMarker -Value $gameInputVersion -Encoding ASCII
        Write-InstallerRecord 'Microsoft GameInput redistributable is ready.'
    }catch{Write-InstallerRecord "Microsoft GameInput redistributable was not installed; system-button input will use available fallbacks. $($_.Exception.Message)" 'WARN'}
}

try{foreach($relative in $script:NewMap.Keys){Unblock-File -LiteralPath (Join-Path $script:Destination $relative) -ErrorAction SilentlyContinue}}catch{}

if(-not $SilentUpdate){
    try{
        $wsh=New-Object -ComObject WScript.Shell
        $nativeExe=Join-Path $script:Destination 'HuymaierConsole.exe'
        foreach($folder in @([Environment]::GetFolderPath('Desktop'),(Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs'))){
            $shortcut=$wsh.CreateShortcut((Join-Path $folder 'Huymaier Console.lnk'))
            $shortcut.TargetPath=$nativeExe;$shortcut.Arguments='';$shortcut.WorkingDirectory=$script:Destination
            $icon=Join-Path $script:Destination 'HuymaierConsole.ico';if(Test-Path $icon){$shortcut.IconLocation=$icon}
            $shortcut.Description='Huymaier Console Windows 11 FSE';$shortcut.Save()
        }
    }catch{Write-InstallerRecord "Shortcut refresh failed without affecting the verified installation: $($_.Exception.Message)" 'WARN'}
}

Write-InstallerRecord "Installation completed successfully at $script:Destination"
if($script:TranscriptStarted){try{Stop-Transcript|Out-Null;$script:TranscriptStarted=$false}catch{}}
if($null -ne $script:Backup){Remove-Item -LiteralPath $script:Backup.Root -Recurse -Force -ErrorAction SilentlyContinue}
if($script:OwnsInstallerMutex -and $null -ne $script:InstallerMutex){try{$script:InstallerMutex.ReleaseMutex()}catch{};$script:OwnsInstallerMutex=$false}
if($null -ne $script:InstallerMutex){try{$script:InstallerMutex.Dispose()}catch{};$script:InstallerMutex=$null}

if($SilentUpdate){exit 0}
try{
    Add-Type -AssemblyName PresentationFramework
    $result=[System.Windows.MessageBox]::Show("Huymaier Console v$script:InstallVersion was installed and verified for this Windows account.`n`nLocation:`n$script:Destination`n`nLaunch it now?",'Huymaier Console','YesNo','Information')
    if($result -eq 'Yes'){Start-Process -FilePath (Join-Path $script:Destination 'HuymaierConsole.exe') -WorkingDirectory $script:Destination|Out-Null}
}catch{}
