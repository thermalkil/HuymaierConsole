# Huymaier Console manual Recomps library.
# Recomps are intentionally explicit: the user adds one native .exe at a time.
# No folder scanning, executable guessing, or emulator-platform reassignment occurs.
Set-StrictMode -Version 2.0

if(Get-Variable HcManualRecompsInstalled -Scope Script -ErrorAction SilentlyContinue){return}
$script:HcManualRecompsInstalled=$true

$script:HcManualRecompsBaseGetGameProviderDefinitions=${function:Get-GameProviderDefinitions}
$script:HcManualRecompsBaseGetProviderCatalogNode=${function:Get-ProviderCatalogNode}
$script:HcManualRecompsBaseAddProviderControlRail=${function:Add-ProviderControlRail}
$script:HcManualRecompsBaseRenderGameProviderStore=${function:Render-GameProviderStore}
$script:HcManualRecompsBaseGetGameProviderPageDefinition=${function:Get-GameProviderPageDefinition}
$script:HcManualRecompsBaseInvokeGameProviderAction=${function:Invoke-GameProviderAction}
$script:HcManualRecompsBaseCompleteProviderConfirmation=${function:Complete-ProviderConfirmation}
$script:HcManualRecompsBaseCompleteNativeFileSelection=${function:Complete-NativeFileSelection}
$script:HcManualRecompsBaseGetPageDefinition=${function:Get-PageDefinition}
$script:HcManualRecompsBaseInvokeAction=${function:Invoke-Action}
$script:HcManualRecompsBaseGetFileBrowserItems=${function:Get-FileBrowserItems}

function Initialize-HcManualRecompConfig {
    if($null -eq $script:Config.PSObject.Properties['RecompGames']){
        # The legacy core config loader does not know this new property yet. Read
        # it directly from config.json so the manual list survives every restart.
        $persisted=@()
        try{
            if($script:ConfigPath -and (Test-Path -LiteralPath $script:ConfigPath -PathType Leaf)){
                $disk=Get-Content -Raw -LiteralPath $script:ConfigPath -Encoding UTF8|ConvertFrom-Json
                if($null-ne$disk -and $null-ne$disk.PSObject.Properties['RecompGames']){$persisted=Convert-ToStableArray $disk.RecompGames}
            }
        }catch{Write-Log "Manual Recomps config recovery skipped: $($_.Exception.Message)" 'WARN'}
        $script:Config|Add-Member -NotePropertyName RecompGames -NotePropertyValue $persisted -Force
    }
    $script:Config.RecompGames=Convert-ToStableArray $script:Config.RecompGames
}

function Get-HcManualRecompGames {
    Initialize-HcManualRecompConfig
    $games=New-Object System.Collections.ArrayList
    foreach($saved in @($script:Config.RecompGames)){
        if($null -eq $saved){continue}
        $target=[string](Get-EntryProperty $saved 'LaunchTarget' (Get-EntryProperty $saved 'Path' ''))
        if([string]::IsNullOrWhiteSpace($target)){continue}
        try{$target=[IO.Path]::GetFullPath([Environment]::ExpandEnvironmentVariables($target))}catch{}
        $id=[string](Get-EntryProperty $saved 'Id' '')
        if([string]::IsNullOrWhiteSpace($id)){$id='Recomps:'+([guid]::NewGuid().ToString('N'))}
        $name=[string](Get-EntryProperty $saved 'Name' '')
        if([string]::IsNullOrWhiteSpace($name)){$name=[IO.Path]::GetFileNameWithoutExtension($target)}
        $dir='';try{$dir=[IO.Path]::GetDirectoryName($target)}catch{}
        $exists=Test-Path -LiteralPath $target -PathType Leaf
        $art=[string](Get-EntryProperty $saved 'ArtworkPath' '')
        [void]$games.Add([pscustomobject]@{
            Id=$id
            Name=$name
            Source='Recomps'
            Provider='Recomps'
            ProviderGameId=$id
            LaunchTarget=$target
            Path=$dir
            InstallPath=$dir
            ArtworkPath=$art
            Installed=[bool]$exists
            Description=$(if($exists){'Manually added native recomp: '+$target}else{'Executable not found: '+$target})
            Added=[string](Get-EntryProperty $saved 'Added' '')
        })
    }
    return [object[]]$games.ToArray()
}

