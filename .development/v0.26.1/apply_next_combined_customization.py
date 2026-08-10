from pathlib import Path


def read(path):
    return Path(path).read_text(encoding='utf-8-sig')


def write(path, text, bom=False):
    Path(path).write_text(text, encoding='utf-8-sig' if bom else 'utf-8', newline='\n')


def replace_once(text, old, new, label):
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{label}: expected exactly one match, found {count}')
    return text.replace(old, new, 1)


# Carry the confirmed Game Bar z-order/modal-input and native folder-picker fix
# into this combined build even if its earlier queued transformer has not run.
if 'HuymaierGameBarHost.BlocksNativeNavigation' not in read('Native/HuymaierConsole.NativeApp.cs'):
    rc13 = Path('.development/v0.26.1/apply_rc13_overlay_modal_filepicker.py')
    namespace = {'__name__': '__main__', '__file__': str(rc13)}
    exec(compile(rc13.read_text(encoding='utf-8'), str(rc13), 'exec'), namespace, namespace)

# ---------------------------------------------------------------------------
# Fix and integrate the customization module.
# ---------------------------------------------------------------------------
p = 'HuymaierCustomization.ps1'
t = read(p)
t = t.replace(
    "if([string]::IsNullOrWhiteSpace([string]$script:Config.ConsoleName){$script:Config.ConsoleName='Huymaier Console'}",
    "if([string]::IsNullOrWhiteSpace([string]$script:Config.ConsoleName)){$script:Config.ConsoleName='Huymaier Console'}"
)
write(p, t, bom=True)

p = 'HuymaierConsole.ps1'
t = read(p)

# Module path and load order: customization loads last so it can decorate/wrap
# the shared shell, emulator, browser, and Game Bar surfaces.
path_anchor = "$script:GameBarModulePath = Join-Path $script:BaseDir 'HuymaierGameBar.ps1'\n"
if '$script:CustomizationModulePath' not in t:
    t = replace_once(t, path_anchor, path_anchor + "$script:CustomizationModulePath = Join-Path $script:BaseDir 'HuymaierCustomization.ps1'\n", 'customization module path')

load_anchor = '''if (Test-Path -LiteralPath $script:GameBarModulePath) {\n    try { . $script:GameBarModulePath }\n    catch { Write-Log "Huymaier Game Bar module load failed: $($_.Exception.Message)" 'ERROR' }\n}\n\n'''
load_block = load_anchor + '''if (Test-Path -LiteralPath $script:CustomizationModulePath) {\n    try { . $script:CustomizationModulePath }\n    catch { Write-Log "Customization module load failed: $($_.Exception.Message)" 'ERROR' }\n}\n\n'''
if 'Customization module load failed' not in t:
    t = replace_once(t, load_anchor, load_block, 'customization module load')

# Persist new settings across restart instead of merely adding them at runtime.
default_anchor = '''        MusicEnabled = $true\n        MusicVolume = 30\n        DynamicBackground = $true\n        UiSoundsEnabled = $true\n'''
default_block = '''        MusicEnabled = $true\n        MusicVolume = 30\n        UiSoundVolume = 62\n        DynamicBackground = $true\n        ConsoleName = 'Huymaier Console'\n        ShellBaseColor = '#09111E'\n        AccentColor = '#E7C45E'\n        AccentHighlightColor = '#FFF0A0'\n        DynamicThemePreset = 'Huymaier'\n        DynamicPrimaryColor = '#D6B64F'\n        DynamicSecondaryColor = '#4474C2'\n        DynamicTertiaryColor = '#315F9D'\n        UiSoundsEnabled = $true\n'''
if 'UiSoundVolume = 62' not in t:
    t = replace_once(t, default_anchor, default_block, 'customization config defaults')

load_names_old = "'CustomGames','CustomApps','MusicEnabled','MusicVolume','DynamicBackground','UiSoundsEnabled','HapticsEnabled'"
load_names_new = "'CustomGames','CustomApps','MusicEnabled','MusicVolume','UiSoundVolume','DynamicBackground','ConsoleName','ShellBaseColor','AccentColor','AccentHighlightColor','DynamicThemePreset','DynamicPrimaryColor','DynamicSecondaryColor','DynamicTertiaryColor','UiSoundsEnabled','HapticsEnabled'"
if load_names_old in t:
    t = t.replace(load_names_old, load_names_new, 1)

