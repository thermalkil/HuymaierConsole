# Huymaier Console native emulator-settings adapter core.
#
# Design goals:
# - Every meaningful emulator setting can be surfaced inside Huymaier Console.
# - Editing one setting must not rewrite a backend config from a reduced schema.
# - Unknown/new emulator keys, comments, ordering and unrelated sections survive edits.
# - Curated console-specific settings pages can sit on top of the complete raw setting
#   inventory, so advanced/new backend keys never become unreachable.

$script:HcEmulatorAdapterRegistryPath = Join-Path $script:BaseDir 'EmulatorPlatforms\emulator-adapters.json'
$script:HcEmulatorAdapterRegistryCache = $null
$script:HcEmulatorAdapterRegistryStamp = [datetime]::MinValue

function Read-HcEmulatorAdapterRegistry {
    if(-not(Test-Path -LiteralPath $script:HcEmulatorAdapterRegistryPath -PathType Leaf)){
        return [pscustomobject]@{schemaVersion=1;policy=[pscustomobject]@{};adapters=@()}
    }
    try{
        $stamp=(Get-Item -LiteralPath $script:HcEmulatorAdapterRegistryPath -ErrorAction Stop).LastWriteTimeUtc
        if($null -eq $script:HcEmulatorAdapterRegistryCache -or $stamp -ne $script:HcEmulatorAdapterRegistryStamp){
            $script:HcEmulatorAdapterRegistryCache=Get-Content -Raw -LiteralPath $script:HcEmulatorAdapterRegistryPath -Encoding UTF8|ConvertFrom-Json
            $script:HcEmulatorAdapterRegistryStamp=$stamp
        }
        return $script:HcEmulatorAdapterRegistryCache
    }catch{
        Write-Log "Emulator adapter registry could not be read: $($_.Exception.Message)" 'ERROR'
        return [pscustomobject]@{schemaVersion=1;policy=[pscustomobject]@{};adapters=@()}
    }
}

function Get-HcEmulatorAdapter {
    param([Parameter(Mandatory=$true)][string]$AdapterId)
    $registry=Read-HcEmulatorAdapterRegistry
    foreach($adapter in @((Get-EntryProperty $registry 'adapters' @()))){
        if([string]::Equals([string](Get-EntryProperty $adapter 'id' ''),$AdapterId,[StringComparison]::OrdinalIgnoreCase)){return $adapter}
        if([string]::Equals([string](Get-EntryProperty $adapter 'displayName' ''),$AdapterId,[StringComparison]::OrdinalIgnoreCase)){return $adapter}
    }
    return $null
}

function Get-HcEmulatorAdapterEntries {
    $registry=Read-HcEmulatorAdapterRegistry
    return [object[]]@((Get-EntryProperty $registry 'adapters' @()))
}

function Get-HcSettingsFileEncoding {
    param([Parameter(Mandatory=$true)][string]$Path)
    try{
        $bytes=[IO.File]::ReadAllBytes($Path)
        if($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF){return New-Object Text.UTF8Encoding($true)}
        if($bytes.Length -ge 2 -and $bytes[0] -eq 0xFF -and $bytes[1] -eq 0xFE){return [Text.Encoding]::Unicode}
        if($bytes.Length -ge 2 -and $bytes[0] -eq 0xFE -and $bytes[1] -eq 0xFF){return [Text.Encoding]::BigEndianUnicode}
    }catch{}
    return New-Object Text.UTF8Encoding($false)
}

function Backup-HcEmulatorConfigFile {
    param([Parameter(Mandatory=$true)][string]$Path,[string]$AdapterId='emulator')
    if(-not(Test-Path -LiteralPath $Path -PathType Leaf)){return ''}
    try{
        $root=Join-Path $env:LOCALAPPDATA 'Huymaier Console\EmulatorPlatforms\ConfigBackups'
        $safe=([string]$AdapterId -replace '[^A-Za-z0-9_.-]','_')
        $stamp=Get-Date -Format 'yyyyMMdd-HHmmss-fff'
        $folder=Join-Path (Join-Path $root $safe) $stamp
        New-Item -ItemType Directory -Force -Path $folder|Out-Null
        $name=[IO.Path]::GetFileName($Path)
        $target=Join-Path $folder $name
        Copy-Item -LiteralPath $Path -Destination $target -Force
        return $target
    }catch{
        Write-Log "Could not back up emulator config $Path: $($_.Exception.Message)" 'WARN'
        return ''
    }
}

