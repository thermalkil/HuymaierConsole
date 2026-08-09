# Huymaier Console

Huymaier Console is a controller-first Windows 11 full-screen console shell with native storefront, emulator-platform, library, downloads, system settings, update, artwork, controller, and media integrations.

## Current baseline

The current development and release baseline is **v0.25.6**.

Confirmed behaviors carried forward include:

- Native Steam game population inside Huymaier Console while retaining Steam Big Picture as an option.
- Shared authoritative artwork between Library/Shelf and native console views.
- RPCS3 user discovery and per-user PS3 launch/save/trophy behavior.
- Native console interfaces for supported emulator platforms.
- Storefront-aware Games page and application-only Apps page.
- Controller-first Quick Access navigation.
- Centered controller-friendly choosers for finite Settings options.
- Native Windows display scale control under Settings → Display.
- Dedicated Windows Update and driver-management pages.
- Epic/Legendary live download percentage, bytes, rate, and ETA.
- Seven-day / twenty-entry completed download history.
- Native Huymaier Console update page backed by verified GitHub Releases.
- Fresh-PC startup handling for empty/scalar/list collection states.

## Source and release packages

This public repository is the authoritative **source/configuration** history. The v0.25.6 release-to-source bootstrap synchronized 140 text/source/configuration files from the verified release package.

Large runtime audio/video/image media and firmware-derived or otherwise proprietary console presentation assets are intentionally not kept in normal Git history. Installable GitHub Release ZIPs may contain additional runtime assets only when redistribution is appropriate.

The application must never rename, move, or modify a user's game/ROM files merely to resolve artwork. Artwork is cached independently by Huymaier Console.

## Updates

Settings → Updates contains **Huymaier Console Update**, **Windows Update**, and **Driver Updates**.

Huymaier Console Update checks this public repository's latest GitHub Release, downloads the installable ZIP, requires a matching SHA-256 checksum asset, stages the update out of process, closes the running shell, applies the verified package, runs the installer, and relaunches Huymaier Console.

Because the repository is public, normal release checks and downloads work anonymously; end-user PCs do not need a GitHub token or GitHub CLI login just to update Huymaier Console.

## Release automation

Releases are published by the repository workflow in `.github/workflows/publish-release.yml`. A release manifest under `.release/release.json` drives version/tag/asset metadata. For builds that preserve large runtime media from the previous complete package, verified release patch sets under `.release/patches/` are applied before internal checksums and the external ZIP SHA-256 are regenerated.

The repository also contains `.github/workflows/sync-source-from-release.yml`, which can synchronize the releasable text/source/configuration tree back from a published package without committing the large runtime media.

## Repository

`thermalkil/HuymaierConsole`
