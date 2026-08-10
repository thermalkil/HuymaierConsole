from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
path=ROOT/'HuymaierConsole.ps1'
text=path.read_text(encoding='utf-8-sig')

def once(old,new,label):
    global text
    count=text.count(old)
    if count!=1:
        raise SystemExit(f'{label}: expected one match, found {count}')
    text=text.replace(old,new,1)

once(
    "$script:EmulatorPlatformsModulePath = Join-Path $script:BaseDir 'HuymaierEmulatorPlatforms.ps1'",
    "$script:EmulatorPlatformsModulePath = Join-Path $script:BaseDir 'HuymaierEmulatorPlatforms.ps1'\n$script:EmulatorSettingsModulePath = Join-Path $script:BaseDir 'HuymaierEmulatorSettings.ps1'",
    'settings module path'
)
once(
    "if (Test-Path -LiteralPath $script:EmulatorPlatformsModulePath) {\n    try { . $script:EmulatorPlatformsModulePath }\n    catch { Write-Log \"Emulator platform module load failed: $($_.Exception.Message)\" 'ERROR' }\n}",
    "if (Test-Path -LiteralPath $script:EmulatorPlatformsModulePath) {\n    try { . $script:EmulatorPlatformsModulePath }\n    catch { Write-Log \"Emulator platform module load failed: $($_.Exception.Message)\" 'ERROR' }\n}\nif (Test-Path -LiteralPath $script:EmulatorSettingsModulePath) {\n    try { . $script:EmulatorSettingsModulePath }\n    catch { Write-Log \"Emulator settings module load failed: $($_.Exception.Message)\" 'ERROR' }\n}",
    'settings module load'
)
path.write_text(text,encoding='utf-8')

# Windows PowerShell 5.1 parses "$Path:" as a scoped-variable expression.
# Delimit the variable explicitly without changing the user-visible log text.
module=ROOT/'HuymaierEmulatorSettings.ps1'
module_text=module.read_text(encoding='utf-8-sig')
old='Write-Log "Could not back up emulator config $Path: $($_.Exception.Message)" \'WARN\''
new='Write-Log "Could not back up emulator config ${Path}: $($_.Exception.Message)" \'WARN\''
count=module_text.count(old)
if count != 1:
    raise SystemExit(f'emulator settings parser fix: expected one match, found {count}')
module.write_text(module_text.replace(old,new,1),encoding='utf-8')

print('integrated and parser-hardened HuymaierEmulatorSettings.ps1')
