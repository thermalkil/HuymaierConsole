param([string]$StageRoot='',[switch]$VerifyCompiledHost)
Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
# HUYMAIER_V0308_NATIVE_BUILD_STAMP_GATE_V1
if(-not $StageRoot){$StageRoot=Split-Path -Parent (Split-Path -Parent $PSScriptRoot)}
$StageRoot=(Resolve-Path -LiteralPath $StageRoot).Path
function Assert([bool]$Condition,[string]$Message){if(-not $Condition){throw $Message}}
$sourcePath=Join-Path $StageRoot 'Native\HuymaierConsole.GameInput.cs'
Assert (Test-Path -LiteralPath $sourcePath -PathType Leaf) 'Native build-stamp source is missing.'
$source=Get-Content -Raw -LiteralPath $sourcePath -Encoding UTF8
Assert ($source.Contains('public const string Version = "0.30.8";')) 'Native source build stamp is not v0.30.8.'
Assert ($source.Contains('public const string Architecture = "x64";')) 'Native source architecture stamp is not x64.'
if($VerifyCompiledHost){
    $hostPath=Join-Path $StageRoot 'HuymaierConsole.exe'
    Assert (Test-Path -LiteralPath $hostPath -PathType Leaf) 'Compiled HuymaierConsole.exe is missing.'
    $assembly=[Reflection.Assembly]::LoadFile((Resolve-Path -LiteralPath $hostPath).Path)
    $stampType=$assembly.GetType('HuymaierConsole.NativeApp.HuymaierBuildStamp',$false)
    Assert ($null -ne $stampType) 'Compiled native host has no HuymaierBuildStamp.'
    $flags=[Reflection.BindingFlags]::Public -bor [Reflection.BindingFlags]::Static
    $versionField=$stampType.GetField('Version',$flags)
    $architectureField=$stampType.GetField('Architecture',$flags)
    Assert ($null -ne $versionField) 'Compiled native host has no public Version stamp.'
    Assert ($null -ne $architectureField) 'Compiled native host has no public Architecture stamp.'
    $version=[string]$versionField.GetValue($null)
    $architecture=[string]$architectureField.GetValue($null)
    Assert ([string]::Equals($version,'0.30.8',[StringComparison]::OrdinalIgnoreCase)) "Compiled native host build stamp is $version; expected 0.30.8."
    Assert ([string]::Equals($architecture,'x64',[StringComparison]::OrdinalIgnoreCase)) "Compiled native host architecture is $architecture; expected x64."
    Write-Host "Compiled native host build stamp verified: $version/$architecture"
}
Write-Host 'v0.30.8 native build stamp validation passed.'
