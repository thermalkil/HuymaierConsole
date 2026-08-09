param(
    [ValidateSet('Scan','Download')][string]$Action='Scan',
    [Parameter(Mandatory=$true)][string]$StatePath,
    [string]$CurrentVersion='0.26.0',
    [string]$Repository='thermalkil/HuymaierConsole'
)
Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12
$updateRoot=Join-Path $env:LOCALAPPDATA 'Huymaier Console\Updates'
New-Item -ItemType Directory -Force -Path $updateRoot|Out-Null

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
        Phase=$Phase;Message=$Message;Busy=$Busy;Repository=$Repository;CurrentVersion=$CurrentVersion;
        LatestVersion=$LatestVersion;UpdateAvailable=$UpdateAvailable;AssetName=$AssetName;AssetUrl=$AssetUrl;
        AssetApiUrl=$AssetApiUrl;AssetSize=$AssetSize;ReleaseUrl=$ReleaseUrl;ReleaseNotes=$ReleaseNotes;
        PublishedAt=$PublishedAt;DownloadedBytes=$DownloadedBytes;TotalBytes=$TotalBytes;Percent=$Percent;
        LocalPath=$LocalPath;Sha256=$Sha256;Error=$Error;UpdatedAt=[DateTime]::UtcNow.ToString('o')
    }
    $tmp=$StatePath+'.tmp'
    $state|ConvertTo-Json -Depth 6|Set-Content -LiteralPath $tmp -Encoding UTF8
    Move-Item -LiteralPath $tmp -Destination $StatePath -Force
}
function Get-Token {
    foreach($name in @('GH_TOKEN','GITHUB_TOKEN')){
        $v=[Environment]::GetEnvironmentVariable($name)
        if(-not [string]::IsNullOrWhiteSpace($v)){return $v.Trim()}
    }
    try{
        $gh=Get-Command gh.exe -ErrorAction SilentlyContinue
        if($null -eq $gh){$gh=Get-Command gh -ErrorAction SilentlyContinue}
        if($null -ne $gh){$token=(& $gh.Source auth token 2>$null | Select-Object -First 1);if($LASTEXITCODE -eq 0 -and $token){return ([string]$token).Trim()}}
    }catch{}
    return ''
}
function Get-Headers([string]$Token,[string]$Accept='application/vnd.github+json'){
    $h=@{'User-Agent'='HuymaierConsole';'Accept'=$Accept;'X-GitHub-Api-Version'='2022-11-28'}
    if($Token){$h['Authorization']='Bearer '+$Token}
    return $h
}
function Parse-Version([string]$Text){
    $clean=([string]$Text).Trim();if($clean.StartsWith('v')){$clean=$clean.Substring(1)}
    $m=[regex]::Match($clean,'^\d+(?:\.\d+){1,3}')
    if(-not $m.Success){return [version]'0.0'}
    try{return [version]$m.Value}catch{return [version]'0.0'}
}
function Get-LatestRelease([string]$Token){
    $uri='https://api.github.com/repos/'+$Repository+'/releases/latest'
    try{return Invoke-RestMethod -UseBasicParsing -Uri $uri -Headers (Get-Headers $Token) -Method Get -TimeoutSec 30}
    catch{
        $code='';try{$code=[int]$_.Exception.Response.StatusCode}catch{}
        if($code -eq 404 -and -not $Token){throw 'The GitHub repository is private or has no published release yet. For a private repository, sign in with GitHub CLI (gh auth login) or set GH_TOKEN/GITHUB_TOKEN on this PC.'}
        if($code -eq 404){throw 'No published Huymaier Console GitHub Release was found yet.'}
        throw
    }
}
function Select-PackageAsset($Release){
    $assets=@($Release.assets)
    if($assets.Count -eq 0){return $null}
    $preferred=@($assets|Where-Object{[string]$_.name -match '(?i)^(HC|HuymaierConsole).+\.zip$'}|Sort-Object {[long]$_.size} -Descending)
    if($preferred.Count -gt 0){return $preferred[0]}
    return @($assets|Where-Object{[string]$_.name -match '(?i)\.zip$'}|Sort-Object {[long]$_.size} -Descending|Select-Object -First 1)[0]
}

