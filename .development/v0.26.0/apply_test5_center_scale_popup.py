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


# ---------------------------------------------------------------------------
# Main shell/config: persistent Game Bar scale + ranged slider support + direct
# native popup command routing.
# ---------------------------------------------------------------------------
p = "HuymaierConsole.ps1"
s = read(p)

s = replace_once(
    s,
    "        QuickMenuPosition = 'Bottom'\n        ProviderInstallRoots = @()",
    "        QuickMenuPosition = 'Bottom'\n        GameBarScale = 100\n        ProviderInstallRoots = @()",
    "default GameBarScale",
)

s = replace_once(
    s,
    "'StorefrontInstallOverrides','QuickMenuPosition','ProviderInstallRoots'",
    "'StorefrontInstallOverrides','QuickMenuPosition','GameBarScale','ProviderInstallRoots'",
    "load GameBarScale",
)

s = replace_once(
    s,
    "    foreach ($collectionName in @('CustomGames','CustomApps','ImportedGames','RecentGames','RecentApps','StorefrontRoots','StorefrontInstallOverrides','ProviderInstallRoots','FavoriteGames')) {\n        $defaults.$collectionName = Convert-ToStableArray $defaults.$collectionName\n    }\n    return $defaults",
    "    foreach ($collectionName in @('CustomGames','CustomApps','ImportedGames','RecentGames','RecentApps','StorefrontRoots','StorefrontInstallOverrides','ProviderInstallRoots','FavoriteGames')) {\n        $defaults.$collectionName = Convert-ToStableArray $defaults.$collectionName\n    }\n    try{$defaults.GameBarScale=[math]::Max(70,[math]::Min(140,[int]$defaults.GameBarScale))}catch{$defaults.GameBarScale=100}\n    return $defaults",
    "clamp GameBarScale",
)

s = replace_once(
    s,
    "function New-SliderAction {\n    param([string]$Id,[string]$Title,[int]$Value,[string]$Description='Use Left/Right to adjust.')\n    New-Action $Id $Title $Description 'Slider' ([math]::Max(0,[math]::Min(100,$Value)))\n}",
    "function New-SliderAction {\n    param([string]$Id,[string]$Title,[int]$Value,[string]$Description='Use Left/Right to adjust.',[int]$Minimum=0,[int]$Maximum=100)\n    if($Maximum -lt $Minimum){$tmp=$Minimum;$Minimum=$Maximum;$Maximum=$tmp}\n    $clamped=[math]::Max($Minimum,[math]::Min($Maximum,$Value))\n    $action=New-Action $Id $Title $Description 'Slider' $clamped\n    $action|Add-Member -NotePropertyName Minimum -NotePropertyValue $Minimum -Force\n    $action|Add-Member -NotePropertyName Maximum -NotePropertyValue $Maximum -Force\n    return $action\n}",
    "ranged slider action",
)

s = replace_once(
    s,
    "$slider=New-Object System.Windows.Controls.Slider;$slider.Minimum=0;$slider.Maximum=100;$slider.Value=[int](Get-EntryProperty $action 'Value' 0);$slider.IsHitTestVisible=$false;$slider.Width=330;$slider.HorizontalAlignment='Left';$slider.Height=22;$slider.VerticalAlignment='Center';$sliderGrid.Children.Add($slider)|Out-Null",
    "$slider=New-Object System.Windows.Controls.Slider;$slider.Minimum=[int](Get-EntryProperty $action 'Minimum' 0);$slider.Maximum=[int](Get-EntryProperty $action 'Maximum' 100);$slider.Value=[int](Get-EntryProperty $action 'Value' 0);$slider.IsHitTestVisible=$false;$slider.Width=330;$slider.HorizontalAlignment='Left';$slider.Height=22;$slider.VerticalAlignment='Center';$sliderGrid.Children.Add($slider)|Out-Null",
    "ranged slider renderer",
)

