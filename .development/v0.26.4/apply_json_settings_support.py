from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
path=ROOT/'HuymaierEmulatorSettings.ps1'
text=path.read_text(encoding='utf-8-sig')

functions=r'''
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

'''
anchor='function Get-HcEmulatorConfigSettings {'
if 'function Get-HcJsonSettings {' not in text:
    if text.count(anchor)!=1:raise SystemExit('JSON settings function insertion anchor missing')
    text=text.replace(anchor,functions+anchor,1)

old="if($ext -in @('.ini','.cfg')){$Format='ini'}elseif($ext -in @('.yml','.yaml')){$Format='yaml'}elseif($ext -eq '.bml'){$Format='bml'}else{$Format='key-value'}"
new="if($ext -in @('.ini','.cfg')){$Format='ini'}elseif($ext -in @('.yml','.yaml')){$Format='yaml'}elseif($ext -eq '.json'){$Format='json'}elseif($ext -eq '.bml'){$Format='bml'}else{$Format='key-value'}"
if old in text:text=text.replace(old,new,1)
elif "elseif($ext -eq '.json'){$Format='json'}" not in text:raise SystemExit('JSON format detection anchor missing')

old="        'yaml' { return [object[]](Get-HcYamlScalarSettings -Path $Path -AdapterId $AdapterId) }\n        'bml' { return [object[]](Get-HcBmlScalarSettings -Path $Path -AdapterId $AdapterId) }"
new="        'yaml' { return [object[]](Get-HcYamlScalarSettings -Path $Path -AdapterId $AdapterId) }\n        'json' { return [object[]](Get-HcJsonSettings -Path $Path -AdapterId $AdapterId) }\n        'bml' { return [object[]](Get-HcBmlScalarSettings -Path $Path -AdapterId $AdapterId) }"
if old in text:text=text.replace(old,new,1)
elif "'json' { return [object[]](Get-HcJsonSettings" not in text:raise SystemExit('JSON inventory switch anchor missing')

old="        'yaml' { Set-HcYamlScalarSetting -Path $path -LineIndex $line -Key $key -Value $Value -AdapterId $adapter }\n        'bml' { Set-HcBmlScalarSetting -Path $path -LineIndex $line -Key $key -Value $Value -AdapterId $adapter }"
new="        'yaml' { Set-HcYamlScalarSetting -Path $path -LineIndex $line -Key $key -Value $Value -AdapterId $adapter }\n        'json' { Set-HcJsonSetting -Path $path -Section $section -Key $key -Value $Value -AdapterId $adapter }\n        'bml' { Set-HcBmlScalarSetting -Path $path -LineIndex $line -Key $key -Value $Value -AdapterId $adapter }"
if old in text:text=text.replace(old,new,1)
elif "'json' { Set-HcJsonSetting" not in text:raise SystemExit('JSON writer switch anchor missing')

path.write_text(text,encoding='utf-8')
print('materialized unknown-key-preserving JSON emulator config support')