# V7 and the provider layer both consume this name. Owning it here makes the
# manual list authoritative even when an old Recomps root remains in config.
function Get-HcRecompGames {
    return [object[]]@(Get-HcManualRecompGames)
}

function Add-HcManualRecompExecutable {
    param([string]$Path)
    if([string]::IsNullOrWhiteSpace($Path)){return $null}
    try{$full=[IO.Path]::GetFullPath([Environment]::ExpandEnvironmentVariables($Path))}catch{$full=$Path}
    if(-not [string]::Equals([IO.Path]::GetExtension($full),'.exe',[StringComparison]::OrdinalIgnoreCase)){
        Set-ConsoleNotice 'Recomps accepts executable (.exe) files only.' 'WARN'
        return $null
    }
    if(-not(Test-Path -LiteralPath $full -PathType Leaf)){
        Set-ConsoleNotice 'The selected recomp executable could not be found.' 'ERROR'
        return $null
    }
    Initialize-HcManualRecompConfig
    foreach($saved in @($script:Config.RecompGames)){
        $existing=[string](Get-EntryProperty $saved 'LaunchTarget' (Get-EntryProperty $saved 'Path' ''))
        if($existing -and [string]::Equals($existing,$full,[StringComparison]::OrdinalIgnoreCase)){
            Set-ConsoleNotice "$([IO.Path]::GetFileNameWithoutExtension($full)) is already in Recomps." 'INFO'
            return $saved
        }
    }
    $record=[pscustomobject]@{
        Id='Recomps:'+([guid]::NewGuid().ToString('N'))
        Name=[IO.Path]::GetFileNameWithoutExtension($full)
        LaunchTarget=$full
        ArtworkPath=''
        Added=(Get-Date).ToString('o')
    }
    $list=New-Object System.Collections.ArrayList
    foreach($saved in @($script:Config.RecompGames)){if($null-ne$saved){[void]$list.Add($saved)}}
    [void]$list.Add($record)
    $script:Config.RecompGames=[object[]]$list.ToArray()
    Save-Config
    Set-ConsoleNotice "Added $($record.Name) to Recomps." 'INFO'
    return $record
}

function Remove-HcManualRecompGame {
    param([string]$Id)
    Initialize-HcManualRecompConfig
    if([string]::IsNullOrWhiteSpace($Id)){return $false}
    $removed=$null;$kept=New-Object System.Collections.ArrayList
    foreach($saved in @($script:Config.RecompGames)){
        if($null-eq$saved){continue}
        if($null-eq$removed -and [string]::Equals([string](Get-EntryProperty $saved 'Id' ''),$Id,[StringComparison]::OrdinalIgnoreCase)){$removed=$saved;continue}
        [void]$kept.Add($saved)
    }
    if($null-eq$removed){return $false}
    $script:Config.RecompGames=[object[]]$kept.ToArray()

    # Removing a library entry must not leave a stale launcher in Recently Played.
    $target=[string](Get-EntryProperty $removed 'LaunchTarget' '')
    $recent=New-Object System.Collections.ArrayList
    foreach($entry in @(Get-EntryProperty $script:Config 'RecentGames' @())){
        if($null-eq$entry){continue}
        $entryId=[string](Get-EntryProperty $entry 'Id' '')
        $entryTarget=[string](Get-EntryProperty $entry 'LaunchTarget' '')
        $isSame=[string]::Equals($entryId,$Id,[StringComparison]::OrdinalIgnoreCase)
        if((-not $isSame) -and $target){$isSame=[string]::Equals($entryTarget,$target,[StringComparison]::OrdinalIgnoreCase)}
        if(-not $isSame){[void]$recent.Add($entry)}
    }
    if($null-ne$script:Config.PSObject.Properties['RecentGames']){$script:Config.RecentGames=[object[]]$recent.ToArray()}

    if($null-ne$script:Config.PSObject.Properties['FavoriteGames']){
        $favorites=New-Object System.Collections.ArrayList
        foreach($favorite in @($script:Config.FavoriteGames)){
            if(-not [string]::Equals([string]$favorite,$Id,[StringComparison]::OrdinalIgnoreCase)){[void]$favorites.Add($favorite)}
        }
        $script:Config.FavoriteGames=[object[]]$favorites.ToArray()
    }
    Save-Config
    $name=[string](Get-EntryProperty $removed 'Name' 'Recomp game')
    Set-ConsoleNotice "Removed $name from Recomps. No game files were deleted." 'INFO'
    return $true
}

