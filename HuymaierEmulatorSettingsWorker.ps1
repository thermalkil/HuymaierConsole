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
$inventory=@(Get-HcCompleteEmulatorSettingsInventory -AdapterId $adapterId -ConfigFiles $configFiles)
foreach($setting in $inventory){$setting.Category=Get-SettingCategory $setting}


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
    Set-HcEmulatorConfigSetting -Setting $target[0] -Value $Value
    $configFiles=Get-ExplicitConfigFiles -AdapterId $adapterId -Roots $roots
    $inventory=@(Get-HcCompleteEmulatorSettingsInventory -AdapterId $adapterId -ConfigFiles $configFiles)
    foreach($setting in $inventory){$setting.Category=Get-SettingCategory $setting}
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
