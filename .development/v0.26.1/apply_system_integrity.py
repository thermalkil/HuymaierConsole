from pathlib import Path
import re, json

ROOT=Path('.')

def read(path):
    return (ROOT/path).read_text(encoding='utf-8-sig')

def write(path,text,bom=False):
    p=ROOT/path
    p.parent.mkdir(parents=True,exist_ok=True)
    enc='utf-8-sig' if bom else 'utf-8'
    p.write_text(text,encoding=enc,newline='\n')

def replace_once(text,old,new,label):
    if old not in text:
        raise SystemExit(f'{label}: expected text not found')
    return text.replace(old,new,1)

# ---------------------------------------------------------------------------
# Bootstrap: refuse mixed/incomplete installs rather than launching degraded.
# ---------------------------------------------------------------------------
p=Path('HuymaierBootstrap.ps1'); t=read(p)
anchor="function Test-PowerShellFile {"
pre="""$script:ExpectedConsoleVersion = '0.26.1'\n$script:InstallIncompleteMarker = Join-Path $dataDir 'install-incomplete.json'\n\nfunction Assert-HuymaierInstallIntegrity {\n    if(Test-Path -LiteralPath $script:InstallIncompleteMarker -PathType Leaf){\n        throw \"Huymaier Console installation is marked incomplete. Rerun the v$script:ExpectedConsoleVersion installer to repair it before starting the Console.\"\n    }\n    $bridgeVariable=Get-Variable -Name HuymaierNativeBridge -ErrorAction SilentlyContinue\n    if($null -ne $bridgeVariable -and $null -ne $bridgeVariable.Value){\n        $nativeVersion=''\n        try{$nativeVersion=[string]$bridgeVariable.Value.Version}catch{}\n        if([string]::IsNullOrWhiteSpace($nativeVersion) -or -not [string]::Equals($nativeVersion,$script:ExpectedConsoleVersion,[StringComparison]::OrdinalIgnoreCase)){\n            throw \"Native/script version mismatch. Native=$nativeVersion Script=$script:ExpectedConsoleVersion. Rerun the installer; Huymaier Console will not start from a mixed-version installation.\"\n        }\n    }\n}\n\n"""
if 'Assert-HuymaierInstallIntegrity' not in t:
    t=replace_once(t,anchor,pre+anchor,'bootstrap integrity insertion')
t=replace_once(t,"try {\n    Test-PowerShellFile $corePath", "try {\n    Assert-HuymaierInstallIntegrity\n    Test-PowerShellFile $corePath",'bootstrap integrity call')
write(p,t,bom=True)

# ---------------------------------------------------------------------------
# Native host: exact version, singleton, incomplete-install fail-closed.
# ---------------------------------------------------------------------------
p=Path('Native/HuymaierConsole.NativeApp.cs'); t=read(p)
t=t.replace('public string Version { get { return "0.26.0"; } }','public string Version { get { return "0.26.1"; } }')
if 'private static Mutex SingleInstanceMutex;' not in t:
    t=replace_once(t,'    public static class Program\n    {\n','    public static class Program\n    {\n        private static Mutex SingleInstanceMutex;\n','native singleton field')
old='''            string baseDirectory = AppDomain.CurrentDomain.BaseDirectory;\n            AppDomain.CurrentDomain.UnhandledException += delegate(object sender, UnhandledExceptionEventArgs e)'''
new='''            string baseDirectory = AppDomain.CurrentDomain.BaseDirectory;\n            try\n            {\n                bool createdNew;\n                SingleInstanceMutex = new Mutex(true, "Local\\\\HuymaierConsole.Main", out createdNew);\n                if (!createdNew) return 0;\n            }\n            catch { }\n            string incompleteMarker = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),\n                "Huymaier Console", "install-incomplete.json");\n            if (File.Exists(incompleteMarker))\n            {\n                MessageBox.Show("Huymaier Console detected an incomplete installation.\\n\\nRerun the latest installer to repair it before starting the Console.",\n                    "Huymaier Console", MessageBoxButton.OK, MessageBoxImage.Warning);\n                return 4;\n            }\n            AppDomain.CurrentDomain.UnhandledException += delegate(object sender, UnhandledExceptionEventArgs e)'''
if 'install-incomplete.json' not in t:
    t=replace_once(t,old,new,'native fail closed')
