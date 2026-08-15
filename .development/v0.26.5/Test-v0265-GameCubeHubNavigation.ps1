Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
$repo=(Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$temp=Join-Path $env:TEMP ('hc-v0265-gamecube-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $temp|Out-Null
try{
    $source=Join-Path $repo 'Native\HuymaierConsole.ConsolePlatforms.cs'
    $copy=Join-Path $temp 'HuymaierConsole.ConsolePlatforms.cs'
    Copy-Item -LiteralPath $source -Destination $copy -Force
    & (Join-Path $repo '.build\Optimize-NintendoLibraryOwnership.ps1') -NativePath $copy
    & (Join-Path $repo '.build\Optimize-NintendoDisplayNames.ps1') -ConsolePlatformsPath $copy
    & (Join-Path $repo '.build\Optimize-DolphinIntegration.ps1') -ConsolePlatformsPath $copy
    & (Join-Path $repo '.build\Optimize-WiiArtworkAliases.ps1') -ConsolePlatformsPath $copy
    & (Join-Path $repo '.build\Optimize-GameCubeHubNavigation.ps1') -ConsolePlatformsPath $copy
    $raw=Get-Content -Raw -LiteralPath $copy -Encoding UTF8
    foreach($required in @(
        'models.Children.Add(CreateGameCubeFace("MEMORY CARD", "Slot A / Slot B", "bottom"));',
        'else if (command == XmbInputCommand.Down) next = 2;  // Memory Card',
        'else if (page == 2) RenderGameCubeMemoryCards(FindSaveRoots())',
        'if(index==2) return new Quaternion(new Vector3D(1,0,0),-90);',
        'HUYMAIER_GAMECUBE_MEMORY_FACE_V1'
    )){if($raw.IndexOf($required,[StringComparison]::Ordinal) -lt 0){throw "Transformed GameCube hub missing: $required"}}
    if($raw.IndexOf('if(index==2) return new Quaternion(new Vector3D(1,0,0),90);',[StringComparison]::Ordinal) -ge 0){throw 'GameCube Down/page-2 still rotates toward the top Nintendo GameCube face.'}
    $optimizer=Join-Path $repo '.build\Optimize-GameCubeHubNavigation.ps1'
    $tokens=$null;$errors=$null
    [void][Management.Automation.Language.Parser]::ParseFile($optimizer,[ref]$tokens,[ref]$errors)
    if($errors.Count){throw (($errors|ForEach-Object{"$($_.Extent.StartLineNumber): $($_.Message)"}) -join '; ')}
    Write-Host 'v0.26.5 GameCube cube navigation gate passed: Down -> bottom Memory Card face -> Memory Card manager.'
}finally{Remove-Item $temp -Recurse -Force -ErrorAction SilentlyContinue}
