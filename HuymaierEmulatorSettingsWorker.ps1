[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][ValidateSet('Inventory','Set')][string]$Mode,
    [Parameter(Mandatory=$true)][string]$PlatformId,
    [Parameter(Mandatory=$true)][string]$ConsoleRoot,
    [Parameter(Mandatory=$true)][string]$PlatformSettingsPath,
    [Parameter(Mandatory=$true)][string]$OutputPath,
    [string]$Identity='',
    [AllowEmptyString()][string]$Value='',
    [string]$EditRequestPath=''
)
Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
$ProgressPreference='SilentlyContinue'

$script:BaseDir=[IO.Path]::GetFullPath($ConsoleRoot)

function Write-Log { param([string]$Message,[string]$Level='INFO') }
function Get-EntryProperty {
    param($Object,[string]$Name,$Default=$null)
    if($null -eq $Object){return $Default}
    try{if($Object -is [Collections.IDictionary]){if($Object.Contains($Name)){return $Object[$Name]};return $Default}}catch{}
    try{$p=$Object.PSObject.Properties[$Name];if($null -ne $p){return $p.Value}}catch{}
    return $Default
}

$module=Join-Path $script:BaseDir 'HuymaierEmulatorSettings.ps1'
if(-not(Test-Path -LiteralPath $module -PathType Leaf)){throw 'HuymaierEmulatorSettings.ps1 is missing.'}
. $module

function Get-PlatformDefinition {
    param([string]$Id)
    $path=Join-Path (Join-Path $script:BaseDir 'EmulatorPlatforms') (Join-Path $Id.ToUpperInvariant() 'platform.json')
    if(-not(Test-Path -LiteralPath $path -PathType Leaf)){throw "Platform definition is missing: $Id"}
    return Get-Content -Raw -LiteralPath $path -Encoding UTF8|ConvertFrom-Json
}

function Read-PlatformSettings {
    if(Test-Path -LiteralPath $PlatformSettingsPath -PathType Leaf){
        try{return Get-Content -Raw -LiteralPath $PlatformSettingsPath -Encoding UTF8|ConvertFrom-Json}catch{}
    }
    $default=Join-Path (Join-Path $script:BaseDir 'EmulatorPlatforms') (Join-Path $PlatformId.ToUpperInvariant() 'settings.default.json')
    if(Test-Path -LiteralPath $default -PathType Leaf){return Get-Content -Raw -LiteralPath $default -Encoding UTF8|ConvertFrom-Json}
    return [pscustomobject]@{}
}

function Add-Root {
    param([Collections.ArrayList]$List,[hashtable]$Seen,[string]$Path)
    if([string]::IsNullOrWhiteSpace($Path)){return}
    try{
        $expanded=[Environment]::ExpandEnvironmentVariables($Path)
        if(Test-Path -LiteralPath $expanded -PathType Leaf){$expanded=Split-Path -Parent $expanded}
        if(-not(Test-Path -LiteralPath $expanded -PathType Container)){return}
        $full=[IO.Path]::GetFullPath($expanded);$key=$full.ToLowerInvariant()
        if(-not $Seen.ContainsKey($key)){$Seen[$key]=$true;[void]$List.Add($full)}
    }catch{}
}