write(p,t)

# ---------------------------------------------------------------------------
# FSE package: version follows app; never silently mutate HKLM developer mode.
# ---------------------------------------------------------------------------
p=Path('FSEPackage/AppxManifest.xml'); t=read(p)
t=re.sub(r'Version="[0-9.]+"','Version="0.26.1.0"',t,count=1)
write(p,t)

p=Path('Register-HuymaierFSEHome.ps1'); t=read(p)
t=re.sub(r"\n\s*\$developerKey='HKLM:\\\\SOFTWARE\\\\Microsoft\\\\Windows\\\\CurrentVersion\\\\AppModelUnlock'\n\s*New-Item -Path \$developerKey -Force\|Out-Null\n\s*Set-ItemProperty -Path \$developerKey -Name AllowDevelopmentWithoutDevLicense -Type DWord -Value 1\n", "\n    # Registration is per-user. Do not change machine-wide Developer Mode policy.\n    # If loose package registration is blocked, report it and let the user decide\n    # whether to enable Developer Mode in Windows Settings.\n", t, count=1)
write(p,t,bom=True)

# ---------------------------------------------------------------------------
# Restore helper + Game Bar: only suppress controller->Xbox Game Bar takeover.
# ---------------------------------------------------------------------------
restore=r'''param([switch]$Quiet)\nSet-StrictMode -Version 2.0\n$ErrorActionPreference='Stop'\n$root=Join-Path $env:LOCALAPPDATA 'Huymaier Console'\n$backupPath=Join-Path $root 'xbox-gamebar-backup.json'\n$runOnce='HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\RunOnce'\n$name='HuymaierConsoleRestoreGameBar'\ntry{\n    if(Test-Path -LiteralPath $backupPath -PathType Leaf){\n        $backup=Get-Content -Raw -LiteralPath $backupPath -Encoding UTF8|ConvertFrom-Json\n        $path=[string]$backup.Path;$valueName=[string]$backup.Name\n        $current=$null;$currentExists=$false\n        try{\n            $item=Get-ItemProperty -LiteralPath $path -Name $valueName -ErrorAction Stop\n            if($null -ne $item.PSObject.Properties[$valueName]){$currentExists=$true;$current=$item.$valueName}\n        }catch{}\n        # Restore only if Huymaier's forced value (0) is still present. If the\n        # user changed it while Huymaier was running, their newer choice wins.\n        if($currentExists -and [int]$current -eq 0){\n            if([bool]$backup.Exists){\n                if(-not(Test-Path -LiteralPath $path)){New-Item -Path $path -Force|Out-Null}\n                Set-ItemProperty -LiteralPath $path -Name $valueName -Type DWord -Value ([int]$backup.Value) -Force\n            }else{\n                Remove-ItemProperty -LiteralPath $path -Name $valueName -ErrorAction SilentlyContinue\n            }\n        }\n        Remove-Item -LiteralPath $backupPath -Force -ErrorAction SilentlyContinue\n    }\n    Remove-ItemProperty -LiteralPath $runOnce -Name $name -ErrorAction SilentlyContinue\n}catch{if(-not $Quiet){throw}}\n'''.replace('\\n','\n')
write(Path('Restore-HuymaierWindowsSettings.ps1'),restore,bom=True)

p=Path('HuymaierGameBar.ps1'); t=read(p)
if '$script:HcWindowsRestorePath' not in t:
    t=replace_once(t,"$script:HcGameBarBackupPath=Join-Path $script:DataDir 'xbox-gamebar-backup.json'", "$script:HcGameBarBackupPath=Join-Path $script:DataDir 'xbox-gamebar-backup.json'\n$script:HcWindowsRestorePath=Join-Path $script:BaseDir 'Restore-HuymaierWindowsSettings.ps1'",'gamebar restore path')
