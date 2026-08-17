param()

Set-StrictMode -Version 2.0
$ErrorActionPreference='Continue'

$stamp=Get-Date -Format 'yyyyMMdd-HHmmss'
$temp=Join-Path $env:TEMP "Huymaier-PS3-Diagnostics-$stamp"
$out=Join-Path ([Environment]::GetFolderPath([Environment+SpecialFolder]::Desktop)) "Huymaier-PS3-Diagnostics-$stamp.zip"
New-Item -ItemType Directory -Force -Path $temp|Out-Null

$summary=New-Object System.Collections.Generic.List[string]
$summary.Add("Captured: $(Get-Date -Format o)")
$summary.Add("Windows: $([Environment]::OSVersion.VersionString)")
try{
    $processes=@(Get-Process HuymaierConsole -ErrorAction SilentlyContinue)
    foreach($process in $processes){
        $summary.Add("Process PID=$($process.Id) WorkingSetMB=$([math]::Round($process.WorkingSet64/1MB,1)) Handles=$($process.HandleCount)")
    }
}catch{}
$summary|Set-Content -LiteralPath (Join-Path $temp 'summary.txt') -Encoding UTF8

$root=Join-Path $env:LOCALAPPDATA 'Huymaier Console'
$logRoot=Join-Path $root 'Logs'
if(Test-Path $logRoot){
    New-Item -ItemType Directory -Force -Path (Join-Path $temp 'Logs')|Out-Null
    Get-ChildItem -LiteralPath $logRoot -Filter '*.log' -File -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTimeUtc -Descending | Select-Object -First 8 |
        Copy-Item -Destination (Join-Path $temp 'Logs') -Force -ErrorAction SilentlyContinue
}
$ps3Root=Join-Path $root 'EmulatorPlatforms\PS3'
if(Test-Path $ps3Root){
    New-Item -ItemType Directory -Force -Path (Join-Path $temp 'PS3')|Out-Null
    foreach($name in @('ps3-native-xmb.log','settings.json','settings.json.bak','library-summary.json')){
        $source=Join-Path $ps3Root $name
        if(Test-Path $source){Copy-Item -LiteralPath $source -Destination (Join-Path $temp 'PS3') -Force -ErrorAction SilentlyContinue}
    }
}

Compress-Archive -Path (Join-Path $temp '*') -DestinationPath $out -Force
Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue
Write-Host "PS3 diagnostics saved to:`n$out" -ForegroundColor Green
Start-Process explorer.exe -ArgumentList ('/select,"'+$out+'"')
