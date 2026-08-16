# Huymaier Console simple manual Recomps library.
# Loaded after V7 GPU shelves. Recomps deliberately bypasses the generic
# provider/platform-choice UI: selecting Recomps opens one explicit EXE library.
Set-StrictMode -Version 2.0

if(-not(Get-Command Get-HcManualRecompGames -ErrorAction SilentlyContinue)){throw 'Manual Recomps runtime was not loaded before final ownership.'}
if(Get-Variable HcRecompsSimpleLibraryInstalled -Scope Script -ErrorAction SilentlyContinue){return}
$script:HcRecompsSimpleLibraryInstalled=$true

# Capture the actual post-V7 owners and wrap only Recomps behavior. Do not fall
# back to pre-V7 snapshots because that can silently undo unrelated shelf fixes.
$script:HcRecompsSimpleBaseRenderGamesHub=${function:Render-GamesHub}
$script:HcRecompsSimpleBaseInvokeAction=${function:Invoke-Action}
$script:HcRecompsSimpleBaseHandleBack=${function:Handle-Back}
$script:HcRecompsSimpleBaseGetPageDefinition=${function:Get-PageDefinition}
$script:HcRecompsSimpleBaseCompleteProviderConfirmation=${function:Complete-ProviderConfirmation}
$script:HcRecompsSimpleBaseCompleteNativeFileSelection=${function:Complete-NativeFileSelection}
$script:HcRecompPageEntries=@()
$script:HcSelectedRecompId=''
$script:HcManualRecompsFinalOwner='HuymaierRecompsFinal.SimpleLibrary'

function Get-HcRecompGames {
    return [object[]]@(Get-HcManualRecompGames)
}

function Get-HcSelectedRecompGame {
    $id=[string]$script:HcSelectedRecompId
    if([string]::IsNullOrWhiteSpace($id)){return $null}
    foreach($game in @(Get-HcManualRecompGames)){
        if([string]::Equals([string](Get-EntryProperty $game 'Id' ''),$id,[StringComparison]::OrdinalIgnoreCase)){return $game}
    }
    return $null
}

function New-HcRecompCommandCard {
    param([string]$Id,[string]$Title,[string]$Subtitle,[string]$Glyph='')
    $button=New-Object System.Windows.Controls.Button
    $button.Tag=$Id;$button.Width=244;$button.Height=132;$button.Margin='0,0,18,12';$button.Padding='0'
    $button.HorizontalContentAlignment='Stretch';$button.VerticalContentAlignment='Stretch'
    $button.Background='#8D101927';$button.BorderBrush='#33445E';$button.BorderThickness='1';$button.RenderTransformOrigin='0.5,0.5';$button.Cursor='Hand'
    $button.Template=[Windows.Markup.XamlReader]::Parse('<ControlTemplate xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" TargetType="Button"><Border Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="17" ClipToBounds="True"><ContentPresenter/></Border></ControlTemplate>')
    $grid=New-Object System.Windows.Controls.Grid;$grid.Margin='18,15,18,14'
    $grid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition -Property @{Height='Auto'}))
    $grid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition -Property @{Height='Auto'}))
    $grid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition -Property @{Height='*'}))
    if($Glyph){$g=New-Object System.Windows.Controls.TextBlock;$g.Text=$Glyph;$g.FontSize=11;$g.FontWeight='Bold';$g.Foreground='#E7C45E';$g.Margin='0,0,0,8';[System.Windows.Controls.Grid]::SetRow($g,0);$grid.Children.Add($g)|Out-Null}
    $title=New-Object System.Windows.Controls.TextBlock;$title.Text=$Title;$title.FontSize=21;$title.FontWeight='Bold';$title.Foreground='White';$title.TextWrapping='Wrap';[System.Windows.Controls.Grid]::SetRow($title,1);$grid.Children.Add($title)|Out-Null
    $sub=New-Object System.Windows.Controls.TextBlock;$sub.Text=$Subtitle;$sub.FontSize=12;$sub.Foreground='#AEBBD0';$sub.TextWrapping='Wrap';$sub.LineHeight=17;$sub.MaxHeight=38;$sub.Margin='0,6,0,0';[System.Windows.Controls.Grid]::SetRow($sub,2);$grid.Children.Add($sub)|Out-Null
    $button.Content=$grid
    $button.Add_Click({param($sender,$eventArgs)Invoke-UiFeedback 'Confirm';Invoke-Action ([string]$sender.Tag)})
    $button.Add_MouseEnter({param($sender,$eventArgs)if(-not(Test-HcMouseHoverAllowed)){return};Set-KeyboardActive;$idx=[array]::IndexOf($script:ActionButtons,$sender);if($idx-ge0){$script:SelectedAction=$idx;Update-ActionVisuals}})
    return $button
}

