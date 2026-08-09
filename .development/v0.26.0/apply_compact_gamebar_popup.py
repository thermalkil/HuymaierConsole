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
# Huymaier Game Bar: compact lower-center overlay, constrained horizontal rails,
# and preserve fullscreen/maximized state when switching back to a game/app.
# ---------------------------------------------------------------------------
p = "Native/HuymaierConsole.SystemOverlay.cs"
s = read(p)

s = replace_once(
    s,
    '[DllImport("user32.dll")] internal static extern bool ShowWindow(IntPtr hWnd, int command);\n        [DllImport("user32.dll")] internal static extern bool PostMessage',
    '[DllImport("user32.dll")] internal static extern bool ShowWindow(IntPtr hWnd, int command);\n        [DllImport("user32.dll")] private static extern bool IsIconic(IntPtr hWnd);\n        [DllImport("user32.dll")] internal static extern bool PostMessage',
    "IsIconic import",
)

s = replace_once(
    s,
    '            try { ShowWindow(hWnd, SW_RESTORE); } catch { }\n            try { SetForegroundWindow(hWnd); } catch { }',
    '            // Never restore a maximized/fullscreen game to its normal windowed size.\n            // SW_RESTORE is needed only for an actually minimized task.\n            try { if (IsIconic(hWnd)) ShowWindow(hWnd, SW_RESTORE); } catch { }\n            try { SetForegroundWindow(hWnd); } catch { }',
    "preserve target window state",
)

s = replace_once(
    s,
    '            root = new Grid();\n            root.Background = new SolidColorBrush(Color.FromArgb(180, 0, 0, 0));\n            Border card = new Border();\n            card.Width = 1180;\n            card.MaxHeight = 790;\n            card.HorizontalAlignment = HorizontalAlignment.Center;\n            card.VerticalAlignment = VerticalAlignment.Center;\n            card.Background = new SolidColorBrush(Color.FromArgb(248, 8, 12, 18));\n            card.BorderBrush = new SolidColorBrush(Color.FromRgb(69, 81, 99));\n            card.BorderThickness = new Thickness(1.5);\n            card.CornerRadius = new CornerRadius(22);\n            card.Padding = new Thickness(32, 25, 32, 23);',
    '            root = new Grid();\n            // This is a compact Game Bar, not a fullscreen takeover. The window itself\n            // is positioned over only the lower-center portion of the target monitor.\n            root.Background = Brushes.Transparent;\n            Border card = new Border();\n            card.HorizontalAlignment = HorizontalAlignment.Stretch;\n            card.VerticalAlignment = VerticalAlignment.Stretch;\n            card.Background = new SolidColorBrush(Color.FromArgb(246, 8, 12, 18));\n            card.BorderBrush = new SolidColorBrush(Color.FromRgb(69, 81, 99));\n            card.BorderThickness = new Thickness(1.5);\n            card.CornerRadius = new CornerRadius(20);\n            card.Padding = new Thickness(22, 16, 22, 14);',
    "compact Game Bar card",
)

s = replace_once(
    s,
    '            TextBlock brand = new TextBlock(); brand.Text = "HUYMAIER GAME BAR"; brand.FontSize = 24; brand.FontWeight = FontWeights.Bold; brand.Foreground = new SolidColorBrush(Color.FromRgb(231, 196, 94)); header.Children.Add(brand);\n            contextText = new TextBlock(); contextText.Margin = new Thickness(18, 7, 0, 0); contextText.FontSize = 13;',
    '            TextBlock brand = new TextBlock(); brand.Text = "HUYMAIER GAME BAR"; brand.FontSize = 18; brand.FontWeight = FontWeights.Bold; brand.Foreground = new SolidColorBrush(Color.FromRgb(231, 196, 94)); header.Children.Add(brand);\n            contextText = new TextBlock(); contextText.Margin = new Thickness(14, 3, 0, 0); contextText.FontSize = 11;',
    "compact Game Bar header",
)

