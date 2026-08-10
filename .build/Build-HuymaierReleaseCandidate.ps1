param(
    [Parameter(Mandatory=$true)][string]$TriggerPath
)
Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'

$trigger=Get-Content -Raw -LiteralPath $TriggerPath -Encoding UTF8|ConvertFrom-Json
$version=[string]$trigger.version
$baseRelease=[string]$trigger.base_release
$baseAsset=[string]$trigger.base_asset
$packageRoot=[string]$trigger.package_root
$assetName=[string]$trigger.asset_name
if([string]::IsNullOrWhiteSpace($version) -or [string]::IsNullOrWhiteSpace($baseRelease) -or [string]::IsNullOrWhiteSpace($baseAsset) -or [string]::IsNullOrWhiteSpace($packageRoot) -or [string]::IsNullOrWhiteSpace($assetName)){throw 'Candidate trigger is missing required fields.'}

$workspace=$env:GITHUB_WORKSPACE
$temp=$env:RUNNER_TEMP
$baseDir=Join-Path $temp 'hc-base'
$extract=Join-Path $temp 'hc-base-extract'
$stageParent=Join-Path $temp 'hc-stage'
$stage=Join-Path $stageParent $packageRoot
$out=Join-Path $temp 'hc-output'
Remove-Item $baseDir,$extract,$stageParent,$out -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path $baseDir,$extract,$stage,$out|Out-Null

Write-Host "Staging $assetName from $baseRelease / $baseAsset"
& gh release download $baseRelease --repo $env:GITHUB_REPOSITORY --pattern $baseAsset --dir $baseDir
if($LASTEXITCODE -ne 0){throw "Could not download $baseAsset from $baseRelease."}
$baseZip=Join-Path $baseDir $baseAsset
if(-not(Test-Path -LiteralPath $baseZip -PathType Leaf)){throw "Base asset missing: $baseZip"}
Expand-Archive -LiteralPath $baseZip -DestinationPath $extract -Force
$roots=@(Get-ChildItem -LiteralPath $extract -Directory)
$baseRoot=if($roots.Count -eq 1){$roots[0].FullName}else{$extract}
Copy-Item (Join-Path $baseRoot '*') $stage -Recurse -Force

