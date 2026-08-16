Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
$root=(Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$utf8=New-Object Text.UTF8Encoding($false)
function ReadText([string]$p){return ([IO.File]::ReadAllText($p)).Replace("`r`n","`n")}
function WriteText([string]$p,[string]$s){[IO.File]::WriteAllText($p,$s.Replace("`r`n","`n"),$utf8)}
function ReplaceReq([string]$s,[string]$old,[string]$new,[string]$label){
    $old=$old.Replace("`r`n","`n");$new=$new.Replace("`r`n","`n")
    if($s.Contains($new)){return $s}
    if(-not$s.Contains($old)){throw "Patch anchor missing: $label"}
    return $s.Replace($old,$new)
}

$regPath=Join-Path $root 'EmulatorPlatforms\platform-registry.json'
$reg=ReadText $regPath
$reg=ReplaceReq $reg '"menuName": "CD",' '"menuName": "Sega CD",' 'Sega CD menu name'
$reg=ReplaceReq $reg '"menuName": "4",' '"menuName": "PS4",' 'PS4 menu name'
$reg=ReplaceReq $reg @'
"Sega CD",
        "SegaCD",
'@ @'
"Sega CD",
        "SegaCD",
        "CD",
'@ 'Sega CD legacy alias'
$reg=ReplaceReq $reg @'
"PlayStation 4",
        "PS4",
'@ @'
"PlayStation 4",
        "PS4",
        "4",
'@ 'PS4 legacy alias'
WriteText $regPath $reg

$mapPath=Join-Path $root 'Assets\Models\model-map.json'
$map=ReadText $mapPath
$map=ReplaceReq $map @'
"PS4": "atlas:playstation-4",
    "PlayStation 4": "atlas:playstation-4",
'@ @'
"PS4": "atlas:playstation-4",
    "4": "atlas:playstation-4",
    "PlayStation 4": "atlas:playstation-4",
'@ 'PS4 model alias'
$map=ReplaceReq $map '"Sega CD": "atlas:sega-cd",' @'
"Sega CD": "atlas:sega-cd",
    "CD": "atlas:sega-cd",
'@ 'Sega CD model alias'
WriteText $mapPath $map

$providersPath=Join-Path $root 'HuymaierGameProviders.ps1'
$p=ReadText $providersPath
$p=ReplaceReq $p @'
        [pscustomobject]@{Id='Amazon';Name='Amazon Games';Backend='Nile';Description='Direct Amazon Games management through Nile.';Glyph='AMZN'}
'@ @'
        [pscustomobject]@{Id='Amazon';Name='Amazon Games';Backend='Nile';Description='Direct Amazon Games management through Nile.';Glyph='AMZN'},
        [pscustomobject]@{Id='Recomps';Name='Recomps';Backend='Native';Description='Launch native recomp builds from a user-selected folder.';Glyph='RECOMP'}
'@ 'Recomps provider definition'

$p=ReplaceReq $p @'
function Get-ProviderCatalogNode {
    param([string]$Provider)
'@ @'
function Get-ProviderCatalogNode {
    param([string]$Provider)
    if([string]::Equals($Provider,'Recomps',[StringComparison]::OrdinalIgnoreCase)){
        $root=''
        foreach($entry in @($script:Config.ProviderInstallRoots)){
            if($null-ne$entry-and[string]::Equals([string](Get-EntryProperty $entry 'Provider' ''),'Recomps',[StringComparison]::OrdinalIgnoreCase)){$root=[string](Get-EntryProperty $entry 'Path' '');break}
        }
        $games=@()
        if(Get-Command Get-HcRecompGames -ErrorAction SilentlyContinue){$games=@(Get-HcRecompGames)}
        return [pscustomobject]@{Id='Recomps';Name='Recomps';Backend='Native';ToolReady=$true;Authenticated=$true;ToolPath='';Status=$(if($root){'Native recomp folder: '+$root}else{'Choose a Recomps root folder.'});Error='';Games=$games;Updated=(Get-Date).ToString('o')}
    }
'@ 'Recomps catalog node'

$p=ReplaceReq $p @'
    if(-not $provider -or -not $gameId){return $false}
    if([string]::Equals($provider,'HES',[StringComparison]::OrdinalIgnoreCase)){
'@ @'
    if(-not $provider -or -not $gameId){return $false}
    if([string]::Equals($provider,'Recomps',[StringComparison]::OrdinalIgnoreCase)){
        $target=[string](Get-EntryProperty $Entry 'LaunchTarget' '')
        if(-not $target-or-not(Test-Path -LiteralPath $target -PathType Leaf)){Set-ConsoleNotice 'The selected recomp executable could not be found.' 'ERROR';return $false}
        Start-ExternalProcess $target @()|Out-Null
        return $true
    }
    if([string]::Equals($provider,'HES',[StringComparison]::OrdinalIgnoreCase)){
'@ 'Recomps native launch'

$p=ReplaceReq $p @'
    $isHes=[string]::Equals($Provider,'HES',[StringComparison]::OrdinalIgnoreCase)
    if($isHes){
'@ @'
    $isHes=[string]::Equals($Provider,'HES',[StringComparison]::OrdinalIgnoreCase)
    $isRecomps=[string]::Equals($Provider,'Recomps',[StringComparison]::OrdinalIgnoreCase)
    if($isRecomps){
        $root=''
        foreach($entry in @($script:Config.ProviderInstallRoots)){if($null-ne$entry-and[string]::Equals([string](Get-EntryProperty $entry 'Provider' ''),'Recomps',[StringComparison]::OrdinalIgnoreCase)){$root=[string](Get-EntryProperty $entry 'Path' '');break}}
        $choices+=,[pscustomobject]@{Id='provider-recomps-folder';Glyph='FOLDER';Title=$(if($root){'Change Recomps Folder'}else{'Set Recomps Folder'});Subtitle=$(if($root){$root}else{'Choose the root folder containing native recomp builds.'})}
        $choices+=,[pscustomobject]@{Id='provider-refresh:Recomps';Glyph='SYNC';Title='Refresh Recomps';Subtitle='Rescan the configured folder for native recomp executables.'}
    }else{
    if($isHes){
'@ 'Recomps control rail start'
$p=ReplaceReq $p @'
    $choices+=,[pscustomobject]@{Id='provider-back';Glyph='BACK';Title='Platform Menu';Subtitle='Return to Home and Library choices.'}
'@ @'
    }
    $choices+=,[pscustomobject]@{Id='provider-back';Glyph='BACK';Title='Platform Menu';Subtitle='Return to Home and Library choices.'}
'@ 'Recomps control rail end'

$p=ReplaceReq $p @'
    $actions=New-Object System.Collections.Generic.List[object]
    if($installed){
'@ @'
    $actions=New-Object System.Collections.Generic.List[object]
    if([string]::Equals($provider,'Recomps',[StringComparison]::OrdinalIgnoreCase)){
        if($installed){
            $actions.Add((New-Action 'provider-game-launch' 'Launch' ('Start '+$name+' directly.')))
            $actions.Add((New-Action 'provider-recomps-open-folder' 'Open game folder' 'Open the discovered recomp build folder in Explorer.'))
        }
        $actions.Add((New-Action 'provider-game-back' 'Back to provider library'))
        return [pscustomobject]@{Title=$name;Subtitle='Native recomp';Hero=$(if($installed){'INSTALLED'}else{'NOT FOUND'});HeroText=$description;Actions=([object[]]$actions.ToArray())}
    }
    if($installed){
'@ 'Recomps game page'

$p=ReplaceReq $p @'
        $provider=[string]$matches[2]
        if([string]::Equals($provider,'HES',[StringComparison]::OrdinalIgnoreCase)){
'@ @'
        $provider=[string]$matches[2]
        if([string]::Equals($provider,'Recomps',[StringComparison]::OrdinalIgnoreCase)){
            if($actionName -eq 'refresh'){
                try{$script:HcRecompCacheUntil=[datetime]::MinValue;$script:HcRecompCache=@()}catch{}
                Render-Page
                Set-ConsoleNotice 'Recomps folder rescanned.' 'INFO'
            }
            return $true
        }
        if([string]::Equals($provider,'HES',[StringComparison]::OrdinalIgnoreCase)){
'@ 'Recomps refresh action'

$p=ReplaceReq $p @'
    switch($Id){
        'provider-hes-url'{
'@ @'
    switch($Id){
        'provider-recomps-folder'{
            $root=''
            foreach($entry in @($script:Config.ProviderInstallRoots)){if($null-ne$entry-and[string]::Equals([string](Get-EntryProperty $entry 'Provider' ''),'Recomps',[StringComparison]::OrdinalIgnoreCase)){$root=[string](Get-EntryProperty $entry 'Path' '');break}}
            $picker=@{Mode='PickFolder';Store='Recomps';EntryType='ProviderInstall';ReturnTab=1}
            if($root){$picker.StartPath=$root}
            Start-NativeFilePicker @picker
            return $true
        }
        'provider-recomps-open-folder'{
            $game=Get-SelectedProviderGame
            $path=[string](Get-EntryProperty $game 'InstallPath' (Get-EntryProperty $game 'Path' ''))
            if($path-and(Test-Path -LiteralPath $path -PathType Container)){Start-Process explorer.exe -ArgumentList $path|Out-Null}
            return $true
        }
        'provider-hes-url'{
'@ 'Recomps folder/open actions'
WriteText $providersPath $p

$v7Path=Join-Path $root 'HuymaierGpuPlatformShelves.ps1'
$v=ReadText $v7Path
$v=ReplaceReq $v @'
        'super nintendo entertainment system' {return 'Super Nintendo Entertainment System'}
        default {return $Platform}
'@ @'
        'super nintendo entertainment system' {return 'Super Nintendo Entertainment System'}
        '4' {return 'PS4'}
        'ps4' {return 'PS4'}
        'playstation 4' {return 'PS4'}
        'cd' {return 'Sega CD'}
        'segacd' {return 'Sega CD'}
        'sega cd' {return 'Sega CD'}
        default {return $Platform}
'@ 'PS4/Sega CD canonical names'
$v=ReplaceReq $v @'
[pscustomobject]@{Id=('Recomps:'+$key);Name=$exe.BaseName;Source='Recomps';LaunchTarget=$exe.FullName;Path=$exe.DirectoryName;ArtworkPath='';Installed=$true}
'@ @'
[pscustomobject]@{Id=('Recomps:'+$key);Name=$exe.BaseName;Source='Recomps';Provider='Recomps';LaunchTarget=$exe.FullName;Path=$exe.DirectoryName;InstallPath=$exe.DirectoryName;ArtworkPath='';Installed=$true;Description=('Native recomp build at '+$exe.DirectoryName)}
'@ 'root recomp provider fields'
$v=ReplaceReq $v @'
[pscustomobject]@{Id=('Recomps:'+$key);Name=$dir.Name;Source='Recomps';LaunchTarget=$exe.FullName;Path=$dir.FullName;ArtworkPath='';Installed=$true}
'@ @'
[pscustomobject]@{Id=('Recomps:'+$key);Name=$dir.Name;Source='Recomps';Provider='Recomps';LaunchTarget=$exe.FullName;Path=$dir.FullName;InstallPath=$dir.FullName;ArtworkPath='';Installed=$true;Description=('Native recomp build at '+$dir.FullName)}
'@ 'folder recomp provider fields'
WriteText $v7Path $v

Write-Host 'namingRecompsPatchGate: success'
