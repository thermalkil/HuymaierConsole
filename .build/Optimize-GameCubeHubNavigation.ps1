param(
    [Parameter(Mandatory=$true)][string]$ConsolePlatformsPath
)
Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
if(-not(Test-Path -LiteralPath $ConsolePlatformsPath -PathType Leaf)){throw "GameCube hub source missing: $ConsolePlatformsPath"}

$raw=Get-Content -Raw -LiteralPath $ConsolePlatformsPath -Encoding UTF8
if($raw -notmatch 'HUYMAIER_GAMECUBE_MEMORY_FACE_V1'){
    $old='if(index==2) return new Quaternion(new Vector3D(1,0,0),90);'
    if(-not $raw.Contains($old)){throw 'GameCube hub optimizer could not find the page-2 cube rotation.'}
    $new='if(index==2) return new Quaternion(new Vector3D(1,0,0),-90); // HUYMAIER_GAMECUBE_MEMORY_FACE_V1: Down/page 2 presents the physical bottom Memory Card face.'
    $raw=$raw.Replace($old,$new)
    Set-Content -LiteralPath $ConsolePlatformsPath -Value $raw -Encoding UTF8
}

$check=Get-Content -Raw -LiteralPath $ConsolePlatformsPath -Encoding UTF8
foreach($required in @(
    'else if (command == XmbInputCommand.Down) next = 2;  // Memory Card',
    'else if (page == 2) RenderGameCubeMemoryCards(FindSaveRoots())',
    'CreateGameCubeFace("MEMORY CARD", "Slot A / Slot B", "bottom")',
    'if(index==2) return new Quaternion(new Vector3D(1,0,0),-90);',
    'HUYMAIER_GAMECUBE_MEMORY_FACE_V1'
)){
    if($check.IndexOf($required,[StringComparison]::Ordinal) -lt 0){throw "GameCube hub invariant missing after transform: $required"}
}
if($check.IndexOf('if(index==2) return new Quaternion(new Vector3D(1,0,0),90);',[StringComparison]::Ordinal) -ge 0){throw 'GameCube page 2 still rotates toward the decorative top face.'}
Write-Host 'GameCube cube page/action mapping corrected: Down -> bottom Memory Card face -> Memory Card manager.'