s = replace_once(
    s,
    "        'audio-volume-slider' {\n            $value=[math]::Max(0,[math]::Min(100,(Get-AudioVolume)+$Delta));try{[HuymaierConsole.Native.AudioBridge]::SetMasterVolume($value/100.0)}catch{}\n        }\n        default{return $false}",
    "        'audio-volume-slider' {\n            $value=[math]::Max(0,[math]::Min(100,(Get-AudioVolume)+$Delta));try{[HuymaierConsole.Native.AudioBridge]::SetMasterVolume($value/100.0)}catch{}\n        }\n        'gamebar-scale-slider' {\n            $value=[math]::Max(70,[math]::Min(140,([int]$script:Config.GameBarScale)+$Delta));$script:Config.GameBarScale=$value;Save-Config\n            try{if('HuymaierConsole.NativeApp.HuymaierGameBarHost' -as [type]){[HuymaierConsole.NativeApp.HuymaierGameBarHost]::SetScalePercent($value)}}catch{}\n        }\n        default{return $false}",
    "Game Bar slider adjustment",
)

s = replace_once(
    s,
    "        'music-volume-slider' { Adjust-SelectedSlider 5 }\n        'music-theme' { Cycle-MusicTheme }",
    "        'music-volume-slider' { Adjust-SelectedSlider 5 }\n        'gamebar-scale-slider' { Adjust-SelectedSlider 5 }\n        'music-theme' { Cycle-MusicTheme }",
    "Game Bar slider invoke",
)

s = replace_once(
    s,
    "            if([bool]$nativeCommand.Active){\n                $family=[string]$nativeCommand.Family\n                if($family -eq 'Gamepad'){$family='Xbox'}\n                Set-ActiveInputFamily $family ([string]$nativeCommand.Name)\n                Hide-ConsoleCursor\n            }\n            $nativeMask=0;$nativeDirection=''",
    "            if([bool]$nativeCommand.Active){\n                $family=[string]$nativeCommand.Family\n                if($family -eq 'Gamepad'){$family='Xbox'}\n                Set-ActiveInputFamily $family ([string]$nativeCommand.Name)\n                Hide-ConsoleCursor\n            }\n            # A centered choice popup is a true modal input surface. Feed the\n            # normalized native command directly to it instead of converting it\n            # back through the legacy mask/focus path.\n            if((Get-Command Handle-HcChoicePopupNativeCommand -ErrorAction SilentlyContinue) -and (Handle-HcChoicePopupNativeCommand ([string]$nativeCommand.Command))){return}\n            $nativeMask=0;$nativeDirection=''",
    "direct native popup routing",
)

write(p, s)


# ---------------------------------------------------------------------------
# Shell redesign: expose Game Bar scale and consume native popup commands
# independently of WPF button focus.
# ---------------------------------------------------------------------------
p = "HuymaierShellRedesign.ps1"
s = read(p)

s = replace_once(
    s,
    "        try{$script:ControllerInputGuardUntil=[datetime]::MinValue;$script:Window.Activate()|Out-Null;$overlay.Focus()|Out-Null;[System.Windows.Input.Keyboard]::Focus($overlay)|Out-Null}catch{}",
    "        try{$script:ControllerInputGuardUntil=[datetime]::MinValue;$overlay.Focus()|Out-Null;[System.Windows.Input.Keyboard]::Focus($overlay)|Out-Null}catch{}",
    "do not reactivate window for popup",
)

anchor = "function Handle-HcChoicePopupController {param([int]$Mask,[string]$Direction);if(-not(Test-HcChoicePopupVisible)){return $false};$now=Get-Date;if($Direction){if($Direction -ne $script:LastDirection -or $now -ge $script:NextDirectionAt){if($Direction -in @('Up','Left')){Move-HcChoicePopup -1}elseif($Direction -in @('Down','Right')){Move-HcChoicePopup 1};$isNew=$Direction -ne $script:LastDirection;$script:LastDirection=$Direction;$script:NextDirectionAt=$now.AddMilliseconds($(if($isNew){330}else{120}))}}else{$script:LastDirection='';$script:NextDirectionAt=[datetime]::MinValue};if(Is-NewButtonPress $Mask 4){Invoke-HcChoicePopupSelected}elseif((Is-NewButtonPress $Mask 8)-or(Is-NewButtonPress $Mask 2)){Invoke-UiFeedback 'Back';Close-HcChoicePopup};$script:LastGamepadMask=$Mask;return $true}\n"
insert = anchor + "function Handle-HcChoicePopupNativeCommand {param([string]$Command);if(-not(Test-HcChoicePopupVisible)){return $false};switch($Command){'Up'{Move-HcChoicePopup -1}'Left'{Move-HcChoicePopup -1}'Down'{Move-HcChoicePopup 1}'Right'{Move-HcChoicePopup 1}'Confirm'{Invoke-HcChoicePopupSelected}'Back'{Invoke-UiFeedback 'Back';Close-HcChoicePopup}'Guide'{Invoke-UiFeedback 'Back';Close-HcChoicePopup;if(Get-Command Show-HcMainMenu -ErrorAction SilentlyContinue){Show-HcMainMenu}}};return $true}\n"
s = replace_once(s, anchor, insert, "native popup command handler")

