from pathlib import Path

p=Path('Native/HuymaierConsole.SystemOverlay.cs')
t=p.read_text(encoding='utf-8-sig')
old='if (content != null) Keyboard.Focus(content);'
new='if (content != null) System.Windows.Input.Keyboard.Focus(content);'
if t.count(old)!=1:
    raise SystemExit(f'expected one unqualified Keyboard.Focus call, found {t.count(old)}')
p.write_text(t.replace(old,new,1),encoding='utf-8',newline='\n')
print('Qualified WPF Keyboard.Focus in Game Bar foreground promotion.')
