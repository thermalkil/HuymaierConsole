from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
worker=ROOT/'HuymaierEmulatorSettingsWorker.ps1'
w=worker.read_text(encoding='utf-8-sig')

functions=r'''
function Get-StellaOverridePath {
    $dir=Split-Path -Parent $PlatformSettingsPath
    if([string]::IsNullOrWhiteSpace($dir)){$dir=Join-Path (Join-Path $env:LOCALAPPDATA 'Huymaier Console\EmulatorPlatforms') 'ATARI2600'}
    New-Item -ItemType Directory -Force -Path $dir|Out-Null
    return Join-Path $dir 'stella-command-line-overrides.json'
}

function Read-StellaOverrides {
    $path=Get-StellaOverridePath
    $map=[ordered]@{}
    if(Test-Path -LiteralPath $path -PathType Leaf){
        try{
            $loaded=Get-Content -Raw -LiteralPath $path -Encoding UTF8|ConvertFrom-Json
            foreach($property in @($loaded.PSObject.Properties)){if($null -ne $property){$map[[string]$property.Name]=[string]$property.Value}}
        }catch{}
    }
    return $map
}

function Get-StellaHelpText {
    param($Settings)
    $exe=[string](Get-EntryProperty $Settings 'emulatorPath' '')
    if(-not(Test-Path -LiteralPath $exe -PathType Leaf)){return ''}
    try{
        $psi=New-Object Diagnostics.ProcessStartInfo
        $psi.FileName=$exe;$psi.Arguments='-help';$psi.UseShellExecute=$false;$psi.CreateNoWindow=$true;$psi.RedirectStandardOutput=$true;$psi.RedirectStandardError=$true
        $process=[Diagnostics.Process]::Start($psi)
        if($null -eq $process){return ''}
        $stdout=$process.StandardOutput.ReadToEnd();$stderr=$process.StandardError.ReadToEnd()
        if(-not $process.WaitForExit(6000)){try{$process.Kill()}catch{};return ''}
        return (($stdout+[Environment]::NewLine+$stderr).Trim())
    }catch{return ''}
}

function Get-StellaCliSettings {
    param($Settings)
    $help=Get-StellaHelpText $Settings
    if([string]::IsNullOrWhiteSpace($help)){return [object[]]@()}
    $overrides=Read-StellaOverrides;$overridePath=Get-StellaOverridePath
    $result=New-Object Collections.ArrayList;$seen=@{}
    foreach($line in ($help -split "`r?`n")){
        # Stella's runtime -help is authoritative for the installed version.
        # Only entries with an argument placeholder are persistent settings;
        # action flags such as -help are intentionally omitted.
        $match=[regex]::Match([string]$line,'^\s*-(?<key>[A-Za-z0-9_.-]+)\s+(?<arg><[^>]+>|\[[^\]]+\])(?:\s+(?<desc>.*))?$')
        if(-not $match.Success){continue}
        $key=$match.Groups['key'].Value
        if($seen.ContainsKey($key)){continue};$seen[$key]=$true
        $value='';if($overrides.Contains($key)){$value=[string]$overrides[$key]}
        $record=New-HcEmulatorSettingRecord -Format 'stella-cli' -FilePath $overridePath -Section '' -Key $key -Value $value -LineIndex -1 -AdapterId 'stella'
        $record.DisplayName=('-'+$key+' '+$match.Groups['arg'].Value)
        $record.Category=Get-SettingCategory $record
        [void]$result.Add($record)
    }
    return [object[]]$result.ToArray()
}

function Set-StellaCliOverride {
    param([Parameter(Mandatory=$true)][string]$Key,[AllowEmptyString()][string]$Value)
    if($Key -notmatch '^[A-Za-z0-9_.-]+$'){throw 'The Stella setting name is invalid.'}
    $path=Get-StellaOverridePath;$map=Read-StellaOverrides
    if(Test-Path -LiteralPath $path -PathType Leaf){[void](Backup-HcEmulatorConfigFile -Path $path -AdapterId 'stella-cli')}
    if([string]::IsNullOrWhiteSpace($Value)){
        if($map.Contains($Key)){$map.Remove($Key)}
    }else{$map[$Key]=[string]$Value}
    $object=New-Object psobject
    foreach($name in @($map.Keys|Sort-Object)){Add-Member -InputObject $object -MemberType NoteProperty -Name ([string]$name) -Value ([string]$map[$name])}
    $object|ConvertTo-Json -Depth 4|Set-Content -LiteralPath $path -Encoding UTF8
}

'''
if 'function Get-StellaCliSettings {' not in w:
    anchor='$definition=Get-PlatformDefinition $PlatformId\n'
    if w.count(anchor)!=1:raise SystemExit('Stella worker function insertion anchor missing')
    w=w.replace(anchor,functions+anchor,1)