function Add-HcRecompCommandRow {
    param([object[]]$Commands)
    $commands=Convert-ToStableArray $Commands
    if($commands.Count-eq0){return}
    $start=$script:ActionButtons.Count
    $row=New-Object System.Windows.Controls.StackPanel;$row.Orientation='Horizontal';$row.Margin='0,0,20,6'
    foreach($command in $commands){
        $button=New-HcRecompCommandCard ([string]$command.Id) ([string]$command.Title) ([string]$command.Subtitle) ([string]$command.Glyph)
        $row.Children.Add($button)|Out-Null;$script:ActionButtons+=$button;$script:CurrentActions+=(New-Action ([string]$command.Id) ([string]$command.Title) ([string]$command.Subtitle))
    }
    $scroll=New-Object System.Windows.Controls.ScrollViewer;$scroll.HorizontalScrollBarVisibility='Hidden';$scroll.VerticalScrollBarVisibility='Disabled';$scroll.PanningMode='HorizontalOnly';$scroll.Content=$row;$scroll.Margin='0,0,0,18'
    $script:ActionPanel.Children.Add($scroll)|Out-Null
    $script:HomeRows+=,[pscustomobject]@{Start=$start;Count=$commands.Count;Platform=$false}
}

function Add-HcRecompHeader {
    param([string]$Title,[string]$Subtitle='')
    $stack=New-Object System.Windows.Controls.StackPanel;$stack.Margin='0,0,0,18'
    $eyebrow=New-Object System.Windows.Controls.TextBlock;$eyebrow.Text='RECOMPS';$eyebrow.FontSize=12;$eyebrow.FontWeight='Bold';$eyebrow.Foreground='#E7C45E';$stack.Children.Add($eyebrow)|Out-Null
    $title=New-Object System.Windows.Controls.TextBlock;$title.Text=$Title;$title.FontSize=32;$title.FontWeight='Bold';$title.Foreground='#F5F7FB';$title.Margin='0,5,0,0';$stack.Children.Add($title)|Out-Null
    if($Subtitle){$sub=New-Object System.Windows.Controls.TextBlock;$sub.Text=$Subtitle;$sub.FontSize=14;$sub.Foreground='#AAB7C9';$sub.Margin='0,6,0,0';$sub.TextWrapping='Wrap';$stack.Children.Add($sub)|Out-Null}
    $script:ActionPanel.Children.Add($stack)|Out-Null
}

function Render-HcRecompsLibrary {
    $script:HcRecompsLastRendered='Library'
    $script:GameHubLaunchEntries=@()
    $script:HcRecompPageEntries=@(Get-HcManualRecompGames)
    Add-HcRecompHeader 'Recomps' 'Manual native games only. Add each game by selecting its exact .exe file.'
    Add-HcRecompCommandRow @(
        [pscustomobject]@{Id='recomps-add-game';Title='Add Recomp Game';Subtitle='Choose one game executable (.exe). Existing entries stay in the library.';Glyph='ADD'},
        [pscustomobject]@{Id='recomps-platforms';Title='Back to Platforms';Subtitle=("$($script:HcRecompPageEntries.Count) recomp game(s) saved.");Glyph='BACK'}
    )
    $heading=New-Object System.Windows.Controls.TextBlock;$heading.Text='Your Recomp Games';$heading.FontSize=23;$heading.FontWeight='SemiBold';$heading.Margin='0,2,0,11';$heading.Foreground='#F5F7FB';$script:ActionPanel.Children.Add($heading)|Out-Null
    if($script:HcRecompPageEntries.Count-eq0){
        $empty=New-Object System.Windows.Controls.Border;$empty.Height=112;$empty.CornerRadius=14;$empty.Background='#7A101827';$empty.BorderBrush='#2B3A51';$empty.BorderThickness=1;$empty.Margin='0,0,0,20'
        $tb=New-Object System.Windows.Controls.TextBlock;$tb.Text='No recomp games added yet. Choose Add Recomp Game, then select the game executable.';$tb.FontSize=16;$tb.Foreground='#AAB7C9';$tb.VerticalAlignment='Center';$tb.HorizontalAlignment='Center';$tb.TextWrapping='Wrap';$tb.Margin='30';$empty.Child=$tb;$script:ActionPanel.Children.Add($empty)|Out-Null
        return
    }
    $start=$script:ActionButtons.Count
    $row=New-Object System.Windows.Controls.StackPanel;$row.Orientation='Horizontal';$row.Margin='0,0,20,0'
    for($i=0;$i-lt$script:HcRecompPageEntries.Count;$i++){
        $entry=$script:HcRecompPageEntries[$i]
        $button=New-HomeCard $entry ("recomp-open:$i") 'Recomps Apps'
        $row.Children.Add($button)|Out-Null;$script:ActionButtons+=$button;$script:CurrentActions+=(New-Action ("recomp-open:$i") ([string](Get-EntryProperty $entry 'Name' 'Recomp Game')))
    }
    $scroll=New-Object System.Windows.Controls.ScrollViewer;$scroll.HorizontalScrollBarVisibility='Hidden';$scroll.VerticalScrollBarVisibility='Disabled';$scroll.PanningMode='HorizontalOnly';$scroll.Content=$row;$scroll.Margin='0,0,0,18';$script:ActionPanel.Children.Add($scroll)|Out-Null
    $script:HomeRows+=,[pscustomobject]@{Start=$start;Count=$script:HcRecompPageEntries.Count;Platform=$false}
}

