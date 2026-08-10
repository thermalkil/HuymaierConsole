# Huymaier Console v0.26.4 Platform Expansion

This branch begins from the exact source used for the successful v0.26.3 RC4 candidate (`9f3b5b390dd24f82ecce129c1e25dbc97bf598a5`). RC4 remains immutable for real-machine testing.

## Non-negotiable platform rules

1. Every platform gets a distinct console/handheld/arcade identity. Shared infrastructure is allowed; a generic shared visible menu is not.
2. If original hardware had a real system menu, firmware UI, dashboard, media player, memory manager, or home screen, reproduce its spatial model and navigation closely while exposing only functionality Huymaier Console can actually perform.
3. If the original hardware had no dashboard, derive an original Huymaier interface from the physical console/controller/cartridge/card/CD design and, where useful, documented later first-party mini-console navigation. Do not redistribute proprietary theme assets or fonts.
4. Every emulator path, firmware/BIOS path, ROM/library folder, save location, import/export destination, and optional media path uses the Huymaier controller-first file browser.
5. A missing emulator always presents **Locate Emulator** and **Install Latest Supported Emulator** inside the platform's own visual language.
6. Emulator installers resolve current official project releases dynamically; do not freeze stale download versions into the package.
7. Emulator-provided artwork and local emulator metadata are preferred first, then Huymaier cache/provider artwork, then online fallback.
8. SteamGridDB is an optional PC-storefront artwork fallback. Steam uses Steam AppID matching; non-Steam storefronts use normalized title matching. No shared API key is embedded.
9. Guide/Home remains owned by Huymaier Game Bar while a native console surface or launched game is foreground.
10. LB/RB never changes normal pages or selections. A platform with a very large library may explicitly use LB/RB only for first-letter/alphabet acceleration.

## Native emulator settings contract

Every supported backend must have a Huymaier adapter that exposes all meaningful end-user settings without requiring the emulator desktop settings window for routine configuration.

Required setting groups:

- **System / Hardware** — emulated model, region, language, clocks/timing, firmware and hardware options.
- **Graphics / Display** — renderer/backend, resolution/scale, aspect, VSync, filtering, shaders, texture options, HDR where supported, latency/presentation options.
- **Audio** — backend/device where supported, volume, latency/buffer, interpolation/filtering and system-specific sound options.
- **Input** — device assignment, mappings, deadzones, motion/touch, multitap/link/peripheral settings and hotkeys relevant to gameplay.
- **Paths / Firmware** — emulator data root, game roots, firmware/BIOS/NAND/keys where legally user-supplied, screenshots, saves, texture packs and other backend-specific roots.
- **Network / Multiplayer** — only settings the emulator actually supports; no fake online service entries.
- **Enhancements / Compatibility** — speedhacks, accuracy options, patches, cheats, texture replacement, widescreen, overclocking and similar supported features.
- **Save / Storage** — native memory-card/VMU/backup-RAM/save-data views when the original platform has a recognizable storage model.
- **Advanced** — remaining documented user-facing backend options, clearly marked when changing them may reduce compatibility.
- **Per-game** — Huymaier-native per-title overrides whenever the emulator has an override/profile mechanism.

Adapters must preserve unknown emulator keys when writing configuration. Huymaier Console should modify only the selected setting rather than rewriting a backend config from a reduced schema.

## Emulator adapter strategy

