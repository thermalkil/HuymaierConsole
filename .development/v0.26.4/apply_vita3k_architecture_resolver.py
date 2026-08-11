from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
path=ROOT/'HuymaierEmulatorInstaller.ps1';text=path.read_text(encoding='utf-8-sig')
old="    'VITA' {$exe=Install-GithubArchive 'Vita3K/Vita3K' { $_.name -match '(?i)(windows|win).*(x64|64).*\\.(zip|7z)$' -or $_.name -match '(?i)Vita3K.*windows.*\\.(zip|7z)$' } 'Vita3K' @('Vita3K.exe','vita3k.exe')}"
new="    'VITA' {$exe=Install-GithubArchive 'Vita3K/Vita3K' { $_.name -ieq 'windows-latest.zip' -or ($_.name -match '(?i)(windows|win).*(x86_64|x64|amd64).*\\.(zip|7z)$' -and $_.name -notmatch '(?i)(arm64|aarch64)') } 'Vita3K' @('Vita3K.exe','vita3k.exe')}"
if old in text:text=text.replace(old,new,1)
elif new not in text:raise SystemExit('Vita3K installer resolver anchor missing')
path.write_text(text,encoding='utf-8-sig')
print('materialized Vita3K exact Windows x64 resolver; ARM64 excluded')
