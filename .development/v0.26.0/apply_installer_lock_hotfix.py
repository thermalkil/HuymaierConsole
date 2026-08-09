from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
installer_path = ROOT / 'Install-HuymaierConsole.ps1'
updater_path = ROOT / 'HuymaierSelfUpdater.ps1'

installer = installer_path.read_text(encoding='utf-8-sig')
updater = updater_path.read_text(encoding='utf-8-sig')

installer = installer.replace("$script:InstallVersion = '0.26.0'", "$script:InstallVersion = '0.26.1'", 1)

anchor = "New-Item -ItemType Directory -Force -Path $destination | Out-Null\n\n$files = @("
if anchor not in installer:
    raise RuntimeError('installer destination anchor not found')

helpers = r'''New-Item -ItemType Directory -Force -Path $destination | Out-Null

function Test-HcInstallFilesIdentical {
    param([string]$SourcePath,[string]$DestinationPath)
    if(-not (Test-Path -LiteralPath $SourcePath -PathType Leaf) -or -not (Test-Path -LiteralPath $DestinationPath -PathType Leaf)){return $false}
    try{
        $srcInfo=Get-Item -LiteralPath $SourcePath -ErrorAction Stop
        $dstInfo=Get-Item -LiteralPath $DestinationPath -ErrorAction Stop
        if($srcInfo.Length -ne $dstInfo.Length){return $false}
        $srcHash=(Get-FileHash -LiteralPath $SourcePath -Algorithm SHA256 -ErrorAction Stop).Hash
        $dstHash=(Get-FileHash -LiteralPath $DestinationPath -Algorithm SHA256 -ErrorAction Stop).Hash
        return [string]::Equals($srcHash,$dstHash,[StringComparison]::OrdinalIgnoreCase)
    }catch{return $false}
}

function Copy-HcInstallFile {
    param([Parameter(Mandatory=$true)][string]$SourcePath,[Parameter(Mandatory=$true)][string]$DestinationPath)
    if(Test-HcInstallFilesIdentical $SourcePath $DestinationPath){
        Write-InstallerRecord "Unchanged payload already installed: $([IO.Path]::GetFileName($DestinationPath))"
        return
    }
    $parent=Split-Path -Parent $DestinationPath
    if($parent){New-Item -ItemType Directory -Force -Path $parent|Out-Null}
    $lastError=$null
    for($attempt=1;$attempt -le 30;$attempt++){
        try{
            Copy-Item -LiteralPath $SourcePath -Destination $DestinationPath -Force -ErrorAction Stop
            return
        }catch{
            $lastError=$_.Exception
            if($attempt -lt 30){Start-Sleep -Milliseconds 250}
        }
    }
    throw "Could not replace installed file after 7.5 seconds: $DestinationPath. $($lastError.Message)"
}

function Copy-HcInstallTree {
    param([Parameter(Mandatory=$true)][string]$SourceRoot,[Parameter(Mandatory=$true)][string]$DestinationRoot)
    if(-not (Test-Path -LiteralPath $SourceRoot -PathType Container)){return}
    New-Item -ItemType Directory -Force -Path $DestinationRoot|Out-Null
    foreach($dir in @(Get-ChildItem -LiteralPath $SourceRoot -Directory -Recurse -ErrorAction Stop)){
        $relative=$dir.FullName.Substring($SourceRoot.Length).TrimStart('\\')
        New-Item -ItemType Directory -Force -Path (Join-Path $DestinationRoot $relative)|Out-Null
    }
    foreach($file in @(Get-ChildItem -LiteralPath $SourceRoot -File -Recurse -ErrorAction Stop)){
        $relative=$file.FullName.Substring($SourceRoot.Length).TrimStart('\\')
        Copy-HcInstallFile -SourcePath $file.FullName -DestinationPath (Join-Path $DestinationRoot $relative)
    }
}

# Stop every native Console host before replacing *any* payload file. The old
# installer performed this step after copying scripts/assets, allowing a single
# locked file to leave a mixed-version installation.
$runningConsole = @(Get-Process -Name 'HuymaierConsole' -ErrorAction SilentlyContinue)
if($runningConsole.Count -gt 0){
    Write-InstallerRecord ('Closing {0} running Huymaier Console process(es) before payload replacement.' -f $runningConsole.Count)
    $runningConsole | Stop-Process -Force -ErrorAction SilentlyContinue
    $deadline = [DateTime]::UtcNow.AddSeconds(10)
    do {
        Start-Sleep -Milliseconds 150
        $stillRunning = @(Get-Process -Name 'HuymaierConsole' -ErrorAction SilentlyContinue)
    } while($stillRunning.Count -gt 0 -and [DateTime]::UtcNow -lt $deadline)
    if($stillRunning.Count -gt 0){ throw 'HuymaierConsole.exe is still running and installed files cannot be replaced safely.' }
}

$files = @('''
installer = installer.replace(anchor, helpers, 1)