function Get-GameProviderDefinitions {
    $result=New-Object System.Collections.ArrayList
    foreach($definition in @(& $script:HcManualRecompsBaseGetGameProviderDefinitions)){
        if($null-eq$definition){continue}
        if([string]::Equals([string](Get-EntryProperty $definition 'Id' ''),'Recomps',[StringComparison]::OrdinalIgnoreCase)){
            [void]$result.Add([pscustomobject]@{Id='Recomps';Name='Recomps';Backend='Native';Description='Manually added native recomp games. Choose one executable at a time.';Glyph='RECOMP'})
        }else{[void]$result.Add($definition)}
    }
    return [object[]]$result.ToArray()
}

function Get-ProviderCatalogNode {
    param([string]$Provider)
    if([string]::Equals($Provider,'Recomps',[StringComparison]::OrdinalIgnoreCase)){
        $games=@(Get-HcManualRecompGames)
        return [pscustomobject]@{
            Id='Recomps';Name='Recomps';Backend='Native';ToolReady=$true;Authenticated=$true;ToolPath=''
            Status=("$($games.Count) manually added recomp game(s).")
            Error='';Games=$games;Updated=(Get-Date).ToString('o')
        }
    }
    return (& $script:HcManualRecompsBaseGetProviderCatalogNode $Provider)
}

function Add-ProviderControlRail {
    param([string]$Provider)
    if(-not [string]::Equals($Provider,'Recomps',[StringComparison]::OrdinalIgnoreCase)){
        & $script:HcManualRecompsBaseAddProviderControlRail $Provider
        return
    }
    $games=@(Get-HcManualRecompGames)
    $heading=New-Object System.Windows.Controls.TextBlock
    $heading.Text='Recomps Management';$heading.FontSize=25;$heading.FontWeight='SemiBold';$heading.Margin='0,0,0,12';$heading.Foreground='#F5F7FB'
    $script:ActionPanel.Children.Add($heading)|Out-Null
    $start=$script:ActionButtons.Count
    $row=New-Object System.Windows.Controls.StackPanel;$row.Orientation='Horizontal'
    $choices=@(
        [pscustomobject]@{Id='provider-recomps-add';Glyph='ADD';Title=$(if($games.Count){'Add Another Recomp Game'}else{'Add Recomp Game'});Subtitle='Select one native game executable (.exe). Existing Recomps entries are kept.'},
        [pscustomobject]@{Id='provider-back';Glyph='BACK';Title='Platform Menu';Subtitle="Recomps library: $($games.Count) game(s)."}
    )
    foreach($choice in $choices){
        $button=New-ProviderControlCard $choice.Id $choice.Glyph $choice.Title $choice.Subtitle
        $row.Children.Add($button)|Out-Null;$script:ActionButtons+=$button;$script:CurrentActions+=(New-Action $choice.Id $choice.Title $choice.Subtitle)
    }
    $scroll=New-Object System.Windows.Controls.ScrollViewer;$scroll.HorizontalScrollBarVisibility='Hidden';$scroll.VerticalScrollBarVisibility='Disabled';$scroll.PanningMode='HorizontalOnly';$scroll.Content=$row;$scroll.Margin='0,0,0,20'
    $script:ActionPanel.Children.Add($scroll)|Out-Null
    $script:HomeRows+=,[pscustomobject]@{Start=$start;Count=$choices.Count;Platform=$false}
}

function Render-GameProviderStore {
    param([string]$Provider)
    if(-not [string]::Equals($Provider,'Recomps',[StringComparison]::OrdinalIgnoreCase)){
        & $script:HcManualRecompsBaseRenderGameProviderStore $Provider
        return
    }
    $script:ProviderGameEntries=@()
    Add-ProviderControlRail 'Recomps'
    Add-ProviderGameRail 'Recomp Games' @(Get-HcManualRecompGames) 'No recomp games have been added. Choose Add Recomp Game and select a game .exe.'
}

