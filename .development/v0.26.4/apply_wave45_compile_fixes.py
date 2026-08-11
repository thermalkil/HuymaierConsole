from pathlib import Path
import re
ROOT=Path(__file__).resolve().parents[2]
path=ROOT/'Native'/'HuymaierConsole.ConsolePlatforms.cs'
text=path.read_text(encoding='utf-8-sig')
fixes={
    'WrapPanel cards=new WrapPanel;':'WrapPanel cards=new WrapPanel();',
    'Grid icon=new Grid;':'Grid icon=new Grid();'
}
changed=0
for old,new in fixes.items():
    count=text.count(old)
    if count>1:raise SystemExit(f'Wave 4/5 compile fix expected at most one {old!r}, found {count}')
    if count:
        text=text.replace(old,new,1);changed+=count
# Refuse to silently ship another generated bare constructor for the WPF types
# used by the Wave 4/5 renderer. Object initializers (`new Grid{...}`) are valid.
bare=re.findall(r'\b(?:Grid|WrapPanel|StackPanel|Border|Button|TextBlock|ScrollViewer)\s+\w+\s*=\s*new\s+(?:Grid|WrapPanel|StackPanel|Border|Button|TextBlock|ScrollViewer)\s*;',text)
if bare:raise SystemExit('Wave 4/5 generated source still contains bare constructors: '+', '.join(bare[:8]))
path.write_text(text,encoding='utf-8')
print(f'Wave 4/5 compile corrections: {changed}')
