param(
    [switch]$Windowed
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

$baseVariable=Get-Variable -Name HuymaierBaseDirectory -ErrorAction SilentlyContinue
$baseDir = if($null -ne $baseVariable -and -not [string]::IsNullOrWhiteSpace([string]$baseVariable.Value)){[string]$baseVariable.Value}else{Split-Path -Parent $MyInvocation.MyCommand.Path}
$corePath = Join-Path $baseDir 'HuymaierConsole.ps1'
$libraryWorkerPath = Join-Path $baseDir 'HuymaierLibraryWorker.ps1'
$ps1LibraryWorkerPath = Join-Path $baseDir 'HuymaierPs1LibraryWorker.ps1'
$storefrontModulePath = Join-Path $baseDir 'HuymaierStorefronts.ps1'
$storefrontWorkerPath = Join-Path $baseDir 'HuymaierStorefrontWorker.ps1'
$providerModulePath = Join-Path $baseDir 'HuymaierGameProviders.ps1'
$providerWorkerPath = Join-Path $baseDir 'HuymaierGameProviderWorker.ps1'
$artworkWorkerPath = Join-Path $baseDir 'HuymaierArtworkWorker.ps1'
$gameExperiencePath = Join-Path $baseDir 'HuymaierGameExperience.ps1'
$shellRedesignPath = Join-Path $baseDir 'HuymaierShellRedesign.ps1'
$gameBarPath = Join-Path $baseDir 'HuymaierGameBar.ps1'
$dataDir = Join-Path $env:LOCALAPPDATA 'Huymaier Console'
$logDir = Join-Path $dataDir 'Logs'
New-Item -ItemType Directory -Force -Path $dataDir, $logDir | Out-Null

function Write-BootstrapLog {
    param([string]$Message, [string]$Level = 'INFO')
    try {
        $path = Join-Path $logDir "$(Get-Date -Format 'yyyy-MM-dd').log"
        "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff') [$Level] $Message" | Add-Content -Path $path -Encoding UTF8
    } catch { }
}

function Test-PowerShellFile {
    param([string]$Path,[string]$Label)
    if (-not (Test-Path -LiteralPath $Path)) { throw "$Label is missing: $Path" }
    $tokens=$null;$parseErrors=$null
    [void][System.Management.Automation.Language.Parser]::ParseFile($Path,[ref]$tokens,[ref]$parseErrors)
    if($null -eq $parseErrors -or $parseErrors.Count -eq 0){return}
    $details=New-Object System.Text.StringBuilder
    foreach($parseError in $parseErrors){
        [void]$details.AppendLine(("{0} line {1}, column {2}: {3}" -f $Label,$parseError.Extent.StartLineNumber,$parseError.Extent.StartColumnNumber,$parseError.Message))
    }
    throw $details.ToString().Trim()
}

try {
    Test-PowerShellFile $corePath 'Main shell'
    Test-PowerShellFile $libraryWorkerPath 'Library worker'
    Test-PowerShellFile $ps1LibraryWorkerPath 'PlayStation 1 library worker'
    Test-PowerShellFile $storefrontModulePath 'Storefront hub'
    Test-PowerShellFile $storefrontWorkerPath 'Storefront worker'
    Test-PowerShellFile $providerModulePath 'Game provider hub'
    Test-PowerShellFile $providerWorkerPath 'Game provider worker'
    Test-PowerShellFile $artworkWorkerPath 'Online artwork worker'
    Test-PowerShellFile $gameExperiencePath 'Unified game experience'
    Test-PowerShellFile $shellRedesignPath 'Shell redesign'
    Test-PowerShellFile $gameBarPath 'Huymaier Game Bar'
    Write-BootstrapLog 'Huymaier Console v0.26.0 preflight passed.'
    if ($Windowed) { & $corePath -Windowed } else { & $corePath }
}
catch {
    $message=$_.Exception.Message
    Write-BootstrapLog "v0.26.0 preflight/startup failed:`n$message" 'FATAL'
    try {
        Add-Type -AssemblyName PresentationFramework
        [System.Windows.MessageBox]::Show(
            "Huymaier Console could not start.`n`n$message`n`nThe error was saved to:`n$logDir",
            'Huymaier Console','OK','Error'
        ) | Out-Null
    } catch { }
    exit 1
}