pattern=r"function Set-HcXboxGameBarSuppression \{.*?\n\}\n\nfunction Get-HcRawSystemGuidePressed"
replacement=r'''function Restore-HcXboxGameBarSuppression {\n    try{\n        if(Test-Path -LiteralPath $script:HcWindowsRestorePath -PathType Leaf){& $script:HcWindowsRestorePath -Quiet}\n    }catch{Write-Log "Xbox Game Bar controller-setting restore failed: $($_.Exception.Message)" 'WARN'}\n}\n\nfunction Set-HcXboxGameBarSuppression {\n    try{\n        # Recover a setting left suppressed by an abnormal prior termination.\n        Restore-HcXboxGameBarSuppression\n        $path='HKCU:\\Software\\Microsoft\\GameBar'\n        $name='UseNexusForGameBarEnabled'\n        $backup=Get-HcRegistryBackupValue $path $name\n        $backup|ConvertTo-Json -Depth 4|Set-Content -LiteralPath $script:HcGameBarBackupPath -Encoding UTF8\n        if(-not(Test-Path -LiteralPath $path)){New-Item -Path $path -Force|Out-Null}\n        Set-ItemProperty -LiteralPath $path -Name $name -Value 0 -Type DWord -Force\n        # Crash/reboot recovery: if normal shutdown never restores the setting,\n        # Windows runs the per-user restore helper at the next sign-in.\n        $runOnce='HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\RunOnce'\n        if(-not(Test-Path -LiteralPath $runOnce)){New-Item -Path $runOnce -Force|Out-Null}\n        $cmd='powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "'+$script:HcWindowsRestorePath+'" -Quiet'\n        Set-ItemProperty -LiteralPath $runOnce -Name 'HuymaierConsoleRestoreGameBar' -Value $cmd -Type String -Force\n        Write-Log 'Windows Xbox Game Bar controller-button capture was disabled while Huymaier Console is running.'\n    }catch{Write-Log "Xbox Game Bar controller suppression failed: $($_.Exception.Message)" 'WARN'}\n}\n\nfunction Get-HcRawSystemGuidePressed'''.replace('\\n','\n')
t2,n=re.subn(pattern,replacement,t,count=1,flags=re.S)
if n!=1: raise SystemExit('gamebar suppression block not found')
t=t2
# Any Huymaier-owned WPF window counts as internal; do not let external watcher consume Guide.
t=t.replace("if([bool]$script:Window.IsActive){\n                    $script:HcExternalGuideDown=$false\n                    return\n                }", "if(@([System.Windows.Application]::Current.Windows|Where-Object{[bool]$_.IsActive}).Count -gt 0){\n                    $script:HcExternalGuideDown=$false\n                    return\n                }")
if 'Restore-HcXboxGameBarSuppression' not in t.split('function Stop-HuymaierGameBar',1)[1]:
    t=t.replace("    try{if('HuymaierConsole.NativeApp.HuymaierGameBarHost' -as [type]){[HuymaierConsole.NativeApp.HuymaierGameBarHost]::Hide()}}catch{}\n}", "    try{if('HuymaierConsole.NativeApp.HuymaierGameBarHost' -as [type]){[HuymaierConsole.NativeApp.HuymaierGameBarHost]::Hide()}}catch{}\n    Restore-HcXboxGameBarSuppression\n}",1)
write(p,t,bom=True)