function New-HcEmulatorSettingRecord {
    param(
        [string]$Format,[string]$FilePath,[string]$Section,[string]$Key,[string]$Value,
        [int]$LineIndex=-1,[string]$AdapterId='',[string]$Category='Advanced'
    )
    [pscustomobject]@{
        AdapterId=$AdapterId
        Format=$Format
        FilePath=$FilePath
        Section=$Section
        Key=$Key
        Value=$Value
        LineIndex=$LineIndex
        Category=$Category
        Identity=("{0}|{1}|{2}|{3}" -f $Format,$FilePath,$Section,$Key)
        DisplayName=$(if([string]::IsNullOrWhiteSpace($Section)){$Key}else{"$Section / $Key"})
    }
}

function Get-HcIniSettings {
    param([Parameter(Mandatory=$true)][string]$Path,[string]$AdapterId='')
    $result=New-Object System.Collections.ArrayList
    if(-not(Test-Path -LiteralPath $Path -PathType Leaf)){return [object[]]@()}
    $section=''
    $lines=[IO.File]::ReadAllLines($Path,(Get-HcSettingsFileEncoding $Path))
    for($i=0;$i -lt $lines.Length;$i++){
        $raw=[string]$lines[$i];$trim=$raw.Trim()
        if($trim -match '^\[([^\]]+)\]\s*$'){$section=$matches[1].Trim();continue}
        if(-not $trim -or $trim.StartsWith(';') -or $trim.StartsWith('#')){continue}
        $match=[regex]::Match($raw,'^\s*([^=:#][^=:]*?)\s*=\s*(.*?)\s*$')
        if(-not $match.Success){$match=[regex]::Match($raw,'^\s*([^=:#][^=:]*?)\s*:\s*(.*?)\s*$')}
        if($match.Success){
            [void]$result.Add((New-HcEmulatorSettingRecord -Format 'ini' -FilePath $Path -Section $section -Key $match.Groups[1].Value.Trim() -Value $match.Groups[2].Value -LineIndex $i -AdapterId $AdapterId))
        }
    }
    return [object[]]$result.ToArray()
}

function Set-HcIniSetting {
    param(
        [Parameter(Mandatory=$true)][string]$Path,[string]$Section,
        [Parameter(Mandatory=$true)][string]$Key,[AllowEmptyString()][string]$Value,[string]$AdapterId=''
    )
    if(-not(Test-Path -LiteralPath $Path -PathType Leaf)){throw "Emulator config file was not found: $Path"}
    [void](Backup-HcEmulatorConfigFile -Path $Path -AdapterId $AdapterId)
    $encoding=Get-HcSettingsFileEncoding $Path
    $lines=New-Object System.Collections.ArrayList
    foreach($line in [IO.File]::ReadAllLines($Path,$encoding)){[void]$lines.Add([string]$line)}
    $active='';$targetIndex=-1;$sectionIndex=-1;$nextSectionIndex=$lines.Count
    for($i=0;$i -lt $lines.Count;$i++){
        $raw=[string]$lines[$i];$trim=$raw.Trim()
        if($trim -match '^\[([^\]]+)\]\s*$'){
            $active=$matches[1].Trim()
            if([string]::Equals($active,[string]$Section,[StringComparison]::OrdinalIgnoreCase)){$sectionIndex=$i;$nextSectionIndex=$lines.Count}
            elseif($sectionIndex -ge 0 -and $nextSectionIndex -eq $lines.Count){$nextSectionIndex=$i}
            continue
        }
        if(-not [string]::Equals($active,[string]$Section,[StringComparison]::OrdinalIgnoreCase)){continue}
        $match=[regex]::Match($raw,'^(\s*)([^=:#][^=:]*?)(\s*)(=|:)(\s*)(.*?)(\s*)$')
        if($match.Success -and [string]::Equals($match.Groups[2].Value.Trim(),$Key,[StringComparison]::OrdinalIgnoreCase)){
            $lines[$i]=$match.Groups[1].Value+$match.Groups[2].Value+$match.Groups[3].Value+$match.Groups[4].Value+$match.Groups[5].Value+$Value
            $targetIndex=$i;break
        }
    }
    if($targetIndex -lt 0){
        if([string]::IsNullOrWhiteSpace($Section)){
            $insert=0
            while($insert -lt $lines.Count -and ([string]$lines[$insert]).TrimStart().StartsWith(';')){$insert++}
            $lines.Insert($insert,"$Key = $Value")
        }else{
            if($sectionIndex -lt 0){
                if($lines.Count -gt 0 -and -not [string]::IsNullOrWhiteSpace([string]$lines[$lines.Count-1])){[void]$lines.Add('')}
                [void]$lines.Add("[$Section]");[void]$lines.Add("$Key = $Value")
            }else{
                $lines.Insert($nextSectionIndex,"$Key = $Value")
            }
        }
    }
    [IO.File]::WriteAllLines($Path,[string[]]$lines.ToArray([string]),$encoding)
}

