Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
$root=(Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$registry=Get-Content -Raw -LiteralPath (Join-Path $root 'EmulatorPlatforms\platform-registry.json') -Encoding UTF8|ConvertFrom-Json
$bad=New-Object System.Collections.ArrayList
foreach($p in @($registry.platforms|Sort-Object {[int]$_.sortOrder},id)){
    if($null-eq$p){continue}
    $id=[string]$p.id;$name=[string]$p.name;$display=[string]$p.displayName;$menu=[string]$p.menuName
    Write-Host ("PLATFORM_NAME`t{0}`tname={1}`tdisplay={2}`tmenu={3}" -f $id,$name,$display,$menu)
    if([string]::IsNullOrWhiteSpace($name)){[void]$bad.Add("$id => blank name")}
    if([string]::IsNullOrWhiteSpace($display)){[void]$bad.Add("$id => blank displayName")}
    if([string]::IsNullOrWhiteSpace($menu)){[void]$bad.Add("$id => blank menuName");continue}
    if($menu -match '^\d+$'){[void]$bad.Add("$id => numeric-only menuName '$menu'")}
    if($menu -in @('CD')){[void]$bad.Add("$id => generic/truncated menuName '$menu'")}
}
if($bad.Count){$bad|ForEach-Object{Write-Host ('NAMING_PROBLEM '+$_)};throw "Platform naming audit found $($bad.Count) definite naming problems."}
Write-Host 'platformNamingAuditGate: success'
