from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PATH = ROOT / 'Native' / 'HuymaierConsole.SystemOverlay.cs'
text = PATH.read_text(encoding='utf-8-sig')

old = '''            if (command == "Left") { if (page == PageAudio && selected == 0) { AdjustVolume(-5); return; } if (page == PageSwitcher) { Move(-1); return; } }
            if (command == "Right") { if (page == PageAudio && selected == 0) { AdjustVolume(5); return; } if (page == PageSwitcher) { Move(1); return; } }
            if (command == "Up") { if (page != PageSwitcher) Move(-1); return; }
            if (command == "Down") { if (page != PageSwitcher) Move(1); return; }'''
new = '''            bool horizontalRail = page == PageHome || page == PageSwitcher;
            if (command == "Left")
            {
                if (page == PageAudio && selected == 0) { AdjustVolume(-5); return; }
                if (horizontalRail) { Move(-1); return; }
            }
            if (command == "Right")
            {
                if (page == PageAudio && selected == 0) { AdjustVolume(5); return; }
                if (horizontalRail) { Move(1); return; }
            }
            // Home and Switch Apps are horizontal rails. Vertical pages keep Up/Down.
            if (command == "Up") { if (!horizontalRail) Move(-1); return; }
            if (command == "Down") { if (!horizontalRail) Move(1); return; }'''

if text.count(old) != 1:
    raise RuntimeError(f'Game Bar navigation block match count: {text.count(old)}')
text = text.replace(old, new, 1)
PATH.write_text(text, encoding='utf-8')
print('Game Bar Home and Switch Apps now use Left/Right navigation; vertical pages retain Up/Down.')
