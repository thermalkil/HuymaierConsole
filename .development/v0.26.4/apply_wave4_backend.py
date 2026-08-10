from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]

installer=ROOT/'HuymaierEmulatorInstaller.ps1';p=installer.read_text(encoding='utf-8-sig')

mame=r'''
function Install-MameLatest {
    $assets=Get-GithubLatestAssets 'mamedev/mame'
    $asset=@($assets|Where-Object{$_.name -match '(?i)^mame[0-9]+b?_64bit\.exe$' -or $_.name -match '(?i)mame.*64.*\.exe$'}|Select-Object -First 1)
    if(-not $asset){throw 'The latest official MAME GitHub release did not expose a 64-bit Windows self-extracting archive.'}
    $target=Join-Path $DestinationRoot 'MAME';$work=Join-Path $env:TEMP ('hc-mame-'+[guid]::NewGuid().ToString('N'));New-Item -ItemType Directory -Force -Path $work|Out-Null
    try{
        $archive=Join-Path $work ([string]$asset.name);Invoke-WebRequest -UseBasicParsing -Headers $headers -Uri ([string]$asset.browser_download_url) -OutFile $archive
        if($asset.PSObject.Properties['digest'] -and [string]$asset.digest -match '(?i)^sha256:(?<hash>[0-9a-f]{64})$'){$actual=(Get-FileHash -Algorithm SHA256 -LiteralPath $archive).Hash.ToLowerInvariant();if($actual -ne $matches['hash'].ToLowerInvariant()){throw 'The official MAME archive failed SHA-256 verification.'}}
        New-Item -ItemType Directory -Force -Path $target|Out-Null
        $process=Start-Process -FilePath $archive -ArgumentList @('-y',('-o'+$target)) -Wait -PassThru -WindowStyle Hidden
        if($process.ExitCode -ne 0){throw "MAME self-extractor exited with code $($process.ExitCode)."}
        $exe=Get-ChildItem -LiteralPath $target -Filter 'mame.exe' -File -Recurse -ErrorAction SilentlyContinue|Select-Object -First 1;if(-not $exe){$exe=Get-ChildItem -LiteralPath $target -Filter 'mame64.exe' -File -Recurse -ErrorAction SilentlyContinue|Select-Object -First 1};if(-not $exe){throw 'mame.exe was not found after extraction.'};return $exe.FullName
    }finally{Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue}
}

'''
if 'function Install-MameLatest {' not in p:
    marker='function Install-BigPEmuLatest {'
    if p.count(marker)!=1:raise SystemExit('MAME installer insertion anchor missing')
    p=p.replace(marker,mame+marker,1)

cases=r'''    'ARCADE' {$exe=Install-MameLatest}
    'FINALBURNNEO' {$exe=Install-GithubArchive 'finalburnneo/FBNeo' { $_.name -match '(?i)(fbneo|finalburn).*(windows|win|x64|64).*\.(zip|7z)$' -and $_.name -notmatch '(?i)(source|debug|symbols|pdb)' } 'FinalBurnNeo' @('fbneo.exe','FinalBurnNeo.exe')}
'''
if "'ARCADE' {$exe=Install-MameLatest}" not in p:
    anchor="    'ATARILYNX' {$exe=Install-MednafenLatest}"
    idx=p.find(anchor)
    if idx<0:raise SystemExit('Wave4 installer case anchor missing')
    p=p[:idx]+cases+p[idx:]
installer.write_text(p,encoding='utf-8')

