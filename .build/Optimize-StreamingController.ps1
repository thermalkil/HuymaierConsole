param(
    [Parameter(Mandatory=$true)][string]$CorePath,
    [Parameter(Mandatory=$true)][string]$BootstrapPath,
    [Parameter(Mandatory=$true)][string]$InstallerScriptPath,
    [Parameter(Mandatory=$true)][string]$CoreBuilderPath
)

Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
foreach($path in @($CorePath,$BootstrapPath,$InstallerScriptPath,$CoreBuilderPath)){if(-not(Test-Path -LiteralPath $path -PathType Leaf)){throw "Streaming-controller transform input missing: $path"}}

$core=Get-Content -Raw -LiteralPath $CorePath -Encoding UTF8
if($core -notmatch 'HUYMAIER_STREAMING_CONTROLLER_RUNTIME_V1'){
    $pathNeedle='$script:AppLibraryModulePath = Join-Path $script:BaseDir ''HuymaierAppLibrary.ps1'''
    if(-not $core.Contains($pathNeedle)){throw 'Streaming-controller transform requires the curated App library transform first.'}
    $core=$core.Replace($pathNeedle,$pathNeedle+"`r`n`$script:StreamingControllerModulePath = Join-Path `$script:BaseDir 'HuymaierStreamingController.ps1'")

    $appBlock=@'
# HUYMAIER_CURATED_APP_LIBRARY_V1
if (Test-Path -LiteralPath $script:AppLibraryModulePath) {
    try { . $script:AppLibraryModulePath }
    catch { Write-Log "App library module load failed: $($_.Exception.Message)" 'ERROR' }
}
'@
    if(-not $core.Contains($appBlock)){throw 'Streaming-controller transform could not find curated App library load block.'}
    $streamingBlock=@'
# HUYMAIER_STREAMING_CONTROLLER_RUNTIME_V1
if (Test-Path -LiteralPath $script:StreamingControllerModulePath) {
    try { . $script:StreamingControllerModulePath }
    catch { Write-Log "Streaming controller module load failed: $($_.Exception.Message)" 'ERROR' }
}
'@
    $core=$core.Replace($appBlock,$appBlock+"`r`n"+$streamingBlock)
    Set-Content -LiteralPath $CorePath -Value $core -Encoding UTF8
}

$bootstrap=Get-Content -Raw -LiteralPath $BootstrapPath -Encoding UTF8
if($bootstrap -notmatch 'HUYMAIER_STREAMING_CONTROLLER_PREFLIGHT_V1'){
    $pathNeedle='$appInstallWorkerPath=Join-Path $baseDir ''HuymaierAppInstallWorker.ps1'''
    if(-not $bootstrap.Contains($pathNeedle)){throw 'Streaming-controller transform requires App library bootstrap preflight first.'}
    $bootstrap=$bootstrap.Replace($pathNeedle,$pathNeedle+"`r`n# HUYMAIER_STREAMING_CONTROLLER_PREFLIGHT_V1`r`n`$streamingControllerPath=Join-Path `$baseDir 'HuymaierStreamingController.ps1'")
    $entryNeedle="        [pscustomobject]@{Path=`$appInstallWorkerPath;Label='Native app install worker'},"
    if(-not $bootstrap.Contains($entryNeedle)){throw 'Streaming-controller transform could not find App install worker preflight entry.'}
    $bootstrap=$bootstrap.Replace($entryNeedle,$entryNeedle+"`r`n        [pscustomobject]@{Path=`$streamingControllerPath;Label='Streaming controller runtime'},")
    Set-Content -LiteralPath $BootstrapPath -Value $bootstrap -Encoding UTF8
}

$installer=Get-Content -Raw -LiteralPath $InstallerScriptPath -Encoding UTF8
if($installer -notmatch 'HUYMAIER_STREAMING_CONTROLLER_INSTALLER_CACHE_V1'){
    $entryNeedle="            'HuymaierAppInstallWorker.ps1',"
    if(-not $installer.Contains($entryNeedle)){throw 'Streaming-controller transform could not find App install worker installer-cache entry.'}
    $installer=$installer.Replace($entryNeedle,$entryNeedle+"`r`n            # HUYMAIER_STREAMING_CONTROLLER_INSTALLER_CACHE_V1`r`n            'HuymaierStreamingController.ps1',")
    Set-Content -LiteralPath $InstallerScriptPath -Value $installer -Encoding UTF8
}

$builder=Get-Content -Raw -LiteralPath $CoreBuilderPath -Encoding UTF8
if($builder -notmatch 'HUYMAIER_STREAMING_CURSOR_HOST_BUILD_V1'){
    $compileNeedle=@'
& $csc @args
if($LASTEXITCODE -ne 0 -or -not(Test-Path $exe)){throw 'x64 HuymaierConsole.exe compilation failed.'}
'@
    if(-not $builder.Contains($compileNeedle)){throw 'Streaming-controller transform could not find native host compiler boundary.'}
    $compileBlock=@'
& $csc @args
if($LASTEXITCODE -ne 0 -or -not(Test-Path $exe)){throw 'x64 HuymaierConsole.exe compilation failed.'}

# HUYMAIER_STREAMING_CURSOR_HOST_BUILD_V1
$streamingCursorSource=Join-Path $stage 'Native\HuymaierStreamingCursorHost.cs'
$streamingCursorExe=Join-Path $stage 'HuymaierStreamingCursorHost.exe'
if(-not(Test-Path -LiteralPath $streamingCursorSource -PathType Leaf)){throw "Streaming cursor host source missing: $streamingCursorSource"}
$streamArgs=@('/noconfig','/nologo','/target:winexe','/platform:x64','/optimize+',('/out:'+$streamingCursorExe),('/win32icon:'+(Join-Path $stage 'HuymaierConsole.ico')))
foreach($r in $refs){$streamArgs+=('/reference:'+$r)}
$streamArgs+=$streamingCursorSource
& $csc @streamArgs
if($LASTEXITCODE -ne 0 -or -not(Test-Path $streamingCursorExe)){throw 'x64 HuymaierStreamingCursorHost.exe compilation failed.'}
'@
    $builder=$builder.Replace($compileNeedle,$compileBlock)

    $requiredNeedle="'HuymaierGameInputBridge.dll','HuymaierConsole.exe','Restore-HuymaierWindowsSettings.ps1'"
    if(-not $builder.Contains($requiredNeedle)){throw 'Streaming-controller transform could not find required production payload list.'}
    $builder=$builder.Replace($requiredNeedle,"'HuymaierGameInputBridge.dll','HuymaierConsole.exe','HuymaierStreamingCursorHost.exe','Restore-HuymaierWindowsSettings.ps1'")

    $archNeedle='$headers=(& $dumpbin /nologo /headers $exe) -join "`n";if($headers -notmatch ''(?i)machine \(x64\)|8664 machine''){throw ''HuymaierConsole.exe is not x64.''}'
    if(-not $builder.Contains($archNeedle)){throw 'Streaming-controller transform could not find native host architecture gate.'}
    $archBlock=$archNeedle+"`r`n`$streamHeaders=(& `$dumpbin /nologo /headers `$streamingCursorExe) -join \"``n\";if(`$streamHeaders -notmatch '(?i)machine \\(x64\\)|8664 machine'){throw 'HuymaierStreamingCursorHost.exe is not x64.'}"
    $builder=$builder.Replace($archNeedle,$archBlock)
    Set-Content -LiteralPath $CoreBuilderPath -Value $builder -Encoding UTF8
}
