Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
$root=(Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$registryPath=Join-Path $root 'EmulatorPlatforms\platform-registry.json'
$runtimePath=Join-Path $root 'HuymaierUser3DModels.ps1'
$v7Path=Join-Path $root 'HuymaierGpuPlatformShelves.ps1'
foreach($p in @($registryPath,$runtimePath,$v7Path)){if(-not(Test-Path -LiteralPath $p -PathType Leaf)){throw "Platform naming source missing: $p"}}
$registry=Get-Content -Raw -LiteralPath $registryPath -Encoding UTF8|ConvertFrom-Json

# Execute the actual production presentation functions. The audit is deliberately
# scoped to unique presentation identities (name/menuName/displayName). Emulator
# aliases such as ares, Mednafen and Mesen are shared by multiple platforms and
# therefore cannot serve as a unique visible console name.
$tokens=$null;$errors=$null
$ast=[Management.Automation.Language.Parser]::ParseFile($runtimePath,[ref]$tokens,[ref]$errors)
if($errors.Count){throw "Platform presentation runtime failed PowerShell 5.1 parse: $(@($errors|ForEach-Object{$_.Message}) -join '; ')"}
$init=@($ast.FindAll({param($n)$n -is [Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq 'Initialize-HcPlatformDisplayLabelMap'},$true)|Select-Object -First 1)
$get=@($ast.FindAll({param($n)$n -is [Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq 'Get-HcPlatformDisplayLabel'},$true)|Select-Object -First 1)
if($init.Count-ne1-or$get.Count-ne1){throw 'Production canonical platform presentation functions are missing.'}
function Get-EntryProperty {param($Object,[string]$Name,$Default='');if($null-eq$Object){return $Default};$prop=$Object.PSObject.Properties[$Name];if($null-eq$prop-or$null-eq$prop.Value){return $Default};return $prop.Value}
$script:BaseDir=$root
$script:HcPlatformDisplayLabelMap=$null
. ([ScriptBlock]::Create($init[0].Extent.Text+"`r`n"+$get[0].Extent.Text))

$problems=New-Object System.Collections.ArrayList
foreach($p in @($registry.platforms|Sort-Object {[int]$_.sortOrder},id)){
    if($null-eq$p){continue}
    $id=[string]$p.id;$name=[string]$p.name;$display=[string]$p.displayName;$menu=[string]$p.menuName
    if([string]::IsNullOrWhiteSpace($name)){[void]$problems.Add("$id => blank name");continue}
    if([string]::IsNullOrWhiteSpace($display)){[void]$problems.Add("$id => blank displayName");continue}
    if([string]::IsNullOrWhiteSpace($menu)){[void]$problems.Add("$id => blank menuName");continue}
    foreach($identity in @($name,$menu,$display)|Select-Object -Unique){
        $resolved=[string](Get-HcPlatformDisplayLabel ([string]$identity) 'Consoles')
        Write-Host ("PLATFORM_DISPLAY`t{0}`tinternal={1}`tvisible={2}`texpected={3}" -f $id,$identity,$resolved,$display)
        if(-not[string]::Equals($resolved,$display,[StringComparison]::Ordinal)){[void]$problems.Add("$id => '$identity' displayed as '$resolved', expected '$display'")}
    }
}

# Explicit high-risk examples from previous visible regressions and shorthand.
$required=@{
    '32X'='Sega 32X'
    'Dreamcast'='Sega Dreamcast'
    'Saturn'='Sega Saturn'
    'Game Gear'='Sega Game Gear'
    'Master System'='Sega Master System'
    'N64'='Nintendo 64'
    'GameCube'='Nintendo GameCube'
    'Wii'='Nintendo Wii'
    'Wii U'='Nintendo Wii U'
    'Switch'='Nintendo Switch'
    'Game Boy'='Nintendo Game Boy'
    'Game Boy Color'='Nintendo Game Boy Color'
    'Game Boy Advance'='Nintendo Game Boy Advance'
    'Vita'='PlayStation Vita'
    'PSP'='PlayStation Portable'
    'PS4'='PlayStation 4'
    'Sega CD'='Sega CD'
    'Nintendo Entertainment System'='Nintendo Entertainment System'
    'Super Nintendo Entertainment System'='Super Nintendo Entertainment System'
}
foreach($key in $required.Keys){$actual=[string](Get-HcPlatformDisplayLabel $key 'Consoles');if($actual-ne$required[$key]){[void]$problems.Add("explicit '$key' => '$actual', expected '$($required[$key])'")}}

# Provider labels are separately canonicalized; Xbox PC remains isolated from
# Original Xbox hardware.
$providers=@{
    'Steam'='Steam';'Epic'='Epic Games';'GOG'='GOG';'EA'='EA';'Ubisoft'='Ubisoft Connect';'Xbox'='Xbox PC';'Battle.net'='Battle.net';'Rockstar'='Rockstar Games';'Amazon'='Amazon Games';'Recomps'='Recomps'
}
foreach($key in $providers.Keys){$actual=[string](Get-HcPlatformDisplayLabel $key 'Providers');if($actual-ne$providers[$key]){[void]$problems.Add("provider '$key' => '$actual', expected '$($providers[$key])'")}}
if((Get-HcPlatformDisplayLabel 'Original Xbox' 'Consoles')-ne'Original Xbox'){[void]$problems.Add('Original Xbox hardware display identity was confused with Xbox PC provider.')}

# Presentation-only: the existing internal 32X menu identity remains untouched.
$thirtyTwoX=@($registry.platforms|Where-Object{$_.id-eq'sega32x'}|Select-Object -First 1)
if($thirtyTwoX.Count-ne1-or[string]$thirtyTwoX[0].menuName-ne'32X'){[void]$problems.Add('32X internal platform routing identity changed unexpectedly.')}

$v7=Get-Content -Raw -LiteralPath $v7Path -Encoding UTF8
foreach($needle in @('Get-HcPlatformDisplayLabel $Platform $Group','DisplayName=$displayName','$selectedCard.DisplayName')){if($v7.IndexOf($needle,[StringComparison]::Ordinal)-lt0){[void]$problems.Add("V7 shelf is not using canonical display labels: $needle")}}

if($problems.Count){$problems|ForEach-Object{Write-Host ('NAMING_PROBLEM '+$_)};throw "Canonical platform naming audit found $($problems.Count) problems."}
Write-Host 'platformNamingAllRegistryDisplayNamesGate: success'
Write-Host 'platformNamingSega32XGate: success'
Write-Host 'platformNamingProviderHardwareIsolationGate: success'
Write-Host 'platformNamingInternalRoutingUnchangedGate: success'
