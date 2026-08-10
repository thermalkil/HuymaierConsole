# Huymaier Console

Huymaier Console is a controller-first Windows 11 full-screen console shell with native storefront, emulator-platform, library, downloads, system settings, update, artwork, controller, media, and Game Bar integrations.

## Current baseline

The current published stable release is **v0.26.2**.

The active development branch for **v0.26.3** is focused on native-console fidelity and emulator integration. It preserves the tested v0.26.2 Game Bar/Guide behavior and leaves the PS1, PS2, and PS3 visual/interface implementations frozen except for the shared Huymaier emulator/path handoff requested for all emulator platforms.

Confirmed behaviors carried forward include:

- Native Steam, GOG, Epic, Amazon, Xbox, and emulator-platform library integration.
- Shared authoritative artwork between Library, Shelf, storefronts, and native console views.
- Steam owned-library recovery and authoritative owned counts.
- Controller-first Quick Access and Huymaier Game Bar behavior.
- Game Bar over external apps and Huymaier-native console surfaces while the main shell keeps Guide/Home mapped to Quick Access.
- Native console interfaces for supported emulator platforms.
- Storefront-aware Games page and application-only Apps page.
- Persistent Games layout editing and controller-first customization.
- Epic/Legendary live download telemetry and completed-download history.
- Native Windows Update and driver-management pages.
- Transactional install/update behavior with exact-artifact verification and fail-closed mixed-version protection.
- x64 GameInput controller bridge and controller hot-plug/reconnect support.

## v0.26.3 development goals

The v0.26.3 console-fidelity pass is replacing generalized non-PlayStation console surfaces with interfaces that match each console's real design language and navigation model.

- N64: original Huymaier presentation inspired by the supplied classic-mini reference rather than a fabricated BIOS/dashboard.
- GameCube: translucent 3D IPL-style cube with animated face rotation for Game Play, Calendar, Memory Card, and Options.
- Wii / Wii U: authentic channel/software presentation with real emulator settings integrated into the console UI instead of generic desktop menus.
- Nintendo Switch: HOME-style software presentation with only functional Huymaier-integrated system actions.
- Original Xbox / Xbox 360: console-specific dashboard navigation and presentation.
- LB/RB shoulder buttons are not used for ordinary page or selection changes in Huymaier native console interfaces.
- Emulator/library/data paths use Huymaier Console's own picker. Missing emulators can be located manually or installed through the supported latest-release installer flow.
- Console artwork resolves emulator-provided artwork first, then Huymaier cache/online fallbacks.
- Steam artwork must not intentionally remain blank when Steam-hosted or deterministic fallback artwork can be resolved.

## Source and release packages

This public repository is the authoritative source/configuration history. Large runtime audio/video/image media and firmware-derived or otherwise proprietary console presentation assets are intentionally not kept in normal Git history. Installable GitHub Release ZIPs may contain additional runtime assets only when redistribution is appropriate.

The application must never rename, move, or modify a user's game/ROM files merely to resolve artwork. Artwork is cached independently by Huymaier Console.

## Updates

Settings → Updates contains **Huymaier Console Update**, **Windows Update**, and **Driver Updates**.

Huymaier Console Update checks this repository's latest GitHub Release, downloads the installable ZIP, requires the matching SHA-256 checksum asset, stages the update out of process, closes the running shell, applies the verified package, runs the installer, and relaunches Huymaier Console.

Because the repository is public, normal release checks and downloads work anonymously; end-user PCs do not need a GitHub token or GitHub CLI login just to update Huymaier Console.

## Release automation

Releases are published by `.github/workflows/publish-release.yml`. `.release/release.json` drives version/tag/asset metadata. Verified candidate/release workflows retain the tested package bytes where required instead of silently rebuilding a different artifact.

`.github/workflows/sync-source-from-release.yml` can synchronize releasable text/source/configuration files from a published package. Historical per-build validation and release-note text files are intentionally excluded from source synchronization; release history belongs in GitHub Releases and `.release/notes/`.

## Repository

`thermalkil/HuymaierConsole`
