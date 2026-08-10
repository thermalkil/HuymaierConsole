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

p = '.build/Test-HuymaierCandidate.ps1'
t = read(p)

obsolete = '''    # Public installer wrapper invariant. The wrapper must own the success\n    # process exit code explicitly; $LASTEXITCODE is not guaranteed to exist\n    # after invoking another PowerShell script under StrictMode.\n    $wrapper=Get-Content -Raw -LiteralPath (Join-Path $StageRoot 'Install-HuymaierConsole.ps1') -Encoding UTF8\n    if($wrapper -match [regex]::Escape('$LASTEXITCODE')){throw 'Public installer wrapper still depends on undefined $LASTEXITCODE.'}\n    $coreText=Get-Content -Raw -LiteralPath (Join-Path $StageRoot 'HuymaierInstallerCore.ps1') -Encoding UTF8\n    if($coreText -match [regex]::Escape('if($SilentUpdate){exit 0}')){throw 'Installer core still bypasses the public wrapper success path during CI.'}\n\n'''
t = replace_once(t, obsolete, '', 'remove obsolete wrapper invariant')

t = replace_once(
    t,
    "foreach($required in @('UseNexusForGameBarEnabled','Get-HcGameInputGuideEdge','Invoke-HcInternalGuide'))",
    "foreach($required in @('UseNexusForGameBarEnabled','Get-HcSystemGuideEdge','Invoke-HcInternalGuide'))",
    'Game Bar Guide-only required-name gate'
)

t = t.replace(
    '# installer wrapper must own success without relying on $LASTEXITCODE.',
    '# installer wrapper must seed success state while propagating real failures.'
)

anchor = '''    if($wrapper -notmatch [regex]::Escape('exit ([int]$global:LASTEXITCODE)')){throw 'Public installer wrapper does not propagate the core transaction exit state.'}\n'''
insert = anchor + '''    $coreText=Get-Content -Raw -LiteralPath (Join-Path $StageRoot 'HuymaierInstallerCore.ps1') -Encoding UTF8\n    if($coreText -notmatch [regex]::Escape('if($SilentUpdate){return}')){throw 'Installer core does not return through the public wrapper on silent success.'}\n'''
t = replace_once(t, anchor, insert, 'wrapper/core success-path gate')

validation_anchor = '''    $validation|Add-Member -NotePropertyName unmanagedDataPreservation -NotePropertyValue 'success' -Force\n'''
validation_insert = validation_anchor + '''    $validation|Add-Member -NotePropertyName guideOnlyWakeGate -NotePropertyValue 'success' -Force\n    $validation|Add-Member -NotePropertyName installerWrapperExitGate -NotePropertyValue 'success' -Force\n'''
t = replace_once(t, validation_anchor, validation_insert, 'validation gate fields')

write(p, t, bom=True)
print('RC12 candidate test gates consolidated around the final Guide-only and wrapper contracts.')