norm_anchor = '''    try{$defaults.GameBarScale=[math]::Max(70,[math]::Min(140,[int]$defaults.GameBarScale))}catch{$defaults.GameBarScale=100}\n    return $defaults\n}\n'''
norm_block = '''    try{$defaults.GameBarScale=[math]::Max(70,[math]::Min(140,[int]$defaults.GameBarScale))}catch{$defaults.GameBarScale=100}\n    try{$defaults.UiSoundVolume=[math]::Max(0,[math]::Min(100,[int]$defaults.UiSoundVolume))}catch{$defaults.UiSoundVolume=62}\n    if([string]::IsNullOrWhiteSpace([string]$defaults.ConsoleName)){$defaults.ConsoleName='Huymaier Console'}\n    return $defaults\n}\n'''
if 'try{$defaults.UiSoundVolume=' not in t:
    t = replace_once(t, norm_anchor, norm_block, 'customization config normalization')

# Remove native WPF focus rectangles from the shared styled buttons. Huymaier's
# own border is the only focus treatment. This fixes the dashed artifacts seen on
# Power and prevents two focus visuals from stacking.
for style_marker in ('<Style x:Key="NavButtonStyle" TargetType="Button">', '<Style x:Key="ActionButtonStyle" TargetType="Button">'):
    idx = t.find(style_marker)
    if idx < 0:
        raise SystemExit('shared button style not found: ' + style_marker)
    end = t.find('</Style>', idx)
    block = t[idx:end]
    if 'FocusVisualStyle' not in block:
        insert_at = t.find('\n', idx) + 1
        t = t[:insert_at] + '            <Setter Property="FocusVisualStyle" Value="{x:Null}"/>\n' + t[insert_at:]

# Name dynamic-theme and visible branding elements so the customization module
# can recolor/rename them without reconstructing the visual tree.
replacements = [
    ('<Rectangle Width="1920" Height="1080">', '<Rectangle x:Name="DynamicBase" Width="1920" Height="1080">', 'dynamic base'),
    ('<Ellipse Width="960" Height="960" Canvas.Left="-350" Canvas.Top="-420">', '<Ellipse x:Name="DynamicGlowOne" Width="960" Height="960" Canvas.Left="-350" Canvas.Top="-420">', 'dynamic glow one'),
    ('<Ellipse Width="1180" Height="1180" Canvas.Left="1100" Canvas.Top="280">', '<Ellipse x:Name="DynamicGlowTwo" Width="1180" Height="1180" Canvas.Left="1100" Canvas.Top="280">', 'dynamic glow two'),
    ('<Path Data="M-180,870 C300,350 760,1040 2100,280" StrokeThickness="115" Opacity="0.22">', '<Path x:Name="DynamicRibbonOne" Data="M-180,870 C300,350 760,1040 2100,280" StrokeThickness="115" Opacity="0.22">', 'dynamic ribbon one'),
    ('<Path Data="M-220,260 C420,850 1120,60 2140,700" StrokeThickness="92" Opacity="0.18">', '<Path x:Name="DynamicRibbonTwo" Data="M-220,260 C420,850 1120,60 2140,700" StrokeThickness="92" Opacity="0.18">', 'dynamic ribbon two'),
    ('<Path Data="M120,1180 C420,520 930,390 1780,-120" Stroke="#38597DB8" StrokeThickness="38" Opacity="0.22">', '<Path x:Name="DynamicRibbonThree" Data="M120,1180 C420,520 930,390 1780,-120" Stroke="#38597DB8" StrokeThickness="38" Opacity="0.22">', 'dynamic ribbon three'),
    ('<Border Width="48" Height="48" CornerRadius="24" BorderBrush="#E7C45E" BorderThickness="2" Background="#0D1726">', '<Border x:Name="ConsoleBrandBadge" Width="48" Height="48" CornerRadius="24" BorderBrush="#E7C45E" BorderThickness="2" Background="#0D1726">', 'console brand badge'),
    ('<TextBlock Text="H" FontSize="25" FontWeight="Bold" Foreground="#E7C45E" HorizontalAlignment="Center" VerticalAlignment="Center"/>', '<TextBlock x:Name="ConsoleBrandGlyph" Text="H" FontSize="25" FontWeight="Bold" Foreground="#E7C45E" HorizontalAlignment="Center" VerticalAlignment="Center"/>', 'console brand glyph'),
    ('<TextBlock Text="HUYMAIER CONSOLE" FontSize="25" FontWeight="Bold"/>', '<TextBlock x:Name="ConsoleBrandText" Text="HUYMAIER CONSOLE" FontSize="25" FontWeight="Bold" TextTrimming="CharacterEllipsis"/>', 'console brand text'),
    ('<TextBlock Grid.Column="1" VerticalAlignment="Center" Text="HUYMAIER FSE  v0.26.0" FontSize="12" Foreground="#77869C"/>', '<TextBlock x:Name="ProductFooterText" Grid.Column="1" VerticalAlignment="Center" Text="HUYMAIER CONSOLE FSE" FontSize="12" Foreground="#77869C"/>', 'product footer text'),
]
for old, new, label in replacements:
    if new not in t:
        t = replace_once(t, old, new, label)

