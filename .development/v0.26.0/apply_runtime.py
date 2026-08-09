from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def read(path):
    return (ROOT / path).read_text(encoding="utf-8-sig")


def write(path, text):
    (ROOT / path).write_text(text, encoding="utf-8")


def replace_once(text, old, new, label):
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f"{label}: expected exactly one match, found {count}")
    return text.replace(old, new, 1)


p = "HuymaierConsole.ps1"
s = read(p)
s = replace_once(
    s,
    "    if(-not (Test-ConsoleHasInputFocus)){\n        $script:LastGamepadMask=0;$script:LastDirection='';$script:NextDirectionAt=[datetime]::MinValue\n        try{if('HuymaierConsole.NativeApp.NativeConsoleNavigation' -as [type]){[HuymaierConsole.NativeApp.NativeConsoleNavigation]::Reset()}}catch{}\n        return\n    }",
    "    if(-not (Test-ConsoleHasInputFocus)){\n        # Do not reset the native router here. While an external game/app or the\n        # Huymaier Game Bar owns focus, the external Guide watcher uses this same\n        # router for A/B/D-pad/shoulder input. Resetting it from the background\n        # Console timer would erase every navigation edge before the overlay sees it.\n        $script:LastGamepadMask=0;$script:LastDirection='';$script:NextDirectionAt=[datetime]::MinValue\n        return\n    }",
    "external Game Bar native input ownership",
)
write(p, s)

p = "Native/HuymaierConsole.SystemOverlay.cs"
s = read(p)
s = replace_once(
    s,
    "                        if (consoleWindow.WindowState == WindowState.Minimized) consoleWindow.WindowState = WindowState.Maximized;\n                        consoleWindow.Show(); consoleWindow.Activate(); consoleWindow.Topmost = true; consoleWindow.Topmost = false; consoleWindow.Focus();",
    "                        if (consoleWindow.WindowState == WindowState.Minimized) consoleWindow.WindowState = WindowState.Maximized;\n                        // Flush external-overlay edges before Console resumes ownership.\n                        try { NativeConsoleNavigation.Reset(); } catch { }\n                        consoleWindow.Show(); consoleWindow.Activate(); consoleWindow.Topmost = true; consoleWindow.Topmost = false; consoleWindow.Focus();",
    "reset native input when returning to Console",
)
write(p, s)

print("v0.26.0 external overlay input ownership completed.")
