param([string]$StageRoot='')
Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'

if(-not $StageRoot){$StageRoot=Split-Path -Parent (Split-Path -Parent $PSScriptRoot)}
function Need([bool]$Condition,[string]$Message){if(-not $Condition){throw "v0.30.8 background-task validation failed: $Message"}}
function Read-Text([string]$Relative){$path=Join-Path $StageRoot $Relative;Need (Test-Path -LiteralPath $path -PathType Leaf) "missing $Relative";return [IO.File]::ReadAllText($path,[Text.Encoding]::UTF8)}
function Parse-File([string]$Relative){$path=Join-Path $StageRoot $Relative;$tokens=$null;$errors=$null;[void][Management.Automation.Language.Parser]::ParseFile($path,[ref]$tokens,[ref]$errors);Need (@($errors).Count -eq 0) ("PowerShell parse failure in ${Relative}: "+((@($errors)|ForEach-Object{$_.Message}) -join '; '))}

$core=Read-Text 'HuymaierConsole.ps1'
$tasks=Read-Text 'HuymaierBackgroundTasks.ps1'
$shell=Read-Text 'HuymaierShellRedesign.ps1'
$cursor=Read-Text 'HuymaierUnifiedCursor.ps1'
$bootstrap=Read-Text 'HuymaierBootstrap.ps1'
$installer=Read-Text 'Install-HuymaierConsole.ps1'
$installerCore=Read-Text 'HuymaierInstallerCore.ps1'
foreach($file in @('HuymaierConsole.ps1','HuymaierBackgroundTasks.ps1','HuymaierShellRedesign.ps1','HuymaierUnifiedCursor.ps1','HuymaierBootstrap.ps1','Install-HuymaierConsole.ps1','HuymaierInstallerCore.ps1')){Parse-File $file}

Need ($core.Contains('HUYMAIER_V0308_BACKGROUND_TASK_CORE_V2')) 'core module integration marker missing'
Need ($core.Contains('HUYMAIER_V0308_BACKGROUND_TASK_HUD_V2')) 'top-right HUD XAML marker missing'
Need ($core.Contains('x:Name="BackgroundTaskHud"')) 'BackgroundTaskHud visual missing'
Need ($core.Contains('x:Name="BackgroundTaskPanel"')) 'BackgroundTaskPanel visual missing'
Need ($core.Contains("'BackgroundTaskHud','BackgroundTaskPanel','NavPanel'")) 'HUD controls are not resolved from XAML'
Need ($core.Contains('$script:BackgroundTasksModulePath')) 'background task module path missing'
Need ($core.Contains('. $script:BackgroundTasksModulePath')) 'background task module is not loaded'
Need ($core.Contains('HUYMAIER_V0308_BACKGROUND_TASK_WATCHER_V2')) 'event-driven artwork state hook missing'
Need ($core.Contains('Test-HcRuntimePathDirty $script:ArtworkStatePath')) 'artwork state is not consumed from runtime dirty map'
Need ($core.Contains('Update-HcBackgroundTaskHud')) 'runtime does not update the background task HUD'
Need (-not ($core -match '(?s)systemTimer\.Add_Tick\(\{.{0,5000}Get-Content[^\r\n]*ArtworkStatePath')) 'HUD added direct ArtworkState JSON polling to the system timer'
Need ($core.Contains("'artwork-refresh' { if(Get-Command Start-HcLibraryAndArtworkRefresh")) 'Settings artwork refresh is not routed through the sequenced coordinator'

Need ($tasks.Contains('function Get-HcBackgroundTasks')) 'common background task model missing'
Need ($tasks.Contains('function Update-HcBackgroundTaskHud')) 'background task HUD renderer missing'
Need ($tasks.Contains('System.Windows.Controls.ProgressBar')) 'task progress bar missing'
Need ($tasks.Contains('$limit=[math]::Min(3,$tasks.Count)')) 'task stack is not capped at three visible jobs'
Need ($tasks.Contains('more background task(s)')) 'overflow task count missing'
Need ($tasks.Contains("Title='Artwork refresh'")) 'artwork task descriptor missing'
Need ($tasks.Contains("'Library scan'")) 'library task descriptor missing'
Need ($tasks.Contains("'Windows Update'")) 'Windows Update task descriptor missing'
Need ($tasks.Contains("'Driver task'")) 'driver task descriptor missing'
Need ($tasks.Contains('function Start-HcLibraryAndArtworkRefresh')) 'library -> artwork coordinator missing'
Need ($tasks.Contains('$script:HcArtworkRefreshAfterLibrary=$true')) 'artwork queue state missing'
Need ($tasks.Contains('$script:HcBackgroundBaseApplyLibrary=${function:Apply-LibraryResult}')) 'library result sequencing wrapper missing'
Need ($tasks.Contains('Sequenced missing-artwork refresh started after library import.')) 'artwork is not started after fresh library import'
Need ($tasks.Contains('$script:HcArtworkTaskScanned +=')) 'cumulative artwork scan accounting missing'
Need ($tasks.Contains('$script:HcArtworkTaskResolved +=')) 'cumulative artwork resolved accounting missing'
Need ($tasks.Contains('TheGamesDB key not configured')) 'HUD does not expose missing TGDB configuration'
Need ($tasks.Contains('$Mode -in @(''TheGamesDbApiKey'',''SteamGridDbApiKey'')')) 'API key completion modes are not explicitly handled'
Need ($tasks.Contains('Save-Config')) 'API key completion does not persist config'

Need ($shell.Contains('HUYMAIER_V0308_SEQUENCED_ARTWORK_REFRESH_V2')) 'active shell refresh sequencing marker missing'
Need ($shell.Contains("'^storefront-manage-refresh:(.+)$' {Start-HcLibraryAndArtworkRefresh;return}")) 'active storefront refresh does not use sequenced coordinator'
Need (-not ($shell.Contains('Start-LibraryScan;Start-OnlineArtworkScan -ResetCursor'))) 'active shell still races library scan and artwork scan'

Need ($cursor.Contains('HUYMAIER_V0308_CURSOR_STATE_REPLACE_V2')) 'cursor state replacement fix missing'
Need (-not ($cursor.Contains('[IO.File]::Replace($tmp,$script:HcUnifiedCursorStatePath,$null,$true)'))) 'invalid null-backup File.Replace remains'
Need ($cursor.Contains('$backup=$script:HcUnifiedCursorStatePath+''.bak''')) 'cursor replacement does not use a valid sibling backup'
Need ($cursor.Contains('Move-Item -LiteralPath $tmp -Destination $script:HcUnifiedCursorStatePath -Force')) 'cursor replacement fallback missing'

Need ($bootstrap.Contains('HuymaierBackgroundTasks.ps1')) 'startup preflight does not require background task module'
Need ($installer.Contains("'HuymaierBackgroundTasks.ps1'")) 'installer preflight/cache does not include background task module'
Need ($installerCore.Contains("'HuymaierBackgroundTasks.ps1'")) 'installer required payload does not include background task module'

Write-Host 'v0.30.8 background task HUD/sequencing validation passed.'