worker=ROOT/'HuymaierEmulatorSettingsWorker.ps1';w=worker.read_text(encoding='utf-8-sig')
functions=r'''
function Get-MameOverridePath {
    $dir=Split-Path -Parent $PlatformSettingsPath;if([string]::IsNullOrWhiteSpace($dir)){$dir=Join-Path (Join-Path $env:LOCALAPPDATA 'Huymaier Console\EmulatorPlatforms') 'ARCADE'};New-Item -ItemType Directory -Force -Path $dir|Out-Null;return Join-Path $dir 'mame-command-line-overrides.json'
}
function Read-MameOverrides {
    $path=Get-MameOverridePath;$map=[ordered]@{};if(Test-Path -LiteralPath $path){try{$loaded=Get-Content -Raw $path -Encoding UTF8|ConvertFrom-Json;foreach($property in @($loaded.PSObject.Properties)){$map[[string]$property.Name]=[string]$property.Value}}catch{}};return $map
}
function Get-MameConfigText {
    param($Settings);$exe=[string](Get-EntryProperty $Settings 'emulatorPath' '');if(-not(Test-Path $exe)){return ''}
    try{$psi=New-Object Diagnostics.ProcessStartInfo;$psi.FileName=$exe;$psi.Arguments='-showconfig';$psi.UseShellExecute=$false;$psi.CreateNoWindow=$true;$psi.RedirectStandardOutput=$true;$psi.RedirectStandardError=$true;$process=[Diagnostics.Process]::Start($psi);if($null -eq $process){return ''};$stdout=$process.StandardOutput.ReadToEnd();$stderr=$process.StandardError.ReadToEnd();if(-not $process.WaitForExit(10000)){try{$process.Kill()}catch{};return ''};return (($stdout+[Environment]::NewLine+$stderr).Trim())}catch{return ''}
}
function Get-MameCliSettings {
    param($Settings);$text=Get-MameConfigText $Settings;if([string]::IsNullOrWhiteSpace($text)){return [object[]]@()};$overrides=Read-MameOverrides;$path=Get-MameOverridePath;$result=New-Object Collections.ArrayList
    foreach($line in ($text -split "`r?`n")){$raw=([string]$line).Trim();if(-not $raw -or $raw.StartsWith('#')){continue};$m=[regex]::Match($raw,'^(?<key>[A-Za-z0-9_.-]+)\s+(?<value>.*)$');if(-not $m.Success){continue};$key=$m.Groups['key'].Value;$value=$(if($overrides.Contains($key)){[string]$overrides[$key]}else{[string]$m.Groups['value'].Value.Trim()});$record=New-HcEmulatorSettingRecord -Format 'mame-cli' -FilePath $path -Section '' -Key $key -Value $value -LineIndex -1 -AdapterId 'mame';$record.DisplayName=$key;$record.Category=Get-SettingCategory $record;[void]$result.Add($record)};return [object[]]$result.ToArray()
}
function Set-MameCliOverride {
    param([string]$Key,[AllowEmptyString()][string]$Value);if($Key -notmatch '^[A-Za-z0-9_.-]+$'){throw 'The MAME option name is invalid.'};$path=Get-MameOverridePath;$map=Read-MameOverrides;if(Test-Path $path){[void](Backup-HcEmulatorConfigFile -Path $path -AdapterId 'mame-cli')};if([string]::IsNullOrWhiteSpace($Value)){if($map.Contains($Key)){$map.Remove($Key)}}else{$map[$Key]=$Value};$object=New-Object psobject;foreach($name in @($map.Keys|Sort-Object)){Add-Member -InputObject $object -MemberType NoteProperty -Name ([string]$name) -Value ([string]$map[$name])};$object|ConvertTo-Json -Depth 4|Set-Content $path -Encoding UTF8
}

'''
if 'function Get-MameCliSettings {' not in w:
    anchor='function Get-StellaOverridePath {'
    if w.count(anchor)!=1:raise SystemExit('MAME worker insertion anchor missing')
    w=w.replace(anchor,functions+anchor,1)

# Inventory and set can dynamically select MAME or Stella special adapters.
old="$inventory=$(if($adapterId -ieq 'stella'){@(Get-StellaCliSettings -Settings $settings)}else{@(Get-HcCompleteEmulatorSettingsInventory -AdapterId $adapterId -ConfigFiles $configFiles)})"
new="$inventory=$(if($adapterId -ieq 'stella'){@(Get-StellaCliSettings -Settings $settings)}elseif($adapterId -ieq 'mame'){@(Get-MameCliSettings -Settings $settings)}else{@(Get-HcCompleteEmulatorSettingsInventory -AdapterId $adapterId -ConfigFiles $configFiles)})"
if old in w:w=w.replace(old,new)
elif "elseif($adapterId -ieq 'mame')" not in w:raise SystemExit('MAME inventory selector anchor missing')
old="if([string](Get-EntryProperty $target[0] 'Format' '') -eq 'stella-cli'){Set-StellaCliOverride -Key ([string](Get-EntryProperty $target[0] 'Key' '')) -Value $Value}else{Set-HcEmulatorConfigSetting -Setting $target[0] -Value $Value}"
new="if([string](Get-EntryProperty $target[0] 'Format' '') -eq 'stella-cli'){Set-StellaCliOverride -Key ([string](Get-EntryProperty $target[0] 'Key' '')) -Value $Value}elseif([string](Get-EntryProperty $target[0] 'Format' '') -eq 'mame-cli'){Set-MameCliOverride -Key ([string](Get-EntryProperty $target[0] 'Key' '')) -Value $Value}else{Set-HcEmulatorConfigSetting -Setting $target[0] -Value $Value}"
if old in w:w=w.replace(old,new,1)
elif "'mame-cli'" not in w:raise SystemExit('MAME set selector anchor missing')
# replace second inventory refresh selector if only Stella currently.
w=w.replace("$inventory=$(if($adapterId -ieq 'stella'){@(Get-StellaCliSettings -Settings $settings)}else{@(Get-HcCompleteEmulatorSettingsInventory -AdapterId $adapterId -ConfigFiles $configFiles)})","$inventory=$(if($adapterId -ieq 'stella'){@(Get-StellaCliSettings -Settings $settings)}elseif($adapterId -ieq 'mame'){@(Get-MameCliSettings -Settings $settings)}else{@(Get-HcCompleteEmulatorSettingsInventory -AdapterId $adapterId -ConfigFiles $configFiles)})")
worker.write_text(w,encoding='utf-8')

