param(
    [Parameter(Mandatory=$true)][string]$ConfigPath,
    [Parameter(Mandatory=$true)][string]$StatePath,
    [Parameter(Mandatory=$true)][string]$ResultPath
)
Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
function Write-State([bool]$Busy,[string]$Phase,[string]$Message,[int]$Count=0,[string]$Error=''){
    $state=[pscustomobject]@{Busy=$Busy;Phase=$Phase;Message=$Message;ImportedCount=$Count;Error=$Error;UpdatedAt=(Get-Date).ToString('o')}
    $tmp="$StatePath.tmp";$state|ConvertTo-Json -Depth 5|Set-Content -LiteralPath $tmp -Encoding UTF8;Move-Item -LiteralPath $tmp -Destination $StatePath -Force
}
function Get-Prop($Object,[string]$Name,$Default=''){if($null -eq $Object){return $Default};$p=$Object.PSObject.Properties[$Name];if($null -eq $p -or $null -eq $p.Value){return $Default};return $p.Value}
function Add-Path([System.Collections.ArrayList]$List,$Path){if($null -eq $Path){return};if($Path -is [System.Array]){foreach($p in $Path){Add-Path $List $p};return};$s=[string]$Path;if([string]::IsNullOrWhiteSpace($s)){return};try{$s=[IO.Path]::GetFullPath([Environment]::ExpandEnvironmentVariables($s.Trim()))}catch{$s=$s.Trim()};foreach($x in $List){if([string]::Equals([string]$x,$s,[StringComparison]::OrdinalIgnoreCase)){return}};[void]$List.Add($s)}
$config=if(Test-Path -LiteralPath $ConfigPath){Get-Content -Raw -LiteralPath $ConfigPath|ConvertFrom-Json}else{[pscustomobject]@{StorefrontRoots=@()}}
function Roots([string]$Store){foreach($e in @($config.StorefrontRoots)){if($null -ne $e -and [string](Get-Prop $e 'Store') -eq $Store){$p=[string](Get-Prop $e 'Path');if($p){$p}}}}
function Add-Game([System.Collections.ArrayList]$Target,[string]$Id,[string]$Name,[string]$Source,[string]$LaunchTarget,[string]$Path='',[string]$Artwork=''){if($Id -and $Name -and $LaunchTarget){[void]$Target.Add([pscustomobject]@{Id=$Id;Name=$Name;Source=$Source;LaunchTarget=$LaunchTarget;Path=$Path;ArtworkPath=$Artwork})}}
function SteamRoots{
    $roots=New-Object System.Collections.ArrayList
    foreach($key in @('HKCU:\Software\Valve\Steam','HKLM:\SOFTWARE\WOW6432Node\Valve\Steam','HKLM:\SOFTWARE\Valve\Steam')){try{$p=Get-ItemProperty $key -ErrorAction Stop;foreach($n in @('SteamPath','InstallPath')){if($p.PSObject.Properties[$n]){Add-Path $roots ([string]$p.$n)}}}catch{}}
    foreach($r in @(Roots 'Steam')){if((Split-Path -Leaf ([string]$r)) -ieq 'steamapps'){Add-Path $roots (Split-Path -Parent ([string]$r))}else{Add-Path $roots $r}}
    foreach($r in @($roots.ToArray())){$v=Join-Path ([string]$r) 'steamapps\libraryfolders.vdf';if(Test-Path -LiteralPath $v){try{$t=Get-Content -Raw -LiteralPath $v;foreach($m in [regex]::Matches($t,'"path"\s+"([^"]+)"')){Add-Path $roots ($m.Groups[1].Value -replace '\\\\','\')}}catch{}}}
    $roots.ToArray()
}
function SteamFallbackArt([string]$AppId,[string]$Name){
    $dataDir=Split-Path -Parent $ConfigPath;$cache=Join-Path (Join-Path $dataDir 'Artwork\Steam') ("$AppId.png")
    if(Test-Path -LiteralPath $cache -PathType Leaf){return $cache}
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $cache)|Out-Null
    try{
        Add-Type -AssemblyName System.Drawing -ErrorAction Stop
        $bmp=New-Object System.Drawing.Bitmap 600,900;$g=[System.Drawing.Graphics]::FromImage($bmp)
        try{$g.Clear([System.Drawing.Color]::FromArgb(255,22,32,48));$font=New-Object System.Drawing.Font 'Segoe UI',38,[System.Drawing.FontStyle]::Bold;$small=New-Object System.Drawing.Font 'Segoe UI',20;try{$g.DrawString('STEAM',[System.Drawing.Font]$small,[System.Drawing.Brushes]::White,42,60);$label=if($Name){$Name}else{"Steam App $AppId"};$g.DrawString($label,$font,[System.Drawing.Brushes]::White,(New-Object System.Drawing.RectangleF 42,240,516,420));$g.DrawString("APPID $AppId",$small,[System.Drawing.Brushes]::LightGray,42,820)}finally{$font.Dispose();$small.Dispose()};$bmp.Save($cache,[System.Drawing.Imaging.ImageFormat]::Png)}finally{$g.Dispose();$bmp.Dispose()}
    }catch{}
    return $(if(Test-Path -LiteralPath $cache -PathType Leaf){$cache}else{''})
}
function SteamArt([string]$Root,[string]$AppId,[string]$Name=''){
    $artRoots=New-Object System.Collections.ArrayList
    Add-Path $artRoots $Root
    foreach($key in @('HKCU:\Software\Valve\Steam','HKLM:\SOFTWARE\WOW6432Node\Valve\Steam','HKLM:\SOFTWARE\Valve\Steam')){
        try{$p=Get-ItemProperty $key -ErrorAction Stop;foreach($n in @('SteamPath','InstallPath')){if($p.PSObject.Properties[$n]){Add-Path $artRoots ([string]$p.$n)}}}catch{}
    }
    foreach($artRoot in $artRoots){
        foreach($c in @(
            (Join-Path $artRoot "appcache\librarycache\${AppId}_library_600x900.jpg"),
            (Join-Path $artRoot "appcache\librarycache\${AppId}_library_600x900.png"),
            (Join-Path $artRoot "appcache\librarycache\${AppId}_library_600x900_2x.jpg"),
            (Join-Path $artRoot "appcache\librarycache\$AppId\library_600x900.jpg"),
            (Join-Path $artRoot "appcache\librarycache\$AppId\library_600x900.png")
        )){if(Test-Path -LiteralPath $c){return $c}}
        $userdata=Join-Path $artRoot 'userdata'
        if(Test-Path -LiteralPath $userdata){foreach($user in Get-ChildItem -LiteralPath $userdata -Directory -ErrorAction SilentlyContinue){$grid=Join-Path $user.FullName 'config\grid';foreach($ext in @('jpg','png','webp','jpeg')){foreach($suffix in @('p','')){$candidate=Join-Path $grid ("$AppId$suffix.$ext");if(Test-Path -LiteralPath $candidate){return $candidate}}}}}
    }
    $dataDir=Split-Path -Parent $ConfigPath;$cache=Join-Path (Join-Path $dataDir 'Artwork\Steam') ("$AppId.png")
    if(Test-Path -LiteralPath $cache -PathType Leaf){return $cache}
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $cache)|Out-Null
    foreach($url in @("https://cdn.cloudflare.steamstatic.com/steam/apps/$AppId/library_600x900.jpg","https://cdn.cloudflare.steamstatic.com/steam/apps/$AppId/library_600x900_2x.jpg","https://cdn.cloudflare.steamstatic.com/steam/apps/$AppId/header.jpg")){
        $tmp="$cache.download";try{Invoke-WebRequest -UseBasicParsing -Uri $url -Headers @{'User-Agent'='Huymaier-Console/0.26.3'} -TimeoutSec 8 -OutFile $tmp;if((Test-Path -LiteralPath $tmp) -and (Get-Item -LiteralPath $tmp).Length -gt 2048){Move-Item -LiteralPath $tmp -Destination $cache -Force;return $cache}}catch{}finally{Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue}
    }
    return (SteamFallbackArt $AppId $Name)
}
function Test-SteamImportedGame([string]$Name,[string]$InstallDir){
    if([string]::IsNullOrWhiteSpace($Name)){return $false}
    if($Name -match '(?i)^(Steamworks Common Redistributables|Steam Linux Runtime|Proton |SteamVR$|Steam Controller Configs$)'){return $false}
    if($Name -match '(?i)\b(Dedicated Server|SDK Base|Authoring Tools|Development Kit)\b'){return $false}
    return $true
}
function Scan-SteamGames([System.Collections.ArrayList]$Target){
    $seen=@{}
    foreach($root in @(SteamRoots)){
        $steamapps=Join-Path ([string]$root) 'steamapps'
        if(-not(Test-Path -LiteralPath $steamapps -PathType Container)){continue}
        foreach($manifest in Get-ChildItem -LiteralPath $steamapps -Filter 'appmanifest_*.acf' -File -ErrorAction SilentlyContinue){
            try{
                $text=Get-Content -Raw -LiteralPath $manifest.FullName
                $appid=[regex]::Match($text,'"appid"\s+"([^"]+)"').Groups[1].Value
                $name=[regex]::Match($text,'"name"\s+"([^"]+)"').Groups[1].Value
                $dir=[regex]::Match($text,'"installdir"\s+"([^"]+)"').Groups[1].Value
                if(-not $appid -or -not(Test-SteamImportedGame $name $dir)){continue}
                $key=$appid.ToLowerInvariant();if($seen.ContainsKey($key)){continue};$seen[$key]=$true
                $install=if($dir){Join-Path $steamapps ("common\"+$dir)}else{''}
                Add-Game $Target ("Steam:"+$appid) $name 'Steam' ("steam://rungameid/"+$appid) $install (SteamArt ([string]$root) $appid $name)
            }catch{}
        }
    }
}
function Find-LocalArtwork([string]$Root){
    if([string]::IsNullOrWhiteSpace($Root) -or -not(Test-Path -LiteralPath $Root)){return ''}
    $names=@('cover.jpg','cover.png','boxart.jpg','boxart.png','poster.jpg','poster.png','folder.jpg','folder.png','library_600x900.jpg','library_600x900.png','capsule_600x900.jpg','capsule_600x900.png','icon.jpg','icon.png')
    foreach($name in $names){$candidate=Join-Path $Root $name;if(Test-Path -LiteralPath $candidate){return $candidate}}
    try{$candidate=Get-ChildItem -LiteralPath $Root -File -ErrorAction SilentlyContinue|Where-Object{$_.Extension -match '^\.(jpg|jpeg|png|webp)$' -and $_.Name -match 'cover|box|poster|capsule|library|hero|icon'}|Select-Object -First 1;if($candidate){return $candidate.FullName}}catch{}
    return ''
}

function Test-EpicManifestGame($g){
    if($null -eq $g){return $false}
    $name=[string](Get-Prop $g 'DisplayName');$install=[string](Get-Prop $g 'InstallLocation');$app=[string](Get-Prop $g 'AppName');$exe=[string](Get-Prop $g 'LaunchExecutable')
    # An installed Epic game has a launch executable. Marketplace assets/plugins
    # commonly have an AppName + InstallLocation but no runnable game executable.
    if(-not $name -or -not $install -or [string]::IsNullOrWhiteSpace($exe)){return $false}
    $build=[string](Get-Prop $g 'BuildVersion');$catalog=[string](Get-Prop $g 'CatalogNamespace')
    $extra='';try{$extra=$g|ConvertTo-Json -Depth 12 -Compress}catch{}
    $combined=("$name`n$install`n$app`n$exe`n$build`n$catalog`n$extra")
    if($combined -match '(?i)(Dev-Marketplace|Marketplace-Windows|UE[45]\+Dev-Marketplace|UnrealEngine|UnrealEditor|UE4Editor|EpicGamesLauncher|BuildPatchTool|CrashReportClient|VaultCache|UEFN)'){return $false}
    if($combined -match '(?im)^(Unreal Engine|Unreal Editor|Twinmotion|RealityCapture|MetaHuman|Quixel Bridge|Fab|Epic Online Services|Unreal Datasmith|Unreal Marketplace)\b'){return $false}
    if($combined -match '(?i)\b(Marketplace Asset|Engine Plugin|Editor Plugin|Plugin|Asset Pack|Content Pack|Starter Content|Content Examples|Feature Pack|SDK|Mod Kit|Editor Symbols|Debug Symbols|Source Code|Marketplace Content|Engine Content)\b'){return $false}
    if($install -match '(?i)[\\/](UE_[0-9][^\\/]*|Engine|VaultCache|Marketplace|Plugins)[\\/]'){return $false}
    if($exe -match '(?i)(UnrealEditor|UE4Editor|EpicGamesLauncher|BuildPatchTool|CrashReportClient)\.exe$'){return $false}
    return $true
}

function Scan-Exes([System.Collections.ArrayList]$Target,[string]$Store,[string]$Root){if(-not $Root -or -not(Test-Path -LiteralPath $Root)){return};foreach($exe in Get-ChildItem -LiteralPath $Root -Filter '*.exe' -File -Recurse -ErrorAction SilentlyContinue|Where-Object{$_.Name -notmatch 'unins|setup|crash|report|launcherhelper|unitycrash|redist|vc_redist'}|Select-Object -First 500){Add-Game $Target "${Store}:$($exe.FullName.ToLowerInvariant())" $exe.BaseName $Store $exe.FullName $exe.DirectoryName ''}}
try{
    Write-State $true 'Steam' 'Scanning Steam libraries.'
    $items=New-Object System.Collections.ArrayList
    # Steam stays the owner/launcher, but its installed games belong in the
    # native Huymaier Console Library and Shelf. Big Picture is a separate option.
    Scan-SteamGames $items
    Write-State $true 'Epic' 'Scanning Epic Games manifests.' $items.Count
    $epic=New-Object System.Collections.ArrayList;Add-Path $epic "$env:ProgramData\Epic\EpicGamesLauncher\Data\Manifests";foreach($r in @(Roots 'Epic')){Add-Path $epic $r};foreach($r in $epic){if(-not(Test-Path -LiteralPath $r)){continue};foreach($f in Get-ChildItem -LiteralPath $r -Filter '*.item' -File -Recurse -ErrorAction SilentlyContinue){try{$g=Get-Content -Raw -LiteralPath $f.FullName|ConvertFrom-Json;if(-not(Test-EpicManifestGame $g)){continue};$name=[string](Get-Prop $g 'DisplayName');$install=[string](Get-Prop $g 'InstallLocation');$app=[string](Get-Prop $g 'AppName');$exeRel=[string](Get-Prop $g 'LaunchExecutable');$target=if($app){"com.epicgames.launcher://apps/$app?action=launch&silent=true"}elseif($exeRel){Join-Path $install $exeRel}else{''};if($target){Add-Game $items "Epic:$app" $name 'Epic' $target $install (Find-LocalArtwork $install)}}catch{}}}
    # Do not recursively import arbitrary .exe files from Epic roots. Unreal Engine, Marketplace assets and plugins share those trees.
    Write-State $true 'GOG' 'Scanning GOG libraries.' $items.Count
    foreach($keyRoot in @('HKLM:\SOFTWARE\WOW6432Node\GOG.com\Games','HKLM:\SOFTWARE\GOG.com\Games')){if(Test-Path $keyRoot){foreach($key in Get-ChildItem $keyRoot -ErrorAction SilentlyContinue){try{$p=Get-ItemProperty $key.PSPath;$name=[string]$p.gameName;$path=[string]$p.path;$exe=[string]$p.exe;if($exe -and -not [IO.Path]::IsPathRooted($exe)){$exe=Join-Path $path $exe};if($exe -and(Test-Path -LiteralPath $exe)){Add-Game $items "GOG:$($key.PSChildName)" $name 'GOG' $exe $path (Find-LocalArtwork $path)}}catch{}}}}
    foreach($r in @(Roots 'GOG')){if(Test-Path -LiteralPath $r){foreach($info in Get-ChildItem -LiteralPath $r -Filter 'goggame-*.info' -File -Recurse -ErrorAction SilentlyContinue){try{$g=Get-Content -Raw -LiteralPath $info.FullName|ConvertFrom-Json;$task=@(Get-Prop $g 'playTasks' @())|Where-Object{[string](Get-Prop $_ 'category') -eq 'game'}|Select-Object -First 1;$exe=[string](Get-Prop $task 'path');if($exe -and -not [IO.Path]::IsPathRooted($exe)){$exe=Join-Path $info.DirectoryName $exe};if(Test-Path -LiteralPath $exe){Add-Game $items "GOG:$(Get-Prop $g 'gameId')" ([string](Get-Prop $g 'name')) 'GOG' $exe $info.DirectoryName (Find-LocalArtwork $info.DirectoryName)}}catch{}}}}
    Write-State $true 'Ubisoft and EA' 'Scanning Ubisoft and EA libraries.' $items.Count
    foreach($root in @('HKLM:\SOFTWARE\WOW6432Node\Ubisoft\Launcher\Installs','HKLM:\SOFTWARE\Ubisoft\Launcher\Installs')){if(Test-Path $root){foreach($key in Get-ChildItem $root -ErrorAction SilentlyContinue){try{$p=Get-ItemProperty $key.PSPath;$path=[string]$p.InstallDir;Add-Game $items "Ubisoft:$($key.PSChildName)" (Split-Path $path -Leaf) 'Ubisoft' "uplay://launch/$($key.PSChildName)/0" $path (Find-LocalArtwork $path)}catch{}}}}
    foreach($r in @(Roots 'Ubisoft')){Scan-Exes $items 'Ubisoft' $r};foreach($r in @(Roots 'EA')){Scan-Exes $items 'EA' $r}
    foreach($root in @('HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall','HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall')){if(Test-Path $root){foreach($key in Get-ChildItem $root -ErrorAction SilentlyContinue){try{$p=Get-ItemProperty $key.PSPath;$publisher=[string]$p.Publisher;if($publisher -notmatch 'Electronic Arts|EA Swiss|EA Games'){continue};$name=[string]$p.DisplayName;$install=[string]$p.InstallLocation;$icon=[string]$p.DisplayIcon;if($icon){$icon=$icon.Trim('"');if($icon -match '^(.*?\.exe)'){$icon=$matches[1]}};if($name -and $icon -and(Test-Path -LiteralPath $icon)){Add-Game $items "EA:$($key.PSChildName)" $name 'EA' $icon $install (Find-LocalArtwork $install)}}catch{}}}}
    Write-State $true 'Xbox and other stores' 'Scanning Xbox, Battle.net, Rockstar, and Amazon.' $items.Count
    $xroots=New-Object System.Collections.ArrayList;Add-Path $xroots "$env:SystemDrive\XboxGames";foreach($r in @(Roots 'Xbox')){Add-Path $xroots $r};foreach($r in $xroots){if(Test-Path -LiteralPath $r){foreach($cfg in Get-ChildItem -LiteralPath $r -Filter 'MicrosoftGame.Config' -File -Recurse -ErrorAction SilentlyContinue){try{[xml]$x=Get-Content -Raw -LiteralPath $cfg.FullName;$name=[string]$x.Game.ShellVisuals.DefaultDisplayName;if( -not $name){$name=$cfg.Directory.Parent.Name};$helper=Join-Path $cfg.DirectoryName 'gamelaunchhelper.exe';if(Test-Path -LiteralPath $helper){Add-Game $items "Xbox:$($cfg.Directory.Parent.Name)" $name 'Xbox' $helper $cfg.DirectoryName (Find-LocalArtwork $cfg.DirectoryName)}}catch{}}}}
    foreach($store in @('Battle.net','Rockstar','Amazon','Generic')){foreach($r in @(Roots $store)){Scan-Exes $items $store $r}}
    $seen=@{};$out=New-Object System.Collections.ArrayList
    foreach($g in $items){$id=[string](Get-Prop $g 'Id');if( -not $id){continue};$k=$id.ToLowerInvariant();if($seen.ContainsKey($k)){continue};$seen[$k]=$true;[void]$out.Add($g)}
    $result=[pscustomobject]@{Games=[object[]]$out.ToArray();CompletedAt=(Get-Date).ToString('o')};$tmp="$ResultPath.tmp";$result|ConvertTo-Json -Depth 8|Set-Content -LiteralPath $tmp -Encoding UTF8;Move-Item -LiteralPath $tmp -Destination $ResultPath -Force
    Write-State $false 'Complete' "Imported $($out.Count) installed game(s)." $out.Count
}catch{Write-State $false 'Failed' 'Library scan failed.' 0 $_.Exception.Message;exit 1}
