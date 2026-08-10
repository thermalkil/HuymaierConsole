param(
    [Parameter(Mandatory=$true)][string]$StageRoot,
    [Parameter(Mandatory=$true)][string]$ValidationPath
)
Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'

$obsolete=@(
    'README.txt',
    'EmulatorPlatforms\GameCube\README.txt',
    'EmulatorPlatforms\N64\README.txt',
    'EmulatorPlatforms\Switch\README.txt',
    'EmulatorPlatforms\Wii\README.txt',
    'EmulatorPlatforms\WiiU\README.txt',
    'EmulatorPlatforms\Xbox\README.txt',
    'EmulatorPlatforms\Xbox360\README.txt'
)
foreach($relative in $obsolete){
    Remove-Item -LiteralPath (Join-Path $StageRoot $relative) -Force -ErrorAction SilentlyContinue
}

# Keep the PlayStation asset/readme files: those describe startup/media/legal handling
# and are not the obsolete one-line platform setup documents removed above.
foreach($required in @(
    'EmulatorPlatforms\PS1\Assets\README.txt',
    'EmulatorPlatforms\PS2\Assets\README.txt',
    'EmulatorPlatforms\PS3\Assets\README.txt'
)){
    if(-not(Test-Path -LiteralPath (Join-Path $StageRoot $required) -PathType Leaf)){
        throw "Required PlayStation asset README disappeared during text cleanup: $required"
    }
}

foreach($relative in $obsolete){
    if(Test-Path -LiteralPath (Join-Path $StageRoot $relative)){
        throw "Obsolete package text survived cleanup: $relative"
    }
}
if(@(Get-ChildItem -LiteralPath $StageRoot -File -Filter 'BUILD-VALIDATION*.txt' -ErrorAction SilentlyContinue).Count -gt 0){
    throw 'Historical BUILD-VALIDATION files survived final v0.26.3 cleanup.'
}
if(@(Get-ChildItem -LiteralPath $StageRoot -File -Filter 'RELEASE_NOTES-v*.txt' -ErrorAction SilentlyContinue).Count -gt 0){
    throw 'Historical versioned release-note files survived final v0.26.3 cleanup.'
}

# Re-seal the internal package checksum manifests after deleting inherited files.
$rows=New-Object Collections.Generic.List[string]
foreach($f in @(Get-ChildItem $StageRoot -File -Recurse|Where-Object{$_.Name -notin @('checksums.sha256','SHA256SUMS.txt')}|Sort-Object FullName)){
    $rel=$f.FullName.Substring($StageRoot.Length).TrimStart('\').Replace('\','/')
    $hash=(Get-FileHash $f.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
    [void]$rows.Add("$hash  $rel")
}
$text=($rows -join "`n")+"`n"
$utf8NoBom=New-Object Text.UTF8Encoding($false)
[IO.File]::WriteAllText((Join-Path $StageRoot 'checksums.sha256'),$text,$utf8NoBom)
[IO.File]::WriteAllText((Join-Path $StageRoot 'SHA256SUMS.txt'),$text,$utf8NoBom)

$validation=Get-Content -Raw -LiteralPath $ValidationPath -Encoding UTF8|ConvertFrom-Json
$asset=[string]$validation.asset
if([string]::IsNullOrWhiteSpace($asset)){throw 'Candidate validation record does not name an asset.'}
$out=Split-Path -Parent $ValidationPath
$zip=Join-Path $out $asset
Remove-Item -LiteralPath $zip -Force -ErrorAction SilentlyContinue
Compress-Archive -LiteralPath $StageRoot -DestinationPath $zip -CompressionLevel Optimal -Force
$zipHash=(Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash.ToLowerInvariant()
Set-Content -LiteralPath ($zip+'.sha256') -Value ($zipHash+'  '+$asset) -Encoding ASCII
$validation.sha256=$zipHash
$validation.packageFiles=$rows.Count
$validation|Add-Member -NotePropertyName obsoleteTextCleanupGate -NotePropertyValue 'success' -Force
$validation|ConvertTo-Json -Depth 8|Set-Content -LiteralPath $ValidationPath -Encoding UTF8

# Verify the exact rebuilt archive, not only the mutable staging directory.
$verify=Join-Path $env:RUNNER_TEMP ('hc-v0263-text-verify-'+[guid]::NewGuid().ToString('N'))
try {
    Expand-Archive -LiteralPath $zip -DestinationPath $verify -Force
    $roots=@(Get-ChildItem -LiteralPath $verify -Directory)
    $root=if($roots.Count -eq 1){$roots[0].FullName}else{$verify}
    foreach($relative in $obsolete){
        if(Test-Path -LiteralPath (Join-Path $root $relative)){throw "Rebuilt ZIP still contains obsolete text: $relative"}
    }
    foreach($required in @(
        'EmulatorPlatforms\PS1\Assets\README.txt',
        'EmulatorPlatforms\PS2\Assets\README.txt',
        'EmulatorPlatforms\PS3\Assets\README.txt'
    )){
        if(-not(Test-Path -LiteralPath (Join-Path $root $required) -PathType Leaf)){throw "Rebuilt ZIP lost required PlayStation asset README: $required"}
    }
    $sealed=Get-Content -LiteralPath (Join-Path $root 'checksums.sha256') -Encoding UTF8
    $expected=@{}
    foreach($line in $sealed){
        if($line -match '^([0-9a-fA-F]{64})  (.+)$'){$expected[$matches[2]]=$matches[1].ToLowerInvariant()}
    }
    $payload=@(Get-ChildItem $root -File -Recurse|Where-Object{$_.Name -notin @('checksums.sha256','SHA256SUMS.txt')})
    if($payload.Count -ne $expected.Count){throw "Rebuilt ZIP checksum manifest count mismatch: payload=$($payload.Count), checksums=$($expected.Count)"}
    foreach($f in $payload){
        $rel=$f.FullName.Substring($root.Length).TrimStart('\').Replace('\','/')
        if(-not $expected.ContainsKey($rel)){throw "Rebuilt ZIP contains unchecksummed payload: $rel"}
        $actual=(Get-FileHash -LiteralPath $f.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
        if($actual -ne $expected[$rel]){throw "Rebuilt ZIP checksum mismatch: $rel"}
    }
} finally {
    Remove-Item -LiteralPath $verify -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host "v0.26.3 obsolete text cleanup passed; resealed candidate SHA-256: $zipHash"
