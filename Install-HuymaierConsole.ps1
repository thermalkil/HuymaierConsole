param([switch]$SilentUpdate)
Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

$script:InstallVersion = '0.26.0'
$script:InstallStartedUtc = [DateTime]::UtcNow
$script:InstallLogRoot = Join-Path $env:LOCALAPPDATA 'Huymaier Console\Logs'
New-Item -ItemType Directory -Force -Path $script:InstallLogRoot | Out-Null
$script:InstallLogPath = Join-Path $script:InstallLogRoot ('install-v{0}-{1}.log' -f $script:InstallVersion,(Get-Date -Format 'yyyyMMdd-HHmmss'))
$script:TranscriptStarted = $false
$script:TranscriptLogPath = Join-Path $script:InstallLogRoot ('transcript-v{0}-{1}.log' -f $script:InstallVersion,(Get-Date -Format 'yyyyMMdd-HHmmss'))

function Write-InstallerRecord {
    param([string]$Message,[string]$Level='INFO')
    $line = '{0} [{1}] {2}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff'),$Level,$Message
    try { Add-Content -LiteralPath $script:InstallLogPath -Value $line -Encoding UTF8 } catch { }
    try {
        if($Level -eq 'ERROR'){ Write-Host $line -ForegroundColor Red }
        elseif($Level -eq 'WARN'){ Write-Host $line -ForegroundColor Yellow }
        else { Write-Host $line }
    } catch { }
}

trap {
    $failure = $_
    $position = ''
    try { $position = [string]$failure.InvocationInfo.PositionMessage } catch { }
    $details = [string]$failure.Exception.Message
    if(-not [string]::IsNullOrWhiteSpace($position)){ $details += "`r`n`r`n$position" }
    try {
        if($failure.ScriptStackTrace){ $details += "`r`n`r`nScript stack:`r`n$($failure.ScriptStackTrace)" }
    } catch { }
    Write-InstallerRecord -Level 'ERROR' -Message $details
    try {
        Add-Type -AssemblyName System.Windows.Forms -ErrorAction SilentlyContinue
        [System.Windows.Forms.MessageBox]::Show(
            "Huymaier Console installation failed.`r`n`r`n$details`r`n`r`nInstall log:`r`n$script:InstallLogPath`r`n`r`nTranscript:`r`n$script:TranscriptLogPath",
            'Huymaier Console Installer',
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        ) | Out-Null
    } catch { }
    if($script:TranscriptStarted){ try { Stop-Transcript | Out-Null } catch { } }
    exit 1
}

try {
    Start-Transcript -LiteralPath $script:TranscriptLogPath -Force | Out-Null
    $script:TranscriptStarted = $true
} catch { }
Write-InstallerRecord "Installer v$script:InstallVersion started from $PSScriptRoot"

Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase,System.Xaml,System.Windows.Forms,System.Drawing,System.Web.Extensions

$source = Split-Path -Parent $MyInvocation.MyCommand.Path

# Validate every packaged PowerShell source before copying or compiling. This
# catches both real syntax mistakes and Windows PowerShell 5.1 encoding issues.
$scriptFiles = @(Get-ChildItem -LiteralPath $source -Filter '*.ps1' -File -Recurse -ErrorAction Stop)
$parseFailures = New-Object System.Collections.Generic.List[string]
foreach($scriptFile in $scriptFiles){
    $tokens = $null
    $parseErrors = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile($scriptFile.FullName,[ref]$tokens,[ref]$parseErrors)
    foreach($parseError in @($parseErrors)){
        [void]$parseFailures.Add(('{0} line {1}, column {2}: {3}' -f $scriptFile.Name,$parseError.Extent.StartLineNumber,$parseError.Extent.StartColumnNumber,$parseError.Message))
    }
}
if($parseFailures.Count -gt 0){
    throw "PowerShell source validation failed:`r`n$($parseFailures -join "`r`n")"
}
Write-InstallerRecord ('PowerShell source validation passed for {0} script(s).' -f $scriptFiles.Count)

$destination = Join-Path $env:LOCALAPPDATA 'Huymaier Console'
# Browser authorization requests are transient. v0.25.2 removes a stale
# v0.18.0-v0.18.4 request so installing the update cannot reopen a trapped
# sign-in screen. Credentials, cookies, and browser profile data are untouched.
$staleBrowserRequest = Join-Path $env:LOCALAPPDATA 'Huymaier Console\browser-auth-request.json'
Remove-Item -LiteralPath $staleBrowserRequest -Force -ErrorAction SilentlyContinue