function Get-HcKeyValueSettings {
    param([Parameter(Mandatory=$true)][string]$Path,[string]$AdapterId='')
    $result=New-Object System.Collections.ArrayList
    if(-not(Test-Path -LiteralPath $Path -PathType Leaf)){return [object[]]@()}
    $lines=[IO.File]::ReadAllLines($Path,(Get-HcSettingsFileEncoding $Path))
    for($i=0;$i -lt $lines.Length;$i++){
        $raw=[string]$lines[$i];$trim=$raw.Trim()
        if(-not $trim -or $trim.StartsWith(';') -or $trim.StartsWith('#')){continue}
        $match=[regex]::Match($raw,'^\s*([^\s=]+)\s+(.*?)\s*$')
        if(-not $match.Success){$match=[regex]::Match($raw,'^\s*([^=]+?)\s*=\s*(.*?)\s*$')}
        if($match.Success){[void]$result.Add((New-HcEmulatorSettingRecord -Format 'key-value' -FilePath $Path -Key $match.Groups[1].Value.Trim() -Value $match.Groups[2].Value -LineIndex $i -AdapterId $AdapterId))}
    }
    return [object[]]$result.ToArray()
}

function Set-HcKeyValueSetting {
    param([Parameter(Mandatory=$true)][string]$Path,[Parameter(Mandatory=$true)][string]$Key,[AllowEmptyString()][string]$Value,[string]$AdapterId='')
    if(-not(Test-Path -LiteralPath $Path -PathType Leaf)){throw "Emulator config file was not found: $Path"}
    [void](Backup-HcEmulatorConfigFile -Path $Path -AdapterId $AdapterId)
    $encoding=Get-HcSettingsFileEncoding $Path
    $lines=New-Object System.Collections.ArrayList
    foreach($line in [IO.File]::ReadAllLines($Path,$encoding)){[void]$lines.Add([string]$line)}
    $updated=$false
    for($i=0;$i -lt $lines.Count;$i++){
        $raw=[string]$lines[$i]
        $match=[regex]::Match($raw,'^(\s*)([^\s=]+)(\s+)(.*?)(\s*)$')
        if($match.Success -and [string]::Equals($match.Groups[2].Value,$Key,[StringComparison]::OrdinalIgnoreCase)){
            $lines[$i]=$match.Groups[1].Value+$match.Groups[2].Value+$match.Groups[3].Value+$Value;$updated=$true;break
        }
        $match=[regex]::Match($raw,'^(\s*)([^=]+?)(\s*=\s*)(.*?)(\s*)$')
        if($match.Success -and [string]::Equals($match.Groups[2].Value.Trim(),$Key,[StringComparison]::OrdinalIgnoreCase)){
            $lines[$i]=$match.Groups[1].Value+$match.Groups[2].Value+$match.Groups[3].Value+$Value;$updated=$true;break
        }
    }
    if(-not $updated){[void]$lines.Add("$Key $Value")}
    [IO.File]::WriteAllLines($Path,[string[]]$lines.ToArray([string]),$encoding)
}

function Get-HcYamlScalarSettings {
    param([Parameter(Mandatory=$true)][string]$Path,[string]$AdapterId='')
    $result=New-Object System.Collections.ArrayList
    if(-not(Test-Path -LiteralPath $Path -PathType Leaf)){return [object[]]@()}
    $stack=@();$lines=[IO.File]::ReadAllLines($Path,(Get-HcSettingsFileEncoding $Path))
    for($i=0;$i -lt $lines.Length;$i++){
        $raw=[string]$lines[$i];$trim=$raw.Trim()
        if(-not $trim -or $trim.StartsWith('#') -or $trim.StartsWith('- ')){continue}
        $m=[regex]::Match($raw,'^(\s*)([^:#][^:]*?):\s*(.*?)\s*$')
        if(-not $m.Success){continue}
        $indent=$m.Groups[1].Value.Length;$key=$m.Groups[2].Value.Trim();$value=$m.Groups[3].Value
        while($stack.Count -gt 0 -and [int]$stack[$stack.Count-1].Indent -ge $indent){if($stack.Count -eq 1){$stack=@()}else{$stack=$stack[0..($stack.Count-2)]}}
        if([string]::IsNullOrWhiteSpace($value)){$stack+=,[pscustomobject]@{Indent=$indent;Key=$key};continue}
        $section=($stack|ForEach-Object{$_.Key}) -join ' / '
        [void]$result.Add((New-HcEmulatorSettingRecord -Format 'yaml' -FilePath $Path -Section $section -Key $key -Value $value -LineIndex $i -AdapterId $AdapterId))
    }
    return [object[]]$result.ToArray()
}