function Render-HcRecompGame {
    $script:HcRecompsLastRendered='Game'
    $game=Get-HcSelectedRecompGame
    if($null-eq$game){$script:SubPage='RecompsLibrary';Render-HcRecompsLibrary;return}
    $name=[string](Get-EntryProperty $game 'Name' 'Recomp Game')
    $target=[string](Get-EntryProperty $game 'LaunchTarget' '')
    $exists=$target-and(Test-Path -LiteralPath $target -PathType Leaf)
    Add-HcRecompHeader $name $(if($exists){$target}else{"Executable not found or moved:`n$target"})
    $commands=New-Object System.Collections.ArrayList
    if($exists){[void]$commands.Add([pscustomobject]@{Id='recomp-launch';Title='Launch';Subtitle='Start the exact executable saved for this game.';Glyph='PLAY'})}
    [void]$commands.Add([pscustomobject]@{Id='recomp-open-folder';Title='Open Folder';Subtitle='Open the folder containing this executable.';Glyph='FOLDER'})
    [void]$commands.Add([pscustomobject]@{Id='recomp-remove';Title='Remove from Recomps';Subtitle='Remove this library entry only. Game files are never deleted.';Glyph='REMOVE'})
    [void]$commands.Add([pscustomobject]@{Id='recomp-back';Title='Back';Subtitle='Return to your Recomps library.';Glyph='BACK'})
    Add-HcRecompCommandRow ([object[]]$commands.ToArray())
}

function Render-GamesHub {
    if([string]::Equals([string]$script:SelectedGamePlatform,'Recomps',[StringComparison]::OrdinalIgnoreCase)){
        # Normalize every historical Recomps provider/platform page into the
        # simple manual library. This also fixes stale navigation restored from
        # older builds.
        if($script:SubPage -in @('PlatformChoice','ProviderStore','PlatformHome','PlatformShelf','PlatformLibrary')){$script:SubPage='RecompsLibrary'}
        if($script:SubPage -eq 'ProviderGame'){
            try{$legacy=Get-SelectedProviderGame;if($null-ne$legacy){$script:HcSelectedRecompId=[string](Get-EntryProperty $legacy 'Id' '')}}catch{}
            $script:SubPage='RecompsGame'
        }
        if($script:SubPage -eq 'RecompsLibrary'){Render-HcRecompsLibrary;return}
        if($script:SubPage -eq 'RecompsGame'){Render-HcRecompGame;return}
    }
    & $script:HcRecompsSimpleBaseRenderGamesHub
}

