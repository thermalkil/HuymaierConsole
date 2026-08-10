param(
    [ValidateSet('Scan','Download')][string]$Action='Scan',
    [Parameter(Mandatory=$true)][string]$StatePath,
    [string]$CurrentVersion='0.26.1',
    [string]$Repository='thermalkil/HuymaierConsole'
)
Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12

$updateRoot=Join-Path $env:LOCALAPPDATA 'Huymaier Console\Updates'
New-Item -ItemType Directory -Force -Path $updateRoot|Out-Null
$partialPath=''
$sidecarPath=''

function Write-State {
    param(
        [string]$Phase,[string]$Message,[bool]$Busy,
        [string]$LatestVersion='', [bool]$UpdateAvailable=$false,
        [string]$AssetName='', [string]$AssetUrl='', [string]$AssetApiUrl='', [long]$AssetSize=0,
        [string]$ReleaseUrl='', [string]$ReleaseNotes='', [string]$PublishedAt='',
        [long]$DownloadedBytes=0,[long]$TotalBytes=0,[double]$Percent=0,
        [string]$LocalPath='',[string]$Sha256='',[string]$Error=''
    )
    $state=[ordered]@{
        Phase=$Phase;Message=$Message;Busy=$Busy;Repository=$Repository;CurrentVersion=$CurrentVersion
        LatestVersion=$LatestVersion;UpdateAvailable=$UpdateAvailable;AssetName=$AssetName;AssetUrl=$AssetUrl
        AssetApiUrl=$AssetApiUrl;AssetSize=$AssetSize;ReleaseUrl=$ReleaseUrl;ReleaseNotes=$ReleaseNotes
        PublishedAt=$PublishedAt;DownloadedBytes=$DownloadedBytes;TotalBytes=$TotalBytes;Percent=$Percent
        LocalPath=$LocalPath;Sha256=$Sha256;Error=$Error;UpdatedAt=[DateTime]::UtcNow.ToString('o')
    }
    $parent=Split-Path -Parent $StatePath;if($parent){New-Item -ItemType Directory -Force -Path $parent|Out-Null}
    $tmp=$StatePath+'.tmp'
    $state|ConvertTo-Json -Depth 6|Set-Content -LiteralPath $tmp -Encoding UTF8
    Move-Item -LiteralPath $tmp -Destination $StatePath -Force
}

function Get-Token {
    foreach($name in @('GH_TOKEN','GITHUB_TOKEN')){
        $value=[Environment]::GetEnvironmentVariable($name)
        if(-not [string]::IsNullOrWhiteSpace($value)){return $value.Trim()}
    }
    try{
        $gh=Get-Command gh.exe -ErrorAction SilentlyContinue;if($null -eq $gh){$gh=Get-Command gh -ErrorAction SilentlyContinue}
        if($null -ne $gh){$token=(& $gh.Source auth token 2>$null|Select-Object -First 1);if($LASTEXITCODE -eq 0 -and $token){return ([string]$token).Trim()}}
    }catch{}
    return ''
}

function Get-Headers {
    param([string]$Token,[string]$Accept='application/vnd.github+json')
    $headers=@{'User-Agent'='HuymaierConsole/0.26.1';'Accept'=$Accept;'X-GitHub-Api-Version'='2022-11-28'}
    if($Token){$headers['Authorization']='Bearer '+$Token}
    return $headers
}

function Parse-Version([string]$Text){
    $clean=([string]$Text).Trim();if($clean.StartsWith('v',[StringComparison]::OrdinalIgnoreCase)){$clean=$clean.Substring(1)}
    $match=[regex]::Match($clean,'^\d+(?:\.\d+){1,3}')
    if(-not $match.Success){return [version]'0.0'}
    try{return [version]$match.Value}catch{return [version]'0.0'}
}

function Get-LatestRelease([string]$Token){
    $uri='https://api.github.com/repos/'+$Repository+'/releases/latest'
    try{return Invoke-RestMethod -UseBasicParsing -Uri $uri -Headers (Get-Headers -Token $Token) -Method Get -TimeoutSec 30}
    catch{
        $code='';try{$code=[int]$_.Exception.Response.StatusCode}catch{}
        if($code -eq 404){throw 'No published Huymaier Console GitHub Release was found.'}
        throw
    }
}

