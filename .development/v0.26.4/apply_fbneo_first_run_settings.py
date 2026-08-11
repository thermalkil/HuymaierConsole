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
        try{
            $psi=New-Object Diagnostics.ProcessStartInfo;$psi.FileName=$exe[0].FullName;$psi.Arguments='-listinfo';$psi.WorkingDirectory=$exe[0].Directory.FullName;$psi.UseShellExecute=$false;$psi.CreateNoWindow=$true;$psi.RedirectStandardOutput=$true;$psi.RedirectStandardError=$true
            $process=[Diagnostics.Process]::Start($psi);if($null-ne$process){$stdoutTask=$process.StandardOutput.ReadToEndAsync();$stderrTask=$process.StandardError.ReadToEndAsync();if(-not$process.WaitForExit(20000)){try{$process.Kill()}catch{}};try{$null=$stdoutTask.Result;$null=$stderrTask.Result}catch{}}
        }catch{Write-Log "FBNeo default configuration initialization recovered: $($_.Exception.Message)" 'WARN'}
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
print('materialized FBNeo non-GUI first-run full config initialization')