try{
    Write-State 'Scanning' 'Checking GitHub Releases for a newer Huymaier Console build...' $true
    $token=Get-Token
    $release=Get-LatestRelease $token
    $latestText=([string]$release.tag_name).Trim();if(-not $latestText){$latestText=[string]$release.name}
    $latestVersionText=$latestText.TrimStart('v','V')
    $current=Parse-Version $CurrentVersion;$latest=Parse-Version $latestVersionText
    $asset=Select-PackageAsset $release
    if($null -eq $asset){
        Write-State 'Ready' "GitHub Release $latestVersionText exists but has no installable ZIP asset." $false $latestVersionText ($latest -gt $current) '' '' '' 0 ([string]$release.html_url) ([string]$release.body) ([string]$release.published_at)
        exit 0
    }
    $available=$latest -gt $current
    if($Action -eq 'Scan'){
        $msg=if($available){"Huymaier Console $latestVersionText is available."}else{"Huymaier Console is up to date ($CurrentVersion)."}
        Write-State 'Ready' $msg $false $latestVersionText $available ([string]$asset.name) ([string]$asset.browser_download_url) ([string]$asset.url) ([long]$asset.size) ([string]$release.html_url) ([string]$release.body) ([string]$release.published_at)
        exit 0
    }
    if(-not $available){
        Write-State 'Ready' "Huymaier Console is already up to date ($CurrentVersion)." $false $latestVersionText $false ([string]$asset.name) ([string]$asset.browser_download_url) ([string]$asset.url) ([long]$asset.size) ([string]$release.html_url) ([string]$release.body) ([string]$release.published_at)
        exit 0
    }
    $safeName=[IO.Path]::GetFileName([string]$asset.name);if(-not $safeName){$safeName='HuymaierConsole-'+$latestVersionText+'.zip'}
    $target=Join-Path $updateRoot $safeName;$partial=$target+'.partial';Remove-Item -LiteralPath $partial -Force -ErrorAction SilentlyContinue
    Add-Type -AssemblyName System.Net.Http
    $handler=[System.Net.Http.HttpClientHandler]::new();$handler.AllowAutoRedirect=$true
    $client=[System.Net.Http.HttpClient]::new($handler)
    $client.DefaultRequestHeaders.UserAgent.ParseAdd('HuymaierConsole/0.26.0')
    if($token){$client.DefaultRequestHeaders.Authorization=[System.Net.Http.Headers.AuthenticationHeaderValue]::new('Bearer',$token)}
    $downloadUri=if($token -and [string]$asset.url){[string]$asset.url}else{[string]$asset.browser_download_url}
    if($token){$client.DefaultRequestHeaders.Accept.Clear();$client.DefaultRequestHeaders.Accept.Add([System.Net.Http.Headers.MediaTypeWithQualityHeaderValue]::new('application/octet-stream'))}
    $response=$client.GetAsync($downloadUri,[System.Net.Http.HttpCompletionOption]::ResponseHeadersRead).GetAwaiter().GetResult();$response.EnsureSuccessStatusCode()
    $stream=$response.Content.ReadAsStreamAsync().GetAwaiter().GetResult();$file=[IO.File]::Open($partial,[IO.FileMode]::Create,[IO.FileAccess]::Write,[IO.FileShare]::None)
    try{
        $total=[long]$asset.size;$contentLength=$response.Content.Headers.ContentLength;if($null -ne $contentLength -and [long]$contentLength -gt 0){$total=[long]$contentLength}
        $buffer=New-Object byte[] (1024*1024);$done=[long]0;$last=[DateTime]::MinValue
        while(($read=$stream.Read($buffer,0,$buffer.Length)) -gt 0){
            $file.Write($buffer,0,$read);$done+=$read
            if(((Get-Date)-$last).TotalMilliseconds -ge 350){$pct=if($total -gt 0){[math]::Min(100,[math]::Round(($done*100.0)/$total,1))}else{0};Write-State 'Downloading' "Downloading Huymaier Console $latestVersionText..." $true $latestVersionText $true ([string]$asset.name) ([string]$asset.browser_download_url) ([string]$asset.url) ([long]$asset.size) ([string]$release.html_url) ([string]$release.body) ([string]$release.published_at) $done $total $pct $partial; $last=Get-Date}
        }
    }finally{$file.Dispose();$stream.Dispose();$client.Dispose();$handler.Dispose()}
    Move-Item -LiteralPath $partial -Destination $target -Force
    $hash=(Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash.ToLowerInvariant();$size=(Get-Item -LiteralPath $target).Length
    Write-State 'Downloaded' "Huymaier Console $latestVersionText is downloaded and ready to install." $false $latestVersionText $true ([string]$asset.name) ([string]$asset.browser_download_url) ([string]$asset.url) ([long]$asset.size) ([string]$release.html_url) ([string]$release.body) ([string]$release.published_at) $size $size 100 $target $hash
}catch{
    Write-State 'Error' 'Huymaier Console update check could not complete.' $false '' $false '' '' '' 0 '' '' '' 0 0 0 '' '' ([string]$_.Exception.Message)
    exit 1
}
