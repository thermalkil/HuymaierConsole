param(
    [Parameter(Mandatory=$true)][string]$StageRoot
)
Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'

$shellPath=Join-Path $StageRoot 'HuymaierShellRedesign.ps1'
if(-not(Test-Path -LiteralPath $shellPath -PathType Leaf)){throw "Missing shell redesign source: $shellPath"}

$tokens=$null;$errors=$null
[void][Management.Automation.Language.Parser]::ParseFile($shellPath,[ref]$tokens,[ref]$errors)
if($errors.Count){$errors|ForEach-Object{Write-Host ("{0}:{1}:{2} {3}" -f $shellPath,$_.Extent.StartLineNumber,$_.Extent.StartColumnNumber,$_.Message)};throw 'HuymaierShellRedesign.ps1 failed Windows PowerShell parsing.'}

$text=Get-Content -Raw -LiteralPath $shellPath -Encoding UTF8
$start=$text.IndexOf("if(`$script:SubPage -eq 'ConsoleSettings')")
if($start -lt 0){throw 'Active ConsoleSettings page was not found in HuymaierShellRedesign.ps1.'}
$end=$text.IndexOf("if(`$script:SubPage -eq 'UpdatesHub')",$start)
if($end -lt 0){throw 'ConsoleSettings page boundary was not found.'}
$block=$text.Substring($start,$end-$start)

$required=@(
    'HUYMAIER_V0308_SHELL_ARTWORK_UI_V1',
    "New-Action 'thegamesdb-key'",
    "New-Action 'artwork-refresh' 'Refresh missing box art'",
    "New-Action 'artwork-retry-unresolved' 'Retry unresolved cover art'",
    "New-Action 'artwork-refresh-platform' 'Refresh current platform cover art'",
    "New-Action 'artwork-open-cache' 'Open artwork cache & mappings'"
)
foreach($needle in $required){if(-not $block.Contains($needle)){throw "Active ConsoleSettings page is missing: $needle"}}

$refreshPos=$block.IndexOf("New-Action 'artwork-refresh' 'Refresh missing box art'")
$keyPos=$block.IndexOf("New-Action 'thegamesdb-key'")
$retryPos=$block.IndexOf("New-Action 'artwork-retry-unresolved'")
if($keyPos -lt 0 -or $refreshPos -lt 0 -or $retryPos -lt 0 -or -not($keyPos -lt $refreshPos -and $refreshPos -lt $retryPos)){throw 'Artwork settings controls are not ordered key -> refresh -> retry.'}

Write-Host 'v0.30.8 active shell artwork UI validation passed.'