# ---------------------------------------------------------------------------
# Installer: validate closed package before mutation, install CI-built x64 exe,
# persistent incomplete marker, verify installed payload, no client compilation.
# ---------------------------------------------------------------------------
p=Path('Install-HuymaierConsole.ps1'); t=read(p)
verify=r'''\nfunction Get-HcChecksumMap {\n    param([string]$Root)\n    $a=Join-Path $Root 'checksums.sha256';$b=Join-Path $Root 'SHA256SUMS.txt'\n    if(-not(Test-Path -LiteralPath $a -PathType Leaf) -or -not(Test-Path -LiteralPath $b -PathType Leaf)){throw 'Package checksum manifests are missing.'}\n    $ta=Get-Content -Raw -LiteralPath $a -Encoding UTF8;$tb=Get-Content -Raw -LiteralPath $b -Encoding UTF8\n    if($ta -ne $tb){throw 'checksums.sha256 and SHA256SUMS.txt do not agree.'}\n    $map=@{}\n    foreach($line in @($ta -split "`r?`n")){\n        if([string]::IsNullOrWhiteSpace($line)){continue}\n        if($line -notmatch '^([0-9a-fA-F]{64})\\s{2}(.+)$'){throw "Invalid checksum row: $line"}\n        $rel=$Matches[2].Replace('/','\\')\n        if([IO.Path]::IsPathRooted($rel) -or $rel -match '(^|\\)\\.\\.(\\|$)'){throw "Unsafe checksum path: $rel"}\n        $map[$rel]=$Matches[1].ToLowerInvariant()\n    }\n    return $map\n}\nfunction Assert-HcPayloadRoot {\n    param([string]$Root,[string]$ExpectedVersion)\n    $manifest=Join-Path $Root 'manifest.json'\n    if(-not(Test-Path -LiteralPath $manifest -PathType Leaf)){throw 'manifest.json is missing.'}\n    $version=[string]((Get-Content -Raw -LiteralPath $manifest -Encoding UTF8|ConvertFrom-Json).version)\n    if(-not [string]::Equals($version,$ExpectedVersion,[StringComparison]::OrdinalIgnoreCase)){throw "Package version mismatch: expected $ExpectedVersion, found $version"}\n    $map=Get-HcChecksumMap $Root\n    foreach($rel in $map.Keys){\n        $file=Join-Path $Root $rel\n        if(-not(Test-Path -LiteralPath $file -PathType Leaf)){throw "Checksummed payload is missing: $rel"}\n        $actual=(Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash.ToLowerInvariant()\n        if($actual -ne $map[$rel]){throw "Payload checksum mismatch: $rel"}\n    }\n    $actualFiles=@(Get-ChildItem -LiteralPath $Root -File -Recurse|ForEach-Object{$_.FullName.Substring($Root.Length).TrimStart('\\')})\n    foreach($rel in $actualFiles){if($rel -notin @('checksums.sha256','SHA256SUMS.txt') -and -not $map.ContainsKey($rel)){throw "Unchecksummed package payload is not allowed: $rel"}}\n    $exe=Join-Path $Root 'HuymaierConsole.exe'\n    if(-not(Test-Path -LiteralPath $exe -PathType Leaf)){throw 'The CI-built HuymaierConsole.exe is missing.'}\n    $fs=[IO.File]::Open($exe,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::ReadWrite)\n    try{\n        $br=New-Object IO.BinaryReader($fs);$fs.Position=0x3c;$pe=$br.ReadInt32();$fs.Position=$pe+4;$machine=$br.ReadUInt16()\n        if($machine -ne 0x8664){throw ('HuymaierConsole.exe is not x64 (PE machine 0x{0:X4}).' -f $machine)}\n    }finally{$fs.Dispose()}\n    return $map\n}\n'''.replace('\\n','\n')
if 'function Assert-HcPayloadRoot' not in t:
    t=replace_once(t,"$source = Split-Path -Parent $MyInvocation.MyCommand.Path\n", "$source = Split-Path -Parent $MyInvocation.MyCommand.Path\n"+verify+"\n$script:PackageChecksums=Assert-HcPayloadRoot -Root $source -ExpectedVersion $script:InstallVersion\nWrite-InstallerRecord ('Closed package integrity validation passed for {0} payload files.' -f $script:PackageChecksums.Count)\n",'installer package verifier')
# Files installed directly include exact tested host + recovery helper.
if "    'HuymaierConsole.exe'," not in t:
    t=t.replace("    'HuymaierGameInputBridge.dll',", "    'HuymaierGameInputBridge.dll',\n    'HuymaierConsole.exe',\n    'Restore-HuymaierWindowsSettings.ps1',",1)
# Marker before first payload replacement, after native process shutdown.
marker="""\n$script:InstallIncompleteMarker=Join-Path $destination 'install-incomplete.json'\n[ordered]@{version=$script:InstallVersion;startedAtUtc=[DateTime]::UtcNow.ToString('o');source=$source}|ConvertTo-Json|Set-Content -LiteralPath $script:InstallIncompleteMarker -Encoding UTF8\nWrite-InstallerRecord 'Installation transaction marker created.'\n\n"""
needle="if($runningConsole.Count -gt 0){ throw 'HuymaierConsole.exe is still running and installed files cannot be replaced safely.' }\n}\n\n$files = @("
if 'Installation transaction marker created.' not in t:
    t=replace_once(t,needle,needle.replace('\n\n$files = @(','\n}'+marker+'$files = @(') if False else needle[:-len('\n$files = @(')]+marker+'$files = @(','installer marker')
