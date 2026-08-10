from pathlib import Path


def read(path):
    return Path(path).read_text(encoding='utf-8-sig')


def write(path,text,bom=False):
    Path(path).write_text(text,encoding='utf-8-sig' if bom else 'utf-8',newline='\n')


def replace_once(text,old,new,label):
    count=text.count(old)
    if count!=1:
        raise SystemExit(f'{label}: expected exactly one match, found {count}')
    return text.replace(old,new,1)

# Prune non-runtime material inherited from the previous release before overlay.
p='.build/Build-HuymaierReleaseCandidate.ps1'
t=read(p)
old="""Copy-Item (Join-Path $baseRoot '*') $stage -Recurse -Force

# Overlay repository-owned production payload only. Developer/release machinery
"""
new="""Copy-Item (Join-Path $baseRoot '*') $stage -Recurse -Force

# Previous release ZIPs may contain historical development/release material.
# Production candidates start from the runtime/media base only; stale CI/source
# metadata must never survive merely because it existed in an older package.
foreach($inheritedDev in @('.development','.source','.release','.github','.build','Docs')){
    Remove-Item -LiteralPath (Join-Path $stage $inheritedDev) -Recurse -Force -ErrorAction SilentlyContinue
}
Get-ChildItem -LiteralPath $stage -File -Filter 'BUILD-VALIDATION*.txt' -ErrorAction SilentlyContinue|Remove-Item -Force -ErrorAction SilentlyContinue
Get-ChildItem -LiteralPath $stage -File -Filter 'RELEASE_NOTES-v*.txt' -ErrorAction SilentlyContinue|Remove-Item -Force -ErrorAction SilentlyContinue

# Overlay repository-owned production payload only. Developer/release machinery
"""
t=replace_once(t,old,new,'builder inherited prune')
write(p,t,bom=True)

# Candidate test asserts that developer/history material cannot re-enter the ZIP.
p='.build/Test-HuymaierCandidate.ps1'
t=read(p)
anchor="""    # Static conflict gates for Windows/Game Bar ownership and dead paths.
"""
insert="""    # Production-package hygiene: no repository development state or stale
    # validation/release-history files may survive from the base ZIP.
    foreach($forbiddenDir in @('.development','.source','.release','.github','.build','Docs')){
        if(Test-Path -LiteralPath (Join-Path $StageRoot $forbiddenDir)){throw "Developer-only package directory survived staging: $forbiddenDir"}
    }
    if(@(Get-ChildItem -LiteralPath $StageRoot -File -Filter 'BUILD-VALIDATION*.txt' -ErrorAction SilentlyContinue).Count -gt 0){throw 'Historical BUILD-VALIDATION files survived production staging.'}
    if(@(Get-ChildItem -LiteralPath $StageRoot -File -Filter 'RELEASE_NOTES-v*.txt' -ErrorAction SilentlyContinue).Count -gt 0){throw 'Historical versioned release-note files survived production staging.'}

"""
if 'Developer-only package directory survived staging' not in t:
    if anchor not in t: raise SystemExit('candidate hygiene insertion anchor missing')
    t=t.replace(anchor,insert+anchor,1)
write(p,t,bom=True)

# GitHub release promotion runs on Linux, while the exact Windows Compress-Archive
# candidate stores entry separators as backslashes. Normalize for validation but
# retain a normalized->raw map for zipfile reads so the exact bytes are promoted.
p='.github/workflows/publish-release.yml'
t=read(p)
old="""          with zipfile.ZipFile(zp,'r') as z:
              names=[n.replace('\\\\','/') for n in z.namelist() if not n.endswith('/')]
              if not names:
                  raise SystemExit('Candidate ZIP has no files.')
"""
new="""          with zipfile.ZipFile(zp,'r') as z:
              raw_files=[n for n in z.namelist() if not n.endswith(('/', '\\\\'))]
              normalized=[n.replace('\\\\','/') for n in raw_files]
              if not normalized:
                  raise SystemExit('Candidate ZIP has no files.')
              if len(set(normalized))!=len(normalized):
                  raise SystemExit('Candidate ZIP contains duplicate paths after Windows separator normalization.')
              raw_by_normalized=dict(zip(normalized,raw_files))
              names=list(raw_by_normalized)
              def read_norm(name):
                  try: raw=raw_by_normalized[name]
                  except KeyError: raise SystemExit(f'Candidate ZIP is missing {name}')
                  return z.read(raw)
"""
t=replace_once(t,old,new,'promotion normalized raw map')
for old,new,label in [
    ("manifest=json.loads(z.read(manifest_name).decode('utf-8-sig'))","manifest=json.loads(read_norm(manifest_name).decode('utf-8-sig'))",'manifest read'),
    ("checks=z.read(checks_name).decode('utf-8')","checks=read_norm(checks_name).decode('utf-8')",'checks read'),
    ("compat=z.read(compat_name).decode('utf-8')","compat=read_norm(compat_name).decode('utf-8')",'compat read'),
    ("data=z.read(prefix+rel)\n                  if hashlib.sha256(data).hexdigest()!=expected_hash:","data=read_norm(prefix+rel)\n                  if hashlib.sha256(data).hexdigest()!=expected_hash:",'payload hash read'),
    ("data=z.read(prefix+rel)\n                  if len(data)<0x40", "data=read_norm(prefix+rel)\n                  if len(data)<0x40", 'PE read'),
]:
    t=replace_once(t,old,new,label)
write(p,t)

print('v0.26.1 package prune and promotion ZIP normalization completed')
