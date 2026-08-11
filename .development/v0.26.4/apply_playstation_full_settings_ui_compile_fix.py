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

# The complete-backend settings list and its controller keyboard are native
# console surfaces too. Guide/Home must open/focus the Huymaier Game Bar from
# either nested layer, while shoulders remain unused for ordinary navigation.
start=text.find('// v0.26.4 COMPLETE_BACKEND_SETTINGS_WINDOW_BEGIN')
end=text.find('// v0.26.4 COMPLETE_BACKEND_SETTINGS_WINDOW_END')
if start>=0 and end>start:
    block=text[start:end]
    needle='if (command == null || String.IsNullOrWhiteSpace(command.Command)) return;\n            if (command.Command == "Left")'
    replacement='if (command == null || String.IsNullOrWhiteSpace(command.Command)) return;\n            if (command.Command == "Guide") { HuymaierGameBarHost.Toggle(); return; }\n            if (command.Command == "Left")'
    if needle in block:block=block.replace(needle,replacement,1)
    needle2='if (command == null || String.IsNullOrWhiteSpace(command.Command)) return; if (command.Command == "Up")'
    replacement2='if (command == null || String.IsNullOrWhiteSpace(command.Command)) return; if (command.Command == "Guide") { HuymaierGameBarHost.Toggle(); return; } if (command.Command == "Up")'
    if needle2 in block:block=block.replace(needle2,replacement2,1)
    if block.count('command.Command == "Guide"') < 2:raise SystemExit('Guide/Game Bar routing is not present in both PlayStation full-settings nested input layers')
    if 'LeftShoulder' in block or 'RightShoulder' in block:raise SystemExit('PlayStation full-settings nested UI must not assign shoulder navigation')
    text=text[:start]+block+text[end:]
path.write_text(text,encoding='utf-8-sig')
print('PlayStation full-settings compile/navigation overlay applied')