# Remove local C# compilation block: package carries exact CI-tested x64 host.
start=t.find('# Build the normal-use Windows GUI executable.')
end=t.find('# v0.25.2 keeps the Console-side HES integration retired',start)
if start<0 or end<0: raise SystemExit('installer compile block bounds missing')
replacement="""# The install package carries the exact x64 HuymaierConsole.exe produced and\n# validated by Windows CI. Client PCs never compile a different executable.\n$nativeExe=Join-Path $destination 'HuymaierConsole.exe'\nif(-not(Test-Path -LiteralPath $nativeExe -PathType Leaf)){throw 'CI-built HuymaierConsole.exe was not installed.'}\nWrite-InstallerRecord \"Verified CI-built native application at $nativeExe\"\n\n"""
t=t[:start]+replacement+t[end:]
# Verify installed managed payload before commit marker removal.
commit="""\nforeach($rel in $script:PackageChecksums.Keys){\n    $installed=Join-Path $destination $rel\n    if(-not(Test-Path -LiteralPath $installed -PathType Leaf)){throw \"Installed payload is missing after transaction: $rel\"}\n    $actual=(Get-FileHash -LiteralPath $installed -Algorithm SHA256).Hash.ToLowerInvariant()\n    if($actual -ne $script:PackageChecksums[$rel]){throw \"Installed payload checksum mismatch after transaction: $rel\"}\n}\nRemove-Item -LiteralPath $script:InstallIncompleteMarker -Force -ErrorAction Stop\nWrite-InstallerRecord 'Installed payload verified; installation transaction committed.'\n\n"""
if 'installation transaction committed' not in t:
    t=replace_once(t,'Write-InstallerRecord "Installation completed successfully at $destination"',commit+'Write-InstallerRecord "Installation completed successfully at $destination"','installer commit verification')
write(p,t,bom=True)

