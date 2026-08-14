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
function Set-Prop($Object,[string]$Name,$Value){
    if($null -eq $Object){return}
    $p=$Object.PSObject.Properties[$Name]
    if($null -eq $p){$Object|Add-Member -NotePropertyName $Name -NotePropertyValue $Value -Force}else{$Object.$Name=$Value}
}
function Add-Root([System.Collections.ArrayList]$Target,[string]$Value){
    if(-not $Value){return}
    try{$full=[IO.Path]::GetFullPath([Environment]::ExpandEnvironmentVariables($Value.Trim())).TrimEnd('\')}catch{return}
    if(-not(Test-Path -LiteralPath $full -PathType Container)){return}
    foreach($existing in $Target){if([string]::Equals([string]$existing,$full,[StringComparison]::OrdinalIgnoreCase)){return}}
    [void]$Target.Add($full)
}

function Test-PathSegment([string]$Path,[string[]]$Names){
    if([string]::IsNullOrWhiteSpace($Path)){return $false}
    $parts=@($Path -split '[\\/]')
    foreach($part in $parts){foreach($name in $Names){if([string]::Equals([string]$part,[string]$name,[StringComparison]::OrdinalIgnoreCase)){return $true}}}
    return $false
}
function Get-NintendoScopedRoots([string]$Id,[System.Collections.ArrayList]$Roots){
    $key=$Id.ToUpperInvariant()
    if($key -notin @('WII','GAMECUBE')){return $Roots.ToArray()}
    [string[]]$aliases=if($key -eq 'WII'){@('Wii','Nintendo Wii')}else{@('GameCube','Game Cube','Nintendo GameCube')}
    $scoped=New-Object System.Collections.ArrayList
    foreach($rootValue in $Roots){
        $root=[string]$rootValue
        if([string]::IsNullOrWhiteSpace($root)){continue}
        $leaf=''
        try{$leaf=[IO.Path]::GetFileName($root.TrimEnd('\','/'))}catch{}
        $alreadyScoped=$false
        foreach($alias in $aliases){if([string]::Equals($leaf,$alias,[StringComparison]::OrdinalIgnoreCase)){$alreadyScoped=$true;break}}
        if($alreadyScoped){Add-Root $scoped $root;continue}

        $matchingChildren=New-Object System.Collections.ArrayList
        try{
            foreach($child in Get-ChildItem -LiteralPath $root -Directory -ErrorAction SilentlyContinue){
                foreach($alias in $aliases){
                    if([string]::Equals([string]$child.Name,$alias,[StringComparison]::OrdinalIgnoreCase)){[void]$matchingChildren.Add([string]$child.FullName);break}
                }
            }
        }catch{}
        if($matchingChildren.Count -gt 0){foreach($childPath in $matchingChildren){Add-Root $scoped ([string]$childPath)}}else{Add-Root $scoped $root}
    }
    return $scoped.ToArray()
}
function Save-NintendoScopedRoots([string]$Id,$Settings,[string]$Path,[object[]]$Before,[object[]]$After){
    $key=$Id.ToUpperInvariant()
    if($key -notin @('WII','GAMECUBE') -or $null -eq $Settings -or -not(Test-Path -LiteralPath $Path -PathType Leaf)){return}
    $beforeNormalized=@($Before|ForEach-Object{[string]$_}|Where-Object{$_})
    $afterNormalized=@($After|ForEach-Object{[string]$_}|Where-Object{$_})
    if($beforeNormalized.Count -eq $afterNormalized.Count){
        $same=$true
        for($i=0;$i -lt $beforeNormalized.Count;$i++){if(-not [string]::Equals($beforeNormalized[$i],$afterNormalized[$i],[StringComparison]::OrdinalIgnoreCase)){$same=$false;break}}
        if($same){return}
    }
    try{
        $backup="$Path.pre-v0265-nintendo-root.bak"
        if(-not(Test-Path -LiteralPath $backup -PathType Leaf)){Copy-Item -LiteralPath $Path -Destination $backup -Force}
        Set-Prop $Settings 'gameFolders' ([object[]]$afterNormalized)
        $tmp="$Path.v0265.tmp"
        $Settings|ConvertTo-Json -Depth 30|Set-Content -LiteralPath $tmp -Encoding UTF8
        Move-Item -LiteralPath $tmp -Destination $Path -Force
    }catch{}
}
function Test-RawNintendoDiscHeader([string]$Path,[string]$Kind){
    $stream=$null
    try{
        $stream=[IO.File]::Open($Path,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::ReadWrite)
        $offset=if($Kind -eq 'WII'){0x18}else{0x1C}
        if($stream.Length -lt ($offset+4)){return $false}
        [void]$stream.Seek($offset,[IO.SeekOrigin]::Begin)
        $bytes=New-Object byte[] 4
        if($stream.Read($bytes,0,4) -ne 4){return $false}
        if($Kind -eq 'WII'){return $bytes[0]-eq 0x5D -and $bytes[1]-eq 0x1C -and $bytes[2]-eq 0x9E -and $bytes[3]-eq 0xA3}
        return $bytes[0]-eq 0xC2 -and $bytes[1]-eq 0x33 -and $bytes[2]-eq 0x9F -and $bytes[3]-eq 0x3D
    }catch{return $false}finally{if($null -ne $stream){try{$stream.Dispose()}catch{}}}
}
function Test-PlatformGameFile([string]$Id,$File){
    $key=$Id.ToUpperInvariant()
    $ext=$File.Extension.ToLowerInvariant()
    if($key -eq 'WII'){
        if(Test-PathSegment $File.FullName @('GameCube','Game Cube','Nintendo GameCube')){return $false}
        if($ext -eq '.iso'){return Test-RawNintendoDiscHeader $File.FullName 'WII'}
        if($ext -eq '.gcm'){return $false}
        return $true
    }
    if($key -eq 'GAMECUBE'){
        if(Test-PathSegment $File.FullName @('Wii','Nintendo Wii')){return $false}
        if($ext -eq '.iso' -or $ext -eq '.gcm'){return Test-RawNintendoDiscHeader $File.FullName 'GAMECUBE'}
        return $true
    }
    return $true
}

function Count-ModernInstalledApplications([string]$Id,[System.Collections.ArrayList]$Roots){
    $seen=@{};$visited=0
    foreach($root in $Roots){
        $candidates=New-Object System.Collections.ArrayList
        [void]$candidates.Add($root)
        if($Id -eq 'VITA'){
            foreach($candidate in @((Join-Path $root 'ux0\app'),(Join-Path $root 'Vita3K\ux0\app'))){if(Test-Path -LiteralPath $candidate -PathType Container){[void]$candidates.Add($candidate)}}
        }
        foreach($base in $candidates){
            if(-not(Test-Path -LiteralPath $base -PathType Container)){continue}
            try{
                foreach($eboot in Get-ChildItem -LiteralPath $base -Filter 'eboot.bin' -File -Recurse -ErrorAction SilentlyContinue){
                    if(++$visited -gt 12000){break};$appRoot=$eboot.Directory.FullName;$sfo=Join-Path $appRoot 'sce_sys\param.sfo';if(-not(Test-Path -LiteralPath $sfo -PathType Leaf)){continue};$seen[$eboot.FullName.ToLowerInvariant()]=$true
                }
            }catch{}
            if($visited -gt 12000){break}
        }
        if($visited -gt 12000){break}
    }
    return [pscustomobject]@{Count=$seen.Count;Visited=$visited}
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
$configuredRoots=[object[]]$roots.ToArray()
$scopedRoots=@(Get-NintendoScopedRoots $PlatformId $roots)
$roots=New-Object System.Collections.ArrayList
foreach($root in $scopedRoots){Add-Root $roots ([string]$root)}
Save-NintendoScopedRoots $PlatformId $settings $SettingsPath $configuredRoots ([object[]]$roots.ToArray())
$extensions=@(Get-Extensions $PlatformId)
$seen=@{}
$filesVisited=0
if($PlatformId.ToUpperInvariant() -in @('PS4','VITA')){
    $modern=Count-ModernInstalledApplications $PlatformId $roots
    $result=[ordered]@{Platform=$PlatformId.ToUpperInvariant();Count=[int]$modern.Count;UpdatedAt=(Get-Date).ToString('o');Error='';Roots=[object[]]$roots.ToArray();FilesVisited=[int]$modern.Visited}
    $dir=Split-Path -Parent $ResultPath;if($dir){New-Item -ItemType Directory -Force -Path $dir|Out-Null};$result|ConvertTo-Json -Depth 5|Set-Content -LiteralPath $ResultPath -Encoding UTF8;exit 0
}
foreach($root in $roots){
    try{
        foreach($file in Get-ChildItem -LiteralPath $root -File -Recurse -ErrorAction SilentlyContinue){
            $filesVisited++
            if($filesVisited -gt 100000){break}
            if($extensions -notcontains $file.Extension.ToLowerInvariant()){continue}
            if(-not(Test-PlatformGameFile $PlatformId $file)){continue}
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
    Roots=[object[]]$roots.ToArray()
    FilesVisited=$filesVisited
}
$dir=Split-Path -Parent $ResultPath
if($dir){New-Item -ItemType Directory -Force -Path $dir|Out-Null}
$result|ConvertTo-Json -Depth 5|Set-Content -LiteralPath $ResultPath -Encoding UTF8