New-Item -ItemType Directory -Force -Path $destination | Out-Null

$files = @(
    'HuymaierBootstrap.ps1',
    'HuymaierConsole.ps1',
    'HuymaierNativeDisplay.cs',
    'HuymaierNativeAudio.cs',
    'HuymaierNativeInput.cs',
    'HuymaierPerformance.cs',
    'HuymaierFSEHost.cs',
    'Register-HuymaierFSEHome.ps1',
    'HuymaierUpdateWorker.ps1',
    'HuymaierConsoleUpdateWorker.ps1',
    'HuymaierSelfUpdater.ps1',
    'HuymaierDriverWorker.ps1',
    'HuymaierLibraryWorker.ps1',
    'HuymaierStorefronts.ps1',
    'HuymaierStorefrontWorker.ps1',
    'HuymaierGameProviders.ps1',
    'HuymaierGameProviderWorker.ps1',
    'HuymaierGameExperience.ps1',
    'HuymaierShellRedesign.ps1',
    'HuymaierGameBar.ps1',
    'HuymaierGameInputBridge.dll',
    'HuymaierEmulatorPlatforms.ps1',
    'HuymaierArtworkWorker.ps1',
    'HuymaierPs3LibraryWorker.ps1',
    'HuymaierPs2LibraryWorker.ps1',
    'HuymaierPs1LibraryWorker.ps1',
    'HuymaierNativeConsoleLibraryWorker.ps1',
    'HuymaierWebBrowser.ps1',
    'Launch-HuymaierConsole.cmd',
    'Launch-Windowed.cmd',
    'HuymaierConsole.ico',
    'README.txt',
    'Uninstall-HuymaierConsole.cmd',
    'RELEASE_NOTES.txt',
    'THIRD_PARTY_NOTICES.txt'
)
foreach ($file in $files) {
    $src = Join-Path $source $file
    if (Test-Path $src) { Copy-Item $src (Join-Path $destination $file) -Force }
}


$fseSource=Join-Path $source 'FSEPackage'
$fseDestination=Join-Path $destination 'FSEPackage'
if(Test-Path $fseSource){
    New-Item -ItemType Directory -Force -Path $fseDestination|Out-Null
    Copy-Item (Join-Path $fseSource '*') $fseDestination -Recurse -Force
}

$assetSource = Join-Path $source 'Assets'
$assetDestination = Join-Path $destination 'Assets'
if (Test-Path $assetSource) {
    New-Item -ItemType Directory -Force -Path $assetDestination | Out-Null
    Copy-Item (Join-Path $assetSource '*') $assetDestination -Recurse -Force
}


$emulatorSource=Join-Path $source 'EmulatorPlatforms'
$emulatorDestination=Join-Path $destination 'EmulatorPlatforms'
if(Test-Path $emulatorSource){
    New-Item -ItemType Directory -Force -Path $emulatorDestination|Out-Null
    Copy-Item (Join-Path $emulatorSource '*') $emulatorDestination -Recurse -Force
}
$toolsSource=Join-Path $source 'Tools'
$toolsDestination=Join-Path $destination 'Tools'
if(Test-Path $toolsSource){
    New-Item -ItemType Directory -Force -Path $toolsDestination|Out-Null
    Copy-Item (Join-Path $toolsSource '*') $toolsDestination -Recurse -Force
}

# Microsoft GameInput is the primary Xbox system-button path for v0.26+.
# The official redistributable does not downgrade a newer installed runtime.
$gameInputRedistVersion='3.5.262'
$gameInputRedist=Join-Path $toolsDestination 'GameInput\GameInputRedist.msi'
$gameInputMarker=Join-Path $destination 'gameinput-redist.version'
$installedGameInputVersion=''
try{if(Test-Path -LiteralPath $gameInputMarker -PathType Leaf){$installedGameInputVersion=(Get-Content -Raw -LiteralPath $gameInputMarker).Trim()}}catch{}
if((Test-Path -LiteralPath $gameInputRedist -PathType Leaf) -and $installedGameInputVersion -ne $gameInputRedistVersion){
    try{
        Write-InstallerRecord "Installing Microsoft GameInput redistributable $gameInputRedistVersion. Windows may request administrator approval."
        $msiArgs='/i "'+$gameInputRedist+'" /qn /norestart'
        $gameInputInstall=Start-Process -FilePath "$env:SystemRoot\System32\msiexec.exe" -ArgumentList $msiArgs -Verb RunAs -Wait -PassThru
        if($gameInputInstall.ExitCode -notin @(0,3010,1638)){throw "GameInput redistributable installer exited with code $($gameInputInstall.ExitCode)."}
        Set-Content -LiteralPath $gameInputMarker -Value $gameInputRedistVersion -Encoding ASCII
        Write-InstallerRecord 'Microsoft GameInput redistributable is ready.'
    }catch{Write-InstallerRecord "Microsoft GameInput redistributable could not be installed; controller input will fall back to Raw HID/XInput where available. $($_.Exception.Message)" 'WARN'}
}

