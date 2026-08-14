$ErrorActionPreference='Stop'
Set-StrictMode -Version 2.0

$repo=Resolve-Path (Join-Path $PSScriptRoot '..\..')
$worker=Join-Path $repo 'HuymaierNativeConsoleLibraryWorker.ps1'
$temp=Join-Path $env:TEMP ('hc-v0265-nintendo-'+[guid]::NewGuid().ToString('N'))
try{
    $romRoot=Join-Path $temp 'ROMs'
    $wii=Join-Path $romRoot 'Wii'
    $gc=Join-Path $romRoot 'GameCube'
    New-Item -ItemType Directory -Force -Path $wii,$gc|Out-Null
    $wiiCanonical=(Get-Item -LiteralPath $wii).FullName
    $gcCanonical=(Get-Item -LiteralPath $gc).FullName

    function New-RawDisc([string]$Path,[string]$Kind){
        $bytes=New-Object byte[] 0x40
        if($Kind -eq 'Wii'){$bytes[0x18]=0x5D;$bytes[0x19]=0x1C;$bytes[0x1A]=0x9E;$bytes[0x1B]=0xA3}
        else{$bytes[0x1C]=0xC2;$bytes[0x1D]=0x33;$bytes[0x1E]=0x9F;$bytes[0x1F]=0x3D}
        [IO.File]::WriteAllBytes($Path,$bytes)
    }
    New-RawDisc (Join-Path $wii 'Real Wii.iso') 'Wii'
    New-RawDisc (Join-Path $wii 'Wrong GameCube.iso') 'GameCube'
    New-RawDisc (Join-Path $gc 'Real GameCube.iso') 'GameCube'
    New-RawDisc (Join-Path $gc 'Wrong Wii.iso') 'Wii'
    Set-Content -LiteralPath (Join-Path $wii 'Compressed Wii.wbfs') -Value 'fixture' -Encoding ASCII
    Set-Content -LiteralPath (Join-Path $gc 'Compressed GameCube.rvz') -Value 'fixture' -Encoding ASCII

    $settingsPath=Join-Path $temp 'wii-settings.json'
    $defaultPath=Join-Path $temp 'default.json'
    $resultPath=Join-Path $temp 'wii-result.json'
    @{schemaVersion=7;gameFolders=@($romRoot)}|ConvertTo-Json -Depth 4|Set-Content -LiteralPath $settingsPath -Encoding UTF8
    @{schemaVersion=7;gameFolders=@()}|ConvertTo-Json -Depth 4|Set-Content -LiteralPath $defaultPath -Encoding UTF8

    & $worker -PlatformId WII -SettingsPath $settingsPath -DefaultSettingsPath $defaultPath -ResultPath $resultPath
    $result=Get-Content -Raw -LiteralPath $resultPath|ConvertFrom-Json
    $saved=Get-Content -Raw -LiteralPath $settingsPath|ConvertFrom-Json
    $resultRootText=((@($result.Roots)|ForEach-Object{"[$_]"}) -join ', ')
    $savedRootText=((@($saved.gameFolders)|ForEach-Object{"[$_]"}) -join ', ')
    Write-Host ("Wii expected canonical root: {0}" -f $wiiCanonical)
    Write-Host ("Wii result roots ({0}): {1}" -f @($result.Roots).Count,$resultRootText)
    Write-Host ("Wii saved roots ({0}): {1}" -f @($saved.gameFolders).Count,$savedRootText)
    if([int]$result.Count -ne 2){throw "Wii fixture expected exactly 2 Wii-owned games, got $($result.Count)."}
    if(@($result.Roots).Count -ne 1 -or -not [string]::Equals([string]$result.Roots[0],$wiiCanonical,[StringComparison]::OrdinalIgnoreCase)){throw 'Wii shared-parent root did not narrow to the Wii child.'}
    if(@($saved.gameFolders).Count -ne 1 -or -not [string]::Equals([string]$saved.gameFolders[0],$wiiCanonical,[StringComparison]::OrdinalIgnoreCase)){throw 'Wii resolved root was not persisted for the native renderer.'}
    if(-not(Test-Path -LiteralPath "$settingsPath.pre-v0265-nintendo-root.bak" -PathType Leaf)){throw 'Wii settings backup was not created before root migration.'}

    $gcSettings=Join-Path $temp 'gc-settings.json'
    $gcResult=Join-Path $temp 'gc-result.json'
    @{schemaVersion=7;gameFolders=@($romRoot)}|ConvertTo-Json -Depth 4|Set-Content -LiteralPath $gcSettings -Encoding UTF8
    & $worker -PlatformId GAMECUBE -SettingsPath $gcSettings -DefaultSettingsPath $defaultPath -ResultPath $gcResult
    $gcData=Get-Content -Raw -LiteralPath $gcResult|ConvertFrom-Json
    $gcSaved=Get-Content -Raw -LiteralPath $gcSettings|ConvertFrom-Json
    $gcResultRootText=((@($gcData.Roots)|ForEach-Object{"[$_]"}) -join ', ')
    $gcSavedRootText=((@($gcSaved.gameFolders)|ForEach-Object{"[$_]"}) -join ', ')
    Write-Host ("GameCube expected canonical root: {0}" -f $gcCanonical)
    Write-Host ("GameCube result roots ({0}): {1}" -f @($gcData.Roots).Count,$gcResultRootText)
    Write-Host ("GameCube saved roots ({0}): {1}" -f @($gcSaved.gameFolders).Count,$gcSavedRootText)
    if([int]$gcData.Count -ne 2){throw "GameCube fixture expected exactly 2 GameCube-owned games, got $($gcData.Count)."}
    if(@($gcData.Roots).Count -ne 1 -or -not [string]::Equals([string]$gcData.Roots[0],$gcCanonical,[StringComparison]::OrdinalIgnoreCase)){throw 'GameCube shared-parent root did not narrow to the GameCube child.'}

    Write-Host 'Nintendo library ownership regression fixture passed.' -ForegroundColor Green
}finally{
    Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue
}
