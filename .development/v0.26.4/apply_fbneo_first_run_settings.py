from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
path=ROOT/'HuymaierEmulatorSettingsWorker.ps1';text=path.read_text(encoding='utf-8-sig')
helper=r'''
function Invoke-FbNeoHiddenInitialization {
    param([string]$Executable,[string]$WorkingDirectory,[string]$ConfigPath,[string]$Arguments='')
    $stdout=Join-Path $env:TEMP ('hc-fbneo-init-'+[guid]::NewGuid().ToString('N')+'.out')
    $stderr=Join-Path $env:TEMP ('hc-fbneo-init-'+[guid]::NewGuid().ToString('N')+'.err')
    try{
        $start=@{FilePath=$Executable;WorkingDirectory=$WorkingDirectory;PassThru=$true;WindowStyle='Hidden';RedirectStandardOutput=$stdout;RedirectStandardError=$stderr}
        if(-not[string]::IsNullOrWhiteSpace($Arguments)){$start.ArgumentList=$Arguments}
        $process=Start-Process @start
        $deadline=[DateTime]::UtcNow.AddSeconds(5)
        while([DateTime]::UtcNow -lt $deadline -and -not(Test-Path -LiteralPath $ConfigPath -PathType Leaf)){
            if($process.HasExited){break};Start-Sleep -Milliseconds 150
        }
        if(-not$process.HasExited){try{[void]$process.CloseMainWindow()}catch{};try{[void]$process.WaitForExit(2500)}catch{}}
        if(-not$process.HasExited){try{$process.Kill();$process.WaitForExit()}catch{}}
    }catch{Write-Log "FBNeo hidden initialization recovered: $($_.Exception.Message)" 'WARN'}
    finally{Remove-Item -LiteralPath $stdout,$stderr -Force -ErrorAction SilentlyContinue}
    return (Test-Path -LiteralPath $ConfigPath -PathType Leaf)
}

function Initialize-FbNeoConfigIfNeeded {
    param([string[]]$Roots)
    foreach($root in @($Roots)){
        if([string]::IsNullOrWhiteSpace($root)-or-not(Test-Path -LiteralPath $root -PathType Container)){continue}
        $exe=@(Get-ChildItem -LiteralPath $root -File -Recurse -ErrorAction SilentlyContinue|Where-Object{$_.Name -match '(?i)^fbneo(?:64)?\.exe$' -or $_.Name -match '(?i)^FinalBurnNeo(?:64)?\.exe$'}|Select-Object -First 1)
        if(-not$exe){continue}
        $config=Join-Path $exe[0].Directory.FullName ('config\'+[IO.Path]::GetFileNameWithoutExtension($exe[0].Name)+'.ini')
        if(Test-Path -LiteralPath $config -PathType Leaf){return $config}
        # Prefer the command-line listing path. If that build does not save its
        # defaults during -listinfo, do one normal startup hidden from the user and
        # close it normally so FBNeo's AppExit persists the authoritative config.
        if(Invoke-FbNeoHiddenInitialization -Executable $exe[0].FullName -WorkingDirectory $exe[0].Directory.FullName -ConfigPath $config -Arguments '-listinfo'){return $config}
        if(Invoke-FbNeoHiddenInitialization -Executable $exe[0].FullName -WorkingDirectory $exe[0].Directory.FullName -ConfigPath $config){return $config}
    }
    return ''
}

'''
if 'function Initialize-FbNeoConfigIfNeeded {' not in text:
    anchor='$definition=Get-PlatformDefinition $PlatformId\n'
    if text.count(anchor)!=1:raise SystemExit('FBNeo first-run helper insertion anchor missing')
    text=text.replace(anchor,helper+anchor,1)
old='$roots=Get-ConfigRoots -AdapterId $adapterId -Settings $settings\n$configFiles=Get-ExplicitConfigFiles -AdapterId $adapterId -Roots $roots\n'
new="$roots=Get-ConfigRoots -AdapterId $adapterId -Settings $settings\nif($adapterId -ieq 'fbneo'){[void](Initialize-FbNeoConfigIfNeeded -Roots $roots)}\n$configFiles=Get-ExplicitConfigFiles -AdapterId $adapterId -Roots $roots\n"
if old in text:text=text.replace(old,new,1)
elif new not in text:raise SystemExit('FBNeo first-run invocation anchor missing')
path.write_text(text,encoding='utf-8-sig')
print('materialized hidden fallback FBNeo first-run full config initialization')
