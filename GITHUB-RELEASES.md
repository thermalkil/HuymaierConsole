# GitHub release packaging

Huymaier Console's native updater reads the latest public GitHub Release from `thermalkil/HuymaierConsole`.

Each installable release contains:

1. One complete Huymaier Console ZIP package, for example `HC256.zip`.
2. A matching SHA-256 companion asset such as `HC256.zip.sha256`.

The native updater refuses to install a package if it cannot verify the downloaded ZIP against its companion SHA-256 asset.

Because the repository is public, normal update checks and downloads work anonymously; end-user PCs do not require `GH_TOKEN`, `GITHUB_TOKEN`, or GitHub CLI authentication.

## Automated publishing

`.github/workflows/publish-release.yml` publishes releases from `.release/release.json`.

For large packaged builds, the workflow can download the previous complete Release ZIP, apply a verified patch set from `.release/patches/<version>/`, regenerate the package's internal checksum manifests, create the new ZIP and external SHA-256 asset, and publish both under the requested tag.

The workflow writes `.release/status.json` after each publication attempt so release success/failure can be checked through normal repository access.

## Source synchronization

`.github/workflows/sync-source-from-release.yml` can extract a published release and synchronize releasable text/source/configuration files back into `main`. Large runtime audio/video/image assets remain outside ordinary Git history.

Large runtime media and firmware-derived/proprietary presentation assets must only be redistributed when appropriate.
