param()
Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
# HUYMAIER_V0308_BACKGROUND_TASK_TRANSFORM_V2
$root=Split-Path -Parent $PSScriptRoot
function Read-Normalized([string]$Path){return ([IO.File]::ReadAllText($Path,[Text.Encoding]::UTF8).Replace("`r`n","`n"))}
function Write-Normalized([string]$Path,[string]$Text){[IO.File]::WriteAllText($Path,$Text.Replace("`n","`r`n"),(New-Object Text.UTF8Encoding($true)))}
function Replace-Required([string]$Text,[string]$Old,[string]$New,[string]$Label){if(-not $Text.Contains($Old)){throw "v0.30.8 background-task transform anchor missing: $Label"};return $Text.Replace($Old,$New)}
$lf="`n"

# Core owns the shell visual tree/runtime watcher. BackgroundTasks owns only the
# task model/presentation behavior and is loaded after Customization.
$corePath=Join-Path $root 'HuymaierConsole.ps1'
$core=Read-Normalized $corePath
if($core -notmatch 'HUYMAIER_V0308_BACKGROUND_TASK_CORE_V2'){
    $anchor='$script:CustomizationModulePath = Join-Path $script:BaseDir ''HuymaierCustomization.ps1'''
    $insert=@($anchor,'$script:BackgroundTasksModulePath = Join-Path $script:BaseDir ''HuymaierBackgroundTasks.ps1'' # HUYMAIER_V0308_BACKGROUND_TASK_CORE_V2') -join $lf
    $core=Replace-Required $core $anchor $insert 'background task module path'

    $anchor=@'
if (Test-Path -LiteralPath $script:CustomizationModulePath) {
    try { . $script:CustomizationModulePath }
    catch { Write-Log "Customization module load failed: $($_.Exception.Message)" 'ERROR' }
}
'@
    $insert=@'
if (Test-Path -LiteralPath $script:CustomizationModulePath) {
    try { . $script:CustomizationModulePath }
    catch { Write-Log "Customization module load failed: $($_.Exception.Message)" 'ERROR' }
}
if (Test-Path -LiteralPath $script:BackgroundTasksModulePath) {
    try { . $script:BackgroundTasksModulePath }
    catch { Write-Log "Background task module load failed: $($_.Exception.Message)" 'ERROR' }
}
'@
    $core=Replace-Required $core $anchor $insert 'background task module load'

    $anchor=@'
                <StackPanel Grid.Column="1" HorizontalAlignment="Right" VerticalAlignment="Center">
                    <TextBlock x:Name="ClockText" Text="--:--" FontSize="25" FontWeight="SemiBold" HorizontalAlignment="Right"/>
                    <TextBlock x:Name="ControllerText" Text="Keyboard / Mouse" FontSize="12" Foreground="#AAB8CC" HorizontalAlignment="Right"/>
                    <TextBlock x:Name="FpsText" Text="FPS --" Visibility="Collapsed" FontSize="12" FontWeight="SemiBold" Foreground="#E7C45E" HorizontalAlignment="Right" Margin="0,3,0,0"/>
                </StackPanel>
'@
    $insert=@'
                <!-- HUYMAIER_V0308_BACKGROUND_TASK_HUD_V2 -->
                <StackPanel Grid.Column="1" HorizontalAlignment="Right" VerticalAlignment="Top" Panel.ZIndex="1700">
                    <TextBlock x:Name="ClockText" Text="--:--" FontSize="25" FontWeight="SemiBold" HorizontalAlignment="Right"/>
                    <TextBlock x:Name="ControllerText" Text="Keyboard / Mouse" FontSize="12" Foreground="#AAB8CC" HorizontalAlignment="Right"/>
                    <TextBlock x:Name="FpsText" Text="FPS --" Visibility="Collapsed" FontSize="12" FontWeight="SemiBold" Foreground="#E7C45E" HorizontalAlignment="Right" Margin="0,3,0,0"/>
                    <Border x:Name="BackgroundTaskHud" Visibility="Collapsed" IsHitTestVisible="False" Width="410" HorizontalAlignment="Right" Margin="0,8,0,0" Padding="12,9" Background="#EE0A101A" BorderBrush="#506077" BorderThickness="1" CornerRadius="10">
                        <StackPanel x:Name="BackgroundTaskPanel"/>
                    </Border>
                </StackPanel>
'@
    $core=Replace-Required $core $anchor $insert 'top-right task HUD XAML'

    $core=Replace-Required $core "'ClockText','ControllerText','FpsText','NavPanel'" "'ClockText','ControllerText','FpsText','BackgroundTaskHud','BackgroundTaskPanel','NavPanel'" 'task HUD named controls'

    $anchor=@'
            Update-HcRuntimeStateEvents
            Invoke-HcIncrementalConsoleCountRefresh
'@
    $insert=@'
            Update-HcRuntimeStateEvents
            # HUYMAIER_V0308_BACKGROUND_TASK_WATCHER_V2
            # Artwork state is consumed from the existing FileSystemWatcher dirty
            # map. The HUD never adds a second JSON polling loop to the UI thread.
            if(Test-HcRuntimePathDirty $script:ArtworkStatePath){
                try{$script:HcBackgroundArtworkState=Read-ArtworkState}catch{$script:HcBackgroundArtworkState=$null}
            }
            if(Get-Command Update-HcBackgroundTaskHud -ErrorAction SilentlyContinue){Update-HcBackgroundTaskHud}
            Invoke-HcIncrementalConsoleCountRefresh
'@
    $core=Replace-Required $core $anchor $insert 'task state watcher integration'

    $anchor="        'artwork-refresh' { Start-OnlineArtworkScan -ResetCursor;Set-ConsoleNotice 'Missing box art is being refreshed in the background.' 'INFO';Render-Page }"
    $insert="        'artwork-refresh' { if(Get-Command Start-HcLibraryAndArtworkRefresh -ErrorAction SilentlyContinue){Start-HcLibraryAndArtworkRefresh}else{Start-OnlineArtworkScan -ResetCursor;Set-ConsoleNotice 'Missing box art is being refreshed in the background.' 'INFO';Render-Page} }"
    $core=Replace-Required $core $anchor $insert 'settings artwork refresh sequencing'
}
Write-Normalized $corePath $core

