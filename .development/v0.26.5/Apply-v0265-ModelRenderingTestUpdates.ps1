Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
$root=(Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$utf8=New-Object Text.UTF8Encoding($false)
function Patch([string]$rel,[scriptblock]$edit){$p=Join-Path $root $rel;$s=([IO.File]::ReadAllText($p)).Replace("`r`n","`n");$n=&$edit $s;if($n-ne$s){[IO.File]::WriteAllText($p,$n,$utf8)}}

Patch '.development\v0.26.5\Test-v0265-GpuShelfAssetCompiler.ps1' {param($s)$s.Replace('$version-ne1','$version-ne2')}
Patch '.development\v0.26.5\Test-v0265-D3D11CachedModelRender.ps1' {param($s)$s.Replace('br.ReadInt32()-ne1','br.ReadInt32()-ne2').Replace('$version-ne1','$version-ne2')}
Patch '.development\v0.26.5\Test-v0265-GpuPlatformShelvesV7.ps1' {param($s)$s.Replace("if(`$reader.ReadInt32()-ne1){return `$false}","if(`$reader.ReadInt32()-ne2){return `$false}")}
Patch '.build\Test-HuymaierV0265PlatformModelsCandidate.ps1' {param($s)$s.Replace("br.ReadInt32()-ne1","br.ReadInt32()-ne2").Replace("'HC_GPU_SetShelfItem'","'HC_GPU_SetShelfItem','HC_GPU_SetShelfBrightness'")}
Patch '.build\Optimize-GpuPlatformShelves.ps1' {param($s)$s.Replace("'HC_GPU_SetShelfItem','HC_GPU_RenderShelfSurface'","'HC_GPU_SetShelfItem','HC_GPU_SetShelfBrightness','HC_GPU_RenderShelfSurface'")}
Patch '.development\v0.26.5\Test-v0265-D3D11ShelfBackend.ps1' {param($s)$s.Replace("'HC_GPU_SetShelfItem','HC_GPU_RenderShelfSurface'","'HC_GPU_SetShelfItem','HC_GPU_SetShelfBrightness','HC_GPU_RenderShelfSurface'").Replace("'HC_GPU_SetShelfItem','HC_GPU_ClearShelfItems'","'HC_GPU_SetShelfItem','HC_GPU_SetShelfBrightness','HC_GPU_ClearShelfItems'")}

Write-Host 'modelRenderingTestUpdateGate: success'
