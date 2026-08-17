param([string]$RepoRoot=(Split-Path -Parent (Split-Path -Parent $PSScriptRoot)))
Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
$user=Get-Content -Raw -LiteralPath (Join-Path $RepoRoot 'HuymaierUser3DModels.ps1') -Encoding UTF8
$host=Get-Content -Raw -LiteralPath (Join-Path $RepoRoot 'Native\HuymaierD3D11ShelfHost.cs') -Encoding UTF8

foreach($token in @(
  'HUYMAIER_V0301_BRIGHTNESS_0_200_AND_FAN_MOTION_V1',
  '[math]::Max(0,[math]::Min(200,[int]$script:Config.PlatformModelBrightness))',
  "'3D model brightness' ([int]`$script:Config.PlatformModelBrightness) 'Adjust lighting for both the Games 3D shelves and the full-screen model viewer.' 0 200",
  '[math]::Max(0,[math]::Min(200,([int]$script:Config.PlatformModelBrightness)+$Delta))'
)){if(-not$user.Contains($token)){throw "Missing 0-200 brightness contract: $token"}}
if($user -match "platform-model-brightness-slider'.*50 250"){throw 'Legacy 50-250 brightness range remains active.'}

foreach($token in @(
  'HUYMAIER_D3D11_SHELF_HOST_V3_BOUNDED_FAN_MOTION',
  'FanPeriodSeconds = 8.0',
  'FanPhaseAmplitude = 0.75f',
  '-FanPhaseAmplitude * (float)Math.Sin',
  'Math.Max(0.0, Math.Min(200.0, percent))'
)){if(-not$host.Contains($token)){throw "Missing bounded fan/native brightness contract: $token"}}
if($host.Contains('float phase = (float)renderClock.Elapsed.TotalSeconds;')){throw 'Legacy unbounded phase still drives continuous turntable rotation.'}
Write-Host 'platformModelBrightness0To200Gate: success'
Write-Host 'platformModelBoundedFanMotionGate: success'
