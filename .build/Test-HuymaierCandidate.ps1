param(
    [Parameter(Mandatory=$true)][string]$StageRoot,
    [Parameter(Mandatory=$true)][string]$ValidationPath
)
Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'

function Invoke-Installer {
    param([string]$Root,[string]$FakeLocal)
    $installer=Join-Path $Root 'Install-HuymaierConsole.ps1'
    $old=$env:LOCALAPPDATA
    $stdout=Join-Path $env:RUNNER_TEMP ('hc-installer-'+[guid]::NewGuid().ToString('N')+'.stdout.log')
    $stderr=Join-Path $env:RUNNER_TEMP ('hc-installer-'+[guid]::NewGuid().ToString('N')+'.stderr.log')
    try{
        $env:LOCALAPPDATA=$FakeLocal
        # Match production self-update invocation. Do not add -NonInteractive:
        # real self-updates are hidden but still run under the user's normal
        # Windows PowerShell culture/UI environment.
        $proc=Start-Process -FilePath "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -ArgumentList @('-NoLogo','-NoProfile','-ExecutionPolicy','Bypass','-File',$installer,'-SilentUpdate') -Wait -PassThru -WindowStyle Hidden -RedirectStandardOutput $stdout -RedirectStandardError $stderr
        $exit=[int]$proc.ExitCode
        if($exit -ne 0){
            Write-Host "--- installer child stdout (exit $exit) ---"
            if(Test-Path -LiteralPath $stdout){Get-Content -LiteralPath $stdout -ErrorAction SilentlyContinue|ForEach-Object{Write-Host $_}}
            Write-Host '--- installer child stderr ---'
            if(Test-Path -LiteralPath $stderr){Get-Content -LiteralPath $stderr -ErrorAction SilentlyContinue|ForEach-Object{Write-Host $_}}
            $logs=Join-Path $FakeLocal 'Huymaier Console\Logs'
            $latest=@(Get-ChildItem -LiteralPath $logs -Filter 'install-v*.log' -File -ErrorAction SilentlyContinue|Sort-Object LastWriteTimeUtc -Descending|Select-Object -First 1)
            if($latest.Count -gt 0){
                Write-Host "--- installer transaction log: $($latest[0].FullName) ---"
                Get-Content -LiteralPath $latest[0].FullName -ErrorAction SilentlyContinue|ForEach-Object{Write-Host $_}
            }
        }
        return $exit
    }finally{
        $env:LOCALAPPDATA=$old
        Remove-Item -LiteralPath $stdout,$stderr -Force -ErrorAction SilentlyContinue
    }
}

$fakeLocal=Join-Path $env:RUNNER_TEMP ('hc-failure-tests-'+[guid]::NewGuid().ToString('N'))
$install=Join-Path $fakeLocal 'Huymaier Console'
New-Item -ItemType Directory -Force -Path $install|Out-Null
# Avoid an elevation prompt in CI. Candidate construction separately validates
# that the official GameInput redist exists in the closed payload.
Set-Content -LiteralPath (Join-Path $install 'gameinput-redist.version') -Value '3.5.262' -Encoding ASCII