- **MAME** — `mame.ini`, machine/system INI hierarchy and command-line option surface; use MAME's own `-showconfig`/documentation as the authoritative setting vocabulary.
- **Stella** — documented command-line/advanced configuration and per-ROM properties.
- **Mednafen** — `mednafen.cfg`, optional per-module `<system>.cfg`, and per-game `pgconfig` override files. Mednafen documents that any setting can also be supplied on the command line.
- **FinalBurn Neo** — native Windows configuration, DIP-switch/game input configuration and current project-supported option set.
- **PrimeHack / Dolphin** — Dolphin and PrimeHack INI files, controller profiles, graphics settings, paths and PrimeHack-specific gameplay/view controls.
- **Azahar** — current desktop configuration and per-game settings; Huymaier mirrors current setting keys rather than Citra-era stale assumptions.
- **melonDS** — current DS/DSi global configuration, renderer/audio/input/screen settings, firmware/NAND/BIOS and per-title behavior where supported.
- **Mesen Community Edition** — current community-maintained Mesen configuration for NES/SNES/GB/GBA/PCE/SMS/GG.
- **SameBoy** — hardware model/revision, color correction/palettes, audio, link/peripherals, input and display settings.
- **mGBA** — native configuration, BIOS, display/color, audio, input/link/peripherals, cheats and per-game overrides.
- **shadPS4** — current emulator/core configuration and installed-title folders; because the project is still early, Huymaier labels experimental compatibility options accordingly.
- **ares** — current `settings.bml`/core-specific settings; recent releases provide core-specific input configuration and an alternate settings-file CLI option, useful for safe Huymaier-managed profiles.
- **Flycast** — global and game-specific Dreamcast/Naomi configuration, renderer, paths, VMUs, network and input.
- **BigPEmu** — system timing, video/HDR/post-processing, audio, input/keypad overlays, Jaguar CD, networking/scripts and per-game profiles.
- **Kronos** — optional Saturn enhancement backend; only used as a selectable alternative to the accuracy-first Saturn backend.
- **PPSSPP** — Graphics, Audio, Controls, Networking, Tools, System, hidden/advanced documented settings and native per-game overrides.
- **Vita3K** — current renderer, audio, input, firmware/modules, paths and per-title configuration.

## Missing platform inventory from the user's ROM root

The screenshot contains 38 top-level folders. `Backup` is not a console. Ten platform identities already exist in Huymaier Console (PS1, PS2, PS3, N64, GameCube, Wii, Wii U, Switch, Original Xbox and Xbox 360). The remaining 27 platform surfaces targeted by this branch are:

1. Arcade
2. Atari 2600
3. Atari Lynx
4. Final Burn Neo
5. Metroid Prime Hack / PrimeHack
6. Neo Geo
7. Neo Geo Pocket Color
8. Nintendo 3DS
9. Nintendo DS
10. Nintendo DSi
11. Nintendo Entertainment System
12. Nintendo Game Boy
13. Nintendo Game Boy Advance
14. Nintendo Game Boy Color
15. PlayStation 4
16. Sega 32X
17. Sega CD / Mega CD
18. Sega Dreamcast
19. Sega Game Gear
20. Sega Genesis / Mega Drive
21. Atari Jaguar (also accept the existing `Sega Jaguar` folder name as an alias)
22. Sega Master System
23. Sega Saturn
24. PlayStation Portable
25. PlayStation Vita
26. Super Nintendo Entertainment System
27. TurboGrafx-16 / PC Engine

The machine-readable backend/interface choices and implementation waves live in `.development/v0.26.4/platform-expansion.json`.

## Implementation waves

**Wave 1 — real firmware/home-menu systems:** Nintendo 3DS, Nintendo DS, Nintendo DSi, Dreamcast, Saturn, PSP. These provide strong original UI references and establish the new generalized native-settings adapter contract.

**Wave 2 — cartridge/card/CD hardware surfaces:** Atari 2600, NES, SNES, Game Boy, Game Boy Color, GBA, Genesis, Sega CD, 32X, Game Gear, Master System and TurboGrafx-16.

**Wave 3 — specialty hardware:** Atari Lynx, Neo Geo, Neo Geo Pocket Color, Atari Jaguar and PrimeHack.

**Wave 4 — arcade:** MAME-backed Arcade and FinalBurn Neo with cabinet/operator/DIP-switch presentation.

**Wave 5 — experimental modern PlayStation:** PS4/shadPS4 and Vita/Vita3K. These require more dynamic title-install and compatibility handling than file-based cartridge/disc libraries.

Each wave stays disabled in the production platform registry until its native interface, launch path, save/storage behavior, emulator adapter and navigation regression tests are present. This prevents generic or half-functional console pages from appearing simply because a folder was detected.
