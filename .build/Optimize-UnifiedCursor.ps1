param(
    [Parameter(Mandatory=$true)][string]$CorePath,
    [Parameter(Mandatory=$true)][string]$BootstrapPath,
    [Parameter(Mandatory=$true)][string]$InstallerScriptPath,
    [Parameter(Mandatory=$true)][string]$CoreBuilderPath
)
Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
foreach($path in @($CorePath,$BootstrapPath,$InstallerScriptPath,$CoreBuilderPath)){if(-not(Test-Path -LiteralPath $path -PathType Leaf)){throw "Unified-cursor transform input missing: $path"}}

$core=Get-Content -Raw -LiteralPath $CorePath -Encoding UTF8
if($core -notmatch 'HUYMAIER_UNIFIED_CURSOR_RUNTIME_V1'){
    $pathNeedle='$script:StreamingControllerModulePath = Join-Path $script:BaseDir ''HuymaierStreamingController.ps1'''
    if(-not $core.Contains($pathNeedle)){throw 'Unified cursor requires streaming-controller transform first.'}
    $core=$core.Replace($pathNeedle,$pathNeedle+"`r`n`$script:UnifiedCursorModulePath = Join-Path `$script:BaseDir 'HuymaierUnifiedCursor.ps1'")
    $loadNeedle=@'
# HUYMAIER_STREAMING_CONTROLLER_RUNTIME_V1
if (Test-Path -LiteralPath $script:StreamingControllerModulePath) {
    try { . $script:StreamingControllerModulePath }
    catch { Write-Log "Streaming controller module load failed: $($_.Exception.Message)" 'ERROR' }
}
'@
    if(-not $core.Contains($loadNeedle)){throw 'Unified cursor could not find streaming runtime load block.'}
    $loadBlock=@'
# HUYMAIER_STREAMING_CONTROLLER_RUNTIME_V1
if (Test-Path -LiteralPath $script:StreamingControllerModulePath) {
    try { . $script:StreamingControllerModulePath }
    catch { Write-Log "Streaming controller module load failed: $($_.Exception.Message)" 'ERROR' }
}

# HUYMAIER_UNIFIED_CURSOR_RUNTIME_V1
if (Test-Path -LiteralPath $script:UnifiedCursorModulePath) {
    try { . $script:UnifiedCursorModulePath }
    catch { Write-Log "Unified cursor module load failed: $($_.Exception.Message)" 'ERROR' }
}
'@
    $core=$core.Replace($loadNeedle,$loadBlock)
    Set-Content -LiteralPath $CorePath -Value $core -Encoding UTF8
}

$bootstrap=Get-Content -Raw -LiteralPath $BootstrapPath -Encoding UTF8
if($bootstrap -notmatch 'HUYMAIER_UNIFIED_CURSOR_PREFLIGHT_V1'){
    $pathNeedle='$streamingControllerPath=Join-Path $baseDir ''HuymaierStreamingController.ps1'''
    if(-not $bootstrap.Contains($pathNeedle)){throw 'Unified cursor requires streaming bootstrap preflight first.'}
    $bootstrap=$bootstrap.Replace($pathNeedle,$pathNeedle+"`r`n# HUYMAIER_UNIFIED_CURSOR_PREFLIGHT_V1`r`n`$unifiedCursorPath=Join-Path `$baseDir 'HuymaierUnifiedCursor.ps1'")
    $entryNeedle="        [pscustomobject]@{Path=`$streamingControllerPath;Label='Streaming controller runtime'},"
    if(-not $bootstrap.Contains($entryNeedle)){throw 'Unified cursor could not find streaming preflight entry.'}
    $bootstrap=$bootstrap.Replace($entryNeedle,$entryNeedle+"`r`n        [pscustomobject]@{Path=`$unifiedCursorPath;Label='Unified cursor runtime'},")
    Set-Content -LiteralPath $BootstrapPath -Value $bootstrap -Encoding UTF8
}