var_old = "'ActionScrollViewer','RootGrid','ShellContent','MainMenuOverlay'"
var_new = "'ActionScrollViewer','RootGrid','ConsoleBrandBadge','ConsoleBrandGlyph','ConsoleBrandText','ProductFooterText','DynamicBase','DynamicGlowOne','DynamicGlowTwo','DynamicRibbonOne','DynamicRibbonTwo','DynamicRibbonThree','ShellContent','MainMenuOverlay'"
if var_old in t:
    t = t.replace(var_old, var_new, 1)

# Apply branding/palette only after the XAML names and media players exist.
startup_anchor = '''    Initialize-UiFeedback\n    Initialize-BackgroundMusic\n'''
startup_block = '''    Initialize-UiFeedback\n    if(Get-Command Apply-HcCustomizationVisuals -ErrorAction SilentlyContinue){Apply-HcCustomizationVisuals}\n    Initialize-BackgroundMusic\n'''
if 'if(Get-Command Apply-HcCustomizationVisuals' not in t:
    t = replace_once(t, startup_anchor, startup_block, 'customization visual startup')

write(p, t, bom=True)

# ---------------------------------------------------------------------------
# Game Bar branding and stronger foreground activation. RC13 already makes the
# window HWND_TOPMOST; attach to the foreground thread for the activation call so
# the overlay reliably receives focus rather than merely appearing above a game.
# ---------------------------------------------------------------------------
p = 'Native/HuymaierConsole.SystemOverlay.cs'
t = read(p)

host_fields = '''        private static int scalePercent = 100;\n        [ThreadStatic] private static bool navigationPollBypass;\n'''
host_fields_new = '''        private static int scalePercent = 100;\n        private static string displayName = "Huymaier Console";\n        private static string accentColor = "#E7C45E";\n        [ThreadStatic] private static bool navigationPollBypass;\n'''
if 'private static string displayName' not in t:
    t = replace_once(t, host_fields, host_fields_new, 'Game Bar branding state')

scale_line = '''        public static void SetScalePercent(int value) { scalePercent = Math.Max(70, Math.Min(140, value)); if (gameBar != null) gameBar.SetScalePercent(scalePercent); }\n'''
brand_methods = scale_line + '''        public static void SetDisplayName(string value) { displayName = String.IsNullOrWhiteSpace(value) ? "Huymaier Console" : value.Trim(); if (gameBar != null) gameBar.SetBrand(displayName, accentColor); }\n        public static void SetAccentColor(string value) { accentColor = String.IsNullOrWhiteSpace(value) ? "#E7C45E" : value.Trim(); if (gameBar != null) gameBar.SetBrand(displayName, accentColor); }\n'''
if 'public static void SetDisplayName' not in t:
    t = replace_once(t, scale_line, brand_methods, 'Game Bar branding setters')