function Get-GameProviderPageDefinition {
    if($script:SubPage -eq 'ProviderGame'){
        $game=Get-SelectedProviderGame
        if($null-ne$game -and [string]::Equals([string](Get-EntryProperty $game 'Provider' ''),'Recomps',[StringComparison]::OrdinalIgnoreCase)){
            $name=[string](Get-EntryProperty $game 'Name' 'Recomp game')
            $target=[string](Get-EntryProperty $game 'LaunchTarget' '')
            $exists=$target -and (Test-Path -LiteralPath $target -PathType Leaf)
            $actions=New-Object System.Collections.Generic.List[object]
            if($exists){$actions.Add((New-Action 'provider-game-launch' 'Launch' "Start $name using the exact executable you selected."))}
            $actions.Add((New-Action 'provider-recomps-open-folder' 'Open game folder' 'Open the folder containing the selected executable.'))
            $actions.Add((New-Action 'provider-recomps-remove' 'Remove from Recomps' 'Remove only this Huymaier Console library entry. The game files stay untouched.'))
            $actions.Add((New-Action 'provider-game-back' 'Back to Recomps'))
            return [pscustomobject]@{
                Title=$name;Subtitle='Manually added native recomp';Hero=$(if($exists){'READY'}else{'EXE NOT FOUND'})
                HeroText=$(if($exists){$target}else{"The saved executable is missing or moved.`n$target"})
                Actions=[object[]]$actions.ToArray()
            }
        }
    }
    return (& $script:HcManualRecompsBaseGetGameProviderPageDefinition)
}

# HUYMAIER_RECOMPS_EXE_PICKER_VISIBILITY_V2
# The generic native browser intentionally hides some protected entries. Recomps
# must be able to select the exact game EXE, so merge every visible/hidden .exe
# from the current directory back into the picker results without broadening the
# accepted file type. This also makes the manual picker independent of generic
# PickExecutable filtering quirks.
function Get-FileBrowserItems {
    $base=[object[]]@(& $script:HcManualRecompsBaseGetFileBrowserItems)
    if(-not [string]::Equals([string]$script:FileBrowserEntryType,'RecompGame',[StringComparison]::OrdinalIgnoreCase) -or
       -not [string]::Equals([string]$script:FileBrowserMode,'PickExecutable',[StringComparison]::OrdinalIgnoreCase) -or
       [string]::IsNullOrWhiteSpace([string]$script:FileBrowserPath)){return $base}

    $items=New-Object System.Collections.ArrayList
    $seen=@{}
    foreach($entry in @($base)){
        if($null-eq$entry){continue}
        $type=[string](Get-EntryProperty $entry 'Type' '')
        $full=[string](Get-EntryProperty $entry 'FullName' '')
        if([string]::Equals($type,'File',[StringComparison]::OrdinalIgnoreCase)){
            $extension=[string](Get-EntryProperty $entry 'Extension' '')
            if([string]::IsNullOrWhiteSpace($extension) -and $full){try{$extension=[IO.Path]::GetExtension($full)}catch{}}
            if(-not [string]::Equals($extension,'.exe',[StringComparison]::OrdinalIgnoreCase)){continue}
        }
        [void]$items.Add($entry)
        if($full){$seen[$full.ToLowerInvariant()]=$true}
    }
    try{
        foreach($exe in @(Get-ChildItem -LiteralPath $script:FileBrowserPath -Force -File -Filter '*.exe' -ErrorAction Stop|Sort-Object Name)){
            if($null-eq$exe){continue}
            $full=[string]$exe.FullName
            if([string]::IsNullOrWhiteSpace($full)){continue}
            $key=$full.ToLowerInvariant()
            if($seen.ContainsKey($key)){continue}
            $seen[$key]=$true
            [void]$items.Add([pscustomobject]@{
                Type='File';Name=[string]$exe.Name;FullName=$full
                Description="$(Format-FileSize ([long]$exe.Length))  |  $($exe.LastWriteTime.ToString('g'))"
                Extension='.exe';Length=[long]$exe.Length
            })
        }
    }catch{try{Write-Log ("Recomps picker could not enumerate executables in '$($script:FileBrowserPath)': "+$_.Exception.Message) 'WARN'}catch{}}
    return [object[]]$items.ToArray()
}

function Start-HcManualRecompPicker {
    $script:SelectedGamePlatform='Recomps'
    Start-NativeFilePicker -Mode PickExecutable -Store 'Recomps' -EntryType 'RecompGame' -ReturnTab 1
}

