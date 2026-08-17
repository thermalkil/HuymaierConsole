param()
Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
$source=Join-Path $PSScriptRoot 'Optimize-ConsoleStudioLightAdvanced.ps1'
if(-not(Test-Path -LiteralPath $source -PathType Leaf)){throw 'Advanced studio-light transform is missing.'}
$text=Get-Content -Raw -LiteralPath $source -Encoding UTF8
$old=@'
    $hostText=Replace-HcOnce $hostText 'state.KeyLightScale, state.LightAzimuth, state.LightElevation, state.LightTemperature, state.AmbientScale, state.SpecularScale)' 'state.KeyLightScale, state.LightAzimuth, state.LightElevation, state.LightDistance, state.LightAimX, state.LightAimY, state.ConeDegrees, state.ConeSoftness, state.FalloffScale, state.LightTemperature, state.AmbientScale, state.SpecularScale, state.HighlightScale)' 'advanced host replay call'
'@.TrimEnd()
$new=@'
    $old='                bool studioOk = !state.StudioLightOverride || D3D11ShelfNative.HC_GPU_SetShelfItemStudioLight(nativeHandle, id, state.KeyLightScale, state.LightAzimuth, state.LightElevation, state.LightTemperature, state.AmbientScale, state.SpecularScale) != 0;'
    $new='                bool studioOk = !state.StudioLightOverride || D3D11ShelfNative.HC_GPU_SetShelfItemStudioLight(nativeHandle, id, state.KeyLightScale, state.LightAzimuth, state.LightElevation, state.LightDistance, state.LightAimX, state.LightAimY, state.ConeDegrees, state.ConeSoftness, state.FalloffScale, state.LightTemperature, state.AmbientScale, state.SpecularScale, state.HighlightScale) != 0;'
    $hostText=Replace-HcOnce $hostText $old $new 'advanced host replay call'
'@.TrimEnd()
$count=([regex]::Matches($text,[regex]::Escape($old))).Count
if($count-ne1){throw "Expected one ambiguous advanced replay patch line, found $count."}
$text=$text.Replace($old,$new)
$temp=Join-Path ([IO.Path]::GetTempPath()) ('hc-advanced-light-'+[guid]::NewGuid().ToString('N')+'.ps1')
try{
    [IO.File]::WriteAllText($temp,$text,(New-Object Text.UTF8Encoding($false)))
    & $temp
    if($LASTEXITCODE-ne0){throw "Advanced studio-light transform exited with code $LASTEXITCODE."}
}
finally{Remove-Item -LiteralPath $temp -Force -ErrorAction SilentlyContinue}
