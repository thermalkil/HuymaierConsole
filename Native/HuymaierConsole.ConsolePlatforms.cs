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
using System.Windows.Media.Animation;
using System.Windows.Media.Imaging;
using System.Windows.Media.Media3D;

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
        public string emulatorDataPath { get; set; }
        public List<string> gameFolders { get; set; }
        public bool startupEnabled { get; set; }
        public double startupVolume { get; set; }
        public bool ambienceEnabled { get; set; }
        public string ambiencePath { get; set; }
        public double ambienceVolume { get; set; }
        public double soundVolume { get; set; }
        public string dashboardStyle { get; set; }
        public bool fullscreen { get; set; }
        public double gameCubeScale { get; set; }

        public ConsolePlatformSettings()
        {
            schemaVersion = 7;
            emulatorPath = String.Empty;
            fallbackEmulatorPath = String.Empty;
            emulatorDataPath = String.Empty;
            gameFolders = new List<string>();
            startupEnabled = true;
            startupVolume = 1.0;
            ambienceEnabled = false;
            ambiencePath = String.Empty;
            ambienceVolume = 0.75;
            soundVolume = 1.0;
            dashboardStyle = String.Empty;
            fullscreen = true;
            gameCubeScale = 0.66;
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
            if (result.emulatorDataPath == null) result.emulatorDataPath = String.Empty;
            result.gameFolders = result.gameFolders.Where(delegate(string p) { return !String.IsNullOrWhiteSpace(p); })
                .Select(delegate(string p) { try { return Path.GetFullPath(Environment.ExpandEnvironmentVariables(p)); } catch { return p; } })
                .Distinct(StringComparer.OrdinalIgnoreCase).ToList();
            if (String.IsNullOrWhiteSpace(result.dashboardStyle)) result.dashboardStyle = definition.DefaultDashboardStyle;
            if (String.IsNullOrWhiteSpace(result.emulatorPath)) result.emulatorPath = definition.FindPrimaryEmulator();
            if (String.IsNullOrWhiteSpace(result.fallbackEmulatorPath)) result.fallbackEmulatorPath = definition.FindFallbackEmulator(result.emulatorPath);
            result.startupVolume = Clamp(result.startupVolume);
            result.ambienceVolume = Clamp(result.ambienceVolume);
            result.soundVolume = Clamp(result.soundVolume);
            if (loadedSchema < 7 || Double.IsNaN(result.gameCubeScale) || result.gameCubeScale < 0.45 || result.gameCubeScale > 1.05) result.gameCubeScale = 0.66;
            result.gameCubeScale = Math.Max(0.50, Math.Min(1.00, result.gameCubeScale));
            result.schemaVersion = 7;
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
            else if (key == "ATARILYNX")
            {
                d.DisplayName="Atari Lynx";d.Subtitle="HANDHELD COLOR ENTERTAINMENT SYSTEM";d.Shell="AtariLynx";d.PrimaryBackend="Mednafen";d.FallbackBackend="ares";d.PrimaryExecutableNames=new string[]{"mednafen.exe"};d.FallbackExecutableNames=new string[]{"ares.exe"};d.GameExtensions=new string[]{".lnx",".lyx",".o",".zip"};d.ColorA=Color.FromRgb(22,23,24);d.ColorB=Color.FromRgb(4,5,6);d.Accent=Color.FromRgb(226,82,44);
            }
            else if (key == "NEOGEO")
            {
                d.DisplayName="Neo Geo";d.Subtitle="ADVANCED ENTERTAINMENT SYSTEM";d.Shell="NeoGeo";d.PrimaryBackend="FinalBurn Neo";d.FallbackBackend="MAME";d.PrimaryExecutableNames=new string[]{"fbneo.exe","FinalBurnNeo.exe"};d.FallbackExecutableNames=new string[]{"mame.exe"};d.GameExtensions=new string[]{".zip",".7z",".neo"};d.ColorA=Color.FromRgb(14,15,16);d.ColorB=Color.FromRgb(3,4,5);d.Accent=Color.FromRgb(215,31,39);
            }
            else if (key == "NGPC")
            {
                d.DisplayName="Neo Geo Pocket Color";d.Subtitle="COLOR";d.Shell="NGPC";d.PrimaryBackend="Mednafen";d.FallbackBackend="ares";d.PrimaryExecutableNames=new string[]{"mednafen.exe"};d.FallbackExecutableNames=new string[]{"ares.exe"};d.GameExtensions=new string[]{".ngc",".ngp",".npc",".zip"};d.ColorA=Color.FromRgb(84,87,89);d.ColorB=Color.FromRgb(29,31,32);d.Accent=Color.FromRgb(78,183,182);
            }
            else if (key == "JAGUAR")
            {
                d.DisplayName="Atari Jaguar";d.Subtitle="64-BIT INTERACTIVE MULTIMEDIA SYSTEM";d.Shell="Jaguar";d.PrimaryBackend="BigPEmu";d.FallbackBackend="Virtual Jaguar libretro";d.PrimaryExecutableNames=new string[]{"BigPEmu.exe","bigpemu.exe"};d.FallbackExecutableNames=new string[]{"retroarch.exe"};d.GameExtensions=new string[]{".j64",".jag",".rom",".bin",".abs",".cof",".zip"};d.ColorA=Color.FromRgb(17,18,19);d.ColorB=Color.FromRgb(4,5,5);d.Accent=Color.FromRgb(209,35,42);
            }
            else if (key == "PRIMEHACK")
            {
                d.DisplayName="Metroid PrimeHack";d.Subtitle="PRIME VISOR";d.Shell="PrimeHack";d.PrimaryBackend="PrimeHack";d.FallbackBackend="Dolphin";d.PrimaryExecutableNames=new string[]{"PrimeHack.exe","DolphinQt2.exe","Dolphin.exe"};d.FallbackExecutableNames=new string[]{"Dolphin.exe","DolphinQt2.exe"};d.GameExtensions=new string[]{".iso",".rvz",".wbfs",".gcm",".ciso"};d.ColorA=Color.FromRgb(5,29,31);d.ColorB=Color.FromRgb(2,7,9);d.Accent=Color.FromRgb(63,225,211);
            }
            else if (key == "ATARI2600")
            {
                d.DisplayName="Atari 2600";d.Subtitle="Video Computer System";d.Shell="Atari2600";d.PrimaryBackend="Stella";d.FallbackBackend="ares";d.PrimaryExecutableNames=new string[]{"Stella.exe","stella.exe"};d.FallbackExecutableNames=new string[]{"ares.exe"};d.GameExtensions=new string[]{".a26",".bin",".rom",".zip"};d.ColorA=Color.FromRgb(25,21,17);d.ColorB=Color.FromRgb(76,45,24);d.Accent=Color.FromRgb(220,149,57);
            }
            else if (key == "NES")
            {
                d.DisplayName="Nintendo Entertainment System";d.Subtitle="Control Deck";d.Shell="NES";d.PrimaryBackend="Mesen Community Edition";d.FallbackBackend="ares";d.PrimaryExecutableNames=new string[]{"Mesen.exe","Mesen2.exe"};d.FallbackExecutableNames=new string[]{"ares.exe"};d.GameExtensions=new string[]{".nes",".fds",".unf",".unif",".zip"};d.ColorA=Color.FromRgb(205,204,199);d.ColorB=Color.FromRgb(102,103,100);d.Accent=Color.FromRgb(194,35,42);
            }
            else if (key == "SNES")
            {
                d.DisplayName="Super Nintendo Entertainment System";d.Subtitle="Super NES Control Deck";d.Shell="SNES";d.PrimaryBackend="Mesen Community Edition";d.FallbackBackend="ares";d.PrimaryExecutableNames=new string[]{"Mesen.exe","Mesen2.exe"};d.FallbackExecutableNames=new string[]{"ares.exe"};d.GameExtensions=new string[]{".sfc",".smc",".fig",".swc",".zip"};d.ColorA=Color.FromRgb(208,207,205);d.ColorB=Color.FromRgb(116,113,123);d.Accent=Color.FromRgb(103,74,151);
            }
            else if (key == "GAMEBOY")
            {
                d.DisplayName="Nintendo Game Boy";d.Subtitle="DOT MATRIX WITH STEREO SOUND";d.Shell="GameBoy";d.PrimaryBackend="SameBoy";d.FallbackBackend="Mesen Community Edition";d.PrimaryExecutableNames=new string[]{"sameboy.exe","SameBoy.exe"};d.FallbackExecutableNames=new string[]{"Mesen.exe","Mesen2.exe"};d.GameExtensions=new string[]{".gb",".sgb",".zip"};d.ColorA=Color.FromRgb(197,198,189);d.ColorB=Color.FromRgb(145,147,137);d.Accent=Color.FromRgb(117,44,111);
            }
            else if (key == "GBC")
            {
                d.DisplayName="Nintendo Game Boy Color";d.Subtitle="COLOR";d.Shell="GBC";d.PrimaryBackend="SameBoy";d.FallbackBackend="Mesen Community Edition";d.PrimaryExecutableNames=new string[]{"sameboy.exe","SameBoy.exe"};d.FallbackExecutableNames=new string[]{"Mesen.exe","Mesen2.exe"};d.GameExtensions=new string[]{".gbc",".gb",".zip"};d.ColorA=Color.FromRgb(80,36,122);d.ColorB=Color.FromRgb(37,20,66);d.Accent=Color.FromRgb(244,73,142);
            }
            else if (key == "GBA")
            {
                d.DisplayName="Nintendo Game Boy Advance";d.Subtitle="ADVANCE";d.Shell="GBA";d.PrimaryBackend="mGBA";d.FallbackBackend="Mesen Community Edition";d.PrimaryExecutableNames=new string[]{"mGBA.exe","mgba.exe","mGBA-qt.exe"};d.FallbackExecutableNames=new string[]{"Mesen.exe","Mesen2.exe"};d.GameExtensions=new string[]{".gba",".agb",".zip"};d.ColorA=Color.FromRgb(79,55,145);d.ColorB=Color.FromRgb(38,26,83);d.Accent=Color.FromRgb(168,145,255);
            }
            else if (key == "GENESIS")
            {
                d.DisplayName="Sega Genesis";d.Subtitle="16-BIT";d.Shell="Genesis";d.PrimaryBackend="ares";d.FallbackBackend="BlastEm";d.PrimaryExecutableNames=new string[]{"ares.exe"};d.FallbackExecutableNames=new string[]{"blastem.exe","BlastEm.exe"};d.GameExtensions=new string[]{".md",".gen",".bin",".smd",".zip"};d.ColorA=Color.FromRgb(5,7,9);d.ColorB=Color.FromRgb(29,31,34);d.Accent=Color.FromRgb(191,34,45);
            }
            else if (key == "SEGACD")
            {
                d.DisplayName="Sega CD";d.Subtitle="CD-ROM SYSTEM";d.Shell="SegaCD";d.PrimaryBackend="ares";d.FallbackBackend="Mednafen";d.PrimaryExecutableNames=new string[]{"ares.exe"};d.FallbackExecutableNames=new string[]{"mednafen.exe"};d.GameExtensions=new string[]{".cue",".chd",".iso",".bin"};d.ColorA=Color.FromRgb(6,8,11);d.ColorB=Color.FromRgb(31,35,40);d.Accent=Color.FromRgb(80,147,214);
            }
            else if (key == "SEGA32X")
            {
                d.DisplayName="Sega 32X";d.Subtitle="32X";d.Shell="Sega32X";d.PrimaryBackend="ares";d.FallbackBackend="PicoDrive libretro";d.PrimaryExecutableNames=new string[]{"ares.exe"};d.FallbackExecutableNames=new string[]{"retroarch.exe"};d.GameExtensions=new string[]{".32x",".bin",".md",".zip"};d.ColorA=Color.FromRgb(4,5,6);d.ColorB=Color.FromRgb(27,29,31);d.Accent=Color.FromRgb(224,60,48);
            }
            else if (key == "GAMEGEAR")
            {
                d.DisplayName="Sega Game Gear";d.Subtitle="GAME GEAR";d.Shell="GameGear";d.PrimaryBackend="Mesen Community Edition";d.FallbackBackend="ares";d.PrimaryExecutableNames=new string[]{"Mesen.exe","Mesen2.exe"};d.FallbackExecutableNames=new string[]{"ares.exe"};d.GameExtensions=new string[]{".gg",".zip"};d.ColorA=Color.FromRgb(12,14,17);d.ColorB=Color.FromRgb(34,39,45);d.Accent=Color.FromRgb(47,137,205);
            }
            else if (key == "MASTERSYSTEM")
            {
                d.DisplayName="Sega Master System";d.Subtitle="MASTER SYSTEM";d.Shell="MasterSystem";d.PrimaryBackend="Mesen Community Edition";d.FallbackBackend="ares";d.PrimaryExecutableNames=new string[]{"Mesen.exe","Mesen2.exe"};d.FallbackExecutableNames=new string[]{"ares.exe"};d.GameExtensions=new string[]{".sms",".sg",".zip"};d.ColorA=Color.FromRgb(8,9,10);d.ColorB=Color.FromRgb(38,39,40);d.Accent=Color.FromRgb(206,31,39);
            }
            else if (key == "TURBOGRAFX16")
            {
                d.DisplayName="TurboGrafx-16";d.Subtitle="ENTERTAINMENT SUPER SYSTEM";d.Shell="TurboGrafx16";d.PrimaryBackend="Mednafen";d.FallbackBackend="Mesen Community Edition";d.PrimaryExecutableNames=new string[]{"mednafen.exe"};d.FallbackExecutableNames=new string[]{"Mesen.exe","Mesen2.exe"};d.GameExtensions=new string[]{".pce",".sgx",".cue",".chd",".zip"};d.ColorA=Color.FromRgb(224,223,218);d.ColorB=Color.FromRgb(178,177,171);d.Accent=Color.FromRgb(193,34,42);
            }
            else if (key == "3DS")
            {
                d.DisplayName = "Nintendo 3DS"; d.Subtitle = "HOME Menu"; d.Shell = "3DS";
                d.PrimaryBackend = "Azahar"; d.FallbackBackend = "Azahar Nightly";
                d.PrimaryExecutableNames = new string[] { "azahar.exe", "Azahar.exe" };
                d.FallbackExecutableNames = new string[] { "azahar.exe", "Azahar.exe" };
                d.GameExtensions = new string[] { ".3ds", ".cci", ".cxi", ".app", ".zcci", ".zcxi" };
                d.ColorA = Color.FromRgb(228, 232, 237); d.ColorB = Color.FromRgb(249, 250, 251); d.Accent = Color.FromRgb(72, 148, 203);
            }
            else if (key == "NDS")
            {
                d.DisplayName = "Nintendo DS"; d.Subtitle = "DS Menu"; d.Shell = "NDS";
                d.PrimaryBackend = "melonDS"; d.FallbackBackend = "melonDS Development";
                d.PrimaryExecutableNames = new string[] { "melonDS.exe" }; d.FallbackExecutableNames = new string[] { "melonDS.exe" };
                d.GameExtensions = new string[] { ".nds", ".srl", ".zip" };
                d.ColorA = Color.FromRgb(233, 241, 248); d.ColorB = Color.FromRgb(250, 252, 254); d.Accent = Color.FromRgb(70, 145, 202);
            }
            else if (key == "DSI")
            {
                d.DisplayName = "Nintendo DSi"; d.Subtitle = "DSi Menu"; d.Shell = "DSI";
                d.PrimaryBackend = "melonDS"; d.FallbackBackend = "melonDS Development";
                d.PrimaryExecutableNames = new string[] { "melonDS.exe" }; d.FallbackExecutableNames = new string[] { "melonDS.exe" };
                d.GameExtensions = new string[] { ".nds", ".srl", ".app" };
                d.ColorA = Color.FromRgb(243, 245, 247); d.ColorB = Color.FromRgb(255, 255, 255); d.Accent = Color.FromRgb(67, 181, 222);
            }
            else if (key == "DREAMCAST")
            {
                d.DisplayName = "Sega Dreamcast"; d.Subtitle = "Dreamcast Main Menu"; d.Shell = "Dreamcast";
                d.PrimaryBackend = "Flycast"; d.FallbackBackend = "Flycast Development";
                d.PrimaryExecutableNames = new string[] { "flycast.exe", "Flycast.exe" }; d.FallbackExecutableNames = new string[] { "flycast.exe", "Flycast.exe" };
                d.GameExtensions = new string[] { ".gdi", ".cdi", ".chd", ".cue" };
                d.ColorA = Color.FromRgb(190, 220, 246); d.ColorB = Color.FromRgb(58, 124, 195); d.Accent = Color.FromRgb(240, 104, 45);
            }
            else if (key == "SATURN")
            {
                d.DisplayName = "Sega Saturn"; d.Subtitle = "Saturn System"; d.Shell = "Saturn";
                d.PrimaryBackend = "Mednafen"; d.FallbackBackend = "Kronos";
                d.PrimaryExecutableNames = new string[] { "mednafen.exe" }; d.FallbackExecutableNames = new string[] { "kronos.exe", "Kronos.exe" };
                d.GameExtensions = new string[] { ".cue", ".chd", ".ccd", ".mds", ".iso" };
                d.ColorA = Color.FromRgb(7, 21, 65); d.ColorB = Color.FromRgb(15, 102, 159); d.Accent = Color.FromRgb(249, 64, 120);
            }
            else if (key == "PSP")
            {
                d.DisplayName = "PlayStation Portable"; d.Subtitle = "XMB"; d.Shell = "PSP";
                d.PrimaryBackend = "PPSSPP"; d.FallbackBackend = "PPSSPP Development";
                d.PrimaryExecutableNames = new string[] { "PPSSPPWindows64.exe", "PPSSPPWindows.exe", "PPSSPPQt.exe" };
                d.FallbackExecutableNames = new string[] { "PPSSPPWindows64.exe", "PPSSPPWindows.exe", "PPSSPPQt.exe" };
                d.GameExtensions = new string[] { ".iso", ".cso", ".pbp", ".elf" };
                d.ColorA = Color.FromRgb(20, 91, 166); d.ColorB = Color.FromRgb(1, 28, 79); d.Accent = Color.FromRgb(102, 196, 255);
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
            else if (key == "XBOX360")
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

    internal sealed class GameCubeSaveEntry
    {
        internal string Name;
        internal string GameCode;
        internal int Blocks;
        internal DateTime Modified;
        internal string CardPath;
    }

    internal sealed class GameCubeMemoryCardInfo
    {
        internal string Slot;
        internal string Path;
        internal int TotalBlocks;
        internal int FreeBlocks;
        internal List<GameCubeSaveEntry> Saves = new List<GameCubeSaveEntry>();
    }

    internal sealed class WiiSaveEntry
    {
        internal string Name;
        internal string TitleId;
        internal string Path;
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
        private bool consoleArtworkScanRunning;
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
        private int n64LibraryIndex;
        private int n64Zone;
        private int n64UtilityIndex;
        private int gameCubePreviousPage;
        private int pspCategoryIndex;
        private int pspItemIndex;
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
            consoleArtworkScanRunning = false;
            wiiMenuPage = 0;
            wiiUMenuPage = 0;
            switchZone = 0;
            switchSoftwareIndex = 0;
            switchSystemIndex = 0;
            switchSoftwareActionCount = 0;
            switchSystemActionStart = 0;
            chromeNavigationActive = definition.Shell == "Xbox" || (definition.Shell == "Xbox360" && String.Equals(settings.dashboardStyle, "Metro", StringComparison.OrdinalIgnoreCase));
            shellSelectedGame = null;
            n64LibraryIndex = 0;
            n64Zone = 0;
            n64UtilityIndex = 0;
            gameCubePreviousPage = -1;
            pspCategoryIndex = 0;
            pspItemIndex = 0;
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
            if (definition.Shell == "GameCube") helpText = "D-Pad  Menu     LB / RB  Letter     A  Select     B  Back     GUIDE  Game Bar";
            else if (definition.Shell == "Wii") helpText = "D-Pad  Navigate     LB / RB  Letter     A  Select     B  Back     GUIDE  Game Bar";
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
            return definition.Shell == "Wii" || definition.Shell == "WiiU" || definition.Shell == "3DS" || definition.Shell == "NDS" || definition.Shell == "DSI" || definition.Shell == "Dreamcast";
        }

        private bool IsXboxFamily() { return definition.Shell == "Xbox" || definition.Shell == "Xbox360"; }
        private bool IsBlades() { return definition.Shell == "Xbox360" && String.Equals(settings.dashboardStyle, "Blades", StringComparison.OrdinalIgnoreCase); }
        private bool IsMetro() { return definition.Shell == "Xbox360" && String.Equals(settings.dashboardStyle, "Metro", StringComparison.OrdinalIgnoreCase); }
        private bool IsGamePage() { return definition.Shell == "Xbox360" ? (IsBlades() ? page == 1 : page == 2) : page == 0; }
        private int GetPageCount() { if (definition.Shell == "GameCube") return 4; return definition.Shell == "Xbox" ? 4 : (definition.Shell == "Xbox360" ? (IsBlades() ? 4 : 7) : 3); }
        private int GetDefaultPageIndex() { return definition.Shell == "Xbox360" && String.Equals(settings == null ? definition.DefaultDashboardStyle : settings.dashboardStyle, "Blades", StringComparison.OrdinalIgnoreCase) ? 1 : 0; }
        private int GetSettingsPageIndex() { if (definition.Shell == "GameCube") return 3; return definition.Shell == "Xbox" ? 3 : (definition.Shell == "Xbox360" ? (IsBlades() ? 3 : 6) : 2); }
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
            if (definition.Shell == "PSP")
            {
                LinearGradientBrush psp = new LinearGradientBrush(); psp.StartPoint = new Point(0,0); psp.EndPoint = new Point(1,1);
                psp.GradientStops.Add(new GradientStop(Color.FromRgb(17,116,205),0)); psp.GradientStops.Add(new GradientStop(Color.FromRgb(2,48,119),0.58)); psp.GradientStops.Add(new GradientStop(Color.FromRgb(0,15,56),1)); return psp;
            }
            if (definition.Shell == "Saturn")
            {
                RadialGradientBrush saturn = new RadialGradientBrush(); saturn.Center = new Point(0.5,0.48); saturn.GradientOrigin = new Point(0.5,0.48);
                saturn.GradientStops.Add(new GradientStop(Color.FromRgb(31,126,178),0)); saturn.GradientStops.Add(new GradientStop(Color.FromRgb(7,35,89),0.55)); saturn.GradientStops.Add(new GradientStop(Color.FromRgb(2,8,29),1)); return saturn;
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
            AddNav("play game", 0); AddNav("memory", 1); AddNav("music", 2); AddNav("settings", 3);
            UpdateNavigation();
        }

        private void BuildXbox360Chrome()
        {
            chrome.RowDefinitions.Clear(); chrome.ColumnDefinitions.Clear();
            navButtons.Clear(); navigation.Children.Clear();
            if (IsBlades())
            {
                string[] labels = new string[] { "home", "games", "media", "system" };
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
                AddNav("home", 0); AddNav("profile", 1); AddNav("games", 2); AddNav("video", 3); AddNav("music", 4); AddNav("apps", 5); AddNav("settings", 6);
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
            QueueConsoleArtworkRefresh();
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
            if (backendValueEditorActive)
            {
                ProcessBackendValueEditorCommand(command);
                return;
            }

            // Shoulder buttons never change console sections/pages.  The only native-console
            // exception is a deliberate large-library accelerator requested for N64/GameCube/Wii:
            // LB/RB jumps to the previous/next populated first-letter group.
            if (command == XmbInputCommand.LeftShoulder || command == XmbInputCommand.RightShoulder)
            {
                if (TryProcessLibraryLetterJump(command)) return;
                return;
            }

            if (definition.Shell == "N64" && IsRootConsoleSurface()) { ProcessN64MenuCommand(command); return; }
            if (definition.Shell == "PSP" && IsRootConsoleSurface()) { ProcessPspXmbCommand(command); return; }
            if (IsGameCubeHub()) { ProcessGameCubeHubCommand(command); return; }
            if (IsXboxRoot()) { ProcessXboxRootCommand(command); return; }
            if (definition.Shell == "Switch" && IsRootConsoleSurface()) { ProcessSwitchHomeCommand(command); return; }
            if (definition.Shell == "Xbox360" && IsMetro() && IsRootConsoleSurface() && ProcessMetroNavigationCommand(command)) return;
            if (definition.Shell == "Xbox360" && IsBlades() && IsRootConsoleSurface() && (command == XmbInputCommand.Left || command == XmbInputCommand.Right))
            {
                SwitchPage(command == XmbInputCommand.Left ? -1 : 1); return;
            }
            if (definition.Shell == "Wii" && IsRootConsoleSurface()) { ProcessWiiMenuCommand(command); return; }
            if (definition.Shell == "WiiU" && IsRootConsoleSurface() && ProcessWiiUPageEdge(command)) return;

            if (command == XmbInputCommand.Back)
            {
                PlayEffect("Back.wav");
                if (!String.IsNullOrWhiteSpace(dashboardSubpage))
                {
                    if (dashboardSubpage == "backend-setting-detail") { dashboardSubpage = "backend-settings-list"; selected = 0; RenderPage(); return; }
                    if (dashboardSubpage == "backend-settings-list") { dashboardSubpage = "backend-settings"; selectedBackendSetting = null; selected = 0; RenderPage(); return; }
                    if (dashboardSubpage == "backend-settings") { dashboardSubpage = "settings"; selectedBackendSetting = null; selected = 0; RenderPage(); return; }
                    if (dashboardSubpage == "wii-start") { dashboardSubpage = String.Empty; shellSelectedGame = null; selected = 0; RenderPage(); return; }
                    if (dashboardSubpage == "wii-data" || dashboardSubpage == "wii-settings") { dashboardSubpage = "wii-options"; selected = 0; RenderPage(); return; }
                    if (dashboardSubpage == "wii-options") { dashboardSubpage = String.Empty; selected = 0; RenderPage(); return; }
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
            if (next != page)
            {
                gameCubePreviousPage = page;
                page = next;
                PlayEffect("Navigate.wav");
                RenderPage();
            }
        }

        private void ProcessN64MenuCommand(XmbInputCommand command)
        {
            if (command == XmbInputCommand.Back) { PlayEffect("Back.wav"); Close(); return; }
            if (n64Zone == 0)
            {
                if (command == XmbInputCommand.Left || command == XmbInputCommand.Right)
                {
                    if (games.Count > 0)
                    {
                        int delta = command == XmbInputCommand.Left ? -1 : 1;
                        n64LibraryIndex = Math.Max(0, Math.Min(games.Count - 1, n64LibraryIndex + delta));
                        PlayEffect("Navigate.wav"); RenderPage();
                    }
                    return;
                }
                if (command == XmbInputCommand.Down) { n64Zone = 1; PlayEffect("Navigate.wav"); RenderPage(); return; }
                if (command == XmbInputCommand.Confirm)
                {
                    PlayEffect("Confirm.wav");
                    if (games.Count > 0) LaunchGame(games[Math.Max(0, Math.Min(games.Count - 1, n64LibraryIndex))], false);
                    else { dashboardSubpage = "n64-settings"; page = 2; selected = 0; RenderPage(); }
                }
                return;
            }
            if (command == XmbInputCommand.Up) { n64Zone = 0; PlayEffect("Navigate.wav"); RenderPage(); return; }
            if (command == XmbInputCommand.Left || command == XmbInputCommand.Right)
            {
                n64UtilityIndex = command == XmbInputCommand.Left ? 0 : 1; PlayEffect("Navigate.wav"); RenderPage(); return;
            }
            if (command == XmbInputCommand.Confirm)
            {
                PlayEffect("Confirm.wav");
                if (n64UtilityIndex == 0) { dashboardSubpage = "n64-pak"; page = 1; selected = 0; RenderPage(); }
                else { dashboardSubpage = "n64-settings"; page = 2; selected = 0; RenderPage(); }
            }
        }

        private void ProcessWiiMenuCommand(XmbInputCommand command)
        {
            if (command == XmbInputCommand.Back) { PlayEffect("Back.wav"); Close(); return; }
            int channelCount = Math.Min(12, Math.Max(1, games.Count - wiiMenuPage * 12));
            int systemStart = Math.Min(actions.Count, channelCount);
            if (selected < systemStart)
            {
                int lastWiiPage = Math.Max(0, GetWiiMenuPageCount() - 1);
                if (command == XmbInputCommand.Left && selected % 4 == 0 && wiiMenuPage > 0) { wiiMenuPage--; selected = 0; PlayEffect("Tab.wav"); RenderPage(); return; }
                if (command == XmbInputCommand.Right && selected % 4 == 3 && wiiMenuPage < lastWiiPage) { wiiMenuPage++; selected = 0; PlayEffect("Tab.wav"); RenderPage(); return; }
                if (command == XmbInputCommand.Down && selected + 4 >= systemStart) { selected = systemStart; PlayEffect("Navigate.wav"); UpdateActionVisuals(); return; }
                int next = selected;
                if (command == XmbInputCommand.Left) next--;
                else if (command == XmbInputCommand.Right) next++;
                else if (command == XmbInputCommand.Up) next -= 4;
                else if (command == XmbInputCommand.Down) next += 4;
                else if (command == XmbInputCommand.Confirm) { if (selected < actions.Count) { PlayEffect("Confirm.wav"); actions[selected].Invoke(); } return; }
                else return;
                selected = Math.Max(0, Math.Min(systemStart - 1, next)); PlayEffect("Navigate.wav"); UpdateActionVisuals(); return;
            }
            if (command == XmbInputCommand.Up) { selected = Math.Max(0, systemStart - 1); PlayEffect("Navigate.wav"); UpdateActionVisuals(); return; }
            if (command == XmbInputCommand.Left || command == XmbInputCommand.Right)
            {
                int next = selected + (command == XmbInputCommand.Left ? -1 : 1);
                selected = Math.Max(systemStart, Math.Min(actions.Count - 1, next)); PlayEffect("Navigate.wav"); UpdateActionVisuals(); return;
            }
            if (command == XmbInputCommand.Confirm && selected < actions.Count) { PlayEffect("Confirm.wav"); actions[selected].Invoke(); }
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
            if (definition.Shell == "N64" && !IsRootConsoleSurface()) { if (page == 1) RenderN64ControllerPak(FindSaveRoots()); else RenderN64Options(); UpdateActionVisuals(); return; }
            if (definition.Shell == "WiiU" && !IsRootConsoleSurface()) { if (page == 1) RenderWiiUDataManagement(FindSaveRoots()); else RenderWiiUSettings(); UpdateActionVisuals(); return; }
            if (definition.Shell == "Switch" && !IsRootConsoleSurface()) { if (dashboardSubpage == "switch-all") RenderSwitchAllSoftware(); else if (dashboardSubpage == "switch-data") RenderSwitchDataManagement(FindSaveRoots()); else RenderSwitchSettings(); UpdateActionVisuals(); return; }
            if (definition.Shell == "GameCube")
            {
                if (IsRootConsoleSurface()) RenderGameCubeHub();
                else if (page == 0) RenderGameCubeGamePlay(); else if (page == 1) RenderGameCubeCalendar(); else if (page == 2) RenderGameCubeMemoryCards(FindSaveRoots()); else RenderGameCubeOptions();
                UpdateActionVisuals(); return;
            }
            if (definition.Shell == "Wii")
            {
                if (dashboardSubpage == "wii-start") RenderWiiChannelStart();
                else if (dashboardSubpage == "wii-options") RenderWiiOptions();
                else if (dashboardSubpage == "wii-data") RenderWiiDataManagement(FindSaveRoots());
                else if (dashboardSubpage == "wii-settings") RenderWiiSettings();
                else RenderWiiMenuAuthentic();
                UpdateActionVisuals(); return;
            }
            if (definition.Shell == "WiiU" && IsRootConsoleSurface()) { RenderWiiUMenuAuthentic(); UpdateActionVisuals(); return; }
            if (definition.Shell == "Switch" && IsRootConsoleSurface()) { RenderSwitchHomeAuthentic(); UpdateActionVisuals(); return; }
            if (definition.Shell == "N64" && IsRootConsoleSurface()) { RenderN64GamePakLauncher(); return; }
            if (IsWave2Shell()) { if (IsRootConsoleSurface()) RenderWave2Root(); else RenderWave2Subpage(); UpdateActionVisuals(); return; }
            if (IsWave3Shell()) { if (IsRootConsoleSurface()) RenderWave3Root(); else RenderWave3Subpage(); UpdateActionVisuals(); return; }
            if (definition.Shell == "3DS") { if (IsRootConsoleSurface()) Render3dsHome(); else RenderWave1Subpage(); UpdateActionVisuals(); return; }
            if (definition.Shell == "NDS") { if (IsRootConsoleSurface()) RenderDsMenu(); else RenderWave1Subpage(); UpdateActionVisuals(); return; }
            if (definition.Shell == "DSI") { if (IsRootConsoleSurface()) RenderDsiMenu(); else RenderWave1Subpage(); UpdateActionVisuals(); return; }
            if (definition.Shell == "Dreamcast") { if (IsRootConsoleSurface()) RenderDreamcastMenu(); else RenderWave1Subpage(); UpdateActionVisuals(); return; }
            if (definition.Shell == "Saturn") { if (IsRootConsoleSurface()) RenderSaturnMenu(); else RenderWave1Subpage(); UpdateActionVisuals(); return; }
            if (definition.Shell == "PSP") { if (IsRootConsoleSurface()) RenderPspXmb(); else RenderWave1Subpage(); UpdateActionVisuals(); return; }
            if (definition.Shell == "Xbox" && IsRootConsoleSurface()) { RenderXboxRoot(); UpdateActionVisuals(); return; }
            if (definition.Shell == "Xbox360" && String.Equals(dashboardSubpage, "achievements", StringComparison.OrdinalIgnoreCase)) { RenderXbox360Achievements(); UpdateActionVisuals(); return; }
            if (definition.Shell == "Xbox360" && String.Equals(dashboardSubpage, "settings", StringComparison.OrdinalIgnoreCase)) { RenderXbox360Settings(); UpdateActionVisuals(); return; }
            if (IsXboxFamily() && String.Equals(dashboardSubpage, "storage", StringComparison.OrdinalIgnoreCase)) { RenderXboxStorageManager(); UpdateActionVisuals(); return; }
            if (IsXboxFamily() && String.Equals(dashboardSubpage, "save-detail", StringComparison.OrdinalIgnoreCase)) { RenderXboxSaveDetail(); UpdateActionVisuals(); return; }
            if (definition.Shell == "Xbox")
            {
                if (page == 0) RenderGames(); else if (page == 1) { ScanXboxSaves(); RenderXboxStorageManager(); } else if (page == 2) RenderXboxMusic(); else RenderXboxSettings();
            }
            else if (definition.Shell == "Xbox360")
            {
                if (IsBlades())
                {
                    if (page == 0) RenderXbox360Home(); else if (page == 1) RenderGames(); else if (page == 2) RenderXbox360Media(); else RenderXbox360System();
                }
                else
                {
                    if (page == 0) RenderMetroHome(); else if (page == 1) RenderXbox360Profile(); else if (page == 2) RenderGames(); else if (page == 3) RenderXbox360Video(); else if (page == 4) RenderXbox360Music(); else if (page == 5) RenderXbox360Apps(); else RenderXbox360Settings();
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
            if (IsWave2Shell()) { RenderWave2Root(); return; }
            if (IsWave3Shell()) { RenderWave3Root(); return; }
            if (definition.Shell == "3DS") { Render3dsHome(); return; }
            if (definition.Shell == "NDS") { RenderDsMenu(); return; }
            if (definition.Shell == "DSI") { RenderDsiMenu(); return; }
            if (definition.Shell == "Dreamcast") { RenderDreamcastMenu(); return; }
            if (definition.Shell == "Saturn") { RenderSaturnMenu(); return; }
            if (definition.Shell == "PSP") { RenderPspXmb(); return; }
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
            titleText.Text = String.Empty; subtitleText.Text = String.Empty;
            if (games.Count > 0) n64LibraryIndex = Math.Max(0, Math.Min(games.Count - 1, n64LibraryIndex)); else n64LibraryIndex = 0;
            Grid body = new Grid { Margin = new Thickness(0) };
            body.RowDefinitions.Add(new RowDefinition { Height = new GridLength(0.18, GridUnitType.Star) });
            body.RowDefinitions.Add(new RowDefinition { Height = new GridLength(0.60, GridUnitType.Star) });
            body.RowDefinitions.Add(new RowDefinition { Height = new GridLength(0.22, GridUnitType.Star) });
            contentHost.Children.Add(body);

            Border top = new Border { Background = new LinearGradientBrush(Color.FromRgb(55,56,59), Color.FromRgb(25,26,29), 90), BorderBrush = new SolidColorBrush(Color.FromRgb(12,12,13)), BorderThickness = new Thickness(0,0,0,5) };
            Grid topGrid = new Grid();
            topGrid.Children.Add(new TextBlock { Text = "HUYMAIER 64", FontSize = 34, FontWeight = FontWeights.Bold, Foreground = new SolidColorBrush(Color.FromRgb(18,18,20)), HorizontalAlignment = HorizontalAlignment.Center, VerticalAlignment = VerticalAlignment.Center });
            top.Child = topGrid; body.Children.Add(top);

            Border redBand = new Border { Background = new LinearGradientBrush(Color.FromRgb(129,4,4), Color.FromRgb(70,0,0), 90), BorderBrush = new SolidColorBrush(Color.FromRgb(35,0,0)), BorderThickness = new Thickness(0,3,0,3) };
            Grid carousel = new Grid { Margin = new Thickness(32,20,32,20) };
            for (int i=0;i<5;i++) carousel.ColumnDefinitions.Add(new ColumnDefinition());
            int center = 2;
            for (int slot=0; slot<5; slot++)
            {
                int idx = n64LibraryIndex + slot - center;
                bool active = slot == center && games.Count > 0;
                Border frame = new Border { Margin = new Thickness(active ? 7 : 16, active ? 2 : 18, active ? 7 : 16, active ? 2 : 18), CornerRadius = new CornerRadius(10), Background = new LinearGradientBrush(Color.FromRgb(39,40,44), Color.FromRgb(11,11,13), 90), BorderBrush = new SolidColorBrush(active && n64Zone==0 ? Color.FromRgb(244,244,244) : Color.FromRgb(105,106,111)), BorderThickness = new Thickness(active && n64Zone==0 ? 5 : 2), Padding = new Thickness(6) };
                Grid card = new Grid(); card.RowDefinitions.Add(new RowDefinition { Height = new GridLength(32) }); card.RowDefinitions.Add(new RowDefinition { Height = new GridLength(1,GridUnitType.Star) }); card.RowDefinitions.Add(new RowDefinition { Height = new GridLength(44) });
                Border lip = new Border { Background = new SolidColorBrush(Color.FromRgb(8,8,10)), CornerRadius = new CornerRadius(5), Margin = new Thickness(2,2,2,5) }; card.Children.Add(lip);
                if (idx >= 0 && idx < games.Count)
                {
                    ConsolePlatformGame game = games[idx];
                    Border art = new Border { Margin = new Thickness(5), Background = new SolidColorBrush(Color.FromRgb(238,238,232)), BorderBrush = new SolidColorBrush(Color.FromRgb(13,13,15)), BorderThickness = new Thickness(2) };
                    if (!String.IsNullOrWhiteSpace(game.Cover) && File.Exists(game.Cover)) { try { art.Child = new Image { Source=LoadBitmap(game.Cover), Stretch=Stretch.UniformToFill }; } catch {} }
                    if (art.Child == null) art.Child = new TextBlock { Text="N64", FontSize=28, FontWeight=FontWeights.Bold, Foreground=new SolidColorBrush(Color.FromRgb(33,34,38)), HorizontalAlignment=HorizontalAlignment.Center, VerticalAlignment=VerticalAlignment.Center };
                    Grid.SetRow(art,1); card.Children.Add(art);
                    TextBlock name = new TextBlock { Text=game.Name, FontSize=active?13:10, FontWeight=active?FontWeights.Bold:FontWeights.SemiBold, Foreground=Brushes.White, TextAlignment=TextAlignment.Center, TextWrapping=TextWrapping.Wrap, TextTrimming=TextTrimming.CharacterEllipsis, Margin=new Thickness(4,5,4,0) }; Grid.SetRow(name,2); card.Children.Add(name);
                }
                else
                {
                    TextBlock empty = new TextBlock { Text=games.Count==0 && slot==center ? "INSERT GAME PAK" : String.Empty, FontSize=16, FontWeight=FontWeights.Bold, Foreground=new SolidColorBrush(Color.FromRgb(190,190,194)), HorizontalAlignment=HorizontalAlignment.Center, VerticalAlignment=VerticalAlignment.Center }; Grid.SetRow(empty,1); card.Children.Add(empty);
                }
                frame.Child = card; Grid.SetColumn(frame,slot); carousel.Children.Add(frame);
            }
            Grid redContent = new Grid(); redContent.RowDefinitions.Add(new RowDefinition { Height = new GridLength(36) }); redContent.RowDefinitions.Add(new RowDefinition { Height = new GridLength(1, GridUnitType.Star) });
            Border n64Letters = BuildLibraryAlphabetRail(n64LibraryIndex, false); redContent.Children.Add(n64Letters); Grid.SetRow(carousel, 1); redContent.Children.Add(carousel);
            redBand.Child=redContent; Grid.SetRow(redBand,1); body.Children.Add(redBand);

            Grid lower = new Grid { Background = new LinearGradientBrush(Color.FromRgb(50,51,54), Color.FromRgb(24,25,28), 90) };
            lower.ColumnDefinitions.Add(new ColumnDefinition { Width=new GridLength(0.34,GridUnitType.Star) }); lower.ColumnDefinitions.Add(new ColumnDefinition { Width=new GridLength(0.32,GridUnitType.Star) }); lower.ColumnDefinitions.Add(new ColumnDefinition { Width=new GridLength(0.34,GridUnitType.Star) });
            Button pak = CreateN64ConsoleButton("CONTROLLER PAK", "save data", n64Zone==1 && n64UtilityIndex==0, delegate { dashboardSubpage="n64-pak"; page=1; selected=0; RenderPage(); }); lower.Children.Add(pak);
            StackPanel jewel = new StackPanel { VerticalAlignment=VerticalAlignment.Center, HorizontalAlignment=HorizontalAlignment.Center };
            StackPanel blocks = new StackPanel { Orientation=Orientation.Horizontal, HorizontalAlignment=HorizontalAlignment.Center };
            foreach(Color c in new Color[]{Color.FromRgb(34,170,79),Color.FromRgb(238,59,53),Color.FromRgb(248,205,55),Color.FromRgb(52,91,170)}) blocks.Children.Add(new Border{Width=16,Height=16,Margin=new Thickness(2),Background=new SolidColorBrush(c)});
            jewel.Children.Add(blocks); jewel.Children.Add(new TextBlock { Text="64",FontSize=28,FontWeight=FontWeights.Black,Foreground=Brushes.White,HorizontalAlignment=HorizontalAlignment.Center }); Grid.SetColumn(jewel,1); lower.Children.Add(jewel);
            Button options = CreateN64ConsoleButton("OPTIONS", String.IsNullOrWhiteSpace(settings.emulatorPath)?"emulator setup":"system", n64Zone==1 && n64UtilityIndex==1, delegate { dashboardSubpage="n64-settings"; page=2; selected=0; RenderPage(); }); Grid.SetColumn(options,2); lower.Children.Add(options);
            Grid.SetRow(lower,2); body.Children.Add(lower);
            actions.Add(new ConsolePlatformAction{Button=pak,Invoke=delegate{dashboardSubpage="n64-pak";page=1;selected=0;RenderPage();},Name="Controller Pak"});
            actions.Add(new ConsolePlatformAction{Button=options,Invoke=delegate{dashboardSubpage="n64-settings";page=2;selected=0;RenderPage();},Name="Options"});
        }

        private Button CreateN64ConsoleButton(string title, string detail, bool active, Action invoke)
        {
            Button b = new Button { Margin=new Thickness(30,18,30,18),Background=new SolidColorBrush(active?Color.FromRgb(129,0,0):Color.FromRgb(20,20,23)),BorderBrush=new SolidColorBrush(active?Color.FromRgb(255,255,255):Color.FromRgb(91,92,96)),BorderThickness=new Thickness(active?4:2),RenderTransformOrigin=new Point(0.5,0.5) };
            StackPanel s=new StackPanel{VerticalAlignment=VerticalAlignment.Center};s.Children.Add(new TextBlock{Text=title,FontSize=17,FontWeight=FontWeights.Bold,Foreground=Brushes.White,HorizontalAlignment=HorizontalAlignment.Center});s.Children.Add(new TextBlock{Text=detail,FontSize=10,Foreground=new SolidColorBrush(Color.FromRgb(180,181,185)),HorizontalAlignment=HorizontalAlignment.Center});b.Content=s;b.Click+=delegate{invoke();};return b;
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
            Grid stage = new Grid { Margin=new Thickness(12,0,12,0) }; contentHost.Children.Add(stage);
            Viewport3D viewport = new Viewport3D { HorizontalAlignment=HorizontalAlignment.Stretch, VerticalAlignment=VerticalAlignment.Stretch };
            PerspectiveCamera camera = new PerspectiveCamera { Position=new Point3D(0,0,5.3), LookDirection=new Vector3D(0,0,-5.3), UpDirection=new Vector3D(0,1,0), FieldOfView=44 }; viewport.Camera=camera;
            Model3DGroup models = new Model3DGroup(); models.Children.Add(new AmbientLight(Color.FromRgb(130,120,180))); models.Children.Add(new DirectionalLight(Color.FromRgb(215,210,255),new Vector3D(-0.5,-0.4,-1)));
            models.Children.Add(CreateGameCubeFace("GAME PLAY", "Game Disc", "front"));
            models.Children.Add(CreateGameCubeFace("CALENDAR", DateTime.Now.ToString("MMM d  yyyy",CultureInfo.CurrentCulture), "right"));
            models.Children.Add(CreateGameCubeFace("MEMORY CARD", "Slot A / Slot B", "bottom"));
            models.Children.Add(CreateGameCubeFace("OPTIONS", "System / Emulator", "left"));
            models.Children.Add(CreateGameCubeFace("NINTENDO GAMECUBE", "", "top"));
            models.Children.Add(CreateGameCubeFace("HUYMAIER", "", "back"));
            QuaternionRotation3D rotation = new QuaternionRotation3D();
            Quaternion target = GetGameCubeQuaternion(page);
            Quaternion start = gameCubePreviousPage >= 0 ? GetGameCubeQuaternion(gameCubePreviousPage) : target;
            rotation.Quaternion=start;
            RotateTransform3D rotate = new RotateTransform3D(rotation);
            Transform3DGroup cubeTransforms = new Transform3DGroup();
            cubeTransforms.Children.Add(new ScaleTransform3D(settings.gameCubeScale, settings.gameCubeScale, settings.gameCubeScale));
            cubeTransforms.Children.Add(rotate);
            models.Transform=cubeTransforms;
            ModelVisual3D visual = new ModelVisual3D { Content=models }; viewport.Children.Add(visual); stage.Children.Add(viewport);
            if (gameCubePreviousPage >= 0 && gameCubePreviousPage != page)
            {
                QuaternionAnimation animation = new QuaternionAnimation(start,target,new Duration(TimeSpan.FromMilliseconds(430))) { AccelerationRatio=0.28, DecelerationRatio=0.32, FillBehavior=FillBehavior.HoldEnd };
                rotation.BeginAnimation(QuaternionRotation3D.QuaternionProperty,animation,HandoffBehavior.SnapshotAndReplace);
            }
            gameCubePreviousPage=-1;
            Border legend = new Border { VerticalAlignment=VerticalAlignment.Bottom,HorizontalAlignment=HorizontalAlignment.Center,Margin=new Thickness(0,0,0,20),Padding=new Thickness(22,8,22,8),CornerRadius=new CornerRadius(18),Background=new SolidColorBrush(Color.FromArgb(145,12,9,31)) };
            legend.Child=new TextBlock{Text="D-Pad / Stick rolls the cube     A  Open     B  Back",FontSize=13,Foreground=new SolidColorBrush(Color.FromRgb(218,214,240))};stage.Children.Add(legend);
        }

        private Quaternion GetGameCubeQuaternion(int index)
        {
            if(index==1) return new Quaternion(new Vector3D(0,1,0),-90);
            if(index==2) return new Quaternion(new Vector3D(1,0,0),90);
            if(index==3) return new Quaternion(new Vector3D(0,1,0),90);
            return Quaternion.Identity;
        }

        private GeometryModel3D CreateGameCubeFace(string title, string detail, string face)
        {
            Point3D[] p;
            if(face=="right") p=new[]{new Point3D(1.35,-1.35,1.35),new Point3D(1.35,-1.35,-1.35),new Point3D(1.35,1.35,-1.35),new Point3D(1.35,1.35,1.35)};
            else if(face=="left") p=new[]{new Point3D(-1.35,-1.35,-1.35),new Point3D(-1.35,-1.35,1.35),new Point3D(-1.35,1.35,1.35),new Point3D(-1.35,1.35,-1.35)};
            else if(face=="bottom") p=new[]{new Point3D(-1.35,-1.35,-1.35),new Point3D(1.35,-1.35,-1.35),new Point3D(1.35,-1.35,1.35),new Point3D(-1.35,-1.35,1.35)};
            else if(face=="top") p=new[]{new Point3D(-1.35,1.35,1.35),new Point3D(1.35,1.35,1.35),new Point3D(1.35,1.35,-1.35),new Point3D(-1.35,1.35,-1.35)};
            else if(face=="back") p=new[]{new Point3D(1.35,-1.35,-1.35),new Point3D(-1.35,-1.35,-1.35),new Point3D(-1.35,1.35,-1.35),new Point3D(1.35,1.35,-1.35)};
            else p=new[]{new Point3D(-1.35,-1.35,1.35),new Point3D(1.35,-1.35,1.35),new Point3D(1.35,1.35,1.35),new Point3D(-1.35,1.35,1.35)};
            MeshGeometry3D mesh=new MeshGeometry3D(); foreach(Point3D point in p) mesh.Positions.Add(point); mesh.TextureCoordinates.Add(new Point(0,1));mesh.TextureCoordinates.Add(new Point(1,1));mesh.TextureCoordinates.Add(new Point(1,0));mesh.TextureCoordinates.Add(new Point(0,0)); mesh.TriangleIndices.Add(0);mesh.TriangleIndices.Add(1);mesh.TriangleIndices.Add(2);mesh.TriangleIndices.Add(0);mesh.TriangleIndices.Add(2);mesh.TriangleIndices.Add(3);
            Grid visual=new Grid{Width=420,Height=420,Background=new SolidColorBrush(Color.FromArgb(118,43,32,93))}; visual.RowDefinitions.Add(new RowDefinition{Height=new GridLength(1,GridUnitType.Star)});visual.RowDefinitions.Add(new RowDefinition{Height=new GridLength(86)});
            Border inner=new Border{Margin=new Thickness(20),CornerRadius=new CornerRadius(20),BorderBrush=new SolidColorBrush(Color.FromArgb(210,167,153,255)),BorderThickness=new Thickness(5),Background=new LinearGradientBrush(Color.FromArgb(55,164,151,255),Color.FromArgb(42,30,22,71),45)};inner.Child=new TextBlock{Text=title,FontSize=34,FontWeight=FontWeights.SemiBold,Foreground=new SolidColorBrush(Color.FromArgb(235,238,235,255)),HorizontalAlignment=HorizontalAlignment.Center,VerticalAlignment=VerticalAlignment.Center,TextAlignment=TextAlignment.Center};visual.Children.Add(inner);
            TextBlock sub=new TextBlock{Text=detail,FontSize=16,Foreground=new SolidColorBrush(Color.FromArgb(225,205,201,232)),HorizontalAlignment=HorizontalAlignment.Center,VerticalAlignment=VerticalAlignment.Center};Grid.SetRow(sub,1);visual.Children.Add(sub);
            VisualBrush brush=new VisualBrush(visual){Opacity=0.88,Stretch=Stretch.Fill}; MaterialGroup material=new MaterialGroup();material.Children.Add(new DiffuseMaterial(brush));material.Children.Add(new EmissiveMaterial(new SolidColorBrush(Color.FromArgb(58,100,84,210))));
            GeometryModel3D model=new GeometryModel3D(mesh,material);model.BackMaterial=material;return model;
        }

        private void AddGameCubeHubNode(Grid hub, string title, string detail, int index, int row, int column, string arrow)
        {
            bool active = page == index; Border node = new Border { Width = 310, Height = 128, CornerRadius = new CornerRadius(54), Background = new SolidColorBrush(active ? Color.FromArgb(235, 112, 88, 211) : Color.FromArgb(175, 51, 39, 106)), BorderBrush = new SolidColorBrush(active ? Color.FromRgb(224, 217, 255) : Color.FromRgb(116, 99, 192)), BorderThickness = new Thickness(active ? 5 : 2), HorizontalAlignment = HorizontalAlignment.Center, VerticalAlignment = VerticalAlignment.Center };
            StackPanel s = new StackPanel { VerticalAlignment = VerticalAlignment.Center }; s.Children.Add(new TextBlock { Text = arrow + "  " + title, FontSize = 22, FontWeight = FontWeights.Bold, Foreground = Brushes.White, HorizontalAlignment = HorizontalAlignment.Center }); s.Children.Add(new TextBlock { Text = detail, FontSize = 11, Foreground = new SolidColorBrush(Color.FromRgb(214, 210, 235)), HorizontalAlignment = HorizontalAlignment.Center }); node.Child = s; Grid.SetRow(node, row); Grid.SetColumn(node, column); hub.Children.Add(node);
        }

        private void RenderGameCubeGamePlay()
        {
            titleText.Text = "Game Play"; subtitleText.Text = games.Count == 0 ? "No Game Disc / library title detected" : "Select a Game Disc image • LB / RB jumps by first letter";
            Grid gamePlayBody = new Grid(); gamePlayBody.RowDefinitions.Add(new RowDefinition { Height = new GridLength(38) }); gamePlayBody.RowDefinitions.Add(new RowDefinition { Height = new GridLength(1, GridUnitType.Star) }); contentHost.Children.Add(gamePlayBody);
            Border gcLetters = BuildLibraryAlphabetRail(Math.Max(0, Math.Min(games.Count - 1, selected)), false); gamePlayBody.Children.Add(gcLetters);
            ScrollViewer scroll = new ScrollViewer { VerticalScrollBarVisibility = ScrollBarVisibility.Hidden, HorizontalScrollBarVisibility = ScrollBarVisibility.Disabled }; WrapPanel wrap = new WrapPanel { HorizontalAlignment = HorizontalAlignment.Center, Margin = new Thickness(20) }; scroll.Content = wrap; Grid.SetRow(scroll, 1); gamePlayBody.Children.Add(scroll);
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
            titleText.Text=String.Empty;subtitleText.Text=String.Empty;columns=4;
            Grid body=new Grid{Margin=new Thickness(34,12,34,0)};body.RowDefinitions.Add(new RowDefinition{Height=new GridLength(1,GridUnitType.Star)});body.RowDefinitions.Add(new RowDefinition{Height=new GridLength(94)});contentHost.Children.Add(body);
            Grid menuArea=new Grid();menuArea.RowDefinitions.Add(new RowDefinition{Height=new GridLength(34)});menuArea.RowDefinitions.Add(new RowDefinition{Height=new GridLength(1,GridUnitType.Star)});body.Children.Add(menuArea);
            Border wiiLetters=BuildLibraryAlphabetRail(Math.Max(0,Math.Min(games.Count-1,wiiMenuPage*12+Math.Min(selected,11))),true);menuArea.Children.Add(wiiLetters);
            UniformGrid channels=new UniformGrid{Columns=4,Rows=3,Margin=new Thickness(6,0,6,10)};Grid.SetRow(channels,1);menuArea.Children.Add(channels);
            int start=wiiMenuPage*12;int added=0;
            for(int slot=0;slot<12;slot++)
            {
                int idx=start+slot;
                if(idx<games.Count)
                {
                    ConsolePlatformGame game=games[idx];ConsolePlatformGame captured=game;Button tile=CreateWiiChannelTile(game,false,delegate{shellSelectedGame=captured;dashboardSubpage="wii-start";selected=0;RenderPage();});channels.Children.Add(tile);actions.Add(new ConsolePlatformAction{Button=tile,Invoke=delegate{shellSelectedGame=captured;dashboardSubpage="wii-start";selected=0;RenderPage();},Name=game.Name,Game=game});added++;
                }
                else if(slot==0 && games.Count==0)
                {
                    Button setup=CreateWiiEmptyChannel("Disc Channel","No disc / library configured",delegate{dashboardSubpage="wii-settings";selected=0;RenderPage();});channels.Children.Add(setup);actions.Add(new ConsolePlatformAction{Button=setup,Invoke=delegate{dashboardSubpage="wii-settings";selected=0;RenderPage();},Name="Disc Channel"});added++;
                }
                else channels.Children.Add(new Border{Margin=new Thickness(9),CornerRadius=new CornerRadius(13),Background=new LinearGradientBrush(Color.FromRgb(252,253,253),Color.FromRgb(233,238,240),90),BorderBrush=new SolidColorBrush(Color.FromRgb(194,207,211)),BorderThickness=new Thickness(2)});
            }
            Grid bottom=new Grid{Margin=new Thickness(4,0,4,0)};bottom.ColumnDefinitions.Add(new ColumnDefinition{Width=new GridLength(220)});bottom.ColumnDefinitions.Add(new ColumnDefinition{Width=new GridLength(1,GridUnitType.Star)});bottom.ColumnDefinitions.Add(new ColumnDefinition{Width=new GridLength(220)});
            Button wii=CreateWiiRoundButton("Wii","",delegate{dashboardSubpage="wii-options";selected=0;RenderPage();});wii.Width=148;wii.HorizontalAlignment=HorizontalAlignment.Left;bottom.Children.Add(wii);
            StackPanel clock=new StackPanel{HorizontalAlignment=HorizontalAlignment.Center,VerticalAlignment=VerticalAlignment.Center};clock.Children.Add(new TextBlock{Text=DateTime.Now.ToString("h:mm tt",CultureInfo.CurrentCulture),FontSize=25,Foreground=new SolidColorBrush(Color.FromRgb(87,99,104)),HorizontalAlignment=HorizontalAlignment.Center});clock.Children.Add(new TextBlock{Text=DateTime.Now.ToString("ddd M/d",CultureInfo.CurrentCulture)+"   "+(wiiMenuPage+1).ToString(CultureInfo.InvariantCulture)+"/"+GetWiiMenuPageCount().ToString(CultureInfo.InvariantCulture),FontSize=12,Foreground=new SolidColorBrush(Color.FromRgb(123,134,139)),HorizontalAlignment=HorizontalAlignment.Center});Grid.SetColumn(clock,1);bottom.Children.Add(clock);
            Button data=CreateWiiRoundButton("✉","Save Data",delegate{dashboardSubpage="wii-data";selected=0;RenderPage();});data.Width=148;data.HorizontalAlignment=HorizontalAlignment.Right;Grid.SetColumn(data,2);bottom.Children.Add(data);Grid.SetRow(bottom,1);body.Children.Add(bottom);
            actions.Add(new ConsolePlatformAction{Button=wii,Invoke=delegate{dashboardSubpage="wii-options";selected=0;RenderPage();},Name="Wii Options"});actions.Add(new ConsolePlatformAction{Button=data,Invoke=delegate{dashboardSubpage="wii-data";selected=0;RenderPage();},Name="Save Data"});
            selected=Math.Max(0,Math.Min(actions.Count-1,selected));
        }

        private Button CreateWiiEmptyChannel(string title,string detail,Action invoke)
        {
            Button b=new Button{Margin=new Thickness(9),Background=Brushes.White,BorderBrush=new SolidColorBrush(Color.FromRgb(154,205,219)),BorderThickness=new Thickness(3),RenderTransformOrigin=new Point(0.5,0.5)};StackPanel s=new StackPanel{VerticalAlignment=VerticalAlignment.Center};s.Children.Add(new TextBlock{Text=title,FontSize=22,Foreground=new SolidColorBrush(Color.FromRgb(94,109,115)),HorizontalAlignment=HorizontalAlignment.Center});s.Children.Add(new TextBlock{Text=detail,FontSize=10,Foreground=new SolidColorBrush(Color.FromRgb(132,143,147)),HorizontalAlignment=HorizontalAlignment.Center});b.Content=s;b.Click+=delegate{invoke();};return b;
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
            titleText.Text=String.Empty;subtitleText.Text=String.Empty;
            Grid shell=new Grid{Margin=new Thickness(0)};shell.RowDefinitions.Add(new RowDefinition{Height=new GridLength(66)});shell.RowDefinitions.Add(new RowDefinition{Height=new GridLength(1,GridUnitType.Star)});shell.RowDefinitions.Add(new RowDefinition{Height=new GridLength(72)});contentHost.Children.Add(shell);
            Border top=new Border{Background=new LinearGradientBrush(Color.FromRgb(20,20,22),Color.FromRgb(3,3,4),90),BorderBrush=new SolidColorBrush(Color.FromRgb(220,220,220)),BorderThickness=new Thickness(0,0,0,2),Child=new TextBlock{Text="Wii",FontSize=28,FontWeight=FontWeights.Bold,Foreground=Brushes.White,HorizontalAlignment=HorizontalAlignment.Right,VerticalAlignment=VerticalAlignment.Center,Margin=new Thickness(0,0,32,0)}};shell.Children.Add(top);
            Border middle=new Border{Background=new LinearGradientBrush(Color.FromRgb(67,67,69),Color.FromRgb(44,44,46),90),BorderBrush=new SolidColorBrush(Color.FromRgb(175,175,177)),BorderThickness=new Thickness(0,1,0,1)};Grid.SetRow(middle,1);shell.Children.Add(middle);
            Grid choices=new Grid{Margin=new Thickness(120,70,120,70)};choices.ColumnDefinitions.Add(new ColumnDefinition());choices.ColumnDefinitions.Add(new ColumnDefinition());middle.Child=choices;
            Button data=CreateWiiOptionPanel("▣","Data Management","Save Data",delegate{dashboardSubpage="wii-data";selected=0;RenderPage();});choices.Children.Add(data);actions.Add(new ConsolePlatformAction{Button=data,Invoke=delegate{dashboardSubpage="wii-data";selected=0;RenderPage();},Name="Data Management"});
            Button settingsButton=CreateWiiOptionPanel("🔧","Wii Settings","Emulator / library / display",delegate{dashboardSubpage="wii-settings";selected=0;RenderPage();});Grid.SetColumn(settingsButton,1);choices.Children.Add(settingsButton);actions.Add(new ConsolePlatformAction{Button=settingsButton,Invoke=delegate{dashboardSubpage="wii-settings";selected=0;RenderPage();},Name="Wii Settings"});
            Border bottom=new Border{Background=new LinearGradientBrush(Color.FromRgb(13,13,14),Color.FromRgb(2,2,3),90)};Button back=CreateWiiRoundButton("Back","Wii Menu",delegate{dashboardSubpage=String.Empty;selected=0;RenderPage();});back.Width=185;back.HorizontalAlignment=HorizontalAlignment.Left;back.Margin=new Thickness(44,7,0,7);bottom.Child=back;Grid.SetRow(bottom,2);shell.Children.Add(bottom);actions.Add(new ConsolePlatformAction{Button=back,Invoke=delegate{dashboardSubpage=String.Empty;selected=0;RenderPage();},Name="Back"});
        }

        private Button CreateWiiOptionPanel(string glyph,string title,string detail,Action invoke)
        {
            Button b=new Button{Margin=new Thickness(35),Background=new LinearGradientBrush(Color.FromRgb(249,251,252),Color.FromRgb(217,224,228),90),BorderBrush=new SolidColorBrush(Color.FromRgb(74,193,225)),BorderThickness=new Thickness(4),RenderTransformOrigin=new Point(0.5,0.5)};StackPanel s=new StackPanel{VerticalAlignment=VerticalAlignment.Center};s.Children.Add(new TextBlock{Text=glyph,FontSize=62,Foreground=new SolidColorBrush(Color.FromRgb(130,139,144)),HorizontalAlignment=HorizontalAlignment.Center});s.Children.Add(new TextBlock{Text=title,FontSize=24,Foreground=new SolidColorBrush(Color.FromRgb(86,96,101)),HorizontalAlignment=HorizontalAlignment.Center,Margin=new Thickness(0,14,0,4)});s.Children.Add(new TextBlock{Text=detail,FontSize=11,Foreground=new SolidColorBrush(Color.FromRgb(121,132,137)),HorizontalAlignment=HorizontalAlignment.Center});b.Content=s;b.Click+=delegate{invoke();};return b;
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
            StackPanel sys = new StackPanel { Orientation = Orientation.Horizontal, HorizontalAlignment = HorizontalAlignment.Center, VerticalAlignment = VerticalAlignment.Center }; Button data = CreateWiiURoundSystemButton("Data Management", delegate { dashboardSubpage = "wiiu-data"; page = 1; selected = 0; RenderWiiUDataManagement(FindSaveRoots()); UpdateActionVisuals(); }); Button settingsButton = CreateWiiURoundSystemButton("System Settings", delegate { dashboardSubpage = "wiiu-settings"; page = 2; selected = 0; contentHost.Children.Clear(); actions.Clear(); RenderWiiUSettings(); UpdateActionVisuals(); }); sys.Children.Add(data); sys.Children.Add(settingsButton); Grid.SetRow(sys,1); body.Children.Add(sys); actions.Add(new ConsolePlatformAction { Button=data, Invoke=delegate { dashboardSubpage="wiiu-data"; page=1; selected=0; contentHost.Children.Clear(); actions.Clear(); RenderWiiUDataManagement(FindSaveRoots()); UpdateActionVisuals(); }, Name="Data Management" }); actions.Add(new ConsolePlatformAction { Button=settingsButton, Invoke=delegate { dashboardSubpage="wiiu-settings"; page=2; selected=0; contentHost.Children.Clear(); actions.Clear(); RenderWiiUSettings(); UpdateActionVisuals(); }, Name="System Settings" }); selected=Math.Max(0,Math.Min(actions.Count-1,selected));
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
            titleText.Text=String.Empty;subtitleText.Text=String.Empty;switchSoftwareActionCount=0;switchSystemActionStart=0;
            Grid body=new Grid{Margin=new Thickness(48,18,48,12)};body.RowDefinitions.Add(new RowDefinition{Height=new GridLength(70)});body.RowDefinitions.Add(new RowDefinition{Height=new GridLength(1,GridUnitType.Star)});body.RowDefinitions.Add(new RowDefinition{Height=new GridLength(108)});contentHost.Children.Add(body);
            Grid status=new Grid();status.ColumnDefinitions.Add(new ColumnDefinition());status.ColumnDefinitions.Add(new ColumnDefinition());StackPanel user=new StackPanel{Orientation=Orientation.Horizontal,VerticalAlignment=VerticalAlignment.Center};Border avatar=new Border{Width=48,Height=48,CornerRadius=new CornerRadius(24),Background=new SolidColorBrush(Color.FromRgb(230,0,18)),Child=new TextBlock{Text=Environment.UserName.Length>0?Environment.UserName.Substring(0,1).ToUpperInvariant():"U",FontSize=23,FontWeight=FontWeights.Bold,Foreground=Brushes.White,HorizontalAlignment=HorizontalAlignment.Center,VerticalAlignment=VerticalAlignment.Center}};user.Children.Add(avatar);user.Children.Add(new TextBlock{Text=Environment.UserName,FontSize=16,Foreground=Brushes.White,VerticalAlignment=VerticalAlignment.Center,Margin=new Thickness(12,0,0,0)});status.Children.Add(user);TextBlock clock=new TextBlock{Text=DateTime.Now.ToString("h:mm tt",CultureInfo.CurrentCulture),FontSize=15,Foreground=Brushes.White,HorizontalAlignment=HorizontalAlignment.Right,VerticalAlignment=VerticalAlignment.Center};Grid.SetColumn(clock,1);status.Children.Add(clock);body.Children.Add(status);
            ScrollViewer scroller=new ScrollViewer{HorizontalScrollBarVisibility=ScrollBarVisibility.Hidden,VerticalScrollBarVisibility=ScrollBarVisibility.Disabled,Margin=new Thickness(0,8,0,8)};StackPanel software=new StackPanel{Orientation=Orientation.Horizontal,VerticalAlignment=VerticalAlignment.Center};scroller.Content=software;Grid.SetRow(scroller,1);body.Children.Add(scroller);
            int visible=Math.Min(12,games.Count);for(int i=0;i<visible;i++){ConsolePlatformGame game=games[i];ConsolePlatformGame captured=game;Button tile=CreateSwitchSoftwareTile(game,delegate{LaunchGame(captured,false);});software.Children.Add(tile);actions.Add(new ConsolePlatformAction{Button=tile,Invoke=delegate{LaunchGame(captured,false);},Name=game.Name,Game=game});}
            if(games.Count>12){Button all=CreateSwitchSystemTile("ALL","All Software",delegate{dashboardSubpage="switch-all";selected=0;RenderPage();},120);software.Children.Add(all);actions.Add(new ConsolePlatformAction{Button=all,Invoke=delegate{dashboardSubpage="switch-all";selected=0;contentHost.Children.Clear();actions.Clear();RenderSwitchAllSoftware();UpdateActionVisuals();},Name="All Software"});}
            if(actions.Count==0){Button add=CreateSwitchSystemTile("+","Add Software",delegate{dashboardSubpage="switch-settings";selected=0;RenderPage();},180);software.Children.Add(add);actions.Add(new ConsolePlatformAction{Button=add,Invoke=delegate{dashboardSubpage="switch-settings";selected=0;contentHost.Children.Clear();actions.Clear();RenderSwitchSettings();UpdateActionVisuals();},Name="Add Software"});}
            switchSoftwareActionCount=actions.Count;switchSystemActionStart=actions.Count;
            StackPanel system=new StackPanel{Orientation=Orientation.Horizontal,HorizontalAlignment=HorizontalAlignment.Center,VerticalAlignment=VerticalAlignment.Center};
            AddSwitchSystemAction(system,"▣","Data Management",delegate{dashboardSubpage="switch-data";selected=0;contentHost.Children.Clear();actions.Clear();RenderSwitchDataManagement(FindSaveRoots());UpdateActionVisuals();});
            AddSwitchSystemAction(system,"◫","Controllers",delegate{RequestHuymaierPicker("OpenControllerSettings");});
            AddSwitchSystemAction(system,"⚙","System Settings",delegate{dashboardSubpage="switch-settings";selected=0;contentHost.Children.Clear();actions.Clear();RenderSwitchSettings();UpdateActionVisuals();});
            AddSwitchSystemAction(system,"↩","Huymaier",delegate{Close();});
            Grid.SetRow(system,2);body.Children.Add(system);
            int sysCount=Math.Max(0,actions.Count-switchSystemActionStart);switchSoftwareIndex=Math.Min(Math.Max(0,switchSoftwareActionCount-1),switchSoftwareIndex);switchSystemIndex=Math.Min(Math.Max(0,sysCount-1),switchSystemIndex);selected=switchZone==0?switchSoftwareIndex:Math.Min(actions.Count-1,switchSystemActionStart+switchSystemIndex);
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


        private Button CreateWave1Tile(string title, string detail, string glyph, Brush background, Brush foreground, Action invoke, double width, double height)
        {
            Button b = new Button { Width=width, Height=height, Margin=new Thickness(10), Padding=new Thickness(10), Background=background, BorderBrush=new SolidColorBrush(Color.FromArgb(130,255,255,255)), BorderThickness=new Thickness(2), RenderTransformOrigin=new Point(0.5,0.5) };
            StackPanel s = new StackPanel { VerticalAlignment=VerticalAlignment.Center };
            s.Children.Add(new TextBlock { Text=glyph, FontSize=Math.Max(24,height*0.22), FontWeight=FontWeights.Light, Foreground=foreground, HorizontalAlignment=HorizontalAlignment.Center });
            s.Children.Add(new TextBlock { Text=title, FontSize=15, FontWeight=FontWeights.SemiBold, Foreground=foreground, HorizontalAlignment=HorizontalAlignment.Center, TextAlignment=TextAlignment.Center, TextWrapping=TextWrapping.Wrap });
            if(!String.IsNullOrWhiteSpace(detail)) s.Children.Add(new TextBlock { Text=detail, FontSize=10, Foreground=foreground, Opacity=0.75, HorizontalAlignment=HorizontalAlignment.Center, TextAlignment=TextAlignment.Center, TextTrimming=TextTrimming.CharacterEllipsis, MaxWidth=Math.Max(80,width-20) });
            b.Content=s; b.Click+=delegate{invoke();}; return b;
        }

        private void AddWave1Action(Panel panel, Button button, string name, Action invoke, ConsolePlatformGame game)
        {
            panel.Children.Add(button); actions.Add(new ConsolePlatformAction { Button=button, Name=name, Invoke=invoke, Game=game });
        }

        private void OpenWave1Subpage(string name)
        {
            dashboardSubpage=name; selected=0; shellSelectedGame=null; RenderPage();
        }

        private void Render3dsHome()
        {
            titleText.Text=String.Empty; subtitleText.Text=String.Empty; columns=6;
            Grid body=new Grid{Margin=new Thickness(28,0,28,8)}; body.RowDefinitions.Add(new RowDefinition{Height=new GridLength(0.38,GridUnitType.Star)}); body.RowDefinitions.Add(new RowDefinition{Height=new GridLength(0.62,GridUnitType.Star)}); contentHost.Children.Add(body);
            Border top=new Border{CornerRadius=new CornerRadius(12),Margin=new Thickness(90,0,90,8),Background=new LinearGradientBrush(Color.FromRgb(236,240,243),Color.FromRgb(205,215,224),90),BorderBrush=new SolidColorBrush(Color.FromRgb(169,181,191)),BorderThickness=new Thickness(2)};
            Grid topInner=new Grid(); topInner.Children.Add(new TextBlock{Text=DateTime.Now.ToString("h:mm",CultureInfo.CurrentCulture),FontSize=54,FontWeight=FontWeights.Light,Foreground=new SolidColorBrush(Color.FromRgb(71,80,88)),HorizontalAlignment=HorizontalAlignment.Center,VerticalAlignment=VerticalAlignment.Center,Margin=new Thickness(0,0,0,22)}); topInner.Children.Add(new TextBlock{Text=DateTime.Now.ToString("dddd, MMMM d",CultureInfo.CurrentCulture),FontSize=16,Foreground=new SolidColorBrush(Color.FromRgb(93,106,116)),HorizontalAlignment=HorizontalAlignment.Center,VerticalAlignment=VerticalAlignment.Bottom,Margin=new Thickness(0,0,0,24)}); top.Child=topInner; body.Children.Add(top);
            Border bottom=new Border{CornerRadius=new CornerRadius(14),Background=new SolidColorBrush(Color.FromRgb(248,249,250)),BorderBrush=new SolidColorBrush(Color.FromRgb(174,186,194)),BorderThickness=new Thickness(2),Padding=new Thickness(18)}; Grid.SetRow(bottom,1); body.Children.Add(bottom);
            ScrollViewer scroll=new ScrollViewer{VerticalScrollBarVisibility=ScrollBarVisibility.Hidden,HorizontalScrollBarVisibility=ScrollBarVisibility.Disabled}; WrapPanel wrap=new WrapPanel(); scroll.Content=wrap; bottom.Child=scroll;
            int shown=Math.Min(games.Count,18); for(int i=0;i<shown;i++){ConsolePlatformGame game=games[i];ConsolePlatformGame captured=game;Button tile=CreateWave1GameIcon(game,"3DS",Color.FromRgb(72,148,203),145,120,delegate{LaunchGame(captured,false);});AddWave1Action(wrap,tile,game.Name,delegate{LaunchGame(captured,false);},game);}
            Button library=CreateWave1Tile("Software Library",games.Count+" titles","▦",new SolidColorBrush(Color.FromRgb(91,168,219)),Brushes.White,delegate{OpenWave1Subpage("library");},145,120);AddWave1Action(wrap,library,"Software Library",delegate{OpenWave1Subpage("library");},null);
            Button data=CreateWave1Tile("Data Management","saves and installed data","▣",new SolidColorBrush(Color.FromRgb(239,157,56)),Brushes.White,delegate{OpenWave1Subpage("saves");},145,120);AddWave1Action(wrap,data,"Data Management",delegate{OpenWave1Subpage("saves");},null);
            Button system=CreateWave1Tile("System Settings","Azahar + Huymaier","⚙",new SolidColorBrush(Color.FromRgb(91,101,111)),Brushes.White,delegate{OpenWave1Subpage("settings");},145,120);AddWave1Action(wrap,system,"System Settings",delegate{OpenWave1Subpage("settings");},null);
        }

        private Button CreateWave1GameIcon(ConsolePlatformGame game,string fallbackText,Color accent,double width,double height,Action invoke)
        {
            Button b=new Button{Width=width,Height=height,Margin=new Thickness(10),Padding=new Thickness(3),Background=Brushes.White,BorderBrush=new SolidColorBrush(accent),BorderThickness=new Thickness(2),RenderTransformOrigin=new Point(0.5,0.5)};Grid g=new Grid();
            if(!String.IsNullOrWhiteSpace(game.Cover)&&File.Exists(game.Cover)){try{g.Children.Add(new Image{Source=LoadBitmap(game.Cover),Stretch=Stretch.UniformToFill});}catch{}}
            if(g.Children.Count==0)g.Children.Add(new TextBlock{Text=fallbackText,FontSize=22,FontWeight=FontWeights.Bold,Foreground=new SolidColorBrush(accent),HorizontalAlignment=HorizontalAlignment.Center,VerticalAlignment=VerticalAlignment.Center});
            Border cap=new Border{Height=30,VerticalAlignment=VerticalAlignment.Bottom,Background=new SolidColorBrush(Color.FromArgb(225,250,251,252)),Padding=new Thickness(4)};cap.Child=new TextBlock{Text=game.Name,FontSize=9,Foreground=new SolidColorBrush(Color.FromRgb(50,58,64)),TextTrimming=TextTrimming.CharacterEllipsis,HorizontalAlignment=HorizontalAlignment.Center};g.Children.Add(cap);b.Content=g;b.Click+=delegate{invoke();};return b;
        }

        private void RenderDsMenu()
        {
            titleText.Text=String.Empty;subtitleText.Text=String.Empty;columns=2;Grid body=new Grid{Margin=new Thickness(120,0,120,6)};body.RowDefinitions.Add(new RowDefinition{Height=new GridLength(0.48,GridUnitType.Star)});body.RowDefinitions.Add(new RowDefinition{Height=new GridLength(0.52,GridUnitType.Star)});contentHost.Children.Add(body);
            Border top=new Border{Margin=new Thickness(20,0,20,8),CornerRadius=new CornerRadius(10),Background=Brushes.White,BorderBrush=new SolidColorBrush(Color.FromRgb(158,178,193)),BorderThickness=new Thickness(2)};Grid tg=new Grid();tg.ColumnDefinitions.Add(new ColumnDefinition());tg.ColumnDefinitions.Add(new ColumnDefinition());TextBlock clock=new TextBlock{Text=DateTime.Now.ToString("h:mm tt",CultureInfo.CurrentCulture),FontSize=40,Foreground=new SolidColorBrush(Color.FromRgb(70,85,97)),HorizontalAlignment=HorizontalAlignment.Center,VerticalAlignment=VerticalAlignment.Center};tg.Children.Add(clock);TextBlock date=new TextBlock{Text=DateTime.Now.ToString("MMM\ndd",CultureInfo.CurrentCulture).ToUpperInvariant(),FontSize=30,TextAlignment=TextAlignment.Center,Foreground=new SolidColorBrush(Color.FromRgb(73,137,190)),HorizontalAlignment=HorizontalAlignment.Center,VerticalAlignment=VerticalAlignment.Center};Grid.SetColumn(date,1);tg.Children.Add(date);top.Child=tg;body.Children.Add(top);
            UniformGrid menu=new UniformGrid{Columns=2,Rows=2,Margin=new Thickness(20,8,20,0)};Grid.SetRow(menu,1);body.Children.Add(menu);
            Action openLibrary=delegate{OpenWave1Subpage("library");};Action openSaves=delegate{OpenWave1Subpage("saves");};Action openSettings=delegate{OpenWave1Subpage("settings");};Action quickGame=delegate{if(games.Count>0)LaunchGame(games[0],false);else OpenWave1Subpage("settings");};
            Button game=CreateWave1Tile("DS Game Card",games.Count>0?games[0].Name:"No game card library configured","▣",new SolidColorBrush(Color.FromRgb(224,236,245)),new SolidColorBrush(Color.FromRgb(57,81,99)),quickGame,300,115);AddWave1Action(menu,game,"DS Game Card",quickGame,games.Count>0?games[0]:null);
            Button library=CreateWave1Tile("Game Library",games.Count+" titles","▦",new SolidColorBrush(Color.FromRgb(224,236,245)),new SolidColorBrush(Color.FromRgb(57,81,99)),openLibrary,300,115);AddWave1Action(menu,library,"Game Library",openLibrary,null);
            Button saves=CreateWave1Tile("Saved Data","manage DS saves","▤",new SolidColorBrush(Color.FromRgb(224,236,245)),new SolidColorBrush(Color.FromRgb(57,81,99)),openSaves,300,115);AddWave1Action(menu,saves,"Saved Data",openSaves,null);
            Button settingsButton=CreateWave1Tile("Settings","melonDS and system options","⚙",new SolidColorBrush(Color.FromRgb(224,236,245)),new SolidColorBrush(Color.FromRgb(57,81,99)),openSettings,300,115);AddWave1Action(menu,settingsButton,"Settings",openSettings,null);
        }

        private void RenderDsiMenu()
        {
            titleText.Text=String.Empty;subtitleText.Text=String.Empty;columns=5;Grid body=new Grid{Margin=new Thickness(48,0,48,8)};body.RowDefinitions.Add(new RowDefinition{Height=new GridLength(0.39,GridUnitType.Star)});body.RowDefinitions.Add(new RowDefinition{Height=new GridLength(0.61,GridUnitType.Star)});contentHost.Children.Add(body);
            Border top=new Border{Margin=new Thickness(100,0,100,10),CornerRadius=new CornerRadius(12),Background=new LinearGradientBrush(Color.FromRgb(245,246,248),Color.FromRgb(217,225,230),90),BorderBrush=new SolidColorBrush(Color.FromRgb(175,188,196)),BorderThickness=new Thickness(2)};Grid info=new Grid();info.Children.Add(new TextBlock{Text="Nintendo DSi",FontSize=31,FontWeight=FontWeights.Light,Foreground=new SolidColorBrush(Color.FromRgb(80,89,96)),HorizontalAlignment=HorizontalAlignment.Center,VerticalAlignment=VerticalAlignment.Center});info.Children.Add(new TextBlock{Text=DateTime.Now.ToString("M/d/yyyy   h:mm tt",CultureInfo.CurrentCulture),FontSize=14,Foreground=new SolidColorBrush(Color.FromRgb(93,107,116)),HorizontalAlignment=HorizontalAlignment.Right,VerticalAlignment=VerticalAlignment.Top,Margin=new Thickness(0,16,20,0)});top.Child=info;body.Children.Add(top);
            Border lower=new Border{CornerRadius=new CornerRadius(12),Background=Brushes.White,BorderBrush=new SolidColorBrush(Color.FromRgb(184,194,201)),BorderThickness=new Thickness(2),Padding=new Thickness(18)};Grid.SetRow(lower,1);body.Children.Add(lower);ScrollViewer sc=new ScrollViewer{HorizontalScrollBarVisibility=ScrollBarVisibility.Hidden,VerticalScrollBarVisibility=ScrollBarVisibility.Disabled};StackPanel ribbon=new StackPanel{Orientation=Orientation.Horizontal,VerticalAlignment=VerticalAlignment.Center};sc.Content=ribbon;lower.Child=sc;
            foreach(ConsolePlatformGame game in games.Take(16)){ConsolePlatformGame captured=game;Button tile=CreateWave1GameIcon(game,"DSi",Color.FromRgb(67,181,222),155,155,delegate{LaunchGame(captured,false);});AddWave1Action(ribbon,tile,game.Name,delegate{LaunchGame(captured,false);},game);}
            Action lib=delegate{OpenWave1Subpage("library");};Action saves=delegate{OpenWave1Subpage("saves");};Action set=delegate{OpenWave1Subpage("settings");};
            Button l=CreateWave1Tile("Software",games.Count+" titles","▦",new SolidColorBrush(Color.FromRgb(224,242,249)),new SolidColorBrush(Color.FromRgb(53,105,129)),lib,155,155);AddWave1Action(ribbon,l,"Software",lib,null);
            Button d=CreateWave1Tile("Data Management","saves / NAND data","▤",new SolidColorBrush(Color.FromRgb(224,242,249)),new SolidColorBrush(Color.FromRgb(53,105,129)),saves,155,155);AddWave1Action(ribbon,d,"Data Management",saves,null);
            Button s=CreateWave1Tile("System Settings","melonDS DSi","⚙",new SolidColorBrush(Color.FromRgb(224,242,249)),new SolidColorBrush(Color.FromRgb(53,105,129)),set,155,155);AddWave1Action(ribbon,s,"System Settings",set,null);
        }

        private void RenderDreamcastMenu()
        {
            titleText.Text=String.Empty;subtitleText.Text=String.Empty;columns=2;Grid body=new Grid{Margin=new Thickness(150,18,150,18)};body.RowDefinitions.Add(new RowDefinition{Height=new GridLength(64)});body.RowDefinitions.Add(new RowDefinition{Height=new GridLength(1,GridUnitType.Star)});contentHost.Children.Add(body);
            TextBlock date=new TextBlock{Text=DateTime.Now.ToString("M/d/yyyy  HH:mm",CultureInfo.CurrentCulture),FontSize=19,Foreground=new SolidColorBrush(Color.FromRgb(57,65,73)),HorizontalAlignment=HorizontalAlignment.Right,VerticalAlignment=VerticalAlignment.Center};body.Children.Add(date);
            UniformGrid grid=new UniformGrid{Columns=2,Rows=2};Grid.SetRow(grid,1);body.Children.Add(grid);
            Action play=delegate{OpenWave1Subpage("library");};Action file=delegate{OpenWave1Subpage("saves");};Action music=delegate{OpenWave1Subpage("music");};Action settingsAction=delegate{OpenWave1Subpage("settings");};
            Button p=CreateDreamcastMenuTile("Play",games.Count+" games","◉",Color.FromRgb(230,151,92),play);AddWave1Action(grid,p,"Play",play,null);
            Button f=CreateDreamcastMenuTile("File","VMU / saved data","▯",Color.FromRgb(74,190,148),file);AddWave1Action(grid,f,"File",file,null);
            Button m=CreateDreamcastMenuTile("Music","dashboard audio","♪",Color.FromRgb(67,174,224),music);AddWave1Action(grid,m,"Music",music,null);
            Button s=CreateDreamcastMenuTile("Settings",definition.PrimaryBackend,"◷",Color.FromRgb(222,105,184),settingsAction);AddWave1Action(grid,s,"Settings",settingsAction,null);
        }

        private Button CreateDreamcastMenuTile(string title,string detail,string glyph,Color color,Action invoke)
        {
            Button b=new Button{Margin=new Thickness(24),Background=Brushes.Transparent,BorderThickness=new Thickness(0),RenderTransformOrigin=new Point(0.5,0.5)};StackPanel panel=new StackPanel{VerticalAlignment=VerticalAlignment.Center};Border icon=new Border{Width=150,Height=118,CornerRadius=new CornerRadius(60),Background=new SolidColorBrush(Color.FromArgb(150,color.R,color.G,color.B)),BorderBrush=new SolidColorBrush(color),BorderThickness=new Thickness(5),HorizontalAlignment=HorizontalAlignment.Center,Child=new TextBlock{Text=glyph,FontSize=58,Foreground=Brushes.White,HorizontalAlignment=HorizontalAlignment.Center,VerticalAlignment=VerticalAlignment.Center}};panel.Children.Add(icon);Border label=new Border{MinWidth=180,Height=44,CornerRadius=new CornerRadius(22),Background=new SolidColorBrush(color),Margin=new Thickness(0,-4,0,0),HorizontalAlignment=HorizontalAlignment.Center,Child=new TextBlock{Text=title,FontSize=25,Foreground=Brushes.White,HorizontalAlignment=HorizontalAlignment.Center,VerticalAlignment=VerticalAlignment.Center}};panel.Children.Add(label);panel.Children.Add(new TextBlock{Text=detail,FontSize=10,Foreground=new SolidColorBrush(Color.FromRgb(55,72,86)),HorizontalAlignment=HorizontalAlignment.Center,Margin=new Thickness(0,5,0,0)});b.Content=panel;b.Click+=delegate{invoke();};return b;
        }

        private void RenderSaturnMenu()
        {
            titleText.Text=String.Empty;subtitleText.Text=String.Empty;columns=2;Grid body=new Grid{Margin=new Thickness(140,24,140,20)};contentHost.Children.Add(body);System.Windows.Shapes.Ellipse orbit=new System.Windows.Shapes.Ellipse{Stroke=new SolidColorBrush(Color.FromArgb(90,92,202,255)),StrokeThickness=5,Margin=new Thickness(50)};body.Children.Add(orbit);UniformGrid grid=new UniformGrid{Columns=2,Rows=2,Margin=new Thickness(90,50,90,50)};body.Children.Add(grid);
            Action app=delegate{OpenWave1Subpage("library");};Action cd=delegate{OpenWave1Subpage("music");};Action memory=delegate{OpenWave1Subpage("saves");};Action settingsAction=delegate{OpenWave1Subpage("settings");};
            Button a=CreateSaturnOrb("Start Application",games.Count+" discs","▶",Color.FromRgb(34,162,225),app);AddWave1Action(grid,a,"Start Application",app,null);
            Button c=CreateSaturnOrb("CD Player","audio controls","♪",Color.FromRgb(89,200,198),cd);AddWave1Action(grid,c,"CD Player",cd,null);
            Button m=CreateSaturnOrb("Memory Manager","backup memory","▣",Color.FromRgb(239,67,129),memory);AddWave1Action(grid,m,"Memory Manager",memory,null);
            Button s=CreateSaturnOrb("System Settings",definition.PrimaryBackend,"⚙",Color.FromRgb(243,169,61),settingsAction);AddWave1Action(grid,s,"System Settings",settingsAction,null);
        }

        private Button CreateSaturnOrb(string title,string detail,string glyph,Color color,Action invoke)
        {
            Button b=new Button{Margin=new Thickness(24),Background=Brushes.Transparent,BorderThickness=new Thickness(0),RenderTransformOrigin=new Point(0.5,0.5)};StackPanel s=new StackPanel{VerticalAlignment=VerticalAlignment.Center};Border orb=new Border{Width=132,Height=132,CornerRadius=new CornerRadius(66),Background=new RadialGradientBrush(Color.FromArgb(245,(byte)Math.Min(255,color.R+30),(byte)Math.Min(255,color.G+30),(byte)Math.Min(255,color.B+30)),Color.FromArgb(225,(byte)(color.R/2),(byte)(color.G/2),(byte)(color.B/2))),BorderBrush=Brushes.White,BorderThickness=new Thickness(2),HorizontalAlignment=HorizontalAlignment.Center,Child=new TextBlock{Text=glyph,FontSize=48,Foreground=Brushes.White,HorizontalAlignment=HorizontalAlignment.Center,VerticalAlignment=VerticalAlignment.Center}};s.Children.Add(orb);s.Children.Add(new TextBlock{Text=title,FontSize=18,FontWeight=FontWeights.SemiBold,Foreground=Brushes.White,HorizontalAlignment=HorizontalAlignment.Center,Margin=new Thickness(0,6,0,0)});s.Children.Add(new TextBlock{Text=detail,FontSize=10,Foreground=new SolidColorBrush(Color.FromRgb(188,218,235)),HorizontalAlignment=HorizontalAlignment.Center});b.Content=s;b.Click+=delegate{invoke();};return b;
        }

        private void ProcessPspXmbCommand(XmbInputCommand command)
        {
            string[] categories=new string[]{"Settings","Photo","Music","Video","Game"};
            if(command==XmbInputCommand.Back){PlayEffect("Back.wav");Close();return;}
            if(command==XmbInputCommand.Left||command==XmbInputCommand.Right){int next=Math.Max(0,Math.Min(categories.Length-1,pspCategoryIndex+(command==XmbInputCommand.Left?-1:1)));if(next!=pspCategoryIndex){pspCategoryIndex=next;pspItemIndex=0;PlayEffect("Navigate.wav");RenderPage();}return;}
            List<ConsolePlatformAction> visible=actions;
            if(command==XmbInputCommand.Up||command==XmbInputCommand.Down){int next=Math.Max(0,Math.Min(Math.Max(0,visible.Count-1),pspItemIndex+(command==XmbInputCommand.Up?-1:1)));if(next!=pspItemIndex){pspItemIndex=next;selected=next;PlayEffect("Navigate.wav");UpdateActionVisuals();}return;}
            if(command==XmbInputCommand.Confirm&&visible.Count>0){selected=Math.Max(0,Math.Min(visible.Count-1,pspItemIndex));PlayEffect("Confirm.wav");if(visible[selected].Invoke!=null)visible[selected].Invoke();}
        }

        private void RenderPspXmb()
        {
            titleText.Text=String.Empty;subtitleText.Text=String.Empty;columns=1;string[] cats=new string[]{"Settings","Photo","Music","Video","Game"};string[] glyphs=new string[]{"⚙","▧","♪","▶","◉"};pspCategoryIndex=Math.Max(0,Math.Min(cats.Length-1,pspCategoryIndex));
            Grid body=new Grid{Margin=new Thickness(60,36,60,20)};body.RowDefinitions.Add(new RowDefinition{Height=new GridLength(180)});body.RowDefinitions.Add(new RowDefinition{Height=new GridLength(1,GridUnitType.Star)});contentHost.Children.Add(body);StackPanel categoryRow=new StackPanel{Orientation=Orientation.Horizontal,HorizontalAlignment=HorizontalAlignment.Center,VerticalAlignment=VerticalAlignment.Center};body.Children.Add(categoryRow);
            for(int i=0;i<cats.Length;i++){bool active=i==pspCategoryIndex;StackPanel c=new StackPanel{Width=150,Opacity=active?1.0:0.42};c.Children.Add(new TextBlock{Text=glyphs[i],FontSize=active?58:42,Foreground=Brushes.White,HorizontalAlignment=HorizontalAlignment.Center});c.Children.Add(new TextBlock{Text=cats[i],FontSize=active?18:13,FontWeight=active?FontWeights.SemiBold:FontWeights.Normal,Foreground=Brushes.White,HorizontalAlignment=HorizontalAlignment.Center});categoryRow.Children.Add(c);}
            StackPanel list=new StackPanel{Margin=new Thickness(310,8,190,0)};Grid.SetRow(list,1);body.Children.Add(list);
            if(pspCategoryIndex==4){foreach(ConsolePlatformGame game in games){ConsolePlatformGame captured=game;Button b=CreatePspXmbRow(game.Name,"Memory Stick / UMD image",delegate{LaunchGame(captured,false);});list.Children.Add(b);actions.Add(new ConsolePlatformAction{Button=b,Name=game.Name,Game=game,Invoke=delegate{LaunchGame(captured,false);}});}if(games.Count==0)AddPspAction(list,"Game Library","Choose a PSP game folder",delegate{OpenWave1Subpage("settings");});}
            else if(pspCategoryIndex==0){AddPspAction(list,"PPSSPP Settings","Graphics, audio, controls, networking, system and advanced",delegate{OpenWave1Subpage("settings");});AddPspAction(list,"Saved Data Utility","PSP saved data",delegate{OpenWave1Subpage("saves");});AddPspAction(list,"System Information",definition.PrimaryBackend,delegate{OpenWave1Subpage("info");});}
            else if(pspCategoryIndex==1){AddPspAction(list,"Photo","No photo folder configured",delegate{OpenWave1Subpage("media");});}
            else if(pspCategoryIndex==2){AddPspAction(list,"Music",String.IsNullOrWhiteSpace(settings.ambiencePath)?"No music configured":Path.GetFileName(settings.ambiencePath),delegate{OpenWave1Subpage("music");});}
            else if(pspCategoryIndex==3){AddPspAction(list,"Video","No video folder configured",delegate{OpenWave1Subpage("media");});}
            pspItemIndex=Math.Max(0,Math.Min(Math.Max(0,actions.Count-1),pspItemIndex));selected=pspItemIndex;
        }

        private Button CreatePspXmbRow(string title,string detail,Action invoke)
        {
            Button b=new Button{Height=72,Margin=new Thickness(0,3,0,3),Padding=new Thickness(18,5,18,5),HorizontalContentAlignment=HorizontalAlignment.Left,Background=new SolidColorBrush(Color.FromArgb(55,255,255,255)),BorderBrush=new SolidColorBrush(Color.FromArgb(90,255,255,255)),BorderThickness=new Thickness(0,0,0,1),RenderTransformOrigin=new Point(0.5,0.5)};StackPanel s=new StackPanel();s.Children.Add(new TextBlock{Text=title,FontSize=19,Foreground=Brushes.White});s.Children.Add(new TextBlock{Text=detail,FontSize=10,Foreground=new SolidColorBrush(Color.FromArgb(190,255,255,255)),TextTrimming=TextTrimming.CharacterEllipsis});b.Content=s;b.Click+=delegate{invoke();};return b;
        }

        private void AddPspAction(Panel panel,string title,string detail,Action invoke)
        {
            Button b=CreatePspXmbRow(title,detail,invoke);panel.Children.Add(b);actions.Add(new ConsolePlatformAction{Button=b,Name=title,Invoke=invoke});
        }

        private void RenderWave1Subpage()
        {
            if(dashboardSubpage=="backend-settings"){RenderBackendSettingsCategories();return;}
            if(dashboardSubpage=="backend-settings-list"){RenderBackendSettingsList();return;}
            if(dashboardSubpage=="backend-setting-detail"){RenderBackendSettingDetail();return;}
            if(dashboardSubpage=="library"){RenderWave1Library();return;}
            if(dashboardSubpage=="saves"){RenderWave1Storage();return;}
            if(dashboardSubpage=="music"){RenderWave1Music();return;}
            if(dashboardSubpage=="media"){RenderWave1Media();return;}
            if(dashboardSubpage=="info"){RenderWave1Info();return;}
            RenderWave1Settings();
        }

        private void RenderWave1Library()
        {
            titleText.Text=definition.Shell=="PSP"?"Game":"Software Library";subtitleText.Text=games.Count.ToString(CultureInfo.InvariantCulture)+" titles";columns=6;ScrollViewer scroll=new ScrollViewer{VerticalScrollBarVisibility=ScrollBarVisibility.Hidden,HorizontalScrollBarVisibility=ScrollBarVisibility.Disabled};WrapPanel wrap=new WrapPanel{Margin=new Thickness(12)};scroll.Content=wrap;contentHost.Children.Add(scroll);foreach(ConsolePlatformGame game in games){ConsolePlatformGame captured=game;Button b=CreateGameButton(game,delegate{LaunchGame(captured,false);});wrap.Children.Add(b);actions.Add(new ConsolePlatformAction{Button=b,Invoke=delegate{LaunchGame(captured,false);},Name=game.Name,Game=game});}if(games.Count==0)AddRoundedStorage(wrap,"No software found","Add a game folder from this console's system settings",definition.Accent,delegate{dashboardSubpage="settings";selected=0;RenderPage();});
        }

        private void RenderWave1Storage()
        {
            if (definition.Shell == "PSP") { RenderPspSavedDataUtility(); return; }
            if (definition.Shell == "Dreamcast") { RenderDreamcastVmuManager(); return; }
            if (definition.Shell == "Saturn") { RenderSaturnMemoryManager(); return; }
            if (definition.Shell == "NDS") { RenderDsSavedData(false); return; }
            if (definition.Shell == "DSI") { RenderDsSavedData(true); return; }
            if (definition.Shell == "3DS") { Render3dsDataManagement(); return; }
            titleText.Text="Saved Data"; subtitleText.Text="Native storage view for "+definition.DisplayName;
            StackPanel panel=new StackPanel{Margin=new Thickness(36,8,36,24)};contentHost.Children.Add(new ScrollViewer{VerticalScrollBarVisibility=ScrollBarVisibility.Hidden,Content=panel});
            List<string> roots=FindSaveRoots();if(roots.Count==0)AddRoundedStorage(panel,"No saved data detected","Configure the emulator data path in system settings",definition.Accent,delegate{dashboardSubpage="settings";selected=0;RenderPage();});else foreach(string rootPath in roots){string captured=rootPath;AddRoundedStorage(panel,Path.GetFileName(rootPath.TrimEnd(Path.DirectorySeparatorChar)),rootPath,definition.Accent,delegate{BackupNativeSavePath(captured,definition.Id+"-SavedData");});}
        }


        private List<string> GetUniqueExistingPaths(IEnumerable<string> paths)
        {
            List<string> result = new List<string>();
            foreach (string value in paths ?? Enumerable.Empty<string>())
            {
                if (String.IsNullOrWhiteSpace(value)) continue;
                string pathValue = value;
                try { pathValue = Path.GetFullPath(Environment.ExpandEnvironmentVariables(value)); } catch { }
                if ((!File.Exists(pathValue) && !Directory.Exists(pathValue)) || result.Contains(pathValue, StringComparer.OrdinalIgnoreCase)) continue;
                result.Add(pathValue);
            }
            return result;
        }

        private static DateTime GetPathModifiedUtcSafe(string pathValue)
        {
            try { return File.Exists(pathValue) ? File.GetLastWriteTime(pathValue) : Directory.GetLastWriteTime(pathValue); } catch { return DateTime.MinValue; }
        }

        private static string ReadPspSfoString(string sfoPath, string wantedKey)
        {
            if (String.IsNullOrWhiteSpace(sfoPath) || !File.Exists(sfoPath) || String.IsNullOrWhiteSpace(wantedKey)) return String.Empty;
            try
            {
                byte[] data = File.ReadAllBytes(sfoPath); if (data.Length < 20) return String.Empty;
                Func<int, ushort> u16 = delegate(int offset) { return (ushort)(data[offset] | (data[offset + 1] << 8)); };
                Func<int, uint> u32 = delegate(int offset) { return (uint)(data[offset] | (data[offset + 1] << 8) | (data[offset + 2] << 16) | (data[offset + 3] << 24)); };
                if (u32(0) != 0x46535000) return String.Empty;
                int keyTable = (int)u32(8); int valueTable = (int)u32(12); int count = (int)u32(16);
                if (keyTable < 20 || valueTable < keyTable || count < 0 || count > 512) return String.Empty;
                for (int i = 0; i < count; i++)
                {
                    int entry = 20 + i * 16; if (entry + 16 > data.Length) break;
                    int keyOffset = keyTable + u16(entry); int length = (int)u32(entry + 4); int valueOffset = valueTable + (int)u32(entry + 12);
                    if (keyOffset < 0 || keyOffset >= data.Length || valueOffset < 0 || valueOffset >= data.Length) continue;
                    int keyEnd = keyOffset; while (keyEnd < data.Length && data[keyEnd] != 0) keyEnd++;
                    string key = Encoding.UTF8.GetString(data, keyOffset, Math.Max(0, keyEnd - keyOffset));
                    if (!String.Equals(key, wantedKey, StringComparison.Ordinal)) continue;
                    int available = Math.Min(Math.Max(0, length), data.Length - valueOffset); if (available <= 0) return String.Empty;
                    int end = valueOffset; int limit = valueOffset + available; while (end < limit && data[end] != 0) end++;
                    return Encoding.UTF8.GetString(data, valueOffset, Math.Max(0, end - valueOffset)).Trim();
                }
            }
            catch { }
            return String.Empty;
        }

        private Button CreatePspSaveTile(string title, string subtitle, string iconPath, string detail, Action invoke)
        {
            Button button = new Button { Width = 245, Height = 150, Margin = new Thickness(9), Padding = new Thickness(0), Background = new SolidColorBrush(Color.FromArgb(86, 255, 255, 255)), BorderBrush = new SolidColorBrush(Color.FromArgb(170, 145, 218, 255)), BorderThickness = new Thickness(2), RenderTransformOrigin = new Point(0.5, 0.5) };
            Grid layout = new Grid(); layout.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(96) }); layout.ColumnDefinitions.Add(new ColumnDefinition());
            Border imageFrame = new Border { Width = 82, Height = 82, Margin = new Thickness(9), CornerRadius = new CornerRadius(6), Background = new SolidColorBrush(Color.FromArgb(70, 0, 20, 50)), VerticalAlignment = VerticalAlignment.Top };
            if (!String.IsNullOrWhiteSpace(iconPath) && File.Exists(iconPath)) { try { imageFrame.Child = new Image { Source = LoadBitmap(iconPath), Stretch = Stretch.UniformToFill }; } catch { } }
            if (imageFrame.Child == null) imageFrame.Child = new TextBlock { Text = "SAVE", FontSize = 15, FontWeight = FontWeights.Bold, Foreground = Brushes.White, HorizontalAlignment = HorizontalAlignment.Center, VerticalAlignment = VerticalAlignment.Center };
            layout.Children.Add(imageFrame);
            StackPanel info = new StackPanel { Margin = new Thickness(8, 12, 10, 8) }; Grid.SetColumn(info, 1);
            info.Children.Add(new TextBlock { Text = title, FontSize = 15, FontWeight = FontWeights.SemiBold, Foreground = Brushes.White, TextWrapping = TextWrapping.Wrap, MaxHeight = 42 });
            if (!String.IsNullOrWhiteSpace(subtitle)) info.Children.Add(new TextBlock { Text = subtitle, FontSize = 10, Foreground = new SolidColorBrush(Color.FromArgb(205, 255, 255, 255)), TextTrimming = TextTrimming.CharacterEllipsis, Margin = new Thickness(0, 4, 0, 0) });
            info.Children.Add(new TextBlock { Text = detail, FontSize = 9, Foreground = new SolidColorBrush(Color.FromArgb(165, 255, 255, 255)), TextWrapping = TextWrapping.Wrap, Margin = new Thickness(0, 4, 0, 0) });
            layout.Children.Add(info); button.Content = layout; button.Click += delegate { invoke(); }; return button;
        }

        private void RenderPspSavedDataUtility()
        {
            titleText.Text = "Saved Data Utility"; subtitleText.Text = "Memory Stick™  •  PSP saved data"; columns = 3;
            ScrollViewer scroll = new ScrollViewer { VerticalScrollBarVisibility = ScrollBarVisibility.Hidden, HorizontalScrollBarVisibility = ScrollBarVisibility.Disabled }; WrapPanel panel = new WrapPanel { Margin = new Thickness(28, 5, 28, 24) }; scroll.Content = panel; contentHost.Children.Add(scroll);
            List<string> roots = FindSaveRoots(); List<string> saveFolders = new List<string>();
            foreach (string rootPath in roots)
            {
                string candidate = rootPath;
                if (!String.Equals(Path.GetFileName(candidate.TrimEnd(Path.DirectorySeparatorChar)), "SAVEDATA", StringComparison.OrdinalIgnoreCase))
                {
                    string nested = Path.Combine(candidate, "PSP", "SAVEDATA"); if (Directory.Exists(nested)) candidate = nested;
                }
                if (!Directory.Exists(candidate)) continue;
                try { foreach (string dir in Directory.GetDirectories(candidate)) if (!saveFolders.Contains(dir, StringComparer.OrdinalIgnoreCase)) saveFolders.Add(dir); } catch { }
            }
            saveFolders = saveFolders.OrderBy(delegate(string p) { return GetPathModifiedUtcSafe(p); }).Reverse().ToList();
            foreach (string savePath in saveFolders.Take(300))
            {
                string captured = savePath; string id = Path.GetFileName(savePath); string title = ReadPspSfoString(Path.Combine(savePath, "PARAM.SFO"), "TITLE"); string savedTitle = ReadPspSfoString(Path.Combine(savePath, "PARAM.SFO"), "SAVEDATA_TITLE");
                if (String.IsNullOrWhiteSpace(title)) title = id; string detail = FormatBytes(GetPathSize(savePath)) + "  •  " + GetPathModifiedUtcSafe(savePath).ToString("g", CultureInfo.CurrentCulture);
                Button tile = CreatePspSaveTile(title, savedTitle, Path.Combine(savePath, "ICON0.PNG"), detail, delegate { BackupNativeSavePath(captured, "PSP-" + Path.GetFileName(captured)); });
                panel.Children.Add(tile); actions.Add(new ConsolePlatformAction { Button = tile, Name = title, Invoke = delegate { BackupNativeSavePath(captured, "PSP-" + Path.GetFileName(captured)); } });
            }
            if (saveFolders.Count == 0) AddRoundedStorage(panel, "No Saved Data", "PPSSPP Memory Stick / PSP / SAVEDATA was not found. Set the PPSSPP data path in System Settings.", definition.Accent, delegate { dashboardSubpage = "settings"; selected = 0; RenderPage(); });
            else AddRoundedStorage(panel, "Back Up All Saved Data", saveFolders.Count.ToString(CultureInfo.InvariantCulture) + " save folder(s)", definition.Accent, BackupSaves);
        }

        private List<string> FindDreamcastVmuImages()
        {
            List<string> found = new List<string>();
            foreach (string rootPath in FindSaveRoots())
            {
                if (!Directory.Exists(rootPath)) continue;
                try
                {
                    foreach (string file in Directory.EnumerateFiles(rootPath, "vmu_save_*.bin", SearchOption.AllDirectories).Take(64)) if (!found.Contains(file, StringComparer.OrdinalIgnoreCase)) found.Add(file);
                }
                catch { }
            }
            return found.OrderBy(delegate(string pathValue) { return Path.GetFileName(pathValue); }, StringComparer.OrdinalIgnoreCase).ToList();
        }

        private Button CreateDreamcastVmuCard(string pathValue, Action invoke)
        {
            string name = Path.GetFileNameWithoutExtension(pathValue); string slot = name.StartsWith("vmu_save_", StringComparison.OrdinalIgnoreCase) ? name.Substring("vmu_save_".Length).ToUpperInvariant() : name.ToUpperInvariant();
            Button button = new Button { Width = 220, Height = 260, Margin = new Thickness(18), Padding = new Thickness(8), Background = Brushes.Transparent, BorderThickness = new Thickness(0), RenderTransformOrigin = new Point(0.5, 0.5) };
            Grid shell = new Grid { Background = Brushes.Transparent }; Border body = new Border { Width = 174, Height = 218, CornerRadius = new CornerRadius(18, 18, 30, 30), Background = new LinearGradientBrush(Color.FromRgb(239, 242, 244), Color.FromRgb(183, 195, 203), 90), BorderBrush = new SolidColorBrush(Color.FromRgb(93, 120, 138)), BorderThickness = new Thickness(3), HorizontalAlignment = HorizontalAlignment.Center, VerticalAlignment = VerticalAlignment.Top };
            StackPanel stack = new StackPanel { Margin = new Thickness(14) }; stack.Children.Add(new TextBlock { Text = "VISUAL MEMORY", FontSize = 9, FontWeight = FontWeights.Bold, Foreground = new SolidColorBrush(Color.FromRgb(64, 83, 94)), HorizontalAlignment = HorizontalAlignment.Center });
            Border screen = new Border { Width = 112, Height = 72, Margin = new Thickness(0, 12, 0, 8), Background = new SolidColorBrush(Color.FromRgb(121, 153, 145)), BorderBrush = new SolidColorBrush(Color.FromRgb(44, 63, 61)), BorderThickness = new Thickness(5), Child = new TextBlock { Text = slot, FontFamily = new FontFamily("Consolas"), FontSize = 28, FontWeight = FontWeights.Bold, Foreground = new SolidColorBrush(Color.FromRgb(24, 47, 41)), HorizontalAlignment = HorizontalAlignment.Center, VerticalAlignment = VerticalAlignment.Center } }; stack.Children.Add(screen);
            stack.Children.Add(new TextBlock { Text = FormatBytes(GetPathSize(pathValue)), FontSize = 11, Foreground = new SolidColorBrush(Color.FromRgb(64, 83, 94)), HorizontalAlignment = HorizontalAlignment.Center }); stack.Children.Add(new TextBlock { Text = GetPathModifiedUtcSafe(pathValue).ToString("g", CultureInfo.CurrentCulture), FontSize = 9, Foreground = new SolidColorBrush(Color.FromRgb(83, 101, 112)), HorizontalAlignment = HorizontalAlignment.Center, Margin = new Thickness(0, 3, 0, 0) });
            body.Child = stack; shell.Children.Add(body); TextBlock hint = new TextBlock { Text = "A  Back Up VMU", FontSize = 10, Foreground = new SolidColorBrush(Color.FromRgb(55, 72, 86)), HorizontalAlignment = HorizontalAlignment.Center, VerticalAlignment = VerticalAlignment.Bottom }; shell.Children.Add(hint); button.Content = shell; button.Click += delegate { invoke(); }; return button;
        }

        private void RenderDreamcastVmuManager()
        {
            titleText.Text = "File"; subtitleText.Text = "Visual Memory Unit manager"; columns = 4;
            ScrollViewer scroll = new ScrollViewer { VerticalScrollBarVisibility = ScrollBarVisibility.Hidden, HorizontalScrollBarVisibility = ScrollBarVisibility.Disabled }; WrapPanel panel = new WrapPanel { Margin = new Thickness(45, 8, 45, 24) }; scroll.Content = panel; contentHost.Children.Add(scroll);
            List<string> vmus = FindDreamcastVmuImages(); foreach (string pathValue in vmus) { string captured = pathValue; Button card = CreateDreamcastVmuCard(pathValue, delegate { BackupNativeSavePath(captured, "Dreamcast-" + Path.GetFileNameWithoutExtension(captured)); }); panel.Children.Add(card); actions.Add(new ConsolePlatformAction { Button = card, Name = Path.GetFileNameWithoutExtension(pathValue), Invoke = delegate { BackupNativeSavePath(captured, "Dreamcast-" + Path.GetFileNameWithoutExtension(captured)); } }); }
            if (vmus.Count == 0) AddRoundedStorage(panel, "No VMUs Detected", "Flycast VMU images (vmu_save_*.bin) were not found. Set the Flycast data path in Settings or run a Dreamcast game once.", Color.FromRgb(74,190,148), delegate { dashboardSubpage = "settings"; selected = 0; RenderPage(); });
            else AddRoundedStorage(panel, "Back Up All VMUs", vmus.Count.ToString(CultureInfo.InvariantCulture) + " VMU image(s)", Color.FromRgb(74,190,148), BackupSaves);
        }

        private void RenderSaturnMemoryManager()
        {
            titleText.Text = "Memory Manager"; subtitleText.Text = "Internal backup memory and cartridge save files"; columns = 2;
            StackPanel panel = new StackPanel { Margin = new Thickness(100, 8, 100, 28) }; contentHost.Children.Add(new ScrollViewer { VerticalScrollBarVisibility = ScrollBarVisibility.Hidden, Content = panel });
            List<string> saves = new List<string>(); foreach (string rootPath in FindSaveRoots()) { if (!Directory.Exists(rootPath)) continue; try { foreach (string file in Directory.EnumerateFiles(rootPath, "*", SearchOption.TopDirectoryOnly)) { string ext = Path.GetExtension(file).ToLowerInvariant(); if (ext == ".bkr" || ext == ".bcr" || ext == ".sav" || ext == ".srm" || ext == ".nv" || ext == ".ram") if (!saves.Contains(file, StringComparer.OrdinalIgnoreCase)) saves.Add(file); } } catch { } }
            saves = saves.OrderBy(delegate(string pathValue) { return Path.GetFileName(pathValue); }, StringComparer.OrdinalIgnoreCase).ToList();
            foreach (string file in saves) { string captured = file; string ext = Path.GetExtension(file).TrimStart('.').ToUpperInvariant(); string title = Path.GetFileNameWithoutExtension(file); string detail = ext + " BACKUP MEMORY  •  " + FormatBytes(GetPathSize(file)) + "  •  " + GetPathModifiedUtcSafe(file).ToString("g", CultureInfo.CurrentCulture); AddRoundedStorage(panel, title, detail, Color.FromRgb(239,67,129), delegate { BackupNativeSavePath(captured, "Saturn-" + Path.GetFileNameWithoutExtension(captured)); }); }
            if (saves.Count == 0) AddRoundedStorage(panel, "No Backup Memory Found", "Mednafen's sav directory has no Saturn nonvolatile save files yet. Configure Mednafen and start a game once.", Color.FromRgb(239,67,129), delegate { dashboardSubpage = "settings"; selected = 0; RenderPage(); });
            else AddRoundedStorage(panel, "Back Up All Memory", saves.Count.ToString(CultureInfo.InvariantCulture) + " nonvolatile file(s)", Color.FromRgb(34,162,225), BackupSaves);
        }

        private List<KeyValuePair<ConsolePlatformGame, string>> FindDsSidecarSaves()
        {
            List<KeyValuePair<ConsolePlatformGame, string>> result = new List<KeyValuePair<ConsolePlatformGame, string>>(); HashSet<string> seen = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            foreach (ConsolePlatformGame game in games)
            {
                if (game == null || String.IsNullOrWhiteSpace(game.Path)) continue;
                foreach (string ext in new string[] { ".sav", ".dsv" })
                {
                    string candidate; try { candidate = Path.ChangeExtension(game.Path, ext); } catch { continue; }
                    if (File.Exists(candidate) && seen.Add(candidate)) { result.Add(new KeyValuePair<ConsolePlatformGame, string>(game, candidate)); break; }
                }
            }
            foreach (string rootPath in FindSaveRoots())
            {
                if (!Directory.Exists(rootPath)) continue;
                try { foreach (string file in Directory.EnumerateFiles(rootPath, "*.sav", SearchOption.TopDirectoryOnly).Take(500)) if (seen.Add(file)) result.Add(new KeyValuePair<ConsolePlatformGame, string>(null, file)); } catch { }
            }
            return result.OrderBy(delegate(KeyValuePair<ConsolePlatformGame,string> pair) { return pair.Key == null ? Path.GetFileNameWithoutExtension(pair.Value) : pair.Key.Name; }, StringComparer.OrdinalIgnoreCase).ToList();
        }

        private void RenderDsSavedData(bool dsi)
        {
            titleText.Text = dsi ? "Data Management" : "Saved Data"; subtitleText.Text = dsi ? "Nintendo DSi system memory and DS software saves" : "Nintendo DS game-card save data"; columns = 2;
            Grid body = new Grid { Margin = new Thickness(90, 4, 90, 22) }; body.RowDefinitions.Add(new RowDefinition { Height = new GridLength(dsi ? 120 : 84) }); body.RowDefinitions.Add(new RowDefinition { Height = new GridLength(1, GridUnitType.Star) }); contentHost.Children.Add(body);
            Border header = new Border { CornerRadius = new CornerRadius(12), Background = new SolidColorBrush(dsi ? Color.FromRgb(232,247,252) : Color.FromRgb(228,239,247)), BorderBrush = new SolidColorBrush(dsi ? Color.FromRgb(67,181,222) : Color.FromRgb(70,145,202)), BorderThickness = new Thickness(2), Padding = new Thickness(18) };
            header.Child = new TextBlock { Text = dsi ? "SYSTEM MEMORY\nManage locally emulated DSi data without exposing dead DSi Shop services." : "GAME CARD SAVE MEMORY\nSaved data remains paired with its DS software image.", FontSize = 15, Foreground = new SolidColorBrush(Color.FromRgb(61,84,99)), TextAlignment = TextAlignment.Center, HorizontalAlignment = HorizontalAlignment.Center, VerticalAlignment = VerticalAlignment.Center }; body.Children.Add(header);
            StackPanel list = new StackPanel { Margin = new Thickness(0, 10, 0, 0) }; ScrollViewer scroll = new ScrollViewer { VerticalScrollBarVisibility = ScrollBarVisibility.Hidden, Content = list }; Grid.SetRow(scroll, 1); body.Children.Add(scroll);
            List<KeyValuePair<ConsolePlatformGame,string>> saves = FindDsSidecarSaves(); foreach (KeyValuePair<ConsolePlatformGame,string> pair in saves) { string captured = pair.Value; string name = pair.Key == null ? Path.GetFileNameWithoutExtension(pair.Value) : pair.Key.Name; AddRoundedStorage(list, name, FormatBytes(GetPathSize(pair.Value)) + "  •  " + Path.GetFileName(pair.Value) + "  •  " + GetPathModifiedUtcSafe(pair.Value).ToString("g", CultureInfo.CurrentCulture), dsi ? Color.FromRgb(67,181,222) : Color.FromRgb(70,145,202), delegate { BackupNativeSavePath(captured, (dsi ? "DSi-" : "DS-") + Path.GetFileNameWithoutExtension(captured)); }); }
            if (dsi) { foreach (string rootPath in FindSaveRoots().Where(delegate(string p) { return p.IndexOf("NAND", StringComparison.OrdinalIgnoreCase) >= 0; })) { string captured = rootPath; AddRoundedStorage(list, "Nintendo DSi System Memory", FormatBytes(GetPathSize(rootPath)) + "  •  NAND data", Color.FromRgb(239,157,56), delegate { BackupNativeSavePath(captured, "DSi-SystemMemory"); }); } }
            if (saves.Count == 0 && (!dsi || !FindSaveRoots().Any(delegate(string p) { return p.IndexOf("NAND", StringComparison.OrdinalIgnoreCase) >= 0; }))) AddRoundedStorage(list, "No Saved Data Detected", "Choose the melonDS data path or launch software once to create save data.", dsi ? Color.FromRgb(67,181,222) : Color.FromRgb(70,145,202), delegate { dashboardSubpage = "settings"; selected = 0; RenderPage(); });
        }

        private void Render3dsDataManagement()
        {
            titleText.Text = "Data Management"; subtitleText.Text = "Nintendo 3DS emulated system storage"; columns = 2;
            Grid body = new Grid { Margin = new Thickness(75, 0, 75, 20) }; body.RowDefinitions.Add(new RowDefinition { Height = new GridLength(145) }); body.RowDefinitions.Add(new RowDefinition { Height = new GridLength(1, GridUnitType.Star) }); contentHost.Children.Add(body);
            Border top = new Border { Margin = new Thickness(80, 0, 80, 10), CornerRadius = new CornerRadius(12), Background = new LinearGradientBrush(Color.FromRgb(239,243,246), Color.FromRgb(211,220,227), 90), BorderBrush = new SolidColorBrush(Color.FromRgb(164,177,187)), BorderThickness = new Thickness(2) };
            top.Child = new TextBlock { Text = "DATA MANAGEMENT", FontSize = 25, FontWeight = FontWeights.Light, Foreground = new SolidColorBrush(Color.FromRgb(66,80,91)), HorizontalAlignment = HorizontalAlignment.Center, VerticalAlignment = VerticalAlignment.Center }; body.Children.Add(top);
            UniformGrid cards = new UniformGrid { Columns = 2, Rows = 2, Margin = new Thickness(40, 5, 40, 0) }; Grid.SetRow(cards, 1); body.Children.Add(cards);
            List<string> roots = FindSaveRoots(); List<string> sdmc = roots.Where(delegate(string p) { return String.Equals(Path.GetFileName(p.TrimEnd(Path.DirectorySeparatorChar)), "sdmc", StringComparison.OrdinalIgnoreCase); }).ToList(); List<string> nand = roots.Where(delegate(string p) { return p.IndexOf("nand", StringComparison.OrdinalIgnoreCase) >= 0; }).ToList();
            Action backupSd = delegate { foreach (string value in sdmc) BackupNativeSavePath(value, "3DS-SDMC"); }; Action backupNand = delegate { foreach (string value in nand) BackupNativeSavePath(value, "3DS-NAND"); };
            Button sd = CreateWave1Tile("SD Card", sdmc.Count == 0 ? "Not detected" : FormatBytes(sdmc.Sum(delegate(string p) { return GetPathSize(p); })), "SD", new SolidColorBrush(Color.FromRgb(91,168,219)), Brushes.White, backupSd, 330, 150); AddWave1Action(cards, sd, "SD Card", backupSd, null);
            Button system = CreateWave1Tile("System Memory", nand.Count == 0 ? "Not detected" : FormatBytes(nand.Sum(delegate(string p) { return GetPathSize(p); })), "▣", new SolidColorBrush(Color.FromRgb(239,157,56)), Brushes.White, backupNand, 330, 150); AddWave1Action(cards, system, "System Memory", backupNand, null);
            Action refresh = delegate { RenderPage(); }; Button refreshButton = CreateWave1Tile("Refresh Data", "Rescan Azahar storage", "↻", new SolidColorBrush(Color.FromRgb(91,101,111)), Brushes.White, refresh, 330, 150); AddWave1Action(cards, refreshButton, "Refresh Data", refresh, null);
            Action settingsAction = delegate { dashboardSubpage = "settings"; selected = 0; RenderPage(); }; Button settingsButton = CreateWave1Tile("Storage Settings", "Azahar data path", "⚙", new SolidColorBrush(Color.FromRgb(103,146,106)), Brushes.White, settingsAction, 330, 150); AddWave1Action(cards, settingsButton, "Storage Settings", settingsAction, null);
        }

        private void RenderWave1Music()
        {
            titleText.Text=definition.Shell=="Dreamcast"?"Music":(definition.Shell=="Saturn"?"CD Player":"Music");subtitleText.Text="Local audio controls";WrapPanel panel=new WrapPanel{Margin=new Thickness(36,20,36,20)};contentHost.Children.Add(panel);AddRoundedStorage(panel,"Audio Source",String.IsNullOrWhiteSpace(settings.ambiencePath)?"Choose local audio":Path.GetFileName(settings.ambiencePath),definition.Accent,ChooseAmbience);AddRoundedStorage(panel,settings.ambienceEnabled?"Pause":"Play",Math.Round(settings.ambienceVolume*100).ToString(CultureInfo.InvariantCulture)+"% volume",definition.Accent,delegate{settings.ambienceEnabled=!settings.ambienceEnabled;settings.Save(settingsPath);StartAmbience();RenderPage();});AddRoundedStorage(panel,"Volume",Math.Round(settings.ambienceVolume*100).ToString(CultureInfo.InvariantCulture)+"%",definition.Accent,CycleAmbienceVolume);
        }

        private void RenderWave1Media()
        {
            titleText.Text=pspCategoryIndex==1?"Photo":"Video";subtitleText.Text="Media folders will use the Huymaier file browser";StackPanel panel=new StackPanel{Margin=new Thickness(80,30,80,30)};contentHost.Children.Add(panel);AddRoundedStorage(panel,"Media folder","Not configured in this development scaffold",definition.Accent,delegate{ShowNotice("Media-folder routing is not enabled until the PSP adapter owns the path safely");});
        }

        private void RenderWave1Info()
        {
            titleText.Text="System Information";subtitleText.Text=definition.DisplayName;StackPanel panel=new StackPanel{Margin=new Thickness(80,24,80,24)};contentHost.Children.Add(panel);AddRoundedStorage(panel,"Primary Emulator",DisplayPath(settings.emulatorPath),definition.Accent,ChoosePrimaryEmulator);AddRoundedStorage(panel,"Data Path",DisplayPath(settings.emulatorDataPath),definition.Accent,ChooseEmulatorDataRoot);AddRoundedStorage(panel,"Library",games.Count.ToString(CultureInfo.InvariantCulture)+" titles",definition.Accent,delegate{dashboardSubpage="library";selected=0;RenderPage();});
        }

        private void RenderWave1Settings()
        {
            titleText.Text=definition.Shell=="Dreamcast"?"Settings":(definition.Shell=="Saturn"?"System Settings":(definition.Shell=="PSP"?"PPSSPP Settings":"System Settings"));subtitleText.Text=definition.PrimaryBackend+"  •  Huymaier native configuration";StackPanel panel=new StackPanel{Margin=new Thickness(44,6,44,24)};contentHost.Children.Add(new ScrollViewer{VerticalScrollBarVisibility=ScrollBarVisibility.Hidden,Content=panel});
            if(String.IsNullOrWhiteSpace(settings.emulatorPath)||!File.Exists(settings.emulatorPath)){AddRoundedStorage(panel,"Locate Emulator","Point Huymaier Console to "+definition.PrimaryBackend,definition.Accent,ChoosePrimaryEmulator);AddRoundedStorage(panel,"Install Latest Emulator","Resolve the latest supported official release",definition.Accent,InstallPrimaryEmulator);}else AddRoundedStorage(panel,definition.PrimaryBackend,settings.emulatorPath,definition.Accent,ChoosePrimaryEmulator);
            AddRoundedStorage(panel,"Emulator Data",DisplayPath(settings.emulatorDataPath),definition.Accent,ChooseEmulatorDataRoot);AddRoundedStorage(panel,"Game Folders",settings.gameFolders.Count.ToString(CultureInfo.InvariantCulture)+" configured",definition.Accent,AddGameFolder);AddRoundedStorage(panel,"Full Emulator Settings","Every discovered backend setting; unknown keys are preserved",definition.Accent,OpenNativeBackendSettings);AddRoundedStorage(panel,"Refresh Library",games.Count.ToString(CultureInfo.InvariantCulture)+" titles",definition.Accent,delegate{RefreshLibrary(true);});
        }


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



        private bool IsWave3Shell()
        {
            return definition.Shell == "AtariLynx" || definition.Shell == "NeoGeo" || definition.Shell == "NGPC" || definition.Shell == "Jaguar" || definition.Shell == "PrimeHack";
        }

        private void RenderWave3Root()
        {
            if (definition.Shell == "AtariLynx") { RenderAtariLynxHandheld(); return; }
            if (definition.Shell == "NeoGeo") { RenderNeoGeoDeck(); return; }
            if (definition.Shell == "NGPC") { RenderNgpcHandheld(); return; }
            if (definition.Shell == "Jaguar") { RenderJaguarDeck(); return; }
            RenderPrimeHackVisor();
        }

        private void RenderWave3Subpage()
        {
            if (dashboardSubpage == "library") { RenderWave1Library(); return; }
            if (dashboardSubpage == "backend-settings" || dashboardSubpage == "backend-settings-list" || dashboardSubpage == "backend-setting-detail") { RenderWave1Subpage(); return; }
            if (dashboardSubpage == "settings") { RenderWave3Settings(); return; }
            if (dashboardSubpage == "saves") { RenderWave3Storage(); return; }
            RenderWave3Settings();
        }


        private Color GetWave3Accent(){if(definition.Shell=="AtariLynx")return Color.FromRgb(226,82,44);if(definition.Shell=="NeoGeo")return Color.FromRgb(215,31,39);if(definition.Shell=="NGPC")return Color.FromRgb(78,183,182);if(definition.Shell=="Jaguar")return Color.FromRgb(209,35,42);return Color.FromRgb(63,225,211);}
        private string[] GetWave3SaveExtensions(){if(definition.Shell=="NeoGeo")return new[]{".mem",".nv",".nvram",".sav",".srm",".fs"};if(definition.Shell=="Jaguar")return new[]{".sav",".nv",".nvram",".eeprom",".eep",".ram"};return new[]{".sav",".srm",".ram",".rtc",".gci",".raw",".bin"};}
        private List<string> FindWave3SaveFiles(){HashSet<string> found=new HashSet<string>(StringComparer.OrdinalIgnoreCase);List<string> roots=FindSaveRoots();Action<string> addRoot=delegate(string value){if(String.IsNullOrWhiteSpace(value))return;try{if(File.Exists(value))value=Path.GetDirectoryName(value);if(Directory.Exists(value)&&!roots.Contains(value,StringComparer.OrdinalIgnoreCase))roots.Add(value);}catch{}};addRoot(settings.emulatorDataPath);addRoot(settings.emulatorPath);addRoot(settings.fallbackEmulatorPath);foreach(string root in roots.ToArray())foreach(string name in new[]{"sav","Save","Saves","memcard","Memcard","nvram","NVRAM","GC","Wii"}){try{addRoot(Path.Combine(root,name));}catch{}};string[] exts=GetWave3SaveExtensions();int visited=0;foreach(string root in roots){if(!Directory.Exists(root))continue;try{foreach(string file in Directory.EnumerateFiles(root,"*",SearchOption.AllDirectories)){if(++visited>10000)break;if(exts.Contains(Path.GetExtension(file),StringComparer.OrdinalIgnoreCase))found.Add(file);}}catch{}if(visited>10000)break;}return found.OrderBy(delegate(string p){return Path.GetFileName(p);},StringComparer.CurrentCultureIgnoreCase).ToList();}
        private void RenderWave3Storage(){Color accent=GetWave3Accent();titleText.Text=definition.Shell=="NeoGeo"?"Memory Card":(definition.Shell=="PrimeHack"?"Prime Save Data":"Saved Data");subtitleText.Text=definition.DisplayName+" native save storage";columns=3;WrapPanel panel=new WrapPanel{Margin=new Thickness(35,8,35,24)};contentHost.Children.Add(new ScrollViewer{VerticalScrollBarVisibility=ScrollBarVisibility.Hidden,Content=panel});List<string>saves=FindWave3SaveFiles();foreach(string value in saves.Take(700)){string captured=value;AddHardwareUtility(panel,Path.GetFileNameWithoutExtension(value),FormatBytes(GetPathSize(value))+"  •  "+Path.GetExtension(value).TrimStart('.').ToUpperInvariant(),"▣",accent,delegate{BackupNativeSavePath(captured,definition.Id+"-"+Path.GetFileNameWithoutExtension(captured));},300,120);}if(saves.Count==0)AddHardwareUtility(panel,"No Saved Data",definition.PrimaryBackend+" has no detected save data yet.","▣",accent,delegate{dashboardSubpage="settings";selected=0;RenderPage();},300,120);else AddHardwareUtility(panel,"Back Up All",saves.Count+" save item(s)","⇧",accent,delegate{foreach(string value in saves)BackupNativeSavePath(value,definition.Id+"-"+Path.GetFileNameWithoutExtension(value));},300,120);}
        private void RenderWave3Settings(){Color accent=GetWave3Accent();titleText.Text=definition.DisplayName+" System";subtitleText.Text=definition.PrimaryBackend+"  •  native emulator integration";columns=3;WrapPanel panel=new WrapPanel{Margin=new Thickness(45,20,45,24)};contentHost.Children.Add(new ScrollViewer{VerticalScrollBarVisibility=ScrollBarVisibility.Hidden,Content=panel});if(String.IsNullOrWhiteSpace(settings.emulatorPath)||!File.Exists(settings.emulatorPath)){AddHardwareUtility(panel,"Locate Emulator",definition.PrimaryBackend,"⌕",accent,ChoosePrimaryEmulator,300,135);AddHardwareUtility(panel,"Install Latest",definition.PrimaryBackend+" official/current supported build","↓",accent,InstallPrimaryEmulator,300,135);}else AddHardwareUtility(panel,definition.PrimaryBackend,settings.emulatorPath,"✓",accent,ChoosePrimaryEmulator,300,135);AddHardwareUtility(panel,"Full Emulator Settings","Every discovered backend setting","⚙",accent,OpenNativeBackendSettings,300,135);AddHardwareUtility(panel,"Emulator Data",DisplayPath(settings.emulatorDataPath),"▣",accent,ChooseEmulatorDataRoot,300,135);AddHardwareUtility(panel,"Game Folders",settings.gameFolders.Count+" configured","▦",accent,AddGameFolder,300,135);AddHardwareUtility(panel,"Saved Data","Native storage manager","◫",accent,delegate{dashboardSubpage="saves";selected=0;RenderPage();},300,135);AddHardwareUtility(panel,"Refresh Library",games.Count+" titles","↻",accent,delegate{RefreshLibrary(true);},300,135);}

        private void RenderAtariLynxHandheld()
        {
            titleText.Text=String.Empty;subtitleText.Text=String.Empty;columns=5;Grid body=new Grid{Margin=new Thickness(35,5,35,18)};body.RowDefinitions.Add(new RowDefinition{Height=new GridLength(330)});body.RowDefinitions.Add(new RowDefinition{Height=new GridLength(1,GridUnitType.Star)});contentHost.Children.Add(body);
            Border unit=new Border{CornerRadius=new CornerRadius(55),Background=new LinearGradientBrush(Color.FromRgb(40,41,42),Color.FromRgb(6,7,8),90),BorderBrush=new SolidColorBrush(Color.FromRgb(72,73,74)),BorderThickness=new Thickness(5),Padding=new Thickness(28),Margin=new Thickness(75,0,75,12)};Grid h=new Grid();h.ColumnDefinitions.Add(new ColumnDefinition{Width=new GridLength(185)});h.ColumnDefinitions.Add(new ColumnDefinition());h.ColumnDefinitions.Add(new ColumnDefinition{Width=new GridLength(185)});h.Children.Add(new TextBlock{Text="✚",FontSize=68,Foreground=new SolidColorBrush(Color.FromRgb(85,87,88)),HorizontalAlignment=HorizontalAlignment.Center,VerticalAlignment=VerticalAlignment.Center});Border screen=new Border{CornerRadius=new CornerRadius(5),Background=new SolidColorBrush(Color.FromRgb(34,45,42)),BorderBrush=new SolidColorBrush(Color.FromRgb(7,8,9)),BorderThickness=new Thickness(14),Margin=new Thickness(8),Child=new TextBlock{Text="LYNX",FontSize=34,FontWeight=FontWeights.Bold,Foreground=new SolidColorBrush(Color.FromRgb(226,82,44)),HorizontalAlignment=HorizontalAlignment.Center,VerticalAlignment=VerticalAlignment.Center}};Grid.SetColumn(screen,1);h.Children.Add(screen);TextBlock ab=new TextBlock{Text="A      B",FontSize=30,Foreground=new SolidColorBrush(Color.FromRgb(226,82,44)),HorizontalAlignment=HorizontalAlignment.Center,VerticalAlignment=VerticalAlignment.Center};Grid.SetColumn(ab,2);h.Children.Add(ab);unit.Child=h;body.Children.Add(unit);WrapPanel cards=new WrapPanel();ScrollViewer sc=new ScrollViewer{VerticalScrollBarVisibility=ScrollBarVisibility.Hidden,Content=cards};Grid.SetRow(sc,1);body.Children.Add(sc);foreach(ConsolePlatformGame game in games)AddHardwareGame(cards,game,Color.FromRgb(226,82,44),126,158,"LYNX");AddHardwareUtility(cards,"System",definition.PrimaryBackend,"⚙",Color.FromRgb(226,82,44),delegate{OpenWave1Subpage("settings");},140,158);
        }

        private void RenderNeoGeoDeck()
        {
            titleText.Text=String.Empty;subtitleText.Text=String.Empty;columns=6;Grid body=new Grid{Margin=new Thickness(50,0,50,18)};body.RowDefinitions.Add(new RowDefinition{Height=new GridLength(190)});body.RowDefinitions.Add(new RowDefinition{Height=new GridLength(1,GridUnitType.Star)});contentHost.Children.Add(body);Border deck=new Border{CornerRadius=new CornerRadius(14),Background=new LinearGradientBrush(Color.FromRgb(29,30,31),Color.FromRgb(3,4,5),90),BorderBrush=new SolidColorBrush(Color.FromRgb(87,88,89)),BorderThickness=new Thickness(4),Padding=new Thickness(22),Margin=new Thickness(135,0,135,10)};Grid g=new Grid();g.Children.Add(new Border{Width=380,Height=64,Background=new SolidColorBrush(Color.FromRgb(5,6,7)),BorderBrush=new SolidColorBrush(Color.FromRgb(215,31,39)),BorderThickness=new Thickness(0,5,0,0),HorizontalAlignment=HorizontalAlignment.Center,VerticalAlignment=VerticalAlignment.Center});g.Children.Add(new TextBlock{Text="NEO•GEO\nADVANCED ENTERTAINMENT SYSTEM",FontSize=21,FontWeight=FontWeights.Bold,Foreground=Brushes.White,HorizontalAlignment=HorizontalAlignment.Left,VerticalAlignment=VerticalAlignment.Center,Margin=new Thickness(35,0,0,0),TextAlignment=TextAlignment.Center});g.Children.Add(new TextBlock{Text="MAX 330 MEGA\nPRO-GEAR SPEC",FontSize=9,Foreground=new SolidColorBrush(Color.FromRgb(215,31,39)),HorizontalAlignment=HorizontalAlignment.Right,VerticalAlignment=VerticalAlignment.Center,Margin=new Thickness(0,0,35,0),TextAlignment=TextAlignment.Center});deck.Child=g;body.Children.Add(deck);WrapPanel cards=new WrapPanel();ScrollViewer scroll=new ScrollViewer{VerticalScrollBarVisibility=ScrollBarVisibility.Hidden,Content=cards};Grid.SetRow(scroll,1);body.Children.Add(scroll);foreach(ConsolePlatformGame game in games)AddHardwareGame(cards,game,Color.FromRgb(215,31,39),126,158,"NEO GEO");AddHardwareUtility(cards,"Memory Card","saved data","▣",Color.FromRgb(215,31,39),delegate{OpenWave1Subpage("saves");},140,158);AddHardwareUtility(cards,"System",definition.PrimaryBackend,"⚙",Color.FromRgb(122,25,30),delegate{OpenWave1Subpage("settings");},140,158);
        }

        private void RenderNgpcHandheld()
        {
            titleText.Text=String.Empty;subtitleText.Text=String.Empty;columns=5;Grid body=new Grid{Margin=new Thickness(40,5,40,18)};body.RowDefinitions.Add(new RowDefinition{Height=new GridLength(335)});body.RowDefinitions.Add(new RowDefinition{Height=new GridLength(1,GridUnitType.Star)});contentHost.Children.Add(body);Border handheld=new Border{Width=620,CornerRadius=new CornerRadius(70),HorizontalAlignment=HorizontalAlignment.Center,Background=new LinearGradientBrush(Color.FromRgb(89,93,95),Color.FromRgb(35,38,39),90),BorderBrush=new SolidColorBrush(Color.FromRgb(117,121,122)),BorderThickness=new Thickness(4),Padding=new Thickness(30)};Grid h=new Grid();h.ColumnDefinitions.Add(new ColumnDefinition{Width=new GridLength(160)});h.ColumnDefinitions.Add(new ColumnDefinition());h.ColumnDefinitions.Add(new ColumnDefinition{Width=new GridLength(160)});Border stick=new Border{Width=74,Height=74,CornerRadius=new CornerRadius(37),Background=new RadialGradientBrush(Color.FromRgb(88,91,92),Color.FromRgb(21,23,24)),BorderBrush=new SolidColorBrush(Color.FromRgb(135,138,139)),BorderThickness=new Thickness(3),HorizontalAlignment=HorizontalAlignment.Center,VerticalAlignment=VerticalAlignment.Center,Child=new TextBlock{Text="●",FontSize=34,Foreground=new SolidColorBrush(Color.FromRgb(32,34,35)),HorizontalAlignment=HorizontalAlignment.Center,VerticalAlignment=VerticalAlignment.Center}};h.Children.Add(stick);Border screen=new Border{Background=new SolidColorBrush(Color.FromRgb(45,61,54)),BorderBrush=new SolidColorBrush(Color.FromRgb(12,14,15)),BorderThickness=new Thickness(12),CornerRadius=new CornerRadius(8),Child=new TextBlock{Text="NEO GEO\nPOCKET COLOR",FontSize=22,FontWeight=FontWeights.SemiBold,Foreground=new SolidColorBrush(Color.FromRgb(78,183,182)),HorizontalAlignment=HorizontalAlignment.Center,VerticalAlignment=VerticalAlignment.Center,TextAlignment=TextAlignment.Center}};Grid.SetColumn(screen,1);h.Children.Add(screen);TextBlock ab=new TextBlock{Text="A    B",FontSize=28,Foreground=new SolidColorBrush(Color.FromRgb(78,183,182)),HorizontalAlignment=HorizontalAlignment.Center,VerticalAlignment=VerticalAlignment.Center};Grid.SetColumn(ab,2);h.Children.Add(ab);handheld.Child=h;body.Children.Add(handheld);WrapPanel cards=new WrapPanel();ScrollViewer scroll=new ScrollViewer{VerticalScrollBarVisibility=ScrollBarVisibility.Hidden,Content=cards};Grid.SetRow(scroll,1);body.Children.Add(scroll);foreach(ConsolePlatformGame game in games)AddHardwareGame(cards,game,Color.FromRgb(78,183,182),126,158,"NGPC");AddHardwareUtility(cards,"System",definition.PrimaryBackend,"⚙",Color.FromRgb(78,183,182),delegate{OpenWave1Subpage("settings");},140,158);
        }

        private void RenderJaguarDeck()
        {
            titleText.Text=String.Empty;subtitleText.Text=String.Empty;columns=6;Grid body=new Grid{Margin=new Thickness(45,0,45,18)};body.RowDefinitions.Add(new RowDefinition{Height=new GridLength(220)});body.RowDefinitions.Add(new RowDefinition{Height=new GridLength(1,GridUnitType.Star)});contentHost.Children.Add(body);Border deck=new Border{CornerRadius=new CornerRadius(80,80,18,18),Background=new LinearGradientBrush(Color.FromRgb(38,39,40),Color.FromRgb(4,5,6),90),BorderBrush=new SolidColorBrush(Color.FromRgb(73,74,75)),BorderThickness=new Thickness(5),Padding=new Thickness(22),Margin=new Thickness(150,0,150,10)};Grid g=new Grid();g.Children.Add(new Border{Width=330,Height=52,CornerRadius=new CornerRadius(8),Background=new SolidColorBrush(Color.FromRgb(9,10,11)),BorderBrush=new SolidColorBrush(Color.FromRgb(209,35,42)),BorderThickness=new Thickness(3),HorizontalAlignment=HorizontalAlignment.Center,VerticalAlignment=VerticalAlignment.Center});g.Children.Add(new TextBlock{Text="JAGUAR",FontSize=32,FontWeight=FontWeights.Black,Foreground=new SolidColorBrush(Color.FromRgb(209,35,42)),HorizontalAlignment=HorizontalAlignment.Left,VerticalAlignment=VerticalAlignment.Center,Margin=new Thickness(38,0,0,0)});g.Children.Add(new TextBlock{Text="64\nBIT",FontSize=21,FontWeight=FontWeights.Bold,Foreground=Brushes.White,HorizontalAlignment=HorizontalAlignment.Right,VerticalAlignment=VerticalAlignment.Center,Margin=new Thickness(0,0,42,0),TextAlignment=TextAlignment.Center});deck.Child=g;body.Children.Add(deck);WrapPanel cards=new WrapPanel();ScrollViewer scroll=new ScrollViewer{VerticalScrollBarVisibility=ScrollBarVisibility.Hidden,Content=cards};Grid.SetRow(scroll,1);body.Children.Add(scroll);foreach(ConsolePlatformGame game in games)AddHardwareGame(cards,game,Color.FromRgb(209,35,42),126,158,"JAGUAR");AddHardwareUtility(cards,"Keypad & Input","Jaguar controller mappings","#",Color.FromRgb(209,35,42),delegate{OpenWave1Subpage("settings");},140,158);AddHardwareUtility(cards,"System",definition.PrimaryBackend,"⚙",Color.FromRgb(128,27,32),delegate{OpenWave1Subpage("settings");},140,158);
        }

        private void RenderPrimeHackVisor()
        {
            titleText.Text=String.Empty;subtitleText.Text=String.Empty;columns=5;Grid body=new Grid{Margin=new Thickness(34,10,34,18)};contentHost.Children.Add(body);Border visor=new Border{CornerRadius=new CornerRadius(90,90,45,45),BorderBrush=new SolidColorBrush(Color.FromArgb(220,63,225,211)),BorderThickness=new Thickness(4),Background=new RadialGradientBrush(Color.FromArgb(115,15,91,91),Color.FromArgb(245,1,9,12)),Padding=new Thickness(58)};Grid inner=new Grid();inner.RowDefinitions.Add(new RowDefinition{Height=new GridLength(65)});inner.RowDefinitions.Add(new RowDefinition{Height=new GridLength(1,GridUnitType.Star)});inner.Children.Add(new TextBlock{Text="PRIME VISOR  //  PRIMEHACK",FontFamily=new FontFamily("Consolas"),FontSize=21,FontWeight=FontWeights.SemiBold,Foreground=new SolidColorBrush(Color.FromRgb(111,255,233)),HorizontalAlignment=HorizontalAlignment.Center,VerticalAlignment=VerticalAlignment.Center});WrapPanel cards=new WrapPanel{HorizontalAlignment=HorizontalAlignment.Center};ScrollViewer scroll=new ScrollViewer{VerticalScrollBarVisibility=ScrollBarVisibility.Hidden,Content=cards};Grid.SetRow(scroll,1);inner.Children.Add(scroll);foreach(ConsolePlatformGame game in games)AddHardwareGame(cards,game,Color.FromRgb(63,225,211),150,190,"PRIME");AddHardwareUtility(cards,"PrimeHack Controls","mouse-look, camera, reticle and visor controls","⊕",Color.FromRgb(29,151,148),delegate{OpenWave1Subpage("settings");},170,190);AddHardwareUtility(cards,"System",definition.PrimaryBackend,"⚙",Color.FromRgb(23,105,107),delegate{OpenWave1Subpage("settings");},150,190);visor.Child=inner;body.Children.Add(visor);
        }

        private bool IsWave2Shell()
        {
            return definition.Shell == "Atari2600" || definition.Shell == "NES" || definition.Shell == "SNES" || definition.Shell == "GameBoy" || definition.Shell == "GBC" || definition.Shell == "GBA" || definition.Shell == "Genesis" || definition.Shell == "SegaCD" || definition.Shell == "Sega32X" || definition.Shell == "GameGear" || definition.Shell == "MasterSystem" || definition.Shell == "TurboGrafx16";
        }

        private void RenderWave2Root()
        {
            if (definition.Shell == "Atari2600") { RenderAtari2600Deck(); return; }
            if (definition.Shell == "NES") { RenderNesDeck(); return; }
            if (definition.Shell == "SNES") { RenderSnesDeck(); return; }
            if (definition.Shell == "GameBoy") { RenderGameBoyHandheld(false); return; }
            if (definition.Shell == "GBC") { RenderGameBoyHandheld(true); return; }
            if (definition.Shell == "GBA") { RenderGbaHandheld(); return; }
            if (definition.Shell == "Genesis") { RenderGenesisDeck(false); return; }
            if (definition.Shell == "Sega32X") { RenderGenesisDeck(true); return; }
            if (definition.Shell == "SegaCD") { RenderSegaCdDeck(); return; }
            if (definition.Shell == "GameGear") { RenderGameGearHandheld(); return; }
            if (definition.Shell == "MasterSystem") { RenderMasterSystemDeck(); return; }
            RenderTurboGrafxDeck();
        }

        private void RenderWave2Subpage()
        {
            if (dashboardSubpage == "library") { RenderWave1Library(); return; }
            if (dashboardSubpage == "backend-settings" || dashboardSubpage == "backend-settings-list" || dashboardSubpage == "backend-setting-detail") { RenderWave1Subpage(); return; }
            if (dashboardSubpage == "settings") { RenderWave2Settings(); return; }
            if (dashboardSubpage == "saves") { RenderWave2Storage(); return; }
            if (dashboardSubpage == "music") { RenderWave1Music(); return; }
            RenderWave2Settings();
        }

        private Border CreateHardwareGameCard(ConsolePlatformGame game, Color accent, double width, double height, string mediaLabel, Action invoke)
        {
            Border frame = new Border { Width=width, Height=height, Margin=new Thickness(9), CornerRadius=new CornerRadius(7), Background=new SolidColorBrush(Color.FromRgb(27,29,31)), BorderBrush=new SolidColorBrush(accent), BorderThickness=new Thickness(2) };
            Grid body = new Grid(); body.RowDefinitions.Add(new RowDefinition{Height=new GridLength(1,GridUnitType.Star)}); body.RowDefinitions.Add(new RowDefinition{Height=new GridLength(44)});
            if (!String.IsNullOrWhiteSpace(game.Cover) && File.Exists(game.Cover)) { try { body.Children.Add(new Image{Source=LoadBitmap(game.Cover),Stretch=Stretch.UniformToFill,Margin=new Thickness(5)}); } catch { } }
            if (body.Children.Count==0) body.Children.Add(new TextBlock{Text=mediaLabel,FontSize=22,FontWeight=FontWeights.Bold,Foreground=new SolidColorBrush(accent),HorizontalAlignment=HorizontalAlignment.Center,VerticalAlignment=VerticalAlignment.Center});
            Border label = new Border{Background=new SolidColorBrush(Color.FromArgb(235,10,11,12)),Padding=new Thickness(6)}; Grid.SetRow(label,1); label.Child=new TextBlock{Text=game.Name,FontSize=10,Foreground=Brushes.White,TextTrimming=TextTrimming.CharacterEllipsis,HorizontalAlignment=HorizontalAlignment.Center};body.Children.Add(label);frame.Child=body;
            Button button=new Button{Width=width+6,Height=height+6,Margin=new Thickness(7),Padding=new Thickness(0),Background=Brushes.Transparent,BorderThickness=new Thickness(0),Content=frame,RenderTransformOrigin=new Point(0.5,0.5)};button.Click+=delegate{invoke();};return new Border{Child=button,Background=Brushes.Transparent};
        }

        private void AddHardwareGame(Panel panel, ConsolePlatformGame game, Color accent, double width, double height, string mediaLabel)
        {
            ConsolePlatformGame captured=game; Border wrapper=CreateHardwareGameCard(game,accent,width,height,mediaLabel,delegate{LaunchGame(captured,false);});panel.Children.Add(wrapper);Button button=wrapper.Child as Button;if(button!=null)actions.Add(new ConsolePlatformAction{Button=button,Name=game.Name,Game=game,Invoke=delegate{LaunchGame(captured,false);}});
        }

        private void AddHardwareUtility(Panel panel,string title,string detail,string glyph,Color accent,Action invoke,double width,double height)
        {
            Button button=CreateWave1Tile(title,detail,glyph,new SolidColorBrush(Color.FromArgb(225,accent.R,accent.G,accent.B)),Brushes.White,invoke,width,height);panel.Children.Add(button);actions.Add(new ConsolePlatformAction{Button=button,Name=title,Invoke=invoke});
        }


        private Color GetWave2Accent()
        {
            if (definition.Shell == "Atari2600") return Color.FromRgb(220,149,57);
            if (definition.Shell == "NES") return Color.FromRgb(194,35,42);
            if (definition.Shell == "SNES") return Color.FromRgb(103,74,151);
            if (definition.Shell == "GameBoy") return Color.FromRgb(117,44,111);
            if (definition.Shell == "GBC") return Color.FromRgb(244,73,142);
            if (definition.Shell == "GBA") return Color.FromRgb(168,145,255);
            if (definition.Shell == "Genesis") return Color.FromRgb(191,34,45);
            if (definition.Shell == "SegaCD") return Color.FromRgb(80,147,214);
            if (definition.Shell == "Sega32X") return Color.FromRgb(224,60,48);
            if (definition.Shell == "GameGear") return Color.FromRgb(47,137,205);
            if (definition.Shell == "MasterSystem") return Color.FromRgb(206,31,39);
            return Color.FromRgb(193,34,42);
        }

        private string GetWave2SaveMediaLabel()
        {
            if (definition.Shell == "Atari2600") return "CARTRIDGE NVRAM / SAVEKEY";
            if (definition.Shell == "SegaCD") return "BACKUP RAM";
            if (definition.Shell == "TurboGrafx16") return "HUCARD / CD BACKUP";
            if (definition.Shell == "GameBoy" || definition.Shell == "GBC" || definition.Shell == "GBA" || definition.Shell == "GameGear") return "BATTERY SAVE";
            return "CARTRIDGE SAVE MEMORY";
        }

        private string[] GetWave2SaveExtensions()
        {
            if (definition.Shell == "Atari2600") return new string[] { ".sav", ".dat", ".eep", ".eeprom", ".nv", ".nvram", ".ram" };
            if (definition.Shell == "SegaCD") return new string[] { ".brm", ".bkr", ".bcr", ".sav", ".srm", ".ram" };
            if (definition.Shell == "GameBoy" || definition.Shell == "GBC" || definition.Shell == "GBA") return new string[] { ".sav", ".srm", ".rtc", ".ram" };
            return new string[] { ".sav", ".srm", ".ram", ".brm", ".eep", ".eeprom", ".nv", ".nvram" };
        }

        private List<string> GetWave2SaveSearchRoots()
        {
            List<string> roots = new List<string>();
            Action<string> add = delegate(string value) { if (String.IsNullOrWhiteSpace(value)) return; try { if (File.Exists(value)) value = Path.GetDirectoryName(value); if (Directory.Exists(value) && !roots.Contains(value, StringComparer.OrdinalIgnoreCase)) roots.Add(value); } catch { } };
            add(settings.emulatorDataPath); add(settings.emulatorPath); add(settings.fallbackEmulatorPath);
            string app = Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData); string local = Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData); string docs = Environment.GetFolderPath(Environment.SpecialFolder.MyDocuments);
            if (definition.PrimaryBackend.IndexOf("Mesen", StringComparison.OrdinalIgnoreCase) >= 0) { add(Path.Combine(app,"Mesen")); add(Path.Combine(app,"Mesen2")); add(Path.Combine(local,"Mesen")); add(Path.Combine(local,"Mesen2")); }
            if (definition.PrimaryBackend.IndexOf("SameBoy", StringComparison.OrdinalIgnoreCase) >= 0) { add(Path.Combine(app,"SameBoy")); add(Path.Combine(local,"SameBoy")); }
            if (definition.PrimaryBackend.IndexOf("mGBA", StringComparison.OrdinalIgnoreCase) >= 0) { add(Path.Combine(app,"mGBA")); add(Path.Combine(local,"mGBA")); }
            if (definition.PrimaryBackend.IndexOf("Stella", StringComparison.OrdinalIgnoreCase) >= 0) add(Path.Combine(app,"Stella"));
            if (definition.PrimaryBackend.IndexOf("ares", StringComparison.OrdinalIgnoreCase) >= 0) { add(Path.Combine(app,"ares")); add(Path.Combine(local,"ares")); }
            if (definition.PrimaryBackend.IndexOf("Mednafen", StringComparison.OrdinalIgnoreCase) >= 0) { add(Path.Combine(docs,"Mednafen")); add(Path.Combine(app,"Mednafen")); }
            List<string> baseRoots = roots.ToList(); foreach (string rootPath in baseRoots) foreach (string name in new string[] { "Save", "Saves", "Battery", "SRAM", "NVRAM", "Backup", "sav" }) { try { add(Path.Combine(rootPath,name)); } catch { } }
            return roots;
        }

        private List<string> FindWave2SaveFiles()
        {
            HashSet<string> found = new HashSet<string>(StringComparer.OrdinalIgnoreCase); string[] extensions = GetWave2SaveExtensions();
            foreach (ConsolePlatformGame game in games)
            {
                if (game == null || String.IsNullOrWhiteSpace(game.Path)) continue;
                string basePath; try { basePath = Path.Combine(Path.GetDirectoryName(game.Path), Path.GetFileNameWithoutExtension(game.Path)); } catch { continue; }
                foreach (string ext in extensions) { string candidate = basePath + ext; if (File.Exists(candidate)) found.Add(candidate); }
            }
            int visited = 0;
            foreach (string rootPath in GetWave2SaveSearchRoots())
            {
                if (!Directory.Exists(rootPath)) continue;
                try
                {
                    foreach (string file in Directory.EnumerateFiles(rootPath,"*",SearchOption.AllDirectories))
                    {
                        if (++visited > 7000) break; string ext = Path.GetExtension(file); if (extensions.Contains(ext,StringComparer.OrdinalIgnoreCase)) found.Add(file);
                    }
                }
                catch { }
                if (visited > 7000) break;
            }
            return found.OrderBy(delegate(string p) { return Path.GetFileName(p); }, StringComparer.CurrentCultureIgnoreCase).ToList();
        }

        private string GetWave2SaveDisplayName(string pathValue)
        {
            string baseName = Path.GetFileNameWithoutExtension(pathValue); string normalized = NormalizeArtworkTitle(baseName); ConsolePlatformGame best = null; double bestScore = 0;
            foreach (ConsolePlatformGame game in games) { string candidate = NormalizeArtworkTitle(game.Name); if (candidate == normalized) return game.Name; double score = candidate.Contains(normalized) || normalized.Contains(candidate) ? 0.8 : 0; if (score > bestScore) { bestScore = score; best = game; } }
            return best != null && bestScore >= 0.8 ? best.Name : baseName;
        }

        private Button CreateWave2SaveChip(string pathValue, Action invoke)
        {
            Color accent = GetWave2Accent(); string title = GetWave2SaveDisplayName(pathValue); string media = GetWave2SaveMediaLabel();
            Button button = new Button { Width=315, Height=126, Margin=new Thickness(9), Padding=new Thickness(0), Background=Brushes.Transparent, BorderThickness=new Thickness(0), RenderTransformOrigin=new Point(0.5,0.5) };
            Border chip = new Border { CornerRadius=new CornerRadius(8), Background=new LinearGradientBrush(Color.FromRgb(30,31,32),Color.FromRgb(8,9,10),90), BorderBrush=new SolidColorBrush(accent), BorderThickness=new Thickness(2), Padding=new Thickness(14) };
            Grid layout = new Grid(); layout.ColumnDefinitions.Add(new ColumnDefinition{Width=new GridLength(76)}); layout.ColumnDefinitions.Add(new ColumnDefinition());
            Border die = new Border { Width=54, Height=72, CornerRadius=new CornerRadius(5), Background=new SolidColorBrush(Color.FromRgb(14,15,16)), BorderBrush=new SolidColorBrush(Color.FromArgb(180,accent.R,accent.G,accent.B)), BorderThickness=new Thickness(2), VerticalAlignment=VerticalAlignment.Center, Child=new TextBlock{Text="SAVE\nRAM",FontSize=10,FontWeight=FontWeights.Bold,Foreground=new SolidColorBrush(accent),HorizontalAlignment=HorizontalAlignment.Center,VerticalAlignment=VerticalAlignment.Center,TextAlignment=TextAlignment.Center} }; layout.Children.Add(die);
            StackPanel info = new StackPanel { Margin=new Thickness(8,2,0,0) }; Grid.SetColumn(info,1); info.Children.Add(new TextBlock{Text=title,FontSize=15,FontWeight=FontWeights.SemiBold,Foreground=Brushes.White,TextTrimming=TextTrimming.CharacterEllipsis}); info.Children.Add(new TextBlock{Text=media,FontSize=9,Foreground=new SolidColorBrush(accent),Margin=new Thickness(0,3,0,0)}); info.Children.Add(new TextBlock{Text=FormatBytes(GetPathSize(pathValue))+"  •  "+GetPathModifiedUtcSafe(pathValue).ToString("g",CultureInfo.CurrentCulture),FontSize=9,Foreground=new SolidColorBrush(Color.FromArgb(185,255,255,255)),Margin=new Thickness(0,5,0,0)}); info.Children.Add(new TextBlock{Text=Path.GetFileName(pathValue),FontSize=8,Foreground=new SolidColorBrush(Color.FromArgb(135,255,255,255)),TextTrimming=TextTrimming.CharacterEllipsis}); layout.Children.Add(info); chip.Child=layout; button.Content=chip; button.Click+=delegate{invoke();}; return button;
        }

        private void RenderWave2Storage()
        {
            Color accent = GetWave2Accent(); string media = GetWave2SaveMediaLabel(); titleText.Text = definition.Shell == "SegaCD" ? "Backup RAM" : "Saved Data"; subtitleText.Text = media + "  •  " + definition.DisplayName; columns = 3;
            ScrollViewer scroll = new ScrollViewer { VerticalScrollBarVisibility=ScrollBarVisibility.Hidden, HorizontalScrollBarVisibility=ScrollBarVisibility.Disabled }; WrapPanel panel = new WrapPanel { Margin=new Thickness(34,8,34,24) }; scroll.Content=panel; contentHost.Children.Add(scroll);
            List<string> saves = FindWave2SaveFiles(); foreach (string pathValue in saves.Take(600)) { string captured=pathValue; Button chip=CreateWave2SaveChip(pathValue,delegate{BackupNativeSavePath(captured,definition.Id+"-"+Path.GetFileNameWithoutExtension(captured));}); panel.Children.Add(chip); actions.Add(new ConsolePlatformAction{Button=chip,Name=GetWave2SaveDisplayName(pathValue),Invoke=delegate{BackupNativeSavePath(captured,definition.Id+"-"+Path.GetFileNameWithoutExtension(captured));}}); }
            if (saves.Count == 0) AddHardwareUtility(panel,"No Saved Data",definition.PrimaryBackend+" has not produced detected "+media.ToLowerInvariant()+" yet.","▣",accent,delegate{dashboardSubpage="settings";selected=0;RenderPage();},310,126);
            else AddHardwareUtility(panel,"Back Up All",saves.Count.ToString(CultureInfo.InvariantCulture)+" save file(s)","⇧",accent,delegate{foreach(string value in saves)BackupNativeSavePath(value,definition.Id+"-"+Path.GetFileNameWithoutExtension(value));},310,126);
        }

        private void RenderWave2Settings()
        {
            Color accent=GetWave2Accent(); titleText.Text=definition.DisplayName+" System"; subtitleText.Text=definition.PrimaryBackend+"  •  every setting remains inside Huymaier Console"; columns=3;
            Grid body=new Grid{Margin=new Thickness(42,4,42,22)};body.RowDefinitions.Add(new RowDefinition{Height=new GridLength(115)});body.RowDefinitions.Add(new RowDefinition{Height=new GridLength(1,GridUnitType.Star)});contentHost.Children.Add(body);
            Border plaque=new Border{CornerRadius=new CornerRadius(10),Background=new LinearGradientBrush(Color.FromRgb(35,36,38),Color.FromRgb(9,10,11),90),BorderBrush=new SolidColorBrush(accent),BorderThickness=new Thickness(2),Padding=new Thickness(20)};Grid header=new Grid();header.Children.Add(new TextBlock{Text=definition.DisplayName.ToUpperInvariant(),FontSize=24,FontWeight=FontWeights.SemiBold,Foreground=Brushes.White,VerticalAlignment=VerticalAlignment.Center});header.Children.Add(new TextBlock{Text=String.IsNullOrWhiteSpace(settings.emulatorPath)?"EMULATOR NOT ATTACHED":Path.GetFileName(settings.emulatorPath),FontSize=11,Foreground=new SolidColorBrush(accent),HorizontalAlignment=HorizontalAlignment.Right,VerticalAlignment=VerticalAlignment.Center});plaque.Child=header;body.Children.Add(plaque);
            WrapPanel controls=new WrapPanel{Margin=new Thickness(0,12,0,0)};ScrollViewer scroll=new ScrollViewer{VerticalScrollBarVisibility=ScrollBarVisibility.Hidden,Content=controls};Grid.SetRow(scroll,1);body.Children.Add(scroll);
            if(String.IsNullOrWhiteSpace(settings.emulatorPath)||!File.Exists(settings.emulatorPath)){AddHardwareUtility(controls,"Locate Emulator","Point Huymaier Console to "+definition.PrimaryBackend,"⌕",accent,ChoosePrimaryEmulator,300,130);AddHardwareUtility(controls,"Install Latest",definition.PrimaryBackend+" official release","↓",accent,InstallPrimaryEmulator,300,130);}else AddHardwareUtility(controls,definition.PrimaryBackend,settings.emulatorPath,"✓",accent,ChoosePrimaryEmulator,300,130);
            AddHardwareUtility(controls,"Full Emulator Settings","Every discovered setting; unknown keys preserved","⚙",accent,OpenNativeBackendSettings,300,130);AddHardwareUtility(controls,"Emulator Data",DisplayPath(settings.emulatorDataPath),"▣",accent,ChooseEmulatorDataRoot,300,130);AddHardwareUtility(controls,"Game Folders",settings.gameFolders.Count.ToString(CultureInfo.InvariantCulture)+" configured","▦",accent,AddGameFolder,300,130);AddHardwareUtility(controls,"Saved Data",GetWave2SaveMediaLabel(),"◫",accent,delegate{dashboardSubpage="saves";selected=0;RenderPage();},300,130);AddHardwareUtility(controls,"Refresh Library",games.Count.ToString(CultureInfo.InvariantCulture)+" titles","↻",accent,delegate{RefreshLibrary(true);},300,130);
        }

        private void RenderAtari2600Deck()
        {
            titleText.Text=String.Empty;subtitleText.Text=String.Empty;columns=5;Grid body=new Grid{Margin=new Thickness(45,5,45,18)};body.RowDefinitions.Add(new RowDefinition{Height=new GridLength(185)});body.RowDefinitions.Add(new RowDefinition{Height=new GridLength(1,GridUnitType.Star)});contentHost.Children.Add(body);
            Border deck=new Border{CornerRadius=new CornerRadius(8),Background=new LinearGradientBrush(Color.FromRgb(60,33,17),Color.FromRgb(126,74,36),0),BorderBrush=new SolidColorBrush(Color.FromRgb(17,16,15)),BorderThickness=new Thickness(8),Padding=new Thickness(20)};Grid d=new Grid();d.ColumnDefinitions.Add(new ColumnDefinition{Width=new GridLength(1,GridUnitType.Star)});d.ColumnDefinitions.Add(new ColumnDefinition{Width=new GridLength(350)});TextBlock brand=new TextBlock{Text="ATARI\nVIDEO COMPUTER SYSTEM",FontSize=22,FontWeight=FontWeights.Light,Foreground=new SolidColorBrush(Color.FromRgb(239,213,170)),VerticalAlignment=VerticalAlignment.Center,Margin=new Thickness(35,0,0,0)};d.Children.Add(brand);StackPanel switches=new StackPanel{Orientation=Orientation.Horizontal,HorizontalAlignment=HorizontalAlignment.Center,VerticalAlignment=VerticalAlignment.Center};foreach(string name in new[]{"POWER","TV TYPE","GAME SELECT","GAME RESET"}){StackPanel sw=new StackPanel{Width=76};sw.Children.Add(new Border{Width=12,Height=52,Background=new SolidColorBrush(Color.FromRgb(215,215,207)),BorderBrush=Brushes.Black,BorderThickness=new Thickness(2),HorizontalAlignment=HorizontalAlignment.Center});sw.Children.Add(new TextBlock{Text=name,FontSize=7,Foreground=new SolidColorBrush(Color.FromRgb(238,215,179)),TextAlignment=TextAlignment.Center,HorizontalAlignment=HorizontalAlignment.Center,Margin=new Thickness(0,5,0,0)});switches.Children.Add(sw);}Grid.SetColumn(switches,1);d.Children.Add(switches);deck.Child=d;body.Children.Add(deck);
            ScrollViewer sc=new ScrollViewer{HorizontalScrollBarVisibility=ScrollBarVisibility.Hidden,VerticalScrollBarVisibility=ScrollBarVisibility.Disabled};StackPanel row=new StackPanel{Orientation=Orientation.Horizontal,VerticalAlignment=VerticalAlignment.Center};sc.Content=row;Grid.SetRow(sc,1);body.Children.Add(sc);foreach(ConsolePlatformGame game in games)AddHardwareGame(row,game,Color.FromRgb(220,149,57),136,178,"CARTRIDGE");AddHardwareUtility(row,"Console Setup",definition.PrimaryBackend,"⚙",Color.FromRgb(143,76,34),delegate{OpenWave1Subpage("settings");},150,178);
        }

        private void RenderNesDeck()
        {
            titleText.Text=String.Empty;subtitleText.Text=String.Empty;columns=6;Grid body=new Grid{Margin=new Thickness(55,0,55,16)};body.RowDefinitions.Add(new RowDefinition{Height=new GridLength(155)});body.RowDefinitions.Add(new RowDefinition{Height=new GridLength(1,GridUnitType.Star)});contentHost.Children.Add(body);Border console=new Border{CornerRadius=new CornerRadius(4),Background=new LinearGradientBrush(Color.FromRgb(204,203,198),Color.FromRgb(128,128,125),90),BorderBrush=new SolidColorBrush(Color.FromRgb(54,54,53)),BorderThickness=new Thickness(3),Padding=new Thickness(20)};Grid c=new Grid();c.ColumnDefinitions.Add(new ColumnDefinition());c.ColumnDefinitions.Add(new ColumnDefinition{Width=new GridLength(320)});Border slot=new Border{Height=45,Background=new SolidColorBrush(Color.FromRgb(36,37,37)),BorderBrush=new SolidColorBrush(Color.FromRgb(81,81,79)),BorderThickness=new Thickness(4),VerticalAlignment=VerticalAlignment.Center,Margin=new Thickness(30,0,45,0)};c.Children.Add(slot);StackPanel right=new StackPanel{VerticalAlignment=VerticalAlignment.Center};right.Children.Add(new TextBlock{Text="Nintendo\nENTERTAINMENT SYSTEM",FontSize=20,FontWeight=FontWeights.Bold,Foreground=new SolidColorBrush(Color.FromRgb(186,34,41)),HorizontalAlignment=HorizontalAlignment.Center,TextAlignment=TextAlignment.Center});right.Children.Add(new TextBlock{Text="POWER     RESET",FontSize=9,Foreground=new SolidColorBrush(Color.FromRgb(55,55,54)),HorizontalAlignment=HorizontalAlignment.Center,Margin=new Thickness(0,15,0,0)});Grid.SetColumn(right,1);c.Children.Add(right);console.Child=c;body.Children.Add(console);WrapPanel cards=new WrapPanel{Margin=new Thickness(0,12,0,0)};ScrollViewer scroll=new ScrollViewer{VerticalScrollBarVisibility=ScrollBarVisibility.Hidden,Content=cards};Grid.SetRow(scroll,1);body.Children.Add(scroll);foreach(ConsolePlatformGame game in games)AddHardwareGame(cards,game,Color.FromRgb(194,35,42),132,170,"GAME PAK");AddHardwareUtility(cards,"Control Deck",definition.PrimaryBackend,"⚙",Color.FromRgb(194,35,42),delegate{OpenWave1Subpage("settings");},145,170);
        }

        private void RenderSnesDeck()
        {
            titleText.Text=String.Empty;subtitleText.Text=String.Empty;columns=6;Grid body=new Grid{Margin=new Thickness(55,0,55,16)};body.RowDefinitions.Add(new RowDefinition{Height=new GridLength(160)});body.RowDefinitions.Add(new RowDefinition{Height=new GridLength(1,GridUnitType.Star)});contentHost.Children.Add(body);Border console=new Border{CornerRadius=new CornerRadius(30),Background=new LinearGradientBrush(Color.FromRgb(216,215,212),Color.FromRgb(153,151,154),90),BorderBrush=new SolidColorBrush(Color.FromRgb(98,95,105)),BorderThickness=new Thickness(3),Padding=new Thickness(22)};Grid c=new Grid();Border slot=new Border{Width=420,Height=44,Background=new SolidColorBrush(Color.FromRgb(77,75,84)),BorderBrush=new SolidColorBrush(Color.FromRgb(130,127,137)),BorderThickness=new Thickness(3),HorizontalAlignment=HorizontalAlignment.Center,VerticalAlignment=VerticalAlignment.Center};c.Children.Add(slot);c.Children.Add(new TextBlock{Text="SUPER NINTENDO\nENTERTAINMENT SYSTEM",FontSize=16,FontWeight=FontWeights.SemiBold,Foreground=new SolidColorBrush(Color.FromRgb(78,75,87)),HorizontalAlignment=HorizontalAlignment.Left,VerticalAlignment=VerticalAlignment.Center,Margin=new Thickness(25,0,0,0),TextAlignment=TextAlignment.Center});c.Children.Add(new TextBlock{Text="●  ●  ●  ●",FontSize=23,Foreground=new SolidColorBrush(Color.FromRgb(103,74,151)),HorizontalAlignment=HorizontalAlignment.Right,VerticalAlignment=VerticalAlignment.Center,Margin=new Thickness(0,0,35,0)});console.Child=c;body.Children.Add(console);WrapPanel cards=new WrapPanel{Margin=new Thickness(0,10,0,0)};ScrollViewer scroll=new ScrollViewer{VerticalScrollBarVisibility=ScrollBarVisibility.Hidden,Content=cards};Grid.SetRow(scroll,1);body.Children.Add(scroll);foreach(ConsolePlatformGame game in games)AddHardwareGame(cards,game,Color.FromRgb(103,74,151),132,170,"GAME PAK");AddHardwareUtility(cards,"Console Setup",definition.PrimaryBackend,"⚙",Color.FromRgb(103,74,151),delegate{OpenWave1Subpage("settings");},145,170);
        }

        private void RenderGameBoyHandheld(bool colorModel)
        {
            titleText.Text=String.Empty;subtitleText.Text=String.Empty;columns=4;Grid body=new Grid{Margin=new Thickness(70,0,70,20)};body.ColumnDefinitions.Add(new ColumnDefinition{Width=new GridLength(410)});body.ColumnDefinitions.Add(new ColumnDefinition());contentHost.Children.Add(body);Color shell=colorModel?Color.FromRgb(86,38,131):Color.FromRgb(190,191,181);Border handheld=new Border{Width=330,Height=520,CornerRadius=new CornerRadius(18,18,55,18),HorizontalAlignment=HorizontalAlignment.Center,VerticalAlignment=VerticalAlignment.Center,Background=new LinearGradientBrush(shell,Color.FromRgb((byte)Math.Max(0,shell.R-35),(byte)Math.Max(0,shell.G-35),(byte)Math.Max(0,shell.B-35)),90),BorderBrush=new SolidColorBrush(Color.FromRgb(69,69,67)),BorderThickness=new Thickness(3),Padding=new Thickness(25)};StackPanel h=new StackPanel();h.Children.Add(new TextBlock{Text=colorModel?"GAME BOY COLOR":"DOT MATRIX WITH STEREO SOUND",FontSize=colorModel?22:9,FontWeight=FontWeights.SemiBold,Foreground=colorModel?Brushes.White:new SolidColorBrush(Color.FromRgb(56,65,100)),HorizontalAlignment=HorizontalAlignment.Center});Border screen=new Border{Height=230,Margin=new Thickness(0,18,0,20),CornerRadius=new CornerRadius(8),Background=new SolidColorBrush(colorModel?Color.FromRgb(82,91,78):Color.FromRgb(119,137,84)),BorderBrush=new SolidColorBrush(Color.FromRgb(55,55,55)),BorderThickness=new Thickness(12)};ConsolePlatformGame selectedGame=games.Count>0?games[Math.Max(0,Math.Min(games.Count-1,selected))]:null;if(selectedGame!=null&&!String.IsNullOrWhiteSpace(selectedGame.Cover)&&File.Exists(selectedGame.Cover)){try{screen.Child=new Image{Source=LoadBitmap(selectedGame.Cover),Stretch=Stretch.Uniform};}catch{}}if(screen.Child==null)screen.Child=new TextBlock{Text=games.Count+"\nGAMES",FontFamily=new FontFamily("Consolas"),FontSize=28,FontWeight=FontWeights.Bold,Foreground=new SolidColorBrush(Color.FromRgb(30,53,30)),HorizontalAlignment=HorizontalAlignment.Center,VerticalAlignment=VerticalAlignment.Center,TextAlignment=TextAlignment.Center};h.Children.Add(screen);h.Children.Add(new TextBlock{Text="✚                       A     B",FontSize=25,Foreground=colorModel?Brushes.White:new SolidColorBrush(Color.FromRgb(73,65,88)),HorizontalAlignment=HorizontalAlignment.Center});h.Children.Add(new TextBlock{Text="SELECT     START",FontSize=10,Foreground=colorModel?Brushes.White:new SolidColorBrush(Color.FromRgb(73,65,88)),HorizontalAlignment=HorizontalAlignment.Center,Margin=new Thickness(0,26,0,0)});handheld.Child=h;body.Children.Add(handheld);WrapPanel list=new WrapPanel{Margin=new Thickness(15)};ScrollViewer sc=new ScrollViewer{VerticalScrollBarVisibility=ScrollBarVisibility.Hidden,Content=list};Grid.SetColumn(sc,1);body.Children.Add(sc);Color accent=colorModel?Color.FromRgb(244,73,142):Color.FromRgb(117,44,111);foreach(ConsolePlatformGame game in games)AddHardwareGame(list,game,accent,120,155,"PAK");AddHardwareUtility(list,"System",definition.PrimaryBackend,"⚙",accent,delegate{OpenWave1Subpage("settings");},132,155);
        }

        private void RenderGbaHandheld()
        {
            titleText.Text=String.Empty;subtitleText.Text=String.Empty;columns=5;Grid body=new Grid{Margin=new Thickness(38,8,38,18)};body.RowDefinitions.Add(new RowDefinition{Height=new GridLength(330)});body.RowDefinitions.Add(new RowDefinition{Height=new GridLength(1,GridUnitType.Star)});contentHost.Children.Add(body);Border handheld=new Border{CornerRadius=new CornerRadius(110),Background=new LinearGradientBrush(Color.FromRgb(91,65,159),Color.FromRgb(53,36,103),90),BorderBrush=new SolidColorBrush(Color.FromRgb(33,24,65)),BorderThickness=new Thickness(4),Padding=new Thickness(36),Margin=new Thickness(45,0,45,8)};Grid h=new Grid();h.ColumnDefinitions.Add(new ColumnDefinition{Width=new GridLength(150)});h.ColumnDefinitions.Add(new ColumnDefinition());h.ColumnDefinitions.Add(new ColumnDefinition{Width=new GridLength(150)});h.Children.Add(new TextBlock{Text="✚",FontSize=64,Foreground=new SolidColorBrush(Color.FromRgb(39,31,70)),HorizontalAlignment=HorizontalAlignment.Center,VerticalAlignment=VerticalAlignment.Center});Border screen=new Border{CornerRadius=new CornerRadius(10),Background=new SolidColorBrush(Color.FromRgb(39,55,58)),BorderBrush=new SolidColorBrush(Color.FromRgb(24,26,33)),BorderThickness=new Thickness(11),Margin=new Thickness(10)};Grid.SetColumn(screen,1);screen.Child=new TextBlock{Text="GAME BOY\nADVANCE",FontSize=26,FontStyle=FontStyles.Italic,Foreground=new SolidColorBrush(Color.FromRgb(169,185,182)),HorizontalAlignment=HorizontalAlignment.Center,VerticalAlignment=VerticalAlignment.Center,TextAlignment=TextAlignment.Center};h.Children.Add(screen);TextBlock ab=new TextBlock{Text="A    B",FontSize=30,FontWeight=FontWeights.Bold,Foreground=new SolidColorBrush(Color.FromRgb(183,156,241)),HorizontalAlignment=HorizontalAlignment.Center,VerticalAlignment=VerticalAlignment.Center};Grid.SetColumn(ab,2);h.Children.Add(ab);handheld.Child=h;body.Children.Add(handheld);WrapPanel cards=new WrapPanel();ScrollViewer scroll=new ScrollViewer{VerticalScrollBarVisibility=ScrollBarVisibility.Hidden,Content=cards};Grid.SetRow(scroll,1);body.Children.Add(scroll);foreach(ConsolePlatformGame game in games)AddHardwareGame(cards,game,Color.FromRgb(168,145,255),126,158,"GBA");AddHardwareUtility(cards,"System",definition.PrimaryBackend,"⚙",Color.FromRgb(92,66,157),delegate{OpenWave1Subpage("settings");},140,158);
        }

        private void RenderGenesisDeck(bool thirtyTwoX)
        {
            titleText.Text=String.Empty;subtitleText.Text=String.Empty;columns=6;Grid body=new Grid{Margin=new Thickness(50,0,50,18)};body.RowDefinitions.Add(new RowDefinition{Height=new GridLength(210)});body.RowDefinitions.Add(new RowDefinition{Height=new GridLength(1,GridUnitType.Star)});contentHost.Children.Add(body);Border deck=new Border{CornerRadius=new CornerRadius(105),Background=new RadialGradientBrush(Color.FromRgb(47,49,51),Color.FromRgb(4,5,6)),BorderBrush=new SolidColorBrush(Color.FromRgb(72,74,76)),BorderThickness=new Thickness(5),Margin=new Thickness(160,0,160,10)};Grid g=new Grid();g.Children.Add(new Border{Width=thirtyTwoX?220:330,Height=thirtyTwoX?130:55,CornerRadius=new CornerRadius(thirtyTwoX?18:5),Background=new SolidColorBrush(Color.FromRgb(15,16,17)),BorderBrush=new SolidColorBrush(Color.FromRgb(78,80,82)),BorderThickness=new Thickness(4),HorizontalAlignment=HorizontalAlignment.Center,VerticalAlignment=VerticalAlignment.Center});g.Children.Add(new TextBlock{Text=thirtyTwoX?"SEGA 32X\n32-BIT ENHANCEMENT":"16-BIT\nSEGA GENESIS",FontSize=thirtyTwoX?22:18,FontWeight=FontWeights.Bold,Foreground=new SolidColorBrush(thirtyTwoX?Color.FromRgb(224,60,48):Color.FromRgb(210,210,211)),HorizontalAlignment=HorizontalAlignment.Center,VerticalAlignment=VerticalAlignment.Center,TextAlignment=TextAlignment.Center});deck.Child=g;body.Children.Add(deck);WrapPanel cards=new WrapPanel();ScrollViewer scroll=new ScrollViewer{VerticalScrollBarVisibility=ScrollBarVisibility.Hidden,Content=cards};Grid.SetRow(scroll,1);body.Children.Add(scroll);Color accent=thirtyTwoX?Color.FromRgb(224,60,48):Color.FromRgb(191,34,45);foreach(ConsolePlatformGame game in games)AddHardwareGame(cards,game,accent,126,158,thirtyTwoX?"32X":"GENESIS");AddHardwareUtility(cards,"System",definition.PrimaryBackend,"⚙",accent,delegate{OpenWave1Subpage("settings");},140,158);
        }

        private void RenderSegaCdDeck()
        {
            titleText.Text=String.Empty;subtitleText.Text=String.Empty;columns=4;Grid body=new Grid{Margin=new Thickness(65,0,65,18)};body.RowDefinitions.Add(new RowDefinition{Height=new GridLength(250)});body.RowDefinitions.Add(new RowDefinition{Height=new GridLength(1,GridUnitType.Star)});contentHost.Children.Add(body);Border system=new Border{CornerRadius=new CornerRadius(12),Background=new LinearGradientBrush(Color.FromRgb(38,41,45),Color.FromRgb(5,7,9),90),BorderBrush=new SolidColorBrush(Color.FromRgb(76,82,88)),BorderThickness=new Thickness(4),Padding=new Thickness(22),Margin=new Thickness(145,0,145,10)};Grid s=new Grid();System.Windows.Shapes.Ellipse tray=new System.Windows.Shapes.Ellipse{Width=210,Height=210,Fill=new RadialGradientBrush(Color.FromRgb(37,39,42),Color.FromRgb(6,7,8)),Stroke=new SolidColorBrush(Color.FromRgb(100,105,109)),StrokeThickness=4,HorizontalAlignment=HorizontalAlignment.Left};s.Children.Add(tray);TextBlock label=new TextBlock{Text="SEGA CD\nCD-ROM SYSTEM",FontSize=24,FontWeight=FontWeights.Light,Foreground=new SolidColorBrush(Color.FromRgb(157,195,228)),HorizontalAlignment=HorizontalAlignment.Right,VerticalAlignment=VerticalAlignment.Center,Margin=new Thickness(0,0,65,0),TextAlignment=TextAlignment.Center};s.Children.Add(label);system.Child=s;body.Children.Add(system);WrapPanel cards=new WrapPanel();ScrollViewer scroll=new ScrollViewer{VerticalScrollBarVisibility=ScrollBarVisibility.Hidden,Content=cards};Grid.SetRow(scroll,1);body.Children.Add(scroll);foreach(ConsolePlatformGame game in games)AddHardwareGame(cards,game,Color.FromRgb(80,147,214),132,166,"COMPACT DISC");AddHardwareUtility(cards,"CD Player","local disc audio","♪",Color.FromRgb(80,147,214),delegate{OpenWave1Subpage("music");},145,166);AddHardwareUtility(cards,"Backup RAM","saved games","▣",Color.FromRgb(56,112,167),delegate{OpenWave1Subpage("saves");},145,166);AddHardwareUtility(cards,"System",definition.PrimaryBackend,"⚙",Color.FromRgb(45,88,130),delegate{OpenWave1Subpage("settings");},145,166);
        }

        private void RenderGameGearHandheld()
        {
            titleText.Text=String.Empty;subtitleText.Text=String.Empty;columns=5;Grid body=new Grid{Margin=new Thickness(35,5,35,18)};body.RowDefinitions.Add(new RowDefinition{Height=new GridLength(335)});body.RowDefinitions.Add(new RowDefinition{Height=new GridLength(1,GridUnitType.Star)});contentHost.Children.Add(body);Border handheld=new Border{CornerRadius=new CornerRadius(95),Background=new LinearGradientBrush(Color.FromRgb(34,39,45),Color.FromRgb(8,10,12),90),BorderBrush=new SolidColorBrush(Color.FromRgb(58,65,72)),BorderThickness=new Thickness(4),Padding=new Thickness(32),Margin=new Thickness(100,0,100,10)};Grid h=new Grid();h.ColumnDefinitions.Add(new ColumnDefinition{Width=new GridLength(170)});h.ColumnDefinitions.Add(new ColumnDefinition());h.ColumnDefinitions.Add(new ColumnDefinition{Width=new GridLength(170)});h.Children.Add(new TextBlock{Text="✚",FontSize=58,Foreground=new SolidColorBrush(Color.FromRgb(52,60,68)),HorizontalAlignment=HorizontalAlignment.Center,VerticalAlignment=VerticalAlignment.Center});Border screen=new Border{Background=new SolidColorBrush(Color.FromRgb(29,43,50)),BorderBrush=new SolidColorBrush(Color.FromRgb(5,7,9)),BorderThickness=new Thickness(12),CornerRadius=new CornerRadius(7),Margin=new Thickness(5),Child=new TextBlock{Text="GAME GEAR",FontSize=29,FontWeight=FontWeights.Bold,Foreground=new SolidColorBrush(Color.FromRgb(47,137,205)),HorizontalAlignment=HorizontalAlignment.Center,VerticalAlignment=VerticalAlignment.Center}};Grid.SetColumn(screen,1);h.Children.Add(screen);TextBlock buttons=new TextBlock{Text="1    2",FontSize=30,Foreground=new SolidColorBrush(Color.FromRgb(198,49,55)),HorizontalAlignment=HorizontalAlignment.Center,VerticalAlignment=VerticalAlignment.Center};Grid.SetColumn(buttons,2);h.Children.Add(buttons);handheld.Child=h;body.Children.Add(handheld);WrapPanel cards=new WrapPanel();ScrollViewer scroll=new ScrollViewer{VerticalScrollBarVisibility=ScrollBarVisibility.Hidden,Content=cards};Grid.SetRow(scroll,1);body.Children.Add(scroll);foreach(ConsolePlatformGame game in games)AddHardwareGame(cards,game,Color.FromRgb(47,137,205),126,158,"GAME GEAR");AddHardwareUtility(cards,"System",definition.PrimaryBackend,"⚙",Color.FromRgb(47,137,205),delegate{OpenWave1Subpage("settings");},140,158);
        }

        private void RenderMasterSystemDeck()
        {
            titleText.Text=String.Empty;subtitleText.Text=String.Empty;columns=6;Grid body=new Grid{Margin=new Thickness(55,0,55,18)};body.RowDefinitions.Add(new RowDefinition{Height=new GridLength(160)});body.RowDefinitions.Add(new RowDefinition{Height=new GridLength(1,GridUnitType.Star)});contentHost.Children.Add(body);Border deck=new Border{Background=new LinearGradientBrush(Color.FromRgb(44,45,46),Color.FromRgb(7,8,9),90),BorderBrush=new SolidColorBrush(Color.FromRgb(93,94,95)),BorderThickness=new Thickness(3),Padding=new Thickness(24)};Grid g=new Grid();g.Children.Add(new TextBlock{Text="SEGA\nMASTER SYSTEM",FontSize=24,FontWeight=FontWeights.Bold,Foreground=Brushes.White,HorizontalAlignment=HorizontalAlignment.Left,VerticalAlignment=VerticalAlignment.Center,Margin=new Thickness(35,0,0,0),TextAlignment=TextAlignment.Center});g.Children.Add(new Border{Width=400,Height=45,Background=new SolidColorBrush(Color.FromRgb(14,15,16)),BorderBrush=new SolidColorBrush(Color.FromRgb(206,31,39)),BorderThickness=new Thickness(0,5,0,0),HorizontalAlignment=HorizontalAlignment.Center,VerticalAlignment=VerticalAlignment.Center});g.Children.Add(new TextBlock{Text="POWER  ●     RESET  ○",FontSize=11,Foreground=new SolidColorBrush(Color.FromRgb(206,31,39)),HorizontalAlignment=HorizontalAlignment.Right,VerticalAlignment=VerticalAlignment.Center,Margin=new Thickness(0,0,40,0)});deck.Child=g;body.Children.Add(deck);WrapPanel cards=new WrapPanel{Margin=new Thickness(0,10,0,0)};ScrollViewer scroll=new ScrollViewer{VerticalScrollBarVisibility=ScrollBarVisibility.Hidden,Content=cards};Grid.SetRow(scroll,1);body.Children.Add(scroll);foreach(ConsolePlatformGame game in games)AddHardwareGame(cards,game,Color.FromRgb(206,31,39),126,158,"CARTRIDGE");AddHardwareUtility(cards,"System",definition.PrimaryBackend,"⚙",Color.FromRgb(206,31,39),delegate{OpenWave1Subpage("settings");},140,158);
        }

        private void RenderTurboGrafxDeck()
        {
            titleText.Text=String.Empty;subtitleText.Text=String.Empty;columns=6;Grid body=new Grid{Margin=new Thickness(55,0,55,18)};body.RowDefinitions.Add(new RowDefinition{Height=new GridLength(155)});body.RowDefinitions.Add(new RowDefinition{Height=new GridLength(1,GridUnitType.Star)});contentHost.Children.Add(body);Border deck=new Border{CornerRadius=new CornerRadius(5),Background=new LinearGradientBrush(Color.FromRgb(235,234,230),Color.FromRgb(184,183,178),90),BorderBrush=new SolidColorBrush(Color.FromRgb(103,103,100)),BorderThickness=new Thickness(3),Padding=new Thickness(22)};Grid g=new Grid();g.Children.Add(new TextBlock{Text="TurboGrafx-16\nENTERTAINMENT SUPER SYSTEM",FontSize=21,FontWeight=FontWeights.SemiBold,Foreground=new SolidColorBrush(Color.FromRgb(67,67,65)),HorizontalAlignment=HorizontalAlignment.Left,VerticalAlignment=VerticalAlignment.Center,Margin=new Thickness(35,0,0,0),TextAlignment=TextAlignment.Center});g.Children.Add(new Border{Width=290,Height=12,Background=new SolidColorBrush(Color.FromRgb(55,55,53)),HorizontalAlignment=HorizontalAlignment.Center,VerticalAlignment=VerticalAlignment.Center});g.Children.Add(new TextBlock{Text="POWER",FontSize=10,Foreground=new SolidColorBrush(Color.FromRgb(193,34,42)),HorizontalAlignment=HorizontalAlignment.Right,VerticalAlignment=VerticalAlignment.Center,Margin=new Thickness(0,0,55,0)});deck.Child=g;body.Children.Add(deck);WrapPanel cards=new WrapPanel{Margin=new Thickness(0,10,0,0)};ScrollViewer scroll=new ScrollViewer{VerticalScrollBarVisibility=ScrollBarVisibility.Hidden,Content=cards};Grid.SetRow(scroll,1);body.Children.Add(scroll);foreach(ConsolePlatformGame game in games)AddHardwareGame(cards,game,Color.FromRgb(193,34,42),126,158,Path.GetExtension(game.Path).Equals(".cue",StringComparison.OrdinalIgnoreCase)||Path.GetExtension(game.Path).Equals(".chd",StringComparison.OrdinalIgnoreCase)?"CD-ROM²":"HUCARD");AddHardwareUtility(cards,"System",definition.PrimaryBackend,"⚙",Color.FromRgb(193,34,42),delegate{OpenWave1Subpage("settings");},140,158);
        }

        private void RenderXboxRoot()
        {
            string[] names=new string[]{"play game","memory","music","settings"};string[] detail=new string[]{games.Count.ToString(CultureInfo.InvariantCulture)+" titles ready to launch","saved games and storage","soundtracks and dashboard ambience","console and emulator options"};page=Math.Max(0,Math.Min(page,names.Length-1));titleText.Text=names[page];subtitleText.Text=detail[page];
            Grid scene=new Grid{Margin=new Thickness(24,8,24,18)};contentHost.Children.Add(scene);Border glow=new Border{Width=460,Height=260,CornerRadius=new CornerRadius(150,18,150,18),Background=new RadialGradientBrush(Color.FromArgb(225,76,196,28),Color.FromArgb(240,0,16,0)),BorderBrush=new SolidColorBrush(Color.FromRgb(113,238,61)),BorderThickness=new Thickness(3),HorizontalAlignment=HorizontalAlignment.Center,VerticalAlignment=VerticalAlignment.Center};StackPanel s=new StackPanel{VerticalAlignment=VerticalAlignment.Center};s.Children.Add(new TextBlock{Text=names[page].ToUpperInvariant(),FontSize=44,FontWeight=FontWeights.Bold,FontStyle=FontStyles.Italic,Foreground=Brushes.White,HorizontalAlignment=HorizontalAlignment.Center});s.Children.Add(new TextBlock{Text="A  select",FontSize=14,Foreground=new SolidColorBrush(Color.FromRgb(173,231,145)),HorizontalAlignment=HorizontalAlignment.Center,Margin=new Thickness(0,16,0,0)});glow.Child=s;scene.Children.Add(glow);
            System.Windows.Shapes.Ellipse ring=new System.Windows.Shapes.Ellipse{Width=720,Height=390,Stroke=new SolidColorBrush(Color.FromArgb(100,130,255,77)),StrokeThickness=8,HorizontalAlignment=HorizontalAlignment.Center,VerticalAlignment=VerticalAlignment.Center};scene.Children.Insert(0,ring);
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
            titleText.Text = "settings"; subtitleText.Text = "console and emulator configuration";
            WrapPanel panel = new WrapPanel { Margin = new Thickness(14) }; contentHost.Children.Add(panel);
            AddDashboardTile(panel, "network settings", "open xemu configuration", delegate { OpenFolderForExecutable(settings.emulatorPath); }, Color.FromRgb(37, 103, 19), 300, 190, "●");
            AddDashboardTile(panel, "games", games.Count.ToString(CultureInfo.InvariantCulture) + " titles", delegate { page = 0; selected = 0; RenderPage(); }, Color.FromRgb(29, 80, 13), 300, 190, "▶");
        }

        private void RenderXbox360Home()
        {
            titleText.Text = "home"; subtitleText.Text = Environment.UserName + "  •  " + GetXboxGamerscore().ToString(CultureInfo.InvariantCulture) + " G"; StackPanel panel = new StackPanel { Margin = new Thickness(4, 0, 4, 16) }; contentHost.Children.Add(new ScrollViewer { VerticalScrollBarVisibility = ScrollBarVisibility.Hidden, Content = panel });
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

        private void RenderXbox360Profile()
        {
            titleText.Text = "profile"; subtitleText.Text = Environment.UserName + "  •  local Xenia profile"; WrapPanel panel = new WrapPanel { Margin = new Thickness(0, 4, 0, 14) }; contentHost.Children.Add(new ScrollViewer { VerticalScrollBarVisibility = ScrollBarVisibility.Hidden, Content = panel }); AddDashboardTile(panel, Environment.UserName, GetXboxGamerscore().ToString(CultureInfo.InvariantCulture) + " G", OpenXboxAchievements, Color.FromRgb(20, 151, 35), 440, 220, "☺"); AddDashboardTile(panel, "achievements", xboxAchievementsLoaded ? xboxAchievements.Count(delegate(XboxAchievementEntry a) { return a.Earned; }).ToString(CultureInfo.InvariantCulture) + " unlocked" : "read Xenia profile", OpenXboxAchievements, Color.FromRgb(20, 137, 34), 215, 220, "★"); AddDashboardTile(panel, "storage", "saved games", OpenXboxStorageManager, Color.FromRgb(53, 91, 51), 215, 220, "▣");
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

        private static char GetLibraryInitial(ConsolePlatformGame game)
        {
            if (game == null || String.IsNullOrWhiteSpace(game.Name)) return '#';
            char value = Char.ToUpperInvariant(game.Name.Trim()[0]);
            return Char.IsLetter(value) ? value : '#';
        }

        private List<char> GetAvailableLibraryLetters()
        {
            List<char> result = new List<char>();
            foreach (char letter in "#ABCDEFGHIJKLMNOPQRSTUVWXYZ")
            {
                if (games.Any(delegate(ConsolePlatformGame game) { return GetLibraryInitial(game) == letter; })) result.Add(letter);
            }
            return result;
        }

        private int FindFirstGameIndex(char letter)
        {
            for (int i = 0; i < games.Count; i++) if (GetLibraryInitial(games[i]) == letter) return i;
            return 0;
        }

        private int GetWiiMenuPageCount() { return Math.Max(1, (games.Count + 11) / 12); }

        private bool TryProcessLibraryLetterJump(XmbInputCommand command)
        {
            if (games == null || games.Count == 0) return false;
            bool n64 = definition.Shell == "N64" && IsRootConsoleSurface() && n64Zone == 0;
            bool gameCube = definition.Shell == "GameCube" && !IsRootConsoleSurface() && page == 0;
            bool wii = definition.Shell == "Wii" && IsRootConsoleSurface();
            bool wave2 = IsWave2Shell() && IsRootConsoleSurface() && selected >= 0 && selected < games.Count;
            if (!n64 && !gameCube && !wii && !wave2) return false;

            int currentIndex = n64 ? n64LibraryIndex : (gameCube ? Math.Max(0, Math.Min(games.Count - 1, selected)) : (wave2 ? Math.Max(0, Math.Min(games.Count - 1, selected)) : Math.Max(0, Math.Min(games.Count - 1, wiiMenuPage * 12 + Math.Min(selected, 11)))));
            List<char> letters = GetAvailableLibraryLetters();
            if (letters.Count == 0) return false;
            char current = GetLibraryInitial(games[currentIndex]);
            int letterIndex = letters.IndexOf(current);
            if (letterIndex < 0) letterIndex = 0;
            int delta = command == XmbInputCommand.LeftShoulder ? -1 : 1;
            letterIndex = (letterIndex + delta + letters.Count) % letters.Count;
            int target = FindFirstGameIndex(letters[letterIndex]);

            if (n64) n64LibraryIndex = target;
            else if (gameCube || wave2) selected = target;
            else
            {
                wiiMenuPage = target / 12;
                selected = target % 12;
            }
            PlayEffect("Tab.wav");
            RenderPage();
            return true;
        }

        private Border BuildLibraryAlphabetRail(int currentGameIndex, bool light)
        {
            StackPanel lettersPanel = new StackPanel { Orientation = Orientation.Horizontal, HorizontalAlignment = HorizontalAlignment.Center, VerticalAlignment = VerticalAlignment.Center };
            char current = games.Count == 0 ? '#' : GetLibraryInitial(games[Math.Max(0, Math.Min(games.Count - 1, currentGameIndex))]);
            foreach (char letter in "#ABCDEFGHIJKLMNOPQRSTUVWXYZ")
            {
                bool available = games.Any(delegate(ConsolePlatformGame game) { return GetLibraryInitial(game) == letter; });
                TextBlock text = new TextBlock
                {
                    Text = letter.ToString(),
                    FontSize = letter == current ? 16 : 11,
                    FontWeight = letter == current ? FontWeights.Bold : FontWeights.Normal,
                    Foreground = new SolidColorBrush(letter == current ? (light ? Color.FromRgb(30, 155, 197) : definition.Accent) : (available ? (light ? Color.FromRgb(91, 108, 114) : Color.FromRgb(205, 205, 214)) : (light ? Color.FromRgb(188, 198, 202) : Color.FromRgb(82, 82, 92)))),
                    Margin = new Thickness(5, 0, 5, 0),
                    VerticalAlignment = VerticalAlignment.Center
                };
                lettersPanel.Children.Add(text);
            }
            return new Border { Height = 32, HorizontalAlignment = HorizontalAlignment.Center, VerticalAlignment = VerticalAlignment.Top, Padding = new Thickness(12, 4, 12, 4), CornerRadius = new CornerRadius(12), Background = new SolidColorBrush(light ? Color.FromArgb(225, 248, 251, 252) : Color.FromArgb(160, 12, 12, 18)), Child = lettersPanel };
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
            titleText.Text = "Memory Card"; subtitleText.Text = "Native Slot A / Slot B save browser";
            List<GameCubeMemoryCardInfo> cards = ScanGameCubeMemoryCards(roots);
            Grid body = new Grid { Margin = new Thickness(30, 6, 30, 20) }; body.ColumnDefinitions.Add(new ColumnDefinition()); body.ColumnDefinitions.Add(new ColumnDefinition()); contentHost.Children.Add(body);
            for (int slotIndex = 0; slotIndex < 2; slotIndex++)
            {
                GameCubeMemoryCardInfo card = slotIndex < cards.Count ? cards[slotIndex] : null;
                Color accent = slotIndex == 0 ? Color.FromRgb(101, 217, 255) : Color.FromRgb(121, 255, 172);
                Border slot = new Border { Margin = new Thickness(14), CornerRadius = new CornerRadius(38), Background = new SolidColorBrush(Color.FromArgb(220, 35, 27, 82)), BorderBrush = new SolidColorBrush(accent), BorderThickness = new Thickness(4), Padding = new Thickness(20) };
                Grid panel = new Grid(); panel.RowDefinitions.Add(new RowDefinition { Height = new GridLength(78) }); panel.RowDefinitions.Add(new RowDefinition { Height = new GridLength(1, GridUnitType.Star) }); panel.RowDefinitions.Add(new RowDefinition { Height = new GridLength(74) });
                StackPanel heading = new StackPanel { HorizontalAlignment = HorizontalAlignment.Center }; heading.Children.Add(new TextBlock { Text = "MEMORY CARD  " + (slotIndex == 0 ? "A" : "B"), FontSize = 24, FontWeight = FontWeights.Bold, Foreground = Brushes.White, HorizontalAlignment = HorizontalAlignment.Center }); heading.Children.Add(new TextBlock { Text = card == null ? "No card detected" : card.Saves.Count.ToString(CultureInfo.InvariantCulture) + " save(s)  •  " + Math.Max(0, card.TotalBlocks - card.FreeBlocks).ToString(CultureInfo.InvariantCulture) + " / " + card.TotalBlocks.ToString(CultureInfo.InvariantCulture) + " blocks", FontSize = 12, Foreground = new SolidColorBrush(Color.FromRgb(207, 202, 232)), HorizontalAlignment = HorizontalAlignment.Center }); panel.Children.Add(heading);
                WrapPanel saveGrid = new WrapPanel { HorizontalAlignment = HorizontalAlignment.Center };
                if (card != null)
                {
                    foreach (GameCubeSaveEntry save in card.Saves.Take(18))
                    {
                        GameCubeSaveEntry capturedSave = save;
                        Button saveTile = CreateGameCubeNativeSaveTile(save, accent, delegate { ShowNotice(capturedSave.Name + "  •  " + capturedSave.GameCode + "  •  " + capturedSave.Blocks.ToString(CultureInfo.InvariantCulture) + " blocks"); });
                        saveGrid.Children.Add(saveTile); actions.Add(new ConsolePlatformAction { Button = saveTile, Invoke = delegate { ShowNotice(capturedSave.Name + "  •  " + capturedSave.GameCode + "  •  " + capturedSave.Blocks.ToString(CultureInfo.InvariantCulture) + " blocks"); }, Name = save.Name });
                    }
                }
                if (saveGrid.Children.Count == 0) saveGrid.Children.Add(new TextBlock { Text = "EMPTY", FontSize = 34, Foreground = new SolidColorBrush(Color.FromArgb(180, 255, 255, 255)), Margin = new Thickness(20), HorizontalAlignment = HorizontalAlignment.Center, VerticalAlignment = VerticalAlignment.Center });
                ScrollViewer scroller = new ScrollViewer { VerticalScrollBarVisibility = ScrollBarVisibility.Hidden, Content = saveGrid }; Grid.SetRow(scroller, 1); panel.Children.Add(scroller);
                GameCubeMemoryCardInfo capturedCard = card; Button backup = CreateShellAction("BACK UP CARD " + (slotIndex == 0 ? "A" : "B"), card == null ? "No card detected" : Path.GetFileName(card.Path), delegate { if (capturedCard != null) BackupNativeSavePath(capturedCard.Path, "GameCube-Card-" + capturedCard.Slot); }, Color.FromRgb(78, 59, 151)); backup.Margin = new Thickness(30, 8, 30, 0); Grid.SetRow(backup, 2); panel.Children.Add(backup); actions.Add(new ConsolePlatformAction { Button = backup, Invoke = delegate { if (capturedCard != null) BackupNativeSavePath(capturedCard.Path, "GameCube-Card-" + capturedCard.Slot); }, Name = "Back Up Card " + (slotIndex == 0 ? "A" : "B") });
                slot.Child = panel; Grid.SetColumn(slot, slotIndex); body.Children.Add(slot);
            }
        }

        private Button CreateGameCubeNativeSaveTile(GameCubeSaveEntry save, Color accent, Action invoke)
        {
            Button button = new Button { Width = 190, Height = 108, Margin = new Thickness(7), Padding = new Thickness(10), Background = new SolidColorBrush(Color.FromRgb(42, 38, 67)), BorderBrush = new SolidColorBrush(accent), BorderThickness = new Thickness(2), RenderTransformOrigin = new Point(0.5, 0.5) };
            Grid grid = new Grid(); grid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(48) }); grid.ColumnDefinitions.Add(new ColumnDefinition());
            Border icon = new Border { Width = 40, Height = 40, CornerRadius = new CornerRadius(8), Background = new SolidColorBrush(accent), VerticalAlignment = VerticalAlignment.Center, Child = new TextBlock { Text = save.GameCode.Length > 0 ? save.GameCode.Substring(0, 1) : "G", FontSize = 20, FontWeight = FontWeights.Bold, Foreground = Brushes.White, HorizontalAlignment = HorizontalAlignment.Center, VerticalAlignment = VerticalAlignment.Center } }; grid.Children.Add(icon);
            StackPanel text = new StackPanel { Margin = new Thickness(8, 0, 0, 0), VerticalAlignment = VerticalAlignment.Center }; text.Children.Add(new TextBlock { Text = save.Name, FontSize = 12, FontWeight = FontWeights.Bold, Foreground = Brushes.White, TextTrimming = TextTrimming.CharacterEllipsis }); text.Children.Add(new TextBlock { Text = save.GameCode + "  •  " + save.Blocks.ToString(CultureInfo.InvariantCulture) + " blocks", FontSize = 9, Foreground = new SolidColorBrush(Color.FromRgb(204, 198, 226)) }); Grid.SetColumn(text, 1); grid.Children.Add(text); button.Content = grid; button.Click += delegate { invoke(); }; return button;
        }

        private void RenderWiiDataManagement(List<string> roots)
        {
            titleText.Text = "Save Data"; subtitleText.Text = "System Memory";
            List<WiiSaveEntry> saves = ScanWiiSaves(roots);
            Grid body = new Grid { Margin = new Thickness(54, 6, 54, 24) }; body.RowDefinitions.Add(new RowDefinition { Height = new GridLength(68) }); body.RowDefinitions.Add(new RowDefinition { Height = new GridLength(1, GridUnitType.Star) }); contentHost.Children.Add(body);
            Border heading = new Border { Background = new SolidColorBrush(Color.FromRgb(241, 247, 249)), BorderBrush = new SolidColorBrush(Color.FromRgb(96, 194, 220)), BorderThickness = new Thickness(2), CornerRadius = new CornerRadius(18), Padding = new Thickness(20, 10, 20, 10), Child = new TextBlock { Text = saves.Count.ToString(CultureInfo.InvariantCulture) + " saved title(s)", FontSize = 22, Foreground = new SolidColorBrush(Color.FromRgb(72, 91, 98)), HorizontalAlignment = HorizontalAlignment.Center, VerticalAlignment = VerticalAlignment.Center } }; body.Children.Add(heading);
            WrapPanel channels = new WrapPanel { HorizontalAlignment = HorizontalAlignment.Center, Margin = new Thickness(0, 14, 0, 0) };
            foreach (WiiSaveEntry save in saves)
            {
                WiiSaveEntry captured = save; Button tile = CreateChannelTile(save.Name, save.TitleId + "  •  " + FormatBytes(save.Size), delegate { BackupNativeSavePath(captured.Path, "Wii-" + captured.TitleId); }); channels.Children.Add(tile); actions.Add(new ConsolePlatformAction { Button = tile, Invoke = delegate { BackupNativeSavePath(captured.Path, "Wii-" + captured.TitleId); }, Name = save.Name });
            }
            if (saves.Count == 0) channels.Children.Add(new Border { Width = 300, Height = 150, Margin = new Thickness(12), Background = Brushes.White, BorderBrush = new SolidColorBrush(Color.FromRgb(135, 203, 221)), BorderThickness = new Thickness(3), Child = new TextBlock { Text = "No save data detected", FontSize = 18, Foreground = new SolidColorBrush(Color.FromRgb(82, 101, 109)), HorizontalAlignment = HorizontalAlignment.Center, VerticalAlignment = VerticalAlignment.Center } });
            Button backupAll = CreateChannelTile("Back Up All", "Create a recoverable Huymaier copy", BackupSaves); channels.Children.Add(backupAll); actions.Add(new ConsolePlatformAction { Button = backupAll, Invoke = BackupSaves, Name = "Back Up All" });
            ScrollViewer scroller = new ScrollViewer { VerticalScrollBarVisibility = ScrollBarVisibility.Hidden, Content = channels }; Grid.SetRow(scroller, 1); body.Children.Add(scroller);
        }

        private static ushort ReadBe16(byte[] data, int offset) { return (ushort)((data[offset] << 8) | data[offset + 1]); }
        private static short ReadBeS16(byte[] data, int offset) { return unchecked((short)ReadBe16(data, offset)); }
        private static uint ReadBe32(byte[] data, int offset) { return ((uint)data[offset] << 24) | ((uint)data[offset + 1] << 16) | ((uint)data[offset + 2] << 8) | data[offset + 3]; }

        private List<GameCubeMemoryCardInfo> ScanGameCubeMemoryCards(List<string> roots)
        {
            List<GameCubeMemoryCardInfo> cards = new List<GameCubeMemoryCardInfo>();
            List<string> candidates = new List<string>();
            foreach (string rootPath in roots)
            {
                try { foreach (string file in Directory.EnumerateFiles(rootPath, "*.raw", SearchOption.AllDirectories).Take(12)) if (!candidates.Contains(file, StringComparer.OrdinalIgnoreCase)) candidates.Add(file); } catch { }
            }
            candidates = candidates.OrderBy(delegate(string path) { return Path.GetFileName(path); }, StringComparer.CurrentCultureIgnoreCase).ToList();
            for (int i = 0; i < candidates.Count && cards.Count < 2; i++)
            {
                GameCubeMemoryCardInfo card = ParseGameCubeRawCard(candidates[i], cards.Count == 0 ? "A" : "B");
                if (card != null) cards.Add(card);
            }
            return cards;
        }

        private GameCubeMemoryCardInfo ParseGameCubeRawCard(string path, string slot)
        {
            try
            {
                const int blockSize = 0x2000;
                FileInfo info = new FileInfo(path);
                if (!info.Exists || info.Length < blockSize * 6 || info.Length % blockSize != 0) return null;
                byte[] metadata = new byte[blockSize * 5];
                using (FileStream stream = File.Open(path, FileMode.Open, FileAccess.Read, FileShare.ReadWrite))
                {
                    if (stream.Read(metadata, 0, metadata.Length) != metadata.Length) return null;
                }
                int dir0 = blockSize, dir1 = blockSize * 2, bat0 = blockSize * 3, bat1 = blockSize * 4;
                int activeDir = ReadBeS16(metadata, dir0 + 0x1FFA) >= ReadBeS16(metadata, dir1 + 0x1FFA) ? dir0 : dir1;
                int activeBat = ReadBeS16(metadata, bat0 + 0x0004) >= ReadBeS16(metadata, bat1 + 0x0004) ? bat0 : bat1;
                GameCubeMemoryCardInfo card = new GameCubeMemoryCardInfo { Slot = slot, Path = path, TotalBlocks = Math.Max(0, (int)(info.Length / blockSize) - 5), FreeBlocks = ReadBe16(metadata, activeBat + 0x0006) };
                for (int index = 0; index < 127; index++)
                {
                    int entry = activeDir + index * 0x40;
                    if (metadata[entry] == 0xFF && metadata[entry + 1] == 0xFF && metadata[entry + 2] == 0xFF && metadata[entry + 3] == 0xFF) continue;
                    string gameCode = Encoding.ASCII.GetString(metadata, entry, 4).Trim('\0', ' ', '\u00ff');
                    int nameLength = 0; while (nameLength < 0x20 && metadata[entry + 0x08 + nameLength] != 0 && metadata[entry + 0x08 + nameLength] != 0xFF) nameLength++;
                    string fileName = nameLength > 0 ? Encoding.ASCII.GetString(metadata, entry + 0x08, nameLength).Trim() : gameCode;
                    uint seconds = ReadBe32(metadata, entry + 0x28);
                    double safeSeconds = Math.Min((double)seconds, 3155760000.0); DateTime modified = new DateTime(2000, 1, 1, 0, 0, 0, DateTimeKind.Local).AddSeconds(safeSeconds);
                    card.Saves.Add(new GameCubeSaveEntry { Name = String.IsNullOrWhiteSpace(fileName) ? gameCode : fileName, GameCode = gameCode, Blocks = ReadBe16(metadata, entry + 0x38), Modified = modified, CardPath = path });
                }
                return card;
            }
            catch (Exception ex) { WritePlatformLog("GameCube memory-card parser skipped " + path + ": " + ex.Message, "WARN"); return null; }
        }

        private List<WiiSaveEntry> ScanWiiSaves(List<string> roots)
        {
            List<WiiSaveEntry> result = new List<WiiSaveEntry>();
            foreach (string rootPath in roots)
            {
                string titleRoot = Path.Combine(rootPath, "title");
                if (!Directory.Exists(titleRoot)) continue;
                string[] highDirs; try { highDirs = Directory.GetDirectories(titleRoot); } catch { continue; }
                foreach (string high in highDirs)
                {
                    string[] lowDirs; try { lowDirs = Directory.GetDirectories(high); } catch { continue; }
                    foreach (string low in lowDirs)
                    {
                        string data = Path.Combine(low, "data"); if (!Directory.Exists(data)) continue;
                        long size = GetPathSize(data); if (size <= 0) continue;
                        string lowName = Path.GetFileName(low); string titleId = Path.GetFileName(high) + lowName;
                        string code = DecodeWiiTitleCode(lowName); string display = String.IsNullOrWhiteSpace(code) ? "Save " + lowName.ToUpperInvariant() : "Save " + code;
                        DateTime modified = Directory.GetLastWriteTime(data);
                        result.Add(new WiiSaveEntry { Name = display, TitleId = titleId.ToUpperInvariant(), Path = data, Size = size, Modified = modified });
                    }
                }
            }
            return result.OrderBy(delegate(WiiSaveEntry entry) { return entry.Name; }, StringComparer.CurrentCultureIgnoreCase).ToList();
        }

        private static string DecodeWiiTitleCode(string lowHex)
        {
            try
            {
                if (String.IsNullOrWhiteSpace(lowHex) || lowHex.Length != 8) return String.Empty;
                byte[] raw = new byte[4];
                for (int i = 0; i < 4; i++) raw[i] = Convert.ToByte(lowHex.Substring(i * 2, 2), 16);
                string code = Encoding.ASCII.GetString(raw);
                return code.All(delegate(char c) { return c >= 0x20 && c <= 0x7E; }) ? code : String.Empty;
            }
            catch { return String.Empty; }
        }

        private void BackupNativeSavePath(string source, string label)
        {
            if (String.IsNullOrWhiteSpace(source) || (!File.Exists(source) && !Directory.Exists(source))) { ShowNotice("Save data is not available"); return; }
            try
            {
                string targetRoot = Path.Combine(dataRoot, "Backups", "Native", DateTime.Now.ToString("yyyyMMdd-HHmmss-fff", CultureInfo.InvariantCulture));
                Directory.CreateDirectory(targetRoot);
                string safe = Sanitize(label);
                if (File.Exists(source)) File.Copy(source, Path.Combine(targetRoot, safe + Path.GetExtension(source)), true);
                else CopyDirectory(source, Path.Combine(targetRoot, safe), 20000);
                ShowNotice("Save data backed up safely");
            }
            catch (Exception ex) { ShowNotice("Backup failed: " + ex.Message); }
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
        private void ExportXboxSave(XboxSaveEntry entry){ExportSave(entry);}
        private void ExportSave(XboxSaveEntry entry)
        {
            if(entry==null||String.IsNullOrWhiteSpace(entry.Path))return;
            try
            {
                string requestPath=Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),"Huymaier Console","EmulatorPlatforms","picker-request.json");Directory.CreateDirectory(Path.GetDirectoryName(requestPath));Dictionary<string,object> request=new Dictionary<string,object>();request["platformId"]=definition.Id;request["displayName"]=definition.DisplayName;request["action"]="ExportSave";request["sourcePath"]=entry.Path;request["suggestedName"]=Sanitize(entry.Name);request["startPath"]=Environment.GetFolderPath(Environment.SpecialFolder.UserProfile);File.WriteAllText(requestPath,new JavaScriptSerializer().Serialize(request),Encoding.UTF8);Close();
            }catch(Exception ex){ShowNotice("Export request failed: "+ex.Message);}
        }
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
            if(definition.Shell=="N64"){RenderN64Options();return;}
            if(definition.Shell=="GameCube"){RenderGameCubeOptions();return;}
            if(definition.Shell=="Wii"){RenderWiiSettings();return;}
            if(definition.Shell=="WiiU"){RenderWiiUSettings();return;}
            if(definition.Shell=="Switch"){RenderSwitchSettings();return;}
            if(definition.Shell=="Xbox"){RenderXboxSettings();return;}
            RenderXbox360Settings();
        }

        private string EmulatorStatusText()
        {
            if(!String.IsNullOrWhiteSpace(settings.emulatorPath)&&File.Exists(settings.emulatorPath))return Path.GetFileName(settings.emulatorPath);
            return "Not detected — locate or install";
        }

        private void AddCorePlatformActions(Panel panel, Func<string,string,Action,Button> factory)
        {
            Action<string,string,Action> add=delegate(string name,string detail,Action invoke){Button b=factory(name,detail,invoke);panel.Children.Add(b);actions.Add(new ConsolePlatformAction{Button=b,Invoke=invoke,Name=name});};
            add("Locate "+definition.PrimaryBackend,EmulatorStatusText(),ChoosePrimaryEmulator);
            add("Install Latest "+definition.PrimaryBackend,"Download from the emulator project's current supported release",InstallPrimaryEmulator);
            if(!String.IsNullOrWhiteSpace(definition.FallbackBackend))add("Alternate Emulator",String.IsNullOrWhiteSpace(settings.fallbackEmulatorPath)?definition.FallbackBackend:DisplayPath(settings.fallbackEmulatorPath),ChooseFallbackEmulator);
            add("Emulator Data",String.IsNullOrWhiteSpace(settings.emulatorDataPath)?"Auto-detect or choose data / cache folder":DisplayPath(settings.emulatorDataPath),ChooseEmulatorDataRoot);
            add("Game Folders",settings.gameFolders.Count.ToString(CultureInfo.InvariantCulture)+" configured — add another",AddGameFolder);
            add("Refresh Library",games.Count.ToString(CultureInfo.InvariantCulture)+" titles",delegate{RefreshLibrary(true);});
            add("Refresh Cover Art","Emulator artwork first, Huymaier cache and online sources second",QueueConsoleArtworkRefresh);
        }

        private Button CreateN64SettingsRow(string title,string detail,Action invoke)
        {
            Button b=new Button{Height=66,Margin=new Thickness(16,5,16,5),Background=new LinearGradientBrush(Color.FromRgb(45,46,50),Color.FromRgb(22,23,26),90),BorderBrush=new SolidColorBrush(Color.FromRgb(137,0,0)),BorderThickness=new Thickness(3),HorizontalContentAlignment=HorizontalAlignment.Stretch,RenderTransformOrigin=new Point(0.5,0.5)};Grid g=new Grid();g.ColumnDefinitions.Add(new ColumnDefinition{Width=new GridLength(310)});g.ColumnDefinitions.Add(new ColumnDefinition());g.Children.Add(new TextBlock{Text=title.ToUpperInvariant(),FontSize=16,FontWeight=FontWeights.Bold,Foreground=Brushes.White,VerticalAlignment=VerticalAlignment.Center,Margin=new Thickness(16,0,0,0)});TextBlock d=new TextBlock{Text=detail,FontSize=11,Foreground=new SolidColorBrush(Color.FromRgb(194,195,199)),VerticalAlignment=VerticalAlignment.Center,TextTrimming=TextTrimming.CharacterEllipsis};Grid.SetColumn(d,1);g.Children.Add(d);b.Content=g;b.Click+=delegate{invoke();};return b;
        }
        private void RenderN64Options(){titleText.Text="OPTIONS";subtitleText.Text="Nintendo 64 / emulator configuration";StackPanel p=new StackPanel{Margin=new Thickness(70,6,70,20)};contentHost.Children.Add(new ScrollViewer{VerticalScrollBarVisibility=ScrollBarVisibility.Hidden,Content=p});AddCorePlatformActions(p,CreateN64SettingsRow);}

        private Button CreateGameCubeSettingsRow(string title,string detail,Action invoke){Button b=new Button{Height=72,Margin=new Thickness(28,7,28,7),Background=new SolidColorBrush(Color.FromArgb(155,56,43,117)),BorderBrush=new SolidColorBrush(Color.FromRgb(155,137,245)),BorderThickness=new Thickness(3),HorizontalContentAlignment=HorizontalAlignment.Stretch,RenderTransformOrigin=new Point(0.5,0.5)};Grid g=new Grid();g.ColumnDefinitions.Add(new ColumnDefinition{Width=new GridLength(330)});g.ColumnDefinitions.Add(new ColumnDefinition());g.Children.Add(new TextBlock{Text=title,FontSize=19,FontWeight=FontWeights.SemiBold,Foreground=Brushes.White,VerticalAlignment=VerticalAlignment.Center,Margin=new Thickness(18,0,0,0)});TextBlock d=new TextBlock{Text=detail,FontSize=11,Foreground=new SolidColorBrush(Color.FromRgb(213,208,235)),VerticalAlignment=VerticalAlignment.Center,TextTrimming=TextTrimming.CharacterEllipsis};Grid.SetColumn(d,1);g.Children.Add(d);b.Content=g;b.Click+=delegate{invoke();};return b;}
        private void RenderGameCubeOptions(){titleText.Text="Options";subtitleText.Text="Nintendo GameCube IPL options";Border cubePanel=new Border{Margin=new Thickness(110,12,110,26),CornerRadius=new CornerRadius(46),Background=new LinearGradientBrush(Color.FromArgb(180,38,28,84),Color.FromArgb(160,73,56,142),45),BorderBrush=new SolidColorBrush(Color.FromRgb(155,137,245)),BorderThickness=new Thickness(5),Padding=new Thickness(18)};StackPanel p=new StackPanel();cubePanel.Child=new ScrollViewer{VerticalScrollBarVisibility=ScrollBarVisibility.Hidden,Content=p};contentHost.Children.Add(cubePanel);Button scale=CreateGameCubeSettingsRow("Cube Size",Math.Round(settings.gameCubeScale*100).ToString(CultureInfo.InvariantCulture)+"%  •  A cycles size",CycleGameCubeScale);p.Children.Add(scale);actions.Add(new ConsolePlatformAction{Button=scale,Invoke=CycleGameCubeScale,Name="Cube Size"});AddCorePlatformActions(p,CreateGameCubeSettingsRow);}

        private Button CreateWiiSettingsRow(string title,string detail,Action invoke){Button b=new Button{Height=70,Margin=new Thickness(32,5,32,5),Background=new LinearGradientBrush(Color.FromRgb(250,252,253),Color.FromRgb(224,231,234),90),BorderBrush=new SolidColorBrush(Color.FromRgb(80,190,220)),BorderThickness=new Thickness(3),HorizontalContentAlignment=HorizontalAlignment.Stretch,RenderTransformOrigin=new Point(0.5,0.5)};Grid g=new Grid();g.ColumnDefinitions.Add(new ColumnDefinition{Width=new GridLength(340)});g.ColumnDefinitions.Add(new ColumnDefinition());g.Children.Add(new TextBlock{Text=title,FontSize=18,Foreground=new SolidColorBrush(Color.FromRgb(77,89,94)),VerticalAlignment=VerticalAlignment.Center,Margin=new Thickness(18,0,0,0)});TextBlock d=new TextBlock{Text=detail,FontSize=11,Foreground=new SolidColorBrush(Color.FromRgb(118,130,135)),VerticalAlignment=VerticalAlignment.Center,TextTrimming=TextTrimming.CharacterEllipsis};Grid.SetColumn(d,1);g.Children.Add(d);b.Content=g;b.Click+=delegate{invoke();};return b;}
        private void RenderWiiSettings(){titleText.Text="Wii Settings";subtitleText.Text=String.Empty;StackPanel p=new StackPanel{Margin=new Thickness(100,16,100,28)};contentHost.Children.Add(new ScrollViewer{VerticalScrollBarVisibility=ScrollBarVisibility.Hidden,Content=p});AddCorePlatformActions(p,CreateWiiSettingsRow);}

        private Button CreateWiiUSettingsRow(string title,string detail,Action invoke){Button b=new Button{Height=72,Margin=new Thickness(22,6,22,6),Background=Brushes.White,BorderBrush=new SolidColorBrush(Color.FromRgb(43,165,208)),BorderThickness=new Thickness(2),HorizontalContentAlignment=HorizontalAlignment.Stretch,RenderTransformOrigin=new Point(0.5,0.5)};Grid g=new Grid();g.ColumnDefinitions.Add(new ColumnDefinition{Width=new GridLength(350)});g.ColumnDefinitions.Add(new ColumnDefinition());g.Children.Add(new TextBlock{Text=title,FontSize=18,FontWeight=FontWeights.SemiBold,Foreground=new SolidColorBrush(Color.FromRgb(44,80,92)),VerticalAlignment=VerticalAlignment.Center,Margin=new Thickness(20,0,0,0)});TextBlock d=new TextBlock{Text=detail,FontSize=11,Foreground=new SolidColorBrush(Color.FromRgb(99,122,130)),VerticalAlignment=VerticalAlignment.Center,TextTrimming=TextTrimming.CharacterEllipsis};Grid.SetColumn(d,1);g.Children.Add(d);b.Content=g;b.Click+=delegate{invoke();};return b;}
        private void RenderWiiUSettings(){titleText.Text="System Settings";subtitleText.Text="Wii U / Cemu";StackPanel p=new StackPanel{Margin=new Thickness(110,12,110,28)};contentHost.Children.Add(new ScrollViewer{VerticalScrollBarVisibility=ScrollBarVisibility.Hidden,Content=p});AddCorePlatformActions(p,CreateWiiUSettingsRow);}

        private Button CreateSwitchSettingsRow(string title,string detail,Action invoke){Button b=new Button{Height=70,Margin=new Thickness(0,0,0,2),Background=new SolidColorBrush(Color.FromRgb(48,49,54)),BorderBrush=new SolidColorBrush(Color.FromRgb(74,75,80)),BorderThickness=new Thickness(0,0,0,1),HorizontalContentAlignment=HorizontalAlignment.Stretch,RenderTransformOrigin=new Point(0.5,0.5)};Grid g=new Grid();g.ColumnDefinitions.Add(new ColumnDefinition{Width=new GridLength(360)});g.ColumnDefinitions.Add(new ColumnDefinition());g.Children.Add(new TextBlock{Text=title,FontSize=18,Foreground=Brushes.White,VerticalAlignment=VerticalAlignment.Center,Margin=new Thickness(22,0,0,0)});TextBlock d=new TextBlock{Text=detail,FontSize=11,Foreground=new SolidColorBrush(Color.FromRgb(184,185,190)),VerticalAlignment=VerticalAlignment.Center,TextTrimming=TextTrimming.CharacterEllipsis};Grid.SetColumn(d,1);g.Children.Add(d);b.Content=g;b.Click+=delegate{invoke();};return b;}
        private void RenderSwitchSettings(){titleText.Text="System Settings";subtitleText.Text=String.Empty;Grid body=new Grid{Margin=new Thickness(90,8,90,24)};body.ColumnDefinitions.Add(new ColumnDefinition{Width=new GridLength(280)});body.ColumnDefinitions.Add(new ColumnDefinition());contentHost.Children.Add(body);Border side=new Border{Background=new SolidColorBrush(Color.FromRgb(37,38,42)),Child=new TextBlock{Text="SYSTEM\nSETTINGS",FontSize=28,FontWeight=FontWeights.Light,Foreground=Brushes.White,Margin=new Thickness(28),VerticalAlignment=VerticalAlignment.Top}};body.Children.Add(side);StackPanel p=new StackPanel{Margin=new Thickness(18,0,0,0)};ScrollViewer sc=new ScrollViewer{VerticalScrollBarVisibility=ScrollBarVisibility.Hidden,Content=p};Grid.SetColumn(sc,1);body.Children.Add(sc);AddCorePlatformActions(p,CreateSwitchSettingsRow);}

        private Button CreateXboxSettingsRow(string title,string detail,Action invoke){return CreateXboxPanelRow(title,detail,invoke,"X");}
        private void RenderXboxSettings(){titleText.Text="settings";subtitleText.Text="system / emulator";StackPanel p=new StackPanel{Margin=new Thickness(26,8,26,24)};contentHost.Children.Add(new ScrollViewer{VerticalScrollBarVisibility=ScrollBarVisibility.Hidden,Content=p});AddCorePlatformActions(p,CreateXboxSettingsRow);AddXboxSettingAction(p,"Memory","Manage save storage",OpenXboxStorageManager);}
        private void AddXboxSettingAction(Panel panel,string title,string detail,Action invoke){Button b=CreateXboxSettingsRow(title,detail,invoke);panel.Children.Add(b);actions.Add(new ConsolePlatformAction{Button=b,Invoke=invoke,Name=title});}

        private Button CreateXbox360SettingsRow(string title,string detail,Action invoke){return IsBlades()?CreateBladePanelButton(title,detail,invoke,Color.FromRgb(103,76,151)):CreateShellAction(title,detail,invoke,Color.FromRgb(83,156,44));}
        private void RenderXbox360Settings(){titleText.Text=IsBlades()?"system":"settings";subtitleText.Text="Xbox 360 / Xenia";StackPanel p=new StackPanel{Margin=new Thickness(22,4,22,24)};contentHost.Children.Add(new ScrollViewer{VerticalScrollBarVisibility=ScrollBarVisibility.Hidden,Content=p});AddCorePlatformActions(p,CreateXbox360SettingsRow);Button storage=CreateXbox360SettingsRow("Storage","Manage Xenia saves",OpenXboxStorageManager);p.Children.Insert(0,storage);actions.Insert(0,new ConsolePlatformAction{Button=storage,Invoke=OpenXboxStorageManager,Name="Storage"});Button achievements=CreateXbox360SettingsRow("Achievements",GetXboxGamerscore().ToString(CultureInfo.InvariantCulture)+" G earned",OpenXboxAchievements);p.Children.Insert(1,achievements);actions.Insert(1,new ConsolePlatformAction{Button=achievements,Invoke=OpenXboxAchievements,Name="Achievements"});Button style=CreateXbox360SettingsRow("Dashboard Style",settings.dashboardStyle,CycleDashboardStyle);p.Children.Insert(2,style);actions.Insert(2,new ConsolePlatformAction{Button=style,Invoke=CycleDashboardStyle,Name="Dashboard Style"});}


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

        private void ChoosePrimaryEmulator(){RequestHuymaierPicker("PrimaryEmulator");}
        private void ChooseFallbackEmulator(){RequestHuymaierPicker("FallbackEmulator");}
        private void ChooseEmulatorDataRoot(){RequestHuymaierPicker("DataRoot");}
        private void AddGameFolder(){RequestHuymaierPicker("GameFolder");}
        private void ChooseAmbience(){RequestHuymaierPicker("Ambience");}
        private void InstallPrimaryEmulator(){RequestHuymaierPicker("InstallPrimaryEmulator");}

        private void RequestHuymaierPicker(string action)
        {
            try
            {
                string requestPath=Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),"Huymaier Console","EmulatorPlatforms","picker-request.json");
                Directory.CreateDirectory(Path.GetDirectoryName(requestPath));
                Dictionary<string,object> request=new Dictionary<string,object>();request["platformId"]=definition.Id;request["displayName"]=definition.DisplayName;request["action"]=action;request["primaryBackend"]=definition.PrimaryBackend;request["fallbackBackend"]=definition.FallbackBackend;request["startPath"]=GetPickerStartPath(action);request["requestedAtUtc"]=DateTime.UtcNow.ToString("o",CultureInfo.InvariantCulture);
                File.WriteAllText(requestPath,new JavaScriptSerializer().Serialize(request),Encoding.UTF8);
                WritePlatformLog("Requested Huymaier picker action "+action+" for "+definition.Id,"INFO");
                Close();
            }
            catch(Exception ex){WritePlatformLog("Could not request Huymaier picker: "+ex,"ERROR");ShowNotice("Huymaier file browser could not be opened");}
        }
        private string GetPickerStartPath(string action)
        {
            string value=String.Empty;if(action=="PrimaryEmulator")value=settings.emulatorPath;else if(action=="FallbackEmulator")value=settings.fallbackEmulatorPath;else if(action=="DataRoot")value=settings.emulatorDataPath;else if(action=="GameFolder"&&settings.gameFolders.Count>0)value=settings.gameFolders[settings.gameFolders.Count-1];else if(action=="Ambience")value=settings.ambiencePath;
            try{if(File.Exists(value))return Path.GetDirectoryName(value);if(Directory.Exists(value))return value;}catch{}return Environment.GetFolderPath(Environment.SpecialFolder.UserProfile);
        }











        private void OpenFolderForExecutable(string executable)
        {
            try { string folder = !String.IsNullOrWhiteSpace(executable) && File.Exists(executable) ? Path.GetDirectoryName(executable) : dataRoot; Process.Start("explorer.exe", "\"" + folder + "\""); } catch { }
        }

        private void OpenFirstSaveRoot()
        {
            List<string> roots = FindSaveRoots(); if (roots.Count > 0) Process.Start("explorer.exe", "\"" + roots[0] + "\""); else ShowNotice("No storage folder detected");
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


        private void CycleGameCubeScale()
        {
            double[] levels = new double[] { 0.52, 0.60, 0.66, 0.74, 0.82, 0.90 };
            int index = 0; double best = Double.MaxValue;
            for (int i = 0; i < levels.Length; i++) { double delta = Math.Abs(levels[i] - settings.gameCubeScale); if (delta < best) { best = delta; index = i; } }
            settings.gameCubeScale = levels[(index + 1) % levels.Length];
            settings.Save(settingsPath);
            ShowNotice("Cube size " + Math.Round(settings.gameCubeScale * 100).ToString(CultureInfo.InvariantCulture) + "%");
            RenderPage();
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
                    QueueConsoleArtworkRefresh();
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
            QueueConsoleArtworkRefresh();
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
            string title=CleanName(Path.GetFileNameWithoutExtension(gamePath));
            string emulator=FindEmulatorArtwork(gamePath,title);if(!String.IsNullOrWhiteSpace(emulator))return emulator;
            string shared=FindSharedArtwork(title);if(!String.IsNullOrWhiteSpace(shared))return shared;
            string cached=GetConsoleArtworkCachePath(title);if(File.Exists(cached))return cached;
            return String.Empty;
        }

        private string FindEmulatorArtwork(string gamePath,string title)
        {
            List<string> roots=new List<string>();Action<string> add=delegate(string value){if(String.IsNullOrWhiteSpace(value))return;try{if(File.Exists(value))value=Path.GetDirectoryName(value);if(Directory.Exists(value)&&!roots.Contains(value,StringComparer.OrdinalIgnoreCase))roots.Add(value);}catch{}};
            string gameFolder=String.Empty;try{gameFolder=Path.GetDirectoryName(gamePath);}catch{}add(gameFolder);add(settings.emulatorDataPath);add(settings.emulatorPath);add(settings.fallbackEmulatorPath);
            foreach(string root in roots.ToArray())
            {
                foreach(string name in new[]{"covers","cover","GameCovers","boxart","thumbnails","artwork","images","icons","cache","screenshots","textures"}){try{string nested=Path.Combine(root,name);if(Directory.Exists(nested))add(nested);}catch{}}
            }
            string normalized=NormalizeArtworkTitle(title);string best=String.Empty;double bestScore=0;
            foreach(string root in roots)
            {
                try
                {
                    foreach(string file in Directory.EnumerateFiles(root,"*.*",SearchOption.TopDirectoryOnly).Take(1200))
                    {
                        string ext=Path.GetExtension(file);if(!new[]{".png",".jpg",".jpeg",".webp"}.Contains(ext,StringComparer.OrdinalIgnoreCase))continue;string candidate=NormalizeArtworkTitle(Path.GetFileNameWithoutExtension(file));double score=candidate==normalized?1.0:(candidate.Contains(normalized)||normalized.Contains(candidate)?0.82:0.0);if(score>bestScore){bestScore=score;best=file;if(score>=1.0)return best;}
                    }
                }catch{}
            }
            return bestScore>=0.8?best:String.Empty;
        }

        private string GetConsoleArtworkCachePath(string title)
        {
            string safe=title??"game";foreach(char invalid in Path.GetInvalidFileNameChars())safe=safe.Replace(invalid,'_');if(safe.Length>110)safe=safe.Substring(0,110);if(String.IsNullOrWhiteSpace(safe))safe="game";string folder=Path.Combine(dataRoot,"Artwork","BoxArt");try{Directory.CreateDirectory(folder);}catch{}return Path.Combine(folder,safe+".png");
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

        private string GetXboxArtworkCachePath(string title){return GetConsoleArtworkCachePath(title);}

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

        private string TryDownloadXboxCover(ConsolePlatformGame game){return TryDownloadConsoleCover(game);}
        private string TryDownloadConsoleCover(ConsolePlatformGame game)
        {
            if(game==null||String.IsNullOrWhiteSpace(game.Name))return String.Empty;
            string emulator=FindEmulatorArtwork(game.Path,game.Name);if(!String.IsNullOrWhiteSpace(emulator))return emulator;
            string shared=FindSharedArtwork(game.Name);if(!String.IsNullOrWhiteSpace(shared))return shared;
            string target=GetConsoleArtworkCachePath(game.Name);if(File.Exists(target))return target;
            string system=definition.Shell=="N64"?"Nintendo - Nintendo 64":definition.Shell=="GameCube"?"Nintendo - GameCube":definition.Shell=="Wii"?"Nintendo - Wii":definition.Shell=="WiiU"?"Nintendo - Wii U":definition.Shell=="Switch"?"Nintendo - Nintendo Switch":definition.Shell=="Xbox360"?"Microsoft - Xbox 360":"Microsoft - Xbox";
            string repo=system.Replace(" ","_");string temp=target+".download";
            foreach(string variant in GetXboxArtworkNameVariants(game.Name))
            {
                string encoded=Uri.EscapeDataString(variant);string[] urls=new[]{"https://thumbnails.libretro.com/"+Uri.EscapeDataString(system)+"/Named_Boxarts/"+encoded+".png","https://raw.githubusercontent.com/libretro-thumbnails/"+repo+"/master/Named_Boxarts/"+encoded+".png"};
                foreach(string url in urls)
                {
                    try{HttpWebRequest request=(HttpWebRequest)WebRequest.Create(url);request.UserAgent="HuymaierConsole/0.26.3";request.Timeout=4500;request.ReadWriteTimeout=6500;request.AutomaticDecompression=DecompressionMethods.GZip|DecompressionMethods.Deflate;using(WebResponse response=request.GetResponse())using(Stream input=response.GetResponseStream())using(FileStream output=File.Create(temp))input.CopyTo(output);if(IsDownloadedPng(temp)){if(File.Exists(target))File.Delete(target);File.Move(temp,target);return target;}}catch{}try{if(File.Exists(temp))File.Delete(temp);}catch{}
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

        private void QueueXboxArtworkRefresh(){QueueConsoleArtworkRefresh();}
        private void QueueConsoleArtworkRefresh()
        {
            if(closing||consoleArtworkScanRunning||games==null||games.Count==0)return;List<ConsolePlatformGame> missing=games.Where(delegate(ConsolePlatformGame game){return game!=null&&!String.IsNullOrWhiteSpace(game.Path)&&(String.IsNullOrWhiteSpace(game.Cover)||!File.Exists(game.Cover));}).Select(delegate(ConsolePlatformGame game){return new ConsolePlatformGame{Name=game.Name,Path=game.Path,Cover=game.Cover};}).ToList();if(missing.Count==0)return;consoleArtworkScanRunning=true;int generation=asyncGeneration;
            System.Threading.ThreadPool.QueueUserWorkItem(delegate{try{Dictionary<string,string> found=new Dictionary<string,string>(StringComparer.OrdinalIgnoreCase);foreach(ConsolePlatformGame game in missing){if(closing||generation!=asyncGeneration)break;string cover=FindEmulatorArtwork(game.Path,game.Name);if(String.IsNullOrWhiteSpace(cover))cover=TryDownloadConsoleCover(game);if(!String.IsNullOrWhiteSpace(cover)&&File.Exists(cover))found[game.Path]=cover;}try{if(Dispatcher.HasShutdownStarted||Dispatcher.HasShutdownFinished)return;Dispatcher.BeginInvoke(new Action(delegate{if(!CanApplyAsync(generation))return;consoleArtworkScanRunning=false;int added=0;foreach(ConsolePlatformGame game in games){string cover;if(game!=null&&found.TryGetValue(game.Path,out cover)&&File.Exists(cover)){game.Cover=cover;added++;}}if(added>0){SaveCachedGames();RenderPage();ShowNotice(added.ToString(CultureInfo.InvariantCulture)+" game cover"+(added==1?"":"s")+" refreshed");}}));}catch{}}catch(Exception ex){consoleArtworkScanRunning=false;WritePlatformLog(definition.DisplayName+" artwork worker recovered: "+ex,"ERROR");}});
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



        private string BuildMameOverrideArguments()
        {
            string path=Path.Combine(dataRoot,"mame-command-line-overrides.json");if(!File.Exists(path))return String.Empty;
            try{Dictionary<string,object> values=new JavaScriptSerializer().Deserialize<Dictionary<string,object>>(File.ReadAllText(path,Encoding.UTF8));if(values==null)return String.Empty;StringBuilder result=new StringBuilder();foreach(KeyValuePair<string,object> pair in values.OrderBy(delegate(KeyValuePair<string,object> item){return item.Key;},StringComparer.OrdinalIgnoreCase)){string key=pair.Key??String.Empty;if(!System.Text.RegularExpressions.Regex.IsMatch(key,"^[A-Za-z0-9_.-]+$"))continue;string value=pair.Value==null?String.Empty:Convert.ToString(pair.Value,CultureInfo.InvariantCulture);if(String.IsNullOrWhiteSpace(value))continue;if(result.Length>0)result.Append(' ');result.Append('-').Append(key).Append(' ').Append(QuoteProcessArgument(value));}return result.ToString();}catch(Exception ex){WritePlatformLog("Could not read MAME launch overrides: "+ex.Message,"WARN");return String.Empty;}
        }

        private string BuildStellaOverrideArguments()
        {
            string path = Path.Combine(dataRoot, "stella-command-line-overrides.json");
            if (!File.Exists(path)) return String.Empty;
            try
            {
                Dictionary<string, object> values = new JavaScriptSerializer().Deserialize<Dictionary<string, object>>(File.ReadAllText(path, Encoding.UTF8));
                if (values == null || values.Count == 0) return String.Empty;
                StringBuilder result = new StringBuilder();
                foreach (KeyValuePair<string, object> pair in values.OrderBy(delegate(KeyValuePair<string, object> item) { return item.Key; }, StringComparer.OrdinalIgnoreCase))
                {
                    string key = pair.Key ?? String.Empty; if (!System.Text.RegularExpressions.Regex.IsMatch(key, "^[A-Za-z0-9_.-]+$")) continue;
                    string value = pair.Value == null ? String.Empty : Convert.ToString(pair.Value, CultureInfo.InvariantCulture); if (String.IsNullOrWhiteSpace(value)) continue;
                    if (result.Length > 0) result.Append(' '); result.Append('-').Append(key).Append(' ').Append(QuoteProcessArgument(value));
                }
                return result.ToString();
            }
            catch (Exception ex) { WritePlatformLog("Could not read Stella launch overrides: " + ex.Message, "WARN"); return String.Empty; }
        }

        private string BuildLaunchArguments(string executable, string gamePath)
        {
            string exe = Path.GetFileName(executable).ToLowerInvariant();
            string quoted = "\"" + gamePath.Replace("\"", String.Empty) + "\"";
            if (definition.Shell == "Arcade" && exe.IndexOf("mame", StringComparison.OrdinalIgnoreCase) >= 0) { string driver=Path.GetFileNameWithoutExtension(gamePath); string romDir=Path.GetDirectoryName(gamePath); string overrides=BuildMameOverrideArguments(); StringBuilder mame=new StringBuilder(); if(!String.IsNullOrWhiteSpace(overrides))mame.Append(overrides).Append(' '); if(!String.IsNullOrWhiteSpace(romDir))mame.Append("-rompath ").Append(QuoteProcessArgument(romDir)).Append(' '); mame.Append(driver); return mame.ToString(); }
            if (definition.Shell == "Atari2600" && exe.IndexOf("stella", StringComparison.OrdinalIgnoreCase) >= 0) { string overrides = BuildStellaOverrideArguments(); return (String.IsNullOrWhiteSpace(overrides) ? String.Empty : overrides + " ") + quoted; }
            if (definition.Shell == "GameCube" || definition.Shell == "Wii") return "-b -e " + quoted;
            if (definition.Shell == "3DS") return quoted;
            if (definition.Shell == "NDS" || definition.Shell == "DSI") return quoted;
            if (definition.Shell == "Dreamcast") return quoted;
            if (definition.Shell == "Saturn") return quoted;
            if (definition.Shell == "PSP") return quoted;
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
            if (definition.Shell == "GameCube")
            {
                string dolphinData = settings.emulatorDataPath;
                AddExisting(roots, Path.Combine(dolphinData, "GC"));
                AddExisting(roots, Path.Combine(exeRoot, "User", "GC"));
            }
            else if (definition.Shell == "Wii")
            {
                string dolphinData = settings.emulatorDataPath;
                AddExisting(roots, Path.Combine(dolphinData, "Wii"));
                AddExisting(roots, Path.Combine(exeRoot, "User", "Wii"));
            }
            else if (definition.Shell == "WiiU") { AddExisting(roots, Path.Combine(exeRoot, "mlc01", "usr", "save")); AddExisting(roots, Path.Combine(local, "Cemu", "mlc01", "usr", "save")); }
            else if (definition.Shell == "3DS")
            {
                string azaharData=settings.emulatorDataPath; AddExisting(roots, Path.Combine(azaharData,"sdmc")); AddExisting(roots, Path.Combine(azaharData,"nand")); AddExisting(roots,Path.Combine(app,"Azahar","sdmc")); AddExisting(roots,Path.Combine(app,"azahar","sdmc"));
            }
            else if (definition.Shell == "NDS")
            {
                AddExisting(roots, settings.emulatorDataPath); AddExisting(roots, Path.Combine(app,"melonDS")); AddExisting(roots, Path.Combine(local,"melonDS"));
            }
            else if (definition.Shell == "DSI")
            {
                AddExisting(roots, settings.emulatorDataPath); AddExisting(roots, Path.Combine(settings.emulatorDataPath,"NAND")); AddExisting(roots, Path.Combine(app,"melonDS")); AddExisting(roots, Path.Combine(local,"melonDS"));
            }
            else if (definition.Shell == "Dreamcast")
            {
                AddExisting(roots, settings.emulatorDataPath); AddExisting(roots, Path.Combine(exeRoot,"data")); AddExisting(roots, exeRoot); AddExisting(roots, Path.Combine(app,"flycast")); AddExisting(roots, Path.Combine(local,"flycast"));
            }
            else if (definition.Shell == "Saturn")
            {
                AddExisting(roots, Path.Combine(settings.emulatorDataPath,"sav")); AddExisting(roots, Path.Combine(exeRoot,"sav")); AddExisting(roots, Path.Combine(docs,"Mednafen","sav")); AddExisting(roots, Path.Combine(app,"Mednafen","sav"));
            }
            else if (definition.Shell == "PSP")
            {
                AddExisting(roots, Path.Combine(settings.emulatorDataPath,"PSP","SAVEDATA")); AddExisting(roots, Path.Combine(settings.emulatorDataPath,"memstick","PSP","SAVEDATA")); AddExisting(roots, Path.Combine(exeRoot,"memstick","PSP","SAVEDATA")); AddExisting(roots, Path.Combine(docs,"PPSSPP","PSP","SAVEDATA"));
            }
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
