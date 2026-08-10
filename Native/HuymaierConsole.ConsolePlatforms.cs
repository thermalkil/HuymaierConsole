using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Net;
using System.Runtime.InteropServices;
using System.Text;
using System.Web.Script.Serialization;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Controls.Primitives;
using System.Windows.Input;
using System.Windows.Interop;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using Microsoft.Win32;

namespace HuymaierConsole.NativeApp
{
    public sealed class ConsoleStartupVideoOverlay : Grid
    {
        private readonly MediaElement media;
        private readonly TextBlock hint;
        private readonly System.Windows.Threading.DispatcherTimer watchdog;
        private Action completed;
        private bool active;
        private string fallbackPath;
        private double playbackVolume;
        private bool fallbackAttempted;

        public ConsoleStartupVideoOverlay()
        {
            Background = Brushes.Black;
            Visibility = Visibility.Collapsed;
            IsHitTestVisible = true;
            Panel.SetZIndex(this, 5000);

            media = new MediaElement();
            media.LoadedBehavior = MediaState.Manual;
            media.UnloadedBehavior = MediaState.Stop;
            media.Stretch = Stretch.Uniform;
            media.HorizontalAlignment = HorizontalAlignment.Stretch;
            media.VerticalAlignment = VerticalAlignment.Stretch;
            media.MediaEnded += delegate { Finish(); };
            media.MediaFailed += delegate { TryFallbackOrFinish(); };
            Children.Add(media);

            hint = new TextBlock();
            hint.Text = "A / CROSS  Skip";
            hint.Foreground = new SolidColorBrush(Color.FromArgb(175, 255, 255, 255));
            hint.FontSize = 13;
            hint.HorizontalAlignment = HorizontalAlignment.Right;
            hint.VerticalAlignment = VerticalAlignment.Bottom;
            hint.Margin = new Thickness(0, 0, 32, 24);
            Children.Add(hint);

            watchdog = new System.Windows.Threading.DispatcherTimer(System.Windows.Threading.DispatcherPriority.Background);
            watchdog.Interval = TimeSpan.FromSeconds(35);
            watchdog.Tick += delegate { Finish(); };
        }

        public bool IsActive { get { return active; } }

        public void Play(string path, double volume, Action onCompleted)
        {
            completed = onCompleted;
            playbackVolume = Math.Max(0.0, Math.Min(1.0, volume));
            fallbackAttempted = false;
            fallbackPath = String.Empty;
            try
            {
                string folder = Path.GetDirectoryName(path ?? String.Empty);
                if (!String.IsNullOrWhiteSpace(folder))
                {
                    string candidate = Path.Combine(folder, "Startup.fallback.mp4");
                    if (File.Exists(candidate)) fallbackPath = candidate;
                }
            }
            catch { fallbackPath = String.Empty; }
            if (String.IsNullOrWhiteSpace(path) || !File.Exists(path))
            {
                if (!String.IsNullOrWhiteSpace(fallbackPath))
                {
                    fallbackAttempted = true;
                    BeginPlayback(fallbackPath);
                }
                else Finish();
                return;
            }
            BeginPlayback(path);
        }

        private void BeginPlayback(string path)
        {
            try
            {
                active = true;
                Visibility = Visibility.Visible;
                media.Stop();
                media.Close();
                media.Source = new Uri(path, UriKind.Absolute);
                media.Volume = playbackVolume;
                media.Position = TimeSpan.Zero;
                media.Play();
                watchdog.Stop();
                watchdog.Start();
            }
            catch { TryFallbackOrFinish(); }
        }

        private void TryFallbackOrFinish()
        {
            if (!fallbackAttempted && !String.IsNullOrWhiteSpace(fallbackPath) && File.Exists(fallbackPath))
            {
                fallbackAttempted = true;
                BeginPlayback(fallbackPath);
                return;
            }
            Finish();
        }

        public void Skip() { Finish(); }

        public void Stop()
        {
            try { watchdog.Stop(); } catch { }
            try { media.Stop(); media.Close(); } catch { }
            active = false;
            Visibility = Visibility.Collapsed;
            completed = null;
        }

        private void Finish()
        {
            Action callback = completed;
            completed = null;
            try { watchdog.Stop(); } catch { }
            try { media.Stop(); media.Close(); } catch { }
            active = false;
            Visibility = Visibility.Collapsed;
            if (callback != null)
            {
                try { callback(); } catch { }
            }
        }
    }

    public sealed class ConsolePlatformSettings
    {
        public int schemaVersion { get; set; }
        public string emulatorPath { get; set; }
        public string fallbackEmulatorPath { get; set; }
        public List<string> gameFolders { get; set; }
        public bool startupEnabled { get; set; }
        public double startupVolume { get; set; }
        public bool ambienceEnabled { get; set; }
        public string ambiencePath { get; set; }
        public double ambienceVolume { get; set; }
        public double soundVolume { get; set; }
        public string dashboardStyle { get; set; }
        public bool fullscreen { get; set; }

        public ConsolePlatformSettings()
        {
            schemaVersion = 5;
            emulatorPath = String.Empty;
            fallbackEmulatorPath = String.Empty;
            gameFolders = new List<string>();
            startupEnabled = true;
            startupVolume = 1.0;
            ambienceEnabled = false;
            ambiencePath = String.Empty;
            ambienceVolume = 0.75;
            soundVolume = 1.0;
            dashboardStyle = String.Empty;
            fullscreen = true;
        }

        public static ConsolePlatformSettings Load(string userPath, string defaultPath, ConsolePlatformDefinition definition)
        {
            JavaScriptSerializer serializer = new JavaScriptSerializer();
            ConsolePlatformSettings result = new ConsolePlatformSettings();
            try { if (File.Exists(defaultPath)) result = serializer.Deserialize<ConsolePlatformSettings>(File.ReadAllText(defaultPath, Encoding.UTF8)); } catch { }
            try { if (File.Exists(userPath)) result = serializer.Deserialize<ConsolePlatformSettings>(File.ReadAllText(userPath, Encoding.UTF8)); } catch { }
            int loadedSchema = result == null ? 0 : result.schemaVersion;
            if (result == null) result = new ConsolePlatformSettings();
            if (loadedSchema < 2 && Math.Abs(result.ambienceVolume - 0.55) < 0.001) result.ambienceVolume = 0.75;
            if (loadedSchema < 3 && result.soundVolume < 0.85) result.soundVolume = 1.0;
            if (loadedSchema < 3 && definition.Shell == "Xbox360" && Math.Abs(result.ambienceVolume - 0.75) < 0.001) result.ambienceVolume = 0.90;
            if (definition.Shell == "Xbox360" && String.Equals(result.dashboardStyle, "NXE", StringComparison.OrdinalIgnoreCase)) result.dashboardStyle = "Blades";
            if (loadedSchema < 4 && definition.Shell == "Xbox360" && result.ambienceVolume < 0.90) result.ambienceVolume = 0.90;
            if (result.gameFolders == null) result.gameFolders = new List<string>();
            result.gameFolders = result.gameFolders.Where(delegate(string p) { return !String.IsNullOrWhiteSpace(p); })
                .Select(delegate(string p) { try { return Path.GetFullPath(Environment.ExpandEnvironmentVariables(p)); } catch { return p; } })
                .Distinct(StringComparer.OrdinalIgnoreCase).ToList();
            if (String.IsNullOrWhiteSpace(result.dashboardStyle)) result.dashboardStyle = definition.DefaultDashboardStyle;
            if (String.IsNullOrWhiteSpace(result.emulatorPath)) result.emulatorPath = definition.FindPrimaryEmulator();
            if (String.IsNullOrWhiteSpace(result.fallbackEmulatorPath)) result.fallbackEmulatorPath = definition.FindFallbackEmulator(result.emulatorPath);
            result.startupVolume = Clamp(result.startupVolume);
            result.ambienceVolume = Clamp(result.ambienceVolume);
            result.soundVolume = Clamp(result.soundVolume);
            result.schemaVersion = 5;
            result.Save(userPath);
            return result;
        }

        public void Save(string path)
        {
            try
            {
                Directory.CreateDirectory(Path.GetDirectoryName(path));
                File.WriteAllText(path, new JavaScriptSerializer().Serialize(this), Encoding.UTF8);
            }
            catch { }
        }

        private static double Clamp(double value) { return Math.Max(0.0, Math.Min(1.0, value)); }
    }

    public sealed class ConsolePlatformDefinition
    {
        public string Id;
        public string DisplayName;
        public string Subtitle;
        public string Shell;
        public string PrimaryBackend;
        public string FallbackBackend;
        public string[] PrimaryExecutableNames;
        public string[] FallbackExecutableNames;
        public string[] GameExtensions;
        public string[] DashboardStyles;
        public string DefaultDashboardStyle;
        public Color ColorA;
        public Color ColorB;
        public Color Accent;

        public static ConsolePlatformDefinition Create(string id)
        {
            string key = (id ?? String.Empty).Replace(" ", String.Empty).Replace("-", String.Empty).ToUpperInvariant();
            ConsolePlatformDefinition d = new ConsolePlatformDefinition();
            d.Id = key;
            d.DashboardStyles = new string[] { "Original" };
            d.DefaultDashboardStyle = "Original";
            if (key == "N64")
            {
                d.DisplayName = "Nintendo 64"; d.Subtitle = "Cartridge Library"; d.Shell = "N64";
                d.PrimaryBackend = "RMG"; d.FallbackBackend = "ares";
                d.PrimaryExecutableNames = new string[] { "RMG.exe", "Rosalie's Mupen GUI.exe" };
                d.FallbackExecutableNames = new string[] { "ares.exe" };
                d.GameExtensions = new string[] { ".z64", ".n64", ".v64", ".zip", ".7z" };
                d.ColorA = Color.FromRgb(18, 19, 28); d.ColorB = Color.FromRgb(44, 25, 65); d.Accent = Color.FromRgb(243, 196, 46);
            }
            else if (key == "GAMECUBE")
            {
                d.DisplayName = "Nintendo GameCube"; d.Subtitle = "Disc Library"; d.Shell = "GameCube";
                d.PrimaryBackend = "Dolphin"; d.FallbackBackend = "Dolphin Development";
                d.PrimaryExecutableNames = new string[] { "Dolphin.exe", "DolphinQt2.exe" };
                d.FallbackExecutableNames = new string[] { "Dolphin.exe", "DolphinQt2.exe" };
                d.GameExtensions = new string[] { ".iso", ".gcm", ".rvz", ".ciso", ".gcz" };
                d.ColorA = Color.FromRgb(18, 15, 53); d.ColorB = Color.FromRgb(73, 51, 142); d.Accent = Color.FromRgb(150, 126, 255);
            }
            else if (key == "WII")
            {
                d.DisplayName = "Nintendo Wii"; d.Subtitle = "Wii Menu"; d.Shell = "Wii";
                d.PrimaryBackend = "Dolphin"; d.FallbackBackend = "Dolphin Development";
                d.PrimaryExecutableNames = new string[] { "Dolphin.exe", "DolphinQt2.exe" };
                d.FallbackExecutableNames = new string[] { "Dolphin.exe", "DolphinQt2.exe" };
                d.GameExtensions = new string[] { ".iso", ".wbfs", ".rvz", ".wia", ".gcz" };
                d.ColorA = Color.FromRgb(231, 236, 240); d.ColorB = Color.FromRgb(255, 255, 255); d.Accent = Color.FromRgb(63, 184, 220);
            }
            else if (key == "WIIU")
            {
                d.DisplayName = "Nintendo Wii U"; d.Subtitle = "Wii U Menu"; d.Shell = "WiiU";
                d.PrimaryBackend = "Cemu"; d.FallbackBackend = "Cemu Portable";
                d.PrimaryExecutableNames = new string[] { "Cemu.exe" };
                d.FallbackExecutableNames = new string[] { "Cemu.exe" };
                d.GameExtensions = new string[] { ".wua", ".wud", ".wux", ".rpx" };
                d.ColorA = Color.FromRgb(223, 239, 245); d.ColorB = Color.FromRgb(250, 253, 255); d.Accent = Color.FromRgb(30, 154, 205);
            }
            else if (key == "SWITCH")
            {
                d.DisplayName = "Nintendo Switch"; d.Subtitle = "HOME Menu"; d.Shell = "Switch";
                d.PrimaryBackend = "Eden"; d.FallbackBackend = "Ryubing";
                d.PrimaryExecutableNames = new string[] { "eden.exe", "Eden.exe" };
                d.FallbackExecutableNames = new string[] { "Ryujinx.exe", "ryujinx.exe" };
                d.GameExtensions = new string[] { ".nsp", ".xci", ".nca", ".nro" };
                d.ColorA = Color.FromRgb(39, 40, 44); d.ColorB = Color.FromRgb(68, 69, 74); d.Accent = Color.FromRgb(230, 0, 18);
            }
            else if (key == "XBOX")
            {
                d.DisplayName = "Xbox"; d.Subtitle = "Original Xbox Dashboard"; d.Shell = "Xbox";
                d.PrimaryBackend = "xemu"; d.FallbackBackend = "Cxbx-Reloaded";
                d.PrimaryExecutableNames = new string[] { "xemu.exe" };
                d.FallbackExecutableNames = new string[] { "cxbxr-ldr.exe", "Cxbx.exe" };
                d.GameExtensions = new string[] { ".iso", ".xiso", ".xbe" };
                d.ColorA = Color.FromRgb(2, 10, 2); d.ColorB = Color.FromRgb(18, 63, 8); d.Accent = Color.FromRgb(96, 197, 24);
            }
            else
            {
                d.Id = "XBOX360"; d.DisplayName = "Xbox 360"; d.Subtitle = "Xbox 360 Dashboard"; d.Shell = "Xbox360";
                d.PrimaryBackend = "Xenia Canary"; d.FallbackBackend = "Xenia Master";
                d.PrimaryExecutableNames = new string[] { "xenia_canary.exe", "xenia_canary_netplay.exe" };
                d.FallbackExecutableNames = new string[] { "xenia.exe" };
                d.GameExtensions = new string[] { ".iso", ".xex", ".zar" };
                d.DashboardStyles = new string[] { "Blades", "Metro" };
                d.DefaultDashboardStyle = "Blades";
                d.ColorA = Color.FromRgb(37, 43, 48); d.ColorB = Color.FromRgb(98, 110, 104); d.Accent = Color.FromRgb(107, 181, 43);
            }
            return d;
        }

        public string FindPrimaryEmulator() { return FindExecutable(PrimaryExecutableNames, String.Empty); }
        public string FindFallbackEmulator(string primary) { return FindExecutable(FallbackExecutableNames, primary); }

