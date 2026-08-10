# Huymaier Console v0.26.2 checkpoint

Checkpoint date: 2026-08-10
Branch: `feature/v0.26.2-customization-runtime`
PR: #4 `v0.26.2 controller-first customization and provider runtime`
Baseline: published/frozen v0.26.1 exact RC19 release.

## Good/current baseline

- v0.26.1 is published and should remain frozen.
- Exact released v0.26.1 payload came from RC19 candidate run `31389633299`, source commit `be962a3e7c156e46f1eff7baaf3d66c2cda801f1`, SHA-256 `c881bf453a1d2443552a923a958778a4c8ed879c3f04c07061df3d67bdd51268`.
- Existing in-console updater can download/install v0.26.1 from GitHub Releases using `HC261.zip` + `HC261.zip.sha256`.
- Storefront library importing/file picker is confirmed fixed in v0.26.1 and must not regress.
- Guide/Home detection works on both tested PCs.
- RC19 Game Bar works over ordinary external applications.
- Remaining Game Bar bug is specific to Huymaier-native console surfaces: current Guide arbiter classifies every foreground HWND owned by the Huymaier process as the main shell, so Guide is diverted to internal Quick Access instead of opening Game Bar over PS3/PS2/Original Xbox/Xbox 360/native console surfaces.
- Game Bar modal Huymaier controller ownership must be preserved while visible.
- Customization page already exists from v0.26.1 with console display-name, accent/base/highlight colors, dynamic palette, music, navigation sounds, and keyboard appearance.

## Locked v0.26.2 work

1. Fix Guide routing by distinguishing main shell HWND from Huymaier-native console HWNDs:
   - main shell foreground => Quick Access
   - native console surface foreground => Huymaier Game Bar
   - external app foreground => Huymaier Game Bar
   - Game Bar remains true topmost/modal and does not let underlying Huymaier navigation consume the same controls.
2. Add a controller-first visual color wheel for every editable color:
   - no required hex typing
   - D-pad/left stick navigates hue/saturation
   - triggers adjust brightness/value
   - A applies, B cancels
   - bumpers can move between presets/palette slots
   - optional/read-only hex reference only
   - dynamic primary/secondary/tertiary colors use the same wheel.
3. Add Settings -> Customization -> Layout:
   - Edit Layout mode for Games page
   - reorder storefront/console tiles
   - hide/show tiles
   - size presets Small / Normal / Large / Extra Large
   - A selects/places, D-pad/stick moves, bumpers/triggers resize, B saves/exits
   - reset Games layout
   - persist across restart/update.
4. Fix shared action-card title vertical clipping at TextBlock/template level. Screenshot showed lower glyph portions clipped even when selected-card scaling had already been removed.
5. Steam storefront:
   - accurate installed/owned game count on Games page
   - per-title installed/uninstalled state
   - controller-first Install / Uninstall from management
   - preserve Steam storefront identity; never treat Steam as emulator/native console.
6. Downloads/provider progress:
   - real progress/state adapters for Steam, GOG, Xbox, EA, Ubisoft, Epic and other supported providers
   - use true byte progress where exposed
   - otherwise show honest provider states (Preparing, Waiting for provider, Downloading, Installing, Verifying, Paused, Failed, Complete)
   - do not leave provider tasks visually stalled while the provider is still working
   - preserve recent completion-history semantics: actual completion events only, max 7 days / 20 entries.

## Development pipeline

- Draft PR #4 is open.
- `.development/v0.26.2/scope.md` contains the locked scope.
- Shared deterministic batch workflow has been extended to recognize `feature/v0.26.2-customization-runtime` and `.development/v0.26.2/apply.json`.
- Continue using deterministic transforms and Windows gates rather than ad-hoc edits to the large shell source.

## Validation bar for next user-facing candidate

Do not distribute v0.26.2 candidate until all combined scope is in one package and it passes:
- Windows PowerShell 5.1 parse
- complete managed/native x64 compile
- release-shaped package integrity and closed checksums
- installer/update integrity gates
- targeted static gates for Game Bar routing/modal ownership, color wheel, layout persistence, Steam management/count, provider progress, and card clipping
- real-PC testing on both test machines before release.