function Select-PackageAsset($Release){
    $assets=@($Release.assets)
    $preferred=@($assets|Where-Object{[string]$_.name -match '(?i)^(HC|HuymaierConsole).+\.zip$'}|Sort-Object {[long]$_.size} -Descending)
    if($preferred.Count -gt 0){return $preferred[0]}
    $fallback=@($assets|Where-Object{[string]$_.name -match '(?i)\.zip$'}|Sort-Object {[long]$_.size} -Descending)
    if($fallback.Count -gt 0){return $fallback[0]}
    return $null
}

function Find-SidecarAsset($Release,$PackageAsset){
    if($null -eq $PackageAsset){return $null}
    $wanted=[string]$PackageAsset.name+'.sha256'
    foreach($asset in @($Release.assets)){if([string]::Equals([string]$asset.name,$wanted,[StringComparison]::OrdinalIgnoreCase)){return $asset}}
    return $null
}

function Download-SmallAsset {
    param($Asset,[string]$Destination,[string]$Token)
    $uri=if($Token -and [string]$Asset.url){[string]$Asset.url}else{[string]$Asset.browser_download_url}
    $accept=if($Token){'application/octet-stream'}else{'application/vnd.github+json'}
    Invoke-WebRequest -UseBasicParsing -Uri $uri -Headers (Get-Headers -Token $Token -Accept $accept) -OutFile $Destination -TimeoutSec 30
}

