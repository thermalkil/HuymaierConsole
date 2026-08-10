from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
cs=ROOT/'Native'/'HuymaierConsole.ConsolePlatforms.cs'
text=cs.read_text(encoding='utf-8-sig')

def once(old,new,label):
    global text
    count=text.count(old)
    if count!=1:
        raise SystemExit(f'{label}: expected exactly one match, found {count}')
    text=text.replace(old,new,1)

classes=r'''
    internal sealed class BackendSettingEntry
    {
        public string AdapterId { get; set; }
        public string Format { get; set; }
        public string FilePath { get; set; }
        public string Section { get; set; }
        public string Key { get; set; }
        public string Value { get; set; }
        public int LineIndex { get; set; }
        public string Category { get; set; }
        public string Identity { get; set; }
        public string DisplayName { get; set; }
    }

    internal sealed class BackendSettingsInventory
    {
        public int schemaVersion { get; set; }
        public string result { get; set; }
        public string platformId { get; set; }
        public string displayName { get; set; }
        public string adapterId { get; set; }
        public string backend { get; set; }
        public string[] roots { get; set; }
        public string[] configFiles { get; set; }
        public int count { get; set; }
        public List<BackendSettingEntry> settings { get; set; }
        public string generatedAtUtc { get; set; }
    }

'''
anchor='    internal sealed class ConsolePlatformAction\n'
if classes.strip() not in text:
    if text.count(anchor)!=1: raise SystemExit('backend settings class insertion anchor missing')
    text=text.replace(anchor,classes+anchor,1)

once(
    '        private int pspItemIndex;\n',
    '''        private int pspItemIndex;
        private BackendSettingsInventory backendSettingsInventory;
        private List<BackendSettingEntry> backendSettingsEntries;
        private string backendSettingsCategory;
        private BackendSettingEntry selectedBackendSetting;
        private Grid backendValueEditorOverlay;
        private TextBlock backendValueEditorText;
        private List<Button> backendValueKeyButtons;
        private string[] backendValueKeyTokens;
        private int backendValueKeyIndex;
        private bool backendValueEditorActive;
        private bool backendValueShift;
        private string backendValueBuffer;
''',
    'backend settings state fields'
)
once(
    '            pspItemIndex = 0;\n',
    '''            pspItemIndex = 0;
            backendSettingsInventory = null;
            backendSettingsEntries = new List<BackendSettingEntry>();
            backendSettingsCategory = "All Settings";
            selectedBackendSetting = null;
            backendValueEditorOverlay = null;
            backendValueEditorText = null;
            backendValueKeyButtons = new List<Button>();
            backendValueKeyTokens = new string[0];
            backendValueKeyIndex = 0;
            backendValueEditorActive = false;
            backendValueShift = false;
            backendValueBuffer = String.Empty;
''',
    'backend settings state initialization'
)

once(
    '''            if (dashboardGuideVisible)
            {
                if (command == XmbInputCommand.Back || command == XmbInputCommand.Confirm) ToggleDashboardGuide();
                return;
            }

            // Shoulder buttons never change console sections/pages.''',
    '''            if (dashboardGuideVisible)
            {
                if (command == XmbInputCommand.Back || command == XmbInputCommand.Confirm) ToggleDashboardGuide();
                return;
            }
            if (backendValueEditorActive)
            {
                ProcessBackendValueEditorCommand(command);
                return;
            }

            // Shoulder buttons never change console sections/pages.''',
    'backend value editor input interception'
)

once(
    '''                if (!String.IsNullOrWhiteSpace(dashboardSubpage))
                {
                    if (dashboardSubpage == "wii-start")''',
    '''                if (!String.IsNullOrWhiteSpace(dashboardSubpage))
                {
                    if (dashboardSubpage == "backend-setting-detail") { dashboardSubpage = "backend-settings-list"; selected = 0; RenderPage(); return; }
                    if (dashboardSubpage == "backend-settings-list") { dashboardSubpage = "backend-settings"; selectedBackendSetting = null; selected = 0; RenderPage(); return; }
                    if (dashboardSubpage == "backend-settings") { dashboardSubpage = "settings"; selectedBackendSetting = null; selected = 0; RenderPage(); return; }
                    if (dashboardSubpage == "wii-start")''',
    'backend settings back hierarchy'
)