s = replace_once(
    s,
    '            tabsText = new TextBlock(); tabsText.Margin = new Thickness(0, 15, 0, 0); tabsText.FontSize = 12; tabsText.FontWeight = FontWeights.SemiBold;',
    '            tabsText = new TextBlock(); tabsText.Margin = new Thickness(0, 8, 0, 0); tabsText.FontSize = 10; tabsText.FontWeight = FontWeights.SemiBold;',
    "compact tabs",
)

s = replace_once(
    s,
    '            pageText = new TextBlock(); pageText.Margin = new Thickness(0, 10, 0, 16); pageText.FontSize = 31; pageText.FontWeight = FontWeights.SemiBold;',
    '            pageText = new TextBlock(); pageText.Margin = new Thickness(0, 5, 0, 7); pageText.FontSize = 20; pageText.FontWeight = FontWeights.SemiBold;',
    "compact page heading",
)

s = replace_once(
    s,
    '            statusText = new TextBlock(); statusText.Margin = new Thickness(0, 12, 0, 0); statusText.FontSize = 12;',
    '            statusText = new TextBlock(); statusText.Margin = new Thickness(0, 5, 0, 0); statusText.FontSize = 10;',
    "compact status",
)
s = replace_once(
    s,
    '            footerText = new TextBlock(); footerText.Margin = new Thickness(0, 12, 0, 0); footerText.FontSize = 13;',
    '            footerText = new TextBlock(); footerText.Margin = new Thickness(0, 5, 0, 0); footerText.FontSize = 10;',
    "compact footer",
)

s = replace_once(
    s,
    '        private void PositionOnTargetMonitor(IntPtr target)\n        {\n            try { Forms.Screen screen = target != IntPtr.Zero ? Forms.Screen.FromHandle(target) : Forms.Screen.PrimaryScreen; Drawing.Rectangle bounds = screen.Bounds; Left = bounds.Left; Top = bounds.Top; Width = bounds.Width; Height = bounds.Height; }\n            catch { Left = SystemParameters.VirtualScreenLeft; Top = SystemParameters.VirtualScreenTop; Width = SystemParameters.PrimaryScreenWidth; Height = SystemParameters.PrimaryScreenHeight; }\n        }',
    '        private void PositionOnTargetMonitor(IntPtr target)\n        {\n            try\n            {\n                Forms.Screen screen = target != IntPtr.Zero ? Forms.Screen.FromHandle(target) : Forms.Screen.PrimaryScreen;\n                Drawing.Rectangle bounds = screen.Bounds;\n                double width = Math.Max(860.0, Math.Min(bounds.Width * 0.70, 1500.0));\n                double height = Math.Max(235.0, Math.Min(bounds.Height * 0.24, 310.0));\n                Left = bounds.Left + ((bounds.Width - width) / 2.0);\n                // Lower third, Xbox/Steam-style: visible without covering the game center.\n                Top = bounds.Top + Math.Min(bounds.Height - height - 28.0, bounds.Height * 0.66);\n                Width = width;\n                Height = height;\n            }\n            catch\n            {\n                double width = Math.Max(860.0, SystemParameters.PrimaryScreenWidth * 0.70);\n                double height = Math.Max(235.0, SystemParameters.PrimaryScreenHeight * 0.24);\n                Width = width; Height = height;\n                Left = SystemParameters.VirtualScreenLeft + ((SystemParameters.PrimaryScreenWidth - width) / 2.0);\n                Top = SystemParameters.VirtualScreenTop + (SystemParameters.PrimaryScreenHeight * 0.66);\n            }\n        }',
    "compact lower-third positioning",
)