$installer=Get-Content -Raw -LiteralPath $InstallerScriptPath -Encoding UTF8
if($installer -notmatch 'HUYMAIER_UNIFIED_CURSOR_INSTALLER_CACHE_V1'){
    $entryNeedle="            'HuymaierStreamingController.ps1',"
    if(-not $installer.Contains($entryNeedle)){throw 'Unified cursor could not find streaming installer-cache entry.'}
    $installer=$installer.Replace($entryNeedle,$entryNeedle+"`r`n            # HUYMAIER_UNIFIED_CURSOR_INSTALLER_CACHE_V1`r`n            'HuymaierUnifiedCursor.ps1',")
    Set-Content -LiteralPath $InstallerScriptPath -Value $installer -Encoding UTF8
}

$builder=Get-Content -Raw -LiteralPath $CoreBuilderPath -Encoding UTF8
if($builder -notmatch 'HUYMAIER_UNIFIED_CURSOR_HOST_BUILD_V1'){
    $compileNeedle=@'
& $csc @streamArgs
if($LASTEXITCODE -ne 0 -or -not(Test-Path $streamingCursorExe)){throw 'x64 HuymaierStreamingCursorHost.exe compilation failed.'}
'@
    if(-not $builder.Contains($compileNeedle)){throw 'Unified cursor requires streaming cursor host compile block first.'}
    $compileBlock=@'
& $csc @streamArgs
if($LASTEXITCODE -ne 0 -or -not(Test-Path $streamingCursorExe)){throw 'x64 HuymaierStreamingCursorHost.exe compilation failed.'}

# HUYMAIER_UNIFIED_CURSOR_HOST_BUILD_V1
$unifiedCursorSource=Join-Path $stage 'Native\HuymaierUnifiedCursorHost.cs'
$unifiedCursorExe=Join-Path $stage 'HuymaierUnifiedCursorHost.exe'
if(-not(Test-Path -LiteralPath $unifiedCursorSource -PathType Leaf)){throw "Unified cursor host source missing: $unifiedCursorSource"}
$unifiedArgs=@('/noconfig','/nologo','/target:winexe','/platform:x64','/optimize+',('/out:'+$unifiedCursorExe),('/win32icon:'+(Join-Path $stage 'HuymaierConsole.ico')))
foreach($r in $refs){$unifiedArgs+=('/reference:'+$r)}
$unifiedArgs+=$unifiedCursorSource
& $csc @unifiedArgs
if($LASTEXITCODE -ne 0 -or -not(Test-Path $unifiedCursorExe)){throw 'x64 HuymaierUnifiedCursorHost.exe compilation failed.'}
'@
    $builder=$builder.Replace($compileNeedle,$compileBlock)
    $requiredNeedle="'HuymaierGameInputBridge.dll','HuymaierConsole.exe','HuymaierStreamingCursorHost.exe','Restore-HuymaierWindowsSettings.ps1'"
    if(-not $builder.Contains($requiredNeedle)){throw 'Unified cursor could not find production payload list.'}
    $builder=$builder.Replace($requiredNeedle,"'HuymaierGameInputBridge.dll','HuymaierConsole.exe','HuymaierStreamingCursorHost.exe','HuymaierUnifiedCursorHost.exe','Restore-HuymaierWindowsSettings.ps1'")
    $archNeedle=@'
$streamHeaders=(& $dumpbin /nologo /headers $streamingCursorExe) -join "`n";if($streamHeaders -notmatch '(?i)machine \(x64\)|8664 machine'){throw 'HuymaierStreamingCursorHost.exe is not x64.'}
'@
    if(-not $builder.Contains($archNeedle)){throw 'Unified cursor could not find streaming host architecture gate.'}
    $archBlock=@'
$streamHeaders=(& $dumpbin /nologo /headers $streamingCursorExe) -join "`n";if($streamHeaders -notmatch '(?i)machine \(x64\)|8664 machine'){throw 'HuymaierStreamingCursorHost.exe is not x64.'}
$unifiedHeaders=(& $dumpbin /nologo /headers $unifiedCursorExe) -join "`n";if($unifiedHeaders -notmatch '(?i)machine \(x64\)|8664 machine'){throw 'HuymaierUnifiedCursorHost.exe is not x64.'}
'@
    $builder=$builder.Replace($archNeedle,$archBlock)
    Set-Content -LiteralPath $CoreBuilderPath -Value $builder -Encoding UTF8
}
