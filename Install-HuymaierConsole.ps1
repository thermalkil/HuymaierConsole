param([switch]$SilentUpdate)
Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'

$core=Join-Path $PSScriptRoot 'HuymaierInstallerCore.ps1'
if(-not(Test-Path -LiteralPath $core -PathType Leaf)){
    try{
        Add-Type -AssemblyName PresentationFramework -ErrorAction SilentlyContinue
        [System.Windows.MessageBox]::Show("Huymaier Console installation cannot start because HuymaierInstallerCore.ps1 is missing.`n`nPackage:`n$PSScriptRoot",'Huymaier Console Installer','OK','Error')|Out-Null
    }catch{}
    exit 1
}

function Write-HuymaierStartupPreflightCache {
    param([string]$InstallRoot,[string]$Version='0.30.7')
    try{
        $entries=@(
            'HuymaierConsole.ps1',
            'HuymaierLibraryWorker.ps1',
            'HuymaierPs1LibraryWorker.ps1',
            'HuymaierStorefronts.ps1',
            'HuymaierStorefrontWorker.ps1',
            'HuymaierGameProviders.ps1',
            'HuymaierGameProviderWorker.ps1',
            'HuymaierProviderTelemetry.ps1',
            'HuymaierProviderProgressWorker.ps1',
            'HuymaierProviderTelemetryCoordinator.ps1',
            'HuymaierProviderConcurrency.ps1',
            'HuymaierProviderConcurrencyUi.ps1',
            'HuymaierProviderTransferCoordinator.ps1',
            'HuymaierArtworkWorker.ps1',
            'HuymaierGameExperience.ps1',
            'HuymaierShellRedesign.ps1',
            # HUYMAIER_APP_LIBRARY_INSTALLER_CACHE_V1
            'HuymaierAppLibrary.ps1',
            'HuymaierAppInstallWorker.ps1',
            # HUYMAIER_STREAMING_CONTROLLER_INSTALLER_CACHE_V1
            'HuymaierStreamingController.ps1',
            # HUYMAIER_UNIFIED_CURSOR_INSTALLER_CACHE_V1
            'HuymaierUnifiedCursor.ps1',
            # HUYMAIER_PLATFORM_3D_LIVE_INSTALLER_CACHE_V2
            'HuymaierPlatformModels.ps1',
            'HuymaierLivePlatformModels.ps1',
            # HUYMAIER_USER_3D_MODELS_INSTALLER_CACHE_V1
            'HuymaierUser3DModels.ps1',
            # HUYMAIER_GPU_3D_SHELVES_INSTALLER_CACHE_V1
            'HuymaierGpuPlatformShelves.ps1',
            # HUYMAIER_MANUAL_RECOMPS_INSTALLER_CACHE_V1
            'HuymaierRecompsManual.ps1',
            'HuymaierRecompsFinal.ps1',
            # HUYMAIER_V0304_MODEL_DEFAULT_INSTALLER_CACHE_V1
            'HuymaierModelDefaults.ps1',
            'HuymaierD3D11ShelfRenderer.dll',
            'HuymaierGpuShelfHost.dll',
            'HuymaierGpuShelfAssetCompiler.exe',
            'HuymaierLiveModel3D.dll',
            'HuymaierGameBar.ps1'
        )
        $files=New-Object System.Collections.ArrayList
        foreach($name in $entries){
            $path=Join-Path $InstallRoot $name
            if(-not(Test-Path -LiteralPath $path -PathType Leaf)){return}
            $item=Get-Item -LiteralPath $path -ErrorAction Stop
            [void]$files.Add([pscustomobject]@{
                Name=[IO.Path]::GetFileName($item.FullName)
                Length=[int64]$item.Length
                LastWriteUtcTicks=[int64]$item.LastWriteTimeUtc.Ticks
            })
        }
        $cache=[pscustomobject]@{
            SchemaVersion=1
            ConsoleVersion=$Version
            BaseDir=[IO.Path]::GetFullPath($InstallRoot).TrimEnd('\')
            Files=[object[]]$files.ToArray()
            ValidatedAtUtc=[DateTime]::UtcNow.ToString('o')
            ValidationSource='installer'
        }
        $path=Join-Path $InstallRoot 'startup-preflight-v1.json'
        $temp="$path.$PID.tmp"
        $cache|ConvertTo-Json -Depth 6|Set-Content -LiteralPath $temp -Encoding UTF8
        Move-Item -LiteralPath $temp -Destination $path -Force
    }catch{
        # Cache creation is only a performance optimization. The bootstrap will
        # perform the normal fail-closed syntax preflight if this seed is absent.
    }
}

# Seed the process exit state because an interactive successful PowerShell
# script invocation may never create $LASTEXITCODE. The installer core uses
# explicit `exit 1` for a transactional failure, which updates this value; a
# normal interactive success leaves the seeded 0 unchanged.
$global:LASTEXITCODE=0
& $core -PackageRoot $PSScriptRoot -SilentUpdate:$SilentUpdate
if([int]$global:LASTEXITCODE -eq 0){
    Write-HuymaierStartupPreflightCache -InstallRoot (Join-Path $env:LOCALAPPDATA 'Huymaier Console') -Version '0.30.7'
}
exit ([int]$global:LASTEXITCODE)






