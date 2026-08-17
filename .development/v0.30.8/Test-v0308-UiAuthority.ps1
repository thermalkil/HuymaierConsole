param(
    [Parameter(Mandatory=$true)][string]$StageRoot
)
Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'

$corePath=Join-Path $StageRoot 'HuymaierConsole.ps1'
$shellPath=Join-Path $StageRoot 'HuymaierShellRedesign.ps1'
foreach($path in @($corePath,$shellPath)){
    if(-not(Test-Path -LiteralPath $path -PathType Leaf)){throw "Missing UI authority source: $path"}
    $tokens=$null;$errors=$null
    [void][Management.Automation.Language.Parser]::ParseFile($path,[ref]$tokens,[ref]$errors)
    if($errors.Count){$errors|ForEach-Object{Write-Host ("{0}:{1}:{2} {3}" -f $path,$_.Extent.StartLineNumber,$_.Extent.StartColumnNumber,$_.Message)};throw "$path failed Windows PowerShell parsing."}
}

$core=Get-Content -Raw -LiteralPath $corePath -Encoding UTF8
$shell=Get-Content -Raw -LiteralPath $shellPath -Encoding UTF8

if(-not $core.Contains('HUYMAIER_V0308_UI_AUTHORITY_CLEANUP_V1')){throw 'Core UI authority cleanup marker is missing.'}
$forbiddenCore=@(
    "if(`$script:SubPage -eq 'Artwork')",
    "`$script:SubPage='Artwork'",
    "New-Action 'artwork-settings'",
    "New-Action 'steamgriddb-key'",
    "New-Action 'online-artwork-toggle'",
    "New-Action 'artwork-refresh' 'Refresh missing box art'"
)
foreach($needle in $forbiddenCore){if($core.Contains($needle)){throw "Dead legacy artwork presentation still exists in HuymaierConsole.ps1: $needle"}}

$requiredCoreHandlers=@(
    "'steamgriddb-key' {",
    "'thegamesdb-key' {",
    "'online-artwork-toggle' {",
    "'artwork-refresh' {"
)
foreach($needle in $requiredCoreHandlers){if(-not $core.Contains($needle)){throw "Core artwork behavior handler was removed during presentation cleanup: $needle"}}

$start=$shell.IndexOf("if(`$script:SubPage -eq 'ConsoleSettings')")
if($start -lt 0){throw 'Active ConsoleSettings page was not found in HuymaierShellRedesign.ps1.'}
$end=$shell.IndexOf("if(`$script:SubPage -eq 'UpdatesHub')",$start)
if($end -lt 0){throw 'ConsoleSettings page boundary was not found.'}
$block=$shell.Substring($start,$end-$start)
if(-not $block.Contains('HUYMAIER_V0308_SHELL_ARTWORK_UI_V2')){throw 'Active shell artwork authority marker is missing.'}

$uiNeedles=@(
    "New-Action 'thegamesdb-key'",
    "New-Action 'steamgriddb-key'",
    "New-Action 'online-artwork-toggle'",
    "New-Action 'artwork-refresh' 'Refresh missing box art'",
    "New-Action 'artwork-retry-unresolved' 'Retry unresolved cover art'",
    "New-Action 'artwork-refresh-platform' 'Refresh current platform cover art'",
    "New-Action 'artwork-open-cache' 'Open artwork cache & mappings'"
)
foreach($needle in $uiNeedles){
    $count=([regex]::Matches($block,[regex]::Escape($needle))).Count
    if($count -ne 1){throw "Active ConsoleSettings must contain exactly one '$needle' entry; found $count."}
}

$positions=@{}
foreach($needle in $uiNeedles){$positions[$needle]=$block.IndexOf($needle)}
for($i=1;$i -lt $uiNeedles.Count;$i++){
    if($positions[$uiNeedles[$i-1]] -ge $positions[$uiNeedles[$i]]){throw 'Artwork settings order drifted from TGDB -> SGDB -> online -> refresh -> retry -> platform -> cache.'}
}

Write-Host 'v0.30.8 UI authority validation passed: Settings presentation has one owner and dead artwork UI is removed.'
