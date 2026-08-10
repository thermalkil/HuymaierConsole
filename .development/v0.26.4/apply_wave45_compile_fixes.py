from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
path=ROOT/'Native'/'HuymaierConsole.ConsolePlatforms.cs'
text=path.read_text(encoding='utf-8-sig')
count=text.count('WrapPanel cards=new WrapPanel;')
if count not in (0,1):raise SystemExit(f'Wave 4/5 WrapPanel compile fix expected 0 or 1 matches, found {count}')
if count:text=text.replace('WrapPanel cards=new WrapPanel;','WrapPanel cards=new WrapPanel();')
path.write_text(text,encoding='utf-8')
print(f'Wave 4/5 compile corrections: {count}')