function Invoke-Action {
    param([string]$Id)
    if($Id -match '^platform-select:(\d+)$'){
        $index=[int]$matches[1]
        if($index-ge0-and$index-lt$script:GameHubPlatforms.Count){
            $platform=[string]$script:GameHubPlatforms[$index]
            if([string]::Equals($platform,'Recomps',[StringComparison]::OrdinalIgnoreCase)){
                $script:SelectedGamePlatform='Recomps';$script:SelectedTab=1;$script:SubPage='RecompsLibrary';$script:SelectedAction=0;$script:HcSelectedRecompId='';Render-Page;return
            }
        }
    }
    if([string]::Equals([string]$script:SelectedGamePlatform,'Recomps',[StringComparison]::OrdinalIgnoreCase)){
        switch -Regex($Id){
            '^platform-store$|^provider-back$|^provider-refresh:Recomps$|^provider-recomps-folder$' {$script:SubPage='RecompsLibrary';$script:SelectedAction=0;Render-Page;return}
            '^provider-recomps-add$|^recomps-add-game$' {$script:SubPage='RecompsLibrary';Start-HcManualRecompPicker;return}
            '^recomps-platforms$' {$script:SubPage='';$script:SelectedAction=0;$script:HcSelectedRecompId='';Render-Page;return}
            '^recomp-open:(\d+)$' {
                $index=[int]$matches[1]
                if($index-ge0-and$index-lt$script:HcRecompPageEntries.Count){$script:HcSelectedRecompId=[string](Get-EntryProperty $script:HcRecompPageEntries[$index] 'Id' '');$script:SubPage='RecompsGame';$script:SelectedAction=0;Render-Page}
                return
            }
            '^recomp-launch$|^provider-game-launch$' {
                $game=Get-HcSelectedRecompGame
                if($null-eq$game){Set-ConsoleNotice 'The selected recomp game is unavailable.' 'WARN';Render-Page;return}
                $target=[string](Get-EntryProperty $game 'LaunchTarget' '')
                if(-not$target-or-not(Test-Path -LiteralPath $target -PathType Leaf)){Set-ConsoleNotice 'The saved recomp executable could not be found.' 'ERROR';Render-Page;return}
                try{Add-ToRecent 'Game' $game}catch{}
                $dir='';try{$dir=[IO.Path]::GetDirectoryName($target)}catch{}
                Start-ExternalProcess $target @() $dir|Out-Null
                return
            }
            '^recomp-open-folder$|^provider-recomps-open-folder$' {
                $game=Get-HcSelectedRecompGame;$target=[string](Get-EntryProperty $game 'LaunchTarget' '')
                $dir='';if($target){try{$dir=[IO.Path]::GetDirectoryName($target)}catch{}}
                if($dir-and(Test-Path -LiteralPath $dir -PathType Container)){Start-Process explorer.exe -ArgumentList $dir|Out-Null}else{Set-ConsoleNotice 'The saved recomp folder could not be found.' 'WARN';Render-Page}
                return
            }
            '^recomp-remove$|^provider-recomps-remove$' {
                $game=Get-HcSelectedRecompGame
                if($null-eq$game){$script:SubPage='RecompsLibrary';Render-Page;return}
                $rid=[string](Get-EntryProperty $game 'Id' '');$name=[string](Get-EntryProperty $game 'Name' 'this game')
                Request-NativeConfirmation ("recomp-simple-remove:"+$rid) ("Remove $name from Recomps? This removes only the Huymaier Console entry; no game files will be deleted.")
                return
            }
            '^recomp-back$|^provider-game-back$' {$script:SubPage='RecompsLibrary';$script:SelectedAction=0;Render-Page;return}
        }
    }
    & $script:HcRecompsSimpleBaseInvokeAction $Id
}

function Handle-Back {
    if([string]::Equals([string]$script:SelectedGamePlatform,'Recomps',[StringComparison]::OrdinalIgnoreCase)){
        if($script:SubPage -eq 'RecompsGame'){$script:SubPage='RecompsLibrary';$script:SelectedAction=0;Invoke-UiFeedback 'Back';Render-Page;return}
        if($script:SubPage -eq 'RecompsLibrary'){$script:SubPage='';$script:SelectedAction=0;$script:HcSelectedRecompId='';Invoke-UiFeedback 'Back';Render-Page;return}
    }
    & $script:HcRecompsSimpleBaseHandleBack
}

function Complete-ProviderConfirmation {
    param([string]$Action)
    if($Action -match '^recomp-simple-remove:(.+)$'){
        [void](Remove-HcManualRecompGame ([string]$matches[1]))
        $script:HcSelectedRecompId='';$script:SelectedProviderGame=$null;$script:SelectedGamePlatform='Recomps';$script:SelectedTab=1;$script:SubPage='RecompsLibrary';$script:SelectedAction=0
        Render-Page;Update-NavVisuals
        return $true
    }
    return (& $script:HcRecompsSimpleBaseCompleteProviderConfirmation $Action)
}

function Complete-NativeFileSelection {
    param($Entry)
    $isRecomp=[string]::Equals([string]$script:FileBrowserEntryType,'RecompGame',[StringComparison]::OrdinalIgnoreCase)
    & $script:HcRecompsSimpleBaseCompleteNativeFileSelection $Entry
    if($isRecomp){
        $script:SelectedGamePlatform='Recomps';$script:SelectedTab=1;$script:SubPage='RecompsLibrary';$script:SelectedAction=0;$script:HcSelectedRecompId=''
        Render-Page;Update-NavVisuals
    }
}

function Get-PageDefinition {
    param([int]$Index)
    $page=& $script:HcRecompsSimpleBaseGetPageDefinition $Index
    if($Index-eq7-and$null-ne$page-and$null-ne$page.PSObject.Properties['Actions']){
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