old="$inventory=@(Get-HcCompleteEmulatorSettingsInventory -AdapterId $adapterId -ConfigFiles $configFiles)\nforeach($setting in $inventory){$setting.Category=Get-SettingCategory $setting}\n"
new="$inventory=$(if($adapterId -ieq 'stella'){@(Get-StellaCliSettings -Settings $settings)}else{@(Get-HcCompleteEmulatorSettingsInventory -AdapterId $adapterId -ConfigFiles $configFiles)})\nforeach($setting in @($inventory)){$setting.Category=Get-SettingCategory $setting}\n"
if old in w:w=w.replace(old,new,1)
elif "Get-StellaCliSettings -Settings $settings" not in w:raise SystemExit('Stella inventory replacement anchor missing')

old_set="    Set-HcEmulatorConfigSetting -Setting $target[0] -Value $Value\n    $configFiles=Get-ExplicitConfigFiles -AdapterId $adapterId -Roots $roots\n    $inventory=@(Get-HcCompleteEmulatorSettingsInventory -AdapterId $adapterId -ConfigFiles $configFiles)\n    foreach($setting in $inventory){$setting.Category=Get-SettingCategory $setting}\n"
new_set="    if([string](Get-EntryProperty $target[0] 'Format' '') -eq 'stella-cli'){Set-StellaCliOverride -Key ([string](Get-EntryProperty $target[0] 'Key' '')) -Value $Value}else{Set-HcEmulatorConfigSetting -Setting $target[0] -Value $Value}\n    $configFiles=Get-ExplicitConfigFiles -AdapterId $adapterId -Roots $roots\n    $inventory=$(if($adapterId -ieq 'stella'){@(Get-StellaCliSettings -Settings $settings)}else{@(Get-HcCompleteEmulatorSettingsInventory -AdapterId $adapterId -ConfigFiles $configFiles)})\n    foreach($setting in @($inventory)){$setting.Category=Get-SettingCategory $setting}\n"
if old_set in w:w=w.replace(old_set,new_set,1)
elif 'Set-StellaCliOverride -Key' not in w:raise SystemExit('Stella Set replacement anchor missing')
worker.write_text(w,encoding='utf-8')

cs=ROOT/'Native'/'HuymaierConsole.ConsolePlatforms.cs'
c=cs.read_text(encoding='utf-8-sig')
helper=r'''
        private string BuildStellaOverrideArguments()
        {
            string path = Path.Combine(dataRoot, "stella-command-line-overrides.json");
            if (!File.Exists(path)) return String.Empty;
            try
            {
                Dictionary<string, object> values = new JavaScriptSerializer().Deserialize<Dictionary<string, object>>(File.ReadAllText(path, Encoding.UTF8));
                if (values == null || values.Count == 0) return String.Empty;
                StringBuilder result = new StringBuilder();
                foreach (KeyValuePair<string, object> pair in values.OrderBy(delegate(KeyValuePair<string, object> item) { return item.Key; }, StringComparer.OrdinalIgnoreCase))
                {
                    string key = pair.Key ?? String.Empty; if (!System.Text.RegularExpressions.Regex.IsMatch(key, "^[A-Za-z0-9_.-]+$")) continue;
                    string value = pair.Value == null ? String.Empty : Convert.ToString(pair.Value, CultureInfo.InvariantCulture); if (String.IsNullOrWhiteSpace(value)) continue;
                    if (result.Length > 0) result.Append(' '); result.Append('-').Append(key).Append(' ').Append(QuoteProcessArgument(value));
                }
                return result.ToString();
            }
            catch (Exception ex) { WritePlatformLog("Could not read Stella launch overrides: " + ex.Message, "WARN"); return String.Empty; }
        }

'''
if 'private string BuildStellaOverrideArguments()' not in c:
    anchor='        private string BuildLaunchArguments(string executable, string gamePath)\n'
    if c.count(anchor)!=1:raise SystemExit('Stella launch helper insertion anchor missing')
    c=c.replace(anchor,helper+anchor,1)

if 'BuildStellaOverrideArguments()' in c and 'definition.Shell == "Atari2600" && exe.IndexOf("stella"' not in c:
    marker='            string quoted = "\\\"" + gamePath.Replace("\\\"", String.Empty) + "\\\"";\n'
    if c.count(marker)!=1:raise SystemExit(f'Stella launch insertion marker expected one match, found {c.count(marker)}')
    add=marker+'            if (definition.Shell == "Atari2600" && exe.IndexOf("stella", StringComparison.OrdinalIgnoreCase) >= 0) { string overrides = BuildStellaOverrideArguments(); return (String.IsNullOrWhiteSpace(overrides) ? String.Empty : overrides + " ") + quoted; }\n'
    c=c.replace(marker,add,1)
cs.write_text(c,encoding='utf-8')
print('materialized Stella runtime command-line settings adapter and safe launch overrides')
