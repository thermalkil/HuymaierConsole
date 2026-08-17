[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$DestinationRoot)
Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
$target=Join-Path ([IO.Path]::GetFullPath($DestinationRoot)) 'DuckStation'
New-Item -ItemType Directory -Force -Path $target|Out-Null
$temp=Join-Path $env:TEMP ('duckstation-'+[guid]::NewGuid().ToString('N')+'.zip')
try{
    $url='https://github.com/stenzek/duckstation/releases/download/latest/duckstation-windows-x64-release.zip'
    Invoke-WebRequest -UseBasicParsing -Uri $url -OutFile $temp
    if(Get-Command Expand-Archive -ErrorAction SilentlyContinue){Expand-Archive -LiteralPath $temp -DestinationPath $target -Force}else{throw 'Expand-Archive is unavailable.'}
    $portable=Join-Path $target 'portable.txt';if(-not(Test-Path -LiteralPath $portable)){New-Item -ItemType File -Path $portable|Out-Null}
}finally{Remove-Item -LiteralPath $temp -Force -ErrorAction SilentlyContinue}