old_file_copy = """foreach ($file in $files) {
    $src = Join-Path $source $file
    if (Test-Path $src) { Copy-Item $src (Join-Path $destination $file) -Force }
}
"""
new_file_copy = """foreach ($file in $files) {
    $src = Join-Path $source $file
    if (Test-Path -LiteralPath $src -PathType Leaf) { Copy-HcInstallFile -SourcePath $src -DestinationPath (Join-Path $destination $file) }
}
"""
if installer.count(old_file_copy) != 1:
    raise RuntimeError(f'top-level copy block match count {installer.count(old_file_copy)}')
installer = installer.replace(old_file_copy, new_file_copy, 1)

replacements = {
"""if(Test-Path $fseSource){
    New-Item -ItemType Directory -Force -Path $fseDestination|Out-Null
    Copy-Item (Join-Path $fseSource '*') $fseDestination -Recurse -Force
}""": """if(Test-Path $fseSource){Copy-HcInstallTree -SourceRoot $fseSource -DestinationRoot $fseDestination}""",
"""if (Test-Path $assetSource) {
    New-Item -ItemType Directory -Force -Path $assetDestination | Out-Null
    Copy-Item (Join-Path $assetSource '*') $assetDestination -Recurse -Force
}""": """if (Test-Path $assetSource) {Copy-HcInstallTree -SourceRoot $assetSource -DestinationRoot $assetDestination}""",
"""if(Test-Path $emulatorSource){
    New-Item -ItemType Directory -Force -Path $emulatorDestination|Out-Null
    Copy-Item (Join-Path $emulatorSource '*') $emulatorDestination -Recurse -Force
}""": """if(Test-Path $emulatorSource){Copy-HcInstallTree -SourceRoot $emulatorSource -DestinationRoot $emulatorDestination}""",
"""if(Test-Path $toolsSource){
    New-Item -ItemType Directory -Force -Path $toolsDestination|Out-Null
    Copy-Item (Join-Path $toolsSource '*') $toolsDestination -Recurse -Force
}""": """if(Test-Path $toolsSource){Copy-HcInstallTree -SourceRoot $toolsSource -DestinationRoot $toolsDestination}""",
"""if(Test-Path $nativeSourceRoot){
    New-Item -ItemType Directory -Force -Path $nativeDestinationRoot|Out-Null
    Copy-Item (Join-Path $nativeSourceRoot '*') $nativeDestinationRoot -Recurse -Force
}""": """if(Test-Path $nativeSourceRoot){Copy-HcInstallTree -SourceRoot $nativeSourceRoot -DestinationRoot $nativeDestinationRoot}""",
}
for old,new in replacements.items():
    if installer.count(old) != 1:
        raise RuntimeError(f'tree copy block match count {installer.count(old)} for {old[:40]!r}')
    installer = installer.replace(old,new,1)

old_late_stop = r'''# Stop a running native host before replacing HuymaierConsole.exe. Earlier
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

'''
if installer.count(old_late_stop) != 1:
    raise RuntimeError(f'late process-stop block match count {installer.count(old_late_stop)}')
installer = installer.replace(old_late_stop, '', 1)

# Correct stale manual-install completion text while touching the installer.
installer = installer.replace('Huymaier Console v0.25.6 stabilization build was installed for this Windows account.', 'Huymaier Console v0.26.1 was installed for this Windows account.', 1)

