from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
path=ROOT/'Native'/'HuymaierConsole.ConsolePlatforms.cs'
text=path.read_text(encoding='utf-8-sig')
old='ChooseEmulatorDataPath'
count=text.count(old)
if count:
    text=text.replace(old,'ChooseEmulatorDataRoot')
    path.write_text(text,encoding='utf-8')
print(f'Wave 1 compile corrections applied: {count} emulator-data method reference(s)')
