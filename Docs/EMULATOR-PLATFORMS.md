# Native emulator platforms

Huymaier Console keeps emulator backends external and opens each supported system as a compiled in-process platform view.

## PlayStation 1

- Backend: DuckStation
- Interface: native in-process PlayStation classic view with Games, Memory Cards, Save States and Settings
- Existing DuckStation installations are detected in standard, legacy Documents and portable layouts
- Optional managed portable install goes to a user-selected external folder
- Cached game library, existing DuckStation cover reuse, multi-disc grouping and # through Z navigation
- DuckStation Big Picture/fullscreen launch with return to the PlayStation main menu
- Native PS1 memory-card save browsing, icons, backup, export, copy, recoverable delete and card creation
- BIOS selection/status and user-supplied startup/menu audio

## PlayStation 3

- Backend: RPCS3
- Interface: native XMB
- Existing or user-folder-managed RPCS3 installation
- Native library, firmware assets, trophies, settings, photos, saved data and game launching
- XMB color modes: Automatic month/time cycle, fixed Custom color, or Theme Controlled

## PlayStation 2

- Backend: PCSX2
- Interface: native channel-based PlayStation 2 view inspired by the Broadband Navigator/HDD-OSD presentation
- User-facing branding remains PlayStation 2
- Existing or user-folder-managed PCSX2 installation
- Native BIOS selection/status, game-library folders, game booting, global/per-game settings, memory cards, saves, photos, music, movies, patches, cheats, widescreen fixes, texture replacements, cache and logs
- PCSX2 desktop UI is retained only as an advanced troubleshooting option

No emulator firmware, BIOS, copyrighted console program files, games, system audio, or Sony-owned interface assets are bundled. Personal interface assets can be selected at runtime.