try{
    Write-State 'Scanning' 'Checking GitHub Releases for a newer Huymaier Console build...' $true
    $token=Get-Token
    $release=Get-LatestRelease -Token $token
    $latestText=([string]$release.tag_name).Trim();if(-not $latestText){$latestText=([string]$release.name).Trim()}
    $latestVersionText=$latestText.TrimStart('v','V')
    $current=Parse-Version $CurrentVersion
    $latest=Parse-Version $latestVersionText
    $asset=Select-PackageAsset $release
    $sidecar=Find-SidecarAsset -Release $release -PackageAsset $asset

    if($null -eq $asset){
        Write-State 'Ready' "GitHub Release $latestVersionText exists but has no installable ZIP asset." $false $latestVersionText ($latest -gt $current) '' '' '' 0 ([string]$release.html_url) ([string]$release.body) ([string]$release.published_at)
        exit 0
    }

    $available=$latest -gt $current
    $hasSidecar=$null -ne $sidecar
    if($Action -eq 'Scan'){
        $message=if(-not $available){"Huymaier Console is up to date ($CurrentVersion)."}elseif(-not $hasSidecar){"Huymaier Console $latestVersionText exists, but its required SHA-256 verification asset is missing."}else{"Huymaier Console $latestVersionText is available and has a published integrity hash."}
        Write-State 'Ready' $message $false $latestVersionText $available ([string]$asset.name) ([string]$asset.browser_download_url) ([string]$asset.url) ([long]$asset.size) ([string]$release.html_url) ([string]$release.body) ([string]$release.published_at)
        exit 0
    }

    if(-not $available){
        Write-State 'Ready' "Huymaier Console is already up to date ($CurrentVersion)." $false $latestVersionText $false ([string]$asset.name) ([string]$asset.browser_download_url) ([string]$asset.url) ([long]$asset.size) ([string]$release.html_url) ([string]$release.body) ([string]$release.published_at)
        exit 0
    }
    if(-not $hasSidecar){throw "Release $latestVersionText is missing $([string]$asset.name).sha256; safe update download is blocked."}

    $safeName=[IO.Path]::GetFileName([string]$asset.name)
    if([string]::IsNullOrWhiteSpace($safeName)){throw 'Release ZIP has an invalid asset name.'}
    $target=Join-Path $updateRoot $safeName
    $partialPath=$target+'.partial'
    $sidecarPath=$target+'.sha256'
    Remove-Item -LiteralPath $partialPath,$sidecarPath -Force -ErrorAction SilentlyContinue

    Add-Type -AssemblyName System.Net.Http
    $handler=New-Object System.Net.Http.HttpClientHandler
    $handler.AllowAutoRedirect=$true
    $client=New-Object System.Net.Http.HttpClient($handler)
    $client.DefaultRequestHeaders.UserAgent.ParseAdd('HuymaierConsole/0.26.1')
    if($token){$client.DefaultRequestHeaders.Authorization=New-Object System.Net.Http.Headers.AuthenticationHeaderValue('Bearer',$token);$client.DefaultRequestHeaders.Accept.Clear();$client.DefaultRequestHeaders.Accept.Add((New-Object System.Net.Http.Headers.MediaTypeWithQualityHeaderValue('application/octet-stream')))}
    $downloadUri=if($token -and [string]$asset.url){[string]$asset.url}else{[string]$asset.browser_download_url}
    $response=$client.GetAsync($downloadUri,[System.Net.Http.HttpCompletionOption]::ResponseHeadersRead).GetAwaiter().GetResult()
    $response.EnsureSuccessStatusCode()
    $stream=$response.Content.ReadAsStreamAsync().GetAwaiter().GetResult()
    $file=[IO.File]::Open($partialPath,[IO.FileMode]::Create,[IO.FileAccess]::Write,[IO.FileShare]::None)
    try{
        $total=[long]$asset.size
        $contentLength=$response.Content.Headers.ContentLength
        if($null -ne $contentLength -and [long]$contentLength -gt 0){$total=[long]$contentLength}
        $buffer=New-Object byte[] (1024*1024)
        $done=[long]0
        $last=[DateTime]::MinValue
        while(($read=$stream.Read($buffer,0,$buffer.Length)) -gt 0){
            $file.Write($buffer,0,$read);$done+=$read
            if(((Get-Date)-$last).TotalMilliseconds -ge 350){
                $percent=if($total -gt 0){[math]::Min(100,[math]::Round(($done*100.0)/$total,1))}else{0}
                Write-State 'Downloading' "Downloading Huymaier Console $latestVersionText..." $true $latestVersionText $true ([string]$asset.name) ([string]$asset.browser_download_url) ([string]$asset.url) ([long]$asset.size) ([string]$release.html_url) ([string]$release.body) ([string]$release.published_at) $done $total $percent $partialPath
                $last=Get-Date
            }
        }
    }finally{$file.Dispose();$stream.Dispose();$response.Dispose();$client.Dispose();$handler.Dispose()}
    Move-Item -LiteralPath $partialPath -Destination $target -Force
    $partialPath=''

    Download-SmallAsset -Asset $sidecar -Destination $sidecarPath -Token $token
    $sidecarLine=Get-Content -LiteralPath $sidecarPath -Encoding ASCII|Select-Object -First 1
    if($sidecarLine -notmatch '^([0-9a-fA-F]{64})(?:\s+.+)?$'){throw 'Published SHA-256 sidecar has an invalid format.'}
    $publishedHash=$Matches[1].ToLowerInvariant()
    $localHash=(Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash.ToLowerInvariant()
    if($localHash -ne $publishedHash){throw 'Downloaded update ZIP does not match the SHA-256 published with the GitHub Release.'}

    $size=(Get-Item -LiteralPath $target).Length
    Write-State 'Downloaded' "Huymaier Console $latestVersionText is downloaded, release-verified, and ready to install." $false $latestVersionText $true ([string]$asset.name) ([string]$asset.browser_download_url) ([string]$asset.url) ([long]$asset.size) ([string]$release.html_url) ([string]$release.body) ([string]$release.published_at) $size $size 100 $target $publishedHash
}catch{
    if($partialPath){Remove-Item -LiteralPath $partialPath -Force -ErrorAction SilentlyContinue}
    if($sidecarPath -and -not(Test-Path -LiteralPath ($sidecarPath.Substring(0,$sidecarPath.Length-7)) -PathType Leaf)){Remove-Item -LiteralPath $sidecarPath -Force -ErrorAction SilentlyContinue}
    Write-State 'Error' 'Huymaier Console update check/download could not complete safely.' $false '' $false '' '' '' 0 '' '' '' 0 0 0 '' '' ([string]$_.Exception.Message)
    exit 1
}