once(
    '''        private void RenderWave1Subpage()
        {
            if(dashboardSubpage=="library"){RenderWave1Library();return;}
''',
    '''        private void RenderWave1Subpage()
        {
            if(dashboardSubpage=="backend-settings"){RenderBackendSettingsCategories();return;}
            if(dashboardSubpage=="backend-settings-list"){RenderBackendSettingsList();return;}
            if(dashboardSubpage=="backend-setting-detail"){RenderBackendSettingDetail();return;}
            if(dashboardSubpage=="library"){RenderWave1Library();return;}
''',
    'backend settings Wave1 dispatch'
)

old_stub='AddRoundedStorage(panel,"Full Emulator Settings","Every discovered backend setting; unknown keys are preserved",definition.Accent,delegate{RequestHuymaierPicker("OpenNativeEmulatorSettings");});'
new_stub='AddRoundedStorage(panel,"Full Emulator Settings","Every discovered backend setting; unknown keys are preserved",definition.Accent,OpenNativeBackendSettings);'
once(old_stub,new_stub,'replace backend settings stub')

methods=r'''
        private string BackendSettingsOutputPath { get { return Path.Combine(dataRoot, "backend-settings.json"); } }
        private string BackendSettingsEditRequestPath { get { return Path.Combine(dataRoot, "backend-settings-edit.json"); } }

        private static string QuoteProcessArgument(string value)
        {
            if (value == null) value = String.Empty;
            if (value.Length == 0) return "\"\"";
            bool needsQuotes = value.Any(delegate(char c) { return Char.IsWhiteSpace(c) || c == '\"'; });
            if (!needsQuotes) return value;
            StringBuilder result = new StringBuilder(); result.Append('\"'); int slashCount = 0;
            foreach (char c in value)
            {
                if (c == '\\') { slashCount++; continue; }
                if (c == '\"') { result.Append('\\', slashCount * 2 + 1); result.Append('\"'); slashCount = 0; continue; }
                if (slashCount > 0) { result.Append('\\', slashCount); slashCount = 0; }
                result.Append(c);
            }
            if (slashCount > 0) result.Append('\\', slashCount * 2);
            result.Append('\"'); return result.ToString();
        }

        private bool RunBackendSettingsWorker(string mode, string editRequestPath)
        {
            string worker = Path.Combine(consoleRoot, "HuymaierEmulatorSettingsWorker.ps1");
            if (!File.Exists(worker)) { ShowNotice("The native emulator settings worker is missing"); return false; }
            try
            {
                Directory.CreateDirectory(dataRoot);
                if (File.Exists(BackendSettingsOutputPath)) File.Delete(BackendSettingsOutputPath);
                string powershell = Path.Combine(Environment.SystemDirectory, "WindowsPowerShell", "v1.0", "powershell.exe");
                if (!File.Exists(powershell)) powershell = "powershell.exe";
                StringBuilder arguments = new StringBuilder();
                arguments.Append("-NoProfile -ExecutionPolicy Bypass -File ").Append(QuoteProcessArgument(worker));
                arguments.Append(" -Mode ").Append(QuoteProcessArgument(mode));
                arguments.Append(" -PlatformId ").Append(QuoteProcessArgument(definition.Id));
                arguments.Append(" -ConsoleRoot ").Append(QuoteProcessArgument(consoleRoot));
                arguments.Append(" -PlatformSettingsPath ").Append(QuoteProcessArgument(settingsPath));
                arguments.Append(" -OutputPath ").Append(QuoteProcessArgument(BackendSettingsOutputPath));
                if (!String.IsNullOrWhiteSpace(editRequestPath)) arguments.Append(" -EditRequestPath ").Append(QuoteProcessArgument(editRequestPath));
                ProcessStartInfo start = new ProcessStartInfo { FileName = powershell, Arguments = arguments.ToString(), UseShellExecute = false, CreateNoWindow = true, WindowStyle = ProcessWindowStyle.Hidden };
                using (Process process = Process.Start(start))
                {
                    if (process == null) throw new InvalidOperationException("The settings worker did not start.");
                    if (!process.WaitForExit(12000)) { try { process.Kill(); } catch { } throw new TimeoutException("The emulator settings scan took too long."); }
                    if (process.ExitCode != 0) throw new InvalidOperationException("The emulator settings worker exited with code " + process.ExitCode.ToString(CultureInfo.InvariantCulture) + ".");
                }
                if (!File.Exists(BackendSettingsOutputPath)) throw new InvalidOperationException("The emulator settings worker did not return an inventory.");
                BackendSettingsInventory inventory = new JavaScriptSerializer().Deserialize<BackendSettingsInventory>(File.ReadAllText(BackendSettingsOutputPath, Encoding.UTF8));
                if (inventory == null || !String.Equals(inventory.result, "success", StringComparison.OrdinalIgnoreCase)) throw new InvalidOperationException("The emulator settings inventory was invalid.");
                backendSettingsInventory = inventory;
                backendSettingsEntries = inventory.settings == null ? new List<BackendSettingEntry>() : inventory.settings.Where(delegate(BackendSettingEntry item) { return item != null && !String.IsNullOrWhiteSpace(item.Identity); }).ToList();
                return true;
            }
            catch (Exception ex)
            {
                WritePlatformLog("Native emulator settings worker failed for " + definition.DisplayName + ": " + ex, "ERROR");
                ShowNotice("Emulator settings could not be loaded: " + ex.Message);
                return false;
            }
        }

        private void OpenNativeBackendSettings()
        {
            backendSettingsCategory = "All Settings"; selectedBackendSetting = null; selected = 0;
            RunBackendSettingsWorker("Inventory", String.Empty);
            dashboardSubpage = "backend-settings"; RenderPage();
        }

        private void AddBackendSettingsAction(Panel panel, string title, string detail, Action invoke)
        {
            Button button = CreateActionButton(title, detail, invoke); panel.Children.Add(button); actions.Add(new ConsolePlatformAction { Button = button, Invoke = invoke, Name = title });
        }

        private string[] GetBackendSettingsCategoryOrder()
        {
            return new string[] { "System", "Graphics", "Audio", "Input", "Paths & Storage", "Network", "Enhancements & Advanced", "Other" };
        }

        private void RenderBackendSettingsCategories()
        {
            titleText.Text = definition.PrimaryBackend + " Settings";
            string files = backendSettingsInventory == null || backendSettingsInventory.configFiles == null ? "0" : backendSettingsInventory.configFiles.Length.ToString(CultureInfo.InvariantCulture);
            subtitleText.Text = backendSettingsEntries.Count.ToString(CultureInfo.InvariantCulture) + " setting(s) discovered across " + files + " config file(s) — changes are backed up before write";
            StackPanel panel = new StackPanel { Margin = new Thickness(44, 4, 44, 24) }; contentHost.Children.Add(new ScrollViewer { VerticalScrollBarVisibility = ScrollBarVisibility.Hidden, Content = panel });
            if (backendSettingsEntries.Count == 0)
            {
                AddBackendSettingsAction(panel, "No emulator settings detected", "Run " + definition.PrimaryBackend + " once or choose its emulator-data folder, then refresh.", delegate { RunBackendSettingsWorker("Inventory", String.Empty); RenderPage(); });
                AddBackendSettingsAction(panel, "Refresh Settings", "Rescan emulator configuration files", delegate { RunBackendSettingsWorker("Inventory", String.Empty); RenderPage(); });
                AddBackendSettingsAction(panel, "Emulator Data", DisplayPath(settings.emulatorDataPath), ChooseEmulatorDataRoot);
                return;
            }
            string all = "All Settings"; AddBackendSettingsAction(panel, all, backendSettingsEntries.Count.ToString(CultureInfo.InvariantCulture) + " discovered settings", delegate { backendSettingsCategory = all; dashboardSubpage = "backend-settings-list"; selected = 0; RenderPage(); });
            foreach (string categoryName in GetBackendSettingsCategoryOrder())
            {
                string captured = categoryName; int count = backendSettingsEntries.Count(delegate(BackendSettingEntry item) { return String.Equals(item.Category, captured, StringComparison.OrdinalIgnoreCase); });
                if (count == 0) continue;
                AddBackendSettingsAction(panel, categoryName, count.ToString(CultureInfo.InvariantCulture) + " settings", delegate { backendSettingsCategory = captured; dashboardSubpage = "backend-settings-list"; selected = 0; RenderPage(); });
            }
            AddBackendSettingsAction(panel, "Refresh Settings", "Rescan files in case the emulator changed them", delegate { RunBackendSettingsWorker("Inventory", String.Empty); RenderPage(); });
        }

        private void RenderBackendSettingsList()
        {
            titleText.Text = String.IsNullOrWhiteSpace(backendSettingsCategory) ? "All Settings" : backendSettingsCategory;
            List<BackendSettingEntry> list = backendSettingsEntries.Where(delegate(BackendSettingEntry item) { return String.Equals(backendSettingsCategory, "All Settings", StringComparison.OrdinalIgnoreCase) || String.Equals(item.Category, backendSettingsCategory, StringComparison.OrdinalIgnoreCase); }).OrderBy(delegate(BackendSettingEntry item) { return item.DisplayName; }, StringComparer.CurrentCultureIgnoreCase).ToList();
            subtitleText.Text = definition.PrimaryBackend + "  •  " + list.Count.ToString(CultureInfo.InvariantCulture) + " setting(s)";
            StackPanel panel = new StackPanel { Margin = new Thickness(30, 0, 30, 24) }; contentHost.Children.Add(new ScrollViewer { VerticalScrollBarVisibility = ScrollBarVisibility.Hidden, Content = panel });
            foreach (BackendSettingEntry item in list)
            {
                BackendSettingEntry captured = item; string fileName = String.IsNullOrWhiteSpace(item.FilePath) ? String.Empty : Path.GetFileName(item.FilePath); string detail = (item.Value ?? String.Empty) + (String.IsNullOrWhiteSpace(fileName) ? String.Empty : "   •   " + fileName);
                AddBackendSettingsAction(panel, String.IsNullOrWhiteSpace(item.DisplayName) ? item.Key : item.DisplayName, detail, delegate { selectedBackendSetting = captured; dashboardSubpage = "backend-setting-detail"; selected = 0; RenderPage(); });
            }
        }

        private static bool TryGetBackendBooleanValue(string value, out bool state)
        {
            state = false; string raw = (value ?? String.Empty).Trim().Trim('\"', '\'').ToLowerInvariant();
            if (raw == "true" || raw == "yes" || raw == "on" || raw == "enabled" || raw == "1") { state = true; return true; }
            if (raw == "false" || raw == "no" || raw == "off" || raw == "disabled" || raw == "0") { state = false; return true; }
            return false;
        }

        private static string ToggleBackendBooleanText(string original, bool newState)
        {
            string value = original ?? String.Empty; string raw = value.Trim(); bool quoted = raw.Length >= 2 && ((raw[0] == '\"' && raw[raw.Length - 1] == '\"') || (raw[0] == '\'' && raw[raw.Length - 1] == '\'')); char quote = quoted ? raw[0] : '\0'; string core = quoted ? raw.Substring(1, raw.Length - 2) : raw; string lower = core.ToLowerInvariant(); string next;
            if (lower == "yes" || lower == "no") next = newState ? "yes" : "no";
            else if (lower == "on" || lower == "off") next = newState ? "on" : "off";
            else if (lower == "enabled" || lower == "disabled") next = newState ? "enabled" : "disabled";
            else if (lower == "1" || lower == "0") next = newState ? "1" : "0";
            else next = newState ? "true" : "false";
            if (core.Length > 0 && Char.IsUpper(core[0])) next = Char.ToUpperInvariant(next[0]) + next.Substring(1);
            return quoted ? quote + next + quote : next;
        }

        private void RenderBackendSettingDetail()
        {
            if (selectedBackendSetting == null) { dashboardSubpage = "backend-settings-list"; RenderBackendSettingsList(); return; }
            BackendSettingEntry item = selectedBackendSetting; titleText.Text = String.IsNullOrWhiteSpace(item.DisplayName) ? item.Key : item.DisplayName; subtitleText.Text = (item.Category ?? "Other") + "  •  " + (String.IsNullOrWhiteSpace(item.FilePath) ? definition.PrimaryBackend : item.FilePath);
            StackPanel panel = new StackPanel { Margin = new Thickness(55, 8, 55, 24) }; contentHost.Children.Add(new ScrollViewer { VerticalScrollBarVisibility = ScrollBarVisibility.Hidden, Content = panel });
            AddBackendSettingsAction(panel, "Current Value", item.Value ?? String.Empty, delegate { OpenBackendValueEditor(item); });
            bool booleanValue; if (TryGetBackendBooleanValue(item.Value, out booleanValue)) { bool next = !booleanValue; AddBackendSettingsAction(panel, next ? "Turn On" : "Turn Off", "Apply immediately with a recoverable config backup", delegate { ApplyBackendSettingValue(item, ToggleBackendBooleanText(item.Value, next)); }); }
            AddBackendSettingsAction(panel, "Edit Value", "Controller-native editor for numeric, enum and text values", delegate { OpenBackendValueEditor(item); });
            AddBackendSettingsAction(panel, "Source", (item.Format ?? "config") + "  •  line " + (item.LineIndex + 1).ToString(CultureInfo.InvariantCulture), delegate { });
            AddBackendSettingsAction(panel, "Back to " + backendSettingsCategory, "Return without changing this setting", delegate { dashboardSubpage = "backend-settings-list"; selected = 0; RenderPage(); });
        }

        private void ApplyBackendSettingValue(BackendSettingEntry item, string value)
        {
            if (item == null) return;
            try
            {
                Dictionary<string, object> request = new Dictionary<string, object>(); request["identity"] = item.Identity; request["value"] = value ?? String.Empty;
                File.WriteAllText(BackendSettingsEditRequestPath, new JavaScriptSerializer().Serialize(request), Encoding.UTF8);
                string identity = item.Identity;
                if (!RunBackendSettingsWorker("Set", BackendSettingsEditRequestPath)) return;
                selectedBackendSetting = backendSettingsEntries.FirstOrDefault(delegate(BackendSettingEntry entry) { return String.Equals(entry.Identity, identity, StringComparison.Ordinal); });
                if (selectedBackendSetting == null) { dashboardSubpage = "backend-settings-list"; }
                ShowNotice("Emulator setting saved — previous config backed up"); RenderPage();
            }
            catch (Exception ex) { WritePlatformLog("Could not apply native emulator setting: " + ex, "ERROR"); ShowNotice("Setting could not be saved: " + ex.Message); }
            finally { try { if (File.Exists(BackendSettingsEditRequestPath)) File.Delete(BackendSettingsEditRequestPath); } catch { } }
        }

        private void OpenBackendValueEditor(BackendSettingEntry item)
        {
            if (item == null) return; selectedBackendSetting = item; backendValueBuffer = item.Value ?? String.Empty; backendValueShift = false; backendValueKeyIndex = 0;
            EnsureBackendValueEditor(); backendValueEditorActive = true; backendValueEditorOverlay.Visibility = Visibility.Visible; UpdateBackendValueEditorText(); UpdateBackendValueEditorVisuals();
        }

        private void EnsureBackendValueEditor()
        {
            if (backendValueEditorOverlay != null) return;
            backendValueKeyTokens = new string[] { "a","b","c","d","e","f","g","h","i","j","k","l","m","n","o","p","q","r","s","t","u","v","w","x","y","z","0","1","2","3","4","5","6","7","8","9",".","-","_","+",":","/","\\","[","]","(",")","{","}","'","\"",",",";","=","SPACE","SHIFT","BACKSPACE","CLEAR","OK" };
            Grid overlay = new Grid { Background = new SolidColorBrush(Color.FromArgb(225, 0, 0, 0)), Visibility = Visibility.Collapsed }; Panel.SetZIndex(overlay, 6000); Grid.SetRowSpan(overlay, 3);
            Border card = new Border { Width = 920, MaxHeight = 690, HorizontalAlignment = HorizontalAlignment.Center, VerticalAlignment = VerticalAlignment.Center, CornerRadius = new CornerRadius(18), Background = new SolidColorBrush(IsLightShell() ? Color.FromRgb(246,248,249) : Color.FromRgb(18,25,36)), BorderBrush = new SolidColorBrush(definition.Accent), BorderThickness = new Thickness(3), Padding = new Thickness(24) };
            Grid layout = new Grid(); layout.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto }); layout.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto }); layout.RowDefinitions.Add(new RowDefinition { Height = new GridLength(1, GridUnitType.Star) });
            TextBlock heading = new TextBlock { Text = "EDIT EMULATOR VALUE", FontSize = 22, FontWeight = FontWeights.SemiBold, Foreground = IsLightShell() ? new SolidColorBrush(Color.FromRgb(49,61,67)) : Brushes.White, Margin = new Thickness(0,0,0,10) }; layout.Children.Add(heading);
            backendValueEditorText = new TextBlock { FontSize = 17, TextWrapping = TextWrapping.Wrap, MinHeight = 68, MaxHeight = 126, Padding = new Thickness(14), Background = new SolidColorBrush(IsLightShell() ? Color.FromRgb(225,231,235) : Color.FromRgb(6,11,19)), Foreground = IsLightShell() ? new SolidColorBrush(Color.FromRgb(35,45,51)) : Brushes.White, Margin = new Thickness(0,0,0,15) }; Grid.SetRow(backendValueEditorText,1); layout.Children.Add(backendValueEditorText);
            UniformGrid keys = new UniformGrid { Columns = 10 }; Grid.SetRow(keys,2); layout.Children.Add(keys);
            foreach (string token in backendValueKeyTokens) { string captured = token; Button button = new Button { Height = 52, Margin = new Thickness(3), FontSize = token.Length == 1 ? 16 : 10, Background = new SolidColorBrush(IsLightShell() ? Color.FromRgb(232,237,240) : Color.FromRgb(33,43,57)), Foreground = IsLightShell() ? new SolidColorBrush(Color.FromRgb(41,51,58)) : Brushes.White, BorderBrush = new SolidColorBrush(Color.FromArgb(90,definition.Accent.R,definition.Accent.G,definition.Accent.B)), BorderThickness = new Thickness(1), Tag = token }; button.Content = GetBackendEditorKeyLabel(token); button.Click += delegate { ApplyBackendEditorToken(captured); }; keys.Children.Add(button); backendValueKeyButtons.Add(button); }
            card.Child = layout; overlay.Children.Add(card); backendValueEditorOverlay = overlay; root.Children.Add(overlay);
        }

        private string GetBackendEditorKeyLabel(string token)
        {
            if (token == "SPACE") return "SPACE"; if (token == "SHIFT") return backendValueShift ? "SHIFT ↑" : "SHIFT"; if (token == "BACKSPACE") return "⌫"; if (token == "CLEAR") return "CLEAR"; if (token == "OK") return "OK";
            if (token.Length == 1 && Char.IsLetter(token[0])) return backendValueShift ? token.ToUpperInvariant() : token; return token;
        }

        private void UpdateBackendValueEditorText()
        {
            if (backendValueEditorText != null) backendValueEditorText.Text = backendValueBuffer + "\n\nA  Type     B  Cancel     D-Pad  Move";
        }

        private void UpdateBackendValueEditorVisuals()
        {
            for (int i = 0; i < backendValueKeyButtons.Count; i++) { Button button = backendValueKeyButtons[i]; button.Content = GetBackendEditorKeyLabel((string)button.Tag); bool active = i == backendValueKeyIndex; button.BorderBrush = new SolidColorBrush(active ? definition.Accent : Color.FromArgb(90,definition.Accent.R,definition.Accent.G,definition.Accent.B)); button.BorderThickness = active ? new Thickness(3) : new Thickness(1); button.RenderTransform = active ? new ScaleTransform(1.08,1.08) : Transform.Identity; }
        }

        private void ProcessBackendValueEditorCommand(XmbInputCommand command)
        {
            if (command == XmbInputCommand.Back) { CloseBackendValueEditor(false); PlayEffect("Back.wav"); return; }
            if (backendValueKeyButtons.Count == 0) return; int next = backendValueKeyIndex; int row = 10;
            if (command == XmbInputCommand.Left) next--; else if (command == XmbInputCommand.Right) next++; else if (command == XmbInputCommand.Up) next -= row; else if (command == XmbInputCommand.Down) next += row; else if (command == XmbInputCommand.Confirm) { ApplyBackendEditorToken(backendValueKeyTokens[backendValueKeyIndex]); return; } else return;
            next = Math.Max(0, Math.Min(backendValueKeyButtons.Count - 1, next)); if (next != backendValueKeyIndex) { backendValueKeyIndex = next; PlayEffect("Navigate.wav"); UpdateBackendValueEditorVisuals(); }
        }

        private void ApplyBackendEditorToken(string token)
        {
            if (token == "OK") { CloseBackendValueEditor(true); return; }
            if (token == "CLEAR") backendValueBuffer = String.Empty;
            else if (token == "BACKSPACE") { if (backendValueBuffer.Length > 0) backendValueBuffer = backendValueBuffer.Substring(0, backendValueBuffer.Length - 1); }
            else if (token == "SPACE") backendValueBuffer += " ";
            else if (token == "SHIFT") backendValueShift = !backendValueShift;
            else backendValueBuffer += (backendValueShift && token.Length == 1 && Char.IsLetter(token[0])) ? token.ToUpperInvariant() : token;
            PlayEffect("Confirm.wav"); UpdateBackendValueEditorText(); UpdateBackendValueEditorVisuals();
        }

        private void CloseBackendValueEditor(bool commit)
        {
            string value = backendValueBuffer; backendValueEditorActive = false; if (backendValueEditorOverlay != null) backendValueEditorOverlay.Visibility = Visibility.Collapsed;
            if (commit && selectedBackendSetting != null) { PlayEffect("Confirm.wav"); ApplyBackendSettingValue(selectedBackendSetting, value); }
        }

'''
insert='        private void RenderXboxRoot()\n'
if 'private void OpenNativeBackendSettings()' not in text:
    if text.count(insert)!=1: raise SystemExit('backend settings methods insertion anchor missing')
    text=text.replace(insert,methods+insert,1)