# Overlay repository-owned production payload only. Developer/release machinery
# is never allowed into the install ZIP.
$excludeRegex='^(\.github/|\.development/|\.release/|\.source/|\.build/|Docs/|\.gitignore$|README\.md$|RELEASING\.md$|GITHUB-RELEASES\.md$)'
foreach($relative in @(& git ls-files)){
    if([string]::IsNullOrWhiteSpace($relative) -or $relative -match $excludeRegex){continue}
    $src=Join-Path $workspace ($relative -replace '/','\')
    if(-not(Test-Path -LiteralPath $src -PathType Leaf)){continue}
    $dst=Join-Path $stage ($relative -replace '/','\')
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $dst)|Out-Null
    Copy-Item -LiteralPath $src -Destination $dst -Force
}

# Files inherited from old packages but retired from the active architecture.
foreach($dead in @(
    'HuymaierGuideInput.cs',
    'HuymaierGuideBridge.dll',
    'HuymaierConsoleUpdate.ps1',
    'HuymaierConsoleApplyUpdate.ps1',
    'Native\GuideBridge'
)){Remove-Item -LiteralPath (Join-Path $stage $dead) -Recurse -Force -ErrorAction SilentlyContinue}

# Microsoft GameInput 3.5.262: build the system-button bridge x64 with static
# MSVC runtime so clean Windows machines do not need a separate VC++ redist.
$giVersion='3.5.262'
$nupkg=Join-Path $temp 'Microsoft.GameInput.nupkg'
$archive=Join-Path $temp 'Microsoft.GameInput.zip'
$expanded=Join-Path $temp 'Microsoft.GameInput'
Invoke-WebRequest -UseBasicParsing -Uri "https://api.nuget.org/v3-flatcontainer/microsoft.gameinput/$giVersion/microsoft.gameinput.$giVersion.nupkg" -OutFile $nupkg
Copy-Item $nupkg $archive -Force
Expand-Archive -LiteralPath $archive -DestinationPath $expanded -Force
$header=Get-ChildItem $expanded -Recurse -Filter GameInput.h -File|Select-Object -First 1
$lib=Get-ChildItem $expanded -Recurse -Filter gameinput.lib -File|Where-Object{$_.FullName -match '(?i)x64|amd64'}|Select-Object -First 1
$redist=Get-ChildItem $expanded -Recurse -Filter GameInputRedist.msi -File|Select-Object -First 1
if($null -eq $header -or $null -eq $lib -or $null -eq $redist){throw 'Microsoft.GameInput package is missing x64 SDK/redist files.'}
$redistDst=Join-Path $stage 'Tools\GameInput\GameInputRedist.msi';New-Item -ItemType Directory -Force -Path (Split-Path -Parent $redistDst)|Out-Null;Copy-Item $redist.FullName $redistDst -Force

$vswhere=Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
$vs=& $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
if(-not $vs){throw 'MSVC x64 toolchain was not found.'}
$vcvars=Join-Path $vs 'VC\Auxiliary\Build\vcvars64.bat'
$bridgeOut=Join-Path $stage 'HuymaierGameInputBridge.dll'
$bridgeSrc=Join-Path $workspace 'Native\HuymaierGameInputBridge.cpp'
$cmd='call "'+$vcvars+'" && cl /nologo /std:c++17 /O2 /EHsc /MT /LD /I"'+$header.Directory.FullName+'" "'+$bridgeSrc+'" /link /LIBPATH:"'+$lib.Directory.FullName+'" gameinput.lib /OUT:"'+$bridgeOut+'"'
cmd.exe /d /s /c $cmd
if($LASTEXITCODE -ne 0 -or -not(Test-Path $bridgeOut)){throw 'x64 static-runtime GameInput bridge compilation failed.'}

# Normalize all Windows PowerShell source to UTF-8 BOM, then parse it with the
# same Windows PowerShell 5.1 language parser used by client machines.
$bom=New-Object Text.UTF8Encoding($true)
$psFiles=@(Get-ChildItem $stage -Recurse -File|Where-Object{$_.Extension -in @('.ps1','.psm1','.psd1')})
foreach($f in $psFiles){$text=[IO.File]::ReadAllText($f.FullName,[Text.Encoding]::UTF8);[IO.File]::WriteAllText($f.FullName,$text,$bom)}
$failures=New-Object Collections.Generic.List[string]
foreach($f in $psFiles){$tokens=$null;$errors=$null;[void][Management.Automation.Language.Parser]::ParseFile($f.FullName,[ref]$tokens,[ref]$errors);foreach($e in @($errors)){[void]$failures.Add("$($f.FullName):$($e.Extent.StartLineNumber):$($e.Extent.StartColumnNumber) $($e.Message)")}}
if($failures.Count){throw ($failures -join "`r`n")}

# Compile the exact x64 managed/native host that ships in the ZIP.
Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase,System.Xaml,System.Windows.Forms,System.Drawing,System.Web.Extensions
$csc=Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
if(-not(Test-Path $csc)){throw 'Framework64 csc.exe was not found.'}
$automation=[Management.Automation.PSObject].Assembly.Location
$refs=@([Uri].Assembly.Location,[Linq.Enumerable].Assembly.Location,[System.Xaml.XamlReader].Assembly.Location,[Xml.XmlDocument].Assembly.Location,[Windows.DependencyObject].Assembly.Location,[Windows.Media.Visual].Assembly.Location,[Windows.Window].Assembly.Location,[Windows.Forms.Form].Assembly.Location,[Drawing.Bitmap].Assembly.Location,[Web.Script.Serialization.JavaScriptSerializer].Assembly.Location,$automation)|Select-Object -Unique
$sources=@(
    'Native\HuymaierConsole.NativeApp.cs','Native\HuymaierConsole.Ps1.cs','Native\HuymaierConsole.ConsolePlatforms.cs','Native\HuymaierConsole.SystemOverlay.cs','Native\HuymaierConsole.GameInput.cs',
    'HuymaierNativeInput.cs','HuymaierNativeDisplay.cs','HuymaierNativeAudio.cs','HuymaierPerformance.cs','EmulatorPlatforms\Shared\Huymaier.P3T.cs'
)|ForEach-Object{Join-Path $stage $_}
foreach($s in $sources){if(-not(Test-Path $s)){throw "Native source missing: $s"}}
$exe=Join-Path $stage 'HuymaierConsole.exe'
$args=@('/noconfig','/nologo','/target:winexe','/platform:x64','/optimize+',('/out:'+$exe),('/win32icon:'+(Join-Path $stage 'HuymaierConsole.ico')))
foreach($r in $refs){$args+=('/reference:'+$r)};$args+=$sources
& $csc @args
if($LASTEXITCODE -ne 0 -or -not(Test-Path $exe)){throw 'x64 HuymaierConsole.exe compilation failed.'}

# Architecture/dependency gates.
$dumpbin=(Get-ChildItem (Join-Path $vs 'VC\Tools\MSVC') -Recurse -Filter dumpbin.exe -File|Where-Object{$_.FullName -match '\\Hostx64\\x64\\dumpbin\.exe$'}|Sort-Object FullName -Descending|Select-Object -First 1).FullName
if(-not $dumpbin){throw 'dumpbin.exe x64 was not found.'}
$headers=(& $dumpbin /nologo /headers $exe) -join "`n";if($headers -notmatch '(?i)machine \(x64\)|8664 machine'){throw 'HuymaierConsole.exe is not x64.'}
$deps=(& $dumpbin /nologo /dependents $bridgeOut) -join "`n";if($deps -match '(?i)VCRUNTIME|MSVCP|CONCRT'){throw "GameInput bridge unexpectedly depends on dynamic MSVC runtime:`n$deps"}

# Cross-file version invariants.
$manifest=Get-Content -Raw (Join-Path $stage 'manifest.json') -Encoding UTF8|ConvertFrom-Json
if([string]$manifest.version -ne $version){throw "manifest.json version $($manifest.version) does not match candidate $version"}
$core=Get-Content -Raw (Join-Path $stage 'HuymaierConsole.ps1') -Encoding UTF8
if($core -notmatch [regex]::Escape("`$script:AppVersion = '$version'")){throw 'HuymaierConsole.ps1 version does not match candidate.'}
$appx=Get-Content -Raw (Join-Path $stage 'FSEPackage\AppxManifest.xml') -Encoding UTF8
if($appx -notmatch ('Version="'+[regex]::Escape($version)+'.0"')){throw 'FSE AppX version does not match candidate.'}
foreach($required in @('Install-HuymaierConsole.ps1','HuymaierSelfUpdater.ps1','HuymaierConsoleUpdateWorker.ps1','HuymaierGameInputBridge.dll','HuymaierConsole.exe','Restore-HuymaierWindowsSettings.ps1')){if(-not(Test-Path (Join-Path $stage $required))){throw "Required production payload missing: $required"}}
foreach($dead in @('HuymaierGuideInput.cs','HuymaierGuideBridge.dll','HuymaierConsoleUpdate.ps1','HuymaierConsoleApplyUpdate.ps1')){if(Test-Path (Join-Path $stage $dead)){throw "Retired payload survived packaging: $dead"}}

# Closed internal checksum manifest. No payload exists outside this list except
# the two checksum files themselves.
$rows=New-Object Collections.Generic.List[string]
foreach($f in @(Get-ChildItem $stage -File -Recurse|Where-Object{$_.Name -notin @('checksums.sha256','SHA256SUMS.txt')}|Sort-Object FullName)){
    $rel=$f.FullName.Substring($stage.Length).TrimStart('\').Replace('\','/')
    $hash=(Get-FileHash $f.FullName -Algorithm SHA256).Hash.ToLowerInvariant();[void]$rows.Add("$hash  $rel")
}
$text=($rows -join "`n")+"`n";[IO.File]::WriteAllText((Join-Path $stage 'checksums.sha256'),$text,(New-Object Text.UTF8Encoding($false)));[IO.File]::WriteAllText((Join-Path $stage 'SHA256SUMS.txt'),$text,(New-Object Text.UTF8Encoding($false)))
if((Get-Content -Raw (Join-Path $stage 'checksums.sha256')) -ne (Get-Content -Raw (Join-Path $stage 'SHA256SUMS.txt'))){throw 'Internal checksum manifests diverged.'}

# Isolated installer tests. Pretend GameInput redist is already current to avoid
# elevation in CI; runtime/redist acquisition was validated above.
$fakeLocal=Join-Path $temp 'hc-localappdata';Remove-Item $fakeLocal -Recurse -Force -ErrorAction SilentlyContinue;New-Item -ItemType Directory -Force -Path (Join-Path $fakeLocal 'Huymaier Console')|Out-Null
Set-Content (Join-Path $fakeLocal 'Huymaier Console\gameinput-redist.version') '3.5.262' -Encoding ASCII
$oldLocal=$env:LOCALAPPDATA;$env:LOCALAPPDATA=$fakeLocal
try{
    & powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File (Join-Path $stage 'Install-HuymaierConsole.ps1') -SilentUpdate
    if($LASTEXITCODE -ne 0){throw "Clean installer test failed: $LASTEXITCODE"}
    $installed=Join-Path $fakeLocal 'Huymaier Console\HuymaierConsole.exe'
    if((Get-FileHash $installed -Algorithm SHA256).Hash -ne (Get-FileHash $exe -Algorithm SHA256).Hash){throw 'Installed executable differs from CI-built executable.'}
    # Repair install over identical payload must also succeed (covers the icon-lock class by avoiding replacement of identical files).
    & powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File (Join-Path $stage 'Install-HuymaierConsole.ps1') -SilentUpdate
    if($LASTEXITCODE -ne 0){throw "Repair installer test failed: $LASTEXITCODE"}
    # Tampered payload must fail before mutation.
    $tamper=Join-Path $temp 'hc-tamper';Copy-Item $stage $tamper -Recurse -Force;Add-Content (Join-Path $tamper 'manifest.json') 'tamper'
    & powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File (Join-Path $tamper 'Install-HuymaierConsole.ps1') -SilentUpdate
    if($LASTEXITCODE -eq 0){throw 'Tampered package was incorrectly accepted.'}
    # Extra unchecksummed payload must fail closed.
    $extra=Join-Path $temp 'hc-extra';Copy-Item $stage $extra -Recurse -Force;Set-Content (Join-Path $extra 'unexpected.bin') 'unexpected' -Encoding ASCII
    & powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File (Join-Path $extra 'Install-HuymaierConsole.ps1') -SilentUpdate
    if($LASTEXITCODE -eq 0){throw 'Unchecksummed extra payload was incorrectly accepted.'}
}finally{$env:LOCALAPPDATA=$oldLocal}

# Final release-shaped asset and provenance record.
$zip=Join-Path $out $assetName
Compress-Archive -LiteralPath $stage -DestinationPath $zip -CompressionLevel Optimal -Force
$zipHash=(Get-FileHash $zip -Algorithm SHA256).Hash.ToLowerInvariant()
Set-Content ($zip+'.sha256') ($zipHash+'  '+$assetName) -Encoding ASCII
$validation=[ordered]@{version=$version;asset=$assetName;sha256=$zipHash;sourceCommit=$env:GITHUB_SHA;runId=$env:GITHUB_RUN_ID;runAttempt=$env:GITHUB_RUN_ATTEMPT;architecture='x64';gameInput='3.5.262';packageFiles=$rows.Count;validatedAtUtc=[DateTime]::UtcNow.ToString('o')}
$validation|ConvertTo-Json|Set-Content (Join-Path $out 'candidate-validation.json') -Encoding UTF8
"HC_CANDIDATE_OUTPUT=$out"|Out-File $env:GITHUB_ENV -Encoding utf8 -Append
Write-Host "Validated release candidate SHA-256: $zipHash"