s = replace_once(
    s,
    "                (New-Action 'quick-menu-position' \"Quick Access location: $($script:Config.QuickMenuPosition)\"),\n                (New-Action 'startup-toggle'",
    "                (New-Action 'quick-menu-position' \"Quick Access location: $($script:Config.QuickMenuPosition)\"),\n                (New-SliderAction 'gamebar-scale-slider' 'Game Bar scale' ([int]$script:Config.GameBarScale) 'Use Left/Right to adjust the centered overlay.' 70 140),\n                (New-Action 'startup-toggle'",
    "Game Bar scale setting",
)

write(p, s)


# ---------------------------------------------------------------------------
# External Game Bar module: pass the persisted scale into the native host.
# ---------------------------------------------------------------------------
p = "HuymaierGameBar.ps1"
s = read(p)
s = replace_once(
    s,
    "        [HuymaierConsole.NativeApp.HuymaierGameBarHost]::Initialize($script:Window)\n        Set-HcXboxGameBarSuppression",
    "        [HuymaierConsole.NativeApp.HuymaierGameBarHost]::Initialize($script:Window)\n        [HuymaierConsole.NativeApp.HuymaierGameBarHost]::SetScalePercent([int](Get-EntryProperty $script:Config 'GameBarScale' 100))\n        Set-HcXboxGameBarSuppression",
    "initialize Game Bar scale",
)
write(p, s)


# ---------------------------------------------------------------------------
# Native Game Bar: true screen-center placement, DPI-correct monitor dimensions,
# and live scale updates. 100% = 70% monitor width x 24% monitor height.
# ---------------------------------------------------------------------------
p = "Native/HuymaierConsole.SystemOverlay.cs"
s = read(p)

s = replace_once(
    s,
    "        private static Window consoleWindow;\n        private static HuymaierGameBarWindow gameBar;\n        public static bool IsVisible",
    "        private static Window consoleWindow;\n        private static HuymaierGameBarWindow gameBar;\n        private static int scalePercent = 100;\n        public static bool IsVisible",
    "Game Bar host scale state",
)

s = replace_once(
    s,
    "        public static void Initialize(Window mainConsoleWindow) { consoleWindow = mainConsoleWindow; }\n        public static void Show() { if (consoleWindow == null) return; if (gameBar == null) gameBar = new HuymaierGameBarWindow(consoleWindow); gameBar.ShowForForegroundWindow(); }",
    "        public static void Initialize(Window mainConsoleWindow) { consoleWindow = mainConsoleWindow; }\n        public static void SetScalePercent(int value) { scalePercent = Math.Max(70, Math.Min(140, value)); if (gameBar != null) gameBar.SetScalePercent(scalePercent); }\n        public static void Show() { if (consoleWindow == null) return; if (gameBar == null) gameBar = new HuymaierGameBarWindow(consoleWindow); gameBar.SetScalePercent(scalePercent); gameBar.ShowForForegroundWindow(); }",
    "Game Bar host setter",
)

s = replace_once(
    s,
    "        private bool closeConfirmation;\n        private string lastStatus;",
    "        private bool closeConfirmation;\n        private string lastStatus;\n        private int scalePercent;",
    "Game Bar window scale field",
)

s = replace_once(
    s,
    "            audioEndpoints = new AudioEndpointInfo[0];\n            lastStatus = String.Empty;",
    "            audioEndpoints = new AudioEndpointInfo[0];\n            lastStatus = String.Empty;\n            scalePercent = 100;",
    "Game Bar default scale",
)

