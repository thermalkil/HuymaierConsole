# Huymaier Console v0.26.2 locked scope

Baseline: published v0.26.1 exact RC19 release.

## Runtime blockers and fixes

- Huymaier Game Bar must open above Huymaier-native console interfaces (PS3, PS2, Original Xbox, Xbox 360, and other native console surfaces), not only external applications.
- Main shell Guide/Home continues to open Quick Access. Guide/Home while a native console surface owns foreground opens Huymaier Game Bar over that surface.
- Game Bar remains modal for Huymaier controller navigation while visible.
- Preserve fixed storefront library importing from v0.26.1.
- Fix vertically clipped action-card titles at the shared TextBlock/template level.

## Controller-first customization

- Settings -> Customization -> visual color wheel for every editable color.
- Normal controller use requires no hex typing.
- D-pad/left stick chooses hue/saturation, triggers adjust brightness/value, A applies, B cancels, LB/RB move through presets or dynamic-palette slots.
- Hex may be displayed as a read-only/advanced reference only.
- Dynamic palette editor covers primary, secondary, and tertiary dynamic-theme colors.

## Layout customization

- Settings -> Customization -> Layout.
- Controller-first Edit Layout mode.
- Games page supports reordering storefront/console tiles.
- Hide/show individual platform tiles.
- Tile/card sizing presets: Small, Normal, Large, Extra Large.
- A selects/places, D-pad/stick moves, bumpers/triggers resize, B saves/exits.
- Reset Games layout restores defaults.
- Persist layout across restarts and upgrades.

## Steam

- Accurate Steam installed/owned count on Games page.
- Per-title installed/uninstalled state.
- Controller-first Steam Install and Uninstall from game management.
- Steam remains storefront identity, never emulator/native-console identity.

## Downloads

- Global Downloads page and download bar consume real provider transfer state for every supported provider where available.
- Steam, GOG, Xbox, EA, Ubisoft and other storefronts must not remain stalled while provider work continues.
- Use true bytes/progress when exposed by the provider.
- When exact bytes are unavailable, report honest states such as Preparing, Waiting for provider, Downloading, Installing, Verifying, Paused, Failed, or Complete instead of fabricated percentages.
- Preserve completed download/install history semantics: only actual completion events, up to 7 days and 20 entries.

All scope items ship in one v0.26.2 test candidate and must pass Windows PowerShell 5.1 parsing, native/managed x64 compilation, release-shaped package integrity, and real-PC testing before release.
