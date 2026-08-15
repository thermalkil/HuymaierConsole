Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
$root=(Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$module=Join-Path $root 'HuymaierPlatformModels.ps1'
$worker=Join-Path $root 'Native\HuymaierModelPreviewWorker.cs'
$aliases=Join-Path $root 'Native\HuymaierModelPreviewWpfAliases.cs'
$optimizer=Join-Path $root '.build\Optimize-Platform3DModels.ps1'
$modelMap=Join-Path $root 'Assets\Models\model-map.json'
foreach($p in @($module,$worker,$aliases,$optimizer,$modelMap)){if(-not(Test-Path -LiteralPath $p -PathType Leaf)){throw "Platform-model source is missing: $p"}}

foreach($ps in @($module,$optimizer)){
    $tokens=$null;$errors=$null
    [void][Management.Automation.Language.Parser]::ParseFile($ps,[ref]$tokens,[ref]$errors)
    if(@($errors).Count){throw "$ps failed Windows PowerShell 5.1 parse: $(@($errors|ForEach-Object{$_.Message}) -join '; ')"}
}

$moduleText=Get-Content -Raw -LiteralPath $module -Encoding UTF8
foreach($needle in @(
    'PlatformVisualStyle',"@('Icons','3D Models')",'HuymaierModelPreviewWorker.exe',
    "Join-Path `$script:DataDir 'Models'","Join-Path `$script:BaseDir 'Assets\Models'",
    'function New-PlatformCard','function Add-PlatformRail','function Get-PageDefinition',
    "'platform-visual-style'",'Request-HcModelPreview','Start-Process -FilePath $script:HcModelPreviewWorkerPath'
)){if(-not $moduleText.Contains($needle)){throw "Platform-model runtime contract missing: $needle"}}
if($moduleText -match '(?i)Remove-Item.+PS[123]|PlayStationPresentation'){throw 'Platform-model runtime must not mutate frozen PlayStation presentation.'}

$map=Get-Content -Raw -LiteralPath $modelMap -Encoding UTF8|ConvertFrom-Json
if([int]$map.schemaVersion -ne 1){throw '3D model map schema version must be 1.'}
$keys=@{};foreach($p in @($map.models.PSObject.Properties)){$keys[[string]$p.Name.ToLowerInvariant()]=[string]$p.Value}
foreach($provider in @('Steam','Epic','GOG','EA','Ubisoft','Xbox App','Battle.net','Rockstar','Amazon Games')){if(-not $keys.ContainsKey($provider.ToLowerInvariant())){throw "3D model map is missing provider: $provider"}}
$registry=Get-Content -Raw -LiteralPath (Join-Path $root 'EmulatorPlatforms\platform-registry.json') -Encoding UTF8|ConvertFrom-Json
foreach($platform in @($registry.platforms|Where-Object{[bool]$_.enabled})){
    $platformAliases=New-Object System.Collections.ArrayList
    foreach($value in @([string]$platform.name,[string]$platform.displayName,[string]$platform.menuName,[string]$platform.id)){if($value){[void]$platformAliases.Add($value)}}
    foreach($value in @($platform.aliases)){if($value){[void]$platformAliases.Add([string]$value)}}
    $covered=$false
    foreach($alias in @($platformAliases)){if($keys.ContainsKey(([string]$alias).ToLowerInvariant())){$covered=$true;break}}
    if(-not $covered){throw "3D model map has no alias for enabled platform $([string]$platform.id) / $([string]$platform.name)"}
}

function New-HcTinyGlb {
    param([string]$Path)
    $json='{"asset":{"version":"2.0"},"scene":0,"scenes":[{"nodes":[0]}],"nodes":[{"mesh":0}],"meshes":[{"primitives":[{"attributes":{"POSITION":0},"indices":1,"mode":4,"material":0}]}],"materials":[{"pbrMetallicRoughness":{"baseColorFactor":[0.84,0.55,0.18,1],"metallicFactor":0.15,"roughnessFactor":0.55}}],"buffers":[{"byteLength":44}],"bufferViews":[{"buffer":0,"byteOffset":0,"byteLength":36},{"buffer":0,"byteOffset":36,"byteLength":6}],"accessors":[{"bufferView":0,"componentType":5126,"count":3,"type":"VEC3","min":[-0.8,-0.6,0],"max":[0.8,0.8,0]},{"bufferView":1,"componentType":5123,"count":3,"type":"SCALAR","min":[0],"max":[2]}]}'
    $jsonBytes=[Text.Encoding]::UTF8.GetBytes($json)
    $jsonPad=(4-($jsonBytes.Length%4))%4
    $jsonChunk=New-Object byte[] ($jsonBytes.Length+$jsonPad);[Array]::Copy($jsonBytes,$jsonChunk,$jsonBytes.Length);for($i=$jsonBytes.Length;$i-lt$jsonChunk.Length;$i++){$jsonChunk[$i]=0x20}
    $binStream=New-Object IO.MemoryStream;$bw=New-Object IO.BinaryWriter($binStream)
    foreach($f in @([single]-0.8,[single]-0.6,[single]0,[single]0.8,[single]-0.6,[single]0,[single]0,[single]0.8,[single]0)){$bw.Write($f)}
    foreach($ix in @([uint16]0,[uint16]1,[uint16]2)){$bw.Write($ix)};$bw.Write([uint16]0);$bw.Flush();$bin=$binStream.ToArray();$bw.Dispose();$binStream.Dispose()
    $total=12+8+$jsonChunk.Length+8+$bin.Length
    $fs=[IO.File]::Create($Path);$out=New-Object IO.BinaryWriter($fs)
    try{$out.Write([byte[]](0x67,0x6C,0x54,0x46));$out.Write([uint32]2);$out.Write([uint32]$total);$out.Write([uint32]$jsonChunk.Length);$out.Write([uint32]0x4E4F534A);$out.Write($jsonChunk);$out.Write([uint32]$bin.Length);$out.Write([uint32]0x004E4942);$out.Write($bin)}finally{$out.Dispose();$fs.Dispose()}
}

Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase,System.Xaml,System.Web.Extensions
$csc=Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
if(-not(Test-Path -LiteralPath $csc -PathType Leaf)){throw 'Framework64 csc.exe was not found.'}
$tempRoot=$(if($env:RUNNER_TEMP){$env:RUNNER_TEMP}else{[IO.Path]::GetTempPath()})
$temp=Join-Path $tempRoot ('hc-model-test-'+[guid]::NewGuid().ToString('N'));New-Item -ItemType Directory -Force -Path $temp|Out-Null
try{
    $exe=Join-Path $temp 'HuymaierModelPreviewWorker.exe'
    $refs=@([Uri].Assembly.Location,[Linq.Enumerable].Assembly.Location,[Web.Script.Serialization.JavaScriptSerializer].Assembly.Location,[Windows.DependencyObject].Assembly.Location,[Windows.Media.Visual].Assembly.Location,[Windows.Window].Assembly.Location,[System.Xaml.XamlReader].Assembly.Location)|Select-Object -Unique
    $args=@('/noconfig','/nologo','/target:winexe','/platform:x64','/optimize+',('/out:'+$exe));foreach($r in $refs){$args+=('/reference:'+$r)};$args+=@($worker,$aliases)
    & $csc @args
    if($LASTEXITCODE -ne 0 -or -not(Test-Path -LiteralPath $exe -PathType Leaf)){throw 'Platform-model preview worker x64 compile failed.'}
    $bytes=[IO.File]::ReadAllBytes($exe);$pe=[BitConverter]::ToInt32($bytes,0x3C);$machine=[BitConverter]::ToUInt16($bytes,$pe+4);if($machine-ne0x8664){throw 'Platform-model preview worker is not x64.'}

    $tiny=Join-Path $temp 'tiny.glb';$png=Join-Path $temp 'tiny.png';New-HcTinyGlb $tiny
    $proc=Start-Process -FilePath $exe -ArgumentList ('--model "'+$tiny+'" --output "'+$png+'" --size 128 --yaw 24 --pitch -12') -Wait -PassThru
    if($proc.ExitCode -ne 0){throw "Platform-model preview worker smoke render failed with exit $($proc.ExitCode)."}
    if(-not(Test-Path -LiteralPath $png -PathType Leaf)){throw 'Platform-model preview worker did not produce PNG output.'}
    $pngBytes=[IO.File]::ReadAllBytes($png);if($pngBytes.Length-lt500 -or $pngBytes[0]-ne0x89 -or $pngBytes[1]-ne0x50 -or $pngBytes[2]-ne0x4E -or $pngBytes[3]-ne0x47){throw 'Platform-model preview worker output is not a valid PNG.'}
}finally{Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue}

Write-Host 'platformModelSettingGate: success'
Write-Host 'platformModelMapCoverageGate: success'
Write-Host 'platformModelBackgroundWorkerGate: success'
Write-Host 'platformModelWorkerX64Gate: success'
Write-Host 'platformModelGlbRenderSmokeGate: success'
