param(
    [Parameter(Mandatory=$true)][string]$BootstrapPath
)
Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
if(-not(Test-Path -LiteralPath $BootstrapPath -PathType Leaf)){throw "Epic telemetry watch optimizer could not find $BootstrapPath"}
$text=[IO.File]::ReadAllText($BootstrapPath,[Text.Encoding]::UTF8)
$old="`$provider -notin @('GOG','Amazon')"
$new="`$provider -notin @('Epic','GOG','Amazon')"
$matches=[regex]::Matches($text,[regex]::Escape($old))
if($matches.Count -ne 1){throw "Epic telemetry watch optimizer expected one provider filter but found $($matches.Count)."}
$text=$text.Replace($old,$new)
$bom=New-Object Text.UTF8Encoding($true)
[IO.File]::WriteAllText($BootstrapPath,$text,$bom)
Write-Host 'Enabled event-driven Epic transfer fallback without adding a normal-boot worker process.'