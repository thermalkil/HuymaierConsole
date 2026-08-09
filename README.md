# Huymaier Console

Huymaier Console is a controller-first Windows 11 full-screen console shell with native storefront, emulator-platform, library, downloads, system settings, update, artwork, controller, and media integrations.

## Current baseline

The repository baseline starts from **v0.25.3**.

Confirmed behaviors carried forward include:

- Native Steam game population inside Huymaier Console while retaining Steam Big Picture as an option.
- Shared authoritative artwork between Library/Shelf and native console views.
- RPCS3 user discovery and per-user PS3 launch/save/trophy behavior.
- Native console interfaces for supported emulator platforms.
- Storefront-aware Games page and application-only Apps page.
- Controller-first Quick Access navigation.
- Windows Update and driver-management pages.
- Epic/Legendary live download telemetry.
- Seven-day / twenty-entry completed download history.

## Repository vs release packages

This repository is the authoritative **source/configuration** history. Large runtime media and firmware-derived/proprietary console presentation assets are intentionally not kept in normal Git history. Installable GitHub Release ZIPs may contain additional runtime assets required by a packaged build.

The application must never rename, move, or modify a user's game/ROM files merely to resolve artwork. Artwork is cached independently by Huymaier Console.

## Updates

Huymaier Console's native updater is designed to check this repository's GitHub Releases and install a newer release package without requiring the user to leave the full-screen shell. Public repositories can be checked anonymously; private repositories require authenticated GitHub access on the PC.

## Repository

`thermalkil/HuymaierConsole`
