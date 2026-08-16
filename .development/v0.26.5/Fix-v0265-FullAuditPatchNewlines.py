from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

replacements = {
    'HuymaierUser3DModels.ps1': [
        ("$displayName=Get-HcPlatformDisplayLabel $Platform $Group`r`n    $label.Text=$displayName;", "$displayName=Get-HcPlatformDisplayLabel $Platform $Group\n    $label.Text=$displayName;"),
    ],
    'HuymaierGpuPlatformShelves.ps1': [
        ("$displayName=Get-HcPlatformDisplayLabel $Platform $Group`r`n    $label=New-Object", "$displayName=Get-HcPlatformDisplayLabel $Platform $Group\n    $label=New-Object"),
    ],
    'HuymaierLivePlatformModels.ps1': [
        ("$viewerGroup=$(if(Test-HcStorefrontPlatform $Platform){'Providers'}else{'Consoles'})`r`n    $title.Text=", "$viewerGroup=$(if(Test-HcStorefrontPlatform $Platform){'Providers'}else{'Consoles'})\n    $title.Text="),
    ],
}

for rel, pairs in replacements.items():
    path = ROOT / rel
    text = path.read_text(encoding='utf-8-sig')
    for old, new in pairs:
        count = text.count(old)
        if count != 1:
            raise RuntimeError(f'{rel}: expected one generated literal-newline marker, found {count}')
        text = text.replace(old, new, 1)
    path.write_text(text, encoding='utf-8')

print('fullAuditGeneratedNewlinesGate: success')
