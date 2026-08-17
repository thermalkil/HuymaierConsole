param()
Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
$source=Join-Path $PSScriptRoot 'Optimize-ConsoleStudioLightAdvanced.ps1'
if(-not(Test-Path -LiteralPath $source -PathType Leaf)){throw 'Advanced studio-light transform is missing.'}
$text=Get-Content -Raw -LiteralPath $source -Encoding UTF8

function Replace-TransformLine([string]$Old,[string]$New,[string]$Label){
    $count=([regex]::Matches($script:text,[regex]::Escape($Old))).Count
    if($count-ne1){throw "Expected one $Label transform line, found $count."}
    $script:text=$script:text.Replace($Old,$New)
}

$old=@'
    $hostText=Replace-HcOnce $hostText 'state.KeyLightScale, state.LightAzimuth, state.LightElevation, state.LightTemperature, state.AmbientScale, state.SpecularScale)' 'state.KeyLightScale, state.LightAzimuth, state.LightElevation, state.LightDistance, state.LightAimX, state.LightAimY, state.ConeDegrees, state.ConeSoftness, state.FalloffScale, state.LightTemperature, state.AmbientScale, state.SpecularScale, state.HighlightScale)' 'advanced host replay call'
'@.TrimEnd()
$new=@'
    $old='                bool studioOk = !state.StudioLightOverride || D3D11ShelfNative.HC_GPU_SetShelfItemStudioLight(nativeHandle, id, state.KeyLightScale, state.LightAzimuth, state.LightElevation, state.LightTemperature, state.AmbientScale, state.SpecularScale) != 0;'
    $new='                bool studioOk = !state.StudioLightOverride || D3D11ShelfNative.HC_GPU_SetShelfItemStudioLight(nativeHandle, id, state.KeyLightScale, state.LightAzimuth, state.LightElevation, state.LightDistance, state.LightAimX, state.LightAimY, state.ConeDegrees, state.ConeSoftness, state.FalloffScale, state.LightTemperature, state.AmbientScale, state.SpecularScale, state.HighlightScale) != 0;'
    $hostText=Replace-HcOnce $hostText $old $new 'advanced host replay call'
'@.TrimEnd()
Replace-TransformLine $old $new 'ambiguous host replay'

# PowerShell treats inline concatenated strings followed by a parenthesized next
# argument as a format-expression edge case in Windows PowerShell 5.1. Expand
# those two multiline replacements into explicit $old/$new variables first.
$old=@'
    $runtimeText=Replace-HcOnce $runtimeText '        XMFLOAT4 extra;'+$nl+'    };' ('        XMFLOAT4 extra;'+$nl+'        XMFLOAT4 extra2;'+$nl+'    };') 'advanced constants layout'
'@.TrimEnd()
$new=@'
    $old='        XMFLOAT4 extra;'+$nl+'    };'
    $new='        XMFLOAT4 extra;'+$nl+'        XMFLOAT4 extra2;'+$nl+'    };'
    $runtimeText=Replace-HcOnce $runtimeText $old $new 'advanced constants layout'
'@.TrimEnd()
Replace-TransformLine $old $new 'runtime constants layout'

$old=@'
    $assetText=Replace-HcOnce $assetText '        float4 StudioLightExtra;'+$nl+'    };' ('        float4 StudioLightExtra;'+$nl+'        float4 StudioLightExtra2;'+$nl+'    };') 'advanced shader constants'
'@.TrimEnd()
$new=@'
    $old='        float4 StudioLightExtra;'+$nl+'    };'
    $new='        float4 StudioLightExtra;'+$nl+'        float4 StudioLightExtra2;'+$nl+'    };'
    $assetText=Replace-HcOnce $assetText $old $new 'advanced shader constants'
'@.TrimEnd()
Replace-TransformLine $old $new 'shader constants layout'

# Keep the temporary script beside the real transform so its $PSScriptRoot is
# still .build and the transform resolves the repository root correctly.
$temp=Join-Path $PSScriptRoot ('.tmp-advanced-light-'+[guid]::NewGuid().ToString('N')+'.ps1')
try{
    [IO.File]::WriteAllText($temp,$text,(New-Object Text.UTF8Encoding($false)))
    & $temp
    if($LASTEXITCODE-ne0){throw "Advanced studio-light transform exited with code $LASTEXITCODE."}
}
finally{Remove-Item -LiteralPath $temp -Force -ErrorAction SilentlyContinue}