# The active Storefront Manage refresh had been launching library import and art
# discovery at the same instant. Route it through the same sequenced coordinator.
$shellPath=Join-Path $root 'HuymaierShellRedesign.ps1'
$shell=Read-Normalized $shellPath
if($shell -notmatch 'HUYMAIER_V0308_SEQUENCED_ARTWORK_REFRESH_V2'){
    $anchor="        '^storefront-manage-refresh:(.+)$' {if(Get-Command Clear-HcGameDataCache -ErrorAction SilentlyContinue){Clear-HcGameDataCache};Start-LibraryScan;Start-OnlineArtworkScan -ResetCursor;Set-ConsoleNotice 'Library and missing artwork refresh started.' 'INFO';Render-Page;return}"
    $insert="        '^storefront-manage-refresh:(.+)$' {Start-HcLibraryAndArtworkRefresh;return} # HUYMAIER_V0308_SEQUENCED_ARTWORK_REFRESH_V2"
    $shell=Replace-Required $shell $anchor $insert 'storefront refresh sequencing'
}
Write-Normalized $shellPath $shell

# Preflight the new production module so a partial install fails closed before UI.
$bootstrapPath=Join-Path $root 'HuymaierBootstrap.ps1'
$bootstrap=Read-Normalized $bootstrapPath
if($bootstrap -notmatch 'HUYMAIER_V0308_BACKGROUND_TASK_PREFLIGHT_V2'){
    $anchor='$artworkManagementPath=Join-Path $baseDir ''HuymaierArtworkManagement.ps1'''
    $insert=@($anchor,'$backgroundTasksPath=Join-Path $baseDir ''HuymaierBackgroundTasks.ps1'' # HUYMAIER_V0308_BACKGROUND_TASK_PREFLIGHT_V2') -join $lf
    $bootstrap=Replace-Required $bootstrap $anchor $insert 'background task preflight path'
    $anchor="        [pscustomobject]@{Path=`$artworkManagementPath;Label='Artwork management UI helpers'},"
    $insert=@($anchor,"        [pscustomobject]@{Path=`$backgroundTasksPath;Label='Background task HUD and coordinator'},") -join $lf
    $bootstrap=Replace-Required $bootstrap $anchor $insert 'background task preflight entry'
}
Write-Normalized $bootstrapPath $bootstrap