function Set-HcYamlScalarSetting {
    param([Parameter(Mandatory=$true)][string]$Path,[Parameter(Mandatory=$true)][int]$LineIndex,[Parameter(Mandatory=$true)][string]$Key,[AllowEmptyString()][string]$Value,[string]$AdapterId='')
    if(-not(Test-Path -LiteralPath $Path -PathType Leaf)){throw "Emulator config file was not found: $Path"}
    [void](Backup-HcEmulatorConfigFile -Path $Path -AdapterId $AdapterId)
    $encoding=Get-HcSettingsFileEncoding $Path;$lines=[IO.File]::ReadAllLines($Path,$encoding)
    if($LineIndex -lt 0 -or $LineIndex -ge $lines.Length){throw 'YAML setting location is no longer valid. Refresh the settings page.'}
    $m=[regex]::Match([string]$lines[$LineIndex],'^(\s*)([^:#][^:]*?)(:\s*)(.*?)(\s*)$')
    if(-not $m.Success -or -not [string]::Equals($m.Groups[2].Value.Trim(),$Key,[StringComparison]::Ordinal)){throw 'YAML setting changed externally. Refresh the settings page.'}
    $lines[$LineIndex]=$m.Groups[1].Value+$m.Groups[2].Value+$m.Groups[3].Value+$Value
    [IO.File]::WriteAllLines($Path,$lines,$encoding)
}

function Get-HcBmlScalarSettings {
    param([Parameter(Mandatory=$true)][string]$Path,[string]$AdapterId='')
    $result=New-Object System.Collections.ArrayList
    if(-not(Test-Path -LiteralPath $Path -PathType Leaf)){return [object[]]@()}
    $stack=@();$lines=[IO.File]::ReadAllLines($Path,(Get-HcSettingsFileEncoding $Path))
    for($i=0;$i -lt $lines.Length;$i++){
        $raw=[string]$lines[$i];$trim=$raw.Trim()
        if(-not $trim -or $trim.StartsWith('//') -or $trim.StartsWith('#')){continue}
        $indent=$raw.Length-$raw.TrimStart().Length
        while($stack.Count -gt 0 -and [int]$stack[$stack.Count-1].Indent -ge $indent){if($stack.Count -eq 1){$stack=@()}else{$stack=$stack[0..($stack.Count-2)]}}
        $m=[regex]::Match($trim,'^([^:]+):\s*(.*)$')
        if($m.Success){
            $key=$m.Groups[1].Value.Trim();$value=$m.Groups[2].Value
            if([string]::IsNullOrWhiteSpace($value)){$stack+=,[pscustomobject]@{Indent=$indent;Key=$key};continue}
            $section=($stack|ForEach-Object{$_.Key}) -join ' / '
            [void]$result.Add((New-HcEmulatorSettingRecord -Format 'bml' -FilePath $Path -Section $section -Key $key -Value $value -LineIndex $i -AdapterId $AdapterId))
        }
    }
    return [object[]]$result.ToArray()
}

function Set-HcBmlScalarSetting {
    param([Parameter(Mandatory=$true)][string]$Path,[Parameter(Mandatory=$true)][int]$LineIndex,[Parameter(Mandatory=$true)][string]$Key,[AllowEmptyString()][string]$Value,[string]$AdapterId='')
    if(-not(Test-Path -LiteralPath $Path -PathType Leaf)){throw "Emulator config file was not found: $Path"}
    [void](Backup-HcEmulatorConfigFile -Path $Path -AdapterId $AdapterId)
    $encoding=Get-HcSettingsFileEncoding $Path;$lines=[IO.File]::ReadAllLines($Path,$encoding)
    if($LineIndex -lt 0 -or $LineIndex -ge $lines.Length){throw 'BML setting location is no longer valid. Refresh the settings page.'}
    $m=[regex]::Match([string]$lines[$LineIndex],'^(\s*)([^:]+?)(:\s*)(.*?)(\s*)$')
    if(-not $m.Success -or -not [string]::Equals($m.Groups[2].Value.Trim(),$Key,[StringComparison]::Ordinal)){throw 'BML setting changed externally. Refresh the settings page.'}
    $lines[$LineIndex]=$m.Groups[1].Value+$m.Groups[2].Value+$m.Groups[3].Value+$Value
    [IO.File]::WriteAllLines($Path,$lines,$encoding)
}

