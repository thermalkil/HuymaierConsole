param(
    [Parameter(Mandatory=$true)][string]$CoordinatorPath
)
Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
if(-not(Test-Path -LiteralPath $CoordinatorPath -PathType Leaf)){throw "Epic coordinator optimizer could not find $CoordinatorPath"}
$text=[IO.File]::ReadAllText($CoordinatorPath,[Text.Encoding]::UTF8)
$old="`$provider -in @('GOG','Amazon')"
$new="`$provider -in @('Epic','GOG','Amazon')"
$matches=[regex]::Matches($text,[regex]::Escape($old))
if($matches.Count -ne 1){throw "Epic coordinator optimizer expected one activation filter but found $($matches.Count)."}
$text=$text.Replace($old,$new)
$bom=New-Object Text.UTF8Encoding($true)
[IO.File]::WriteAllText($CoordinatorPath,$text,$bom)
Write-Host 'Enabled Epic fallback coordinator activation.'