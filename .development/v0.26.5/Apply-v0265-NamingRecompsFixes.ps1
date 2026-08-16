Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
$root=(Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$utf8=New-Object Text.UTF8Encoding($false)
function ReadText([string]$p){([IO.File]::ReadAllText($p)).Replace("`r`n","`n")}
function WriteText([string]$p,[string]$s){[IO.File]::WriteAllText($p,$s.Replace("`r`n","`n"),$utf8)}
function ReplaceReq([string]$s,[string]$old,[string]$new,[string]$label){if($s.Contains($new)){return $s};if(-not$s.Contains($old)){throw "Patch anchor missing: $label"};$s.Replace($old,$new)}

# Canonical platform naming: retain useful abbreviations, eliminate accidental
# truncations that escaped from backend/menu token generation.
$regPath=Join-Path $root 'EmulatorPlatforms\platform-registry.json'
$reg=ReadText $regPath
$reg=ReplaceReq $reg '"menuName": "CD",' '"menuName": "Sega CD",' 'Sega CD menuName'
$reg=ReplaceReq $reg '"menuName": "4",' '"menuName": "PS4",' 'PS4 menuName'
$reg=ReplaceReq $reg '"Sega CD",`n        "SegaCD",' '"Sega CD",`n        "SegaCD",`n        "CD",' 'Sega CD legacy alias'
$reg=ReplaceReq $reg '"PlayStation 4",`n        "PS4",' '"PlayStation 4",`n        "PS4",`n        "4",' 'PS4 legacy alias'
WriteText $regPath $reg

$mapPath=Join-Path $root 'Assets\Models\model-map.json'
$map=ReadText $mapPath
$map=ReplaceReq $map '"PS4": "atlas:playstation-4",`n    "PlayStation 4": "atlas:playstation-4",' '"PS4": "atlas:playstation-4",`n    "4": "atlas:playstation-4",`n    "PlayStation 4": "atlas:playstation-4",' 'PS4 model legacy alias'
$map=ReplaceReq $map '"Sega CD": "atlas:sega-cd",' '"Sega CD": "atlas:sega-cd",`n    "CD": "atlas:sega-cd",' 'Sega CD model legacy alias'
WriteText $mapPath $map

# First-class Recomps provider behavior lives in the provider module. V7 still
# owns discovery/presentation, but Install & Manage must route to native folder
# selection and native EXE launch rather than emulator/backend actions.
$providersPath=Join-Path $root 'HuymaierGameProviders.ps1'
$p=ReadText $providersPath
$p=ReplaceReq $p "        [pscustomobject]@{Id='Amazon';Name='Amazon Games';Backend='Nile';Description='Direct Amazon Games management through Nile.';Glyph='AMZN'}`n" "        [pscustomobject]@{Id='Amazon';Name='Amazon Games';Backend='Nile';Description='Direct Amazon Games management through Nile.';Glyph='AMZN'},`n        [pscustomobject]@{Id='Recomps';Name='Recomps';Backend='Native';Description='Launch native recomp builds from a user-selected folder.';Glyph='RECOMP'}`n" 'Recomps provider definition'

$anchor="function Get-ProviderCatalogNode {`n    param([string]`$Provider)`n"
$insert=@'
function Get-ProviderCatalogNode {
    param([string]$Provider)
    if([string]::Equals($Provider,'Recomps',[StringComparison]::OrdinalIgnoreCase)){
        $root=''
        foreach($entry in @($script:Config.ProviderInstallRoots)){
            if($null-ne$entry-and[string]::Equals([string](Get-EntryProperty $entry 'Provider' ''),'Recomps',[StringComparison]::OrdinalIgnoreCase)){$root=[string](Get-EntryProperty $entry 'Path' '');break}
        }
        $games=@()
        if((Get-Command Get-HcRecompGames -ErrorAction SilentlyContinue)){$games=@(Get-HcRecompGames)}
        return [pscustomobject]@{Id='Recomps';Name='Recomps';Backend='Native';ToolReady=$true;Authenticated=$true;ToolPath='';Status=$(if($root){'Native recomp folder: '+$root}else{'Choose a Recomps root folder.'});Error='';Games=$games;Updated=(Get-Date).ToString('o')}
    }
'@
$insert=$insert.Replace("`r`n","`n")
if(-not$p.Contains("if([string]::Equals(`$Provider,'Recomps'")){
    if(-not$p.Contains($anchor)){throw 'Patch anchor missing: Recomps catalog node'}
    $p=$p.Replace($anchor,$insert)
}

# Native recomp launch bypasses the provider worker entirely.
$old="    if(-not `$provider -or -not `$gameId){return `$false}`n    if([string]::Equals(`$provider,'HES',[StringComparison]::OrdinalIgnoreCase)){"
$new="    if(-not `$provider -or -not `$gameId){return `$false}`n    if([string]::Equals(`$provider,'Recomps',[StringComparison]::OrdinalIgnoreCase)){`n        `$target=[string](Get-EntryProperty `$Entry 'LaunchTarget' '')`n        if(-not `$target-or-not(Test-Path -LiteralPath `$target -PathType Leaf)){Set-ConsoleNotice 'The selected recomp executable could not be found.' 'ERROR';return `$false}`n        Start-ExternalProcess `$target @()|Out-Null`n        return `$true`n    }`n    if([string]::Equals(`$provider,'HES',[StringComparison]::OrdinalIgnoreCase)){"
$p=ReplaceReq $p $old $new 'Recomps native launch'

# Replace the control-rail branching with a dedicated local-provider rail.
$old="    `$isHes=[string]::Equals(`$Provider,'HES',[StringComparison]::OrdinalIgnoreCase)`n    if(`$isHes){"
$new="    `$isHes=[string]::Equals(`$Provider,'HES',[StringComparison]::OrdinalIgnoreCase)`n    `$isRecomps=[string]::Equals(`$Provider,'Recomps',[StringComparison]::OrdinalIgnoreCase)`n    if(`$isRecomps){`n        `$root=''`n        foreach(`$entry in @(`$script:Config.ProviderInstallRoots)){if(`$null-ne`$entry-and[string]::Equals([string](Get-EntryProperty `$entry 'Provider' ''),'Recomps',[StringComparison]::OrdinalIgnoreCase)){`$root=[string](Get-EntryProperty `$entry 'Path' '');break}}`n        `$choices+=,[pscustomobject]@{Id='provider-recomps-folder';Glyph='FOLDER';Title=$(if(`$root){'Change Recomps Folder'}else{'Set Recomps Folder'});Subtitle=$(if(`$root){`$root}else{'Choose the root folder containing native recomp builds.'})}`n        `$choices+=,[pscustomobject]@{Id='provider-refresh:Recomps';Glyph='SYNC';Title='Refresh Recomps';Subtitle='Rescan the configured folder for native recomp executables.'}`n    }else{`n    if(`$isHes){"
$p=ReplaceReq $p $old $new 'Recomps control rail start'
$backAnchor="    `$choices+=,[pscustomobject]@{Id='provider-back';Glyph='BACK';Title='Platform Menu';Subtitle='Return to Home and Library choices.'}`n"
if(-not$p.Contains("Refresh Recomps")){throw 'Recomps control rail insertion failed.'}
if(-not$p.Contains("    }`n"+$backAnchor)){
    if(-not$p.Contains($backAnchor)){throw 'Patch anchor missing: Recomps control rail end'}
    $p=$p.Replace($backAnchor,"    }`n"+$backAnchor)
}

# Recomp game details expose only actions that make sense for native builds.
$old="    `$actions=New-Object System.Collections.Generic.List[object]`n    if(`$installed){"
$new="    `$actions=New-Object System.Collections.Generic.List[object]`n    if([string]::Equals(`$provider,'Recomps',[StringComparison]::OrdinalIgnoreCase)){`n        if(`$installed){`$actions.Add((New-Action 'provider-game-launch' 'Launch' ('Start '+`$name+' directly.')));`$actions.Add((New-Action 'provider-recomps-open-folder' 'Open game folder' 'Open the discovered recomp build folder in Explorer.'))}`n        `$actions.Add((New-Action 'provider-game-back' 'Back to provider library'))`n        return [pscustomobject]@{Title=`$name;Subtitle='Native recomp';Hero=$(if(`$installed){'INSTALLED'}else{'NOT FOUND'});HeroText=`$description;Actions=([object[]]`$actions.ToArray())}`n    }`n    if(`$installed){"
$p=ReplaceReq $p $old $new 'Recomps game detail actions'

# Refresh and folder-selection actions never invoke Legendary/gogdl/Nile worker logic.
$old="        `$provider=[string]`$matches[2]`n        if([string]::Equals(`$provider,'HES',[StringComparison]::OrdinalIgnoreCase)){"
$new="        `$provider=[string]`$matches[2]`n        if([string]::Equals(`$provider,'Recomps',[StringComparison]::OrdinalIgnoreCase)){`n            if(`$actionName -eq 'refresh'){try{`$script:HcRecompCacheUntil=[datetime]::MinValue;`$script:HcRecompCache=@()}catch{};Render-Page;Set-ConsoleNotice 'Recomps folder rescanned.' 'INFO'}`n            return `$true`n        }`n        if([string]::Equals(`$provider,'HES',[StringComparison]::OrdinalIgnoreCase)){"
$p=ReplaceReq $p $old $new 'Recomps refresh action'

$switchAnchor="    switch(`$Id){`n        'provider-hes-url'{"
$switchNew="    switch(`$Id){`n        'provider-recomps-folder'{`n            `$root=''`n            foreach(`$entry in @(`$script:Config.ProviderInstallRoots)){if(`$null-ne`$entry-and[string]::Equals([string](Get-EntryProperty `$entry 'Provider' ''),'Recomps',[StringComparison]::OrdinalIgnoreCase)){`$root=[string](Get-EntryProperty `$entry 'Path' '');break}}`n            `$args=@{Mode='PickFolder';Store='Recomps';EntryType='ProviderInstall';ReturnTab=1};if(`$root){`$args.StartPath=`$root};Start-NativeFilePicker @args;return `$true`n        }`n        'provider-recomps-open-folder'{`n            `$game=Get-SelectedProviderGame;`$path=[string](Get-EntryProperty `$game 'InstallPath' (Get-EntryProperty `$game 'Path' ''));if(`$path-and(Test-Path -LiteralPath `$path -PathType Container)){Start-Process explorer.exe -ArgumentList ('\"'+`$path+'\"')|Out-Null};return `$true`n        }`n        'provider-hes-url'{"
$p=ReplaceReq $p $switchAnchor $switchNew 'Recomps folder/open actions'
WriteText $providersPath $p

# V7 discovery entries need actual Provider/InstallPath fields so the provider UI
# and normal Game Hub launch adapter can identify them correctly.
$v7Path=Join-Path $root 'HuymaierGpuPlatformShelves.ps1'
$v7=ReadText $v7Path
$v7=ReplaceReq $v7 "        'super nintendo entertainment system' {return 'Super Nintendo Entertainment System'}`n        default {return `$Platform}" "        'super nintendo entertainment system' {return 'Super Nintendo Entertainment System'}`n        '4' {return 'PS4'}`n        'ps4' {return 'PS4'}`n        'playstation 4' {return 'PS4'}`n        'cd' {return 'Sega CD'}`n        'segacd' {return 'Sega CD'}`n        'sega cd' {return 'Sega CD'}`n        default {return `$Platform}" 'PS4/Sega CD canonical identities'
$v7=$v7.Replace("[pscustomobject]@{Id=('Recomps:'+`$key);Name=`$exe.BaseName;Source='Recomps';LaunchTarget=`$exe.FullName;Path=`$exe.DirectoryName;ArtworkPath='';Installed=`$true}","[pscustomobject]@{Id=('Recomps:'+`$key);Name=`$exe.BaseName;Source='Recomps';Provider='Recomps';LaunchTarget=`$exe.FullName;Path=`$exe.DirectoryName;InstallPath=`$exe.DirectoryName;ArtworkPath='';Installed=`$true;Description=('Native recomp build at '+`$exe.DirectoryName)}")
$v7=$v7.Replace("[pscustomobject]@{Id=('Recomps:'+`$key);Name=`$dir.Name;Source='Recomps';LaunchTarget=`$exe.FullName;Path=`$dir.FullName;ArtworkPath='';Installed=`$true}","[pscustomobject]@{Id=('Recomps:'+`$key);Name=`$dir.Name;Source='Recomps';Provider='Recomps';LaunchTarget=`$exe.FullName;Path=`$dir.FullName;InstallPath=`$dir.FullName;ArtworkPath='';Installed=`$true;Description=('Native recomp build at '+`$dir.FullName)}")
if(-not$v7.Contains("Provider='Recomps'")){throw 'Recomps discovery entry provider fields were not patched.'}
WriteText $v7Path $v7

Write-Host 'namingRecompsPatchGate: success'