# ---------------------------------------------------------------------------
# Self-updater: one mutex, sidecar + internal verification, managed-path rollback,
# bounded PS5.1-compatible wait, release gate before relaunch.
# ---------------------------------------------------------------------------
selfup=r'''param(\n    [Parameter(Mandatory=$true)][string]$PackagePath,\n    [Parameter(Mandatory=$true)][int]$ParentProcessId,\n    [string]$InstallRoot=(Join-Path $env:LOCALAPPDATA 'Huymaier Console')\n)\nSet-StrictMode -Version 2.0\n$ErrorActionPreference='Stop'\n$logRoot=Join-Path $env:LOCALAPPDATA 'Huymaier Console\\Logs';New-Item -ItemType Directory -Force -Path $logRoot|Out-Null\n$log=Join-Path $logRoot ('self-update-'+(Get-Date -Format 'yyyyMMdd-HHmmss')+'.log')\nfunction Log([string]$m){try{Add-Content -LiteralPath $log -Value ((Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff')+' '+$m) -Encoding UTF8}catch{}}\nfunction Read-Checksums([string]$Root){\n    $path=Join-Path $Root 'checksums.sha256';if(-not(Test-Path -LiteralPath $path)){throw 'checksums.sha256 is missing.'}\n    $map=@{};foreach($line in @((Get-Content -Raw -LiteralPath $path -Encoding UTF8) -split "`r?`n")){\n        if([string]::IsNullOrWhiteSpace($line)){continue};if($line -notmatch '^([0-9a-fA-F]{64})\\s{2}(.+)$'){throw "Invalid checksum row: $line"}\n        $rel=$Matches[2].Replace('/','\\');if([IO.Path]::IsPathRooted($rel) -or $rel -match '(^|\\)\\.\\.(\\|$)'){throw "Unsafe package path: $rel"};$map[$rel]=$Matches[1].ToLowerInvariant()\n    };return $map\n}\nfunction Assert-Payload([string]$Root){\n    $a=Join-Path $Root 'checksums.sha256';$b=Join-Path $Root 'SHA256SUMS.txt';if(-not(Test-Path $b)){throw 'SHA256SUMS.txt is missing.'}\n    if((Get-Content -Raw $a -Encoding UTF8) -ne (Get-Content -Raw $b -Encoding UTF8)){throw 'Internal checksum manifests disagree.'}\n    $map=Read-Checksums $Root;foreach($rel in $map.Keys){$f=Join-Path $Root $rel;if(-not(Test-Path $f -PathType Leaf)){throw "Missing payload: $rel"};if((Get-FileHash $f -Algorithm SHA256).Hash.ToLowerInvariant() -ne $map[$rel]){throw "Checksum mismatch: $rel"}}\n    return $map\n}\nfunction Wait-ForPid([int]$Id,[int]$Seconds){$deadline=[DateTime]::UtcNow.AddSeconds($Seconds);do{try{$p=Get-Process -Id $Id -ErrorAction Stop}catch{return};Start-Sleep -Milliseconds 200}while([DateTime]::UtcNow -lt $deadline);throw "Timed out waiting for PID $Id to exit."}\n$temp=Join-Path $env:TEMP ('HuymaierConsoleUpdate-'+[guid]::NewGuid().ToString('N'));$backup=Join-Path $env:TEMP ('HuymaierConsoleBackup-'+[guid]::NewGuid().ToString('N'))\n$mutex=$null;$owns=$false;$relaunch='';$success=$false\ntry{\n    $created=$false;$mutex=New-Object Threading.Mutex($true,'Local\\HuymaierConsole.Updater',[ref]$created);$owns=$created;if(-not $owns){throw 'Another Huymaier Console update is already running.'}\n    Log "Updater waiting for PID $ParentProcessId";Wait-ForPid $ParentProcessId 90\n    if(-not(Test-Path -LiteralPath $PackagePath -PathType Leaf)){throw "Downloaded update package is missing: $PackagePath"}\n    $sidecar=$PackagePath+'.sha256';if(-not(Test-Path -LiteralPath $sidecar -PathType Leaf)){throw 'Release SHA-256 sidecar is missing.'}\n    $line=(Get-Content -LiteralPath $sidecar -Encoding ASCII|Select-Object -First 1);if($line -notmatch '^([0-9a-fA-F]{64})'){throw 'Release SHA-256 sidecar is invalid.'}\n    $expected=$Matches[1].ToLowerInvariant();$actual=(Get-FileHash -LiteralPath $PackagePath -Algorithm SHA256).Hash.ToLowerInvariant();if($actual -ne $expected){throw 'Downloaded ZIP SHA-256 does not match the published release sidecar.'}\n    New-Item -ItemType Directory -Force -Path $temp,$backup|Out-Null;Expand-Archive -LiteralPath $PackagePath -DestinationPath $temp -Force\n    $installer=Get-ChildItem -LiteralPath $temp -Recurse -File -Filter 'Install-HuymaierConsole.ps1'|Select-Object -First 1;if($null -eq $installer){throw 'Release does not contain Install-HuymaierConsole.ps1.'}\n    $root=$installer.Directory.FullName;$newMap=Assert-Payload $root\n    $oldMap=@{};if(Test-Path -LiteralPath (Join-Path $InstallRoot 'checksums.sha256')){try{$oldMap=Read-Checksums $InstallRoot}catch{}}\n    foreach($rel in $oldMap.Keys){$src=Join-Path $InstallRoot $rel;if(Test-Path -LiteralPath $src -PathType Leaf){$dst=Join-Path $backup $rel;New-Item -ItemType Directory -Force -Path (Split-Path -Parent $dst)|Out-Null;Copy-Item -LiteralPath $src -Destination $dst -Force}}\n    foreach($name in @('checksums.sha256','SHA256SUMS.txt')){$src=Join-Path $InstallRoot $name;if(Test-Path $src){Copy-Item $src (Join-Path $backup $name) -Force}}\n    Log "Running verified installer $($installer.FullName)"\n    $proc=Start-Process -FilePath "$env:SystemRoot\\System32\\WindowsPowerShell\\v1.0\\powershell.exe" -ArgumentList @('-NoLogo','-NoProfile','-ExecutionPolicy','Bypass','-File',$installer.FullName,'-SilentUpdate') -Wait -PassThru -WindowStyle Hidden\n    if($proc.ExitCode -ne 0){throw "Installer exited with code $($proc.ExitCode)."}\n    $exe=Join-Path $InstallRoot 'HuymaierConsole.exe';if(-not(Test-Path $exe)){throw 'Updated HuymaierConsole.exe was not created.'};$relaunch=$exe;$success=$true;Log 'Update transaction completed successfully.'\n}catch{\n    Log ('ERROR '+$_.Exception.Message)\n    try{\n        Get-Process -Name HuymaierConsole -ErrorAction SilentlyContinue|Stop-Process -Force -ErrorAction SilentlyContinue\n        if(Test-Path -LiteralPath $temp){$installer=Get-ChildItem -LiteralPath $temp -Recurse -File -Filter 'Install-HuymaierConsole.ps1'|Select-Object -First 1;if($installer){$newMap=Read-Checksums $installer.Directory.FullName;foreach($rel in $newMap.Keys){Remove-Item -LiteralPath (Join-Path $InstallRoot $rel) -Force -ErrorAction SilentlyContinue}}}\n        if(Test-Path -LiteralPath $backup){foreach($f in @(Get-ChildItem -LiteralPath $backup -File -Recurse -ErrorAction SilentlyContinue)){$rel=$f.FullName.Substring($backup.Length).TrimStart('\\');$dst=Join-Path $InstallRoot $rel;New-Item -ItemType Directory -Force -Path (Split-Path -Parent $dst)|Out-Null;Copy-Item $f.FullName $dst -Force}}\n        Remove-Item -LiteralPath (Join-Path $InstallRoot 'install-incomplete.json') -Force -ErrorAction SilentlyContinue\n        $old=Join-Path $InstallRoot 'HuymaierConsole.exe';if(Test-Path $old){$relaunch=$old}\n    }catch{Log ('ROLLBACK ERROR '+$_.Exception.Message)}\n}finally{\n    Remove-Item -LiteralPath $temp,$backup -Recurse -Force -ErrorAction SilentlyContinue\n    if($owns -and $null -ne $mutex){try{$mutex.ReleaseMutex()}catch{}};if($null -ne $mutex){$mutex.Dispose()}\n}\nif($relaunch){Start-Sleep -Milliseconds 250;Start-Process -FilePath $relaunch -WorkingDirectory $InstallRoot|Out-Null}\nif(-not $success){exit 1}\n'''.replace('\\n','\n')
write(Path('HuymaierSelfUpdater.ps1'),selfup,bom=True)

