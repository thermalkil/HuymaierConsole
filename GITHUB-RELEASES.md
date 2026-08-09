# GitHub release packaging

Huymaier Console's native updater reads the latest GitHub Release from `thermalkil/HuymaierConsole`.

Each installable release should contain:

1. One complete Huymaier Console ZIP package, for example `HC254.zip`.
2. A SHA-256 companion asset named either `HC254.zip.sha256`, `HC254.sha256`, or `SHA256SUMS.txt`.

The updater refuses to install a package if it cannot verify the ZIP against a companion SHA-256 asset.

For a private repository the PC must provide authenticated GitHub API access using one of:

- `HUYMAIER_GITHUB_TOKEN`
- `GITHUB_TOKEN`
- `gh auth login` / GitHub CLI authentication

If the repository becomes public, release checks and downloads work without a token.

Large runtime media and firmware-derived/proprietary presentation assets should stay out of normal Git history and be included only in the release package when redistribution is permitted.
