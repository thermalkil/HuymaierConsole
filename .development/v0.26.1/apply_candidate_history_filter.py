from pathlib import Path

path = Path('.build/Build-HuymaierReleaseCandidate.ps1')
text = path.read_text(encoding='utf-8-sig')
old = "$excludeRegex='^(\\.github/|\\.development/|\\.release/|\\.source/|\\.build/|Docs/|\\.gitignore$|README\\.md$|RELEASING\\.md$|GITHUB-RELEASES\\.md$)'"
new = "$excludeRegex='^(\\.github/|\\.development/|\\.release/|\\.source/|\\.build/|Docs/|\\.gitignore$|README\\.md$|RELEASING\\.md$|GITHUB-RELEASES\\.md$|BUILD-VALIDATION[^/]*\\.txt$|RELEASE_NOTES-v[^/]*\\.txt$)'"
if old not in text:
    raise SystemExit('Expected production overlay excludeRegex was not found.')
text = text.replace(old, new, 1)
if old in text:
    raise SystemExit('Stale production overlay excludeRegex remains.')
if 'BUILD-VALIDATION[^/]*\\.txt$' not in text or 'RELEASE_NOTES-v[^/]*\\.txt$' not in text:
    raise SystemExit('Historical file exclusions were not installed.')
path.write_text(text, encoding='utf-8')
print('Production overlay now excludes historical BUILD-VALIDATION and versioned RELEASE_NOTES files.')
