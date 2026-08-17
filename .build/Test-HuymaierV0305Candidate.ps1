param(
    [Parameter(Mandatory=$true)][string]$StageRoot,
    [Parameter(Mandatory=$true)][string]$ValidationPath
)
Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
if(-not(Test-Path -LiteralPath $StageRoot -PathType Container)){throw "v0.30.5 stage root missing: $StageRoot"}
if(-not(Test-Path -LiteralPath $ValidationPath -PathType Leaf)){throw "v0.30.5 validation record missing: $ValidationPath"}
$validation=Get-Content -Raw -LiteralPath $ValidationPath -Encoding UTF8|ConvertFrom-Json
if([string]$validation.version -ne '0.30.5'){throw "Expected validation version 0.30.5, found $($validation.version)."}
if([string]$validation.asset -ne 'HC0305.zip'){throw "Expected HC0305.zip, found $($validation.asset)."}
$manifest=Get-Content -Raw -LiteralPath (Join-Path $StageRoot 'manifest.json') -Encoding UTF8|ConvertFrom-Json
if([string]$manifest.version -ne '0.30.5' -or [string]$manifest.baseVersion -ne '0.30.4'){throw 'v0.30.5 manifest identity/base release is wrong.'}
$appx=Get-Content -Raw -LiteralPath (Join-Path $StageRoot 'FSEPackage\AppxManifest.xml') -Encoding UTF8
if($appx -notmatch 'Version="0\.30\.5\.0"'){throw 'v0.30.5 AppX identity is missing.'}
Write-Host 'v0305VersionIdentityGate: success'

$compilerSource=Get-Content -Raw -LiteralPath (Join-Path $StageRoot 'Native\HuymaierGpuShelfAssetCompiler.cs') -Encoding UTF8
foreach($needle in @('HUYMAIER_V0305_ADAPTIVE_WINDING_V1','ShouldFlipWinding','bool flipWinding=ShouldFlipWinding(vertices,baseVertex,ix,mirrored)','if(mirrored)tw=-tw;')){
    if($compilerSource.IndexOf($needle,[StringComparison]::Ordinal)-lt0){throw "Staged v0.30.5 compiler winding contract missing: $needle"}
}
$gpuRuntime=Get-Content -Raw -LiteralPath (Join-Path $StageRoot 'HuymaierGpuPlatformShelves.ps1') -Encoding UTF8
if($gpuRuntime.IndexOf("`$name+'.winding-v2.hc3d'",[StringComparison]::Ordinal)-lt0){throw 'Staged v0.30.5 cache namespace is missing.'}
Write-Host 'v0305AdaptiveWindingStageSourceGate: success'
Write-Host 'v0305WindingCacheRefreshStageGate: success'

$modelDefaults=Get-Content -Raw -LiteralPath (Join-Path $StageRoot 'HuymaierModelDefaults.ps1') -Encoding UTF8
foreach($needle in @('HUYMAIER_V0304_MODEL_DEFAULT_ORIENTATION_EDITOR_V1','EDIT MODEL','Set-HcModelDefaultView','SetItemView([int]$card.ActionIndex')){if($modelDefaults.IndexOf($needle,[StringComparison]::Ordinal)-lt0){throw "v0.30.4 model editor carry-forward missing: $needle"}}
$updater=Get-Content -Raw -LiteralPath (Join-Path $StageRoot 'HuymaierSelfUpdater.ps1') -Encoding UTF8
foreach($needle in @("GetEnvironmentVariable('HUYMAIER_FSE_HOST')",'HuymaierConsoleFseUpdate.lock','if($relaunch -and -not $isFseManaged)','Windows FSE host owns post-update relaunch.')){if($updater.IndexOf($needle,[StringComparison]::Ordinal)-lt0){throw "v0.30.3 FSE updater carry-forward missing: $needle"}}
$customization=Get-Content -Raw -LiteralPath (Join-Path $StageRoot 'HuymaierCustomization.ps1') -Encoding UTF8
foreach($needle in @('HUYMAIER_V0302_CONSOLE_BRIGHTNESS_V1',"New-SliderAction 'console-brightness-slider' 'Huymaier Console brightness'","'Adjust the entire Huymaier Console interface from 0% to 200% in 10% steps.' 0 200")){if($customization.IndexOf($needle,[StringComparison]::Ordinal)-lt0){throw "Console brightness carry-forward missing: $needle"}}
Write-Host 'v0305ModelEditorCarryForwardGate: success'
Write-Host 'v0305FseUpdaterCarryForwardGate: success'
Write-Host 'v0305BrightnessCarryForwardGate: success'