s = replace_once(
    s,
    '            itemPanel.Children.Clear(); itemCards.Clear();\n            itemPanel.Orientation = page == PageSwitcher ? Orientation.Horizontal : Orientation.Vertical;\n            scroller.HorizontalScrollBarVisibility = page == PageSwitcher ? ScrollBarVisibility.Hidden : ScrollBarVisibility.Disabled;\n            scroller.VerticalScrollBarVisibility = page == PageSwitcher ? ScrollBarVisibility.Disabled : ScrollBarVisibility.Hidden;',
    '            itemPanel.Children.Clear(); itemCards.Clear();\n            bool horizontalRail = page == PageHome || page == PageSwitcher;\n            itemPanel.Orientation = horizontalRail ? Orientation.Horizontal : Orientation.Vertical;\n            scroller.HorizontalScrollBarVisibility = horizontalRail ? ScrollBarVisibility.Hidden : ScrollBarVisibility.Disabled;\n            scroller.VerticalScrollBarVisibility = horizontalRail ? ScrollBarVisibility.Disabled : ScrollBarVisibility.Hidden;',
    "horizontal Home/Switcher rails",
)

s = replace_once(
    s,
    '        private void AddStandardItem(string title, string detail, bool selectable)\n        {\n            Border border = new Border(); border.Height = 78; border.Margin = new Thickness(0, 0, 0, 9); border.Padding = new Thickness(18, 10, 18, 10); border.CornerRadius = new CornerRadius(13); border.BorderThickness = new Thickness(1); border.Tag = selectable;\n            StackPanel stack = new StackPanel();\n            TextBlock titleText = new TextBlock(); titleText.Text = title; titleText.FontSize = 19; titleText.FontWeight = FontWeights.SemiBold;\n            TextBlock detailText = new TextBlock(); detailText.Text = detail; detailText.FontSize = 12; detailText.Foreground = new SolidColorBrush(Color.FromRgb(153, 168, 190)); detailText.Margin = new Thickness(0, 5, 0, 0); detailText.TextTrimming = TextTrimming.CharacterEllipsis;\n            stack.Children.Add(titleText); stack.Children.Add(detailText); border.Child = stack; itemPanel.Children.Add(border); itemCards.Add(border);\n        }',
    '        private void AddStandardItem(string title, string detail, bool selectable)\n        {\n            bool compactRail = page == PageHome;\n            Border border = new Border();\n            border.Height = compactRail ? 86 : 56;\n            border.Width = compactRail ? 158 : Double.NaN;\n            border.Margin = compactRail ? new Thickness(0, 0, 9, 0) : new Thickness(0, 0, 0, 6);\n            border.Padding = compactRail ? new Thickness(12, 9, 12, 8) : new Thickness(14, 7, 14, 7);\n            border.CornerRadius = new CornerRadius(11); border.BorderThickness = new Thickness(1); border.Tag = selectable;\n            StackPanel stack = new StackPanel();\n            TextBlock titleText = new TextBlock(); titleText.Text = title; titleText.FontSize = compactRail ? 14 : 15; titleText.FontWeight = FontWeights.SemiBold; titleText.TextWrapping = TextWrapping.Wrap;\n            TextBlock detailText = new TextBlock(); detailText.Text = detail; detailText.FontSize = compactRail ? 9 : 10; detailText.Foreground = new SolidColorBrush(Color.FromRgb(153, 168, 190)); detailText.Margin = new Thickness(0, 3, 0, 0); detailText.TextTrimming = TextTrimming.CharacterEllipsis; detailText.MaxHeight = compactRail ? 28 : 20;\n            stack.Children.Add(titleText); stack.Children.Add(detailText); border.Child = stack; itemPanel.Children.Add(border); itemCards.Add(border);\n        }',
    "compact standard items",
)

