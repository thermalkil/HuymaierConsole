from pathlib import Path


def read(path):
    return Path(path).read_text(encoding='utf-8-sig')


def write(path, text, bom=False):
    Path(path).write_text(text, encoding='utf-8-sig' if bom else 'utf-8', newline='\n')


def replace_once(text, old, new, label):
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{label}: expected exactly one match, found {count}')
    return text.replace(old, new, 1)

# Public installer wrapper: define the automatic native/script exit state before
# invoking the core. Interactive success leaves it at 0; the core's explicit
# `exit 1` on a real transactional failure updates it to 1. This preserves the
# RC8 failure behavior while eliminating StrictMode's undefined-variable error.
p = 'Install-HuymaierConsole.ps1'
t = read(p)
start = t.find('# HuymaierInstallerCore.ps1 exits 1 itself on a transactional failure.')
if start < 0:
    raise SystemExit('installer wrapper contract comment not found')
end_marker = 'exit 0\n'
end = t.find(end_marker, start)
if end < 0:
    raise SystemExit('installer wrapper success exit not found')
end += len(end_marker)
new = '''# Seed the process exit state because an interactive successful PowerShell\n# script invocation may never create $LASTEXITCODE. The installer core uses\n# explicit `exit 1` for a transactional failure, which updates this value; a\n# normal interactive success leaves the seeded 0 unchanged.\n$global:LASTEXITCODE=0\n& $core -PackageRoot $PSScriptRoot -SilentUpdate:$SilentUpdate\nexit ([int]$global:LASTEXITCODE)\n'''
t = t[:start] + new + t[end:]
write(p, t)

# Candidate static contract: allow LASTEXITCODE only in the seeded/returned form.
p = '.build/Test-HuymaierCandidate.ps1'
t = read(p)
old = '''    $wrapper=Get-Content -Raw -LiteralPath (Join-Path $StageRoot 'Install-HuymaierConsole.ps1') -Encoding UTF8\n    if($wrapper -match [regex]::Escape('$LASTEXITCODE')){throw 'Public installer wrapper still references $LASTEXITCODE.'}\n    if($wrapper -notmatch [regex]::Escape('exit 0')){throw 'Public installer wrapper has no explicit success exit code.'}\n'''
new = '''    $wrapper=Get-Content -Raw -LiteralPath (Join-Path $StageRoot 'Install-HuymaierConsole.ps1') -Encoding UTF8\n    if($wrapper -notmatch [regex]::Escape('$global:LASTEXITCODE=0')){throw 'Public installer wrapper does not seed a deterministic success exit state.'}\n    if($wrapper -notmatch [regex]::Escape('exit ([int]$global:LASTEXITCODE)')){throw 'Public installer wrapper does not propagate the core transaction exit state.'}\n'''
t = replace_once(t, old, new, 'candidate wrapper exit contract')
write(p, t, bom=True)

print('RC11 installer wrapper exit-state contract applied.')
