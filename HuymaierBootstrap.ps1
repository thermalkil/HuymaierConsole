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

function Get-HuymaierNativeAssembly {
    $nativeVariable=Get-Variable -Name HuymaierNativeBridge -ErrorAction SilentlyContinue
    if($null -eq $nativeVariable -or $null -eq $nativeVariable.Value){throw 'The Huymaier native host bridge is unavailable. Rerun the installer.'}
    return $nativeVariable.Value.GetType().Assembly
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

    $nativeAssembly=Get-HuymaierNativeAssembly
    $stampType=$nativeAssembly.GetType('HuymaierConsole.NativeApp.HuymaierBuildStamp',$false)
    if($null -eq $stampType){throw 'The installed native host has no Huymaier build stamp. Rerun the installer.'}
    $flags=[Reflection.BindingFlags]::Public -bor [Reflection.BindingFlags]::Static
    $versionField=$stampType.GetField('Version',$flags)
    $architectureField=$stampType.GetField('Architecture',$flags)
    $nativeVersion=if($null -ne $versionField){[string]$versionField.GetValue($null)}else{''}
    $nativeArchitecture=if($null -ne $architectureField){[string]$architectureField.GetValue($null)}else{''}
    if(-not [string]::Equals($nativeVersion,$script:ExpectedConsoleVersion,[StringComparison]::OrdinalIgnoreCase) -or -not [string]::Equals($nativeArchitecture,'x64',[StringComparison]::OrdinalIgnoreCase)){
        throw "Native host build mismatch. Native=$nativeVersion/$nativeArchitecture Expected=$script:ExpectedConsoleVersion/x64. Rerun the installer; mixed native/script installations are blocked."
    }

    foreach($requiredType in @(
        'HuymaierConsole.NativeApp.HuymaierGameBarHost',
        'HuymaierConsole.NativeApp.HuymaierSystemButtonBridge',
        'HuymaierConsole.NativeApp.HuymaierInstanceGate'
    )){
        if($null -eq $nativeAssembly.GetType($requiredType,$false)){throw "The installed native host is missing required type $requiredType. Rerun the installer."}
    }
}

function Enter-HuymaierSingleInstance {
    $nativeAssembly=Get-HuymaierNativeAssembly
    $gateType=$nativeAssembly.GetType('HuymaierConsole.NativeApp.HuymaierInstanceGate',$true)
    $flags=[Reflection.BindingFlags]::Public -bor [Reflection.BindingFlags]::Static
    $method=$gateType.GetMethod('TryAcquire',$flags)
    if($null -eq $method){throw 'The native single-instance gate is incomplete.'}
    return [bool]$method.Invoke($null,$null)
}

function Exit-HuymaierSingleInstance {
    try{
        $nativeAssembly=Get-HuymaierNativeAssembly
        $gateType=$nativeAssembly.GetType('HuymaierConsole.NativeApp.HuymaierInstanceGate',$false)
        if($null -eq $gateType){return}
        $flags=[Reflection.BindingFlags]::Public -bor [Reflection.BindingFlags]::Static
        $method=$gateType.GetMethod('Release',$flags)
        if($null -ne $method){[void]$method.Invoke($null,$null)}
    }catch{}
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

    if(-not(Enter-HuymaierSingleInstance)){
        Write-BootstrapLog 'Duplicate Huymaier Console launch was blocked by the native single-instance gate.' 'WARN'
        exit 0
    }

    Write-BootstrapLog 'Huymaier Console v0.26.1 integrity preflight and single-instance gate passed.'
    try{
        if($Windowed){& $corePath -Windowed}else{& $corePath}
    }finally{
        Exit-HuymaierSingleInstance
    }
}catch{
    $message=$_.Exception.Message
    Write-BootstrapLog "v0.26.1 preflight/startup failed:`n$message" 'FATAL'
    try{
        Add-Type -AssemblyName PresentationFramework
        [System.Windows.MessageBox]::Show("Huymaier Console could not start safely.`n`n$message`n`nThe error was saved to:`n$logDir",'Huymaier Console','OK','Error')|Out-Null
    }catch{}
    exit 1
}
