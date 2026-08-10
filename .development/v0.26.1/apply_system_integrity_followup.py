from pathlib import Path

p=Path('Install-HuymaierConsole.ps1')
t=p.read_text(encoding='utf-8-sig')
needle="    'THIRD_PARTY_NOTICES.txt'\n)"
replacement="    'THIRD_PARTY_NOTICES.txt',\n    'manifest.json',\n    'checksums.sha256',\n    'SHA256SUMS.txt'\n)"
if "    'manifest.json'," not in t:
    if needle not in t: raise SystemExit('installer payload list tail not found')
    t=t.replace(needle,replacement,1)
p.write_text(t,encoding='utf-8-sig',newline='\n')

# Closed packages deliberately exclude repository/developer-only material.
# The build workflow owns this list too; this marker is asserted in CI.
Path('.development/v0.26.1/package-excludes.txt').write_text(
    '.github/\n.development/\n.release/\n.source/\nDocs/\n.gitignore\nREADME.md\nRELEASING.md\nGITHUB-RELEASES.md\n',
    encoding='utf-8',newline='\n')

print('v0.26.1 system integrity follow-up completed')
