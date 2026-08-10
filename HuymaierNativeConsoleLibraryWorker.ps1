[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$PlatformId,
    [Parameter(Mandatory=$true)][string]$SettingsPath,
    [Parameter(Mandatory=$true)][string]$DefaultSettingsPath,
    [Parameter(Mandatory=$true)][string]$ResultPath
)
Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'

function Read-JsonFile([string]$Path){
    if(-not(Test-Path -LiteralPath $Path -PathType Leaf)){return $null}
    try{return Get-Content -Raw -LiteralPath $Path|ConvertFrom-Json}catch{return $null}
}
function Get-Prop($Object,[string]$Name,$Default){
    if($null -eq $Object){return $Default}
    $p=$Object.PSObject.Properties[$Name]
    if($null -eq $p -or $null -eq $p.Value){return $Default}
    return $p.Value
}
function Add-Root([System.Collections.ArrayList]$Target,[string]$Value){
    if(-not $Value){return}
    try{$full=[IO.Path]::GetFullPath([Environment]::ExpandEnvironmentVariables($Value.Trim())).TrimEnd('\')}catch{return}
    if(-not(Test-Path -LiteralPath $full -PathType Container)){return}
    foreach($existing in @($Target)){if([string]::Equals([string]$existing,$full,[StringComparison]::OrdinalIgnoreCase)){return}}
    [void]$Target.Add($full)
}
function Get-Extensions([string]$Id){
    switch($Id.ToUpperInvariant()){
        'PS4' { return @('.pkg','.elf','.bin') }
        'VITA' { return @('.vpk','.pkg','.zip') }
        'ARCADE' { return @('.zip','.7z','.chd') }
        'FINALBURNNEO' { return @('.zip','.7z','.chd') }
        'ATARILYNX' { return @('.lnx','.lyx','.o','.zip') }
        'NEOGEO' { return @('.zip','.7z','.neo') }
        'NGPC' { return @('.ngc','.ngp','.npc','.zip') }
        'JAGUAR' { return @('.j64','.jag','.rom','.bin','.abs','.cof','.zip') }
        'PRIMEHACK' { return @('.iso','.rvz','.wbfs','.gcm','.ciso') }
        'ATARI2600' { return @('.a26','.bin','.rom','.zip') }
        'NES' { return @('.nes','.fds','.unf','.unif','.zip') }
        'SNES' { return @('.sfc','.smc','.fig','.swc','.zip') }
        'GAMEBOY' { return @('.gb','.sgb','.zip') }
        'GBC' { return @('.gbc','.gb','.zip') }
        'GBA' { return @('.gba','.agb','.zip') }
        'GENESIS' { return @('.md','.gen','.bin','.smd','.zip') }
        'SEGACD' { return @('.cue','.chd','.iso','.bin') }
        'SEGA32X' { return @('.32x','.bin','.md','.zip') }
        'GAMEGEAR' { return @('.gg','.zip') }
        'MASTERSYSTEM' { return @('.sms','.sg','.zip') }
        'TURBOGRAFX16' { return @('.pce','.sgx','.cue','.chd','.zip') }
        'N64' { return @('.z64','.n64','.v64','.zip','.7z') }
        'GAMECUBE' { return @('.iso','.gcm','.rvz','.ciso','.gcz') }
        'WII' { return @('.iso','.wbfs','.rvz','.wia','.gcz') }
        'WIIU' { return @('.wua','.wud','.wux','.rpx') }
        'SWITCH' { return @('.nsp','.xci','.nca','.nro') }
        '3DS' { return @('.3ds','.cci','.cxi','.app','.zcci','.zcxi') }
        'NDS' { return @('.nds','.srl','.zip') }
        'DSI' { return @('.nds','.srl','.app') }
        'DREAMCAST' { return @('.gdi','.cdi','.chd','.cue') }
        'SATURN' { return @('.cue','.chd','.ccd','.mds','.iso') }
        'PSP' { return @('.iso','.cso','.pbp','.elf') }
        'XBOX' { return @('.iso','.xiso','.xbe') }
        'XBOX360' { return @('.iso','.xex','.zar') }
        default { return @() }
    }
}

$settings=Read-JsonFile $SettingsPath
if($null -eq $settings){$settings=Read-JsonFile $DefaultSettingsPath}
$roots=New-Object System.Collections.ArrayList
foreach($root in @(Get-Prop $settings 'gameFolders' @())){Add-Root $roots ([string]$root)}
$extensions=@(Get-Extensions $PlatformId)
$seen=@{}
$filesVisited=0
foreach($root in @($roots)){
    try{
        foreach($file in Get-ChildItem -LiteralPath $root -File -Recurse -ErrorAction SilentlyContinue){
            $filesVisited++
            if($filesVisited -gt 100000){break}
            if($extensions -notcontains $file.Extension.ToLowerInvariant()){continue}
            try{$key=$file.FullName.ToLowerInvariant()}catch{$key=[string]$file.FullName}
            if($key){$seen[$key]=$true}
        }
    }catch{}
    if($filesVisited -gt 100000){break}
}
$result=[ordered]@{
    Platform=$PlatformId.ToUpperInvariant()
    Count=$seen.Count
    UpdatedAt=(Get-Date).ToString('o')
    Error=''
    Roots=@($roots)
    FilesVisited=$filesVisited
}
$dir=Split-Path -Parent $ResultPath
if($dir){New-Item -ItemType Directory -Force -Path $dir|Out-Null}
$result|ConvertTo-Json -Depth 5|Set-Content -LiteralPath $ResultPath -Encoding UTF8