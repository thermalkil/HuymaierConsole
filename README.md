# Huymaier Console

Huymaier Console is a controller-first Windows 11 full-screen console shell with native storefront, emulator-platform, library, downloads, system settings, update, artwork, controller, and media integrations.

## Current baseline

The current development baseline is **v0.25.4**.

Confirmed behaviors carried forward include:

- Native Steam game population inside Huymaier Console while retaining Steam Big Picture as an option.
- Shared authoritative artwork between Library/Shelf and native console views.
- RPCS3 user discovery and per-user PS3 launch/save/trophy behavior.
- Native console interfaces for supported emulator platforms.
- Storefront-aware Games page and application-only Apps page.
- Controller-first Quick Access navigation.
- Dedicated Windows Update and driver-management pages.
- Epic/Legendary live download telemetry.
- Seven-day / twenty-entry completed download history.
- Native Huymaier Console update page backed by verified GitHub Releases.

## Repository vs release packages

This repository is the authoritative **source/configuration** history. Large runtime media and firmware-derived/proprietary console presentation assets are intentionally not kept in normal Git history. Installable GitHub Release ZIPs may contain additional runtime assets required by a packaged build.

The application must never rename, move, or modify a user's game/ROM files merely to resolve artwork. Artwork is cached independently by Huymaier Console.

## Updates

Settings → Updates contains **Huymaier Console Update**, **Windows Update**, and **Driver Updates**.

Huymaier Console Update checks this repository's latest GitHub Release, downloads the installable ZIP, requires a matching SHA-256 checksum asset, stages the update out of process, closes the running shell, applies the verified package, runs the installer, and relaunches Huymaier Console.

Public repositories can be checked anonymously. While this repository is private, the Windows PC needs authenticated GitHub access through `HUYMAIER_GITHUB_TOKEN`, `GITHUB_TOKEN`, or `gh auth login`.

## Repository

`thermalkil/HuymaierConsole`