$nativeSourceRoot=Join-Path $source 'Native'
$nativeDestinationRoot=Join-Path $destination 'Native'
if(Test-Path $nativeSourceRoot){
    New-Item -ItemType Directory -Force -Path $nativeDestinationRoot|Out-Null
    Copy-Item (Join-Path $nativeSourceRoot '*') $nativeDestinationRoot -Recurse -Force
}

# Remove Mark-of-the-Web from installed local files so the compiled host can
# relaunch even when Windows PowerShell is configured for RemoteSigned.
try { Get-ChildItem -LiteralPath $destination -Recurse -File -ErrorAction SilentlyContinue | Unblock-File -ErrorAction SilentlyContinue } catch { }

# Stop a running native host before replacing HuymaierConsole.exe. Earlier
# installers could fail with a locked executable and then close before the user
# could read the error.
$runningConsole = @(Get-Process -Name 'HuymaierConsole' -ErrorAction SilentlyContinue)
if($runningConsole.Count -gt 0){
    Write-InstallerRecord ('Closing {0} running Huymaier Console process(es).' -f $runningConsole.Count)
    $runningConsole | Stop-Process -Force -ErrorAction Stop
    $deadline = [DateTime]::UtcNow.AddSeconds(8)
    do {
        Start-Sleep -Milliseconds 150
        $stillRunning = @(Get-Process -Name 'HuymaierConsole' -ErrorAction SilentlyContinue)
    } while($stillRunning.Count -gt 0 -and [DateTime]::UtcNow -lt $deadline)
    if($stillRunning.Count -gt 0){ throw 'HuymaierConsole.exe is still running and could not be replaced.' }
}