try{
    $exit=Invoke-Installer -Root $StageRoot -FakeLocal $fakeLocal
    if($exit -ne 0){throw "Failure-test clean install returned $exit."}

    $packageIcon=Join-Path $StageRoot 'HuymaierConsole.ico'
    $installedIcon=Join-Path $install 'HuymaierConsole.ico'
    $marker=Join-Path $install 'install-incomplete.json'
    if(-not(Test-Path -LiteralPath $installedIcon)){throw 'Installed icon is missing after clean install.'}

    # Non-package user data must survive every repair/update transaction.
    $config=Join-Path $install 'config.json'
    $sentinel=Join-Path $install 'user-integrity-sentinel.dat'
    Set-Content -LiteralPath $config -Value '{"auditSentinel":"preserve-me"}' -Encoding UTF8
    Set-Content -LiteralPath $sentinel -Value 'preserve-me' -Encoding ASCII

    # Reproduce the wife's failure class exactly: an unchanged icon is held open
    # with write/delete sharing denied. The installer must hash it, recognize it
    # as identical, and never attempt replacement.
    $lock=[IO.File]::Open($installedIcon,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::Read)
    try{
        $exit=Invoke-Installer -Root $StageRoot -FakeLocal $fakeLocal
        if($exit -ne 0){throw "Identical locked-file repair returned $exit."}
    }finally{$lock.Dispose()}
    if(Test-Path -LiteralPath $marker){throw 'Identical locked-file repair left an incomplete marker.'}

    # A genuinely changed locked file must fail closed. Corrupt only the
    # installed copy, hold it open, require installer failure, and require the
    # persistent marker to remain because rollback cannot safely replace it.
    [IO.File]::AppendAllText($installedIcon,'AUDIT')
    $lock=[IO.File]::Open($installedIcon,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::Read)
    try{
        $exit=Invoke-Installer -Root $StageRoot -FakeLocal $fakeLocal
        if($exit -eq 0){throw 'Changed locked-file transaction incorrectly returned success.'}
        if(-not(Test-Path -LiteralPath $marker -PathType Leaf)){throw 'Changed locked-file failure did not retain the incomplete-install marker.'}
    }finally{$lock.Dispose()}

    # Once the external lock disappears, a normal repair must recover the
    # incomplete installation, restore exact package bytes, and commit cleanly.
    $exit=Invoke-Installer -Root $StageRoot -FakeLocal $fakeLocal
    if($exit -ne 0){throw "Repair after released lock returned $exit."}
    if(Test-Path -LiteralPath $marker){throw 'Successful repair did not clear the incomplete-install marker.'}
    if((Get-FileHash -LiteralPath $installedIcon -Algorithm SHA256).Hash -ne (Get-FileHash -LiteralPath $packageIcon -Algorithm SHA256).Hash){throw 'Repaired icon does not match the package.'}

    # Known obsolete package-owned files must be removed during repair even on a
    # machine that predates installed checksum manifests.
    $legacy=Join-Path $install 'HuymaierGuideInput.cs'
    Set-Content -LiteralPath $legacy -Value 'legacy' -Encoding ASCII
    $exit=Invoke-Installer -Root $StageRoot -FakeLocal $fakeLocal
    if($exit -ne 0){throw "Legacy-file cleanup repair returned $exit."}
    if(Test-Path -LiteralPath $legacy){throw 'Obsolete Guide implementation survived repair.'}

    # User-owned data remains untouched.
    if((Get-Content -Raw -LiteralPath $config -Encoding UTF8) -notmatch 'preserve-me'){throw 'config.json was modified by the managed-package transaction.'}
    if((Get-Content -Raw -LiteralPath $sentinel -Encoding ASCII).Trim() -ne 'preserve-me'){throw 'Unmanaged user data was modified by the installer.'}

    # Tampered and extra/unchecksummed packages must fail before any installed
    # managed byte is mutated. Use fresh fake install roots so rollback state from
    # one negative test cannot influence another.
    $tamperRoot=Join-Path $env:RUNNER_TEMP ('hc-tamper-'+[guid]::NewGuid().ToString('N'))
    Copy-Item -LiteralPath $StageRoot -Destination $tamperRoot -Recurse -Force
    Add-Content -LiteralPath (Join-Path $tamperRoot 'manifest.json') -Value 'tamper'
    $tamperLocal=Join-Path $env:RUNNER_TEMP ('hc-tamper-local-'+[guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Force -Path (Join-Path $tamperLocal 'Huymaier Console')|Out-Null
    Set-Content -LiteralPath (Join-Path $tamperLocal 'Huymaier Console\gameinput-redist.version') -Value '3.5.262' -Encoding ASCII
    try{
        if((Invoke-Installer -Root $tamperRoot -FakeLocal $tamperLocal) -eq 0){throw 'Tampered package was incorrectly accepted.'}
        if(Test-Path -LiteralPath (Join-Path $tamperLocal 'Huymaier Console\HuymaierConsole.exe')){throw 'Tampered package mutated the install root before rejection.'}
    }finally{Remove-Item -LiteralPath $tamperRoot,$tamperLocal -Recurse -Force -ErrorAction SilentlyContinue}

    $extraRoot=Join-Path $env:RUNNER_TEMP ('hc-extra-'+[guid]::NewGuid().ToString('N'))
    Copy-Item -LiteralPath $StageRoot -Destination $extraRoot -Recurse -Force
    Set-Content -LiteralPath (Join-Path $extraRoot 'unexpected.bin') -Value 'unexpected' -Encoding ASCII
    $extraLocal=Join-Path $env:RUNNER_TEMP ('hc-extra-local-'+[guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Force -Path (Join-Path $extraLocal 'Huymaier Console')|Out-Null
    Set-Content -LiteralPath (Join-Path $extraLocal 'Huymaier Console\gameinput-redist.version') -Value '3.5.262' -Encoding ASCII
    try{
        if((Invoke-Installer -Root $extraRoot -FakeLocal $extraLocal) -eq 0){throw 'Unchecksummed extra payload was incorrectly accepted.'}
        if(Test-Path -LiteralPath (Join-Path $extraLocal 'Huymaier Console\HuymaierConsole.exe')){throw 'Unchecksummed package mutated the install root before rejection.'}
    }finally{Remove-Item -LiteralPath $extraRoot,$extraLocal -Recurse -Force -ErrorAction SilentlyContinue}

    # Static conflict gates for Windows/Game Bar ownership and dead paths.
    $gameBar=Get-Content -Raw -LiteralPath (Join-Path $StageRoot 'HuymaierGameBar.ps1') -Encoding UTF8
    foreach($forbidden in @('AppCaptureEnabled','GameDVR_Enabled','VKMToggleGameBar')){if($gameBar -match [regex]::Escape($forbidden)){throw "Game Bar module still changes broad Windows setting: $forbidden"}}
    foreach($required in @('UseNexusForGameBarEnabled','Get-HcGameInputGuideEdge','Invoke-HcInternalGuide')){if($gameBar -notmatch [regex]::Escape($required)){throw "Game Bar integrity behavior is missing: $required"}}
    foreach($dead in @('HuymaierGuideInput.cs','HuymaierGuideBridge.dll','HuymaierConsoleUpdate.ps1','HuymaierConsoleApplyUpdate.ps1')){if(Test-Path -LiteralPath (Join-Path $StageRoot $dead)){throw "Retired payload is still packaged: $dead"}}

    $validation=Get-Content -Raw -LiteralPath $ValidationPath -Encoding UTF8|ConvertFrom-Json
    $validation|Add-Member -NotePropertyName failureInjectionTests -NotePropertyValue 'success' -Force
    $validation|Add-Member -NotePropertyName lockedIdenticalRepair -NotePropertyValue 'success' -Force
    $validation|Add-Member -NotePropertyName lockedChangedFailClosedRepair -NotePropertyValue 'success' -Force
    $validation|Add-Member -NotePropertyName unmanagedDataPreservation -NotePropertyValue 'success' -Force
    $validation|ConvertTo-Json -Depth 8|Set-Content -LiteralPath $ValidationPath -Encoding UTF8
    Write-Host 'Huymaier candidate failure-injection tests passed.'
}finally{
    Remove-Item -LiteralPath $fakeLocal -Recurse -Force -ErrorAction SilentlyContinue
}
