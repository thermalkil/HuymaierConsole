param(
    [switch]$Windowed
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

$script:ExpectedConsoleVersion='0.26.1'
$baseVariable=Get-Variable -Name HuymaierBaseDirectory -ErrorAction SilentlyContinue
$baseDir=if($null -ne $baseVariable -and -not [string]::IsNullOrWhiteSpace([string]$baseVariable.Value)){[string]$baseVariable.Value}else{Split-Path -Parent $MyInvocation.MyCommand.Path}
$corePath=Join-Path $baseDir 'HuymaierConsole.ps1'
$libraryWorkerPath=Join-Path $baseDir 'HuymaierLibraryWorker.ps1'
$ps1LibraryWorkerPath=Join-Path $baseDir 'HuymaierPs1LibraryWorker.ps1'
$storefrontModulePath=Join-Path $baseDir 'HuymaierStorefronts.ps1'
$storefrontWorkerPath=Join-Path $baseDir 'HuymaierStorefrontWorker.ps1'
$providerModulePath=Join-Path $baseDir 'HuymaierGameProviders.ps1'
$providerWorkerPath=Join-Path $baseDir 'HuymaierGameProviderWorker.ps1'
$artworkWorkerPath=Join-Path $baseDir 'HuymaierArtworkWorker.ps1'
$gameExperiencePath=Join-Path $baseDir 'HuymaierGameExperience.ps1'
$shellRedesignPath=Join-Path $baseDir 'HuymaierShellRedesign.ps1'
$gameBarPath=Join-Path $baseDir 'HuymaierGameBar.ps1'
$dataDir=Join-Path $env:LOCALAPPDATA 'Huymaier Console'
$logDir=Join-Path $dataDir 'Logs'
$manifestPath=Join-Path $baseDir 'manifest.json'
$installIncompleteMarker=Join-Path $dataDir 'install-incomplete.json'
$gameInputBridgePath=Join-Path $baseDir 'HuymaierGameInputBridge.dll'
New-Item -ItemType Directory -Force -Path $dataDir,$logDir|Out-Null

function Write-BootstrapLog {
    param([string]$Message,[string]$Level='INFO')
    try{
        $path=Join-Path $logDir "$(Get-Date -Format 'yyyy-MM-dd').log"
        "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff') [$Level] $Message"|Add-Content -Path $path -Encoding UTF8
    }catch{}
}

function Test-PowerShellFile {
    param([string]$Path,[string]$Label)
    if(-not(Test-Path -LiteralPath $Path -PathType Leaf)){throw "$Label is missing: $Path"}
    $tokens=$null;$parseErrors=$null
    [void][System.Management.Automation.Language.Parser]::ParseFile($Path,[ref]$tokens,[ref]$parseErrors)
    if($null -eq $parseErrors -or $parseErrors.Count -eq 0){return}
    $details=New-Object System.Text.StringBuilder
    foreach($parseError in $parseErrors){[void]$details.AppendLine(("{0} line {1}, column {2}: {3}" -f $Label,$parseError.Extent.StartLineNumber,$parseError.Extent.StartColumnNumber,$parseError.Message))}
    throw $details.ToString().Trim()
}

function Assert-HuymaierInstallIntegrity {
    if(Test-Path -LiteralPath $installIncompleteMarker -PathType Leaf){
        throw "Huymaier Console installation is marked incomplete. Rerun the v$script:ExpectedConsoleVersion installer to repair it before starting the Console."
    }
    if(-not(Test-Path -LiteralPath $manifestPath -PathType Leaf)){throw 'The installed package manifest is missing. Rerun the installer to repair Huymaier Console.'}
    $manifest=Get-Content -Raw -LiteralPath $manifestPath -Encoding UTF8|ConvertFrom-Json
    $manifestVersion=[string]$manifest.version
    if(-not [string]::Equals($manifestVersion,$script:ExpectedConsoleVersion,[StringComparison]::OrdinalIgnoreCase)){
        throw "Installed package version mismatch. Manifest=$manifestVersion Expected=$script:ExpectedConsoleVersion. Rerun the installer; Huymaier Console will not start from a mixed-version installation."
    }
    if(-not(Test-Path -LiteralPath $gameInputBridgePath -PathType Leaf)){throw 'The native GameInput system-button bridge is missing. Rerun the installer.'}

    # The native entry executable publishes this bridge object into the hosted
    # runspace. Resolve required native types through that loaded assembly rather
    # than relying on PowerShell's type-name resolver.
    $nativeVariable=Get-Variable -Name HuymaierNativeBridge -ErrorAction SilentlyContinue
    if($null -eq $nativeVariable -or $null -eq $nativeVariable.Value){throw 'The Huymaier native host bridge is unavailable. Rerun the installer.'}
    $nativeAssembly=$nativeVariable.Value.GetType().Assembly
    if($null -eq $nativeAssembly.GetType('HuymaierConsole.NativeApp.HuymaierGameBarHost',$false)){
        throw 'The installed native host does not contain the v0.26+ Huymaier Game Bar. Rerun the installer; mixed native/script installations are blocked.'
    }
    if($null -eq $nativeAssembly.GetType('HuymaierConsole.NativeApp.HuymaierSystemButtonBridge',$false)){
        throw 'The installed native host does not contain the Huymaier system-button bridge. Rerun the installer.'
    }
}

try{
    Assert-HuymaierInstallIntegrity
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
    Write-BootstrapLog 'Huymaier Console v0.26.1 integrity preflight passed.'
    if($Windowed){& $corePath -Windowed}else{& $corePath}
}catch{
    $message=$_.Exception.Message
    Write-BootstrapLog "v0.26.1 preflight/startup failed:`n$message" 'FATAL'
    try{
        Add-Type -AssemblyName PresentationFramework
        [System.Windows.MessageBox]::Show("Huymaier Console could not start safely.`n`n$message`n`nThe error was saved to:`n$logDir",'Huymaier Console','OK','Error')|Out-Null
    }catch{}
    exit 1
}
