[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$Destination)

Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
$ProgressPreference='SilentlyContinue'

$Destination=[IO.Path]::GetFullPath($Destination)
$trimChars=[char[]]@([IO.Path]::DirectorySeparatorChar,[IO.Path]::AltDirectorySeparatorChar)
$consoleRoot=([IO.Path]::GetFullPath((Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)))).TrimEnd($trimChars)
$normalizedDestination=$Destination.TrimEnd($trimChars)
if([string]::Equals($normalizedDestination,$consoleRoot,[StringComparison]::OrdinalIgnoreCase) -or
   $normalizedDestination.StartsWith(($consoleRoot+[IO.Path]::DirectorySeparatorChar),[StringComparison]::OrdinalIgnoreCase)){
    throw 'PCSX2 must be installed outside the Huymaier Console application folder.'
}
New-Item -ItemType Directory -Force -Path $Destination|Out-Null
$work=Join-Path $env:TEMP ('Huymaier-PCSX2-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $work|Out-Null

function Backup-Pcsx2Configuration {
    param([string]$Root)
    $exe=Get-ChildItem -LiteralPath $Root -Filter 'pcsx2*.exe' -File -ErrorAction SilentlyContinue|Select-Object -First 1
    if(-not $exe){return $null}
    $backup=Join-Path $Root ('.huymaier-backups\'+(Get-Date -Format 'yyyyMMdd-HHmmss'))
    New-Item -ItemType Directory -Force -Path $backup|Out-Null
    foreach($name in @('portable.ini','inis','gamesettings','inputprofiles')){
        $source=Join-Path $Root $name
        if(Test-Path -LiteralPath $source){Copy-Item -LiteralPath $source -Destination (Join-Path $backup $name) -Recurse -Force}
    }
    return $backup
}

try{
    $headers=@{'User-Agent'='Huymaier-Console';'Accept'='application/vnd.github+json'}
    $release=Invoke-RestMethod -Headers $headers -Uri 'https://api.github.com/repos/PCSX2/pcsx2/releases/latest'
    $assets=@($release.assets|Where-Object{
        $_.name -match '(?i)windows' -and $_.name -match '(?i)(x64|avx2)' -and
        $_.name -match '\.(7z|zip)$' -and $_.name -notmatch '(?i)(symbols|pdb|debug)'
    })
    if($assets.Count -eq 0){
        $assets=@($release.assets|Where-Object{$_.name -match '(?i)windows' -and $_.name -match '\.(7z|zip)$' -and $_.name -notmatch '(?i)(symbols|pdb|debug)'})
    }
    $asset=$assets|Sort-Object @{Expression={if($_.name -match '(?i)avx2'){0}else{1}}},name|Select-Object -First 1
    if(-not $asset){throw 'The latest official PCSX2 Windows archive could not be identified.'}
    $archive=Join-Path $work $asset.name
    Invoke-WebRequest -Headers $headers -Uri $asset.browser_download_url -OutFile $archive
    $expanded=Join-Path $work 'expanded'
    New-Item -ItemType Directory -Force -Path $expanded|Out-Null
    if($archive -match '(?i)\.zip$'){
        Expand-Archive -LiteralPath $archive -DestinationPath $expanded -Force
    }else{
        $sevenCandidates=@()
        $sevenCommand=Get-Command 7z.exe -ErrorAction SilentlyContinue
        if($sevenCommand){$sevenCandidates+=[string]$sevenCommand.Source}
        if($env:ProgramFiles){$sevenCandidates+=(Join-Path $env:ProgramFiles '7-Zip\7z.exe')}
        $seven=$sevenCandidates|Where-Object{$_ -and (Test-Path -LiteralPath $_ -PathType Leaf)}|Select-Object -First 1
        if($seven){
            & $seven x -y "-o$expanded" $archive|Out-Null
            if($LASTEXITCODE -ne 0){throw '7-Zip could not extract the PCSX2 archive.'}
        }else{
            $tar=(Get-Command tar.exe -ErrorAction SilentlyContinue).Source
            if(-not $tar){throw 'PCSX2 is distributed as 7z and neither Windows tar nor 7-Zip is available.'}
            & $tar -xf $archive -C $expanded
            if($LASTEXITCODE -ne 0){throw 'Windows tar could not extract the PCSX2 archive. Install 7-Zip and try again.'}
        }
    }
    $exe=Get-ChildItem -LiteralPath $expanded -Filter 'pcsx2*.exe' -Recurse -File|Where-Object{$_.Name -notmatch '(?i)(updater|uninstall)'}|Select-Object -First 1
    if(-not $exe){throw 'A PCSX2 executable was not present in the downloaded archive.'}
    $source=$exe.Directory.FullName
    $backup=Backup-Pcsx2Configuration -Root $Destination
    Copy-Item -Path (Join-Path $source '*') -Destination $Destination -Recurse -Force
    $marker=[ordered]@{managedBy='Huymaier Console';installedAt=(Get-Date).ToString('o');release=[string]$release.tag_name;destination=$Destination;backup=$backup}
    $marker|ConvertTo-Json -Depth 4|Set-Content -LiteralPath (Join-Path $Destination '.huymaier-managed-pcsx2.json') -Encoding UTF8
    Write-Host "PCSX2 installed or updated at $Destination"
    if($backup){Write-Host "Configuration backup: $backup"}
}finally{
    Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
}