function Get-ConfigRoots {
    param([string]$AdapterId,$Settings)
    $roots=New-Object Collections.ArrayList;$seen=@{}
    foreach($value in @(
        [string](Get-EntryProperty $Settings 'emulatorDataPath' ''),
        [string](Get-EntryProperty $Settings 'emulatorPath' ''),
        [string](Get-EntryProperty $Settings 'fallbackEmulatorPath' '')
    )){Add-Root $roots $seen $value}
    $app=[Environment]::GetFolderPath([Environment+SpecialFolder]::ApplicationData)
    $local=[Environment]::GetFolderPath([Environment+SpecialFolder]::LocalApplicationData)
    $docs=[Environment]::GetFolderPath([Environment+SpecialFolder]::MyDocuments)
    switch($AdapterId.ToLowerInvariant()){
        'duckstation' {Add-Root $roots $seen ([string](Get-EntryProperty $Settings 'dataRoot' ''));Add-Root $roots $seen ([string](Get-EntryProperty $Settings 'duckStationPath' ''));Add-Root $roots $seen (Join-Path $docs 'DuckStation');Add-Root $roots $seen (Join-Path $app 'DuckStation');Add-Root $roots $seen (Join-Path $local 'DuckStation')}
        'pcsx2' {Add-Root $roots $seen ([string](Get-EntryProperty $Settings 'dataRoot' ''));Add-Root $roots $seen ([string](Get-EntryProperty $Settings 'pcsx2Path' ''));Add-Root $roots $seen (Join-Path $docs 'PCSX2');Add-Root $roots $seen (Join-Path $app 'PCSX2');Add-Root $roots $seen (Join-Path $local 'PCSX2')}
        'rpcs3' {Add-Root $roots $seen ([string](Get-EntryProperty $Settings 'rpcs3DataPath' ''));Add-Root $roots $seen ([string](Get-EntryProperty $Settings 'rpcs3Path' ''));Add-Root $roots $seen (Join-Path $app 'rpcs3');Add-Root $roots $seen (Join-Path $local 'rpcs3');Add-Root $roots $seen (Join-Path $docs 'RPCS3')}
        'shadps4' {Add-Root $roots $seen (Join-Path $app 'shadPS4');Add-Root $roots $seen (Join-Path $local 'shadPS4');Add-Root $roots $seen (Join-Path $docs 'shadPS4')}
        'vita3k' {Add-Root $roots $seen (Join-Path $app 'Vita3K');Add-Root $roots $seen (Join-Path $local 'Vita3K');Add-Root $roots $seen (Join-Path $docs 'Vita3K')}
        'rmg' {Add-Root $roots $seen (Join-Path $app 'RMG');Add-Root $roots $seen (Join-Path $local 'RMG')}
        'dolphin' {Add-Root $roots $seen (Join-Path $docs 'Dolphin Emulator');Add-Root $roots $seen (Join-Path $app 'Dolphin Emulator');Add-Root $roots $seen (Join-Path $local 'Dolphin')}
        'cemu' {Add-Root $roots $seen (Join-Path $app 'Cemu');Add-Root $roots $seen (Join-Path $local 'Cemu')}
        'eden' {Add-Root $roots $seen (Join-Path $app 'Eden');Add-Root $roots $seen (Join-Path $local 'Eden');Add-Root $roots $seen (Join-Path $app 'Ryujinx')}
        'xemu' {Add-Root $roots $seen (Join-Path $app 'xemu');Add-Root $roots $seen (Join-Path $local 'xemu')}
        'xenia' {Add-Root $roots $seen (Join-Path $docs 'Xenia');Add-Root $roots $seen (Join-Path $app 'Xenia');Add-Root $roots $seen (Join-Path $local 'Xenia')}
        'fbneo' {Add-Root $roots $seen (Join-Path $app 'FBNeo');Add-Root $roots $seen (Join-Path $local 'FBNeo');Add-Root $roots $seen (Join-Path $app 'FinalBurn Neo')}
        'primehack' {Add-Root $roots $seen (Join-Path $app 'PrimeHack');Add-Root $roots $seen (Join-Path $local 'PrimeHack');Add-Root $roots $seen (Join-Path $docs 'PrimeHack');Add-Root $roots $seen (Join-Path $docs 'Dolphin Emulator')}
        'bigpemu' {Add-Root $roots $seen (Join-Path $app 'BigPEmu');Add-Root $roots $seen (Join-Path $local 'BigPEmu');foreach($folder in @((Get-EntryProperty $Settings 'gameFolders' @()))){Add-Root $roots $seen ([string]$folder)}}
        'mesence' {Add-Root $roots $seen (Join-Path $app 'Mesen');Add-Root $roots $seen (Join-Path $app 'Mesen2');Add-Root $roots $seen (Join-Path $local 'Mesen');Add-Root $roots $seen (Join-Path $local 'Mesen2')}
        'sameboy' {Add-Root $roots $seen (Join-Path $app 'SameBoy');Add-Root $roots $seen (Join-Path $local 'SameBoy')}
        'mgba' {Add-Root $roots $seen (Join-Path $app 'mGBA');Add-Root $roots $seen (Join-Path $local 'mGBA')}
        'stella' {Add-Root $roots $seen (Join-Path $app 'Stella')}
        'ares' {Add-Root $roots $seen (Join-Path $app 'ares');Add-Root $roots $seen (Join-Path $local 'ares')}
        'azahar' {Add-Root $roots $seen (Join-Path $app 'Azahar');Add-Root $roots $seen (Join-Path $app 'azahar');Add-Root $roots $seen (Join-Path $local 'Azahar')}
        'melonds' {Add-Root $roots $seen (Join-Path $app 'melonDS');Add-Root $roots $seen (Join-Path $local 'melonDS')}
        'flycast' {Add-Root $roots $seen (Join-Path $app 'flycast');Add-Root $roots $seen (Join-Path $local 'flycast')}
        'mednafen' {Add-Root $roots $seen (Join-Path $docs 'Mednafen');Add-Root $roots $seen (Join-Path $app 'Mednafen')}
        'kronos' {Add-Root $roots $seen (Join-Path $app 'Kronos');Add-Root $roots $seen (Join-Path $local 'Kronos')}
        'ppsspp' {Add-Root $roots $seen (Join-Path $docs 'PPSSPP');Add-Root $roots $seen (Join-Path $app 'PPSSPP');Add-Root $roots $seen (Join-Path $local 'PPSSPP')}
        'vita3k' {Add-Root $roots $seen (Join-Path $app 'Vita3K');Add-Root $roots $seen (Join-Path $local 'Vita3K')}
    }
    return [string[]]$roots.ToArray([string])
}

