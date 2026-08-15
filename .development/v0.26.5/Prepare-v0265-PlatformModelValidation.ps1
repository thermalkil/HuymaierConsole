Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'

$root=(Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$core=Join-Path $root 'HuymaierConsole.ps1'
$bootstrap=Join-Path $root 'HuymaierBootstrap.ps1'
$installer=Join-Path $root 'Install-HuymaierConsole.ps1'
$builder=Join-Path $root '.build\Build-HuymaierReleaseCandidate.Core.ps1'

# The platform-model transform intentionally layers on top of the same runtime
# transforms used by the release builder. Prepare those prerequisites in the
# checkout before Test-v0265-PlatformModels.ps1 makes its isolated temp copies.
# This keeps the source validator honest without teaching the platform transform
# to accept impossible raw-package ordering.
& (Join-Path $root '.build\Optimize-ProviderConcurrencyPreflight.ps1') -BootstrapPath $bootstrap -InstallerScriptPath $installer
& (Join-Path $root '.build\Optimize-AppLibrary.ps1') -CorePath $core -BootstrapPath $bootstrap -InstallerScriptPath $installer
& (Join-Path $root '.build\Optimize-StreamingController.ps1') -CorePath $core -BootstrapPath $bootstrap -InstallerScriptPath $installer -CoreBuilderPath $builder
& (Join-Path $root '.build\Optimize-UnifiedCursor.ps1') -CorePath $core -BootstrapPath $bootstrap -InstallerScriptPath $installer -CoreBuilderPath $builder

Write-Host 'platformModelValidationPrerequisites: success'
