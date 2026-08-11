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
        Write-Log "Could not back up emulator config ${Path}: $($_.Exception.Message)" 'WARN'
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


function Convert-HcJsonValueToDisplayText {
    param($Value)
    if($null -eq $Value){return 'null'}
    if($Value -is [bool]){return $(if($Value){'true'}else{'false'})}
    if($Value -is [string]){return [string]$Value}
    if($Value -is [ValueType]){return [Convert]::ToString($Value,[Globalization.CultureInfo]::InvariantCulture)}
    try{return ($Value|ConvertTo-Json -Depth 50 -Compress)}catch{return [string]$Value}
}

function Add-HcJsonSettingRecords {
    param($Node,[string]$Path,[string]$FilePath,[string]$AdapterId,[Collections.ArrayList]$Result)
    if($null -eq $Node){return}
    if($Node -is [Collections.IDictionary]){
        foreach($keyValue in @($Node.Keys)){
            $key=[string]$keyValue;$value=$Node[$keyValue]
            if($null -eq $value -or $value -is [string] -or $value -is [ValueType] -or $value -is [array] -or $value -is [Collections.IList]){
                [void]$Result.Add((New-HcEmulatorSettingRecord -Format 'json' -FilePath $FilePath -Section $Path -Key $key -Value (Convert-HcJsonValueToDisplayText $value) -LineIndex -1 -AdapterId $AdapterId))
            }else{
                Add-HcJsonSettingRecords -Node $value -Path $(if($Path){$Path+' / '+$key}else{$key}) -FilePath $FilePath -AdapterId $AdapterId -Result $Result
            }
        }
        return
    }
    $properties=@($Node.PSObject.Properties|Where-Object{$_ -and $_.MemberType -match 'Property'})
    foreach($property in $properties){
        $key=[string]$property.Name;$value=$property.Value
        if($null -eq $value -or $value -is [string] -or $value -is [ValueType] -or $value -is [array] -or $value -is [Collections.IList]){
            [void]$Result.Add((New-HcEmulatorSettingRecord -Format 'json' -FilePath $FilePath -Section $Path -Key $key -Value (Convert-HcJsonValueToDisplayText $value) -LineIndex -1 -AdapterId $AdapterId))
        }else{
            Add-HcJsonSettingRecords -Node $value -Path $(if($Path){$Path+' / '+$key}else{$key}) -FilePath $FilePath -AdapterId $AdapterId -Result $Result
        }
    }
}



function Get-HcXmlNodePath {
    param([Xml.XmlNode]$Node)
    if($null -eq $Node -or $Node.NodeType -eq [Xml.XmlNodeType]::Document){return ''}
    $parent=$Node.ParentNode;$segment=$Node.Name
    if($null -ne $parent){$same=@($parent.ChildNodes|Where-Object{$_.NodeType -eq [Xml.XmlNodeType]::Element -and $_.Name -eq $Node.Name});if($same.Count -gt 1){$index=1;foreach($candidate in $same){if([object]::ReferenceEquals($candidate,$Node)){break};$index++};$segment+="[$index]"}}
    $base=Get-HcXmlNodePath $parent
    return $(if($base){$base+'/'+$segment}else{'/'+$segment})
}
function Add-HcXmlSettingRecords {
    param([Xml.XmlNode]$Node,[string]$FilePath,[string]$AdapterId,[Collections.ArrayList]$Result)
    if($null -eq $Node){return}
    if($Node.NodeType -eq [Xml.XmlNodeType]::Element){
        $nodePath=Get-HcXmlNodePath $Node
        foreach($attribute in @($Node.Attributes)){[void]$Result.Add((New-HcEmulatorSettingRecord -Format 'xml' -FilePath $FilePath -Section $nodePath -Key ('@'+$attribute.Name) -Value ([string]$attribute.Value) -LineIndex -1 -AdapterId $AdapterId))}
        $elementChildren=@($Node.ChildNodes|Where-Object{$_.NodeType -eq [Xml.XmlNodeType]::Element})
        if($elementChildren.Count -eq 0){$value=[string]$Node.InnerText;[void]$Result.Add((New-HcEmulatorSettingRecord -Format 'xml' -FilePath $FilePath -Section $nodePath -Key '#text' -Value $value -LineIndex -1 -AdapterId $AdapterId))}
    }
    foreach($child in @($Node.ChildNodes)){if($child.NodeType -eq [Xml.XmlNodeType]::Element){Add-HcXmlSettingRecords -Node $child -FilePath $FilePath -AdapterId $AdapterId -Result $Result}}
}
function Get-HcXmlSettings {
    param([Parameter(Mandatory=$true)][string]$Path,[string]$AdapterId='')
    if(-not(Test-Path -LiteralPath $Path -PathType Leaf)){return [object[]]@()}
    try{$doc=New-Object Xml.XmlDocument;$doc.PreserveWhitespace=$true;$doc.Load($Path)}catch{Write-Log "Could not parse XML emulator config ${Path}: $($_.Exception.Message)" 'WARN';return [object[]]@()}
    $result=New-Object Collections.ArrayList;Add-HcXmlSettingRecords -Node $doc.DocumentElement -FilePath $Path -AdapterId $AdapterId -Result $result;return [object[]]$result.ToArray()
}
function Set-HcXmlSetting {
    param([Parameter(Mandatory=$true)][string]$Path,[Parameter(Mandatory=$true)][string]$Section,[Parameter(Mandatory=$true)][string]$Key,[AllowEmptyString()][string]$Value,[string]$AdapterId='')
    if(-not(Test-Path -LiteralPath $Path -PathType Leaf)){throw "XML emulator config file was not found: $Path"};[void](Backup-HcEmulatorConfigFile -Path $Path -AdapterId $AdapterId)
    $doc=New-Object Xml.XmlDocument;$doc.PreserveWhitespace=$true;$doc.Load($Path);$node=$doc.SelectSingleNode($Section);if($null -eq $node){throw "XML setting path no longer exists: $Section"}
    if($Key -eq '#text'){$node.InnerText=$Value}elseif($Key.StartsWith('@')){$name=$Key.Substring(1);$attribute=$node.Attributes[$name];if($null -eq $attribute){throw "XML attribute no longer exists: $Key"};$attribute.Value=$Value}else{throw "Unsupported XML setting key: $Key"}
    $encoding=Get-HcSettingsFileEncoding $Path;$settings=New-Object Xml.XmlWriterSettings;$settings.Indent=$false;$settings.OmitXmlDeclaration=$false;$settings.Encoding=$encoding;$writer=[Xml.XmlWriter]::Create($Path,$settings);try{$doc.Save($writer)}finally{$writer.Close()}
}