function Get-ExplicitConfigFiles {
    param([string]$AdapterId,[string[]]$Roots)
    $found=New-Object Collections.ArrayList;$seen=@{}
    function Add-File([string]$Candidate){
        if(-not(Test-Path -LiteralPath $Candidate -PathType Leaf)){return}
        $full=[IO.Path]::GetFullPath($Candidate);$key=$full.ToLowerInvariant();if(-not $seen.ContainsKey($key)){$seen[$key]=$true;[void]$found.Add($full)}
    }
    foreach($root in @($Roots)){
        switch($AdapterId.ToLowerInvariant()){
            'duckstation' {foreach($rel in @('settings.ini','portable.txt','config\settings.ini')){Add-File (Join-Path $root $rel)};foreach($dirName in @('gamesettings','inputprofiles')){try{Get-ChildItem -LiteralPath (Join-Path $root $dirName) -File -Filter '*.ini' -ErrorAction SilentlyContinue|Select-Object -First 300|ForEach-Object{Add-File $_.FullName}}catch{}}}
            'pcsx2' {foreach($rel in @('inis\PCSX2.ini','inis\GS.ini','inis\SPU2.ini','inis\DEV9.ini','inis\USB.ini','inis\PAD.ini','PCSX2.ini','GS.ini')){Add-File (Join-Path $root $rel)};try{Get-ChildItem -LiteralPath $root -File -Recurse -ErrorAction SilentlyContinue|Where-Object{$_.Extension -ieq '.ini' -and $_.FullName -notmatch '(?i)\logs?\'}|Select-Object -First 350|ForEach-Object{Add-File $_.FullName}}catch{}}
            'rpcs3' {foreach($rel in @('config.yml','config.yaml','GuiConfigs\CurrentSettings.ini')){Add-File (Join-Path $root $rel)};try{Get-ChildItem -LiteralPath (Join-Path $root 'custom_configs') -File -ErrorAction SilentlyContinue|Where-Object{$_.Extension -match '(?i)^\.ya?ml$'}|Select-Object -First 500|ForEach-Object{Add-File $_.FullName}}catch{};try{Get-ChildItem -LiteralPath $root -File -ErrorAction SilentlyContinue|Where-Object{$_.Name -match '(?i)^config\.ya?ml$'}|ForEach-Object{Add-File $_.FullName}}catch{}}
            'shadps4' {foreach($rel in @('config.toml','settings.toml','config.json','settings.json','config.ini')){Add-File (Join-Path $root $rel)};try{Get-ChildItem -LiteralPath $root -File -ErrorAction SilentlyContinue|Where-Object{$_.Name -match '(?i)(config|settings).*\.(toml|json|ini|cfg)$'}|Select-Object -First 30|ForEach-Object{Add-File $_.FullName}}catch{}}
            'vita3k' {foreach($rel in @('config.yml','config.yaml','config\config.yml','config\config.yaml')){Add-File (Join-Path $root $rel)};try{Get-ChildItem -LiteralPath $root -File -ErrorAction SilentlyContinue|Where-Object{$_.Name -match '(?i)(config|settings).*\.(ya?ml|json|ini)$'}|Select-Object -First 30|ForEach-Object{Add-File $_.FullName}}catch{}}
            'rmg' {foreach($rel in @('RMG.ini','rmg.ini','settings.ini','config.ini','Config\RMG.ini')){Add-File (Join-Path $root $rel)};try{Get-ChildItem -LiteralPath $root -File -Recurse -ErrorAction SilentlyContinue|Where-Object{$_.Extension -match '(?i)^\.(ini|cfg|json)$'}|Select-Object -First 50|ForEach-Object{Add-File $_.FullName}}catch{}}
            'dolphin' {foreach($rel in @('Config\Dolphin.ini','Config\GFX.ini','Config\Controllers.ini','Config\WiimoteNew.ini','Config\Hotkeys.ini','Config\Logger.ini','Config\FreeLookController.ini','Config\Qt.ini','User\Config\Dolphin.ini','User\Config\GFX.ini','User\Config\Controllers.ini','User\Config\WiimoteNew.ini')){Add-File (Join-Path $root $rel)}}
            'cemu' {foreach($rel in @('settings.xml','cemuhook.ini','controllerProfiles\controller0.xml')){Add-File (Join-Path $root $rel)};try{Get-ChildItem -LiteralPath $root -File -Recurse -ErrorAction SilentlyContinue|Where-Object{$_.Name -match '(?i)(settings|config|profile).*\.(xml|ini|cfg)$'}|Select-Object -First 80|ForEach-Object{Add-File $_.FullName}}catch{}}
            'eden' {foreach($rel in @('config.json','Config.json','settings.json','config\config.json','config.yml','config.yaml')){Add-File (Join-Path $root $rel)};try{Get-ChildItem -LiteralPath $root -File -Recurse -ErrorAction SilentlyContinue|Where-Object{$_.Name -match '(?i)(config|settings).*\.(json|ya?ml|ini)$'}|Select-Object -First 50|ForEach-Object{Add-File $_.FullName}}catch{}}
            'xemu' {foreach($rel in @('xemu.toml','config.toml','xemu.ini','settings.toml')){Add-File (Join-Path $root $rel)};try{Get-ChildItem -LiteralPath $root -File -ErrorAction SilentlyContinue|Where-Object{$_.Extension -match '(?i)^\.(toml|ini|cfg|json)$'}|Select-Object -First 40|ForEach-Object{Add-File $_.FullName}}catch{}}
            'xenia' {foreach($rel in @('xenia-canary.config.toml','xenia.config.toml','xenia-canary.config.json','xenia.config.json')){Add-File (Join-Path $root $rel)};try{Get-ChildItem -LiteralPath $root -File -ErrorAction SilentlyContinue|Where-Object{$_.Name -match '(?i)^xenia.*config\.(toml|json)$'}|Select-Object -First 20|ForEach-Object{Add-File $_.FullName}}catch{}}
            'fbneo' {foreach($rel in @('config\fbneo.ini','config\fbneo.cfg','fbneo.ini','fbneo.cfg')){Add-File (Join-Path $root $rel)};try{Get-ChildItem -LiteralPath (Join-Path $root 'config') -File -ErrorAction SilentlyContinue|Where-Object{$_.Extension -match '(?i)^\.(ini|cfg)$'}|Select-Object -First 80|ForEach-Object{Add-File $_.FullName}}catch{}}
            'primehack' {foreach($rel in @('Config\Dolphin.ini','Config\GFX.ini','Config\PrimeHack.ini','Config\WiimoteNew.ini','Config\Hotkeys.ini','Config\Logger.ini','Dolphin.ini','GFX.ini','PrimeHack.ini')){Add-File (Join-Path $root $rel)}}
            'bigpemu' {foreach($rel in @('BigPEmuConfig.bigpcfg','UserData\BigPEmuConfig.bigpcfg','BigPEmu.ini','bigpemu.ini','config.ini','settings.ini','config.json','settings.json')){Add-File (Join-Path $root $rel)};try{Get-ChildItem -LiteralPath $root -File -Recurse -ErrorAction SilentlyContinue|Where-Object{$_.Name -ieq 'BigPEmuConfig.bigpcfg' -or $_.Extension -ieq '.bigpcfg' -or $_.Name -match '(?i)(bigpemu|config|settings|profile).*\.(ini|cfg|json)$'}|Select-Object -First 500|ForEach-Object{Add-File $_.FullName}}catch{}}
            'mesence' {foreach($rel in @('settings.json','Settings.json','config.json','preferences.json','Mesen.json','Mesen2.json')){Add-File (Join-Path $root $rel)};try{Get-ChildItem -LiteralPath $root -File -ErrorAction SilentlyContinue|Where-Object{$_.Name -match '(?i)(settings|config|preferences).*\.(json|ini|cfg)$'}|Select-Object -First 20|ForEach-Object{Add-File $_.FullName}}catch{}}
            'sameboy' {foreach($rel in @('sameboy.ini','SameBoy.ini','sameboy.cfg','preferences.ini','config.ini')){Add-File (Join-Path $root $rel)};try{Get-ChildItem -LiteralPath $root -File -ErrorAction SilentlyContinue|Where-Object{$_.Name -match '(?i)(sameboy|settings|config|preferences).*\.(ini|cfg|json)$'}|Select-Object -First 20|ForEach-Object{Add-File $_.FullName}}catch{}}
            'mgba' {foreach($rel in @('config.ini','mGBA.ini','mgba.ini','qt.ini')){Add-File (Join-Path $root $rel)};try{Get-ChildItem -LiteralPath $root -File -ErrorAction SilentlyContinue|Where-Object{$_.Name -match '(?i)(mgba|config|settings).*\.(ini|cfg|json)$'}|Select-Object -First 20|ForEach-Object{Add-File $_.FullName}}catch{}}
            'stella' {foreach($rel in @('stella.ini','settings.ini','config.ini')){Add-File (Join-Path $root $rel)}}
            'azahar' {foreach($rel in @('config\qt-config.ini','qt-config.ini','config.ini')){Add-File (Join-Path $root $rel)}}
            'melonds' {foreach($rel in @('melonDS.ini','melonDS.toml','config\melonDS.ini')){Add-File (Join-Path $root $rel)}}
            'flycast' {foreach($rel in @('emu.cfg','config\emu.cfg')){Add-File (Join-Path $root $rel)}}
            'mednafen' {foreach($rel in @('mednafen.cfg','saturn.cfg','lynx.cfg','ngp.cfg','pce.cfg')){Add-File (Join-Path $root $rel)};try{Get-ChildItem -LiteralPath (Join-Path $root 'pgconfig') -File -Filter '*.cfg' -ErrorAction SilentlyContinue|ForEach-Object{Add-File $_.FullName}}catch{}}
            'kronos' {foreach($rel in @('kronos.ini','kronos.cfg','config\kronos.ini')){Add-File (Join-Path $root $rel)}}
            'ppsspp' {foreach($rel in @('PSP\SYSTEM\ppsspp.ini','PSP\SYSTEM\controls.ini','ppsspp.ini','controls.ini')){Add-File (Join-Path $root $rel)}}
            'vita3k' {foreach($rel in @('config.yml','config.yaml')){Add-File (Join-Path $root $rel)}}
            'ares' {foreach($rel in @('settings.bml')){Add-File (Join-Path $root $rel)}}
            default {}
        }
    }
    foreach($path in @(Resolve-HcAdapterConfigFiles -AdapterId $AdapterId -Roots $Roots)){Add-File $path}
    return [string[]]$found.ToArray([string])
}

function Get-SettingCategory {
    param($Setting)
    $text=(([string](Get-EntryProperty $Setting 'Section' ''))+' '+([string](Get-EntryProperty $Setting 'Key' ''))).ToLowerInvariant()
    if($text -match 'gpu|renderer|render|video|display|resolution|scale|shader|texture|filter|vsync|frame|aspect|stereo|3d'){return 'Graphics'}
    if($text -match 'audio|sound|volume|speaker|dsp|latency|buffer|mic'){return 'Audio'}
    if($text -match 'input|controller|gamepad|keyboard|mouse|touch|motion|gyro|deadzone|hotkey|pad|wiimote'){return 'Input'}
    if($text -match 'bios|firmware|nand|system|region|language|clock|cpu|core|jit|memory|hardware|console'){return 'System'}
    if($text -match 'path|folder|directory|rom|game dir|save|screenshot|texture dir|memstick|sdmc|user dir'){return 'Paths & Storage'}
    if($text -match 'network|online|wlan|adhoc|server|port|proxy|dns|multiplayer'){return 'Network'}
    if($text -match 'cheat|patch|hack|overclock|widescreen|enhance|accuracy|debug|log|developer'){return 'Enhancements & Advanced'}
    return 'Other'
}



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

$definition=Get-PlatformDefinition $PlatformId
$settings=Read-PlatformSettings
$adapterId=[string](Get-EntryProperty $definition 'adapter' '')
if([string]::IsNullOrWhiteSpace($adapterId)){
    $backend=[string](Get-EntryProperty $definition 'primaryBackend' '')
    if(-not $backend){$backend=[string](Get-EntryProperty $definition 'backend' '')}
    $adapterId=$backend.ToLowerInvariant().Replace(' ','').Replace('-','')
}
$roots=Get-ConfigRoots -AdapterId $adapterId -Settings $settings
$configFiles=Get-ExplicitConfigFiles -AdapterId $adapterId -Roots $roots
$inventory=$(if($adapterId -ieq 'stella'){@(Get-StellaCliSettings -Settings $settings)}elseif($adapterId -ieq 'mame'){@(Get-MameCliSettings -Settings $settings)}else{@(Get-HcCompleteEmulatorSettingsInventory -AdapterId $adapterId -ConfigFiles $configFiles)})
foreach($setting in @($inventory)){$setting.Category=Get-SettingCategory $setting}


if($Mode -eq 'Set' -and -not [string]::IsNullOrWhiteSpace($EditRequestPath)){
    if(-not(Test-Path -LiteralPath $EditRequestPath -PathType Leaf)){throw 'The native emulator setting edit request is missing.'}
    $editRequest=Get-Content -Raw -LiteralPath $EditRequestPath -Encoding UTF8|ConvertFrom-Json
    $Identity=[string](Get-EntryProperty $editRequest 'identity' '')
    $Value=[string](Get-EntryProperty $editRequest 'value' '')
}

if($Mode -eq 'Set'){
    if([string]::IsNullOrWhiteSpace($Identity)){throw 'Set mode requires a setting identity.'}
    $target=@($inventory|Where-Object{[string]::Equals([string]$_.Identity,$Identity,[StringComparison]::Ordinal)}|Select-Object -First 1)
    if(-not $target){throw 'The requested emulator setting is no longer present. Refresh the native settings list.'}
    if([string](Get-EntryProperty $target[0] 'Format' '') -eq 'stella-cli'){Set-StellaCliOverride -Key ([string](Get-EntryProperty $target[0] 'Key' '')) -Value $Value}elseif([string](Get-EntryProperty $target[0] 'Format' '') -eq 'mame-cli'){Set-MameCliOverride -Key ([string](Get-EntryProperty $target[0] 'Key' '')) -Value $Value}else{Set-HcEmulatorConfigSetting -Setting $target[0] -Value $Value}
    $configFiles=Get-ExplicitConfigFiles -AdapterId $adapterId -Roots $roots
    $inventory=$(if($adapterId -ieq 'stella'){@(Get-StellaCliSettings -Settings $settings)}elseif($adapterId -ieq 'mame'){@(Get-MameCliSettings -Settings $settings)}else{@(Get-HcCompleteEmulatorSettingsInventory -AdapterId $adapterId -ConfigFiles $configFiles)})
    foreach($setting in @($inventory)){$setting.Category=Get-SettingCategory $setting}
}

$result=[ordered]@{
    schemaVersion=1
    result='success'
    platformId=$PlatformId.ToUpperInvariant()
    displayName=[string](Get-EntryProperty $definition 'displayName' $PlatformId)
    adapterId=$adapterId
    backend=[string](Get-EntryProperty $definition 'primaryBackend' '')
    roots=[string[]]$roots
    configFiles=[string[]]$configFiles
    count=@($inventory).Count
    settings=[object[]]$inventory
    generatedAtUtc=[DateTime]::UtcNow.ToString('o')
}
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $OutputPath)|Out-Null
$result|ConvertTo-Json -Depth 8|Set-Content -LiteralPath $OutputPath -Encoding UTF8
