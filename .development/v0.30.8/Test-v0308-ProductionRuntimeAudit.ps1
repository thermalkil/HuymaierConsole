param([string]$StageRoot='.')
Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
$root=(Resolve-Path -LiteralPath $StageRoot).Path
function Need([bool]$Condition,[string]$Message){if(-not $Condition){throw "v0.30.8 production runtime audit failed: $Message"}}
function Read-Hc([string]$Relative){$path=Join-Path $root $Relative;Need (Test-Path -LiteralPath $path -PathType Leaf) "missing $Relative";[IO.File]::ReadAllText($path,[Text.Encoding]::UTF8)}
function Parse-Hc([string]$Relative){$path=Join-Path $root $Relative;$tokens=$null;$errors=$null;[void][Management.Automation.Language.Parser]::ParseFile($path,[ref]$tokens,[ref]$errors);if(@($errors).Count){throw (($errors|ForEach-Object{"${Relative}:$($_.Extent.StartLineNumber):$($_.Extent.StartColumnNumber) $($_.Message)"})-join"`n")}}

$psTargets=@('HuymaierGameProviderWorker.ps1','HuymaierArtworkWorker.ps1','HuymaierSteamOwnership.ps1','HuymaierLibraryWorker.ps1','HuymaierSteamWorker.ps1','HuymaierEmulatorInstaller.ps1','HuymaierConsoleUpdateWorker.ps1','HuymaierEmulatorPlatforms.ps1')
foreach($file in $psTargets){Parse-Hc $file}
foreach($file in @('HuymaierGameProviderWorker.ps1','HuymaierArtworkWorker.ps1','HuymaierSteamOwnership.ps1','HuymaierLibraryWorker.ps1','HuymaierSteamWorker.ps1','HuymaierEmulatorInstaller.ps1','Native/HuymaierConsole.ConsolePlatforms.cs')){
    $text=Read-Hc $file
    foreach($line in @($text -split "`r?`n")){
        if($line -notmatch 'User-Agent|UserAgent'){continue}
        foreach($match in [regex]::Matches($line,'Huymaier-?Console/([0-9]+(?:\.[0-9]+){1,3})')){
            Need ([string]$match.Groups[1].Value -eq '0.30.8') ("stale active User-Agent in ${file}: "+$match.Value)
        }
    }
}
$update=Read-Hc 'HuymaierConsoleUpdateWorker.ps1'
Need ($update.Contains("[string]`$CurrentVersion='0.30.8'")) 'updater default CurrentVersion is stale'
Need ($update.Contains('HUYMAIER_V0308_RUNTIME_METADATA_V1')) 'runtime metadata cleanup marker missing'
$native=Read-Hc 'Native/HuymaierConsole.NativeApp.cs'
Need ($native.Contains('public string Version { get { return "0.30.8"; } }')) 'NativeBridge.Version is stale'
$platforms=Read-Hc 'HuymaierEmulatorPlatforms.ps1'
Need (-not $platforms.Contains('run the v0.25.6 installer once')) 'stale v0.25.6 installer guidance remains in active UI'
Need ($platforms.Contains('rerun the current Huymaier Console installer')) 'current generic installer recovery guidance missing'

# Old-named compatibility layers are still live dependencies. Cleanup must not
# delete them until their behavior is deliberately migrated into new owners.
$picker=Read-Hc 'HuymaierColorPicker.ps1';$provider=Read-Hc 'HuymaierV0262ProviderRuntime.ps1'
Need ($picker.Contains("Join-Path `$script:BaseDir 'HuymaierV0262Runtime.ps1'")) 'active v0.26.2 runtime compatibility loader was removed'
Need ($picker.Contains("Join-Path `$script:BaseDir 'HuymaierV0262ProviderRuntime.ps1'")) 'active v0.26.2 provider compatibility loader was removed'
Need ($provider.Contains("Join-Path `$script:BaseDir 'HuymaierV0262Hardening.ps1'")) 'active v0.26.2 hardening compatibility loader was removed'

Write-Host 'v0.30.8 production runtime metadata/dependency cleanup audit passed.'
