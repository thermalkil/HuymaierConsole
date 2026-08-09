param(
    [Parameter(Mandatory=$true)][ValidateSet('Setup','Authenticate','Refresh','Install','Update','Verify','Move','Uninstall','Launch')][string]$Mode,
    [Parameter(Mandatory=$true)][ValidateSet('Epic','GOG','Amazon')][string]$Provider,
    [string]$GameId='',
    [string]$GameName='',
    [string]$InstallPath='',
    [string]$AuthCode='',
    [Parameter(Mandatory=$true)][string]$DataDir,
    [Parameter(Mandatory=$true)][string]$StatePath,
    [Parameter(Mandatory=$true)][string]$CatalogPath,
    [Parameter(Mandatory=$true)][string]$ToolRoot,
    [Parameter(Mandatory=$true)][string]$ArtworkRoot
)

Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
$ProgressPreference='SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12

$logDir=Join-Path $DataDir 'Logs'
New-Item -ItemType Directory -Force -Path $DataDir,$logDir,$ToolRoot,$ArtworkRoot | Out-Null
$logPath=Join-Path $logDir "provider-$((Get-Date).ToString('yyyy-MM-dd')).log"
$managedPath=Join-Path $DataDir 'GameProviders\managed-installs.json'
$startedAt=(Get-Date).ToString('o')
# Live transfer telemetry. These fields are serialized with provider-state.json
# so the full-screen Downloads page can render real byte counts, transfer rate
# and ETA while provider tools are still running.
$script:TransferDownloadedBytes=[int64]0
$script:TransferTotalBytes=[int64]0
$script:TransferInstallSizeBytes=[int64]0
$script:TransferSpeedBytesPerSec=[double]0
$script:TransferEtaSeconds=[int64]-1
$script:TransferTelemetryUpdated=''

function Protect-ProviderLogText{
    param([string]$Text)
    if([string]::IsNullOrEmpty($Text)){return $Text}
    $safe=$Text
    $safe=[regex]::Replace($safe,'(?i)("(?:access_token|refresh_token|client_token|raw_token|token)"\s*:\s*")[^"]+(")','$1[REDACTED]$2')
    $safe=[regex]::Replace($safe,'(?i)(Authorization\s*[:=]\s*Bearer\s+)[A-Za-z0-9._~+/=-]+','$1[REDACTED]')
    $safe=[regex]::Replace($safe,'(?i)(Bearer\s+)[A-Za-z0-9._~+/=-]{20,}','$1[REDACTED]')
    $safe=[regex]::Replace($safe,'(?i)rmm_[a-f0-9]{64}','rmm_[REDACTED]')
    $safe=[regex]::Replace($safe,'(?i)([?&](?:code|token)=)[^&\s]+','$1[REDACTED]')
    if($safe.Length -gt 12000){$safe=$safe.Substring(0,12000)+" ... [provider output truncated; $($safe.Length-12000) characters omitted]"}
    return $safe
}
function Write-ProviderLog{param([string]$Message,[string]$Level='INFO');try{$sanitized=Protect-ProviderLogText $Message;"$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff') [$Level] [$Provider/$Mode] $sanitized"|Add-Content -LiteralPath $logPath -Encoding UTF8}catch{}}
function Write-AtomicJson{param([string]$Path,$Value);$tmp="$Path.tmp";$json=ConvertTo-Json -InputObject $Value -Depth 20;if([string]::IsNullOrWhiteSpace($json)){$json='[]'};Set-Content -LiteralPath $tmp -Value $json -Encoding UTF8;Move-Item -LiteralPath $tmp -Destination $Path -Force}
function Write-State{
    param([bool]$Busy,[string]$Phase,[string]$Message,[int]$Progress=-1,[string]$Error='',[switch]$Quiet)
    $state=[pscustomobject]@{
        Busy=$Busy;Provider=$Provider;Mode=$Mode;Phase=$Phase;Message=$Message;Progress=$Progress;Error=$Error;
        GameId=$GameId;GameName=$GameName;WorkerPid=$PID;StartedAt=$startedAt;Updated=(Get-Date).ToString('o');
        DownloadedBytes=[int64]$script:TransferDownloadedBytes;TotalBytes=[int64]$script:TransferTotalBytes;
        InstallSizeBytes=[int64]$script:TransferInstallSizeBytes;DownloadSpeedBytesPerSec=[double]$script:TransferSpeedBytesPerSec;
        EtaSeconds=[int64]$script:TransferEtaSeconds;TelemetryUpdated=[string]$script:TransferTelemetryUpdated
    }
    Write-AtomicJson $StatePath $state
    if(-not $Quiet){Write-ProviderLog "$Phase - $Message" $(if($Error){'ERROR'}else{'INFO'})}
}
function Get-Prop{param($Object,[string]$Name,$Default=$null);if($null -eq $Object){return $Default};try{$property=$Object.PSObject.Properties[$Name];if($null -ne $property -and $null -ne $property.Value){return $property.Value}}catch{};return $Default}
function To-Array{param($Value);$list=New-Object System.Collections.ArrayList;if($null -ne $Value){try{foreach($item in $Value){[void]$list.Add($item)}}catch{[void]$list.Add($Value)}};return [object[]]$list.ToArray()}
function Read-Catalog{if(Test-Path -LiteralPath $CatalogPath){try{return Get-Content -Raw -LiteralPath $CatalogPath|ConvertFrom-Json}catch{}};return [pscustomobject]@{Providers=@();Updated=''}}
function Save-ProviderNode{param($Node);$catalog=Read-Catalog;$nodes=New-Object System.Collections.ArrayList;$done=$false;foreach($existing in @(Get-Prop $catalog 'Providers' @())){if([string]::Equals([string](Get-Prop $existing 'Id' ''),$Provider,[StringComparison]::OrdinalIgnoreCase)){[void]$nodes.Add($Node);$done=$true}else{[void]$nodes.Add($existing)}};if(-not $done){[void]$nodes.Add($Node)};Write-AtomicJson $CatalogPath ([pscustomobject]@{Providers=[object[]]$nodes.ToArray();Updated=(Get-Date).ToString('o')})}
function Read-ManagedInstalls{if(Test-Path -LiteralPath $managedPath){try{return To-Array (Get-Content -Raw -LiteralPath $managedPath|ConvertFrom-Json)}catch{}};return @()}
function Save-ManagedInstall{param([string]$Id,[string]$Name,[string]$Path);$items=New-Object System.Collections.ArrayList;$done=$false;foreach($item in @(Read-ManagedInstalls)){if([string](Get-Prop $item 'Provider' '') -eq $Provider -and [string](Get-Prop $item 'Id' '') -eq $Id){[void]$items.Add([pscustomobject]@{Provider=$Provider;Id=$Id;Name=$Name;Path=$Path;Updated=(Get-Date).ToString('o')});$done=$true}else{[void]$items.Add($item)}};if(-not $done){[void]$items.Add([pscustomobject]@{Provider=$Provider;Id=$Id;Name=$Name;Path=$Path;Updated=(Get-Date).ToString('o')})};Write-AtomicJson $managedPath ([object[]]$items.ToArray())}
function Remove-ManagedInstall{param([string]$Id);$items=New-Object System.Collections.ArrayList;foreach($item in @(Read-ManagedInstalls)){if(-not ([string](Get-Prop $item 'Provider' '') -eq $Provider -and [string](Get-Prop $item 'Id' '') -eq $Id)){[void]$items.Add($item)}};Write-AtomicJson $managedPath ([object[]]$items.ToArray())}
function Get-ManagedInstall{param([string]$Id);foreach($item in @(Read-ManagedInstalls)){if([string](Get-Prop $item 'Provider' '') -eq $Provider -and [string](Get-Prop $item 'Id' '') -eq $Id){return $item}};return $null}


# Cross-process bridge to Huymaier Console's native WebView2 browser. Provider
# workers run independently from the WPF shell, so requests and results are
# exchanged through atomic JSON files under the current user's data directory.
$script:HcBrowserRequestPath=Join-Path $DataDir 'browser-auth-request.json'
$script:HcBrowserResultDir=Join-Path $DataDir 'BrowserAuth'
$script:HcBrowserReadyPath=Join-Path $script:HcBrowserResultDir 'native-browser.ready.json'
New-Item -ItemType Directory -Force -Path $script:HcBrowserResultDir|Out-Null
function Test-HcNativeBrowserReady{
    if(-not (Test-Path -LiteralPath $script:HcBrowserReadyPath -PathType Leaf)){return $false}
    try{
        $ready=Get-Content -Raw -LiteralPath $script:HcBrowserReadyPath|ConvertFrom-Json
        $hostPid=[int](Get-Prop $ready 'Pid' 0)
        if($hostPid -le 0){return $false}
        Get-Process -Id $hostPid -ErrorAction Stop|Out-Null
        return $true
    }catch{return $false}
}
function Wait-HcNativeBrowserReady{
    param([int]$Milliseconds=3000)
    $deadline=(Get-Date).AddMilliseconds([Math]::Max(0,$Milliseconds))
    do{
        if(Test-HcNativeBrowserReady){return $true}
        Start-Sleep -Milliseconds 125
    }while((Get-Date) -lt $deadline)
    return (Test-HcNativeBrowserReady)
}
function New-HcNativeBrowserRequest{
    param([string]$Url,[string]$Completion,[string]$Title,[string]$CallbackPrefix='',[int]$TimeoutSec=480)
    # WebView2 initializes asynchronously with the main WPF window. Give it a
    # brief chance to publish its readiness marker before falling back to the
    # system browser, especially when Connect is selected immediately at boot.
    if(-not (Wait-HcNativeBrowserReady 3000)){return $null}
    $id=[guid]::NewGuid().ToString('N')
    $request=[pscustomobject]@{
        Id=$id;Provider=$Provider;Url=$Url;Completion=$Completion;Title=$Title;
        CallbackPrefix=$CallbackPrefix;TimeoutSec=$TimeoutSec;Created=(Get-Date).ToString('o');WorkerPid=$PID
    }
    Write-AtomicJson $script:HcBrowserRequestPath $request
    Write-ProviderLog "Requested the native controller browser for $Provider authentication."
    return $request
}
function Remove-HcNativeBrowserRequest{
    param($Request)
    try{
        if($null -ne $Request){
            $resultPath=Join-Path $script:HcBrowserResultDir ("result-"+[string]$Request.Id+'.json')
            Remove-Item -LiteralPath $resultPath -Force -ErrorAction SilentlyContinue
        }
        if(Test-Path -LiteralPath $script:HcBrowserRequestPath -PathType Leaf){
            $current=$null;try{$current=Get-Content -Raw -LiteralPath $script:HcBrowserRequestPath|ConvertFrom-Json}catch{}
            if($null -eq $Request -or $null -eq $current -or [string]$current.Id -eq [string]$Request.Id){Remove-Item -LiteralPath $script:HcBrowserRequestPath -Force -ErrorAction SilentlyContinue}
        }
    }catch{}
}
function Wait-HcNativeBrowserResult{
    param($Request,[int]$TimeoutSec=480)
    if($null -eq $Request){return ''}
    $resultPath=Join-Path $script:HcBrowserResultDir ("result-"+[string]$Request.Id+'.json')
    $deadline=(Get-Date).AddSeconds([math]::Max(30,$TimeoutSec))
    try{
        while((Get-Date) -lt $deadline){
            if(Test-Path -LiteralPath $resultPath -PathType Leaf){
                $result=$null
                try{$result=Get-Content -Raw -LiteralPath $resultPath|ConvertFrom-Json}catch{Start-Sleep -Milliseconds 100;continue}
                if([string]$result.Id -ne [string]$Request.Id){Start-Sleep -Milliseconds 100;continue}
                $errorText=[string](Get-Prop $result 'Error' '')
                if($errorText){throw $errorText}
                return [string](Get-Prop $result 'Value' '')
            }
            Start-Sleep -Milliseconds 125
        }
        throw "$Provider sign-in timed out in the native browser."
    }finally{Remove-HcNativeBrowserRequest $Request}
}
function Open-HcAuthenticationUrl{
    param([string]$Url,[string]$Completion,[string]$Title,[string]$CallbackPrefix='',[int]$TimeoutSec=480,[switch]$DoNotWait)
    $request=New-HcNativeBrowserRequest -Url $Url -Completion $Completion -Title $Title -CallbackPrefix $CallbackPrefix -TimeoutSec $TimeoutSec
    if($null -eq $request){
        Start-Process -FilePath $Url|Out-Null
        return ''
    }
    if($DoNotWait){return $request}
    return Wait-HcNativeBrowserResult $request $TimeoutSec
}
function Get-JsonObjectFromOutput{
    param([string]$Text)
    if([string]::IsNullOrWhiteSpace($Text)){return $null}
    try{return $Text|ConvertFrom-Json}catch{}
    $matches=[regex]::Matches($Text,'(?s)\{.*?\}')
    for($i=$matches.Count-1;$i -ge 0;$i--){try{return $matches[$i].Value|ConvertFrom-Json}catch{}}
    return $null
}

