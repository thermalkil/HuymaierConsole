param()
Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'

$root=Split-Path -Parent $PSScriptRoot
$corePath=Join-Path $root 'HuymaierConsole.ps1'
if(-not(Test-Path -LiteralPath $corePath -PathType Leaf)){throw "Core source missing: $corePath"}

function Read-HcText([string]$Path){return [IO.File]::ReadAllText($Path,[Text.Encoding]::UTF8).Replace("`r`n","`n")}
function Write-HcText([string]$Path,[string]$Text){[IO.File]::WriteAllText($Path,$Text.Replace("`n","`r`n"),(New-Object Text.UTF8Encoding($true)))}
function Remove-HcBlockByMarker([string]$Text,[string]$Marker){
    $start=$Text.IndexOf($Marker,[StringComparison]::Ordinal)
    if($start -lt 0){throw "UI authority cleanup marker not found: $Marker"}
    $open=$Text.IndexOf('{',$start)
    if($open -lt 0){throw "Opening brace not found for: $Marker"}
    $depth=0;$end=-1
    for($i=$open;$i -lt $Text.Length;$i++){
        $ch=$Text[$i]
        if($ch -eq '{'){$depth++}
        elseif($ch -eq '}'){$depth--;if($depth -eq 0){$end=$i+1;break}}
    }
    if($end -lt 0){throw "Closing brace not found for: $Marker"}
    while($end -lt $Text.Length -and ($Text[$end] -eq "`r" -or $Text[$end] -eq "`n")){$end++}
    return $Text.Remove($start,$end-$start)
}

$text=Read-HcText $corePath
if($text -notmatch 'HUYMAIER_V0308_UI_AUTHORITY_CLEANUP_V1'){
    # The redesigned shell owns Settings presentation. Remove the unreachable
    # legacy Artwork subpage so future feature work cannot accidentally patch a
    # dead UI model and pass validation while the active shell remains stale.
    $legacySubPage="            if(`$script:SubPage -eq 'Artwork'){"
    $text=Remove-HcBlockByMarker $text $legacySubPage

    $legacyHandler="        'artwork-settings' { `$script:SubPage='Artwork';`$script:SelectedAction=0;Render-Page }`n"
    if(-not $text.Contains($legacyHandler)){throw 'Legacy artwork-settings handler anchor missing.'}
    $text=$text.Replace($legacyHandler,'')

    $legacyActions=@(
        ",(New-Action 'artwork-settings' 'Artwork & Metadata' 'SteamGridDB key, provider artwork, online artwork, cache refresh and platform backgrounds.')",
        ",(New-Action 'steamgriddb-key' `$(if([string]::IsNullOrWhiteSpace([string]`$script:Config.SteamGridDbApiKey)){'SteamGridDB artwork key: Not configured'}else{'SteamGridDB artwork key: Configured'}) 'Optional personal SteamGridDB API key. Steam uses AppID matching; other PC storefronts use title matching.')",
        ",(New-Action 'online-artwork-toggle' `$(if(`$script:Config.OnlineArtworkEnabled){'Online box art: On'}else{'Online box art: Off'}))",
        ",(New-Action 'artwork-refresh' 'Refresh missing box art')"
    )
    foreach($legacy in $legacyActions){
        if(-not $text.Contains($legacy)){throw "Legacy core settings action anchor missing: $legacy"}
        $text=$text.Replace($legacy,'')
    }

    $anchor='$script:AppName = ''Huymaier Console'''
    if(-not $text.Contains($anchor)){throw 'Core authority marker anchor missing.'}
    $text=$text.Replace($anchor,"# HUYMAIER_V0308_UI_AUTHORITY_CLEANUP_V1 - HuymaierShellRedesign owns Settings presentation`n$anchor")
    Write-HcText $corePath $text
}

Write-Host 'v0.30.8 UI authority cleanup removed dead legacy artwork settings presentation from the core shell.'
