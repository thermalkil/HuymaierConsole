# Huymaier Console v0.26.4 platform implementation status

This file distinguishes research/staging from production-ready platform enablement. A native-looking surface is not considered complete until launch, Huymaier path selection, latest-emulator installation, complete native emulator settings, save/storage behavior, controller navigation and x64 compilation are all gated.

## Baseline retained from v0.26.3 RC4

Existing interfaces remain separate and are not replaced by expansion work: PS1, PS2, PS3, Nintendo 64, GameCube, Wii, Wii U, Nintendo Switch, Original Xbox and Xbox 360.

## Expansion Wave 1 — enabled in v0.26.4 development

- PlayStation Portable — PPSSPP — PSP XMB + Saved Data Utility
- Nintendo DS — melonDS — dual-screen DS firmware-style surface
- Nintendo DSi — melonDS — DSi Menu / system-memory surface
- Nintendo 3DS — Azahar — dual-screen HOME Menu / Data Management surface
- Sega Dreamcast — Flycast — BIOS Play / File / Music / Settings + VMU management
- Sega Saturn — Mednafen, Kronos fallback — BIOS/CD-player style surface + backup-memory manager

Wave 1 has passed Windows PowerShell 5.1 parsing and the exact x64 managed/native host compile. Each platform uses the shared native backend-settings editor and Huymaier picker/install contract.

## Expansion Wave 2 — staged, not enabled until all backend audits are complete

- Atari 2600 — Stella, ares fallback — woodgrain VCS control deck
- NES — Mesen Community Edition, ares fallback — NES Control Deck
- SNES — Mesen Community Edition, ares fallback — Super NES Control Deck
- Game Boy — SameBoy, Mesen CE fallback — DMG-01 handheld
- Game Boy Color — SameBoy, Mesen CE fallback — CGB handheld
- Game Boy Advance — mGBA, Mesen CE fallback — AGB-001 handheld
- Sega Genesis — ares, BlastEm fallback — Model 1 control deck
- Sega CD — ares, Mednafen fallback — Model 1 CD-ROM system
- Sega 32X — ares, PicoDrive fallback — Genesis + 32X tower
- Sega Game Gear — Mesen CE, ares fallback — Game Gear handheld
- Sega Master System — Mesen CE, ares fallback — Master System control deck
- TurboGrafx-16 — Mednafen, Mesen CE fallback — HuCard/CD system

Wave 2 hardware renderers have passed the exact x64 compile. The backend layer includes dynamic latest-release installation, JSON/TOML/INI/BML/YAML/key-value preservation infrastructure, save-memory presentation and large-library first-letter acceleration. Atari 2600 additionally uses an installed-version Stella `-help` adapter so Huymaier does not write Stella 7's SQLite database directly. SameBoy remains under settings-completeness audit before Wave 2 is globally enabled.

## Expansion Wave 3 — staged, disabled pending backend/storage completion

- Atari Lynx — Mednafen, ares fallback — Lynx handheld
- Neo Geo — FinalBurn Neo, MAME fallback — AES/MVS cartridge system
- Neo Geo Pocket Color — Mednafen, ares fallback — NGPC handheld
- Atari Jaguar — BigPEmu, Virtual Jaguar fallback — Jaguar console/keypad identity; `Sega Jaguar` remains a ROM-folder alias only
- Metroid PrimeHack — PrimeHack, Dolphin fallback — Prime visor HUD

The Wave 3 native surfaces are intentionally disabled until their current installer/settings/storage gates complete. BigPEmu uses its official download page rather than a pinned third-party build; its complete settings format remains under audit.

## Expansion Wave 4 — staged, disabled pending arcade content/storage completion

- Arcade — MAME, FinalBurn Neo fallback — cabinet/marquee/operator panel
- Final Burn Neo — FinalBurn Neo, MAME fallback — arcade board/operator surface

MAME is treated as an arcade machine database, not a generic ROM-path executable. The backend design discovers the installed version's complete option inventory using `-showconfig`, stores only reversible Huymaier command-line overrides, and launches ROM sets using driver name + `-rompath`.

## Expansion Wave 5 — staged, disabled pending installed-content models

- PlayStation 4 — shadPS4 — Dynamic Menu-style surface
- PlayStation Vita — Vita3K — LiveArea-style surface

These stay disabled until Huymaier understands installed/extracted PS4 applications and Vita3K installed-title/content records instead of pretending every package file is directly launchable.

## Global completion gates for every emulator platform

1. Distinct native console/handheld/arcade visual identity; no shared visible generic platform menu.
2. Controller-local D-pad navigation, A/Cross confirm, B/Circle one layer back.
3. Guide/Home remains Huymaier Game Bar while a native console surface is active.
4. LB/RB never changes normal pages/selections. First-letter library acceleration is the only permitted exception on large libraries.
5. Huymaier native file browser owns emulator, library, BIOS/firmware/NAND/data/save/media path selection.
6. Missing emulator offers Locate Emulator and Install Latest Supported Emulator.
7. Complete meaningful emulator settings are exposed inside Huymaier, with unknown/new config keys preserved and a backup before writes.
8. Global and per-game override capability is used where the backend supports it.
9. Emulator/local artwork is preferred, then Huymaier/provider cache, then online fallback.
10. Native save/storage presentation is implemented where the original platform has a recognizable storage model.
11. PowerShell 5.1 parse and exact x64 managed/native compile are required before generated source is committed.
12. Expansion platforms stay disabled until their platform-specific launch/settings/storage gates are complete.
