from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
path=ROOT/'HuymaierEmulatorInstaller.ps1';text=path.read_text(encoding='utf-8-sig')
old="""function Install-MameLatest {
    $assets=Get-GithubLatestAssets 'mamedev/mame'
    $asset=@($assets|Where-Object{$_.name -match '(?i)^mame[0-9]+b?_64bit\\.exe$' -or $_.name -match '(?i)mame.*64.*\\.exe$'}|Select-Object -First 1)
    if(-not $asset){throw 'The latest official MAME GitHub release did not expose a 64-bit Windows self-extracting archive.'}
"""
new="""function Install-MameLatest {
    $asset=Get-GithubReleaseAsset 'mamedev/mame' { $_.name -match '(?i)^mame[0-9]+b?_x64\\.exe$' -or ($_.name -match '(?i)^mame[0-9]+b?_.*(x86_64|amd64|x64).*\\.exe$' -and $_.name -notmatch '(?i)(arm64|aarch64|source|symbols|debug)') }
    if(-not $asset){throw 'The latest official MAME GitHub release did not expose a Windows x64 self-extracting archive.'}
"""
if old in text:text=text.replace(old,new,1)
elif new not in text:raise SystemExit('MAME installer helper anchor missing')
path.write_text(text,encoding='utf-8-sig')
print('materialized MAME current Windows x64 release resolver using shared GitHub asset helper')