show_old = '''        public static void Show() { if (consoleWindow == null) return; if (gameBar == null) gameBar = new HuymaierGameBarWindow(consoleWindow); gameBar.SetScalePercent(scalePercent); gameBar.ShowForForegroundWindow(); }\n'''
show_new = '''        public static void Show() { if (consoleWindow == null) return; if (gameBar == null) gameBar = new HuymaierGameBarWindow(consoleWindow); gameBar.SetScalePercent(scalePercent); gameBar.SetBrand(displayName, accentColor); gameBar.ShowForForegroundWindow(); }\n'''
if show_old in t:
    t = replace_once(t, show_old, show_new, 'Game Bar applies custom brand on show')

field_anchor = '''        private readonly Grid root;\n        private readonly TextBlock contextText;\n'''
field_new = '''        private readonly Grid root;\n        private readonly TextBlock brandText;\n        private readonly TextBlock contextText;\n'''
if 'private readonly TextBlock brandText;' not in t:
    t = replace_once(t, field_anchor, field_new, 'Game Bar brand field')

brand_old = '''            StackPanel header = new StackPanel(); header.Orientation = Orientation.Horizontal;\n            TextBlock brand = new TextBlock(); brand.Text = "HUYMAIER GAME BAR"; brand.FontSize = 18; brand.FontWeight = FontWeights.Bold; brand.Foreground = new SolidColorBrush(Color.FromRgb(231, 196, 94)); header.Children.Add(brand);\n'''
brand_new = '''            StackPanel header = new StackPanel(); header.Orientation = Orientation.Horizontal;\n            brandText = new TextBlock(); brandText.Text = "HUYMAIER CONSOLE GAME BAR"; brandText.FontSize = 18; brandText.FontWeight = FontWeights.Bold; brandText.Foreground = new SolidColorBrush(Color.FromRgb(231, 196, 94)); header.Children.Add(brandText);\n'''
if brand_old in t:
    t = replace_once(t, brand_old, brand_new, 'Game Bar brand text field')

show_method_anchor = '''        internal void ShowForForegroundWindow()\n        {\n'''
set_brand = '''        internal void SetBrand(string name, string accent)\n        {\n            try\n            {\n                string safeName = String.IsNullOrWhiteSpace(name) ? "Huymaier Console" : name.Trim();\n                if (safeName.Length > 48) safeName = safeName.Substring(0, 48).Trim();\n                Color color = (Color)ColorConverter.ConvertFromString(String.IsNullOrWhiteSpace(accent) ? "#E7C45E" : accent);\n                SolidColorBrush brush = new SolidColorBrush(color); brush.Freeze();\n                brandText.Text = safeName.ToUpperInvariant() + " GAME BAR";\n                brandText.Foreground = brush;\n                statusText.Foreground = brush;\n            }\n            catch { }\n        }\n\n'''
if 'internal void SetBrand(string name, string accent)' not in t:
    t = replace_once(t, show_method_anchor, set_brand + show_method_anchor, 'Game Bar SetBrand')

# Thread-input attachment declarations go alongside RC13's user32 promotion calls.
dll_anchor = '''        [DllImport("user32.dll")] private static extern bool SetForegroundWindow(IntPtr hWnd);\n'''
dll_new = dll_anchor + '''        [DllImport("user32.dll")] private static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint processId);\n        [DllImport("kernel32.dll")] private static extern uint GetCurrentThreadId();\n        [DllImport("user32.dll")] private static extern bool AttachThreadInput(uint idAttach, uint idAttachTo, bool attach);\n'''
if 'AttachThreadInput' not in t:
    t = replace_once(t, dll_anchor, dll_new, 'Game Bar foreground-thread activation declarations')

