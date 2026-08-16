Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
$root=(Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$utf8NoBom=New-Object Text.UTF8Encoding($false)

function Read-HcText([string]$Path){return ([IO.File]::ReadAllText($Path)).Replace("`r`n","`n")}
function Write-HcText([string]$Path,[string]$Text){[IO.File]::WriteAllText($Path,$Text.Replace("`r`n","`n"),$utf8NoBom)}
function Replace-HcRequired([string]$Text,[string]$Old,[string]$New,[string]$Label){
    if($Text.Contains($New)){return $Text}
    if(-not $Text.Contains($Old)){throw "Patch anchor missing: $Label"}
    return $Text.Replace($Old,$New)
}

$registryPath=Join-Path $root 'EmulatorPlatforms\platform-registry.json'
$registry=Read-HcText $registryPath
$registry=Replace-HcRequired $registry '"menuName": "Entertainment System",' '"menuName": "Nintendo Entertainment System",' 'NES canonical menu name'
$registry=Replace-HcRequired $registry '"menuName": "Super Entertainment System",' '"menuName": "Super Nintendo Entertainment System",' 'SNES canonical menu name'
$old="`"Nintendo Entertainment System`",`n        `"NES`","
$new="`"Nintendo Entertainment System`",`n        `"NES`",`n        `"Nintendo NES`",`n        `"Entertainment System`","
$registry=Replace-HcRequired $registry $old $new 'NES legacy aliases'
$old="`"Super Nintendo Entertainment System`",`n        `"SNES`","
$new="`"Super Nintendo Entertainment System`",`n        `"SNES`",`n        `"Super NES`",`n        `"Super Nintendo`",`n        `"Super Entertainment System`","
$registry=Replace-HcRequired $registry $old $new 'SNES legacy aliases'
Write-HcText $registryPath $registry

$modelMapPath=Join-Path $root 'Assets\Models\model-map.json'
$modelMap=Read-HcText $modelMapPath
$old="`"NES`": `"atlas:nintendo-entertainment-system`",`n    `"Nintendo Entertainment System`": `"atlas:nintendo-entertainment-system`","
$new="`"NES`": `"atlas:nintendo-entertainment-system`",`n    `"Nintendo NES`": `"atlas:nintendo-entertainment-system`",`n    `"Entertainment System`": `"atlas:nintendo-entertainment-system`",`n    `"Nintendo Entertainment System`": `"atlas:nintendo-entertainment-system`","
$modelMap=Replace-HcRequired $modelMap $old $new 'NES model aliases'
$old="`"SNES`": `"atlas:super-nintendo-entertainment-system`",`n    `"Super Nintendo`": `"atlas:super-nintendo-entertainment-system`","
$new="`"SNES`": `"atlas:super-nintendo-entertainment-system`",`n    `"Super NES`": `"atlas:super-nintendo-entertainment-system`",`n    `"Super Nintendo`": `"atlas:super-nintendo-entertainment-system`",`n    `"Super Entertainment System`": `"atlas:super-nintendo-entertainment-system`",`n    `"Super Nintendo Entertainment System`": `"atlas:super-nintendo-entertainment-system`","
$modelMap=Replace-HcRequired $modelMap $old $new 'SNES model aliases'
Write-HcText $modelMapPath $modelMap

$smokePath=Join-Path $root 'Native\HuymaierD3D11ShelfAssetSmoke.cpp'
$smoke=Read-HcText $smokePath
if(-not $smoke.Contains('HC3D v1 cache-space UV convention')){
    $old='    float4 tex = Flags.x != 0 ? BaseTexture.Sample(BaseSampler, i.uv0) : float4(1,1,1,1);'
    $new="    // HC3D v1 cache-space UV convention: restore authored glTF V before sampling.`n    float2 baseUv = float2(i.uv0.x, 1.0 - i.uv0.y);`n    float2 emissiveUv = float2(i.uv1.x, 1.0 - i.uv1.y);`n    float4 tex = Flags.x != 0 ? BaseTexture.Sample(BaseSampler, baseUv) : float4(1,1,1,1);"
    $smoke=Replace-HcRequired $smoke $old $new 'cached smoke base UV'
    $smoke=Replace-HcRequired $smoke 'if (Flags.y != 0) emissive *= EmissiveTexture.Sample(EmissiveSampler, i.uv1).rgb;' 'if (Flags.y != 0) emissive *= EmissiveTexture.Sample(EmissiveSampler, emissiveUv).rgb;' 'cached smoke emissive UV'
    Write-HcText $smokePath $smoke
}

$v7Path=Join-Path $root 'HuymaierGpuPlatformShelves.ps1'
$v7=Read-HcText $v7Path
$marker='# HUYMAIER_V0265_CANONICAL_RECOMPS_V1'
if(-not $v7.Contains($marker)){
$block=@'

# HUYMAIER_V0265_CANONICAL_RECOMPS_V1
# V7 owns final Games presentation. These wrappers canonicalize legacy platform
# identities and add a local native Recomps provider without changing emulator
# console selection behavior. In particular, Xbox PC remains distinct from the
# Original Xbox hardware platform and never resolves Xbox.glb as a provider.
if(-not (Get-Variable HcV7BaseGetGameHubPlatforms -Scope Script -ErrorAction SilentlyContinue)){$script:HcV7BaseGetGameHubPlatforms=${function:Get-GameHubPlatforms}}
if(-not (Get-Variable HcV7BaseGetAllGameHubEntries -Scope Script -ErrorAction SilentlyContinue)){$script:HcV7BaseGetAllGameHubEntries=${function:Get-AllGameHubEntries}}
if(-not (Get-Variable HcV7BaseTestStorefrontPlatform -Scope Script -ErrorAction SilentlyContinue)){$script:HcV7BaseTestStorefrontPlatform=${function:Test-HcStorefrontPlatform}}
if(-not (Get-Variable HcV7BaseGetPageDefinition -Scope Script -ErrorAction SilentlyContinue)){$script:HcV7BaseGetPageDefinition=${function:Get-PageDefinition}}
if(-not (Get-Variable HcV7BaseInvokeAction -Scope Script -ErrorAction SilentlyContinue)){$script:HcV7BaseInvokeAction=${function:Invoke-Action}}
$script:HcRecompCacheRoot=''
$script:HcRecompCacheUntil=[datetime]::MinValue
$script:HcRecompCache=@()

function Get-HcCanonicalPlatformName([string]$Platform){
    if([string]::IsNullOrWhiteSpace($Platform)){return $Platform}
    switch($Platform.Trim().ToLowerInvariant()){
        'nes' {return 'Nintendo Entertainment System'}
        'nintendo nes' {return 'Nintendo Entertainment System'}
        'entertainment system' {return 'Nintendo Entertainment System'}
        'nintendo entertainment system' {return 'Nintendo Entertainment System'}
        'snes' {return 'Super Nintendo Entertainment System'}
        'super nes' {return 'Super Nintendo Entertainment System'}
        'super nintendo' {return 'Super Nintendo Entertainment System'}
        'super entertainment system' {return 'Super Nintendo Entertainment System'}
        'super nintendo entertainment system' {return 'Super Nintendo Entertainment System'}
        default {return $Platform}
    }
}

function Get-HcExplicitProviderRoot([string]$Provider){
    foreach($entry in @($script:Config.ProviderInstallRoots)){
        if($null -eq $entry){continue}
        if([string]::Equals([string](Get-EntryProperty $entry 'Provider' ''),$Provider,[StringComparison]::OrdinalIgnoreCase)){
            return [string](Get-EntryProperty $entry 'Path' '')
        }
    }
    return ''
}

function Convert-HcRecompNameKey([string]$Value){
    if([string]::IsNullOrWhiteSpace($Value)){return ''}
    return (($Value -replace '[^A-Za-z0-9]','').ToLowerInvariant())
}

function Test-HcRecompExecutable($File){
    if($null -eq $File -or -not [bool](Get-EntryProperty $File 'Exists' $false)){return $false}
    $name=[string](Get-EntryProperty $File 'Name' '')
    $path=[string](Get-EntryProperty $File 'FullName' '')
    if(-not $name -or -not $path){return $false}
    if($name -match '(?i)^(unins|uninstall|setup|install|crash|report|updater?|helper|vc_redist|dxsetup).*\.exe$'){return $false}
    if($path -match '(?i)[\\/](redist|redistributable|prereq|prerequisites|dependencies|crashdumps?|tools)[\\/]'){return $false}
    return $true
}

function Select-HcRecompExecutable($Directory){
    if($null -eq $Directory){return $null}
    $folderName=[string](Get-EntryProperty $Directory 'Name' '')
    $folderPath=[string](Get-EntryProperty $Directory 'FullName' '')
    if(-not $folderPath){return $null}
    $folderKey=Convert-HcRecompNameKey $folderName
    $candidates=@(Get-ChildItem -LiteralPath $folderPath -Filter '*.exe' -File -Recurse -ErrorAction SilentlyContinue|Where-Object{Test-HcRecompExecutable $_}|Select-Object -First 120)
    $best=$null;$bestScore=[int]::MinValue
    foreach($candidate in $candidates){
        $score=0;$candidateKey=Convert-HcRecompNameKey ([string]$candidate.BaseName)
        if($folderKey -and $candidateKey -eq $folderKey){$score+=120}
        elseif($folderKey -and $candidateKey.Contains($folderKey)){$score+=50}
        if([string]::Equals([string]$candidate.DirectoryName,$folderPath,[StringComparison]::OrdinalIgnoreCase)){$score+=35}
        if([string]$candidate.FullName -match '(?i)[\\/](release|bin|build)[\\/]'){$score+=12}
        $score-=[math]::Min(20,[math]::Floor(([string]$candidate.FullName).Length/80))
        if($null -eq $best -or $score -gt $bestScore){$best=$candidate;$bestScore=$score}
    }
    return $best
}

function Get-HcRecompGames {
    $root=Get-HcExplicitProviderRoot 'Recomps'
    if([string]::IsNullOrWhiteSpace($root) -or -not (Test-Path -LiteralPath $root -PathType Container)){
        $script:HcRecompCacheRoot=$root;$script:HcRecompCache=@();$script:HcRecompCacheUntil=[datetime]::Now.AddSeconds(5);return @()
    }
    if([string]::Equals($script:HcRecompCacheRoot,$root,[StringComparison]::OrdinalIgnoreCase) -and [datetime]::Now -lt $script:HcRecompCacheUntil){return [object[]]@($script:HcRecompCache)}
    $items=New-Object System.Collections.ArrayList;$seen=@{}
    foreach($exe in @(Get-ChildItem -LiteralPath $root -Filter '*.exe' -File -ErrorAction SilentlyContinue|Where-Object{Test-HcRecompExecutable $_})){
        $key=$exe.FullName.ToLowerInvariant();if($seen.ContainsKey($key)){continue};$seen[$key]=$true
        [void]$items.Add([pscustomobject]@{Id=('Recomps:'+$key);Name=$exe.BaseName;Source='Recomps';LaunchTarget=$exe.FullName;Path=$exe.DirectoryName;ArtworkPath='';Installed=$true})
    }
    foreach($dir in @(Get-ChildItem -LiteralPath $root -Directory -ErrorAction SilentlyContinue|Sort-Object Name)){
        $exe=Select-HcRecompExecutable $dir;if($null -eq $exe){continue}
        $key=$exe.FullName.ToLowerInvariant();if($seen.ContainsKey($key)){continue};$seen[$key]=$true
        [void]$items.Add([pscustomobject]@{Id=('Recomps:'+$key);Name=$dir.Name;Source='Recomps';LaunchTarget=$exe.FullName;Path=$dir.FullName;ArtworkPath='';Installed=$true})
    }
    $script:HcRecompCacheRoot=$root;$script:HcRecompCache=[object[]]$items.ToArray();$script:HcRecompCacheUntil=[datetime]::Now.AddSeconds(10)
    return [object[]]@($script:HcRecompCache)
}

function Get-AllGameHubEntries {
    $items=New-Object System.Collections.ArrayList;$seen=@{}
    foreach($entry in @(& $script:HcV7BaseGetAllGameHubEntries)){
        if($null -eq $entry){continue};$id=[string](Get-EntryProperty $entry 'Id' '');$key=$(if($id){$id.ToLowerInvariant()}else{[guid]::NewGuid().ToString('N')})
        if($seen.ContainsKey($key)){continue};$seen[$key]=$true;[void]$items.Add($entry)
    }
    foreach($entry in @(Get-HcRecompGames)){
        $id=[string](Get-EntryProperty $entry 'Id' '');$key=$id.ToLowerInvariant();if($seen.ContainsKey($key)){continue};$seen[$key]=$true;[void]$items.Add($entry)
    }
    return [object[]]$items.ToArray()
}

function Get-GameHubPlatforms {
    try{$script:SelectedGamePlatform=Get-HcCanonicalPlatformName ([string]$script:SelectedGamePlatform)}catch{}
    $base=@(& $script:HcV7BaseGetGameHubPlatforms);$result=New-Object System.Collections.ArrayList;$seen=@{};$recompsAdded=$false
    foreach($raw in $base){
        $platform=Get-HcCanonicalPlatformName ([string]$raw)
        if(-not $recompsAdded -and $platform -notin @('Steam','Epic','GOG','Amazon')){[void]$result.Add('Recomps');$seen['recomps']=$true;$recompsAdded=$true}
        if([string]::IsNullOrWhiteSpace($platform)){continue};$key=$platform.ToLowerInvariant();if($seen.ContainsKey($key)){continue};$seen[$key]=$true;[void]$result.Add($platform)
    }
    if(-not $recompsAdded){[void]$result.Add('Recomps')}
    return [object[]]$result.ToArray()
}

function Test-HcStorefrontPlatform {
    param([string]$Platform)
    if([string]::Equals($Platform,'Recomps',[StringComparison]::OrdinalIgnoreCase)){return $true}
    return [bool](& $script:HcV7BaseTestStorefrontPlatform $Platform)
}

function Get-PageDefinition {
    param([int]$Index)
    $page=& $script:HcV7BaseGetPageDefinition $Index
    if($Index -ne 7 -or $null -eq $page -or -not [string]::IsNullOrWhiteSpace([string]$script:SubPage)){return $page}
    $root=Get-HcExplicitProviderRoot 'Recomps'
    $label=$(if($root){'Recomps folder: Configured'}else{'Recomps folder: Not configured'})
    $description=$(if($root){$root}else{'Choose the root folder containing native recomp builds.'})
    $action=New-Action 'recomps-root' $label $description
    $actions=New-Object System.Collections.ArrayList;$inserted=$false
    foreach($existing in @($page.Actions)){
        [void]$actions.Add($existing)
        if(-not $inserted -and [string](Get-EntryProperty $existing 'Id' '') -eq 'artwork-settings'){[void]$actions.Add($action);$inserted=$true}
    }
    if(-not $inserted){[void]$actions.Add($action)}
    $page.Actions=[object[]]$actions.ToArray();return $page
}

function Invoke-Action {
    param([string]$Id)
    if([string]::Equals($Id,'recomps-root',[StringComparison]::OrdinalIgnoreCase)){
        $picker=@{Mode='PickFolder';Store='Recomps';EntryType='ProviderInstall';ReturnTab=7}
        $root=Get-HcExplicitProviderRoot 'Recomps';if($root){$picker.StartPath=$root}
        Start-NativeFilePicker @picker;return
    }
    & $script:HcV7BaseInvokeAction $Id
}
'@
    $block=$block.Replace("`r`n","`n")
    $anchor="Set-StrictMode -Version 2.0`n"
    if(-not $v7.Contains($anchor)){throw 'V7 insertion anchor missing.'}
    $v7=$v7.Replace($anchor,$anchor+$block+"`n")
    Write-HcText $v7Path $v7
}

Write-Host 'v0265UvAliasesRecompsPatchGate: success'