function Get-HcTomlScalarSettings {
    param([Parameter(Mandatory=$true)][string]$Path,[string]$AdapterId='')
    $lines=Get-HcSettingsFileLines $Path;if($lines.Count -eq 0){return [object[]]@()};$result=New-Object Collections.ArrayList;$section=''
    for($i=0;$i -lt $lines.Count;$i++){$line=[string]$lines[$i];$trim=$line.Trim();if(-not $trim -or $trim.StartsWith('#')){continue};if($trim -match '^\[(?<section>[^\]]+)\]\s*(?:#.*)?$'){$section=$matches['section'].Trim();continue};$m=[regex]::Match($line,'^\s*(?<key>[A-Za-z0-9_.-]+)\s*=\s*(?<value>.*?)(?:\s+#.*)?$');if($m.Success){[void]$result.Add((New-HcEmulatorSettingRecord -Format 'toml' -FilePath $Path -Section $section -Key $m.Groups['key'].Value -Value $m.Groups['value'].Value.Trim() -LineIndex $i -AdapterId $AdapterId))}}
    return [object[]]$result.ToArray()
}
function Set-HcTomlScalarSetting {
    param([Parameter(Mandatory=$true)][string]$Path,[Parameter(Mandatory=$true)][int]$LineIndex,[Parameter(Mandatory=$true)][string]$Key,[AllowEmptyString()][string]$Value,[string]$AdapterId='')
    $lines=Get-HcSettingsFileLines $Path;if($LineIndex -lt 0 -or $LineIndex -ge $lines.Count){throw "TOML setting index is out of range: $LineIndex"};$line=[string]$lines[$LineIndex];$pattern='^(?<prefix>\s*'+[regex]::Escape($Key)+'\s*=\s*)(?<value>.*?)(?<comment>\s+#.*)?$';$m=[regex]::Match($line,$pattern);if(-not $m.Success){throw "TOML setting no longer matches expected key: $Key"};[void](Backup-HcEmulatorConfigFile -Path $Path -AdapterId $AdapterId);$lines[$LineIndex]=$m.Groups['prefix'].Value+$Value+$m.Groups['comment'].Value;Write-HcSettingsFileLines -Path $Path -Lines $lines
}

function Get-HcJsonSettings {
    param([Parameter(Mandatory=$true)][string]$Path,[string]$AdapterId='')
    if(-not(Test-Path -LiteralPath $Path -PathType Leaf)){return [object[]]@()}
    try{$root=Get-Content -Raw -LiteralPath $Path -Encoding UTF8|ConvertFrom-Json}catch{Write-Log "Could not parse JSON emulator config ${Path}: $($_.Exception.Message)" 'WARN';return [object[]]@()}
    $result=New-Object Collections.ArrayList
    Add-HcJsonSettingRecords -Node $root -Path '' -FilePath $Path -AdapterId $AdapterId -Result $result
    return [object[]]$result.ToArray()
}

