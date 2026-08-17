param(
    [Parameter(Mandatory=$true)][ValidateSet('Setup','Authenticate','Refresh','Install','Update','Verify','Uninstall','Launch')][string]$Mode,
    [string]$GameId='',
    [string]$GameName='',
    [Parameter(Mandatory=$true)][string]$DataDir,
    [Parameter(Mandatory=$true)][string]$StatePath,
    [Parameter(Mandatory=$true)][string]$CatalogPath
)

Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
$ProgressPreference='SilentlyContinue'
$startedAt=(Get-Date)
$logDir=Join-Path $DataDir 'Logs'
New-Item -ItemType Directory -Force -Path $DataDir,$logDir|Out-Null
$logPath=Join-Path $logDir "steam-provider-$((Get-Date).ToString('yyyy-MM-dd')).log"
$script:DownloadedBytes=[int64]0
$script:TotalBytes=[int64]0
$script:InstallSizeBytes=[int64]0
$script:SpeedBytesPerSec=[double]0
$script:EtaSeconds=[int64]-1
$script:LastBytes=[int64]0
$script:LastSampleAt=[DateTime]::UtcNow
$script:ObservedActivity=$false

function Write-LogLine {param([string]$Message,[string]$Level='INFO');try{"$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff') [$Level] [Steam/$Mode] $Message"|Add-Content -LiteralPath $logPath -Encoding UTF8}catch{}}
function Write-AtomicJson {param([string]$Path,$Value);$tmp="$Path.$PID.tmp";$Value|ConvertTo-Json -Depth 20|Set-Content -LiteralPath $tmp -Encoding UTF8;Move-Item -LiteralPath $tmp -Destination $Path -Force}
function Get-Prop {param($Object,[string]$Name,$Default=$null);if($null -eq $Object){return $Default};try{$p=$Object.PSObject.Properties[$Name];if($null -ne $p -and $null -ne $p.Value){return $p.Value}}catch{};return $Default}
function To-Array {param($Value);$list=New-Object System.Collections.ArrayList;if($null -ne $Value){try{foreach($item in $Value){[void]$list.Add($item)}}catch{[void]$list.Add($Value)}};return [object[]]$list.ToArray()}
function Write-State {
    param([bool]$Busy,[string]$Phase,[string]$Message,[int]$Progress=-1,[string]$Error='')
    $state=[pscustomobject]@{
        Busy=$Busy;Provider='Steam';Mode=$Mode;Phase=$Phase;Message=$Message;Progress=$Progress;Error=$Error;
        GameId=$GameId;GameName=$GameName;WorkerPid=$PID;StartedAt=$startedAt.ToString('o');Updated=(Get-Date).ToString('o');
        DownloadedBytes=[int64]$script:DownloadedBytes;TotalBytes=[int64]$script:TotalBytes;InstallSizeBytes=[int64]$script:InstallSizeBytes;
        DownloadSpeedBytesPerSec=[double]$script:SpeedBytesPerSec;EtaSeconds=[int64]$script:EtaSeconds;TelemetryUpdated=[DateTime]::UtcNow.ToString('o')
    }
    Write-AtomicJson $StatePath $state
}
function Read-Catalog {if(Test-Path -LiteralPath $CatalogPath -PathType Leaf){try{return Get-Content -Raw -LiteralPath $CatalogPath|ConvertFrom-Json}catch{}};return [pscustomobject]@{Providers=@();Updated=''}}
function Save-SteamNode {param($Node);$catalog=Read-Catalog;$nodes=New-Object System.Collections.ArrayList;$done=$false;foreach($n in @(Get-Prop $catalog 'Providers' @())){if([string]::Equals([string](Get-Prop $n 'Id' ''),'Steam',[StringComparison]::OrdinalIgnoreCase)){[void]$nodes.Add($Node);$done=$true}else{[void]$nodes.Add($n)}};if(-not $done){[void]$nodes.Add($Node)};Write-AtomicJson $CatalogPath ([pscustomobject]@{Providers=[object[]]$nodes.ToArray();Updated=(Get-Date).ToString('o')})}
function Get-ExistingSteamNode {foreach($n in @(Get-Prop (Read-Catalog) 'Providers' @())){if([string]::Equals([string](Get-Prop $n 'Id' ''),'Steam',[StringComparison]::OrdinalIgnoreCase)){return $n}};return $null}
function Add-UniquePath {param([System.Collections.ArrayList]$List,[hashtable]$Seen,[string]$Path);if([string]::IsNullOrWhiteSpace($Path)){return};try{$Path=[IO.Path]::GetFullPath($Path)}catch{};$key=$Path.ToLowerInvariant();if(-not $Seen.ContainsKey($key)){$Seen[$key]=$true;[void]$List.Add($Path)}}
function Get-SteamRoots {
    $roots=New-Object System.Collections.ArrayList;$seen=@{}
    foreach($key in @('HKCU:\Software\Valve\Steam','HKLM:\SOFTWARE\WOW6432Node\Valve\Steam','HKLM:\SOFTWARE\Valve\Steam')){try{$p=Get-ItemProperty $key -ErrorAction Stop;foreach($n in @('SteamPath','InstallPath')){if($p.PSObject.Properties[$n]){Add-UniquePath $roots $seen ([string]$p.$n)}}}catch{}}
    foreach($root in @($roots.ToArray())){
        $vdf=Join-Path ([string]$root) 'steamapps\libraryfolders.vdf'
        if(Test-Path -LiteralPath $vdf -PathType Leaf){try{$text=Get-Content -Raw -LiteralPath $vdf;foreach($m in [regex]::Matches($text,'"path"\s+"([^"]+)"')){Add-UniquePath $roots $seen ($m.Groups[1].Value -replace '\\\\','\')}}catch{}}
    }
    return [object[]]$roots.ToArray()
}
function Get-SteamExe {foreach($root in @(Get-SteamRoots)){$exe=Join-Path ([string]$root) 'steam.exe';if(Test-Path -LiteralPath $exe -PathType Leaf){return $exe}};return ''}
function Get-AcfValue {param([string]$Text,[string]$Name,[string]$Default='');$m=[regex]::Match($Text,'(?im)^\s*"'+[regex]::Escape($Name)+'"\s+"([^"]*)"');if($m.Success){return $m.Groups[1].Value};return $Default}
function Read-AppManifest {param([string]$Path);if(-not(Test-Path -LiteralPath $Path -PathType Leaf)){return $null};try{$text=Get-Content -Raw -LiteralPath $Path;$appid=Get-AcfValue $text 'appid';if(-not $appid){return $null};return [pscustomobject]@{Path=$Path;AppId=$appid;Name=(Get-AcfValue $text 'name' "Steam App $appid");InstallDir=(Get-AcfValue $text 'installdir' '');StateFlags=[int64](Get-AcfValue $text 'StateFlags' '0');SizeOnDisk=[int64](Get-AcfValue $text 'SizeOnDisk' '0');BytesToDownload=[int64](Get-AcfValue $text 'BytesToDownload' '0');BytesDownloaded=[int64](Get-AcfValue $text 'BytesDownloaded' '0');BytesToStage=[int64](Get-AcfValue $text 'BytesToStage' '0');BytesStaged=[int64](Get-AcfValue $text 'BytesStaged' '0');BuildId=(Get-AcfValue $text 'buildid' '');LastWriteUtc=(Get-Item -LiteralPath $Path).LastWriteTimeUtc}}catch{return $null}}
function Find-AppManifest {param([string]$Id);foreach($root in @(Get-SteamRoots)){$path=Join-Path ([string]$root) ("steamapps\appmanifest_$Id.acf");if(Test-Path -LiteralPath $path -PathType Leaf){return $path}};return ''}
function Find-AppRootForManifest {param([string]$ManifestPath);if(-not $ManifestPath){return ''};try{return Split-Path -Parent (Split-Path -Parent $ManifestPath)}catch{return ''}}
function Get-DirBytes {param([string]$Path);if(-not $Path -or -not(Test-Path -LiteralPath $Path -PathType Container)){return [int64]0};$sum=[int64]0;try{foreach($f in Get-ChildItem -LiteralPath $Path -File -Recurse -Force -ErrorAction SilentlyContinue){$sum+=[int64]$f.Length}}catch{};return $sum}
function New-SteamFallbackArtwork {
    param([string]$Id,[string]$Name,[string]$Target)
    try{
        Add-Type -AssemblyName System.Drawing -ErrorAction Stop
        $dir=Split-Path -Parent $Target;New-Item -ItemType Directory -Force -Path $dir|Out-Null
        $bmp=New-Object System.Drawing.Bitmap 600,900
        $g=[System.Drawing.Graphics]::FromImage($bmp)
        try{
            $seed=0;foreach($ch in ([string]$Id).ToCharArray()){$seed=(($seed*33)+[int]$ch)-band 0x7fffffff}
            $c1=[System.Drawing.Color]::FromArgb(255,18+(($seed -shr 1)-band 63),28+(($seed -shr 7)-band 63),45+(($seed -shr 13)-band 70))
            $c2=[System.Drawing.Color]::FromArgb(255,10,15,24)
            $rect=New-Object System.Drawing.Rectangle 0,0,600,900
            $brush=New-Object System.Drawing.Drawing2D.LinearGradientBrush $rect,$c1,$c2,90
            try{$g.FillRectangle($brush,$rect)}finally{$brush.Dispose()}
            $g.SmoothingMode=[System.Drawing.Drawing2D.SmoothingMode]::HighQuality
            $steamFont=New-Object System.Drawing.Font 'Segoe UI',34,[System.Drawing.FontStyle]::Bold
            $titleFont=New-Object System.Drawing.Font 'Segoe UI',42,[System.Drawing.FontStyle]::Bold
            $smallFont=New-Object System.Drawing.Font 'Segoe UI',18,[System.Drawing.FontStyle]::Regular
            $white=[System.Drawing.Brushes]::White;$soft=New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(205,225,235,245))
            try{
                $g.DrawString('STEAM',$steamFont,$soft,42,55)
                $nameText=if([string]::IsNullOrWhiteSpace($Name)){"Steam App $Id"}else{$Name}
                $format=New-Object System.Drawing.StringFormat;$format.Trimming=[System.Drawing.StringTrimming]::EllipsisWord;$format.FormatFlags=[System.Drawing.StringFormatFlags]::LineLimit
                $g.DrawString($nameText,$titleFont,$white,(New-Object System.Drawing.RectangleF 42,250,516,370),$format)
                $g.DrawString("APPID $Id",$smallFont,$soft,44,815)
                $format.Dispose()
            }finally{$steamFont.Dispose();$titleFont.Dispose();$smallFont.Dispose();$soft.Dispose()}
            $bmp.Save($Target,[System.Drawing.Imaging.ImageFormat]::Png)
        }finally{$g.Dispose();$bmp.Dispose()}
        if(Test-Path -LiteralPath $Target -PathType Leaf){return $Target}
    }catch{Write-LogLine "Could not generate deterministic Steam fallback artwork for ${Id}: $($_.Exception.Message)" 'WARN'}
    return ''
}
function Get-SteamArtwork {
    param([string]$Root,[string]$Id,[string]$Name='')
    if([string]::IsNullOrWhiteSpace($Id)){return ''}
    $artRoots=New-Object System.Collections.ArrayList;$seen=@{}
    foreach($candidateRoot in @($Root)+(Get-SteamRoots)){if($candidateRoot){Add-UniquePath $artRoots $seen ([string]$candidateRoot)}}
    foreach($artRoot in @($artRoots.ToArray())){
        foreach($candidate in @(
            (Join-Path $artRoot "appcache\librarycache\${Id}_library_600x900.jpg"),
            (Join-Path $artRoot "appcache\librarycache\${Id}_library_600x900.png"),
            (Join-Path $artRoot "appcache\librarycache\${Id}_library_600x900_2x.jpg"),
            (Join-Path $artRoot "appcache\librarycache\$Id\library_600x900.jpg"),
            (Join-Path $artRoot "appcache\librarycache\$Id\library_600x900.png")
        )){if(Test-Path -LiteralPath $candidate -PathType Leaf){return $candidate}}
        $nested=Join-Path $artRoot "appcache\librarycache\$Id"
        if(Test-Path -LiteralPath $nested -PathType Container){
            try{$found=Get-ChildItem -LiteralPath $nested -File -ErrorAction SilentlyContinue|Where-Object{$_.Extension -match '^\.(jpg|jpeg|png|webp)$' -and $_.Name -match '(?i)(library|600x900|portrait|cover)'}|Sort-Object Length -Descending|Select-Object -First 1;if($found){return $found.FullName}}catch{}
        }
        $userdata=Join-Path $artRoot 'userdata'
        if(Test-Path -LiteralPath $userdata -PathType Container){
            foreach($user in Get-ChildItem -LiteralPath $userdata -Directory -ErrorAction SilentlyContinue){
                $grid=Join-Path $user.FullName 'config\grid'
                foreach($ext in @('jpg','png','webp','jpeg')){foreach($suffix in @('p','')){$candidate=Join-Path $grid ("$Id$suffix.$ext");if(Test-Path -LiteralPath $candidate -PathType Leaf){return $candidate}}}
            }
        }
    }
    $cache=Join-Path (Join-Path $DataDir 'Artwork\Steam') ("$Id.png")
    if(Test-Path -LiteralPath $cache -PathType Leaf){return $cache}
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $cache)|Out-Null
    foreach($url in @(
        "https://cdn.cloudflare.steamstatic.com/steam/apps/$Id/library_600x900.jpg",
        "https://cdn.cloudflare.steamstatic.com/steam/apps/$Id/library_600x900_2x.jpg",
        "https://cdn.cloudflare.steamstatic.com/steam/apps/$Id/header.jpg"
    )){
        $tmp="$cache.download"
        try{
            Invoke-WebRequest -UseBasicParsing -Uri $url -Headers @{'User-Agent'='Huymaier-Console/0.26.3'} -TimeoutSec 8 -OutFile $tmp
            if((Test-Path -LiteralPath $tmp -PathType Leaf) -and (Get-Item -LiteralPath $tmp).Length -gt 2048){Move-Item -LiteralPath $tmp -Destination $cache -Force;return $cache}
        }catch{}finally{Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue}
    }
    return (New-SteamFallbackArtwork $Id $Name $cache)
}
function Refresh-SteamCatalog {
    $previous=Get-ExistingSteamNode;$games=New-Object System.Collections.ArrayList;$byId=@{}
    foreach($root in @(Get-SteamRoots)){
        $steamapps=Join-Path ([string]$root) 'steamapps';if(-not(Test-Path -LiteralPath $steamapps -PathType Container)){continue}
        foreach($file in Get-ChildItem -LiteralPath $steamapps -Filter 'appmanifest_*.acf' -File -ErrorAction SilentlyContinue){$m=Read-AppManifest $file.FullName;if($null -eq $m){continue};if($m.Name -match '(?i)^(Steamworks Common Redistributables|Steam Linux Runtime|Proton |SteamVR$|Steam Controller Configs$)'){continue};$install=if($m.InstallDir){Join-Path $steamapps ("common\"+$m.InstallDir)}else{''};$game=[pscustomobject]@{Id=[string]$m.AppId;Name=[string]$m.Name;Provider='Steam';Source='Steam';Installed=$true;InstallPath=$install;Path=$install;LaunchTarget=("steam://rungameid/"+$m.AppId);ArtworkPath=(Get-SteamArtwork ([string]$root) ([string]$m.AppId) ([string]$m.Name));Description='Steam library title';SizeText=$(if($m.SizeOnDisk -gt 0){'{0:N1} GB' -f ($m.SizeOnDisk/1GB)}else{''});InstallSizeBytes=[int64]$m.SizeOnDisk;UpdateAvailable=$false;BuildId=[string]$m.BuildId};$byId[[string]$m.AppId]=$games.Count;[void]$games.Add($game)}
    }
    foreach($old in @(Get-Prop $previous 'Games' @())){$id=[string](Get-Prop $old 'Id' '');if(-not $id -or $byId.ContainsKey($id)){continue};$name=[string](Get-Prop $old 'Name' "Steam App $id");if($name -match '^Steam App \d+$'){continue};[void]$games.Add([pscustomobject]@{Id=$id;Name=$name;Provider='Steam';Source='Steam';Installed=$false;InstallPath='';Path='';LaunchTarget=("steam://rungameid/"+$id);ArtworkPath=$(if([string](Get-Prop $old 'ArtworkPath' '')){[string](Get-Prop $old 'ArtworkPath' '')}else{Get-SteamArtwork '' $id $name});Description='Known Steam library title';SizeText=[string](Get-Prop $old 'SizeText' '');InstallSizeBytes=[int64](Get-Prop $old 'InstallSizeBytes' 0);UpdateAvailable=$false;BuildId=[string](Get-Prop $old 'BuildId' '')})}
    $exe=Get-SteamExe;$node=[pscustomobject]@{Id='Steam';Name='Steam';Backend='Steam Client';SchemaVersion=1;ToolReady=[bool]$exe;Authenticated=[bool]$exe;ToolPath=$exe;Status=$(if($exe){"$($games.Count) known Steam game(s) loaded."}else{'Steam client is not installed.'});Error='';Games=[object[]]$games.ToArray();Updated=(Get-Date).ToString('o')};Save-SteamNode $node;return [object[]]$games.ToArray()
}
function Open-SteamUri {param([string]$Uri);$exe=Get-SteamExe;if($exe){Start-Process -FilePath $exe -ArgumentList @('-silent',$Uri)|Out-Null}else{Start-Process $Uri|Out-Null}}
function Update-TransferFromManifest {param($Manifest,[string]$DownloadPath='');$downloaded=[int64]0;$total=[int64]0;$installSize=[int64]0;$phase='Waiting for Steam';if($Manifest){$installSize=[int64]$Manifest.SizeOnDisk;$toDownload=[int64]$Manifest.BytesToDownload;$didDownload=[int64]$Manifest.BytesDownloaded;$toStage=[int64]$Manifest.BytesToStage;$didStage=[int64]$Manifest.BytesStaged;if($toDownload -gt 0){$total=$toDownload;$downloaded=[math]::Min($toDownload,$didDownload);$phase=$(if($downloaded -lt $total){'Downloading'}else{'Installing'})}elseif($toStage -gt 0){$total=$toStage;$downloaded=[math]::Min($toStage,$didStage);$phase='Installing'}};if($downloaded -le 0 -and $DownloadPath){$dirBytes=Get-DirBytes $DownloadPath;if($dirBytes -gt 0){$downloaded=$dirBytes;$phase='Downloading';$script:ObservedActivity=$true}};if($downloaded -ne $script:DownloadedBytes){$script:ObservedActivity=$true};$now=[DateTime]::UtcNow;$elapsed=[math]::Max(.05,($now-$script:LastSampleAt).TotalSeconds);$delta=[math]::Max([int64]0,$downloaded-$script:LastBytes);$script:SpeedBytesPerSec=$delta/$elapsed;$script:LastBytes=$downloaded;$script:LastSampleAt=$now;$script:DownloadedBytes=$downloaded;$script:TotalBytes=$total;$script:InstallSizeBytes=$installSize;if($total -gt 0 -and $script:SpeedBytesPerSec -gt 1){$script:EtaSeconds=[int64][math]::Ceiling(($total-$downloaded)/$script:SpeedBytesPerSec)}else{$script:EtaSeconds=-1};$progress=$(if($total -gt 0){[int][math]::Max(0,[math]::Min(100,[math]::Round(($downloaded*100.0)/$total)))}else{-1});return [pscustomobject]@{Phase=$phase;Progress=$progress}}
function Wait-SteamOperation {
    param([ValidateSet('Install','Update','Verify')][string]$Operation,[string]$Id)
    $deadline=(Get-Date).AddHours($(if($Operation -eq 'Verify'){4}else{12}));$initialManifest=Find-AppManifest $Id;$initialWrite=$null;if($initialManifest){try{$initialWrite=(Get-Item -LiteralPath $initialManifest).LastWriteTimeUtc}catch{}}
    $lastPhase='';$stableComplete=0
    while((Get-Date) -lt $deadline){
        $manifestPath=Find-AppManifest $Id;$manifest=Read-AppManifest $manifestPath;$root=Find-AppRootForManifest $manifestPath;$downloadPath=if($root){Join-Path $root ("steamapps\downloading\"+$Id)}else{''}
        $tele=Update-TransferFromManifest $manifest $downloadPath;$phase=[string]$tele.Phase
        if($Operation -eq 'Verify' -and $phase -eq 'Waiting for Steam'){$phase='Verifying'}
        if($manifestPath -and $initialWrite){try{if((Get-Item -LiteralPath $manifestPath).LastWriteTimeUtc -ne $initialWrite){$script:ObservedActivity=$true}}catch{}}
        $fullyInstalled=$false;if($manifest){$fullyInstalled=(([int64]$manifest.StateFlags -band 4) -ne 0)}
        $downloadActive=($downloadPath -and (Test-Path -LiteralPath $downloadPath -PathType Container))
        if($fullyInstalled -and -not $downloadActive -and ($script:ObservedActivity -or $Operation -eq 'Update')){$stableComplete++}else{$stableComplete=0}
        $message=$(if($phase -eq 'Waiting for Steam'){"Waiting for Steam to begin $Operation. Accept any Steam confirmation if shown."}else{"Steam $Operation in progress."})
        Write-State $true $phase $message ([int]$tele.Progress)
        if($stableComplete -ge 3){return $true}
        Start-Sleep -Milliseconds 1000
    }
    return $false
}

$script:HcSteamOwnershipModulePath=Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) 'HuymaierSteamOwnership.ps1'
if(Test-Path -LiteralPath $script:HcSteamOwnershipModulePath -PathType Leaf){. $script:HcSteamOwnershipModulePath}

try{
    $GameId=$GameId -replace '^(?i)Steam:',''
    switch($Mode){
        'Setup' {Write-State $true 'Preparing' 'Checking the installed Steam client.' 10;[void](Refresh-SteamCatalog);Write-State $false 'Complete' 'Steam client integration is ready.' 100;exit 0}
        'Authenticate' {Write-State $true 'Preparing' 'Steam uses the account already signed into the Steam client.' 25;[void](Refresh-SteamCatalog);Write-State $false 'Complete' 'Steam account integration uses the current Steam client session.' 100;exit 0}
        'Refresh' {Write-State $true 'Refreshing library' 'Scanning Steam library folders and manifests.' 20;$games=@(Refresh-SteamCatalog);Write-State $false 'Complete' "$($games.Count) known Steam game(s) loaded." 100;exit 0}
        'Launch' {if(-not $GameId){throw 'Steam App ID is missing.'};Open-SteamUri ("steam://rungameid/"+$GameId);Write-State $false 'Complete' 'Launch handed to Steam.' 100;exit 0}
        'Install' {if(-not $GameId){throw 'Steam App ID is missing.'};Write-State $true 'Waiting for Steam' 'Opening the Steam installation flow.' -1;Open-SteamUri ("steam://install/"+$GameId);if(Wait-SteamOperation 'Install' $GameId){[void](Refresh-SteamCatalog);Write-State $false 'Complete' "$GameName installed through Steam." 100}else{[void](Refresh-SteamCatalog);Write-State $false 'Delegated' 'Steam still owns this installation. Continue or review it in Steam.' -1};exit 0}
        'Update' {if(-not $GameId){throw 'Steam App ID is missing.'};Write-State $true 'Waiting for Steam' 'Requesting the latest Steam build.' -1;Open-SteamUri ("steam://install/"+$GameId);if(Wait-SteamOperation 'Update' $GameId){[void](Refresh-SteamCatalog);Write-State $false 'Complete' "$GameName is ready in Steam." 100}else{[void](Refresh-SteamCatalog);Write-State $false 'Delegated' 'Steam still owns this update. Continue or review it in Steam.' -1};exit 0}
        'Verify' {if(-not $GameId){throw 'Steam App ID is missing.'};Write-State $true 'Waiting for Steam' 'Opening Steam file verification.' -1;Open-SteamUri ("steam://validate/"+$GameId);if(Wait-SteamOperation 'Verify' $GameId){[void](Refresh-SteamCatalog);Write-State $false 'Complete' "$GameName verification finished in Steam." 100}else{Write-State $false 'Delegated' 'Steam still owns this verification. Continue or review it in Steam.' -1};exit 0}
        'Uninstall' {if(-not $GameId){throw 'Steam App ID is missing.'};$before=Find-AppManifest $GameId;Write-State $true 'Waiting for Steam' 'Opening Steam uninstall confirmation.' -1;Open-SteamUri ("steam://uninstall/"+$GameId);$deadline=(Get-Date).AddMinutes(30);while((Get-Date) -lt $deadline){$current=Find-AppManifest $GameId;if($before -and -not $current){[void](Refresh-SteamCatalog);Write-State $false 'Complete' "$GameName was uninstalled through Steam." 100;exit 0};Write-State $true 'Waiting for Steam' 'Confirm the uninstall in Steam.' -1;Start-Sleep -Seconds 1};[void](Refresh-SteamCatalog);Write-State $false 'Delegated' 'Steam still owns this uninstall request.' -1;exit 0}
    }
}catch{
    Write-LogLine $_.Exception.Message 'ERROR'
    try{[void](Refresh-SteamCatalog)}catch{}
    Write-State $false 'Failed' "Steam $Mode failed." -1 $_.Exception.Message
    exit 1
}