cs.write_text(text,encoding='utf-8')

worker=ROOT/'HuymaierEmulatorSettingsWorker.ps1'
w=worker.read_text(encoding='utf-8-sig')
old="    [string]$Identity='',\n    [AllowEmptyString()][string]$Value=''\n)"
new="    [string]$Identity='',\n    [AllowEmptyString()][string]$Value='',\n    [string]$EditRequestPath=''\n)"
if old in w:
    w=w.replace(old,new,1)
elif '[string]$EditRequestPath' not in w:
    raise SystemExit('worker edit request parameter anchor missing')
edit=r'''
if($Mode -eq 'Set' -and -not [string]::IsNullOrWhiteSpace($EditRequestPath)){
    if(-not(Test-Path -LiteralPath $EditRequestPath -PathType Leaf)){throw 'The native emulator setting edit request is missing.'}
    $editRequest=Get-Content -Raw -LiteralPath $EditRequestPath -Encoding UTF8|ConvertFrom-Json
    $Identity=[string](Get-EntryProperty $editRequest 'identity' '')
    $Value=[string](Get-EntryProperty $editRequest 'value' '')
}

'''
mark="if($Mode -eq 'Set'){\n"
if edit.strip() not in w:
    if w.count(mark)!=1: raise SystemExit('worker edit request insertion anchor missing')
    w=w.replace(mark,edit+mark,1)
worker.write_text(w,encoding='utf-8')
print('materialized controller-native full backend settings editor')