function Get-HcEmulatorConfigSettings {
    param([Parameter(Mandatory=$true)][string]$AdapterId,[Parameter(Mandatory=$true)][string]$Path,[string]$Format='')
    if(-not $Format){
        $ext=[IO.Path]::GetExtension($Path).ToLowerInvariant()
        if($ext -in @('.ini','.cfg')){$Format='ini'}elseif($ext -in @('.yml','.yaml')){$Format='yaml'}elseif($ext -eq '.bml'){$Format='bml'}else{$Format='key-value'}
        if($AdapterId -ieq 'mednafen'){$Format='key-value'}
        if($AdapterId -ieq 'ares'){$Format='bml'}
    }
    switch($Format.ToLowerInvariant()){
        'ini' { return [object[]](Get-HcIniSettings -Path $Path -AdapterId $AdapterId) }
        'yaml' { return [object[]](Get-HcYamlScalarSettings -Path $Path -AdapterId $AdapterId) }
        'bml' { return [object[]](Get-HcBmlScalarSettings -Path $Path -AdapterId $AdapterId) }
        default { return [object[]](Get-HcKeyValueSettings -Path $Path -AdapterId $AdapterId) }
    }
}

function Set-HcEmulatorConfigSetting {
    param([Parameter(Mandatory=$true)]$Setting,[Parameter(Mandatory=$true)][AllowEmptyString()][string]$Value)
    $format=[string](Get-EntryProperty $Setting 'Format' '')
    $path=[string](Get-EntryProperty $Setting 'FilePath' '')
    $adapter=[string](Get-EntryProperty $Setting 'AdapterId' '')
    $key=[string](Get-EntryProperty $Setting 'Key' '')
    $section=[string](Get-EntryProperty $Setting 'Section' '')
    $line=[int](Get-EntryProperty $Setting 'LineIndex' -1)
    switch($format.ToLowerInvariant()){
        'ini' { Set-HcIniSetting -Path $path -Section $section -Key $key -Value $Value -AdapterId $adapter }
        'yaml' { Set-HcYamlScalarSetting -Path $path -LineIndex $line -Key $key -Value $Value -AdapterId $adapter }
        'bml' { Set-HcBmlScalarSetting -Path $path -LineIndex $line -Key $key -Value $Value -AdapterId $adapter }
        'key-value' { Set-HcKeyValueSetting -Path $path -Key $key -Value $Value -AdapterId $adapter }
        default { throw "Unsupported emulator config format: $format" }
    }
}

function Resolve-HcAdapterConfigFiles {
    param([Parameter(Mandatory=$true)][string]$AdapterId,[string[]]$Roots=@())
    $adapter=Get-HcEmulatorAdapter $AdapterId
    if($null -eq $adapter){return [string[]]@()}
    $found=New-Object System.Collections.ArrayList
    $seen=@{}
    $patterns=@((Get-EntryProperty $adapter 'configFiles' @()))
    foreach($rootValue in @($Roots)){
        $root=[Environment]::ExpandEnvironmentVariables([string]$rootValue)
        if([string]::IsNullOrWhiteSpace($root)){continue}
        if(Test-Path -LiteralPath $root -PathType Leaf){$root=Split-Path -Parent $root}
        if(-not(Test-Path -LiteralPath $root -PathType Container)){continue}
        foreach($patternValue in $patterns){
            $pattern=[string]$patternValue
            if($pattern -match '[<>]'){continue}
            $candidate=Join-Path $root $pattern
            try{
                $matches=if($pattern.IndexOfAny([char[]]'*?') -ge 0){Get-ChildItem -Path $candidate -File -ErrorAction SilentlyContinue}else{Get-Item -LiteralPath $candidate -ErrorAction SilentlyContinue}
                foreach($item in @($matches)){
                    if($null -eq $item -or -not $item.FullName){continue}
                    $key=$item.FullName.ToLowerInvariant()
                    if(-not $seen.ContainsKey($key)){$seen[$key]=$true;[void]$found.Add($item.FullName)}
                }
            }catch{}
        }
    }
    return [string[]]$found.ToArray([string])
}

function Get-HcCompleteEmulatorSettingsInventory {
    param([Parameter(Mandatory=$true)][string]$AdapterId,[string[]]$ConfigFiles=@())
    $all=New-Object System.Collections.ArrayList
    foreach($path in @($ConfigFiles)){
        if(-not(Test-Path -LiteralPath $path -PathType Leaf)){continue}
        foreach($setting in @(Get-HcEmulatorConfigSettings -AdapterId $AdapterId -Path $path)){[void]$all.Add($setting)}
    }
    return [object[]]$all.ToArray()
}
