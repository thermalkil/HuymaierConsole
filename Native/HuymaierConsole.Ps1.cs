using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Runtime.InteropServices;
using System.Text;
using System.Text.RegularExpressions;
using System.Threading;
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
    public sealed class Ps1Settings
    {
        public string duckStationPath { get; set; }
        public string dataRoot { get; set; }
        public List<string> gameFolders { get; set; }
        public bool bigPictureEnabled { get; set; }
        public bool slowBootEnabled { get; set; }
        public bool platformBootEnabled { get; set; }
        public string startupAudioPath { get; set; }
        public string ambienceAudioPath { get; set; }
        public double musicVolume { get; set; }
        public string shellStyle { get; set; }

        public Ps1Settings()
        {
            duckStationPath = String.Empty;
            dataRoot = String.Empty;
            gameFolders = new List<string>();
            bigPictureEnabled = true;
            slowBootEnabled = false;
            platformBootEnabled = true;
            startupAudioPath = String.Empty;
            ambienceAudioPath = String.Empty;
            musicVolume = 0.55;
            shellStyle = "Original";
        }

        public static Ps1Settings Load(string path)
        {
            Ps1Settings value = new Ps1Settings();
            try
            {
                if (File.Exists(path))
                {
                    Ps1Settings parsed = new JavaScriptSerializer().Deserialize<Ps1Settings>(File.ReadAllText(path, Encoding.UTF8));
                    if (parsed != null) value = parsed;
                }
            }
            catch { }
            if (value.gameFolders == null) value.gameFolders = new List<string>();
            if (String.IsNullOrWhiteSpace(value.duckStationPath)) value.duckStationPath = Ps1Environment.FindDuckStationExecutable();
            if (String.IsNullOrWhiteSpace(value.dataRoot)) value.dataRoot = Ps1Environment.FindDataRoot(value.duckStationPath);
            if (!String.Equals(value.shellStyle, "Updated", StringComparison.OrdinalIgnoreCase)) value.shellStyle = "Original";
            return value;
        }

        public void Save(string path)
        {
            Directory.CreateDirectory(Path.GetDirectoryName(path));
            File.WriteAllText(path, new JavaScriptSerializer().Serialize(this), Encoding.UTF8);
        }
    }

    public sealed class Ps1Game
    {
        public string Name { get; set; }
        public string SortName { get; set; }
        public string Serial { get; set; }
        public string CoverPath { get; set; }
        public List<string> Discs { get; set; }
        public string PrimaryPath { get; set; }

        public Ps1Game()
        {
            Name = String.Empty;
            SortName = String.Empty;
            Serial = String.Empty;
            CoverPath = String.Empty;
            PrimaryPath = String.Empty;
            Discs = new List<string>();
        }
    }

    public sealed class Ps1MusicTrack
    {
        public string AlbumName { get; set; }
        public string Title { get; set; }
        public string SourcePath { get; set; }
        public string SourceType { get; set; }
        public int DiscNumber { get; set; }
        public int TrackNumber { get; set; }
        public long StartSector { get; set; }
        public long EndSector { get; set; }

        public Ps1MusicTrack()
        {
            AlbumName = String.Empty; Title = String.Empty; SourcePath = String.Empty; SourceType = String.Empty;
            DiscNumber = 1; TrackNumber = 1; StartSector = 0; EndSector = -1;
        }
    }

    public sealed class Ps1MusicAlbum
    {
        public string Name { get; set; }
        public string CoverPath { get; set; }
        public List<Ps1MusicTrack> Tracks { get; set; }

        public Ps1MusicAlbum()
        {
            Name = String.Empty; CoverPath = String.Empty; Tracks = new List<Ps1MusicTrack>();
        }
    }

    public sealed class Ps1SaveEntry
    {
        public int FirstSlot { get; set; }
        public List<int> Slots { get; set; }
        public string FileName { get; set; }
        public string Title { get; set; }
        public int Blocks { get; set; }
        public BitmapSource Icon { get; set; }

        public Ps1SaveEntry()
        {
            Slots = new List<int>();
            FileName = String.Empty;
            Title = String.Empty;
        }
    }

    public sealed class Ps1StateEntry
    {
        public string Path { get; set; }
        public string Name { get; set; }
        public string GameName { get; set; }
        public DateTime Modified { get; set; }
        public long Size { get; set; }

        public Ps1StateEntry()
        {
            Path = String.Empty;
            Name = String.Empty;
            GameName = String.Empty;
        }
    }

    internal sealed class Ps1UiAction
    {
        internal Button Button;
        internal Action Invoke;
        internal string Name;
        internal char Letter;
    }

    public sealed class Ps1ClassicWindow : Window
    {
        private const int WmInputDeviceChange = 0x00FE;
        private readonly string platformRoot;
        private readonly string consoleRoot;
        private readonly string dataHome;
        private readonly string settingsPath;
        private readonly string libraryCachePath;
        private readonly string logPath;
        private Ps1Settings settings;
        private readonly Grid root;
        private readonly Grid contentHost;
        private readonly StackPanel navPanel;
        private readonly TextBlock sectionTitle;
        private readonly TextBlock sectionSubtitle;
        private readonly TextBlock noticeText;
        private readonly TextBlock footerText;
        private readonly List<Ps1UiAction> actions;
        private readonly List<Button> navButtons;
        private readonly System.Windows.Threading.DispatcherTimer inputTimer;
        private readonly MediaPlayer musicPlayer;
        private readonly MediaPlayer trackPlayer;
        private List<Ps1Game> games;
        private List<Ps1Game> cachedLibraryEntries;
        private List<Ps1MusicAlbum> musicAlbums;
        private bool musicIndexReady;
        private bool musicIndexLoading;
        private Ps1MusicAlbum browsedMusicAlbum;
        private Ps1MusicAlbum playingMusicAlbum;
        private int playingMusicTrackIndex;
        private bool musicTrackActive;
        private bool musicTrackPaused;
        private int section;
        private int selected;
        private int columns;
        private bool letterMode;
        private int letterIndex;
        private string activeCardPath;
        private List<Ps1SaveEntry> activeSaves;
        private List<Ps1StateEntry> states;
        private bool subviewOpen;
        private Process activeProcess;
        private HwndSource source;
        private HwndSourceHook sourceHook;
        private bool scanning;
        private DateTime noticeUntil;
        private readonly char[] letters;
        private readonly Grid bootOverlay;
        private readonly ConsoleStartupVideoOverlay startupVideoOverlay;
        private readonly System.Windows.Threading.DispatcherTimer bootTimer;
        private readonly ScaleTransform bootScale;
        private DateTime bootStartedUtc;
        private bool bootActive;
        private bool navigationMode;
        private int navigationSelected;
        private bool playingStartupAudio;
        private string activeAmbiencePath;

        public Ps1ClassicWindow(string platformRootValue, string consoleRootValue)
        {
            platformRoot = platformRootValue ?? String.Empty;
            consoleRoot = consoleRootValue ?? String.Empty;
            dataHome = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "Huymaier Console", "EmulatorPlatforms", "PS1");
            settingsPath = Path.Combine(dataHome, "settings.json");
            libraryCachePath = Path.Combine(dataHome, "library-cache.json");
            logPath = Path.Combine(dataHome, "ps1-native.log");
            Directory.CreateDirectory(dataHome);
            Directory.CreateDirectory(Path.Combine(dataHome, "Backups"));
            Directory.CreateDirectory(Path.Combine(dataHome, "Exports"));
            Directory.CreateDirectory(Path.Combine(dataHome, "MusicCache"));
            settings = Ps1Settings.Load(settingsPath);
            settings.Save(settingsPath);
            cachedLibraryEntries = new List<Ps1Game>();
            musicAlbums = new List<Ps1MusicAlbum>();
            musicIndexReady = false;
            musicIndexLoading = false;
            browsedMusicAlbum = null;
            playingMusicAlbum = null;
            playingMusicTrackIndex = -1;
            musicTrackActive = false;
            musicTrackPaused = false;
            games = LoadLibraryCacheFast();
            activeSaves = new List<Ps1SaveEntry>();
            states = new List<Ps1StateEntry>();
            subviewOpen = false;
            actions = new List<Ps1UiAction>();
            navButtons = new List<Button>();
            letters = "#ABCDEFGHIJKLMNOPQRSTUVWXYZ".ToCharArray();
            columns = 6;
            activeCardPath = String.Empty;
            section = 4;
            selected = 0;
            navigationMode = false;
            navigationSelected = 0;
            bootActive = false;
            playingStartupAudio = false;
            activeAmbiencePath = String.Empty;

            Title = "PlayStation";
            WindowStyle = WindowStyle.None;
            ResizeMode = ResizeMode.NoResize;
            WindowState = WindowState.Maximized;
            Background = Brushes.Black;
            Foreground = Brushes.White;
            ShowInTaskbar = false;
            SnapsToDevicePixels = true;
            UseLayoutRounding = true;

            root = new Grid();
            root.Background = BuildBackgroundBrush();
            root.RowDefinitions.Add(new RowDefinition { Height = new GridLength(1, GridUnitType.Star) });
            root.RowDefinitions.Add(new RowDefinition { Height = new GridLength(48) });

            navPanel = new StackPanel { Visibility = Visibility.Collapsed };
            BuildNavigation();
            sectionTitle = new TextBlock { Visibility = Visibility.Collapsed };
            sectionSubtitle = new TextBlock { Visibility = Visibility.Collapsed };

            contentHost = new Grid();
            contentHost.Margin = new Thickness(28, 18, 28, 8);
            root.Children.Add(contentHost);

            Grid footer = new Grid { Margin = new Thickness(30, 0, 30, 0) };
            footerText = new TextBlock { Text = "A / CROSS  Select    B / CIRCLE  Back    Y / TRIANGLE  Options", FontSize = 14, FontWeight = FontWeights.SemiBold, Foreground = Brushes.White, VerticalAlignment = VerticalAlignment.Center };
            footerText.Effect = new System.Windows.Media.Effects.DropShadowEffect { Color = Colors.Black, BlurRadius = 3, ShadowDepth = 1, Opacity = 0.8 };
            noticeText = new TextBlock { FontSize = 14, FontWeight = FontWeights.SemiBold, Foreground = new SolidColorBrush(Color.FromRgb(255, 226, 66)), HorizontalAlignment = HorizontalAlignment.Right, VerticalAlignment = VerticalAlignment.Center };
            footer.Children.Add(footerText);
            footer.Children.Add(noticeText);
            Grid.SetRow(footer, 1);
            root.Children.Add(footer);

            bootScale = new ScaleTransform(0.55, 0.55);
            bootOverlay = BuildBootOverlay();
            Grid.SetRowSpan(bootOverlay, 2);
            root.Children.Add(bootOverlay);
            startupVideoOverlay = new ConsoleStartupVideoOverlay();
            Grid.SetRowSpan(startupVideoOverlay, 2);
            root.Children.Add(startupVideoOverlay);
            bootTimer = new System.Windows.Threading.DispatcherTimer(System.Windows.Threading.DispatcherPriority.Render);
            bootTimer.Interval = TimeSpan.FromMilliseconds(16);
            bootTimer.Tick += delegate { UpdatePlatformBoot(); };

            Content = root;
            musicPlayer = new MediaPlayer();
            musicPlayer.MediaEnded += OnMusicEnded;
            trackPlayer = new MediaPlayer();
            trackPlayer.MediaEnded += OnTrackEnded;
            inputTimer = new System.Windows.Threading.DispatcherTimer(System.Windows.Threading.DispatcherPriority.Input);
            inputTimer.Interval = TimeSpan.FromMilliseconds(16);
            inputTimer.Tick += delegate { PollInput(); UpdateNotice(); };
            inputTimer.Start();

            SourceInitialized += OnSourceInitialized;
            Loaded += OnLoaded;
            Closed += OnClosed;
            PreviewKeyDown += OnPreviewKeyDown;
            SizeChanged += delegate { CalculateColumns(); };
            RenderSection();
        }

        private Grid BuildBootOverlay()
        {
            Grid overlay = new Grid();
            overlay.Background = Brushes.Black;
            overlay.Visibility = Visibility.Collapsed;
            overlay.Opacity = 1;
            overlay.IsHitTestVisible = true;

            Canvas canvas = new Canvas();
            canvas.Width = 560;
            canvas.Height = 360;
            canvas.HorizontalAlignment = HorizontalAlignment.Center;
            canvas.VerticalAlignment = VerticalAlignment.Center;
            canvas.RenderTransformOrigin = new Point(0.5, 0.48);
            canvas.RenderTransform = bootScale;

            System.Windows.Shapes.Rectangle blue = new System.Windows.Shapes.Rectangle();
            blue.Width = 48; blue.Height = 178; blue.RadiusX = 6; blue.RadiusY = 6;
            blue.Fill = new LinearGradientBrush(Color.FromRgb(36, 91, 195), Color.FromRgb(83, 145, 240), 90);
            blue.RenderTransform = new SkewTransform(-10, 0);
            Canvas.SetLeft(blue, 228); Canvas.SetTop(blue, 42); canvas.Children.Add(blue);

            System.Windows.Shapes.Rectangle red = new System.Windows.Shapes.Rectangle();
            red.Width = 150; red.Height = 34; red.RadiusX = 16; red.RadiusY = 16;
            red.Fill = new LinearGradientBrush(Color.FromRgb(212, 45, 42), Color.FromRgb(246, 126, 45), 0);
            red.RenderTransform = new RotateTransform(-14, 75, 17);
            Canvas.SetLeft(red, 208); Canvas.SetTop(red, 78); canvas.Children.Add(red);

            System.Windows.Shapes.Rectangle yellow = new System.Windows.Shapes.Rectangle();
            yellow.Width = 154; yellow.Height = 28; yellow.RadiusX = 14; yellow.RadiusY = 14;
            yellow.Fill = new LinearGradientBrush(Color.FromRgb(245, 183, 41), Color.FromRgb(255, 222, 102), 0);
            yellow.RenderTransform = new RotateTransform(10, 77, 14);
            Canvas.SetLeft(yellow, 196); Canvas.SetTop(yellow, 180); canvas.Children.Add(yellow);

            System.Windows.Shapes.Rectangle green = new System.Windows.Shapes.Rectangle();
            green.Width = 128; green.Height = 27; green.RadiusX = 14; green.RadiusY = 14;
            green.Fill = new LinearGradientBrush(Color.FromRgb(36, 151, 91), Color.FromRgb(87, 203, 132), 0);
            green.RenderTransform = new RotateTransform(-8, 64, 14);
            Canvas.SetLeft(green, 250); Canvas.SetTop(green, 211); canvas.Children.Add(green);

            TextBlock word = new TextBlock();
            word.Text = "PlayStation";
            word.FontSize = 42;
            word.FontWeight = FontWeights.SemiBold;
            word.Foreground = Brushes.White;
            word.HorizontalAlignment = HorizontalAlignment.Center;
            Canvas.SetLeft(word, 158); Canvas.SetTop(word, 270); canvas.Children.Add(word);

            TextBlock subtitle = new TextBlock();
            subtitle.Text = "HUYMAIER CONSOLE";
            subtitle.FontSize = 12;
            subtitle.FontWeight = FontWeights.SemiBold;
            subtitle.Foreground = new SolidColorBrush(Color.FromRgb(158, 166, 188));
            Canvas.SetLeft(subtitle, 216); Canvas.SetTop(subtitle, 326); canvas.Children.Add(subtitle);

            overlay.Children.Add(canvas);
            return overlay;
        }

        private void StartPlatformBoot()
        {
            bootActive = true;
            bootStartedUtc = DateTime.UtcNow;
            bootScale.ScaleX = 0.55;
            bootScale.ScaleY = 0.55;
            bootOverlay.Opacity = 1;
            bootOverlay.Visibility = Visibility.Visible;
            Panel.SetZIndex(bootOverlay, 1000);
            TryStartAudio();
            bootTimer.Start();
        }

        private void UpdatePlatformBoot()
        {
            if (!bootActive) return;
            double elapsed = (DateTime.UtcNow - bootStartedUtc).TotalSeconds;
            if (elapsed >= 4.6)
            {
                EndPlatformBoot();
                return;
            }
            double grow = Math.Min(1.0, elapsed / 2.4);
            double scale = 0.55 + (0.45 * (1.0 - Math.Pow(1.0 - grow, 3.0)));
            bootScale.ScaleX = scale;
            bootScale.ScaleY = scale;
            if (elapsed < 0.45) bootOverlay.Opacity = Math.Max(0, Math.Min(1, elapsed / 0.45));
            else if (elapsed > 3.7) bootOverlay.Opacity = Math.Max(0, 1.0 - ((elapsed - 3.7) / 0.9));
            else bootOverlay.Opacity = 1;
        }

        private void EndPlatformBoot()
        {
            if (!bootActive) return;
            bootActive = false;
            try { bootTimer.Stop(); } catch { }
            bootOverlay.Visibility = Visibility.Collapsed;
            bootOverlay.Opacity = 1;
            UpdateVisuals();
        }

        private Brush BuildBackgroundBrush()
        {
            if (String.Equals(settings.shellStyle, "Updated", StringComparison.OrdinalIgnoreCase))
            {
                DrawingGroup drawing = new DrawingGroup();
                drawing.Children.Add(new GeometryDrawing(new SolidColorBrush(Color.FromRgb(189, 192, 190)), null, new RectangleGeometry(new Rect(0, 0, 64, 64))));
                Pen dark = new Pen(new SolidColorBrush(Color.FromRgb(88, 94, 92)), 2);
                drawing.Children.Add(new GeometryDrawing(null, dark, new LineGeometry(new Point(0, 0), new Point(64, 0))));
                drawing.Children.Add(new GeometryDrawing(null, dark, new LineGeometry(new Point(0, 0), new Point(0, 64))));
                DrawingBrush tile = new DrawingBrush(drawing);
                tile.TileMode = TileMode.Tile;
                tile.Viewport = new Rect(0, 0, 64, 64);
                tile.ViewportUnits = BrushMappingMode.Absolute;
                tile.Stretch = Stretch.None;
                return tile;
            }
            RadialGradientBrush original = new RadialGradientBrush();
            original.Center = new Point(0.56, 0.48);
            original.GradientOrigin = new Point(0.56, 0.48);
            original.RadiusX = 0.78;
            original.RadiusY = 0.78;
            original.GradientStops.Add(new GradientStop(Color.FromRgb(64, 83, 221), 0));
            original.GradientStops.Add(new GradientStop(Color.FromRgb(16, 31, 110), 0.55));
            original.GradientStops.Add(new GradientStop(Color.FromRgb(1, 4, 30), 1));
            return original;
        }

        private Grid BuildHeader()
        {
            Grid header = new Grid { Margin = new Thickness(40, 16, 40, 0) };
            header.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
            header.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
            StackPanel logo = new StackPanel { Orientation = Orientation.Horizontal, VerticalAlignment = VerticalAlignment.Center };
            Border mark = new Border { Width = 54, Height = 54, CornerRadius = new CornerRadius(2), Background = new LinearGradientBrush(Color.FromRgb(29, 76, 151), Color.FromRgb(218, 62, 43), 45), BorderBrush = new SolidColorBrush(Color.FromRgb(61, 72, 83)), BorderThickness = new Thickness(2) };
            Grid markGrid = new Grid();
            markGrid.Children.Add(new TextBlock { Text = "P", FontSize = 34, FontWeight = FontWeights.Bold, Foreground = Brushes.White, HorizontalAlignment = HorizontalAlignment.Center, VerticalAlignment = VerticalAlignment.Center });
            mark.Child = markGrid;
            logo.Children.Add(mark);
            StackPanel words = new StackPanel { Margin = new Thickness(16, 3, 0, 0) };
            words.Children.Add(new TextBlock { Text = "PlayStation Browser", FontSize = 29, FontWeight = FontWeights.SemiBold, Foreground = new SolidColorBrush(Color.FromRgb(35, 45, 56)) });
            words.Children.Add(new TextBlock { Text = "MEMORY CARD / CD-ROM", FontSize = 11, Foreground = new SolidColorBrush(Color.FromRgb(65, 80, 95)), Margin = new Thickness(1, 1, 0, 0) });
            logo.Children.Add(words);
            header.Children.Add(logo);
            TextBlock clock = new TextBlock { FontSize = 14, Foreground = new SolidColorBrush(Color.FromRgb(43, 57, 70)), HorizontalAlignment = HorizontalAlignment.Right, VerticalAlignment = VerticalAlignment.Center };
            clock.Text = DateTime.Now.ToString("ddd  MMM d    h:mm tt", CultureInfo.CurrentCulture);
            Grid.SetColumn(clock, 1);
            header.Children.Add(clock);
            return header;
        }

        private void BuildNavigation()
        {
            navPanel.Children.Clear();
            navButtons.Clear();
            AddNav("CD-ROM", "PlayStation software", 0);
            AddNav("MUSIC PLAYER", "Game disc audio", 5);
            AddNav("MEMORY CARD", "Saved data browser", 1);
            AddNav("SAVE STATES", "DuckStation snapshots", 2);
            AddNav("OPTIONS", "System configuration", 3);
        }

        private void AddNav(string name, string detail, int index)
        {
            Button button = new Button();
            button.Tag = index;
            button.Height = 82;
            button.Margin = new Thickness(0, 0, 0, 10);
            button.Padding = new Thickness(18, 10, 14, 10);
            button.HorizontalContentAlignment = HorizontalAlignment.Left;
            button.Background = new LinearGradientBrush(Color.FromRgb(201, 207, 211), Color.FromRgb(143, 155, 165), 90);
            button.BorderBrush = new SolidColorBrush(Color.FromRgb(71, 88, 105));
            button.BorderThickness = new Thickness(2);
            button.Template = (ControlTemplate)System.Windows.Markup.XamlReader.Parse("<ControlTemplate xmlns=\"http://schemas.microsoft.com/winfx/2006/xaml/presentation\" TargetType=\"Button\"><Border Background=\"{TemplateBinding Background}\" BorderBrush=\"{TemplateBinding BorderBrush}\" BorderThickness=\"{TemplateBinding BorderThickness}\" CornerRadius=\"14\"><ContentPresenter/></Border></ControlTemplate>");
            StackPanel stack = new StackPanel();
            stack.Children.Add(new TextBlock { Text = name, FontSize = 20, FontWeight = FontWeights.SemiBold, Foreground = new SolidColorBrush(Color.FromRgb(35, 48, 61)) });
            stack.Children.Add(new TextBlock { Text = detail, FontSize = 11, Foreground = new SolidColorBrush(Color.FromRgb(77, 93, 107)), Margin = new Thickness(0, 3, 0, 0) });
            button.Content = stack;
            button.Click += delegate
            {
                section = (int)button.Tag;
                selected = 0;
                letterMode = false;
                navigationMode = false;
                navigationSelected = navButtons.IndexOf(button);
                RenderSection();
            };
            navPanel.Children.Add(button);
            navButtons.Add(button);
        }

        private void OnLoaded(object sender, RoutedEventArgs e)
        {
            CalculateColumns();
            string startup = Path.Combine(platformRoot, "Assets", "Startup.mp4");
            if (settings.platformBootEnabled) startupVideoOverlay.Play(startup, 1.0, TryStartAudio); else TryStartAudio();
            // Never parse CUE sheets while the modal window is being constructed.  The
            // v0.24.22 synchronous music index could hold ShowDialog before the PS1 shell
            // became visible on large/network libraries.  Build it only after the window
            // is already on screen.
            QueueMusicIndexBuild();
            WriteLog("PS1 shell opened; cached games rendered before music indexing.", "INFO");
        }

        private void OnSourceInitialized(object sender, EventArgs e)
        {
            try
            {
                WindowInteropHelper helper = new WindowInteropHelper(this);
                HuymaierConsole.Native.RawHidController.Register(helper.Handle);
                source = HwndSource.FromHwnd(helper.Handle);
                sourceHook = new HwndSourceHook(WindowMessage);
                if (source != null) source.AddHook(sourceHook);
            }
            catch { }
        }

        private IntPtr WindowMessage(IntPtr hwnd, int msg, IntPtr wParam, IntPtr lParam, ref bool handled)
        {
            if (msg == WmInputDeviceChange)
            {
                try
                {
                    HuymaierConsole.Native.RawHidController.ProcessDeviceChange(wParam, lParam);
                    NativeConsoleNavigation.NotifyDeviceChange();
                }
                catch { }
            }
            return IntPtr.Zero;
        }

        private void OnClosed(object sender, EventArgs e)
        {
            try { inputTimer.Stop(); } catch { }
            try { bootTimer.Stop(); } catch { }
            try { startupVideoOverlay.Stop(); } catch { }
            try { musicPlayer.Stop(); musicPlayer.Close(); } catch { }
            try { trackPlayer.Stop(); trackPlayer.Close(); } catch { }
            try { if (source != null && sourceHook != null) source.RemoveHook(sourceHook); } catch { }
        }

        private void TryStartAudio()
        {
            activeAmbiencePath = settings.ambienceAudioPath ?? String.Empty;
            if (musicTrackActive) return;
            try
            {
                musicPlayer.Stop();
                musicPlayer.Close();
                musicPlayer.Volume = Math.Max(0, Math.Min(1, settings.musicVolume));
                playingStartupAudio = false;
                if (!String.IsNullOrWhiteSpace(activeAmbiencePath) && File.Exists(activeAmbiencePath))
                {
                    musicPlayer.Open(new Uri(activeAmbiencePath));
                    musicPlayer.Play();
                }
            }
            catch { playingStartupAudio = false; }
        }

        private void OnMusicEnded(object sender, EventArgs e)
        {
            try
            {
                if (musicTrackActive) return;
                if (!String.IsNullOrWhiteSpace(activeAmbiencePath) && File.Exists(activeAmbiencePath))
                {
                    playingStartupAudio = false;
                    musicPlayer.Open(new Uri(activeAmbiencePath));
                    musicPlayer.Position = TimeSpan.Zero;
                    musicPlayer.Play();
                }
            }
            catch { }
        }

        private void OnTrackEnded(object sender, EventArgs e)
        {
            try
            {
                if (playingMusicAlbum != null && playingMusicTrackIndex + 1 < playingMusicAlbum.Tracks.Count)
                {
                    PlayMusicTrack(playingMusicAlbum, playingMusicTrackIndex + 1);
                    return;
                }
            }
            catch { }
            StopMusicTrack(true);
        }

        private void ResumeMenuAudio()
        {
            try
            {
                if (musicTrackActive)
                {
                    musicTrackPaused = false;
                    trackPlayer.Play();
                }
                else TryStartAudio();
            }
            catch { TryStartAudio(); }
        }

        private void CalculateColumns()
        {
            double width = contentHost.ActualWidth;
            if (width < 600) width = ActualWidth - 360;
            // Game and album cards occupy 237 DIPs including their margins.  Using the actual
            // footprint keeps vertical navigation in the same visible column.
            columns = Math.Max(2, (int)Math.Floor((width - 62) / 237.0));
        }

        private void OnPreviewKeyDown(object sender, KeyEventArgs e)
        {
            if (startupVideoOverlay.IsActive)
            {
                if (e.Key == Key.Enter || e.Key == Key.Escape || e.Key == Key.Back) startupVideoOverlay.Skip();
                e.Handled = true;
                return;
            }
            if (bootActive)
            {
                if (e.Key == Key.Enter || e.Key == Key.Escape || e.Key == Key.Back) EndPlatformBoot();
                e.Handled = true;
                return;
            }
            if (e.Key == Key.Tab || e.Key == Key.Home) { section = 4; selected = 0; navigationMode = false; RenderSection(); e.Handled = true; }
            else if (e.Key == Key.Left) { Move("Left"); e.Handled = true; }
            else if (e.Key == Key.Right) { Move("Right"); e.Handled = true; }
            else if (e.Key == Key.Up) { Move("Up"); e.Handled = true; }
            else if (e.Key == Key.Down) { Move("Down"); e.Handled = true; }
            else if (e.Key == Key.Enter) { Confirm(); e.Handled = true; }
            else if (e.Key == Key.Escape || e.Key == Key.Back) { Back(); e.Handled = true; }
            else if (e.Key == Key.Delete || e.Key == Key.F1) { Options(); e.Handled = true; }
        }

        private void PollInput()
        {
            if (!IsActive || activeProcess != null) return;
            NativeNavigationCommand command = NativeConsoleNavigation.Poll();
            if (command == null || String.IsNullOrWhiteSpace(command.Command)) return;
            if (command.Command == "Menu") { HuymaierConsole.NativeApp.NativeQuickAccessRequest.Request(); try { Close(); } catch { } return; }
            if (startupVideoOverlay.IsActive)
            {
                if (command.Command == "Confirm" || command.Command == "Back" || command.Command == "Menu") startupVideoOverlay.Skip();
                return;
            }
            if (bootActive)
            {
                if (command.Command == "Confirm" || command.Command == "Back" || command.Command == "Menu") EndPlatformBoot();
                return;
            }
            if (command.Command == "Left" || command.Command == "Right" || command.Command == "Up" || command.Command == "Down") Move(command.Command);
            else if (command.Command == "Confirm") Confirm();
            else if (command.Command == "Back") Back();
            else if (command.Command == "Options") Options();
            else if (command.Command == "LeftShoulder") JumpLetter(-1);
            else if (command.Command == "RightShoulder") JumpLetter(1);
        }

        private void Move(string direction)
        {
            if (navigationMode)
            {
                if (direction == "Up") navigationSelected = Math.Max(0, navigationSelected - 1);
                else if (direction == "Down") navigationSelected = Math.Min(navButtons.Count - 1, navigationSelected + 1);
                else if (direction == "Right")
                {
                    if (navigationSelected >= 0 && navigationSelected < navButtons.Count) section = (int)navButtons[navigationSelected].Tag;
                    selected = 0;
                    navigationMode = false;
                    RenderSection();
                    return;
                }
                UpdateVisuals();
                return;
            }
            if (actions.Count == 0) return;
            bool gridSection = section == 0 || (section == 5 && browsedMusicAlbum == null);
            if (gridSection && activeCardPath.Length == 0)
            {
                if (section == 0 && letterMode)
                {
                    if (direction == "Up") letterIndex = (letterIndex + letters.Length - 1) % letters.Length;
                    else if (direction == "Down") letterIndex = (letterIndex + 1) % letters.Length;
                    else if (direction == "Right") letterMode = false;
                    UpdateVisuals();
                    return;
                }
                if (section == 0 && direction == "Left" && selected % columns == 0)
                {
                    letterMode = true;
                    letterIndex = LetterIndexForSelected();
                    UpdateVisuals();
                    return;
                }
                if (direction == "Left") selected = Math.Max(0, selected - 1);
                else if (direction == "Right") selected = Math.Min(actions.Count - 1, selected + 1);
                else if (direction == "Up") MoveGridVertical(-1);
                else if (direction == "Down") MoveGridVertical(1);
            }
            else
            {
                if (direction == "Up") selected = Math.Max(0, selected - 1);
                else if (direction == "Down") selected = Math.Min(actions.Count - 1, selected + 1);
                else if (direction == "Left") selected = Math.Max(0, selected - 1);
                else if (direction == "Right") selected = Math.Min(actions.Count - 1, selected + 1);
            }
            UpdateVisuals();
        }

        private void MoveGridVertical(int direction)
        {
            if (actions.Count == 0 || columns <= 0) return;
            int target = selected + (direction * columns);
            if (direction < 0)
            {
                if (target >= 0) selected = target;
                return;
            }
            if (target < actions.Count)
            {
                selected = target;
                return;
            }
            // Do not clamp to the final card, which causes a diagonal jump.  Move only when
            // the last row actually contains a card in this same visual column.
            int column = selected % columns;
            int lastRowStart = ((actions.Count - 1) / columns) * columns;
            int sameColumn = lastRowStart + column;
            if (sameColumn > selected && sameColumn < actions.Count) selected = sameColumn;
        }

        private void Confirm()
        {
            if (navigationMode)
            {
                if (navigationSelected >= 0 && navigationSelected < navButtons.Count) section = (int)navButtons[navigationSelected].Tag;
                selected = 0;
                letterMode = false;
                navigationMode = false;
                RenderSection();
                return;
            }
            if (letterMode)
            {
                JumpToLetter(letters[letterIndex]);
                letterMode = false;
                UpdateVisuals();
                return;
            }
            if (selected >= 0 && selected < actions.Count && actions[selected].Invoke != null) actions[selected].Invoke();
        }

        private void Back()
        {
            if (letterMode) { letterMode = false; UpdateVisuals(); return; }
            if (subviewOpen)
            {
                subviewOpen = false;
                selected = 0;
                if (section == 0) RenderGames();
                else if (section == 1) RenderMemoryCards();
                else if (section == 2) RenderSaveStates();
                else RenderSettings();
                return;
            }
            if (section == 5 && browsedMusicAlbum != null)
            {
                browsedMusicAlbum = null;
                selected = 0;
                RenderMusicPlayer();
                return;
            }
            if (!String.IsNullOrWhiteSpace(activeCardPath))
            {
                activeCardPath = String.Empty;
                activeSaves.Clear();
                selected = 0;
                RenderMemoryCards();
                return;
            }
            if (section != 4)
            {
                section = 4;
                selected = 0;
                RenderSection();
                return;
            }
            Close();
        }

        private void Options()
        {
            if (section == 4) { section = 3; selected = 0; RenderSection(); return; }
            if (section == 0 && selected >= 0 && selected < games.Count) ShowGameOptions(games[selected]);
            else if (section == 1 && !String.IsNullOrWhiteSpace(activeCardPath) && selected >= 0 && selected < activeSaves.Count) ShowSaveOptions(activeSaves[selected]);
            else if (section == 2 && selected >= 0 && selected < states.Count) ShowStateOptions(states[selected]);
        }

        private void RenderSection()
        {
            activeCardPath = String.Empty;
            selected = 0;
            letterMode = false;
            subviewOpen = false;
            root.Background = BuildBackgroundBrush();
            if (section == 4) RenderHome();
            else if (section == 0) RenderGames();
            else if (section == 1) RenderMemoryCards();
            else if (section == 2) RenderSaveStates();
            else if (section == 5) RenderMusicPlayer();
            else RenderSettings();
            UpdateNavVisuals();
        }

        private void RenderHome()
        {
            contentHost.Children.Clear();
            actions.Clear();
            activeCardPath = String.Empty;
            selected = Math.Max(0, Math.Min(selected, 3));
            if (String.Equals(settings.shellStyle, "Updated", StringComparison.OrdinalIgnoreCase)) RenderUpdatedHome();
            else RenderOriginalHome();
            UpdateVisuals();
        }

        private void RenderOriginalHome()
        {
            Viewbox view = new Viewbox { Stretch = Stretch.Uniform };
            Canvas canvas = new Canvas { Width = 1600, Height = 820 };
            view.Child = canvas;
            contentHost.Children.Add(view);
            AddSphere(canvas, 480, -60, 150); AddSphere(canvas, 600, 8, 116); AddSphere(canvas, 782, 520, 210); AddSphere(canvas, 690, 430, 92);
            TextBlock model = ShadowText("SCPH-1001 - ORIGINAL", 45, FontWeights.Bold);
            Canvas.SetLeft(model, 24); Canvas.SetTop(model, 8); canvas.Children.Add(model);
            Border main = new Border { Width = 320, Height = 72, BorderBrush = new SolidColorBrush(Color.FromRgb(55, 93, 255)), BorderThickness = new Thickness(3), Background = new SolidColorBrush(Color.FromArgb(110, 8, 22, 88)) };
            main.Child = ShadowText("MAIN MENU", 30, FontWeights.Bold);
            Canvas.SetLeft(main, 1245); Canvas.SetTop(main, 14); canvas.Children.Add(main);
            Button memory = CreateSplashButton("MEMORY CARD", 600, 100, delegate { section = 1; selected = 0; RenderSection(); });
            Canvas.SetLeft(memory, 220); Canvas.SetTop(memory, 280); canvas.Children.Add(memory);
            actions.Add(new Ps1UiAction { Button = memory, Invoke = delegate { section = 1; selected = 0; RenderSection(); }, Name = "Memory Card" });
            Button cd = CreateSplashButton("CD PLAYER", 470, 92, delegate { section = 0; selected = 0; RenderSection(); });
            Canvas.SetLeft(cd, 250); Canvas.SetTop(cd, 465); canvas.Children.Add(cd);
            actions.Add(new Ps1UiAction { Button = cd, Invoke = delegate { section = 0; selected = 0; RenderSection(); }, Name = "CD Player" });
            Button music = CreateSplashButton("MUSIC PLAYER", 500, 86, delegate { section = 5; selected = 0; browsedMusicAlbum = null; RenderSection(); });
            Canvas.SetLeft(music, 870); Canvas.SetTop(music, 500); canvas.Children.Add(music);
            actions.Add(new Ps1UiAction { Button = music, Invoke = delegate { section = 5; selected = 0; browsedMusicAlbum = null; RenderSection(); }, Name = "Music Player" });
            Button options = CreateSplashButton("OPTIONS", 330, 70, delegate { section = 3; selected = 0; RenderSection(); });
            Canvas.SetLeft(options, 1110); Canvas.SetTop(options, 690); canvas.Children.Add(options);
            actions.Add(new Ps1UiAction { Button = options, Invoke = delegate { section = 3; selected = 0; RenderSection(); }, Name = "Options" });
        }

        private void RenderUpdatedHome()
        {
            Viewbox view = new Viewbox { Stretch = Stretch.Uniform };
            Canvas canvas = new Canvas { Width = 1600, Height = 820 };
            view.Child = canvas;
            contentHost.Children.Add(view);
            TextBlock model = ShadowText("SCPH-100 - UPDATED", 44, FontWeights.Bold);
            model.Foreground = new SolidColorBrush(Color.FromRgb(245, 245, 245));
            Canvas.SetLeft(model, 28); Canvas.SetTop(model, 10); canvas.Children.Add(model);
            Button memory = CreateUpdatedTab("MEMORY CARD", Color.FromRgb(229, 191, 15), 360, 90, delegate { section = 1; selected = 0; RenderSection(); });
            Canvas.SetLeft(memory, 270); Canvas.SetTop(memory, 125); canvas.Children.Add(memory);
            actions.Add(new Ps1UiAction { Button = memory, Invoke = delegate { section = 1; selected = 0; RenderSection(); }, Name = "Memory Card" });
            Button cd = CreateUpdatedTab("CD PLAYER", Color.FromRgb(185, 30, 16), 360, 90, delegate { section = 0; selected = 0; RenderSection(); });
            Canvas.SetLeft(cd, 970); Canvas.SetTop(cd, 125); canvas.Children.Add(cd);
            actions.Add(new Ps1UiAction { Button = cd, Invoke = delegate { section = 0; selected = 0; RenderSection(); }, Name = "CD Player" });
            Button card = CreateMemoryCardGlyph(delegate { section = 1; selected = 0; RenderSection(); });
            Canvas.SetLeft(card, 325); Canvas.SetTop(card, 325); canvas.Children.Add(card);
            Button disc = CreateDiscGlyph(delegate { section = 0; selected = 0; RenderSection(); });
            Canvas.SetLeft(disc, 1015); Canvas.SetTop(disc, 315); canvas.Children.Add(disc);
            Button music = CreateUpdatedTab("MUSIC PLAYER", Color.FromRgb(31, 139, 85), 360, 78, delegate { section = 5; selected = 0; browsedMusicAlbum = null; RenderSection(); });
            Canvas.SetLeft(music, 620); Canvas.SetTop(music, 590); canvas.Children.Add(music);
            actions.Add(new Ps1UiAction { Button = music, Invoke = delegate { section = 5; selected = 0; browsedMusicAlbum = null; RenderSection(); }, Name = "Music Player" });
            Button options = CreateUpdatedTab("OPTIONS", Color.FromRgb(30, 55, 170), 250, 62, delegate { section = 3; selected = 0; RenderSection(); });
            Canvas.SetLeft(options, 675); Canvas.SetTop(options, 705); canvas.Children.Add(options);
            actions.Add(new Ps1UiAction { Button = options, Invoke = delegate { section = 3; selected = 0; RenderSection(); }, Name = "Options" });
        }

        private static TextBlock ShadowText(string value, double size, FontWeight weight)
        {
            TextBlock text = new TextBlock { Text = value, FontSize = size, FontWeight = weight, Foreground = Brushes.White, TextAlignment = TextAlignment.Center, VerticalAlignment = VerticalAlignment.Center, HorizontalAlignment = HorizontalAlignment.Center };
            text.Effect = new System.Windows.Media.Effects.DropShadowEffect { Color = Colors.Black, BlurRadius = 3, ShadowDepth = 3, Opacity = 0.9 };
            return text;
        }

        private static void AddSphere(Canvas canvas, double left, double top, double size)
        {
            RadialGradientBrush fill = new RadialGradientBrush();
            fill.GradientOrigin = new Point(0.35, 0.28); fill.Center = new Point(0.42, 0.38);
            fill.GradientStops.Add(new GradientStop(Color.FromRgb(102, 116, 255), 0));
            fill.GradientStops.Add(new GradientStop(Color.FromRgb(34, 42, 126), 0.62));
            fill.GradientStops.Add(new GradientStop(Color.FromRgb(5, 8, 38), 1));
            System.Windows.Shapes.Ellipse sphere = new System.Windows.Shapes.Ellipse { Width = size, Height = size, Fill = fill };
            Canvas.SetLeft(sphere, left); Canvas.SetTop(sphere, top); canvas.Children.Add(sphere);
        }

        private Button CreateSplashButton(string label, double width, double height, Action action)
        {
            Button button = new Button { Width = width, Height = height, Background = Brushes.Transparent, BorderBrush = Brushes.Transparent, BorderThickness = new Thickness(3), Padding = new Thickness(0), Cursor = Cursors.Hand, RenderTransformOrigin = new Point(0.5, 0.5) };
            Grid splash = new Grid();
            Color[] colors = new Color[] { Color.FromRgb(20, 204, 255), Color.FromRgb(15, 222, 74), Color.FromRgb(245, 51, 189), Color.FromRgb(255, 215, 25), Color.FromRgb(102, 38, 255) };
            for (int i = 0; i < 15; i++)
            {
                Border fleck = new Border { Width = width / 5.2, Height = height * (0.38 + ((i * 17) % 45) / 100.0), Background = new SolidColorBrush(colors[i % colors.Length]), CornerRadius = new CornerRadius((i % 3) * 5), HorizontalAlignment = HorizontalAlignment.Left, VerticalAlignment = VerticalAlignment.Center, Margin = new Thickness((i * width / 16.5), 0, 0, 0), RenderTransformOrigin = new Point(0.5, 0.5), RenderTransform = new RotateTransform((i % 2 == 0 ? -1 : 1) * (4 + (i % 5) * 3)) };
                splash.Children.Add(fleck);
            }
            splash.Children.Add(ShadowText(label, Math.Max(25, height * 0.42), FontWeights.Bold));
            button.Content = splash;
            button.Click += delegate { action(); };
            return button;
        }

        private Button CreateUpdatedTab(string label, Color color, double width, double height, Action action)
        {
            Button button = new Button { Width = width, Height = height, Background = new SolidColorBrush(color), Foreground = Brushes.White, BorderBrush = new SolidColorBrush(Color.FromRgb(65, 65, 65)), BorderThickness = new Thickness(3), FontSize = height * 0.36, FontWeight = FontWeights.Bold, Content = label, Cursor = Cursors.Hand, RenderTransformOrigin = new Point(0.5, 0.5) };
            button.Click += delegate { action(); };
            return button;
        }

        private Button CreateMemoryCardGlyph(Action action)
        {
            Button button = new Button { Width = 265, Height = 315, Background = Brushes.Transparent, BorderBrush = Brushes.Transparent, BorderThickness = new Thickness(3), Cursor = Cursors.Hand, RenderTransformOrigin = new Point(0.5, 0.5) };
            Grid grid = new Grid();
            Border card = new Border { Width = 180, Height = 240, CornerRadius = new CornerRadius(16), Background = new SolidColorBrush(Color.FromRgb(222, 225, 222)), BorderBrush = new SolidColorBrush(Color.FromRgb(70, 74, 72)), BorderThickness = new Thickness(5), VerticalAlignment = VerticalAlignment.Center };
            Grid details = new Grid();
            details.Children.Add(new Border { Width = 120, Height = 8, Background = new SolidColorBrush(Color.FromRgb(158, 163, 160)), Margin = new Thickness(0, 62, 0, 0), VerticalAlignment = VerticalAlignment.Top });
            details.Children.Add(new Border { Width = 108, Height = 62, Background = new SolidColorBrush(Color.FromRgb(234, 236, 234)), BorderBrush = new SolidColorBrush(Color.FromRgb(174, 179, 176)), BorderThickness = new Thickness(2), Margin = new Thickness(0, 96, 0, 0), VerticalAlignment = VerticalAlignment.Top });
            card.Child = details; grid.Children.Add(card); button.Content = grid; button.Click += delegate { action(); }; return button;
        }

        private Button CreateDiscGlyph(Action action)
        {
            Button button = new Button { Width = 300, Height = 315, Background = Brushes.Transparent, BorderBrush = Brushes.Transparent, BorderThickness = new Thickness(3), Cursor = Cursors.Hand, RenderTransformOrigin = new Point(0.5, 0.5) };
            Grid grid = new Grid();
            RadialGradientBrush fill = new RadialGradientBrush();
            fill.GradientStops.Add(new GradientStop(Color.FromRgb(250, 250, 239), 0)); fill.GradientStops.Add(new GradientStop(Color.FromRgb(211, 213, 201), 0.72)); fill.GradientStops.Add(new GradientStop(Color.FromRgb(120, 120, 115), 1));
            System.Windows.Shapes.Ellipse disc = new System.Windows.Shapes.Ellipse { Width = 230, Height = 230, Fill = fill, Stroke = new SolidColorBrush(Color.FromRgb(55, 57, 55)), StrokeThickness = 5 };
            grid.Children.Add(disc);
            grid.Children.Add(new System.Windows.Shapes.Ellipse { Width = 54, Height = 54, Fill = new SolidColorBrush(Color.FromRgb(180, 182, 175)), Stroke = new SolidColorBrush(Color.FromRgb(70, 72, 70)), StrokeThickness = 4 });
            button.Content = grid; button.Click += delegate { action(); }; return button;
        }

        private Grid CreatePs1PageRoot(string heading, string detail)
        {
            Grid pageRoot = new Grid();
            pageRoot.RowDefinitions.Add(new RowDefinition { Height = new GridLength(92) });
            pageRoot.RowDefinitions.Add(new RowDefinition { Height = new GridLength(1, GridUnitType.Star) });
            StackPanel header = new StackPanel { Margin = new Thickness(20, 4, 20, 8) };
            TextBlock title = ShadowText(heading, 38, FontWeights.Bold); title.HorizontalAlignment = HorizontalAlignment.Left; title.TextAlignment = TextAlignment.Left;
            TextBlock subtitle = ShadowText(detail, 14, FontWeights.SemiBold); subtitle.HorizontalAlignment = HorizontalAlignment.Left; subtitle.TextAlignment = TextAlignment.Left; subtitle.Opacity = 0.86;
            header.Children.Add(title); header.Children.Add(subtitle); pageRoot.Children.Add(header);
            return pageRoot;
        }

        private void RenderGames()
        {
            sectionTitle.Text = "Games";
            sectionSubtitle.Text = scanning ? "Scanning DuckStation game folders…" : games.Count.ToString(CultureInfo.InvariantCulture) + " titles cached  •  LB/RB jumps by letter";
            contentHost.Children.Clear();
            actions.Clear();
            Grid pageRoot = CreatePs1PageRoot("CD PLAYER", scanning ? "Scanning DuckStation game folders…" : games.Count.ToString(CultureInfo.InvariantCulture) + " titles cached  •  LB/RB jumps by letter");
            contentHost.Children.Add(pageRoot);
            Grid grid = new Grid();
            grid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(44) });
            grid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
            Grid.SetRow(grid, 1);
            pageRoot.Children.Add(grid);

            StackPanel rail = new StackPanel { VerticalAlignment = VerticalAlignment.Center };
            for (int i = 0; i < letters.Length; i++)
            {
                TextBlock letter = new TextBlock { Text = letters[i].ToString(), FontSize = 11, Foreground = String.Equals(settings.shellStyle, "Updated", StringComparison.OrdinalIgnoreCase) ? new SolidColorBrush(Color.FromRgb(35, 39, 36)) : Brushes.White, HorizontalAlignment = HorizontalAlignment.Center, Margin = new Thickness(0, 0, 0, 1), Tag = i };
                rail.Children.Add(letter);
            }
            grid.Children.Add(rail);

            ScrollViewer scroll = new ScrollViewer { VerticalScrollBarVisibility = ScrollBarVisibility.Hidden, HorizontalScrollBarVisibility = ScrollBarVisibility.Disabled, PanningMode = PanningMode.VerticalOnly };
            WrapPanel wrap = new WrapPanel { Orientation = Orientation.Horizontal, Margin = new Thickness(18, 0, 0, 10) };
            Grid.SetColumn(scroll, 1);
            scroll.Content = wrap;
            grid.Children.Add(scroll);

            if (games.Count == 0)
            {
                StackPanel empty = new StackPanel { Margin = new Thickness(36, 80, 0, 0) };
                empty.Children.Add(new TextBlock { Text = "No PlayStation games are cached yet.", FontSize = 23, Foreground = String.Equals(settings.shellStyle, "Updated", StringComparison.OrdinalIgnoreCase) ? new SolidColorBrush(Color.FromRgb(35, 39, 36)) : Brushes.White });
                Button scan = CreateListButton("Scan Game Folders", "Read the configured DuckStation library folders now", delegate { RefreshLibrary(false); });
                scan.Width = 420;
                empty.Children.Add(scan);
                wrap.Children.Add(empty);
            }
            else
            {
                for (int index = 0; index < games.Count; index++)
                {
                    Ps1Game game = games[index];
                    Button card = CreateGameCard(game, index);
                    wrap.Children.Add(card);
                    actions.Add(new Ps1UiAction { Button = card, Invoke = delegate { LaunchGame(game); }, Name = game.Name, Letter = GetLetter(game.Name) });
                }
            }
            UpdateVisuals();
        }

        private Button CreateGameCard(Ps1Game game, int index)
        {
            bool updated = String.Equals(settings.shellStyle, "Updated", StringComparison.OrdinalIgnoreCase);
            Button card = new Button { Width = 212, Height = 212, Margin = new Thickness(7, 4, 18, 20), Padding = new Thickness(8, 7, 7, 7), Background = updated ? (Brush)new LinearGradientBrush(Color.FromRgb(230, 231, 228), Color.FromRgb(150, 154, 151), 90) : (Brush)new SolidColorBrush(Color.FromArgb(185, 5, 10, 62)), BorderBrush = new SolidColorBrush(updated ? Color.FromRgb(54, 58, 55) : Color.FromRgb(68, 103, 255)), BorderThickness = new Thickness(3), HorizontalContentAlignment = HorizontalAlignment.Stretch, VerticalContentAlignment = VerticalAlignment.Stretch, RenderTransformOrigin = new Point(0.5, 0.5) };
            card.Template = (ControlTemplate)System.Windows.Markup.XamlReader.Parse("<ControlTemplate xmlns=\"http://schemas.microsoft.com/winfx/2006/xaml/presentation\" TargetType=\"Button\"><Border Background=\"{TemplateBinding Background}\" BorderBrush=\"{TemplateBinding BorderBrush}\" BorderThickness=\"{TemplateBinding BorderThickness}\" CornerRadius=\"3\" ClipToBounds=\"True\"><ContentPresenter Margin=\"{TemplateBinding Padding}\"/></Border></ControlTemplate>");
            Grid cardGrid = new Grid();
            if (!String.IsNullOrWhiteSpace(game.CoverPath) && File.Exists(game.CoverPath))
            {
                BitmapSource sourceImage = Ps1Environment.LoadBitmap(game.CoverPath, 420);
                if (sourceImage != null) cardGrid.Children.Add(new Image { Source = sourceImage, Stretch = Stretch.UniformToFill });
            }
            if (cardGrid.Children.Count == 0)
            {
                LinearGradientBrush bg = new LinearGradientBrush(Color.FromRgb(68, 89, 124), Color.FromRgb(25, 39, 65), 45);
                cardGrid.Background = bg;
                cardGrid.Children.Add(new TextBlock { Text = "PS", FontSize = 70, FontWeight = FontWeights.Bold, Foreground = new SolidColorBrush(Color.FromArgb(125, 255, 255, 255)), HorizontalAlignment = HorizontalAlignment.Center, VerticalAlignment = VerticalAlignment.Center, Margin = new Thickness(0, 0, 0, 24) });
            }
            Border spine = new Border { Width = 13, HorizontalAlignment = HorizontalAlignment.Left, Background = new LinearGradientBrush(Color.FromArgb(145, 235, 239, 241), Color.FromArgb(155, 70, 82, 91), 0) };
            cardGrid.Children.Add(spine);
            Border titleShade = new Border { Height = 52, VerticalAlignment = VerticalAlignment.Bottom, Background = new LinearGradientBrush(Color.FromArgb(0, 0, 0, 0), Color.FromArgb(230, 10, 16, 25), 90) };
            cardGrid.Children.Add(titleShade);
            TextBlock title = new TextBlock { Text = game.Name, FontSize = 12, FontWeight = FontWeights.SemiBold, Foreground = Brushes.White, VerticalAlignment = VerticalAlignment.Bottom, Margin = new Thickness(19, 0, 9, 9), TextTrimming = TextTrimming.CharacterEllipsis };
            cardGrid.Children.Add(title);
            if (game.Discs.Count > 1)
            {
                Border badge = new Border { Background = new SolidColorBrush(Color.FromArgb(210, 20, 29, 55)), CornerRadius = new CornerRadius(7), Padding = new Thickness(7, 3, 7, 3), HorizontalAlignment = HorizontalAlignment.Right, VerticalAlignment = VerticalAlignment.Top, Margin = new Thickness(0, 9, 8, 0) };
                badge.Child = new TextBlock { Text = game.Discs.Count.ToString(CultureInfo.InvariantCulture) + " DISCS", FontSize = 9, FontWeight = FontWeights.Bold, Foreground = Brushes.White };
                cardGrid.Children.Add(badge);
            }
            card.Content = cardGrid;
            card.Click += delegate { selected = index; UpdateVisuals(); LaunchGame(game); };
            return card;
        }

        private void RefreshLibrary(bool firstRun)
        {
            if (scanning) return;
            scanning = true;
            sectionSubtitle.Text = "Scanning DuckStation game folders…";
            ThreadPool.QueueUserWorkItem(delegate
            {
                try
                {
                    List<Ps1Game> scanned = Ps1Environment.ScanGames(settings, WriteLog);
                    SaveLibraryCache(scanned);
                    Dispatcher.BeginInvoke(new Action(delegate
                    {
                        cachedLibraryEntries = scanned ?? new List<Ps1Game>();
                        games = FilterRegularGames(cachedLibraryEntries);
                        musicIndexReady = false;
                        scanning = false;
                        selected = 0;
                        RenderGames();
                        QueueMusicIndexBuild();
                        ShowNotice("PlayStation library refreshed: " + games.Count.ToString(CultureInfo.InvariantCulture) + " titles");
                    }));
                }
                catch (Exception ex)
                {
                    WriteLog("PS1 library scan failed: " + ex, "ERROR");
                    Dispatcher.BeginInvoke(new Action(delegate { scanning = false; ShowNotice("Library scan failed: " + ex.Message); RenderGames(); }));
                }
            });
        }

        private List<Ps1Game> LoadLibraryCacheFast()
        {
            try
            {
                if (File.Exists(libraryCachePath))
                {
                    List<Ps1Game> cached = new JavaScriptSerializer().Deserialize<List<Ps1Game>>(File.ReadAllText(libraryCachePath, Encoding.UTF8));
                    if (cached != null)
                    {
                        bool coversChanged = Ps1Environment.AttachDuckStationCovers(cached, settings, WriteLog);
                        if (coversChanged) SaveLibraryCache(cached);
                        cachedLibraryEntries = cached;
                        return FilterRegularGames(cached);
                    }
                }
            }
            catch (Exception ex) { WriteLog("PS1 library cache load failed: " + ex.Message, "WARN"); }
            return new List<Ps1Game>();
        }

        private List<Ps1Game> FilterRegularGames(List<Ps1Game> source)
        {
            List<Ps1Game> regular = new List<Ps1Game>();
            foreach (Ps1Game game in source ?? new List<Ps1Game>())
            {
                string albumName; int trackNumber;
                if (game != null && !TryParseLegacyTrackName(game.Name, out albumName, out trackNumber)) regular.Add(game);
            }
            return regular.OrderBy(delegate(Ps1Game game) { return game.SortName; }, StringComparer.CurrentCultureIgnoreCase).ToList();
        }

        private void QueueMusicIndexBuild()
        {
            if (musicIndexLoading || musicIndexReady) return;
            musicIndexLoading = true;
            List<Ps1Game> snapshot = (cachedLibraryEntries ?? new List<Ps1Game>()).Where(delegate(Ps1Game game) { return game != null; }).ToList();
            ThreadPool.QueueUserWorkItem(delegate
            {
                List<Ps1MusicAlbum> built = new List<Ps1MusicAlbum>();
                try
                {
                    // PrepareLibrary builds the album index.  Capture its result and only
                    // publish it to the UI thread after all filesystem/CUE work finishes.
                    PrepareLibrary(snapshot);
                    built = musicAlbums == null ? new List<Ps1MusicAlbum>() : musicAlbums.ToList();
                }
                catch (Exception ex) { WriteLog("PS1 music index failed: " + ex, "WARN"); }
                Dispatcher.BeginInvoke(new Action(delegate
                {
                    musicAlbums = built;
                    musicIndexLoading = false;
                    musicIndexReady = true;
                    if (section == 5) RenderMusicPlayer();
                }));
            });
        }

        private List<Ps1Game> PrepareLibrary(List<Ps1Game> source)
        {
            List<Ps1Game> all = source ?? new List<Ps1Game>();
            List<Ps1Game> regular = new List<Ps1Game>();
            List<Ps1Game> legacyTracks = new List<Ps1Game>();
            foreach (Ps1Game game in all)
            {
                string albumName; int trackNumber;
                if (TryParseLegacyTrackName(game == null ? String.Empty : game.Name, out albumName, out trackNumber)) legacyTracks.Add(game);
                else if (game != null) regular.Add(game);
            }

            Dictionary<string, Ps1MusicAlbum> albumMap = new Dictionary<string, Ps1MusicAlbum>(StringComparer.OrdinalIgnoreCase);
            foreach (Ps1Game game in regular)
            {
                int discNumber = 0;
                foreach (string disc in game.Discs ?? new List<string>())
                {
                    discNumber++;
                    if (!String.Equals(Path.GetExtension(disc), ".cue", StringComparison.OrdinalIgnoreCase)) continue;
                    foreach (Ps1MusicTrack track in Ps1Environment.ReadCueAudioTracks(disc, discNumber)) AddMusicTrack(albumMap, game.Name, game.CoverPath, track);
                }
            }

            foreach (Ps1Game trackGame in legacyTracks)
            {
                string albumName; int trackNumber;
                if (!TryParseLegacyTrackName(trackGame.Name, out albumName, out trackNumber)) continue;
                Ps1Game matchingGame = regular.FirstOrDefault(delegate(Ps1Game candidate) { return String.Equals(NormalizeMusicKey(candidate.Name), NormalizeMusicKey(albumName), StringComparison.OrdinalIgnoreCase); });
                Ps1MusicTrack track = new Ps1MusicTrack();
                track.AlbumName = albumName; track.Title = "Track " + trackNumber.ToString("00", CultureInfo.InvariantCulture);
                track.SourcePath = trackGame.PrimaryPath; track.SourceType = Path.GetExtension(trackGame.PrimaryPath).TrimStart('.').ToUpperInvariant();
                track.TrackNumber = trackNumber; track.DiscNumber = 1; track.StartSector = 0; track.EndSector = -1;
                AddMusicTrack(albumMap, albumName, matchingGame == null ? trackGame.CoverPath : matchingGame.CoverPath, track);
            }

            musicAlbums = albumMap.Values.Where(delegate(Ps1MusicAlbum album) { return album.Tracks.Count > 0; }).OrderBy(delegate(Ps1MusicAlbum album) { return album.Name; }, StringComparer.CurrentCultureIgnoreCase).ToList();
            foreach (Ps1MusicAlbum album in musicAlbums)
            {
                album.Tracks = album.Tracks.GroupBy(delegate(Ps1MusicTrack track) { return (track.SourcePath ?? String.Empty).ToLowerInvariant() + "|" + track.StartSector.ToString(CultureInfo.InvariantCulture); }).Select(delegate(IGrouping<string, Ps1MusicTrack> group) { return group.First(); }).OrderBy(delegate(Ps1MusicTrack track) { return track.DiscNumber; }).ThenBy(delegate(Ps1MusicTrack track) { return track.TrackNumber; }).ToList();
            }
            return regular.OrderBy(delegate(Ps1Game game) { return game.SortName; }, StringComparer.CurrentCultureIgnoreCase).ToList();
        }

        private static void AddMusicTrack(Dictionary<string, Ps1MusicAlbum> albums, string albumName, string coverPath, Ps1MusicTrack track)
        {
            if (track == null || String.IsNullOrWhiteSpace(track.SourcePath) || !File.Exists(track.SourcePath)) return;
            string displayName = String.IsNullOrWhiteSpace(albumName) ? "Unknown Album" : albumName.Trim();
            string key = NormalizeMusicKey(displayName);
            Ps1MusicAlbum album;
            if (!albums.TryGetValue(key, out album))
            {
                album = new Ps1MusicAlbum { Name = displayName, CoverPath = coverPath ?? String.Empty };
                albums[key] = album;
            }
            if (String.IsNullOrWhiteSpace(album.CoverPath) && !String.IsNullOrWhiteSpace(coverPath)) album.CoverPath = coverPath;
            track.AlbumName = displayName;
            album.Tracks.Add(track);
        }

        private static bool TryParseLegacyTrackName(string value, out string albumName, out int trackNumber)
        {
            albumName = String.Empty; trackNumber = 0;
            if (String.IsNullOrWhiteSpace(value)) return false;
            Match match = Regex.Match(value.Trim(), @"^(.*?)(?:\s*[\(\[]\s*Track\s*0*(\d+)\s*[\)\]]|\s*-\s*Track\s*0*(\d+))\s*$", RegexOptions.IgnoreCase);
            if (!match.Success) return false;
            albumName = match.Groups[1].Value.Trim().TrimEnd('-', '_');
            string number = match.Groups[2].Success ? match.Groups[2].Value : match.Groups[3].Value;
            return albumName.Length > 0 && Int32.TryParse(number, NumberStyles.Integer, CultureInfo.InvariantCulture, out trackNumber);
        }

        private static string NormalizeMusicKey(string value)
        {
            if (String.IsNullOrWhiteSpace(value)) return String.Empty;
            StringBuilder builder = new StringBuilder();
            foreach (char c in value.ToLowerInvariant()) if (Char.IsLetterOrDigit(c)) builder.Append(c);
            return builder.ToString();
        }

        private void RenderMusicPlayer()
        {
            sectionTitle.Text = "Music Player";
            contentHost.Children.Clear(); actions.Clear(); letterMode = false;
            if (!musicIndexReady)
            {
                QueueMusicIndexBuild();
                Grid loadingRoot = CreatePs1PageRoot("MUSIC PLAYER", musicIndexLoading ? "Indexing CUE audio in the background…" : "Preparing game-disc audio…");
                contentHost.Children.Add(loadingRoot);
                StackPanel loading = new StackPanel { Width = 760, HorizontalAlignment = HorizontalAlignment.Center, VerticalAlignment = VerticalAlignment.Center };
                loading.Children.Add(ShadowText("The PlayStation shell remains responsive while audio tracks are indexed.", 22, FontWeights.SemiBold));
                Button back = CreateListButton("Back to Main Menu", "Music indexing will continue in the background", delegate { section = 4; selected = 0; RenderSection(); });
                loading.Children.Add(back); actions.Add(new Ps1UiAction { Button = back, Invoke = delegate { section = 4; selected = 0; RenderSection(); }, Name = "Back" });
                Grid.SetRow(loading, 1); loadingRoot.Children.Add(loading);
                selected = 0; UpdateVisuals(); return;
            }
            if (browsedMusicAlbum != null) { RenderMusicAlbumTracks(); return; }
            string detail = musicAlbums.Count.ToString(CultureInfo.InvariantCulture) + " game soundtrack album" + (musicAlbums.Count == 1 ? String.Empty : "s") + "  •  artwork from the matching game";
            Grid pageRoot = CreatePs1PageRoot("MUSIC PLAYER", detail); contentHost.Children.Add(pageRoot);
            ScrollViewer scroll = new ScrollViewer { VerticalScrollBarVisibility = ScrollBarVisibility.Hidden, HorizontalScrollBarVisibility = ScrollBarVisibility.Disabled, PanningMode = PanningMode.VerticalOnly };
            WrapPanel wrap = new WrapPanel { Orientation = Orientation.Horizontal, Margin = new Thickness(62, 4, 0, 10) }; scroll.Content = wrap; Grid.SetRow(scroll, 1); pageRoot.Children.Add(scroll);
            if (musicAlbums.Count == 0)
            {
                StackPanel empty = new StackPanel { Margin = new Thickness(34, 70, 0, 0) };
                empty.Children.Add(ShadowText("No CD-audio tracks were found in the cached game discs.", 21, FontWeights.SemiBold));
                Button refresh = CreateListButton("Refresh Library", "Parse configured CUE sheets for AUDIO tracks", delegate { section = 0; RefreshLibrary(false); }); refresh.Width = 440; empty.Children.Add(refresh); wrap.Children.Add(empty);
            }
            else
            {
                for (int i = 0; i < musicAlbums.Count; i++)
                {
                    Ps1MusicAlbum album = musicAlbums[i]; Button card = CreateMusicAlbumCard(album, i); wrap.Children.Add(card);
                    actions.Add(new Ps1UiAction { Button = card, Invoke = delegate { OpenMusicAlbum(album); }, Name = album.Name, Letter = GetLetter(album.Name) });
                }
            }
            selected = Math.Max(0, Math.Min(selected, Math.Max(0, actions.Count - 1))); UpdateVisuals();
        }

        private Button CreateMusicAlbumCard(Ps1MusicAlbum album, int index)
        {
            bool updated = String.Equals(settings.shellStyle, "Updated", StringComparison.OrdinalIgnoreCase);
            Button card = new Button { Width = 212, Height = 212, Margin = new Thickness(7, 4, 18, 20), Padding = new Thickness(8), Background = updated ? (Brush)new LinearGradientBrush(Color.FromRgb(230, 231, 228), Color.FromRgb(150, 154, 151), 90) : (Brush)new SolidColorBrush(Color.FromArgb(185, 5, 10, 62)), BorderBrush = new SolidColorBrush(updated ? Color.FromRgb(54, 58, 55) : Color.FromRgb(68, 103, 255)), BorderThickness = new Thickness(3), HorizontalContentAlignment = HorizontalAlignment.Stretch, VerticalContentAlignment = VerticalAlignment.Stretch, RenderTransformOrigin = new Point(0.5, 0.5) };
            card.Template = (ControlTemplate)System.Windows.Markup.XamlReader.Parse("<ControlTemplate xmlns=\"http://schemas.microsoft.com/winfx/2006/xaml/presentation\" TargetType=\"Button\"><Border Background=\"{TemplateBinding Background}\" BorderBrush=\"{TemplateBinding BorderBrush}\" BorderThickness=\"{TemplateBinding BorderThickness}\" CornerRadius=\"3\" ClipToBounds=\"True\"><ContentPresenter Margin=\"{TemplateBinding Padding}\"/></Border></ControlTemplate>");
            Grid grid = new Grid();
            if (!String.IsNullOrWhiteSpace(album.CoverPath) && File.Exists(album.CoverPath))
            {
                BitmapSource image = Ps1Environment.LoadBitmap(album.CoverPath, 420); if (image != null) grid.Children.Add(new Image { Source = image, Stretch = Stretch.UniformToFill });
            }
            if (grid.Children.Count == 0)
            {
                grid.Background = new LinearGradientBrush(Color.FromRgb(46, 122, 94), Color.FromRgb(11, 37, 52), 45);
                grid.Children.Add(new TextBlock { Text = "♪", FontSize = 84, Foreground = new SolidColorBrush(Color.FromArgb(175, 255, 255, 255)), HorizontalAlignment = HorizontalAlignment.Center, VerticalAlignment = VerticalAlignment.Center, Margin = new Thickness(0, 0, 0, 24) });
            }
            grid.Children.Add(new Border { Height = 58, VerticalAlignment = VerticalAlignment.Bottom, Background = new LinearGradientBrush(Color.FromArgb(0, 0, 0, 0), Color.FromArgb(235, 7, 13, 22), 90) });
            grid.Children.Add(new TextBlock { Text = album.Name, FontSize = 12, FontWeight = FontWeights.SemiBold, Foreground = Brushes.White, VerticalAlignment = VerticalAlignment.Bottom, Margin = new Thickness(10, 0, 9, 22), TextTrimming = TextTrimming.CharacterEllipsis });
            grid.Children.Add(new TextBlock { Text = album.Tracks.Count.ToString(CultureInfo.InvariantCulture) + " TRACKS", FontSize = 9, FontWeight = FontWeights.Bold, Foreground = new SolidColorBrush(Color.FromRgb(174, 232, 201)), VerticalAlignment = VerticalAlignment.Bottom, Margin = new Thickness(10, 0, 9, 8) });
            card.Content = grid; card.Click += delegate { selected = index; OpenMusicAlbum(album); }; return card;
        }

        private void OpenMusicAlbum(Ps1MusicAlbum album)
        {
            browsedMusicAlbum = album; selected = 0; RenderMusicPlayer();
        }

        private void RenderMusicAlbumTracks()
        {
            Ps1MusicAlbum album = browsedMusicAlbum; if (album == null) { RenderMusicPlayer(); return; }
            string nowPlaying = musicTrackActive && playingMusicAlbum == album && playingMusicTrackIndex >= 0 && playingMusicTrackIndex < album.Tracks.Count ? "  •  NOW PLAYING: " + album.Tracks[playingMusicTrackIndex].Title : String.Empty;
            Grid pageRoot = CreatePs1PageRoot(album.Name.ToUpperInvariant(), album.Tracks.Count.ToString(CultureInfo.InvariantCulture) + " CD-audio tracks" + nowPlaying); contentHost.Children.Add(pageRoot);
            Grid body = new Grid { Margin = new Thickness(34, 4, 34, 12) }; body.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(320) }); body.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) }); Grid.SetRow(body, 1); pageRoot.Children.Add(body);
            Border art = new Border { Width = 280, Height = 280, HorizontalAlignment = HorizontalAlignment.Left, VerticalAlignment = VerticalAlignment.Top, Background = new SolidColorBrush(Color.FromArgb(160, 8, 20, 47)), BorderBrush = new SolidColorBrush(Color.FromRgb(83, 120, 239)), BorderThickness = new Thickness(4) };
            if (!String.IsNullOrWhiteSpace(album.CoverPath) && File.Exists(album.CoverPath)) { BitmapSource image = Ps1Environment.LoadBitmap(album.CoverPath, 560); if (image != null) art.Child = new Image { Source = image, Stretch = Stretch.UniformToFill }; }
            if (art.Child == null) art.Child = new TextBlock { Text = "♪", FontSize = 104, Foreground = Brushes.White, HorizontalAlignment = HorizontalAlignment.Center, VerticalAlignment = VerticalAlignment.Center };
            body.Children.Add(art);
            StackPanel list = new StackPanel { Margin = new Thickness(24, 0, 0, 16) }; ScrollViewer scroll = new ScrollViewer { VerticalScrollBarVisibility = ScrollBarVisibility.Hidden, Content = list }; Grid.SetColumn(scroll, 1); body.Children.Add(scroll);
            AddActionButton(list, musicTrackActive && playingMusicAlbum == album ? (musicTrackPaused ? "Resume" : "Pause") : "Play Album", "AUDIO CD controls", delegate { if (musicTrackActive && playingMusicAlbum == album) ToggleMusicPause(); else PlayMusicTrack(album, 0); });
            AddActionButton(list, "Previous Track", "Move to the previous CD track", delegate { ChangeMusicTrack(-1); });
            AddActionButton(list, "Next Track", "Move to the next CD track", delegate { ChangeMusicTrack(1); });
            AddActionButton(list, "Stop", "Stop CD audio and restore menu ambience", delegate { StopMusicTrack(true); RenderMusicPlayer(); });
            for (int i = 0; i < album.Tracks.Count; i++)
            {
                int trackIndex = i; Ps1MusicTrack track = album.Tracks[i];
                string detail = (track.DiscNumber > 1 ? "Disc " + track.DiscNumber.ToString(CultureInfo.InvariantCulture) + "  •  " : String.Empty) + Path.GetFileName(track.SourcePath);
                AddActionButton(list, track.Title, detail, delegate { PlayMusicTrack(album, trackIndex); });
            }
            AddActionButton(list, "Back to Albums", "Return to Music Player", delegate { browsedMusicAlbum = null; selected = 0; RenderMusicPlayer(); });
            selected = Math.Max(0, Math.Min(selected, Math.Max(0, actions.Count - 1))); UpdateVisuals();
        }

        private void PlayMusicTrack(Ps1MusicAlbum album, int index)
        {
            if (album == null || index < 0 || index >= album.Tracks.Count) return;
            Ps1MusicTrack track = album.Tracks[index];
            try
            {
                string playable = Ps1Environment.PrepareAudioTrack(track, Path.Combine(dataHome, "MusicCache"), WriteLog);
                if (String.IsNullOrWhiteSpace(playable) || !File.Exists(playable)) { ShowNotice("This CD track could not be prepared for playback"); return; }
                musicPlayer.Pause(); trackPlayer.Stop(); trackPlayer.Close(); trackPlayer.Volume = Math.Max(0, Math.Min(1, settings.musicVolume)); trackPlayer.Open(new Uri(playable)); trackPlayer.Play();
                playingMusicAlbum = album; playingMusicTrackIndex = index; musicTrackActive = true; musicTrackPaused = false;
                ShowNotice("Playing " + album.Name + " — " + track.Title); if (section == 5 && browsedMusicAlbum != null) RenderMusicPlayer();
            }
            catch (Exception ex) { WriteLog("PS1 music playback failed: " + ex, "ERROR"); ShowNotice("Music playback failed: " + ex.Message); }
        }

        private void ToggleMusicPause()
        {
            if (!musicTrackActive) { if (browsedMusicAlbum != null) PlayMusicTrack(browsedMusicAlbum, 0); return; }
            try { if (musicTrackPaused) trackPlayer.Play(); else trackPlayer.Pause(); musicTrackPaused = !musicTrackPaused; if (section == 5 && browsedMusicAlbum != null) RenderMusicPlayer(); } catch { }
        }

        private void ChangeMusicTrack(int delta)
        {
            Ps1MusicAlbum album = playingMusicAlbum ?? browsedMusicAlbum; if (album == null || album.Tracks.Count == 0) return;
            int index = playingMusicAlbum == album ? playingMusicTrackIndex : 0; index = (index + delta + album.Tracks.Count) % album.Tracks.Count; PlayMusicTrack(album, index);
        }

        private void StopMusicTrack(bool restoreAmbience)
        {
            try { trackPlayer.Stop(); trackPlayer.Close(); } catch { }
            musicTrackActive = false; musicTrackPaused = false; playingMusicAlbum = null; playingMusicTrackIndex = -1;
            if (restoreAmbience) TryStartAudio();
        }

        private void SaveLibraryCache(List<Ps1Game> value)
        {
            try { File.WriteAllText(libraryCachePath, new JavaScriptSerializer().Serialize(value), Encoding.UTF8); }
            catch (Exception ex) { WriteLog("PS1 library cache save failed: " + ex.Message, "WARN"); }
        }

        private void LaunchGame(Ps1Game game)
        {
            if (activeProcess != null) return;
            string executable = settings.duckStationPath;
            if (String.IsNullOrWhiteSpace(executable) || !File.Exists(executable))
            {
                executable = Ps1Environment.FindDuckStationExecutable();
                settings.duckStationPath = executable;
                settings.Save(settingsPath);
            }
            if (String.IsNullOrWhiteSpace(executable) || !File.Exists(executable))
            {
                ShowNotice("Select or install DuckStation in Settings first");
                section = 3;
                selected = 0;
                RenderSection();
                return;
            }
            string disc = game.PrimaryPath;
            if (game.Discs.Count > 1) disc = SelectDisc(game);
            if (String.IsNullOrWhiteSpace(disc)) return;
            try
            {
                musicPlayer.Pause();
                if (musicTrackActive) trackPlayer.Pause();
                ProcessStartInfo info = new ProcessStartInfo();
                info.FileName = executable;
                StringBuilder args = new StringBuilder();
                args.Append("-batch ");
                if (settings.bigPictureEnabled) args.Append("-bigpicture ");
                args.Append("-fullscreen ");
                args.Append(settings.slowBootEnabled ? "-slowboot " : "-fastboot ");
                args.Append("-- \"").Append(disc.Replace("\"", String.Empty)).Append("\"");
                info.Arguments = args.ToString();
                info.WorkingDirectory = Path.GetDirectoryName(executable);
                info.UseShellExecute = true;
                activeProcess = Process.Start(info);
                if (activeProcess == null) throw new InvalidOperationException("Windows did not return a DuckStation process.");
                WriteLog("Launched DuckStation: " + info.FileName + " " + info.Arguments, "INFO");
                ThreadPool.QueueUserWorkItem(delegate
                {
                    int exitCode = 0;
                    try { activeProcess.WaitForExit(); exitCode = activeProcess.ExitCode; } catch { }
                    Dispatcher.BeginInvoke(new Action(delegate
                    {
                        activeProcess = null;
                        section = 4;
                        selected = 0;
                        activeCardPath = String.Empty;
                        WindowState = WindowState.Maximized;
                        RenderSection();
                        NativeWindowActivation.Restore(this);
                        ResumeMenuAudio();
                        if (exitCode != 0) ShowNotice("DuckStation exited with code " + exitCode.ToString(CultureInfo.InvariantCulture));
                    }));
                });
            }
            catch (Exception ex)
            {
                activeProcess = null;
                ResumeMenuAudio();
                WriteLog("DuckStation launch failed: " + ex, "ERROR");
                ShowNotice("DuckStation launch failed: " + ex.Message);
            }
        }

        private string SelectDisc(Ps1Game game)
        {
            if (game.Discs.Count <= 1) return game.PrimaryPath;
            Window dialog = new Window { Title = "Select Disc", Width = 540, Height = Math.Min(560, 170 + game.Discs.Count * 72), WindowStartupLocation = WindowStartupLocation.CenterOwner, Owner = this, WindowStyle = WindowStyle.None, ResizeMode = ResizeMode.NoResize, Background = new SolidColorBrush(Color.FromRgb(10, 13, 22)), Foreground = Brushes.White, ShowInTaskbar = false };
            StackPanel panel = new StackPanel { Margin = new Thickness(24) };
            panel.Children.Add(new TextBlock { Text = game.Name, FontSize = 24, FontWeight = FontWeights.SemiBold, Margin = new Thickness(0, 0, 0, 16) });
            string selectedDisc = String.Empty;
            for (int i = 0; i < game.Discs.Count; i++)
            {
                string path = game.Discs[i];
                Button button = CreateListButton("Disc " + (i + 1).ToString(CultureInfo.InvariantCulture), Path.GetFileName(path), delegate { selectedDisc = path; dialog.DialogResult = true; });
                panel.Children.Add(button);
            }
            dialog.Content = panel;
            dialog.ShowDialog();
            return selectedDisc;
        }

        private void ShowGameOptions(Ps1Game game)
        {
            subviewOpen = true;
            List<Ps1UiAction> optionActions = new List<Ps1UiAction>();
            contentHost.Children.Clear();
            actions.Clear();
            sectionTitle.Text = game.Name;
            sectionSubtitle.Text = game.Serial + (game.Discs.Count > 1 ? "  •  " + game.Discs.Count.ToString(CultureInfo.InvariantCulture) + " discs" : String.Empty);
            StackPanel panel = new StackPanel { Width = 620, HorizontalAlignment = HorizontalAlignment.Left };
            contentHost.Children.Add(panel);
            AddActionButton(panel, "Play", "Launch in DuckStation Big Picture", delegate { LaunchGame(game); });
            AddActionButton(panel, "Open Game Folder", Path.GetDirectoryName(game.PrimaryPath), delegate { Process.Start("explorer.exe", "/select,\"" + game.PrimaryPath + "\""); });
            AddActionButton(panel, "Refresh Library", "Rescan configured PlayStation game folders", delegate { section = 0; RefreshLibrary(false); });
            AddActionButton(panel, "Back to Games", "Return to the collection", delegate { section = 0; selected = 0; RenderGames(); });
            selected = 0;
            UpdateVisuals();
        }

        private void RenderMemoryCards()
        {
            contentHost.Children.Clear();
            actions.Clear();
            if (!String.IsNullOrWhiteSpace(activeCardPath)) { RenderCardContents(); return; }
            List<string> cards = Ps1Environment.FindMemoryCards(settings.dataRoot);
            Grid pageRoot = CreatePs1PageRoot("MEMORY CARD", "Select a card, copy the full card, or create a new card");
            contentHost.Children.Add(pageRoot);
            Grid body = new Grid { Margin = new Thickness(20, 0, 20, 12) };
            body.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
            body.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(330) });
            body.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
            Grid.SetRow(body, 1); pageRoot.Children.Add(body);
            string card1 = cards.Count > 0 ? cards[0] : String.Empty;
            string card2 = cards.Count > 1 ? cards[1] : String.Empty;
            Border slot1 = BuildCardSlot("CARD 1", card1, 1); body.Children.Add(slot1);
            Border slot2 = BuildCardSlot("CARD 2", card2, 2); Grid.SetColumn(slot2, 2); body.Children.Add(slot2);
            StackPanel commands = new StackPanel { VerticalAlignment = VerticalAlignment.Center, Margin = new Thickness(24, 0, 24, 0) };
            Grid.SetColumn(commands, 1); body.Children.Add(commands);
            AddMemoryCommand(commands, "EXIT", delegate { section = 4; selected = 0; RenderSection(); });
            AddMemoryCommand(commands, "COPY ALL", delegate { CopyWholeMemoryCard(card1, card2); });
            AddMemoryCommand(commands, "BACKUP", delegate { BackupMemoryCards(cards); });
            AddMemoryCommand(commands, "NEW CARD", CreateMemoryCard);
            selected = Math.Max(0, Math.Min(selected, actions.Count - 1));
            UpdateVisuals();
        }

        private Border BuildCardSlot(string label, string path, int slot)
        {
            Border panel = new Border { Margin = new Thickness(10), Padding = new Thickness(18), BorderThickness = new Thickness(3), BorderBrush = new SolidColorBrush(String.Equals(settings.shellStyle, "Updated", StringComparison.OrdinalIgnoreCase) ? Color.FromRgb(45, 45, 45) : Color.FromRgb(38, 77, 255)), Background = new SolidColorBrush(String.Equals(settings.shellStyle, "Updated", StringComparison.OrdinalIgnoreCase) ? Color.FromArgb(225, 15, 15, 15) : Color.FromArgb(105, 0, 0, 28)) };
            Grid grid = new Grid(); grid.RowDefinitions.Add(new RowDefinition { Height = new GridLength(72) }); grid.RowDefinitions.Add(new RowDefinition { Height = new GridLength(1, GridUnitType.Star) });
            Button open = String.Equals(settings.shellStyle, "Updated", StringComparison.OrdinalIgnoreCase) ? CreateUpdatedTab(label, slot == 1 ? Color.FromRgb(0, 142, 45) : Color.FromRgb(226, 207, 0), 330, 62, delegate { OpenCardSlot(path); }) : CreateSplashButton(label, 330, 70, delegate { OpenCardSlot(path); });
            open.HorizontalAlignment = HorizontalAlignment.Center; grid.Children.Add(open);
            actions.Add(new Ps1UiAction { Button = open, Invoke = delegate { OpenCardSlot(path); }, Name = label });
            UniformGrid savesGrid = new UniformGrid { Columns = 3, Rows = 5, Margin = new Thickness(16, 8, 16, 8) }; Grid.SetRow(savesGrid, 1); grid.Children.Add(savesGrid);
            List<Ps1SaveEntry> saves = String.IsNullOrWhiteSpace(path) ? new List<Ps1SaveEntry>() : Ps1MemoryCard.ReadSaves(path);
            for (int i = 0; i < 15; i++)
            {
                Border cell = new Border { Margin = new Thickness(5), Background = new SolidColorBrush(Color.FromArgb(170, 8, 10, 15)), BorderBrush = new SolidColorBrush(Color.FromArgb(95, 255, 255, 255)), BorderThickness = new Thickness(1) };
                if (i < saves.Count && saves[i].Icon != null) cell.Child = new Image { Source = saves[i].Icon, Stretch = Stretch.Uniform, Margin = new Thickness(6), SnapsToDevicePixels = true };
                savesGrid.Children.Add(cell);
            }
            panel.Child = grid; return panel;
        }

        private void OpenCardSlot(string path)
        {
            if (String.IsNullOrWhiteSpace(path)) { CreateMemoryCard(); return; }
            activeCardPath = path; activeSaves = Ps1MemoryCard.ReadSaves(path); selected = 0; RenderMemoryCards();
        }

        private void AddMemoryCommand(Panel panel, string label, Action action)
        {
            Button button = String.Equals(settings.shellStyle, "Updated", StringComparison.OrdinalIgnoreCase) ? CreateUpdatedTab(label, label == "EXIT" ? Color.FromRgb(31, 61, 181) : Color.FromRgb(184, 184, 184), 285, 66, action) : CreateSplashButton(label, 285, 70, action);
            button.Margin = new Thickness(0, 8, 0, 8); panel.Children.Add(button); actions.Add(new Ps1UiAction { Button = button, Invoke = action, Name = label });
        }

        private void CopyWholeMemoryCard(string source, string target)
        {
            try
            {
                if (String.IsNullOrWhiteSpace(source) || !File.Exists(source)) { ShowNotice("Card 1 is not available"); return; }
                if (String.IsNullOrWhiteSpace(target)) { ShowNotice("Create Card 2 first"); return; }
                string backup = Path.Combine(dataHome, "Backups", Path.GetFileNameWithoutExtension(target) + "-before-copy-" + DateTime.Now.ToString("yyyyMMdd-HHmmss") + Path.GetExtension(target));
                Directory.CreateDirectory(Path.GetDirectoryName(backup)); if (File.Exists(target)) File.Copy(target, backup, true); File.Copy(source, target, true); ShowNotice("Card 1 copied to Card 2"); RenderMemoryCards();
            }
            catch (Exception ex) { ShowNotice("Copy All failed: " + ex.Message); }
        }

        private void BackupMemoryCards(List<string> cards)
        {
            try
            {
                string folder = Path.Combine(dataHome, "Backups", "Memory Cards", DateTime.Now.ToString("yyyyMMdd-HHmmss")); Directory.CreateDirectory(folder);
                int count = 0; foreach (string card in cards) if (File.Exists(card)) { File.Copy(card, Path.Combine(folder, Path.GetFileName(card)), true); count++; }
                ShowNotice("Backed up " + count.ToString(CultureInfo.InvariantCulture) + " memory card(s)");
            }
            catch (Exception ex) { ShowNotice("Memory-card backup failed: " + ex.Message); }
        }

        private void RenderCardContents()
        {
            Grid pageRoot = CreatePs1PageRoot("MEMORY CARD", Path.GetFileNameWithoutExtension(activeCardPath) + "  •  " + activeSaves.Count.ToString(CultureInfo.InvariantCulture) + " saves");
            contentHost.Children.Add(pageRoot);
            Grid body = new Grid { Margin = new Thickness(36, 0, 36, 20) }; body.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) }); body.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(340) }); Grid.SetRow(body, 1); pageRoot.Children.Add(body);
            UniformGrid slots = new UniformGrid { Columns = 3, Rows = 5, Margin = new Thickness(20) }; body.Children.Add(slots);
            for (int i = 0; i < 15; i++)
            {
                if (i < activeSaves.Count)
                {
                    Ps1SaveEntry save = activeSaves[i]; Button tile = new Button { Margin = new Thickness(7), Padding = new Thickness(5), Background = new SolidColorBrush(Color.FromArgb(195, 12, 14, 20)), BorderBrush = new SolidColorBrush(Color.FromArgb(85, 255, 255, 255)), BorderThickness = new Thickness(2), RenderTransformOrigin = new Point(0.5, 0.5) };
                    Grid g = new Grid(); if (save.Icon != null) g.Children.Add(new Image { Source = save.Icon, Stretch = Stretch.Uniform, Margin = new Thickness(8) }); g.Children.Add(new TextBlock { Text = String.IsNullOrWhiteSpace(save.Title) ? save.FileName : save.Title, Foreground = Brushes.White, FontSize = 10, TextAlignment = TextAlignment.Center, VerticalAlignment = VerticalAlignment.Bottom, TextWrapping = TextWrapping.Wrap, MaxHeight = 32, Background = new SolidColorBrush(Color.FromArgb(165, 0, 0, 0)) }); tile.Content = g; tile.Click += delegate { ShowSaveOptions(save); }; slots.Children.Add(tile); actions.Add(new Ps1UiAction { Button = tile, Invoke = delegate { ShowSaveOptions(save); }, Name = save.Title });
                }
                else slots.Children.Add(new Border { Margin = new Thickness(7), Background = new SolidColorBrush(Color.FromArgb(140, 5, 7, 12)), BorderBrush = new SolidColorBrush(Color.FromArgb(45, 255, 255, 255)), BorderThickness = new Thickness(1) });
            }
            StackPanel commands = new StackPanel { VerticalAlignment = VerticalAlignment.Center, Margin = new Thickness(24) }; Grid.SetColumn(commands, 1); body.Children.Add(commands);
            AddMemoryCommand(commands, "COPY", delegate { if (selected >= 0 && selected < activeSaves.Count) CopySave(activeSaves[selected]); else ShowNotice("Select a save first"); });
            AddMemoryCommand(commands, "DELETE", delegate { if (selected >= 0 && selected < activeSaves.Count) DeleteSave(activeSaves[selected]); else ShowNotice("Select a save first"); });
            AddMemoryCommand(commands, "CARD OPTIONS", ShowCardOptions);
            AddMemoryCommand(commands, "EXIT", delegate { activeCardPath = String.Empty; activeSaves.Clear(); selected = 0; RenderMemoryCards(); });
            selected = Math.Max(0, Math.Min(selected, actions.Count - 1)); UpdateVisuals();
        }

        private void ShowSaveOptions(Ps1SaveEntry save)
        {
            subviewOpen = true;
            contentHost.Children.Clear();
            actions.Clear();
            sectionTitle.Text = String.IsNullOrWhiteSpace(save.Title) ? save.FileName : save.Title;
            sectionSubtitle.Text = save.Blocks.ToString(CultureInfo.InvariantCulture) + " block(s)  •  " + save.FileName;
            StackPanel panel = new StackPanel { Width = 650, HorizontalAlignment = HorizontalAlignment.Left };
            contentHost.Children.Add(panel);
            AddActionButton(panel, "Export Save", "Write an MCS-style save package to Huymaier Console exports", delegate { ExportSave(save); });
            AddActionButton(panel, "Copy to Another Card", "Copy this save and its block chain to another PS1 memory card", delegate { CopySave(save); });
            AddActionButton(panel, "Delete (Recoverable)", "Back up the full card, then mark this save deleted", delegate { DeleteSave(save); });
            AddActionButton(panel, "Back to Card", "Return without changing the save", delegate { activeSaves = Ps1MemoryCard.ReadSaves(activeCardPath); selected = 0; RenderMemoryCards(); });
            selected = 0;
            UpdateVisuals();
        }

        private void ShowCardOptions()
        {
            subviewOpen = true;
            contentHost.Children.Clear();
            actions.Clear();
            sectionTitle.Text = Path.GetFileNameWithoutExtension(activeCardPath);
            sectionSubtitle.Text = activeCardPath;
            StackPanel panel = new StackPanel { Width = 650, HorizontalAlignment = HorizontalAlignment.Left };
            contentHost.Children.Add(panel);
            AddActionButton(panel, "Backup Card", "Create a timestamped safety copy", delegate { BackupCard(activeCardPath); });
            AddActionButton(panel, "Duplicate Card", "Create a second card beside the original", delegate { DuplicateCard(activeCardPath); });
            AddActionButton(panel, "Open Card Folder", Path.GetDirectoryName(activeCardPath), delegate { Process.Start("explorer.exe", "/select,\"" + activeCardPath + "\""); });
            AddActionButton(panel, "Back to Saves", "Return to the save grid", delegate { activeSaves = Ps1MemoryCard.ReadSaves(activeCardPath); selected = 0; RenderMemoryCards(); });
            selected = 0;
            UpdateVisuals();
        }

        private void BackupCard(string cardPath)
        {
            try
            {
                string destination = Path.Combine(dataHome, "Backups", Path.GetFileNameWithoutExtension(cardPath) + "-" + DateTime.Now.ToString("yyyyMMdd-HHmmss") + Path.GetExtension(cardPath));
                File.Copy(cardPath, destination, true);
                ShowNotice("Memory card backed up");
            }
            catch (Exception ex) { ShowNotice("Backup failed: " + ex.Message); }
        }

        private void DuplicateCard(string cardPath)
        {
            try
            {
                string directory = Path.GetDirectoryName(cardPath);
                string destination = Path.Combine(directory, Path.GetFileNameWithoutExtension(cardPath) + " Copy" + Path.GetExtension(cardPath));
                int suffix = 2;
                while (File.Exists(destination)) { destination = Path.Combine(directory, Path.GetFileNameWithoutExtension(cardPath) + " Copy " + suffix.ToString(CultureInfo.InvariantCulture) + Path.GetExtension(cardPath)); suffix++; }
                File.Copy(cardPath, destination);
                ShowNotice("Memory card duplicated");
                activeCardPath = String.Empty;
                RenderMemoryCards();
            }
            catch (Exception ex) { ShowNotice("Duplicate failed: " + ex.Message); }
        }

        private void CreateMemoryCard()
        {
            try
            {
                string rootPath = Ps1Environment.GetMemoryCardRoot(settings.dataRoot);
                Directory.CreateDirectory(rootPath);
                string path = Path.Combine(rootPath, "Huymaier Card.mcd");
                int suffix = 2;
                while (File.Exists(path)) { path = Path.Combine(rootPath, "Huymaier Card " + suffix.ToString(CultureInfo.InvariantCulture) + ".mcd"); suffix++; }
                Ps1MemoryCard.CreateFormatted(path);
                ShowNotice("PS1 memory card created");
                RenderMemoryCards();
            }
            catch (Exception ex) { ShowNotice("Card creation failed: " + ex.Message); }
        }

        private void ExportSave(Ps1SaveEntry save)
        {
            try
            {
                string name = Ps1Environment.SafeName(String.IsNullOrWhiteSpace(save.Title) ? save.FileName : save.Title);
                string path = Path.Combine(dataHome, "Exports", name + "-" + DateTime.Now.ToString("yyyyMMdd-HHmmss") + ".mcs");
                Ps1MemoryCard.ExportSave(activeCardPath, save, path);
                ShowNotice("Save exported to " + Path.GetFileName(path));
            }
            catch (Exception ex) { ShowNotice("Export failed: " + ex.Message); }
        }

        private void CopySave(Ps1SaveEntry save)
        {
            try
            {
                List<string> cards = Ps1Environment.FindMemoryCards(settings.dataRoot).Where(p => !String.Equals(p, activeCardPath, StringComparison.OrdinalIgnoreCase)).ToList();
                if (cards.Count == 0) { ShowNotice("No second PS1 memory card is available"); return; }
                string target = cards[0];
                Ps1MemoryCard.CopySave(activeCardPath, save, target, Path.Combine(dataHome, "Backups"));
                ShowNotice("Save copied to " + Path.GetFileNameWithoutExtension(target));
            }
            catch (Exception ex) { ShowNotice("Copy failed: " + ex.Message); }
        }

        private void DeleteSave(Ps1SaveEntry save)
        {
            try
            {
                Ps1MemoryCard.DeleteSave(activeCardPath, save, Path.Combine(dataHome, "Backups"));
                activeSaves = Ps1MemoryCard.ReadSaves(activeCardPath);
                selected = 0;
                RenderMemoryCards();
                ShowNotice("Save moved to recoverable deleted state");
            }
            catch (Exception ex) { ShowNotice("Delete failed: " + ex.Message); }
        }

        private void RenderSaveStates()
        {
            subviewOpen = false;
            sectionTitle.Text = "Save States";
            states = Ps1Environment.FindSaveStates(settings.dataRoot);
            sectionSubtitle.Text = states.Count.ToString(CultureInfo.InvariantCulture) + " cached state(s)  •  state files remain in DuckStation's data folder";
            contentHost.Children.Clear();
            actions.Clear();
            Grid pageRoot = CreatePs1PageRoot("SAVE STATES", states.Count.ToString(CultureInfo.InvariantCulture) + " cached state(s)  •  DuckStation snapshots");
            contentHost.Children.Add(pageRoot);
            ScrollViewer scroll = new ScrollViewer { VerticalScrollBarVisibility = ScrollBarVisibility.Hidden };
            StackPanel panel = new StackPanel { MaxWidth = 1180, HorizontalAlignment = HorizontalAlignment.Stretch, Margin = new Thickness(42, 0, 42, 22) };
            scroll.Content = panel;
            Grid.SetRow(scroll, 1);
            pageRoot.Children.Add(scroll);
            if (states.Count == 0)
            {
                panel.Children.Add(new TextBlock { Text = "No DuckStation save states were found.", FontSize = 21, Foreground = Brushes.White, Margin = new Thickness(0, 28, 0, 18) });
                AddActionButton(panel, "Open DuckStation Big Picture", "Create or manage save states in DuckStation", delegate { OpenDuckStationBigPicture(); });
            }
            else
            {
                for (int index = 0; index < states.Count; index++)
                {
                    Ps1StateEntry state = states[index];
                    string detail = state.Modified.ToString("g", CultureInfo.CurrentCulture) + "  •  " + Ps1Environment.FormatBytes(state.Size);
                    Button button = CreateListButton(state.GameName, detail, delegate { LaunchState(state); });
                    panel.Children.Add(button);
                    actions.Add(new Ps1UiAction { Button = button, Invoke = delegate { LaunchState(state); }, Name = state.Name });
                }
            }
            selected = Math.Max(0, Math.Min(selected, actions.Count - 1));
            UpdateVisuals();
        }

        private void LaunchState(Ps1StateEntry state)
        {
            if (state == null || !File.Exists(state.Path)) { ShowNotice("Save state file is missing"); return; }
            string executable = settings.duckStationPath;
            if (String.IsNullOrWhiteSpace(executable) || !File.Exists(executable)) executable = Ps1Environment.FindDuckStationExecutable();
            if (String.IsNullOrWhiteSpace(executable) || !File.Exists(executable)) { ShowNotice("Select or install DuckStation in Settings first"); return; }
            try
            {
                musicPlayer.Pause();
                ProcessStartInfo info = new ProcessStartInfo();
                info.FileName = executable;
                info.Arguments = "-batch -bigpicture -fullscreen -statefile \"" + state.Path.Replace("\"", String.Empty) + "\"";
                info.WorkingDirectory = Path.GetDirectoryName(executable);
                info.UseShellExecute = true;
                activeProcess = Process.Start(info);
                if (activeProcess == null) throw new InvalidOperationException("Windows did not return a DuckStation process.");
                ThreadPool.QueueUserWorkItem(delegate
                {
                    try { activeProcess.WaitForExit(); } catch { }
                    Dispatcher.BeginInvoke(new Action(delegate
                    {
                        activeProcess = null;
                        section = 4;
                        selected = 0;
                        WindowState = WindowState.Maximized;
                        RenderSection();
                        NativeWindowActivation.Restore(this);
                        TryStartAudio();
                    }));
                });
            }
            catch (Exception ex) { activeProcess = null; TryStartAudio(); ShowNotice("Save state could not be loaded: " + ex.Message); }
        }

        private void ShowStateOptions(Ps1StateEntry state)
        {
            if (state == null) return;
            subviewOpen = true;
            contentHost.Children.Clear();
            actions.Clear();
            sectionTitle.Text = state.GameName;
            sectionSubtitle.Text = state.Path;
            StackPanel panel = new StackPanel { Width = 700, HorizontalAlignment = HorizontalAlignment.Left };
            contentHost.Children.Add(panel);
            AddActionButton(panel, "Load State", "Resume this state in DuckStation Big Picture", delegate { LaunchState(state); });
            AddActionButton(panel, "Export State", "Copy the state into Huymaier Console exports", delegate { ExportState(state); });
            AddActionButton(panel, "Delete (Recoverable)", "Move the state into Huymaier Console backups", delegate { DeleteState(state); });
            AddActionButton(panel, "Back to Save States", "Return without changing this state", delegate { subviewOpen = false; selected = 0; RenderSaveStates(); });
            selected = 0;
            UpdateVisuals();
        }

        private void ExportState(Ps1StateEntry state)
        {
            try
            {
                string rootPath = Path.Combine(dataHome, "Exports", "Save States");
                Directory.CreateDirectory(rootPath);
                string destination = Path.Combine(rootPath, Path.GetFileName(state.Path));
                if (File.Exists(destination)) destination = Path.Combine(rootPath, Path.GetFileNameWithoutExtension(state.Path) + "-" + DateTime.Now.ToString("yyyyMMdd-HHmmss") + Path.GetExtension(state.Path));
                File.Copy(state.Path, destination, true);
                ShowNotice("Save state exported");
            }
            catch (Exception ex) { ShowNotice("State export failed: " + ex.Message); }
        }

        private void DeleteState(Ps1StateEntry state)
        {
            try
            {
                string rootPath = Path.Combine(dataHome, "Backups", "Save States");
                Directory.CreateDirectory(rootPath);
                string destination = Path.Combine(rootPath, Path.GetFileNameWithoutExtension(state.Path) + "-" + DateTime.Now.ToString("yyyyMMdd-HHmmss") + Path.GetExtension(state.Path));
                File.Move(state.Path, destination);
                subviewOpen = false;
                selected = 0;
                RenderSaveStates();
                ShowNotice("Save state moved to recoverable backup");
            }
            catch (Exception ex) { ShowNotice("State delete failed: " + ex.Message); }
        }

        private void RenderSettings()
        {
            sectionTitle.Text = "Options";
            sectionSubtitle.Text = "DuckStation, BIOS, game folders and PlayStation Browser audio";
            contentHost.Children.Clear();
            actions.Clear();
            ScrollViewer scroll = new ScrollViewer { VerticalScrollBarVisibility = ScrollBarVisibility.Hidden };
            StackPanel panel = new StackPanel { MaxWidth = 1280, HorizontalAlignment = HorizontalAlignment.Stretch, Margin = new Thickness(42, 8, 42, 24) };
            scroll.Content = panel;
            contentHost.Children.Add(scroll);
            TextBlock optionsHeading = ShadowText("OPTIONS", 42, FontWeights.Bold); optionsHeading.HorizontalAlignment = HorizontalAlignment.Left; panel.Children.Add(optionsHeading);
            string executableStatus = File.Exists(settings.duckStationPath) ? settings.duckStationPath : "Not detected";
            AddActionButton(panel, "Interface Style", settings.shellStyle, CycleShellStyle);
            string biosStatus = Ps1Environment.GetBiosStatus(settings.dataRoot);
            AddActionButton(panel, "DuckStation", executableStatus, delegate { ChooseDuckStation(); });
            AddActionButton(panel, "DuckStation Data", String.IsNullOrWhiteSpace(settings.dataRoot) ? "Not detected" : settings.dataRoot, delegate { ChooseDataRoot(); });
            AddActionButton(panel, "Install Managed DuckStation", "Install the official portable Windows build to an external folder", delegate { InstallManagedDuckStation(); });
            AddActionButton(panel, "BIOS", biosStatus, delegate { ImportBiosImage(); });
            AddActionButton(panel, "Open BIOS Folder", "Open DuckStation's BIOS directory", delegate { OpenBiosFolder(); });
            AddActionButton(panel, "Add Game Folder", settings.gameFolders.Count.ToString(CultureInfo.InvariantCulture) + " Huymaier folder(s) configured; DuckStation paths are also detected", delegate { AddGameFolder(); });
            for (int folderIndex = 0; folderIndex < settings.gameFolders.Count; folderIndex++)
            {
                string configuredFolder = settings.gameFolders[folderIndex];
                AddActionButton(panel, "Remove Game Folder", configuredFolder, delegate { settings.gameFolders.RemoveAll(p => String.Equals(p, configuredFolder, StringComparison.OrdinalIgnoreCase)); settings.Save(settingsPath); RenderSettings(); });
            }
            AddActionButton(panel, "Refresh Library", "Rescan only when requested; cached covers are reused otherwise", delegate { section = 0; RefreshLibrary(false); });
            AddActionButton(panel, "Big Picture Launch", settings.bigPictureEnabled ? "Enabled" : "Disabled", delegate { settings.bigPictureEnabled = !settings.bigPictureEnabled; SaveSettingsAndRender(); });
            AddActionButton(panel, "Original Startup Video", settings.platformBootEnabled ? "Enabled" : "Disabled", delegate { settings.platformBootEnabled = !settings.platformBootEnabled; SaveSettingsAndRender(); });
            AddActionButton(panel, "Game Boot", settings.slowBootEnabled ? "Original BIOS sequence" : "Fast boot", delegate { settings.slowBootEnabled = !settings.slowBootEnabled; SaveSettingsAndRender(); });
            AddActionButton(panel, "Import Menu Ambience", String.IsNullOrWhiteSpace(settings.ambienceAudioPath) ? "Not configured" : Path.GetFileName(settings.ambienceAudioPath), delegate { ImportAudio(false); });
            AddActionButton(panel, "Music Volume", Math.Round(settings.musicVolume * 100).ToString(CultureInfo.InvariantCulture) + "%", delegate { settings.musicVolume += 0.1; if (settings.musicVolume > 1.001) settings.musicVolume = 0; SaveSettingsAndRender(); TryStartAudio(); });
            AddActionButton(panel, "Open DuckStation Big Picture", "Open the emulator TV interface without starting a game", delegate { OpenDuckStationBigPicture(); });
            selected = Math.Max(0, Math.Min(selected, actions.Count - 1));
            UpdateVisuals();
        }

        private Button CreateListButton(string name, string detail, Action action)
        {
            bool updated = String.Equals(settings.shellStyle, "Updated", StringComparison.OrdinalIgnoreCase);
            Button button = new Button { MinHeight = 74, Margin = new Thickness(14, 0, 14, 11), Padding = new Thickness(24, 11, 24, 11), Background = updated ? (Brush)new LinearGradientBrush(Color.FromRgb(228, 229, 226), Color.FromRgb(168, 171, 168), 90) : (Brush)new SolidColorBrush(Color.FromArgb(155, 6, 12, 67)), BorderBrush = new SolidColorBrush(updated ? Color.FromRgb(65, 67, 65) : Color.FromRgb(58, 91, 250)), BorderThickness = new Thickness(2), HorizontalContentAlignment = HorizontalAlignment.Stretch, RenderTransformOrigin = new Point(0.5, 0.5) };
            Grid grid = new Grid();
            grid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(330) });
            grid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
            TextBlock title = new TextBlock { Text = name, FontSize = 18, FontWeight = FontWeights.Bold, Foreground = updated ? new SolidColorBrush(Color.FromRgb(35, 38, 36)) : Brushes.White, VerticalAlignment = VerticalAlignment.Center, Margin = new Thickness(4, 0, 22, 0) };
            TextBlock subtitle = new TextBlock { Text = detail ?? String.Empty, FontSize = 13, Foreground = updated ? new SolidColorBrush(Color.FromRgb(64, 68, 65)) : new SolidColorBrush(Color.FromRgb(208, 218, 255)), VerticalAlignment = VerticalAlignment.Center, TextTrimming = TextTrimming.CharacterEllipsis, TextWrapping = TextWrapping.NoWrap, Margin = new Thickness(12, 0, 8, 0) };
            Grid.SetColumn(subtitle, 1); grid.Children.Add(title); grid.Children.Add(subtitle); button.Content = grid; button.Click += delegate { action(); }; return button;
        }

        private void CycleShellStyle()
        {
            settings.shellStyle = String.Equals(settings.shellStyle, "Updated", StringComparison.OrdinalIgnoreCase) ? "Original" : "Updated";
            settings.Save(settingsPath); root.Background = BuildBackgroundBrush(); selected = 0; RenderSettings();
        }

        private void AddActionButton(Panel panel, string name, string detail, Action action)
        {
            Button button = CreateListButton(name, detail, action);
            panel.Children.Add(button);
            actions.Add(new Ps1UiAction { Button = button, Invoke = action, Name = name });
        }

        private void ChooseDuckStation()
        {
            OpenFileDialog dialog = new OpenFileDialog();
            dialog.Title = "Select DuckStation";
            dialog.Filter = "DuckStation executable (duckstation*.exe)|duckstation*.exe|Applications (*.exe)|*.exe";
            if (dialog.ShowDialog(this) == true)
            {
                settings.duckStationPath = dialog.FileName;
                if (File.Exists(Path.Combine(Path.GetDirectoryName(dialog.FileName), "portable.txt"))) settings.dataRoot = Path.GetDirectoryName(dialog.FileName);
                else if (String.IsNullOrWhiteSpace(settings.dataRoot)) settings.dataRoot = Ps1Environment.FindDataRoot(dialog.FileName);
                settings.Save(settingsPath);
                RenderSettings();
            }
        }

        private void ChooseDataRoot()
        {
            using (System.Windows.Forms.FolderBrowserDialog dialog = new System.Windows.Forms.FolderBrowserDialog())
            {
                dialog.Description = "Choose the DuckStation user data folder containing bios, covers, memcards and states";
                if (dialog.ShowDialog() == System.Windows.Forms.DialogResult.OK)
                {
                    settings.dataRoot = dialog.SelectedPath;
                    settings.Save(settingsPath);
                    RenderSettings();
                }
            }
        }

        private void AddGameFolder()
        {
            using (System.Windows.Forms.FolderBrowserDialog dialog = new System.Windows.Forms.FolderBrowserDialog())
            {
                dialog.Description = "Choose a PlayStation game folder";
                if (dialog.ShowDialog() == System.Windows.Forms.DialogResult.OK)
                {
                    if (!settings.gameFolders.Any(p => String.Equals(p, dialog.SelectedPath, StringComparison.OrdinalIgnoreCase))) settings.gameFolders.Add(dialog.SelectedPath);
                    settings.Save(settingsPath);
                    RenderSettings();
                }
            }
        }

        private void ImportBiosImage()
        {
            OpenFileDialog dialog = new OpenFileDialog();
            dialog.Title = "Select a PlayStation BIOS image you legally dumped";
            dialog.Filter = "PlayStation BIOS images|*.bin;*.rom|All files|*.*";
            if (dialog.ShowDialog(this) != true) return;
            try
            {
                long length = new FileInfo(dialog.FileName).Length;
                if (length != 262144 && length != 524288) { ShowNotice("The selected file is not a recognized 256/512 KB PS1 BIOS image"); return; }
                string rootPath = Path.Combine(settings.dataRoot ?? String.Empty, "bios");
                Directory.CreateDirectory(rootPath);
                string destination = Path.Combine(rootPath, Path.GetFileName(dialog.FileName));
                if (!String.Equals(Path.GetFullPath(dialog.FileName), Path.GetFullPath(destination), StringComparison.OrdinalIgnoreCase)) File.Copy(dialog.FileName, destination, true);
                ShowNotice("BIOS image imported");
                RenderSettings();
            }
            catch (Exception ex) { ShowNotice("BIOS import failed: " + ex.Message); }
        }

        private void OpenBiosFolder()
        {
            string rootPath = Path.Combine(settings.dataRoot ?? String.Empty, "bios");
            Directory.CreateDirectory(rootPath);
            Process.Start("explorer.exe", rootPath);
        }

        private void ImportAudio(bool startup)
        {
            OpenFileDialog dialog = new OpenFileDialog();
            dialog.Title = startup ? "Choose PlayStation startup audio" : "Choose PlayStation menu ambience";
            dialog.Filter = "Audio files|*.mp3;*.wav;*.wma;*.m4a|All files|*.*";
            if (dialog.ShowDialog(this) == true)
            {
                if (startup) settings.startupAudioPath = dialog.FileName; else settings.ambienceAudioPath = dialog.FileName;
                settings.Save(settingsPath);
                TryStartAudio();
                RenderSettings();
            }
        }

        private void SaveSettingsAndRender()
        {
            settings.Save(settingsPath);
            RenderSettings();
        }

        private void InstallManagedDuckStation()
        {
            using (System.Windows.Forms.FolderBrowserDialog dialog = new System.Windows.Forms.FolderBrowserDialog())
            {
                dialog.Description = "Choose an external folder for DuckStation";
                if (dialog.ShowDialog() != System.Windows.Forms.DialogResult.OK) return;
                string script = Path.Combine(consoleRoot, "Tools", "Install-Latest-DuckStation.ps1");
                if (!File.Exists(script)) { ShowNotice("DuckStation installer helper is missing"); return; }
                ShowNotice("Installing DuckStation…");
                ThreadPool.QueueUserWorkItem(delegate
                {
                    try
                    {
                        ProcessStartInfo info = new ProcessStartInfo("powershell.exe", "-NoLogo -NoProfile -ExecutionPolicy Bypass -File \"" + script + "\" -DestinationRoot \"" + dialog.SelectedPath.Replace("\"", String.Empty) + "\"");
                        info.UseShellExecute = false;
                        info.CreateNoWindow = true;
                        Process process = Process.Start(info);
                        if (process != null) process.WaitForExit();
                        string executable = Ps1Environment.FindDuckStationUnder(dialog.SelectedPath);
                        Dispatcher.BeginInvoke(new Action(delegate
                        {
                            if (!String.IsNullOrWhiteSpace(executable))
                            {
                                settings.duckStationPath = executable;
                                settings.dataRoot = Path.GetDirectoryName(executable);
                                settings.Save(settingsPath);
                                ShowNotice("DuckStation installed");
                            }
                            else ShowNotice("DuckStation was not found after installation");
                            RenderSettings();
                        }));
                    }
                    catch (Exception ex) { Dispatcher.BeginInvoke(new Action(delegate { ShowNotice("Install failed: " + ex.Message); })); }
                });
            }
        }

        private void OpenDuckStationBigPicture()
        {
            if (String.IsNullOrWhiteSpace(settings.duckStationPath) || !File.Exists(settings.duckStationPath)) { ShowNotice("Select DuckStation first"); return; }
            try { Process.Start(new ProcessStartInfo(settings.duckStationPath, "-bigpicture -fullscreen") { WorkingDirectory = Path.GetDirectoryName(settings.duckStationPath), UseShellExecute = true }); }
            catch (Exception ex) { ShowNotice("DuckStation could not open: " + ex.Message); }
        }

        private void UpdateNavVisuals()
        {
            int highlighted = navigationMode ? navigationSelected : -1;
            if (!navigationMode)
            {
                for (int i = 0; i < navButtons.Count; i++)
                {
                    if ((int)navButtons[i].Tag == section) { highlighted = i; break; }
                }
            }
            for (int i = 0; i < navButtons.Count; i++)
            {
                bool active = i == highlighted;
                bool focus = navigationMode && active;
                navButtons[i].Background = new SolidColorBrush(active ? Color.FromArgb(focus ? (byte)175 : (byte)120, (byte)35, (byte)55, (byte)108) : Color.FromArgb(0, 0, 0, 0));
                navButtons[i].BorderBrush = new SolidColorBrush(focus ? Color.FromRgb(238, 209, 107) : (active ? Color.FromRgb(103, 142, 238) : Color.FromArgb(35, 255, 255, 255)));
                navButtons[i].BorderThickness = new Thickness(active ? (focus ? 3 : 2) : 1);
            }
        }

        private void UpdateVisuals()
        {
            UpdateNavVisuals();
            for (int i = 0; i < actions.Count; i++)
            {
                bool active = !letterMode && i == selected;
                Button button = actions[i].Button;
                if (button == null) continue;
                Color focusColor = String.Equals(settings.shellStyle, "Updated", StringComparison.OrdinalIgnoreCase) ? Color.FromRgb(255, 213, 24) : Color.FromRgb(90, 126, 255);
                button.BorderBrush = new SolidColorBrush(active ? focusColor : Color.FromArgb(55, 255, 255, 255));
                button.BorderThickness = new Thickness(active ? 4 : 1);
                button.Opacity = active ? 1 : 0.88;
                button.RenderTransform = new ScaleTransform(active ? 1.018 : 1, active ? 1.018 : 1);
                if (active) button.BringIntoView();
            }
            if (letterMode) footerText.Text = "UP / DOWN  Choose Letter    A / CROSS  Jump    B / CIRCLE  Cancel";
            else if (section == 5) footerText.Text = "A / CROSS  Select / Play    B / CIRCLE  Back    MUSIC PLAYER  Game-disc audio";
            else footerText.Text = section == 4 ? "A / CROSS  Select    B / CIRCLE  Exit    Y / TRIANGLE  Options" : "A / CROSS  Select    B / CIRCLE  Main Menu    GUIDE / HOME  Main Menu    Y / TRIANGLE  Options";
        }

        private int LetterIndexForSelected()
        {
            if (selected < 0 || selected >= actions.Count) return 0;
            char value = actions[selected].Letter;
            int index = Array.IndexOf(letters, value);
            return index < 0 ? 0 : index;
        }

        private void JumpLetter(int delta)
        {
            if (section != 0 || games.Count == 0) return;
            int current = LetterIndexForSelected();
            int next = (current + delta + letters.Length) % letters.Length;
            JumpToLetter(letters[next]);
            UpdateVisuals();
        }

        private void JumpToLetter(char letter)
        {
            for (int i = 0; i < actions.Count; i++)
            {
                if (actions[i].Letter == letter) { selected = i; return; }
            }
            ShowNotice("No titles under " + letter);
        }

        private static char GetLetter(string value)
        {
            if (String.IsNullOrWhiteSpace(value)) return '#';
            char c = Char.ToUpperInvariant(value.Trim()[0]);
            return c >= 'A' && c <= 'Z' ? c : '#';
        }

        private void ShowNotice(string value)
        {
            noticeText.Text = value ?? String.Empty;
            noticeUntil = DateTime.UtcNow.AddSeconds(4);
        }

        private void UpdateNotice()
        {
            if (noticeText.Text.Length > 0 && DateTime.UtcNow >= noticeUntil) noticeText.Text = String.Empty;
        }

        private void WriteLog(string message, string level)
        {
            try
            {
                Directory.CreateDirectory(Path.GetDirectoryName(logPath));
                File.AppendAllText(logPath, DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss.fff") + " [" + level + "] " + message + Environment.NewLine, Encoding.UTF8);
            }
            catch { }
        }
    }

    public static class Ps1Environment
    {
        private static readonly string[] GameExtensions = new string[] { ".cue", ".chd", ".pbp", ".ccd", ".m3u", ".iso", ".mds", ".ecm", ".bin" };

        public static string FindDuckStationExecutable()
        {
            List<string> candidates = new List<string>();
            string local = Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData);
            string programFiles = Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles);
            string programFilesX86 = Environment.GetFolderPath(Environment.SpecialFolder.ProgramFilesX86);
            AddExecutableCandidates(candidates, Path.Combine(local, "Programs", "DuckStation"));
            AddExecutableCandidates(candidates, Path.Combine(local, "DuckStation"));
            AddExecutableCandidates(candidates, Path.Combine(programFiles, "DuckStation"));
            AddExecutableCandidates(candidates, Path.Combine(programFilesX86, "DuckStation"));
            AddExecutableCandidates(candidates, Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.UserProfile), "Applications", "DuckStation"));
            try
            {
                using (RegistryKey key = Registry.CurrentUser.OpenSubKey(@"Software\Microsoft\Windows\CurrentVersion\App Paths\duckstation-qt-x64-ReleaseLTCG.exe"))
                {
                    if (key != null) candidates.Add(Convert.ToString(key.GetValue(String.Empty), CultureInfo.InvariantCulture));
                }
            }
            catch { }
            return candidates.FirstOrDefault(File.Exists) ?? String.Empty;
        }

        public static string FindDuckStationUnder(string root)
        {
            try
            {
                if (!Directory.Exists(root)) return String.Empty;
                string[] files = Directory.GetFiles(root, "duckstation*.exe", SearchOption.AllDirectories);
                return files.FirstOrDefault(p => Path.GetFileName(p).IndexOf("qt", StringComparison.OrdinalIgnoreCase) >= 0) ?? files.FirstOrDefault() ?? String.Empty;
            }
            catch { return String.Empty; }
        }

        private static void AddExecutableCandidates(List<string> target, string root)
        {
            if (!Directory.Exists(root)) return;
            try
            {
                target.AddRange(Directory.GetFiles(root, "duckstation*.exe", SearchOption.TopDirectoryOnly).OrderByDescending(p => p.IndexOf("LTCG", StringComparison.OrdinalIgnoreCase) >= 0));
            }
            catch { }
        }

        public static string FindDataRoot(string executable)
        {
            try
            {
                if (!String.IsNullOrWhiteSpace(executable))
                {
                    string directory = Path.GetDirectoryName(executable);
                    if (File.Exists(Path.Combine(directory, "portable.txt"))) return directory;
                }
            }
            catch { }
            string local = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "DuckStation");
            if (Directory.Exists(local)) return local;
            string documents = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.MyDocuments), "DuckStation");
            if (Directory.Exists(documents)) return documents;
            return local;
        }

        public static List<Ps1Game> ScanGames(Ps1Settings settings, Action<string, string> log)
        {
            HashSet<string> roots = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            foreach (string folder in settings.gameFolders ?? new List<string>()) if (Directory.Exists(folder)) roots.Add(folder);
            foreach (string folder in ReadDuckStationGameFolders(settings.dataRoot)) if (Directory.Exists(folder)) roots.Add(folder);
            Dictionary<string, Ps1Game> groups = new Dictionary<string, Ps1Game>(StringComparer.OrdinalIgnoreCase);
            foreach (string root in roots)
            {
                List<string> files;
                try { files = Directory.EnumerateFiles(root, "*", SearchOption.AllDirectories).Take(7000).ToList(); }
                catch { continue; }
                HashSet<string> cueReferencedFiles = ReadCueReferencedFiles(files);
                int count = 0;
                foreach (string file in files)
                {
                    count++;
                    string extension = Path.GetExtension(file).ToLowerInvariant();
                    if (!GameExtensions.Contains(extension)) continue;
                    if ((extension == ".bin" || extension == ".raw" || extension == ".img") && cueReferencedFiles.Contains(file)) continue;
                    if (extension == ".bin" && File.Exists(Path.ChangeExtension(file, ".cue"))) continue;
                    string display = CleanTitle(Path.GetFileNameWithoutExtension(file));
                    string key = NormalizeDiscGroup(display);
                    Ps1Game game;
                    if (!groups.TryGetValue(key, out game))
                    {
                        game = new Ps1Game();
                        game.Name = display;
                        game.SortName = SortKey(display);
                        game.Serial = FindSerial(Path.GetFileName(file));
                        game.PrimaryPath = file;
                        groups[key] = game;
                    }
                    if (extension == ".m3u")
                    {
                        try
                        {
                            string playlistRoot = Path.GetDirectoryName(file);
                            foreach (string rawEntry in File.ReadAllLines(file))
                            {
                                string entry = rawEntry.Trim();
                                if (entry.Length == 0 || entry.StartsWith("#", StringComparison.Ordinal)) continue;
                                string resolved = Path.IsPathRooted(entry) ? entry : Path.GetFullPath(Path.Combine(playlistRoot, entry));
                                if (File.Exists(resolved) && !game.Discs.Contains(resolved, StringComparer.OrdinalIgnoreCase)) game.Discs.Add(resolved);
                            }
                        }
                        catch { }
                    }
                    else if (!game.Discs.Contains(file, StringComparer.OrdinalIgnoreCase)) game.Discs.Add(file);
                }
            }
            foreach (Ps1Game game in groups.Values)
            {
                game.Discs = game.Discs.Distinct(StringComparer.OrdinalIgnoreCase).OrderBy(p => p, StringComparer.CurrentCultureIgnoreCase).ToList();
                game.PrimaryPath = game.Discs.FirstOrDefault() ?? game.PrimaryPath;
            }
            List<Ps1Game> result = groups.Values.Where(g => g.Discs.Count > 0 && File.Exists(g.PrimaryPath)).OrderBy(g => g.SortName, StringComparer.CurrentCultureIgnoreCase).ToList();
            AttachDuckStationCovers(result, settings, log);
            if (log != null) log("DuckStation library scan found " + result.Count.ToString(CultureInfo.InvariantCulture) + " title(s) from " + roots.Count.ToString(CultureInfo.InvariantCulture) + " root(s).", "INFO");
            return result;
        }

        private sealed class CueTrackRecord
        {
            public string FilePath; public string FileType; public int TrackNumber; public bool Audio; public long StartSector;
            public CueTrackRecord() { FilePath = String.Empty; FileType = String.Empty; TrackNumber = 0; Audio = false; StartSector = -1; }
        }

        public static List<Ps1MusicTrack> ReadCueAudioTracks(string cuePath, int discNumber)
        {
            List<Ps1MusicTrack> result = new List<Ps1MusicTrack>();
            if (String.IsNullOrWhiteSpace(cuePath) || !File.Exists(cuePath)) return result;
            List<CueTrackRecord> records = new List<CueTrackRecord>();
            string currentFile = String.Empty; string currentType = "BINARY"; CueTrackRecord currentTrack = null;
            try
            {
                foreach (string raw in File.ReadAllLines(cuePath))
                {
                    string line = raw.Trim(); if (line.Length == 0) continue;
                    if (line.StartsWith("FILE ", StringComparison.OrdinalIgnoreCase))
                    {
                        string fileValue; string fileType; ParseCueFileLine(line, out fileValue, out fileType);
                        currentFile = Path.IsPathRooted(fileValue) ? fileValue : Path.GetFullPath(Path.Combine(Path.GetDirectoryName(cuePath), fileValue));
                        currentType = fileType;
                        continue;
                    }
                    if (line.StartsWith("TRACK ", StringComparison.OrdinalIgnoreCase))
                    {
                        string[] parts = line.Split(new char[] { ' ', '\t' }, StringSplitOptions.RemoveEmptyEntries); int number = 0;
                        if (parts.Length >= 3 && Int32.TryParse(parts[1], NumberStyles.Integer, CultureInfo.InvariantCulture, out number))
                        {
                            currentTrack = new CueTrackRecord { FilePath = currentFile, FileType = currentType, TrackNumber = number, Audio = String.Equals(parts[2], "AUDIO", StringComparison.OrdinalIgnoreCase), StartSector = -1 };
                            records.Add(currentTrack);
                        }
                        continue;
                    }
                    if (currentTrack != null && line.StartsWith("INDEX 01 ", StringComparison.OrdinalIgnoreCase))
                    {
                        string[] parts = line.Split(new char[] { ' ', '\t' }, StringSplitOptions.RemoveEmptyEntries);
                        if (parts.Length >= 3) currentTrack.StartSector = ParseMsfSector(parts[2]);
                    }
                }
            }
            catch { return result; }
            for (int i = 0; i < records.Count; i++)
            {
                CueTrackRecord record = records[i]; if (!record.Audio || String.IsNullOrWhiteSpace(record.FilePath) || !File.Exists(record.FilePath)) continue;
                long start = Math.Max(0, record.StartSector); long end = -1;
                for (int j = i + 1; j < records.Count; j++)
                {
                    CueTrackRecord next = records[j];
                    if (!String.Equals(next.FilePath, record.FilePath, StringComparison.OrdinalIgnoreCase)) break;
                    if (next.StartSector >= 0) { end = next.StartSector; break; }
                }
                if (end < 0 && String.Equals(record.FileType, "BINARY", StringComparison.OrdinalIgnoreCase))
                {
                    try { end = new FileInfo(record.FilePath).Length / 2352L; } catch { end = -1; }
                }
                Ps1MusicTrack track = new Ps1MusicTrack(); track.SourcePath = record.FilePath; track.SourceType = record.FileType; track.DiscNumber = Math.Max(1, discNumber); track.TrackNumber = record.TrackNumber; track.StartSector = start; track.EndSector = end;
                track.Title = "Track " + record.TrackNumber.ToString("00", CultureInfo.InvariantCulture); result.Add(track);
            }
            return result;
        }

        private static void ParseCueFileLine(string line, out string fileValue, out string fileType)
        {
            fileValue = String.Empty; fileType = "BINARY"; string rest = line.Substring(4).Trim();
            if (rest.StartsWith("\"", StringComparison.Ordinal))
            {
                int closing = rest.IndexOf('"', 1); if (closing > 0) { fileValue = rest.Substring(1, closing - 1); fileType = rest.Substring(closing + 1).Trim(); }
            }
            else
            {
                int split = rest.LastIndexOf(' '); if (split > 0) { fileValue = rest.Substring(0, split).Trim(); fileType = rest.Substring(split + 1).Trim(); } else fileValue = rest;
            }
            if (String.IsNullOrWhiteSpace(fileType)) fileType = "BINARY";
        }

        private static long ParseMsfSector(string value)
        {
            string[] parts = (value ?? String.Empty).Split(':'); int minutes, seconds, frames;
            if (parts.Length != 3 || !Int32.TryParse(parts[0], out minutes) || !Int32.TryParse(parts[1], out seconds) || !Int32.TryParse(parts[2], out frames)) return -1;
            return ((long)minutes * 60L * 75L) + ((long)seconds * 75L) + frames;
        }

        public static string PrepareAudioTrack(Ps1MusicTrack track, string cacheRoot, Action<string, string> log)
        {
            if (track == null || String.IsNullOrWhiteSpace(track.SourcePath) || !File.Exists(track.SourcePath)) return String.Empty;
            string extension = Path.GetExtension(track.SourcePath).ToLowerInvariant();
            if ((extension == ".wav" || extension == ".mp3" || extension == ".wma" || extension == ".m4a") && track.StartSector <= 0 && track.EndSector < 0) return track.SourcePath;
            if (!String.Equals(track.SourceType, "BINARY", StringComparison.OrdinalIgnoreCase) && extension != ".bin" && extension != ".raw" && extension != ".img") return track.SourcePath;
            Directory.CreateDirectory(cacheRoot);
            FileInfo source = new FileInfo(track.SourcePath); long startByte = Math.Max(0, track.StartSector) * 2352L; long endByte = track.EndSector > track.StartSector ? Math.Min(source.Length, track.EndSector * 2352L) : source.Length;
            long dataLength = endByte - startByte; if (dataLength <= 0 || dataLength > UInt32.MaxValue) return String.Empty;
            string stem = MakeSafeFileName((track.AlbumName ?? "Album") + "-D" + track.DiscNumber.ToString(CultureInfo.InvariantCulture) + "-T" + track.TrackNumber.ToString("00", CultureInfo.InvariantCulture));
            string fingerprint = StablePathHash(track.SourcePath + "|" + startByte.ToString(CultureInfo.InvariantCulture) + "|" + endByte.ToString(CultureInfo.InvariantCulture) + "|" + source.LastWriteTimeUtc.Ticks.ToString(CultureInfo.InvariantCulture));
            string output = Path.Combine(cacheRoot, stem + "-" + fingerprint + ".wav");
            if (File.Exists(output) && new FileInfo(output).Length == dataLength + 44) return output;
            string temporary = output + ".tmp";
            try
            {
                using (FileStream input = new FileStream(track.SourcePath, FileMode.Open, FileAccess.Read, FileShare.Read))
                using (FileStream stream = new FileStream(temporary, FileMode.Create, FileAccess.Write, FileShare.None))
                using (BinaryWriter writer = new BinaryWriter(stream, Encoding.ASCII))
                {
                    writer.Write(Encoding.ASCII.GetBytes("RIFF")); writer.Write((UInt32)(dataLength + 36)); writer.Write(Encoding.ASCII.GetBytes("WAVE"));
                    writer.Write(Encoding.ASCII.GetBytes("fmt ")); writer.Write((UInt32)16); writer.Write((UInt16)1); writer.Write((UInt16)2); writer.Write((UInt32)44100); writer.Write((UInt32)176400); writer.Write((UInt16)4); writer.Write((UInt16)16);
                    writer.Write(Encoding.ASCII.GetBytes("data")); writer.Write((UInt32)dataLength); input.Position = startByte;
                    byte[] buffer = new byte[1024 * 1024]; long remaining = dataLength;
                    while (remaining > 0) { int read = input.Read(buffer, 0, (int)Math.Min((long)buffer.Length, remaining)); if (read <= 0) break; writer.Write(buffer, 0, read); remaining -= read; }
                    if (remaining != 0) throw new EndOfStreamException("The CD-audio track ended unexpectedly.");
                }
                if (File.Exists(output)) File.Delete(output); File.Move(temporary, output);
                if (log != null) log("Prepared PS1 CD-audio track: " + output, "INFO"); return output;
            }
            catch (Exception ex) { try { if (File.Exists(temporary)) File.Delete(temporary); } catch { } if (log != null) log("CD-audio extraction failed: " + ex.Message, "WARN"); return String.Empty; }
        }

        private static string MakeSafeFileName(string value)
        {
            StringBuilder result = new StringBuilder(); foreach (char c in value ?? String.Empty) result.Append(Path.GetInvalidFileNameChars().Contains(c) ? '_' : c); return result.ToString().Trim();
        }

        private static string StablePathHash(string value)
        {
            unchecked { UInt32 hash = 2166136261; foreach (char c in value ?? String.Empty) { hash ^= c; hash *= 16777619; } return hash.ToString("X8", CultureInfo.InvariantCulture); }
        }

        private static HashSet<string> ReadCueReferencedFiles(IEnumerable<string> files)
        {
            HashSet<string> result = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            foreach (string cue in files.Where(delegate(string path) { return String.Equals(Path.GetExtension(path), ".cue", StringComparison.OrdinalIgnoreCase); }))
            {
                try
                {
                    foreach (string raw in File.ReadAllLines(cue))
                    {
                        string line = raw.Trim(); if (!line.StartsWith("FILE ", StringComparison.OrdinalIgnoreCase)) continue;
                        string fileValue; string fileType; ParseCueFileLine(line, out fileValue, out fileType); if (String.IsNullOrWhiteSpace(fileValue)) continue;
                        string resolved = Path.IsPathRooted(fileValue) ? fileValue : Path.GetFullPath(Path.Combine(Path.GetDirectoryName(cue), fileValue)); result.Add(resolved);
                    }
                }
                catch { }
            }
            return result;
        }

        public static List<string> ReadDuckStationGameFolders(string dataRoot)
        {
            List<string> result = new List<string>();
            if (String.IsNullOrWhiteSpace(dataRoot)) return result;
            string settingsFile = Path.Combine(dataRoot, "settings.ini");
            if (!File.Exists(settingsFile)) settingsFile = Path.Combine(dataRoot, "settings", "settings.ini");
            if (!File.Exists(settingsFile)) return result;
            try
            {
                bool gameList = false;
                foreach (string raw in File.ReadAllLines(settingsFile))
                {
                    string line = raw.Trim();
                    if (line.StartsWith("[") && line.EndsWith("]")) { gameList = line.Equals("[GameList]", StringComparison.OrdinalIgnoreCase); continue; }
                    if (!gameList) continue;
                    int equal = line.IndexOf('=');
                    if (equal <= 0) continue;
                    string key = line.Substring(0, equal).Trim();
                    string value = line.Substring(equal + 1).Trim().Trim('"');
                    if (key.IndexOf("Path", StringComparison.OrdinalIgnoreCase) < 0 || String.IsNullOrWhiteSpace(value)) continue;
                    foreach (string part in value.Split(new char[] { ';', '|' }, StringSplitOptions.RemoveEmptyEntries))
                    {
                        string folder = part.Trim().Trim('"');
                        if (Directory.Exists(folder) && !result.Contains(folder, StringComparer.OrdinalIgnoreCase)) result.Add(folder);
                    }
                }
            }
            catch { }
            return result;
        }

        private sealed class DuckStationGameCacheEntry
        {
            public string Path;
            public string Serial;
            public string Title;

            public DuckStationGameCacheEntry()
            {
                Path = String.Empty;
                Serial = String.Empty;
                Title = String.Empty;
            }
        }

        public static bool AttachDuckStationCovers(List<Ps1Game> games, Ps1Settings settings, Action<string, string> log)
        {
            if (games == null || games.Count == 0 || settings == null) return false;
            List<string> coverRoots = FindCoverRoots(settings.dataRoot, settings.duckStationPath);
            Dictionary<string, string> coverIndex = BuildCoverIndex(coverRoots);
            Dictionary<string, DuckStationGameCacheEntry> cacheByPath = new Dictionary<string, DuckStationGameCacheEntry>(StringComparer.OrdinalIgnoreCase);
            Dictionary<string, DuckStationGameCacheEntry> cacheByFile = new Dictionary<string, DuckStationGameCacheEntry>(StringComparer.OrdinalIgnoreCase);
            foreach (DuckStationGameCacheEntry entry in ReadDuckStationGameCache(settings.dataRoot, log))
            {
                string pathKey = NormalizePathKey(entry.Path);
                if (!String.IsNullOrWhiteSpace(pathKey) && !cacheByPath.ContainsKey(pathKey)) cacheByPath[pathKey] = entry;
                string fileKey = NormalizeCoverKey(Path.GetFileNameWithoutExtension(entry.Path));
                if (!String.IsNullOrWhiteSpace(fileKey) && !cacheByFile.ContainsKey(fileKey)) cacheByFile[fileKey] = entry;
            }

            bool changed = false;
            int matched = 0;
            foreach (Ps1Game game in games)
            {
                DuckStationGameCacheEntry metadata = null;
                foreach (string disc in game.Discs ?? new List<string>())
                {
                    string pathKey = NormalizePathKey(disc);
                    if (!String.IsNullOrWhiteSpace(pathKey) && cacheByPath.TryGetValue(pathKey, out metadata)) break;
                    string fileKey = NormalizeCoverKey(Path.GetFileNameWithoutExtension(disc));
                    if (!String.IsNullOrWhiteSpace(fileKey) && cacheByFile.TryGetValue(fileKey, out metadata)) break;
                    metadata = null;
                }
                if (metadata == null && !String.IsNullOrWhiteSpace(game.PrimaryPath))
                {
                    string pathKey = NormalizePathKey(game.PrimaryPath);
                    cacheByPath.TryGetValue(pathKey, out metadata);
                }

                if (metadata != null && String.IsNullOrWhiteSpace(game.Serial) && !String.IsNullOrWhiteSpace(metadata.Serial))
                {
                    game.Serial = metadata.Serial;
                    changed = true;
                }

                string existing = game.CoverPath;
                if (!String.IsNullOrWhiteSpace(existing) && File.Exists(existing))
                {
                    matched++;
                    continue;
                }

                string cover = FindCover(game, metadata, coverIndex);
                if (!String.IsNullOrWhiteSpace(cover) && File.Exists(cover))
                {
                    if (!String.Equals(game.CoverPath, cover, StringComparison.OrdinalIgnoreCase))
                    {
                        game.CoverPath = cover;
                        changed = true;
                    }
                    matched++;
                }
                else if (!String.IsNullOrWhiteSpace(game.CoverPath))
                {
                    game.CoverPath = String.Empty;
                    changed = true;
                }
            }
            if (log != null) log("DuckStation cover import matched " + matched.ToString(CultureInfo.InvariantCulture) + " of " + games.Count.ToString(CultureInfo.InvariantCulture) + " cached PlayStation title(s) from " + coverRoots.Count.ToString(CultureInfo.InvariantCulture) + " cover folder(s).", "INFO");
            return changed;
        }

        private static List<string> FindCoverRoots(string dataRoot, string executable)
        {
            List<string> result = new List<string>();
            List<string> bases = new List<string>();
            AddDirectory(bases, dataRoot);
            try { AddDirectory(bases, Path.GetDirectoryName(executable ?? String.Empty)); } catch { }
            string configured = ReadDuckStationFolderSetting(dataRoot, "Covers");
            AddDirectory(result, ResolveDuckStationFolder(dataRoot, configured));
            foreach (string baseRoot in bases)
            {
                AddDirectory(result, Path.Combine(baseRoot, "covers"));
                AddDirectory(result, Path.Combine(baseRoot, "Covers"));
                AddDirectory(result, Path.Combine(baseRoot, "cache", "covers"));
                AddDirectory(result, Path.Combine(baseRoot, "cache", "game-covers"));
                try
                {
                    foreach (string directory in Directory.EnumerateDirectories(baseRoot, "*", SearchOption.TopDirectoryOnly))
                    {
                        string name = Path.GetFileName(directory);
                        if (name.IndexOf("cover", StringComparison.OrdinalIgnoreCase) >= 0) AddDirectory(result, directory);
                    }
                }
                catch { }
            }
            return result;
        }

        private static Dictionary<string, string> BuildCoverIndex(List<string> roots)
        {
            Dictionary<string, string> result = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
            foreach (string root in roots)
            {
                try
                {
                    int count = 0;
                    foreach (string file in Directory.EnumerateFiles(root, "*", SearchOption.AllDirectories))
                    {
                        if (++count > 30000) break;
                        string extension = Path.GetExtension(file).ToLowerInvariant();
                        if (extension != ".png" && extension != ".jpg" && extension != ".jpeg" && extension != ".webp") continue;
                        string key = NormalizeCoverKey(Path.GetFileNameWithoutExtension(file));
                        if (!String.IsNullOrWhiteSpace(key) && !result.ContainsKey(key)) result[key] = file;
                    }
                }
                catch { }
            }
            return result;
        }

        private static string FindCover(Ps1Game game, DuckStationGameCacheEntry metadata, Dictionary<string, string> index)
        {
            List<string> candidates = new List<string>();
            AddCoverCandidate(candidates, game.Serial);
            if (metadata != null) AddCoverCandidate(candidates, metadata.Serial);
            AddCoverCandidate(candidates, Path.GetFileNameWithoutExtension(game.PrimaryPath));
            if (metadata != null)
            {
                AddCoverCandidate(candidates, Path.GetFileNameWithoutExtension(metadata.Path));
                AddCoverCandidate(candidates, metadata.Title);
            }
            AddCoverCandidate(candidates, game.Name);
            foreach (string disc in game.Discs ?? new List<string>()) AddCoverCandidate(candidates, Path.GetFileNameWithoutExtension(disc));

            string value;
            foreach (string candidate in candidates)
            {
                string key = NormalizeCoverKey(candidate);
                if (!String.IsNullOrWhiteSpace(key) && index.TryGetValue(key, out value)) return value;
            }

            // Last-resort title match for region/revision suffix differences.
            string looseTitle = NormalizeLooseTitle(metadata != null && !String.IsNullOrWhiteSpace(metadata.Title) ? metadata.Title : game.Name);
            if (looseTitle.Length >= 6)
            {
                foreach (KeyValuePair<string, string> pair in index)
                {
                    string looseFile = NormalizeLooseTitle(Path.GetFileNameWithoutExtension(pair.Value));
                    if (looseFile == looseTitle || (looseFile.Length >= 8 && looseTitle.Length >= 8 && (looseFile.StartsWith(looseTitle, StringComparison.OrdinalIgnoreCase) || looseTitle.StartsWith(looseFile, StringComparison.OrdinalIgnoreCase)))) return pair.Value;
                }
            }
            return String.Empty;
        }

        private static void AddCoverCandidate(List<string> target, string value)
        {
            if (String.IsNullOrWhiteSpace(value)) return;
            if (!target.Contains(value, StringComparer.OrdinalIgnoreCase)) target.Add(value);
        }

        private static string NormalizeCoverKey(string value)
        {
            if (String.IsNullOrWhiteSpace(value)) return String.Empty;
            return System.Text.RegularExpressions.Regex.Replace(value.ToLowerInvariant(), "[^a-z0-9]+", String.Empty);
        }

        private static string NormalizeLooseTitle(string value)
        {
            if (String.IsNullOrWhiteSpace(value)) return String.Empty;
            string title = value.Replace("&", " and ");
            title = System.Text.RegularExpressions.Regex.Replace(title, @"[\(\[].*?[\)\]]", " ");
            title = System.Text.RegularExpressions.Regex.Replace(title, @"\b(disc|disk|cd|rev|revision)\s*[a-z0-9.]*\b", " ", System.Text.RegularExpressions.RegexOptions.IgnoreCase);
            return NormalizeCoverKey(title);
        }

        private static string NormalizePathKey(string value)
        {
            if (String.IsNullOrWhiteSpace(value)) return String.Empty;
            try { return Path.GetFullPath(value).TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar); }
            catch { return value.Trim(); }
        }

        private static List<DuckStationGameCacheEntry> ReadDuckStationGameCache(string dataRoot, Action<string, string> log)
        {
            List<DuckStationGameCacheEntry> result = new List<DuckStationGameCacheEntry>();
            if (String.IsNullOrWhiteSpace(dataRoot)) return result;
            string configuredCache = ReadDuckStationFolderSetting(dataRoot, "Cache");
            List<string> candidates = new List<string>();
            string configuredRoot = ResolveDuckStationFolder(dataRoot, configuredCache);
            if (!String.IsNullOrWhiteSpace(configuredRoot)) candidates.Add(Path.Combine(configuredRoot, "gamelist.cache"));
            candidates.Add(Path.Combine(dataRoot, "cache", "gamelist.cache"));
            candidates.Add(Path.Combine(dataRoot, "gamelist.cache"));
            string cachePath = candidates.FirstOrDefault(File.Exists);
            if (String.IsNullOrWhiteSpace(cachePath)) return result;
            try
            {
                using (FileStream stream = new FileStream(cachePath, System.IO.FileMode.Open, FileAccess.Read, FileShare.ReadWrite | FileShare.Delete))
                using (BinaryReader reader = new BinaryReader(stream, Encoding.UTF8))
                {
                    if (stream.Length < 8) return result;
                    uint signature = reader.ReadUInt32();
                    uint version = reader.ReadUInt32();
                    if (signature != 0x45434C48) return result;
                    while (stream.Position < stream.Length)
                    {
                        if (stream.Length - stream.Position < 2) break;
                        reader.ReadByte(); // entry type
                        reader.ReadByte(); // region
                        DuckStationGameCacheEntry entry = new DuckStationGameCacheEntry();
                        entry.Path = ReadDuckStationCacheString(reader);
                        entry.Serial = ReadDuckStationCacheString(reader);
                        entry.Title = ReadDuckStationCacheString(reader);
                        if (stream.Length - stream.Position < 49) break;
                        reader.ReadUInt64(); // hash
                        reader.ReadInt64(); // file size
                        reader.ReadUInt64(); // uncompressed size
                        reader.ReadUInt64(); // modified time
                        reader.ReadSByte(); // disc-set index
                        reader.ReadBytes(16); // achievements hash
                        if (!String.IsNullOrWhiteSpace(entry.Path)) result.Add(entry);
                    }
                    if (log != null) log("Read " + result.Count.ToString(CultureInfo.InvariantCulture) + " DuckStation game metadata entries from gamelist.cache version " + version.ToString(CultureInfo.InvariantCulture) + ".", "INFO");
                }
            }
            catch (Exception ex)
            {
                if (log != null) log("DuckStation gamelist.cache could not be read for cover matching: " + ex.Message, "WARN");
                result.Clear();
            }
            return result;
        }

        private static string ReadDuckStationCacheString(BinaryReader reader)
        {
            uint length = reader.ReadUInt32();
            if (length > 1024 * 1024) throw new InvalidDataException("DuckStation cache string is too large.");
            byte[] bytes = reader.ReadBytes((int)length);
            if (bytes.Length != (int)length) throw new EndOfStreamException();
            return Encoding.UTF8.GetString(bytes);
        }

        private static string ReadDuckStationFolderSetting(string dataRoot, string keyName)
        {
            if (String.IsNullOrWhiteSpace(dataRoot)) return String.Empty;
            foreach (string settingsFile in new string[] { Path.Combine(dataRoot, "settings.ini"), Path.Combine(dataRoot, "settings", "settings.ini") })
            {
                if (!File.Exists(settingsFile)) continue;
                try
                {
                    bool folders = false;
                    foreach (string raw in File.ReadAllLines(settingsFile))
                    {
                        string line = raw.Trim();
                        if (line.StartsWith("[") && line.EndsWith("]")) { folders = line.Equals("[Folders]", StringComparison.OrdinalIgnoreCase); continue; }
                        if (!folders) continue;
                        int equal = line.IndexOf('=');
                        if (equal <= 0) continue;
                        string key = line.Substring(0, equal).Trim();
                        if (!key.Equals(keyName, StringComparison.OrdinalIgnoreCase) && !key.Equals(keyName + "Directory", StringComparison.OrdinalIgnoreCase)) continue;
                        return line.Substring(equal + 1).Trim().Trim('"');
                    }
                }
                catch { }
            }
            return String.Empty;
        }

        private static string ResolveDuckStationFolder(string dataRoot, string value)
        {
            if (String.IsNullOrWhiteSpace(value)) return String.Empty;
            try { return Path.IsPathRooted(value) ? value : Path.GetFullPath(Path.Combine(dataRoot ?? String.Empty, value)); }
            catch { return value; }
        }

        private static void AddDirectory(List<string> target, string value)
        {
            if (!String.IsNullOrWhiteSpace(value) && Directory.Exists(value) && !target.Contains(value, StringComparer.OrdinalIgnoreCase)) target.Add(value);
        }

        public static List<Ps1StateEntry> FindSaveStates(string dataRoot)
        {
            List<Ps1StateEntry> result = new List<Ps1StateEntry>();
            foreach (string root in new string[] { Path.Combine(dataRoot ?? String.Empty, "savestates"), Path.Combine(dataRoot ?? String.Empty, "states") })
            {
                if (!Directory.Exists(root)) continue;
                try
                {
                    foreach (string file in Directory.GetFiles(root, "*", SearchOption.TopDirectoryOnly))
                    {
                        string extension = Path.GetExtension(file).ToLowerInvariant();
                        if (extension != ".sav" && extension != ".state" && extension != ".savestate") continue;
                        FileInfo info = new FileInfo(file);
                        string name = Path.GetFileNameWithoutExtension(file);
                        string game = System.Text.RegularExpressions.Regex.Replace(name, @"[._-](resume|global|slot)?\d+$", String.Empty, System.Text.RegularExpressions.RegexOptions.IgnoreCase);
                        game = game.Replace('_', ' ').Trim();
                        if (String.IsNullOrWhiteSpace(game)) game = name;
                        result.Add(new Ps1StateEntry { Path = file, Name = name, GameName = game, Modified = info.LastWriteTime, Size = info.Length });
                    }
                }
                catch { }
            }
            return result.OrderByDescending(p => p.Modified).ToList();
        }

        public static List<string> FindMemoryCards(string dataRoot)
        {
            List<string> result = new List<string>();
            foreach (string root in new string[] { GetMemoryCardRoot(dataRoot), Path.Combine(dataRoot ?? String.Empty, "saves") })
            {
                if (!Directory.Exists(root)) continue;
                try
                {
                    foreach (string file in Directory.GetFiles(root, "*", SearchOption.TopDirectoryOnly))
                    {
                        string extension = Path.GetExtension(file).ToLowerInvariant();
                        if ((extension == ".mcd" || extension == ".mcr" || extension == ".mc" || extension == ".gme") && new FileInfo(file).Length >= 131072) result.Add(file);
                    }
                }
                catch { }
            }
            return result.Distinct(StringComparer.OrdinalIgnoreCase).OrderBy(p => p, StringComparer.CurrentCultureIgnoreCase).ToList();
        }

        public static string GetMemoryCardRoot(string dataRoot)
        {
            string root = Path.Combine(dataRoot ?? String.Empty, "memcards");
            if (Directory.Exists(root)) return root;
            string saves = Path.Combine(dataRoot ?? String.Empty, "saves");
            if (Directory.Exists(saves)) return saves;
            return root;
        }

        public static string GetBiosStatus(string dataRoot)
        {
            string root = Path.Combine(dataRoot ?? String.Empty, "bios");
            if (!Directory.Exists(root)) return "BIOS folder is missing";
            try
            {
                string[] files = Directory.GetFiles(root, "*", SearchOption.TopDirectoryOnly).Where(p => { long length = new FileInfo(p).Length; return length == 524288 || length == 262144; }).ToArray();
                return files.Length == 0 ? "No valid 256/512 KB BIOS image found" : files.Length.ToString(CultureInfo.InvariantCulture) + " BIOS image(s) detected";
            }
            catch { return "BIOS status unavailable"; }
        }

        public static BitmapSource LoadBitmap(string path, int width)
        {
            try
            {
                BitmapImage image = new BitmapImage();
                image.BeginInit();
                image.CacheOption = BitmapCacheOption.OnLoad;
                image.CreateOptions = BitmapCreateOptions.PreservePixelFormat;
                if (width > 0) image.DecodePixelWidth = width;
                image.UriSource = new Uri(path);
                image.EndInit();
                image.Freeze();
                return image;
            }
            catch { return null; }
        }

        public static string SafeName(string value)
        {
            if (String.IsNullOrWhiteSpace(value)) return "PlayStation Save";
            char[] invalid = Path.GetInvalidFileNameChars();
            StringBuilder builder = new StringBuilder();
            foreach (char c in value) builder.Append(invalid.Contains(c) ? ' ' : c);
            return String.Join(" ", builder.ToString().Split(new char[] { ' ' }, StringSplitOptions.RemoveEmptyEntries)).Trim();
        }

        public static string FormatBytes(long bytes)
        {
            if (bytes >= 1024 * 1024) return (bytes / 1048576.0).ToString("0.0", CultureInfo.InvariantCulture) + " MB";
            return (bytes / 1024.0).ToString("0", CultureInfo.InvariantCulture) + " KB";
        }

        private static string CleanTitle(string value)
        {
            string title = value.Replace('_', ' ').Trim();
            title = System.Text.RegularExpressions.Regex.Replace(title, @"\s*[\(\[]\s*(Disc|Disk|CD)\s*\d+\s*[\)\]]", String.Empty, System.Text.RegularExpressions.RegexOptions.IgnoreCase);
            title = System.Text.RegularExpressions.Regex.Replace(title, @"\s*-\s*(Disc|Disk|CD)\s*\d+\s*$", String.Empty, System.Text.RegularExpressions.RegexOptions.IgnoreCase);
            return title.Trim();
        }

        private static string NormalizeDiscGroup(string value)
        {
            string normalized = CleanTitle(value).ToLowerInvariant();
            normalized = System.Text.RegularExpressions.Regex.Replace(normalized, "[^a-z0-9]+", String.Empty);
            return normalized;
        }

        private static string SortKey(string value)
        {
            string result = value == null ? String.Empty : value.Trim();
            if (result.StartsWith("The ", StringComparison.OrdinalIgnoreCase)) result = result.Substring(4) + ", The";
            return result;
        }

        private static string FindSerial(string value)
        {
            System.Text.RegularExpressions.Match match = System.Text.RegularExpressions.Regex.Match(value ?? String.Empty, @"([A-Z]{4})[-_ ]?(\d{3})[\. _-]?(\d{2})", System.Text.RegularExpressions.RegexOptions.IgnoreCase);
            if (!match.Success) return String.Empty;
            return match.Groups[1].Value.ToUpperInvariant() + "-" + match.Groups[2].Value + match.Groups[3].Value;
        }
    }

    public static class Ps1MemoryCard
    {
        private const int CardSize = 131072;
        private const int FrameSize = 128;
        private const int BlockSize = 8192;

        public static List<Ps1SaveEntry> ReadSaves(string path)
        {
            List<Ps1SaveEntry> result = new List<Ps1SaveEntry>();
            byte[] card = File.ReadAllBytes(path);
            int offset = DetectOffset(card);
            if (card.Length - offset < CardSize) return result;
            Encoding shiftJis;
            try { shiftJis = Encoding.GetEncoding(932); } catch { shiftJis = Encoding.Default; }
            bool[] consumed = new bool[15];
            for (int slot = 0; slot < 15; slot++)
            {
                int directoryOffset = offset + FrameSize * (slot + 1);
                byte status = card[directoryOffset];
                if ((status & 0xF0) != 0x50 || (status & 0x0F) != 1 || consumed[slot]) continue;
                Ps1SaveEntry save = new Ps1SaveEntry();
                save.FirstSlot = slot;
                save.Blocks = Math.Max(1, ReadInt32(card, directoryOffset + 4) / BlockSize);
                save.FileName = ReadAscii(card, directoryOffset + 0x0A, 20);
                int current = slot;
                for (int block = 0; block < 15 && current >= 0 && current < 15 && !consumed[current]; block++)
                {
                    consumed[current] = true;
                    save.Slots.Add(current);
                    int entryOffset = offset + FrameSize * (current + 1);
                    ushort next = ReadUInt16(card, entryOffset + 8);
                    if (next == 0xFFFF || next >= 15) break;
                    current = next;
                }
                int dataOffset = offset + (slot + 1) * BlockSize;
                save.Title = ReadShiftJis(shiftJis, card, dataOffset + 4, 64);
                save.Icon = DecodeIcon(card, dataOffset);
                if (save.Blocks <= 0) save.Blocks = save.Slots.Count;
                result.Add(save);
            }
            return result;
        }

        public static void CreateFormatted(string path)
        {
            byte[] card = new byte[CardSize];
            card[0] = (byte)'M'; card[1] = (byte)'C';
            for (int frame = 1; frame <= 15; frame++)
            {
                int at = frame * FrameSize;
                card[at] = 0xA0;
                for (int i = 0x0A; i < 0x1E; i++) card[at + i] = 0;
                card[at + 8] = 0xFF; card[at + 9] = 0xFF;
                UpdateChecksum(card, at);
            }
            File.WriteAllBytes(path, card);
        }

        public static void ExportSave(string cardPath, Ps1SaveEntry save, string destination)
        {
            byte[] card = File.ReadAllBytes(cardPath);
            int offset = DetectOffset(card);
            using (FileStream stream = File.Create(destination))
            {
                int firstDirectory = offset + FrameSize * (save.FirstSlot + 1);
                stream.Write(card, firstDirectory, FrameSize);
                foreach (int slot in save.Slots)
                {
                    int data = offset + (slot + 1) * BlockSize;
                    stream.Write(card, data, BlockSize);
                }
            }
        }

        public static void DeleteSave(string cardPath, Ps1SaveEntry save, string backupRoot)
        {
            Backup(cardPath, backupRoot);
            byte[] card = File.ReadAllBytes(cardPath);
            int offset = DetectOffset(card);
            foreach (int slot in save.Slots)
            {
                int entry = offset + FrameSize * (slot + 1);
                card[entry] = (byte)(0xA0 | (card[entry] & 0x0F));
                UpdateChecksum(card, entry);
            }
            File.WriteAllBytes(cardPath, card);
        }

        public static void CopySave(string sourcePath, Ps1SaveEntry save, string targetPath, string backupRoot)
        {
            Backup(targetPath, backupRoot);
            byte[] source = File.ReadAllBytes(sourcePath);
            byte[] target = File.ReadAllBytes(targetPath);
            int sourceOffset = DetectOffset(source);
            int targetOffset = DetectOffset(target);
            List<int> free = new List<int>();
            for (int slot = 0; slot < 15; slot++)
            {
                byte status = target[targetOffset + FrameSize * (slot + 1)];
                if ((status & 0xF0) != 0x50) free.Add(slot);
            }
            if (free.Count < save.Slots.Count) throw new InvalidOperationException("The destination card does not have enough free blocks.");
            List<int> assigned = free.Take(save.Slots.Count).ToList();
            for (int index = 0; index < save.Slots.Count; index++)
            {
                int sourceSlot = save.Slots[index];
                int targetSlot = assigned[index];
                Buffer.BlockCopy(source, sourceOffset + (sourceSlot + 1) * BlockSize, target, targetOffset + (targetSlot + 1) * BlockSize, BlockSize);
                int sourceEntry = sourceOffset + FrameSize * (sourceSlot + 1);
                int targetEntry = targetOffset + FrameSize * (targetSlot + 1);
                Buffer.BlockCopy(source, sourceEntry, target, targetEntry, FrameSize);
                target[targetEntry] = (byte)(index == 0 ? 0x51 : (index == save.Slots.Count - 1 ? 0x53 : 0x52));
                ushort next = index == save.Slots.Count - 1 ? (ushort)0xFFFF : (ushort)assigned[index + 1];
                target[targetEntry + 8] = (byte)(next & 0xFF);
                target[targetEntry + 9] = (byte)(next >> 8);
                UpdateChecksum(target, targetEntry);
            }
            File.WriteAllBytes(targetPath, target);
        }

        private static void Backup(string path, string root)
        {
            Directory.CreateDirectory(root);
            string destination = Path.Combine(root, Path.GetFileNameWithoutExtension(path) + "-" + DateTime.Now.ToString("yyyyMMdd-HHmmss") + Path.GetExtension(path));
            File.Copy(path, destination, true);
        }

        private static int DetectOffset(byte[] card)
        {
            if (card.Length >= CardSize + 3904 && card[3904] == (byte)'M' && card[3905] == (byte)'C') return 3904;
            if (card.Length >= CardSize + 64 && card[64] == (byte)'M' && card[65] == (byte)'C') return 64;
            return 0;
        }

        private static BitmapSource DecodeIcon(byte[] card, int dataOffset)
        {
            try
            {
                int paletteOffset = dataOffset + 0x60;
                int iconOffset = dataOffset + 0x80;
                if (iconOffset + 128 > card.Length || paletteOffset + 32 > card.Length) return null;
                uint[] palette = new uint[16];
                for (int i = 0; i < 16; i++)
                {
                    ushort color = ReadUInt16(card, paletteOffset + i * 2);
                    byte r = (byte)(((color >> 0) & 31) * 255 / 31);
                    byte g = (byte)(((color >> 5) & 31) * 255 / 31);
                    byte b = (byte)(((color >> 10) & 31) * 255 / 31);
                    byte a = (byte)((color & 0x8000) != 0 || i != 0 ? 255 : 0);
                    palette[i] = (uint)(b | (g << 8) | (r << 16) | (a << 24));
                }
                byte[] pixels = new byte[16 * 16 * 4];
                for (int pixel = 0; pixel < 256; pixel++)
                {
                    byte packed = card[iconOffset + pixel / 2];
                    int index = (pixel & 1) == 0 ? packed & 0x0F : packed >> 4;
                    uint color = palette[index];
                    int destination = pixel * 4;
                    pixels[destination] = (byte)(color & 0xFF);
                    pixels[destination + 1] = (byte)((color >> 8) & 0xFF);
                    pixels[destination + 2] = (byte)((color >> 16) & 0xFF);
                    pixels[destination + 3] = (byte)((color >> 24) & 0xFF);
                }
                BitmapSource bitmap = BitmapSource.Create(16, 16, 96, 96, PixelFormats.Bgra32, null, pixels, 64);
                bitmap.Freeze();
                return bitmap;
            }
            catch { return null; }
        }

        private static string ReadShiftJis(Encoding encoding, byte[] bytes, int offset, int length)
        {
            if (offset < 0 || offset >= bytes.Length) return String.Empty;
            int count = Math.Min(length, bytes.Length - offset);
            string value = encoding.GetString(bytes, offset, count);
            int zero = value.IndexOf('\0');
            if (zero >= 0) value = value.Substring(0, zero);
            return value.Replace('\r', ' ').Replace('\n', ' ').Trim();
        }

        private static string ReadAscii(byte[] bytes, int offset, int length)
        {
            string value = Encoding.ASCII.GetString(bytes, offset, Math.Min(length, bytes.Length - offset));
            int zero = value.IndexOf('\0');
            if (zero >= 0) value = value.Substring(0, zero);
            return value.Trim();
        }

        private static int ReadInt32(byte[] bytes, int offset)
        {
            return bytes[offset] | (bytes[offset + 1] << 8) | (bytes[offset + 2] << 16) | (bytes[offset + 3] << 24);
        }

        private static ushort ReadUInt16(byte[] bytes, int offset)
        {
            return (ushort)(bytes[offset] | (bytes[offset + 1] << 8));
        }

        private static void UpdateChecksum(byte[] card, int frameOffset)
        {
            byte checksum = 0;
            for (int i = 0; i < 127; i++) checksum ^= card[frameOffset + i];
            card[frameOffset + 127] = checksum;
        }
    }
}