old_position = '''        private void PositionOnTargetMonitor(IntPtr target)
        {
            try
            {
                Forms.Screen screen = target != IntPtr.Zero ? Forms.Screen.FromHandle(target) : Forms.Screen.PrimaryScreen;
                Drawing.Rectangle bounds = screen.Bounds;
                double width = Math.Max(860.0, Math.Min(bounds.Width * 0.70, 1500.0));
                double height = Math.Max(235.0, Math.Min(bounds.Height * 0.24, 310.0));
                Left = bounds.Left + ((bounds.Width - width) / 2.0);
                // Lower third, Xbox/Steam-style: visible without covering the game center.
                Top = bounds.Top + Math.Min(bounds.Height - height - 28.0, bounds.Height * 0.66);
                Width = width;
                Height = height;
            }
            catch
            {
                double width = Math.Max(860.0, SystemParameters.PrimaryScreenWidth * 0.70);
                double height = Math.Max(235.0, SystemParameters.PrimaryScreenHeight * 0.24);
                Width = width; Height = height;
                Left = SystemParameters.VirtualScreenLeft + ((SystemParameters.PrimaryScreenWidth - width) / 2.0);
                Top = SystemParameters.VirtualScreenTop + (SystemParameters.PrimaryScreenHeight * 0.66);
            }
        }'''
new_position = '''        internal void SetScalePercent(int value)
        {
            scalePercent = Math.Max(70, Math.Min(140, value));
            if (IsVisible) PositionOnTargetMonitor(targetWindow);
        }

        private Rect GetLogicalMonitorBounds(Forms.Screen screen)
        {
            Drawing.Rectangle bounds = screen == null ? Forms.Screen.PrimaryScreen.Bounds : screen.Bounds;
            try
            {
                IntPtr handle = new WindowInteropHelper(this).EnsureHandle();
                HwndSource source = HwndSource.FromHwnd(handle);
                if (source != null && source.CompositionTarget != null)
                {
                    Matrix fromDevice = source.CompositionTarget.TransformFromDevice;
                    Point topLeft = fromDevice.Transform(new Point(bounds.Left, bounds.Top));
                    Point bottomRight = fromDevice.Transform(new Point(bounds.Right, bounds.Bottom));
                    return new Rect(topLeft, bottomRight);
                }
            }
            catch { }
            return new Rect(bounds.Left, bounds.Top, bounds.Width, bounds.Height);
        }

        private void PositionOnTargetMonitor(IntPtr target)
        {
            try
            {
                Forms.Screen screen = target != IntPtr.Zero ? Forms.Screen.FromHandle(target) : Forms.Screen.PrimaryScreen;
                Rect bounds = GetLogicalMonitorBounds(screen);
                double factor = scalePercent / 100.0;
                double width = Math.Max(760.0, Math.Min(bounds.Width * 0.92, bounds.Width * 0.70 * factor));
                double height = Math.Max(220.0, Math.Min(bounds.Height * 0.50, bounds.Height * 0.24 * factor));
                Width = width;
                Height = height;
                Left = bounds.Left + ((bounds.Width - width) / 2.0);
                Top = bounds.Top + ((bounds.Height - height) / 2.0);
            }
            catch
            {
                double factor = scalePercent / 100.0;
                double width = Math.Max(760.0, Math.Min(SystemParameters.PrimaryScreenWidth * 0.92, SystemParameters.PrimaryScreenWidth * 0.70 * factor));
                double height = Math.Max(220.0, Math.Min(SystemParameters.PrimaryScreenHeight * 0.50, SystemParameters.PrimaryScreenHeight * 0.24 * factor));
                Width = width; Height = height;
                Left = SystemParameters.VirtualScreenLeft + ((SystemParameters.PrimaryScreenWidth - width) / 2.0);
                Top = SystemParameters.VirtualScreenTop + ((SystemParameters.PrimaryScreenHeight - height) / 2.0);
            }
        }'''
s = replace_once(s, old_position, new_position, "DPI-correct centered Game Bar positioning")

write(p, s)

print("v0.26.0 test-5 center/DPI/scale/modal-popup changes applied.")