function Convert-HcJsonEditedValue {
    param([AllowEmptyString()][string]$Text,$Existing)
    $trim=([string]$Text).Trim()
    if($null -eq $Existing){if($trim -eq 'null'){return $null};return [string]$Text}
    if($Existing -is [bool]){if($trim -match '^(?i:true|1|yes|on|enabled)$'){return $true};if($trim -match '^(?i:false|0|no|off|disabled)$'){return $false};throw 'This JSON setting requires a boolean value.'}
    if($Existing -is [byte] -or $Existing -is [int16] -or $Existing -is [int32] -or $Existing -is [int64] -or $Existing -is [uint16] -or $Existing -is [uint32] -or $Existing -is [uint64]){
        $number=0L;if(-not [int64]::TryParse($trim,[Globalization.NumberStyles]::Integer,[Globalization.CultureInfo]::InvariantCulture,[ref]$number)){throw 'This JSON setting requires an integer value.'};return $number
    }
    if($Existing -is [single] -or $Existing -is [double] -or $Existing -is [decimal]){
        $number=0.0;if(-not [double]::TryParse($trim,[Globalization.NumberStyles]::Float,[Globalization.CultureInfo]::InvariantCulture,[ref]$number)){throw 'This JSON setting requires a numeric value.'};return $number
    }
    if($Existing -is [array] -or $Existing -is [Collections.IList] -or $Existing -is [Collections.IDictionary]){try{return ($trim|ConvertFrom-Json)}catch{throw 'This JSON collection requires valid JSON syntax.'}}
    return [string]$Text
}

function Set-HcJsonSetting {
    param([Parameter(Mandatory=$true)][string]$Path,[string]$Section,[Parameter(Mandatory=$true)][string]$Key,[AllowEmptyString()][string]$Value,[string]$AdapterId='')
    if(-not(Test-Path -LiteralPath $Path -PathType Leaf)){throw "Emulator config file was not found: $Path"}
    [void](Backup-HcEmulatorConfigFile -Path $Path -AdapterId $AdapterId)
    $root=Get-Content -Raw -LiteralPath $Path -Encoding UTF8|ConvertFrom-Json
    $node=$root
    foreach($segment in @(([string]$Section -split '\s*/\s*')|Where-Object{$_})){
        if($node -is [Collections.IDictionary]){if(-not $node.Contains($segment)){throw "JSON setting path no longer exists: $Section"};$node=$node[$segment]}
        else{$property=$node.PSObject.Properties[$segment];if($null -eq $property){throw "JSON setting path no longer exists: $Section"};$node=$property.Value}
    }
    if($node -is [Collections.IDictionary]){
        if(-not $node.Contains($Key)){throw "JSON setting no longer exists: $Key"};$existing=$node[$Key];$node[$Key]=Convert-HcJsonEditedValue -Text $Value -Existing $existing
    }else{
        $property=$node.PSObject.Properties[$Key];if($null -eq $property){throw "JSON setting no longer exists: $Key"};$property.Value=Convert-HcJsonEditedValue -Text $Value -Existing $property.Value
    }
    $encoding=Get-HcSettingsFileEncoding $Path
    [IO.File]::WriteAllText($Path,(($root|ConvertTo-Json -Depth 100)+[Environment]::NewLine),$encoding)
}

function Get-HcEmulatorConfigSettings {
    param([Parameter(Mandatory=$true)][string]$AdapterId,[Parameter(Mandatory=$true)][string]$Path,[string]$Format='')
    if(-not $Format){
        $ext=[IO.Path]::GetExtension($Path).ToLowerInvariant()
        if($ext -in @('.ini','.cfg')){$Format='ini'}elseif($ext -in @('.yml','.yaml')){$Format='yaml'}elseif($ext -eq '.json'){$Format='json'}elseif($ext -eq '.toml'){$Format='toml'}elseif($ext -eq '.xml'){$Format='xml'}elseif($ext -eq '.bml'){$Format='bml'}else{$Format='key-value'}
        if($AdapterId -ieq 'mednafen'){$Format='key-value'}
        if($AdapterId -ieq 'bigpemu' -and $ext -ieq '.bigpcfg'){$Format='json'}
        if($AdapterId -ieq 'ares'){$Format='bml'}
    }
    switch($Format.ToLowerInvariant()){
        'ini' { return [object[]](Get-HcIniSettings -Path $Path -AdapterId $AdapterId) }
        'yaml' { return [object[]](Get-HcYamlScalarSettings -Path $Path -AdapterId $AdapterId) }
        'json' { return [object[]](Get-HcJsonSettings -Path $Path -AdapterId $AdapterId) }
        'toml' { return [object[]](Get-HcTomlScalarSettings -Path $Path -AdapterId $AdapterId) }
        'xml' { return [object[]](Get-HcXmlSettings -Path $Path -AdapterId $AdapterId) }
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
        'json' { Set-HcJsonSetting -Path $path -Section $section -Key $key -Value $Value -AdapterId $adapter }
        'toml' { Set-HcTomlScalarSetting -Path $path -LineIndex $line -Key $key -Value $Value -AdapterId $adapter }
        'xml' { Set-HcXmlSetting -Path $path -Section $section -Key $key -Value $Value -AdapterId $adapter }
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
