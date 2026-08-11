from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
path=ROOT/'HuymaierEmulatorSettingsWorker.ps1';text=path.read_text(encoding='utf-8-sig')
helper=r'''
function Initialize-FbNeoConfigIfNeeded {
    param([string[]]$Roots)
    foreach($root in @($Roots)){
        if([string]::IsNullOrWhiteSpace($root)-or-not(Test-Path -LiteralPath $root -PathType Container)){continue}
        $exe=@(Get-ChildItem -LiteralPath $root -File -Recurse -ErrorAction SilentlyContinue|Where-Object{$_.Name -match '(?i)^fbneo(?:64)?\.exe$' -or $_.Name -match '(?i)^FinalBurnNeo(?:64)?\.exe$'}|Select-Object -First 1)
        if(-not$exe){continue}
        $config=Join-Path $exe[0].Directory.FullName ('config\'+[IO.Path]::GetFileNameWithoutExtension($exe[0].Name)+'.ini')
        if(Test-Path -LiteralPath $config -PathType Leaf){return $config}
        $stdout=Join-Path $env:TEMP ('hc-fbneo-listinfo-'+[guid]::NewGuid().ToString('N')+'.out')
        $stderr=Join-Path $env:TEMP ('hc-fbneo-listinfo-'+[guid]::NewGuid().ToString('N')+'.err')
        try{
            # FBNeo -listinfo emits a very large driver listing and can block if its
            # redirected stdout pipe is not continuously drained. Redirect to files,
            # poll only for the config artifact Huymaier needs, then terminate as soon
            # as the complete first-run config has appeared.
            $process=Start-Process -FilePath $exe[0].FullName -ArgumentList '-listinfo' -WorkingDirectory $exe[0].Directory.FullName -RedirectStandardOutput $stdout -RedirectStandardError $stderr -PassThru -WindowStyle Hidden
            $deadline=[DateTime]::UtcNow.AddSeconds(15)
            while([DateTime]::UtcNow -lt $deadline -and -not(Test-Path -LiteralPath $config -PathType Leaf)){
                if($process.HasExited){break}
                Start-Sleep -Milliseconds 150
            }
            if(-not$process.HasExited){try{$process.Kill();$process.WaitForExit()}catch{}}
        }catch{Write-Log "FBNeo default configuration initialization recovered: $($_.Exception.Message)" 'WARN'}
        finally{Remove-Item -LiteralPath $stdout,$stderr -Force -ErrorAction SilentlyContinue}
        if(Test-Path -LiteralPath $config -PathType Leaf){return $config}
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
print('materialized nonblocking FBNeo first-run full config initialization')
