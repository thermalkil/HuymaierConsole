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
    # Lightweight rollback snapshot: preserve installed program files, not caches/assets/user data.
    if(Test-Path -LiteralPath $InstallRoot){
        foreach($f in @(Get-ChildItem -LiteralPath $InstallRoot -File -ErrorAction SilentlyContinue)){Copy-Item -LiteralPath $f.FullName -Destination (Join-Path $backup $f.Name) -Force -ErrorAction SilentlyContinue}
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
        if(Test-Path -LiteralPath $backup){foreach($f in @(Get-ChildItem -LiteralPath $backup -File -ErrorAction SilentlyContinue)){Copy-Item -LiteralPath $f.FullName -Destination (Join-Path $InstallRoot $f.Name) -Force -ErrorAction SilentlyContinue}}
        $old=Join-Path $InstallRoot 'HuymaierConsole.exe';if(Test-Path -LiteralPath $old){Start-Process -FilePath $old -WorkingDirectory $InstallRoot|Out-Null}
    }catch{}
}finally{
    Remove-Item -LiteralPath $temp,$backup -Recurse -Force -ErrorAction SilentlyContinue
}