# ---------------------------------------------------------------------------
# Update worker: require and persist published ZIP sidecar; never call a local
# hash alone "verified".
# ---------------------------------------------------------------------------
p=Path('HuymaierConsoleUpdateWorker.ps1'); t=read(p)
t=t.replace("[string]$CurrentVersion='0.26.0'","[string]$CurrentVersion='0.26.1'")
t=t.replace("UserAgent.ParseAdd('HuymaierConsole/0.26.0')","UserAgent.ParseAdd('HuymaierConsole/0.26.1')")
if '$sidecarAsset=' not in t:
    t=t.replace("    $asset=Select-PackageAsset $release\n", "    $asset=Select-PackageAsset $release\n    $sidecarAsset=$null\n    if($null -ne $asset){$sidecarName=[string]$asset.name+'.sha256';$sidecarAsset=@($release.assets|Where-Object{[string]::Equals([string]$_.name,$sidecarName,[StringComparison]::OrdinalIgnoreCase)}|Select-Object -First 1)[0]}\n")
old="""    $hash=(Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash.ToLowerInvariant();$size=(Get-Item -LiteralPath $target).Length\n    Write-State 'Downloaded' \"Huymaier Console $latestVersionText is downloaded and ready to install.\" $false $latestVersionText $true ([string]$asset.name) ([string]$asset.browser_download_url) ([string]$asset.url) ([long]$asset.size) ([string]$release.html_url) ([string]$release.body) ([string]$release.published_at) $size $size 100 $target $hash\n"""
new="""    $hash=(Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash.ToLowerInvariant();$size=(Get-Item -LiteralPath $target).Length\n    if($null -eq $sidecarAsset){throw \"Release asset $([string]$asset.name) has no matching .sha256 sidecar.\"}\n    $sidecarTarget=$target+'.sha256'\n    $sidecarHeaders=Get-Headers $token 'application/octet-stream'\n    $sidecarUri=if($token -and [string]$sidecarAsset.url){[string]$sidecarAsset.url}else{[string]$sidecarAsset.browser_download_url}\n    Invoke-WebRequest -UseBasicParsing -Uri $sidecarUri -Headers $sidecarHeaders -OutFile $sidecarTarget -TimeoutSec 30\n    $sidecarLine=Get-Content -LiteralPath $sidecarTarget -Encoding ASCII|Select-Object -First 1\n    if($sidecarLine -notmatch '^([0-9a-fA-F]{64})'){throw 'Release SHA-256 sidecar is invalid.'}\n    $published=$Matches[1].ToLowerInvariant();if($published -ne $hash){throw 'Downloaded ZIP does not match the SHA-256 published with the GitHub Release.'}\n    Write-State 'Downloaded' \"Huymaier Console $latestVersionText is downloaded, release-verified, and ready to install.\" $false $latestVersionText $true ([string]$asset.name) ([string]$asset.browser_download_url) ([string]$asset.url) ([long]$asset.size) ([string]$release.html_url) ([string]$release.body) ([string]$release.published_at) $size $size 100 $target $published\n"""
if old not in t: raise SystemExit('update worker download tail not found')
t=t.replace(old,new,1)
write(p,t,bom=True)

