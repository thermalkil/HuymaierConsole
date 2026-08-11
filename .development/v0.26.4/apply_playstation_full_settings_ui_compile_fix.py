from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
path=ROOT/'Native'/'HuymaierConsole.NativeApp.cs'
text=path.read_text(encoding='utf-8-sig')
old='UniformGrid grid = new UniformGrid {'
new='System.Windows.Controls.Primitives.UniformGrid grid = new System.Windows.Controls.Primitives.UniformGrid {'
count=text.count(old)
if count>1: raise SystemExit(f'Expected at most one native backend keyboard UniformGrid declaration, found {count}')
if count==1:text=text.replace(old,new,1)
if 'COMPLETE_BACKEND_SETTINGS_WINDOW_BEGIN' in text and old in text:raise SystemExit('Unqualified UniformGrid remains in backend settings window')
path.write_text(text,encoding='utf-8-sig')
print('PlayStation full-settings compile overlay applied')
