from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
path=ROOT/'Native'/'HuymaierConsole.ConsolePlatforms.cs'
text=path.read_text(encoding='utf-8-sig')
old='WrapPanel cards=new WrapPanel;'
count=text.count(old)
if count not in (0,4):
    raise SystemExit(f'Wave 2 WrapPanel compile fix expected 0 or 4 matches, found {count}')
if count:
    text=text.replace(old,'WrapPanel cards=new WrapPanel();')
    path.write_text(text,encoding='utf-8')
print(f'Wave 2 compile correction applied to {count} WrapPanel instantiation(s)')