# Installer cache/preflight and required-payload gates must know about the module.
$installerPath=Join-Path $root 'Install-HuymaierConsole.ps1'
$installer=Read-Normalized $installerPath
if($installer -notmatch 'HUYMAIER_V0308_BACKGROUND_TASK_INSTALLER_V2'){
    $anchor="            'HuymaierArtworkManagement.ps1',"
    $insert=@($anchor,"            'HuymaierBackgroundTasks.ps1', # HUYMAIER_V0308_BACKGROUND_TASK_INSTALLER_V2") -join $lf
    $installer=Replace-Required $installer $anchor $insert 'installer background task cache entry'
}
Write-Normalized $installerPath $installer

$installerCorePath=Join-Path $root 'HuymaierInstallerCore.ps1'
$installerCore=Read-Normalized $installerCorePath
if($installerCore -notmatch 'HUYMAIER_V0308_BACKGROUND_TASK_REQUIRED_V2'){
    $anchor="'HuymaierArtworkSources.ps1','HuymaierArtworkSourcesTgdbSchema.ps1','HuymaierArtworkManagement.ps1','HuymaierGameBar.ps1', # HUYMAIER_V0308_ARTWORK_INSTALLER_REQUIRED_V2"
    $insert="'HuymaierArtworkSources.ps1','HuymaierArtworkSourcesTgdbSchema.ps1','HuymaierArtworkManagement.ps1','HuymaierBackgroundTasks.ps1','HuymaierGameBar.ps1', # HUYMAIER_V0308_ARTWORK_INSTALLER_REQUIRED_V2 HUYMAIER_V0308_BACKGROUND_TASK_REQUIRED_V2"
    $installerCore=Replace-Required $installerCore $anchor $insert 'installer required background task module'
}
Write-Normalized $installerCorePath $installerCore

# RC4's log exposed a noisy .NET Framework File.Replace call with a null backup
# path. Use a real sibling backup and retain an atomic move fallback.
$cursorPath=Join-Path $root 'HuymaierUnifiedCursor.ps1'
$cursor=Read-Normalized $cursorPath
if($cursor -notmatch 'HUYMAIER_V0308_CURSOR_STATE_REPLACE_V2'){
    $anchor='            [IO.File]::Replace($tmp,$script:HcUnifiedCursorStatePath,$null,$true)'
    $insert=@'
            # HUYMAIER_V0308_CURSOR_STATE_REPLACE_V2
            $backup=$script:HcUnifiedCursorStatePath+'.bak'
            try{
                [IO.File]::Replace($tmp,$script:HcUnifiedCursorStatePath,$backup,$true)
                Remove-Item -LiteralPath $backup -Force -ErrorAction SilentlyContinue
            }catch{
                Move-Item -LiteralPath $tmp -Destination $script:HcUnifiedCursorStatePath -Force
            }
'@
    $cursor=Replace-Required $cursor $anchor $insert.TrimEnd("`r","`n") 'cursor atomic state replacement'
}
Write-Normalized $cursorPath $cursor

Write-Host 'Applied v0.30.8 unified background-task HUD, sequenced artwork refresh, and cursor-state cleanup.'