# Build the normal-use Windows GUI executable. PowerShell is used only here as
# an installer/compiler host; HuymaierConsole.exe owns the runtime process and
# loads the existing modules in-process with no visible shell window.
$nativeExe=Join-Path $destination 'HuymaierConsole.exe'
$nativeTemp=Join-Path $destination 'HuymaierConsole.native.new.exe'
$nativeAppSource=Join-Path $nativeDestinationRoot 'HuymaierConsole.NativeApp.cs'
$nativePs1Source=Join-Path $nativeDestinationRoot 'HuymaierConsole.Ps1.cs'
$nativeConsolePlatformsSource=Join-Path $nativeDestinationRoot 'HuymaierConsole.ConsolePlatforms.cs'
$nativeGameBarSource=Join-Path $nativeDestinationRoot 'HuymaierGameBar.cs'
$nativeGameInputSource=Join-Path $nativeDestinationRoot 'HuymaierConsole.GameInput.cs'
$nativeInputSource=Join-Path $destination 'HuymaierNativeInput.cs'
$nativeDisplaySource=Join-Path $destination 'HuymaierNativeDisplay.cs'
$nativeAudioSource=Join-Path $destination 'HuymaierNativeAudio.cs'
$nativePerformanceSource=Join-Path $destination 'HuymaierPerformance.cs'
$p3tSource=Join-Path $destination 'EmulatorPlatforms\Shared\Huymaier.P3T.cs'
foreach($requiredSource in @($nativeAppSource,$nativePs1Source,$nativeConsolePlatformsSource,$nativeGameBarSource,$nativeGameInputSource,$nativeInputSource,$nativeDisplaySource,$nativeAudioSource,$nativePerformanceSource,$p3tSource)){
    if(-not (Test-Path -LiteralPath $requiredSource)){throw "Native application source is missing: $requiredSource"}
}
Remove-Item -LiteralPath $nativeTemp -Force -ErrorAction SilentlyContinue
$cscCandidates=@(
    (Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'),
    (Join-Path $env:WINDIR 'Microsoft.NET\Framework\v4.0.30319\csc.exe')
)
$csc=$cscCandidates|Where-Object{Test-Path -LiteralPath $_ -PathType Leaf}|Select-Object -First 1
if(-not $csc){throw 'The Windows .NET Framework C# compiler was not found.'}
$automationAssembly=[System.Management.Automation.PSObject].Assembly.Location
# Compile without csc.rsp so standard .NET assemblies are not imported a
# second time behind the installer. Resolve every required framework reference
# from assemblies already loaded by Windows PowerShell, using full paths.
$frameworkReferences=@(
    [System.Uri].Assembly.Location,
    [System.Linq.Enumerable].Assembly.Location,
    [System.Xaml.XamlReader].Assembly.Location,
    [System.Xml.XmlDocument].Assembly.Location,
    [System.Windows.DependencyObject].Assembly.Location,
    [System.Windows.Media.Visual].Assembly.Location,
    [System.Windows.Window].Assembly.Location,
    [System.Windows.Forms.Form].Assembly.Location,
    [System.Drawing.Bitmap].Assembly.Location,
    [System.Web.Script.Serialization.JavaScriptSerializer].Assembly.Location,
    $automationAssembly
) | Select-Object -Unique
foreach($frameworkReference in $frameworkReferences){
    if([string]::IsNullOrWhiteSpace([string]$frameworkReference) -or -not (Test-Path -LiteralPath $frameworkReference -PathType Leaf)){
        throw "Required compiler reference could not be resolved: $frameworkReference"
    }
    Write-InstallerRecord "Compiler reference: $frameworkReference"
}
$compilerArgs=@(
    '/noconfig',
    '/nologo',
    '/target:winexe',
    '/platform:anycpu',
    '/optimize+',
    ('/out:'+ $nativeTemp),
    ('/win32icon:'+ (Join-Path $destination 'HuymaierConsole.ico'))
)
foreach($frameworkReference in $frameworkReferences){
    $compilerArgs += ('/reference:'+ $frameworkReference)
}
$compilerArgs += @(
    $nativeAppSource,
    $nativePs1Source,
    $nativeConsolePlatformsSource,
    $nativeGameBarSource,
    $nativeGameInputSource,
    $nativeInputSource,
    $nativeDisplaySource,
    $nativeAudioSource,
    $nativePerformanceSource,
    $p3tSource
)
$compilerStamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$compilerStdOut = Join-Path $script:InstallLogRoot ('compiler-v{0}-{1}.stdout.log' -f $script:InstallVersion,$compilerStamp)
$compilerStdErr = Join-Path $script:InstallLogRoot ('compiler-v{0}-{1}.stderr.log' -f $script:InstallVersion,$compilerStamp)
try{
    Write-InstallerRecord "Compiling native application with $csc"
    Push-Location $destination
    try{
        $compilerOutput = @(& $csc @compilerArgs 2>&1 | ForEach-Object { [string]$_ })
        $compilerExitCode = $LASTEXITCODE
    } finally {
        Pop-Location
    }
    $compilerOutput | Set-Content -LiteralPath $compilerStdOut -Encoding UTF8
    if(-not (Test-Path -LiteralPath $compilerStdErr)){ New-Item -ItemType File -Path $compilerStdErr -Force | Out-Null }
    foreach($compilerLine in $compilerOutput){ if(-not [string]::IsNullOrWhiteSpace([string]$compilerLine)){ Write-InstallerRecord ([string]$compilerLine) 'COMPILER' } }
    if($compilerExitCode -ne 0){
        $summary = ($compilerOutput | Select-Object -Last 30) -join "`r`n"
        throw "C# compiler exited with code $compilerExitCode.`r`n$summary"
    }
    if(-not (Test-Path -LiteralPath $nativeTemp -PathType Leaf)){throw 'The native compiler did not create HuymaierConsole.exe.'}
    Move-Item -LiteralPath $nativeTemp -Destination $nativeExe -Force
    Write-InstallerRecord "Native application installed at $nativeExe"
}catch{
    Remove-Item -LiteralPath $nativeTemp -Force -ErrorAction SilentlyContinue
    throw "The native Huymaier Console application could not be compiled or installed. $($_.Exception.Message)"
}

# v0.25.2 keeps the Console-side HES integration retired while leaving the separate
# Huymaier Entertainment System server project untouched.
Remove-Item -LiteralPath (Join-Path $assetDestination 'Platforms\hes.png') -Force -ErrorAction SilentlyContinue
Remove-Item -LiteralPath (Join-Path $destination 'GameProviders\Config\HES') -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -LiteralPath (Join-Path $destination 'GameProviders\Artwork\HES') -Recurse -Force -ErrorAction SilentlyContinue
foreach($legacy in @('hes.json','hes-auth.json','hes-token.json','hes-platforms.json','hes-cache.json')){
    Remove-Item -LiteralPath (Join-Path $destination $legacy) -Force -ErrorAction SilentlyContinue
}
$configFile=Join-Path $destination 'config.json'
if(Test-Path -LiteralPath $configFile){
    try{
        $cfg=Get-Content -Raw -LiteralPath $configFile|ConvertFrom-Json
        foreach($property in @('HesServerUrl','HesApiUrl')){if($cfg.PSObject.Properties[$property]){$cfg.PSObject.Properties.Remove($property)}}
        foreach($collection in @('ImportedGames','RecentGames','FavoriteGames')){
            if($cfg.PSObject.Properties[$collection]){
                $cfg.$collection=[object[]]@($cfg.$collection|Where-Object{
                    -not [string]::Equals([string]$_.Source,'HES',[StringComparison]::OrdinalIgnoreCase) -and
                    -not [string]::Equals([string]$_.Provider,'HES',[StringComparison]::OrdinalIgnoreCase)
                })
            }
        }
        $cfg|ConvertTo-Json -Depth 10|Set-Content -LiteralPath $configFile -Encoding UTF8
    }catch{}
}
$catalogFile=Join-Path $destination 'GameProviders\provider-catalog.json'
if(Test-Path -LiteralPath $catalogFile){
    try{
        $catalog=Get-Content -Raw -LiteralPath $catalogFile|ConvertFrom-Json
        $catalog.Providers=[object[]]@($catalog.Providers|Where-Object{-not [string]::Equals([string]$_.Id,'HES',[StringComparison]::OrdinalIgnoreCase)})
        $catalog|ConvertTo-Json -Depth 12|Set-Content -LiteralPath $catalogFile -Encoding UTF8
    }catch{}
}


# Install the app-local WebView2 WPF SDK. The Evergreen browser Runtime remains
# maintained by Microsoft; only the small managed SDK and x64 loader are stored
# with Huymaier Console.
$webViewFolder=Join-Path $destination 'WebView2'
$webViewReady=(Test-Path (Join-Path $webViewFolder 'Microsoft.Web.WebView2.Core.dll')) -and
              (Test-Path (Join-Path $webViewFolder 'Microsoft.Web.WebView2.Wpf.dll')) -and
              (Test-Path (Join-Path $webViewFolder 'WebView2Loader.dll'))
if(-not $webViewReady){
    $tempRoot=Join-Path $env:TEMP ('Huymaier-WebView2-'+[guid]::NewGuid().ToString('N'))
    try{
        [Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12
        New-Item -ItemType Directory -Force -Path $tempRoot,$webViewFolder|Out-Null
        $package=Join-Path $tempRoot 'webview2.nupkg'
        $archive=Join-Path $tempRoot 'webview2.zip'
        Invoke-WebRequest -UseBasicParsing -Uri 'https://www.nuget.org/api/v2/package/Microsoft.Web.WebView2/1.0.4078.44' -OutFile $package
        Copy-Item $package $archive -Force
        $expanded=Join-Path $tempRoot 'expanded';Expand-Archive -LiteralPath $archive -DestinationPath $expanded -Force
        $core=Get-ChildItem -LiteralPath (Join-Path $expanded 'lib') -Recurse -Filter 'Microsoft.Web.WebView2.Core.dll'|Where-Object{$_.FullName -match 'net462|net48|net45'}|Sort-Object @{Expression={if($_.FullName -match 'net462'){0}elseif($_.FullName -match 'net48'){1}else{2}}},FullName|Select-Object -First 1
        $wpf=Get-ChildItem -LiteralPath (Join-Path $expanded 'lib') -Recurse -Filter 'Microsoft.Web.WebView2.Wpf.dll'|Where-Object{$_.FullName -match 'net462|net48|net45'}|Sort-Object @{Expression={if($_.FullName -match 'net462'){0}elseif($_.FullName -match 'net48'){1}else{2}}},FullName|Select-Object -First 1
        $loader=Get-ChildItem -LiteralPath (Join-Path $expanded 'runtimes') -Recurse -Filter 'WebView2Loader.dll'|Where-Object{$_.FullName -match 'win-x64'}|Select-Object -First 1
        if($null -eq $core -or $null -eq $wpf -or $null -eq $loader){throw 'The official WebView2 SDK package did not contain the required WPF x64 files.'}
        Copy-Item $core.FullName (Join-Path $webViewFolder $core.Name) -Force
        Copy-Item $wpf.FullName (Join-Path $webViewFolder $wpf.Name) -Force
        Copy-Item $loader.FullName (Join-Path $webViewFolder $loader.Name) -Force
        $webViewReady=$true
    }catch{
        [System.Windows.MessageBox]::Show("The native browser SDK could not be downloaded.`n`n$($_.Exception.Message)`n`nHuymaier Console will still install, but browser-based sign-in will require rerunning this installer while online.",'Huymaier Console','OK','Warning')|Out-Null
    }finally{Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue}
}

# Ensure the Microsoft Evergreen Runtime is available. Windows 11 commonly has
# it already; the official bootstrapper is invoked only when version discovery
# fails after loading the app-local SDK.
if($webViewReady){
    $runtimeAvailable=$false
    try{
        $oldPath=$env:PATH;$env:PATH=$webViewFolder+';'+$env:PATH
        Add-Type -Path (Join-Path $webViewFolder 'Microsoft.Web.WebView2.Core.dll') -ErrorAction Stop
        $version=[Microsoft.Web.WebView2.Core.CoreWebView2Environment]::GetAvailableBrowserVersionString()
        $runtimeAvailable=-not [string]::IsNullOrWhiteSpace([string]$version)
    }catch{}finally{$env:PATH=$oldPath}
    if(-not $runtimeAvailable){
        $bootstrapper=Join-Path $env:TEMP ('MicrosoftEdgeWebview2Setup-'+[guid]::NewGuid().ToString('N')+'.exe')
        try{
            Invoke-WebRequest -UseBasicParsing -Uri 'https://go.microsoft.com/fwlink/p/?LinkId=2124703' -OutFile $bootstrapper
            $runtimeInstall=Start-Process -FilePath $bootstrapper -ArgumentList '/silent','/install' -Wait -PassThru
            if($runtimeInstall.ExitCode -ne 0){throw "WebView2 Runtime installer exited with code $($runtimeInstall.ExitCode)."}
        }catch{
            [System.Windows.MessageBox]::Show("The Microsoft WebView2 Runtime could not be installed.`n`n$($_.Exception.Message)`n`nThe rest of Huymaier Console remains available.",'Huymaier Console','OK','Warning')|Out-Null
        }finally{Remove-Item -LiteralPath $bootstrapper -Force -ErrorAction SilentlyContinue}
    }
}
try { Get-ChildItem -LiteralPath $destination -Recurse -File -ErrorAction SilentlyContinue | Unblock-File -ErrorAction SilentlyContinue } catch { }

$legacyTheme = Join-Path $assetDestination 'HuymaierTheme.wav'
if (Test-Path $legacyTheme) { Remove-Item $legacyTheme -Force -ErrorAction SilentlyContinue }

$wsh = New-Object -ComObject WScript.Shell
$nativeExe = Join-Path $destination 'HuymaierConsole.exe'
$arguments = ''

$desktop = [Environment]::GetFolderPath('Desktop')
$startMenu = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs'
foreach ($folder in @($desktop,$startMenu)) {
    $shortcutPath = Join-Path $folder 'Huymaier Console.lnk'
    $shortcut = $wsh.CreateShortcut($shortcutPath)
    $shortcut.TargetPath = $nativeExe
    $shortcut.Arguments = $arguments
    $shortcut.WorkingDirectory = $destination
    $icon = Join-Path $destination 'HuymaierConsole.ico'
    if (Test-Path $icon) { $shortcut.IconLocation = $icon }
    $shortcut.Description = 'Huymaier Console Windows 11 FSE'
    $shortcut.Save()
}

Write-InstallerRecord "Installation completed successfully at $destination"
if($script:TranscriptStarted){ try { Stop-Transcript | Out-Null; $script:TranscriptStarted=$false } catch { } }

if($SilentUpdate){
    Write-InstallerRecord 'Silent self-update installation completed; relaunch is delegated to HuymaierSelfUpdater.ps1.'
    exit 0
}
$result = [System.Windows.MessageBox]::Show("Huymaier Console v0.25.6 stabilization build was installed for this Windows account.`n`nLocation:`n$destination`n`nLaunch it now?", 'Huymaier Console', 'YesNo', 'Information')
if ($result -eq 'Yes') {
    Start-Process $nativeExe -WorkingDirectory $destination
}
