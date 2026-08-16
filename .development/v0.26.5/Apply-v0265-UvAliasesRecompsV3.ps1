Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
$root=(Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
& (Join-Path $PSScriptRoot 'Apply-v0265-UvAliasesRecompsV2.ps1')

$runtimePath=Join-Path $root 'Native\HuymaierD3D11ShelfRuntime.cpp'
$runtime=[IO.File]::ReadAllText($runtimePath)
$bad='hr=s.d3d9->CreateTexture(width,height,1,D3DUSAGE_RENDERTARGET,D3DFMT_A8R8G8B8,D3DPOOL_DEFAULT,s.texture9.GetAddressOf(),&s.sharedHandle);'
$good='hr=s.device9->CreateTexture(width,height,1,D3DUSAGE_RENDERTARGET,D3DFMT_A8R8G8B8,D3DPOOL_DEFAULT,s.texture9.GetAddressOf(),&s.sharedHandle);'
if(-not $runtime.Contains($good)){
    if(-not $runtime.Contains($bad)){throw 'D3D9Ex shared-texture creation anchor missing.'}
    $runtime=$runtime.Replace($bad,$good)
    [IO.File]::WriteAllText($runtimePath,$runtime,(New-Object Text.UTF8Encoding($false)))
}
Write-Host 'platformModelD3D9DeviceTextureCreationGate: success'