$compilerExe=Join-Path $StageRoot 'HuymaierGpuShelfAssetCompiler.exe'
if(-not(Test-Path -LiteralPath $compilerExe -PathType Leaf)){throw 'Staged GPU shelf compiler exe is missing.'}
$temp=Join-Path $(if($env:RUNNER_TEMP){$env:RUNNER_TEMP}else{[IO.Path]::GetTempPath()}) ('hc-v0305-stage-winding-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $temp|Out-Null
function New-HcStageWindingProbe {
    param([Parameter(Mandatory=$true)][string]$Path,[Parameter(Mandatory=$true)][uint16[]]$TriangleIndices)
    $ms=New-Object IO.MemoryStream;$bw=New-Object IO.BinaryWriter($ms)
    try{
        foreach($f in @([single]-1,[single]-1,[single]0,[single]1,[single]-1,[single]0,[single]0,[single]1,[single]0)){$bw.Write($f)}
        foreach($i in 0..2){$bw.Write([single]0);$bw.Write([single]0);$bw.Write([single]1)}
        foreach($ix in $TriangleIndices){$bw.Write([uint16]$ix)}
        while(($ms.Position%4)-ne0){$bw.Write([byte]0)};$bw.Flush();$bin=[byte[]]$ms.ToArray()
    }finally{$bw.Dispose();$ms.Dispose()}
    $json="{`"asset`":{`"version`":`"2.0`"},`"scene`":0,`"scenes`":[{`"nodes`":[0]}],`"nodes`":[{`"mesh`":0,`"scale`":[-1,1,1]}],`"meshes`":[{`"primitives`":[{`"attributes`":{`"POSITION`":0,`"NORMAL`":1},`"indices`":2,`"material`":0,`"mode`":4}]}],`"materials`":[{`"doubleSided`":false,`"pbrMetallicRoughness`":{`"baseColorFactor`":[1,1,1,1]}}],`"buffers`":[{`"byteLength`":$($bin.Length)}],`"bufferViews`":[{`"buffer`":0,`"byteOffset`":0,`"byteLength`":36},{`"buffer`":0,`"byteOffset`":36,`"byteLength`":36},{`"buffer`":0,`"byteOffset`":72,`"byteLength`":6}],`"accessors`":[{`"bufferView`":0,`"componentType`":5126,`"count`":3,`"type`":`"VEC3`"},{`"bufferView`":1,`"componentType`":5126,`"count`":3,`"type`":`"VEC3`"},{`"bufferView`":2,`"componentType`":5123,`"count`":3,`"type`":`"SCALAR`"}]}"
    $jb=[Text.Encoding]::UTF8.GetBytes($json);$pad=(4-($jb.Length%4))%4;$jc=New-Object byte[]($jb.Length+$pad);[Array]::Copy($jb,$jc,$jb.Length);for($i=$jb.Length;$i-lt$jc.Length;$i++){$jc[$i]=0x20};$total=12+8+$jc.Length+8+$bin.Length
    $fs=[IO.File]::Create($Path);$out=New-Object IO.BinaryWriter($fs);try{$out.Write([byte[]](0x67,0x6C,0x54,0x46));$out.Write([uint32]2);$out.Write([uint32]$total);$out.Write([uint32]$jc.Length);$out.Write([uint32]0x4E4F534A);$out.Write($jc);$out.Write([uint32]$bin.Length);$out.Write([uint32]0x004E4942);$out.Write($bin)}finally{$out.Dispose();$fs.Dispose()}
}
function Get-HcStageTriangle([string]$Cache){
    $br=New-Object IO.BinaryReader([IO.File]::OpenRead($Cache));try{
        if((-join$br.ReadChars(4))-ne'HC3D'){throw 'Staged winding probe cache magic is invalid.'};$version=$br.ReadInt32();if($version-ne4){throw "Expected staged HC3D v4, found v$version"}
        [void]$br.ReadInt64();[void]$br.ReadInt64();[void]$br.ReadInt32();$vc=$br.ReadInt32();$ic=$br.ReadInt32();[void]$br.ReadInt32();[void]$br.ReadInt32();for($i=0;$i-lt6;$i++){[void]$br.ReadSingle()};if($vc-ne3-or$ic-ne3){throw "Unexpected staged winding counts v=$vc i=$ic"};$br.BaseStream.Position+=($vc*96);return @($br.ReadUInt32(),$br.ReadUInt32(),$br.ReadUInt32())
    }finally{$br.Dispose()}
}
try{
    $a=Join-Path $temp 'canonical.glb';$ac=Join-Path $temp 'canonical.hc3d';New-HcStageWindingProbe $a @([uint16]0,[uint16]1,[uint16]2);& $compilerExe --model $a --cache $ac --size 128;if($LASTEXITCODE-ne0){throw 'Staged compiler failed canonical negative-determinant probe.'};$ai=@(Get-HcStageTriangle $ac);if(($ai-join',')-ne'0,2,1'){throw "Staged canonical winding repair failed: $($ai-join',')"}
    $b=Join-Path $temp 'premirrored.glb';$bc=Join-Path $temp 'premirrored.hc3d';New-HcStageWindingProbe $b @([uint16]0,[uint16]2,[uint16]1);& $compilerExe --model $b --cache $bc --size 128;if($LASTEXITCODE-ne0){throw 'Staged compiler failed pre-mirrored probe.'};$bi=@(Get-HcStageTriangle $bc);if(($bi-join',')-ne'0,2,1'){throw "Staged pre-mirrored mesh was double-flipped: $($bi-join',')"}
    Write-Host 'v0305StagedNegativeDeterminantRepairGate: success'
    Write-Host 'v0305StagedPreMirroredNoDoubleFlipGate: success'
}finally{Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue}
