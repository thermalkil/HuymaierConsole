param([switch]$Remove)

Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
$baseDir=Split-Path -Parent $MyInvocation.MyCommand.Path
$packageDir=Join-Path $baseDir 'FSEPackage'
$manifest=Join-Path $packageDir 'AppxManifest.xml'
$hostSource=Join-Path $baseDir 'HuymaierFSEHost.cs'
$hostExe=Join-Path $packageDir 'HuymaierFSEHost.exe'
$packageName='Huymaier.Console.FSE.Home'
$dataDir=Join-Path $env:LOCALAPPDATA 'Huymaier Console'
$logDir=Join-Path $dataDir 'Logs'
New-Item -ItemType Directory -Force -Path $dataDir,$logDir|Out-Null

function Write-FseLog([string]$Message,[string]$Level='INFO'){
    try{"$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff') [$Level] FSE Home: $Message"|Add-Content (Join-Path $logDir "$(Get-Date -Format 'yyyy-MM-dd').log") -Encoding UTF8}catch{}
}

try{
    if($Remove){
        $packages=@(Get-AppxPackage -Name $packageName -ErrorAction SilentlyContinue)
        foreach($package in $packages){Remove-AppxPackage -Package $package.PackageFullName -ErrorAction Stop}
        Write-FseLog 'Removed Xbox Mode gaming home-app registration.'
        exit 0
    }

    if(-not (Test-Path -LiteralPath $manifest)){throw "Missing manifest: $manifest"}
    if(-not (Test-Path -LiteralPath $hostSource)){throw "Missing host source: $hostSource"}

    $developerKey='HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock'
    New-Item -Path $developerKey -Force|Out-Null
    Set-ItemProperty -Path $developerKey -Name AllowDevelopmentWithoutDevLicense -Type DWord -Value 1

    Get-AppxPackage -Name $packageName -ErrorAction SilentlyContinue|ForEach-Object{
        Remove-AppxPackage -Package $_.PackageFullName -ErrorAction SilentlyContinue
    }

    Remove-Item -LiteralPath $hostExe -Force -ErrorAction SilentlyContinue

    # Windows PowerShell 5.1 does not reliably expose Add-Type -CompilerOptions.
    # Compile the tiny launcher with the inbox .NET Framework compiler instead.
    $compilerCandidates=@(
        (Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'),
        (Join-Path $env:WINDIR 'Microsoft.NET\Framework\v4.0.30319\csc.exe')
    )
    $csc=$compilerCandidates|Where-Object{Test-Path -LiteralPath $_}|Select-Object -First 1
    if([string]::IsNullOrWhiteSpace([string]$csc)){throw 'The inbox C# compiler could not be found.'}

    $compileArgs=@(
        '/nologo',
        '/target:winexe',
        '/platform:x64',
        '/optimize+',
        "/out:$hostExe",
        $hostSource
    )
    & $csc @compileArgs
    if($LASTEXITCODE -ne 0){throw "The FSE host compiler exited with code $LASTEXITCODE."}
    if(-not (Test-Path -LiteralPath $hostExe)){throw 'The FSE host executable was not produced.'}

    Add-AppxPackage -Register $manifest -ForceApplicationShutdown -ErrorAction Stop
    $registered=Get-AppxPackage -Name $packageName -ErrorAction SilentlyContinue|Select-Object -First 1
    if($null -eq $registered){throw 'Windows did not return the registered gaming home-app package.'}
    Write-FseLog "Registered package $($registered.PackageFullName)."
    exit 0
}catch{
    Write-FseLog $_.Exception.ToString() 'ERROR'
    exit 1
}
