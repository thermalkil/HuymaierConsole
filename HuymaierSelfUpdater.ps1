param(
    [Parameter(Mandatory=$true)][string]$PackagePath,
    [Parameter(Mandatory=$true)][int]$ParentProcessId,
    [string]$InstallRoot=(Join-Path $env:LOCALAPPDATA 'Huymaier Console')
)
Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
$logRoot=Join-Path $env:LOCALAPPDATA 'Huymaier Console\Logs';New-Item -ItemType Directory -Force -Path $logRoot|Out-Null
$log=Join-Path $logRoot ('self-update-'+(Get-Date -Format 'yyyyMMdd-HHmmss')+'.log')
function Log([string]$m){try{Add-Content -LiteralPath $log -Value ((Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff')+' '+$m) -Encoding UTF8}catch{}}
$temp=Join-Path $env:TEMP ('HuymaierConsoleUpdate-'+[guid]::NewGuid().ToString('N'))
$backup=Join-Path $env:TEMP ('HuymaierConsoleBackup-'+[guid]::NewGuid().ToString('N'))
try{
    Log "Updater waiting for PID $ParentProcessId"
    try{Wait-Process -Id $ParentProcessId -Timeout 60 -ErrorAction SilentlyContinue}catch{}
    Start-Sleep -Milliseconds 500
    if(-not (Test-Path -LiteralPath $PackagePath -PathType Leaf)){throw "Downloaded update package is missing: $PackagePath"}
    New-Item -ItemType Directory -Force -Path $temp,$backup|Out-Null
    # Recursive rollback snapshot. Exclude only transient Logs/Updates so a
    # failed install cannot leave old native binaries mixed with new scripts.
    $backupInstall=Join-Path $backup 'install'
    New-Item -ItemType Directory -Force -Path $backupInstall|Out-Null
    if(Test-Path -LiteralPath $InstallRoot){
        foreach($dir in @(Get-ChildItem -LiteralPath $InstallRoot -Directory -Recurse -ErrorAction SilentlyContinue)){
            $relative=$dir.FullName.Substring($InstallRoot.Length).TrimStart('\\')
            if($relative -match '^(?i)(Logs|Updates)(\\|$)'){continue}
            New-Item -ItemType Directory -Force -Path (Join-Path $backupInstall $relative)|Out-Null
        }
        foreach($f in @(Get-ChildItem -LiteralPath $InstallRoot -File -Recurse -ErrorAction SilentlyContinue)){
            $relative=$f.FullName.Substring($InstallRoot.Length).TrimStart('\\')
            if($relative -match '^(?i)(Logs|Updates)(\\|$)'){continue}
            $target=Join-Path $backupInstall $relative
            New-Item -ItemType Directory -Force -Path (Split-Path -Parent $target)|Out-Null
            Copy-Item -LiteralPath $f.FullName -Destination $target -Force -ErrorAction SilentlyContinue
        }
    }
    Expand-Archive -LiteralPath $PackagePath -DestinationPath $temp -Force
    $installer=Get-ChildItem -LiteralPath $temp -Recurse -File -Filter 'Install-HuymaierConsole.ps1'|Select-Object -First 1
    if($null -eq $installer){throw 'The downloaded GitHub Release does not contain Install-HuymaierConsole.ps1.'}
    Log "Running installer $($installer.FullName)"
    $quotedInstaller='"'+$installer.FullName+'"'
    $arguments="-NoLogo -NoProfile -ExecutionPolicy Bypass -File $quotedInstaller -SilentUpdate"
    $proc=Start-Process -FilePath "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -ArgumentList $arguments -Wait -PassThru -WindowStyle Hidden
    if($proc.ExitCode -ne 0){throw "Installer exited with code $($proc.ExitCode)."}
    $exe=Join-Path $InstallRoot 'HuymaierConsole.exe';if(-not (Test-Path -LiteralPath $exe)){throw 'Updated HuymaierConsole.exe was not created.'}
    Log 'Update installed successfully; relaunching.'
    Start-Process -FilePath $exe -WorkingDirectory $InstallRoot|Out-Null
}catch{
    Log ('ERROR '+$_.Exception.Message)
    try{
        $backupInstall=Join-Path $backup 'install'
        if(Test-Path -LiteralPath $backupInstall){
            foreach($dir in @(Get-ChildItem -LiteralPath $backupInstall -Directory -Recurse -ErrorAction SilentlyContinue)){
                $relative=$dir.FullName.Substring($backupInstall.Length).TrimStart('\\')
                New-Item -ItemType Directory -Force -Path (Join-Path $InstallRoot $relative)|Out-Null
            }
            foreach($f in @(Get-ChildItem -LiteralPath $backupInstall -File -Recurse -ErrorAction SilentlyContinue)){
                $relative=$f.FullName.Substring($backupInstall.Length).TrimStart('\\')
                $target=Join-Path $InstallRoot $relative
                New-Item -ItemType Directory -Force -Path (Split-Path -Parent $target)|Out-Null
                Copy-Item -LiteralPath $f.FullName -Destination $target -Force -ErrorAction SilentlyContinue
            }
        }
        $old=Join-Path $InstallRoot 'HuymaierConsole.exe';if(Test-Path -LiteralPath $old){Start-Process -FilePath $old -WorkingDirectory $InstallRoot|Out-Null}
    }catch{}
}finally{
    Remove-Item -LiteralPath $temp,$backup -Recurse -Force -ErrorAction SilentlyContinue
}
