param(
    [Parameter(Mandatory=$true)][string]$CorePath,
    [Parameter(Mandatory=$true)][string]$BootstrapPath,
    [Parameter(Mandatory=$true)][string]$InstallerScriptPath
)

Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
foreach($path in @($CorePath,$BootstrapPath,$InstallerScriptPath)){if(-not(Test-Path -LiteralPath $path -PathType Leaf)){throw "App-library transform input missing: $path"}}

$core=Get-Content -Raw -LiteralPath $CorePath -Encoding UTF8
if($core -notmatch 'HUYMAIER_CURATED_APP_LIBRARY_V1'){
    $pathNeedle='$script:ShellRedesignModulePath = Join-Path $script:BaseDir ''HuymaierShellRedesign.ps1'''
    if(-not $core.Contains($pathNeedle)){throw 'App-library transform could not find shell redesign module path.'}
    $core=$core.Replace($pathNeedle,$pathNeedle+"`r`n`$script:AppLibraryModulePath = Join-Path `$script:BaseDir 'HuymaierAppLibrary.ps1'")
    $loadNeedle='if (Test-Path -LiteralPath $script:EmulatorPlatformsModulePath) {'
    if(-not $core.Contains($loadNeedle)){throw 'App-library transform could not find emulator-platform load boundary.'}
    $load=@'
# HUYMAIER_CURATED_APP_LIBRARY_V1
if (Test-Path -LiteralPath $script:AppLibraryModulePath) {
    try { . $script:AppLibraryModulePath }
    catch { Write-Log "App library module load failed: $($_.Exception.Message)" 'ERROR' }
}
'@
    $core=$core.Replace($loadNeedle,$load+"`r`n"+$loadNeedle)
    Set-Content -LiteralPath $CorePath -Value $core -Encoding UTF8
}

$bootstrap=Get-Content -Raw -LiteralPath $BootstrapPath -Encoding UTF8
if($bootstrap -notmatch 'HUYMAIER_APP_LIBRARY_PREFLIGHT_V1'){
    $pathNeedle='$shellRedesignPath=Join-Path $baseDir ''HuymaierShellRedesign.ps1'''
    if(-not $bootstrap.Contains($pathNeedle)){throw 'App-library transform could not find bootstrap shell path.'}
    $bootstrap=$bootstrap.Replace($pathNeedle,$pathNeedle+"`r`n# HUYMAIER_APP_LIBRARY_PREFLIGHT_V1`r`n`$appLibraryPath=Join-Path `$baseDir 'HuymaierAppLibrary.ps1'`r`n`$appInstallWorkerPath=Join-Path `$baseDir 'HuymaierAppInstallWorker.ps1'")
    $entryNeedle='        [pscustomobject]@{Path=$shellRedesignPath;Label=''Shell redesign''},'
    if(-not $bootstrap.Contains($entryNeedle)){throw 'App-library transform could not find bootstrap shell preflight entry.'}
    $entries=$entryNeedle+"`r`n        [pscustomobject]@{Path=`$appLibraryPath;Label='Curated app library'},`r`n        [pscustomobject]@{Path=`$appInstallWorkerPath;Label='Native app install worker'},"
    $bootstrap=$bootstrap.Replace($entryNeedle,$entries)
    Set-Content -LiteralPath $BootstrapPath -Value $bootstrap -Encoding UTF8
}

$installer=Get-Content -Raw -LiteralPath $InstallerScriptPath -Encoding UTF8
if($installer -notmatch 'HUYMAIER_APP_LIBRARY_INSTALLER_CACHE_V1'){
    $entryNeedle="            'HuymaierShellRedesign.ps1',"
    if(-not $installer.Contains($entryNeedle)){throw 'App-library transform could not find installer preflight entry.'}
    $entries=$entryNeedle+"`r`n            # HUYMAIER_APP_LIBRARY_INSTALLER_CACHE_V1`r`n            'HuymaierAppLibrary.ps1',`r`n            'HuymaierAppInstallWorker.ps1',"
    $installer=$installer.Replace($entryNeedle,$entries)
    Set-Content -LiteralPath $InstallerScriptPath -Value $installer -Encoding UTF8
}
