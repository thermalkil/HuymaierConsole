[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$Destination
)

Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
$ProgressPreference='SilentlyContinue'

$Destination=[IO.Path]::GetFullPath($Destination)
$trimChars=[char[]]@([IO.Path]::DirectorySeparatorChar,[IO.Path]::AltDirectorySeparatorChar)
$consoleRoot=([IO.Path]::GetFullPath((Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)))).TrimEnd($trimChars)
$normalizedDestination=$Destination.TrimEnd($trimChars)
if([string]::Equals($normalizedDestination,$consoleRoot,[StringComparison]::OrdinalIgnoreCase) -or
   $normalizedDestination.StartsWith(($consoleRoot+[IO.Path]::DirectorySeparatorChar),[StringComparison]::OrdinalIgnoreCase)){
    throw 'RPCS3 must be installed outside the Huymaier Console application folder.'
}
New-Item -ItemType Directory -Force -Path $Destination | Out-Null
$work=Join-Path $env:TEMP ('Huymaier-RPCS3-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $work | Out-Null

function Backup-Rpcs3UserState {
    param([string]$Root)
    if(-not (Test-Path -LiteralPath (Join-Path $Root 'rpcs3.exe') -PathType Leaf)){return $null}
    $stamp=Get-Date -Format 'yyyyMMdd-HHmmss'
    $backup=Join-Path $Root ('.huymaier-backups\'+$stamp)
    New-Item -ItemType Directory -Force -Path $backup | Out-Null

    # Back up native configuration that an application update could touch. The
    # large firmware, games, saves, caches and content directories stay in place
    # and are never deleted or relocated by this helper.
    foreach($name in @('config.yml','CurrentSettings.ini','GuiConfigs','custom_configs','patches')){
        $source=Join-Path $Root $name
        if(Test-Path -LiteralPath $source){Copy-Item -LiteralPath $source -Destination (Join-Path $backup $name) -Recurse -Force}
    }
    return $backup
}

try {
    $headers=@{'User-Agent'='Huymaier-Console';'Accept'='application/vnd.github+json'}
    $release=Invoke-RestMethod -Headers $headers -Uri 'https://api.github.com/repos/RPCS3/rpcs3-binaries-win/releases/latest'
    $asset=@($release.assets|Where-Object{$_.name -match 'win64.*\.(7z|zip)$' -or $_.name -match 'windows.*\.(7z|zip)$'}|Select-Object -First 1)
    if(-not $asset){$asset=@($release.assets|Where-Object{$_.name -match '\.(7z|zip)$'}|Select-Object -First 1)}
    if(-not $asset){throw 'The latest RPCS3 Windows archive could not be identified.'}

    $archive=Join-Path $work $asset.name
    Invoke-WebRequest -Headers $headers -Uri $asset.browser_download_url -OutFile $archive
    if($archive -match '\.zip$'){
        $expanded=Join-Path $work 'expanded'
        Expand-Archive -LiteralPath $archive -DestinationPath $expanded -Force
    } else {
        $expanded=Join-Path $work 'expanded'
        New-Item -ItemType Directory -Force -Path $expanded | Out-Null
        $sevenCommand=Get-Command 7z.exe -ErrorAction SilentlyContinue
        $sevenCandidates=@()
        if($null -ne $sevenCommand){$sevenCandidates+=[string]$sevenCommand.Source}
        if($env:ProgramFiles){$sevenCandidates+=(Join-Path $env:ProgramFiles '7-Zip\7z.exe')}
        $seven=$sevenCandidates|Where-Object{$_ -and (Test-Path -LiteralPath $_ -PathType Leaf)}|Select-Object -First 1
        if($seven){
            & $seven x -y "-o$expanded" $archive | Out-Null
            if($LASTEXITCODE -ne 0){throw '7-Zip could not extract the RPCS3 archive.'}
        } else {
            $tar=(Get-Command tar.exe -ErrorAction SilentlyContinue).Source
            if(-not $tar){throw 'RPCS3 is distributed as 7z and neither Windows tar nor 7-Zip is available.'}
            & $tar -xf $archive -C $expanded
            if($LASTEXITCODE -ne 0){throw 'Windows tar could not extract the RPCS3 7z archive. Install 7-Zip and try again.'}
        }
    }

    $exe=Get-ChildItem -LiteralPath $work -Filter rpcs3.exe -Recurse -File|Select-Object -First 1
    if(-not $exe){throw 'rpcs3.exe was not present in the downloaded archive.'}
    $source=$exe.Directory.FullName
    $backup=Backup-Rpcs3UserState -Root $Destination

    # Overlay only the official program payload. Do not clear the destination:
    # user-selected data folders, firmware, games, saves, patches, caches and
    # unrelated files remain exactly where the user placed them.
    Copy-Item -Path (Join-Path $source '*') -Destination $Destination -Recurse -Force

    $marker=[ordered]@{
        managedBy='Huymaier Console'
        installedAt=(Get-Date).ToString('o')
        release=[string]$release.tag_name
        destination=$Destination
        backup=$backup
    }
    $marker|ConvertTo-Json -Depth 4|Set-Content -LiteralPath (Join-Path $Destination '.huymaier-managed-rpcs3.json') -Encoding UTF8
    Write-Host "RPCS3 installed or updated at $Destination"
    if($backup){Write-Host "Configuration backup: $backup"}
}
finally {
    Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
}
