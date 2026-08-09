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


# Native controller semantics: Guide is system-only; face buttons and Menu/View
# remain distinct so Game Bar prompts correspond to real commands.
p = "Native/HuymaierConsole.NativeApp.cs"
s = read(p)
s = replace_once(
    s,
    "        None, Left, Right, Up, Down, Confirm, Back, Guide, Menu, Options, LeftShoulder, RightShoulder",
    "        None, Left, Right, Up, Down, Confirm, Back, Secondary, Tertiary, Guide, Menu, View, Options, LeftShoulder, RightShoulder",
    "native command enum",
)
s = replace_once(
    s,
    "            if ((newButtons & 1) != 0) return XmbInputCommand.Confirm;\n            if ((newButtons & 2) != 0) return XmbInputCommand.Back;\n            if ((newButtons & 4) != 0) return XmbInputCommand.Guide;\n            if ((newButtons & 32) != 0) return XmbInputCommand.Options;\n            if ((newButtons & 8) != 0) return XmbInputCommand.LeftShoulder;\n            if ((newButtons & 16) != 0) return XmbInputCommand.RightShoulder;",
    "            if ((newButtons & 1) != 0) return XmbInputCommand.Confirm;\n            if ((newButtons & 2) != 0) return XmbInputCommand.Back;\n            if ((newButtons & 64) != 0) return XmbInputCommand.Secondary;\n            if ((newButtons & 128) != 0) return XmbInputCommand.Tertiary;\n            if ((newButtons & 4) != 0) return XmbInputCommand.Guide;\n            if ((newButtons & 32) != 0) return XmbInputCommand.Menu;\n            if ((newButtons & 256) != 0) return XmbInputCommand.View;\n            if ((newButtons & 8) != 0) return XmbInputCommand.LeftShoulder;\n            if ((newButtons & 16) != 0) return XmbInputCommand.RightShoulder;",
    "native face/menu command routing",
)
s = replace_once(
    s,
    "                    if ((snapshot.Mask & 2) != 0 && !systemGuideOwned) buttons |= 4;\n                    if ((snapshot.Mask & 1) != 0 || (snapshot.Mask & 32) != 0) buttons |= 32;\n                    if ((snapshot.Mask & 1024) != 0) buttons |= 8;",
    "                    if ((snapshot.Mask & 2) != 0 && !systemGuideOwned) buttons |= 4;\n                    if ((snapshot.Mask & 1) != 0) buttons |= 32;\n                    if ((snapshot.Mask & 16) != 0) buttons |= 64;\n                    if ((snapshot.Mask & 32) != 0) buttons |= 128;\n                    if ((snapshot.Mask & 1024) != 0) buttons |= 8;",
    "Sony face/menu mapping",
)
s = replace_once(
    s,
    "                        if ((mask & 0x0400) != 0) buttons |= 4;\n                        if ((mask & 0x8000) != 0) buttons |= 32;\n                        if ((mask & 0x0100) != 0) buttons |= 8;",
    "                        if ((mask & 0x0400) != 0) buttons |= 4;\n                        if ((mask & 0x0010) != 0) buttons |= 32;\n                        if ((mask & 0x0020) != 0) buttons |= 256;\n                        if ((mask & 0x4000) != 0) buttons |= 64;\n                        if ((mask & 0x8000) != 0) buttons |= 128;\n                        if ((mask & 0x0100) != 0) buttons |= 8;",
    "XInput face/menu/view mapping",
)
write(p, s)


# Shell uses the expanded native command model. Menu/Options no longer jumps to
# Power; Guide opens Quick Access and X/Square remains the real secondary action.
p = "HuymaierConsole.ps1"
s = read(p)
s = replace_once(
    s,
    "                'Confirm' {$nativeMask=4}\n                'Back' {$nativeMask=8}\n                'Guide' {$nativeMask=2}\n                'LeftShoulder' {$nativeMask=1024}",
    "                'Confirm' {$nativeMask=4}\n                'Back' {$nativeMask=8}\n                'Secondary' {$nativeMask=16}\n                'Tertiary' {$nativeMask=32}\n                'Guide' {$nativeMask=2}\n                'Menu' {$nativeMask=1}\n                'View' {$nativeMask=4096}\n                'LeftShoulder' {$nativeMask=1024}",
    "shell native command mapping",
)
s = replace_once(
    s,
    "    if(Is-NewButtonPress $Mask 16){Invoke-SecondaryAction}\n    if(Is-NewButtonPress $Mask 1){Invoke-UiFeedback 'Confirm';Set-Tab 8}\n",
    "    if(Is-NewButtonPress $Mask 16){Invoke-SecondaryAction}\n",
    "remove global Menu to Power shortcut",
)
s = replace_once(
    s,
    "            Add-PromptPair (New-KeycapPrompt 'PS' 34) 'Quick Access'\n            Add-PromptPair (New-PlayStationPrompt 'Options') 'Power'",
    "            Add-PromptPair (New-KeycapPrompt 'PS' 34) 'Quick Access'",
    "remove PlayStation Options Power prompt",
)
s = replace_once(
    s,
    "            Add-PromptPair (New-KeycapPrompt 'HOME' 48) 'Quick Access'\n            Add-PromptPair (New-KeycapPrompt '+') 'Power'",
    "            Add-PromptPair (New-KeycapPrompt 'HOME' 48) 'Quick Access'",
    "remove Nintendo Plus Power prompt",
)
s = replace_once(
    s,
    "            Add-PromptPair (New-KeycapPrompt 'XBOX' 48) 'Quick Access'\n            Add-PromptPair (New-KeycapPrompt 'MENU' 48) 'Power'",
    "            Add-PromptPair (New-KeycapPrompt 'XBOX' 48) 'Quick Access'",
    "remove Xbox Menu Power prompt",
)
write(p, s)


# Standardize installer source naming on the real managed overlay file.
p = "Install-HuymaierConsole.ps1"
s = read(p)
s = replace_once(
    s,
    "$nativeGameBarSource=Join-Path $nativeDestinationRoot 'HuymaierGameBar.cs'\n$nativeGameInputSource=Join-Path $nativeDestinationRoot 'HuymaierConsole.GameInput.cs'",
    "$nativeSystemOverlaySource=Join-Path $nativeDestinationRoot 'HuymaierConsole.SystemOverlay.cs'\n$nativeGameInputSource=Join-Path $nativeDestinationRoot 'HuymaierConsole.GameInput.cs'",
    "installer overlay source variable",
)
s = replace_once(
    s,
    "foreach($requiredSource in @($nativeAppSource,$nativePs1Source,$nativeConsolePlatformsSource,$nativeGameBarSource,$nativeGameInputSource,$nativeInputSource,$nativeDisplaySource,$nativeAudioSource,$nativePerformanceSource,$p3tSource)){",
    "foreach($requiredSource in @($nativeAppSource,$nativePs1Source,$nativeConsolePlatformsSource,$nativeSystemOverlaySource,$nativeGameInputSource,$nativeInputSource,$nativeDisplaySource,$nativeAudioSource,$nativePerformanceSource,$p3tSource)){",
    "installer required overlay source",
)
s = replace_once(
    s,
    "    $nativeConsolePlatformsSource,\n    $nativeGameBarSource,\n    $nativeGameInputSource,",
    "    $nativeConsolePlatformsSource,\n    $nativeSystemOverlaySource,\n    $nativeGameInputSource,",
    "installer compile overlay source",
)
write(p, s)

print("v0.26.0 controller semantics and installer source alignment completed.")
