[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$SettingsPath,
    [Parameter(Mandatory=$true)][string]$DefaultSettingsPath,
    [Parameter(Mandatory=$true)][string]$ResultPath
)
Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'

function Read-JsonFile([string]$Path){
    if(-not (Test-Path -LiteralPath $Path -PathType Leaf)){return $null}
    try{return Get-Content -Raw -LiteralPath $Path|ConvertFrom-Json}catch{return $null}
}
function Get-Prop($Object,[string]$Name,$Default){
    if($null -eq $Object){return $Default}
    $property=$Object.PSObject.Properties[$Name]
    if($null -eq $property -or $null -eq $property.Value){return $Default}
    return $property.Value
}
function Resolve-Pcsx2DataRoot($Settings){
    $configured=[string](Get-Prop $Settings 'pcsx2DataPath' '')
    $exe=[string](Get-Prop $Settings 'pcsx2Path' '')
    $candidates=New-Object System.Collections.ArrayList
    if($configured){[void]$candidates.Add($configured)}
    if($exe -and (Test-Path -LiteralPath $exe -PathType Leaf)){
        $dir=Split-Path -Parent $exe
        if((Test-Path -LiteralPath (Join-Path $dir 'portable.ini') -PathType Leaf) -or (Test-Path -LiteralPath (Join-Path $dir 'inis') -PathType Container)){[void]$candidates.Add($dir)}
    }
    [void]$candidates.Add((Join-Path ([Environment]::GetFolderPath([Environment+SpecialFolder]::MyDocuments)) 'PCSX2'))
    [void]$candidates.Add((Join-Path $env:APPDATA 'PCSX2'))
    [void]$candidates.Add((Join-Path $env:LOCALAPPDATA 'PCSX2'))
    foreach($candidate in $candidates){
        if(-not $candidate -or -not (Test-Path -LiteralPath $candidate -PathType Container)){continue}
        if((Test-Path -LiteralPath (Join-Path $candidate 'inis') -PathType Container) -or (Test-Path -LiteralPath (Join-Path $candidate 'memcards') -PathType Container) -or (Test-Path -LiteralPath (Join-Path $candidate 'PCSX2.ini') -PathType Leaf)){return [IO.Path]::GetFullPath($candidate)}
    }
    return $configured
}
function Read-IniValue([string]$Path,[string]$Section,[string]$Key){
    if(-not (Test-Path -LiteralPath $Path -PathType Leaf)){return ''}
    $current=''
    foreach($raw in Get-Content -LiteralPath $Path){
        $line=[string]$raw
        if($line.Trim() -match '^\[(.+)\]$'){$current=$matches[1];continue}
        if(-not [string]::Equals($current,$Section,[StringComparison]::OrdinalIgnoreCase)){continue}
        $index=$line.IndexOf('=')
        if($index -le 0){continue}
        if([string]::Equals($line.Substring(0,$index).Trim(),$Key,[StringComparison]::OrdinalIgnoreCase)){return $line.Substring($index+1).Trim()}
    }
    return ''
}
function Add-Root([System.Collections.ArrayList]$Target,[string]$Value){
    if(-not $Value){return}
    try{$full=[IO.Path]::GetFullPath([Environment]::ExpandEnvironmentVariables($Value.Trim())).TrimEnd([IO.Path]::DirectorySeparatorChar,[IO.Path]::AltDirectorySeparatorChar)}catch{return}
    if(-not (Test-Path -LiteralPath $full -PathType Container)){return}
    foreach($existing in @($Target)){
        if([string]::Equals([string]$existing,$full,[StringComparison]::OrdinalIgnoreCase)){return}
        if($full.StartsWith(([string]$existing+[IO.Path]::DirectorySeparatorChar),[StringComparison]::OrdinalIgnoreCase)){return}
    }
    foreach($existing in @($Target)){
        if(([string]$existing).StartsWith(($full+[IO.Path]::DirectorySeparatorChar),[StringComparison]::OrdinalIgnoreCase)){[void]$Target.Remove($existing)}
    }
    [void]$Target.Add($full)
}

$settings=Read-JsonFile $DefaultSettingsPath
$user=Read-JsonFile $SettingsPath
if($null -ne $user){$settings=$user}
$roots=New-Object System.Collections.ArrayList
foreach($root in @(Get-Prop $settings 'libraryRoots' @())){Add-Root $roots ([string]$root)}
$dataRoot=Resolve-Pcsx2DataRoot $settings
$ini=if($dataRoot){Join-Path $dataRoot 'inis\PCSX2.ini'}else{''}
if($ini -and -not (Test-Path -LiteralPath $ini -PathType Leaf)){$ini=Join-Path $dataRoot 'PCSX2.ini'}
$recursive=Read-IniValue $ini 'GameList' 'RecursivePaths'
foreach($raw in @($recursive -split '[|;\r\n]')){
    $value=[string]$raw
    if(-not $value.Trim()){continue}
    try{$path=if([IO.Path]::IsPathRooted($value.Trim())){[IO.Path]::GetFullPath($value.Trim())}else{[IO.Path]::GetFullPath((Join-Path $dataRoot $value.Trim()))}}catch{continue}
    Add-Root $roots $path
}
$extensions=@('.iso','.bin','.chd','.cso','.gz','.elf','.img','.mdf','.nrg')
$seen=@{}
$visitedFiles=0
$visitedDirectories=0
foreach($root in @($roots)){
    $queue=New-Object 'System.Collections.Generic.Queue[object]'
    $queue.Enqueue([pscustomobject]@{Path=[string]$root;Depth=0})
    while($queue.Count -gt 0 -and $visitedFiles -lt 25000 -and $visitedDirectories -lt 12000 -and $seen.Count -lt 5000){
        $current=$queue.Dequeue();$visitedDirectories++
        try{
            foreach($file in Get-ChildItem -LiteralPath $current.Path -File -ErrorAction SilentlyContinue){
                $visitedFiles++
                if($visitedFiles -gt 25000 -or $seen.Count -ge 5000){break}
                if($extensions -notcontains $file.Extension.ToLowerInvariant()){continue}
                $seen[$file.FullName.ToLowerInvariant()]=$true
            }
        }catch{}
        if([int]$current.Depth -ge 8){continue}
        try{
            foreach($directory in Get-ChildItem -LiteralPath $current.Path -Directory -ErrorAction SilentlyContinue){
                if(($directory.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0){continue}
                $queue.Enqueue([pscustomobject]@{Path=$directory.FullName;Depth=([int]$current.Depth+1)})
            }
        }catch{}
    }
}
$result=[ordered]@{Count=$seen.Count;UpdatedAt=(Get-Date).ToString('o');Error='';Roots=@($roots);FilesVisited=$visitedFiles;DirectoriesVisited=$visitedDirectories}
$directory=Split-Path -Parent $ResultPath
if($directory){New-Item -ItemType Directory -Force -Path $directory|Out-Null}
$result|ConvertTo-Json -Depth 5|Set-Content -LiteralPath $ResultPath -Encoding UTF8
