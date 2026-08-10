from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
path=ROOT/'HuymaierEmulatorSettings.ps1';text=path.read_text(encoding='utf-8-sig')
functions=r'''
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

'''
if 'function Get-HcTomlScalarSettings {' not in text:
    anchor='function Get-HcJsonSettings {'
    if text.count(anchor)!=1:raise SystemExit('TOML insertion anchor missing')
    text=text.replace(anchor,functions+anchor,1)
text=text.replace("elseif($ext -eq '.json'){$Format='json'}elseif($ext -eq '.bml')", "elseif($ext -eq '.json'){$Format='json'}elseif($ext -eq '.toml'){$Format='toml'}elseif($ext -eq '.bml')")
if "'toml' { return [object[]](Get-HcTomlScalarSettings" not in text:
    text=text.replace("        'json' { return [object[]](Get-HcJsonSettings -Path $Path -AdapterId $AdapterId) }\n", "        'json' { return [object[]](Get-HcJsonSettings -Path $Path -AdapterId $AdapterId) }\n        'toml' { return [object[]](Get-HcTomlScalarSettings -Path $Path -AdapterId $AdapterId) }\n",1)
if "'toml' { Set-HcTomlScalarSetting" not in text:
    text=text.replace("        'json' { Set-HcJsonSetting -Path $path -Section $section -Key $key -Value $Value -AdapterId $adapter }\n", "        'json' { Set-HcJsonSetting -Path $path -Section $section -Key $key -Value $Value -AdapterId $adapter }\n        'toml' { Set-HcTomlScalarSetting -Path $path -LineIndex $line -Key $key -Value $Value -AdapterId $adapter }\n",1)
path.write_text(text,encoding='utf-8');print('materialized unknown-key-preserving TOML scalar settings support')