# ---------------------------------------------------------------------------
# Uninstall restores per-user Windows setting first.
# ---------------------------------------------------------------------------
p=Path('Uninstall-HuymaierConsole.cmd'); t=read(p)
old="if(Test-Path $d){Remove-Item $d -Recurse -Force};"
new="if(Test-Path (Join-Path $d 'Restore-HuymaierWindowsSettings.ps1')){try{& (Join-Path $d 'Restore-HuymaierWindowsSettings.ps1') -Quiet}catch{}}; if(Test-Path $d){Remove-Item $d -Recurse -Force};"
if old in t:t=t.replace(old,new,1)
write(p,t)

# ---------------------------------------------------------------------------
# Remove stale parallel implementations. Active paths are ShellRedesign +
# HuymaierConsoleUpdateWorker/HuymaierSelfUpdater and Native GameInput bridge.
# ---------------------------------------------------------------------------
for dead in [Path('HuymaierGuideInput.cs'),Path('Native/GuideBridge/HuymaierGuideBridge.cpp'),Path('HuymaierConsoleUpdate.ps1'),Path('HuymaierConsoleApplyUpdate.ps1')]:
    if dead.exists(): dead.unlink()

# Manifest describes the new integrity architecture.
p=Path('manifest.json'); data=json.loads(read(p));data['version']='0.26.1';data['baseVersion']='0.26.0';data['build']='system-integrity-transactional-installer-hotfix';data['builtFrom']='HC260.zip';features=list(data.get('features',[]))
for f in [
    'installs the exact x64 HuymaierConsole.exe validated by Windows CI instead of recompiling on client PCs',
    'fails closed on incomplete or mixed native/script installations',
    'requires closed internal SHA-256 manifests and rejects unchecksummed package payload',
    'verifies the GitHub Release SHA-256 sidecar before self-update installation',
    'uses managed-path rollback so failed updates remove newly introduced files before restoring the prior payload',
    'keeps Xbox Game Bar suppression limited to controller-button takeover and restores the user setting on exit, crash recovery, next sign-in, and uninstall',
    'removes obsolete parallel updater and Guide bridge implementations',
    'keeps FSE Home registration per-user without silently changing machine-wide Developer Mode policy'
]:
    if f not in features:features.append(f)
data['features']=features;data['description']='v0.26.1 system-integrity hotfix: exact-artifact packaging, transactional/fail-closed installation, release checksum verification, reversible Windows setting ownership, and removal of stale parallel runtime paths.'
write(p,json.dumps(data,indent=2)+'\n')

print('v0.26.1 system integrity transformer completed')
