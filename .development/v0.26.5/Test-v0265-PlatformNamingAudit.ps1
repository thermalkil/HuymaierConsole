Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
$root=(Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$registryPath=Join-Path $root 'EmulatorPlatforms\platform-registry.json'
$registry=Get-Content -Raw -LiteralPath $registryPath -Encoding UTF8|ConvertFrom-Json
$bad=New-Object System.Collections.ArrayList
foreach($p in @($registry.platforms)){
    if($null-eq$p){continue}
    $id=[string]$p.id;$name=[string]$p.name;$display=[string]$p.displayName;$menu=[string]$p.menuName
    if([string]::IsNullOrWhiteSpace($menu)){[void]$bad.Add("$id => blank menuName");continue}
    if($menu -match '^\d+$'){[void]$bad.Add("$id => numeric-only menuName '$menu'")}
    if($menu.Length -le 2 -and $name.Length -gt 3 -and $menu -notin @('DS','3DS','GB')){[void]$bad.Add("$id => suspiciously short menuName '$menu' (name '$name')")}
    if($display -and $name -and $display.Length -gt 3 -and $menu.Length -lt [math]::Min(3,[math]::Floor($display.Length/3))){[void]$bad.Add("$id => truncated menuName '$menu' (display '$display')")}
}
if($bad.Count){$bad|ForEach-Object{Write-Host $_};throw "Platform naming audit found $($bad.Count) suspicious menu names."}
Write-Host 'platformNamingAuditGate: success'
