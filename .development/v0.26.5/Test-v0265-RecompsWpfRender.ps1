param(
    [string]$FinalPath=''
)

Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Xaml

$repoRoot=(Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
if([string]::IsNullOrWhiteSpace($FinalPath)){$FinalPath=Join-Path $repoRoot 'HuymaierRecompsFinal.ps1'}
$finalPath=(Resolve-Path -LiteralPath $FinalPath).Path
if(-not(Test-Path -LiteralPath $finalPath -PathType Leaf)){throw "HuymaierRecompsFinal.ps1 is missing: $FinalPath"}

# Minimal post-V7 shell contract. This test deliberately executes the actual
# WPF renderer instead of merely checking route/state strings.
$script:ActionPanel=New-Object System.Windows.Controls.StackPanel
$script:ActionPanel.Width=1400
$script:ActionPanel.Height=900
$script:ActionButtons=@()
$script:CurrentActions=@()
$script:HomeRows=@()
$script:GameHubLaunchEntries=@()
$script:GameHubPlatforms=@('Steam','Recomps')
$script:SelectedGamePlatform='Recomps'
$script:SelectedTab=1
$script:SubPage='RecompsLibrary'
$script:SelectedAction=0
$script:SelectedProviderGame=$null
$script:FileBrowserEntryType=''
$script:FakeRecompGames=@()

function Convert-ToStableArray { param($Value);$items=New-Object System.Collections.ArrayList;if($null-ne$Value){foreach($item in $Value){[void]$items.Add($item)}};return ,([object[]]$items.ToArray()) }
function Get-EntryProperty { param($Object,[string]$Name,$Default='');if($null-eq$Object){return $Default};$property=$Object.PSObject.Properties[$Name];if($null-eq$property-or$null-eq$property.Value){return $Default};return $property.Value }
function New-Action { param([string]$Id,[string]$Title,[string]$Description='',[string]$Kind='Action',[int]$Value=0);[pscustomobject]@{Id=$Id;Title=$Title;Description=$Description;Kind=$Kind;Value=$Value} }
function Get-HcManualRecompGames { return [object[]]@($script:FakeRecompGames) }
function New-HomeCard { param($Entry,[string]$Id,[string]$Kind);$button=New-Object System.Windows.Controls.Button;$button.Tag=$Id;$text=New-Object System.Windows.Controls.TextBlock;$text.Text=[string](Get-EntryProperty $Entry 'Name' 'Recomp Game');$button.Content=$text;return $button }
function Test-HcMouseHoverAllowed { return $false }
function Set-KeyboardActive {}
function Update-ActionVisuals {}
function Invoke-UiFeedback { param([string]$Name) }
function Write-Log { param([string]$Message,[string]$Level='INFO') }
function Set-ConsoleNotice { param([string]$Message,[string]$Level='INFO') }
function Render-Page {}
function Update-NavVisuals {}
function Start-HcManualRecompPicker {}
function Start-ExternalProcess { param([string]$Path,[object[]]$Arguments,[string]$WorkingDirectory);return $true }
function Add-ToRecent { param([string]$Kind,$Entry) }
function Request-NativeConfirmation { param([string]$Action,[string]$Question) }
function Remove-HcManualRecompGame { param([string]$Id);return $true }
function Get-SelectedProviderGame { return $null }

# Owners captured by the final module.
function Render-GamesHub {}
function Invoke-Action { param([string]$Id) }
function Handle-Back {}
function Get-PageDefinition { param([int]$Index);return [pscustomobject]@{Title='Test';Subtitle='';Hero='';HeroText='';Actions=@()} }
function Complete-ProviderConfirmation { param([string]$Action);return $false }
function Complete-NativeFileSelection { param($Entry) }

. $finalPath

function Get-HcWpfText {
    param($Node)
    if($null-eq$Node){return}
    if($Node -is [System.Windows.Controls.TextBlock]){Write-Output ([string]$Node.Text);return}
    if($Node -is [System.Windows.Controls.Panel]){foreach($child in @($Node.Children)){Get-HcWpfText $child};return}
    if($Node -is [System.Windows.Controls.Border]){if($Node.Child){Get-HcWpfText $Node.Child};return}
    if($Node -is [System.Windows.Controls.ScrollViewer]){if($Node.Content){Get-HcWpfText $Node.Content};return}
    if($Node -is [System.Windows.Controls.ContentControl]){if($Node.Content){Get-HcWpfText $Node.Content};return}
}

function Reset-HcWpfFixture {
    $script:ActionPanel.Children.Clear()
    $script:ActionButtons=@()
    $script:CurrentActions=@()
    $script:HomeRows=@()
    $script:GameHubLaunchEntries=@()
    $script:SelectedAction=0
}

# Empty library: this is the exact state that produced the user-visible blank
# screen in RC6. Both the header and command-card renderers must execute.
Reset-HcWpfFixture
$script:FakeRecompGames=@()
Render-HcRecompsLibrary
$emptyText=@(Get-HcWpfText $script:ActionPanel)
foreach($required in @('RECOMPS','Recomps','Add Recomp Game','Back to Platforms','Your Recomp Games','No recomp games added yet. Choose Add Recomp Game, then select the game executable.')){
    if($emptyText -notcontains $required){throw "Recomps WPF empty-library render is missing visible text: $required"}
}
if($script:ActionPanel.Children.Count-lt4){throw 'Recomps WPF empty-library render produced too few visual children.'}
if($script:ActionButtons.Count-ne2){throw "Recomps WPF empty-library render expected 2 actionable buttons, got $($script:ActionButtons.Count)."}
Write-Host 'recompsWpfEmptyLibraryVisibleGate: success'

# Populated library: prove separately persisted games are actually surfaced as
# visible cards, not just present in route state.
Reset-HcWpfFixture
$script:FakeRecompGames=@(
    [pscustomobject]@{Id='Recomps:alpha';Name='Recomp Alpha';Source='Recomps';LaunchTarget='C:\Fake\Alpha.exe';Installed=$false;ArtworkPath=''},
    [pscustomobject]@{Id='Recomps:beta';Name='Recomp Beta';Source='Recomps';LaunchTarget='C:\Fake\Beta.exe';Installed=$false;ArtworkPath=''}
)
Render-HcRecompsLibrary
$populatedText=@(Get-HcWpfText $script:ActionPanel)
foreach($required in @('Add Recomp Game','Recomp Alpha','Recomp Beta')){
    if($populatedText -notcontains $required){throw "Recomps WPF populated-library render is missing visible text: $required"}
}
if($script:ActionButtons.Count-ne4){throw "Recomps WPF populated-library render expected 4 actionable buttons, got $($script:ActionButtons.Count)."}
Write-Host 'recompsWpfPopulatedLibraryVisibleGate: success'

# Game page: exercise the same header/card constructors with an existing EXE so
# Launch, Open Folder, Remove and Back all have real WPF controls.
$tempExe=Join-Path $env:TEMP ('hc-recomp-render-'+[guid]::NewGuid().ToString('N')+'.exe')
try{
    [IO.File]::WriteAllBytes($tempExe,[byte[]](0x4D,0x5A))
    Reset-HcWpfFixture
    $script:FakeRecompGames=@([pscustomobject]@{Id='Recomps:alpha';Name='Recomp Alpha';Source='Recomps';LaunchTarget=$tempExe;Installed=$true;ArtworkPath=''})
    $script:HcSelectedRecompId='Recomps:alpha'
    $script:SubPage='RecompsGame'
    Render-HcRecompGame
    $gameText=@(Get-HcWpfText $script:ActionPanel)
    foreach($required in @('RECOMPS','Recomp Alpha','Launch','Open Folder','Remove from Recomps','Back')){
        if($gameText -notcontains $required){throw "Recomps WPF game render is missing visible text: $required"}
    }
    if($script:ActionButtons.Count-ne4){throw "Recomps WPF game render expected 4 actionable buttons, got $($script:ActionButtons.Count)."}
    Write-Host 'recompsWpfGameActionsVisibleGate: success'
}finally{
    Remove-Item -LiteralPath $tempExe -Force -ErrorAction SilentlyContinue
}

# Prevent recurrence of the PowerShell case-insensitive parameter/control-name
# collision that caused RC6 to clear the page and then throw before first paint.
$source=Get-Content -Raw -LiteralPath $finalPath -Encoding UTF8
if($source -match '(?im)^\s*\$title\s*=\s*New-Object\s+System\.Windows\.Controls\.TextBlock'){
    throw 'Recomps renderer reintroduced a $Title/$title case-insensitive variable collision.'
}
Write-Host 'recompsWpfTypedParameterCollisionGate: success'
