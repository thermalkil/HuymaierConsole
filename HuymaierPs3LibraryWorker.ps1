param(
    [Parameter(Mandatory=$true)][string]$SettingsPath,
    [Parameter(Mandatory=$true)][string]$DefaultSettingsPath,
    [Parameter(Mandatory=$true)][string]$ResultPath
)

Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
$ProgressPreference='SilentlyContinue'

function Get-Prop { param($Object,[string]$Name,$Default=$null); if($null -eq $Object){return $Default}; try{$p=$Object.PSObject.Properties[$Name];if($null -ne $p -and $null -ne $p.Value){return $p.Value}}catch{};return $Default }
function Read-Settings {
    $settings=$null
    foreach($path in @($SettingsPath,$DefaultSettingsPath)){
        if(-not (Test-Path -LiteralPath $path -PathType Leaf)){continue}
        try{$candidate=Get-Content -Raw -LiteralPath $path|ConvertFrom-Json;if($null -ne $candidate){$settings=$candidate;break}}catch{}
    }
    if($null -eq $settings){$settings=[pscustomobject]@{rpcs3Path='';rpcs3DataPath='';libraryRoots=@();scanRpcs3InstalledGames=$true}}
    return $settings
}
function Resolve-DataRoot {
    param($Settings)
    $candidates=New-Object System.Collections.ArrayList
    $configured=[string](Get-Prop $Settings 'rpcs3DataPath' '')
    if($configured){[void]$candidates.Add($configured)}
    $exe=[string](Get-Prop $Settings 'rpcs3Path' '')
    if($exe -and (Test-Path -LiteralPath $exe -PathType Leaf)){[void]$candidates.Add((Split-Path -Parent $exe))}
    [void]$candidates.Add((Join-Path $env:APPDATA 'rpcs3'))
    [void]$candidates.Add((Join-Path $env:LOCALAPPDATA 'rpcs3'))
    foreach($candidate in $candidates){
        if(-not $candidate -or -not (Test-Path -LiteralPath $candidate -PathType Container)){continue}
        if((Test-Path -LiteralPath (Join-Path $candidate 'dev_hdd0') -PathType Container) -or
           (Test-Path -LiteralPath (Join-Path $candidate 'dev_flash') -PathType Container) -or
           (Test-Path -LiteralPath (Join-Path $candidate 'config.yml') -PathType Leaf) -or
           (Test-Path -LiteralPath (Join-Path $candidate 'GuiConfigs') -PathType Container)){
            return [IO.Path]::GetFullPath($candidate)
        }
    }
    if($exe -and (Test-Path -LiteralPath $exe -PathType Leaf)){return (Split-Path -Parent $exe)}
    return ''
}
function Get-SfoTitleId {
    param([string]$Path)
    try{
        $bytes=[IO.File]::ReadAllBytes($Path)
        if($bytes.Length -lt 20 -or $bytes[0] -ne 0 -or $bytes[1] -ne 0x50 -or $bytes[2] -ne 0x53 -or $bytes[3] -ne 0x46){return ''}
        $keyTable=[BitConverter]::ToUInt32($bytes,8)
        $dataTable=[BitConverter]::ToUInt32($bytes,12)
        $count=[BitConverter]::ToUInt32($bytes,16)
        for($i=0;$i -lt $count;$i++){
            $entry=20+($i*16)
            if($entry+16 -gt $bytes.Length){break}
            $keyOffset=[BitConverter]::ToUInt16($bytes,$entry)
            $format=[BitConverter]::ToUInt16($bytes,$entry+2)
            $length=[BitConverter]::ToUInt32($bytes,$entry+4)
            $dataOffset=[BitConverter]::ToUInt32($bytes,$entry+12)
            $keyPos=[int]$keyTable+[int]$keyOffset
            if($keyPos -lt 0 -or $keyPos -ge $bytes.Length){continue}
            $keyEnd=$keyPos
            while($keyEnd -lt $bytes.Length -and $bytes[$keyEnd] -ne 0){$keyEnd++}
            $key=[Text.Encoding]::UTF8.GetString($bytes,$keyPos,$keyEnd-$keyPos)
            if($key -ne 'TITLE_ID'){continue}
            $dataPos=[int]$dataTable+[int]$dataOffset
            if($dataPos -lt 0 -or $dataPos -ge $bytes.Length){return ''}
            if($format -eq 0x0404 -or $format -eq 0x0204){
                $safe=[Math]::Min([int]$length,$bytes.Length-$dataPos)
                return [Text.Encoding]::UTF8.GetString($bytes,$dataPos,$safe).Trim([char]0).Trim()
            }
        }
    }catch{}
    return ''
}
function Find-SfoFiles {
    param([string]$Root,[int]$MaxDepth)
    $results=New-Object System.Collections.ArrayList
    if(-not $Root -or -not (Test-Path -LiteralPath $Root -PathType Container)){return [object[]]$results.ToArray()}
    $queue=New-Object System.Collections.Queue
    $visited=@{};$examined=0;$maxDirectories=20000
    $queue.Enqueue([pscustomobject]@{Path=$Root;Depth=0})
    while($queue.Count -gt 0 -and $examined -lt $maxDirectories){
        $node=$queue.Dequeue();$nodePath=[string]$node.Path
        try{$full=[IO.Path]::GetFullPath($nodePath).TrimEnd('\').ToLowerInvariant()}catch{$full=$nodePath.ToLowerInvariant()}
        if($visited.ContainsKey($full)){continue};$visited[$full]=$true;$examined++
        $candidate=Join-Path $nodePath 'PARAM.SFO'
        if(Test-Path -LiteralPath $candidate -PathType Leaf){[void]$results.Add($candidate)}
        if([int]$node.Depth -ge $MaxDepth){continue}
        try{foreach($dir in @(Get-ChildItem -LiteralPath $nodePath -Directory -ErrorAction Stop|Where-Object{-not ($_.Attributes -band [IO.FileAttributes]::ReparsePoint)})){$queue.Enqueue([pscustomobject]@{Path=$dir.FullName;Depth=([int]$node.Depth+1)})}}catch{}
    }
    return [object[]]$results.ToArray()
}

function Test-LooksLikePath {
    param([string]$Value)
    if(-not $Value){return $false}
    $expanded=[Environment]::ExpandEnvironmentVariables($Value.Trim())
    return [IO.Path]::IsPathRooted($expanded) -or $expanded.Contains('\') -or $expanded.Contains('/') -or $expanded.EndsWith('.iso',[StringComparison]::OrdinalIgnoreCase)
}
function Get-YamlSeparatorIndex {
    param([string]$Line)
    $single=$false;$quoted=$false
    for($i=0;$i -lt $Line.Length;$i++){
        $ch=$Line[$i]
        if($ch -eq "'" -and -not $quoted){$single=-not $single;continue}
        if($ch -eq '"' -and -not $single){$quoted=-not $quoted;continue}
        if($ch -eq ':' -and -not $single -and -not $quoted){return $i}
    }
    return -1
}
function Remove-YamlComment {
    param([string]$Value)
    $single=$false;$quoted=$false
    for($i=0;$i -lt $Value.Length;$i++){
        $ch=$Value[$i]
        if($ch -eq "'" -and -not $quoted){$single=-not $single;continue}
        if($ch -eq '"' -and -not $single -and ($i -eq 0 -or $Value[$i-1] -ne '\')){$quoted=-not $quoted;continue}
        if($ch -eq '#' -and -not $single -and -not $quoted -and ($i -eq 0 -or [char]::IsWhiteSpace($Value[$i-1]))){return $Value.Substring(0,$i).TrimEnd()}
    }
    return $Value
}
function Get-GamesYmlEntries {
    param([string]$Path)
    $entries=New-Object System.Collections.ArrayList
    if(-not $Path -or -not (Test-Path -LiteralPath $Path -PathType Leaf)){return [object[]]$entries.ToArray()}
    try{$lines=[IO.File]::ReadAllLines($Path)}catch{return [object[]]$entries.ToArray()}
    foreach($raw in $lines){
        $line=[string]$raw
        if(-not $line){continue};$line=$line.Trim()
        if(-not $line -or $line.StartsWith('#') -or $line.StartsWith('%') -or $line -eq '---' -or $line -eq '...'){continue}
        $separator=Get-YamlSeparatorIndex $line
        if($separator -le 0 -or $separator -ge ($line.Length-1)){continue}
        $left=$line.Substring(0,$separator).Trim().Trim('"').Trim("'")
        $right=Remove-YamlComment ($line.Substring($separator+1).Trim())
        if($right.StartsWith('"') -and $right.EndsWith('"')){$right=$right.Substring(1,$right.Length-2)}
        elseif($right.StartsWith("'") -and $right.EndsWith("'")){$right=$right.Substring(1,$right.Length-2).Replace("''", "'")}
        if((Test-LooksLikePath $left) -and -not (Test-LooksLikePath $right)){$id=$right;$value=$left}else{$id=$left;$value=$right}
        if($id -and $value){$id=$id.Trim().ToUpperInvariant();if($id){[void]$entries.Add([pscustomobject]@{Id=$id;Path=$value})}}
    }
    return [object[]]$entries.ToArray()
}

function Write-AtomicJson { param([string]$Path,$Value);$dir=Split-Path -Parent $Path;if($dir){New-Item -ItemType Directory -Force -Path $dir|Out-Null};$tmp="$Path.$PID.tmp";$Value|ConvertTo-Json -Depth 8|Set-Content -LiteralPath $tmp -Encoding UTF8;Move-Item -LiteralPath $tmp -Destination $Path -Force }

try{
    $settings=Read-Settings
    $dataRoot=Resolve-DataRoot $settings
    $roots=New-Object System.Collections.ArrayList
    if([bool](Get-Prop $settings 'scanRpcs3InstalledGames' $true) -and $dataRoot){
        [void]$roots.Add([pscustomobject]@{Path=(Join-Path $dataRoot 'dev_hdd0\game');Depth=2})
        [void]$roots.Add([pscustomobject]@{Path=(Join-Path $dataRoot 'dev_hdd0\disc');Depth=4})
        [void]$roots.Add([pscustomobject]@{Path=(Join-Path $dataRoot 'games');Depth=6})
    }
    $exe=[string](Get-Prop $settings 'rpcs3Path' '')
    $exeRoot=''
    if($exe -and (Test-Path -LiteralPath $exe -PathType Leaf)){
        $exeRoot=Split-Path -Parent $exe
        if(-not $dataRoot -or $exeRoot -ne $dataRoot){[void]$roots.Add([pscustomobject]@{Path=(Join-Path $exeRoot 'games');Depth=6})}
    }
    foreach($root in @(Get-Prop $settings 'libraryRoots' @())){if($root){[void]$roots.Add([pscustomobject]@{Path=[string]$root;Depth=7})}}
    $seen=@{};$count=0
    $gamesYmlPaths=New-Object System.Collections.ArrayList
    if($dataRoot){[void]$gamesYmlPaths.Add((Join-Path $dataRoot 'games.yml'))}
    if($exeRoot -and $exeRoot -ne $dataRoot){[void]$gamesYmlPaths.Add((Join-Path $exeRoot 'games.yml'))}
    foreach($yml in $gamesYmlPaths){
        foreach($entry in @(Get-GamesYmlEntries $yml)){
            $id=([string]$entry.Id).Trim().ToUpperInvariant()
            if($id -and -not $seen.ContainsKey($id)){$seen[$id]=$true;$count++}
        }
    }
    foreach($root in $roots){
        foreach($sfo in @(Find-SfoFiles ([string]$root.Path) ([int]$root.Depth))){
            $id=Get-SfoTitleId $sfo
            if(-not $id){$id=(Split-Path -Leaf (Split-Path -Parent $sfo))}
            $id=([string]$id).Trim().ToUpperInvariant()
            if($id -and -not $seen.ContainsKey($id)){$seen[$id]=$true;$count++}
        }
    }
    Write-AtomicJson $ResultPath ([pscustomobject]@{Count=$count;DataRoot=$dataRoot;UpdatedAt=(Get-Date).ToString('o');Error=''})
}catch{
    try{Write-AtomicJson $ResultPath ([pscustomobject]@{Count=0;DataRoot='';UpdatedAt=(Get-Date).ToString('o');Error=$_.Exception.Message})}catch{}
    exit 1
}
