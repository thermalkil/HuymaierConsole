Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
$root=(Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$module=Join-Path $root 'HuymaierPlatformModels.ps1'
$worker=Join-Path $root 'Native\HuymaierModelPreviewWorker.cs'
$optimizer=Join-Path $root '.build\Optimize-Platform3DModels.ps1'
$modelMap=Join-Path $root 'Assets\Models\model-map.json'
foreach($p in @($module,$worker,$optimizer,$modelMap)){if(-not(Test-Path -LiteralPath $p -PathType Leaf)){throw "Platform-model source is missing: $p"}}

foreach($ps in @($module,$optimizer)){
    $tokens=$null;$errors=$null
    [void][Management.Automation.Language.Parser]::ParseFile($ps,[ref]$tokens,[ref]$errors)
    if(@($errors).Count){throw "$ps failed Windows PowerShell 5.1 parse: $(@($errors|ForEach-Object{$_.Message}) -join '; ')"}
}

$moduleText=Get-Content -Raw -LiteralPath $module -Encoding UTF8
foreach($needle in @(
    "PlatformVisualStyle",
    "@('Icons','3D Models')",
    "HuymaierModelPreviewWorker.exe",
    "Join-Path `$script:DataDir 'Models'",
    "Join-Path `$script:BaseDir 'Assets\Models'",
    "function New-PlatformCard",
    "function Add-PlatformRail",
    "function Get-PageDefinition",
    "'platform-visual-style'",
    "Request-HcModelPreview",
    "Start-Process -FilePath `$script:HcModelPreviewWorkerPath"
)){if(-not $moduleText.Contains($needle)){throw "Platform-model runtime contract missing: $needle"}}
if($moduleText -match '(?i)Remove-Item.+PS[123]|PlayStationPresentation'){throw 'Platform-model runtime must not mutate frozen PlayStation presentation.'}

$map=Get-Content -Raw -LiteralPath $modelMap -Encoding UTF8|ConvertFrom-Json
if([int]$map.schemaVersion -ne 1){throw '3D model map schema version must be 1.'}
$keys=@{};foreach($p in @($map.models.PSObject.Properties)){$keys[[string]$p.Name.ToLowerInvariant()]=[string]$p.Value}
foreach($provider in @('Steam','Epic','GOG','EA','Ubisoft','Xbox App','Battle.net','Rockstar','Amazon Games')){if(-not $keys.ContainsKey($provider.ToLowerInvariant())){throw "3D model map is missing provider: $provider"}}
$registry=Get-Content -Raw -LiteralPath (Join-Path $root 'EmulatorPlatforms\platform-registry.json') -Encoding UTF8|ConvertFrom-Json
foreach($platform in @($registry.platforms|Where-Object{[bool]$_.enabled})){
    $aliases=New-Object System.Collections.ArrayList
    foreach($value in @([string]$platform.name,[string]$platform.displayName,[string]$platform.menuName,[string]$platform.id)){if($value){[void]$aliases.Add($value)}}
    foreach($value in @($platform.aliases)){if($value){[void]$aliases.Add([string]$value)}}
    $covered=$false
    foreach($alias in @($aliases)){if($keys.ContainsKey(([string]$alias).ToLowerInvariant())){$covered=$true;break}}
    if(-not $covered){throw "3D model map has no alias for enabled platform $([string]$platform.id) / $([string]$platform.name)"}
}

Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase,System.Web.Extensions
$csc=Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
if(-not(Test-Path -LiteralPath $csc -PathType Leaf)){throw 'Framework64 csc.exe was not found.'}
$temp=Join-Path $env:RUNNER_TEMP ('hc-model-test-'+[guid]::NewGuid().ToString('N'));New-Item -ItemType Directory -Force -Path $temp|Out-Null
try{
    $exe=Join-Path $temp 'HuymaierModelPreviewWorker.exe'
    $refs=@([Uri].Assembly.Location,[Linq.Enumerable].Assembly.Location,[Web.Script.Serialization.JavaScriptSerializer].Assembly.Location,[Windows.DependencyObject].Assembly.Location,[Windows.Media.Visual].Assembly.Location,[Windows.Window].Assembly.Location)|Select-Object -Unique
    $args=@('/noconfig','/nologo','/target:winexe','/platform:x64','/optimize+',('/out:'+$exe));foreach($r in $refs){$args+=('/reference:'+$r)};$args+=$worker
    & $csc @args
    if($LASTEXITCODE -ne 0 -or -not(Test-Path -LiteralPath $exe -PathType Leaf)){throw 'Platform-model preview worker x64 compile failed.'}

    $tiny=Join-Path $temp 'tiny.glb';$png=Join-Path $temp 'tiny.png'
    [IO.File]::WriteAllBytes($tiny,[Convert]::FromBase64String('Z2xURgIAAACoBAAAnAMAAEpTT057InNjZW5lIjowLCJzY2VuZXMiOlt7Im5vZGVzIjpbMF19XSwiYXNzZXQiOnsidmVyc2lvbiI6IjIuMCIsImdlbmVyYXRvciI6Imh0dHBzOi8vZ2l0aHViLmNvbS9taWtlZGgvdHJpbWVzaCJ9LCJhY2Nlc3NvcnMiOlt7ImNvbXBvbmVudFR5cGUiOjUxMjUsInR5cGUiOiJTQ0FMQVIiLCJidWZmZXJWaWV3IjowLCJjb3VudCI6MzYsIm1heCI6WzddLCJtaW4iOlswXX0seyJjb21wb25lbnRUeXBlIjo1MTI2LCJ0eXBlIjoiVkVDMyIsImJ5dGVPZmZzZXQiOjAsImJ1ZmZlclZpZXciOjEsImNvdW50Ijo4LCJtYXgiOlswLjc1LDAuNSwwLjIwMDAwMDAwMjk4MDIzMjI0XSwibWluIjpbLTAuNzUsLTAuNSwtMC4yMDAwMDAwMDI5ODAyMzIyNF19XSwibWVzaGVzIjpbeyJuYW1lIjoiZ2VvbWV0cnlfMCIsImV4dHJhcyI6eyJzaGFwZSI6ImJveCIsImV4dGVudHMiOlsxLjUsMS4wLDAuNF19LCJwcmltaXRpdmVzIjpbeyJhdHRyaWJ1dGVzIjp7IlBPU0lUSU9OIjoxfSwiaW5kaWNlcyI6MCwibW9kZSI6NCwibWF0ZXJpYWwiOjB9XX1dLCJtYXRlcmlhbHMiOlt7InBick1ldGFsbGljUm91Z2huZXNzIjp7ImJhc2VDb2xvckZhY3RvciI6WzAuODYyNzQ1MDk4MDM5MjE1NywwLjM1Mjk0MTE3NjQ3MDU4ODI2LDAuMTU2ODYyNzQ1MDk4MDM5MiwxLjBdLCJyb3VnaG5lc3NGYWN0b3IiOjAuNTUsIm1ldGFsbGljRmFjdG9yIjowLjJ9LCJkb3VibGVTaWRlZCI6ZmFsc2V9XSwibm9kZXMiOlt7Im5hbWUiOiJ3b3JsZCIsImNoaWxkcmVuIjpbMV19LHsibmFtZSI6Imdlb21ldHJ5XzAiLCJtZXNoIjowfV0sImJ1ZmZlcnMiOlt7ImJ5dGVMZW5ndGgiOjI0MH1dLCJidWZmZXJWaWV3cyI6W3siYnVmZmVyIjowLCJieXRlT2Zmc2V0IjowLCJieXRlTGVuZ3RoIjoxNDR9LHsiYnVmZmVyIjowLCJieXRlT2Zmc2V0IjoxNDQsImJ5dGVMZW5ndGgiOjk2fV19ICDwAAAAQklOAAEAAAADAAAAAAAAAAQAAAABAAAAAAAAAAAAAAADAAAAAgAAAAIAAAAEAAAAAAAAAAEAAAAHAAAAAwAAAAUAAAABAAAABAAAAAUAAAAHAAAAAQAAAAMAAAAHAAAAAgAAAAYAAAAEAAAAAgAAAAIAAAAHAAAABgAAAAYAAAAFAAAABAAAAAcAAAAFAAAABgAAAAAAQL8AAAC/zcxMvgAAQL8AAAC/zcxMPgAAQL8AAAA/zcxMvgAAQL8AAAA/zcxMPgAAQD8AAAC/zcxMvgAAQD8AAAC/zcxMPgAAQD8AAAA/zcxMvgAAQD8AAAA/zcxMPg=='))
    $proc=Start-Process -FilePath $exe -ArgumentList ('--model "'+$tiny+'" --output "'+$png+'" --size 128 --yaw 24 --pitch -12') -Wait -PassThru
    if($proc.ExitCode -ne 0){throw "Platform-model preview worker smoke render failed with exit $($proc.ExitCode)."}
    if(-not(Test-Path -LiteralPath $png -PathType Leaf)){throw 'Platform-model preview worker did not produce PNG output.'}
    $bytes=[IO.File]::ReadAllBytes($png);if($bytes.Length -lt 500 -or $bytes[0] -ne 0x89 -or $bytes[1] -ne 0x50 -or $bytes[2] -ne 0x4E -or $bytes[3] -ne 0x47){throw 'Platform-model preview worker output is not a valid PNG.'}
}finally{Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue}

Write-Host 'platformModelSettingGate: success'
Write-Host 'platformModelMapCoverageGate: success'
Write-Host 'platformModelBackgroundWorkerGate: success'
Write-Host 'platformModelGlbRenderSmokeGate: success'
