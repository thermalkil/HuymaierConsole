param(
    [switch]$Windowed
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

$script:ExpectedConsoleVersion='0.26.4'
$baseVariable=Get-Variable -Name HuymaierBaseDirectory -ErrorAction SilentlyContinue
$baseDir=if($null -ne $baseVariable -and -not [string]::IsNullOrWhiteSpace([string]$baseVariable.Value)){[string]$baseVariable.Value}else{Split-Path -Parent $MyInvocation.MyCommand.Path}
$corePath=Join-Path $baseDir 'HuymaierConsole.ps1'
$libraryWorkerPath=Join-Path $baseDir 'HuymaierLibraryWorker.ps1'
$ps1LibraryWorkerPath=Join-Path $baseDir 'HuymaierPs1LibraryWorker.ps1'
$storefrontModulePath=Join-Path $baseDir 'HuymaierStorefronts.ps1'
$storefrontWorkerPath=Join-Path $baseDir 'HuymaierStorefrontWorker.ps1'
$providerModulePath=Join-Path $baseDir 'HuymaierGameProviders.ps1'
$providerWorkerPath=Join-Path $baseDir 'HuymaierGameProviderWorker.ps1'
$providerTelemetryPath=Join-Path $baseDir 'HuymaierProviderTelemetry.ps1'
$providerProgressWorkerPath=Join-Path $baseDir 'HuymaierProviderProgressWorker.ps1'
$providerTelemetryCoordinatorPath=Join-Path $baseDir 'HuymaierProviderTelemetryCoordinator.ps1'
$artworkWorkerPath=Join-Path $baseDir 'HuymaierArtworkWorker.ps1'
$gameExperiencePath=Join-Path $baseDir 'HuymaierGameExperience.ps1'
$shellRedesignPath=Join-Path $baseDir 'HuymaierShellRedesign.ps1'
$gameBarPath=Join-Path $baseDir 'HuymaierGameBar.ps1'
$dataDir=Join-Path $env:LOCALAPPDATA 'Huymaier Console'
$logDir=Join-Path $dataDir 'Logs'
$manifestPath=Join-Path $baseDir 'manifest.json'
$installIncompleteMarker=Join-Path $dataDir 'install-incomplete.json'
$gameInputBridgePath=Join-Path $baseDir 'HuymaierGameInputBridge.dll'
$preflightCachePath=Join-Path $dataDir 'startup-preflight-v1.json'
$script:ProviderTelemetryWatcher=$null
$script:ProviderTelemetrySubscriptions=@()
$script:ProviderTelemetryPidPath=Join-Path (Join-Path $dataDir 'GameProviders') 'provider-telemetry-coordinator.pid'
New-Item -ItemType Directory -Force -Path $dataDir,$logDir|Out-Null

function Write-BootstrapLog {
    param([string]$Message,[string]$Level='INFO')
    try{
        $path=Join-Path $logDir "$(Get-Date -Format 'yyyy-MM-dd').log"
        "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff') [$Level] $Message"|Add-Content -Path $path -Encoding UTF8
    }catch{}
}

function Get-ObjectProperty {
    param($Object,[string]$Name,$Default=$null)
    if($null -eq $Object){return $Default}
    try{$property=$Object.PSObject.Properties[$Name];if($null -ne $property -and $null -ne $property.Value){return $property.Value}}catch{}
    return $Default
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

function Get-PowerShellPreflightEntries {
    return @(
        [pscustomobject]@{Path=$corePath;Label='Main shell'},
        [pscustomobject]@{Path=$libraryWorkerPath;Label='Library worker'},
        [pscustomobject]@{Path=$ps1LibraryWorkerPath;Label='PlayStation 1 library worker'},
        [pscustomobject]@{Path=$storefrontModulePath;Label='Storefront hub'},
        [pscustomobject]@{Path=$storefrontWorkerPath;Label='Storefront worker'},
        [pscustomobject]@{Path=$providerModulePath;Label='Game provider hub'},
        [pscustomobject]@{Path=$providerWorkerPath;Label='Game provider worker'},
        [pscustomobject]@{Path=$providerTelemetryPath;Label='Provider telemetry helpers'},
        [pscustomobject]@{Path=$providerProgressWorkerPath;Label='Provider progress worker'},
        [pscustomobject]@{Path=$providerTelemetryCoordinatorPath;Label='Provider telemetry coordinator'},
        [pscustomobject]@{Path=$artworkWorkerPath;Label='Online artwork worker'},
        [pscustomobject]@{Path=$gameExperiencePath;Label='Unified game experience'},
        [pscustomobject]@{Path=$shellRedesignPath;Label='Shell redesign'},
        [pscustomobject]@{Path=$gameBarPath;Label='Huymaier Game Bar'}
    )
}

function Get-PowerShellFileSignature {
    param([string]$Path,[string]$Label)
    if(-not(Test-Path -LiteralPath $Path -PathType Leaf)){throw "$Label is missing: $Path"}
    $item=Get-Item -LiteralPath $Path -ErrorAction Stop
    return [pscustomobject]@{
        Name=[IO.Path]::GetFileName($item.FullName)
        Length=[int64]$item.Length
        LastWriteUtcTicks=[int64]$item.LastWriteTimeUtc.Ticks
    }
}

function Test-PowerShellPreflightCache {
    param([object[]]$Entries)
    if(-not(Test-Path -LiteralPath $preflightCachePath -PathType Leaf)){return $false}
    try{
        $cache=Get-Content -Raw -LiteralPath $preflightCachePath -Encoding UTF8|ConvertFrom-Json
        if([int](Get-ObjectProperty $cache 'SchemaVersion' 0) -ne 1){return $false}
        if(-not [string]::Equals([string](Get-ObjectProperty $cache 'ConsoleVersion' ''),$script:ExpectedConsoleVersion,[StringComparison]::OrdinalIgnoreCase)){return $false}
        $cachedBase=[string](Get-ObjectProperty $cache 'BaseDir' '')
        $currentBase=[IO.Path]::GetFullPath($baseDir).TrimEnd('\')
        if(-not [string]::Equals($cachedBase,$currentBase,[StringComparison]::OrdinalIgnoreCase)){return $false}
        $cachedFiles=@(Get-ObjectProperty $cache 'Files' @())
        if($cachedFiles.Count -ne $Entries.Count){return $false}
        for($i=0;$i -lt $Entries.Count;$i++){
            $entry=$Entries[$i]
            $signature=Get-PowerShellFileSignature ([string]$entry.Path) ([string]$entry.Label)
            $cached=$cachedFiles[$i]
            if(-not [string]::Equals([string](Get-ObjectProperty $cached 'Name' ''),[string]$signature.Name,[StringComparison]::OrdinalIgnoreCase)){return $false}
            if([int64](Get-ObjectProperty $cached 'Length' -1) -ne [int64]$signature.Length){return $false}
            if([int64](Get-ObjectProperty $cached 'LastWriteUtcTicks' -1) -ne [int64]$signature.LastWriteUtcTicks){return $false}
        }
        return $true
    }catch{return $false}
}

function Save-PowerShellPreflightCache {
    param([object[]]$Entries)
    $files=New-Object System.Collections.ArrayList
    foreach($entry in $Entries){[void]$files.Add((Get-PowerShellFileSignature ([string]$entry.Path) ([string]$entry.Label)))}
    $cache=[pscustomobject]@{
        SchemaVersion=1
        ConsoleVersion=$script:ExpectedConsoleVersion
        BaseDir=[IO.Path]::GetFullPath($baseDir).TrimEnd('\')
        Files=[object[]]$files.ToArray()
        ValidatedAtUtc=[DateTime]::UtcNow.ToString('o')
    }
    $temp="$preflightCachePath.$PID.tmp"
    $cache|ConvertTo-Json -Depth 6|Set-Content -LiteralPath $temp -Encoding UTF8
    Move-Item -LiteralPath $temp -Destination $preflightCachePath -Force
}

function Invoke-PowerShellSyntaxPreflight {
    $entries=[object[]](Get-PowerShellPreflightEntries)
    $timer=[Diagnostics.Stopwatch]::StartNew()
    if(Test-PowerShellPreflightCache $entries){
        $timer.Stop()
        Write-BootstrapLog ("Startup syntax cache hit; skipped reparsing {0} unchanged PowerShell files in {1} ms." -f $entries.Count,$timer.ElapsedMilliseconds)
        return
    }
    foreach($entry in $entries){Test-PowerShellFile ([string]$entry.Path) ([string]$entry.Label)}
    Save-PowerShellPreflightCache $entries
    $timer.Stop()
    Write-BootstrapLog ("Startup syntax cache refreshed after validating {0} PowerShell files in {1} ms." -f $entries.Count,$timer.ElapsedMilliseconds)
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

function Start-ProviderTelemetryWatch {
    if(-not(Test-Path -LiteralPath $providerTelemetryCoordinatorPath -PathType Leaf)){return}
    $providerRoot=Join-Path $dataDir 'GameProviders'
    New-Item -ItemType Directory -Force -Path $providerRoot|Out-Null
    $statePath=Join-Path $providerRoot 'provider-state.json'
    try{
        $watcher=New-Object IO.FileSystemWatcher $providerRoot,'provider-state.json'
        $watcher.NotifyFilter=[IO.NotifyFilters]::LastWrite -bor [IO.NotifyFilters]::Size -bor [IO.NotifyFilters]::FileName
        $context=[pscustomobject]@{
            StatePath=$statePath
            CoordinatorPath=$providerTelemetryCoordinatorPath
            BaseDir=$baseDir
            DataDir=$dataDir
            ParentPid=$PID
            PidPath=$script:ProviderTelemetryPidPath
        }
        $action={
            $ctx=$event.MessageData
            try{
                if($null -eq $ctx -or -not(Test-Path -LiteralPath $ctx.StatePath -PathType Leaf)){return}
                $state=$null;try{$state=Get-Content -Raw -LiteralPath $ctx.StatePath -Encoding UTF8|ConvertFrom-Json}catch{return}
                if($null -eq $state -or -not [bool]$state.Busy){return}
                $provider=[string]$state.Provider;$mode=[string]$state.Mode;$workerPid=[int]$state.WorkerPid
                if($provider -notin @('GOG','Amazon') -or $mode -notin @('Install','Update') -or $workerPid -le 0){return}
                if(Test-Path -LiteralPath $ctx.PidPath -PathType Leaf){
                    $existing=0;try{$existing=[int](Get-Content -Raw -LiteralPath $ctx.PidPath)}catch{}
                    if($existing -gt 0){try{$p=Get-Process -Id $existing -ErrorAction Stop;if(-not $p.HasExited){return}}catch{}}
                    Remove-Item -LiteralPath $ctx.PidPath -Force -ErrorAction SilentlyContinue
                }
                $powershell="$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
                $quote={param([string]$v);'"'+([string]$v).Replace('"','')+'"'}
                $args=@(
                    '-NoLogo','-NoProfile','-ExecutionPolicy','Bypass','-File',(& $quote $ctx.CoordinatorPath),
                    '-ParentPid',[string]$ctx.ParentPid,'-BaseDir',(& $quote $ctx.BaseDir),'-DataDir',(& $quote $ctx.DataDir)
                )
                $process=Start-Process -FilePath $powershell -ArgumentList $args -WindowStyle Hidden -PassThru
                try{$process.PriorityClass='BelowNormal'}catch{}
                Set-Content -LiteralPath $ctx.PidPath -Value ([string]$process.Id) -Encoding ASCII
            }catch{}
        }
        $subscriptions=New-Object System.Collections.ArrayList
        foreach($eventName in @('Changed','Created')){
            $sourceIdentifier="Huymaier.ProviderTelemetry.$eventName.$PID"
            $job=Register-ObjectEvent -InputObject $watcher -EventName $eventName -SourceIdentifier $sourceIdentifier -MessageData $context -Action $action
            [void]$subscriptions.Add([pscustomobject]@{SourceIdentifier=$sourceIdentifier;Job=$job})
        }
        $watcher.EnableRaisingEvents=$true
        $script:ProviderTelemetryWatcher=$watcher
        $script:ProviderTelemetrySubscriptions=[object[]]$subscriptions.ToArray()
        Write-BootstrapLog 'Provider telemetry is event-driven; no telemetry PowerShell process is started during normal boot.'
    }catch{Write-BootstrapLog "Provider telemetry watcher could not start: $($_.Exception.Message)" 'WARN'}
}

function Stop-ProviderTelemetryWatch {
    try{if($null -ne $script:ProviderTelemetryWatcher){$script:ProviderTelemetryWatcher.EnableRaisingEvents=$false}}catch{}
    foreach($subscription in @($script:ProviderTelemetrySubscriptions)){
        try{Unregister-Event -SourceIdentifier ([string]$subscription.SourceIdentifier) -ErrorAction SilentlyContinue}catch{}
        try{if($null -ne $subscription.Job){Remove-Job -Id $subscription.Job.Id -Force -ErrorAction SilentlyContinue}}catch{}
    }
    $script:ProviderTelemetrySubscriptions=@()
    try{if($null -ne $script:ProviderTelemetryWatcher){$script:ProviderTelemetryWatcher.Dispose()}}catch{}
    $script:ProviderTelemetryWatcher=$null
    try{
        if(Test-Path -LiteralPath $script:ProviderTelemetryPidPath -PathType Leaf){
            $coordinatorPid=0;try{$coordinatorPid=[int](Get-Content -Raw -LiteralPath $script:ProviderTelemetryPidPath)}catch{}
            if($coordinatorPid -gt 0){Stop-Process -Id $coordinatorPid -Force -ErrorAction SilentlyContinue}
            Remove-Item -LiteralPath $script:ProviderTelemetryPidPath -Force -ErrorAction SilentlyContinue
        }
    }catch{}
}

try{
    Assert-HuymaierInstallIntegrity
    Invoke-PowerShellSyntaxPreflight

    if(-not(Enter-HuymaierSingleInstance)){
        Write-BootstrapLog 'Duplicate Huymaier Console launch was blocked by the native single-instance gate.' 'WARN'
        exit 0
    }

    Write-BootstrapLog "Huymaier Console v$script:ExpectedConsoleVersion integrity preflight and single-instance gate passed."
    Start-ProviderTelemetryWatch
    try{
        if($Windowed){& $corePath -Windowed}else{& $corePath}
    }finally{
        Stop-ProviderTelemetryWatch
        Exit-HuymaierSingleInstance
    }
}catch{
    Stop-ProviderTelemetryWatch
    $message=$_.Exception.Message
    Write-BootstrapLog "v$script:ExpectedConsoleVersion preflight/startup failed:`n$message" 'FATAL'
    try{
        Add-Type -AssemblyName PresentationFramework
        [System.Windows.MessageBox]::Show("Huymaier Console could not start safely.`n`n$message`n`nThe error was saved to:`n$logDir",'Huymaier Console','OK','Error')|Out-Null
    }catch{}
    exit 1
}