promote_old = '''                IntPtr handle = new WindowInteropHelper(this).EnsureHandle();\n                if (handle != IntPtr.Zero)\n                {\n                    SetWindowPos(handle, HWND_TOPMOST, 0, 0, 0, 0, SWP_NOMOVE | SWP_NOSIZE | SWP_SHOWWINDOW);\n                    BringWindowToTop(handle);\n                    SetForegroundWindow(handle);\n                }\n                Activate();\n                Focus();\n'''
promote_new = '''                IntPtr handle = new WindowInteropHelper(this).EnsureHandle();\n                if (handle != IntPtr.Zero)\n                {\n                    IntPtr foreground = SystemWindowCatalog.GetForegroundWindow();\n                    uint foregroundPid;\n                    uint foregroundThread = foreground == IntPtr.Zero ? 0 : GetWindowThreadProcessId(foreground, out foregroundPid);\n                    uint currentThread = GetCurrentThreadId();\n                    bool attached = false;\n                    try\n                    {\n                        if (foregroundThread != 0 && foregroundThread != currentThread) attached = AttachThreadInput(currentThread, foregroundThread, true);\n                        SetWindowPos(handle, HWND_TOPMOST, 0, 0, 0, 0, SWP_NOMOVE | SWP_NOSIZE | SWP_SHOWWINDOW);\n                        BringWindowToTop(handle);\n                        SetForegroundWindow(handle);\n                        Activate();\n                        Focus();\n                    }\n                    finally\n                    {\n                        if (attached) try { AttachThreadInput(currentThread, foregroundThread, false); } catch { }\n                    }\n                }\n                else { Activate(); Focus(); }\n'''
if promote_old in t:
    t = replace_once(t, promote_old, promote_new, 'strong Game Bar foreground activation')

write(p, t)

# ---------------------------------------------------------------------------
# Candidate gates for the combined next build.
# ---------------------------------------------------------------------------
p = '.build/Test-HuymaierCandidate.ps1'
t = read(p)
validation_anchor = '''    $validation=Get-Content -Raw -LiteralPath $ValidationPath -Encoding UTF8|ConvertFrom-Json\n'''
static_gates = r'''    # Combined next-build gates: customization is persisted and controller-first,
    # storefront Xbox counts by storefront display identity, custom WPF focus
    # rectangles are removed, and the Game Bar receives the selected branding.
    $customPath=Join-Path $StageRoot 'HuymaierCustomization.ps1'
    if(-not(Test-Path -LiteralPath $customPath -PathType Leaf)){throw 'Customization module is missing from the candidate.'}
    $custom=Get-Content -Raw -LiteralPath $customPath -Encoding UTF8
    foreach($required in @("SubPage -eq 'Customization'",'ConsoleName','DynamicPrimaryColor','DynamicSecondaryColor','UiSoundVolume','Test-HcStorefrontPlatform $Platform','Scaling normal list cards caused selected text/borders to be clipped')){if($custom -notmatch [regex]::Escape($required)){throw "Customization/count/card invariant is missing: $required"}}
    $shell=Get-Content -Raw -LiteralPath (Join-Path $StageRoot 'HuymaierConsole.ps1') -Encoding UTF8
    foreach($required in @('HuymaierCustomization.ps1','FocusVisualStyle','ConsoleBrandText','DynamicGlowOne','Apply-HcCustomizationVisuals')){if($shell -notmatch [regex]::Escape($required)){throw "Shell customization/focus invariant is missing: $required"}}
    $overlay=Get-Content -Raw -LiteralPath (Join-Path $StageRoot 'Native\HuymaierConsole.SystemOverlay.cs') -Encoding UTF8
    foreach($required in @('SetDisplayName','SetAccentColor','SetBrand(displayName, accentColor)','AttachThreadInput','SetWindowPos(handle, HWND_TOPMOST')){if($overlay -notmatch [regex]::Escape($required)){throw "Game Bar branding/focus invariant is missing: $required"}}

'''
if 'Combined next-build gates:' not in t:
    t = replace_once(t, validation_anchor, static_gates + validation_anchor, 'combined next-build static gates')

val_anchor = '''    $validation|Add-Member -NotePropertyName nativeFilePickerRoutingGate -NotePropertyValue 'success' -Force\n'''
val_add = val_anchor + '''    $validation|Add-Member -NotePropertyName customizationGate -NotePropertyValue 'success' -Force\n    $validation|Add-Member -NotePropertyName cardFocusVisualGate -NotePropertyValue 'success' -Force\n    $validation|Add-Member -NotePropertyName xboxStorefrontCountGate -NotePropertyValue 'success' -Force\n    $validation|Add-Member -NotePropertyName gameBarForegroundFocusGate -NotePropertyValue 'success' -Force\n'''
if 'customizationGate' not in t:
    t = replace_once(t, val_anchor, val_add, 'combined next-build validation fields')
write(p, t, bom=True)

print('Combined Game Bar, storefront picker/count, shared-card focus, and customization integration applied.')