        private static string FindExecutable(string[] names, string excluded)
        {
            if (names == null) return String.Empty;
            List<string> roots = new List<string>();
            AddRoot(roots, AppDomain.CurrentDomain.BaseDirectory);
            AddRoot(roots, Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles));
            AddRoot(roots, Environment.GetFolderPath(Environment.SpecialFolder.ProgramFilesX86));
            AddRoot(roots, Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData));
            AddRoot(roots, Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "Programs"));
            AddRoot(roots, Environment.GetFolderPath(Environment.SpecialFolder.DesktopDirectory));
            AddRoot(roots, Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.UserProfile), "Emulators"));
            foreach (string root in roots)
            {
                foreach (string name in names)
                {
                    string direct = Path.Combine(root, name);
                    if (File.Exists(direct) && !String.Equals(direct, excluded, StringComparison.OrdinalIgnoreCase)) return direct;
                    try
                    {
                        foreach (string dir in Directory.GetDirectories(root).Take(160))
                        {
                            string candidate = Path.Combine(dir, name);
                            if (File.Exists(candidate) && !String.Equals(candidate, excluded, StringComparison.OrdinalIgnoreCase)) return candidate;
                        }
                    }
                    catch { }
                }
            }
            return String.Empty;
        }

        private static void AddRoot(List<string> roots, string value)
        {
            if (String.IsNullOrWhiteSpace(value) || !Directory.Exists(value)) return;
            if (!roots.Contains(value, StringComparer.OrdinalIgnoreCase)) roots.Add(value);
        }
    }

    public sealed class ConsolePlatformGame
    {
        public string Name { get; set; }
        public string Path { get; set; }
        public string Cover { get; set; }
        public ConsolePlatformGame() { Name = String.Empty; Path = String.Empty; Cover = String.Empty; }
    }

    internal sealed class XboxAchievementEntry
    {
        internal string TitleId;
        internal string TitleName;
        internal uint AchievementId;
        internal uint ImageId;
        internal int Gamerscore;
        internal uint Flags;
        internal DateTime UnlockTime;
        internal string Name;
        internal string UnlockedDescription;
        internal string LockedDescription;
        internal string IconPath;
        internal bool Earned { get { return (Flags & 0x00020000U) != 0; } }
        internal bool ShowUnachieved { get { return (Flags & 0x00000008U) != 0; } }
    }

    internal sealed class XboxSaveEntry
    {
        internal string Name;
        internal string TitleId;
        internal string Path;
        internal bool IsDirectory;
        internal long Size;
        internal DateTime Modified;
    }

    internal sealed class XboxXdbfEntry
    {
        internal ushort Namespace;
        internal ulong Id;
        internal uint Offset;
        internal uint Length;
    }

    internal sealed class ConsolePlatformAction
    {
        internal Button Button;
        internal Action Invoke;
        internal string Name;
        internal ConsolePlatformGame Game;
    }

    public sealed class ConsolePlatformWindow : Window
    {
        private readonly string platformRoot;
        private readonly string consoleRoot;
        private readonly ConsolePlatformDefinition definition;
        private readonly string dataRoot;
        private readonly string settingsPath;
        private readonly string libraryCachePath;
        private ConsolePlatformSettings settings;
        private readonly Grid root;
        private readonly Grid chrome;
        private readonly Grid contentHost;
        private readonly TextBlock titleText;
        private readonly TextBlock subtitleText;
        private readonly TextBlock noticeText;
        private readonly StackPanel navigation;
        private readonly List<Button> navButtons;
        private readonly List<ConsolePlatformAction> actions;
        private readonly XmbInputRouter input;
        private readonly System.Windows.Threading.DispatcherTimer inputTimer;
        private readonly MediaPlayer effectPlayer;
        private readonly MediaPlayer ambiencePlayer;
        private readonly ConsoleStartupVideoOverlay startupOverlay;
        private readonly Grid dashboardGuideOverlay;
        private List<ConsolePlatformGame> games;
        private int page;
        private int selected;
        private int columns;
        private Process activeProcess;
        private HwndSource source;
        private HwndSourceHook hook;
        private DateTime inputGuardUntilUtc;
        private DateTime noticeUntilUtc;
        private bool dashboardGuideVisible;
        private string dashboardSubpage;
        private XboxSaveEntry selectedXboxSave;
        private List<XboxSaveEntry> xboxSaveEntries;
        private List<XboxAchievementEntry> xboxAchievements;
        private Dictionary<string, string> xboxTitleNames;
        private bool xboxAchievementsLoaded;
        private bool xboxAchievementScanRunning;
        private bool xboxArtworkScanRunning;
        private Dictionary<string, string> sharedArtworkIndex;
        private DateTime sharedArtworkIndexLoadedUtc;
        private bool closing;
        private int asyncGeneration;
        private TextBlock xboxPreviewTitle;
        private TextBlock xboxPreviewDetail;
        private Image xboxPreviewImage;
        private int wiiMenuPage;
        private int wiiUMenuPage;
        private int switchZone;
        private int switchSoftwareIndex;
        private int switchSystemIndex;
        private int switchSoftwareActionCount;
        private int switchSystemActionStart;
        private bool chromeNavigationActive;
        private ConsolePlatformGame shellSelectedGame;

        public ConsolePlatformWindow(string platformRootValue, string consoleRootValue, string platformId)
        {
            platformRoot = platformRootValue ?? String.Empty;
            consoleRoot = consoleRootValue ?? String.Empty;
            definition = ConsolePlatformDefinition.Create(platformId);
            dataRoot = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "Huymaier Console", "EmulatorPlatforms", definition.Id);
            settingsPath = Path.Combine(dataRoot, "settings.json");
            libraryCachePath = Path.Combine(dataRoot, "library-cache.json");
            Directory.CreateDirectory(dataRoot);
            Directory.CreateDirectory(Path.Combine(dataRoot, "Backups"));
            settings = ConsolePlatformSettings.Load(settingsPath, Path.Combine(platformRoot, "settings.default.json"), definition);
            games = LoadCachedGames();
            page = GetDefaultPageIndex();
            selected = 0;
            columns = 6;
            navButtons = new List<Button>();
            actions = new List<ConsolePlatformAction>();
            dashboardSubpage = String.Empty;
            selectedXboxSave = null;
            xboxSaveEntries = new List<XboxSaveEntry>();
            xboxAchievements = new List<XboxAchievementEntry>();
            xboxTitleNames = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
            xboxAchievementsLoaded = false;
            xboxAchievementScanRunning = false;
            xboxArtworkScanRunning = false;
            wiiMenuPage = 0;
            wiiUMenuPage = 0;
            switchZone = 0;
            switchSoftwareIndex = 0;
            switchSystemIndex = 0;
            switchSoftwareActionCount = 0;
            switchSystemActionStart = 0;
            chromeNavigationActive = definition.Shell == "Xbox" || (definition.Shell == "Xbox360" && String.Equals(settings.dashboardStyle, "Metro", StringComparison.OrdinalIgnoreCase));
            shellSelectedGame = null;
            sharedArtworkIndex = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
            sharedArtworkIndexLoadedUtc = DateTime.MinValue;
            closing = false;
            asyncGeneration = 0;
            input = new XmbInputRouter();
            effectPlayer = new MediaPlayer();
            ambiencePlayer = new MediaPlayer();
            ambiencePlayer.MediaEnded += delegate { try { ambiencePlayer.Position = TimeSpan.Zero; ambiencePlayer.Play(); } catch { } };

            Title = definition.DisplayName;
            WindowStyle = WindowStyle.None;
            ResizeMode = ResizeMode.NoResize;
            WindowState = settings.fullscreen ? WindowState.Maximized : WindowState.Normal;
            Background = Brushes.Black;
            ShowInTaskbar = false;
            SnapsToDevicePixels = true;
            UseLayoutRounding = true;

            root = new Grid();
            root.Background = BuildBackground();
            bool immersiveDashboard = true;
            root.RowDefinitions.Add(new RowDefinition { Height = new GridLength(0) });
            root.RowDefinitions.Add(new RowDefinition { Height = new GridLength(1, GridUnitType.Star) });
            root.RowDefinitions.Add(new RowDefinition { Height = new GridLength(immersiveDashboard ? 56 : 48) });

            Grid header = BuildHeader();
            Grid.SetRow(header, 0);
            root.Children.Add(header);

            chrome = new Grid();
            Grid.SetRow(chrome, 1);
            root.Children.Add(chrome);
            navigation = new StackPanel();
            contentHost = new Grid();
            titleText = new TextBlock();
            subtitleText = new TextBlock();
            BuildChrome();

            Grid footer = new Grid { Margin = new Thickness(28, 0, 28, 0) };
            string helpText;
            if (definition.Shell == "GameCube") helpText = "D-Pad  Menu     A  Select     B  Back     OPTIONS  Alternate emulator     GUIDE  Game Bar";
            else if (definition.Shell == "Wii") helpText = "D-Pad  Point / Navigate     A  Select     B  Back     GUIDE  Game Bar";
            else if (definition.Shell == "WiiU") helpText = "D-Pad  Navigate     A  Select     B  Back     GUIDE  Game Bar";
            else if (definition.Shell == "Switch") helpText = "D-Pad  Navigate     A  OK     B  Back     GUIDE  Game Bar";
            else if (definition.Shell == "Xbox360" && IsBlades()) helpText = "LEFT / RIGHT  Blade     UP / DOWN  Item     A  Select     B  Back     GUIDE  Game Bar";
            else if (definition.Shell == "Xbox360") helpText = "D-Pad  Navigate     A  Select     B  Back     GUIDE  Game Bar";
            else if (definition.Shell == "Xbox") helpText = "UP / DOWN  Menu     A  Select     B  Back     X  Alternate     GUIDE  Game Bar";
            else helpText = "D-Pad  Navigate     A  Select     B  Back     OPTIONS  Alternate emulator     GUIDE  Game Bar";
            TextBlock help = new TextBlock { Text = helpText, FontSize = 13, VerticalAlignment = VerticalAlignment.Center };
            help.Foreground = IsLightShell() ? new SolidColorBrush(Color.FromRgb(54, 69, 75)) : new SolidColorBrush(Color.FromRgb(218, 224, 230));
            noticeText = new TextBlock { HorizontalAlignment = HorizontalAlignment.Right, VerticalAlignment = VerticalAlignment.Center, FontSize = 13, Foreground = new SolidColorBrush(definition.Accent) };
            footer.Children.Add(help);
            footer.Children.Add(noticeText);
            Grid.SetRow(footer, 2);
            root.Children.Add(footer);

            dashboardGuideOverlay = BuildDashboardGuideOverlay();
            Grid.SetRowSpan(dashboardGuideOverlay, 3);
            root.Children.Add(dashboardGuideOverlay);

            startupOverlay = new ConsoleStartupVideoOverlay();
            Grid.SetRowSpan(startupOverlay, 3);
            root.Children.Add(startupOverlay);
            Content = root;

            inputTimer = new System.Windows.Threading.DispatcherTimer(System.Windows.Threading.DispatcherPriority.Input);
            inputTimer.Interval = TimeSpan.FromMilliseconds(12);
            inputTimer.Tick += InputTick;

            Dispatcher.UnhandledException += DispatcherUnhandledException;
            SourceInitialized += OnSourceInitialized;
            Loaded += OnLoaded;
            Closing += OnClosing;
            Closed += OnClosed;
            PreviewKeyDown += OnKeyDown;
            SizeChanged += delegate { CalculateColumns(); };
            RenderPage();
        }

        private bool IsLightShell()
        {
            return definition.Shell == "Wii" || definition.Shell == "WiiU";
        }

        private bool IsXboxFamily() { return definition.Shell == "Xbox" || definition.Shell == "Xbox360"; }
        private bool IsBlades() { return definition.Shell == "Xbox360" && String.Equals(settings.dashboardStyle, "Blades", StringComparison.OrdinalIgnoreCase); }
        private bool IsMetro() { return definition.Shell == "Xbox360" && String.Equals(settings.dashboardStyle, "Metro", StringComparison.OrdinalIgnoreCase); }
        private bool IsGamePage() { return definition.Shell == "Xbox360" ? (IsBlades() ? page == 1 : page == 2) : page == 0; }
        private int GetPageCount() { if (definition.Shell == "GameCube") return 4; return definition.Shell == "Xbox" ? 5 : (definition.Shell == "Xbox360" ? (IsBlades() ? 4 : 7) : 3); }
        private int GetDefaultPageIndex() { return definition.Shell == "Xbox360" && String.Equals(settings == null ? definition.DefaultDashboardStyle : settings.dashboardStyle, "Blades", StringComparison.OrdinalIgnoreCase) ? 1 : 0; }
        private int GetSettingsPageIndex() { if (definition.Shell == "GameCube") return 3; return definition.Shell == "Xbox" ? 4 : (definition.Shell == "Xbox360" ? (IsBlades() ? 3 : 6) : 2); }
        private bool IsRootConsoleSurface() { return String.IsNullOrWhiteSpace(dashboardSubpage); }
        private bool IsXboxRoot() { return definition.Shell == "Xbox" && IsRootConsoleSurface(); }
        private bool IsGameCubeHub() { return definition.Shell == "GameCube" && IsRootConsoleSurface(); }

        private Brush BuildBackground()
        {
            if (definition.Shell == "Xbox")
            {
                RadialGradientBrush xbox = new RadialGradientBrush();
                xbox.Center = new Point(0.34, 0.48); xbox.GradientOrigin = new Point(0.34, 0.48); xbox.RadiusX = 0.82; xbox.RadiusY = 1.05;
                xbox.GradientStops.Add(new GradientStop(Color.FromRgb(37, 112, 12), 0));
                xbox.GradientStops.Add(new GradientStop(Color.FromRgb(5, 34, 3), 0.36));
                xbox.GradientStops.Add(new GradientStop(Color.FromRgb(0, 4, 0), 1));
                return xbox;
            }
            if (definition.Shell == "Xbox360")
            {
                string style = settings == null ? definition.DefaultDashboardStyle : settings.dashboardStyle;
                if (String.Equals(style, "Blades", StringComparison.OrdinalIgnoreCase))
                {
                    LinearGradientBrush blades = new LinearGradientBrush();
                    blades.StartPoint = new Point(0, 0); blades.EndPoint = new Point(1, 1);
                    blades.GradientStops.Add(new GradientStop(Color.FromRgb(238, 240, 239), 0));
                    blades.GradientStops.Add(new GradientStop(Color.FromRgb(148, 153, 151), 0.42));
                    blades.GradientStops.Add(new GradientStop(Color.FromRgb(38, 43, 45), 1));
                    return blades;
                }
                LinearGradientBrush metro = new LinearGradientBrush();
                metro.StartPoint = new Point(0, 0); metro.EndPoint = new Point(1, 1);
                metro.GradientStops.Add(new GradientStop(Color.FromRgb(52, 56, 54), 0));
                metro.GradientStops.Add(new GradientStop(Color.FromRgb(22, 25, 24), 0.58));
                metro.GradientStops.Add(new GradientStop(Color.FromRgb(7, 9, 8), 1));
                return metro;
            }
            if (definition.Shell == "Switch")
            {
                LinearGradientBrush s = new LinearGradientBrush(Color.FromRgb(43, 44, 48), Color.FromRgb(66, 67, 72), 90);
                return s;
            }
            LinearGradientBrush brush = new LinearGradientBrush();
            brush.StartPoint = new Point(0, 0);
            brush.EndPoint = new Point(1, 1);
            brush.GradientStops.Add(new GradientStop(definition.ColorA, 0));
            brush.GradientStops.Add(new GradientStop(definition.ColorB, 1));
            return brush;
        }

        private Grid BuildHeader()
        {
            Grid header = new Grid { Margin = new Thickness(34, 14, 34, 0) };
            header.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(10) });
            header.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
            Border accent = new Border { Background = new SolidColorBrush(definition.Accent), CornerRadius = new CornerRadius(5), Margin = new Thickness(0, 4, 0, 4) };
            header.Children.Add(accent);
            StackPanel words = new StackPanel { Margin = new Thickness(18, 0, 0, 0), VerticalAlignment = VerticalAlignment.Center };
            TextBlock name = new TextBlock { Text = definition.DisplayName, FontSize = 30, FontWeight = FontWeights.SemiBold };
            name.Foreground = IsLightShell() ? new SolidColorBrush(Color.FromRgb(49, 61, 67)) : Brushes.White;
            string shellLabel = definition.Shell == "Xbox360" ? settings.dashboardStyle.ToUpperInvariant() + " DASHBOARD" : definition.Subtitle.ToUpperInvariant();
            TextBlock tag = new TextBlock { Text = shellLabel + "  •  " + definition.PrimaryBackend.ToUpperInvariant(), FontSize = 11, Margin = new Thickness(1, 1, 0, 0) };
            tag.Foreground = IsLightShell() ? new SolidColorBrush(Color.FromRgb(93, 112, 120)) : new SolidColorBrush(Color.FromRgb(185, 196, 210));
            words.Children.Add(name); words.Children.Add(tag);
            Grid.SetColumn(words, 1); header.Children.Add(words);
            TextBlock clock = new TextBlock { Text = DateTime.Now.ToString("ddd  MMM d    h:mm tt", CultureInfo.CurrentCulture), FontSize = 13, HorizontalAlignment = HorizontalAlignment.Right, VerticalAlignment = VerticalAlignment.Center };
            clock.Foreground = name.Foreground;
            Grid.SetColumn(clock, 1); header.Children.Add(clock);
            return header;
        }

        private void BuildChrome()
        {
            Panel oldContentParent = contentHost.Parent as Panel;
            if (oldContentParent != null) oldContentParent.Children.Remove(contentHost);
            Panel oldTitleParent = titleText.Parent as Panel;
            if (oldTitleParent != null) oldTitleParent.Children.Remove(titleText);
            Panel oldSubtitleParent = subtitleText.Parent as Panel;
            if (oldSubtitleParent != null) oldSubtitleParent.Children.Remove(subtitleText);
            chrome.Children.Clear();
            chrome.RowDefinitions.Clear(); chrome.ColumnDefinitions.Clear();
            navButtons.Clear(); navigation.Children.Clear();
            if (definition.Shell == "Xbox") { BuildXboxChrome(); return; }
            if (definition.Shell == "Xbox360") { BuildXbox360Chrome(); return; }

            // N64, GameCube, Wii, Wii U and Switch no longer inherit a fake common
            // tab strip. Their real systems used fundamentally different spatial
            // menus, so the entire center surface belongs to that system renderer.
            Border content = BuildAuthenticConsoleFrame();
            chrome.Children.Add(content);
        }

        private Border BuildAuthenticConsoleFrame()
        {
            Border frame = new Border { Margin = new Thickness(18, 16, 18, 8), Padding = new Thickness(20), BorderThickness = new Thickness(0), Background = Brushes.Transparent };
            Grid inner = new Grid();
            inner.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
            inner.RowDefinitions.Add(new RowDefinition { Height = new GridLength(1, GridUnitType.Star) });
            StackPanel heading = new StackPanel { Margin = new Thickness(10, 0, 10, 8) };
            titleText.FontSize = definition.Shell == "GameCube" ? 30 : 28;
            titleText.FontWeight = FontWeights.Light;
            titleText.Foreground = IsLightShell() ? new SolidColorBrush(Color.FromRgb(61, 74, 80)) : Brushes.White;
            subtitleText.FontSize = 12; subtitleText.Margin = new Thickness(1, 2, 0, 8); subtitleText.TextWrapping = TextWrapping.Wrap;
            subtitleText.Foreground = IsLightShell() ? new SolidColorBrush(Color.FromRgb(100, 115, 121)) : new SolidColorBrush(Color.FromArgb(210, 255, 255, 255));
            heading.Children.Add(titleText); heading.Children.Add(subtitleText); inner.Children.Add(heading);
            Grid.SetRow(contentHost, 1); inner.Children.Add(contentHost); frame.Child = inner; return frame;
        }

        private void BuildXboxChrome()
        {
            chrome.RowDefinitions.Clear(); chrome.ColumnDefinitions.Clear();
            chrome.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(535) });
            chrome.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });

            Grid scene = new Grid { Margin = new Thickness(0, 0, 0, 0), ClipToBounds = true };
            Canvas canvas = new Canvas { Width = 535, Height = 790, HorizontalAlignment = HorizontalAlignment.Center, VerticalAlignment = VerticalAlignment.Center };

            // Recreate the original dashboard's large green jewel and layered
            // elliptical energy rings with primitives; no Microsoft dashboard code
            // or extracted dashboard assets are used.
            for (int ring = 0; ring < 9; ring++)
            {
                double width = 500 - ring * 42; double height = 430 - ring * 33;
                System.Windows.Shapes.Ellipse ellipse = new System.Windows.Shapes.Ellipse();
                ellipse.Width = width; ellipse.Height = height;
                ellipse.Stroke = new SolidColorBrush(Color.FromArgb((byte)Math.Max(28, 180 - ring * 17), 107, 235, 54));
                ellipse.StrokeThickness = ring < 2 ? 5 : 2;
                ellipse.RenderTransform = new RotateTransform(-16 + ring * 3.4);
                Canvas.SetLeft(ellipse, 4 + ring * 20); Canvas.SetTop(ellipse, 135 + ring * 15); canvas.Children.Add(ellipse);
            }
            System.Windows.Shapes.Ellipse jewel = new System.Windows.Shapes.Ellipse { Width = 276, Height = 276, StrokeThickness = 5 };
            RadialGradientBrush jewelFill = new RadialGradientBrush(); jewelFill.Center = new Point(0.36, 0.30); jewelFill.GradientOrigin = new Point(0.28, 0.22);
            jewelFill.GradientStops.Add(new GradientStop(Color.FromRgb(198, 255, 157), 0)); jewelFill.GradientStops.Add(new GradientStop(Color.FromRgb(67, 198, 24), 0.40)); jewelFill.GradientStops.Add(new GradientStop(Color.FromRgb(0, 29, 0), 1));
            jewel.Fill = jewelFill; jewel.Stroke = new SolidColorBrush(Color.FromRgb(129, 244, 75));
            jewel.Effect = new System.Windows.Media.Effects.DropShadowEffect { Color = Color.FromRgb(80, 255, 31), BlurRadius = 45, ShadowDepth = 0, Opacity = 0.72 };
            Canvas.SetLeft(jewel, 98); Canvas.SetTop(jewel, 218); canvas.Children.Add(jewel);
            System.Windows.Shapes.Polygon xmark = new System.Windows.Shapes.Polygon();
            xmark.Points = new PointCollection(new Point[] { new Point(161, 290), new Point(220, 326), new Point(302, 270), new Point(257, 357), new Point(319, 408), new Point(238, 375), new Point(156, 431), new Point(200, 346) });
            xmark.Fill = new LinearGradientBrush(Color.FromRgb(224, 255, 205), Color.FromRgb(53, 179, 18), 90);
            xmark.Effect = new System.Windows.Media.Effects.DropShadowEffect { Color = Color.FromRgb(62, 255, 23), BlurRadius = 18, ShadowDepth = 0, Opacity = 0.9 }; canvas.Children.Add(xmark);
            TextBlock xbox = new TextBlock { Text = "XBOX", FontSize = 58, FontWeight = FontWeights.Bold, FontStyle = FontStyles.Italic, Foreground = Brushes.White };
            xbox.Effect = new System.Windows.Media.Effects.DropShadowEffect { Color = Color.FromRgb(66, 255, 27), BlurRadius = 12, ShadowDepth = 0, Opacity = 0.8 }; Canvas.SetLeft(xbox, 152); Canvas.SetTop(xbox, 498); canvas.Children.Add(xbox);
            scene.Children.Add(canvas);

            navigation.Orientation = Orientation.Vertical; navigation.HorizontalAlignment = HorizontalAlignment.Right; navigation.VerticalAlignment = VerticalAlignment.Center;
            navigation.Margin = new Thickness(0, 185, 0, 0); scene.Children.Add(navigation); chrome.Children.Add(scene);

            Border frame = BuildXboxContentFrame(); Grid.SetColumn(frame, 1); chrome.Children.Add(frame);
            AddNav("play game", 0); AddNav("memory", 1); AddNav("music", 2); AddNav("xbox live", 3); AddNav("settings", 4);
            UpdateNavigation();
        }

        private void BuildXbox360Chrome()
        {
            chrome.RowDefinitions.Clear(); chrome.ColumnDefinitions.Clear();
            navButtons.Clear(); navigation.Children.Clear();
            if (IsBlades())
            {
                string[] labels = new string[] { "xbox live", "games", "media", "system" };
                Color[] colors = new Color[] { Color.FromRgb(226, 111, 16), Color.FromRgb(83, 156, 44), Color.FromRgb(48, 119, 180), Color.FromRgb(105, 76, 150) };

                // 2005-style Blades: the blade edges stay as a compact silver stack
                // at the left while one colored blade owns the content surface.
                for (int i = 0; i < labels.Length; i++) chrome.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(i == page ? 72 : 58) });
                chrome.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
                for (int i = 0; i < labels.Length; i++)
                {
                    Button tab = CreateBladeTab(labels[i], i, colors[i], i == page);
                    Grid.SetColumn(tab, i); chrome.Children.Add(tab); navButtons.Add(tab);
                }
                Border active = BuildXbox360ContentFrame(); Grid.SetColumn(active, labels.Length); chrome.Children.Add(active);

                Border gamertag = new Border
                {
                    Height = 48, HorizontalAlignment = HorizontalAlignment.Right, VerticalAlignment = VerticalAlignment.Top,
                    Margin = new Thickness(0, 32, 54, 0), Padding = new Thickness(14, 6, 14, 6),
                    Background = new LinearGradientBrush(Color.FromArgb(220, 246, 247, 246), Color.FromArgb(220, 176, 181, 178), 90),
                    BorderBrush = new SolidColorBrush(Color.FromArgb(220, 255, 255, 255)), BorderThickness = new Thickness(2), CornerRadius = new CornerRadius(5)
                };
                StackPanel gamer = new StackPanel { Orientation = Orientation.Horizontal };
                Border gamerPicture = new Border { Width = 34, Height = 34, Background = new SolidColorBrush(colors[Math.Max(0, Math.Min(page, colors.Length - 1))]), BorderBrush = Brushes.White, BorderThickness = new Thickness(1), Margin = new Thickness(0, 0, 9, 0) };
                gamerPicture.Child = new TextBlock { Text = "X", FontSize = 19, FontWeight = FontWeights.Bold, Foreground = Brushes.White, HorizontalAlignment = HorizontalAlignment.Center, VerticalAlignment = VerticalAlignment.Center };
                gamer.Children.Add(gamerPicture);
                StackPanel gamerWords = new StackPanel { VerticalAlignment = VerticalAlignment.Center };
                gamerWords.Children.Add(new TextBlock { Text = Environment.UserName, FontSize = 14, FontWeight = FontWeights.SemiBold, Foreground = new SolidColorBrush(Color.FromRgb(48, 53, 50)) });
                gamerWords.Children.Add(new TextBlock { Text = GetXboxGamerscore().ToString(CultureInfo.InvariantCulture) + " Gamerscore", FontSize = 11, Foreground = new SolidColorBrush(Color.FromRgb(80, 87, 83)) });
                gamer.Children.Add(gamerWords); gamertag.Child = gamer; Grid.SetColumn(gamertag, labels.Length); chrome.Children.Add(gamertag);
            }
            else
            {
                chrome.RowDefinitions.Add(new RowDefinition { Height = new GridLength(94) });
                chrome.RowDefinitions.Add(new RowDefinition { Height = new GridLength(1, GridUnitType.Star) });
                Grid top = new Grid { Margin = new Thickness(48, 14, 48, 0) };
                top.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) }); top.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
                navigation.Orientation = Orientation.Horizontal; navigation.HorizontalAlignment = HorizontalAlignment.Left; navigation.VerticalAlignment = VerticalAlignment.Center; top.Children.Add(navigation);
                StackPanel profile = new StackPanel { Orientation = Orientation.Horizontal, HorizontalAlignment = HorizontalAlignment.Right, VerticalAlignment = VerticalAlignment.Center };
                StackPanel gamerWords = new StackPanel { VerticalAlignment = VerticalAlignment.Center, Margin = new Thickness(0, 0, 12, 0) };
                gamerWords.Children.Add(new TextBlock { Text = Environment.UserName, FontSize = 17, FontWeight = FontWeights.SemiBold, Foreground = Brushes.White, HorizontalAlignment = HorizontalAlignment.Right });
                gamerWords.Children.Add(new TextBlock { Text = GetXboxGamerscore().ToString(CultureInfo.InvariantCulture) + " G", FontSize = 12, Foreground = new SolidColorBrush(Color.FromRgb(185, 203, 190)), HorizontalAlignment = HorizontalAlignment.Right });
                profile.Children.Add(gamerWords); Border gamer = new Border { Width = 48, Height = 48, Background = new SolidColorBrush(Color.FromRgb(107, 181, 43)), BorderBrush = Brushes.White, BorderThickness = new Thickness(2) }; gamer.Child = new TextBlock { Text = "X", FontSize = 27, FontWeight = FontWeights.Bold, Foreground = Brushes.White, HorizontalAlignment = HorizontalAlignment.Center, VerticalAlignment = VerticalAlignment.Center }; profile.Children.Add(gamer);
                Grid.SetColumn(profile, 1); top.Children.Add(profile); chrome.Children.Add(top);
                Border frame = BuildXbox360ContentFrame(); Grid.SetRow(frame, 1); chrome.Children.Add(frame);
                AddNav("home", 0); AddNav("social", 1); AddNav("games", 2); AddNav("video", 3); AddNav("music", 4); AddNav("apps", 5); AddNav("settings", 6);
            }
            UpdateNavigation();
        }

        private Button CreateBladeTab(string label, int index, Color color, bool active)
        {
            Button tab = new Button
            {
                Tag = index, Margin = new Thickness(-1, 22, -1, 22), Padding = new Thickness(3),
                BorderThickness = new Thickness(2), BorderBrush = new SolidColorBrush(Color.FromArgb(225, 255, 255, 255)),
                HorizontalContentAlignment = HorizontalAlignment.Center, VerticalContentAlignment = VerticalAlignment.Center,
                RenderTransformOrigin = new Point(0.5, 0.5)
            };
            tab.Template = (ControlTemplate)System.Windows.Markup.XamlReader.Parse(@"<ControlTemplate xmlns=""http://schemas.microsoft.com/winfx/2006/xaml/presentation"" TargetType=""Button""><Border Background=""{TemplateBinding Background}"" BorderBrush=""{TemplateBinding BorderBrush}"" BorderThickness=""{TemplateBinding BorderThickness}"" CornerRadius=""10,2,2,10""><ContentPresenter HorizontalAlignment=""Center"" VerticalAlignment=""Center""/></Border></ControlTemplate>");
            LinearGradientBrush fill = new LinearGradientBrush(); fill.StartPoint = new Point(0, 0); fill.EndPoint = new Point(1, 0);
            if (active)
            {
                fill.GradientStops.Add(new GradientStop(Color.FromRgb((byte)Math.Min(255, color.R + 48), (byte)Math.Min(255, color.G + 48), (byte)Math.Min(255, color.B + 48)), 0));
                fill.GradientStops.Add(new GradientStop(color, 0.52));
                fill.GradientStops.Add(new GradientStop(Color.FromRgb((byte)(color.R * 0.62), (byte)(color.G * 0.62), (byte)(color.B * 0.62)), 1));
            }
            else
            {
                fill.GradientStops.Add(new GradientStop(Color.FromRgb(252, 252, 252), 0));
                fill.GradientStops.Add(new GradientStop(Color.FromRgb(207, 210, 208), 0.55));
                fill.GradientStops.Add(new GradientStop(Color.FromRgb(126, 131, 128), 1));
            }
            tab.Background = fill;
            Grid content = new Grid();
            Border stripe = new Border { Width = 7, HorizontalAlignment = HorizontalAlignment.Right, Background = new SolidColorBrush(color), Opacity = active ? 1.0 : 0.72 }; content.Children.Add(stripe);
            TextBlock text = new TextBlock { Text = label, FontSize = active ? 18 : 16, FontWeight = FontWeights.SemiBold, Foreground = active ? Brushes.White : new SolidColorBrush(Color.FromRgb(77, 82, 79)), HorizontalAlignment = HorizontalAlignment.Center, VerticalAlignment = VerticalAlignment.Center };
            text.LayoutTransform = new RotateTransform(-90); content.Children.Add(text); tab.Content = content;
            tab.Click += delegate { page = (int)tab.Tag; dashboardSubpage = String.Empty; selected = 0; input.Reset(); inputGuardUntilUtc = DateTime.UtcNow.AddMilliseconds(420); BuildChrome(); RenderPage(); };
            return tab;
        }


        private Border BuildXboxContentFrame()
        {
            Border frame = new Border
            {
                Margin = new Thickness(0, 46, 38, 34), Padding = new Thickness(44, 32, 36, 30),
                CornerRadius = new CornerRadius(58, 12, 12, 58),
                Background = new LinearGradientBrush(Color.FromArgb(232, 0, 10, 0), Color.FromArgb(244, 0, 39, 1), 0),
                BorderBrush = new SolidColorBrush(Color.FromArgb(220, 114, 238, 58)), BorderThickness = new Thickness(3)
            };
            Grid inner = BuildDashboardContentInner(Brushes.White, new SolidColorBrush(Color.FromRgb(156, 221, 126)));
            frame.Child = inner; return frame;
        }

        private Border BuildXbox360ContentFrame()
        {
            Border frame = new Border();
            if (IsBlades())
            {
                Color[] colors = new Color[] { Color.FromRgb(226, 111, 16), Color.FromRgb(83, 156, 44), Color.FromRgb(48, 119, 180), Color.FromRgb(105, 76, 150) };
                Color blade = colors[Math.Max(0, Math.Min(page, colors.Length - 1))];
                frame.Margin = new Thickness(-4, 22, 34, 22); frame.Padding = new Thickness(42, 58, 38, 24); frame.CornerRadius = new CornerRadius(12, 4, 4, 12); frame.BorderThickness = new Thickness(6, 3, 4, 3);
                frame.BorderBrush = new LinearGradientBrush(Color.FromRgb(255, 255, 255), Color.FromRgb(112, 117, 114), 90);
                LinearGradientBrush fill = new LinearGradientBrush(); fill.StartPoint = new Point(0, 0); fill.EndPoint = new Point(1, 1);
                fill.GradientStops.Add(new GradientStop(Color.FromRgb((byte)Math.Min(255, blade.R + 44), (byte)Math.Min(255, blade.G + 44), (byte)Math.Min(255, blade.B + 44)), 0));
                fill.GradientStops.Add(new GradientStop(blade, 0.40)); fill.GradientStops.Add(new GradientStop(Color.FromRgb((byte)(blade.R / 2), (byte)(blade.G / 2), (byte)(blade.B / 2)), 1)); frame.Background = fill;
            }
            else
            {
                frame.Margin = new Thickness(48, 0, 48, 28); frame.Padding = new Thickness(0, 12, 0, 18); frame.CornerRadius = new CornerRadius(0); frame.BorderThickness = new Thickness(0); frame.Background = Brushes.Transparent;
            }
            frame.Child = BuildDashboardContentInner(Brushes.White, new SolidColorBrush(Color.FromArgb(230, 255, 255, 255))); return frame;
        }


        private Grid BuildDashboardContentInner(Brush titleBrush, Brush subtitleBrush)
        {
            Grid inner = new Grid(); inner.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto }); inner.RowDefinitions.Add(new RowDefinition { Height = new GridLength(1, GridUnitType.Star) });
            StackPanel title = new StackPanel { Margin = new Thickness(4, 0, 4, 6) };
            titleText.FontSize = definition.Shell == "Xbox" ? 37 : (IsMetro() ? 34 : 32); titleText.FontWeight = FontWeights.Light; titleText.Foreground = titleBrush;
            subtitleText.FontSize = 13; subtitleText.Margin = new Thickness(1, 3, 0, 14); subtitleText.TextWrapping = TextWrapping.Wrap; subtitleText.Foreground = subtitleBrush;
            title.Children.Add(titleText); title.Children.Add(subtitleText); inner.Children.Add(title);
            Grid.SetRow(contentHost, 1); inner.Children.Add(contentHost); return inner;
        }

        private Border BuildContentFrame()
        {
            Border frame = new Border();
            frame.Margin = new Thickness(16, 6, 32, 18);
            frame.Padding = new Thickness(32, 22, 32, 22);
            if (definition.Shell == "N64")
            {
                frame.CornerRadius = new CornerRadius(2); frame.Background = new SolidColorBrush(Color.FromArgb(218, 13, 14, 22)); frame.BorderBrush = new SolidColorBrush(Color.FromRgb(241, 194, 38)); frame.BorderThickness = new Thickness(3);
            }
            else if (definition.Shell == "GameCube")
            {
                frame.CornerRadius = new CornerRadius(42); frame.Background = new SolidColorBrush(Color.FromArgb(210, 31, 22, 73)); frame.BorderBrush = new SolidColorBrush(Color.FromRgb(143, 118, 255)); frame.BorderThickness = new Thickness(3);
            }
            else if (definition.Shell == "Wii" || definition.Shell == "WiiU")
            {
                frame.CornerRadius = new CornerRadius(26); frame.Background = new SolidColorBrush(Color.FromArgb(246, 255, 255, 255)); frame.BorderBrush = new SolidColorBrush(Color.FromRgb(151, 203, 220)); frame.BorderThickness = new Thickness(2);
            }
            else if (definition.Shell == "Switch")
            {
                frame.CornerRadius = new CornerRadius(0); frame.Background = new SolidColorBrush(Color.FromRgb(45, 46, 50)); frame.BorderBrush = new SolidColorBrush(Color.FromRgb(90, 91, 96)); frame.BorderThickness = new Thickness(1);
            }
            else if (definition.Shell == "Xbox")
            {
                frame.CornerRadius = new CornerRadius(55); frame.Background = new SolidColorBrush(Color.FromArgb(220, 0, 18, 0)); frame.BorderBrush = new SolidColorBrush(Color.FromRgb(79, 190, 27)); frame.BorderThickness = new Thickness(3);
            }
            else if (definition.Shell == "Xbox360" && String.Equals(settings.dashboardStyle, "Metro", StringComparison.OrdinalIgnoreCase))
            {
                frame.CornerRadius = new CornerRadius(0); frame.Background = new SolidColorBrush(Color.FromArgb(235, 22, 25, 24)); frame.BorderBrush = new SolidColorBrush(Color.FromRgb(107, 181, 43)); frame.BorderThickness = new Thickness(1);
            }
            else
            {
                frame.CornerRadius = new CornerRadius(12); frame.Background = IsLightShell() ? new SolidColorBrush(Color.FromArgb(240, 255, 255, 255)) : new SolidColorBrush(Color.FromArgb(195, 4, 8, 11)); frame.BorderBrush = IsLightShell() ? new SolidColorBrush(Color.FromRgb(171, 197, 207)) : new SolidColorBrush(Color.FromArgb(70, 255, 255, 255)); frame.BorderThickness = new Thickness(1);
            }
            Grid inner = new Grid(); inner.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto }); inner.RowDefinitions.Add(new RowDefinition { Height = new GridLength(1, GridUnitType.Star) });
            StackPanel title = new StackPanel { Margin = new Thickness(8, 0, 8, 4) };
            titleText.FontSize = definition.Shell == "GameCube" ? 34 : 29; titleText.FontWeight = FontWeights.Bold;
            titleText.Foreground = IsLightShell() ? new SolidColorBrush(Color.FromRgb(48, 62, 68)) : Brushes.White;
            subtitleText.FontSize = 13; subtitleText.Margin = new Thickness(0, 3, 0, 14); subtitleText.TextWrapping = TextWrapping.Wrap;
            subtitleText.Foreground = IsLightShell() ? new SolidColorBrush(Color.FromRgb(88, 107, 114)) : new SolidColorBrush(Color.FromRgb(190, 203, 217));
            title.Children.Add(titleText); title.Children.Add(subtitleText); inner.Children.Add(title);
            Grid.SetRow(contentHost, 1); inner.Children.Add(contentHost); frame.Child = inner; return frame;
        }

        private void AddNav(string text, int index)
        {
            Button button = new Button(); button.Tag = index; button.FontWeight = FontWeights.Bold; button.Cursor = Cursors.Hand; button.RenderTransformOrigin = new Point(0.5, 0.5);
            button.Template = (ControlTemplate)System.Windows.Markup.XamlReader.Parse(@"<ControlTemplate xmlns=""http://schemas.microsoft.com/winfx/2006/xaml/presentation"" TargetType=""Button""><Border Background=""{TemplateBinding Background}"" BorderBrush=""{TemplateBinding BorderBrush}"" BorderThickness=""{TemplateBinding BorderThickness}"" CornerRadius=""12""><ContentPresenter HorizontalAlignment=""{TemplateBinding HorizontalContentAlignment}"" VerticalAlignment=""{TemplateBinding VerticalContentAlignment}"" Margin=""{TemplateBinding Padding}""/></Border></ControlTemplate>");
            if (definition.Shell == "Xbox")
            {
                button.Template = (ControlTemplate)System.Windows.Markup.XamlReader.Parse(@"<ControlTemplate xmlns=""http://schemas.microsoft.com/winfx/2006/xaml/presentation"" TargetType=""Button""><Border Background=""{TemplateBinding Background}"" BorderBrush=""{TemplateBinding BorderBrush}"" BorderThickness=""{TemplateBinding BorderThickness}"" CornerRadius=""3""><ContentPresenter HorizontalAlignment=""{TemplateBinding HorizontalContentAlignment}"" VerticalAlignment=""{TemplateBinding VerticalContentAlignment}"" Margin=""{TemplateBinding Padding}""/></Border></ControlTemplate>");
                Grid nav = new Grid(); nav.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(38) }); nav.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
                Border node = new Border { Width = 20, Height = 20, CornerRadius = new CornerRadius(10), HorizontalAlignment = HorizontalAlignment.Center, VerticalAlignment = VerticalAlignment.Center, Background = new RadialGradientBrush(Color.FromRgb(173, 255, 125), Color.FromRgb(20, 96, 5)), BorderBrush = new SolidColorBrush(Color.FromRgb(191, 255, 158)), BorderThickness = new Thickness(1) };
                nav.Children.Add(node); TextBlock label = new TextBlock { Text = text, FontSize = 24, FontWeight = FontWeights.Bold, Foreground = Brushes.White, VerticalAlignment = VerticalAlignment.Center }; Grid.SetColumn(label, 1); nav.Children.Add(label); button.Content = nav;
                button.Height = 54; button.Width = 318; button.HorizontalContentAlignment = HorizontalAlignment.Stretch; button.VerticalContentAlignment = VerticalAlignment.Center;
                button.Margin = new Thickness(0, 3, 0, 3); button.Padding = new Thickness(7, 2, 12, 2); button.BorderThickness = new Thickness(1);
            }
            else if (IsBlades())
            {
                TextBlock bladeText = new TextBlock { Text = text.ToUpperInvariant(), FontSize = 23, FontWeight = FontWeights.Bold, Foreground = Brushes.White, HorizontalAlignment = HorizontalAlignment.Center, VerticalAlignment = VerticalAlignment.Center };
                bladeText.LayoutTransform = new RotateTransform(-90); button.Content = bladeText;
                button.Width = 86; button.Height = 700; button.Margin = new Thickness(-8, 0, -8, 0); button.Padding = new Thickness(8); button.BorderThickness = new Thickness(3);
                button.HorizontalContentAlignment = HorizontalAlignment.Center; button.VerticalContentAlignment = VerticalAlignment.Center;
            }
            else if (IsMetro())
            {
                button.Content = new TextBlock { Text = text, FontSize = 19, FontWeight = FontWeights.Normal, Foreground = Brushes.White };
                button.Height = 54; button.MinWidth = 82; button.Margin = new Thickness(0, 0, 24, 0); button.Padding = new Thickness(3, 5, 3, 5);
                button.Background = Brushes.Transparent; button.BorderThickness = new Thickness(0, 0, 0, 4); button.HorizontalContentAlignment = HorizontalAlignment.Center;
            }
            else
            {
                button.Content = text; button.FontSize = definition.Shell == "GameCube" ? 19 : 17; button.Height = definition.Shell == "Wii" || definition.Shell == "WiiU" || definition.Shell == "Switch" ? 50 : 64; button.MinWidth = definition.Shell == "Switch" ? 190 : 150;
                button.Margin = navigation.Orientation == Orientation.Horizontal ? new Thickness(6, 0, 6, 0) : new Thickness(0, 0, 0, 10); button.Padding = new Thickness(14, 6, 14, 6); button.BorderThickness = new Thickness(2);
            }
            button.Click += delegate { page = (int)button.Tag; selected = 0; if (IsBlades()) BuildChrome(); RenderPage(); };
            navigation.Children.Add(button); navButtons.Add(button);
        }

        private void UpdateNavigation()
        {
            Color[] bladeColors = new Color[] { Color.FromRgb(232, 116, 18), Color.FromRgb(87, 156, 46), Color.FromRgb(56, 126, 183), Color.FromRgb(103, 76, 151) };
            for (int i = 0; i < navButtons.Count; i++)
            {
                bool active = (int)navButtons[i].Tag == page; Button button = navButtons[i];
                if (definition.Shell == "Xbox")
                {
                    button.Background = new LinearGradientBrush(active ? Color.FromArgb(245, 123, 231, 57) : Color.FromArgb(158, 0, 52, 3), active ? Color.FromArgb(245, 26, 111, 5) : Color.FromArgb(172, 0, 20, 0), 0);
                    button.BorderBrush = new SolidColorBrush(active ? Color.FromRgb(214, 255, 187) : Color.FromArgb(105, 101, 218, 61));
                    button.RenderTransform = active ? new TranslateTransform(-18, 0) : Transform.Identity;
                    button.Opacity = active ? 1.0 : 0.82;
                }
                else if (IsBlades())
                {
                    Color color = bladeColors[Math.Min(i, bladeColors.Length - 1)];
                    button.BorderBrush = new SolidColorBrush(active ? Colors.White : Color.FromArgb(150, 255, 255, 255));
                    button.Opacity = active ? 1.0 : 0.94; button.RenderTransform = active ? new ScaleTransform(1.01, 1.01) : Transform.Identity;
                }
                else if (IsMetro())
                {
                    button.Background = Brushes.Transparent; button.BorderBrush = new SolidColorBrush(active ? Color.FromRgb(107, 181, 43) : Colors.Transparent);
                    button.Opacity = active ? 1.0 : 0.68; button.RenderTransform = active ? new ScaleTransform(1.05, 1.05) : Transform.Identity;
                }
                else
                {
                    button.Background = new SolidColorBrush(active ? definition.Accent : (IsLightShell() ? Color.FromArgb(155, 236, 243, 246) : Color.FromArgb(80, 0, 0, 0)));
                    button.Foreground = new SolidColorBrush(active && (definition.Shell == "Wii" || definition.Shell == "WiiU") ? Colors.White : (IsLightShell() ? Color.FromRgb(49, 62, 68) : Colors.White));
                    button.BorderBrush = new SolidColorBrush(active ? definition.Accent : Color.FromArgb(45, 255, 255, 255));
                }
            }
        }

        private void OnSourceInitialized(object sender, EventArgs e)
        {
            try
            {
                source = HwndSource.FromHwnd(new WindowInteropHelper(this).Handle);
                hook = RawHook;
                if (source != null) source.AddHook(hook);
                HuymaierConsole.Native.RawHidController.Register(new WindowInteropHelper(this).Handle);
            }
            catch { }
        }

        private IntPtr RawHook(IntPtr hwnd, int msg, IntPtr wParam, IntPtr lParam, ref bool handled)
        {
            if (msg == 0x00FF) { try { HuymaierConsole.Native.RawHidController.ProcessInput(lParam); } catch { } }
            else if (msg == 0x00FE)
            {
                try { HuymaierConsole.Native.RawHidController.ProcessDeviceChange(wParam, lParam); NativeConsoleNavigation.NotifyDeviceChange(); inputGuardUntilUtc = DateTime.UtcNow.AddMilliseconds(750); } catch { }
            }
            handled = false;
            return IntPtr.Zero;
        }

        private void OnLoaded(object sender, RoutedEventArgs e)
        {
            WritePlatformLog("Opened native emulator platform interface: " + definition.DisplayName + (definition.Shell == "Xbox360" ? " (" + settings.dashboardStyle + ")" : String.Empty), "INFO");
            CalculateColumns();
            inputGuardUntilUtc = DateTime.UtcNow.AddMilliseconds(350);
            inputTimer.Start();
            // Keep startup immediate by rendering the cache first, then reconcile the
            // configured game folders on a worker so newly added/removed titles appear
            // without requiring a manual Refresh Library command.
            QueueLibraryRefresh();
            if (IsXboxFamily()) QueueXboxArtworkRefresh();
            string startup = Path.Combine(platformRoot, "Assets", "Startup.mp4");
            if (settings.startupEnabled) startupOverlay.Play(startup, settings.startupVolume, StartAmbience);
            else StartAmbience();
        }

        private void OnClosing(object sender, System.ComponentModel.CancelEventArgs e)
        {
            if (closing) return;
            closing = true;
            asyncGeneration++;
            xboxArtworkScanRunning = false;
            xboxAchievementScanRunning = false;
            try { inputTimer.Stop(); } catch { }
            try { input.Reset(); } catch { }
            WritePlatformLog("Closing native emulator platform interface: " + definition.DisplayName + (definition.Shell == "Xbox360" ? " (" + settings.dashboardStyle + ")" : String.Empty), "INFO");
        }

        private void OnClosed(object sender, EventArgs e)
        {
            try { Dispatcher.UnhandledException -= DispatcherUnhandledException; } catch { }
            try { inputTimer.Stop(); } catch { }
            try { startupOverlay.Stop(); } catch { }
            try { effectPlayer.Stop(); effectPlayer.Close(); } catch { }
            try { ambiencePlayer.Stop(); ambiencePlayer.Close(); } catch { }
            try { if (source != null && hook != null) source.RemoveHook(hook); } catch { }
            settings.Save(settingsPath);
            NativeWindowActivation.Restore(Owner);
        }

        private void DispatcherUnhandledException(object sender, System.Windows.Threading.DispatcherUnhandledExceptionEventArgs e)
        {
            try { WritePlatformLog(definition.DisplayName + " dashboard dispatcher recovered from an unhandled error: " + e.Exception, "ERROR"); } catch { }
            e.Handled = true;
            if (closing) return;
            // A dashboard render/input failure should never terminate the shared Huymaier Console process.
            // Return to the parent Console view after recording the exact stack trace.
            try
            {
                closing = true;
                asyncGeneration++;
                xboxArtworkScanRunning = false;
                xboxAchievementScanRunning = false;
                inputTimer.Stop();
                Dispatcher.BeginInvoke(System.Windows.Threading.DispatcherPriority.Background, new Action(delegate { try { Close(); } catch { } }));
            }
            catch { try { Close(); } catch { } }
        }

        private bool CanApplyAsync(int generation)
        {
            return !closing && generation == asyncGeneration && IsLoaded && !Dispatcher.HasShutdownStarted && !Dispatcher.HasShutdownFinished;
        }

        private void StartAmbience()
        {
            try
            {
                ambiencePlayer.Stop(); ambiencePlayer.Close();
                if (!settings.ambienceEnabled || String.IsNullOrWhiteSpace(settings.ambiencePath) || !File.Exists(settings.ambiencePath)) return;
                ambiencePlayer.Open(new Uri(settings.ambiencePath));
                ambiencePlayer.Volume = settings.ambienceVolume;
                ambiencePlayer.Play();
            }
            catch { }
        }

        private void InputTick(object sender, EventArgs e)
        {
            if (closing || !IsActive || DateTime.UtcNow < inputGuardUntilUtc || activeProcess != null) return;
            try
            {
                XmbInputCommand command = input.Poll();
                if (command == XmbInputCommand.None) { UpdateNotice(); return; }
                ProcessCommand(command);
                UpdateNotice();
            }
            catch (Exception ex)
            {
                WritePlatformLog(definition.DisplayName + " input/render command recovered: " + ex, "ERROR");
            }
        }

        private void ProcessCommand(XmbInputCommand command)
        {
            if (command == XmbInputCommand.Menu) { HuymaierConsole.NativeApp.NativeQuickAccessRequest.Request(); try { Close(); } catch { } return; }
            if (startupOverlay.IsActive)
            {
                if (command == XmbInputCommand.Confirm || command == XmbInputCommand.Back) startupOverlay.Skip();
                return;
            }
            if (dashboardGuideVisible)
            {
                if (command == XmbInputCommand.Back || command == XmbInputCommand.Confirm) ToggleDashboardGuide();
                return;
            }

            // Shoulder buttons are never section/page selectors in Huymaier native
            // console surfaces. Keep them unbound here so controller behavior stays
            // consistent with the main console and the PlayStation interfaces.
            if (command == XmbInputCommand.LeftShoulder || command == XmbInputCommand.RightShoulder) return;

            if (IsGameCubeHub()) { ProcessGameCubeHubCommand(command); return; }
            if (IsXboxRoot()) { ProcessXboxRootCommand(command); return; }
            if (definition.Shell == "Switch" && IsRootConsoleSurface()) { ProcessSwitchHomeCommand(command); return; }
            if (definition.Shell == "Xbox360" && IsMetro() && IsRootConsoleSurface() && ProcessMetroNavigationCommand(command)) return;
            if (definition.Shell == "Xbox360" && IsBlades() && IsRootConsoleSurface() && (command == XmbInputCommand.Left || command == XmbInputCommand.Right))
            {
                SwitchPage(command == XmbInputCommand.Left ? -1 : 1); return;
            }
            if (definition.Shell == "Wii" && IsRootConsoleSurface() && ProcessWiiPageEdge(command)) return;
            if (definition.Shell == "WiiU" && IsRootConsoleSurface() && ProcessWiiUPageEdge(command)) return;

            if (command == XmbInputCommand.Back)
            {
                PlayEffect("Back.wav");
                if (!String.IsNullOrWhiteSpace(dashboardSubpage))
                {
                    if (dashboardSubpage == "wii-start") { dashboardSubpage = String.Empty; shellSelectedGame = null; selected = 0; RenderPage(); return; }
                    dashboardSubpage = String.Empty; selectedXboxSave = null; shellSelectedGame = null; selected = 0; chromeNavigationActive = definition.Shell == "Xbox" || (definition.Shell == "Xbox360" && IsMetro()); RenderPage(); return;
                }
                Close(); return;
            }
            if (actions.Count == 0) return;
            if (command == XmbInputCommand.Options)
            {
                if (IsGamePage() && selected >= 0 && selected < actions.Count && actions[selected].Game != null)
                {
                    PlayEffect("Confirm.wav"); LaunchGame(actions[selected].Game, true);
                }
                return;
            }
            int next = selected;
            int rowStep = (IsGamePage() && !IsBlades()) ? Math.Max(1, columns) : 1;
            if (command == XmbInputCommand.Left) next--;
            else if (command == XmbInputCommand.Right) next++;
            else if (command == XmbInputCommand.Up) next -= rowStep;
            else if (command == XmbInputCommand.Down) next += rowStep;
            else if (command == XmbInputCommand.Confirm)
            {
                PlayEffect("Confirm.wav");
                if (selected >= 0 && selected < actions.Count && actions[selected].Invoke != null) actions[selected].Invoke();
                return;
            }
            else return;
            next = Math.Max(0, Math.Min(actions.Count - 1, next));
            if (next != selected) { selected = next; PlayEffect("Navigate.wav"); UpdateActionVisuals(); }
        }

        private void ProcessGameCubeHubCommand(XmbInputCommand command)
        {
            int next = page;
            if (command == XmbInputCommand.Up) next = 0;          // Game Play
            else if (command == XmbInputCommand.Right) next = 1; // Calendar
            else if (command == XmbInputCommand.Down) next = 2;  // Memory Card
            else if (command == XmbInputCommand.Left) next = 3;  // Options
            else if (command == XmbInputCommand.Confirm)
            {
                dashboardSubpage = "gamecube-section"; selected = 0; PlayEffect("Confirm.wav"); RenderPage(); return;
            }
            else if (command == XmbInputCommand.Back) { PlayEffect("Back.wav"); Close(); return; }
            else return;
            if (next != page) { page = next; PlayEffect("Navigate.wav"); RenderPage(); }
        }

        private void ProcessXboxRootCommand(XmbInputCommand command)
        {
            if (command == XmbInputCommand.Up || command == XmbInputCommand.Down)
            {
                int next = Math.Max(0, Math.Min(GetPageCount() - 1, page + (command == XmbInputCommand.Up ? -1 : 1)));
                if (next != page) { page = next; PlayEffect("Navigate.wav"); UpdateNavigation(); RenderPage(); }
                return;
            }
            if (command == XmbInputCommand.Confirm)
            {
                dashboardSubpage = "xbox-section"; chromeNavigationActive = false; selected = 0; PlayEffect("Confirm.wav"); RenderPage(); return;
            }
            if (command == XmbInputCommand.Back) { PlayEffect("Back.wav"); Close(); }
        }

        private void ProcessSwitchHomeCommand(XmbInputCommand command)
        {
            if (switchSoftwareActionCount <= 0 && actions.Count == 0) { if (command == XmbInputCommand.Back) Close(); return; }
            int systemCount = Math.Max(0, actions.Count - switchSystemActionStart);
            if (command == XmbInputCommand.Up) { switchZone = 0; }
            else if (command == XmbInputCommand.Down && systemCount > 0) { switchZone = 1; }
            else if (command == XmbInputCommand.Left)
            {
                if (switchZone == 0) switchSoftwareIndex = Math.Max(0, switchSoftwareIndex - 1);
                else switchSystemIndex = Math.Max(0, switchSystemIndex - 1);
            }
            else if (command == XmbInputCommand.Right)
            {
                if (switchZone == 0) switchSoftwareIndex = Math.Min(Math.Max(0, switchSoftwareActionCount - 1), switchSoftwareIndex + 1);
                else switchSystemIndex = Math.Min(Math.Max(0, systemCount - 1), switchSystemIndex + 1);
            }
            else if (command == XmbInputCommand.Confirm)
            {
                int index = switchZone == 0 ? switchSoftwareIndex : switchSystemActionStart + switchSystemIndex;
                if (index >= 0 && index < actions.Count && actions[index].Invoke != null) { selected = index; PlayEffect("Confirm.wav"); actions[index].Invoke(); }
                return;
            }
            else if (command == XmbInputCommand.Back) { PlayEffect("Back.wav"); Close(); return; }
            else return;
            selected = switchZone == 0 ? Math.Min(Math.Max(0, switchSoftwareActionCount - 1), switchSoftwareIndex) : Math.Min(actions.Count - 1, switchSystemActionStart + switchSystemIndex);
            PlayEffect("Navigate.wav"); UpdateActionVisuals();
        }

        private bool ProcessMetroNavigationCommand(XmbInputCommand command)
        {
            if (chromeNavigationActive)
            {
                if (command == XmbInputCommand.Left || command == XmbInputCommand.Right)
                {
                    SwitchPage(command == XmbInputCommand.Left ? -1 : 1); chromeNavigationActive = true; return true;
                }
                if (command == XmbInputCommand.Down || command == XmbInputCommand.Confirm)
                {
                    if (actions.Count > 0) { chromeNavigationActive = false; selected = Math.Max(0, Math.Min(selected, actions.Count - 1)); PlayEffect("Navigate.wav"); UpdateActionVisuals(); }
                    return true;
                }
                if (command == XmbInputCommand.Back) { PlayEffect("Back.wav"); Close(); return true; }
                return command == XmbInputCommand.Up;
            }
            if (command == XmbInputCommand.Up && selected < Math.Max(1, columns))
            {
                chromeNavigationActive = true; PlayEffect("Navigate.wav"); return true;
            }
            if (command == XmbInputCommand.Back)
            {
                chromeNavigationActive = true; PlayEffect("Back.wav"); return true;
            }
            return false;
        }

        private bool ProcessWiiPageEdge(XmbInputCommand command)
        {
            int totalPages = 4;
            if (command == XmbInputCommand.Left && selected >= 0 && selected < 12 && selected % 4 == 0 && wiiMenuPage > 0)
            {
                wiiMenuPage--; selected = Math.Min(11, Math.Max(0, games.Count - wiiMenuPage * 12 - 1)); PlayEffect("Tab.wav"); RenderPage(); return true;
            }
            if (command == XmbInputCommand.Right && selected >= 0 && selected < 12 && selected % 4 == 3 && wiiMenuPage + 1 < totalPages)
            {
                wiiMenuPage++; selected = 0; PlayEffect("Tab.wav"); RenderPage(); return true;
            }
            return false;
        }

        private bool ProcessWiiUPageEdge(XmbInputCommand command)
        {
            int totalPages = Math.Max(1, (int)Math.Ceiling(Math.Max(1, games.Count) / 15.0));
            if (command == XmbInputCommand.Left && selected >= 0 && selected < 15 && selected % 5 == 0 && wiiUMenuPage > 0)
            {
                wiiUMenuPage--; selected = Math.Min(14, Math.Max(0, games.Count - wiiUMenuPage * 15 - 1)); PlayEffect("Tab.wav"); RenderPage(); return true;
            }
            if (command == XmbInputCommand.Right && selected >= 0 && selected < 15 && selected % 5 == 4 && wiiUMenuPage + 1 < totalPages)
            {
                wiiUMenuPage++; selected = 0; PlayEffect("Tab.wav"); RenderPage(); return true;
            }
            return false;
        }

        private void SwitchPage(int delta)
        {
            int pageCount = GetPageCount(); dashboardSubpage = String.Empty; selectedXboxSave = null;
            page = (page + delta + pageCount) % pageCount; selected = 0; PlayEffect("Tab.wav"); input.Reset(); inputGuardUntilUtc = DateTime.UtcNow.AddMilliseconds(260);
            if (IsBlades()) BuildChrome(); RenderPage();
        }


        private void OnKeyDown(object sender, KeyEventArgs e)
        {
            XmbInputCommand command = XmbInputCommand.None;
            if (e.Key == Key.Left) command = XmbInputCommand.Left;
            else if (e.Key == Key.Right) command = XmbInputCommand.Right;
            else if (e.Key == Key.Up) command = XmbInputCommand.Up;
            else if (e.Key == Key.Down) command = XmbInputCommand.Down;
            else if (e.Key == Key.Enter || e.Key == Key.Space) command = XmbInputCommand.Confirm;
            else if (e.Key == Key.Escape || e.Key == Key.Back) command = XmbInputCommand.Back;
            else if (e.Key == Key.PageUp) command = XmbInputCommand.LeftShoulder;
            else if (e.Key == Key.PageDown) command = XmbInputCommand.RightShoulder;
            else if (e.Key == Key.F) command = XmbInputCommand.Options;
            else if (e.Key == Key.G) command = XmbInputCommand.Menu;
            if (command != XmbInputCommand.None)
            {
                e.Handled = true;
                try { ProcessCommand(command); }
                catch (Exception ex) { WritePlatformLog(definition.DisplayName + " keyboard command recovered: " + ex, "ERROR"); }
            }
        }

        private void RenderPage()
        {
            UpdateNavigation(); contentHost.Children.Clear(); actions.Clear(); xboxPreviewTitle = null; xboxPreviewDetail = null; xboxPreviewImage = null;
            if (definition.Shell == "N64" && !IsRootConsoleSurface()) { if (page == 1) RenderN64ControllerPak(FindSaveRoots()); else RenderSettings(); UpdateActionVisuals(); return; }
            if (definition.Shell == "WiiU" && !IsRootConsoleSurface()) { if (page == 1) RenderWiiUDataManagement(FindSaveRoots()); else RenderSettings(); UpdateActionVisuals(); return; }
            if (definition.Shell == "Switch" && !IsRootConsoleSurface()) { if (dashboardSubpage == "switch-all") RenderSwitchAllSoftware(); else RenderSettings(); UpdateActionVisuals(); return; }
            if (definition.Shell == "GameCube")
            {
                if (IsRootConsoleSurface()) RenderGameCubeHub();
                else if (page == 0) RenderGameCubeGamePlay(); else if (page == 1) RenderGameCubeCalendar(); else if (page == 2) RenderGameCubeMemoryCards(FindSaveRoots()); else RenderSettings();
                UpdateActionVisuals(); return;
            }
            if (definition.Shell == "Wii")
            {
                if (dashboardSubpage == "wii-start") RenderWiiChannelStart();
                else if (dashboardSubpage == "wii-options") RenderWiiOptions();
                else if (dashboardSubpage == "wii-data") RenderWiiDataManagement(FindSaveRoots());
                else if (dashboardSubpage == "wii-settings") RenderSettings();
                else RenderWiiMenuAuthentic();
                UpdateActionVisuals(); return;
            }
            if (definition.Shell == "WiiU" && IsRootConsoleSurface()) { RenderWiiUMenuAuthentic(); UpdateActionVisuals(); return; }
            if (definition.Shell == "Switch" && IsRootConsoleSurface()) { RenderSwitchHomeAuthentic(); UpdateActionVisuals(); return; }
            if (definition.Shell == "N64" && IsRootConsoleSurface()) { RenderN64GamePakLauncher(); UpdateActionVisuals(); return; }
            if (definition.Shell == "Xbox" && IsRootConsoleSurface()) { RenderXboxRoot(); UpdateActionVisuals(); return; }
            if (definition.Shell == "Xbox360" && String.Equals(dashboardSubpage, "achievements", StringComparison.OrdinalIgnoreCase)) { RenderXbox360Achievements(); UpdateActionVisuals(); return; }
            if (definition.Shell == "Xbox360" && String.Equals(dashboardSubpage, "settings", StringComparison.OrdinalIgnoreCase)) { RenderSettings(); UpdateActionVisuals(); return; }
            if (IsXboxFamily() && String.Equals(dashboardSubpage, "storage", StringComparison.OrdinalIgnoreCase)) { RenderXboxStorageManager(); UpdateActionVisuals(); return; }
            if (IsXboxFamily() && String.Equals(dashboardSubpage, "save-detail", StringComparison.OrdinalIgnoreCase)) { RenderXboxSaveDetail(); UpdateActionVisuals(); return; }
            if (definition.Shell == "Xbox")
            {
                if (page == 0) RenderGames(); else if (page == 1) { ScanXboxSaves(); RenderXboxStorageManager(); } else if (page == 2) RenderXboxMusic(); else if (page == 3) RenderXboxLive(); else RenderSettings();
            }
            else if (definition.Shell == "Xbox360")
            {
                if (IsBlades())
                {
                    if (page == 0) RenderXbox360Live(); else if (page == 1) RenderGames(); else if (page == 2) RenderXbox360Media(); else RenderXbox360System();
                }
                else
                {
                    if (page == 0) RenderMetroHome(); else if (page == 1) RenderXbox360Social(); else if (page == 2) RenderGames(); else if (page == 3) RenderXbox360Video(); else if (page == 4) RenderXbox360Music(); else if (page == 5) RenderXbox360Apps(); else RenderSettings();
                }
            }
            else
            {
                if (page == 0) RenderGames(); else if (page == 1) RenderSaves(); else RenderSettings();
            }
            UpdateActionVisuals();
        }


        private void RenderGames()
        {
            if (definition.Shell == "Xbox") { RenderXboxGamesAuthentic(); return; }
            if (IsBlades()) { RenderBladesGamesAuthentic(); return; }
            if (IsMetro()) { RenderMetroGamesAuthentic(); return; }
            if (definition.Shell == "N64") { RenderN64GamePakLauncher(); return; }
            if (definition.Shell == "GameCube") { RenderGameCubeGamePlay(); return; }
            if (definition.Shell == "Wii") { RenderWiiMenuAuthentic(); return; }
            if (definition.Shell == "WiiU") { RenderWiiUMenuAuthentic(); return; }
            if (definition.Shell == "Switch") { RenderSwitchHomeAuthentic(); return; }
            titleText.Text = "Games"; subtitleText.Text = games.Count.ToString(CultureInfo.InvariantCulture) + " detected games  •  " + definition.PrimaryBackend + " primary";
            ScrollViewer scroll = new ScrollViewer { VerticalScrollBarVisibility = ScrollBarVisibility.Hidden, HorizontalScrollBarVisibility = ScrollBarVisibility.Disabled };
            WrapPanel wrap = new WrapPanel { Margin = new Thickness(18, 4, 18, 18) }; scroll.Content = wrap; contentHost.Children.Add(scroll);
            foreach (ConsolePlatformGame game in games)
            {
                ConsolePlatformGame captured = game; Button button = CreateGameButton(game, delegate { LaunchGame(captured, false); }); wrap.Children.Add(button); actions.Add(new ConsolePlatformAction { Button = button, Invoke = delegate { LaunchGame(captured, false); }, Name = game.Name, Game = captured });
            }
        }

        private void RenderN64GamePakLauncher()
        {
            titleText.Text = "Nintendo 64"; subtitleText.Text = "GAME PAK  •  cartridge-first launcher";
            Grid body = new Grid { Margin = new Thickness(20, 4, 20, 12) };
            body.RowDefinitions.Add(new RowDefinition { Height = new GridLength(1, GridUnitType.Star) }); body.RowDefinitions.Add(new RowDefinition { Height = new GridLength(96) }); contentHost.Children.Add(body);
            ScrollViewer scroll = new ScrollViewer { VerticalScrollBarVisibility = ScrollBarVisibility.Hidden, HorizontalScrollBarVisibility = ScrollBarVisibility.Disabled };
            WrapPanel shelf = new WrapPanel { HorizontalAlignment = HorizontalAlignment.Center, Margin = new Thickness(8) }; scroll.Content = shelf; body.Children.Add(scroll);
            foreach (ConsolePlatformGame game in games)
            {
                ConsolePlatformGame captured = game; Button cart = CreateN64CartridgeTile(game, delegate { LaunchGame(captured, false); }); shelf.Children.Add(cart); actions.Add(new ConsolePlatformAction { Button = cart, Invoke = delegate { LaunchGame(captured, false); }, Name = game.Name, Game = game });
            }
            if (games.Count == 0)
            {
                Button empty = CreateN64UtilityButton("INSERT GAME PAK", "Configure a ROM folder", delegate { dashboardSubpage = "n64-settings"; page = 2; selected = 0; RenderPage(); }); shelf.Children.Add(empty); actions.Add(new ConsolePlatformAction { Button = empty, Invoke = delegate { dashboardSubpage = "n64-settings"; page = 2; selected = 0; RenderSettings(); }, Name = "Insert Game Pak" });
            }
            StackPanel utilities = new StackPanel { Orientation = Orientation.Horizontal, HorizontalAlignment = HorizontalAlignment.Center, VerticalAlignment = VerticalAlignment.Center };
            Button pak = CreateN64UtilityButton("CONTROLLER PAK", "Save data", delegate { dashboardSubpage = "n64-pak"; page = 1; selected = 0; contentHost.Children.Clear(); actions.Clear(); RenderN64ControllerPak(FindSaveRoots()); UpdateActionVisuals(); });
            Button options = CreateN64UtilityButton("OPTIONS", "RMG / ares", delegate { dashboardSubpage = "n64-settings"; page = 2; selected = 0; contentHost.Children.Clear(); actions.Clear(); RenderSettings(); UpdateActionVisuals(); });
            utilities.Children.Add(pak); utilities.Children.Add(options); Grid.SetRow(utilities, 1); body.Children.Add(utilities);
            actions.Add(new ConsolePlatformAction { Button = pak, Invoke = delegate { dashboardSubpage = "n64-pak"; page = 1; selected = 0; contentHost.Children.Clear(); actions.Clear(); RenderN64ControllerPak(FindSaveRoots()); UpdateActionVisuals(); }, Name = "Controller Pak" });
            actions.Add(new ConsolePlatformAction { Button = options, Invoke = delegate { dashboardSubpage = "n64-settings"; page = 2; selected = 0; contentHost.Children.Clear(); actions.Clear(); RenderSettings(); UpdateActionVisuals(); }, Name = "Options" });
        }

        private Button CreateN64CartridgeTile(ConsolePlatformGame game, Action invoke)
        {
            Button button = new Button { Width = 228, Height = 270, Margin = new Thickness(12), Padding = new Thickness(10), Background = new LinearGradientBrush(Color.FromRgb(73, 74, 79), Color.FromRgb(31, 32, 38), 90), BorderBrush = new SolidColorBrush(Color.FromRgb(231, 187, 38)), BorderThickness = new Thickness(2), RenderTransformOrigin = new Point(0.5, 0.5) };
            Grid grid = new Grid(); grid.RowDefinitions.Add(new RowDefinition { Height = new GridLength(34) }); grid.RowDefinitions.Add(new RowDefinition { Height = new GridLength(1, GridUnitType.Star) }); grid.RowDefinitions.Add(new RowDefinition { Height = new GridLength(58) });
            Border ridge = new Border { Background = new SolidColorBrush(Color.FromRgb(104, 105, 110)), CornerRadius = new CornerRadius(5), Margin = new Thickness(20, 1, 20, 6) }; grid.Children.Add(ridge);
            Border label = new Border { Margin = new Thickness(12, 8, 12, 8), Background = new SolidColorBrush(Color.FromRgb(233, 231, 218)), BorderBrush = new SolidColorBrush(Color.FromRgb(29, 29, 31)), BorderThickness = new Thickness(2) };
            if (!String.IsNullOrWhiteSpace(game.Cover) && File.Exists(game.Cover)) { try { label.Child = new Image { Source = LoadBitmap(game.Cover), Stretch = Stretch.UniformToFill }; } catch { } }
            if (label.Child == null) label.Child = new TextBlock { Text = "NINTENDO\n64", TextAlignment = TextAlignment.Center, FontSize = 28, FontWeight = FontWeights.Bold, Foreground = new SolidColorBrush(Color.FromRgb(34, 35, 39)), HorizontalAlignment = HorizontalAlignment.Center, VerticalAlignment = VerticalAlignment.Center };
            Grid.SetRow(label, 1); grid.Children.Add(label);
            TextBlock name = new TextBlock { Text = game.Name, FontSize = 13, FontWeight = FontWeights.Bold, Foreground = Brushes.White, TextAlignment = TextAlignment.Center, TextWrapping = TextWrapping.Wrap, TextTrimming = TextTrimming.CharacterEllipsis, Margin = new Thickness(6, 5, 6, 0) }; Grid.SetRow(name, 2); grid.Children.Add(name); button.Content = grid; button.Click += delegate { invoke(); }; return button;
        }

        private Button CreateN64UtilityButton(string title, string detail, Action invoke)
        {
            Button b = new Button { Width = 240, Height = 68, Margin = new Thickness(8), Background = new SolidColorBrush(Color.FromRgb(36, 37, 44)), BorderBrush = new SolidColorBrush(Color.FromRgb(232, 188, 39)), BorderThickness = new Thickness(2), RenderTransformOrigin = new Point(0.5, 0.5) };
            StackPanel s = new StackPanel { VerticalAlignment = VerticalAlignment.Center }; s.Children.Add(new TextBlock { Text = title, FontSize = 16, FontWeight = FontWeights.Bold, Foreground = Brushes.White, HorizontalAlignment = HorizontalAlignment.Center }); s.Children.Add(new TextBlock { Text = detail, FontSize = 10, Foreground = new SolidColorBrush(Color.FromRgb(197, 198, 205)), HorizontalAlignment = HorizontalAlignment.Center }); b.Content = s; b.Click += delegate { invoke(); }; return b;
        }

        private void RenderGameCubeHub()
        {
            titleText.Text = String.Empty; subtitleText.Text = String.Empty;
            Grid hub = new Grid { Margin = new Thickness(70, 20, 70, 20) }; hub.RowDefinitions.Add(new RowDefinition()); hub.RowDefinitions.Add(new RowDefinition()); hub.RowDefinitions.Add(new RowDefinition()); hub.ColumnDefinitions.Add(new ColumnDefinition()); hub.ColumnDefinitions.Add(new ColumnDefinition()); hub.ColumnDefinitions.Add(new ColumnDefinition()); contentHost.Children.Add(hub);
            Border center = new Border { Width = 250, Height = 250, CornerRadius = new CornerRadius(125), Background = new RadialGradientBrush(Color.FromRgb(168, 152, 255), Color.FromRgb(40, 26, 95)), BorderBrush = new SolidColorBrush(Color.FromRgb(204, 195, 255)), BorderThickness = new Thickness(5), HorizontalAlignment = HorizontalAlignment.Center, VerticalAlignment = VerticalAlignment.Center };
            center.Child = new TextBlock { Text = "NINTENDO\nGAMECUBE", FontSize = 28, FontWeight = FontWeights.Bold, Foreground = Brushes.White, TextAlignment = TextAlignment.Center, HorizontalAlignment = HorizontalAlignment.Center, VerticalAlignment = VerticalAlignment.Center }; Grid.SetRow(center, 1); Grid.SetColumn(center, 1); hub.Children.Add(center);
            AddGameCubeHubNode(hub, "GAME PLAY", "Game Disc", 0, 0, 1, "▲");
            AddGameCubeHubNode(hub, "CALENDAR", DateTime.Now.ToString("MMM d  yyyy", CultureInfo.CurrentCulture), 1, 1, 2, "▶");
            AddGameCubeHubNode(hub, "MEMORY CARD", "Slot A / Slot B", 2, 2, 1, "▼");
            AddGameCubeHubNode(hub, "OPTIONS", "Sound / Display / Emulator", 3, 1, 0, "◀");
            TextBlock help = new TextBlock { Text = "Move the Control Stick / D-Pad toward a menu • A Select • B Back", FontSize = 13, Foreground = new SolidColorBrush(Color.FromRgb(203, 198, 235)), HorizontalAlignment = HorizontalAlignment.Center, VerticalAlignment = VerticalAlignment.Bottom, Margin = new Thickness(0, 0, 0, 4) }; Grid.SetRow(help, 2); Grid.SetColumnSpan(help, 3); hub.Children.Add(help);
        }

        private void AddGameCubeHubNode(Grid hub, string title, string detail, int index, int row, int column, string arrow)
        {
            bool active = page == index; Border node = new Border { Width = 310, Height = 128, CornerRadius = new CornerRadius(54), Background = new SolidColorBrush(active ? Color.FromArgb(235, 112, 88, 211) : Color.FromArgb(175, 51, 39, 106)), BorderBrush = new SolidColorBrush(active ? Color.FromRgb(224, 217, 255) : Color.FromRgb(116, 99, 192)), BorderThickness = new Thickness(active ? 5 : 2), HorizontalAlignment = HorizontalAlignment.Center, VerticalAlignment = VerticalAlignment.Center };
            StackPanel s = new StackPanel { VerticalAlignment = VerticalAlignment.Center }; s.Children.Add(new TextBlock { Text = arrow + "  " + title, FontSize = 22, FontWeight = FontWeights.Bold, Foreground = Brushes.White, HorizontalAlignment = HorizontalAlignment.Center }); s.Children.Add(new TextBlock { Text = detail, FontSize = 11, Foreground = new SolidColorBrush(Color.FromRgb(214, 210, 235)), HorizontalAlignment = HorizontalAlignment.Center }); node.Child = s; Grid.SetRow(node, row); Grid.SetColumn(node, column); hub.Children.Add(node);
        }

        private void RenderGameCubeGamePlay()
        {
            titleText.Text = "Game Play"; subtitleText.Text = games.Count == 0 ? "No Game Disc / library title detected" : "Select a Game Disc image • A opens / launches";
            ScrollViewer scroll = new ScrollViewer { VerticalScrollBarVisibility = ScrollBarVisibility.Hidden, HorizontalScrollBarVisibility = ScrollBarVisibility.Disabled }; WrapPanel wrap = new WrapPanel { HorizontalAlignment = HorizontalAlignment.Center, Margin = new Thickness(20) }; scroll.Content = wrap; contentHost.Children.Add(scroll);
            foreach (ConsolePlatformGame game in games) { ConsolePlatformGame captured = game; Button b = CreateGameCubeDiscTile(game, delegate { LaunchGame(captured, false); }); wrap.Children.Add(b); actions.Add(new ConsolePlatformAction { Button = b, Invoke = delegate { LaunchGame(captured, false); }, Name = game.Name, Game = game }); }
            if (games.Count == 0) { Button add = CreateActionButton("No Game Disc", "Open Options to configure a Dolphin game folder", delegate { page = 3; selected = 0; RenderPage(); }); wrap.Children.Add(add); actions.Add(new ConsolePlatformAction { Button = add, Invoke = delegate { page = 3; selected = 0; RenderPage(); }, Name = "Options" }); }
        }

        private Button CreateGameCubeDiscTile(ConsolePlatformGame game, Action invoke)
        {
            Button b = new Button { Width = 260, Height = 260, Margin = new Thickness(18), Padding = new Thickness(12), Background = new RadialGradientBrush(Color.FromRgb(91, 72, 172), Color.FromRgb(32, 22, 76)), BorderBrush = new SolidColorBrush(Color.FromRgb(169, 153, 255)), BorderThickness = new Thickness(3), RenderTransformOrigin = new Point(0.5, 0.5) };
            Grid g = new Grid(); System.Windows.Shapes.Ellipse disc = new System.Windows.Shapes.Ellipse { Width = 180, Height = 180, Fill = new RadialGradientBrush(Color.FromRgb(233, 234, 239), Color.FromRgb(92, 94, 109)), Stroke = new SolidColorBrush(Color.FromRgb(245, 245, 250)), StrokeThickness = 2, HorizontalAlignment = HorizontalAlignment.Center, VerticalAlignment = VerticalAlignment.Center }; g.Children.Add(disc);
            if (!String.IsNullOrWhiteSpace(game.Cover) && File.Exists(game.Cover)) { try { Image art = new Image { Source = LoadBitmap(game.Cover), Width = 136, Height = 136, Stretch = Stretch.UniformToFill, HorizontalAlignment = HorizontalAlignment.Center, VerticalAlignment = VerticalAlignment.Center }; art.Clip = new EllipseGeometry(new Point(68,68),68,68); g.Children.Add(art); } catch { } }
            Border label = new Border { Height = 54, VerticalAlignment = VerticalAlignment.Bottom, Background = new SolidColorBrush(Color.FromArgb(220, 26, 19, 61)), Padding = new Thickness(8) }; label.Child = new TextBlock { Text = game.Name, FontSize = 13, FontWeight = FontWeights.Bold, Foreground = Brushes.White, TextAlignment = TextAlignment.Center, TextTrimming = TextTrimming.CharacterEllipsis }; g.Children.Add(label); b.Content = g; b.Click += delegate { invoke(); }; return b;
        }

        private void RenderGameCubeCalendar()
        {
            titleText.Text = "Calendar"; subtitleText.Text = "Internal Clock";
            Grid panel = new Grid { Margin = new Thickness(110, 36, 110, 50) }; panel.ColumnDefinitions.Add(new ColumnDefinition()); panel.ColumnDefinitions.Add(new ColumnDefinition()); contentHost.Children.Add(panel);
            Border date = CreateGameCubeClockPanel("DATE", DateTime.Now.ToString("MM / dd / yyyy", CultureInfo.CurrentCulture), DateTime.Now.ToString("dddd", CultureInfo.CurrentCulture)); panel.Children.Add(date);
            Border time = CreateGameCubeClockPanel("TIME", DateTime.Now.ToString("HH : mm", CultureInfo.CurrentCulture), DateTime.Now.ToString("h:mm:ss tt", CultureInfo.CurrentCulture)); Grid.SetColumn(time, 1); panel.Children.Add(time);
        }

        private Border CreateGameCubeClockPanel(string heading, string value, string detail)
        {
            Border box = new Border { Margin = new Thickness(26), CornerRadius = new CornerRadius(48), Background = new SolidColorBrush(Color.FromArgb(220, 52, 39, 111)), BorderBrush = new SolidColorBrush(Color.FromRgb(150, 130, 240)), BorderThickness = new Thickness(4), Padding = new Thickness(30) };
            StackPanel s = new StackPanel { VerticalAlignment = VerticalAlignment.Center }; s.Children.Add(new TextBlock { Text = heading, FontSize = 18, Foreground = new SolidColorBrush(Color.FromRgb(205, 199, 238)), HorizontalAlignment = HorizontalAlignment.Center }); s.Children.Add(new TextBlock { Text = value, FontSize = 42, FontWeight = FontWeights.Light, Foreground = Brushes.White, HorizontalAlignment = HorizontalAlignment.Center, Margin = new Thickness(0, 20, 0, 12) }); s.Children.Add(new TextBlock { Text = detail, FontSize = 14, Foreground = new SolidColorBrush(Color.FromRgb(213, 209, 236)), HorizontalAlignment = HorizontalAlignment.Center }); box.Child = s; return box;
        }

        private void RenderWiiMenuAuthentic()
        {
            titleText.Text = String.Empty; subtitleText.Text = String.Empty; columns = 4;
            Grid body = new Grid { Margin = new Thickness(42, 18, 42, 6) }; body.RowDefinitions.Add(new RowDefinition { Height = new GridLength(1, GridUnitType.Star) }); body.RowDefinitions.Add(new RowDefinition { Height = new GridLength(80) }); contentHost.Children.Add(body);
            UniformGrid channels = new UniformGrid { Columns = 4, Rows = 3, Margin = new Thickness(8, 0, 8, 8) }; body.Children.Add(channels);
            int start = wiiMenuPage * 12; int count = Math.Min(12, Math.Max(0, games.Count - start));
            for (int slot = 0; slot < 12; slot++)
            {
                int gameIndex = start + slot;
                if (gameIndex < games.Count)
                {
                    ConsolePlatformGame game = games[gameIndex]; ConsolePlatformGame captured = game; Button channel = CreateWiiChannelTile(game, slot == 0, delegate { shellSelectedGame = captured; dashboardSubpage = "wii-start"; selected = 0; RenderPage(); }); channels.Children.Add(channel); actions.Add(new ConsolePlatformAction { Button = channel, Invoke = delegate { shellSelectedGame = captured; dashboardSubpage = "wii-start"; selected = 0; RenderPage(); }, Name = game.Name, Game = game });
                }
                else
                {
                    Border blank = new Border { Margin = new Thickness(10), CornerRadius = new CornerRadius(16), Background = new SolidColorBrush(Color.FromArgb(135, 250, 252, 253)), BorderBrush = new SolidColorBrush(Color.FromRgb(202, 218, 224)), BorderThickness = new Thickness(2) }; channels.Children.Add(blank);
                }
            }
            Grid bottom = new Grid { Margin = new Thickness(10, 0, 10, 0) }; bottom.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(320) }); bottom.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) }); bottom.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(220) });
            StackPanel leftControls = new StackPanel { Orientation = Orientation.Horizontal, HorizontalAlignment = HorizontalAlignment.Left, VerticalAlignment = VerticalAlignment.Center };
            Button wii = CreateWiiRoundButton("Wii", "Options", delegate { dashboardSubpage = "wii-options"; selected = 0; RenderPage(); }); wii.Width = 146;
            Button sd = CreateWiiRoundButton("SD", "SD Card", OpenFirstSaveRoot); sd.Width = 146; leftControls.Children.Add(wii); leftControls.Children.Add(sd); bottom.Children.Add(leftControls);
            StackPanel clock = new StackPanel { HorizontalAlignment = HorizontalAlignment.Center, VerticalAlignment = VerticalAlignment.Center }; clock.Children.Add(new TextBlock { Text = DateTime.Now.ToString("h:mm tt", CultureInfo.CurrentCulture), FontSize = 24, Foreground = new SolidColorBrush(Color.FromRgb(86, 101, 108)), HorizontalAlignment = HorizontalAlignment.Center }); clock.Children.Add(new TextBlock { Text = DateTime.Now.ToString("ddd M/d", CultureInfo.CurrentCulture) + "    " + (wiiMenuPage + 1).ToString(CultureInfo.InvariantCulture) + "/4", FontSize = 11, Foreground = new SolidColorBrush(Color.FromRgb(126, 139, 145)), HorizontalAlignment = HorizontalAlignment.Center }); Grid.SetColumn(clock, 1); bottom.Children.Add(clock);
            Button messages = CreateWiiRoundButton("✉", "Wii Message Board", delegate { ShowNotice("Wii Message Board is represented for menu fidelity; Huymaier Console does not emulate Nintendo messaging services."); }); messages.Width = 194; Grid.SetColumn(messages, 2); bottom.Children.Add(messages); Grid.SetRow(bottom, 1); body.Children.Add(bottom);
            actions.Add(new ConsolePlatformAction { Button = wii, Invoke = delegate { dashboardSubpage = "wii-options"; selected = 0; RenderPage(); }, Name = "Wii Options" }); actions.Add(new ConsolePlatformAction { Button = sd, Invoke = OpenFirstSaveRoot, Name = "SD Card Menu" }); actions.Add(new ConsolePlatformAction { Button = messages, Invoke = delegate { ShowNotice("Wii Message Board is represented for menu fidelity; Huymaier Console does not emulate Nintendo messaging services."); }, Name = "Wii Message Board" });
            selected = Math.Max(0, Math.Min(actions.Count - 1, selected));
        }

        private Button CreateWiiChannelTile(ConsolePlatformGame game, bool discSlot, Action invoke)
        {
            Button b = new Button { Margin = new Thickness(10), Background = Brushes.White, BorderBrush = new SolidColorBrush(Color.FromRgb(156, 207, 221)), BorderThickness = new Thickness(3), RenderTransformOrigin = new Point(0.5, 0.5), Padding = new Thickness(0) }; Grid g = new Grid();
            if (!String.IsNullOrWhiteSpace(game.Cover) && File.Exists(game.Cover)) { try { g.Children.Add(new Image { Source = LoadBitmap(game.Cover), Stretch = Stretch.UniformToFill, Margin = new Thickness(5) }); } catch { } }
            if (g.Children.Count == 0) g.Children.Add(new TextBlock { Text = discSlot ? "Disc Channel" : "Wii", FontSize = discSlot ? 22 : 30, Foreground = new SolidColorBrush(Color.FromRgb(107, 126, 133)), HorizontalAlignment = HorizontalAlignment.Center, VerticalAlignment = VerticalAlignment.Center });
            Border caption = new Border { Height = 42, VerticalAlignment = VerticalAlignment.Bottom, Background = new SolidColorBrush(Color.FromArgb(230, 248, 251, 252)), Padding = new Thickness(6) }; caption.Child = new TextBlock { Text = discSlot ? "Disc Channel" : game.Name, FontSize = 11, FontWeight = FontWeights.SemiBold, Foreground = new SolidColorBrush(Color.FromRgb(70, 87, 94)), HorizontalAlignment = HorizontalAlignment.Center, TextTrimming = TextTrimming.CharacterEllipsis }; g.Children.Add(caption); b.Content = g; b.Click += delegate { invoke(); }; return b;
        }

        private Button CreateWiiRoundButton(string title, string detail, Action invoke)
        {
            Button b = new Button { Width = 180, Height = 58, Margin = new Thickness(4), Background = new SolidColorBrush(Color.FromRgb(246, 249, 250)), BorderBrush = new SolidColorBrush(Color.FromRgb(142, 201, 219)), BorderThickness = new Thickness(2), RenderTransformOrigin = new Point(0.5,0.5) }; StackPanel s = new StackPanel { VerticalAlignment = VerticalAlignment.Center }; s.Children.Add(new TextBlock { Text = title, FontSize = 19, FontWeight = FontWeights.SemiBold, Foreground = new SolidColorBrush(Color.FromRgb(69, 86, 92)), HorizontalAlignment = HorizontalAlignment.Center }); s.Children.Add(new TextBlock { Text = detail, FontSize = 9, Foreground = new SolidColorBrush(Color.FromRgb(115, 131, 137)), HorizontalAlignment = HorizontalAlignment.Center }); b.Content = s; b.Click += delegate { invoke(); }; return b;
        }

        private void RenderWiiChannelStart()
        {
            titleText.Text = String.Empty; subtitleText.Text = String.Empty; Grid body = new Grid { Margin = new Thickness(90, 22, 90, 24), Background = Brushes.White }; body.RowDefinitions.Add(new RowDefinition { Height = new GridLength(1, GridUnitType.Star) }); body.RowDefinitions.Add(new RowDefinition { Height = new GridLength(90) }); contentHost.Children.Add(body);
            Grid preview = new Grid { Margin = new Thickness(40, 18, 40, 18) }; if (shellSelectedGame != null && !String.IsNullOrWhiteSpace(shellSelectedGame.Cover) && File.Exists(shellSelectedGame.Cover)) { try { preview.Children.Add(new Image { Source = LoadBitmap(shellSelectedGame.Cover), Stretch = Stretch.Uniform }); } catch { } } if (preview.Children.Count == 0) preview.Children.Add(new TextBlock { Text = shellSelectedGame == null ? "Wii" : shellSelectedGame.Name, FontSize = 42, Foreground = new SolidColorBrush(Color.FromRgb(86, 102, 108)), HorizontalAlignment = HorizontalAlignment.Center, VerticalAlignment = VerticalAlignment.Center }); body.Children.Add(preview);
            Grid buttons = new Grid { Margin = new Thickness(60, 8, 60, 8) }; buttons.ColumnDefinitions.Add(new ColumnDefinition()); buttons.ColumnDefinitions.Add(new ColumnDefinition()); Button back = CreateWiiRoundButton("Wii Menu", "Back", delegate { dashboardSubpage = String.Empty; shellSelectedGame = null; selected = 0; RenderPage(); }); back.Width = 300; buttons.Children.Add(back); Button start = CreateWiiRoundButton("Start", shellSelectedGame == null ? "No title" : shellSelectedGame.Name, delegate { if (shellSelectedGame != null) LaunchGame(shellSelectedGame, false); }); start.Width = 300; Grid.SetColumn(start, 1); buttons.Children.Add(start); Grid.SetRow(buttons, 1); body.Children.Add(buttons); actions.Add(new ConsolePlatformAction { Button = back, Invoke = delegate { dashboardSubpage = String.Empty; shellSelectedGame = null; selected = 0; RenderPage(); }, Name = "Wii Menu" }); actions.Add(new ConsolePlatformAction { Button = start, Invoke = delegate { if (shellSelectedGame != null) LaunchGame(shellSelectedGame, false); }, Name = "Start", Game = shellSelectedGame });
        }

        private void RenderWiiOptions()
        {
            titleText.Text = "Wii Options"; subtitleText.Text = ""; Grid grid = new Grid { Margin = new Thickness(150, 70, 150, 70) }; grid.ColumnDefinitions.Add(new ColumnDefinition()); grid.ColumnDefinitions.Add(new ColumnDefinition()); contentHost.Children.Add(grid);
            Button data = CreateShellAction("Data Management", "Save Data and Channels", delegate { dashboardSubpage = "wii-data"; selected = 0; RenderPage(); }, Color.FromRgb(54, 181, 216)); data.Margin = new Thickness(25); grid.Children.Add(data); actions.Add(new ConsolePlatformAction { Button = data, Invoke = delegate { dashboardSubpage = "wii-data"; selected = 0; RenderPage(); }, Name = "Data Management" });
            Button settingsButton = CreateShellAction("Wii Settings", "Console and emulator settings", delegate { dashboardSubpage = "wii-settings"; selected = 0; RenderPage(); }, Color.FromRgb(76, 191, 218)); settingsButton.Margin = new Thickness(25); Grid.SetColumn(settingsButton, 1); grid.Children.Add(settingsButton); actions.Add(new ConsolePlatformAction { Button = settingsButton, Invoke = delegate { dashboardSubpage = "wii-settings"; selected = 0; RenderPage(); }, Name = "Wii Settings" });
        }

        private void RenderWiiUMenuAuthentic()
        {
            titleText.Text = "Wii U Menu"; subtitleText.Text = "WaraWara Plaza  •  " + games.Count.ToString(CultureInfo.InvariantCulture) + " software titles"; columns = 5;
            Grid body = new Grid { Margin = new Thickness(42, 2, 42, 8) }; body.RowDefinitions.Add(new RowDefinition { Height = new GridLength(1, GridUnitType.Star) }); body.RowDefinitions.Add(new RowDefinition { Height = new GridLength(78) }); contentHost.Children.Add(body);
            Grid plaza = new Grid(); for (int i = 0; i < 18; i++) { System.Windows.Shapes.Ellipse bubble = new System.Windows.Shapes.Ellipse { Width = 74 + (i % 4) * 18, Height = 48 + (i % 3) * 12, Fill = new SolidColorBrush(Color.FromArgb(35, 35, 158, 205)), HorizontalAlignment = (i % 2 == 0) ? HorizontalAlignment.Left : HorizontalAlignment.Right, VerticalAlignment = (i % 3 == 0) ? VerticalAlignment.Top : VerticalAlignment.Bottom, Margin = new Thickness(20 + (i * 71) % 460, 12 + (i * 47) % 210, 20 + (i * 29) % 320, 12 + (i * 31) % 160) }; plaza.Children.Add(bubble); }
            UniformGrid icons = new UniformGrid { Columns = 5, Rows = 3, Margin = new Thickness(18, 18, 18, 18) }; plaza.Children.Add(icons); body.Children.Add(plaza);
            int start = wiiUMenuPage * 15;
            for (int slot = 0; slot < 15; slot++)
            {
                int idx = start + slot;
                if (idx < games.Count) { ConsolePlatformGame game = games[idx]; ConsolePlatformGame captured = game; Button icon = CreateWiiUSoftwareIcon(game, delegate { LaunchGame(captured, false); }); icons.Children.Add(icon); actions.Add(new ConsolePlatformAction { Button = icon, Invoke = delegate { LaunchGame(captured, false); }, Name = game.Name, Game = game }); }
                else icons.Children.Add(new Border { Margin = new Thickness(11), CornerRadius = new CornerRadius(16), Background = new SolidColorBrush(Color.FromArgb(120, 255, 255, 255)), BorderBrush = new SolidColorBrush(Color.FromArgb(100, 36, 160, 206)), BorderThickness = new Thickness(1) });
            }
            StackPanel sys = new StackPanel { Orientation = Orientation.Horizontal, HorizontalAlignment = HorizontalAlignment.Center, VerticalAlignment = VerticalAlignment.Center }; Button data = CreateWiiURoundSystemButton("Data Management", delegate { dashboardSubpage = "wiiu-data"; page = 1; selected = 0; RenderWiiUDataManagement(FindSaveRoots()); UpdateActionVisuals(); }); Button settingsButton = CreateWiiURoundSystemButton("System Settings", delegate { dashboardSubpage = "wiiu-settings"; page = 2; selected = 0; contentHost.Children.Clear(); actions.Clear(); RenderSettings(); UpdateActionVisuals(); }); sys.Children.Add(data); sys.Children.Add(settingsButton); Grid.SetRow(sys,1); body.Children.Add(sys); actions.Add(new ConsolePlatformAction { Button=data, Invoke=delegate { dashboardSubpage="wiiu-data"; page=1; selected=0; contentHost.Children.Clear(); actions.Clear(); RenderWiiUDataManagement(FindSaveRoots()); UpdateActionVisuals(); }, Name="Data Management" }); actions.Add(new ConsolePlatformAction { Button=settingsButton, Invoke=delegate { dashboardSubpage="wiiu-settings"; page=2; selected=0; contentHost.Children.Clear(); actions.Clear(); RenderSettings(); UpdateActionVisuals(); }, Name="System Settings" }); selected=Math.Max(0,Math.Min(actions.Count-1,selected));
        }

        private Button CreateWiiUSoftwareIcon(ConsolePlatformGame game, Action invoke)
        {
            Button b = new Button { Margin = new Thickness(11), Background = new SolidColorBrush(Color.FromArgb(245,255,255,255)), BorderBrush = new SolidColorBrush(Color.FromRgb(79, 183, 217)), BorderThickness = new Thickness(2), RenderTransformOrigin = new Point(0.5,0.5), Padding = new Thickness(0) }; Grid g = new Grid(); if (!String.IsNullOrWhiteSpace(game.Cover) && File.Exists(game.Cover)) { try { g.Children.Add(new Image { Source=LoadBitmap(game.Cover), Stretch=Stretch.UniformToFill, Margin=new Thickness(5) }); } catch {} } if (g.Children.Count==0) g.Children.Add(new TextBlock { Text="Wii U", FontSize=26, Foreground=new SolidColorBrush(Color.FromRgb(28,145,190)), HorizontalAlignment=HorizontalAlignment.Center, VerticalAlignment=VerticalAlignment.Center }); Border cap=new Border { Height=38, VerticalAlignment=VerticalAlignment.Bottom, Background=new SolidColorBrush(Color.FromArgb(235,250,253,255)), Padding=new Thickness(5) }; cap.Child=new TextBlock { Text=game.Name, FontSize=10, FontWeight=FontWeights.SemiBold, Foreground=new SolidColorBrush(Color.FromRgb(57,75,82)), TextTrimming=TextTrimming.CharacterEllipsis, HorizontalAlignment=HorizontalAlignment.Center }; g.Children.Add(cap); b.Content=g; b.Click+=delegate { invoke(); }; return b;
        }

        private Button CreateWiiURoundSystemButton(string text, Action invoke)
        {
            Button b = new Button { MinWidth=230, Height=58, Margin=new Thickness(12,4,12,4), Background=Brushes.White, BorderBrush=new SolidColorBrush(Color.FromRgb(44,163,205)), BorderThickness=new Thickness(2), RenderTransformOrigin=new Point(0.5,0.5), Content=new TextBlock { Text=text, FontSize=16, Foreground=new SolidColorBrush(Color.FromRgb(53,79,88)), HorizontalAlignment=HorizontalAlignment.Center } }; b.Click+=delegate { invoke(); }; return b;
        }

        private void RenderSwitchHomeAuthentic()
        {
            titleText.Text = String.Empty; subtitleText.Text = String.Empty; switchSoftwareActionCount=0; switchSystemActionStart=0;
            Grid body = new Grid { Margin = new Thickness(54, 22, 54, 18) }; body.RowDefinitions.Add(new RowDefinition { Height=new GridLength(72) }); body.RowDefinitions.Add(new RowDefinition { Height=new GridLength(1,GridUnitType.Star) }); body.RowDefinitions.Add(new RowDefinition { Height=new GridLength(112) }); contentHost.Children.Add(body);
            Grid status=new Grid(); status.ColumnDefinitions.Add(new ColumnDefinition()); status.ColumnDefinitions.Add(new ColumnDefinition()); StackPanel user=new StackPanel { Orientation=Orientation.Horizontal, VerticalAlignment=VerticalAlignment.Center }; Border avatar=new Border { Width=48,Height=48,CornerRadius=new CornerRadius(24),Background=new SolidColorBrush(Color.FromRgb(230,0,18)),Child=new TextBlock { Text=Environment.UserName.Length>0?Environment.UserName.Substring(0,1).ToUpperInvariant():"U",FontSize=23,FontWeight=FontWeights.Bold,Foreground=Brushes.White,HorizontalAlignment=HorizontalAlignment.Center,VerticalAlignment=VerticalAlignment.Center } }; user.Children.Add(avatar); user.Children.Add(new TextBlock { Text=Environment.UserName,FontSize=16,Foreground=Brushes.White,VerticalAlignment=VerticalAlignment.Center,Margin=new Thickness(12,0,0,0) }); status.Children.Add(user); TextBlock clock=new TextBlock { Text=DateTime.Now.ToString("h:mm tt",CultureInfo.CurrentCulture)+"   ◉   100%",FontSize=15,Foreground=Brushes.White,HorizontalAlignment=HorizontalAlignment.Right,VerticalAlignment=VerticalAlignment.Center }; Grid.SetColumn(clock,1); status.Children.Add(clock); body.Children.Add(status);
            ScrollViewer scroller=new ScrollViewer { HorizontalScrollBarVisibility=ScrollBarVisibility.Hidden,VerticalScrollBarVisibility=ScrollBarVisibility.Disabled,Margin=new Thickness(0,10,0,8) }; StackPanel software=new StackPanel { Orientation=Orientation.Horizontal,VerticalAlignment=VerticalAlignment.Center }; scroller.Content=software; Grid.SetRow(scroller,1); body.Children.Add(scroller);
            int visible=Math.Min(12,games.Count); for(int i=0;i<visible;i++){ConsolePlatformGame game=games[i];ConsolePlatformGame captured=game;Button tile=CreateSwitchSoftwareTile(game,delegate{LaunchGame(captured,false);});software.Children.Add(tile);actions.Add(new ConsolePlatformAction{Button=tile,Invoke=delegate{LaunchGame(captured,false);},Name=game.Name,Game=game});}
            if(games.Count>12){Button all=CreateSwitchSystemTile("ALL","All Software",delegate{dashboardSubpage="switch-all";selected=0;RenderSwitchAllSoftware();UpdateActionVisuals();},120);software.Children.Add(all);actions.Add(new ConsolePlatformAction{Button=all,Invoke=delegate{dashboardSubpage="switch-all";selected=0;contentHost.Children.Clear();actions.Clear();RenderSwitchAllSoftware();UpdateActionVisuals();},Name="All Software"});}
            if(actions.Count==0){Button add=CreateSwitchSystemTile("+","No Software",delegate{dashboardSubpage="switch-settings";selected=0;contentHost.Children.Clear();actions.Clear();RenderSettings();UpdateActionVisuals();},180);software.Children.Add(add);actions.Add(new ConsolePlatformAction{Button=add,Invoke=delegate{dashboardSubpage="switch-settings";selected=0;contentHost.Children.Clear();actions.Clear();RenderSettings();UpdateActionVisuals();},Name="No Software"});}
            switchSoftwareActionCount=actions.Count; switchSystemActionStart=actions.Count;
            StackPanel system=new StackPanel { Orientation=Orientation.Horizontal,HorizontalAlignment=HorizontalAlignment.Center,VerticalAlignment=VerticalAlignment.Center }; AddSwitchSystemAction(system,"●","Nintendo Switch Online",delegate{ShowNotice("Nintendo Switch Online is represented for HOME Menu fidelity; online services remain with the emulator/provider.");}); AddSwitchSystemAction(system,"N","News",delegate{ShowNotice("News is not provided by the local emulator shell.");}); AddSwitchSystemAction(system,"▣","eShop",delegate{ShowNotice("Nintendo eShop is not exposed through the local emulator shell.");}); AddSwitchSystemAction(system,"□","Album",OpenFirstSaveRoot); AddSwitchSystemAction(system,"↔","GameShare",delegate{ShowNotice("GameShare is represented for current HOME Menu fidelity; local software sharing is not provided by the emulator shell.");}); AddSwitchSystemAction(system,"◫","Controllers",delegate{ShowNotice("Controller routing is managed by Huymaier Console.");}); AddSwitchSystemAction(system,"▤","Virtual Game Card",delegate{ShowNotice("Virtual Game Cards are represented for current HOME Menu fidelity; installed emulator titles remain managed by Huymaier Console.");}); AddSwitchSystemAction(system,"⚙","System Settings",delegate{dashboardSubpage="switch-settings";selected=0;contentHost.Children.Clear();actions.Clear();RenderSettings();UpdateActionVisuals();}); AddSwitchSystemAction(system,"◐","Sleep Mode",delegate{ShowNotice("Use Huymaier Console Power for Windows sleep and shutdown.");}); Grid.SetRow(system,2);body.Children.Add(system);
            int sysCount=Math.Max(0,actions.Count-switchSystemActionStart); switchSoftwareIndex=Math.Min(Math.Max(0,switchSoftwareActionCount-1),switchSoftwareIndex); switchSystemIndex=Math.Min(Math.Max(0,sysCount-1),switchSystemIndex); selected=switchZone==0?switchSoftwareIndex:Math.Min(actions.Count-1,switchSystemActionStart+switchSystemIndex);
        }

        private Button CreateSwitchSoftwareTile(ConsolePlatformGame game, Action invoke)
        {
            Button b=new Button { Width=244,Height=244,Margin=new Thickness(9),Padding=new Thickness(0),Background=new SolidColorBrush(Color.FromRgb(55,56,61)),BorderBrush=new SolidColorBrush(Color.FromRgb(100,101,106)),BorderThickness=new Thickness(2),RenderTransformOrigin=new Point(0.5,0.5) };Grid g=new Grid();if(!String.IsNullOrWhiteSpace(game.Cover)&&File.Exists(game.Cover)){try{g.Children.Add(new Image{Source=LoadBitmap(game.Cover),Stretch=Stretch.UniformToFill});}catch{}}if(g.Children.Count==0)g.Children.Add(new TextBlock{Text="Nintendo\nSwitch",FontSize=28,Foreground=Brushes.White,TextAlignment=TextAlignment.Center,HorizontalAlignment=HorizontalAlignment.Center,VerticalAlignment=VerticalAlignment.Center});Border cap=new Border{Height=54,VerticalAlignment=VerticalAlignment.Bottom,Background=new SolidColorBrush(Color.FromArgb(225,27,28,31)),Padding=new Thickness(8)};cap.Child=new TextBlock{Text=game.Name,FontSize=12,Foreground=Brushes.White,TextTrimming=TextTrimming.CharacterEllipsis,HorizontalAlignment=HorizontalAlignment.Center};g.Children.Add(cap);b.Content=g;b.Click+=delegate{invoke();};return b;
        }

        private Button CreateSwitchSystemTile(string glyph,string title,Action invoke,double size)
        {
            Button b=new Button{Width=size,Height=size,Margin=new Thickness(8),Background=Brushes.Transparent,BorderBrush=new SolidColorBrush(Color.FromRgb(129,130,135)),BorderThickness=new Thickness(2),RenderTransformOrigin=new Point(0.5,0.5)};StackPanel s=new StackPanel{VerticalAlignment=VerticalAlignment.Center};s.Children.Add(new TextBlock{Text=glyph,FontSize=Math.Max(24,size*0.32),Foreground=Brushes.White,HorizontalAlignment=HorizontalAlignment.Center});s.Children.Add(new TextBlock{Text=title,FontSize=10,Foreground=new SolidColorBrush(Color.FromRgb(216,217,221)),HorizontalAlignment=HorizontalAlignment.Center,TextTrimming=TextTrimming.CharacterEllipsis,MaxWidth=Math.Max(60,size-12)});b.Content=s;b.Click+=delegate{invoke();};return b;
        }

        private void AddSwitchSystemAction(Panel panel,string glyph,string title,Action invoke)
        {
            Button b=CreateSwitchSystemTile(glyph,title,invoke,78);panel.Children.Add(b);actions.Add(new ConsolePlatformAction{Button=b,Invoke=invoke,Name=title});
        }

        private void RenderSwitchAllSoftware()
        {
            titleText.Text="All Software";subtitleText.Text=games.Count.ToString(CultureInfo.InvariantCulture)+" titles";columns=6;ScrollViewer scroll=new ScrollViewer{VerticalScrollBarVisibility=ScrollBarVisibility.Hidden,HorizontalScrollBarVisibility=ScrollBarVisibility.Disabled};WrapPanel wrap=new WrapPanel{Margin=new Thickness(10)};scroll.Content=wrap;contentHost.Children.Add(scroll);foreach(ConsolePlatformGame game in games){ConsolePlatformGame captured=game;Button b=CreateGameButton(game,delegate{LaunchGame(captured,false);});wrap.Children.Add(b);actions.Add(new ConsolePlatformAction{Button=b,Invoke=delegate{LaunchGame(captured,false);},Name=game.Name,Game=game});}
        }

        private void RenderXboxRoot()
        {
            string[] names=new string[]{"play game","memory","music","xbox live","settings"};string[] detail=new string[]{games.Count.ToString(CultureInfo.InvariantCulture)+" titles ready to launch","saved games and storage","soundtracks and dashboard ambience","network and service settings","console and emulator options"};titleText.Text=names[Math.Max(0,Math.Min(page,names.Length-1))];subtitleText.Text=detail[Math.Max(0,Math.Min(page,detail.Length-1))];
            Grid scene=new Grid{Margin=new Thickness(24,8,24,18)};contentHost.Children.Add(scene);Border glow=new Border{Width=420,Height=240,CornerRadius=new CornerRadius(120),Background=new RadialGradientBrush(Color.FromArgb(220,74,192,30),Color.FromArgb(235,0,20,0)),BorderBrush=new SolidColorBrush(Color.FromRgb(113,238,61)),BorderThickness=new Thickness(3),HorizontalAlignment=HorizontalAlignment.Center,VerticalAlignment=VerticalAlignment.Center};StackPanel s=new StackPanel{VerticalAlignment=VerticalAlignment.Center};s.Children.Add(new TextBlock{Text=names[page].ToUpperInvariant(),FontSize=44,FontWeight=FontWeights.Bold,Foreground=Brushes.White,HorizontalAlignment=HorizontalAlignment.Center});s.Children.Add(new TextBlock{Text="A  select",FontSize=14,Foreground=new SolidColorBrush(Color.FromRgb(173,231,145)),HorizontalAlignment=HorizontalAlignment.Center,Margin=new Thickness(0,16,0,0)});glow.Child=s;scene.Children.Add(glow);
        }

        private void RenderXboxGamesAuthentic()
        {
            titleText.Text = "games"; subtitleText.Text = games.Count.ToString(CultureInfo.InvariantCulture) + " titles on the Xbox hard disk";
            Grid body = new Grid { Margin = new Thickness(2, 0, 2, 8) }; body.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(0.68, GridUnitType.Star) }); body.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(0.32, GridUnitType.Star) }); contentHost.Children.Add(body);
            ScrollViewer scroll = new ScrollViewer { VerticalScrollBarVisibility = ScrollBarVisibility.Hidden, HorizontalScrollBarVisibility = ScrollBarVisibility.Disabled, Margin = new Thickness(0, 4, 18, 0) };
            WrapPanel covers = new WrapPanel { Margin = new Thickness(2, 2, 2, 12) }; scroll.Content = covers; body.Children.Add(scroll);
            foreach (ConsolePlatformGame game in games)
            {
                ConsolePlatformGame captured = game; Button tile = CreateXboxCoverTile(game, delegate { LaunchGame(captured, false); }); covers.Children.Add(tile); actions.Add(new ConsolePlatformAction { Button = tile, Invoke = delegate { LaunchGame(captured, false); }, Name = game.Name, Game = game });
            }
            if (games.Count == 0)
            {
                Button empty = CreateXboxPanelRow("add games", "choose a library folder in settings", delegate { page = GetSettingsPageIndex(); selected = 0; RenderPage(); }, "+"); covers.Children.Add(empty); actions.Add(new ConsolePlatformAction { Button = empty, Invoke = delegate { page = GetSettingsPageIndex(); selected = 0; RenderPage(); }, Name = "Add games" });
            }
            Border preview = new Border { Margin = new Thickness(4, 8, 0, 8), Padding = new Thickness(20), Background = new RadialGradientBrush(Color.FromArgb(218, 36, 132, 12), Color.FromArgb(238, 0, 20, 0)), BorderBrush = new SolidColorBrush(Color.FromArgb(190, 141, 255, 91)), BorderThickness = new Thickness(3), CornerRadius = new CornerRadius(80, 10, 10, 80) }; Grid.SetColumn(preview, 1); body.Children.Add(preview);
            Grid info = new Grid(); info.RowDefinitions.Add(new RowDefinition { Height = new GridLength(1, GridUnitType.Star) }); info.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
            xboxPreviewImage = new Image { Width = 220, Height = 320, Stretch = Stretch.Uniform, HorizontalAlignment = HorizontalAlignment.Center, VerticalAlignment = VerticalAlignment.Center }; info.Children.Add(xboxPreviewImage);
            StackPanel words = new StackPanel { Margin = new Thickness(8, 14, 8, 4) }; xboxPreviewTitle = new TextBlock { FontSize = 25, FontWeight = FontWeights.Bold, Foreground = Brushes.White, TextWrapping = TextWrapping.Wrap, TextAlignment = TextAlignment.Center }; xboxPreviewDetail = new TextBlock { Text = "A  Play     X  Alternate", FontSize = 13, Foreground = new SolidColorBrush(Color.FromRgb(167, 229, 142)), HorizontalAlignment = HorizontalAlignment.Center, Margin = new Thickness(0, 8, 0, 0) }; words.Children.Add(xboxPreviewTitle); words.Children.Add(xboxPreviewDetail); Grid.SetRow(words, 1); info.Children.Add(words); preview.Child = info; UpdateXboxGamePreview();
        }

        private Button CreateXboxCoverTile(ConsolePlatformGame game, Action invoke)
        {
            Button tile = new Button { Width = 172, Height = 246, Margin = new Thickness(0, 0, 12, 12), Padding = new Thickness(0), Background = new SolidColorBrush(Color.FromRgb(1, 20, 1)), BorderBrush = new SolidColorBrush(Color.FromRgb(96, 197, 24)), BorderThickness = new Thickness(2), RenderTransformOrigin = new Point(0.5, 0.5) };
            Grid grid = new Grid(); grid.RowDefinitions.Add(new RowDefinition { Height = new GridLength(1, GridUnitType.Star) }); grid.RowDefinitions.Add(new RowDefinition { Height = new GridLength(46) });
            if (!String.IsNullOrWhiteSpace(game.Cover) && File.Exists(game.Cover)) { try { grid.Children.Add(new Image { Source = LoadBitmap(game.Cover), Stretch = Stretch.UniformToFill }); } catch { } }
            if (grid.Children.Count == 0) grid.Children.Add(new TextBlock { Text = "XBOX", FontSize = 31, FontWeight = FontWeights.Bold, FontStyle = FontStyles.Italic, Foreground = Brushes.White, HorizontalAlignment = HorizontalAlignment.Center, VerticalAlignment = VerticalAlignment.Center });
            Border caption = new Border { Background = new LinearGradientBrush(Color.FromArgb(245, 0, 41, 0), Color.FromArgb(245, 0, 16, 0), 90), Padding = new Thickness(8, 5, 8, 4) }; caption.Child = new TextBlock { Text = game.Name, FontSize = 12, FontWeight = FontWeights.SemiBold, Foreground = Brushes.White, TextWrapping = TextWrapping.Wrap, TextTrimming = TextTrimming.CharacterEllipsis }; Grid.SetRow(caption, 1); grid.Children.Add(caption); tile.Content = grid; tile.Click += delegate { invoke(); }; return tile;
        }


        private Button CreateXboxDashboardRow(ConsolePlatformGame game, Action invoke)
        {
            Button row = new Button { Height = 86, Margin = new Thickness(0, 0, 0, 8), Padding = new Thickness(12, 7, 18, 7), Background = new LinearGradientBrush(Color.FromArgb(218, 18, 91, 7), Color.FromArgb(228, 0, 31, 0), 0), BorderBrush = new SolidColorBrush(Color.FromArgb(150, 130, 255, 84)), BorderThickness = new Thickness(2), HorizontalContentAlignment = HorizontalAlignment.Stretch, RenderTransformOrigin = new Point(0.5, 0.5) };
            Grid grid = new Grid(); grid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(72) }); grid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
            Border icon = new Border { Width = 62, Height = 62, Background = new SolidColorBrush(Color.FromRgb(3, 24, 2)), BorderBrush = new SolidColorBrush(Color.FromRgb(107, 213, 48)), BorderThickness = new Thickness(1) };
            if (!String.IsNullOrWhiteSpace(game.Cover) && File.Exists(game.Cover)) { try { icon.Child = new Image { Source = LoadBitmap(game.Cover), Stretch = Stretch.UniformToFill }; } catch { } }
            if (icon.Child == null) icon.Child = new TextBlock { Text = "X", FontSize = 30, FontWeight = FontWeights.Bold, Foreground = Brushes.White, HorizontalAlignment = HorizontalAlignment.Center, VerticalAlignment = VerticalAlignment.Center };
            grid.Children.Add(icon); StackPanel words = new StackPanel { Margin = new Thickness(14, 7, 0, 0) }; words.Children.Add(new TextBlock { Text = game.Name, FontSize = 23, FontWeight = FontWeights.Bold, Foreground = Brushes.White, TextTrimming = TextTrimming.CharacterEllipsis }); words.Children.Add(new TextBlock { Text = "A  launch title", FontSize = 12, Foreground = new SolidColorBrush(Color.FromRgb(164, 226, 140)) }); Grid.SetColumn(words, 1); grid.Children.Add(words); row.Content = grid; row.Click += delegate { invoke(); }; return row;
        }

        private Button CreateXboxPanelRow(string title, string subtitle, Action invoke, string glyph)
        {
            Button row = new Button { MinHeight = 88, Margin = new Thickness(0, 0, 0, 9), Padding = new Thickness(16, 10, 18, 10), Background = new LinearGradientBrush(Color.FromArgb(224, 22, 101, 8), Color.FromArgb(235, 0, 30, 0), 0), BorderBrush = new SolidColorBrush(Color.FromArgb(150, 137, 255, 88)), BorderThickness = new Thickness(2), HorizontalContentAlignment = HorizontalAlignment.Stretch, RenderTransformOrigin = new Point(0.5, 0.5) };
            Grid grid = new Grid(); grid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(72) }); grid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
            Border orb = new Border { Width = 58, Height = 58, CornerRadius = new CornerRadius(29), Background = new RadialGradientBrush(Color.FromRgb(116, 239, 54), Color.FromRgb(0, 30, 0)), BorderBrush = new SolidColorBrush(Color.FromRgb(177, 255, 142)), BorderThickness = new Thickness(2) }; orb.Child = new TextBlock { Text = glyph, FontSize = 24, FontWeight = FontWeights.Bold, Foreground = Brushes.White, HorizontalAlignment = HorizontalAlignment.Center, VerticalAlignment = VerticalAlignment.Center }; grid.Children.Add(orb);
            StackPanel words = new StackPanel { Margin = new Thickness(16, 5, 0, 0) }; words.Children.Add(new TextBlock { Text = title, FontSize = 23, FontWeight = FontWeights.Bold, Foreground = Brushes.White, TextTrimming = TextTrimming.CharacterEllipsis }); words.Children.Add(new TextBlock { Text = subtitle ?? String.Empty, FontSize = 13, Foreground = new SolidColorBrush(Color.FromRgb(164, 226, 140)), TextTrimming = TextTrimming.CharacterEllipsis }); Grid.SetColumn(words, 1); grid.Children.Add(words); row.Content = grid; row.Click += delegate { invoke(); }; return row;
        }

        private void RenderBladesGamesAuthentic()
        {
            titleText.Text = "games"; subtitleText.Text = games.Count.ToString(CultureInfo.InvariantCulture) + " titles  •  LEFT / RIGHT changes blade";
            StackPanel list = new StackPanel { Margin = new Thickness(2, 0, 6, 18) };
            ScrollViewer scroll = new ScrollViewer { VerticalScrollBarVisibility = ScrollBarVisibility.Hidden, HorizontalScrollBarVisibility = ScrollBarVisibility.Disabled, Content = list }; contentHost.Children.Add(scroll);
            foreach (ConsolePlatformGame game in games)
            {
                ConsolePlatformGame captured = game;
                Button row = CreateBladePanelButton(game.Name, "A  play     X  alternate emulator", delegate { LaunchGame(captured, false); }, Color.FromRgb(83, 156, 44));
                list.Children.Add(row); actions.Add(new ConsolePlatformAction { Button = row, Invoke = delegate { LaunchGame(captured, false); }, Name = game.Name, Game = game });
            }
            if (games.Count == 0)
            {
                Button empty = CreateBladePanelButton("no games found", "configure a game folder in System", delegate { page = 3; selected = 0; BuildChrome(); RenderPage(); }, Color.FromRgb(83, 156, 44));
                list.Children.Add(empty); actions.Add(new ConsolePlatformAction { Button = empty, Invoke = delegate { page = 3; selected = 0; BuildChrome(); RenderPage(); }, Name = "System" });
            }
        }

        private Button CreateBladeCoverTile(ConsolePlatformGame game, Action invoke)
        {
            Button tile = new Button { Width = 154, Height = 220, Margin = new Thickness(6), Padding = new Thickness(0), Background = new SolidColorBrush(Color.FromRgb(224, 227, 225)), BorderBrush = new SolidColorBrush(Color.FromArgb(220, 255, 255, 255)), BorderThickness = new Thickness(3), RenderTransformOrigin = new Point(0.5, 0.5) };
            Grid grid = new Grid(); grid.RowDefinitions.Add(new RowDefinition { Height = new GridLength(1, GridUnitType.Star) }); grid.RowDefinitions.Add(new RowDefinition { Height = new GridLength(42) });
            if (!String.IsNullOrWhiteSpace(game.Cover) && File.Exists(game.Cover)) { try { grid.Children.Add(new Image { Source = LoadBitmap(game.Cover), Stretch = Stretch.UniformToFill }); } catch { } }
            if (grid.Children.Count == 0) grid.Children.Add(new TextBlock { Text = "XBOX 360", FontSize = 23, FontWeight = FontWeights.Light, Foreground = new SolidColorBrush(Color.FromRgb(82, 157, 46)), HorizontalAlignment = HorizontalAlignment.Center, VerticalAlignment = VerticalAlignment.Center });
            Border caption = new Border { Background = new LinearGradientBrush(Color.FromArgb(245, 248, 249, 248), Color.FromArgb(245, 185, 190, 187), 90), Padding = new Thickness(7, 4, 7, 3) }; caption.Child = new TextBlock { Text = game.Name, FontSize = 11, FontWeight = FontWeights.SemiBold, Foreground = new SolidColorBrush(Color.FromRgb(39, 45, 42)), TextWrapping = TextWrapping.Wrap, TextTrimming = TextTrimming.CharacterEllipsis }; Grid.SetRow(caption, 1); grid.Children.Add(caption); tile.Content = grid; tile.Click += delegate { invoke(); }; return tile;
        }


        private void RenderMetroGamesAuthentic()
        {
            titleText.Text = "games"; subtitleText.Text = "My Games";
            Grid body = new Grid { Margin = new Thickness(0, 0, 0, 10) }; body.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(245) }); body.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) }); contentHost.Children.Add(body);
            StackPanel rail = new StackPanel { Margin = new Thickness(0, 5, 10, 0) }; body.Children.Add(rail);
            AddDashboardTile(rail, "My Games", games.Count.ToString(CultureInfo.InvariantCulture) + " titles", delegate { }, Color.FromRgb(17, 168, 31), 230, 135, "▰");
            AddDashboardTile(rail, "Achievements", GetXboxGamerscore().ToString(CultureInfo.InvariantCulture) + " G", OpenXboxAchievements, Color.FromRgb(21, 155, 34), 230, 135, "★");
            AddDashboardTile(rail, "Storage", "Manage saved games", OpenXboxStorageManager, Color.FromRgb(16, 139, 32), 230, 135, "▣");
            ScrollViewer scroll = new ScrollViewer { VerticalScrollBarVisibility = ScrollBarVisibility.Hidden, HorizontalScrollBarVisibility = ScrollBarVisibility.Disabled }; Grid.SetColumn(scroll, 1); body.Children.Add(scroll); WrapPanel tiles = new WrapPanel { Margin = new Thickness(0, 0, 0, 12) }; scroll.Content = tiles;
            for (int i = 0; i < games.Count; i++) { ConsolePlatformGame game = games[i]; ConsolePlatformGame captured = game; bool hero = i == 0; Button tile = CreateMetroGameTile(game, hero, delegate { LaunchGame(captured, false); }); tiles.Children.Add(tile); actions.Add(new ConsolePlatformAction { Button = tile, Invoke = delegate { LaunchGame(captured, false); }, Name = game.Name, Game = game }); }
            if (games.Count == 0) AddDashboardTile(tiles, "add games", "choose a library folder in settings", delegate { page = 6; selected = 0; RenderPage(); }, Color.FromRgb(107, 181, 43), 430, 215, "+");
        }


        private Button CreateMetroGameTile(ConsolePlatformGame game, bool hero, Action invoke)
        {
            double width = hero ? 438 : 212; double height = 212; Button tile = new Button { Width = width, Height = height, Margin = new Thickness(6), Padding = new Thickness(0), Background = new SolidColorBrush(Color.FromRgb(52, 122, 35)), BorderBrush = new SolidColorBrush(Color.FromArgb(105, 255, 255, 255)), BorderThickness = new Thickness(1), RenderTransformOrigin = new Point(0.5, 0.5) }; Grid grid = new Grid();
            if (!String.IsNullOrWhiteSpace(game.Cover) && File.Exists(game.Cover)) { try { grid.Children.Add(new Image { Source = LoadBitmap(game.Cover), Stretch = Stretch.UniformToFill }); } catch { } }
            if (grid.Children.Count == 0) grid.Children.Add(new TextBlock { Text = "XBOX 360", FontSize = hero ? 48 : 28, FontWeight = FontWeights.Light, Foreground = Brushes.White, HorizontalAlignment = HorizontalAlignment.Center, VerticalAlignment = VerticalAlignment.Center });
            Border shade = new Border { Height = 62, VerticalAlignment = VerticalAlignment.Bottom, Background = new LinearGradientBrush(Color.FromArgb(0, 0, 0, 0), Color.FromArgb(235, 0, 0, 0), 90) }; grid.Children.Add(shade); grid.Children.Add(new TextBlock { Text = game.Name, FontSize = hero ? 22 : 15, FontWeight = FontWeights.SemiBold, Foreground = Brushes.White, VerticalAlignment = VerticalAlignment.Bottom, Margin = new Thickness(14, 0, 12, 16), TextTrimming = TextTrimming.CharacterEllipsis }); tile.Content = grid; tile.Click += delegate { invoke(); }; return tile;
        }

        private Button CreateBladePanelButton(string title, string subtitle, Action invoke, Color accent)
        {
            Button row = new Button { MinHeight = 92, Margin = new Thickness(0, 0, 0, 10), Padding = new Thickness(20, 13, 20, 13), Background = new LinearGradientBrush(Color.FromRgb(242, 244, 243), Color.FromRgb(169, 175, 172), 90), BorderBrush = new SolidColorBrush(Color.FromArgb(190, 255, 255, 255)), BorderThickness = new Thickness(2), HorizontalContentAlignment = HorizontalAlignment.Stretch, RenderTransformOrigin = new Point(0.5, 0.5) }; Grid grid = new Grid(); grid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(12) }); grid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) }); Border stripe = new Border { Background = new SolidColorBrush(accent), Margin = new Thickness(0, 0, 12, 0) }; grid.Children.Add(stripe); StackPanel words = new StackPanel { Margin = new Thickness(18, 0, 0, 0) }; words.Children.Add(new TextBlock { Text = title, FontSize = 24, FontWeight = FontWeights.SemiBold, Foreground = new SolidColorBrush(Color.FromRgb(41, 47, 44)) }); words.Children.Add(new TextBlock { Text = subtitle ?? String.Empty, FontSize = 13, Foreground = new SolidColorBrush(Color.FromRgb(79, 88, 83)), TextTrimming = TextTrimming.CharacterEllipsis }); Grid.SetColumn(words, 1); grid.Children.Add(words); row.Content = grid; row.Click += delegate { invoke(); }; return row;
        }

        private Button CreateGameButton(ConsolePlatformGame game, Action invoke)
        {
            bool square = definition.Shell == "N64" || definition.Shell == "GameCube" || definition.Shell == "Wii" || definition.Shell == "WiiU" || definition.Shell == "Switch" || IsMetro();
            double width = definition.Shell == "Xbox" ? 188 : (IsBlades() ? 184 : (square ? 202 : 170));
            double height = definition.Shell == "Xbox" ? 268 : (IsBlades() ? 258 : (square ? 202 : 248));
            Button button = new Button { Width = width, Height = height, Margin = new Thickness(0, 0, 14, 14), Padding = new Thickness(0), BorderThickness = new Thickness(2), RenderTransformOrigin = new Point(0.5, 0.5), Cursor = Cursors.Hand };
            if (definition.Shell == "N64") { button.Background = new SolidColorBrush(Color.FromRgb(54, 55, 62)); button.BorderBrush = new SolidColorBrush(Color.FromRgb(241, 194, 38)); }
            else if (definition.Shell == "GameCube") { button.Background = new SolidColorBrush(Color.FromRgb(44, 31, 98)); button.BorderBrush = new SolidColorBrush(Color.FromRgb(143, 118, 255)); }
            else if (definition.Shell == "Wii" || definition.Shell == "WiiU") { button.Background = Brushes.White; button.BorderBrush = new SolidColorBrush(Color.FromRgb(114, 198, 221)); }
            else if (definition.Shell == "Switch") { button.Background = new SolidColorBrush(Color.FromRgb(57, 58, 63)); button.BorderBrush = new SolidColorBrush(Color.FromRgb(230, 0, 18)); }
            else if (definition.Shell == "Xbox") { button.Background = new SolidColorBrush(Color.FromRgb(3, 32, 2)); button.BorderBrush = new SolidColorBrush(Color.FromRgb(96, 197, 24)); }
            else if (IsBlades()) { button.Background = new SolidColorBrush(Color.FromRgb(31, 37, 40)); button.BorderBrush = new SolidColorBrush(Color.FromRgb(101, 181, 44)); }
            else if (IsMetro()) { button.Background = new SolidColorBrush(Color.FromRgb(54, 124, 34)); button.BorderBrush = Brushes.White; }
            else { button.Background = IsLightShell() ? Brushes.White : new SolidColorBrush(Color.FromRgb(18, 22, 27)); button.BorderBrush = IsLightShell() ? new SolidColorBrush(Color.FromRgb(165, 190, 201)) : new SolidColorBrush(Color.FromArgb(65, 255, 255, 255)); }
            Grid grid = new Grid();
            grid.RowDefinitions.Add(new RowDefinition { Height = new GridLength(1, GridUnitType.Star) });
            grid.RowDefinitions.Add(new RowDefinition { Height = new GridLength(52) });
            if (!String.IsNullOrWhiteSpace(game.Cover) && File.Exists(game.Cover))
            {
                Image image = new Image { Stretch = Stretch.UniformToFill };
                try { image.Source = LoadBitmap(game.Cover); } catch { }
                grid.Children.Add(image);
            }
            else
            {
                Border placeholder = new Border { Background = new SolidColorBrush(Color.FromArgb(150, definition.Accent.R, definition.Accent.G, definition.Accent.B)) };
                placeholder.Child = new TextBlock { Text = definition.Shell == "N64" ? "64" : definition.DisplayName.Substring(0, Math.Min(2, definition.DisplayName.Length)).ToUpperInvariant(), FontSize = 50, FontWeight = FontWeights.Bold, Foreground = Brushes.White, HorizontalAlignment = HorizontalAlignment.Center, VerticalAlignment = VerticalAlignment.Center };
                grid.Children.Add(placeholder);
            }
            Border caption = new Border { Background = IsLightShell() ? new SolidColorBrush(Color.FromArgb(240, 245, 248, 250)) : new SolidColorBrush(Color.FromArgb(235, 3, 5, 8)), Padding = new Thickness(10, 6, 10, 5) };
            caption.Child = new TextBlock { Text = game.Name, FontSize = 13, FontWeight = FontWeights.SemiBold, TextWrapping = TextWrapping.Wrap, TextTrimming = TextTrimming.CharacterEllipsis, Foreground = IsLightShell() ? new SolidColorBrush(Color.FromRgb(45, 58, 63)) : Brushes.White };
            Grid.SetRow(caption, 1); grid.Children.Add(caption);
            button.Content = grid;
            button.Click += delegate { invoke(); };
            return button;
        }

        private void RenderXboxMusic()
        {
            titleText.Text = "music"; subtitleText.Text = "Soundtracks and dashboard ambience";
            WrapPanel panel = new WrapPanel { Margin = new Thickness(14) }; contentHost.Children.Add(panel);
            AddDashboardTile(panel, "soundtracks", String.IsNullOrWhiteSpace(settings.ambiencePath) ? "choose dashboard music" : Path.GetFileName(settings.ambiencePath), ChooseAmbience, Color.FromRgb(45, 117, 22), 330, 170, "♪");
            AddDashboardTile(panel, settings.ambienceEnabled ? "music on" : "music off", "toggle dashboard ambience", delegate { settings.ambienceEnabled = !settings.ambienceEnabled; settings.Save(settingsPath); StartAmbience(); RenderPage(); }, Color.FromRgb(37, 91, 18), 330, 170, "►");
            AddDashboardTile(panel, "music volume", Math.Round(settings.ambienceVolume * 100).ToString(CultureInfo.InvariantCulture) + "%", CycleAmbienceVolume, Color.FromRgb(27, 72, 13), 330, 170, "+");
        }

        private void RenderXboxLive()
        {
            titleText.Text = "xbox live"; subtitleText.Text = "Original Xbox network and dashboard runtime";
            WrapPanel panel = new WrapPanel { Margin = new Thickness(14) }; contentHost.Children.Add(panel);
            AddDashboardTile(panel, "network settings", "open xemu configuration", delegate { OpenFolderForExecutable(settings.emulatorPath); }, Color.FromRgb(37, 103, 19), 300, 190, "●");
            AddDashboardTile(panel, "games", games.Count.ToString(CultureInfo.InvariantCulture) + " titles", delegate { page = 0; selected = 0; RenderPage(); }, Color.FromRgb(29, 80, 13), 300, 190, "▶");
        }

        private void RenderXbox360Live()
        {
            titleText.Text = "xbox live"; subtitleText.Text = Environment.UserName + "  •  " + GetXboxGamerscore().ToString(CultureInfo.InvariantCulture) + " G"; StackPanel panel = new StackPanel { Margin = new Thickness(4, 0, 4, 16) }; contentHost.Children.Add(new ScrollViewer { VerticalScrollBarVisibility = ScrollBarVisibility.Hidden, Content = panel });
            AddDashboardTile(panel, Environment.UserName, GetXboxGamerscore().ToString(CultureInfo.InvariantCulture) + " Gamerscore", OpenXboxAchievements, Color.FromRgb(226, 111, 16), 620, 142, "★"); AddDashboardTile(panel, "achievements", xboxAchievementsLoaded ? xboxAchievements.Count(delegate(XboxAchievementEntry a) { return a.Earned; }).ToString(CultureInfo.InvariantCulture) + " unlocked" : "view profile achievements", OpenXboxAchievements, Color.FromRgb(206, 92, 8), 620, 142, "G"); AddDashboardTile(panel, "recent games", games.Count.ToString(CultureInfo.InvariantCulture) + " games", delegate { page = 1; selected = 0; BuildChrome(); RenderPage(); }, Color.FromRgb(188, 78, 6), 620, 142, "▶");
        }


        private void RenderXbox360Media()
        {
            titleText.Text = "media"; subtitleText.Text = "Music, video and dashboard media";
            WrapPanel panel = new WrapPanel { Margin = new Thickness(10) }; contentHost.Children.Add(panel);
            AddDashboardTile(panel, "music", String.IsNullOrWhiteSpace(settings.ambiencePath) ? "choose dashboard music" : Path.GetFileName(settings.ambiencePath), ChooseAmbience, Color.FromRgb(56, 126, 183), 350, 185, "♪");
            AddDashboardTile(panel, "video", settings.startupEnabled ? "startup video enabled" : "startup video disabled", delegate { settings.startupEnabled = !settings.startupEnabled; settings.Save(settingsPath); RenderPage(); }, Color.FromRgb(103, 76, 151), 350, 185, "▶");
            AddDashboardTile(panel, "pictures", "open dashboard media", delegate { Process.Start("explorer.exe", "\"" + Path.Combine(platformRoot, "Assets") + "\""); }, Color.FromRgb(232, 116, 18), 350, 185, "▣");
        }

        private void RenderXbox360System()
        {
            titleText.Text = "system"; subtitleText.Text = "console settings and storage"; StackPanel panel = new StackPanel { Margin = new Thickness(4, 0, 4, 16) }; contentHost.Children.Add(new ScrollViewer { VerticalScrollBarVisibility = ScrollBarVisibility.Hidden, Content = panel }); AddDashboardTile(panel, "memory", "manage Xenia saved games", OpenXboxStorageManager, Color.FromRgb(105, 76, 150), 650, 132, "▣"); AddDashboardTile(panel, "console settings", settings.dashboardStyle + " dashboard", delegate { dashboardSubpage = "settings"; selected = 0; RenderPage(); }, Color.FromRgb(93, 66, 137), 650, 132, "⚙"); AddDashboardTile(panel, "achievements", GetXboxGamerscore().ToString(CultureInfo.InvariantCulture) + " G", OpenXboxAchievements, Color.FromRgb(82, 58, 126), 650, 132, "★");
        }


        private void RenderXbox360Apps()
        {
            titleText.Text = "apps"; subtitleText.Text = "Xbox 360 applications and emulator tools";
            WrapPanel panel = new WrapPanel { Margin = new Thickness(8) }; contentHost.Children.Add(panel);
            AddDashboardTile(panel, "Xenia Canary", DisplayPath(settings.emulatorPath), ChoosePrimaryEmulator, Color.FromRgb(107, 181, 43), 380, 190, "X");
            AddDashboardTile(panel, "Xenia Master", DisplayPath(settings.fallbackEmulatorPath), ChooseFallbackEmulator, Color.FromRgb(56, 126, 183), 300, 190, "X");
            AddDashboardTile(panel, "content", "open Xenia content folder", delegate { OpenFirstSaveRoot(); }, Color.FromRgb(112, 82, 161), 300, 190, "▤");
        }

        private void RenderXbox360Music()
        {
            titleText.Text = "music"; subtitleText.Text = "Dashboard music";
            WrapPanel panel = new WrapPanel { Margin = new Thickness(8) }; contentHost.Children.Add(panel);
            AddDashboardTile(panel, "now playing", String.IsNullOrWhiteSpace(settings.ambiencePath) ? "no music selected" : Path.GetFileName(settings.ambiencePath), ChooseAmbience, Color.FromRgb(214, 83, 34), 470, 210, "♪");
            AddDashboardTile(panel, settings.ambienceEnabled ? "pause music" : "play music", Math.Round(settings.ambienceVolume * 100).ToString(CultureInfo.InvariantCulture) + "% volume", delegate { settings.ambienceEnabled = !settings.ambienceEnabled; settings.Save(settingsPath); StartAmbience(); RenderPage(); }, Color.FromRgb(107, 181, 43), 300, 210, "►");
            AddDashboardTile(panel, "volume", Math.Round(settings.ambienceVolume * 100).ToString(CultureInfo.InvariantCulture) + "%", CycleAmbienceVolume, Color.FromRgb(56, 126, 183), 260, 210, "+");
        }

        private void RenderXbox360Video()
        {
            titleText.Text = "video"; subtitleText.Text = "Startup and dashboard video";
            WrapPanel panel = new WrapPanel { Margin = new Thickness(8) }; contentHost.Children.Add(panel);
            AddDashboardTile(panel, "startup video", settings.startupEnabled ? "enabled" : "disabled", delegate { settings.startupEnabled = !settings.startupEnabled; settings.Save(settingsPath); RenderPage(); }, Color.FromRgb(107, 181, 43), 420, 220, "▶");
            AddDashboardTile(panel, "video library", "open startup assets", delegate { Process.Start("explorer.exe", "\"" + Path.Combine(platformRoot, "Assets") + "\""); }, Color.FromRgb(56, 126, 183), 340, 220, "▣");
        }

        private void RenderXbox360Social()
        {
            titleText.Text = "social"; subtitleText.Text = Environment.UserName + "  •  local Xenia profile"; WrapPanel panel = new WrapPanel { Margin = new Thickness(0, 4, 0, 14) }; contentHost.Children.Add(new ScrollViewer { VerticalScrollBarVisibility = ScrollBarVisibility.Hidden, Content = panel }); AddDashboardTile(panel, Environment.UserName, GetXboxGamerscore().ToString(CultureInfo.InvariantCulture) + " G", OpenXboxAchievements, Color.FromRgb(20, 151, 35), 440, 220, "☺"); AddDashboardTile(panel, "achievements", xboxAchievementsLoaded ? xboxAchievements.Count(delegate(XboxAchievementEntry a) { return a.Earned; }).ToString(CultureInfo.InvariantCulture) + " unlocked" : "read Xenia profile", OpenXboxAchievements, Color.FromRgb(20, 137, 34), 215, 220, "★"); AddDashboardTile(panel, "storage", "saved games", OpenXboxStorageManager, Color.FromRgb(53, 91, 51), 215, 220, "▣");
        }


        private void RenderXbox360Bing()
        {
            titleText.Text = "bing"; subtitleText.Text = "Browse the cached Xbox 360 library";
            WrapPanel panel = new WrapPanel { Margin = new Thickness(8) }; contentHost.Children.Add(panel);
            foreach (char letter in "#ABCDEFGHIJKLMNOPQRSTUVWXYZ")
            {
                char captured = letter;
                int count = games.Count(delegate(ConsolePlatformGame g) { char first = String.IsNullOrWhiteSpace(g.Name) ? '#' : Char.ToUpperInvariant(g.Name[0]); return captured == '#' ? !Char.IsLetter(first) : first == captured; });
                if (count == 0) continue;
                AddDashboardTile(panel, captured.ToString(), count.ToString(CultureInfo.InvariantCulture) + " games", delegate { page = 0; selected = FindFirstGameIndex(captured); RenderPage(); }, Color.FromRgb(64, 69, 67), 132, 104, captured.ToString());
            }
        }

        private void RenderInlineSettings()
        {
            contentHost.Children.Clear(); actions.Clear(); RenderSettings(); UpdateActionVisuals();
        }

        private int FindFirstGameIndex(char letter)
        {
            for (int i = 0; i < games.Count; i++)
            {
                char first = String.IsNullOrWhiteSpace(games[i].Name) ? '#' : Char.ToUpperInvariant(games[i].Name[0]);
                if (letter == '#' ? !Char.IsLetter(first) : first == letter) return i;
            }
            return 0;
        }

        private void AddDashboardTile(Panel panel, string title, string subtitle, Action invoke, Color color, double width, double height, string glyph)
        {
            if (IsBlades())
            {
                Button row = CreateBladePanelButton(title, subtitle, invoke, color); row.Width = Math.Max(420, width); panel.Children.Add(row); actions.Add(new ConsolePlatformAction { Button = row, Invoke = invoke, Name = title }); return;
            }
            if (definition.Shell == "Xbox")
            {
                Button row = CreateXboxPanelRow(title, subtitle, invoke, glyph); row.Width = Math.Max(430, width); panel.Children.Add(row); actions.Add(new ConsolePlatformAction { Button = row, Invoke = invoke, Name = title }); return;
            }
            Button tile = new Button { Width = width, Height = height, Margin = new Thickness(7), Padding = new Thickness(20), Background = new SolidColorBrush(color), BorderBrush = new SolidColorBrush(Color.FromArgb(100, 255, 255, 255)), BorderThickness = new Thickness(1), HorizontalContentAlignment = HorizontalAlignment.Stretch, VerticalContentAlignment = VerticalAlignment.Stretch, RenderTransformOrigin = new Point(0.5, 0.5), Cursor = Cursors.Hand };
            Grid grid = new Grid(); grid.RowDefinitions.Add(new RowDefinition { Height = new GridLength(1, GridUnitType.Star) }); grid.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
            TextBlock icon = new TextBlock { Text = glyph, FontSize = height > 180 ? 68 : 48, FontWeight = FontWeights.Light, Foreground = new SolidColorBrush(Color.FromArgb(215, 255, 255, 255)), HorizontalAlignment = HorizontalAlignment.Right, VerticalAlignment = VerticalAlignment.Top }; grid.Children.Add(icon);
            StackPanel words = new StackPanel { VerticalAlignment = VerticalAlignment.Bottom }; words.Children.Add(new TextBlock { Text = title, FontSize = 24, FontWeight = FontWeights.SemiBold, Foreground = Brushes.White, TextTrimming = TextTrimming.CharacterEllipsis }); words.Children.Add(new TextBlock { Text = subtitle ?? String.Empty, FontSize = 12, Foreground = new SolidColorBrush(Color.FromArgb(220, 255, 255, 255)), TextTrimming = TextTrimming.CharacterEllipsis, MaxWidth = Math.Max(80, width - 42) }); Grid.SetRow(words, 1); grid.Children.Add(words); tile.Content = grid; tile.Click += delegate { invoke(); }; panel.Children.Add(tile); actions.Add(new ConsolePlatformAction { Button = tile, Invoke = invoke, Name = title });
        }

        private void RenderSaves()
        {
            List<string> roots = FindSaveRoots();
            if (definition.Shell == "N64") { RenderN64ControllerPak(roots); return; }
            if (definition.Shell == "GameCube") { RenderGameCubeMemoryCards(roots); return; }
            if (definition.Shell == "Wii") { RenderWiiDataManagement(roots); return; }
            if (definition.Shell == "WiiU") { RenderWiiUDataManagement(roots); return; }
            if (definition.Shell == "Switch") { RenderSwitchDataManagement(roots); return; }
            if (definition.Shell == "Xbox") { RenderXboxMemory(roots); return; }
            if (definition.Shell == "Xbox360") { RenderXbox360Storage(roots); return; }
            RenderStorageList("Save Data", roots, "Detected emulator save locations");
        }

        private void RenderN64ControllerPak(List<string> roots)
        {
            titleText.Text = "CONTROLLER PAK"; subtitleText.Text = "Controller Pak notes and 123-page storage";
            Grid grid = new Grid(); grid.RowDefinitions.Add(new RowDefinition { Height = new GridLength(58) }); grid.RowDefinitions.Add(new RowDefinition { Height = new GridLength(1, GridUnitType.Star) }); contentHost.Children.Add(grid);
            Grid header = new Grid { Background = new SolidColorBrush(Color.FromRgb(226, 185, 35)), Margin = new Thickness(18, 0, 18, 6) };
            header.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) }); header.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(180) });
            header.Children.Add(new TextBlock { Text = "NOTE", FontSize = 22, FontWeight = FontWeights.Bold, Foreground = Brushes.Black, VerticalAlignment = VerticalAlignment.Center, Margin = new Thickness(24, 0, 0, 0) });
            TextBlock pages = new TextBlock { Text = "PAGES", FontSize = 22, FontWeight = FontWeights.Bold, Foreground = Brushes.Black, VerticalAlignment = VerticalAlignment.Center, HorizontalAlignment = HorizontalAlignment.Center }; Grid.SetColumn(pages, 1); header.Children.Add(pages); grid.Children.Add(header);
            StackPanel list = new StackPanel { Margin = new Thickness(18, 0, 18, 18) }; ScrollViewer scroll = new ScrollViewer { VerticalScrollBarVisibility = ScrollBarVisibility.Hidden, Content = list }; Grid.SetRow(scroll, 1); grid.Children.Add(scroll);
            foreach (string rootPath in roots) AddStorageRow(list, Path.GetFileName(rootPath.TrimEnd(Path.DirectorySeparatorChar)).ToUpperInvariant(), "OPEN", rootPath, Color.FromRgb(40, 42, 53), Color.FromRgb(241, 194, 38));
            AddStorageRow(list, "BACK UP CONTROLLER PAK", "RUN", "Create a recoverable copy of detected Pak data", Color.FromRgb(40, 42, 53), Color.FromRgb(241, 194, 38), BackupSaves);
        }

        private void RenderGameCubeMemoryCards(List<string> roots)
        {
            titleText.Text = "Memory Card"; subtitleText.Text = "Slot A and Slot B";
            Grid body = new Grid { Margin = new Thickness(26, 6, 26, 20) }; body.ColumnDefinitions.Add(new ColumnDefinition()); body.ColumnDefinitions.Add(new ColumnDefinition()); contentHost.Children.Add(body);
            for (int i = 0; i < 2; i++)
            {
                string path = i < roots.Count ? roots[i] : String.Empty; Border slot = new Border { Margin = new Thickness(18), CornerRadius = new CornerRadius(32), Background = new SolidColorBrush(Color.FromArgb(225, 47, 34, 101)), BorderBrush = new SolidColorBrush(i == 0 ? Color.FromRgb(110, 224, 255) : Color.FromRgb(255, 172, 89)), BorderThickness = new Thickness(4), Padding = new Thickness(26) };
                StackPanel panel = new StackPanel(); panel.Children.Add(new TextBlock { Text = "MEMORY CARD SLOT " + (i == 0 ? "A" : "B"), FontSize = 25, FontWeight = FontWeights.Bold, Foreground = Brushes.White, HorizontalAlignment = HorizontalAlignment.Center });
                panel.Children.Add(new Border { Width = 180, Height = 112, Margin = new Thickness(0, 30, 0, 24), CornerRadius = new CornerRadius(18), Background = new SolidColorBrush(Color.FromRgb(52, 53, 62)), BorderBrush = new SolidColorBrush(Color.FromRgb(169, 166, 184)), BorderThickness = new Thickness(3), Child = new TextBlock { Text = String.IsNullOrWhiteSpace(path) ? "EMPTY" : "CARD", FontSize = 28, Foreground = Brushes.White, HorizontalAlignment = HorizontalAlignment.Center, VerticalAlignment = VerticalAlignment.Center } });
                string captured = path; Button open = CreateShellAction(String.IsNullOrWhiteSpace(path) ? "No card detected" : "Open Card", String.IsNullOrWhiteSpace(path) ? "Configure Dolphin memory cards" : path, delegate { if (!String.IsNullOrWhiteSpace(captured)) Process.Start("explorer.exe", "\"" + captured + "\""); }, Color.FromRgb(91, 70, 176)); panel.Children.Add(open); actions.Add(new ConsolePlatformAction { Button = open, Invoke = delegate { if (!String.IsNullOrWhiteSpace(captured)) Process.Start("explorer.exe", "\"" + captured + "\""); }, Name = "Slot" }); slot.Child = panel; Grid.SetColumn(slot, i); body.Children.Add(slot);
            }
            AddFloatingBackup(body, BackupSaves);
        }

        private void RenderWiiDataManagement(List<string> roots)
        {
            titleText.Text = "Save Data"; subtitleText.Text = "Wii Console and SD Card";
            StackPanel panel = new StackPanel { Margin = new Thickness(26, 4, 26, 20) }; contentHost.Children.Add(new ScrollViewer { VerticalScrollBarVisibility = ScrollBarVisibility.Hidden, Content = panel });
            Grid tabs = new Grid { Height = 64, Margin = new Thickness(0, 0, 0, 20) }; tabs.ColumnDefinitions.Add(new ColumnDefinition()); tabs.ColumnDefinitions.Add(new ColumnDefinition());
            tabs.Children.Add(CreateWiiTab("Wii", true)); Button sd = CreateWiiTab("SD Card", false); Grid.SetColumn(sd, 1); tabs.Children.Add(sd); panel.Children.Add(tabs);
            WrapPanel channels = new WrapPanel(); panel.Children.Add(channels);
            foreach (string rootPath in roots) { string captured = rootPath; Button tile = CreateChannelTile(Path.GetFileName(rootPath.TrimEnd(Path.DirectorySeparatorChar)), captured, delegate { Process.Start("explorer.exe", "\"" + captured + "\""); }); channels.Children.Add(tile); actions.Add(new ConsolePlatformAction { Button = tile, Invoke = delegate { Process.Start("explorer.exe", "\"" + captured + "\""); }, Name = captured }); }
            Button backup = CreateChannelTile("Back Up", "Copy save data", BackupSaves); channels.Children.Add(backup); actions.Add(new ConsolePlatformAction { Button = backup, Invoke = BackupSaves, Name = "Back Up" });
        }

        private void RenderWiiUDataManagement(List<string> roots)
        {
            titleText.Text = "Data Management"; subtitleText.Text = "Copy, move, or delete software and save data";
            StackPanel panel = new StackPanel { Margin = new Thickness(44, 10, 44, 30) }; contentHost.Children.Add(panel);
            foreach (string rootPath in roots) AddRoundedStorage(panel, "System Memory", rootPath, Color.FromRgb(26, 161, 208));
            if (roots.Count == 0) AddRoundedStorage(panel, "System Memory", "No Cemu save directory detected", Color.FromRgb(26, 161, 208));
            AddRoundedStorage(panel, "USB Storage Device", "Back up detected data", Color.FromRgb(98, 190, 78), BackupSaves);
        }

        private void RenderSwitchDataManagement(List<string> roots)
        {
            titleText.Text = "Data Management"; subtitleText.Text = "Save data is stored per user in system memory";
            StackPanel panel = new StackPanel { Margin = new Thickness(54, 8, 54, 28) }; contentHost.Children.Add(new ScrollViewer { VerticalScrollBarVisibility = ScrollBarVisibility.Hidden, Content = panel });
            foreach (string rootPath in roots) AddStorageRow(panel, "Save Data", "OPEN", rootPath, Color.FromRgb(57, 58, 63), Color.FromRgb(230, 0, 18));
            AddStorageRow(panel, "Back Up Save Data", "RUN", "Create a recoverable copy", Color.FromRgb(57, 58, 63), Color.FromRgb(230, 0, 18), BackupSaves);
        }

        private void RenderXboxMemory(List<string> roots)
        {
            titleText.Text = "memory"; subtitleText.Text = "Xbox hard disk and memory units";
            Grid body = new Grid { Margin = new Thickness(16, 0, 16, 18) }; body.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(330) }); body.ColumnDefinitions.Add(new ColumnDefinition()); contentHost.Children.Add(body);
            Grid orbHost = new Grid { Width = 285, Height = 285, VerticalAlignment = VerticalAlignment.Center };
            Border orb = new Border { Width = 270, Height = 270, CornerRadius = new CornerRadius(135), Background = new RadialGradientBrush(Color.FromRgb(111, 235, 47), Color.FromRgb(1, 28, 0)), BorderBrush = new SolidColorBrush(Color.FromRgb(142, 255, 83)), BorderThickness = new Thickness(4), Child = new TextBlock { Text = "XBOX", FontSize = 42, FontWeight = FontWeights.Bold, FontStyle = FontStyles.Italic, Foreground = Brushes.White, HorizontalAlignment = HorizontalAlignment.Center, VerticalAlignment = VerticalAlignment.Center } };
            orbHost.Children.Add(orb); body.Children.Add(orbHost);
            StackPanel list = new StackPanel { VerticalAlignment = VerticalAlignment.Center, Margin = new Thickness(12) }; Grid.SetColumn(list, 1); body.Children.Add(list);
            foreach (string rootPath in roots) AddStorageRow(list, "Xbox Hard Disk", "OPEN", rootPath, Color.FromRgb(3, 39, 2), Color.FromRgb(96, 197, 24));
            if (roots.Count == 0) AddStorageRow(list, "Xbox Hard Disk", "SETUP", "No xemu data folder detected", Color.FromRgb(3, 39, 2), Color.FromRgb(96, 197, 24), delegate { page = 4; selected = 0; RenderPage(); });
            AddStorageRow(list, "Back Up Memory", "RUN", "Create a recoverable copy", Color.FromRgb(3, 39, 2), Color.FromRgb(96, 197, 24), BackupSaves);
        }

        private void RenderXbox360Storage(List<string> roots)
        {
            titleText.Text = IsBlades() ? "memory" : "storage"; subtitleText.Text = "Storage Devices";
            StackPanel panel = new StackPanel { Margin = new Thickness(20, 4, 20, 18) }; contentHost.Children.Add(panel);
            Color accent = Color.FromRgb(107, 181, 43); Color bg = Color.FromRgb(48, 53, 51);
            foreach (string rootPath in roots) AddStorageRow(panel, "Hard Drive", "OPEN", rootPath, bg, accent);
            if (roots.Count == 0) AddStorageRow(panel, "Hard Drive", "SETUP", "No Xenia content folder detected", bg, accent, delegate { page = GetSettingsPageIndex(); selected = 0; RenderPage(); });
            AddStorageRow(panel, "Back Up Storage", "RUN", "Create a recoverable copy", bg, accent, BackupSaves);
        }

        private void RenderStorageList(string title, List<string> roots, string subtitle)
        {
            titleText.Text = title; subtitleText.Text = subtitle; StackPanel panel = new StackPanel { Margin = new Thickness(24) }; contentHost.Children.Add(panel);
            foreach (string rootPath in roots) AddStorageRow(panel, Path.GetFileName(rootPath.TrimEnd(Path.DirectorySeparatorChar)), "OPEN", rootPath, Color.FromRgb(40, 43, 48), definition.Accent);
            AddStorageRow(panel, "Back Up Save Data", "RUN", "Create a recoverable copy", Color.FromRgb(40, 43, 48), definition.Accent, BackupSaves);
        }

        private void AddStorageRow(Panel panel, string name, string value, string detail, Color background, Color accent) { AddStorageRow(panel, name, value, detail, background, accent, delegate { if (Directory.Exists(detail)) Process.Start("explorer.exe", "\"" + detail + "\""); }); }
        private void AddStorageRow(Panel panel, string name, string value, string detail, Color background, Color accent, Action invoke)
        {
            Button button = new Button { MinHeight = 76, Margin = new Thickness(16, 0, 16, 10), Padding = new Thickness(22, 10, 22, 10), HorizontalContentAlignment = HorizontalAlignment.Stretch, Background = new SolidColorBrush(background), BorderBrush = new SolidColorBrush(accent), BorderThickness = new Thickness(2), RenderTransformOrigin = new Point(0.5, 0.5) };
            Grid row = new Grid(); row.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(280) }); row.ColumnDefinitions.Add(new ColumnDefinition()); row.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(110) });
            row.Children.Add(new TextBlock { Text = name, FontSize = 19, FontWeight = FontWeights.Bold, Foreground = IsLightShell() ? new SolidColorBrush(Color.FromRgb(37, 43, 40)) : Brushes.White, VerticalAlignment = VerticalAlignment.Center, Margin = new Thickness(4, 0, 14, 0) });
            TextBlock details = new TextBlock { Text = detail, FontSize = 12, Foreground = IsLightShell() ? new SolidColorBrush(Color.FromRgb(75, 83, 79)) : new SolidColorBrush(Color.FromRgb(194, 205, 198)), VerticalAlignment = VerticalAlignment.Center, TextTrimming = TextTrimming.CharacterEllipsis, Margin = new Thickness(12, 0, 12, 0) }; Grid.SetColumn(details, 1); row.Children.Add(details);
            TextBlock status = new TextBlock { Text = value, FontSize = 15, FontWeight = FontWeights.Bold, Foreground = new SolidColorBrush(accent), VerticalAlignment = VerticalAlignment.Center, HorizontalAlignment = HorizontalAlignment.Center }; Grid.SetColumn(status, 2); row.Children.Add(status); button.Content = row; button.Click += delegate { invoke(); }; panel.Children.Add(button); actions.Add(new ConsolePlatformAction { Button = button, Invoke = invoke, Name = name });
        }

        private Button CreateShellAction(string name, string detail, Action invoke, Color color)
        {
            Button button = new Button { MinHeight = 74, Margin = new Thickness(8), Padding = new Thickness(18), Background = new SolidColorBrush(color), BorderBrush = Brushes.White, BorderThickness = new Thickness(2), HorizontalContentAlignment = HorizontalAlignment.Stretch, RenderTransformOrigin = new Point(0.5, 0.5) };
            StackPanel stack = new StackPanel(); stack.Children.Add(new TextBlock { Text = name, FontSize = 19, FontWeight = FontWeights.Bold, Foreground = Brushes.White }); stack.Children.Add(new TextBlock { Text = detail, FontSize = 11, Foreground = new SolidColorBrush(Color.FromRgb(224, 226, 235)), TextTrimming = TextTrimming.CharacterEllipsis }); button.Content = stack; button.Click += delegate { invoke(); }; return button;
        }

        private Button CreateWiiTab(string text, bool selectedTab) { Button b = new Button { Content = text, FontSize = 22, FontWeight = FontWeights.Bold, Foreground = new SolidColorBrush(Color.FromRgb(75, 93, 101)), Background = new SolidColorBrush(selectedTab ? Color.FromRgb(216, 245, 253) : Color.FromRgb(242, 247, 249)), BorderBrush = new SolidColorBrush(Color.FromRgb(113, 195, 219)), BorderThickness = new Thickness(selectedTab ? 3 : 1), Margin = new Thickness(8) }; return b; }
        private Button CreateChannelTile(string title, string detail, Action invoke) { Button b = new Button { Width = 250, Height = 150, Margin = new Thickness(12), Background = Brushes.White, BorderBrush = new SolidColorBrush(Color.FromRgb(135, 203, 221)), BorderThickness = new Thickness(3), RenderTransformOrigin = new Point(0.5, 0.5) }; StackPanel s = new StackPanel { VerticalAlignment = VerticalAlignment.Center }; s.Children.Add(new TextBlock { Text = title, FontSize = 20, FontWeight = FontWeights.Bold, Foreground = new SolidColorBrush(Color.FromRgb(61, 81, 90)), HorizontalAlignment = HorizontalAlignment.Center }); s.Children.Add(new TextBlock { Text = detail, FontSize = 11, Foreground = new SolidColorBrush(Color.FromRgb(102, 121, 128)), HorizontalAlignment = HorizontalAlignment.Center, TextTrimming = TextTrimming.CharacterEllipsis, MaxWidth = 210 }); b.Content = s; b.Click += delegate { invoke(); }; return b; }
        private void AddRoundedStorage(Panel panel, string name, string detail, Color accent) { AddRoundedStorage(panel, name, detail, accent, delegate { if (Directory.Exists(detail)) Process.Start("explorer.exe", "\"" + detail + "\""); }); }
        private void AddRoundedStorage(Panel panel, string name, string detail, Color accent, Action invoke) { Button b = new Button { Height = 120, Margin = new Thickness(0, 0, 0, 20), Padding = new Thickness(28), Background = Brushes.White, BorderBrush = new SolidColorBrush(accent), BorderThickness = new Thickness(4), HorizontalContentAlignment = HorizontalAlignment.Stretch, RenderTransformOrigin = new Point(0.5, 0.5) }; Grid g = new Grid(); g.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(120) }); g.ColumnDefinitions.Add(new ColumnDefinition()); Border icon = new Border { Width = 74, Height = 74, CornerRadius = new CornerRadius(37), Background = new SolidColorBrush(accent), Child = new TextBlock { Text = "DATA", FontSize = 14, FontWeight = FontWeights.Bold, Foreground = Brushes.White, HorizontalAlignment = HorizontalAlignment.Center, VerticalAlignment = VerticalAlignment.Center } }; g.Children.Add(icon); StackPanel s = new StackPanel { Margin = new Thickness(20, 0, 0, 0), VerticalAlignment = VerticalAlignment.Center }; s.Children.Add(new TextBlock { Text = name, FontSize = 23, FontWeight = FontWeights.Bold, Foreground = new SolidColorBrush(Color.FromRgb(47, 65, 73)) }); s.Children.Add(new TextBlock { Text = detail, FontSize = 12, Foreground = new SolidColorBrush(Color.FromRgb(88, 105, 112)), TextTrimming = TextTrimming.CharacterEllipsis }); Grid.SetColumn(s, 1); g.Children.Add(s); b.Content = g; b.Click += delegate { invoke(); }; panel.Children.Add(b); actions.Add(new ConsolePlatformAction { Button = b, Invoke = invoke, Name = name }); }
        private void AddFloatingBackup(Grid body, Action invoke) { Button backup = CreateShellAction("BACK UP", "Create recoverable copies", invoke, Color.FromRgb(82, 60, 164)); backup.Width = 250; backup.HorizontalAlignment = HorizontalAlignment.Center; backup.VerticalAlignment = VerticalAlignment.Bottom; backup.Margin = new Thickness(0, 0, 0, 14); Grid.SetColumnSpan(backup, 2); body.Children.Add(backup); actions.Add(new ConsolePlatformAction { Button = backup, Invoke = invoke, Name = "Back Up" }); }

        private void RenderMetroHome()
        {
            titleText.Text = "home"; subtitleText.Text = "xbox home";
            WrapPanel tiles = new WrapPanel { Margin = new Thickness(0, 4, 0, 12) }; contentHost.Children.Add(new ScrollViewer { VerticalScrollBarVisibility = ScrollBarVisibility.Hidden, Content = tiles });
            AddDashboardTile(tiles, "play", games.Count > 0 ? games[0].Name : "My Games", delegate { page = 2; selected = 0; RenderPage(); }, Color.FromRgb(18, 158, 31), 440, 220, "▶");
            AddDashboardTile(tiles, "achievements", GetXboxGamerscore().ToString(CultureInfo.InvariantCulture) + " G", OpenXboxAchievements, Color.FromRgb(24, 141, 34), 215, 220, "★");
            AddDashboardTile(tiles, "storage", "saved games", OpenXboxStorageManager, Color.FromRgb(21, 128, 34), 215, 220, "▣");
            AddDashboardTile(tiles, "recent", games.Count.ToString(CultureInfo.InvariantCulture) + " games", delegate { page = 2; selected = 0; RenderPage(); }, Color.FromRgb(54, 91, 51), 215, 150, "◷");
            AddDashboardTile(tiles, "settings", settings.dashboardStyle + " dashboard", delegate { page = 6; selected = 0; RenderPage(); }, Color.FromRgb(67, 72, 69), 440, 150, "⚙");
        }

        private void OpenXboxAchievements()
        {
            if (definition.Shell != "Xbox360") return;
            dashboardSubpage = "achievements"; selected = 0; RenderPage(); QueueXboxAchievementScan();
        }

        private void QueueXboxAchievementScan()
        {
            if (closing || xboxAchievementScanRunning || xboxAchievementsLoaded) return;
            xboxAchievementScanRunning = true;
            int generation = asyncGeneration;
            System.Threading.ThreadPool.QueueUserWorkItem(delegate
            {
                try
                {
                    List<XboxAchievementEntry> loaded = new List<XboxAchievementEntry>();
                    Dictionary<string, string> names = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
                    try { loaded = ScanXboxAchievements(names); }
                    catch (Exception ex) { WritePlatformLog("Xbox 360 achievement scan failed: " + ex, "WARN"); }
                    try
                    {
                        if (Dispatcher.HasShutdownStarted || Dispatcher.HasShutdownFinished) return;
                        Dispatcher.BeginInvoke(new Action(delegate
                        {
                            if (!CanApplyAsync(generation)) return;
                            xboxAchievements = loaded;
                            xboxTitleNames = names;
                            xboxAchievementsLoaded = true;
                            xboxAchievementScanRunning = false;
                            if (definition.Shell == "Xbox360") BuildChrome();
                            RenderPage();
                        }));
                    }
                    catch (Exception ex) { WritePlatformLog("Xbox 360 achievement UI callback was cancelled safely: " + ex.Message, "WARN"); }
                }
                catch (Exception ex)
                {
                    xboxAchievementScanRunning = false;
                    WritePlatformLog("Xbox 360 achievement worker recovered from an unexpected error: " + ex, "ERROR");
                }
            });
        }

        private int GetXboxGamerscore()
        {
            int score = 0; foreach (XboxAchievementEntry item in xboxAchievements ?? new List<XboxAchievementEntry>()) if (item != null && item.Earned) score += Math.Max(0, item.Gamerscore); return score;
        }

        private void RenderXbox360Achievements()
        {
            titleText.Text = IsBlades() ? "achievements" : "achievements";
            if (!xboxAchievementsLoaded)
            {
                subtitleText.Text = xboxAchievementScanRunning ? "Reading the signed-in Xenia profile…" : "Xbox 360 profile achievements";
                StackPanel wait = new StackPanel { HorizontalAlignment = HorizontalAlignment.Center, VerticalAlignment = VerticalAlignment.Center }; wait.Children.Add(new TextBlock { Text = "★", FontSize = 82, Foreground = Brushes.White, HorizontalAlignment = HorizontalAlignment.Center }); wait.Children.Add(new TextBlock { Text = "Loading achievements", FontSize = 26, Foreground = Brushes.White, HorizontalAlignment = HorizontalAlignment.Center, Margin = new Thickness(0, 16, 0, 0) }); contentHost.Children.Add(wait); QueueXboxAchievementScan(); return;
            }
            int earned = xboxAchievements.Count(delegate(XboxAchievementEntry a) { return a.Earned; }); int totalScore = xboxAchievements.Sum(delegate(XboxAchievementEntry a) { return Math.Max(0, a.Gamerscore); });
            subtitleText.Text = earned.ToString(CultureInfo.InvariantCulture) + " of " + xboxAchievements.Count.ToString(CultureInfo.InvariantCulture) + " unlocked  •  " + GetXboxGamerscore().ToString(CultureInfo.InvariantCulture) + " / " + totalScore.ToString(CultureInfo.InvariantCulture) + " G";
            StackPanel list = new StackPanel { Margin = new Thickness(4, 0, 4, 20) }; contentHost.Children.Add(new ScrollViewer { VerticalScrollBarVisibility = ScrollBarVisibility.Hidden, Content = list });
            foreach (XboxAchievementEntry achievement in xboxAchievements.OrderBy(delegate(XboxAchievementEntry a) { return a.TitleName; }, StringComparer.CurrentCultureIgnoreCase).ThenByDescending(delegate(XboxAchievementEntry a) { return a.Earned; }).ThenBy(delegate(XboxAchievementEntry a) { return a.Name; }, StringComparer.CurrentCultureIgnoreCase))
            {
                XboxAchievementEntry captured = achievement; Button row = CreateAchievementRow(achievement, delegate { ShowNotice((captured.Earned ? "Unlocked: " : "Locked: ") + captured.Name + " — " + (captured.Earned ? captured.UnlockedDescription : captured.LockedDescription)); }); list.Children.Add(row); actions.Add(new ConsolePlatformAction { Button = row, Invoke = delegate { ShowNotice((captured.Earned ? "Unlocked: " : "Locked: ") + captured.Name); }, Name = achievement.Name });
            }
            if (xboxAchievements.Count == 0) { Button empty = CreateActionButton("No profile achievements found", "Run an Xbox 360 game in Xenia Canary with a profile signed in", delegate { xboxAchievementsLoaded = false; QueueXboxAchievementScan(); }); list.Children.Add(empty); actions.Add(new ConsolePlatformAction { Button = empty, Invoke = delegate { xboxAchievementsLoaded = false; QueueXboxAchievementScan(); }, Name = "Refresh achievements" }); }
        }

        private Button CreateAchievementRow(XboxAchievementEntry item, Action invoke)
        {
            Button row = new Button { MinHeight = 92, Margin = new Thickness(4, 0, 4, 8), Padding = new Thickness(12), HorizontalContentAlignment = HorizontalAlignment.Stretch, Background = IsBlades() ? (Brush)new LinearGradientBrush(Color.FromRgb(242, 244, 243), Color.FromRgb(172, 178, 175), 90) : new SolidColorBrush(item.Earned ? Color.FromRgb(30, 148, 43) : Color.FromRgb(62, 66, 64)), BorderBrush = new SolidColorBrush(Color.FromArgb(150, 255, 255, 255)), BorderThickness = new Thickness(1), RenderTransformOrigin = new Point(0.5, 0.5) };
            Grid grid = new Grid(); grid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(76) }); grid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) }); grid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(90) });
            Border icon = new Border { Width = 64, Height = 64, Background = new SolidColorBrush(item.Earned ? Color.FromRgb(90, 177, 48) : Color.FromRgb(71, 75, 73)), BorderBrush = Brushes.White, BorderThickness = new Thickness(1) };
            if (!String.IsNullOrWhiteSpace(item.IconPath) && File.Exists(item.IconPath)) { try { icon.Child = new Image { Source = LoadBitmap(item.IconPath), Stretch = Stretch.UniformToFill }; } catch { } }
            if (icon.Child == null) icon.Child = new TextBlock { Text = item.Earned ? "★" : "?", FontSize = 32, Foreground = Brushes.White, HorizontalAlignment = HorizontalAlignment.Center, VerticalAlignment = VerticalAlignment.Center }; grid.Children.Add(icon);
            StackPanel text = new StackPanel { Margin = new Thickness(12, 2, 8, 0) }; Brush fg = IsBlades() ? (Brush)new SolidColorBrush(Color.FromRgb(41, 47, 44)) : Brushes.White; Brush sub = IsBlades() ? (Brush)new SolidColorBrush(Color.FromRgb(75, 84, 79)) : new SolidColorBrush(Color.FromRgb(221, 229, 223));
            string visibleName = (!item.Earned && !item.ShowUnachieved) ? "Secret Achievement" : item.Name; string description = item.Earned ? item.UnlockedDescription : ((!item.ShowUnachieved) ? "Keep playing to discover this achievement." : item.LockedDescription);
            text.Children.Add(new TextBlock { Text = visibleName, FontSize = 20, FontWeight = FontWeights.SemiBold, Foreground = fg, TextTrimming = TextTrimming.CharacterEllipsis }); text.Children.Add(new TextBlock { Text = item.TitleName + "  •  " + description, FontSize = 12, Foreground = sub, TextTrimming = TextTrimming.CharacterEllipsis }); Grid.SetColumn(text, 1); grid.Children.Add(text);
            TextBlock score = new TextBlock { Text = item.Gamerscore.ToString(CultureInfo.InvariantCulture) + " G", FontSize = 18, FontWeight = FontWeights.Bold, Foreground = item.Earned ? new SolidColorBrush(Color.FromRgb(239, 255, 229)) : sub, HorizontalAlignment = HorizontalAlignment.Center, VerticalAlignment = VerticalAlignment.Center }; Grid.SetColumn(score, 2); grid.Children.Add(score); row.Content = grid; row.Click += delegate { invoke(); }; return row;
        }

        private List<XboxAchievementEntry> ScanXboxAchievements(Dictionary<string, string> titleNames)
        {
            List<XboxAchievementEntry> result = new List<XboxAchievementEntry>(); List<string> roots = FindXeniaContentRoots(); List<string> gpdFiles = new List<string>();
            foreach (string rootPath in roots)
            {
                string profile = Path.Combine(rootPath, "FFFE07D1", "00000001"); if (!Directory.Exists(profile)) continue;
                try { gpdFiles.AddRange(Directory.EnumerateFiles(profile, "*.gpd", SearchOption.AllDirectories).Take(400)); } catch { }
            }
            foreach (string path in gpdFiles.Where(delegate(string p) { return String.Equals(Path.GetFileNameWithoutExtension(p), "FFFE07D1", StringComparison.OrdinalIgnoreCase); })) ParseXboxDashboardTitles(path, titleNames);
            foreach (string path in gpdFiles)
            {
                string titleId = Path.GetFileNameWithoutExtension(path).ToUpperInvariant(); if (!IsHexTitleId(titleId) || titleId == "FFFE07D1") continue;
                try { result.AddRange(ParseXboxAchievementGpd(path, titleId, titleNames.ContainsKey(titleId) ? titleNames[titleId] : titleId)); } catch (Exception ex) { WritePlatformLog("Skipped achievement GPD " + path + ": " + ex.Message, "WARN"); }
            }
            return result;
        }

        private void ParseXboxDashboardTitles(string path, Dictionary<string, string> names)
        {
            byte[] data = File.ReadAllBytes(path); bool big; int dataBase; List<XboxXdbfEntry> entries = ReadXdbfEntries(data, out big, out dataBase);
            foreach (XboxXdbfEntry entry in entries.Where(delegate(XboxXdbfEntry e) { return e.Namespace == 4 && e.Id <= UInt32.MaxValue; }))
            {
                int offset = dataBase + (int)entry.Offset; if (offset < 0 || offset + 0x28 > data.Length) continue; string title = ReadUtf16Null(data, offset + 0x28, offset + (int)entry.Length, big); string id = ((uint)entry.Id).ToString("X8", CultureInfo.InvariantCulture); if (!String.IsNullOrWhiteSpace(title)) names[id] = title;
            }
        }

        private List<XboxAchievementEntry> ParseXboxAchievementGpd(string path, string titleId, string titleName)
        {
            byte[] data = File.ReadAllBytes(path); bool big; int dataBase; List<XboxXdbfEntry> entries = ReadXdbfEntries(data, out big, out dataBase); Dictionary<uint, string> images = new Dictionary<uint, string>(); string iconRoot = Path.Combine(dataRoot, "AchievementIcons", titleId); Directory.CreateDirectory(iconRoot);
            foreach (XboxXdbfEntry entry in entries.Where(delegate(XboxXdbfEntry e) { return e.Namespace == 2 && e.Id <= UInt32.MaxValue; }))
            {
                int offset = dataBase + (int)entry.Offset; int length = (int)entry.Length; if (offset < 0 || length < 8 || offset + length > data.Length) continue; if (data[offset] != 0x89 || data[offset + 1] != 0x50 || data[offset + 2] != 0x4E || data[offset + 3] != 0x47) continue; string output = Path.Combine(iconRoot, ((uint)entry.Id).ToString("X8", CultureInfo.InvariantCulture) + ".png"); try { if (!File.Exists(output) || new FileInfo(output).Length != length) { byte[] image = new byte[length]; Buffer.BlockCopy(data, offset, image, 0, length); File.WriteAllBytes(output, image); } images[(uint)entry.Id] = output; } catch { }
            }
            List<XboxAchievementEntry> result = new List<XboxAchievementEntry>();
            foreach (XboxXdbfEntry entry in entries.Where(delegate(XboxXdbfEntry e) { return e.Namespace == 1 && e.Id <= UInt32.MaxValue; }))
            {
                int offset = dataBase + (int)entry.Offset; int end = Math.Min(data.Length, offset + (int)entry.Length); if (offset < 0 || offset + 0x1C > end) continue; uint size = ReadUInt32(data, offset, big); if (size < 0x18 || size > entry.Length) size = 0x1C; XboxAchievementEntry item = new XboxAchievementEntry(); item.TitleId = titleId; item.TitleName = titleName; item.AchievementId = ReadUInt32(data, offset + 4, big); item.ImageId = ReadUInt32(data, offset + 8, big); item.Gamerscore = unchecked((int)ReadUInt32(data, offset + 12, big)); item.Flags = ReadUInt32(data, offset + 16, big); long ticks = unchecked((long)ReadUInt64(data, offset + 20, big)); item.UnlockTime = DateTime.MinValue; try { if (ticks > DateTime.MinValue.Ticks && ticks < DateTime.MaxValue.Ticks) item.UnlockTime = new DateTime(ticks, DateTimeKind.Utc); } catch { }
                int cursor = offset + (int)(size < 0x1CU ? 0x1CU : size); item.Name = ReadUtf16NullAdvance(data, ref cursor, end, big); item.UnlockedDescription = ReadUtf16NullAdvance(data, ref cursor, end, big); item.LockedDescription = ReadUtf16NullAdvance(data, ref cursor, end, big); if (String.IsNullOrWhiteSpace(item.Name)) item.Name = "Achievement " + item.AchievementId.ToString(CultureInfo.InvariantCulture); string icon; if (images.TryGetValue(item.ImageId, out icon)) item.IconPath = icon; else item.IconPath = String.Empty; result.Add(item);
            }
            return result;
        }

        private static List<XboxXdbfEntry> ReadXdbfEntries(byte[] data, out bool bigEndian, out int dataBase)
        {
            List<XboxXdbfEntry> entries = new List<XboxXdbfEntry>(); bigEndian = true; dataBase = 0; if (data == null || data.Length < 24 || data[0] != 0x58 || data[1] != 0x44 || data[2] != 0x42 || data[3] != 0x46) return entries;
            uint entryTableLength = ReadUInt32(data, 8, true); uint entryCount = ReadUInt32(data, 12, true); uint freeTableLength = ReadUInt32(data, 16, true); if (entryTableLength > 100000 || freeTableLength > 100000 || entryCount > entryTableLength) return entries; dataBase = checked(24 + (int)entryTableLength * 18 + (int)freeTableLength * 8); int table = 24;
            for (uint i = 0; i < entryCount; i++) { int offset = table + checked((int)i * 18); if (offset + 18 > data.Length) break; XboxXdbfEntry item = new XboxXdbfEntry(); item.Namespace = ReadUInt16(data, offset, true); item.Id = ReadUInt64(data, offset + 2, true); item.Offset = ReadUInt32(data, offset + 10, true); item.Length = ReadUInt32(data, offset + 14, true); if ((long)dataBase + item.Offset + item.Length <= data.Length) entries.Add(item); }
            return entries;
        }

        private static ushort ReadUInt16(byte[] data, int offset, bool big) { if (big) return (ushort)((data[offset] << 8) | data[offset + 1]); return (ushort)(data[offset] | (data[offset + 1] << 8)); }
        private static uint ReadUInt32(byte[] data, int offset, bool big) { if (big) return ((uint)data[offset] << 24) | ((uint)data[offset + 1] << 16) | ((uint)data[offset + 2] << 8) | data[offset + 3]; return data[offset] | ((uint)data[offset + 1] << 8) | ((uint)data[offset + 2] << 16) | ((uint)data[offset + 3] << 24); }
        private static ulong ReadUInt64(byte[] data, int offset, bool big) { ulong value = 0; if (big) { for (int i = 0; i < 8; i++) value = (value << 8) | data[offset + i]; } else { for (int i = 7; i >= 0; i--) value = (value << 8) | data[offset + i]; } return value; }
        private static string ReadUtf16Null(byte[] data, int offset, int end, bool big) { int cursor = offset; return ReadUtf16NullAdvance(data, ref cursor, end, big); }
        private static string ReadUtf16NullAdvance(byte[] data, ref int cursor, int end, bool big) { StringBuilder text = new StringBuilder(); while (cursor + 1 < end) { ushort value = ReadUInt16(data, cursor, big); cursor += 2; if (value == 0) break; if (value >= 32 || value == 9) text.Append((char)value); } return text.ToString().Trim(); }
        private static bool IsHexTitleId(string value) { if (String.IsNullOrWhiteSpace(value) || value.Length != 8) return false; foreach (char c in value) if (!Uri.IsHexDigit(c)) return false; return true; }

        private void OpenXboxStorageManager() { dashboardSubpage = "storage"; selectedXboxSave = null; selected = 0; ScanXboxSaves(); RenderPage(); }

        private void ScanXboxSaves()
        {
            List<XboxSaveEntry> found = new List<XboxSaveEntry>();
            if (definition.Shell == "Xbox360")
            {
                foreach (string rootPath in FindXeniaContentRoots())
                {
                    foreach (string dir in EnumerateDirectoriesLimited(rootPath, 6, 5000))
                    {
                        if (!String.Equals(Path.GetFileName(dir), "00000001", StringComparison.OrdinalIgnoreCase)) continue; string titleId = Path.GetFileName(Path.GetDirectoryName(dir)); if (!IsHexTitleId(titleId)) continue; string title = xboxTitleNames.ContainsKey(titleId) ? xboxTitleNames[titleId] : titleId; found.Add(new XboxSaveEntry { Name = title, TitleId = titleId, Path = dir, IsDirectory = true, Size = GetPathSize(dir), Modified = Directory.GetLastWriteTime(dir) });
                    }
                }
            }
            else
            {
                foreach (string rootPath in FindOriginalXboxStorageRoots())
                {
                    try
                    {
                        foreach (string file in Directory.EnumerateFiles(rootPath, "*.*", SearchOption.AllDirectories).Take(1200))
                        {
                            string ext = Path.GetExtension(file).ToLowerInvariant(); string name = Path.GetFileName(file).ToLowerInvariant(); if (!(ext == ".qcow2" || ext == ".img" || ext == ".raw" || ext == ".vhd" || ext == ".vhdx" || ext == ".bin") || (ext == ".bin" && name.IndexOf("mu", StringComparison.OrdinalIgnoreCase) < 0 && name.IndexOf("memory", StringComparison.OrdinalIgnoreCase) < 0)) continue; FileInfo info = new FileInfo(file); found.Add(new XboxSaveEntry { Name = Path.GetFileNameWithoutExtension(file), TitleId = ext == ".qcow2" || name.IndexOf("hdd", StringComparison.OrdinalIgnoreCase) >= 0 ? "HARD DISK" : "MEMORY UNIT", Path = file, IsDirectory = false, Size = info.Length, Modified = info.LastWriteTime });
                        }
                    }
                    catch { }
                }
            }
            xboxSaveEntries = found.GroupBy(delegate(XboxSaveEntry e) { return e.Path; }, StringComparer.OrdinalIgnoreCase).Select(delegate(IGrouping<string, XboxSaveEntry> g) { return g.First(); }).OrderBy(delegate(XboxSaveEntry e) { return e.Name; }, StringComparer.CurrentCultureIgnoreCase).ToList();
        }

        private void RenderXboxStorageManager()
        {
            titleText.Text = definition.Shell == "Xbox360" ? (IsBlades() ? "memory" : "storage") : "memory"; subtitleText.Text = xboxSaveEntries.Count.ToString(CultureInfo.InvariantCulture) + " storage item(s)";
            StackPanel list = new StackPanel { Margin = new Thickness(4, 0, 4, 20) }; contentHost.Children.Add(new ScrollViewer { VerticalScrollBarVisibility = ScrollBarVisibility.Hidden, Content = list });
            foreach (XboxSaveEntry entry in xboxSaveEntries)
            {
                XboxSaveEntry captured = entry; Button row = CreateStorageEntryRow(entry, delegate { selectedXboxSave = captured; dashboardSubpage = "save-detail"; selected = 0; RenderPage(); }); list.Children.Add(row); actions.Add(new ConsolePlatformAction { Button = row, Invoke = delegate { selectedXboxSave = captured; dashboardSubpage = "save-detail"; selected = 0; RenderPage(); }, Name = entry.Name });
            }
            if (xboxSaveEntries.Count == 0) { Button empty = CreateActionButton("No save storage detected", definition.Shell == "Xbox360" ? "Run a game in Xenia or select the correct emulator path" : "Select xemu so its hard disk and memory-unit images can be detected", delegate { ScanXboxSaves(); RenderPage(); }); list.Children.Add(empty); actions.Add(new ConsolePlatformAction { Button = empty, Invoke = delegate { ScanXboxSaves(); RenderPage(); }, Name = "Refresh storage" }); }
            Button restore = CreateActionButton("Restore Latest Removed Save", "Restore the newest recoverable item removed through Huymaier Console", RestoreLatestDeletedSave); list.Children.Add(restore); actions.Add(new ConsolePlatformAction { Button = restore, Invoke = RestoreLatestDeletedSave, Name = "Restore latest" });
        }

        private Button CreateStorageEntryRow(XboxSaveEntry entry, Action invoke)
        {
            string detail = entry.TitleId + "  •  " + FormatBytes(entry.Size) + "  •  " + entry.Modified.ToString("g", CultureInfo.CurrentCulture); return CreateActionButton(entry.Name, detail, invoke);
        }

        private void RenderXboxSaveDetail()
        {
            if (selectedXboxSave == null) { dashboardSubpage = "storage"; RenderXboxStorageManager(); return; }
            titleText.Text = selectedXboxSave.Name; subtitleText.Text = selectedXboxSave.TitleId + "  •  " + FormatBytes(selectedXboxSave.Size) + "  •  " + selectedXboxSave.Path; StackPanel panel = new StackPanel { Margin = new Thickness(8, 0, 8, 20) }; contentHost.Children.Add(new ScrollViewer { VerticalScrollBarVisibility = ScrollBarVisibility.Hidden, Content = panel });
            AddSetting(panel, "Back Up", "Create a timestamped recoverable copy", delegate { BackupXboxSave(selectedXboxSave); }); AddSetting(panel, "Export", "Copy this save/storage item to a folder you choose", delegate { ExportXboxSave(selectedXboxSave); }); AddSetting(panel, "Open Location", selectedXboxSave.Path, delegate { OpenSaveLocation(selectedXboxSave); }); AddSetting(panel, "Remove (Recoverable)", "Move to Huymaier Console's Deleted Saves backup", delegate { DeleteXboxSave(selectedXboxSave); }); AddSetting(panel, "Back to Storage", "Return without changing this item", delegate { dashboardSubpage = "storage"; selectedXboxSave = null; selected = 0; RenderPage(); });
        }

        private void BackupXboxSave(XboxSaveEntry entry) { if (entry == null) return; string targetRoot = Path.Combine(dataRoot, "Backups", "Saves", DateTime.Now.ToString("yyyyMMdd-HHmmss", CultureInfo.InvariantCulture)); Directory.CreateDirectory(targetRoot); string target = Path.Combine(targetRoot, Sanitize(entry.Name)); try { CopySavePath(entry.Path, target); ShowNotice("Save backed up"); } catch (Exception ex) { ShowNotice("Backup failed: " + ex.Message); } }
        private void ExportXboxSave(XboxSaveEntry entry) { if (entry == null) return; using (System.Windows.Forms.FolderBrowserDialog dialog = new System.Windows.Forms.FolderBrowserDialog()) { dialog.Description = "Export " + entry.Name; if (dialog.ShowDialog() != System.Windows.Forms.DialogResult.OK) return; string target = Path.Combine(dialog.SelectedPath, Sanitize(entry.Name)); try { CopySavePath(entry.Path, target); ShowNotice("Save exported"); } catch (Exception ex) { ShowNotice("Export failed: " + ex.Message); } } }
        private void OpenSaveLocation(XboxSaveEntry entry) { try { string folder = entry.IsDirectory ? entry.Path : Path.GetDirectoryName(entry.Path); Process.Start("explorer.exe", "\"" + folder + "\""); } catch { } }
        private void DeleteXboxSave(XboxSaveEntry entry) { if (entry == null) return; string targetRoot = Path.Combine(dataRoot, "Backups", "Deleted", DateTime.Now.ToString("yyyyMMdd-HHmmss-fff", CultureInfo.InvariantCulture)); Directory.CreateDirectory(targetRoot); string target = Path.Combine(targetRoot, "item" + (entry.IsDirectory ? String.Empty : Path.GetExtension(entry.Path))); try { File.WriteAllText(Path.Combine(targetRoot, "restore-path.txt"), entry.Path, Encoding.UTF8); if (entry.IsDirectory) Directory.Move(entry.Path, target); else File.Move(entry.Path, target); ShowNotice("Moved to recoverable backup"); dashboardSubpage = "storage"; selectedXboxSave = null; ScanXboxSaves(); RenderPage(); } catch (Exception ex) { ShowNotice("Remove failed: " + ex.Message); } }
        private void RestoreLatestDeletedSave() { string deletedRoot = Path.Combine(dataRoot, "Backups", "Deleted"); if (!Directory.Exists(deletedRoot)) { ShowNotice("No removed saves are available"); return; } try { DirectoryInfo latest = new DirectoryInfo(deletedRoot).GetDirectories().OrderByDescending(delegate(DirectoryInfo d) { return d.CreationTimeUtc; }).FirstOrDefault(); if (latest == null) { ShowNotice("No removed saves are available"); return; } string metadata = Path.Combine(latest.FullName, "restore-path.txt"); if (!File.Exists(metadata)) { ShowNotice("The latest backup has no restore metadata"); return; } string original = File.ReadAllText(metadata, Encoding.UTF8).Trim(); FileSystemInfo item = latest.GetFileSystemInfos().FirstOrDefault(delegate(FileSystemInfo f) { return !String.Equals(f.Name, "restore-path.txt", StringComparison.OrdinalIgnoreCase); }); if (item == null || String.IsNullOrWhiteSpace(original)) { ShowNotice("The latest backup is incomplete"); return; } if (File.Exists(original) || Directory.Exists(original)) { ShowNotice("The original save location is already occupied"); return; } Directory.CreateDirectory(Path.GetDirectoryName(original)); DirectoryInfo dir = item as DirectoryInfo; if (dir != null) Directory.Move(dir.FullName, original); else File.Move(item.FullName, original); try { File.Delete(metadata); Directory.Delete(latest.FullName, false); } catch { } ScanXboxSaves(); RenderPage(); ShowNotice("Latest removed save restored"); } catch (Exception ex) { ShowNotice("Restore failed: " + ex.Message); } }
        private static void CopySavePath(string source, string target) { if (Directory.Exists(source)) { Directory.CreateDirectory(target); CopyDirectory(source, target, 20000); } else { Directory.CreateDirectory(Path.GetDirectoryName(target)); File.Copy(source, target + Path.GetExtension(source), true); } }

        private List<string> FindXeniaContentRoots()
        {
            List<string> roots = new List<string>(); string docs = Environment.GetFolderPath(Environment.SpecialFolder.MyDocuments); string local = Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData); string exeRoot = !String.IsNullOrWhiteSpace(settings.emulatorPath) && File.Exists(settings.emulatorPath) ? Path.GetDirectoryName(settings.emulatorPath) : String.Empty; AddExisting(roots, Path.Combine(exeRoot, "content")); AddExisting(roots, Path.Combine(docs, "Xenia", "content")); AddExisting(roots, Path.Combine(local, "Xenia", "content"));
            string config = Path.Combine(exeRoot, "xenia-canary-config.toml"); if (!File.Exists(config)) config = Path.Combine(exeRoot, "xenia.config.toml"); if (File.Exists(config)) { try { foreach (string line in File.ReadAllLines(config)) { string trimmed = line.Trim(); if (!trimmed.StartsWith("content_root", StringComparison.OrdinalIgnoreCase)) continue; int equals = trimmed.IndexOf('='); if (equals < 0) continue; string value = trimmed.Substring(equals + 1).Trim().Trim('"', '\''); if (!String.IsNullOrWhiteSpace(value)) AddExisting(roots, Environment.ExpandEnvironmentVariables(value)); } } catch { } }
            return roots;
        }
        private List<string> FindOriginalXboxStorageRoots() { List<string> roots = new List<string>(); string exeRoot = !String.IsNullOrWhiteSpace(settings.emulatorPath) && File.Exists(settings.emulatorPath) ? Path.GetDirectoryName(settings.emulatorPath) : String.Empty; AddExisting(roots, exeRoot); AddExisting(roots, Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), "xemu")); AddExisting(roots, Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "xemu")); AddExisting(roots, Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.MyDocuments), "xemu")); return roots; }
        private static IEnumerable<string> EnumerateDirectoriesLimited(string rootPath, int maxDepth, int maxCount) { Queue<KeyValuePair<string, int>> queue = new Queue<KeyValuePair<string, int>>(); queue.Enqueue(new KeyValuePair<string, int>(rootPath, 0)); int count = 0; while (queue.Count > 0 && count < maxCount) { KeyValuePair<string, int> item = queue.Dequeue(); if (item.Value >= maxDepth) continue; string[] dirs; try { dirs = Directory.GetDirectories(item.Key); } catch { continue; } foreach (string dir in dirs) { yield return dir; count++; if (count >= maxCount) yield break; queue.Enqueue(new KeyValuePair<string, int>(dir, item.Value + 1)); } } }
        private static long GetPathSize(string path) { try { if (File.Exists(path)) return new FileInfo(path).Length; long total = 0; foreach (string file in Directory.EnumerateFiles(path, "*", SearchOption.AllDirectories).Take(20000)) { try { total += new FileInfo(file).Length; } catch { } } return total; } catch { return 0; } }
        private static string FormatBytes(long value) { double size = Math.Max(0.0, (double)value); string[] units = new string[] { "B", "KB", "MB", "GB", "TB" }; int unit = 0; while (size >= 1024 && unit < units.Length - 1) { size /= 1024; unit++; } return size.ToString(unit == 0 ? "0" : "0.0", CultureInfo.InvariantCulture) + " " + units[unit]; }

        private void UpdateXboxGamePreview()
        {
            if (xboxPreviewTitle == null || actions.Count == 0) return; int index = Math.Max(0, Math.Min(selected, actions.Count - 1)); ConsolePlatformGame game = actions[index].Game; if (game == null) return; xboxPreviewTitle.Text = game.Name; if (xboxPreviewDetail != null) xboxPreviewDetail.Text = definition.Shell == "Xbox360" ? "A  Play     X  Fallback emulator" : "A  Play     X  Fallback emulator"; if (xboxPreviewImage != null) { xboxPreviewImage.Source = null; if (!String.IsNullOrWhiteSpace(game.Cover) && File.Exists(game.Cover)) { try { xboxPreviewImage.Source = LoadBitmap(game.Cover); } catch { } } }
        }

        private void WritePlatformLog(string message, string level)
        {
            try { string logRoot = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "Huymaier Console", "Logs"); Directory.CreateDirectory(logRoot); string path = Path.Combine(logRoot, DateTime.Now.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture) + ".log"); File.AppendAllText(path, DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss.fff", CultureInfo.InvariantCulture) + " [" + level + "] " + message + Environment.NewLine, Encoding.UTF8); } catch { }
        }

        private void RenderSettings()
        {
            titleText.Text = definition.Shell == "Xbox360" ? (IsBlades() ? "system" : "settings") : definition.DisplayName + " Settings";
            subtitleText.Text = definition.PrimaryBackend + " with " + definition.FallbackBackend + " fallback";
            StackPanel panel = new StackPanel { Margin = IsXboxFamily() ? new Thickness(8, 0, 8, 24) : new Thickness(22, 0, 22, 24), MaxWidth = 1320, HorizontalAlignment = HorizontalAlignment.Stretch }; contentHost.Children.Add(new ScrollViewer { VerticalScrollBarVisibility = ScrollBarVisibility.Hidden, Content = panel });
            if (definition.Shell == "Xbox360")
            {
                AddSetting(panel, "Storage", "Manage Xenia save containers and profile backups", OpenXboxStorageManager);
                AddSetting(panel, "Achievements", GetXboxGamerscore().ToString(CultureInfo.InvariantCulture) + " G earned from Xenia profiles", OpenXboxAchievements);
                AddSetting(panel, "Dashboard Style", settings.dashboardStyle, CycleDashboardStyle);
            }
            else if (definition.Shell == "Xbox") AddSetting(panel, "Memory", "Back up, export, and restore Xbox storage images", OpenXboxStorageManager);
            AddSetting(panel, "Primary Emulator", DisplayPath(settings.emulatorPath), ChoosePrimaryEmulator); AddSetting(panel, "Fallback Emulator", DisplayPath(settings.fallbackEmulatorPath), ChooseFallbackEmulator);
            AddSetting(panel, "Add Game Folder", settings.gameFolders.Count.ToString(CultureInfo.InvariantCulture) + " configured", AddGameFolder); AddSetting(panel, "Refresh Library", "Rescan configured folders and reuse cached covers", delegate { RefreshLibrary(true); });
            if (IsXboxFamily()) AddSetting(panel, "Refresh Online Cover Art", "Download missing Xbox box art and keep it in the local dashboard cache", QueueXboxArtworkRefresh);
            AddSetting(panel, "Startup Video", settings.startupEnabled ? "Enabled" : "Disabled", delegate { settings.startupEnabled = !settings.startupEnabled; settings.Save(settingsPath); RenderSettingsPage(); });
            AddSetting(panel, "Navigation Sound Volume", Math.Round(settings.soundVolume * 100).ToString(CultureInfo.InvariantCulture) + "%", CycleSoundVolume); AddSetting(panel, "Import Ambience", String.IsNullOrWhiteSpace(settings.ambiencePath) ? "Not configured" : Path.GetFileName(settings.ambiencePath), ChooseAmbience);
            AddSetting(panel, "Dashboard Music Volume", Math.Round(settings.ambienceVolume * 100).ToString(CultureInfo.InvariantCulture) + "%", CycleAmbienceVolume); AddSetting(panel, "Ambience", settings.ambienceEnabled ? "Enabled" : "Disabled", delegate { settings.ambienceEnabled = !settings.ambienceEnabled; settings.Save(settingsPath); StartAmbience(); RenderSettingsPage(); });
            AddSetting(panel, "Open Platform Data", dataRoot, delegate { Process.Start("explorer.exe", "\"" + dataRoot + "\""); }); AddSetting(panel, "Return to Huymaier Console", "Close the " + definition.DisplayName + " shell", delegate { Close(); });
        }


        private void RenderSettingsPage() { selected = Math.Max(0, Math.Min(selected, actions.Count - 1)); RenderPage(); }

        private void AddSetting(StackPanel panel, string title, string subtitle, Action invoke)
        {
            Button button = CreateActionButton(title, subtitle, invoke);
            panel.Children.Add(button);
            actions.Add(new ConsolePlatformAction { Button = button, Invoke = invoke, Name = title });
        }

        private Button CreateActionButton(string title, string subtitle, Action invoke)
        {
            if (definition.Shell == "Xbox") return CreateXboxPanelRow(title, subtitle, invoke, "X");
            if (IsBlades()) return CreateBladePanelButton(title, subtitle, invoke, new Color[] { Color.FromRgb(232, 116, 18), Color.FromRgb(87, 156, 46), Color.FromRgb(56, 126, 183), Color.FromRgb(103, 76, 151) }[Math.Max(0, Math.Min(page, 3))]);
            Color baseColor = IsLightShell() ? Color.FromRgb(244, 248, 250) : Color.FromArgb(150, 8, 12, 17);
            if (definition.Shell == "N64") baseColor = Color.FromRgb(38, 40, 50);
            else if (definition.Shell == "GameCube") baseColor = Color.FromRgb(65, 48, 132);
            else if (IsMetro()) baseColor = Color.FromRgb(53, 121, 36);
            else if (definition.Shell == "Switch") baseColor = Color.FromRgb(57, 58, 63);
            Button button = new Button { MinHeight = IsMetro() ? 92 : 72, Margin = new Thickness(18, 0, 18, 10), Padding = new Thickness(24, 10, 24, 10), HorizontalContentAlignment = HorizontalAlignment.Stretch, BorderThickness = new Thickness(IsMetro() ? 1 : 2), Cursor = Cursors.Hand, RenderTransformOrigin = new Point(0.5, 0.5), Background = new SolidColorBrush(baseColor), BorderBrush = new SolidColorBrush(IsMetro() ? Color.FromArgb(90, 255, 255, 255) : definition.Accent) };
            Grid grid = new Grid(); grid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(IsMetro() ? 300 : 330) }); grid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
            TextBlock nameText = new TextBlock { Text = title, FontSize = IsMetro() ? 22 : 18, FontWeight = IsMetro() ? FontWeights.SemiBold : FontWeights.Bold, Foreground = IsLightShell() ? new SolidColorBrush(Color.FromRgb(44, 58, 64)) : Brushes.White, VerticalAlignment = VerticalAlignment.Center, Margin = new Thickness(4, 0, 24, 0) };
            TextBlock detail = new TextBlock { Text = subtitle ?? String.Empty, FontSize = 12, TextTrimming = TextTrimming.CharacterEllipsis, TextWrapping = TextWrapping.NoWrap, Foreground = IsLightShell() ? new SolidColorBrush(Color.FromRgb(91, 109, 116)) : new SolidColorBrush(Color.FromRgb(220, 232, 225)), VerticalAlignment = VerticalAlignment.Center, Margin = new Thickness(12, 0, 8, 0) }; Grid.SetColumn(detail, 1); grid.Children.Add(nameText); grid.Children.Add(detail); button.Content = grid; button.Click += delegate { invoke(); }; return button;
        }

        private void UpdateActionVisuals()
        {
            for (int i = 0; i < actions.Count; i++)
            {
                bool active = i == selected;
                Button button = actions[i].Button;
                if (button == null) continue;
                if (definition.Shell == "Xbox")
                {
                    button.BorderBrush = new SolidColorBrush(active ? Color.FromRgb(157, 255, 103) : Color.FromArgb(80, 96, 197, 24));
                    button.BorderThickness = new Thickness(active ? 4 : 1);
                    button.RenderTransform = active ? new ScaleTransform(1.025, 1.025) : Transform.Identity;
                }
                else if (definition.Shell == "Xbox360")
                {
                    button.BorderBrush = new SolidColorBrush(active ? Color.FromRgb(255, 255, 255) : Color.FromArgb(70, 255, 255, 255));
                    button.BorderThickness = new Thickness(active ? 4 : 1);
                    button.RenderTransform = active ? new ScaleTransform(1.035, 1.035) : Transform.Identity;
                }
                else
                {
                    button.BorderBrush = new SolidColorBrush(active ? definition.Accent : (IsLightShell() ? Color.FromRgb(184, 204, 212) : Color.FromArgb(45, 255, 255, 255)));
                    button.BorderThickness = new Thickness(active ? 3 : 1);
                    button.RenderTransform = active ? new ScaleTransform(1.012, 1.012) : Transform.Identity;
                }
                if (active) button.BringIntoView();
            }
            if (IsXboxFamily() && IsGamePage()) UpdateXboxGamePreview();
        }

        private void CalculateColumns()
        {
            if (definition.Shell == "Wii") { columns = 4; return; }
            if (definition.Shell == "WiiU") { columns = 5; return; }
            if (definition.Shell == "Switch") { columns = 6; return; }
            if (IsBlades()) { columns = 1; return; }
            double reserved = definition.Shell == "Xbox" ? 760 : (IsMetro() ? 360 : 340);
            double available = Math.Max(420, ActualWidth - reserved);
            double cardWidth = IsMetro() ? 224 : (definition.Shell == "Xbox" ? 184 : 205);
            columns = Math.Max(1, (int)(available / cardWidth));
        }

        private void ChoosePrimaryEmulator()
        {
            string path = ChooseExecutable(definition.PrimaryBackend);
            if (!String.IsNullOrWhiteSpace(path)) { settings.emulatorPath = path; settings.Save(settingsPath); RenderPage(); }
        }

        private void ChooseFallbackEmulator()
        {
            string path = ChooseExecutable(definition.FallbackBackend);
            if (!String.IsNullOrWhiteSpace(path)) { settings.fallbackEmulatorPath = path; settings.Save(settingsPath); RenderPage(); }
        }

        private string ChooseExecutable(string title)
        {
            OpenFileDialog dialog = new OpenFileDialog();
            dialog.Title = "Select " + title;
            dialog.Filter = "Windows applications (*.exe)|*.exe|All files (*.*)|*.*";
            return dialog.ShowDialog(this) == true ? dialog.FileName : String.Empty;
        }

        private void AddGameFolder()
        {
            using (System.Windows.Forms.FolderBrowserDialog dialog = new System.Windows.Forms.FolderBrowserDialog())
            {
                dialog.Description = "Select a " + definition.DisplayName + " game folder";
                if (dialog.ShowDialog() != System.Windows.Forms.DialogResult.OK) return;
                if (!settings.gameFolders.Contains(dialog.SelectedPath, StringComparer.OrdinalIgnoreCase)) settings.gameFolders.Add(dialog.SelectedPath);
                settings.Save(settingsPath);
                RefreshLibrary(true);
            }
        }





        private void OpenFolderForExecutable(string executable)
        {
            try { string folder = !String.IsNullOrWhiteSpace(executable) && File.Exists(executable) ? Path.GetDirectoryName(executable) : dataRoot; Process.Start("explorer.exe", "\"" + folder + "\""); } catch { }
        }

        private void OpenFirstSaveRoot()
        {
            List<string> roots = FindSaveRoots(); if (roots.Count > 0) Process.Start("explorer.exe", "\"" + roots[0] + "\""); else ShowNotice("No storage folder detected");
        }

        private void ChooseAmbience()
        {
            OpenFileDialog dialog = new OpenFileDialog();
            dialog.Title = "Choose " + definition.DisplayName + " ambience";
            dialog.Filter = "Audio files|*.mp3;*.wav;*.wma;*.m4a;*.aac|All files|*.*";
            if (dialog.ShowDialog(this) != true) return;
            settings.ambiencePath = dialog.FileName;
            settings.ambienceEnabled = true;
            settings.Save(settingsPath);
            StartAmbience();
            RenderPage();
        }

        private void CycleDashboardStyle()
        {
            if (definition.Shell != "Xbox360" || definition.DashboardStyles == null || definition.DashboardStyles.Length == 0) return;
            int index = Array.FindIndex(definition.DashboardStyles, delegate(string value) { return String.Equals(value, settings.dashboardStyle, StringComparison.OrdinalIgnoreCase); });
            string previous = settings.dashboardStyle; string nextStyle = definition.DashboardStyles[(index + 1 + definition.DashboardStyles.Length) % definition.DashboardStyles.Length];
            try
            {
                dashboardGuideVisible = false; dashboardGuideOverlay.Visibility = Visibility.Collapsed; dashboardSubpage = String.Empty; selectedXboxSave = null;
                settings.dashboardStyle = nextStyle; settings.Save(settingsPath); page = GetDefaultPageIndex(); selected = 0; root.Background = BuildBackground();
                input.Reset(); inputGuardUntilUtc = DateTime.UtcNow.AddMilliseconds(900); BuildChrome(); RenderPage(); NativeWindowActivation.Restore(this);
                ShowNotice("Dashboard changed to " + nextStyle); WritePlatformLog("Xbox 360 dashboard changed in place: " + previous + " -> " + nextStyle, "INFO");
            }
            catch (Exception ex)
            {
                settings.dashboardStyle = previous; settings.Save(settingsPath); page = GetDefaultPageIndex(); selected = 0; root.Background = BuildBackground(); BuildChrome(); RenderPage(); NativeWindowActivation.Restore(this);
                WritePlatformLog("Xbox 360 dashboard switch recovered: " + ex, "ERROR"); ShowNotice("Dashboard switch recovered without closing Huymaier Console");
            }
        }


        private void CycleSoundVolume()
        {
            double[] levels = new double[] { 0.5, 0.7, 0.85, 1.0 };
            int index = 0;
            double best = Double.MaxValue;
            for (int i = 0; i < levels.Length; i++) { double delta = Math.Abs(levels[i] - settings.soundVolume); if (delta < best) { best = delta; index = i; } }
            settings.soundVolume = levels[(index + 1) % levels.Length];
            settings.Save(settingsPath);
            RenderPage();
        }

        private void CycleAmbienceVolume()
        {
            double[] levels = new double[] { 0.65, 0.80, 0.90, 1.0 };
            int index = 0; double best = Double.MaxValue;
            for (int i = 0; i < levels.Length; i++) { double delta = Math.Abs(levels[i] - settings.ambienceVolume); if (delta < best) { best = delta; index = i; } }
            settings.ambienceVolume = levels[(index + 1) % levels.Length]; settings.Save(settingsPath); StartAmbience(); RenderPage();
        }

        private void QueueLibraryRefresh()
        {
            if (closing) return;
            string[] folders = settings.gameFolders == null ? new string[0] : settings.gameFolders.ToArray();
            string[] extensions = definition.GameExtensions == null ? new string[0] : definition.GameExtensions.ToArray();
            int generation = asyncGeneration;
            System.Threading.ThreadPool.QueueUserWorkItem(delegate
            {
                List<ConsolePlatformGame> found = new List<ConsolePlatformGame>();
                HashSet<string> seen = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
                foreach (string folder in folders)
                {
                    if (!Directory.Exists(folder)) continue;
                    try
                    {
                        foreach (string path in Directory.EnumerateFiles(folder, "*.*", SearchOption.AllDirectories))
                        {
                            string extension = Path.GetExtension(path);
                            if (!extensions.Contains(extension, StringComparer.OrdinalIgnoreCase) || !seen.Add(path)) continue;
                            found.Add(new ConsolePlatformGame { Name = CleanName(Path.GetFileNameWithoutExtension(path)), Path = path, Cover = FindCover(path) });
                        }
                    }
                    catch { }
                }
                found = found.OrderBy(delegate(ConsolePlatformGame g) { return g.Name; }, StringComparer.CurrentCultureIgnoreCase).ToList();
                try
                {
                    if (Dispatcher.HasShutdownStarted || Dispatcher.HasShutdownFinished) return;
                    Dispatcher.BeginInvoke(new Action(delegate
                {
                    if (!CanApplyAsync(generation) || activeProcess != null) return;
                    bool changed = found.Count != games.Count;
                    if (!changed)
                    {
                        for (int i = 0; i < found.Count; i++)
                        {
                            if (!String.Equals(found[i].Path, games[i].Path, StringComparison.OrdinalIgnoreCase)) { changed = true; break; }
                        }
                    }
                    if (!changed) return;
                    games = found;
                    SaveCachedGames();
                    selected = 0;
                    RenderPage();
                    ShowNotice("Library updated — " + games.Count.ToString(CultureInfo.InvariantCulture) + " games");
                    if (IsXboxFamily()) QueueXboxArtworkRefresh();
                })); } catch (Exception ex) { WritePlatformLog(definition.DisplayName + " library UI callback was cancelled safely: " + ex.Message, "WARN"); }
            });
        }

        private void RefreshLibrary(bool showNotice)
        {
            List<ConsolePlatformGame> found = new List<ConsolePlatformGame>();
            HashSet<string> seen = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            foreach (string folder in settings.gameFolders.ToArray())
            {
                if (!Directory.Exists(folder)) continue;
                try
                {
                    foreach (string path in Directory.EnumerateFiles(folder, "*.*", SearchOption.AllDirectories))
                    {
                        string extension = Path.GetExtension(path);
                        if (!definition.GameExtensions.Contains(extension, StringComparer.OrdinalIgnoreCase)) continue;
                        if (!seen.Add(path)) continue;
                        found.Add(new ConsolePlatformGame { Name = CleanName(Path.GetFileNameWithoutExtension(path)), Path = path, Cover = FindCover(path) });
                    }
                }
                catch { }
            }
            games = found.OrderBy(delegate(ConsolePlatformGame g) { return g.Name; }, StringComparer.CurrentCultureIgnoreCase).ToList();
            SaveCachedGames();
            selected = 0;
            if (showNotice) ShowNotice("Library refreshed — " + games.Count.ToString(CultureInfo.InvariantCulture) + " games");
            RenderPage();
            if (IsXboxFamily()) QueueXboxArtworkRefresh();
        }

        private static string CleanName(string value)
        {
            if (String.IsNullOrWhiteSpace(value)) return "Unknown Game";
            string name = value.Replace('_', ' ').Replace('.', ' ').Trim();
            int disc = name.IndexOf("(Disc", StringComparison.OrdinalIgnoreCase);
            if (disc > 0) name = name.Substring(0, disc).Trim();
            return name;
        }

        private string FindCover(string gamePath)
        {
            string folder = Path.GetDirectoryName(gamePath);
            string baseName = Path.GetFileNameWithoutExtension(gamePath);
            foreach (string extension in new string[] { ".png", ".jpg", ".jpeg", ".webp" })
            {
                string sidecar = Path.Combine(folder, baseName + extension);
                if (File.Exists(sidecar)) return sidecar;
                string cover = Path.Combine(folder, "covers", baseName + extension);
                if (File.Exists(cover)) return cover;
            }
            if (IsXboxFamily())
            {
                string shared = FindSharedArtwork(CleanName(baseName));
                if (!String.IsNullOrWhiteSpace(shared)) return shared;
                string cached = GetXboxArtworkCachePath(CleanName(baseName));
                if (File.Exists(cached)) return cached;
            }
            return String.Empty;
        }

        private static string NormalizeArtworkTitle(string value)
        {
            if (String.IsNullOrWhiteSpace(value)) return String.Empty;
            string normalized = value.ToLowerInvariant();
            normalized = System.Text.RegularExpressions.Regex.Replace(normalized, @"\([^)]*(usa|europe|world|japan|disc|disk|rev|beta|demo)[^)]*\)", " ");
            normalized = System.Text.RegularExpressions.Regex.Replace(normalized, @"\[[^]]+\]", " ");
            normalized = System.Text.RegularExpressions.Regex.Replace(normalized, @"[^a-z0-9]+", " ");
            return normalized.Trim();
        }

        private void RefreshSharedArtworkIndex()
        {
            if ((DateTime.UtcNow - sharedArtworkIndexLoadedUtc).TotalSeconds < 20 && sharedArtworkIndex != null) return;
            Dictionary<string, string> updated = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
            try
            {
                string path = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "Huymaier Console", "ArtworkCache", "artwork-index.tsv");
                if (File.Exists(path))
                {
                    foreach (string rawLine in File.ReadAllLines(path))
                    {
                        string line = rawLine == null ? String.Empty : rawLine.TrimStart('﻿');
                        int tab = line.IndexOf('	');
                        if (tab <= 0 || tab >= line.Length - 1) continue;
                        string key = line.Substring(0, tab);
                        string artworkPath = line.Substring(tab + 1);
                        if (File.Exists(artworkPath)) updated[key] = artworkPath;
                    }
                }
            }
            catch { }
            sharedArtworkIndex = updated;
            sharedArtworkIndexLoadedUtc = DateTime.UtcNow;
        }

        private string FindSharedArtwork(string title)
        {
            try
            {
                RefreshSharedArtworkIndex();
                string key = "*|" + NormalizeArtworkTitle(title);
                string path;
                if (sharedArtworkIndex != null && sharedArtworkIndex.TryGetValue(key, out path) && File.Exists(path)) return path;
            }
            catch { }
            return String.Empty;
        }

        private string GetXboxArtworkCachePath(string title)
        {
            string safe = title ?? "game";
            foreach (char invalid in Path.GetInvalidFileNameChars()) safe = safe.Replace(invalid, '_');
            safe = new string(safe.Select(delegate(char c) { return Char.IsLetterOrDigit(c) || c == ' ' || c == '-' || c == '_' || c == '.' ? c : '_'; }).ToArray()).Trim();
            if (safe.Length > 110) safe = safe.Substring(0, 110);
            if (String.IsNullOrWhiteSpace(safe)) safe = "game";
            string folder = Path.Combine(dataRoot, "Artwork", "BoxArt");
            try { Directory.CreateDirectory(folder); } catch { }
            return Path.Combine(folder, safe + ".png");
        }

        private static List<string> GetXboxArtworkNameVariants(string title)
        {
            List<string> values = new List<string>();
            Action<string> add = delegate(string value)
            {
                if (String.IsNullOrWhiteSpace(value)) return;
                value = value.Trim();
                if (!values.Contains(value, StringComparer.OrdinalIgnoreCase)) values.Add(value);
            };
            add(title);
            string baseName = title ?? String.Empty;
            baseName = System.Text.RegularExpressions.Regex.Replace(baseName, @"\s*[\(\[].*?[\)\]]\s*", " ").Trim();
            baseName = System.Text.RegularExpressions.Regex.Replace(baseName, @"(?i)\s*[-:]?\s*(game of the year|goty|complete|definitive|ultimate|deluxe|special|remastered|remaster|enhanced|anniversary|edition)\b.*$", String.Empty).Trim();
            add(baseName);
            add(baseName.Replace("&", "and"));
            add(baseName.Replace(" and ", " & "));
            if (!String.IsNullOrWhiteSpace(baseName))
            {
                add(baseName + " (USA)");
                add(baseName + " (Europe)");
                add(baseName + " (World)");
            }
            return values;
        }

        private string TryDownloadXboxCover(ConsolePlatformGame game)
        {
            if (game == null || String.IsNullOrWhiteSpace(game.Name)) return String.Empty;
            string shared = FindSharedArtwork(game.Name);
            if (!String.IsNullOrWhiteSpace(shared)) return shared;
            string target = GetXboxArtworkCachePath(game.Name);
            if (File.Exists(target)) return target;
            string repo = definition.Shell == "Xbox360" ? "Microsoft_-_Xbox_360" : "Microsoft_-_Xbox";
            string libretroSystem = definition.Shell == "Xbox360" ? "Microsoft - Xbox 360" : "Microsoft - Xbox";
            string libretroSystemEncoded = Uri.EscapeDataString(libretroSystem);
            string temp = target + ".download";
            foreach (string variant in GetXboxArtworkNameVariants(game.Name))
            {
                string encoded = Uri.EscapeDataString(variant);
                string[] urls = new string[]
                {
                    "https://thumbnails.libretro.com/" + libretroSystemEncoded + "/Named_Boxarts/" + encoded + ".png",
                    "https://raw.githubusercontent.com/libretro-thumbnails/" + repo + "/master/Named_Boxarts/" + encoded + ".png"
                };
                foreach (string url in urls)
                {
                    try
                    {
                        HttpWebRequest request = (HttpWebRequest)WebRequest.Create(url);
                        request.UserAgent = "HuymaierConsole/0.25.6";
                        request.Timeout = 4500; request.ReadWriteTimeout = 6500;
                        request.AutomaticDecompression = DecompressionMethods.GZip | DecompressionMethods.Deflate;
                        using (WebResponse response = request.GetResponse())
                        using (Stream input = response.GetResponseStream())
                        using (FileStream output = File.Create(temp)) input.CopyTo(output);
                        if (IsDownloadedPng(temp))
                        {
                            if (File.Exists(target)) File.Delete(target);
                            File.Move(temp, target);
                            return target;
                        }
                    }
                    catch { }
                    try { if (File.Exists(temp)) File.Delete(temp); } catch { }
                }
            }
            return String.Empty;
        }

        private static bool IsDownloadedPng(string path)
        {
            try
            {
                if (!File.Exists(path) || new FileInfo(path).Length < 1024) return false;
                byte[] header = new byte[8];
                using (FileStream stream = File.OpenRead(path))
                {
                    if (stream.Read(header, 0, header.Length) != header.Length) return false;
                }
                return header[0] == 0x89 && header[1] == 0x50 && header[2] == 0x4E && header[3] == 0x47;
            }
            catch { return false; }
        }

        private void QueueXboxArtworkRefresh()
        {
            if (closing || !IsXboxFamily() || xboxArtworkScanRunning || games == null || games.Count == 0) return;
            List<ConsolePlatformGame> missing = games.Where(delegate(ConsolePlatformGame game)
            {
                return game != null && !String.IsNullOrWhiteSpace(game.Path) && (String.IsNullOrWhiteSpace(game.Cover) || !File.Exists(game.Cover));
            }).Select(delegate(ConsolePlatformGame game)
            {
                return new ConsolePlatformGame { Name = game.Name, Path = game.Path, Cover = game.Cover };
            }).ToList();
            if (missing.Count == 0) return;
            xboxArtworkScanRunning = true;
            int generation = asyncGeneration;
            System.Threading.ThreadPool.QueueUserWorkItem(delegate
            {
                try
                {
                    Dictionary<string, string> found = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
                    foreach (ConsolePlatformGame game in missing)
                    {
                        if (closing || generation != asyncGeneration) break;
                        if (game == null || String.IsNullOrWhiteSpace(game.Path)) continue;
                        string cover = TryDownloadXboxCover(game);
                        if (!String.IsNullOrWhiteSpace(cover)) found[game.Path] = cover;
                    }
                    try
                    {
                        if (Dispatcher.HasShutdownStarted || Dispatcher.HasShutdownFinished) return;
                        Dispatcher.BeginInvoke(new Action(delegate
                        {
                            if (!CanApplyAsync(generation)) return;
                            xboxArtworkScanRunning = false;
                            int added = 0;
                            foreach (ConsolePlatformGame game in games)
                            {
                                string cover;
                                if (game != null && !String.IsNullOrWhiteSpace(game.Path) && found.TryGetValue(game.Path, out cover) && File.Exists(cover)) { game.Cover = cover; added++; }
                            }
                            if (added > 0)
                            {
                                SaveCachedGames();
                                RenderPage();
                                ShowNotice(added.ToString(CultureInfo.InvariantCulture) + " online game cover" + (added == 1 ? "" : "s") + " added");
                            }
                        }));
                    }
                    catch (Exception ex) { WritePlatformLog(definition.DisplayName + " artwork UI callback was cancelled safely: " + ex.Message, "WARN"); }
                }
                catch (Exception ex)
                {
                    xboxArtworkScanRunning = false;
                    WritePlatformLog(definition.DisplayName + " artwork worker recovered from an unexpected error: " + ex, "ERROR");
                }
            });
        }

        private void LaunchGame(ConsolePlatformGame game, bool useFallback)
        {
            if (game == null || !File.Exists(game.Path)) { ShowNotice("Game file is missing"); return; }
            string executable = useFallback ? settings.fallbackEmulatorPath : settings.emulatorPath;
            if (String.IsNullOrWhiteSpace(executable) || !File.Exists(executable))
            {
                executable = useFallback ? definition.FindFallbackEmulator(settings.emulatorPath) : definition.FindPrimaryEmulator();
                if (useFallback) settings.fallbackEmulatorPath = executable; else settings.emulatorPath = executable;
                settings.Save(settingsPath);
            }
            if (String.IsNullOrWhiteSpace(executable) || !File.Exists(executable))
            {
                page = GetSettingsPageIndex(); selected = 0; RenderPage(); ShowNotice("Select " + (useFallback ? definition.FallbackBackend : definition.PrimaryBackend) + " first"); return;
            }
            try
            {
                try { ambiencePlayer.Pause(); } catch { }
                ProcessStartInfo info = new ProcessStartInfo();
                info.FileName = executable;
                info.WorkingDirectory = Path.GetDirectoryName(executable);
                info.Arguments = BuildLaunchArguments(executable, game.Path);
                info.UseShellExecute = true;
                activeProcess = Process.Start(info);
                if (activeProcess == null) throw new InvalidOperationException("Windows did not return an emulator process.");
                Process launched = activeProcess;
                launched.EnableRaisingEvents = true;
                EventHandler restore = null;
                restore = delegate
                {
                    try { launched.Exited -= restore; } catch { }
                    Dispatcher.BeginInvoke(new Action(delegate
                    {
                        try { launched.Dispose(); } catch { }
                        if (Object.ReferenceEquals(activeProcess, launched)) activeProcess = null;
                        dashboardSubpage = String.Empty; page = definition.Shell == "Xbox360" ? (IsBlades() ? 1 : 2) : 0; selected = 0;
                        Show();
                        WindowState = WindowState.Maximized;
                        NativeWindowActivation.Restore(this);
                        input.Reset();
                        inputGuardUntilUtc = DateTime.UtcNow.AddMilliseconds(900);
                        StartAmbience();
                        RenderPage();
                    }));
                };
                launched.Exited += restore;
                Hide();
                if (launched.HasExited) restore(launched, EventArgs.Empty);
            }
            catch (Exception ex)
            {
                activeProcess = null;
                Show();
                NativeWindowActivation.Restore(this);
                StartAmbience();
                ShowNotice("Emulator launch failed: " + ex.Message);
            }
        }

        private string BuildLaunchArguments(string executable, string gamePath)
        {
            string exe = Path.GetFileName(executable).ToLowerInvariant();
            string quoted = "\"" + gamePath.Replace("\"", String.Empty) + "\"";
            if (definition.Shell == "GameCube" || definition.Shell == "Wii") return "-b -e " + quoted;
            if (definition.Shell == "WiiU") return "-g " + quoted + " -f";
            if (definition.Shell == "N64" && exe.IndexOf("ares", StringComparison.OrdinalIgnoreCase) >= 0) return "--fullscreen --no-file-prompt " + quoted;
            if (definition.Shell == "Switch" && exe.IndexOf("ryujinx", StringComparison.OrdinalIgnoreCase) >= 0) return "--fullscreen " + quoted;
            if (definition.Shell == "Switch") return "-f -g " + quoted;
            if (definition.Shell == "Xbox" && exe.IndexOf("xemu", StringComparison.OrdinalIgnoreCase) >= 0) return "-full-screen -dvd_path " + quoted;
            return quoted;
        }

        private List<string> FindSaveRoots()
        {
            List<string> roots = new List<string>();
            string app = Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData);
            string local = Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData);
            string docs = Environment.GetFolderPath(Environment.SpecialFolder.MyDocuments);
            string exeRoot = !String.IsNullOrWhiteSpace(settings.emulatorPath) && File.Exists(settings.emulatorPath) ? Path.GetDirectoryName(settings.emulatorPath) : String.Empty;
            if (definition.Shell == "GameCube" || definition.Shell == "Wii")
            {
                AddExisting(roots, Path.Combine(docs, "Dolphin Emulator", "GC"));
                AddExisting(roots, Path.Combine(docs, "Dolphin Emulator", "Wii"));
                AddExisting(roots, Path.Combine(exeRoot, "User", "GC"));
                AddExisting(roots, Path.Combine(exeRoot, "User", "Wii"));
            }
            else if (definition.Shell == "WiiU") { AddExisting(roots, Path.Combine(exeRoot, "mlc01", "usr", "save")); AddExisting(roots, Path.Combine(local, "Cemu", "mlc01", "usr", "save")); }
            else if (definition.Shell == "Switch") { AddExisting(roots, Path.Combine(app, "Ryujinx", "bis", "user", "save")); AddExisting(roots, Path.Combine(app, "Eden", "nand", "user", "save")); }
            else if (definition.Shell == "Xbox") { AddExisting(roots, Path.Combine(app, "xemu")); AddExisting(roots, Path.Combine(local, "xemu")); }
            else if (definition.Shell == "Xbox360") { AddExisting(roots, Path.Combine(exeRoot, "content")); AddExisting(roots, Path.Combine(docs, "Xenia", "content")); }
            else { AddExisting(roots, Path.Combine(app, "RMG")); AddExisting(roots, Path.Combine(exeRoot, "Save")); }
            return roots;
        }

        private static void AddExisting(List<string> roots, string path)
        {
            if (String.IsNullOrWhiteSpace(path) || !Directory.Exists(path)) return;
            if (!roots.Contains(path, StringComparer.OrdinalIgnoreCase)) roots.Add(path);
        }

        private void BackupSaves()
        {
            List<string> roots = FindSaveRoots();
            if (roots.Count == 0) { ShowNotice("No save folder was detected"); return; }
            string target = Path.Combine(dataRoot, "Backups", DateTime.Now.ToString("yyyyMMdd-HHmmss", CultureInfo.InvariantCulture));
            Directory.CreateDirectory(target);
            int copied = 0;
            foreach (string rootPath in roots)
            {
                string destination = Path.Combine(target, Sanitize(Path.GetFileName(rootPath.TrimEnd(Path.DirectorySeparatorChar))));
                copied += CopyDirectory(rootPath, destination, 3000);
            }
            ShowNotice("Backed up " + copied.ToString(CultureInfo.InvariantCulture) + " save files");
        }

        private static int CopyDirectory(string source, string destination, int limit)
        {
            int count = 0;
            try
            {
                foreach (string file in Directory.EnumerateFiles(source, "*", SearchOption.AllDirectories))
                {
                    if (count >= limit) break;
                    string relative = file.Substring(source.TrimEnd(Path.DirectorySeparatorChar).Length).TrimStart(Path.DirectorySeparatorChar);
                    string target = Path.Combine(destination, relative);
                    Directory.CreateDirectory(Path.GetDirectoryName(target));
                    File.Copy(file, target, true);
                    count++;
                }
            }
            catch { }
            return count;
        }

        private void PlayEffect(string fileName)
        {
            string path = Path.Combine(platformRoot, "Assets", fileName);
            if (!File.Exists(path)) path = Path.Combine(consoleRoot, "Assets", fileName);
            if (!File.Exists(path)) return;
            try { effectPlayer.Stop(); effectPlayer.Close(); effectPlayer.Open(new Uri(path)); effectPlayer.Volume = settings.soundVolume; effectPlayer.Play(); } catch { }
        }

        private Grid BuildDashboardGuideOverlay()
        {
            Grid overlay = new Grid { Background = new SolidColorBrush(Color.FromArgb(165, 0, 0, 0)), Visibility = Visibility.Collapsed }; Panel.SetZIndex(overlay, 4500); return overlay;
        }

        private void PopulateDashboardGuideOverlay()
        {
            dashboardGuideOverlay.Children.Clear(); Border card = new Border { Width = 560, MinHeight = 590, HorizontalAlignment = HorizontalAlignment.Center, VerticalAlignment = VerticalAlignment.Center, Background = new SolidColorBrush(Color.FromRgb(236, 238, 237)), BorderBrush = new SolidColorBrush(Color.FromRgb(107, 181, 43)), BorderThickness = new Thickness(5), Padding = new Thickness(28) }; StackPanel panel = new StackPanel(); panel.Children.Add(new TextBlock { Text = "XBOX GUIDE", FontSize = 31, FontWeight = FontWeights.Light, Foreground = new SolidColorBrush(Color.FromRgb(44, 49, 47)), HorizontalAlignment = HorizontalAlignment.Center, Margin = new Thickness(0, 0, 0, 22) }); panel.Children.Add(CreateGuideRow("Profile", Environment.UserName)); panel.Children.Add(CreateGuideRow("Gamerscore", GetXboxGamerscore().ToString(CultureInfo.InvariantCulture) + " G")); panel.Children.Add(CreateGuideRow("Achievements", xboxAchievementsLoaded ? xboxAchievements.Count(delegate(XboxAchievementEntry a) { return a.Earned; }).ToString(CultureInfo.InvariantCulture) + " unlocked" : "Open Achievements to scan")); panel.Children.Add(CreateGuideRow("Storage", xboxSaveEntries.Count.ToString(CultureInfo.InvariantCulture) + " save item(s)")); panel.Children.Add(CreateGuideRow("Xbox Home", "Press GUIDE or B to close")); card.Child = panel; dashboardGuideOverlay.Children.Add(card);
        }


        private Border CreateGuideRow(string title, string detail)
        {
            Grid row = new Grid { Margin = new Thickness(0, 0, 0, 8) }; row.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(190) }); row.ColumnDefinitions.Add(new ColumnDefinition());
            row.Children.Add(new TextBlock { Text = title, FontSize = 19, FontWeight = FontWeights.SemiBold, Foreground = new SolidColorBrush(Color.FromRgb(45, 51, 48)), Margin = new Thickness(12), VerticalAlignment = VerticalAlignment.Center });
            TextBlock text = new TextBlock { Text = detail, FontSize = 13, Foreground = new SolidColorBrush(Color.FromRgb(84, 93, 88)), Margin = new Thickness(12), VerticalAlignment = VerticalAlignment.Center, TextTrimming = TextTrimming.CharacterEllipsis }; Grid.SetColumn(text, 1); row.Children.Add(text);
            return new Border { MinHeight = 62, Background = Brushes.White, BorderBrush = new SolidColorBrush(Color.FromRgb(188, 196, 192)), BorderThickness = new Thickness(1), Child = row };
        }

        private void ToggleDashboardGuide()
        {
            if (definition.Shell != "Xbox360") return; dashboardGuideVisible = !dashboardGuideVisible; if (dashboardGuideVisible) PopulateDashboardGuideOverlay(); dashboardGuideOverlay.Visibility = dashboardGuideVisible ? Visibility.Visible : Visibility.Collapsed; if (dashboardGuideVisible) PlayEffect("Tab.wav"); else PlayEffect("Back.wav");
        }


        private List<ConsolePlatformGame> LoadCachedGames()
        {
            try
            {
                if (File.Exists(libraryCachePath))
                {
                    List<ConsolePlatformGame> value = new JavaScriptSerializer().Deserialize<List<ConsolePlatformGame>>(File.ReadAllText(libraryCachePath, Encoding.UTF8));
                    if (value != null) return value.Where(delegate(ConsolePlatformGame g) { return g != null && !String.IsNullOrWhiteSpace(g.Path); }).ToList();
                }
            }
            catch { }
            return new List<ConsolePlatformGame>();
        }

        private void SaveCachedGames()
        {
            try { File.WriteAllText(libraryCachePath, new JavaScriptSerializer().Serialize(games), Encoding.UTF8); } catch { }
        }

        private static BitmapSource LoadBitmap(string path)
        {
            BitmapImage bitmap = new BitmapImage();
            bitmap.BeginInit();
            bitmap.CacheOption = BitmapCacheOption.OnLoad;
            bitmap.UriSource = new Uri(path, UriKind.Absolute);
            bitmap.DecodePixelWidth = 420;
            bitmap.EndInit();
            bitmap.Freeze();
            return bitmap;
        }

        private void ShowNotice(string text)
        {
            noticeText.Text = text ?? String.Empty;
            noticeUntilUtc = DateTime.UtcNow.AddSeconds(5);
        }

        private void UpdateNotice()
        {
            if (DateTime.UtcNow >= noticeUntilUtc && !String.IsNullOrWhiteSpace(noticeText.Text)) noticeText.Text = String.Empty;
        }

        private static string DisplayPath(string value) { return String.IsNullOrWhiteSpace(value) ? "Not configured" : value; }
        private static string Sanitize(string value)
        {
            if (String.IsNullOrWhiteSpace(value)) return "Saves";
            foreach (char invalid in Path.GetInvalidFileNameChars()) value = value.Replace(invalid, '_');
            return value;
        }
    }
}