s = replace_once(
    s,
    '        private void AddTaskItem(SystemWindowEntry entry)\n        {\n            Border border = new Border(); border.Width = 330; border.Height = 300; border.Margin = new Thickness(0, 0, 14, 0); border.Padding = new Thickness(12); border.CornerRadius = new CornerRadius(14); border.BorderThickness = new Thickness(1); border.Tag = true;\n            Grid grid = new Grid(); grid.RowDefinitions.Add(new RowDefinition { Height = new GridLength(190) }); grid.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto }); grid.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });\n            Border previewTarget = new Border(); previewTarget.Background = new SolidColorBrush(Color.FromRgb(3, 6, 10)); previewTarget.CornerRadius = new CornerRadius(9); previewTarget.ClipToBounds = true; Grid.SetRow(previewTarget, 0); grid.Children.Add(previewTarget);\n            TextBlock title = new TextBlock(); title.Text = entry.Title; title.FontSize = 17; title.FontWeight = FontWeights.SemiBold; title.Margin = new Thickness(3, 10, 3, 0); title.TextTrimming = TextTrimming.CharacterEllipsis; Grid.SetRow(title, 1); grid.Children.Add(title);\n            TextBlock process = new TextBlock(); process.Text = String.IsNullOrWhiteSpace(entry.ProcessName) ? "Desktop app" : entry.ProcessName; process.FontSize = 11; process.Foreground = new SolidColorBrush(Color.FromRgb(153, 168, 190)); process.Margin = new Thickness(3, 5, 3, 0); Grid.SetRow(process, 2); grid.Children.Add(process);\n            border.Child = grid; itemPanel.Children.Add(border); itemCards.Add(border); taskPreviewTargets.Add(previewTarget);\n        }',
    '        private void AddTaskItem(SystemWindowEntry entry)\n        {\n            // Preview cards must stay fully inside the compact bar; the horizontal\n            // ScrollViewer handles additional tasks instead of letting cards overflow.\n            Border border = new Border(); border.Width = 214; border.Height = 112; border.Margin = new Thickness(0, 0, 9, 0); border.Padding = new Thickness(7); border.CornerRadius = new CornerRadius(11); border.BorderThickness = new Thickness(1); border.Tag = true;\n            Grid grid = new Grid(); grid.RowDefinitions.Add(new RowDefinition { Height = new GridLength(66) }); grid.RowDefinitions.Add(new RowDefinition { Height = new GridLength(21) }); grid.RowDefinitions.Add(new RowDefinition { Height = new GridLength(14) });\n            Border previewTarget = new Border(); previewTarget.Background = new SolidColorBrush(Color.FromRgb(3, 6, 10)); previewTarget.CornerRadius = new CornerRadius(7); previewTarget.ClipToBounds = true; Grid.SetRow(previewTarget, 0); grid.Children.Add(previewTarget);\n            TextBlock title = new TextBlock(); title.Text = entry.Title; title.FontSize = 11; title.FontWeight = FontWeights.SemiBold; title.Margin = new Thickness(2, 3, 2, 0); title.TextTrimming = TextTrimming.CharacterEllipsis; Grid.SetRow(title, 1); grid.Children.Add(title);\n            TextBlock process = new TextBlock(); process.Text = String.IsNullOrWhiteSpace(entry.ProcessName) ? "Desktop app" : entry.ProcessName; process.FontSize = 9; process.Foreground = new SolidColorBrush(Color.FromRgb(153, 168, 190)); process.Margin = new Thickness(2, 1, 2, 0); process.TextTrimming = TextTrimming.CharacterEllipsis; Grid.SetRow(process, 2); grid.Children.Add(process);\n            border.Child = grid; itemPanel.Children.Add(border); itemCards.Add(border); taskPreviewTargets.Add(previewTarget);\n        }',
    "constrained task preview cards",
)

write(p, s)

# ---------------------------------------------------------------------------
# Choice popup: make focus ownership explicit and keep WPF buttons from stealing
# directional focus away from the popup's own controller/keyboard selection.
# ---------------------------------------------------------------------------
p = "HuymaierShellRedesign.ps1"
s = read(p)

