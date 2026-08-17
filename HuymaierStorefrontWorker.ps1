param(
    [Parameter(Mandatory=$true)][ValidateSet('Install','Uninstall')][string]$Mode,
    [Parameter(Mandatory=$true)][string]$StoreId,
    [Parameter(Mandatory=$true)][string]$Name,
    [string]$WingetId='',
    [string]$StoreSource='',
    [string]$OfficialUrl='',
    [string]$DirectUrl='',
    [string]$FileName='Installer.exe',
    [string]$AppxName='',
    [string]$UninstallPattern='',
    [Parameter(Mandatory=$true)][string]$StatePath,
    [Parameter(Mandatory=$true)][string]$DownloadDir
)

$ErrorActionPreference='Stop'
$startedAt=(Get-Date).ToString('o')
try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls11 } catch { }

function Write-State {
    param([bool]$Busy,[string]$Status,[string]$Message,[int]$Progress=0)
    $state=[pscustomobject]@{
        StoreId=$StoreId
        Name=$Name
        Mode=$Mode
        Busy=$Busy
        Status=$Status
        Message=$Message
        Progress=$Progress
        StartedAt=$startedAt
        Updated=(Get-Date).ToString('o')
    }
    $directory=Split-Path -Parent $StatePath
    if($directory){New-Item -ItemType Directory -Force -Path $directory|Out-Null}
    $state|ConvertTo-Json -Depth 4|Set-Content -LiteralPath $StatePath -Encoding UTF8
}

function Get-UninstallCommand {
    param([string]$Pattern)
    $roots=@(
        'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall',
        'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall',
        'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall'
    )
    foreach($root in $roots){
        if(-not(Test-Path -LiteralPath $root)){continue}
        foreach($key in Get-ChildItem -LiteralPath $root -ErrorAction SilentlyContinue){
            try{
                $item=Get-ItemProperty -LiteralPath $key.PSPath -ErrorAction Stop
                if([string]$item.DisplayName -match $Pattern){
                    if([string]$item.QuietUninstallString){return [string]$item.QuietUninstallString}
                    if([string]$item.UninstallString){return [string]$item.UninstallString}
                }
            }catch{}
        }
    }
    return ''
}

function Start-CommandLine {
    param([string]$CommandLine)
    if([string]::IsNullOrWhiteSpace($CommandLine)){return $false}
    $commandLine=$CommandLine.Trim()
    if($commandLine -match '^\s*"([^"]+)"\s*(.*)$'){
        $exe=$matches[1]
        $args=$matches[2]
    }elseif($commandLine -match '^\s*([^\s]+)\s*(.*)$'){
        $exe=$matches[1]
        $args=$matches[2]
    }else{return $false}
    if($exe -match '(?i)msiexec(\.exe)?$'){
        $args=$args -replace '(?i)(^|\s)/I(?=\s*\{)',' /X'
        if($args -notmatch '(?i)/q'){ $args="$args /passive" }
    }
    $process=Start-Process -FilePath $exe -ArgumentList $args -Wait -PassThru
    return ($null -ne $process -and [int]$process.ExitCode -eq 0)
}

function Try-Winget {
    param([string]$Operation)
    $winget=Get-Command winget.exe -ErrorAction SilentlyContinue
    if($null -eq $winget -or [string]::IsNullOrWhiteSpace($WingetId)){return $false}
    $arguments=New-Object System.Collections.ArrayList
    [void]$arguments.Add($Operation.ToLowerInvariant())
    [void]$arguments.Add('--id')
    [void]$arguments.Add($WingetId)
    [void]$arguments.Add('--exact')
    if($StoreSource){[void]$arguments.Add('--source');[void]$arguments.Add($StoreSource)}
    [void]$arguments.Add('--accept-package-agreements')
    [void]$arguments.Add('--accept-source-agreements')
    [void]$arguments.Add('--disable-interactivity')
    if($Operation -eq 'Install'){[void]$arguments.Add('--silent')}
    $process=Start-Process -FilePath $winget.Source -ArgumentList ([string[]]$arguments.ToArray()) -Wait -PassThru -WindowStyle Hidden
    return ($null -ne $process -and [int]$process.ExitCode -eq 0)
}

try{
    Write-State $true 'Starting' "$Mode started for $Name." 5
    if($Mode -eq 'Install'){
        if(Try-Winget 'Install'){
            Write-State $false 'Complete' "$Name was installed through Windows Package Manager." 100
            exit 0
        }

        if($DirectUrl){
            New-Item -ItemType Directory -Force -Path $DownloadDir|Out-Null
            $target=Join-Path $DownloadDir $FileName
            Write-State $true 'Downloading' "Downloading the official $Name installer..." 25
            $client=New-Object System.Net.WebClient
            $client.Headers['User-Agent']='Huymaier Console FSE'
            $client.DownloadFile($DirectUrl,$target)
            Write-State $true 'Installing' "Starting the official $Name installer..." 70
            $process=Start-Process -FilePath $target -Wait -PassThru
            if($null -ne $process -and [int]$process.ExitCode -eq 0){
                Write-State $false 'Complete' "$Name installation completed." 100
                exit 0
            }
            Write-State $false 'NeedsAttention' "$Name installer closed with exit code $($process.ExitCode)." 100
            exit 1
        }

        if($OfficialUrl){
            Start-Process $OfficialUrl|Out-Null
            Write-State $false 'OpenedOfficialPage' "The official $Name download page was opened because no unattended installer was available." 100
            exit 0
        }
        throw "No official installation route is configured for $Name."
    }

    if($AppxName){
        $packages=Get-AppxPackage -Name $AppxName -ErrorAction SilentlyContinue
        foreach($package in $packages){Remove-AppxPackage -Package $package.PackageFullName -ErrorAction Stop}
        Write-State $false 'Complete' "$Name was uninstalled." 100
        exit 0
    }

    if(Try-Winget 'Uninstall'){
        Write-State $false 'Complete' "$Name was uninstalled through Windows Package Manager." 100
        exit 0
    }

    $command=Get-UninstallCommand $UninstallPattern
    if($command -and (Start-CommandLine $command)){
        Write-State $false 'Complete' "$Name was uninstalled using its registered Windows uninstaller." 100
        exit 0
    }
    throw "No registered uninstaller was found for $Name."
}catch{
    Write-State $false 'Error' "${Mode} failed for ${Name}: $($_.Exception.Message)" 100
    exit 1
}