function Get-ConsoleConfig{
    $path=Join-Path $DataDir 'config.json'
    if(Test-Path -LiteralPath $path -PathType Leaf){try{return Get-Content -Raw -LiteralPath $path|ConvertFrom-Json}catch{}}
    return [pscustomobject]@{}
}
$script:HesResolvedApiUrl=''
function Normalize-HesUrl{
    param([string]$Url)
    if([string]::IsNullOrWhiteSpace($Url)){return ''}
    $value=$Url.Trim().TrimEnd('/')
    if($value -notmatch '^[a-zA-Z][a-zA-Z0-9+.-]*://'){$value='http://'+$value}
    return $value
}
function Get-HesWebUrl{
    $config=Get-ConsoleConfig
    $url=Normalize-HesUrl ([string](Get-Prop $config 'HesServerUrl' 'http://localhost:6099'))
    if(-not $url){$url='http://localhost:6099'}
    return $url
}
# Compatibility alias used by launch/UI code. This is the human-facing site,
# not necessarily the API endpoint when Authentik protects the public domain.
function Get-HesServerUrl{return (Get-HesWebUrl)}
function Get-HesConfiguredApiUrl{
    $config=Get-ConsoleConfig
    return Normalize-HesUrl ([string](Get-Prop $config 'HesApiUrl' ''))
}
function Get-HesApiCandidates{
    $values=New-Object System.Collections.ArrayList
    $seen=@{}
    function Add-Candidate([string]$Value){
        $candidate=Normalize-HesUrl $Value
        if(-not $candidate){return}
        $key=$candidate.ToLowerInvariant()
        if(-not $seen.ContainsKey($key)){$seen[$key]=$true;[void]$values.Add($candidate)}
    }
    Add-Candidate (Get-HesConfiguredApiUrl)
    $web=Get-HesWebUrl
    Add-Candidate $web
    try{
        $uri=[uri]$web
        if($uri.Host){
            Add-Candidate ("http://{0}:6099" -f $uri.Host)
            if($uri.Host -notmatch '(?i)localhost|^127\.|^10\.|^192\.168\.|^172\.(1[6-9]|2[0-9]|3[01])\.'){
                $first=($uri.Host -split '\.')[0]
                if($first){Add-Candidate ("http://{0}:6099" -f $first);Add-Candidate ("http://{0}.local:6099" -f $first)}
            }
        }
    }catch{}
    # HES' normal server/container hostnames. These resolve instantly when
    # available and avoid sending API traffic through an Authentik proxy.
    Add-Candidate 'http://huymaierserver:6099'
    Add-Candidate 'http://huymaierserver.local:6099'
    Add-Candidate 'http://localhost:6099'
    return [object[]]$values.ToArray()
}
function Test-HesApiCandidate{
    param([string]$Base)
    $baseUrl=Normalize-HesUrl $Base
    if(-not $baseUrl){return $false}
    foreach($path in @('/openapi.json','/api/heartbeat')){
        try{
            $response=Invoke-WebRequest -UseBasicParsing -Uri ($baseUrl+$path) -Method GET -TimeoutSec 4 -MaximumRedirection 0 -Headers @{'User-Agent'='HuymaierConsole/0.25.3'} -ErrorAction Stop
            if([int]$response.StatusCode -lt 200 -or [int]$response.StatusCode -ge 300){continue}
            $content=[string]$response.Content
            $contentType='';try{$contentType=[string]$response.Headers['Content-Type']}catch{}
            if($contentType -match '(?i)text/html' -or $content.TrimStart().StartsWith('<')){continue}
            if($path -eq '/openapi.json'){
                try{$spec=$content|ConvertFrom-Json;if([string](Get-Prop $spec 'openapi' '') -and $null -ne (Get-Prop $spec 'paths' $null)){return $true}}catch{}
            }elseif(-not [string]::IsNullOrWhiteSpace($content)){return $true}
        }catch{}
    }
    return $false
}
function Resolve-HesApiUrl{
    param([switch]$Force)
    if(-not $Force -and $script:HesResolvedApiUrl){return $script:HesResolvedApiUrl}
    $attempted=New-Object System.Collections.ArrayList
    foreach($candidate in @(Get-HesApiCandidates)){
        [void]$attempted.Add($candidate)
        if(Test-HesApiCandidate $candidate){$script:HesResolvedApiUrl=$candidate;Write-ProviderLog "Using HES API endpoint $candidate";return $candidate}
    }
    $configured=Get-HesConfiguredApiUrl
    $hint=if($configured){"The configured API address '$configured' did not return the RomM API."}else{'The public HES address may be protected by Authentik.'}
    throw "$hint Set HES API Address to the direct RomM/LAN endpoint, normally http://<server-ip>:6099. Attempted: $([string]::Join(', ',[string[]]$attempted.ToArray()))"
}
function Get-HesApiUrl{return (Resolve-HesApiUrl)}
function Get-HesTokenPath{
    $dir=Join-Path $DataDir 'GameProviders\Config\HES'
    New-Item -ItemType Directory -Force -Path $dir|Out-Null
    return Join-Path $dir 'client-token.dat'
}
function Save-HesClientToken{
    param([string]$Token)
    if([string]::IsNullOrWhiteSpace($Token)){throw 'HES did not return a client token.'}
    try{
        Add-Type -AssemblyName System.Security -ErrorAction SilentlyContinue
        $plain=[Text.Encoding]::UTF8.GetBytes($Token.Trim())
        $protected=[Security.Cryptography.ProtectedData]::Protect($plain,$null,[Security.Cryptography.DataProtectionScope]::CurrentUser)
        [IO.File]::WriteAllBytes((Get-HesTokenPath),$protected)
    }catch{throw "The HES client token could not be protected for this Windows account: $($_.Exception.Message)"}
}
function Get-HesClientToken{
    $path=Get-HesTokenPath
    if(-not (Test-Path -LiteralPath $path -PathType Leaf)){return ''}
    try{
        Add-Type -AssemblyName System.Security -ErrorAction SilentlyContinue
        $protected=[IO.File]::ReadAllBytes($path)
        $plain=[Security.Cryptography.ProtectedData]::Unprotect($protected,$null,[Security.Cryptography.DataProtectionScope]::CurrentUser)
        return [Text.Encoding]::UTF8.GetString($plain)
    }catch{return ''}
}
function Join-HesUrl{
    param([string]$Path)
    if($Path -match '^https?://'){return $Path}
    $base=Get-HesApiUrl
    if(-not $Path.StartsWith('/')){$Path='/'+$Path}
    return $base+$Path
}
function Invoke-HesRequest{
    param([string]$Method='GET',[string]$Path='/', $Body=$null,[switch]$Anonymous)
    $headers=@{'User-Agent'='HuymaierConsole/0.25.3';'Accept'='application/json'}
    if(-not $Anonymous){$token=Get-HesClientToken;if(-not $token){throw 'HES pairing is required.'};$headers.Authorization="Bearer $token"}
    $parameters=@{Uri=(Join-HesUrl $Path);Method=$Method;Headers=$headers;ErrorAction='Stop';TimeoutSec=30}
    if($null -ne $Body){$parameters.ContentType='application/json';$parameters.Body=(ConvertTo-Json -InputObject $Body -Depth 10 -Compress)}
    try{return Invoke-RestMethod @parameters}catch{
        $message=$_.Exception.Message
        try{
            $response=$_.Exception.Response
            if($null -ne $response){$message="HTTP $([int]$response.StatusCode) from $(Get-HesApiUrl): $message"}
        }catch{}
        throw $message
    }
}
function Test-HesServer{
    try{Resolve-HesApiUrl -Force|Out-Null;return $true}catch{Write-ProviderLog $_.Exception.Message 'WARN';return $false}
}
function Connect-HesPairingCode{
    param([string]$Code)
    $trimmed=($Code -replace '[^0-9]','')
    if($trimmed.Length -ne 8){throw 'Enter the eight-digit pairing code shown in HES.'}
    $response=Invoke-HesRequest -Method POST -Path '/api/client-tokens/exchange' -Body @{code=$trimmed} -Anonymous
    $token=[string](Get-Prop $response 'raw_token' (Get-Prop $response 'token' (Get-Prop $response 'client_token' (Get-Prop $response 'access_token' ''))))
    if(-not $token -and $response -is [string]){$token=[string]$response}
    Save-HesClientToken $token
}
function ConvertFrom-HesFormBody{
    param([string]$Body)
    $values=@{}
    foreach($pair in @($Body -split '&')){
        if([string]::IsNullOrWhiteSpace($pair)){continue}
        $parts=$pair -split '=',2
        $rawName=[string]$parts[0]
        $rawValue=if($parts.Count -gt 1){[string]$parts[1]}else{''}
        try{$name=[uri]::UnescapeDataString(($rawName -replace '\+',' '))}catch{$name=$rawName}
        try{$value=[uri]::UnescapeDataString(($rawValue -replace '\+',' '))}catch{$value=$rawValue}
        if($name){$values[$name]=$value}
    }
    return $values
}
function Send-HesLoopbackResponse{
    param($Stream,[int]$StatusCode,[string]$StatusText,[string]$Heading,[string]$Message)
    if($null -eq $Stream){return}
    $safeHeading=[System.Security.SecurityElement]::Escape($Heading)
    $safeMessage=[System.Security.SecurityElement]::Escape($Message)
    $html=@"
<!doctype html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>$safeHeading</title><style>html,body{height:100%;margin:0}body{display:grid;place-items:center;background:radial-gradient(circle at 15% 10%,#17345d,#06101f 52%,#03070d);font-family:Segoe UI,Arial,sans-serif;color:#f6f7fb}.card{width:min(560px,calc(100% - 40px));box-sizing:border-box;padding:34px;border:1px solid rgba(231,196,94,.35);border-radius:24px;background:rgba(8,18,33,.95);box-shadow:0 28px 90px rgba(0,0,0,.45)}h1{margin:0 0 14px;color:#f5d674;font-size:28px}p{margin:0;color:#ced8e7;font-size:17px;line-height:1.6}</style></head><body><main class="card"><h1>$safeHeading</h1><p>$safeMessage</p></main></body></html>
"@
    $body=[Text.Encoding]::UTF8.GetBytes($html)
    $headers="HTTP/1.1 $StatusCode $StatusText`r`nContent-Type: text/html; charset=utf-8`r`nContent-Length: $($body.Length)`r`nCache-Control: no-store, no-cache, must-revalidate`r`nPragma: no-cache`r`nConnection: close`r`n`r`n"
    $headerBytes=[Text.Encoding]::ASCII.GetBytes($headers)
    $Stream.Write($headerBytes,0,$headerBytes.Length)
    $Stream.Write($body,0,$body.Length)
    $Stream.Flush()
}
function New-HesBrowserAuthState{
    $bytes=New-Object byte[] 32
    $rng=[Security.Cryptography.RandomNumberGenerator]::Create()
    try{$rng.GetBytes($bytes)}finally{$rng.Dispose()}
    return ([Convert]::ToBase64String($bytes).TrimEnd('=') -replace '\+','-' -replace '/','_')
}
function Connect-HesBrowserAuthentication{
    $browserRequest=$null
    $listener=$null
    $client=$null
    $stream=$null
    $reader=$null
    try{
        $listener=[Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback,0)
        $listener.Start()
        $port=([Net.IPEndPoint]$listener.LocalEndpoint).Port
        $state=New-HesBrowserAuthState
        $callback="http://127.0.0.1:$port/hes-auth/callback"
        $device=[Environment]::MachineName
        $web=(Get-HesWebUrl).TrimEnd('/')
        $authorizeUrl=$web+'/connect/console?callback='+[uri]::EscapeDataString($callback)+'&state='+[uri]::EscapeDataString($state)+'&device='+[uri]::EscapeDataString($device)
        Write-State $true 'Account sign-in' 'Sign in to HES in the browser and approve this console.' 18
        Write-ProviderLog 'Opening the HES browser authorization page.'
        $browserRequest=Open-HcAuthenticationUrl -Url $authorizeUrl -Completion 'Callback' -Title 'Connect HES Account' -CallbackPrefix $callback -TimeoutSec 300 -DoNotWait

        $deadline=(Get-Date).AddMinutes(5)
        $token=''
        while((Get-Date) -lt $deadline -and -not $token){
            # The native browser can explicitly cancel the request. Observe the
            # bridge result here so HES does not leave a listener and worker
            # waiting for five minutes after the user presses Close or B.
            if($null -ne $browserRequest){
                $browserResultPath=Join-Path $script:HcBrowserResultDir ("result-"+[string]$browserRequest.Id+'.json')
                if(Test-Path -LiteralPath $browserResultPath -PathType Leaf){
                    $browserResult=$null;try{$browserResult=Get-Content -Raw -LiteralPath $browserResultPath|ConvertFrom-Json}catch{}
                    $browserError=[string](Get-Prop $browserResult 'Error' '')
                    if($browserError){throw $browserError}
                }elseif(-not (Test-Path -LiteralPath $script:HcBrowserRequestPath -PathType Leaf)){
                    throw 'HES browser authentication was cancelled.'
                }
            }
            if(-not $listener.Pending()){Start-Sleep -Milliseconds 125;continue}
            $client=$listener.AcceptTcpClient()
            $client.ReceiveTimeout=10000
            $client.SendTimeout=10000
            $stream=$client.GetStream()
            $reader=New-Object IO.StreamReader($stream,[Text.Encoding]::UTF8,$false,4096,$true)
            $requestLine=[string]$reader.ReadLine()
            $contentLength=0
            while($true){
                $line=$reader.ReadLine()
                if($null -eq $line -or $line -eq ''){break}
                if($line -match '^(?i)Content-Length:\s*(\d+)\s*$'){$contentLength=[int]$matches[1]}
            }
            $body=''
            if($contentLength -gt 0 -and $contentLength -le 131072){
                $buffer=New-Object char[] $contentLength
                $total=0
                while($total -lt $contentLength){
                    $read=$reader.Read($buffer,$total,$contentLength-$total)
                    if($read -le 0){break}
                    $total+=$read
                }
                if($total -gt 0){$body=-join $buffer[0..($total-1)]}
            }
            $isCallback=$requestLine -match '^POST\s+/hes-auth/callback(?:\?[^\s]*)?\s+HTTP/'
            if(-not $isCallback){
                Send-HesLoopbackResponse $stream 404 'Not Found' 'Huymaier Console' 'This local callback is not available.'
            }else{
                $form=ConvertFrom-HesFormBody $body
                $returnedState=[string]$form['state']
                if(-not [string]::Equals($state,$returnedState,[StringComparison]::Ordinal)){
                    Send-HesLoopbackResponse $stream 400 'Bad Request' 'Connection rejected' 'The browser response did not match this console session.'
                    throw 'HES browser authentication returned an invalid session state.'
                }
                $errorCode=[string]$form['error']
                if($errorCode){
                    Send-HesLoopbackResponse $stream 200 'OK' 'Connection cancelled' 'No HES credential was shared. You can close this browser window.'
                    throw 'HES browser authentication was cancelled.'
                }
                $token=[string]$form['token']
                if([string]::IsNullOrWhiteSpace($token)){
                    Send-HesLoopbackResponse $stream 400 'Bad Request' 'Connection failed' 'HES did not return a usable console credential.'
                    throw 'HES browser authentication completed without a client token.'
                }
                Send-HesLoopbackResponse $stream 200 'OK' 'Huymaier Console connected' 'Return to Huymaier Console. Your HES library is being refreshed.'
            }
            try{$reader.Dispose()}catch{};$reader=$null
            try{$stream.Dispose()}catch{};$stream=$null
            try{$client.Close()}catch{};$client=$null
        }
        if([string]::IsNullOrWhiteSpace($token)){throw 'HES browser sign-in timed out before approval was received.'}
        Save-HesClientToken $token
        Write-ProviderLog 'HES browser authorization completed and the client token was protected with DPAPI.'
    }finally{
        try{if($reader){$reader.Dispose()}}catch{}
        try{if($stream){$stream.Dispose()}}catch{}
        try{if($client){$client.Close()}}catch{}
        try{if($listener){$listener.Stop()}}catch{}
        try{if($null -ne $browserRequest){Remove-HcNativeBrowserRequest $browserRequest}}catch{}
    }
}
function Test-HesAuthentication{
    if(-not (Get-HesClientToken)){return $false}
    foreach($path in @('/api/users/me','/api/platforms','/api/roms?limit=1&offset=0&with_char_index=false&with_filter_values=false')){
        try{Invoke-HesRequest -Method GET -Path $path|Out-Null;return $true}catch{Write-ProviderLog "HES credential validation failed at ${path}: $($_.Exception.Message)" 'WARN'}
    }
    return $false
}
function Get-HesCollectionItems{
    param($Response)
    if($null -eq $Response){return @()}
    if($Response -is [string]){return @()}

    # RomM 5.0 and 5.1 can expose the ROM collection directly, in a top-level
    # pagination member, or nested under a data/roms payload. Unwrap each shape
    # without ever relying on a scalar object's synthetic Count property.
    foreach($name in @('items','results','roms')){
        $value=Get-Prop $Response $name $null
        if($null -ne $value){return To-Array $value}
    }

    $data=Get-Prop $Response 'data' $null
    if($null -ne $data){
        foreach($name in @('items','results','roms','data')){
            $value=Get-Prop $data $name $null
            if($null -ne $value){return To-Array $value}
        }
        if($data -is [System.Collections.IEnumerable] -and -not ($data -is [string])){return To-Array $data}
    }

    if($Response -is [System.Collections.IEnumerable] -and -not ($Response -is [string])){return To-Array $Response}
    return @()
}
function Get-HesResponseTotal{
    param($Response)
    foreach($container in @($Response,(Get-Prop $Response 'pagination' $null),(Get-Prop $Response 'meta' $null),(Get-Prop $Response 'data' $null))){
        if($null -eq $container){continue}
        foreach($name in @('total','count','total_count','totalCount')){
            $value=Get-Prop $container $name $null
            if($null -ne $value){try{return [int64]$value}catch{}}
        }
    }
    return 0
}
function Get-HesPlatformName{
    param($Rom)
    $platform=Get-Prop $Rom 'platform' $null
    if($null -ne $platform){
        foreach($name in @('display_name','custom_name','name','igdb_name','fs_slug','slug')){$value=[string](Get-Prop $platform $name '');if($value){return $value}}
    }
    foreach($name in @('platform_display_name','platform_custom_name','platform_name','platform_fs_slug','platform_slug','system')){$value=[string](Get-Prop $Rom $name '');if($value){return $value}}
    return 'HES'
}
function Get-HesArtworkUrl{
    param($Rom)
    # Prefer RomM's local cover resources so a companion token can retrieve the
    # same artwork visible in the server UI even when metadata-provider URLs are
    # absent or protected.
    foreach($name in @('path_cover_large','path_cover_small','url_cover','cover_url','cover_path','image_url','thumbnail_url','artwork_url')){$value=[string](Get-Prop $Rom $name '');if($value){return Join-HesUrl $value}}
    $resources=Get-Prop $Rom 'resources' $null
    if($null -ne $resources){foreach($name in @('cover_large','cover_small','cover','cover_url','image','thumbnail')){$value=[string](Get-Prop $resources $name '');if($value){return Join-HesUrl $value}}}
    return ''
}
function Get-HesHeroArtworkUrl{
    param($Rom,[string]$Fallback='')
    foreach($name in @('screenshot_path','path_background','path_title_screen','background_url','hero_url')){$value=[string](Get-Prop $Rom $name '');if($value){return Join-HesUrl $value}}
    foreach($name in @('merged_screenshots','screenshots')){
        $items=@(To-Array (Get-Prop $Rom $name @()))
        foreach($item in $items){
            if($item -is [string] -and -not [string]::IsNullOrWhiteSpace([string]$item)){return Join-HesUrl ([string]$item)}
            foreach($field in @('path','url','src')){$value=[string](Get-Prop $item $field '');if($value){return Join-HesUrl $value}}
        }
    }
    return $Fallback
}
function Save-HesArtwork{
    param([string]$GameKey,[string]$Url)
    if(-not $Url){return ''}
    $dir=Join-Path $ArtworkRoot 'HES';New-Item -ItemType Directory -Force -Path $dir|Out-Null
    $safe=($GameKey -replace '[^a-zA-Z0-9._-]','_');$target=Join-Path $dir "$safe.jpg"
    if(Test-ImageFile $target){return $target}
    $temp="$target.download"
    try{
        $headers=@{'User-Agent'='HuymaierConsole/0.25.3'};$token=Get-HesClientToken;if($token){$headers.Authorization="Bearer $token"}
        Invoke-WebRequest -UseBasicParsing -Uri $Url -OutFile $temp -Headers $headers
        if(-not (Test-ImageFile $temp)){throw 'HES returned an invalid artwork file.'}
        Move-Item -LiteralPath $temp -Destination $target -Force;return $target
    }catch{Remove-Item -LiteralPath $temp -Force -ErrorAction SilentlyContinue;return ''}
}


function Get-WindowsExecutableMachine {
    param([string]$Path)
    if(-not $Path -or -not (Test-Path -LiteralPath $Path -PathType Leaf)){return 0}
    $stream=$null;$reader=$null
    try{
        $stream=[IO.File]::Open($Path,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::ReadWrite)
        if($stream.Length -lt 68){return 0}
        $reader=New-Object IO.BinaryReader($stream)
        if($reader.ReadUInt16() -ne 0x5A4D){return 0}
        $stream.Position=0x3C
        $peOffset=$reader.ReadInt32()
        if($peOffset -lt 0 -or ($peOffset+6) -gt $stream.Length){return 0}
        $stream.Position=$peOffset
        if($reader.ReadUInt32() -ne 0x00004550){return 0}
        return [int]$reader.ReadUInt16()
    }catch{return 0}
    finally{if($reader){$reader.Dispose()}elseif($stream){$stream.Dispose()}}
}

function Test-CompatibleWindowsTool {
    param([string]$Path)
    if(-not $Path -or -not (Test-Path -LiteralPath $Path -PathType Leaf)){return $false}
    if([IO.Path]::GetExtension($Path) -ne '.exe'){return $true}
    $machine=Get-WindowsExecutableMachine $Path
    # x86 and x64 are valid on this Windows build; ARM64 is deliberately rejected.
    return ($machine -eq 0x014C -or $machine -eq 0x8664)
}

function Get-HeroicToolPath{
    param([string]$Name)
    $roots=@(
        (Join-Path $env:LOCALAPPDATA 'Programs\heroic'),
        (Join-Path $env:ProgramFiles 'Heroic'),
        (Join-Path ${env:ProgramFiles(x86)} 'Heroic')
    )|Where-Object{$_ -and (Test-Path -LiteralPath $_ -PathType Container)}
    foreach($root in $roots){
        foreach($candidate in @(
            (Join-Path $root "resources\app.asar.unpacked\build\bin\x64\win32\$Name.exe"),
            (Join-Path $root "resources\app.asar.unpacked\build\bin\x64\win32\$Name"),
            (Join-Path $root "resources\app.asar.unpacked\build\bin\win32\$Name.exe"),
            (Join-Path $root "resources\app.asar.unpacked\build\bin\win32\$Name")
        )){if(Test-Path -LiteralPath $candidate -PathType Leaf){return $candidate}}
    }
    return ''
}

function Get-LocalToolPath{
    switch($Provider){
        'Epic'{$name='legendary'}
        'GOG'{$name='gogdl'}
        'Amazon'{$name='nile'}
        'HES'{return 'HES API'}
    }
    foreach($candidate in @(
        (Join-Path (Join-Path $ToolRoot $Provider) "$name.exe"),
        (Join-Path (Join-Path $ToolRoot $Provider) "venv\Scripts\$name.exe"),
        (Join-Path (Join-Path $ToolRoot $Provider) $name),
        (Get-HeroicToolPath $name)
    )){
        if($candidate -and (Test-Path -LiteralPath $candidate -PathType Leaf)){
            if(Test-CompatibleWindowsTool $candidate){return $candidate}
            Write-ProviderLog "Ignoring incompatible provider executable: $candidate" 'WARN'
        }
    }
    return ''
}

function Expand-ReleaseAsset{
    param([string]$Url,[string]$TargetDir,[string]$ToolName)
    New-Item -ItemType Directory -Force -Path $TargetDir|Out-Null
    $leaf=[IO.Path]::GetFileName(([uri]$Url).AbsolutePath);if(-not $leaf){$leaf="$ToolName.download"}
    $download=Join-Path $TargetDir $leaf
    Invoke-WebRequest -UseBasicParsing -Uri $Url -OutFile $download -Headers @{'User-Agent'='HuymaierConsole/0.25.3'}
    if($download.ToLowerInvariant().EndsWith('.zip')){Expand-Archive -LiteralPath $download -DestinationPath $TargetDir -Force;Remove-Item -LiteralPath $download -Force -ErrorAction SilentlyContinue}
    elseif($download.ToLowerInvariant().EndsWith('.exe')){$destination=Join-Path $TargetDir "$ToolName.exe";$same=[string]::Equals([IO.Path]::GetFullPath($download),[IO.Path]::GetFullPath($destination),[StringComparison]::OrdinalIgnoreCase);if(-not $same){Copy-Item -LiteralPath $download -Destination $destination -Force;Remove-Item -LiteralPath $download -Force -ErrorAction SilentlyContinue}}
    $found=Get-ChildItem -LiteralPath $TargetDir -Recurse -File -ErrorAction SilentlyContinue|Where-Object{$_.Name -in @($ToolName,"$ToolName.exe")}|Select-Object -First 1
    if($found -and $found.FullName -ne (Join-Path $TargetDir "$ToolName.exe")){Copy-Item -LiteralPath $found.FullName -Destination (Join-Path $TargetDir "$ToolName.exe") -Force}
}

function Install-ReleaseTool{
    param([string]$Repo,[string]$ToolName)
    $target=Join-Path $ToolRoot $Provider
    Write-State $true 'Installing backend' "Downloading $ToolName from its project release..." 10
    $release=Invoke-RestMethod -Uri "https://api.github.com/repos/$Repo/releases/latest" -Headers @{'User-Agent'='HuymaierConsole/0.25.3'}
    $assets=@(Get-Prop $release 'assets' @())
    $asset=$null
    if([string]::Equals($ToolName,'gogdl',[StringComparison]::OrdinalIgnoreCase)){
        # heroic-gogdl names its desktop Windows build gogdl_windows_x86_64.exe.
        # The previous generic selector missed x86_64 and could pick ARM64 first.
        $asset=$assets|Where-Object{[string](Get-Prop $_ 'name' '') -match '(?i)^gogdl_windows_(x86_64|amd64|x64)\.exe$'}|Select-Object -First 1
    }
    if(-not $asset){$asset=$assets|Where-Object{([string](Get-Prop $_ 'name' '') -match '(?i)(x86[_-]?64|x64|amd64)' -and [string](Get-Prop $_ 'name' '') -notmatch '(?i)(arm|aarch)' -and [string](Get-Prop $_ 'name' '') -match '(?i)(\.exe$|\.zip$)')}|Select-Object -First 1}
    if(-not $asset){$asset=$assets|Where-Object{([string](Get-Prop $_ 'name' '') -match '(?i)(win|windows)' -and [string](Get-Prop $_ 'name' '') -notmatch '(?i)(arm|aarch)' -and [string](Get-Prop $_ 'name' '') -match '(?i)(\.exe$|\.zip$)')}|Select-Object -First 1}
    if(-not $asset){throw "No Windows release asset was found for $Repo."}
    Expand-ReleaseAsset ([string](Get-Prop $asset 'browser_download_url' '')) $target $ToolName
    $installedTool=Join-Path $target "$ToolName.exe"
    if(-not (Test-Path -LiteralPath $installedTool -PathType Leaf)){throw "The selected $Repo release did not contain a Windows $ToolName executable."}
    if(-not (Test-CompatibleWindowsTool $installedTool)){
        try{Remove-Item -LiteralPath $installedTool -Force -ErrorAction SilentlyContinue}catch{}
        throw "The selected $Repo release was not compatible with this x64 Windows installation."
    }
}

function Find-Python{
    foreach($candidate in @((Get-Command py.exe -ErrorAction SilentlyContinue),(Get-Command python.exe -ErrorAction SilentlyContinue),(Get-Command python3.exe -ErrorAction SilentlyContinue))){if($candidate){return [string]$candidate.Source}}
    return ''
}

function Install-PythonTool{
    param([string]$Repo,[string]$ToolName,[string]$Branch='main')
    $python=Find-Python
    if(-not $python){
        $winget=Get-Command winget.exe -ErrorAction SilentlyContinue
        if($winget){
            Write-State $true 'Installing backend' 'Installing the lightweight Python runtime required by this provider...' 12
            & $winget.Source install --id Python.Python.3.12 --exact --silent --accept-package-agreements --accept-source-agreements --disable-interactivity | Out-Null
            $python=Find-Python
        }
    }
    if(-not $python){throw 'Python 3 is required for this provider backend and could not be installed automatically.'}
    $target=Join-Path $ToolRoot $Provider;$venv=Join-Path $target 'venv';New-Item -ItemType Directory -Force -Path $target|Out-Null
    if(-not (Test-Path -LiteralPath (Join-Path $venv 'Scripts\python.exe'))){& $python -m venv $venv}
    $venvPython=Join-Path $venv 'Scripts\python.exe'
    & $venvPython -m pip install --disable-pip-version-check --upgrade pip | Out-Null
    & $venvPython -m pip install --disable-pip-version-check --upgrade "https://github.com/$Repo/archive/refs/heads/$Branch.zip" | Out-Null
    $tool=Join-Path $venv "Scripts\$ToolName.exe"
    if(-not (Test-Path -LiteralPath $tool)){throw "$ToolName was installed but its executable was not found."}
}

function Ensure-Tool{
    $tool=Get-LocalToolPath;if($tool){return $tool}
    switch($Provider){
        'Epic'{Install-ReleaseTool 'derrod/legendary' 'legendary'}
        'GOG'{try{Install-ReleaseTool 'Heroic-Games-Launcher/heroic-gogdl' 'gogdl'}catch{Write-ProviderLog "Release install fallback: $($_.Exception.Message)" 'WARN';Install-PythonTool 'Heroic-Games-Launcher/heroic-gogdl' 'gogdl' 'main'}}
        'Amazon'{try{Install-ReleaseTool 'imLinguin/nile' 'nile'}catch{Write-ProviderLog "Release install fallback: $($_.Exception.Message)" 'WARN';Install-PythonTool 'imLinguin/nile' 'nile' 'master'}}
        'HES'{if(-not (Test-HesServer)){throw 'A direct HES / RomM API endpoint could not be reached. Configure HES API Address, normally http://<server-ip>:6099.'};return 'HES API'}
    }
    $tool=Get-LocalToolPath;if(-not $tool){throw 'Provider backend setup completed without producing a usable executable.'};return $tool
}

function Set-ProviderEnvironment{
    switch($Provider){
        'Epic'{$env:LEGENDARY_CONFIG_PATH=Join-Path $DataDir 'GameProviders\Config\Legendary'}
        'GOG'{$env:GOGDL_CONFIG_PATH=Join-Path $DataDir 'GameProviders\Config\GOGDL'}
        'Amazon'{$env:NILE_CONFIG_PATH=Join-Path $DataDir 'GameProviders\Config\Nile'}
    }
    foreach($path in @($env:LEGENDARY_CONFIG_PATH,$env:GOGDL_CONFIG_PATH,$env:NILE_CONFIG_PATH)){if($path){New-Item -ItemType Directory -Force -Path $path|Out-Null}}
}

function Quote-ProcessArgument{param([string]$Value);if($null -eq $Value){return '""'};if($Value -notmatch '[\s"]'){return $Value};return '"'+($Value -replace '(\\*)"','$1$1\"' -replace '(\\+)$','$1$1')+'"'}
function Invoke-Captured{
    param([string]$File,[string[]]$Arguments,[switch]$AllowFailure)
    $outFile=Join-Path $env:TEMP ("huymaier-provider-out-"+[guid]::NewGuid().ToString('N')+'.txt')
    $errFile=Join-Path $env:TEMP ("huymaier-provider-err-"+[guid]::NewGuid().ToString('N')+'.txt')
    try{
        $quoted=@($Arguments|ForEach-Object{Quote-ProcessArgument ([string]$_)})
        $process=Start-Process -FilePath $File -ArgumentList $quoted -WindowStyle Hidden -Wait -PassThru -RedirectStandardOutput $outFile -RedirectStandardError $errFile
        $stdout=if(Test-Path -LiteralPath $outFile){Get-Content -Raw -LiteralPath $outFile}else{''}
        $stderr=if(Test-Path -LiteralPath $errFile){Get-Content -Raw -LiteralPath $errFile}else{''}
        if($stdout){Write-ProviderLog $stdout.Trim()}
        if($stderr){Write-ProviderLog $stderr.Trim() $(if($process.ExitCode -eq 0){'INFO'}else{'WARN'})}
        if($process.ExitCode -ne 0 -and -not $AllowFailure){throw "Backend exited with code $($process.ExitCode): $stderr"}
        return [pscustomobject]@{ExitCode=$process.ExitCode;StdOut=$stdout;StdErr=$stderr}
    }finally{Remove-Item -LiteralPath $outFile,$errFile -Force -ErrorAction SilentlyContinue}
}

function Reset-TransferTelemetry{
    $script:TransferDownloadedBytes=[int64]0
    $script:TransferTotalBytes=[int64]0
    $script:TransferInstallSizeBytes=[int64]0
    $script:TransferSpeedBytesPerSec=[double]0
    $script:TransferEtaSeconds=[int64]-1
    $script:TransferTelemetryUpdated=''
}
function Convert-MiBToBytes{
    param([string]$Value)
    try{return [int64]([double]::Parse($Value,[Globalization.CultureInfo]::InvariantCulture)*1MB)}catch{return [int64]0}
}
function Format-ProviderByteValue{
    param([int64]$Bytes)
    if($Bytes -ge 1GB){return ('{0:N2} GB' -f ($Bytes/1GB))}
    if($Bytes -ge 1MB){return ('{0:N1} MB' -f ($Bytes/1MB))}
    if($Bytes -ge 1KB){return ('{0:N0} KB' -f ($Bytes/1KB))}
    return "$Bytes B"
}
function Format-ProviderSpeedValue{
    param([double]$BytesPerSecond)
    if($BytesPerSecond -ge 1GB){return ('{0:N2} GB/s' -f ($BytesPerSecond/1GB))}
    if($BytesPerSecond -ge 1MB){return ('{0:N1} MB/s' -f ($BytesPerSecond/1MB))}
    if($BytesPerSecond -ge 1KB){return ('{0:N0} KB/s' -f ($BytesPerSecond/1KB))}
    return ('{0:N0} B/s' -f $BytesPerSecond)
}
function Update-LegendaryTransferTelemetry{
    param([string]$Text)
    if([string]::IsNullOrWhiteSpace($Text)){return $false}
    $changed=$false
    $matches=[regex]::Matches($Text,'(?im)Install size:\s*([0-9]+(?:\.[0-9]+)?)\s*MiB')
    if($matches.Count -gt 0){$value=Convert-MiBToBytes $matches[$matches.Count-1].Groups[1].Value;if($value -gt 0 -and $value -ne $script:TransferInstallSizeBytes){$script:TransferInstallSizeBytes=$value;$changed=$true}}
    $matches=[regex]::Matches($Text,'(?im)Download size:\s*([0-9]+(?:\.[0-9]+)?)\s*MiB')
    if($matches.Count -gt 0){$value=Convert-MiBToBytes $matches[$matches.Count-1].Groups[1].Value;if($value -gt 0 -and $value -ne $script:TransferTotalBytes){$script:TransferTotalBytes=$value;$changed=$true}}
    $progress=-1
    $matches=[regex]::Matches($Text,'(?im)Progress:\s*([0-9]+(?:\.[0-9]+)?)%.*?ETA:\s*(\d{2}):(\d{2}):(\d{2})')
    if($matches.Count -gt 0){
        $m=$matches[$matches.Count-1]
        $progress=[int][math]::Round([double]::Parse($m.Groups[1].Value,[Globalization.CultureInfo]::InvariantCulture))
        $eta=([int64]$m.Groups[2].Value*3600)+([int64]$m.Groups[3].Value*60)+[int64]$m.Groups[4].Value
        if($eta -ne $script:TransferEtaSeconds){$script:TransferEtaSeconds=$eta;$changed=$true}
    }
    $matches=[regex]::Matches($Text,'(?im)Downloaded:\s*([0-9]+(?:\.[0-9]+)?)\s*MiB')
    if($matches.Count -gt 0){$value=Convert-MiBToBytes $matches[$matches.Count-1].Groups[1].Value;if($value -ne $script:TransferDownloadedBytes){$script:TransferDownloadedBytes=$value;$changed=$true}}
    $matches=[regex]::Matches($Text,'(?im)\+\s*Download\s*-\s*([0-9]+(?:\.[0-9]+)?)\s*MiB/s\s*\(raw\)')
    if($matches.Count -gt 0){
        $value=[double]::Parse($matches[$matches.Count-1].Groups[1].Value,[Globalization.CultureInfo]::InvariantCulture)*1MB
        if([math]::Abs($value-$script:TransferSpeedBytesPerSec) -gt 1024){$script:TransferSpeedBytesPerSec=$value;$changed=$true}
    }
    if($progress -lt 0 -and $script:TransferTotalBytes -gt 0){$progress=[int][math]::Round([math]::Min(99,($script:TransferDownloadedBytes/[double]$script:TransferTotalBytes)*100))}
    if($progress -ge 0){$script:TransferTelemetryUpdated=(Get-Date).ToString('o')}
    if($changed -or $progress -ge 0){
        $amount=if($script:TransferTotalBytes -gt 0){"$(Format-ProviderByteValue $script:TransferDownloadedBytes) / $(Format-ProviderByteValue $script:TransferTotalBytes)"}elseif($script:TransferDownloadedBytes -gt 0){Format-ProviderByteValue $script:TransferDownloadedBytes}else{'Preparing download…'}
        $speed=if($script:TransferSpeedBytesPerSec -gt 0){Format-ProviderSpeedValue $script:TransferSpeedBytesPerSec}else{'Measuring speed…'}
        Write-State $true 'Downloading' "$amount  •  $speed" $(if($progress -ge 0){$progress}else{5}) -Quiet
        return $true
    }
    return $false
}
function Invoke-EpicLegendaryTransfer{
    param([string]$File,[string[]]$Arguments)
    Reset-TransferTelemetry
    $outFile=Join-Path $env:TEMP ("huymaier-legendary-live-out-"+[guid]::NewGuid().ToString('N')+'.txt')
    $errFile=Join-Path $env:TEMP ("huymaier-legendary-live-err-"+[guid]::NewGuid().ToString('N')+'.txt')
    try{
        $quoted=@($Arguments|ForEach-Object{Quote-ProcessArgument ([string]$_)})
        Write-State $true 'Preparing download' "Preparing $GameName for download…" 2
        $process=Start-Process -FilePath $File -ArgumentList $quoted -WindowStyle Hidden -PassThru -RedirectStandardOutput $outFile -RedirectStandardError $errFile
        $lastTelemetry=''
        while(-not $process.HasExited){
            Start-Sleep -Milliseconds 400
            try{$process.Refresh()}catch{}
            $stdout=if(Test-Path -LiteralPath $outFile){Get-Content -Raw -LiteralPath $outFile -ErrorAction SilentlyContinue}else{''}
            $stderr=if(Test-Path -LiteralPath $errFile){Get-Content -Raw -LiteralPath $errFile -ErrorAction SilentlyContinue}else{''}
            $combined="$stdout`n$stderr"
            # Avoid rewriting provider-state.json for identical buffered output.
            $signature=if($combined.Length -gt 2400){$combined.Substring($combined.Length-2400)}else{$combined}
            if($signature -ne $lastTelemetry){$lastTelemetry=$signature;[void](Update-LegendaryTransferTelemetry $combined)}
        }
        try{$process.WaitForExit()}catch{}
        $stdout=if(Test-Path -LiteralPath $outFile){Get-Content -Raw -LiteralPath $outFile}else{''}
        $stderr=if(Test-Path -LiteralPath $errFile){Get-Content -Raw -LiteralPath $errFile}else{''}
        [void](Update-LegendaryTransferTelemetry "$stdout`n$stderr")
        if($stdout){Write-ProviderLog $stdout.Trim()}
        if($stderr){Write-ProviderLog $stderr.Trim() $(if($process.ExitCode -eq 0){'INFO'}else{'WARN'})}
        if($process.ExitCode -ne 0){throw "Legendary exited with code $($process.ExitCode): $stderr"}
        return [pscustomobject]@{ExitCode=$process.ExitCode;StdOut=$stdout;StdErr=$stderr}
    }finally{Remove-Item -LiteralPath $outFile,$errFile -Force -ErrorAction SilentlyContinue}
}

function Invoke-Interactive{
    param([string]$File,[string[]]$Arguments)
    $quoted=foreach($arg in $Arguments){if($arg -match '[\s"]'){'"'+$arg.Replace('"','\"')+'"'}else{$arg}}
    $p=Start-Process -FilePath $File -ArgumentList $quoted -Wait -PassThru
    if($p.ExitCode -ne 0){throw "Authentication backend exited with code $($p.ExitCode)."}
}

function Get-GogAuthPath{
    foreach($candidate in @(
        (Join-Path $env:APPDATA 'heroic\gog_store\auth.json'),
        (Join-Path $DataDir 'GameProviders\Config\GOG\auth.json'),
        (Join-Path $DataDir 'GameProviders\Config\GOGDL\auth.json')
    )){if(Test-Path -LiteralPath $candidate -PathType Leaf){return $candidate}}
    $target=Join-Path $DataDir 'GameProviders\Config\GOG\auth.json';New-Item -ItemType Directory -Force -Path (Split-Path -Parent $target)|Out-Null;return $target
}


function Get-ConfiguredBrowserPath{
    $configPath=Join-Path $DataDir 'config.json'
    if(Test-Path -LiteralPath $configPath){try{$config=Get-Content -Raw -LiteralPath $configPath|ConvertFrom-Json;$candidate=[string](Get-Prop $config 'BrowserPath' '');if($candidate -and (Test-Path -LiteralPath $candidate -PathType Leaf)){return $candidate}}catch{}}
    foreach($candidate in @(
        (Join-Path ${env:ProgramFiles(x86)} 'Microsoft\Edge\Application\msedge.exe'),
        (Join-Path $env:ProgramFiles 'Microsoft\Edge\Application\msedge.exe'),
        (Join-Path $env:LOCALAPPDATA 'Google\Chrome\Application\chrome.exe'),
        (Join-Path ${env:ProgramFiles(x86)} 'Google\Chrome\Application\chrome.exe')
    )){if($candidate -and (Test-Path -LiteralPath $candidate -PathType Leaf)){return $candidate}}
    return ''
}

function Get-EdgeBrowserPath{
    foreach($candidate in @(
        (Join-Path ${env:ProgramFiles(x86)} 'Microsoft\Edge\Application\msedge.exe'),
        (Join-Path $env:ProgramFiles 'Microsoft\Edge\Application\msedge.exe'),
        (Join-Path $env:LOCALAPPDATA 'Microsoft\Edge\Application\msedge.exe')
    )){if($candidate -and (Test-Path -LiteralPath $candidate -PathType Leaf)){return $candidate}}
    return ''
}

function Get-CodeFromGogUrl{
    param([string]$Value)
    if([string]::IsNullOrWhiteSpace($Value)){return ''}
    if($Value -match '[?&]code=([^&#]+)'){return [uri]::UnescapeDataString([string]$matches[1])}
    return ''
}

function Get-GogAuthorizationCodeInteractive{
    # Prefer Huymaier Console's persistent controller browser. It captures the
    # OAuth redirect directly, so no mouse, keyboard, or manual code copy is needed.
    $url='https://auth.gog.com/auth?client_id=46899977096215655&redirect_uri=https%3A%2F%2Fembed.gog.com%2Fon_login_success%3Forigin%3Dclient&response_type=code&layout=client2'
    if(Wait-HcNativeBrowserReady 3000){
        Write-State $true 'Account sign-in' 'Sign in to GOG in the Huymaier browser.' 10
        $request=New-HcNativeBrowserRequest -Url $url -Completion 'UrlCode' -Title 'Connect GOG Account' -TimeoutSec 480
        $captured=Wait-HcNativeBrowserResult $request 480
        if($captured){return $captured}
    }
    # Compatibility fallback when WebView2 is unavailable.
    $browser=Get-EdgeBrowserPath
    if(-not $browser){throw 'Microsoft Edge is required for the native GOG sign-in surface on Windows 11.'}
    $port=Get-Random -Minimum 21000 -Maximum 49000
    $session=[guid]::NewGuid().ToString('N')
    $profile=Join-Path $DataDir ("GameProviders\GogAuthBrowser\"+$session)
    New-Item -ItemType Directory -Force -Path $profile|Out-Null
    Write-State $true 'Account sign-in' 'Sign in to GOG. Huymaier Console is watching the secure redirect and will finish automatically.' 10
    $args=@(
        "--remote-debugging-port=$port",
        '--remote-allow-origins=*',
        "--user-data-dir=$profile",
        '--new-window',
        '--no-first-run',
        '--disable-background-mode',
        '--disable-extensions',
        "--app=$url"
    )
    $process=Start-Process -FilePath $browser -ArgumentList $args -PassThru
    $deadline=(Get-Date).AddMinutes(8)
    $captured=''
    try{
        while((Get-Date) -lt $deadline -and -not $captured){
            Start-Sleep -Milliseconds 220
            foreach($endpoint in @("http://127.0.0.1:$port/json/list","http://127.0.0.1:$port/json")){
                try{
                    $targets=Invoke-RestMethod -Uri $endpoint -TimeoutSec 2
                    foreach($target in @($targets)){
                        foreach($candidate in @(
                            [string](Get-Prop $target 'url' ''),
                            [string](Get-Prop $target 'title' ''),
                            [string](Get-Prop $target 'description' '')
                        )){
                            $captured=Get-CodeFromGogUrl $candidate
                            if($captured){break}
                        }
                        if($captured){break}
                    }
                }catch{}
                if($captured){break}
            }
            if($process.HasExited -and -not $captured){break}
        }
    }finally{
        try{if(-not $process.HasExited){Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue}}catch{}
        Start-Sleep -Milliseconds 150
        try{Remove-Item -LiteralPath $profile -Recurse -Force -ErrorAction SilentlyContinue}catch{}
    }
    if($captured){return $captured}
    throw 'GOG sign-in finished without a detectable authorization redirect. Use GOG Manual Code as a fallback.'
}


function Invoke-AmazonNativeAuthentication{
    param([string]$Tool)
    if(-not (Wait-HcNativeBrowserReady 3000)){Invoke-Interactive $Tool @('auth','--login','--gui');return}
    Write-State $true 'Account sign-in' 'Preparing Amazon device authorization...' 15
    $bootstrap=Invoke-Captured $Tool @('auth','--login','--non-interactive')
    $login=Get-JsonObjectFromOutput $bootstrap.StdOut
    if($null -eq $login){throw 'Nile did not return the Amazon non-interactive login data.'}
    $url=[string](Get-Prop $login 'url' '')
    $clientId=[string](Get-Prop $login 'client_id' '')
    $verifier=[string](Get-Prop $login 'code_verifier' '')
    $serial=[string](Get-Prop $login 'serial' '')
    if(-not $url -or -not $clientId -or -not $verifier -or -not $serial){throw 'Nile returned incomplete Amazon login data.'}
    Write-State $true 'Account sign-in' 'Sign in to Amazon in the Huymaier browser.' 20
    $request=New-HcNativeBrowserRequest -Url $url -Completion 'AmazonAuthorizationCode' -Title 'Connect Amazon Games Account' -TimeoutSec 600
    $code=Wait-HcNativeBrowserResult $request 600
    if([string]::IsNullOrWhiteSpace($code)){throw 'Amazon did not return an authorization code.'}
    Write-State $true 'Account sign-in' 'Registering this console with Amazon Games...' 65
    Invoke-Captured $Tool @('register','--code',$code,'--client-id',$clientId,'--code-verifier',$verifier,'--serial',$serial)|Out-Null
}

function Test-Authenticated{
    param([string]$Tool)
    try{
        switch($Provider){
            'Epic'{
                $r=Invoke-Captured $Tool @('status','--offline','--json') -AllowFailure
                if($r.ExitCode -ne 0 -or [string]::IsNullOrWhiteSpace($r.StdOut)){return $false}
                try{
                    $status=$r.StdOut|ConvertFrom-Json
                    $loggedIn=Get-Prop $status 'logged_in' (Get-Prop $status 'loggedIn' $null)
                    if($null -ne $loggedIn){return [bool]$loggedIn}
                    $account=[string](Get-Prop $status 'account' (Get-Prop $status 'display_name' (Get-Prop $status 'displayName' '')))
                    if([string]::IsNullOrWhiteSpace($account)){return $false}
                    return $account -notmatch '(?i)^\s*<?not\s+logged\s+in>?\s*$'
                }catch{
                    return $r.StdOut -match '(?i)\"logged(_in|In)?\"\s*:\s*true'
                }
            }
            'GOG'{$auth=Get-GogAuthPath;if(-not (Test-Path -LiteralPath $auth)){return $false};$r=Invoke-Captured $Tool @('--auth-config-path',$auth,'auth') -AllowFailure;return $r.ExitCode -eq 0 -and $r.StdOut -match 'access_token'}
            'Amazon'{
                $r=Invoke-Captured $Tool @('auth','--status') -AllowFailure
                if($r.ExitCode -ne 0 -or [string]::IsNullOrWhiteSpace($r.StdOut)){return $false}
                try{$status=$r.StdOut|ConvertFrom-Json;return [bool](Get-Prop $status 'LoggedIn' $false)}catch{return $r.StdOut -match '(?i)LoggedIn\s*[:=]\s*true'}
            }
            'HES'{return Test-HesAuthentication}
        }
    }catch{return $false}
    return $false
}

function Get-ArtUrlFromLegendaryGame{param($Game);$metadata=Get-Prop $Game 'metadata' $null;$keyImages=Get-Prop $metadata 'keyImages' @();foreach($type in @('DieselGameBoxTall','OfferImageTall','Thumbnail','DieselGameBox','OfferImageWide')){foreach($img in @($keyImages)){if([string](Get-Prop $img 'type' '') -eq $type){return [string](Get-Prop $img 'url' '')}}};return ''}
function Get-HeroUrlFromLegendaryGame{param($Game);$metadata=Get-Prop $Game 'metadata' $null;$keyImages=Get-Prop $metadata 'keyImages' @();foreach($type in @('DieselGameBox','OfferImageWide','DieselStoreFrontWide','Featured','Thumbnail')){foreach($img in @($keyImages)){if([string](Get-Prop $img 'type' '') -eq $type){return [string](Get-Prop $img 'url' '')}}};return ''}
function Test-ImageFile{
    param([string]$Path)
    try{
        if(-not (Test-Path -LiteralPath $Path -PathType Leaf)){return $false}
        $stream=[IO.File]::OpenRead($Path);try{$bytes=New-Object byte[] 12;$read=$stream.Read($bytes,0,12)}finally{$stream.Dispose()}
        if($read -lt 12){return $false}
        $jpg=($bytes[0]-eq 0xFF -and $bytes[1]-eq 0xD8)
        $png=($bytes[0]-eq 0x89 -and $bytes[1]-eq 0x50 -and $bytes[2]-eq 0x4E -and $bytes[3]-eq 0x47)
        $gif=([Text.Encoding]::ASCII.GetString($bytes,0,3)-eq 'GIF')
        $webp=([Text.Encoding]::ASCII.GetString($bytes,0,4)-eq 'RIFF' -and [Text.Encoding]::ASCII.GetString($bytes,8,4)-eq 'WEBP')
        return $jpg -or $png -or $gif -or $webp
    }catch{return $false}
}
function Save-Artwork{
    param([string]$ProviderId,[string]$GameKey,[string]$Url)
    if(-not $Url){return ''};if($Url.StartsWith('//')){$Url='https:'+$Url}
    $dir=Join-Path $ArtworkRoot $ProviderId;New-Item -ItemType Directory -Force -Path $dir|Out-Null
    $safe=($GameKey -replace '[^a-zA-Z0-9._-]','_');$target=Join-Path $dir "$safe.jpg"
    if(Test-ImageFile $target){return $target}
    Remove-Item -LiteralPath $target -Force -ErrorAction SilentlyContinue
    $temp="$target.download"
    try{
        Invoke-WebRequest -UseBasicParsing -Uri $Url -OutFile $temp -Headers @{'User-Agent'='HuymaierConsole/0.25.3'}
        if(-not (Test-ImageFile $temp)){throw 'The artwork endpoint did not return a supported image.'}
        Move-Item -LiteralPath $temp -Destination $target -Force;return $target
    }catch{Remove-Item -LiteralPath $temp -Force -ErrorAction SilentlyContinue;return ''}
}

function Test-EpicCatalogGame{
    param($Item)
    if($null -eq $Item){return $false}
    $id=[string](Get-Prop $Item 'app_name' '')
    $title=[string](Get-Prop $Item 'app_title' $id)
    if([string]::IsNullOrWhiteSpace($id) -or [string]::IsNullOrWhiteSpace($title)){return $false}
    $metadata=Get-Prop $Item 'metadata' $null
    $text=New-Object System.Text.StringBuilder
    foreach($value in @($id,$title,(Get-Prop $Item 'catalog_item_id' ''),(Get-Prop $Item 'namespace' ''),(Get-Prop $metadata 'title' ''),(Get-Prop $metadata 'description' ''))){if($value){[void]$text.AppendLine([string]$value)}}
    foreach($category in @(Get-Prop $metadata 'categories' @())){
        foreach($name in @('path','name','id')){$value=Get-Prop $category $name '';if($value){[void]$text.AppendLine([string]$value)}}
    }
    try{[void]$text.AppendLine(($Item|ConvertTo-Json -Depth 12 -Compress))}catch{}
    $combined=$text.ToString()
    # Legendary normally excludes UE content unless --include-ue is supplied.
    # Keep a second defensive filter because stale metadata and imported EGL
    # manifests can still contain engines, editors, plugins and Marketplace items.
    if($combined -match '(?im)^(Unreal Engine|Unreal Editor|Twinmotion|RealityCapture|MetaHuman|Quixel Bridge|Fab|Epic Online Services|Unreal Datasmith|Unreal Marketplace)\b'){return $false}
    if($combined -match '(?i)\b(UE_[45]\.[0-9]+|UnrealEditor|UE4Editor|Marketplace Asset|Engine Plugin|Editor Plugin|Asset Pack|Content Pack|Starter Content|Content Examples|Feature Pack|SDK|Mod Kit|Editor Symbols|Debug Symbols|Source Code|Marketplace Content|Engine Content|Plugin Content)\b'){return $false}
    if($combined -match '(?i)(Dev-Marketplace|Marketplace-Windows|UE[45]\+Dev-Marketplace|UnrealEngine|UEFN|VaultCache)'){return $false}
    if($combined -match '(?i)(^|[/\.\x5c])(engine|marketplace|plugins?|assets?|editors?|developer-tools)([/\.\x5c]|$)'){return $false}
    # Explicit DLC records belong under their base game instead of becoming
    # standalone library cards.
    try{if([bool](Get-Prop $Item 'is_dlc' $false)){return $false}}catch{}
    return $true
}

function Refresh-EpicCatalog{
    param([string]$Tool)
    Write-State $true 'Refreshing library' 'Reading owned Epic games...' 20
    $ownedResult=Invoke-Captured $Tool @('list','--platform','Windows','--json')
    $installedResult=Invoke-Captured $Tool @('list-installed','--json') -AllowFailure
    $owned=@();$installed=@();try{$owned=To-Array ($ownedResult.StdOut|ConvertFrom-Json)}catch{throw 'Legendary returned an unreadable owned-game list.'};try{$installed=To-Array ($installedResult.StdOut|ConvertFrom-Json)}catch{}
    $installedById=@{};foreach($item in $installed){$id=[string](Get-Prop $item 'app_name' '');if($id){$installedById[$id]=$item}}
    $games=New-Object System.Collections.ArrayList;$counter=0
    foreach($item in $owned){
        if(-not (Test-EpicCatalogGame $item)){continue}
        $id=[string](Get-Prop $item 'app_name' '');if(-not $id){continue};$name=[string](Get-Prop $item 'app_title' $id);$installedItem=$installedById[$id];$isInstalled=$null -ne $installedItem
        $artUrl=Get-ArtUrlFromLegendaryGame $item
        $heroUrl=Get-HeroUrlFromLegendaryGame $item
        $art=Save-Artwork 'Epic' $id $artUrl
        $hero=Save-Artwork 'Epic-Hero' $id $heroUrl
        [void]$games.Add([pscustomobject]@{Id=$id;Name=$name;Provider='Epic';Installed=$isInstalled;InstallPath=$(if($isInstalled){[string](Get-Prop $installedItem 'install_path' '')}else{''});ArtworkPath=$art;HeroArtworkPath=$hero;ArtworkUrl=$artUrl;HeroArtworkUrl=$heroUrl;Description='Epic Games library title';SizeText=$(if($isInstalled){'{0:N1} GB' -f ([double](Get-Prop $installedItem 'install_size' 0)/1GB)}else{''});UpdateAvailable=$false})
        $counter++;if(($counter%25)-eq 0){Write-State $true 'Refreshing library' "Processed $counter Epic titles..." ([math]::Min(85,20+[int]($counter/[math]::Max(1,$owned.Count)*65)))}
    }
    return [object[]]$games.ToArray()
}

function Refresh-AmazonCatalog{
    param([string]$Tool)
    Write-State $true 'Refreshing library' 'Synchronizing Amazon Games library...' 20
    Invoke-Captured $Tool @('library','sync')|Out-Null
    $result=Invoke-Captured $Tool @('library','list','--json')
    $raw=@();try{$raw=To-Array ($result.StdOut|ConvertFrom-Json)}catch{throw 'Nile returned an unreadable library list.'}
    $configPath=Join-Path (Join-Path $env:NILE_CONFIG_PATH 'nile') 'installed.json';$installed=@();if(Test-Path -LiteralPath $configPath){try{$installed=To-Array (Get-Content -Raw -LiteralPath $configPath|ConvertFrom-Json)}catch{}}
    $installedById=@{};foreach($item in $installed){$id=[string](Get-Prop $item 'id' '');if($id){$installedById[$id]=$item}};foreach($item in @(Read-ManagedInstalls)){if([string](Get-Prop $item 'Provider' '') -eq 'Amazon'){$installedById[[string](Get-Prop $item 'Id' '')]=[pscustomobject]@{id=[string](Get-Prop $item 'Id' '');path=[string](Get-Prop $item 'Path' '')}}}
    $games=New-Object System.Collections.ArrayList
    foreach($item in $raw){
        $product=Get-Prop $item 'product' $item;$id=[string](Get-Prop $product 'id' (Get-Prop $item 'id' ''));if(-not $id){continue};$name=[string](Get-Prop $product 'title' $id);$installedItem=$installedById[$id]
        $images=Get-Prop $product 'images' @();$url='';foreach($img in @($images)){if(-not $url){$url=[string](Get-Prop $img 'url' '')}}
        $detail=Get-Prop $product 'productDetail' $null
        $details=Get-Prop $detail 'details' $null
        if(-not $url){foreach($candidate in @((Get-Prop $details 'pgCrownImageUrl' ''),(Get-Prop $product 'iconUrl' ''),(Get-Prop $details 'logoUrl' ''),(Get-Prop $detail 'imageUrl' ''))){if(-not $url -and $candidate){$url=[string]$candidate}}}
        $heroUrl='';foreach($candidate in @((Get-Prop $details 'backgroundUrl1' ''),(Get-Prop $details 'backgroundUrl2' ''),(Get-Prop $product 'backgroundUrl1' ''))){if(-not $heroUrl -and $candidate){$heroUrl=[string]$candidate}}
        $description=[string](Get-Prop $details 'shortDescription' (Get-Prop $product 'description' 'Amazon Games library title'))
        [void]$games.Add([pscustomobject]@{Id=$id;Name=$name;Provider='Amazon';Installed=($null -ne $installedItem);InstallPath=$(if($installedItem){[string](Get-Prop $installedItem 'path' '')}else{''});ArtworkPath=(Save-Artwork 'Amazon' $id $url);HeroArtworkPath=(Save-Artwork 'Amazon-Hero' $id $heroUrl);ArtworkUrl=$url;HeroArtworkUrl=$heroUrl;Description=$description;SizeText='';UpdateAvailable=$false})
    }
    return [object[]]$games.ToArray()
}

function Test-UsefulProviderTitle{
    param([string]$Title)
    if([string]::IsNullOrWhiteSpace($Title)){return $false}
    $trim=$Title.Trim()
    if($trim -match '^\d{6,}$'){return $false}
    if($trim -match '^(?i)(game|unknown|untitled)$'){return $false}
    return $true
}

function Get-GogCatalogDetail{
    param([string]$Id,[hashtable]$Headers)
    $account=$null;$product=$null
    try{$account=Invoke-RestMethod -Uri "https://embed.gog.com/account/gameDetails/$Id.json" -Headers $Headers}catch{}
    $title=[string](Get-Prop $account 'title' (Get-Prop $account 'name' ''))
    if(-not (Test-UsefulProviderTitle $title)){
        try{$product=Invoke-RestMethod -Uri "https://api.gog.com/products/$Id?locale=en-US" -Headers @{'User-Agent'='HuymaierConsole/0.25.3'}}catch{}
        $title=[string](Get-Prop $product 'title' (Get-Prop $product 'name' ''))
    }
    if(-not (Test-UsefulProviderTitle $title)){return $null}

    $url='';$heroUrl=''
    $images=Get-Prop $account 'images' $null
    foreach($candidate in @(
        (Get-Prop $images 'menuNotificationAv' ''),
        (Get-Prop $images 'logo2x' ''),
        (Get-Prop $images 'logo' ''),
        (Get-Prop $account 'image' '')
    )){if(-not $url -and $candidate){$url=[string]$candidate}}
    foreach($candidate in @((Get-Prop $images 'background' ''),(Get-Prop $account 'backgroundImage' ''))){if(-not $heroUrl -and $candidate){$heroUrl=[string]$candidate}}
    if($null -ne $product){
        $productImages=Get-Prop $product 'images' $null
        if(-not $url){foreach($candidate in @((Get-Prop $productImages 'logo2x' ''),(Get-Prop $productImages 'logo' ''),(Get-Prop $productImages 'icon' ''))){if(-not $url -and $candidate){$url=[string]$candidate}}}
        if(-not $heroUrl){$heroUrl=[string](Get-Prop $productImages 'background' '')}
    }
    if(-not $url){$url=$heroUrl}
    $description=[string](Get-Prop $account 'description' (Get-Prop $product 'description' 'DRM-free GOG library title'))
    return [pscustomobject]@{Title=$title;ArtworkUrl=$url;HeroArtworkUrl=$heroUrl;Description=$description}
}

function Refresh-GogCatalog{
    param([string]$Tool)
    $authPath=Get-GogAuthPath
    $authResult=Invoke-Captured $Tool @('--auth-config-path',$authPath,'auth') -AllowFailure
    if($authResult.ExitCode -ne 0 -or -not $authResult.StdOut){throw 'GOG authentication is required.'}
    $auth=$null;try{$auth=$authResult.StdOut|ConvertFrom-Json}catch{try{$auth=Get-Content -Raw -LiteralPath $authPath|ConvertFrom-Json}catch{}}
    $token=[string](Get-Prop $auth 'access_token' '');if(-not $token){throw 'GOG did not provide a usable access token.'}
    Write-State $true 'Refreshing library' 'Reading owned GOG games...' 20
    $headers=@{Authorization="Bearer $token";'User-Agent'='HuymaierConsole/0.25.3'}
    $owned=Invoke-RestMethod -Uri 'https://embed.gog.com/user/data/games' -Headers $headers
    $ids=New-Object System.Collections.ArrayList;$seenIds=@{}
    foreach($idValue in @(Get-Prop $owned 'owned' @())){
        $id=[string]$idValue;if(-not $id){continue};$key=$id.ToLowerInvariant();if($seenIds.ContainsKey($key)){continue};$seenIds[$key]=$true;[void]$ids.Add($id)
    }
    $installedMap=@{}
    foreach($i in @(Read-ManagedInstalls)){if([string](Get-Prop $i 'Provider' '') -eq 'GOG'){$installedMap[[string](Get-Prop $i 'Id' '')]=[pscustomobject]@{install_path=[string](Get-Prop $i 'Path' '')}}}
    $heroicInstalled=Join-Path $env:APPDATA 'heroic\gog_store\installed.json';if(Test-Path -LiteralPath $heroicInstalled){try{foreach($i in @(Get-Content -Raw -LiteralPath $heroicInstalled|ConvertFrom-Json)){$installedMap[[string](Get-Prop $i 'appName' (Get-Prop $i 'id' ''))]=$i}}catch{}}
    $games=New-Object System.Collections.ArrayList;$indexByTitle=@{};$count=0
    foreach($id in @($ids)){
        $resolved=Get-GogCatalogDetail $id $headers
        if($null -eq $resolved){Write-ProviderLog "Skipped unresolved GOG product $id instead of exposing a numeric placeholder." 'WARN';continue}
        $name=[string]$resolved.Title;$titleKey=(($name.ToLowerInvariant() -replace '[™®©]','' -replace '[^a-z0-9]+',' ').Trim())
        $installed=$installedMap[$id]
        $entry=[pscustomobject]@{
            Id=$id;Name=$name;Provider='GOG';Installed=($null -ne $installed);
            InstallPath=$(if($installed){[string](Get-Prop $installed 'install_path' (Get-Prop $installed 'installPath' ''))}else{''});
            ArtworkPath=(Save-Artwork 'GOG' $id ([string]$resolved.ArtworkUrl));HeroArtworkPath=(Save-Artwork 'GOG-Hero' $id ([string]$resolved.HeroArtworkUrl));ArtworkUrl=[string]$resolved.ArtworkUrl;HeroArtworkUrl=[string]$resolved.HeroArtworkUrl;
            Description=[string]$resolved.Description;SizeText='';InstallSizeBytes=0;UpdateAvailable=$false
        }
        if($titleKey -and $indexByTitle.ContainsKey($titleKey)){
            $existingIndex=[int]$indexByTitle[$titleKey];$existing=$games[$existingIndex]
            if([bool]$entry.Installed -and -not [bool](Get-Prop $existing 'Installed' $false)){$games[$existingIndex]=$entry}
        }else{
            if($titleKey){$indexByTitle[$titleKey]=$games.Count};[void]$games.Add($entry)
        }
        $count++;if(($count%15)-eq 0){Write-State $true 'Refreshing library' "Processed $count GOG titles..." ([math]::Min(85,20+[int]($count/[math]::Max(1,$ids.Count)*65)))}
    }
    return [object[]]$games.ToArray()
}

function Refresh-HesCatalog{
    param([string]$Tool)
    if(-not (Test-HesAuthentication)){throw 'HES pairing is required.'}
    Write-State $true 'Refreshing library' 'Reading the HES game library...' 20
    $rawList=New-Object System.Collections.ArrayList;$seenIds=@{};$offset=0;$pageSize=100;$pageNumber=0
    do{
        $response=Invoke-HesRequest -Method GET -Path ("/api/roms?limit=$pageSize&offset=$offset")
        $page=@(Get-HesCollectionItems $response)
        $pageCount=@($page).Count
        foreach($rom in @($page)){
            $rid=[string](Get-Prop $rom 'id' '')
            if($rid -and -not $seenIds.ContainsKey($rid)){$seenIds[$rid]=$true;[void]$rawList.Add($rom)}
        }
        $offset+=$pageCount
        $pageNumber++
        $total=Get-HesResponseTotal $response
        Write-ProviderLog "HES ROM page $pageNumber returned $pageCount item(s); collected $($rawList.Count), reported total $total."
        $continue=($pageCount -ge $pageSize) -or ($total -gt $offset)
    }while($continue -and $pageCount -gt 0 -and $pageNumber -lt 100)

    $raw=@($rawList.ToArray())
    $rawCount=@($raw).Count
    $games=New-Object System.Collections.ArrayList;$count=0
    foreach($rom in @($raw)){
        $id=[string](Get-Prop $rom 'id' '')
        if(-not $id){continue}
        $name=[string](Get-Prop $rom 'name' (Get-Prop $rom 'fs_name' (Get-Prop $rom 'title' $id)))
        $platform=Get-HesPlatformName $rom
        $artUrl=Get-HesArtworkUrl $rom
        $description=[string](Get-Prop $rom 'summary' (Get-Prop $rom 'description' "Available from HES on $platform."))
        $sizeValue=Get-Prop $rom 'fs_size_bytes' (Get-Prop $rom 'size' 0)
        $sizeText='';try{if([double]$sizeValue -gt 0){$sizeText='{0:N1} GB' -f ([double]$sizeValue/1GB)}}catch{}

        # Download a single cached cover during the provider refresh. The shared
        # artwork worker may later replace/augment it, but duplicating the same
        # download for both card and hero art made HES refreshes unnecessarily slow.
        $cachedArt=Save-HesArtwork $id $artUrl
        [void]$games.Add([pscustomobject]@{
            Id=$id;Name=$name;Provider='HES';Platform=$platform;Installed=$true;InstallPath=(Get-HesApiUrl);
            ArtworkPath=$cachedArt;HeroArtworkPath=$cachedArt;ArtworkUrl=$artUrl;HeroArtworkUrl=$artUrl;Description=$description;SizeText=$sizeText;
            UpdateAvailable=$false;LaunchTarget=((Get-HesServerUrl)+"/rom/$id")
        })
        $count++
        if(($count%50)-eq 0){
            $denominator=[math]::Max(1,$rawCount)
            Write-State $true 'Refreshing library' "Processed $count HES titles..." ([math]::Min(90,20+[int]($count/$denominator*70)))
        }
    }
    return [object[]]$games.ToArray()
}

function Refresh-ProviderCatalog{
    param([string]$Tool)
    Set-ProviderEnvironment
    $authenticated=Test-Authenticated $Tool
    $games=@();$providerError='';$status='Backend ready.'
    if($authenticated){
        try{
            $games=@(switch($Provider){'Epic'{Refresh-EpicCatalog $Tool}'GOG'{Refresh-GogCatalog $Tool}'Amazon'{Refresh-AmazonCatalog $Tool}'HES'{Refresh-HesCatalog $Tool}})
            $gameCount=@($games).Count
            $status="$gameCount owned game(s) loaded."
        }catch{$providerError=$_.Exception.Message;$status='Library refresh failed.';Write-ProviderLog $providerError 'ERROR'}
    }else{$status='Account sign-in required.'}
    $definition=switch($Provider){'Epic'{@('Epic Games','Legendary')}'GOG'{@('GOG','gogdl')}'Amazon'{@('Amazon Games','Nile')}'HES'{@('Huymaier Entertainment System','RomM API')}}
    $node=[pscustomobject]@{Id=$Provider;Name=$definition[0];Backend=$definition[1];SchemaVersion=2;ToolReady=$true;Authenticated=$authenticated;ToolPath=$Tool;Status=$status;Error=$providerError;Games=$games;Updated=(Get-Date).ToString('o')}
    Save-ProviderNode $node
    if($providerError){throw $providerError}
}

function Invoke-ProviderGameCommand{
    param([string]$Tool)
    Set-ProviderEnvironment
    if(-not $GameId){throw 'No game identifier was supplied.'}
    if(-not $InstallPath){$InstallPath=Join-Path 'C:\Games' $Provider}
    New-Item -ItemType Directory -Force -Path $InstallPath|Out-Null
    switch($Provider){
        'HES'{throw 'HES titles launch through the configured console browser and are not locally modified by this provider worker.'}
        'Epic'{
            switch($Mode){
                'Install'{Invoke-EpicLegendaryTransfer $Tool @('-y','install',$GameId,'--base-path',$InstallPath,'--platform','Windows','--skip-sdl')|Out-Null;Save-ManagedInstall $GameId $GameName $InstallPath}
                'Update'{Invoke-EpicLegendaryTransfer $Tool @('-y','install',$GameId,'--update-only')|Out-Null}
                'Verify'{Invoke-Captured $Tool @('verify',$GameId)|Out-Null}
                'Move'{Invoke-Captured $Tool @('-y','move',$GameId,$InstallPath)|Out-Null;Save-ManagedInstall $GameId $GameName $InstallPath}
                'Uninstall'{Invoke-Captured $Tool @('-y','uninstall',$GameId)|Out-Null;Remove-ManagedInstall $GameId}
                'Launch'{Start-Process -FilePath $Tool -ArgumentList @('launch',$GameId) | Out-Null}
            }
        }
        'Amazon'{
            switch($Mode){
                'Install'{Invoke-Captured $Tool @('install',$GameId,'--base-path',$InstallPath)|Out-Null;Save-ManagedInstall $GameId $GameName $InstallPath}
                'Update'{Invoke-Captured $Tool @('update',$GameId,'--base-path',$InstallPath)|Out-Null}
                'Verify'{Invoke-Captured $Tool @('verify',$GameId,'--base-path',$InstallPath)|Out-Null}
                'Move'{throw 'Amazon/Nile does not expose a safe move command. Uninstall and reinstall to the new location.'}
                'Uninstall'{Invoke-Captured $Tool @('uninstall',$GameId)|Out-Null;Remove-ManagedInstall $GameId}
                'Launch'{Start-Process -FilePath $Tool -ArgumentList @('launch',$GameId,'--no-wine') | Out-Null}
            }
        }
        'GOG'{
            $auth=Get-GogAuthPath
            switch($Mode){
                'Install'{$safeName=if($GameName){$GameName -replace '[<>:"/\|?*]','_'}else{$GameId};$exactPath=Join-Path $InstallPath $safeName;Invoke-Captured $Tool @('--auth-config-path',$auth,'download',$GameId,'--path',$exactPath,'--platform','windows')|Out-Null;Save-ManagedInstall $GameId $GameName $exactPath}
                'Update'{$managed=Get-ManagedInstall $GameId;$exactPath=if($managed){[string](Get-Prop $managed 'Path' $InstallPath)}else{$InstallPath};Invoke-Captured $Tool @('--auth-config-path',$auth,'update',$GameId,'--path',$exactPath,'--platform','windows')|Out-Null}
                'Verify'{$managed=Get-ManagedInstall $GameId;$exactPath=if($managed){[string](Get-Prop $managed 'Path' $InstallPath)}else{$InstallPath};Invoke-Captured $Tool @('--auth-config-path',$auth,'repair',$GameId,'--path',$exactPath,'--platform','windows')|Out-Null}
                'Move'{$managed=Get-ManagedInstall $GameId;if(-not $managed){throw 'Only GOG installations managed by Huymaier Console can be moved safely.'};$current=[string](Get-Prop $managed 'Path' '');if(-not $current -or -not (Test-Path -LiteralPath $current -PathType Container)){throw 'The current managed GOG install folder was not found.'};New-Item -ItemType Directory -Force -Path $InstallPath|Out-Null;$leaf=Split-Path -Leaf $current;$destination=Join-Path $InstallPath $leaf;if([string]::Equals($current,$destination,[StringComparison]::OrdinalIgnoreCase)){throw 'The game is already installed in that location.'};if(Test-Path -LiteralPath $destination){throw 'A folder with the same game name already exists at the destination.'};Move-Item -LiteralPath $current -Destination $destination;Save-ManagedInstall $GameId $GameName $destination}
                'Uninstall'{$managed=Get-ManagedInstall $GameId;if(-not $managed){throw 'This GOG title was not installed by Huymaier Console, so it will not delete an unverified folder.'};$exactPath=[string](Get-Prop $managed 'Path' '');if(-not $exactPath -or -not (Test-Path -LiteralPath $exactPath -PathType Container)){throw 'The managed GOG install folder was not found.'};Remove-Item -LiteralPath $exactPath -Recurse -Force;Remove-ManagedInstall $GameId}
                'Launch'{$managed=Get-ManagedInstall $GameId;$exactPath=if($managed){[string](Get-Prop $managed 'Path' $InstallPath)}else{$InstallPath};Start-Process -FilePath $Tool -ArgumentList @('--auth-config-path',$auth,'launch',$exactPath,$GameId,'--platform','windows','--no-wine') | Out-Null}
            }
        }
    }
}


# v0.25.2: scalable platform-first HES/RomM enumeration with flat record output.
# A normal refresh loads the small platform index only. Games are fetched and
# cached one platform at a time when that platform is selected in Huymaier
# Console. This avoids parsing and artwork-downloading 20,000+ ROMs at startup.
function Test-HesPlatformRecord{
    param($Value)
    if($null -eq $Value -or $Value -is [string] -or $Value -is [ValueType]){return $false}
    $id=[string](Get-Prop $Value 'id' (Get-Prop $Value 'platform_id' (Get-Prop $Value 'platformId' '')))
    if(-not $id){return $false}
    foreach($name in @('display_name','custom_name','name','igdb_name','fs_slug','slug')){
        if([string](Get-Prop $Value $name '')){return $true}
    }
    return $false
}
function Add-HesPlatformCandidates{
    param($Value,[System.Collections.ArrayList]$List,[hashtable]$Seen,[int]$Depth=0)
    if($null -eq $Value -or $Depth -gt 10 -or $Value -is [string] -or $Value -is [ValueType]){return}

    if(Test-HesPlatformRecord $Value){
        $id=[string](Get-Prop $Value 'id' (Get-Prop $Value 'platform_id' (Get-Prop $Value 'platformId' '')))
        $key=$id.ToLowerInvariant()
        if(-not $Seen.ContainsKey($key)){
            $Seen[$key]=$true
            [void]$List.Add($Value)
        }
        return
    }

    # Prefer common/documented wrapper names first. In some RomM 5.1
    # responses, items/platforms is itself an object map rather than an array.
    foreach($name in @('items','results','platforms','data')){
        $nested=Get-Prop $Value $name $null
        if($null -ne $nested){Add-HesPlatformCandidates $nested $List $Seen ($Depth+1)}
    }
    if($List.Count -gt 0){return}

    if($Value -is [System.Collections.IDictionary]){
        foreach($key in @($Value.Keys)){
            Add-HesPlatformCandidates $Value[$key] $List $Seen ($Depth+1)
        }
        return
    }

    if($Value -is [System.Collections.IEnumerable] -and -not ($Value -is [string])){
        foreach($item in $Value){Add-HesPlatformCandidates $item $List $Seen ($Depth+1)}
        return
    }

    # Last-resort support for JSON object maps such as
    # {"1":{platform...},"2":{platform...}}.
    try{
        foreach($property in @($Value.PSObject.Properties)){
            if($property.Name -in @('pagination','meta','links','total','count','limit','offset')){continue}
            Add-HesPlatformCandidates $property.Value $List $Seen ($Depth+1)
        }
    }catch{}
}
function Get-HesPlatformItems{
    $lastError=''
    foreach($path in @('/api/platforms?limit=1000','/api/platforms')){
        try{
            $response=Invoke-HesRequest -Method GET -Path $path
            $found=New-Object System.Collections.ArrayList
            $seen=@{}
            Add-HesPlatformCandidates $response $found $seen 0
            if($found.Count -gt 0){
                Write-ProviderLog "HES platform payload resolved to $($found.Count) platform record(s)."
                return [object[]]$found.ToArray()
            }
            Write-ProviderLog "HES platform response from ${path} contained no recognizable platform records." 'WARN'
        }catch{$lastError=$_.Exception.Message}
    }
    if($lastError){throw "HES platform enumeration failed: $lastError"}
    return @()
}
function Get-HesPlatformDisplayName{
    param($Platform)
    foreach($name in @('display_name','custom_name','name','igdb_name','fs_slug','slug')){$value=[string](Get-Prop $Platform $name '');if($value){return $value}}
    return 'Unknown platform'
}
function Get-HesPlatformExpectedCount{
    param($Platform)
    foreach($name in @('rom_count','roms_count','n_roms','romCount','romsCount','game_count','gameCount','count')){$value=Get-Prop $Platform $name $null;if($null -ne $value){try{return [int64]$value}catch{}}}
    return 0
}
function Convert-HesPlatformToMarker{
    param($Platform)
    $platformId=[string](Get-Prop $Platform 'id' (Get-Prop $Platform 'platform_id' (Get-Prop $Platform 'platformId' '')))
    if(-not $platformId){return $null}
    $platformName=Get-HesPlatformDisplayName $Platform
    $platformSlug=[string](Get-Prop $Platform 'slug' (Get-Prop $Platform 'fs_slug' ''))
    $count=Get-HesPlatformExpectedCount $Platform
    $logoUrl=''
    foreach($name in @('url_logo','logo_url','icon_url','path_logo')){$value=[string](Get-Prop $Platform $name '');if($value){$logoUrl=Join-HesUrl $value;break}}
    $cached=''
    if($logoUrl){try{$cached=Save-HesArtwork ("platform_"+$platformId) $logoUrl}catch{Write-ProviderLog "Platform artwork failed for ${platformName}: $($_.Exception.Message)" 'WARN'}}
    return [pscustomobject]@{
        Id=("hes-platform:"+$platformId);Name=$platformName;Provider='HES';Platform=$platformName;
        PlatformId=$platformId;PlatformSlug=$platformSlug;PlatformGameCount=$count;IsPlatformMarker=$true;
        Installed=$true;InstallPath=(Get-HesApiUrl);ArtworkPath=$cached;HeroArtworkPath=$cached;
        ArtworkUrl=$logoUrl;HeroArtworkUrl=$logoUrl;Description=("$count games available from HES.");
        SizeText='';UpdateAvailable=$false;LaunchTarget=''
    }
}
function Convert-HesRomToCatalogGame{
    param($Rom,$Platform,[switch]$CacheArtwork)
    $id=[string](Get-Prop $Rom 'id' '')
    if(-not $id){return $null}
    $platformId=[string](Get-Prop $Platform 'id' (Get-Prop $Rom 'platform_id' ''))
    $platformSlug=[string](Get-Prop $Platform 'slug' (Get-Prop $Platform 'fs_slug' (Get-Prop $Rom 'platform_slug' '')))
    $platformName=if($null -ne $Platform){Get-HesPlatformDisplayName $Platform}else{Get-HesPlatformName $Rom}
    $name=[string](Get-Prop $Rom 'name' '')
    if(-not $name){$name=[string](Get-Prop $Rom 'fs_name_no_ext' '')}
    if(-not $name){$name=[string](Get-Prop $Rom 'fs_name' '')}
    if(-not $name){$name=[string](Get-Prop $Rom 'title' $id)}
    $artUrl=Get-HesArtworkUrl $Rom
    $heroUrl=Get-HesHeroArtworkUrl $Rom $artUrl
    $description=[string](Get-Prop $Rom 'summary' '')
    if(-not $description){$description=[string](Get-Prop $Rom 'description' '')}
    if(-not $description){$description="Available from HES on $platformName."}
    $sizeValue=Get-Prop $Rom 'fs_size_bytes' (Get-Prop $Rom 'size' 0)
    $sizeText='';try{if([double]$sizeValue -gt 0){$sizeText='{0:N1} GB' -f ([double]$sizeValue/1GB)}}catch{}
    $cachedArt='';$cachedHero=''
    if($CacheArtwork){
        try{$cachedArt=Save-HesArtwork $id $artUrl}catch{Write-ProviderLog "Cover download failed for ${name}: $($_.Exception.Message)" 'WARN'}
        if($heroUrl -and -not [string]::Equals($heroUrl,$artUrl,[StringComparison]::OrdinalIgnoreCase)){try{$cachedHero=Save-HesArtwork ("${id}_hero") $heroUrl}catch{}}
        if(-not $cachedHero){$cachedHero=$cachedArt}
    }
    return [pscustomobject]@{
        Id=$id;Name=$name;Provider='HES';Platform=$platformName;PlatformId=$platformId;PlatformSlug=$platformSlug;
        IsPlatformMarker=$false;Installed=$true;InstallPath=(Get-HesApiUrl);ArtworkPath=$cachedArt;HeroArtworkPath=$cachedHero;
        ArtworkUrl=$artUrl;HeroArtworkUrl=$heroUrl;Description=$description;SizeText=$sizeText;
        UpdateAvailable=$false;LaunchTarget=((Get-HesServerUrl)+"/rom/$id")
    }
}
function Get-HesRomPlatformId{
    param($Rom)
    foreach($name in @('platform_id','platformId')){
        $value=[string](Get-Prop $Rom $name '')
        if($value){return $value}
    }
    $platform=Get-Prop $Rom 'platform' $null
    if($null -ne $platform){
        if($platform -is [string] -or $platform -is [ValueType]){return [string]$platform}
        $value=[string](Get-Prop $platform 'id' '')
        if($value){return $value}
    }
    return ''
}
function Get-HesRomsForPlatform{
    param($Platform)
    $platformId=[string](Get-Prop $Platform 'id' (Get-Prop $Platform 'platform_id' (Get-Prop $Platform 'platformId' '')))
    if(-not $platformId){return @()}

    # RomM uses the plural platform_ids query parameter. The singular
    # platform_id form is accepted by the server but does not filter the ROM
    # collection, which can silently return the entire library.
    $encoded=[uri]::EscapeDataString($platformId)
    $expected=Get-HesPlatformExpectedCount $Platform
    $all=New-Object System.Collections.ArrayList
    $seen=@{}
    $offset=0
    $limit=100
    $pageNumber=0

    do{
        $path="/api/roms?platform_ids=$encoded&limit=$limit&offset=$offset&order_by=name&order_dir=asc&group_by_meta_id=false&with_char_index=false&with_filter_values=false"
        $response=Invoke-HesRequest -Method GET -Path $path
        $page=@(Get-HesCollectionItems $response)
        $pageCount=[int]$page.Count
        $total=Get-HesResponseTotal $response
        $foreign=0

        foreach($rom in $page){
            $romPlatformId=Get-HesRomPlatformId $rom
            if($romPlatformId -and -not [string]::Equals($romPlatformId,$platformId,[StringComparison]::OrdinalIgnoreCase)){
                $foreign++
                continue
            }
            $id=[string](Get-Prop $rom 'id' '')
            if($id -and -not $seen.ContainsKey($id)){
                $seen[$id]=$true
                [void]$all.Add($rom)
            }
        }

        if($foreign -gt 0){
            throw "HES returned $foreign ROM(s) from another platform while filtering platform $platformId. The unfiltered response was rejected."
        }

        $offset+=$pageCount
        $pageNumber++
        Write-ProviderLog "HES platform $platformId page $pageNumber returned $pageCount item(s); collected $($all.Count), reported total $total."

        # A wildly larger total indicates that the server ignored the filter.
        # Allow a small margin because RomM's platform counts can lag a scan.
        if($expected -gt 0 -and $total -gt ([Math]::Max([double]($expected+10),[double][Math]::Ceiling($expected*1.10)))){
            throw "HES reported $total ROM(s) for platform $platformId although the platform index reports $expected. The unfiltered response was rejected."
        }

        $continue=($pageCount -ge $limit) -or ($total -gt $offset)
    }while($continue -and $pageCount -gt 0 -and $pageNumber -lt 500)

    return [object[]]$all.ToArray()
}
function Refresh-HesCatalog{
    param([string]$Tool)
    if(-not (Test-HesAuthentication)){throw 'HES account connection is required.'}
    Write-State $true 'Refreshing library' 'Reading HES platforms...' 15
    $platforms=@(Get-HesPlatformItems)
    if($platforms.Count -eq 0){throw 'HES returned no platforms. The existing HES catalog was preserved.'}
    $markers=New-Object System.Collections.ArrayList
    foreach($platform in $platforms){$marker=Convert-HesPlatformToMarker $platform;if($null -ne $marker){[void]$markers.Add($marker)}}
    $expectedTotal=0;foreach($platform in $platforms){$expectedTotal+=Get-HesPlatformExpectedCount $platform}
    Write-ProviderLog "HES returned $($platforms.Count) platform(s) with $expectedTotal reported ROM(s)."

    # A normal account refresh updates only the platform index. Full game lists
    # are pulled lazily for the selected platform using GameId as platform id.
    if([string]::IsNullOrWhiteSpace($GameId)){
        $script:HesRefreshPlatformCount=$markers.Count
        return [object[]]$markers.ToArray()
    }

    $target=$null
    foreach($platform in $platforms){
        $id=[string](Get-Prop $platform 'id' (Get-Prop $platform 'platform_id' (Get-Prop $platform 'platformId' '')));$slug=[string](Get-Prop $platform 'slug' (Get-Prop $platform 'fs_slug' ''))
        if([string]::Equals($id,$GameId,[StringComparison]::OrdinalIgnoreCase) -or [string]::Equals($slug,$GameId,[StringComparison]::OrdinalIgnoreCase)){$target=$platform;break}
    }
    if($null -eq $target){throw "HES platform '$GameId' was not found on the server."}
    $platformName=Get-HesPlatformDisplayName $target
    Write-State $true 'Refreshing library' "Loading $platformName games..." 22
    $roms=@(Get-HesRomsForPlatform $target)
    $expected=Get-HesPlatformExpectedCount $target
    if($expected -gt 0 -and $roms.Count -eq 0){throw "HES reports $expected game(s) for $platformName, but the client token returned none."}
    $result=New-Object System.Collections.ArrayList
    foreach($marker in $markers){[void]$result.Add($marker)}
    $count=0
    foreach($rom in $roms){
        $count++
        # Prime only the first shelf-worth of artwork. The serialized artwork
        # worker fills the rest without blocking platform loading.
        $game=Convert-HesRomToCatalogGame $rom $target -CacheArtwork:($count -le 24)
        if($null -ne $game){[void]$result.Add($game)}
        if(($count % 100) -eq 0){Write-State $true 'Refreshing library' "Loaded $count $platformName games..." ([math]::Min(92,22+[int](($count/[math]::Max(1,$roms.Count))*68)))}
    }
    $script:HesRefreshPlatformCount=$markers.Count
    return [object[]]$result.ToArray()
}
function Get-ExistingProviderNode{
    param([string]$ProviderId)
    $catalog=Read-Catalog
    foreach($node in @(Get-Prop $catalog 'Providers' @())){if([string]::Equals([string](Get-Prop $node 'Id' ''),$ProviderId,[StringComparison]::OrdinalIgnoreCase)){return $node}}
    return $null
}
function Refresh-ProviderCatalog{
    param([string]$Tool)
    Set-ProviderEnvironment
    $authenticated=Test-Authenticated $Tool
    $previousNode=Get-ExistingProviderNode $Provider
    $previousGames=@(Get-Prop $previousNode 'Games' @())
    $games=@();$providerError='';$status='Backend ready.'
    if($authenticated){
        try{
            $games=@(switch($Provider){'Epic'{Refresh-EpicCatalog $Tool}'GOG'{Refresh-GogCatalog $Tool}'Amazon'{Refresh-AmazonCatalog $Tool}'HES'{Refresh-HesCatalog $Tool}})
            if($Provider -eq 'HES'){
                $newMarkers=@($games|Where-Object{[bool](Get-Prop $_ 'IsPlatformMarker' $false)})
                $newActual=@($games|Where-Object{-not [bool](Get-Prop $_ 'IsPlatformMarker' $false)})
                $previousActual=@($previousGames|Where-Object{-not [bool](Get-Prop $_ 'IsPlatformMarker' $false)})
                if([string]::IsNullOrWhiteSpace($GameId)){
                    # Platform-index refreshes retain any platform libraries that
                    # were already loaded in this Windows account.
                    $games=@($newMarkers+$previousActual)
                    $status="$($newMarkers.Count) HES platform(s) loaded. Select a platform to load its games."
                }else{
                    $kept=@($previousActual|Where-Object{-not [string]::Equals([string](Get-Prop $_ 'PlatformId' ''),$GameId,[StringComparison]::OrdinalIgnoreCase)})
                    $games=@($newMarkers+$kept+$newActual)
                    $status="$($newActual.Count) $GameName game(s) loaded; $($newMarkers.Count) HES platform(s) available."
                }
                if($newMarkers.Count -eq 0){throw 'HES returned an empty platform index.'}
            }else{
                $gameCount=$games.Count
                $status="$gameCount owned game(s) loaded."
            }
        }catch{
            $providerError=$_.Exception.Message
            if($Provider -eq 'HES' -and $previousGames.Count -gt 0){$games=$previousGames;$status="Library refresh failed; $($previousGames.Count) previous HES game(s) retained."}
            else{$status='Library refresh failed.'}
            Write-ProviderLog $providerError 'ERROR'
        }
    }else{$status='Account sign-in required.'}
    $definition=switch($Provider){'Epic'{@('Epic Games','Legendary')}'GOG'{@('GOG','gogdl')}'Amazon'{@('Amazon Games','Nile')}'HES'{@('Huymaier Entertainment System','RomM API')}}
    $node=[pscustomobject]@{Id=$Provider;Name=$definition[0];Backend=$definition[1];SchemaVersion=2;ToolReady=$true;Authenticated=$authenticated;ToolPath=$Tool;Status=$status;Error=$providerError;Games=$games;Updated=(Get-Date).ToString('o')}
    Save-ProviderNode $node
    if($providerError){throw $providerError}
}

try{
    Write-State $true 'Starting' "$Mode $GameName" 0
    Set-ProviderEnvironment
    $tool=Get-LocalToolPath
    if($Mode -eq 'Setup'){
        $tool=Ensure-Tool
        Refresh-ProviderCatalog $tool
        Write-State $false 'Complete' $(if($Provider -eq 'HES'){"HES API is ready at $(Get-HesApiUrl)."}else{"$Provider direct backend is ready."}) 100
        exit 0
    }
    if(-not $tool){$tool=Ensure-Tool}
    if($Mode -eq 'Authenticate'){
        Write-State $true 'Account sign-in' "Complete the $Provider sign-in flow." 10
        switch($Provider){
            'Epic'{
                Write-State $true 'Account sign-in' 'Checking for an existing Epic Games Launcher session...' 15
                $import=Invoke-Captured $tool @('auth','--import') -AllowFailure
                if($import.ExitCode -ne 0 -or -not (Test-Authenticated $tool)){
                    if(Wait-HcNativeBrowserReady 3000){
                        Write-State $true 'Account sign-in' 'Sign in to Epic in the Huymaier browser.' 20
                        $request=New-HcNativeBrowserRequest -Url 'https://legendary.gl/epiclogin' -Completion 'EpicAuthorizationCode' -Title 'Connect Epic Games Account' -TimeoutSec 600
                        $epicCode=Wait-HcNativeBrowserResult $request 600
                        if([string]::IsNullOrWhiteSpace($epicCode)){throw 'Epic did not return an authorization code.'}
                        Invoke-Captured $tool @('auth','--code',$epicCode)|Out-Null
                    }else{
                        Write-State $true 'Account sign-in' 'Complete the Epic sign-in window.' 20
                        Invoke-Interactive $tool @('auth')
                    }
                }
            }
            'GOG'{
                if(-not $AuthCode){$AuthCode=Get-GogAuthorizationCodeInteractive}
                else{$urlCode=Get-CodeFromGogUrl $AuthCode;if($urlCode){$AuthCode=$urlCode}}
                if([string]::IsNullOrWhiteSpace($AuthCode)){throw 'GOG did not return an authorization code.'}
                Invoke-Captured $tool @('--auth-config-path',(Get-GogAuthPath),'auth','--code',$AuthCode)|Out-Null
            }
            'Amazon'{Invoke-AmazonNativeAuthentication $tool}
            'HES'{if([string]::IsNullOrWhiteSpace($AuthCode)){Connect-HesBrowserAuthentication}else{Connect-HesPairingCode $AuthCode}}
        }
        if(-not (Test-Authenticated $tool)){throw "$Provider sign-in completed without saving usable account credentials."}
        Refresh-ProviderCatalog $tool;Write-State $false 'Complete' "$Provider account connected." 100;exit 0
    }
    if($Mode -eq 'Refresh'){
        if(-not (Test-Authenticated $tool)){throw "$Provider account connection is required before refreshing the library."}
        Refresh-ProviderCatalog $tool
        Write-State $false 'Complete' "$Provider library refreshed." 100
        exit 0
    }
    Write-State $true $Mode "$Mode $GameName through $Provider..." 5
    Invoke-ProviderGameCommand $tool
    if($Mode -ne 'Launch'){Refresh-ProviderCatalog $tool}
    Write-State $false 'Complete' "$Mode completed for $GameName." 100
}catch{
    Write-State $false 'Failed' "$Mode failed for $GameName." -1 $_.Exception.Message
    Write-ProviderLog $_.Exception.ToString() 'ERROR'
    exit 1
}
