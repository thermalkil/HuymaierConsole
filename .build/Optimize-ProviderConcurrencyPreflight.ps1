param(
    [Parameter(Mandatory=$true)][string]$BootstrapPath,
    [Parameter(Mandatory=$true)][string]$InstallerScriptPath
)
Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
foreach($path in @($BootstrapPath,$InstallerScriptPath)){if(-not(Test-Path -LiteralPath $path -PathType Leaf)){throw "Provider preflight transform input missing: $path"}}

$bootstrap=Get-Content -Raw -LiteralPath $BootstrapPath -Encoding UTF8
if($bootstrap -notmatch 'HuymaierProviderTransferCoordinator.ps1'){
    $pathNeedle='$providerTelemetryCoordinatorPath=Join-Path $baseDir ''HuymaierProviderTelemetryCoordinator.ps1'''
    if(-not $bootstrap.Contains($pathNeedle)){throw 'Provider preflight transform could not find bootstrap provider coordinator path.'}
    $pathReplacement=$pathNeedle+"`r`n"+'$providerConcurrencyPath=Join-Path $baseDir ''HuymaierProviderConcurrency.ps1'''+"`r`n"+'$providerConcurrencyUiPath=Join-Path $baseDir ''HuymaierProviderConcurrencyUi.ps1'''+"`r`n"+'$providerTransferCoordinatorPath=Join-Path $baseDir ''HuymaierProviderTransferCoordinator.ps1'''
    $bootstrap=$bootstrap.Replace($pathNeedle,$pathReplacement)

    $entryNeedle="        [pscustomobject]@{Path=`$providerTelemetryCoordinatorPath;Label='Provider telemetry coordinator'},"
    if(-not $bootstrap.Contains($entryNeedle)){throw 'Provider preflight transform could not find bootstrap provider coordinator entry.'}
    $entryReplacement=$entryNeedle+"`r`n        [pscustomobject]@{Path=`$providerConcurrencyPath;Label='Provider concurrency layer'},`r`n        [pscustomobject]@{Path=`$providerConcurrencyUiPath;Label='Provider concurrent Downloads UI'},`r`n        [pscustomobject]@{Path=`$providerTransferCoordinatorPath;Label='Provider transfer coordinator'},"
    $bootstrap=$bootstrap.Replace($entryNeedle,$entryReplacement)
    Set-Content -LiteralPath $BootstrapPath -Value $bootstrap -Encoding UTF8
}

$installer=Get-Content -Raw -LiteralPath $InstallerScriptPath -Encoding UTF8
if($installer -notmatch "'HuymaierProviderTransferCoordinator.ps1'"){
    $entry="            'HuymaierProviderTelemetryCoordinator.ps1',"
    if(-not $installer.Contains($entry)){throw 'Provider preflight transform could not find installer cache provider coordinator entry.'}
    $replacement=$entry+"`r`n            'HuymaierProviderConcurrency.ps1',`r`n            'HuymaierProviderConcurrencyUi.ps1',`r`n            'HuymaierProviderTransferCoordinator.ps1',"
    $installer=$installer.Replace($entry,$replacement)
    Set-Content -LiteralPath $InstallerScriptPath -Value $installer -Encoding UTF8
}
