from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
path=ROOT/'.source'/'source-files.txt'
lines=[]
if path.exists():
    lines=[line.strip().replace('\\','/') for line in path.read_text(encoding='utf-8-sig').splitlines() if line.strip()]
entries=set(lines)
for fixed in [
    'Docs/EMULATOR-PLATFORMS.md','Docs/PLATFORM-EXPANSION-v0.26.4.md','Docs/PLATFORM-IMPLEMENTATION-STATUS-v0.26.4.md',
    'EmulatorPlatforms/emulator-adapters.json','EmulatorPlatforms/platform-registry.json',
    'HuymaierEmulatorInstaller.ps1','HuymaierEmulatorPlatforms.ps1','HuymaierEmulatorSettings.ps1','HuymaierEmulatorSettingsWorker.ps1','HuymaierNativeConsoleLibraryWorker.ps1',
    'Native/HuymaierConsole.ConsolePlatforms.cs'
]: entries.add(fixed)
for folder in (ROOT/'EmulatorPlatforms').iterdir():
    if not folder.is_dir(): continue
    for name in ('platform.json','settings.default.json'):
        candidate=folder/name
        if candidate.exists(): entries.add(candidate.relative_to(ROOT).as_posix())
    assets=folder/'Assets'
    if assets.exists():
        for readme in assets.glob('README*.txt'): entries.add(readme.relative_to(ROOT).as_posix())
# Preserve the existing list, but normalize/sort it so future branch merges do not
# accidentally drop expansion platform source files.
path.write_text('\n'.join(sorted(entries,key=str.lower))+'\n',encoding='utf-8')
print(f'source sync manifest contains {len(entries)} production source entries')
