from pathlib import Path


def replace_once(path, old, new):
    p = Path(path)
    text = p.read_text(encoding='utf-8-sig')
    if old not in text:
        raise SystemExit(f'Expected text not found in {path}: {old!r}')
    text = text.replace(old, new, 1)
    p.write_text(text, encoding='utf-8-sig')

# The core is a library-style implementation. On success it must return to the
# public installer wrapper so the wrapper owns the process exit code. On a
# transactional failure the existing trap still exits 1 immediately.
replace_once(
    'HuymaierInstallerCore.ps1',
    "if($SilentUpdate){exit 0}",
    "if($SilentUpdate){return}"
)

# Candidate tests invoke the public wrapper with -SilentUpdate. With the core
# returning normally, every successful installer test now traverses the exact
# wrapper success path that failed interactively on RC8.
p = Path('.build/Test-HuymaierCandidate.ps1')
text = p.read_text(encoding='utf-8-sig')
anchor = "    # Static conflict gates for Windows/Game Bar ownership and dead paths.\n"
addition = """    # Public installer wrapper invariant. The wrapper must own the success\n    # process exit code explicitly; $LASTEXITCODE is not guaranteed to exist\n    # after invoking another PowerShell script under StrictMode.\n    $wrapper=Get-Content -Raw -LiteralPath (Join-Path $StageRoot 'Install-HuymaierConsole.ps1') -Encoding UTF8\n    if($wrapper -match [regex]::Escape('$LASTEXITCODE')){throw 'Public installer wrapper still depends on undefined $LASTEXITCODE.'}\n    $coreText=Get-Content -Raw -LiteralPath (Join-Path $StageRoot 'HuymaierInstallerCore.ps1') -Encoding UTF8\n    if($coreText -match [regex]::Escape('if($SilentUpdate){exit 0}')){throw 'Installer core still bypasses the public wrapper success path during CI.'}\n\n"""
if addition not in text:
    if anchor not in text:
        raise SystemExit('Candidate-test insertion anchor not found')
    text = text.replace(anchor, addition + anchor, 1)
p.write_text(text, encoding='utf-8-sig')
