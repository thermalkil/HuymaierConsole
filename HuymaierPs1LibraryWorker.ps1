[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$SettingsPath,
    [Parameter(Mandatory=$true)][string]$DefaultSettingsPath,
    [Parameter(Mandatory=$true)][string]$ResultPath
)
Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
function Read-JsonFile([string]$Path){if(-not(Test-Path -LiteralPath $Path -PathType Leaf)){return $null};try{return Get-Content -Raw -LiteralPath $Path|ConvertFrom-Json}catch{return $null}}
function Get-Prop($Object,[string]$Name,$Default){if($null -eq $Object){return $Default};$p=$Object.PSObject.Properties[$Name];if($null -eq $p -or $null -eq $p.Value){return $Default};return $p.Value}
function Add-Root([System.Collections.ArrayList]$Target,[string]$Value){if(-not $Value){return};try{$full=[IO.Path]::GetFullPath([Environment]::ExpandEnvironmentVariables($Value.Trim())).TrimEnd('\')}catch{return};if(-not(Test-Path -LiteralPath $full -PathType Container)){return};foreach($e in @($Target)){if([string]::Equals([string]$e,$full,[StringComparison]::OrdinalIgnoreCase)){return}};[void]$Target.Add($full)}
function Resolve-DataRoot($Settings){$configured=[string](Get-Prop $Settings 'dataRoot' '');if($configured){return $configured};$exe=[string](Get-Prop $Settings 'duckStationPath' '');if($exe -and (Test-Path -LiteralPath $exe -PathType Leaf)){try{$dir=Split-Path -Parent $exe;if(Test-Path -LiteralPath (Join-Path $dir 'portable.txt') -PathType Leaf){return $dir}}catch{}};$local=Join-Path $env:LOCALAPPDATA 'DuckStation';if(Test-Path -LiteralPath $local -PathType Container){return $local};return (Join-Path ([Environment]::GetFolderPath([Environment+SpecialFolder]::MyDocuments)) 'DuckStation')}
$settings=Read-JsonFile $SettingsPath;if($null -eq $settings){$settings=Read-JsonFile $DefaultSettingsPath}
$roots=New-Object System.Collections.ArrayList
foreach($r in @(Get-Prop $settings 'gameFolders' @())){Add-Root $roots ([string]$r)}
$dataRoot=Resolve-DataRoot $settings
$ini=Join-Path $dataRoot 'settings.ini'
if(Test-Path -LiteralPath $ini -PathType Leaf){$inGameList=$false;foreach($raw in Get-Content -LiteralPath $ini){$line=[string]$raw;$t=$line.Trim();if($t -match '^\[(.+)\]$'){$inGameList=[string]::Equals($matches[1],'GameList',[StringComparison]::OrdinalIgnoreCase);continue};if(-not $inGameList){continue};$eq=$t.IndexOf('=');if($eq -le 0){continue};$key=$t.Substring(0,$eq).Trim();if($key -notmatch 'Path'){continue};$value=$t.Substring($eq+1).Trim().Trim('"');foreach($part in @($value -split '[|;]')){Add-Root $roots ([string]$part)}}}
$extensions=@('.cue','.chd','.pbp','.ccd','.m3u','.iso','.mds','.ecm','.bin')
$groups=@{};$filesVisited=0
foreach($root in @($roots)){try{foreach($file in Get-ChildItem -LiteralPath $root -File -Recurse -ErrorAction SilentlyContinue){$filesVisited++;if($filesVisited -gt 25000){break};$ext=$file.Extension.ToLowerInvariant();if($extensions -notcontains $ext){continue};if($ext -eq '.bin' -and (Test-Path -LiteralPath ([IO.Path]::ChangeExtension($file.FullName,'.cue')) -PathType Leaf)){continue};$name=[IO.Path]::GetFileNameWithoutExtension($file.Name);if($name -match '(?i)\s*(?:[\(\[]\s*Track\s*0*\d+\s*[\)\]]|-\s*Track\s*0*\d+)\s*$'){continue};$name=$name -replace '\s*[\(\[]\s*(Disc|Disk|CD)\s*\d+\s*[\)\]]','' -replace '\s*-\s*(Disc|Disk|CD)\s*\d+\s*$','';$key=($name.ToLowerInvariant() -replace '[^a-z0-9]+','');if($key){$groups[$key]=$true}}}catch{}}
$result=[ordered]@{Count=$groups.Count;UpdatedAt=(Get-Date).ToString('o');Error='';Roots=@($roots);FilesVisited=$filesVisited}
$dir=Split-Path -Parent $ResultPath;if($dir){New-Item -ItemType Directory -Force -Path $dir|Out-Null};$result|ConvertTo-Json -Depth 5|Set-Content -LiteralPath $ResultPath -Encoding UTF8
