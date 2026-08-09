# Huymaier Console release automation

Huymaier Console releases are published by `.github/workflows/publish-release.yml`.

## Why this exists

The source repository intentionally does not store the large runtime/media payload that ships in the installable ZIP. The release workflow therefore uses the most recent published Huymaier Console ZIP as the binary/media base, overlays the tracked source/configuration payload from `main`, regenerates internal checksums, creates the new versioned ZIP, creates an external SHA-256 file, and publishes both as a GitHub Release.

## Release trigger

Publishing is controlled by `.release/release.json`. Updating that file on `main` triggers the workflow. A manifest with `publish: false` performs no release. A manifest with `publish: true` publishes the specified release if the tag does not already exist.

Example:

```json
{
  "publish": true,
  "version": "0.25.6",
  "tag": "v0.25.6",
  "title": "Huymaier Console v0.25.6",
  "asset_name": "HC256.zip",
  "package_root": "HC256",
  "notes_file": "RELEASE_NOTES-v0.25.6.txt",
  "delete_paths": []
}
```

## Safety behavior

- Existing releases are never overwritten.
- The workflow requires a previous full installable ZIP release to use as its runtime/media base.
- Repository-only files (`.github`, `.release`, `.gitignore`, `README.md`, `RELEASING.md`) are not copied into the install package.
- `checksums.sha256` and `SHA256SUMS.txt` are regenerated from the staged package.
- A separate `<asset>.sha256` release asset is generated for Huymaier Console's self-updater.
- Optional `delete_paths` removes payload paths that should no longer be carried forward from the previous release.

This makes `main` the authoritative source/configuration state while GitHub Releases remain the authoritative packaged runtime distribution channel.