function Invoke-GameProviderAction {
    param([string]$Id)
    switch($Id){
        'provider-recomps-add'{Start-HcManualRecompPicker;return $true}
        'provider-recomps-folder'{Start-HcManualRecompPicker;return $true}
        'provider-refresh:Recomps'{Render-Page;Set-ConsoleNotice 'Recomps is a manual library; there is no folder scan.' 'INFO';return $true}
        'provider-recomps-open-folder'{
            $game=Get-SelectedProviderGame;$target=[string](Get-EntryProperty $game 'LaunchTarget' '')
            $dir='';if($target){try{$dir=[IO.Path]::GetDirectoryName($target)}catch{}}
            if($dir -and (Test-Path -LiteralPath $dir -PathType Container)){Start-Process explorer.exe -ArgumentList $dir|Out-Null}
            else{Set-ConsoleNotice 'The saved recomp game folder could not be found.' 'WARN'}
            return $true
        }
        'provider-recomps-remove'{
            $game=Get-SelectedProviderGame
            if($null-eq$game){return $true}
            $id=[string](Get-EntryProperty $game 'Id' '');$name=[string](Get-EntryProperty $game 'Name' 'this recomp game')
            Request-NativeConfirmation ("provider-recomp-remove:"+$id) ("Remove $name from Recomps? The executable and all game files will remain on disk.")
            return $true
        }
    }
    return (& $script:HcManualRecompsBaseInvokeGameProviderAction $Id)
}

function Complete-ProviderConfirmation {
    param([string]$Action)
    if($Action -match '^provider-recomp-remove:(.+)$'){
        [void](Remove-HcManualRecompGame ([string]$matches[1]))
        $script:SelectedProviderGame=$null;$script:SelectedGamePlatform='Recomps';$script:SelectedTab=1;$script:SubPage='ProviderStore';$script:SelectedAction=0
        Render-Page;Update-NavVisuals
        return $true
    }
    return (& $script:HcManualRecompsBaseCompleteProviderConfirmation $Action)
}

function Complete-NativeFileSelection {
    param($Entry)
    if([string]::Equals([string]$script:FileBrowserEntryType,'RecompGame',[StringComparison]::OrdinalIgnoreCase)){
        if($null-eq$Entry -or [string](Get-EntryProperty $Entry 'Type' '') -ne 'File'){return}
        $path=[string](Get-EntryProperty $Entry 'FullName' '')
        if(-not [string]::Equals([IO.Path]::GetExtension($path),'.exe',[StringComparison]::OrdinalIgnoreCase)){
            Set-ConsoleNotice 'Choose the recomp game executable (.exe).' 'WARN';Render-Page;return
        }
        $saved=Add-HcManualRecompExecutable $path
        if($null-eq$saved){Render-Page;return}
        $script:SelectedGamePlatform='Recomps';$script:SelectedTab=$script:FileBrowserReturnTab;$script:SubPage=$script:FileBrowserReturnSubPage
        if([string]::IsNullOrWhiteSpace([string]$script:SubPage) -or $script:SubPage -eq 'FilePicker'){$script:SubPage='ProviderStore'}
        $script:SelectedAction=0
        Render-Page;Update-NavVisuals
        return
    }
    & $script:HcManualRecompsBaseCompleteNativeFileSelection $Entry
}

# Remove the obsolete root-folder setting from Settings. If a stale UI/action
# invokes it anyway, route it to the manual one-EXE picker instead.
function Get-PageDefinition {
    param([int]$Index)
    $page=& $script:HcManualRecompsBaseGetPageDefinition $Index
    if($Index -eq 7 -and $null-ne$page -and $null-ne$page.PSObject.Properties['Actions']){
        $filtered=New-Object System.Collections.ArrayList
        foreach($action in @($page.Actions)){
            if($null-eq$action){continue}
            if([string]::Equals([string](Get-EntryProperty $action 'Id' ''),'recomps-root',[StringComparison]::OrdinalIgnoreCase)){continue}
            [void]$filtered.Add($action)
        }
        $page.Actions=[object[]]$filtered.ToArray()
    }
    return $page
}

function Invoke-Action {
    param([string]$Id)
    if([string]::Equals($Id,'recomps-root',[StringComparison]::OrdinalIgnoreCase)){
        Start-HcManualRecompPicker
        return
    }
    & $script:HcManualRecompsBaseInvokeAction $Id
}

Initialize-HcManualRecompConfig