# Strengthen self-updater rollback: recursively snapshot installed program files
# except transient update/log folders, and restore them recursively on failure.
old_backup = r'''    # Lightweight rollback snapshot: preserve installed program files, not caches/assets/user data.
    if(Test-Path -LiteralPath $InstallRoot){
        foreach($f in @(Get-ChildItem -LiteralPath $InstallRoot -File -ErrorAction SilentlyContinue)){Copy-Item -LiteralPath $f.FullName -Destination (Join-Path $backup $f.Name) -Force -ErrorAction SilentlyContinue}
    }
'''
new_backup = r'''    # Recursive rollback snapshot. Exclude only transient Logs/Updates so a
    # failed install cannot leave old native binaries mixed with new scripts.
    $backupInstall=Join-Path $backup 'install'
    New-Item -ItemType Directory -Force -Path $backupInstall|Out-Null
    if(Test-Path -LiteralPath $InstallRoot){
        foreach($dir in @(Get-ChildItem -LiteralPath $InstallRoot -Directory -Recurse -ErrorAction SilentlyContinue)){
            $relative=$dir.FullName.Substring($InstallRoot.Length).TrimStart('\\')
            if($relative -match '^(?i)(Logs|Updates)(\\|$)'){continue}
            New-Item -ItemType Directory -Force -Path (Join-Path $backupInstall $relative)|Out-Null
        }
        foreach($f in @(Get-ChildItem -LiteralPath $InstallRoot -File -Recurse -ErrorAction SilentlyContinue)){
            $relative=$f.FullName.Substring($InstallRoot.Length).TrimStart('\\')
            if($relative -match '^(?i)(Logs|Updates)(\\|$)'){continue}
            $target=Join-Path $backupInstall $relative
            New-Item -ItemType Directory -Force -Path (Split-Path -Parent $target)|Out-Null
            Copy-Item -LiteralPath $f.FullName -Destination $target -Force -ErrorAction SilentlyContinue
        }
    }
'''
if updater.count(old_backup) != 1:
    raise RuntimeError(f'updater backup block match count {updater.count(old_backup)}')
updater = updater.replace(old_backup,new_backup,1)

old_restore = r'''        if(Test-Path -LiteralPath $backup){foreach($f in @(Get-ChildItem -LiteralPath $backup -File -ErrorAction SilentlyContinue)){Copy-Item -LiteralPath $f.FullName -Destination (Join-Path $InstallRoot $f.Name) -Force -ErrorAction SilentlyContinue}}
        $old=Join-Path $InstallRoot 'HuymaierConsole.exe';if(Test-Path -LiteralPath $old){Start-Process -FilePath $old -WorkingDirectory $InstallRoot|Out-Null}
'''
new_restore = r'''        $backupInstall=Join-Path $backup 'install'
        if(Test-Path -LiteralPath $backupInstall){
            foreach($dir in @(Get-ChildItem -LiteralPath $backupInstall -Directory -Recurse -ErrorAction SilentlyContinue)){
                $relative=$dir.FullName.Substring($backupInstall.Length).TrimStart('\\')
                New-Item -ItemType Directory -Force -Path (Join-Path $InstallRoot $relative)|Out-Null
            }
            foreach($f in @(Get-ChildItem -LiteralPath $backupInstall -File -Recurse -ErrorAction SilentlyContinue)){
                $relative=$f.FullName.Substring($backupInstall.Length).TrimStart('\\')
                $target=Join-Path $InstallRoot $relative
                New-Item -ItemType Directory -Force -Path (Split-Path -Parent $target)|Out-Null
                Copy-Item -LiteralPath $f.FullName -Destination $target -Force -ErrorAction SilentlyContinue
            }
        }
        $old=Join-Path $InstallRoot 'HuymaierConsole.exe';if(Test-Path -LiteralPath $old){Start-Process -FilePath $old -WorkingDirectory $InstallRoot|Out-Null}
'''
if updater.count(old_restore) != 1:
    raise RuntimeError(f'updater restore block match count {updater.count(old_restore)}')
updater = updater.replace(old_restore,new_restore,1)

installer_path.write_text(installer,encoding='utf-8')
updater_path.write_text(updater,encoding='utf-8')
print('Applied v0.26.1 locked-file installer and recursive rollback hotfix.')
