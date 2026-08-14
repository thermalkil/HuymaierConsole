param(
    [Parameter(Mandatory=$true)][string]$CorePath
)
Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'

if(-not(Test-Path -LiteralPath $CorePath -PathType Leaf)){throw "Huymaier startup optimizer could not find $CorePath"}
$text=[IO.File]::ReadAllText($CorePath,[Text.Encoding]::UTF8)

function Replace-HcExact {
    param([string]$Label,[string]$Old,[string]$New)
    $first=$script:text.IndexOf($Old,[StringComparison]::Ordinal)
    if($first -lt 0){throw "Startup optimizer could not find the expected $Label block."}
    if($script:text.IndexOf($Old,$first+$Old.Length,[StringComparison]::Ordinal) -ge 0){throw "Startup optimizer found duplicate $Label blocks."}
    $script:text=$script:text.Substring(0,$first)+$New+$script:text.Substring($first+$Old.Length)
}

Replace-HcExact 'native display Add-Type' @'
try {
    if (Test-Path $script:NativeDisplayPath) { Add-Type -Path $script:NativeDisplayPath -ErrorAction Stop }
} catch { }
'@ @'
try {
    if (-not ('HuymaierConsole.Native.DisplayBridge' -as [type]) -and (Test-Path $script:NativeDisplayPath)) { Add-Type -Path $script:NativeDisplayPath -ErrorAction Stop }
} catch { }
'@

Replace-HcExact 'native audio Add-Type' @'
try {
    if (Test-Path $script:NativeAudioPath) { Add-Type -Path $script:NativeAudioPath -ErrorAction Stop }
} catch { }
'@ @'
try {
    if (-not ('HuymaierConsole.Native.AudioBridge' -as [type]) -and (Test-Path $script:NativeAudioPath)) { Add-Type -Path $script:NativeAudioPath -ErrorAction Stop }
} catch { }
'@

Replace-HcExact 'native input Add-Type' @'
try {
    if (Test-Path $script:NativeInputPath) { Add-Type -Path $script:NativeInputPath -ErrorAction Stop }
} catch { }
'@ @'
try {
    if (-not ('HuymaierConsole.Native.LegacyJoystick' -as [type]) -and (Test-Path $script:NativeInputPath)) { Add-Type -Path $script:NativeInputPath -ErrorAction Stop }
} catch { }
'@

Replace-HcExact 'native performance Add-Type' @'
try {
    if (Test-Path $script:NativePerformancePath) { Add-Type -Path $script:NativePerformancePath -ReferencedAssemblies @('System.dll','System.Core.dll','WindowsBase.dll','PresentationCore.dll') -ErrorAction Stop }
} catch { }
'@ @'
try {
    if (-not ('HuymaierConsole.Native.FrameRateMonitor' -as [type]) -and (Test-Path $script:NativePerformancePath)) { Add-Type -Path $script:NativePerformancePath -ReferencedAssemblies @('System.dll','System.Core.dll','WindowsBase.dll','PresentationCore.dll') -ErrorAction Stop }
} catch { }
'@

Replace-HcExact 'pre-show visual/audio startup' @'
    Set-BackgroundAnimationState
    Set-FpsCounterState
    Initialize-UiFeedback
    if(Get-Command Apply-HcCustomizationVisuals -ErrorAction SilentlyContinue){Apply-HcCustomizationVisuals}
    Initialize-BackgroundMusic
    Update-NavVisuals
    Render-Page
'@ @'
    # Keep only first-frame-critical visual construction on the synchronous boot
    # path. Animations, FPS hooks and MediaPlayer initialization are deferred
    # until WPF has rendered once so Xbox/Home Experience becomes usable sooner.
    if(Get-Command Apply-HcCustomizationVisuals -ErrorAction SilentlyContinue){Apply-HcCustomizationVisuals}
    Update-NavVisuals
    Render-Page
    $script:HcDeferredStartupInitialized=$false
    $script:Window.Add_ContentRendered({
        if($script:HcDeferredStartupInitialized){return}
        $script:HcDeferredStartupInitialized=$true
        $initializeDeferred=[Action]{
            try{Set-BackgroundAnimationState}catch{Write-Log "Deferred background animation startup failed: $($_.Exception.Message)" 'WARN'}
            try{Set-FpsCounterState}catch{Write-Log "Deferred FPS startup failed: $($_.Exception.Message)" 'WARN'}
            try{Initialize-UiFeedback}catch{Write-Log "Deferred UI feedback startup failed: $($_.Exception.Message)" 'WARN'}
            try{Initialize-BackgroundMusic}catch{Write-Log "Deferred background music startup failed: $($_.Exception.Message)" 'WARN'}
            Write-Log 'Deferred post-first-frame shell services initialized.'
        }
        try{[void]$script:Window.Dispatcher.BeginInvoke([System.Windows.Threading.DispatcherPriority]::Background,$initializeDeferred)}
        catch{& $initializeDeferred}
    })
'@

Replace-HcExact 'initial library scan delay' @'
        $script:InitialScanTimer.Interval = [TimeSpan]::FromMilliseconds(700)
'@ @'
        $script:InitialScanTimer.Interval = [TimeSpan]::FromMilliseconds(1800)
'@

$bom=New-Object Text.UTF8Encoding($true)
[IO.File]::WriteAllText($CorePath,$text,$bom)
Write-Host 'Applied deterministic packaged startup optimizations to HuymaierConsole.ps1.'