lib=ROOT/'HuymaierNativeConsoleLibraryWorker.ps1';l=lib.read_text(encoding='utf-8-sig')
if "'ARCADE' { return @('.zip','.7z','.chd') }" not in l:
    anchor="        'ATARILYNX' { return @('.lnx','.lyx','.o','.zip') }"
    add="        'ARCADE' { return @('.zip','.7z','.chd') }\n        'FINALBURNNEO' { return @('.zip','.7z','.chd') }\n"
    if l.count(anchor)!=1:raise SystemExit('Wave4 count scanner anchor missing')
    l=l.replace(anchor,add+anchor,1)
lib.write_text(l,encoding='utf-8')

cs=ROOT/'Native'/'HuymaierConsole.ConsolePlatforms.cs';c=cs.read_text(encoding='utf-8-sig')
helper=r'''
        private string BuildMameOverrideArguments()
        {
            string path=Path.Combine(dataRoot,"mame-command-line-overrides.json");if(!File.Exists(path))return String.Empty;
            try{Dictionary<string,object> values=new JavaScriptSerializer().Deserialize<Dictionary<string,object>>(File.ReadAllText(path,Encoding.UTF8));if(values==null)return String.Empty;StringBuilder result=new StringBuilder();foreach(KeyValuePair<string,object> pair in values.OrderBy(delegate(KeyValuePair<string,object> item){return item.Key;},StringComparer.OrdinalIgnoreCase)){string key=pair.Key??String.Empty;if(!System.Text.RegularExpressions.Regex.IsMatch(key,"^[A-Za-z0-9_.-]+$"))continue;string value=pair.Value==null?String.Empty:Convert.ToString(pair.Value,CultureInfo.InvariantCulture);if(String.IsNullOrWhiteSpace(value))continue;if(result.Length>0)result.Append(' ');result.Append('-').Append(key).Append(' ').Append(QuoteProcessArgument(value));}return result.ToString();}catch(Exception ex){WritePlatformLog("Could not read MAME launch overrides: "+ex.Message,"WARN");return String.Empty;}
        }

'''
if 'private string BuildMameOverrideArguments()' not in c:
    anchor='        private string BuildStellaOverrideArguments()\n'
    if c.count(anchor)!=1:raise SystemExit('MAME C# helper insertion anchor missing')
    c=c.replace(anchor,helper+anchor,1)
# Insert MAME launch branch immediately after quoted game path creation.
marker='            string quoted = "\\\"" + gamePath.Replace("\\\"", String.Empty) + "\\\"";\n'
if 'definition.Shell == "Arcade" && exe.IndexOf("mame"' not in c:
    if c.count(marker)!=1:raise SystemExit('MAME launch branch anchor missing')
    branch='''            if (definition.Shell == "Arcade" && exe.IndexOf("mame", StringComparison.OrdinalIgnoreCase) >= 0) { string driver=Path.GetFileNameWithoutExtension(gamePath); string romDir=Path.GetDirectoryName(gamePath); string overrides=BuildMameOverrideArguments(); StringBuilder mame=new StringBuilder(); if(!String.IsNullOrWhiteSpace(overrides))mame.Append(overrides).Append(' '); if(!String.IsNullOrWhiteSpace(romDir))mame.Append("-rompath ").Append(QuoteProcessArgument(romDir)).Append(' '); mame.Append(driver); return mame.ToString(); }\n'''
    c=c.replace(marker,marker+branch,1)
cs.write_text(c,encoding='utf-8')
print('materialized MAME/FBNeo install, complete MAME settings, count scanning and driver launch adapter')
