# HUYMAIER_V0308_SETTINGS_STORE_V1
# Single persistence owner for Huymaier Console settings. Modules may add their
# own config properties without also editing a central load allowlist.
Set-StrictMode -Version 2.0

$script:HcSettingsStoreLock=New-Object object

function Merge-HcPersistedConfig {
    param($Defaults,$Loaded)
    if($null -eq $Defaults){throw 'Settings defaults are unavailable.'}
    if($null -eq $Loaded){return $Defaults}
    foreach($property in @($Loaded.PSObject.Properties)){
        if($null -eq $property -or [string]::IsNullOrWhiteSpace([string]$property.Name)){continue}
        $name=[string]$property.Name
        if($null -ne $Defaults.PSObject.Properties[$name]){
            $Defaults.$name=$property.Value
        }else{
            $Defaults|Add-Member -NotePropertyName $name -NotePropertyValue $property.Value -Force
        }
    }
    return $Defaults
}

function Read-HcPersistedConfig {
    param([Parameter(Mandatory=$true)][string]$Path)
    if(-not(Test-Path -LiteralPath $Path -PathType Leaf)){return $null}
    return (Get-Content -Raw -LiteralPath $Path -Encoding UTF8|ConvertFrom-Json)
}

function Write-HcConfigAtomic {
    param(
        [Parameter(Mandatory=$true)][string]$Path,
        [Parameter(Mandatory=$true)]$Config,
        [int]$Depth=16
    )
    if([string]::IsNullOrWhiteSpace($Path)){throw 'Settings path is empty.'}
    $directory=Split-Path -Parent $Path
    if([string]::IsNullOrWhiteSpace($directory)){throw "Settings path has no parent directory: $Path"}
    New-Item -ItemType Directory -Force -Path $directory|Out-Null
    $tmp=Join-Path $directory ('.'+[IO.Path]::GetFileName($Path)+'.'+$PID+'.'+[guid]::NewGuid().ToString('N')+'.tmp')
    $backup=$Path+'.replace-backup'
    [Threading.Monitor]::Enter($script:HcSettingsStoreLock)
    try{
        Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
        $json=$Config|ConvertTo-Json -Depth ([math]::Max(8,[math]::Min(64,$Depth)))
        [IO.File]::WriteAllText($tmp,$json,(New-Object Text.UTF8Encoding($true)))
        if(Test-Path -LiteralPath $Path -PathType Leaf){
            try{
                Remove-Item -LiteralPath $backup -Force -ErrorAction SilentlyContinue
                [IO.File]::Replace($tmp,$Path,$backup,$true)
                Remove-Item -LiteralPath $backup -Force -ErrorAction SilentlyContinue
            }catch{
                Move-Item -LiteralPath $tmp -Destination $Path -Force
                Remove-Item -LiteralPath $backup -Force -ErrorAction SilentlyContinue
            }
        }else{
            Move-Item -LiteralPath $tmp -Destination $Path -Force
        }
        return $true
    }finally{
        Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
        [Threading.Monitor]::Exit($script:HcSettingsStoreLock)
    }
}

function Repair-HcSettingsStoreArtifacts {
    param([Parameter(Mandatory=$true)][string]$Path)
    try{
        $directory=Split-Path -Parent $Path
        if(-not(Test-Path -LiteralPath $directory -PathType Container)){return}
        $name=[IO.Path]::GetFileName($Path)
        foreach($file in @(Get-ChildItem -LiteralPath $directory -File -Filter ('.'+$name+'.*.tmp') -ErrorAction SilentlyContinue)){
            if($file.LastWriteTimeUtc -lt [DateTime]::UtcNow.AddMinutes(-5)){Remove-Item -LiteralPath $file.FullName -Force -ErrorAction SilentlyContinue}
        }
        $backup=$Path+'.replace-backup'
        if(Test-Path -LiteralPath $backup -PathType Leaf){Remove-Item -LiteralPath $backup -Force -ErrorAction SilentlyContinue}
    }catch{}
}