s = replace_once(
    s,
    "$script:HcChoiceSelected=0\n$script:HcChoiceSetting=''",
    "$script:HcChoiceSelected=0\n$script:HcChoiceSetting=''\n$script:HcChoicePreviousFocus=$null",
    "choice popup focus state",
)

s = replace_once(
    s,
    "$script:HcChoiceOverlay=$null;$script:HcChoiceButtons=@();$script:HcChoiceOptions=@();$script:HcChoiceSelected=0;$script:HcChoiceSetting='';Set-HcShellBlur $false;Update-Footer",
    "$script:HcChoiceOverlay=$null;$script:HcChoiceButtons=@();$script:HcChoiceOptions=@();$script:HcChoiceSelected=0;$script:HcChoiceSetting='';Set-HcShellBlur $false;Update-Footer;try{if($null -ne $script:HcChoicePreviousFocus){[System.Windows.Input.Keyboard]::Focus($script:HcChoicePreviousFocus)|Out-Null}}catch{};$script:HcChoicePreviousFocus=$null",
    "restore choice popup focus",
)

s = replace_once(
    s,
    "$overlay=New-Object System.Windows.Controls.Grid;$overlay.Background='#96000000';$overlay.IsHitTestVisible=$true;$overlay.Focusable=$true;[System.Windows.Controls.Panel]::SetZIndex($overlay,9000)",
    "$script:HcChoicePreviousFocus=[System.Windows.Input.Keyboard]::FocusedElement;$overlay=New-Object System.Windows.Controls.Grid;$overlay.Background='#96000000';$overlay.IsHitTestVisible=$true;$overlay.Focusable=$true;[System.Windows.Input.KeyboardNavigation]::SetDirectionalNavigation($overlay,[System.Windows.Input.KeyboardNavigationMode]::None);[System.Windows.Input.KeyboardNavigation]::SetTabNavigation($overlay,[System.Windows.Input.KeyboardNavigationMode]::None);[System.Windows.Controls.Panel]::SetZIndex($overlay,9000)",
    "choice popup focus ownership",
)

s = replace_once(
    s,
    "$b.Height=58;$b.Margin='0,0,0,8';$b.Padding='18,8';$b.HorizontalContentAlignment='Left';$b.FontSize=18;$b.Cursor='Hand';$b.Add_Click",
    "$b.Height=58;$b.Margin='0,0,0,8';$b.Padding='18,8';$b.HorizontalContentAlignment='Left';$b.FontSize=18;$b.Cursor='Hand';$b.Focusable=$false;$b.IsTabStop=$false;$b.Add_Click",
    "choice buttons do not steal focus",
)

s = replace_once(
    s,
    "$script:RootGrid.Children.Add($overlay)|Out-Null;$script:HcChoiceOverlay=$overlay;Set-HcShellBlur $true;Update-HcChoicePopupVisuals;Update-Footer\n        try{$overlay.Focus()|Out-Null}catch{}",
    "$script:RootGrid.Children.Add($overlay)|Out-Null;$script:HcChoiceOverlay=$overlay;Set-HcShellBlur $true;Update-HcChoicePopupVisuals;Update-Footer\n        # Clear the activation edge that opened the popup, then make the popup the\n        # explicit focus scope. This prevents the underlying Settings page from\n        # consuming D-pad/A/B while the chooser is visible.\n        $script:LastGamepadMask=0;$script:LastDirection='';$script:NextDirectionAt=[datetime]::MinValue\n        try{$script:ControllerInputGuardUntil=[datetime]::MinValue;$script:Window.Activate()|Out-Null;$overlay.Focus()|Out-Null;[System.Windows.Input.Keyboard]::Focus($overlay)|Out-Null}catch{}",
    "choice popup activation state",
)

write(p, s)

print("v0.26.0 compact Game Bar, task-switcher bounds, fullscreen-preserving activation, and popup focus fixes applied.")
