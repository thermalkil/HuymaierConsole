param(
    [Parameter(Mandatory=$true)][string]$PackagePath,
    [Parameter(Mandatory=$true)][string]$InstallRoot,
    [Parameter(Mandatory=$true)][int]$ConsoleProcessId
)
Set-StrictMode -Version 2.0;$ErrorActionPreference='Stop'
$stateDir=Join-Path $env:LOCALAPPDATA 'Huymaier Console';$logDir=Join-Path $stateDir 'Logs';New-Item -ItemType Directory -Force -Path $logDir|Out-Null
$log=Join-Path $logDir ((Get-Date -Format 'yyyy-MM-dd')+'.log')
function Log($m,$l='INFO'){Add-Content -LiteralPath $log -Value ((Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff')+" [$l] "+$m) -Encoding UTF8}
try{
    Log "Self-update apply helper started for $PackagePath"
    try{Wait-Process -Id $ConsoleProcessId -Timeout 90 -ErrorAction SilentlyContinue}catch{}
    $stage=Join-Path $stateDir ('UpdateStage-'+[guid]::NewGuid().ToString('N'));New-Item -ItemType Directory -Force -Path $stage|Out-Null
    Expand-Archive -LiteralPath $PackagePath -DestinationPath $stage -Force
    $main=Get-ChildItem -LiteralPath $stage -Filter 'HuymaierConsole.ps1' -File -Recurse|Select-Object -First 1
    if($null -eq $main){throw 'Downloaded release does not contain HuymaierConsole.ps1.'}
    $source=$main.Directory.FullName
    $backup=Join-Path $stateDir ('UpdateBackup-'+(Get-Date -Format 'yyyyMMdd-HHmmss'));New-Item -ItemType Directory -Force -Path $backup|Out-Null
    Get-ChildItem -LiteralPath $InstallRoot -Force|Where-Object{$_.Name -notin @('Data')}|ForEach-Object{Copy-Item -LiteralPath $_.FullName -Destination $backup -Recurse -Force -ErrorAction SilentlyContinue}
    Copy-Item -Path (Join-Path $source '*') -Destination $InstallRoot -Recurse -Force
    $installer=Join-Path $InstallRoot 'Install-HuymaierConsole.ps1'
    if(Test-Path -LiteralPath $installer){& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $installer;if($LASTEXITCODE -ne 0){throw "Installer returned exit code $LASTEXITCODE."}}
    $launcher=Join-Path $InstallRoot 'Launch-HuymaierConsole.cmd'
    if(Test-Path -LiteralPath $launcher){Start-Process -FilePath $launcher|Out-Null}else{Start-Process powershell.exe -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-File',(Join-Path $InstallRoot 'HuymaierConsole.ps1'))|Out-Null}
    Log 'Self-update applied and Huymaier Console relaunched.'
    Remove-Item -LiteralPath $stage -Recurse -Force -ErrorAction SilentlyContinue
}catch{Log ("Self-update failed: "+$_.Exception.Message) 'ERROR';exit 1}
