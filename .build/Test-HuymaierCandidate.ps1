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
    foreach($required in @('UseNexusForGameBarEnabled','Get-HcSystemGuideEdge','Invoke-HcInternalGuide')){if($gameBar -notmatch [regex]::Escape($required)){throw "Game Bar integrity behavior is missing: $required"}}
    foreach($dead in @('HuymaierGuideInput.cs','HuymaierGuideBridge.dll','HuymaierConsoleUpdate.ps1','HuymaierConsoleApplyUpdate.ps1')){if(Test-Path -LiteralPath (Join-Path $StageRoot $dead)){throw "Retired payload is still packaged: $dead"}}


    # Runtime ownership invariant: the hidden watcher must never call the shared
    # normal-navigation poller directly. Once the overlay is visibly active, the
    # Game-Bar-owned modal bypass is the only permitted D-pad/A/B/etc. poll path.
    $visibleIndex=$gameBar.IndexOf('$visible=[HuymaierConsole.NativeApp.HuymaierGameBarHost]::IsVisible')
    $safePollIndex=$gameBar.IndexOf('[HuymaierConsole.NativeApp.HuymaierGameBarHost]::PollNavigation()')
    if($gameBar -match [regex]::Escape('[HuymaierConsole.NativeApp.NativeConsoleNavigation]::Poll()')){throw 'Game Bar module directly polls shared normal navigation instead of using modal ownership.'}
    if($visibleIndex -lt 0 -or $safePollIndex -lt 0 -or $safePollIndex -lt $visibleIndex){throw 'Game Bar modal navigation polling is not confined to the visible-overlay path.'}
    foreach($required in @('Test-HcForegroundOwnedByConsole','HuymaierForegroundOwnership','System Guide backend initialized')){if($gameBar -notmatch [regex]::Escape($required)){throw "Game Bar foreground/Guide ownership invariant is missing: $required"}}
    $emulator=Get-Content -Raw -LiteralPath (Join-Path $StageRoot 'HuymaierEmulatorPlatforms.ps1') -Encoding UTF8
    if($emulator -notmatch [regex]::Escape('Test-HcEmulatorPlatformMenuName $platform')){throw 'Platform selection is not using strict emulator menu identity.'}
    $restore=Get-Content -Raw -LiteralPath (Join-Path $StageRoot 'Restore-HuymaierWindowsSettings.ps1') -Encoding UTF8
    if($restore -notmatch [regex]::Escape('foreach($backup in @($rawBackup))')){throw 'Legacy Xbox Game Bar backup-array migration is missing.'}


    # RC9: external Guide fallback must be strictly Guide-only, and the public
    # installer wrapper must seed success state while propagating real failures.
    foreach($required in @('ConsumeGuideOnly','Get-HcSystemGuideEdge')){if($gameBar -notmatch [regex]::Escape($required)){throw "Guide-only external Game Bar wake path is missing: $required"}}
    $nativeApp=Get-Content -Raw -LiteralPath (Join-Path $StageRoot 'Native\\HuymaierConsole.NativeApp.cs') -Encoding UTF8
    foreach($required in @('public static bool ConsumeGuideOnly()','XInputBridge.ConsumeGuideEdge()','RawHidController.ConsumeGuideEdge()')){if($nativeApp -notmatch [regex]::Escape($required)){throw "Native Guide-only fallback invariant is missing: $required"}}
    $nativeInput=Get-Content -Raw -LiteralPath (Join-Path $StageRoot 'HuymaierNativeInput.cs') -Encoding UTF8
    if($nativeInput -notmatch [regex]::Escape('value.PendingMask &= ~2')){throw 'PlayStation Guide-only fallback does not preserve non-Guide pending input.'}
    $wrapper=Get-Content -Raw -LiteralPath (Join-Path $StageRoot 'Install-HuymaierConsole.ps1') -Encoding UTF8
    if($wrapper -notmatch [regex]::Escape('$global:LASTEXITCODE=0')){throw 'Public installer wrapper does not seed a deterministic success exit state.'}
    if($wrapper -notmatch [regex]::Escape('exit ([int]$global:LASTEXITCODE)')){throw 'Public installer wrapper does not propagate the core transaction exit state.'}
    $coreText=Get-Content -Raw -LiteralPath (Join-Path $StageRoot 'HuymaierInstallerCore.ps1') -Encoding UTF8
    if($coreText -notmatch [regex]::Escape('if($SilentUpdate){return}')){throw 'Installer core does not return through the public wrapper on silent success.'}


    # RC13: Game Bar must raise itself above fullscreen/maximized surfaces, own
    # Huymaier controller navigation modally while visible, and native folder
    # pickers must actually enter the File Explorer surface before returning.
    $overlay=Get-Content -Raw -LiteralPath (Join-Path $StageRoot 'Native\\HuymaierConsole.SystemOverlay.cs') -Encoding UTF8
    foreach($required in @('SetWindowPos(handle, HWND_TOPMOST','PromoteOverlayToFront()','BlocksNativeNavigation','PollNavigation()')){if($overlay -notmatch [regex]::Escape($required)){throw "Game Bar z-order/modal ownership invariant is missing: $required"}}
    $nativeApp=Get-Content -Raw -LiteralPath (Join-Path $StageRoot 'Native\\HuymaierConsole.NativeApp.cs') -Encoding UTF8
    $modalGateCount=([regex]::Matches($nativeApp,[regex]::Escape('HuymaierGameBarHost.BlocksNativeNavigation'))).Count
    if($modalGateCount -lt 2){throw 'Game Bar modal ownership is not enforced in both native router layers.'}
    if($gameBar -notmatch [regex]::Escape('[HuymaierConsole.NativeApp.HuymaierGameBarHost]::PollNavigation()')){throw 'Visible Game Bar does not use its modal-safe navigation poll.'}
    $shell=Get-Content -Raw -LiteralPath (Join-Path $StageRoot 'HuymaierConsole.ps1') -Encoding UTF8
    $pickerStart=$shell.IndexOf('function Start-NativeFilePicker')
    $pickerEnd=$shell.IndexOf('function Complete-NativeFolderSelection',$pickerStart)
    $tabIndex=$shell.IndexOf('$script:SelectedTab=6',$pickerStart)
    $subPageIndex=$shell.IndexOf('$script:SubPage=''FilePicker''',$pickerStart)
    if($pickerStart -lt 0 -or $pickerEnd -lt 0 -or $tabIndex -lt $pickerStart -or $tabIndex -ge $pickerEnd -or $subPageIndex -lt $tabIndex -or $subPageIndex -ge $pickerEnd){throw 'Native non-Browse file picker does not enter the File Explorer tab before rendering FilePicker.'}

    # Combined next-build gates: customization is persisted and controller-first,
    # storefront Xbox counts by storefront display identity, custom WPF focus
    # rectangles are removed, and the Game Bar receives the selected branding.
    $customPath=Join-Path $StageRoot 'HuymaierCustomization.ps1'
    if(-not(Test-Path -LiteralPath $customPath -PathType Leaf)){throw 'Customization module is missing from the candidate.'}
    $custom=Get-Content -Raw -LiteralPath $customPath -Encoding UTF8
    foreach($required in @("SubPage -eq 'Customization'",'ConsoleName','DynamicPrimaryColor','DynamicSecondaryColor','UiSoundVolume','Test-HcStorefrontPlatform $Platform','Scaling normal list cards caused selected text/borders to be clipped')){if($custom -notmatch [regex]::Escape($required)){throw "Customization/count/card invariant is missing: $required"}}
    foreach($required in @('New-HcRadialThemeBrush','Update-HcPageDisplayBrand','Convert-HcDisplayBrandText')){if($custom -notmatch [regex]::Escape($required)){throw "Customization gradient/display-name coverage is missing: $required"}}
    $shellRedesign=Get-Content -Raw -LiteralPath (Join-Path $StageRoot 'HuymaierShellRedesign.ps1') -Encoding UTF8
    $consoleSettingsStart=$shellRedesign.IndexOf('if($script:SubPage -eq ''ConsoleSettings'')')
    $updatesStart=$shellRedesign.IndexOf('if($script:SubPage -eq ''UpdatesHub'')',$consoleSettingsStart)
    if($consoleSettingsStart -lt 0 -or $updatesStart -lt 0){throw 'ConsoleSettings test window could not be located.'}
    $consoleSettings=$shellRedesign.Substring($consoleSettingsStart,$updatesStart-$consoleSettingsStart)
    foreach($moved in @("'music-toggle'","'music-theme'","'music-import'","'music-volume-slider'","'ui-sounds-toggle'","'background-toggle'","'keyboard-theme'")){if($consoleSettings -match [regex]::Escape($moved)){throw "Personalization setting remains duplicated outside Customization: $moved"}}
    $shell=Get-Content -Raw -LiteralPath (Join-Path $StageRoot 'HuymaierConsole.ps1') -Encoding UTF8
    foreach($required in @('HuymaierCustomization.ps1','FocusVisualStyle','ConsoleBrandText','DynamicGlowOne','Apply-HcCustomizationVisuals')){if($shell -notmatch [regex]::Escape($required)){throw "Shell customization/focus invariant is missing: $required"}}
    $overlay=Get-Content -Raw -LiteralPath (Join-Path $StageRoot 'Native\HuymaierConsole.SystemOverlay.cs') -Encoding UTF8
    foreach($required in @('SetDisplayName','SetAccentColor','SetBrand(displayName, accentColor)','AttachThreadInput','SetWindowPos(handle, HWND_TOPMOST')){if($overlay -notmatch [regex]::Escape($required)){throw "Game Bar branding/focus invariant is missing: $required"}}

    $validation=Get-Content -Raw -LiteralPath $ValidationPath -Encoding UTF8|ConvertFrom-Json
    $validation|Add-Member -NotePropertyName failureInjectionTests -NotePropertyValue 'success' -Force
    $validation|Add-Member -NotePropertyName lockedIdenticalRepair -NotePropertyValue 'success' -Force
    $validation|Add-Member -NotePropertyName lockedChangedFailClosedRepair -NotePropertyValue 'success' -Force
    $validation|Add-Member -NotePropertyName unmanagedDataPreservation -NotePropertyValue 'success' -Force
    $validation|Add-Member -NotePropertyName guideOnlyWakeGate -NotePropertyValue 'success' -Force
    $validation|Add-Member -NotePropertyName installerWrapperExitGate -NotePropertyValue 'success' -Force
    $validation|Add-Member -NotePropertyName gameBarZOrderGate -NotePropertyValue 'success' -Force
    $validation|Add-Member -NotePropertyName gameBarModalInputGate -NotePropertyValue 'success' -Force
    $validation|Add-Member -NotePropertyName nativeFilePickerRoutingGate -NotePropertyValue 'success' -Force
    $validation|Add-Member -NotePropertyName customizationGate -NotePropertyValue 'success' -Force
    $validation|Add-Member -NotePropertyName cardFocusVisualGate -NotePropertyValue 'success' -Force
    $validation|Add-Member -NotePropertyName xboxStorefrontCountGate -NotePropertyValue 'success' -Force
    $validation|Add-Member -NotePropertyName gameBarForegroundFocusGate -NotePropertyValue 'success' -Force
    $validation|ConvertTo-Json -Depth 8|Set-Content -LiteralPath $ValidationPath -Encoding UTF8
    Write-Host 'Huymaier candidate failure-injection tests passed.'
}finally{
    Remove-Item -LiteralPath $fakeLocal -Recurse -Force -ErrorAction SilentlyContinue
}
