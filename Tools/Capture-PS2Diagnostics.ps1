[CmdletBinding()]
param()
Set-StrictMode -Version 2.0
$ErrorActionPreference='SilentlyContinue'
$stamp=Get-Date -Format 'yyyyMMdd-HHmmss'
$desktop=[Environment]::GetFolderPath([Environment+SpecialFolder]::Desktop)
$work=Join-Path $env:TEMP ("Huymaier-PS2-Diagnostics-$stamp")
$out=Join-Path $desktop ("Huymaier-PS2-Diagnostics-$stamp.zip")
New-Item -ItemType Directory -Force -Path $work|Out-Null
$appRoot=Join-Path $env:LOCALAPPDATA 'Huymaier Console'
$ps2Root=Join-Path $appRoot 'EmulatorPlatforms\PS2'
$consoleLogs=Join-Path $appRoot 'Logs'
foreach($file in @(
    (Join-Path $ps2Root 'settings.json'),
    (Join-Path $ps2Root 'library-summary.json'),
    (Join-Path $ps2Root 'ps2-native.log')
)){
    if(Test-Path -LiteralPath $file -PathType Leaf){Copy-Item -LiteralPath $file -Destination $work -Force}
}
if(Test-Path -LiteralPath $consoleLogs){
    $logTarget=Join-Path $work 'ConsoleLogs';New-Item -ItemType Directory -Force -Path $logTarget|Out-Null
    Get-ChildItem -LiteralPath $consoleLogs -File|Sort-Object LastWriteTime -Descending|Select-Object -First 6|ForEach-Object{Copy-Item -LiteralPath $_.FullName -Destination $logTarget -Force}
}
try{
    $settings=Get-Content -Raw -LiteralPath (Join-Path $ps2Root 'settings.json')|ConvertFrom-Json
    $data=[string]$settings.pcsx2DataPath
    if($data -and (Test-Path -LiteralPath $data)){
        $native=Join-Path $work 'PCSX2';New-Item -ItemType Directory -Force -Path $native|Out-Null
        foreach($relative in @('PCSX2.ini','inis\PCSX2.ini','logs\emulog.txt','logs\GSLog.txt')){
            $source=Join-Path $data $relative
            if(Test-Path -LiteralPath $source -PathType Leaf){
                $safe=($relative -replace '[\\/:*?"<>|]','_')
                Copy-Item -LiteralPath $source -Destination (Join-Path $native $safe) -Force
            }
        }
        $covers=Join-Path $data 'covers'
        if(Test-Path -LiteralPath $covers -PathType Container){
            Get-ChildItem -LiteralPath $covers -File -ErrorAction SilentlyContinue|Select-Object -First 200 Name,Length,LastWriteTime|Format-Table -AutoSize|Out-File (Join-Path $native 'covers-list.txt') -Encoding utf8
        }
        $memcards=Join-Path $data 'memcards'
        if(Test-Path -LiteralPath $memcards -PathType Container){
            Get-ChildItem -LiteralPath $memcards -Force -ErrorAction SilentlyContinue|Select-Object Name,PSIsContainer,Length,LastWriteTime|Format-Table -AutoSize|Out-File (Join-Path $native 'memory-cards-list.txt') -Encoding utf8
        }
    }
}catch{}
Get-CimInstance Win32_VideoController|Select-Object Name,DriverVersion,CurrentHorizontalResolution,CurrentVerticalResolution,CurrentRefreshRate|Format-List|Out-File (Join-Path $work 'display.txt') -Encoding utf8
Get-PnpDevice -PresentOnly|Where-Object{$_.Class -in @('HIDClass','Bluetooth','USB')}|Select-Object Class,FriendlyName,InstanceId,Status|Format-Table -AutoSize|Out-File (Join-Path $work 'input-devices.txt') -Encoding utf8
Compress-Archive -Path (Join-Path $work '*') -DestinationPath $out -Force
Remove-Item -LiteralPath $work -Recurse -Force
Write-Host "Created: $out"
