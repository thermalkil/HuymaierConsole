param()
Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'

$root=Split-Path -Parent $PSScriptRoot
$shellPath=Join-Path $root 'HuymaierShellRedesign.ps1'
if(-not(Test-Path -LiteralPath $shellPath -PathType Leaf)){throw "Shell redesign source missing: $shellPath"}

$text=[IO.File]::ReadAllText($shellPath,[Text.Encoding]::UTF8).Replace("`r`n","`n")
if($text -notmatch 'HUYMAIER_V0308_SHELL_ARTWORK_UI_V2'){
    $anchor=@(
        '                (New-Action ''online-artwork-toggle'' $(if($script:Config.OnlineArtworkEnabled){''Online box art: On''}else{''Online box art: Off''})),',
        '                (New-Action ''artwork-refresh'' ''Refresh missing box art''),'
    ) -join "`n"
    if(-not $text.Contains($anchor)){throw 'v0.30.8 shell artwork UI anchor missing.'}
    $replacement=@(
        '                # HUYMAIER_V0308_SHELL_ARTWORK_UI_V2 - active settings authority',
        '                (New-Action ''thegamesdb-key'' $(if([string]::IsNullOrWhiteSpace([string]$script:Config.TheGamesDbApiKey)){''TheGamesDB API key: Add personal key''}else{''TheGamesDB API key: Configured''}) ''Primary automated missing-cover source. The key is stored locally and used only for TheGamesDB API requests.''),',
        '                (New-Action ''steamgriddb-key'' $(if([string]::IsNullOrWhiteSpace([string]$script:Config.SteamGridDbApiKey)){''SteamGridDB API key: Add personal key''}else{''SteamGridDB API key: Configured''}) ''Optional PC/storefront fallback. The key is stored locally and used only for SteamGridDB API requests.''),',
        '                (New-Action ''online-artwork-toggle'' $(if($script:Config.OnlineArtworkEnabled){''Online box art: On''}else{''Online box art: Off''}) ''Provider/local artwork stays preferred; online sources are used only for missing artwork.''),',
        '                (New-Action ''artwork-refresh'' ''Refresh missing box art'' ''Rescans entries that still do not have usable artwork.''),',
        '                (New-Action ''artwork-retry-unresolved'' ''Retry unresolved cover art'' ''Clears failed-lookup backoff and retries missing covers.''),',
        '                (New-Action ''artwork-refresh-platform'' ''Refresh current platform cover art'' ''Runs the missing-art matcher only for the currently selected game platform.''),',
        '                (New-Action ''artwork-open-cache'' ''Open artwork cache & mappings'' ''Opens cached images, provenance data, failed lookups, and the optional The Cover Project mapping file.''),'
    ) -join "`n"
    $text=$text.Replace($anchor,$replacement)
    [IO.File]::WriteAllText($shellPath,$text.Replace("`n","`r`n"),(New-Object Text.UTF8Encoding($true)))
}

Write-Host 'v0.30.8 artwork controls consolidated into the active Console Settings page.'
